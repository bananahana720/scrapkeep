# Gate shard: tests 705-1055 on 0e258a0e

**Verdict: RED: 1 new red (ui_workshop_bay_test).** 348 of 351 passed on the first run.

- Head: 0e258a0e19585ec14d917e3737ac32d3e2901fa3, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: non-bot list 705 to 1055 of 1055 (presentation_ace_test to zone_schema_test), 351 tests. Run 2026-11-10T23:04:54.563Z to 2026-11-10T23:45:49.836Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 3 s | 14.8 to 14.8 |
| import-2 | 0 | 3 s | 14.8 to 15.4 |
| chunk00 | 0 | 519 s | 15.4 to 16.4 |
| chunk01 | 0 | 853 s | 15.4 to 17.5 |
| chunk02 | 0 | 1024 s | 16.4 to 14.7 |
| chunk03 | 1 | 976 s | 17.5 to 21.9 |
| chunk05 | 0 | 250 s | 21.9 to 13 |
| chunk04 | 1 | 567 s | 14.7 to 11.7 |
| solo-trace_readonly_test-1 | 0 | 141 s | 11.7 to 10.5 |
| solo-trace_readonly_test-2 | 0 | 142 s | 10.5 to 11 |
| solo-ui_workshop_bay_test-1 | 1 | 16 s | 11 to 9.7 |
| solo-ui_workshop_bay_test-2 | 1 | 15 s | 9.7 to 8.9 |
| solo-warden_counter_pulse_test-1 | 1 | 12 s | 8.9 to 8.6 |
| solo-warden_counter_pulse_test-2 | 1 | 12 s | 8.6 to 8.6 |

## Failures

| Test | Alone | Call | Why |
| --- | --- | --- | --- |
| trace_readonly_test | 2/2 pass alone | carried | red, owner testing lane, review 2026-11-23: the production actor wiring child process times out |
| ui_workshop_bay_test | 0/2 pass alone | new-red | no ledger row and it fails alone: a new red, which blocks (ruling ai) |
| warden_counter_pulse_test | 0/2 pass alone | carried | red, owner testing lane, review 2026-11-23: every check passes, but warden.gd pilot_heft prints SCRIPT ERROR lines because the CtxDouble test double has no 'run' |

A carried red must fail the check its row names; a different failing check in the same test is a new red. Read the solo logs before posting.

Failing lines of ui_workshop_bay_test alone (new-red):

```
[Moss greets behind it] bubble "Shelf's there. Hook's not for sale. Ask anyway, everyone does." for the bark "Shelf's there. Hook's not for sale. Ask anyway, everyone does." -> FAIL
```

Failing lines of warden_counter_pulse_test alone (carried):

```
SCRIPT ERROR: Invalid access to property or key 'run' on a base object of type 'RefCounted (CtxDouble)'. (x10)
```

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 10, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 262. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

| Test | Time | Limit |
| --- | --- | --- |
| speed_bank_test | 337.9 s | 360 s |

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
