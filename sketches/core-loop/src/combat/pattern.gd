extends Resource

const MAX_VOLLEY := 16
const MAX_RATE := 20.0
const MIN_RATE := 0.05
const MAX_WAVE := 1.2
const MAX_ARM_OFFSET := 14.0
const MAX_ARMS := 8
const MAX_PIERCE := 3
const TRIGGER_HOLD_AUTO := "hold_auto"
const TRIGGER_PRESS := "press"
const TRIGGER_TAP_CHARGE := "tap_charge"
const TRIGGER_LOB_SNAP := "lob_snap"
const TRIGGER_BEATS := "beats"
const TRIGGER_STAMP := "stamp"
const TRIGGER_LOCK := "lock"
const DEFAULT_TRIGGER := TRIGGER_HOLD_AUTO
const TRIGGERS := [TRIGGER_HOLD_AUTO, TRIGGER_PRESS, TRIGGER_TAP_CHARGE, TRIGGER_LOB_SNAP,
	TRIGGER_BEATS, TRIGGER_STAMP, TRIGGER_LOCK]
const MAX_FLOOR_S := 5.0
const MAX_MAG := 32
const MAX_RELOAD_S := 6.0
const MAX_WINDOW_S := 5.0
const MIN_WINDOW_MULT := 1.0
const MAX_WINDOW_MULT := 4.0
const MAX_CHARGE_S := 5.0
const MAX_TAP_THRESHOLD_S := 1.0
const MAX_RECOVER_S := 5.0
const MIN_CAST_COST := 0.1
const MAX_CAST_COST := 3.0
const MAX_REFUND := 1.0
const MAX_STAMP_STREAK_BONUS := 40.0
const MAX_STAMP_STREAK_CAP := 100.0
const MAX_LOCK_DAMAGE := 200.0
const MAX_LOCK_REACH := 80.0
const MIN_LOCK_WIDTH_MULT := 0.25
const MAX_LOCK_WIDTH_MULT := 4.0
const MIN_BEAT_MULT := 0.1
const MAX_BEAT_MULT := 10.0
const MAX_BEAT_SPEED_MULT := 2.0
const MAX_BEAT_KNOCK_MULT := 5.0
const MAX_BEAT_RANGE_MULT := 3.0
const MAX_CHARGE_BOLT_MULT := 20.0
const MAX_CHARGE_PULSES := 12
const MAX_CHARGE_PULSE_SPAN_S := 3.0
const MAX_PIERCE_EVERY := 20
const MAX_LIVE_CAP := 16

@export var count := 1
@export var spread_deg := 0.0
@export var arms := 1
@export var arm_offset_deg := 0.0
@export var rotation_deg := 0.0
@export var spin_deg := 0.0
@export var wave_amp := 0.0
@export var wave_hz := 0.0
@export var pierce := 0
@export var damage := 10.0
@export var rate := 5.0
@export var range_m := 70.0
@export var speed := 120.0
@export var bolt_radius := 0.3
@export var knock := 8.0
@export var chain_jumps := 0
@export var chain_range := 0.0
@export var chain_falloff := 0.7
@export var lattice_chain_falloff := 0.0
@export var burst_scale := 1.0
@export var special_scale := 1.0
@export var trigger := DEFAULT_TRIGGER
@export var floor_s := 0.0
@export var beat_floors_s: Array = []
@export var mag := 0
@export var reload_s := 0.0
@export var window_s := Vector2.ZERO
@export var window_mult := 1.0
@export var charge_s := 0.0
@export var charge_min := 0.0
@export var tap_threshold_s := 0.0
@export var recover_s := 0.0
@export var beat_window_s := 0.0
@export var beat_mults: Array = []
@export var beat_speed_mult := 0.0
@export var beat_knock_mult := 1.0
@export var beat_range_mult := 1.0
@export var cast_cost := 1.0
@export var refund := 0.0
@export var stamp_streak_bonus := 0.0
@export var stamp_streak_cap := 0.0
@export var lock_rail_damage := 0.0
@export var lock_barrage_damage := 0.0
@export var lock_pulse_reach := 0.0
@export var lock_rail_reach := 0.0
@export var lock_pulse_width_mult := 1.0
@export var lock_rail_width_mult := 1.0
@export var lock_barrage_width_mult := 1.0
@export var lock_rail_breaks_props := false
@export var fan := false
@export var spark_count := 1
@export var charge_bolt_mult := 0.0
@export var charge_pulses := 1
@export var charge_pulse_span_s := 0.0
@export var charge_pierce := 0
@export var charge_no_chain := false
@export var pierce_every := 0
@export var breaks_props := false
@export var beat_breaks_props := false
@export var max_live := 0

const FIELDS := ["count", "spread_deg", "arms", "arm_offset_deg", "rotation_deg", "spin_deg",
	"wave_amp", "wave_hz", "pierce", "damage", "rate", "range_m", "speed", "bolt_radius", "knock",
	"chain_jumps", "chain_range", "chain_falloff", "lattice_chain_falloff", "burst_scale", "special_scale",
	"trigger", "floor_s", "beat_floors_s", "mag", "reload_s", "window_s", "window_mult",
	"charge_s", "charge_min", "tap_threshold_s", "recover_s", "beat_window_s",
	"beat_mults", "beat_speed_mult", "beat_knock_mult", "beat_range_mult",
	"cast_cost", "refund", "stamp_streak_bonus", "stamp_streak_cap",
	"lock_rail_damage", "lock_barrage_damage", "lock_pulse_reach", "lock_rail_reach",
	"lock_pulse_width_mult", "lock_rail_width_mult", "lock_barrage_width_mult", "lock_rail_breaks_props", "fan",
	"spark_count", "charge_bolt_mult", "charge_pulses", "charge_pulse_span_s", "charge_pierce", "charge_no_chain",
	"pierce_every", "breaks_props", "beat_breaks_props", "max_live"]

const TRANSFORMERS := {
	"cross_split": {
		"label": "Cross split", "text": "every shot splits into a cross around your aim",
		"add": {"arms": 3}, "min": {"arm_offset_deg": 7.0},
	},
	"spiral_wave": {
		"label": "Spiral wave", "text": "the spread turns each shot and bolts corkscrew",
		"add": {"spin_deg": 23.0, "wave_amp": 0.35}, "min": {"arms": 2, "arm_offset_deg": 4.0, "wave_hz": 3.0},
	},
	"fan_spread": {
		"label": "Fan spread", "text": "shots fan into a 5-round cone",
		"add": {"count": 4}, "mul": {"damage": 0.65}, "min": {"spread_deg": 7.0},
	},
	"helix_drill": {
		"label": "Helix drill", "text": "shots corkscrew through two machines",
		"add": {"count": 2, "pierce": 1, "wave_amp": 0.35}, "mul": {"damage": 0.75}, "min": {"spread_deg": 6.0, "wave_hz": 3.0},
	},
	"halo": {
		"label": "Halo rig", "text": "adds a ring of shots around your aim",
		"add": {"arms": 5}, "min": {"arm_offset_deg": 10.0}, "mul": {"damage": 0.55, "rate": 0.85},
	},
	"chain_arc": {
		"label": "Chain arc", "text": "hits arc to one more enemy nearby",
		"add": {"chain_jumps": 1, "chain_range": 4.0}, "min": {"chain_range": 9.0},
	},
	"damage_tier": {
		"label": "Hot rounds", "text": "+25% weapon damage",
		"mul": {"damage": 1.25},
	},
	"rate_tier": {
		"label": "Fast cycle", "text": "+20% fire rate",
		"mul": {"rate": 1.2},
	},
	"range_tier": {
		"label": "Long barrel", "text": "+25% range, +10% bolt speed",
		"mul": {"range_m": 1.25, "speed": 1.1},
	},
	"capacitor": {
		"label": "Pylon capacitor", "text": "the pylon's discharge hits harder and arcs further",
		"add": {"chain_range": 3.0}, "mul": {"burst_scale": 1.5},
	},
	"overclock": {
		"label": "Overclock", "text": "+30% fire rate and a longer overdrive",
		"mul": {"rate": 1.3, "special_scale": 1.3},
	},
	"brass_drum": {
		"label": "Brass drum", "text": "Adds 4 rounds, +35% fire rate, 72% damage",
		"add": {"mag": 4},
		"mul": {"rate": 1.35, "damage": 0.72, "lock_rail_damage": 0.72, "lock_barrage_damage": 0.72},
	},
	"heavy_breech": {
		"label": "Heavy breech", "text": "55% rate, 180% damage, 2x knock, breaks props",
		"set": {"breaks_props": true, "lock_rail_breaks_props": true},
		"mul": {"mag": 0.5, "rate": 0.55, "damage": 1.8, "lock_rail_damage": 1.8, "lock_barrage_damage": 1.8, "knock": 2.0},
	},
}


static func make(values: Dictionary) -> Resource:
	var pattern: Resource = load("res://src/combat/pattern.gd").new()
	for key in values:
		pattern.set(key, _coerce(key, values[key]))
	return pattern


func copy() -> Resource:
	var twin: Resource = load("res://src/combat/pattern.gd").new()
	for key in FIELDS:
		var val = get(key)
		twin.set(key, val.duplicate() if val is Array else val)
	return twin


static func has_transformer(id: String) -> bool:
	return TRANSFORMERS.has(id)


func transformed(ids: Array) -> Resource:
	var out: Resource = copy()
	for id in ids:
		if TRANSFORMERS.has(id):
			out._apply(TRANSFORMERS[id])
	out._clamp()
	return out


static func _coerce(key: String, value):
	if key == "window_s" and value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if (key == "beat_floors_s" or key == "beat_mults") and value is Array:
		var vals: Array = []
		for v in value:
			vals.append(float(v))
		return vals
	return value


func _apply(row: Dictionary) -> void:
	var assigned: Dictionary = row.get("set", {})
	for key in assigned:
		set(key, _coerce(key, assigned[key]))
	var add: Dictionary = row.get("add", {})
	for key in add:
		set(key, get(key) + add[key])
	var mul: Dictionary = row.get("mul", {})
	for key in mul:
		var cur = get(key)
		if cur is Array:
			var scaled: Array = []
			for v in cur:
				scaled.append(float(v) * float(mul[key]))
			set(key, scaled)
		elif typeof(cur) == TYPE_INT:
			var scaled_i := roundi(float(cur) * float(mul[key]))
			if key == "mag" and int(cur) > 0 and float(mul[key]) > 0.0:
				scaled_i = maxi(1, scaled_i)
			set(key, scaled_i)
		else:
			set(key, cur * mul[key])
	var floor_row: Dictionary = row.get("min", {})
	for key in floor_row:
		set(key, maxf(get(key), floor_row[key]) if typeof(get(key)) == TYPE_FLOAT else maxi(get(key), floor_row[key]))


static func _clamp_f(value: float, lo: float, hi: float) -> float:
	return lo if not is_finite(value) else clampf(value, lo, hi)


func _clamp() -> void:
	arms = clampi(arms, 1, MAX_ARMS)
	count = clampi(count, 1, MAX_VOLLEY)
	rate = clampf(rate, MIN_RATE, MAX_RATE)
	wave_amp = minf(wave_amp, MAX_WAVE)
	pierce = clampi(pierce, 0, MAX_PIERCE)
	arm_offset_deg = minf(arm_offset_deg, MAX_ARM_OFFSET)
	if not (trigger in TRIGGERS):
		trigger = DEFAULT_TRIGGER
	floor_s = _clamp_f(floor_s, 0.0, MAX_FLOOR_S)
	if not beat_floors_s.is_empty():
		var clamped_floors: Array = []
		for v in beat_floors_s:
			clamped_floors.append(_clamp_f(float(v), 0.0, MAX_FLOOR_S))
		beat_floors_s = clamped_floors
	mag = clampi(mag, 0, MAX_MAG)
	reload_s = _clamp_f(reload_s, 0.0, MAX_RELOAD_S)
	var w_open := _clamp_f(window_s.x, 0.0, MAX_WINDOW_S)
	var w_close := _clamp_f(window_s.y, w_open, MAX_WINDOW_S)
	window_s = Vector2(w_open, w_close)
	window_mult = _clamp_f(window_mult, MIN_WINDOW_MULT, MAX_WINDOW_MULT)
	charge_s = _clamp_f(charge_s, 0.0, MAX_CHARGE_S)
	charge_min = _clamp_f(charge_min, 0.0, 1.0)
	tap_threshold_s = _clamp_f(tap_threshold_s, 0.0, MAX_TAP_THRESHOLD_S)
	recover_s = _clamp_f(recover_s, 0.0, MAX_RECOVER_S)
	beat_window_s = _clamp_f(beat_window_s, 0.0, MAX_WINDOW_S)
	if not beat_mults.is_empty():
		var clamped_mults: Array = []
		for v in beat_mults:
			clamped_mults.append(_clamp_f(float(v), MIN_BEAT_MULT, MAX_BEAT_MULT))
		beat_mults = clamped_mults
	beat_speed_mult = _clamp_f(beat_speed_mult, 0.0, MAX_BEAT_SPEED_MULT)
	beat_knock_mult = _clamp_f(beat_knock_mult, 1.0, MAX_BEAT_KNOCK_MULT)
	beat_range_mult = _clamp_f(beat_range_mult, 1.0, MAX_BEAT_RANGE_MULT)
	cast_cost = _clamp_f(cast_cost, MIN_CAST_COST, MAX_CAST_COST)
	refund = _clamp_f(refund, 0.0, minf(MAX_REFUND, cast_cost))
	stamp_streak_bonus = _clamp_f(stamp_streak_bonus, 0.0, MAX_STAMP_STREAK_BONUS)
	stamp_streak_cap = _clamp_f(stamp_streak_cap, 0.0, MAX_STAMP_STREAK_CAP)
	lock_rail_damage = _clamp_f(lock_rail_damage, 0.0, MAX_LOCK_DAMAGE)
	lock_barrage_damage = _clamp_f(lock_barrage_damage, 0.0, MAX_LOCK_DAMAGE)
	lock_pulse_reach = _clamp_f(lock_pulse_reach, 0.0, MAX_LOCK_REACH)
	lock_rail_reach = _clamp_f(lock_rail_reach, 0.0, MAX_LOCK_REACH)
	lock_pulse_width_mult = _clamp_f(lock_pulse_width_mult, MIN_LOCK_WIDTH_MULT, MAX_LOCK_WIDTH_MULT)
	lock_rail_width_mult = _clamp_f(lock_rail_width_mult, MIN_LOCK_WIDTH_MULT, MAX_LOCK_WIDTH_MULT)
	lock_barrage_width_mult = _clamp_f(lock_barrage_width_mult, MIN_LOCK_WIDTH_MULT, MAX_LOCK_WIDTH_MULT)
	spark_count = clampi(spark_count, 1, MAX_VOLLEY)
	charge_bolt_mult = _clamp_f(charge_bolt_mult, 0.0, MAX_CHARGE_BOLT_MULT)
	charge_pulses = clampi(charge_pulses, 1, MAX_CHARGE_PULSES)
	charge_pulse_span_s = _clamp_f(charge_pulse_span_s, 0.0, MAX_CHARGE_PULSE_SPAN_S)
	charge_pierce = clampi(charge_pierce, 0, MAX_PIERCE)
	pierce_every = clampi(pierce_every, 0, MAX_PIERCE_EVERY)
	max_live = clampi(max_live, 0, MAX_LIVE_CAP)


func volley_size() -> int:
	var raw := count if arms <= 1 else 1 + arms * count
	return mini(raw, MAX_VOLLEY)


func layout(forward: Vector3, volley: int) -> Array:
	var fwd := forward.normalized()
	var up_hint := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var right := fwd.cross(up_hint).normalized()
	var up := right.cross(fwd).normalized()
	var roll := deg_to_rad(rotation_deg + spin_deg * volley)
	var out := []
	if arms <= 1:
		for i in count:
			var off := (i - (count - 1) * 0.5) * spread_deg
			var phase := roll if off >= 0.0 else roll + PI
			out.append({"dir": _tilt(fwd, right, up, deg_to_rad(absf(off)), phase), "phase": phase, "centre": is_zero_approx(off)})
	else:
		out.append({"dir": fwd, "phase": roll, "centre": true})
		var step := spread_deg if spread_deg > 0.1 else 3.0
		for j in count:
			for a in arms:
				var phase := roll + TAU * a / arms
				var theta := deg_to_rad(arm_offset_deg + step * j)
				out.append({"dir": _tilt(fwd, right, up, theta, phase), "phase": phase, "centre": false})
	if out.size() > MAX_VOLLEY:
		out.resize(MAX_VOLLEY)
	return out


func directions(forward: Vector3, volley: int) -> Array:
	var dirs := []
	for bolt in layout(forward, volley):
		dirs.append(bolt["dir"])
	return dirs


static func _tilt(fwd: Vector3, right: Vector3, up: Vector3, theta: float, phase: float) -> Vector3:
	if is_zero_approx(theta):
		return fwd
	var side := right * cos(phase) + up * sin(phase)
	return (fwd * cos(theta) + side * sin(theta)).normalized()
