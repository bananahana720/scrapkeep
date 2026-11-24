# What WeaponCadence.tla stands for

`models/WeaponCadence.tla` checks the weapon trigger and cadence state machine (ruling `ek`, PILOT-CADENCE.md sections 2, 3.1, 3.2, 3.5 and 8, Wave 46 unit E1-17): Rivet's single-press revolver cylinder and reload notch (`press`), Sable's tap-spark and hold-charge bolt across ball and mounted pylon (`tap_charge`), Tally's stamp refund bound (`stamp`, `refund <= cost`), play and pause gating, attempt boundaries, interruptions (jam, ultimate, mount/dismount, weapon swap, pause), and proc isolation (`item_proc` / `_proc_volley`). This page maps each step to the code. `scripts/gate/model-receipts.mjs` reads every source path under `sketches/core-loop/src` on this page as the list of covered files, and the last line as the sync commit.

The covered files:

- `sketches/core-loop/src/combat/weapon_driver.gd`: `step`, `_step_press`, `_fire_press_round`, `_update_reload_window`, `_step_tap_charge`, `top_up_cylinder`, `reset`, `interrupt` (`INTERRUPT_ATTEMPT`, `INTERRUPT_ULTIMATE`, `INTERRUPT_MOUNT`, `INTERRUPT_SWAP`), `_switch_weapon`, `_sync_pattern`, and `state_snapshot`.
- `sketches/core-loop/src/combat/combat.gd`: `_physics_process` (`ctx.flow.in_play()` gate and `weapon_driver.step` call), `_proc_volley` and `_fire(..., "item_proc")` (proc isolation), `setup` signal wiring (`skid_smashed` -> `top_up_cylinder`, `run_started` -> `weapon_driver.reset`, `mounted` / `dismounted` -> `INTERRUPT_MOUNT`, `ultimate_started` -> `INTERRUPT_ULTIMATE`, `run_ended`), `_on_stage_entered`, `_on_stage_content_cleared`, `_start_attempt`, `_on_player_died`, `_step_roll_restore`, and `_run_balance`.

## Steps

| Model step | Code |
| --- | --- |
| `InPlayTick`, `OutsidePlay` | combat.gd `_physics_process`: returns immediately when `not ctx.flow.in_play()` or `ctx.run.class_def == null`; Godot scene-tree pause (`paused = TRUE`) stops physics ticks on `Combat` without resetting timers. |
| `StepRivet` | weapon_driver.gd `_step_press`, `_fire_press_round`, `_update_reload_window`: one round per press (`GuardPressNoRepeat`), `FloorTicks` floor, 1-tick input buffer (`BUFFER_S`), 6-round cylinder (`Mag`) entering reload immediately on empty, notch opening on `[WindowOpen, WindowClose]`, early press spending the notch (`GuardEarlyPressSpends`), notch hit shutting cylinder with hot rounds and firing the first immediately (`GuardWindowOnce`), and reload completion restoring plain rounds and firing any buffered press. |
| `TopUpCylinder` | weapon_driver.gd `top_up_cylinder`, called from combat.gd `skid_smashed` and rivet_kit.gd Line Drive: ends a reload immediately with plain rounds, or tops a part-used cylinder to `Mag` while keeping loaded hot rounds ahead of added plain rounds. |
| `StepSable` | weapon_driver.gd `_step_tap_charge`: immediate spark on press, 1-tick input buffer, hold past tap threshold filling charge up to `ChargeMax` (holding at full without decay or auto-fire), and release at `>= 1` firing a charged bolt with `RecoverTicks` post-bolt recover. |
| `StepTally`, `TallyRollRefill` | PILOT-CADENCE.md section 3.5 stamp economics and pattern.gd `MAX_REFUND` clamp (`refund <= cost`), paired with combat.gd `_step_roll_restore` and `_run_balance`: a cast spends `CastCost` (`2` = `1.0` pressure), a PAID stamp inside the beat window refunds `StampRefund` (`1` = `0.5 <= CastCost`), and rolling at cruise refills pressure up to `MaxPressure` (`6` = `3.0`). |
| `ProcVolley` | combat.gd `_proc_volley` -> `_fire(weapon, "item_proc")`: bypasses `weapon_driver` completely (`GuardProcIsolated`), spending no round, opening or spending no window, and leaving reload, charge, buffer, and cooldown untouched. |
| `ToggleJam` | combat.gd `_physics_process` never checks `abilities.jammed()` or `abilities.silenced(WEAPON)` (ability_state.gd `SILENCED` excludes `WEAPON`): a jam pulse never freezes trigger, reload, or charge (`GuardJamNoFreeze`). |
| `TogglePause` | Pause stops `InPlayTick` while keeping driver state frozen; unpause resumes timers to ready within `MaxReadyBound` ticks. |
| `InterruptUltimate` | combat.gd `ultimate_started` -> `weapon_driver.interrupt(INTERRUPT_ULTIMATE)`: clears `_charge`, `_charging`, `_charge_armed`, `_hold_s`, `_lane_painted`, `_buffered` (`GuardInterruptDropsHold`), spends a `waiting` or `open` window, and keeps an active reload running to completion. |
| `InterruptMount` | combat.gd `mounted` / `dismounted` -> `weapon_driver.interrupt(INTERRUPT_MOUNT)` and weapon_driver.gd `_switch_weapon` (`mount_swap` between `arc_caster` and `pylon_turret`): drops charge and buffer with no bolt (`GuardInterruptDropsHold`) while preserving `_cooldown` and `_recover_s`. |
| `SwapWeapon` | weapon_driver.gd `_switch_weapon` (non-mount swap) / `interrupt(INTERRUPT_SWAP)`: drops old trigger state and starts the new weapon at rest (`AtRest`). |
| `BoundaryWired` | combat.gd `_on_stage_entered` (stage entry, stage retry), `_on_stage_content_cleared` (arena entry, arena retry, victory lap), `_on_player_died` (death), and `run_started` (new run, Continue): each calls `weapon_driver.reset()` (`GuardBoundaryReset`). |
| `QuitToTitle` | combat.gd `run_ended` and `flow_changed` (`"summary"`, `"title"`) call `weapon_driver.reset()` (`GuardTitleReset`, WC-1 closed by W46-FIX1 PR #1229). |

## Guards

| Constant | The guard in the code | Config that turns it off | Rule that must break |
| --- | --- | --- | --- |
| `GuardPlayGate` | combat.gd `_physics_process` `if not playing ... return` and Godot pause tree | `weaponcadence-broken-play-gate` | `NoShotOutsidePlay` |
| `GuardBoundaryReset` | combat.gd `_start_attempt`, `_on_player_died`, and `run_started` call `weapon_driver.reset()` | `weaponcadence-broken-boundary-reset` | `RestAfterBoundary` |
| `GuardTitleReset` | combat.gd `run_ended` and `flow_changed` (`"summary"`, `"title"`) call `weapon_driver.reset()` (WC-1 closed by W46-FIX1) | `weaponcadence-broken-title-reset` (`AllowDirectTitleQuit = TRUE`) | `RestAfterBoundary` |
| `GuardJamNoFreeze` | combat.gd `_physics_process` and ability_state.gd `SILENCED` leave weapon trigger unjammed | `weaponcadence-broken-jam-freeze` | `BoundedReadyAfterInterrupt` |
| `GuardInterruptDropsHold` | weapon_driver.gd `interrupt(INTERRUPT_ULTIMATE)` and `interrupt(INTERRUPT_MOUNT)` clear `_charge_armed`, `_charging`, `_charge`, `_buffered` | `weaponcadence-broken-interrupt-hold` | `BoundedReadyAfterInterrupt` |
| `GuardPressNoRepeat` | weapon_driver.gd `_step_press` fires once per press when not sprint-fanning | `weaponcadence-broken-hold-repeat` | `OneVolleyPerPress` |
| `GuardProcIsolated` | combat.gd `_proc_volley` calls `_fire(weapon, "item_proc")` without touching `weapon_driver` | `weaponcadence-broken-proc-touch` | `OneVolleyPerPress` |
| `GuardEarlyPressSpends` | weapon_driver.gd `_step_press` sets `WINDOW_SPENT` on press during `WINDOW_WAITING`; `_update_reload_window` keeps `WINDOW_SPENT` | `weaponcadence-broken-early-mash` | `WindowPaysAtMostOnce` |
| `GuardWindowOnce` | weapon_driver.gd `_step_press` sets `_reloading = false` and `WINDOW_HIT` on notch hit | `weaponcadence-broken-double-notch` | `WindowPaysAtMostOnce` |
| `GuardRefundBound` | PILOT-CADENCE.md section 3.5 stamp refund `<= cost` (pattern.gd `MAX_REFUND`) | `weaponcadence-broken-refund` | `RefundNeverExceedsSpend` |

## Closed finding: WC-1 (closed by W46-FIX1, PR #1229)

**Original defect (E1-17).** Before W46-FIX1, `sketches/core-loop/src/combat/combat.gd` connected `ctx.events.run_ended` only to `_clear_devices()` and did not connect `flow_changed` for `show_title()` or `_close_lap()`. After winning a boss fight or firing/charging during the victory lap (`LAP`) and closing into `SUMMARY` -> `TITLE`, `weapon_driver` kept stale cooldown, cylinder, reload, window, buffer, or charge state.

**Counterexample trace** (`models/weaponcadence-broken-title-reset.cfg`: `AllowDirectTitleQuit = TRUE, GuardTitleReset = FALSE`, 155 distinct states, violates `RestAfterBoundary`):

1. **State 1 (`Init`)**: `flow = "play"`, `weapon = "sable_ball"`, `cooldown = 0`, `AtRest = TRUE`.
2. **State 2 (`StepSable("press_tap")`)**: Sable fires a spark (`last_act = "spark"`, `cooldown = 2`, `flow = "play"`).
3. **State 3 (`QuitToTitle`)**: `flow = "title"`, `just_crossed_boundary = TRUE`, `cooldown = 2` (`AtRest = FALSE`) -> **`RestAfterBoundary` violated** (the same break occurs for Rivet partial `chamber = 1` / `reloading = TRUE` / `hot_rounds > 0` or Sable `charging = TRUE`).

**Closure (`fcaa784b6`, W46-FIX1 PR #1229).** combat.gd now calls `weapon_driver.reset()` in its `run_ended` handler and in `_on_flow_changed` when entering `"summary"` or `"title"`. `weaponcadence-today.cfg` now runs with `AllowDirectTitleQuit = TRUE` and `GuardTitleReset = TRUE` (6,394 distinct states, 0 errors), and `weaponcadence-broken-title-reset.cfg` stays in the plant set as a regression guard.

## Bounds and scaling

- Rivet cylinder `Mag = 2` (models the 6-round cylinder: shot 1 exercises partial cylinder, cooldown, buffer, and mid-cylinder top-up; shot 2 enters reload).
- `FloorTicks = 2`, `BufferTicks = 1` (models 0.20 s / 0.30 s / 0.40 s floors with 0.10 s buffer).
- `ReloadTicks = 4`, `WindowOpen = 2`, `WindowClose = 2` (tick 1 = `waiting` where early press spends the notch; tick 2 = `open` notch; tick 3 = past notch and inside `BufferTicks`; tick 4 = reload completes).
- Sable `RecoverTicks = 1`, `ChargeMax = 2` (0 = under min, 1 = partial `>= 0.25`, 2 = full holding without decay/auto-fire).
- Tally pressure in integer half-units: `MaxPressure = 6` (`3.0`), `CastCost = 2` (`1.0`), `StampRefund = 1` (`0.5`), beat window `[2, 3]`.
- `MaxReadyBound = 4` (`ReloadTicks`).

## Configs

Run plain TLC on each `weaponcadence-*.cfg` with `models/WeaponCadence.tla`.

| Config | Stands for | Must report |
| --- | --- | --- |
| `weaponcadence-today` | every guard in place (including direct quit to title / summary; WC-1 closed) | no break, in at least the pinned 6,394 distinct states |
| `weaponcadence-broken-play-gate` | `GuardPlayGate = FALSE` | `NoShotOutsidePlay` breaks |
| `weaponcadence-broken-boundary-reset` | `GuardBoundaryReset = FALSE` | `RestAfterBoundary` breaks |
| `weaponcadence-broken-title-reset` | `AllowDirectTitleQuit = TRUE, GuardTitleReset = FALSE` (WC-1 regression plant) | `RestAfterBoundary` breaks |
| `weaponcadence-broken-jam-freeze` | `GuardJamNoFreeze = FALSE` | `BoundedReadyAfterInterrupt` breaks |
| `weaponcadence-broken-interrupt-hold` | `GuardInterruptDropsHold = FALSE` | `BoundedReadyAfterInterrupt` breaks |
| `weaponcadence-broken-hold-repeat` | `GuardPressNoRepeat = FALSE` | `OneVolleyPerPress` breaks |
| `weaponcadence-broken-proc-touch` | `GuardProcIsolated = FALSE` | `OneVolleyPerPress` breaks |
| `weaponcadence-broken-early-mash` | `GuardEarlyPressSpends = FALSE` | `WindowPaysAtMostOnce` breaks |
| `weaponcadence-broken-double-notch` | `GuardWindowOnce = FALSE` | `WindowPaysAtMostOnce` breaks |
| `weaponcadence-broken-refund` | `GuardRefundBound = FALSE` | `RefundNeverExceedsSpend` breaks |
| `weaponcadence-reach-*` (13 probes) | reachability probes for plain fire, reload, notch hit, early-press spend, top-up, spark, charged bolt, mount drop, ultimate interrupt, boundary reset, jam-safe fire, proc-no-touch, and stamp-refund | every probe breaks |

## Not modelled

Real-time seconds, float epsilon tolerances, DPS ceilings (checked by weapon_envelope_test.gd), Rivet Overdrive Sprint hold-fanning (checked by weapon_cadence_test.gd), Rivet's 6th hot round 50% pierce chip (weapon_cadence_test.gd), Sable's speed-tier charge multipliers and 3 s mounted plant boost (weapon_cadence_test.gd), mid-run `_sync_pattern` mag resizing (weapon_cadence_test.gd), `hold_auto` rollback parity (weapon_driver_test.gd), future phase E2 trigger modes (`lob_snap`, `beats`, `lock`) and Tally's fractional pressure implementation in combat.gd (Tally's `stamp` economics are modelled directly from PILOT-CADENCE.md section 3.5 and pattern.gd's `MAX_REFUND` bound), proc depth 1 across deferred queues (covered by `models/DeferredEffects.tla`), and anything drawn or heard.

Sync commit: fcaa784b6 (stage/alpha-w46, 23 November 2026, W46-FIX1 PR #1229 merge: sketches/core-loop/src/combat/weapon_driver.gd fixes same-tick buffer aging and reload_rate_mult scaling; sketches/core-loop/src/combat/combat.gd closes WC-1 via weapon_driver.reset() on run_ended and flow_changed summary/title; AllowDirectTitleQuit=TRUE enabled on weaponcadence-today in 6,394 distinct states)


Sync commit: 156b92797 (stage/alpha-w46, 24 November 2026, E2-01 PR #1254 merge: `sketches/core-loop/src/combat/weapon_driver.gd` and `sketches/core-loop/src/combat/combat.gd` add Kest `lob_snap` and Tarn `beats` trigger paths (listed under Not modelled until E2-08 extends `WeaponCadence.tla` to all six pilots); Rivet, Sable, Tally, attempt-boundary, interrupt, and proc-isolation steps are semantically unchanged; independent Neon review r1 verified `weaponcadence-today` in 6,394 distinct states and 10/10 plants caught)
