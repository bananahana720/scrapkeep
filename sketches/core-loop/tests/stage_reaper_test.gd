extends SceneTree

# A park stage that leaves memory (terrain.gd _free_stage, on the entry two stages on) is freed over frames by the
# terrain's Reaper, not in one queue_free: park_dam's placed rows run to 20,000 nodes, and freeing them at once cost the
# stage 2 exit frame 263 ms on the cloud (#241). Checked on park_dam then park_flume: on the stage 2 entry the stage 1
# root is out of the terrain, still in the tree, parked below the map with processing off and queued on the reaper; it
# outlives the entry frame (a queue_free would have freed it by the next frame), then goes whole within a bounded number
# of frames, leaves first, and the stage 2 root is untouched.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_dam"}, {"stage": 2, "world": 1, "map": "park_flume"}]}
# 20,000 nodes at REAP_BUDGET_USEC a frame take well under this on any machine that runs the game.
const MAX_FRAMES := 3000

var t := T.new("stage_reaper_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	# Terrain3D follows the active camera, as the game's; without one it prints an error each run.
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	var terrain = Terrain.new(TABLE)
	terrain.build(holder)
	terrain.use(1)
	var first: Node3D = terrain.geometry_root(1)
	var second: Node3D = terrain.geometry_root(2)
	var nodes := _count(first)
	t.check("stage 1 is a big tree (its placed rows)", nodes > 5000, "%d nodes" % nodes)
	var freed := []
	terrain.stage_freed.connect(func(stage: int): freed.append(stage))
	terrain.use(2)
	var reaper: Node = holder.get_node_or_null("StageReaper")
	t.check("the stage 2 entry releases stage 1 (stage_freed 1)", freed == [1], str(freed))
	t.check("the released root waits on the reaper, still in the tree", reaper != null and is_instance_valid(first)
		and first.is_inside_tree() and reaper.dying.has(first))
	t.check("it waits parked: hidden, below the map, processing off", is_instance_valid(first) and not first.visible
		and first.position.y <= -Terrain.PARK_DEPTH and first.process_mode == Node.PROCESS_MODE_DISABLED)
	await process_frame
	await process_frame
	# A queue_free from the entry would be gone by now; the reaper frees a slice a frame.
	var left := _count(first) if is_instance_valid(first) else 0
	t.check("it outlives the entry frame (no one-frame free)", is_instance_valid(first), "%d nodes left" % left)
	# Leaves first and a slice a frame: two frames in, the root still stands and part of its tree is already gone.
	t.check("it frees a slice a frame, leaves first", left > 0 and left < nodes, "%d of %d nodes left" % [left, nodes])
	var frames := 2
	while is_instance_valid(first) and frames < MAX_FRAMES:
		await process_frame
		frames += 1
	t.check("the reaper frees the whole stage over frames", not is_instance_valid(first) and reaper != null and reaper.dying.is_empty(),
		"%d frames for %d nodes" % [frames, nodes])
	t.check("the stage 2 root is untouched", is_instance_valid(second) and second.is_inside_tree() and second.visible)
	holder.queue_free()
	await process_frame
	quit(t.verdict())


static func _count(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _count(child)
	return n
