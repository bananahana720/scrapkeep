extends SceneTree

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Push := preload("res://tests/support/push.gd")
const T := preload("res://tests/support/t.gd")

# The ending page (prog-G5): a win over the final world's boss opens the summary on
# Worlds.ENDING before the stats. Keys are pushed into the viewport for the screens; the game
# skips its own _input in test mode, so each press is also fed to _screen_key the way the
# game would read it. Checks:
#   the Mind's victory screen shows its HIRED stamp and Brindle's shows none;
#   a final win shows the page with the summary actions hidden; Space inside ENDING_HOLD
#   neither closes it nor starts a run; Space after closes it onto RUN COMPLETE with the
#   Mind's epitaph, still in summary, run_ended fired once;
#   pad A just after closing, with the closing key still held, does not restart (the input latch);
#   with bot_driven set the page closes itself after ENDING_HOLD;
#   a loss, a Brindle win on the alpha table that ends at stage 2, and a world-1 win on the
#   slice table show no page;
#   the copy caps prog-G6 writes to.

var _t := T.new("ui_ending_screen_test")
var _game
var _ended := 0


func _initialize() -> void:
	_run.call_deferred()


func _boot(table: String):
	var game = Game.new()
	game.table = table
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await process_frame
	for i in 5:
		await process_frame
	game.ctx.calm = true
	game.bot_driven = false
	return game


func _settle(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= _game.get_process_delta_time()


func _key(code: Key) -> void:
	Push.key(root, code)
	_game._screen_key(code)


# Beat the boss of the world `stage` sits in, then end the run as the flow would.
func _end_at(stage: int, won: bool) -> void:
	_game.run.stage = stage
	_game.flow._set_state(_game.flow.VICTORY)
	_game.flow._end_run(won)


func _run() -> void:
	_game = await _boot("")
	var flow = _game.flow
	var screens = _game.screens
	_game.events.run_ended.connect(func(_won): _ended += 1)
	var mind: Dictionary = Worlds.BOSSES["mind"]

	# The Mind's victory screen inks its stamp (HIRED, "All hands") under the title.
	_game.run.stage = StageDefs.COUNT
	flow._set_state(flow.VICTORY)
	_t.check("mind victory: the stamp shows", screens._mark.visible, "hidden")
	_t.eq("mind victory: the stamp is the row's", screens._mark.text, String(mind["stamp"]))
	flow._set_state(flow.TITLE)
	_game.run.stage = 1
	flow._set_state(flow.VICTORY)
	_t.check("brindle victory: no stamp", not screens._mark.visible, screens._mark.text)
	flow._set_state(flow.TITLE)

	# A final win, played by a human.
	_end_at(StageDefs.COUNT, true)
	_t.eq("final win: state is summary", flow.state_name(), "summary")
	_t.check("final win: the ending page is open", screens.ending_open(), "closed")
	_t.eq("final win: the page title is ENDING's", screens._ending_title.text, String(Worlds.ENDING["title"]))
	_t.check("final win: the summary actions are hidden", not screens._actions.visible, "actions visible")
	_t.check("final win: the stats are hidden", not screens._stats.visible, "stats visible")
	_t.check("final win: the comic row is hidden under the page", not screens._comic_row.visible, "comic row visible")
	_key(KEY_SPACE)
	await process_frame
	_t.check("Space inside the hold leaves the page open", screens.ending_open(), "closed early")
	_t.eq("Space inside the hold starts no run", flow.state_name(), "summary")
	await _settle(screens.ENDING_HOLD + 0.1)
	_t.check("the page waits for a human after the hold", screens.ending_open(), "closed with no press")
	_hold(KEY_SPACE, true)
	_key(KEY_SPACE)
	await process_frame
	_t.check("Space after the hold closes the page", not screens.ending_open(), "still open")
	_t.eq("closing leaves the state in summary", flow.state_name(), "summary")
	_t.check("the summary reads RUN COMPLETE", screens._title.text.contains("RUN COMPLETE"), screens._title.text)
	_t.check("the summary holds the Mind's epitaph", screens.said_body().contains(String(mind["epitaph"])), screens.said_body())
	_t.check("the summary actions are back", screens._actions.visible and screens._actions.get_child_count() > 0, "hidden")
	_t.check("the comic row is back", screens._comic_row.visible, "hidden")
	_t.eq("run_ended fired once", _ended, 1)
	Push.pad(root, JOY_BUTTON_A)
	_game._screen_key(_game.pad_screen_key(_pad(JOY_BUTTON_A)))
	await process_frame
	_t.eq("pad A just after closing, Space still held, does not restart", flow.state_name(), "summary")
	_hold(KEY_SPACE, false)
	await process_frame

	# A final win with a bot driving: the page closes itself.
	_game.bot_driven = true
	_end_at(StageDefs.COUNT, true)
	_t.check("bot: the page opens", screens.ending_open(), "closed")
	await _settle(screens.ENDING_HOLD + 0.1)
	_t.check("bot: the page closes itself after the hold", not screens.ending_open(), "still open")
	_t.check("bot: the summary reads RUN COMPLETE", screens._title.text.contains("RUN COMPLETE"), screens._title.text)
	_game.bot_driven = false

	# A loss after the final boss's victory screen.
	_end_at(StageDefs.COUNT, false)
	_t.eq("loss: state is summary", flow.state_name(), "summary")
	_t.check("loss: no ending page", not screens.ending_open(), "open")
	_t.check("loss: the actions show", screens._actions.visible, "hidden")

	# Brindle beaten on the alpha table, with the run ending at stage 2.
	_end_at(2, true)
	_t.eq("brindle at stage 2: the victory row was Brindle's", screens.said_body().contains(String(Worlds.BOSSES["brindle"]["epitaph"])), true)
	_t.check("brindle at stage 2: no ending page", not screens.ending_open(), "open")

	# A world-1 win on the slice table.
	_game.free()
	_game = await _boot("slice")
	_end_at(1, true)
	_t.eq("slice win: state is summary", _game.flow.state_name(), "summary")
	_t.check("slice win: no ending page", not _game.screens.ending_open(), "open")

	_copy_caps()
	quit(_t.verdict())


func _pad(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _words(text: String) -> int:
	return text.split(" ", false).size()


func _copy_caps() -> void:
	var total := _words(String(Worlds.ENDING["sign"]))
	var log_lines: Array = []
	for world_id in [1, 2, 3]:
		_t.check("copy: world %d has two log lines" % world_id, Worlds.ENDING["log"].get(world_id, []).size() == 2, str(Worlds.ENDING["log"].get(world_id, []).size()))
		log_lines.append_array(Worlds.ENDING["log"].get(world_id, []))
	log_lines.append_array(Worlds.ENDING["close"])
	for line in log_lines:
		_t.check("copy: log line has 14 words or fewer", _words(line) <= 14, "%d: %s" % [_words(line), line])
		total += _words(line)
	_t.check("copy: log plus close plus sign is 40 to 120 words", total >= 40 and total <= 120, str(total))
	_t.check("copy: title is 4 words or fewer", _words(Worlds.ENDING["title"]) <= 4, Worlds.ENDING["title"])
	for id in Worlds.BOSSES:
		for field in ["victory", "epitaph"]:
			var line := String(Worlds.BOSSES[id][field])
			_t.check("copy: %s %s is 12 words or fewer" % [id, field], _words(line) <= 12, line)


# Holds or releases a physical key in the Input singleton, as a finger on it would.
func _hold(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
