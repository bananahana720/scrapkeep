extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# SQ9, the speed bank (comps/roboquest/movement-and-feel.md, "A speed bank with a spend
# window"). Each pilot's real rigid ball rolls at cruise off a 2 m drop onto open floor with
# the stick held forward. The landing banks speed: the roll starts above cruise and decays to
# it. Four runs per pilot:
#   trace   log planar speed per tick from the landing to past the decay
#   window  Space inside the last 25% of the decay (u = 0.875): keeps at least 90% of the burst
#   early   Space at u = 0.3, outside the window: does not keep 90%
#   late    Space 0.3 s after the decay ended: does not keep 90%
# Checks per pilot: the burst-to-cruise ratio inside 1.2 to 1.3, then the three jumps. One
# more check reads the six traces on each pilot's own decay clock: every pair must differ
# in shape by at least SHAPE_GAP, so no trace is another's rescaled. 6 x 4 + 1 = 25 checks.

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const RUNS := ["trace", "window", "early", "late"]
const EXPECTED_CHECKS := 25
const RATIO_BAND := [1.2, 1.3]
const KEEP := 0.9
const WINDOW_U := 0.875
const EARLY_U := 0.3
const LATE_S := 0.3
# Ticks after the Space press the kept speed is read: the ball is in the air by then.
const READ_TICKS := 15
const SHAPE_SAMPLES := [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
const SHAPE_GAP := 0.08
const START := Vector3(0.0, 3.0, 150.0)
# Used only when the tuning has no bank row (the red run before SQ9): a 1 s decay.
const FALLBACK_DECAY := 1.0

var _world: Node3D
var _events
var _player
var _tuning
var _source := Intent.Scripted.new()
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
	_events = GameEvents.new()
	_world.add_child(_events)
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


func _start(pilot: String, run: String) -> void:
	_player.fit_class(ClassDef.by_id(pilot))
	var cruise: float = _tuning.f("cruise")
	_player.reset_to(START, Vector3(0.0, 0.0, -cruise))
	_source.hold = {"move": Vector2(0.0, 1.0)}
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
		"landed_t": -1.0, "t": 0.0, "trace": [], "pressed_tick": -1, "ticks": 0, "done": false}


func _physics_process(delta: float) -> bool:
	if _run.is_empty() or _run["done"]:
		if not _run.is_empty():
			_finish()
		if _queue.is_empty():
			_shape_check()
			var counted := _checks == EXPECTED_CHECKS
			if not counted:
				print("[count] %d checks ran, expected %d -> FAIL" % [_checks, EXPECTED_CHECKS])
			print("speed_bank_test: %s" % ("PASS" if _failures == 0 and counted else "FAIL (%d)" % (_failures + (0 if counted else 1))))
			quit(0 if _failures == 0 and counted else 1)
			return true
		var next: Array = _queue.pop_front()
		_start(next[0], next[1])
		return false
	_step(delta)
	return false


func _step(delta: float) -> void:
	_run["ticks"] += 1
	if _run["ticks"] > 90 * 8:
		_run["done"] = true
		return
	var grounded: bool = _player.state.grounded
	if _run["landed_t"] < 0.0:
		if not grounded:
			_run["airborne"] = true
		elif _run["airborne"]:
			_run["landed_t"] = 0.0
		return
	_run["t"] += delta
	var t: float = _run["t"]
	_run["trace"].append([t, _planar()])
	if _run["run"] == "trace":
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
	if run == "trace":
		var peak := 0.0
		for sample in trace:
			if sample[0] <= 0.3:
				peak = maxf(peak, sample[1])
		_traces[pilot] = trace
		_peaks[pilot] = peak
		var ratio := peak / cruise
		_check("%s ratio" % pilot, ratio >= RATIO_BAND[0] and ratio <= RATIO_BAND[1],
			"landing at %.1f m/s cruise banks a burst of %.2f m/s, %.3f x cruise (band %.1f to %.1f); decay %.2f s"
				% [cruise, peak, ratio, RATIO_BAND[0], RATIO_BAND[1], _run["decay"]])
		_run = {}
		return
	# Never below the band's floor, so a ball with no bank cannot keep "90%" of cruise.
	var burst: float = maxf(_peaks.get(pilot, 0.0), cruise * RATIO_BAND[0])
	var kept: float = _run.get("kept", 0.0)
	var share := kept / burst
	var landed: bool = _run["pressed_tick"] >= 0
	var detail := "Space at %.2f s of a %.2f s decay (%s), %.2f m/s at the press, %.2f m/s %d ticks later = %.1f%% of the %.2f m/s burst" \
		% [_run["press_at"], _run["decay"], run, _run.get("speed_at_press", 0.0), kept, READ_TICKS, share * 100.0, burst]
	if run == "window":
		_check("%s window keeps" % pilot, landed and share >= KEEP, detail + " (want at least %d%%)" % int(KEEP * 100.0))
	else:
		_check("%s %s spends" % [pilot, run], landed and share < KEEP, detail + " (want under %d%%)" % int(KEEP * 100.0))
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
