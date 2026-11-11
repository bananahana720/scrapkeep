# Gate shard: bots 1-5 on 0e258a0e

**Verdict: PASS, no new red.** 5 of 5 passed on the first run.

- Head: 0e258a0e19585ec14d917e3737ac32d3e2901fa3, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: bot list 1 to 5 of 23 (alpha_bot_sweep_test to bot_completionist_repeat_test), 5 tests. Run 2026-11-10T23:18:14.415Z to 2026-11-10T23:40:57.216Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 3 s | 19.1 to 19.1 |
| import-2 | 0 | 3 s | 19.1 to 19.3 |
| bot-alpha_bot_sweep_test | 0 | 223 s | 19.3 to 18.3 |
| bot-alpha_posture_bands_test | 0 | 249 s | 18.3 to 14.5 |
| bot-boss_phase_hold_test | 0 | 344 s | 14.5 to 11.6 |
| bot-bot_chain_hand_test | 0 | 309 s | 11.6 to 15.4 |
| bot-bot_completionist_repeat_test | 0 | 232 s | 15.4 to 10.9 |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 34. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
