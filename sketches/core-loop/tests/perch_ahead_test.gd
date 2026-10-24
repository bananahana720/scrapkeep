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
			var bare: float = Terrain._park_height(terrain._heights[i], terrain._holes[i], terrain._under[i], p.x, p.y)
			if absf(terrain.height(p.x, p.y) - bare) > 0.01:
				over += 1
				if absf(ground.height(p.x, p.y) - terrain.height(p.x, p.y)) > 0.001:
					differ.append(p)
	_t.check("park_sinkhole: over its roofs the worker's floor is height() (%d points where a roof stands over the ground)" % over,
		over > 0 and differ.is_empty(), str(differ.slice(0, 3)))

