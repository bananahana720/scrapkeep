# Structure survey: world
commit: 23e935514ef33e7eb58d50e21bd2a5f757f41fa9   model: Gemini 4 Neon (high)   files read: 38 (direct) + 111 (automated AST/grep survey)   date: 2026-11-27

## Module map
sketches/core-loop/src/world/activities.gd | 2636 | Plans, pre-builds, ticks and pays all stage activity sites, pockets, stocktake yards, mend wards and lore plates | `sites`, `wards`, `plates`, `_graph`, `_draw_layout`, `_prep`, `_ahead`, `_mark_pools`, `_keep_rows`, `stage_modifier`, static `_shared_graphs`/`_parts`/`_find_wet`/`_interior_block`/`_wall` | `world/world.gd`, `world/contraptions.gd`, `world/pockets/pocket_draw.gd`, `world/park/park_map.gd`, 33 tests
sketches/core-loop/src/world/park/park_recipes.gd | 1989 | Places authored park geometry rows, landmarks, sensor triggers, anchor-post fields, cover tags and batched `Placer` builds | 14 static caches/locks (`_budgets`, `_origins*`, `_ends`, `_tiles`, `_anchor_meshes`, `_anchor_fit*`, `_anchor_hulls*`, `_beam_roots`, `_anchor_lod_cache`) | `world/terrain.gd`, `world/park/park_map.gd`, `world/camp_hub.gd`, `world/contraptions.gd`, `presentation/park_props.gd`, 53 tests
sketches/core-loop/src/world/contraptions.gd | 1736 | Builds, resets and steps stage contraptions (barges, lifts, launchers, cables, valves, legacy sluice valves, cracked walls, thermals, cinders, glazes) | `barges`, `lifts`, `launchers`, `cables`, `valves`, `sluice_valves`, `walls`, `thermals`, `cinders`, `glazes`, `_slams`, `_puffs`, `_pending_facts`, `_cache_rules`, `_unbuilt` | `world/world.gd`, `world/codex_world.gd`, `presentation/sound_twins.gd`, 16 tests
sketches/core-loop/src/world/camp_hub.gd | 1165 | Builds and drives the 3D camp hub arena, walking stations, pet reactions, NPC crew, feature hosts and HUD station prompt cards | `game`, `ball`, `camp_store`, `root`, `built`, `walking`, `_pieces`, `_zones`, `_inside`, `_prompt_buttons`, `_crew`, `_shelved` | `game.gd`, 4 tests
sketches/core-loop/src/world/director.gd | 1079 | Schedules reinforcement packs, elites, breathers, threat tiers and park pack spawn-point selection | `stage_time`, `credits`, `spike`, `threat`, `arrivals`, `packs`, `build`, `terrain`, static `_parks` | `world/world.gd`, `world/activities.gd`, `world/park/park_schema.gd`, `presentation/bake_warm.gd`, 46 tests
sketches/core-loop/src/world/terrain.gd | 1046 | Owns stage map registry, ground build/park/free lifecycle, height/floor/top_surface queries, cave roofs, overlays and perch read-ahead | `maps`, `stage`, `flood`, `environment`, `bay`, `overlays`, `_roots`, `_heights`, `_holes`, `_under`, `_cave_roofs`, `_grounds`, `_perches`, static `threaded_in_bot_runs` | `world/world.gd`, `combat/fleet.gd`, `presentation/bake_warm.gd`, `presentation/park_props.gd`, 61 tests
sketches/core-loop/src/world/destructibles.gd | 1042 | Builds, grids, shatters and pays heft-gated destructible props and shard pools | `_pieces`, `_order`, `_grid`, `_refused`, `_breaks`, `_shards`, `_queue`, `_scrap_paid`/`_cogs_paid`/`_consumables_paid` | `world/world.gd`, `combat/combat.gd`, `experimental/dynamic_setpieces.gd`, 21 tests
sketches/core-loop/src/world/world.gd | 981 | Module entry point (`setup(ctx)`): wires terrain, flood, director, events, bay, contraptions, interact, activities, locks, rescue and launch | `terrain`, `flood`, `director`, `events`, `event_families`, `contraptions`, `bay`, `ride`, `interact`, `locks`, `activities`, `rescue`, `breach`, `swap_log`, `cinder_heat` | `game.gd`, `world/codex_world.gd`, 5 tests
sketches/core-loop/src/world/park/park_terrain.gd | 915 | Builds chunked park heightfields, Terrain3D regions, holes, undercroft floors and berms (sync or threaded) | `heights`, `holes`, `under`, `tiles`, `berm_rows`, `_bite_mask`, `terrain3d`, static `draw_regions`/`build_tasks` | `world/terrain.gd`, `world/events/event_ground.gd`, `world/events/natural.gd`, `world/scatter.gd`, `presentation/park_props.gd`, 15 tests
sketches/core-loop/src/world/events/natural.gd | 859 | Plans, projects and runs park natural events (flood_fill, drain, flash_flood, cave_in, collapse, impact, lightning) and water/overlay fields | `active`, `_sites`, `_prepared`, `_original_map`, `_overlay_map`, `_water_field`, `_original_flood`, `_audio`, `_world_sound`, `seek`, static `_plans`/`_marks_job` | `world/events/families.gd`, `world/event_director.gd`, `world/activities.gd`, `world/events/industrial.gd`, 9 tests
sketches/core-loop/src/world/park/park_schema.gd | 806 | Validates `scrapkeep-park/1` JSON files and holds park element, landform, event, activity and asset registry rules | static `_registry_ids`, `_registry_read`, `_registry_lock` | `world/park/park_map.gd`, `world/terrain.gd`, `world/event_director.gd`, `world/director.gd`, `world/events/natural.gd`, 35 tests
sketches/core-loop/src/world/event_director.gd | 771 | Schedules both legacy stage events (flood, squall, surge, relay, stampede, terrain swaps) and park family events (`_park_*`) | `rng`, `stage_time`, `flood`, `squall`, `offers`, `terrain`, `_park`, `_park_states`, `_park_families`, static `_prewarmed_stages`/`_prewarmed_scripts` | `world/world.gd`, `world/event_view.gd`, `world/events/natural.gd`, `core/flow.gd`, `core/run_log.gd`, 29 tests
sketches/core-loop/src/world/events/event_ground.gd | 717 | Projects event mark/water/overlay surfaces, cave roofs and read-only terrain snapshots (`Surface`, `OverlayMap`, `Ground`, `Snapshot`) | Stateless module (inner classes hold projected meshes, swaps, profiles, copied height grids) | `world/terrain.gd`, `world/events/natural.gd`, `world/events/industrial.gd`, `world/events/fleet.gd`, `world/events/ancient.gd`, 7 tests
sketches/core-loop/src/world/scatter.gd | 697 | Scatters chunked or immediate instanced ground clutter/props respecting keep-outs and slopes | Stateless module (builds `MultiMeshInstance3D` nodes under stage root) | `world/terrain.gd`, 2 tests
sketches/core-loop/src/world/sluice_valves.gd | 650 | Builds and runs grapple-yanked sluice valves and surge lanes from `m.contraptions` `sluice_valve` specs | `ctx`, `cruise`, `valves`, `_ground`, `_scene_cache`, `_water_mat`, `_events_wired`, `_stage_root` | `world/flood.gd`, 1 test
sketches/core-loop/src/world/bay.gd | 605 | Builds and steps Moss's hover-barge workshop bay, cradle catch/launch, deck yard, jukebox and bay lap toy | `docked`, `inside`, `banked`, `facing`, `cradle_at`, `visits`, `jukebox`, `lap`, `_barge`, `_prompt` | `world/world.gd`, `world/codex_world.gd`, 7 tests
sketches/core-loop/src/world/map_gorge.gd | 594 | Legacy procedural gorge `StageMap` (not in any stage table) plus `SWAP_PARK`, `crater_profile` and `rubble_profile` helpers | `landmark`, `contraptions`, `terrain_sites`, `swaps`, `start_overlays`, `marble_path` | `world/map_reach.gd` (extends), `world/terrain.gd`, `world/events/event_ground.gd`, 13 tests
sketches/core-loop/src/world/stage_locks.gd | 590 | Runs park stage-lock yard enclosures, wave pips, barrier spring walls, overtime bell and warden-gate refusal | `row`, `cleared`, `gate_open`, `lock_state`, `lock_centre`, `_packs`, `_crew`, `_wave`, static `active` | `world/world.gd`, `world/park/park_map.gd`, `presentation/sound_twins.gd`, 12 tests
sketches/core-loop/src/world/park/sockets.gd | 577 | Offline socket-closure validator and seeded socket-draw laboratory (0 `src/` callers) | Stateless module | `tools/park_sockets.gd`, `tests/park_sockets_test.gd` (0 `src/` callers)
sketches/core-loop/src/world/park/park_graph.gd | 552 | Reads/writes binary `graph.bin` navigation lattices, zone partitions and shortest-path queries for park maps | `px`, `py`, `pz`, `node_flags`, `node_rows`, `names`, `off`, `to`, `length`, `ride`, `zone_table` | `world/park/park_map.gd`, `world/activities.gd`, `world/director.gd`, `world/pockets/pocket_draw.gd`, 37 tests
sketches/core-loop/src/world/stake_devices.gd | 541 | Implements pocket trade/risk `Device` subclasses (`trade_chest`, `blood_shrine`, `healing_ward`) | `kind`, `offer`, `last`, `spot_owner`, `_offered`, `_pulse`, static `_cast`/`_glow`/`_bolt`/`_chalk` | `world/activities.gd`, `world/interact.gd`, `build/build.gd`, 9 tests
sketches/core-loop/src/world/cracked_cache.gd | 526 | Implements ram/slam-opened cache wall `Device`, pedestals, relic rolls, consumable drop and keeper flag | `state`, `offers`, `taken`, `consumable_dropped`, `relic_guaranteed`, `_wall`, `_lid`, `_pedestals`, static `_shared`/`_loaded` | `world/activities.gd`, `world/interact.gd`, `world/contraptions.gd`, `combat/plated_brute.gd`, `presentation/site_markers.gd`, 10 tests
sketches/core-loop/src/world/park/park_map.gd | 455 | `StageMap` adapter over `scrapkeep-park/1` JSON files: derives spawn, beacon, contraptions, fight sites, handover and footprints | `path`, `ok`, `errors`, `park`, `landmark`, `contraptions`, `bay_dock`, `reach_m`, `rescue_sites`, `survival_sites`, `approach`, `_ride_lines` | `world/terrain.gd`, `world/events/natural.gd`, `world/event_director.gd`, `presentation/park_props.gd`, `core/flow.gd`, 68 tests
sketches/core-loop/src/world/rescue_site.gd | 423 | Builds and drives pilot-rescue cage devices and keeper scarf animation on park rescue sites | `ctx`, `system`, `cages`, `_done`, static `model_path`/`scarf_path`/`_shared`/`_warned` | `world/world.gd`, 14 tests
sketches/core-loop/src/world/bowl_approach.gd | 416 | Builds and steps the Slag Bowl approach weighbridge gantry, tag racks, burst crates and furnace stacks | `ctx`, `racks`, `bridge`, `furnace`, `crates_burst`, `clusters_paid`, `weighed`, `_puffs`, `_piece_models` | `world/world.gd`, `world/survey_posts.gd`, 2 tests
sketches/core-loop/src/world/camp_trial.gd | 416 | Builds and runs the camp time-trial checkpoint track, medal timer, ghost replay mesh and guide lamps | `hub`, `records`, `run`, `recorder`, `timer_label`, `ghost_mesh`, `lamps`, `_sensors` | `world/camp_hub.gd`, 2 tests
sketches/core-loop/src/world/trade_pockets.gd | 416 | Pure rules and weighted selection for trade-pocket families (risk/safe counters, contracts, door words, payouts) | Stateless module | `world/activities.gd`, `world/pockets/pocket_draw.gd`, `build/build.gd`, `core/run_state.gd`, 9 tests
sketches/core-loop/src/world/camp_sandbox.gd | 404 | Runs the camp enemy-testing sandbox yard (spawns enemies directly via combat scripts, tracks hull/wrecks/clears) | `hub`, `game`, `ctx`, `combat`, `ground`, `live`, `hull`, `wrecks`, `clears`, `_slots`, `_shells` | `world/camp_hub.gd`, `ui/camp_enemy_picker.gd`, 2 tests

## Outward dependencies
- `src/core/`: 85 preloads/loads + 5 `class_name` refs (90 total) — `core/palette.gd` (39), `core/event_kinds.gd` (12). (expected downward dependency)
- `src/presentation/`: 71 preloads/loads + 4 `class_name` refs (75 total) — `presentation/craft_prop_meshes.gd` (10), `presentation/recipe_props.gd` (7). **[WRONG DIRECTION: lower layer -> presentation]**
- `src/combat/`: 31 preloads — `combat/threat_grammar.gd` (6), `combat/silt_boil.gd` (3). **[CROSS-MODULE: `CONTRACTS.md` forbids peer module preloads]**
- `src/ui/`: 19 preloads/loads — `ui/ui_fonts.gd` (5), `ui/world_prompt.gd` (3). **[WRONG DIRECTION: lower layer -> UI]**
- `src/build/`: 15 preloads/loads — `build/parts.gd` (7), `build/item_gen.gd` (3). **[CROSS-MODULE: peer module preloads]**
- `src/movement/`: 11 preloads — `movement/speed_tier.gd` (5), `movement/augments.gd` (4). (spine layer; 3 of 4 `augments.gd` preloads exist only for `WORLD_MASK`/`SLAM_KNOCK`)
- `src/boss/`: 5 preloads — `boss/hazard.gd` (5). **[WRONG DIRECTION / CROSS-MODULE: world -> boss]**
- Autoloads: 0 (`sketches/core-loop/project.godot` has no `[autoload]` entries).

## Findings

### WORLD-01 Dead stubs, zero-`src`-caller park/world modules, and 4 unused preloads
- kind: B
- evidence:
  - 1-line empty stubs (`extends RefCounted`) with 0 callers anywhere: `sketches/core-loop/src/world/park/flume_piers.gd:1`, `sketches/core-loop/src/world/park/grapple_footing.gd:1`. `git grep -n "park/flume_piers" sketches/core-loop scripts` -> 0 hits; `git grep -n "park/grapple_footing" sketches/core-loop scripts` -> 0 hits.
  - Tool+test-only (0 `src/` callers): `sketches/core-loop/src/world/park/sockets.gd` (577L). `git grep -n "park/sockets.gd" sketches/core-loop scripts` -> 2 hits (`tools/park_sockets.gd:4`, `tests/park_sockets_test.gd:8`).
  - Test-only (0 `src/`, 0 `tools/` callers): `sketches/core-loop/src/world/park/risk_sites.gd` (249L, `git grep -n "park/risk_sites.gd" sketches/core-loop scripts` -> 2 hits, both in `tests/park_risk_sites_test.gd`); `sketches/core-loop/src/world/events/weather.gd` (61L, `git grep -n "events/weather.gd" sketches/core-loop scripts` -> 1 hit, `tests/park_weather_test.gd`); `sketches/core-loop/src/world/zone_seed.gd` (50L, `git grep -n "world/zone_seed.gd" sketches/core-loop scripts` -> 3 hits, all in `tests/`); `sketches/core-loop/src/world/park/regions.gd` (27L, `git grep -n "park/regions.gd" sketches/core-loop scripts` -> 2 hits: `tests/park_regions_test.gd` and its L14 reset entry in `scripts/sketch-lint.mjs:1089`).
  - Unused `const ... := preload(...)` imports: `sketches/core-loop/src/world/director.gd:7` (`Tuning`), `sketches/core-loop/src/world/events/natural.gd:14` (`Gorge`), `sketches/core-loop/src/world/park/park_recipes.gd:7` (`MaterialSlots` — shadowed by `Placer`'s own preload at `L1806`), `sketches/core-loop/src/world/stake_devices.gd:3` (`Altar`).
- fix: Remove the 4 unused preloads immediately. With owner go-ahead (per `AGENTS.md` delete rule), delete the two 1-line stubs `flume_piers.gd` and `grapple_footing.gd`, move `park/sockets.gd` under `tools/` beside its sole caller `tools/park_sockets.gd`, and either wire or retire `events/weather.gd`, `park/risk_sites.gd`, `park/regions.gd` and `zone_seed.gd` (removing `regions.gd` from `scripts/sketch-lint.mjs:1089` if retired).
- files to change: `sketches/core-loop/src/world/director.gd`, `sketches/core-loop/src/world/events/natural.gd`, `sketches/core-loop/src/world/park/park_recipes.gd`, `sketches/core-loop/src/world/stake_devices.gd` (immediate); plus the 7 zero-`src`-caller files and their 6 test/tool files after delete go-ahead.
- size: -4 lines immediate; up to -966 lines moved/removed from `src/world/` with go-ahead.
- risk: low — unused preloads and 0-caller stubs have zero runtime effect; moving `sockets.gd` only updates 2 paths.
- behaviour-preserving: yes — none of these symbols are reached by live play or any other `src/` module.
- tests that cover it: `sketches/core-loop/tests/park_sockets_test.gd`, `sketches/core-loop/tests/park_risk_sites_test.gd`, `sketches/core-loop/tests/park_weather_test.gd`, `sketches/core-loop/tests/park_regions_test.gd`, `sketches/core-loop/tests/zone_schema_test.gd`, `sketches/core-loop/tests/dig_zone_test.gd`, `sketches/core-loop/tests/dig_deep_zone_test.gd`.
- guard: Add a `sketch-lint.mjs` rule flagging unused `const ... := preload(...)` aliases and `src/` `.gd` files with 0 `src/` callers (with an explicit allowlist for entry points like `game.gd`).

### WORLD-02 Dual sluice-valve implementations fighting over the same `kind == "sluice_valve"` rows
- kind: A
- evidence:
  - `sketches/core-loop/src/world/contraptions.gd:20-110, 126, 203, 268-270, 330-392, 1152-1581` (~500 lines) builds, registers (`SluicePayDevice`), steps, telegraphs and surges every `kind == "sluice_valve"` entry in `m.contraptions`.
  - `sketches/core-loop/src/world/sluice_valves.gd:1-650` (hosted as a child of `world/flood.gd:69-82`) reads the exact same `m.contraptions` rows where `kind == "sluice_valve"` (`sluice_valves.gd:85-93`), builds a second set of valve bodies/wheels/hazards, and calls `_hide_legacy_wheels(stage)` (`sluice_valves.gd:182-197`) to walk `ctx.world.contraptions[stage]` and hide `valve_wheel*` meshes.
  - `contraptions.gd` checks `_delegated_to_grapple_sluice(id)` (`contraptions.gd:380-392`) at 7 sites (`L368, L450, L1290, L1301, L1335, L1504, L1551`) to skip its own copy whenever `flood.sluice_valves` owns the same ID.
  - Caller count: `git grep -n "sluice_valves" sketches/core-loop/src sketches/core-loop/tests` -> 22 hits in `contraptions.gd`, 5 in `flood.gd`, 1 test (`grapple_sluice_valve_test.gd`), plus 2 tests touching `contraptions.sluice_valves` (`greybox_eradication_test.gd:269`, `visual_polish_regression_test.gd:41`).
- fix: Pick one owner for `kind == "sluice_valve"`: keep `sluice_valves.gd` (the live grapple-yanked implementation, moved directly under `world.gd` instead of piggybacking on legacy `flood.gd`), remove the ~500 lines of `SluicePayDevice` / `sluice_valves` / `_delegated_to_grapple_sluice` from `contraptions.gd`, and delete `_hide_legacy_wheels` from `sluice_valves.gd`. (Alternative: have `contraptions.gd` delegate construction to `SluiceValves` directly so `contraptions.gd` never builds duplicate geometry, keeping `contraptions.sluice_valves` only if `works_surge_test.gd` still tests the pay-valve path — verify whether pay-valve is still wanted first.)
- files to change: `sketches/core-loop/src/world/contraptions.gd`, `sketches/core-loop/src/world/sluice_valves.gd`, `sketches/core-loop/src/world/flood.gd`, `sketches/core-loop/src/world/world.gd`, `sketches/core-loop/tests/greybox_eradication_test.gd`, `sketches/core-loop/tests/visual_polish_regression_test.gd`.
- size: -520 / +30 lines.
- risk: medium — touches hazard timing and `world_telegraphs` reporting checked by `works_surge_test.gd` and `grapple_sluice_valve_test.gd`.
- behaviour-preserving: yes for live park stages (where `_delegated_to_grapple_sluice` already suppresses `contraptions.gd`'s copy); verify `works_surge_test.gd` (which tests `contraptions.gd` standalone without `flood.sluice_valves`).
- tests that cover it: `sketches/core-loop/tests/grapple_sluice_valve_test.gd`, `sketches/core-loop/tests/works_surge_test.gd`, `sketches/core-loop/tests/greybox_eradication_test.gd`, `sketches/core-loop/tests/visual_polish_regression_test.gd`.
- guard: Add a unit check asserting each contraption `kind` in `park_schema.gd` has exactly one builder.

### WORLD-03 `events/natural.gd` hijacks `ctx.events.world_fact` and calls private `presentation.audio._admit`/`_start`
- kind: C
- evidence:
  - `sketches/core-loop/src/world/events/natural.gd:15-18` preloads 4 presentation modules (`presentation/audio.gd`, `presentation/sfx_bank.gd`, `presentation/rows.gd`, `presentation/harmony.gd`).
  - `sketches/core-loop/src/world/events/natural.gd:130-138` fetches `world.ctx.root.get("presentation").audio`, inspects `world.ctx.events.get_signal_connection_list("world_fact")`, disconnects audio's listener, and inserts `_on_world_sound` in front of it (reconnecting in `release()` at `L847-849`).
  - `sketches/core-loop/src/world/events/natural.gd:813-824` intercepts `EventDirector.PARK_LAND_FACTS` keys/values and calls private `_audio._admit("world_fact", sound, pitch)` and `_audio._start(...)` directly.
- fix: Move the `PARK_LAND_FACTS` immediate-playback rule into `src/presentation/audio.gd`'s own `world_fact` handler (keyed by an `"immediate": true` flag on those rows in `src/core/event_kinds.gd`, or by reading `EventKinds.WORLD_ROWS`). Delete `_on_world_sound`, `_audio`, `_world_sound`, the signal-disconnect dance, and all 4 presentation preloads from `natural.gd`.
- files to change: `sketches/core-loop/src/world/events/natural.gd`, `sketches/core-loop/src/core/event_kinds.gd`, `sketches/core-loop/src/presentation/audio.gd`.
- size: -32 / +10 lines.
- risk: low — audio routing only; no physics, RNG, or signal-order change on simulation signals.
- behaviour-preserving: yes — identical sound id, trim dB, priority dB, pitch and bus (`"SFX"`) are played on the same `world_fact` signal.
- tests that cover it: `sketches/core-loop/tests/park_cave_in_test.gd`, `sketches/core-loop/tests/park_natural_projection_test.gd`, `sketches/core-loop/tests/presentation_sfx_test.gd`, `sketches/core-loop/tests/sound_twins_test.gd`.
- guard: Extend `scripts/deep-sweep.mjs` / `sketch-lint.mjs` to ban `src/world/` preloading `src/presentation/audio.gd`, `sfx_bank.gd`, `rows.gd`, or `harmony.gd`, and flag `get_signal_connection_list` outside tests.

### WORLD-04 Triplicated 70-line GLB slot/mesh loader across `ambush_altar.gd`, `bet_crate.gd` and `cracked_cache.gd`
- kind: A
- evidence:
  - Identical `_slot_material(slot)` (`["device_concrete", "device_metal", "device_marks"]`), `_parts()` (instantiates `MODEL`, validates `MeshInstance3D` surfaces + `ARRAY_VERTEX`/`ARRAY_COLOR`, accumulates ancestor `Transform3D`, validates `REQUIRED`, caches in `static var _shared`/`_loaded`), and `_model_part`/`_attach` exist verbatim in:
    - `sketches/core-loop/src/world/ambush_altar.gd:18-19, 128-198` (73 lines)
    - `sketches/core-loop/src/world/bet_crate.gd:20-21, 113-183` (73 lines)
    - `sketches/core-loop/src/world/cracked_cache.gd:73-75, 389-473` (85 lines; differs only by a 4-line `StageMap.dressed_surface` hook for `FINISH` at `L435-439`)
  - Meanwhile `sketches/core-loop/src/world/model_kit.gd` (80L) already serves as the shared GLB part loader for `activities.gd`, `bay.gd`, `radio_cache.gd`, `flood.gd`, `stocktake_dress.gd`, `survey_posts.gd`, `bowl_approach.gd`, and `find_kit.gd`; `rescue_site.gd:265-350` and `sluice_valves.gd:322-355` implement two more ad-hoc GLB loaders.
- fix: Add one parameterized helper (`ModelKit.device_parts(model_path, required, finish_table := {})` + `ModelKit.attach_part(...)`) to `src/world/model_kit.gd` (preserving exact `ARRAY_COLOR` validation, ancestor transform accumulation, slot roughness/metallic values, and optional `StageMap.dressed_surface`), and replace all three copies in `ambush_altar.gd`, `bet_crate.gd`, and `cracked_cache.gd` with one-line calls. (Also removes 3 per-file `static var _shared`/`_loaded` reset pairs.)
- files to change: `sketches/core-loop/src/world/model_kit.gd`, `sketches/core-loop/src/world/ambush_altar.gd`, `sketches/core-loop/src/world/bet_crate.gd`, `sketches/core-loop/src/world/cracked_cache.gd`, `sketches/core-loop/tools/test_batch_driver.gd` (if those static vars are registered there).
- size: -215 / +75 lines.
- risk: low — pure mesh/material loading at build time; no simulation or RNG impact.
- behaviour-preserving: yes — produces identical duplicated `Mesh` surfaces, materials, transforms, and greybox fallback warnings.
- tests that cover it: `sketches/core-loop/tests/device_props_asset_test.gd`, `sketches/core-loop/tests/world_ambush_test.gd`, `sketches/core-loop/tests/world_bet_test.gd`, `sketches/core-loop/tests/cracked_cache_test.gd`, `sketches/core-loop/tests/test_batch_reset_test.gd`.
- guard: Keep all device GLB loaders in `model_kit.gd`; new `find_children("*", "MeshInstance3D"` loops in `src/world/` reviewed against `ModelKit`.

### WORLD-05 `contraptions.gd` spawns a headless `Activities` node solely to call 3 private `Activities` methods
- kind: C
- evidence:
  - `sketches/core-loop/src/world/contraptions.gd:237-244` instantiates `_cache_rules = Activities.new()`, sets `_cache_rules.ctx = owner_node.get("ctx")` and `_cache_rules.set_physics_process(false)`, and adds it as a child.
  - `contraptions.gd` then calls three underscore-private methods on `_cache_rules`:
    - `contraptions.gd:304`: `_cache_rules._build("cracked_cache", cache["at"], room)` (then immediately calls `s.wall.free(); s.view.hide()` at `L305-307`!)
    - `contraptions.gd:316`: `_cache_rules._finish(s, s.pedestal)`
    - `contraptions.gd:1127` and `contraptions.gd:1628`: `_cache_rules._watch_pickup(v["cache_site"], ball)` / `_cache_rules._watch_pickup(w["cache_site"], ball)`
  - `git grep -n "_cache_rules" sketches/core-loop/src` -> 9 hits, all in `contraptions.gd`.
- fix: Extract the cache-pedestal build/finish/pickup logic (`_build_cache`, `_finish`, `_watch_pickup`, `_pay_*`) into a focused `src/world/cache_pedestal.gd` helper (or public API on `cracked_cache.gd` / the extracted seam from `WORLD-10`), and have both `activities.gd` and `contraptions.gd` call it directly without constructing a wall just to free it or spawning a dormant `Activities` node.
- files to change: `sketches/core-loop/src/world/contraptions.gd`, `sketches/core-loop/src/world/activities.gd`, new `sketches/core-loop/src/world/cache_pedestal.gd` (or `cracked_cache.gd`).
- size: -30 / +35 lines (net negative if combined with `WORLD-10`).
- risk: medium — touches reward/pickup payout order (`_finish` draws from `Interact.luck` / part rolls); keep exact seed ID and call sequence.
- behaviour-preserving: yes — same `Site`/pedestal reward roll and pickup radius (`PICKUP_REACH = 1.7`).
- tests that cover it: `sketches/core-loop/tests/activities_test.gd`, `sketches/core-loop/tests/contraptions_materials_test.gd`, `sketches/core-loop/tests/park_recipes_contraptions_test.gd`, `sketches/core-loop/tests/cracked_cache_test.gd`.
- guard: `scripts/deep-sweep.mjs` D2 already flags new `._` reach-ins; promoting D2 to fail on `src/world/` after cleanup prevents recurrence.

### WORLD-06 `world -> ui` wrong-direction dependencies (19 preloads + `game.screens._press` reach-in)
- kind: C
- evidence:
  - 19 `preload`/`load` lines from `src/world/` into `src/ui/` across 10 files:
    - **Pure logic/data misplaced in `src/ui/` (4 preloads, cheapest to invert):**
      - `world/world.gd:24, 957` -> `ui/why_callout.gd` (`WhyCallout.warden_fight_live(ctx.flow)` — also called by `presentation/codex_banner.gd:304` and `presentation/reward_ceremony.gd:409`; reads only `flow.engaged()`)
      - `world/activities.gd:12, 2310` -> `ui/odds_readout.gd` (`OddsReadout.odds_for(rarities, class_id)` — pure loot-table probability math)
      - `world/victory_lap.gd:3, 73` -> `ui/ending_sequence.gd` (`EndingSequence.CRATER_ROW` — static park-row Dictionary constant)
      - `world/cracked_cache.gd:8, 481` -> `ui/ui_tokens.gd` (only reads `UiTokens.reduced_motion` boolean!)
    - **Camp hub building 2D HUD widgets directly inside `src/world/` (9 preloads + 1 private reach-in):**
      - `world/camp_hub.gd:8, 9, 11, 12, 20, 21, 32` -> `ui/keycap.gd`, `ui/glyphs.gd`, `ui/ui_fonts.gd`, `ui/choice_button.gd`, `ui/caller_tile.gd`, `ui/ui_tokens.gd`, `ui/camp_scrapbook.gd`; plus private reach-in `camp_hub.gd:800` `card.pressed.connect(game.screens._press.bind(glyph))` and `camp_sandbox.gd:14, 342-366` (`ui/camp_enemy_picker.gd` / `game.screens.open_walk_page`).
    - **3D `Label3D` font overrides (4 preloads):** `camp_ring.gd:5`, `camp_skee.gd:5`, `camp_trial.gd:5`, `victory_lap.gd:7` -> `ui/ui_fonts.gd`.
    - **Documented `WorldPrompt` seam (4 preloads, leave on seam or move `WorldPrompt` contract):** `bay.gd:7`, `device.gd:4-5` (`glyphs.gd`, `world_prompt.gd`), `event_view.gd:6`.
- fix: Four small independent PRs:
  1. Move `warden_fight_live()` onto `src/core/flow.gd`, `odds_for()` onto `src/build/parts.gd` (re-exporting from `odds_readout.gd` for tests), `CRATER_ROW` onto `src/world/victory_lap.gd` (or `src/core/`), and `reduced_motion` onto `ctx`/settings (`src/core/settings_store.gd` or `Palette`). Eliminates 4 `world -> ui` preloads in ~40 lines.
  2. Move `UiFonts` font-loading helper (`mono()`, `bold()`) into `src/core/fonts.gd` (thin alias left in `src/ui/ui_fonts.gd`). Eliminates 5 more `world -> ui` preloads.
  3. Add a public `screens.press_glyph(glyph)` on `src/ui/screens.gd` (removes `camp_hub.gd:800` reach-in) and extract `camp_hub.gd`'s station card/quip HUD layer (`L745-815, L990-1045`) into `src/ui/camp_hud.gd` listening to `camp_hub` signals.
  4. Keep `WorldPrompt` / `Glyphs` on `device.gd`/`bay.gd`/`event_view.gd` (explicitly blessed by `CONTRACTS.md:354`).
- files to change: `sketches/core-loop/src/world/world.gd`, `activities.gd`, `victory_lap.gd`, `cracked_cache.gd`, `camp_hub.gd`, `camp_ring.gd`, `camp_skee.gd`, `camp_trial.gd`; plus `src/core/flow.gd`, `src/build/parts.gd`, `src/ui/why_callout.gd`, `odds_readout.gd`, `ending_sequence.gd`, `ui_fonts.gd`, `screens.gd`.
- size: ~120 lines moved/rewired across 2–3 PRs.
- risk: low — pure symbol moves and UI signal inversion; no physics, RNG, or save-format change.
- behaviour-preserving: yes — identical font resources, predicates, and button callbacks.
- tests that cover it: `sketches/core-loop/tests/visible_odds_test.gd`, `sketches/core-loop/tests/camp_hub_test.gd`, `sketches/core-loop/tests/camp_sandbox_test.gd`, `sketches/core-loop/tests/ui_contract_test.gd`, `sketches/core-loop/tests/world_interact_test.gd`.
- guard: Add a `sketch-lint.mjs` boundary rule forbidding new `src/world/` preloads of `src/ui/` except the documented `world_prompt.gd` / `glyphs.gd` allowlist.

### WORLD-07 71 `world -> presentation` preloads/loads and `activities._exit_tree()` clearing presentation caches
- kind: C
- evidence:
  - 71 `preload`/`load` lines from `src/world/` into `src/presentation/` across 26 files (plus 4 `class_name` refs to `CampCraftMeshes`/`ModelVariants` and 8 direct `ctx.root.get_node_or_null("Presentation")` / `ctx.root.presentation` lookups). They fall into 3 clean turnaround buckets:
    1. **Pure geometry, material and comfort helpers living in `presentation/` (38 preloads — 54% of the total):** `craft_prop_meshes.gd` (10), `recipe_props.gd` (7), `flash_guard.gd` (6), `fx_library.gd` (4), `enemy_motion.gd` (4, only reading `EnemyMotion.motion_scale`!), `material_slots.gd` (3, 1 unused), `camp_craft_meshes.gd` (3), `destructible_kit.gd` (1), `prop_kicks.gd` (1).
    2. **Direct audio/VFX calls bypassing `GameEvents` (14 preloads + 6 runtime `Presentation` lookups):** `natural.gd` (4 preloads, see `WORLD-03`), `activities.gd:30,32,33,884,1577,2606,2633` (`SfxBank`, `WorldFx`, `WorldFxAnchor`, `presentation.audio.play`), `activity_view.gd:5,96` (`PresentationRows`, `_tell_audio.play`), `events/fleet.gd:4` & `events/rubble_fall.gd:4` (`FoleyAudio`), `stake_devices.gd:11,352` (`SfxBank`, `audio.play_at`), `events/weather.gd:4-5` (`WorldLook`, `WorldFx` — test-only), `world.gd:450,794` (`ctx.root.presentation.audio.park_transport`, `presentation.line_view.set_ride`).
    3. **World invoking presentation scenery, look, and cache-teardown hooks (17 preloads):** `spillway_scenery.gd` (5 inline `load()`s in `activities.gd:1005,1093`, `contraptions.gd:289`, `map_reach.gd:237`, `map_spillway.gd:228`), `graphics_preset.gd` (3: `terrain.gd:943,1046`, `camp_hub.gd:13`), `hero_assets.gd` (2: `camp_hub.gd:19`, `rescue_site.gd:7`), `world_look.gd` (1: `camp_hub.gd:14`), `landmark_proxy.gd` & `landmark_beam.gd` (`park_recipes.gd:9-10`), `bake_look.gd` (`activities.gd:15`), `dig_scenery.gd` (`scatter.gd:6,575` — calling private `DigScenery._relative`), and `activities.gd:388-389` calling `load("res://src/presentation/set_dressing.gd").release_shared()` and `load("res://src/presentation/park_props.gd").release_shared()` inside `Activities._exit_tree()`!
- fix: Three cheapest turnarounds in priority order:
  1. Move `set_dressing.gd` and `park_props.gd` `release_shared()` calls out of `activities.gd:388-389` into `presentation.gd._exit_tree()`; replace `scatter.gd:575`'s `DigScenery._relative` with a 5-line local transform walk (or shared `ModelKit.relative_transform`).
  2. Move pure stateless mesh/material/comfort helpers (`flash_guard.gd`, `material_slots.gd`, `recipe_props.gd`, `craft_prop_meshes.gd`, `motion_scale` comfort flag) to `src/shared/` or `src/core/` (leaving thin re-exports only if tests import old paths). This single layer clarification removes >50% of all `world -> presentation` preloads without changing a single call site's behaviour.
  3. Route `activities.gd` (`_ward_cue`, `read_plate`, `_cue`, `WorldFx.fire`), `activity_view.gd`, `fleet.gd`, `rubble_fall.gd`, and `stake_devices.gd` through `ctx.events.world_fact` / `lore_found` (already on `GameEvents`), and let `presentation.gd` subscribe to `terrain.stage_built` for `graphics_preset` / `spillway_scenery` dressing.
- files to change: 26 files under `sketches/core-loop/src/world/` (staged by bucket: 2 files for bucket 1 cleanup, ~15 files for bucket 2 shared helpers, ~8 files for bucket 3 bus inversion).
- size: ~80 lines moved/changed in bucket 1; ~200 lines re-pointed in bucket 2; ~120 lines in bucket 3.
- risk: low for buckets 1–2 (pure relocation & teardown ownership); medium for bucket 3 (audio cue timing / test listeners on `presentation_sfx_test.gd` and `sound_twins_test.gd`).
- behaviour-preserving: yes — same meshes, materials, lighting bindings, and sound recipes.
- tests that cover it: `sketches/core-loop/tests/presentation_sfx_test.gd`, `sketches/core-loop/tests/sound_twins_test.gd`, `sketches/core-loop/tests/activities_test.gd`, `sketches/core-loop/tests/rescue_cage_test.gd`, `sketches/core-loop/tests/greybox_eradication_test.gd`.
- guard: Add a `sketch-lint.mjs` rule capping/ratcheting `src/world/ -> src/presentation/` preloads to an explicit shrinking allowlist.

### WORLD-08 25+ private reach-ins into `Terrain` and `EventDirector` from `events/` and `activities.gd`
- kind: C
- evidence:
  - `sketches/core-loop/src/world/events/event_ground.gd:109, 115-116, 145-150, 158, 220, 225, 312, 317, 562, 573, 580` reaches into 9 private `Terrain` members (`_heights`, `_holes`, `_under`, `_cave_roofs`, `_is_park`, `_grid_height`, `_retained_park_height`, `_park_height`, `_ensure`, `_floor`) across 18 lines.
  - `sketches/core-loop/src/world/events/natural.gd:288, 290, 732` reaches into `terrain._is_park`, `terrain._roots`, `terrain._heights`, `terrain._cave_roofs`, and directly overwrites `world.terrain.flood = _water_field` (`L129`) and `world.terrain.maps[stage - 1] = _overlay_map` (`L593`, restored at `L850-852`).
  - `sketches/core-loop/src/world/events/natural.gd` calls `EventGround._rectangle(...)` at 11 lines (`L159, 572, 776, 780, 782-783, 785, 799-802`).
  - `sketches/core-loop/src/world/events/families.gd:32` reaches into `director._park_families.clear()`.
  - `sketches/core-loop/src/world/activities.gd:658` calls `ctx.terrain._worker_builds()`.
  - `sketches/core-loop/src/world/terrain.gd:100, 438` calls `ParkSchema._registry()` and `ParkMap._v2(...)`; `world/event_director.gd:515` calls `ParkSchema._lead_floor(...)`; `world/pockets/pocket_draw.gd:204, 210` calls `Placement._within(...)` and `Placement._pay(...)`.
- fix: Promote the legitimate cross-file queries to small public methods on their owners: `Terrain.park_stage_grid(index) -> Dictionary`, `Terrain.cave_roofs(index) -> Dictionary`, `Terrain.stage_root_key(index) -> int`, `Terrain.worker_builds() -> bool`, `Terrain.set_overlay_map(stage, overlay_map)` / `push_flood_field(field)`; `EventDirector.clear_families()`; and drop the leading underscore on cross-module static helpers `EventGround.rectangle`, `ParkMap.v2`, `ParkSchema.warm_registry`/`lead_floor`, `ParkPlacement.within`/`pay`.
- files to change: `sketches/core-loop/src/world/terrain.gd`, `events/event_ground.gd`, `events/natural.gd`, `events/families.gd`, `event_director.gd`, `activities.gd`, `park/park_schema.gd`, `park/park_map.gd`, `park/park_placement.gd`, `pockets/pocket_draw.gd`.
- size: ~70 lines added, ~55 lines edited.
- risk: low — pure visibility/accessor cleanup; no logic, frame order, or worker-thread contract changes (note `EventGround.snapshot` still captures the exact same arrays).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/park_natural_projection_test.gd`, `sketches/core-loop/tests/event_overlays_planned_test.gd`, `sketches/core-loop/tests/natural_marks_planned_test.gd`, `sketches/core-loop/tests/park_cave_in_test.gd`, `sketches/core-loop/tests/perch_ahead_test.gd`.
- guard: Extend `scripts/deep-sweep.mjs` D2 regex to match uppercase `ClassName._method` reach-ins in addition to lowercase `obj._member`, and gate new D2 hits on `src/world/`.

### WORLD-09 Private reach-ins from `camp_hub.gd`, `camp_sandbox.gd`, and `world.gd`
- kind: C
- evidence:
  - `sketches/core-loop/src/world/camp_hub.gd:450, 459-460, 463, 465-466, 479, 482, 610, 623` reaches into 7 private static helpers of `ParkRecipes`: `_load`, `_body`, `_views`, `_range`, `_relative`, `_lift_drawn`, `_band_hull`.
  - `sketches/core-loop/src/world/camp_sandbox.gd:266` connects `shell.returned_landed.connect(combat._on_shell_returned)` (private method on `src/combat/combat.gd`, plus `camp_sandbox.gd:4-12` preloads 9 internal `src/combat/` scripts instead of routing through a `combat.spawn_sandbox_enemy` seam).
  - `sketches/core-loop/src/world/world.gd:878` calls `m._polyline_channel(ball.x, ball.z, m.marble_path, m.MARBLE_HALF, m.MARBLE_WALL)` on `map_gorge.gd` / `map_reach.gd` instead of asking `m.in_marble_chute(ball)`.
- fix: Add one public `ParkRecipes.build_camp_prop(...)` (or expose the shared `load_scene`/`build_body`/`band_hull` helpers publicly on `ParkRecipes`), add public `combat.on_shell_returned` / `map.in_marble_chute(ball: Vector3) -> bool`, and replace the 12 private reach-ins.
- files to change: `sketches/core-loop/src/world/camp_hub.gd`, `sketches/core-loop/src/world/park/park_recipes.gd`, `sketches/core-loop/src/world/camp_sandbox.gd`, `sketches/core-loop/src/combat/combat.gd`, `sketches/core-loop/src/world/world.gd`, `sketches/core-loop/src/world/map_gorge.gd`.
- size: ~35 lines added/changed.
- risk: low — thin method-exposure and delegation cleanup.
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/camp_hub_test.gd`, `sketches/core-loop/tests/camp_sandbox_test.gd`, `sketches/core-loop/tests/invisible_walls_test.gd`, `sketches/core-loop/tests/world_gorge_test.gd` (and `world_reach` / `layer` tests).
- guard: `scripts/deep-sweep.mjs` D2 (extended to uppercase static `._` calls).

### WORLD-10 `activities.gd` (2,636 lines) has 5 clean, already-isolated state seams ready to split
- kind: H
- evidence:
  - `sketches/core-loop/src/world/activities.gd` is 2,636 lines, 149 functions, 30 top-level vars, and one 70-field `Site` inner class (`L219-300`), combining 6 unrelated subsystems. Function-to-variable analysis shows 5 crisp seams where private state is barely shared:
    1. **MendWard & LorePlate (`L302-359` + `L2489-2636`, ~208 lines):** owns `wards` and `plates` exclusively; `activities.gd` only calls `_build_wards_and_plates`, `_watch_ward`, `_watch_plate`, `_on_surface_changed`, and clears both arrays in `clear()`. Zero overlap with `sites`.
    2. **Stocktake Yard & Muster (`L1979-2177`, ~200 lines):** owns `_keep_map`, `_keep_rows`, and `Site.yard*` fields (`L283-292`); wraps `SurvivalCount` and `StocktakeDress`.
    3. **Pocket runtime & interior builder (`L977-1030` + `L1405-1761`, ~410 lines):** owns `_graph`, `_graph_map`, `_draw_layout`, `_draw_map`, `_mark_pools`, `_elite_arrivals`, `_interior_block`, `_wall`, and `Site` pocket/round/mark fields (`L238-267`).
    4. **Cracked-cache / wall / find / door dressing (`L1040-1286` + `L2192-2277`, ~333 lines):** owns `_find_wet`, `FindKit`, wall-break, patch-wire and room-log dressing (extracting this also eliminates `WORLD-05` in `contraptions.gd`!).
    5. **Hold-the-relay & Surge-run controllers (`L1804-1978`, ~175 lines):** owns `Site.relay*` and `Site.surge*` (`L268-282`) wrapping `HoldRelay`, `RelayStake`, and `SurgeCourse`.
- fix: Split in small one-seam-per-PR steps, starting with the cleanest zero-overlap seam: (1) extract `MendWard` + `LorePlate` into `src/world/secrets_sites.gd` (keeps `activities.wards` / `activities.plates` forwarding or moves callers); (2) extract cracked-cache/find dressing into `src/world/cache_sites.gd` (resolving `WORLD-05` simultaneously); (3) extract stocktake yard/muster into `src/world/stocktake_sites.gd`; (4) extract pocket runtime into `src/world/pockets/pocket_runner.gd`. Keep `Activities` as the thin stage-lifecycle orchestrator (~900 lines).
- files to change: `sketches/core-loop/src/world/activities.gd` + up to 4 new sibling modules under `src/world/` (one PR per seam).
- size: ~1,300 lines moved out of `activities.gd` into 4 cohesive modules (net ~+60 lines for headers/wiring).
- risk: low for `MendWard`+`LorePlate` (no RNG/physics interaction with sites); medium for Pocket/Cache/Stocktake seams (keep exact `_physics_process` iteration order and `Interact.luck` seed strings intact).
- behaviour-preserving: yes — pure move-method / extract-collaborator refactoring along existing state boundaries.
- tests that cover it: `sketches/core-loop/tests/activities_test.gd`, `sketches/core-loop/tests/activities_pay_test.gd`, `sketches/core-loop/tests/pocket_draw_test.gd`, `sketches/core-loop/tests/stocktake_yard_test.gd`, `sketches/core-loop/tests/lore_plates_test.gd`, `sketches/core-loop/tests/mend_ward_test.gd` (33+ tests reference `activities.gd`).
- guard: `scripts/deep-sweep.mjs` D5 already flags >1500-line files growing by 100+ lines.

### WORLD-11 `park/park_recipes.gd` (1,989 lines) has a self-contained 625-line Anchor Field / LOD / Hull seam
- kind: H
- evidence:
  - `sketches/core-loop/src/world/park/park_recipes.gd:1098-1723` (626 lines, 34 functions) owns all anchor-post placement, cover-height tagging, procedural LOD simplification (`_anchor_lod_mesh`, `_lod_tri`), anchor-fit boxes, and farthest-point convex band hulls (`_band_hull`, `_farthest_points`).
  - Its 7 private static caches (`_anchor_meshes`, `_anchor_fit`, `_anchor_fit_read`, `_anchor_fit_lock`, `_anchor_hulls`, `_anchor_hull_lock`, `_anchor_lod_cache` at `L157-163, L1420`) are NEVER referenced anywhere outside `L1098-1723`!
  - Only 6 functions from that block are called by the rest of `park_recipes.gd` (`tag_cover`, `is_anchor_field`, `place_anchor_field`, `anchor_kit_ready`, `anchor_paths`, `field_posts` at `L501, 504, 584, 711, 791, 821, 1015, 1726-1727, 1740, 1763, 1780, 1886`).
  - Additionally, the `Placer` inner class (`L1802-1989`, 188 lines) is self-contained and re-preloads `material_slots.gd` at `L1806` (rendering `L7`'s top-level `MaterialSlots` unused).
- fix: Extract `L1098-1723` and its 7 static caches into `src/world/park/park_anchors.gd`, keeping thin forwarding wrappers on `ParkRecipes` only for public functions named in external tests/tools (check `git grep` on each of the 19 public anchor functions), and register `park_anchors.gd` in `test_batch_driver.gd`'s `_reset()` for `_anchor_lod_cache`.
- files to change: `sketches/core-loop/src/world/park/park_recipes.gd`, new `sketches/core-loop/src/world/park/park_anchors.gd`, `sketches/core-loop/tools/test_batch_driver.gd`.
- size: ~630 lines moved (net +25 lines).
- risk: low — pure static geometry/caching functions with mutex-guarded reads; preserve exact float math so anchor-field placements and cover tags do not shift.
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/flume_post_walls_test.gd`, `sketches/core-loop/tests/asset_registry_test.gd`, `sketches/core-loop/tests/park_props_test.gd`, `sketches/core-loop/tests/test_batch_reset_test.gd` (53 tests reference `park_recipes.gd`).
- guard: `scripts/deep-sweep.mjs` D5 + `sketch-lint.mjs` L14 (`_reset()` static-var guard).

### WORLD-12 Four parallel map/stage/park builders — legacy `StageMap` & `EventDirector` paths are test-only, and `event_ground.gd` still depends on orphan `map_gorge.gd`
- kind: G
- evidence:
  - `src/world/` maintains **four** distinct stage/map description & build systems (plus bespoke camp/victory arenas in `camp_hub.gd` and `victory_lap.gd`):
    1. **Live JSON Park maps** (`ParkDefs` — `game.gd:85` `LAUNCH_TABLE := "park"`): `park_dam..park_crown.json` -> `ParkMap` + `ParkTerrain` + `ParkRecipes` + `ParkSchema` + `ParkGraph` + `ParkStamps` + `ParkPlacement`. **Reached in live game.**
    2. **Live Pockets** (layered on park maps by `activities.gd`): `pockets/w1|w2|w3/*.json` -> `PocketLibrary` + `PocketDraw` + `TradePockets` + `PocketFog`. **Reached in live game.**
    3. **Live Park Events** (layered on park maps by `events/families.gd` + `EventDirector._build_park`): `events/event_ground.gd` + `natural.gd`/`fleet.gd`/`industrial.gd`/`ancient.gd`/`cave_ins.gd`/`rubble_fall.gd`/`storm_seek.gd`/`stage_modifier.gd`. **Reached in live game.**
    4. **Legacy procedural `StageMap` maps & legacy `EventDirector` events**: `map_spillway.gd` (228L), `map_gorge.gd` (594L), `map_reach.gd` (298L), `map_dig.gd` (137L), `map_dig_deep.gd` (68L), `map_highdraft.gd` (171L), `map_highdraft_crown.gd` (87L) + `terrain.gd`'s legacy grid/relief builder (`L852-1019`) + `event_director.gd`'s non-park half (`L129-316`) + `flood_cycle.gd`, `dust_squall.gd`, `scrap_stampede.gd`, `terrain_event.gd`, `terrain_event_view.gd`, `event_view.gd`, `zone_schema.gd` (~2,700 lines total). **Never reached in default live play** (`game.gd:518` returns `ParkDefs` unless `test_mode` or `--table=alpha|slice|default`), yet `world.gd:105-113, 175-178` still constructs `Flood`, `EventView`, and `TerrainEventView` on every live park run.
  - Worse, `map_gorge.gd` (594L) is not referenced by ANY stage table (`ParkDefs`, `AlphaDefs`, `StageDefs`, `SliceDefs` — `git grep -n '"gorge"' sketches/core-loop/src` -> 1 hit: `terrain.gd:24` `MAPS`), yet live park code in `events/event_ground.gd:6, 62, 65, 69, 532, 550-551` preloads `map_gorge.gd` solely for 3 pure constants/math functions (`SWAP_PARK`, `crater_profile`, `rubble_profile`) and `events/natural.gd:14` has a dead preload of it!
- fix: Immediate behaviour-preserving decoupling: move `SWAP_PARK`, `crater_profile`, and `rubble_profile` out of `map_gorge.gd` into `events/event_ground.gd` (with `map_gorge.gd` delegating to them) and drop `event_ground.gd:6` and `natural.gd:14`'s preloads of `map_gorge.gd` so live park code has zero dependency on legacy procedural maps. (Retiring the legacy `map_*.gd` files and switching `test_mode` off `StageDefs` is listed under *Needs the owner* because 60+ tests depend on `StageDefs`.)
- files to change: `sketches/core-loop/src/world/events/event_ground.gd`, `sketches/core-loop/src/world/events/natural.gd`, `sketches/core-loop/src/world/map_gorge.gd`.
- size: ~30 lines moved, -2 preloads.
- risk: low — pure static math move; identical numbers.
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/park_natural_projection_test.gd`, `sketches/core-loop/tests/event_overlays_planned_test.gd`, `sketches/core-loop/tests/park_cave_in_test.gd`, `sketches/core-loop/tests/world_gorge_test.gd`.
- guard: `sketch-lint.mjs` rule banning `src/world/park/` and `src/world/events/` from preloading legacy `src/world/map_*.gd`.

### WORLD-13 Physics layer numbers and masks repeated across 8+ world files with no single owner
- kind: E
- evidence:
  - `WORLD_LAYER := 1` redefined locally in `world/park/park_recipes.gd:28`, `world/destructibles.gd:14` (and `combat/miniboss.gd:25`, `presentation/work_machines.gd:3`, `experimental/dynamic_setpieces.gd:35`).
  - `BALL_LAYER := 2` redefined locally in `world/park/park_recipes.gd:29`, `world/camp_skee.gd:10`, `world/camp_trial.gd:11` (while `camp_hub.gd:493, 684` reads `Recipes.WORLD_LAYER`/`Recipes.BALL_LAYER`).
  - `Augments.WORLD_MASK` (`1`) pulled via a `world -> movement` preload in `world/park/isle_rig.gd:4, 56` and `world/sluice_valves.gd:3, 250` (and `Augments.WORLD_MASK` is duplicated as `const WORLD_MASK := 1` in `combat/bolts.gd:12`, `combat/sticky.gd:9`, `presentation/ambient_life.gd:13`, `presentation/hero_fx.gd:10`).
  - Raw magic integer `1` passed for world ray/shape mask in `world/bay.gd:178` (`q.collision_mask = 1`) and `world/terrain.gd:511` (`PhysicsRayQueryParameters3D.create(..., 1)`).
- fix: Create `src/core/physics_layers.gd` (`WORLD_LAYER := 1`, `BALL_LAYER := 2`, `ENEMY_LAYER := 3`, `STAKE_LAYER := ...`, plus `WORLD_MASK`, `BALL_MASK`, `ENEMY_MASK`), have `Augments` alias them, and point all `src/world/` callers (`park_recipes.gd`, `destructibles.gd`, `camp_hub.gd`, `camp_skee.gd`, `camp_trial.gd`, `isle_rig.gd`, `sluice_valves.gd`, `bay.gd`, `terrain.gd`) at `PhysicsLayers`. Also removes 2 `world -> movement/augments.gd` preloads (`isle_rig.gd`, `sluice_valves.gd`).
- files to change: new `sketches/core-loop/src/core/physics_layers.gd`, `src/movement/augments.gd`, `src/world/park/park_recipes.gd`, `src/world/destructibles.gd`, `src/world/camp_hub.gd`, `src/world/camp_skee.gd`, `src/world/camp_trial.gd`, `src/world/park/isle_rig.gd`, `src/world/sluice_valves.gd`, `src/world/bay.gd`, `src/world/terrain.gd`.
- size: +18 / ~25 lines edited.
- risk: low — compile-time integer constants (`1`, `2`, `1 << 0`), zero runtime change.
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/grapple_sluice_valve_test.gd`, `sketches/core-loop/tests/destructibles_test.gd`, `sketches/core-loop/tests/camp_hub_test.gd`, `sketches/core-loop/tests/top_surface_test.gd`.
- guard: Add a `sketch-lint.mjs` check flagging raw integer literals on `.collision_mask =` / `PhysicsRayQueryParameters3D.create(..., <int>)` and duplicate `const WORLD_LAYER`/`BALL_LAYER`/`WORLD_MASK` definitions outside `src/core/physics_layers.gd`.

### WORLD-14 Raw group names and park map IDs scattered across 9+ world files
- kind: E
- evidence:
  - **Group `"world_telegraphs"`** spelled as raw string across 5 world files (`contraptions.gd:1219-1220`, `events/cave_ins.gd:27`, `events/industrial.gd:35`, `events/natural.gd:111`, `sluice_valves.gd:61-62,102-103`) + 1 tool (`tools/bot_fairness.gd:158`) + 2 tests (`stand_crew_test.gd:21`, `works_surge_test.gd:375`) with no single constant owner.
  - **Group `"enemy"`** spelled raw at 13 sites across 9 world files (`camp_sandbox.gd:237`, `destructibles.gd:1034`, `events/cave_ins.gd:53`, `events/fleet.gd:341`, `events/hazard_hits.gd:32`, `events/rubble_fall.gd:79`, `overtime.gd:220`, `stage_locks.gd:219`, `world.gd:643, 689, 695, 711`); `"enemy_shot"` raw in `camp_sandbox.gd:238` and `world.gd:702`.
  - **Park map IDs (`"park_dam"`, `"park_flume"`, `"park_pit"`, `"park_sinkhole"`, `"park_islands"`, `"park_crown"`)** are keyed in 8 separate GDScript side-tables outside `park_*.json` (plus `park_schema.gd:104`): `lock_rows.gd:4-27`, `breather_rows.gd:5-14`, `pockets/pocket_draw.gd:13-19`, `events/natural.gd:25` (`FOAM_PARKS`), `park/park_terrain.gd:257` (scour/stain colours), `director.gd:667` (`RIB_MIN_DOORS`), `pylon_bite.gd:20` (berm names), `scatter.gd:195` (noise seed/density). Note: `sketch-lint.mjs` L11 only guards raw `== "park_dam"` comparisons, not these 8 map-keyed dictionary side-tables.
- fix:
  1. Define `Groups` constants (`ENEMY`, `ENEMY_SHOT`, `WORLD_TELEGRAPHS`, `THREAT`) in `src/core/groups.gd` (or alongside `PhysicsLayers`) and replace raw group strings in `src/world/` and `tools/bot_fairness.gd`.
  2. Fold small single-map properties (`foam`, `scour`/`stain`, `rib_min_doors`, `tidy_level_m`, `scatter_noise`) into each `park_*.json` schema section (with defaults in `park_schema.gd`), or at minimum centralize the valid map-ID list in `ParkDefs` so `park_schema.gd:104` and the side tables are validated against one authoritative list.
- files to change: new `sketches/core-loop/src/core/groups.gd`, 13 files in `src/world/` for groups; and 8 side-table files + `park_schema.gd` (staged separately) for map keys.
- size: +15 / ~30 lines edited for groups; ~120 lines moved into JSON/schema for map keys.
- risk: low for `Groups` constants; medium for moving side-table data into `park_*.json` (schema tests and park-hash pins may need updating).
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/stand_crew_test.gd`, `sketches/core-loop/tests/works_surge_test.gd`, `sketches/core-loop/tests/park_schema_test.gd`, `sketches/core-loop/tests/scatter_rows_test.gd`, `sketches/core-loop/tests/stage_locks_test.gd`, `sketches/core-loop/tests/pocket_draw_test.gd`.
- guard: Add a `sketch-lint.mjs` check asserting every map-keyed const dictionary in `src/world/` uses keys present in `ParkDefs.DEFS`, and ban raw `"world_telegraphs"` literals.

### WORLD-15 Four mixed ways `src/world/` plays sound effects
- kind: G
- evidence:
  - Method 1 — Canonical bus (`ctx.events.world_fact.emit(kind, at)`): `world.gd` (9 sites), `overtime.gd` (6), `stage_locks.gd` (6), `cracked_cache.gd` (3), `activities.gd` (4), `sluice_valves.gd` (1), `stake_devices.gd` (1).
  - Method 2 — Direct `FoleyAudio.one_shot` / `FoleyAudio.player`: `events/fleet.gd:151, 254, 306, 328`, `events/rubble_fall.gd:75, 95`.
  - Method 3 — Direct `AudioStreamPlayer3D` + `SfxBank.loop_stream` / `trim_db`: `activities.gd:1189-1201` (`_find_sound`).
  - Method 4 — Direct `presentation.audio.play(...)` / `play_at(...)` / `_audio._admit`+`_start`: `activities.gd:1579-1581, 2608, 2635`, `activity_view.gd:96`, `stake_devices.gd:352-353`, `events/natural.gd:821-823`.
- fix: Standardize all one-shot world cues on Method 1 (`ctx.events.world_fact.emit(kind, at)`, backed by `EventKinds.WORLD_ROWS` — with positional 3D playback handled in `presentation/audio.gd` when `at != Vector3.INF`), removing Methods 2 and 4 from `src/world/`. Keep positional ambient loops (`_find_sound`) behind a single `presentation` listener on a world-anchor node or signal rather than `SfxBank` in `activities.gd`.
- files to change: `sketches/core-loop/src/world/events/natural.gd`, `events/fleet.gd`, `events/rubble_fall.gd`, `activities.gd`, `activity_view.gd`, `stake_devices.gd`, `src/core/event_kinds.gd`, `src/presentation/audio.gd`.
- size: ~60 lines removed from `world/`, ~40 lines unified in `event_kinds.gd` + `audio.gd`.
- risk: medium — sound-coverage and twin tests (`presentation_sfx_test.gd`, `sound_twins_test.gd`) assert exact heard cues and sound IDs.
- behaviour-preserving: yes — same sound IDs, trims and spatial positions, routed through one bus.
- tests that cover it: `sketches/core-loop/tests/presentation_sfx_test.gd`, `sketches/core-loop/tests/sound_twins_test.gd`, `sketches/core-loop/tests/stake_devices_test.gd`, `sketches/core-loop/tests/activities_test.gd`.
- guard: Ban `FoleyAudio`, `SfxBank`, `AudioStreamPlayer3D`, and `.audio.play` under `src/world/` in `sketch-lint.mjs`.

### WORLD-16 `director.gd` duplicates `Roster.COUNTERS` and `Roster.ANCIENTS` despite preloading `Roster`
- kind: A
- evidence:
  - `sketches/core-loop/src/world/director.gd:5` already preloads `const Roster := preload("res://src/combat/roster.gd")`.
  - `sketches/core-loop/src/world/director.gd:20-23` defines `const COUNTERS := ["mag_trapper", "bola_thrower", "hooker", "plated_brute", "netcaster", "deflector", "winch_drone", "gyro_jammer", "swatter", "ramp_flipper", "catch_trap"]` and `const FAMILY_ANCIENT := ["reactor_relic", "swarm_remnant", "mind_hand"]`.
  - Identical arrays already live in `sketches/core-loop/src/combat/roster.gd:162-164` (`const COUNTERS` and `const ANCIENTS`).
- fix: Alias `const COUNTERS := Roster.COUNTERS` and `const FAMILY_ANCIENT := Roster.ANCIENTS` in `director.gd` (or move the shared enemy-ID catalogue to `src/core/` so `director.gd` does not need a `world -> combat` preload at all).
- files to change: `sketches/core-loop/src/world/director.gd`.
- size: -4 / +2 lines.
- risk: low — identical compile-time string arrays.
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/world_director_test.gd`, `sketches/core-loop/tests/combat_roster_test.gd`, `sketches/core-loop/tests/director_homes_test.gd`.
- guard: Unit assertion in `tests/unit/` that `Director.COUNTERS == Roster.COUNTERS` and `Director.FAMILY_ANCIENT == Roster.ANCIENTS` (or eliminating the copy makes drift impossible).

### WORLD-17 Shallow 10-line wrapper `find_kit.gd` with one caller
- kind: D
- evidence:
  - `sketches/core-loop/src/world/find_kit.gd:1-10` only declares `MODEL`, `REQUIRED`, and a 1-line static forwarder `part(part_name, parent)` -> `ModelKit.part(MODEL, REQUIRED, part_name, parent)`.
  - `git grep -n "find_kit.gd" sketches/core-loop scripts` -> 1 hit (`sketches/core-loop/src/world/activities.gd:28`), which already preloads `ModelKit` at `L29` and defines `POCKET_KIT` / `POCKET_PARTS` inline at `L44-45` for the exact same `ModelKit.part(...)` pattern!
- fix: Inline `FIND_KIT` / `FIND_PARTS` beside `POCKET_KIT` / `POCKET_PARTS` in `activities.gd` (or the extracted `cache_sites.gd` from `WORLD-10`), replace `FindKit.part(...)` with `ModelKit.part(FIND_KIT, FIND_PARTS, ...)`, and delete `find_kit.gd` (with delete go-ahead).
- files to change: `sketches/core-loop/src/world/activities.gd`, `sketches/core-loop/src/world/find_kit.gd`.
- size: -11 / +3 lines.
- risk: low — 1 caller, trivial inline.
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/activities_test.gd`.
- guard: None needed beyond `deep-sweep.mjs` D1.

### WORLD-18 Cross-module static-cache teardown and shared mutable static flags
- kind: F
- evidence:
  - `sketches/core-loop/src/world/activities.gd:203, 363, 384-389`: `Activities._exit_tree()` (gated on `_owns_shared`) dynamically `load()`s and calls `.release_parks()`, `.release_plans()`, and `.release_shared()` on 4 unrelated modules (`world/director.gd`, `world/events/natural.gd`, `presentation/set_dressing.gd`, `presentation/park_props.gd`). If a test or scene frees `Activities` early or runs without `Activities`, those 4 modules' caches leak or get cleared unexpectedly.
  - `sketches/core-loop/src/world/terrain.gd:193`: `static var threaded_in_bot_runs := false` is read across 3 layers (`world/terrain.gd:190`, `combat/fleet.gd:111`, `presentation/bake_warm.gd:83`), forcing `combat/fleet.gd` and `presentation/bake_warm.gd` to preload `world/terrain.gd` just to read a threading flag.
  - `sketches/core-loop/src/world/park/park_terrain.gd:6`: `static var draw_regions := true` is read by `world/world.gd:357` to toggle destructible visuals (`"no_visuals": not ParkTerrain.draw_regions`).
- fix:
  1. Move `director.release_parks()` and `natural.release_plans()` into `world.gd._exit_tree()`, and move `set_dressing.release_shared()` / `park_props.release_shared()` into `presentation.gd._exit_tree()`.
  2. Move `threaded_in_bot_runs` to `src/core/sim_clock.gd` (which `terrain.gd`, `fleet.gd`, and `bake_warm.gd` already preload!), eliminating `combat/fleet.gd`'s preload of `world/terrain.gd`.
- files to change: `sketches/core-loop/src/world/activities.gd`, `sketches/core-loop/src/world/world.gd`, `sketches/core-loop/src/presentation/presentation.gd`, `sketches/core-loop/src/core/sim_clock.gd`, `sketches/core-loop/src/world/terrain.gd`, `sketches/core-loop/src/combat/fleet.gd`, `sketches/core-loop/src/presentation/bake_warm.gd`, `sketches/core-loop/tools/test_batch_driver.gd`.
- size: ~30 lines moved.
- risk: low — keep `SimClock.reset_for_tests()` / `test_batch_driver.gd` resetting the flag identically.
- behaviour-preserving: yes — same teardown on scene exit and identical bot-run threading gate.
- tests that cover it: `sketches/core-loop/tests/test_batch_reset_test.gd`, `sketches/core-loop/tests/new_world_cost_test.gd`.
- guard: `sketch-lint.mjs` L14 already enforces `_reset()` for static vars; add review/lint ban on `load("res://src/presentation/...").release_shared()` from `src/world/`.

## Not findings
- `world/events/natural_footprint.gd` (13 lines): small, not shallow — 6 callers (`park_map.gd`, `event_director.gd`, `events/natural.gd`, `events/event_ground.gd`, `events/industrial.gd`, `presentation/park_props.gd`) share its single collapse-face override rule.
- `world/events/warning_gap.gd` (23 lines) and `world/events/hazard_hits.gd` (49 lines): focused rule modules with multiple callers and dedicated tests (`hazard_hits.gd` has 6 `src/` callers + 4 tests; its `plants` fault switch is already guarded by `sketch-lint.mjs` L12).
- `world/stage_locks.gd:10` (`static var active := true`): intentional test/bot switch (`--locks=0`), already reset in `tools/test_batch_driver.gd:254` and pinned by `tests/test_batch_reset_test.gd:356`.
- `world/launch.gd:195` (`ring_nodes()`) and `world/destructibles.gd` (`is_built`, `ids`, `refusals`, `break_order`, `shard_pool_size`) and `world/park/park_graph.gd` (`node_count`, `edge_count`, `zone_count`): flagged by `deep-sweep.mjs` D1 as 1-line pass-throughs, but they are intentional encapsulation/test seams (several cited in `AGENTS.md` Rule 7 / `tests/`).
- `world/bay.gd:7`, `world/device.gd:5`, `world/event_view.gd:6` preloading `ui/world_prompt.gd`: explicitly mandated seam in `CONTRACTS.md:354` ("A module that labels something in the world uses `src/ui/world_prompt.gd`").
- `world/world.gd:15`, `contraptions.gd:12`, `sluice_valves.gd:9`, `events/industrial.gd:5`, `events/rubble_fall.gd:6`, `events/storm_seek.gd:4` preloading `combat/threat_grammar.gd` and `boss/hazard.gd`: intentional shared threat-drawing/damage geometry seam (`CONTRACTS.md:455, 480`), though moving `threat_grammar.gd` and `hazard.gd` to `src/core/` or `src/shared/` is a cross-slice decision.
- `world/park/park_recipes.gd` mutex-guarded static caches (`_origins_lock`, `_anchor_fit_lock`, `_anchor_hull_lock`) and `terrain.gd:107` single-thread `ParkMap` warm-up: deliberate Godot 4.7.2 worker-thread safety workarounds; leave untouched.
- `world/events/event_ground.gd` `OverlayMap` / `Snapshot` roof-copy logic: intentional lock-free snapshot seam for `terrain.gd` `WorkerThreadPool` perch reads (`perch_ahead_test.gd`).
- `world/park/footings.gd:7` (`plant_ignore_lines`) and `world/rescue_site.gd:21-22` (`model_path`, `scarf_path`): documented fault-injection test switches already guarded by `sketch-lint.mjs` L12/L14.

## Needs the owner
- **Retiring legacy procedural maps (`map_spillway.gd`, `map_gorge.gd`, `map_reach.gd`, `map_dig.gd`, `map_dig_deep.gd`, `map_highdraft.gd`, `map_highdraft_crown.gd`) and legacy `EventDirector` events (`flood.gd`/`flood_cycle.gd`, `dust_squall.gd`, `scrap_stampede.gd`, `terrain_event.gd`, `terrain_event_view.gd`, `event_view.gd`):** default live play uses `ParkDefs` exclusively (`game.gd:85`), while `test_mode` still defaults to `StageDefs` (`AlphaDefs`), keeping ~2,700 lines of legacy world code alive solely for ~60+ tests; deciding whether to migrate those tests to `ParkDefs` or freeze/archive legacy maps is a product/test-suite call.
- **Sluice valve pay-path (`contraptions.gd` `SluicePayDevice`) vs grapple-yanked sluice (`sluice_valves.gd`):** confirm whether E-to-pay sluice valves tested standalone in `works_surge_test.gd` are retired in favour of `sluice_valves.gd` before deleting the ~500 lines in `contraptions.gd`.
- **Relocating shared visual/threat primitives (`craft_prop_meshes.gd`, `recipe_props.gd`, `flash_guard.gd`, `material_slots.gd`, `threat_grammar.gd`, `hazard.gd`) into a `src/shared/` or `src/core/` layer:** spans `world`, `presentation`, `combat`, and `boss` slices and needs a one-line directory-layering decision from the coordinator/owner.
- **Delete go-ahead (`AGENTS.md`):** deleting `park/flume_piers.gd`, `park/grapple_footing.gd`, `find_kit.gd`, and retiring/moving `park/sockets.gd`, `park/risk_sites.gd`, `park/regions.gd`, `events/weather.gd`, and `zone_seed.gd` requires Andrew's delete go-ahead.
- **Camp hub (`camp_hub.gd` + `camp_sandbox.gd` + `camp_trial.gd` + `camp_skee.gd` + `camp_ring.gd`):** sits inside `src/world/` yet imports 9 `combat/` internals, 7 `ui/` widgets, and 6 `presentation/` scripts; consider giving camp its own top-level `src/camp/` feature module above `world`/`combat`/`ui` rather than forcing it under `src/world/`'s lower-layer rules.
