# smoke: solo timeout=180s (one fixed-90-fps child, its own 120 s wall budget)
extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const Game := preload("res://src/game.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const T := preload("res://tests/support/t.gd")

# Spillway stage 1 on the default table (red team w15 sweep b2, Tarn random seed 35221). The Warden
# stands on a shelf 16 m up; the random bot wandered down into the basin south of it and from
# t=46 s to the 240 s stage limit pushed at the 14 m face under the shelf. tools/bot_driver.gd
# _climb_route found no way up within CLIMB_SLOPE 0.5, since the basin's way out climbs a little
# steeper, so _fight_way_up steered straight at the Warden. The skipper on the same seed, which
# never leaves the shelf, breaks the Warden in 56 s, so the stage is fine and the bot was not.
# Pins, from the ball's stall point on that run, (-54, 2, 50):
#   route   the bot's climb plan to the Warden (_climb_route_any) is not empty and ends within
#           LEVEL_BAND of the Warden's ground;
#   exit    the bot's own climb steering (_fight_way_up, then _act) puts the ball on the ground
#           within SHELF_NEAR of the shelf's height inside EXIT_S.
#
# Evidence limit: one seed, one pilot, one stall point on the default table; it says the bot can
# leave this basin, not that a first-time player finds the way.

const SEED := 35221
const PILOT := "tarn"
const STALL := Vector3(-54.0, 2.0, 50.0)
const EXIT_S := 60.0
const SHELF_NEAR := 3.0
const SETTLE_TICKS := 30

var _t := T.new("bot_basin_exit_test")
var _game
var _driver
var _ticks := 0
var _seconds := 0.0
var _target := Vector3.ZERO
var _shelf_y := 0.0
var _out_at := -1.0
var _done := false


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--child"):
		var results := ChildRuns.run([{"script": "res://tests/bot_basin_exit_test.gd", "args": ["--child"]}], 120.0)
		var result: Dictionary = results[0]
		print(result["log"])
		_t.check("child ran clean", result["code"] == 0 and not result["timed_out"] and ChildRuns.summary(result)["errors"].is_empty(),
			"exit %s, timed out %s" % [result["code"], result["timed_out"]])
		quit(_t.verdict())
		return
	SimClock.ticks = true
	seed(SEED)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "random", SEED)
		_driver.class_index = BotDriver.class_index_for(SEED, PILOT)
		_driver.start()
		return false
	if _ticks == 0 and _game.flow.state_name() != "stage":
		_driver.tick(delta)
		return false
	_ticks += 1
	if _ticks < SETTLE_TICKS:
		return false
	if _ticks == SETTLE_TICKS:
		_game.ctx.calm = true
		_game.run.set_max_hp(99999.0)
		var warden: Node3D = _game.flow.warden
		_t.check("stage 1 has its Warden", is_instance_valid(warden), str(warden))
		if not is_instance_valid(warden):
			return _finish()
		_target = warden.global_position
		_shelf_y = _game.ctx.terrain.height(_target.x, _target.z)
		var start: Vector3 = _driver._ground_point(STALL.x, STALL.z)
		_t.check("the stall point lies below the shelf", _shelf_y - start.y > BotDriver.LEVEL_BAND,
			"ground %.1f, shelf %.1f" % [start.y, _shelf_y])
		var route: Array[Vector3] = _driver._climb_route_any(start, _target)
		var end_y: float = _game.ctx.terrain.height(route.back().x, route.back().z) if not route.is_empty() else -INF
		print("basin route from %s to %s: %d points, ends at ground %.1f (shelf %.1f), strict plan %d points: %s" % [
			start, _target, route.size(), end_y, _shelf_y, _driver._climb_route(start, _target).size(), route])
		_t.check("a climb route to the Warden exists", not route.is_empty(), "%d points" % route.size())
		_t.check("the route ends at the shelf's level", _shelf_y - end_y <= BotDriver.LEVEL_BAND, "ground %.1f, shelf %.1f" % [end_y, _shelf_y])
		_driver._fight_climb.clear()
		_driver._fight_climb_clock = 0.0
		_game.player.reset_to(start)
		return false
	_seconds += delta
	var ball: Vector3 = _game.player.ball_position()
	if _out_at < 0.0 and _game.player.state.grounded and _shelf_y - ball.y <= SHELF_NEAR:
		_out_at = _seconds
	# The tick count and boost clock tick() runs before it acts, so the boost comes back as in a run.
	_driver.ticks += 1
	_driver._boost_clock -= delta
	var steer: Vector3 = _driver._fight_way_up(ball, _target, delta) if _driver._climbing(ball, _target) else _target
	_driver._act(steer, null, delta, null, false)
	if OS.get_cmdline_user_args().has("--trace") and _driver.ticks % 90 == 0:
		print("  t=%.1f ball=(%.1f, %.1f, %.1f) speed=%.1f grounded=%s steer=(%.1f, %.1f, %.1f)" % [_seconds, ball.x, ball.y, ball.z,
			_game.player.planar_velocity().length(), _game.player.state.grounded, steer.x, steer.y, steer.z])
	if _out_at >= 0.0 or _seconds >= EXIT_S:
		print("basin exit from %s: on the shelf at %.1f s, ball %s" % [STALL, _out_at, ball])
		_t.check("the bot climbs out of the basin onto the shelf inside %.0f s" % EXIT_S, _out_at >= 0.0,
			"ball %s after %.1f s" % [ball, _seconds])
		return _finish()
	return false


func _finish() -> bool:
	_done = true
	_game.free()
	quit(_t.verdict())
	return true
