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
	quit(1 if failed else 0)
