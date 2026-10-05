extends SceneTree

const Game := preload("res://src/game.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const Sable := preload("res://src/core/trees/sable.gd")
const Rivet := preload("res://src/core/trees/rivet.gd")

# Rule: on the real six-stage default table, stages 1, 3 and 5 are worlds 1, 2 and 3 and
# the tree opens depths 2, 3 and 4 there. A world-1 Sable run that picked the world-one
# Face Runner still gets a depth-3 offer in world 2, and depth 4 opens only in world 3.
# Evidence limit: live offered/max_depth reads in one frame after the opener; this does not
# qualify saved-path migration, pick timing, or which Face Runner node the picked id resolves to.

var _game
var _done := false
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	_done = true
	_game.ctx.calm = true
	_game.flow.press_start()
	var stages = _game.ctx.stages
	for pair in [[1, 1, 2], [3, 2, 3], [5, 3, 4]]:
		_check("table stage %d" % pair[0],
			stages.world_of(pair[0]) == pair[1] and UpgradeTree.depth_cap(pair[1]) == pair[2],
			"world %d cap %d, want world %d cap %d"
				% [stages.world_of(pair[0]), UpgradeTree.depth_cap(stages.world_of(pair[0])), pair[1], pair[2]])
	_fresh_run(0)
	_face_runner_route()
	_fresh_run(0)
	_nodes_route("Sable NODES route", Sable.NODES, 1, 0)
	_fresh_run(0)
	_nodes_route("Sable NODES route (other branch)", Sable.NODES, 1, 1)
	_fresh_run(1)
	_nodes_route("Rivet route", Rivet.NODES, 0, 0)
	print("upgrade_tree_depth_test: %s" % ("PASS (%d)" % _checks if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _fresh_run(class_index: int) -> void:
	_game.flow._set_state(_game.flow.CLASS_SELECT)
	_game.flow.choose_class(class_index)
	_game.player.state.grounded = true


func _open(stage: int, label: String, cap: int, world_one: bool) -> void:
	_game.flow.enter_stage(stage, Vector3.ZERO, false)
	_game.world._open_pick(99)
	var tree = _game.player.tree
	_check("%s stage %d" % [label, stage], tree.max_depth == cap and tree.world_one == world_one,
		"cap %d world_one %s, want %d %s" % [tree.max_depth, tree.world_one, cap, world_one])


func _depth_ids(ids: Array, depth: int) -> bool:
	if ids.size() != 2:
		return false
	for id in ids:
		var i := UpgradeTree.index_of(_game.player.tree.class_id, id)
		if i < 0 or UpgradeTree.depth_of(i) != depth:
			return false
	return true


func _step(tree, depth: int, id: String, label: String) -> void:
	tree.open_checkpoint()
	var ids: Array = tree.offered(tree.class_id, depth).map(func(n): return n["id"])
	var offered_ok := id in ids
	_check("%s depth %d offered" % [label, depth], offered_ok, "%s in %s" % [id, ids])
	_check("%s depth %d picked" % [label, depth], tree.pick(id), id)


func _no_held(tree, ids: Array) -> bool:
	for id in ids:
		if id in tree.path():
			return false
	return true


func _face_runner_route() -> void:
	var cls: String = _game.player.tree.class_id
	for pick_index in [0, 1]:
		var label := "Sable Face Runner route (depth-3 pick %d)" % pick_index
		var tree = _game.player.tree
		if pick_index == 1:
			_fresh_run(0)
			tree = _game.player.tree
		_open(1, label, 2, true)
		_check(label + " world one offer empty at 3", tree.offered(cls, 3).is_empty(), "offered at depth 3 in world 1")
		_step(tree, 1, tree.offered(cls, 1)[0]["id"], label)
		_step(tree, 2, "s_face_runner", label)
		_open(3, label, 3, false)
		var ids: Array = tree.offered(cls, 3).map(func(n): return n["id"])
		_check(label + " depth-3 offer", _depth_ids(ids, 3) and _in_nodes(Sable.NODES, ids) and _no_held(tree, ids),
			"two unheld depth-3 ids in Sable.NODES: %s, path %s" % [ids, tree.path()])
		tree.open_checkpoint()
		_check(label + " pick refuses held id", not tree.pick("s_face_runner"), "s_face_runner refused")
		_check(label + " depth 4 closed in world 2", tree.offered(cls, 4).is_empty(), "offered at depth 4 at cap 3")
		var chosen: String = ids[pick_index]
		_check(label + " depth-3 pick", tree.pick(chosen), chosen)
		var again: Array = tree.offered(cls, 3).map(func(n): return n["id"])
		_check(label + " depth-3 offer unchanged after pick", again == ids, "%s vs %s" % [again, ids])
		_open(5, label, 4, false)
		tree.open_checkpoint()
		var deep: Array = tree.offered(cls, 4).map(func(n): return n["id"])
		var want: Array = UpgradeTree.children_of(UpgradeTree.index_of(cls, chosen, false)).map(
			func(i): return Sable.NODES[i]["id"])
		_check(label + " depth-4 offer", _depth_ids(deep, 4) and deep == want and _no_held(tree, deep),
			"depth-4 ids %s, want %s" % [deep, want])


func _in_nodes(nodes: Array, ids: Array) -> bool:
	for id in ids:
		var found := false
		for n in nodes:
			found = found or n["id"] == id
		if not found:
			return false
	return true


func _nodes_route(label: String, nodes: Array, first: int, second: int) -> void:
	var tree = _game.player.tree
	var cls: String = tree.class_id
	_open(1, label, 2, true)
	_step(tree, 1, tree.offered(cls, 1)[first]["id"], label)
	_step(tree, 2, tree.offered(cls, 2)[second]["id"], label)
	_open(3, label, 3, false)
	var ids: Array = tree.offered(cls, 3).map(func(n): return n["id"])
	_check(label + " depth-3 offer", _depth_ids(ids, 3) and _in_nodes(nodes, ids), "two depth-3 ids: %s" % [ids])
	_step(tree, 3, ids[0], label)
	_check(label + " depth 4 closed in world 2", tree.offered(cls, 4).is_empty(), "offered at depth 4 in world 2")
	_open(5, label, 4, false)
	var deep: Array = tree.offered(cls, 4).map(func(n): return n["id"])
	_check(label + " depth-4 offer", _depth_ids(deep, 4) and _in_nodes(nodes, deep), "two depth-4 ids after stage 5: %s" % [deep])
