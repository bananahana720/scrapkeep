"""One process at a time; evidence stays outside Git. Uses the task-local command recorder."""
import argparse
import importlib.util
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--pass-id", default="pass1")
    parser.add_argument("--revision", type=int, choices=[1, 2], default=1)
    parser.add_argument("--first", type=int, default=1)
    parser.add_argument("--last", type=int, default=8)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--ride-only", action="store_true")
    parser.add_argument("--pilots", default="rivet,kest,floor")
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("recorder", args.evidence / "run.py")
    recorder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(recorder)
    root = Path(__file__).resolve().parents[5]
    sketch = root / "sketches/core-loop"
    godot = ["nice", "-n", "10", "timeout", "1800s", "godot", "--headless", "--path", str(sketch)]
    for seed in range(args.first, args.last + 1):
        name = f"park_wgen_s{seed}"
        if not args.ride_only:
            commands = [("gen", ["nice", "-n", "10", "prlimit", "--as=12884901888",
                         "/home/andrew/.local/bin/blender", "--background", "--python-exit-code", "1", "--python", str(Path(__file__).with_name("generate.py")),
                         "--", "--seed", str(seed), "--revision", str(args.revision), "--out", str(sketch / f"src/world/park/{name}.json"),
                         "--lines-out", str(sketch / f"tools/park_lines/{name}.json"), "--meta-out", str(args.evidence / f"meta-s{seed}.json")])]
            commands.extend((tool, godot + ["--script", f"res://tools/blender/wgen/{tool}.gd", "--", f"--map={name}"]) for tool in ("schema", "bake", "graph"))
            for tool, command in commands:
                if recorder.run(f"{args.pass_id}-{tool}-s{seed}", command) != 0:
                    return 1
        if args.prepare_only:
            continue
        for pilot in args.pilots.split(","):
            command = godot + ["--fixed-fps", "90", "--script", "res://tools/blender/wgen/traverse.gd", "--", "--table=park", "--stage=1", f"--map={name}",
                              f"--pilot={'rivet' if pilot == 'floor' else pilot}", "--seeds=1,2,3,4", f"--out={args.evidence / args.pass_id / f's{seed}'}", "--commit=9ac8969+trial"]
            if pilot == "floor": command.append("--floor")
            if recorder.run(f"{args.pass_id}-ride-s{seed}-{pilot}", command) != 0:
                return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
