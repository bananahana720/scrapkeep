# Gate shard: bots 21-23 on fe7c68a0

**Verdict: PASS, no new red.** 3 of 3 passed on the first run.

- Head: fe7c68a0441226600ae644789a0d6af235b371d1, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: bot list 21 to 23 of 23 (session_test to world1_run_test), 3 tests. Run 2026-11-11T12:55:50.766Z to 2026-11-11T13:22:26.351Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 3 s | 81.7 to 76.3 |
| import-2 | 0 | 3 s | 76.3 to 76.3 |
| bot-session_test | 0 | 229 s | 76.3 to 15.9 |
| bot-skill_band_test | 0 | 556 s | 15.9 to 20.3 |
| bot-world1_run_test | 0 | 804 s | 20.3 to 14.8 |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 30. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
