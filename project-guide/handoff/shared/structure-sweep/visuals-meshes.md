# Structure survey: visuals-meshes
commit: 23e935514ef33e7eb58d50e21bd2a5f757f41fa9   model: Claude Opus 5.5 (claude-opus-5-5), high effort   files read: 34 (20 slice files, 14 callers and owners outside the slice)   date: 2026-11-27

Paths are relative to `sketches/core-loop/`. Every grep below ran in that folder at the commit above.

## Module map
Files of 400 lines or more, all under `src/presentation/`.

path | lines | what it owns | state it owns | who calls it most
--- | --- | --- | --- | ---
hero_assets.gd | 3348 | Hero models for pilots, wardens, the weapon ring, masts, shelters and reactions; it loads the .glb or builds a primitive stand-in | static `_scenes` PackedScene cache, `_warn_logged` | 72 test files; combat, ui, world and presentation callers
world23_chunk_craft.gd | 1886 | World 2 and 3 chunk meshes, the chunk dress, and the PBR material helpers `make_weathered_pbr` and `enrich_standard_pbr` | static `_mesh_cache`, `_mat_cache` | 16 files: boss/mind_dress, combat/deflector, combat/kite_drone, highdraft_scenery
park_props.gd | 1817 | Park prop placement, MultiMesh batches, LOD ranges, the far merge, and the stand-in versus hero-model choice | static caches for stand-ins and generated meshes | 18 test files; world/park
craft/experimental_setpiece_craft.gd | 1469 | The smelter crane set piece (a near fork of world23_chunk_craft) | static `_mesh_cache`, `_mat_cache` | experimental/dynamic_setpieces, smelter_crane_chunk.tscn
craft_prop_meshes.gd | 1449 | World 1 prop meshes plus the oldest primitive set (`_bevel_box`, `_bevel_cyl`, `_bevel_ring`, `_bolt_ring` and the `_masked` variants) and `weathered_material` / `salvage_wear_material` | static mesh and material caches | 23 files: boss/arena, build/scrap_field, combat/stakes, arena_bowl_yard
craft/hero_kitbash_sculptor.gd | 1378 | `KitbashCanvas` (per-slot SurfaceTool, add_tri, add_quad, commit) and the public kitbash parts | none | craft_showcase_assembly, experimental_setpiece, world23, tools/craft_sculptor_capture
highdraft_scenery.gd | 1270 | Highdraft stage dressing and the glb mesh extraction `_scene` | scene caches | 7 test files; world/map_highdraft
craft/enemy_boss_craft.gd | 1051 | Enemy and boss meshes, a second copy of the primitive set, and `craft_shader_material` | static `_mesh_cache` with multiple slots | 18 files: boss/arena, boss/boss, boss/requisition, boss/waking_dress
spillway_scenery.gd | 1010 | Spillway dressing, the merged `_batch`, cottonwoods, `_prop_material` | scene cache, tree plan | 13 test files
dig_scenery.gd | 967 | Dig stage dressing, `_slot_material`, glb part extraction `_parts` | `_dir_cache` | 8 test files
craft/vista_atmosphere_rig.gd | 769 | Vista fog and light rig | node-local | craft_showcase_arena.tscn
craft/vista_megastructures.gd | 593 | Background megastructure meshes, with its own `_append_box` | node-local | craft_showcase_arena.tscn
crafted_ball_gear.gd | 525 | Ball gear meshes with another primitive set (`add_beveled_box`, `add_cylinder`, `add_torus`, `add_faceted_orb`) | mesh cache | build/accretion, combat/bolts, weapon_rig_fx
w50_asset_hooks.gd | 514 | Dresses drops, stations and active or relic world props with glb models | static `_packed_cache`, a per-kind node pool | combat (per-frame sync), tests/w50_3d_assets_test.gd
craft/camp_craft_meshes.gd | 424 | Camp meshes, a third copy of `_uv_for` and `_add_tri`, public `vc` and `add_bevel_box`, and camp materials | static caches | world/camp_hub, camp_ring, camp_trial, experimental/live_run_bridge, live_world_actors, ui/customize_page
craft/craft_showcase_assembly.gd | 421 | Showcase arena assembly, used by tools only | none | tools/craft_showcase_capture, craft_showcase_deep_audit, test_batch_driver

## Outward dependencies
- `src/core`: 20 of the 20 slice files preload something from it. Examples: `palette.gd` in craft_prop_meshes.gd and world23_chunk_craft.gd; `app_shell.gd` and `thread_guard.gd` in park_props.gd. Higher layer to lower layer, the right direction.
- `src/world`: 4 slice files. Examples: park_props.gd:8 preloads `world/park/park_terrain.gd` and :13 preloads `world/event_director.gd`; highdraft_scenery.gd preloads `world/map_highdraft.gd`. Presentation to world, acceptable, but see VM-03 for the private calls.
- `src/combat`: 3 slice files. Examples: hero_assets.gd preloads `combat/warden_look.gd`, `combat/warden_kit.gd` and `combat/enemy.gd` (:2763); hero_fx.gd preloads `combat/weapons.gd`. Acceptable direction.
- `src/build`: 1 slice file. Example: hero_assets.gd preloads `build/accretion.gd` and `build/reward_gates.gd`.
- `src/movement`: 3 slice files. Examples: highdraft_scenery.gd preloads `movement/augments.gd`; park_props.gd and hero_assets.gd preload `movement/tuning.gd`.
- `src/ui`: 1 slice file. Example: hero_assets.gd preloads `ui/ui_tokens.gd`. **Sideways, from presentation into ui.**
- Inward from lower layers, the wrong direction. **World, combat, build and boss preload presentation mesh builders.** world/camp_hub.gd, camp_ring.gd and camp_trial.gd preload `craft/camp_craft_meshes.gd`; combat/stakes.gd and build/scrap_field.gd use `craft_prop_meshes.gd`; combat/deflector.gd:75 and :135 and combat/kite_drone.gd:143 preload `world23_chunk_craft.gd` for a material helper; boss/* uses `enemy_boss_craft.gd` (18 files).

## Findings  (≤20, best first)

### VM-01 Seven copies of the vertex-mask helper `_vc` re-implement `CraftLookdev.encode_mask`
- kind: A (also E: the mask contract is a fact with one owner)
- evidence: `git grep -nE '^static func _vc\(|^static func vc\(' -- src` returns 7 hits. They are camp_craft_meshes.gd:17 (`vc`) and :21 (`_vc` forwards to `vc`), enemy_boss_craft.gd:18, experimental_setpiece_craft.gd:358, hero_kitbash_sculptor.gd:173, pilot_gear_kit.gd:141 and world23_chunk_craft.gd:685. Each returns `Color(clamp(wear), clamp(grime), clamp(emissive), 1.0)`, which is the R/G/B/A contract that `CraftLookdev.encode_mask` (craft/craft_lookdev.gd:87) and `HeroKitbashSculptor.VERTEX_COLOR_CONTRACT` already state. `git grep -n 'encode_mask' -- src tools tests` finds its only callers in tests/craft_lookdev_shader_test.gd and tools/craft_lookdev_capture.gd. No game code calls the owner. In-file use counts: enemy 117, camp 48, hero_kitbash 16, experimental 13, world23 12.
- fix: Make `CraftLookdev.encode_mask` the one public mask call. Point each `_vc` body at it, or replace its call sites, one file per PR.
- files to change: the 6 files above (one per PR); craft_lookdev.gd only if the default `emissive := 0.0` needs adding.
- size: S each (a 3-line body change per file; replacing call sites is M).
- risk: low
- behaviour-preserving: yes, provided encode_mask clamps the same way (it does: clamp 0–1 and alpha 1.0). Check pilot_gear_kit's `emit` parameter name.
- tests that cover it: tests/craft_lookdev_shader_test.gd, step5_enemy_boss_craft_test.gd, slice4_camp_and_w1116_test.gd, slice3_highdraft_mind_perf_test.gd, step5_smelter_setpiece_craft_test.gd, hero_asset_sculptor_test.gd
- guard: a lint rule that fails on `func _?vc(` outside craft_lookdev.gd.

### VM-02 Ten separate bevel-box builders, and three byte-identical `_uv_for` / `_add_tri` copies
- kind: A (also G: same primitive, different colour placement)
- evidence:
  - `git grep -nE 'func _?(add_)?(bevel(ed)?_box|_?bevel_box_masked|chamfered_box|append_chamfered_box|add_chamfered_plate)\(' -- src tools` finds 9 hits. They are craft_prop_meshes.gd:88 and :789, enemy_boss_craft.gd:134, camp_craft_meshes.gd:25 and :74, crafted_ball_gear.gd:345, pilot_gear_kit.gd:153, recipe_props.gd:137 (Plane-based), hero_kitbash_sculptor.gd:185 and tools/craft_lookdev_capture.gd:334.
  - vista_megastructures.gd:535 `_append_box` and combat/dispatcher.gd:152 `_append_box` bring the total to 10 or more.
  - `git grep -nE '^static func _uv_for\(' -- src` finds 3 hits, byte-identical by `diff`: craft_prop_meshes.gd:58, enemy_boss_craft.gd:48 and camp_craft_meshes.gd:29.
  - `_add_tri` in enemy_boss_craft.gd:57 and camp_craft_meshes.gd:38 has identical bodies, including the degenerate skip `cross.length_squared() < 1e-12`. craft_prop_meshes.gd:67 has no skip, and its :767 `_add_tri_col` is a single-colour variant.
  - Cylinders and rings: craft_prop_meshes `_bevel_cyl` :147 (69 uses) and `_bevel_ring` :196 (49); enemy `_bevel_cyl` :196 and `_bevel_ring` :247 differ only in colour arguments; crafted_ball_gear `add_cylinder` :406.
- fix: Name `HeroKitbashSculptor` (the `KitbashCanvas` plus its public parts) as the single owner of SurfaceTool primitives. Order:
  1. Move the identical `_uv_for` / `_add_tri` into it as public statics.
  2. Point enemy and camp at them.
  3. Give it a coloured `bevel_box(st, center, size, bevel, uv_scale, xf, c_flat, c_edge, c_bot)` that the enemy and camp bodies call.
  4. Leave craft_prop_meshes' uncoloured set and recipe_props' Plane hulls for last, since their vertex output differs.
- files to change: craft/hero_kitbash_sculptor.gd, craft/enemy_boss_craft.gd, craft/camp_craft_meshes.gd (first PR); craft_prop_meshes.gd, crafted_ball_gear.gd, pilot_gear_kit.gd, vista_megastructures.gd (later PRs, one each).
- size: S for `_uv_for` / `_add_tri`; M per bevel-box merge.
- risk: medium (vertex order, the degenerate skip and colour placement differ, so a careless merge changes meshes and mesh-hash pins)
- behaviour-preserving: yes for the byte-identical helpers; unsure for the bevel family until each body is compared vertex by vertex.
- tests that cover it: step5_enemy_boss_craft_test.gd, slice4_camp_and_w1116_test.gd, hero_asset_sculptor_test.gd, craft_pipeline_integration_test.gd, greybox_eradication_test.gd, weapon_ball_craft_test.gd
- guard: a lint rule that fails on a new `func _uv_for(` or `func *bevel*box(` outside the owner file.

### VM-03 Presentation reads combat's and world's private members by string name
- kind: C
- evidence:
  - w50_asset_hooks.gd reaches into combat private state every frame. It reads `combat.get("actives")` and then `actives.get("_kinds")` (:366-367), where `_kinds` is private in combat/actives/active_rack.gd:27. From `combat.get("relic_swaps")` it reads `swaps.get("_augers")` (:408), `"_orbit_halo"` (:421), `"_halos"` (:437), `"_snares"` (:453) and `"_mortars"` (:467). All five are private vars in combat/relic_swaps.gd:97-106.
  - At :273-274 it calls `drop.get/set("_cartridge_node")`, the private member in build/consumables.gd:680.
  - park_props.gd calls world private statics: `ParkTerrain._read_zstd` (:201, defined at world/park/park_terrain.gd:637), `Terrain._park_ground_at` (:211, world/terrain.gd:786) and `EventDirector._park_ground` (:289, world/event_director.gd:548). It also reads `sites._cells` together with `ParkSites._cell` (:156, presentation/park_sites.gd:14 and :57).
  - Command: `git grep -noE '[A-Z][A-Za-z0-9]+\._[a-z][a-z_0-9]*' -- <slice files>` plus `git grep -nE '"_(kinds|augers|orbit_halo|halos|snares|mortars|cartridge_node)"' -- src` finds 8 string reach-ins.
- fix: Give each owner one public read and have w50 call that:
  - active_rack `kind(id)` or `buoys()`;
  - relic_swaps `world_props() -> Dictionary` (augers, orbit halo, halos, snares, mortars);
  - consumables drop `set_cartridge_model(node)`.
  For park_props, make `park_terrain.read_heights(dir)`, `terrain.park_ground_at` and `event_director.park_ground` public. One owner per PR.
- files to change: combat/actives/active_rack.gd, combat/relic_swaps.gd, build/consumables.gd, world/park/park_terrain.gd, world/terrain.gd, world/event_director.gd, presentation/park_sites.gd, plus the two callers.
- size: S per owner.
- risk: medium (w50's string reads fail silently. A renamed private var already makes w50 draw nothing and raise no error, so the public accessor must return the same arrays.)
- behaviour-preserving: yes, if each accessor returns the same object without copying it.
- tests that cover it: tests/w50_3d_assets_test.gd (its fake fixture at :259-269 supplies the private names, so it would need the accessor too), park_props_test.gd, active_*_test.gd.
- guard: extend the L6–L10 isolation lint to fail on `.get("_` and `.set("_` with a leading-underscore string in src/presentation.

### VM-04 22 hand-rolled glb loaders, each with its own cache and warning; only 13 calls go through `ModelVariants`
- kind: G (also A)
- evidence:
  - `git grep -nE 'load\([^)]*\) as PackedScene if ResourceLoader.exists' -- src` finds 21 hits. Plain `exists`-then-`load` variants add dig_scenery.gd:403 and :418 and spillway_scenery.gd:504 and :522.
  - Each site keeps its own cache: hero_assets `_scenes`, w50 `_packed_cache`, dig `_dir_cache`, world/model_kit `_kits`, work_machines `_scenes`, core/beacon `_packed_models`.
  - Each has its own fallback warning: "keeping primitive fallback", "stays on the greybox", "it stays out" (recipe_props.gd:77), "parts stay plain shapes".
  - `git grep -nE 'ModelVariants\.(path|only)\(' -- src` finds 13 hits. The variant switch (model_variants.gd:21) is skipped by recipe_props, dig_scenery, spillway, highdraft, w50, model_kit, work_machines, beacon, companion_body, ball_looks and title_stage, so `--models=tripo` swaps some props and not others.
- fix: Add one `ModelVariants.packed(path) -> PackedScene` (or a small `model_loader.gd` beside it) that applies `path()`, checks `exists`, caches the scene and warns once. Move one caller per PR.
- files to change: model_variants.gd, then each loader in turn (hero_assets, w50_asset_hooks, recipe_props, dig_scenery, spillway_scenery, highdraft_scenery, world/model_kit, work_machines, …).
- size: S for the owner; S per caller.
- risk: low for the cache and warning merge; medium for routing a caller through `path()`, because that adds tripo swaps under the flag (flag-only, off by default).
- behaviour-preserving: yes with the flag off (the default); no with `--models=tripo` for callers that bypass it today, which is the intent but is a visible change.
- tests that cover it: tripo_variants_test.gd, w50_3d_assets_test.gd, dig_scenery_test.gd, dress_arb_test.gd, test_batch_reset_test.gd (the reset of `_on`, `_rejected` and `_stamp`).
- guard: a lint rule that fails on `as PackedScene if ResourceLoader.exists` outside the owner.

### VM-05 experimental_setpiece_craft.gd is a fork of world23_chunk_craft.gd with drifted constants
- kind: A
- evidence:
  - Byte-identical by `diff` of the extracted bodies: `_dup_preset`, `_new_canvas`, `_vc`, `bind_surface_materials`, `_notification`, `_ready`.
  - Near-copies with drifted numbers:
    - `_add_flat_deck_slab` (87 lines each): edge_grime 0.42 vs 0.40, center_grime 0.05 vs 0.04, edge_wear 0.12 vs 0.10.
    - `_add_clean_louver` (55 each): 0.88/0.86, 0.32/0.30, 0.72/0.68.
    - `_add_beveled_annulus` (72 vs 69 lines; experimental adds an `r_ramp_top` ring).
  - Same name but larger in world23: `get_material` (141 vs 229 lines).
- fix: Move the 6 identical helpers into one shared craft module (HeroKitbashSculptor or CraftLookdev for `bind_surface_materials`). Then give the three near-copies their differing constants as parameters, with each caller passing its current numbers.
- files to change: craft/experimental_setpiece_craft.gd, world23_chunk_craft.gd, craft/hero_kitbash_sculptor.gd or craft/craft_lookdev.gd
- size: M
- risk: low for the identical helpers; medium for the parametrised ones (a wrong default changes the mask colours)
- behaviour-preserving: yes if every caller passes its current constants.
- tests that cover it: step5_smelter_setpiece_craft_test.gd, slice3_highdraft_mind_perf_test.gd, craft_pipeline_integration_test.gd
- guard: none fits well; review discipline.

### VM-06 enemy_boss_craft's multi-slot `_cached` / `_slot_st` re-implements `KitbashCanvas`
- kind: A
- evidence: enemy_boss_craft.gd:22 `_cached(key, builder)` and :39 `_slot_st` hold one SurfaceTool per material slot and commit them in order. That is what `HeroKitbashSculptor.KitbashCanvas._tool_for` and `commit` do, except that the canvas also calls `st.index()`. craft_prop_meshes.gd:46 has a single-slot `_cached`, and recipe_props.gd:101 `piece()` is a third cache-then-commit helper.
- fix: Build enemy meshes on `KitbashCanvas`, or give the canvas a `cached(key, builder)` entry. Decide `st.index()` explicitly, because it changes vertex count.
- files to change: craft/enemy_boss_craft.gd, craft/hero_kitbash_sculptor.gd
- size: M
- risk: medium (indexing changes array layout; mesh-hash or vertex-count pins may move)
- behaviour-preserving: unsure, because of the indexing difference.
- tests that cover it: step5_enemy_boss_craft_test.gd, slice2_dig_waking_craft_test.gd
- guard: none.

### VM-07 The world23 material helper `enrich_standard_pbr` is the shared PBR owner by accident
- kind: C (wrong owner; also a lower-to-higher direction)
- evidence: `git grep -n 'enrich_standard_pbr\|make_weathered_pbr' -- src | grep -v world23` finds 6 hits outside its file: combat/deflector.gd:75 and :135, combat/kite_drone.gd:143, arena_mind_dress.gd:193 and :290, and highdraft_scenery.gd:1061. Each preloads a 1886-line chunk builder to tune one StandardMaterial3D (world23_chunk_craft.gd:267). Combat is a lower layer reaching into a presentation chunk builder.
- fix: Move `enrich_standard_pbr` and `make_weathered_pbr` into a material module (CraftLookdev, or next to `weathered_material` in one material owner). Leave a forwarder in world23 for one PR, then move the callers.
- files to change: world23_chunk_craft.gd, craft/craft_lookdev.gd, combat/deflector.gd, combat/kite_drone.gd, arena_mind_dress.gd, highdraft_scenery.gd
- size: S
- risk: low
- behaviour-preserving: yes (a pure function move)
- tests that cover it: highdraft_materials_test.gd, slice3_highdraft_mind_perf_test.gd
- guard: the L6–L10 isolation lint could fail on combat preloading `src/presentation/world23_chunk_craft.gd`.

### VM-08 Lower layers preload presentation mesh builders
- kind: C (wrong direction)
- evidence:
  - world/camp_hub.gd, camp_ring.gd and camp_trial.gd preload craft/camp_craft_meshes.gd (`git grep -l camp_craft_meshes -- src/world` finds 3).
  - combat/stakes.gd and build/scrap_field.gd use craft_prop_meshes.gd.
  - boss/arena, boss, requisition and waking_dress use enemy_boss_craft.gd.
  - combat/dispatcher.gd:152 has its own `_append_box`, a mesh builder inside combat.
- fix: Per caller, move the mesh build into a presentation dresser that the world node calls through one hook, or accept boss/ as presentation-adjacent and record that. One module per PR.
- files to change: the world, combat and build callers named above.
- size: M each
- risk: medium (node creation order in `_ready` can move)
- behaviour-preserving: unsure until each caller's timing is read.
- tests that cover it: slice4_camp_and_w1116_test.gd, greybox_eradication_test.gd, step5_enemy_boss_craft_test.gd
- guard: an isolation lint rule against `src/world|src/combat|src/build` preloading `src/presentation/craft*`.

### VM-09 hero_assets flips a private flag on WeaponRigFx and calls a private BallLooks static
- kind: C
- evidence: hero_assets.gd:1424 `rig.get("_cutaway_dressed")` and :1429 `rig.set("_cutaway_dressed", true)`, where the var is private in weapon_rig_fx.gd:45 and reset at :241. hero_assets.gd:1427 calls `BallLooks._cut_kit(ring_mount, "")`.
- fix: Move the cutaway dress into `WeaponRigFx.dress_cutaway(plated: bool)` so the rig owns its flag and the reset, and make `BallLooks.cut_kit` public.
- files to change: weapon_rig_fx.gd, hero_assets.gd, ball_looks.gd
- size: S
- risk: low
- behaviour-preserving: yes
- tests that cover it: ball_looks_test.gd, and the hero_assets tests that build the ring
- guard: the same `.get("_` / `.set("_` lint as VM-03.

### VM-10 Four copies of the glb-to-MeshInstance extraction loop
- kind: A
- evidence: the loop `instantiate`, `find_children("*", "MeshInstance3D")`, copy mesh, rebuild surface materials, accumulate the relative transform, then free appears in recipe_props.gd:73-95 `_place` (with `_relative` :179), world/model_kit.gd `_meshes`, dig_scenery.gd `_parts` and highdraft_scenery.gd `_scene`.
- fix: One `extract_meshes(packed, material_for: Callable) -> Array` in the model loader from VM-04, with recipe_props' `_relative` as the transform walk.
- files to change: recipe_props.gd, world/model_kit.gd, dig_scenery.gd, highdraft_scenery.gd
- size: M
- risk: low
- behaviour-preserving: yes if each caller passes its own material mapping and node naming.
- tests that cover it: dig_scenery_test.gd, dress_arb_test.gd, highdraft_materials_test.gd, cog_ui_test.gd
- guard: none.

### VM-11 Six material factories with overlapping jobs
- kind: G
- evidence: `git grep -n 'func weathered_material\|func salvage_wear_material\|func craft_shader_material\|func make_weathered_pbr\|func enrich_standard_pbr\|func preset_material' -- src` finds 6 hits. They are craft_prop_meshes.gd:19 and :739, enemy_boss_craft.gd:315, world23_chunk_craft.gd:240 and :267, and craft_lookdev.gd:102. Also: hero_assets.gd:251 `material(slot, tint)`, recipe_props.gd:20 `slot_material`, dig_scenery.gd:383 `_slot_material`, spillway_scenery.gd:71 `_prop_material` and `_prop_shader`, camp `sandstone_material` / `berm_material` / `iron_material`, and model_kit's ROUGH table. enemy's `craft_shader_material` duplicates `CraftLookdev.preset_material` and then sets the base parameters.
- fix: Start with enemy `craft_shader_material`, which should call `CraftLookdev.preset_material(preset_id)` and set the parameters. Then fold `enrich_standard_pbr` (VM-07). Keep MaterialSlots as the owner of slot rows; recipe_props and dig both read it already.
- files to change: craft/enemy_boss_craft.gd, craft/craft_lookdev.gd, later craft_prop_meshes.gd
- size: M
- risk: medium (material cache keys and shader-parameter defaults)
- behaviour-preserving: unsure until each parameter set is compared.
- tests that cover it: craft_lookdev_shader_test.gd, step5_enemy_boss_craft_test.gd
- guard: none.

### VM-12 camp_craft_meshes has two private forwarders to its own public calls
- kind: D
- evidence: camp_craft_meshes.gd:21 `_vc` only returns `vc(...)` (:17); :25 `_add_bevel_box` only calls `add_bevel_box` (:74). The public pair is used by experimental/live_run_bridge.gd:549-581 and live_world_actors.gd:1095, :1117 and :1122.
- fix: Rename the in-file calls to the public names and delete the two forwarders, or remove both under VM-01 and VM-02.
- files to change: craft/camp_craft_meshes.gd
- size: S
- risk: low
- behaviour-preserving: yes
- tests that cover it: slice4_camp_and_w1116_test.gd
- guard: none.

### VM-13 `_bolt_ring` exists twice with drifted constants
- kind: A
- evidence: craft_prop_meshes.gd:240 (`bolt_r * 0.88`, uv 1.0) and enemy_boss_craft.gd:292 (`bolt_r * 0.86`, uv 1.2, with `_vc` colours).
- fix: One coloured `bolt_ring` in the primitive owner (VM-02) with the shoulder factor and uv as parameters.
- files to change: craft_prop_meshes.gd, craft/enemy_boss_craft.gd, craft/hero_kitbash_sculptor.gd
- size: S
- risk: low
- behaviour-preserving: yes if each caller passes its factor.
- tests that cover it: step5_enemy_boss_craft_test.gd, slice1_patch_and_w1_craft_test.gd
- guard: none.

### VM-14 spillway_scenery calls craft_prop_meshes' private primitives
- kind: C
- evidence: spillway_scenery.gd:706 `PropMeshes._bevel_box(...)` and :714 `PropMeshes._bevel_cyl(...)` (`git grep -nE 'PropMeshes\._' -- src | grep -v craft_prop_meshes.gd` finds 2 hits).
- fix: Covered by VM-02. Once the primitives are public on their owner, spillway calls those.
- files to change: spillway_scenery.gd
- size: S
- risk: low
- behaviour-preserving: yes
- tests that cover it: dam_asset_test.gd, dress_wog_test.gd
- guard: VM-02's lint.

### VM-15 Two more torus and faceted-orb builders
- kind: A
- evidence: world23_chunk_craft.gd:845 `_add_closed_torus` and :888 `_add_faceted_orb`, against crafted_ball_gear.gd:452 `add_torus` and :484 `add_faceted_orb`. `_add_lathe` appears in camp_craft_meshes.gd:125 and harpoon_physics_rig.gd:545.
- fix: Fold into the primitive owner after VM-02.
- files to change: world23_chunk_craft.gd, crafted_ball_gear.gd, craft/camp_craft_meshes.gd
- size: S each
- risk: low
- behaviour-preserving: unsure (segment counts and colour arguments need comparing)
- tests that cover it: weapon_ball_craft_test.gd, slice3_highdraft_mind_perf_test.gd
- guard: none.

### VM-16 hero_assets.gd is 3348 lines with clear seams
- kind: H
- evidence: `wc -l src/presentation/hero_assets.gd` gives 3348. Separable blocks:
  - warden dressing, which preloads combat/warden_look and warden_kit;
  - the weapon ring and cutaway at :1410-1432;
  - pilot reactions;
  - mast and shelter heroes;
  - the glb load and stand-in at :376-390 and `_loadable` at :1017.
  72 test files reference it.
- fix: Split the warden dressing into `warden_dress.gd` first (it owns the combat preloads), then the ring rig (after VM-09). Keep `hero_assets` as the façade callers already use.
- files to change: hero_assets.gd plus one new file per split
- size: L overall, M per split
- risk: medium (72 test files; static caches move)
- behaviour-preserving: yes if the façade forwards.
- tests that cover it: the 72 test files (`git grep -l hero_assets -- tests`)
- guard: none; a size budget would help.

## Not findings  (≤10 one-liners)
- Raw mask colour literals are not widespread. `Color(0.88, 0.12, 0.0`, `Color(0.10, 0.14, 0.0` and the like each appear in only 1 file, as default arguments; colours otherwise come from `Palette`.
- park_props.gd:1329 `_batch` (MultiMesh) and spillway_scenery.gd:606 `_batch` (a CPU mesh merge with a sandstone material) only share a name; they are different techniques.
- spillway_scenery.gd:331 preloads itself as `Scenery` inside a thread function. `Scenery._plan` and the like are self-calls, not reach-ins.
- The static `_mesh_cache` / `_mat_cache` with `reset_for_tests()` in each builder is covered by the L14 reset guard.
- `ModelVariants` itself is small and deep (54 lines, 3 static vars, all reset); the problem is only that callers bypass it (VM-04).
- recipe_props' Plane-hull `bevel_box` (:137) is a convex-hull technique, not a SurfaceTool primitive copy; keep it apart from VM-02.
- `"rusted-salvaged-plate-worn"` appears once per file in 10 files, as a look-texture key Palette owns; not a scattered fact.
- Collision shapes are not built in this slice (only work_machines.gd has 2 `*Shape3D.new`).
- craft_showcase_assembly.gd is used only by tools and the batch driver; it is a tool seam, not dead.

## Needs the owner
- VM-02 and VM-06: which module is the single owner of SurfaceTool primitives? I recommend HeroKitbashSculptor/KitbashCanvas, but it is named "hero". A neutral `craft_primitives.gd` may read better. Should merged meshes adopt the canvas's `st.index()` (a vertex-count change) or keep unindexed output?
- VM-04: should every glb caller honour `--models=tripo`? Routing today's bypassing callers through `ModelVariants.path()` makes more props swap under the flag.
- VM-08: is `src/boss/` treated as presentation-adjacent (allowed to own mesh builders), or must boss meshes come in through a dresser like the world and combat callers?
- VM-03: the w50 test fixture (tests/w50_3d_assets_test.gd:259-269) fakes combat's private names. The accessor change has to update the fixture in the same PR. That is the owner's call on test shape.
