# Gate shard: tests 721-1078 on fe7c68a0

**Verdict: PASS, no new red (1 carried on the ledger).** 357 of 358 passed on the first run.

- Head: fe7c68a0441226600ae644789a0d6af235b371d1, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: non-bot list 721 to 1078 of 1078 (posture_bands_reactor_test to zone_schema_test), 358 tests. Run 2026-11-11T11:41:28.133Z to 2026-11-11T12:22:02.064Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 3 s | 11.6 to 11.6 |
| import-2 | 0 | 3 s | 11.6 to 11.2 |
| chunk00 | 1 | 583 s | 11.2 to 18.4 |
| chunk01 | 0 | 813 s | 11.2 to 20.6 |
| chunk02 | 0 | 1040 s | 18.4 to 12.8 |
| chunk03 | 0 | 1088 s | 20.6 to 16.9 |
| chunk04 | 0 | 567 s | 12.8 to 13.1 |
| chunk05 | 0 | 312 s | 16.9 to 12.2 |
| solo-posture_bands_reactor_test-1 | 1 | 108 s | 12.2 to 14.7 |
| solo-posture_bands_reactor_test-2 | 1 | 107 s | 14.7 to 13.5 |

## Failures

| Test | Alone | Call | Why |
| --- | --- | --- | --- |
| posture_bands_reactor_test | 0/2 pass alone | carried | red, owner coordinator, review 2026-11-23: small breaks in under twice the grown time (60.2/31.8 = 1.89, the check wants 2.0); the ruling bl pins hold |

A carried red must fail the check its row names; a different failing check in the same test is a new red. Read the solo logs before posting.

Failing lines of posture_bands_reactor_test alone (carried):

```
[small takes at least twice grown's time] small 60.2 s, grown 31.8 s -> FAIL
```

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 290. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

| Test | Time | Limit |
| --- | --- | --- |
| speed_bank_test | 337.5 s | 360 s |

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
