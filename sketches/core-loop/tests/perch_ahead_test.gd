extends SceneTree

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const PerchPoints := preload("res://src/world/perch_points.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

# A park stage's perch lists are read on a worker once its ground is built (terrain.gd _perch_read_ahead), over
# the bare ground. They must be the lists the first perch read made on the main thread through height(), and
# perch_near must take them once. The parks are the three with post tops and the most ledges (islands,
# pit, crown). Built whole in the calling frame (SimClock.ticks), as a bot run builds them.

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_islands"}, {"stage": 2, "world": 1, "map": "park_pit"},
	{"stage": 3, "world": 1, "map": "park_crown"}]}

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
	for s in range(1, 4):
		var i: int = s - 1
		terrain.stage = s
		terrain.geometry_root(s)
		var id: String = TABLE.DEFS[i].map
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
