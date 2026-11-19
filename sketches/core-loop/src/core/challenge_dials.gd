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
# World 1's Wardens pulse harder (wave 37 unit D6, ruling cu): the core ring hits x1.3 on the dam and the flume,
# and the flume's cycle runs x0.85 (6.0 s to 5.1 s), the HARD ladder's rung 2 values. The ring still charges
# Warden.PULSE_TELEGRAPH seconds, so the tell is no shorter; only the gap between pulses is. The dam keeps the
# 6 s gap (wave 39): at 5.1 s a ball rolling at cruise lost hull faster per second than one stopped (bot_fairness
# F2 stop tax 1.05 pooled over six seeds, line 2.0; 3.71 at 6 s), so speed stopped being safety on the first
# stage. A ladder rung multiplies on top of these.
const PULSE_DAMAGE_W1 := [1.3, 1.3, 1.0, 1.0, 1.0, 1.0]
const PULSE_CYCLE_W1 := [1.0, 0.85, 1.0, 1.0, 1.0, 1.0]
# The Wardens escalate (W1-67, gameplay critique finding 5): each chunk the Warden has lost multiplies its
# pulse cycle by this, so the fight tightens as it goes (5.1 s, 4.59, 4.13, 3.72 on the flume). The tell is
# unchanged; only the rest between pulses shrinks (warden.gd cycle_now). 1.0 is the flat fight of before.
# The dam stays on its flat 6 s (PR 845 moved it back from 5.1: a tighter dam pulse taxed the ball at cruise
# more than the stopped one, bot_fairness_test F2); its escalation is the sheet's one-of-two lanes instead.
const PULSE_RATCHET_W1 := [1.0, 0.9, 1.0, 1.0, 1.0, 1.0]
# Silt boils ship on world 1 at strength 2 (pack pressure E, 24 Oct ruling; DECISIONS section 5).
const SILT_W1 := [2.0, 2.0, 0.0, 0.0, 0.0, 0.0]
# Crews on world 1 lead the ball's roll by half (wave 37 unit D1, ruling cu call 4: chasers lead your line).
# A crew steers to cut the roll off and a chaser lays its lunge lane halfway to where the roll will be, so a
# ball that slows or holds a line it can be met on gets lunged, and a ball at cruise across it still slips.
# The lane is committed at the wind-up as before and the wind-up is no shorter.
const LEAD_W1 := [0.5, 0.5, 0.0, 0.0, 0.0, 0.0]
# The share of that lead a crew keeps on a ball at cruise: none on world 1 (wave 37, the stop-tax line F2). The
# lead is whole below 85% of cruise and gone at cruise (PackPressure.lead_now), so pressure lands on the ball
# that slows and a ball that keeps its speed is aimed at where it is, as before wave 37. 1 keeps it whole.
const LEAD_CRUISE_W1 := [0.0, 0.0, 1.0, 1.0, 1.0, 1.0]
# The dam (stage 1) takes mob hits at x1.5 (w19 world 1 bands, Andrew 26 Oct option 1, DECISIONS section 5).
# 24 seeds on w1: Novice wins 33% (a measured miss of the <= 15% target: the dam Warden is world 1's
# teaching Warden), Learner a5 67%, Expert 100% with the same fight time. Hit size, not crew aggression or
# spawn rate: both of those slowed the Expert.
# Wave 37 (ruling cu, unit D5's payment): x2. With the boils on the stall test the dam eased for the Novice
# (8 wins of 12 against the base's 4); at x2 with all seven units it reads 3 of 12, 7 deaths, 1.72 hits a
# second before armour against the base's 1.47 and the same hull lost a run (178). Hit size again, for the
# reason above. A stalled ball's boil now hits 40 (10 x strength 2 x 2).
const MOBS_DAMAGE_W1 := [2.0, 1.0, 1.0, 1.0, 1.0, 1.0]
# Chasers on world 1 run at 9 m/s, up from 4.8 (wave 37 unit D2, ruling cu call 4: faster than walking pace,
# slower than cruise). A ball that stops or dawdles is run down; a ball at cruise (14 m/s) is never caught by
# running. The lunge, its lane and its wind-up are as they were.
const CHASER_SPEED_W1 := [9.0, 9.0, 0.0, 0.0, 0.0, 0.0]
# The flume's crowd comes sooner (W1-31, gameplay critique section 6): the director's spawn interval x0.7 on stage 2, so the
# opening carries packs instead of a walk. Interval, not hit size: it asks the ball to keep moving and no warning, shape
# or damage changes. The dam keeps its own pace.
const INTERVAL_W1 := [1.0, 0.7, 1.0, 1.0, 1.0, 1.0]
const PackPressure := preload("res://src/combat/pack_pressure.gd")

const DEFAULTS := {
	# Per boss: hazard damage to the pilot, attack cadence, warn seconds, punish windows,
	# and the number of extra follow-up attacks queued right after an attack.
	# Brindle (world 1 boss): phases Requisition, Furnace, Scuttle, chase. Requisition (phase 1) deals no damage,
	# so its damage entry stays 1.0. The band sweep tbr-k (12 seeds, 2a45b9c2) was read at the old 2.0 and 1.3 hit
	# sizes and the 0.5 and 1.0 periods; nobody has swept the values below.
	# Wave 37 (ruling cu; systems audit pass E, change 5): world 1 kept getting easier after the dam, so Brindle's
	# Furnace slag hits x3 (36) on a 0.35 gap and his Scuttle charge x2 (36) on half the rest. One hit is 36, about
	# 30% of a 120 hull, and the fight asks for more dodges, not one-shot luck. Eight random-policy runs a side
	# (seeds 2860 to 2867, PR 787): the worst minute at Brindle took a median 40% of max hull before and 71% after,
	# against 76% to 79% at the dam Warden. Every run that reached Brindle cleared it.
	"brindle.damage_mult": 1.0, "brindle.damage_by_phase": [1.0, 3.0, 2.0, 1.0],
	"brindle.period_mult": 1.0, "brindle.period_by_phase": [0.6, 0.35, 0.5, 1.0],
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
	# Wave 37 unit D4, ruling cu call 2: terrain stops enemy shells, and lobbers lead more of them. shell_cover is 1
	# where a lobber shell bursts on the first terrain or landform it meets (0 = it flies through, the game before
	# this unit); lobber_lead is the share of the ball's FLIGHT travel a lobber aims ahead (0.5 is Lobber.LEAD);
	# lobber_share_step is the lobber share added per effective clock tier. It ships at the old step, 0.07, on every
	# stage: at 0.12 the dam's Novice runs replayed tick for tick (12 seeds, wave 37 screen s4), because the dam's
	# packs are authored and never read the share, and the flume was not read.
	"hazard.shell_cover_by_stage": [1.0, 1.0, 0.0, 0.0, 0.0, 0.0],
	"mobs.lobber_lead_by_stage": [0.75, 0.75, 0.5, 0.5, 0.5, 0.5],
	"mobs.lobber_share_step_by_stage": [0.07, 0.07, 0.07, 0.07, 0.07, 0.07],
	# Wardens (warden.gd): the pulse's damage and cycle, the meltdown slag's damage.
	"warden.pulse_damage_mult": 1.0, "warden.pulse_cycle_mult": 1.0, "warden.slag_damage_mult": 1.0,
	"warden.pulse_damage_by_stage": PULSE_DAMAGE_W1, "warden.pulse_cycle_by_stage": PULSE_CYCLE_W1, "warden.slag_damage_by_stage": ONES6,
	"warden.pulse_ratchet_by_stage": PULSE_RATCHET_W1,
	# The Warden's counter-pulse (warden.gd): a second core ring committed inside a stagger. Damage is an
	# absolute value per stage (0 = off, the default: nothing is built or rolled); the telegraph is floored at
	# TELL_FLOOR; the delay is seconds into the stagger before it starts charging.
	"warden.counter_damage_by_stage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	"warden.counter_telegraph_by_stage": [0.8, 0.8, 0.8, 0.8, 0.8, 0.8],
	"warden.counter_delay_by_stage": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	# The difficulty clock's last tier per stage (director.gd clock_tiers, build/run_clock.gd tiers): the clock
	# rises one tier each Director.TIER_SECONDS up to this count. World 1 climbs a third tier, at 135 s (wave 37
	# unit D3, ruling cu): staying longer means a bigger crowd, shorter gaps and more lobbers. Every rise is
	# announced (threat_rose), as the first two are. Later worlds keep two.
	"mobs.clock_tiers_by_stage": [3.0, 3.0, 2.0, 2.0, 2.0, 2.0],
	# Mobs: enemy hits (after director.damage_scale(); Warden and vault sources excluded),
	# the director's crowd cap and spawn interval, and the elite repeat chance. The attack_budget
	# caps and Director.HARD_CAP stay hard ceilings.
	"mobs.damage_mult": 1.0, "mobs.pack_scale_mult": 1.0, "mobs.interval_scale_mult": 1.0, "mobs.elite_rate_mult": 1.0,
	"mobs.damage_by_stage": MOBS_DAMAGE_W1, "mobs.pack_scale_by_stage": ONES6, "mobs.interval_scale_by_stage": INTERVAL_W1, "mobs.elite_rate_by_stage": ONES6,
	# A chaser's run speed in m/s per stage (chaser.gd stage_speed): 0 keeps the chaser's own SPEED, a value
	# can only raise it, and it is held under Chaser.SPEED_CEILING, below the ball's cruise.
	"mobs.chaser_speed_by_stage": CHASER_SPEED_W1,
	# Pack pressure, the world 1 kiting experiments (combat/pack_pressure.gd; --pack-pressure=A|B|C|D|E presets).
	# Absolute per-stage values, identity at defaults but the lead and the boils: lead 0 to 1 of the ball's
	# predicted roll that crews steer and aim at (LEAD_W1) and the share of it kept at cruise (LEAD_CRUISE_W1);
	# extra chasers per crew; a multiplier on the re-engage
	# gap; 1 makes every second chaser a flanker; churned-silt drag strength (churn_ground.gd); silt boil damage,
	# 0 off (silt_boil.gd).
	"pack.lead_by_stage": LEAD_W1, "pack.lead_cruise_by_stage": LEAD_CRUISE_W1, "pack.crew_extra_by_stage": ZEROS6, "pack.rest_by_stage": ONES6,
	"pack.flank_by_stage": ZEROS6, "ground.churn_by_stage": ZEROS6, "hazard.boil_by_stage": SILT_W1,
	# What the silt boils under (silt_boil.gd): 1 = a ball that stalls in a fight (it stops, crawls or holds a
	# tight orbit), 0 = the loop test they shipped with on 24 Oct, which also boils a wide kite round a pack and
	# never a ball that stood still. World 1 ships the stall test (wave 37 unit D5, ruling cu call 3). On its own
	# it eased the Novice on the dam (12 seeds: 8 wins against 4), so it ships with the dam's mob hits at x2
	# (MOBS_DAMAGE_W1), read together: 3 wins of 12, and the Expert's kite no longer boils at cruise.
	"hazard.boil_stall_by_stage": [1.0, 1.0, 0.0, 0.0, 0.0, 0.0],
	"hazard.hits_enemies_by_stage": [1.0, 1.0, 0.0, 0.0, 0.0, 0.0],
	# Pilot regen: not allowed as defaults or tunes (--tune-unruled only). The HARD ladder's top rungs cut it
	# (run_tier.gd LADDER, Andrew 27 Oct option 3).
	"pilot.regen_delay_mult": 1.0, "pilot.regen_rate_mult": 1.0,
	# Hull regenerates only while the ball rolls in the cruise speed tier or above (run_state.gd advance; wave 37
	# unit D7, ruling cu call 1: motion heals, camping does not). 1 on, 0 = the hull regenerates at any speed,
	# the game before this unit. World 1 ships it on; later worlds stay off until their bands are read. Ruled, so
	# unlike the two multipliers above it is a plain tune (RULED_PILOT).
	"pilot.regen_rolling_by_stage": [1.0, 1.0, 0.0, 0.0, 0.0, 0.0],
}

# Pilot dials a ruling covers: tunable without --tune-unruled.
const RULED_PILOT := ["pilot.regen_rolling_by_stage"]

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
		if k.begins_with("pilot.") and not k in RULED_PILOT and not _unruled():
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
