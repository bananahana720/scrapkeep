# Gate shard: weekly tests 1-75 on 75099fa7

**Verdict: PASS, no new red (2 carried on the ledger, 1 new load flake to list).** 72 of 75 passed on the first run.

- Head: 75099fa7080378295788d9741a0a03fdf9e594b2, a clean checkout, recorded before the first step and checked before each one.
- Box: 32 vCPU AMD Ryzen 9 5950X 16-Core Processor, 63 GB. Godot: Godot_v4.7.2-stable_linux.x86_64.
- Window: weekly non-bot list 1 to 75 of 75 (achievement_fragment_test to warden_swarm_test), 75 tests. Run 2026-11-10T17:27:35.676Z to 2026-11-10T19:37:04.261Z by `scripts/gate/shard.mjs`; no runner patch, no commits, no pushes.

## Steps

| Step | Exit | Wall |
| --- | --- | --- |
| import-1 | 0 | 4 s |
| import-2 | 0 | 4 s |
| chunk01 | 1 | 803 s |
| chunk00 | 1 | 2610 s |
| solo-bot_stub_boss_test-1 | 0 | 1386 s |
| solo-bot_stub_boss_test-2 | 0 | 847 s |
| solo-posture_bands_mind_test-1 | 1 | 278 s |
| solo-posture_bands_mind_test-2 | 1 | 255 s |
| solo-waking_fight_test-1 | 1 | 33 s |
| solo-waking_fight_test-2 | 1 | 32 s |

## Failures

| Test | Alone | Call | Why |
| --- | --- | --- | --- |
| bot_stub_boss_test | 2/2 pass alone | new-flake | fails under load only; add a flake row to project-guide/handoff/KNOWN-FAILING.tsv |
| posture_bands_mind_test | 0/2 pass alone | carried | red, owner coordinator, review 2026-11-23: small Mind median 119.1 s against its 103.8 s pin; world 3, out of scope until the world 1 sitting (ruling at) |
| waking_fight_test | 0/2 pass alone | carried | red, owner coordinator, review 2026-11-23: exits 0 but prints an ERROR line from ambient_life.gd line 85; world 2, out of scope until the world 1 sitting (ruling at) |

A carried red must fail the check its row names; a different failing check in the same test is a new red. Read the solo logs before posting.

Failing lines of posture_bands_mind_test alone (carried):

```
[small median within 10 percent of the pin] small 119.1 s, pin 103.8 s -> FAIL
```

Failing lines of waking_fight_test alone (carried):

```
ERROR: Resumed function '_stage_entered()' after await, but class instance is gone. At script: res://src/presentation/ambient_life.gd:85
```

## Error lines in every test's log

`^ERROR` 1, `SCRIPT ERROR` 0, "still in use" 0, "previously freed" 0, "leaked at exit" warnings 64. The count covers passing tests too (logs/ holds one file per test).

## Tests near their time limit

| Test | Time | Limit |
| --- | --- | --- |
| bot_stub_boss_test | 180.1 s | 180 s |
| presentation_random_guard_test | 178.5 s | 180 s |

## What moved against the last promoted head

(The shard thread writes this part: compare logs/ with the receipts folder named in STATE.md's Wave facts.)
