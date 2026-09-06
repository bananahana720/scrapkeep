# Agent playtest evidence

Runner acceptance: **did not pass**. Recorded trials: 2 / 3. Total run wall time: 480.99s.

Acceptance checks the configured run and requested checks. A recorded loss is a terminal outcome; a smoke pass does not establish a full clear.

| Trial | Outcome | Original terminal outcome | Wall time | Active time | Native / semantic actions | Rewards | Requested checks |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| [1](trial-001/result.json) | won | won | 174.81s | 127.67s | 767 / 6 | 2 | pause/resume: passed; defeat or victory/restart: not requested |
| [2](trial-002/result.json) | timeout | none recorded | 303.45s | 242.80s | 855 / 6 | 2 | pause/resume: passed; defeat or victory/restart: not requested |

- Trial 1: The orchard is yours.; ALL THREE WAVES CLEARED. Recorded reward actions: ground-loop × 1, echo × 1. [Actions and frame timings](trial-001/events.ndjson); [complete result labels](trial-001/result.json).
- Trial 2: no terminal label recorded. Recorded reward actions: ground-loop × 1, echo × 1. [Actions and frame timings](trial-002/events.ndjson); [complete result labels](trial-002/result.json).

Recorded action totals: 1622 native intent changes, 12 semantic dispatches, 4 reward selections. Native intent changes exclude individual input ticks and helper key taps.

## Timing

All values below are milliseconds, pooled across recorded trials. Percentiles use nearest rank; missing or invalid samples are omitted, never replaced by zero.

| Stage | Samples | p50 | p95 | Maximum |
| --- | ---: | ---: | ---: | ---: |
| Input tick gap | 18478 | 20.06 | 20.11 | 32.01 |
| Fresh-frame age | 3091 | 54.92 | 69.27 | 104.52 |
| Capture | 3091 | 20.89 | 28.75 | 39.16 |
| Total visual observation | 3091 | 45.24 | 54.76 | 92.87 |
| Semantic UI observation | 34 | 3161.01 | 3377.72 | 3430.51 |

Input tick gap measures combat-loop iterations, including startup waits. Fresh-frame age is sampled when a new frame is consumed. Capture and total visual observation use those consumed frames; total observation includes capture and detection. Semantic UI observation is a separate menu-state read. These are local pipeline timings, not model API latency or complete display latency.

Wall time includes setup, menu work, observation and waits. Trial active time is the combat policy's accumulated time, not a simulation clock or displayed game completion time; a separate restart probe may add wall time without advancing the original trial policy.

## Provenance and limits

Exact per-file SHA-256 values, configuration, desktop identity and runtime versions are retained in [report.json](report.json). Compare these identities before comparing runs.

- Game and player source: 35 hashed files; unchanged at completion: True.
- Installed controller: 17 hashed files; unchanged at completion: True.
- Served build: 31 hashed files.

Combat decisions use screenshots; menu decisions use exposed accessibility names and roles. The player does not read or mutate simulation state. Saved action records and periodic screenshots support inspection and reruns, but timing and game randomness are nondeterministic. No deterministic replay, video recording, human enjoyment, or physical controller result is established.
