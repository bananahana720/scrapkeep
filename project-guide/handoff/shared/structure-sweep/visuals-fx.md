# Structure survey: visuals-fx
commit: 23e935514ef33e7eb58d50e21bd2a5f757f41fa9   model: Claude Opus 5.5 (claude-opus-5-5), high   files read: 101 listed and grepped, 34 read in part   date: 2026-11-27

All paths are under `sketches/core-loop/`. Line numbers are at the commit above.

## Module map
- src/presentation/player_fx.gd | 2116 | the player's sound words and their placement, dunk glow, heft aura, rim, overdrive, carve sparks, growth columns, boons, Rivet muzzle flashes and casings, the PauseGuard class | 69 vars: word pool, flash and casing pools, aura and rim meshes | fx_budget.gd, sound_twins.gd, presentation.gd (10 src files, 9 tests)
- src/presentation/vfx.gd | 1160 | hit, crit and kill effects: SPECS pools owned by "vfx", the BURSTS table and its CPU pools, sparkles, glyph rings and pips, the trail, the density governor, fusion signatures, edge flash | 40 vars: _fx/_burst/_sparkle/_glyph pools and round-robin indexes | presentation.gd, fx_budget.gd (3 src, 6 tests)
- src/presentation/grapple_rig.gd | 1135 | the pilot's grapple and mutation look | 45 vars incl. active_mutations, _mutation_override | presentation.gd (1 src, 2 tests)
- src/presentation/juice.gd | 1026 | camera shake, rumble, impact zoom, the hit-stop budget, pylon ghosts | 38 vars incl. _stops, hit_stop_log, hit_stop_sink | presentation.gd, sound_twins.gd (3 src, 10 tests)
- src/presentation/title_intro_player.gd | 890 | the title intro camera and staging | 26 vars: host, camera, environment | title_stage.gd
- src/presentation/pilot_gear_kit.gd | 856 | pilot gear mesh rows (static) | none | hero_assets.gd
- src/presentation/machine_fx.gd | 839 | what enemies and bosses throw off: SPECS pools owned by "machine", machine words (KRNK, EJECT), special cues, the FAMILY table | 30 vars: _fx pools, word pool, spawned | presentation.gd, sound_twins.gd (4 src, 5 tests)
- src/presentation/title_stage.gd | 759 | the title diorama: hero, posters, dressing | 33 vars | presentation.gd
- src/presentation/world_look.gd | 737 | per-world light, fog and sky | _park_fog | weather.gd, camp_hub.gd (13 src, 22 tests)
- src/presentation/reward_ceremony.gd | 708 | the reward ceremony steps, plus pausing the tree and holding the ball's velocity | 24 vars incl. _held_velocity | presentation.gd (2 src, 6 tests)
- src/presentation/flourish_player.gd | 678 | plays flourish rows (camera, lines, veil) | 19 vars, static reduced_motion | presentation.gd, edge_markers.gd
- src/presentation/set_dressing.gd | 674 | route dressing for a map | 25 vars | activities.gd, presentation.gd (5 src)
- src/presentation/companion_body.gd | 648 | the companion's body, paint and words | 30 vars | ending_sequence.gd, title_stage.gd
- src/presentation/harpoon_physics_rig.gd | 647 | harpoon meshes and their motion | 8 vars | line_view.gd
- src/presentation/highdraft_fx.gd | 631 | highdraft world effects: thermals, motes, streaks, one-off library pools | 43 vars incl. thermals | stage_beats.gd, class_preview.gd (7 src, 13 tests)
- src/presentation/line_view.gd | 617 | the grapple line drawing | 47 vars | presentation.gd, sound_twins.gd
- src/presentation/ally_husk_look.gd | 602 | ally husk mesh look (static) | none | ally_husk.gd
- src/presentation/weapon_rig_fx.gd | 547 | weapon mod nodes and spinners on the pilot | 16 vars | hero_assets.gd
- src/presentation/arena_waking_dress.gd | 546 | the Waking boss arena dressing | 14 vars | boss/waking.gd
- src/presentation/deck_fx.gd | 545 | deck move effects | 4 vars (caches) | deck_moves.gd
- src/presentation/charge_halo.gd | 524 | Sable's charge halo, sparks and release rings | 20 vars, own GPUParticles3D | player_fx.gd, fx_budget.gd
- src/presentation/mecha_motion.gd | 523 | pilot mecha motion clips | 16 vars | hero_assets.gd (1 src, 10 tests)
- src/presentation/dig_fx.gd | 495 | dig world effects: lamps and one-off library pools | 32 vars | stage_beats.gd, dig_scenery.gd
- src/presentation/fx_library.gd | 479 | about 30 particle SPECS rows with an owner field, particle shader source (six looks), heat, colours, `build`/`fire`/`burst` | static _shaders, _meshes caches | 27 src files; 112 `FxLibrary.burst` call sites, mostly combat
- src/presentation/world_fx/world_fx.gd | 456 | world ambient air, overlays, hook bursts, the Spillway wake and its sound | static current, preferred; ambient/overlay/wake arrays, _bursts pools | fx_budget.gd, weather.gd (6 src)
- src/presentation/ink_outline.gd | 448 | ink outline shader and per-mesh inks | static _shaders, _inks | weapon_rig_fx.gd, w50_asset_hooks.gd (8 src)
- src/presentation/enemy_motion.gd | 448 | enemy idle and death motion, attack clock, the reduced-motion `motion_scale` static | static motion_scale, headless_idle, tag caches | 18 src files, 22 tests; 30 `EnemyMotion.motion_scale` reads in combat, world and boss
- src/presentation/ball_looks.gd | 447 | ball plating shaders | static shader caches | ink_outline.gd, hero_assets.gd
- src/presentation/flourish_cues.gd | 442 | picks flourish rows for a fight and the victory plan | 12 vars | presentation.gd
- src/presentation/arena_mind_dress.gd | 439 | the Mind boss arena sky and panorama | 7 vars | bake_warm.gd, boss/mind.gd
- src/presentation/pilot_liveliness.gd | 428 | pilot skeleton liveliness (SkeletonModifier3D) | 25 vars | pilot_glance.gd
- src/presentation/cosmetic_presentation.gd | 424 | cosmetic pick looks | 19 vars | customize_page.gd, hero_assets.gd
- src/presentation/graphics_preset.gd | 418 | the graphics preset and dressing hosts | static current, _worlds, _scenery | world_look.gd, world_fx_kit.gd (20 src, 30 tests)
- src/presentation/codex_banner.gd | 408 | the codex banner cards | 28 vars | presentation.gd, codex_style.gd
- src/presentation/world_fx/world_fx_specs.gd | 406 | world_fx SPECS, HOOKS and its own KIT colour table | none (const) | fx_budget.gd, world_fx_sound.gd (7 src)
- src/presentation/pilot_antics.gd | 405 | pilot idle antics | 17 vars, static reduced_motion | class_preview.gd, title_stage.gd
- src/presentation/presentation.gd | 402 | builds and wires the presentation children | 33 vars: ctx, audio, juice and the rest | game.gd, sound_twins.gd

## Outward dependencies
Preloads from slice files, counted by `res://src/<dir>/` occurrences.
- src/core | 87 | palette.gd (47), event_kinds.gd (18). Higher to lower: fine.
- src/combat | 48 | threat_grammar.gd (5), roster.gd (3). Higher to lower: fine.
- src/ui | 24 | ui_tokens.gd (5), ui_fonts.gd (4); juice.gd also preloads ui/settings_store.gd for REDUCED_FLASH. Sideways, between two higher layers.
- src/build | 16 | parts.gd (6), reward_gates.gd (3). Higher to lower.
- src/world | 13 | interactables.gd (2), director.gd (2). Higher to lower.
- src/movement | 13 | tuning.gd (6), augments.gd (4). Higher to lower.
- src/boss | 10 | arena.gd (3), mind_attacks.gd (2). Higher to lower.
- **Lower to higher (inbound, wrong direction).** 91 lower-layer files preload `src/presentation/`: combat 39, world 33, boss 9, core 6, build 4. The top paths are flash_guard.gd (22), fx_library.gd (19), craft_prop_meshes.gd (13), craft/enemy_boss_craft.gd (12), recipe_props.gd (9) and enemy_motion.gd (9). Core's six include beacon.gd (material_slots, recipe_props) and content_registry.gd (music_rows, windup_rows, phase_music). Only flash_guard, fx_library and enemy_motion are inside this slice.

## Findings

### VF-01 Seven separate ways to spawn, pool, time and free a particle effect, with no single owner
- kind: A, G
- evidence: (1) `FxLibrary.burst` (fx_library.gd) is unpooled. Each call runs `build()`, then `add_child`, then `create_timer(lifetime+0.15)`, then `queue_free` through a weakref. It has 112 call sites. (2) SPECS rows filtered by owner and pooled round-robin, in vfx.gd `_build_fx` 949–963 / `_fire_fx` 975 and again in machine_fx.gd `setup` 139–149 / `fire` 217. (3) vfx.gd's own `BURSTS` table, with hand-built CPUParticles3D pools in `_build_bursts` 882 and `burst` 932, and its own `burst_ceiling` 1090. (4) vfx.gd `_make_sparkle` 713, a third hand-built pool (SPARKLE_POOL 6, StandardMaterial3D). (5) One-off `FxLibrary.build` calls kept by their module: dig_fx.gd 69/238/317 and highdraft_fx.gd 125/308. (6) player_fx.gd building ParticleProcessMaterials by hand, `_emitter` 1582 to `_boon_material` 1715, outside SPECS. (7) world_fx: its own SPECS/HOOKS table, its own particle shader (world_fx_kit.gd `_SHADER`), `Kit.build`, and its own pool (`_burst` 297, BURST_POOL 2 per id). charge_halo.gd adds one more emitter. fx_budget.gd's ROWS table needs 19 rows across 9 owner files just to add up the ceilings.
- fix: Make fx_library the single owner of spawning. Add one `FxLibrary.pool(owner_or_ids, size) -> Pool` with `fire(at, tint, toward)`, round-robin inside, and one free/lifetime policy. Move vfx `_build_fx`/`_fire_fx`, machine_fx setup/fire and world_fx `_burst` onto it first. Fold BURSTS, sparkles and the player_fx materials into SPECS rows in later steps. Keep `burst()` as the unpooled one-shot.
- files to change: fx_library.gd, vfx.gd, machine_fx.gd, world_fx/world_fx.gd, then player_fx.gd, dig_fx.gd, highdraft_fx.gd, fx_budget.gd
- size: L as a whole; the first step (VF-02) is S
- risk: medium. Pool size, round-robin order and emitter build order must not change, or capture stills will differ.
- behaviour-preserving: yes, if each pool keeps its size and order
- tests that cover it: fx_library_test, fx_budget_test, machine_fx_test, kill_look_test, combat_juice_elevation_test, world_fx_test, spillway_fx_test, lens_fade_test
- guard: a lint rule that bans `GPUParticles3D.new()`/`CPUParticles3D.new()` outside fx_library.gd and world_fx_kit.gd. Six files have one today.

### VF-02 vfx.gd and machine_fx.gd each carry a copy of the owner-pool code
- kind: A
- evidence: vfx.gd `_build_fx` 949–963 loops `FxLibrary.SPECS`, keeps rows whose owner is "vfx", calls `FxLibrary.build`, `add_child`, and keeps `_fx_next`. `_fire_fx` 975 round-robins and calls `FxLibrary.fire`. machine_fx.gd `setup` 139–149 and `fire` 217 do the same for owner "machine".
- fix: `FxLibrary.pools(parent, owner) -> Dictionary` and `FxLibrary.fire_pooled(pools, id, ...)`, or the Pool object from VF-01. Each caller then makes one call.
- files to change: fx_library.gd, vfx.gd, machine_fx.gd
- size: S
- risk: low
- behaviour-preserving: yes
- tests that cover it: fx_library_test, machine_fx_test, kill_look_test, fx_budget_test
- guard: none needed once the copy is gone

### VF-03 flash_guard.gd is a game-wide comfort fact that sits in presentation; 22 lower-layer files preload it
- kind: C
- evidence: `git grep -l 'presentation/flash_guard.gd'` finds src/combat 11, src/world 6, src/boss 3, src/build 2, game.gd 1, ui 4, presentation 24, plus about 20 tests and 5 tools. The file is pure math with no dependencies: the ALPHA/INFO/SPIKE/WHITE shares, `static var on`, and `alpha`/`info`/`spike`/`whiten`/`blink`/`period`/`rate`. Combat and boss also branch on `FlashGuard.on` with their own literals instead of a helper: boss/requisition.gd:546 (0.75), :564 (0.45), combat/bolts.gd:573 (0.45).
- fix: move it to `src/core/flash_guard.gd` and rewrite the preload paths. Then add `FlashGuard.dim(x, share)` or name the 0.45 and 0.75 shares, so callers stop branching on `on`. Pair this with VF-04.
- files to change: about 65 preload lines (src, tests, tools), plus requisition.gd and bolts.gd for the literals
- size: M (mechanical)
- risk: low. It is a path move. The literal step must keep the exact values.
- behaviour-preserving: yes
- tests that cover it: active_flashes_test, combat_juice_elevation_test, presentation_comfort_test and 16 other tests that name flash_guard
- guard: extend sketch:lint so that core, combat, build, boss, world and movement may not preload `res://src/presentation/` except from an allow-list that shrinks over time (today 91 files)

### VF-04 The reduced-motion setting is copied into 14 static variables
- kind: F, E
- evidence: game.gd `set_motion_statics` (about line 1064) writes `EnemyMotion.motion_scale`, `HighdraftFx.preferred`, `WorldFx.preferred` (which forwards to `world_fx_kit.reduced_motion`), `PilotAntics`, `flourish_player`, `UiTokens`, `AbilityBar`, `AimReticle`, `RewardView`, `MossBubble`, `caller_tile`, `ClassCard`, `ClassPreview` and `BossPlate.reduced_motion`. `set_reduced_motion` then also pushes the flag to juice, player_fx and camera instances. Readers mix the copies: boss/requisition.gd:227 reads both `UiTokens.reduced_motion` and `EnemyMotion.motion_scale`. 28 src files read `EnemyMotion.motion_scale`, which makes a presentation static the game-rule layer's motion switch. Each static also needs its own L14 reset.
- fix: put one comfort module in core, holding `reduced_motion` and the flash switch from VF-03, and have every reader read it. `motion_scale` becomes a getter. game.gd then writes the setting in one place.
- files to change: a new core comfort file (or flash_guard.gd grown into it), game.gd, the 14 owners above, about 30 readers, tools/test_batch_driver.gd `_reset()`
- size: M
- risk: low to medium. A missed reader would silently stop following the setting.
- behaviour-preserving: yes
- tests that cover it: presentation_comfort_test, test_batch_reset_test, world_fx_test, pilot_antics_test
- guard: a lint rule that bans a new `static var reduced_motion`

### VF-05 Three Label3D "word" systems, each with its own recipe, lifetime and budget
- kind: A, G
- evidence: player_fx.gd has `_make_word` 566, `word_label` 573 (node "SoundWord", font 96, billboard DISABLED, no_depth_test, RENDER_PRIORITY), `word` 657 and `_draw_word` 1004, with its own placement (`_pick_spot`, `_keep_rects`, `foe_rects`, `stack_rect`, `clear_of_lane`, `_in_safe_area`). machine_fx.gd has `_make_word` 283, `word_label` 290 (font 112, outline 30, billboard ENABLED, render_priority 20/19), `word` 312 with WORD_GAP, `_free_spot` and `_draw_word`. world_fx/world_fx_word.gd `stamp` 17 makes a third recipe (font 72, outline 22, pixel 0.0011, NotoSans-Bold), is unpooled, frees itself in `_process`, and keeps its own static `_live` and `_hushed`. fx_budget lists the first two as separate rows, `player_words` and `machine_words`.
- fix: one word module that owns the Label3D recipe (a style row for each caller), the pool, the lifetime and the shared room budget. player_fx keeps its placement policy and passes a rect. machine_fx and world_fx call `Words.say(style, text, at)`.
- files to change: a new presentation/words.gd, player_fx.gd, machine_fx.gd, world_fx/world_fx_word.gd, fx_budget.gd
- size: M
- risk: medium. Font size, outline, billboard mode and render priority must match each style exactly.
- behaviour-preserving: yes, if the style rows copy today's values
- tests that cover it: machine_fx_test, player_fx_brindle_test, damage_families_test, pilot_antics_test, world_fx_test, pick_card_clarity_test
- guard: a lint rule that bans `Label3D.new()` in the effect files

### VF-06 player_fx and machine_fx reach into each other through groups and duck typing
- kind: C
- evidence: player_fx.gd `candy_room` 610 walks MARKS_GROUP, finds the machine_fx node with `has_method("candy_alive")`, and adds `_machine.candy_alive()` to its count. machine_fx.gd uses `PlayerFx.PauseGuard`, `PlayerFx.MARKS_GROUP` and `PlayerFx.ROOM_GROUP` (PauseGuard is created at machine_fx.gd:153). PauseGuard is a class inside player_fx.gd (2108) with no tie to player effects.
- fix: once VF-05 lands, the shared word budget lives in the word module, so neither side looks the other up. Move PauseGuard to its own small file, or into the word module.
- files to change: player_fx.gd, machine_fx.gd (plus the VF-05 module)
- size: S after VF-05
- risk: low
- behaviour-preserving: yes
- tests that cover it: machine_fx_test, player_fx_brindle_test
- guard: none

### VF-07 "Hold play" has no owner; reward_ceremony and workshop each pause the tree and turn input off in their own way
- kind: G, C
- evidence: reward_ceremony.gd `_step_ceremony` 489 sets `get_tree().paused = true`. `_hold(on)` 556–581 pauses the tree, calls `game.set_menu_held`, writes `game.keyboard.enabled` (false, or `ctx.flow.in_play()`), saves `body.linear_velocity` and `ctx.player.state.velocity`, and restores them with `ctx.player.set_velocity_now`. ui/workshop.gd 160–172 and 325–348 do the same job differently: `tree.paused = pause or game.pause_toggled() or game.notes_held()`, keyboard.enabled and capture_mouse. game.gd `set_menu_held` (1226) only sets a meta, and game.gd 805 and 816 write keyboard.enabled a third way. A presentation file writes the ball's velocity and input state.
- fix: one `game.hold_play(who, on)` (or a flow method) that owns pause, input, mouse capture and the velocity save and restore, counting holders. The ceremony and the workshop each call it.
- files to change: game.gd, presentation/reward_ceremony.gd, ui/workshop.gd
- size: M
- risk: medium. Pause and unpause order and the velocity restore must not change, so the signal order stays the same.
- behaviour-preserving: yes, if the writes keep their order
- tests that cover it: presentation_ceremony_test, find_in_fight_test, parts_shop_words_test, persistence_truncation_test
- guard: a lint rule that bans `get_tree().paused =` and `keyboard.enabled =` outside game.gd

### VF-08 juice.gd decides how long game time stops (the hit-stop budget lives in presentation)
- kind: C
- evidence: juice.gd `request_hit_stop` 921 filters by STRIKE_STOP_FACTS, caps the stop with SPINE_CAP_MS and stop_scale, spends `EventKinds.STOP_BUDGET_MS`/`STOP_WINDOW_BUDGET_MS`/`STOP_GAP_MS`, reads `ctx.flow.in_play()`, then calls `hit_stop_sink` (`ctx.hit_stop`, set at 132). The budget constants already live in core/event_kinds.gd. Only the spending logic sits in presentation.
- fix: move the budget (`_stops`, the filter, the log) into a core module next to `ctx.hit_stop`, and have juice call it with `(seconds, fact)`. Juice keeps shake and rumble.
- files to change: juice.gd, a core hit-stop owner (or game.gd's hit_stop), presentation.gd wiring
- size: M
- risk: medium. It is timing code, so it must move without changing a value.
- behaviour-preserving: yes (pure move)
- tests that cover it: presentation_hitstop_test, juice_budget_test, presentation_comfort_test, stand_crew_test
- guard: none

### VF-09 flourish_cues injects a callable that stretches the VICTORY state in core/flow
- kind: C
- evidence: flourish_cues.gd:54–55 sets `ctx.flow.victory_plan = plan_victory`. core/flow.gd:1027–1031 calls it and adds `plan.hold` to `_victory_left` and `victory_veil`. `plan_victory` 82 decides from flourish rows and `_earned_in_fight`. So a presentation module sets how long a game state lasts. No test names `victory_plan`.
- fix: see Needs the owner. Either flow asks a core-level rule for the hold (rows are data), or this is accepted as a deliberate presentation hook and gets a test.
- files to change: flourish_cues.gd, core/flow.gd
- size: S
- risk: medium (victory timing)
- behaviour-preserving: yes if moved as is
- tests that cover it: none by name (gap)
- guard: a test that pins hold and veil for one rout row

### VF-10 Two ink colours are written as literals in shaders and code instead of coming from Palette
- kind: E
- evidence: Palette.CHARCOAL is `Color("242a28")`, which is 0.141, 0.165, 0.157 to three places. It is written as a literal in fx_library.gd:177 (the `bead` look; the other looks use the `ink_colour` uniform), presentation/launch_take.gdshader:11, dev/dev_paint.gdshader:23 and dev/dev_print.gdshader:23. A second ink, 0.07, 0.07, 0.08, is player_fx.gd:26 `INK`, world_fx_kit.gd:17 `ink_colour` default and world/camp_hub.gd:1156.
- fix: the bead look uses the `ink_colour` uniform. Add `Palette.INK_DEEP := Color(0.07, 0.07, 0.08)` and read it in player_fx, camp_hub and world_fx_kit (set the uniform from it).
- files to change: fx_library.gd, player_fx.gd, world_fx/world_fx_kit.gd, world/camp_hub.gd, core/palette.gd (gdshader defaults can stay but should be set from Palette)
- size: S
- risk: low. 0.141 against 36/255 = 0.14118 is below one 8-bit step, but check a still.
- behaviour-preserving: yes, to below 1/255
- tests that cover it: fx_library_test, kill_look_test, fxd_side_read_test
- guard: the colour_meanings audit (core/colour_meanings.gd) could add an ink row

### VF-11 fx_budget.gd copies owner facts instead of reading them
- kind: E, A
- evidence: fx_budget.gd:54 `SPARKLE_MAX := 20` copies the literal in vfx.gd:747 `clampi(6 + amount * 2, 6, 20)`. `THERMAL_VIEWS := 2` (55) copies highdraft_fx.gd:161/244 `for kind in 2`. `BEAM_LAYERS := 2` (53) does the same for landmark_beam. Its "vfx_bursts" branch also recomputes the sum that `Vfx.burst_ceiling()` (vfx.gd:1090) already returns; combat_juice_elevation_test:191–193 checks both numbers.
- fix: owners name their constants (vfx `SPARKLE_MAX`, highdraft_fx `THERMAL_VIEWS`, landmark_beam `BEAM_LAYERS`), and the budget reads them through its existing `"const"` row form. The `vfx_bursts` branch calls `Vfx.burst_ceiling()`.
- files to change: fx_budget.gd, vfx.gd, highdraft_fx.gd, landmark_beam.gd
- size: S
- risk: low
- behaviour-preserving: yes
- tests that cover it: fx_budget_test, combat_juice_elevation_test
- guard: fx_budget_test could check that every row reads a const or a function, never a local copy

### VF-12 Ten public functions in the slice have no caller anywhere in the repo
- kind: B
- evidence: `git grep -wn <name>` over the whole repo (code, tests, tools, scripts and docs) finds only the definition, 1 hit each. I also checked string uses (`"valid_"`, `"use_"` and similar prefixes, has_method, call): none. The functions: grapple_rig.gd:314 `clear_mutation_override`, :325 `mutation_for`; reward_ceremony.gd:583 `held_velocity`; charge_halo.gd:248 `hoop_alpha`; world_fx/world_fx.gd:283 `live_ceiling` (fx_budget computes hook_bursts by itself); line_view.gd:285 `projected_px`; title_stage.gd:627 `use_poster`; enemy_motion.gd:263 `valid_idle`, :269 `valid_death`; companion_body.gd:503 `words_shown`.
- fix: delete them, or have a test call them if they were meant as test probes. `valid_idle` and `valid_death` look like schema checks that a test of the motion rows should call.
- files to change: the 7 files named
- size: S
- risk: low
- behaviour-preserving: yes
- tests that cover it: none (that is the point)
- guard: none

### VF-13 machine_fx's special-cue functions are forwarders to SpecialCues
- kind: D
- evidence: machine_fx.gd:190 `special_of(enemy)` returns `SpecialCues.special_of(enemy)`; it is used only inside machine_fx (433, 514, 630). machine_fx.gd:193 `special_sound` returns `SpecialCues.sound`; it is used at 654 and in tests/machine_fx_test.gd:98 and 112. Deletion test: removing both and calling SpecialCues loses nothing.
- fix: call `SpecialCues` directly, and have the test read SpecialCues.
- files to change: machine_fx.gd, tests/machine_fx_test.gd
- size: S
- risk: low
- behaviour-preserving: yes
- tests that cover it: machine_fx_test
- guard: none

### VF-14 player_fx.gd (2116 lines) holds five separate jobs
- kind: H
- evidence: the function outline shows clear seams: dunk glow 222–330; sound words, their placement and the screen-rect maths 566–1143 (about 580 lines); the `ImpactFrame` inner class 1144–1348; heft aura, rim, overdrive and carve 1349–1568; particle materials 1569–1728; Rivet weapon fire and casings 1793–2084; `PauseGuard` 2108.
- fix: split along these seams. The words block goes into the VF-05 word module, ImpactFrame and the particle materials into their own files, and Rivet fire next to weapon_rig_fx.gd. Each new file keeps one setup call from player_fx.
- files to change: player_fx.gd, plus new files
- size: L
- risk: medium. The `_process` order must stay the same.
- behaviour-preserving: yes
- tests that cover it: player_fx_brindle_test, damage_families_test, fx_budget_test, kill_look_test
- guard: none

### VF-15 vfx.gd (1160 lines) mixes four pools, a governor and rule tables
- kind: H
- evidence: it holds the SPECS pools (949–975), BURSTS (882–945), sparkles (713–760), the glyph pool and PopGate, the trail, the density governor (`_govern` 1065, `Density.publish_fill_scale`), FUSION_SIGNATURES and edge_flash. It preloads movement/speed_tier, movement/augments, world/interactables, combat/threat_grammar and build/synergies.
- fix: after VF-01 the pools leave. Glyphs and PopGate go to their own file, and the governor goes next to fx_budget.
- files to change: vfx.gd, plus new files
- size: M
- risk: low to medium
- behaviour-preserving: yes
- tests that cover it: kill_look_test, lens_fade_test, combat_juice_elevation_test, fx_budget_test
- guard: none

### VF-16 Shader parameter names are bare strings in 10 files, across two separate particle shaders
- kind: E
- evidence: `set_instance_shader_parameter("tint", ...)` appears in charge_halo, dig_fx, fx_library, machine_fx, player_fx, vfx, world_fx, world_fx_anchor, world_fx_grain and world_fx_kit. The two particle shaders each declare `tint` and an ink uniform of their own: fx_library's `ink_colour` set from Palette, and world_fx_kit `ink_colour` with a 0.07 default (see VF-10). `heat` goes through `FxLibrary.set_heat` and HEAT_GROUP, which is fine.
- fix: `FxLibrary.TINT := &"tint"` (and `INK`), used by every caller. Longer term, the two shader sources share one header.
- files to change: the 10 files
- size: S
- risk: low
- behaviour-preserving: yes
- tests that cover it: fx_library_test, world_fx_grain_test
- guard: none

### VF-17 fx_library.gd (the spawn owner) is preloaded by 18 combat, boss and world files for `burst`
- kind: C
- evidence: 13 combat files (boom_tender 12 calls, dispatcher 9, netcaster 8, swatter 7, ramp_flipper 6, mag_trapper 6, plated_brute 5, jolt_layer 5, foreman 5, hooker 4, lobber 3, chaser 3, warden_reactor 2), boss/boss.gd 4, and world camp_hub 2, contraptions 3, cracked_cache 2, events/industrial 4. core/colour_meanings.gd:95 names the path as a string. `FxLibrary.effects(kind, variant)` already maps an event kind to effects through `EventKinds.juice`.
- fix: see Needs the owner. Either combat emits an event kind on ctx.events and presentation fires the effect (the `EventKinds.juice` route that exists), or `burst` moves behind a small core port. Do not move the shader code into core.
- files to change: 18 lower-layer files and fx_library.gd
- size: L
- risk: medium. Moving to events changes when an effect spawns within a frame.
- behaviour-preserving: only the port option is strictly preserving
- tests that cover it: fx_library_test, fxd_side_read_test, kill_look_test
- guard: the VF-03 lower-to-higher allow-list

## Not findings
- companion_body.gd:114 `seat_for_capture` writes `ctx.run.companion`, but only tests call it (companion_body_test:161 and three more). It is a named test seam.
- bake_warm.gd:241 `enemy.position = Vector3.ZERO` places a warm-up copy inside its own hidden holder, not a live enemy.
- pilot_liveliness.gd:68 and :73 `set("pilot_class", ...)` set a field on its own script instance made with `load().new()`, so it does not reach into another module.
- juice.gd:131 `player.builtin_squash = false` turns off a look flag at setup; it is not game state.
- vfx.gd preloading movement, world, combat and build rule tables is higher to lower and fine.
- world_fx `static var current` and the `world_fx_word` statics reset for tests (test_batch_reset_test names world_fx_word).
- `heat` goes through `FxLibrary.set_heat` and one group (`&"fx_heat"`); it has one owner already.
- machine_fx `family_of` and `family_of_kind` read a real FAMILY table, so they are not forwarders.
- flourish_player.gd:226 reads `Engine.time_scale` and does not write it.

## Needs the owner
- VF-17 / VF-03: should combat and world spawn effects through events (`EventKinds.juice`), which can shift spawn timing within a frame, or through a core port that keeps today's timing? Should flash_guard and the comfort statics move to src/core?
- VF-09: is presentation (flourish rows) meant to stretch VICTORY, or should flow own that hold?
- VF-12: delete the ten uncalled functions, or keep `valid_idle`/`valid_death` as schema checks and give them a test?
- VF-07: should the reward ceremony keep pausing the whole tree, or hold play the same way the workshop does (pause toggled, notes held)?
