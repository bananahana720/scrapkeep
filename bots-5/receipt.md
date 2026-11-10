# Gate shard: bots 21-23 on 75099fa7

**Verdict: PASS, no new red.** 3 of 3 passed on the first run.

- Head: 75099fa7080378295788d9741a0a03fdf9e594b2, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64.
- Window: bot list 21 to 23 of 23 (session_test to world1_run_test), 3 tests. Run 2026-11-10T20:31:32.730Z to 2026-11-10T20:56:59.882Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall |
| --- | --- | --- |
| import-1 | 0 | 3 s |
| import-2 | 0 | 2 s |
| bot-session_test | 0 | 206 s |
| bot-skill_band_test | 0 | 601 s |
| bot-world1_run_test | 0 | 716 s |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 30. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
