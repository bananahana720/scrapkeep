extends SceneTree

const Game := preload("res://src/game.gd")

# Juice through the real game: the camera hooks fire for dash, slam and launch; a
# landing squashes the ball; with no plating data from combat yet, hit-stop falls back
# to big contact hits, is 30-50 ms, never above the spine's 60 ms cap, and never
# stacks or chains, measured on the real Engine.time_scale the spine drives. The
# plated policy has its own test, presentation_hitstop_test.

var _game
var _juice
var _failures := 0
var _step := 0
var _wait_until := 0
var _enemy: Node3D
var _stop_started := -1
var _stop_seen_ms := 0.0
var _sent_before := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	var now := Time.get_ticks_msec()
	# Measure how long the spine really holds the freeze, in real time.
	if Engine.time_scale < 1.0:
		if _stop_started < 0:
			_stop_started = Time.get_ticks_usec()
	elif _stop_started >= 0:
		_stop_seen_ms = maxf(_stop_seen_ms, (Time.get_ticks_usec() - _stop_started) / 1000.0)
		_stop_started = -1
	if now < _wait_until:
		return false
	match _step:
		0:
			_juice = _game.presentation.juice
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_enemy = Node3D.new()
			_game.add_child(_enemy)
			_enemy.global_position = _game.player.ball_position() + Vector3(0.0, 0.0, -4.0)
			_next(100)
		1:
			var before: float = _game.camera._punch
			_game.events.dashed.emit(Vector3.FORWARD)
			_check("dash punch", _logged("punch_fov", "dashed") and _game.camera._punch > before, "dashed -> punch_fov, camera fov punch %.1f deg" % _game.camera._punch)
			_game.events.landed.emit(20.0)
			_check("landing squash", _juice.squash_amount() > 0.2 and not _game.player.builtin_squash, "a 20 m/s landing squashes the ball by %.2f" % _juice.squash_amount())
			_game.events.slammed.emit(_game.player.ball_position(), 1.2, 1.0)
			_check("slam kick", _logged("kick", "slammed") and _logged("punch_fov", "slammed"), "slammed -> camera kick and a zoom-in punch")
			_check("slam no stop", _sent_for("slammed").is_empty(), "a slam on open ground asks for no hit-stop; only a break-through does")
			_game.events.launched.emit(Vector3(0.0, 20.0, 20.0))
			_check("launch punch", _logged("punch_fov", "launched") and _logged("kick", "launched"), "launched -> fov punch and kick")
			_next(400)
		2:
			_sent_before = _sent().size()
			for i in 5:
				_game.events.enemy_struck.emit(_enemy, "ram", 30.0)
			_game.events.enemy_struck.emit(_enemy, "ram", 10.0)
			_game.events.enemy_struck.emit(_enemy, "arc", 99.0)
			_game.events.enemy_struck.emit(_enemy, "stomp", 5.0)
			var sent := _sent().size() - _sent_before
			_check("no stack", sent == 1, "five big rams in one frame send %d stop; the rest are gated" % sent)
			_check("small hits free", _juice.hit_stop_log.size() == 5, "a slow ram, a weapon arc and a soft stomp ask for no stop (%d requests logged)" % _juice.hit_stop_log.size())
			_next(100)
		3:
			# Inside the spacing window: gated. After it: allowed again.
			_game.events.enemy_struck.emit(_enemy, "stomp", 20.0)
			_check("no chain", _sent().size() - _sent_before == 1, "a big stomp 100 ms later is gated so stops never chain")
			_next(450)
		4:
			_game.events.enemy_struck.emit(_enemy, "stomp", 20.0)
			_check("spaced stop", _sent().size() - _sent_before == 2, "the same stomp 550 ms later gets its stop")
			_next(200)
		5:
			var within := true
			var values: Array = []
			for entry in _sent():
				within = within and entry[1] >= 0.03 and entry[1] <= 0.05 and entry[1] <= Game.HIT_STOP_MAX
				values.append(entry[1])
			_check("stop length", within, "every sent stop is 30-50 ms, under the spine's %.0f ms cap: %s" % [Game.HIT_STOP_MAX * 1000.0, values])
			_check("real freeze", _stop_seen_ms > 0.0 and _stop_seen_ms < 60.0 + 40.0 and Engine.time_scale == 1.0,
				"longest observed Engine.time_scale dip %.0f ms (cap 60 ms plus frame granularity), time scale back to 1" % _stop_seen_ms)
			print("presentation_juice_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			_game.free()
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _next(wait_ms: int) -> void:
	_step += 1
	_wait_until = Time.get_ticks_msec() + wait_ms


func _logged(hook: String, fact: String) -> bool:
	for entry in _juice.hook_log:
		if entry[0] == hook and entry[1] == fact:
			return true
	return false


func _sent() -> Array:
	return _juice.hit_stop_log.filter(func(entry: Array): return entry[1] > 0.0)


func _sent_for(fact: String) -> Array:
	return _sent().filter(func(entry: Array): return entry[2] == fact).map(func(entry: Array): return entry[1])


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
