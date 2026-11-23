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
| `QuitToTitle` | flow.gd `show_title()`: after `death`, `_on_player_died` has already reset `weapon_driver`. From a boss win or victory lap close without death, see Finding WC-1 below. |

## Guards

| Constant | The guard in the code | Config that turns it off | Rule that must break |
| --- | --- | --- | --- |
| `GuardPlayGate` | combat.gd `_physics_process` `if not playing ... return` and Godot pause tree | `weaponcadence-broken-play-gate` | `NoShotOutsidePlay` |
| `GuardBoundaryReset` | combat.gd `_start_attempt`, `_on_player_died`, and `run_started` call `weapon_driver.reset()` | `weaponcadence-broken-boundary-reset` | `RestAfterBoundary` |
| `GuardTitleReset` | `QuitToTitle` from play/win resets `weapon_driver` (missing in combat.gd today; see WC-1) | `weaponcadence-broken-title-reset` (`AllowDirectTitleQuit = TRUE`) | `RestAfterBoundary` |
| `GuardJamNoFreeze` | combat.gd `_physics_process` and ability_state.gd `SILENCED` leave weapon trigger unjammed | `weaponcadence-broken-jam-freeze` | `BoundedReadyAfterInterrupt` |
| `GuardInterruptDropsHold` | weapon_driver.gd `interrupt(INTERRUPT_ULTIMATE)` and `interrupt(INTERRUPT_MOUNT)` clear `_charge_armed`, `_charging`, `_charge`, `_buffered` | `weaponcadence-broken-interrupt-hold` | `BoundedReadyAfterInterrupt` |
| `GuardPressNoRepeat` | weapon_driver.gd `_step_press` fires once per press when not sprint-fanning | `weaponcadence-broken-hold-repeat` | `OneVolleyPerPress` |
| `GuardProcIsolated` | combat.gd `_proc_volley` calls `_fire(weapon, "item_proc")` without touching `weapon_driver` | `weaponcadence-broken-proc-touch` | `OneVolleyPerPress` |
| `GuardEarlyPressSpends` | weapon_driver.gd `_step_press` sets `WINDOW_SPENT` on press during `WINDOW_WAITING`; `_update_reload_window` keeps `WINDOW_SPENT` | `weaponcadence-broken-early-mash` | `WindowPaysAtMostOnce` |
| `GuardWindowOnce` | weapon_driver.gd `_step_press` sets `_reloading = false` and `WINDOW_HIT` on notch hit | `weaponcadence-broken-double-notch` | `WindowPaysAtMostOnce` |
| `GuardRefundBound` | PILOT-CADENCE.md section 3.5 stamp refund `<= cost` (pattern.gd `MAX_REFUND`) | `weaponcadence-broken-refund` | `RefundNeverExceedsSpend` |

## Open finding: WC-1 (combat.gd does not reset `weapon_driver` on `run_ended` or `show_title()`)

**Where.** `sketches/core-loop/src/combat/combat.gd` line 617 connects `ctx.events.run_ended` only to `_clear_devices()` and does not call `weapon_driver.reset()`. combat.gd does not connect `flow_changed` for `show_title()` (flow.gd line 392) or `_close_lap()` (flow.gd line 1297).

**What happens.** After winning a boss fight without entering the victory lap (`BOSS` -> `VICTORY` -> `_end_run(true)` -> `SUMMARY` -> `open_camp_from_summary()` -> `show_title()`), or after firing or charging during the victory lap (`LAP`, where `flow.in_play()` is true) and letting `_close_lap()` end the lap into `SUMMARY` -> `show_title()`, `weapon_driver` is not reset to rest. Its `state_snapshot()` still carries the last run's non-zero cooldown, partial cylinder, active reload, hot rounds, open/spent window, buffer, or charge while on `SUMMARY` and `TITLE`.

**Mitigation today.** Because combat.gd `_physics_process` gates on `ctx.flow.in_play()`, no shot can fire on `VICTORY`, `SUMMARY`, or `TITLE`, and starting a new run or Continue (`run_started` + `stage_entered`) calls `weapon_driver.reset()` before play resumes. However, PILOT-CADENCE.md section 2.3 requires quit to title to put the trigger at rest immediately, and any reticle or UI inspecting `weapon_driver.state_snapshot()` on `SUMMARY` or `TITLE` would read stale trigger state.

**Counterexample trace** (`models/weaponcadence-broken-title-reset.cfg`: `AllowDirectTitleQuit = TRUE, GuardTitleReset = FALSE`, 155 distinct states, violates `RestAfterBoundary`):

1. **State 1 (`Init`)**: `flow = "play"`, `weapon = "sable_ball"`, `cooldown = 0`, `AtRest = TRUE`.
2. **State 2 (`StepSable("press_tap")`)**: Sable fires a spark (`last_act = "spark"`, `cooldown = 2`, `flow = "play"`).
3. **State 3 (`QuitToTitle`)**: `flow = "title"`, `just_crossed_boundary = TRUE`, `cooldown = 2` (`AtRest = FALSE`) -> **`RestAfterBoundary` violated** (the same break occurs for Rivet partial `chamber = 1` / `reloading = TRUE` / `hot_rounds > 0` or Sable `charging = TRUE`).

**Fix (for a follow-up code unit, outside E1-17's fence).** Call `weapon_driver.reset()` in combat.gd's `run_ended` handler and on `flow_changed` when entering `"title"` or `"summary"`; then set `AllowDirectTitleQuit = TRUE` and `GuardTitleReset = TRUE` on `weaponcadence-today` and re-pin its state count.

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
| `weaponcadence-today` | every guard in place (wired boundaries + title after death; WC-1 left out until fixed) | no break, in at least the pinned 6,388 distinct states |
| `weaponcadence-broken-play-gate` | `GuardPlayGate = FALSE` | `NoShotOutsidePlay` breaks |
| `weaponcadence-broken-boundary-reset` | `GuardBoundaryReset = FALSE` | `RestAfterBoundary` breaks |
| `weaponcadence-broken-title-reset` | `AllowDirectTitleQuit = TRUE, GuardTitleReset = FALSE` (live WC-1 finding) | `RestAfterBoundary` breaks |
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

Sync commit: 4976cc02d (stage/alpha-w46, 23 November 2026, E1-17: initial WeaponCadence.tla model covering sketches/core-loop/src/combat/weapon_driver.gd and sketches/core-loop/src/combat/combat.gd)
