import argparse
import hashlib
import json
import statistics
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from observer import SceneChange, lower_sky_fraction, upper_ground_fraction
from PIL import Image
from policy import Policy
from vision import detect


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--retained-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    fixtures = Path(__file__).parent / "fixtures"
    paths = [fixtures / "workers.jpg", fixtures / "nameplate.jpg"]
    paths.extend(sorted(args.retained_root.rglob("timeout.jpg")))
    records = []
    costs = []
    for path in paths:
        image = Image.open(path).convert("RGB")
        change = SceneChange()
        for _ in range(10):
            started = time.perf_counter()
            targets = detect(image)
            change.measure(image)
            costs.append((time.perf_counter() - started) * 1000)
        repeated = change.measure(image)
        assert repeated["changed_fraction"] == 0
        framing = {
            "lower_sky_fraction": lower_sky_fraction(image),
            "upper_ground_fraction": upper_ground_fraction(image),
        }
        policy = Policy()
        transitions = []
        previous = None
        for i in range(360):
            policy.step(0.1)
            policy.aim(
                {
                    "id": i,
                    "time": i / 10,
                    "width": image.width,
                    "height": image.height,
                    "targets": targets,
                    "scene_change": repeated,
                    **framing,
                }
            )
            if policy.recovery.phase in ("reverse", "lateral", "settle", "relocate"):
                assert policy.elapsed < policy.recovery.until + 0.001
            phase = policy.recovery.phase
            if phase != previous:
                transitions.append(
                    {
                        "seconds": round(policy.elapsed, 2),
                        **policy.diagnostics()["recovery"],
                    }
                )
                previous = phase
        phases = {item["phase"] for item in transitions}
        assert {"reverse", "lateral", "settle"} <= phases
        assert policy.recovery.attempt >= 4
        records.append(
            {
                "path": str(path),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "targets": targets,
                "repeated_image": repeated,
                "framing": framing,
                "transitions": transitions,
            }
        )
    change = SceneChange()
    change.measure(Image.open(fixtures / "workers.jpg"))
    different = change.measure(Image.open(fixtures / "nameplate.jpg"))
    assert different["changed_fraction"] > 0.05
    result = {
        "verdict": "PASS+NOTES",
        "evidence_level": 4,
        "source_sha256": {
            name: hashlib.sha256(
                (Path(__file__).resolve().parents[1] / name).read_bytes()
            ).hexdigest()
            for name in ("policy.py", "observer.py", "combat.py", "vision.py")
        },
        "detection_and_scene_change_ms": {
            "samples": len(costs),
            "median": statistics.median(costs),
            "p95": sorted(costs)[int(len(costs) * 0.95)],
            "maximum": max(costs),
        },
        "different_retained_images": different,
        "records": records,
        "limits": [
            "Image differences are not world translation or successful obstacle escape.",
            "Repeated retained images simulate fresh captures of a frozen scene.",
            "Cross-image difference uses unrelated captures, not a timed movement sequence.",
            "Detection is unchanged; timeout views remain outside proven worker-face coverage.",
            "Live reliability is unmeasured in this candidate.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(
        json.dumps(
            {
                "verdict": result["verdict"],
                "images": len(records),
                "timing": result["detection_and_scene_change_ms"],
                "different_retained_images": different,
                "output": str(args.output),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
