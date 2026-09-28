extends RefCounted

# Settings are applied on bind or an explicit preset change, never polled each frame.
const PRESETS := {
	"high": {"ssao": true, "glow": true, "shadow_distance": 180.0, "shadow_mode": 2,
		"scenery_distance": 780.0, "lod_threshold": 1.0, "msaa": 2,
		"ambient": 0.42, "sun": 2.0, "fog": 0.00065, "sun_rotation": Vector3(-42.0, -48.0, 0.0)},
	"low": {"ssao": false, "glow": false, "shadow_distance": 95.0, "shadow_mode": 1,
		"scenery_distance": 520.0, "lod_threshold": 4.0, "msaa": 1,
		"ambient": 0.42, "sun": 2.0, "fog": 0.00065, "sun_rotation": Vector3(-42.0, -48.0, 0.0)},
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
	env.ambient_light_color = Color("a4bace")
	env.ambient_light_sky_contribution = 0.25
	env.ambient_light_energy = spec.ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.ssao_enabled = spec.ssao
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.35
	env.ssao_power = 1.35
	env.ssao_light_affect = 0.12
	env.glow_enabled = spec.glow
	env.glow_intensity = 0.18
	env.glow_hdr_threshold = 1.5
	env.fog_enabled = true
	env.fog_density = spec.fog
	env.fog_light_color = Color("819faf")
	env.fog_sky_affect = 0.08
	env.fog_aerial_perspective = 0.25
	env.volumetric_fog_enabled = false
	sun.rotation_degrees = spec.sun_rotation
	sun.light_color = Color("ffdfb5")
	sun.light_energy = spec.sun
	sun.directional_shadow_max_distance = spec.shadow_distance
	sun.directional_shadow_mode = spec.shadow_mode
	sun.shadow_normal_bias = 0.65
	sun.directional_shadow_blend_splits = true
	if viewport != null:
		viewport.msaa_3d = spec.msaa
		viewport.mesh_lod_threshold = spec.lod_threshold
