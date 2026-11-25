"""Measure each core pack's key from its stems and compare it with the manifest's nominal tonic.

    python key_check.py <work>      # <work>/stems/htdemucs/<mix>/{bass,other,vocals}.wav from split.sh

Chroma (FFT, 60-2000 Hz, bass weighted double) correlated with the Krumhansl-Schmuckler major and minor
profiles. Reports the best key, the correlation of the best fit for the nominal tonic, and a verdict.
It reports; it never edits a manifest.
"""
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

NAMES = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B']
MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
SKETCH = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from package_core_packs import PACKS
CUE_OF = {pack: row[2] for pack, row in PACKS.items()}


def chroma(path, weight):
    a, sr = sf.read(path, always_2d=True)
    x = a.mean(axis=1)[:sr * 90]
    out = np.zeros(12)
    n = 8192
    win = np.hanning(n)
    freqs = np.fft.rfftfreq(n, 1 / sr)
    ok = (freqs > 60) & (freqs < 2000)
    pc = (np.round(12 * np.log2(freqs[ok] / 261.6256)).astype(int)) % 12
    for i in range(0, len(x) - n, n * 2):
        mag = np.abs(np.fft.rfft(x[i:i + n] * win))[ok]
        out += np.bincount(pc, weights=mag, minlength=12)
    return out / (out.sum() + 1e-9) * weight


def best_key(c):
    rows = []
    for t in range(12):
        for mode, prof in (('major', MAJOR), ('minor', MINOR)):
            rows.append((float(np.corrcoef(c, np.roll(prof, t))[0, 1]), NAMES[t], mode))
    return sorted(rows, reverse=True)


def main():
    work = Path(sys.argv[1])
    for pack, cue in CUE_OF.items():
        folder = work / 'stems/htdemucs' / f'{cue}-current'
        if not (folder / 'other.wav').exists():
            print(f'{pack:16s} no stems yet')
            continue
        c = chroma(folder / 'other.wav', 1.0) + chroma(folder / 'bass.wav', 2.0)
        rows = best_key(c)
        nominal = PACKS[pack][1]
        near = [r for r in rows if r[1] == nominal]
        top = rows[0]
        rel = {NAMES[(NAMES.index(top[1]) + (3 if top[2] == 'minor' else -3)) % 12]}
        verdict = 'match' if top[1] == nominal else ('relative' if nominal in rel else 'MISMATCH')
        print(f'{pack:16s} nominal {nominal:2s}  best {top[1]} {top[2]} r={top[0]:.2f}  nominal-best {near[0][2]} r={near[0][0]:.2f}  -> {verdict}')


if __name__ == '__main__':
    main()
