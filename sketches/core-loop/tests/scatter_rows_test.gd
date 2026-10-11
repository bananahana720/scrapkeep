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
#
# Park scatter chunks (wave 13 KB5, PARK.md sections 3 and 9): a park's scatter is built in 160 m
# chunks aligned to park_terrain.gd's collider tiles, one MultiMesh per kind per chunk, on worker
# threads with the main thread attaching chunks inside an 8 ms budget; every piece stands on
# height(); the visible vertices from any camera stay under the budget; and the old maps' scatter
# transforms stay byte-identical to the base.

const ParkTerrain := preload("res://src/world/park/park_terrain.gd")

# SHA-256 of every old-map scatter transform (kind, seed, instance buffer, maps sorted), recorded
# 2026-10-11 on the untouched base d204cea (KB5). A change here moves an old map's scatter.
const OLD_MAPS_HASH := "5bdc8fbaa2b82655daf9425a055b042a7b8ce55de12e01ce71e643a2a5ce7666"
# The rows that hash covers: Dig 4, Dig Deep 4, Spillway 4 (a missing batch must not pass).
const OLD_MAPS_ROWS := 12
const PARK_TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_test"}]}
const FRAME_CAP_USEC := 8000
const BUILD_FRAMES_MAX := 6000
# The P-ADDON probe's unmerged scatter: Proton Scatter chunks of 15 m, one node per row per chunk
# (artifacts/local/alpha/push/w12/probes/addon/REPORT.md:71), the shape that read draws 2.06 times.
const PROBE_CHUNK_M := 15.0
const CAMERA_LIFT := 2.0

var t := T.new("scatter_rows_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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

	var old_hash := _old_maps_hash()
	print("scatter_rows_test: old-map scatter hash ", old_hash)
	t.eq("the old maps' scatter transforms are byte-identical to d204cea", old_hash, OLD_MAPS_HASH)

	await _park_chunks()
	quit(t.verdict())


# Every old map with scatter rows, built alone through terrain.gd as the game builds it; each batch's
# kind, seed and submitted instance buffer go into one SHA-256, maps sorted, rows in table order.
func _old_maps_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var ids: Array = Terrain.MAPS.keys()
	ids.sort()
	var hashed := 0
	for map_id: String in ids:
		var rows: Array = Terrain.MAPS[map_id].new().scatter["kit"]
		if rows.is_empty():
			continue
		var holder := Node3D.new()
		root.add_child(holder)
		var terrain := Terrain.new({"DEFS": [{"stage": 1, "world": 1, "map": map_id}]})
		terrain.build(holder)
		var scatter := terrain.geometry_root(1).get_node_or_null("GroundScatter")
		ctx.update(map_id.to_utf8_buffer())
		for row: Dictionary in rows:
			var batch: Node = scatter.get_node_or_null("Scatter_%s" % row["seed"]) if scatter != null else null
			ctx.update(("%s|%s|" % [row["kind"], row["seed"]]).to_utf8_buffer())
			if batch != null:
				ctx.update((batch.get_meta("instance_buffer") as PackedFloat32Array).to_byte_array())
				hashed += 1
		holder.free()
	t.eq("the old-map hash covers every old scatter row", hashed, OLD_MAPS_ROWS)
	return ctx.finish().hex_encode()


# The park fixture (park_test, KB4's bake): its stage built through terrain.gd, then its scatter
# built in chunks through a local shim (terrain.gd does not call the chunked build yet; the hook is
# reported with KB5), on worker threads, pumped frame by frame as the game would.
func _park_chunks() -> void:
	var api: Variant = Scatter
	if not t.check("scatter.gd has the chunked park build", Scatter.new().has_method("build_chunked") and Scatter.new().has_method("visible_vertices")):
		return
	var constants: Dictionary = (ScatterRows as Script).get_script_constant_map()
	var park_kit: Array = constants.get("PARK_KIT", [])
	var ranges: Dictionary = constants.get("RANGE", {})
	t.check("scatter_rows.gd carries the park kit rows", not park_kit.is_empty())
	for row: Dictionary in park_kit:
		var tag := "park/%s" % row.get("seed", "?")
		t.check("%s validates" % tag, ScatterRows.problems(row).is_empty(), ", ".join(ScatterRows.problems(row)))
		t.check("%s has a visibility range that covers its own chunk" % tag, float(ranges.get(row["kind"], 0.0)) >= ParkTerrain.TILE_M * sqrt(2.0) * 0.5)
	var rows_api: Variant = ScatterRows
	t.check("the park kit rows give one mesh and slot per kind", (rows_api.kind_problems(park_kit) as Array).is_empty(), str(rows_api.kind_problems(park_kit)))
	t.check("a table with two meshes under one kind is refused", not (rows_api.kind_problems([
		{"kind": "rock", "mesh": "kit:rubble", "slot": "stone"}, {"kind": "rock", "mesh": "kit:pebble", "slot": "stone"}]) as Array).is_empty())

	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	var terrain = Terrain.new(PARK_TABLE)
	terrain.build(holder)
	terrain.use(1)
	var stage_root: Node3D = terrain.geometry_root(1)
	var map = terrain.map_for(1)
	var ground: Callable = terrain.ground_callable(1)
	var chunks: Node3D = api.build_chunked(stage_root, map, ground, true)
	t.check("the chunked build starts on worker threads", chunks != null and not chunks.is_ready())
	var frames := 0
	while chunks != null and not chunks.is_ready() and frames < BUILD_FRAMES_MAX:
		await process_frame
		frames += 1
	if not t.check("the park scatter finished building", chunks != null and chunks.is_ready(), "%d frames" % frames):
		holder.free()
		return
	var slowest_ms: float = chunks.slowest_usec / 1000.0
	print("scatter_rows_test: park scatter built over %d frames, %d chunks on worker threads, slowest main-thread step %.2f ms at %s, worst frame %.2f ms"
		% [frames, chunks.worker_chunks, slowest_ms, chunks.slowest_step, chunks.frame_usec_max / 1000.0])
	t.check("the build spanned frames", frames > 1, "%d frames" % frames)
	t.eq("every chunk was built off the main thread", chunks.worker_chunks, ParkTerrain.TILE_COUNT)
	t.check("no main-thread scatter step over 8 ms during the build", chunks.slowest_usec > 0 and chunks.slowest_usec < FRAME_CAP_USEC, "%.2f ms" % slowest_ms)

	# One MultiMesh per kind per chunk; no node for a kind a chunk has none of; each chunk sits in
	# its collider tile; every piece stands on height().
	var per_chunk_errors := []
	var off_height := 0
	var off_tile := 0
	var batches := 0
	var instances := 0
	var probe_cells := {}
	for chunk: Node in chunks.get_children():
		var parts := String(chunk.name).trim_prefix("Chunk").split("_")
		var ci := int(parts[0])
		var cj := int(parts[1])
		var tile := Rect2(-ParkTerrain.HALF + ci * ParkTerrain.TILE_M, -ParkTerrain.HALF + cj * ParkTerrain.TILE_M, ParkTerrain.TILE_M, ParkTerrain.TILE_M)
		var seen := {}
		for batch: Node in chunk.get_children():
			if not batch is MultiMeshInstance3D:
				per_chunk_errors.append("%s/%s is not a MultiMeshInstance3D" % [chunk.name, batch.name])
				continue
			var kind := String(batch.get_meta("kind", ""))
			seen[kind] = int(seen.get(kind, 0)) + 1
			var multi: MultiMesh = batch.multimesh
			if multi.instance_count == 0:
				per_chunk_errors.append("%s/%s is empty" % [chunk.name, batch.name])
			batches += 1
			instances += multi.instance_count
			# grounds: the ground point under each piece (its transform origin is sunk by the bury share).
			var grounds: Array = batch.get_meta("grounds", [])
			if grounds.size() != multi.instance_count:
				per_chunk_errors.append("%s/%s has %d ground points for %d pieces" % [chunk.name, batch.name, grounds.size(), multi.instance_count])
			for at: Vector3 in grounds:
				if not tile.has_point(Vector2(at.x, at.z)):
					off_tile += 1
				if absf(at.y - terrain.height(at.x, at.z)) > 0.001:
					off_height += 1
				probe_cells["%s|%d|%d" % [kind, floori(at.x / PROBE_CHUNK_M), floori(at.z / PROBE_CHUNK_M)]] = true
		for kind in seen:
			if int(seen[kind]) != 1:
				per_chunk_errors.append("%s has %d batches of %s" % [chunk.name, seen[kind], kind])
	t.check("one MultiMesh per kind per chunk, none empty", batches > 0 and per_chunk_errors.is_empty(), ", ".join(per_chunk_errors.slice(0, 8)))
	t.check("every chunk's pieces lie inside its 160 m collider tile", instances > 0 and off_tile == 0, "%d of %d outside" % [off_tile, instances])
	t.check("every piece stands on height()", instances > 0 and off_height == 0, "%d of %d off" % [off_height, instances])
	t.check("the park scatter adds no collider", chunks.find_children("*", "CollisionObject3D", true, false).is_empty())

	# The same chunks built at once on the main thread give the same buffers: placement does not
	# depend on which worker ran a chunk or in what order.
	var spare := Node3D.new()
	var again: Node3D = api.build_chunked(spare, map, ground, false)
	var differ := 0
	for chunk: Node in chunks.get_children():
		for batch: Node in chunk.get_children():
			var twin: Node = again.get_node_or_null("%s/%s" % [chunk.name, batch.name])
			if twin == null or twin.get_meta("instance_buffer") != batch.get_meta("instance_buffer"):
				differ += 1
	t.check("a threaded build and a main-thread build place the same pieces", differ == 0 and again.get_child_count() == chunks.get_child_count(), "%d batches differ" % differ)
	spare.free()

	# Visible vertices: the fixture's spawn and beacon, and every chunk's centre, corners and edge
	# midpoints inside the play rect, a camera height above the ground.
	var cameras: Array[Vector2] = [map.spawn, map.beacon]
	for j in ParkTerrain.TILES_PER_SIDE * 2 + 1:
		for i in ParkTerrain.TILES_PER_SIDE * 2 + 1:
			var p := Vector2(-ParkTerrain.HALF + i * ParkTerrain.TILE_M * 0.5, -ParkTerrain.HALF + j * ParkTerrain.TILE_M * 0.5)
			if (map.play_rect as Rect2).has_point(p):
				cameras.append(p)
	var worst_verts := 0
	var worst_at := Vector2.ZERO
	var worst_draws := 0
	for p in cameras:
		var eye := Vector3(p.x, terrain.height(p.x, p.y) + CAMERA_LIFT, p.y)
		var verts: int = api.visible_vertices(chunks, eye)
		if verts > worst_verts:
			worst_verts = verts
			worst_at = p
		worst_draws = maxi(worst_draws, api.visible_batches(chunks, eye))
	print("scatter_rows_test: park visible scatter verts worst %d at %s over %d cameras; %d instances" % [worst_verts, worst_at, cameras.size(), instances])
	t.check("visible scatter vertices at most %d at the fixture's worst camera" % ScatterRows.VERTEX_BUDGET, worst_verts > 0 and worst_verts <= ScatterRows.VERTEX_BUDGET, "worst %d at %s" % [worst_verts, worst_at])

	# Draws: the merged MultiMesh count against the probe's unmerged shape (reported; KB6 gates 1.3x).
	var probe := probe_cells.size()
	print("scatter_rows_test: park draws %d MultiMeshes (worst camera %d visible) vs %d probe-shape scatter nodes, ratio %.4f"
		% [batches, worst_draws, probe, float(batches) / maxf(1.0, float(probe))])
	t.check("the merged chunks draw fewer batches than the probe's unmerged chunks", batches > 0 and batches < probe, "%d vs %d" % [batches, probe])
	holder.free()


static func _key(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)]
