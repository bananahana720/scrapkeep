# smoke: solo timeout=300s (builds the chunked scatter for three parks; 115 s alone at load 5 on 2026-10-22, killed at the 180 s default cap on head fbd7f110 and base e83a21c2 in a width-2 fast lane)
extends SceneTree

const T := preload("res://tests/support/t.gd")
const ScatterRows := preload("res://src/world/scatter_rows.gd")
const Scatter := preload("res://src/world/scatter.gd")
const Palette := preload("res://src/core/palette.gd")
# The sanctioned clock: the wall clock unless a bot run sets SimClock.ticks; this test never sets it.
const SimClock := preload("res://src/core/sim_clock.gd")
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
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkStamps := preload("res://src/world/park/park_stamps.gd")
const PinHash := preload("res://tests/support/pin_hash.gd")
const AppShell := preload("res://src/core/app_shell.gd")

# Every old-map scatter transform (kind, seed, instance buffer, maps sorted) is pinned in OLD_MAPS_PIN through
# tests/support/pin_hash.gd. A change there moves an old map's scatter. Until 16 Nov 2026 this was a SHA-256 of the
# exact buffers, which needed one value per maths library (a57519e6 on the cloud lanes, 5bdc8fba on Andrew's Arch PC,
# a third on the Mac); the pin rounds the floats so one pin holds on all of them. Record with PIN_RECORD=1.
const OLD_MAPS_PIN := "res://tests/fixtures/pins/scatter_old_maps.pin"
# The rows that pin covers: Dig 4, Dig Deep 4, Spillway 4 (a missing batch must not pass).
const OLD_MAPS_ROWS := 12
const PARK_TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_test"}]}
const FRAME_CAP_USEC := 8000
# The wait for a threaded build is a wall-clock deadline, not a frame count: on a loaded box the workers starve
# while frames come fast and empty, so a frame cap runs out before the build does. A real hang still fails, after 120 s.
const BUILD_WAIT_MSEC := 120000
# The P-ADDON probe's unmerged scatter: Proton Scatter chunks of 15 m, one node per row per chunk
# (artifacts/local/alpha/push/w12/probes/addon/REPORT.md:71), the shape that read draws 2.06 times.
const PROBE_CHUNK_M := 15.0
const CAMERA_LIFT := 2.0

var t := T.new("scatter_rows_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# The park section runs first, so the process's resource cache holds none of what the build reads.
	await _park_chunks()
	_plain_slopes()
	await _lane_scatter()
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

	var old_maps := _old_maps()
	print("scatter_rows_test: old-map scatter rounding margin %.2f" % PinHash.margin(old_maps))
	var pin_error := PinHash.check(OLD_MAPS_PIN, old_maps)
	t.check("the old maps' scatter transforms match their pin", pin_error.is_empty(), pin_error)

	quit(t.verdict())


# Every old map with scatter rows, built alone through terrain.gd as the game builds it; each batch's
# kind, seed and submitted instance buffer, maps sorted, rows in table order.
func _old_maps() -> Array:
	var pinned := []
	var ids: Array = Terrain.MAPS.keys()
	ids.sort()
	var hashed := 0
	# SCATTER_DUMP=<file> writes every row's output as text (map, row seed, mesh aabb, instance count,
	# then one line per instance: 12 buffer floats at full precision, in buffer order) so two machines'
	# runs can be diffed with tools/scatter_dump_diff.py.
	var dump_path := OS.get_environment("SCATTER_DUMP")
	var dump := PackedStringArray()
	for map_id: String in ids:
		var rows: Array = Terrain.MAPS[map_id].new().scatter["kit"]
		if rows.is_empty():
			continue
		var holder := Node3D.new()
		root.add_child(holder)
		var terrain := Terrain.new({"DEFS": [{"stage": 1, "world": 1, "map": map_id}]})
		terrain.build(holder)
		var scatter := terrain.geometry_root(1).get_node_or_null("GroundScatter")
		pinned.append(map_id)
		for row: Dictionary in rows:
			var batch: Node = scatter.get_node_or_null("Scatter_%s" % row["seed"]) if scatter != null else null
			pinned.append([row["kind"], row["seed"]])
			if batch != null:
				var buffer: PackedFloat32Array = batch.get_meta("instance_buffer")
				pinned.append(buffer)
				hashed += 1
				if dump_path != "":
					var aabb: AABB = Scatter._source(row["mesh"]).get("aabb", AABB())
					dump.append("row %s %s mesh=%s aabb=%.9f,%.9f,%.9f,%.9f,%.9f,%.9f count=%d" % [map_id, row["seed"], row["mesh"],
						aabb.position.x, aabb.position.y, aabb.position.z, aabb.size.x, aabb.size.y, aabb.size.z, buffer.size() / 12])
					for i in buffer.size() / 12:
						var cells := PackedStringArray()
						for k in 12:
							cells.append("%.9f" % buffer[i * 12 + k])
						dump.append(" ".join(cells))
		holder.free()
	t.eq("the old-map hash covers every old scatter row", hashed, OLD_MAPS_ROWS)
	if dump_path != "":
		var out := FileAccess.open(dump_path, FileAccess.WRITE)
		out.store_string("\n".join(dump) + "\n")
		out.close()
		print("scatter_rows_test: dumped ", dump.size(), " lines to ", dump_path)
	return pinned


# The park fixture (park_test, KB4's bake): its stage built through terrain.gd, then its scatter
# built in chunks by terrain.gd's own hook (KB5b), on worker threads, pumped frame by frame as the
# game would. The fixture's kit is PARK_KIT plus a second rock row (same mesh and slot, other density
# and size) so the per-kind merge is observable: unmerged, a chunk holds two rock batches.
const BIG_ROCK := {"kind": "rock", "density": 0.3, "scale": Vector2(0.9, 1.5), "slope": 0.8, "bury": 0.35, "seed": "scatter_park_rock_big", "mesh": "kit:rubble", "slot": "stone"}
const STRUT := "res://assets/models/dig_mechanical/strut_bent.glb"


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
	var fixture_kit: Array = park_kit.duplicate()
	fixture_kit.append(BIG_ROCK)
	t.check("the park kit rows give one mesh and slot per kind", (rows_api.kind_problems(park_kit) as Array).is_empty(), str(rows_api.kind_problems(park_kit)))
	t.check("the fixture kit still gives one mesh and slot per kind", (rows_api.kind_problems(fixture_kit) as Array).is_empty(), str(rows_api.kind_problems(fixture_kit)))
	var rock_rows := fixture_kit.filter(func(r: Dictionary) -> bool: return r["kind"] == "rock")
	t.check("the fixture carries two rows of one kind, same mesh and slot, other density and size", rock_rows.size() >= 2 and rock_rows[0]["mesh"] == rock_rows[1]["mesh"] and rock_rows[0]["slot"] == rock_rows[1]["slot"] and rock_rows[0]["density"] != rock_rows[1]["density"] and rock_rows[0]["scale"] != rock_rows[1]["scale"])
	t.check("a table with two meshes under one kind is refused", not (rows_api.kind_problems([
		{"kind": "rock", "mesh": "kit:rubble", "slot": "stone"}, {"kind": "rock", "mesh": "kit:pebble", "slot": "stone"}]) as Array).is_empty())

	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	var terrain = Terrain.new(PARK_TABLE)
	var map = terrain.map_for(1)
	map.scatter["kit"] = fixture_kit
	# Cold run: this section runs first, so the process holds none of what the build reads; the strut glb
	# is also requested with the cache bypassed, so it is cold on every run.
	var stone_path := String(Palette.SLOT_TABLE.row("stone").get("path", ""))
	t.check("the cold run: neither the strut glb nor the stone material is in the resource cache yet", not ResourceLoader.has_cached(STRUT) and not ResourceLoader.has_cached(stone_path), "strut %s, stone %s" % [ResourceLoader.has_cached(STRUT), ResourceLoader.has_cached(stone_path)])
	terrain.build(holder)
	terrain.use(1)
	var stage_root: Node3D = terrain.geometry_root(1)
	var ground: Callable = terrain.ground_callable(1)
	var chunks: Node3D = stage_root.get_node_or_null("GroundScatter")
	if not t.check("terrain.gd built the stage's chunked scatter (no shim)", chunks != null and chunks.has_method("is_ready")):
		holder.free()
		return
	t.check("the chunked build starts on worker threads", not chunks.is_ready())
	var frames := 0
	var wait0 := SimClock.msec()
	var deadline := wait0 + BUILD_WAIT_MSEC
	while chunks != null and not chunks.is_ready() and SimClock.msec() < deadline:
		await process_frame
		frames += 1
	if not t.check("the park scatter finished building", chunks != null and chunks.is_ready(), "%d frames" % frames):
		holder.free()
		return
	var slowest_ms: float = chunks.slowest_chunk_usec / 1000.0
	print("scatter_rows_test: park scatter build wall %d ms (deadline %d ms)" % [SimClock.msec() - wait0, BUILD_WAIT_MSEC])
	print("scatter_rows_test: park scatter built over %d frames, %d chunks on worker threads, start() work %.2f ms (wall-clock %.2f ms), slowest main-thread chunk step %.2f ms, worst frame %.2f ms"
		% [frames, chunks.worker_chunks, chunks.start_work_usec / 1000.0, chunks.start_usec / 1000.0, slowest_ms, chunks.frame_usec_max / 1000.0])
	t.check("the build spanned frames", frames > 1, "%d frames" % frames)
	t.eq("every chunk was built off the main thread", chunks.worker_chunks, ParkTerrain.TILE_COUNT)
	t.eq("the stage root holds all 100 chunks", chunks.get_child_count(), ParkTerrain.TILE_COUNT)
	t.check("start() is metered", chunks.start_usec > 0 and chunks.slowest_usec >= chunks.start_usec, "%d usec" % chunks.start_usec)
	# The glb source is requested on the loader thread with the cache bypassed, so the main thread never
	# loads it and the build is cold whatever the process has cached (KB5's receipt ran warm). Headless (the
	# dummy rasterizer, whose mesh RID owner is not thread-safe) the sources load on the main thread instead.
	if not AppShell.headless():
		t.eq("the glb mesh sources load on the loader thread, not the main thread", chunks.get("threaded_loads"), 1)
		t.check("the slot materials that are resources load on the loader thread", int(chunks.get("threaded_materials")) >= 1, str(chunks.get("threaded_materials")))
	else:
		t.eq("headless, no glb source loads on the loader thread", chunks.get("threaded_loads"), 0)
		t.eq("headless, no slot material loads on the loader thread", chunks.get("threaded_materials"), 0)
		var glb_kinds := []
		for row: Dictionary in Scatter.park_rows(map):
			if String(row["mesh"]).begins_with("glb:") and not glb_kinds.has(row["kind"]):
				glb_kinds.append(row["kind"])
		var glb_views := 0
		for view: MultiMeshInstance3D in chunks.find_children("*", "MultiMeshInstance3D", true, false):
			if glb_kinds.has(view.get_meta("kind")) and view.multimesh.mesh != null:
				glb_views += 1
		t.check("headless, the glb sources still load (main thread) and their kinds are scattered", not glb_kinds.is_empty() and glb_views > 0, "%d batches of %s" % [glb_views, glb_kinds])
	# start_work_usec is the groups loop and launch, timed on the wall clock apart from start_usec; a heavily
	# preempted main thread can still read it high, so it is the first (guarded) build's figure alone.
	t.check("start()'s own work (groups loop and launch, not its wall-clock) is under 8 ms", chunks.start_work_usec > 0 and chunks.start_work_usec < FRAME_CAP_USEC, "%.2f ms work, %.2f ms wall-clock" % [chunks.start_work_usec / 1000.0, chunks.start_usec / 1000.0])
	t.check("no main-thread scatter chunk step over 8 ms during the build (start() excluded)", chunks.slowest_chunk_usec > 0 and chunks.slowest_chunk_usec < FRAME_CAP_USEC, "%.2f ms" % slowest_ms)

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
	# The merge: each chunk's rock batch holds the pieces of every rock row, and only one rock batch stands.
	var merge_errors := []
	var merged_chunks := 0
	var rock_source: Dictionary = Scatter._source(rock_rows[0]["mesh"])
	for chunk: Node in chunks.get_children():
		var cparts := String(chunk.name).trim_prefix("Chunk").split("_")
		var expect := 0
		var rows_present := 0
		for row: Dictionary in rock_rows:
			var n: int = Scatter.chunk_transforms(row, map, ground, rock_source["aabb"], int(cparts[0]), int(cparts[1]), []).size()
			expect += n
			rows_present += 1 if n > 0 else 0
		var rocks := chunk.get_children().filter(func(b: Node) -> bool: return b.get_meta("kind", "") == "rock")
		if rocks.size() != (1 if expect > 0 else 0):
			merge_errors.append("%s has %d rock batches" % [chunk.name, rocks.size()])
		elif expect > 0 and (rocks[0] as MultiMeshInstance3D).multimesh.instance_count != expect:
			merge_errors.append("%s rock batch holds %d of %d" % [chunk.name, (rocks[0] as MultiMeshInstance3D).multimesh.instance_count, expect])
		elif rows_present >= 2:
			merged_chunks += 1
	t.check("each chunk's rock rows merge into one batch holding every row's pieces", merge_errors.is_empty() and merged_chunks > 0, "%d chunks merged two rows; %s" % [merged_chunks, ", ".join(merge_errors.slice(0, 6))])
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


# "Ride lips only" (Andrew, 2026-10-17 06:16Z) and "Edges are ground" (22:29Z): on every park map the stage table
# uses, a stamped plain slope (ParkMap.plain_slope, the placeholder gate's isPlainSlope) or mesa edge (ParkMap.mesa_edge)
# is not in keep_out and gets scatter inside its footprint, while every other built footprint but the ground stays
# clear; a plain slope left bare has a built piece over it. Placed on flat ground, so each row's whole footprint is in
# reach; on the real stamp the slope rule still keeps pieces off the steep faces.
func _plain_slopes() -> void:
	var flat := func(x: float, z: float, _r: float) -> Vector3: return Vector3(x, 0.0, z)
	var maps := {}
	for def: Dictionary in ParkDefs.DEFS:
		maps[String(def["map"])] = true
	var plain_total := 0
	var edges := 0
	var problems := []
	for map_id: String in maps:
		var map = ParkMap.new("res://src/world/park/%s.json" % map_id)
		if not map.ok:
			problems.append("%s fails its schema" % map_id)
			continue
		var kept := {}
		for f: Dictionary in map.scatter["keep_out"]:
			kept[f["id"]] = f
		var plain := []
		var built := []
		for row: Dictionary in map.park["park_rows"]:
			if ParkMap.mesa_edge(row, map.play_rect):
				edges += 1
			if ParkMap.plain_slope(row) or ParkMap.mesa_edge(row, map.play_rect):
				plain.append(row)
				if kept.has(row["id"]):
					problems.append("%s/%s is a plain slope kept out" % [map_id, row["id"]])
			# 2026-10-18 (w17 fix): a scatter-dressed row (recipe "scatter", #114's cinder_cone) is dressed by
			# the scatter, so park_map.gd keeps it out of keep_out; it is neither plain nor built here.
			elif row["element"] != "ground" and row["recipe"] != ParkRecipes.SCATTER_DRESSED:
				built.append(row)
				if not kept.has(row["id"]):
					problems.append("%s/%s is built but not kept out" % [map_id, row["id"]])
		plain_total += plain.size()
		if plain.is_empty():
			continue
		# The chunks under the plain slopes' centres, every kit row.
		var cells := {}
		for row: Dictionary in plain:
			var at: Vector2 = ParkMap._v2(row["at"])
			cells[Vector2i(floori((at.x + ParkTerrain.HALF) / ParkTerrain.TILE_M), floori((at.y + ParkTerrain.HALF) / ParkTerrain.TILE_M))] = true
		var on_plain := {}
		var on_built := 0
		for row: Dictionary in ScatterRows.PARK_KIT:
			var aabb: AABB = Scatter._source(row["mesh"])["aabb"]
			for cell: Vector2i in cells:
				for xf: Transform3D in Scatter.chunk_transforms(row, map, flat, aabb, cell.x, cell.y, []):
					var p := Vector2(xf.origin.x, xf.origin.z)
					for slope: Dictionary in plain:
						if ParkMap.footprint_contains(slope, p):
							on_plain[slope["id"]] = true
					for b: Dictionary in built:
						if Scatter._kept_out([kept[b["id"]]], p):
							on_built += 1
		print("scatter_rows_test: %s has scatter on %d of %d stamped plain slopes and mesa edges" % [map_id, on_plain.size(), plain.size()])
		# A plain slope with no scatter is one a built piece stands on (a half-pipe in a drop, an anchor field on a
		# bank), so its centre is kept out by that piece.
		for row: Dictionary in plain:
			# The scatter dresses the play rect only, so a mesa edge standing wholly outside it (the dam's canyon walls
			# east, west and south) carries none.
			var box := ParkStamps.bounds(ParkStamps.frame(row))
			if not Rect2(box[0], box[1], box[2] - box[0], box[3] - box[1]).intersects(map.play_rect):
				continue
			if not on_plain.has(row["id"]) and not Scatter._kept_out(map.scatter["keep_out"], ParkMap._v2(row["at"])):
				problems.append("%s/%s has no scatter and nothing built on it" % [map_id, row["id"]])
		if on_built > 0:
			problems.append("%s %d pieces inside built footprints" % [map_id, on_built])
	print("scatter_rows_test: %d stamped plain slopes and mesa edges over the stage table's parks" % plain_total)
	t.check("scatter lands on the stamped plain slopes and stays out of every other built footprint", plain_total > 0 and problems.is_empty(), ", ".join(problems.slice(0, 8)))
	var fixture = ParkMap.new()
	var lip: Array = fixture.park["park_rows"].filter(func(r: Dictionary) -> bool: return r["element"] == "kicker")
	t.check("the Highdraft carries mesa edges and an ordinary kicker is not one", edges > 0 and not lip.is_empty()
		and not lip.any(func(r: Dictionary) -> bool: return ParkMap.mesa_edge(r, fixture.play_rect)), "%d edges" % edges)


# Ruling 5, 2026-10-19 (issue #149) and the #241 ruling, option (c): a kit row that can stand more than
# Scatter.LANE_BAND_M above the ground keeps every piece whose centre is in the park's lane mask (park_map.gd build_lane_mask,
# the graph's LINE nodes), sunk so its highest box corner is at most the band above the ground under that corner. Pieces
# outside the mask, flat rows and off-line scatter are unchanged. Run over every chunk that holds a mask cell, with and
# without the mask (passed as the production path does, the `lane` argument), on flat ground and on a tilted, rolling one; then a threaded build is compared with a
# main-thread one on a real park.
func _lane_scatter() -> void:
	var grounds := {
		"flat": func(x: float, z: float, _r: float) -> Vector3: return Vector3(x, 0.0, z),
		"rolling": func(x: float, z: float, _r: float) -> Vector3: return Vector3(x, 0.45 * x + 0.8 * sin(z * 0.7) + 0.5 * cos(x * 1.3), z),
	}
	# The park kit has no flat kind (every kind can pass the band), so a pebble row at a tenth of a metre stands in.
	var flat_row := {"kind": "pebble", "density": 3.0, "scale": Vector2(0.04, 0.1), "slope": 0.8, "bury": 0.3, "seed": "scatter_lane_flat", "mesh": "kit:pebble", "slot": "stone"}
	var rows: Array = ScatterRows.PARK_KIT.duplicate()
	rows.append(flat_row)
	var problems := []
	var tall_kinds := []
	var flat_kept := 0
	for row: Dictionary in rows:
		var aabb: AABB = Scatter._source(row["mesh"])["aabb"]
		if Scatter.is_tall(row, aabb):
			tall_kinds.append(row["kind"])
		print("scatter_rows_test: lane band, %s top bound %.3f m, %s" % [row["kind"], Scatter.top_bound(row, aabb), "tall" if Scatter.is_tall(row, aabb) else "not tall"])
	t.check("the fixture pebble row is under the band", not Scatter.is_tall(flat_row, Scatter._source("kit:pebble")["aabb"]))
	t.check("the lane band tells tall kit kinds from flat ones, and some are tall", not tall_kinds.is_empty(), str(tall_kinds))
	var checked := 0
	var over_total := 0
	var max_corner := -INF
	var masked_parks := 0
	for map_id: String in ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]:
		var map = ParkMap.new("res://src/world/park/%s.json" % map_id)
		if not map.ok:
			problems.append("%s fails its schema" % map_id)
			continue
		# The mask is made as scatter.gd's chunked build makes it (park_map.gd lane_mask_for).
		var graph = ParkGraph.read(ParkMap.graph_path_for(map.path))
		var mask: Dictionary = ParkMap.build_lane_mask(graph, map.park, map_id)
		if mask.is_empty():
			problems.append("%s has no lane mask" % map_id)
			continue
		masked_parks += 1
		var cells := {}
		var mask_cells := 0
		var side: int = mask["side"]
		for n in side * side:
			if (mask["cells"] as PackedByteArray)[n] != 0:
				mask_cells += 1
				var x: float = -float(mask["half"]) + float(mask["step"]) * (n % side)
				var z: float = -float(mask["half"]) + float(mask["step"]) * (n / side)
				var home := Vector2i(clampi(floori((x + ParkTerrain.HALF) / ParkTerrain.TILE_M), 0, ParkTerrain.TILES_PER_SIDE - 1), clampi(floori((z + ParkTerrain.HALF) / ParkTerrain.TILE_M), 0, ParkTerrain.TILES_PER_SIDE - 1))
				# The chunk and its 8 neighbours: a piece's origin can sit across a chunk edge from its draw.
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						var nb := home + Vector2i(dx, dz)
						if nb.x >= 0 and nb.y >= 0 and nb.x < ParkTerrain.TILES_PER_SIDE and nb.y < ParkTerrain.TILES_PER_SIDE:
							cells[nb] = true
		var report := []
		var park_checked := 0
		var park_over := 0
		var flat_sunk := 0
		for ground_name: String in grounds:
			var ground: Callable = grounds[ground_name]
			var g_checked := 0
			var g_over := 0
			for row: Dictionary in rows:
				var aabb: AABB = Scatter._source(row["mesh"])["aabb"]
				var tall := Scatter.is_tall(row, aabb)
				var in_lane := 0
				var changed := 0
				var worst := -INF
				for cell: Vector2i in cells:
					var free: Array[Transform3D] = Scatter.chunk_transforms(row, map, ground, aabb, cell.x, cell.y, [])
					var kept: Array[Transform3D] = Scatter.chunk_transforms(row, map, ground, aabb, cell.x, cell.y, [], mask)
					if free.size() != kept.size():
						problems.append("%s %s %s: %d pieces became %d" % [map_id, ground_name, row["kind"], free.size(), kept.size()])
						continue
					for i in free.size():
						var inside := Scatter._in_lane(mask, free[i].origin.x, free[i].origin.z)
						if not inside or not tall:
							if free[i] != kept[i]:
								changed += 1
							if inside:
								in_lane += 1
							continue
						in_lane += 1
						var before := -INF
						for k in 8:
							var c0: Vector3 = free[i] * aabb.get_endpoint(k)
							before = maxf(before, c0.y - (ground.call(c0.x, c0.z, 0.0) as Vector3).y)
						if before > Scatter.LANE_BAND_M + 1e-4:
							g_over += 1
						for k in 8:
							var corner: Vector3 = kept[i] * aabb.get_endpoint(k)
							worst = maxf(worst, corner.y - (ground.call(corner.x, corner.z, 0.0) as Vector3).y)
						# Sunk straight down: the same spot, the same lean, the same size.
						if not (kept[i].basis.is_equal_approx(free[i].basis) and is_equal_approx(kept[i].origin.x, free[i].origin.x) and is_equal_approx(kept[i].origin.z, free[i].origin.z) and kept[i].origin.y <= free[i].origin.y + 1e-5):
							changed += 1
						g_checked += 1
				if tall:
					max_corner = maxf(max_corner, worst)
					if worst > Scatter.LANE_BAND_M + 1e-4:
						problems.append("%s %s %s stands %.4f m above its ground on the line" % [map_id, ground_name, row["kind"], worst])
				else:
					flat_kept += in_lane
				if changed > 0:
					problems.append("%s %s %s: %d pieces changed that should not have" % [map_id, ground_name, row["kind"], changed])
			if ground_name == "flat":
				flat_sunk = g_checked
			report.append("%s: %d tall pieces sunk, %d over the band before the sink" % [ground_name, g_checked, g_over])
			park_checked += g_checked
			park_over += g_over
		# All the park's tall pieces on flat ground, for the share the line sinks.
		var tall_all := 0
		for row: Dictionary in rows:
			var aabb2: AABB = Scatter._source(row["mesh"])["aabb"]
			if row == flat_row or not Scatter.is_tall(row, aabb2):
				continue
			for ci in 10:
				for cj in 10:
					tall_all += Scatter.chunk_transforms(row, map, grounds["flat"], aabb2, ci, cj, []).size()
		report.append("flat share sunk %.1f%% of %d tall pieces" % [100.0 * float(flat_sunk) / maxf(1.0, float(tall_all)), tall_all])
		checked += park_checked
		over_total += park_over
		print("scatter_rows_test: %s lane mask %d of %d cells, %d chunks; %s" % [map_id, mask_cells, side * side, cells.size(), "; ".join(report)])
		if map_id == "park_dam":
			_lane_mask_shape(map, graph, mask)
		if map_id == "park_sinkhole":
			_lane_square_row(map, graph, mask)
	t.check("every tall piece on the line is sunk to the band, none dropped, all else unchanged", problems.is_empty(), ", ".join(problems.slice(0, 8)))
	print("scatter_rows_test: lane band, %d tall pieces on the line checked, %d over the band before the sink, max corner height %.4f m" % [checked, over_total, max_corner])
	t.check("all six parks have a lane mask", masked_parks == 6, str(masked_parks))
	t.check("tall pieces were checked on the line", checked > 0, str(checked))
	t.check("some pieces stood over the band before the sink (the negative)", over_total > 0, str(over_total))
	t.check("a flat row still lands on the line, unchanged", flat_kept > 0, str(flat_kept))
	await _lane_threads()


# A routed grind chord, a routed kicker's ends: park_dam's `canal_lips` and `shelf_lip` sit in the mask.
func _lane_mask_shape(map, graph, mask: Dictionary) -> void:
	var rows := {}
	for row: Dictionary in map.park["park_rows"]:
		rows[row["id"]] = row
	var lips: Vector2 = ParkMap._v2(rows["canal_lips"]["at"])
	t.check("a routed grind row's chord midpoint is in the mask (dam canal_lips)", Scatter._in_lane(mask, lips.x, lips.y), str(lips))
	var ends := 0
	var marked := 0
	for a in ParkGraph.SIDE * ParkGraph.SIDE:
		for e in range(graph.off[a], graph.off[a + 1]):
			if graph.ride[e] >= 0 and graph.names[graph.ride[e]] == "shelf_lip":
				for end in [a, graph.to[e]]:
					if end < ParkGraph.SIDE * ParkGraph.SIDE:
						ends += 1
						if Scatter._in_lane(mask, graph.px[end], graph.pz[end]):
							marked += 1
	t.check("a routed kicker's ground ends are in the mask (dam shelf_lip)", ends > 0 and marked == ends, "%d of %d" % [marked, ends])
	# LINE alone may already cover those points, so the ride edges and chords must add cells of their own.
	var bare: Dictionary = map.park.duplicate(false)
	bare["routes"] = []
	var line_only := ParkMap.build_lane_mask(graph, bare, "park_dam")
	var line_cells := 0
	var all_cells := 0
	for n in (mask["cells"] as PackedByteArray).size():
		line_cells += int(line_only["cells"][n] != 0)
		all_cells += int(mask["cells"][n] != 0)
	t.check("routed ride edges and chords add cells beyond LINE (dam, routes emptied)", all_cells > line_cells, "%d vs %d" % [all_cells, line_cells])


# A square routed row adds nothing beyond LINE and the ride edges: park_sinkhole's cinder_cone, taken out of the park
# data, leaves the mask as it was.
func _lane_square_row(map, graph, mask: Dictionary) -> void:
	var trimmed: Dictionary = map.park.duplicate(false)
	trimmed["park_rows"] = (map.park["park_rows"] as Array).filter(func(r: Dictionary) -> bool: return r["id"] != "cinder_cone")
	var without := ParkMap.build_lane_mask(graph, trimmed, "park_sinkhole")
	t.check("a square routed row adds no cells to the mask (sinkhole cinder_cone)", (map.park["park_rows"] as Array).size() == trimmed["park_rows"].size() + 1 and without["cells"] == mask["cells"])


# A threaded and a main-thread chunked build of one real park (its mask is not empty) give the same buffers.
func _lane_threads() -> void:
	var map = ParkMap.new("res://src/world/park/park_sinkhole.json")
	var flat := func(x: float, z: float, _r: float) -> Vector3: return Vector3(x, 0.0, z)
	var holder := Node3D.new()
	root.add_child(holder)
	var main_node: Node3D = Scatter.build_chunked(holder, map, flat, false)
	var thread_node: Node3D = Scatter.build_chunked(holder, map, flat, true)
	var frames := 0
	var wait0 := SimClock.msec()
	var deadline := wait0 + BUILD_WAIT_MSEC
	while not thread_node.is_ready() and SimClock.msec() < deadline:
		await process_frame
		frames += 1
	print("scatter_rows_test: park_sinkhole threaded build wall %d ms over %d frames (deadline %d ms)" % [SimClock.msec() - wait0, frames, BUILD_WAIT_MSEC])
	var differ := 0
	var batches := 0
	for chunk: Node in main_node.get_children():
		var twin := thread_node.get_node_or_null(NodePath(chunk.name))
		if twin == null or twin.get_child_count() != chunk.get_child_count():
			differ += 1
			continue
		for i in chunk.get_child_count():
			batches += 1
			if (chunk.get_child(i).get_meta("instance_buffer") as PackedFloat32Array) != (twin.get_child(i).get_meta("instance_buffer") as PackedFloat32Array):
				differ += 1
	t.check("the chunked build made the lane mask itself, in a worker job before the chunks read it", not (thread_node.get("lane_mask") as Dictionary).is_empty() and thread_node.get("lane_mask") == main_node.get("lane_mask"))
	t.check("a threaded and a main-thread build of park_sinkhole give identical buffers", thread_node.is_ready() and batches > 0 and differ == 0, "%d batches, %d differ" % [batches, differ])
	holder.free()


static func _key(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)]
