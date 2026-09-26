extends SceneTree

const Lab := preload("res://src/lab.gd")

# The grapple rig and the magnet walls are placed by arithmetic against the height
# field, so they are worth looking at once from somewhere other than the spawn.
const VIEWS := [
	{"name": "grapple_rig", "from": Vector3(10.0, 62.0, 96.0), "at": Vector3(-62.0, 24.0, 28.0)},
	{"name": "magnet_walls", "from": Vector3(22.0, 46.0, 8.0), "at": Vector3(78.0, 14.0, 40.0)},
]

var _lab
var _camera: Camera3D
var _frames := 0
var _index := 0


func _initialize() -> void:
	_lab = Lab.new()
	_lab.test_mode = true
	root.add_child(_lab)
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.far = 900.0
	root.add_child(_camera)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 30:
		return false
	var view: Dictionary = VIEWS[_index]
	_camera.global_position = view["from"]
	_camera.look_at(view["at"], Vector3.UP)
	_camera.current = true
	if _frames < 34:
		return false
	var prefix: PackedStringArray = OS.get_cmdline_user_args()
	var path := "%s_%s.png" % [prefix[0] if prefix.size() > 0 else "user://rig", view["name"]]
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path), " ", image.get_size())
	_index += 1
	_frames = 0
	if _index < VIEWS.size():
		return false
	_lab.free()
	quit(0)
	return true
