extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")

# PF-55: a quit in the victory beat after a world's boss falls. The run file was written before the
# arena, so Continue put the player back in a fight already won, with less than he held at the fall.
# On the two-world table, with the boss's fall signalled by hand:
#   (a) a quit in the boss fight, before the fall, still continues in the arena;
#   (b) a quit in the victory beat continues at the next world's entrance with the cogs and parts held at the fall;
#   (c) a second Continue from the file the first one left does not pay again nor re-enter the arena.

const DIR := "user://run_resume_boss_won_test/"
const PATH := DIR + "run.json"
const FLIGHT := Vector3(0.0, 6.0, 30.0)


class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld


var _game
var _failures := 0


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
	return game


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _resume() -> bool:
	_game = _boot()
	await _frames(2)
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
	_game.free()

	resumed = await _resume()
	run = _game.run
	_report("a second Continue pays nothing twice", resumed and run.stage == 4 and not _game.flow.in_arena
		and run.cogs == held_cogs and Array(run.parts) == held_parts and not RunStore.new(PATH).load().has("boss_won"),
		"resumed %s at stage %d, cogs %d (held %d), parts %s, marker on disk %s" % [resumed, run.stage, run.cogs, held_cogs,
			Array(run.parts), RunStore.new(PATH).load().has("boss_won")])
	_game.free()

	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	print("run_resume_boss_won_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
