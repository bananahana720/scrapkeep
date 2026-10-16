"""Measure ACE-Step takes and cut a 16-bar loop from each world take.

    python cut_loops.py <render_dir> <out_dir>

Reads <render_dir>/manifest.json. For every take it reports the tempo the kick actually
plays (searched 120 to 138 BPM), the longest stretch quieter than -50 dBFS and the
peak. For the world loops it finds the kick's downbeat phase, cuts 16 bars starting at
bar 8 and crossfades 20 ms of the following audio into the head so the seam is
continuous. The loop length is set by the measured tempo, so a take that drifts gets a
wrong seam: the report prints the seam's level jump for that reason.
"""

import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf


def onset_envelope(mono, sr, hop=256):
    frames = len(mono) // hop
    low = np.convolve(mono, np.ones(32) / 32, "same")  # the kick lives low
    energy = np.array([np.sum(low[i * hop:(i + 1) * hop] ** 2) for i in range(frames)])
    flux = np.maximum(np.diff(np.log1p(energy * 1e3), prepend=0), 0)
    return flux, sr / hop


def tempo(flux, rate):
    best = None
    for bpm in np.arange(120.0, 138.01, 0.05):
        lag = rate * 60 / bpm
        idx = np.arange(0, len(flux) - 4 * lag, lag)
        score = sum(np.mean(np.interp(idx + k * lag, np.arange(len(flux)), flux)) for k in range(4))
        if best is None or score > best[0]:
            best = (score, bpm)
    return best[1]


def phase(flux, rate, bpm):
    beat = rate * 60 / bpm
    scores = [np.mean(np.interp(np.arange(p, len(flux), beat), np.arange(len(flux)), flux))
              for p in np.arange(0, beat, 0.25)]
    return np.argmax(scores) * 0.25 / rate


def longest_quiet(mono, sr, floor_db=-50.0, win=0.05):
    n = int(win * sr)
    db = [20 * np.log10(np.sqrt(np.mean(mono[i:i + n] ** 2)) + 1e-9) for i in range(0, len(mono) - n, n)]
    run = best = 0
    for d in db:
        run = run + 1 if d < floor_db else 0
        best = max(best, run)
    return best * win


def main():
    render_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    report = []
    for job in json.loads((render_dir / "manifest.json").read_text()):
        for take in job["audios"]:
            audio, sr = sf.read(take["path"], always_2d=True)
            mono = audio.mean(axis=1)
            flux, rate = onset_envelope(mono, sr)
            bpm = tempo(flux, rate)
            row = dict(take=f"{job['name']}-s{take['seed']}", seconds=round(len(mono) / sr, 2),
                       bpm=round(bpm, 2), quiet_s=round(longest_quiet(mono, sr), 2),
                       peak_db=round(20 * np.log10(np.max(np.abs(audio))), 2))
            if job["name"].endswith("-loop"):
                bar = 4 * 60 / bpm
                start = phase(flux, rate, bpm) + 8 * bar
                a, length, fade = int(start * sr), int(16 * bar * sr), int(0.02 * sr)
                if a + length + fade <= len(audio):
                    loop = audio[a:a + length].copy()
                    ramp = np.linspace(0, 1, fade)[:, None]
                    loop[:fade] = loop[:fade] * ramp + audio[a + length:a + length + fade] * (1 - ramp)
                    seam = 20 * np.log10((np.sqrt(np.mean(loop[-fade:] ** 2)) + 1e-9)
                                         / (np.sqrt(np.mean(loop[:fade] ** 2)) + 1e-9))
                    name = f"{row['take']}-16bar-loop.wav"
                    sf.write(out_dir / name, loop.astype(np.float32), sr, subtype="PCM_16")
                    row.update(loop=name, loop_start_s=round(start, 3), loop_s=round(16 * bar, 3),
                               seam_jump_db=round(float(seam), 2))
            report.append(row)
            print(row)
    (out_dir / "measurements.json").write_text(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
