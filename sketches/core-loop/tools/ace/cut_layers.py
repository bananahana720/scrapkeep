"""Cut the crown's four place layers from the Highdraft crown's own ACE pack.

    python -I cut_layers.py [--packs <music_ace dir>] [--out <assets/audio/layers>]

The crown pass (event_kinds.gd layer_crown_*) plays music_layer_crown_<place> as each place's
sound_next when the player reaches it: the hoodoos, the alcove, the toppled section and the ramp.
Each is a two-bar phrase of the stage's own track, so the place answers in the band's key and
groove: the hoodoos take the travel groove whole, the alcove the calm clip's melody under a
lowpass (sheltered), the toppled section the drop clip's drums and bass (rubble, weight) and the
ramp the build clip's last two bars, landing on the downbeat (the climb). Same finish and level
as the park stingers (cut_stingers.py): -16 LUFS, true peak at or under -1 dBTP, 44.1 kHz mono.
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cut_stingers import DEFAULT_PACKS, PROJECT, RATE, finish, level, lufs, mix, read_clip, true_peak_db, write_wav

PACK = "highdraft_crown"
LAYERS = {
    "crown_hoodoos": ("travel", 1, (1.0, 1.0, 1.0), None, None),
    "crown_alcove": ("calm", 1, (0.35, 0.6, 1.0), 2400, None),
    "crown_toppled": ("drop", 1, (1.0, 1.0, 0.35), None, None),
    "crown_ramp": ("build", "last", (1.0, 0.9, 1.0), None, 60),
}
BARS = 2


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--packs", type=Path, default=DEFAULT_PACKS)
    ap.add_argument("--out", type=Path, default=PROJECT / "assets/audio/layers")
    args = ap.parse_args()
    pack_dir = args.packs / PACK
    manifest = json.loads((pack_dir / "manifest.json").read_text())
    report = {}
    for place, (clip, first, weights, lowpass, highpass) in LAYERS.items():
        meta, stems = read_clip(pack_dir, manifest, clip)
        bar = int(meta["bar"])
        start_bar = int(meta["bars"]) - BARS if first == "last" else first
        lo = int(meta["entry"]) + start_bar * bar
        hi = lo + BARS * bar
        x = level(finish(mix(stems, weights, lo, hi, lowpass, highpass), 0.12 if first != "last" else 0.008, 0.01))
        name = f"music_layer_{place}"
        write_wav(args.out / f"{name}.wav", x)
        report[name] = dict(pack=PACK, clip=clip, bars=[start_bar, start_bar + BARS], seconds=round(len(x) / RATE, 2),
                            lufs=round(lufs(x), 1), true_peak=round(true_peak_db(x), 2))
        print(name, report[name], flush=True)
    (args.out / "manifest.json").write_text(json.dumps(report, indent=1) + "\n")


if __name__ == "__main__":
    main()
