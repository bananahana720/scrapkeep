extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WardenDrop := preload("res://src/combat/warden_drop.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The drop mode's timing contract and its reads (LOOP-REDESIGN section 2, review findings
# 2 and 6), on the stage 1 Warden:
#   schedule   with the ball parked on the shelf, far outside the Warden's reach, the
#              core still opens on its own clock: at least MIN_WINDOWS windows in
#              SCHEDULE_SECONDS, each after a telegraph of 1.5 s or more, and the
#              published schedule (open_at, the dial over the Warden) agrees with what
#              then happens at least AGREE of the time, looked up to 6 s ahead
#   states     closed, telegraph, open and recover are each published
#   beam       the open beam stands only while the core is open and only shrinks
#   dial       the dial stands only while the core is shut
#   fast       a ball held on the west lip's run-up at FAST_SPEED is let go when the
#              landing marker turns amber; its first drop lands, with no stop or wait
#   forecast   the marker's colour is the schedule's answer at its own eta
#   dodge      a ball in the core ring through the telegraph that leaves within 0.3 s
#              of the clang is a near-miss; one that leaves early is a safe resolution;
#              the two are told apart on the bus and on screen, and neither wears the
#              core shape that means "open"
#
# Evidence limit: reads are checked as nodes and bus facts, not as pixels in moving
# footage with music; that remains Andrew's sitting.

const SCHEDULE_SECONDS := 20.0
const MIN_WINDOWS := 3
const AGREE := 0.97
const LOOKAHEAD := [0.5, 1.5, 3.0, 4.5, 6.0]
const FAST_SPEED := 32.0
const RUN_UP := 9.0

var _game
var _source := Intent.Scripted.new()
var _failures := 0
var _warden
var _drop
var _juice
var _phase := "boot"
var _clock := 0.0
var _windows_at := 0
var _states := {}
var _predictions: Array = []
var _agree := 0
var _checked := 0
var _beam_ok := true
var _beam_last := INF
var _dial_ok := true
var _landed := 0
var _release_eta := 0.0
var _dodges: Array = []
var _dodge_mode := ""
var _marker_seen := false
var _was_open := false
var _since_edge := 0.0
var _pulses_at := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.flow.force_warden = true
			_game.player.source = _source
			_game.ctx._hit_stop = Callable()
			_game.tuning.set_option("loop_mode", "drop")
			_game.tuning.set_option("gun_role", "hold")
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_game.events.warden_state_changed.connect(func(state: String, _at: Vector3): _states[state] = true)
			_game.events.warden_drop_landed.connect(func(_at: Vector3, _s: float, _l: int, _n: int): _landed += 1)
			_game.events.warden_pulse_dodged.connect(func(_at: Vector3, near: bool): _dodges.append(near))
			_to("settle")
		"settle":
			if _clock > 0.3:
				_game.run.set_max_hp(99999.0)
				_warden = _game.flow.warden
				_drop = _warden.get("drop") if is_instance_valid(_warden) else null
				_juice = _game.presentation.get("drop_juice") if _game.presentation != null else null
				if _drop == null or _juice == null:
					_report("setup", false, "drop rules %s, drop juice %s" % [_drop != null, _juice != null])
					return _finish()
				_windows_at = _drop.windows
				_to("schedule")
		"schedule":
			_step_schedule()
		"fast_hold":
			_step_fast_hold()
		"fast_fly":
			if _landed > 0 or _clock > 3.0:
				_report("fast", _landed == 1 and _drop.drops_landed == 1,
					"a %.0f m/s ball let go %.1f m up the west lip's run-up when the marker turned amber (eta %.2f s): %s after %.2f s"
						% [FAST_SPEED, RUN_UP, _release_eta, "landed" if _landed > 0 else "no drop", _clock])
				_to("dodge_wait")
				_dodge_mode = "near"
				_pulses_at = _warden.pulses
		"dodge_wait":
			_step_dodge()
	return false


func _to(phase: String) -> void:
	_phase = phase
	_clock = 0.0


func _park() -> void:
	var start: Vector2 = _game.ctx.terrain.map().drop_lines[0]["start"]
	_game.player.reset_to(_game.ctx.terrain.drop_point(start.x, start.y, 1.2))


func _step_schedule() -> void:
	_park()
	var now := _clock
	var open: bool = _warden.family_open()
	for p in _predictions.duplicate():
		if p["at"] <= now:
			_predictions.erase(p)
			_checked += 1
			if p["open"] == open:
				_agree += 1
	if int(round(now * 90.0)) % 45 == 0:
		for eta in LOOKAHEAD:
			_predictions.append({"at": now + eta, "open": _drop.open_at(eta)})
	var left: float = _drop.window_left()
	_since_edge = 0.0 if (left > 0.0) != _was_open else _since_edge + 1.0 / 90.0
	_was_open = left > 0.0
	# The look redraws on the frame after a physics edge; judge it once it has.
	if _since_edge >= 0.1:
		if left > 0.0:
			var h: float = _juice.beam.scale.y
			if not _juice.beam.visible or h > _beam_last + 0.001:
				_beam_ok = false
			_beam_last = h
			if _juice.schedule.visible:
				_dial_ok = false
		else:
			_beam_last = INF
			if _juice.beam.visible or not _juice.schedule.visible:
				_dial_ok = false
	if now < SCHEDULE_SECONDS:
		return
	var windows: int = _drop.windows - _windows_at
	_report("schedule", windows >= MIN_WINDOWS and _warden.min_pulse_telegraph >= 1.5,
		"parked %.0f m from the mast (reach %.0f m): %d windows in %.0f s, shortest telegraph %.2f s"
			% [_flat(_game.player.ball_position(), _warden.global_position), _warden.reach, windows, SCHEDULE_SECONDS, _warden.min_pulse_telegraph])
	var share := float(_agree) / maxf(1.0, float(_checked))
	_report("readable ahead", _checked > 50 and share >= AGREE,
		"open_at() looked %s s ahead matched the core %d of %d times (%.3f, band >= %.2f)" % [LOOKAHEAD, _agree, _checked, share, AGREE])
	_report("states", _states.has("telegraph") and _states.has("open") and _states.has("recover") and _states.has("closed"),
		"published states %s" % [_states.keys()])
	_report("beam", _beam_ok, "the beam stood only while open and never grew within a window")
	_report("dial", _dial_ok, "the opening dial stood only while the core was shut")
	_to("fast_hold")


# Held on the run-up at speed, the ball is let go the moment the marker reads amber for
# its eta and the schedule says open 0.3 s either side of it.
func _step_fast_hold() -> void:
	var line: Dictionary = _game.ctx.terrain.map().drop_lines[0]
	var lip: Vector2 = line["at"]
	var dir: Vector2 = line["dir"]
	var at: Vector2 = lip - dir * RUN_UP
	var point: Vector3 = _game.ctx.terrain.drop_point(at.x, at.y, 1.05)
	var v := Vector3(dir.x, 0.0, dir.y) * FAST_SPEED
	_game.player.reset_to(point, v)
	var f: Dictionary = _juice.forecast
	if f.is_empty():
		if _clock > 10.0:
			_report("forecast", false, "no landing marker on the west run-up at %.0f m/s" % FAST_SPEED)
			_to("dodge_wait")
			_dodge_mode = "near"
			_pulses_at = _warden.pulses
		return
	if not _marker_seen:
		_marker_seen = true
		_report("forecast", _juice.marker.visible and f["open"] == _drop.open_at(f["eta"]),
			"the marker stands over the core, %s for an eta of %.2f s (the schedule says %s)"
				% ["amber" if f["open"] else "hazard", f["eta"], "open" if _drop.open_at(f["eta"]) else "shut"])
	if f["open"] and _drop.open_at(f["eta"] - 0.3) and _drop.open_at(f["eta"] + 0.3):
		_release_eta = f["eta"]
		_to("fast_fly")


func _step_dodge() -> void:
	var mast: Vector3 = _warden.global_position
	var inside: Vector3 = _game.ctx.terrain.drop_point(mast.x + 4.0, mast.z, 1.05)
	var outside: Vector3 = _game.ctx.terrain.drop_point(mast.x + 12.0, mast.z, 1.05)
	if _dodge_mode == "done":
		return
	if _warden.pulses > _pulses_at:
		_pulses_at = _warden.pulses
		if _dodge_mode == "near":
			_dodge_mode = "safe"
		else:
			_dodge_mode = "done"
			_judge_dodges()
			return
	if not _warden._charging:
		_game.player.reset_to(outside)
		if _clock > 12.0:
			_report("dodge", false, "no telegraph to dodge in 12 s")
			_finish()
		return
	var left: float = _warden._charge_len - _warden._charge_time
	var leave_at: float = 0.15 if _dodge_mode == "near" else 0.9
	_game.player.reset_to(inside if left > leave_at else outside)


func _judge_dodges() -> void:
	var dodged: Dictionary = EventKinds.ROWS["warden_pulse_dodged"]
	var opened: Dictionary = EventKinds.ROWS["weak_point_opened"]
	_report("dodge", _dodges == [true, false] and _juice.near_misses_heard == 1 and _juice.safe_dodges_heard == 1
		and _warden.near_misses == 1 and _warden.safe_dodges == 1,
		"leaving 0.15 s before the clang is a near-miss, 0.9 s before a safe resolution: bus %s, heard near %d / safe %d"
			% [_dodges, _juice.near_misses_heard, _juice.safe_dodges_heard])
	_report("dodge shape", dodged["shape"] != opened["shape"] and dodged["color"] != _game.player.class_color(),
		"a dodge wears '%s' in bone; open wears '%s' and the class colour" % [dodged["shape"], opened["shape"]])
	_finish()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _finish() -> bool:
	_phase = "done"
	print("warden_window_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
