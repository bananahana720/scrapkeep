extends SceneTree

# Rule (scrapkeep#494, flume entry stall): a Spillway park stage built ahead on worker threads takes its
# park pass a step a frame (spillway_scenery.gd ParkBuild) instead of all in its entry tick, and the
# result is the one the whole pass builds: the same mist and cottonwood batches at the same placements,
# the same detail shells under the same holders, and the spillway effects. Entry's finish of a pass
# still running builds the rest. Fixture: a one-stage table of park_flume built whole (bot ticks); no
# check here is timed.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Scenery := preload("res://src/presentation/spillway_scenery.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_flume"}]}

var t := T.new("spillway_park_steps_test")


class Stages extends RefCounted:
	var DEFS: Array = TABLE["DEFS"]


class Ctx extends RefCounted:
	var terrain
	var stages
	var flow


class QuietFlow extends RefCounted:
	var quiet := false

	func calm() -> bool:
		return quiet


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
	Scenery.build_park(whole_root, map, ground, 1)
	var whole := _read(whole_root)
	t.check("the whole pass plants cottonwoods with their detail shells", not whole.batches.is_empty() and not whole.holders.is_empty() and whole.shells > 0,
		"%s, %d holders, %d shells" % [whole.batches.keys(), whole.holders.size(), whole.shells])

	var stepped_root := Node3D.new()
	holder.add_child(stepped_root)
	var pass_ = Scenery.ParkPass.new(stepped_root, map, ground, 1)
	var step := Scenery.ParkBuild.new()
	step.pass_ = pass_
	var flow := QuietFlow.new()
	step.flow = flow
	pass_.scenery.add_child(step)
	for n in 5:
		await process_frame
	t.check("the stepped pass waits while the stage is not calm", pass_.scenery.get_children().size() == 1
		and stepped_root.get_node_or_null("Cottonwoods") == null)
	flow.quiet = true
	var frames := 0
	while is_instance_valid(step) and not step.is_queued_for_deletion() and frames < 2000:
		await process_frame
		frames += 1
	await process_frame
	t.check("the stepped pass takes more than one frame and ends", frames > 2 and frames < 2000, "%d frames" % frames)
	var stepped := _read(stepped_root)
	t.check("the stepped pass builds the whole pass's batches at the same placements", stepped.batches == whole.batches,
		"%s vs %s" % [stepped.batches.keys(), whole.batches.keys()])
	t.check("the stepped pass hangs the whole pass's detail shells under the same holders", stepped.holders == whole.holders and stepped.shells == whole.shells,
		"%d vs %d shells" % [stepped.shells, whole.shells])
	t.check("the stepped pass places the whole pass's effects", stepped.fx == whole.fx and not whole.fx.is_empty(), "%s vs %s" % [stepped.fx, whole.fx])

	# The build-ahead hook leaves a stage built whole (a bot run) to its entry.
	var ctx := Ctx.new()
	ctx.terrain = terrain
	ctx.stages = Stages.new()
	var stage_root: Node3D = terrain.geometry_root(1)
	Scenery._on_stage_built(1, ctx)
	t.check("a stage built whole takes no pass ahead", stage_root.get_node_or_null("SpillwayScenery") == null)

	# Entry finishes a pass still running on the stage's root: a few steps, then the entry hook.
	var cut_pass = Scenery.ParkPass.new(stage_root, map, ground, 1)
	var cut_step := Scenery.ParkBuild.new()
	cut_step.name = "ParkBuild"
	cut_step.pass_ = cut_pass
	cut_pass.scenery.add_child(cut_step)
	for n in 2:
		await process_frame
	t.check("the pass is still running when the stage is entered", is_instance_valid(cut_step) and not cut_step.is_queued_for_deletion())
	Scenery._on_stage_entered(1, false, ctx)
	t.check("entry finishes the running pass rather than building a second", stage_root.find_children("SpillwayScenery*", "", false, false).size() == 1)
	await process_frame
	var cut := _read(stage_root)
	t.check("entry's finish of a running pass builds the whole pass", cut.batches == whole.batches and cut.holders == whole.holders and cut.fx == whole.fx)

	SimClock.ticks = false
	holder.queue_free()
	await process_frame
	quit(t.verdict())


# What a pass left under a stage root (its Cottonwoods and SpillwayScenery only, as a terrain stage root
# holds other batches): each MultiMesh batch's placements by name, the cottonwood holders'
# frames, the shell count and the scenery's other children (the effects) by name.
func _read(stage_root: Node) -> Dictionary:
	var batches := {}
	var views := []
	for part in ["Cottonwoods", "SpillwayScenery"]:
		var node := stage_root.get_node_or_null(part)
		if node != null:
			views.append_array(node.find_children("*", "MultiMeshInstance3D", true, false))
	for view in views:
		var multi: MultiMesh = view.multimesh
		var places := []
		for i in multi.instance_count:
			places.append(multi.get_instance_transform(i))
		batches[String(view.name)] = places
	var holders := []
	var shells := 0
	var group := stage_root.get_node_or_null("Cottonwoods")
	if group != null:
		for child in group.get_children():
			if child is MultiMeshInstance3D:
				continue
			holders.append([String(child.name), child.transform])
			shells += child.get_child_count()
	var fx := []
	var scenery := stage_root.get_node_or_null("SpillwayScenery")
	if scenery != null:
		for child in scenery.get_children():
			# Engine-named nodes ("@Node3D@12") differ per build.
			if not child.is_queued_for_deletion() and not String(child.name).begins_with("@"):
				fx.append(String(child.name))
	return {"batches": batches, "holders": holders, "shells": shells, "fx": fx}
