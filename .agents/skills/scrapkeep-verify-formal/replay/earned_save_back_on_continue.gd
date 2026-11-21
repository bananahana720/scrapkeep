extends SceneTree

# Replays the SaveOnce counterexample of models/EarnedSave.tla (config earnedsave-today) on the real game, one model
# step per call:
#   Launch, NewRun, TakePart (the Spare Frame, written into the stage entrance), Hit with the run write failing
#   (run_state._try_death_save spends the save; flow._on_death_saved's _save is refused), Quit (to the desktop: no
#   write), Launch, Continue (flow.resume_run), Hit.
# The failed write is real: a directory sits where safe_store.gd puts the run file's temp file, so store.save()
# returns write_failed through its own write path. No game code is changed.
# It prints REPRODUCED when the continued run holds the save unspent and its next killing hit leaves the ball alive a
# second time, NOT REPRODUCED otherwise. The control (`-- --control` after the script) leaves the write failure out;
# it must print NOT REPRODUCED.
# Copy it into sketches/core-loop/tests/ to run it (SKILL.md, "Read a result"); it is not a suite test. Run it with
# HOME (and XDG_DATA_HOME on the PC) set to a scratch folder so no real save is touched.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const SafeStore := preload("res://src/core/safe_store.gd")

const DIR := "user://replay_earned_save/"
const PATH := DIR + "run.json"

var control := OS.get_cmdline_user_args().has("--control")


func _initialize() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(DIR)
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


func _run() -> void:
	var died := [0]
	# Launch, NewRun.
	var game = await _boot()
	game.flow.press_start()
	game.flow.choose_class(1)
	for i in 5:
		await process_frame
	# TakePart: the Spare Frame, then a stage entrance that writes it into the run document.
	game.run.add_part("spare_frame", "replay")
	game.build.recompute()
	game.flow.enter_stage(1, Vector3(0.0, 0.0, 14.0), false)
	print("step take part: disk parts hold it %s, disk death_save_spent %s, store_error '%s'" % [
		_disk().get("parts", []).has("spare_frame"), _disk().get("death_save_spent", false), game.flow.store_error])
	# Hit, with the run write failing.
	var blocker := SafeStore.tmp_path(PATH)
	if not control:
		DirAccess.make_dir_recursive_absolute(blocker)
	game.events.player_died.connect(func(): died[0] += 1)
	game.run.damage(99999.0, "replay")
	print("step hit: alive %s, flow %s, run death_save_spent %s, store_error '%s', disk death_save_spent %s" % [
		game.run.alive(), game.flow.state_name(), game.run.death_save_spent, game.flow.store_error,
		_disk().get("death_save_spent", false)])
	# Quit to the desktop: the pause menu's quit calls get_tree().quit() and writes nothing.
	game.free()
	await process_frame
	DirAccess.remove_absolute(blocker)
	print("step quit: disk death_save_spent %s" % _disk().get("death_save_spent", false))
	# Launch, Continue.
	game = await _boot()
	var offered: bool = game.flow.continue_ready
	var resumed: bool = game.flow.resume_run()
	game.build.recompute()
	print("step continue: offered %s, resumed %s, run death_save_spent %s, parts hold it %s" % [
		offered, resumed, game.run.death_save_spent, game.run.parts.has("spare_frame")])
	# Hit again.
	game.events.player_died.connect(func(): died[0] += 1)
	game.run.damage(99999.0, "replay")
	var second_life: bool = game.run.alive() and game.flow.state_name() == "stage" and not game.run.over
	print("step hit again: alive %s, flow %s, player_died %d, run over %s" % [
		game.run.alive(), game.flow.state_name(), died[0], game.run.over])
	game.free()
	await process_frame
	_clean()
	print("REPRODUCED" if second_life else "NOT REPRODUCED")
	quit(0)
