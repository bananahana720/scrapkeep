extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")

# The laps-mode lapper, end to end (v3 fun lab, Option C; DESIGN-NOTES L2 "Measured").
# One seeded lapper run on stage 1 under --loop=laps: it rings the bell, runs the
# course's three laps through the return lift, wakes the Warden and breaks it. This is
# the regression guard for the drop lips' aim (world.gd _aim_drop), which belongs to
# drop mode only: when it also fired in laps mode, a lap over the west chute had its
# arc turned onto the sleeping Warden, the lapper never reached the lift for lap 2 and
# the Warden never woke. loop_laps_test's lift and ring checks never cross a live lip
# at speed, so they missed it.
#
# The span runs at SCALE with the physics tick raised by the same factor, as in
# loop_camper_test, so every step is the game's own 1/90 s.
#
# Evidence limit: this proves the laps loop closes for one bot seed; it says nothing
# about how the laps feel.

const SEED := 1
const SCALE := 4.0
# Base and fixed trees break the Warden at about 66 s on this seed.
const STAGE_LIMIT := 150.0

var _game
var _driver
var _failures := 0
var _laps := 0
var _engaged := -1.0
var _broken := -1.0
var _done := false
var _base_tps := 90


func _initialize() -> void:
	_base_tps = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = int(_base_tps * SCALE)
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = SCALE
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	if _driver == null:
		_game.tuning.set_option("loop_mode", "laps")
		# Hit-stop sets time_scale back to 1; the span needs its scale held.
		_game.ctx._hit_stop = Callable()
		var bus = _game.events
		bus.lap_completed.connect(func(lap: int, _required: int, _seconds: float): _laps = maxi(_laps, lap))
		bus.warden_engaged.connect(func(_s: int): _engaged = _game.run.stage_time)
		bus.beacon_unsealed.connect(func(_s: int): _broken = _game.run.stage_time)
		_driver = BotDriver.new(_game, "lapper", SEED)
		_driver.start()
		return false
	var over: bool = _driver.tick(delta)
	if _broken >= 0.0 or over or _game.run.stage_time >= STAGE_LIMIT:
		return _finish()
	return false


func _finish() -> bool:
	_done = true
	var aims: int = int(_game.world.drop_aims)
	var where := "lapper seed %d as %s, bot outcome '%s', goal '%s', stage time %.1f s" \
		% [SEED, _driver.class_id(), _driver.outcome, _driver.get("_goal"), _game.run.stage_time]
	_report("course on stage 1", _game.world.course != null, "laps mode stands a lap course (%s)" % where)
	_report("three laps", _laps >= 3, "%d lap(s) completed (%s)" % [_laps, where])
	_report("Warden wakes", _engaged >= 0.0, "engaged at %.1f s" % _engaged)
	_report("Warden breaks", _broken >= 0.0 and _broken < STAGE_LIMIT, "broken at %.1f s (limit %.0f s)" % [_broken, STAGE_LIMIT])
	_report("no lip aim in laps", aims == 0, "%d drop aim(s) fired in laps mode" % aims)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = _base_tps
	print("loop_lapper_laps_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
