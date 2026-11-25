extends SceneTree

const Game := preload("res://src/game.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")

var _game
var _ticks := 0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _seconds := 12.0
var _start := 1.0
var _t := 0
var _started := false
var _peak := 0.0
var _peak_at := Vector3.ZERO
var _lock_state := ""
var _hist: Array[float] = []
var _snagged := false
var _win_min := INF
var _win_n := 0
var _prev_z := -INF


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() != 2:
			continue
		if kv[0] == "locks":
			StageLocks.active = kv[1] != "0"
			continue
		var xy := kv[1].split(",")
		match kv[0]:
			"from": _from = Vector2(float(xy[0]), float(xy[1]))
			"to": _to = Vector2(float(xy[0]), float(xy[1]))
			"seconds": _seconds = float(kv[1])
			"start": _start = float(kv[1])
	SimClock.ticks = true
	seed(1)
	node_added.connect(func(node: Node):
		if node is Game:
			node.table = "park")
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 2:
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if _ticks < 120:
		return false
	var cruise: float = _game.player.tuning.tier_cruise()
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.run.set_max_hp(99999.0)
		_game.events.activity_done.connect(func(id: String, at: Vector3): print("activity_done %s at (%.0f, %.0f) t %.2f" % [id, at.x, at.z, _t / 90.0]))
		_game.events.verb_failed.connect(func(verb: String, reason: String, at: Vector3): print("verb_failed %s %s t %.2f" % [verb, reason, _t / 90.0]))
		var dir := (_to - _from).normalized()
		_game.player.body().global_position = _game.ctx.terrain.drop_point(_from.x, _from.y, 1.0)
		_game.player.set_velocity_now(Vector3(dir.x, 0.0, dir.y) * cruise * _start, "probe")
		return false
	_t += 1
	var ball: Vector3 = _game.player.ball_position()
	var v: Vector3 = _game.player.state.velocity
	var flat := Vector2(v.x, v.z).length()
	if flat > _peak:
		_peak = flat
		_peak_at = ball
	var gate = _game.flow.gate
	if gate != null and "lock_state" in gate and gate.lock_state != _lock_state:
		_lock_state = gate.lock_state
		print("lock %s at z %.0f t %.2f centre z %.0f" % [_lock_state, ball.z, _t / 90.0, gate.lock_centre.z])
	_hist.append(flat)
	if _hist.size() > 19:
		_hist.pop_front()
	if _hist.size() == 19 and not _snagged and flat <= 0.5 * _hist[0] and _hist[0] > cruise:
		_snagged = true
		print("snag: %.1f -> %.1f m/s within 18 ticks at (%.0f, %.0f, %.0f) t %.2f" % [_hist[0], flat, ball.x, ball.y, ball.z, _t / 90.0])
	if ball.z >= 400.0 and ball.z <= 430.0:
		_win_min = minf(_win_min, flat)
		_win_n += 1
	if ball.z < _prev_z - 0.001 and _t > 18:
		print("moved toward -z at z %.1f t %.2f" % [ball.z, _t / 90.0])
	_prev_z = ball.z
	if _t % 45 == 0:
		print("t %.1f at (%.0f, %.0f, %.0f) flat %.1f m/s = %.2f x cruise" % [_t / 90.0, ball.x, ball.y, ball.z, flat, flat / cruise])
	if _t >= int(_seconds * 90.0):
		print("peak %.1f m/s = %.2f x cruise at (%.0f, %.0f, %.0f)" % [_peak, _peak / cruise, _peak_at.x, _peak_at.y, _peak_at.z])
		print("window z 400-430: min %.2f x cruise over %d ticks" % [_win_min / cruise if _win_n > 0 else -1.0, _win_n])
		quit(0)
	return false
