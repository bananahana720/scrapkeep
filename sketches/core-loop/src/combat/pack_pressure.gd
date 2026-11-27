extends RefCounted

const PRESSURE_CUE_S := 0.5
const MAX_LEAD_S := 2.5
const MAX_TURN := 2.5
const TURN_SMOOTH_S := 0.3
const MIN_TURN_SPEED := 3.0
const LEAD_FADE_FROM := 0.85

const STEADY_SPREAD_DEG := 10.0
const UNSTEADY_SPREAD_DEG := 20.0
const BOSS_MAX_LEAD_S := 4.0
const LEAD_TELL_FULL := 1.0
const LEAD_TELL_NONE := 0.6
const LEAD_SOLVE_STEPS := 3

static var lead_plant := ""


class HeadingRecord:
	const SAMPLE_S := 0.1
	const SAMPLES := 11
	var headings := PackedFloat32Array()
	var newest := -1
	var count := 0
	var _since := 0.0

	func _init() -> void:
		headings.resize(SAMPLES)

	func clear() -> void:
		newest = -1
		count = 0
		_since = 0.0

	func push(heading: float, dt: float) -> void:
		_since += dt
		if count > 0 and _since < SAMPLE_S:
			return
		_since = 0.0
		newest = (newest + 1) % SAMPLES
		headings[newest] = heading
		count = mini(count + 1, SAMPLES)

	func spread(now: float) -> float:
		if count < SAMPLES:
			return INF
		var widest := 0.0
		for h in headings:
			if is_nan(h):
				return INF
			widest = maxf(widest, absf(wrapf(h - now, -PI, PI)))
		return widest


static var _frame := -1
static var _heading := 0.0
static var _turn := 0.0
static var _have_heading := false
static var _cruise := 0.0
static var _record := HeadingRecord.new()


static func reset_for_tests() -> void:
	lead_plant = ""
	_frame = -1
	_heading = 0.0
	_turn = 0.0
	_have_heading = false
	_cruise = 0.0
	_record.clear()


static func crew_row(stage: int) -> Dictionary:
	return {
		"lead": ChallengeDials.by_stage_or("pack.lead_by_stage", stage, 0.0),
		"lead_cruise": ChallengeDials.by_stage_or("pack.lead_cruise_by_stage", stage, 1.0),
		"rest": ChallengeDials.by_stage("pack.rest_by_stage", stage),
		"flank": ChallengeDials.by_stage_or("pack.flank_by_stage", stage, 0.0),
	}


static func lead_now(pressure: Dictionary, target) -> float:
	var lead := float(pressure.get("lead", 0.0))
	var keep := float(pressure.get("lead_cruise", 1.0))
	if lead <= 0.0 or keep >= 1.0 or _cruise <= 0.0:
		return lead
	var pace: float = target.planar_velocity().length() / _cruise
	return lead * lerpf(1.0, keep, clampf((pace - LEAD_FADE_FROM) / (1.0 - LEAD_FADE_FROM), 0.0, 1.0))


static func crew_extra(stage: int) -> int:
	return maxi(0, int(round(ChallengeDials.by_stage_or("pack.crew_extra_by_stage", stage, 0.0))))


static func predict(target, seconds: float) -> Vector3:
	return _carry(target.ball_position(), target.planar_velocity(), clampf(seconds, 0.0, MAX_LEAD_S))


static func _carry(at: Vector3, v: Vector3, t: float) -> Vector3:
	var w := _turn
	if absf(w) < 0.05:
		return at + v * t
	var phi := w * t
	var a := sin(phi)
	var b := 1.0 - cos(phi)
	return at + Vector3(v.x * a - v.z * b, 0.0, v.x * b + v.z * a) / w


static func lead_aim(target, from: Vector3, tell: float, travel_speed := 0.0, reach := 0.0, body := 0.0) -> Vector3:
	var at: Vector3 = target.ball_position()
	var v: Vector3 = target.planar_velocity()
	if travel_speed > 0.0 and v.length() >= travel_speed:
		return at
	var share := _lead_share(v) * clampf((tell - LEAD_TELL_NONE) / (LEAD_TELL_FULL - LEAD_TELL_NONE), 0.0, 1.0)
	if share <= 0.0:
		return at
	var aim := at
	for i in LEAD_SOLVE_STEPS:
		var t := tell
		if travel_speed > 0.0:
			t += maxf(0.0, Vector2(aim.x - from.x, aim.z - from.z).length() - reach) / travel_speed
		aim = _carry(at, v, clampf(t, 0.0, BOSS_MAX_LEAD_S))
	return _stop_at_body(at.lerp(aim, share), from, at, body)


static func _stop_at_body(led: Vector3, from: Vector3, at: Vector3, body: float) -> Vector3:
	if body <= 0.0:
		return led
	var a := Vector2(at.x - from.x, at.z - from.z)
	var d := Vector2(led.x - at.x, led.z - at.z)
	if a.length() <= body:
		return at
	var len2 := d.length_squared()
	if len2 <= 0.0:
		return led
	var b := a.dot(d)
	var disc := b * b - len2 * (a.length_squared() - body * body)
	if disc < 0.0:
		return led
	var t := (-b - sqrt(disc)) / len2
	if t < 0.0 or t > 1.0:
		return led
	return at.lerp(led, t)


static func _lead_share(v: Vector3) -> float:
	if lead_plant == "full":
		return 1.0
	if lead_plant == "none":
		return 0.0
	if Vector2(v.x, v.z).length() < MIN_TURN_SPEED:
		return 0.0
	var spread := rad_to_deg(_record.spread(atan2(v.z, v.x)))
	return clampf((UNSTEADY_SPREAD_DEG - spread) / (UNSTEADY_SPREAD_DEG - STEADY_SPREAD_DEG), 0.0, 1.0)


static func turn_rate() -> float:
	return _turn


static func observe(v: Vector3, cruise := 0.0) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _frame:
		_cruise = cruise
		return
	var fresh := frame != _frame + 1
	_frame = frame
	# Godot _physics_process ticks at physics_ticks_per_second under Engine.time_scale, so scale dt by time_scale.
	observe_tick(v, Engine.time_scale / float(Engine.physics_ticks_per_second), cruise, fresh)


static func observe_tick(v: Vector3, dt: float, cruise := 0.0, fresh := false) -> void:
	_cruise = cruise
	if fresh:
		_have_heading = false
		_turn = 0.0
		_record.clear()
	var speed := Vector2(v.x, v.z).length()
	var heading := atan2(v.z, v.x)
	_record.push(heading if speed >= MIN_TURN_SPEED else NAN, dt)
	if speed < MIN_TURN_SPEED:
		_have_heading = false
		_turn = move_toward(_turn, 0.0, dt * MAX_TURN)
		return
	if _have_heading:
		var raw := clampf(wrapf(heading - _heading, -PI, PI) / dt, -MAX_TURN, MAX_TURN)
		_turn = lerpf(_turn, raw, 1.0 - exp(-dt / TURN_SMOOTH_S))
	_heading = heading
	_have_heading = true
