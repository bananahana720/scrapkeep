# Gate shard: tests 353-704 on 0e258a0e

**Verdict: PASS, no new red (1 carried on the ledger).** 351 of 352 passed on the first run.

- Head: 0e258a0e19585ec14d917e3737ac32d3e2901fa3, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64. Load is the 1-minute average, read against 32 threads.
- Window: non-bot list 353 to 704 of 1055 (enemy_kite_drone_test to presentation_ace_director_test), 352 tests. Run 2026-11-10T22:35:19.656Z to 2026-11-10T23:18:14.293Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall | Load |
| --- | --- | --- | --- |
| import-1 | 0 | 108 s | 9.2 to 9.8 |
| import-2 | 0 | 3 s | 9.8 to 9.8 |
| chunk01 | 0 | 370 s | 9.8 to 21.2 |
| chunk00 | 0 | 492 s | 9.8 to 17.9 |
| chunk02 | 0 | 425 s | 21.2 to 25.1 |
| chunk03 | 0 | 1126 s | 17.9 to 11.4 |
| chunk05 | 1 | 556 s | 11.4 to 18.8 |
| chunk04 | 0 | 1443 s | 25.1 to 12.8 |
| solo-posture_bands_reactor_test-1 | 1 | 111 s | 12.8 to 19.3 |
| solo-posture_bands_reactor_test-2 | 1 | 114 s | 19.3 to 19.1 |

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

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 209. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

None at or past 85% of its limit.

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
