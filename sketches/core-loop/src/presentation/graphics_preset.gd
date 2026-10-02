extends RefCounted

# Settings are applied on bind or an explicit preset change, never polled each frame.
const PRESETS := {
	"high": {"ssao": true, "glow": true, "shadow_distance": 180.0, "shadow_mode": 1,
		"scenery_distance": 780.0, "lod_threshold": 1.0, "msaa": 2,
		"ambient": 0.28, "sun": 2.35, "fog": 0.0006, "sun_rotation": Vector3(-36.0, -55.0, 0.0), "ssao_quality": 2, "fill": 0.5},
	"low": {"ssao": false, "glow": false, "shadow_distance": 95.0, "shadow_mode": 1,
		"scenery_distance": 520.0, "lod_threshold": 4.0, "msaa": 1,
		"ambient": 0.28, "sun": 2.35, "fog": 0.0006, "sun_rotation": Vector3(-36.0, -55.0, 0.0), "ssao_quality": 0, "fill": 0.5},
}
static var current := "high"
static var _worlds: Array = []
static var _scenery: Array = []

static func apply(preset: String) -> bool:
	if not PRESETS.has(preset):
		return false
	current = preset
	_worlds = _worlds.filter(func(w): return w.sun.get_ref() != null)
	for world in _worlds:
		_apply_world(world)
	_scenery = _scenery.filter(func(w): return w.get_ref() != null)
	for ref in _scenery:
		_apply_scenery(ref.get_ref())
	return true

static func bind(environment: Environment, sun: DirectionalLight3D, viewport: Viewport) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preset=") and PRESETS.has(arg.trim_prefix("--preset=")):
			current = arg.trim_prefix("--preset=")
	var world := {"environment": environment, "sun": weakref(sun), "viewport": weakref(viewport)}
	_worlds.append(world)
	_apply_world(world)

static func register_scenery(view: GeometryInstance3D) -> void:
	_scenery.append(weakref(view))
	_apply_scenery(view)

static func _apply_scenery(view: GeometryInstance3D) -> void:
	view.visibility_range_end = PRESETS[current].scenery_distance
	view.visibility_range_end_margin = 30.0
	view.lod_bias = 1.0 / PRESETS[current].lod_threshold

static func _apply_world(world: Dictionary) -> void:
	var spec: Dictionary = PRESETS[current]
	var env: Environment = world.environment
	var sun: DirectionalLight3D = world.sun.get_ref()
	var viewport: Viewport = world.viewport.get_ref()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9db5cf")
	env.ambient_light_sky_contribution = 0.25
	env.ambient_light_energy = spec.ambient
	# AgX with a fixed exposure; auto exposure and SDFGI/SSIL/SSR stay off.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.tonemap_agx_white = 16.29
	env.tonemap_agx_contrast = 1.25
	env.ssao_enabled = spec.ssao
	env.ssao_radius = 0.45
	env.ssao_intensity = 1.15
	env.ssao_power = 1.25
	env.ssao_detail = 0.35
	env.ssao_sharpness = 0.85
	env.ssao_light_affect = 0.05
	env.ssao_ao_channel_affect = 0.0
	RenderingServer.environment_set_ssao_quality(spec.ssao_quality, true, 0.5, 2.0, 50.0, 300.0)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.sdfgi_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.glow_enabled = spec.glow
	env.glow_intensity = 0.18
	env.glow_hdr_threshold = 1.5
	env.fog_enabled = true
	env.fog_density = spec.fog
	env.fog_light_color = Color("a3bdd0")
	env.fog_light_energy = 0.75
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.0
	env.fog_sun_scatter = 0.25
	env.volumetric_fog_enabled = false
	sun.rotation_degrees = spec.sun_rotation
	sun.light_color = Color("ffd49a")
	sun.directional_shadow_split_1 = 0.18
	# PCSS (angular distance above 0) samples the hoop's shadow on the pilot's head with visible
	# noise; the smooth high-quality filter blurs it without any.
	sun.light_angular_distance = 0.0
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	sun.shadow_blur = 1.0
	_apply_fill(sun, spec)
	sun.light_energy = spec.sun
	sun.directional_shadow_max_distance = spec.shadow_distance
	sun.directional_shadow_mode = spec.shadow_mode
	sun.shadow_normal_bias = 0.65
	sun.directional_shadow_blend_splits = true
	if viewport != null:
		viewport.msaa_3d = spec.msaa
		viewport.mesh_lod_threshold = spec.lod_threshold


# One shadowless cool directional fill opposite the sun (LIGHTING-TARGETS: elevation 50,
# azimuth 298). It is a sibling of the world sun, so the sun stays the only shadow caster.
static func _apply_fill(sun: DirectionalLight3D, spec: Dictionary) -> void:
	var parent := sun.get_parent()
	if parent == null:
		return
	var fill := parent.get_node_or_null("SkyFill") as DirectionalLight3D
	if fill == null:
		fill = DirectionalLight3D.new()
		fill.name = "SkyFill"
		fill.shadow_enabled = false
		fill.rotation_degrees = Vector3(-50.0, spec.sun_rotation.y + 180.0, 0.0)
		fill.light_color = Color("a3c4e6")
		fill.light_specular = 0.0
		parent.add_child(fill)
	# Opposite the sun's yaw, so the wall faces the key misses get cool light.
	fill.rotation_degrees = Vector3(-50.0, spec.sun_rotation.y + 180.0, 0.0)
	fill.light_energy = spec.fill

