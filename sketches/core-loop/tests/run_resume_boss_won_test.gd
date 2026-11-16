extends SceneTree
# smoke: timeout=300s (74 s run alone at load 51 on the PC at stage/alpha-w43 d99352d2 on 2026-11-16, killed once at the 180 s default cap in sketch:fast at load 86 with every check passed)

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")

# PF-55: a quit in the victory beat after a world's boss falls. The run file was written before the
# arena, so Continue put the player back in a fight already won, with less than he held at the fall.
# On the two-world table, with the boss's fall signalled by hand:
#   (a) a quit in the boss fight, before the fall, still continues in the arena;
#   (b) a quit in the victory beat continues at the next world's entrance with the cogs and parts held at the fall;
#   (c) a second Continue from the file the first one left does not pay again nor re-enter the arena;
#   (d) the played launch ends the run won at world 1's boss: a quit in the victory beat and a Continue end the run
#       won at the summary, bank what an uninterrupted win banks, leave no run file and offer no second Continue;
#   (e) the boss_defeated listeners that join the bus after flow (progress's ledger grant) change the saved
#       run's settled ids, so the save waits for them: the file on disk carries the run's settled ids.

const DIR := "user://run_resume_boss_won_test/"
const PATH := DIR + "run.json"
# Banked at the fall itself, in the first game, whose test storage a free removes; the win's own banking is what is compared.
const FALL_BANKED := ["ach.mind_quieted", "ach.waking_stilled"]
const FLIGHT := Vector3(0.0, 6.0, 30.0)


class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld


var _game
var _failures := 0
var _final := false
# The worlds announced (world_entered) during the last _resume.
var _worlds: Array = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	_run.call_deferred()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _boot():
	var game := TwoWorldGame.new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	var spawner := SpawnerDouble.new()
	game.add_child(spawner)
	spawner.setup(game.ctx)
	game.ctx.spawner = spawner
	game.ctx.calm = true
	game.tuning.set_option("world_one_builds", "off")
	game.player.source = Intent.Scripted.new()
	if _final:
		game.tuning.set_option("final_world", "1")
	return game


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _resume() -> bool:
	_game = _boot()
	await _frames(2)
	_worlds = []
	_game.events.world_entered.connect(func(world: int): _worlds.append(world))
	var resumed: bool = _game.flow.resume_run()
	await _frames(2)
	return resumed


func _run() -> void:
	_game = _boot()
	await _frames(2)
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)
	var run = _game.run
	# Stage 3 closes world one: land its flight in the boss arena.
	run.enter_stage(3)
	_game.flow.state = _game.flow.GATES
	_game.events.launched.emit(FLIGHT)
	await _frames(1)
	_game.flow._finish_stage()
	await _frames(2)
	var in_arena: bool = _game.flow.in_arena
	var at_entry_cogs: int = run.cogs
	_game.free()

	var resumed: bool = await _resume()
	run = _game.run
	_report("a quit before the fall continues in the arena", in_arena and resumed and _game.flow.in_arena
		and _game.flow.state_name() == "boss" and run.stage == 3,
		"arena %s; resumed %s at stage %d, flow %s" % [in_arena, resumed, run.stage, _game.flow.state_name()])

	# The fall: the boss pays out, then the victory beat starts; quit one second in.
	run.add_cogs(500)
	run.add_part("boost_coil", "test")
	var held_cogs: int = run.cogs
	var held_parts: Array = Array(run.parts)
	_game.events.boss_defeated.emit()
	await _frames(60)
	var in_beat: bool = _game.flow.state_name() == "victory"
	_game.free()

	resumed = await _resume()
	run = _game.run
	_report("a quit in the victory beat continues after the win", in_beat and resumed and run.stage == 4
		and not _game.flow.in_arena and _game.flow.state_name() == "stage"
		and run.cogs == held_cogs and Array(run.parts) == held_parts and held_cogs > at_entry_cogs,
		"in beat %s; resumed %s at stage %d, arena %s, flow %s, cogs %d (held %d), parts %s (held %s)" % [in_beat, resumed,
			run.stage, _game.flow.in_arena, _game.flow.state_name(), run.cogs, held_cogs, Array(run.parts), held_parts])
	# Entering world 2 is announced once, as on the uninterrupted path; world 1 is not announced again.
	_report("the resumed run announces world 2 once", _worlds == [2], "worlds announced %s" % [_worlds])
	_game.free()

	resumed = await _resume()
	run = _game.run
	_report("a second Continue pays nothing twice", resumed and run.stage == 4 and not _game.flow.in_arena
		and run.cogs == held_cogs and Array(run.parts) == held_parts and not RunStore.new(PATH).load().has("boss_won"),
		"resumed %s at stage %d, cogs %d (held %d), parts %s, marker on disk %s" % [resumed, run.stage, run.cogs, held_cogs,
			Array(run.parts), RunStore.new(PATH).load().has("boss_won")])
	_game.free()

	await _final_case()

	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	print("run_resume_boss_won_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _wipe() -> void:
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	var storage := "user://test-%d" % OS.get_process_id()
	if not DirAccess.dir_exists_absolute(storage):
		return
	for name in DirAccess.get_files_at(storage):
		if name.begins_with("profile"):
			DirAccess.remove_absolute(storage.path_join(name))


# What the profile holds on disk after a win: the part a double bank would change.
func _banked() -> Dictionary:
	var profile := preload("res://src/core/profile.gd").new("user://test-%d/profile.json" % OS.get_process_id())
	profile.load_profile()
	var doc: Dictionary = profile._doc
	var earned: Array = doc["achievements"].keys().filter(func(id): return not ("ach." + String(id)) in FALL_BANKED)
	earned.sort()
	# The ledger leaf is settled at the fall, in the first game, whose test storage a free removes.
	var settled: Array = doc["settled"].filter(func(id): return not String(id).begins_with("ledger."))
	settled.sort()
	var stats := {}
	for key in doc["stats"]:
		# Clock readings and per-run ids differ between two plays of the same win.
		var fall_banked: bool = String(key).begins_with("door.") or String(key) in FALL_BANKED
		if not fall_banked and not (String(key).contains("time") or String(key).contains("run_tally") or String(key).contains("-")):
			stats[key] = doc["stats"][key]
	return {"stats": stats, "earned": earned, "settled": settled}


# Plays to the fall of world 1's boss in a played launch (final world 1) and returns the cogs and parts held.
func _to_the_fall() -> Dictionary:
	_game = _boot()
	await _frames(2)
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)
	var run = _game.run
	run.enter_stage(3)
	_game.flow.state = _game.flow.GATES
	_game.events.launched.emit(FLIGHT)
	await _frames(1)
	_game.flow._finish_stage()
	await _frames(2)
	run.add_cogs(500)
	run.add_part("boost_coil", "test")
	var held := {"cogs": run.cogs, "parts": Array(run.parts)}
	_game.events.boss_defeated.emit()
	await _frames(1)
	return held


func _final_case() -> void:
	_final = true
	# The uninterrupted win is the baseline for what a win banks.
	_wipe()
	var held: Dictionary = await _to_the_fall()
	var frames := 0
	while _game.flow.state_name() != "summary" and frames < 600:
		await _frames(1)
		frames += 1
	var won_plain: bool = _game.flow.run_won and _game.run.over
	var plain := _banked()
	_game.free()

	# Quit 1.0 s into the beat, Continue.
	_wipe()
	held = await _to_the_fall()
	var disk: Dictionary = RunStore.new(PATH).load()
	_report("the file on disk carries the run's settled ids", Array(disk.get("settled", [])).size() == _game.run.settled.size()
		and _game.run.settled.size() > 0, "disk %s, run %s" % [disk.get("settled"), _game.run.settled])
	await _frames(59)
	var in_beat: bool = _game.flow.state_name() == "victory"
	_game.free()
	var resumed: bool = await _resume()
	frames = 0
	while _game.flow.state_name() != "summary" and frames < 600:
		await _frames(1)
		frames += 1
	var banked := _banked()
	var store := RunStore.new(PATH)
	var gone: bool = store.load().is_empty()
	_report("a launch quit in the beat and Continue end the run won at the summary", won_plain and in_beat and resumed
		and _game.flow.state_name() == "summary" and _game.flow.run_won and _game.run.over
		and _game.run.cogs == int(held["cogs"]) and Array(_game.run.parts) == held["parts"],
		"plain win %s; in beat %s, resumed %s, flow %s, won %s, over %s, cogs %d (held %d)" % [won_plain, in_beat, resumed,
			_game.flow.state_name(), _game.flow.run_won, _game.run.over, _game.run.cogs, int(held["cogs"])])
	_report("the win banks what an uninterrupted win banks", banked == plain and not plain["earned"].is_empty(),
		"interrupted %s; uninterrupted %s" % [JSON.stringify(banked), JSON.stringify(plain)])
	_report("the run file is a tombstone", gone and store.refusal == RunStore.REFUSED_ENDED,
		"load empty %s, refusal '%s'" % [gone, store.refusal])
	_game.free()

	resumed = await _resume()
	var again := _banked()
	# A freed game removes its test storage, so the second Continue's profile starts empty: it must stay so.
	_report("a second Continue finds no run and banks nothing", not resumed and not _game.flow.continue_ready
		and again["earned"].is_empty() and again["stats"].is_empty(),
		"resumed %s, continue_ready %s, banked %s" % [resumed, _game.flow.continue_ready, JSON.stringify(again)])
	_game.free()
	_final = false
