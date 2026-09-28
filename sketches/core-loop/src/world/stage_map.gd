extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const Shapes := preload("res://src/world/features.gd")

# One stage's shape as data plus a height function. The terrain builds the ground
# from sample(), and every other question (where you spawn, where the beacon stands,
# where an event's ring is, where the flood can rise) is answered from these fields,
# so the geometry and the events that use it cannot disagree.

var title := ""
var spawn := Vector2.ZERO
var heading := Vector3(0.0, 0.0, 1.0)
var beacon := Vector2.ZERO
var scrap_lines: Array = []
# The flood's bowl: centre (Vector2), radius, depth (m of water at full), plane_size
# (Vector2) and plane_centre (Vector2). Empty for a map with no basin.
var basin := {}
# Participatory event sites keyed by event id. Each holds what that event needs:
# "ring" (Vector2, the start ring), plus "route" (PackedVector2Array) for a surge run
# or a stampede, or "relay" (Vector2) for a hold.
var sites := {}
# Events this map carries whatever stage_defs' event_mix says: an event unique to a map.
var unique_events: Array[String] = []
# Where spawns and rescues stay: the playable floor inside the rim walls.
var play_rect := Rect2(-150.0, -150.0, 300.0, 300.0)
# The plated vault's spot: off the fall line, on a plinth, with a downhill way back.
var vault := Vector2.ZERO
# The beacon bowl's floor height; the Warden stands on it.
var beacon_floor := 0.0
# Spots where the ball leaving the ground counts as a kicker launch (codex): each is
# {"at": Vector2 lip, "dir": Vector2, "width": float}.
var kickers: Array = []

# The v3 loop (design-v3/LOOP-REDESIGN.md sections 1 and 3), empty on a map without
# one. loop is the lap as a route.gd-style polyline: shelf, a drop line, the bowl, the
# return. Each drop line runs from the shelf to an amber kicker lip aimed at the
# Warden's mast: {"id", "kind" ("fast" or "long"), "start" (Vector2, where it leaves
# the shelf), "via" (Array of Vector2 on the way down), "at" (Vector2, the lip),
# "dir" (Vector2 unit, the way you ride it), "width", "length", "lip" (m of rise),
# "target" (Vector2, the mast)}. return_at is the return contraption's mouth in the
# bowl and return_to where it sets the ball down on the shelf.
var loop := PackedVector2Array()
var drop_lines: Array = []
var return_at := Vector2.INF
var return_to := Vector2.INF
# True while a loop mode has the lips and the return live on this map (world sets it at
# stage entry), so the codex reads a drop lip as a kicker only when one stands there.
var loop_live := false
# The loop's swap id: its lips are pre-built colliders parked until a loop mode is on.
const LOOP_SWAP := "drop_loop"
const LOOP_PARK := 400.0


# How far p is from the fall line, the straight run from the spawn to the beacon. The
# v2 route contract (world_route_test) reads this; the loop reads off_loop().
func off_line(p: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, spawn, beacon))


# How far p is from the loop, INF on a map without one.
func off_loop(p: Vector2) -> float:
	var best := INF
	for i in range(1, loop.size()):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, loop[i - 1], loop[i])))
	return best


# The drop lines' lips as height over the ground, 0 away from them.
func drop_lip_height(x: float, z: float) -> float:
	var h := 0.0
	for line in drop_lines:
		h = maxf(h, Shapes.kicker(x, z, line["at"], line["dir"], line["length"], line["width"], line["lip"]))
	return h


# The drop line whose lip p is at or just past, else {}. whole_ramp widens the reach
# back over the lip's whole run-up, where a hopping ball crosses it in the air.
func drop_line_at(p: Vector2, whole_ramp := false) -> Dictionary:
	for line in drop_lines:
		var rel: Vector2 = p - (line["at"] as Vector2)
		var dir: Vector2 = line["dir"]
		var u := rel.dot(dir)
		var back: float = float(line["length"]) if whole_ramp else 3.0
		if u > -back and u < 6.0 and absf(rel.dot(Vector2(-dir.y, dir.x))) < float(line["width"]) * 0.5 + 1.5:
			return line
	return {}


# The flatter arc at this speed that covers distance d and rises by dy: (planar, up), or
# null when no arc at this speed reaches.
static func aim_arc(speed: float, d: float, dy: float, g: float):
	var s2 := speed * speed
	var disc := s2 * s2 - g * (g * d * d + 2.0 * dy * s2)
	if disc < 0.0:
		return null
	var angle := atan((s2 - sqrt(disc)) / (g * d))
	return Vector2(cos(angle), sin(angle)) * speed


# Puts a pre-built terrain change in or out by moving its finished bodies (the gorge's
# swap, map_gorge.gd apply_swap): swaps is id -> {"before": [Node3D], "after": [Node3D]},
# each node carrying its "home" meta.
static func move_swap(swaps: Dictionary, id: String, changed: bool) -> void:
	if not swaps.has(id):
		return
	for node in swaps[id]["after"]:
		var home: Vector3 = node.get_meta("home")
		node.position = home if changed else home + Vector3.DOWN * LOOP_PARK
		node.visible = changed
	for node in swaps[id]["before"]:
		var home: Vector3 = node.get_meta("home")
		node.position = home + Vector3.DOWN * LOOP_PARK if changed else home
		node.visible = not changed


func near_kicker_lip(p: Vector2) -> bool:
	if loop_live and not drop_line_at(p).is_empty():
		return true
	for k in kickers:
		var rel: Vector2 = p - (k["at"] as Vector2)
		var dir: Vector2 = k["dir"]
		var u := rel.dot(dir)
		var v := absf(rel.dot(Vector2(-dir.y, dir.x)))
		if u > -6.0 and u < 4.0 and v < float(k["width"]) * 0.5 + 1.0:
			return true
	return false


# [height, tint]. The tint is the ground's own reading of the feature it belongs to.
func sample(_x: float, _z: float) -> Array:
	return [0.0, Palette.SAND]


func material_at(_x: float, _z: float) -> String:
	return "sand"


func build_props(_parent: Node3D, _ground: Callable) -> void:
	pass


# A live terrain change's height at (x, z) over the ground, or -INF where it has none.
func overlay_height(_id: String, _x: float, _z: float, _ground: float) -> float:
	return -INF


static func box(parent: Node3D, size: Vector3, origin: Vector3, mat: Material, turn := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = origin
	body.rotation.y = turn
	var mesh := MeshInstance3D.new()
	var shape_mesh := BoxMesh.new()
	shape_mesh.size = size
	mesh.mesh = shape_mesh
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)
	return body


static func cylinder(parent: Node3D, radius: float, height_m: float, origin: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = origin
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height_m
	mesh.mesh = cyl
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = radius
	cyl_shape.height = height_m
	shape.shape = cyl_shape
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)
	return body


# A grapple post: a tall copper mast with an amber cap, the movement colour, so a hook
# point reads as one from across the stage.
static func grapple_post(parent: Node3D, foot: Vector3, height_m: float) -> void:
	cylinder(parent, 0.9, height_m, foot + Vector3.UP * height_m * 0.5, Palette.solid(Palette.COPPER))
	var cap := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 1.4
	ball.height = 2.8
	cap.mesh = ball
	cap.material_override = Palette.solid(Palette.AMBER, 1.2)
	cap.position = foot + Vector3.UP * (height_m + 0.6)
	parent.add_child(cap)


# A pylon wall: a sheer concrete slab in the verdigris the ground uses for any face a
# pylon can bite, so the engineer can read a turret spot at a glance.
static func pylon_wall(parent: Node3D, foot: Vector3, length: float, height_m: float, turn: float) -> void:
	box(parent, Vector3(length, height_m, 1.6), foot + Vector3.UP * (height_m * 0.5 - 0.5),
		Palette.striped(Palette.VERDIGRIS, Palette.CHARCOAL), turn)
