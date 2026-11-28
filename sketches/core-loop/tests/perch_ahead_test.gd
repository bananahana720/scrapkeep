extends SceneTree

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const PerchPoints := preload("res://src/world/perch_points.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const EventGround := preload("res://src/world/events/event_ground.gd")

# A park stage's perch lists are read on a worker once its ground is built (terrain.gd _perch_read_ahead), over
# the bare ground. They must be the lists the first perch read made on the main thread through height(), and
# perch_near must take them once. The parks are the three with post tops and the most ledges (islands,
# pit, crown), and the sinkhole, whose cave roofs the worker reads from the floor snapshot. Built whole in the calling frame (SimClock.ticks), as a bot run builds them.

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_islands"}, {"stage": 2, "world": 1, "map": "park_pit"},
	{"stage": 3, "world": 1, "map": "park_crown"}, {"stage": 4, "world": 1, "map": "park_sinkhole"}]}

var _t := T.new("perch_ahead_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	# Terrain3D follows the active camera; without one it prints an ERROR line.
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	SimClock.ticks = true
	var terrain = Terrain.new(TABLE)
	terrain.build(holder)
	for s in range(1, 5):
		var i: int = s - 1
		terrain.stage = s
		terrain.geometry_root(s)
		var id: String = TABLE.DEFS[i].map
		if id == "park_sinkhole":
			_check_roof_floor(terrain, s, i)
		_t.check("%s: the built stage queued a worker perch read" % id, terrain._perch_ahead.has(i))
		var park: Dictionary = terrain.map().park
		var main := {"tops": PerchPoints.derive(park, terrain.height), "blockers": PerchPoints.blockers(park),
			"ledges": PerchPoints.ledges(park, terrain.height)}
		var near := Vector3(terrain.map().spawn.x, 0.0, terrain.map().spawn.y)
		var pick: Vector3 = terrain.perch_near(near, 7)
		_t.check("%s: perch_near took the worker's read" % id, not terrain._perch_ahead.has(i) and terrain._perches.has(i))
		var taken: Dictionary = terrain._perches.get(i, {})
		for key in ["tops", "blockers", "ledges"]:
			_t.check("%s: the worker's %s are the main thread's" % [id, key], str(taken.get(key)) == str(main[key]),
				"%d / %d" % [(taken.get(key, []) as Array).size(), (main[key] as Array).size()])
		_t.eq("%s: the pick is the main thread's pick" % id, pick,
			PerchPoints.pick(main.tops, near, terrain.height, main.blockers, 7, main.ledges))
		_t.check("%s: it found tops or ledges" % id, (main.tops as Array).size() + (main.ledges as Array).size() > 0)
		_check_patched(id, park, terrain, taken)
	_check_prepared(holder)
	# A stage built with no perch ask: its read is pending until the stage is freed, which waits on it.
	var fresh = Terrain.new(TABLE)
	fresh.build(holder)
	fresh.stage = 2
	fresh.geometry_root(2)
	_t.check("an unasked stage holds its read", fresh._perch_ahead.has(1))
	fresh.use(3)
	_t.check("freeing the stages behind waits on and drops their reads", not fresh._perch_ahead.has(0) and not fresh._perch_ahead.has(1))
	SimClock.ticks = false
	quit(_t.verdict())


# With overlays down, perch_near reads the ledges again only near them (PerchPoints.patched_ledges). A raised
# disc stands in for a landed overlay: the patched list must be the whole read over the raised ground.
func _check_patched(id: String, park: Dictionary, terrain, taken: Dictionary) -> void:
	_t.check("%s: the worker kept its unthinned tops" % id, taken.has("found"))
	var bare: Array = taken.get("found", [])
	if bare.is_empty():
		return
	var mid: Vector4 = bare[bare.size() / 2]
	var disc := Vector3(mid.x, mid.z, 18.0)
	var raised := func(x: float, z: float) -> float:
		var y: float = terrain.height(x, z)
		return y + 7.0 if Vector2(x, z).distance_to(Vector2(disc.x, disc.y)) <= disc.z else y
	var whole := PerchPoints.ledges(park, raised)
	var patched := PerchPoints.patched_ledges(park, raised, bare, [disc])
	_t.check("%s: patched ledges are the whole read over the raised ground" % id, str(patched) == str(whole),
		"%d / %d" % [patched.size(), whole.size()])
	_t.check("%s: the raised disc changed the ledges (the check bites)" % id, str(whole) != str(taken.ledges))


# The worker reads the floor from EventGround.snapshot, which carries the cave roofs: over a roof it must answer
# as height() does, and not as the bare ground under it.
func _check_roof_floor(terrain, s: int, i: int) -> void:
	var roofs: Dictionary = terrain._cave_roofs.get(i, {})
	_t.check("park_sinkhole: the stage has cave roofs", not roofs.is_empty())
	var ground = EventGround.snapshot(terrain, s).terrain
	var over := 0
	var differ := []
	for roof in roofs.values():
		var surface = roof.surface
		for cell: Vector2i in surface.cells:
			var k: int = surface.cells[cell][0]
			var p := Vector2((surface.vertices[k].x + surface.vertices[k + 1].x + surface.vertices[k + 2].x) / 3.0,
				(surface.vertices[k].z + surface.vertices[k + 1].z + surface.vertices[k + 2].z) / 3.0)
			var bare: float = Terrain.park_height(terrain._heights[i], terrain._holes[i], terrain._under[i], p.x, p.y)
			if absf(terrain.height(p.x, p.y) - bare) > 0.01:
				over += 1
				if absf(ground.height(p.x, p.y) - terrain.height(p.x, p.y)) > 0.001:
					differ.append(p)
	_t.check("park_sinkhole: over its roofs the worker's floor is height() (%d points where a roof stands over the ground)" % over,
		over > 0 and differ.is_empty(), str(differ.slice(0, 3)))



# A Dispatcher on its way with an overlay down: prepare_perches reads the ledges near it again on a worker, and
# perch_near takes that read, the lists the main thread reads through height() with the overlay down. A slab
# 7 m over a found top stands in for a landed slide, as an OverlayMap profile like prepare_overlay makes.
func _check_prepared(holder: Node3D) -> void:
	var terrain = Terrain.new(TABLE)
	terrain.build(holder)
	terrain.stage = 2
	terrain.geometry_root(2)
	var m = _overlay_map(terrain, 1)
	terrain.prepare_perches()
	_t.check("with no overlay down, nothing is read again", not terrain._perch_patch.has(1))
	Terrain._settle_perch_read(terrain._perch_ahead[1])
	var found: Array = terrain._perch_ahead[1].out.get("found", [])
	var mid: Vector4 = found[found.size() / 2]
	var site := {"id": "test_slab", "at": [mid.x, mid.z], "size": [30.0, 0.0, 30.0], "yaw_deg": 0.0, "y": mid.y + 7.0}
	m.profiles["test_slab_after"] = {"site": site, "surface": EventGround.span_surface(site, 0.0)}
	terrain.overlays.append("test_slab_after")
	var park: Dictionary = m.park
	var main := {"tops": PerchPoints.derive(park, terrain.height), "ledges": PerchPoints.ledges(park, terrain.height)}
	terrain.prepare_perches()
	_t.check("an overlay down queues a worker read near it", terrain._perch_patch.has(1))
	var queued = terrain._perch_patch.get(1)
	terrain.prepare_perches()
	_t.check("asking again with the same overlays queues nothing new", terrain._perch_patch.get(1) == queued)
	var near := Vector3(mid.x, 0.0, mid.z)
	var pick: Vector3 = terrain.perch_near(near, 3)
	var taken: Dictionary = terrain._perches.get(1, {})
	_t.check("perch_near took the worker's read", not terrain._perch_patch.has(1) and is_same(taken.get("ledges"), queued.out.get("ledges")))
	for key in ["tops", "ledges"]:
		_t.check("the prepared %s are the main thread's with the overlay down" % key, str(taken.get(key)) == str(main[key]),
			"%d / %d" % [(taken.get(key, []) as Array).size(), (main[key] as Array).size()])
	_t.check("the overlay changed the ledges (the check bites)", str(main.ledges) != str(PerchPoints.thin(found)))
	_t.eq("the pick is the main thread's pick", pick, PerchPoints.pick(main.tops, near, terrain.height, taken.blockers, 3, main.ledges))

	# A filling collapse lays a new surface every step: no ask waits on the read still running, a finished read
	# for the old surface gives way to one for the new, and one made for a surface since replaced is not used.
	var fill = Terrain.new(TABLE)
	fill.build(holder)
	fill.stage = 2
	fill.geometry_root(2)
	var fm = _overlay_map(fill, 1)
	fm.profiles["test_slab_after"] = {"site": site, "surface": EventGround.span_surface(site, 0.0)}
	fill.overlays.append("test_slab_after")
	Terrain._settle_perch_read(fill._perch_ahead[1])
	fill.prepare_perches()
	var first = fill._perch_patch.get(1)
	fm.profiles["test_slab_after"] = {"site": site, "surface": EventGround.span_surface(site, 0.0)}
	if not Terrain._read_done(first):
		fill.prepare_perches()
		_t.check("an ask while the old read runs keeps it and queues nothing", fill._perch_patch.get(1) == first and first.has("task"))
	Terrain._settle_perch_read(first)
	fill.prepare_perches()
	var second = fill._perch_patch.get(1)
	_t.check("a finished read for the old surface gives way to one for the new", second != null and second != first)
	fm.profiles["test_slab_after"] = {"site": site, "surface": EventGround.span_surface(site, 0.0)}
	fill.perch_near(near, 3)
	var used: Dictionary = fill._perches.get(1, {})
	_t.check("a read for a surface since replaced is not used, and the main thread's read is the same",
		not is_same(used.get("ledges"), second.out.get("ledges")) and str(used.get("ledges")) == str(main.ledges))

	# The overlays change between the ask and the spawn: the read made for the old list is dropped.
	var later = Terrain.new(TABLE)
	later.build(holder)
	later.stage = 2
	later.geometry_root(2)
	var lm = _overlay_map(later, 1)
	lm.profiles["test_slab_after"] = m.profiles["test_slab_after"]
	later.overlays.append("test_slab_after")
	later.prepare_perches()
	later.overlays.clear()
	var bare := {"tops": PerchPoints.derive(park, later.height), "ledges": PerchPoints.ledges(park, later.height)}
	later.perch_near(near, 3)
	_t.check("a read made for overlays since lifted is dropped", not later._perch_patch.has(1)
		and str(later._perches.get(1, {}).get("ledges")) == str(bare.ledges))


# The stage's map as an OverlayMap, its loaded fields copied as EventGround.prepare_overlay copies them.
func _overlay_map(terrain, i: int):
	var current = terrain.maps[i]
	var m = EventGround.OverlayMap.new("")
	for property in current.get_property_list():
		if int(property.usage) & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE) and property.name != "script":
			var value = current.get(property.name)
			m.set(property.name, value.duplicate(true) if value is Dictionary or value is Array else value)
	m.source = current
	terrain.maps[i] = m
	return m
