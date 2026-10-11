extends SceneTree
# 2026-10-10 (w13 KC1): the half-pipe family builds the park's channels (design-v3/PARK.md section 4, row 1).
# Recipes: half_pipe_concrete, slot_canyon_flow (straight, bend15, bend30) and wash_dropin_lip, each a base GLB with a
# "<id>-col" trimesh and two detail shells (<id>_detail1.glb, <id>_detail2.glb), placed through park_recipes.gd.
#
# Convention under test (tools/blender/park/halfpipes.py header): +Y up, the ride direction +Z (the fall line), origin
# at the entry lip, the channel floor at y 0 there (the drop-in's deck at y 0), a "socket_exit" node where the next
# piece's origin goes (its yaw is the bend), "gauge_l" and "gauge_r" on the wall crests at the exit end.
# (a) Every GLB exists, imports as a scene, sits inside its budget class (base landform with the -col counted, shells detail).
# (b) park_recipes.place() makes a real recipe node: one world collider holding the -col trimesh, the -col mesh never
# drawn, the base view and two shells on the landform ranges, and no greybox stand-in.
# (c) The channel is a half-pipe of the table's size: crest to crest 12 to 40 m, walls 6 to 14 m; the exit socket is the
# bend (0, 15 or 30 degrees) and the floor falls from the entry to the exit.
# (d) A headless roll: a ball dropped on the floor at the entry, and another off the centre line (the wall's transition),
# each publishes ride_chute, reaches the exit end, stays in the channel and never sits under 2 m/s for over 0.5 s.
# Evidence limit: headless Jolt physics, a 1 m ball and the -col mesh only; no feel or look claim. The look is judged in
# the blind pairs under artifacts/local/alpha/push/w13/park-recipes/halfpipes/.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# id -> {bend: yaw of the exit socket in degrees (right turn is +), drop: the deck-to-floor drop-in height, 0 for a channel}.
const RECIPES := {
	"half_pipe_concrete": {"bend": 0.0, "drop": 0.0},
	"slot_canyon_flow": {"bend": 0.0, "drop": 0.0},
	"slot_canyon_flow_bend15": {"bend": 15.0, "drop": 0.0},
	"slot_canyon_flow_bend30": {"bend": 30.0, "drop": 0.0},
	"wash_dropin_lip": {"bend": 0.0, "drop": 8.0},
}
const MODELS := "res://assets/models/park/"
const WIDTH_RANGE := Vector2(12.0, 40.0)
const WALL_RANGE := Vector2(6.0, 14.0)
const MIN_SPEED := 2.0
const DEAD_STOP_S := 0.5
const TICKS := 90
const ROLL_FRAMES := 1500
const START_SPEED := 8.0
const SPACING := 300.0
const YAW_DEG := 30.0
const BEND_TOL_DEG := 0.5
const LANDFORM := {"tris": 8000, "draws": 2}
const DETAIL := {"tris": 1500, "draws": 1}

var _t := T.new("park_recipes_halfpipes_test")
var _facts: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_files()
	_check_place()
	_check_geometry()
	await _check_roll()
	quit(_t.verdict())


func _glb(id: String, suffix := "") -> String:
	return MODELS + id + suffix + ".glb"


func _have(id: String) -> bool:
	return ResourceLoader.exists(_glb(id)) and ResourceLoader.exists(_glb(id, "_detail1")) and ResourceLoader.exists(_glb(id, "_detail2"))


func _measure(path: String) -> Dictionary:
	var packed := load(path) as PackedScene
	if packed == null:
		return {}
	var node := packed.instantiate()
	var out := {"tris": 0, "draws": 0}
	for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			out["draws"] += 1
			var arrays := m.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			out["tris"] += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	node.free()
	return out


func _check_files() -> void:
	for id in RECIPES:
		for suffix in ["", "_detail1", "_detail2"]:
			var path := _glb(id, suffix)
			var exists := ResourceLoader.exists(path)
			_t.check("(a) %s exists" % path.trim_prefix(MODELS), exists)
			if not exists:
				continue
			var cap: Dictionary = LANDFORM if suffix == "" else DETAIL
			var m := _measure(path)
			_t.check("(a) %s imports and fits its class" % path.trim_prefix(MODELS), not m.is_empty()
				and m["tris"] > 0 and m["tris"] <= cap["tris"] and m["draws"] <= cap["draws"], str(m))


func _row(id: String, at: Vector2, size: Vector3) -> Dictionary:
	return {"id": "t_" + id, "element": "flow_line", "at": [at.x, at.y], "y": 0.0, "size": [size.x, size.y, size.z],
		"yaw_deg": YAW_DEG, "ride_fact": "ride_chute", "recipe": id, "budget": "landform"}


func _check_place() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var ranges := ParkRecipes.ranges("landform")
	var i := 0
	for id in RECIPES:
		i += 1
		if not _have(id):
			_t.check("(b) %s places as a recipe" % id, false, "GLBs missing")
			continue
		var node := ParkRecipes.place(_row(id, Vector2(-i * 200.0, 500.0), Vector3(48, 10, 24)), parent)
		var greybox := node.find_child("Greybox", true, false)
		_t.check("(b) %s is not the greybox stand-in" % id, node != null and greybox == null)
		var views := node.find_children("*", "MeshInstance3D", true, false)
		var drawn_col := views.filter(func(v): return String(v.name).ends_with(ParkRecipes.COL_SUFFIX))
		_t.check("(b) %s draws the base and two shells, never the -col" % id, views.size() == 3 and drawn_col.is_empty(),
			"%d views, %d -col" % [views.size(), drawn_col.size()])
		var enamel := 0
		for v: MeshInstance3D in views:
			var worn := v.get_surface_override_material(0) as BaseMaterial3D
			if worn != null and worn.vertex_color_use_as_albedo:
				enamel += 1
		_t.check("(b) %s views wear the enamel slot, so their vertex colour shows" % id, enamel == views.size(), "%d of %d" % [enamel, views.size()])
		var bodies := node.find_children("*", "StaticBody3D", true, false)
		var shapes := node.find_children("*", "CollisionShape3D", true, false).filter(func(s): return s.get_parent() is StaticBody3D)
		var faces := 0
		for s: CollisionShape3D in shapes:
			if s.shape is ConcavePolygonShape3D:
				faces += (s.shape as ConcavePolygonShape3D).get_faces().size() / 3
		_t.check("(b) %s has one world body holding the -col trimesh" % id, bodies.size() == 1 and shapes.size() == 1
			and faces >= 100, "%d bodies, %d shapes, %d faces" % [bodies.size(), shapes.size(), faces])
		if views.size() == 3:
			var base: GeometryInstance3D = views[0]
			var d1: GeometryInstance3D = views[1]
			var d2: GeometryInstance3D = views[2]
			_t.check("(b) %s views take the landform ranges" % id, is_equal_approx(base.visibility_range_end, float(ranges["base_end"]))
				and is_equal_approx(d1.visibility_range_end, float(ranges["shells"][0][0]))
				and is_equal_approx(d2.visibility_range_end, float(ranges["shells"][1][0])),
				"%s %s %s" % [base.visibility_range_end, d1.visibility_range_end, d2.visibility_range_end])
	parent.free()


func _socket(scene: Node, name: String) -> Node3D:
	return scene.find_child(name, true, false) as Node3D


func _local(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf


func _check_geometry() -> void:
	for id in RECIPES:
		if not _have(id):
			_t.check("(c) %s geometry" % id, false, "GLBs missing")
			continue
		var scene := (load(_glb(id)) as PackedScene).instantiate()
		var exit_node := _socket(scene, "socket_exit")
		var gl := _socket(scene, "gauge_l")
		var gr := _socket(scene, "gauge_r")
		var sockets_ok := exit_node != null and gl != null and gr != null
		_t.check("(c) %s names socket_exit, gauge_l and gauge_r" % id, sockets_ok)
		if not sockets_ok:
			scene.free()
			continue
		var exit_xf := _local(exit_node, scene)
		var l := _local(gl, scene).origin
		var r := _local(gr, scene).origin
		var width := Vector2(l.x - r.x, l.z - r.z).length()
		var wall: float = l.y - exit_xf.origin.y
		_t.check("(c) %s is %.1f m crest to crest, in 12 to 40 m" % [id, width], width >= WIDTH_RANGE.x and width <= WIDTH_RANGE.y)
		_t.check("(c) %s wall is %.1f m, in 6 to 14 m" % [id, wall], wall >= WALL_RANGE.x and wall <= WALL_RANGE.y)
		var yaw := rad_to_deg(atan2(exit_xf.basis.z.x, exit_xf.basis.z.z))
		_t.near("(c) %s exit yaw is its bend" % id, yaw, float(RECIPES[id]["bend"]), BEND_TOL_DEG)
		_t.check("(c) %s runs 30 m or more along its heading" % id, exit_xf.origin.length() >= 30.0, str(exit_xf.origin))
		_t.check("(c) %s floor falls toward the exit" % id, exit_xf.origin.y < -0.5, "exit y %.2f" % exit_xf.origin.y)
		scene.free()


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
	parent.add_child(ball)
	ball.global_position = at
	ball.linear_velocity = velocity
	return ball


# One run per ball: {id, frame (the GLB's), ball, exit (local), slow_frames, worst_slow, min_x, max_x, lowest}.
func _check_roll() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var publish := func(kind: String, at: Vector3) -> void: _facts.append([kind, at])
	var runs: Array = []
	var i := 0
	for id in RECIPES:
		i += 1
		if not _have(id):
			_t.check("(d) %s rolls" % id, false, "GLBs missing")
			continue
		var scene := (load(_glb(id)) as PackedScene).instantiate()
		var exit_local := _local(_socket(scene, "socket_exit"), scene)
		var gl := _local(_socket(scene, "gauge_l"), scene).origin
		scene.free()
		var at := Vector2(i * SPACING, 0.0)
		var row := _row(id, at, Vector3(48, 10, 24))
		var node := ParkRecipes.place(row, parent, Callable(), publish)
		# The GLB's own frame: its entry-lip origin sits half a length behind the row's centred at (ride_frame).
		var frame := node.global_transform * Transform3D(Basis.IDENTITY, ParkRecipes.ride_frame(row)["origin"])
		var drop := float(RECIPES[id]["drop"])
		# A channel's ball starts 1.4 m over the entry floor, a drop-in's 6 m back on the deck, 1.4 m over it.
		var start_z := 2.0 if drop == 0.0 else -6.0
		for lane in [0.0, 4.5]:
			# The off-centre ball starts higher in a channel, so it falls onto the wall's transition instead of into it.
			var local_start := Vector3(lane, 1.4 if (lane == 0.0 or drop > 0.0) else 4.0, start_z)
			var ball := _ball(parent, frame * local_start, frame.basis * Vector3(0, 0, START_SPEED))
			runs.append({"id": id, "lane": lane, "frame": frame, "ball": ball, "exit": exit_local, "half": absf(gl.x) + 1.0,
				"slow": 0, "worst": 0, "published": false})
	for f in ROLL_FRAMES:
		await physics_frame
		for run in runs:
			if run.has("reached"):
				continue
			var ball: RigidBody3D = run["ball"]
			run["min"] = minf(run.get("min", 1e9), ball.linear_velocity.length())
			if ball.linear_velocity.length() < MIN_SPEED:
				run["slow"] += 1
				run["worst"] = maxi(run["worst"], run["slow"])
			else:
				run["slow"] = 0
			var local: Vector3 = (run["frame"] as Transform3D).affine_inverse() * ball.global_position
			if not run.has("reached") and local.z >= (run["exit"] as Transform3D).origin.z * 0.9 \
					and local.distance_to((run["exit"] as Transform3D).origin) < 14.0:
				run["reached"] = f
			run["lowest"] = minf(run.get("lowest", 1e9), local.y - (run["exit"] as Transform3D).origin.y)
			run["widest"] = maxf(run.get("widest", 0.0), absf(local.x))
			run["farthest"] = maxf(run.get("farthest", -1e9), local.z)
	for run in runs:
		var label := "%s lane %.1f" % [run["id"], run["lane"]]
		_t.check("(d) %s reaches its exit end" % label, run.has("reached"), "farthest z %.1f" % run.get("farthest", -1e9))
		var dead_ticks := int(DEAD_STOP_S * TICKS)
		_t.check("(d) %s never sits under %.0f m/s for %.1f s" % [label, MIN_SPEED, DEAD_STOP_S], run["worst"] <= dead_ticks,
			"%d ticks slow, limit %d, lowest speed %.1f m/s" % [run["worst"], dead_ticks, run.get("min", 0.0)])
		_t.check("(d) %s stays over the exit floor line" % label, run.get("lowest", -1e9) > -6.0, "lowest %.1f above the exit floor" % run.get("lowest", -1e9))
	for id in RECIPES:
		if not _have(id):
			continue
		var kinds := _facts.filter(func(e): return absf(e[1].x - (RECIPES.keys().find(id) + 1) * SPACING) < SPACING * 0.5).map(func(e): return e[0])
		_t.check("(d) a roll over %s publishes ride_chute" % id, kinds.has("ride_chute") and EventKinds.WORLD_ROWS.has("ride_chute"), str(kinds))
	parent.free()
