extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")

# SAFE1: a run file that loads as no run names why. A newer-schema file, a file changed on
# disk into something unreadable and an ended run's tombstone each load with `refusal` set
# and a player sentence (one line, no path); the file is never deleted or rewritten (the
# unreadable one is moved aside whole as .bad). A booted Game's continue_refusal() is "" with
# a good run and with no run, and the sentence for a refused one.

const DIR := "user://run_store_refusal_test/"
const PATH := DIR + "run.json"


class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld


var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("  %s %s%s" % ["ok  " if ok else "FAIL", label, "" if detail.is_empty() else " (%s)" % detail])


func _wipe() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)


func _write(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _boot():
	var game := TwoWorldGame.new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	await _frames(3)
	return game


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _sentence_ok(s: String) -> bool:
	return s != "" and not s.contains("\n") and not s.contains("://") and not s.contains("run.json")


func _run() -> void:
	_wipe()
	var game = await _boot()
	game.flow.saved_run()
	_report("no run: continue_refusal is empty", game.continue_refusal() == "" and not game.flow.continue_ready, "'%s'" % game.continue_refusal())
	game.flow.press_start()
	game.flow.choose_class(0)
	await _frames(3)
	var good := FileAccess.get_file_as_string(PATH)
	game.free()
	game = await _boot()
	game.flow.saved_run()
	_report("good run: Continue offered and continue_refusal is empty", game.flow.continue_ready and game.continue_refusal() == "", "'%s'" % game.continue_refusal())
	game.free()

	var cases := {
		RunStore.REFUSED_NEWER: '{"schema": 9, "generation": 4, "run": {"x": 1}}',
		RunStore.REFUSED_CHANGED: '{"schema": 1, "generation": 3, "run": {"stage":',
		RunStore.REFUSED_ENDED: '{"schema": 1, "generation": 5, "ended": true}',
	}
	for cause in cases:
		_wipe()
		_write(cases[cause])
		var bytes := FileAccess.get_file_as_bytes(PATH)
		var store := RunStore.new(PATH)
		var doc := store.load()
		var sentence := store.refusal_sentence()
		var kept := FileAccess.get_file_as_bytes(PATH + ".bad" if cause == RunStore.REFUSED_CHANGED else PATH) == bytes
		_report("%s: refusal and a sentence" % cause, doc.is_empty() and store.refusal == cause and _sentence_ok(sentence) and store.last_error != "",
				"refusal '%s', sentence '%s'" % [store.refusal, sentence])
		_report("%s: the file is kept byte for byte" % cause, kept, "")
		if cause == RunStore.REFUSED_CHANGED:
			_write(cases[cause])
		game = await _boot()
		game.flow.saved_run()
		var shown: String = game.continue_refusal()
		_report("%s: the game names it" % cause, not game.flow.continue_ready and shown == RunStore.SENTENCES[cause], "'%s'" % shown)
		game.free()

	_wipe()
	_write(good.replace('"class_id"', '"class_gone"'))
	game = await _boot()
	game.flow.saved_run()
	_report("invalid run: the game names it", not game.flow.continue_ready and _sentence_ok(game.continue_refusal()), "'%s'" % game.continue_refusal())
	game.free()

	_wipe()
	print("run_store_refusal_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
