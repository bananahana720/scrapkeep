"""Offline image and recovery evidence. Never opens a desktop or dispatches inputs."""

import argparse
import hashlib
import json
import statistics
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from PIL import Image
from observer import scene_sample, scene_change
from policy import Policy
from vision import detect


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("retained_root", type=Path)
    args = parser.parse_args()
    paths = sorted(args.retained_root.glob("**/timeout.jpg"))
    if not paths:
        raise SystemExit("No retained timeout images found")
    rows = []
    timings = []
    samples = []
    for path in paths:
        image = Image.open(path)
        image.load()
        started = time.perf_counter()
        targets = detect(image)
        sample = scene_sample(image)
        elapsed = (time.perf_counter() - started) * 1000
        timings.append(elapsed)
        samples.append(sample)
        unchanged = scene_change(sample, sample)
        assert unchanged["changed_fraction"] == 0
        policy = Policy()
        phases = []
        for number in range(100):
            policy.step(0.1)
            policy.aim(dict(id=number, width=image.width, height=image.height,
                            targets=targets, scene_change=unchanged))
            if not phases or phases[-1]["phase"] != policy.recovery.phase:
                phases.append(dict(at=round(policy.elapsed, 2), **policy.diagnostics()["recovery"]))
        assert any(row["phase"] == "back" for row in phases)
        assert any(row["phase"] == "advance" for row in phases)
        rows.append(dict(path=str(path), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                         targets=targets, detect_and_sample_ms=round(elapsed, 3),
                         identical_image=unchanged, replay_phases=phases))
    assert len(samples) > 1
    differences = [scene_change(samples[0], sample) for sample in samples[1:]]
    assert any(item["changed_fraction"] > 0.015 for item in differences)
    source = Path(__file__).resolve().parents[1]
    result = dict(
        evidence_level=4,
        claims="Retained-image detection, pixel-change discrimination and timed policy replay only",
        world_translation="unverified", native_input="not used",
        source_sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in sorted(source.glob("*.py"))},
        timing=dict(samples=len(timings), mean_ms=round(statistics.mean(timings), 3),
                    max_ms=round(max(timings), 3)),
        cross_view_scene_changes=differences, retained_images=rows,
    )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
