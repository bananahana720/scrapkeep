# Gate shard: bots 1-5 on fe7c68a0

**Verdict: PASS, no new red.** 5 of 5 passed on the first run.

- Head: fe7c68a0441226600ae644789a0d6af235b371d1, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: bot list 1 to 5 of 23 (alpha_bot_sweep_test to bot_completionist_repeat_test), 5 tests. Run 2026-11-11T11:48:55.083Z to 2026-11-11T12:11:22.466Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 3 s | 15.3 to 14.7 |
| import-2 | 0 | 3 s | 14.7 to 14.7 |
| bot-alpha_bot_sweep_test | 0 | 212 s | 14.7 to 17 |
| bot-alpha_posture_bands_test | 0 | 246 s | 17 to 15.6 |
| bot-boss_phase_hold_test | 0 | 340 s | 15.6 to 9.6 |
| bot-bot_chain_hand_test | 0 | 293 s | 9.6 to 14.9 |
| bot-bot_completionist_repeat_test | 0 | 251 s | 14.9 to 15 |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 34. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
