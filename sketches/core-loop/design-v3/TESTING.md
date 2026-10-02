# Testing: baseline and decisions

The method is in [ALPHA-PLAN.md](ALPHA-PLAN.md), section "Testing method". This file holds the measurements it rests on and the decisions they settled. Raw data is under `artifacts/local/test-baseline/` (git-ignored) in the coordinator's worktree.

## Baseline, 2026-10-01, `proto/alpha` at `ffa7f4b`

Machine: 32 threads, load 3 to 15 during the runs. Godot 4.7.2 headless. ACE stems present (24 `.ogg`).

| Measure | Value | How |
| --- | --- | --- |
| Full core-loop suite, 8 at a time | 456 s wall, 219 tests, 0 failed, 0 skipped | scratch runner mirroring `scripts/sketch-smoke.mjs`, per-test timings kept (`base-w8.json`) |
| Split of that wall | import 4 s, pooled 353 s, six solo tests 99 s | same run |
| Summed test time | 2,867 s, median 11.3 s | same run |
| Empty script start | 0.26 s (0.37, 0.26, 0.26) | `godot --headless --script empty.gd` |
| Build `Game`, run 3 frames, quit | 10.2 s (10.1, 11.1, 10.4) | `gamebuild.gd` probe |
| Warm import | 4.8 s | second `--import` in one worktree |
| Checks printed | 1,977 `-> PASS` lines; 23 tests print none | same run |

### Where a Game test's ten seconds go

One probe run with timers around each module (`gameprofile.gd`).

| Step | Time |
| --- | --- |
| Engine start to `_initialize` (script load and compile) | 1.66 s |
| `world` module setup (three maps built) | 1.22 s |
| `combat`, `build`, `boss`, `presentation` setup | 0.10 s together |
| Three frames | under 0.01 s |
| Quit to `_finalize` | 7.04 s |

The 7 seconds at quit are `Audio._exit_tree` waiting for the worker that bakes the whole sound bank (`src/presentation/audio.gd`). A test that never needed the bank still pays for it. 102 of 219 tests take 9 to 12 s, 1,136 s summed, so this wait is the largest single cost in the suite. Unit TA makes the bake abandonable at exit.

### Per-test time bands

| Band | Tests | Summed |
| --- | --- | --- |
| under 2 s | 33 | 18 s |
| 2 to 9 s | 9 | 58 s |
| 9 to 12 s | 102 | 1,136 s |
| 12 to 20 s | 47 | 640 s |
| 20 to 40 s | 20 | 589 s |
| over 40 s | 8 | 425 s |

Slowest: `item_fuzz_smoke` 70.6 s, `char_bot` 66.9 s, `loop_camper` 63.8 s, `presentation_themes` 48.1 s (solo), `char_bot_sable` 47.7 s, `audio_board` 44.3 s, `combat_warden` 43.1 s, `presentation_bass` 41.0 s.

## Shipping flags forced on, same day

Every test launched with `--scrap=armor --wear=on --music=ace --discovery=cards --telegraph=haze --world-one-builds=on --hotwire-shell=on --hotwire-tread=on --harpoon=lock --harpoon-keys=shift` (`flags-w8.json`). 15 of 219 fail, none by timeout.

This count is a lower bound. Launch-phase flags reach only the tests that build a `Game`; a test that builds a bare `Tuning` never saw them. Unit K0 flips the defaults themselves and runs the suite once to find the rest.

| Test | What fails | Kind |
| --- | --- | --- |
| `durability_test`, `hotwire_shell_test` | the "flag off" checks | pins the losing variant |
| `spine_heft_test`, `shop_economy_test`, `build_compaction_test` | parts no longer add heft under armour; purchase compaction | rule changed by design |
| `stage_bay_test`, `ui_workshop_bay_test`, `ui_workshop_shop_test` | pick cadence under world-one builds | rule changed by design |
| `ui_ability_slots_test` | slot keys with the harpoon on | rule changed by design |
| `threat_grammar_test` | fill alphas under haze | rule changed by design |
| `presentation_banner_test` | banner path replaced by cards | pins the losing variant |
| `presentation_bass_test`, `presentation_escalation_test` | the synth band is muted while ACE plays | test must select the synth band it is about |
| `ui_word_budget_test` | 32 HUD words in a stage-1 fight against a budget of 25 | real regression the flags expose |
| `build_power_curve_test` | punch 50 to 64 against bands of 80 to 120 | real balance shift under armour |

The last two are not test debt. They are things the flags break, and they go to their owning units (the objective board and the boss chassis) with the tests kept red-aware, never loosened to pass.

## After wave A0, same day, `proto/alpha` at `364189c`

The wave's one gate run, from the runner's own receipt (`gate-c57bcb8ef631-2026-10-02T02-46-45-369Z.json`, tree `c57bcb8`, 24 stems present, no lock wait).

| Measure | Before | After |
| --- | --- | --- |
| Full suite wall, 8 at a time | 456 s | 339 s |
| Tests run, failed, skipped | 219, 0, 0 | 220, 0, 0 |
| Summed test time | 2,867 s | 2,059 s |
| Median test | 11.3 s | 5.5 s |
| Tests in the 9 to 12 s band | 102 | 12 |
| Tests in the 2 to 9 s band | 9 | 126 |
| Six solo tests | 99 s | 79 s |
| Build `Game`, run 3 frames, quit | 10.2 s | 3.06 s (the writer's probe, three runs) |
| Unit cases, one process | none | 3 cases, 20 checks, 0.7 s |

Summed test time fell 28 percent and the wall 26 percent. What is left is the long tail: 27 tests over 20 s and the six that run one at a time. Nine tests print no verdict line (`ace_restart_state`, `ace_stage_window_grid`, `ace_gentle_break_window`, `drop_cage_frames`, `char_bot_sable`, `char_bot`, `spine_run`, `telegraph_slope`, `wear_fraction_debt`); they pass, and `--strict-verdict` stays off until they are mended or deleted with their variants. (superseded by the section below)

The wave cost one full run for three merged units (0.33 runs per unit) and 27 minutes from launch to verdict.

## After wave A1, `proto/alpha` at `e407e37`

Seven units, one fix round of three, then coordinator fixes. Receipt `gate-5a9b3baf0d9d-2026-10-02T05-54-31-482Z.json` (tree `5a9b3ba`, no lock wait).

| Measure | After A0 | After A1 |
| --- | --- | --- |
| Full suite wall, 8 at a time | 339 s | 323 s |
| Tests run, failed, skipped | 220, 0, 0 | 222, 0, 0 |
| Quarantined red | none | 2 (`build_power_curve_test`, `ui_word_budget_test`) |
| Six solo tests | 79 s | 77 s |
| Lint | none | 0 findings, 88 ms, 22 baseline entries |
| Tests with no verdict line | 9 | 9 |

What the wave cost in gate runs: three full runs for ten units (the first gate, the flag flip's one discovery run, the final gate), so 0.3 runs per unit.

First-gate results, by cause:

| Unit | Result | Cause |
| --- | --- | --- |
| C4 | Gate failed 1 of 222 | `brief`: the test that drives stops with gun kinds was outside the unit's file list |
| C4 | Blasts lost their stop | `brief`: blasts publish under gun kinds and the packet did not say so |
| K0 | A removed check and a loosened bound | `writer`, then `verifier-miss` (the integrator passed them) |
| A2 | Save before load overwrote the disk file | `writer` |
| A2 | Two stores lost the first one's unlocks | `brief` |
| F1 (fix) | The impact record leaked to later strikes for two frames | `writer` |
| F2 (fix) | An upper bound widened, a pin removed unasked | `writer` |

Three of seven units had a review finding of medium or above at the first gate, and two of three fix units failed their review. The flag-flip probe undercounted: launch flags reach only tests that build the whole game, so 15 failures measured became 20 after the defaults changed.

### With the visual branch merged, `proto/alpha` at `ad78651`

One gate run (receipt `gate-f817cf4e1b25-2026-10-02T06-03-11-287Z.json`): 241 runs, 0 failed, 2 quarantined red, 338 s, six solo tests 79 s. The 19 added tests cost 15 s of wall. Eleven tests now print no verdict line. (superseded by the section below)

### After G1 and ST, `proto/alpha` at `2cbdb65`

One gate run for two units (receipt `gate-f600d45526bf-2026-10-02T06-28-52-058Z.json`): 242 runs, 0 failed, 2 quarantined red, 339 s. The unit suite runs 92 checks in 0.7 s; the grammar's 25 are among them. Writers ran named tests only (17 and 28 runs, 42 s and 123 s, no lock). Both units failed review on a reader outside the fence, cause `brief`; neither cost a second gate, because the fixes went onto the unit branches before the merge.

## Decisions the numbers settled

| Question | Decision | Why |
| --- | --- | --- |
| Convert node-free tests to save process starts | No conversion for speed. New pure tests still use the unit format. | A start costs 0.26 s. |
| Skip the import when nothing changed | Not built. | A warm import is 4.8 s per run. |
| Run many Game tests in one process | Not built. | The cost was the exit wait, not the process. TA removes it without giving up isolation. |
| Widen the pool past 8 | Held until TA lands and the baseline is rerun. | The pooled time will change shape. |
| Thresholds | Set as multiples of the post-TA baseline. | Today's 456 s already exceeds the earlier 360 s target. |

## Still to measure

- A cold import in a fresh worktree.
- The suite after TA, then at pool widths 8, 12 and 16.
- Lock wait per run, once the runner records it (unit T1).

### After wave R1a, `proto/alpha` at `abb1f80`

Two gate runs for three units. The first, at `1ce63b7`, failed one test for a real reason: `int_arena_standdown_test` counts every `scrap_collected` in the boss arena, and discovery now pays at a synergy's first firing. Cause `brief`: the discovery burst's scrap was a reader of the change the WY1 packet did not name. The second (receipt `gate-e96b600bfbab-2026-10-02T08-00-36-533Z.json`): 240 runs, 0 failed, 2 quarantined red, 354 s.

All three units failed their first review and took one fix round (cause split: C2 two `brief`, one `env`; WY1 one `writer`, one `brief`; TM one `writer`). TM failed its second review on one point, fixed by the coordinator with a check that fails without the fix.

`loop_camper_test` failed once in a writer's 2-wide run and once in a coordinator's 2-wide run, in two different arms, and passed alone 6 of 6 and in three 8-wide gates. It is load-sensitive and nobody has found why. It tests the drop loop, which unit B0b deletes; until then a red there is rerun alone before it is read.

A SCRIPT ERROR inside a check body left the test's own verdict line reading PASS; the runner's SCRIPT ERROR scan caught it. The check helper should fail the test itself.

### After wave R1b, `proto/alpha` at `ba03120`

One gate run for four units (receipt `gate-c834277ff5d5-2026-10-02T09-18-37-659Z.json`): 244 runs, 0 failed, 2 quarantined red, 448 s.

Two of four units failed their first review, both cause `writer`: a looped sound that outlived its line on a route no check walked (death), and a prompt rule whose tests never reached the code that reads the player. One fix round; the second C1 review failed on one line, fixed by the coordinator with a check that puts a device in front of a pilot who cannot mount.

Three review findings were tests that could not fail: a width check that used the function under test to convert metres to pixels, a level check that equalled its own constants, and a spy that passed on the base code. Each was rewritten to measure independently.

`ui_word_budget_test` reads 34 words against 25 at this head (32 before the prompts). It stays quarantined to the HUD unit in wave R2.

### After unit B0b, `proto/alpha` at `38d852b`

The suite is 233 runs after the loop deletion (244 before): 12 tests and 2 unit cases went with the loops, 2 were added. Gate at b824c6c: 0 failed, 2 quarantined red, 380 s (receipt `artifacts/local/alpha/r1/gate-eba89c45b09e-2026-10-02T09-59-33-588Z.json`). The writer ran the gate twice; the first run failed on four tests the deletion had moved (two pinned hashes, one scripted route, one stage record), all fixed in the unit.

Review failed on cause `writer`: two deleted drop tests also held the only checks that a landing's shockwave strikes the landed body and a bystander. Two more findings were cause `brief`: the packet named two drop-only tests as default-game tests, and its grep acceptance matched Godot's own `loop_mode` properties, so it could not return empty.

For packets: when a unit deletes tests, the packet asks for each deleted test's checks to be listed one by one, with the rule each pinned and where that rule is pinned now.

A smash landing on the Warden is four strikes: a stomp, the shockwave's slam and Rivet's skid slam in one physics frame, then a second stomp when the ball comes down from the rebound (`landing_shockwave_test`). The posture rule counts contacts per frame for this reason.

### After unit B0a, `proto/alpha` at `67c0ecb`

Gate: 235 runs, 0 failed, 2 quarantined red, 340 s (receipt `artifacts/local/alpha/r1/gate-914e0eb535a5-2026-10-02T10-53-43-234Z.json`). The unit adds one unit case (37 checks) and one scene test.

Review passed with notes. Two were cause `writer` (combat relabelled a declined hit as a core hit; a glance exemption the packet did not allow), four were cause `brief` (a wrong statement about the spec, a band with no clock, a field list missing two fields, a forbidden line that contradicted an ordered edit).

The bots measured the rule and found it does not reward growth. That is a design result, not a test failure: the unit's acceptance asked for the numbers, not for a band. A band that gates admission belongs to the bands unit, and it needs bots that repeat: one camper seed won once and stalled on a rerun.

For packets: a rule object with a pure `judge` let the reviewer and the coordinator attack the rule with unit checks in under a second each. Ask for that shape whenever a rule can be separated from the scene.

### After wave R2, `proto/alpha` at `221bb9b`

Gate: 244 runs, 0 failed, 2 quarantined red, 1189 s (receipt `artifacts/local/alpha/r2/receipts/gate-37ddec822b1e-2026-10-02T12-45-42-812Z.json`).

Quarantine changed. `ui_word_budget_test` is green again and left the file: the HUD cut brought a stage-1 fight under its budget. `ui_word_budget_first_find_test` joined it, owner R3: a first find opens its reveal card during a fight.

Review failures by cause, both rounds:

| Unit | Round one | Fix round |
| --- | --- | --- |
| B3 boss plate | FAIL: `writer` (amber leaked onto a posture Warden for each hit flash) | FAIL: `writer` (the new colour scan was dead code) |
| O1 objective board | FAIL: `writer` (LET GO added as a verb) and `brief` (a reader test left out of the file list; a word-budget case primed to pass) | PASS+NOTES |
| C5 enemy state | FAIL: `writer` (the tint change stopped the Warden processing) and `brief` (the star had no cause rule) | FAIL: `writer` (the pulse check could not fail) |
| EN slice packs | PASS+NOTES | PASS+NOTES |

Both fix-round failures were tests that pass with the rule removed, reported as PASS by the writer. From now on a packet asks for the red run by breaking the rule itself, and the report quotes the failing line.

The first gate on the merged build failed twice for real, and both were merge effects no unit could have seen alone. The boss plate seated by the HUD and the armour number together broke the word budget. Moving devices to their own map removed walls a test was leaning on. Named runs after a merge are not a substitute for the gate.

Found while merging: a `SCRIPT ERROR` inside an awaited test coroutine ended the coroutine and the test still exited 0 with no verdict line. The gate lists such tests under "lacks a verdict line"; ten are on that list. Owed: make a missing verdict line a failure, after giving those ten a verdict. (superseded by the section below)

The Sol unit PR reported FAIL on itself for two whole-file hash pins that the brief listed to run but not to edit (cause `brief`). Whole-file hash pins on generated rigs are owed a structural replacement.

The 1189 s is not a regression in the suite. The runner chose a pool of 2 because the machine was at load 37 when it started (two Sol jobs, a map candidate's test run and five scouts), and the app had crashed and killed the previous attempt 54 tests in. On a quiet machine the same suite ran in 445 s an hour earlier (receipt `gate-670fd9eb7eb9`). A gate run should start when the load is low, or the wave should hold its other jobs for it.

### After unit Z3, `proto/alpha` at `94fb9d6`

Gate: 246 runs, 0 failed, 2 quarantined red (`build_power_curve_test`, `ui_word_budget_first_find_test`), 404 s (receipt `gate-a887bec09339-2026-10-02T13-55-04-659Z.json`).

The first gate on the merged map (246 runs, 1002 s on a loaded machine, receipt `gate-19df5e199c5e-2026-10-02T13-33-06-389Z.json`) failed `slice_packs_test` for real: it wanted four packs inside 72 s, and on the Reach a ball that never fights lets the cap fill by 24 s, so the fourth cannot land. A Sol unit saw the same failure on its base, on the old map, so the check was fragile to how fast enemies thin out, not to the map. It now requires the elite third and once before the field is cleared at 30 s, and a fourth pack after, and prints each arrival's time. That print showed the same pack on both sides of the elite: the draw rule let the elite reset its no-repeat memory. Fixed with a unit check that was red on 8 of 20 seeds. Cause of the gate failure: `brief` (the coordinator ran the map's named tests before the gate and left this one out).

Review failures by cause: the winner's Fable review failed it on two `writer` points (gates re-placed and republished their offer on every tick once the ball was past the fixed row; the control run could not fail), and named two `brief` gaps (the slice's event mix, and a device under a line that R2 had since removed).

A measure can ride on a bug. The traversal bars were taken on a spawn that had a misplaced Spillway cache on it; every pilot landed on the cache and rolled off it faster. When R2 moved devices to their own map the same lines measured lower for two pilots with no change to the map. A baseline is retaken on the admission head before a bar is trusted.

`npm test` was red at the R2 admission head: `tests/lab-verdicts.test.js` wants one `verdicts.ndjson` line per playtest entry and entry 11 had none. `check:docs` does not cover it. Two R3a reviewers found it. The coordinator now runs `npm test` before committing a playtest entry.

## A test ends with a verdict (unit HV)

A test passes only if it prints a line matching `<name>: PASS`; new tests use `t.gd`'s `verdict()`. The runner fails a test that exits 0 with neither a verdict line nor a skip line, and prints `no verdict line: the test ended early`. A skip line exempts a test only when no check ran; a `FAIL` verdict fails it whatever the exit code; an error line under a `PASS` verdict fails it too. `scrapkeep test` (`scripts/play.mjs`) uses the same `judge()`. A test that prints the skip line and runs no check is counted as skipped. `--strict-verdict` is still accepted and does nothing more.

Under `--script`, a `SCRIPT ERROR` inside an awaited part of a test (observed with Godot 4.7.2) ends that part, prints the error with its backtrace, and lets the caller carry on, so a test that then calls `quit(0)` exits 0 with its remaining checks never run. The runner's error-line scan already failed that output; the missing-verdict rule fails it a second way, and the runner's unit tests pin both. The same error in a deferred coroutine with no caller waiting leaves the process running until the runner's timeout.

Nine tests were mended: `ace_stage_window_grid`, `ace_restart_state`, `ace_gentle_break_window`, `asset_capture`, `char_bot` (and `char_bot_sable` through it), `graphics_preset`, `spine_run`, `telegraph_slope` and `wear_fraction_debt`. Check counts are unchanged. `spine_run_test` prints its class on its own line and ends on `spine_run_test: PASS`; `char_full_run_test` reads that line with an anchored pattern and accepts trailing text after `PASS`.

### After waves R3a and X2a, `proto/alpha` at `e48f114`

Gate at `e48f114`: 250 runs, 0 failed, 1 quarantined red, 944 s (receipt `gate-4d51d79917cd-2026-10-02T14-45-04-208Z.json`). The machine was loaded by three writers and a capture job.

The first gate on this batch (`8684ea2`, 250 runs, 945 s) failed `ui_boss_plate_mount_test`, which exits 0. Breaking two of the Warden's armour segments within 0.55 s connected `physics_frame` to the same method twice; a signal holds one connection per method whatever is bound to it, so the second flying copy never moved or freed and the engine printed an `ERROR` line. Cause: `writer` (WM), and a `verifier-miss`: the Opus read walked the fragment lifetime for one copy at a time. The unit's own test broke one segment per stagger, so two copies were never in flight together. What caught it was a different test striking every two frames, under the pass rule this same batch added (an error line fails a test at exit 0). A model unit's test now breaks two things at once where the rule allows it.

Review findings by cause, first round then fix round. RV: 5 `writer` and 6 `brief`, then 3 `writer`, 3 `brief` and 1 `env`. HV: 6 `writer` and 7 `brief`, then 2 `writer` and 4 `brief`. SS: 4 `writer` and 5 `brief`, then 4 `writer` and 2 `brief`. More than half of the first-round findings were `brief`: two were fences that made the unit impossible to finish cleanly (a posture count with no public accessor; a parent test outside the file list that parses a child's verdict line).

A check can lock in the fault. RV's fix round added a check that a repeat synergy "stays queued" in banner mode; the ruling was that a repeat draws nothing. The re-review caught it by reading the assertion against the ruling, not by running it.

A tree child's stdout reaches the runner, so a child's `<child>: PASS` line can stand in for its parent's verdict. Not fixed: `judge()` should require the verdict line's name to equal the test's file stem. Owed.

The Sol units' own tests passed in their sandboxes and again on the merged build; none has a rendered check.

### After waves X2b and R3b, `proto/alpha` at `e750d5b`

Gate at `e750d5b`: 260 runs, 0 failed, 1 quarantined red, 505 s (receipt `gate-4d3b49c307cc-2026-10-02T16-30-41-299Z.json`).

Two faults were found at merge, before the gate. `activities_test` reached for the plated brute's plates as a direct child, and the wind-up pose unit had moved them under a rig: a cross-unit break no single unit could see (cause: neither writer; the merge). The cache's slam threshold was in the wrong unit and its test sent strengths the bus never carries; the re-review found it by reading the bus formula (cause: `writer`, and the brief did not name the bus formula, so partly `brief`).

The first gate (`12f2926`, 260 runs, 560 s, receipt `gate-ce1193f29c66-2026-10-02T16-14-12-532Z.json`) failed `find_in_fight_test` on 3 checks: a held card never opened within 60 frames of the Warden's break. A run of the test at each merge point put the cause in the standing activities: the test's inputless ball rolls straight down the spawn launch past the hauler bounty, whose brute wakes and telegraphs, and the telegraph holds the shared calm timer at 3 s. The bounty guards the straight drop to the Warden by design, about 90 m from every pilot's line; the test now clears the activities before its fight (`e750d5b`). Cause: the merge (two units built in parallel on the same map), not either writer.

A test that sends a fact straight to the bus can pass while the game path is dead. Prefer driving the producer (here `player._on_slammed`) so the test carries the value the game would.

The same bot seed is not repeatable across processes: one brawler seed gave a 28.6 s fight in one process and 22.0 s in another. Sweep bands need wide margins until this is found. A Sol unit is diagnosing it.

