# Gate shard: bots 21-23 on 0e258a0e

**Verdict: RED: 1 new red (world1_run_test).** 2 of 3 passed on the first run.

- Head: 0e258a0e19585ec14d917e3737ac32d3e2901fa3, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: bot list 21 to 23 of 23 (session_test to world1_run_test), 3 tests. Run 2026-11-11T00:17:07.012Z to 2026-11-11T03:14:32.825Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 4 s | 77.3 to 72.8 |
| import-2 | 0 | 3 s | 72.8 to 72.8 |
| bot-session_test | 0 | 195 s | 72.8 to 13.1 |
| bot-skill_band_test | 0 | 460 s | 13.1 to 6.3 |
| bot-world1_run_test | 1 | 643 s | 6.3 to 5.4 |
| solo-world1_run_test-1 | 1 | 1337 s | 0.6 to 14.6 |
| solo-world1_run_test-2 | 0 | 1069 s | 14.6 to 26.7 |

## Failures

| Test | Alone | Call | Why |
| --- | --- | --- | --- |
| world1_run_test | 1/2 pass alone | new-red | no ledger row and it fails alone: a new red, which blocks (ruling ai) |

A carried red must fail the check its row names; a different failing check in the same test is a new red. Read the solo logs before posting.

Failing lines of world1_run_test alone (new-red):

```
ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D() (x3)
[tally: no script error or ERROR line] 3 lines: ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D() -> FAIL
```

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 30. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
