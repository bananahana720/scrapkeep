"""The Highdraft's designed event drops, in place of slices cut from its pack (PR #83).

    python -I highdraft_stingers.py [--out <assets/audio/stingers>]

Cut from the crown and islands packs, drop_fleet_anvil and drop_boiler came out as two beats of
groove that could land in any park. These are designed one-shots at the same paths, one per
Highdraft stage, in G Lydian so they sit in the band's key (cut_stingers.py writes everything
else; it leaves these two to this script):

  drop_fleet_anvil   the dropship lands: an anvil pair, then a Lydian brass stab (G B C# D) that
                     swells and falls
  drop_boiler        the burner blows: a hiss, a pop, then a whistle on the tritone (G to C#)

The second Highdraft stage plays each a whole step brighter, so the two stages differ.
The Mind's cut stingers (riser_mind_quote, drop_mind_wrong) are not made here or cut: without a
file the engine plays its pilot-aware Mind quote, which quotes each pilot's own motif back.
Same finish and level as the cut stingers: -16 LUFS, true peak at or under -1 dBTP, 44.1 kHz mono.
"""

import argparse
import hashlib
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cut_stingers import PROJECT, RATE, finish, level, lufs, true_peak_db, write_wav

DESIGNED = ("drop_fleet_anvil", "drop_boiler")
UNCUT = ("riser_mind_quote", "drop_mind_wrong")
WORLD = "3"
ZONES = {"3_1": 0, "3_2": 2}
rng = np.random.default_rng(83)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def t_of(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def noise(n, lo, hi):
    from scipy import signal
    sos = signal.butter(2, [lo, hi], "bandpass", fs=RATE, output="sos")
    return signal.sosfilt(sos, rng.standard_normal(n))


def place(n, at, x):
    out = np.zeros(n)
    s = int(at * RATE)
    out[s:s + len(x)] += x[: n - s]
    return out


def anvil(root, seconds=0.9):
    t = t_of(seconds)
    f = hz(root)
    partials = [(1.0, 1.0, 0.35), (2.76, 0.6, 0.22), (5.40, 0.4, 0.12), (8.93, 0.25, 0.07)]
    ring = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / d) for r, a, d in partials)
    click = noise(len(t), 2000, 12000) * np.exp(-t / 0.006)
    return ring + click * 0.8


def brass(notes, seconds):
    t = t_of(seconds)
    swell = np.minimum(t / 0.06, 1.0) * np.exp(-np.clip(t - 0.15, 0, None) / 0.35)
    out = np.zeros_like(t)
    for m in notes:
        phase = 2 * np.pi * hz(m) * t + 0.08 * np.sin(2 * np.pi * 5.5 * t)
        out += sum(np.sin(k * phase) / k ** 1.2 for k in range(1, 9))
    return out * swell / len(notes)


def drop_fleet_anvil(shift):
    n = int(1.4 * RATE)
    g = 43 + shift
    x = place(n, 0.0, anvil(g + 24)) + place(n, 0.17, anvil(g + 31) * 0.85)
    boom = np.sin(2 * np.pi * hz(g - 12) * t_of(1.4)) * np.exp(-t_of(1.4) / 0.2)
    lydian = [g + 24, g + 28, g + 30, g + 31]
    return x + boom * 0.9 + place(n, 0.34, brass(lydian, 1.0)) * 1.2


def drop_boiler(shift):
    n = int(1.3 * RATE)
    t = t_of(1.3)
    g = 67 + shift
    hiss = noise(n, 2500, 11000) * np.minimum(t / 0.02, 1.0) * np.exp(-t / 0.5) * 0.6
    pop = place(n, 0.08, noise(int(0.04 * RATE), 80, 3000) * np.exp(-t_of(0.04) / 0.008) * 2.0)
    pop += place(n, 0.08, np.sin(2 * np.pi * hz(g - 24) * t_of(0.25)) * np.exp(-t_of(0.25) / 0.07))
    wt = t_of(1.0)
    pitch = hz(g + 12) * 2 ** ((6 / 12) * np.clip((wt - 0.25) / 0.2, 0, 1))
    whistle = np.sin(np.cumsum(2 * np.pi * pitch / RATE)) * np.minimum(wt / 0.05, 1.0) * np.exp(-np.clip(wt - 0.6, 0, None) / 0.2)
    whistle *= 1 + 0.3 * noise(len(wt), 1000, 6000) / 3
    return hiss + pop + place(n, 0.18, whistle * 0.5)


MAKERS = {"drop_fleet_anvil": drop_fleet_anvil, "drop_boiler": drop_boiler}


def design(out_dir):
    report = {}
    for zone, shift in ZONES.items():
        report[zone] = {}
        for cue, make in MAKERS.items():
            x = level(finish(make(shift), 0.1))
            write_wav(out_dir / zone / f"{cue}.wav", x)
            report[zone][cue] = {"kind": "designed", "samples": len(x), "lufs": round(float(lufs(x)), 2),
                                 "dbtp": round(float(true_peak_db(x)), 2)}
        for cue in UNCUT:
            stale = out_dir / zone / f"{cue}.wav"
            if stale.exists():
                stale.unlink()
    return report


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, default=PROJECT / "assets/audio/stingers")
    args = ap.parse_args()
    for zone, rows in design(args.out).items():
        for cue, row in rows.items():
            sha = hashlib.sha256((args.out / zone / f"{cue}.wav").read_bytes()).hexdigest()[:12]
            print(zone, cue, row, sha)


if __name__ == "__main__":
    main()
