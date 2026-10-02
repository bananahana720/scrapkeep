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

Summed test time fell 28 percent and the wall 26 percent. What is left is the long tail: 27 tests over 20 s and the six that run one at a time. Nine tests print no verdict line (`ace_restart_state`, `ace_stage_window_grid`, `ace_gentle_break_window`, `drop_cage_frames`, `char_bot_sable`, `char_bot`, `spine_run`, `telegraph_slope`, `wear_fraction_debt`); they pass, and `--strict-verdict` stays off until they are mended or deleted with their variants.

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

One gate run (receipt `gate-f817cf4e1b25-2026-10-02T06-03-11-287Z.json`): 241 runs, 0 failed, 2 quarantined red, 338 s, six solo tests 79 s. The 19 added tests cost 15 s of wall. Eleven tests now print no verdict line.

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

