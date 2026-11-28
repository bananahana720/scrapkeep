# Structure survey: experimental-dev
commit: 23e935514ef33e7eb58d50e21bd2a5f757f41fa9   model: Gemini 4 Neon (High)   files read: 36   date: 2026-11-27

## Module map
- `sketches/core-loop/src/experimental/dynamic_setpieces.gd` | 1529 | Runs four interactive arena setpieces (EM crane, slag furnace, compactor vent, cryo pipes) plus jump-pad launch physics and a local env-tag cache | `_crane`, `_furnace`, `_compactor`, `_cryo_pipes`, `_pads`, `_pad_decks`, `_pad_flights`, `_active_tags`, `_clock_s` | `src/experimental/live_run_bridge.gd`, `tests/experimental_vertical_setpieces_test.gd`, `tests/step5_smelter_setpiece_craft_test.gd`
- `sketches/core-loop/src/dev/dev_console.gd` | 1461 | Owns the F10/tilde dev drawer UI, command registration, input-hold lock, and screenshot/QA-pack/contact-sheet capture | `commands`, `look`, `lens`, `fight`, `overlay`, `inspect`, `agent`, `open`, `_drawer`, `_rows`, `_held_input`, `_busy` | `src/game.gd` (dynamic `load`), `src/dev/dev_session.gd`, `tests/dev_console_test.gd`, `tests/dev_overlay_test.gd`
- `sketches/core-loop/src/experimental/live_world_actors.gd` | 1421 | Materializes experimental lockdown beacons, defenders, elites, props, haulers, hit/ram/hazard resolution, and inline procedural meshes in live runs | `_targets`, `_rings`, `_beacon`, `_lockdown`, `_apex_id`, `_mesh_cache`, `_fx_mats`, `_hazard_cd`, `_paid_scrap`/`_paid_cogs` | `src/experimental/live_run_bridge.gd`, `tests/experimental_live_game_test.gd`
- `sketches/core-loop/src/dev/dev_inspect.gd` | 1193 | Produces structured JSON state/perf/prim/UI/anomaly snapshots, records `GameEvents` signals, and evaluates `assert` checks | `recording`, `_events`, `_event_counts`, `_connected`, `_assertions`, `_perf_ring` | `src/dev/dev_console.gd`, `src/dev/dev_agent.gd`, `src/dev/dev_session.gd`, `tests/dev_console_test.gd`
- `sketches/core-loop/src/experimental/live_run_bridge.gd` | 954 | Composes all experimental pillars behind `--experimental-depth` / `SCRAPKEEP_EXPERIMENTAL`, sites and builds stage chunks, and drives `ExperimentalAudioBank` playback | `env_tags`, `synergies`, `ecology`, `director`, `encounters`, `setpieces`, `live_actors`, `_live_chunk`, `_audio_players`, `_active_loops` | `src/game.gd` (dynamic `load`), `tools/test_batch_driver.gd`, `tests/experimental_live_game_test.gd`, `tests/experimental_worlds23_and_bridge_test.gd`
- `sketches/core-loop/src/experimental/jury_rig_synergies.gd` | 910 | Loads 14 `.tres` experimental parts, tracks heat/overclock/venting, and dispatches trigger-driven part effects and emergent synergies | `env_tags`, `heat`, `hull_cooked_total`, `_equipped`, `_extra_parts`, `_synergies_log`, `_dispatch_log` | `src/experimental/live_run_bridge.gd`, `tests/experimental_builds_ecology_test.gd`, `tests/experimental_cross_pillar_test.gd`
- `sketches/core-loop/src/experimental/ecology_actors.gd` | 887 | Simulates experimental interactive props, neutral loot couriers, and four role-based enemy state machines reacting to `EnvTags` | `env_tags`, `_props`, `_couriers`, `_enemies`, `_consumed_serials`, `_event_log`, `_clock` | `src/experimental/live_run_bridge.gd`, `src/experimental/live_world_actors.gd`, `tests/experimental_builds_ecology_test.gd`
- `sketches/core-loop/src/experimental/adversity_director.gd` | 863 | Runs seeded stall-vs-flow credit income, hazard tier escalation, Fleet pack/Refurbished elite buying, and biome hazard cycles | `config`, `rng`, `credit_pool`, `hazard_tier`, `stall_meter`, `flow_meter`, `active_elites`, `pending_arrivals`, `hazard_phase` | `src/experimental/live_run_bridge.gd`, `tests/experimental_director_events_test.gd`, `tests/experimental_worlds23_and_bridge_test.gd`
- `sketches/core-loop/src/dev/dev_fight.gd` | 742 | Provides dev combat/state commands: enemy spawning, clear, god/calm/time/freeze, stage/warp/vel/speed, parts/panels/relics/tuning, and warden/beacon/flood controls | `god`, `_time_scale`, `_frozen`, `_stepping`, `_phys_steps`, `_held_hook`, `_spawned` | `src/dev/dev_console.gd`, `src/dev/dev_agent.gd`, `src/dev/dev_session.gd`
- `sketches/core-loop/src/experimental/env_tags.gd` | 734 | Owns the 6-tag environmental substrate, spatial zones, actor tags, visual grammar, and bounded-cascade pairwise reaction table | `_clock`, `_zones`, `_actors`, `_in_pass`, `_active_queue`, `_stats` | `src/experimental/jury_rig_synergies.gd`, `src/experimental/ecology_actors.gd`, `src/experimental/live_run_bridge.gd`, `src/experimental/live_world_actors.gd`
- `sketches/core-loop/src/experimental/encounter_engine.gd` | 730 | Runs triggered encounter volumes (lockdown waves + apex construct, blitz gate) and weighted random encounters (airdrop, compactor chase, greed ambush) | `catalog`, `rng`, `triggered_volumes`, `active_triggered_id`, `active_random`, `random_cooldown_s`, `settled_history` | `src/experimental/live_run_bridge.gd`, `src/experimental/live_world_actors.gd`, `tests/experimental_director_events_test.gd`
- `sketches/core-loop/src/dev/dev_overlay.gd` | 638 | Renders 3D wireframe collider bounds, telegraph outlines, velocity/aim vectors, and a 2D top-right FPS/draw-call sparkline | `_layers`, `_perf_mode`, `_mesh`, `_solid_v`/`_xray_v`, `_frame_ms`, `_reads` | `src/dev/dev_console.gd`, `tests/dev_overlay_test.gd`
- `sketches/core-loop/src/dev/dev_look.gd` | 636 | Overrides world `Environment`, sun `DirectionalLight3D`, `InkOutline` width, and two post-process shader passes (`paint`/`print`), bakes/loads JSON looks, and builds 4-oracle QA pack images | `_env_touched`, `_sun_touched`, `_env_rest`, `_sun_rest`, `_filter`, `_colour`, `_ink_scale`, `preset_name` | `src/dev/dev_console.gd`, `tests/dev_console_test.gd`
- `sketches/core-loop/src/experimental/arena_chunk_socket.gd` | 626 | Discovers `Marker3D` chunk sockets, computes chunk snap transforms, and runs 10-point clearance/verticality/sightline/loop/navigation validation on `.tscn` chunks | Stateless (`RefCounted` static API) | `src/experimental/dynamic_setpieces.gd`, `tests/experimental_vertical_setpieces_test.gd`, `tests/slice3_highdraft_mind_perf_test.gd`
- `sketches/core-loop/src/dev/dev_agent.gd` | 514 | Parses `--dev-*` flags and executes scripted scenarios or a file-based IPC mailbox (`in/*.req.json` -> `out/*.res.json`) writing receipts and NDJSON step logs | `out_dir`, `inbox_dir`, `idle_limit_s`, `_batch_steps`, `_mailbox_active`, `_mailbox_busy` | `src/dev/dev_console.gd`, `src/dev/dev_session.gd`, `tests/dev_console_test.gd`
- `sketches/core-loop/src/experimental/refurbished_elites.gd` | 469 | Loads 10 `.tres` Refurbished elite specs, selects weighted variants, and simulates per-plate break/stagger/backfire/magnetic-tether instances | Stateless static helpers + `RefurbishedInstance` (`hull_hp`, `plates`, `phase`, `stagger_left`, `bounty_paid`) | `src/experimental/adversity_director.gd`, `src/experimental/encounter_engine.gd`, `tests/experimental_director_events_test.gd`

*Files under 400 lines in this slice (read in full, omitted from map above per layout rule):* `src/dev/dev_lens.gd` (281), `src/experimental/part_resource.gd` (173), `src/dev/dev_commands.gd` (133), `src/dev/dev_session.gd` (113), `src/experimental/resources/director/refurbished_elite_config.gd` (85), `src/experimental/resources/director/adversity_director_config.gd` (33), `src/experimental/resources/director/encounter_catalog_config.gd` (11), plus `src/dev/dev_paint.gdshader` (124) and `src/dev/dev_print.gdshader` (153).

## Outward dependencies
Directory dependency counts across `src/experimental/` and `src/dev/` (counting `preload`/`load`/`ext_resource` `res://` references to directories outside each sub-slice; `project.godot` declares zero autoloads):
- `src/core`: 11 (4 from `experimental`, 7 from `dev`) — `src/core/palette.gd` (5), `src/core/app_shell.gd` (3), `src/core/safe_store.gd` (3).
- `src/presentation`: 11 (5 from `experimental`, 6 from `dev`) — `src/presentation/graphics_preset.gd` (3), `src/presentation/world23_chunk_craft.gd` (2), `src/presentation/flash_guard.gd` (2). **Wrong-direction from `experimental`:** gameplay/simulation modules (`dynamic_setpieces.gd`, `live_run_bridge.gd`, `live_world_actors.gd`) directly import presentation (`prop_motion_rig.gd`, `experimental_audio_bank.gd`, `flash_guard.gd`).
- `src/ui`: 8 (2 from `experimental`, 6 from `dev`) — `src/ui/ui_tokens.gd` (4), `src/ui/ui_fonts.gd` (2). **Wrong-direction from `experimental`:** simulation/world modules (`dynamic_setpieces.gd:10`, `live_world_actors.gd:12`) directly preload `src/ui/ui_tokens.gd` to read `UiTokens.reduced_motion`.
- `src/combat`: 7 (0 from `experimental`, 7 from `dev`) — `src/combat/threat_grammar.gd` (2), `src/combat/combat.gd` (1) (plus `rogue.gd`, `fleet.gd`, `roster.gd`, `elite_affixes.gd` in `dev_fight.gd`).
- `src/movement`: 7 (2 from `experimental`, 5 from `dev`) — `src/movement/speed_tier.gd` (4), `src/movement/tuning.gd` (2).
- `src/presentation/craft`: 6 (6 from `experimental`, 0 from `dev`) — `src/presentation/craft/experimental_setpiece_craft.gd` (2), `src/presentation/craft/camp_craft_meshes.gd` (2) (plus `craft_lookdev.gd`, `enemy_boss_craft.gd`). **Wrong-direction from `experimental`:** gameplay/bridge modules directly construct meshes/materials from `src/presentation/craft/`.
- `src/build`: 4 (0 from `experimental`, 4 from `dev`) — `src/build/relics.gd` (2), `src/build/parts.gd` (1).
- `src/world`: 2 (1 from `experimental`, 1 from `dev`) — `src/world/destructibles.gd` (1), `src/world/flood_cycle.gd` (1).
- `src/game.gd`: 1 (0 from `experimental`, 1 from `dev`) — `src/game.gd` (1, from `dev_session.gd:3`).

**Inward dependencies (rest of the game -> this slice):**
No core, combat, build, world, boss, presentation, or UI module requires `src/dev/` or `src/experimental/` to run. The only non-slice `src/` caller is `src/game.gd`, which dynamically `load()`s `src/dev/dev_console.gd` (`:333`, gated by `dev and not test_mode`) and `src/experimental/live_run_bridge.gd` (`:456-458`, gated by `--experimental-depth` / `SCRAPKEEP_EXPERIMENTAL` / `experimental_override`). Outside `src/`, `tools/test_batch_driver.gd:79` hard-preloads `src/experimental/live_run_bridge.gd` solely to call a redundant `_reset()` forwarder (XD-10).

## Findings

### XD-01 Shipped release exports bundle all of `src/dev/` and `src/experimental/`, and `game.gd` loads them with no existence or release guard
- kind: C
- evidence:
  - `sketches/core-loop/export_presets.cfg:8,10,27,29,46,48`: all three presets (`Linux x64`, `Linux x64 proof`, `macOS`) use `export_filter="all_resources"` with `exclude_filter="tests/*, tools/*, design-v2/*, design-v3/*, perf-lab/*, assets/music_ace/*"` — `src/dev/*`, `src/experimental/*`, and `assets/audio/experimental/*` are not excluded, so ~15,000 lines of dev/experimental GDScript, 2 shaders, 3 `.tscn` chunks, 28 `.tres` resources, and 7 `.ogg` files ship in every release pack.
  - `sketches/core-loop/src/game.gd:172,332-333`: `dev = dev or _launch_flag("--dev")` and `load("res://src/dev/dev_console.gd").hook(self)` run in shipped release builds with neither `OS.is_debug_build()` nor `ResourceLoader.exists(...)`.
  - `sketches/core-loop/src/game.gd:455-462`: `_attach_experimental()` calls `load(EXPERIMENTAL_BRIDGE).is_enabled()` and `load(EXPERIMENTAL_BRIDGE).new()` with no `ResourceLoader.exists(EXPERIMENTAL_BRIDGE)` guard (contrast `BOSS_PATH` at `game.gd:278` and `--self-play` at `game.gd:483`).
  - `git grep -n -E 'is_debug_build|has_feature\("editor"|has_feature\("debug"' -- sketches/core-loop/ scripts/` -> 0 hits; `scripts/export-include-check.mjs:68-87` and `scripts/sketch-export.mjs:147-173` never check that `src/dev/*` or `src/experimental/*` are excluded from release presets.
- fix: Add `src/dev/*`, `src/experimental/*`, and `assets/audio/experimental/*` to `exclude_filter` for release presets (`Linux x64` and `macOS`; decide with owner whether `Linux x64 proof` keeps `src/dev/*`), guard both `load(...)` sites in `src/game.gd` with `ResourceLoader.exists(...)` (so passing `--dev` or `--experimental-depth` to a stripped pack is a clean no-op instead of a null-dereference crash), and gate `--dev` behind `OS.is_debug_build()` if release packs must disable `F1`/`F3`/`F4` debug hotkeys too.
- files to change: `sketches/core-loop/export_presets.cfg`, `sketches/core-loop/src/game.gd`, `scripts/export-include-check.mjs`, `scripts/export-include-check.test.mjs`
- size: +40 / -5 lines
- risk: low — only affects exported packs and opt-in flag paths; normal gameplay, tests, and `--dev` runs from source keep identical behaviour (`DEEP-SWEEP` low risk: no physics, timing, RNG, or save change).
- behaviour-preserving: yes for normal play and all source/dev runs; intentionally removes dev/experimental payload and runtime hooks from shipped release packs.
- tests that cover it: `scripts/export-include-check.test.mjs`, `scripts/sketch-export.test.mjs`, `scripts/sketch-export-mac.test.mjs`, `sketches/core-loop/tests/dev_console_test.gd`, `sketches/core-loop/tests/experimental_live_game_test.gd`
- guard: Extend `scripts/export-include-check.mjs` (already run on exports and in node tests) to assert that `Linux x64` and `macOS` `exclude_filter` contain `src/dev/*`, `src/experimental/*`, and `assets/audio/experimental/*`.

### XD-02 Env-tag vocabulary, payload builder, and validator are duplicated 4 times across 3 experimental files with drifted clamps
- kind: A
- evidence:
  - Canonical owner: `sketches/core-loop/src/experimental/env_tags.gd:16-32,251-283` (`CANONICAL_TAGS`, `make_payload`, `validate_payload` — intensity `[0.0, 10.0]`, ttl `>= 0.0`).
  - Copy 2: `sketches/core-loop/src/experimental/refurbished_elites.gd:4-11,33-61` (`ENV_TAGS`, `make_env_tag_payload`, `is_valid_env_tag_payload` — intensity `>= 0.0` unbounded, ttl `>= 0.1`). Callers (`git grep -n -E 'make_env_tag_payload|is_valid_env_tag_payload'`): 4 calls in `src/experimental/` (`adversity_director.gd:820,829`, `encounter_engine.gd:582,585`) + 4 calls in `tests/`.
  - Copy 3: `sketches/core-loop/src/experimental/refurbished_elites.gd:257-271` (`RefurbishedInstance._make_tag` — identical body to `make_env_tag_payload`, 4 local callers at `:330,350,419,428`).
  - Copy 4: `sketches/core-loop/src/experimental/dynamic_setpieces.gd:18-32,106-141` (`ENV_TAGS`, `make_env_tag`, `validate_env_tag` — intensity `[0.05, 2.0]`, ttl `>= 0.05`, rejects `intensity == 0` unlike `EnvTags.validate_payload`). Callers (`git grep -n -E 'make_env_tag\(|validate_env_tag\('`): 3 internal calls + `tests/experimental_vertical_setpieces_test.gd`.
- fix: Preload `EnvTags` in `refurbished_elites.gd` and `dynamic_setpieces.gd`, delete `RefurbishedInstance._make_tag` and the duplicated tag arrays/validators, and route all tag construction and validation through `EnvTags` (preserving `DynamicSetpieces.make_env_tag` / `validate_env_tag` and `RefurbishedElites.is_valid_env_tag_payload` only if tests need a thin transition, or updating the 3 experimental tests to call `EnvTags` directly). Pick: update the 3 experimental tests and remove all duplicate helpers so one schema owns bounds and validation.
- files to change: `sketches/core-loop/src/experimental/refurbished_elites.gd`, `sketches/core-loop/src/experimental/dynamic_setpieces.gd`, `sketches/core-loop/src/experimental/adversity_director.gd`, `sketches/core-loop/src/experimental/encounter_engine.gd`, `sketches/core-loop/tests/experimental_cross_pillar_test.gd`, `sketches/core-loop/tests/experimental_director_events_test.gd`, `sketches/core-loop/tests/experimental_vertical_setpieces_test.gd`
- size: +25 / -115 lines
- risk: low — pure experimental-slice refactor with deterministic unit tests; check the one clamp-test assertion in `experimental_vertical_setpieces_test.gd` (`intensity` upper cap `2.0` vs `10.0`).
- behaviour-preserving: yes for all in-range runtime intensities (`0.4..1.5`); note `DynamicSetpieces.make_env_tag` clamped intensity to `2.0` whereas `EnvTags.make_payload` clamps to `10.0`, so align that one test expectation explicitly.
- tests that cover it: `sketches/core-loop/tests/experimental_builds_ecology_test.gd`, `sketches/core-loop/tests/experimental_cross_pillar_test.gd`, `sketches/core-loop/tests/experimental_director_events_test.gd`, `sketches/core-loop/tests/experimental_vertical_setpieces_test.gd`
- guard: `tests/experimental_worlds23_and_bridge_test.gd` already scans `src/experimental/` files; add an assertion that `"electrified"`/`"slag_coated"` tag lists are declared only in `env_tags.gd`.

### XD-03 `never_brake()` is copy-pasted twice in `refurbished_elites.gd`, duplicating `EventDirector.never_brake()`
- kind: A
- evidence:
  - Canonical owner: `sketches/core-loop/src/world/event_director.gd:328-336` (`static func never_brake(push_accel: Vector3, velocity: Vector3) -> Vector3`, already reused by `src/world/activities.gd:1943`).
  - Duplicate 1: `sketches/core-loop/src/experimental/refurbished_elites.gd:64-72` (`static func never_brake(accel: Vector3, velocity: Vector3) -> Vector3`, called by `adversity_director.gd:302,343,373`).
  - Duplicate 2: `sketches/core-loop/src/experimental/refurbished_elites.gd:273-281` (`RefurbishedInstance._never_brake_local`, byte-for-byte identical, called at `:468`).
  - Exact command: `git grep -n 'never_brake' -- sketches/core-loop/src/` -> 9 hits across 4 files (3 definitions).
- fix: Remove both copies from `refurbished_elites.gd` and call `EventDirector.never_brake()` (or move `never_brake` to a tiny shared physics helper in `src/movement/` and have `event_director.gd`, `activities.gd`, `refurbished_elites.gd`, and `adversity_director.gd` call it). Pick: call `EventDirector.never_brake()` directly (zero change to shipped world code; `dynamic_setpieces.gd` already preloads `src/world/destructibles.gd`).
- files to change: `sketches/core-loop/src/experimental/refurbished_elites.gd`, `sketches/core-loop/src/experimental/adversity_director.gd`
- size: +6 / -22 lines
- risk: low — all three implementations are mathematically identical.
- behaviour-preserving: yes — identical float operations and `0.5` speed threshold.
- tests that cover it: `sketches/core-loop/tests/experimental_director_events_test.gd`, `sketches/core-loop/tests/experimental_monte_carlo_physics_test.gd`, `sketches/core-loop/tests/experimental_worlds23_and_bridge_test.gd`
- guard: None needed beyond code review.

### XD-04 `DevFight` and `DevAgent` reach into private underscore methods on `Flow`, `DevConsole`, and `DevInspect`
- kind: C
- evidence:
  - `sketches/core-loop/src/dev/dev_fight.gd:671` and `:693`: calls `game.flow._unseal()` directly (`_unseal` is private in `src/core/flow.gd:1222`).
  - `sketches/core-loop/src/dev/dev_agent.gd:324-325`: `if is_instance_valid(console) and console.has_method("_refresh_rows"): console._refresh_rows()`.
  - `sketches/core-loop/src/dev/dev_agent.gd:421`: `DevInspect._summarize("perf", data)`.
  - Exact command: `git grep -n -E '\.[_][a-zA-Z0-9_]+' -- sketches/core-loop/src/dev/` -> 5 hits (the 4 above plus self-factory `session._boot` in `dev_session.gd:18`).
- fix: Add a small public `force_unseal() -> bool` on `src/core/flow.gd` (guarding `in_stage()` and `sealed`, delegating to `_unseal()`), rename `_refresh_rows()` -> `refresh_rows()` on `dev_console.gd` and `_summarize()` -> `summarize()` on `dev_inspect.gd`, and update the 4 call sites.
- files to change: `sketches/core-loop/src/core/flow.gd`, `sketches/core-loop/src/dev/dev_fight.gd`, `sketches/core-loop/src/dev/dev_console.gd`, `sketches/core-loop/src/dev/dev_inspect.gd`, `sketches/core-loop/src/dev/dev_agent.gd`
- size: +15 / -10 lines
- risk: low — purely structural; `flow.gd` gains one additive public method without touching normal run/Warden transitions (`DEEP-SWEEP` D2 pattern).
- behaviour-preserving: yes — identical call sequence and signals.
- tests that cover it: `sketches/core-loop/tests/dev_console_test.gd`, `sketches/core-loop/tests/spine_run_test.gd`
- guard: `scripts/deep-sweep.mjs` D2 already flags new `obj._member` reach-ins; extending `sketch-lint.mjs` to enforce D2 across `src/dev/` would keep it clean.

### XD-05 `DevFight` and `DevLens` mutate internal sub-objects of `Flood`, `RunState`, `Build`, `Combat`, and `ChaseCamera` instead of calling small owner APIs
- kind: C
- evidence:
  - `sketches/core-loop/src/dev/dev_fight.gd:706-713`: directly sets `f.cycle.phase = FloodCycle.HIGH/DRY`, `f.cycle.elapsed = 0.0`, then calls `f.render()`, reaching past `Flood` (`src/world/flood.gd`) into `FloodCycle`.
  - `sketches/core-loop/src/dev/dev_fight.gd:504`: directly calls `game.run.parts.clear()`, violating `CONTRACTS.md:33` ("Change run state only through the `run` mutators").
  - `sketches/core-loop/src/dev/dev_fight.gd:535`: directly writes `game.build.dropper.scale = clampf(...)`, reaching past `Build` into `Panels.Dropper`.
  - `sketches/core-loop/src/dev/dev_fight.gd:58-95`: preloads 4 combat tables (`Combat`, `Rogue`, `Fleet`, `Roster`) and calls `c.spawner.fleet.makes(kind)` to discover and validate spawnable enemy kinds.
  - `sketches/core-loop/src/dev/dev_fight.gd:99,436,471`: computes forward vector from `-game.camera.yaw_basis().z` instead of `c.heading()` (`CONTRACTS.md:73,272`).
  - `sketches/core-loop/src/dev/dev_lens.gd:262,265,269`: reaches into `game.camera.cam.current = true` (`ChaseCamera` child `Camera3D`).
- fix: Add five tiny single-responsibility public methods on the owning modules:
  1. `Flood.set_phase(phase: int) -> void` (`src/world/flood.gd`)
  2. `RunState.clear_parts() -> void` (`src/core/run_state.gd`)
  3. `Build.set_drop_scale(mult: float) -> float` (`src/build/build.gd`)
  4. `Combat.spawnable_kinds(world := 0) -> Array[String]` and `Combat.can_spawn(kind: String) -> bool` (`src/combat/combat.gd`)
  5. `ChaseCamera.make_current() -> void` (`src/movement/chase_camera.gd`)
  And switch `dev_fight.gd:99,436,471` to `c.heading()`.
- files to change: `sketches/core-loop/src/world/flood.gd`, `sketches/core-loop/src/core/run_state.gd`, `sketches/core-loop/src/build/build.gd`, `sketches/core-loop/src/combat/combat.gd`, `sketches/core-loop/src/movement/chase_camera.gd`, `sketches/core-loop/src/dev/dev_fight.gd`, `sketches/core-loop/src/dev/dev_lens.gd`
- size: +55 / -40 lines
- risk: low — additive public methods on owners with zero change to normal gameplay call paths; keeps `dev_fight.gd` from preloading `Rogue`, `Fleet`, `Roster`, and `FloodCycle`.
- behaviour-preserving: yes — exact same state transitions, encapsulated on each owner.
- tests that cover it: `sketches/core-loop/tests/dev_console_test.gd`, `sketches/core-loop/tests/dev_overlay_test.gd`
- guard: Review against `CONTRACTS.md` (and verify `worktree-sandbox.mjs` overlay policy before removing older fallbacks if `src/dev/` still overlays historical commits).

### XD-06 `DevFight.set_god()` overwrites `RunState.defend_hook`, colliding with `src/combat/ultimate.gd`
- kind: F
- evidence:
  - `git grep -n 'defend_hook' sketches/core-loop/src/` -> 2 writers of the single `Callable` field `RunState.defend_hook` (`src/core/run_state.gd:76,660`):
    1. `sketches/core-loop/src/combat/ultimate.gd:128`: `ctx.run.defend_hook = Callable(self, "defend")`
    2. `sketches/core-loop/src/dev/dev_fight.gd:141-146`: saves `_held_hook = c.run.defend_hook`, replaces it with `func(_amount, _hp) -> float: return 0.0`, and restores `_held_hook` on `god off`.
  - If `god on` is enabled before `ultimate.gd` installs its hook (or across a stage/run setup), `ultimate.gd` silently overwrites god mode; if `god off` runs after `ultimate.gd` installed its hook, `_held_hook` erases `ultimate.gd`'s defense hook.
- fix: Add a `var invulnerable := false` flag on `RunState` (`src/core/run_state.gd`), early-return in `RunState.damage()` when `invulnerable` is true (or clamp `amount = 0.0` before `defend_hook`), and have `DevFight.set_god()` toggle `c.run.invulnerable` instead of swapping `c.run.defend_hook`.
- files to change: `sketches/core-loop/src/core/run_state.gd`, `sketches/core-loop/src/dev/dev_fight.gd`
- size: +8 / -10 lines
- risk: low — `invulnerable` defaults to `false`, so non-dev runs never take that branch (`damage()` behaviour unchanged).
- behaviour-preserving: yes for normal play; fixes a real hook-clobbering bug when `god` interacts with ultimate defense.
- tests that cover it: `sketches/core-loop/tests/dev_console_test.gd` (lines 120-129 test `god on`/`off` with `run.damage()`).
- guard: Add a test in `tests/dev_console_test.gd` verifying `c.run.defend_hook` is unchanged before, during, and after `god on`/`god off`.

### XD-07 Dead code in `src/dev/` and `src/experimental/`: unimplemented `complete_args`, dead `contact_sheet_mode` compat branch, unused preload/constants, and empty `reset()` stubs
- kind: B
- evidence:
  - `sketches/core-loop/src/dev/dev_console.gd:42,1161-1167,1395-1396`: `MODULE_HEADS` and `_module_pool()` check `module.has_method("complete_args")` on `fight`, `inspect`, `agent` — `git grep -n complete_args -- sketches/core-loop/ scripts/` -> 2 hits, both inside `dev_console.gd` (0 implementations anywhere).
  - `sketches/core-loop/src/dev/dev_agent.gd:437-446,508-514`: checks `console.has_method("contact_sheet_mode")` (`git grep -n contact_sheet_mode -- sketches/core-loop/ scripts/` -> 2 hits, both in `dev_agent.gd`, 0 implementations) and reflects on `contact_sheet` argument count via `_method_argc` even though `dev_console.gd` always defines `sheet_detailed` and `worktree-sandbox.mjs:382-394` always overlays all `src/dev/*` files as one bundle.
  - `sketches/core-loop/src/experimental/dynamic_setpieces.gd:4`: `const Palette := preload("res://src/core/palette.gd")` — 0 references in the file.
  - `sketches/core-loop/src/experimental/arena_chunk_socket.gd:40` (`GROWN_HEFT_ENVELOPE_RADIUS_M`, `git grep` -> 1 hit total) and `sketches/core-loop/src/experimental/jury_rig_synergies.gd:17` (`HEAT_MAX`, `git grep` -> 1 hit total).
  - Empty `static func reset() -> void: pass` stubs in `part_resource.gd:68`, `env_tags.gd:231`, `ecology_actors.gd:121`, `jury_rig_synergies.gd:70` — test-only no-ops (`git grep` -> 2 hits each, only in `tests/experimental_builds_ecology_test.gd:24-27` and `tests/experimental_cross_pillar_test.gd:24-27`).
- fix: Delete `_module_pool`/`MODULE_HEADS` (or actually implement `complete_args` if Tab completion for `stage`/`warp`/`give`/`inspect` is wanted — pick deletion unless Tab completion is prioritized), delete `dev_agent.gd`'s dead `contact_sheet_mode`/`_method_argc` branches, remove the unused `Palette` preload and 2 unused constants, and drop the 4 empty `reset()` stubs and their test calls.
- files to change: `sketches/core-loop/src/dev/dev_console.gd`, `sketches/core-loop/src/dev/dev_agent.gd`, `sketches/core-loop/src/experimental/dynamic_setpieces.gd`, `sketches/core-loop/src/experimental/arena_chunk_socket.gd`, `sketches/core-loop/src/experimental/jury_rig_synergies.gd`, `sketches/core-loop/src/experimental/part_resource.gd`, `sketches/core-loop/src/experimental/env_tags.gd`, `sketches/core-loop/src/experimental/ecology_actors.gd`, `sketches/core-loop/tests/experimental_builds_ecology_test.gd`, `sketches/core-loop/tests/experimental_cross_pillar_test.gd`
- size: +4 / -55 lines
- risk: low — every removed symbol has zero runtime callers.
- behaviour-preserving: yes — dead branches never execute and empty `pass` functions do nothing.
- tests that cover it: `sketches/core-loop/tests/dev_console_test.gd`, `sketches/core-loop/tests/experimental_builds_ecology_test.gd`, `sketches/core-loop/tests/experimental_cross_pillar_test.gd`, `sketches/core-loop/tests/experimental_vertical_setpieces_test.gd`
- guard: Add an unused-preload check to `scripts/sketch-lint.mjs` (cheap regex over `^const X := preload(...)`).

### XD-08 `DevConsole.LENS_RANGES` duplicates `DevLens` knob bounds and already drifts on `distance` (`200` vs `400`)
- kind: A
- evidence:
  - `sketches/core-loop/src/dev/dev_console.gd:48-49`: defines `LENS_RANGES` with `"distance": [2.0, 200.0, 0.5]` and repeats all 9 lens knob min/max bounds.
  - `sketches/core-loop/src/dev/dev_lens.gd:20-21,128-148`: defines `MIN_DISTANCE := 2.0`, `MAX_DISTANCE := 400.0`, and repeats all 9 clamp ranges inline in `set_knob()`.
- fix: Move `LENS_RANGES` onto `dev_lens.gd` (with `[MIN_DISTANCE, MAX_DISTANCE, 0.5]` or one agreed max), have `DevLens.set_knob()` clamp from `LENS_RANGES[key]`, and read `DevLens.LENS_RANGES` in `dev_console.gd:1000`.
- files to change: `sketches/core-loop/src/dev/dev_lens.gd`, `sketches/core-loop/src/dev/dev_console.gd`
- size: +10 / -14 lines
- risk: low — dev-only camera UI and knob clamping.
- behaviour-preserving: yes (reconciles the slider max with the command clamp; keep `200.0` or `400.0` consistently).
- tests that cover it: `sketches/core-loop/tests/dev_console_test.gd`, `sketches/core-loop/tests/dev_overlay_test.gd`
- guard: None needed once `dev_console.gd` reads `DevLens.LENS_RANGES`.

### XD-09 `DevConsole` duplicates `DevAgent`'s `--dev-run=` parser and fallback script runner with divergent defaults
- kind: A
- evidence:
  - `sketches/core-loop/src/dev/dev_console.gd:33-34,113-122`: dynamically `load()`s `dev_inspect.gd` and `dev_agent.gd` behind `ResourceLoader.exists(...)` instead of preloading them like `DevLook`/`DevLens`/`DevFight`/`DevOverlay`.
  - `sketches/core-loop/src/dev/dev_console.gd:127-130,266-296`: keeps a fallback `--dev-run=` flag loop and a 30-line fallback `run_script()` interpreter for `wait`, `tick`, `sheet`, `shot`, `quit` that duplicates `dev_agent.gd:54-55,288-326` — and diverges (`wait` defaults to 30 frames in `dev_console.gd:272` vs 1 frame in `dev_agent.gd:295`, and omits `until`, `qa_pack`, `perf`, and `#` comments).
  - `scripts/worktree-sandbox.mjs:380-394`: always copies every file in `src/dev/` together, so `dev_console.gd` never runs without `dev_inspect.gd` and `dev_agent.gd`.
- fix: Preload `DevInspect` and `DevAgent` directly in `dev_console.gd`, mount them unconditionally in `setup()`, and delete the dead `agent == null` fallback paths (`dev_console.gd:127-130,266-296`).
- files to change: `sketches/core-loop/src/dev/dev_console.gd`
- size: +6 / -40 lines
- risk: low — `agent` is always non-null today whenever `dev_console.gd` mounts.
- behaviour-preserving: yes — removes an unreachable fallback branch.
- tests that cover it: `sketches/core-loop/tests/dev_console_test.gd`, `scripts/worktree-sandbox.test.mjs`
- guard: Existing `dev_console_test.gd` exercises `DevConsole` + `DevInspect` + `DevAgent` mounting and `run_script`.

### XD-10 `LiveRunBridge._reset()` is a shallow forwarding stub that forces `test_batch_driver.gd` to `preload` `src/experimental/` and resets `ExperimentalAudioBank` twice
- kind: D
- evidence:
  - `sketches/core-loop/src/experimental/live_run_bridge.gd:116-117`: `static func _reset() -> void: ExperimentalAudioBank._reset()` — `LiveRunBridge` owns zero `static var`s (`git grep -n 'static var ' sketches/core-loop/src/experimental/` -> 0 hits).
  - `sketches/core-loop/tools/test_batch_driver.gd:78-79,243-244`: preloads both `ExperimentalAudioBank` and `LiveRunBridge`, calls `ExperimentalAudioBank._reset()` on line 243, then calls `LiveRunBridge._reset()` on line 244 (calling `ExperimentalAudioBank._reset()` twice per test file).
- fix: Delete `LiveRunBridge._reset()` and remove lines 79 and 244 from `tools/test_batch_driver.gd` (which already resets `ExperimentalAudioBank` directly).
- files to change: `sketches/core-loop/src/experimental/live_run_bridge.gd`, `sketches/core-loop/tools/test_batch_driver.gd`
- size: +0 / -5 lines
- risk: low — `LiveRunBridge` has no static mutable state; L14 in `scripts/sketch-lint.mjs` only requires `_reset()` for files with `static var`.
- behaviour-preserving: yes — eliminates a redundant second `ExperimentalAudioBank._reset()` call per batched test.
- tests that cover it: `sketches/core-loop/tests/test_batch_reset_test.gd`, `sketches/core-loop/tests/experimental_worlds23_and_bridge_test.gd`
- guard: `scripts/deep-sweep.mjs` D1 catches new 1-line public pass-throughs (missed `_reset` because it starts with `_`).

### XD-11 `src/experimental/` gameplay modules invert layer boundaries by preloading `src/ui/ui_tokens.gd` and `src/presentation/*`
- kind: C
- evidence:
  - `sketches/core-loop/src/experimental/dynamic_setpieces.gd:8-10`: preloads `src/presentation/craft/experimental_setpiece_craft.gd`, `src/presentation/prop_motion_rig.gd`, and `src/ui/ui_tokens.gd` (reads `UiTokens.reduced_motion` at `:785,929,933,972`).
  - `sketches/core-loop/src/experimental/live_world_actors.gd:7-9,12`: preloads `src/presentation/craft/camp_craft_meshes.gd`, `src/presentation/craft/enemy_boss_craft.gd`, `src/presentation/flash_guard.gd`, and `src/ui/ui_tokens.gd` (reads `UiTokens.reduced_motion` at `:672,941,964,972,996` and `FlashGuard.on` at `:1021,1029`), and embeds 350 lines of procedural `ArrayMesh` building (`:1069-1421`).
  - `sketches/core-loop/src/experimental/live_run_bridge.gd:12-14`: preloads `src/presentation/experimental_audio_bank.gd`, `camp_craft_meshes.gd`, and `craft_lookdev.gd` to build foundation/ramp meshes (`:534-595`) and play audio directly (`:322-377`).
- fix: Move `live_world_actors.gd:1069-1421` mesh/material builders into `src/presentation/craft/experimental_actor_craft.gd`, inject a `reduced_motion: bool` flag (or callable) via `setup` / `opts` instead of preloading `UiTokens` from gameplay modules, and route experimental audio cues through `src/presentation/audio.gd` if experimental features graduate.
- files to change: `sketches/core-loop/src/experimental/live_world_actors.gd`, `sketches/core-loop/src/experimental/dynamic_setpieces.gd`, `sketches/core-loop/src/experimental/live_run_bridge.gd`, new `sketches/core-loop/src/presentation/craft/experimental_actor_craft.gd`
- size: +410 / -400 lines (mostly code move)
- risk: medium — touches mesh-cache lifecycle and tests that call `live_actors.*_mesh()` directly (`tests/experimental_live_game_test.gd`); verify all test mesh checks keep working.
- behaviour-preserving: yes — identical geometry, materials, and reduced-motion reads.
- tests that cover it: `sketches/core-loop/tests/experimental_live_game_test.gd`, `sketches/core-loop/tests/step5_smelter_setpiece_craft_test.gd`, `sketches/core-loop/tests/experimental_vertical_setpieces_test.gd`
- guard: Add a `sketch-lint.mjs` rule forbidding `src/experimental/` (and non-UI/presentation folders) from preloading `src/ui/`.

### XD-12 `EncounterEngine` duplicates `StageLocks`'s perimeter spring constants and force formula
- kind: A
- evidence:
  - Canonical owner: `sketches/core-loop/src/world/stage_locks.gd:18-19,22,480` (`WALL_SPRING := 60.0`, `WALL_DAMP := 8.0`, `WALL_ACCEL_CAP := 120.0`, and `-n * minf(WALL_ACCEL_CAP, WALL_SPRING * (dist - radius) + WALL_DAMP * maxf(outward, 0.0))`).
  - Copy: `sketches/core-loop/src/experimental/encounter_engine.gd:11-13,717-730` (`WALL_SPRING := 60.0`, `WALL_DAMP := 8.0`, `WALL_ACCEL_CAP := 120.0`, and `_perimeter_spring_accel()`).
  - Exact command: `git grep -n 'WALL_SPRING' -- sketches/core-loop/ scripts/` -> 5 hits across `stage_locks.gd`, `encounter_engine.gd`, and 1 design doc.
- fix: Promote `perimeter_spring_accel(ball_pos, ball_vel, centre, radius) -> Vector3` as a `static func` on `src/world/stage_locks.gd` and call `StageLocks.perimeter_spring_accel(...)` from both `stage_locks.gd:480` and `encounter_engine.gd:413`.
- files to change: `sketches/core-loop/src/world/stage_locks.gd`, `sketches/core-loop/src/experimental/encounter_engine.gd`
- size: +16 / -20 lines
- risk: low — pure arithmetic extraction; `stage_locks.gd` physics output is bit-for-bit identical.
- behaviour-preserving: yes — identical constants and clamp order.
- tests that cover it: `sketches/core-loop/tests/experimental_director_events_test.gd`, `sketches/core-loop/tests/experimental_monte_carlo_physics_test.gd`, `sketches/core-loop/tests/stage_locks_*` (verify exact filename by grep when editing).
- guard: None needed once one `static func` owns the spring constants.

### XD-13 `PartResource.VALID_MAKERS` duplicates `MakerSets` / `Relics.VALID_MAKERS`
- kind: A
- evidence:
  - `sketches/core-loop/src/build/maker_sets.gd:7-13,15`: defines the 7 maker constants (`spillway_works`, `fleet_surplus`, `redjaw`, `highdraft_roosts`, `waking`, `mind_glass`, `moss`) and `SETS`.
  - `sketches/core-loop/src/build/relics.gd:12`: duplicates all 7 as `const VALID_MAKERS := [...]`.
  - `sketches/core-loop/src/experimental/part_resource.gd:14-22`: duplicates all 7 again as `const VALID_MAKERS: Array[StringName] = [...]`.
  - Exact command: `git grep -n 'VALID_MAKERS' -- sketches/core-loop/ scripts/` -> 6 hits across `relics.gd`, `part_resource.gd`, and 2 tests.
- fix: Preload `MakerSets` in `part_resource.gd` and validate `MakerSets.SETS.has(String(maker))` (keeping `VALID_MAKERS` removed or derived from `MakerSets`, and updating `relics.gd` in its own build-slice cleanup).
- files to change: `sketches/core-loop/src/experimental/part_resource.gd`
- size: +4 / -10 lines
- risk: low — `part_resource.gd:102` is the only reader of `PartResource.VALID_MAKERS`.
- behaviour-preserving: yes — exact same 7 maker IDs.
- tests that cover it: `sketches/core-loop/tests/experimental_builds_ecology_test.gd`, `sketches/core-loop/tests/experimental_worlds23_and_bridge_test.gd`
- guard: Existing `JuryRigSynergies.validate_all_catalogues()` test validates every `.tres` maker against `PartResource.validate()`.

### XD-14 `DevConsole`'s `run` command duplicates `DevFight`'s `pilot` command
- kind: A
- evidence:
  - `sketches/core-loop/src/dev/dev_console.gd:400-408`: registers `run [pilot number]`, checks `flow.state_name() != "title"`, bounds-checks `flow.classes`, calls `flow.launch_from_title(flow.classes[index])`, returns plain string `"run started"`.
  - `sketches/core-loop/src/dev/dev_fight.gd:286,346-386`: registers `pilot <index|id>`, checks `flow.state_name() != "title"`, resolves 1-based index OR pilot ID/display-name prefix against `flow.classes`, calls `flow.launch_from_title(chosen)`, returns structured `{ok, text, data}`.
- fix: Have `dev_console.gd:400`'s `run` command delegate directly to `fight.launch_pilot(args)` (defaulting empty `args` to `["1"]`), so one function owns title-screen pilot resolution and launch.
- files to change: `sketches/core-loop/src/dev/dev_console.gd`, `sketches/core-loop/src/dev/dev_fight.gd`
- size: +6 / -10 lines
- risk: low — dev CLI only; check if `dev_console_test.gd` asserts `"run started"` text.
- behaviour-preserving: yes (keep `run`'s default pilot `1`; check test string expectations).
- tests that cover it: `sketches/core-loop/tests/dev_console_test.gd`, `sketches/core-loop/tests/dev_overlay_test.gd`
- guard: Existing `dev_console_test.gd`.

### XD-15 `DevOverlay` and `DevInspect` run parallel 60-frame performance sampling loops every `_process` frame
- kind: A
- evidence:
  - `sketches/core-loop/src/dev/dev_inspect.gd:11,31,45-50,349-365`: unconditionally calls `_capture_perf_tick()` (10 `Performance.get_monitor()` calls per frame) on every `_process` frame into `_perf_ring` (cap 60), even when `inspect perf` is never invoked.
  - `sketches/core-loop/src/dev/dev_overlay.gd:35,57-59,216,602-623`: unconditionally samples wall-clock frame delta into `_frame_ms` (cap 60) on every `_process` frame and polls `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` when visible.
- fix: Share one frame-timing sample source (have `DevInspect` expose `frame_ms_ring()` / latest `draws`, or gate `DevInspect`'s 10-monitor polling behind an active flag / `sample_perf()` while keeping a cheap single-timestamp ring shared with `DevOverlay`). Pick: keep `DevInspect` as the single 60-frame owner, gate its heavy 10-monitor capture when neither perf strip nor perf sampling is active (falling back to `_capture_perf_tick()` on demand), and let `DevOverlay` read from `console.inspect`.
- files to change: `sketches/core-loop/src/dev/dev_inspect.gd`, `sketches/core-loop/src/dev/dev_overlay.gd`
- size: +20 / -28 lines
- risk: low — dev-only instrumentation; keep `dev_overlay_test.gd`'s standalone `DevOverlay` sparkline working if `console.inspect` is null.
- behaviour-preserving: yes — same sparkline and `inspect perf` outputs, less per-frame monitor overhead in `--dev` sessions.
- tests that cover it: `sketches/core-loop/tests/dev_overlay_test.gd`, `sketches/core-loop/tests/dev_console_test.gd`
- guard: None needed.

### XD-16 Stage aliases and boss arena map names are hardcoded in `dev_fight.gd` and `dev_inspect.gd` outside the owning stage/world tables
- kind: E
- evidence:
  - `sketches/core-loop/src/dev/dev_fight.gd:26,313`: hardcodes `const STAGE_ALIASES := {"dam": 1, "flume": 2, "pit": 3, "sinkhole": 4, "islands": 5, "crown": 6}` — only matches `ParkDefs` (`src/core/park_defs.gd`), silently mismatches `AlphaDefs` (`spillway`, `reach`, `dig`, `dig_deep`, `highdraft`, `highdraft_crown`) and `StageDefs`.
  - `sketches/core-loop/src/dev/dev_inspect.gd:174-181`: hardcodes a `match int(game.run.world)` returning `"park_slag_bowl"`, `"waking_arena"`, `"mind_arena"`.
  - `scripts/sketch-lint.mjs:536` explicitly exempts `src/dev/` from rule L11 (raw map/pilot ID branching), hiding this drift from lint.
- fix: In `dev_fight.gd`, resolve stage aliases dynamically from `c.stages.DEFS` (matching `row["map"]` and `row["map"].trim_prefix("park_")`). In `dev_inspect.gd`, query a `map_name()` method on `ctx.boss` or a `boss_map` field on `Worlds.BOSSES` (`src/core/worlds.gd`) instead of hardcoding world numbers to strings.
- files to change: `sketches/core-loop/src/dev/dev_fight.gd`, `sketches/core-loop/src/dev/dev_inspect.gd`, `sketches/core-loop/src/core/worlds.gd`
- size: +22 / -16 lines
- risk: low — dev CLI and inspection telemetry only; preserves existing `"dam"`..`"crown"` aliases on `ParkDefs` while making `AlphaDefs`/`StageDefs` work too.
- behaviour-preserving: yes for `ParkDefs` (exact same alias-to-index mapping and boss map strings).
- tests that cover it: `sketches/core-loop/tests/dev_console_test.gd`, `scripts/dev-console.test.mjs`
- guard: Narrow `scripts/sketch-lint.mjs:536` so `src/dev/` is not blanket-exempted from L11 (or keep only explicit command-help strings exempt).

### XD-17 Cruise speed fallback (`14.0`) and telegraph floor (`0.6 s`) are scattered across 7 `src/experimental/` files
- kind: E
- evidence:
  - `14.0` default cruise speed spelled independently in 7 files: `adversity_director_config.gd:6`, `adversity_director.gd:271,326,366,384`, `encounter_engine.gd:203,365`, `jury_rig_synergies.gd:23`, `dynamic_setpieces.gd:37`, `live_run_bridge.gd:219,274,891`, `live_world_actors.gd:398` (whereas `src/movement/tuning.gd` owns the actual `cruise` default).
  - `0.6` minimum tell/warning floor spelled in 5 files: `adversity_director.gd:11` (`HAZARD_TELL_FLOOR_S`), `encounter_engine.gd:9` (`MIN_TELL_S`), `refurbished_elites.gd:26` (`MIN_TELL_S`), `refurbished_elite_config.gd:64` (`maxf(0.6, tell_s)`), `dynamic_setpieces.gd:36` (`MIN_WARN_FLOOR_S`).
- fix: Define one `DEFAULT_CRUISE_MPS` and one `MIN_TELL_S` constant on `EnvTags` (or read `Tuning`'s default cruise and `Threat`'s warn floor) and reference them across all experimental modules.
- files to change: `sketches/core-loop/src/experimental/env_tags.gd`, `sketches/core-loop/src/experimental/adversity_director.gd`, `sketches/core-loop/src/experimental/encounter_engine.gd`, `sketches/core-loop/src/experimental/jury_rig_synergies.gd`, `sketches/core-loop/src/experimental/dynamic_setpieces.gd`, `sketches/core-loop/src/experimental/live_run_bridge.gd`, `sketches/core-loop/src/experimental/live_world_actors.gd`, `sketches/core-loop/src/experimental/refurbished_elites.gd`, `sketches/core-loop/src/experimental/resources/director/refurbished_elite_config.gd`
- size: +15 / -18 lines
- risk: low — constant consolidation only, keeping exact numeric values (`14.0` and `0.6`).
- behaviour-preserving: yes — identical runtime values.
- tests that cover it: `sketches/core-loop/tests/experimental_director_events_test.gd`, `sketches/core-loop/tests/step5_smelter_setpiece_craft_test.gd`, `sketches/core-loop/tests/experimental_builds_ecology_test.gd`
- guard: None needed.

### XD-18 Three oversized files (~1,420–1,530 lines) have clean, state-disjoint seams ready to split
- kind: H
- evidence:
  - `sketches/core-loop/src/experimental/dynamic_setpieces.gd` (1,529 lines): jump-pad launching and deck collision-exception flight tracking (`:558-754`, 197 lines) exclusively owns `_pads`, `_pad_decks`, `_pad_flights`, `_pad_facts` — zero state shared with `_crane`, `_furnace`, `_compactor`, or `_cryo_pipes`.
  - `sketches/core-loop/src/dev/dev_console.gd` (1,461 lines): still, QA-pack, and contact-sheet capture + SubViewport label composition (`:460-750`, 291 lines) exclusively owns `_busy`, `_shots`, `shot_dir`, `SHEET_*` constants, and touches zero UI drawer widgets beyond toggling `_drawer.visible`.
  - `sketches/core-loop/src/experimental/live_world_actors.gd` (1,421 lines): procedural `ArrayMesh` and material generation (`:1020-1421`, 402 lines) exclusively owns `_mesh_cache` and `_fx_mats` — zero gameplay/target state (see also XD-11).
- fix: Split along those three existing state seams:
  1. Extract `src/experimental/jump_pad_launcher.gd` from `dynamic_setpieces.gd` (reduces it to ~1,330 lines).
  2. Extract `src/dev/dev_capture.gd` from `dev_console.gd` (reduces it to ~1,170 lines; keep thin public delegators on `DevConsole` for `shot`/`shot_detailed`/`qa_pack_detailed`/`sheet_detailed`/`sheet_grid`/`sheet_ids` if tests call them directly).
  3. Extract `src/presentation/craft/experimental_actor_craft.gd` from `live_world_actors.gd` (reduces it to ~1,020 lines and removes presentation coupling).
- files to change: `sketches/core-loop/src/experimental/dynamic_setpieces.gd`, `sketches/core-loop/src/dev/dev_console.gd`, `sketches/core-loop/src/experimental/live_world_actors.gd`, plus 3 new sibling/craft scripts (and `scripts/worktree-sandbox.mjs` automatically picks up any new file under `src/dev/`).
- size: +900 / -880 lines (pure extraction)
- risk: low-to-medium — low for `dev_capture.gd` and `experimental_actor_craft.gd`; medium for `jump_pad_launcher.gd` because `_physics_process` order and `Area3D` parenting affect jump-pad flight tests.
- behaviour-preserving: yes — same node parenting, physics callbacks, and public methods.
- tests that cover it: `sketches/core-loop/tests/dev_console_test.gd`, `sketches/core-loop/tests/dev_overlay_test.gd`, `sketches/core-loop/tests/experimental_vertical_setpieces_test.gd`, `sketches/core-loop/tests/experimental_monte_carlo_physics_test.gd`, `sketches/core-loop/tests/experimental_live_game_test.gd`
- guard: `scripts/deep-sweep.mjs` D5 watches files over 1,500 lines (`dynamic_setpieces.gd` is already over 1,500).

### XD-19 `ExperimentalAudioBank` stores global mutable cooldown state shared across `LiveRunBridge` instances, and `LiveRunBridge` bypasses `src/presentation/audio.gd`
- kind: F
- evidence:
  - `sketches/core-loop/src/presentation/experimental_audio_bank.gd:113,171-183`: `static var _last_trigger_s: Dictionary = {}` is mutated by `src/experimental/live_run_bridge.gd:329,332,771` (`can_trigger`, `mark_triggered`, `reset_cooldowns`). Because `sim_time_s` is per-bridge-instance while `_last_trigger_s` is process-global static state, two `LiveRunBridge` instances (or a bridge created before another tears down) corrupt each other's cooldowns.
  - `sketches/core-loop/src/experimental/live_run_bridge.gd:322-377,823-832`: creates and plays its own `AudioStreamPlayer` children outside `src/presentation/audio.gd`; `duck_db` and `duck_bus` from `ExperimentalAudioBank.EVENT_SPECS` are merely copied into the returned `cue` dictionary (`:348`) and never applied to any bus.
- fix: Move `_last_trigger_s` to an instance variable on `LiveRunBridge` (or pass a cooldown dictionary into `ExperimentalAudioBank.can_trigger()`), keeping `ExperimentalAudioBank` purely immutable specs + read-only stream/texture caches. If experimental audio is promoted to shipped play, route playback and bus ducking through `src/presentation/audio.gd`.
- files to change: `sketches/core-loop/src/experimental/live_run_bridge.gd`, `sketches/core-loop/src/presentation/experimental_audio_bank.gd`, `sketches/core-loop/tests/experimental_audio_bank_test.gd`, `sketches/core-loop/tests/experimental_worlds23_and_bridge_test.gd`
- size: +25 / -20 lines
- risk: low — touches only experimental audio cooldown bookkeeping; update the cooldown assertions in the 2 experimental tests.
- behaviour-preserving: yes for single-bridge runs; fixes cross-instance cooldown bleed.
- tests that cover it: `sketches/core-loop/tests/experimental_audio_bank_test.gd`, `sketches/core-loop/tests/experimental_worlds23_and_bridge_test.gd`
- guard: `scripts/sketch-lint.mjs` L14 already guards `static var`; keeping `_last_trigger_s` off static state shrinks the L14 reset surface.

### XD-20 `src/dev/` mixes two command-return protocols (`!`-prefixed `String` vs `{ok, text, data}` `Dictionary`) and duplicates CLI flag parsing across `game.gd`, `live_run_bridge.gd`, and `dev_agent.gd`
- kind: G
- evidence:
  - `sketches/core-loop/src/dev/dev_commands.gd:95-108` branches on `if result is Dictionary` vs string prefix `!` because `dev_console.gd:341-449`, `dev_look.gd`, `dev_lens.gd`, `dev_overlay.gd`, and `dev_fight.gd:84-263` return `String`, while `dev_fight.gd:304-720` and `dev_inspect.gd` return `{ok, text, data}` `Dictionary`s. Furthermore `dev_console.gd:416-427` triggers async `shot`/`qa_pack_detailed`/`sheet_detailed` fire-and-forget while returning `""`, forcing `dev_agent.gd:310-315,450-476` to intercept those commands separately and parse `"-> "` out of string replies as a fallback.
  - Experimental launch flags (`--experimental-depth`, `SCRAPKEEP_EXPERIMENTAL`) are parsed twice in two different files with overlapping string constants: `src/game.gd:161-162,465-471` (`_experimental_asked`) and `src/experimental/live_run_bridge.gd:17-20,120-144` (`is_enabled`). Meanwhile `dev_agent.gd:29,50-64` parses `--dev-*` only from `OS.get_cmdline_user_args()` while `game.gd:172,468,1301-1302` checks both `get_cmdline_args()` and `get_cmdline_user_args()`.
- fix: Standardize command handlers on one helper constructor (`DevCommands.ok(text, data)` / `DevCommands.err(text, data)`) or let `DevCommands` keep string-adaptation strictly at the leaf while unifying `dev_agent.gd`'s capture normalization around `{ok, text, data}` only; keep experimental flag constants/parsing in one place (either `game.gd` reads only `LiveRunBridge.is_enabled()` behind `ResourceLoader.exists()`, or a single `LaunchFlags` helper). Pick: unify `dev_agent.gd` capture normalization onto `{ok, text, data}` (paired with XD-07/XD-09) and remove duplicate `--experimental-depth` parsing from `game.gd:_experimental_asked()` once `export_presets.cfg` excludes `src/experimental/*`.
- files to change: `sketches/core-loop/src/dev/dev_commands.gd`, `sketches/core-loop/src/dev/dev_agent.gd`, `sketches/core-loop/src/game.gd`, `sketches/core-loop/src/experimental/live_run_bridge.gd`
- size: +25 / -40 lines
- risk: low — internal dev/experimental plumbing.
- behaviour-preserving: yes — same CLI flags and JSON receipt shapes.
- tests that cover it: `sketches/core-loop/tests/dev_console_test.gd`, `sketches/core-loop/tests/experimental_live_game_test.gd`, `sketches/core-loop/tests/experimental_worlds23_and_bridge_test.gd`
- guard: Existing `dev_console_test.gd` and `experimental_worlds23_and_bridge_test.gd`.

## Not findings
- `src/dev/dev_fight.gd:729-742` (`_parts_rows()` / `_relic_ids()` dynamic `has_method` fallback to `CATALOGUE`/`ROWS`): intentional compatibility shim for `scripts/worktree-sandbox.mjs`, which overlays `src/dev/` onto older historical worktrees.
- `src/game.gd:333` and `:456-458` using `load()` instead of `preload()` for `dev_console.gd` and `live_run_bridge.gd`: intentional so default runs and tests do not parse or load dev/experimental trees (only the missing `ResourceLoader.exists()` check and export exclusion are defects, covered in XD-01).
- Static-var hygiene inside `src/dev/` and `src/experimental/`: zero `static var` declarations exist in either directory (`git grep -n 'static var ' sketches/core-loop/src/dev/ sketches/core-loop/src/experimental/` -> 0 hits; `tests/experimental_worlds23_and_bridge_test.gd:543` already enforces this for `src/experimental/`).
- File-write and headless-check hygiene in `src/dev/` and `src/experimental/`: all disk writes go through `SafeStore.write_atomic` (L2 compliant) and headless checks go through `AppShell.headless()` (L13 compliant).
- `src/presentation/world23_chunk_craft.gd`: preloaded by shipped combat/boss scripts (`deflector.gd`, `gap_net.gd`, `gyro_jammer.gd`, `kite_drone.gd`, `mind_dress.gd`) as well as two experimental `.tscn` chunks — it is a shared presentation craft library, not a reverse dependency from the game into `src/experimental/`.
- `src/dev/dev_session.gd:18` (`session._boot(...)`) and `WeakRef` callbacks in `ecology_actors.gd:131` and `live_run_bridge.gd:497,868-883` (`inst._on_*`): same-class private dispatch used to avoid GDScript `Callable` reference cycles, not cross-module reach-ins.
- `src/dev/dev_overlay.gd:100-101` (`debug` alias for `overlay`) and `src/dev/dev_fight.gd:298` (`hurt` alias for `damage`): single-line command aliases sharing the same handler callable, not duplicated logic.
- `src/dev/dev_console.gd` / `dev_fight.gd` / `dev_look.gd` / `dev_lens.gd` / `dev_agent.gd` `_exit_tree()` cleanup: properly restores `Engine.time_scale`, `hold_for_dev`, `freeze_for_dev`, signals, and `ready.json`.
- `src/experimental/resources/director/*.gd` (`adversity_director_config.gd`, `encounter_catalog_config.gd`, `refurbished_elite_config.gd`) and `part_resource.gd`: clean typed `Resource` data schemas backing the 28 `.tres` assets.
- `src/dev/dev_console.gd:561` (`contact_sheet`): tiny convenience wrapper over `sheet_detailed("presets", "", close_menu)` kept for interactive/legacy callers; harmless once `dev_agent.gd`'s dead reflection branches are removed (XD-07).

## Needs the owner
- **Graduate, quarantine, or delete `src/experimental/` (9,425 lines + 28 `.tres` + 3 `.tscn` + 7 `.ogg`):** `src/experimental/` duplicates core game subsystems in parallel (`env_tags.gd` vs `build/elements.gd` + `element_field.gd`; `part_resource.gd` + `jury_rig_synergies.gd` vs `build/parts.gd` + `synergies.gd`; `adversity_director.gd` + `encounter_engine.gd` vs `world/director.gd` + `event_director.gd` + `stage_locks.gd`; `refurbished_elites.gd` + `ecology_actors.gd` vs `combat/elite_affixes.gd` + `roster.gd`; `live_run_bridge.gd` audio vs `presentation/audio.gd`). Owner decision needed on which pillars merge into the real modules and which get archived or removed.
- **Release-pack policy for `src/dev/` and `Linux x64 proof`:** Confirm whether `Linux x64` and `macOS` release exports should strip `src/dev/*` and `src/experimental/*` and disable `--dev` via `OS.is_debug_build()`, and whether `Linux x64 proof` still needs `src/dev/*` for capture runs.
- **Historical worktree-overlay horizon for `scripts/worktree-sandbox.mjs`:** Decide whether `src/dev/` still needs backward-compatibility shims for overlaying onto pre-`main` worktrees (`_parts_rows`, `_relic_ids`), or whether `src/dev/` can depend directly on current owner APIs introduced by XD-04/XD-05.
- **Unwired bus ducking in `ExperimentalAudioBank`:** Six cues in `src/presentation/experimental_audio_bank.gd` specify `duck_db` and `duck_bus`, but `LiveRunBridge.trigger_audio_cue()` only logs them and never ducks any audio bus; decide whether to move experimental audio into `src/presentation/audio.gd` before exposing it to players.
