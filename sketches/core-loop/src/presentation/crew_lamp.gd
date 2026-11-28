extends Node3D

const CrewLampField := preload("res://src/presentation/crew_lamp_field.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")


const ROWS := {
	"mag_trapper": {"part": "MagTrapperBody/Cart", "at": Vector3(0.0, 1.41, 0.15)},
	"hooker": {"part": "HookerBody/Body", "at": Vector3(0.0, 1.41, 0.2)},
	"jolt_layer": {"part": "JoltBody", "at": Vector3(0.0, 1.11, 0.32)},
	"catch_trap": {"part": "CatchBody", "at": Vector3(0.0, 0.83, 0.45)},
	"plated_brute": {"part": "BruteBody", "at": Vector3(0.0, 1.23, 0.23)},
	"ramp_flipper": {"part": "RampBody", "at": Vector3(0.0, 1.25, 0.17)},
	"bola_thrower": {"part": "BolaThrowerBody", "at": Vector3(0.0, 1.13, 0.29)},
	"netcaster": {"part": "NetcasterBody/Body", "at": Vector3(0.0, 1.1, 0.38)},
	"deflector": {"part": "DeflectorBody/Body", "at": Vector3(0.0, 1.22, 0.33)},
	"gyro_jammer": {"part": "GyroBody", "at": Vector3(0.0, 1.02, 0.26)},
	"swatter": {"part": "SwatterBody", "at": Vector3(0.0, 1.2, 0.18)},
	"winch_drone": {"part": "WinchBody/Body", "at": Vector3(0.0, 0.95, 0.39)},
}

const SWELL := 2.6
const REST := 0.25
const REST_TINT := 0.45
const FADE := 0.3
const FIELD := "CrewLamps"

var warmth := 0.0
var _out := false
var _field: Node3D


static func fit(pivot: Node3D, kind: String, world: Node) -> Node3D:
	var row: Dictionary = ROWS.get(kind, {})
	if row.is_empty() or pivot == null or world == null:
		return null
	var part := pivot.get_node_or_null(NodePath(String(row.part))) as Node3D
	if part == null:
		return null
	var lamp: Node3D = (load("res://src/presentation/crew_lamp.gd") as GDScript).new()
	lamp.name = "CrewLamp"
	part.add_child(lamp)
	lamp.transform = Transform3D(Basis.IDENTITY, _in_part(part, pivot) * (row.at as Vector3))
	lamp._field = _field_in(world)
	lamp._field.join(lamp)
	return lamp


static func _in_part(part: Node3D, pivot: Node3D) -> Transform3D:
	var to_part := Transform3D.IDENTITY
	var node: Node = part
	while node != null and node != pivot:
		to_part = (node as Node3D).transform * to_part
		node = node.get_parent()
	return to_part.affine_inverse()


static func _field_in(world: Node) -> Node3D:
	var found := world.get_node_or_null(FIELD) as Node3D
	if found == null:
		found = CrewLampField.new()
		found.name = FIELD
		world.add_child(found)
	return found


func watch(delta: float, goal: float) -> void:
	if _out:
		return
	goal = clampf(goal, 0.0, 1.0)
	warmth = goal if goal >= warmth else maxf(goal, warmth - delta / FADE)


func go_out() -> void:
	_out = true
	warmth = 0.0


func energy() -> float:
	return 0.0 if _out else lerpf(REST, FlashGuard.spike(REST, CrewLampField.PEAK), warmth * warmth)


func swell() -> float:
	return 1.0 if _out else lerpf(1.0, SWELL, warmth)


func tint() -> float:
	return 0.0 if _out else lerpf(REST_TINT, 1.0, warmth * warmth)


func _enter_tree() -> void:
	if is_instance_valid(_field):
		_field.join(self)


func danger() -> float:
	return 0.0 if _out else warmth


func _exit_tree() -> void:
	if is_instance_valid(_field):
		_field.leave(self)
