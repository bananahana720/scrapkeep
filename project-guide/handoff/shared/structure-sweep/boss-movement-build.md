# Structure survey: boss-movement-build
commit: 23e935514ef33e7eb58d50e21bd2a5f757f41fa9   model: Gemini 4 Neon (high)   files read: 65   date: 2026-11-27

## Module map
- `sketches/core-loop/src/boss/arena.gd` | 527 | Bowl arena geometry, stands, lighting, rim collider and warm-ahead cache | `_bowl`, `_stands`, `_rim`, static `_looks_warm`/`_ahead_bowl` | `boss/boss.gd`, `boss/mind_attacks.gd`, `boss/stub_boss.gd`, `core/flow.gd` (7 src)
- `sketches/core-loop/src/boss/boss.gd` | 1972 | Brindle four-phase warden boss fight, pickups, drones, charge, scooter and cobalt gates | `_phase`, `_pickups`, `_drones`, `_charge_*`, `_scooter_*`, `_cobalt_gates` | `core/flow.gd`, `core/worlds.gd`, `game.gd`, `presentation/sound_twins.gd` (5 src)
- `sketches/core-loop/src/boss/mind.gd` | 640 | World 3 Mind boss fight loop, hand takeover, arena hazards and weak points | `_warden`, `_hands`, `_hazards`, `_weak`, `_phase` | `core/worlds.gd`, `combat/codex_entries.gd`, `presentation/sound_twins.gd` (3 src)
- `sketches/core-loop/src/boss/mind_dress.gd` | 402 | Mind boss 3D kit dress, clip rig, quiet-gun mount and layer-40 ceremony card | `_rig`, `_gun`, `_card`, static `base_path`/`kit_path` | `boss/mind.gd`, `core/stage_beats.gd`, `presentation/bake_warm.gd` (3 src)
- `sketches/core-loop/src/boss/requisition.gd` | 725 | Brindle boss 3D model, scooter rig, lead-line sign, prompts and warm-ahead dress cache | `_rig`, `_scooter`, `_prompt`, static `model_path`/`scooter_path`/`_ahead` | `boss/arena.gd`, `boss/boss.gd`, `core/colour_meanings.gd`, `presentation/flourish_cues.gd` (4 src)
- `sketches/core-loop/src/boss/stub_boss.gd` | 483 | Shared base harness for World 2/3 bosses (arena enter, warden spawn, posture, pacing) | `warden`, `arena`, `_phase`, `_posture`, `_elapsed` | `boss/mind.gd`, `boss/waking.gd`, `core/colour_meanings.gd`, `presentation/sound_twins.gd` (4 src)
- `sketches/core-loop/src/boss/waking.gd` | 965 | World 2 Waking boss fight loop, floor shifts, hazards, crew callouts and weak parts | `_warden`, `_floors`, `_hazards`, `_dropping`, `_center` | `core/worlds.gd`, `combat/codex_entries.gd`, `presentation/sound_twins.gd` (3 src)
- `sketches/core-loop/src/build/accretion.gd` | 400 | 3D part-gear accretion lattice and sockets mounted on the player ball | `_nodes`, `_held`, static `_layout`/`_part_meshes` | `build/build.gd`, `build/panel_shell.gd`, `core/colour_meanings.gd`, `presentation/hero_assets.gd` (4 src)
- `sketches/core-loop/src/build/build.gd` | 1638 | Top-level build coordinator: stat recompute, hotwire shell/tread, relics, synergies, gates, shop, scrap | `sheet`, `stat_cache`, `shop`, `gates`, `scrap`, `elements`, `effects`, `_shell_*`, `_relic_fx` | `game.gd` (1 src; accessed via `ctx.build` across codebase)
- `sketches/core-loop/src/build/consumables.gd` | 773 | Pocket consumable catalogue (base + W50), W50 effects, drop cradles and anchor balloons | `ROWS`, `ROWS_W50`, static `_packed_cache`, `Cradle`, `AnchorBalloon` | `build/build.gd`, `build/reward_gates.gd`, `build/shop.gd`, `combat/combat.gd` (12 src)
- `sketches/core-loop/src/build/element_field.gd` | 968 | Active ice slabs, electrified water, steam updrafts and elemental fusion zones | `_surfaces`, `_electrified`, `_steam`, `_fusions` | `build/build.gd`, `build/item_effects.gd`, `core/colour_meanings.gd` (3 src)
- `sketches/core-loop/src/build/fabricators.gd` | 448 | Cog pricing table (`COG_PRICES`), in-world fabricator/forge/press/scrapper stations and prompts | `_stations`, `_presses`, `_scrappers` | `build/build.gd`, `build/shop.gd`, `combat/actives/active_offers.gd`, `ui/shop_counter.gd` (6 src)
- `sketches/core-loop/src/build/item_effects.gd` | 879 | Trigger bus execution, part proc effects, active grapple mutations and cross-synergy procs | `bus`, `grapple_mutations`, `_timers`, `_armed`, `_drones` | `build/build.gd`, `core/colour_meanings.gd`, `ui/build_readout.gd` (3 src)
- `sketches/core-loop/src/build/parts.gd` | 2013 | Authored part/expansion/evolved/hotwire/mutation tables, `PartDef` cache and offer roll/nudge engine | `ROWS`, `EXPANSION`, `EVOLVED`, `HOTWIRE`, `MICRO_MUTATIONS`, `GRAPPLE_MUTATIONS`, static `_defs`/`seams`/`opened_items`/`_run_ref` | `build/build.gd`, `build/build_sheet.gd`, `build/stat_cache.gd`, `build/shop.gd`, `combat/combat.gd` (41 src)
- `sketches/core-loop/src/build/reward_gates.gd` | 652 | Post-stage & cobalt-rung 3D reward gates, offer picking/rerolling, rarity colors and world prompts | `offers`, `_gates`, `_held`, `_selected` | `boss/boss.gd`, `build/build.gd`, `build/fabricators.gd`, `presentation/hero_assets.gd` (8 src)
- `sketches/core-loop/src/build/scrap_field.gd` | 688 | World scrap, cog and recovery pickups, magnet pull, ground plates and pickup audio/meshes | `_pickups`, `magnet_scale`, static `_pickup_mesh_cache`/`_pickup_assets`/`_ground_plates` | `boss/boss.gd`, `build/build.gd`, `core/stage_beats.gd`, `presentation/bake_warm.gd` (4 src)
- `sketches/core-loop/src/build/shop.gd` | 946 | Moss shop counter stock, weighing mass for cogs, cell/part buying, selling and audit rerolls | `stock`, `_rerolls`, `_weigh_*`, `_sold` | `build/build.gd`, `core/colour_meanings.gd` (2 src)
- `sketches/core-loop/src/build/synergies.gd` | 549 | Maker synergies, evolution recipes (base + W50) and cross-system synergy activation rules | `ROWS`, `EVOLUTIONS`, `EVOLUTIONS_W50`, `CROSS_SYSTEM`, `CROSS_SYSTEM_W50`, static `table` | `build/parts.gd`, `build/build.gd`, `build/build_sheet.gd`, `build/stat_cache.gd` (15 src)
- `sketches/core-loop/src/movement/augments.gd` | 894 | Pure movement augment rules: grapple/harpoon, wall vault/kick, burst abilities, bank exit and raycasts | Stateless rule module (reads/mutates `AugmentKit`, `BallState`, `Intent`) | `movement/player_ball.gd`, `boss/stub_boss.gd`, `combat/combat.gd`, `build/consumables.gd` (32 src)
- `sketches/core-loop/src/movement/chase_camera.gd` | 418 | Third-person follow camera, spring arm, aim/glance yaw-pitch, FOV and shake | `yaw`, `pitch`, `_arm`, `_shake`, `_glance` | `boss/requisition.gd`, `combat/warden.gd`, `core/context.gd`, `game.gd` (4 src)
- `sketches/core-loop/src/movement/indicator.gd` | 425 | Diegetic 3D grapple/aim/mount reticle and line-readout markers on the ball | `_marks`, `_ring`, `_line` | `movement/player_ball.gd`, `combat/rivet_kit.gd` (2 src)
- `sketches/core-loop/src/movement/player_ball.gd` | 1776 | Player ball `Node3D` controller: rigid physics step, input, speed bank, Kest air-draw/wall-kick, visual spin | `state`, `kit`, `intent`, `tuning`, `_rigid`, `chain`, `dunk`, `redline`, `_speed_bank_*`, `_kest_*`, `_spin_*` | `game.gd`, `core/context.gd`, `combat/rivet_kit.gd` (3 src; accessed via `ctx.player`)

## Outward dependencies
Deduplicated `(file -> target)` edges from `boss/`, `movement/`, `build/` to directories outside the slice (no autoloads exist in `project.godot`):
- `core`: 63 edges — most common: `core/palette.gd` (26), `core/challenge_dials.gd` (7 via `class_name`), `core/ability_state.gd` (7). Expected downward direction.
- `combat`: 35 edges — most common: `combat/boss_posture.gd` (3), `combat/threat_grammar.gd` (3), `combat/warden.gd` (3), `combat/roster.gd` (3), `combat/weapons.gd` (3), `combat/actives/active_offers.gd` (3). **LOWER -> HIGHER on 6 `movement -> combat` edges** (`player_ball.gd:21-25`, `grip.gd:3`); cross-module on 17 `boss -> combat` and 12 `build -> combat` edges.
- `presentation`: 30 edges — most common: `presentation/flash_guard.gd` (5), `presentation/craft/enemy_boss_craft.gd` (4), `presentation/ink_outline.gd` (3). **ALL 30 LOWER -> HIGHER** (22 from `boss/`, 8 from `build/`).
- `ui`: 10 edges — most common: `ui/world_prompt.gd` (3), `ui/ui_fonts.gd` (2), `ui/ui_tokens.gd` (2). **ALL 10 LOWER -> HIGHER** (4 from `boss/`, 6 from `build/`).
- `world`: 6 edges — most common: `world/hull_mark.gd` (2), `world/model_kit.gd` (1), `world/stake_devices.gd` (1), `world/trade_pockets.gd` (1), `world/interact.gd` (1). Cross-module (1 from `boss/`, 5 from `build/`).
*(Intra-slice edges for completeness: `boss -> movement` 7, `build -> movement` 4, `boss -> build` 2.)*

## Findings

### BMB-01 `movement/` preloads `combat/` for movement constants, strike damage and enemy heft (6 upward edges; 3 trivial to cut)
- kind: C
- evidence: `sketches/core-loop/src/movement/player_ball.gd:21-25` preloads `combat/chain.gd`, `combat/dunk.gd`, `combat/redline.gd`, `combat/combat.gd` (used only for `CombatRules.STRIKE_DAMAGE` at `:1387,1658,1660`), and `combat/weapons.gd` (used only for movement constants `KEST_AIR_DRAW_MAX_S`, `KEST_AIR_DRAW_GRAVITY`, `KEST_SPIRE_VAULT_UP`, `KEST_WALL_KICK_CAP`, `KEST_WALL_KICK_MULT`, `KEST_WALL_KICK_UP_MULT`, `KEST_WALL_KICK_LOCK_S` at `:138,327,447,456,463,465,1706,1716,1742,1744,1751,1752`). `sketches/core-loop/src/movement/grip.gd:3` preloads `combat/roster.gd` solely to read enemy heft.
- fix: Remove the three pure-constant/data upward edges now: (1) move the seven `KEST_*` air-draw/vault/wall-kick constants from `combat/weapons.gd` into `movement/augments.gd` (re-exporting aliases in `weapons.gd` if any test reads `Weapons.KEST_*`); (2) inject a `strike_damage_of: Callable` (or slam-base table) from `combat.gd` into `PlayerBall` instead of preloading `combat.gd`; (3) pass the target's heft float into `Grip` instead of preloading `combat/roster.gd`. (The remaining three `chain`/`dunk`/`redline` ownership edges are listed in `## Needs the owner`.)
- files to change: `sketches/core-loop/src/movement/player_ball.gd`, `sketches/core-loop/src/movement/augments.gd`, `sketches/core-loop/src/movement/grip.gd`, `sketches/core-loop/src/combat/weapons.gd`, `sketches/core-loop/src/combat/combat.gd`
- size: ~+30 / -25 lines
- risk: low (DEEP-SWEEP: constant relocation + injected numeric lookup; no tick order or formula changes)
- behaviour-preserving: yes; identical constants and numeric values, zero physics or signal order change
- tests that cover it: `sketches/core-loop/tests/char_movement_test.gd`, `sketches/core-loop/tests/char_kits_test.gd`, `sketches/core-loop/tests/flail_swing_test.gd`, `sketches/core-loop/tests/pole_flail_grip_test.gd`
- guard: Add a `sketch-lint.mjs` layer-direction rule forbidding `src/movement/` from preloading `src/combat/` (with a shrinking 3-entry baseline for `chain`/`dunk`/`redline`).

### BMB-02 Pure `build/` economy and field modules depend upward on `ui/` and `presentation/` (`shop.gd`, `scrap_field.gd`, `element_field.gd`)
- kind: C
- evidence: `sketches/core-loop/src/build/shop.gd:9` preloads `ui/odds_readout.gd` to compute numeric rarity odds; `sketches/core-loop/src/build/scrap_field.gd:4,7,8` preloads `presentation/sfx_bank.gd` (spawning `AudioStreamPlayer3D` directly), `presentation/flash_guard.gd`, and `presentation/craft_prop_meshes.gd`; `sketches/core-loop/src/build/element_field.gd:7` preloads `presentation/flash_guard.gd`. In total, `build/` has 8 upward `-> presentation` and 6 upward `-> ui` edges (`fabricators.gd:7-8`, `reward_gates.gd:8-10,13`, `accretion.gd:8-10`).
- fix: Execute the three zero-redesign cuts first: (1) move numeric `odds_for(...)` calculation from `ui/odds_readout.gd` into `build/item_gen.gd` (keeping text formatting in `ui/odds_readout.gd`), removing `shop.gd -> ui`; (2) relocate the pure boolean toggle `presentation/flash_guard.gd` into `core/flash_guard.gd`, removing 5 lower->presentation edges across `build/` (`element_field.gd`, `scrap_field.gd`) and `boss/` (`boss.gd`, `requisition.gd`, `waking.gd`); (3) emit a pickup audio fact from `scrap_field.gd` to `presentation/audio.gd` instead of preloading `sfx_bank.gd`. (The remaining 3D-view preloads in `reward_gates.gd`/`fabricators.gd`/`accretion.gd` are in `## Needs the owner`.)
- files to change: `sketches/core-loop/src/build/shop.gd`, `sketches/core-loop/src/build/item_gen.gd`, `sketches/core-loop/src/ui/odds_readout.gd`, `sketches/core-loop/src/presentation/flash_guard.gd` (move to `core/`), `sketches/core-loop/src/build/scrap_field.gd`, `sketches/core-loop/src/build/element_field.gd`, `sketches/core-loop/src/boss/boss.gd`, `sketches/core-loop/src/boss/requisition.gd`, `sketches/core-loop/src/boss/waking.gd`, `sketches/core-loop/tools/test_batch_driver.gd`
- size: ~+45 / -40 lines
- risk: low (DEEP-SWEEP: pure helper/toggle move; note `boss.gd:18` is outside `_spawn_pickup` `:705-772`, so **no re-pin of `tests/boss_pickup_asset_test.gd`**)
- behaviour-preserving: yes; same odds math, same `FlashGuard.on` boolean, same pickup sound trigger
- tests that cover it: `sketches/core-loop/tests/moss_last_call_test.gd`, `sketches/core-loop/tests/consumables_test.gd`, `sketches/core-loop/tests/durability_test.gd`, `sketches/core-loop/tests/fusion_pairing_test.gd`, `sketches/core-loop/tests/boss_pickup_asset_test.gd`
- guard: Add a `sketch-lint.mjs` rule forbidding `src/build/` from preloading `src/ui/` or `src/presentation/` outside an explicit shrinking allowlist for 3D world-view builders.

### BMB-03 Fifteen dead functions and a 27-line unreachable fallback branch with zero callers in `build/` and `movement/`
- kind: B
- evidence: Every symbol below returned exactly 1 hit (its own definition) under `git grep -n -w -- "<sym>" sketches/core-loop scripts` (verified no string/`Callable`/`.tscn` callers):
  - `sketches/core-loop/src/build/parts.gd`: `micro_mutation_ids` (`:408`), `all_micro_mutation_ids` (`:412`), `expansion_ids` (`:926`), `all_evolved` (`:930`), `all_verb_evolved` (`:937`), `hotwire_recycle` (`:1187`).
  - `sketches/core-loop/src/build/fabricators.gd`: `add_scrapper_at` (`:241`), `scrappers` (`:265`), `roll_press_target` (`:312`).
  - `sketches/core-loop/src/build/build.gd`: `synergy_read` (`:1477`).
  - `sketches/core-loop/src/build/item_effects.gd`: `grapple_mutation_for_slot` (`:210`), `cross_synergies` (`:221`), `cross_synergy_row` (`:229`).
  - `sketches/core-loop/src/build/relics.gd`: `world_swap_ids` (`:161`).
  - `sketches/core-loop/src/movement/ball_rules.gd`: `slope_gravity` (`:168`).
  - `sketches/core-loop/src/build/consumables.gd:452-478`: unreachable fallback inside `_audit_reroll_gates()` (dynamically `load("res://src/build/parts.gd")` and duplicates reroll logic) that never executes because `build/reward_gates.gd:164` always implements `reroll_offers()`.
- fix: Delete the 15 zero-caller functions and the 27-line dead fallback in `consumables.gd:452-478`.
- files to change: `sketches/core-loop/src/build/parts.gd`, `sketches/core-loop/src/build/fabricators.gd`, `sketches/core-loop/src/build/build.gd`, `sketches/core-loop/src/build/item_effects.gd`, `sketches/core-loop/src/build/relics.gd`, `sketches/core-loop/src/build/consumables.gd`, `sketches/core-loop/src/movement/ball_rules.gd`
- size: ~+0 / -115 lines
- risk: low (DEEP-SWEEP: dead-code deletion; zero references in `src/`, `tests/`, `tools/`, `scripts/`)
- behaviour-preserving: yes; none of these functions or branches are reachable
- tests that cover it: `sketches/core-loop/tests/build_catalogue_test.gd`, `sketches/core-loop/tests/build_fabricator_test.gd`, `sketches/core-loop/tests/consumables_test.gd`, `sketches/core-loop/tests/relics_data_test.gd`, `sketches/core-loop/tests/wall_grip_test.gd`
- guard: Periodic `deep-sweep.mjs` or a Node check flagging unreferenced `static func` / `func` definitions in `src/build/` and `src/movement/`.

### BMB-04 Maker-set thresholds, maker/pilot/rarity lists and grapple-mutation ownership are duplicated across `parts.gd`, `maker_sets.gd`, `relics.gd`, `item_gen.gd` and `part_def.gd`
- kind: E
- evidence:
  - Maker-set piece thresholds and grapple-mutation activation live twice: `build/maker_sets.gd:15-40` (`SETS`, `GRAPPLE_MUTATIONS`, `live_grapple_mutations()`) vs `build/parts.gd:190-193` (`MAKER_SET_PIECES`) and `build/parts.gd:475-620,648-659` (`GRAPPLE_MUTATIONS[*].maker`/`maker_pieces`, where `active_grapple_mutations()` re-derives maker completion even though `build/item_effects.gd:123` already passes `MakerSets.live_grapple_mutations(held)`).
  - `build/relics.gd:11-12` hardcodes `PILOTS` (6 IDs, despite already preloading `ClassDef` at `:5`) and `VALID_MAKERS` (7 IDs, duplicating `MakerSets.SETS.keys()`).
  - `build/item_gen.gd:15` and `build/part_def.gd:7` both declare `const RARITIES := ["common", "rare", "relic", "evolved"]`.
  - Catalogue keys from `parts.gd` are also repeated outside it in `build/items.gd` (22 part IDs), `build/synergies.gd` (22 part IDs, including `_part_matches_system` hardcoding 19 IDs at `:510-528`), `build/item_effects.gd` (8), `build/maker_sets.gd` (7), plus `combat/combat.gd` (16), `combat/orbital_satellites.gd` (14), `core/alpha_defs.gd` (13).
- fix: Make `MakerSets` the sole owner of maker-set counts and maker-to-grapple-mutation activation (`Parts` reads `MakerSets.SETS` instead of `MAKER_SET_PIECES`, and `Parts.active_grapple_mutations` delegates maker checks to `MakerSets.live_grapple_mutations(held)` instead of duplicating the loop); have `ItemGen` alias `PartDef.RARITIES`; have `Relics` read `ClassDef.ORDER` and `MakerSets.SETS.keys()`. (Larger part-ID string removal in `combat/` is in `## Needs the owner`.)
- files to change: `sketches/core-loop/src/build/parts.gd`, `sketches/core-loop/src/build/maker_sets.gd`, `sketches/core-loop/src/build/item_gen.gd`, `sketches/core-loop/src/build/relics.gd`
- size: ~+15 / -40 lines
- risk: low (DEEP-SWEEP: single-source constant & lookup consolidation)
- behaviour-preserving: yes; every maker count, rarity order, pilot list and grapple-mutation unlock condition is unchanged
- tests that cover it: `sketches/core-loop/tests/grapple_muts_test.gd`, `sketches/core-loop/tests/maker_bonuses_test.gd`, `sketches/core-loop/tests/relics_data_test.gd`, `sketches/core-loop/tests/build_catalogue_test.gd`
- guard: Extend `build_catalogue_test.gd` to assert `Parts` does not redeclare maker counts or rarity arrays independently of `MakerSets` / `PartDef`.

### BMB-05 `BuildSheet.from_parts()` and `StatCache` duplicate the full part-counting, capping, leveling and folding pipeline
- kind: A
- evidence: `sketches/core-loop/src/build/build_sheet.gd:31-82` (`from_parts`, `fold_row`, `_fold`) and `sketches/core-loop/src/build/stat_cache.gd:76-191` (`_refold_synergy`, `_counted`, `_refold`, `_fold_mods`, `_fold_patterns`, `_fold_elements`) contain line-for-line duplicate implementations of evolution-live filtering, `Parts.def_at` level override, non-hyperbolic `stack_cap` enforcement, synergy transformer/dial folding, and mod/pattern/element folding. (`BuildSheet.from_parts` is called in `combat/combat.gd:5517`, `ui/build_readout.gd:305`, and 30 tests; `StatCache` is used by `build/build.gd:105`.)
- fix: Move `_counted(held)` and the category fold helpers (`fold_mods`, `fold_patterns`, `fold_elements`, `fold_synergy_row`) onto `BuildSheet` as shared helpers, and call them from both `BuildSheet.from_parts()` and `StatCache`. Preserve `StatCache`'s existing dirty-check scope (see `## Needs the owner` regarding `EVOLUTIONS` vs `all_evolutions()`).
- files to change: `sketches/core-loop/src/build/build_sheet.gd`, `sketches/core-loop/src/build/stat_cache.gd`
- size: ~+25 / -70 lines
- risk: low (DEEP-SWEEP: pure internal deduplication across two tightly paired files)
- behaviour-preserving: yes; `stat_cache_test.gd` already asserts `StatCache.sync(held)` matches `BuildSheet.from_parts(held)` field-for-field
- tests that cover it: `sketches/core-loop/tests/stat_cache_test.gd`, `sketches/core-loop/tests/part_levels_test.gd`, `sketches/core-loop/tests/build_parts_test.gd`
- guard: Existing `stat_cache_test.gd` equivalence assertions keep both paths locked together.

### BMB-06 Ten cross-module private (`_`) member reach-ins across `boss/`, `movement/` and `build/`
- kind: C
- evidence:
  - `sketches/core-loop/src/boss/boss.gd:723` calls `Field._pickup_material(Palette.AMBER)` (`build/scrap_field.gd:119`). **Pin check**: line 723 sits inside `_spawn_pickup`'s mesh block (`:706-733`), which `tests/boss_pickup_asset_test.gd:160-163` strips before hashing `BASE_LOGIC_SHA`, so renaming `_pickup_material` requires **no re-pin**.
  - `sketches/core-loop/src/boss/mind.gd:308-311` reads/writes `hand._rest` and `hand._takeover_cd` on `combat/mind_hand.gd`.
  - `sketches/core-loop/src/boss/waking.gd:287` reads `warden._pulse_clock`; `boss/mind_dress.gd:147` and `boss/waking_dress.gd:258` read `warden._charging`; `boss/boss_model.gd:137-138` reads `warden.get("_look")` and `warden.get("_kit")`.
  - `sketches/core-loop/src/boss/waking_dress.gd:63,264` reads `owner_module._center` and `module._dropping`.
  - `sketches/core-loop/src/movement/player_ball.gd:701-702` reads `_rigid._probe` on `movement/rigid_ball.gd`.
  - `sketches/core-loop/src/build/build.gd:1601` calls `ctx.player._refit()` on `movement/player_ball.gd:476`.
  - `sketches/core-loop/src/build/maker_bonuses.gd:184` calls `ctx.spawner._trail_deal(...)` on `combat/spawner.gd`.
- fix: Expose a small public method on each owning class (`ScrapField.pickup_material()`, `MindHand.reset_rest()`, `Warden.is_charging()`/`pulse_clock()`/`visual_rig()`, `Waking.arena_center()`/`is_dropping()`, `RigidBall.probe()`, `PlayerBall.refit()`, `Spawner.deal_trail()`) and call those from the 10 sites (also updating `tests/first_warm_test.gd:92` if `_pickup_material` is renamed rather than kept as an alias).
- files to change: `sketches/core-loop/src/boss/boss.gd`, `sketches/core-loop/src/build/scrap_field.gd`, `sketches/core-loop/src/boss/mind.gd`, `sketches/core-loop/src/combat/mind_hand.gd`, `sketches/core-loop/src/boss/waking.gd`, `sketches/core-loop/src/boss/mind_dress.gd`, `sketches/core-loop/src/boss/waking_dress.gd`, `sketches/core-loop/src/boss/boss_model.gd`, `sketches/core-loop/src/combat/warden.gd`, `sketches/core-loop/src/movement/player_ball.gd`, `sketches/core-loop/src/movement/rigid_ball.gd`, `sketches/core-loop/src/build/build.gd`, `sketches/core-loop/src/build/maker_bonuses.gd`, `sketches/core-loop/src/combat/spawner.gd`
- size: ~+40 / -25 lines
- risk: low (DEEP-SWEEP: public accessor/method promotions; zero logic change)
- behaviour-preserving: yes; identical reads/writes routed through the owning class's public API
- tests that cover it: `sketches/core-loop/tests/boss_pickup_asset_test.gd`, `sketches/core-loop/tests/first_warm_test.gd`, `sketches/core-loop/tests/boss_dress_test.gd`, `sketches/core-loop/tests/maker_bonuses_test.gd`, `sketches/core-loop/tests/movement_bughunt_test.gd`
- guard: Promote `scripts/deep-sweep.mjs` D2 (cross-object `._` reach-in) into a `sketch-lint.mjs` rule with an allowlist that shrinks to zero.

### BMB-07 Duplicated physics and geometry helpers in `movement/` and `build/`: steep-face raycast, orthonormal-up basis and `MAX_SLOPE_DOT`
- kind: A
- evidence:
  - `sketches/core-loop/src/movement/player_ball.gd:1759-1776` (`_kest_steep_face`) is a verbatim duplicate of `sketches/core-loop/src/movement/augments.gd:842-858` (`_steepest_face_at`) — same 8-ray horizontal circle cast and `WALL_NORMAL_MAX_Y` filter.
  - Orthonormal-up `Basis` construction (`side := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD`) is copy-pasted 3 times in this slice (`movement/player_ball.gd:1238-1242` `_align_up`, `build/accretion.gd:272-276` `_facing`, `build/panel_shell.gd:172-176` `_facing`) and 4 more times outside (`combat/dispatcher.gd:673`, `presentation/craft/enemy_boss_craft.gd:302`, `presentation/juice.gd:360`, `presentation/vfx.gd:635`).
  - `MAX_SLOPE_DOT := 0.45` is redeclared 3 times in `movement/`: `movement/tuning.gd:86`, `movement/ball_state.gd:4`, and `movement/contact.gd:69` (`BUMP_FLOOR_DOT := 0.45`).
- fix: Make `Augments.steepest_face_at(...)` public and call it from `player_ball.gd:1730`; put one `basis_up(up: Vector3) -> Basis` helper in `core/` (e.g., `core/palette.gd` sibling `core/math_util.gd`) and call it from `player_ball.gd`, `accretion.gd` and `panel_shell.gd`; reference `Tuning.MAX_SLOPE_DOT` in `ball_state.gd` and `contact.gd`.
- files to change: `sketches/core-loop/src/movement/player_ball.gd`, `sketches/core-loop/src/movement/augments.gd`, `sketches/core-loop/src/movement/ball_state.gd`, `sketches/core-loop/src/movement/contact.gd`, `sketches/core-loop/src/build/accretion.gd`, `sketches/core-loop/src/build/panel_shell.gd`, plus one new `core/` math helper (or reuse existing `core/` utility)
- size: ~+15 / -40 lines
- risk: low (DEEP-SWEEP: pure math/raycast deduplication with identical vectors and tolerances)
- behaviour-preserving: yes; identical ray geometry, basis handedness and 0.45 slope threshold
- tests that cover it: `sketches/core-loop/tests/char_movement_test.gd`, `sketches/core-loop/tests/wall_grip_test.gd`, `sketches/core-loop/tests/panels_stack_test.gd`, `sketches/core-loop/tests/cage_contract_test.gd`
- guard: None needed beyond code review; single named helper makes future copies obvious.

### BMB-08 Burst-ability enumeration and readiness logic is triplicated across `augments.gd`, `harpoon.gd` and `player_ball.gd`
- kind: A
- evidence: `sketches/core-loop/src/movement/augments.gd:188-197` (`_burst_can_spend`), `sketches/core-loop/src/movement/harpoon.gd:49-78` (`burst_wait` and `burst_ready`, misplaced in `harpoon.gd` and called only by `player_ball.gd:918,961`), and `sketches/core-loop/src/movement/player_ball.gd:904-906` (`_burst_pilot`) each separately list `[SPRINT, BLINK, CLAW_PULL, SURGE, RECOIL]` and duplicate the cloak/mounted/ready checks. Adding a pilot burst currently requires editing all three files.
- fix: Move `BURST_ABILITIES`, `has_burst(kit)`, `burst_wait(kit)` and `burst_ready(kit)` onto `movement/augments.gd`; route `_burst_can_spend(kit)` and `player_ball.gd:904,918,961` through them, and remove `burst_wait`/`burst_ready` from `movement/harpoon.gd`.
- files to change: `sketches/core-loop/src/movement/augments.gd`, `sketches/core-loop/src/movement/harpoon.gd`, `sketches/core-loop/src/movement/player_ball.gd`
- size: ~+25 / -45 lines
- risk: low (DEEP-SWEEP: 3-file consolidation in one module; `git grep -n -w -- "burst_wait\|burst_ready" sketches/core-loop` confirms zero external callers outside `player_ball.gd`)
- behaviour-preserving: yes; identical conditions for all 6 pilots
- tests that cover it: `sketches/core-loop/tests/char_kits_test.gd`, `sketches/core-loop/tests/char_movement_test.gd`, `sketches/core-loop/tests/sable_set_piece_test.gd`
- guard: One `BURST_ABILITIES` array in `augments.gd` prevents future pilot additions from drifting across three files.

### BMB-09 Duplicated `Palette.ICE`, rarity-color lookup and tier-preserving offer-reroll logic inside `build/`
- kind: A
- evidence:
  - `const ICE := Color("c8f0ff")` is redeclared in `sketches/core-loop/src/build/accretion.gd:31` and `sketches/core-loop/src/build/element_field.gd:16` even though both already preload `core/palette.gd` which defines `Palette.ICE := Color("c8f0ff")` (`core/palette.gd:21`).
  - `sketches/core-loop/src/build/fabricators.gd:390` (`_rarity_color`) duplicates `sketches/core-loop/src/build/reward_gates.gd:360` (`rarity_color`), even though `fabricators.gd` already preloads `RewardGates`.
  - Tier-preserving offer rerolling (pick unmaxed, unused part at `tier >= min_tier`) is implemented twice: `sketches/core-loop/src/build/shop.gd:911-946` (`audit_reroll`) and `sketches/core-loop/src/build/reward_gates.gd:164-220` (`reroll_offers`).
- fix: Use `Palette.ICE` in `accretion.gd` and `element_field.gd`; replace `fabricators.gd:_rarity_color()` with `RewardGates.rarity_color()`; extract one `Parts.roll_upgrade_tier(rng, class_id, min_tier, held, used)` helper called by both `shop.gd` and `reward_gates.gd`.
- files to change: `sketches/core-loop/src/build/accretion.gd`, `sketches/core-loop/src/build/element_field.gd`, `sketches/core-loop/src/build/fabricators.gd`, `sketches/core-loop/src/build/shop.gd`, `sketches/core-loop/src/build/reward_gates.gd`, `sketches/core-loop/src/build/parts.gd`
- size: ~+25 / -55 lines
- risk: low (DEEP-SWEEP: exact same colors and pool filter; keep `Accretion.RARITY_COLORS` untouched where `tripo_variants_test.gd:256` pins it)
- behaviour-preserving: yes; identical RGB values and same-or-higher tier pool order
- tests that cover it: `sketches/core-loop/tests/build_fabricator_test.gd`, `sketches/core-loop/tests/consumables_test.gd`, `sketches/core-loop/tests/w50_isaac_economy_test.gd`, `sketches/core-loop/tests/fusion_pairing_test.gd`
- guard: `sketch-lint.mjs` or grep check for literal `Color("c8f0ff")` outside `core/palette.gd`.

### BMB-10 `boss/waking_attacks.gd` preloads `mind_attacks.gd` yet copy-pastes 8 attack/geometry helpers, and `MindAttacks.build` forces `waking.gd` to depend on `mind_attacks.gd`
- kind: A
- evidence: `sketches/core-loop/src/boss/waking_attacks.gd` preloads `boss/mind_attacks.gd` yet duplicates 8 helpers verbatim or near-verbatim: `escape_point` (`waking_attacks.gd:165` vs `mind_attacks.gd:214`), `_clear` (`:178` vs `:226`), `exposed` (`:184` vs `:232`), `choose` (`:192` vs `:239`), `commit_safe` (`:204` vs `:253`), `_bearing` (`:208` vs `:257`), `_rng` (`:212` vs `:261`), and `_flat` (`:174` vs `mind_attacks.gd:222` and `boss/hazard.gd:239`). In addition, `waking_attacks.gd:149` (`_chord`) duplicates the ray-circle exit math of `boss/boss.gd:1197` (`_travel_to_rim`). Meanwhile `MindAttacks.build(d)` (`mind_attacks.gd:127`) is purely a `Hazard` factory, forcing `boss/waking.gd:6` to preload `mind_attacks.gd`.
- fix: Move `Hazard.from_def(d)` (replacing `MindAttacks.build`) and `flat(v)` onto `boss/hazard.gd`, extract the shared attack-deck & circle-chord helpers into `boss/boss_attacks.gd` (used by `mind_attacks.gd`, `waking_attacks.gd`, and `boss.gd:_travel_to_rim`), and remove `waking.gd`'s preload of `mind_attacks.gd`. **Pin check**: `boss.gd:1197` is outside `_spawn_pickup` (`:705-772`), so **no re-pin of `tests/boss_pickup_asset_test.gd`**.
- files to change: `sketches/core-loop/src/boss/hazard.gd`, `sketches/core-loop/src/boss/mind_attacks.gd`, `sketches/core-loop/src/boss/waking_attacks.gd`, `sketches/core-loop/src/boss/waking.gd`, `sketches/core-loop/src/boss/boss.gd`, plus new `sketches/core-loop/src/boss/boss_attacks.gd`
- size: ~+105 / -145 lines
- risk: low (DEEP-SWEEP: pure deterministic math and `Hazard` constructor extraction)
- behaviour-preserving: yes; identical RNG seeds, escape-point checks and chord lengths
- tests that cover it: `sketches/core-loop/tests/waking_attack_fight_test.gd`, `sketches/core-loop/tests/mind_escape_guarantee_test.gd`, `sketches/core-loop/tests/boss_weak_parts_test.gd`, `sketches/core-loop/tests/boss_pickup_asset_test.gd`
- guard: `boss/waking*.gd` should never preload `boss/mind*.gd`.

### BMB-11 Duplicated boss dress, ceremony card and hazard-cleanup machinery across `mind_dress.gd`, `waking_dress.gd`, `mind.gd` and `waking.gd`
- kind: A
- evidence:
  - `sketches/core-loop/src/boss/mind_dress.gd:103` and `sketches/core-loop/src/boss/waking_dress.gd:68` duplicate `_has_parts(scene, parts)` verbatim.
  - `sketches/core-loop/src/boss/mind_dress.gd:266-402` and `sketches/core-loop/src/boss/waking_dress.gd:160-249` duplicate the `layer = 40` boss ceremony `CanvasLayer` card, input-dismiss polling and `0.45 s` fade loop (~140 lines of UI code duplicated inside `src/boss/`, responsible for `mind_dress.gd:8-9` preloading `ui_fonts.gd` and `ui_tokens.gd`).
  - `sketches/core-loop/src/boss/mind.gd:435-436` & `waking.gd:829-830` duplicate the `is_reel_impact` fallback; `mind.gd:535-545` & `waking.gd:493-504` duplicate `_clear_attacks` / `_free_hazards`.
- fix: Move `_has_parts` into `boss/boss_model.gd`; extract the shared `layer = 40` ceremony card into one helper (ideally in `ui/` so `boss/mind_dress.gd` drops its `ui_fonts.gd`/`ui_tokens.gd` preloads, or in `boss/boss_model.gd` if kept local); hoist `_free_hazards` and `is_reel_impact` onto `boss/stub_boss.gd` which both `mind.gd` and `waking.gd` already preload.
- files to change: `sketches/core-loop/src/boss/mind_dress.gd`, `sketches/core-loop/src/boss/waking_dress.gd`, `sketches/core-loop/src/boss/boss_model.gd`, `sketches/core-loop/src/boss/mind.gd`, `sketches/core-loop/src/boss/waking.gd`, `sketches/core-loop/src/boss/stub_boss.gd`
- size: ~+85 / -165 lines
- risk: low (DEEP-SWEEP: duplicated UI card and cleanup helpers with direct test coverage)
- behaviour-preserving: yes; identical card layout, dismiss timing and hazard teardown
- tests that cover it: `sketches/core-loop/tests/boss_dress_test.gd`, `sketches/core-loop/tests/dress_bosses_wiring_test.gd`, `sketches/core-loop/tests/boss_clip_isolation_test.gd`, `sketches/core-loop/tests/boss_phase_hold_test.gd`
- guard: None needed beyond the layer-direction lint on `src/boss/ -> src/ui/`.

### BMB-12 Copy-pasted 70-line draw loop and `hits_harder()` safeguard in `Parts.roll()` and `Parts.roll_for_stage()`
- kind: A
- evidence: `sketches/core-loop/src/build/parts.gd:1581-1644` (`roll()`) and `sketches/core-loop/src/build/parts.gd:1877-1968` (`roll_for_stage()`) duplicate the weighted pick loop, rarity fallback and the 15-line `hits_harder()` replacement block.
- fix: Extract a private helper `_pick_offers(...)` inside `build/parts.gd` shared by `roll()` and `roll_for_stage()`, keeping the exact order of `rng.randf()` / `rng.randi_range()` calls intact.
- files to change: `sketches/core-loop/src/build/parts.gd`
- size: ~+45 / -90 lines
- risk: medium (DEEP-SWEEP: RNG draw-order sensitivity; must preserve exact sequence of RNG draws for seeded determinism)
- behaviour-preserving: yes, provided RNG call order is kept identical
- tests that cover it: `sketches/core-loop/tests/offer_weights_test.gd`, `sketches/core-loop/tests/answer_weights_test.gd`, `sketches/core-loop/tests/risk_reward_distribution_test.gd`, `sketches/core-loop/tests/diversity_pool_test.gd`
- guard: Existing seeded offer-distribution tests verify draw parity.

### BMB-13 Shallow and duplicate accessors: `PlayerBall.active_body()` vs `body()` and one-line pass-throughs in `build/`
- kind: D
- evidence:
  - `sketches/core-loop/src/movement/player_ball.gd:242-248` defines both `body() -> RigidBody3D` and `active_body() -> RigidBody3D` returning `_rigid` (remnant of the retired kinematic/rigid mode switch; `git grep -n -w -- "active_body" sketches/core-loop scripts` returns 28 hits, only 2 in `src/`).
  - `sketches/core-loop/src/build/panels.gd:57-58` (`drop_row(world)`) is a 1-line forwarder to `Dropper.drop_row(world)`.
  - `sketches/core-loop/src/build/consumables.gd:205-210` defines both `_reset()` and `reset_for_tests()` where `reset_for_tests()` only calls `_reset()`.
  - `sketches/core-loop/src/build/parts.gd:1289-1298` (`completed_by`, `started_by`) are 2-line pass-throughs to `Synergies.completed_by` / `Synergies.started_by` (already surfaced by `deep-sweep.mjs` D1).
- fix: Delete `PlayerBall.active_body()` and update callers to `body()`; inline `Consumables._reset()` into `reset_for_tests()`; fold `Panels.Dropper.drop_row` onto `Panels.drop_row` directly (deleting the double definition).
- files to change: `sketches/core-loop/src/movement/player_ball.gd`, `sketches/core-loop/src/build/panels.gd`, `sketches/core-loop/src/build/consumables.gd`, plus 1 `src/` caller and test/tool callers of `active_body()`
- size: ~+25 / -35 lines
- risk: low (DEEP-SWEEP: mechanical rename/inline of zero-logic aliases)
- behaviour-preserving: yes; `active_body()` and `body()` return the exact same `_rigid` reference
- tests that cover it: `sketches/core-loop/tests/movement_bughunt_test.gd`, `sketches/core-loop/tests/panels_stack_test.gd`, `sketches/core-loop/tests/consumables_test.gd`
- guard: `scripts/deep-sweep.mjs` D1 already flags 1–2 line pass-throughs.

### BMB-14 Mixed ball-shove physics, ball-speed reads across the 3 bosses, and `item_effects.gd` reading `1.0 / physics_ticks_per_second`
- kind: G
- evidence:
  - `sketches/core-loop/src/boss/boss.gd:604-618` (`_shove_ball`) bypasses `PlayerBall.crowd_control()` by mutating `ctx.player.body().linear_velocity` directly and re-implementing `freeze`/`mounted`/`plant_time` checks (to avoid `Engine.time_scale` hit-stop scaling), whereas `boss.gd:594-600` (`_tug`), `mind.gd` and `waking.gd` use `crowd_control()`. **Pin check**: `boss.gd:604-618` is outside `_spawn_pickup` (`:705-772`), so **no re-pin of `tests/boss_pickup_asset_test.gd`**.
  - `sketches/core-loop/src/build/item_effects.gd:878-879` defines `_step() -> float: return 1.0 / float(Engine.physics_ticks_per_second)` (called at `:548,754`), violating `CONTRACTS.md:292` (*"every sim step reads `delta`, never `1.0 / physics_ticks_per_second`"*).
  - The three bosses read ball speed three different ways: `boss/waking.gd:243` (`body().linear_velocity`), `boss/mind.gd:233` (`maxf(planar, state.velocity)`), and `boss/boss.gd:513` (`planar_velocity()`).
- fix: Add `PlayerBall.shove_planar(dv: Vector3, interrupts := true)` on `player_ball.gd` owning the `freeze`/`mounted`/`plant_time` guard and call it from `boss.gd:_shove_ball`; pass `_physics_process`'s `delta` into `item_effects.gd` (eliminating `_step()`); standardize boss planar-speed checks through `PlayerBall.planar_velocity()`.
- files to change: `sketches/core-loop/src/movement/player_ball.gd`, `sketches/core-loop/src/boss/boss.gd`, `sketches/core-loop/src/boss/mind.gd`, `sketches/core-loop/src/boss/waking.gd`, `sketches/core-loop/src/build/item_effects.gd`, `sketches/core-loop/src/build/build.gd`
- size: ~+35 / -35 lines
- risk: medium (DEEP-SWEEP: live combat physics/hit-stop path; `item_effects.gd` `delta` change only differs under `Engine.time_scale != 1.0` hit-stop)
- behaviour-preserving: yes at `time_scale == 1.0`; under hit-stop, `item_effects.gd` aligns with `CONTRACTS.md:292` (verify with `build_bughunt_test.gd`)
- tests that cover it: `sketches/core-loop/tests/boss_flow_test.gd`, `sketches/core-loop/tests/boss_fixwave_test.gd`, `sketches/core-loop/tests/boss_pickup_asset_test.gd`, `sketches/core-loop/tests/build_bughunt_test.gd`, `sketches/core-loop/tests/waking_attack_fight_test.gd`
- guard: Extend `sketch-lint.mjs` to flag `Engine.physics_ticks_per_second` inside `src/build/`, `src/combat/`, `src/boss/` and `src/movement/` (enforcing `CONTRACTS.md:292`).

### BMB-15 `boss/` reaches upward into `presentation/` (22 edges, incl. 2 hidden inline `preload()`s), `ui/` (4 edges), and `build/reward_gates.gd`
- kind: C
- evidence:
  - 22 `boss -> presentation` edges across 10 files, including 2 mid-function inline `preload()` calls hidden in `sketches/core-loop/src/boss/mind_dress.gd:78` (`presentation/quiet_gun.gd`) and `mind_dress.gd:241` (`presentation/world23_chunk_craft.gd`).
  - 4 `boss -> ui` edges: `boss/mind_dress.gd:8-9` (`ui_fonts.gd`, `ui_tokens.gd`), `boss/requisition.gd:7,14` (`world_prompt.gd`, `ui_tokens.gd`).
  - `sketches/core-loop/src/boss/boss.gd:22` preloads `build/reward_gates.gd` solely to build cobalt-rung gates at `:1491,1497` (and `:17` preloads `build/scrap_field.gd` solely for `_pickup_material` at `:723`).
- fix: Do the clean low-risk steps first: (1) hoist the 2 inline `preload()`s in `mind_dress.gd:78,241` to file-top constants so the dependency graph is visible; (2) route `boss.gd:1491,1497` cobalt-rung gate creation through `ctx.build` (which already owns `RewardGates`), removing `boss.gd -> build/reward_gates.gd`; (3) pair with `BMB-02` (`flash_guard.gd` -> `core/`) and `BMB-11` (ceremony card -> `ui/`). **Pin check**: `boss.gd:17,22,1491,1497` are outside `_spawn_pickup` (`:705-772`), so **no re-pin of `tests/boss_pickup_asset_test.gd`**.
- files to change: `sketches/core-loop/src/boss/boss.gd`, `sketches/core-loop/src/build/build.gd`, `sketches/core-loop/src/boss/mind_dress.gd`
- size: ~+25 / -25 lines
- risk: low (for hoisting inline preloads + routing cobalt gates through `ctx.build`; full dress split is medium and noted in `## Needs the owner`)
- behaviour-preserving: yes; same cobalt-rung offers and same preloaded scripts
- tests that cover it: `sketches/core-loop/tests/boss_flow_test.gd`, `sketches/core-loop/tests/boss_pickup_asset_test.gd`, `sketches/core-loop/tests/cobalt_rung_voice_test.gd`, `sketches/core-loop/tests/boss_dress_test.gd`
- guard: Add a `sketch-lint.mjs` rule forbidding inline `preload("res://src/...")` inside function bodies and forbidding `src/boss/` from preloading `src/build/`.

### BMB-16 Cross-module shared mutable `static var` globals (`Synergies.table`, `Parts.seams`, `Parts.opened_items`, `Parts._run_ref`)
- kind: F
- evidence:
  - `sketches/core-loop/src/build/synergies.gd:10` (`static var table = null`) is written by `build/build.gd:161,762` and `tools/test_batch_driver.gd:255`, and read across `build/synergies.gd:140`, `build/parts.gd:1402,1412,1975` and `build/stat_cache.gd:31,39`.
  - `sketches/core-loop/src/build/parts.gd:855,893-894`: `static var seams := {}` is written directly by `build/build.gd:423`; `static var opened_items := {}` is mutated directly by `src/game.gd:547,551`; `static var _run_ref: WeakRef` is written by `core/run_state.gd:190,957,1306` via `load("res://src/build/parts.gd").bind_run(self)`.
- fix: Give `Parts` and `Synergies` explicit setter methods (`Parts.set_seams(...)`, `Parts.set_opened_items(...)`, `Synergies.set_table(...)`) or a single `BuildContext` session binding owned by `build.gd` so external modules stop mutating public `static var` fields directly and `test_batch_driver.gd` resets one entry point.
- files to change: `sketches/core-loop/src/build/parts.gd`, `sketches/core-loop/src/build/synergies.gd`, `sketches/core-loop/src/build/build.gd`, `sketches/core-loop/src/game.gd`, `sketches/core-loop/tools/test_batch_driver.gd`
- size: ~+35 / -20 lines
- risk: medium (DEEP-SWEEP: `parts.gd` has 41 `src/` callers and 101 test files; keep existing defaults when unbound and preserve `reset_for_tests()`)
- behaviour-preserving: yes; same session lifecycle and reset semantics
- tests that cover it: `sketches/core-loop/tests/stat_cache_test.gd`, `sketches/core-loop/tests/run_tier_test.gd`, `sketches/core-loop/tests/build_synergy_test.gd`, `sketches/core-loop/tests/test_batch_reset_test.gd`
- guard: Extend `sketch-lint.mjs` L14 to disallow cross-file assignments to `static var` fields (`ClassName.static_field =`).

### BMB-17 Oversized `build/parts.gd` (2,013 lines) splits cleanly into catalogue, mutations and offer/roll engine
- kind: H
- evidence: `sketches/core-loop/src/build/parts.gd` (2,013 lines, 41 `src/` callers) packs three distinct subsystems whose private state does not overlap:
  1. Authored part/expansion/evolved/hotwire tables + `def()` lookup (~950 lines).
  2. `MICRO_MUTATIONS` & `GRAPPLE_MUTATIONS` tables + lookups (`:250-720`, ~455 lines).
  3. Offer pool, maker/archetype/answer nudge weighting, and `roll()`/`roll_for_stage()` (`:1400-2013`, ~610 lines — sole reader of `maker_nudge_on`, `archetype_nudge_on`, `answer_nudge_on`, `_answering_by_class`).
- fix: Extract the offer/roll/nudge engine into `build/part_offers.gd` and the mutation tables into `build/part_mutations.gd`, leaving thin forwarding calls on `Parts` initially so all 41 `src/` callers and 101 tests stay green without a flag-day rewrite.
- files to change: `sketches/core-loop/src/build/parts.gd`, plus new `sketches/core-loop/src/build/part_offers.gd` and `sketches/core-loop/src/build/part_mutations.gd`
- size: ~+1050 / -1020 lines (pure move)
- risk: medium (DEEP-SWEEP: high fan-in module; keeping thin public facades on `Parts` avoids breaking external callers/tests)
- behaviour-preserving: yes; zero logic or RNG-order change
- tests that cover it: `sketches/core-loop/tests/build_catalogue_test.gd`, `sketches/core-loop/tests/offer_weights_test.gd`, `sketches/core-loop/tests/answer_weights_test.gd`, `sketches/core-loop/tests/grapple_muts_test.gd`
- guard: Optional line-budget ceiling on `src/build/parts.gd` after extraction.

### BMB-18 Oversized `boss/boss.gd` (1,972 lines) bundles 5 boss subsystems with isolated private state (mind the `_spawn_pickup` pin)
- kind: H
- evidence: `sketches/core-loop/src/boss/boss.gd` (1,972 lines) holds five self-contained subsystems whose private fields are unused by the others: (1) crane & pickup spawning (`:520-810`, `_crane_*`, `_pickups`); (2) furnace & shield drones (`:810-1140`, `_furnace_*`, `_drones`); (3) charge telegraph & ram (`:1140-1410`, `_charge_*`); (4) scooter chase & dismount (`:1410-1580`, `_scooter_*`); (5) cobalt-rung gates (`:1485-1580` / gate helpers). **Pin check**: `sketches/core-loop/tests/boss_pickup_asset_test.gd:158-165` hashes `func _spawn_pickup` (lines 705 and 734–772, stripping mesh lines 706–733) directly from `src/boss/boss.gd` against `BASE_LOGIC_SHA`.
- fix: Extract phases 2–4 (furnace/drones, charge, scooter) and cobalt-rung gate delegation first while leaving `_spawn_pickup` in `boss.gd`, which requires **no re-pin of `tests/boss_pickup_asset_test.gd`**. Only if phase 1 (`_spawn_pickup`) is moved to a new file must `boss_pickup_asset_test.gd:158` be repointed to that file (and `BASE_LOGIC_SHA` re-pinned if lines 705 or 734–772 change).
- files to change: `sketches/core-loop/src/boss/boss.gd`, plus new `sketches/core-loop/src/boss/boss_furnace.gd`, `sketches/core-loop/src/boss/boss_charge.gd`, `sketches/core-loop/src/boss/boss_scooter.gd`
- size: ~+780 / -740 lines (pure move)
- risk: medium (DEEP-SWEEP: real-time multi-phase boss state machine; extract one phase per PR)
- behaviour-preserving: yes; identical phase transitions, timers and physics calls
- tests that cover it: `sketches/core-loop/tests/boss_pickup_asset_test.gd`, `sketches/core-loop/tests/boss_flow_test.gd`, `sketches/core-loop/tests/boss_fixwave_test.gd`, `sketches/core-loop/tests/brindle_flume_ride_sounds_test.gd`
- guard: `tests/boss_pickup_asset_test.gd` automatically verifies `_spawn_pickup` logic hash integrity.

### BMB-19 Oversized `movement/player_ball.gd` (1,776 lines) contains three isolated private-state subsystems
- kind: H
- evidence: `sketches/core-loop/src/movement/player_ball.gd` (1,776 lines) mixes the core ball controller with three subsystems whose private fields are read nowhere else: (1) speed-bank state machine (`:124-131,668-755`, ~110 lines, `_speed_bank_*`); (2) Kest air-draw / spire-vault / wall-kick (`:138,1680-1776`, ~95 lines, `_kest_*` — the sole reason `player_ball.gd` preloads `combat/weapons.gd`); (3) visual spin & squash interpolation (~55 lines, `_spin_*`).
- fix: Extract `movement/speed_bank.gd` (`RefCounted`) and `movement/kest_air.gd` (`RefCounted`, paired with `BMB-01` to drop `combat/weapons.gd`), then move visual spin/squash interpolation to a small visual helper.
- files to change: `sketches/core-loop/src/movement/player_ball.gd`, plus new `sketches/core-loop/src/movement/speed_bank.gd`, `sketches/core-loop/src/movement/kest_air.gd`
- size: ~+260 / -240 lines (pure move)
- risk: medium (DEEP-SWEEP: core physics loop; preserve exact `_physics_process` call order)
- behaviour-preserving: yes; exact same per-tick state transitions and forces
- tests that cover it: `sketches/core-loop/tests/char_movement_test.gd`, `sketches/core-loop/tests/movement_bughunt_test.gd`, `sketches/core-loop/tests/wall_grip_test.gd`, `sketches/core-loop/tests/char_kits_test.gd`
- guard: None beyond existing movement regression tests.

### BMB-20 Oversized `build/build.gd` (1,638 lines) mixes build orchestration with four self-contained subsystems
- kind: H
- evidence: `sketches/core-loop/src/build/build.gd` (1,638 lines) interleaves run-level build orchestration with four self-contained clusters owning private state nobody else touches: (1) hotwire shell & spark-tread lifecycle (~185 lines, `_shell_*`/`_hotwire_*`/`_tread_*`, splitting hotwire logic across `build.gd` and `hotwire_rules.gd`); (2) relic-to-ability-kit sync (`:1580-1638`, ~66 lines, `_relic_fx`/`_relic_apply`/`_relic_undo`); (3) rib caches & panel drops (~60 lines, `_rib_*`/`_dropper`); (4) synergy runtime stepping (`:1481-1614`, ~145 lines, `_step_synergies`).
- fix: Extract hotwire shell/tread runtime into `build/hotwire_shell.gd` (beside `hotwire_rules.gd`), relic-kit sync into `build/relic_sync.gd`, and synergy runtime stepping into `build/synergy_runtime.gd`, keeping `build.gd` as the slim coordinator for `ctx.build`.
- files to change: `sketches/core-loop/src/build/build.gd`, plus new `sketches/core-loop/src/build/hotwire_shell.gd`, `sketches/core-loop/src/build/relic_sync.gd`, `sketches/core-loop/src/build/synergy_runtime.gd`
- size: ~+450 / -420 lines (pure move)
- risk: medium (DEEP-SWEEP: central coordinator for `recompute()`, signals and per-tick build updates; extract one cluster per PR)
- behaviour-preserving: yes; identical signal connections, recompute order and per-tick stepping
- tests that cover it: `sketches/core-loop/tests/hotwire_shell_held_test.gd`, `sketches/core-loop/tests/hotwire_shell_offer_test.gd`, `sketches/core-loop/tests/build_bughunt_test.gd`, `sketches/core-loop/tests/build_synergy_test.gd`, `sketches/core-loop/tests/relics_data_test.gd`
- guard: None beyond existing build and hotwire tests.

## Not findings
- `boss/hazard.gd:4` -> `combat/threat_grammar.gd`: explicitly documented intentional seam (`CONTRACTS.md:480`).
- `boss/boss_contract.gd` (89 lines): test-only contract verifier used by `tests/boss_contract_test.gd`; intentionally co-located with boss modules.
- Static caches `boss/boss.gd:_pickup_materials`/`_pickup_mesh`, `build/accretion.gd:_layout`/`_part_meshes`, `build/panel_shell.gd:_meshes`/`_sockets`: immutable geometry/material caches explicitly allowlisted in `scripts/sketch-lint.mjs:770-778` (rule L14).
- `build/build.gd` thin pass-throughs (`apply_element`, `clock_paused`, `note_offered`, etc.): contractual facade methods (`CONTRACTS.md`) — deleting them would spread `ctx.build.<subcomponent>` reach-ins across callers.
- `build/parts.gd:234-248` (`maker_nudge_on`, `archetype_nudge_on`, `answer_nudge_on`): test-control toggles already reset by `Parts.reset_for_tests()` in `tools/test_batch_driver.gd:186`.
- `movement/augments.gd:84,87,98` (`MASS_HEFT_DIVISOR`, `VAULT_FACE_COOLDOWN`, `SKID_KEEP`): appear unused inside `augments.gd`, but are actively read by `core/upgrade_tree.gd:38,46` and movement tests.
- `build/fabricators.gd:253,273` (`add_press_at`, `use_press`): test-only today (`tests/w50_isaac_economy_test.gd:136-137`) for the W50 press feature rather than stale legacy code.
- `boss/boss.gd:706-733` mesh edits inside `_spawn_pickup`: `tests/boss_pickup_asset_test.gd:160-163` strips that range before hashing `BASE_LOGIC_SHA`, so cleanup inside those lines does not break the pin.
- `movement/player_ball.gd:401,421` (`Augments.bank_exit`): already delegates to `augments.gd` rather than duplicating the launch formula.
- `build/accretion.gd:25` (`RARITY_COLORS["common"] = Palette.COPPER`) vs `build/reward_gates.gd:360` (`"common" -> Palette.ARC`): intentional palette split pinned by `tests/tripo_variants_test.gd:256` and `CONTRACTS.md:678`.

## Needs the owner
- `movement/player_ball.gd:21-23` preloads `combat/chain.gd`, `combat/dunk.gd` and `combat/redline.gd`: deciding whether those three combo/line state machines move into `movement/` or stay in `combat/` behind signals is a module-boundary call affecting scene/test paths.
- `build/build.gd:519` vs `:1381`: `_physics_process` overwrites `scrap.magnet_scale = sheet.magnet * effects.magnet_boost()`, dropping `Companion.vacuum_scale(ctx.run.companion)` that `recompute()` applies at `:519` — needs owner confirmation on intended behaviour before touching.
- `build/stat_cache.gd:96,104` checks `Synergies.EVOLUTIONS` rather than `Synergies.all_evolutions()` (omitting `EVOLUTIONS_W50` dirty-tracking on ingredient changes): fixing it alters runtime cache invalidation for W50 evolutions and needs owner sign-off.
- `build/reward_gates.gd`, `build/fabricators.gd`, `build/accretion.gd`, `boss/mind_dress.gd`, `boss/waking_dress.gd`, `boss/requisition.gd`, `boss/arena.gd` build 3D meshes and HUD prompts directly inside `build/` and `boss/` (driving most of the 30 `-> presentation` and 10 `-> ui` edges): needs an architecture call on whether to split them into `presentation/` listeners or formalize a `dress/` layer.
- `movement/tuning.gd` (`SPECS`/`FLAGS`) owns non-movement global flags (`called_shot`, audio/combat/UI switches) because `scripts/sketch-lint.mjs` L3 binds CLI flags to `tuning.gd`: relocating global flags to `core/` requires updating L3 and 133 tests.
- Part IDs from `build/parts.gd` are hardcoded as raw string literals across `build/items.gd` (22), `build/synergies.gd` (22), `combat/combat.gd` (16), `combat/orbital_satellites.gd` (14) and `core/alpha_defs.gd` (13): replacing string ID branches with schema-driven `PartDef` tags/effects is a larger data-model redesign.
