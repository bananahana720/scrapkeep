class_name ChallengeDials
extends RefCounted
# Challenge lane C3a: the named difficulty dials (Andrew's 19 Oct ruling: Souls-like hard but
# fair, tuned against measured skill-band win rates). Plumbing first: a dial at its default is
# the identity unless a per-world PR has set a tuned default below, each with a note citing its
# band table. The sweep harness moves numbers through set_overrides() or
# `--tune=key=value,key=value` on the command line, with no code edits. An override or tune
# REPLACES that key's default (it does not multiply it), so `--tune=brindle.period_by_phase=1/1/1/1`
# is the raw identity and the sweeps stay meaningful; the other keys of a boss (`_mult`) still
# multiply on top of the tuned list.
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
# line). Keys ending in `_by_stage` are the same with six entries, one per stage (`a/b/c/d/e/f`),
# so a world is tuned apart from the others (world = ceil(stage / 2)). Static API, no autoload.

# No dial may shorten a boss tell below this (seconds).
const TELL_FLOOR := 0.6
# The warning gap: no two warnings start closer than this (waking_attacks.gd GAP). A combo
# follow-up and a scaled period never come sooner than this after the last attack.
const WARN_GAP := 0.2

const ONES6 := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
const ZEROS6 := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
# Silt boils ship on world 1 at strength 2 (pack pressure E, 24 Oct ruling; DECISIONS section 5).
const SILT_W1 := [2.0, 2.0, 0.0, 0.0, 0.0, 0.0]
# The dam (stage 1) takes mob hits at x1.5 (w19 world 1 bands, Andrew 26 Oct option 1, DECISIONS section 5).
# 24 seeds on w1: Novice wins 33% (a measured miss of the <= 15% target: the dam Warden is world 1's
# teaching Warden), Learner a5 67%, Expert 100% with the same fight time. Hit size, not crew aggression or
# spawn rate: both of those slowed the Expert.
const MOBS_DAMAGE_W1 := [1.5, 1.0, 1.0, 1.0, 1.0, 1.0]
const PackPressure := preload("res://src/combat/pack_pressure.gd")

const DEFAULTS := {
	# Per boss: hazard damage to the pilot, attack cadence, warn seconds, punish windows,
	# and the number of extra follow-up attacks queued right after an attack.
	# Brindle (world 1 boss) is tuned: phases Requisition, Furnace, Scuttle, chase. Band table: sweep
	# tbr-k, 12 seeds, scratch/challenge-tune-tbr-k 2a45b9c2: Novice 0%, Learner a5 100%, Expert 100%,
	# Top 100%, no Learner death under 45 s, largest hit 30% (brindle_slag). Learner a1 100% is reported,
	# not graded (NEEDS 6267672032). Requisition (phase 1) deals no damage, so its damage entry stays 1.0;
	# the tbr-k sweep ran it at 1.5 with the same result.
	"brindle.damage_mult": 1.0, "brindle.damage_by_phase": [1.0, 2.0, 1.3, 1.0],
	"brindle.period_mult": 1.0, "brindle.period_by_phase": [0.6, 0.5, 1.0, 1.0],
	"brindle.tell_mult": 1.0, "brindle.punish_mult": 1.0, "brindle.combo": 0.0,
	# Fight phases (fight_phases.gd, Andrew 23 Oct 19:02Z): cued follow-ups after each lead attack, per
	# phase. Brindle's Furnace answers a slag ring with the other ring, his Scuttle answers a charge with a
	# hook turn; both sound the ratchet cue first. Untuned: no band sweep yet (wave 19 challenge card).
	"brindle.follow_ups_by_phase": [0.0, 1.0, 1.0, 0.0],
	# The transition beat that opens each later phase (FightPhases.TRANSITION_SECONDS x this). Not a
	# stagger or posture timing: it holds the boss between phases, before the next bar fills.
	"brindle.transition_mult": 1.0,
	"waking.damage_mult": 1.0, "waking.damage_by_phase": [1.0, 1.0, 1.0, 1.0],
	"waking.period_mult": 1.0, "waking.period_by_phase": [1.0, 1.0, 1.0, 1.0],
	"waking.tell_mult": 1.0, "waking.punish_mult": 1.0, "waking.combo": 0.0,
	# phase_min_by_phase: a multiplier on the fight's PHASE_MIN_SECONDS (waking.gd, mind.gd; Brindle's
	# pattern), the seconds a phase must last before a chunk lost in it opens the next. Until then the bar
	# fills only to warden.gd HOLD_CAP. One entry per chunk; the last is unused. 0 removes the hold.
	"waking.phase_min_by_phase": [1.0, 1.0, 1.0, 1.0],
	# weak_points (stub_boss.gd, weak_points.gd; #241): 0 = off, the fight without it; 1 = the weak-point rule.
	# Both ship on 0 for wave 18 (#241 6355894644, option b): on 1 the skipper lost the world 2 Waking
	# (bot_posture_boss_test) and the Expert's median stood near 113 s. Tuning dial 1 is a wave 19 card with the Mind's.
	"waking.weak_points": 0.0, "mind.weak_points": 0.0,
	"mind.damage_mult": 1.0, "mind.damage_by_phase": [1.0, 1.0, 1.0, 1.0],
	"mind.period_mult": 1.0, "mind.period_by_phase": [1.0, 1.0, 1.0, 1.0],
	"mind.tell_mult": 1.0, "mind.punish_mult": 1.0, "mind.combo": 0.0,
	"mind.phase_min_by_phase": [1.0, 1.0, 1.0, 1.0],
	# Wardens (warden.gd): the pulse's damage and cycle, the meltdown slag's damage.
	"warden.pulse_damage_mult": 1.0, "warden.pulse_cycle_mult": 1.0, "warden.slag_damage_mult": 1.0,
	"warden.pulse_damage_by_stage": ONES6, "warden.pulse_cycle_by_stage": ONES6, "warden.slag_damage_by_stage": ONES6,
	# The Warden's counter-pulse (warden.gd): a second core ring committed inside a stagger. Damage is an
	# absolute value per stage (0 = off, the default: nothing is built or rolled); the telegraph is floored at
	# TELL_FLOOR; the delay is seconds into the stagger before it starts charging.
	"warden.counter_damage_by_stage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	"warden.counter_telegraph_by_stage": [0.8, 0.8, 0.8, 0.8, 0.8, 0.8],
	"warden.counter_delay_by_stage": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	# Mobs: enemy hits (after director.damage_scale(); Warden and vault sources excluded),
	# the director's crowd cap and spawn interval, and the elite repeat chance. The attack_budget
	# caps and Director.HARD_CAP stay hard ceilings.
	"mobs.damage_mult": 1.0, "mobs.pack_scale_mult": 1.0, "mobs.interval_scale_mult": 1.0, "mobs.elite_rate_mult": 1.0,
	"mobs.damage_by_stage": MOBS_DAMAGE_W1, "mobs.pack_scale_by_stage": ONES6, "mobs.interval_scale_by_stage": ONES6, "mobs.elite_rate_by_stage": ONES6,
	# Pack pressure, the world 1 kiting experiments (combat/pack_pressure.gd; --pack-pressure=A|B|C|D|E presets).
	# Absolute per-stage values, identity at defaults: lead 0 to 1 of the ball's predicted roll that crews steer
	# and aim at; extra chasers per crew; a multiplier on the re-engage gap; 1 makes every second chaser a
	# flanker; churned-silt drag strength (churn_ground.gd); silt boil damage, 0 off (silt_boil.gd).
	"pack.lead_by_stage": ZEROS6, "pack.crew_extra_by_stage": ZEROS6, "pack.rest_by_stage": ONES6,
	"pack.flank_by_stage": ZEROS6, "ground.churn_by_stage": ZEROS6, "hazard.boil_by_stage": SILT_W1,
	# Pilot regen: not allowed as defaults or tunes (--tune-unruled only). The HARD ladder's top rungs cut it
	# (run_tier.gd LADDER, Andrew 27 Oct option 3).
	"pilot.regen_delay_mult": 1.0, "pilot.regen_rate_mult": 1.0,
}

static var _overrides := {}
# The HARD ladder rung's dials (run_tier.gd LADDER), set with the run tier (run_state.gd): each multiplies
# its key's value on top of defaults, overrides and tunes. Empty at the base tier.
static var _rung := {}
static var _cli_loaded := false
static var _cli := {}
static var _warned := {}
# Every refusal's message, in order, for tests to read. With quiet set, a refusal is recorded but not
# printed: only a test that feeds bad input on purpose sets it (an ERROR line fails the test lane).
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


# The rung dials in force (tests read them; a bot record carries run_tier instead).
static func rung() -> Dictionary:
	return _rung


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
		if _is_list(k) and not v is Array:
			_reject(k, "a list dial takes an array, not '%s'" % str(v))
			continue
		var raw: String = "/".join((v as Array).map(func(x): return str(x))) if v is Array else str(v)
		if not _valid(k, raw):
			_reject(k, "'%s' is not a non-negative number" % raw)
			continue
		_overrides[k] = _coerce(k, v)


# Clears overrides and forgets the command line, so the next read parses it again.
static func reset() -> void:
	_overrides = {}
	_rung = {}
	_cli = {}
	_cli_loaded = false
	_warned = {}
	rejected = []
	quiet = false


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
			_reject(k, "'%s' is not a non-negative number" % raw + (" list a/b/c/d" if k.ends_with("_by_phase") else " list a/b/c/d/e/f" if k.ends_with("_by_stage") else ""))
			continue
		out[k] = _coerce(k, raw)
	return out


static func _load_cli() -> void:
	if _cli_loaded:
		return
	_cli_loaded = true
	# A --pack-pressure preset first, so an explicit --tune of the same key wins.
	for args in [OS.get_cmdline_args(), OS.get_cmdline_user_args()]:
		for arg in args:
			if String(arg).begins_with("--pack-pressure="):
				var unknown := []
				_cli.merge(parse(PackPressure.tune_spec(String(arg).trim_prefix("--pack-pressure="), unknown)), true)
				for letter in unknown:
					_refuse("pack-pressure " + letter, "challenge_dials: --pack-pressure variant '%s' ignored (A, B, C, D or E)" % letter)
	for args in [OS.get_cmdline_args(), OS.get_cmdline_user_args()]:
		for arg in args:
			if String(arg).begins_with("--tune="):
				_cli.merge(parse(String(arg).trim_prefix("--tune=")), true)


static func _unruled() -> bool:
	return "--tune-unruled" in OS.get_cmdline_args() or "--tune-unruled" in OS.get_cmdline_user_args()


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


# Records every refusal; prints each distinct one once unless quiet.
static func _refuse(id: String, message: String) -> void:
	rejected.append(message)
	if quiet or _warned.has(id):
		return
	_warned[id] = true
	push_error(message)


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


# One entry of a six-entry per-stage list (stage counts from 1); 1.0 for a stage outside it.
static func by_stage(key: String, stage: int) -> float:
	var a: Array = value(key)
	return float(a[stage - 1]) if stage >= 1 and stage <= a.size() else 1.0


# Like by_stage, but a stage outside the list reads `outside` (an absolute dial, not a multiplier).
static func by_stage_or(key: String, stage: int, outside: float) -> float:
	var a: Array = value(key)
	return float(a[stage - 1]) if stage >= 1 and stage <= a.size() else outside


# A wire point's whole multiplier: the global `<base>_mult` times the stage's `<base>_by_stage`.
# Identity at defaults.
static func stage_mult(base_key: String, stage: int) -> float:
	return f(base_key + "_mult") * by_stage(base_key + "_by_stage", stage)
