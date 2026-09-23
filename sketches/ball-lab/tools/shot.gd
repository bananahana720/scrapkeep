extends SceneTree

const Lab := preload("res://src/lab.gd")

var _lab
var _frames := 0


func _initialize() -> void:
	_lab = Lab.new()
	_lab.test_mode = true
	root.add_child(_lab)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 40:
		return false
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://ball_lab_shot.png"
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path), " ", image.get_size())
	_lab.free()
	quit(0)
	return true
