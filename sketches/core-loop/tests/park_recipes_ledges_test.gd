extends SceneTree
# 2026-10-10 (w13 KC6): the ledges family (design-v3/PARK.md section 4): cliff_dwelling_row, mesa_rim_ledge, viga_pivot.
# (a) Each recipe ships its base GLB, a <id>-col trimesh node and the two detail shells park_recipes.gd names (_detail1,
# _detail2); the base with its -col mesh stays inside the landform budget (8,000 triangles) and each shell inside detail (1,500).
# (b) Convention: +Y up, the ride along +Z from the entry lip at the origin, centred on x; the -col mesh spans z 0 to the
# recipe's length and its walkable top (the shelf) is a ledge at least 8 m deep in x.
# (c) The harpoon targets: a ray dropped on each projecting beam of viga_pivot and of the first dwelling room hits a collider
# at the beam's top.
# (d) A headless roll: a ball rolling at 20 m/s from the ground onto each recipe, placed through park_recipes.gd with its
# row's ride_ledge fact, publishes ride_ledge, crosses the whole line, stays on the shelf, and never spends more than 0.5 s
# under 2 m/s on the line (PARK.md section 8 dead-stop rule).
# Evidence limit: headless physics on the placed recipe with a bare rigid ball; no look, feel or harpoon-swing claim.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

const SHELF_Y := 2.5
const MIN_DEPTH_M := 8.0
const BASE_TRIS := 8000
const SHELL_TRIS := 1500
const DEAD_SPEED := 2.0
const DEAD_SECONDS := 0.5
const START_SPEED := 20.0
const ROLL_FRAMES := 540
# id: [length (z), height (y), width (x), lane x of the roll]
const RECIPES := {
	"cliff_dwelling_row": [60.0, 11.0, 14.0, 2.0],
	"mesa_rim_ledge": [60.0, 7.0, 18.0, 0.0],
	"viga_pivot": [36.0, 9.0, 12.0, 1.0],
}
const DIR := "res://assets/models/park/"

var _t := T.new("park_recipes_ledges_test")
var _facts: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id: String in RECIPES:
		_check_files(id)
	await _check_beams()
	await _check_rolls()
	quit(_t.verdict())


func _scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _tris(scene: Node, want_col: bool) -> int:
	var n := 0
	for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).ends_with(ParkRecipes.COL_SUFFIX) != want_col or m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var arrays := m.mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_INDEX] != null:
				n += arrays[Mesh.ARRAY_INDEX].size() / 3
			else:
				n += arrays[Mesh.ARRAY_VERTEX].size() / 3
	return n


func _col_faces(scene: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).ends_with(ParkRecipes.COL_SUFFIX):
			out.append_array(m.mesh.create_trimesh_shape().get_faces())
	return out


func _check_files(id: String) -> void:
	var base := _scene(DIR + id + ".glb")
	if not _t.check("(a) %s.glb exists and loads" % id, base != null):
		return
	var col_tris := _tris(base, true)
	_t.check("(a) %s has a -col mesh named %s-col" % [id, id], base.find_child(id + "-col", true, false) != null and col_tris > 0, "col tris %d" % col_tris)
	var drawn := _tris(base, false)
	_t.check("(a) %s base plus -col is inside the landform budget" % id, drawn > 0 and drawn + col_tris <= BASE_TRIS, "%d + %d" % [drawn, col_tris])
	var shells: Array = ParkRecipes.paths(id, "landform")["shells"]
	for k in shells.size():
		var shell := _scene(shells[k])
		var tris := _tris(shell, false) if shell != null else -1
		_t.check("(a) %s detail shell %d is inside the detail budget" % [id, k + 1], shell != null and tris > 0 and tris <= SHELL_TRIS, "tris %d" % tris)
		if shell != null:
			shell.free()
	var size: Array = RECIPES[id]
	var faces := _col_faces(base)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for p in faces:
		lo = lo.min(p)
		hi = hi.max(p)
	_t.check("(b) %s collider runs z 0 to %.0f from the entry lip" % [id, size[0]], faces.size() > 0 and absf(lo.z) < 0.05 and absf(hi.z - float(size[0])) < 0.05,
		"z %.2f to %.2f" % [lo.z, hi.z])
	var depth_lo := INF
	var depth_hi := -INF
	for k in range(0, faces.size() - 2, 3):
		var n := (faces[k + 1] - faces[k]).cross(faces[k + 2] - faces[k])
		if n.length() < 0.0001 or absf(n.normalized().y) < 0.99:
			continue
		if absf(faces[k].y - SHELF_Y) > 0.02:
			continue
		for q in [faces[k], faces[k + 1], faces[k + 2]]:
			if q.z > 13.0 and q.z < float(size[0]) - 13.0:
				depth_lo = minf(depth_lo, q.x)
				depth_hi = maxf(depth_hi, q.x)
	_t.check("(b) %s has a shelf at y %.1f at least %.0f m deep" % [id, SHELF_Y, MIN_DEPTH_M], depth_hi - depth_lo >= MIN_DEPTH_M, "x %.2f to %.2f" % [depth_lo, depth_hi])
	_t.check("(b) %s collider stays +Y up near its width" % id, hi.y > SHELF_Y and lo.x >= -float(size[2]) - 6.0 and hi.x <= float(size[2]) * 0.5 + 9.0, "%s %s" % [lo, hi])
	base.free()


func _row(id: String) -> Dictionary:
	var s: Array = RECIPES[id]
	return {"id": "r_" + id, "element": "ledge", "at": [0.0, 0.0], "y": 0.0, "size": [s[0], s[1], s[2]], "yaw_deg": 0.0,
		"ride_fact": "ride_ledge", "recipe": id, "budget": "landform"}


func _ground(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.set_collision_layer_value(1, true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2000, 2, 400)
	shape.shape = box
	shape.position = Vector3(800, -1, 0)
	body.add_child(shape)
	parent.add_child(body)


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
	parent.add_child(ball)
	return ball


func _ray_down(world: PhysicsDirectSpaceState3D, at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3(0, 30, 0), at, 1)
	return world.intersect_ray(query)


func _check_beams() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var viga := _row("viga_pivot")
	ParkRecipes.place(viga, parent)
	var dwelling := _row("cliff_dwelling_row")
	dwelling["at"] = [200.0, 0.0]
	ParkRecipes.place(dwelling, parent)
	await physics_frame
	await physics_frame
	var world := parent.get_world_3d().direct_space_state
	# viga_pivot: four beams across the lane at y 7.5, tips out over the lip; cliff_dwelling_row: room 0's lower beams.
	for z in [10.5, 16.0, 21.5, 27.0]:
		var hit := _ray_down(world, Vector3(4.0, 0.0, z))
		_t.check("(c) viga_pivot beam at z %.1f takes a ray at its top" % z, not hit.is_empty() and absf(hit["position"].y - 7.78) < 0.15,
			str(hit.get("position")))
	for z in [13.5, 15.0, 16.5]:
		var hit := _ray_down(world, Vector3(200.0 - 2.8, 0.0, z))
		_t.check("(c) cliff_dwelling_row room beam at z %.1f takes a ray at its top" % z, not hit.is_empty() and absf(hit["position"].y - 5.22) < 0.15,
			str(hit.get("position")))
	parent.free()


func _check_rolls() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	_ground(parent)
	var publish := func(kind: String, at: Vector3) -> void: _facts.append([kind, at])
	var runs: Array = []
	var i := 0
	for id: String in RECIPES:
		var s: Array = RECIPES[id]
		var row := _row(id)
		row["at"] = [i * 400.0, 0.0]
		ParkRecipes.place(row, parent, Callable(), publish)
		var ball := _ball(parent, Vector3(i * 400.0 + float(s[3]), 1.0, -45.0), Vector3(0, 0, START_SPEED))
		runs.append({"id": id, "ball": ball, "x": i * 400.0, "length": float(s[0]), "lane": float(s[3]), "slow": 0.0, "worst": 0.0, "min": INF,
			"off": false})
		i += 1
	for f in ROLL_FRAMES:
		await physics_frame
		for r in runs:
			var b: RigidBody3D = r["ball"]
			var z := b.position.z
			if z < 0.0 or z > r["length"]:
				continue
			var speed := Vector2(b.linear_velocity.x, b.linear_velocity.z).length()
			r["min"] = minf(r["min"], speed)
			if speed < DEAD_SPEED:
				r["slow"] += 1.0 / 60.0
				r["worst"] = maxf(r["worst"], r["slow"])
			else:
				r["slow"] = 0.0
			if b.position.y < -0.5:
				r["off"] = true
	for r in runs:
		var b: RigidBody3D = r["ball"]
		var id: String = r["id"]
		var near := _facts.filter(func(e): return absf(e[1].x - r["x"]) < 200.0)
		_t.check("(d) a roll along %s publishes ride_ledge" % id, near.any(func(e): return e[0] == "ride_ledge"), str(near.map(func(e): return e[0])))
		_t.check("(d) the ball crosses %s to its far lip" % id, b.position.z > r["length"] - 2.0, "z %.1f" % b.position.z)
		_t.check("(d) the ball stays on %s, never off the shelf or into the void" % id, not r["off"] and absf(b.position.x - (r["x"] + r["lane"])) < 6.0,
			"x %.1f y %.1f" % [b.position.x - r["x"], b.position.y])
		_t.check("(d) %s: no stretch under %.0f m/s lasts %.1f s (worst %.2f s, slowest %.1f m/s)" % [id, DEAD_SPEED, DEAD_SECONDS, r["worst"], r["min"]],
			r["worst"] <= DEAD_SECONDS and r["min"] != INF)
	parent.free()
