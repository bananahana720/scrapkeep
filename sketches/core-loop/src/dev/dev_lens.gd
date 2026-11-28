extends Node3D

const MODES := {
	"game": {"blurb": "the game's own chase camera"},
	"orbit": {"blurb": "free orbit around the ball: drag with the right mouse button, wheel to zoom",
		"yaw": 0.0, "pitch": -24.0, "distance": 14.0, "fov": 55.0},
	"iso": {"blurb": "isometric diorama: orthographic, 35 degrees down, 45 degrees off the chase heading",
		"yaw": 45.0, "pitch": -35.264, "distance": 60.0, "ortho": true, "size": 34.0},
	"side": {"blurb": "2.5D side-scroller: orthographic, level with the ball, square to its heading",
		"yaw": 90.0, "pitch": -10.0, "distance": 90.0, "ortho": true, "size": 26.0, "lift": 3.0},
	"top": {"blurb": "top-down arena read: straight down, orthographic",
		"yaw": 0.0, "pitch": -89.0, "distance": 70.0, "ortho": true, "size": 48.0},
	"hero": {"blurb": "low hero angle: knee height behind the ball, long lens",
		"yaw": 0.0, "pitch": 6.0, "distance": 7.0, "fov": 38.0, "lift": -0.4},
	"high": {"blurb": "high chase: a tactics view that keeps the ball and its threats in one frame",
		"yaw": 0.0, "pitch": -52.0, "distance": 26.0, "fov": 50.0},
	"cinema": {"blurb": "slow turntable around the ball for stills and reels",
		"yaw": 0.0, "pitch": -14.0, "distance": 18.0, "fov": 34.0, "spin": 9.0},
}
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 400.0
const DRAG_SCALE := 0.25
const WHEEL_STEP := 1.12
const FOLLOW_RATE := 10.0
const CUTAWAY := 14.0
const LENS_KNOBS := ["fov", "distance", "pitch", "yaw", "size", "lift", "spin", "tilt", "cut"]
const LENS_RANGES := {
	"fov": [10.0, 120.0, 0.5],
	"distance": [MIN_DISTANCE, MAX_DISTANCE, 0.5],
	"pitch": [-89.5, 60.0, 0.5],
	"yaw": [-180.0, 180.0, 1.0],
	"size": [2.0, 300.0, 0.5],
	"lift": [-5.0, 30.0, 0.1],
	"spin": [-90.0, 90.0, 1.0],
	"tilt": [0.0, 1.0, 0.01],
	"cut": [0.0, 200.0, 0.5],
}

var game
var mode := "game"
var yaw := 0.0
var pitch := -24.0
var distance := 14.0
var fov := 55.0
var ortho := false
var ortho_size := 30.0
var lift := 0.0
var spin := 0.0
var tilt_shift := 0.0
var cutaway := CUTAWAY
var follow := true
var _cam: Camera3D
var _held: Camera3D
var _focus := Vector3.ZERO
var _attributes: CameraAttributesPractical
var _dragging := false


func setup(game_ref) -> void:
	game = game_ref
	name = "DevLens"
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	_cam = Camera3D.new()
	_cam.name = "DevCamera"
	_cam.far = 2000.0
	add_child(_cam)
	_attributes = CameraAttributesPractical.new()


func use(id: String) -> String:
	if not MODES.has(id):
		var matches := MODES.keys().filter(func(k: String): return k.begins_with(id))
		if matches.size() != 1:
			return "!no camera '%s' (%s)" % [id, ", ".join(MODES.keys())]
		id = matches[0]
	var row: Dictionary = MODES[id]
	mode = id
	if id == "game":
		_release()
		return "camera: %s" % row.blurb
	yaw = float(row.get("yaw", 0.0))
	pitch = float(row.get("pitch", -24.0))
	distance = float(row.get("distance", 14.0))
	fov = float(row.get("fov", 55.0))
	ortho = bool(row.get("ortho", false))
	ortho_size = float(row.get("size", 30.0))
	lift = float(row.get("lift", 0.0))
	spin = float(row.get("spin", 0.0))
	_focus = _target()
	_take()
	return "camera %s: %s" % [id, row.blurb]


func _exit_tree() -> void:
	if live():
		_release()


func live() -> bool:
	return mode != "game"


func snapshot() -> Dictionary:
	return {"mode": mode, "yaw": yaw, "pitch": pitch, "distance": distance, "fov": fov, "ortho": ortho, "size": ortho_size,
		"lift": lift, "spin": spin, "tilt": tilt_shift, "cut": cutaway, "follow": follow}


func restore(data: Dictionary) -> void:
	var id := String(data.get("mode", "game"))
	if not MODES.has(id):
		id = "game"
	if id == "game":
		if live():
			mode = "game"
			_release()
	elif not live():
		use(id)
	mode = id
	yaw = float(data.get("yaw", yaw))
	pitch = float(data.get("pitch", pitch))
	distance = float(data.get("distance", distance))
	fov = float(data.get("fov", fov))
	ortho = bool(data.get("ortho", ortho))
	ortho_size = float(data.get("size", ortho_size))
	lift = float(data.get("lift", lift))
	spin = float(data.get("spin", spin))
	tilt_shift = float(data.get("tilt", tilt_shift))
	cutaway = float(data.get("cut", cutaway))
	follow = bool(data.get("follow", follow))
	_apply_attributes()


func set_knob(key: String, amount: float) -> String:
	if not key in LENS_KNOBS:
		return "!no camera knob '%s' (%s)" % [key, " ".join(LENS_KNOBS)]
	if not live() and key != "cut":
		use("orbit")
	var span: Array = LENS_RANGES[key]
	var lo := float(span[0])
	var hi := float(span[1])
	match key:
		"fov":
			fov = clampf(amount, lo, hi)
		"distance":
			distance = clampf(amount, lo, hi)
		"pitch":
			pitch = clampf(amount, lo, hi)
		"yaw":
			yaw = wrapf(amount, lo, hi)
		"size":
			ortho_size = clampf(amount, lo, hi)
		"lift":
			lift = clampf(amount, lo, hi)
		"spin":
			spin = clampf(amount, lo, hi)
		"tilt":
			tilt_shift = clampf(amount, lo, hi)
			_apply_attributes()
		"cut":
			cutaway = clampf(amount, lo, hi)
	return "camera %s %.2f" % [key, knob(key)]


func knob(key: String) -> float:
	match key:
		"fov":
			return fov
		"distance":
			return distance
		"pitch":
			return pitch
		"yaw":
			return yaw
		"size":
			return ortho_size
		"lift":
			return lift
		"spin":
			return spin
		"tilt":
			return tilt_shift
		"cut":
			return cutaway
	return 0.0


func set_ortho(on: bool) -> String:
	ortho = on
	if not live():
		use("orbit")
		ortho = on
	return "camera %s" % ("orthographic: flat 2D read, no perspective" if on else "perspective")


func drag(relative: Vector2) -> void:
	if not live():
		return
	var yaw_span: Array = LENS_RANGES["yaw"]
	var pitch_span: Array = LENS_RANGES["pitch"]
	yaw = wrapf(yaw - relative.x * DRAG_SCALE, float(yaw_span[0]), float(yaw_span[1]))
	pitch = clampf(pitch - relative.y * DRAG_SCALE, float(pitch_span[0]), float(pitch_span[1]))


func zoom(steps: float) -> void:
	if not live():
		return
	if ortho:
		var size_span: Array = LENS_RANGES["size"]
		ortho_size = clampf(ortho_size * pow(WHEEL_STEP, steps), float(size_span[0]), float(size_span[1]))
	else:
		var dist_span: Array = LENS_RANGES["distance"]
		distance = clampf(distance * pow(WHEEL_STEP, steps), float(dist_span[0]), float(dist_span[1]))


func handle(event: InputEvent) -> bool:
	if not live():
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			return true
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-1.0)
			return true
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.0)
			return true
	if event is InputEventMouseMotion and _dragging:
		drag(event.relative)
		return true
	return false


func _process(delta: float) -> void:
	if not live():
		return
	var real := delta / maxf(Engine.time_scale, 0.05)
	yaw = wrapf(yaw + spin * real, -180.0, 180.0)
	if follow:
		_focus = _focus.lerp(_target(), 1.0 - exp(-FOLLOW_RATE * real))
	var heading := _heading()
	var turn := Basis.from_euler(Vector3(deg_to_rad(pitch), heading + deg_to_rad(yaw), 0.0))
	var anchor := _focus + Vector3.UP * lift
	_cam.global_transform = Transform3D(turn, anchor + turn.z * distance)
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL if ortho else Camera3D.PROJECTION_PERSPECTIVE
	_cam.size = ortho_size
	_cam.near = maxf(0.05, distance - cutaway) if ortho and cutaway > 0.0 else 0.05
	_cam.fov = fov
	if not _cam.current:
		_cam.current = true
	if tilt_shift > 0.0:
		_attributes.dof_blur_far_distance = maxf(distance * 1.4, 4.0)
		_attributes.dof_blur_near_distance = maxf(distance * 0.55, 0.5)


func _target() -> Vector3:
	if game != null and game.player != null:
		return game.player.shown_position() + Vector3.UP * 0.8
	return global_position


func _heading() -> float:
	if game != null and game.camera != null:
		return float(game.camera.yaw)
	return 0.0


func _take() -> void:
	var current := get_viewport().get_camera_3d()
	if current != _cam:
		_held = current
	_cam.current = true
	_apply_attributes()


func _release() -> void:
	_dragging = false
	var alive: bool = game != null and is_instance_valid(game)
	var chase = game.camera.cam if alive and game.camera != null and is_instance_valid(game.camera) else null
	var playing: bool = alive and game.flow != null and game.flow.in_play()
	if playing and chase != null:
		chase.current = true
	elif is_instance_valid(_held):
		_held.current = true
	elif chase != null and is_instance_valid(chase):
		chase.current = true
	_held = null
	_apply_attributes()


func _apply_attributes() -> void:
	var on := tilt_shift > 0.0
	_attributes.dof_blur_far_enabled = on
	_attributes.dof_blur_near_enabled = on
	_attributes.dof_blur_amount = 0.04 + 0.16 * tilt_shift
	_attributes.dof_blur_far_transition = 6.0
	_attributes.dof_blur_near_transition = 2.0
	_cam.attributes = _attributes if on else null
