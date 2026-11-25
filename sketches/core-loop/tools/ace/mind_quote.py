"""The Mind's first appearance: its theme, inverted, inside a Spillway track.

    python -I mind_quote.py [--packs <music_ace dir>] [--out <assets/audio/layers>]

Andrew, Q9 "A musical quote" (2026-10-17): before the Mind shows itself in the Highdraft, the
player has already heard it once, in the Spillway, as a quote. music_layer_mind_quote_spillway
is two bars of the Spillway's own travel groove with the Mind's line on top: the Keepers' theme
(K, bars 1 and 2: Sable's motif as the call and its fall back) in the Spillway's D Dorian, every
interval flipped around the first note and the last note a semitone flat (themes.py invert, the
rule harmony.gd mind_quote uses). It plays on the Mind's own voice, the sine chime (harmony.gd
"mind": voice chime), swung like the band, an octave above where the inversion lands so it sits
over the groove. The band's melody stem is pulled back under it. Same finish and level as the
crown layers (cut_layers.py): -16 LUFS, true peak at or under -1 dBTP, 44.1 kHz mono.
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cut_stingers import DEFAULT_PACKS, PROJECT, RATE, finish, level, lufs, mix, read_clip, true_peak_db, write_wav

PACK = "spillway"
CLIP = "travel"
FIRST_BAR = 1
BARS = 2
QUOTE = [(0, 74, 0.5), (0.5, 71, 0.5), (1, 67, 0.5), (1.5, 64, 0.5), (2, 60, 1.5),
         (4, 62, 0.5), (4.5, 64, 0.5), (5, 65, 1), (6, 67, 0.5), (6.5, 69, 0.5), (7, 70, 1)]
SWING = 2 / 3
WEIGHTS = (1.0, 1.0, 0.45)


def swung(beat):
    whole, frac = divmod(beat, 1.0)
    return whole + (SWING if abs(frac - 0.5) < 1e-6 else frac)


def chime(midi, seconds):
    f = 440.0 * 2 ** ((midi - 69) / 12)
    t = np.arange(int(seconds * RATE)) / RATE
    body = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / 0.08)
    return body * np.minimum(t / 0.004, 1.0) * np.exp(-t / max(0.25, seconds * 0.8))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--packs", type=Path, default=DEFAULT_PACKS)
    ap.add_argument("--out", type=Path, default=PROJECT / "assets/audio/layers")
    args = ap.parse_args()
    pack_dir = args.packs / PACK
    manifest = json.loads((pack_dir / "manifest.json").read_text())
    meta, stems = read_clip(pack_dir, manifest, CLIP)
    bar = int(meta["bar"])
    lo = int(meta["entry"]) + FIRST_BAR * bar
    band = mix(stems, WEIGHTS, lo, lo + BARS * bar)
    beat = bar / 4
    lead = np.zeros_like(band)
    for b, midi, beats in QUOTE:
        at = int(swung(b) * beat)
        note = chime(midi, beats * beat / RATE + 0.25)[: len(lead) - at]
        lead[at:at + len(note)] += note
    lead *= 0.6 * np.sqrt(np.mean(band ** 2)) / max(np.sqrt(np.mean(lead ** 2)), 1e-9)
    x = level(finish(band + lead, 0.12))
    name = "music_layer_mind_quote_spillway"
    write_wav(args.out / f"{name}.wav", x)
    row = dict(pack=PACK, clip=CLIP, bars=[FIRST_BAR, FIRST_BAR + BARS], seconds=round(len(x) / RATE, 2),
               lufs=round(lufs(x), 1), true_peak=round(true_peak_db(x), 2))
    manifest_path = args.out / "manifest.json"
    report = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    report[name] = row
    manifest_path.write_text(json.dumps(report, indent=1) + "\n")
    print(name, row)


if __name__ == "__main__":
    main()
