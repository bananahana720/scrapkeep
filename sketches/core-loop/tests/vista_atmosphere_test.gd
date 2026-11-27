extends SceneTree


const T := preload("res://tests/support/t.gd")
const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const VistaMegas := preload("res://src/presentation/craft/vista_megastructures.gd")
const AtmoRig := preload("res://src/presentation/craft/vista_atmosphere_rig.gd")
const AudioCues := preload("res://src/presentation/craft/craft_audio_cues.gd")

const SCENE_PATH := "res://src/presentation/craft/craft_showcase_arena.tscn"
const HEAT_HAZE_SHADER_PATH := "res://assets/shaders/craft_heat_haze.gdshader"

var _t := T.new("vista_atmosphere_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_environment_presets()
	_check_heat_haze_shader()
	await _check_showcase_scene_and_rig()
	_check_audio_manifest()
	quit(_t.verdict())


func _check_environment_presets() -> void:
	for preset in ["smelter_dawn", "spillway_morning"]:
		var env := AtmoRig.build_environment(preset)
		_t.check("%s uses AgX tonemapping" % preset, env.tonemap_mode == Environment.TONE_MAPPER_AGX,
			"mode=%d" % env.tonemap_mode)
		_t.check("%s enables SSIL indirect lighting" % preset, env.ssil_enabled and env.ssil_intensity > 0.0,
			"enabled=%s intensity=%.2f" % [env.ssil_enabled, env.ssil_intensity])
		_t.check("%s enables SSAO contact shadows" % preset, env.ssao_enabled and env.ssao_intensity > 0.0,
			"enabled=%s intensity=%.2f" % [env.ssao_enabled, env.ssao_intensity])
		_t.check("%s sets selective HDR glow threshold > 1.0" % preset,
			env.glow_enabled and env.glow_hdr_threshold > 1.0,
			"enabled=%s threshold=%.2f" % [env.glow_enabled, env.glow_hdr_threshold])
		_t.check("%s enables depth-graded fog keeping 0-45 m combat lane clear" % preset,
			env.fog_enabled and env.fog_mode == Environment.FOG_MODE_DEPTH and env.fog_depth_begin >= 45.0,
			"begin=%.1f end=%.1f" % [env.fog_depth_begin, env.fog_depth_end])
		_t.check("%s enables volumetric fog with directional sun scattering" % preset,
			env.volumetric_fog_enabled and env.volumetric_fog_density > 0.0 and env.volumetric_fog_anisotropy > 0.4,
			"density=%.4f anisotropy=%.2f" % [env.volumetric_fog_density, env.volumetric_fog_anisotropy])


func _check_heat_haze_shader() -> void:
	var shader := load(HEAT_HAZE_SHADER_PATH) as Shader
	_t.check("craft_heat_haze.gdshader loads cleanly", shader != null and not shader.code.is_empty())
	if shader != null:
		_t.check("heat haze shader samples hint_screen_texture and honors reduced_motion + reduce_flashes",
			shader.code.contains("hint_screen_texture")
			and shader.code.contains("reduced_motion")
			and shader.code.contains("reduce_flashes"))


func _check_showcase_scene_and_rig() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_t.check("craft_showcase_arena.tscn loads as PackedScene", packed != null)
	if packed == null:
		return

	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	await process_frame

	var floor_body := arena.get_node_or_null("CombatLaneFloor") as StaticBody3D
	_t.check("showcase has flat CombatLaneFloor at y=0.0",
		floor_body != null
		and bool(floor_body.get_meta("flat_combat_floor", false))
		and is_zero_approx(float(floor_body.get_meta("floor_y", -1.0))))
	var floor_mesh := floor_body.get_node_or_null("FloorMesh") as MeshInstance3D if floor_body != null else null
	if floor_mesh != null and floor_mesh.mesh is BoxMesh:
		var box := floor_mesh.mesh as BoxMesh
		var top_y := floor_mesh.position.y + box.size.y * 0.5
		_t.near("combat floor top surface sits cleanly at y=0.0", top_y, 0.0, 0.001)
		var mat := box.material as StandardMaterial3D
		_t.check("combat floor uses desaturated mid-tone matte finish",
			mat != null and mat.roughness >= 0.8 and mat.albedo_color.s < 0.35 and mat.albedo_color.v >= 0.35 and mat.albedo_color.v <= 0.65,
			"s=%.2f v=%.2f r=%.2f" % [mat.albedo_color.s, mat.albedo_color.v, mat.roughness] if mat != null else "null")

	var sockets := arena.get_node_or_null("HeroSockets")
	var markers := sockets.find_children("*", "Marker3D", false, false) if sockets != null else []
	_t.check("showcase exposes >= 4 Marker3D HeroSockets for downstream asset integration",
		markers.size() >= 4, "count=%d" % markers.size())

	var vistas := arena.get_node_or_null("VistaMegastructures") as VistaMegas
	_t.check("VistaMegastructures built inside showcase", vistas != null)
	if vistas != null:
		var records := vistas.get_vista_records()
		var kinds := {}
		var out_of_band := []
		for rec in records:
			kinds[rec["kind"]] = int(kinds.get(rec["kind"], 0)) + 1
			var d: float = rec["distance_m"]
			if d < VistaMegas.MIN_VISTA_DISTANCE_M or d > VistaMegas.MAX_VISTA_DISTANCE_M:
				out_of_band.append("%s:%.1fm" % [rec["name"], d])
		_t.check("all vista megastructures sit strictly in 180 m - 650 m band outside combat floor",
			not records.is_empty() and out_of_band.is_empty(),
			"total=%d violations=%s" % [records.size(), str(out_of_band)])
		_t.check("vistas include orbital_launch_ring, salvage_crane_tower, smelter_smokestack, and horizon_pier",
			kinds.has("orbital_launch_ring") and kinds.has("salvage_crane_tower")
			and kinds.has("smelter_smokestack") and kinds.has("horizon_pier"),
			str(kinds))
		var vista_colliders := vistas.find_children("*", "CollisionObject3D", true, false)
		_t.check("vistas carry zero colliders", vista_colliders.is_empty(), str(vista_colliders))
		var first_rotor := vistas.find_child("SlowRotor", true, false) as Node3D
		var rot_before := first_rotor.rotation.z if first_rotor != null else 0.0
		vistas.step_animation(1.0)
		var rot_after := first_rotor.rotation.z if first_rotor != null else 0.0
		_t.check("salvage crane rotors turn slowly when reduced_motion is off",
			vistas.get_rotor_count() >= 4 and not is_equal_approx(rot_before, rot_after),
			"rotors=%d delta=%.3f" % [vistas.get_rotor_count(), rot_after - rot_before])
		vistas.set_reduced_motion(true)
		var rot_frozen_before := first_rotor.rotation.z if first_rotor != null else 0.0
		vistas.step_animation(1.0)
		var rot_frozen_after := first_rotor.rotation.z if first_rotor != null else 0.0
		_t.check("salvage crane rotors freeze when reduced_motion is on",
			is_equal_approx(rot_frozen_before, rot_frozen_after))
		vistas.set_reduced_motion(false)

	var rig := arena.get_node_or_null("VistaAtmosphereRig") as AtmoRig
	_t.check("VistaAtmosphereRig attached and initialized", rig != null)
	if rig != null:
		var we := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
		_t.check("WorldEnvironment receives rig's AgX/SSIL/SSAO/volumetric-fog preset",
			we != null and we.environment != null
			and we.environment.tonemap_mode == Environment.TONE_MAPPER_AGX
			and we.environment.ssil_enabled and we.environment.ssao_enabled
			and we.environment.volumetric_fog_enabled
			and we.environment.glow_hdr_threshold > 1.0)

		var godray_vol := rig.find_child("GantryGodRayVolume", true, false) as FogVolume
		_t.check("GantryGodRayVolume sits strictly above combat height (y >= 6.0 m)",
			godray_vol != null and (godray_vol.position.y - godray_vol.size.y * 0.5) >= 6.0,
			"min_y=%.2f" % (godray_vol.position.y - godray_vol.size.y * 0.5) if godray_vol != null else "null")

		var particles := rig.get_particle_systems()
		_t.check("living air spawns >= 3 GPUParticles3D systems (embers, dust motes, steam vents)",
			particles.size() >= 3, "count=%d" % particles.size())

		var cables := rig.get_cable_nodes()
		_t.check("overhead catenary cables built above combat height",
			cables.size() >= 4 and cables.all(func(c: MeshInstance3D) -> bool: return c.position.y >= 13.0),
			"count=%d" % cables.size())
		var cable_p0 := cables[0].position if not cables.is_empty() else Vector3.ZERO
		rig.step_atmosphere(1.2)
		var cable_p1 := cables[0].position if not cables.is_empty() else Vector3.ZERO
		_t.check("catenary cables gently sway when reduced_motion is off",
			not cable_p0.is_equal_approx(cable_p1))

		var haze_positions := rig.get_heat_haze_positions()
		var haze_clear := haze_positions.all(func(p: Vector3) -> bool:
			return Vector2(p.x, p.z).length() >= AtmoRig.HEAT_HAZE_MIN_RADIUS_M)
		_t.check("localized heat-haze vents sit strictly outside central combat lane (>= 22 m)",
			haze_positions.size() >= 2 and haze_clear, "count=%d" % haze_positions.size())

		var bounces := rig.get_bounce_lights()
		var has_warm := bounces.any(func(l: OmniLight3D) -> bool:
			return l.light_color == Palette.SODIUM or l.light_color == Palette.AMBER)
		var has_cool_arc := bounces.any(func(l: OmniLight3D) -> bool:
			return l.light_color == Palette.ARC)
		var no_hazard_bounce := bounces.all(func(l: OmniLight3D) -> bool:
			return l.light_color != Palette.HAZARD and not l.shadow_enabled)
		_t.check("localized shadowless OmniLight3D bounce pools include warm sodium/amber and cool arc, never HAZARD",
			bounces.size() >= 4 and has_warm and has_cool_arc and no_hazard_bounce,
			"count=%d warm=%s arc=%s" % [bounces.size(), has_warm, has_cool_arc])

		rig.set_reduced_motion(true)
		rig.step_atmosphere(0.8)
		var embers := rig.find_child("EmberParticles", true, false) as GPUParticles3D
		_t.check("reduced_motion freezes particle speed_scale and disables cosmetic embers",
			embers != null and is_zero_approx(embers.speed_scale) and not embers.emitting)
		var cable_rest := cables[0].position
		rig.step_atmosphere(0.9)
		_t.check("reduced_motion holds catenary cables steady", cable_rest.is_equal_approx(cables[0].position))

		rig.set_reduced_motion(false)
		FlashGuard.on = true
		rig.apply_accessibility(false)
		var fg_energy := bounces[0].light_energy
		FlashGuard.on = false
		rig.apply_accessibility(false)
		var normal_energy := bounces[0].light_energy
		_t.check("FlashGuard attenuates bounce light peak energy cleanly",
			fg_energy < normal_energy, "flash_guard=%.3f normal=%.3f" % [fg_energy, normal_energy])

	var arena_id := arena.get_instance_id()
	arena.free()
	await process_frame
	_t.check("CraftShowcaseArena tears down cleanly with zero dangling instance",
		instance_from_id(arena_id) == null)


func _check_audio_manifest() -> void:
	var report := AudioCues.audit_manifest()
	_t.check("CraftAudioCues resolves all 4 experimental audio stems (1 ambience + 3 callouts)",
		int(report["total"]) == 4 and int(report["resolved"]) == 4 and (report["missing"] as Array).is_empty(),
		str(report["missing"]))
	for cue_id in AudioCues.cue_ids():
		var player := AudioCues.create_player(cue_id)
		_t.check("audio cue %s builds valid AudioStreamPlayer safely headless" % cue_id,
			player != null and player.stream != null and player.stream.get_length() > 0.0)
		if player != null:
			player.free()
