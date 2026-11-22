# What BrindleReel.tla stands for

`models/BrindleReel.tla` checks that Admiral Brindle keeps pressing, slowed, while a strong build has him reeling across all three hull phases (ruling `ed`, W1-139d and W1-139g), without ever dropping a tell below the 0.6 s fairness floor, committing inside a phase transition beat, or dropping an already-cued follow-up attack. This page maps each step to the code. `scripts/gate/model-receipts.mjs` reads every source path on this page as the list of covered files, and the last line as the sync commit.

The covered files: `sketches/core-loop/src/boss/boss.gd` (the fight loop, reel cadence, transition guard, slag reprise and Scuttle charge state machine) and `sketches/core-loop/src/boss/boss_rules.gd` (the reel cadence, gap clamp and phase-floor constants).

## Steps

| Model step | Code |
| --- | --- |
| `Held`, `Reeling` | `_held()` (`_chunks_lost() >= phase`) and `reeling()` (`_held() and not _in_transition()`) in Brindle's fight controller |
| `TurnPhase` | `_maybe_turn_phase()` and `_enter_phase()`: advances phase 1 -> 2 -> 3 -> 4 (`_begin_eject()`) once `_chunks_lost() >= phase` and `phase_clock >= Rules.PHASE_MIN_SECONDS[phase - 1]`, starting a `FightPhases.TRANSITION_SECONDS` beat in phases 2 and 3 |
| `BreakChunk` | `on_struck()`, `judge_hit()` and `_apply_posture()` chunk shatter while `not _in_transition()`, paired with reel-entry timer clamping in `_step_furnace()` (phase 2, clamping `_next_attack` to `clock + Rules.REEL_SLAG_PERIOD` while preserving any already-cued `_reprise`) and `_step_charges()` (phase 3, clamping `CHARGE_REST` timer to `REEL_MAX_GAP`) |
| `StepPhase1` | `_step_cranes()` and `_commit_crane()`: commits crane sweeps at slowed reel cadence `minf(base_period * Rules.REEL_PERIOD_MULT, Rules.REEL_MAX_GAP)` with `ChallengeDials.tell("brindle", Rules.CRANE_WARN, Hazard.MIN_WARN)` (`>= 0.6 s`) |
| `StepPhase2` | `_step_furnace()`, `_step_reprise()` and `_commit_slag()`: waits out the transition beat, honours any already-cued reprise at `FightPhases.CUED_WARN` (`0.6 s`), and commits ball-targeted reel slag rings every `Rules.REEL_SLAG_PERIOD` (`3.0 s`) with full `Rules.SLAG_WARN` (`2.5 s`) |
| `StepPhase3` | `_step_charges()`, `_commit_charge()` and `_run_charge()`: steps `CHARGE_REST` -> `CHARGE_BRACE` -> `CHARGE_RUN` -> `CHARGE_HOOK` / `CHARGE_RECOVER` / `CHARGE_STUN`, keeping slowed `REEL_PERIOD_MULT` rest clamped to `Rules.REEL_MAX_GAP`, continuing hook turns during reels with `FightPhases.CUED_WARN` (`0.6 s`), and pausing the gap clock during an earned `CHARGE_STUN` |
| `StepChase` | `_begin_eject()` and `_step_scooter()`: phase 4 scooter chase after the third hull chunk and phase 3 floor complete |

## Ticks and seconds

One model tick is 1 s (`MaxReelGap = 6` stands for the 6 s promise from W1-139g, with code clamping reel intervals to `REEL_MAX_GAP = 5.5 s` and `REEL_SLAG_PERIOD = 3.0 s`). Tells are recorded in tenths of a second (`MinTellTenths = 6` stands for `0.6 s`, `ChallengeDials.TELL_FLOOR` and `FightPhases.CUED_WARN`). `PhaseFloor = 12` shortens the real `PHASE_MIN_SECONDS` (`[28, 24, 22] s`) to keep the state space compact while leaving room for multiple reel cycles past `MaxReelGap`. Real-time seconds, dial overrides (`brindle.period_mult`), and the 7 s quiet-reel plant are checked by `sketches/core-loop/tests/brindle_reel_test.gd`.

## Configs

| Config | Stands for | Must report |
| --- | --- | --- |
| `brindlereel-today` | every reel cadence, clamp, transition and cued-promise guard in place | no break, in at least the pinned 635 distinct states |
| `brindlereel-broken-stop` | Brindle stops committing attacks during a reel (`ReelAttacks = FALSE`) | `NoLongReelGap` breaks |
| `brindlereel-broken-unclamped` | Phase 2 carries an 8 s normal slag timer into a reel (`ClampPhase2Reel = FALSE`) | `NoLongReelGap` breaks |
| `brindlereel-broken-shorttell` | cued follow-up draws a 0.4 s tell (`TellGuard = FALSE`) | `TellFloor` breaks |
| `brindlereel-broken-transition` | attack commits inside the phase transition beat (`RespectTransition = FALSE`) | `NoTransitionCommit` breaks |
| `brindlereel-broken-dropcue` | entering a reel drops an already-cued follow-up (`KeepCuedPromise = FALSE`) | `CuedPromiseKept` breaks |

## Not modelled

Phase 1 reel-entry clamping under elevated `brindle.period_mult` dials (in `_step_cranes()`, checked by `sketches/core-loop/tests/brindle_reel_test.gd`; the model uses fixed `CraneNormal = 2 < CraneReel = 4`), 3D arena geometry, ball physics, aim lead, knockback arcs, crane scrap theft and trail placement, `_reel_sear` armour shedding, lobber drones, the phase 4 chase scooter, and anything drawn or heard (including the W1-105 harmless reprise preview ring, the W1-106 hull crouch, BowRam glow and `charge_warn` animation clip on the Requisition hull, and `FightPhases` transition and cue helpers). Those are covered by `sketches/core-loop/tests/brindle_reel_test.gd`, `sketches/core-loop/tests/boss_telegraph_test.gd`, `sketches/core-loop/tests/boss_lead_line_test.gd`, `sketches/core-loop/tests/brindle_charge_turn_test.gd`, and `sketches/core-loop/tests/brindle_phase_preview_test.gd`.

Sync commit: 02e8934b5 (branch w46/t2-warm-resets, 22 November 2026, W46-T2: of the covered files only `sketches/core-loop/src/boss/boss.gd` changed, adding read-only `trace_snapshot()` for band_trace.gd. Boss phase cadence, reel clamps, transition guards and cued follow-ups are unchanged, so no modelled step changed. Before it, ea640a583 (branch w46/05-brindle-presses, 22 November 2026, W46-05 fix round 2: jump_to_phase(1) chunk restore in boss.gd; boss.gd and boss_rules.gd match BrindleReel.tla))
