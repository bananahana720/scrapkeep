extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# The explorer (the completionist policy) reaches the Reach's enemy camp (alpha wave 7). The slice
# table's map is the Cable Reach; its camp stands on the west shelf about 22 m above the trough the
# explorer works last. One seeded run: from the first frame the camp is the bot's target, the ball
# must roll into the camp's ring (the site starts its pack) within ACTIVITY_SECONDS, the camp must
# be in the activities_entered note, and the ball must never sit under STUCK_SPEED for 60 s
# straight. Before the fix the bot steered straight at the camp and wedged under the shelf's cliff
# near (-33, 7, 50) until the camp's 40 s ran out, so the ring never started.
#
# Evidence limit: one seed of the headless bot; the 16-seed count is the coordinator's bot_run sweep.

const SEED := 1
const TICK_LIMIT := 150 * 90
const STUCK_WINDOW := 60.0

var _game
var _driver
var _t := T.new("bot_explorer_camp_path_test")
var _ticks := 0
var _camp_ticks := 0
var _slow := 0.0
var _slowest := 0.0
var _started_at := -1.0
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "completionist", SEED)
		_driver.start()
		return false
	_ticks += 1
	var over: bool = _driver.tick(delta)
	var player = _game.player
	if player.planar_velocity().length() < BotDriver.STUCK_SPEED and player.state.grounded:
		_slow += delta
		_slowest = maxf(_slowest, _slow)
	else:
		_slow = 0.0
	var camp = _camp()
	if _driver._activity == "enemy_camp" or _camp_ticks > 0:
		_camp_ticks += 1
	if camp != null and camp.started and _started_at < 0.0:
		_started_at = float(_camp_ticks) / 90.0
	var budget_out := float(_camp_ticks) / 90.0 > BotDriver.ACTIVITY_SECONDS
	if over or _ticks > TICK_LIMIT or _started_at >= 0.0 or budget_out:
		_finish()
		return true
	return false


func _camp():
	if _game.world == null or _game.world.activities == null:
		return null
	return _game.world.activities.site("enemy_camp")


func _finish() -> void:
	_done = true
	var ball: Vector3 = _game.player.ball_position()
	_t.check("the explorer turns to the camp", _camp_ticks > 0,
		"first camp frame after %.1f s; goal '%s'" % [float(_ticks - _camp_ticks) / 90.0, _driver._goal])
	_t.check("the camp is in the activities_entered note", "enemy_camp" in _driver._note.get("activities_entered", []),
		"entered %s" % [_driver._note.get("activities_entered", [])])
	_t.check("the ball rolls into the camp's ring inside ACTIVITY_SECONDS", _started_at >= 0.0
		and _started_at <= BotDriver.ACTIVITY_SECONDS,
		"ring started %.1f s after the camp became the target (budget %.0f s); ball at (%.1f, %.1f, %.1f), goal '%s'"
			% [_started_at, BotDriver.ACTIVITY_SECONDS, ball.x, ball.y, ball.z, _driver._goal])
	_t.check("no 60 s stretch under STUCK_SPEED", _slowest < STUCK_WINDOW, "longest slow stretch %.1f s" % _slowest)
	_t.check("the game is bot driven", _game.bot_driven)
	_game.free()
	quit(_t.verdict())
