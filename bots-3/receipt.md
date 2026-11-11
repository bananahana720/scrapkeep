# Gate shard: bots 11-15 on fe7c68a0

**Verdict: PASS, no new red.** 5 of 5 passed on the first run.

- Head: fe7c68a0441226600ae644789a0d6af235b371d1, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: bot list 11 to 15 of 23 (park_reactor_fight_test to posture_bands_swarm_test), 5 tests. Run 2026-11-11T12:22:02.166Z to 2026-11-11T12:55:50.527Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 3 s | 13.5 to 14.1 |
| import-2 | 0 | 3 s | 14.1 to 14.1 |
| bot-park_reactor_fight_test | 0 | 163 s | 14.1 to 10.9 |
| bot-pocket_entry_test | 0 | 756 s | 10.9 to 50.5 |
| bot-posture_bands_flume_test | 0 | 533 s | 50.5 to 23.2 |
| bot-posture_bands_swarm_camper_test | 0 | 282 s | 23.2 to 25.3 |
| bot-posture_bands_swarm_test | 0 | 289 s | 25.3 to 81.7 |

## Failures

None.

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 88. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
