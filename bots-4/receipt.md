# Gate shard: bots 16-20 on fe7c68a0

**Verdict: PASS, no new red.** 5 of 5 passed on the first run.

- Head: fe7c68a0441226600ae644789a0d6af235b371d1, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: bot list 16 to 20 of 23 (posture_bands_test to self_play_launch_test), 5 tests. Run 2026-11-11T12:44:35.852Z to 2026-11-11T13:14:32.844Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 3 s | 18.1 to 18.7 |
| import-2 | 0 | 3 s | 18.7 to 18.7 |
| bot-posture_bands_test | 0 | 892 s | 18.7 to 16.4 |
| bot-restart_latency_test | 0 | 132 s | 16.4 to 15.3 |
| bot-run_save_interrupt_test | 0 | 141 s | 15.3 to 13.6 |
| bot-run_tier_test | 0 | 294 s | 13.6 to 20.3 |
| bot-self_play_launch_test | 0 | 332 s | 20.3 to 9.2 |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 77. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
