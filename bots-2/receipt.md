# Gate shard: bots 6-10 on 0e258a0e

**Verdict: PASS, no new red.** 5 of 5 passed on the first run.

- Head: 0e258a0e19585ec14d917e3737ac32d3e2901fa3, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: bot list 6 to 10 of 23 (bot_park_trace_repeat_test to matchup_lab_test), 5 tests. Run 2026-11-10T23:40:57.307Z to 2026-11-11T00:12:09.955Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 4 s | 10.9 to 10.8 |
| import-2 | 0 | 3 s | 10.8 to 10.5 |
| bot-bot_park_trace_repeat_test | 0 | 519 s | 10.5 to 9.1 |
| bot-bot_run_end_test | 0 | 278 s | 9.1 to 8.1 |
| bot-bot_six_pilots_test | 0 | 300 s | 8.1 to 13.7 |
| bot-bot_skill_bar_test | 0 | 465 s | 13.7 to 51.8 |
| bot-matchup_lab_test | 0 | 303 s | 51.8 to 17.7 |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 46. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
