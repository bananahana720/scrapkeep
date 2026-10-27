extends SceneTree

# Reap (src/core/reap.gd): what a clear lets go is hidden, disabled and out of its groups (its
# children's too) at once, is left alone on the frame that let it go, then is deleted oldest first a budget a frame until none is left. A
# node freed first with its parent, a node never in the tree and nodes still held when Reap
# goes are all handled.

const Reap := preload("res://src/core/reap.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("reap_test")


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var parent := Node3D.new()
	root.add_child(parent)
	var nodes: Array = []
	for i in 40:
		var n := Node3D.new()
		for j in 50:
			n.add_child(MeshInstance3D.new())
		parent.add_child(n)
		nodes.append(n)
	nodes[1].add_to_group("let_go")
	nodes[1].get_child(0).add_to_group("let_go")
	var child_first := Node3D.new()
	nodes[0].add_child(child_first)
	for n in nodes:
		Reap.free_later(n)
	Reap.free_later(child_first)
	var loose := Node3D.new()
	Reap.free_later(loose)
	_t.check("each let-go node is hidden and stops processing at once",
		nodes.all(func(n): return not n.visible and n.process_mode == Node.PROCESS_MODE_DISABLED))
	_t.check("it and its children leave their groups", get_nodes_in_group("let_go").is_empty())
	_t.check("a node outside the tree is just queued", loose.is_queued_for_deletion())
	await process_frame
	_t.check("nothing is freed on the frame that let it go", nodes.all(func(n): return is_instance_valid(n)))
	var frames := 0
	var reap: Node = root.get_node_or_null("Reap")
	var most := 0
	while (nodes.any(func(n): return is_instance_valid(n)) or reap.pending() > 0) and frames < 200:
		var before := nodes.filter(func(n): return is_instance_valid(n)).size()
		await process_frame
		most = maxi(most, before - nodes.filter(func(n): return is_instance_valid(n)).size())
		frames += 1
	_t.check("every node is freed over later frames", frames >= 1 and frames < 200,
		"%d frames, at most %d a frame" % [frames, most])
	_t.check("the queue ends empty, a child freed with its parent included", reap != null and reap.pending() == 0 and not is_instance_valid(child_first))
	var late := Node3D.new()
	parent.add_child(late)
	Reap.free_later(late)
	reap.free()
	_t.check("Reap deletes what it still holds when it goes", not is_instance_valid(late))
	parent.free()
	quit(_t.verdict())
