extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ScreenBusy := preload("res://src/ui/screen_busy.gd")
const T := preload("res://tests/support/t.gd")

# A named fight is live from its first phase until its own enemy dies, read from the bus and not
# latched until a pressure emission (PF-19). A mini-boss enters phase one and dies while the stage's
# pressure stays flat (the world emits pressure only when it moves by 0.05): a waiting card shows
# within the quiet hold plus 60 frames of the death. Planted control: before the death it must NOT
# show, so the card is really being held by the fight; and the old latch (no clear on death) is the
# state this test fails in.

const SLACK_S := 1.0

var _t := T.new("screen_busy_fight_test")
var _game
var _clock := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _settle(seconds: float) -> void:
	var until := _clock + seconds
	while _clock < until:
		await process_frame
		_clock += _game.get_process_delta_time()


func _card_up() -> bool:
	return not _game.hud.ach_toasts().is_empty()


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _settle(0.1)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.presentation.flourish.stop_all()
	await _settle(1.0)
	_game.events.fight_phase_changed.emit("miniboss", 1, 2)
	_game.hud.tune_found("Phase Record")
	await _settle(ScreenBusy.SETTLE + SLACK_S)
	_t.check("planted control: a named fight in phase one holds the card", not _card_up() and _game.ctx.screen_busy.fighting(),
		"card up %s, fighting %s" % [_card_up(), _game.ctx.screen_busy.fighting()])
	_game.events.enemy_killed.emit("miniboss", Vector3.ZERO, 0)
	_t.check("its death ends the fight with the pressure never emitted", not _game.ctx.screen_busy.fighting(), "fighting %s" % _game.ctx.screen_busy.fighting())
	var shown_at := -1.0
	var over_at := _clock
	while _clock < over_at + ScreenBusy.SETTLE + SLACK_S and shown_at < 0.0:
		await _settle(0.02)
		if _card_up():
			shown_at = _clock - over_at
	_t.check("the waiting card shows within the quiet hold plus 60 frames of the death", shown_at >= 0.0, "shown after %.2f s" % shown_at)
	quit(_t.verdict())
