# smoke: solo (verdict reads wall time: hit-stop spacing and per-second budget)
extends SceneTree

const Game := preload("res://src/game.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const Juice := preload("res://src/presentation/juice.gd")

# The v3 W11 hit-stop policy, through the real game. Every landed hit stops for its
# damage band (base + per damage point, clamped), a crit or weak point stops longer and
# a ram longer still, and nothing passes the spine's 60 ms cap. A deflected hit never
# stops. The hits of one frame coalesce into one stop; rapid fire is spaced at least
# STOP_GAP_MS apart and spends at most STOP_BUDGET_MS a second (a trimmed stop allowed).
# A real stop on the spine's Engine.time_scale leaves the rolling ball's velocity as it was.

var _game
var _juice
var _failures := 0
var _phase_t0 := 0
var _plan: Array = []
var _target: Node3D
var _marks := {}
var _done := false
var _velocity_before := Vector3.ZERO
var _stop_seen := false
var _velocity_after := Vector3.ZERO
var _speed_checked := false
var _dealt := 10.0
var _full := true


func _initialize() -> void:
	# One physics tick a frame so a slow frame cannot run all slowed ticks of the real hit-stop
	# before _process() sees Engine.time_scale < 1.0.
	Engine.max_physics_steps_per_frame = 1
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	var events = _game.events
	if _juice == null:
		_juice = _game.presentation.juice
		_juice.resolve_of = func(_enemy: Node3D, _kind: String, _force: float) -> Dictionary:
			return {"dealt": _dealt, "punch": _dealt, "full": _full, "part": "", "plating": 0.0}
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_target = Node3D.new()
		_game.add_child(_target)
		_phase_t0 = Time.get_ticks_msec()
		_check_bands()
		# Step types: "phase" waits ms from _phase_t0 and re-anchors _phase_t0 after running so
		# stalls in one section cannot collide into the next; "at" waits ms from the current
		# _phase_t0 without drifting across a timed burst; "clear" also waits until any prior
		# hit-stop has ended. Only one step runs per _process frame.
		_plan.append(["phase", 100, func():
			_juice.reset_stops()
			_dealt = 10.0
			events.enemy_struck.emit(_target, "sticky", 1.0)
			_juice.flush()
			_marks["low"] = _last_sent()])
		_plan.append(["phase", 200, func():
			_juice.reset_stops()
			_dealt = 80.0
			events.enemy_struck.emit(_target, "sticky", 1.0)
			_juice.flush()
			_marks["high"] = _last_sent()])
		_plan.append(["phase", 200, func():
			_juice.reset_stops()
			_dealt = 80.0
			events.enemy_struck.emit(_target, "ram", 1.0)
			_juice.flush()
			_marks["ram"] = _last_sent()])
		_plan.append(["phase", 200, func():
			_juice.reset_stops()
			_full = false
			var before: int = _sent().size()
			events.enemy_struck.emit(_target, "ram", 1.0)
			_juice.flush()
			_marks["deflect"] = _sent().size() - before
			_full = true])
		_plan.append(["phase", 200, func():
			_juice.reset_stops()
			_dealt = 20.0
			var before: int = _sent().size()
			for i in 5:
				events.enemy_struck.emit(_target, "sticky", 1.0)
			_juice.flush()
			_marks["frame"] = [_sent().size() - before, _last_sent()]])
		# Stacking: a crit ram, a dodge and a multi-kill beat 100 ms apart share one budget.
		_plan.append(["phase", 50, func():
			_juice.reset_stops()
			_marks["stack_from"] = _juice.hit_stop_log.size()
			_juice.request_hit_stop(0.06, "enemy_struck")])
		_plan.append(["at", 50, func(): _juice.request_hit_stop(0.045, "near_miss")])
		_plan.append(["at", 100, func(): _juice.request_hit_stop(0.03, "multi_kill")])
		_plan.append(["phase", 140, func(): _marks["stack"] = _juice.hit_stop_log.slice(_marks["stack_from"]).filter(func(e: Array): return e[1] > 0.0)])
		# Rapid fire: a hit every 33 ms for a second.
		_plan.append(["phase", 10, func():
			_juice.reset_stops()
			_marks["rapid_from"] = _juice.hit_stop_log.size()])
		for i in 30:
			_plan.append(["at", 10 + i * 33, func():
				_dealt = 30.0
				events.enemy_struck.emit(_target, "sticky", 1.0)
				_juice.flush()])
		_plan.append(["phase", 1050, func(): _marks["rapid"] = _juice.hit_stop_log.slice(_marks["rapid_from"]).filter(func(e: Array): return e[1] > 0.0)])
		# Guns never stop time: a burst of gun-kind hits sends nothing.
		_plan.append(["phase", 50, func():
			_juice.reset_stops()
			_dealt = 80.0
			var before: int = _sent().size()
			for gun in ["runner", "arc", "turret"]:
				for i in 4:
					events.enemy_struck.emit(_target, gun, 1.0)
					_juice.flush()
			_marks["guns"] = _sent().size() - before])
		# The harpoon's bite to a body is one stop of 40 ms; a world latch sends none.
		_plan.append(["phase", 50, func():
			_juice.reset_stops()
			var before: int = _sent().size()
			events.harpoon_bit.emit(_target, Vector3.ZERO)
			_marks["bite"] = _sent().slice(before)
			before = _sent().size()
			events.grapple_fired.emit(Vector3.ZERO)
			_marks["world_latch"] = _sent().size() - before])
		# A real stop on the rolling ball.
		_plan.append(["clear", 150, func():
			_juice.reset_stops()
			_game.player.reset_to(_game.ctx.terrain.spawn_point(1) + Vector3.UP * 10.0, Vector3(0.0, 0.0, -18.0))])
		_plan.append(["clear", 50, func():
			_velocity_before = _game.player._rigid.linear_velocity
			_juice.request_hit_stop(0.06, "test")])
		return false
	if _velocity_before != Vector3.ZERO and not _speed_checked:
		if Engine.time_scale < 1.0:
			_stop_seen = true
		elif _stop_seen:
			_velocity_after = _game.player._rigid.linear_velocity
			_speed_checked = true
	var now := Time.get_ticks_msec()
	if not _plan.is_empty():
		var item: Array = _plan[0]
		var ready: bool = now - _phase_t0 >= int(item[1])
		if ready and item[0] == "clear":
			ready = not _game._hit_stopped and Engine.time_scale == 1.0
		if ready:
			_plan.pop_front()
			(item[2] as Callable).call()
			if item[0] != "at":
				_phase_t0 = Time.get_ticks_msec()
	if not _plan.is_empty() or _done or not _speed_checked:
		return false
	_done = true
	_check("damage scales", _marks["high"] > _marks["low"] and _marks["ram"] > _marks["high"],
		"a 10-damage hit stops %.0f ms, an 80-damage hit %.0f ms, an 80-damage ram %.0f ms" % [_marks["low"] * 1000.0, _marks["high"] * 1000.0, _marks["ram"] * 1000.0])
	_check("deflects free", _marks["deflect"] == 0, "a deflected ram sends %d stops" % _marks["deflect"])
	var one: Array = _marks["frame"]
	var expected := (Juice.stop_ms_for(20.0) + 4.0 * EventJuice.STOP_PER_EXTRA_HIT_MS) / 1000.0
	_check("one frame, one stop", one[0] == 1 and absf(one[1] - expected) < 0.0005,
		"five hits in one frame send %d stop of %.0f ms (the band plus %.0f ms per extra hit)" % [one[0], one[1] * 1000.0, EventJuice.STOP_PER_EXTRA_HIT_MS])
	var stack: Array = _marks["stack"]
	var stacked := 0.0
	for entry in stack:
		stacked += entry[1] * 1000.0
	_check("stops never stack", stack.size() == 1 and stacked <= EventJuice.STOP_WINDOW_BUDGET_MS + 0.5,
		"a 60 ms stop, a dodge tick 50 ms later and a multi-kill beat 100 ms later send %d stop totalling %.0f ms (at most %.0f in any %d ms)"
			% [stack.size(), stacked, EventJuice.STOP_WINDOW_BUDGET_MS, EventJuice.STOP_WINDOW_MS])
	var rapid: Array = _marks["rapid"]
	var total := 0.0
	var gaps_ok := true
	var window_ok := true
	for i in rapid.size():
		total += rapid[i][1] * 1000.0
		if i > 0:
			gaps_ok = gaps_ok and rapid[i][3] - rapid[i - 1][3] - rapid[i - 1][1] * 1000.0 >= EventJuice.STOP_GAP_MS
		var span := 0.0
		for other in rapid:
			if other[3] <= rapid[i][3] and rapid[i][3] - other[3] < EventJuice.STOP_WINDOW_MS:
				span += other[1] * 1000.0
		window_ok = window_ok and span <= EventJuice.STOP_WINDOW_BUDGET_MS + 0.5
	_check("rapid fire capped", rapid.size() >= 2 and total <= EventJuice.STOP_BUDGET_MS + 0.5 and gaps_ok and window_ok,
		"30 hits in a second send %d stops totalling %.0f ms (budget %.0f), %d ms clear after each %s, %.0f ms per %d ms window %s"
			% [rapid.size(), total, EventJuice.STOP_BUDGET_MS, EventJuice.STOP_GAP_MS, gaps_ok, EventJuice.STOP_WINDOW_BUDGET_MS, EventJuice.STOP_WINDOW_MS, window_ok])
	var bite: Array = _marks["bite"]
	_check("bite stops 40 ms", bite.size() == 1 and absf(bite[0][1] - 0.04) < 0.0005 and bite[0][1] * 1000.0 <= EventJuice.STOP_WINDOW_BUDGET_MS and _marks["world_latch"] == 0,
		"a bite to a body sends %d stop of %.0f ms (window budget %.0f); a world latch sends %d" % [bite.size(), bite[0][1] * 1000.0 if not bite.is_empty() else 0.0, EventJuice.STOP_WINDOW_BUDGET_MS, _marks["world_latch"]])
	_check("guns never stop", _marks["guns"] == 0, "twelve laser, arc and turret hits send %d stops" % _marks["guns"])
	var flat_before := Vector2(_velocity_before.x, _velocity_before.z)
	var drift := (Vector2(_velocity_after.x, _velocity_after.z) - flat_before).length()
	_check("momentum kept", _stop_seen and drift < 0.05 and flat_before.length() > 10.0,
		"a real 60 ms stop: velocity %s before, %s after; planar drift %.4f m/s (gravity alone moves y)" % [_velocity_before, _velocity_after, drift])
	var lengths_ok := true
	for entry in _sent():
		lengths_ok = lengths_ok and entry[1] <= Game.HIT_STOP_MAX + 0.0001
	_check("under the cap", lengths_ok, "every sent stop is at or under the spine's %.0f ms" % (Game.HIT_STOP_MAX * 1000.0))
	print("presentation_hitstop_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


# The bands themselves: monotonic in damage, a crit and a ram above a plain hit, all capped.
func _check_bands() -> void:
	var bands: Array = []
	var ok := true
	var previous := 0.0
	for damage in [0.0, 5.0, 10.0, 20.0, 40.0, 60.0, 80.0, 150.0]:
		var ms := Juice.stop_ms_for(damage)
		ok = ok and ms >= previous and ms <= 60.0
		previous = ms
		bands.append("%d:%.0f" % [damage, ms])
	var crit := Juice.stop_ms_for(20.0, true)
	var heavy := Juice.stop_ms_for(20.0, false, true)
	var both := Juice.stop_ms_for(150.0, true, true)
	_check("bands", ok and crit > Juice.stop_ms_for(20.0) and heavy > Juice.stop_ms_for(20.0) and both <= 60.0,
		"damage:ms %s; at 20 damage a crit %.0f ms, a ram %.0f ms; a 150-damage crit ram %.0f ms" % [" ".join(bands), crit, heavy, both])


func _sent() -> Array:
	return _juice.hit_stop_log.filter(func(entry: Array): return entry[1] > 0.0)


func _last_sent() -> float:
	var sent := _sent()
	return sent.back()[1] if not sent.is_empty() else 0.0


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
