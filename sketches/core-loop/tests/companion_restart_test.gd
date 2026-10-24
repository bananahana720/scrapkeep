extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const Profile := preload("res://src/core/profile.gd")
const T := preload("res://tests/support/t.gd")

# Codex review w18 (tech #1): a companion piece earned mid-stage was lost to a restart (pause
# menu Restart, or held R), because only a stage entry or a run end wrote it to the profile and
# new_run reseeds from the profile. On a saving profile, the piece an activity pays reaches the
# profile on disk at once; a stage retry keeps it; a quit and Continue (whose zone entrance
# predates the piece) keeps it and does not write the older companion back over the profile; and
# the restarted run starts with it. The Game runs with a run store, as the real game does.

const STORE := "user://companion_restart_test/run.json"

var _t := T.new("companion_restart_test")
var _game


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(STORE.get_base_dir())
	DirAccess.remove_absolute(STORE)
	_game = _boot()
	_run.call_deferred()


func _boot():
	var game := Game.new()
	game.test_mode = true
	game.run_store_path = STORE
	root.add_child(game)
	return game


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	var flow = _game.flow
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	flow.press_start()
	flow.choose_class(1)
	await _frames(20)
	var profile = _game.ctx.profile
	_t.check("the profile saves", profile.can_save)
	var activities = _game.world.activities
	# A first piece, then a stage entry: the zone entrance on disk holds that older companion.
	activities._pay_piece()
	_game.events.activity_done.emit("first_activity", _game.player.ball_position())
	flow.enter_stage(_game.run.stage, Vector3.ZERO, false)
	await _frames(5)
	var before: Dictionary = _game.run.companion.duplicate(true)
	var piece := Companion.next_drop(before)
	_t.check("a first piece is owned and another is still to find", not before.get("owned", []).is_empty() and piece != "", str(before))
	# The activity pays its piece and announces itself done, as activities._finish does.
	activities._piece_paid = false
	activities._pay_piece()
	_game.events.activity_done.emit("test_activity", _game.player.ball_position())
	await _frames(2)
	var earned: Dictionary = _game.run.companion.duplicate(true)
	_t.check("the run holds the piece", earned != before and Companion.next_drop(earned) != piece, str(earned))
	_t.eq("the profile took the piece at once", profile.companion(), earned)
	var disk := Profile.new(profile.path)
	disk.load_profile()
	_t.eq("the profile on disk holds the piece", disk.companion(), earned)
	# A stage retry rolls the run back to the stage start; the found piece stays, and a later
	# persist (the next stage entry's save) does not write the older companion over the profile.
	flow.retry_stage()
	await _frames(3)
	_t.eq("a retry keeps the piece", _game.run.companion, earned)
	flow._persist_companion()
	_t.eq("and the profile still holds it after a persist", profile.companion(), earned)
	# Quit and Continue: the run resumes from its zone entrance on disk, saved before the piece.
	# (A Game in test mode deletes its storage when freed, so the quit is a return to the title.)
	flow.show_title()
	await _frames(2)
	_t.eq("the zone entrance on disk holds the older companion",
		(flow.saved_run().get("companion", {}) as Dictionary).get("owned", []), before.get("owned", []))
	_t.check("Continue resumes the run", flow.resume_run())
	await _frames(5)
	_t.eq("the resumed run holds the piece", _game.run.companion.get("owned", []), earned.get("owned", []))
	disk = Profile.new(profile.path)
	disk.load_profile()
	_t.eq("the resumed stage entry's save kept the piece on disk", disk.companion().get("owned", []), earned.get("owned", []))
	# Restart from the pause menu: the same call held R makes with a run store.
	var menu = _game.get_node_or_null("PauseMenu")
	while menu == null:
		await process_frame
		menu = _game.get_node_or_null("PauseMenu")
	menu.open()
	menu.press("restart")
	await _frames(5)
	_t.eq("the restarted run starts with the piece", _game.run.companion, earned)
	_game.queue_free()
	quit(_t.verdict())
