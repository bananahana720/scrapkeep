# Gate shard: bots 16-20 on 75099fa7

**Verdict: PASS, no new red.** 5 of 5 passed on the first run.

- Head: 75099fa7080378295788d9741a0a03fdf9e594b2, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64.
- Window: bot list 16 to 20 of 23 (posture_bands_test to self_play_launch_test), 5 tests. Run 2026-11-10T20:01:20.778Z to 2026-11-10T20:31:44.003Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall |
| --- | --- | --- |
| import-1 | 0 | 7 s |
| import-2 | 0 | 6 s |
| bot-posture_bands_test | 0 | 1068 s |
| bot-restart_latency_test | 0 | 109 s |
| bot-run_save_interrupt_test | 0 | 119 s |
| bot-run_tier_test | 0 | 252 s |
| bot-self_play_launch_test | 0 | 261 s |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 77. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
