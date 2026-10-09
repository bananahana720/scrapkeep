extends SceneTree

const T := preload("res://tests/support/t.gd")
const ScatterRows := preload("res://src/world/scatter_rows.gd")
const Scatter := preload("res://src/world/scatter.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# P-GROUND: the scatter table validates, a row's placements are a pure function of its seed,
# every instance stays at pebble-to-ball scale, and the ground collider is still the 2 m grid
# with nothing from the scatter or the relief in the physics world.


func _initialize() -> void:
	var t := T.new("scatter_rows_test")
	var seeds := {}
	var row_errors := []
	for row: Dictionary in ScatterRows.ROWS:
		var tag := "%s/%s" % [row["map"], row["kind"]]
		if not Terrain.MAPS.has(row["map"]): row_errors.append(tag + " unknown map")
		if not row["kind"] in ScatterRows.KINDS: row_errors.append(tag + " unknown kind")
		if float(row["density"]) <= 0.0: row_errors.append(tag + " density")
		var sc: Vector2 = row["scale"]
		if sc.x <= 0.0 or sc.x > sc.y: row_errors.append(tag + " scale range")
		if float(row["slope"]) <= 0.0 or float(row["slope"]) > 1.0: row_errors.append(tag + " slope")
		if float(row["bury"]) < 0.0 or float(row["bury"]) >= 1.0: row_errors.append(tag + " bury")
		if seeds.has(row["seed"]): row_errors.append(tag + " seed reused")
		seeds[row["seed"]] = true
		if not DigScenery.SLOTS.has(row["slot"]): row_errors.append(tag + " slot")
		if Scatter._source(row["mesh"]).is_empty(): row_errors.append(tag + " mesh source")
	t.check("every scatter row validates", row_errors.is_empty(), ", ".join(row_errors))
	for map_id: String in ScatterRows.RELIEF:
		var relief: Dictionary = ScatterRows.RELIEF[map_id]
		t.check("%s relief stays under a fifth of the ball radius" % map_id, Terrain.MAPS.has(map_id) and float(relief["amp"]) <= Tuning.RADIUS * 0.2, str(relief))

	# Determinism and scale on a synthetic slope: same seed, same transforms.
	var ground := func(x: float, z: float, clearance: float) -> Vector3: return Vector3(x, 0.05 * x + clearance, z)
	var rect := Rect2(-40.0, -40.0, 80.0, 80.0)
	for row: Dictionary in ScatterRows.ROWS:
		var aabb: AABB = Scatter._source(row["mesh"]).get("aabb", AABB())
		var a := Scatter.transforms(row, rect, ground, aabb)
		var b := Scatter.transforms(row, rect, ground, aabb)
		t.check("%s/%s builds twice to identical transforms" % [row["map"], row["kind"]], a.size() > 0 and a == b, "%d vs %d" % [a.size(), b.size()])
		var widest := 0.0
		for xf in a:
			widest = maxf(widest, (xf * aabb).size.x)
		t.check("%s/%s is pebble-to-ball scale" % [row["map"], row["kind"]], widest > Tuning.RADIUS * 0.2 and widest <= Tuning.RADIUS * 2.0, "widest %.2f m, ball radius %.2f m" % [widest, Tuning.RADIUS])
	var moved := (ScatterRows.ROWS[0] as Dictionary).duplicate()
	moved["seed"] = "scatter_other"
	var aabb0: AABB = Scatter._source(moved["mesh"])["aabb"]
	t.check("a different seed moves the placements", Scatter.transforms(moved, rect, ground, aabb0) != Scatter.transforms(ScatterRows.ROWS[0], rect, ground, aabb0))

	# The built Spillway: scatter present, no collider under it, the collider is still the 2 m grid.
	var parent := Node3D.new()
	root.add_child(parent)
	var terrain := Terrain.new()
	terrain.build(parent)
	var stage_root: Node3D = terrain.geometry_root(1)
	var scatter := stage_root.get_node_or_null("GroundScatter")
	t.check("Spillway carries the ground scatter", scatter != null and scatter.get_child_count() == ScatterRows.for_map("spillway").size())
	t.check("the scatter adds no collider", scatter != null and scatter.find_children("*", "CollisionObject3D", true, false).is_empty())
	var shape: CollisionShape3D = stage_root.get_node("Ground").find_children("*", "CollisionShape3D", true, false)[0]
	var faces := (shape.shape as ConcavePolygonShape3D).get_faces().size()
	t.check("the ground collider is still the 2 m grid", faces == Terrain.CELLS * Terrain.CELLS * 6, "%d face verts" % faces)
	var view: MeshInstance3D = stage_root.get_node("Ground").find_children("*", "MeshInstance3D", true, false)[0]
	var sub: int = ScatterRows.RELIEF["spillway"]["sub"]
	var side := Terrain.CELLS * sub + 1
	t.check("the Spillway view carries the relief grid", view.mesh.surface_get_array_len(0) == side * side, "%d verts" % view.mesh.surface_get_array_len(0))
	parent.free()
	quit(t.verdict())
