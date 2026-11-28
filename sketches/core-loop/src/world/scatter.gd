extends RefCounted


const AppShell := preload("res://src/core/app_shell.gd")
const ScatterRows := preload("res://src/world/scatter_rows.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")

const COIL_RADIUS := 0.38
const COIL_TUBE := 0.06
const COIL_TURNS := 2.0
const COIL_STEPS := 8
const COIL_SIDES := 5
const SLOPE_PROBE := 1.0
const FLOATS := 12
const LANE_BAND_M := 0.12


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
		# Godot's headless dummy server has no MultiMesh buffer readback; retain buffer metadata for tests.
		view.set_meta("instance_buffer", buffer)
		view.set_meta("origins", origins)
		view.set_meta("verts_per_instance", source["verts"])
		view.material_override = PaletteMaterials.slot_material(row["slot"])
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


static func _kept_out(footprints: Array, at: Vector2) -> bool:
	for f: Dictionary in footprints:
		var yaw: float = f["yaw"]
		var facing := Vector2(sin(yaw), cos(yaw))
		var d: Vector2 = at - (f["at"] as Vector2)
		var size: Vector2 = f["size"]
		if absf(d.dot(facing)) <= size.x * 0.5 and absf(d.dot(Vector2(facing.y, -facing.x))) <= size.y * 0.5:
			return true
	return false


static func park_rows(map) -> Array:
	var kit: Array = map.scatter.get("kit", []) if map.get("scatter") is Dictionary else []
	return kit if not kit.is_empty() else ScatterRows.PARK_KIT


static func chunk_rect(ci: int, cj: int) -> Rect2:
	return Rect2(-ParkTerrain.HALF + ci * ParkTerrain.TILE_M, -ParkTerrain.HALF + cj * ParkTerrain.TILE_M, ParkTerrain.TILE_M, ParkTerrain.TILE_M)


static func build_chunked(parent: Node3D, map, ground: Callable, threaded: bool, rows: Array = []) -> Node3D:
	var node := Chunked.new()
	node.name = "GroundScatter"
	parent.add_child(node)
	node.start(map, ground, rows if not rows.is_empty() else park_rows(map), threaded)
	return node


static func chunk_transforms(row: Dictionary, map, ground: Callable, aabb: AABB, ci: int, cj: int, grounds: Array, lane: Dictionary = {}) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var rect: Rect2 = chunk_rect(ci, cj).intersection(map.play_rect)
	if rect.get_area() <= 0.0:
		return out
	var clear: Dictionary = map.scatter["clear"]
	var keeps := [[map.spawn, float(clear["spawn"])], [map.beacon, float(clear["beacon"])], [map.vault, float(clear["vault"])]]
	var keep_out: Array = map.scatter.get("keep_out", [])
	var tall := is_tall(row, aabb)
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
		if x >= rect.end.x or z >= rect.end.y:
			continue
		if field != null and rng.randf() > _clump_keep(clump, field, x, z):
			continue
		if _kept_clear(keeps, Vector2(x, z)) or _kept_out(keep_out, Vector2(x, z)):
			continue
		var placed := out.size()
		_stand(row, ground, aabb, x, z, yaw, s, tilt, out, grounds)
		if tall and out.size() > placed and _in_lane(lane_mask, out[placed].origin.x, out[placed].origin.z):
			out[placed] = _sunk_to_band(out[placed], ground, aabb)
	return out


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


static func _clump_keep(clump: Dictionary, field: FastNoiseLite, x: float, z: float) -> float:
	var keep := float(clump["keep"])
	return clampf(keep + field.get_noise_2d(x, z) * float(clump["gain"]), 0.0, 2.0 * keep)


static func _in_lane(mask: Dictionary, x: float, z: float) -> bool:
	if mask.is_empty():
		return false
	var side: int = mask["side"]
	var step: float = mask["step"]
	var half: float = mask["half"]
	var i := clampi(roundi((x + half) / step), 0, side - 1)
	var j := clampi(roundi((z + half) / step), 0, side - 1)
	return (mask["cells"] as PackedByteArray)[j * side + i] != 0


static func _sunk_to_band(xf: Transform3D, ground: Callable, aabb: AABB) -> Transform3D:
	var worst := -INF
	for i in 8:
		var c := xf * aabb.get_endpoint(i)
		worst = maxf(worst, c.y - (ground.call(c.x, c.z, 0.0) as Vector3).y)
	if worst > LANE_BAND_M:
		xf.origin.y -= worst - LANE_BAND_M
	return xf


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
	const ATTACH_BUDGET_USEC := 6000
	const CHUNKS_PER_FRAME := 8
	const WORKERS := 4

	enum Phase { IDLE, LOADING, BUILDING, ATTACHING, READY }

	var phase := Phase.IDLE
	var worker_chunks := 0
	var slowest_usec := 0
	var slowest_step := ""
	var start_usec := 0
	var start_work_usec := 0
	var slowest_chunk_usec := 0
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
	var threaded_loads := 0
	var threaded_materials := 0

	func is_ready() -> bool:
		return phase == Phase.READY

	func start(map, ground: Callable, rows: Array, threaded: bool) -> void:
		var t0 := Time.get_ticks_usec()
		# Godot's headless dummy rasterizer mesh RID owner is not thread-safe ("Attempting to initialize the wrong RID"); load on main thread when headless.
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
			var slot_row: Dictionary = PaletteMaterials.SLOT_TABLE.row(group["slot"])
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

	func _ensure_lane_mask() -> void:
		_mask_lock.lock()
		if not _mask_done:
			_mask_done = true
			if _map.get("park") != null and _map.get("path") != null and (_map.scatter as Dictionary).has("lane_mask"):
				lane_mask = _map.scatter["lane_mask"]
			elif _map.get("park") != null and _map.get("path") != null:
				var t0 := Time.get_ticks_usec()
				lane_mask = ParkMapScript.lane_mask_for(_map.path, _map.park)
				lane_mask_usec = Time.get_ticks_usec() - t0
		_mask_lock.unlock()

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

	func _build_chunk(c: int) -> void:
		_ensure_lane_mask()
		_results[c] = Self.chunk_batches(_groups, _map, _ground, c % Tiles.TILES_PER_SIDE, c / Tiles.TILES_PER_SIDE, lane_mask)
		if OS.get_thread_caller_id() != OS.get_main_thread_id():
			_lock.lock()
			worker_chunks += 1
			_lock.unlock()

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
			# Godot's headless dummy server has no MultiMesh buffer readback; retain buffer metadata for tests.
			view.set_meta("instance_buffer", buffer)
			view.set_meta("origins", data["origins"])
			view.set_meta("grounds", data["grounds"])
			view.set_meta("bounds", data["bounds"])
			view.set_meta("verts_per_instance", group["source"]["verts"])
			view.material_override = group["material"] if group.get("material") != null else PaletteMaterials.slot_material(group["slot"])
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk.add_child(view)
		add_child(chunk)

	func _group_of(kind: String) -> Dictionary:
		for group: Dictionary in _groups:
			if group["kind"] == kind:
				return group
		return {}


static func _lean(normal: Vector3) -> Basis:
	var axis := Vector3.UP.cross(normal)
	if axis.length() < 0.0001:
		return Basis.IDENTITY
	return Basis(axis.normalized(), Vector3.UP.angle_to(normal))


static func row_vertices(row: Dictionary, map, ground: Callable) -> int:
	var source := _source(row["mesh"])
	if source.is_empty():
		return 0
	return transforms(row, map, ground, source["aabb"]).size() * int(source["verts"])


static func _source(spec: String) -> Dictionary:
	if spec == "prim:coil":
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


static func _wind(indices: PackedInt32Array, verts: PackedVector3Array, normals: PackedVector3Array, tri: Array, given := false) -> void:
	var a: Vector3 = verts[tri[0]]
	var face := (verts[tri[1]] - a).cross(verts[tri[2]] - a)
	var outside := normals[0] + normals[1] + normals[2] if given else normals[tri[0]] + normals[tri[1]] + normals[tri[2]]
	if face.dot(outside) > 0.0:
		indices.append_array([tri[0], tri[2], tri[1]])
	else:
		indices.append_array([tri[0], tri[1], tri[2]])


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


static func _jitter(p: Vector3, i: int, k: int, spec: Dictionary) -> Vector3:
	var h := sin(float(i) * 12.9898 + float(k) * 78.233 + float(spec["seed"]) * 37.719) * 43758.5453
	return p * (1.0 + float(spec["jitter"]) * (2.0 * (h - floorf(h)) - 1.0))
