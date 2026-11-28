class_name ChallengeDials
extends RefCounted

const CliFlags := preload("res://src/core/cli_flags.gd")

const TELL_FLOOR := 0.6
const WARN_GAP := 0.2

const ONES6 := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
const ZEROS6 := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const PULSE_DAMAGE_W1 := [4.0, 4.5, 1.0, 1.0, 1.0, 1.0]
const SLAG_DAMAGE_W1 := [1.0, 4.5, 1.0, 1.0, 1.0, 1.0]
const PULSE_CYCLE_W1 := [1.0, 0.85, 1.0, 1.0, 1.0, 1.0]
const PULSE_RATCHET_W1 := [1.0, 0.9, 1.0, 1.0, 1.0, 1.0]
const SILT_W1 := [2.0, 2.0, 0.0, 0.0, 0.0, 0.0]
const LEAD_W1 := [0.7, 0.5, 0.5, 0.5, 0.5, 0.5]
const LEAD_CRUISE_W1 := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const MOBS_DAMAGE_W1 := [2.6, 2.5, 1.0, 1.0, 1.0, 1.0]
const CHASER_SPEED_W1 := [9.0, 9.0, 9.0, 9.0, 9.0, 9.0]
const INTERVAL_W1 := [1.0, 0.7, 1.0, 1.0, 1.0, 1.0]
const PACK_W1 := [1.0, 1.0, 0.0, 0.0, 0.0, 0.0]
const PACK_HALF_W1 := [0.5, 0.5, 1.0, 1.0, 1.0, 1.0]

const PACK_PRESSURE_PRESETS := {
	"A": {"pack.lead_by_stage": PACK_W1},
	"B": {"pack.crew_extra_by_stage": PACK_W1, "pack.rest_by_stage": PACK_HALF_W1},
	"C": {"pack.flank_by_stage": PACK_W1},
	"D": {"ground.churn_by_stage": PACK_W1},
	"E": {"hazard.boil_by_stage": SILT_W1},
}

const DEFAULTS := {
	"brindle.damage_mult": 1.0, "brindle.damage_by_phase": [2.5, 3.2, 2.5, 1.0],
	"brindle.period_mult": 1.0, "brindle.period_by_phase": [0.6, 0.35, 0.5, 1.0],
	"brindle.tell_mult": 1.0, "brindle.punish_mult": 1.0, "brindle.combo": 0.0,
	"brindle.follow_ups_by_phase": [0.0, 1.0, 1.0, 0.0],
	"brindle.transition_mult": 1.0,
	"waking.damage_mult": 1.0, "waking.damage_by_phase": [1.0, 1.0, 1.0, 1.0],
	"waking.period_mult": 1.0, "waking.period_by_phase": [1.0, 1.0, 1.0, 1.0],
	"waking.tell_mult": 1.0, "waking.punish_mult": 1.0, "waking.combo": 0.0,
	"waking.phase_min_by_phase": [1.0, 1.0, 1.0, 1.0],
	"waking.weak_points": 0.0, "mind.weak_points": 0.0,
	"mind.damage_mult": 1.0, "mind.damage_by_phase": [1.0, 1.0, 1.0, 1.0],
	"mind.period_mult": 1.0, "mind.period_by_phase": [1.0, 1.0, 1.0, 1.0],
	"mind.tell_mult": 1.0, "mind.punish_mult": 1.0, "mind.combo": 0.0,
	"mind.phase_min_by_phase": [1.0, 1.0, 1.0, 1.0],
	"hazard.shell_cover_by_stage": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	"mobs.lobber_lead_by_stage": [0.75, 0.75, 0.75, 0.75, 0.75, 0.75],
	"mobs.lobber_share_step_by_stage": [0.07, 0.07, 0.07, 0.07, 0.07, 0.07],
	"warden.pulse_damage_mult": 1.0, "warden.pulse_cycle_mult": 1.0, "warden.slag_damage_mult": 1.0,
	"warden.pulse_damage_by_stage": PULSE_DAMAGE_W1, "warden.pulse_cycle_by_stage": PULSE_CYCLE_W1, "warden.slag_damage_by_stage": SLAG_DAMAGE_W1,
	"warden.pulse_ratchet_by_stage": PULSE_RATCHET_W1,
	"warden.counter_damage_by_stage": ZEROS6,
	"warden.counter_telegraph_by_stage": [0.8, 0.8, 0.8, 0.8, 0.8, 0.8],
	"warden.counter_delay_by_stage": ONES6,
	"mobs.clock_tiers_by_stage": [3.0, 3.0, 2.0, 2.0, 2.0, 2.0],
	"mobs.damage_mult": 1.0, "mobs.pack_scale_mult": 1.0, "mobs.interval_scale_mult": 1.0, "mobs.elite_rate_mult": 1.0,
	"mobs.damage_by_stage": MOBS_DAMAGE_W1, "mobs.pack_scale_by_stage": ONES6, "mobs.interval_scale_by_stage": INTERVAL_W1, "mobs.elite_rate_by_stage": ONES6,
	"mobs.chaser_speed_by_stage": CHASER_SPEED_W1,
	"pack.lead_by_stage": LEAD_W1, "pack.lead_cruise_by_stage": LEAD_CRUISE_W1, "pack.crew_extra_by_stage": ZEROS6, "pack.rest_by_stage": ONES6,
	"pack.flank_by_stage": ZEROS6, "ground.churn_by_stage": ZEROS6, "hazard.boil_by_stage": SILT_W1,
	"hazard.boil_stall_by_stage": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	"hazard.hits_enemies_by_stage": [1.0, 1.0, 0.0, 0.0, 0.0, 0.0],
	"pilot.regen_delay_mult": 1.0, "pilot.regen_rate_mult": 1.0,
	"pilot.regen_rolling_by_stage": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
}

const RULED_PILOT := ["pilot.regen_rolling_by_stage"]

static var _overrides := {}
static var _rung := {}
static var _cli_loaded := false
static var _cli := {}
static var _warned := {}
static var rejected: Array[String] = []
static var quiet := false


static func value(key: String) -> Variant:
	_load_cli()
	if _overrides.has(key):
		return _overrides[key]
	if _cli.has(key):
		return _cli[key]
	return DEFAULTS[key]


static func f(key: String) -> float:
	return float(value(key)) * float(_rung.get(key, 1.0))


static func set_rung(d: Dictionary) -> void:
	_rung = d


static func rung() -> Dictionary:
	return _rung


static func set_overrides(d: Dictionary, allow_unruled := false) -> void:
	_overrides = {}
	for key in d:
		var k := String(key)
		if not DEFAULTS.has(k):
			_unknown(k)
			continue
		if k.begins_with("pilot.") and not k in RULED_PILOT and not allow_unruled and not _unruled():
			_reject(k, "pilot dials are not allowed levers yet (no ruling)")
			continue
		var v: Variant = d[key]
		if _is_list(k) and not v is Array:
			_reject(k, "a list dial takes an array, not '%s'" % str(v))
			continue
		var raw: String = "/".join((v as Array).map(func(x): return str(x))) if v is Array else str(v)
		if not _valid(k, raw):
			_reject(k, "'%s' is not a non-negative number" % raw)
			continue
		_overrides[k] = _coerce(k, v)


static func reset() -> void:
	_overrides = {}
	_rung = {}
	_cli = {}
	_cli_loaded = false
	_warned = {}
	rejected = []
	quiet = false


static func describe() -> Dictionary:
	_load_cli()
	var out := {}
	for key in DEFAULTS:
		var v: Variant = value(key)
		if v != DEFAULTS[key]:
			out[key] = v
	return out


static func parse(spec: String) -> Dictionary:
	var out := {}
	for pair in spec.split(",", false):
		var eq := pair.find("=")
		if eq <= 0:
			_unknown(pair)
			continue
		var k := pair.substr(0, eq).strip_edges()
		if not DEFAULTS.has(k):
			_unknown(k)
			continue
		if k.begins_with("pilot.") and not k in RULED_PILOT and not _unruled():
			_reject(k, "pilot dials are not allowed levers yet (no ruling); add --tune-unruled to override")
			continue
		var raw := pair.substr(eq + 1).strip_edges()
		if not _valid(k, raw):
			_reject(k, "'%s' is not a non-negative number" % raw + (" list a/b/c/d" if k.ends_with("_by_phase") else " list a/b/c/d/e/f" if k.ends_with("_by_stage") else ""))
			continue
		out[k] = _coerce(k, raw)
	return out


static func pack_pressure_spec(value: String, unknown: Array = []) -> String:
	var merged := {}
	for letter in value.to_upper().split("+", false):
		var key := letter.strip_edges()
		if not PACK_PRESSURE_PRESETS.has(key):
			unknown.append(key)
			continue
		merged.merge(PACK_PRESSURE_PRESETS[key], true)
	var pairs: Array[String] = []
	for k in merged:
		pairs.append("%s=%s" % [k, "/".join((merged[k] as Array).map(func(x): return str(x)))])
	return ",".join(pairs)


static func _load_cli() -> void:
	if _cli_loaded:
		return
	_cli_loaded = true
	for raw in CliFlags.values_of("--pack-pressure=", true):
		var unknown := []
		_cli.merge(parse(pack_pressure_spec(raw, unknown)), true)
		for letter in unknown:
			_refuse("pack-pressure " + letter, "challenge_dials: --pack-pressure variant '%s' ignored (A, B, C, D or E)" % letter)
	for raw in CliFlags.values_of("--tune=", true):
		_cli.merge(parse(raw), true)


static func _unruled() -> bool:
	return CliFlags.has_flag("--tune-unruled", true)


static func _is_list(key: String) -> bool:
	return key.ends_with("_by_phase") or key.ends_with("_by_stage")


static func _number(raw: String) -> bool:
	return raw.is_valid_float() and float(raw) >= 0.0


static func _valid(key: String, raw: String) -> bool:
	if _is_list(key):
		var parts := raw.split("/", true)
		for part in parts:
			if not _number(part):
				return false
		return not parts.is_empty()
	return _number(raw)


static func _reject(key: String, why: String) -> void:
	_refuse(key + why, "challenge_dials: dial '%s' ignored: %s" % [key, why])


static func _coerce(key: String, raw: Variant) -> Variant:
	if _is_list(key):
		var out := []
		if raw is String:
			for part in (raw as String).split("/", false):
				out.append(float(part))
		else:
			for part in raw:
				out.append(float(part))
		return out if not out.is_empty() else DEFAULTS[key]
	return float(raw)


static func _unknown(key: String) -> void:
	_refuse(key, "challenge_dials: unknown dial '%s' ignored" % key)


static func _refuse(id: String, message: String) -> void:
	rejected.append(message)
	if quiet or _warned.has(id):
		return
	_warned[id] = true
	push_error(message)


static func damage(boss: String, base: float, phase: int) -> float:
	return base * f(boss + ".damage_mult") * by_phase(boss + ".damage_by_phase", phase)


static func period(boss: String, base: float, phase: int) -> float:
	return maxf(WARN_GAP, base * f(boss + ".period_mult") * by_phase(boss + ".period_by_phase", phase))


static func tell(boss: String, seconds: float, module_floor := 0.0) -> float:
	return floored(seconds, f(boss + ".tell_mult"), module_floor)


static func floored(seconds: float, mult: float, module_floor := 0.0) -> float:
	var floor_s := maxf(TELL_FLOOR, module_floor)
	return maxf(minf(seconds, floor_s), seconds * mult)


static func punish(boss: String, base: float) -> float:
	return base * f(boss + ".punish_mult")


static func combo(boss: String) -> int:
	return maxi(0, int(round(f(boss + ".combo"))))


static func combo_step(boss: String, left: int) -> int:
	return combo(boss) if left < 0 else left - 1


static func by_phase(key: String, phase: int) -> float:
	var a: Array = value(key)
	return float(a[clampi(phase - 1, 0, a.size() - 1)])


static func by_stage(key: String, stage: int) -> float:
	var a: Array = value(key)
	return float(a[stage - 1]) if stage >= 1 and stage <= a.size() else 1.0


static func by_stage_or(key: String, stage: int, outside: float) -> float:
	var a: Array = value(key)
	return float(a[stage - 1]) if stage >= 1 and stage <= a.size() else outside


static func stage_mult(base_key: String, stage: int) -> float:
	return f(base_key + "_mult") * by_stage(base_key + "_by_stage", stage)
