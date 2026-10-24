extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const Profile := preload("res://src/core/profile.gd")
const T := preload("res://tests/support/t.gd")

# Codex review w18 (tech #1): a companion piece earned mid-stage was lost to a restart (pause
# menu Restart, or held R), because only a stage entry or a run end wrote it to the profile and
# new_run reseeds from the profile. On a saving profile, the piece an activity pays reaches the
# profile on disk at once, and the restarted run starts with it.

var _t := T.new("companion_restart_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


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
	var before: Dictionary = _game.run.companion.duplicate(true)
	var piece := Companion.next_drop(before)
	_t.check("a piece is still to find", piece != "", str(before))
	# The activity pays its piece and announces itself done, as activities._finish does.
	var activities = _game.world.activities
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
