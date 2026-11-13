extends Node3D

const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# A crew's eye (W1-83): one work lamp on its job head, facing the way the head faces. The gait
# turns the model to watch where the crew means to strike, so the lamp shows where it looks; it
# glows dull at rest, brightens through the wind-up in the danger colour and goes out when the
# crew dies. A player reads attention and intent on the body before the telegraph finishes, and
# the read adds nothing to the ground the "clear" telegraph keeps open.
#
# This node is the lamp's place: a child of the head's own part, so a baked clip that moves the
# part moves the eye, and a death clip carries it dark. It draws nothing itself. Every lamp in a
# world is one instance of the world's lamp field (one MultiMesh, one draw for all of them), so
# the eyes add no draw to any crew's budget. Presentation only: nothing reads it back, and it
# holds no game clock. The owner fits it once the model is built and calls watch(delta, goal) a
# tick: goal is the open attack's warn progress (0 to 1), 1 while it is live, 0 between attacks.
#
# ROWS: per kind, the part the head is cast in (a path under the reaction pivot) and the lamp's
# point in the pivot's frame, which is the model's: on the front face of the head (the crew faces
# +Z), measured by ray on each GLB (stage/alpha-w40, 13 Nov 2026). Head centres and sizes are the
# crew.*_head calls in tools/blender/world_one/enemy_<kind>.py.

const ROWS := {
	"mag_trapper": {"part": "MagTrapperBody/Cart", "at": Vector3(0.0, 1.41, 0.15)},
	"hooker": {"part": "HookerBody/Body", "at": Vector3(0.0, 1.41, 0.2)},
	"jolt_layer": {"part": "JoltBody", "at": Vector3(0.0, 1.11, 0.32)},
	"catch_trap": {"part": "CatchBody", "at": Vector3(0.0, 0.83, 0.45)},
	"plated_brute": {"part": "BruteBody", "at": Vector3(0.0, 1.23, 0.23)},
	"ramp_flipper": {"part": "RampBody", "at": Vector3(0.0, 1.25, 0.17)},
	# The signal lantern's own lens, behind its guard bars.
	"bola_thrower": {"part": "BolaThrowerBody", "at": Vector3(0.0, 1.13, 0.29)},
	"netcaster": {"part": "NetcasterBody/Body", "at": Vector3(0.0, 1.1, 0.38)},
	# Behind the dish from straight ahead (the dish is the deflector's read from the front).
	"deflector": {"part": "DeflectorBody/Body", "at": Vector3(0.0, 1.22, 0.33)},
	"gyro_jammer": {"part": "GyroBody", "at": Vector3(0.0, 1.02, 0.26)},
	"swatter": {"part": "SwatterBody", "at": Vector3(0.0, 1.2, 0.18)},
	"winch_drone": {"part": "WinchBody/Body", "at": Vector3(0.0, 0.95, 0.39)},
}

# The lens: a dome this wide, standing this far out of the head.
const LENS := 0.085
const LENS_DEPTH := 0.06
# Glow: dull at rest, full at the strike (emission energy), and the share of the lens colour
# lit at rest.
const REST := 0.35
const PEAK := 4.0
const REST_TINT := 0.45
# Seconds the glow takes to fall back after an attack (the rise follows the warning exactly).
const FADE := 0.3
const FIELD := "CrewLamps"
const FIELD_ROOM := 48

var warmth := 0.0
var _out := false
var _field: Node3D


# The kind's lamp seated on its head part, or null for a kind with no row or no such part.
# `world` holds the lamp field (the crews' common parent).
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


# The pivot-frame point in the part's frame (parts are nested under bodies the kind builds).
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
		found = (load("res://src/presentation/crew_lamp_field.gd") as GDScript).new()
		found.name = FIELD
		world.add_child(found)
	return found


# goal 0 to 1: the open attack's warn progress, 1 while it is live, 0 between attacks.
func watch(delta: float, goal: float) -> void:
	if _out:
		return
	goal = clampf(goal, 0.0, 1.0)
	warmth = goal if goal >= warmth else maxf(goal, warmth - delta / FADE)


# The crew is dead: the lamp goes dark and stays dark.
func go_out() -> void:
	_out = true
	warmth = 0.0


# Emission energy now: 0 once out.
func energy() -> float:
	return 0.0 if _out else lerpf(REST, FlashGuard.spike(REST, PEAK), warmth * warmth)


# The lens colour's lit share now: 0 (charcoal) once out.
func tint() -> float:
	return 0.0 if _out else lerpf(REST_TINT, 1.0, warmth * warmth)


# A death clip lifts the pivot out and back into the tree; the dark lens goes with it.
func _enter_tree() -> void:
	if is_instance_valid(_field):
		_field.join(self)


func _exit_tree() -> void:
	if is_instance_valid(_field):
		_field.leave(self)
