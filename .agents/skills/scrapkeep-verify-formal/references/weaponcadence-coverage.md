# What WeaponCadence.tla stands for

`models/WeaponCadence.tla` checks the weapon trigger and cadence state machine across all six pilots (ruling `ek`, PILOT-CADENCE.md sections 2, 3.1–3.6 and 8, Wave 46 units E1-17 and E2-08): Rivet's single-press revolver cylinder and reload notch (`press`), Sable's tap-spark and hold-charge bolt across ball and mounted pylon (`tap_charge`), Kest's hold-lob, snap window inside the throw floor, snap hold-lock and Detonation Line snap consumption (`lob_snap`), Tarn's press-only 1->2->3 beat order, Beat 1 combo timeout and Beat 3 window/recovery (`beats`), Tally's fractional-pressure Balance Due, PAID stamp window and `refund <= cost` bound (`stamp`), Cannon's hold-paint closing brackets and Pulse/Rail/Barrage release bands (`lock`), play and pause gating, attempt boundaries, interruptions (jam, ultimate, mount/dismount, weapon swap, pause), and proc isolation (`item_proc` / `_proc_volley`). This page maps each step to the code. `scripts/gate/model-receipts.mjs` reads every source path under `sketches/core-loop/src` on this page as the list of covered files, and the last line as the sync commit.

The covered files:

- `sketches/core-loop/src/combat/weapon_driver.gd`: `step`, `_step_press`, `_fire_press_round`, `_update_reload_window`, `_step_tap_charge`, `_emit_charged_shot`, `arm_instant_max_charge`, `_step_lob_snap`, `commit_lob_throw`, `consume_snap_window`, `notify_lob_charge_gone`, `consume_buffer`, `set_lob_charging`, `_step_beats`, `_step_stamp`, `_make_stamp_shot`, `commit_stamp`, `_step_lock`, `_release_lock`, `top_up_cylinder`, `hot_reload_cylinder`, `reset`, `interrupt` (`INTERRUPT_ATTEMPT`, `INTERRUPT_ULTIMATE`, `INTERRUPT_MOUNT`, `INTERRUPT_SWAP`), `_switch_weapon`, `_sync_pattern`, and `state_snapshot`.
- `sketches/core-loop/src/combat/combat.gd`: `_physics_process` (`ctx.flow.in_play()` gate and `weapon_driver.step` call), `_proc_volley` and `_fire(..., "item_proc")` / `_run_balance(..., "item_proc")` / `_fire_cannon_lane(..., "item_proc")` (proc isolation), `setup` signal wiring (`skid_smashed` -> `top_up_cylinder`, `run_started` -> `weapon_driver.reset`, `mounted` / `dismounted` -> `INTERRUPT_MOUNT`, `ultimate_started` -> `INTERRUPT_ULTIMATE` + `_clear_cannon_paint` + weapon gauge cancel, `run_ended` and `flow_changed` -> `weapon_driver.reset` + `_clear_cannon_paint`), `_on_stage_entered`, `_on_stage_content_cleared`, `_start_attempt`, `_on_player_died`, `_step_sticky_weapon`, `_fire_line`, `_detonate`, `_step_cards`, `_step_roll_restore`, `_run_balance`, `_step_cannon_paint`, `_clear_cannon_paint`, and `_fire_cannon_lane`.

## Steps

| Model step | Code |
| --- | --- |
| `InPlayTick`, `OutsidePlay` | combat.gd `_physics_process`: returns immediately when `not ctx.flow.in_play()` or `ctx.run.class_def == null`; Godot scene-tree pause (`paused = TRUE`) stops physics ticks on `Combat` without resetting timers. |
| `StepRivet` | weapon_driver.gd `_step_press`, `_fire_press_round`, `_update_reload_window`: one round per press (`GuardPressNoRepeat`), `FloorTicks` floor, 1-tick input buffer (`BUFFER_S`), 6-round cylinder (`Mag`) entering reload immediately on empty, notch opening on `[WindowOpen, WindowClose]`, early press spending the notch (`GuardEarlyPressSpends`), notch hit shutting cylinder with hot rounds and firing the first immediately (`GuardWindowOnce`), and reload completion restoring plain rounds and firing any buffered press. |
| `TopUpCylinder`, `HotReloadCylinder` | weapon_driver.gd `top_up_cylinder` (from combat.gd `skid_smashed` and rivet_kit.gd Line Drive) and `hot_reload_cylinder` (from relic_swaps.gd): ends a reload immediately (`top_up_cylinder` with plain rounds, `hot_reload_cylinder` with full hot rounds) or tops up a part-used cylinder to `Mag` while keeping `_hot_rounds <= _chamber` and never firing or paying a window. |
| `StepSable`, `ArmInstantCharge` | weapon_driver.gd `_step_tap_charge`, `_emit_charged_shot`, and `arm_instant_max_charge` (from combat.gd Sable Spire Vault): immediate spark on press, 1-tick input buffer, hold past tap threshold filling charge up to `ChargeMax` (holding at full without decay or auto-fire), Spire Vault instant max-charge on `ARC_CASTER` (cleared on `reset` / `INTERRUPT_ULTIMATE`, decayed or consumed on press/release, ignored on `pylon_turret`), and release at `>= 1` firing a charged bolt with `RecoverTicks` post-bolt recover. |
| `StepKest` | weapon_driver.gd `_step_lob_snap`, `commit_lob_throw`, `consume_buffer`, `set_lob_charging` and combat.gd `_step_sticky_weapon`: tap tail-drop or hold-lob throw arming `LobFloorTicks` (`WindowClose + 1`) throw floor with snap window `[WindowOpen, WindowClose]` strictly inside the floor; press in open window bursts snap once (`GuardSnapOnce`) and sets `_snap_hold_lock` so holding never opens the lob gauge (`GuardSnapHoldLock`); early press before window opens spends it (`GuardEarlyPressSpends`); press near floor end after a spent/hit window buffers the next throw. |
| `KestDetonationLine` | combat.gd `_fire_line` -> weapon_driver.gd `consume_snap_window(tok)` / `_detonate`: takes the snap burst when the caught charge's window is open and marks `WINDOW_HIT` once (`GuardDetLineConsumes`), or detonates plain and clears the window when not open. |
| `KestChargePlainDetonate` | combat.gd `_detonate(charge, false)` -> weapon_driver.gd `notify_lob_charge_gone(tok)`: when a live charge expires on fuse or enemy touch without snapping, clears `WAITING`/`OPEN`/`SPENT` back to `IDLE`. |
| `StepTarn` | weapon_driver.gd `_step_beats`: press-only 1->2->3 combo order (`GuardBeatsNoRepeat`, `GuardBeatsOrder`); Beat 1 starts `FloorTicks` and combo timeout (`BeatTimeoutTicks` -> resets to Beat 0); Beat 2 starts `Beat2FloorTicks` (`WindowClose + 1`) and opens Beat 3 window `[WindowOpen, WindowClose]` strictly inside the floor; early press spends the window (`GuardEarlyPressSpends`); press in open window fires Beat 3 with `FloorTicks` recovery and resets beat to 0; Beat 2 expiry resets to Beat 0 and fires Beat 1 on press or latched buffer. |
| `StepTally`, `TallyRollRefill` | weapon_driver.gd `_step_stamp`, `_make_stamp_shot`, `commit_stamp` and combat.gd `_step_cards`, `_step_roll_restore`, `_run_balance`: Balance Due spends `CastCost` (`2` = `1.0` fractional pressure), opens the beat window `[WindowOpen, WindowClose + 1]` (`[0.40, 0.60]` s), early press spends the window (`GuardEarlyPressSpends`), press-only (`GuardPressNoRepeat`), PAID stamp in open window refunds `StampRefund` (`1` = `0.5 <= CastCost`, `GuardRefundBound`), dry press (`pressure < CastCost`) does not commit, and rolling on the ground at cruise refills fractional pressure up to `MaxPressure` (`6` = `3.0`). |
| `StepCannon` | weapon_driver.gd `_step_lock`, `_release_lock` and combat.gd `_step_cannon_paint`, `_fire_cannon_lane`: press paints the ground lane (tap immediately releases Pulse); hold advances brackets through Pulse (`< WindowOpen`), Rail lock (`[WindowOpen, WindowClose]`), and Barrage (`> WindowClose`, holds without auto-fire); release fires the active band, clears `_lane_painted`, and starts `FloorTicks` recovery with 1-tick input buffer. |
| `ProcVolley` | combat.gd `_proc_volley` -> `_fire(weapon, "item_proc")` / `_run_balance(..., "item_proc")` / `_fire_cannon_lane(..., "item_proc")`: bypasses `weapon_driver` completely (`GuardProcIsolated`), spending no round or pressure, opening or spending no window, and leaving reload, charge, lob gauge, beat, painted lane, buffer, and cooldown untouched. |
| `ToggleJam` | combat.gd `_physics_process` never checks `abilities.jammed()` or `abilities.silenced(WEAPON)` (ability_state.gd `SILENCED` excludes `WEAPON`): a jam pulse never freezes trigger, reload, charge, lob, beats, stamp, or paint (`GuardJamNoFreeze`). |
| `TogglePause` | Pause stops `InPlayTick` while keeping driver state frozen; unpause resumes timers to ready within `MaxReadyBound` ticks. |
| `InterruptUltimate` | combat.gd `ultimate_started` -> `weapon_driver.interrupt(INTERRUPT_ULTIMATE)` + `_clear_cannon_paint()` + weapon gauge cancel: clears `_charge`, `_charging`, `_charge_armed`, `_lob_charging`, `_snap_hold_lock`, `_hold_s`, `_buffered` (`GuardInterruptDropsHold`), clears `_lane_painted` without firing (`GuardLockInterruptClears`), resets `_beat` / `_beat_t` / `_stamp_streak` to 0, spends a `waiting` or `open` window, and keeps an active Rivet reload running to completion. |
| `InterruptMount` | combat.gd `mounted` / `dismounted` -> `weapon_driver.interrupt(INTERRUPT_MOUNT)` and weapon_driver.gd `_switch_weapon` (`mount_swap` between `arc_caster` and `pylon_turret`): drops charge and buffer with no bolt (`GuardInterruptDropsHold`) while preserving `_cooldown` and `_recover_s`. |
| `SwapWeapon` | weapon_driver.gd `_switch_weapon` (non-mount swap) / `interrupt(INTERRUPT_SWAP)`: drops old trigger state and starts the new weapon at rest (`AtRest`). |
| `BoundaryWired` | combat.gd `_on_stage_entered` (stage entry, stage retry), `_on_stage_content_cleared` (arena entry, arena retry, victory lap), `_on_player_died` (death), and `run_started` (new run, Continue): each calls `weapon_driver.reset()` (plus `_clear_devices` / `_clear_cannon_paint`) (`GuardBoundaryReset`). |
| `QuitToTitle` | combat.gd `run_ended` and `flow_changed` (`"summary"`, `"title"`) call `_clear_cannon_paint()` and `weapon_driver.reset()` (`GuardTitleReset`, WC-1 closed by W46-FIX1 PR #1229). |

## Guards

| Constant | The guard in the code | Config that turns it off | Rule that must break |
| --- | --- | --- | --- |
| `GuardPlayGate` | combat.gd `_physics_process` `if not playing ... return` and Godot pause tree | `weaponcadence-broken-play-gate` | `NoShotOutsidePlay` |
| `GuardBoundaryReset` | combat.gd `_start_attempt`, `_on_player_died`, and `run_started` call `weapon_driver.reset()` | `weaponcadence-broken-boundary-reset` | `RestAfterBoundary` |
| `GuardTitleReset` | combat.gd `run_ended` and `flow_changed` (`"summary"`, `"title"`) call `weapon_driver.reset()` (WC-1 closed by W46-FIX1) | `weaponcadence-broken-title-reset` (`AllowDirectTitleQuit = TRUE`) | `RestAfterBoundary` |
| `GuardJamNoFreeze` | combat.gd `_physics_process` and ability_state.gd `SILENCED` leave weapon trigger unjammed | `weaponcadence-broken-jam-freeze` | `BoundedReadyAfterInterrupt` |
| `GuardInterruptDropsHold` | weapon_driver.gd `interrupt(INTERRUPT_ULTIMATE)` and `interrupt(INTERRUPT_MOUNT)` clear `_charge_armed`, `_charging`, `_charge`, `_lob_charging`, `_snap_hold_lock`, `_buffered` | `weaponcadence-broken-interrupt-hold` | `BoundedReadyAfterInterrupt` |
| `GuardLockInterruptClears` | weapon_driver.gd `interrupt(INTERRUPT_ULTIMATE)` sets `_lane_painted = false` and combat.gd calls `_clear_cannon_paint()` without firing | `weaponcadence-broken-lock-stuck` | `BoundedReadyAfterInterrupt` |
| `GuardPressNoRepeat` | weapon_driver.gd `_step_press` and `_step_stamp` fire once per press when not sprint-fanning | `weaponcadence-broken-hold-repeat` | `OneVolleyPerPress` |
| `GuardBeatsNoRepeat` | weapon_driver.gd `_step_beats` checks `pressed` / `_buffered` only and never fires on `held` | `weaponcadence-broken-beats-hold-repeat` | `OneVolleyPerPress` |
| `GuardSnapHoldLock` | weapon_driver.gd `_step_lob_snap` sets `_snap_hold_lock = held` on snap hit and blocks gauge open until release | `weaponcadence-broken-snap-hold-lock` | `OneVolleyPerPress` |
| `GuardProcIsolated` | combat.gd `_proc_volley` calls `_fire` / `_run_balance` / `_fire_cannon_lane` with `"item_proc"` without touching `weapon_driver` | `weaponcadence-broken-proc-touch` | `OneVolleyPerPress` |
| `GuardEarlyPressSpends` | weapon_driver.gd `_step_press`, `_step_lob_snap`, `_step_beats`, and `_step_stamp` set `WINDOW_SPENT` on press during `WINDOW_WAITING` | `weaponcadence-broken-early-mash` | `WindowPaysAtMostOnce` |
| `GuardWindowOnce` | weapon_driver.gd `_step_press` sets `_reloading = false` and `WINDOW_HIT` on notch hit | `weaponcadence-broken-double-notch` | `WindowPaysAtMostOnce` |
| `GuardSnapOnce` | weapon_driver.gd `_step_lob_snap` sets `WINDOW_HIT` on snap hit and combat.gd detonates matching live charge(s) | `weaponcadence-broken-double-snap` | `WindowPaysAtMostOnce` |
| `GuardDetLineConsumes` | weapon_driver.gd `consume_snap_window(tok)` requires `WINDOW_OPEN` and marks `WINDOW_HIT` once | `weaponcadence-broken-detline-double` | `WindowPaysAtMostOnce` |
| `GuardBeatsOrder` | weapon_driver.gd `_step_beats` emits `SHOT_BEAT_3` only from `_beat == 2` with `WINDOW_OPEN` | `weaponcadence-broken-beats-skip` | `WindowPaysAtMostOnce` |
| `GuardRefundBound` | weapon_driver.gd `_make_stamp_shot` / `_sync_pattern` and combat.gd `_step_cards` clamp `refund <= safe_cost` (pattern.gd `MAX_REFUND`) | `weaponcadence-broken-refund` | `RefundNeverExceedsSpend` |

## Closed finding: WC-1 (closed by W46-FIX1, PR #1229)

**Original defect (E1-17).** Before W46-FIX1, `sketches/core-loop/src/combat/combat.gd` connected `ctx.events.run_ended` only to `_clear_devices()` and did not connect `flow_changed` for `show_title()` or `_close_lap()`. After winning a boss fight or firing/charging during the victory lap (`LAP`) and closing into `SUMMARY` -> `TITLE`, `weapon_driver` kept stale cooldown, cylinder, reload, window, buffer, or charge state.

**Counterexample trace** (`models/weaponcadence-broken-title-reset.cfg`: `AllowDirectTitleQuit = TRUE, GuardTitleReset = FALSE`, violates `RestAfterBoundary`):

1. **State 1 (`Init`)**: `flow = "play"`, `weapon = "sable_ball"`, `cooldown = 0`, `AtRest = TRUE`.
2. **State 2 (`StepSable("press_tap")`)**: Sable fires a spark (`last_act = "spark"`, `cooldown = 2`, `flow = "play"`).
3. **State 3 (`QuitToTitle`)**: `flow = "title"`, `just_crossed_boundary = TRUE`, `cooldown = 2` (`AtRest = FALSE`) -> **`RestAfterBoundary` violated** (the same break occurs for any of the six pilots with active cooldown, reload, charge, lob gauge, beat, or painted lane).

**Closure (`fcaa784b6`, W46-FIX1 PR #1229).** combat.gd calls `_clear_cannon_paint()` and `weapon_driver.reset()` in its `run_ended` handler and in `flow_changed` when entering `"summary"` or `"title"`. `weaponcadence-today.cfg` runs with `AllowDirectTitleQuit = TRUE` and `GuardTitleReset = TRUE` across all six pilots (10,122 distinct states, 0 errors), and `weaponcadence-broken-title-reset.cfg` stays in the plant set as a regression guard.

## Note surfaced during E2-08 modelling (non-blocking)

In weapon_driver.gd (`_step_lock`, line 1043), once `_recover_s <= 0.0` while `not _lane_painted`, the driver clears `WINDOW_HIT` to `WINDOW_IDLE` but leaves `WINDOW_SPENT` (set by `interrupt(INTERRUPT_ULTIMATE)` when interrupting a painted Cannon lane at lines 302–303) until the next fire press overwrites `_window_state = WINDOW_WAITING` (line 1051). `state_snapshot().ready` is `true`, `_lane_painted` is `false`, and all six cadence invariants hold; `StepCannon` models this exact shipped behaviour (`IF recNext = 0 /\ window = "hit" THEN "idle" ELSE window`).

## Bounds and scaling

- Rivet cylinder `Mag = 2` (models the 6-round cylinder: shot 1 exercises partial cylinder, cooldown, buffer, and mid-cylinder top-up; shot 2 enters reload).
- `FloorTicks = 2`, `BufferTicks = 1` (models 0.20 s / 0.30 s / 0.40 s / 0.45 s floors and Tarn Beat 3 / Cannon post-release recovery with 0.10 s buffer).
- `ReloadTicks = 4`, `WindowOpen = 2`, `WindowClose = 2` (Rivet reload tick 1 = `waiting`, tick 2 = `open` notch, tick 3 = bufferable past notch, tick 4 = reload completes).
- Sable `RecoverTicks = 1`, `ChargeMax = 2` (0 = under min, 1 = partial `>= 0.25`, 2 = full holding without decay/auto-fire).
- Kest `LobFloorTicks = WindowClose + 1 = 3` (throw floor `0.60` s with snap window `[2, 2]` strictly inside it so the next throw press never snaps by accident; `hold_t \in 0..1` models tail-drop vs lob hold).
- Tarn `BeatTimeoutTicks = FloorTicks + 1 = 3` (Beat 1 combo expires 1 tick after Beat 1 floor), `Beat2FloorTicks = WindowClose + 1 = 3` (Beat 3 window `[2, 2]` strictly inside Beat 2's floor), Beat 3 recovery `FloorTicks = 2`.
- Tally pressure in integer half-units: `MaxPressure = 6` (`3.0`), `CastCost = 2` (`1.0`), `StampRefund = 1` (`0.5`), beat window `[2, 3]` (`[0.40, 0.60]` s).
- Cannon `LockHoldMax = WindowClose + 1 = 3` (`0..1` = Pulse `< 0.30` s, `2` = Rail `[0.30, 0.46]` s, `3` = Barrage `> 0.46` s holding without auto-fire), post-release recovery `FloorTicks = 2`.
- `MaxReadyBound = 4` (`ReloadTicks`).

## Configs

Run plain TLC on each `weaponcadence-*.cfg` with `models/WeaponCadence.tla`.

| Config | Stands for | Must report |
| --- | --- | --- |
| `weaponcadence-today` | all six pilots with every guard in place (including direct quit to title / summary; WC-1 closed) | no break, in 12,415 distinct states (>= pinned 10,122) |
| `weaponcadence-broken-play-gate` | `GuardPlayGate = FALSE` | `NoShotOutsidePlay` breaks |
| `weaponcadence-broken-boundary-reset` | `GuardBoundaryReset = FALSE` | `RestAfterBoundary` breaks |
| `weaponcadence-broken-title-reset` | `AllowDirectTitleQuit = TRUE, GuardTitleReset = FALSE` (WC-1 regression plant) | `RestAfterBoundary` breaks |
| `weaponcadence-broken-jam-freeze` | `GuardJamNoFreeze = FALSE` | `BoundedReadyAfterInterrupt` breaks |
| `weaponcadence-broken-interrupt-hold` | `GuardInterruptDropsHold = FALSE` | `BoundedReadyAfterInterrupt` breaks |
| `weaponcadence-broken-lock-stuck` | `GuardLockInterruptClears = FALSE` | `BoundedReadyAfterInterrupt` breaks |
| `weaponcadence-broken-hold-repeat` | `GuardPressNoRepeat = FALSE` | `OneVolleyPerPress` breaks |
| `weaponcadence-broken-beats-hold-repeat` | `GuardBeatsNoRepeat = FALSE` | `OneVolleyPerPress` breaks |
| `weaponcadence-broken-snap-hold-lock` | `GuardSnapHoldLock = FALSE` | `OneVolleyPerPress` breaks |
| `weaponcadence-broken-proc-touch` | `GuardProcIsolated = FALSE` | `OneVolleyPerPress` breaks |
| `weaponcadence-broken-early-mash` | `GuardEarlyPressSpends = FALSE` | `WindowPaysAtMostOnce` breaks |
| `weaponcadence-broken-double-notch` | `GuardWindowOnce = FALSE` | `WindowPaysAtMostOnce` breaks |
| `weaponcadence-broken-double-snap` | `GuardSnapOnce = FALSE` | `WindowPaysAtMostOnce` breaks |
| `weaponcadence-broken-detline-double` | `GuardDetLineConsumes = FALSE` | `WindowPaysAtMostOnce` breaks |
| `weaponcadence-broken-beats-skip` | `GuardBeatsOrder = FALSE` | `WindowPaysAtMostOnce` breaks |
| `weaponcadence-broken-refund` | `GuardRefundBound = FALSE` | `RefundNeverExceedsSpend` breaks |
| `weaponcadence-reach-*` (21 probes) | reachability probes for plain fire, reload, notch hit, early-press spend, top-up, spark, charged bolt, mount drop, ultimate interrupt, boundary reset, jam-safe fire, proc-no-touch, stamp-refund, kest-throw, kest-snap, kest-detline, tarn-beat3, cannon-pulse, cannon-rail, cannon-barrage, and cannon-interrupt | every probe breaks |

## Not modelled

Real-time seconds, float epsilon tolerances, DPS ceilings (checked by weapon_envelope_test.gd), Rivet Overdrive Sprint and `r_fan_hammer` hold-fanning (checked by weapon_cadence_test.gd), Rivet's 6th hot round 50% pierce chip (weapon_cadence_test.gd), Sable's speed-tier charge multipliers, 3 s mounted plant boost, and `s_static_flutter`'s `_pending_pulses` queue (cleared on `reset`, `INTERRUPT_ULTIMATE`, and `INTERRUPT_MOUNT`; checked by weapon_cadence_test.gd), Kest's multi-charge Cluster scatter sharing one `snap_token` and rocket-jump cooldown non-refresh on snap (weapon_cadence_test.gd), Tarn's Beat 3 planar-speed scaling cap, Clamp multiplier, and `t_saw_flurry`'s Beat-3 window extending past `floor2` (weapon_cadence_test.gd), Tally's Compound Interest streak damage cap and sky-aim ray validity (weapon_cadence_test.gd), Cannon's lane geometry widths/reaches and Walking Lane link (weapon_cadence_test.gd), mid-run `_sync_pattern` mag resizing (weapon_cadence_test.gd), `hold_auto` rollback parity (weapon_driver_test.gd), proc depth 1 across deferred queues (covered by `models/DeferredEffects.tla`), and anything drawn or heard.

Sync commit: fcaa784b6 (stage/alpha-w46, 23 November 2026, W46-FIX1 PR #1229 merge: sketches/core-loop/src/combat/weapon_driver.gd fixes same-tick buffer aging and reload_rate_mult scaling; sketches/core-loop/src/combat/combat.gd closes WC-1 via weapon_driver.reset() on run_ended and flow_changed summary/title; AllowDirectTitleQuit=TRUE enabled on weaponcadence-today in 6,394 distinct states)

Sync commit: 156b92797 (stage/alpha-w46, 24 November 2026, E2-01 PR #1254 merge: `sketches/core-loop/src/combat/weapon_driver.gd` and `sketches/core-loop/src/combat/combat.gd` add Kest `lob_snap` and Tarn `beats` trigger paths)

Sync commit: a4a17dcea (stage/alpha-w46, 24 November 2026, E2-02 PR #1255 merge: `sketches/core-loop/src/combat/weapon_driver.gd` and `sketches/core-loop/src/combat/combat.gd` implement Tally `stamp` fractional-pressure Balance Due and Cannon `lock` hold-paint lane branches)

Sync commit: 659c4597a (stage/alpha-w46, 24 November 2026, E2-08: `WeaponCadence.tla` expanded to all six pilots — Rivet `press`, Sable `tap_charge`, Kest `lob_snap`, Tarn `beats`, Tally `stamp`, and Cannon `lock` — matching shipped `sketches/core-loop/src/combat/weapon_driver.gd` and `sketches/core-loop/src/combat/combat.gd`; `weaponcadence-today` clean in 10,122 distinct states, 16/16 plants caught, 21/21 reachability probes broken)

Sync commit: 3f2081799 (stage/alpha-w46, 24 November 2026, E2-09 PR #1261 merge: `sketches/core-loop/src/combat/weapon_driver.gd` and `sketches/core-loop/src/combat/combat.gd` wire the 12 Depth-1 opposite-feel weapon keystones and `brass_drum`/`heavy_breech` pattern fields; no modelled cadence transition or invariant changed — `weaponcadence-today` clean in 10,122 distinct states, 16/16 plants caught, 21/21 reachability probes broken)

Sync commit: 4657692058523576912f6adeaf30d560a6ffa8c9 (25 November 2026, Phase 3 formal maintenance: updated `WeaponCadence.tla` to model `hot_reload_cylinder` (`HotReloadCylinder`) and Sable Spire Vault `arm_instant_max_charge` / `_instant_charge_left` (`ArmInstantCharge`, cleared in `reset` and `INTERRUPT_ULTIMATE`, decayed or consumed on `ARC_CASTER` press/release); documented `recoil_airborne` Cannon rail width/overpenetration and Rivet `sixth_hot` tag; updated shifted line citations in the E2-08 note after Phase 2 `/no-comments`; `weaponcadence-today` clean in 12,415 distinct states, 16/16 plants caught)

Sync commit: d30d3dcc1d9fbbb5963a67e7101923ffe415bc0c (26 November 2026, cross-unit sync on main: of the covered files only combat.gd changed, adding 0.12 s `_special_buffer` / `_line_buffer` / `_active_buffer` (cleared via `_clear_input_buffers()` on all run/attempt/interrupt boundaries; weapon trigger untouched), `actives.lock_remaining()`, and World 2 `march_lane` overdrive in `_cannon_lane_plan` / `_fire_cannon_lane` (`weapon_driver`, `_step_cannon_paint` lock bands, `_proc_volley` proc isolation, jam non-freeze, interrupts, and boundary resets unchanged); in sync)
