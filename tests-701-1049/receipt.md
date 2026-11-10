# Gate shard: tests 701-1049 on 75099fa7

**Verdict: PASS, no new red (4 carried on the ledger, 2 new load flakes to list).** 343 of 349 passed on the first run.

- Head: 75099fa7080378295788d9741a0a03fdf9e594b2, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64.
- Window: non-bot list 701 to 1049 of 1049 (presentation_ace_test to zone_schema_test), 349 tests. Run 2026-11-10T16:42:08.283Z to 2026-11-10T18:45:48.065Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall |
| --- | --- | --- |
| import-1 | 0 | 165 s |
| import-2 | 0 | 4 s |
| chunk00 | 1 | 980 s |
| chunk01 | 0 | 1532 s |
| chunk02 | 1 | 1333 s |
| chunk03 | 1 | 1282 s |
| chunk04 | 1 | 749 s |
| chunk05 | 0 | 319 s |
| solo-presentation_hitstop_test-1 | 0 | 373 s |
| solo-presentation_hitstop_test-2 | 0 | 2923 s |
| solo-stage_entry_budget_test-1 | 0 | 38 s |
| solo-stage_entry_budget_test-2 | 0 | 37 s |
| solo-tree_play_test-1 | 0 | 66 s |
| solo-tree_play_test-2 | 0 | 61 s |
| solo-telegraph_timing_pack_test-1 | 0 | 271 s |
| solo-telegraph_timing_pack_test-2 | 0 | 271 s |
| solo-trace_readonly_test-1 | 1 | 24 s |
| solo-trace_readonly_test-2 | 1 | 24 s |
| solo-warden_counter_pulse_test-1 | 1 | 15 s |
| solo-warden_counter_pulse_test-2 | 1 | 14 s |

## Failures

| Test | Alone | Call | Why |
| --- | --- | --- | --- |
| presentation_hitstop_test | 2/2 pass alone | new-flake | fails under load only; add a flake row to project-guide/handoff/KNOWN-FAILING.tsv |
| stage_entry_budget_test | 2/2 pass alone | carried | flake, owner testing lane, review 2026-11-23: the stage 2 activities sample reads 34.9 ms against the 30 ms limit under load; its retry and a solo run pass (wave 31 gate) |
| tree_play_test | 2/2 pass alone | carried | red, owner testing lane, review 2026-11-23: the class 5 child process times out on a cloud box, with no script error; not yet re-read on the PC |
| telegraph_timing_pack_test | 2/2 pass alone | new-flake | fails under load only; add a flake row to project-guide/handoff/KNOWN-FAILING.tsv |
| trace_readonly_test | 0/2 pass alone | carried | red, owner testing lane, review 2026-11-23: the production actor wiring child process times out |
| warden_counter_pulse_test | 0/2 pass alone | carried | red, owner testing lane, review 2026-11-23: every check passes, but warden.gd pilot_heft prints SCRIPT ERROR lines because the CtxDouble test double has no 'run' |

A carried red must fail the check its row names; a different failing check in the same test is a new red. Read the solo logs before posting.

Failing lines of trace_readonly_test alone (carried):

```
[production actor wiring child passes without a direct replay_side call] exit -1, timeout true, errors [] -> FAIL
```

Failing lines of warden_counter_pulse_test alone (carried):

```
SCRIPT ERROR: Invalid access to property or key 'run' on a base object of type 'RefCounted (CtxDouble)'. (x10)
```

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 10, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 258. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

| Test | Time | Limit |
| --- | --- | --- |
| presentation_hitstop_test | 180.3 s | 180 s |
| telegraph_timing_pack_test | 360.1 s | 360 s |
| speed_bank_test | 339.4 s | 360 s |
| scatter_rows_test | 275.3 s | 300 s |

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
