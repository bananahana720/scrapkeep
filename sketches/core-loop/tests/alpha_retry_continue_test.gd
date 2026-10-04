extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const Game := preload("res://src/game.gd")

# One retry per world and Continue, on the game's default table with a store. Stage and world
# numbers come from game.ctx.stages, so it holds on two stages and on six.
#   (a) the first death in world 1 shows the dead screen and flow.retry_stage() spends the
#       world's one retry (retries_spent[1] == flow.WORLD_RETRIES, written to the store);
#       the second death ends the run on the summary, run_won false;
#   (b) a New Game on the same file enters the world's second stage; a new Game on the same
#       path offers Continue, and resume_run() lands on that stage with the saved hp, mass,
#       cogs, parts and tree picks, retries_spent unchanged;
#   (c) the world-1 arena: die there on a fresh run, free the Game, Continue. Observed rule
#       (owner call, pinned here as it stands): Continue resumes at the entrance of the stage
#       that leads into the arena (final_stage), in state "stage", not in the arena. The
#       store holds no arena save, only the stage entrance doc, and the arena death charged
#       no retry (the dead screen is not a retry; retry_stage() spends it, Continue does not).

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
	var retries: int = _game.flow.WORLD_RETRIES

	# (a) the world's one retry, then the end of the run.
	await _start_run()
	var ended := [false, true]
	_game.events.run_ended.connect(func(won: bool):
		ended[0] = true
		ended[1] = won)
	_kill()
	var dead: bool = _game.flow.state_name() == "dead"
	_game.flow.retry_stage()
	var spent: int = int(_game.run.retries_spent.get(1, 0))
	_report("first death spends the retry", dead and spent == retries and _spent_disk(1) == retries and _game.flow.state_name() == "stage",
		"stage %d: dead screen %s, retries_spent[1] %d (WORLD_RETRIES %d), on disk %d, flow %s" % [_game.run.stage, dead, spent, retries, _spent_disk(1), _game.flow.state_name()])
	_kill()
	_report("second death ends the run", _game.flow.state_name() == "summary" and ended[0] and not ended[1] and not _game.flow.run_won,
		"flow %s, run_ended %s won %s, run_won %s" % [_game.flow.state_name(), ended[0], ended[1], _game.flow.run_won])

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
		"spent": _game.run.retries_spent.duplicate(),
	}
	_game.free()

	_game = _boot()
	await _frames(2)
	var offered: bool = _game.flow.continue_ready
	var resumed: bool = _game.flow.resume_run()
	var back := {
		"stage": _game.run.stage, "hp": _game.run.hp, "mass": _game.run.mass, "cogs": _game.run.cogs,
		"parts": Array(_game.run.parts), "picks": Array(_game.player.tree.picks),
		"spent": _game.run.retries_spent.duplicate(),
	}
	var same: bool = saved["stage"] == second and back["stage"] == second and is_equal_approx(back["hp"], saved["hp"]) \
		and is_equal_approx(back["mass"], saved["mass"]) and back["cogs"] == saved["cogs"] and back["cogs"] > 0 \
		and back["parts"] == saved["parts"] and not back["parts"].is_empty() and back["picks"] == saved["picks"]
	_report("continue resumes the second stage", offered and resumed and picked and same and _game.run.world == second_world and _game.flow.state_name() == "stage",
		"stage %d (world %d) offered %s resumed %s: %s against saved %s" % [second, second_world, offered, resumed, back, saved])
	_report("continue spends nothing", back["spent"] == saved["spent"] and _spent_disk(1) == int(saved["spent"].get(1, 0)),
		"retries_spent after the continue %s, saved %s, on disk %d" % [back["spent"], saved["spent"], _spent_disk(1)])

	# (c) the world-1 arena: a New Game, clear the last stage, enter the boss, die, quit, Continue.
	_game.free()
	_game = _boot()
	await _frames(2)
	await _start_run()
	_game.flow.enter_stage(last, Vector3(0.0, 0.0, 14.0), false)
	var entrance_run: String = _game.run.run_id
	var entry_doc := _disk()
	_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
	var in_arena: bool = _game.flow.in_arena and _game.flow.state_name() == "boss"
	_kill()
	var arena_dead: bool = _game.flow.state_name() == "dead"
	var doc_after_death := _disk()
	var arena_spent: int = int(_game.run.retries_spent.get(1, 0))
	_game.free()

	_game = _boot()
	await _frames(2)
	var arena_offered: bool = _game.flow.continue_ready
	var arena_resumed: bool = _game.flow.resume_run()
	var at_entrance: bool = _game.run.stage == last and _game.flow.state_name() == "stage" and not _game.flow.in_arena and _game.run.run_id == entrance_run
	var saved_stage: int = int(doc_after_death.get("stage", -1))
	_report("arena death continues at the stage entrance", in_arena and arena_dead and arena_offered and arena_resumed and at_entrance \
			and saved_stage == last and doc_after_death == entry_doc and not str(doc_after_death).contains("arena") \
			and arena_spent == 0 and int(_game.run.retries_spent.get(1, 0)) == 0 and _spent_disk(1) == 0,
		"in arena %s, dead %s; store stage %d unchanged since the entrance %s, no arena key; Continue -> stage %d flow %s in_arena %s; retries charged %d (run) %d (disk)" \
			% [in_arena, arena_dead, saved_stage, doc_after_death == entry_doc, _game.run.stage, _game.flow.state_name(), _game.flow.in_arena, arena_spent, _spent_disk(1)])

	_game.free()
	_clean()
	DirAccess.remove_absolute(DIR)
	print("alpha_retry_continue_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
