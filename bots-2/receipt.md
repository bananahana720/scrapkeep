# Gate shard: bots 6-10 on 75099fa7

**Verdict: PASS, no new red (1 new load flake to list).** 4 of 5 passed on the first run.

- Head: 75099fa7080378295788d9741a0a03fdf9e594b2, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64.
- Window: bot list 6 to 10 of 23 (bot_park_trace_repeat_test to matchup_lab_test), 5 tests. Run 2026-11-10T19:27:06.845Z to 2026-11-10T20:31:32.654Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall |
| --- | --- | --- |
| import-1 | 0 | 5 s |
| import-2 | 0 | 4 s |
| bot-bot_park_trace_repeat_test | 1 | 853 s |
| bot-bot_run_end_test | 0 | 474 s |
| bot-bot_six_pilots_test | 0 | 544 s |
| bot-bot_skill_bar_test | 0 | 644 s |
| bot-matchup_lab_test | 0 | 479 s |
| solo-bot_park_trace_repeat_test-1 | 0 | 424 s |
| solo-bot_park_trace_repeat_test-2 | 0 | 439 s |

## Failures

| Test | Alone | Call | Why |
| --- | --- | --- | --- |
| bot_park_trace_repeat_test | 2/2 pass alone | new-flake | fails under load only; add a flake row to project-guide/handoff/KNOWN-FAILING.tsv |

A carried red must fail the check its row names; a different failing check in the same test is a new red. Read the solo logs before posting.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 44. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

| Test | Time | Limit |
| --- | --- | --- |
| bot_park_trace_repeat_test | 848.6 s | 900 s |

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
