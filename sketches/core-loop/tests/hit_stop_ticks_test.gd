extends SceneTree

const Game := preload("res://src/game.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

# A headless test's hit stop (Game.test_mode, no SimClock.ticks) slows floor(seconds * physics rate)
# physics ticks and hands back the time scale that was in force before it. The count is exact
# while a frame carries one physics tick (Godot reads the scale once per frame), so the test caps
# a frame at one tick. A played game keeps the wall-time timer; this covers the tick path only.
# FEEL_PLANT=zero_stop (a test-only switch; the game is untouched) asks every counted stop for zero
# seconds, a hit-stop of zero ticks, so [slowed ticks] must fail: scripts/gate/core-feel-receipt.mjs
# requires that.

var _game
var _failures := 0
var _stage := 0
var _wait := 0
var _ticks := 0
var _unended := 0
var _timer_kept := false
var _timer_scale := 0.0
var _slow := 0
var _runs: Array = []
var _plant := OS.get_environment("FEEL_PLANT") == "zero_stop"


func _initialize() -> void:
	# One physics tick a frame, as on an idle box: a loaded box otherwise packs several ticks into one
	# frame and the frame-paced checks drift (w33 gate, red only under load). The game just runs slower.
	Engine.max_physics_steps_per_frame = 1
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


# Each tick's delta says whether it ran slowed: a stop leaves the step at HIT_STOP_SCALE of normal.
func _physics_process(delta: float) -> bool:
	_ticks += 1
	if _stage >= 2 and _stage <= 4:
		if absf(delta - Game.HIT_STOP_SCALE / Engine.physics_ticks_per_second) < 1e-6:
			_slow += 1
	return false


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	match _stage:
		0:
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_stage = 1
		1:
			_wait += 1
			if _wait > 10 and _game.flow.in_play():
				_begin(1.0, 0.06)
			elif _ticks > 900:
				print("[play] the game never reached play -> FAIL")
				quit(1)
				return true
		2:
			if _ended():
				_finish_run(0.06)
				_begin(2.0, 0.03)
		3:
			if _ended():
				_finish_run(0.03)
				_begin(1.0, 0.5)
		4:
			if _ended():
				_finish_run(0.5)
				_stage = 5
		5:
			# A run on the sim clock (SimClock.ticks) keeps the wall timer: no tick counter starts.
			SimClock.ticks = true
			Engine.time_scale = 1.5
			_ticks = 0
			_game.hit_stop(0.06)
			_timer_kept = _game._hit_stopped and _game._stop_ticks_left <= 0
			_stage = 6
		6:
			if _ended():
				_timer_scale = Engine.time_scale
				SimClock.ticks = false
				_stage = 7
		7:
			Engine.time_scale = 1.0
			var expect := [5, 2, 5]
			var scales := [1.0, 2.0, 1.0]
			var counts_ok := true
			var scales_ok := true
			for i in 3:
				counts_ok = counts_ok and _runs[i][0] == expect[i]
				scales_ok = scales_ok and _runs[i][1] == scales[i]
			_check("slowed ticks", counts_ok,
				"0.06 s, 0.03 s and 0.5 s (capped at %.2f) slow %s ticks at %d ticks/s (want %s)" % [Game.HIT_STOP_MAX, [_runs[0][0], _runs[1][0], _runs[2][0]], Engine.physics_ticks_per_second, expect])
			_check("sim clock keeps the timer", _timer_kept and _timer_scale == 1.5,
				"with SimClock.ticks a stop starts with no tick counter (%s) and ends with the prior scale 1.5 back, got %s" % [_timer_kept, _timer_scale])
			_check("stops end", _unended == 0, "%d stops still running 600 ticks after they began" % _unended)
			_check("scale restored", scales_ok,
				"scales before %s, after %s" % [scales, [_runs[0][1], _runs[1][1], _runs[2][1]]])
			if _plant:
				print("PLANT %s" % JSON.stringify({"switch": "FEEL_PLANT=zero_stop", "slowed": [_runs[0][0], _runs[1][0], _runs[2][0]]}))
			print("hit_stop_ticks_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			_game.free()
			quit(0 if _failures == 0 else 1)
			return true
	return false


# A stop is over once the game says so; a few ticks later the scale is back and counted. A stop
# that never ends (600 ticks) is a failure, not a hang.
func _ended() -> bool:
	if _ticks > 600 and _game._hit_stopped:
		_unended += 1
		return true
	return _ticks > 3 and not _game._hit_stopped


func _begin(scale: float, seconds: float) -> void:
	Engine.time_scale = scale
	_slow = 0
	_ticks = 0
	_stage += 1
	_game.hit_stop(0.0 if _plant else seconds)


func _finish_run(_seconds: float) -> void:
	_runs.append([_slow, Engine.time_scale])


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
