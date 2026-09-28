"""Split a mix into drums, bass and other stems with Demucs (htdemucs).

Copied from music-video/tools/separate.py for the Scrapkeep cover audition. Runs in
its own venv (~/.local/share/demucs-venv), takes the shared GPU lock and caps its VRAM
like every other GPU job here. Prints each stem's RMS in dB, vocals included, so an
instrumental take that grew a voice shows up without writing that stem.

    ~/.local/share/demucs-venv/bin/python separate.py <mix>.wav [...]   # -> <mix>.<stem>.wav
"""

import fcntl
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
from demucs.apply import apply_model
from demucs.pretrained import get_model

GPU_LOCK = Path("/tmp/claude-1000/ace-gpu.lock")
VRAM_FRACTION = 0.4  # ~6 GB of 16: plenty for htdemucs, leaves the desktop its share
KEEP = ("drums", "bass", "other")


def rms_db(x):
    return float(20 * np.log10(np.sqrt(np.mean(np.square(x))) + 1e-12))


def separate(model, path):
    y, sr = sf.read(path, dtype="float32", always_2d=True)
    if sr != model.samplerate:
        import julius
        y = julius.resample_frac(torch.from_numpy(y.T.copy()), sr, model.samplerate).numpy().T
    wav = torch.from_numpy(y.T.copy())
    ref = wav.mean(0)
    wav = (wav - ref.mean()) / (ref.std() + 1e-8)
    started = time.perf_counter()
    with torch.no_grad():
        stems = apply_model(model, wav[None], device="cuda", split=True, overlap=0.25,
                            progress=False)[0]
    torch.cuda.synchronize()
    took = time.perf_counter() - started
    stems = stems * (ref.std() + 1e-8) + ref.mean()
    print(f"{path}: separated in {took:.1f} s, peak torch {torch.cuda.max_memory_allocated() / 2**20:.0f} MiB, "
          f"mix {rms_db(y):.1f} dB RMS", flush=True)
    for name in model.sources:
        stem = stems[model.sources.index(name)].cpu().numpy().T
        line = f"  {name}: {rms_db(stem):.1f} dB RMS"
        if name in KEEP:
            out = Path(path).with_suffix(f".{name}.wav")
            sf.write(out, stem, model.samplerate, subtype="PCM_16")
            line += f" -> {out}"
        print(line, flush=True)


def main():
    GPU_LOCK.parent.mkdir(parents=True, exist_ok=True)
    with open(GPU_LOCK, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        torch.cuda.set_per_process_memory_fraction(VRAM_FRACTION)
        model = get_model("htdemucs")
        for p in sys.argv[1:]:
            separate(model, p)


if __name__ == "__main__":
    main()
