# Gate shard: tests 1-350 on 75099fa7

**Verdict: PASS, no new red.** 350 of 350 passed on the first run.

- Head: 75099fa7080378295788d9741a0a03fdf9e594b2, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64.
- Window: non-bot list 1 to 350 of 1049 (ability_swap_pressure_test to enemy_kill_first_rig_test), 350 tests. Run 2026-11-10T16:42:07.114Z to 2026-11-10T17:27:35.480Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall |
| --- | --- | --- |
| import-1 | 0 | 165 s |
| import-2 | 0 | 4 s |
| chunk00 | 0 | 1025 s |
| chunk01 | 0 | 1295 s |
| chunk03 | 0 | 666 s |
| chunk02 | 0 | 944 s |
| chunk04 | 0 | 413 s |
| chunk05 | 0 | 591 s |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 229. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
