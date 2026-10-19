class_name ChallengeDials
extends RefCounted
# Challenge lane C3a: the named difficulty dials (Andrew's 19 Oct ruling: Souls-like hard but
# fair, tuned against measured skill-band win rates). Plumbing only: with every dial at its
# default the game is byte-identical (tests/run_tier_test.gd pins that). Later units and the
# sweep harness move numbers through set_overrides() or `--tune=key=value,key=value` on the
# command line, with no code edits.
#
# Allowed levers: boss damage, attack patterns, combos, punish windows, extra phases, mob
# aggression, elite affixes. Frozen, and not dials: stagger and posture timing, the attacker
# caps (combat/attack_budget.gd), the 0.2 s warning gap, growth ratios, and enemy HEALTH
# (difficulty never raises enemy health). Every lethal attack keeps a tell of at least TELL_FLOOR.
#
# brindle.punish_mult scales WALL_STUN and CLASH_STUN, Brindle's punish windows; it does not touch
# posture or stagger timing (frozen).
#
# Values are floats; keys ending in `_by_phase` are arrays of floats (`a/b/c/d` on the command
# line). Static API, no autoload.

# No dial may shorten a boss tell below this (seconds).
const TELL_FLOOR := 0.6
# The warning gap: no two warnings start closer than this (waking_attacks.gd GAP). A combo
# follow-up and a scaled period never come sooner than this after the last attack.
const WARN_GAP := 0.2

const DEFAULTS := {
	# Per boss: hazard damage to the pilot, attack cadence, warn seconds, punish windows,
	# and the number of extra follow-up attacks queued right after an attack.
	"brindle.damage_mult": 1.0, "brindle.damage_by_phase": [1.0, 1.0, 1.0, 1.0],
	"brindle.period_mult": 1.0, "brindle.period_by_phase": [1.0, 1.0, 1.0, 1.0],
	"brindle.tell_mult": 1.0, "brindle.punish_mult": 1.0, "brindle.combo": 0.0,
	"waking.damage_mult": 1.0, "waking.damage_by_phase": [1.0, 1.0, 1.0, 1.0],
	"waking.period_mult": 1.0, "waking.period_by_phase": [1.0, 1.0, 1.0, 1.0],
	"waking.tell_mult": 1.0, "waking.punish_mult": 1.0, "waking.combo": 0.0,
	"mind.damage_mult": 1.0, "mind.damage_by_phase": [1.0, 1.0, 1.0, 1.0],
	"mind.period_mult": 1.0, "mind.period_by_phase": [1.0, 1.0, 1.0, 1.0],
	"mind.tell_mult": 1.0, "mind.punish_mult": 1.0, "mind.combo": 0.0,
	# Wardens (warden.gd): the pulse's damage and cycle, the meltdown slag's damage.
	"warden.pulse_damage_mult": 1.0, "warden.pulse_cycle_mult": 1.0, "warden.slag_damage_mult": 1.0,
	# Mobs: enemy hits (after director.damage_scale(); Warden and vault sources excluded),
	# the director's crowd cap and spawn interval, and the elite repeat chance. The attack_budget
	# caps and Director.HARD_CAP stay hard ceilings.
	"mobs.damage_mult": 1.0, "mobs.pack_scale_mult": 1.0, "mobs.interval_scale_mult": 1.0, "mobs.elite_rate_mult": 1.0,
	# NOT ALLOWED LEVERS YET. Plumbed only: a ruling is needed before any non-default value ships.
	"pilot.regen_delay_mult": 1.0, "pilot.regen_rate_mult": 1.0,
}

static var _overrides := {}
static var _cli_loaded := false
static var _cli := {}
static var _warned := {}


static func value(key: String) -> Variant:
	_load_cli()
	if _overrides.has(key):
		return _overrides[key]
	if _cli.has(key):
		return _cli[key]
	return DEFAULTS[key]


static func f(key: String) -> float:
	return float(value(key))


# Replaces the programmatic overrides (tests, the ladder later). Unknown keys, non-numeric or
# negative values, and pilot.* keys (unless allow_unruled) push_error once and are ignored: the
# same checks as the command line's.
static func set_overrides(d: Dictionary, allow_unruled := false) -> void:
	_overrides = {}
	for key in d:
		var k := String(key)
		if not DEFAULTS.has(k):
			_unknown(k)
			continue
		if k.begins_with("pilot.") and not allow_unruled and not _unruled():
			_reject(k, "pilot dials are not allowed levers yet (no ruling)")
			continue
		var v: Variant = d[key]
		var raw: String = "/".join((v as Array).map(func(x): return str(x))) if v is Array else str(v)
		if not _valid(k, raw):
			_reject(k, "'%s' is not a non-negative number" % raw)
			continue
		_overrides[k] = _coerce(k, v)


# Clears overrides and forgets the command line, so the next read parses it again.
static func reset() -> void:
	_overrides = {}
	_cli = {}
	_cli_loaded = false
	_warned = {}


# Only the non-default values, for run records.
static func describe() -> Dictionary:
	_load_cli()
	var out := {}
	for key in DEFAULTS:
		var v: Variant = value(key)
		if v != DEFAULTS[key]:
			out[key] = v
	return out


# Parses "key=value,key=value" (the --tune= payload). Unknown keys push_error once and drop.
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
		if k.begins_with("pilot.") and not _unruled():
			_reject(k, "pilot dials are not allowed levers yet (no ruling); add --tune-unruled to override")
			continue
		var raw := pair.substr(eq + 1).strip_edges()
		if not _valid(k, raw):
			_reject(k, "'%s' is not a non-negative number" % raw + (" list a/b/c/d" if k.ends_with("_by_phase") else ""))
			continue
		out[k] = _coerce(k, raw)
	return out


static func _load_cli() -> void:
	if _cli_loaded:
		return
	_cli_loaded = true
	for args in [OS.get_cmdline_args(), OS.get_cmdline_user_args()]:
		for arg in args:
			if String(arg).begins_with("--tune="):
				_cli.merge(parse(String(arg).trim_prefix("--tune=")), true)


static func _unruled() -> bool:
	return "--tune-unruled" in OS.get_cmdline_args() or "--tune-unruled" in OS.get_cmdline_user_args()


static func _number(raw: String) -> bool:
	return raw.is_valid_float() and float(raw) >= 0.0


static func _valid(key: String, raw: String) -> bool:
	if key.ends_with("_by_phase"):
		var parts := raw.split("/", true)
		for part in parts:
			if not _number(part):
				return false
		return not parts.is_empty()
	return _number(raw)


static func _reject(key: String, why: String) -> void:
	var id := key + why
	if _warned.has(id):
		return
	_warned[id] = true
	push_error("challenge_dials: dial '%s' ignored: %s" % [key, why])


static func _coerce(key: String, raw: Variant) -> Variant:
	if key.ends_with("_by_phase"):
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
	if _warned.has(key):
		return
	_warned[key] = true
	push_error("challenge_dials: unknown dial '%s' ignored" % key)


# --- Readings the game's wire points share ----------------------------------------------

# A hazard's damage to the pilot: boss is "brindle", "waking" or "mind". phase counts from 1.
static func damage(boss: String, base: float, phase: int) -> float:
	return base * f(boss + ".damage_mult") * by_phase(boss + ".damage_by_phase", phase)


# A boss attack period (seconds) or rest, scaled; never under the warning gap.
static func period(boss: String, base: float, phase: int) -> float:
	return maxf(WARN_GAP, base * f(boss + ".period_mult") * by_phase(boss + ".period_by_phase", phase))


# A boss warn seconds, scaled by tell_mult but never under min(seconds, floor), where floor is
# the larger of TELL_FLOOR and the module's own floor (Hazard.MIN_WARN, the Mind's WARN_FLOOR),
# so the number is what the committed hazard shows. Identity at tell_mult 1.
static func tell(boss: String, seconds: float, module_floor := 0.0) -> float:
	return floored(seconds, f(boss + ".tell_mult"), module_floor)


static func floored(seconds: float, mult: float, module_floor := 0.0) -> float:
	var floor_s := maxf(TELL_FLOOR, module_floor)
	return maxf(minf(seconds, floor_s), seconds * mult)


# A punish window (seconds).
static func punish(boss: String, base: float) -> float:
	return base * f(boss + ".punish_mult")


# Extra follow-up attacks queued right after an attack.
static func combo(boss: String) -> int:
	return maxi(0, int(round(f(boss + ".combo"))))


# One step of a combo chain. `left` is -1 when the attack just committed leads a chain.
# Returns the follow-ups still owed; the caller schedules WARN_GAP when it is above 0 and the
# normal period (resetting its counter to -1) otherwise.
static func combo_step(boss: String, left: int) -> int:
	return combo(boss) if left < 0 else left - 1


static func by_phase(key: String, phase: int) -> float:
	var a: Array = value(key)
	return float(a[clampi(phase - 1, 0, a.size() - 1)])
