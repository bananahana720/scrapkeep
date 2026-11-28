class_name VistaAtmosphereRig
extends Node3D


const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Comfort := preload("res://src/core/comfort.gd")
const HEAT_HAZE_SHADER := preload("res://assets/shaders/craft_heat_haze.gdshader")

const COMBAT_CLEAR_FOG_BEGIN_M := 68.0
const HEAT_HAZE_MIN_RADIUS_M := 22.0
const GLOW_HDR_THRESHOLD_MIN := 1.05

const PRESETS := {
	"smelter_dawn": {
		"tonemap_exposure": 0.98,
		"tonemap_agx_white": 16.29,
		"tonemap_agx_contrast": 1.22,
		"ambient_color": Color("8a96c4"),
		"ambient_energy": 0.34,
		"ambient_sky_contribution": 0.22,
		"ssil_radius": 4.5,
		"ssil_intensity": 0.85,
		"ssao_radius": 0.72,
		"ssao_intensity": 1.55,
		"glow_hdr_threshold": 2.40,
		"glow_intensity": 0.24,
		"glow_bloom": 0.0,
		"glow_strength": 0.82,
		"fog_color": Color("aa8c72"),
		"fog_depth_begin": 145.0,
		"fog_depth_end": 940.0,
		"fog_depth_curve": 1.45,
		"fog_aerial_perspective": 0.10,
		"fog_sun_scatter": 0.04,
		"fog_sky_affect": 0.14,
		"volumetric_fog_density": 0.0005,
		"volumetric_fog_albedo": Color("dcb98e"),
		"volumetric_fog_anisotropy": 0.64,
		"volumetric_fog_length": 140.0,
		"volumetric_fog_ambient_inject": 0.08,
		"volumetric_fog_gi_inject": 0.16,
		"volumetric_fog_sky_affect": 0.04,
		"adjustment_saturation": 1.10,
		"adjustment_contrast": 1.05,
		"sky_top": Color("4a5c9a"),
		"sky_horizon": Color("c88d64"),
		"sky_glow": Color("3c2010"),
		"sky_recolor": 0.50,
		"sky_energy": 0.58,
		"sun_dir": Vector3(0.76, 0.50, -0.42),
	},
	"spillway_morning": {
		"tonemap_exposure": 1.06,
		"tonemap_agx_white": 16.29,
		"tonemap_agx_contrast": 1.20,
		"ambient_color": Color("9cc8cc"),
		"ambient_energy": 0.32,
		"ambient_sky_contribution": 0.30,
		"ssil_radius": 4.2,
		"ssil_intensity": 0.78,
		"ssao_radius": 0.60,
		"ssao_intensity": 1.28,
		"glow_hdr_threshold": 1.40,
		"glow_intensity": 0.30,
		"glow_bloom": 0.12,
		"glow_strength": 0.85,
		"fog_color": Color("bfd6d4"),
		"fog_depth_begin": 74.0,
		"fog_depth_end": 680.0,
		"fog_depth_curve": 1.30,
		"fog_aerial_perspective": 0.34,
		"fog_sun_scatter": 0.32,
		"fog_sky_affect": 0.24,
		"volumetric_fog_density": 0.0022,
		"volumetric_fog_albedo": Color("e2eee8"),
		"volumetric_fog_anisotropy": 0.60,
		"volumetric_fog_length": 240.0,
		"volumetric_fog_ambient_inject": 0.24,
		"volumetric_fog_gi_inject": 0.30,
		"volumetric_fog_sky_affect": 0.12,
		"adjustment_saturation": 1.10,
		"adjustment_contrast": 1.02,
		"sky_top": Color("82b8d8"),
		"sky_horizon": Color("f0d4b8"),
		"sky_glow": Color("6a4424"),
		"sky_recolor": 0.25,
		"sky_energy": 0.96,
		"sun_dir": Vector3(0.55, 0.44, -0.71),
	},
}

const HEAT_HAZE_VENTS := [
	{"name": "HeatHaze_NorthW", "pos": Vector3(-19.5, 6.2, -30.0), "size": Vector2(6.8, 5.2), "yaw_deg": 14.0},
	{"name": "HeatHaze_NorthE", "pos": Vector3(19.5, 6.2, -30.0), "size": Vector2(6.8, 5.2), "yaw_deg": -14.0},
	{"name": "HeatHaze_West", "pos": Vector3(-31.5, 4.6, -10.0), "size": Vector2(6.0, 5.0), "yaw_deg": 82.0},
	{"name": "HeatHaze_East", "pos": Vector3(31.5, 4.6, -10.0), "size": Vector2(6.0, 5.0), "yaw_deg": -82.0},
]

const CATENARY_SPANS := [
	{"name": "Cable_NorthSpanA", "a": Vector3(-29.5, 22.8, -18.0), "b": Vector3(29.5, 22.8, -18.0), "sag": 2.4, "sway": 0.30},
	{"name": "Cable_NorthSpanB", "a": Vector3(-30.0, 24.4, -26.0), "b": Vector3(30.0, 24.4, -26.0), "sag": 2.8, "sway": 0.36},
	{"name": "Cable_WestRun", "a": Vector3(-29.5, 20.5, 14.0), "b": Vector3(-29.5, 22.8, -26.0), "sag": 2.1, "sway": 0.24},
	{"name": "Cable_EastRun", "a": Vector3(29.5, 20.5, 14.0), "b": Vector3(29.5, 22.8, -26.0), "sag": 2.1, "sway": 0.24},
]

const BOUNCE_SPECS := {
	"FurnaceBounce_NW": {"color": Palette.SODIUM, "energy": 3.2, "range": 22.0, "attenuation": 1.15, "pulse_hz": 0.45, "amp": 0.16},
	"FurnaceBounce_NE": {"color": Palette.SODIUM, "energy": 3.2, "range": 22.0, "attenuation": 1.15, "pulse_hz": 0.41, "amp": 0.16},
	"FurnaceBounce_SW": {"color": Palette.AMBER, "energy": 2.4, "range": 18.0, "attenuation": 1.25, "pulse_hz": 0.36, "amp": 0.12},
	"FurnaceBounce_SE": {"color": Palette.AMBER, "energy": 2.4, "range": 18.0, "attenuation": 1.25, "pulse_hz": 0.38, "amp": 0.12},
	"ArcConduitBounce_W": {"color": Palette.ARC, "energy": 2.1, "range": 16.0, "attenuation": 1.30, "pulse_hz": 0.55, "amp": 0.10},
	"ArcConduitBounce_E": {"color": Palette.ARC, "energy": 2.1, "range": 16.0, "attenuation": 1.30, "pulse_hz": 0.52, "amp": 0.10},
}

const QUALITY_TIERS := {
	"low": {
		"ssao": false,
		"ssil": false,
		"volumetric_fog": false,
		"glow": false,
		"particles": false,
		"heat_haze": false,
		"shadow_max_distance": 95.0,
		"shadow_bias": 0.24,
		"shadow_normal_bias": 1.75,
		"ssao_scale": 0.0,
		"ssil_scale": 0.0,
	},
	"medium": {
		"ssao": true,
		"ssil": false,
		"volumetric_fog": false,
		"glow": true,
		"particles": true,
		"heat_haze": false,
		"shadow_max_distance": 135.0,
		"shadow_bias": 0.13,
		"shadow_normal_bias": 0.95,
		"ssao_scale": 0.85,
		"ssil_scale": 0.0,
	},
	"high": {
		"ssao": true,
		"ssil": true,
		"volumetric_fog": true,
		"glow": true,
		"particles": true,
		"heat_haze": true,
		"shadow_max_distance": 160.0,
		"shadow_bias": 0.10,
		"shadow_normal_bias": 0.65,
		"ssao_scale": 1.0,
		"ssil_scale": 1.0,
	},
	"ultra": {
		"ssao": true,
		"ssil": true,
		"volumetric_fog": true,
		"glow": true,
		"particles": true,
		"heat_haze": true,
		"shadow_max_distance": 200.0,
		"shadow_bias": 0.08,
		"shadow_normal_bias": 0.55,
		"ssao_scale": 1.08,
		"ssil_scale": 1.12,
	},
}

@export var preset_name := "smelter_dawn"
@export var quality_tier := "high"

var _built := false
var _environment: Environment
var _particles: Array[GPUParticles3D] = []
var _cables: Array[Dictionary] = []
var _haze_nodes: Array[MeshInstance3D] = []
var _haze_materials: Array[ShaderMaterial] = []
var _bounce_lights: Array[Dictionary] = []
var _soft_disc: ImageTexture
var _anim_time := 0.0


func _ready() -> void:
	build_atmosphere()


func _process(delta: float) -> void:
	step_atmosphere(delta)


static func build_environment(preset: String = "smelter_dawn") -> Environment:
	var spec: Dictionary = PRESETS.get(preset, PRESETS["smelter_dawn"])
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = _make_sky(spec)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = spec["ambient_color"]
	env.ambient_light_energy = float(spec["ambient_energy"])
	env.ambient_light_sky_contribution = float(spec["ambient_sky_contribution"])
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = float(spec["tonemap_exposure"])
	env.tonemap_agx_white = float(spec["tonemap_agx_white"])
	env.tonemap_agx_contrast = float(spec["tonemap_agx_contrast"])

	env.ssil_enabled = true
	env.ssil_radius = float(spec["ssil_radius"])
	env.ssil_intensity = float(spec["ssil_intensity"])
	env.ssil_sharpness = 0.9
	env.ssil_normal_rejection = 1.0

	env.ssao_enabled = true
	env.ssao_radius = float(spec["ssao_radius"])
	env.ssao_intensity = float(spec["ssao_intensity"])
	env.ssao_power = 1.3
	env.ssao_detail = 0.45
	env.ssao_sharpness = 0.85
	env.ssao_light_affect = 0.08

	env.glow_enabled = true
	env.glow_hdr_threshold = maxf(float(spec["glow_hdr_threshold"]), GLOW_HDR_THRESHOLD_MIN)
	env.glow_intensity = float(spec["glow_intensity"])
	env.glow_bloom = float(spec["glow_bloom"])
	env.glow_strength = float(spec["glow_strength"])
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = spec["fog_color"]
	env.fog_light_energy = 0.85
	env.fog_depth_begin = float(spec["fog_depth_begin"])
	env.fog_depth_end = float(spec["fog_depth_end"])
	env.fog_depth_curve = float(spec["fog_depth_curve"])
	env.fog_aerial_perspective = float(spec["fog_aerial_perspective"])
	env.fog_sun_scatter = float(spec["fog_sun_scatter"])
	env.fog_sky_affect = float(spec["fog_sky_affect"])

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(spec["volumetric_fog_density"])
	env.volumetric_fog_albedo = spec["volumetric_fog_albedo"]
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	env.volumetric_fog_anisotropy = float(spec["volumetric_fog_anisotropy"])
	env.volumetric_fog_length = float(spec["volumetric_fog_length"])
	env.volumetric_fog_detail_spread = 1.35
	env.volumetric_fog_ambient_inject = float(spec["volumetric_fog_ambient_inject"])
	env.volumetric_fog_gi_inject = float(spec["volumetric_fog_gi_inject"])
	env.volumetric_fog_sky_affect = float(spec["volumetric_fog_sky_affect"])

	env.adjustment_enabled = true
	env.adjustment_saturation = float(spec["adjustment_saturation"])
	env.adjustment_contrast = float(spec["adjustment_contrast"])
	return env


static func _make_sky(spec: Dictionary) -> Sky:
	var sky := Sky.new()
	if ResourceLoader.exists(PaletteMaterials.HDRI_SKY):
		var pano := load(PaletteMaterials.HDRI_SKY) as Texture2D
		if pano != null:
			var mat := PaletteMaterials.time_sky_material(pano)
			mat.set_shader_parameter("top_tint", spec["sky_top"])
			mat.set_shader_parameter("horizon_tint", spec["sky_horizon"])
			mat.set_shader_parameter("glow", spec["sky_glow"])
			mat.set_shader_parameter("recolor", float(spec["sky_recolor"]))
			mat.set_shader_parameter("highlight", 1.35)
			mat.set_shader_parameter("energy", float(spec["sky_energy"]))
			mat.set_shader_parameter("sun_dir", (spec["sun_dir"] as Vector3).normalized())
			sky.sky_material = mat
			return sky
	var proc := ProceduralSkyMaterial.new()
	proc.sky_top_color = spec["sky_top"]
	proc.sky_horizon_color = spec["sky_horizon"]
	proc.ground_bottom_color = Palette.CHARCOAL
	proc.ground_horizon_color = spec["fog_color"]
	sky.sky_material = proc
	return sky


func build_atmosphere() -> void:
	if _built:
		return
	_built = true
	_particles.clear()
	_cables.clear()
	_haze_nodes.clear()
	_haze_materials.clear()
	_bounce_lights.clear()
	_soft_disc = _make_soft_disc_texture(64)

	_environment = build_environment(preset_name)
	_apply_environment_to_scene(_environment)
	_enhance_showcase_surfaces()
	_build_fog_volumes()
	_build_particles()
	_build_catenary_cables()
	_build_heat_haze_vents()

	var parent_node := get_parent()
	if parent_node != null:
		var pool := parent_node.get_node_or_null("BounceLightPool") as Node3D
		if pool != null:
			bind_bounce_pool(pool)
	apply_accessibility()


func apply_preset(name_id: String) -> Environment:
	preset_name = name_id if PRESETS.has(name_id) else "smelter_dawn"
	_environment = build_environment(preset_name)
	_apply_environment_to_scene(_environment)
	apply_quality_tier(quality_tier)
	return _environment


func apply_quality_tier(tier: String) -> Dictionary:
	var key := tier.strip_edges().to_lower()
	if not QUALITY_TIERS.has(key):
		key = "high"
	quality_tier = key
	var q: Dictionary = QUALITY_TIERS[key]
	var spec: Dictionary = PRESETS.get(preset_name, PRESETS["smelter_dawn"])
	if _environment != null:
		_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
		_environment.ssao_enabled = bool(q["ssao"])
		_environment.ssao_intensity = float(spec["ssao_intensity"]) * float(q["ssao_scale"])
		_environment.ssil_enabled = bool(q["ssil"])
		_environment.ssil_intensity = float(spec["ssil_intensity"]) * float(q["ssil_scale"])
		_environment.volumetric_fog_enabled = bool(q["volumetric_fog"])
		_environment.glow_enabled = bool(q["glow"])
		_environment.glow_bloom = float(spec["glow_bloom"])
		_environment.glow_hdr_threshold = maxf(float(spec["glow_hdr_threshold"]), GLOW_HDR_THRESHOLD_MIN)
	var vol_root := get_node_or_null("VolumetricGodRays") as Node3D
	if vol_root != null:
		vol_root.visible = bool(q["volumetric_fog"])
	var show_particles := bool(q["particles"])
	for p in _particles:
		if not is_instance_valid(p):
			continue
		p.visible = show_particles
		if not show_particles:
			p.emitting = false
	var show_haze := bool(q["heat_haze"])
	for h in _haze_nodes:
		if is_instance_valid(h):
			h.visible = show_haze
	var parent_node := get_parent()
	if parent_node != null:
		var sun := parent_node.get_node_or_null("SunKey") as DirectionalLight3D
		if sun != null:
			sun.directional_shadow_max_distance = float(q["shadow_max_distance"])
			sun.shadow_bias = float(q["shadow_bias"])
			sun.shadow_normal_bias = float(q["shadow_normal_bias"])
	if show_particles:
		apply_accessibility()
	return {
		"tier": quality_tier,
		"ssao": _environment.ssao_enabled if _environment != null else false,
		"ssil": _environment.ssil_enabled if _environment != null else false,
		"volumetric_fog": _environment.volumetric_fog_enabled if _environment != null else false,
		"glow": _environment.glow_enabled if _environment != null else false,
		"particles": show_particles,
		"heat_haze": show_haze,
		"shadow_max_distance": float(q["shadow_max_distance"]),
		"shadow_bias": float(q["shadow_bias"]),
		"shadow_normal_bias": float(q["shadow_normal_bias"]),
	}


func get_environment_resource() -> Environment:
	return _environment


func bind_bounce_pool(pool_root: Node3D) -> int:
	_bounce_lights.clear()
	if pool_root == null:
		return 0
	for child in pool_root.get_children():
		var omni := child as OmniLight3D
		if omni == null:
			continue
		var spec: Dictionary = BOUNCE_SPECS.get(String(omni.name), {})
		if not spec.is_empty():
			omni.light_color = spec["color"]
			omni.light_energy = float(spec["energy"])
			omni.omni_range = float(spec["range"])
			omni.omni_attenuation = float(spec["attenuation"])
		omni.shadow_enabled = false
		omni.light_specular = 0.25
		_bounce_lights.append({
			"light": omni,
			"base_energy": omni.light_energy,
			"pulse_hz": float(spec.get("pulse_hz", 0.42)),
			"amp": float(spec.get("amp", 0.12)),
		})
	apply_accessibility()
	return _bounce_lights.size()


func apply_accessibility() -> void:
	for p in _particles:
		if not is_instance_valid(p):
			continue
		var cosmetic_spark := String(p.name).begins_with("Ember")
		if Comfort.reduced_motion:
			p.speed_scale = 0.0
			if cosmetic_spark:
				p.emitting = false
		else:
			p.speed_scale = 1.0
			p.emitting = true
	for mat in _haze_materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("reduced_motion", 1.0 if Comfort.reduced_motion else 0.0)
			mat.set_shader_parameter("reduce_flashes", 1.0 if FlashGuard.on else 0.0)
	for entry in _bounce_lights:
		var omni: OmniLight3D = entry["light"]
		if is_instance_valid(omni):
			var base_e: float = entry["base_energy"]
			omni.light_energy = FlashGuard.spike(base_e * 0.85, base_e)


func step_atmosphere(delta: float) -> void:
	if not _built or delta <= 0.0:
		return
	if not Comfort.reduced_motion:
		_anim_time += delta
	for i in _cables.size():
		var entry: Dictionary = _cables[i]
		var cable: MeshInstance3D = entry["node"]
		if not is_instance_valid(cable):
			continue
		var base_pos: Vector3 = entry["base_pos"]
		if Comfort.reduced_motion:
			cable.position = base_pos
		else:
			var sway_amt: float = entry["sway"]
			var sway_dir: Vector3 = entry["sway_dir"]
			var phase := _anim_time * 0.85 + float(i) * 1.4
			cable.position = base_pos + sway_dir * (sin(phase) * sway_amt)
	for mat in _haze_materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("reduced_motion", 1.0 if Comfort.reduced_motion else 0.0)
			mat.set_shader_parameter("reduce_flashes", 1.0 if FlashGuard.on else 0.0)
	for i in _bounce_lights.size():
		var entry: Dictionary = _bounce_lights[i]
		var omni: OmniLight3D = entry["light"]
		if not is_instance_valid(omni):
			continue
		var base_e: float = entry["base_energy"]
		if Comfort.reduced_motion:
			omni.light_energy = FlashGuard.spike(base_e * 0.85, base_e)
		else:
			var hz := FlashGuard.rate(float(entry["pulse_hz"]))
			var amp: float = entry["amp"]
			var wave := 0.5 + 0.5 * sin(_anim_time * TAU * hz + float(i) * 0.9)
			var rest := base_e * (1.0 - amp * 0.5)
			var peak := base_e * (1.0 + amp * wave)
			omni.light_energy = FlashGuard.spike(rest, peak)


func get_particle_systems() -> Array[GPUParticles3D]:
	return _particles.duplicate()


func get_cable_nodes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for entry in _cables:
		out.append(entry["node"] as MeshInstance3D)
	return out


func get_heat_haze_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for node in _haze_nodes:
		if is_instance_valid(node):
			out.append(node.position)
	return out


func get_bounce_lights() -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	for entry in _bounce_lights:
		var omni: OmniLight3D = entry["light"]
		if is_instance_valid(omni):
			out.append(omni)
	return out


func _apply_environment_to_scene(env: Environment) -> void:
	var we: WorldEnvironment = null
	if get_parent() != null:
		we = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		we = get_node_or_null("RigWorldEnvironment") as WorldEnvironment
	if we == null:
		we = WorldEnvironment.new()
		we.name = "RigWorldEnvironment"
		add_child(we)
	we.environment = env


func _enhance_showcase_surfaces() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var floor_mesh := parent_node.get_node_or_null("CombatLaneFloor/FloorMesh") as MeshInstance3D
	if floor_mesh != null and floor_mesh.mesh is BoxMesh:
		var mat := (floor_mesh.mesh as BoxMesh).material as StandardMaterial3D
		if mat != null:
			PaletteMaterials.surface_grain(mat)
			mat.normal_scale = 0.25
			mat.roughness = 0.86


func _build_fog_volumes() -> void:
	var volumes_root := Node3D.new()
	volumes_root.name = "VolumetricFogVolumes"
	add_child(volumes_root)

	var gantry_vol := FogVolume.new()
	gantry_vol.name = "GantryGodRayVolume"
	gantry_vol.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	gantry_vol.size = Vector3(58.0, 17.0, 22.0)
	gantry_vol.position = Vector3(-4.0, 15.5, -36.0)
	var gantry_mat := FogMaterial.new()
	gantry_mat.density = 0.022
	gantry_mat.albedo = Color("e4be8a")
	gantry_mat.edge_fade = 0.35
	gantry_vol.material = gantry_mat
	volumes_root.add_child(gantry_vol)


func _build_particles() -> void:
	var fx_root := Node3D.new()
	fx_root.name = "LivingAirParticles"
	add_child(fx_root)

	var embers := GPUParticles3D.new()
	embers.name = "EmberParticles"
	embers.position = Vector3(0.0, 3.0, -29.0)
	embers.amount = 48
	embers.lifetime = 5.5
	embers.preprocess = 2.0
	embers.visibility_aabb = AABB(Vector3(-34.0, -2.0, -14.0), Vector3(68.0, 26.0, 28.0))
	var ember_proc := ParticleProcessMaterial.new()
	ember_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ember_proc.emission_box_extents = Vector3(28.0, 1.5, 4.0)
	ember_proc.direction = Vector3(0.22, 1.0, 0.08)
	ember_proc.spread = 24.0
	ember_proc.gravity = Vector3(0.18, 0.35, 0.0)
	ember_proc.initial_velocity_min = 1.2
	ember_proc.initial_velocity_max = 2.8
	ember_proc.scale_min = 0.7
	ember_proc.scale_max = 1.4
	embers.process_material = ember_proc
	var ember_mesh := QuadMesh.new()
	ember_mesh.size = Vector2(0.16, 0.16)
	ember_mesh.material = _make_particle_mat(Palette.SODIUM.lerp(Palette.AMBER, 0.4), 0.9, 1.8)
	embers.draw_pass_1 = ember_mesh
	fx_root.add_child(embers)
	_particles.append(embers)

	var dust := GPUParticles3D.new()
	dust.name = "DustMotesParticles"
	dust.position = Vector3(0.0, 12.5, -8.0)
	dust.amount = 72
	dust.lifetime = 8.0
	dust.preprocess = 3.0
	dust.visibility_aabb = AABB(Vector3(-36.0, -8.0, -32.0), Vector3(72.0, 18.0, 64.0))
	var dust_proc := ParticleProcessMaterial.new()
	dust_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_proc.emission_box_extents = Vector3(26.0, 4.5, 22.0)
	dust_proc.direction = Vector3(1.0, -0.08, 0.25)
	dust_proc.spread = 32.0
	dust_proc.gravity = Vector3(0.05, -0.04, 0.0)
	dust_proc.initial_velocity_min = 0.35
	dust_proc.initial_velocity_max = 0.85
	dust_proc.scale_min = 0.6
	dust_proc.scale_max = 1.3
	dust.process_material = dust_proc
	var dust_mesh := QuadMesh.new()
	dust_mesh.size = Vector2(0.14, 0.14)
	dust_mesh.material = _make_particle_mat(Palette.SAND, 0.22, 0.0)
	dust.draw_pass_1 = dust_mesh
	fx_root.add_child(dust)
	_particles.append(dust)

	var wispy_tex := _make_wispy_steam_texture(64)
	for side in [{"name": "SteamVentParticles_W", "pos": Vector3(-33.5, 5.5, -27.5)}, {"name": "SteamVentParticles_E", "pos": Vector3(33.5, 5.5, -27.5)}]:
		var steam := GPUParticles3D.new()
		steam.name = side["name"]
		steam.position = side["pos"]
		steam.amount = 48
		steam.lifetime = 5.2
		steam.preprocess = 2.6
		steam.visibility_aabb = AABB(Vector3(-10.0, -1.0, -10.0), Vector3(20.0, 26.0, 20.0))
		var steam_proc := ParticleProcessMaterial.new()
		steam_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		steam_proc.emission_sphere_radius = 1.2
		steam_proc.direction = Vector3(0.24, 1.0, -0.15)
		steam_proc.spread = 20.0
		steam_proc.gravity = Vector3(0.28, 0.18, 0.0)
		steam_proc.initial_velocity_min = 0.85
		steam_proc.initial_velocity_max = 1.45
		steam_proc.scale_min = 0.9
		steam_proc.scale_max = 1.7
		steam.process_material = steam_proc
		var steam_mesh := QuadMesh.new()
		steam_mesh.size = Vector2(3.8, 3.8)
		var steam_mat := _make_particle_mat(Color("cbbba6"), 0.065, 0.0)
		steam_mat.albedo_texture = wispy_tex
		steam_mesh.material = steam_mat
		steam.draw_pass_1 = steam_mesh
		fx_root.add_child(steam)
		_particles.append(steam)


func _build_catenary_cables() -> void:
	var cables_root := Node3D.new()
	cables_root.name = "CatenaryCables"
	add_child(cables_root)

	var cable_mat := StandardMaterial3D.new()
	cable_mat.albedo_color = Palette.CABLE
	cable_mat.roughness = 0.78
	cable_mat.metallic = 0.25

	for span in CATENARY_SPANS:
		var a: Vector3 = span["a"]
		var b: Vector3 = span["b"]
		var sag: float = span["sag"]
		var mid := (a + b) * 0.5
		var local_a := a - mid
		var local_b := b - mid

		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs := 16
		var radius := 0.14
		for i in segs:
			var t0 := float(i) / float(segs)
			var t1 := float(i + 1) / float(segs)
			var p0 := local_a.lerp(local_b, t0) - Vector3(0.0, sag * 4.0 * t0 * (1.0 - t0), 0.0)
			var p1 := local_a.lerp(local_b, t1) - Vector3(0.0, sag * 4.0 * t1 * (1.0 - t1), 0.0)
			_append_cable_segment(st, p0, p1, radius)
		st.generate_normals()

		var mi := MeshInstance3D.new()
		mi.name = span["name"]
		mi.mesh = st.commit()
		mi.material_override = cable_mat
		mi.position = mid
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		cables_root.add_child(mi)

		var run_dir := (b - a).normalized()
		var sway_dir := run_dir.cross(Vector3.UP).normalized()
		if sway_dir.length_squared() < 0.01:
			sway_dir = Vector3.RIGHT
		_cables.append({
			"node": mi,
			"base_pos": mid,
			"sway": float(span["sway"]),
			"sway_dir": sway_dir,
		})


func _build_heat_haze_vents() -> void:
	var haze_root := Node3D.new()
	haze_root.name = "HeatHazeVents"
	add_child(haze_root)

	for vent in HEAT_HAZE_VENTS:
		var mat := ShaderMaterial.new()
		mat.shader = HEAT_HAZE_SHADER
		mat.set_shader_parameter("distortion_strength", 0.0085)
		mat.set_shader_parameter("rise_speed", 1.35)
		mat.set_shader_parameter("tint_color", Palette.SODIUM)
		mat.set_shader_parameter("tint_strength", 0.08)
		mat.set_shader_parameter("opacity", 0.76)

		var quad := QuadMesh.new()
		quad.size = vent["size"]
		var mi := MeshInstance3D.new()
		mi.name = vent["name"]
		mi.mesh = quad
		mi.material_override = mat
		mi.position = vent["pos"]
		mi.rotation_degrees = Vector3(0.0, float(vent["yaw_deg"]), 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		haze_root.add_child(mi)
		_haze_nodes.append(mi)
		_haze_materials.append(mat)


func _make_particle_mat(color: Color, alpha: float, emit: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.albedo_texture = _soft_disc
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emit
	return mat


static func _make_wispy_steam_texture(dim: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 319
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.065
	noise.fractal_octaves = 3
	var img := Image.create_empty(dim, dim, false, Image.FORMAT_RGBA8)
	var half := float(dim - 1) * 0.5
	for y in dim:
		for x in dim:
			var dx := (float(x) - half) / half
			var dy := (float(y) - half) / half
			var r := sqrt(dx * dx + dy * dy)
			var env := clampf(1.0 - smoothstep(0.05, 0.96, r), 0.0, 1.0)
			var n := 0.5 + 0.5 * noise.get_noise_2d(float(x) * 1.4, float(y) * 1.4)
			var a := pow(env, 1.8) * smoothstep(0.22, 0.85, n)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _make_soft_disc_texture(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var dx := (float(x) + 0.5 - half) / half
			var dy := (float(y) + 0.5 - half) / half
			var r := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - smoothstep(0.15, 1.0, r), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	return ImageTexture.create_from_image(img)


static func _append_cable_segment(st: SurfaceTool, a: Vector3, b: Vector3, radius: float) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.001:
		return
	var dir := delta / length
	var ref_up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var side := dir.cross(ref_up).normalized() * radius
	var up := side.cross(dir).normalized() * radius
	var ring: Array[Vector3] = [side, up, -side, -up]
	for i in 4:
		var ni := (i + 1) % 4
		var a0: Vector3 = a + ring[i]
		var a1: Vector3 = a + ring[ni]
		var b0: Vector3 = b + ring[i]
		var b1: Vector3 = b + ring[ni]
		st.add_vertex(a0); st.add_vertex(b0); st.add_vertex(b1)
		st.add_vertex(a0); st.add_vertex(b1); st.add_vertex(a1)
