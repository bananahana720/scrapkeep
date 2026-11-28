# Structure survey: tools-tests
commit: 23e935514ef33e7eb58d50e21bd2a5f757f41fa9   model: Gemini 4 Neon (high)   files read: 42 (direct) + pattern scans across 1,549 tests and 321 non-blender tools   date: 2026-11-27

## Module map

All 48 code files of 400+ lines under `sketches/core-loop/tools/` (excluding individual `tools/blender/` asset recipes and binary `.glb` files; shared `tools/blender/` helpers included) plus the 3 `tests/unit/` cases and largest `tests/*.gd` suites (174 total `.gd` files >= 400 lines under `sketches/core-loop/tests/`, of which 171 are standalone leaf `*_test.gd` scripts invoked only by `scripts/sketch-smoke.mjs` / `tools/test_batch_driver.gd` and own only suite-local fixtures):

sketches/core-loop/tools/bot_driver.gd | 4710 | Automated bot AI for all 6 pilots, stage traversal, activities, combat, boss fights and telemetry | 204 instance vars (goals, climb routes, fight state, BrindleRings, note dict); 0 statics | 82 `.gd` callers (`tools/bot_run.gd`, `tests/bot_*_test.gd`)
sketches/core-loop/tools/park_graph.gd | 2095 | Offline stage navigation graph baker (`graph.bin` / `graph.json`) and landform-zone/jitter checks | Stateless CLI (`Builder` inner class builds graph in memory) | 20 `.gd` callers (`tests/park_*`, `tools/map_sheet_capture.gd`)
sketches/core-loop/tools/icons/generate_icons.py | 2001 | Procedural V2 UI icon PNG generator reading `tools/palette_gd.py` | Stateless Python CLI | `scripts/palette-gd.test.mjs`, docs (5 refs)
sketches/core-loop/tools/build_patch_glbs.py | 1746 | Pure-Python glTF 2.0 generator for Patch pilot/shell GLBs | Stateless Python script | 0 callers (strictly unreferenced)
sketches/core-loop/tools/matchup_lab.gd | 1550 | Headless enemy-vs-pilot duel matrix runner and hard-cell evaluator | 84 instance vars (`DuelDriver`, duel state, results) | `tests/matchup_lab_test.gd`, `tests/matchup_lab_pocket_test.gd` (2 `.gd` callers)
sketches/core-loop/tools/traversal_line.gd | 1471 | Park traversal-line speed/airtime sampler and band checker | 19 instance vars + 3 static vars (`graph_notes`, `_park_defs_source`, `_graphs`) | 8 `.gd` callers (`tests/traversal_measure_test.gd`, `tests/bot_hands_flag_test.gd`)
sketches/core-loop/tools/look_harness.gd | 1372 | Multi-subject rendered visual baseline capture, diff pairer and boss smoke runner | 24 instance vars (`game`, `cam`, `_anchors`, `_pins`, CLI flags) | 3 `.gd` callers (`tools/boss_smoke_crash.gd`, `tools/offscreen_probe.gd`, `tools/pilot_mask.gd`)
sketches/core-loop/tools/park_props_audit.gd | 1307 | Park prop placement, draw-count and density auditor | 29 instance vars (`game`, audit tallies) | 1 `.gd` caller + 4 design docs
sketches/core-loop/tools/perf_bench.gd | 1271 | Headless/rendered performance benchmark harness (`SilentBand`, `Probe`, `SiteRide`) | 59 instance vars (timings, monitors, run state) | `scripts/checkpoint.mjs`, `scripts/redteam/run.mjs` (11 refs)
sketches/core-loop/tools/blender/park/props/kit.py | 1028 | Shared Blender park-dressing prop builder, LOD decimator and colour/budget gate | `Kit` registry, hardcoded `C`/`BANNED`/`WARN` hex dicts | 41 Blender prop recipe scripts
sketches/core-loop/tools/map_sheet_capture.gd | 864 | Top-down and perspective map-sheet PNG capture for 10-point map standard receipts | 9 instance vars (`SubViewport`, camera, map state) | `scripts/gate/map-standard-receipt.mjs`, `tests/map_sheet_capture_test.gd`
sketches/core-loop/tools/stress_capture.gd | 816 | Dense combat/VFX frame-time stress capture script | 36 instance vars (frame timings, run/FX counters) | 1 `.gd` caller + docs (11 refs)
sketches/core-loop/tools/qa/collision_sweep.gd | 812 | Automated park collision/snag/out-of-bounds sweep probe | 25 instance vars (`game`, sweep samples) | `docs/promises/` (5 refs)
sketches/core-loop/tools/kinetic_sheet_capture.gd | 783 | Rendered enemy/VFX kinetic motion contact-sheet generator | 1 instance var (`SubViewport` render state) | `tests/kinetic_sheet_capture_test.gd`
sketches/core-loop/tools/balance_report.gd | 755 | Bot NDJSON balance/win-rate/economy report aggregator | 4 instance vars (CLI opts, parsed records) | `tests/balance_report_old_record_test.gd` + docs (9 refs)
sketches/core-loop/tools/asset_capture.gd | 727 | Multi-camera rendered asset turnaround/mask/pair capture CLI | 23 instance vars (`game`, `camera`, CLI opts) | `tests/asset_capture_test.gd`, `tools/cliff_gate_export.gd`
sketches/core-loop/tools/asset_rig_craft_audit.gd | 675 | Rig bone/clip/liveliness craft-standard auditor | 1 instance var | `tests/pilot_rig_liveliness_test.gd`, `tests/slice1_patch_and_w1_craft_test.gd`
sketches/core-loop/tools/vertex_colour_probe.gd | 663 | Forward+ vs sRGB vertex-colour material probe and still capture | 10 instance vars | 1 `.gd` caller + 3 design docs
sketches/core-loop/tools/press_latency_capture.gd | 661 | Input-to-effect press-latency measurement and frame capture | 13 instance vars | `tests/press_latency_measure_test.gd`, `tests/w45_combat_feel_test.gd`
sketches/core-loop/tools/blender/common.py | 660 | Shared Blender `Part` mesh builder, material slots, `HEX` palette literal, GLB exporter | Module globals `DETAIL`, `POLISH`, `SLOTS` | 160 Blender recipe scripts
sketches/core-loop/tools/blender/shell_base.py | 638 | Shared Blender pilot ball shell/truss/plate geometry primitives | Stateless helpers | 21 Blender shell recipe scripts
sketches/core-loop/tools/greybox_eradication_capture.gd | 629 | One-off greybox-eradication prop comparison still capture | 1 instance var | 0 callers (strictly unreferenced)
sketches/core-loop/tools/harpoon_physics_capture.gd | 617 | One-off harpoon physics rig still/strip capture | 4 instance vars | 0 callers (strictly unreferenced)
sketches/core-loop/tools/blender/polish.py | 596 | Shared Blender bevel, deterministic Python Catmull-Clark subdivision and AO/wear baker | Module global `_opts` | 112 Blender recipe scripts
sketches/core-loop/tools/audio_board.gd | 576 | Offline audio synthesis/harmony board renderer and waveform dumper | Stateless SceneTree CLI | `tests/audio_board_test.gd`, docs (4 refs)
sketches/core-loop/tools/attack_sheet_core.gd | 574 | Pure enemy attack-telegraph sheet table builder and validator | 4 instance vars | `tools/attack_sheet.gd`, `tests/attack_sheet_test.gd`
sketches/core-loop/tools/priority_proof.gd | 556 | Bot target-priority proof harness over combat encounters | 34 instance vars | `tests/priority_proof_test.gd`, `tools/priority_proof.md`
sketches/core-loop/tools/qa/invisible_walls.gd | 536 | Rendered vs collider invisible-wall discrepancy probe | 18 instance vars | `tests/flume_post_walls_test.gd`, docs (3 refs)
sketches/core-loop/tools/model_audit.py | 531 | Exported GLB mesh/clip/triangle/outline budget auditor | Stateless Python CLI | `scripts/far-faults.mjs`, `tools/blender/park/props/kit.py` (7 refs)
sketches/core-loop/tools/build_sweep.gd | 522 | Headless item/part/synergy build-growth statistical sweep | Stateless SceneTree CLI | `scripts/redteam/run.mjs`, `tests/slot_growth_sweep_test.gd`
sketches/core-loop/tools/craft_lookdev_capture.gd | 515 | One-off craft lookdev contact-sheet capture | 1 instance var | 0 callers (strictly unreferenced)
sketches/core-loop/tools/spillway_route_capture.gd | 513 | One-off Spillway route still capture | 20 instance vars | 0 callers (strictly unreferenced)
sketches/core-loop/tools/self_play.gd | 507 | In-game self-play runner dynamically loaded by `src/game.gd` (`SELF_PLAY`) | 51 instance vars (driver, watch, film hooks) | `src/game.gd` (guarded by `ResourceLoader.exists`), skills (14 refs)
sketches/core-loop/tools/clip_audit.py | 506 | NumPy clipping auditor over `tools/clip_dump.gd` outputs | Stateless Python CLI | `project-guide/handoff/LESSONS.md` (doc-only, 1 ref)
sketches/core-loop/tools/bot_run.gd | 492 | CLI runner executing multi-seed `BotDriver` runs and writing `bots.ndjson` + traces | 30 instance vars (seeds, game, driver, frame/trace files) | `tests/bot_*_test.gd`, `scripts/` (78 refs)
sketches/core-loop/tools/pilot_liveliness_capture.gd | 492 | One-off pilot liveliness rig still capture | 8 instance vars | 0 callers (strictly unreferenced)
sketches/core-loop/tools/posture_sweep.gd | 487 | Headless Warden/boss posture band sweep harness | 25 instance vars | 8 `.gd` callers (`tests/arena_posture_record_test.gd`, `tests/posture_*`)
sketches/core-loop/tools/qa/snag_probe.gd | 485 | Physics snag/lip-catch probe for park surfaces and takeoffs | 11 instance vars | 3 `.gd` callers (`tests/dam_takeoff_test.gd`), docs (8 refs)
sketches/core-loop/tools/bot_fairness.gd | 466 | Telegraph-fairness evaluator reading `scripts/challenge/fairness.json` | 23 instance vars + 1 static var (`_config`) | 5 `.gd` callers (`tests/bot_fairness*_test.gd`, `tests/unit_suite_test.gd`)
sketches/core-loop/tools/concept/journey_page.py | 458 | Static HTML journey-board page generator | Stateless Python script | `sketches/core-loop/design-v3/PARK.md` (doc-only, 1 ref)
sketches/core-loop/tools/w12_side_trebuchet_launcher.gd | 430 | Wave-12 side-by-side detail-LOD capture for trebuchet launcher (copy-paste of `w12_recipe_cart_side.gd`) | 1 instance var | 0 code callers (1 comment in `tools/blender/trebuchet_launcher_detail1.py`)
sketches/core-loop/tools/look_subjects.gd | 429 | Subject table and camera/strip option parser for `tools/look_harness.gd` | Stateless constants/helpers | 5 `.gd` callers (`tools/look_harness.gd`, `tests/look_*`)
sketches/core-loop/tools/blender/ambient/_life.py | 428 | Shared Blender ambient-creature mesh/colour/export kit | Stateless helpers | 11 Blender ambient-creature scripts
sketches/core-loop/tools/weapon_ball_craft_capture.gd | 416 | One-off weapon/ball craft still capture | 4 instance vars | 0 callers (strictly unreferenced)
sketches/core-loop/tools/craft_showcase_deep_audit.gd | 411 | One-off craft showcase assembly audit capture | 1 instance var | 0 callers (strictly unreferenced)
sketches/core-loop/tools/w12_side_valve_wheel.gd | 409 | Wave-12 side-by-side detail-LOD capture for valve wheel (copy-paste) | Stateless SceneTree | 0 callers (strictly unreferenced)
sketches/core-loop/tools/w12_side_lift_platform.gd | 404 | Wave-12 side-by-side detail-LOD capture for lift platform (copy-paste) | Stateless SceneTree | 0 code callers (1 comment in `tools/blender/lift_platform_detail1.py`)
sketches/core-loop/tools/w12_side_geyser_launcher.gd | 402 | Wave-12 side-by-side detail-LOD capture for geyser launcher (copy-paste) | Stateless SceneTree | 0 callers (strictly unreferenced)
sketches/core-loop/tests/unit/weight_table_case.gd | 461 | Unit test cases for weighted drop/offer tables | 1 suite var | `tests/unit_suite_test.gd`
sketches/core-loop/tests/unit/objectives_case.gd | 423 | Unit test cases for stage objective/Warden posture rules | Stateless case | `tests/unit_suite_test.gd`
sketches/core-loop/tests/unit/boss_posture_case.gd | 413 | Unit test cases for Warden posture rule object | 1 suite var | `tests/unit_suite_test.gd`
sketches/core-loop/tests/weapon_cadence_test.gd | 1780 | Standalone weapon cadence test suite (largest of 171 top-level `*_test.gd` files >= 400L; next largest: `park_props_test.gd` 1341L, `rivet_set_piece_test.gd` 1209L, `experimental_monte_carlo_physics_test.gd` 1170L, `weapon_envelope_test.gd` 1075L, `tally_kit_test.gd` 998L, `player_fx_test.gd` 957L) | 2 suite vars | `scripts/sketch-smoke.mjs` / `tools/test_batch_driver.gd`

## Outward dependencies

Computed across all 1,740 `.gd` files in `sketches/core-loop/tools/` (191) and `sketches/core-loop/tests/` (1,549) by `preload`/`load("res://...")` and `src/` `class_name` references (`project.godot` declares 0 autoloads). Because `tools/` and `tests/` are the topmost verification/tooling layer, dependencies into `src/*` point in the expected downward direction; no wrong-direction edge originates in this slice (and `L7` enforces that `src/` cannot reference `res://tools/`, with only `src/game.gd`'s guarded `SELF_PLAY` exception).

- `src/core` | 1,739 refs across 886 files | `src/core/palette.gd` (226), `src/core/class_def.gd` (192)
- `src/presentation` | 1,136 refs across 498 files | `src/presentation/sfx_bank.gd` (88), `src/presentation/harmony.gd` (70)
- `src/movement` | 948 refs across 733 files | `src/movement/intent.gd` (587), `src/movement/tuning.gd` (156)
- `src` (root) | 909 refs across 908 files | `src/game.gd` (909)
- `src/world` | 844 refs across 414 files | `src/world/park/park_map.gd` (75), `src/world/park/park_recipes.gd` (65)
- `src/combat` | 802 refs across 416 files | `src/combat/threat_grammar.gd` (82), `src/combat/warden.gd` (62)
- `src/ui` | 488 refs across 249 files | `src/ui/word_budget.gd` (46), `src/ui/icons.gd` (30)
- `src/build` | 423 refs across 206 files | `src/build/parts.gd` (109), `src/build/synergies.gd` (37)
- `src/boss` | 245 refs across 132 files | `src/boss/boss_rules.gd` (38), `src/boss/hazard.gd` (36)
- `assets` | 55 refs across 37 files | `assets/models/dig_mechanical/cart_body.glb` (13), `assets/models/dig_mechanical/cart_wheel.glb` (13)
- `src/experimental` | 47 refs across 10 files | `src/experimental/dynamic_setpieces.gd` (6), `src/experimental/arena_chunk_socket.gd` (5)
- `src/dev` | 8 refs across 2 files | `src/dev/dev_console.gd` (2), `src/dev/dev_lens.gd` (2)
- `main.tscn` | 1 ref across 1 file | `main.tscn` (1)
- (Internal slice edge: `tests/` -> `tools/` | 142 test files preload 40+ `tools/*.gd` scripts, most heavily `tools/bot_driver.gd` (82 callers) and `tools/park_graph.gd` (20 callers).)

## Findings

### TT-01 72 strictly dead tool scripts (~15.5k lines) plus 5 comment-only w12 side scripts have zero live callers
- kind: B
- evidence: Full-repo text scan of 321 non-blender scripts under `sketches/core-loop/tools/` against all 6,235 tracked text files (`scripts/`, `package.json`, `.agents/`, `.claude/`, `src/`, `tests/`, `tools/`, `docs/`, `project-guide/`, `.github/`) found **72 strictly unreferenced scripts** (0 hits anywhere outside themselves, even by stem), totaling **15,489 lines** (54 `.gd` files = 12,250 lines + 18 `.py`/`.sh` files = 3,239 lines, including 5 standalone Python test scripts not wired into `package.json` or CI). Exact `git grep -l` checks confirm 0 external hits for the largest dead files:
  - `git grep -l "build_patch_glbs.py"` -> only `sketches/core-loop/tools/build_patch_glbs.py` (1,746L; string also baked into binary GLB generator tag)
  - `git grep -l "greybox_eradication_capture.gd"` -> 0 hits (629L)
  - `git grep -l "harpoon_physics_capture.gd"` -> 0 hits (617L)
  - `git grep -l "craft_lookdev_capture.gd"` -> self only (515L)
  - `git grep -l "spillway_route_capture.gd"` -> 0 hits (513L)
  - `git grep -l "pilot_liveliness_capture.gd"` -> 0 hits (492L)
  - `git grep -l "weapon_ball_craft_capture.gd"` -> 0 hits (416L)
  - `git grep -l "craft_showcase_deep_audit.gd"` -> 0 hits (411L)
  - `git grep -l "w12_side_barge.gd"` -> 0 hits (385L), plus 7 other strictly dead `w12_side_*.gd` and 4 `w12_capture`/`w12_fx_capture`/`w12_ground_capture`/`w12_material_count` (3,889L combined)
  - Plus 5 more `w12_side_*` / `w12_recipe_cart_side.gd` files (1,977L) referenced only in Blender docstring comments or copy-pasted `push_error("w12_recipe_cart_side: ...")` strings (`tools/w12_side_barge.gd:46` et al.), plus 6 unreferenced `tools/coordinator/*.sh|.py` helpers and 3 unreferenced `tools/sysaudit/*.gd` scripts. (An additional 53 tool scripts are referenced only in historical `.md`/`.tsv` docs.)
- fix: After Andrew's delete go-ahead (`AGENTS.md` requires explicit approval before deleting tracked files), list the 72 strictly dead scripts (and their `.gd.uid` sidecars) in `housekeeping/pending-deletes.md` and delete them in batches (starting with the 18 `w12_*.gd` files and the 5 `craft_*_capture.gd` / one-off capture scripts). Keep or wire the 5 standalone Python selftests (`tools/ace/package_render_music_test.py`, `tools/mix/cue_reel_test.py`, `tools/mix/mixsim_test.py`, `tools/park_reactor_ideal_check_test.py`, `tools/tile_check_selftest.py`) only if a CI command actually runs them.
- files to change: 72 files (+ 54 `.gd.uid` sidecars) under `sketches/core-loop/tools/` (see exact list from repo scan; largest 20 named above; plus `w12_recipe_cart_side.gd` and the 4 comment-only `w12_side_*.gd` files)
- size: ~0 added, ~15,489–17,466 removed
- risk: low — zero callers in `src/`, `tests/`, `scripts/`, `package.json`, skills, or CI; zero gameplay or test impact.
- behaviour-preserving: yes — none of these files are loaded by the game, tests, build, or any script.
- tests that cover it: none (zero references in `sketches/core-loop/tests/` or `scripts/`)
- guard: A lightweight check in `scripts/` (or `sketch-lint.mjs` report) flagging any `tools/*.gd` not referenced by `scripts/`, `tests/`, `tools/`, `.agents/skills/`, or a `tools/TOOLS-MANIFEST.json` allowlist of manual developer CLIs.

### TT-02 13 copy-pasted `w12_side_*.gd` / `w12_recipe_cart_side.gd` scripts duplicate ~309 identical lines each (5,070 lines total)
- kind: A
- evidence: `git ls-files sketches/core-loop/tools/w12_side_*.gd sketches/core-loop/tools/w12_recipe_cart_side.gd` lists 13 files totaling **5,070 lines** (`w12_recipe_cart_side.gd` 344L, `w12_side_barge.gd` 385L, `w12_side_cannon_launcher.gd` 398L, `w12_side_cottonwood.gd` 379L, `w12_side_fabricator_hoop.gd` 377L, `w12_side_gauge_dial.gd` 380L, `w12_side_geyser_launcher.gd` 402L, `w12_side_kicker_wedge.gd` 390L, `w12_side_lift_platform.gd` 404L, `w12_side_moss_hover_barge.gd` 390L, `w12_side_moss_jukebox.gd` 382L, `w12_side_trebuchet_launcher.gd` 430L, `w12_side_valve_wheel.gd` 409L). Diffing `tools/w12_side_barge.gd` (385L) against `tools/w12_side_cottonwood.gd` (379L) shows **309 identical non-empty lines** (`_slots`, `_glb`, `_ball`, `_shot`, `_sheet`, `_show`, `_bbox`, `_layers`, `_detail`). All 12 `w12_side_*.gd` copies even retain the copy-pasted error message `push_error("w12_recipe_cart_side: cannot read %s" % path)` (e.g. `tools/w12_side_barge.gd:46`, `tools/w12_side_cannon_launcher.gd:45`, `tools/w12_side_cottonwood.gd:42`).
- fix: Preferred: delete all 13 under TT-01 once approved (none have any executable caller; only 4 are named in comments inside `tools/blender/*_detail1.py`). Alternative if wave-12 LOD comparisons are still needed: collapse all 13 into one parameterized `tools/w12_side_capture.gd` reading a small subject dictionary (~420L total).
- files to change: 13 files (`sketches/core-loop/tools/w12_recipe_cart_side.gd`, `sketches/core-loop/tools/w12_side_*.gd`) + 13 `.uid` files
- size: +0 / -5,070 (delete) or +50 / -4,650 (consolidate)
- risk: low — zero runtime or test callers.
- behaviour-preserving: yes — unused offline capture scripts.
- tests that cover it: none
- guard: None needed once deleted; if consolidated, put shared camera/sheet helpers in a capture support module (TT-08).

### TT-03 Static-var reset registration in `test_batch_driver.gd` has four split owners, 7+ reset conventions, 21 inline mutations, and live uncalled `reset_for_tests()` methods
- kind: F
- evidence: Registering a new mutable `static var` in `src/` currently spans four files with no single owner:
  1. **Owning `src/*.gd` script**: 189 `src/` files declare 494 `static var`s, using **7+ different reset method names** (`reset_for_tests`: 58, `_reset`: 7, `reset`: 6, plus ad-hoc `clear_force`, `reset_ally`, `reset_prewarm`, `reset_drain`, `quiet`, `set_motion_statics`).
  2. **`sketches/core-loop/tools/test_batch_driver.gd`** (82 `src/` preloads/refs): calls 65 reset methods (lines 178–249), **directly reaches into 4 private `_reset()` methods** (`ExperimentalAudioBank._reset()` L243, `LiveRunBridge._reset()` L244, `ParkRecipes._reset()` L247, `World23ChunkCraft._reset()` L248 — note `world23_chunk_craft.gd` already defines `reset_for_tests()`!), **dynamically loads tracked `w50_asset_hooks.gd`** with dual `has_method` checks (L233–239), and **directly mutates 17 static fields on 16 modules inline** (L181 `FlashGuard.on = false`, L251–267 `SimClock.ticks`, `Glyphs.device`, `SettingsPages.last_page`, `StageLocks.active`, `Synergies.table`, `EnemyMotion.headless_idle`, `EnemyClips.headless`, `Enemy.rim_color`, `WorldFx.current`, `Synth.score_transpose`, `Footings.plant_ignore_lines`, `RescueSite.model_path`/`scarf_path`, `MusicRows.stem_dir`, `HighdraftFx.shader_dir`, `QuietGun.housing_path`).
  3. **`scripts/sketch-lint.mjs`** (`L14_STATIC_VAR_BASELINE`, L767–1093): freezes **325** static vars out of L14 checks — including **3 stale entries whose vars no longer exist** (`src/combat/rivet_kit.gd:_cap_unit`, `src/combat/rivet_kit.gd:_strip_unit`, `src/combat/threat_grammar.gd:_stripes`), **87 vars in files already registered in `test_batch_driver.gd`**, and **2 modules that ALREADY wrote `static func reset_for_tests()` yet were NEVER wired into `test_batch_driver.gd`**: `src/presentation/craft/craft_lookdev.gd:55` (`_cache`, `_unmasked_cache`, baselined at `sketch-lint.mjs:953-954`) and `src/presentation/harpoon_physics_rig.gd:36` (8 mesh/material statics, baselined at `sketch-lint.mjs:974-981`), plus `src/presentation/sfx_bank.gd` (12 statics + `reset_voice_sidecar()`, baselined at `sketch-lint.mjs:1006-1017`).
  4. **`sketches/core-loop/tests/test_batch_reset_test.gd`**: duplicates preloads manually and has drifted by **20 modules** present in `test_batch_driver.gd` but absent from `test_batch_reset_test.gd` (e.g., `craft_prop_meshes.gd`, `enemy_boss_craft.gd`, `experimental_setpiece_craft.gd`, `experimental_audio_bank.gd`, `live_run_bridge.gd`, `park_recipes.gd`, `world23_chunk_craft.gd`, `craft_showcase_assembly.gd`).
- fix: Make `reset_for_tests()` the single standard static reset protocol and give registration one declarative list: (a) wire `CraftLookdev.reset_for_tests()` and `HarpoonPhysicsRig.reset_for_tests()` into `test_batch_driver.gd` and remove their entries + the 3 stale entries from `L14_STATIC_VAR_BASELINE`; (b) replace the 17 inline field writes (L181, L251–267) and 4 private `_reset()` calls + dynamic `w50_asset_hooks` load with standard `reset_for_tests()` calls driven by one `const RESET_MODULES := [...]` array in `test_batch_driver.gd` (eliminating per-module boilerplate in `_reset()`); (c) have `test_batch_reset_test.gd` assert every module in `Driver.RESET_MODULES` responds to `reset_for_tests`.
- files to change: `sketches/core-loop/tools/test_batch_driver.gd`, `scripts/sketch-lint.mjs`, `sketches/core-loop/tests/test_batch_reset_test.gd`, and the ~18 `src/` files getting a 2-line `static func reset_for_tests()` wrapper for their currently inline-mutated statics
- size: ~+120 / -180 lines
- risk: medium — touches warm-batch test isolation; verify with `npm run sketch:fast -- --shuffle` and `tests/test_batch_reset_test.gd`. Must preserve exact reset order where `Palette.ARC` or `tree` is needed (`AttackBudget.reset_ally(tree)` stays explicit).
- behaviour-preserving: yes — runtime gameplay does not execute `test_batch_driver.gd`; warm-batch test isolation strictly improves.
- tests that cover it: `sketches/core-loop/tests/test_batch_reset_test.gd`, `sketches/core-loop/tests/buff_ledger_test.gd`, `scripts/sketch-lint.test.mjs`
- guard: Extend `lintL14` in `scripts/sketch-lint.mjs` to (1) fail on stale `L14_STATIC_VAR_BASELINE` entries (mirroring `applyBaseline`), (2) fail if a `src/` file declares `static func reset_for_tests()` without being registered in `test_batch_driver.gd`, and (3) disallow direct field writes or `_reset()` calls in `test_batch_driver.gd`.

### TT-04 Mutable `static var`s in `tools/` libraries are invisible to `L14` and never reset between warm-batched tests
- kind: F
- evidence: 4 shared `tools/` scripts preloaded by tests declare **15 mutable `static var`s** that `test_batch_driver.gd` never resets and `sketch-lint.mjs` `L14` ignores (because `lintL14` only scans `src/`):
  - `tools/bot_profile.gd:3-11`: `enabled`, `_stack`, `_totals`, `_samples`, `_tick_start`, `_tick_count`, `_physics_end`, `_pending`, `_monitors`
  - `tools/skill_band.gd:25-26`: `quiet`, `last_refusal` (8 callers; `tests/skill_band_test.gd:75` mutates `SkillBand.quiet = true`)
  - `tools/traversal_line.gd:70-72`: `graph_notes`, `_park_defs_source`, `_graphs` (8 callers; `tests/traversal_measure_test.gd:229-237` asserts `TraversalLine.graph_notes == 0` then `1`!)
  - `tools/bot_fairness.gd:9`: `_config` (5 callers; `tests/unit_suite_test.gd:38` reaches in with `BotFairness._config = {}`)
  Also `tests/support/cosmetic_art.gd:10` caches `static var _shipping := {}`.
- fix: Add `static func reset_for_tests() -> void` to `bot_profile.gd`, `skill_band.gd`, `traversal_line.gd`, and `bot_fairness.gd`, register them in `test_batch_driver.gd`, and replace `tests/unit_suite_test.gd:38`'s `BotFairness._config = {}` reach-in with `BotFairness.reset_for_tests()`.
- files to change: `sketches/core-loop/tools/bot_profile.gd`, `sketches/core-loop/tools/skill_band.gd`, `sketches/core-loop/tools/traversal_line.gd`, `sketches/core-loop/tools/bot_fairness.gd`, `sketches/core-loop/tools/test_batch_driver.gd`, `sketches/core-loop/tests/unit_suite_test.gd`
- size: ~+45 / -5 lines
- risk: low — only clears cached/mutable test-tool state between warm-batched test files.
- behaviour-preserving: yes — fixes latent `--shuffle` ordering dependence across tests that preload `tools/`.
- tests that cover it: `sketches/core-loop/tests/skill_band_test.gd`, `sketches/core-loop/tests/traversal_measure_test.gd`, `sketches/core-loop/tests/unit_suite_test.gd`, `sketches/core-loop/tests/bot_fairness_test.gd`, `sketches/core-loop/tests/test_batch_reset_test.gd`
- guard: Extend `lintL14` in `scripts/sketch-lint.mjs` to scan `tools/*.gd` files that are preloaded by `tests/` (excluding `tools/test_batch_shim.gd:batch`).

### TT-05 131 test/tool files hand-move `player.body().global_position =` and 27 reach into `player._rigid`, bypassing `PlayerBall.reset_to()` and `body()`
- kind: C
- evidence: `src/movement/player_ball.gd` already exposes `body()` (L242), `active_body()` (L246), `shown_position()` (L260), and `reset_to(point, velocity)` (L306) — the exact public API that `L10` enforces in `src/`. Yet outside `src/`:
  - `git grep -F "body().global_position =" -- sketches/core-loop/tools sketches/core-loop/tests` -> **181 hits across 131 files** (12 tools, 119 tests), including `tests/doubles/boss_harness.gd:28-29` (`game.player.body().global_position = at` immediately followed by `game.player.reset_to(at, velocity)`!) and `tests/activities_camp_test.gd:32-33` (`_game.player.reset_to(at, Vector3.ZERO)` followed by `_game.player.body().global_position = at`!).
  - `git grep -F "player._rigid" -- sketches/core-loop/tools sketches/core-loop/tests` -> **55 hits across 27 files** (1 tool: `tools/traversal_line.gd:282,692`, 26 tests: e.g. `tests/challenge_dials_stage_test.gd:175`, `tests/challenge_dials_warden_test.gd:63`, `tests/boss_weak_parts_test.gd:234-235`).
  - `git grep -F "player._visual_root" -- sketches/core-loop/tools sketches/core-loop/tests` -> **6 hits across 5 tools** (`tools/asset_capture.gd:327,336`, `tools/cliff_gate_export.gd:60`, `tools/look_capture.gd:93`, etc.), moving the visual node directly instead of `player.reset_to()`.
- fix: Remove the redundant `body().global_position =` line from `tests/doubles/boss_harness.gd:28` first, then mechanically replace `player._rigid` with `player.body()` (or `player.reset_to(...)` for position/velocity writes) across the 12 tools and 26+ tests in small domain batches. (Note: `boss_weak_parts_test.gd:234` accesses `recent_velocities` on the rigid body, which works via `player.body().recent_velocities`.)
- files to change: 12 tools + ~130 test files (start with `tests/doubles/boss_harness.gd`, `tools/ambient_capture.gd`, `tools/traversal_line.gd`, `tools/asset_capture.gd`, `tests/activities_camp_test.gd`, `tests/challenge_dials_stage_test.gd`)
- size: ~+160 / -240 lines across batches
- risk: low-to-medium — `reset_to()` zeroes/sets velocity and updates interpolation state cleanly; tests that specifically set position without clearing velocity need `player.reset_to(at, player.body().linear_velocity)`. Verify each batch with its focused tests.
- behaviour-preserving: yes — for `boss_harness.gd` and `activities_camp_test.gd` it removes an already-overwritten duplicate write; for others it routes placement through the single owner.
- tests that cover it: the modified test files themselves + `sketches/core-loop/tests/asset_capture_test.gd`, `sketches/core-loop/tests/traversal_measure_test.gd`
- guard: Extend `L10` in `scripts/sketch-lint.mjs` with a shrinking baseline to cover `tools/` and `tests/`.

### TT-06 81 tool/test files read raw `DisplayServer.get_name()` instead of `AppShell.headless()`
- kind: G
- evidence: `L13` in `scripts/sketch-lint.mjs:753-765` enforces `AppShell.headless()` (`src/core/app_shell.gd`) across `src/`, but does not scan `tools/` or `tests/`.
  - `git grep -F "DisplayServer.get_name(" -- sketches/core-loop/tools sketches/core-loop/tests` -> **91 hits across 81 files** (70 tools, 11 tests), e.g. `tools/alpha_capture.gd:31`, `tools/ambient_capture.gd:33`, `tools/asset_capture.gd:98`, `tools/bot_options.gd:56`, `tools/look_harness.gd:77`, `tools/ui_screens_capture.gd:66`, `tools/visual_capture.gd:44`. (Only `tools/offscreen_window.gd:8`, `tools/visual_capture.gd:69` metadata logging, and `tests/app_shell_test.gd` legitimately read the driver name string.)
- fix: Replace `DisplayServer.get_name() == "headless"` with `AppShell.headless()` across active `tools/` and `tests/` (or centralize the check inside a shared capture boot helper per TT-08).
- files to change: ~78 files (excluding `tools/offscreen_window.gd`, `tests/app_shell_test.gd`, and metadata string logging; shrinks drastically after TT-01 removes dead capture scripts)
- size: ~+80 / -80 lines (or ~+10 / -70 after TT-01 + TT-08)
- risk: low — `AppShell.headless()` returns the exact same headless predicate.
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/app_shell_test.gd`, `sketches/core-loop/tests/bot_options_test.gd` (or `tests/bot_explore_by_test.gd`), `sketches/core-loop/tests/asset_capture_test.gd`
- guard: Extend `L13` in `scripts/sketch-lint.mjs` to `tools/` and `tests/` with an allowlist for `tools/offscreen_window.gd`, `tests/app_shell_test.gd`, and diagnostic metadata fields.

### TT-07 423 top-level tests hand-roll failure counters and `_check`/`_report` helpers instead of using `tests/support/t.gd`
- kind: A
- evidence: `sketches/core-loop/tests/support/t.gd` (41 lines: `check`, `eq`, `near`, `skip`, `verdict`) is already used by **1,033** top-level tests, but **423** of 1,485 top-level `tests/*.gd` files still hand-roll `var _failures := 0` and local `_report()` (249 files) / `_check()` (189 files) / `_finish()` (132 files) functions (e.g., `tests/ace_tracks_test.gd:15,50-53`, `tests/activities_camp_test.gd:14,24-27,70-71`, `tests/alpha_retry_continue_test.gd`, `tests/aim_mark_mount_test.gd`).
- fix: Migrate hand-rolled assertion helpers to `const T := preload("res://tests/support/t.gd")` in domain batches (e.g., 20–30 tests per PR), and add a lint rule prohibiting new `var _?failures` / `func _?report` boilerplate in new test files.
- files to change: 423 top-level `sketches/core-loop/tests/*_test.gd` files (incremental batches; zero changes to `t.gd`)
- size: ~+1,200 / -4,500 lines total across batches
- risk: low — pure test-reporting refactor; no game code touched.
- behaviour-preserving: yes — preserves every check predicate and exit code (`0` on pass, `1` on fail).
- tests that cover it: each migrated test file itself (run via `npm run sketch:fast`)
- guard: A lightweight check in `scripts/sketch-lint.mjs` baselining the existing 423 tests and requiring new `tests/*_test.gd` files to preload `tests/support/t.gd`.

### TT-08 856 tests repeat `Game.new()` + run-boot boilerplate and 268+ repeat frame-stepping loops with no general `tests/support/` boot or step helper
- kind: A
- evidence: Pattern counts across all 1,485 top-level `tests/*.gd` files:
  - **856** files instantiate `Game.new()`, set `game.test_mode = true`, call `root.add_child(game)`, and wait for `game.flow != null`; **604** also call `game.flow.press_start()` + `game.flow.choose_class(...)`; **113** define a local `_boot()` / `_start_run()` / `_make_game()` helper (`tests/activities_camp_test.gd:44-63`, `tests/ace_tracks_test.gd:45-76`, `tests/challenge_dials_stage_test.gd:45-48`). Four existing helpers each re-implement boot slightly differently: `tests/doubles/boss_harness.gd:18-20` (58 callers), `tests/doubles/module_harness.gd:33-35` (40 callers), `tests/support/lighting_harness.gd:7-19` (8 callers), `tests/support/menu_screens.gd:38-48` (2 callers).
  - **268** files define a local frame-stepping function (`_frames`: 183 files, `_step`: 32, `_settle`: 28, `_ticks`: 20, `_tick`: 16), and **305** write raw `for ...: await physics_frame` loops (plus **117** `await process_frame` loops). Meanwhile, **76** test files still carry **124** hardcoded 60 Hz frame-math literals baselined in `L15_HZ_BASELINE` (`scripts/sketch-lint.mjs:1170-1247`, e.g. `tests/activities_camp_test.gd:34`).
  - **14** test files (e.g. `tests/activities_camp_test.gd:75-83`, `tests/bot_six_pilots_test.gd:82-87`) also copy-paste recursive directory-deletion helpers (`_clear_storage`, `_remove_tree`, `_clear_dir`) matching `tools/test_batch_driver.gd:270-281`, and **32** test files + 4 tools hand-build `InputEventKey.new()` presses despite `tests/workshop/push.gd:31-37` (`Push.key`) already existing (32 callers).
- fix: Add one small, composable `tests/support/test_game.gd` (or `harness.gd`) offering: (1) `boot(tree, opts := {})` returning a ready `Game` (optional `table`, `calm`, `scripted_intent`, `class_index`, `max_hp`), (2) `step_physics(tree, count)` / `step_seconds(tree, seconds)` deriving ticks from `Engine.physics_ticks_per_second`, (3) `step_process(tree, count)`, and (4) `fresh_dir(tag)` / `clear_dir(path)` guarded to `user://test-*`. Move `tests/workshop/push.gd` (or re-export from `tests/support/input_push.gd`) for general key/mouse/pad synthesis. Adopt in new tests and incrementally in existing harnesses (`BossHarness`, `ModuleHarness`, `LightingHarness`, `MenuScreens`) and high-churn tests.
- files to change: 1 new file `sketches/core-loop/tests/support/test_game.gd`, then incrementally `tests/doubles/boss_harness.gd`, `tests/doubles/module_harness.gd`, `tests/support/lighting_harness.gd`, `tests/support/menu_screens.gd`, and tests touched during feature work (including draining the 76 `L15_HZ_BASELINE` files)
- size: ~+90 lines for helper; ~-15 to -30 lines per migrated test (1,500–3,000+ lines removable incrementally)
- risk: low — helper lives strictly under `tests/support/`; migrating tests in small batches keeps diffs verifiable and preserves RNG/frame counts when step counts match.
- behaviour-preserving: yes — helper executes the same `Game.new()` + `add_child` + `await` steps.
- tests that cover it: `sketches/core-loop/tests/test_batch_reset_test.gd` + any migrated tests
- guard: `L15` already blocks new hardcoded 60 Hz frame literals; add a brief note in `CONTRIBUTING.md` / `tests/support/` pointing new tests to `test_game.gd` and `push.gd`.

### TT-09 93 capture/probe scripts under `tools/` repeat identical viewport, `Game.new()`, `Camera3D`, screenshot, and CLI-arg boilerplate (~25.5k lines)
- kind: A
- evidence: Across 191 `tools/*.gd` files, **96** are capture/still/probe/audit scripts totaling **25,482 lines**:
  - **93** call `get_texture().get_image()` and **91** call `save_png(...)` (e.g. `tools/alpha_capture.gd:145-149`, `tools/w12_side_barge.gd:64-71`, `tools/ui_screens_capture.gd:108`, `tools/asset_capture.gd`).
  - **66** of those also construct and position their own `Camera3D.new()` (`tools/ambient_capture.gd:87-91`, `tools/look_harness.gd:40`, `tools/visual_capture.gd:21`), and **59** also boot `Game.new()` + `press_start()` + `choose_class()` (`tools/alpha_capture.gd:45-47`, `tools/ambient_capture.gd:55-65`, `tools/ui_screens_capture.gd:75-77`, `tools/visual_capture.gd:78-80,108-113`).
  - **37** define a local `_shot()`, **33** define `_frames()`, **22** define `_finish()`, **14** define `_sheet()` (horizontal PNG contact-sheet composer, e.g. `tools/w12_side_barge.gd:74-88`).
  - Existing shared capture helpers `tools/capture_cameras.gd` (108L, 4 callers) and `tools/offscreen_window.gd` (13L, 5 callers) cover only preset camera coords and Mac embedded-display assertion, leaving viewport sizing (`1920x1080` / `1280x720`, `CONTENT_SCALE_MODE_VIEWPORT`, `VSYNC_DISABLED`), headless guard, `Game` boot, `frame_post_draw` PNG capture, contact-sheet stitching, and CLI arg parsing copy-pasted in every script.
- fix: Extract a small `tools/capture_kit.gd` (`RefCounted`) providing: `parse_args()`, `require_display(root, size, no_vsync := true)` (using `AppShell.headless()` + `OffscreenWindow.apply()`), `boot_game(tree, opts := {})`, `make_camera(parent, fov, near, far)`, `grab_png(root, path, settle_frames := 8)`, and `compose_sheet(images, path, height)`. Migrate active capture tools (`look_harness.gd`, `asset_capture.gd`, `map_sheet_capture.gd`, `ui_screens_capture.gd`, `alpha_capture.gd`, `visual_capture.gd`, `stress_capture.gd`, `kinetic_sheet_capture.gd`) after pruning the dead ones in TT-01.
- files to change: 1 new file `sketches/core-loop/tools/capture_kit.gd` + ~15–25 live capture tools (after TT-01 removes ~40 dead capture scripts)
- size: ~+140 lines added, ~-1,200 to -2,000 lines removed across active capture tools
- risk: low — offline capture/probe scripts only; zero gameplay impact. Keep exact `settle_frames` and viewport size arguments per tool so baseline image sizes do not shift.
- behaviour-preserving: yes — produces identical viewport dimensions and PNG frames.
- tests that cover it: `sketches/core-loop/tests/asset_capture_test.gd`, `sketches/core-loop/tests/map_sheet_capture_test.gd`, `sketches/core-loop/tests/kinetic_sheet_capture_test.gd`, `sketches/core-loop/tests/look_frames_test.gd`
- guard: `scripts/sketch-lint.mjs` rule or review checklist item flagging new `get_texture().get_image()` / `OS.get_cmdline_user_args()` duplication in `tools/`.

### TT-10 Tests and tools bypass existing public accessors on `Screens`, `Warden`, and `Game` (`screens._body`, `warden._posture`, workshop scan)
- kind: C
- evidence: Verified against `src/` public APIs:
  - **`screens._body.text`** (`git grep -F "screens._body" -- sketches/core-loop/tools sketches/core-loop/tests` -> **21 hits across 9 test files**, e.g. `tests/bot_run_end_test.gd:167`, `tests/death_summary_loop_test.gd:180`), even though `src/ui/screens.gd` already provides `said_body()` (L351) and `body_text()` (L1931).
  - **`warden._posture`** (`git grep -F "._posture" -- sketches/core-loop/tools sketches/core-loop/tests` -> **166 hits across 44 files**: 43 tests + `tools/park_reactor_ideal.gd:75-78`), where read-only callers can call `src/combat/warden.gd:940`'s public `posture()` instead of reading `_posture.posture` (writes/config checks like `tests/arena_posture_record_test.gd:53-55,104` legitimately need a small test seam or `posture_state()`).
  - **`tools/alpha_capture.gd:118-121`** iterates `_game.get_children()` matching `String(script.resource_path).ends_with("ui/workshop.gd")` even though `src/game.gd` already exposes `func workshop()`.
- fix: Switch read-only `screens._body.text` calls to `screens.body_text()`/`said_body()`, switch read-only `warden._posture` reads to `warden.posture()`, and replace `tools/alpha_capture.gd:118-121` with `_game.workshop().armed = true`.
- files to change: `sketches/core-loop/tools/alpha_capture.gd`, `sketches/core-loop/tools/park_reactor_ideal.gd` (or delete under TT-01), ~9 tests using `screens._body.text`, and ~20 tests doing read-only `warden._posture.posture` reads
- size: ~+40 / -55 lines
- risk: low — switches callers to already-existing public getters.
- behaviour-preserving: yes.
- tests that cover it: `sketches/core-loop/tests/bot_run_end_test.gd`, `sketches/core-loop/tests/death_summary_loop_test.gd`, `sketches/core-loop/tests/arena_posture_record_test.gd`
- guard: `scripts/deep-sweep.mjs` `D2` already flags new underscore reach-ins in `tools/` diffs; extending `D2` to `tests/` (report-only) surfaces regressions at review.

### TT-11 High-frequency reach-ins into `Game`, `Audio`, `Flow`, and `BotDriver` lack thin public seams (350+ hits across 100+ files)
- kind: C
- evidence: Exact `git grep -F` counts across `sketches/core-loop/tools` and `sketches/core-loop/tests`:
  - `game._screen_key(...)`: **153 hits across 36 files** (34 tests, 2 tools — e.g. `tests/alpha_flow_run_test.gd:96-98`, `tests/camp_hub_test.gd:92`, `tools/clip_dump.gd:68`). `src/game.gd:1305` only defines private `_screen_key(key: int)`.
  - `audio._flush_flow()`: **81 hits across 35 tests** (`tests/ace_arena_release_test.gd:80`, `tests/ace_tracks_test.gd:67`); `audio._last_start`: **65 hits across 30 tests** (`tests/audio_achievement_test.gd:45`); `audio._pump(...)`: **33 hits across 24 tests** (`tests/ace_arena_release_test.gd:51`).
  - `flow._finish_stage()`: **33 hits across 29 files** (6 tools, 23 tests); `flow._set_state(...)`: **44 hits across 27 files** (4 tools, 23 tests); `flow._boss_module()` / `flow._module_for(w)`: **20 hits across 12 files** (4 tools, 8 tests including `tests/doubles/module_harness.gd:51`).
  - `_driver._end(...)`: **16 hits across 10 files** (7 tools: `tools/band_run.gd:58`, `tools/bot_run.gd:326`, `tools/matchup_lab.gd:1213`, `tools/priority_proof.gd:430`, `tools/traversal_line.gd:1293`; 3 tests); `driver._note`: **52 hits across 13 files** (2 tools: `tools/bot_kite.gd:48`, `tools/bot_loops.gd:91`; 11 tests: `tests/bot_chain_hand_test.gd:158`).
- fix: Promote the cleanest, most-called seams to thin public methods on the owning classes rather than having dozens of callers reach past `_`: (1) on `BotDriver`, expose `finish(why: String)` (replacing `_end`) and `note_value(key, default)` / `note_snapshot()` (replacing `_note`); (2) on `Audio`, expose `flush_flow()`, `clear_cooldowns()` (replacing `_last_start.clear()`), and `pump_frames(n)`; (3) on `Game`, expose `send_screen_key(key: int)` (or drive via `Push.key(root, key)` where real input is wanted); (4) on `Flow`, expose `boss_module(world := 0)` (replacing `_boss_module()` and `_module_for(w)`). Leave `flow._set_state()` and `flow._finish_stage()` internal unless a dedicated test-seam review wants them public, since tests intentionally jump states there.
- files to change: `sketches/core-loop/tools/bot_driver.gd`, `sketches/core-loop/src/presentation/audio.gd`, `sketches/core-loop/src/game.gd`, `sketches/core-loop/src/core/flow.gd`, plus callers in batches (~20 tools, ~100 tests)
- size: ~+40 lines in owners; ~±300 mechanical call-site updates across batches
- risk: low-to-medium — pure method rename/thin public wrapper; zero state or timing change. `BotDriver` and `Audio` seams are lowest risk; `Game` and `Flow` seams should land in separate small PRs.
- behaviour-preserving: yes — wrappers call the exact same underlying logic in the same order.
- tests that cover it: `sketches/core-loop/tests/ace_arena_release_test.gd`, `sketches/core-loop/tests/ace_tracks_test.gd`, `sketches/core-loop/tests/audio_achievement_test.gd`, `sketches/core-loop/tests/alpha_flow_run_test.gd`, `sketches/core-loop/tests/bot_chain_hand_test.gd`, `sketches/core-loop/tests/spine_worlds_test.gd`
- guard: `scripts/deep-sweep.mjs` `D2` already monitors new `tools/` reach-ins on every PR.

### TT-12 Five stage-table test doubles in `tests/doubles/` copy-paste the exact same 16 static methods (517 lines)
- kind: A
- evidence: `sketches/core-loop/tests/doubles/dig_table_defs.gd` (86L, 5 callers), `highdraft_table_defs.gd` (85L, 1 caller), `highdraft_world_three_defs.gd` (85L, 1 caller), `row_packs_defs.gd` (90L, 1 caller), and `two_world_defs.gd` (171L, 65 callers) each implement the identical 16-method static `StageDefs` protocol (`of`, `is_last`, `world_of`, `local`, `first_of`, `last_of`, `worlds`, `is_world_last`, `is_run_last`, `synergy_in_play`, `part_in_play`, `parts_listed`, `packs`, `elite`, `elite_arrival`, `has_vault`). Comparing `dig_table_defs.gd` and `highdraft_table_defs.gd` shows lines 20–84 are byte-for-byte identical; only `DEFS[0]` differs (`"map": "dig"` / `"warden_family": "reactor"` vs `"map": "highdraft"` / `"warden_family": "mind"`).
- fix: Create one `tests/doubles/stage_table_double.gd` factory (`static func make(defs: Array, opts := {}) -> StageTableDouble` or a shared base class) implementing the 16 `StageDefs` methods once, and reduce the 5 doubles to small data-only declarations (or inline the 3 single-caller configs into their lone test).
- files to change: `sketches/core-loop/tests/doubles/dig_table_defs.gd`, `highdraft_table_defs.gd`, `highdraft_world_three_defs.gd`, `row_packs_defs.gd`, `two_world_defs.gd` (+ 1 new `stage_table_double.gd` if keeping instance/base pattern; check whether `ctx.stages` callers accept an instance vs script class)
- size: ~+60 / -340 lines
- risk: low — test doubles only; verify whether `src/core/flow.gd` calls methods on `ctx.stages` via dynamic dispatch (works on both script classes and instances).
- behaviour-preserving: yes — identical `DEFS` rows and return values.
- tests that cover it: the 73 tests preloading these 5 doubles (e.g. `tests/spine_worlds_test.gd`, `tests/dig_combat_test.gd`, `tests/highdraft_combat_test.gd`)
- guard: Review check when adding new files under `tests/doubles/`.

### TT-13 `boss_spawner_double.gd` and `spine_spawner_double.gd` duplicate combat strike/plating math
- kind: A
- evidence: `sketches/core-loop/tests/doubles/boss_spawner_double.gd` (130L, 1 caller: `tests/doubles/boss_harness.gd`) and `sketches/core-loop/tests/doubles/spine_spawner_double.gd` (132L, 16 callers) both duplicate `STRIKE_DAMAGE` (`{"stomp": [30.0, 1.1], "ram": [14.0, 1.3], "slam": [0.0, 1.2]}`), `CRUISE_TIER := 1`, `CHIP := 0.2`, `punch_of()`, `punch_now()`, `integrity_of()`, `would_crush()`, and strike deflection event emission (`enemy_struck`, `strike_deflected`). Worse, `STRIKE_DAMAGE` here is a hardcoded copy of combat's damage formula (`src/combat/combat.gd`).
- fix: Extract a shared `tests/doubles/spawner_double_base.gd` (or merge into one configurable double with `mode := "boss" | "spine"`) and import `STRIKE_DAMAGE` / `CHIP` from `src/combat/combat.gd` (if exposed as constants) so strike math has one owner.
- files to change: `sketches/core-loop/tests/doubles/boss_spawner_double.gd`, `sketches/core-loop/tests/doubles/spine_spawner_double.gd`
- size: ~+30 / -85 lines
- risk: low — test doubles only, covered by 58 boss-harness tests + 16 spine tests.
- behaviour-preserving: yes — keeps `Marker` (boss lobber) vs `DoubleEnemy` (`CharacterBody3D` + `delay_deaths`) behaviours intact.
- tests that cover it: all 58 `boss_harness.gd` callers + 16 `spine_spawner_double.gd` callers (e.g. `tests/boss_flow_test.gd`, `tests/spine_worlds_test.gd`)
- guard: None needed beyond existing boss/spine tests.

### TT-14 `tools/bot_driver.gd` (4,710 lines) bundles self-contained inner classes and cohesive subsystems with natural extraction seams
- kind: H
- evidence: `sketches/core-loop/tools/bot_driver.gd` is **4,710 lines** with 227 `const`s, 204 `var`s, 204 functions, and 82 callers (`bot_run.gd`, band/posture/fairness tools and tests). It already contains one completely self-contained seam:
  - `class CuedRing` + `class BrindleRings` (`tools/bot_driver.gd:3291-3461`, **171 lines**): both extend `RefCounted`, own their own `const Rules := preload(...)` and private fields (`known`, `_tick`, `_first`, `_cue`, `_cue_known`), and touch zero `BotDriver` instance variables.
  - Around that, three further cohesive groups have narrow data interfaces to `BotDriver`: (a) terrain/kicker/graph climb routing (`_climb_route`, `_cable_mouths`, `_kickers_within`, `_kicker_height`, `_graph_path`, L1843–2145, ~300L), (b) gate approach/prop-avoidance geometry (`_gate_runup`, `_gate_probe`, `_body_shapes`, `_prop_footprint`, `_gate_round_props`, L3578–3700, ~125L), and (c) run-note/telemetry aggregation (`_note_*`, `_boss_*`, `note_worst_window`, `drawn_pockets`, `record()`, L890–1255 + L4679–4710, ~390L).
- fix: Extract `CuedRing` + `BrindleRings` first into `tools/bot_brindle_rings.gd` (re-exporting `const CuedRing` and `const BrindleRings` on `BotDriver` so existing callers like `tests/bot_brindle_rings_test.gd` need zero edits), then extract the pure geometric/routing helpers (`tools/bot_route.gd`) and telemetry recorder (`tools/bot_notes.gd`) in separate PRs, keeping RNG draw order and tick sequence untouched.
- files to change: `sketches/core-loop/tools/bot_driver.gd` + 1–3 new helper files (`tools/bot_brindle_rings.gd`, `tools/bot_route.gd`, `tools/bot_notes.gd`)
- size: ~+600 / -580 lines across 3 small PRs
- risk: medium — `bot_driver.gd` drives bot bands and posture/fairness tests (per `DEEP-SWEEP.md`, anything a bot band reads is sensitive to RNG/tick order). Extracting `CuedRing`/`BrindleRings` and pure geometry helpers first is low risk because neither touches `_dodge_rng` or tick order; verify with `tests/bot_brindle_rings_test.gd` and bot fast tests.
- behaviour-preserving: yes — pure file split with identical call sequence and zero RNG changes.
- tests that cover it: `sketches/core-loop/tests/bot_brindle_rings_test.gd`, `sketches/core-loop/tests/bot_cadence_band_test.gd`, `sketches/core-loop/tests/bot_fairness_test.gd`, `sketches/core-loop/tests/bot_gate_leg_limit_test.gd`, and 78 other `bot_*` tests
- guard: `scripts/deep-sweep.mjs` `D5` (1500+ line file growth) currently checks `src/` only; extending `D5` to `tools/` prevents `bot_driver.gd` from growing past 4.7k lines again.

### TT-15 Hardcoded `/home/andrew/` Linux paths appear in 19 files across `tools/` and `tests/`, including active scripts, and `tests/hotwire_cue_parallel.sh` leaks past `L4` via baseline
- kind: E
- evidence: `git grep -n "/home/andrew" sketches/core-loop/tools sketches/core-loop/tests` returns **26 hits across 19 files**, including active non-doc scripts that `npm run check:docs` does not scan (since `check:docs` only checks `.md` files):
  - `tools/blender/cycles_device.py:42`: `CAPTURE_DIR = os.environ.get("SCRAPKEEP_CAPTURE_DIR", "/home/andrew/scratch/w18/gates")` (46 Blender importers; stale wave 18 default!)
  - `tests/hotwire_cue_parallel.sh:3`: `G=${GODOT:-/home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64}` (also the sole file baselined in `scripts/sketch-lint.baseline.json:28` under `L4` for sitting at `tests/` root!)
  - `tools/coordinator/compile_check.sh:6`, `tools/coordinator/lab_capture.sh:7-8` (also baselined under `L3` at `scripts/sketch-lint.baseline.json:25`!), `tools/coordinator/watch_codex.sh:5`
  - `tools/ace/cut_stingers.py:28`, `tools/ace/package_core_packs.py:36`, `tools/ace/package_music.py:44`, `tools/blender/dig_stone/verify.py:18`, `tools/blender/pilot_cannon.py:33`, `tools/hud_mock.py:15`
  - Plus 3 `tools/*.md` files (`seam_strip_capture.md:10`, `tripo/README.md:28`, `ui_screens_capture.md:10`) and 2 `tests/fixtures/*.json` notes.
- fix: Replace hardcoded `/home/andrew/` defaults in active scripts (`cycles_device.py`, `dig_stone/verify.py`, `pilot_cannon.py`, `ace/*.py`) with relative repo paths (`Path(__file__).resolve()`) or `os.path.expanduser("~")` / required env vars; move `tests/hotwire_cue_parallel.sh` under `tools/` (or remove if superseded) to clear the `L4` baseline entry in `scripts/sketch-lint.baseline.json`.
- files to change: `sketches/core-loop/tools/blender/cycles_device.py`, `sketches/core-loop/tests/hotwire_cue_parallel.sh`, `scripts/sketch-lint.baseline.json`, plus ~8 active scripts under `tools/` (others disappear under TT-01)
- size: ~+25 / -30 lines
- risk: low — defaults stay configurable via existing env vars (`SCRAPKEEP_CAPTURE_DIR`, `GODOT`).
- behaviour-preserving: yes — scripts continue working on Linux PC when env vars are set and stop embedding another machine's username/stale wave path.
- tests that cover it: `sketches/core-loop/tools/blender/cycles_device_test.py`, `scripts/sketch-lint.test.mjs`
- guard: Extend the `/home/andrew/` check from `npm run check:docs` to `.py`, `.sh`, and `.gd` files under `tools/` and `tests/` (excluding historical `.json` fixture provenance notes if desired).

### TT-16 `tools/blender/park/props/kit.py` hardcodes duplicated palette/banned/warn hex constants instead of reading `tools/palette_gd.py`
- kind: E
- evidence: `sketches/core-loop/tools/palette_gd.py` exists specifically so Python asset tools read `src/core/palette.gd` as the single source of truth (used by 7 Blender scripts and `tools/icons/generate_icons.py`, verified by `scripts/palette-gd.test.mjs`). Yet `sketches/core-loop/tools/blender/park/props/kit.py:61-73` (imported by 41 Blender prop recipes) re-declares `BANNED = {"ff5a3c", "9dff3c", "8bf0d3"}` (copying `HAZARD`, `ANCIENT`, `ARC`), `WARN = {"e5a044", "b77843", "d9b44a"}` (copying `AMBER`, `COPPER`, `BRASS`), and shared palette entries (`sandstone`, `cable`, `charcoal`, `bone`) as raw hex literals — while its `"verdigris": "5f8a7c"` and `"rust": "8a5a44"` sit alongside `palette.gd`'s `VERDIGRIS = 365754` and `RUST = 9b513a` without marking them as desaturated prop overrides.
- fix: Import `palette_gd` in `tools/blender/park/props/kit.py`, derive `BANNED = {palette_gd.HEX["HAZARD"], palette_gd.HEX["ANCIENT"], palette_gd.HEX["ARC"]}`, `WARN = {palette_gd.HEX["AMBER"], palette_gd.HEX["COPPER"], palette_gd.HEX["BRASS"]}`, and source the exact-match `C` entries (`sandstone`, `cable`, `charcoal`, `bone`) from `palette_gd.HEX`, keeping only the intentionally weathered/prop-specific shades (`concrete`, `timber`, `canvas`, `verdigris`, `rust`, `leaf`, `dry_grass`) as explicit prop tints.
- files to change: `sketches/core-loop/tools/blender/park/props/kit.py`
- size: ~+10 / -8 lines
- risk: low — resolved hex values stay identical for every existing prop recipe.
- behaviour-preserving: yes — produces byte-identical vertex colours in Blender exports.
- tests that cover it: `scripts/palette-gd.test.mjs`
- guard: Add a `kit.py` check to `scripts/palette-gd.test.mjs` verifying `BANNED`/`WARN` match `palette.gd`.

### TT-17 Three inconsistent CLI argument parsing idioms repeated across 146 `tools/*.gd` scripts
- kind: G
- evidence: Across 191 `tools/*.gd` files, **146** call `OS.get_cmdline_user_args()` directly using three incompatible hand-written loops:
  - **25** files build a `settings := {}` dictionary via `arg.substr(2, arg.find("=") - 2)` (`tools/alpha_capture.gd:28-30`, `tools/ambient_capture.gd:29-32`, `tools/ui_screens_capture.gd:51-53`, `tools/visual_capture.gd:41-43`).
  - **107** files chain 10–25 `elif arg.begins_with("--x="): x = arg.trim_prefix("--x=")` branches (`tools/asset_capture.gd:47-90`, `tools/look_harness.gd:49-64`).
  - **14** files use ad-hoc positional/split parsers (`tools/bot_run.gd:55`).
  Several tools (`tools/bot_run.gd:95-96`) even parse the same flag twice (`BotPlants.parse` called twice on lines 95 and 96).
- fix: Provide one tiny `CliArgs.parse(args := OS.get_cmdline_user_args())` helper (either standalone `tools/cli_args.gd` or inside `tools/capture_kit.gd` from TT-09) returning `{flags, kv, positional}` with typed getters (`str_opt`, `int_opt`, `float_opt`, `flag`), and adopt it as active tools are touched.
- files to change: 1 new 35-line helper `sketches/core-loop/tools/cli_args.gd` + incremental adoption in live `tools/*.gd` (especially `look_harness.gd`, `asset_capture.gd`, `bot_run.gd`, `alpha_capture.gd`, `ui_screens_capture.gd`, `visual_capture.gd`)
- size: ~+35 lines for helper; ~-10 to -40 lines per migrated tool
- risk: low — pure argument parsing in offline tools.
- behaviour-preserving: yes — accepts the exact same `--key=val` and `--flag` forms.
- tests that cover it: `sketches/core-loop/tests/asset_capture_test.gd`, `sketches/core-loop/tests/bot_explore_by_test.gd`, `sketches/core-loop/tests/map_sheet_capture_test.gd`
- guard: None needed beyond preferring `CliArgs` in new tools.

### TT-18 32 tests and 4 tools hand-roll `InputEventKey.new()` synthesis even though `tests/workshop/push.gd` already owns input pushing
- kind: A
- evidence: `sketches/core-loop/tests/workshop/push.gd` (46L, 32 callers) already provides `Push.hover()`, `Push.click()`, `Push.key()`, and `Push.pad()` pushing real `InputEvent*` events into `root.push_input(...)`. Yet **32** other test files and **4** tools (`tools/alpha_capture.gd:136-142` using `Input.parse_input_event` vs `root.push_input`) still hand-construct `InputEventKey.new()` press/release loops locally (`_press` appears as a local helper in 17 tests).
- fix: Move `tests/workshop/push.gd` to `tests/support/push.gd` (leaving a thin forwarding/re-export or updating the 32 workshop callers in one mechanical pass) so non-workshop tests discover it, and migrate hand-rolled `_press(keycode)` helpers to `Push.key(root, keycode)`.
- files to change: `sketches/core-loop/tests/workshop/push.gd` -> `sketches/core-loop/tests/support/push.gd`, plus 32 tests with hand-rolled `InputEventKey.new()` loops
- size: ~+0 / -220 lines
- risk: low — note that `root.push_input(event)` vs `Input.parse_input_event(event)` can differ slightly for unhandled-input routing; check tests that explicitly test `Input.parse_input_event` before switching them.
- behaviour-preserving: yes — same keycode/physical_keycode press+release pair.
- tests that cover it: the 32 existing `tests/workshop/push.gd` callers + migrated tests
- guard: Keep input synthesis in `tests/support/push.gd` as the single test input helper.

## Not findings

- `sketches/core-loop/tools/blender/common.py:18-31` (`HEX` literal table): looks like duplicated palette data, but `tools/palette_gd.py:8-10` explicitly documents that `common.py` keeps `HEX` as a literal because `tools/asset-forge` parses it via Python `ast`, and `python3 tools/palette_gd.py --check` + `scripts/palette-gd.test.mjs` already enforce zero drift against `src/core/palette.gd`.
- `FAULT_SWITCHES` entries `boss.gd:_reel_plant`, `contraptions.gd:test_no_warn`, and `terrain_faces.gd:keep_one_placement` missing from `tools/test_batch_driver.gd`: verified in `src/` (`boss.gd:87`, `contraptions.gd:131`, `terrain_faces.gd:276`) that all three are instance `var`s, not `static var`s, so freeing `tree.root` children in `_reset()` already clears them between warm-batched tests.
- `sketches/core-loop/src/game.gd`'s `SELF_PLAY := "res://tools/self_play.gd"` reference: guarded by `ResourceLoader.exists(script_path)` and explicitly allowed by `L7` (`scripts/sketch-lint.mjs:72-77`) so packed release builds without `tools/` stay clean.
- `sketches/core-loop/tools/offscreen_window.gd:8` reading `DisplayServer.get_name()`: intentionally checks for Mac's `"embedded"` driver string (not headless), so it cannot be replaced with `AppShell.headless()`.
- `sketches/core-loop/tools/test_batch_driver.gd:284-303` (`_NextGate` tween-drain and `_physics_process` ordering): looks intricate, but is a verified workaround for Godot's `SceneTree::process()` tween-drain and `MainTimerSync` order, stress-tested by `tests/test_batch_reset_test.gd:369-445` (20x20 fast-frame bursts).
- `sketches/core-loop/tests/QUARANTINE.tsv`: already empty (`MAX_QUARANTINE = 0` enforced by `L5`).
- `sketches/core-loop/tools/park_graph.gd:90-98` (`const DOOR_SPAWN_M := Placement.DOOR_SPAWN_M` etc.): thin re-aliases of `src/world/park/park_placement.gd` constants kept for compatibility with callers; they already have one owner (`park_placement.gd`), so no scattered-fact drift.
- `L1`–`L15` and `W1`–`W7`/`S8` lint rules in `scripts/sketch-lint.mjs`: already enforced automatically on `src/` and `tests/` (not re-reported here except where their scope misses `tools/` or their frozen baselines hide real drift in TT-03, TT-04, TT-05, TT-06, TT-15).
- `tests/support/t.gd` (41L) and `tests/support/platform_pin.gd` (13L): small, clean single-purpose helpers with clear ownership (1,033 and 6 callers respectively); not shallow forwarding wrappers.

## Needs the owner

- **Delete approval for dead tools (TT-01 / TT-02):** `AGENTS.md` requires Andrew's explicit go-ahead before deleting tracked files — approve deleting the 72 strictly unreferenced tool scripts (15,489L) + 5 comment-only `w12_side_*` scripts (1,977L), and decide whether the 53 doc-only historical capture/audit tools (referenced only in archived `BACKLOG.md` / `DESIGN-NOTES.md` / `design-v3/*.md`) should also be pruned or archived.
- **Policy on shrinking `L14_STATIC_VAR_BASELINE` (325 entries) and `L15_HZ_BASELINE` (76 files / 124 sites):** decide whether to drain both baselines down to zero (especially the 87 L14 entries in files already registered in `test_batch_driver.gd` and the 12 `sfx_bank.gd` statics) or freeze L14 strictly to read-only mesh/shader caches that never carry test-mutable state.
- **Python tool test runner decision:** decide whether the 5 standalone Python test scripts under `tools/` (`ace/package_render_music_test.py`, `mix/cue_reel_test.py`, `mix/mixsim_test.py`, `park_reactor_ideal_check_test.py`, `tile_check_selftest.py`) and `tools/blender/cycles_device_test.py` should be wired into an npm/CI check or retired with their parent tools.
