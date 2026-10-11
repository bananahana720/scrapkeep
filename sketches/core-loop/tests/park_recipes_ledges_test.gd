extends SceneTree
# 2026-10-10 (w13 KC6): the ledges family (design-v3/PARK.md section 4): cliff_dwelling_row, mesa_rim_ledge, viga_pivot.
# (a) Each recipe ships its base GLB, a <id>-col trimesh node and the two detail shells park_recipes.gd names (_detail1,
# _detail2); the base with its -col mesh stays inside the landform budget (8,000 triangles) and each shell inside detail (1,500).
# (b) Convention: +Y up, the ride along +Z from the entry lip at the origin, centred on x; the -col mesh spans z 0 to the
# recipe's length and its walkable top (the shelf) is a ledge at least 8 m deep in x.
# (c) The harpoon targets: a ray dropped on each projecting beam of viga_pivot and of the first dwelling room hits a collider
# at the beam's top.
# (d) A headless roll: a ball rolling at 16 m/s (the 14 m/s cruise plus a margin) from the ground onto each recipe, placed through park_recipes.gd with its
# row's ride_ledge fact, publishes ride_ledge, crosses the whole line, stays on the shelf, and never spends more than 0.5 s
# under 2 m/s on the line (PARK.md section 8 dead-stop rule). Two more rolls: mesa_rim_ledge along its banked open edge (lane x 7.5)
# and viga_pivot with a full jump (tuning jump_speed) at z 15, which must clear the beams without a dead stop.
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
const START_SPEED := 16.0
const SENSOR_STRICT := true   # KC-INT: the loader places the lip-origin GLB through its centred footprint, so the sensor covers the line
const LIP_SLACK := 1.0
const CLIP_FLOOR := 10.0   # the plain rolls bottom out at 11.5 to 12.2 m/s (the ramp climb); the bank and jump rolls must not fall below 10
# The bank roll drops the x check: the banked lip bends the line inward (a 22 degree slope), which is the verb; falling off (y < -0.5 on the line) and the speed floor still bind.
const ROLL_FRAMES := 900
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
	_t.check("(b) %s collider stays +Y up near its width" % id, hi.y > SHELF_Y and lo.x >= -float(size[2]) - 14.0 and hi.x <= float(size[2]) * 0.5 + 9.0, "%s %s" % [lo, hi])
	base.free()


# The test names where a GLB's entry-lip origin goes; a row's at is its footprint's centre (PARK.md:77), so the row's at is
# that point moved by the loader's own conversion (park_recipes.gd ride_frame), turned by the row's yaw.
func _centre(row: Dictionary) -> Dictionary:
	var o: Vector3 = ParkRecipes.ride_frame(row)["origin"]
	var yaw := deg_to_rad(float(row["yaw_deg"]))
	row["at"] = [float(row["at"][0]) - sin(yaw) * o.z, float(row["at"][1]) - cos(yaw) * o.z]
	return row


func _row(id: String, x := 0.0) -> Dictionary:
	var s: Array = RECIPES[id]
	return _centre({"id": "r_" + id, "element": "ledge", "at": [x, 0.0], "y": 0.0, "size": [s[0], s[1], s[2]], "yaw_deg": 0.0,
		"ride_fact": "ride_ledge", "recipe": id, "budget": "landform"})


func _ground(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.set_collision_layer_value(1, true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6000, 2, 400)
	shape.shape = box
	shape.position = Vector3(2500, -1, 0)
	body.add_child(shape)
	parent.add_child(body)


func _ball(parent: Node3D, at: Vector3, velocity: Vector3) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	# A free ball has no drive, so it carries no damping and little friction: the roll measures the line, not the ground it starts on.
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp = 0.0
	ball.physics_material_override = PhysicsMaterial.new()
	ball.physics_material_override.friction = 0.15
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
	ball.angular_velocity = Vector3.UP.cross(velocity) / Tuning.RADIUS   # already rolling, so the ground costs no speed
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
	var dwelling := _row("cliff_dwelling_row", 200.0)
	ParkRecipes.place(dwelling, parent)
	await physics_frame
	await physics_frame
	var world := parent.get_world_3d().direct_space_state
	# viga_pivot: four beams across the lane at y 8.6 (underside 5.8 m over the shelf, clear of a full jump), tips out over the lip; cliff_dwelling_row: room 0's lower beams.
	for z in [11.5, 16.0, 20.5, 25.0]:
		var hit := _ray_down(world, Vector3(4.0, 0.0, z))
		_t.check("(c) viga_pivot beam at z %.1f takes a ray at its top" % z, not hit.is_empty() and absf(hit["position"].y - 8.88) < 0.15,
			str(hit.get("position")))
	for z in [13.5, 15.0, 16.5]:
		var hit := _ray_down(world, Vector3(200.0 - 2.8, 0.0, z))
		_t.check("(c) cliff_dwelling_row room beam at z %.1f takes a ray at its top" % z, not hit.is_empty() and absf(hit["position"].y - 5.22) < 0.15,
			str(hit.get("position")))
	# The clear lane: rays down across x at a mid-shelf z hit the shelf at y 2.5 along an unbroken run of at least 8 m.
	var mesa := _row("mesa_rim_ledge", 400.0)
	ParkRecipes.place(mesa, parent)
	await physics_frame
	var mid := {"viga_pivot": [0.0, 18.0], "cliff_dwelling_row": [200.0, 14.25], "mesa_rim_ledge": [400.0, 30.0]}
	for id: String in mid:
		var run := 0.0
		var best := 0.0
		for k in range(-48, 49):
			var x := 0.25 * k
			var hit := _ray_down(world, Vector3(float(mid[id][0]) + x, 0.0, float(mid[id][1])))
			if not hit.is_empty() and absf(hit["position"].y - SHELF_Y) < 0.05:
				run += 0.25
				best = maxf(best, run)
			else:
				run = 0.0
		_t.check("(b) %s has a clear shelf at y %.1f at least %.0f m deep" % [id, SHELF_Y, MIN_DEPTH_M], best >= MIN_DEPTH_M, "run %.2f m" % best)
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
		var row := _row(id, i * 400.0)
		ParkRecipes.place(row, parent, Callable(), publish)
		var ball := _ball(parent, Vector3(i * 400.0 + float(s[3]), 1.0, -45.0), Vector3(0, 0, START_SPEED))
		runs.append({"id": id, "ball": ball, "x": i * 400.0, "length": float(s[0]), "lane": float(s[3]), "slow": 0.0, "worst": 0.0, "min": INF,
			"off": false, "on_shelf": 0})
		i += 1
	# The control: viga_pivot with a 5 m wall across the lane at z 20. The dead-stop detector must read it as a stop, or it measures nothing.
	var blocked := _row("viga_pivot", i * 400.0)
	ParkRecipes.place(blocked, parent)
	var wall := StaticBody3D.new()
	wall.collision_layer = 0
	wall.set_collision_layer_value(1, true)
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(12, 5, 1)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(i * 400.0, SHELF_Y + 2.5, 20.0)
	parent.add_child(wall)
	runs.append({"id": "viga_pivot (control: walled lane)", "ball": _ball(parent, Vector3(i * 400.0 + 1.0, 1.0, -45.0), Vector3(0, 0, START_SPEED)),
		"x": i * 400.0, "length": 36.0, "lane": 1.0, "slow": 0.0, "worst": 0.0, "min": INF, "off": false, "on_shelf": 0})
	i += 1
	# Extra rolls: the banked lip's open edge, and a full jump under the beams.
	var jump_speed: float = Tuning.new().f("jump_speed")
	for e: Array in [["mesa_rim_ledge (bank lane x 7.5)", "mesa_rim_ledge", 7.5, -1.0], ["viga_pivot (full jump at z 15)", "viga_pivot", 1.0, 15.0]]:
		var es: Array = RECIPES[e[1]]
		var erow := _row(e[1], i * 400.0)
		ParkRecipes.place(erow, parent, Callable(), publish)
		runs.append({"id": e[0], "ball": _ball(parent, Vector3(i * 400.0 + float(e[2]), 1.0, -45.0), Vector3(0, 0, START_SPEED)),
			"x": i * 400.0, "length": float(es[0]), "lane": float(e[2]), "slow": 0.0, "worst": 0.0, "min": INF, "off": false, "on_shelf": 0,
			"jump_z": float(e[3]), "jumped": false, "peak": 0.0})
		i += 1
	for f in ROLL_FRAMES:
		await physics_frame
		for r in runs:
			var b: RigidBody3D = r["ball"]
			var z := b.position.z
			if z < 0.0 or z > r["length"]:
				continue
			if r.get("jump_z", -1.0) > 0.0 and not r["jumped"] and z >= r["jump_z"]:
				b.linear_velocity.y = jump_speed
				r["jumped"] = true
			if r.has("peak"):
				r["peak"] = maxf(r["peak"], b.position.y)
			var speed := Vector2(b.linear_velocity.x, b.linear_velocity.z).length()
			r["min"] = minf(r["min"], speed)
			if speed < DEAD_SPEED:
				r["slow"] += 1.0 / float(Engine.physics_ticks_per_second)
				r["worst"] = maxf(r["worst"], r["slow"])
			else:
				r["slow"] = 0.0
			if b.position.y < -0.5:
				r["off"] = true
			if absf(b.position.y - (SHELF_Y + Tuning.RADIUS)) < 0.25:
				r["on_shelf"] += 1
	for r in runs:
		var b: RigidBody3D = r["ball"]
		var id: String = r["id"]
		if id.contains("control"):
			_t.check("(d) the control: a walled lane reads as a dead stop (%s, worst %.2f s)" % [id, r["worst"]], r["worst"] > DEAD_SECONDS and b.position.z < 20.0, "z %.1f" % b.position.z)
			continue
		var near := _facts.filter(func(e): return absf(e[1].x - r["x"]) < 200.0)
		_t.check("(d) a roll along %s publishes ride_ledge" % id, near.any(func(e): return e[0] == "ride_ledge"), str(near.map(func(e): return e[0])))
		var first := near.filter(func(e): return e[0] == "ride_ledge")
		if RECIPES.has(id) and not first.is_empty():
			# The fact must fire on the line (z from the entry lip), not on the approach: the sensor is centred on the row's at and the
			# loader runs the lip-origin GLB through that footprint (park_recipes.gd ride_frame, KC-INT).
			var first_z: float = first[0][1].z
			var on_line := first_z >= -LIP_SLACK
			if SENSOR_STRICT:
				_t.check("(d) %s's ride_ledge first fires on the line (z %.1f >= -%.1f)" % [id, first_z, LIP_SLACK], on_line)
			elif not on_line:
				print("LEDGES_SENSOR_GAP ", id, " ride_ledge first fires at row-local z ", first_z, " (before the entry lip; loader-side, see report)")
		if r.has("jump_z"):
			# A clip that only slows the ball (the old beam height cost it 12 m/s) is still a wall in flight, so the floor is tighter than the dead-stop rule.
			_t.check("(d) %s: nothing clips the ball (slowest %.1f m/s, floor %.0f)" % [id, r["min"], CLIP_FLOOR], r["min"] >= CLIP_FLOOR)
		if r.get("jump_z", -1.0) > 0.0:
			_t.check("(d) %s: the jump happened (peak %.2f m, ball top %.2f m over the shelf) and cleared the beams" % [id, r["peak"], r["peak"] + Tuning.RADIUS - SHELF_Y],
				r["jumped"] and r["peak"] > SHELF_Y + Tuning.RADIUS + 2.5)
		_t.check("(d) the ball crosses %s to its far lip" % id, b.position.z > r["length"] - 2.0, "z %.1f" % b.position.z)
		_t.check("(d) the ball rides %s's shelf (%d ticks at shelf height) and never falls off" % [id, r["on_shelf"]], not r["off"] and r["on_shelf"] >= 20
			and absf(b.position.x - (r["x"] + r["lane"])) < (1000.0 if id.contains("bank") else 6.0), "x %.1f y %.1f" % [b.position.x - r["x"], b.position.y])
		_t.check("(d) %s: no stretch under %.0f m/s lasts %.1f s (worst %.2f s, slowest %.1f m/s)" % [id, DEAD_SPEED, DEAD_SECONDS, r["worst"], r["min"]],
			r["worst"] <= DEAD_SECONDS and r["min"] != INF)
	parent.free()
