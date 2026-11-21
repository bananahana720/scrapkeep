extends Node3D

const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")

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
# The device ledger (devices.gd) combat hands in: every charge holds a slot of its kind
# (thrown "sticky" or dropped "mini") while it stands. Null outside combat.
var ledger = null
# Charges a deploy at the cap pushed out; they go off on the next step, never vanish.
var _evicted: Array = []

# A thrown charge bit into the world here; presentation pops on it. Read-only.
signal stuck(at: Vector3)


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


# reach is how close (hull to charge) an enemy must come to set it off; born is the
# caller's clock, for charges that grow while they wait; a riding charge (Hitchhiker)
# sticks to the first enemy it touches and goes off on its fuse.
func throw(origin: Vector3, landing: Vector3, damage: float, radius: float, fuse: float, crit: bool,
		reach := CONTACT_REACH, born := 0.0, ride := false) -> Dictionary:
	var flight := flight_time(origin, landing)
	return _add({"origin": origin, "velocity": launch_velocity(origin, landing, flight), "t": 0.0,
		"flight": flight, "pos": origin, "landing": landing, "stuck": false, "fuse": fuse, "arm": 0.0,
		"damage": damage, "radius": radius, "crit": crit, "mini": false, "reach": reach, "born": born,
		"ride": ride, "rider": null})


func drop(at: Vector3, damage: float, radius: float, fuse: float, arm: float, reach := CONTACT_REACH, born := 0.0) -> Dictionary:
	return _add({"origin": at, "velocity": Vector3.ZERO, "t": 0.0, "flight": 0.0, "pos": at, "landing": at,
		"stuck": true, "fuse": fuse, "arm": arm, "damage": damage, "radius": radius, "crit": false, "mini": true,
		"reach": reach, "born": born, "ride": false, "rider": null})


func live(mini := false) -> Array:
	return charges.filter(func(c): return c["mini"] == mini)


func is_idle() -> bool:
	return charges.is_empty() and _evicted.is_empty()


# Steps every charge; returns the ones that go off this tick, already removed.
func step(delta: float, space: PhysicsDirectSpaceState3D, enemies: Array) -> Array:
	var gone := []
	for charge in charges:
		charge["fuse"] -= delta
		charge["arm"] -= delta
		var rider = charge.get("rider")
		if rider != null and is_instance_valid(rider) and not rider.is_dead():
			charge["pos"] = rider.global_position + Vector3.UP * 0.6
		elif not charge["stuck"]:
			_fly(charge, delta, space)
		(charge["node"] as Node3D).global_position = charge["pos"]
		if ledger != null:
			ledger.move(int(charge.get("device_id", 0)), charge["pos"])
		if charge["fuse"] <= 0.0:
			gone.append(charge)
		elif charge["arm"] <= 0.0 and rider == null:
			var touched = _touching(charge, enemies)
			if touched != null and charge.get("ride", false):
				charge["rider"] = touched
				charge["stuck"] = true
			elif touched != null:
				gone.append(charge)
	for charge in gone:
		take(charge)
	gone.append_array(_evicted)
	_evicted = []
	return gone


# A charge leaves the world (it went off, was caught or cleared): it leaves the count.
func take(charge: Dictionary) -> Dictionary:
	_forget(charge)
	_free(charge)
	return charge


# The ledger recalled this charge past the leash: it leaves without going off.
func recall(device_id: int) -> bool:
	for charge in charges:
		if int(charge.get("device_id", 0)) == device_id:
			_forget(charge)
			_free(charge)
			return true
	return false


func clear() -> void:
	for charge in charges.duplicate():
		take(charge)
	_evicted = []


# take() and tree exit can both run for the same charge. Forget its id before release.
func _forget(charge: Dictionary) -> void:
	charges.erase(charge)
	if ledger != null:
		var id := int(charge.get("device_id", 0))
		charge.erase("device_id")
		if id > 0:
			ledger.remove(id, "destroyed")


func _free(charge: Dictionary) -> void:
	var node = charge.get("node")
	if is_instance_valid(node):
		node.queue_free()


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
		stuck.emit(charge["pos"])
	elif charge["t"] >= charge["flight"]:
		charge["pos"] = charge["landing"]
		charge["stuck"] = true
		stuck.emit(charge["pos"])
	else:
		charge["pos"] = after


# The first live enemy within the charge's reach, or null.
func _touching(charge: Dictionary, enemies: Array):
	var reach: float = charge.get("reach", CONTACT_REACH)
	for enemy in enemies:
		if DamageDoor.dead(enemy):
			continue
		var hull: float = float(enemy.get("radius")) if enemy.get("radius") != null else 1.0
		if (enemy.global_position - charge["pos"]).length() - hull <= reach:
			return enemy
	return null


func _add(charge: Dictionary) -> Dictionary:
	if ledger != null:
		var placed: Dictionary = ledger.deploy("mini" if charge["mini"] else "sticky", charge["pos"])
		for id in placed["evicted"]:
			for old in charges.duplicate():
				if int(old.get("device_id", 0)) == id:
					charges.erase(old)
					_free(old)
					_evicted.append(old)
		if int(placed["id"]) <= 0:
			return charge
		charge["device_id"] = int(placed["id"])
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
	if ledger != null:
		node.tree_exiting.connect(func(): _forget(charge))
	return charge
