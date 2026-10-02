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
