extends Node3D

const Palette := preload("res://src/core/palette.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const CONTACT_REACH := preload("res://src/core/devices.gd").STICKY_CONTACT_REACH
const ARC_POINTS := 16
const FLIGHT_SPEED := 22.0
const FLIGHT_MIN := 0.35
const FLIGHT_MAX := 1.1
const RING_SEGMENTS := 32
const RING_MIN_RADIUS := 0.45

var charges: Array = []
var ledger = null
var _evicted: Array = []
var _ring_mesh: ImmediateMesh
var _ring_view: MeshInstance3D

signal stuck(at: Vector3)


static func flight_time(origin: Vector3, landing: Vector3) -> float:
	var flat := Vector2(landing.x - origin.x, landing.z - origin.z).length()
	return clampf(flat / FLIGHT_SPEED, FLIGHT_MIN, FLIGHT_MAX)


static func launch_velocity(origin: Vector3, landing: Vector3, flight: float) -> Vector3:
	return (landing - origin) / flight + Vector3.UP * 0.5 * Tuning.GRAVITY * flight


static func arc_point(origin: Vector3, velocity: Vector3, t: float) -> Vector3:
	return origin + velocity * t + Vector3.DOWN * 0.5 * Tuning.GRAVITY * t * t


static func arc_points(origin: Vector3, landing: Vector3) -> PackedVector3Array:
	var flight := flight_time(origin, landing)
	var velocity := launch_velocity(origin, landing, flight)
	var points := PackedVector3Array()
	for i in ARC_POINTS + 1:
		points.append(arc_point(origin, velocity, flight * float(i) / float(ARC_POINTS)))
	return points


func throw(origin: Vector3, landing: Vector3, damage: float, radius: float, fuse: float, crit: bool,
		reach := CONTACT_REACH, born := 0.0, ride := false, tail_drop := false) -> Dictionary:
	var flight := 0.0 if tail_drop else flight_time(origin, landing)
	var vel := Vector3.ZERO if tail_drop else launch_velocity(origin, landing, flight)
	var start := landing if tail_drop else origin
	var charge := _add({"origin": start, "velocity": vel, "t": 0.0,
		"flight": flight, "pos": start, "landing": landing, "stuck": tail_drop, "fuse": fuse, "fuse_max": fuse,
		"age": 0.0, "arm": 0.0, "damage": damage, "radius": radius, "crit": crit, "mini": false,
		"reach": reach, "born": born, "ride": ride, "rider": null,
		"snap_token": 0, "snap_window": Vector2.ZERO, "snap_state": ""})
	if tail_drop:
		stuck.emit(landing)
	return charge


func drop(at: Vector3, damage: float, radius: float, fuse: float, arm: float, reach := CONTACT_REACH, born := 0.0) -> Dictionary:
	return _add({"origin": at, "velocity": Vector3.ZERO, "t": 0.0, "flight": 0.0, "pos": at, "landing": at,
		"stuck": true, "fuse": fuse, "fuse_max": fuse, "age": 0.0, "arm": arm, "damage": damage, "radius": radius,
		"crit": false, "mini": true, "reach": reach, "born": born, "ride": false, "rider": null,
		"snap_token": 0, "snap_window": Vector2.ZERO, "snap_state": ""})


func set_snap_cue(charge: Dictionary, window_s: Vector2, token: int) -> void:
	charge["snap_token"] = token
	charge["snap_window"] = window_s
	charge["snap_state"] = "waiting" if window_s.y > window_s.x else ""
	_draw_fuse_rings()


func sync_snap_state(token: int, state: String) -> void:
	if token <= 0:
		return
	var changed := false
	for charge in charges:
		if int(charge.get("snap_token", 0)) == token:
			if String(charge.get("snap_state", "")) != state:
				charge["snap_state"] = state
				changed = true
	if changed:
		_draw_fuse_rings()


static func fuse_ring_color(charge: Dictionary) -> Color:
	var state := String(charge.get("snap_state", ""))
	if state == "open":
		return Palette.live()
	var win: Vector2 = charge.get("snap_window", Vector2.ZERO)
	if state == "spent" or (win.y > win.x and float(charge.get("age", 0.0)) > win.y):
		return Palette.SLATE
	return ClassDef.KEST_COLOR


static func fuse_ring_radius(charge: Dictionary) -> float:
	var max_r := maxf(float(charge.get("radius", 3.0)), RING_MIN_RADIUS)
	var fuse_max := float(charge.get("fuse_max", 1.2))
	if not is_finite(fuse_max) or fuse_max <= 0.001:
		return max_r
	var age := clampf(float(charge.get("age", 0.0)), 0.0, fuse_max)
	var frac := clampf(1.0 - age / fuse_max, 0.0, 1.0)
	return lerpf(RING_MIN_RADIUS, max_r, frac)


func live(mini := false) -> Array:
	return charges.filter(func(c): return c["mini"] == mini)


func is_idle() -> bool:
	return charges.is_empty() and _evicted.is_empty()


func step(delta: float, space: PhysicsDirectSpaceState3D, enemies: Array) -> Array:
	var gone := []
	for charge in charges:
		charge["fuse"] -= delta
		charge["age"] = float(charge.get("age", 0.0)) + delta
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
	_draw_fuse_rings()
	return gone


func take(charge: Dictionary) -> Dictionary:
	_forget(charge)
	_free(charge)
	_draw_fuse_rings()
	return charge


func recall(device_id: int) -> bool:
	for charge in charges:
		if int(charge.get("device_id", 0)) == device_id:
			_forget(charge)
			_free(charge)
			_draw_fuse_rings()
			return true
	return false


func clear() -> void:
	for charge in charges.duplicate():
		take(charge)
	_evicted = []
	if _ring_mesh != null:
		_ring_mesh.clear_surfaces()


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
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(before, after, PhysicsLayers.WORLD_MASK))
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


func _ensure_ring_view() -> void:
	if _ring_mesh != null and is_instance_valid(_ring_view):
		return
	_ring_mesh = ImmediateMesh.new()
	_ring_view = MeshInstance3D.new()
	_ring_view.name = "FuseRings"
	_ring_view.mesh = _ring_mesh
	_ring_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = 1
	_ring_view.material_override = mat
	_ring_view.top_level = true
	add_child(_ring_view)


func _draw_fuse_rings() -> void:
	var cued := false
	for charge in charges:
		var win: Vector2 = charge.get("snap_window", Vector2.ZERO)
		if not charge.get("mini", false) and win.y > win.x and is_finite(float(charge.get("fuse", INF))):
			cued = true
			break
	if not cued:
		if _ring_mesh != null:
			_ring_mesh.clear_surfaces()
		return
	_ensure_ring_view()
	_ring_mesh.clear_surfaces()
	_ring_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for charge in charges:
		var win: Vector2 = charge.get("snap_window", Vector2.ZERO)
		if charge.get("mini", false) or win.y <= win.x or not is_finite(float(charge.get("fuse", INF))):
			continue
		var r := fuse_ring_radius(charge)
		var col := Color(fuse_ring_color(charge), 0.9)
		var at: Vector3 = charge["pos"] + Vector3.UP * 0.18
		var prev := at + Vector3(r, 0.0, 0.0)
		for i in range(1, RING_SEGMENTS + 1):
			var ang := TAU * float(i) / float(RING_SEGMENTS)
			var pt := at + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			_ring_mesh.surface_set_color(col)
			_ring_mesh.surface_add_vertex(prev)
			_ring_mesh.surface_set_color(col)
			_ring_mesh.surface_add_vertex(pt)
			prev = pt
	_ring_mesh.surface_end()
