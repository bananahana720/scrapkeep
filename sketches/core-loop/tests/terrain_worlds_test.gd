extends SceneTree

const Terrain := preload("res://src/world/terrain.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const T := preload("res://tests/support/t.gd")

# A later world's ground is built when it is first read, not at setup. Standalone
# Terrain, so the game's own boot (which reads every Spillway row) is not in the way.

var _t := T.new("terrain_worlds_test")
var _errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_two_world()
	_one_world(StageDefs, "default table")
	_one_world(SliceDefs, "slice")
	_out_of_range()
	quit(_t.verdict())


func _two_world() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var terrain := Terrain.new(TwoWorld)
	terrain.build(world)
	_t.eq("two worlds: one map object per row", terrain.maps.size(), 6)
	for i in 6:
		_t.check("two worlds: stage %d built at setup is %s" % [i + 1, i < 3], terrain.is_built(i + 1) == (i < 3))
	_t.eq("two worlds: only world one's roots are children", world.get_children().filter(func(n): return n.name.begins_with("Stage")).size(), 3)
	var r5 := terrain.geometry_root(5)
	_t.check("two worlds: geometry_root(5) returns a root", r5 != null and r5.name == "Stage5")
	for i in 6:
		_t.check("two worlds: stage %d built after the first read of 5" % (i + 1), terrain.is_built(i + 1))
	for i in [4, 5, 6]:
		var r := terrain.geometry_root(i)
		_t.check("two worlds: stage %d root is parked" % i, not r.visible and r.position.y < -1000.0)
		_t.eq("two worlds: stage %d root process mode" % i, r.process_mode, Node.PROCESS_MODE_INHERIT)
	_t.check("two worlds: the active stage 1 is not parked", terrain.geometry_root(1).visible)
	terrain.use(5)
	var map = terrain.map()
	_t.check("two worlds: stage 5 is the gorge", map == terrain.maps[4])
	_t.near("two worlds: height on stage 5 is that map's sample", terrain.height(10.0, -20.0), float(terrain.maps[4].sample(10.0, -20.0)[0]), 0.6)
	_t.check("two worlds: stage 5 root is shown, stage 1 parked", terrain.geometry_root(5).visible and not terrain.geometry_root(1).visible)
	world.free()

	# A fresh terrain: a stage-5 read from another accessor builds world two too.
	var other := Terrain.new(TwoWorld)
	var holder := Node3D.new()
	root.add_child(holder)
	other.build(holder)
	var sp := other.spawn_point(6)
	_t.check("two worlds: spawn_point(6) builds world two", other.is_built(4) and other.is_built(6))
	_t.check("two worlds: spawn_point(6) sits on the ground", sp.y > -100.0)
	other.park_all()
	var late := Terrain.new(TwoWorld)
	var holder2 := Node3D.new()
	root.add_child(holder2)
	late.build(holder2)
	late.park_all()
	late.geometry_root(4)
	_t.eq("two worlds: a root built after park_all is disabled like the rest", late.geometry_root(4).process_mode, late.geometry_root(1).process_mode)
	holder.free()
	holder2.free()


func _one_world(table, label: String) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var terrain := Terrain.new(table)
	terrain.build(world)
	_t.eq("%s: one map object per row" % label, terrain.maps.size(), table.DEFS.size())
	for i in table.DEFS.size():
		_t.check("%s: stage %d built at setup" % [label, i + 1], terrain.is_built(i + 1))
		var row: Dictionary = table.DEFS[i]
		var want = {"spillway": "map_spillway", "gorge": "map_gorge", "reach": "map_reach"}[row["map"]]
		_t.check("%s: map %d is %s in table order" % [label, i + 1, want], String(terrain.maps[i].get_script().resource_path).ends_with(want + ".gd"))
	world.free()


func _out_of_range() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var terrain := Terrain.new(StageDefs)
	terrain.error_sink = func(text: String): _errors.append(text)
	terrain.build(world)
	var last := terrain.spawn_point(StageDefs.COUNT)
	var far := terrain.spawn_point(9)
	_t.eq("out of range: one error logged", _errors.size(), 1)
	_t.check("out of range: stage 9 reads the clamped stage's data", far == last)
	terrain.spawn_point(9)
	_t.eq("out of range: a repeat of the same stage logs nothing more", _errors.size(), 1)
	_t.check("out of range: geometry_root(0) is stage 1's", terrain.geometry_root(0) == terrain.geometry_root(1))
	_t.eq("out of range: a different bad stage logs its own error", _errors.size(), 2)
	_t.check("out of range: each error says which stage", _errors[0].contains("9") and _errors[1].contains("stage 0"))
	world.free()
