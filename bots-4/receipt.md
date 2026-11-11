# Gate shard: bots 16-20 on 0e258a0e

**Verdict: PASS, no new red.** 5 of 5 passed on the first run.

- Head: 0e258a0e19585ec14d917e3737ac32d3e2901fa3, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: bot list 16 to 20 of 23 (posture_bands_test to self_play_launch_test), 5 tests. Run 2026-11-11T00:12:10.043Z to 2026-11-11T00:38:02.340Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 4 s | 17.7 to 17.7 |
| import-2 | 0 | 3 s | 16.6 to 16.6 |
| bot-posture_bands_test | 0 | 743 s | 16.6 to 10.6 |
| bot-restart_latency_test | 0 | 117 s | 10.6 to 7.3 |
| bot-run_save_interrupt_test | 0 | 125 s | 7.3 to 7.1 |
| bot-run_tier_test | 0 | 267 s | 7.1 to 17 |
| bot-self_play_launch_test | 0 | 293 s | 17 to 6.1 |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 77. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
