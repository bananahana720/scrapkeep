# What DeferredEffects.tla stands for

`models/DeferredEffects.tla` checks what combat holds now and fires later, the follow-up procs that fire at once, the shot bits a bolt carries through a split or a bounce, and the exposure marks drawn on an enemy, across every attempt boundary the run flow makes: a stage entry or retry, an arena entry, arena retry or victory lap, a new run or Continue, a death and a quit to the title. This page maps each step to the code. `scripts/gate/model-receipts.mjs` reads every source path on this page as the list of covered files, and the last line as the sync commit. Its findings are in [deferred-findings.md](deferred-findings.md).

The covered files:

- `sketches/core-loop/src/combat/combat.gd`: `_physics_process` (its `in_play` gate), the queues `_rakes`, `_aftershocks`, `_bells`, `_strips`, `_echo`, `_cast_pending`, `_bite_pending`, `_deferred_procs` (with `_draining_procs` 1-deep guard in `deal_proc_hit` and `_step_deferred_procs`), `_det_cord_queue` (with `_enqueue_det_cord`, `_step_det_cord`, and `_reset_grapple_muts_state`), the records `_pike_count`, `_guards`, `_heated`, `_exposed`, the boundary handlers `_on_stage_entered`, `_on_stage_content_cleared`, `_start_attempt`, `_on_player_died` and the `run_started` handler in `setup`, and the procs (`_fire`, `_pike_press`, `fused_bits`, `rake_follows`, `_tick_rakes`, `_on_fault_slammed`, `_tick_aftershocks`, `_aftershock`, `_ring_bell`, `_toll`, `_tick_echo`, `_lay_strip`, `_step_verb_items`, `_on_reel_chain`, `_proc_volley`, `_evolve_record`, `_drop_exposed`, `_clear_exposed`, `_step_cannon_exposure`, `_door_caps`, the died handler in `spawn_enemy`).
- `sketches/core-loop/src/combat/damage_door.gd`: `in_pass()` and `_depth` around `pass_hit`, plus `dead()` used by `_step_deferred_procs()`.
- `sketches/core-loop/src/combat/bolts.gd`: `fire`, `child`, `split_spent`, `split_children`, `bit_ready`, `step`, `_glance`, and `_flip_boomerang`.
- `sketches/core-loop/src/combat/effects.gd`: `clear`, which `_clear_fight` calls, and `live_mark_count` (P7), which the stress capture reads.
- `sketches/core-loop/src/build/shot_bits.gd`: the five bits, `MAX_SHOT_BITS` and the pair rows.
- `sketches/core-loop/src/core/flow.gd`: `in_play`, and the signals each boundary emits (`stage_entered` from `enter_stage` and `retry_stage`, `stage_content_cleared` from `enter_boss`, `_retry_arena` and the victory lap, `run_started` from `_begin_run` and `resume_run`).

## Steps

| Model step | Code |
| --- | --- |
| `Ticking` | combat `_physics_process`: `if not playing or ctx.run.class_def == null: return`, where `playing` is `flow.in_play()` (STAGE, BEACON, GATES, LAUNCH, BOSS, LAP). The clock, every queue, the bolts and the exposure rows move only after it (`TickInPlay`) |
| `EnterStage` | `stage_entered` -> `_on_stage_entered` -> `_start_attempt`, from a stage entrance (`enter_stage`) or a retry (`retry_stage`) |
| `ContentCleared` | `stage_content_cleared` -> `_on_stage_content_cleared` -> `_start_attempt`, from the arena entry, its retry and the victory lap |
| `NewRun` | `run_started` (its handler clears the same records and `_free_cannon` the marks), then the entrance's `stage_entered` (or, for a cleared doc, `_finish_stage`'s next entrance or the arena's clear), in one call |
| `StartAttempt` | `_start_attempt`: `_clear_fight` frees every enemy (and every mark, a child of its enemy) and calls `bolts.clear()` (`AttemptClearsBolts`); `_deferred_procs.clear()` (`AttemptClearsDefProc`, `452f5c0ac`); `_reset_grapple_muts_state(true)` clears `_det_cord_queue` (`AttemptClearsDetCord`); `_guards.clear()` (`AttemptClearsGuards`, P7); `_echo = {}` (`AttemptClearsEcho`); `_rakes`, `_clear_aftershocks()`, `_heated`, `_clear_exposed()`; `_cast_pending = {}`, `_bite_pending = false` (`AttemptClearsCast`, P7); `_pike_count = 0`, `_pike_last = -INF` (`AttemptClearsPike`); `_clear_verb_items()` (strips, bells) |
| `Death` | `player_died` -> `_on_player_died` (P7, `f47d3e6f1`): `_line_load`, `_cast_pending`, `_bite_pending`, `_clear_verb_items`, `_reset_grapple_muts_state` (`_det_cord_queue`), `_clear_aftershocks`, `_rakes`, `_deferred_procs.clear()`; then flow leaves play (DEAD, or SUMMARY with a store). The echo, the pike count, the guards, heat, the exposure rows and the bolts stay, frozen by the gate, until the next boundary clears them |
| `ToTitle` | `show_title`: nothing combat clears; the gate freezes everything until the next run's boundary |
| `Press` | `_fire(weapon, "weapon")`: the build's shot bits (`_shot_bits()`), a Rake Heart return queued (`rake_follows`), the Slag Pike count advanced (`_pike_press`), and on the fuse one pierce bolt (`pike_bolt`, `fused_bits`) |
| `ProcVolley` | `_proc_volley` -> `_fire(weapon, "item_proc")`: `shot = 0` (`ProcCarriesNoBits`), no rake (`RakeNeedsWeapon`), no pike step (`PikeNeedsWeapon`), and `_evolve_record` gives a proc bolt no hoar |
| `Slam`, `ShockLands` | `_on_fault_slammed` (returns outside play) queues an aftershock; `_tick_aftershocks` -> `_aftershock` strikes as `item_proc` and publishes no slam fact (`ShockBare`) |
| `Special`, `EchoFires`, `BellTolls` | `_step_special`'s release arms `_echo` (Twin Discharge) and `_ring_bell` (Second Bell); `_land_tap` rings the bell for a SPECIAL tap. `_tick_echo` calls `row.fire` alone, never the release path (`EchoBare`); `_toll` never reaches `_ring_bell` (`TollBare`) |
| `Dash`, `StripStrikes` | Backwash: `_on_wake_dash` -> `_lay_strip` (strikes at once); `_step_verb_items` strikes what enters a live strip and drops it at its `until` |
| `CastBegins`, `CastLands` | `_tap` with a cast time sets `_cast_pending`; `_step_cast` lands it through `_land_tap` |
| `BiteLoads`, `BiteFires` | `grapple_fired` -> `_bite_load` sets `_bite_pending`; `_step_line` fires the loaded line skill |
| `ReelChain` | Barbed Reel: `_on_reel_chain` -> `_chain` with one jump, `item_proc`; it emits no `harpoon_smashed` (`ReelBare`) |
| `QueueDefProc`, `DefProcFires` | `deal_proc_hit` during `door.in_pass()` appends to `_deferred_procs` (dropping nested calls while `_draining_procs` is true: `DrainStopsNestProc`, `f47d3e6f1`); `_step_deferred_procs()` inside `_physics_process` clears if dead, sets `_draining_procs = true`, skips `DamageDoor.dead(enemy)`, and calls `_hit` |
| `DetCordQueues`, `DetCordFires` | `_on_grapple_released_muts` (gated by `in_play()`) -> `_enqueue_det_cord` appends to `_det_cord_queue`; `_step_det_cord` inside `_physics_process` drains due nodes as `item_proc` and `on_blast("det_cord")` without re-enqueueing (`DetCordBare`) |
| `RakeFires` | `_tick_rakes` -> `_rake_return`: bolts straight through `bolts.fire` with `bits = 0`, `item_proc` |
| `PikeRead` | `pike_advance` reads `_pike_count` and `_pike_last` on the next press |
| `GuardLink`, `GuardUnlink` | the guard links in `_guards` (linker and partner by instance id) |
| `BoltHits` | `bolts.step`'s hit loop: a ready split throws two children (`split_children`) and spends split; each child is `child()` (the parent's bits, never more) with `spent = split_spent(parent)` (split and pull on, pierce off: `ChildSpendsSplit`, `ChildSpendsPull`) and `hoar` and `hoar_spared` erased (`ChildDropsHoar`); the pierce bit lets the parent fly on once; heat marks the machine (`_heated`); pull acts while ready |
| `BoltWall` | `_glance`: a ready bounce reflects the bolt and spends bounce (`BounceSpends`); any other wall stops it |
| `Spawn`, `Expose` | an enemy enters the fight; `_cannon_expose` / `_arc_mark` set the row and reuse or add the enemy's own `CannonExposure` / `ArcMark` child |
| `Lapses`, `DropExpired` | `_clock` passes `until`; `_step_cannon_exposure` drops an expired row (or one whose enemy is gone) through `_drop_exposed`, mark and all |
| `ContactRead` | `_door_caps`: a contact hit that reads an expired row drops it through `_drop_exposed` (`ContactDropsMark`, P7) |
| `FoeDies`, `CorpseFreed` | the died handler in `spawn_enemy`: `_heated.erase`, `_drop_exposed(id)` and the arc key (`DeathDropsMark`, P7); the body is freed later, with every child |

## Guards

| Constant | The guard in the code | Config that turns it off | Rule that must break |
| --- | --- | --- | --- |
| `TickInPlay` | `_physics_process` returns outside play | `deferred-broken-ungated` | `NoEchoAcrossAttempt` |
| `AttemptClearsEcho` | `_start_attempt`: `_echo = {}` (F002) | `deferred-broken-keepecho` | `NoEchoAcrossAttempt` |
| `AttemptClearsCast` | `_start_attempt`: `_cast_pending`, `_bite_pending` (P7) | `deferred-broken-keepcast` | `NoEchoAcrossAttempt` |
| `AttemptClearsGuards` | `_start_attempt`: `_guards.clear()` (P7) | `deferred-broken-keepguards` | `NoEchoAcrossAttempt` |
| `AttemptClearsPike` | `_start_attempt`: `_pike_count`, `_pike_last` | `deferred-broken-keeppike` | `NoEchoAcrossAttempt` |
| `AttemptClearsBolts` | `_clear_fight`: `bolts.clear()` | `deferred-broken-keepbolts` | `NoEchoAcrossAttempt` |
| `AttemptClearsDefProc` | `_start_attempt`: `_deferred_procs.clear()` (`452f5c0ac`) | `deferred-broken-keepdefproc` | `NoEchoAcrossAttempt` |
| `AttemptClearsDetCord` | `_start_attempt` -> `_reset_grapple_muts_state`: `_det_cord_queue.clear()` | `deferred-broken-keepdetcord` | `NoEchoAcrossAttempt` |
| `RakeNeedsWeapon` | `rake_follows`: `source == "weapon"` | `deferred-broken-rakeproc` | `ProcDepthOne` |
| `PikeNeedsWeapon` | `_pike_press`: `source != "weapon"` returns | `deferred-broken-pikeproc` | `ProcDepthOne` |
| `ProcCarriesNoBits` | `_fire`: a proc volley carries no shot bits | `deferred-broken-procbits` | `ProcDepthOne` |
| `EchoBare` | `_tick_echo` calls `row.fire` alone | `deferred-broken-echoagain` | `ProcDepthOne` |
| `TollBare` | `_toll` never reaches `_ring_bell` | `deferred-broken-tollagain` | `ProcDepthOne` |
| `ShockBare` | `_aftershock` publishes no slam fact | `deferred-broken-shockagain` | `ProcDepthOne` |
| `ReelBare` | `_on_reel_chain`'s jump emits no `harpoon_smashed` | `deferred-broken-reelagain` | `ProcDepthOne` |
| `DrainStopsNestProc` | `deal_proc_hit`: `if _draining_procs: return` inside `door.in_pass()` (`f47d3e6f1`) | `deferred-broken-nestproc` | `ProcDepthOne` |
| `DetCordBare` | `_step_det_cord` fires as `item_proc` without re-enqueueing `_det_cord_queue` | `deferred-broken-detcordagain` | `ProcDepthOne` |
| `ChildSpendsSplit` | `split_spent`: split on | `deferred-broken-childsplit` | `ShotBitsCap` |
| `ChildSpendsPull` | `split_spent`: pull on | `deferred-broken-childpull` | `ShotBitsCap` |
| `ChildDropsHoar` | `split_children`: `kid.erase("hoar")`, `kid.erase("hoar_spared")` | `deferred-broken-childhoar` | `ShotBitsCap` |
| `BounceSpends` | `_glance`: bounce spent | `deferred-broken-rebounce` | `ShotBitsCap` |
| `PikeCapsBits` | `fused_bits`: a full set drops its last bit for pierce | `deferred-broken-pikebits` | `ShotBitsCap` |
| `ContactDropsMark` | `_door_caps` drops through `_drop_exposed` (P7; it erased the row and left the mark before) | `deferred-broken-contactmark` | `ShotBitsCap` |
| `DeathDropsMark` | the died handler drops through `_drop_exposed` (P7) | `deferred-broken-deathmark` | `ShotBitsCap` |

The clears `_on_player_died` makes, `run_started`'s own clears and `_on_fault_slammed`'s `in_play` check have no constant: the gate freezes everything a death or a quit leaves, and every way back into play passes `_start_attempt`, so no rule can see one of them fail (VFM-04). They are defence in depth.

## Assumptions and bounds

- Each queue holds one waiting item: the items of one queue never act on each other, so one stands for all. A queued item is "fresh" in the attempt that made it and "old" once a boundary passes over it.
- One bolt lineage is followed: at a split the model follows the parent or one child (they are copies). The shot sets are {pierce, split, pull} and {bounce, split, heat}: between them every pair row of shot_bits.gd that names a split, a pierce, a pull, a bounce or a heat, and the second is full, so a pike fuse must drop a bit. `HoarHeld` is on.
- One enemy carries the exposure rows and marks; a cannon exposure and an arc mark behave alike, so one row stands for both. `_clear_fight` frees every enemy, corpses included.
- Two attempt boundaries a behaviour (`MaxAtt`).

## Configs

Run `bash models/make-deferred-configs.sh`, then plain TLC on each `deferred-*.cfg` with `DeferredEffects.tla`.

| Config | Stands for | Must report |
| --- | --- | --- |
| `deferred-today` | the code at the sync commit | no break, 9,955,877 distinct states (>= pinned 2,196,005) |
| `deferred-broken-*` | one guard off, as the Guards table lists | the named rule breaks |
| `deferred-reach-*` | one probe per step (43): every boundary, act, deferred step (including `QueueDefProc`, `DefProcFires`, `DetCordQueues`, `DetCordFires`), bolt outcome and mark step, a pike fuse, a child with hoar dropped, and the echo, pike count and a bolt kept frozen over a death | the probe breaks |

`node scripts/gate/model-receipts.mjs --out <dir> --row deferred-effects-safe` writes the receipt from `deferred-today` and the twenty pinned plants (`make-deferred-configs.sh` also emits four additional plants for `_deferred_procs` and `_det_cord_queue`).

## Not modelled

Seconds and geometry (which machine a strip, ring or bolt reaches), damage numbers, `MAX_LIVE` bolt eviction, weapon-only `extra_bounces` (bounded to `MAX_EXTRA_BOUNCES = 2`, never granted to `item_proc`, tested by `sketches/core-loop/tests/synergies_test.gd` — `ShotBits.bounce` still glances once via `BounceSpends`), `boomerang_spool` (`_flip_boomerang` returns once and strips `bits`, `spent`, `chain_jumps`, `extra_bounces`, and `sixth_hot` to `item_proc`, tested by `sketches/core-loop/tests/w50_isaac_parts_test.gd`), the upgrade tree's own procs (`_on_proc_fact`; `UpgradeTree.problems` refuses a build whose actions lead back to their trigger), the sentry, cloud, marks and pulses `_start_attempt` also clears, the boss's own adds, and anything drawn. `sketches/core-loop/tests/w45_combat_formal_fixes_test.gd` plays P7's clears and mark drops in the running game.

Sync commit: 86421447a (stage/alpha-w46, 22 November 2026, E1-01 PR #1212 merge: of the covered files only `sketches/core-loop/src/combat/combat.gd` changed, delegating the `_physics_process` weapon trigger loop and card-cast recovery to weapon_driver.gd in `hold_auto` mode (0 behaviour change, 20/20 Mac run hashes bit-identical); `in_play()`, all deferred queues, `_fire()`, `_proc_volley()`, `enemy_struck.emit` and attempt-boundary clears are semantically unchanged, with line spans shifted +7..+15 (`setup` 475, `spawn_enemy` 681, `_door_caps` 849, `_physics_process` 1723, `_fire` 1858, `_on_player_died` 5316, `_on_stage_content_cleared` 5331, `_start_attempt` 5339). Before it, ff49868cf (stage/alpha-w46, 22 November 2026, W46-T3 PR #1205 merge: of the covered files only scrap_field.gd changed, adding `static func reset_for_tests()` called only by test_batch_driver.gd between warm-batch tests; no combat queue, bolt step or attempt-boundary clear changed. Before it, f57fa1cff (stage/alpha-w46, 22 November 2026, W46-13 PR #1206 merge: of the covered files only `sketches/core-loop/src/combat/effects.gd` changed, setting `mat.vertex_color_is_srgb = true` in `setup()`. `clear` and `live_mark_count` and every attempt-boundary or proc queue are unchanged, so no modelled step changed; Neon review r1 verified `deferred-today` in 2,196,005 distinct states and 20/20 plants caught. Before it, 747c6bda4 (branch w46/08-shift-variants, 22 November 2026, W46-08 fix round 1: of the covered files only `sketches/core-loop/src/core/flow.gd` changed, calling `ShiftVariants.on_stage_retry(ctx.run)` in `retry_stage` after `ctx.run.restore()` and passing `gate != null and gate.yard_ahead()` into `ShiftVariants.wakes_warden` in `physics_step`. `in_play()` and every attempt-boundary signal (`stage_entered`, `stage_content_cleared`, `run_started`) are unchanged, so no modelled step changed. Before it, 1b050f4c2 (branch w46/08-shift-variants, 22 November 2026, W46-08: of the covered files only `sketches/core-loop/src/core/flow.gd` changed, consulting shift_variants.gd in `stage_def`, `stage_look_id`, `_begin_run`, `physics_step` and `_on_enemy_killed`. `in_play()` and every attempt-boundary signal (`stage_entered`, `stage_content_cleared`, `run_started`) are unchanged, so no modelled step changed. Before it, 02e8934b5 (branch w46/t2-warm-resets, 22 November 2026, W46-T2: of the covered files only `sketches/core-loop/src/core/flow.gd` changed, adding read-only `trace_snapshot()` for band_trace.gd. `in_play()` and every attempt-boundary signal are unchanged, so no modelled step changed. Before it, fbe0770da (stage/alpha-w46, 22 November 2026, PR #1181 perf merge: `sketches/core-loop/src/combat/combat.gd`, `sketches/core-loop/src/combat/effects.gd` and scrap_field.gd gain empty-queue guards, idle `set_process(false)` sleeps, a distant-spin skip and `cast_shadow` off; a Gemini 4 Neon review of the merge found no modelled path changed. Before it, 93e3431d4 (branch w45/p9-earned-save-two-refusals, 21 November 2026, P9: only `sketches/core-loop/src/core/flow.gd` changed since e362998b2: `_owed_entrance` and `_flush_save_spend` keep an owed earned-save spend across refused tombstones and restarts; `in_play()` and the boundary signals `stage_entered`, `stage_content_cleared` and `run_started` are unchanged. Before it, e362998b2)))))))

Sync commit: fcaa784b6 (stage/alpha-w46, 23 November 2026, W46-FIX1 PR #1229 merge: of the covered files only `sketches/core-loop/src/combat/combat.gd` changed, calling `weapon_driver.reset()` on `run_ended` and on `flow_changed` for `"summary"` and `"title"` to close WC-1; `in_play()`, all deferred queues, `_fire()`, `_proc_volley()`, `enemy_struck.emit` and attempt-boundary clears are unchanged. Before it, 242cd20d1 (E1-06 PR #1220 merge))

Sync commit: ff23d9dec (stage/alpha-w46, 23 November 2026, E1-16 PR #1236 merge and Gate Note 1: of the covered files only `sketches/core-loop/src/combat/bolts.gd` changed, adding visual-only side-muzzle drawn origin and smoothstep merge onto the true ray over 4.0 m; fire, child, split_spent, split_children, bit_ready, step collision rays, _glance, ShotBits and clear semantics are unchanged, so no modelled step changed)

Sync commit: 8bf28d182 (stage/alpha-w46, 23 November 2026, E1-09b PR #1244 merge: of the covered files only `sketches/core-loop/src/combat/bolts.gd` changed, widening visual-only `RIVET_MUZZLE_SIDE_M` from 0.60 m to 1.26 m to match Rivet's heroic cutaway side-sponson rotary cannons plus two comments; fire, child, split_spent, split_children, bit_ready, step collision rays, _glance, ShotBits and clear semantics are unchanged, so no modelled step changed)


Sync commit: 156b92797 (stage/alpha-w46, 24 November 2026, E2-01 PR #1254 merge: of the covered files only `sketches/core-loop/src/combat/combat.gd` changed, adding Kest `lob_snap` gauge/tail-drop/snap/Detonation-Line wiring and Tarn `beats` strike/knock/range wiring; `in_play()`, all deferred queues, `_fire()`, `_proc_volley()`, proc depth 1, and attempt-boundary clears are semantically unchanged, with line spans shifted (`spawn_enemy` 702, `_door_caps` 871, `_physics_process` 1747, `_fire` 1931, `_proc_volley` 5047, `_on_player_died` 5525, `_on_stage_content_cleared` 5540, `_start_attempt` 5548); independent Neon review r1 verified `deferred-today` in 2,196,005 distinct states and 20/20 plants caught)


Sync commit: a4a17dcea (stage/alpha-w46, 24 November 2026, E2-02 PR #1255 merge: of the covered files only `sketches/core-loop/src/combat/combat.gd` changed, adding Tally `stamp` fractional-pressure Balance Due and Cannon `lock` hold-paint lane branches; `_proc_volley` fires plain Tally Balance Due / plain Cannon Pulse without touching `weapon_driver`, pressure, paint, or starting secondary procs, so `in_play()`, all deferred queues, proc depth 1, and attempt-boundary clears are semantically unchanged)

Sync commit: 3f2081799 (stage/alpha-w46, 24 November 2026, E2-09 PR #1261 merge: of the covered files only `sketches/core-loop/src/combat/combat.gd` changed for the 12 Depth-1 weapon keystones and `brass_drum`/`heavy_breech` pattern fields; all new `_fire` keystone fields stay gated on `source == "weapon"`, leaving `"item_proc"` plain and depth 1; `deferred-today` clean in 2,196,005 distinct states, 20/20 plants caught)

Sync commit: 4657692058523576912f6adeaf30d560a6ffa8c9 (25 November 2026, Phase 3 formal maintenance: added `sketches/core-loop/src/combat/damage_door.gd` to covered files and updated `DeferredEffects.tla` + `make-deferred-configs.sh` to model `Combat._deferred_procs` + `_draining_procs` (`452f5c0ac`, `f47d3e6f1`) and `Combat._det_cord_queue` (`8ba5cf46b`) with four new guards (`AttemptClearsDefProc`, `DrainStopsNestProc`, `AttemptClearsDetCord`, `DetCordBare`), plants, and reach probes; documented weapon-only `extra_bounces` (`MAX_EXTRA_BOUNCES = 2`) and `_flip_boomerang` in bolts.gd, plus Phase 2 `/no-comments`; `deferred-today` clean in 9,955,877 distinct states, 24/24 plants caught)

Sync commit: d30d3dcc1d9fbbb5963a67e7101923ffe415bc0c (26 November 2026, cross-unit sync on main: of the covered files only combat.gd changed, adding 0.12 s `_special_buffer` / `_line_buffer` / `_active_buffer` (cleared via `_clear_input_buffers()` on `run_ended`, `flow_changed` summary/title, `run_started`, `ultimate_started`, `_on_player_died`, and `_start_attempt`), `actives.lock_remaining()`, and World 2 `march_lane` overdrive in `_cannon_lane_plan` / `_fire_cannon_lane` (weapon-only walked link reach/damage scaling, never `"item_proc"`); `in_play()`, all deferred queues, `_fire()`, `_proc_volley()`, proc depth 1, shot bits, exposure marks, and attempt-boundary clears are unchanged; in sync)
