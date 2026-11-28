extends RefCounted

const EventGround := preload("res://src/world/events/event_ground.gd")

const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const PylonBite := preload("res://src/world/pylon_bite.gd")
const Spillway := preload("res://src/world/map_spillway.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const Reach := preload("res://src/world/map_reach.gd")
const Dig := preload("res://src/world/map_dig.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")
const DigDeep := preload("res://src/world/map_dig_deep.gd")
const HighdraftCrown := preload("res://src/world/map_highdraft_crown.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Scatter := preload("res://src/world/scatter.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const PerchPoints := preload("res://src/world/perch_points.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

const PARK_FILES := ["res://src/world/park/%s.json", "res://assets/park/%s_stage1.json"]
const MAPS := {"spillway": Spillway, "gorge": Gorge, "reach": Reach, "dig": Dig, "highdraft": Highdraft, "dig_deep": DigDeep, "highdraft_crown": HighdraftCrown}


const HALF := 200.0
const STEP := 2.0
const CELLS := int(2.0 * HALF / STEP)
const SIDE := CELLS + 1
const PYLON_FACE := PylonBite.FACE
const PARK_DEPTH := 5000.0

var maps: Array = []
var stage := 1
var flood
var environment: Environment
var bay
var overlays: Array[String] = []

var range_errors := {}
var error_sink: Callable

var _roots: Array = []
var _heights: Array[PackedFloat32Array] = []
var _worlds: Array[int] = []
var _parent: Node3D
var _used_frame := -1000
var _changed_frame := -1000
var _arena := false
var _is_park: Array[bool] = []
var _grounds: Array = []
var _holes: Array[PackedByteArray] = []
var _under: Array[PackedFloat32Array] = []
var _cave_roofs := {}
var _placement_holes := {}
var _render: Array[Node3D] = []
var _render_owner: Array[int] = []
var last_use_usec := 0
const SWAP_METER_FRAMES := 120
var publish: Callable
var _threaded: Array[bool] = []
var _perches := {}
var _perch_ahead := {}
var _perch_patch := {}

signal stage_freed(index: int)
signal stage_built(index: int)
signal surface_changed

var _threaded_first := false


func _init(table = StageDefs) -> void:
	var parks := _read_parks_together(table)
	for row in table.DEFS:
		var id := String(row["map"])
		maps.append(parks.get(id) if parks.has(id) else map_named(id, int(row["stage"])))
		parks.erase(id)
		_is_park.append(maps[-1] is ParkMap)
		_worlds.append(int(row.get("world", 1)))
		_roots.append(null)
		_heights.append(PackedFloat32Array())
		_grounds.append(null)
		_holes.append(PackedByteArray())
		_under.append(PackedFloat32Array())
		_threaded.append(false)


static func _read_parks_together(table) -> Dictionary:
	var paths := {}
	for row in table.DEFS:
		var id := String(row["map"])
		if not id.begins_with("park_") or paths.has(id):
			continue
		for pattern in PARK_FILES:
			if FileAccess.file_exists(pattern % id):
				paths[id] = pattern % id
				break
	ParkSchema.warm_registry()
	ParkRecipes.origin("")
	if paths.size() < 2:
		return {}
	var ids: Array = paths.keys()
	var read := []
	read.resize(ids.size())
	# Godot 4.7.2 caches untyped operators lazily without locking; warm ParkMap once before WorkerThreadPool reads it.
	read[0] = ParkMap.new(paths[ids[0]])
	var task := WorkerThreadPool.add_group_task(func(n: int): read[n + 1] = ParkMap.new(paths[ids[n + 1]]), ids.size() - 1, -1, true, "park files")
	WorkerThreadPool.wait_for_group_task_completion(task)
	var parks := {}
	for n in ids.size():
		if read[n] != null and read[n].ok:
			parks[ids[n]] = read[n]
	return parks


static func map_named(id: String, stage_number: int) -> RefCounted:
	if id.begins_with("park_"):
		return _park_map(id, stage_number)
	assert(MAPS.has(id), "terrain: stage %s names an unknown map '%s'" % [stage_number, id])
	return MAPS[id].new()


static func _park_map(id: String, stage_number: int) -> RefCounted:
	for pattern in PARK_FILES:
		var path: String = pattern % id
		if FileAccess.file_exists(path):
			var park = ParkMap.new(path)
			assert(park.ok, "terrain: %s fails the park schema: %s" % [path, str(park.errors)])
			return park
	var old: String = StageDefs.DEFS[clampi(stage_number, 1, StageDefs.COUNT) - 1]["map"]
	return map_named(old, stage_number)


func map() -> RefCounted:
	return maps[stage - 1]


func world() -> int:
	return _worlds[_index(stage)]


func map_for(index: int) -> RefCounted:
	return maps[_index(index)]


func build(parent: Node3D, threaded_first := false) -> void:
	_parent = parent
	_threaded_first = threaded_first
	_build_sky(parent)
	_pad_rows()
	if _is_park.has(true) and parent.is_inside_tree():
		for n in mini(2, _is_park.count(true)):
			_render.append(ParkTerrain.make_render(parent, "ParkRender%d" % (n + 1)))
			_render_owner.append(-1)
	for i in maps.size():
		if _worlds[i] == _worlds[0] and (not _is_park[i] or i == 0):
			if _is_park[i] and threaded_first and worker_builds():
				_build_park_stage(i, true)
			else:
				_build_stage(i)


func is_built(index: int) -> bool:
	return is_ready(index)


func is_ready(index: int) -> bool:
	var i := _index(index)
	return _roots[i] != null and (not _is_park[i] or _grounds[i].is_ready())


func built_threaded(index: int) -> bool:
	return _threaded[_index(index)]


func park_ground(index: int) -> Node3D:
	return _grounds[_index(index)]


func prepare(index: int) -> void:
	var i := _index(index)
	if not _is_park[i] or _roots[i] != null or _parent == null:
		return
	_build_park_stage(i, worker_builds())


static func worker_builds() -> bool:
	return SimClock.threaded_in_bot_runs or not SimClock.ticks


func _build_stage(i: int) -> void:
	if _is_park[i]:
		_build_park_stage(i, false)
		return
	var m = maps[i]
	var holder := Node3D.new()
	holder.name = _hold_name(i)
	var heights := _build_ground(holder, m)
	m.build_props(holder, _ground_at.bind(heights))
	_build_scatter(holder, m, heights)
	_roots[i] = holder
	_heights[i] = heights
	_parent.add_child(holder)
	_park(holder, _arena or i != stage - 1)
	holder.process_mode = Node.PROCESS_MODE_DISABLED if _arena else Node.PROCESS_MODE_INHERIT


func _hold_name(i: int) -> String:
	var stage_name := "Stage%d" % (i + 1)
	var old := _parent.get_node_or_null(NodePath(stage_name)) if _parent != null else null
	if old != null and old.get_node_or_null("Reaper") != null:
		Reaper.yield_name(old)
	return stage_name


func _build_park_stage(i: int, threaded: bool) -> void:
	var m = maps[i]
	var holder := Node3D.new()
	holder.name = _hold_name(i)
	_roots[i] = holder
	_parent.add_child(holder)
	_park(holder, _arena or i != stage - 1)
	var ground := ParkTerrain.new()
	_grounds[i] = ground
	_threaded[i] = threaded
	holder.add_child(ground)
	ground.built.connect(_on_park_built.bind(i), CONNECT_ONE_SHOT)
	var slot := _render_owner.find(-1)
	if slot >= 0:
		_render_owner[slot] = i
	ground.start(String(m.title), m, threaded, _render[slot] if slot >= 0 else null)
	_show_render()
	holder.process_mode = Node.PROCESS_MODE_DISABLED if _arena else Node.PROCESS_MODE_INHERIT


func _on_park_built(i: int) -> void:
	var ground = _grounds[i]
	_heights[i] = ground.heights
	_holes[i] = ground.holes
	_under[i] = ground.under.duplicate()
	_placement_holes[i] = _holes[i].duplicate()
	_cave_roofs[i] = {}
	for row in maps[i].park.event_rows:
		if row.kind != "cave_in":
			continue
		var sites: Array = maps[i].park.park_rows.filter(func(site): return site.id == row.site and bool(site.hole))
		if sites.is_empty():
			continue
		var roof := EventGround.cave_roof(_heights[i], _holes[i], sites[0], _roots[i])
		roof.body.name = "CaveRoof_" + row.id
		_cave_roofs[i][row.id] = roof
		for cell: Vector2i in roof.baseline.cells:
			var i_cell := cell.x + int(ParkTerrain.HALF / ParkTerrain.STEP)
			var j_cell := cell.y + int(ParkTerrain.HALF / ParkTerrain.STEP)
			var k := j_cell * ParkTerrain.CELLS + i_cell
			var floor_y := INF
			for face in roof.baseline.cells[cell]:
				for vertex in range(face, face + 3):
					floor_y = minf(floor_y, roof.baseline.vertices[vertex].y - float(row.effect.depth_m))
			_under[i][k] = floor_y
			_placement_holes[i][k] = 0
	maps[i].build_props(_roots[i], ground_callable(i + 1))
	if maps[i] is ParkMap:
		ParkRecipes.build_placed(_roots[i], maps[i].park, _park_floor_at.bind(_heights[i], _placement_holes[i], _under[i]), publish, _threaded[i], maps[i].line_within)
	Scatter.build_chunked(_roots[i], maps[i], ground_callable(i + 1), worker_builds())
	_perch_read_ahead(i)
	stage_built.emit(i + 1)


func park_rows(index: int) -> Node:
	var root: Node3D = _roots[_index(index)]
	return root.get_node_or_null("ParkRows") if root != null else null


func rows_ready(index: int) -> bool:
	var rows := park_rows(index)
	return not _is_park[_index(index)] or (rows != null and rows.is_ready())


func _ensure(index: int) -> int:
	var i := _index(index)
	if _roots[i] == null:
		assert(_parent != null, "terrain: build() has not run")
		if _is_park[i]:
			_build_stage(i)
		else:
			for j in maps.size():
				if _worlds[j] == _worlds[i] and _roots[j] == null and not _is_park[j]:
					_build_stage(j)
	elif _is_park[i] and not _grounds[i].is_ready():
		if i == 0 and _threaded_first:
			_threaded[i] = false
		_grounds[i].finish()
	return i


func use(index: int) -> void:
	var started := Time.get_ticks_usec()
	_used_frame = Engine.get_physics_frames()
	var target := _index(index)
	for i in _roots.size():
		if _roots[i] != null and _is_park[i] and i != target and i != target + 1:
			_free_stage(i)
	stage = _ensure(target + 1) + 1
	_arena = false
	var m = map()
	overlays.clear()
	if "start_overlays" in m:
		overlays.append_array(m.start_overlays)
	for i in _roots.size():
		if _roots[i] == null:
			continue
		_park(_roots[i], i != stage - 1)
		_roots[i].process_mode = Node.PROCESS_MODE_INHERIT
	_show_render()
	if _is_park[stage - 1]:
		_grounds[stage - 1].meter(SWAP_METER_FRAMES)
	last_use_usec = Time.get_ticks_usec() - started


func _show_render() -> void:
	for n in _render.size():
		_render[n].visible = not _arena and _render_owner[n] == stage - 1


func _free_stage(i: int) -> void:
	var slot := _render_owner.find(i)
	if slot >= 0:
		_render_owner[slot] = -1
	if _grounds[i] != null:
		_grounds[i].set_process(false)
	if worker_builds():
		Reaper.take(_roots[i])
	else:
		_roots[i].queue_free()
	_roots[i] = null
	_grounds[i] = null
	_cave_roofs.erase(i)
	_perches.erase(i)
	_take_perch_ahead(i)
	_take_perch_patch(i)
	_placement_holes.erase(i)
	_heights[i] = PackedFloat32Array()
	_holes[i] = PackedByteArray()
	_under[i] = PackedFloat32Array()
	stage_freed.emit(i + 1)


func park_all() -> void:
	_arena = true
	for root in _roots:
		if root == null:
			continue
		_park(root, true)
		root.process_mode = Node.PROCESS_MODE_DISABLED
	_show_render()


static func _park(root: Node3D, parked: bool) -> void:
	root.visible = not parked
	root.position = Vector3.DOWN * PARK_DEPTH if parked else Vector3.ZERO


class Reaper extends Node:
	const BUDGET_USEC := 3000

	static func take(root: Node3D) -> void:
		root.visible = false
		root.process_mode = Node.PROCESS_MODE_DISABLED
		var reaper := Reaper.new()
		reaper.name = "Reaper"
		reaper.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(reaper)
		root.move_child(reaper, 0)

	func _process(_delta: float) -> void:
		var root := get_parent()
		var deadline := Time.get_ticks_usec() + BUDGET_USEC
		yield_name(root)
		while Time.get_ticks_usec() < deadline:
			if root.get_child_count() <= 1:
				set_process(false)
				root.queue_free()
				return
			var node: Node = root.get_child(root.get_child_count() - 1)
			while node.get_child_count() > 0 and not node is CollisionObject3D:
				node = node.get_child(node.get_child_count() - 1)
			# Godot locks scripted nodes with pending calls against synchronous free(); detach and queue_free them.
			if node.get_script() != null:
				node.get_parent().remove_child(node)
				node.queue_free()
			else:
				node.free()

	static func yield_name(root: Node) -> void:
		if not String(root.name).begins_with("Freed"):
			root.name = "Freed%s" % root.name


func geometry_root(index: int) -> Node3D:
	return _roots[_ensure(index)]


func height(x: float, z: float) -> float:
	var h := _floor(_ensure(stage), x, z)
	if overlays.is_empty():
		return h
	var ground := h
	var m = map()
	for id in overlays:
		h = maxf(h, m.overlay_height(id, x, z, ground))
	return h


func heights(points: PackedVector2Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(points.size())
	if points.is_empty():
		return out
	var i := _ensure(stage)
	var m = map()
	var ids: Array[String] = []
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	for id in overlays:
		if m is EventGround.OverlayMap and m.profiles.has(id):
			var site: Dictionary = m.profiles[id].site
			var centre := ParkMap.v2(site.at)
			var nearest := centre.clamp(bounds.position, bounds.end)
			if centre.distance_to(nearest) > ParkMap.footprint_half_extents(site).length() + 0.01:
				continue
		ids.append(id)
	for k in points.size():
		var p := points[k]
		var ground := _floor(i, p.x, p.y)
		var h := ground
		for id in ids:
			h = maxf(h, m.overlay_height(id, p.x, p.y, ground))
		out[k] = h
	return out


func floor_height(x: float, z: float) -> float:
	return _floor(_ensure(stage), x, z)


func bare_grid_height(x: float, z: float) -> float:
	return grid_height(_heights[_ensure(stage)], x, z)


func hole_floor(x: float, z: float) -> float:
	var i := _ensure(stage)
	return ParkTerrain.hole_floor(_holes[i], _under[i], x, z)


func park_stage_grid(index: int) -> Dictionary:
	if index < 1 or index > maps.size():
		return {}
	var i := index - 1
	if not _is_park[i] or _heights[i].is_empty():
		return {}
	return {"heights": _heights[i], "holes": _holes[i], "under": _under[i]}


func stage_root_key(index: int) -> int:
	if index < 1 or index > maps.size():
		return 0
	var i := index - 1
	if not _is_park[i] or _roots[i] == null or _heights[i].is_empty():
		return 0
	return _roots[i].get_instance_id()


func drop_point(x: float, z: float, clearance := 1.8) -> Vector3:
	return Vector3(x, height(x, z) + clearance, z)


const SURFACE_REACH_M := 40.0
const SURFACE_BELOW_M := 0.05
const SURFACE_SKIPS := 8
const SETTLE_FRAMES := 2
const SURFACE_RING := 16


func top_surface(x: float, z: float, radius := 0.0) -> Dictionary:
	if not rows_ready(stage) or Engine.get_physics_frames() < maxi(_used_frame, _changed_frame) + SETTLE_FRAMES:
		return {}
	var space: PhysicsDirectSpaceState3D = null
	if _parent != null and _parent.is_inside_tree():
		space = _parent.get_world_3d().direct_space_state
	var centre := _surface_hit(space, x, z)
	if radius <= 0.0:
		return centre
	var samples: Array[Vector3] = [centre.point]
	for k in SURFACE_RING:
		var angle := TAU * float(k) / float(SURFACE_RING)
		samples.append(_surface_hit(space, x + cos(angle) * radius, z + sin(angle) * radius).point)
	var sxx := 0.0
	var szz := 0.0
	var sxy := 0.0
	var szy := 0.0
	var mean_y := 0.0
	for p in samples:
		mean_y += p.y
	mean_y /= float(samples.size())
	for p in samples:
		sxx += (p.x - x) * (p.x - x)
		szz += (p.z - z) * (p.z - z)
		sxy += (p.x - x) * (p.y - mean_y)
		szy += (p.z - z) * (p.y - mean_y)
	var b := sxy / sxx
	var c := szy / szz
	var lowest := INF
	for p in samples:
		lowest = minf(lowest, p.y - (mean_y + b * (p.x - x) + c * (p.z - z)))
	return {"point": Vector3(x, mean_y + lowest, z), "normal": Vector3(-b, 1.0, -c).normalized()}


func surface_moved() -> void:
	_changed_frame = Engine.get_physics_frames()
	surface_changed.emit()


func _surface_hit(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Dictionary:
	var ground := height(x, z)
	if space != null:
		var top := Vector3(x, ground + SURFACE_REACH_M, z)
		var query := PhysicsRayQueryParameters3D.create(top, Vector3(x, ground - SURFACE_BELOW_M, z), PhysicsLayers.WORLD_MASK)
		for i in SURFACE_SKIPS:
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			if _is_surface(hit.collider):
				return {"point": hit.position, "normal": hit.normal}
			query.exclude = query.exclude + [hit.rid]
	var e := STEP * 0.25
	var normal := Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()
	return {"point": Vector3(x, ground, z), "normal": normal}


func _is_surface(collider: Object) -> bool:
	if not (collider is StaticBody3D) or collider is AnimatableBody3D or ParkRecipes.moves(collider as Node):
		return false
	var i := _index(stage)
	var owners: Array[Node] = []
	if _is_park[i]:
		owners = [_grounds[i], park_rows(stage)]
	elif _roots[i] != null:
		owners = [_roots[i].get_node_or_null("Ground")]
	for owner in owners:
		if owner != null and (owner == collider or owner.is_ancestor_of(collider as Node)):
			return true
	return false


func perch_near(point: Vector3, salt := 0) -> Vector3:
	var m = map()
	if not (m is ParkMap) or not m.ok:
		return Vector3.INF
	var i := _index(stage)
	if not _perches.has(i):
		_ensure(stage)
		var ahead := _take_perch_ahead(i)
		var patch: Dictionary = _perch_patch.get(i, {})
		_perch_patch.erase(i)
		var discs = _overlay_discs(m) if not ahead.is_empty() and EventGround.pristine(self, i + 1) else null
		if discs != null and (discs as Array).is_empty():
			_perches[i] = ahead
		elif discs != null:
			if patch.get("sig") == _overlay_sig(m):
				_settle_perch_read(patch)
				_perches[i] = {"tops": patch.out.tops, "blockers": ahead.blockers, "ledges": patch.out.ledges}
			else:
				_perches[i] = {"tops": PerchPoints.derive(m.park, height), "blockers": ahead.blockers,
					"ledges": PerchPoints.patched_ledges(m.park, height, ahead.found, discs)}
		else:
			_perches[i] = {"tops": PerchPoints.derive(m.park, height), "blockers": PerchPoints.blockers(m.park), "ledges": PerchPoints.ledges(m.park, height)}
	return PerchPoints.pick(_perches[i]["tops"], point, height, _perches[i]["blockers"], salt, _perches[i]["ledges"])


func prepare_perches() -> void:
	var m = map()
	if not (m is ParkMap) or not m.ok or overlays.is_empty():
		return
	var i := _index(stage)
	if _perches.has(i) or not _perch_ahead.has(i) or not EventGround.pristine(self, i + 1):
		return
	var discs = _overlay_discs(m)
	if discs == null:
		return
	var ahead: Dictionary = _perch_ahead[i]
	if not _read_done(ahead):
		return
	var sig := _overlay_sig(m)
	if _perch_patch.has(i) and (_perch_patch[i].sig == sig or not _read_done(_perch_patch[i])):
		return
	_take_perch_patch(i)
	_settle_perch_read(ahead)
	if ahead.out.is_empty():
		return
	var snap := EventGround.snapshot(self, i + 1, false)
	for id in overlays:
		snap = snap.with_profile({"site": m.profiles[id].site, "surface": m.profiles[id].surface})
	var out := {}
	var patch := {"sig": sig, "out": out, "task": _queue_perch_patch(m.park, snap, ahead.out.found, discs, out)}
	_perch_patch[i] = patch
	_settle_on_exit(_roots[i], patch)


func _overlay_sig(m) -> Array:
	return overlays.map(func(id: String) -> Array: return [id, m.profiles[id].surface] if m.profiles.has(id) else [id])


static func _queue_perch_patch(park: Dictionary, snap: RefCounted, bare_found: Array, discs: Array, out: Dictionary) -> int:
	var ground := func(x: float, z: float) -> float: return snap.terrain.height(x, z)
	return WorkerThreadPool.add_task(func():
		snap.copy_roofs()
		out.merge({"tops": PerchPoints.derive(park, ground), "ledges": PerchPoints.patched_ledges(park, ground, bare_found, discs)}),
		true, "perch patch")


static func _read_done(read: Dictionary) -> bool:
	return not read.has("task") or WorkerThreadPool.is_task_completed(read.task)


func _take_perch_patch(i: int) -> Dictionary:
	if not _perch_patch.has(i):
		return {}
	var patch: Dictionary = _perch_patch[i]
	_perch_patch.erase(i)
	_settle_perch_read(patch)
	return patch


func _overlay_discs(m) -> Variant:
	var discs: Array = []
	for id in overlays:
		if not (m is EventGround.OverlayMap) or not m.profiles.has(id):
			return null
		var site: Dictionary = m.profiles[id].site
		discs.append(Vector3(float(site.at[0]), float(site.at[1]), ParkMap.footprint_half_extents(site).length()))
	return discs


func _perch_read_ahead(i: int) -> void:
	var m = maps[i]
	if not (m is ParkMap) or not m.ok or _perch_ahead.has(i) or _perches.has(i):
		return
	var out := {}
	var ahead := {"out": out, "task": _queue_perch_read(m.park, EventGround.snapshot(self, i + 1, false), out)}
	_perch_ahead[i] = ahead
	_settle_on_exit(_roots[i], ahead)


static func _queue_perch_read(park: Dictionary, floor_snapshot: RefCounted, out: Dictionary) -> int:
	var ground := func(x: float, z: float) -> float: return floor_snapshot.terrain.height(x, z)
	return WorkerThreadPool.add_task(func():
		floor_snapshot.copy_roofs()
		var found := PerchPoints.found(park, ground)
		out.merge({"tops": PerchPoints.derive(park, ground), "blockers": PerchPoints.blockers(park), "found": found, "ledges": PerchPoints.thin(found)}),
		true, "perch read")


static func _settle_on_exit(root: Node, ahead: Dictionary) -> void:
	root.tree_exiting.connect(func(): _settle_perch_read(ahead), CONNECT_ONE_SHOT)


static func _settle_perch_read(ahead: Dictionary) -> void:
	if ahead.has("task"):
		WorkerThreadPool.wait_for_task_completion(ahead.task)
		ahead.erase("task")


func _take_perch_ahead(i: int) -> Dictionary:
	if not _perch_ahead.has(i):
		return {}
	var ahead: Dictionary = _perch_ahead[i]
	_perch_ahead.erase(i)
	_settle_perch_read(ahead)
	return ahead.out


func spawn_point(index: int) -> Vector3:
	var s: Vector2 = map_for(index).spawn
	return Vector3(s.x, _floor(_ensure(index), s.x, s.y) + 2.0, s.y)


func entry_heading(index: int) -> Vector3:
	return (map_for(index).heading as Vector3).normalized()


func beacon_point(index: int) -> Vector3:
	var b: Vector2 = map_for(index).beacon
	return Vector3(b.x, _floor(_ensure(index), b.x, b.y), b.y)


func scrap_lines(index: int) -> Array:
	return map_for(index).scrap_lines


func scrap_trail(index: int) -> Dictionary:
	return map_for(index).scrap_trail


func contains(point: Vector3) -> bool:
	_pad_rows()
	var half := ParkTerrain.HALF if _is_park[stage - 1] else HALF
	return absf(point.x) < half - 1.0 and absf(point.z) < half - 1.0


func rescue_point(near: Vector3) -> Vector3:
	var r: Rect2 = map().play_rect
	return drop_point(clampf(near.x, r.position.x, r.end.x), clampf(near.z, r.position.y, r.end.y), 3.0)


func material_at(point: Vector3) -> Dictionary:
	if not contains(point):
		return {}
	var ground := height(point.x, point.z)
	if flood != null and flood.in_basin(point):
		var surface: float = flood.surface_y()
		if surface > ground:
			return {"material": "water", "surface_y": surface}
	return {"material": map().material_at(point.x, point.z), "surface_y": ground}


func landmark_point(index: int) -> Vector3:
	var m = map_for(index)
	return m.landmark if "landmark" in m else Vector3.INF


func layer_at(point: Vector3) -> String:
	_pad_rows()
	var i := stage - 1
	if _is_park[i] and not is_nan(ParkTerrain.hole_floor(_holes[_ensure(stage)], _under[i], point.x, point.z)):
		return "under"
	var m = map()
	return m.layer_at(point) if m.has_method("layer_at") else ""


func in_bay(point: Vector3) -> bool:
	return bay != null and bay.inside and bay.on_deck(point)


func moss_point() -> Vector3:
	return bay.moss_point() if bay != null and bay.docked else Vector3.INF


func near_moss(point: Vector3) -> bool:
	return bay != null and bay.near_moss(point)


func ground_callable(index: int) -> Callable:
	var i := _ensure(index)
	if _is_park[i]:
		return _park_ground_at.bind(_heights[i], _placement_holes.get(i, _holes[i]), _under[i])
	return _ground_at.bind(_heights[i])


func cave_roof(id: String) -> Dictionary:
	return _cave_roofs.get(stage - 1, {}).get(id, {})


func cave_roofs(index: int) -> Dictionary:
	return _cave_roofs.get(index - 1, {})


func _floor(i: int, x: float, z: float) -> float:
	var roof_y := -INF
	for roof in _cave_roofs.get(i, {}).values():
		roof_y = maxf(roof_y, roof.surface.height(Vector2(x, z)))
	if roof_y > -INF:
		return maxf(roof_y, retained_park_height(_heights[i], _holes[i], x, z))
	if _is_park[i]:
		return park_height(_heights[i], _holes[i], _under[i], x, z)
	return grid_height(_heights[i], x, z)


static func retained_park_height(heights: PackedFloat32Array, holes: PackedByteArray, x: float, z: float) -> float:
	var grid := Vector2((x + ParkTerrain.HALF) / ParkTerrain.STEP, (z + ParkTerrain.HALF) / ParkTerrain.STEP)
	var cell := Vector2i(floori(grid.x), floori(grid.y))
	var result := -INF
	for delta in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]:
		var at: Vector2i = cell + delta
		if at.x < 0 or at.y < 0 or at.x >= ParkTerrain.CELLS or at.y >= ParkTerrain.CELLS:
			continue
		if holes[at.y * ParkTerrain.CELLS + at.x] == 1:
			continue
		var f := grid - Vector2(at)
		if f.x < 0.0 or f.y < 0.0 or f.x > 1.0 or f.y > 1.0:
			continue
		var k := at.y * ParkTerrain.SIDE + at.x
		var a := heights[k]
		var b := heights[k + 1]
		var c := heights[k + ParkTerrain.SIDE]
		var d := heights[k + ParkTerrain.SIDE + 1]
		var y := a + (b - a) * f.x + (c - a) * f.y if f.x + f.y <= 1.0 else d + (c - d) * (1.0 - f.x) + (b - d) * (1.0 - f.y)
		result = maxf(result, y)
	return result


static func park_height(heights: PackedFloat32Array, holes: PackedByteArray, under: PackedFloat32Array, x: float, z: float) -> float:
	var floor_y := ParkTerrain.hole_floor(holes, under, x, z)
	return grid_height(heights, x, z) if is_nan(floor_y) else floor_y


static func _park_ground_at(x: float, z: float, clearance: float, heights: PackedFloat32Array, holes: PackedByteArray, under: PackedFloat32Array) -> Vector3:
	return Vector3(x, park_height(heights, holes, under, x, z) + clearance, z)


static func _park_floor_at(x: float, z: float, heights: PackedFloat32Array, holes: PackedByteArray, under: PackedFloat32Array) -> float:
	return park_height(heights, holes, under, x, z)


func vault_point(index: int) -> Vector3:
	var v: Vector2 = map_for(index).vault
	return Vector3(v.x, _floor(_ensure(index), v.x, v.y), v.y)


func _index(index: int) -> int:
	_pad_rows()
	if index < 1 or index > maps.size():
		_range_error(index)
	return clampi(index, 1, maps.size()) - 1


func _pad_rows() -> void:
	while _is_park.size() < maps.size():
		_is_park.append(maps[_is_park.size()] is ParkMap)
		_grounds.append(null)
		_holes.append(PackedByteArray())
		_under.append(PackedFloat32Array())


func _range_error(index: int) -> void:
	if range_errors.has(index):
		return
	range_errors[index] = true
	var text := "terrain: stage %d is outside the table (1 to %d); reading the nearest stage" % [index, maps.size()]
	if error_sink.is_valid():
		error_sink.call(text)
	else:
		push_error(text)


static func grid_height(heights: PackedFloat32Array, x: float, z: float) -> float:
	var half := HALF
	var cells := CELLS
	var side := SIDE
	if heights.size() == ParkTerrain.SIDE * ParkTerrain.SIDE:
		half = ParkTerrain.HALF
		cells = ParkTerrain.CELLS
		side = ParkTerrain.SIDE
	var gx := clampf((x + half) / STEP, 0.0, cells - 0.001)
	var gz := clampf((z + half) / STEP, 0.0, cells - 0.001)
	var i := int(gx)
	var j := int(gz)
	var fx := gx - i
	var fz := gz - j
	var a := heights[j * side + i]
	var b := heights[j * side + i + 1]
	var c := heights[(j + 1) * side + i]
	var d := heights[(j + 1) * side + i + 1]
	if fx + fz <= 1.0:
		return a + (b - a) * fx + (c - a) * fz
	return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)


static func _ground_at(x: float, z: float, clearance: float, heights: PackedFloat32Array) -> Vector3:
	return Vector3(x, grid_height(heights, x, z) + clearance, z)


static func _build_scatter(holder: Node3D, m: RefCounted, heights: PackedFloat32Array) -> void:
	var scatter: Dictionary = m.get("scatter") if m.get("scatter") is Dictionary else {}
	if (scatter.get("kit", []) as Array).is_empty():
		return
	var relief: Dictionary = scatter.get("relief", {})
	var ground := _ground_at.bind(heights)
	if not relief.is_empty():
		ground = _relief_at.bind(heights, _relief_noise(relief), float(relief["amp"]))
	Scatter.build(holder, m, ground)


static func _relief_at(x: float, z: float, clearance: float, heights: PackedFloat32Array, noise: FastNoiseLite, amp: float) -> Vector3:
	return Vector3(x, grid_height(heights, x, z) + noise.get_noise_2d(x, z) * amp + clearance, z)


static func _relief_noise(row: Dictionary) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = String(row["seed"]).hash()
	noise.frequency = 1.0 / float(row["period"])
	noise.fractal_octaves = 2
	return noise


func _build_ground(parent: Node3D, m: RefCounted) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(SIDE * SIDE)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(SIDE * SIDE)
	colors.resize(SIDE * SIDE)
	uvs.resize(SIDE * SIDE)

	for j in SIDE:
		var z := -HALF + j * STEP
		for i in SIDE:
			var x := -HALF + i * STEP
			var s: Array = m.sample(x, z)
			var idx := j * SIDE + i
			heights[idx] = s[0]
			verts[idx] = Vector3(x, s[0], z)
			uvs[idx] = Vector2(x, z) * 0.1
			colors[idx] = s[1]

	var pylon_tint := PylonBite.tint()
	var normals := PackedVector3Array()
	normals.resize(SIDE * SIDE)
	for j in SIDE:
		for i in SIDE:
			var idx := j * SIDE + i
			var left: float = heights[idx - (1 if i > 0 else 0)]
			var right: float = heights[idx + (1 if i < SIDE - 1 else 0)]
			var back: float = heights[idx - (SIDE if j > 0 else 0)]
			var front: float = heights[idx + (SIDE if j < SIDE - 1 else 0)]
			var n := Vector3(left - right, 2.0 * STEP, back - front).normalized()
			normals[idx] = n
			if n.y < PYLON_FACE:
				colors[idx] = colors[idx].lerp(pylon_tint, PylonBite.weight(n.y))

	var indices := PackedInt32Array()
	indices.resize(CELLS * CELLS * 6)
	var w := 0
	for j in CELLS:
		for i in CELLS:
			var a := j * SIDE + i
			var b := a + 1
			var c := a + SIDE
			var d := c + 1
			indices[w] = a
			indices[w + 1] = b
			indices[w + 2] = c
			indices[w + 3] = b
			indices[w + 4] = d
			indices[w + 5] = c
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var scatter: Dictionary = m.get("scatter") if m.get("scatter") is Dictionary else {}
	var relief: Dictionary = scatter.get("relief", {})
	var view := MeshInstance3D.new()
	view.mesh = _relief_mesh(relief, heights, colors) if not relief.is_empty() else mesh
	view.material_override = PaletteMaterials.ground_material()
	preload("res://src/presentation/graphics_preset.gd").register_ground(view)
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	body.add_child(view)
	parent.add_child(body)
	return heights


static func _relief_mesh(row: Dictionary, heights: PackedFloat32Array, coarse: PackedColorArray) -> ArrayMesh:
	var sub: int = row["sub"]
	var amp: float = row["amp"]
	var shade: float = row["shade"]
	var noise := _relief_noise(row)
	var cells := CELLS * sub
	var side := cells + 1
	var step := STEP / sub
	var fine := PackedFloat32Array()
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	fine.resize(side * side)
	verts.resize(side * side)
	colors.resize(side * side)
	uvs.resize(side * side)
	for j in side:
		var z := -HALF + j * step
		for i in side:
			var x := -HALF + i * step
			var idx := j * side + i
			var n := noise.get_noise_2d(x, z)
			fine[idx] = grid_height(heights, x, z) + n * amp
			verts[idx] = Vector3(x, fine[idx], z)
			uvs[idx] = Vector2(x, z) * 0.1
			var ci := mini(i / sub, CELLS - 1)
			var cj := mini(j / sub, CELLS - 1)
			var fx := float(i - ci * sub) / sub
			var fz := float(j - cj * sub) / sub
			var top := coarse[cj * SIDE + ci].lerp(coarse[cj * SIDE + ci + 1], fx)
			var bottom := coarse[(cj + 1) * SIDE + ci].lerp(coarse[(cj + 1) * SIDE + ci + 1], fx)
			colors[idx] = top.lerp(bottom, fz).darkened(clampf(-n, 0.0, 1.0) * shade)
	var normals := PackedVector3Array()
	normals.resize(side * side)
	for j in side:
		for i in side:
			var idx := j * side + i
			var left: float = fine[idx - (1 if i > 0 else 0)]
			var right: float = fine[idx + (1 if i < side - 1 else 0)]
			var back: float = fine[idx - (side if j > 0 else 0)]
			var front: float = fine[idx + (side if j < side - 1 else 0)]
			normals[idx] = Vector3(left - right, 2.0 * step, back - front).normalized()
	var indices := PackedInt32Array()
	indices.resize(cells * cells * 6)
	var w := 0
	for j in cells:
		for i in cells:
			var a := j * side + i
			var c := a + side
			indices[w] = a
			indices[w + 1] = a + 1
			indices[w + 2] = c
			indices[w + 3] = a + 1
			indices[w + 4] = c + 1
			indices[w + 5] = c
			w += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var fine_mesh := ArrayMesh.new()
	fine_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return fine_mesh


func _build_sky(parent: Node3D) -> void:
	var sky_material := PaletteMaterials.workshop_sky_later()
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.85
	environment.fog_enabled = true
	environment.fog_density = 0.0009
	environment.fog_light_color = Palette.SAND.lerp(Palette.VERDIGRIS, 0.35)
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	parent.add_child(world_env)
	PaletteMaterials.settle_sky_on_exit(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 118.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Palette.AMBER.lerp(Color.WHITE, 0.45)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	parent.add_child(sun)
	preload("res://src/presentation/graphics_preset.gd").bind(environment, sun, parent.get_viewport())
