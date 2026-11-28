extends SceneTree

const Game := preload("res://src/game.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const TreeProblems := preload("res://tests/support/tree_problems.gd")

# Rule: the default tree profile caps worlds 1, 2 and 3+ at depths 2, 3 and 4.
# Both world pick openers read the world index, not the global stage. Walk every
# left/right route through each world's offers, including repeated checkpoints
# and an attempted pick beyond the cap. All pilots retain 30 nodes and 16 full
# endpoints; world one's Sable duplicate stays below its offered depths.
# Evidence limit: independent per-world paths and the live cap-setting calls;
# this does not qualify saved-path migration. The across-world pick schedule lives in
# pick_pace_test. _open_pick(99) stays a cap-only sentinel: 99 is never the first stage
# of a world, so it sets the cap and table and opens no pick.

var _game
var _done := false
var _failures := 0


class ThreeWorlds:
	extends RefCounted

	static func world_of(stage: int) -> int:
		return 1 + int((stage - 1) / 3)


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	_done = true
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	var original_stages = _game.ctx.stages
	_game.ctx.stages = ThreeWorlds
	_game.player.state.grounded = true
	_game.ctx.tuning.set_option("world_one_builds", "on")
	for def in ClassDef.all():
		_structure(def)
		for world_index in range(1, 5):
			_world(def, world_index)
	_retained_path_guard()
	_game.ctx.tuning.set_option("world_one_builds", "off")
	for world_index in range(1, 5):
		_game.run.stage = 1 + (world_index - 1) * 3
		_game.world._open_pick(99)
		_report("legacy world %d" % world_index,
			_game.player.tree.max_depth == 4 and not _game.player.tree.world_one,
			"flag off: cap %d, world-one table %s" % [_game.player.tree.max_depth, _game.player.tree.world_one])
	_game.ctx.stages = original_stages
	print("tree_depth_cap_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _structure(def) -> void:
	var list := UpgradeTree.nodes(def.id)
	var endpoints := 0
	for i in list.size():
		if UpgradeTree.depth_of(i) == 4:
			endpoints += 1
	var problems := TreeProblems.problems(def.id)
	var world_one_problems := TreeProblems.problems(def.id, true)
	_report("%s structure" % def.display_name,
		list.size() == 30 and endpoints == 16 and problems.is_empty() and world_one_problems.is_empty(),
		"%d nodes, %d endpoints; full problems %s; world-one problems %s"
			% [list.size(), endpoints, problems, world_one_problems])
	_report("%s explicit profile" % def.display_name,
		UpgradeTree.WORLD_ONE_TABLES.has(def.id)
			and UpgradeTree.nodes(def.id, true) == UpgradeTree.WORLD_ONE_TABLES[def.id].NODES_WORLD_ONE,
		"pilot declares NODES_WORLD_ONE")


func _world(def, world_index: int) -> void:
	var cap := mini(world_index + 1, 4)
	var first_stage := 1 + (world_index - 1) * 3
	var label := "%s world %d" % [def.display_name, world_index]
	var live = _game.player.tree
	live.reset(def.id)
	for stage in range(first_stage, first_stage + 3):
		_game.run.stage = stage
		_game.world._open_pick(99)
		_report("%s stage %d cap" % [label, stage],
			live.max_depth == cap and live.world_one == (world_index == 1),
			"cap %d, want %d; world-one table %s" % [live.max_depth, cap, live.world_one])
	var world_one: bool = live.world_one
	var observed_cap: int = live.max_depth
	# The class-growth opener must replace stale cap/table state too.
	live.max_depth = 1
	live.world_one = world_index != 1
	_game.world._class_picks_owed = 1
	_game.world._deliver_class_picks()
	_report(label + " class-growth cap",
		live.max_depth == cap and live.world_one == world_one and live.allowed == 1,
		"cap %d, world-one table %s, allowed %d" % [live.max_depth, live.world_one, live.allowed])
	_walk(def.id, label, observed_cap, world_one, cap)


func _walk(class_id: String, label: String, observed_cap: int, world_one: bool, expected_cap: int) -> void:
	var reached := {}
	var offered_ids := {}
	var valid := true
	var bounded := true
	for combo in (1 << expected_cap):
		var tree := UpgradeTree.new()
		tree.max_depth = observed_cap
		tree.world_one = world_one
		tree.reset(class_id)
		# Open every possible checkpoint before picking to cover catch-up offers.
		for _i in 8:
			tree.open_checkpoint()
		for depth in range(1, expected_cap + 1):
			var pair := tree.offered(class_id, depth)
			if pair.size() != 2:
				valid = false
				break
			for n in pair:
				var index := UpgradeTree.index_of(class_id, n["id"], world_one)
				bounded = bounded and index >= 0 and UpgradeTree.depth_of(index) == depth and depth <= expected_cap
				offered_ids[n["id"]] = true
			valid = tree.pick(pair[(combo >> (depth - 1)) & 1]["id"]) and valid
		if tree.picks.size() == expected_cap:
			reached[tree.picks.back()] = true
		else:
			valid = false
		for _i in 3:
			tree.open_checkpoint()
		for depth in range(expected_cap + 1, 7):
			bounded = bounded and tree.offered(class_id, depth).is_empty()
		var list := UpgradeTree.nodes(class_id, world_one)
		var past := (1 << (expected_cap + 1)) - 2
		if past < list.size():
			bounded = not tree.pick(list[past]["id"]) and bounded
		bounded = bounded and tree.allowed == expected_cap and not tree.pending()
	_report(label + " all offers",
		valid and bounded and reached.size() == (1 << expected_cap)
			and offered_ids.size() == (1 << (expected_cap + 1)) - 2,
		"%d unique offered nodes, %d endpoints; valid routes %s, bounded %s"
			% [offered_ids.size(), reached.size(), valid, bounded])


# A world-one Face Runner id is at depth 3 in the full table. Its children are
# depth 4, so they must never masquerade as the run's next depth-3 offer, and the
# retry pair must not hold an id the run already has.
func _retained_path_guard() -> void:
	var tree := UpgradeTree.new()
	tree.world_one = true
	tree.max_depth = 2
	tree.reset("pylon_engineer")
	tree.open_checkpoint()
	var first := tree.pick("s_static_flutter")
	tree.open_checkpoint()
	var second := tree.pick("s_face_runner")
	tree.world_one = false
	tree.max_depth = UpgradeTree.depth_cap(2)
	tree.open_checkpoint()
	var ids: Array = tree.offered(tree.class_id, 3).map(func(n): return n["id"])
	var distinct: bool = ids.size() == 2 and ids[0] != ids[1]
	var fits: bool = distinct
	var held := false
	for id in ids:
		var i := UpgradeTree.index_of(tree.class_id, id)
		fits = fits and i >= 0 and UpgradeTree.depth_of(i) == 3
		held = held or id in tree.path()
	_report("retained Face Runner path offers a fresh depth-3 pair",
		first and second and fits and not held and not tree.pick("s_face_runner"),
		"offered %s, held none %s, duplicate pick refused %s" % [ids, not held, not tree.pick("s_face_runner")])
