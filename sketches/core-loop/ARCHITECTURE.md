# Core-loop architecture

Canonical architecture map for the Godot 4.7.2 alpha game under `sketches/core-loop/src/`. This document owns the live directory map, runtime state owners, complete `Context` field inventory, `GameEvents` signal group index, and script dependency-cycle status.

Behavioral contracts for module seams (Warden handshake, `event_kinds`, Spawner/Terrain APIs, Camera/Ball hooks, Codex, and RunLog formats) remain in [CONTRACTS.md](CONTRACTS.md); gameplay direction lives in [design-v3/DESIGN-V3.md](design-v3/DESIGN-V3.md).

## Directory map

| Path | Role |
| --- | --- |
| `src/game.gd` | Root `Node3D` bootstrapper: creates spine objects (`GameEvents`, `RunState`, `Tuning`, `PlayerBall`, `ChaseCamera`, `Beacon`, `Context`, `Flow`, persistence/log stores), mounts core modules (`world`, `combat`, `build`, `boss`, `presentation`), wires UI (`Hud`, `Screens`, `RadioDeck`, `LaunchTake`, `FieldNotes`, `TuningPanel`), attaches optional `--dev` console and `--experimental-depth` bridge, and lazily loads `MENU_PATHS` (`camp_hub.gd`, `camp_enemy_picker.gd`, `workshop.gd`, `pause_menu.gd`). |
| `src/boot/` | `boot.gd`: lightweight 2D boot card that threaded-loads `main.tscn` (`src/game.gd`) on graphical launches and falls back to synchronous load for headless runs and tests. |
| `src/core/` | Spine, run/meta state, event bus (`game_events.gd`, `event_kinds.gd`), state machine (`flow.gd`), `Context`, `BuffLedger`, persistence stores (`profile.gd`, `progress.gd`, `codex.gd`, `run_log.gd`, `run_moments.gd`, `run_store.gd`, `safe_store.gd`, `scrapbook_store.gd`), stage/world tables (`park_defs.gd`, `alpha_defs.gd`, `slice_defs.gd`, `stage_defs.gd`, `worlds.gd`), pilots (`class_def.gd`, `upgrade_tree.gd`, `pilot_story.gd`), companion, radio, achievements, and shell/stamp utilities. |
| `src/movement/` | Rigid-body gyrosphere (`rigid_ball.gd`, `player_ball.gd`, `ball_rules.gd`, `ball_state.gd`), tuning (`tuning.gd`), chase camera (`chase_camera.gd`), input (`intent.gd`), and mobility augments (`harpoon.gd`, `grip.gd`, `augments.gd`, `augment_kit.gd`, `contact.gd`, `speed_tier.gd`, `aim_style.gd`, `exception_hold.gd`, `indicator.gd`). |
| `src/world/` | World module (`world.gd`), terrain and six Arizona parks (`terrain.gd`, `park/*`), flood/heat/weather hazards, director and stage events (`director.gd`, `event_director.gd`, `events/*`), activities, pockets (`pockets/*`), destructibles (`destructibles.gd`), launch rails, Moss's workshop bay (`bay.gd`), and camp hub (`camp_hub.gd`, `camp_*.gd`). |
| `src/combat/` | Combat module (`combat.gd`), enemy roster/spawner/posture/plating (`enemy.gd`, `roster*.gd`, `warden*.gd`, `boss_posture.gd`, `attack_budget.gd`), pilot weapons/kits/ultimates (`weapons.gd`, `ultimate.gd`, `rivet_kit.gd`), active items (`actives/*`), and special cues/telegraphs (`special_cues.gd`, `telegraph*.gd`, `threat_grammar.gd`). |
| `src/build/` | Build module (`build.gd`), scrap/cogs pickups (`scrap_field.gd`), parts/items/relics/panels/consumables (`parts.gd`, `items.gd`, `relics.gd`, `panels.gd`, `consumables.gd`, `fabricators.gd`, `reward_gates.gd`, `shop.gd`), synergies/elements/maker sets (`synergies.gd`, `elements.gd`, `maker_sets.gd`), accretion, and tuning-mod stat cache (`stat_cache.gd`). |
| `src/boss/` | Boss module (`boss.gd`) and the three world bosses: Admiral Brindle (`boss_model.gd`, `boss_rules.gd`, `arena.gd`, `requisition.gd`), The Waking (`waking*.gd`), and The Mind (`mind*.gd`), plus shared weak points and arena hazards (`weak_points.gd`, `hazard.gd`). |
| `src/presentation/` | Presentation module (`presentation.gd`), juice/VFX/scenery (`juice.gd`, `fx_library.gd`, `world_fx/*`, `world_look.gd`, `*_scenery.gd`, `craft/*`), audio/SFX/music (`audio.gd`, `sfx_bank.gd`, `synth.gd`, `music_engine.gd`, `ace_sequencer.gd`, `radio_deck.gd`), and animations/rigs (`enemy_motion.gd`, `pilot_antics.gd`, `opening.gd`, `launch_take.gd`). |
| `src/ui/` | HUD, screens, menus, pause/workshop/camp UI (`hud.gd`, `screens.gd`, `pause_menu.gd`, `workshop.gd`, `camp_menu.gd`), ability bar/reticle/boss plate/callouts (`ability_bar.gd`, `aim_reticle.gd`, `boss_plate.gd`, `screen_busy.gd`), field notes/tuning panel (`field_notes.gd`, `tuning_panel.gd`), and `settings_store.gd`. |
| `src/dev/` | `--dev` developer console and headless agent/probe helpers (`dev_console.gd`, `dev_agent.gd`, `dev_commands.gd`, `dev_fight.gd`, `dev_inspect.gd`, `dev_lens.gd`, `dev_look.gd`, `dev_overlay.gd`, `dev_session.gd`). Mounted only when `--dev` is active (never in plain launches or tests). |
| `src/experimental/` | Opt-in `--experimental-depth` / `SCRAPKEEP_EXPERIMENTAL` live run bridge (`live_run_bridge.gd`), adversity/encounter prototypes, dynamic setpieces, jury-rig synergies, and experimental director resources (`resources/director/*`). |

To count tracked `.gd` scripts, run `git ls-tree -r --name-only HEAD sketches/core-loop/src | grep -c '\.gd$'` (or pass a subdirectory path for one folder).

### Module mount order in `src/game.gd`

1. Spine core (`GameEvents`, `RunState`, `Tuning`, `PlayerBall`, `ChaseCamera`, `Beacon`, `Context`, `Flow`, `Opening`, `Codex`, `RunLog`, `RunMoments`, `Profile`, `Progress`).
2. `world` (`src/world/world.gd`) -> sets `ctx.terrain` and `ctx.destructibles`; scenery, `WorldFx`, and `bake_warm` hooks attach immediately after.
3. `combat` (`src/combat/combat.gd`) -> sets `ctx.spawner`.
4. `build` (`src/build/build.gd`) -> sets `ctx.build`.
5. `boss` (`src/boss/boss.gd`, loaded if present) -> sets `ctx.boss`.
6. `ctx.screen_busy` (`ScreenBusy`), then `presentation` (`src/presentation/presentation.gd`).
7. `flow.setup(ctx, beacon)`, optional `RunStore`, HUD/screens/radio/notes/tuning UI, optional `--dev` console, optional `--experimental-depth` bridge, and deferred `MENU_PATHS` (`camp_hub`, `camp_enemy_picker`, `workshop`, `pause_menu`).

## Primary runtime state owners

| Owner | Script | Persisted file | Owns |
| --- | --- | --- | --- |
| `RunState` | `src/core/run_state.gd` | none (snapshotted by `RunStore`) | Active run HP/max HP, `scrap` tally, `cogs` spend wallet, `mass`, heft/class, `parts`, `panels`, `consumables`, `bonus_cores`, kills, `events_won` (emits `milestone_won`), stage-start snapshots, and `death_save_hook`. |
| `Flow` | `src/core/flow.gd` | via `RunStore` | Run/stage state machine (`title`, `class_select`, `stage`, `beacon`, `gates`, `launch`, `boss`, `victory`, `lap`, `summary`, `dead`), Warden seal/unseal, arena transitions, and retry/replay checkpoints. |
| `BuffLedger` | `src/core/buff_ledger.gd` | none | Active timed and counted gameplay buffs; subscribes to `GameEvents` run/stage/death resets and binds to `PlayerBall.abilities`. |
| `Profile` | `src/core/profile.gd` | `user://profile.json` (schema 4, `SafeStore`) | Durable unlocks and meta state: pilots, worlds, cosmetics, achievements, equipped loadouts, stats, settled runs, companion, seen flags, meta options, heard tunes, radio, and camp state. |
| `Progress` | `src/core/progress.gd` | writes to `Profile` | Live achievement evaluation, shift-board unlocks, work orders, ledger-leaf returns, and pilot story chapters. |
| `Codex` | `src/core/codex.gd` | `user://codex.json`, `user://codex-log.ndjson` | Discovery registry (build/world/enemy/story/lore entries), per-attempt rewind on stage/arena retry, and discovery burst triggers. |
| `RunLog` / `RunMoments` | `src/core/run_log.gd`, `src/core/run_moments.gd` | `user://runs.ndjson`, scrapbook via `ScrapbookStore` | Cumulative per-run/per-stage telemetry (traversal flow share, dead stops, bites, smashes, anomalies, arena stats) and captured run moments. |
| `RunStore` | `src/core/run_store.gd` | `user://run.json` (schema 1, `SafeStore`) | Atomic in-progress run persistence and refusal checks for Title `Continue`. |
| `SettingsStore` | `src/ui/settings_store.gd` | `user://settings.json` (`SafeStore`) | Audio bus volumes, comfort/display toggles (fullscreen, quality, reduced motion/flashes, frame smoothing, wide picture), look sensitivity, and key bindings. |
| `Tuning` | `src/movement/tuning.gd` | none (optional F4 dump `user://tuning-<ts>.json` is written by `src/game.gd` under `--dev`) | Base movement/launch profile knobs and build-applied modifiers (`clear_mods`, `set_mod`, `mod`). |
| `ScreenBusy` | `src/ui/screen_busy.gd` | none | Combat quiet-window arbiter coordinating non-urgent HUD/callout timing. |

## `Context` field inventory (`src/core/context.gd`)

Every `var` declared on `src/core/context.gd` (checked by `npm run check:docs`):

| Field | Type / default | Set by | Role |
| --- | --- | --- | --- |
| `buffs` | `BuffLedger` (`BuffLedger.new()`) | `Context` default | Active timed/stacked buff ledger; setter rebinds `events` and `player.abilities`. |
| `events` | `GameEvents` | `game.gd` | Central signal bus; setter rebinds `buffs`. |
| `run` | `RunState` | `game.gd` | Active run state and mutators. |
| `tuning` | `Tuning` | `game.gd` | Movement/gameplay tuning values and part modifiers. |
| `player` | `PlayerBall` | `game.gd` | Player rigid-body ball; setter rebinds `player.abilities` to `buffs`. |
| `camera` | `ChaseCamera` | `game.gd` | Chase camera rig backing `aim_origin()`, `aim_forward()`, and `heading()`. |
| `flow` | `Node` (`Flow`) | `game.gd` | Run/stage flow state machine. |
| `terrain` | `RefCounted` | `world.setup(ctx)` | Stage geometry, height/surface queries, spawn/beacon points, scrap trails, and materials. |
| `spawner` | `Node` | `combat.setup(ctx)` | Enemy spawner, `strike()`, `punch_now()`, `plating_of()`, `integrity_of()`, and `would_crush()`. |
| `build` | `Node` | `build.setup(ctx)` | Build/parts/gates/synergies module (also readable via `build_module()`). |
| `codex` | `Node` (`Codex`) | `game.gd` | Discovery registry and persistent codex. |
| `run_log` | `Node` (`RunLog`) | `game.gd` | Run telemetry collector writing `user://runs.ndjson`. |
| `profile` | `RefCounted` (`Profile`) | `game.gd` | Durable player profile (`user://profile.json`). |
| `progress` | `Node` (`Progress`) | `game.gd` | Achievement, shift-board, work-order, and story progression observer. |
| `boss` | `Node` | `boss.setup(ctx)` | World boss encounter controller (`enter_arena`, `live_plating`, `floor_y`, `rescue_point`). |
| `stages` | `StageDefs` (launch default `ParkDefs`) | `game.gd` | Active stage/world definition table (`ParkDefs`, `AlphaDefs`, `SliceDefs`, or `StageDefs`). |
| `root` | `Node3D` | `game.gd` | Scene root (`Game`) under which modules parent world children. |
| `destructibles` | `Node` | `world.setup(ctx)` | Heft-scaled destructible prop manager invoked by `break_props()`. |
| `rng` | `RandomNumberGenerator` | `Context` default (`game.gd` seeds `20260926`) | Shared seeded run RNG stream. |
| `calm` | `bool` (`false`) | tests / `--dev` | Suppresses own-schedule spawns and world pushes when true. |
| `screen_busy` | `Node` (`ScreenBusy`) | `game.gd` | Combat quiet-window arbiter for HUD callouts. |
| `dev` | `bool` (`false`) | `game.gd` | True when launched with `--dev` or set in dev/test harnesses. |
| `_hit_stop` | `Callable` | `Context._init()` | Private callback from `game.gd` backing `hit_stop(seconds)`. |

Helper methods on `Context`: `build_module()`, `aim_origin()`, `aim_forward()`, `heading()`, `can_spawn()`, `break_props(at, radius, source)`, and `hit_stop(seconds)`.

## `GameEvents` signal groups

`src/core/game_events.gd` is the canonical signal list (132 declared `signal` lines plus the dynamic user signal `consumable_used`). Every signal has a matching row in `src/core/event_kinds.gd`, enforced by `sketches/core-loop/tests/spine_event_kinds_test.gd`.

| Group | Signals in `src/core/game_events.gd` |
| --- | --- |
| Run, world, stage & Warden flow | `run_started`, `flow_changed`, `world_entered`, `stage_entered`, `stage_cleared`, `run_ended`, `beacon_charge_changed`, `beacon_unsealed`, `warden_sighted`, `warden_engaged`, `quick_break`, `stage_content_cleared` |
| Economy, growth, hull & kills | `scrap_collected`, `cogs_collected`, `part_gained`, `panel_gained`, `evolution_fired`, `player_hit`, `escape_window`, `player_died`, `enemy_killed`, `milestone_won`, `heft_class_changed`, `heft_class_dropped`, `scrap_lost`, `core_gained` |
| Discovery & codex | `synergy_discovered`, `interaction_found` |
| Movement, harpoon & pylon mount | `jumped`, `boosted`, `dashed`, `landed`, `bumped`, `slammed`, `carved`, `drop_landed`, `missed_drop`, `grapple_fired`, `grapple_released`, `harpoon_bit`, `harpoon_smashed`, `mounted`, `dismounted` |
| Combat hits, shots & posture | `enemy_spawned`, `enemy_struck`, `shot_fired`, `special_used`, `strike_deflected`, `enemy_rebounded`, `enemy_pinned`, `enemy_ringed_out`, `enemy_walled`, `posture_changed` |
| Rewards & elements | `reward_offered`, `reward_chosen`, `element_resolved` |
| Stage events, launch & threat | `event_announced`, `event_started`, `event_ended`, `event_progress`, `launched`, `pressure_changed`, `threat_rose` |
| Boss fights | `boss_arena_entered`, `boss_phase_changed`, `boss_attack_telegraphed`, `fight_phase_changed`, `attack_cued`, `boss_weak_point_hit`, `boss_reeled`, `boss_defeated` |
| Pilot kits, gauges, trees & bay | `vault_kicked`, `gauge_charging`, `gauge_released`, `gauge_cancelled`, `sprint_started`, `cc_ignored`, `cloak_started`, `cloak_broken`, `sticky_detonated`, `rocket_jumped`, `blink_used`, `arc_slammed`, `skid_smashed`, `demo_slammed`, `tree_offered`, `tree_picked`, `bay_entered`, `bay_left`, `world_fact` |
| Holds, packs, tells & interactables | `hold_started`, `hold_broken`, `hold_ended`, `tenacity_gained`, `pack_arrived`, `shield_vaulted`, `vent_charging`, `vent_erupted`, `swarm_scattered`, `mind_adapted`, `weak_point_opened`, `near_miss`, `interact_armed`, `interact_fired`, `ambush_ended`, `bet_resolved` |
| Line state, prompts & quests | `line_state_changed`, `verb_failed`, `prompt_shown`, `cause_armed`, `cause_fired`, `activity_done`, `achievement_earned`, `rescue_completed` |
| Skill bar, actives, ultimates & consumables | `slot_selected`, `slot_cast`, `line_skill_loaded`, `line_skill_fired`, `line_skill_expired`, `active_fired`, `active_heat`, `ultimate_ready`, `ultimate_started`, `ultimate_peak`, `ultimate_landed`, `ultimate_cancelled`, `consumable_used` |
| Specials, radio, stakes, trades & maker sets | `special_broken`, `radio_take_found`, `relay_stake_paid`, `trade_taken`, `maker_set_completed`, `overflow_cashed` |

## Script dependency-cycle status (`L16`)

`npm run sketch:lint` enforces rule `L16` (see `scripts/sketch-lint.mjs` and `scripts/sketch-lint.baseline.json`):

- **Static graph**: `buildScriptGraph` scans every `.gd` file under `sketches/core-loop/src/` for `"res://src/...gd"` references and declared `class_name` uses, then computes strongly connected components (`stronglyConnectedComponents`).
- **Ratchet baseline**: `scripts/sketch-lint.baseline.json` pins the existing files in cycles (`179` files at `d393d7af`). Any file newly joining a cycle fails `sketch:lint`, and any baselined file that leaves its cycle fails until its entry is removed so the list can only shrink.
- **Targeted ownership and boundary rules**: Directories are not yet strict acyclic layers because `src/core/` still references files in other directories. Alongside `L16`, `sketch:lint` enforces `L6` (runtime `Light3D` ownership), `L7` (no `res://tools/` paths in `src/`), `L8` (no physics-tick `ball_position()` reads in `src/presentation/` or `src/ui/`), `L9` (no direct `player.global_position` / `position` reads), and `L10` (no hand-moving the ball's `RigidBody3D`).
