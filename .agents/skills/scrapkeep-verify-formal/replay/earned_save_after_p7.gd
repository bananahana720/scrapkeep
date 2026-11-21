extends SceneTree

# Replays three paths of models/EarnedSave.tla on the real game after P7 (the owed spend, _save_spend_owed), one model
# step per call. Each refused write is real: a directory sits where safe_store.gd puts the run file's temp file, so
# store.save() and store.clear() fail through their own write path. No game code is changed.
#   es1: Launch, NewRun, TakePart (the Spare Frame, written into the stage entrance), Hit with the spend write
#        refused, the disk back, Quit (the game freed: flow._exit_tree flushes the owed spend), Launch, Continue, Hit.
#        P7 closes ES-1: the continued run holds the save spent and the hit ends it (NOT REPRODUCED).
#   es2: the same with the disk still refusing at the death: Hit (spend refused), Hit (the run dies and its tombstone
#        is refused, so the file keeps the run), the disk back, Quit, Launch, Continue, Hit. _record_end empties
#        _entrance before the clear, so the exit has nothing to flush (config earnedsave-es2-only).
#   es3: Launch, NewRun, TakePart, Hit with the spend write refused, then a restart from play (flow.new_run, what the
#        pause menu's Restart and a held R call) whose first entrance is refused too: _begin_run clears the debt and
#        flushes nothing. The disk back, the title (show_title, nothing owed to flush), Continue in the same process,
#        Hit (config earnedsave-today-inprocess, finding ES-3).
# Each step prints REPRODUCED when the continued run's hit leaves the ball alive a second time with the save, NOT
# REPRODUCED otherwise.
# Run it in place (Godot takes an absolute script path) with HOME and XDG_DATA_HOME set to a scratch folder so no real
# save is touched:
#   "$GODOT_BIN" --headless --path sketches/core-loop --script "$PWD/.agents/skills/scrapkeep-verify-formal/replay/earned_save_after_p7.gd"

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const SafeStore := preload("res://src/core/safe_store.gd")

const DIR := "user://replay_earned_save_p7/"
const PATH := DIR + "run.json"


func _initialize() -> void:
	_run.call_deferred()


func _clean() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		return
	for d in DirAccess.get_directories_at(DIR):
		DirAccess.remove_absolute(DIR + d)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	DirAccess.remove_absolute(DIR)


func _boot():
	var game := Game.new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	for i in 2:
		await process_frame
	return game


func _disk() -> Dictionary:
	return RunStore.new(PATH).load()


func _path(clear_refused: bool) -> bool:
	_clean()
	DirAccess.make_dir_recursive_absolute(DIR)
	var died := [0]
	var game = await _boot()
	game.flow.press_start()
	game.flow.choose_class(1)
	for i in 5:
		await process_frame
	game.run.add_part("spare_frame", "replay")
	game.build.recompute()
	game.flow.enter_stage(1, Vector3(0.0, 0.0, 14.0), false)
	print("  take part: disk parts hold it %s, disk death_save_spent %s" % [
		_disk().get("parts", []).has("spare_frame"), _disk().get("death_save_spent", false)])
	var blocker := SafeStore.tmp_path(PATH)
	DirAccess.make_dir_recursive_absolute(blocker)
	game.events.player_died.connect(func(): died[0] += 1)
	game.run.damage(99999.0, "replay")
	print("  hit (spend refused): alive %s, run death_save_spent %s, store_error '%s', owed %s, disk death_save_spent %s" % [
		game.run.alive(), game.run.death_save_spent, game.flow.store_error, game.flow._save_spend_owed,
		_disk().get("death_save_spent", false)])
	if clear_refused:
		game.run.damage(99999.0, "replay")
		print("  hit (dies, clear refused): alive %s, flow %s, store_error '%s', owed %s, entrance held %s, disk holds the run %s" % [
			game.run.alive(), game.flow.state_name(), game.flow.store_error, game.flow._save_spend_owed,
			not game.flow._entrance.is_empty(), not _disk().is_empty()])
	DirAccess.remove_absolute(blocker)
	game.free()
	await process_frame
	print("  quit (disk back): disk death_save_spent %s" % _disk().get("death_save_spent", false))
	game = await _boot()
	var offered: bool = game.flow.continue_ready
	var resumed: bool = game.flow.resume_run()
	game.build.recompute()
	print("  continue: offered %s, resumed %s, run death_save_spent %s, parts hold it %s" % [
		offered, resumed, game.run.death_save_spent, game.run.parts.has("spare_frame")])
	game.events.player_died.connect(func(): died[0] += 1)
	game.run.damage(99999.0, "replay")
	var second_life: bool = resumed and game.run.alive() and game.flow.state_name() == "stage" and not game.run.over
	print("  hit again: alive %s, flow %s, player_died %d, run over %s" % [
		game.run.alive(), game.flow.state_name(), died[0], game.run.over])
	game.free()
	await process_frame
	_clean()
	return second_life


func _restart_path() -> bool:
	_clean()
	DirAccess.make_dir_recursive_absolute(DIR)
	var game = await _boot()
	game.flow.press_start()
	game.flow.choose_class(1)
	for i in 5:
		await process_frame
	game.run.add_part("spare_frame", "replay")
	game.build.recompute()
	game.flow.enter_stage(1, Vector3(0.0, 0.0, 14.0), false)
	print("  take part: disk parts hold it %s, disk death_save_spent %s" % [
		_disk().get("parts", []).has("spare_frame"), _disk().get("death_save_spent", false)])
	var blocker := SafeStore.tmp_path(PATH)
	DirAccess.make_dir_recursive_absolute(blocker)
	game.run.damage(99999.0, "replay")
	print("  hit (spend refused): alive %s, run death_save_spent %s, owed %s, disk death_save_spent %s" % [
		game.run.alive(), game.run.death_save_spent, game.flow._save_spend_owed, _disk().get("death_save_spent", false)])
	game.flow.new_run()
	for i in 2:
		await process_frame
	print("  restart (entrance refused): flow %s, store_error '%s', owed %s, run parts hold it %s, disk parts hold it %s, disk death_save_spent %s" % [
		game.flow.state_name(), game.flow.store_error, game.flow._save_spend_owed, game.run.parts.has("spare_frame"),
		_disk().get("parts", []).has("spare_frame"), _disk().get("death_save_spent", false)])
	DirAccess.remove_absolute(blocker)
	game.flow.show_title()
	for i in 2:
		await process_frame
	print("  title (disk back): owed %s, disk death_save_spent %s, continue offered %s" % [
		game.flow._save_spend_owed, _disk().get("death_save_spent", false), game.flow.continue_ready])
	var resumed: bool = game.flow.resume_run()
	game.build.recompute()
	print("  continue: resumed %s, run death_save_spent %s, parts hold it %s" % [
		resumed, game.run.death_save_spent, game.run.parts.has("spare_frame")])
	var died := [0]
	game.events.player_died.connect(func(): died[0] += 1)
	game.run.damage(99999.0, "replay")
	var second_life: bool = resumed and game.run.alive() and game.flow.state_name() == "stage" and not game.run.over
	print("  hit again: alive %s, flow %s, player_died %d, run over %s" % [
		game.run.alive(), game.flow.state_name(), died[0], game.run.over])
	game.free()
	await process_frame
	_clean()
	return second_life


func _run() -> void:
	print("es1:")
	print("es1: " + ("REPRODUCED" if await _path(false) else "NOT REPRODUCED"))
	print("es2:")
	print("es2: " + ("REPRODUCED" if await _path(true) else "NOT REPRODUCED"))
	print("es3:")
	print("es3: " + ("REPRODUCED" if await _restart_path() else "NOT REPRODUCED"))
	quit(0)
