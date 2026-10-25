extends SceneTree

# Rule (perf lane F): after a world 1 stage entry, bake_warm.gd readies each world 1 kit's shared
# meshes one kit a frame, so a kind's first spawn finds BakeLook.tangent_safe's copy already made
# instead of rebuilding tangents mid-fight. The copies are the ones dress uses later, and a bot run
# that builds stages whole warms nothing. Fixture: the warm node on a bare event bus; it runs under
# the headless (dummy) renderer like every test here.

const T := preload("res://tests/support/t.gd")
const BakeWarm := preload("res://src/presentation/bake_warm.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Context := preload("res://src/core/context.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_test"}, {"stage": 2, "world": 2, "map": "park_test"}]}

var t := T.new("bake_warm_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var events := GameEvents.new()
	root.add_child(events)
	var ctx := Context.new()
	ctx.events = events
	ctx.root = holder
	ctx.stages = TABLE

	SimClock.ticks = true
	BakeWarm.hook(ctx)
	var node: Node = holder.get_node("BakeWarm")
	events.stage_entered.emit(1, false)
	t.check("a bot run that builds stages whole queues nothing", node._queue.is_empty())

	SimClock.ticks = false
	events.stage_entered.emit(2, false)
	t.check("a world 2 entry queues none of world 1's kits", node._queue.is_empty())
	events.stage_entered.emit(1, false)
	var kits: Array = BakeWarm.WORLD_KITS[1]
	t.check("a world 1 entry queues every world 1 kit once", node._queue.size() == kits.size(), "%d of %d" % [node._queue.size(), kits.size()])
	events.stage_entered.emit(1, true)
	t.check("a retry queues no kit twice", node._queue.size() == kits.size())
	var sizes := []
	while not node._queue.is_empty() and sizes.size() < 200:
		await process_frame
		sizes.append(node._queue.size())
	var steady := true
	for i in range(1, sizes.size()):
		steady = steady and sizes[i - 1] - sizes[i] <= 1
	t.check("one kit a frame at most, until all are warm", steady and sizes.size() >= kits.size() and node._queue.is_empty(), "%d frames for %d kits" % [sizes.size(), kits.size()])

	var bare := []
	var counted := 0
	for kit in kits:
		var parts = kit.call("_parts")
		var found := BakeWarm.meshes(parts)
		if found.is_empty():
			bare.append(kit.resource_path.get_file())
		for mesh in found:
			counted += 1
			if mesh is ArrayMesh and not (mesh.has_meta("bake_safe") or mesh.get_meta("bake_tangents_ok", false)):
				bare.append("%s mesh" % kit.resource_path.get_file())
	t.check("every kit's shared meshes carry their tangent-safe copy", bare.is_empty() and counted > kits.size(), "%d meshes; bare %s" % [counted, bare])

	# dress on a spawn of a warmed kit uses the copy made ahead: no new copy, the same object.
	var mesh: Mesh = BakeWarm.meshes(kits[0].call("_parts"))[0]
	var ahead: Mesh = BakeLook.tangent_safe(mesh)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	holder.add_child(view)
	BakeLook.dress(view)
	t.check("dress after the warm-up draws the copy made ahead", view.mesh == ahead)

	holder.queue_free()
	events.queue_free()
	await process_frame
	quit(t.verdict())
