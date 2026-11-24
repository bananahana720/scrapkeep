extends SceneTree

const Game := preload("res://src/game.gd")
const Juice := preload("res://src/presentation/juice.gd")

# SR5 juice budget (W13-INTEGRATION-3). Stacked hits cannot shake the camera past
# Juice.SHAKE_CAP on any frame, and hit-stop belongs to the attacker's own strike: the
# ball's motion, a roll or a dodge asks for none, so the player's movement is never held
# by it. The comfort rows (Screen shake, Hit-stop) still scale both. The damage bands,
# spacing and budget are presentation_hitstop_test's; this file adds the gate and the cap.
# Comps note: ror2/characters-and-feel (hitstop on melee only, shake capped per frame).

# Facts a stop must never carry: the ball's own motion, a roll, a dodge past an attack.
const BALL_FACTS := ["near_miss", "rolling", "roll", "dashed", "landed", "launched"]
const STRESS_HITS := 30

var _game
var _juice
var _failures := 0
var _enemy: Node3D
var _frame := 0
var _setup := false
var _peak_after_emit := 0.0
var _peak_at_frame := 0.0
var _sink_calls: Array = []
var _cap := -1.0
var _stress_done := false
var _shake_events := 0


func _initialize() -> void:
	# One physics tick a frame so a loaded box does not pack ticks during settle or stress.
	Engine.max_physics_steps_per_frame = 1
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	var camera = _game.camera
	if not _setup:
		_setup = true
		_juice = _game.presentation.juice
		_juice.plating_of = Callable()
		_juice.resolve_of = func(_e, _k, force): return {"dealt": force * 2.0, "punch": force, "full": true, "part": "", "plating": 0.0}
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		# Place the ball gently on the deck instead of letting Flow.ENTRY_LIFT (14 m) land mid-stress
		# under load and push chase_camera's landing-impact shake (~0.886) past Juice.SHAKE_CAP.
		var spawn: Vector3 = _game.ctx.terrain.spawn_point(1)
		_game.player.reset_to(_game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05))
		_enemy = Node3D.new()
		_game.add_child(_enemy)
		_enemy.global_position = _game.player.ball_position() + Vector3(0.0, 0.0, -4.0)
		_juice.hit_stop_sink = func(seconds: float): _sink_calls.append(seconds)
		_cap = float((Juice as GDScript).get_script_constant_map().get("SHAKE_CAP", -1.0))
		_check("cap declared", _cap > 0.0 and _cap <= 1.2, "Juice.SHAKE_CAP is %.2f (a positive start value at or under the camera profile ceiling of 1.2)" % _cap)
		return false
	_frame += 1
	if _frame < 30:
		# Let the spawn settle, then start from a still camera.
		return false
	if _frame == 30:
		_game.player.state.impact = 0.0
		camera._shake = 0.0
		return false
	if not _stress_done:
		_peak_at_frame = maxf(_peak_at_frame, camera.shake_amplitude())
		var n := _frame - 30
		if n <= STRESS_HITS:
			_stress_step(n, camera)
			return false
		_stress_done = true
	_finish(camera)
	return true


# One frame of the 30-hit stress: a crit ram or a bomb hit, a blast every fifth frame, and
# every third frame a request far over the cap (a future row, a boss, a stack of rows).
func _stress_step(n: int, camera) -> void:
	_game.events.enemy_struck.emit(_enemy, "ram" if n % 2 == 0 else "sticky", 30.0)
	if n % 5 == 0:
		_game.events.sticky_detonated.emit(_enemy.global_position, true)
	_juice.flush()
	if n % 3 == 0 and _juice.has_method("request_shake"):
		_juice.request_shake(0.9, 0.3, "stress")
	elif n % 3 == 0:
		camera.shake(0.9, 0.3)
	_shake_events += 1
	_peak_after_emit = maxf(_peak_after_emit, camera.shake_amplitude())


func _finish(camera) -> void:
	var peak := maxf(_peak_after_emit, _peak_at_frame)
	_check("stress shakes", _peak_after_emit > 0.0 and _shake_events == STRESS_HITS,
		"%d frames of hits, peak shake after a frame's hits %.3f (a zero here means nothing was measured)" % [_shake_events, _peak_after_emit])
	_check("peak under the cap", peak <= _cap + 0.0001,
		"peak shake %.3f on any frame against the cap %.3f (a stack of requests at 0.9 included)" % [peak, _cap])
	# Positive control: the camera alone passes the cap, so the measure can see an overshoot.
	camera._shake = 0.0
	camera.shake(0.9, 0.3)
	_check("control sees overshoot", camera.shake_amplitude() > _cap + 0.01,
		"the camera taking 0.9 straight reads %.3f, over the cap %.3f" % [camera.shake_amplitude(), _cap])
	camera._shake = 0.0

	# Hit-stop belongs to the strike. A roll, the ball's motion and a dodge send none.
	_game.player._rigid.set_velocity_now(Vector3(0.0, 0.0, -18.0))
	var velocity_before: Vector3 = _game.player._rigid.linear_velocity
	var calls_before := _sink_calls.size()
	var freezes := 0
	var rolled := 0
	for fact in BALL_FACTS:
		_juice.reset_stops()
		var logged: int = _juice.hit_stop_log.size()
		_juice.request_hit_stop(0.04, fact)
		rolled += 1
		for entry in _juice.hit_stop_log.slice(logged):
			if entry[1] > 0.0:
				freezes += 1
	_juice.reset_stops()
	_game.events.near_miss.emit("threat_lane", _game.player.ball_position())
	_check("no stop on a roll", freezes == 0 and _sink_calls.size() == calls_before,
		"%d ball-motion facts (%s) at 18 m/s send %d stops; the sink saw %d calls" % [rolled, ", ".join(BALL_FACTS), freezes, _sink_calls.size() - calls_before])
	# The list of strike facts is closed: a reward card, a beacon and a fact nobody listed
	# send no stop either, and each is still logged at zero.
	var closed := {}
	for fact in ["reward_rare", "beacon_unsealed", "unlisted_ball_motion"]:
		_juice.reset_stops()
		var seen: int = _juice.hit_stop_log.size()
		var sink_seen := _sink_calls.size()
		_juice.request_hit_stop(0.04, fact)
		var rows: Array = _juice.hit_stop_log.slice(seen)
		closed[fact] = rows.size() == 1 and rows[0][1] == 0.0 and _sink_calls.size() == sink_seen
	_check("closed list", closed.values().all(func(v): return v),
		"reward_rare, beacon_unsealed and an unlisted fact each log one zero stop and the sink saw none: %s" % [closed])
	_juice.reset_stops()
	var rare_seen: int = _juice.hit_stop_log.size()
	_juice.request_hit_stop(0.04, "enemy_struck")
	_check("listed fact stops", _juice.hit_stop_log.slice(rare_seen).filter(func(e: Array): return e[1] > 0.0).size() == 1,
		"a listed strike fact sent straight to the budget sends one stop (the control for the closed list)")
	var velocity_after: Vector3 = _game.player._rigid.linear_velocity
	_check("movement not frozen", Vector2(velocity_after.x - velocity_before.x, velocity_after.z - velocity_before.z).length() < 0.5 and Engine.time_scale == 1.0,
		"planar velocity %s before, %s after; Engine.time_scale %.2f" % [velocity_before, velocity_after, Engine.time_scale])
	# Positive control: the attacker's own strike, rolling, still stops.
	_juice.reset_stops()
	var logged: int = _juice.hit_stop_log.size()
	_game.events.enemy_struck.emit(_enemy, "ram", 40.0)
	_juice.flush()
	var melee_sent: Array = _juice.hit_stop_log.slice(logged).filter(func(e: Array): return e[1] > 0.0)
	_check("strike still stops", melee_sent.size() == 1 and melee_sent[0][2] == "enemy_struck" and melee_sent[0][1] <= Juice.SPINE_CAP_MS / 1000.0 + 0.0001,
		"a ram at speed sends %d stop of %.0f ms under the spine's %.0f ms" % [melee_sent.size(), melee_sent[0][1] * 1000.0 if not melee_sent.is_empty() else 0.0, Juice.SPINE_CAP_MS])

	# The comfort rows scale both.
	var shake_full := _shake_for(camera, 1.0)
	var shake_half := _shake_for(camera, 0.5)
	var shake_none := _shake_for(camera, 0.0)
	_check("comfort scales shake", shake_full > 0.0 and absf(shake_half - shake_full * 0.5) < 0.001 and shake_none == 0.0,
		"a capped request reads %.3f at 1, %.3f at 0.5, %.3f at 0" % [shake_full, shake_half, shake_none])
	var stop_full := _stop_for(1.0)
	var stop_half := _stop_for(0.5)
	var stop_none := _stop_for(0.0)
	_check("comfort scales stop", stop_full > 0.0 and absf(stop_half - stop_full * 0.5) < 0.0005 and stop_none == 0.0,
		"a ram's stop is %.0f ms at 1, %.0f ms at 0.5, %.0f ms at 0" % [stop_full * 1000.0, stop_half * 1000.0, stop_none * 1000.0])
	_juice.set_comfort("shake", 1.0)
	_juice.set_comfort("hitstop", 1.0)
	print("juice_budget_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _shake_for(camera, level: float) -> float:
	_juice.set_comfort("shake", level)
	camera._shake = 0.0
	if _juice.has_method("request_shake"):
		_juice.request_shake(0.9, 0.3, "comfort")
	else:
		camera.shake(0.9, 0.3)
	var amplitude: float = camera.shake_amplitude()
	camera._shake = 0.0
	return amplitude


func _stop_for(level: float) -> float:
	_juice.set_comfort("hitstop", level)
	_juice.reset_stops()
	var logged: int = _juice.hit_stop_log.size()
	_game.events.enemy_struck.emit(_enemy, "ram", 40.0)
	_juice.flush()
	var sent: Array = _juice.hit_stop_log.slice(logged).filter(func(e: Array): return e[1] > 0.0)
	return float(sent[0][1]) if not sent.is_empty() else 0.0


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
