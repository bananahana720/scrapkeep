extends SceneTree
# 2026-10-10 (w13 KC3): the bowls and terraces family builds bench_coping, tailings_lip and pit_haul_ramp (design-v3/PARK.md
# section 4, row "Bowls and terraces").
# (a) Files: each recipe has its base GLB (render mesh plus a "<id>-col" mesh) and two detail shells, named the way
# park_recipes.gd loads them, and each id has a registry row in the right class.
# (b) Budgets: after import, the base is within the landform class (or its registry exception) and each shell within the
# detail class, counted the way asset_registry_test counts (every surface of every mesh, the -col mesh included).
# (c) Placement: park_recipes.place gives one Collider body holding the -col trimesh, draws no -col mesh, and ranges the
# base and the shells from the landform class.
# (d) Convention: +Y up, ride direction +Z, origin at the entry lip on the ground and centred across x, the surface falls
# toward +Z by at least the recipe's depth, and the coping lip is a 1.5 m radius fillet measured on the collider by ray casts.
# (e) The roll: a ball rolling at the entry along each recipe publishes the row's ride fact, reaches the far end, and its
# speed never stays under 2 m/s for more than 0.5 s on the line (PARK.md section 8). A wall in front of a ball is the
# control: the same detector must report a dead stop there, or the detector decided nothing.
# Evidence limit: headless physics with a rigid sphere on the recipe trimeshes; no look, feel or Terrain3D stamp claim.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

const REGISTRY := "res://assets/registry.json"
const BUDGETS := "res://assets/asset_budgets.json"
const LANE := 300.0
const START_Z := -40.0
const ENTRY_SPEED := 14.0
const DEAD_SPEED := 2.0
const DEAD_SECONDS := 0.5
const MAX_SECONDS := 14.0
const COPING_R := 1.5

# id: element and fact of the stage row that uses it (design-v3/park/stages/3-park_pit.md), the row size [length, height,
# width], the least drop of the centre line from the lip to the far end, and whether it carries a coping lip fillet.
const RECIPES := {
	"bench_coping": {"element": "bowl", "fact": "ride_bowl", "size": [34.0, 8.0, 24.0], "drop": 7.5, "lip": true},
	"tailings_lip": {"element": "terrace", "fact": "ride_bowl", "size": [40.0, 9.0, 28.0], "drop": 8.0, "lip": true},
	"pit_haul_ramp": {"element": "flow_line", "fact": "ride_chute", "size": [56.0, 5.0, 30.0], "drop": 4.0, "lip": false},
}

var _t := T.new("park_recipes_bowls_test")
var _facts: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	var budgets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS))["classes"]
	var entries := {}
	for row: Dictionary in registry["assets"]:
		entries[String(row.get("id", ""))] = row
	_check_files(entries)
	_check_budgets(entries, budgets)
	_check_place()
	await _check_convention()
	await _check_roll()
	quit(_t.verdict())


# The test names where a GLB's entry-lip origin goes; a row's at is its footprint's centre (PARK.md:77), so the row's at is
# that point moved by the loader's own conversion (park_recipes.gd ride_frame), turned by the row's yaw.
func _centre(row: Dictionary) -> Dictionary:
	var o: Vector3 = ParkRecipes.ride_frame(row)["origin"]
	var yaw := deg_to_rad(float(row["yaw_deg"]))
	row["at"] = [float(row["at"][0]) - sin(yaw) * o.z, float(row["at"][1]) - cos(yaw) * o.z]
	return row


func _row(id: String, recipe: String, at: Vector2, element := "", fact := "") -> Dictionary:
	var spec: Dictionary = RECIPES[recipe]
	return _centre({"id": id, "element": element if element != "" else spec["element"], "at": [at.x, at.y], "y": null, "size": spec["size"],
		"yaw_deg": 0.0, "ride_fact": fact if fact != "" else spec["fact"], "recipe": recipe, "budget": "landform"})


func _glb(recipe: String, part := "") -> String:
	return ParkRecipes.GLB_DIR + recipe + part + ".glb"


func _load_scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _check_files(entries: Dictionary) -> void:
	for recipe: String in RECIPES:
		var paths := ParkRecipes.paths(recipe, "landform")
		_t.check("(a) %s: base GLB exists" % recipe, ResourceLoader.exists(paths["base"]), paths["base"])
		for k in 2:
			_t.check("(a) %s: detail shell %d exists" % [recipe, k + 1], ResourceLoader.exists(paths["shells"][k]), paths["shells"][k])
		var base := _load_scene(paths["base"])
		if base == null:
			_t.check("(a) %s: base loads as a scene" % recipe, false)
			continue
		var cols := base.find_children(recipe + ParkRecipes.COL_SUFFIX, "MeshInstance3D", true, false)
		var drawn := base.find_children("*", "MeshInstance3D", true, false).filter(
			func(m): return not String(m.name).ends_with(ParkRecipes.COL_SUFFIX))
		_t.check("(a) %s: one %s-col mesh and at least one drawn mesh" % [recipe, recipe], cols.size() == 1 and drawn.size() >= 1,
			"%d col, %d drawn" % [cols.size(), drawn.size()])
		var lights := base.find_children("*", "Light3D", true, false)
		_t.check("(a) %s: no light node in the GLB" % recipe, lights.is_empty())
		base.free()
		for part in ["", "_detail1", "_detail2"]:
			var id: String = recipe + part
			var want_class := "landform" if part == "" else "detail"
			var row: Dictionary = entries.get(id, {})
			_t.check("(a) registry row %s is %s, shipped, provenance recipe bowls.py" % [id, want_class], row.get("class", "") == want_class
				and row.get("ships", false) == true and String(row.get("provenance", {}).get("recipe", "")).ends_with("park/bowls.py")
				and row.get("path", "") == _glb(recipe, part), str(row))


# Triangles, vertices and draws as asset_registry_test counts them: every surface of every mesh, the undrawn -col
# collision mesh counting toward triangles and vertices but not draws (KC-INT).
func _measure(scene: Node) -> Dictionary:
	var tris := 0
	var verts := 0
	var draws := 0
	for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		var collision := String(m.name).ends_with(ParkRecipes.COL_SUFFIX)
		for s in m.mesh.get_surface_count():
			draws += 0 if collision else 1
			var arrays := m.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else pos.size()) / 3
			verts += pos.size()
	return {"tris": tris, "verts": verts, "draws": draws}


func _check_budgets(entries: Dictionary, budgets: Dictionary) -> void:
	for recipe: String in RECIPES:
		for part in ["", "_detail1", "_detail2"]:
			var id: String = recipe + part
			var scene := _load_scene(_glb(recipe, part))
			if scene == null:
				_t.check("(b) %s measures" % id, false, "GLB missing")
				continue
			var m := _measure(scene)
			scene.free()
			var cap: Dictionary = budgets["landform" if part == "" else "detail"].duplicate()
			var ex: Dictionary = entries.get(id, {}).get("exception", {})
			for k in ex:
				if cap.has(k):
					cap[k] = ex[k]
			_t.check("(b) %s: %d tris, %d verts, %d draws within %d / %d / %d" % [id, m["tris"], m["verts"], m["draws"], cap["tris"], cap["verts"], cap["draws"]],
				m["tris"] <= cap["tris"] and m["verts"] <= cap["verts"] and m["draws"] <= cap["draws"] and m["tris"] > 0)
			if part == "":
				_t.check("(b) %s: the draws over the class carry an exception_why citing PARK.md section 9" % id,
					m["draws"] <= int(budgets["landform"]["draws"]) or String(entries.get(id, {}).get("exception_why", "")).contains("PARK.md section 9"))
			else:
				_t.check("(b) %s: a shell draws one mesh and has no -col mesh" % id, m["draws"] == 1)


func _check_place() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var r := ParkRecipes.ranges("landform")
	for recipe: String in RECIPES:
		var node := ParkRecipes.place(_row("p_" + recipe, recipe, Vector2(0, 0)), parent)
		if not _t.check("(c) %s places" % recipe, node != null and ResourceLoader.exists(_glb(recipe))):
			continue
		var bodies := node.find_children("*", "StaticBody3D", true, false)
		var shapes := node.find_children("*", "CollisionShape3D", true, false).filter(func(s): return s.get_parent() is StaticBody3D)
		_t.check("(c) %s: one Collider body holding the -col trimesh" % recipe, bodies.size() == 1
			and shapes.size() == 1 and shapes[0].shape is ConcavePolygonShape3D, "%d bodies, %d shapes" % [bodies.size(), shapes.size()])
		var views := node.find_children("*", "MeshInstance3D", true, false)
		_t.check("(c) %s: no -col mesh is drawn" % recipe, views.all(func(v): return not String(v.name).ends_with(ParkRecipes.COL_SUFFIX)) and views.size() >= 3,
			"%d views" % views.size())
		var ranged := views.filter(func(v): return is_equal_approx(v.visibility_range_end, float(r["base_end"])))
		var shell1 := views.filter(func(v): return is_equal_approx(v.visibility_range_end, float(r["shells"][0][0])))
		var shell2 := views.filter(func(v): return is_equal_approx(v.visibility_range_end, float(r["shells"][1][0])))
		_t.check("(c) %s: base views take base_end, shell 1 and 2 their ends" % recipe, ranged.size() >= 1 and shell1.size() == 1 and shell2.size() == 1,
			"%d base, %d shell 1, %d shell 2" % [ranged.size(), shell1.size(), shell2.size()])
	parent.free()


# The -col faces in the GLB's own frame (origin on the entry lip), not the node's centred one.
func _faces(node: Node3D) -> PackedVector3Array:
	var recipe := String(node.get_meta("park_recipe"))
	var lip: Vector3 = ParkRecipes.ride_frame(_row("f", recipe, Vector2.ZERO))["origin"]
	var out := PackedVector3Array()
	for s: CollisionShape3D in node.find_children("*", "CollisionShape3D", true, false):
		if s.get_parent() is StaticBody3D and s.shape is ConcavePolygonShape3D:
			for p in (s.shape as ConcavePolygonShape3D).get_faces():
				out.append(s.transform * p - lip)
	return out


func _bounds(faces: PackedVector3Array) -> AABB:
	var box := AABB(faces[0], Vector3.ZERO)
	for p in faces:
		box = box.expand(p)
	return box


func _ray_y(space: PhysicsDirectSpaceState3D, x: float, z: float, top := 30.0) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -top, z), 1)
	var hit := space.intersect_ray(q)
	return hit["position"].y if not hit.is_empty() else NAN


# Circumradius of three points in the (z, y) plane; INF when they are in line.
func _radius(a: Vector2, b: Vector2, c: Vector2) -> float:
	var area2 := absf((b - a).cross(c - a))
	if area2 < 0.000001:
		return INF
	return (b - a).length() * (c - b).length() * (c - a).length() / (2.0 * area2)


func _check_convention() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var nodes := {}
	var lane_x := {}
	var n := 0
	for recipe: String in RECIPES:
		lane_x[recipe] = (n + 1) * LANE
		nodes[recipe] = ParkRecipes.place(_row("c_" + recipe, recipe, Vector2(lane_x[recipe], 0)), parent)
		n += 1
	await physics_frame
	await physics_frame
	var space := root.get_world_3d().direct_space_state
	for recipe: String in RECIPES:
		var node: Node3D = nodes[recipe]
		if node == null:
			_t.check("(d) %s places" % recipe, false)
			continue
		var x0: float = lane_x[recipe]
		var faces := _faces(node)
		if not _t.check("(d) %s: the -col trimesh has faces" % recipe, faces.size() >= 3):
			continue
		var box := _bounds(faces)
		var spec: Dictionary = RECIPES[recipe]
		var size: Array = spec["size"]
		_t.check("(d) %s: centred across x, width %.0f within 1 m" % [recipe, size[2]], absf(box.get_center().x) < 0.5 and absf(box.size.x - float(size[2])) < 1.0,
			"x %.2f..%.2f" % [box.position.x, box.end.x])
		_t.check("(d) %s: starts before the lip and ends past it along +Z" % recipe, box.position.z <= -3.0 and box.end.z >= float(size[0]) - 8.0,
			"z %.2f..%.2f" % [box.position.z, box.end.z])
		# The far end of the centre line: a bowed or ragged crest leaves the box end past it at the edges.
		var line_end := box.end.z
		while is_nan(_ray_y(space, x0, line_end)) and line_end > 0.0:
			line_end -= 0.25
		var lip_y := _ray_y(space, x0, -2.0)
		_t.check("(d) %s: the approach is level with the ground at the entry lip (y 0)" % recipe, absf(lip_y) < 0.02, "y %.3f" % lip_y)
		var end_y := _ray_y(space, x0, line_end - 1.0)
		_t.check("(d) %s: the line falls at least %.1f m toward +Z" % [recipe, spec["drop"]], lip_y - end_y >= float(spec["drop"]), "end y %.2f" % end_y)
		var steepest := 0.0
		var worst_step := 0.0
		var prev := lip_y
		var z := -3.5
		var ys := {}
		while z <= line_end - 1.0:
			var y := _ray_y(space, x0, z)
			ys[snappedf(z, 0.01)] = y
			if is_nan(y):
				_t.check("(d) %s: the centre line is continuous at z %.2f" % [recipe, z], false)
				break
			steepest = maxf(steepest, absf(y - prev) / 0.25)
			worst_step = maxf(worst_step, absf(y - prev))
			prev = y
			z += 0.25
		_t.check("(d) %s: no wall on the centre line, slope at most 45 degrees (steepest %.2f)" % [recipe, steepest], steepest <= 1.0 + 0.001 and worst_step <= 0.25 + 0.001)
		if spec["lip"]:
			# Coping lip: the convex stretch next to the entry is a fillet of about 1.5 m radius.
			var best := INF
			var zc := -1.0
			while zc <= 4.0:
				var p0 := Vector2(zc - 0.5, _ray_y(space, x0, zc - 0.5))
				var p1 := Vector2(zc, _ray_y(space, x0, zc))
				var p2 := Vector2(zc + 0.5, _ray_y(space, x0, zc + 0.5))
				var convex := (p1 - p0).cross(p2 - p1) < -0.0001
				if convex:
					best = minf(best, _radius(p0, p1, p2))
				zc += 0.25
			_t.check("(d) %s: the coping lip is a convex fillet of %.1f m radius (tightest %.2f, within 20 percent)" % [recipe, COPING_R, best],
				best >= COPING_R * 0.8 and best <= COPING_R * 1.2)
		else:
			var grade := (lip_y - end_y) / (line_end - 1.0)
			_t.check("(d) %s: haul grade between 5 and 12 percent (%.3f)" % [recipe, grade], grade >= 0.05 and grade <= 0.12)
	parent.free()


func _ground(parent: Node3D, x: float, ahead := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.set_collision_layer_value(1, true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 2.0, 120.0 + ahead)
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.position = Vector3(x, -1.0, -4.0 - 60.0 + ahead * 0.5)


func _ball(parent: Node3D, at: Vector3, speed: float) -> RigidBody3D:
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
	ball.linear_velocity = Vector3(0, 0, speed)
	ball.angular_velocity = Vector3(speed / Tuning.RADIUS, 0, 0)
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp = 0.0
	parent.add_child(ball)
	return ball


func _check_roll() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var publish := func(kind: String, at: Vector3) -> void: _facts.append([kind, at])
	var lanes: Array = []
	var i := 0
	# The three stage rows, then the ramp again as a bank row of the bowls family (ride_bowl, the family fact).
	var cases: Array = []
	for recipe: String in RECIPES:
		cases.append([recipe, RECIPES[recipe]["element"], RECIPES[recipe]["fact"]])
	cases.append(["pit_haul_ramp", "bank", "ride_bowl"])
	for case in cases:
		var recipe: String = case[0]
		var x := (i + 1) * LANE
		_ground(parent, x)
		var node := ParkRecipes.place(_row("r_%s_%d" % [recipe, i], recipe, Vector2(x, 0), case[1], case[2]), parent, Callable(), publish)
		var end_z := 40.0
		var glb := false
		if node != null:
			var faces := _faces(node)
			if faces.size() >= 3:
				end_z = _bounds(faces).end.z
				glb = true
		lanes.append({"name": "%s as %s" % [recipe, case[1]], "glb": glb, "x": x, "fact": case[2], "node": node, "end_z": end_z, "control": false,
			"ball": _ball(parent, Vector3(x, Tuning.RADIUS + 0.05, START_Z), ENTRY_SPEED)})
		i += 1
	# The control: a 6 m wall of greybox ledge across the line, 30 m ahead of the ball.
	var cx := (i + 1) * LANE
	_ground(parent, cx, 60.0)
	var wall := {"id": "wall", "element": "ledge", "at": [cx, 6.0], "y": null, "size": [4.0, 6.0, 30.0], "yaw_deg": 0.0,
		"ride_fact": "", "recipe": "greybox:ledge", "budget": "landform"}
	ParkRecipes.place(wall, parent)
	lanes.append({"name": "control wall", "x": cx, "fact": "", "node": null, "end_z": 6.0, "control": true,
		"ball": _ball(parent, Vector3(cx, Tuning.RADIUS + 0.05, START_Z), ENTRY_SPEED)})
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	for lane in lanes:
		lane["slow"] = 0.0
		lane["worst"] = 0.0
		lane["min_speed"] = INF
		lane["done"] = false
		lane["low_y"] = INF
	var frames := int(MAX_SECONDS / dt)
	for f in frames:
		await physics_frame
		var all_done := true
		for lane in lanes:
			if lane["done"]:
				continue
			var ball: RigidBody3D = lane["ball"]
			var z := ball.position.z
			lane["low_y"] = minf(lane["low_y"], ball.position.y)
			if z > float(lane["end_z"]) - 2.0 and not lane["control"]:
				lane["done"] = true
				continue
			if z > START_Z + 3.0:
				var speed := ball.linear_velocity.length()
				lane["min_speed"] = minf(lane["min_speed"], speed)
				if speed < DEAD_SPEED:
					lane["slow"] += dt
					lane["worst"] = maxf(lane["worst"], lane["slow"])
				else:
					lane["slow"] = 0.0
			all_done = false
		if all_done:
			break
	for lane in lanes:
		var ball: RigidBody3D = lane["ball"]
		var name: String = lane["name"]
		if lane["control"]:
			_t.check("(e) control: a wall ahead is detected as a dead stop (%.2f s under %.0f m/s)" % [lane["worst"], DEAD_SPEED],
				lane["worst"] > DEAD_SECONDS)
			continue
		_t.check("(e) %s: the lane rolls the GLB's trimesh, not the greybox stand-in" % name, bool(lane["glb"]))
		_t.check("(e) %s: the ball reaches the far end (z %.1f of %.1f)" % [name, ball.position.z, lane["end_z"]], bool(lane["done"]))
		_t.check("(e) %s: no dead stop, at most %.2f s under %.0f m/s (slowest %.1f m/s)" % [name, lane["worst"], DEAD_SPEED, lane["min_speed"]],
			float(lane["worst"]) <= DEAD_SECONDS and bool(lane["done"]))
		_t.check("(e) %s: the ball stays on the recipe (lowest y %.1f)" % [name, lane["low_y"]], float(lane["low_y"]) > -20.0)
		var near := _facts.filter(func(e): return absf(e[1].x - float(lane["x"])) < LANE * 0.5)
		var kinds := near.map(func(e): return e[0])
		_t.check("(e) %s: the roll publishes %s" % [name, lane["fact"]], kinds.has(lane["fact"]) and EventKinds.WORLD_ROWS.has(lane["fact"]), str(kinds))
	parent.free()
