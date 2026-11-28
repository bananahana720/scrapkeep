extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const TreeProblems := preload("res://tests/support/tree_problems.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# Unit G of the world-one build systems (BUILD-SYSTEMS.md): --world-one-builds=on gives every
# pilot a two-depth tree. A scripted run through Brindle (stage 1 clear, stage 2, stage 3, the
# bay skipped, the bay boarded twice, stage retries) receives exactly two offers, none while
# the ball is airborne, and the second pair is always the children of the first pick. Flag off
# the same script gets the base four offers, delivered at once even in the air. The hot-wired
# flags are registered and independent, and their effects are not built here.
#
# Evidence limit: the run is a fixture on the real Game, its stage clears are bus emissions
# and the airborne ball is a state flag; nothing here says the pick screen feels calm in play.

# What base game.gd offers for this script (measured on the base commit): the start, stage 1 and
# stage 2 each open a pair; stage 3 re-offers the still-unpicked depth 3.
const BASE_OFFER_DEPTHS := [1, 2, 3, 3]

# Preserve the legacy three-stage rule on a double using surviving maps.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _done := false
var _failures := 0
var _offers: Array = []


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	_done = true
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.events.tree_offered.connect(func(c: String, d: int, ids: Array):
		_offers.append({"class": c, "depth": d, "ids": ids, "grounded": _game.player.state.grounded}))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_flags()
	for i in ClassDef.all().size():
		_brindle_run(i, true)
	_air_delivery(true)
	for i in ClassDef.all().size():
		_brindle_run(i, false)
	_air_delivery(false)
	_allowance()
	_validator()
	print("world_one_G_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _flags() -> void:
	var t := Tuning.new()
	_check("flags default on", t.world_one() and t.option("hotwire_shell") == "on" and t.option("hotwire_tread") == "on", "all three rows default on")
	var only_shell := _all_off()
	only_shell.apply_args(PackedStringArray(["--hotwire-shell=on"]), "launch")
	var only_tread := _all_off()
	only_tread.apply_args(PackedStringArray(["--hotwire-tread=on"]), "launch")
	var master := _all_off()
	master.apply_args(PackedStringArray(["--world-one-builds=on"]), "launch")
	_check("flags independent", only_shell.option("hotwire_shell") == "on" and only_shell.option("hotwire_tread") == "off" and not only_shell.world_one()
		and only_tread.option("hotwire_tread") == "on" and only_tread.option("hotwire_shell") == "off" and not only_tread.world_one()
		and master.world_one() and master.option("hotwire_shell") == "off" and master.option("hotwire_tread") == "off",
		"shell, tread and the master flag each switch alone")


func _all_off() -> Tuning:
	var t := Tuning.new()
	t.set_option("world_one_builds", "off")
	t.set_option("hotwire_shell", "off")
	t.set_option("hotwire_tread", "off")
	return t


func _set_flag(on: bool) -> void:
	_game.ctx.tuning.set_option("world_one_builds", "on" if on else "off")


func _new_run(index: int, on: bool) -> void:
	_set_flag(on)
	_game.run.class_def = ClassDef.all()[index]
	_offers.clear()
	_game.player.state.grounded = true
	_game.flow.new_run()
	_game.player.state.grounded = true


func _pair(tree) -> Array:
	var depth: int = tree.path().size() + 1
	return tree.offered(tree.class_id, depth).map(func(n): return n["id"])


# The whole of world one for one pilot, calm: depth 1 at the start, stage 1's clear with the
# bay skipped, a retry and a bay boarded twice, then stages 2 and 3 with more retries.
func _brindle_run(index: int, on: bool) -> void:
	var def = ClassDef.all()[index]
	_new_run(index, on)
	var tree = _game.player.tree
	var world = _game.world
	var label := "%s %s" % [def.display_name, "on" if on else "off"]
	var start_offers := _offers.size()
	var first: Array = _pair(tree)
	_check(label + " start offer", start_offers == 1 and _offers[0]["depth"] == 1, "one depth-1 offer at run start")
	tree.pick(first[0])
	var at_pick_1: Array = tree.path()
	_game.events.stage_cleared.emit(1)
	var second: Array = _pair(tree)
	_check(label + " second offer", _offers.size() == 2 and _offers.back()["depth"] == 2,
		"stage 1 clear (bay skipped) offers depth 2: %s" % [second])
	var expected: Array = UpgradeTree.children_of(UpgradeTree.index_of(def.id, first[0], on)).map(func(i): return UpgradeTree.nodes(def.id, on)[i]["id"])
	_check(label + " parents stable", second == expected, "depth-2 pair %s are the children of %s" % [second, first[0]])
	# Boarding the bay after a skipped clear, and a retry, must not offer again or change the pair.
	world._open_pick(1)
	_game.flow.retry_stage()
	world._open_pick(1)
	_check(label + " no second open", _offers.size() == 2 and _pair(tree) == second and tree.path() == at_pick_1, "skip, bay entry and retry keep one open depth-2 offer %s" % [_pair(tree)])
	tree.pick(second[1])
	var path: Array = tree.path()
	for stage in [2, 3]:
		_game.events.stage_cleared.emit(stage)
		world._open_pick(stage)
		_game.flow.retry_stage()
	# Land the ball so anything queued while airborne would be delivered before the count.
	_game.player.state.grounded = true
	world._physics_process(0.0)
	if on:
		_check(label + " exactly two", _offers.size() == 2 and tree.path() == path and not tree.pending() and tree.allowed == 2 and world._picks_waiting.is_empty(),
			"%d offers and %d picks through Brindle, allowed %d, pending %s, waiting %s" % [_offers.size(), tree.path().size(), tree.allowed, tree.pending(), world._picks_waiting])
	else:
		var depths: Array = _offers.map(func(o): return o["depth"])
		_check(label + " base four", depths == BASE_OFFER_DEPTHS,
			"flag off keeps the base schedule %s: offers at depths %s" % [BASE_OFFER_DEPTHS, depths])
		print("TRACE %s offers %s" % [label, depths])


# A pick that falls due while the ball is airborne is held until it lands (flag on) and opens
# at once as before (flag off).
func _air_delivery(on: bool) -> void:
	_new_run(0, on)
	var tree = _game.player.tree
	tree.pick(_pair(tree)[0])
	_offers.clear()
	_game.player.state.grounded = false
	_game.events.stage_cleared.emit(1)
	var during := _offers.size()
	_game.player.state.grounded = true
	_game.world._physics_process(0.0)
	var label := "airborne %s" % ("on" if on else "off")
	if on:
		_check(label, during == 0 and _offers.size() == 1 and _offers[0]["grounded"] and _offers[0]["depth"] == 2,
			"no offer in the air (%d), one on landing (%d), grounded when offered %s" % [during, _offers.size(), _offers[0]["grounded"] if not _offers.is_empty() else null])
	else:
		_check(label, during == 1 and _offers.size() == 1 and not _offers[0]["grounded"],
			"flag off offers in the air at once, as base (%d during, %d total)" % [during, _offers.size()])
		print("TRACE airborne off during %d" % during)


# The tree itself holds the allowance at two however often a checkpoint is asked for, so a
# caller other than world.gd cannot open a third pick.
func _allowance() -> void:
	var def = ClassDef.all()[0]
	var tree := UpgradeTree.new()
	tree.max_depth = UpgradeTree.WORLD_ONE_DEPTHS
	tree.reset(def.id)
	for _i in 6:
		tree.open_checkpoint()
	tree.pick(tree.offered(def.id, 1)[0]["id"])
	tree.pick(tree.offered(def.id, 2)[0]["id"])
	for _i in 3:
		tree.open_checkpoint()
	_check("tree allowance", tree.allowed == 2 and tree.path().size() == 2 and not tree.pending() and tree.offered(def.id, 3).is_empty(),
		"eight checkpoint calls leave allowed %d, %d picks, depth 3 offers %s" % [tree.allowed, tree.path().size(), tree.offered(def.id, 3)])


func _validator() -> void:
	var bad := []
	var off_ok := true
	for def in ClassDef.all():
		if not TreeProblems.problems(def.id, true).is_empty():
			bad.append(def.id)
		off_ok = off_ok and TreeProblems.problems(def.id) == TreeProblems.problems(def.id, false)
	_check("world-one validator", bad.is_empty() and off_ok, "the six offered nodes of each pilot pass; failures %s; default call unchanged" % [bad])
