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
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

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
	var spawns := []
	# What each drawn frame held: process_frame comes before any node's _process, so the tree read
	# here is the one the frame before was drawn with. -1 with no warm spawn standing, else the
	# debris boxes in it.
	var boxes := []
	var pieces := []
	while (not node._queue.is_empty() or _spawn_warms(node) > 0) and sizes.size() < 200:
		await process_frame
		sizes.append(node._queue.size())
		spawns.append(_spawn_warms(node))
		boxes.append(_debris_boxes(node))
		pieces.append(_debris_pieces(node))
	t.check("stage 1's kinds each stand out of sight for two drawn frames, one at a time, and leave",
		spawns.count(1) == BakeWarm.SPAWN_WARM.size() * 2 and spawns.max() == 1 and _spawn_warms(node) == 0, str(spawns))
	# The renderer only learns of a node that is in the tree when a frame is drawn, so the debris
	# boxes death_warm adds must be there for one: each kind's first frame is its body alone, its
	# second has the boxes. Freed in the call that added them, they were never drawn (the dam's
	# first deaths on the 4080, 10 November 2026).
	var bodies := 0
	var twinned := 0
	for i in boxes.size():
		if boxes[i] == 0 and i + 1 < boxes.size() and boxes[i + 1] > 0:
			bodies += 1
		if boxes[i] > 0:
			twinned += 1
	t.check("each kind's debris boxes stand through a drawn frame, the frame after its body alone",
		bodies == BakeWarm.SPAWN_WARM.size() and twinned == BakeWarm.SPAWN_WARM.size(), str(boxes))
	var thrown := true
	for i in boxes.size():
		thrown = thrown and (pieces[i] >= EnemyMotion.PARTS_MIN) == (boxes[i] > 0)
	t.check("with them stands the body's break-up, built as a death builds it", thrown, str(pieces))
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

	# dress on a spawn of a warmed kit draws the copy made ahead: read before dress, not made by it.
	var mesh: Mesh = BakeWarm.meshes(kits[0].call("_parts"))[0]
	var ahead = mesh.get_meta("bake_safe") if mesh.has_meta("bake_safe") else (mesh if mesh.get_meta("bake_tangents_ok", false) else null)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	holder.add_child(view)
	BakeLook.dress(view)
	t.check("dress after the warm-up draws the copy made ahead", ahead != null and view.mesh == ahead)

	# On screen a rigged kit seats its GLB's own scene: those scenes are held and their meshes readied.
	var rigs: Array = BakeWarm.WORLD_RIGS[1]
	t.check("headless, no rig scene is queued (spawns copy _parts() meshes there)", node._queue.is_empty() and not BakeWarm._held.has(rigs[0]))
	EnemyMotion.headless_idle = true
	events.stage_entered.emit(1, false)
	t.check("on screen, a world 1 entry queues the rig scenes", node._queue.size() == rigs.size(), "%d of %d" % [node._queue.size(), rigs.size()])
	while not node._queue.is_empty():
		await process_frame
	var unready := []
	for path in rigs:
		var model := (load(path) as PackedScene).instantiate()
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh is ArrayMesh and not (mi.mesh.has_meta("bake_safe") or mi.mesh.get_meta("bake_tangents_ok", false)):
				unready.append("%s/%s" % [path.get_file(), mi.name])
		model.free()
	t.check("a spawn's own load of a rig scene finds its meshes readied", unready.is_empty() and BakeWarm._held.size() == rigs.size(), str(unready))
	EnemyMotion.headless_idle = false

	holder.queue_free()
	events.queue_free()
	await process_frame
	quit(t.verdict())


# The debris boxes (death_warm's) in the warm spawn standing under the node now, -1 with none standing.
func _debris_boxes(node: Node) -> int:
	for child in node.get_children():
		if child.has_meta("spawn_warm") and not child.is_queued_for_deletion():
			return child.get_children().filter(func(view): return view is MeshInstance3D and view.mesh is BoxMesh and view.get_parent() == child).size()
	return -1


# The pieces of the break-up (EnemyMotion.scatter) in the warm spawn standing under the node now.
func _debris_pieces(node: Node) -> int:
	for child in node.get_children():
		if child.has_meta("spawn_warm") and not child.is_queued_for_deletion():
			for part in child.get_children():
				if part.get_script() == EnemyMotion:
					return part.get_child_count()
	return 0


# The warm spawns standing under the node now (spawn_warm_test checks what they draw).
func _spawn_warms(node: Node) -> int:
	return node.get_children().filter(func(child): return child.has_meta("spawn_warm") and not child.is_queued_for_deletion()).size()
