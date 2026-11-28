extends SceneTree


const T := preload("res://tests/support/t.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Assembly := preload("res://src/presentation/craft/craft_showcase_assembly.gd")
const HeroSculptor := preload("res://src/presentation/craft/hero_kitbash_sculptor.gd")
const Lookdev := preload("res://src/presentation/craft/craft_lookdev.gd")
const VistaMegas := preload("res://src/presentation/craft/vista_megastructures.gd")
const AtmoRig := preload("res://src/presentation/craft/vista_atmosphere_rig.gd")

var _t := T.new("craft_pipeline_integration_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(Assembly.SHOWCASE_SCENE_PATH) as PackedScene
	_t.check("craft_showcase_arena.tscn loads cleanly", packed != null)
	if packed == null:
		quit(_t.verdict())
		return

	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	await process_frame

	var receipt := Assembly.assemble_into(arena)
	_t.eq("all 4 mapped HeroSockets populated", int(receipt["sockets_populated"]), 4)
	_t.check("all mounted hero surfaces bound via CraftLookdev (>= 24 surfaces)",
		int(receipt["total_surfaces_bound"]) >= 24,
		"bound=%d" % int(receipt["total_surfaces_bound"]))
	_t.check("midground perimeter framing & overhead gantry unified with CraftLookdev PBR presets (>= 25 meshes)",
		int(receipt["perimeter_surfaces_bound"]) >= 25,
		"perimeter_bound=%d" % int(receipt["perimeter_surfaces_bound"]))
	_t.check("vista aqueduct, horizon piers, and smokestack barrels unified with macro CraftLookdev weathering (>= 10 meshes)",
		int(receipt.get("vista_surfaces_bound", 0)) >= 10,
		"vista_bound=%d" % int(receipt.get("vista_surfaces_bound", 0)))
	for perim_path: String in [
		"IndustrialPerimeterFraming/FurnaceBay_NW/Housing",
		"IndustrialPerimeterFraming/OverlookParapet_North",
		"IndustrialPerimeterFraming/OverheadGantryTruss/Chord_NorthLow",
	]:
		var pmi := arena.get_node_or_null(perim_path) as MeshInstance3D
		var pmat := pmi.get_active_material(0) as ShaderMaterial if pmi != null else null
		_t.check("perimeter mesh %s uses craft_master_weathering.gdshader (unmasked)" % perim_path.get_file(),
			pmat != null and pmat.shader != null and pmat.shader.resource_path == Lookdev.MASTER_SHADER_PATH
			and bool(pmat.get_shader_parameter("use_vertex_masks")) == false)
	var aqueduct := arena.get_node_or_null("VistaMegastructures/CanyonBasinFloor/HorizonAqueductTrestle") as MeshInstance3D
	var aq_mat := aqueduct.material_override as ShaderMaterial if aqueduct != null else null
	_t.check("HorizonAqueductTrestle uses macro weathered masonry shader",
		aq_mat != null and aq_mat.shader != null and aq_mat.shader.resource_path == Lookdev.MASTER_SHADER_PATH)
	_t.check("combat floor apron bound to craft_combat_floor.gdshader",
		bool(receipt["floor_bound"]) and String(receipt["floor_shader_path"]) == Lookdev.FLOOR_SHADER_PATH,
		String(receipt["floor_shader_path"]))

	var hero_nodes: Dictionary = receipt["hero_nodes"]
	for socket_name: String in Assembly.SOCKET_SPECS.keys():
		var mi := hero_nodes.get(socket_name) as MeshInstance3D
		_t.check("%s holds valid MountedHero MeshInstance3D" % socket_name, mi != null and mi.mesh is ArrayMesh)
		if mi == null or not (mi.mesh is ArrayMesh):
			continue
		var mesh := mi.mesh as ArrayMesh
		var all_shader := true
		var cable_ok := true
		var core_ok := true
		for si in mesh.get_surface_count():
			var mat := mi.get_surface_override_material(si) as ShaderMaterial
			var sname := mesh.surface_get_name(si)
			if mat == null or mat.shader == null or mat.shader.resource_path != Lookdev.MASTER_SHADER_PATH:
				all_shader = false
			if sname == "cable_rubber" and (mat == null or mat.resource_path != Lookdev.PRESET_PATHS["oil_slicked_iron"]):
				cable_ok = false
			if sname == "emissive_core" and (mat == null or mat.resource_path != Lookdev.PRESET_PATHS["plasma_conduit_core"]):
				core_ok = false
			if sname == "copper_coil" and (mat == null or float(mat.get_shader_parameter("base_metallic")) < 0.65):
				all_shader = false
		_t.check("%s binds craft_master_weathering.gdshader on all %d surfaces" % [socket_name, mesh.get_surface_count()],
			all_shader and cable_ok and core_ok,
			"all_shader=%s cable_ok=%s core_ok=%s" % [all_shader, cable_ok, core_ok])
		var stats := HeroSculptor.inspect_mesh_stats(mesh)
		_t.check("%s preserves rich sculpted detail (>= 3000 tris) and vertex-color masks" % socket_name,
			stats.triangle_count >= 3000 and stats.b_high_ratio > 0.002 and stats.r_high_ratio >= 0.15,
			"tris=%d" % stats.triangle_count)

	var beacon_mi := hero_nodes.get("HeroSocket_CenterBeacon") as MeshInstance3D
	if beacon_mi != null:
		var beacon_bottom := beacon_mi.global_position.y + beacon_mi.mesh.get_aabb().position.y * beacon_mi.scale.y
		_t.near("salvage_press_beacon rests cleanly at y=0.0", beacon_bottom, 0.0, 0.05)
	var crane_mi := hero_nodes.get("HeroSocket_EMCranGantry") as MeshInstance3D
	if crane_mi != null:
		var crane_bottom := crane_mi.global_position.y + crane_mi.mesh.get_aabb().position.y * crane_mi.scale.y
		_t.check("em_crane_gantry suspends cleanly above combat floor (clearance >= 8.0 m)",
			crane_bottom >= 8.0 and crane_bottom <= 18.0, "bottom_y=%.2f" % crane_bottom)

	var we := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_t.check("WorldEnvironment enforces AgX + SSIL + SSAO + volumetric fog + selective bloom (bloom=0, threshold>=2.4)",
		we != null and we.environment != null
		and we.environment.tonemap_mode == Environment.TONE_MAPPER_AGX
		and we.environment.ssil_enabled and we.environment.ssao_enabled
		and we.environment.volumetric_fog_enabled
		and is_zero_approx(we.environment.glow_bloom)
		and we.environment.glow_hdr_threshold >= Assembly.SELECTIVE_GLOW_THRESHOLD_MIN,
		"bloom=%.2f threshold=%.2f" % [we.environment.glow_bloom, we.environment.glow_hdr_threshold] if we != null and we.environment != null else "null")

	var vistas := arena.get_node_or_null("VistaMegastructures") as VistaMegas
	var rig := arena.get_node_or_null("VistaAtmosphereRig") as AtmoRig
	_t.check("distant vistas (22 records) and living air rig remain active alongside mounted heroes",
		vistas != null and vistas.get_vista_records().size() == 22
		and rig != null and rig.get_particle_systems().size() >= 3 and rig.get_bounce_lights().size() == 6)

	var q_low := Assembly.apply_quality_tier(arena, "low")
	var sun_node := arena.get_node_or_null("SunKey") as DirectionalLight3D
	_t.check("quality tier 'low' disables SSAO/SSIL/volumetric fog/particles and scales shadow bias against low-res acne while keeping AgX",
		String(q_low.get("tier", "")) == "low"
		and not bool(q_low.get("ssao", true)) and not bool(q_low.get("ssil", true))
		and not bool(q_low.get("volumetric_fog", true)) and not bool(q_low.get("particles", true))
		and sun_node != null and sun_node.shadow_normal_bias >= 1.5 and sun_node.shadow_bias >= 0.20
		and we != null and we.environment != null and we.environment.tonemap_mode == Environment.TONE_MAPPER_AGX)
	var q_med := Assembly.apply_quality_tier(arena, "medium")
	_t.check("quality tier 'medium' enables SSAO & selective glow without SSIL/volumetric fog",
		String(q_med.get("tier", "")) == "medium"
		and bool(q_med.get("ssao", false)) and not bool(q_med.get("ssil", true))
		and not bool(q_med.get("volumetric_fog", true)) and bool(q_med.get("glow", false)))
	var q_ultra := Assembly.apply_quality_tier(arena, "ultra")
	_t.check("quality tier 'ultra' enables full SSAO/SSIL/volumetric fog/heat haze + extended shadow range",
		String(q_ultra.get("tier", "")) == "ultra"
		and bool(q_ultra.get("ssao", false)) and bool(q_ultra.get("ssil", false))
		and bool(q_ultra.get("volumetric_fog", false)) and float(q_ultra.get("shadow_max_distance", 0.0)) >= 200.0)
	var q_high := Assembly.apply_quality_tier(arena, "high")
	_t.check("quality tier restores cleanly to 'high' with selective bloom discipline",
		String(q_high.get("tier", "")) == "high"
		and bool(q_high.get("ssao", false)) and bool(q_high.get("ssil", false))
		and bool(q_high.get("volumetric_fog", false))
		and we != null and we.environment != null
		and is_zero_approx(we.environment.glow_bloom)
		and we.environment.glow_hdr_threshold >= Assembly.SELECTIVE_GLOW_THRESHOLD_MIN)

	FlashGuard.on = true
	Assembly.sync_accessibility(arena, true)
	var plasma_mat := Lookdev.preset_material("plasma_conduit_core")
	_t.check("FlashGuard propagates reduce_flashes=true into CraftLookdev master weathering shaders",
		plasma_mat != null and bool(plasma_mat.get_shader_parameter("reduce_flashes")) == true)
	FlashGuard.on = false
	Assembly.sync_accessibility(arena, false)
	_t.check("FlashGuard restores reduce_flashes=false cleanly",
		plasma_mat != null and bool(plasma_mat.get_shader_parameter("reduce_flashes")) == false)

	var arena_id := arena.get_instance_id()
	arena.free()
	Assembly.reset_for_tests()
	await process_frame
	_t.check("integrated showcase tears down cleanly", instance_from_id(arena_id) == null)
	quit(_t.verdict())
