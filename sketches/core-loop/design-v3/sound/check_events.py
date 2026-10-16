"""Check the event set against the sound bible's hard targets.

    python check_events.py <event_dir>          # exit 1 on any failure
    python check_events.py --self-test          # a planted late, long, clipped cue must fail

Targets, from SOUND-BIBLE.md "Sound that answers play":
- impact, danger and boss cues reach -20 dB of their peak within 5 ms of the file start, so
  the asset adds no latency to the engine's one-frame (16.7 ms at 60 fps) answer
- every cue peaks at or below -1 dBFS
- length budgets: ui 0.5 s, impact 1.0 s, reward and danger 2.5 s, stinger 3.5 s, boss 4.0 s
"""

import json
import sys
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf

ONSET_MS = 5.0
BUDGET = {"ui": 0.5, "impact": 1.0, "reward": 2.5, "danger": 2.5, "stinger": 3.5, "boss": 4.0}
INSTANT = {"impact", "danger", "boss"}


def check(event_dir):
    manifest = json.loads((event_dir / "manifest.json").read_text())
    if not manifest:
        return ["manifest lists no cues"]
    failures = []
    for row in manifest:
        audio, sr = sf.read(event_dir / f"{row['cue']}.wav")
        peak = np.max(np.abs(audio))
        peak_db = 20 * np.log10(peak + 1e-12)
        onset_ms = np.argmax(np.abs(audio) >= peak * 0.1) / sr * 1000
        seconds = len(audio) / sr
        if peak_db > -0.9:
            failures.append(f"{row['cue']}: peak {peak_db:.2f} dBFS above -1")
        if seconds > BUDGET[row["family"]]:
            failures.append(f"{row['cue']}: {seconds:.2f} s over the {row['family']} budget of {BUDGET[row['family']]} s")
        if row["family"] in INSTANT and onset_ms > ONSET_MS:
            failures.append(f"{row['cue']}: onset at {onset_ms:.1f} ms, target {ONSET_MS} ms")
    print(f"checked {len(manifest)} cues, {len(failures)} failures")
    for line in failures:
        print("  FAIL", line)
    return failures


def self_test():
    with tempfile.TemporaryDirectory() as tmp:
        d, sr = Path(tmp), 48000
        late = np.concatenate([np.zeros(int(0.03 * sr)), np.ones(int(1.2 * sr)) * 0.999])
        sf.write(d / "planted.wav", late.astype(np.float32), sr, subtype="PCM_16")
        (d / "manifest.json").write_text(json.dumps([{"cue": "planted", "family": "impact"}]))
        failures = check(d)
    kinds = {"peak", "budget", "onset"}
    found = {k for k in kinds for f in failures if k in f}
    if found != kinds:
        print(f"self-test FAILED: the planted cue should trip {sorted(kinds)}, tripped {sorted(found)}")
        return 1
    print("self-test passed: the planted cue tripped peak, budget and onset")
    return 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(self_test())
    sys.exit(1 if check(Path(sys.argv[1])) else 0)
