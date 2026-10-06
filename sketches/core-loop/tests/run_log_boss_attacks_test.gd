extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const RunLog := preload("res://src/core/run_log.gd")

# The run record counts the Mind's attack commitments by family (W18): one count per
# _commit_attack, split_lane's two hazards still one commitment, the record line carries
# the dictionary as boss_attacks, and a fresh run starts it at {}.
#
# Evidence limit: attacks are committed by calling _commit_attack directly on the world
# three module; which family the phase would choose is mind_attack_families_test's concern.

var _game
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	Harness.boot(_game)
	Harness.enter_world(_game, 3)
	var mod = Harness.module(_game, 3)
	if mod == null or not mod.has_method("_commit_attack"):
		_report("mind module", false, "world 3 module is not the Mind")
		_game.free()
		quit(1)
		return
	var before: Dictionary = (_game.run.get_meta("boss_attacks", {}) as Dictionary).duplicate()
	var hazards_before: int = _hazard_count(mod)
	for family in ["lane", "split_lane", "rush", "plate"]:
		mod._commit_attack(family)
	var after: Dictionary = _game.run.get_meta("boss_attacks", {})
	var delta := {}
	for family in after:
		delta[family] = int(after[family]) - int(before.get(family, 0))
	_report("one commitment per family", delta == {"lane": 1, "split_lane": 1, "rush": 1, "plate": 1}, JSON.stringify(delta))
	_report("split_lane laid two hazards", _hazard_count(mod) - hazards_before >= 5, "%d hazards for four commitments" % (_hazard_count(mod) - hazards_before))

	_game.ctx.events.run_ended.emit(false)
	var path: String = _game.storage_dir.path_join(RunLog.LOG_FILE)
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n", false)
	var line: Dictionary = JSON.parse_string(lines[lines.size() - 1]) if lines.size() > 0 else {}
	var carried: Dictionary = line.get("boss_attacks", {})
	var same := carried.size() == after.size()
	for family in after:
		same = same and int(carried.get(family, -1)) == int(after[family])
	_report("record line carries boss_attacks", line.has("boss_attacks") and same, JSON.stringify(carried))

	_game.flow.new_run()
	_report("fresh run resets to {}", (_game.run.get_meta("boss_attacks", null) as Dictionary) == {}, JSON.stringify(_game.run.get_meta("boss_attacks", null)))
	print("run_log_boss_attacks_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
	_game.free()
	quit(1 if _failures > 0 else 0)


func _hazard_count(mod) -> int:
	var n := 0
	for attack in mod.attacks:
		n += (attack["hazards"] as Array).size()
	return n
