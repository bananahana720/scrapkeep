extends SceneTree
# 2026-10-10 (w13 KC0): a park row's recipe places a GLB or a greybox stand-in (design-v3/PARK.md sections 2.2, 4, 9).
# (a) The registry: park_recipes.ROWS holds every starting recipe id park_schema accepts, each in a park budget class, and
# assets/asset_budgets.json carries park_large and hero_landmark at the section 9 numbers plus every park class's ranges.
# (b) The four new ride facts are WORLD_ROWS rows in the ROWS schema.
# (c) A greybox:<element> id places a primitive of the row's size at its transform with a collider of the same extent;
# a greybox id naming no element places nothing; a recipe whose GLB is missing falls back to its element's greybox.
# (d) A GLB recipe: the -col mesh becomes the trimesh and is never drawn, in both shapes Godot 4.7.2 gives (the importer's
# StaticBody3D child with a ConcavePolygonShape3D, and the raw mesh); base, shell, mid and far views take their visibility
# ranges from the budget class.
# (e) A headless roll: a ball dropped onto each greybox element publishes the row's ride fact through the publish callable;
# together the elements publish ride_bowl, ride_drop, ride_ledge and ride_hop. A row with no ride fact, a fact that is no
# WORLD_ROWS row (kicker_launch) and a ball beside the footprint publish nothing.
# Evidence limit: headless physics on primitives; no GLB recipe exists yet (KC1 to KC10), so (d) uses in-memory scenes
# shaped as the 4.7.2 importer leaves a -col node. No feel or look claim.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

const NEW_FACTS := ["ride_bowl", "ride_drop", "ride_ledge", "ride_hop"]
const PARK_CLASSES := ["landform", "park_large", "hero_landmark", "detail"]
const EPS := 0.01
const ROLL_FRAMES := 240
const SPACING := 400.0
const MISSING_PROBE := "kc0_missing_probe"

var _t := T.new("park_recipes_test")
var _facts: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_registry()
	_check_rows()
	_check_greybox()
	_check_fallback()
	_check_glb()
	await _check_roll()
	quit(_t.verdict())


func _check_registry() -> void:
	var ids: Array = ParkRecipes.ROWS.keys()
	ids.sort()
	var schema_ids: Array = ParkSchema.RECIPES.duplicate()
	schema_ids.sort()
	_t.eq("(a) registry ids are park_schema's starting ids", ids, schema_ids)
	var bad: Array = []
	for id in ParkRecipes.ROWS:
		if not String(ParkRecipes.ROWS[id].get("budget", "")) in ParkSchema.BUDGETS:
			bad.append(id)
		if String(id).begins_with("landmark_") and ParkRecipes.ROWS[id]["budget"] != "hero_landmark":
			bad.append(id)
	_t.check("(a) every row names a park budget class, landmarks hero_landmark", bad.is_empty(), str(bad))
	var budgets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_budgets.json"))
	var classes: Dictionary = budgets["classes"]
	# Draws 2 to 3 on 2026-10-18 (coordinator call, b624dc1a): a bevelled detail shell is a second draw by design.
	_t.check("(a) park_large is 16,000 triangles and 3 draws", classes.has("park_large")
		and int(classes["park_large"]["tris"]) == 16000 and int(classes["park_large"]["draws"]) == 3, str(classes.get("park_large")))
	_t.check("(a) hero_landmark is 24,000 / 6 draws / mid 6,000 / far 1,500", classes.has("hero_landmark")
		and int(classes["hero_landmark"]["tris"]) == 24000 and int(classes["hero_landmark"]["draws"]) == 6
		and int(classes["hero_landmark"].get("mid_tris", 0)) == 6000 and int(classes["hero_landmark"].get("far_tris", 0)) == 1500,
		str(classes.get("hero_landmark")))
	for name in PARK_CLASSES:
		var c: Dictionary = classes.get(name, {})
		var r: Dictionary = c.get("ranges", {})
		_t.check("(a) %s carries base and two shell ranges" % name, r.has("base_end") and r.has("base_margin")
			and r.get("shells", []).size() == 2, str(r))
		_t.eq("(a) park_recipes reads %s ranges from the json" % name, ParkRecipes.ranges(name), r)
	_t.check("(a) hero_landmark carries a mid range", classes.get("hero_landmark", {}).get("ranges", {}).has("mid_end"))


func _check_rows() -> void:
	for kind in NEW_FACTS:
		var row: Dictionary = EventKinds.WORLD_ROWS.get(kind, {})
		var ok := not row.is_empty()
		for field in EventKinds.FIELDS:
			ok = ok and row.has(field)
		ok = ok and row.get("group", "") == "event" and row.get("shape", "") in EventKinds.SHAPES
		ok = ok and row.get("color") is Color and String(row.get("sound", "")) != "" and String(row.get("sound_next", "")) != ""
		_t.check("(b) %s is a well-formed WORLD_ROWS row" % kind, ok, str(row))


func _row(id: String, element: String, at: Vector2, size: Vector3, yaw: float, fact: String, recipe := "") -> Dictionary:
	return {"id": id, "element": element, "at": [at.x, at.y], "y": null, "size": [size.x, size.y, size.z], "yaw_deg": yaw,
		"ride_fact": fact, "recipe": recipe if recipe != "" else "greybox:" + element, "budget": "landform"}


func _check_greybox() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var ground := func(_x: float, _z: float) -> float: return 5.0
	var i := 0
	for element: String in ParkSchema.ELEMENTS:
		var size := Vector3(30.0 + i, 4.0 + i * 0.5, 12.0 + i)
		var row := _row("g_" + element, element, Vector2(i * 100.0, -50.0), size, 30.0, "")
		var node := ParkRecipes.place(row, parent, ground)
		i += 1
		if not _t.check("(c) %s places" % element, node != null):
			continue
		var want := Vector3(size.z, size.y, size.x)
		var views := node.find_children("*", "MeshInstance3D", true, false)
		var mesh_box := AABB()
		for k in views.size():
			var v := views[k] as MeshInstance3D
			var box := v.transform * v.mesh.get_aabb()
			mesh_box = box if k == 0 else mesh_box.merge(box)
		_t.check("(c) %s primitive is the row's size" % element, views.size() == 1 and mesh_box.size.is_equal_approx(want),
			"%d views, size %s, want %s" % [views.size(), mesh_box.size, want])
		_t.check("(c) %s sits on the ground at its base" % element, absf(mesh_box.position.y) < EPS, str(mesh_box.position))
		var col_box := _collider_box(node)
		_t.check("(c) %s collider matches the primitive" % element, col_box.size.is_equal_approx(mesh_box.size)
			and col_box.position.is_equal_approx(mesh_box.position), "collider %s, mesh %s" % [col_box, mesh_box])
		var want_basis := Basis(Vector3.UP, deg_to_rad(30.0))
		_t.check("(c) %s at the row's transform" % element, node.position.is_equal_approx(Vector3((i - 1) * 100.0, 5.0, -50.0))
			and node.basis.is_equal_approx(want_basis), "%s %s" % [node.position, node.basis])
	var lifted := _row("hung", "rail", Vector2(0, 0), Vector3(40, 1, 2), 0.0, "")
	lifted["y"] = 22.0
	var hung := ParkRecipes.place(lifted, parent, ground)
	_t.check("(c) a row with y sits at y, not the ground", hung != null and is_equal_approx(hung.position.y, 22.0),
		str(hung.position if hung != null else null))
	var bad := _row("bad", "bowl", Vector2.ZERO, Vector3(10, 2, 10), 0.0, "", "greybox:not_an_element")
	_t.check("(c) a greybox id naming no element places nothing", ParkRecipes.place(bad, parent, ground) == null)
	parent.free()


func _check_fallback() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	# kc0_missing_probe is an id no family builds, so the fallback stays tested as recipes land (KC-INT R4).
	var row := _row("wash", "half_pipe", Vector2(0, 0), Vector3(60, 12, 30), 0.0, "ride_chute", MISSING_PROBE)
	_t.check("(c) no %s GLB exists" % MISSING_PROBE, not ResourceLoader.exists(ParkRecipes.paths(MISSING_PROBE, "landform")["base"]))
	var node := ParkRecipes.place(row, parent)
	_t.check("(c) a missing GLB falls back to the element's greybox", node != null and _collider_box(node).size.is_equal_approx(Vector3(30, 12, 60)),
		str(_collider_box(node) if node != null else null))
	parent.free()


# The scene a GLB recipe gives after the 4.7.2 import: the drawn mesh, and a -col mesh with the importer's StaticBody3D
# child holding a ConcavePolygonShape3D (probed 2026-10-10 on a scratch project). raw drops the importer's body.
func _fake_glb(name: String, raw: bool, col_size: Vector3) -> Node3D:
	var top := Node3D.new()
	var view := MeshInstance3D.new()
	view.name = name
	var box := BoxMesh.new()
	box.size = Vector3(4, 4, 4)
	view.mesh = box
	top.add_child(view)
	var col := MeshInstance3D.new()
	col.name = name + "-col"
	var col_mesh := BoxMesh.new()
	col_mesh.size = col_size
	col.mesh = col_mesh
	col.position = Vector3(0, 1, 0)
	top.add_child(col)
	if not raw:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = col_mesh.create_trimesh_shape()
		body.add_child(shape)
		col.add_child(body)
	return top


func _check_glb() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	for raw in [false, true]:
		var label := "raw" if raw else "imported"
		var row := _row("tube", "tunnel", Vector2(10, 20), Vector3(200, 30, 16), 90.0, "ride_chute", "lava_tube_run")
		row["budget"] = "park_large"
		var parts := {"base": [_fake_glb("tube", raw, Vector3(8, 6, 20))],
			"shells": [_fake_glb("tube_d1", raw, Vector3(1, 1, 1)), _fake_glb("tube_d2", raw, Vector3(1, 1, 1))]}
		var node := ParkRecipes.place_parts(row, parts, parent)
		_free_parts(parts)
		var views := node.find_children("*", "MeshInstance3D", true, false)
		var drawn_col := views.filter(func(v): return String(v.name).ends_with(ParkRecipes.COL_SUFFIX))
		_t.check("(d) %s: the -col mesh is never drawn" % label, drawn_col.is_empty() and views.size() == 3,
			"%d views, %d -col views" % [views.size(), drawn_col.size()])
		var shapes := node.find_children("*", "CollisionShape3D", true, false).filter(func(s): return s.get_parent() is StaticBody3D)
		var trimesh := shapes.size() == 3 and shapes.all(func(s): return s.shape is ConcavePolygonShape3D)
		_t.check("(d) %s: the -col meshes become trimesh shapes" % label, trimesh, "%d shapes" % shapes.size())
		var base_shape: CollisionShape3D = shapes[0] if not shapes.is_empty() else null
		var faces: int = (base_shape.shape as ConcavePolygonShape3D).get_faces().size() if base_shape != null and base_shape.shape is ConcavePolygonShape3D else -1
		# lava_tube_run's registry row says origin entry_lip: the GLB origin sits half the 200 m length behind at (ride_frame).
		_t.check("(d) %s: the trimesh is the -col mesh, at its place from the entry lip" % label, base_shape != null and faces == 36
			and base_shape.position.is_equal_approx(Vector3(0, 1, -100)), "faces %d at %s" % [faces, base_shape.position if base_shape != null else null])
		_t.check("(d) %s: no importer body copied in" % label, node.find_children("*", "StaticBody3D", true, false).size() == 1)
		var r := ParkRecipes.ranges("park_large")
		var base_view := views[0] as GeometryInstance3D
		_t.check("(d) %s: base range from park_large" % label, is_equal_approx(base_view.visibility_range_end, float(r["base_end"]))
			and is_equal_approx(base_view.visibility_range_end_margin, float(r["base_margin"])), "%s" % base_view.visibility_range_end)
		for k in 2:
			var shell := views[k + 1] as GeometryInstance3D
			_t.check("(d) %s: shell %d range from park_large" % [label, k + 1],
				is_equal_approx(shell.visibility_range_end, float(r["shells"][k][0]))
				and is_equal_approx(shell.visibility_range_end_margin, float(r["shells"][k][1]))
				and shell.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s" % shell.visibility_range_end)
	var hero := {"id": "dam", "kind": "dam", "at": [0, 600], "size": [300, 120, 60], "yaw_deg": 0, "recipe": "landmark_dam",
		"budget": "hero_landmark"}
	var hparts := {"base": [_fake_glb("dam", false, Vector3(10, 10, 10))], "shells": [], "mid": [_fake_glb("dam_mid", false, Vector3(1, 1, 1))],
		"far": [_fake_glb("dam_far", false, Vector3(1, 1, 1))]}
	var hnode := ParkRecipes.place_parts(hero, hparts, parent)
	_free_parts(hparts)
	var h := ParkRecipes.ranges("hero_landmark")
	var by_name := {}
	for v in hnode.find_children("*", "MeshInstance3D", true, false):
		by_name[String(v.name)] = v
	var near_v: GeometryInstance3D = by_name.get("dam")
	var mid_v: GeometryInstance3D = by_name.get("dam_mid")
	var far_v: GeometryInstance3D = by_name.get("dam_far")
	_t.check("(d) hero: near, mid and far views", near_v != null and mid_v != null and far_v != null, str(by_name.keys()))
	if near_v != null and mid_v != null and far_v != null:
		_t.check("(d) hero: near ends where mid begins", is_equal_approx(near_v.visibility_range_end, float(h["base_end"]))
			and is_equal_approx(mid_v.visibility_range_begin, float(h["base_end"])), "%s %s" % [near_v.visibility_range_end, mid_v.visibility_range_begin])
		_t.check("(d) hero: mid ends where far begins and far never ends", is_equal_approx(mid_v.visibility_range_end, float(h["mid_end"]))
			and is_equal_approx(far_v.visibility_range_begin, float(h["mid_end"])) and far_v.visibility_range_end == 0.0,
			"%s %s %s" % [mid_v.visibility_range_end, far_v.visibility_range_begin, far_v.visibility_range_end])
	_t.eq("(d) path convention", ParkRecipes.paths("landmark_dam", "hero_landmark"), {
		"base": "res://assets/models/park/landmark_dam.glb",
		"shells": ["res://assets/models/park/landmark_dam_detail1.glb", "res://assets/models/park/landmark_dam_detail2.glb"],
		"mid": "res://assets/models/park/landmark_dam_mid.glb", "far": "res://assets/models/park/landmark_dam_far.glb"})
	parent.free()


func _free_parts(parts: Dictionary) -> void:
	for key in parts:
		for scene: Node in parts[key]:
			scene.free()


func _collider_box(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for s: CollisionShape3D in node.find_children("*", "CollisionShape3D", true, false):
		if not s.get_parent() is StaticBody3D:
			continue
		# A convex shape's debug mesh sits inside its margin; its points are the extent the ball meets.
		var local := s.shape.get_debug_mesh().get_aabb()
		if s.shape is ConvexPolygonShape3D:
			var pts: PackedVector3Array = (s.shape as ConvexPolygonShape3D).points
			local = AABB(pts[0], Vector3.ZERO)
			for p in pts:
				local = local.expand(p)
		var box := s.transform * local
		out = box if first else out.merge(box)
		first = false
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
	parent.add_child(ball)
	return ball


func _check_roll() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var publish := func(kind: String, at: Vector3) -> void: _facts.append([kind, at])
	var rides: Array = []
	var i := 0
	for element: String in ParkSchema.ELEMENTS:
		var fact: String = ParkRecipes.ELEMENT_FACTS.get(element, "")
		var size := Vector3(40, 3, 20)
		var at := Vector2(i * SPACING, 0)
		var row := _row("r_" + element, element, at, size, 0.0, fact)
		var node := ParkRecipes.place(row, parent, Callable(), publish)
		var top := ParkRecipes.SENSOR_ABOVE_M + size.y + 4.0
		var ball := _ball(parent, Vector3(at.x, top, at.y - 6.0), Vector3(0, 0, 6))
		rides.append({"element": element, "fact": fact, "x": at.x, "ball": ball, "node": node})
		i += 1
	var quiet := _row("quiet", "bowl", Vector2(i * SPACING, 0), Vector3(40, 3, 20), 0.0, "")
	ParkRecipes.place(quiet, parent, Callable(), publish)
	_ball(parent, Vector3(i * SPACING, 10.0, 0), Vector3.ZERO)
	var beside := _row("beside", "ledge", Vector2((i + 1) * SPACING, 0), Vector3(40, 3, 20), 0.0, "ride_ledge")
	ParkRecipes.place(beside, parent, Callable(), publish)
	_ball(parent, Vector3((i + 1) * SPACING + 40.0, 10.0, 0), Vector3.ZERO)
	for f in ROLL_FRAMES:
		await physics_frame
	var published := {}
	for entry in _facts:
		published[entry[0]] = true
	for ride in rides:
		var near := _facts.filter(func(e): return absf(e[1].x - ride["x"]) < SPACING * 0.5)
		var kinds := near.map(func(e): return e[0])
		var expect: bool = EventKinds.WORLD_ROWS.has(ride["fact"])
		if expect:
			_t.check("(e) a roll over greybox %s publishes %s" % [ride["element"], ride["fact"]], kinds.has(ride["fact"]) and kinds.size() >= 1,
				str(kinds))
		else:
			_t.check("(e) greybox %s (fact '%s') publishes nothing" % [ride["element"], ride["fact"]], kinds.is_empty(), str(kinds))
		var ball: RigidBody3D = ride["ball"]
		if ParkRecipes.WEDGES.has(ride["element"]):
			_t.check("(e) the ball stays on greybox %s" % ride["element"], ball.position.y > 0.0, "y %.2f" % ball.position.y)
		else:
			_t.near("(e) the ball rests on greybox %s's top" % ride["element"], ball.position.y, 3.0 + Tuning.RADIUS, 0.1)
	for kind in NEW_FACTS:
		_t.check("(e) the roll publishes %s" % kind, published.has(kind), str(published.keys()))
	var stray := _facts.filter(func(e): return e[1].x > (i - 0.5) * SPACING)
	_t.check("(e) a row with no fact and a ball beside the footprint publish nothing", stray.is_empty(), str(stray))
	parent.free()
