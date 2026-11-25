extends PanelContainer

const INK := Color("17141a")
const STAND := 10.5
const EYE := 0.9
const LIFT := 2.5
const LENS := 64.0
const REACH := 700.0
const FOCUS_LINES := 30
const FOCUS_BOIL_MS := 90

var still := false

var _subject: Node3D
var _camera: Camera3D
var _focus: Control


func frame(subject: Node3D, home: Vector3, toward: Vector3, extent: Vector2, border: int) -> void:
	_subject = subject
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = INK
	box.border_color = INK
	box.set_border_width_all(border)
	box.set_content_margin_all(0.0)
	box.shadow_color = INK
	box.shadow_offset = Vector2(border, border) * 1.2
	box.shadow_size = 1
	add_theme_stylebox_override("panel", box)
	custom_minimum_size = extent
	size = extent
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var view := SubViewport.new()
	view.name = "InsetView"
	view.size = Vector2i(extent)
	var screen := get_viewport()
	view.world_3d = screen.find_world_3d()
	view.msaa_3d = screen.msaa_3d
	view.mesh_lod_threshold = screen.mesh_lod_threshold
	view.physics_object_picking = false
	view.handle_input_locally = false
	holder.add_child(view)
	_camera = Camera3D.new()
	_camera.fov = LENS
	var play := screen.get_camera_3d()
	_camera.far = play.far if play != null else REACH
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.add_child(_camera)
	var out := Vector3(toward.x - home.x, 0.0, toward.z - home.z)
	out = out.normalized() if out.length() > 0.1 else Vector3.BACK
	_camera.global_position = home + out * STAND + Vector3.UP * EYE
	_camera.current = true
	_aim()
	_focus = Focus.new()
	_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus.clip_contents = true
	add_child(_focus)


func looks_at() -> Vector3:
	return -_camera.global_basis.z if _camera != null else Vector3.ZERO


func stands_at() -> Vector3:
	return _camera.global_position if _camera != null else Vector3.ZERO


func _process(_delta: float) -> void:
	_aim()
	var beat := 0 if still else int(Time.get_ticks_msec() / FOCUS_BOIL_MS)
	if _focus != null and beat != _focus.beat:
		_focus.beat = beat
		_focus.queue_redraw()


func _aim() -> void:
	if _camera == null or not is_instance_valid(_subject) or not _subject.is_inside_tree():
		return
	var at := _subject.global_position + Vector3.UP * LIFT
	if at.distance_to(_camera.global_position) > 0.5:
		_camera.look_at(at, Vector3.UP)


class Focus extends Control:
	var beat := 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 + beat
		var centre := size * 0.5
		var reach := size.length() * 0.5
		for i in FOCUS_LINES:
			var angle := TAU * (i + rng.randf_range(-0.35, 0.35)) / FOCUS_LINES
			var along := Vector2.from_angle(angle)
			var across := along.orthogonal() * rng.randf_range(2.0, 7.0) * size.y / 288.0
			var tip := centre + along * reach * rng.randf_range(0.52, 0.74)
			var root := centre + along * reach * 1.05
			draw_colored_polygon(PackedVector2Array([root - across, root + across, tip]), Color(INK, 0.82))
