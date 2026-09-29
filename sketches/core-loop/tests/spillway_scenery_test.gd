extends SceneTree

const Terrain := preload("res://src/world/terrain.gd")
const Scenery := preload("res://src/presentation/spillway_scenery.gd")
const Spillway := preload("res://src/world/map_spillway.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var terrain := Terrain.new()
	terrain.build(world)
	var scenery := Scenery.build(terrain.geometry_root(1))
	var triangles := 0
	var checked := 0
	var bounds_ok := true
	var materials_ok := true
	var nodes_ok := scenery.transform == Transform3D.IDENTITY and scenery.get_script() == null and not scenery.is_processing() and not scenery.is_physics_processing()
	for child in scenery.get_children():
		nodes_ok = nodes_ok and child is MeshInstance3D and child.get_child_count() == 0
		nodes_ok = nodes_ok and child.transform == Transform3D.IDENTITY and child.get_script() == null and not child.is_processing() and not child.is_physics_processing()
		if not child is MeshInstance3D:
			continue
		var mesh: Mesh = child.mesh
		nodes_ok = nodes_ok and (mesh.get_surface_count() <= 3 if child.name == "DamDetail" else mesh.get_surface_count() == 1)
		var mat: Material = child.material_override
		if mat is ShaderMaterial:
			var expected := "sandstone.gdshader" if child.name == "SandstoneShoulders" else "spill_water.gdshader"
			materials_ok = materials_ok and child.name in ["SandstoneShoulders", "SpillSheets", "Tailrace"]
			materials_ok = materials_ok and mat.shader.resource_path.ends_with(expected)
		elif mat is StandardMaterial3D:
			if child.name == "WaterMist":
				materials_ok = materials_ok and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and mat.albedo_color.a <= 0.12
			else:
				materials_ok = materials_ok and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			materials_ok = materials_ok and (not mat.emission_enabled or child.name == "LanternLenses") and not mat.no_depth_test
		elif child.name == "DamDetail" and mat == null:
			for surface in mesh.get_surface_count():
				var slot_mat := mesh.surface_get_material(surface) as StandardMaterial3D
				materials_ok = materials_ok and slot_mat != null and slot_mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
				materials_ok = materials_ok and not slot_mat.emission_enabled and not slot_mat.no_depth_test
		else:
			materials_ok = false
		materials_ok = materials_ok and child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += indices.size() / 3
			for i in range(0, indices.size(), 3):
				checked += 1
				var bounds := AABB(vertices[indices[i]], Vector3.ZERO)
				bounds = bounds.expand(vertices[indices[i + 1]])
				bounds = bounds.expand(vertices[indices[i + 2]])
				var outside := bounds.end.x < -113.0 or bounds.position.x > 160.0 or bounds.end.z < -186.0 or bounds.position.z > 186.0
				if child.name in ["SpillSheets", "Tailrace", "WaterMist"]:
					outside = outside and bounds.position.z > 200.0
				if not outside:
					print("OVERLAP %s triangle %d %s" % [child.name, i / 3, bounds])
				bounds_ok = bounds_ok and outside
	_check(bounds_ok, "all %d triangle AABBs outside stage-1 play rectangle plus 8 m apron" % checked)
	_check(nodes_ok, "only inert mesh nodes, no collision/navigation/gameplay nodes")
	_check(materials_ok, "depth-tested materials; only named mist alpha and lantern emission; approved rock/water shaders; shadows disabled")
	_check(triangles > 0 and triangles <= 25000 and scenery.get_child_count() <= 20,
		"geometry budget: %d triangles, %d single-surface batches (not measured draw calls)" % [triangles, scenery.get_child_count()])
	_check(scenery.is_visible_in_tree(), "visible under stage 1")
	terrain.use(2)
	_check(not scenery.is_visible_in_tree() and scenery.global_position.y == -Terrain.PARK_DEPTH, "stage 2 hides and parks scenery")
	terrain.use(1)
	_check(scenery.is_visible_in_tree() and scenery.global_position == Vector3.ZERO, "stage 1 restores scenery")
	terrain.park_all()
	_check(not scenery.is_visible_in_tree() and not scenery.can_process(), "arena parking hides and disables scenery")
	terrain.use(1)
	_check(scenery.is_visible_in_tree(), "return from arena restores scenery")
	_check_rim()
	world.free()
	print("spillway_scenery_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


# Rim crown families, GEOMETRY.md section 3. Everything is measured on the same plan and meshes
# that SpillwayScenery.build bakes into the shoulder batch.
func _check_rim() -> void:
	var plan: Array = Scenery.rim_plan(Spillway.new())
	var inside := 0
	var vertex_total := 0
	var triangle_total := 0
	var lip_worst := 0.0
	var depth_worst := 0.0
	var width_ok := true
	var top_ok := true
	var root_ok := true
	var last_z := {-1: -INF, 1: -INF}
	var gully_worst := INF
	for crown in plan:
		var mesh: ArrayMesh = Scenery.crown_mesh(crown)
		var xf: Transform3D = Scenery.crown_transform(crown)
		var arrays := mesh.surface_get_arrays(0)
		var local: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		vertex_total += local.size()
		triangle_total += arrays[Mesh.ARRAY_INDEX].size() / 3
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for point in local:
			var w: Vector3 = xf * point
			# Play rectangle X -105..152, Z -178..178 plus the 8 m apron.
			if w.x > -113.0 and w.x < 160.0 and absf(w.z) < 186.0:
				inside += 1
			lo = lo.min(point)
			hi = hi.max(point)
		depth_worst = maxf(depth_worst, hi.x - lo.x)
		width_ok = width_ok and hi.z - lo.z <= crown["width"] + 0.001
		top_ok = top_ok and absf(hi.y - crown["add"]) < 0.01
		root_ok = root_ok and lo.y <= -5.0 and absf(xf.origin.y - crown["crest"]) < 0.001
		# Lip: the largest outward step of a ring beyond the ring under it, above the crest line.
		var rings: Array[PackedVector3Array] = Scenery.crown_rings(crown)
		for k in range(1, 5):
			for i in rings[k].size():
				var below := Vector2(rings[k][i].x, rings[k][i].z)
				var above := Vector2(rings[k + 1][i].x, rings[k + 1][i].z)
				if below.length() > 0.01:
					lip_worst = maxf(lip_worst, (above - below).dot(below.normalized()))
		# Gully: distance along z to the previous crown of the same side.
		var side: int = crown["side"]
		var start: float = crown["z"] - crown["width"] * 0.5
		if last_z[side] > -INF:
			gully_worst = minf(gully_worst, start - last_z[side])
		last_z[side] = crown["z"] + crown["width"] * 0.5
	_check(inside == 0, "no rim crown vertex inside the play rectangle plus 8 m apron (%d inside of %d)" % [inside, vertex_total])
	_check(plan.size() == 18, "18 rim crowns: three 120 m families a side, %d built" % plan.size())
	_check(depth_worst <= 16.0 + 0.001 and width_ok and top_ok and root_ok,
		"crown limits: depth %.1f m of 16, widths fit 48/36/24 (%s), top exactly add over the sampled crest (%s), root at least 5 m below the crest line (%s)" % [depth_worst, width_ok, top_ok, root_ok])
	_check(lip_worst <= 3.0, "largest ring lip %.2f m, at most 3 m" % lip_worst)
	_check(absf(gully_worst - 6.0) < 0.001, "narrowest gully between crowns %.1f m, 6 m" % gully_worst)
	_check(vertex_total <= 12000 and triangle_total <= 8000, "crown set budget: %d vertices of 12000, %d triangles of 8000" % [vertex_total, triangle_total])
	var repeats := 0
	var heights := {}
	for side in [-1, 1]:
		var prior := {}
		var run: Array = []
		for crown in plan:
			if crown["side"] != side:
				continue
			run.append(crown)
			heights[snappedf(crown["add"], 0.01)] = true
			if not prior.is_empty() and (absf(prior["add"] - crown["add"]) < 3.0 or absf(prior["width"] - crown["width"]) < 6.0):
				repeats += 1
			prior = crown
		for f in 3:
			var adds := {}
			for crown in run:
				if crown["family"] == f:
					adds[crown["add"]] = true
			if adds.size() != 3:
				repeats += 1
	_check(repeats == 0 and heights.size() == 3, "rim family never repeats equal-height crowns: %d repeats, adds %s" % [repeats, str(heights.keys())])
