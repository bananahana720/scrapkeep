extends SceneTree

const Terrain := preload("res://src/world/terrain.gd")
const Scenery := preload("res://src/presentation/spillway_scenery.gd")
const Spillway := preload("res://src/world/map_spillway.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PinHash := preload("res://tests/support/pin_hash.gd")
var failures := 0
# Terrain samples and collider vertices, pinned through tests/support/pin_hash.gd (rounded, so the pin holds on the Linux
# build and the Mac; record with PIN_RECORD=1). Until 16 Nov 2026 these were exact hashes, last re-pinned 2026-10-04 for
# ZS-A and ZS-D (terrain 2890712666, collider 1738491003 over all default roots, Spillway + Reach).
const TERRAIN_PIN := "res://tests/fixtures/pins/spillway_terrain.pin"
const COLLIDER_PIN := "res://tests/fixtures/pins/spillway_collider.pin"


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
	var trees := _check_cottonwoods(terrain.geometry_root(1), scenery)
	terrain.use(2)
	_check(not scenery.is_visible_in_tree() and scenery.global_position.y == -Terrain.PARK_DEPTH, "stage 2 hides and parks scenery")
	_check(trees != null and not trees.is_visible_in_tree(), "stage 2 hides the cottonwoods with the stage root")
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
	var bounds_ok := true
	var form_bad := 0
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
		peak_worst = maxf(peak_worst, top - crown["add"])
		# Station table: every upper-ring station takes the crest profile at its own final z, and the
		# world-Z order of the plan is the family order (east mirror undone).
		var v: int = crown["variant"]
		var rings: Array[PackedVector3Array] = Scenery.crown_rings(crown)
		var zsign := 1.0 if crown["side"] < 0 else -1.0
		for k in [2, 3, 4]:
			for i in rings[k].size():
				var u: float = 0.5 + zsign * rings[k][i].z / crown["width"]
				table_worst = maxf(table_worst, absf(rings[k][i].y - SPEC_RING_Y[k] * _spec_rise(v, u)))
		var below_ceiling := true
		for i in rings[4].size():
			below_ceiling = below_ceiling and absf(rings[4][i].x) <= crown["depth"] * 0.5 + 0.001 and absf(rings[4][i].z) <= crown["width"] * 0.5 + 0.001
		bounds_ok = bounds_ok and below_ceiling
		var form := _crown_form(crown, xf)
		form_bad += form
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
		for zi in range(-int(crown["width"] * 0.5) + 1, int(crown["width"] * 0.5), 2):
			var z: float = float(zi)
			var u: float = 0.5 + zsign * z / crown["width"]
			var rise: float = _spec_rise(v, u)
			for face in [1.0, -1.0]:
				var previous := INF
				var y := 0.0
				while y <= rise - 1.0:
					var reach := _flank_reach(local, indices, face, y, z)
					if reach != -INF:
						lip_worst = maxf(lip_worst, reach - half)
						if previous != INF:
							step_worst = maxf(step_worst, reach - previous)
						previous = reach
					y += 1.0
		var side: int = crown["side"]
		var start: float = crown["z"] - crown["width"] * 0.5
		if last_z[side] > -INF:
			gully_worst = minf(gully_worst, start - last_z[side])
		last_z[side] = crown["z"] + crown["width"] * 0.5
	_check(inside == 0, "no rim crown vertex inside the play rectangle plus 8 m apron (%d inside of %d)" % [inside, vertex_total])
	_check(plan.size() == 18, "18 rim crowns: three 120 m families a side, %d built" % plan.size())
	_check(table_worst <= 0.10 and peak_worst <= 0.05 and bounds_ok, "upper rings on the crest profile within %.3f m of 0.10, no crest above the old maximum (%.3f m over), rings inside the R2 envelope" % [table_worst, peak_worst])
	_check(form_bad == 0, "CLIFF-R3 crown form rules on the mesh (plan sections at h0 and half rise: longest run, axis share, rectangle occupancy, three arena-facing runs): %d rule failures" % form_bad)
	_check(root_worst >= 5.0 - 0.0001 and contact_ok, "root %.2f m under the lowest footprint terrain (5 m), terrain contact continuous at 2 m spacing (%s)" % [root_worst, contact_ok])
	_check(open_edges == 0, "every crown is a closed shell: %d open edges" % open_edges)
	_check(step_worst <= 0.05, "flank never steps outward as it rises: worst step %.3f m" % step_worst)
	_check(lip_worst <= 0.001, "no projecting lip past the base plane: %.3f m" % lip_worst)
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


func _spec_rise(variant: int, u: float) -> float:
	var keys: Array = SPEC_CREST[variant]
	for i in keys.size() - 1:
		if u <= keys[i + 1][0]:
			return lerpf(keys[i][1], keys[i + 1][1], (u - keys[i][0]) / (keys[i + 1][0] - keys[i][0]))
	return keys[keys.size() - 1][1]


# CLIFF-R3 section 2 on a mesh: plan sections cut from the triangles, then the run, axis and
# rectangle-occupancy limits, and three arena-facing runs. Returns the number of failed rules.
func _form_failures(local: PackedVector3Array, indices: PackedInt32Array, levels: Array, min_span: float, toward: Vector2) -> int:
	var bad := 0
	var spans_of := []
	for y in levels:
		var poly := _section(local, indices, y)
		if poly.size() < 3:
			return 99
		var runs := _runs(poly)
		var perimeter := 0.0
		var longest := 0.0
		var axis := 0.0
		for r in runs:
			perimeter += r["len"]
			longest = maxf(longest, r["len"])
			if r["axis"]:
				axis += r["len"]
		if longest > 0.25 * perimeter:
			bad += 1
		if axis > 0.35 * perimeter:
			bad += 1
		if absf(_area(poly)) > 0.90 * _min_rect(poly):
			bad += 1
		if y == levels[0]:
			var spans := []
			for r in runs:
				if r["len"] >= min_span and (r["normal"] as Vector2).dot(toward) > 0.0:
					spans.append(r["len"])
			if spans.size() < 3:
				bad += 1
	return bad


func _crown_form(crown: Dictionary, xf: Transform3D) -> int:
	var arrays := Scenery.crown_mesh(crown).surface_get_arrays(0)
	var local: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return _form_failures(local, indices, [0.01, crown["add"] * 0.5], 4.0, Vector2(1, 0))


func _hull_form(hull: Dictionary, vertices: PackedVector3Array, indices: PackedInt32Array) -> int:
	var rings: Array[PackedVector3Array] = Scenery.hull_rings(hull)
	var bottom := 0.0
	var top := 0.0
	for p in rings[0]:
		bottom += p.y / rings[0].size()
	for p in rings[3]:
		top += p.y / rings[3].size()
	var ys := []
	for f in [0.35, 0.70]:
		ys.append(bottom + (top - bottom) * f)
	return _form_failures(vertices, indices, ys, 6.0, Vector2(-hull["side"], 0))


# The closed outline where the plane y cuts the mesh, in (x, z), in walking order.
func _section(v: PackedVector3Array, idx: PackedInt32Array, y: float) -> PackedVector2Array:
	var next := {}
	var pts := {}
	for i in range(0, idx.size(), 3):
		var cut := []
		for e in 3:
			var a := v[idx[i + e]]
			var b := v[idx[i + (e + 1) % 3]]
			if (a.y - y) * (b.y - y) < 0.0:
				var t := (y - a.y) / (b.y - a.y)
				cut.append(Vector2(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t))
		if cut.size() == 2:
			var k0 := "%d,%d" % [roundi(cut[0].x * 1000.0), roundi(cut[0].y * 1000.0)]
			var k1 := "%d,%d" % [roundi(cut[1].x * 1000.0), roundi(cut[1].y * 1000.0)]
			pts[k0] = cut[0]
			pts[k1] = cut[1]
			if not next.has(k0):
				next[k0] = []
			if not next.has(k1):
				next[k1] = []
			next[k0].append(k1)
			next[k1].append(k0)
	var poly := PackedVector2Array()
	if next.is_empty():
		return poly
	var start: String = next.keys()[0]
	var prev := ""
	var cur := start
	for _n in next.size() + 1:
		poly.append(pts[cur])
		var options: Array = next[cur]
		var step: String = options[0] if options[0] != prev else options[options.size() - 1]
		prev = cur
		cur = step
		if cur == start:
			break
	return poly


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


# Straight runs: consecutive edges whose directions differ by under 5 degrees merge.
func _runs(poly: PackedVector2Array) -> Array:
	var n := poly.size()
	var wind := 1.0 if _area(poly) > 0.0 else -1.0
	var edges := []
	for i in n:
		var e := poly[(i + 1) % n] - poly[i]
		if e.length() > 0.0001:
			edges.append(e)
	var first := 0
	for i in edges.size():
		if rad_to_deg((edges[i] as Vector2).angle_to(edges[(i - 1 + edges.size()) % edges.size()])) > 5.0 or rad_to_deg((edges[i] as Vector2).angle_to(edges[(i - 1 + edges.size()) % edges.size()])) < -5.0:
			first = i
			break
	var runs := []
	var acc := Vector2.ZERO
	var head := Vector2.ZERO
	var length := 0.0
	for c in edges.size():
		var e: Vector2 = edges[(first + c) % edges.size()]
		if c > 0 and absf(rad_to_deg(head.angle_to(e))) >= 5.0:
			runs.append(_run_row(acc, length, wind))
			acc = Vector2.ZERO
			length = 0.0
		if acc == Vector2.ZERO:
			head = e
		acc += e
		length += e.length()
	runs.append(_run_row(acc, length, wind))
	return runs


func _run_row(chord: Vector2, length: float, wind: float) -> Dictionary:
	var deg := fmod(absf(rad_to_deg(atan2(chord.y, chord.x))), 90.0)
	var near_axis := deg <= 10.0 or deg >= 80.0
	return {"len": length, "axis": near_axis, "normal": Vector2(chord.y, -chord.x).normalized() * wind}


# Area of the smallest rectangle around the polygon (edge-aligned search).
func _min_rect(poly: PackedVector2Array) -> float:
	var hull := Geometry2D.convex_hull(poly)
	var best := INF
	for i in hull.size() - 1:
		var d := (hull[i + 1] - hull[i]).normalized()
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in hull:
			var q := Vector2(p.dot(d), p.dot(Vector2(-d.y, d.x)))
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		best = minf(best, (hi.x - lo.x) * (hi.y - lo.y))
	return best


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
	var form_bad := 0
	for hull in plan:
		var mesh: ArrayMesh = Scenery.shoulder_mesh(hull)
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		vertex_total += vertices.size()
		triangle_total += indices.size() / 3
		open_edges += _open_edges(vertices, indices)
		form_bad += _hull_form(hull, vertices, indices)
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
	_check(form_bad == 0, "CLIFF-R3 hull form rules on the mesh (plan sections at 35 and 70 percent of height): %d rule failures" % form_bad)
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


# 2026-10-09 SWAP-WAVE 12-F cottonwood: the shoulder cottonwoods left the scenery batches (CottonwoodTrunks and
# CottonwoodCrowns are gone, so the budget above no longer counts them) for the cottonwood recipe under the stage root:
# one MultiMesh per base view with an instance per tree, and per-tree holders carrying the fading shells.
func _check_cottonwoods(stage_root: Node3D, scenery: Node3D) -> Node3D:
	_check(scenery.get_node_or_null("CottonwoodTrunks") == null and scenery.get_node_or_null("CottonwoodCrowns") == null,
		"the greybox trunk and crown batches are gone from the scenery node")
	var group := stage_root.get_node_or_null("Cottonwoods") as Node3D
	_check(group != null and group.get_parent() == stage_root, "the cottonwoods hang under the stage root, not the scenery node")
	if group == null:
		return null
	var trees := Scenery.cottonwood_trees()
	var probe := Node3D.new()
	var base := RecipeProps.base("cottonwood", probe, Transform3D.IDENTITY)
	var batches := group.find_children("*", "MultiMeshInstance3D", false, false)
	var batches_ok := base.size() == 2 and batches.size() == base.size()
	var top := 0.0
	var crown_wide_x := false
	for view: GeometryInstance3D in base:
		var source := view as MeshInstance3D
		var batch := group.get_node_or_null(NodePath(source.name)) as MultiMeshInstance3D
		batches_ok = batches_ok and batch != null and batch.multimesh.instance_count == trees.size()
		if batch == null:
			continue
		var mesh := batch.multimesh.mesh
		batches_ok = batches_ok and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and batch.material_override == null
		batches_ok = batches_ok and mesh.get_surface_count() == source.mesh.get_surface_count()
		for i in mesh.get_surface_count():
			batches_ok = batches_ok and mesh.surface_get_material(i) == source.get_surface_override_material(i) and mesh.surface_get_material(i) != null
		var origins: PackedVector3Array = batch.get_meta("origins", PackedVector3Array())
		batches_ok = batches_ok and origins.size() == trees.size()
		for i in mini(origins.size(), trees.size()):
			batches_ok = batches_ok and origins[i].is_equal_approx((Scenery.cottonwood_frame(trees[i]) * source.transform).origin)
		var box := source.transform * source.mesh.get_aabb()
		top = maxf(top, box.end.y)
		if source.name.ends_with("Crown"):
			crown_wide_x = box.size.x > box.size.z
	probe.free()
	_check(batches_ok, "%d base batches, one per recipe base view, %d instances each at the tree frames, slot materials per surface, shadows on" % [batches.size(), trees.size()])
	var holders := 0
	var shells_ok := true
	var size_lo := INF
	var size_hi := 0.0
	for i in trees.size():
		var holder := group.get_node_or_null("Cottonwood%02d" % i) as Node3D
		if holder == null:
			shells_ok = false
			continue
		holders += 1
		shells_ok = shells_ok and holder.transform.is_equal_approx(Scenery.cottonwood_frame(trees[i]))
		var rows := RecipeProps.shell_rows("cottonwood")
		shells_ok = shells_ok and holder.get_child_count() == rows.size()
		for k in mini(rows.size(), holder.get_child_count()):
			var shell := holder.get_child(k) as MeshInstance3D
			shells_ok = shells_ok and shell != null and shell.has_meta(RecipeProps.META_FADE) and shell.transform == Transform3D.IDENTITY
			shells_ok = shells_ok and shell.visibility_range_end == rows[k][1] and shell.visibility_range_end_margin == rows[k][2]
			shells_ok = shells_ok and shell.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		size_lo = minf(size_lo, trees[i]["size"])
		size_hi = maxf(size_hi, trees[i]["size"])
	_check(holders == 64 and shells_ok, "%d cottonwood holders at the tree frames, each with the recipe's fading shells" % holders)
	# Scale against the ball mannequin: the full-size tree's crown top matches round 1's 13 m crown (5 percent), over six
	# ball diameters, and the crown's long side runs along X as round 1's blobs did.
	var ball := 2.0 * Tuning.RADIUS
	_check(absf(top * size_hi - 13.0) <= 0.65 and top * size_hi >= 6.0 * ball and crown_wide_x,
		"tree height %.2f m at size %.2f (%.1f ball diameters), %.2f m at size %.2f; crown long side along X" % [top * size_hi, size_hi, top * size_hi / ball, top * size_lo, size_lo])
	return group


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
	var collider := PackedVector3Array()
	for shape_node in world.find_children("*", "CollisionShape3D", true, false):
		var shape := (shape_node as CollisionShape3D).shape
		if shape != null:
			collider.append_array(shape.get_debug_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	var pin_error := PinHash.check(TERRAIN_PIN, heights) + PinHash.check(COLLIDER_PIN, collider)
	print("%d collider vertices; rounding margin terrain %.2f collider %.2f %s" % [collider.size(), PinHash.margin(heights), PinHash.margin(collider), pin_error])
	_check(pin_error.is_empty(), "terrain samples and collider shapes unchanged from the pinned base")
