extends "res://tests/char_bot_test.gd"

const UpgradeTree := preload("res://src/core/upgrade_tree.gd")

# char_bot_test with the bot taking a random branch at every tree offer: depth 1 at
# class select, depth 2 when stage 1 clears. tree_bot_test runs one per class with
# "--seed=N" (0 Sable, 1 Rivet, 2 Kest, 3 Tarn). It pins world_one_builds off: the base tree gives the
# second pick at stage 1's clear, while world-one builds hold it for a calm frame, which a
# bot that is airborne at the gate never reaches before this run ends.

var _offered: Array = []


func _seed() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.trim_prefix("--seed="))
	return 0


func _configure(driver) -> void:
	_game.tuning.set_option("world_one_builds", "off")
	driver.tree_policy = "random"
	_game.events.tree_offered.connect(func(_c: String, depth: int, _ids: Array): _offered.append(depth))


func _extra_checks() -> void:
	var picks: Array[String] = _driver.tree_picks
	var cid: String = _driver.class_id()
	# 2026-10-04: the default table is the alpha ruleset, where a class rise opens a pick
	# (PICK_ON_CLASS_UP), so a bot that reaches class III inside stage 1 is offered a third
	# depth. Two picks or three are both on the path; which happens depends on the run.
	var want_depths: Array = [1, 2] if picks.size() == 2 else [1, 2, 3]
	var on_path: bool = picks.size() in [2, 3] and UpgradeTree.path_to(cid, picks[picks.size() - 1]) == picks
	_report("tree picks", on_path and _offered == want_depths and _game.player.tree.path() == picks,
		"offered depths %s; the bot took %s; tree path %s; tags %s"
			% [_offered, picks, _game.player.tree.path(), _game.player.tree.branch_tags()])
