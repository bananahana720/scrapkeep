extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const Game := preload("res://src/game.gd")

# No free retry, and Continue, on the game's default table with a store. Stage and world
# numbers come from game.ctx.stages, so it holds on two stages and on six.
#   (a) a death with no earned save ends the run at once: summary, run_won false, run_ended
#       fired, the store cleared (no Continue), retries_spent never written; a new run on
#       the same file starts with no save spent;
#   (b) a New Game on the same file enters the world's second stage; a new Game on the same
#       path offers Continue, and resume_run() lands on that stage with the saved hp, mass,
#       cogs, parts and tree picks; Continue refunds nothing (the save flag and retries_spent
#       are as saved);
#   (c) the world-1 arena: die there on a fresh run. The arena death ends the run like any
#       death: the store is cleared, so a second Game offers no Continue and there is no
#       arena save to resume.

const DIR := "user://alpha_retry_continue_test/"
const PATH := DIR + "run.json"

var _game
var _failures := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	_run.call_deferred()


func _clean() -> void:
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _boot():
	var game := Game.new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	return game


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _disk() -> Dictionary:
	return RunStore.new(PATH).load()


func _spent_disk(world: int) -> int:
	return int(_disk().get("retries_spent", {}).get(str(world), 0))


func _kill() -> void:
	_game.run.damage(9999.0, "test")


func _start_run() -> void:
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)


func _run() -> void:
	_game = _boot()
	await _frames(2)
	var stages = _game.ctx.stages
	var first: int = stages.first_of(1)
	var last: int = stages.last_of(1)
	var second: int = first + 1
	var second_world: int = stages.world_of(second)

	# (a) a death with no earned save ends the run.
	await _start_run()
	var ended := [false, true]
	_game.events.run_ended.connect(func(won: bool):
		ended[0] = true
		ended[1] = won)
	_kill()
	var disk_after: Dictionary = _disk()
	_report("a death with no save ends the run", _game.flow.state_name() == "summary" and ended[0] and not ended[1] and not _game.flow.run_won \
			and _game.run.over and not _game.run.death_save_spent and _game.run.retries_spent.is_empty() and disk_after.is_empty(),
		"flow %s, run_ended %s won %s, run_won %s, retries_spent %s, store after %s" \
			% [_game.flow.state_name(), ended[0], ended[1], _game.flow.run_won, _game.run.retries_spent, disk_after])
	await _start_run()
	_report("a new run starts with no save spent", _game.flow.state_name() == "stage" and not _game.run.death_save_spent and _game.run.retries_spent.is_empty() and not _game.run.over,
		"flow %s, death_save_spent %s, retries_spent %s" % [_game.flow.state_name(), _game.run.death_save_spent, _game.run.retries_spent])

	# (b) New Game on the same file, into the world's second stage, quit, Continue.
	await _start_run()
	_game.run.add_part("boost_coil", "test")
	_game.run.damage(12.0, "test")
	_game.run.mass += 40.0
	_game.run.add_cogs(7)
	var tree = _game.player.tree
	var offer: Array = tree.offered(tree.class_id, tree.picks.size() + 1)
	var picked: bool = tree.pending() and not offer.is_empty() and tree.pick(offer[0]["id"])
	_game.flow.enter_stage(second, Vector3(0.0, 0.0, 14.0), false)
	var saved := {
		"stage": _game.run.stage, "hp": _game.run.hp, "mass": _game.run.mass, "cogs": _game.run.cogs,
		"parts": Array(_game.run.parts), "picks": Array(_game.player.tree.picks),
		"spent": _game.run.retries_spent.duplicate(), "save": _game.run.death_save_spent,
	}
	_game.free()

	_game = _boot()
	await _frames(2)
	var offered: bool = _game.flow.continue_ready
	var resumed: bool = _game.flow.resume_run()
	var back := {
		"stage": _game.run.stage, "hp": _game.run.hp, "mass": _game.run.mass, "cogs": _game.run.cogs,
		"parts": Array(_game.run.parts), "picks": Array(_game.player.tree.picks),
		"spent": _game.run.retries_spent.duplicate(), "save": _game.run.death_save_spent,
	}
	var same: bool = saved["stage"] == second and back["stage"] == second and is_equal_approx(back["hp"], saved["hp"]) \
		and is_equal_approx(back["mass"], saved["mass"]) and back["cogs"] == saved["cogs"] and back["cogs"] > 0 \
		and back["parts"] == saved["parts"] and not back["parts"].is_empty() and back["picks"] == saved["picks"]
	_report("continue resumes the second stage", offered and resumed and picked and same and _game.run.world == second_world and _game.flow.state_name() == "stage",
		"stage %d (world %d) offered %s resumed %s: %s against saved %s" % [second, second_world, offered, resumed, back, saved])
	_report("continue refunds nothing", back["spent"] == saved["spent"] and back["save"] == saved["save"] and _spent_disk(1) == int(saved["spent"].get(1, 0)),
		"retries_spent after the continue %s, saved %s, on disk %d; save flag %s then %s" % [back["spent"], saved["spent"], _spent_disk(1), saved["save"], back["save"]])

	# (c) the world-1 arena: a New Game, clear the last stage, enter the boss, die.
	_game.free()
	_game = _boot()
	await _frames(2)
	await _start_run()
	_game.flow.enter_stage(last, Vector3(0.0, 0.0, 14.0), false)
	_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
	var in_arena: bool = _game.flow.in_arena and _game.flow.state_name() == "boss"
	_kill()
	var arena_over: bool = _game.flow.state_name() == "summary" and not _game.flow.run_won
	var doc_after_death := _disk()
	_game.free()

	_game = _boot()
	await _frames(2)
	_report("arena death ends the run, nothing to continue", in_arena and arena_over and not _game.flow.continue_ready and doc_after_death.is_empty() \
			and not _game.flow.resume_run(),
		"in arena %s, summary after death %s; store after %s; Continue offered %s" % [in_arena, arena_over, doc_after_death, _game.flow.continue_ready])

	_game.free()
	_clean()
	DirAccess.remove_absolute(DIR)
	print("alpha_retry_continue_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
