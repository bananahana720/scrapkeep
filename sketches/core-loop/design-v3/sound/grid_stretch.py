"""Time-stretch measured ACE-Step takes onto the 129 BPM house grid with Rubber Band.

    python grid_stretch.py <render_dir> <out_dir> [--target 129] [--only <name prefix> ...]

Reads <render_dir>/measure/measurements.json from cut_loops.py and the take paths from
<render_dir>/manifest.json. A take is stretched only when its measured tempo is within
4.5 percent of the target, the range ACE-Step drifts in; anything further off is more
likely a detector misread (a half-time or 3:4 reading), so it is listed and skipped.
Each output is re-measured, and the report gives the before and after tempo.
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cut_loops  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("render_dir", type=Path)
    ap.add_argument("out_dir", type=Path)
    ap.add_argument("--target", type=float, default=129.0)
    ap.add_argument("--only", nargs="*", default=(), help="stretch only takes whose name starts with one of these")
    args = ap.parse_args()
    measured = {row["take"]: row for row in
                json.loads((args.render_dir / "measure/measurements.json").read_text())}
    args.out_dir.mkdir(parents=True, exist_ok=True)
    report = []
    for job in json.loads((args.render_dir / "manifest.json").read_text()):
        for take in job["audios"]:
            name = f"{job['name']}-s{take['seed']}"
            if args.only and not name.startswith(tuple(args.only)):
                continue
            bpm = measured.get(name, {}).get("bpm")
            if bpm is None or abs(bpm / args.target - 1) > 0.045:
                report.append(dict(take=name, bpm=bpm, skipped="tempo reading too far from target"))
                print(report[-1])
                continue
            out = args.out_dir / f"{name}-{args.target:g}bpm.wav"
            subprocess.run(["rubberband", "-q", "--fine", "-T", f"{args.target / bpm:.5f}",
                            take["path"], str(out)], check=True)
            audio, sr = sf.read(out, always_2d=True)
            flux, rate = cut_loops.onset_envelope(audio.mean(axis=1), sr)
            report.append(dict(take=name, bpm_before=bpm, bpm_after=round(cut_loops.tempo(flux, rate, args.target * 0.93, args.target * 1.07), 2),
                               file=out.name))
            print(report[-1])
    (args.out_dir / "stretch.json").write_text(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
