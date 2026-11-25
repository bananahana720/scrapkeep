extends SceneTree


const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const ClassDef := preload("res://src/core/class_def.gd")

var _frames := 0
var _out := ""
var _pilot := "pylon_engineer"
var _paints := ["", "paint_sable_lagoon", "paint_any_salt"]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--pilot="):
			_pilot = arg.trim_prefix("--pilot=")
		elif arg.begins_with("--paints="):
			_paints = Array(arg.trim_prefix("--paints=").split(","))
			_paints = _paints.map(func(p): return "" if p == "none" else p)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("6f7a80")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c8d0d8")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.4
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.look_at_from_position(Vector3(0, 1.6, 5.6), Vector3(0, 0.45, 0))
	cam.fov = 50
	world.add_child(cam)

	var hook := HeroAssets.new()
	var def = ClassDef.by_id(_pilot)
	for i in _paints.size():
		var ball := Node3D.new()
		ball.position = Vector3((i - (_paints.size() - 1) * 0.5) * 2.15, 0.55, 0)
		ball.rotation_degrees = Vector3(0, 25, 0)
		world.add_child(ball)
		var tints := {"class": def.color}
		if _paints[i] != "":
			tints["paint"] = Cosmetics.row(_paints[i])["tint"]
		var rec: Dictionary = hook.fit_shell_into(ball, _pilot, "", 1, tints)
		if rec.is_empty():
			push_error("no shell for " + _pilot)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	var img := root.get_texture().get_image()
	img.save_png(_out)
	print("saved ", _out)
	return true
