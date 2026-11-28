# Structure survey: core
commit: 23e935514ef33e7eb58d50e21bd2a5f757f41fa9   model: Gemini 4 Neon (high)   files read: 69   date: 2026-11-27

## Module map
`sketches/core-loop/src/core/pilot_story.gd` | 1834 | Pilot narrative chapters, camp beats, in-run calls, habit classifier and table validator | None (pure static data and pure/profile-mutating static helpers) | `src/core` (3), `src/ui` (3), `src/world` (3), `tests/` (6)
`sketches/core-loop/src/game.gd` | 1375 | Composition root wiring every module, input/gamepad router, launch-take gate and settings fan-out | Owns `ctx`, `_settings_store`, `_launch_take`, `_dev_console`, `_frame_log`, input/binding latches | `tools/` (8), `tests/` (903)
`sketches/core-loop/src/core/flow.gd` | 1341 | Run lifecycle state machine, stage transitions, retry/continue, launch swipe and camp handoff | Owns `_state`, `_launch_take`, `_start_card`, `_retry_pending`, `_victory_lap`, stage timers | `src/game.gd` (1), `src/core` (1), `src/presentation` (1), `tests/` (13)
`sketches/core-loop/src/core/run_state.gd` | 1327 | Active run state, hull/scrap/parts/relics/tallies mutators, stage snapshots and entrance-doc codec | Owns `hp`, `max_hp`, `scrap`, `cogs`, `bonus_cores`, `parts`, `relics`, `companion`, `extra`, `settled`, `_tallies`, `_stage_snapshot` | `src/core` (2), `src/ui` (2), `src/build` (1), `tests/` (83)
`sketches/core-loop/src/core/lore_rows.gd` | 1189 | World/stage lore rows, speaker roster, radio/field-note calls and camp exchanges | None (static const tables and pure lookup helpers) | `src/core` (4), `src/boss` (2), `src/presentation` (2), `tests/` (19)
`sketches/core-loop/src/core/work_orders.gd` | 1011 | Maker work-order definitions, shift offers, completion state in profile camp doc and table validator | None (persists under `profile.camp()["work_orders"]`) | `src/ui` (3), `src/core` (2), `tests/` (5)
`sketches/core-loop/src/core/event_kinds.gd` | 983 | Signal/event catalog, attack/threat/loot/UI display rows, plus presentation juice/impact/weight policy | None (static const tables and `weigh()`) | `src/ui` (22), `src/presentation` (21), `src/world` (12), `tests/` (138)
`sketches/core-loop/src/core/ability_state.gd` | 757 | Active ability slot model, cooldown/charge tracking, loadout swaps and keycap glyph resolution | Owns `slots`, `selected`, `cooldowns`, `charges`, plus `static var KEYS` | `src/combat` (8), `src/movement` (4), `src/ui` (4), `tests/` (71)
`sketches/core-loop/src/core/profile.gd` | 732 | Persistent player profile JSON (`profile.json`), stats, unlocks, camp doc, settled rewards and tallies | Owns `_data`, `can_save`, `last_error`, `path`, atomic save/transact rollback state | `src/game.gd` (1), `src/core` (1), `tests/` (64)
`sketches/core-loop/src/core/companion.gd` | 577 | Scrap-hound companion piece catalog, build rules, stat assembly and yard-clear salvage drop | None (model serialized to `run.companion` and `profile.companion`) | `src/core` (3), `src/ui` (3), `src/presentation` (2), `tests/` (32)
`sketches/core-loop/src/core/palette.gd` | 567 | Game color constants plus procedural texture, StandardMaterial3D, surface grain and threaded sky factory | Owns 17 `static var` texture/material/sky caches and `WorkerThreadPool` jobs | `src/presentation` (60), `src/ui` (52), `src/world` (39), `tests/` (195)
`sketches/core-loop/src/core/progress.gd` | 567 | Achievement, mastery, habit-stat, shift-board and work-order listener translating `GameEvents` into `Profile` updates | Owns `_profile`, `_events`, `_run`, `_story_chapter_hook`, run/stage counters | `src/game.gd` (1), `tests/` (25)
`sketches/core-loop/src/core/run_log.gd` | 537 | Per-run telemetry collector and `runs.ndjson` record writer (delegated through `Codex.append_line`) | Owns `_events`, `_run`, `_codex`, per-stage posture/event/speed/death counters | `src/game.gd` (1), `tools/` (1), `tests/` (14)
`sketches/core-loop/src/core/upgrade_tree.gd` | 523 | Six-pilot upgrade tree loader, offer roller, knob/pattern/proc applier and cross-module validator | Owns `static var unknown_warned` | `src/combat` (2), `src/core` (2), `src/movement` (2), `tests/` (39)
`sketches/core-loop/src/core/shift_board.gd` | 522 | Shift-board rung and world-rung tables, unlock queries, reward copy and table validators | None (static tables reading `profile.stat`) | `src/core` (2), `src/ui` (2), `src/game.gd` (1), `tests/` (10)
`sketches/core-loop/src/core/content_registry.gd` | 512 | Cross-module static content integrity validator (events, audio, codex, parts, synergies, trees, icons) | Owns `static var _pass_depth`, `_pass` | `src/` (0 — test-only), `tests/` (14)
`sketches/core-loop/src/core/meta_options.gd` | 470 | Head-start options, override codes and alt-loadout definitions stored inside `profile.camp()` | None (reads/writes `profile.camp()`) | `src/ui` (5), `src/core` (2), `src/game.gd` (1), `tests/` (5)
`sketches/core-loop/src/core/achievements.gd` | 466 | Achievement and mastery row tables, unlock queries and duplicated row validators | None (static const tables) | `src/ui` (9), `src/core` (3), `tools/` (1), `tests/` (46)
`sketches/core-loop/src/core/codex.gd` | 429 | Discovery state (`codex.json`), discovery event log (`log.ndjson`) and `runs.ndjson` tally-sync side effect | Owns `discovered`, `found`, `found_categories`, `log_error`, `last_error` | `src/game.gd` (1), `tests/` (12)
`sketches/core-loop/src/core/run_moments.gd` | 419 | In-run highlight detector, viewport screenshot capture and scrapbook page writer | Owns `_best`, `_capturing`, `_saved_path`, `storage_dir` | `src/game.gd` (1), `tests/` (2)

## Outward dependencies
All `preload()` / `load()` / dynamic path loads from this slice to other directories (zero external `class_name` or autoload references exist in this slice). Split between `src/core/` (bottom layer — every reference below is a **LOWER -> HIGHER violation**), `src/boot/boot.gd` (pre-game splash), and `src/game.gd` (composition root, allowed to wire every layer):

- `src/build` | 29 total (26 in `src/core/` **[LOWER -> HIGHER]**, 3 in `src/game.gd`) | `src/build/parts.gd` (9), `src/build/fabricators.gd` (6)
- `src/presentation` | 30 total (11 in `src/core/` **[LOWER -> HIGHER]**, 19 in `src/game.gd`) | `src/presentation/spillway_scenery.gd` (3), `src/presentation/material_slots.gd` (2), `src/presentation/windup_rows.gd` (2)
- `src/ui` | 23 total (4 in `src/core/` **[LOWER -> HIGHER]**, 1 in `src/boot/boot.gd` (`src/ui/wordmark.gd`), 18 in `src/game.gd`) | `src/ui/glyphs.gd` (2), `src/ui/start_pick_card.gd` (2)
- `src/world` | 19 total (18 in `src/core/` **[LOWER -> HIGHER]**, 1 in `src/game.gd`) | `src/world/trade_pockets.gd` (9), `src/world/pockets/pocket_draw.gd` (4)
- `src/combat` | 16 total (15 in `src/core/` **[LOWER -> HIGHER]**, incl. dynamic `ROSTER_DIG_PATH` in `beacon.gd:8`, 1 in `src/game.gd`) | `src/combat/roster.gd` (3), `src/combat/weapons.gd` (3)
- `src/movement` | 15 total (8 in `src/core/` **[LOWER -> HIGHER]**, 7 in `src/game.gd`) | `src/movement/speed_tier.gd` (4), `src/movement/tuning.gd` (3)
- `src/boss` | 2 total (2 in `src/core/` **[LOWER -> HIGHER]**, 0 in `src/game.gd`) | `src/boss/arena.gd` (1), `src/boss/codex_entries.gd` (1)
- `src/dev` | 1 total (0 in `src/core/`, 1 in `src/game.gd`) | `src/dev/dev_console.gd` (1)

(Note: `src/core/colour_meanings.gd` also embeds 50+ string path literals into `src/combat/`, `src/boss/`, `src/build/`, `src/presentation/`, and `src/ui/`; `src/core/stage_beats.gd`, `src/core/flow.gd:67`, and `src/core/worlds.gd:14-21` hold string script/owner paths without `preload()`/`load()`.)

## Findings

### CORE-01 Move four test-only audit modules out of `src/core/` to remove 15 upward preloads immediately
- kind: C
- evidence: Four modules live in `src/core/` with **0 callers in `src/`**:
  - `sketches/core-loop/src/core/content_registry.gd:8-28` (512 lines, 14 upward preloads into `presentation/`, `combat/`, `boss/`, `build/`, `ui/`); `git grep -n "content_registry.gd" -- sketches/core-loop/src` -> 0 hits (`tests/` -> 14 hits).
  - `sketches/core-loop/src/core/defence_bars.gd:3` (119 lines, preloads `src/build/elements.gd`); `git grep -n "defence_bars.gd" -- sketches/core-loop/src` -> 0 hits (`tests/` -> 14 hits, `tools/` -> 4).
  - `sketches/core-loop/src/core/colour_meanings.gd:29-99` (119 lines, hardcodes 50+ `res://src/...` paths across all higher layers); `git grep -n "colour_meanings.gd" -- sketches/core-loop/src` -> 0 hits (`tests/` -> 6 hits).
  - `sketches/core-loop/src/core/pending_content.gd:1-4` (4 lines, empty `const SIDE_CONTENT_PENDING: Array = []`); `git grep -n "pending_content.gd" -- sketches/core-loop/src` -> 0 hits (`tests/` -> 3 hits).
- fix: **Invert/relocate** all four audit/test-guard files out of `src/core/` into `sketches/core-loop/tests/support/` (or `tools/audit/`) and update the test preload paths. None is shipped runtime code; moving them removes 15 of `core/`'s 84 upward loads and ~754 lines from `src/core/` in one mechanical pass. (`content_registry.gd` also duplicates validation checks already run in `Achievements.validate()` and `Cosmetics.validate()` while omitting `WorkOrders`, `ShiftBoard`, `PilotStory`, and `MetaOptions`.)
- files to change: `sketches/core-loop/src/core/content_registry.gd`, `sketches/core-loop/src/core/defence_bars.gd`, `sketches/core-loop/src/core/colour_meanings.gd`, `sketches/core-loop/src/core/pending_content.gd`, plus ~26 test/script path references (`tests/*_test.gd`, `scripts/sketch-lint.mjs`, `sketches/core-loop/VISUAL-LANGUAGE.md`).
- size: ~30 lines changed (path updates), ~754 lines moved out of `src/core/`
- risk: low — zero runtime `src/` callers; pure path relocation under test-only files (DEEP-SWEEP: low risk)
- behaviour-preserving: yes — no runtime game code imports or executes any of the four files
- tests that cover it: `sketches/core-loop/tests/content_registry_reach_test.gd`, `sketches/core-loop/tests/audio_row_coverage_test.gd`, `sketches/core-loop/tests/colour_meanings_test.gd`, `sketches/core-loop/tests/colour_cvd_test.gd`, `sketches/core-loop/tests/defence_bars_test.gd`, `sketches/core-loop/tests/release_gate_placeholder_test.gd`, `sketches/core-loop/tests/activities_test.gd`, `sketches/core-loop/tests/side_content_roster_test.gd`
- guard: A `sketch:lint` rule forbidding `src/core/` files from preloading `src/{build,combat,boss,world,movement,presentation,ui}/` (with a shrinking baseline)

### CORE-02 Move four verified zero-dependency leaf scripts down into `src/core/`
- kind: C
- evidence: Four higher-layer files preloaded by `src/core/` have **zero non-core preloads** themselves (pure leaf tables/helpers):
  - `sketches/core-loop/src/movement/speed_tier.gd` (24L, 0 loads) — preloaded by `core/flow.gd:14`, `core/run_log.gd:5`, `core/ultimate_meter.gd:3`.
  - `sketches/core-loop/src/combat/pack_pressure.gd` (216L, 0 loads) — preloaded by `core/challenge_dials.gd:19`.
  - `sketches/core-loop/src/world/director_cards.gd` (81L, 0 loads) — preloaded by `core/run_tier.gd:3`.
  - `sketches/core-loop/src/ui/word_budget.gd` (83L, 0 loads) — preloaded by `core/pilot_story.gd:6` (and moving it down lets 5 core files drop duplicate `_words()` helpers — see CORE-16).
  - (Also verified leaf: `src/combat/boss_posture.gd` 207L, 0 loads — preloaded by `core/run_log.gd:7` and loaded by `core/event_kinds.gd:391`; moving its pure `CHUNKS` table or whole leaf down removes 2 more upward refs.)
- fix: **Move leaf files down** into `src/core/` (cheapest fix for all five: zero transitive dependencies to untangle). Update preload paths across callers (or leave a one-line redirect only if a downstream slice cannot be touched in the same PR, then delete it).
- files to change: `src/movement/speed_tier.gd`, `src/combat/pack_pressure.gd`, `src/world/director_cards.gd`, `src/ui/word_budget.gd`, `src/combat/boss_posture.gd` -> `src/core/`, plus preload path updates in callers (25+ files across `src/` and `tests/` for `speed_tier.gd` and `word_budget.gd`, <10 for the others).
- size: ~60 lines changed across preload sites; 0 logic lines changed
- risk: low — pure data/helper leaves with zero scene/node coupling (DEEP-SWEEP: low risk)
- behaviour-preserving: yes — identical constants and pure static functions; `test_batch_driver.gd:22` updates `PackPressure` path identically
- tests that cover it: `sketches/core-loop/tests/word_budget_test.gd`, `sketches/core-loop/tests/lore_rows_test.gd`, `sketches/core-loop/tests/hard_ladder_test.gd`, `sketches/core-loop/tests/run_log_posture_stages_test.gd`, `sketches/core-loop/tests/w50_story_arcs_test.gd`
- guard: `sketch:lint` upward-preload check on `src/core/`

### CORE-03 Split `core/palette.gd` into pure color constants (`core/`) and 3D material/sky factory (`presentation/`)
- kind: C
- evidence: `sketches/core-loop/src/core/palette.gd` (567 lines) puts 28 pure `Color` constants (lines 3-35) in the same file as 530 lines of procedural `ImageTexture`, `StandardMaterial3D`, `ShaderMaterial`, and `WorkerThreadPool` sky baking (lines 37-567), including two upward preloads: `core/palette.gd:168` (`preload("res://src/presentation/material_slots.gd")`) and `core/palette.gd:415` (`preload("res://src/presentation/time_sky.gdshader")`). Because 190+ files across `core/`, `build/`, `combat/`, `world/`, `ui/`, and `presentation/` preload `palette.gd` just for color constants, every bottom-layer file transitively pulls in `src/presentation/` — and `sketches/core-loop/src/boot/boot.gd:36-38` was forced to copy `CHARCOAL` and `AMBER` literals to stay free of `presentation/`.
- fix: **Split along the existing line-36 seam (invert/relocate the factory up)**: keep lines 1-35 (pure `Color` constants) in `src/core/palette.gd` with zero preloads and zero `static var`s; move lines 37-567 (procedural textures, `slot_material`, `sky_material`, `reset_for_tests`, and all 17 `static var` caches) to `src/presentation/palette_materials.gd`. Point `boot/boot.gd:36-38` at `core/palette.gd` so `CHARCOAL`/`AMBER` have one owner.
- files to change: `sketches/core-loop/src/core/palette.gd`, new `sketches/core-loop/src/presentation/palette_materials.gd`, `sketches/core-loop/src/boot/boot.gd`, `sketches/core-loop/tools/test_batch_driver.gd`, plus callers of `Palette.material`/`slot_material`/`sky_material`/`checker` (mostly under `src/presentation/` and `src/world/`).
- size: +535 / -535 lines (move), ~40-60 caller import updates
- risk: medium — high fan-out file (195 test refs, 150+ src refs), though color-only callers (~70% of files) need zero edits if `core/palette.gd` keeps the color constants (DEEP-SWEEP: medium risk)
- behaviour-preserving: yes — pure code relocation with identical cache keys, shader, and `WorkerThreadPool` lifecycle
- tests that cover it: `sketches/core-loop/tests/colour_meanings_test.gd`, `sketches/core-loop/tests/colour_cvd_test.gd`, `sketches/core-loop/tests/test_batch_reset_test.gd`, `sketches/core-loop/tests/borderlands_look_test.gd`
- guard: `sketch:lint` check that `src/core/palette.gd` has zero `preload`/`load` statements and zero `static var` caches

### CORE-04 Move `weigh()` and presentation juice/impact tables out of `core/event_kinds.gd`
- kind: C
- evidence: `sketches/core-loop/src/core/event_kinds.gd` (983 lines) mixes core event/signal metadata with presentation hit-stop, camera punch, and juice weight policy (`JUICE`, `IMPACT`, `REACTIONS`, `WEIGHT`, `WEIGHTED`, `WEIGHT_EXEMPT`, and `weigh()` at lines 366-412). Inside `weigh()`, it executes four runtime `load()`s up into higher layers on every call: `event_kinds.gd:377` (`src/presentation/windup_rows.gd`), `event_kinds.gd:391` (`src/combat/boss_posture.gd`), `event_kinds.gd:398` (`src/presentation/juice.gd`), and `event_kinds.gd:402` (`src/presentation/rows.gd`).
- fix: **Split upward (invert dependency)**: move `JUICE`, `IMPACT`, `REACTIONS`, `WEIGHT`, `WEIGHTED`, `WEIGHT_EXEMPT`, and `weigh()` into `src/presentation/event_juice.gd` (or `src/presentation/rows.gd`), where `WindupRows`, `Juice`, and `Rows` are peer `presentation/` scripts and can be `preload()`ed once instead of runtime-`load()`ed. Keep `core/event_kinds.gd` purely for signal/event/state/attack/display catalogs with zero upward loads.
- files to change: `sketches/core-loop/src/core/event_kinds.gd`, new `sketches/core-loop/src/presentation/event_juice.gd`, and callers of `EventKinds.weigh` / `JUICE` / `IMPACT` / `REACTIONS` / `WEIGHT` (primarily `src/presentation/juice.gd`, `src/presentation/audio.gd`, `src/presentation/vfx.gd`, and juice tests).
- size: +160 / -160 lines moved, ~15 caller updates
- risk: low — pure static tables and a stateless function with strong test coverage (DEEP-SWEEP: low risk)
- behaviour-preserving: yes — identical weighting math and return dictionary keys; avoids repeated `load()` calls in `weigh()`
- tests that cover it: `sketches/core-loop/tests/combat_juice_elevation_test.gd`, `sketches/core-loop/tests/audio_cue_resolution_test.gd`, `sketches/core-loop/tests/audio_row_coverage_test.gd`, `sketches/core-loop/tests/content_registry_reach_test.gd`
- guard: `sketch:lint` upward-preload/load ban in `src/core/`

### CORE-05 Remove combat cache-drain loop and 3D presentation dressing from `core/beacon.gd`
- kind: C
- evidence: `sketches/core-loop/src/core/beacon.gd` (293 lines) reaches into both `presentation/` and `combat/`: `beacon.gd:5` (`src/presentation/material_slots.gd`), `beacon.gd:6` (`src/presentation/recipe_props.gd`), `beacon.gd:7` (`src/combat/dispatcher.gd`), and `beacon.gd:8` (`const ROSTER_DIG_PATH := "res://src/combat/roster_dig.gd"`, lazy-loaded at line 139). Inside `place()` / `_process()` (`beacon.gd:119-144`), the stage beacon runs `begin_dig_drain()` / `drain_dig_burst()`, calling `Dispatcher.warm_shared()` and `RosterDig.tile_drain_step()` to warm combat enemy caches while rendering a 3D lantern GLB/recipe shell (`beacon.gd:160-265`) with 8 unreset `static var` mesh/material caches (`beacon.gd:19-26`, none called in `test_batch_driver.gd`).
- fix: **Invert both responsibilities**: (1) move `begin_dig_drain`/`drain_dig_burst` out of `Beacon` into `src/combat/combat.gd` (triggered on `stage_entered` when entering World 2) — removes both `combat/` references; (2) move the 3D lantern/mast visual builder into `src/presentation/` (listening to beacon state or attached by `presentation.gd` / `world.gd`), leaving `core/beacon.gd` as pure stage-beacon charge/unseal state and radius logic (or move the entire 3D `Node3D` beacon view to `src/world/beacon.gd`).
- files to change: `sketches/core-loop/src/core/beacon.gd`, `sketches/core-loop/src/combat/combat.gd`, `sketches/core-loop/src/world/world.gd` (or `src/presentation/presentation.gd`), `sketches/core-loop/src/game.gd`.
- size: ~180 lines moved, ~20 lines wiring
- risk: medium — touches stage-entry prewarm timing and 3D lantern clearance geometry (DEEP-SWEEP: medium risk)
- behaviour-preserving: yes — same `Dispatcher.warm_shared()` / `RosterDig.tile_drain_step()` budget per frame and identical lantern node transforms/radii
- tests that cover it: `sketches/core-loop/tests/lantern_beacon_clearance_test.gd`, `sketches/core-loop/tests/recipe_props_test.gd`
- guard: `sketch:lint` upward-preload ban in `src/core/` + L14 static reset check on `beacon.gd`'s caches

### CORE-06 Invert `core/run_state.gd`'s 23 upward preloads/loads into `build/`, `world/`, and `combat/`
- kind: C
- evidence: `sketches/core-loop/src/core/run_state.gd` has 23 upward `preload`/`load` sites across 8 higher-layer scripts:
  - `src/world/trade_pockets.gd` (8 inline `preload()`s: lines 47, 179, 831, 924, 1070, 1094, 1170, 1318) and `src/world/pockets/pocket_draw.gd` (4 inline `preload()`s: lines 895, 1028, 1166, 1317) — all for resetting/snapshotting/validating/serializing trade & pocket-draw state.
  - `src/build/fabricators.gd` (6 inline `preload()`s: lines 869, 943, 945, 1078, 1271, 1273) — all for serializing/restoring/validating scrap ingots.
  - `src/build/parts.gd` (3 inline `load()`s: lines 190, 957, 1306) — `Parts.bind_run(self)` and `Parts.def()` validation.
  - Top-level preloads: `src/build/relics.gd:5` (validation/copy), `src/combat/roster.gd:9` (`Roster.SPECIALS` in `record_special_broken`), `src/build/panels.gd:10` (`Panels.PANEL_MASS` / `Panels.has`), `src/build/consumables.gd:11` (consumable state serialize/validate).
- fix: **Invert the dependency** via a small subsystem persistence registry on `RunState` (`register_codec(key, {reset, snapshot, restore, to_doc, validate, from_doc})`) wired once in `game.gd` (and test helper) for `trade_pockets`, `pocket_draw`, `fabricators`, and `consumables`; invert `Parts.bind_run(self)` so `build.gd` binds on `run_started`/`from_entrance_doc`; **pass in** `specials_list` / `panel_mass` / `has_part` / `has_relic` validators (or move tiny pure ID/mass tables down). Removes all 23 upward loads from `run_state.gd` without changing the `entrance_doc` JSON format.
- files to change: `sketches/core-loop/src/core/run_state.gd`, `sketches/core-loop/src/game.gd`, `sketches/core-loop/src/build/build.gd`, `sketches/core-loop/src/world/activities.gd`
- size: +90 / -110 lines
- risk: high — touches run serialization, retry snapshot/restore, and Continue entrance docs (DEEP-SWEEP: high risk)
- behaviour-preserving: yes — identical `to_entrance_doc()`/`from_entrance_doc()` JSON keys, validation rules, and snapshot/restore order
- tests that cover it: `sketches/core-loop/tests/persistence_truncation_test.gd`, `sketches/core-loop/tests/logbook_test.gd`, `sketches/core-loop/tests/run_store_test.gd` (and 80+ tests loading `run_state.gd`)
- guard: `sketch:lint` upward-preload ban in `src/core/` + round-trip `to_entrance_doc`/`from_entrance_doc` parity test

### CORE-07 Invert `core/flow.gd`'s 7 upward preloads into `ui/`, `world/`, `boss/`, and `movement/`
- kind: C
- evidence: `sketches/core-loop/src/core/flow.gd` preloads/loads 7 higher-layer scripts:
  - `flow.gd:17` -> `src/ui/start_pick_card.gd`: `flow.gd:98-106` constructs a `CanvasLayer` and instantiates `StartPickCard` UI directly inside the core flow state machine.
  - `flow.gd:18` -> `src/world/victory_lap.gd` (creates/drives victory lap node).
  - `flow.gd:19` -> `src/boss/arena.gd` (`SlagBowl.warm_ahead` / `drop_ahead`).
  - `flow.gd:20` -> `src/world/event_director.gd` (`EventDirector.prewarm_stage_families` / `settle_prewarm`).
  - `flow.gd:844` -> inline `preload("res://src/world/park/park_map.gd")` solely to read `map.reach_m`.
  - `flow.gd:1286` -> inline `preload("res://src/movement/tuning.gd")` solely to read `Tuning.RADIUS` even though `ctx.tuning` is already on `ctx`.
  - `flow.gd:14` -> `src/movement/speed_tier.gd` (handled by CORE-02: move leaf down).
- fix: Per-ref cheapest fix:
  - `speed_tier.gd`: **move leaf down** (CORE-02).
  - `tuning.gd:1286`: **pass/read from `ctx.tuning`** (1-line change; `ctx.tuning` is already injected).
  - `park_map.gd:844`: **pass value in** via a `beacon_reach(stage)` method on `ctx.terrain` (already owned by `world/`).
  - `start_pick_card.gd:17`: **invert** — let `src/ui/screens.gd` (or `hud.gd`) own the `StartPickCard` `CanvasLayer` and open/close it on a `flow` signal or `ctx.start_pick_ui` hook wired in `game.gd`.
  - `victory_lap.gd:18`, `boss/arena.gd:19`, `world/event_director.gd:20`: **invert** via `prewarm_stage` / `start_victory_lap` callbacks registered on `Flow` by `game.gd` (or `world.gd` listening to `stage_entered` / `boss_defeated`).
- files to change: `sketches/core-loop/src/core/flow.gd`, `sketches/core-loop/src/game.gd`, `sketches/core-loop/src/ui/screens.gd`, `sketches/core-loop/src/world/terrain.gd`
- size: +65 / -55 lines
- risk: high — `flow.gd` is the run-lifecycle state machine checked by TLA+ formal models (`scrapkeep-verify-formal`) and retry/continue tests (DEEP-SWEEP: high risk)
- behaviour-preserving: yes — preserves exact `flow_changed` / `stage_entered` signal order and launch-take state transitions
- tests that cover it: `sketches/core-loop/tests/start_pick_test.gd`, `sketches/core-loop/tests/ending_sequence_test.gd`, `sketches/core-loop/tests/hard_ladder_test.gd`, `sketches/core-loop/tests/loop_bot_test.gd`
- guard: `sketch:lint` upward-preload ban in `src/core/`

### CORE-08 Clear the remaining 13 `src/core/` upward preload files via pass-in, validation inversion, or untyping
- kind: C
- evidence: After CORE-01..07, exactly 13 remaining `src/core/` files hold 19 upward preloads:
  1. `core/context.gd:7,8,9` -> `movement/{tuning,player_ball,chase_camera}.gd` (type hints only; `world`, `combat`, `build`, `hud`, `audio`, `presentation` on `Context` are already untyped `Node`/`RefCounted`).
  2. `core/ability_state.gd:5` -> `ui/glyphs.gd` (only in `slot_key()` lines 727-733).
  3. `core/codex.gd:6` -> `build/parts.gd` (only lines 293-294 checking `Parts.def(part_id).rarity == "relic"`).
  4. `core/companion.gd:557` -> `load("res://src/build/consumables.gd")` (only `roll_id(roll_rng)` in `on_yard_cleared`).
  5. `core/death_cause.gd:6` -> `combat/rogue.gd` (only lines 87-88 reading `Rogue.ROWS[source]["name"]`).
  6. `core/devices.gd:3` -> `combat/weapons.gd` (only line 6 reading `Weapons.STICKY_MAX_LIVE`).
  7. `core/run_log.gd:6` -> `world/event_director.gd` (only `EventDirector.PARTICIPATORY` event-id list).
  8. `core/run_moments.gd:8,9` -> `combat/roster.gd`, `build/parts.gd` (`warden_name`, `display_name`).
  9. `core/shift_board.gd:5,356` -> `build/items.gd` (validation only), `load("res://src/build/parts.gd")` (`item_name`).
  10. `core/shift_variants.gd:5` -> `build/panels.gd` (`Panels.draw` in `claim_overtime_panel`).
  11. `core/start_picks.gd:3` -> `build/parts.gd` (`display_name`, `icon_of`, `row`).
  12. `core/upgrade_tree.gd:12,13,14` -> `movement/augments.gd`, `combat/weapons.gd`, `combat/sticky.gd` (`KNOBS` defaults and test-only `problems()` validator).
  13. `core/work_orders.gd:6,7` -> `build/items.gd`, `build/maker_sets.gd` (used **only** inside test-only `validate()`).
- fix: Cheapest fix per file:
  - **Untype / base-type**: `context.gd` (drop the 3 `movement/` script preloads; type fields as `RefCounted`/`Node3D`).
  - **Invert to UI / test validator**: `ability_state.gd` (return raw verb/key, let `ui/` call `Glyphs.of()`); `work_orders.gd` & `shift_board.gd:5` & `upgrade_tree.gd` (move cross-module table checks in `validate()`/`problems()` into the test-only content audit suite from CORE-01, and copy/move the scalar default constants like `STICKY_MAX_LIVE` into a leaf or pass them in).
  - **Move tiny constant down**: `EventDirector.PARTICIPATORY` event-id list -> `event_kinds.gd` (clears `run_log.gd:6`); `Weapons.STICKY_MAX_LIVE` -> `devices.gd` and read from `Devices` in `weapons.gd` (clears `devices.gd:3`); rogue display names -> `death_cause.gd` `WORDS` or passed in (clears `death_cause.gd:6`).
  - **Pass value/callable in** (from `game.gd`, `build.gd`, or UI caller): `codex.gd` (`is_relic` callable or emit rarity), `companion.gd` (`roll_consumable` callable), `run_moments.gd` (`warden_name`/`part_name` callables), `shift_board.gd:356` (`item_name` callable), `shift_variants.gd` (`draw_panel` callable), `start_picks.gd` (`part_lookup` callable).
- files to change: The 13 `src/core/*.gd` files above, `src/game.gd`, `src/ui/ability_slots.gd`, `src/combat/weapons.gd`, `src/world/event_director.gd`, and the content audit tests.
- size: ~140 lines across 17 files (can be landed as 3-4 tiny independent PRs)
- risk: low to medium — each file is isolated with focused unit tests; `context.gd` and `work_orders.gd`/`shift_board.gd` are low risk (DEEP-SWEEP: low-medium)
- behaviour-preserving: yes — no runtime logic or data changes, only dependency direction
- tests that cover it: `sketches/core-loop/tests/ability_swap_pressure_test.gd`, `sketches/core-loop/tests/lore_unlock_test.gd`, `sketches/core-loop/tests/run_moments_test.gd`, `sketches/core-loop/tests/shift_board_test.gd`, `sketches/core-loop/tests/start_pick_test.gd`, `sketches/core-loop/tests/w50_player_systems_test.gd`
- guard: `sketch:lint` rule banning `preload`/`load` of `res://src/(build|combat|boss|world|movement|presentation|ui)/` inside `src/core/` (reaches zero baseline after CORE-01..08)

### CORE-09 Declare `consumable_used` as a real signal in `game_events.gd` and close the 3-signal gap in `event_kinds.gd`
- kind: G
- evidence: `sketches/core-loop/src/core/game_events.gd:151-159` registers `consumable_used` via `add_user_signal()` inside `_init()` instead of the `signal` keyword used by the other 132 signals (lines 4-149). Because `GameEvents.signal_names()` (`game_events.gd:162-167`) reads `script.get_script_signal_list()`, it returns 132 names and **omits `consumable_used`** — hiding it from `Achievements.bus_signals()`, `EventKinds.ROWS`, and `ContentRegistry`. Independently, two declared and emitted signals — `harpoon_bit` (`game_events.gd:46`, 34 `src/` hits) and `harpoon_smashed` (`game_events.gd:47`, 22 `src/` hits) — are missing from `EventKinds.ROWS` (`130` entries vs `133` total signals). Verified by `git grep` + script comparison of `game_events.gd` vs `event_kinds.gd`.
- fix: Replace `var consumable_used: Signal` + `_init()` `add_user_signal` at `game_events.gd:151-159` with `signal consumable_used(consumable_id: String, at: Vector3)`. Add `consumable_used`, `harpoon_bit`, and `harpoon_smashed` rows to `EventKinds.ROWS` (matching existing silent/internal signal schema so no unwanted HUD/audio cues fire).
- files to change: `sketches/core-loop/src/core/game_events.gd`, `sketches/core-loop/src/core/event_kinds.gd`
- size: +6 / -10 lines
- risk: low — `consumable_used` already has the exact `(consumable_id: String, at: Vector3)` signature; check whether any test asserts exact `EventKinds.ROWS.size()` (DEEP-SWEEP: low risk)
- behaviour-preserving: yes — `consumable_used.emit(...)` and `.connect(...)` behave identically; adding quiet metadata rows changes no runtime feedback
- tests that cover it: `sketches/core-loop/tests/content_registry_reach_test.gd`, `sketches/core-loop/tests/audio_row_coverage_test.gd`, `sketches/core-loop/tests/audio_cue_resolution_test.gd`
- guard: Add a check in `content_registry_reach_test.gd` asserting `Set(GameEvents.signal_names()) == Set(EventKinds.ROWS.keys())` and zero `add_user_signal` calls in `game_events.gd`

### CORE-10 Strip `Profile` tally mutation and raw file I/O from `Codex.append_line()`
- kind: C
- evidence: `sketches/core-loop/src/core/run_log.gd:526` writes `runs.ndjson` by calling `codex.append_line(...)`. Inside `sketches/core-loop/src/core/codex.gd:369-384`, `append_line()` inspects `path.get_file() == "runs.ndjson"`, re-parses the JSON string `run_log.gd` just serialized, injects `run.tallies()`, mutates `profile` (`record_run_tallies`, `settle_run_tallies`), and calls `profile.save()`. Additionally, `codex.gd:385-397` duplicates `SafeStore.append_line()` (`safe_store.gd:25-39`) using raw `FileAccess.open(..., FileAccess.READ_WRITE / WRITE)` (`git grep -n "append_line(" -- sketches/core-loop/src` -> 5 hits: `codex.gd:366,369`, `run_log.gd:526`, `safe_store.gd:25`, `sitting_notes.gd:147`). Meanwhile `codex.gd:256` also calls `run.reconcile_tallies(profile.run_tallies(run.run_id))` on `stage_entered`.
- fix: Move the `tallies` attachment and `profile.record_run_tallies` / `settle_run_tallies` / `profile.save()` step to `run_log.gd` (or a dedicated tally-sync hook in `flow.gd` / `progress.gd` where run lifecycle already lives), and replace `codex.gd:385-397`'s raw file append with `SafeStore.append_line(path, text)`. Keep `Codex` owning only discovery state (`codex.json`) and its own `log.ndjson`.
- files to change: `sketches/core-loop/src/core/codex.gd`, `sketches/core-loop/src/core/run_log.gd`, `sketches/core-loop/src/core/flow.gd`, `sketches/core-loop/tests/build_clock_test.gd`
- size: +25 / -30 lines
- risk: medium — touches run-tally crash-recovery accounting checked by `logbook_test.gd` and `build_clock_test.gd` (DEEP-SWEEP: medium risk)
- behaviour-preserving: yes — same JSON lines written to `runs.ndjson` and identical `profile.json` tally updates/settlement timing
- tests that cover it: `sketches/core-loop/tests/logbook_test.gd`, `sketches/core-loop/tests/build_clock_test.gd`, `sketches/core-loop/tests/run_log_posture_stages_test.gd`, `sketches/core-loop/tests/persistence_truncation_test.gd`
- guard: `sketch:lint` L2 (currently exempts `codex.gd` or misses `READ_WRITE` append — extend L2 to require `SafeStore.append_line` for `.ndjson` appends)

### CORE-11 Enforce `RunState` single-writer ownership by replacing 25+ external field writes with mutators
- kind: F
- evidence: `sketches/core-loop/CONTRACTS.md:33` states only `RunState` mutates run fields, yet `git grep` across `sketches/core-loop/src/` finds 11 files across 6 modules writing `RunState` fields directly:
  - `hp` & `since_damage`: `src/build/consumables.gd:405-406`, `src/combat/combat.gd:6949-6950`, `src/world/stake_devices.gd:194-195`, `src/world/trade_pockets.gd:380-381`, `src/game.gd:563`.
  - `bonus_cores -=`: `src/build/consumables.gd:399`, `src/world/stake_devices.gd:202` (`RunState` has `lose_core()` for 1 core and `burn_cores()`, no `spend_cores(n)`).
  - `companion`: written directly by 6 files across 5 layers (`src/build/build.gd:1317`, `src/core/flow.gd:583,598`, `src/presentation/companion_body.gd:114`, `src/ui/companion_panel.gd:145`, `src/ui/workshop.gd:409`, `src/world/activities.gd:2388`).
  - `stage` temporarily clobbered and restored in `src/world/activities.gd:716,726`!
  - `trade_memory` & `pocket_draw_cache`: `src/world/activities.gd:680-687`; `pick_opened` & `class_rewarded`: `src/world/world.gd:941,952,980`; `brew` & `brew_stage`: `src/build/shop.gd:762-763`; `death_save_spent`: `src/core/flow.gd:499`; `miniboss_at`: `src/world/event_director.gd:193`.
- fix: Add narrow, self-checking mutators on `RunState` (`spend_hp(amount, floor_hp)`, `refill_hp()`, `spend_cores(count)`, `set_companion(doc)`, `add_companion_piece(id)`, `record_brew()`, `mark_pick_opened(stage)`, `spend_death_save()`), pass `stage` as a parameter in `activities.gd:716` instead of mutating `ctx.run.stage`, and route all 11 callers through the mutators.
- files to change: `sketches/core-loop/src/core/run_state.gd`, `src/build/consumables.gd`, `src/build/build.gd`, `src/build/shop.gd`, `src/combat/combat.gd`, `src/core/flow.gd`, `src/game.gd`, `src/presentation/companion_body.gd`, `src/ui/companion_panel.gd`, `src/ui/workshop.gd`, `src/world/activities.gd`, `src/world/stake_devices.gd`, `src/world/trade_pockets.gd`, `src/world/world.gd`
- size: +65 / -40 lines
- risk: medium — touches hull/core spending and companion state across several modules, though each replacement is 1-for-1 (DEEP-SWEEP: medium risk)
- behaviour-preserving: yes — identical clamping (`maxf(floor_hp, ...)`), `since_damage = 0.0` reset, and companion dict values
- tests that cover it: `sketches/core-loop/tests/activities_test.gd`, `sketches/core-loop/tests/w50_player_systems_test.gd`, `sketches/core-loop/tests/companion_test.gd` (plus all combat/trade tests)
- guard: Extend `sketch:lint` L10 (currently guards specific fields) to flag direct assignments to `run.(hp|since_damage|bonus_cores|companion|stage|death_save_spent|brew|pick_opened)` outside `run_state.gd`

### CORE-12 Remove `game.gd`'s private `profile._refuse()` reach-in and centralize `profile.save()` policy
- kind: C
- evidence: (1) `sketches/core-loop/src/game.gd:542` calls private `ctx.profile._refuse("sitting profile: this session does not save")` (`git grep -n "_refuse(" -- sketches/core-loop/src` -> 14 hits, 13 inside `profile.gd` and 1 reach-in in `game.gd:542`). (2) `profile.save()` is called directly across 12 distinct files in 4 layers: `core/codex.gd:383`, `core/flow.gd:414,607,612`, `core/progress.gd:80,195,215,238,276,384,455,564`, `game.gd:504`, `presentation/flourish_player.gd:312`, `presentation/radio_deck.gd:268`, `presentation/title_stage.gd:226`, `ui/class_card.gd:442,510`, `ui/customize_page.gd:543,564,828`, `ui/meta_page.gd:80`, `ui/work_orders_page.gd:214,227`, and `world/camp_records.gd:25,45`. Half check `if profile.can_save and not profile.save():`; UI callers call `_profile.save()` unconditionally and ignore the return value.
- fix: (1) Add a public `disable_saving(reason: String)` method on `Profile` and call it from `game.gd:542`. (2) Add a `save_if_allowed() -> bool` (or make `save()` itself no-op cleanly when `not can_save` vs reporting only genuine I/O failures) so callers cannot diverge on `can_save` handling and `presentation/`/`ui/` do not repeat boilerplate guards.
- files to change: `sketches/core-loop/src/core/profile.gd`, `sketches/core-loop/src/game.gd`, plus optional cleanup of the 11 `profile.save()` callers.
- size: +15 / -15 lines (core fix)
- risk: low — `disable_saving()` is a direct public wrapper for `_refuse()`; `save_if_allowed()` keeps existing `profile.save()` semantics intact for tests asserting `save() == false` on refused profiles (DEEP-SWEEP: low risk)
- behaviour-preserving: yes — preserves `can_save == false` and `last_error` behavior for sitting profiles and read-only profile tests
- tests that cover it: `sketches/core-loop/tests/profile_store_test.gd`, `sketches/core-loop/tests/persistence_truncation_test.gd`, `sketches/core-loop/tests/sitting_kit_test.gd`
- guard: `scripts/deep-sweep.mjs` D2 reach-in check (promote `._` calls outside own class to `sketch:lint`)

### CORE-13 Delete dead compatibility paths (`camp_get`/`camp_set`, `ScrapbookStore` fallback, `BRINDLE_COBALT_PICK`)
- kind: B
- evidence: Three dead compatibility / fallback paths verified in `src/core/`:
  1. `core/meta_options.gd:214-216,224-226` and `core/work_orders.gd:785-787,796-798` branch on `profile.has_method("camp_get")` and `profile.has_method("camp_set")`. `git grep -n "func camp_get\|func camp_set" -- sketches/core-loop` -> 0 hits; `Profile` only exposes `camp()` and `set_camp()`. Furthermore, `_camp_get`/`_camp_set` (`meta_options.gd:211-229`) and `_camp_box`/`_save_camp_box` (`work_orders.gd:782-801`) duplicate the same `profile.camp()` read-modify-write pattern.
  2. `core/run_moments.gd:284-307` guards `ResourceLoader.exists(STORE_PATH)` (`res://src/core/scrapbook_store.gd`, a tracked core file always present) and maintains a 17-line copy of `ScrapbookStore.save()` (lines 291-307) as an unreachable fallback.
  3. `core/worlds.gd:5` `const BRINDLE_COBALT_PICK := true` has only one reader (`src/boss/boss.gd:1480`: `if not Worlds.BRINDLE_COBALT_PICK ...: return`), an always-false early-return branch (`git grep -n "BRINDLE_COBALT_PICK" -- sketches/core-loop scripts` -> 2 hits, 0 tests).
- fix: Add `camp_get(key, fallback)` / `camp_set(key, value)` directly on `Profile` (or delete the dead `has_method` branches and share one helper on `Profile`); replace `run_moments.gd:284-307` with a direct `preload("res://src/core/scrapbook_store.gd")` call; remove `Worlds.BRINDLE_COBALT_PICK` and its dead branch in `boss.gd:1480`.
- files to change: `sketches/core-loop/src/core/profile.gd`, `sketches/core-loop/src/core/meta_options.gd`, `sketches/core-loop/src/core/work_orders.gd`, `sketches/core-loop/src/core/run_moments.gd`, `sketches/core-loop/src/core/worlds.gd`, `sketches/core-loop/src/boss/boss.gd`
- size: +15 / -55 lines
- risk: low — every removed branch is provably unreachable at runtime (DEEP-SWEEP: low risk)
- behaviour-preserving: yes — runtime takes the exact same path before and after
- tests that cover it: `sketches/core-loop/tests/meta_options_test.gd`, `sketches/core-loop/tests/w50_player_systems_test.gd`, `sketches/core-loop/tests/run_moments_test.gd`, `sketches/core-loop/tests/summary_rows_test.gd`
- guard: None needed beyond existing tests

### CORE-14 Collapse `core/stage_defs.gd` forwarding facade and deduplicate stage-table query helpers
- kind: D
- evidence: `sketches/core-loop/src/core/stage_defs.gd` (77 lines) forwards 15 of its 16 symbols verbatim to `AlphaDefs` (`STAGES`, `COUNT`, `of`, `is_last`, `world_of`..`has_vault`), adding only `const RUN_TIER_DIAL_STEPS := {"damage": 0.1, "aggression": 0.1}` at line 10 (`git grep -n "RUN_TIER_DIAL_STEPS" -- sketches/core-loop` -> 4 hits: `stage_defs.gd:10`, `world/director.gd:99`, `tests/run_tier_dials_test.gd:33,38`). Across `alpha_defs.gd:165-226`, `park_defs.gd:125-186`, `slice_defs.gd:46-100`, and `stage_defs.gd:14-77`, the same 14 static query methods (`of`, `is_last`, `world_of`, `boss_of`, `zone_of`, `stage_name`, `index_in_world`, `is_world_end`, `world_stages`, `stages_for_world`, `next_stage`, `has_shop`, `has_vault`, `warden_lesson`) are copy-pasted four times (~230 duplicate lines), and `park_defs.gd` also copy-pastes 7 pack/elite tables (`PACKS`, `PACKS_DAM`, `PACKS_FLUME`, `ELITE`, `ELITE_SPILLWAY`, `DIG_ELITE`, `ELITE_HIGHDRAFT`) from `alpha_defs.gd`.
- fix: Move `RUN_TIER_DIAL_STEPS` onto `RunTier` (or `AlphaDefs`) and either extract a single parameterized `StageTable` helper used by `AlphaDefs`/`ParkDefs`/`SliceDefs` or delete `stage_defs.gd` after pointing its 7 `src/` callers at `AlphaDefs` (applying the deletion test: zero complexity moves to callers; 200+ duplicate lines vanish). Share the 7 pack/elite constants between `alpha_defs.gd` and `park_defs.gd` instead of copying them.
- files to change: `sketches/core-loop/src/core/stage_defs.gd`, `sketches/core-loop/src/core/alpha_defs.gd`, `sketches/core-loop/src/core/park_defs.gd`, `sketches/core-loop/src/core/slice_defs.gd`, plus 7 `src/` callers and `tests/run_tier_dials_test.gd` (if `stage_defs.gd` is removed, ~48 test imports update; keeping the helper extraction alone touches only the 4 core files).
- size: +45 / -230 lines
- risk: low (helper extraction) to medium (retiring `stage_defs.gd` across 48 tests) — pure data lookups (DEEP-SWEEP: low-medium)
- behaviour-preserving: yes — identical stage rows, indices, and return values
- tests that cover it: `sketches/core-loop/tests/alpha_table_test.gd`, `sketches/core-loop/tests/run_tier_dials_test.gd`, `sketches/core-loop/tests/audio_worlds_test.gd`, `sketches/core-loop/tests/combat_worlds_test.gd`
- guard: `scripts/deep-sweep.mjs` D1 pass-through wrapper scan

### CORE-15 Deduplicate `validate()` pairs in `achievements.gd` and `shift_board.gd` plus 5 `_words()` copies in `core/`
- kind: A
- evidence:
  - `sketches/core-loop/src/core/achievements.gd`: `validate()` (lines 291-365) and `validate_mastery()` (lines 402-466) duplicate the same ~65-line row-schema validator (title/text/beat word caps, duplicate IDs, grant/reward checks).
  - `sketches/core-loop/src/core/shift_board.gd`: `validate()` (lines 365-445) and `validate_world_rungs()` (lines 448-522) duplicate the same ~75-line rung/seed validator.
  - Five separate core files define identical word-counting helpers: `achievements.gd:287` `_words(s)`, `meta_options.gd:147` `_words(s)`, `shift_board.gd:361` `_words(s)`, `work_orders.gd:804` `_words(s)`, `prologue_rows.gd:33` `words(s)` (plus `content_registry.gd:482` `_words(...)` and `ui/word_budget.gd:13` `words_in()`).
- fix: Extract a private `_validate_rows(rows, opts)` inside `achievements.gd` and `_validate_rung_set(rungs, seeds, opts)` inside `shift_board.gd`. Once `word_budget.gd` moves down to `src/core/` (CORE-02), replace all 5 `_words()` copies with `WordBudget.words_in()` (note: verify whitespace-splitting parity on tabs/newlines, since `s.split(" ", false)` vs `WordBudget.words_in()` may differ only on multi-whitespace).
- files to change: `sketches/core-loop/src/core/achievements.gd`, `sketches/core-loop/src/core/shift_board.gd`, `sketches/core-loop/src/core/meta_options.gd`, `sketches/core-loop/src/core/work_orders.gd`, `sketches/core-loop/src/core/prologue_rows.gd`
- size: +40 / -145 lines
- risk: low — pure static validation helpers used only by tests (DEEP-SWEEP: low risk)
- behaviour-preserving: yes — identical validation diagnostics returned for every valid and invalid row
- tests that cover it: `sketches/core-loop/tests/achievement_fill_test.gd`, `sketches/core-loop/tests/shift_board_test.gd`, `sketches/core-loop/tests/meta_options_test.gd`, `sketches/core-loop/tests/w50_player_systems_test.gd`, `sketches/core-loop/tests/screens_prologue_test.gd`
- guard: `sketch:lint` / code review against local `_words(` helpers

### CORE-16 Fix raw `FileAccess.WRITE` in `game.gd:dump_tuning()` and duplicate `SettingsStore.new()` allocations
- kind: G
- evidence:
  - `sketches/core-loop/src/game.gd:737` writes `tuning_dump.json` with raw `FileAccess.open(path, FileAccess.WRITE)` instead of `SafeStore.write_atomic(path, ...)`.
  - `sketches/core-loop/src/game.gd:1039-1042` provides a cached `settings_store()` accessor (`_settings_store`), yet two nearby functions in the same file ignore it and allocate fresh `SettingsStore.new(storage_dir)` instances (`game.gd:1000` in `_save_input_settings` and `game.gd:1047` in `apply_saved_display_settings`; `git grep -n "SettingsStore.new" -- sketches/core-loop/src/game.gd` -> 3 hits).
- fix: Replace `game.gd:737-741` with `SafeStore.write_atomic(path, JSON.stringify(doc, "\t"))` and replace `SettingsStore.new(storage_dir)` at `game.gd:1000` and `game.gd:1047` with `settings_store()`.
- files to change: `sketches/core-loop/src/game.gd`
- size: +5 / -11 lines
- risk: low — localized 1-file cleanup with no gameplay or save-format change (DEEP-SWEEP: low risk)
- behaviour-preserving: yes — atomic write produces identical JSON at the same path; `settings_store()` points to the same `storage_dir`
- tests that cover it: `sketches/core-loop/tests/dev_console_test.gd`, `sketches/core-loop/tests/settings_store_test.gd`
- guard: `sketch:lint` L2 (currently exempts `game.gd` or misses `dump_tuning` — tighten L2 so `game.gd` has zero raw `FileAccess.WRITE` calls)

### CORE-17 Unify CLI flag parsing across `game.gd`, `boot.gd`, `frame_log.gd`, `sitting_notes.gd`, and `challenge_dials.gd`
- kind: G
- evidence: Five files in this slice independently scan `OS.get_cmdline_user_args()` / `OS.get_cmdline_args()` with subtly different rules: `game.gd:1301` (`_launch_flag()` checks user args only, exact/prefix), `boot/boot.gd:99` (`_flag()` checks both `get_cmdline_args()` and `get_cmdline_user_args()`), `core/frame_log.gd:22-34` (user args only), `core/sitting_notes.gd:33-42` (user args only), and `core/challenge_dials.gd:156-175` (user args with `--key=value` parsing and warning cache).
- fix: Add a tiny pure helper `src/core/cli_flags.gd` (has_flag, value_of, kv_pairs) supporting both exact `--flag` and `--flag=value` with explicit `include_engine_args` option, and route the 5 callers through it.
- files to change: new `sketches/core-loop/src/core/cli_flags.gd`, `sketches/core-loop/src/game.gd`, `sketches/core-loop/src/boot/boot.gd`, `sketches/core-loop/src/core/frame_log.gd`, `sketches/core-loop/src/core/sitting_notes.gd`, `sketches/core-loop/src/core/challenge_dials.gd`
- size: +45 / -50 lines
- risk: low — pure string parsing over `OS.get_cmdline_*` args (DEEP-SWEEP: low risk)
- behaviour-preserving: yes — keep `boot.gd`'s both-args lookup (`include_engine_args = true`) and user-args-only for the other four so no launch wrapper changes behavior
- tests that cover it: `sketches/core-loop/tests/challenge_dials_test.gd`, `sketches/core-loop/tests/sitting_kit_test.gd`, `sketches/core-loop/tests/frame_log_test.gd`
- guard: None needed beyond unit test for `cli_flags.gd`

### CORE-18 Consolidate `signal_lifetime.gd` into `SignalWire` and replace `run.set_meta` with one extension mechanism
- kind: G
- evidence:
  - Two overlapping signal-wiring helpers live side by side in `src/core/`: `src/core/signal_wire.gd` (`class_name SignalWire`, 14 lines, **65 hits** across `src/presentation/` and `src/ui/`) and `src/core/signal_lifetime.gd` (9 lines, **2 `src/` callers**: `src/combat/warden_swarm.gd:5`, `src/presentation/hero_assets.gd:6`, 1 test `tests/signal_lifetime_test.gd`), plus a third private `_connect_if` in `core/buff_ledger.gd:237`.
  - `RunState` carries two parallel untyped extension bags: `run.extra` (persisted in `to_entrance_doc`, written directly by `flow.gd`, `game.gd`, `progress.gd`, `work_orders.gd`, `shift_variants.gd`) and `Object.set_meta(...)` (non-persisted, written by `run_log.gd`, `companion.gd`, `loop_tally.gd`, `build.gd`, `fabricators.gd`), forcing `run_state.gd:201` to hardcode erasing 4 `w50_*` meta keys (`w50_scrap_ingots`, `w50_consumable_state`, `w50_trade_contracts`, `w50_companion_salvage`) inside `begin()`.
- fix: (1) Add `SignalWire.listen_owned(owner, emitter, signal_name, callback)` (the one extra capability of `signal_lifetime.gd` — disconnecting on `tree_exited`), migrate the 2 `src/` callers and test, and delete `signal_lifetime.gd`. (2) Add a dedicated `ephemeral: Dictionary` (cleared automatically in `RunState.begin()`) or `register_ephemeral(key)` helper so `run_state.gd:201` stops hardcoding higher-module `w50_*` meta keys (leaving `run.extra` untouched to preserve save format).
- files to change: `sketches/core-loop/src/core/signal_wire.gd`, `sketches/core-loop/src/core/signal_lifetime.gd`, `sketches/core-loop/src/combat/warden_swarm.gd`, `sketches/core-loop/src/presentation/hero_assets.gd`, `sketches/core-loop/src/core/run_state.gd`, plus callers of the 4 `w50_*` meta keys (`src/build/fabricators.gd`, `src/build/consumables.gd`, `src/world/trade_pockets.gd`, `src/core/companion.gd`).
- size: +35 / -40 lines
- risk: low — `signal_lifetime.gd` has only 2 callers; replacing `set_meta` keys with `run.ephemeral` is mechanical and does not touch `to_entrance_doc()` (DEEP-SWEEP: low risk)
- behaviour-preserving: yes — identical signal disconnect-on-exit timing and identical per-run reset clearing
- tests that cover it: `sketches/core-loop/tests/signal_lifetime_test.gd`, `sketches/core-loop/tests/w50_player_systems_test.gd`
- guard: `sketch:lint` check forbidding `run.set_meta(` in `src/`

### CORE-19 Split input/gamepad routing and display-settings fan-out out of `src/game.gd` (1,375 lines)
- kind: H
- evidence: `sketches/core-loop/src/game.gd` mixes four responsibilities in one 1,375-line root node, with two clean seams whose private state is unused by the rest of `game.gd`:
  - **Input & gamepad routing** (`game.gd:933-1043, 1159-1371`, ~320 lines): `_unhandled_input`, gamepad hotplug/axis latches, consumable chord routing, quick-restart / screenshot / dev hotkeys, and binding persistence.
  - **Display & accessibility settings fan-out** (`game.gd:1045-1157`, ~115 lines): `apply_saved_display_settings()`, `set_reduced_motion()`, `set_motion_statics()` (which reaches into 15 static vars across `ui/` and `presentation/`), `set_graphics_preset()`, `set_window_mode()`, `set_fps_cap()`.
- fix: Extract `src/core/game_display_settings.gd` (or `src/presentation/display_settings.gd` so `core/` doesn't gain the 15 `ui/`/`presentation/` static references!) for lines 1045-1157, and `src/game_input.gd` for lines 933-1043 & 1159-1371, leaving `src/game.gd` (~900 lines) focused on composition root and module wiring. Keep `Game.set_motion_statics(on)` as a one-line delegate if `test_batch_driver.gd:180` and `test_batch_reset_test.gd:108` call it on `Game` (or update both call sites directly).
- files to change: `sketches/core-loop/src/game.gd`, new `sketches/core-loop/src/game_input.gd`, new `sketches/core-loop/src/presentation/display_settings.gd`, `sketches/core-loop/tools/test_batch_driver.gd`, `sketches/core-loop/tests/test_batch_reset_test.gd`
- size: +435 / -425 lines (move)
- risk: medium — touches input dispatch and `test_batch_driver.gd`'s motion-static reset (DEEP-SWEEP: medium risk)
- behaviour-preserving: yes — identical `_unhandled_input` ordering and identical static flag toggles
- tests that cover it: `sketches/core-loop/tests/test_batch_reset_test.gd`, `sketches/core-loop/tests/bindings_table_test.gd`, `sketches/core-loop/tests/settings_store_test.gd`
- guard: Keep `src/game.gd` under 1,000 lines (repo 1k-line maintainability guideline)

### CORE-20 Split data tables & codecs along existing seams in `pilot_story.gd` (1,834L) and `run_state.gd` (1,327L)
- kind: H
- evidence:
  - `sketches/core-loop/src/core/pilot_story.gd` (1,834 lines) packs ~1,150 lines of static narrative tables (`CHAPTERS`, `CAMP_BEATS`, `RUN_CALLS`, `LOSS_REACTIONS`, etc.), ~450 lines of runtime selectors & habit classification (`punch_mask`, `pick_camp_beat`, `pick_run_call`, `classify_habits`), and ~230 lines of test-only validation (`validate_tables`, lines 1600-1834) into one `class_name PilotStory` script.
  - `sketches/core-loop/src/core/run_state.gd` (1,327 lines) packs live run state & combat hooks (lines 1-820) together with ~500 lines of stage snapshot/restore (`snapshot_stage`, `restore_stage`) and entrance-doc serialization/validation (`ENTRANCE_KEYS`, `to_entrance_doc`, `validate_entrance_doc`, `from_entrance_doc`, lines 825-1327).
- fix: (1) Split `pilot_story.gd` into `pilot_story_rows.gd` (pure const tables), `pilot_story.gd` (runtime selectors re-exporting table constants if tests read `PilotStory.*`), and move `validate_tables()` to `tests/support/` (which also eliminates `pilot_story.gd:6`'s `WordBudget` dependency even before CORE-02). (2) After CORE-06, extract `run_state_codec.gd` owning `ENTRANCE_KEYS`, `to_entrance_doc`, `validate_entrance_doc`, and `from_entrance_doc` (~320 lines), bringing `run_state.gd` under 1,000 lines.
- files to change: `sketches/core-loop/src/core/pilot_story.gd`, new `sketches/core-loop/src/core/pilot_story_rows.gd`, `sketches/core-loop/src/core/run_state.gd`, new `sketches/core-loop/src/core/run_state_codec.gd`, `scripts/sketch-lint-words.mjs` (update `pilot_story_rows.gd` source path)
- size: +1450 / -1450 lines (pure extraction)
- risk: medium — `pilot_story_rows.gd` must stay registered in `scripts/sketch-lint-words.mjs:61-65` so word-budget/voice lint still scans every string; `run_state_codec.gd` must preserve exact JSON schema (DEEP-SWEEP: medium risk)
- behaviour-preserving: yes — pure file split along already-stateless table/codec boundaries
- tests that cover it: `sketches/core-loop/tests/w50_story_arcs_test.gd`, `sketches/core-loop/tests/lore_tone_satire_test.gd`, `sketches/core-loop/tests/persistence_truncation_test.gd`, `sketches/core-loop/tests/logbook_test.gd`
- guard: `scripts/sketch-lint-words.mjs` coverage floor (`COVERAGE_FLOOR = 2650`) catches any missed string table immediately

## Not findings
- `src/game.gd` preloading scripts from all 7 subdirectories (`presentation/`, `ui/`, `movement/`, `build/`, `world/`, `combat/`, `dev/`) — `game.gd` is the intentional composition root that wires every subsystem together.
- `src/boot/boot.gd:14` preloading `src/ui/wordmark.gd` — `boot.gd` is the pre-game splash scene entry point, not a `core/` bottom-layer library, and `wordmark.gd` is its dedicated splash graphic.
- `src/core/run_store.gd:138,152` calling `_read()` on a sibling `RunStore` instance (`prev._read()`) — flagged by automated D2 scans, but both objects are the exact same `RunStore` script class (private peer helper, not a cross-module reach-in).
- `src/core/context.gd` `build_module()` meta fallback — explicitly documented in `CONTRACTS.md` as the sanctioned compatibility seam for tests that pass a minimal `Context`.
- `src/core/stage_defs.gd` `warden_lesson` / `warden_hint` — documented contract fields in `CONTRACTS.md` and scanned by `scripts/sketch-lint-words.mjs`.
- `static var` caches in `core/challenge_dials.gd`, `core/buff_ledger.gd`, `core/cosmetics.gd`, `core/thread_guard.gd`, `core/palette.gd`, `core/shift_variants.gd`, `core/upgrade_tree.gd`, `core/bindings.gd`, `core/sim_clock.gd` — all are already wired into `tools/test_batch_driver.gd:_reset()` and guarded by `sketch:lint` L14.
- `static var NODES_WORLD_ONE` in the six `src/core/trees/*.gd` files — read-only array initialized once because GDScript cannot fold `Array.slice()` into a `const` (explicitly documented at `trees/sable.gd:92`).
- `core/game_events.gd` signals (`dashed`, `carved`, `boss_reeled`, `vault_kicked`, `sprint_started`, `blink_used`, `tree_offered`, `tree_picked`) that showed 0 literal `.emit(` hits — all 8 are actively referenced across `src/` (7-94 `src/` hits each, emitted via dynamic `emit_signal` or `movement/`/`build/` helpers).
- `core/worlds.gd:4` `FULL_ALPHA := true` — actively asserted by `tests/highdraft_combat_test.gd:488` alongside `Tuning.FULL_ALPHA_UNLOCKED` as a release-gate guard.
- `core/camp_lines.gd:153` `is_won()` forwarding to `ScrapbookStore.is_won()` — 1-line internal convenience helper used 3 times inside `camp_lines.gd` itself; deleting it saves nothing.

## Needs the owner
- Unifying `run.extra` (persisted in `entrance.json`) and `run.set_meta` / subsystem keys (`trade_memory`, `pocket_draw_cache`, `w50_scrap_ingots`) into a single typed `RunState` schema requires a save-format version bump for in-progress Continue runs (`run_store.gd` / `to_entrance_doc()`).
- Deciding whether `src/core/slice_defs.gd` (1 `src/` caller, 26 `tests/` callers) and `src/core/stage_defs.gd` (7 `src/` callers, 53 `tests/` callers) should be retired into a single stage-table module (`alpha_defs.gd` + `park_defs.gd`) or kept as test-facing vertical-slice fixtures.
- Deciding whether `Profile` should own a single debounced/transaction save coordinator (eliminating all 12 scattered `profile.save()` calls across `ui/`, `presentation/`, and `world/`) vs keeping explicit immediate saves on every UI click for crash safety.
- Deciding whether `content_registry.gd` should be expanded to own validation for `WorkOrders`, `ShiftBoard`, `PilotStory`, and `MetaOptions` (and drop duplicate field checks from `Achievements`/`Cosmetics`), or keep per-module `validate()` methods and narrow `content_registry.gd` strictly to cross-module referential integrity.
