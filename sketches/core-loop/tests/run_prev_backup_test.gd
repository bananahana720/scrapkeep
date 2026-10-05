extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const T := preload("res://tests/support/t.gd")

# New run keeps the old save (owner ruling): before the first save of a new run replaces
# run.json, its bytes are copied to run.json.prev. RunStore.restore_prev swaps it back in.

const DIR := "user://run_prev_backup_test/"
const PATH := DIR + "run.json"

var t := T.new("run_prev_backup_test")
var _game


func _initialize() -> void:
	_wipe()
	_run.call_deferred()


func _wipe() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _boot():
	var game = load("res://src/game.gd").new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	await _frames(3)
	return game


func _begin(game) -> void:
	game.flow.press_start()
	game.flow.choose_class(1)
	await _frames(3)


func _file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _run_id(path: String) -> String:
	return str(_file(path).get("run", {}).get("run_id", ""))


func _gen(path: String) -> int:
	return int(_file(path).get("generation", -1))


func _run() -> void:
	_game = await _boot()
	await _begin(_game)
	var first_id: String = _game.run.run_id
	t.check("a) first run, no prior save: no .prev", not FileAccess.file_exists(PATH + ".prev") and _run_id(PATH) == first_id,
		"run id %s, .prev exists %s" % [first_id, FileAccess.file_exists(PATH + ".prev")])
	var gen_first := _gen(PATH)
	_game.free()

	_game = await _boot()
	t.check("b0) title offers continue", _game.flow.continue_ready, "continue_ready %s" % _game.flow.continue_ready)
	await _begin(_game)
	var second_id: String = _game.run.run_id
	t.check("b) new run keeps the old: .prev has the old id, run.json the new",
		first_id != second_id and _run_id(PATH + ".prev") == first_id and _run_id(PATH) == second_id,
		"old %s new %s prev %s file %s" % [first_id, second_id, _run_id(PATH + ".prev"), _run_id(PATH)])
	var gen_second := _gen(PATH)
	var gen_prev := _gen(PATH + ".prev")
	_game.free()

	var store := RunStore.new(PATH)
	var ok := store.restore_prev()
	var doc := store.load()
	t.check("c) restore_prev swaps the old run back in", ok and str(doc.get("run_id", "")) == first_id and _run_id(PATH + ".prev") == second_id,
		"ok %s loaded %s prev %s err %s" % [ok, doc.get("run_id", ""), _run_id(PATH + ".prev"), store.last_error])
	var gen_back := _gen(PATH)
	t.check("d) restored generation is above both earlier files", gen_back > gen_second and gen_back > gen_prev and gen_back > gen_first,
		"first %d second %d prev %d restored %d" % [gen_first, gen_second, gen_prev, gen_back])

	_wipe()
	DirAccess.remove_absolute(DIR)
	quit(t.verdict())
