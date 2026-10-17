"""Measure cover variations against their parents: tempo, longest quiet stretch, and whether the
parent's harmony and melody survived.

    python measure_variants.py <render folder> <round> <run dir>

"Parent match" correlates the take's pitch-class profile over time (a 12-bin chroma, 0.19 s frames)
with its own parent's. "Other parent" scores the same take against a different variant's parent,
the negative control: a twist that kept its parent scores clearly above that line.
"""

import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cut_loops  # noqa: E402

SR, HOP, N = 22050, 4096, 8192


def mono(path, seconds=60):
    audio, sr = sf.read(path, frames=int(seconds * 48000))
    audio = audio.mean(axis=1) if audio.ndim > 1 else audio
    return resample_poly(audio, SR, sr), audio, sr


def chroma(x):
    frames = np.lib.stride_tricks.sliding_window_view(x, N)[::HOP] * np.hanning(N)
    mag = np.abs(np.fft.rfft(frames, axis=1))
    f = np.fft.rfftfreq(N, 1 / SR)
    keep = (f > 80) & (f < 2000)
    pc = np.round(12 * np.log2(f[keep] / 440.0)).astype(int) % 12
    out = np.zeros((len(frames), 12))
    for k in range(12):
        out[:, k] = mag[:, keep][:, pc == k].sum(axis=1)
    return out / (out.sum(axis=1, keepdims=True) + 1e-9)


def match(a, b):
    n = min(len(a), len(b))
    return float(np.corrcoef(a[:n].ravel(), b[:n].ravel())[0, 1])


def main():
    root, rnd, run = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    variants = json.loads((root / "ace.json").read_text())["experiments"][rnd]["variants"]
    parents = {v["name"]: chroma(mono(v["src_audio"])[0]) for v in variants}
    names = [v["name"] for v in variants]
    rows = []
    for i, v in enumerate(variants):
        other = names[(i + 3) % len(names)]
        if Path(variants[(i + 3) % len(names)]["src_audio"]) == Path(v["src_audio"]):
            other = names[(i + 4) % len(names)]
        for take in sorted(run.glob(f"{v['name']}-s*.mp3")):
            x, full, sr = mono(take)
            c = chroma(x)
            flux, rate = cut_loops.onset_envelope(full if full.ndim == 1 else full, sr)
            bpm = cut_loops.tempo(flux, rate, v["bpm"] * 0.85, v["bpm"] * 1.15)
            rows.append(dict(take=take.stem, ask=v["bpm"], tempo=round(float(bpm), 1),
                             parent=round(match(c, parents[v["name"]]), 2),
                             other=round(match(c, parents[other]), 2),
                             quiet=round(float(cut_loops.longest_quiet(full, sr)), 1)))
    if not rows:
        sys.exit("no takes found")
    print(f"{'take':32s} {'ask':>4s} {'tempo':>6s} {'parent':>7s} {'other':>6s} {'quiet s':>7s}")
    for r in rows:
        print(f"{r['take']:32s} {r['ask']:4d} {r['tempo']:6.1f} {r['parent']:7.2f} {r['other']:6.2f} {r['quiet']:7.1f}")
    (run / "variants-measure.json").write_text(json.dumps(rows, indent=1))


if __name__ == "__main__":
    main()
