# Gate shard: tests 1-352 on 0e258a0e

**Verdict: PASS, no new red.** 352 of 352 passed on the first run.

- Head: 0e258a0e19585ec14d917e3737ac32d3e2901fa3, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: non-bot list 1 to 352 of 1055 (ability_swap_pressure_test to enemy_kite_drone_asset_test), 352 tests. Run 2026-11-10T22:35:17.738Z to 2026-11-10T23:04:54.453Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 107 s | 9.2 to 9.2 |
| import-2 | 0 | 3 s | 9.2 to 9.8 |
| chunk00 | 0 | 564 s | 9.8 to 23.7 |
| chunk01 | 0 | 764 s | 9.8 to 29 |
| chunk03 | 0 | 502 s | 29 to 14 |
| chunk02 | 0 | 713 s | 23.7 to 14.2 |
| chunk04 | 0 | 262 s | 14 to 14.1 |
| chunk05 | 0 | 389 s | 14.2 to 14.8 |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 230. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
