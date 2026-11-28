# Structure survey: combat
commit: 23e935514ef33e7eb58d50e21bd2a5f757f41fa9   model: Gemini 4 Neon (high)   files read: 113   date: 2026-11-27

## Module map
sketches/core-loop/src/combat/combat.gd | 7609 | combat entry node, spawner API, DamageDoor resolution, weapon/special/line loops, Tally & Cannon kits, grapple mutations, consumables runtime, W47 micro/cross/hero hooks | 187 vars (`_patterns`, `_shred`, `_guards`, `_ledger`, `_exposed`, `_cards`/`_ink`, `_cannon`/`_cannon_piton`, `_det_cord_queue`/`_active_grapple_slots`, `_consumable_drops`/`_memo_frozen`, `_beachhead_pylon`, `_primed`) | `src/game.gd`, `src/combat/relic_swaps.gd`, `src/combat/tarn_claw.gd`, `src/combat/rivet_kit.gd`, `src/combat/ultimate.gd`
sketches/core-loop/src/combat/rivet_kit.gd | 1760 | Rivet pilot kit (rail ride, haul, line punch, volume indicator, terrain-carved slam geometry and set-piece beats) | 43 vars (`volume_indicator`, `rail_ride`, `haul`, `_cached_rails`, `pulses`, `_convex_cache` static) | `src/combat/combat.gd`, `src/combat/ultimate.gd`, `src/combat/codex_entries.gd`
sketches/core-loop/src/combat/threat_grammar.gd | 1606 | shared threat types (`INSTANT`, `WAVE`, `PROJECTILE`, `LANE`), stance/colour rules, shader-driven painter and landing flash | 0 instance vars; 6 static cache/state vars (`_stripes`, `_held_looks`, `_look`, `_materials`, `materials_built`, `_warmed`) | `src/combat/telegraph.gd`, `src/boss/hazard.gd`, 33 other `src/combat/` and `src/boss/` files
sketches/core-loop/src/combat/weapon_driver.gd | 1209 | trigger, cadence, magazine/reload, charge/beat/window state machine and read-only reticle snapshot | 69 vars (`_weapon`, `_trigger`, `_cooldown`, `_recover_s`, `_mag`, `_hot_rounds`, `_beat`, `_buffered`) | `src/combat/combat.gd`, `src/combat/warden_reactor.gd`
sketches/core-loop/src/combat/warden.gd | 1124 | stage Warden enemy: posture fight, pulse/counter attacks, dynamic family driver loading (`warden_<family>.gd`), hardpoints and guard link | 60 vars (`family`, `guard`, `_posture`, `_look`, `_kit`, `_charging`, `_pulse_clock`, `pulses`, `counters`) | `src/combat/combat.gd`, `src/presentation/hero_assets.gd`, `src/boss/waking_dress.gd`, `src/boss/mind_dress.gd`
sketches/core-loop/src/combat/orbital_satellites.gd | 1090 | W50 orbital satellite actors, slag zones, storm charges and W50 cross-synergy procs | 21 vars (`_orbit_angle`, `_satellite_positions`, `_satellite_hit_cd`, `slag_zones`, `storm_charges`, `_satellite_mm`) | `src/combat/combat.gd`
sketches/core-loop/src/combat/enemy.gd | 1085 | base `CharacterBody3D` for all enemies: HP, plating, armour class, knock/wall-slam, rally, ring-out, tint/flash, telegraphs and clip/gait/pose hooks | 81 vars (`kind`, `hp`, `max_hp`, `plating`, `_knock`, `_flash`, `_telegraph`, `_atk`, static `rim_color`, `_ring_out_kept`) | `src/combat/counter.gd` (and 29 Counter subclasses), `src/combat/combat.gd`, `src/combat/chaser.gd`, `src/combat/warden.gd`
sketches/core-loop/src/combat/ultimate.gd | 1078 | ultimate meter, set-piece planner, flight/windup/peak/landing state machine and Sable/Cannon set-piece execution | 47 vars (`meter`, `_phase`, `_left`, `_plan`, `_id`, `_leg`, `_leg_time`, `_beat_len`, `_record`, `_ult_rows`) | `src/combat/combat.gd`, `src/combat/kest_kit.gd`, `src/combat/rivet_kit.gd`, `src/combat/tarn_claw.gd`, `src/combat/stakes.gd`
sketches/core-loop/src/combat/relic_swaps.gd | 928 | W50 relic slot swaps (Voltaic, Fan Burst, Tape Echo, Thermite, Auger, Seam, Whirl) hooked into combat's special/line tables | 19 vars (`_clock`, `_glide_left`, `_fan_shot_index`, `_arc_chords`, `_halos`, `_fan_queue`, `_augers`, `_seams`, `_whirls`) | `src/combat/combat.gd`
sketches/core-loop/src/combat/ally_husk.gd | 856 | Tally Ghost-Shift ally husks: wreck ledger, husk raising, severance, autonomous attacks and Mind takeover interruption | 13 vars (`wrecks`, `husks`, `raises_total`, `severance_total`, `strikes_total`, `takeovers_*`) | `src/combat/combat.gd`, `src/boss/mind.gd`, `src/combat/mind_hand.gd`
sketches/core-loop/src/combat/tarn_claw.gd | 765 | Tarn pilot kit (claw drag, tow, clamp hurl, beat-3 lunge, rake strips, pendulum guard and set-piece legs) | 23 vars (`drag`, `tow`, `hurls`, `rake_shapes`, `seized`, `clamp_hurls`, `beat3_lunge`, `pendulum_guard`) | `src/combat/combat.gd`, `src/combat/codex_entries.gd`
sketches/core-loop/src/combat/dispatcher.gd | 685 | Dispatcher special enemy: perch mast, cargo pod drops, add escalation and cargo flush/return counters | 36 vars (`drops`, `escalation`, `adds`, `perch_top`, `mast`, `_pod`, static `_shared`, `_warmed`) | `src/combat/roster_specials.gd`, `src/core/beacon.gd`, `src/presentation/bake_warm.gd`
sketches/core-loop/src/combat/miniboss.gd | 668 | stage miniboss: leap slam and charge phases, weak windows and phase-based plating | 34 vars (`state`, `phase`, `attacks`, `weak_windows`, `_leap_from`, `_leap_to`, static `_shared`, `_hazard_stripe`) | `src/combat/combat.gd`, `src/combat/rogue.gd`, `src/world/camp_sandbox.gd`
sketches/core-loop/src/combat/kest_kit.gd | 646 | Kest pilot kit (extends `ultimate.gd`): demolition payloads, cable tether/burst, mines, roll/volley set-piece legs | 20 vars (`payloads`, `cable`, `_loaded_cable`, `_cable_burst`, `_groups`, `_mines`, `_rolls`, `roll_log`, `volley_log`) | `src/combat/combat.gd`, `src/combat/codex_entries.gd`
sketches/core-loop/src/combat/bolts.gd | 639 | player projectile pool (cap 64), MultiMesh rendering, crowd fade, bounce/pierce/heat shot-bit flight and hit callbacks | 12 vars (`_bolts`, `_multimesh`, `on_hit`, `on_shell`, `on_stop`, `on_bounce`, `on_flight`, static `_outline_shader`) | `src/combat/combat.gd`, `src/combat/effects.gd`
sketches/core-loop/src/combat/foreman.gd | 638 | Foreman special enemy: crew claiming, rally horn syncs and overtime whistle/interrupt state | 29 vars (`crew`, `wipes`, `horns`, `syncs`, `_overtime_active`, static `_shared`, `_sockets`, `_sync_ring_mesh`) | `src/combat/roster_specials.gd`, `src/combat/codex_entries.gd`, `src/presentation/bake_warm.gd`
sketches/core-loop/src/combat/rogue.gd | 612 | Rogue crane/skip/tender event bosses: site fitting, phase attacks, anthem cues and weak windows | 35 vars (`row`, `phase`, `state`, `attack`, `site_scale`, `weak_windows`, static `_model_warned`) | `src/combat/combat.gd`, `src/core/content_registry.gd`, `src/core/death_cause.gd`, `src/presentation/audio.gd`
sketches/core-loop/src/combat/plated_brute.gd | 590 | Plated Brute counter enemy: layered armour plates, bounty carry, charge crashes and elite affix attacks | 35 vars (`plates`, `plates_popped`, `slams`, `charges`, `affix`, `_absorb`, static `_shared`, `_mask`) | `src/combat/fleet.gd`, `src/combat/codex_entries.gd`, `src/presentation/bake_warm.gd`
sketches/core-loop/src/combat/chaser.gd | 578 | Chaser baseline enemy: pack pressure stalking, lane lunge, ledge vaulting and air parry | 27 vars (`pressure`, `state`, `lunges`, `vaults`, `air_parries`, `run_speed`, static `_shared`, `_warned_asset`) | `src/combat/combat.gd`, `src/world/camp_sandbox.gd`, `src/presentation/bake_warm.gd`
sketches/core-loop/src/combat/kite_drone.gd | 518 | Highdraft Kite Drone enemy: aerial swoops, batted counters and slipstream ride wake | 31 vars (`dives`, `batted`, `air_rams`, `swoops`, `slipstream_*`, static `_shared`, `_warned_asset`) | `src/combat/roster_highdraft.gd`, `src/combat/codex_entries.gd`, `src/presentation/bake_warm.gd`
sketches/core-loop/src/combat/warden_reactor.gd | 509 | Reactor-family Warden driver (dynamically loaded by `warden.gd:549`): spillway chute sheets, ride detection and sheet-ram posture pay | 14 vars (`gates_opened`, `rides`, `sheet_left`, `sheet_dir`, `riding`, `lane`, static `_sheet_shader`, `_line_reference`) | `src/combat/warden.gd` (dynamic path), `tools/park_reactor_ideal.gd`, 28 tests
sketches/core-loop/src/combat/codex_entries.gd | 482 | static registry of `enemy`-category codex entries and flavour lines | 0 vars (const tables `FLAVOUR`, `ENTRIES`) | `src/combat/combat.gd`, `src/core/content_registry.gd`
sketches/core-loop/src/combat/gap_net.gd | 478 | Highdraft Gap Net enemy: dual-post shock nets strung across gaps and rip/crossing counters | 19 vars (`slung`, `torn`, `crossings`, `shock_nets`, `nets`, `post_b`, static `_shared`) | `src/combat/roster_highdraft.gd`, `src/combat/codex_entries.gd`, `src/presentation/bake_warm.gd`
sketches/core-loop/src/combat/counter.gd | 477 | base class for 29 counter/fleet enemies: warn/live/recover/stun state machine, interrupt speed rule, crew/tool mesh builders | 29 vars (`holds`, `fleet`, `row`, `phase`, `warned`, `caught`, `broken_by`, `_rest`, `_t`, `_crew`) | 29 enemy subclasses (`anchor_crew.gd`, `ballast_heavy.gd`, `dispatcher.gd`, `plated_brute.gd`, etc.)
sketches/core-loop/src/combat/mag_trapper.gd | 457 | Mag Trapper counter enemy: polarity flips, repulse blasts and puntable magnetic discs | 20 vars (`polarity_flips`, `repulse_blasts`, `disc_punts`, `_stack`, `_top_disc`, static `_shared`, `_warned_asset`) | `src/combat/fleet.gd`, `src/combat/codex_entries.gd`, `src/presentation/bake_warm.gd`
sketches/core-loop/src/combat/lobber.gd | 454 | Lobber baseline enemy: predictive shell lobbing, cluster volley and chain detonation | 23 vars (`shots`, `cluster_shots`, `chain_detonations`, `charge`, `_cluster_*`, static `_shared`, `_warned_asset`) | `src/combat/combat.gd`, `src/world/camp_sandbox.gd`, `src/presentation/bake_warm.gd`
sketches/core-loop/src/combat/weapons.gd | 436 | static weapon base-pattern catalogue (7 weapons), cadence/charge/pierce constants and pylon/kinetic-pylon tuning tables | 0 vars (const tables `BASE`, `CADENCE`, `CANNON_*`, `KINETIC_PYLON_*`) | `src/combat/combat.gd`, `src/combat/weapon_driver.gd`, `src/combat/relic_swaps.gd`, `src/build/build_sheet.gd`, 13 other files
sketches/core-loop/src/combat/boom_tender.gd | 431 | Spillway Boom Tender enemy: floating buoy chain, buoy throws/returns and float popping | 23 vars (`pinned`, `pops`, `buoy_throws`, `buoy_returns`, `_boom`, `_pops_live`, static `_shared`) | `src/combat/roster.gd`, `src/combat/codex_entries.gd`, `src/presentation/bake_warm.gd`
sketches/core-loop/src/combat/hooker.gd | 427 | Hooker counter enemy: tether rope, snap/catapult counters and reactive whip on player mobility | 18 vars (`rope`, `snaps`, `whips`, `catapult_snaps`, `_whipping`, `_whip_tele`, static `_shared`, `_warned_asset`) | `src/combat/fleet.gd`, `src/combat/codex_entries.gd`, `src/presentation/bake_warm.gd`
sketches/core-loop/src/combat/terrain_faces.gd | 415 | cached terrain/park face queries and ground-normal merging for Rivet's carved slam shapes | 5 vars (`_entries`, `_watched`, `builds`, `hits`, static fault switch `keep_one_placement`) | `src/combat/rivet_kit.gd`
sketches/core-loop/src/combat/linker.gd | 409 | Linker special enemy: partner bracing, directional dish guard and cuttable tether cable | 18 vars (`partner`, `braced`, `cut`, `dish_yaw`, `_combat`, `_linked`, `_dish`) | `src/combat/roster.gd`, `src/combat/codex_entries.gd`

## Outward dependencies
- `src/core/`: 105 refs across 47 combat files (top: `src/core/palette.gd` 33, `ChallengeDials` / `src/core/challenge_dials.gd` 31) — expected downward dependency.
- `src/presentation/`: 99 refs across 40 combat files (top: `EnemyBossCraft` / `src/presentation/craft/enemy_boss_craft.gd` 33 [8 preloads, 25 calls], `src/presentation/fx_library.gd` 13 [75 calls], `src/presentation/flash_guard.gd` 11) — **WRONG DIRECTION (lower -> higher)**.
- `src/movement/`: 54 refs across 35 combat files (top: `src/movement/speed_tier.gd` 25, `src/movement/augments.gd` 9, `src/movement/tuning.gd` 9) — mostly spine value types; 3 preloads of `player_ball.gd`, `chase_camera.gd`, `indicator.gd` are peer/higher coupling.
- `src/build/`: 19 refs across 10 combat files (top: `src/build/shot_bits.gd` 4, `src/build/consumables.gd` 3) — **WRONG DIRECTION / cross-module** (`CONTRACTS.md` forbids module-to-module preloads).
- `src/boss/`: 10 refs across 5 combat files (top: `src/boss/mind_attacks.gd` 5, `src/boss/mind.gd` 2) — **WRONG DIRECTION (lower -> optional higher layer)**.
- `src/world/`: 8 refs across 6 combat files (top: `src/world/ride_rail.gd` 2, `src/world/destructibles.gd` 1) — **WRONG DIRECTION / cross-module**.
- `src/ui/`: 6 refs across 6 combat files (top: `src/ui/ui_tokens.gd` 3, `src/ui/icons.gd` 2, `src/ui/world_prompt.gd` 1) — **WRONG DIRECTION (lower -> higher)**.

## Findings

### COMBAT-01 Move zero-dependency comfort flags (`FlashGuard`, `reduced_motion`) into `src/core/` to remove 14 presentation/UI preloads
- kind: C
- evidence: 11 combat files preload `res://src/presentation/flash_guard.gd` (`git grep -c 'presentation/flash_guard.gd' -- sketches/core-loop/src/combat | wc -l` -> 11: `actives/active_fx.gd:3`, `bolts.gd:7`, `effects.gd:5`, `enemy.gd:14`, `holds.gd:6`, `kest_kit.gd:6`, `orbital_satellites.gd:9`, `projectile.gd:6`, `rivet_kit.gd:10`, `threat_grammar.gd:7`, `warden_reactor.gd:6`), and 3 combat files preload `res://src/ui/ui_tokens.gd` solely to read `UiTokens.reduced_motion` (`miniboss.gd:6,482`, `pit_jaw.gd:7,250`, `warden_reactor.gd:11,372,428`). `src/presentation/flash_guard.gd` (37 lines) imports nothing and only holds `static var on := false` plus 7 pure scaling helpers; `UiTokens.reduced_motion` (`src/ui/ui_tokens.gd:11`) is a bare `static var bool`. Repo-wide, `flash_guard.gd` is already imported by `boss` (3), `build` (2), `combat` (11), `world` (6), `ui` (4), `game.gd` (1), and `presentation` (24).
- fix: Move `flash_guard.gd` to `src/core/flash_guard.gd` (leaving a thin forwarding alias or updating preloads across combat) and move the `reduced_motion` bool into `src/core/flash_guard.gd` (or a new `src/core/comfort.gd`), having `UiTokens.reduced_motion` forward to it via property getter/setter so existing UI callers keep working. Alternative: pass comfort booleans on `ctx`; moving the zero-dependency static module to `src/core/` is cheaper because static helpers like `threat_grammar.gd` and `active_fx.gd` have no `ctx`.
- files to change: `sketches/core-loop/src/core/flash_guard.gd` (moved/new), `sketches/core-loop/src/presentation/flash_guard.gd`, `sketches/core-loop/src/ui/ui_tokens.gd`, plus 14 combat files (`actives/active_fx.gd`, `bolts.gd`, `effects.gd`, `enemy.gd`, `holds.gd`, `kest_kit.gd`, `miniboss.gd`, `orbital_satellites.gd`, `pit_jaw.gd`, `projectile.gd`, `rivet_kit.gd`, `threat_grammar.gd`, `warden_reactor.gd`, and `tools/test_batch_driver.gd` if reset path changes).
- size: ~+25 / -20 lines in core/ui/combat (plus import-path updates).
- risk: low (pure constant-time static getters/flags; zero physics, timing, RNG, or signal order changes).
- behaviour-preserving: yes; identical runtime flag reads and scaling formulas.
- tests that cover it: `sketches/core-loop/tests/flash_comfort_test.gd`, `sketches/core-loop/tests/active_flashes_test.gd`, `sketches/core-loop/tests/test_batch_reset_test.gd`.
- guard: Add a `sketch-lint.mjs` rule forbidding new `res://src/presentation/` and `res://src/ui/` preloads under `src/combat/` (baselined to existing count, shrinking monotonically).

### COMBAT-02 Invert 75 `FxLibrary.burst(...)` calls across 13 combat files through an injected FX callback
- kind: C
- evidence: `git grep -c 'presentation/fx_library.gd' -- sketches/core-loop/src/combat | wc -l` -> 13 files (`boom_tender.gd:4`, `chaser.gd:6`, `dispatcher.gd:5`, `foreman.gd:5`, `hooker.gd:3`, `jolt_layer.gd:5`, `lobber.gd:5`, `mag_trapper.gd:3`, `netcaster.gd:3`, `plated_brute.gd:6`, `ramp_flipper.gd:4`, `swatter.gd:3`, `warden_reactor.gd:7`). Every single call site uses only one static method: `FxLibrary.burst(...)` (`git grep -n 'FxLibrary\.burst(' -- sketches/core-loop/src/combat | wc -l` -> 75 calls; 0 other `FxLibrary` methods called in combat).
- fix: Add a single `burst_fx(parent, id, at, count := -1, tint := Color.TRANSPARENT, toward := Vector3.ZERO, isolate := false)` callback on `ctx` (or a static hook on `src/core/fx_bus.gd` wired once by `presentation.gd:setup(ctx)` to `FxLibrary.burst`), and expose `_burst(...)` on `enemy.gd` so the 13 combat scripts call `_burst(...)` with zero `presentation/fx_library.gd` preloads. Alternative: emit a `GameEvents` signal for every burst; a direct wired `Callable` preserves the return value (`GPUParticles3D`) where callers inspect or parent it, and avoids signal-table churn.
- files to change: `sketches/core-loop/src/core/context.gd` (or `src/core/fx_bus.gd`), `sketches/core-loop/src/presentation/presentation.gd`, `sketches/core-loop/src/combat/enemy.gd`, plus the 13 enemy files listed above.
- size: ~+25 / -15 lines (and 13 cross-layer preloads removed).
- risk: low (only indirection of particle spawns; does not alter simulation, RNG, physics ticks, or signal order).
- behaviour-preserving: yes; in headless/presentation-less tests the hook is a safe no-op returning `null`, matching `FxLibrary.burst` when not in tree.
- tests that cover it: `sketches/core-loop/tests/fx_library_test.gd`, `sketches/core-loop/tests/fx_budget_test.gd`, `sketches/core-loop/tests/dig_fx_test.gd`, `sketches/core-loop/tests/enemy_swatter_asset_test.gd`.
- guard: Same cross-layer preload lint rule as COMBAT-01.

### COMBAT-03 Split `combat.gd`'s cleanest bolt-on seams: W47-H1 hero hooks (342 lines) and Consumables runtime (435 lines)
- kind: H
- evidence: `sketches/core-loop/src/combat/combat.gd` is 7,609 lines, 187 vars, 464 functions. Two contiguous blocks at the bottom of the file already have near-zero state coupling with the rest of `combat.gd`:
  1. **W47-H1 hero hooks (`combat.gd:7158-7499`, 342 lines, 16 funcs, 5 vars: `_beachhead_pylon`, `last_kinetic_arc`, `last_ricochet`, `_kest_trace_left`, `last_kest_trace`)**: **0 of the 5 owned vars** are touched anywhere outside `L7158-7499`; only 11 hook calls enter from `setup`, `_physics_process`, `_fire`, `_on_bolt_hit`, `_on_bolt_bounce`, `_on_mounted`, `_throw_sticky`, `_start_attempt`, `_on_player_died`.
  2. **Consumables runtime (`combat.gd:6638-7072`, 435 lines, 23 funcs, 10 vars: `_nitro_left`, `_overclock_left`, `_memo_left`, `_memo_frozen`, `_balloons`, `_consumable_drops`, `_consumable_rng`, `consumable_uses`, `overclock_skilled_shots`, `last_consumable`)**: only 6 call entry points (`drop_consumable`, `_memo_exposed`, `_step_consumables`, `_apply_overclock_shots`, `_post_consumable_buff`, `_clear_consumables_runtime`) plus 4 narrow var reads (`_overclock_left` in `_physics_process`, `_memo_frozen` and `_consumable_rng` in `spawn_enemy`/`_start_attempt`, `_consumable_drops` in `_step_dragnet_siphon`).
- fix: Extract two child modules owned by `combat.gd` (`src/combat/hero_hooks.gd` and `src/combat/consumables_runtime.gd`, matching existing `actives/active_rack.gd` and `orbital_satellites.gd`), keeping thin public getters on `combat.gd` only for methods tests already call (`use_consumable`, `drop_consumable`, `kinetic_pylon_state`, `nitro_siphon_left`, etc.) or delegating cleanly.
- files to change: `sketches/core-loop/src/combat/combat.gd`, new `sketches/core-loop/src/combat/consumables_runtime.gd`, new `sketches/core-loop/src/combat/hero_hooks.gd`.
- size: ~+800 / -775 lines (reduces `combat.gd` by ~775 lines).
- risk: low-medium (must keep exact `_physics_process` call order and `_consumable_rng` seeding/draw order so consumable drop tests and bot bands stay bit-identical).
- behaviour-preserving: yes, provided step order and RNG stream stay untouched.
- tests that cover it: `sketches/core-loop/tests/consumables_test.gd`, `sketches/core-loop/tests/grapple_muts_test.gd`, `sketches/core-loop/tests/w47_h1_heroes_test.gd`, `sketches/core-loop/tests/w50_isaac_economy_test.gd`, `sketches/core-loop/tests/w50_systems_opt_regression_test.gd`.
- guard: `scripts/deep-sweep.mjs` rule D5 already flags giant files (>1,500 lines) growing by 100+ lines; add a file-line ceiling ratchet on `combat.gd`.

### COMBAT-04 Split `combat.gd`'s Grapple mutations (578 lines) and W47-C2 micro-mutations / cross-synergies (472 lines) seams
- kind: H
- evidence: Two more large contiguous subsystems in `sketches/core-loop/src/combat/combat.gd` own private state almost exclusively:
  1. **Grapple mutations (`combat.gd:6060-6637`, 578 lines, 28 funcs, 9 vars: `_active_grapple_slots`, `_hot_wire_cd`, `_det_cord_queue`, `_tether_live`, `_live_bus_charged_until`, `_live_bus_charges`, `_tether_slam_armed`, `_grapple_mut_counts`, `last_grapple_mut`)**: only 1 owned var (`_hot_wire_cd`) is cleared in `spawn_enemy`; 8 narrow entry points (`_reset_grapple_muts_state`, `_on_grapple_fired_muts`, `_on_grapple_released_muts`, `_consume_grapple_mut_strike`, `live_bus_charged`, `_tether_slam_matches`, `_step_grapple_mutations`, `_sync_grapple_mutations`).
  2. **W47-C2 micro-mutations & cross-synergies (`combat.gd:5588-6059`, 472 lines, 29 funcs, 16 vars: `_air_steer_surge_left`, `_air_dash_bat_left`, `_boost_active_left`, `_cadence_window_extended`, `_cadence_extended_weapon`, `_prev_window_state`, `_pendulum_zapped`, `_pendulum_swing_charged`, `_pendulum_swing_origin`, `_thermobaric_pins`, `_pulled_recent`, `_gravity_ledger_ready_at`, `last_micro_mutation`, `last_cross_synergy`, `_micro_counts`, `_cross_counts`)**: interacts with `combat.gd` via 18 signal/tick hooks and 5 narrow state reads (`_air_dash_bat_left`, `_cadence_window_extended`, `_cadence_extended_weapon`, `_pendulum_zapped`, `_pulled_recent`).
- fix: Extract `src/combat/grapple_mutations.gd` and `src/combat/combat_synergies.gd` in two separate PRs, giving each a clean `setup(ctx, combat)` and `on_enemy_spawned(enemy)` / `reset()` / `step(delta)` interface.
- files to change: `sketches/core-loop/src/combat/combat.gd`, new `sketches/core-loop/src/combat/grapple_mutations.gd`, new `sketches/core-loop/src/combat/combat_synergies.gd`.
- size: ~+1,080 / -1,040 lines (reduces `combat.gd` by ~1,040 lines).
- risk: medium (touches combat strike multipliers, grapple release hooks, and cadence window extension; keep exact hook call order in `_physics_process` and `_door_events`).
- behaviour-preserving: yes, if `combat.gd` keeps delegating public test queries (`grapple_mut_count`, `live_bus_charged`, `det_cord_pending`, `micro_mutation_count`, `cross_synergy_count`, `air_steer_surge_left`, `cadence_window_extended`).
- tests that cover it: `sketches/core-loop/tests/grapple_muts_test.gd`, `sketches/core-loop/tests/risk_reward_distribution_test.gd`, `sketches/core-loop/tests/synergies_test.gd`, `sketches/core-loop/tests/parts_test.gd`, `sketches/core-loop/tests/w50_isaac_parts_test.gd`.
- guard: `combat.gd` line-count ratchet in `scripts/sketch-lint.mjs`.

### COMBAT-05 Extract Tally kit (834 lines) and Remembered Cannon kit (721 lines) out of `combat.gd` to match existing pilot kits
- kind: H
- evidence: Three pilots already have dedicated kit modules (`rivet_kit.gd`, `kest_kit.gd`, `tarn_claw.gd`), whereas Tally and Remembered Cannon remain inline inside `sketches/core-loop/src/combat/combat.gd`:
  1. **Tally kit (`combat.gd:3685-4518`, 834 lines, 57 funcs, 21 vars: `plate`, `last_card`, `bay`, `link_group`, `_arcing`, `_gather_tick`, `_roll_clock`, `_restored_frame`, `tally_last_settle`, `_tally_cards`, `_cards`, `clip_post`, `_ink`, `ride_clips`, `_fly_plates`, `_fly_pulled`, `_run_settles`, `_tally_card_frame`, `tally_piece`, `_stage_clip_casts`, `_ink_mesh`)**: only 3 owned vars (`plate`, `last_card`, `_cards`) are touched outside this range.
  2. **Remembered Cannon kit + W47-H2 piton/recoil (`combat.gd:2870-3479` & `7500-7610`, 721 lines, 46 funcs, 16 vars: `_cannon`, `_walk`, `_wake`, `_recital_index`, `_recital_at`, `_exposure_mesh`, `_exposure_material`, `_arc_mark_mesh`, `_exposed`, `last_cannon_paint`, `_cannon_count`, `_cannon_recoil_airborne`, `_cannon_recoil_air_grace`, `_cannon_piton`, `last_cannon_piton`, `last_cannon_recoil_reset`)**: only 3 owned vars (`_exposed`, `_cannon_count`, `_cannon_piton`) are touched outside.
  Together with COMBAT-03 and COMBAT-04, these 6 existing seams account for **~3,380 lines (44%)** of `combat.gd`, plus a 7th smaller seam: **Companion assist / primer / escape lane** (`combat.gd:825-1112`, 288 lines, 10 vars).
- fix: Extract `src/combat/tally_kit.gd` and `src/combat/cannon_kit.gd` in separate PRs, after COMBAT-06 turns `combat._*` helper reach-ins into a small public collaborator API so the extracted kits do not add new underscore reach-ins.
- files to change: `sketches/core-loop/src/combat/combat.gd`, new `sketches/core-loop/src/combat/tally_kit.gd`, new `sketches/core-loop/src/combat/cannon_kit.gd`, `sketches/core-loop/tools/bot_driver.gd` (lines 4500, 4506), `sketches/core-loop/src/combat/ultimate.gd` (lines 976–1052), `sketches/core-loop/src/combat/relic_swaps.gd` (lines 717, 754).
- size: ~+1,600 / -1,550 lines (reduces `combat.gd` by ~1,550 lines).
- risk: high (per DEEP-SWEEP, pilot cadence, weapon/ultimate timing, and bot-band telemetry read these paths; execute only one kit per PR with full pilot & bot-band verification).
- behaviour-preserving: yes, if signal connection order and `_physics_process` step order are preserved identically.
- tests that cover it: `sketches/core-loop/tests/tally_kit_test.gd`, `sketches/core-loop/tests/tally_set_piece_test.gd`, `sketches/core-loop/tests/tally_ghost_shift_test.gd`, `sketches/core-loop/tests/cannon_kit_test.gd`, `sketches/core-loop/tests/cannon_line_lane_test.gd`, `sketches/core-loop/tests/cannon_ultimate_test.gd`, `sketches/core-loop/tests/w47_h2_heroes_test.gd`.
- guard: `combat.gd` line-count ratchet + D2 reach-in check.

### COMBAT-06 Replace 167 underscore reach-ins into `combat.gd` across 18 files with an explicit public collaborator API
- kind: C
- evidence: Static scan of all `src/` and `tools/` files outside `combat.gd` finds **167 hits across 18 files** reaching into private `combat._*` / `spawner._*` members:
  - Internal combat collaborators (158 hits across 13 files): `relic_swaps.gd` (61), `tarn_claw.gd` (23), `ultimate.gd` (22), `rivet_kit.gd` (15), `kest_kit.gd` (14), `actives/scrap_rockets.gd` (6), `actives/cutting_torch.gd` (3), `actives/silo_battery.gd` (3), `stakes.gd` (3), `actives/glass_lance.gd` (2), `actives/lift_pulse.gd` (2), `actives/quake_knock.gd` (2), `fleet.gd` (1). Top reached members: `_hit` (26), `_flat_aim` (18), `_discover` (13), `_clock` (13), `_damage_mod` (10), `_hull` (8), `_ult_hit` (7), `_nearest_list` (5), `_target_class` (4), `_patterns` (4), `_chain` (3), `_specials` (3).
  - Cross-module reach-ins (2 hits): `src/build/maker_bonuses.gd:184` (`ctx.spawner._trail_deal(...)`) and `src/world/camp_sandbox.gd:266` (`combat._on_shell_returned`).
  - Tool reach-ins (7 hits): `tools/pattern_dps.gd:154,157,171,259` (`_rebuild_patterns`, `_patterns`, `_reset_ledger`), `tools/bot_driver.gd:4500,4506` (`_card_aim`, `_ordinary`), `tools/priority_proof.gd:524,525` (`_shred`, `_show_shred`).
  Meanwhile `combat.gd:2408-2433` already started adding 7 awkward 1-line public pass-throughs (`nearest_enemies` -> `_nearest_list`, `floor_at` -> `_floor_at`, `shot_bits` -> `_shot_bits`, `synergy_context` -> `_synergy_context`, `apply_heat` -> `_heat`, `post_consumable_buff` -> `_post_consumable_buff`, `clear_buff` -> `_clear_buff`) while older callers still call the underscore versions.
- fix: Promote the core collaborator methods on `combat.gd` to public names (`deal_hit`, `flat_aim`, `discover`, `sim_clock`, `damage_mod`, `hull_radius`, `deal_ult_hit`, `chain_hit`, `target_class`, `deal_trail`, `handle_shell_returned`, `register_special`/`register_line_skill`) and delete the 7 redundant 1-line pass-throughs by renaming their targets directly. Expose `shred_reset_for_tool()` or `wipe_shred()` (already public at `combat.gd:1350`) for `priority_proof.gd`.
- files to change: `sketches/core-loop/src/combat/combat.gd` plus the 18 caller files listed above (19 files total).
- size: ~+190 / -210 lines (mostly mechanical renames).
- risk: low (pure identifier renames and encapsulation; no logic or ordering changes).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/rivet_kit_test.gd`, `sketches/core-loop/tests/tarn_claw_drag_test.gd`, `sketches/core-loop/tests/kest_kit_test.gd`, `sketches/core-loop/tests/w50_isaac_relics_test.gd`, `sketches/core-loop/tests/active_rockets_test.gd`, `sketches/core-loop/tests/ultimate_set_piece_test.gd`, `sketches/core-loop/tests/w50_isaac_parts_test.gd`.
- guard: Promote `scripts/deep-sweep.mjs` rule D2 (cross-object `._*` reach-ins) to a baselined `sketch-lint.mjs` rule so no new reach-ins into `combat._*` can land.

### COMBAT-07 Consolidate 25 hand-rolled enemy GLB mesh loaders onto `EnemyCasting.parts()` and move `ModelVariants` to `src/core/`
- kind: A
- evidence: `src/combat/enemy_casting.gd` (40 lines, `class_name EnemyCasting`) already implements GLB mesh extraction (`ModelVariants.path`, `ResourceLoader.exists`, `PackedScene.instantiate()`, `find_children("*", "MeshInstance3D")`, vertex-colour `Palette.solid(Color.WHITE)`, `fleet_paint` surface detection, once-per-tag missing-material `push_warning`, optional `bake_parents`). Only **9** enemy scripts call `EnemyCasting.parts` (`git grep -l 'EnemyCasting\.parts' -- sketches/core-loop/src/combat | wc -l` -> 9: `ballast_heavy`, `boom_tender`, `burrower`, `catch_trap`, `gap_net`, `gyro_jammer`, `jolt_layer`, `line_cutter`, `pit_jaw`), while **25** other enemy scripts hand-roll the same loader (`anchor_crew`, `bola_thrower`, `chaser`, `deflector`, `dispatcher`, `drill_crew`, `foreman`, `hooker`, `kite_drone`, `lamp_swarm`, `linker`, `lobber`, `mag_trapper`, `mind_hand`, `miniboss`, `netcaster`, `plated_brute`, `prop_crew`, `ramp_flipper`, `reactor_relic`, `swarm_remnant`, `swatter`, `vault`, `warden`, `winch_drone`). Specifically:
  - 17 combat files copy-paste the exact warning `"<kind>: surface has no material; using default finish"` (`git grep -l 'surface has no material; using default finish' -- sketches/core-loop/src/combat | wc -l` -> 17).
  - 31 enemy files declare boilerplate `static var _shared` + `static var _warned_asset` caches (`git grep -l 'static var _shared\b' -- sketches/core-loop/src/combat | wc -l` -> 31).
  - `dispatcher.gd:324` and `foreman.gd:175` contain byte-for-byte identical 6-line `_in_scene(node, scene)` helpers duplicating `EnemyCasting.parts(..., bake_parents = true)`.
  - `enemy_casting.gd:10` plus 5 enemy files (`chaser.gd:115`, `hooker.gd:143`, `lobber.gd:107`, `netcaster.gd:130`, `swatter.gd:98`) reference `ModelVariants` (`src/presentation/model_variants.gd`, 54 lines, zero presentation dependencies — only reads `--models=tripo` CLI args and `ResourceLoader.exists`).
- fix: (1) Move `src/presentation/model_variants.gd` to `src/core/model_variants.gd` (instant fix for 6 wrong-direction combat refs, plus build/world refs). (2) Extend `EnemyCasting` with a cached `cached_parts(authored, tag, opts := {})` (with central `reset_for_tests()` clearing one static dict instead of 31 per-file `_shared` / `_warned_asset` vars) and optional flags (`bake_parents`, `keep_materials`, `sockets`) and migrate the 25 hand-rolled enemy loaders in batches.
- files to change: `sketches/core-loop/src/core/model_variants.gd`, `sketches/core-loop/src/combat/enemy_casting.gd`, `sketches/core-loop/tools/test_batch_driver.gd`, and up to 25 enemy `.gd` files under `sketches/core-loop/src/combat/`.
- size: ~+60 / -650 lines (and removes ~25 `L14_STATIC_VAR_BASELINE` entries in `scripts/sketch-lint.mjs`).
- risk: low-medium (mesh/material setup only; verify `fleet_paint` flash surface index and any enemy-specific socket/child naming like `splitter.gd` or `foreman.gd` before migrating each file).
- behaviour-preserving: yes; rendered meshes, flash surfaces, and fallback paths stay identical.
- tests that cover it: `sketches/core-loop/tests/tripo_variants_test.gd`, `sketches/core-loop/tests/test_batch_reset_test.gd`, `sketches/core-loop/tests/enemy_swatter_asset_test.gd`, `sketches/core-loop/tests/bake_look_test.gd`, `sketches/core-loop/tests/asset_registry_test.gd`.
- guard: Disallow new per-enemy `static var _shared` / `_warned_asset` entries via `L14` (already enforced for new static vars) and remove migrated entries from `L14_STATIC_VAR_BASELINE`.

### COMBAT-08 Factor out 4 duplicated helper patterns across all 8 active scripts (`src/combat/actives/`)
- kind: A
- evidence: Across the 8 active implementations (`cutting_torch.gd`, `glass_lance.gd`, `lift_pulse.gd`, `magnet_sling.gd`, `quake_knock.gd`, `scrap_rockets.gd`, `silo_battery.gd`, `slag_mortar.gd`):
  1. `_pattern(id: String) -> int` is copy-pasted identically in **6 files** (`git grep -n 'func _pattern(' -- sketches/core-loop/src/combat/actives | wc -l` -> 6: `cutting_torch.gd:190`, `glass_lance.gd:160`, `lift_pulse.gd:169`, `quake_knock.gd:223`, `scrap_rockets.gd:144`, `silo_battery.gd:150`).
  2. `punch_bonus()` + `tuning.mod("weapon_damage")` scaling is copy-pasted in **all 8 files** (`git grep -l 'punch_bonus' -- sketches/core-loop/src/combat/actives | wc -l` -> 8: `cutting_torch.gd:65-69`, `glass_lance.gd:48-52`, `lift_pulse.gd:43-47`, `magnet_sling.gd:50-55`, `quake_knock.gd:67-71`, `scrap_rockets.gd:47-51`, `silo_battery.gd:62-66`, `slag_mortar.gd:61-66`).
  3. Flattening `ctx.aim_forward()` to horizontal XZ is copy-pasted in **7 files** (`cutting_torch.gd:177-179`, `glass_lance.gd:57-59`, `lift_pulse.gd:62-64`, `magnet_sling.gd:63-65`, `scrap_rockets.gd:57-59`, `silo_battery.gd:139-141`, `slag_mortar.gd:79-81`) — duplicating `combat._flat_aim()` (`combat.gd:2779`).
  4. `_girth(enemy)` is copy-pasted in **2 files** (`glass_lance.gd:156`, `scrap_rockets.gd:122`), while `cutting_torch.gd:155,161` calls `combat._hull(enemy)` instead.
- fix: Add a small base script `src/combat/actives/active_base.gd` (extending `RefCounted`, inherited by all 8 actives — or static helpers on `active_rack.gd`) owning `setup(context, owner_combat)`, `pattern_level(id)`, `scaled_damage(base, mult := 1.0)`, `flat_aim()`, and `enemy_girth(enemy, fallback := 0.6)`.
- files to change: new `sketches/core-loop/src/combat/actives/active_base.gd` (or `active_rack.gd`) and the 8 active `.gd` files under `sketches/core-loop/src/combat/actives/`.
- size: ~+40 / -115 lines.
- risk: low (pure helper extraction; preserve `0.6` default girth on `glass_lance`/`scrap_rockets` vs `1.0` on `cutting_torch` so hitboxes stay identical).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/active_torch_test.gd`, `sketches/core-loop/tests/active_glass_lance_test.gd`, `sketches/core-loop/tests/active_lift_pulse_test.gd`, `sketches/core-loop/tests/active_quake_test.gd`, `sketches/core-loop/tests/active_rockets_test.gd`, `sketches/core-loop/tests/active_silo_test.gd`, `sketches/core-loop/tests/active_rack_test.gd`.
- guard: None needed beyond PR review / `deep-sweep.mjs`.

### COMBAT-09 Unify 13 posture-target checks and direct `_apply_posture()` calls (including `rivet_kit.gd` bypassing `DamageDoor`)
- kind: C
- evidence: `warden.gd:1008` already exposes a public `func apply_posture_hit(result: Dictionary) -> void:` that wraps `_apply_posture(result)`, and `combat.gd:997` already has `_fights_posture(enemy)` checking `enemy.has_method("fight") and enemy.call("fight") == "posture"`. Yet **13 lines outside `warden.gd`** (`git grep -n '_apply_posture' -- sketches/core-loop/src/combat/ | grep -v '^sketches/core-loop/src/combat/warden.gd:' | wc -l` -> 13) either duck-type Wardens by checking private `enemy.has_method("_apply_posture")` (`combat.gd:684,3346,3669,4283,4294,7132`, `relic_swaps.gd:223`, `rivet_kit.gd:246`, `tarn_claw.gd:104,393`) or call private `_apply_posture(...)` directly (`combat.gd:3357`, `rivet_kit.gd:461`, `warden_swarm.gd:378`). Worse, `rivet_kit.gd:454-461` manually runs `target.judge_hit(...)`, mutates `result`, emits `ctx.events.strike_deflected` directly (even when `result["full"]` is true), and calls `target._apply_posture(result)` outside `DamageDoor`.
- fix: Promote `combat.gd:997` `_fights_posture(enemy)` to public `fights_posture(enemy)` (or `is_posture_target(enemy)`), replace all 10 `has_method("_apply_posture")` probes with it, replace the 3 direct `_apply_posture` calls with `apply_posture_hit(...)`, and route `rivet_kit.gd:454-461` through a public `combat.apply_capped_warden_posture(target, kind, punch, cap)` method so posture application and deflection events have one owner.
- files to change: `sketches/core-loop/src/combat/combat.gd`, `sketches/core-loop/src/combat/rivet_kit.gd`, `sketches/core-loop/src/combat/tarn_claw.gd`, `sketches/core-loop/src/combat/relic_swaps.gd`, `sketches/core-loop/src/combat/warden_swarm.gd`.
- size: ~+20 / -25 lines.
- risk: medium (Warden posture is heavily tested and tied to bot bands; preserve `rivet_kit.gd`'s exact `strike_deflected` emit and `LINE_WARDEN_POSTURE` cap in the new helper so behaviour is unchanged).
- behaviour-preserving: yes, if `rivet_kit.gd`'s exact signal emission and posture cap are kept verbatim inside the moved helper.
- tests that cover it: `sketches/core-loop/tests/rivet_kit_test.gd`, `sketches/core-loop/tests/tarn_claw_drag_test.gd`, `sketches/core-loop/tests/cannon_ultimate_test.gd`, `sketches/core-loop/tests/tally_ghost_shift_test.gd`, `sketches/core-loop/tests/arena_posture_record_test.gd`.
- guard: `scripts/deep-sweep.mjs` D2 reach-in check.

### COMBAT-10 Unify enemy hull-radius lookups across 7 combat files (three conflicting fallback defaults)
- kind: A
- evidence: Reading an enemy's collision radius via `enemy.get("radius")` is hand-rolled at **13 sites across 7 combat files** with three different default fallbacks when `radius` is absent:
  - `1.0`: `combat.gd:2765` (`_hull(enemy)`), `combat.gd:2360`, `sticky.gd:213`, `wear_trail.gd:97`
  - `0.6`: `actives/glass_lance.gd:157` (`_girth`), `actives/scrap_rockets.gd:123` (`_girth`)
  - `0.9`: `orbital_satellites.gd:455,594,724`
  - `0.0` / profile: `flail.gd:154-155`, `swarm_remnant.gd:172`, `ally_husk.gd:286`.
- fix: Add one public `static func hull_radius(enemy: Node3D, fallback := 1.0) -> float:` on `enemy.gd` (or `combat.gd`) and route all 13 call sites through it, passing the existing per-caller fallback (`0.6` / `0.9` / `1.0`) first so behaviour is 100% preserved while eliminating duplicate property-probing logic.
- files to change: `sketches/core-loop/src/combat/enemy.gd` (or `combat.gd`), `sketches/core-loop/src/combat/actives/glass_lance.gd`, `sketches/core-loop/src/combat/actives/scrap_rockets.gd`, `sketches/core-loop/src/combat/orbital_satellites.gd`, `sketches/core-loop/src/combat/sticky.gd`, `sketches/core-loop/src/combat/flail.gd`, `sketches/core-loop/src/combat/wear_trail.gd`.
- size: ~+12 / -20 lines.
- risk: low (if existing fallback arguments are preserved; harmonizing the `0.6`/`0.9`/`1.0` defaults themselves is a separate tuning decision).
- behaviour-preserving: yes, when passing existing fallback defaults.
- tests that cover it: `sketches/core-loop/tests/active_glass_lance_test.gd`, `sketches/core-loop/tests/active_rockets_test.gd`, `sketches/core-loop/tests/w50_isaac_parts_test.gd`, `sketches/core-loop/tests/kest_kit_test.gd`.
- guard: None needed (low churn).

### COMBAT-11 Consolidate duplicated plating/shred math and document/reconcile parallel element & armour effectiveness tables
- kind: E
- evidence: Damage, plating, and element rules are spelled out in more than one place inside and across the combat boundary:
  1. **Plating minus shred** is recomputed outside `combat.plating_of()` in `actives/cutting_torch.gd:168-173` (`enemy.plating_for(KIND, "") - combat.shred_of(enemy)`) and `boss/boss.gd:1857-1859`.
  2. **Full-plating shred hack** is copy-pasted twice in `combat.gd:6802` and `combat.gd:6992` (`_add_shred(enemy, float(enemy.plating_now()) / maxf(SHRED_PER_PUNCH, 0.01))`) instead of a single `strip_all_plating(enemy)` helper.
  3. **Damage multiplier chain** in `combat.gd:1370-1375` (`would_crush`) repeats the `_strike_mult` + `DamageFamilies.mult` calculation from `_door_caps` / `_read_armour` (`combat.gd:714-756`), and omits the `override_on("impact_force_2x")` multiplier from line 715, creating a subtle drift seam whenever a damage modifier is added.
  4. **Parallel element/armour tables**: `src/combat/damage_families.gd:12-19` defines `FAMILY_OF` (`arc`, `electrify`, `frost`, default `kinetic`) and `ARMOUR` (`plated` resists `kinetic` 0.6x and is weak to `arc` 1.25x), while `src/build/elements.gd:4-81` independently defines `ELEMENTS_W50` (`frost`, `arc`, `kinetic`, `heat`), `STATUS_KINDS`, `BOSS_KINDS`, and `LAYER_MULT` (`armour`: `kinetic` 1.5x, `arc` 0.75x — the inverse of `damage_families.gd`'s `plated`, used by `src/core/defence_bars.gd:59`). Meanwhile `actives/quake_knock.gd:24` and `actives/slag_mortar.gd:24` hardcode element string literals `"kinetic"` and `"heat"` directly.
- fix: (a) Add `plating_for_kind(enemy, kind)` and `strip_all_plating(enemy)` and a shared `_scaled_dealt(enemy, result, kind, cls)` helper in `combat.gd` so `cutting_torch.gd`, `would_crush`, `_door_caps`, and consumables all share one plating/damage path (immediate, behaviour-preserving). (b) Move shared element string constants (`KINETIC`, `ARC`, `FROST`, `HEAT`) to one `src/core/` schema so `damage_families.gd`, `build/elements.gd`, and `actives/` read the same IDs (reconciling the conflicting `plated` vs `armour` multipliers requires an owner decision — see "Needs the owner").
- files to change: `sketches/core-loop/src/combat/combat.gd`, `sketches/core-loop/src/combat/actives/cutting_torch.gd`, `sketches/core-loop/src/combat/damage_families.gd`, `sketches/core-loop/src/combat/actives/quake_knock.gd`, `sketches/core-loop/src/combat/actives/slag_mortar.gd`.
- size: ~+30 / -25 lines for part (a).
- risk: medium (damage & crush paths affect combat bands; do NOT change `would_crush`'s `impact_force_2x` behaviour without explicit test check).
- behaviour-preserving: yes for helper consolidation in part (a); reconciling `damage_families.gd` vs `elements.gd` multipliers would change gameplay and is deferred to the owner.
- tests that cover it: `sketches/core-loop/tests/damage_families_test.gd`, `sketches/core-loop/tests/active_torch_test.gd`, `sketches/core-loop/tests/consumables_test.gd`, `sketches/core-loop/tests/spine_heft_test.gd`.
- guard: Unit test in `tests/unit/` asserting `DamageFamilies` element IDs are a subset of the canonical element constants.

### COMBAT-12 Remove dead write-only shared mutable state `Enemy.rim_color`
- kind: B
- evidence: `git grep -n 'rim_color' -- sketches/core-loop/src sketches/core-loop/tools sketches/core-loop/tests` shows only 2 sites in `src/combat/`: `src/combat/enemy.gd:43` (`static var rim_color := Palette.ARC`) and `src/combat/fleet.gd:207` (`Enemy.rim_color = ctx.run.class_def.color`, executed every `_physics_process` tick!). **Zero lines anywhere in `src/` read `Enemy.rim_color`** (the remaining grep hits are unrelated `deflector.gd:123 vault_rim_color()`, `projectile.gd:184 rim_color()`, and `presentation/damage_numbers.gd` local dict keys). The only other references to `Enemy.rim_color` are its allowlist entry (`src/core/colour_meanings.gd:90`), batch reset (`tools/test_batch_driver.gd:258`), and test setup/assertion (`tests/status_marks_test.gd:214`, `tests/test_batch_reset_test.gd:127,360`).
- fix: Delete `static var rim_color` from `enemy.gd:43`, delete the per-tick write in `fleet.gd:206-207`, and remove its obsolete entries from `colour_meanings.gd`, `test_batch_driver.gd`, `test_batch_reset_test.gd`, and `status_marks_test.gd`.
- files to change: `sketches/core-loop/src/combat/enemy.gd`, `sketches/core-loop/src/combat/fleet.gd`, `sketches/core-loop/src/core/colour_meanings.gd`, `sketches/core-loop/tools/test_batch_driver.gd`, `sketches/core-loop/tests/test_batch_reset_test.gd`, `sketches/core-loop/tests/status_marks_test.gd`.
- size: ~+0 / -14 lines.
- risk: low (never read by any runtime code).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/test_batch_reset_test.gd`, `sketches/core-loop/tests/status_marks_test.gd`, `sketches/core-loop/tests/colour_meanings_test.gd`.
- guard: `L14` static-var guard in `scripts/sketch-lint.mjs` already discourages new static vars.

### COMBAT-13 Delete 14 verified zero-caller functions across `src/combat/`
- kind: B
- evidence: Verified with `git grep -n '\b<sym>\b' -- sketches/core-loop/src sketches/core-loop/tools sketches/core-loop/tests scripts` — every one of these 14 functions has **1 hit total** (its own declaration, 0 callers in `src/`, `tools/`, `tests/`, `scripts/`, and 0 string/`Callable`/signal references):
  1. `combat.gd:1387` `transformer_info(id)` (documented in `combat/README.md:68`, 0 code callers)
  2. `combat.gd:5666` `active_cross_synergies(extra)`
  3. `orbital_satellites.gd:313` `active_w50_cross_synergies(extra)`
  4. `ally_husk.gd:682` `active_takeovers()`
  5. `counter.gd:445` `_tool_material(...)` (1-line wrapper around `Palette.solid`)
  6. `holds.gd:84` `unholdable()`
  7. `hooker.gd:92` `is_whipping()`
  8. `special_cues.gd:60` `all_sounds()`
  9. `splitter.gd:164` `piece_parts()`
  10. `telegraph.gd:179` `end_point()`
  11. `warden_look.gd:89` `lit_levels()`
  12. `warden_swarm.gd:321` `swell_fraction()`
  13. `warden_swarm.gd:325` `_ball_on_pool(warden)`
  14. `warden_swarm.gd:381` `snip_progress(warden)`
- fix: Remove all 14 dead functions (and drop `transformer_info` from `src/combat/README.md:68` if not needed as an external API).
- files to change: `sketches/core-loop/src/combat/combat.gd`, `orbital_satellites.gd`, `ally_husk.gd`, `counter.gd`, `holds.gd`, `hooker.gd`, `special_cues.gd`, `splitter.gd`, `telegraph.gd`, `warden_look.gd`, `warden_swarm.gd`, `README.md` (12 files).
- size: ~+0 / -95 lines.
- risk: low (zero callers across the entire repo including tests, tools, and scene/shader files).
- behaviour-preserving: yes.
- tests that cover it: `npm run sketch:fast` (syntax/load + all affected combat tests).
- guard: Optional dead-private-method check in `scripts/deep-sweep.mjs`.

### COMBAT-14 Invert remaining combat -> presentation & UI preloads (mesh craft, enemy visuals, audio, `Icons`, `WorldPrompt`, `Density`)
- kind: C
- evidence: After COMBAT-01 (`flash_guard`, `ui_tokens`), COMBAT-02 (`fx_library`), and COMBAT-07 (`ModelVariants`), **27 combat files** still preload presentation or UI scripts:
  - **Procedural mesh craft (14 files)**: `enemy_boss_craft.gd` (8 files: `burrower`, `dispatcher`, `miniboss`, `pit_jaw`, `ramp_flipper`, `swarm_remnant`, `warden_reactor`, `warden_swarm`), `world23_chunk_craft.gd` (4 files: `deflector`, `gap_net`, `gyro_jammer`, `kite_drone`), `craft_prop_meshes.gd` (`stakes.gd:7`), `crafted_ball_gear.gd` (`bolts.gd:6`), `ally_husk_look.gd` (`ally_husk.gd:7`), `crew_lamp.gd` (`counter.gd:8`).
  - **Enemy visual/animation cluster on `enemy.gd` & subclasses (7 files)**: `enemy.gd:4-16` preloads 7 presentation scripts (`bake_look`, `ink_outline`, `enemy_motion`, `enemy_clips`, `windup_rows`, `windup_poses`, `enemy_gait`); `special_rig.gd` (3 files: `dispatcher`, `foreman`, `splitter`); `prop_motion_rig.gd` (2 files: `miniboss`, `pit_jaw`); `enemy_motion.gd` (`threat_grammar.gd:8`, `warden_reactor.gd:8`).
  - **Direct audio & presentation FX (5 files)**: `jolt_layer.gd:4` (`jolt_layer_audio.gd`), `projectile.gd:8` (`sfx_bank.gd`), `prop_crew.gd:4` (`foley_audio.gd`), `combat.gd:31,64` (`way_out_paint.gd`, `hero_fx.gd`).
  - **Density governor (3 files)**: `bolts.gd:3`, `effects.gd:4`, `threat_grammar.gd:5` (`presentation/density.gd`).
  - **UI assets/widgets (3 files)**: `mind_hand.gd:4` & `projectile.gd:7` (`src/ui/icons.gd`), `actives/active_rack.gd:8` (`src/ui/world_prompt.gd`).
- fix: Cheapest turnaround grouped by tier:
  1. **Direct audio (3 files, cheapest)**: Move `jolt_layer_audio`, `projectile` bat-rim SFX, and `prop_crew` foley triggers to `presentation/audio.gd` reacting to existing enemy signals (`attack_phase`, `special_tell`, `enemy_spawned`), removing all 3 audio preloads from combat.
  2. **`Density` (3 files, cheap)**: Move pure density-band math/governor state (`src/presentation/density.gd` imports nothing!) to `src/core/density.gd` (just like `flash_guard.gd`).
  3. **`Icons` & `WorldPrompt` (3 files, cheap)**: Emit a drop-prompt event or call a `ctx.ui_factory` / `ctx.icon_texture(id)` hook wired by `game.gd`/`ui` (or keep `WorldPrompt` as a documented spine seam matching `CONTRACTS.md:354`, where modules already use `src/ui/world_prompt.gd`).
  4. **Mesh craft & `enemy.gd` visual cluster (medium/larger)**: Inject a `visual_hooks` object on `ctx` wired by `presentation.gd` (handling `dress_enemy`, `attach_clips`, `build_mesh(id)`), so `enemy.gd` and enemy scripts own simulation + geometry descriptors while `presentation/` owns meshes, shaders, outlines, and rigs.
- files to change: 27 files in `sketches/core-loop/src/combat/` plus `src/core/` and `src/presentation/presentation.gd` (best done in 4 separate PRs matching the 4 tiers above).
- size: ~+180 / -140 lines across the 4 PRs.
- risk: medium (tiers 1–3 are low risk; tier 4 touches enemy visual seating and `enemy_clips_test`/`bake_look_test` expectations).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/enemy_clips_test.gd`, `sketches/core-loop/tests/enemy_gait_test.gd`, `sketches/core-loop/tests/jolt_layer_test.gd`, `sketches/core-loop/tests/bake_look_test.gd`, `sketches/core-loop/tests/active_rack_test.gd`, `sketches/core-loop/tests/step5_enemy_boss_craft_test.gd`.
- guard: Cross-layer preload lint rule in `scripts/sketch-lint.mjs`.

### COMBAT-15 Break 10 `src/combat/` -> `src/boss/` preloads that violate optional-boss isolation
- kind: C
- evidence: `CONTRACTS.md:25` states `src/boss/boss.gd` is an optional module loaded only when `ResourceLoader.exists`, and `CONTRACTS.md:480` states `boss/hazard.gd -> combat/threat_grammar.gd` is the one intentional seam between boss and combat. Yet **5 combat files** preload `src/boss/` (`git grep -n 'res://src/boss/' -- sketches/core-loop/src/combat | wc -l` -> 10 hits):
  - `combat.gd:27`, `relic_swaps.gd:10`, `ultimate.gd:1002,1029,1037` preload `src/boss/mind_attacks.gd` (for `FAMILIES`, `RUSH_HALF_BAND`, and Mind-style cannon-set-piece attack spawning).
  - `relic_swaps.gd:9` preloads `src/boss/hazard.gd`.
  - `mind_hand.gd:5` preloads `src/boss/boss_model.gd`.
  - `codex_entries.gd:369,408,409` references `src/boss/waking.gd` and `src/boss/mind.gd`.
- fix: Move shared Mind-attack geometry/family constants (`FAMILIES`, `RUSH_HALF_BAND`) or the reusable `Hazard` node into `src/combat/` (beside `telegraph.gd` and `threat_grammar.gd`) or `src/core/`, move `BossModel`'s generic GLB helper into `EnemyCasting` (COMBAT-07), and replace `codex_entries.gd`'s boss-file preloads with string IDs / `codex.declare` calls from `boss.gd`.
- files to change: `sketches/core-loop/src/combat/combat.gd`, `relic_swaps.gd`, `ultimate.gd`, `mind_hand.gd`, `codex_entries.gd`, plus `sketches/core-loop/src/boss/mind_attacks.gd`, `boss_model.gd`.
- size: ~+40 / -35 lines.
- risk: low-medium (pure relocation of shared constants/helpers; verify `boss_pickup_asset_test.gd` content pin is untouched since `boss.gd` itself doesn't move).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/cannon_ultimate_test.gd`, `sketches/core-loop/tests/w50_isaac_relics_test.gd`, `sketches/core-loop/tests/combat_codex_test.gd`, `sketches/core-loop/tests/dress_mnd_assets_test.gd`.
- guard: Add `src/combat/ -> src/boss/` preload ban to `scripts/sketch-lint.mjs`.

### COMBAT-16 Move pure data schemas out of `src/build/` & `src/world/` into `src/core/` to remove 27 cross-module preloads in combat
- kind: C
- evidence: `CONTRACTS.md:32` forbids cross-module preloads, yet `src/combat/` has **19 preloads of `src/build/`** across 10 files (`shot_bits.gd` [4: `bolts`, `combat`, `effects`, `orbital_satellites`], `consumables.gd` [3: `active_rack`, `combat`, `ultimate`], `item_gen.gd` [2: `active_offers`, `active_rack`], `synergies.gd` [2: `combat`, `orbital_satellites`], `parts.gd` [2: `combat`, `orbital_satellites`], `relics.gd` [2: `combat`, `relic_swaps`], `fabricators.gd`, `elements.gd`, `build_sheet.gd`, `attachments.gd`) and **8 preloads of `src/world/`** across 6 files (`ride_rail.gd` [2: `rivet_kit`, `ultimate`], `destructibles.gd` [`combat:58`], `park_map.gd` [`combat:5302`], `hazard_hits.gd` [`combat:52`], `terrain.gd` [`fleet:10`], `cracked_cache.gd` [`plated_brute:5`], `rubble_fall.gd` [`prop_crew:3`]).
- fix: Pure schema/bitmask tables shared by both `build` and `combat` (`shot_bits.gd`, `elements.gd`, `consumable_defs.gd` split out of `consumables.gd`, `part_def.gd`/`parts.gd` read-only defs) belong in `src/core/` (alongside `class_def.gd` and `event_kinds.gd`). Runtime calls like `consumables.gd:echo_ultimate` (`ultimate.gd:722`), `build_sheet.gd` (`combat.gd:5517`), `ride_rail.gd`, and `destructibles.gd` should go through `ctx.build` / `ctx.terrain` methods instead of preloading peer scripts.
- files to change: `sketches/core-loop/src/core/` (relocated pure schemas) and the 14 combat files that preload `src/build/` or `src/world/`.
- size: ~+60 / -55 lines (plus file moves and import updates).
- risk: medium (wide import fan-out across `build/`, `combat/`, and `tests/`; execute one schema per PR starting with `shot_bits.gd`, which has 4 combat preloaders and zero runtime state).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/shot_bits_live_test.gd`, `sketches/core-loop/tests/consumables_test.gd`, `sketches/core-loop/tests/w50_isaac_parts_test.gd`, `sketches/core-loop/tests/w50_isaac_relics_test.gd`, `sketches/core-loop/tests/rivet_kit_test.gd`, `sketches/core-loop/tests/destructibles_hooks_test.gd`.
- guard: Cross-module preload lint rule in `scripts/sketch-lint.mjs`.

### COMBAT-17 Eliminate private reach-ins across combat's external boundaries (`hero_assets` -> `warden`, `boss` -> `warden`, `combat` -> `run_log`/`player`, and `ultimate._*`)
- kind: C
- evidence:
  1. **External reach-ins INTO combat**: `src/presentation/hero_assets.gd` reaches into private Warden members at **20+ sites** (`warden._look`, `warden._kit`, `warden._flash`, `warden._look._jaws`, `warden._look._core_material`, `warden._kit._seam_material`, `warden._kit._open_node`, `warden._kit._lens` at lines `2134–2946`), even though `warden_look.gd:97` already has public `core_material()`! `src/boss/mind_dress.gd:147` and `waking_dress.gd:258` read `warden._charging`; `src/boss/waking.gd:287` reads `warden._pulse_clock`; `src/presentation/enemy_clips.gd:256` reads `enemy.get("_atk")`.
  2. **Combat reach-ins INTO spine**: `src/combat/stakes.gd:157` calls `ctx.run_log._close_ultimate()`; `src/combat/ultimate.gd:834` calls `ctx.player._tag_faces(at)`.
  3. **Internal combat reach-ins INTO `ultimate._*`**: `combat.gd`, `rivet_kit.gd`, `tarn_claw.gd`, and `stakes.gd` reach into `ultimate._knob`, `ultimate._ride`, `ultimate._plan`, `ultimate._leg`, `ultimate._leg_time`, `ultimate._record`, `ultimate._beat_len`, `ultimate._heft_index`, `ultimate._peaked`, `ultimate._beats`, `ultimate._id` (23+ hits).
- fix: Add narrow public read-only accessors on `warden.gd` (`visual_state() -> Dictionary` or `look_node()`/`kit_node()`/`is_charging()`/`pulse_clock()`/`flash_amount()`), `enemy.gd` (`attack_facts()`), `run_log.gd` (`close_ultimate()`), `player_ball.gd` (`tag_faces(at)`), and `ultimate.gd` (`plan_state()`, `knob()`, `record_mut()`, `current_leg()`, `leg_time()`, `beat_len()`).
- files to change: `sketches/core-loop/src/combat/warden.gd`, `warden_look.gd`, `warden_kit.gd`, `enemy.gd`, `ultimate.gd`, `stakes.gd`, `rivet_kit.gd`, `tarn_claw.gd`, `combat.gd`, plus callers in `src/presentation/hero_assets.gd`, `enemy_clips.gd`, `src/boss/mind_dress.gd`, `waking_dress.gd`, `waking.gd`, `src/core/run_log.gd`, `src/movement/player_ball.gd`.
- size: ~+65 / -45 lines.
- risk: low (pure accessor encapsulation).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/dress_coverage_test.gd`, `sketches/core-loop/tests/enemy_clips_test.gd`, `sketches/core-loop/tests/ultimate_set_piece_test.gd`, `sketches/core-loop/tests/rivet_set_piece_test.gd`, `sketches/core-loop/tests/tarn_set_piece_test.gd`.
- guard: `scripts/deep-sweep.mjs` D2 reach-in check.

### COMBAT-18 Deduplicate 6 exact copy-pasted helper functions inside `src/combat/`
- kind: A
- evidence: Automated body-equivalence scan across all 113 combat files verified 6 exact duplicate implementations:
  1. `combat.gd:3006` `_relic_overdrive(slot)` and `relic_swaps.gd:211` `_overdrive_for(slot)` — identical 4-line `Relics.held(ctx.run.parts)` overdrive lookup.
  2. `combat.gd:5659` `_part_synergy_info(part_id)` and `orbital_satellites.gd:324` `_part_info(part_id)` — identical 4-line `Parts.def(part_id)` `{"tags", "bits"}` extractor.
  3. `miniboss.gd:600` `hazard_stripe()` and `swarm_remnant.gd:248` `hazard_stripe()` — identical 7-line `StandardMaterial3D` triplanar stripe material builder (with separate `static var _hazard_stripe` caches in both files).
  4. `drill_crew.gd:271` `take_damage(amount)` and `plated_brute.gd:554` `take_damage(amount)` — identical 5-line `_absorb` consumption override.
  5. `miniboss.gd:301` `_fill(value)` and `rogue.gd:354` `_fill(value)` — identical 3-line telegraph progress setter.
  6. `warden.gd:632` `_offset_of(entry)` and `warden_mind.gd:141` `_point(entry)` — identical 8-line `Vector3`-or-3-element-`Array` parser.
- fix: Move `_fill` into `enemy.gd` (base class of both `miniboss` and `rogue`), move `hazard_stripe()` onto `Threat.Painter` (which already owns `stripe_texture()`), move `_offset_of` onto `warden.gd` as public static `parse_point(entry)`, expose `Relics.overdrive_for_slot(parts, slot)` / `Parts.synergy_info(part_id)` on the owning schema modules, and move the `_absorb` guard into `counter.gd` (base class of both `drill_crew` and `plated_brute`).
- files to change: `sketches/core-loop/src/combat/combat.gd`, `relic_swaps.gd`, `orbital_satellites.gd`, `miniboss.gd`, `swarm_remnant.gd`, `threat_grammar.gd`, `drill_crew.gd`, `plated_brute.gd`, `counter.gd`, `rogue.gd`, `enemy.gd`, `warden.gd`, `warden_mind.gd`.
- size: ~+25 / -60 lines (and removes 1 `L14_STATIC_VAR_BASELINE` entry for `_hazard_stripe`).
- risk: low (pure deduplication of identical bodies).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/w50_isaac_relics_test.gd`, `sketches/core-loop/tests/w50_isaac_parts_test.gd`, `sketches/core-loop/tests/dig_plated_elite_test.gd`, `sketches/core-loop/tests/enemy_counters_test.gd`, `sketches/core-loop/tests/dress_mnd_assets_test.gd`.
- guard: None needed beyond code review.

### COMBAT-19 Delete shallow pass-through wrappers where deletion removes indirection without spreading complexity
- kind: D
- evidence: Applying the deletion test to `scripts/deep-sweep.mjs` D1 leads across `src/combat/`:
  1. `sketches/core-loop/src/combat/actives/active_fx.gd` (7 lines total): single function `static func peak(color: Color) -> Color: return Color(color, FlashGuard.info(color.a))` — exists solely to wrap `presentation/flash_guard.gd` for the 8 actives. Once `FlashGuard` moves to `src/core/` (COMBAT-01) and `FlashGuard.tint(color)` (or `peak`) lives there, `active_fx.gd` disappears completely (note: `tests/active_flashes_test.gd:6,149` and `tests/flash_comfort_test.gd:99` reference it and must be updated in the same PR).
  2. `sketches/core-loop/src/combat/combat.gd:2408-2433` (7 single-line public-to-private pass-throughs: `nearest_enemies` -> `_nearest_list`, `apply_heat` -> `_heat`, `post_consumable_buff` -> `_post_consumable_buff`, `clear_buff` -> `_clear_buff`, `synergy_context` -> `_synergy_context`, `shot_bits` -> `_shot_bits`, `floor_at` -> `_floor_at`): simply renaming the private bodies to the public names deletes 28 lines of dead indirection.
  3. `sketches/core-loop/src/combat/fleet.gd:187` `discover(id, at)` -> `combat._discover(id, at)` (1 line, forwarding to a private reach-in on `combat`).
  4. `sketches/core-loop/src/combat/bolts.gd:50` `bolt_mesh()` -> `CraftedGear.bolt_dart_mesh()` (1 line).
- fix: Rename the 7 `combat.gd` private functions directly to their public names (part of COMBAT-06); fold `active_fx.gd` into `core/flash_guard.gd` (part of COMBAT-01); inline `fleet.gd:187` once `combat.discover` is public.
- files to change: `sketches/core-loop/src/combat/combat.gd`, `actives/active_fx.gd` (delete, with owner go-ahead per AGENTS.md), 8 active files, `fleet.gd`, `bolts.gd`, `tests/active_flashes_test.gd`, `tests/flash_comfort_test.gd`.
- size: ~+10 / -65 lines.
- risk: low (mechanical inlining; note AGENTS.md requires owner go-ahead before deleting `active_fx.gd`).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/active_flashes_test.gd`, `sketches/core-loop/tests/flash_comfort_test.gd`, `sketches/core-loop/tests/w50_isaac_parts_test.gd`.
- guard: `scripts/deep-sweep.mjs` D1 pass-through detector.

### COMBAT-20 Centralize scattered combat constants: `GRAVITY`, `"enemy"` group string, and raw physics layer literals
- kind: E
- evidence:
  1. `const GRAVITY := 26.0` is independently declared in **4 combat files** (`git grep -n 'const GRAVITY :=' -- sketches/core-loop/src/combat`: `enemy.gd:19`, `projectile.gd:11`, `sticky.gd:7`, `ultimate.gd:50`), plus a divergent `const GRAVITY := 24.0` inside `plated_brute.gd:486`.
  2. The group name `"enemy"` is spelled as a raw string literal in **33 combat files** (`get_nodes_in_group("enemy")` in 29 files, `is_in_group("enemy")` in 3 files, `add_to_group("enemy")` in 1 file) with no `Enemy.GROUP` constant (contrast `Threat.GROUP := "threat"` in `threat_grammar.gd`, which is already centralized!).
  3. Raw collision layer/mask bit literals (`collision_layer = 0`, `collision_layer = 1`, `collision_mask = 0`) appear across 8 combat files (`burrower.gd`, `crew_fitter.gd`, `dispatcher.gd`, `drill_crew.gd`, `enemy.gd`, `flail.gd`, `stakes.gd`, `warden_swarm.gd`) instead of named layer constants (`Augments.WORLD_MASK` etc., which `ultimate.gd` and `rivet_kit.gd` already use).
- fix: Export `Enemy.GROUP := "enemy"` and `Enemy.GRAVITY := 26.0` (keep `plated_brute.gd`'s local `24.0` explicitly named `HURL_GRAVITY` so tuning is untouched) and use named physics layer constants from `src/core/` or `src/movement/augments.gd`.
- files to change: `sketches/core-loop/src/combat/enemy.gd` plus 32 combat files (or incremental sweep as files are touched).
- size: ~+5 / -5 lines net across files.
- risk: low (pure constant substitution; keep `plated_brute.gd:486` at `24.0` to avoid any physics change).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/spine_run_test.gd`, `sketches/core-loop/tests/int_arena_standdown_test.gd`, `sketches/core-loop/tests/enemy_counters_test.gd`.
- guard: `scripts/deep-sweep.mjs` D4 (string keys spelled in 3+ files).

## Not findings
- `sketches/core-loop/src/combat/warden_reactor.gd` has 0 static `preload()` references in `src/`, but it is NOT dead: `warden.gd:549` loads it dynamically via `"res://src/combat/warden_%s.gd" % fam`.
- `sketches/core-loop/src/combat/combat.gd:158` `var _cooldown: float:` looks unused inside `combat.gd`, but it is a deliberate getter/setter forwarding to `weapon_driver.cooldown_s()` kept as a test seam for `cannon_kit_test.gd`, `cannon_line_lane_test.gd`, `tally_kit_test.gd`, and `w45_tally_relics_test.gd`.
- `sketches/core-loop/src/combat/floor_rule.gd` (7 lines) is tiny, but it is NOT shallow: 7 combat files share its exact `FLOOR_NORMAL_Y := 0.9` + `not carving` rule; deleting it would duplicate the rule across 7 callers.
- `sketches/core-loop/src/combat/combat.gd`'s 8 raw pilot ID comparisons (`kest_kit.gd`, `rivet_kit.gd`, `tarn_claw.gd` 1 each) are already baselined and tracked by `scripts/sketch-lint.mjs` rule `L11` (`ID_COMPARE_LEGACY`).
- `sketches/core-loop/src/combat/kest_kit.gd`'s direct ball-body placement is already tracked and justified by `scripts/sketch-lint.mjs` rule `L10` (`HAND_MOVED`).
- Fault switches `pack_pressure.gd:28 lead_plant`, `warning_bound.gd:12-13 test_pad_scale`/`test_skip_hazard_merge`, and `terrain_faces.gd keep_one_placement` are deliberate test fault-injection hooks already guarded by `scripts/sketch-lint.mjs` rule `L12` (`FAULT_SWITCHES`).
- `sketches/core-loop/src/combat/combat.gd:1378 register_part` and ~40 other getters (`live_projectiles`, `micro_mutation_count`, `kinetic_pylon_state`, `bolts.gd:drawn_position`, etc.) have 0 `src/` callers because they are active test-only/tool-only seams verified in `tests/` and `tools/`.
- `sketches/core-loop/src/combat/sight.gd:39,43` (`add_external_accel`, `crowd_control`) are 1-line pass-throughs by design: `Sight` is a documented proxy (`CONTRACTS.md:493`) that hides the real `player` node while cloaked.
- `sketches/core-loop/src/combat/threat_grammar.gd` (1,606 lines) has 0 instance vars and cohesive internal `Painter` / geometry-descriptor logic shared by both `combat/telegraph.gd` and `boss/hazard.gd` (`CONTRACTS.md:480`); splitting it now would add seam churn with low payoff.
- `sketches/core-loop/src/combat/damage_door.gd` (95 lines) is a clean deep module with a small interface (`pass_hit`, `hook`, `unhook`) and zero outward dependencies; keep as-is.

## Needs the owner
- Reconcile the conflicting armour-effectiveness tables between `src/combat/damage_families.gd` (`plated` resists `kinetic` 0.6x and is weak to `arc` 1.25x) and `src/build/elements.gd` (`LAYER_MULT["armour"]` gives `kinetic` 1.5x and `arc` 0.75x): unifying the multipliers changes gameplay balance and needs a product call.
- Harmonize the three default enemy hull radii (`0.6` in `actives/glass_lance.gd` and `actives/scrap_rockets.gd`, `0.9` in `orbital_satellites.gd`, `1.0` in `combat.gd`/`sticky.gd`) if uniform hitbox forgiveness is desired (changes hitbox edge by up to 0.4 m on radius-less bodies).
- Decide whether `src/combat/combat.gd:1370-1375` (`would_crush`) should include the `impact_force_2x` run override that `_door_caps` (`combat.gd:715`) applies (currently `would_crush` under-predicts crush kills when that override is on).
- Go-ahead to delete `sketches/core-loop/src/combat/actives/active_fx.gd` (AGENTS.md requires owner approval for file deletions) once `FlashGuard` moves to `src/core/`.
- Decide whether `CONTRACTS.md`'s rule against module-to-module preloads should be tightened to allow pure schema modules in `src/core/` (COMBAT-16) and whether `src/combat/combat.gd`'s legacy `transformer_info` / `register_part` API documented in `src/combat/README.md` should be retired.
