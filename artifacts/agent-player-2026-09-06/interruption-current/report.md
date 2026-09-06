# Agent playtest evidence

Runner acceptance: **did not pass**. Recorded trials: 1 / 1. Total run wall time: 11.43s.

Acceptance checks the configured run and requested checks. A recorded loss is a terminal outcome; a smoke pass does not establish a full clear.

| Trial | Outcome | Original terminal outcome | Wall time | Active time | Native / semantic actions | Rewards | Requested checks |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| [1](trial-001/result.json) | interrupted | none recorded | 8.56s | 0.08s | 1 / 1 | 0 | pause/resume: not requested; defeat or victory/restart: not requested |

- Trial 1: no terminal label recorded. Recorded reward actions: none. [Actions and frame timings](trial-001/events.ndjson); [complete result labels](trial-001/result.json).

Recorded action totals: 1 native intent changes, 1 semantic dispatches, 0 reward selections. Native intent changes exclude individual input ticks and helper key taps.

## Timing

All values below are milliseconds, pooled across recorded trials. Percentiles use nearest rank; missing or invalid samples are omitted, never replaced by zero.

| Stage | Samples | p50 | p95 | Maximum |
| --- | ---: | ---: | ---: | ---: |
| Input tick gap | 6 | 20.07 | 24.39 | 24.39 |
| Fresh-frame age | 1 | 64.53 | 64.53 | 64.53 |
| Capture | 1 | 14.42 | 14.42 | 14.42 |
| Total visual observation | 1 | 53.34 | 53.34 | 53.34 |
| Semantic UI observation | 3 | 2402.10 | 3333.35 | 3333.35 |

Input tick gap measures combat-loop iterations, including startup waits. Fresh-frame age is sampled when a new frame is consumed. Capture and total visual observation use those consumed frames; total observation includes capture and detection. Semantic UI observation is a separate menu-state read. These are local pipeline timings, not model API latency or complete display latency.

Wall time includes setup, menu work, observation and waits. Trial active time is the combat policy's accumulated time, not a simulation clock or displayed game completion time; a separate restart probe may add wall time without advancing the original trial policy.

## Provenance and limits

Exact per-file SHA-256 values, configuration, desktop identity and runtime versions are retained in [report.json](report.json). Compare these identities before comparing runs.

- Game and player source: 38 hashed files; unchanged at completion: True.
- Installed controller: 17 hashed files; unchanged at completion: True.
- Served build: 31 hashed files.

Combat decisions use screenshots; menu decisions use exposed accessibility names and roles. The player does not read or mutate simulation state. Saved action records and periodic screenshots support inspection and reruns, but timing and game randomness are nondeterministic. No deterministic replay, video recording, human enjoyment, or physical controller result is established.

## Errors and evidence gaps

- Trial 1 error: KeyboardInterrupt:
