extends SceneTree
const Preset := preload("res://src/presentation/graphics_preset.gd")
var failed := false
func check(ok: bool, what: String) -> void:
	print("PASS " if ok else "FAIL ", what)
	failed = failed or not ok
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	var mesh := MeshInstance3D.new()
	root.add_child(mesh)
	Preset.bind(env, sun, root)
	Preset.register_scenery(mesh)
	check(Preset.apply("low") and not env.ssao_enabled and not env.glow_enabled, "low disables screen effects")
	check(sun.directional_shadow_max_distance == 95.0 and mesh.visibility_range_end == 520.0, "low shadow and scenery distances share preset")
	check(root.msaa_3d == Viewport.MSAA_2X, "low retains 1080p with 2x MSAA")
	check(Preset.apply("high") and env.ssao_enabled and env.glow_enabled, "high restores effects")
	check(mesh.visibility_range_end == 780.0 and sun.directional_shadow_max_distance == 180.0, "high restores distances")
	check(not Preset.apply("unknown") and Preset.current == "high", "unknown preset preserves current configuration")
	mesh.free()
	sun.free()
	check(Preset.apply("low"), "switch after scene disposal drops dead bindings")
	_target_checks()
	quit(1 if failed else 0)


func _target_checks() -> void:
	var env := Environment.new()
	env.sky = Sky.new()
	var sky_material := PanoramaSkyMaterial.new()
	env.sky.sky_material = sky_material
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	var mesh := MeshInstance3D.new()
	root.add_child(mesh)
	Preset.bind(env, sun, root)
	Preset.register_scenery(mesh)
	var spec: Dictionary = Preset.PRESETS.target
	check(Preset.apply("target") and not env.sdfgi_enabled and not env.ssil_enabled and not env.volumetric_fog_enabled, "target removes global veil and unqualified GI")
	check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and is_equal_approx(sun.light_angular_distance, 0.0), "target restores high shadow filtering")
	check(spec.sun_rotation == Preset.PRESETS.high.sun_rotation and sun.rotation_degrees.is_equal_approx(Vector3(-36, -55, 0)), "target pins the play-shadow sun elevation and direction")
	check(sun.directional_shadow_max_distance == 180.0 and is_equal_approx(sun.shadow_normal_bias, 0.65) and is_equal_approx(sun.directional_shadow_split_1, 0.18), "target pins proven shadow reach, bias and split")
	check(is_equal_approx(env.fog_density, 0.0006) and env.fog_aerial_perspective == 0.0 and not env.volumetric_fog_enabled, "target has high fog without the middle-distance veil")
	check(is_equal_approx(env.tonemap_exposure, 1.1) and env.tonemap_agx_contrast == 1.25 and is_equal_approx(env.adjustment_saturation, 1.2) and sun.light_color == Color("ffd49a"), "target pins high contrast, exposure and colour")
	check(root.msaa_3d == Viewport.MSAA_4X and mesh.visibility_range_end == 780.0, "target keeps high geometry reach and MSAA")
	for key in spec.environment:
		var actual = env.get(key)
		var expected = spec.environment[key]
		check(is_equal_approx(actual, expected) if expected is float else actual == expected, "target Environment." + key)
	for key in spec.sun_properties:
		var actual = sun.get(key)
		var expected = spec.sun_properties[key]
		check(is_equal_approx(actual, expected) if expected is float else actual == expected, "target sun." + key)
	check(env.sky.sky_material == sky_material, "target retains authored sky material")
	for key in spec.sky_properties:
		check(env.sky.get(key) == spec.sky_properties[key], "target Sky." + key)
	for key in ["sdfgi", "ssil", "volumetric_fog"]:
		var modified: Dictionary = spec.duplicate(true)
		modified[key] = not spec[key]
		var world := {"environment": env, "sun": weakref(sun), "viewport": weakref(root)}
		Preset._apply_target(world, modified, env, sun)
		check(env.sdfgi_enabled == modified.sdfgi and env.ssil_enabled == modified.ssil and env.volumetric_fog_enabled == modified.volumetric_fog, "target independently switches " + key)
		Preset._restore_target(world)
	check(Preset.apply("target") and not env.sdfgi_enabled, "target reapplication preserves its effects")
	check(Preset.apply("high") and not env.sdfgi_enabled and not env.ssil_enabled and not env.volumetric_fog_enabled, "leaving target disables its effects")
	check(is_equal_approx(sun.light_angular_distance, 0.0) and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "leaving target restores established shadows")
	var defaults := Environment.new()
	check(env.volumetric_fog_density == defaults.volumetric_fog_density and env.ssil_radius == defaults.ssil_radius, "leaving target restores properties high never touched")
	check(Preset.apply("target") and Preset.apply("low") and not env.sdfgi_enabled and root.msaa_3d == Viewport.MSAA_2X, "target to low restores low effects and MSAA")
	mesh.free()
	sun.free()
