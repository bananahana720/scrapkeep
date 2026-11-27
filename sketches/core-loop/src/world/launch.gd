extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const PropMeshes := preload("res://src/presentation/craft_prop_meshes.gd")


const LIFT := 24.0
const FLOOR_RAMP := 0.5
const RINGS := 7
const RING_RADIUS := 3.2
const RING_FIRST := 0.08
const RING_STEP := 0.075
const LANDING_RINGS := 6
const LANDING_STEP := 0.02
const LANDING_LIMIT := 4.0
const THREADED := 0.05
const TURN_TIME := 0.45

var gravity := 26.0
var landing_point := Vector3.INF

var _origin := Vector3.ZERO
var _velocity := Vector3.ZERO
var _from := Vector3.ZERO
var _flying := false
var _time := 0.0
var _rings: Array[MeshInstance3D] = []
var _landing: Array[MeshInstance3D] = []
var _landing_due: Array[float] = []
var _fall := 0.0
var _pad: MeshInstance3D
var _pad_time := 0.0
var _turn_to := Vector3.ZERO
var _camera = null
var _turn := 0.0
var _view_turn := 0.0
var _view_given := 0.0


static func launch_velocity(current: Vector3, floor_speed: float, fallback_heading: Vector3) -> Vector3:
	var flat := Vector3(current.x, 0.0, current.z)
	if flat.length() < floor_speed:
		var heading := flat.normalized() if flat.length() > 0.5 else Vector3(fallback_heading.x, 0.0, fallback_heading.z).normalized()
		flat = heading * floor_speed
	return flat + Vector3.UP * LIFT


static func arc_point(origin: Vector3, velocity: Vector3, g: float, t: float) -> Vector3:
	return origin + velocity * t + Vector3.DOWN * 0.5 * g * t * t


func setup() -> void:
	var mat := Palette.solid(EventKinds.color("launched"), 2.4)
	for i in RINGS:
		_rings.append(_ring(mat, RING_RADIUS))
	var land_mat := Palette.solid(Palette.AMBER, 1.8)
	for i in LANDING_RINGS:
		_landing.append(_ring(land_mat, RING_RADIUS + 0.6))
	_pad = MeshInstance3D.new()
	_pad.mesh = PropMeshes.launch_landing_pad(7.0)
	_pad.material_override = Palette.unshaded(Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.5))
	_pad.visible = false
	add_child(_pad)


func _ring(mat: Material, radius: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.mesh = PropMeshes.launch_flight_ring(radius)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	add_child(ring)
	return ring


static func rail_start(current: Vector3) -> Vector3:
	return Vector3(current.x, 0.0, current.z) + Vector3.UP * LIFT


func aim(heading: Vector3, camera = null) -> void:
	var flat := Vector3(heading.x, 0.0, heading.z)
	_turn_to = flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
	_camera = camera


func fire(origin: Vector3, velocity: Vector3, from := Vector3.INF) -> void:
	_origin = origin
	_velocity = velocity
	_from = velocity if from == Vector3.INF else from
	_flying = true
	_time = 0.0
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	_turn = flat.signed_angle_to(_turn_to, Vector3.UP) if _turn_to != Vector3.ZERO and flat.length() > 0.5 else 0.0
	_view_turn = 0.0
	_view_given = 0.0
	if _turn_to != Vector3.ZERO and is_instance_valid(_camera):
		_view_turn = angle_difference(float(_camera.yaw), atan2(-_turn_to.x, -_turn_to.z))
	for i in RINGS:
		var t := RING_FIRST + i * RING_STEP
		_place_ring(_rings[i], path_point(origin, _from, velocity, gravity, _turn, t), rail_velocity(_from, velocity, gravity, _turn, t))


static func turned_share(t: float) -> float:
	return smoothstep(0.0, TURN_TIME, t)


static func turned_flat(flat: Vector3, turn: float, t: float) -> Vector3:
	return flat.rotated(Vector3.UP, turn * turned_share(t)) if turn != 0.0 else flat


static func rail_velocity(from: Vector3, velocity: Vector3, g: float, turn: float, t: float) -> Vector3:
	var flat := Vector3(from.x, 0.0, from.z).lerp(Vector3(velocity.x, 0.0, velocity.z), smoothstep(0.0, FLOOR_RAMP, t))
	return turned_flat(flat, turn, t) + Vector3.UP * (velocity.y - g * t)


static func path_point(origin: Vector3, from: Vector3, velocity: Vector3, g: float, turn: float, t: float) -> Vector3:
	var tick := 1.0 / Engine.physics_ticks_per_second
	var at := origin
	var done := 0.0
	while done < t - 0.000001:
		var slice := minf(tick, t - done)
		var v := rail_velocity(from, velocity, g, turn, done)
		if done == 0.0:
			v.y = 0.0
		v.y -= g * tick
		at += v * slice
		done += slice
	return at


func rail(delta: float):
	if not _flying:
		return null
	_time += delta
	for i in RINGS:
		if _rings[i].visible and RING_FIRST + i * RING_STEP < _time - THREADED:
			_rings[i].visible = false
	var share := turned_share(_time)
	if _view_turn != 0.0 and is_instance_valid(_camera):
		_camera.yaw += _view_turn * (share - _view_given)
	_view_given = share
	return rail_velocity(_from, _velocity, gravity, _turn, _time)


func stop() -> void:
	_flying = false
	for ring in _rings:
		ring.visible = false


func flying() -> bool:
	return _flying


func mark_landing(entry: Vector3, velocity: Vector3, height: Callable) -> Vector3:
	var t := 0.0
	var at := entry
	while t < LANDING_LIMIT:
		t += LANDING_STEP
		at = arc_point(entry, velocity, gravity, t)
		if at.y <= float(height.call(at.x, at.z)) + 1.0:
			break
	var flight := t
	_fall = 0.0
	_landing_due.clear()
	for i in LANDING_RINGS:
		var s := flight * float(i + 1) / float(LANDING_RINGS + 1)
		_landing_due.append(s)
		_place_ring(_landing[i], arc_point(entry, velocity, gravity, s), velocity + Vector3.DOWN * gravity * s)
	_pad.position = Vector3(at.x, float(height.call(at.x, at.z)) + 0.15, at.z)
	_pad.visible = true
	_pad_time = flight + 1.5
	landing_point = at
	return at


func clear_landing() -> void:
	_pad.visible = false
	for ring in _landing:
		ring.visible = false


func _process(delta: float) -> void:
	if _pad.visible:
		_fall += delta
		for i in _landing_due.size():
			if _landing[i].visible and _landing_due[i] < _fall - THREADED:
				_landing[i].visible = false
		_pad_time -= delta
		if _pad_time <= 0.0:
			clear_landing()


func landing_rings() -> int:
	return _landing.filter(func(ring: MeshInstance3D): return ring.visible).size()


static func _place_ring(ring: MeshInstance3D, at: Vector3, along: Vector3) -> void:
	ring.visible = true
	ring.position = at
	var dir := along.normalized() if along.length() > 0.1 else Vector3.FORWARD
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	ring.basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI * 0.5)
