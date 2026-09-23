extends Node3D

const Layout := preload("res://src/layout.gd")
const Materials := preload("res://src/materials.gd")
const Palette := preload("res://src/palette.gd")

const CABLE_HEIGHT := 22.0
const LOAD_CLEARANCE := 2.6
const STRIKE_RADIUS := 5.2
const LEAD := 2.0
const KNOCK_SPEED := 22.0
const STRIKE_DAMAGE := 12.0
const HIT_COOLDOWN := 1.2

signal struck(body: Node)

var run
var target
var speed := 28.0

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _length := 1.0
var _travelled := 0.0
var _hit_clock := 0.0
var _load: Node3D
var _shadow: MeshInstance3D
var _lamp: OmniLight3D


func setup(spec: Dictionary, run_ref, target_ref) -> void:
	run = run_ref
	target = target_ref
	speed = float(spec["speed"])
	var a: Vector2 = spec["from"]
	var b: Vector2 = spec["to"]
	_from = Vector3(a.x, Layout.height(a.x, a.y), a.y)
	_to = Vector3(b.x, Layout.height(b.x, b.y), b.y)
	_length = (b - a).length()
	_travelled = fmod(float(spec["phase"]) * speed, _length)

	_build_cable()
	_load = _build_load()
	_shadow = _build_shadow()
	_lamp = OmniLight3D.new()
	_lamp.light_color = Palette.ARC
	_lamp.light_energy = 3.0
	_lamp.omni_range = 16.0
	add_child(_lamp)
	_place()


func progress() -> float:
	return _travelled / _length


func load_position() -> Vector3:
	return _point_at(_travelled)


func path_point(fraction: float) -> Vector3:
	return _point_at(clampf(fraction, 0.0, 1.0) * _length)


# Where the load will be in LEAD seconds: the shadow and the lamp mark this, which
# is the whole warning the player gets.
func warned_position() -> Vector3:
	return _point_at(fmod(_travelled + speed * LEAD, _length))


func tick(delta: float) -> void:
	_travelled = fmod(_travelled + speed * delta, _length)
	_hit_clock = maxf(0.0, _hit_clock - delta)
	_place()
	_strike()


func _physics_process(delta: float) -> void:
	tick(delta)


func _point_at(distance: float) -> Vector3:
	var t := distance / _length
	var flat: Vector3 = _from.lerp(_to, t)
	return Vector3(flat.x, Layout.height(flat.x, flat.z) + LOAD_CLEARANCE, flat.z)


func _place() -> void:
	var at := load_position()
	_load.global_position = at
	var warn := warned_position()
	_shadow.global_position = Vector3(warn.x, Layout.height(warn.x, warn.z) + 0.25, warn.z)
	_lamp.global_position = _shadow.global_position + Vector3.UP * 2.0


func _strike() -> void:
	var at := load_position()
	for foe in get_tree().get_nodes_in_group("foe"):
		if at.distance_to(foe.global_position) < STRIKE_RADIUS + foe.body_radius:
			var away: Vector3 = foe.global_position - at
			away.y = 0.0
			var dir := Vector3.UP
			if away.length() > 0.01:
				dir = away.normalized() + Vector3.UP * 0.4
			foe.knock(dir, KNOCK_SPEED)
			foe.take_damage(18.0)
			struck.emit(foe)
	if target == null or run == null or not run.live() or _hit_clock > 0.0:
		return
	var ball: Vector3 = target.ball_position()
	if at.distance_to(ball) < STRIKE_RADIUS + 1.0:
		_hit_clock = HIT_COOLDOWN
		var push := ball - at
		push.y = 0.0
		push = push.normalized() if push.length() > 0.01 else Vector3.FORWARD
		var carried: Vector3 = target.state.velocity
		target.active_body().set_velocity_now(carried * 0.3 + push * KNOCK_SPEED + Vector3.UP * 7.0)
		run.damage(STRIKE_DAMAGE)
		struck.emit(target)


func _build_cable() -> void:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.22
	cyl.height = _length
	mesh.mesh = cyl
	mesh.material_override = Materials.solid(Palette.CHARCOAL)
	var mid := (_from + _to) * 0.5 + Vector3.UP * CABLE_HEIGHT
	var axis: Vector3 = (_to - _from).normalized()
	add_child(mesh)
	mesh.global_position = mid
	# A cylinder mesh runs along its own +Y, so aim that axis down the cable.
	mesh.global_basis = _basis_along(axis)
	for end in [_from, _to]:
		var pylon := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.0, CABLE_HEIGHT + 4.0, 3.0)
		pylon.mesh = box
		pylon.material_override = Materials.striped(Palette.COPPER, Palette.CHARCOAL)
		add_child(pylon)
		pylon.global_position = end + Vector3.UP * (CABLE_HEIGHT * 0.5)


func _build_load() -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var crate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.4, 4.0, 4.4)
	crate.mesh = box
	crate.material_override = Materials.striped(Palette.RUST, Palette.AMBER)
	holder.add_child(crate)
	var hanger := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.14
	cyl.height = CABLE_HEIGHT - LOAD_CLEARANCE
	hanger.mesh = cyl
	hanger.material_override = Materials.solid(Palette.CHARCOAL)
	hanger.position = Vector3(0.0, (CABLE_HEIGHT - LOAD_CLEARANCE) * 0.5 + 2.0, 0.0)
	holder.add_child(hanger)
	return holder


func _build_shadow() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = STRIKE_RADIUS
	disc.bottom_radius = STRIKE_RADIUS
	disc.height = 0.1
	mesh.mesh = disc
	var mat := Materials.solid(Palette.CHARCOAL)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	add_child(mesh)
	return mesh


static func _basis_along(axis: Vector3) -> Basis:
	var up := axis.normalized()
	var right := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	right = (right - up * right.dot(up)).normalized()
	return Basis(right, up, right.cross(up))
