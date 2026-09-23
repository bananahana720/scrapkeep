extends SceneTree

const Stage := preload("res://src/stage.gd")

# Windowed only: it opens a real window to render. Kept out of tests/ so the
# headless smoke run never picks it up.

var _stage
var _frames := 0


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 90:
		return false
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://cable_bench_shot.png"
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path), " ", image.get_size())
	# The ball can be out of frame: chase_camera.gd rewrites cam.position every idle
	# frame, so a capture can land on a frame where the spring arm has not replaced it.
	print("ball ", _stage.player.ball_position(), " camera ", _stage.camera.cam.global_position)
	_stage.free()
	quit(0)
	return true
