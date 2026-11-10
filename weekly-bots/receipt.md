# Gate shard: weekly bots 1-9 on 75099fa7

**Verdict: PASS, no new red.** 9 of 9 passed on the first run.

- Head: 75099fa7080378295788d9741a0a03fdf9e594b2, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64.
- Window: weekly bot list 1 to 9 of 9 (alpha_posture_bands_w23_test to bot_world_arrivals_test), 9 tests. Run 2026-11-10T18:45:48.168Z to 2026-11-10T19:46:13.015Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall |
| --- | --- | --- |
| import-1 | 0 | 3 s |
| import-2 | 0 | 3 s |
| bot-alpha_posture_bands_w23_test | 0 | 283 s |
| bot-bot_isle_stage5_test | 0 | 450 s |
| bot-bot_park_stage3_break_test | 0 | 350 s |
| bot-bot_six_demolitions_caster_test | 0 | 379 s |
| bot-bot_six_remembered_cannon_test | 0 | 405 s |
| bot-bot_six_runner_gunner_test | 0 | 316 s |
| bot-bot_six_tally_test | 0 | 423 s |
| bot-bot_six_tarn_test | 0 | 468 s |
| bot-bot_world_arrivals_test | 0 | 546 s |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 43. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
