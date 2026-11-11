# Gate shard: tests 361-720 on fe7c68a0

**Verdict: PASS, no new red.** 360 of 360 passed on the first run.

- Head: fe7c68a0441226600ae644789a0d6af235b371d1, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: non-bot list 361 to 720 of 1078 (enemy_line_cutter_test to pole_ride_test), 360 tests. Run 2026-11-11T11:12:05.383Z to 2026-11-11T11:48:54.974Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 123 s | 9.1 to 11.9 |
| import-2 | 0 | 3 s | 11.9 to 11.9 |
| chunk01 | 0 | 408 s | 11.9 to 19.1 |
| chunk00 | 0 | 466 s | 11.9 to 20.5 |
| chunk02 | 0 | 343 s | 19.1 to 16.4 |
| chunk03 | 0 | 1112 s | 20.5 to 12.5 |
| chunk04 | 0 | 1292 s | 16.4 to 18.1 |
| chunk05 | 0 | 504 s | 12.5 to 15.3 |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 206. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
