extends SceneTree

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const T := preload("res://tests/support/t.gd")
const Push := preload("res://tests/support/push.gd")

var _t := T.new("ending_routes_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game = await _boot("default")
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.stage = StageDefs.last_of(1)
	_game.flow._set_state(_game.flow.BOSS)
	_game.events.boss_defeated.emit()
	_t.eq("END-2 non-final boss keeps victory beat", _game.flow.state_name(), "victory")
	_game.flow.physics_step(_game.flow.VICTORY_SECONDS + 0.01)
	_t.eq("END-2 non-final boss advances to next stage", _game.flow.state_name(), "stage")
	_t.eq("END-2 next world", _game.run.world, 2)
	_t.check("END-2 non-final win has no ending", not _game.screens.ending_open())
	_game.flow._set_state(_game.flow.BOSS)
	_game.events.player_died.emit()
	_t.eq("END-2 loss keeps death screen", _game.flow.state_name(), "dead")
	_t.check("END-2 death has no ending", not _game.screens.ending_open())
	_game.flow._end_run(false)
	_t.eq("END-2 spent run keeps lost summary", _game.flow.state_name(), "summary")
	_t.eq("END-2 lost summary copy", _game.screens._title.text, "RUN OVER")
	_t.check("END-2 loss summary has no ending", not _game.screens.ending_open())
	_game.free()
	_game = await _boot("slice")
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.flow._end_run_won()
	_t.eq("END-2 short table win keeps summary", _game.flow.state_name(), "summary")
	_t.check("END-2 short table has no sequence", not is_instance_valid(_game.screens.ending_sequence))
	# Quit follows the existing pause-menu action. SceneTree.quit schedules the exit,
	# so we can assert no ending or run-end save was triggered before it returns.
	_game.flow.new_run()
	# SG10 (2026-10-14): the human answers the new run's start-pick card before opening pause.
	Push.key(root, KEY_1)
	var ended := [0]
	_game.events.run_ended.connect(func(_won): ended[0] += 1)
	var menu = _game.get_node("PauseMenu")
	menu.open()
	_t.check("END-2 quit menu is open", menu._open)
	menu.confirm("quit")
	_t.eq("END-2 quit emits no run end", ended[0], 0)
	_t.check("END-2 quit has no ending", not _game.screens.ending_open())
	_game.free()
	quit(_t.verdict())


func _boot(table: String):
	var game := Game.new()
	game.test_mode = true
	game.table = table
	root.add_child(game)
	for i in 5:
		await physics_frame
	game.bot_driven = false
	game.ctx.calm = true
	return game
