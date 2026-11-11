extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Push := preload("res://tests/workshop/push.gd")

# RS6: the title offers Continue only when the run store holds a valid unfinished run.
#   - no file: no Continue, the start button reads Start, C does nothing;
#   - a saved run: Continue leads the title's buttons; C resumes it, and so does a pad's
#     d-pad (focus lands on the first button) then A;
#   - an unreadable, newer-schema or invalid file: the title names its cause, offers New run
#     only, and C does nothing.

const DIR := "user://ui_continue_test/"
const PATH := DIR + "run.json"

var _game
var _failures := 0


func _initialize() -> void:
	_wipe()
	_run.call_deferred()


func _wipe() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _boot() -> void:
	if _game != null:
		_game.free()
	_game = Game.new()
	_game.test_mode = true
	_game.run_store_path = PATH
	root.add_child(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	await _frames(3)


func _buttons() -> Array:
	var out := []
	for id in ["continue", "start"]:
		var button: Button = _game.screens.button_for(id)
		out.append([id, button.text if button != null else ""])
	return out


# Boots a game that starts a run and leaves at stage 1's entrance, so the file holds a run.
func _save_a_run() -> void:
	await _boot()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(2)


func _bad_file(label: String, text: String, cause: String) -> void:
	_wipe()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	await _boot()
	var body: String = _game.screens.body_text()
	var no_continue: bool = _game.screens.button_for("continue") == null
	var start: Button = _game.screens.button_for("start")
	_game._screen_key(KEY_C)
	# The title says the run would not load in a sentence; the cause id stays data on the flow (wave 36).
	_report(label, no_continue and start != null and start.text == "New run" and body.contains("The saved run would not load.")
			and _game.flow.saved_run_cause == cause and _game.flow.state_name() == "title",
		"title body \"%s\"; cause %s; buttons %s; after C flow %s" % [body.replace("\n", " | "), _game.flow.saved_run_cause, _buttons(), _game.flow.state_name()])


func _run() -> void:
	await _boot()
	_game._screen_key(KEY_C)
	_report("no saved run", _game.screens.button_for("continue") == null and _game.screens.button_for("start").text == "Play"
			and _game.flow.state_name() == "title",
		"buttons %s; after C flow %s" % [_buttons(), _game.flow.state_name()])

	await _save_a_run()
	await _boot()
	var first: Node = _game.screens.button_for("continue")
	var leads: bool = first != null and first.get_index() == 0 and _game.screens.button_for("start").text == "New run"
	_game._screen_key(KEY_C)
	_report("keyboard continue", leads and _game.flow.state_name() == "stage" and _game.run.stage == 1,
		"buttons before %s, Continue first %s; after C flow %s stage %d" % [["continue", "New run"], leads, _game.flow.state_name(), _game.run.stage])

	await _boot()
	Push.pad(root, JOY_BUTTON_DPAD_DOWN)
	await _frames(2)
	var focus := root.gui_get_focus_owner()
	var on_continue: bool = focus != null and focus == _game.screens.button_for("continue")
	Push.pad(root, JOY_BUTTON_A)
	await _frames(2)
	_report("pad continue", on_continue and _game.flow.state_name() == "stage",
		"d-pad focus on Continue %s; after A flow %s" % [on_continue, _game.flow.state_name()])

	await _bad_file("corrupt file", "{ not json", "unreadable")
	await _bad_file("newer schema", JSON.stringify({"schema": 99, "generation": 1, "run": {}}), "newer_schema")
	await _bad_file("invalid run", JSON.stringify({"schema": 1, "generation": 1, "run": {"schema": 1}}), "invalid_run")

	_game.free()
	_wipe()
	print("ui_continue_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
