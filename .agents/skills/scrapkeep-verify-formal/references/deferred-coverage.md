# What DeferredEffects.tla stands for

`models/DeferredEffects.tla` checks what combat holds now and fires later, the follow-up procs that fire at once, the shot bits a bolt carries through a split or a bounce, and the exposure marks drawn on an enemy, across every attempt boundary the run flow makes: a stage entry or retry, an arena entry, arena retry or victory lap, a new run or Continue, a death and a quit to the title. This page maps each step to the code. `scripts/gate/model-receipts.mjs` reads every source path on this page as the list of covered files, and the last line as the sync commit. Its findings are in [deferred-findings.md](deferred-findings.md).

The covered files:

- `sketches/core-loop/src/combat/combat.gd`: `_physics_process` (its `in_play` gate), the queues `_rakes`, `_aftershocks`, `_bells`, `_strips`, `_echo`, `_cast_pending`, `_bite_pending`, the records `_pike_count`, `_guards`, `_heated`, `_exposed`, the boundary handlers `_on_stage_entered`, `_on_stage_content_cleared`, `_start_attempt`, `_on_player_died` and the `run_started` handler in `setup`, and the procs (`_fire`, `_pike_press`, `fused_bits`, `rake_follows`, `_tick_rakes`, `_on_fault_slammed`, `_tick_aftershocks`, `_aftershock`, `_ring_bell`, `_toll`, `_tick_echo`, `_lay_strip`, `_step_verb_items`, `_on_reel_chain`, `_proc_volley`, `_evolve_record`, `_drop_exposed`, `_clear_exposed`, `_step_cannon_exposure`, `_door_caps`, the died handler in `spawn_enemy`).
- `sketches/core-loop/src/combat/bolts.gd`: `fire`, `child`, `split_spent`, `split_children`, `bit_ready`, `step` and `_glance`.
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
| `StartAttempt` | `_start_attempt`: `_clear_fight` frees every enemy (and every mark, a child of its enemy) and calls `bolts.clear()` (`AttemptClearsBolts`); `_guards.clear()` (`AttemptClearsGuards`, P7); `_echo = {}` (`AttemptClearsEcho`); `_rakes`, `_clear_aftershocks()`, `_heated`, `_clear_exposed()`; `_cast_pending = {}`, `_bite_pending = false` (`AttemptClearsCast`, P7); `_pike_count = 0`, `_pike_last = -INF` (`AttemptClearsPike`); `_clear_verb_items()` (strips, bells) |
| `Death` | `player_died` -> `_on_player_died` (P7): `_line_load`, `_cast_pending`, `_bite_pending`, `_clear_verb_items`, `_clear_aftershocks`, `_rakes`; then flow leaves play (DEAD, or SUMMARY with a store). The echo, the pike count, the guards, heat, the exposure rows and the bolts stay, frozen by the gate, until the next boundary clears them |
| `ToTitle` | `show_title`: nothing combat clears; the gate freezes everything until the next run's boundary |
| `Press` | `_fire(weapon, "weapon")`: the build's shot bits (`_shot_bits()`), a Rake Heart return queued (`rake_follows`), the Slag Pike count advanced (`_pike_press`), and on the fuse one pierce bolt (`pike_bolt`, `fused_bits`) |
| `ProcVolley` | `_proc_volley` -> `_fire(weapon, "item_proc")`: `shot = 0` (`ProcCarriesNoBits`), no rake (`RakeNeedsWeapon`), no pike step (`PikeNeedsWeapon`), and `_evolve_record` gives a proc bolt no hoar |
| `Slam`, `ShockLands` | `_on_fault_slammed` (returns outside play) queues an aftershock; `_tick_aftershocks` -> `_aftershock` strikes as `item_proc` and publishes no slam fact (`ShockBare`) |
| `Special`, `EchoFires`, `BellTolls` | `_step_special`'s release arms `_echo` (Twin Discharge) and `_ring_bell` (Second Bell); `_land_tap` rings the bell for a SPECIAL tap. `_tick_echo` calls `row.fire` alone, never the release path (`EchoBare`); `_toll` never reaches `_ring_bell` (`TollBare`) |
| `Dash`, `StripStrikes` | Backwash: `_on_wake_dash` -> `_lay_strip` (strikes at once); `_step_verb_items` strikes what enters a live strip and drops it at its `until` |
| `CastBegins`, `CastLands` | `_tap` with a cast time sets `_cast_pending`; `_step_cast` lands it through `_land_tap` |
| `BiteLoads`, `BiteFires` | `grapple_fired` -> `_bite_load` sets `_bite_pending`; `_step_line` fires the loaded line skill |
| `ReelChain` | Barbed Reel: `_on_reel_chain` -> `_chain` with one jump, `item_proc`; it emits no `harpoon_smashed` (`ReelBare`) |
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
| `RakeNeedsWeapon` | `rake_follows`: `source == "weapon"` | `deferred-broken-rakeproc` | `ProcDepthOne` |
| `PikeNeedsWeapon` | `_pike_press`: `source != "weapon"` returns | `deferred-broken-pikeproc` | `ProcDepthOne` |
| `ProcCarriesNoBits` | `_fire`: a proc volley carries no shot bits | `deferred-broken-procbits` | `ProcDepthOne` |
| `EchoBare` | `_tick_echo` calls `row.fire` alone | `deferred-broken-echoagain` | `ProcDepthOne` |
| `TollBare` | `_toll` never reaches `_ring_bell` | `deferred-broken-tollagain` | `ProcDepthOne` |
| `ShockBare` | `_aftershock` publishes no slam fact | `deferred-broken-shockagain` | `ProcDepthOne` |
| `ReelBare` | `_on_reel_chain`'s jump emits no `harpoon_smashed` | `deferred-broken-reelagain` | `ProcDepthOne` |
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
| `deferred-today` | the code at the sync commit | no break, 2,196,005 distinct states |
| `deferred-broken-*` | one guard off, as the Guards table lists | the named rule breaks |
| `deferred-reach-*` | one probe per step (39): every boundary, act, deferred step, bolt outcome and mark step, a pike fuse, a child with hoar dropped, and the echo, pike count and a bolt kept frozen over a death | the probe breaks |

`node scripts/gate/model-receipts.mjs --out <dir> --row deferred-effects-safe` writes the receipt from `deferred-today` and the twenty plants.

## Not modelled

Seconds and geometry (which machine a strip, ring or bolt reaches), damage numbers, `MAX_LIVE` bolt eviction, the upgrade tree's own procs (`_on_proc_fact`; `UpgradeTree.problems` refuses a build whose actions lead back to their trigger), the sentry, cloud, marks and pulses `_start_attempt` also clears, the boss's own adds, and anything drawn. `sketches/core-loop/tests/w45_combat_formal_fixes_test.gd` plays P7's clears and mark drops in the running game.

Sync commit: e362998b2 (branch stage/alpha-w45, 21 November 2026, FV-3: the model written from this commit, after P7 a12e9adf3 added `_on_player_died`, `_guards`, `_cast_pending` and `_bite_pending` to `_start_attempt`, `_drop_exposed` and `_clear_exposed`, every waiting aftershock's ring and the Second Bell's `breaks_props`)
