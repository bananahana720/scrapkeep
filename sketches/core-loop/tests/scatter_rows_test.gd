extends SceneTree

const T := preload("res://tests/support/t.gd")
const ScatterRows := preload("res://src/world/scatter_rows.gd")
const Scatter := preload("res://src/world/scatter.gd")
const Palette := preload("res://src/core/palette.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# Ground scatter (wave 12): each map's scatter table validates, a row's placements are a pure
# function of its seed, the kit meshes are closed and small, every instance stays at pebble-to-
# boulder scale and clear of the spawn, the beacon and the vault, a stage's scatter stays inside the
# vertex budget, and the ground collider is still the 2 m grid with nothing from the scatter or the
# relief in the physics world.


func _initialize() -> void:
	var t := T.new("scatter_rows_test")
	var seeds := {}
	var row_errors := []
	var relief_errors := []
	for map_id: String in Terrain.MAPS:
		var map = Terrain.MAPS[map_id].new()
		var table: Dictionary = map.scatter
		for row: Dictionary in table["kit"]:
			var tag := "%s/%s" % [map_id, row.get("seed", "?")]
			for problem in ScatterRows.problems(row):
				row_errors.append("%s %s" % [tag, problem])
			if not row_errors.is_empty() and row_errors.back().begins_with(tag):
				continue
			if float(row["density"]) <= 0.0: row_errors.append(tag + " density")
			var sc: Vector2 = row["scale"]
			if sc.x <= 0.0 or sc.x > sc.y: row_errors.append(tag + " scale range")
			if float(row["slope"]) <= 0.0 or float(row["slope"]) > 1.0: row_errors.append(tag + " slope")
			if float(row["bury"]) < 0.0 or float(row["bury"]) >= 1.0: row_errors.append(tag + " bury")
			if seeds.has(row["seed"]): row_errors.append(tag + " seed reused")
			seeds[row["seed"]] = true
			if Palette.slot_material(row["slot"]) == null: row_errors.append(tag + " slot")
			if Scatter._source(row["mesh"]).is_empty(): row_errors.append(tag + " mesh source")
		var relief: Dictionary = table["relief"]
		if not relief.is_empty() and float(relief["amp"]) > 0.14:
			relief_errors.append("%s relief amp %.2f" % [map_id, float(relief["amp"])])
		if relief.is_empty() != (table["kit"] as Array).is_empty():
			relief_errors.append("%s has only one of relief and scatter rows" % map_id)
	t.check("every scatter row validates", row_errors.is_empty(), ", ".join(row_errors))
	t.check("relief stays at or under 0.14 m and travels with scatter rows", relief_errors.is_empty(), ", ".join(relief_errors))
	t.check("the scatter table covers at least the Spillway and both Dig maps", seeds.has("scatter_spillway_rock") and seeds.has("scatter_dig_rock") and seeds.has("scatter_dig_deep_rock"))

	# The kit meshes: under the triangle cap, closed, every face wound outward (Godot: clockwise from outside).
	for kit_name: String in ScatterRows.KIT:
		var mesh := Scatter.kit_mesh(kit_name)
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var tris := verts.size() / 3
		t.check("kit %s is under %d triangles" % [kit_name, ScatterRows.KIT_TRIANGLE_CAP], tris > 0 and tris < ScatterRows.KIT_TRIANGLE_CAP, "%d triangles" % tris)
		var edges := {}
		var inward := 0
		for i in tris:
			var p := verts[i * 3]
			var q := verts[i * 3 + 1]
			var r := verts[i * 3 + 2]
			if (r - p).cross(q - p).dot((p + q + r) / 3.0) <= 0.0: inward += 1
			for pair in [[p, q], [q, r], [r, p]]:
				var a := _key(pair[0])
				var b := _key(pair[1])
				var edge := a + "|" + b if a < b else b + "|" + a
				edges[edge] = int(edges.get(edge, 0)) + 1
		var open := 0
		for edge in edges:
			if edges[edge] != 2: open += 1
		t.check("kit %s is closed, no culled face" % kit_name, open == 0, "%d edges not shared by two faces" % open)
		t.check("kit %s faces wind outward" % kit_name, inward == 0, "%d faces point inward" % inward)

	# Determinism, scale and keep-clear on a synthetic slope: same seed, same transforms.
	var ground := func(x: float, z: float, clearance: float) -> Vector3: return Vector3(x, 0.05 * x + clearance, z)
	var fake = Terrain.MAPS["dig"].new()
	fake.play_rect = Rect2(-40.0, -40.0, 80.0, 80.0)
	fake.spawn = Vector2(-20.0, -20.0)
	fake.beacon = Vector2(25.0, 10.0)
	fake.vault = Vector2(0.0, 30.0)
	var near_keep := 0
	for row: Dictionary in fake.scatter["kit"]:
		var aabb: AABB = Scatter._source(row["mesh"]).get("aabb", AABB())
		var a := Scatter.transforms(row, fake, ground, aabb)
		var b := Scatter.transforms(row, fake, ground, aabb)
		t.check("%s builds twice to identical transforms" % row["seed"], a.size() > 0 and a == b, "%d vs %d" % [a.size(), b.size()])
		var widest := 0.0
		for xf in a:
			widest = maxf(widest, (xf * aabb).size.x)
			var at := Vector2(xf.origin.x, xf.origin.z)
			if at.distance_to(fake.spawn) < 6.0 or at.distance_to(fake.beacon) < 31.0 or at.distance_to(fake.vault) < 11.0:
				near_keep += 1
		t.check("%s is pebble-to-ball scale" % row["seed"], widest > 0.1 and widest <= Tuning.RADIUS * 2.0, "widest %.2f m, ball radius %.2f m" % [widest, Tuning.RADIUS])
	t.check("no instance stands inside the spawn, beacon or vault keep-clear", near_keep == 0, "%d inside" % near_keep)
	var moved := ((fake.scatter["kit"] as Array)[0] as Dictionary).duplicate()
	moved["seed"] = "scatter_other"
	var aabb0: AABB = Scatter._source(moved["mesh"])["aabb"]
	t.check("a different seed moves the placements", Scatter.transforms(moved, fake, ground, aabb0) != Scatter.transforms((fake.scatter["kit"] as Array)[0], fake, ground, aabb0))

	# The built stages: scatter present, no collider under it, the collider is still the 2 m grid,
	# and a stage's scatter stays inside the vertex budget.
	var parent := Node3D.new()
	root.add_child(parent)
	var terrain := Terrain.new()
	terrain.build(parent)
	var worst := 0
	var report := []
	for stage in [1, 3, 4]:
		var stage_root: Node3D = terrain.geometry_root(stage)
		var scatter := stage_root.get_node_or_null("GroundScatter")
		var rows: Array = terrain.map_for(stage).scatter["kit"]
		t.check("stage %d carries one batch per scatter row" % stage, scatter != null and scatter.get_child_count() == rows.size(), "%d of %d" % [scatter.get_child_count() if scatter != null else -1, rows.size()])
		if scatter == null:
			continue
		t.check("stage %d scatter adds no collider" % stage, scatter.find_children("*", "CollisionObject3D", true, false).is_empty())
		var verts := 0
		for batch: MultiMeshInstance3D in scatter.get_children():
			verts += batch.multimesh.instance_count * int(batch.get_meta("verts_per_instance"))
			t.check("%s keeps its instance buffer and casts no shadow" % batch.name, batch.has_meta("instance_buffer") and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		worst = maxi(worst, verts)
		report.append("stage %d: %d scatter verts" % [stage, verts])
		var shape: CollisionShape3D = stage_root.get_node("Ground").find_children("*", "CollisionShape3D", true, false)[0]
		var faces := (shape.shape as ConcavePolygonShape3D).get_faces().size()
		t.check("stage %d ground collider is still the 2 m grid" % stage, faces == Terrain.CELLS * Terrain.CELLS * 6, "%d face verts" % faces)
		var view: MeshInstance3D = stage_root.get_node("Ground").find_children("*", "MeshInstance3D", true, false)[0]
		var sub: int = terrain.map_for(stage).scatter["relief"]["sub"]
		var side := Terrain.CELLS * sub + 1
		t.check("stage %d view carries the relief grid" % stage, view.mesh.surface_get_array_len(0) == side * side, "%d verts" % view.mesh.surface_get_array_len(0))
	print("scatter_rows_test: ", "; ".join(report))
	t.check("scatter stays under %d visual verts per stage" % ScatterRows.VERTEX_BUDGET, worst > 0 and worst <= ScatterRows.VERTEX_BUDGET, "worst %d" % worst)
	parent.free()
	quit(t.verdict())


static func _key(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)]
