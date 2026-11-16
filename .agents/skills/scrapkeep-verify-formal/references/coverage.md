# What the run-flow model covers

Each action in the model (`RunFlow.tla`, in the `models` folder beside this one) stands for the code in this table. When a row's code changes, read the action again before trusting a result.

| Model action | Code | What one step is |
| --- | --- | --- |
| `PressStart` | `sketches/core-loop/src/core/flow.gd` `press_start`; reached from `sketches/core-loop/src/game.gd` `_screen_key` | title or summary to pilot select |
| `PickPilot` | `sketches/core-loop/src/game.gd` `pick_pilot`; `sketches/core-loop/src/presentation/launch_take.gd` `play`, `_begin` | the pick starts the swipe; a busy swipe refuses and drops the callback |
| `TakeCover` with `choose` | the closure in `sketches/core-loop/src/game.gd` `pick_pilot`; `sketches/core-loop/src/core/flow.gd` `choose_class`, `_begin_run`, `enter_stage` | the run starts under full cover |
| `NewRun` | `sketches/core-loop/src/core/flow.gd` `new_run`, `_begin_run`; callers `sketches/core-loop/src/game.gd` `_screen_key` (N on the death screen and summary), `sketches/core-loop/src/game.gd` restart latch (R held for `RESTART_HOLD`, with a store), `sketches/core-loop/src/ui/pause_menu.gd` Restart | a new run from any state in play |
| `ShowTitle` | `sketches/core-loop/src/core/flow.gd` `show_title`; callers `sketches/core-loop/src/ui/screens.gd` `open_camp_from_summary` and `_input` (Escape) | back to the title |
| `Resume` | `sketches/core-loop/src/core/flow.gd` `resume_run` | Continue: the saved run document comes back |
| `QuitRelaunch` | `sketches/core-loop/src/ui/pause_menu.gd` Quit (`get_tree().quit()`), or the window closing, then a fresh start | memory is gone, the saved run document stays; the only way to a Continue with a store |
| `ToBeacon` | `sketches/core-loop/src/core/flow.gd` tick | the ring starts to charge |
| `WardenBroken` | `sketches/core-loop/src/core/flow.gd` `_on_enemy_killed`, `_unseal` | the Warden breaks, the gates open |
| `WardenFreed` | any free of the Warden's node with no kill recorded | the fault `_warden_vanished` exists for |
| `WardenVanished` | `sketches/core-loop/src/core/flow.gd` tick, `_warden_vanished`, `_unseal` | the tick opens a sealed stage with no Warden |
| `GateTaken(launchFirst)` | `sketches/core-loop/src/build/build.gd` `_on_gate_chosen`; `sketches/core-loop/src/core/flow.gd` `_on_reward_chosen`, `_on_launched`, `_play_seam_take`; `sketches/core-loop/src/game.gd` `play_launch_take`, `stamp_launch_take`; `sketches/core-loop/src/presentation/launch_take.gd` `play_over_flight`, `stamp_taken` | one signal emission: the part is granted, flow hears both handlers in either order, the swipe starts |
| `FlightEnds` | `sketches/core-loop/src/core/flow.gd` tick in `LAUNCH`, `_finish_stage` | with no swipe, the flight's end lands the stage |
| `TakeWind`, `TakeHold`, `TakeEnd` | `sketches/core-loop/src/presentation/launch_take.gd` `advance`, `_end` | the swipe's phases; it runs through a pause |
| `TakeCover` with `cut` | `sketches/core-loop/src/core/flow.gd` `_cut_under_cover`, `_finish_stage` | the cut under full cover |
| `Death` | `sketches/core-loop/src/core/flow.gd` `_on_player_died`, `_end_run` | with a store the run ends; without one the death screen shows |
| `Retry` | `sketches/core-loop/src/core/flow.gd` `retry_stage`, `_untake`, `_retry_arena` | store-less flows only: back to the stage's checkpoint. `replay_stage` (T on the death screen) also calls `retry_stage` after moving the stage index; it is not modelled |
| `BossDefeated`, `VictoryEnds` | `sketches/core-loop/src/core/flow.gd` `_on_boss_defeated`, `_end_run_won`, `_end_run` | the boss falls, then the run ends as won |

## Guard constants

| Constant | The guard in the code | At the sync commit |
| --- | --- | --- |
| `UntakeOnRetry` | `retry_stage` calls `_untake` | in place |
| `UntakeOnEnd` | `_end_run` calls `_untake` | in place |
| `UntakeOnNewRun` | `_begin_run` calls `_untake` | in place (added for finding F-1) |
| `VanishGuard` | the tick calls `_warden_vanished` | in place |
| `EndGuard` | `_on_player_died` returns unless `in_play()` | in place |
| `BusyRefuses` | two guards as one: `sketches/core-loop/src/game.gd` `play_launch_take` returns false while the swipe is busy, and `sketches/core-loop/src/presentation/launch_take.gd` `_begin` refuses a busy swipe. Removing only the first does not produce the modelled fault. Visible only with `StageOutlastsSwipe` off. | in place |
| `SwipeOwnsKeys` | `sketches/core-loop/src/game.gd` `_screen_key` and `sketches/core-loop/src/ui/screens.gd` `_input` return early while the swipe is busy | in place |
| `StageOutlastsSwipe` | an assumption, not code: a Warden cannot be broken while a swipe is on screen. A swipe lasts under 3 s (`WIND_S`, `COVER_S`, `HOLD_MAX_S`, `REVEAL_S` in `sketches/core-loop/src/presentation/launch_take.gd`). | assumed |

## Bounds and what is left out

- A world 1 run: two stages, the boss arena, then the summary, as `run_ends_after` gives with the final world set to 1 (the sitting launch). Two runs in one session. A run that goes on to stage 3 after the boss is not modelled.
- `RunLast` is the stage whose launch plays no swipe (`worlds.is_run_last`). It is 6 by default, outside the model, so both world 1 launches play the swipe; `guarded-lastgate` sets it to 2.
- The swipe's word is a part id or 0. The model cannot tell the swipe's own word from no word at all.
- The camp gate's way into a run (`sketches/core-loop/src/game.gd`, the second `launch_take.play` call) is not modelled; it starts the same swipe as a pilot pick.
- The victory lap is folded into the victory state. Stage replay from the death screen and the pilot-select page opened from the death screen are not modelled.
- The arena's retry is one step that restores the checkpoint and stays in the boss state.
- The save is one run document: what the run holds, the stage, and whether the stage is cleared. Profile unlocks and a failed write are not modelled.
- No seconds. The only fact about time is `StageOutlastsSwipe`.
- Part ids are one fresh id per run and stage. Which part, its rarity and its drawing are not modelled.

## Sync commit

The model was last confirmed to describe the code at:

`bbd157f44` (branch w43/new-run-untake, 16 November 2026; before it, `3adc2fd0e`)
