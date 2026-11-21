extends RefCounted

const EventGround := preload("res://src/world/events/event_ground.gd")

const Palette := preload("res://src/core/palette.gd")
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

# A park map id (`--table=park`, park_defs.gd) reads its park file: src/world/park/<id>.json once a
# stage unit (KD1 to KD6) lands it, else the stage-1 stand-in under assets/park/ (KD0). A park id
# with neither stands on the old map of the same stage, so the table still runs end to end.
# A park file's ground is park_terrain.gd (KB4, PARK.md section 3): its bake as Terrain3D regions
# and a tiled trimesh over the 1.6 km square. A park stage is never built with its world: the
# first stage builds at setup, a later one when first read or from prepare(), which builds it
# on worker threads. world.gd calls prepare(stage + 1) when the stage's Warden is engaged (or its
# gates open on a stage with no Warden), so the launch finds the next stage built (KB4b); use()
# frees any park stage that is neither active nor next, so at most two are resident.
const PARK_FILES := ["res://src/world/park/%s.json", "res://assets/park/%s_stage1.json"]
const MAPS := {"spillway": Spillway, "gorge": Gorge, "reach": Reach, "dig": Dig, "highdraft": Highdraft, "dig_deep": DigDeep, "highdraft_crown": HighdraftCrown}

# Owned by writer D (world). The spine reads only the terrain API block below.
#
# Each stage is its own map. The first world's stages are built once at setup (every
# stage of a one-world table), so a stage change is a cheap swap inside the stage_entered
# handler and never a hitch in the launch. A later world's stages are built, all together,
# the first time anything reads one of them (_ensure). Height
# queries read the built grid and interpolate the same two triangles per cell the
# collider uses, so what the spine, combat and build ask about the ground is exactly
# the ground the ball rolls on.

const HALF := 200.0
const STEP := 2.0
const CELLS := int(2.0 * HALF / STEP)
const SIDE := CELLS + 1
# Steeper than PylonBite.FACE (the normal's y below it) takes the pylon tint: the ball's
# pylon bites a face that leans less than 60 degrees off vertical (augments.gd).
const PYLON_FACE := PylonBite.FACE
const PARK_DEPTH := 5000.0

var maps: Array = []
var stage := 1
# The flood the world runs, so material_at can say "water" where it is.
var flood
var environment: Environment
# Moss's bay (bay.gd), set by world, for the read-only bay queries below.
var bay
# The active stage's live overlay heights (terrain changes that have landed, and the
# rubble standing before a cave-in), by the map's overlay ids.
var overlays: Array[String] = []

# Each stage number outside the table is logged once through this (a test sets a sink so the
# errors can be read; with none set it is a push_error), then clamped as before.
var range_errors := {}
var error_sink: Callable

# Per global stage (index stage - 1): the stage's root (null until built) and its grid
# (empty until built). The world of each row, so a read can build its whole world.
var _roots: Array = []
var _heights: Array[PackedFloat32Array] = []
var _worlds: Array[int] = []
var _parent: Node3D
# The physics frame use() last brought a stage up in (top_surface waits SETTLE_FRAMES past it).
var _used_frame := -1000
var _arena := false
# Per global stage: whether it stands on a park file, its park ground node (null until built
# or preparing), and its hole cells and their floors (empty off the park).
var _is_park: Array[bool] = []
var _grounds: Array = []
var _holes: Array[PackedByteArray] = []
var _under: Array[PackedFloat32Array] = []
var _cave_roofs := {}
var _placement_holes := {}
# Two Terrain3D render nodes made at setup (park_terrain.gd make_render), each lent to one
# resident park stage; _render_owner holds the stage index using each, or -1.
var _render: Array[Node3D] = []
var _render_owner: Array[int] = []
# The last use()'s main-thread cost, and how many frames a park stage times after its swap
# (park_terrain.gd meter); PARK.md section 9 caps a frame at 33 ms.
var last_use_usec := 0
const SWAP_METER_FRAMES := 120
# Where a park stage's ride sensors publish (park_recipes.gd _sensor): publish(kind, at). world.gd sets the game
# bus's world_fact.emit before build(); with none set the rows place without sensors.
var publish: Callable
# Per global stage: whether its park ground builds on worker threads, so its rows place the same way (KB9).
var _threaded: Array[bool] = []
# Per stage index: {"tops": [Vector3], "blockers": [zone]} for perch_near, derived on the first ask.
var _perches := {}
# A park stage's perch lists read on a worker once its ground is built (_perch_read_ahead): {i: {task, out}}.
var _perch_ahead := {}
# The active park stage's perch lists read again with its overlays down, on a worker, once a Dispatcher is on
# its way (prepare_perches): {i: {sig, task, out}}.
var _perch_patch := {}

# A park stage left memory (_free_stage), by stage number, so a module that hung nodes on its
# root (world.gd's contraptions) drops them.
signal stage_freed(index: int)
# A park stage's ground and props were built and its rows started placing, by stage number.
signal stage_built(index: int)

# A first stage built behind the menu (build threaded_first).
var _threaded_first := false


func _init(table = StageDefs) -> void:
	var parks := _read_parks_together(table)
	for row in table.DEFS:
		var id := String(row["map"])
		# A park id that repeats in the table gets its own map past the first, as before.
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


# MENU-READY: the park table's six park files are read and checked at setup, 105 to 185 ms one after
# another on the cloud. Read them on worker threads at once instead; a park that fails its schema is
# left to map_named, which reports it as before.
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
	# Read once on first need and marked read before they are filled: fill them here, so no worker sees one half built.
	ParkSchema._registry()
	ParkRecipes.origin("")
	if paths.size() < 2:
		return {}
	var ids: Array = paths.keys()
	var read := []
	read.resize(ids.size())
	# Godot 4.7.2 fills an untyped operator's cache the first time its line runs, and readers take no lock: two
	# workers on the same cold line can call a half-written cache and crash (a rare SIGABRT at Game setup). The
	# first stage's park reads here first, which runs every line the other parks share once before any worker
	# does (a line coverage read of the six parks found no shared operator line left cold); the rest read at once.
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


# The world the current stage is in (1 Spillway, 2 the Dig, 3 the Highdraft).
func world() -> int:
	return _worlds[_index(stage)]


func map_for(index: int) -> RefCounted:
	return maps[_index(index)]


# threaded_first builds a park first stage on worker threads too, as prepare() does, so a played
# game shows its menu without waiting on it (MENU-READY); any read of the ground finishes it.
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
			if _is_park[i] and threaded_first and _worker_builds():
				_build_park_stage(i, true)
			else:
				_build_stage(i)


# True once this stage's ground and props exist.
func is_built(index: int) -> bool:
	return is_ready(index)


# True once this stage's ground and props exist; a park stage still building on worker threads
# is not ready.
func is_ready(index: int) -> bool:
	var i := _index(index)
	return _roots[i] != null and (not _is_park[i] or _grounds[i].is_ready())


# True when this park stage was built on worker threads (a played game or a frame-capture bot run).
func built_threaded(index: int) -> bool:
	return _threaded[_index(index)]


# The park ground node of a park stage (park_terrain.gd), or null.
func park_ground(index: int) -> Node3D:
	return _grounds[_index(index)]


# Starts building a park stage on worker threads; the main thread only adds the finished
# pieces a few a frame. A no-op for an old map or a stage already built or building.
func prepare(index: int) -> void:
	var i := _index(index)
	if not _is_park[i] or _roots[i] != null or _parent == null:
		return
	_build_park_stage(i, _worker_builds())


# A played game builds park stages on worker threads and attaches them inside a wall-clock
# budget. A bot run (SimClock.ticks) builds them whole in the calling frame instead: the
# frame a threaded build finishes on depends on CPU load, and the static bodies it adds to
# the shared physics world move the solver's results, so a seed stops replaying.
static func _worker_builds() -> bool:
	return threaded_in_bot_runs or not SimClock.ticks


# Frame-capture bot runs (tools/bot_run.gd --threaded-stages=1) build park stages threaded
# as a played game does, so the next stage's one-frame build is not in the capture. Only
# that build moves; the hit-stop clock stays on ticks. The seed no longer replays exactly.
static var threaded_in_bot_runs := false


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


# Stage i's root name, taken back from a freed root the Reaper has not renamed yet.
func _hold_name(i: int) -> String:
	var stage_name := "Stage%d" % (i + 1)
	var old := _parent.get_node_or_null(NodePath(stage_name)) if _parent != null else null
	if old != null and old.get_node_or_null("Reaper") != null:
		Reaper.yield_name(old)
	return stage_name


# A park stage: the holder enters the tree parked, then its ground builds, at once (threaded
# false) or on worker threads, and the props follow when the ground is done.
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
	# A stage that is not processing (the arena) still has to finish when it is read.
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
	# The park rows (KB9): every row naming a recipe, with its collider and ride sensor, placed on the height() floor.
	if maps[i] is ParkMap:
		ParkRecipes.build_placed(_roots[i], maps[i].park, _park_floor_at.bind(_heights[i], _placement_holes[i], _under[i]), publish, _threaded[i], maps[i].line_within)
	Scatter.build_chunked(_roots[i], maps[i], ground_callable(i + 1), _worker_builds())
	_perch_read_ahead(i)
	stage_built.emit(i + 1)


# A park stage's placed rows (park_recipes.gd Placer, "ParkRows" under its root), or null.
func park_rows(index: int) -> Node:
	var root: Node3D = _roots[_index(index)]
	return root.get_node_or_null("ParkRows") if root != null else null


# True once a park stage's rows are all placed (an old map has none to place).
func rows_ready(index: int) -> bool:
	var rows := park_rows(index)
	return not _is_park[_index(index)] or (rows != null and rows.is_ready())


# Builds the whole world a stage belongs to, if any of it is not built yet, and returns
# the stage's clamped index. Every read of the ground goes through here. A park stage builds
# alone, or finishes its worker build on the spot when it is read before it is done.
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
		# The first stage read before it was built (a run started on the menu) places its rows now
		# too; a next stage's rows still place across the swap.
		if i == 0 and _threaded_first:
			_threaded[i] = false
		_grounds[i].finish()
	return i


# Swap the active stage's geometry in. Synchronous, so the flow's spawn and beacon
# queries straight after stage_entered read the new stage. The idle stages stay in the
# physics world, hidden and parked far below: moving a body is cheap, while adding a
# trimesh back to the world rebuilds its tree (measured at about 34 ms a swap).
func use(index: int) -> void:
	var started := Time.get_ticks_usec()
	_used_frame = Engine.get_physics_frames()
	# Park stages that are neither the target nor its next leave first, so a target that is
	# not resident (a new run back on stage 1) finds a free Terrain3D render node to draw into.
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


# Only the active park stage's Terrain3D node draws (none in the arena).
func _show_render() -> void:
	for n in _render.size():
		_render[n].visible = not _arena and _render_owner[n] == stage - 1


# A park stage leaves memory (neither active nor next); a later read builds it again. Its
# Terrain3D node goes back to the pool, regions and all, until the next stage replaces them.
func _free_stage(i: int) -> void:
	var slot := _render_owner.find(i)
	if slot >= 0:
		_render_owner[slot] = -1
	# A ground still attaching must not add one more region to the render node it just gave up
	# in the frames before queue_free lands; the stage that takes the node may already own it.
	if _grounds[i] != null:
		_grounds[i].set_process(false)
	# A bot run frees it whole, as before: removals at a load-dependent frame would move the shared physics world.
	if _worker_builds():
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


# The arena is not a stage: every map is hidden and its colliders leave the physics
# world until the next use(). Putting a trimesh back rebuilds its tree, which an arena
# entry or a T replay can afford and a launch swap cannot, so only this path does it.
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


# A freed stage's nodes leave a few a frame, parked and hidden meanwhile: one queue_free of a whole park stage (2917
# shapes) cost 33-50 ms in the swap frame headless (park_swap_test, artifacts/local/c9). take() disables the root, so
# nothing under it processes and its bodies leave the space at once; then deepest first, a physics body whole, the root last.
class Reaper extends Node:
	const BUDGET_USEC := 3000

	static func take(root: Node3D) -> void:
		# Hidden and disabled is enough: its bodies leave the space, so it stays where it stood rather
		# than moving every body and transform under it on the swap tick (scrapkeep#494).
		root.visible = false
		# One switch stops the whole stage (its bodies leave the space with it): two propagate_calls over a park
		# stage's ~20k nodes cost 29 ms in the swap frame, this 9.5 (bot run, stage 1 to 2). The Reaper runs ALWAYS.
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
			# A scripted node can be locked by its own pending work (the scatter refuses free()), so it leaves the
			# tree now and is deleted at the frame's end, as queue_free always did.
			if node.get_script() != null:
				node.get_parent().remove_child(node)
				node.queue_free()
			else:
				node.free()

	# A stage built again (a new run's stage 1) takes the name back while this one empties. The rename
	# tells every node under the root its path changed, 10 ms over a park stage's ~20k nodes on the swap
	# tick on the cloud (scrapkeep#494), so it waits for the Reaper's first frame, or for a stage built
	# under the same name before then (_hold_name).
	static func yield_name(root: Node) -> void:
		if not String(root.name).begins_with("Freed"):
			root.name = "Freed%s" % root.name


func geometry_root(index: int) -> Node3D:
	return _roots[_ensure(index)]


# The terrain API the spine and the other modules read through ctx.terrain (see
# CONTRACTS.md).
func height(x: float, z: float) -> float:
	var h := _floor(_ensure(stage), x, z)
	if overlays.is_empty():
		return h
	var ground := h
	var m = map()
	for id in overlays:
		h = maxf(h, m.overlay_height(id, x, z, ground))
	return h


# height() at many (x, z) points at once, each answer equal to height()'s. A telegraph paints over about
# 500 points a ring, and a Warden pulse's two rings through height() one point at a time were 20 ms of a
# flume frame on the cloud. The stage and map are looked up once, and an overlay whose footprint disc
# misses the points' bounds is left out, as its overlay_height answers -INF there.
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
			var centre := ParkMap._v2(site.at)
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


# height() with no overlay: the ground a ball rolling under an overlay deck (a landed ramp
# whose sheet spans a gap) stands on.
func floor_height(x: float, z: float) -> float:
	return _floor(_ensure(stage), x, z)


func drop_point(x: float, z: float, clearance := 1.8) -> Vector3:
	return Vector3(x, height(x, z) + clearance, z)


# The surface a ball rolling at (x, z) stands on, as {"point", "normal"}: the highest permanent face within
# SURFACE_REACH_M over height(), else height() and its slope. Permanent means a body this module built for the stage
# and nothing moves or breaks: the ground's own tiles and the placed park rows' decks and props (_is_surface). A
# moving body, a destructible, a door, a device, a mast or an ice slab never answers; a landed overlay sheet or a
# cave roof answers through height(), which already carries them, so no face below height() counts. With a radius, the normal is the plane that fits that surface over the disc of that radius, and the
# point lies on the plane under (x, z), lowered to the disc's lowest sample, so a flat disc set on it stands proud
# nowhere. {} while the stage's colliders are not yet where a query finds them: its rows still placing, or the
# stage brought up from parking under SETTLE_FRAMES physics frames ago (a moved body answers from its old place
# until the next step); ask again on a later tick.
const SURFACE_REACH_M := 40.0
# How far under height() a face may sit and still be the ground's (a tile's trimesh against height()'s triangles).
const SURFACE_BELOW_M := 0.05
# Faces a ray steps through before it gives up and answers height(): stacked doors, crates and pieces can sit over a deck.
const SURFACE_SKIPS := 8
const SETTLE_FRAMES := 2
const SURFACE_RING := 16


func top_surface(x: float, z: float, radius := 0.0) -> Dictionary:
	if not rows_ready(stage) or Engine.get_physics_frames() < _used_frame + SETTLE_FRAMES:
		return {}
	var space: PhysicsDirectSpaceState3D = null
	if _parent != null and _parent.is_inside_tree():
		space = _parent.get_world_3d().direct_space_state
	var centre := _surface_hit(space, x, z)
	if radius <= 0.0:
		return centre
	# A least-squares plane y = a + b dx + c dz through the centre and a ring of samples.
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
	# The ring is symmetric about (x, z), so the cross terms vanish and each slope is its own ratio.
	var b := sxy / sxx
	var c := szy / szz
	var lowest := INF
	for p in samples:
		lowest = minf(lowest, p.y - (mean_y + b * (p.x - x) + c * (p.z - z)))
	return {"point": Vector3(x, mean_y + lowest, z), "normal": Vector3(-b, 1.0, -c).normalized()}


func _surface_hit(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Dictionary:
	var ground := height(x, z)
	if space != null:
		var top := Vector3(x, ground + SURFACE_REACH_M, z)
		var query := PhysicsRayQueryParameters3D.create(top, Vector3(x, ground - SURFACE_BELOW_M, z), 1)
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


# A collider top_surface stands a thing on: a plain static body under a node this module built for the current
# stage, the park ground's tiles (_grounds), the placed park rows (park_rows), or an old map's Ground body. Every
# other world-layer body hangs elsewhere (enemies, masts, the boss arena, the element field's ice, activities'
# devices and caches, the destructibles, the barge: the game root; contraptions' doors, barges and lifts: their own
# node under the stage root) or moves (an AnimatableBody3D, such as the isle's tip under its landmark row).
func _is_surface(collider: Object) -> bool:
	if not (collider is StaticBody3D) or collider is AnimatableBody3D:
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


# A perch top for the Dispatcher within PerchPoints.RANGE_M of `point`: a park post top or a landform
# top, 6 to 10 m up and clear of colliders (perch_points.gd); Vector3.INF when the stage has none,
# and the Dispatcher builds its own mast. `salt` varies the pick; one salt always picks the same.
func perch_near(point: Vector3, salt := 0) -> Vector3:
	var m = map()
	if not (m is ParkMap) or not m.ok:
		return Vector3.INF
	var i := _index(stage)
	if not _perches.has(i):
		# Built first, so a stage the ask builds queues its read and this takes it.
		_ensure(stage)
		var ahead := _take_perch_ahead(i)
		# A worker read made for other overlays is left to settle as the stage leaves the tree.
		var patch: Dictionary = _perch_patch.get(i, {})
		_perch_patch.erase(i)
		# The worker read the bare ground; height() matches it only while no overlay or cave roof stands on it.
		# With overlays down (a landed slide or lip), only the ledges near them are read again: the whole read
		# on the main thread was an 870 ms frame on the cloud at the Dig's first Dispatcher.
		# A cave roof the worker read stands in its snapshot; one lowered since (a cave-in) changes the ground.
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


# A Dispatcher is on its way (an arrival a second out). With overlays down on the active park stage, its ledges
# near them are read again on a worker now, over the bare read's floor with those overlays down, as height()
# reads them; perch_near takes the result while the overlays and roofs are still the ones read. Read in the
# spawn frame, it was about 100 ms on the cloud at the Spillway's first Dispatcher with two slides down.
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
	# Nothing here waits: a read still running (the bare one, or a patch for overlays since changed, as a
	# filling collapse changes its surface every step) is asked about again on a later step.
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
	# The roofs are copied on the worker: one lowered meanwhile replaces its surface, so the copy reads the
	# old one, and the pristine check at the take drops the result.
	var snap := EventGround.snapshot(self, i + 1, false)
	for id in overlays:
		snap = snap.with_profile({"site": m.profiles[id].site, "surface": m.profiles[id].surface})
	var out := {}
	var patch := {"sig": sig, "out": out, "task": _queue_perch_patch(m.park, snap, ahead.out.found, discs, out)}
	_perch_patch[i] = patch
	_settle_on_exit(_roots[i], patch)


# The overlays down and the surface each stands on: a patched read is good only for the same list.
func _overlay_sig(m) -> Array:
	return overlays.map(func(id: String) -> Array: return [id, m.profiles[id].surface] if m.profiles.has(id) else [id])


static func _queue_perch_patch(park: Dictionary, snap: RefCounted, bare_found: Array, discs: Array, out: Dictionary) -> int:
	var ground := func(x: float, z: float) -> float: return snap.terrain.height(x, z)
	return WorkerThreadPool.add_task(func():
		snap.copy_roofs()
		out.merge({"tops": PerchPoints.derive(park, ground), "ledges": PerchPoints.patched_ledges(park, ground, bare_found, discs)}),
		true, "perch patch")


# Whether a worker perch read has finished (or was never queued), so settling it does not wait.
static func _read_done(read: Dictionary) -> bool:
	return not read.has("task") or WorkerThreadPool.is_task_completed(read.task)


# Waits on a stage's patched perch read and drops it; the entry ({sig, out}), or {} when none was queued.
func _take_perch_patch(i: int) -> Dictionary:
	if not _perch_patch.has(i):
		return {}
	var patch: Dictionary = _perch_patch[i]
	_perch_patch.erase(i)
	_settle_perch_read(patch)
	return patch


# A disc (Vector3 x, z, radius) around each overlay down, for PerchPoints.patched_ledges; null when an
# overlay's footprint is unknown (not an OverlayMap profile), and the whole read runs again.
func _overlay_discs(m) -> Variant:
	var discs: Array = []
	for id in overlays:
		if not (m is EventGround.OverlayMap) or not m.profiles.has(id):
			return null
		var site: Dictionary = m.profiles[id].site
		discs.append(Vector3(float(site.at[0]), float(site.at[1]), ParkMap.footprint_half_extents(site).length()))
	return discs


# The first perch read of a stage walked every landform sample's rings through height(): 80 to 390 ms of one
# frame by park (stage 6 about 300 ms in a played run, PR #372). Read them on a worker as soon as the ground
# is built, over the stage's floor as height() reads it with no overlay down (EventGround.snapshot: the ground
# and its cave roofs); perch_near takes them while no roof has been lowered since, reading again only near overlays.
func _perch_read_ahead(i: int) -> void:
	var m = maps[i]
	if not (m is ParkMap) or not m.ok or _perch_ahead.has(i) or _perches.has(i):
		return
	var out := {}
	# The next stage is not active, so its roofs are copied on the worker (see EventGround.snapshot).
	var ahead := {"out": out, "task": _queue_perch_read(m.park, EventGround.snapshot(self, i + 1, false), out)}
	_perch_ahead[i] = ahead
	_settle_on_exit(_roots[i], ahead)


# Static, so the worker holds no reference to this terrain: it reads only the park and the floor snapshot (copies of the roofs).
static func _queue_perch_read(park: Dictionary, floor_snapshot: RefCounted, out: Dictionary) -> int:
	# A lambda holds the snapshot; a bound method would not keep it alive.
	var ground := func(x: float, z: float) -> float: return floor_snapshot.terrain.height(x, z)
	return WorkerThreadPool.add_task(func():
		floor_snapshot.copy_roofs()
		var found := PerchPoints.found(park, ground)
		out.merge({"tops": PerchPoints.derive(park, ground), "blockers": PerchPoints.blockers(park), "found": found, "ledges": PerchPoints.thin(found)}),
		true, "perch read")


# A task left unwaited when the engine quits aborts the process: the stage's root waits on its read as it
# leaves the tree, which a quit and a teardown both do, whether or not this terrain is still referenced.
static func _settle_on_exit(root: Node, ahead: Dictionary) -> void:
	root.tree_exiting.connect(func(): _settle_perch_read(ahead), CONNECT_ONE_SHOT)


static func _settle_perch_read(ahead: Dictionary) -> void:
	if ahead.has("task"):
		WorkerThreadPool.wait_for_task_completion(ahead.task)
		ahead.erase("task")


# Waits on a stage's worker perch read and drops it; its lists, or {} when none was read.
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


# For the element and material table (TADR-009, owned by build): what lies at or
# under this point, as {"material", "surface_y"}, or {} off the map. Where the flood
# stands over the ground, the answer is its water at the live surface height, so a
# frost or arc resolves against the same surface the ball floats on.
func material_at(point: Vector3) -> Dictionary:
	if not contains(point):
		return {}
	var ground := height(point.x, point.z)
	if flood != null and flood.in_basin(point):
		var surface: float = flood.surface_y()
		if surface > ground:
			return {"material": "water", "surface_y": surface}
	return {"material": map().material_at(point.x, point.z), "surface_y": ground}


# v2 W6 world: the landmark's light (INF on a map without one), the height band a
# point is in ("sky", "shelf", "undercroft", or "" on a map without bands), and the
# bay's reads for the shop UI and the lounge.
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


# The stage's ground at (x, z): the grid's two triangles, or a hole cell's floor beneath.
func cave_roof(id: String) -> Dictionary:
	return _cave_roofs.get(stage - 1, {}).get(id, {})


func _floor(i: int, x: float, z: float) -> float:
	var roof_y := -INF
	for roof in _cave_roofs.get(i, {}).values():
		roof_y = maxf(roof_y, roof.surface.height(Vector2(x, z)))
	if roof_y > -INF:
		return maxf(roof_y, _retained_park_height(_heights[i], _holes[i], x, z))
	if _is_park[i]:
		return _park_height(_heights[i], _holes[i], _under[i], x, z)
	return _grid_height(_heights[i], x, z)


static func _retained_park_height(heights: PackedFloat32Array, holes: PackedByteArray, x: float, z: float) -> float:
	var grid := Vector2((x + ParkTerrain.HALF) / ParkTerrain.STEP, (z + ParkTerrain.HALF) / ParkTerrain.STEP)
	var cell := Vector2i(floori(grid.x), floori(grid.y))
	var result := -INF
	# The footprint is closed: a rim edge or corner can belong to four ground cells.
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


static func _park_height(heights: PackedFloat32Array, holes: PackedByteArray, under: PackedFloat32Array, x: float, z: float) -> float:
	var floor_y := ParkTerrain.hole_floor(holes, under, x, z)
	return _grid_height(heights, x, z) if is_nan(floor_y) else floor_y


static func _park_ground_at(x: float, z: float, clearance: float, heights: PackedFloat32Array, holes: PackedByteArray, under: PackedFloat32Array) -> Vector3:
	return Vector3(x, _park_height(heights, holes, under, x, z) + clearance, z)


# height()'s floor as (x, z) -> float, for park_recipes.gd placement (safe on a worker thread).
static func _park_floor_at(x: float, z: float, heights: PackedFloat32Array, holes: PackedByteArray, under: PackedFloat32Array) -> float:
	return _park_height(heights, holes, under, x, z)


func vault_point(index: int) -> Vector3:
	var v: Vector2 = map_for(index).vault
	return Vector3(v.x, _floor(_ensure(index), v.x, v.y), v.y)


func _index(index: int) -> int:
	_pad_rows()
	if index < 1 or index > maps.size():
		_range_error(index)
	return clampi(index, 1, maps.size()) - 1


# Test doubles append maps and the original per-stage arrays themselves (dig_zone_test and
# others); the park arrays catch up here so those doubles keep working.
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


# The grid is the old maps' 201 by 201 or a park's 801 by 801 (park_terrain.gd), told apart by
# its size; both are 2 m cells centred on the origin.
static func _grid_height(heights: PackedFloat32Array, x: float, z: float) -> float:
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
	return Vector3(x, _grid_height(heights, x, z) + clearance, z)


# The map's scatter rows, added after every other child of the stage so the nodes' sibling order
# (and every path a test or a tool keys on it) stays what it was.
static func _build_scatter(holder: Node3D, m: RefCounted, heights: PackedFloat32Array) -> void:
	var scatter: Dictionary = m.get("scatter") if m.get("scatter") is Dictionary else {}
	if (scatter.get("kit", []) as Array).is_empty():
		return
	var relief: Dictionary = scatter.get("relief", {})
	var ground := _ground_at.bind(heights)
	if not relief.is_empty():
		ground = _relief_at.bind(heights, _relief_noise(relief), float(relief["amp"]))
	Scatter.build(holder, m, ground)


# The relief view's height at (x, z): the collider's grid plus the same seeded noise the view mesh draws.
static func _relief_at(x: float, z: float, clearance: float, heights: PackedFloat32Array, noise: FastNoiseLite, amp: float) -> Vector3:
	return Vector3(x, _grid_height(heights, x, z) + noise.get_noise_2d(x, z) * amp + clearance, z)


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
			# Form mirrors function: any face a pylon can bite reads as concrete.
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
			# Clockwise from above is Godot's front-face winding, and a trimesh
			# collider only collides on its front faces.
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

	# The collider keeps the 2 m grid; a map with a relief row draws a finer, noisier view.
	# A map without a scatter table (a test double) has no relief and no scatter row.
	var scatter: Dictionary = m.get("scatter") if m.get("scatter") is Dictionary else {}
	var relief: Dictionary = scatter.get("relief", {})
	var view := MeshInstance3D.new()
	view.mesh = _relief_mesh(relief, heights, colors) if not relief.is_empty() else mesh
	view.material_override = Palette.ground_material()
	preload("res://src/presentation/graphics_preset.gd").register_ground(view)
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	body.add_child(view)
	parent.add_child(body)
	return heights


# The visual ground at STEP / sub: the collider's own triangles (the same diagonal per sub-cell,
# so each vertex lies on the coarse face) plus a seeded noise offset under amp metres, with the
# coarse colours interpolated and the dips shaded.
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
			fine[idx] = _grid_height(heights, x, z) + n * amp
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
	var sky_material := Palette.workshop_sky_later()
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
	Palette.settle_sky_on_exit(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 118.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Palette.AMBER.lerp(Color.WHITE, 0.45)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	parent.add_child(sun)
	preload("res://src/presentation/graphics_preset.gd").bind(environment, sun, parent.get_viewport())
