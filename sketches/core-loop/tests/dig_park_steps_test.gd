extends SceneTree

# Rule (perf lane D): a Dig park stage built ahead on worker threads takes its park pass a step a
# frame (dig_scenery.gd ParkBuild) instead of all in its entry frame, and the result is the one the
# whole pass builds: the same batches, in the same order, at the same placements. The same holds
# for a park stage's contraptions built a device a frame (contraptions.gd begin/build_next/finish).
# Fixture: a one-stage table of park_sinkhole built whole (bot ticks); no check here is timed.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const Contraptions := preload("res://src/world/contraptions.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 2, "map": "park_sinkhole"}]}

var t := T.new("dig_park_steps_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	SimClock.ticks = true
	var terrain = Terrain.new(TABLE)
	terrain.build(holder)
	var map = terrain.map_for(1)
	var ground: Callable = terrain.ground_callable(1)
	t.check("a bot run's stage is not built threaded, so it keeps the entry build", not terrain.built_threaded(1))

	var whole_root := Node3D.new()
	holder.add_child(whole_root)
	var whole := DigScenery.build_park(whole_root, map, ground, 1)

	var stepped_root := Node3D.new()
	holder.add_child(stepped_root)
	var builder := DigScenery.new()
	var stepped: Node3D = builder._begin_park(stepped_root, map, ground, 1)
	var step := DigScenery.ParkBuild.new()
	step.builder = builder
	stepped.add_child(step)
	var frames := 0
	while is_instance_valid(step) and not step.is_queued_for_deletion() and frames < 2000:
		await process_frame
		frames += 1
	t.check("the stepped pass takes more than one frame and ends", frames > 1 and frames < 2000, "%d frames" % frames)
	var a := _views(whole)
	var b := _views(stepped)
	t.check("the stepped pass builds the same batches in the same order", a.keys() == b.keys(), "%d vs %d batches" % [a.size(), b.size()])
	var same := a.keys() == b.keys()
	for key in a.keys():
		same = same and b.has(key) and a[key] == b[key]
	t.check("every stepped batch has the whole pass's placements", same and not a.is_empty())
	t.check("the stepped pass has the effects node", stepped.get_node_or_null("DigFx") != null)
	t.check("the stepped pass marks the whole pass's cut faces", whole.get_node("DigFx").faces == stepped.get_node("DigFx").faces)

	# Entry finishes a pass still running: a few steps, then ParkBuild.finish().
	var cut_root := Node3D.new()
	holder.add_child(cut_root)
	var cut_builder := DigScenery.new()
	var cut: Node3D = cut_builder._begin_park(cut_root, map, ground, 1)
	var cut_step := DigScenery.ParkBuild.new()
	cut_step.builder = cut_builder
	cut.add_child(cut_step)
	for n in 5:
		await process_frame
	cut_step.finish()
	t.check("entry's finish of a running pass builds the whole pass's batches", _views(cut) == a)

	var once := Contraptions.new()
	holder.add_child(once)
	once.setup(map, ground, 14.0, 26.0)
	var piece := Contraptions.new()
	holder.add_child(piece)
	piece.begin(map, ground, 14.0, 26.0)
	var calls := 0
	while piece.unbuilt():
		piece.build_next()
		calls += 1
	piece.finish()
	t.check("contraptions build one device a call", calls == map.contraptions.size() and calls > 1, "%d calls, %d specs" % [calls, map.contraptions.size()])
	t.check("contraptions built a device a call match setup's", _devices(once) == _devices(piece), "%s vs %s" % [_devices(once), _devices(piece)])
	t.check("contraptions built a device a call have setup's nodes where setup put them", _nodes(once) == _nodes(piece), "%d vs %d nodes" % [_nodes(once).size(), _nodes(piece).size()])

	SimClock.ticks = false
	holder.queue_free()
	await process_frame
	quit(t.verdict())


func _views(scenery: Node) -> Dictionary:
	var out := {}
	for view in scenery.find_children("*", "MultiMeshInstance3D", true, false):
		out[String(view.name)] = view.get_meta("origins", PackedVector3Array())
	return out


func _devices(c) -> Array:
	return [c.barges.size(), c.lifts.size(), c.launchers.size(), c.cables.size(), c.valves.size(), c.walls.size(),
		c.thermals.size(), c.cinders.size(), c.glazes.size()]


# Every node under a Contraptions as its class and place; unnamed nodes take engine names that differ per build.
func _nodes(c: Node) -> Array:
	return c.find_children("*", "", true, false).map(func(n): return [n.get_class(), n.global_transform if n is Node3D else null])
