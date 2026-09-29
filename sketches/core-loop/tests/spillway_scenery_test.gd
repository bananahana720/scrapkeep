extends SceneTree

const Terrain := preload("res://src/world/terrain.gd")
const Scenery := preload("res://src/presentation/spillway_scenery.gd")
const Spillway := preload("res://src/world/map_spillway.gd")
var failures := 0
# Recorded at base bcd0a7e; the round 2 slice changes neither.
const TERRAIN_HASH := 2887965403
const COLLIDER_HASH := 2873548634


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
	_check_shoulders()
	_check_frozen(world)
	world.free()
	print("spillway_scenery_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


# Rim crown families, CLIFF-R2 sections 1, 3 and 4. Everything is measured on the same plan and
# meshes that SpillwayScenery.build bakes into the shoulder batch.
func _check_rim() -> void:
	var map := Spillway.new()
	var plan: Array = Scenery.rim_plan(map)
	var inside := 0
	var vertex_total := 0
	var triangle_total := 0
	var table_worst := 0.0
	var peak_worst := 0.0
	var root_worst := INF
	var contact_ok := true
	var step_worst := 0.0
	var lip_worst := 0.0
	var open_edges := 0
	var budget_ok := true
	var fold_ok := true
	var s_rise := INF
	var h_rise := INF
	var last_z := {-1: -INF, 1: -INF}
	var gully_worst := INF
	for crown in plan:
		var mesh: ArrayMesh = Scenery.crown_mesh(crown)
		var xf: Transform3D = Scenery.crown_transform(crown)
		var arrays := mesh.surface_get_arrays(0)
		var local: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		vertex_total += local.size()
		triangle_total += indices.size() / 3
		budget_ok = budget_ok and indices.size() / 3 <= 132 and local.size() <= 3 * indices.size() / 3
		open_edges += _open_edges(local, indices)
		var top := -INF
		var base := INF
		for point in local:
			var w: Vector3 = xf * point
			if w.x > -113.0 and w.x < 160.0 and absf(w.z) < 186.0:
				inside += 1
			top = maxf(top, point.y)
			base = minf(base, point.y)
		peak_worst = maxf(peak_worst, absf(top - crown["add"]))
		# Station table: every top-ring station against the crest profile at its u, in world Z.
		var v: int = crown["variant"]
		var rings: Array[PackedVector3Array] = Scenery.crown_rings(crown)
		var stations := Scenery.crown_stations(v)
		var zsign := 1.0 if crown["side"] < 0 else -1.0
		for i in stations.size():
			var u: float = stations[i]["u"]
			table_worst = maxf(table_worst, absf(rings[4][i].y - _spec_rise(v, u)))
			table_worst = maxf(table_worst, absf(rings[2][i].y - SPEC_RING_Y[2] * _spec_rise(v, u)))
			table_worst = maxf(table_worst, absf(rings[3][i].y - SPEC_RING_Y[3] * _spec_rise(v, u)))
			var world_z: float = (xf * rings[1][i]).z
			table_worst = maxf(table_worst, absf(world_z - (crown["z"] + (u - 0.5) * crown["width"])))
		# Depth kept at .35/.70/top: 95, 85, 75 percent about the same centre.
		for k in [2, 3, 4]:
			for i in stations.size():
				var kept: float = absf(rings[k][i].x) / (crown["depth"] * 0.5)
				table_worst = maxf(table_worst, absf(kept - SPEC_RING_DEPTH[k]) * crown["depth"] * 0.5)
		# Terrain under the final footprint: root at least 5 m under the lowest, h0 the highest.
		var hi := -INF
		var lo := INF
		for xi in Scenery.footprint_steps(crown["depth"]):
			for zi in Scenery.footprint_steps(crown["width"]):
				var h: float = map.sample(crown["x"] + xi, crown["z"] + zi)[0]
				hi = maxf(hi, h)
				lo = minf(lo, h)
				contact_ok = contact_ok and h <= crown["crest"] + 0.0001 and h >= crown["crest"] - crown["root"] + 5.0 - 0.0001
		root_worst = minf(root_worst, lo - (crown["crest"] + base))
		contact_ok = contact_ok and absf(hi - crown["crest"]) < 0.0001
		# Flank cross-sections every 2 m along Z, both flanks, from the mesh: the silhouette never
		# steps outward as it rises, and no point passes the base plane (no lip).
		var half: float = crown["depth"] * 0.5
		var folds: Array = _fold_ranges(crown)
		for zi in range(-int(crown["width"] * 0.5) + 1, int(crown["width"] * 0.5), 2):
			var z: float = float(zi)
			var u: float = 0.5 + zsign * z / crown["width"]
			var in_fold := false
			for f in folds:
				in_fold = in_fold or (u >= f.x and u <= f.y)
			var rise: float = _spec_rise(v, u)
			for face in [1.0, -1.0]:
				var previous := INF
				var y := 0.0
				while y <= rise - 1.0:
					var reach := _flank_reach(local, indices, face, y, z)
					if reach == -INF:
						open_edges += 1
					else:
						lip_worst = maxf(lip_worst, reach - half)
						if not in_fold:
							step_worst = maxf(step_worst, reach - previous)
							previous = reach
					y += 1.0
		fold_ok = fold_ok and _fold_depth_ok(crown)
		if v == 1:
			s_rise = minf(s_rise, _fold_rise(crown))
		elif v == 2:
			h_rise = minf(h_rise, _fold_rise(crown))
		var side: int = crown["side"]
		var start: float = crown["z"] - crown["width"] * 0.5
		if last_z[side] > -INF:
			gully_worst = minf(gully_worst, start - last_z[side])
		last_z[side] = crown["z"] + crown["width"] * 0.5
	_check(inside == 0, "no rim crown vertex inside the play rectangle plus 8 m apron (%d inside of %d)" % [inside, vertex_total])
	_check(plan.size() == 18, "18 rim crowns: three 120 m families a side, %d built" % plan.size())
	_check(table_worst <= 0.10 and peak_worst <= 0.05, "station tables within %.3f m of 0.10, crest maxima within %.3f m of 0.05" % [table_worst, peak_worst])
	_check(root_worst >= 5.0 - 0.0001 and contact_ok, "root %.2f m under the lowest footprint terrain (5 m), terrain contact continuous at 2 m spacing (%s)" % [root_worst, contact_ok])
	_check(open_edges == 0, "every crown is a closed shell: %d open edges or empty flank rays" % open_edges)
	_check(step_worst <= 0.05, "unfractured flank never steps outward as it rises: worst step %.3f m" % step_worst)
	_check(lip_worst <= 0.001, "no projecting lip past the base plane: %.3f m" % lip_worst)
	_check(fold_ok, "each fold recesses 0.5 to 0.8 m inside its parent flank and stays within it")
	_check(s_rise >= 2.9 and h_rise >= 4.8, "fold rise from the mesh: S %.2f m (spec 3), H %.2f m (spec 5)" % [s_rise, h_rise])
	_check(absf(gully_worst - 6.0) < 0.001, "narrowest gully between crowns %.1f m, 6 m" % gully_worst)
	_check(budget_ok and vertex_total <= 7128 and triangle_total <= 2376, "crown set budget: %d vertices of 7128, %d triangles of 2376" % [vertex_total, triangle_total])
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
	var order_ok: bool = Scenery.RIM_WEST_ORDER[2] == [0, 1, 2] and Scenery.RIM_EAST_ORDER[2] == [0, 1, 2]
	_check(order_ok, "F2 beside the dam is C/S/H on both sides")
	print("rim counts: crown V %d T %d" % [vertex_total, triangle_total])


# CLIFF-R2 section 1, typed in from the spec so a drifted constant fails here.
const SPEC_CREST := [
	[[0.0, 8.0], [0.20, 16.0], [0.38, 18.0], [0.64, 17.0], [0.85, 12.0], [1.0, 8.0]],
	[[0.0, 3.0], [0.20, 5.0], [0.40, 6.0], [0.60, 5.5], [0.85, 4.0], [1.0, 3.0]],
	[[0.0, 5.0], [0.20, 10.0], [0.38, 12.0], [0.64, 12.0], [0.85, 10.0], [1.0, 6.0]],
]
const SPEC_RING_Y := [0.0, 0.0, 0.35, 0.70, 1.0]
const SPEC_RING_DEPTH := [1.0, 1.0, 0.95, 0.85, 0.75]


func _spec_rise(variant: int, u: float) -> float:
	var keys: Array = SPEC_CREST[variant]
	for i in keys.size() - 1:
		if u <= keys[i + 1][0]:
			return lerpf(keys[i][1], keys[i + 1][1], (u - keys[i][0]) / (keys[i + 1][0] - keys[i][0]))
	return keys[keys.size() - 1][1]


# u intervals of the diagonal folds of a crown.
func _fold_ranges(crown: Dictionary) -> Array:
	var ranges := []
	var face: Array = Scenery.RIM_FACE_U[crown["variant"]]
	for i in Scenery.RIM_FOLDS[crown["variant"]]:
		ranges.append(Vector2(face[i], face[i + 1]))
	return ranges


# Folds sit 0.5 to 0.8 m inside the parent flank: each fold segment has exactly two points that
# are not ring corners and lie off the flank's two original triangles, both that deep.
func _fold_depth_ok(crown: Dictionary) -> bool:
	var v: int = crown["variant"]
	var mesh: ArrayMesh = Scenery.crown_mesh(crown)
	var local: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var rings: Array[PackedVector3Array] = Scenery.crown_rings(crown)
	var corners := {}
	for ring in rings:
		for p in ring:
			corners[_key(p)] = true
	var quads := []
	for i in Scenery.RIM_FOLDS[v]:
		for row in Scenery.RIM_FOLD_BANDS[v]:
			var k: int = row[0]
			quads.append([rings[k][i], rings[k][i + 1], rings[k + 1][i + 1], rings[k + 1][i]])
	var deep := {}
	for p in local:
		if corners.has(_key(p)):
			continue
		var best := INF
		for quad in quads:
			var a: Vector3 = quad[0]
			var b: Vector3 = quad[1]
			var c: Vector3 = quad[2]
			var d: Vector3 = quad[3]
			var box := AABB(a, Vector3.ZERO).expand(b).expand(c).expand(d).grow(1.0)
			if box.has_point(p):
				var n1 := (b - a).cross(d - a).normalized()
				var n2 := (c - b).cross(d - b).normalized()
				best = minf(best, minf(absf((p - a).dot(n1)), absf((p - b).dot(n2))))
		deep[_key(p)] = best
	var ok: bool = deep.size() == 2 * quads.size()
	for key in deep:
		ok = ok and deep[key] >= 0.5 and deep[key] <= 0.8
	return ok


# Vertical extent of a single-fold crown (S or H), from the fold's non-corner points.
func _fold_rise(crown: Dictionary) -> float:
	var local: PackedVector3Array = Scenery.crown_mesh(crown).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var corners := {}
	for ring in Scenery.crown_rings(crown):
		for p in ring:
			corners[_key(p)] = true
	var lo := INF
	var hi := -INF
	for p in local:
		if not corners.has(_key(p)):
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
	return hi - lo


# Outermost x of the flank at height y and z (crown-local), face = +1 for +x, -1 for -x; -INF when
# the ray hits nothing.
func _flank_reach(local: PackedVector3Array, indices: PackedInt32Array, face: float, y: float, z: float) -> float:
	var origin := Vector3(face * 60.0, y, z)
	var dir := Vector3(-face, 0.0, 0.0)
	var best := -INF
	for i in range(0, indices.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(origin, dir, local[indices[i]], local[indices[i + 1]], local[indices[i + 2]])
		if hit != null:
			best = maxf(best, face * hit.x)
	return best


# Edges used by other than two triangles, positions welded to 1 mm.
func _open_edges(vertices: PackedVector3Array, indices: PackedInt32Array) -> int:
	var count := {}
	for i in range(0, indices.size(), 3):
		for e in 3:
			var a := _key(vertices[indices[i + e]])
			var b := _key(vertices[indices[i + (e + 1) % 3]])
			var key := "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
			count[key] = count.get(key, 0) + 1
	var bad := 0
	for key in count:
		if count[key] != 2:
			bad += 1
	return bad


func _key(p: Vector3) -> String:
	return "%d,%d,%d" % [roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0)]


# Shoulder hulls, CLIFF-R2 section 2.
func _check_shoulders() -> void:
	var plan: Array = Scenery.shoulder_plan()
	var vertex_total := 0
	var triangle_total := 0
	var envelope_ok := true
	var open_edges := 0
	var support_worst := INF
	var roots_ok := true
	var lip_worst := 0.0
	var apron_ok := true
	for hull in plan:
		var mesh: ArrayMesh = Scenery.shoulder_mesh(hull)
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		vertex_total += vertices.size()
		triangle_total += indices.size() / 3
		open_edges += _open_edges(vertices, indices)
		var envelope: AABB = Scenery.shoulder_envelope(hull)
		for p in vertices:
			envelope_ok = envelope_ok and envelope.grow(0.001).has_point(p)
			apron_ok = apron_ok and (p.x < -113.0 or p.x > 160.0)
		var rings: Array[PackedVector3Array] = Scenery.hull_rings(hull)
		var polygon := PackedVector2Array()
		for p in rings[3]:
			polygon.append(Vector2(p.x, p.z))
		var top_limit: float = hull["h"] * 0.95 + 12.0
		for root: Vector3 in hull["roots"]:
			var here := Vector2(root.x, root.z)
			roots_ok = roots_ok and Geometry2D.is_point_in_polygon(here, polygon)
			support_worst = minf(support_worst, _edge_distance(here, polygon))
			for p in rings[3]:
				roots_ok = roots_ok and p.y >= root.y + 0.15 - 0.0001 and p.y <= top_limit
		# Each level's outline lies inside the outline of the level under it.
		for level in 3:
			var below_polygon := PackedVector2Array()
			for p in rings[level]:
				below_polygon.append(Vector2(p.x, p.z))
			for p in rings[level + 1]:
				if not Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), below_polygon):
					lip_worst = maxf(lip_worst, _edge_distance(Vector2(p.x, p.z), below_polygon) + 0.001)
	_check(plan.size() == 16 and triangle_total <= 16 * 96 and vertex_total <= 4608, "16 shoulder hulls replace 64 shelves: %d vertices of 4608, %d triangles of 1536" % [vertex_total, triangle_total])
	_check(envelope_ok and apron_ok, "hulls stay inside the union of the old shelf bounds and outside the apron")
	_check(open_edges == 0, "every shoulder hull is a closed shell: %d open edges" % open_edges)
	_check(roots_ok and support_worst >= 2.0, "every cottonwood root sits in the hull top with %.2f m of plan support (2 m) and 0.15 m of solid" % support_worst)
	_check(lip_worst <= 0.001, "no shoulder level projects past the level under it: %.3f m" % lip_worst)
	print("shoulder counts: V %d T %d" % [vertex_total, triangle_total])


func _edge_distance(p: Vector2, polygon: PackedVector2Array) -> float:
	var best := INF
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var closest := Geometry2D.get_closest_point_to_segment(p, a, b)
		best = minf(best, p.distance_to(closest))
	return best


# Terrain, colliders and cottonwoods do not move.
func _check_frozen(world: Node3D) -> void:
	var cottonwoods := Scenery.cottonwood_transforms()
	var trunks: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for i in 8:
			var z := -176.0 + i * 56.0
			var h := 74.0 + 15.0 * sin(i * 1.8 + side)
			for j in 4:
				var foot := Vector3(side * (246.0 + 8.0 * sin(i * 2.1)) + side * 15 + j * 3, h * 0.75 + h * 0.18 + 12, z - 15 + j * 7)
				var size := 0.6 + 0.4 * sin(j * 2.3 + i)
				trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.55, 3, 0.55)), foot + Vector3(0, 3, 0)))
				leaves.append(Transform3D(Basis.IDENTITY.scaled(Vector3(5, 4, 4) * size), foot + Vector3(-2, 6, 0)))
				leaves.append(Transform3D(Basis.IDENTITY.scaled(Vector3(4, 5, 4) * size), foot + Vector3(2, 8, 1)))
	_check(cottonwoods["trunks"] == trunks and cottonwoods["leaves"] == leaves, "cottonwood transforms identical to round 1: %d trunks, %d leaf blobs" % [trunks.size(), leaves.size()])
	var map := Spillway.new()
	var heights := PackedFloat32Array()
	for xi in range(-260, 261, 4):
		for zi in range(-260, 261, 4):
			heights.append(map.sample(float(xi), float(zi))[0])
	var terrain_hash := hash(heights.to_byte_array())
	var collider := PackedVector3Array()
	for shape_node in world.find_children("*", "CollisionShape3D", true, false):
		var shape := (shape_node as CollisionShape3D).shape
		if shape != null:
			collider.append_array(shape.get_debug_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	var collider_hash := hash(collider.to_byte_array())
	print("terrain hash %d collider hash %d (%d collider vertices)" % [terrain_hash, collider_hash, collider.size()])
	_check(terrain_hash == TERRAIN_HASH and collider_hash == COLLIDER_HASH, "terrain samples and collider shapes unchanged from the round 1 base")
