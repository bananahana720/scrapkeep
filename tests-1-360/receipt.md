# Gate shard: tests 1-360 on fe7c68a0

**Verdict: PASS, no new red.** 360 of 360 passed on the first run.

- Head: fe7c68a0441226600ae644789a0d6af235b371d1, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: non-bot list 1 to 360 of 1078 (ability_swap_pressure_test to enemy_line_cutter_asset_test), 360 tests. Run 2026-11-11T11:12:03.205Z to 2026-11-11T11:41:28.041Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 123 s | 9.1 to 12 |
| import-2 | 0 | 3 s | 12 to 11.9 |
| chunk00 | 0 | 535 s | 11.9 to 18 |
| chunk01 | 0 | 724 s | 11.9 to 16.8 |
| chunk03 | 0 | 457 s | 16.8 to 9.9 |
| chunk02 | 0 | 689 s | 18 to 13.1 |
| chunk04 | 0 | 264 s | 9.9 to 13.7 |
| chunk05 | 0 | 415 s | 13.1 to 11.6 |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 233. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
