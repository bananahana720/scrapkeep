extends SceneTree

const Driver := preload("res://tools/test_batch_driver.gd")
const Game := preload("res://src/game.gd")
const Comfort := preload("res://src/core/comfort.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const WorldFxWord := preload("res://src/presentation/world_fx/world_fx_word.gd")
const WorldFxGrain := preload("res://src/presentation/world_fx/world_fx_grain.gd")
const WorldFxSound := preload("res://src/presentation/world_fx/world_fx_sound.gd")
const WorldFxAnchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Density := preload("res://src/presentation/density.gd")
const PickQuiet := preload("res://src/ui/pick_quiet.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const WarningBound := preload("res://src/combat/warning_bound.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const ArenaWakingDress := preload("res://src/presentation/arena_waking_dress.gd")
const DigFx := preload("res://src/presentation/dig_fx.gd")
const ArenaBowlDress := preload("res://src/presentation/arena_bowl_dress.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const CampCraftMeshes := preload("res://src/presentation/craft/camp_craft_meshes.gd")
const WakingDress := preload("res://src/boss/waking_dress.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const MindHand := preload("res://src/combat/mind_hand.gd")
const SpillwayScenery := preload("res://src/presentation/spillway_scenery.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const MechaMotion := preload("res://src/presentation/mecha_motion.gd")
const ThreadGuard := preload("res://src/core/thread_guard.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Glyphs := preload("res://src/core/glyphs.gd")
const SettingsPages := preload("res://src/ui/settings_pages.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const EnemyClips := preload("res://src/presentation/enemy_clips.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Palette := preload("res://src/core/palette.gd")
const Synth := preload("res://src/presentation/synth.gd")
const Footings := preload("res://src/world/park/footings.gd")
const RescueSite := preload("res://src/world/rescue_site.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const HazardHits := preload("res://src/world/events/hazard_hits.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const StageMap := preload("res://src/world/stage_map.gd")
const Screens := preload("res://src/ui/screens.gd")
const ArenaMindDress := preload("res://src/presentation/arena_mind_dress.gd")
const HighdraftScenery := preload("res://src/presentation/highdraft_scenery.gd")
const Arena := preload("res://src/boss/arena.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const ModelVariants := preload("res://src/presentation/model_variants.gd")
const Audio := preload("res://src/presentation/audio.gd")
const InkOutline := preload("res://src/presentation/ink_outline.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const VoiceSynth := preload("res://src/presentation/voice_synth.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const BotProfile := preload("res://tools/bot_profile.gd")
const SkillBand := preload("res://tools/skill_band.gd")
const TraversalLine := preload("res://tools/traversal_line.gd")
const BotFairness := preload("res://tools/bot_fairness.gd")
const RampFlipper := preload("res://src/combat/ramp_flipper.gd")
const CosmeticArt := preload("res://tests/support/cosmetic_art.gd")
const TeardownNoise := preload("res://tests/support/teardown_noise.gd")
const ContentRegistry := preload("res://tests/support/content_registry.gd")
const T := preload("res://tests/support/t.gd")

# W46-T1: tools/test_batch_driver.gd _reset() clears reduced-motion and other process-wide
# statics between tests in a warm batch so no test leaks state into a later test.

var _recording_order := false
var _order_events: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _physics_process(_delta: float) -> bool:
	if _recording_order and not _order_events.has("tree_physics"):
		_order_events.append("tree_physics")
	return false


func _process(_delta: float) -> bool:
	if _recording_order and not _order_events.has("tree_process"):
		_order_events.append("tree_process")
	return false


func _run() -> void:
	var t := T.new("test_batch_reset_test")
	var driver := Driver.new(self, [])

	# Game.set_motion_statics(true) sets the one reduced-motion owner, and the scale derived from it.
	Game.set_motion_statics(true)
	t.check("Game.set_motion_statics(true) sets Comfort", Comfort.reduced_motion and is_zero_approx(Comfort.motion_scale()))

	# Dirty other single-field process-wide statics that tests in the repo flip.
	FlashGuard.on = true
	GraphicsPreset.apply("low")
	SimClock.ticks = true
	Glyphs.device = "pad"
	SettingsPages.last_page = 2
	StageLocks.active = false
	Synergies.set_table(AlphaDefs)
	EnemyMotion.headless_idle = true
	EnemyClips.headless = true
	Enemy.rim_color = Color.RED
	WorldFxWord.quiet(true)
	var hushed_word := WorldFxWord.stamp(root, "QUIET", Vector3.ZERO)
	t.check("WorldFxWord.quiet(true) hides newly stamped words", not hushed_word.visible)
	Synth.score_step = Harmony.BOSS_STEP
	Synth.score_transpose = 3
	SfxBank._shift = 4
	SfxBank._theme = 2
	SfxBank.bake_cancel = true
	VoiceSynth.unknown_callers["probe_caller"] = true
	VoiceSynth.set_voice_sidecar(true, {"sable|probe": "res://missing.wav"})
	MusicEngine._park_tasks["probe"] = -1
	MusicEngine._park_warm["probe"] = PackedFloat32Array([0.1])
	Footings.plant_ignore_lines = true
	RescueSite.model_path = "res://assets/models/__missing_cage__.glb"
	MusicRows.stem_dir = "user://no_stems"

	# Dirty module-owned statics (W46-T2) and root viewport state.
	var start_size := root.size
	var start_scale_size := root.content_scale_size
	var start_aspect := root.content_scale_aspect
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	WorldFxGrain.run_seed = 4242
	WorldFxSound.audio = root
	Density.live().force(0.85)
	UiFonts.face(UiTokens.Hand.ROGUE, true)
	t.check("UiFonts holds a loaded face before reset", not UiFonts._faces.is_empty())
	Density.publish_fill_scale(0.45)
	var fake_hud := _FakeHud.new()
	PickQuiet.hush(_FakeHost.new(fake_hud))
	t.check("PickQuiet.hush marks hud quiet and raises holds", fake_hud.is_quiet and PickQuiet._total == 1)
	PartOffers.maker_nudge_on = false
	PartOffers.answer_nudge_on = false
	Parts.set_seams({"spawner.extend_cloak": true})
	Parts.set_opened_items({"strike_pocket": true})
	WarningBound.test_pad_scale = 0.0
	WarningBound.test_skip_hazard_merge = true
	DigScenery.stone_dir = "res://missing_stone/"
	DigScenery.mech_dir = "res://missing_mech/"
	DigScenery.cart_dir = "res://missing_cart/"
	ArenaWakingDress.stone_dir = "res://missing_stone/"
	ArenaWakingDress.mech_dir = "res://missing_mech/"
	DigFx.lamp_shader_path = "res://missing_lamp.gdshader"
	ArenaBowlDress.asset_dir = "res://missing_bowl/"
	ArenaBowlDress.spillway_dir = "res://missing_spillway/"
	Requisition.model_path = "res://missing_req.glb"
	Requisition.scooter_path = "res://missing_scooter.glb"
	WakingDress.base_path = "res://missing_waking.glb"
	WakingDress.kit_path = "res://missing_waking_kit.glb"
	MindDress.base_path = "res://missing_mind.glb"
	MindDress.kit_path = "res://missing_mind_kit.glb"
	MindHand.model_path = "res://missing_hand.glb"
	SpillwayScenery.prop_shader_path = "res://missing_prop.gdshader"
	PackPressure.lead_plant = "none"
	Cosmetics._test_pending = ["outfit_rivet_hood"]
	MechaMotion.echo = false
	ClassPreview._sitting_unlocks = {"tally": true}
	ThreadGuard.violations = 2
	ThreadGuard.last_violation = "planted"
	PlayerFx.rect_tests = 11
	ParkProps.file_overrides = {"a": "b"}
	ParkProps.far_reads = 5
	ParkProps._meshes["res://fake.glb"] = BoxMesh.new()
	ParkProps._far_sources["res://fake.glb"] = [1]
	ParkProps._cache_owner = "park_dam"
	ParkProps._stand_ins["fake"] = ["res://fake.glb"]
	ParkProps._stand_ins_stamp = 4
	Threat.set_look("classic")
	Threat.Painter._held_looks["plain"] = StandardMaterial3D.new()
	Threat.Painter._warmed = true
	Projectile._held_rim = StandardMaterial3D.new()
	# Dirty W46-T3 statics: world, screens, background-task caches, arena ahead builds, warnings and overrides.
	HazardHits.plants = ["skip_enemies"]
	ParkTerrain.draw_regions = false
	ParkTerrain.build_tasks = 1
	StageMap.surface_shader_path = "res://assets/materials/__missing_workshop__.gdshader"
	StageMap._surface_materials["fake"] = StandardMaterial3D.new()
	StageMap._surface_warnings["fake"] = true
	SimClock.threaded_in_bot_runs = true
	Screens._ready_announced = true
	ArenaMindDress.dir = "res://assets/models/__missing_mind__/"
	ArenaMindDress._sky_material = null
	ArenaMindDress.prepare()
	t.check("ArenaMindDress panorama worker started before reset", ArenaMindDress._panorama_task >= 0)
	ArenaMindDress._sky_material = ShaderMaterial.new()
	ArenaMindDress._kit_ahead["fake"] = BoxMesh.new()
	HighdraftScenery.dir = "res://assets/models/__missing_highdraft__/"
	HighdraftScenery._sky = PanoramaSkyMaterial.new()
	HighdraftScenery._warned["fake"] = true
	HighdraftScenery._coloured[12345] = StandardMaterial3D.new()
	HighdraftScenery._start_cloud()
	t.check("HighdraftScenery cloud bake task started before reset", HighdraftScenery._cloud_task >= 0)
	Arena._looks_warm = true
	var ahead_bowl := Arena.new()
	var ahead_bowl_id := ahead_bowl.get_instance_id()
	Arena._ahead_bowl = ahead_bowl
	var req_ahead := Node3D.new()
	var req_ahead_id := req_ahead.get_instance_id()
	Requisition._ahead["fake"] = req_ahead
	Requisition._ahead_reads["fake"] = null
	var bowl_reading_scene := Node3D.new()
	var bowl_reading_id := bowl_reading_scene.get_instance_id()
	ArenaBowlDress._ahead["fake"] = {}
	ArenaBowlDress._reading = {"path": "fake", "scene": bowl_reading_scene, "views": [], "result": {}, "ok": true}
	UpgradeTree.unknown_warned["probe_pilot"] = true
	Harmony.unknown_warned["probe_motif"] = true
	ScrapField.model_path = "res://assets/models/__missing_scrap__.glb"
	ScrapField._pickup_mesh_cache = [BoxMesh.new()]
	ScrapField._recovery_mesh_cache = [BoxMesh.new()]
	ScrapField._cog_model = BoxMesh.new()
	ScrapField._pickup_assets["fake"] = {}
	ScrapField._ground_plates["fake"] = BoxMesh.new()
	ModelVariants.set_enabled(true, true)
	ModelVariants.set_rejected({})
	var stray_node := Node3D.new()
	root.add_child(stray_node)
	var stray_tween := stray_node.create_tween()
	stray_tween.tween_property(stray_node, "position", Vector3.UP, 10.0)
	t.check("stray tween registered before reset", get_processed_tweens().size() >= 1)
	Palette.workshop_sky_later()
	t.check("Palette sky paint active or cached before reset", Palette._sky_task >= 0 or Palette._sky_texture != null)
	var test_dir := "user://test-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(test_dir)
	var marker_path := test_dir.path_join("leaked_profile.json")
	var marker := FileAccess.open(marker_path, FileAccess.WRITE)
	if marker != null:
		marker.store_string("{}")
		marker.close()
	t.check("leaked file written into user://test-<pid> before reset", FileAccess.file_exists(marker_path))

	driver._reset()

	t.eq("root.size resets to startup size", root.size, start_size)
	t.eq("root.content_scale_size resets to startup size", root.content_scale_size, start_scale_size)
	t.eq("root.content_scale_aspect resets to startup aspect", root.content_scale_aspect, start_aspect)
	t.eq("WorldFxGrain.run_seed resets to 0", WorldFxGrain.run_seed, 0)
	t.eq("WorldFxSound.audio resets to null", WorldFxSound.audio, null)
	t.check("WorldFxAnchor.live clears on reset", WorldFxAnchor.live.is_empty())
	t.check("Density governor resets value and hold", is_zero_approx(Density.live().value) and not Density.live().hold)
	t.near("Density.last_published resets to 1.0", Density.last_published, 1.0)
	t.check("UiFonts empties its loaded faces", UiFonts._faces.is_empty())
	t.check("GraphicsPreset clears tracked state and resets to high", GraphicsPreset.current == "high"
		and not GraphicsPreset._target_server_active and GraphicsPreset._lighting.is_empty()
		and GraphicsPreset._dressing_hosts.is_empty() and GraphicsPreset._worlds.is_empty())
	t.check("PickQuiet clears holds and restores hud", PickQuiet._holds.is_empty() and PickQuiet._total == 0 and not fake_hud.is_quiet)
	t.check("Parts resets nudges, seams and opened_items", PartOffers.maker_nudge_on and PartOffers.answer_nudge_on
		and Parts.seams.is_empty() and Parts.opened_items.is_empty())
	t.check("WarningBound resets test overrides", is_equal_approx(WarningBound.test_pad_scale, 1.0) and not WarningBound.test_skip_hazard_merge)
	t.check("DigScenery resets all three dirs", DigScenery.stone_dir == DigScenery.STONE_DIR
		and DigScenery.mech_dir == DigScenery.MECH_DIR and DigScenery.cart_dir == DigScenery.CART_DIR)
	t.check("ArenaWakingDress resets both dirs", ArenaWakingDress.stone_dir == ArenaWakingDress.STONE_DIR
		and ArenaWakingDress.mech_dir == ArenaWakingDress.MECH_DIR)
	t.eq("DigFx.lamp_shader_path resets to constant", DigFx.lamp_shader_path, DigFx.LAMP_SHADER_PATH)
	t.check("ArenaBowlDress resets both dirs", ArenaBowlDress.asset_dir == ArenaBowlDress.ASSET_DIR
		and ArenaBowlDress.spillway_dir == ArenaBowlDress.SPILLWAY_DIR)
	t.check("Requisition resets both paths", Requisition.model_path == Requisition.MODEL
		and Requisition.scooter_path == Requisition.SCOOTER_MODEL)
	t.check("WakingDress resets both paths", WakingDress.base_path == WakingDress.BASE
		and WakingDress.kit_path == WakingDress.KIT)
	t.check("MindDress resets both paths", MindDress.base_path == MindDress.BASE
		and MindDress.kit_path == MindDress.KIT)
	t.eq("MindHand.model_path resets to MODEL", MindHand.model_path, MindHand.MODEL)
	t.eq("SpillwayScenery.prop_shader_path resets to constant", SpillwayScenery.prop_shader_path, SpillwayScenery.PROP_SHADER_PATH)
	t.eq("PackPressure.lead_plant resets to empty", PackPressure.lead_plant, "")
	t.check("Cosmetics._test_pending clears on reset", Cosmetics._test_pending.is_empty())
	t.check("MechaMotion.echo resets to true", MechaMotion.echo)
	t.check("ClassPreview._sitting_unlocks clears on reset", ClassPreview._sitting_unlocks.is_empty())
	t.check("ThreadGuard resets violations", ThreadGuard.violations == 0 and ThreadGuard.last_violation == "")
	t.eq("PlayerFx.rect_tests resets to 0", PlayerFx.rect_tests, 0)
	t.check("ParkProps resets file_overrides and far_reads", ParkProps.file_overrides.is_empty() and ParkProps.far_reads == 0)
	t.check("ParkProps resets shared caches and stand_ins", ParkProps._meshes.is_empty() and ParkProps._far_sources.is_empty()
		and ParkProps._cache_owner == "" and ParkProps._stand_ins.is_empty() and ParkProps._stand_ins_stamp == -1)
	t.check("Threat resets look, held looks, materials and warmed", Threat.Painter._look == ""
		and Threat.Painter._held_looks.is_empty() and Threat.Painter._materials.is_empty()
		and Threat.Painter.materials_built == 0 and not Threat.Painter._warmed)
	t.eq("Projectile._held_rim resets to null", Projectile._held_rim, null)
	t.check("HazardHits.plants clears on reset", HazardHits.plants.is_empty())
	t.check("ParkTerrain resets draw_regions and build_tasks", ParkTerrain.draw_regions
		and ParkTerrain.build_tasks == maxi(1, OS.get_processor_count() / 2))
	t.check("StageMap resets shader path, material cache and warnings",
		StageMap.surface_shader_path == StageMap.SURFACE_SHADER_PATH
		and StageMap._surface_materials.is_empty() and StageMap._surface_warnings.is_empty())
	t.check("SimClock.threaded_in_bot_runs resets to false", not SimClock.threaded_in_bot_runs)
	t.check("Screens._ready_announced resets to false", not Screens._ready_announced)
	t.check("ArenaMindDress resets dir, sky material, panorama task and kit cache",
		ArenaMindDress.dir == ArenaMindDress.DIR and ArenaMindDress._sky_material == null
		and ArenaMindDress._panorama_task == -1 and ArenaMindDress._panorama_out.is_empty()
		and ArenaMindDress._kit_ahead.is_empty())
	t.check("HighdraftScenery resets dir, sky, cloud task/cache, warnings and coloured cache",
		HighdraftScenery.dir == HighdraftScenery.DIR and HighdraftScenery._sky == null
		and HighdraftScenery._cloud == null and HighdraftScenery._cloud_image == null
		and HighdraftScenery._cloud_task == -1 and HighdraftScenery._warned.is_empty()
		and HighdraftScenery._coloured.is_empty())
	t.check("Arena drops ahead bowl and resets _looks_warm", not Arena._looks_warm
		and Arena._ahead_bowl == null and not is_instance_id_valid(ahead_bowl_id))
	t.check("Requisition drops ahead scenes and caches", Requisition._ahead.is_empty()
		and Requisition._ahead_reads.is_empty() and Requisition._dressing.is_empty()
		and not is_instance_id_valid(req_ahead_id))
	t.check("ArenaBowlDress drops ahead kits and in-flight reading", ArenaBowlDress._ahead.is_empty()
		and ArenaBowlDress._reading.is_empty() and ArenaBowlDress._requested.is_empty()
		and not is_instance_id_valid(bowl_reading_id))
	t.check("UpgradeTree.unknown_warned clears on reset", UpgradeTree.unknown_warned.is_empty())
	t.check("Harmony.unknown_warned clears on reset", Harmony.unknown_warned.is_empty())
	t.check("ScrapField resets model_path and pickup mesh caches", ScrapField.model_path == ScrapField.PICKUP_GLB
		and ScrapField._pickup_mesh_cache.is_empty() and ScrapField._recovery_mesh_cache.is_empty()
		and ScrapField._cog_model == null and ScrapField._pickup_assets.is_empty()
		and ScrapField._ground_plates.is_empty())
	t.check("ModelVariants resets _on, _rejected and _stamp", ModelVariants._on == -1
		and ModelVariants._rejected == ModelVariants.REJECTED and ModelVariants._stamp == 0)
	t.check("Palette sky cache and task reset cleanly", Palette._sky_task == -1 and Palette._sky_texture == null
		and Palette._sky_waiting.is_empty() and Palette._sky_out.is_empty() and Palette._hdri_sky == null)
	t.check("processed tweens are killed on reset", get_processed_tweens().all(func(tw): return not tw.is_valid()))
	t.check("user://test-<pid> is cleared on reset", not FileAccess.file_exists(marker_path))

	t.check("Comfort.reduced_motion resets to false", not Comfort.reduced_motion)
	t.near("Comfort.motion_scale() resets to 1.0", Comfort.motion_scale(), 1.0)
	t.near("SpillwayScenery.flow_scale resets to 1.0", SpillwayScenery.flow_scale, 1.0)

	t.check("FlashGuard.on resets to false", not FlashGuard.on)
	t.eq("GraphicsPreset.current resets to high", GraphicsPreset.current, "high")
	t.check("SimClock.ticks resets to false", not SimClock.ticks)
	t.eq("Glyphs.device resets to kbm", Glyphs.device, "kbm")
	t.eq("SettingsPages.last_page resets to 0", SettingsPages.last_page, 0)
	t.check("StageLocks.active resets to true", StageLocks.active)
	t.eq("Synergies.table resets to null", Synergies.table, null)
	t.check("EnemyMotion.headless_idle resets to false", not EnemyMotion.headless_idle)
	t.check("EnemyClips.headless resets to false", not EnemyClips.headless)
	t.eq("Enemy.rim_color resets to Palette.ARC", Enemy.rim_color, Palette.ARC)
	var after_word := WorldFxWord.stamp(root, "LOUD", Vector3.ZERO)
	t.check("WorldFxWord un-hushes after reset", after_word.visible)
	after_word.free()
	t.eq("Synth.score_step resets to Harmony.STEP", Synth.score_step, Harmony.STEP)
	t.eq("Synth.score_transpose resets to 0", Synth.score_transpose, 0)
	t.check("SfxBank.reset_for_tests clears mutable statics",
		SfxBank._shift == 0 and SfxBank._theme == 0 and not SfxBank.bake_cancel)
	t.check("VoiceSynth.reset_for_tests clears caller and sidecar statics",
		VoiceSynth.unknown_callers.is_empty() and not VoiceSynth._voice_tts
		and VoiceSynth._voice_clips.is_empty() and VoiceSynth._samples.is_empty())
	t.check("MusicEngine.reset_for_tests clears stinger and park warm state",
		MusicEngine._stinger_tasks.is_empty() and MusicEngine._park_tasks.is_empty() and MusicEngine._park_warm.is_empty())
	t.check("Footings.plant_ignore_lines resets to false", not Footings.plant_ignore_lines)
	t.eq("RescueSite.model_path resets to MODEL", RescueSite.model_path, RescueSite.MODEL)
	t.eq("MusicRows.stem_dir resets to empty", MusicRows.stem_dir, "")

	# Verify _schedule_next() runs only after process_tweens() drains killed tweens and after
	# NOTIFICATION_PROCESS finishes, so the next test starts with no root children, no dead
	# tweens, and its first _physics_process() runs before any child _physics_process() or _process().
	var drain_node := Node3D.new()
	root.add_child(drain_node)
	var drain_tween := drain_node.create_tween()
	drain_tween.tween_property(drain_node, "position", Vector3.UP, 10.0)
	t.check("dead tween present before _schedule_next drains it", get_processed_tweens().size() >= 1)
	driver._reset()
	var gate_done := [false]
	var probe_ref := [null]
	driver._schedule_next(func() -> void:
		t.check("dead tweens are drained before next() runs", get_processed_tweens().is_empty())
		t.check("root has no gate or leftover children when next() runs", root.get_children().is_empty())
		_order_events.clear()
		_recording_order = true
		var probe := _OrderProbe.new(_order_events)
		probe_ref[0] = probe
		root.add_child(probe)
		gate_done[0] = true
	)
	for _i in 8:
		await physics_frame
		await process_frame
		if gate_done[0] and _order_events.has("tree_physics") and _order_events.has("child_physics") and _order_events.has("child_process"):
			break
	_recording_order = false
	if probe_ref[0] != null and is_instance_valid(probe_ref[0]):
		probe_ref[0].free()
	var i_tree := _order_events.find("tree_physics")
	var i_child_phys := _order_events.find("child_physics")
	var i_child_proc := _order_events.find("child_process")
	t.check("next() child _process() does not run before the test's first physics frame",
		gate_done[0] and i_tree >= 0 and i_child_proc > i_tree, str(_order_events))
	t.check("next() test _physics_process() runs before child _physics_process()",
		gate_done[0] and i_tree >= 0 and i_child_phys > i_tree, str(_order_events))

	# Stress-test MainTimerSync / delta smoothing: 20 iterations each preceded by 20 fast
	# process_frames and a killed tween must still hand off on a real physics tick with exact
	# order ["tree_physics", "child_physics", "tree_process", "child_process"], empty root,
	# empty processed tweens, and callback invoked once.
	var want_order: Array[String] = ["tree_physics", "child_physics", "tree_process", "child_process"]
	var stress_bad: Array[String] = []
	for iter in 20:
		for _f in 20:
			await process_frame
		var s_node := Node3D.new()
		root.add_child(s_node)
		var s_tw := s_node.create_tween()
		s_tw.tween_property(s_node, "position", Vector3.UP, 10.0)
		driver._reset()
		var calls := [0]
		var s_probe := [null]
		driver._schedule_next(func() -> void:
			calls[0] += 1
			if not get_processed_tweens().is_empty():
				stress_bad.append("iter %d: tweens not drained" % iter)
			if not root.get_children().is_empty():
				stress_bad.append("iter %d: root not empty" % iter)
			_order_events.clear()
			_recording_order = true
			var p := _OrderProbe.new(_order_events)
			s_probe[0] = p
			root.add_child(p)
		)
		for _w in 8:
			await physics_frame
			await process_frame
			if calls[0] > 0 and _order_events.size() >= 4:
				break
		_recording_order = false
		if s_probe[0] != null and is_instance_valid(s_probe[0]):
			s_probe[0].free()
		if calls[0] != 1 or _order_events != want_order:
			stress_bad.append("iter %d: calls=%d events=%s" % [iter, calls[0], str(_order_events)])
	t.check("fast-frame burst stress (20x20 process_frames) preserves exact tick/frame order",
		stress_bad.is_empty(), "; ".join(stress_bad))

	Audio._baked = true
	Audio._bake_done = true
	driver._reset()
	t.check("Audio.reset_for_tests clears _baked, _bake_done, and bake tasks",
		not Audio._baked and not Audio._bake_done and Audio._bake_task == -1 and Audio._rest_task == -1 and Audio._opening_task == -1)

	InkOutline.enabled = false
	var held_ink := InkOutline.ink("warden")
	var inked := StandardMaterial3D.new()
	inked.next_pass = held_ink
	InkOutline.strip(inked)
	t.check("InkOutline holds a stripped copy before reset", not InkOutline._stripped.is_empty())
	driver._reset()
	t.check("InkOutline.reset_for_tests switches the line back on and drops its passes and stripped copies",
		InkOutline.enabled and InkOutline._inks.is_empty() and InkOutline._lifts.is_empty()
		and InkOutline._stripped.is_empty() and InkOutline.ink("warden") != held_ink)

	WorldLook._park_fog["__probe__"] = {"density": 0.1}
	t.check("WorldLook holds a cached park fog before reset", not WorldLook._park_fog.is_empty())
	driver._reset()
	t.check("WorldLook.reset_for_tests clears cached park fog", WorldLook._park_fog.is_empty())

	BossModel._scenes["__probe__"] = PackedScene.new()
	BossModel._coloured[1] = StandardMaterial3D.new()
	var _camp_probe := CampCraftMeshes.guide_pip_mesh()
	t.check("BossModel holds cached scenes before reset", not BossModel._scenes.is_empty() and not BossModel._coloured.is_empty())
	driver._reset()
	t.check("BossModel.reset_for_tests clears _scenes and _coloured", BossModel._scenes.is_empty() and BossModel._coloured.is_empty())
	t.check("CampCraftMeshes.reset_for_tests clears cached meshes", CampCraftMeshes._mesh_cache.is_empty())

	BotProfile.enabled = true
	BotProfile._stack.append({"children": 1})
	BotProfile._totals["probe"] = 1
	BotProfile._samples["probe"] = {"ticks": [1], "usec": [1]}
	BotProfile._tick_start = 10
	BotProfile._tick_count = 2
	BotProfile._physics_end = 5
	BotProfile._pending = true
	BotProfile._monitors["probe"] = [1.0]
	SkillBand.quiet = true
	SkillBand.last_refusal = "probe"
	TraversalLine.graph_notes = 3
	TraversalLine._graphs["__probe__"] = true
	var stage1_map_before := TraversalLine.map_of(1)
	t.check("TraversalLine.use_fixture swaps park defs in memory before reset",
		stage1_map_before != TraversalLine.FIXTURE_MAP
		and TraversalLine.use_fixture()
		and TraversalLine._park_defs_source != ""
		and TraversalLine.map_of(1) == TraversalLine.FIXTURE_MAP)
	var fairness_before := BotFairness.config()
	t.check("BotFairness.config loads before reset", not fairness_before.is_empty())
	driver._reset()
	t.check("BotProfile.reset_for_tests clears profiler statics",
		not BotProfile.enabled and BotProfile._stack.is_empty() and BotProfile._totals.is_empty()
		and BotProfile._samples.is_empty() and BotProfile._tick_start == 0 and BotProfile._tick_count == 0
		and BotProfile._physics_end == 0 and not BotProfile._pending and BotProfile._monitors.is_empty())
	t.check("SkillBand.reset_for_tests clears quiet and last_refusal",
		not SkillBand.quiet and SkillBand.last_refusal == "")
	t.check("TraversalLine.reset_for_tests restores park defs and clears graph_notes, _park_defs_source, and _graphs",
		TraversalLine.graph_notes == 0 and TraversalLine._park_defs_source == "" and TraversalLine._graphs.is_empty()
		and TraversalLine.map_of(1) == stage1_map_before)
	var fairness_after := BotFairness.config()
	t.check("BotFairness.reset_for_tests reloads config cleanly",
		not fairness_after.is_empty() and not is_same(fairness_before, fairness_after))

	t.check("RampFlipper._parts populates _shared before reset", not RampFlipper._parts().is_empty())
	RampFlipper._warned_asset = true
	driver._reset()
	t.check("RampFlipper cache and warning reset cleanly",
		RampFlipper._shared.is_empty() and not RampFlipper._warned_asset)

	var shipping_before := CosmeticArt.shipping_ids()
	t.check("CosmeticArt.shipping_ids populates _shipping before reset", not shipping_before.is_empty())
	TeardownNoise.is_noise("ERROR: 1 resources still in use at exit")
	t.check("TeardownNoise compiles _line before reset", TeardownNoise._line != null)
	ContentRegistry._pass_depth = 2
	ContentRegistry._pass["__probe__"] = true
	driver._reset()
	t.check("CosmeticArt.reset_for_tests clears _shipping", CosmeticArt._shipping.is_empty())
	var shipping_after := CosmeticArt.shipping_ids()
	t.check("CosmeticArt.shipping_ids refills cleanly after reset",
		shipping_after == shipping_before and not is_same(shipping_before, shipping_after))
	t.check("TeardownNoise.reset_for_tests clears _line", TeardownNoise._line == null)
	var noise_line := "ERROR: 1 resources still in use at exit"
	t.eq("TeardownNoise.is_noise recompiles after reset",
		TeardownNoise.is_noise(noise_line), OS.get_name() == "macOS")
	t.check("TeardownNoise._line is compiled again after use", TeardownNoise._line != null)
	t.check("ContentRegistry.reset_for_tests clears _pass_depth and _pass",
		ContentRegistry._pass_depth == 0 and ContentRegistry._pass.is_empty())

	quit(t.verdict())


class _OrderProbe extends Node:
	var _events: Array[String]

	func _init(events: Array[String]) -> void:
		_events = events

	func _process(_delta: float) -> void:
		if not _events.has("child_process"):
			_events.append("child_process")

	func _physics_process(_delta: float) -> void:
		if not _events.has("child_physics"):
			_events.append("child_physics")


class _FakeHud extends RefCounted:
	var is_quiet := false

	func quiet(on: bool) -> void:
		is_quiet = on


class _FakeGame extends RefCounted:
	var hud

	func _init(h) -> void:
		hud = h


class _FakeHost extends RefCounted:
	var game

	func _init(h) -> void:
		game = _FakeGame.new(h)
