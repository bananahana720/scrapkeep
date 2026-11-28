extends SceneTree
# 2026-10-10 (w13 KC2): the grind-line family of the park recipes (design-v3/PARK.md section 4): canal_lip, flume_span,
# penstock_run and pipeline_rail, each a GLB under assets/models/park/ built by tools/blender/park/grind.py.
# (a) Files: each recipe has a base GLB with a "<id>-col" mesh and a rail line, and two detail shells; no light node.
# (b) The rail line is data the GLB carries: nodes "<id>-rail_00", "<id>-rail_01", ... (empties) in ride order. They run
# down +Z from the entry (z 0) for at least 90 percent of the recipe length, and each lies on the collider's rideable top.
# (c) Placed through park_recipes.gd, the -col mesh is the one trimesh on the node's body and is never drawn.
# (d) The harpoon bites the piece: a ray from the beam side through Augments.grapple_target (the harpoon's own rule, walkable
# ground refused) takes a steep face of the collider; the same ray aimed straight down at the walkable top is refused.
# (e) The ride: RideRail.line segments chained along the rail line from the bite's nearest rail point to its end carry the ball
# end to end, never under the speed floor, and the ride fact ride_grapple_line is a WORLD_ROWS row.
# (f) A headless roll: a ball set rolling along each piece's rideable top publishes ride_grapple_line through the row's
# sensor, advances down the line, and never holds under 2 m/s for more than 0.5 s (PARK.md section 8, the dead-stop rule).
# Evidence limit: headless physics on the baked collider and the rail maths; no render, no player input, no feel claim.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Augments := preload("res://src/movement/augments.gd")
const RideRail := preload("res://src/world/ride_rail.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

const RECIPES := {
	"canal_lip": {"element": "grind_line", "size": [120.0, 3.0, 8.8]},
	"flume_span": {"element": "grind_line", "size": [120.0, 8.0, 8.0]},
	"penstock_run": {"element": "grind_line", "size": [120.0, 5.0, 4.4]},
	"pipeline_rail": {"element": "rail", "size": [120.0, 3.0, 3.8]},
}
const FACT := "ride_grapple_line"
const MIN_SPEED := 2.0
const MAX_SLOW_S := 0.5
const MIN_RAIL_SHARE := 0.9
const TOP_TOLERANCE := 0.06
const SPACING := 400.0
const ROLL_SPEED := 10.0
const ROLL_SECONDS := 20.0
const RIDE_PLANAR := 12.0
const RIDE_FLOOR := 14.0
const REACH := 45.0
const SIDE_GAP := 10.0
const ON_TOP := 0.6

var _t := T.new("park_recipes_grind_test")
var _facts: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var loaded := {}
	for id in RECIPES:
		loaded[id] = _check_files(id)
	var ids: Array = RECIPES.keys().filter(func(k): return loaded[k])
	var rails := {}
	for id in ids:
		rails[id] = _check_rail(id)
	_check_fact_row()
	var parent := Node3D.new()
	root.add_child(parent)
	var placed := {}
	var i := 0
	for id in ids:
		placed[id] = _place(id, parent, i)
		_check_placed(id, placed[id])
		i += 1
	await physics_frame
	await physics_frame
	for id in ids:
		_check_rail_on_top(id, rails[id], placed[id])
		_check_bite_and_ride(id, rails[id], placed[id])
	await _check_roll(ids, rails, placed)
	parent.free()
	quit(_t.verdict())


func _path(id: String, part: String) -> String:
	return ParkRecipes.paths(id, "landform")[part] if part == "base" else ParkRecipes.paths(id, "landform")["shells"][int(part)]


# (a) the three GLBs exist, the base carries a -col mesh and the rail empties, and nothing is a light.
func _check_files(id: String) -> bool:
	var ok := true
	for part in ["base", "0", "1"]:
		var path := _path(id, part)
		var exists := ResourceLoader.exists(path)
		_t.check("(a) %s: %s exists" % [id, path.get_file()], exists, path)
		ok = ok and exists
	if not ok:
		return false
	var scene := _scene(_path(id, "base"))
	var cols := scene.find_children("*-col", "MeshInstance3D", true, false)
	_t.check("(a) %s: one %s-col mesh in the base GLB" % [id, id], cols.size() == 1 and String(cols[0].name) == id + ParkRecipes.COL_SUFFIX,
		str(cols.map(func(n): return n.name)))
	var drawn := scene.find_children("*", "MeshInstance3D", true, false).filter(func(m): return not String(m.name).ends_with(ParkRecipes.COL_SUFFIX))
	_t.check("(a) %s: the base draws one render mesh" % id, drawn.size() == 1, str(drawn.map(func(n): return n.name)))
	for part in ["base", "0", "1"]:
		var s := _scene(_path(id, part))
		_t.check("(a) %s %s: no light node (lint rule L6)" % [id, part], s.find_children("*", "Light3D", true, false).is_empty())
		s.free()
	scene.free()
	return true


func _scene(path: String) -> Node:
	return (load(path) as PackedScene).instantiate()


# The rail line: the GLB's "<id>-rail_NN" nodes in numeric order, as points in the recipe's own space.
func _rail_points(id: String) -> PackedVector3Array:
	var scene := _scene(_path(id, "base"))
	var named := {}
	for n: Node3D in scene.find_children(id + "-rail_*", "Node3D", true, false):
		named[String(n.name)] = ParkRecipes.relative_transform(n, scene).origin
	scene.free()
	var keys := named.keys()
	keys.sort()
	var out := PackedVector3Array()
	for k in keys:
		out.append(named[k])
	return out


# (b) the rail line.
func _check_rail(id: String) -> PackedVector3Array:
	var pts := _rail_points(id)
	var length := float(RECIPES[id]["size"][0])
	_t.check("(b) %s: the rail has at least 3 points" % id, pts.size() >= 3, "%d points" % pts.size())
	if pts.size() < 3:
		return pts
	var mono := true
	for k in range(1, pts.size()):
		mono = mono and pts[k].z > pts[k - 1].z + 1.0
	_t.check("(b) %s: the rail runs down +Z, every step over 1 m" % id, mono, str(pts))
	_t.check("(b) %s: the rail starts at the entry lip (z within 1 m of 0)" % id, absf(pts[0].z) <= 1.0, str(pts[0]))
	_t.check("(b) %s: the rail spans %.0f percent of the length" % [id, MIN_RAIL_SHARE * 100.0],
		pts[pts.size() - 1].z - pts[0].z >= MIN_RAIL_SHARE * length, "%.1f of %.1f" % [pts[pts.size() - 1].z - pts[0].z, length])
	var falls := pts[pts.size() - 1].y < pts[0].y
	_t.check("(b) %s: the rail falls toward the exit" % id, falls, "%.2f to %.2f" % [pts[0].y, pts[pts.size() - 1].y])
	return pts


func _check_fact_row() -> void:
	_t.check("(e) ride_grapple_line is a WORLD_ROWS row", EventKinds.WORLD_ROWS.has(FACT))


func _row(id: String, slot: int) -> Dictionary:
	var spec: Dictionary = RECIPES[id]
	return {"id": "grind_" + id, "element": spec["element"], "at": [slot * SPACING, 0.0], "y": null, "size": spec["size"], "yaw_deg": 0.0,
		"ride_fact": FACT, "recipe": id, "budget": "landform"}


func _place(id: String, parent: Node3D, slot: int) -> Node3D:
	var publish := func(kind: String, at: Vector3) -> void: _facts.append([kind, at])
	return ParkRecipes.place(_row(id, slot), parent, Callable(), publish)


# The GLB's origin in the world: its entry lip, half a length behind the row's centred at (park_recipes.gd ride_frame).
func _origin(node: Node3D) -> Vector3:
	var recipe := String(node.get_meta("park_recipe"))
	return node.global_transform * (ParkRecipes.ride_frame(_row(recipe, 0))["origin"] as Vector3)


# (c) placed through park_recipes.gd.
func _check_placed(id: String, node: Node3D) -> void:
	if not _t.check("(c) %s: places as a GLB recipe" % id, node != null and node.find_children("Greybox", "MeshInstance3D", true, false).is_empty()):
		return
	var body: StaticBody3D = node.get_node("Collider")
	var shapes := body.find_children("*", "CollisionShape3D", false, false)
	_t.check("(c) %s: the -col mesh is the one trimesh on the body" % id, shapes.size() == 1 and shapes[0].shape is ConcavePolygonShape3D, str(shapes))
	var drawn := node.find_children("*" + ParkRecipes.COL_SUFFIX, "MeshInstance3D", true, false)
	_t.check("(c) %s: the -col mesh is never drawn" % id, drawn.is_empty(), str(drawn))
	var views := node.find_children("*", "MeshInstance3D", true, false)
	_t.check("(c) %s: one base view and two detail shell views" % id, views.size() == 3, "%d views" % views.size())
	_t.check("(c) %s: the ride sensor is on the node" % id, node.get_node_or_null("Ride") != null)


func _space() -> PhysicsDirectSpaceState3D:
	return (root.get_world_3d() as World3D).direct_space_state


func _ray_down(point: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 6.0, point + Vector3.DOWN * 12.0, Augments.WORLD_MASK)
	return _space().intersect_ray(q)


# (b) continued: every rail point lies on a walkable top of the collider.
func _check_rail_on_top(id: String, pts: PackedVector3Array, node: Node3D) -> void:
	if node == null or pts.size() < 3:
		return
	var worst := 0.0
	var steep := 0
	for p in pts:
		var hit := _ray_down(_origin(node) + p)
		if hit.is_empty():
			worst = INF
			continue
		worst = maxf(worst, absf((hit["position"] as Vector3).y - (_origin(node).y + p.y)))
		if (hit["normal"] as Vector3).y <= Augments.WALKABLE_Y:
			steep += 1
	_t.check("(b) %s: every rail point lies on the collider top (within %.2f m)" % [id, TOP_TOLERANCE], worst <= TOP_TOLERANCE, "worst %.3f" % worst)
	_t.check("(b) %s: the rail top is walkable ground, so the roll can use it" % id, steep == 0, "%d steep points" % steep)


# The beam side of the piece, aimed across it at half its height.
func _side_shot(id: String, node: Node3D, rail: PackedVector3Array) -> Dictionary:
	var mid := rail[rail.size() / 2]
	var height: float = RECIPES[id]["size"][1]
	var from := _origin(node) + Vector3(-SIDE_GAP, mid.y - height * 0.45, mid.z)
	return {"from": from, "forward": Vector3.RIGHT}


# (d) the bite and (e) the ride.
func _check_bite_and_ride(id: String, rail: PackedVector3Array, node: Node3D) -> void:
	if node == null or rail.size() < 3:
		return
	var shot := _side_shot(id, node, rail)
	var from: Vector3 = shot["from"]
	var aim := Augments.grapple_target(_space(), from, shot["forward"], from, REACH, 0.0, Augments.WORLD_MASK | Augments.ENEMY_MASK, false)
	var bit: bool = aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE
	if not _t.check("(d) %s: the harpoon bites the piece from its beam side" % id, bit, str(aim)):
		return
	var point: Vector3 = aim["point"]
	var normal: Vector3 = aim["normal"]
	_t.check("(d) %s: the bite is on a steep face (normal.y %.2f, rule %.1f)" % [id, normal.y, Augments.WALKABLE_Y], normal.y <= Augments.WALKABLE_Y)
	var local := point - _origin(node)
	_t.check("(d) %s: the bite lands on the piece's own footprint" % id, absf(local.x) <= RECIPES[id]["size"][2] and local.z >= 0.0 and local.z <= RECIPES[id]["size"][0],
		str(local))
	# The control: the same rule aimed straight down at the walkable top refuses it.
	var top := _origin(node) + rail[rail.size() / 2]
	var down := Augments.grapple_target(_space(), top + Vector3.UP * 5.0, Vector3.DOWN, top + Vector3.UP * 5.0, REACH, 0.0,
		Augments.WORLD_MASK | Augments.ENEMY_MASK, false)
	_t.check("(d) %s: aimed straight down at the walkable top the harpoon is refused" % id, down.get("state", Augments.AIM_NONE) == Augments.AIM_NONE, str(down))
	# The ride: from the rail point nearest the bite to the rail's end.
	var entry := 0
	var best := INF
	for k in rail.size():
		var d := (_origin(node) + rail[k]).distance_to(point)
		if d < best:
			best = d
			entry = k
	var rise := Vector3.UP * Tuning.RADIUS
	var legs := 0
	var ride_time := 0.0
	var slowest := INF
	var ok_line := true
	var length := 0.0
	var pos := _origin(node) + rail[entry] + rise
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	for k in range(entry + 1, rail.size()):
		var to := _origin(node) + rail[k] + rise
		var ride = RideRail.line("grapple_line", pos, to, RIDE_PLANAR, RIDE_FLOOR)
		length += pos.distance_to(to)
		var steps := 0
		while true:
			var v = ride.step(dt)
			if v == null:
				break
			slowest = minf(slowest, (v as Vector3).length())
			steps += 1
			if steps > 100000:
				ok_line = false
				break
			var on: Vector3 = ride.point_at(ride.time)
			var seg := (to - pos).normalized()
			ok_line = ok_line and (on - pos).cross(seg).length() < 0.01
		ride_time += ride.time
		_t.check("(e) %s: leg %d lets go within the let-go margin of its end" % [id, legs], ride.point_at(ride.flight).distance_to(to) < 0.01
			and ride.release_speed >= RIDE_FLOOR, "%s vs %s" % [ride.point_at(ride.flight), to])
		pos = to
		legs += 1
	_t.check("(e) %s: the ride covers the rail to its last point from rail_%02d" % [id, entry], legs == rail.size() - 1 - entry and legs >= 1 and pos.is_equal_approx(_origin(node) + rail[rail.size() - 1] + rise))
	_t.check("(e) %s: every tick holds the ball to the line" % id, ok_line)
	_t.check("(e) %s: the ride never drops under %.0f m/s (slowest %.1f)" % [id, MIN_SPEED, slowest], slowest >= MIN_SPEED)
	_t.check("(e) %s: the ride runs %.0f m in %.1f s, the floor speed over its planar length" % [id, length, ride_time],
		ride_time > 0.5 and absf(ride_time - _flat(rail, entry) / RIDE_FLOOR) < 0.1 * float(legs), "%.2f s" % ride_time)


# The rail's height at depth z, interpolated between its points.
func _rail_y(rail: PackedVector3Array, z: float) -> float:
	for k in range(1, rail.size()):
		if z <= rail[k].z:
			return lerpf(rail[k - 1].y, rail[k].y, clampf((z - rail[k - 1].z) / (rail[k].z - rail[k - 1].z), 0.0, 1.0))
	return rail[rail.size() - 1].y


# Planar length of the rail from point `from` to its end.
func _flat(rail: PackedVector3Array, from: int) -> float:
	var out := 0.0
	for k in range(from + 1, rail.size()):
		out += Vector2(rail[k].x - rail[k - 1].x, rail[k].z - rail[k - 1].z).length()
	return out


func _ball(parent: Node3D, at: Vector3, velocity: Vector3) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.set_collision_layer_value(2, true)
	ball.set_collision_mask_value(1, true)
	ball.gravity_scale = Tuning.new().f("gravity") / 9.8
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	ball.position = at
	ball.linear_velocity = velocity
	ball.angular_velocity = Vector3(velocity.length() / Tuning.RADIUS, 0.0, 0.0)
	parent.add_child(ball)
	return ball


# (f) a roll along each piece's rideable top.
func _check_roll(ids: Array, rails: Dictionary, placed: Dictionary) -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var balls := {}
	for id in ids:
		var node: Node3D = placed[id]
		var rail: PackedVector3Array = rails[id]
		if node == null or rail.size() < 3:
			continue
		var start := _origin(node) + rail[0] + Vector3(0, Tuning.RADIUS + 0.05, 1.0)
		balls[id] = {"ball": _ball(parent, start, Vector3(0, 0, ROLL_SPEED)), "slow": 0.0, "worst": 0.0, "z0": start.z}
	var frames := int(ROLL_SECONDS * Engine.physics_ticks_per_second)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	for f in frames:
		await physics_frame
		for id in balls:
			var row: Dictionary = balls[id]
			var ball: RigidBody3D = row["ball"]
			var length: float = RECIPES[id]["size"][0]
			var z: float = ball.global_position.z - _origin(placed[id] as Node3D).z
			if z < 4.0 or z > length - 6.0:
				continue
			if ball.linear_velocity.length() < MIN_SPEED:
				row["slow"] += dt
				row["worst"] = maxf(row["worst"], row["slow"])
			else:
				row["slow"] = 0.0
			row["far"] = maxf(float(row.get("far", 0.0)), z)
			var rail: PackedVector3Array = rails[id]
			var want_y := _rail_y(rail, z) + _origin(placed[id] as Node3D).y + Tuning.RADIUS
			var want_x := rail[0].x + _origin(placed[id] as Node3D).x
			row["off"] = maxf(float(row.get("off", 0.0)), maxf(absf(ball.global_position.y - want_y), absf(ball.global_position.x - want_x)))
	for id in balls:
		var row: Dictionary = balls[id]
		var length: float = RECIPES[id]["size"][0]
		_t.check("(f) %s: the roll never holds under %.0f m/s for over %.1f s (worst %.2f s)" % [id, MIN_SPEED, MAX_SLOW_S, row["worst"]], row["worst"] <= MAX_SLOW_S)
		_t.check("(f) %s: the ball rolls the length (reached %.0f of %.0f m)" % [id, float(row.get("far", 0.0)), length], float(row.get("far", 0.0)) >= length - 8.0)
		_t.check("(f) %s: the ball stays on the top (worst %.2f m off the rail line, limit %.1f)" % [id, float(row.get("off", 99.0)), ON_TOP], float(row.get("off", 99.0)) <= ON_TOP)
		var node: Node3D = placed[id]
		var near := _facts.filter(func(e): return absf(e[1].x - _origin(node).x) < SPACING * 0.5)
		_t.check("(f) %s: the roll publishes %s" % [id, FACT], near.any(func(e): return e[0] == FACT), str(near.map(func(e): return e[0])))
	_t.check("(f) every recipe rolled", balls.size() == RECIPES.size(), str(balls.keys()))
	parent.free()
