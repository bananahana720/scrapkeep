# smoke: timeout=360s fixed-fps=90 (six pilots, nineteen input fixtures each)
extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const SpeedBank := preload("res://src/movement/speed_bank.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# SQ9: real rigid-ball inputs, one fixed start per fixture and pilot. Ctrl is the
# shared brake/slide on this ball. The slide rolls off a 2 m ledge; the kicker is
# an unpowered ramp, and the ride uses the world's velocity handoff.
const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const RUNS := ["roll", "roll_reverse", "roll_side", "slide", "jump", "air_jump", "window", "early", "late", "drop", "kicker", "ride", "pad", "grapple", "knock", "brake_release_drop", "slide_stop_drop", "gentle_drop", "gentle_jump"]
const EXPECTED_CHECKS := 133
const RATIO_BAND := [1.2, 1.3]
const KEEP := 0.9
const WINDOW_U := 0.875
const EARLY_U := 0.3
const LATE_S := 0.3
# Ticks after the Space press the kept speed is read: the ball is in the air by then.
const READ_TICKS := 15
const SHAPE_SAMPLES := [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
const SHAPE_GAP := 0.08
const START := Vector3(0.0, 1.03, 158.0)
const RideRail := preload("res://src/world/ride_rail.gd")
# Used only when the tuning has no bank row (the red run before SQ9): a 1 s decay.
const FALLBACK_DECAY := 1.0

var _world: Node3D
var _ledge: StaticBody3D
var _kicker: StaticBody3D
var _events
var _player
var _tuning
var _source := Intent.Scripted.new()
var _landing_count := 0
var _landing_speed := 0.0
var _checks := 0
var _failures := 0
var _queue := []
var _run := {}
var _traces := {}
var _peaks := {}


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(0.0, -1.0, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600.0, 2.0, 600.0)
	shape.shape = box
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	_ledge = StaticBody3D.new()
	var ledge_shape := CollisionShape3D.new()
	var ledge_box := BoxShape3D.new()
	ledge_box.size = Vector3(16.0, 2.0, 28.0)
	ledge_shape.shape = ledge_box
	_ledge.position = Vector3(0.0, 1.0, 154.0)
	_ledge.add_child(ledge_shape)
	_world.add_child(_ledge)
	_kicker = StaticBody3D.new()
	var ramp_shape := CollisionShape3D.new()
	var ramp := ConvexPolygonShape3D.new()
	ramp.points = PackedVector3Array([
		Vector3(-8, -1, 146), Vector3(8, -1, 146),
		Vector3(-8, -1, 134), Vector3(8, -1, 134),
		Vector3(-8, 0, 146), Vector3(8, 0, 146),
		Vector3(-8, 2, 134), Vector3(8, 2, 134)])
	ramp_shape.shape = ramp
	_kicker.add_child(ramp_shape)
	_world.add_child(_kicker)
	_events = GameEvents.new()
	_world.add_child(_events)
	_events.landed.connect(func(_impact: float):
		_landing_count += 1
		_landing_speed = _planar())
	_player = PlayerBall.new()
	_world.add_child(_player)
	_tuning = Tuning.new()
	_player.setup(_tuning, _events, START)
	_player.source = _source
	for pilot in PILOTS:
		for run in RUNS:
			_queue.append([pilot, run])


func _row(pilot: String) -> Dictionary:
	var rows = Tuning.new().get_script().get_script_constant_map().get("BANK_ROWS", {})
	return rows.get(pilot, {}) if rows is Dictionary else {}


func _decay(pilot: String) -> float:
	return float(_row(pilot).get("decay_s", FALLBACK_DECAY))


func _check(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _planar() -> float:
	return _player.planar_velocity().length()


func _probe_grounded() -> bool:
	for i in _player._rigid._probe.get_collision_count():
		if _player._rigid._probe.get_collision_normal(i).y > Tuning.MAX_SLOPE_DOT:
			return true
	return false


func _start(pilot: String, run: String) -> void:
	_player.fit_class(ClassDef.by_id(pilot))
	# Short fixture hops return through the ground probe below the impact signal's
	# 4 m/s threshold. Bank rows and thresholds retain their production values.
	_tuning.set_value("jump_speed", 4.0 if run.begins_with("gentle_") else 13.0)
	var cruise: float = _tuning.f("cruise")
	var long_ledge := run in ["slide_stop_drop", "gentle_drop", "gentle_jump"]
	_ledge.collision_layer = 1 if long_ledge or run in ["slide", "brake_release_drop"] else 0
	var ledge_box: BoxShape3D = _ledge.get_child(0).shape
	ledge_box.size.z = 56.0 if long_ledge else 28.0
	_ledge.position.z = 168.0 if long_ledge else 154.0
	_kicker.collision_layer = 1 if run == "kicker" else 0
	var start := START + Vector3.UP * (2.0 if long_ledge or run in ["slide", "drop", "air_jump", "brake_release_drop"] else 0.0)
	if run == "slide":
		start.z = 142.8
	elif long_ledge:
		start.z = 188.0
	var velocity := Vector3.ZERO
	if run == "roll_reverse":
		velocity = Vector3(0.0, 0.0, cruise * 0.19)
	elif run == "roll_side":
		velocity = Vector3(cruise * 0.19, 0.0, 0.0)
	elif run != "roll":
		var entry_ratio := 1.2 if run in ["slide", "kicker"] else 1.0
		if run == "gentle_drop":
			entry_ratio = 0.3
		velocity = Vector3(0.0, 0.0, -cruise * entry_ratio)
	_player.reset_to(start, velocity)
	_source.hold = {} if run.begins_with("roll") else {"move": Vector2(0.0, 1.0)}
	_source.press = {}
	var decay := _decay(pilot)
	var press_at := -1.0
	match run:
		"window":
			press_at = WINDOW_U * decay
		"early":
			press_at = EARLY_U * decay
		"late":
			press_at = decay + LATE_S
	_run = {"pilot": pilot, "run": run, "decay": decay, "press_at": press_at, "airborne": false,
		"landed_t": -1.0, "t": 0.0, "trace": [], "pressed_tick": -1, "ticks": 0, "done": false,
		"prepared": run in ["drop", "air_jump"], "ground_ticks": 0, "slide_ticks": 0, "burst_seen": false,
		"action_started": run == "drop" or run == "kicker", "action_grounded": false, "landings_before": _landing_count}


func _physics_process(delta: float) -> bool:
	if _run.is_empty() or _run["done"]:
		if not _run.is_empty():
			_finish()
		if _queue.is_empty():
			_shape_check()
			var counted := _checks == EXPECTED_CHECKS
			if not counted:
				print("[count] %d checks ran, expected %d -> FAIL" % [_checks, EXPECTED_CHECKS])
			print("speed_bank_test: %s, %d checks" % [("PASS" if _failures == 0 and counted else "FAIL (%d)" % (_failures + (0 if counted else 1))), _checks])
			quit(0 if _failures == 0 and counted else 1)
			return true
		var next: Array = _queue.pop_front()
		_start(next[0], next[1])
		return false
	_step(delta)
	return false


func _step(delta: float) -> void:
	_run["ticks"] += 1
	if _run["ticks"] > 90 * (16 if _run["run"].ends_with("_drop") else 8):
		_run["done"] = true
		return
	var grounded := _probe_grounded()
	var run: String = _run["run"]
	if run == "air_jump" and not _run["action_started"] and not grounded:
		_source.press = {"jump_pressed": true}
		_run["action_started"] = true
	if not _run["prepared"]:
		if grounded:
			_run["ground_ticks"] += 1
		if _run["ground_ticks"] < 12:
			return
		_run["prepared"] = true
		_run["landings_before"] = _landing_count
		_run["action_grounded"] = grounded
		match run:
			"roll", "roll_reverse", "roll_side":
				_source.hold = {"move": Vector2(0.0, 1.0)}
				_run["landed_t"] = 0.0
				_run["action_started"] = true
			"slide", "brake_release_drop", "slide_stop_drop":
				_source.hold["brake_held"] = true
				if run == "slide_stop_drop":
					_source.hold["move"] = Vector2(0.0, -1.0)
				_run["action_started"] = true
			"jump", "window", "early", "late", "ride", "pad", "grapple", "knock", "gentle_drop", "gentle_jump":
				_source.press = {"jump_pressed": true}
				_run["action_started"] = true
		return
	if run == "slide" and not grounded and _source.hold.get("brake_held", false):
		_run["slide_left_held"] = true
		_source.hold.erase("brake_held")
	if run == "brake_release_drop" and _source.hold.get("brake_held", false):
		_run["slide_ticks"] += 1
		if _run["slide_ticks"] >= 3:
			_run["released_grounded"] = grounded
			_source.hold.erase("brake_held")
	if run == "slide_stop_drop" and not _run.has("resumed"):
		if grounded and _planar() <= Tuning.BANK_REST * _tuning.f("cruise"):
			_run["stop_ticks"] = _run.get("stop_ticks", 0) + 1
			if _run["stop_ticks"] >= 2:
				_run["stopped_grounded"] = true
				_check("%s slide stop consumes" % _run["pilot"],
					_source.hold.get("brake_held", false) and _player.speed_bank_move() == SpeedBank.BankMove.NONE and _player.speed_bank.is_empty(),
					"move held, brake held, grounded at %.2f m/s; eligibility=%d, bank=%s" % [_planar(), _player.speed_bank_move(), _player.speed_bank])
				_run["resumed"] = true
				_source.hold["move"] = Vector2(0.0, 1.0)
				_source.hold.erase("brake_held")
		return
	if run.begins_with("gentle_") and not _run.has("gentle_landed"):
		if not grounded:
			_run["airborne"] = true
		elif _run["airborne"]:
			# Sample one tick after the probe return so PlayerBall has consumed it.
			_run["gentle_ground_ticks"] = _run.get("gentle_ground_ticks", 0) + 1
			if _run["gentle_ground_ticks"] < 2:
				return
			_run["gentle_landed"] = true
			var gentle: bool = _landing_count == _run["landings_before"]
			if run == "gentle_drop":
				_check("%s gentle landing consumes" % _run["pilot"], gentle and _planar() < Tuning.BANK_ARM * _tuning.f("cruise") and _player.speed_bank_move() == SpeedBank.BankMove.NONE and _player.speed_bank.is_empty(),
					"first probe landing %.2f m/s, impact events=%d, eligibility=%d, bank=%s" % [_planar(), _landing_count - _run["landings_before"], _player.speed_bank_move(), _player.speed_bank])
				_run["gentle_no_impact"] = gentle
				_run["airborne"] = false
			else:
				_run["gentle_no_impact"] = gentle
				_run["landed_t"] = 0.0
		return
	if run in ["ride", "pad", "grapple", "knock"] and not _run.has("ride_exit") and _player.ball_position().y >= 3.0:
		# Interrupt a chosen jump so the external motion must cancel its landing eligibility.
		var at: Vector3 = _player.ball_position()
		var ride = RideRail.arc("cannon", at, at + Vector3(0, 0, -20), _tuning.f("cruise"),
			_tuning.f("cruise"), 0.5, _tuning.f("gravity"))
		ride.time = ride.flight
		match run:
			"ride":
				_player.set_velocity_now(ride.release_velocity(), "ride_exit")
			"pad":
				_player.set_velocity_now(ride.release_velocity(), "launch_pad")
			"grapple":
				_player.grapple_to(at + Vector3.UP * 10.0)
				_player.release_grapple()
			"knock":
				_player.crowd_control("knockback", Vector3.UP * 80.0)
		_run["ride_exit"] = true
		_run["airborne"] = false
		return
	if not _player.speed_bank.is_empty():
		_run["burst_seen"] = true
	if _run["landed_t"] < 0.0:
		if not grounded:
			_run["airborne"] = true
		elif _run["airborne"] and (_landing_count > _run["landings_before"] or run in ["slide", "jump", "air_jump", "window", "early", "late"]):
			_run["landed_t"] = 0.0
		return
	_run["t"] += delta
	var t: float = _run["t"]
	_run["trace"].append([t, _planar()])
	if run in ["roll", "roll_reverse", "roll_side", "slide", "jump", "air_jump", "drop", "kicker", "ride", "pad", "grapple", "knock", "brake_release_drop", "slide_stop_drop", "gentle_drop", "gentle_jump"]:
		if t >= _run["decay"] + 0.6:
			_run["done"] = true
		return
	if _run["pressed_tick"] < 0 and t >= _run["press_at"]:
		_source.press = {"jump_pressed": true}
		_run["pressed_tick"] = _run["ticks"]
		_run["speed_at_press"] = _planar()
	elif _run["pressed_tick"] >= 0 and _run["ticks"] - _run["pressed_tick"] >= READ_TICKS:
		_run["kept"] = _planar()
		_run["done"] = true


func _finish() -> void:
	var pilot: String = _run["pilot"]
	var cruise: float = _tuning.f("cruise")
	var run: String = _run["run"]
	var trace: Array = _run["trace"]
	if run in ["roll", "roll_reverse", "roll_side", "slide", "jump", "air_jump", "drop", "kicker", "ride", "pad", "grapple", "knock", "brake_release_drop", "slide_stop_drop", "gentle_drop", "gentle_jump"]:
		var peak := 0.0
		for sample in trace:
			if sample[0] <= 0.3:
				peak = maxf(peak, sample[1])
		if run == "roll":
			_traces[pilot] = trace
			_peaks[pilot] = peak
		var ratio := peak / cruise
		var completed: bool = _run["landed_t"] >= 0.0 and _run["action_started"] and not trace.is_empty()
		if run == "slide":
			_check("%s slide leaves held" % pilot, _run.get("slide_left_held", false),
				"brake held through departure: %s" % _run.get("slide_left_held", false))
		if run in ["drop", "kicker", "ride", "pad", "grapple", "knock", "brake_release_drop", "slide_stop_drop", "gentle_drop"]:
			var history_ok: bool = _run.get("released_grounded", false) if run == "brake_release_drop" else true
			if run == "slide_stop_drop":
				history_ok = _run.get("stopped_grounded", false) and _run.get("resumed", false)
			elif run == "gentle_drop":
				history_ok = _run.get("gentle_landed", false) and _run.get("gentle_no_impact", false)
			completed = completed and history_ok
			_check("%s %s no burst" % [pilot, run], completed and _landing_speed >= Tuning.BANK_ARM * cruise and not _run["burst_seen"] and ratio < RATIO_BAND[0],
				"landed=%s at %.2f m/s, bank_seen=%s, peak %.2f m/s = %.3f x cruise (want <1.2 and no bank)"
					% [completed, _landing_speed, _run["burst_seen"], peak, ratio])
		else:
			if run == "gentle_jump":
				completed = completed and _run.get("gentle_no_impact", false)
			_check("%s %s ratio" % [pilot, run], completed and (_run["action_grounded"] or run == "air_jump") and trace[-1][1] <= cruise * 1.02 and ratio >= RATIO_BAND[0] and ratio <= RATIO_BAND[1],
				"scripted %s from ground=%s, burst %.2f m/s = %.3f x %.1f cruise (band %.1f to %.1f); decay %.2f s"
					% [run, _run["action_grounded"], peak, ratio, cruise, RATIO_BAND[0], RATIO_BAND[1], _run["decay"]])
		_run = {}
		return
	# Never below the band's floor, so a ball with no bank cannot keep "90%" of cruise.
	var burst: float = maxf(_peaks.get(pilot, 0.0), cruise * RATIO_BAND[0])
	var kept: float = _run.get("kept", 0.0)
	var share := kept / burst
	var pressed: bool = _run["pressed_tick"] >= 0
	var detail := "Space at %.2f s of a %.2f s decay (%s), %.2f m/s at the press, %.2f m/s %d ticks later = %.1f%% of the %.2f m/s burst" \
		% [_run["press_at"], _run["decay"], run, _run.get("speed_at_press", 0.0), kept, READ_TICKS, share * 100.0, burst]
	if run == "window":
		_check("%s window keeps" % pilot, pressed and share >= KEEP, detail + " (want at least %d%%)" % int(KEEP * 100.0))
	else:
		var spent := kept < float(_run.get("speed_at_press", 0.0)) - 0.25 if run == "early" else true
		_check("%s %s spends" % [pilot, run], pressed and share < KEEP and spent, detail + " (want under %d%%)" % int(KEEP * 100.0))
	_run = {}


# Each trace on its own clock: u = t / decay, g = (speed - cruise) / (burst - cruise). Two
# pilots whose g curves match differ only in scale.
func _curve(pilot: String) -> Array:
	var cruise: float = _tuning.f("cruise")
	var peak: float = _peaks.get(pilot, cruise)
	var span := peak - cruise
	var decay := _decay(pilot)
	var trace: Array = _traces.get(pilot, [])
	var out := []
	for u in SHAPE_SAMPLES:
		var want: float = u * decay
		var speed := cruise
		for sample in trace:
			if sample[0] >= want:
				speed = sample[1]
				break
		out.append((speed - cruise) / span if span > 0.5 else 0.0)
	return out


func _shape_check() -> void:
	var curves := {}
	for pilot in PILOTS:
		curves[pilot] = _curve(pilot)
		print("[shape] %s g(u) at u=0.1..0.9: %s" % [pilot, ", ".join(curves[pilot].map(func(g): return "%.2f" % g))])
	var worst := INF
	var worst_pair := ""
	for i in PILOTS.size():
		for j in range(i + 1, PILOTS.size()):
			var gap := 0.0
			for k in SHAPE_SAMPLES.size():
				gap = maxf(gap, absf(float(curves[PILOTS[i]][k]) - float(curves[PILOTS[j]][k])))
			if gap < worst:
				worst = gap
				worst_pair = "%s/%s" % [PILOTS[i], PILOTS[j]]
	var spans_ok := true
	for pilot in PILOTS:
		spans_ok = spans_ok and float(_peaks.get(pilot, 0.0)) - _tuning.f("cruise") > 0.5
	_check("shape", spans_ok and worst >= SHAPE_GAP,
		"15 pilot pairs on their own decay clocks: the closest pair %s differs by %.3f (want at least %.2f); every burst above cruise: %s"
			% [worst_pair, worst, SHAPE_GAP, spans_ok])
