extends SceneTree

const Stage := preload("res://src/stage.gd")

# Windowed only, and deliberately not under tests/: it is the spot check that the
# terrain is visible and the right way up, since a trimesh with inverted winding
# is invisible from above and has no collision either.
#
#   <godot> --path sketches/spillway-drop --script res://tools/shot.gd -- /tmp/a.png
#   <godot> --path sketches/spillway-drop --script res://tools/shot.gd -- /tmp/b.png overview

const OVERVIEW_EYE := Vector3(-40.0, 250.0, 330.0)
const OVERVIEW_AIM := Vector3(20.0, 10.0, -30.0)

var _stage
var _frames := 0


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


func _overview() -> bool:
	var args := OS.get_cmdline_user_args()
	return args.size() > 1 and args[1] == "overview"


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 50 and _overview():
		_stage.camera.cam.current = false
		var eye := Camera3D.new()
		eye.far = 1200.0
		eye.fov = 70.0
		root.add_child(eye)
		eye.global_position = OVERVIEW_EYE
		eye.look_at(OVERVIEW_AIM, Vector3.UP)
		eye.current = true
		return false
	if _frames < 70:
		return false

	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://spillway_drop_shot.png"
	print("ball ", _stage.player.ball_position(), "  camera ", _stage.camera.global_position,
		"  arm ", _stage.camera.arm.spring_length, "  hit ", _stage.camera.arm.get_hit_length())
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path), " ", image.get_size())
	_stage.free()
	quit(0)
	return true
