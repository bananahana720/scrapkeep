extends Node3D

const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# Kest's sticky charges. A thrown charge flies the lobbed arc its throw committed and
# sticks where that arc lands (or where the world cuts it short); a dropped one (the
# demo slam's) sits where it fell. A charge goes off when its fuse runs out, or when an
# enemy's hull comes within CONTACT_REACH once it is armed. The manager only moves and
# times charges; combat resolves each detonation it hands back.

const GRAVITY := 26.0
const CONTACT_REACH := 0.6
const WORLD_MASK := 1
const ARC_POINTS := 16
const FLIGHT_SPEED := 22.0
const FLIGHT_MIN := 0.35
const FLIGHT_MAX := 1.1

var charges: Array = []


# The flight time a throw of this length takes, shared by the arc drawn and the throw.
static func flight_time(origin: Vector3, landing: Vector3) -> float:
	var flat := Vector2(landing.x - origin.x, landing.z - origin.z).length()
	return clampf(flat / FLIGHT_SPEED, FLIGHT_MIN, FLIGHT_MAX)


static func launch_velocity(origin: Vector3, landing: Vector3, flight: float) -> Vector3:
	return (landing - origin) / flight + Vector3.UP * 0.5 * GRAVITY * flight


static func arc_point(origin: Vector3, velocity: Vector3, t: float) -> Vector3:
	return origin + velocity * t + Vector3.DOWN * 0.5 * GRAVITY * t * t


# The committed arc, sampled; the indicator draws exactly these points.
static func arc_points(origin: Vector3, landing: Vector3) -> PackedVector3Array:
	var flight := flight_time(origin, landing)
	var velocity := launch_velocity(origin, landing, flight)
	var points := PackedVector3Array()
	for i in ARC_POINTS + 1:
		points.append(arc_point(origin, velocity, flight * float(i) / float(ARC_POINTS)))
	return points


func throw(origin: Vector3, landing: Vector3, damage: float, radius: float, fuse: float, crit: bool) -> Dictionary:
	var flight := flight_time(origin, landing)
	return _add({"origin": origin, "velocity": launch_velocity(origin, landing, flight), "t": 0.0,
		"flight": flight, "pos": origin, "landing": landing, "stuck": false, "fuse": fuse, "arm": 0.0,
		"damage": damage, "radius": radius, "crit": crit, "mini": false})


func drop(at: Vector3, damage: float, radius: float, fuse: float, arm: float) -> Dictionary:
	return _add({"origin": at, "velocity": Vector3.ZERO, "t": 0.0, "flight": 0.0, "pos": at, "landing": at,
		"stuck": true, "fuse": fuse, "arm": arm, "damage": damage, "radius": radius, "crit": false, "mini": true})


func live(mini := false) -> Array:
	return charges.filter(func(c): return c["mini"] == mini)


# Steps every charge; returns the ones that go off this tick, already removed.
func step(delta: float, space: PhysicsDirectSpaceState3D, enemies: Array) -> Array:
	var gone := []
	for charge in charges:
		charge["fuse"] -= delta
		charge["arm"] -= delta
		if not charge["stuck"]:
			_fly(charge, delta, space)
		(charge["node"] as Node3D).global_position = charge["pos"]
		if charge["fuse"] <= 0.0 or (charge["arm"] <= 0.0 and _touching(charge, enemies)):
			gone.append(charge)
	for charge in gone:
		take(charge)
	return gone


func take(charge: Dictionary) -> Dictionary:
	charges.erase(charge)
	var node: Node3D = charge.get("node")
	if is_instance_valid(node):
		node.queue_free()
	return charge


func clear() -> void:
	for charge in charges.duplicate():
		take(charge)


func _fly(charge: Dictionary, delta: float, space: PhysicsDirectSpaceState3D) -> void:
	var before: Vector3 = charge["pos"]
	charge["t"] = minf(float(charge["t"]) + delta, charge["flight"])
	var after := arc_point(charge["origin"], charge["velocity"], charge["t"])
	var hit := {}
	if space != null:
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(before, after, WORLD_MASK))
	if not hit.is_empty():
		charge["pos"] = hit["position"]
		charge["stuck"] = true
	elif charge["t"] >= charge["flight"]:
		charge["pos"] = charge["landing"]
		charge["stuck"] = true
	else:
		charge["pos"] = after


func _touching(charge: Dictionary, enemies: Array) -> bool:
	for enemy in enemies:
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var hull: float = float(enemy.get("radius")) if enemy.get("radius") != null else 1.0
		if (enemy.global_position - charge["pos"]).length() - hull <= CONTACT_REACH:
			return true
	return false


func _add(charge: Dictionary) -> Dictionary:
	var node := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.28 if charge["mini"] else 0.4
	ball.height = ball.radius * 2.0
	node.mesh = ball
	node.material_override = Palette.solid(ClassDef.KEST_COLOR, 2.2)
	add_child(node)
	node.global_position = charge["pos"]
	charge["node"] = node
	charges.append(charge)
	return charge
