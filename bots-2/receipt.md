# Gate shard: bots 6-10 on fe7c68a0

**Verdict: PASS, no new red.** 5 of 5 passed on the first run.

- Head: fe7c68a0441226600ae644789a0d6af235b371d1, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: bot list 6 to 10 of 23 (bot_park_trace_repeat_test to matchup_lab_test), 5 tests. Run 2026-11-11T12:11:22.560Z to 2026-11-11T12:44:35.749Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 3 s | 15 to 20.9 |
| import-2 | 0 | 3 s | 20.9 to 20.3 |
| bot-bot_park_trace_repeat_test | 0 | 623 s | 20.3 to 14.2 |
| bot-bot_run_end_test | 0 | 303 s | 14.2 to 9.5 |
| bot-bot_six_pilots_test | 0 | 302 s | 9.5 to 8.2 |
| bot-bot_skill_bar_test | 0 | 420 s | 8.2 to 52.1 |
| bot-matchup_lab_test | 0 | 339 s | 52.1 to 18.1 |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 46. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
