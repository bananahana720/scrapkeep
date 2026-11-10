# Gate shard: tests 351-700 on 75099fa7

**Verdict: RED: 2 new reds (music_params_test, park_permanent_capacity_test).** 346 of 350 passed on the first run.

- Head: 75099fa7080378295788d9741a0a03fdf9e594b2, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64.
- Window: non-bot list 351 to 700 of 1049 (enemy_kite_drone_asset_test to presentation_ace_director_test), 350 tests. Run 2026-11-10T16:42:08.111Z to 2026-11-10T19:51:18.569Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall |
| --- | --- | --- |
| import-1 | 0 | 166 s |
| import-2 | 0 | 4 s |
| chunk00 | 1 | 865 s |
| chunk01 | 0 | 1012 s |
| chunk02 | 0 | 580 s |
| chunk03 | 1 | 1684 s |
| chunk04 | 1 | 1880 s |
| chunk05 | 1 | 669 s |
| solo-find_in_fight_test-1 | 0 | 153 s |
| solo-find_in_fight_test-2 | 0 | 2922 s |
| solo-music_params_test-1 | 0 | 1122 s |
| solo-music_params_test-2 | 1 | 403 s |
| solo-park_permanent_capacity_test-1 | 1 | 365 s |
| solo-park_permanent_capacity_test-2 | 0 | 360 s |
| solo-posture_bands_reactor_test-1 | 1 | 162 s |
| solo-posture_bands_reactor_test-2 | 1 | 161 s |

## Failures

| Test | Alone | Call | Why |
| --- | --- | --- | --- |
| find_in_fight_test | 2/2 pass alone | new-flake | fails under load only; add a flake row to project-guide/handoff/KNOWN-FAILING.tsv |
| music_params_test | 1/2 pass alone | new-red | no ledger row and it fails alone: a new red, which blocks (ruling ai) |
| park_permanent_capacity_test | 1/2 pass alone | new-red | no ledger row and it fails alone: a new red, which blocks (ruling ai) |
| posture_bands_reactor_test | 0/2 pass alone | carried | red, owner coordinator, review 2026-11-23: small breaks in under twice the grown time (60.2/31.8 = 1.89, the check wants 2.0); the ruling bl pins hold |

A carried red must fail the check its row names; a different failing check in the same test is a new red. Read the solo logs before posting.

Failing lines of posture_bands_reactor_test alone (carried):

```
[small takes at least twice grown's time] small 60.2 s, grown 31.8 s -> FAIL
```

## Error lines in every test's log

`^ERROR` 0, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 207. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

| Test | Time | Limit |
| --- | --- | --- |
| music_params_test | 389.6 s | 360 s |
| park_permanent_capacity_test | 360.2 s | 360 s |
| music_params_trace_game_test | 333.9 s | 360 s |

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
