extends RefCounted

# Seeded ground scatter: one MultiMeshInstance3D per row of the map's `scatter["kit"]` table, placed
# inside the play rect on ground no steeper than the row's slope, partly buried, clear of the spawn,
# the beacon and the vault. Presentation only: no body, no shape, no global random draw. Each row owns
# a private RandomNumberGenerator seeded from its seed name, so two builds give identical transforms.
# Pieces stand on the ground layer (the height callable), never on a collider that sits above it.
# The batches are not registered as scenery: a visibility range is measured to a batch's bounds
# centre, and a map-wide batch would vanish whole (set_dressing.gd, _batch).

const AppShell := preload("res://src/core/app_shell.gd")
const ScatterRows := preload("res://src/world/scatter_rows.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const Palette := preload("res://src/core/palette.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")

# A dropped cable coil (W1-23, was a torus): a tube of COIL_TUBE radius wound COIL_TURNS times about its
# centre, each loop a little tighter and higher than the last, its end trailing off straight. COIL_STEPS samples a turn and
# COIL_SIDES rings the tube, so it costs about what the torus did.
const COIL_RADIUS := 0.38
const COIL_TUBE := 0.06
const COIL_TURNS := 2.0
const COIL_STEPS := 8
const COIL_SIDES := 5
const SLOPE_PROBE := 1.0
const FLOATS := 12
# The ghost-solid lane band (#183): a thing the ride line can touch that stands more than this above the ground
# is solid to the rider, and the kit has no collider, so a tall row's pieces on the line are sunk to the band (ruling 5, 2026-10-19; the lane is the graph's LINE mask).
const LANE_BAND_M := 0.12


# ground: (x, z, clearance) -> Vector3 on the drawn ground (terrain.gd _relief_at or _ground_at).
static func build(parent: Node3D, map, ground: Callable) -> Node3D:
	var holder := Node3D.new()
	holder.name = "GroundScatter"
	for row: Dictionary in map.scatter["kit"]:
		var source := _source(row["mesh"])
		if source.is_empty():
			push_warning("scatter: %s has no mesh, the row stays out" % row["mesh"])
			continue
		var xfs := transforms(row, map, ground, source["aabb"])
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = source["mesh"]
		multi.instance_count = xfs.size()
		var buffer := PackedFloat32Array()
		buffer.resize(xfs.size() * FLOATS)
		var origins := PackedVector3Array()
		for i in xfs.size():
			var tr: Transform3D = xfs[i] * (source["local"] as Transform3D)
			var at := i * FLOATS
			buffer[at] = tr.basis.x.x
			buffer[at + 1] = tr.basis.y.x
			buffer[at + 2] = tr.basis.z.x
			buffer[at + 3] = tr.origin.x
			buffer[at + 4] = tr.basis.x.y
			buffer[at + 5] = tr.basis.y.y
			buffer[at + 6] = tr.basis.z.y
			buffer[at + 7] = tr.origin.y
			buffer[at + 8] = tr.basis.x.z
			buffer[at + 9] = tr.basis.y.z
			buffer[at + 10] = tr.basis.z.z
			buffer[at + 11] = tr.origin.z
			origins.append(xfs[i].origin)
		multi.buffer = buffer
		var view := MultiMeshInstance3D.new()
		view.name = "Scatter_%s" % row["seed"]
		view.multimesh = multi
		# The headless dummy server has no readback, so the submitted buffer is kept for tests.
		view.set_meta("instance_buffer", buffer)
		view.set_meta("origins", origins)
		view.set_meta("verts_per_instance", source["verts"])
		view.material_override = Palette.slot_material(row["slot"])
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(view)
	parent.add_child(holder)
	return holder


static func transforms(row: Dictionary, map, ground: Callable, aabb: AABB) -> Array[Transform3D]:
	var rect: Rect2 = map.play_rect
	var clear: Dictionary = map.scatter["clear"]
	var keeps := [[map.spawn, float(clear["spawn"])], [map.beacon, float(clear["beacon"])], [map.vault, float(clear["vault"])]]
	var rng := RandomNumberGenerator.new()
	rng.seed = String(row["seed"]).hash()
	var count := int(float(row["density"]) * rect.get_area() / 100.0)
	var scale_range: Vector2 = row["scale"]
	var out: Array[Transform3D] = []
	for i in count:
		var x := rng.randf_range(rect.position.x, rect.end.x)
		var z := rng.randf_range(rect.position.y, rect.end.y)
		var yaw := rng.randf_range(0.0, TAU)
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var tilt := rng.randf_range(-0.25, 0.25)
		if _kept_clear(keeps, Vector2(x, z)):
			continue
		_stand(row, ground, aabb, x, z, yaw, s, tilt, out, [])
	return out


# One piece at (x, z) on the ground layer, leaned to its normal and sunk by its bury share; none on
# ground steeper than the row's slope. grounds gets the ground point under each piece kept.
static func _stand(row: Dictionary, ground: Callable, aabb: AABB, x: float, z: float, yaw: float, s: float, tilt: float, out: Array[Transform3D], grounds: Array) -> void:
	var at: Vector3 = ground.call(x, z, 0.0)
	var dx: float = (ground.call(x + SLOPE_PROBE, z, 0.0) as Vector3).y - (ground.call(x - SLOPE_PROBE, z, 0.0) as Vector3).y
	var dz: float = (ground.call(x, z + SLOPE_PROBE, 0.0) as Vector3).y - (ground.call(x, z - SLOPE_PROBE, 0.0) as Vector3).y
	var normal := Vector3(-dx, 2.0 * SLOPE_PROBE, -dz).normalized()
	if normal.y < float(row["slope"]):
		return
	var basis := _lean(normal) * Basis(Vector3.RIGHT, tilt) * Basis(Vector3.UP, yaw)
	var sink := (aabb.position.y + aabb.size.y * float(row["bury"])) * s
	out.append(Transform3D(basis.scaled(Vector3.ONE * s), at - normal * sink))
	grounds.append(at)


# The highest a piece of the row can stand above the ground at its foot, an upper bound: the source box's corners
# at the row's top scale, sunk by the bury share, swung through the steepest lean the slope floor allows plus the
# tilt (+-0.25 rad), taking each corner at its highest angle.
static func top_bound(row: Dictionary, aabb: AABB) -> float:
	var slope := float(row["slope"])
	var swing := acos(clampf(slope, 0.0, 1.0)) + 0.25
	var s: float = (row["scale"] as Vector2).y
	var sink := (aabb.position.y + aabb.size.y * float(row["bury"])) * s
	var best := -INF
	for i in 8:
		var c := aabb.get_endpoint(i)
		var r := Vector2(c.x, c.z).length()
		var h := maxf(c.y, c.y * cos(swing) + r * sin(swing))
		var peak := atan2(r, c.y)
		if c.y > 0.0 and peak <= swing:
			h = Vector2(r, c.y).length()
		best = maxf(best, h)
	return best * s - sink * (minf(slope, 1.0) if sink > 0.0 else 1.0)


static func is_tall(row: Dictionary, aabb: AABB) -> bool:
	return top_bound(row, aabb) > LANE_BAND_M


static func _kept_clear(keeps: Array, at: Vector2) -> bool:
	for keep: Array in keeps:
		if at.distance_to(keep[0] as Vector2) < float(keep[1]):
			return true
	return false


# Inside a built footprint (park_map.gd keep_out: at, size along and across the facing, yaw).
static func _kept_out(footprints: Array, at: Vector2) -> bool:
	for f: Dictionary in footprints:
		var yaw: float = f["yaw"]
		var facing := Vector2(sin(yaw), cos(yaw))
		var d: Vector2 = at - (f["at"] as Vector2)
		var size: Vector2 = f["size"]
		if absf(d.dot(facing)) <= size.x * 0.5 and absf(d.dot(Vector2(facing.y, -facing.x))) <= size.y * 0.5:
			return true
	return false


# --- Park scatter in chunks (PARK.md section 3, K-UNITS KB5). ---
#
# A park's scatter is cut into the collider's 160 m tiles (park_terrain.gd TILE_M), one chunk per
# tile, named as the tile. A chunk holds one MultiMeshInstance3D per kind (every row of a kind
# merged: ScatterRows.kind_problems), each with its kind's visibility range and its own bounds, so
# a far chunk stops drawing and the draws stay one per kind per near chunk. A chunk's pieces come
# from a generator seeded by the row's seed and the chunk, so the chunks build on worker threads in
# any order; the main thread only attaches finished chunks inside a frame budget. terrain.gd starts the
# build when a park stage's ground is done (_on_park_built). The strut glb and the resource slot
# materials (stone.tres took 80 ms cold) load on the loader thread, so no heavy load lands on a frame;
# the chunk build takes WORKERS threads at normal priority so the next stage's ground build keeps the
# rest. Pieces stand on
# the ground callable, which on a park is terrain.gd's height() source (hole floors included).

static func park_rows(map) -> Array:
	var kit: Array = map.scatter.get("kit", []) if map.get("scatter") is Dictionary else []
	return kit if not kit.is_empty() else ScatterRows.PARK_KIT


static func chunk_rect(ci: int, cj: int) -> Rect2:
	return Rect2(-ParkTerrain.HALF + ci * ParkTerrain.TILE_M, -ParkTerrain.HALF + cj * ParkTerrain.TILE_M, ParkTerrain.TILE_M, ParkTerrain.TILE_M)


# Starts a park's chunked scatter under parent (threaded: worker threads, then a few chunks a frame;
# else all at once) and returns its GroundScatter node; is_ready() and the built signal tell when
# every chunk is attached, finish() completes it on the spot.
static func build_chunked(parent: Node3D, map, ground: Callable, threaded: bool, rows: Array = []) -> Node3D:
	var node := Chunked.new()
	node.name = "GroundScatter"
	parent.add_child(node)
	node.start(map, ground, rows if not rows.is_empty() else park_rows(map), threaded)
	return node


# One row's pieces inside chunk (ci, cj): the old placement rule on the chunk's share of the play
# rect, clear of the spawn, beacon, vault and every built footprint.
static func chunk_transforms(row: Dictionary, map, ground: Callable, aabb: AABB, ci: int, cj: int, grounds: Array, lane: Dictionary = {}) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var rect: Rect2 = chunk_rect(ci, cj).intersection(map.play_rect)
	if rect.get_area() <= 0.0:
		return out
	var clear: Dictionary = map.scatter["clear"]
	var keeps := [[map.spawn, float(clear["spawn"])], [map.beacon, float(clear["beacon"])], [map.vault, float(clear["vault"])]]
	var keep_out: Array = map.scatter.get("keep_out", [])
	var tall := is_tall(row, aabb)
	# `lane` is the production path (the chunked build passes its mask); map.scatter["lane_mask"] is a fallback for tests
	# that call this directly with a mask they made.
	var lane_mask: Dictionary = (lane if not lane.is_empty() else map.scatter.get("lane_mask", {})) if tall else {}
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%s/%d_%d" % [row["seed"], ci, cj]).hash()
	var count := int(float(row["density"]) * rect.get_area() / 100.0)
	var scale_range: Vector2 = row["scale"]
	var clump: Dictionary = CLUMPS.get(String(map.get("title") if map.get("title") != null else ""), {})
	var field := _clump_field(clump)
	if not clump.is_empty():
		count = int(count / float(clump["keep"]))
	for i in count:
		var x := rng.randf_range(rect.position.x, rect.end.x)
		var z := rng.randf_range(rect.position.y, rect.end.y)
		var yaw := rng.randf_range(0.0, TAU)
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var tilt := rng.randf_range(-0.25, 0.25)
		# The far edges belong to the next chunk.
		if x >= rect.end.x or z >= rect.end.y:
			continue
		if field != null and rng.randf() > _clump_keep(clump, field, x, z):
			continue
		if _kept_clear(keeps, Vector2(x, z)) or _kept_out(keep_out, Vector2(x, z)):
			continue
		var placed := out.size()
		_stand(row, ground, aabb, x, z, yaw, s, tilt, out, grounds)
		# A tall piece on the line stays, sunk to the band (ruling 5, revised): same draws, same count. The line is read at the
		# piece's own placed origin, the point a reader of the transform sees.
		if tall and out.size() > placed and _in_lane(lane_mask, out[placed].origin.x, out[placed].origin.z):
			out[placed] = _sunk_to_band(out[placed], ground, aabb)
	return out


# A park in CLUMPS gathers its scatter into debris patches (4080 park stills, acb55972: an even sprinkle on flat
# sand reads as nothing): a candidate is kept with a chance that follows a low-frequency noise field, and the row
# draws 1 / keep times its candidates. The chance is clamped to 0..2 keep, symmetric about keep, so over the centred
# noise its mean is keep and the expected count, the vertex budget and the draws stay as they were. gain sharpens
# the patch edges.
const CLUMPS := {
	"park_dam": {"seed": 1871, "frequency": 1.0 / 70.0, "keep": 0.36, "gain": 1.6},
}


static func _clump_field(clump: Dictionary) -> FastNoiseLite:
	if clump.is_empty():
		return null
	var noise := FastNoiseLite.new()
	noise.seed = int(clump["seed"])
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = float(clump["frequency"])
	noise.fractal_octaves = 2
	return noise


# The keep chance at (x, z): the field centred on keep, scaled by gain, clamped to 0..2 keep (keep is under 0.5).
static func _clump_keep(clump: Dictionary, field: FastNoiseLite, x: float, z: float) -> float:
	var keep := float(clump["keep"])
	return clampf(keep + field.get_noise_2d(x, z) * float(clump["gain"]), 0.0, 2.0 * keep)


# Whether (x, z) falls in the cell of a LINE node of park_map.gd's lane mask (its nearest lattice node).
static func _in_lane(mask: Dictionary, x: float, z: float) -> bool:
	if mask.is_empty():
		return false
	var side: int = mask["side"]
	var step: float = mask["step"]
	var half: float = mask["half"]
	var i := clampi(roundi((x + half) / step), 0, side - 1)
	var j := clampi(roundi((z + half) / step), 0, side - 1)
	return (mask["cells"] as PackedByteArray)[j * side + i] != 0


# xf sunk straight down until its highest box corner stands at most LANE_BAND_M above the ground under that corner.
static func _sunk_to_band(xf: Transform3D, ground: Callable, aabb: AABB) -> Transform3D:
	var worst := -INF
	for i in 8:
		var c := xf * aabb.get_endpoint(i)
		worst = maxf(worst, c.y - (ground.call(c.x, c.z, 0.0) as Vector3).y)
	if worst > LANE_BAND_M:
		xf.origin.y -= worst - LANE_BAND_M
	return xf


# The visual vertices a camera at eye draws from a chunked scatter: every batch whose bounds centre
# lies inside its visibility range (the engine's measure, scatter.gd header).
static func visible_vertices(holder: Node, eye: Vector3) -> int:
	var verts := 0
	for batch: MultiMeshInstance3D in _visible(holder, eye):
		verts += batch.multimesh.instance_count * int(batch.get_meta("verts_per_instance"))
	return verts


static func visible_batches(holder: Node, eye: Vector3) -> int:
	return _visible(holder, eye).size()


static func _visible(holder: Node, eye: Vector3) -> Array[MultiMeshInstance3D]:
	var found: Array[MultiMeshInstance3D] = []
	for batch: MultiMeshInstance3D in holder.find_children("*", "MultiMeshInstance3D", true, false):
		var d := eye.distance_to((batch.get_meta("bounds") as AABB).get_center())
		if d >= batch.visibility_range_begin and (batch.visibility_range_end <= 0.0 or d <= batch.visibility_range_end):
			found.append(batch)
	return found


# The 12 floats one instance takes in a MultiMesh buffer (TRANSFORM_3D, rows of the basis then origin).
static func _pack(buffer: PackedFloat32Array, at: int, tr: Transform3D) -> void:
	buffer[at] = tr.basis.x.x
	buffer[at + 1] = tr.basis.y.x
	buffer[at + 2] = tr.basis.z.x
	buffer[at + 3] = tr.origin.x
	buffer[at + 4] = tr.basis.x.y
	buffer[at + 5] = tr.basis.y.y
	buffer[at + 6] = tr.basis.z.y
	buffer[at + 7] = tr.origin.y
	buffer[at + 8] = tr.basis.x.z
	buffer[at + 9] = tr.basis.y.z
	buffer[at + 10] = tr.basis.z.z
	buffer[at + 11] = tr.origin.z


# A chunk's batches as data, built on any thread: per kind {buffer, origins, grounds, bounds}.
static func chunk_batches(groups: Array, map, ground: Callable, ci: int, cj: int, lane_mask: Dictionary = {}) -> Array:
	var batches := []
	for group: Dictionary in groups:
		var source: Dictionary = group["source"]
		var buffer := PackedFloat32Array()
		var origins := PackedVector3Array()
		var grounds := []
		var bounds := AABB()
		var first := true
		for row: Dictionary in group["rows"]:
			var xfs := chunk_transforms(row, map, ground, source["aabb"], ci, cj, grounds, lane_mask)
			var at := buffer.size()
			buffer.resize(at + xfs.size() * FLOATS)
			for xf in xfs:
				_pack(buffer, at, xf * (source["local"] as Transform3D))
				at += FLOATS
				origins.append(xf.origin)
				var box: AABB = xf * (source["aabb"] as AABB)
				bounds = box if first else bounds.merge(box)
				first = false
		if origins.is_empty():
			continue
		batches.append({"kind": group["kind"], "buffer": buffer, "origins": origins, "grounds": grounds, "bounds": bounds})
	return batches


class Chunked extends Node3D:
	signal built

	const Self := preload("res://src/world/scatter.gd")
	const ParkMapScript := preload("res://src/world/park/park_map.gd")
	const Rows := preload("res://src/world/scatter_rows.gd")
	const Tiles := preload("res://src/world/park/park_terrain.gd")
	const Colours := preload("res://src/core/palette.gd")
	const ATTACH_BUDGET_USEC := 6000
	const CHUNKS_PER_FRAME := 8
	# Threads the chunk build may take, at normal priority: the next stage's ground build (park_terrain.gd) shares the pool.
	const WORKERS := 4

	enum Phase { IDLE, LOADING, BUILDING, ATTACHING, READY }

	var phase := Phase.IDLE
	# Chunks built on a thread other than the main one.
	var worker_chunks := 0
	# The longest main-thread step of a threaded build (start() or a _process step) and where it was, and the longest
	# whole frame while it built (park_terrain.gd's meter, PARK.md section 9).
	var slowest_usec := 0
	var slowest_step := ""
	# start()'s own main-thread cost (mesh sources, glb load), also folded into slowest_usec.
	var start_usec := 0
	# The deterministic part of start(): the group loops and _launch() when it runs inside start(). Wall-clock
	# start_usec also counts any time the OS takes the core away; this does not exclude it, but it is what the
	# test caps, next to slowest_chunk_usec (the longest _process step, START left out).
	var start_work_usec := 0
	var slowest_chunk_usec := 0
	# The park's lane mask and what it cost, made by the first chunk job (_ensure_lane_mask).
	var lane_mask := {}
	var lane_mask_usec := 0
	var _mask_done := false
	var _mask_lock := Mutex.new()
	var frame_usec_max := 0
	var _last_frame_usec := 0
	var _map: RefCounted
	var _ground: Callable
	var _groups := []
	var _results := []
	var _group := -1
	var _lock := Mutex.new()
	var _next := 0
	var _threaded := false
	# Glb sources requested on the loader thread instead of loaded here (cache bypassed).
	var threaded_loads := 0
	# Slot materials loaded on the loader thread instead of on the main thread at the first attach.
	var threaded_materials := 0

	func is_ready() -> bool:
		return phase == Phase.READY

	# The rows of a kind share one source. A threaded build requests a glb source on the loader
	# thread, cache bypassed (a glb load is the costliest step and is not for the main thread, and
	# the build is cold whatever the process has cached), and the main thread only turns the
	# loaded scene into a source in a later frame (LOADING); a kit or primitive mesh is built here.
	# Its cost lands in the stage-build frame, so it is metered as the START step.
	# Headless only, the glb and material sources load here on the main thread instead: the headless display server
	# installs the dummy rasterizer, whose mesh RID owner is not thread-safe, so a loader-thread load raced this
	# frame's kit meshes ("Attempting to initialize the wrong RID", 13 of 30 boots); ending_sequence.gd's
	# _build_crater has the same gate and its reasoning. GPU renderers keep the loader thread.
	func start(map, ground: Callable, rows: Array, threaded: bool) -> void:
		var t0 := Time.get_ticks_usec()
		var loader := threaded and not AppShell.headless()
		_map = map
		_ground = ground
		_threaded = threaded
		var work0 := Time.get_ticks_usec()
		var by_kind := {}
		for row: Dictionary in rows:
			var kind := String(row["kind"])
			if not by_kind.has(kind):
				by_kind[kind] = {"kind": kind, "spec": String(row["mesh"]), "source": {}, "slot": row["slot"], "rows": []}
				_groups.append(by_kind[kind])
			by_kind[kind]["rows"].append(row)
		for group: Dictionary in _groups:
			var spec: String = group["spec"]
			if loader and spec.begins_with("glb:") and ResourceLoader.exists(spec.trim_prefix("glb:")):
				var path := spec.trim_prefix("glb:")
				if ResourceLoader.load_threaded_request(path, "PackedScene", false, ResourceLoader.CACHE_MODE_IGNORE) == OK:
					group["path"] = path
					threaded_loads += 1
			if not group.has("path"):
				group["source"] = Self._source(spec)
			# A slot that is a material resource (stone.tres: shader and textures, 80 ms cold) loads on the
			# loader thread too; the other slots are built in code and cost well under a millisecond.
			var slot_row: Dictionary = Colours.SLOT_TABLE.row(group["slot"])
			if loader and String(slot_row.get("kind", "")) == "resource" and ResourceLoader.exists(String(slot_row["path"])):
				if ResourceLoader.load_threaded_request(String(slot_row["path"]), "Material") == OK:
					group["material_path"] = String(slot_row["path"])
					threaded_materials += 1
		_results.resize(Tiles.TILE_COUNT)
		if threaded:
			if threaded_loads + threaded_materials > 0:
				phase = Phase.LOADING
			else:
				_launch()
			start_work_usec = Time.get_ticks_usec() - work0
			start_usec = Time.get_ticks_usec() - t0
			_meter(start_usec, "START")
			set_process(true)
		else:
			_launch()
			finish()

	# A park's lane mask (park_map.gd lane_mask_for), made once by whichever chunk job gets here first, on its worker
	# thread, behind the lock: the others wait for it, so no chunk reads it before it is whole and nothing shared is
	# written (it lives here, not in map.scatter, which the main thread may read). It reads its own copy of the graph,
	# off the main thread, since the shared copy (Activities.shared_graph) is main-thread only and a cold read there cost
	# 612 ms in the frame-cap test. lane_mask_usec is the mask's cost, graph read included.
	func _ensure_lane_mask() -> void:
		_mask_lock.lock()
		if not _mask_done:
			_mask_done = true
			# Tests only: a map that already carries a mask (map.scatter["lane_mask"]) keeps it.
			if _map.get("park") != null and _map.get("path") != null and (_map.scatter as Dictionary).has("lane_mask"):
				lane_mask = _map.scatter["lane_mask"]
			elif _map.get("park") != null and _map.get("path") != null:
				var t0 := Time.get_ticks_usec()
				lane_mask = ParkMapScript.lane_mask_for(_map.path, _map.park)
				lane_mask_usec = Time.get_ticks_usec() - t0
		_mask_lock.unlock()

	# Drops the kinds with no source, then cuts the chunks onto worker threads (or builds them here).
	func _launch() -> void:
		_groups = _groups.filter(func(g: Dictionary) -> bool:
			if (g["source"] as Dictionary).is_empty():
				push_warning("scatter: %s has no mesh, the kind stays out" % g["spec"])
				return false
			return true)
		phase = Phase.BUILDING
		if _threaded:
			_group = WorkerThreadPool.add_group_task(_build_chunk, Tiles.TILE_COUNT, WORKERS, false, "scatter chunks %s" % _map.get("title"))
		else:
			for c in Tiles.TILE_COUNT:
				_build_chunk(c)
			phase = Phase.ATTACHING

	# Turns each finished load into its kind's source; with block, waits for the loader thread.
	func _poll_loading(block: bool) -> void:
		var waiting := false
		for group: Dictionary in _groups:
			if group.has("path"):
				var path: String = group["path"]
				var status := ResourceLoader.load_threaded_get_status(path)
				if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and not block:
					waiting = true
				else:
					group.erase("path")
					if status != ResourceLoader.THREAD_LOAD_FAILED and status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
						group["source"] = Self._scene_source(ResourceLoader.load_threaded_get(path) as PackedScene)
			if group.has("material_path"):
				var mat_path: String = group["material_path"]
				var mat_status := ResourceLoader.load_threaded_get_status(mat_path)
				if mat_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and not block:
					waiting = true
				else:
					group.erase("material_path")
					if mat_status != ResourceLoader.THREAD_LOAD_FAILED and mat_status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
						group["material"] = ResourceLoader.load_threaded_get(mat_path) as Material
						(group["material"] as Material).resource_name = String(group["slot"])
		if not waiting:
			_launch()

	func finish() -> void:
		while phase == Phase.LOADING:
			_poll_loading(true)
		if phase == Phase.BUILDING:
			WorkerThreadPool.wait_for_group_task_completion(_group)
			_group = -1
			phase = Phase.ATTACHING
		while phase == Phase.ATTACHING:
			_attach_step(-1)

	func _ready() -> void:
		set_process(phase == Phase.LOADING or phase == Phase.BUILDING or phase == Phase.ATTACHING)

	func _exit_tree() -> void:
		if _group != -1:
			WorkerThreadPool.wait_for_group_task_completion(_group)
			_group = -1

	func _process(_delta: float) -> void:
		var t0 := Time.get_ticks_usec()
		if _last_frame_usec > 0:
			frame_usec_max = maxi(frame_usec_max, t0 - _last_frame_usec)
		_last_frame_usec = t0
		var was := phase
		match phase:
			Phase.LOADING:
				_poll_loading(false)
			Phase.BUILDING:
				if WorkerThreadPool.is_group_task_completed(_group):
					WorkerThreadPool.wait_for_group_task_completion(_group)
					_group = -1
					phase = Phase.ATTACHING
			Phase.ATTACHING:
				_attach_step(t0 + ATTACH_BUDGET_USEC)
		_meter(Time.get_ticks_usec() - t0, "%s chunk %d" % [Phase.keys()[was], _next])

	func _meter(spent: int, step: String) -> void:
		if step != "START" and spent > slowest_chunk_usec:
			slowest_chunk_usec = spent
		if spent > slowest_usec:
			slowest_usec = spent
			slowest_step = step

	# Worker side: pure data, no scene tree.
	func _build_chunk(c: int) -> void:
		_ensure_lane_mask()
		_results[c] = Self.chunk_batches(_groups, _map, _ground, c % Tiles.TILES_PER_SIDE, c / Tiles.TILES_PER_SIDE, lane_mask)
		if OS.get_thread_caller_id() != OS.get_main_thread_id():
			_lock.lock()
			worker_chunks += 1
			_lock.unlock()

	# Main thread: attach finished chunks, a few a frame inside the budget (deadline -1: all).
	func _attach_step(deadline: int) -> void:
		var added := 0
		while _next < Tiles.TILE_COUNT:
			if deadline >= 0 and (added >= CHUNKS_PER_FRAME or Time.get_ticks_usec() > deadline):
				return
			_attach(_next)
			_results[_next] = null
			_next += 1
			added += 1
		phase = Phase.READY
		set_process(false)
		built.emit()

	func _attach(c: int) -> void:
		var batches: Array = _results[c]
		if batches.is_empty():
			return
		var chunk := Node3D.new()
		chunk.name = "Chunk%d_%d" % [c % Tiles.TILES_PER_SIDE, c / Tiles.TILES_PER_SIDE]
		for data: Dictionary in batches:
			var group: Dictionary = _group_of(data["kind"])
			var buffer: PackedFloat32Array = data["buffer"]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = group["source"]["mesh"]
			multi.instance_count = buffer.size() / Self.FLOATS
			multi.buffer = buffer
			multi.custom_aabb = data["bounds"]
			var view := MultiMeshInstance3D.new()
			view.name = "Scatter_%s" % data["kind"]
			view.multimesh = multi
			view.visibility_range_end = float(Rows.RANGE.get(data["kind"], 0.0))
			view.set_meta("kind", data["kind"])
			view.set_meta("instance_buffer", buffer)
			view.set_meta("origins", data["origins"])
			view.set_meta("grounds", data["grounds"])
			view.set_meta("bounds", data["bounds"])
			view.set_meta("verts_per_instance", group["source"]["verts"])
			view.material_override = group["material"] if group.get("material") != null else Colours.slot_material(group["slot"])
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk.add_child(view)
		add_child(chunk)

	func _group_of(kind: String) -> Dictionary:
		for group: Dictionary in _groups:
			if group["kind"] == kind:
				return group
		return {}


# Tilt +Y onto the ground normal.
static func _lean(normal: Vector3) -> Basis:
	var axis := Vector3.UP.cross(normal)
	if axis.length() < 0.0001:
		return Basis.IDENTITY
	return Basis(axis.normalized(), Vector3.UP.angle_to(normal))


# Visual vertices one row adds on `map`: its placed instances times its mesh's vertices.
static func row_vertices(row: Dictionary, map, ground: Callable) -> int:
	var source := _source(row["mesh"])
	if source.is_empty():
		return 0
	return transforms(row, map, ground, source["aabb"]).size() * int(source["verts"])


# {"mesh", "local", "aabb", "verts"} for a row's mesh source, {} when it cannot be built.
static func _source(spec: String) -> Dictionary:
	if spec == "prim:coil":
		# Placement reads the old torus's bounds, so the old maps' coils land exactly where they did.
		var found := _found(coil_mesh(), Transform3D.IDENTITY)
		var footprint := TorusMesh.new()
		footprint.inner_radius = 0.3
		footprint.outer_radius = 0.42
		footprint.rings = 10
		footprint.ring_segments = 5
		found["aabb"] = footprint.get_aabb()
		return found
	if spec.begins_with("kit:"):
		return _found(kit_mesh(spec.trim_prefix("kit:")), Transform3D.IDENTITY)
	if spec.begins_with("glb:"):
		var path := spec.trim_prefix("glb:")
		if not ResourceLoader.exists(path):
			return {}
		return _scene_source(load(path) as PackedScene)
	return {}


# The first mesh of a kit GLB's scene, as a source ({} when it has none).
static func _scene_source(packed: PackedScene) -> Dictionary:
	if packed == null:
		return {}
	var scene := packed.instantiate()
	var found := {}
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if view.mesh != null and view.mesh.get_surface_count() > 0:
			found = _found(view.mesh, DigScenery._relative(view, scene))
			break
	scene.free()
	return found


static func _found(mesh: Mesh, local: Transform3D) -> Dictionary:
	var arrays := mesh.surface_get_arrays(0)
	return {"mesh": mesh, "local": local, "aabb": local * mesh.get_aabb(), "verts": (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()}


# The cable coil: a smooth tube along a flat spiral plus a short straight tail, wound for Godot.
static func coil_mesh() -> ArrayMesh:
	var path: Array[Vector3] = []
	var loops := int(COIL_TURNS * COIL_STEPS)
	for k in loops + 1:
		var t := float(k) / COIL_STEPS
		var a := TAU * t
		var r := COIL_RADIUS * (1.0 - 0.1 * t / COIL_TURNS)
		path.append(Vector3(cos(a) * r, 0.07 * (t / COIL_TURNS - 0.5), sin(a) * r))
	var last := path[path.size() - 1]
	var along := Vector3(-sin(TAU * COIL_TURNS), 0.0, cos(TAU * COIL_TURNS))
	for k in [1, 2]:
		path.append(Vector3(last.x, -0.035, last.z) + along * 0.22 * k)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for k in path.size():
		var ahead: Vector3 = path[mini(k + 1, path.size() - 1)] - path[maxi(k - 1, 0)]
		var side := ahead.cross(Vector3.UP).normalized()
		var up := side.cross(ahead).normalized()
		for j in COIL_SIDES:
			var phi := TAU * j / COIL_SIDES
			var n := side * cos(phi) + up * sin(phi)
			verts.append(path[k] + n * COIL_TUBE)
			normals.append(n)
			uvs.append(Vector2(float(j) / COIL_SIDES, float(k) / path.size()))
	var indices := PackedInt32Array()
	for k in path.size() - 1:
		for j in COIL_SIDES:
			var a := k * COIL_SIDES + j
			var b := k * COIL_SIDES + (j + 1) % COIL_SIDES
			for tri in [[a, b, a + COIL_SIDES], [b, b + COIL_SIDES, a + COIL_SIDES]]:
				_wind(indices, verts, normals, tri)
	# A cut face on each end of the cable, a fan round the end's centre.
	for end in [[0, 1], [path.size() - 1, -1]]:
		var ring: int = end[0] * COIL_SIDES
		var out: Vector3 = (path[end[0]] - path[end[0] + end[1]]).normalized()
		var centre := verts.size()
		verts.append(path[end[0]])
		normals.append(out)
		uvs.append(Vector2.ZERO)
		for j in COIL_SIDES:
			_wind(indices, verts, PackedVector3Array([out, out, out]), [centre, ring + j, ring + (j + 1) % COIL_SIDES], true)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# Appends tri clockwise seen from outside (Godot's front face), outside being its vertices' normals
# (or, with given, the three normals passed in that order).
static func _wind(indices: PackedInt32Array, verts: PackedVector3Array, normals: PackedVector3Array, tri: Array, given := false) -> void:
	var a: Vector3 = verts[tri[0]]
	var face := (verts[tri[1]] - a).cross(verts[tri[2]] - a)
	var outside := normals[0] + normals[1] + normals[2] if given else normals[tri[0]] + normals[tri[1]] + normals[tri[2]]
	if face.dot(outside) > 0.0:
		indices.append_array([tri[0], tri[2], tri[1]])
	else:
		indices.append_array([tri[0], tri[1], tri[2]])


# One of ScatterRows.KIT: a closed lat-long solid, flat shaded, wound for Godot (clockwise from outside).
static func kit_mesh(kit_name: String) -> ArrayMesh:
	var spec: Dictionary = ScatterRows.KIT[kit_name]
	var segments: int = spec["segments"]
	var rings: int = spec["rings"]
	var grid: Array[Vector3] = []
	grid.append(_jitter(Vector3(0.0, 0.5 * float(spec["squash"]), 0.0), 0, 0, spec))
	for k in range(1, rings):
		var theta := PI * k / rings
		for i in segments:
			var phi := TAU * i / segments
			var p := Vector3(sin(theta) * cos(phi), cos(theta) * float(spec["squash"]), sin(theta) * sin(phi)) * 0.5
			grid.append(_jitter(p, i, k, spec))
	grid.append(_jitter(Vector3(0.0, -0.5 * float(spec["squash"]), 0.0), 0, rings, spec))
	var triangles := []
	var bottom := grid.size() - 1
	for i in segments:
		var j := (i + 1) % segments
		triangles.append_array([grid[0], grid[1 + j], grid[1 + i]])
		for k in range(1, rings - 1):
			var a := 1 + (k - 1) * segments
			var b := 1 + k * segments
			triangles.append_array([grid[a + i], grid[a + j], grid[b + i]])
			triangles.append_array([grid[a + j], grid[b + j], grid[b + i]])
		var last := 1 + (rings - 2) * segments
		triangles.append_array([grid[bottom], grid[last + i], grid[last + j]])
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for t in range(0, triangles.size(), 3):
		var a: Vector3 = triangles[t]
		var b: Vector3 = triangles[t + 1]
		var c: Vector3 = triangles[t + 2]
		var n := (b - a).cross(c - a).normalized()
		for p in [a, c, b]:
			verts.append(p)
			normals.append(n)
			uvs.append(Vector2(p.x, p.z) + Vector2(0.5, 0.5))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# A fixed hash of the vertex's grid slot, so the same kit name gives the same solid every build.
static func _jitter(p: Vector3, i: int, k: int, spec: Dictionary) -> Vector3:
	var h := sin(float(i) * 12.9898 + float(k) * 78.233 + float(spec["seed"]) * 37.719) * 43758.5453
	return p * (1.0 + float(spec["jitter"]) * (2.0 * (h - floorf(h)) - 1.0))
