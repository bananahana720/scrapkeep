extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# ST5-4: a saved run the store refuses (a newer schema) leaves the title with the store's
# sentence under the button row and New run focused; with no saved run the title shows no
# refusal and focuses nothing. The sentence is game.continue_refusal() when the build has it,
# else the run store's last_error.

const DIR := "user://title_continue_refusal_test/"
const PATH := DIR + "run.json"

var _t := preload("res://tests/support/t.gd").new("title_continue_refusal_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _wipe() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)


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


func _run() -> void:
	_wipe()
	await _boot()
	_t.eq("no saved run: no refusal line", _game.screens.refusal_text(), "")
	_t.check("no saved run: nothing focused", root.gui_get_focus_owner() == null, str(root.gui_get_focus_owner()))

	_wipe()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 99, "generation": 1, "run": {}}))
	file.close()
	await _boot()
	var store_says: String = _game.continue_refusal() if _game.has_method("continue_refusal") else String(_game.flow.store.last_error)
	var shown: String = _game.screens.refusal_text()
	_t.check("the store refused it", _game.flow.saved_run_cause == "newer_schema" and store_says != "", "%s: %s" % [_game.flow.saved_run_cause, store_says])
	_t.check("the title shows the sentence", shown.contains(store_says) and store_says != "", shown)
	var line: Control = _game.screens._refusal
	var row: Control = _game.screens._actions
	_t.check("the sentence sits under the button row", line.is_visible_in_tree() and line.get_parent() == row.get_parent() and line.get_index() == row.get_index() + 1,
		"refusal index %d, actions %d" % [line.get_index(), row.get_index()])
	var start: Button = _game.screens.button_for("start")
	_t.check("New run is focused", start != null and start.text == "New run" and root.gui_get_focus_owner() == start, str(root.gui_get_focus_owner()))
	_t.check("no Continue", _game.screens.button_for("continue") == null, "")

	_game.free()
	_wipe()
	quit(_t.verdict())
