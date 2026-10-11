extends SceneTree
# 2026-10-10 (w13 KC5): the flooded-cavern family of design-v3/PARK.md section 4: cenote_pool, flooded_shaft, cavern_shell.
# Written red first (before tools/blender/park/caverns.py and the GLBs exist), then built to pass.
# (a) Files: each recipe has its base GLB and the two detail shells park_recipes.paths names.
# (b) The base scene: one "<recipe>-col" mesh, at most two drawn meshes, a "Water" mesh, no light, Anchor.NN nodes
# with no gap over the harpoon's 45 m rope range (tuning.gd rope range) along the line.
# (c) Placed through park_recipes.place: no greybox stand-in, every collider shape a trimesh, the row's ride sensor on.
# (d) Pool depth: rays from each water vertex down to the placed collider give a depth of at most 1.2 m (PARK.md:294) and
# at least 0.4 m, and the water sheet is flat. Positive control: a 3 m pit fails the same measure.
# (e) A headless roll (a RigidBody3D with the game ball's damping, friction, bounce and 0.3 m/s^2 rolling resistance) along
# each recipe from a 14 m/s approach publishes ride_drop, reaches the far end, and never drops under 2 m/s for more than
# 0.5 s (the dead-stop rule, PARK.md section 8). Pool drop: a ball landing in the pool at 10 m/s planar leaves it by its
# own speed. Positive control: a 4 m box pit holds the ball under 2 m/s for over 0.5 s and the detector says so.
# Evidence limit: headless Jolt physics on a RigidBody3D that copies the ball's settings, not rigid_ball.gd's own
# integrator; no look, feel or sound claim. The look comes from the blind pairs under artifacts/local/alpha/push/w13.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# Row size is [length along +z, height, width] (park_schema.gd); the recipe's nominal size matches the stage rows
# (west_cenote 70 x 20 x 60; west_gallery_1 190 x 16 x 30; the flooded shaft has no row yet, so its nominal is set here).
const RECIPES := {
	"cenote_pool": {"size": [70.0, 20.0, 60.0], "anchors": 6},
	"flooded_shaft": {"size": [80.0, 24.0, 16.0], "anchors": 5},
	"cavern_shell": {"size": [190.0, 16.0, 30.0], "anchors": 14},
}
const GLB_DIR := "res://assets/models/park/"
const ROPE_RANGE_M := 45.0
const MAX_ANCHOR_GAP_M := 40.0
const POOL_MAX_M := 1.2
const POOL_MIN_M := 0.4
const DEAD_SPEED := 2.0
const DEAD_SECONDS := 0.5
const APPROACH_SPEED := 14.0
const POOL_SPEED := 10.0
const ROLLING_RESISTANCE := 0.3
const ROLL_FRAMES := 3600
const POOL_FRAMES := 2400
const SPACING := 400.0
const APPROACH_M := 14.0
const SENSOR_LEAD_M := 6.0

var _t := T.new("park_recipes_caverns_test")
var _facts: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id in RECIPES:
		_check_files(id)
		_check_scene(id)
	var world := Node3D.new()
	root.add_child(world)
	var placed := _place_all(world)
	await physics_frame
	await physics_frame
	for id in RECIPES:
		_check_placed(id, placed[id])
		_check_pool(id, placed[id])
	await _check_controls(world)
	await _check_rolls(world, placed)
	world.free()
	quit(_t.verdict())


func _row(id: String, at: Vector2) -> Dictionary:
	var size: Array = RECIPES[id]["size"]
	return {"id": "w_" + id, "element": "flooded_cavern", "at": [at.x, at.y], "y": 0.0, "size": size, "yaw_deg": 0.0,
		"ride_fact": "ride_drop", "recipe": id, "budget": "park_large"}


# --- (a) ---------------------------------------------------------------------------------------------------------

func _check_files(id: String) -> void:
	var p := ParkRecipes.paths(id, "park_large")
	_t.check("(a) %s base GLB exists" % id, ResourceLoader.exists(p["base"]), p["base"])
	for k in 2:
		_t.check("(a) %s detail shell %d exists" % [id, k + 1], ResourceLoader.exists(p["shells"][k]), p["shells"][k])
	_t.check("(a) %s is a caverns row of park_recipes" % id, ParkRecipes.ROWS.get(id, {}).get("family", "") == "caverns"
		and ParkRecipes.ROWS[id]["budget"] == "park_large")


# --- (b) ---------------------------------------------------------------------------------------------------------

func _load_scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _check_scene(id: String) -> void:
	var scene := _load_scene(ParkRecipes.paths(id, "park_large")["base"])
	if not _t.check("(b) %s base scene loads" % id, scene != null):
		return
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var cols := meshes.filter(func(m): return String(m.name) == id + ParkRecipes.COL_SUFFIX)
	var drawn := meshes.filter(func(m): return not String(m.name).ends_with(ParkRecipes.COL_SUFFIX))
	_t.check("(b) %s has exactly one -col mesh" % id, cols.size() == 1, str(meshes.map(func(m): return m.name)))
	_t.check("(b) %s draws at most 2 meshes (park_large)" % id, drawn.size() >= 1 and drawn.size() <= 2, str(drawn.size()))
	_t.check("(b) %s has a Water mesh" % id, drawn.any(func(m): return String(m.name) == "Water"))
	_t.check("(b) %s carries no light" % id, scene.find_children("*", "Light3D", true, false).is_empty())
	var zs: Array = []
	for n in scene.find_children("Anchor*", "Node3D", true, false):
		zs.append((n as Node3D).global_position.z if (n as Node3D).is_inside_tree() else _scene_z(n as Node3D, scene))
	zs.sort()
	_t.check("(b) %s has at least %d anchors" % [id, RECIPES[id]["anchors"]], zs.size() >= int(RECIPES[id]["anchors"]), str(zs.size()))
	var gap := 0.0
	var prev := 0.0
	for z: float in zs:
		gap = maxf(gap, z - prev)
		prev = z
	_t.check("(b) %s anchor gap under the rope range" % id, not zs.is_empty() and gap <= MAX_ANCHOR_GAP_M and gap < ROPE_RANGE_M,
		"max gap %.1f m over %s" % [gap, zs.size()])
	scene.free()


func _scene_z(n: Node3D, top: Node) -> float:
	var xf := Transform3D.IDENTITY
	var walk: Node = n
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf.origin.z


# --- (c) ---------------------------------------------------------------------------------------------------------

func _place_all(world: Node3D) -> Dictionary:
	var out := {}
	var i := 0
	for id in RECIPES:
		# The row's at is the footprint's centre (PARK.md:77), so the entry lip lands at z 0 and the ride runs z 0 .. L.
		var half: float = float(RECIPES[id]["size"][0]) * 0.5
		out[id] = ParkRecipes.place(_row(id, Vector2(i * SPACING, half)), world, Callable(), func(kind: String, at: Vector3) -> void: _facts.append([kind, at]))
		i += 1
	return out


func _check_placed(id: String, node: Node3D) -> void:
	if not _t.check("(c) %s places" % id, node != null):
		return
	_t.check("(c) %s is the GLB recipe, not the greybox stand-in" % id, node.find_child("Greybox", true, false) == null)
	var shapes := node.find_children("*", "CollisionShape3D", true, false).filter(func(s): return s.get_parent() is StaticBody3D)
	_t.check("(c) %s collider is trimesh only" % id, shapes.size() >= 1 and shapes.all(func(s): return s.shape is ConcavePolygonShape3D),
		"%d shapes" % shapes.size())
	var faces := 0
	for s: CollisionShape3D in shapes:
		if s.shape is ConcavePolygonShape3D:
			faces += (s.shape as ConcavePolygonShape3D).get_faces().size() / 3
	_t.check("(c) %s collider has real triangles" % id, faces >= 200, "%d" % faces)
	var views := node.find_children("*", "MeshInstance3D", true, false)
	_t.check("(c) %s draws are views only (no -col drawn)" % id, views.size() >= 3 and not views.any(func(v): return String(v.name).ends_with(ParkRecipes.COL_SUFFIX)),
		"%d views" % views.size())
	_t.check("(c) %s has a ride sensor" % id, node.find_child("Ride", true, false) != null)


# --- (d) ---------------------------------------------------------------------------------------------------------

# Down-rays from just above each water vertex to the collider below: [depths], and the water's y spread.
func _pool_depths(node: Node3D, water: MeshInstance3D) -> Dictionary:
	var space := root.get_world_3d().direct_space_state
	var arrays := water.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var depths: Array = []
	var lo := INF
	var hi := -INF
	for v in verts:
		var w := water.global_transform * v
		lo = minf(lo, w.y)
		hi = maxf(hi, w.y)
		var q := PhysicsRayQueryParameters3D.create(w + Vector3(0, 0.3, 0), w - Vector3(0, 30, 0))
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			depths.append(w.y - float(hit["position"].y))
	return {"depths": depths, "spread": hi - lo, "count": verts.size()}


func _check_pool(id: String, node: Node3D) -> void:
	if node == null:
		_t.check("(d) %s has a pool to measure" % id, false)
		return
	var water := node.find_child("Water", true, false) as MeshInstance3D
	if not _t.check("(d) %s water view is placed" % id, water != null):
		return
	var m := _pool_depths(node, water)
	var depths: Array = m["depths"].filter(func(d): return d > 0.02)
	var deepest: float = depths.max() if not depths.is_empty() else -1.0
	_t.check("(d) %s water sheet is flat" % id, m["spread"] <= 0.001, "spread %s" % m["spread"])
	_t.check("(d) %s pool is at most 1.2 m deep" % id, not depths.is_empty() and deepest <= POOL_MAX_M, "deepest %.3f m over %d rays" % [deepest, depths.size()])
	_t.check("(d) %s pool is at least 0.4 m deep" % id, deepest >= POOL_MIN_M, "deepest %.3f m" % deepest)


# A pit or ramp as a trimesh body from triangles (the controls below).
func _trimesh_body(parent: Node3D, tris: PackedVector3Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.set_collision_layer_value(1, true)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(tris)
	shape.shape = concave
	body.add_child(shape)
	parent.add_child(body)
	return body


# Godot's front face is clockwise, so a quad given counter-clockwise from its visible side is emitted reversed.
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> PackedVector3Array:
	return PackedVector3Array([a, c, b, a, d, c])


# A pit floor at y=-depth between z0 and z1 with vertical walls up to y=0, floor wide in x.
func _pit(parent: Node3D, at: Vector3, depth: float, z0: float, z1: float, half: float) -> StaticBody3D:
	var f := PackedVector3Array()
	f.append_array(_quad(Vector3(-half, -depth, z0), Vector3(-half, -depth, z1), Vector3(half, -depth, z1), Vector3(half, -depth, z0)))
	f.append_array(_quad(Vector3(-half, 0, z0 - 30), Vector3(-half, 0, z0), Vector3(half, 0, z0), Vector3(half, 0, z0 - 30)))
	f.append_array(_quad(Vector3(-half, 0, z0), Vector3(-half, -depth, z0), Vector3(half, -depth, z0), Vector3(half, 0, z0)))
	f.append_array(_quad(Vector3(-half, -depth, z1), Vector3(-half, 0, z1), Vector3(half, 0, z1), Vector3(half, -depth, z1)))
	f.append_array(_quad(Vector3(-half, 0, z1), Vector3(-half, 0, z1 + 30), Vector3(half, 0, z1 + 30), Vector3(half, 0, z1)))
	var body := _trimesh_body(parent, f)
	body.position = at
	return body


func _check_controls(world: Node3D) -> void:
	# Depth control: a 3 m pit with water at its rim reads 3 m, so the 1.2 m check can fail.
	var pit := _pit(world, Vector3(-5000, 0, 0), 3.0, 0.0, 20.0, 8.0)
	var water := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in _quad(Vector3(-4, 0, 4), Vector3(-4, 0, 16), Vector3(4, 0, 16), Vector3(4, 0, 4)):
		st.add_vertex(p)
	water.mesh = st.commit()
	pit.add_child(water)
	await physics_frame
	await physics_frame
	var deep := _pool_depths(pit, water)
	var deepest: float = deep["depths"].max() if not deep["depths"].is_empty() else -1.0
	_t.check("(d) control: the depth measure reads a 3 m pit as 3 m", absf(deepest - 3.0) < 0.05, "%.3f" % deepest)
	_t.check("(d) control: a 3 m pit fails the 1.2 m limit", deepest > POOL_MAX_M)
	# Dead-stop control: a ball dropped into a 4 m box pit at 6 m/s stays under 2 m/s planar for over 0.5 s.
	var pit2 := _pit(world, Vector3(-6000, 0, 0), 4.0, 0.0, 6.0, 8.0)
	var ball := _ball(world, pit2.position + Vector3(0, 1.2, 2.0), Vector3(0, 0, 6))
	var tracker := {"run": 0, "worst": 0, "frames": 0}
	for f in 480:
		_resist(ball)
		await physics_frame
		_track(ball, tracker, true)
	var worst: float = float(tracker["worst"]) / Engine.physics_ticks_per_second
	_t.check("(e) control: the detector flags a ball held in a 4 m pit", worst > DEAD_SECONDS, "worst %.2f s" % worst)
	ball.queue_free()


# --- (e) ---------------------------------------------------------------------------------------------------------

func _ball(parent: Node3D, at: Vector3, velocity: Vector3) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	ball.mass = 6.0
	ball.continuous_cd = true
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp = 0.25
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.25
	ball.physics_material_override = material
	ball.contact_monitor = true
	ball.max_contacts_reported = 4
	ball.collision_layer = 0
	ball.set_collision_layer_value(2, true)
	ball.collision_mask = 0
	ball.set_collision_mask_value(1, true)
	ball.gravity_scale = Tuning.new().f("gravity") / 9.8
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	ball.position = at
	ball.linear_velocity = velocity
	# Thrown rolling: a ball given only linear speed spends 2/7 of it spinning up on the floor.
	ball.angular_velocity = Vector3(velocity.z, 0, -velocity.x) / Tuning.RADIUS
	parent.add_child(ball)
	return ball


# The game ball pays rolling_resistance (0.3 m/s^2) while grounded and nothing else on the ground (rigid_ball.gd).
func _resist(ball: RigidBody3D) -> void:
	if ball.get_colliding_bodies().size() > 0 and ball.linear_velocity.length() > 0.1:
		ball.apply_central_force(-ball.linear_velocity.normalized() * ROLLING_RESISTANCE * ball.mass)


# tracker: run = consecutive frames under DEAD_SPEED, worst = the longest run, frames = frames tracked.
func _track(ball: RigidBody3D, tracker: Dictionary, active: bool) -> void:
	if not active:
		return
	var planar := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
	tracker["frames"] += 1
	if planar < DEAD_SPEED:
		tracker["run"] += 1
		tracker["worst"] = maxi(tracker["worst"], tracker["run"])
	else:
		tracker["run"] = 0


func _check_rolls(world: Node3D, placed: Dictionary) -> void:
	var rolls := {}
	var i := 0
	for id in RECIPES:
		var node: Node3D = placed[id]
		var size: Array = RECIPES[id]["size"]
		var width: float = size[2]
		var length: float = size[0]
		if node == null:
			rolls[id] = null
			i += 1
			continue
		var x0 := node.position.x
		# An approach plank on the ground before the lip, so the ball arrives rolling at y 0.
		# The ride sensor is centred on the row's at (z L/2), so it spans z 0 .. L, the piece itself; the plank starts the ball
		# before z 0, outside the sensor, so the fact comes from the sensor's own entry at the lip, not from the spawn.
		var lead := maxf(APPROACH_M, length * 0.5 + SENSOR_LEAD_M)
		var plank := PackedVector3Array()
		plank.append_array(_quad(Vector3(-width * 0.5, 0, -lead), Vector3(-width * 0.5, 0, 0.01), Vector3(width * 0.5, 0, 0.01), Vector3(width * 0.5, 0, -lead)))
		_trimesh_body(world, plank).position = Vector3(x0, 0, 0)
		var ball := _ball(world, Vector3(x0, Tuning.RADIUS + 0.02, -lead + 2.0), Vector3(0, 0, APPROACH_SPEED))
		rolls[id] = {"ball": ball, "tracker": {"run": 0, "worst": 0, "frames": 0}, "done": false, "x0": x0, "length": length,
			"exit_speed": 0.0, "min_y": 0.0, "end_frame": -1, "end_y": 0.0}
		i += 1
	for f in ROLL_FRAMES:
		for id in rolls:
			var r = rolls[id]
			if r == null or r["done"]:
				continue
			_resist(r["ball"])
		await physics_frame
		for id in rolls:
			var r = rolls[id]
			if r == null or r["done"]:
				continue
			var ball: RigidBody3D = r["ball"]
			var on_line: bool = ball.position.z >= 0.0
			_track(ball, r["tracker"], on_line)
			r["min_y"] = minf(r["min_y"], ball.position.y)
			if ball.position.z >= float(r["length"]) - 1.0:
				r["done"] = true
				r["end_frame"] = f
				r["end_y"] = ball.position.y
				r["exit_speed"] = Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
		if rolls.values().all(func(r): return r == null or r["done"]):
			break
	for id in RECIPES:
		var r = rolls[id]
		if not _t.check("(e) %s rolls: the recipe placed" % id, r != null):
			continue
		var ball: RigidBody3D = r["ball"]
		_t.check("(e) %s: the ball rolls the whole line, supported at the far end" % id, r["done"] and float(r["end_y"]) - float(r["min_y"]) < 12.0 and r["min_y"] > -40.0,
			"done %s, end y %.1f, min y %.1f" % [r["done"], r["end_y"], r["min_y"]])
		var worst: float = float(r["tracker"]["worst"]) / Engine.physics_ticks_per_second
		_t.check("(e) %s: no dead stop (under 2 m/s for over 0.5 s)" % id, r["done"] and worst <= DEAD_SECONDS, "worst %.2f s" % worst)
		_t.check("(e) %s: leaves at speed" % id, r["exit_speed"] >= DEAD_SPEED * 2.0, "%.1f m/s" % r["exit_speed"])
		var near := _facts.filter(func(e): return absf(e[1].x - r["x0"]) < SPACING * 0.5)
		_t.check("(e) %s: the roll publishes ride_drop (from the sensor entry, the ball started outside it)" % id, near.any(func(e): return e[0] == "ride_drop"), str(near.map(func(e): return e[0])))
		ball.queue_free()
	await _check_pool_drop(world, placed)


# A ball landing in each pool at 10 m/s planar leaves the pool's far edge by its own speed, with no extra push.
func _check_pool_drop(world: Node3D, placed: Dictionary) -> void:
	var drops := {}
	for id in RECIPES:
		var node: Node3D = placed[id]
		var water := node.find_child("Water", true, false) as MeshInstance3D if node != null else null
		if water == null:
			drops[id] = null
			continue
		var box := water.global_transform * water.mesh.get_aabb()
		var z_in := box.position.z + box.size.z * 0.25
		var z_out := box.position.z + box.size.z
		var ball := _ball(world, Vector3(box.get_center().x, box.position.y + 5.0, z_in), Vector3(0, 0, POOL_SPEED))
		drops[id] = {"ball": ball, "z_out": z_out, "length": float(RECIPES[id]["size"][0]), "done": false, "tracker": {"run": 0, "worst": 0, "frames": 0}, "out_speed": -1.0, "min_y": INF,
			"water_y": box.position.y}
	for f in POOL_FRAMES:
		for id in drops:
			if drops[id] != null:
				_resist(drops[id]["ball"])
		await physics_frame
		for id in drops:
			var d = drops[id]
			if d == null or d["done"]:
				continue
			var ball: RigidBody3D = d["ball"]
			if d["out_speed"] < 0.0:
				d["min_y"] = minf(d["min_y"], ball.position.y)
			_track(ball, d["tracker"], true)
			if d["out_speed"] < 0.0 and ball.position.z >= d["z_out"] + 2.0:
				d["out_speed"] = Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
			if ball.position.z >= float(d["length"]) - 1.0:
				d["done"] = true
		if drops.values().all(func(d): return d == null or d["done"]):
			break
	for id in RECIPES:
		var d = drops[id]
		if not _t.check("(e) %s pool drop: a pool exists" % id, d != null):
			continue
		var ball: RigidBody3D = d["ball"]
		_t.check("(e) %s pool drop: the ball sank into the pool (centre within 0.3 m of the sheet, floor under 1.2 m)" % id,
			d["min_y"] <= float(d["water_y"]) + 0.3 and d["min_y"] >= float(d["water_y"]) - 0.35,
			"min y %.2f, water y %.2f" % [d["min_y"], d["water_y"]])
		_t.check("(e) %s pool drop: it rolls out by its own planar speed" % id, d["out_speed"] >= DEAD_SPEED,
			"out speed %.1f at z %.1f (z_out %.1f)" % [d["out_speed"], ball.position.z, d["z_out"]])
		var worst: float = float(d["tracker"]["worst"]) / Engine.physics_ticks_per_second
		_t.check("(e) %s pool drop: the ball leaves the recipe (z >= length - 1 within 2400 frames)" % id, d["done"],
			"z %.1f of %.1f" % [ball.position.z, d["length"]])
		_t.check("(e) %s pool drop: no dead stop (under 2 m/s for over 0.5 s)" % id, d["done"] and worst <= DEAD_SECONDS, "worst %.2f s" % worst)
		ball.queue_free()
