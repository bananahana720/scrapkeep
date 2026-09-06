# Agent playtest evidence

Runner acceptance: **passed**. Recorded trials: 3 / 3. Total run wall time: 503.58s.

Acceptance checks the configured run and requested checks. A recorded loss is a terminal outcome; a smoke pass does not establish a full clear.

| Trial | Outcome | Original terminal outcome | Wall time | Active time | Native / semantic actions | Rewards | Requested checks |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| [1](trial-001/result.json) | lost | lost | 178.67s | 129.47s | 445 / 6 | 2 | pause/resume: passed; defeat or victory/restart: not requested |
| [2](trial-002/result.json) | won | won | 166.84s | 121.78s | 567 / 6 | 2 | pause/resume: passed; defeat or victory/restart: not requested |
| [3](trial-003/result.json) | lost | lost | 155.11s | 110.76s | 483 / 6 | 2 | pause/resume: passed; defeat or victory/restart: not requested |

- Trial 1: One more spark?; RUN ENDED. Recorded reward actions: ground-loop × 1, echo × 1. [Actions and frame timings](trial-001/events.ndjson); [complete result labels](trial-001/result.json).
- Trial 2: The orchard is yours.; ALL THREE WAVES CLEARED. Recorded reward actions: ground-loop × 1, echo × 1. [Actions and frame timings](trial-002/events.ndjson); [complete result labels](trial-002/result.json).
- Trial 3: One more spark?; RUN ENDED. Recorded reward actions: ground-loop × 1, echo × 1. [Actions and frame timings](trial-003/events.ndjson); [complete result labels](trial-003/result.json).

Recorded action totals: 1495 native intent changes, 18 semantic dispatches, 6 reward selections. Native intent changes exclude individual input ticks and helper key taps.

## Timing

All values below are milliseconds, pooled across recorded trials. Percentiles use nearest rank; missing or invalid samples are omitted, never replaced by zero.

| Stage | Samples | p50 | p95 | Maximum |
| --- | ---: | ---: | ---: | ---: |
| Input tick gap | 18067 | 20.07 | 20.11 | 32.78 |
| Fresh-frame age | 3020 | 56.20 | 70.48 | 110.90 |
| Capture | 3020 | 21.47 | 29.31 | 48.11 |
| Total visual observation | 3020 | 46.70 | 56.13 | 96.36 |
| Semantic UI observation | 43 | 3245.21 | 3477.27 | 3523.71 |

Input tick gap measures combat-loop iterations, including startup waits. Fresh-frame age is sampled when a new frame is consumed. Capture and total visual observation use those consumed frames; total observation includes capture and detection. Semantic UI observation is a separate menu-state read. These are local pipeline timings, not model API latency or complete display latency.

Wall time includes setup, menu work, observation and waits. Trial active time is the combat policy's accumulated time, not a simulation clock or displayed game completion time; a separate restart probe may add wall time without advancing the original trial policy.

## Provenance and limits

Exact per-file SHA-256 values, configuration, desktop identity and runtime versions are retained in [report.json](report.json). Compare these identities before comparing runs.

- Game and player source: 38 hashed files; unchanged at completion: True.
- Installed controller: 17 hashed files; unchanged at completion: True.
- Served build: 31 hashed files.

Combat decisions use screenshots; menu decisions use exposed accessibility names and roles. The player does not read or mutate simulation state. Saved action records and periodic screenshots support inspection and reruns, but timing and game randomness are nondeterministic. No deterministic replay, video recording, human enjoyment, or physical controller result is established.
