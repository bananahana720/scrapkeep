extends RefCounted

const Cards := preload("res://src/world/director_cards.gd")
const ChallengeDials := preload("res://src/core/challenge_dials.gd")
const PAY_GAIN_CAP := 1.5
const DAMAGE_DIAL_CAP := 1.3
const REST_DIAL_FLOOR := 0.75
const BASE := 0
const HARD := 1
# The highest tier a run can pick (the HARD ladder's top rung). scripts/challenge/lib.mjs MAX_RUN_TIER mirrors it.
const TOP := 5
const BANNED_DIAL_SUFFIXES := ["hp_mult", "health_mult", "plating_mult", "posture_max_mult"]
const BOSS_PREFIX_BY_WORLD := {1: "brindle.", 2: "waking.", 3: "mind."}
const ALL_BOSS_PREFIXES := ["brindle.", "waking.", "mind."]
# The HARD ladder (Andrew 27 Oct, option 3; DECISIONS section 5): tiers 1 to TOP are its rungs. Rung 1 is the
# old HARD. Each rung's pace and pay live in Cards.RUN_TIERS; these are its attack dials, which multiply on top
# of ChallengeDials (ChallengeDials.set_rung), cumulative up the ladder. Only allowed levers: hit damage,
# attack cadence, punish windows, the elite repeat rate, the spawn interval and pilot regen, which only the top
# rungs cut. Difficulty never raises enemy health (ruling al).
const LADDER := {
	1: {},
	2: {"mobs.damage_mult": 1.15, "warden.pulse_damage_mult": 1.3, "warden.pulse_cycle_mult": 0.85,
		"brindle.damage_mult": 1.1, "waking.damage_mult": 1.1, "mind.damage_mult": 1.1},
	3: {"mobs.damage_mult": 1.25, "warden.pulse_damage_mult": 1.6, "warden.pulse_cycle_mult": 0.7,
		"brindle.damage_mult": 1.2, "brindle.period_mult": 0.9,
		"waking.damage_mult": 1.2, "waking.period_mult": 0.9,
		"mind.damage_mult": 1.2, "mind.period_mult": 0.9,
		"mobs.elite_rate_mult": 1.25},
	4: {"mobs.damage_mult": 1.35, "warden.pulse_damage_mult": 1.95, "warden.pulse_cycle_mult": 0.58,
		"brindle.damage_mult": 1.3, "brindle.period_mult": 0.85,
		"waking.damage_mult": 1.3, "waking.period_mult": 0.85, "waking.punish_mult": 0.9,
		"mind.damage_mult": 1.3, "mind.period_mult": 0.85, "mind.punish_mult": 0.9,
		"mobs.elite_rate_mult": 1.5, "mobs.interval_scale_mult": 0.95, "pilot.regen_delay_mult": 1.5},
	# Tuned on w1 against Expert ordinary ~50% (ruling aq): the Warden's pulse, not mob hits, is what an Expert
	# cannot dodge forever; mob hits x3, crowd pressure or no regen left it at 88-100% (8 seeds each). It reads
	# 79% on the w20 stage (24 seeds), a recorded miss: below it the losses are fight caps, not deaths.
	5: {"mobs.damage_mult": 1.5, "warden.pulse_damage_mult": 2.25, "warden.pulse_cycle_mult": 0.48,
		"brindle.damage_mult": 1.4, "brindle.period_mult": 0.8,
		"waking.damage_mult": 1.4, "waking.period_mult": 0.8, "waking.punish_mult": 0.85,
		"mind.damage_mult": 1.4, "mind.period_mult": 0.8, "mind.punish_mult": 0.85,
		"mobs.elite_rate_mult": 1.75, "mobs.interval_scale_mult": 0.9, "pilot.regen_delay_mult": 2.0,
		"pilot.regen_rate_mult": 0.6},
}
const UNLOCK := "first_win"
# The highest rung a won run has cleared (profile stat). Beating rung N opens N+1 (Andrew 27 Oct, option 3).
const BEST_STAT := "hard_ladder_best"
# Small existing bonuses; the base id and all metadata remain the same.
const ENHANCED := {
	"loose_trigger": {"mods": {"weapon_rate": 1.15}, "text": "+15% fire rate"},
	"long_barrel": {"mods": {"weapon_range": 1.18}, "text": "+18% weapon range"},
}

static func is_variant_id(id: String) -> bool:
	return id.contains("@tier")

static func effective_part(id: String, base: Dictionary, tier: int) -> Dictionary:
	if tier == BASE or not ENHANCED.has(id):
		return base
	var out := base.duplicate(true)
	var change: Dictionary = ENHANCED[id]
	out["mods"].merge(change.mods, true)
	out["text"] = change.text
	return out


# Rung 1 opens on the first won run; rung N above it once a run on rung N-1 is won.
static func unlocked(profile, tier := HARD) -> bool:
	if profile == null or tier < HARD or tier > TOP or not profile.earned(UNLOCK):
		return false
	return tier == HARD or best_rung(profile) >= tier - 1


static func best_rung(profile) -> int:
	return int(profile.stat(BEST_STAT)) if profile != null else 0


# The highest rung the profile may pick, 0 while HARD is locked.
static func top_unlocked(profile) -> int:
	var top := 0
	while top < TOP and unlocked(profile, top + 1):
		top += 1
	return top


# A won run on a rung above the profile's best raises it. True when it changed.
static func note_win(profile, tier: int) -> bool:
	if profile == null or tier < HARD or tier <= best_rung(profile):
		return false
	profile.set_stat(BEST_STAT, float(mini(tier, TOP)))
	return true

static func row(tier: int) -> Dictionary:
	return Cards.RUN_TIERS[clampi(tier, BASE, TOP)]

static func dials(tier: int) -> Dictionary:
	return LADDER.get(tier, {})


static func dials_for_world(tier: int, world: int) -> Dictionary:
	var keep_prefix := String(BOSS_PREFIX_BY_WORLD.get(world, ""))
	var out := {}
	for key in dials(tier):
		var k := String(key)
		var foreign := false
		for prefix in ALL_BOSS_PREFIXES:
			if k.begins_with(prefix) and prefix != keep_prefix:
				foreign = true
				break
		if not foreign:
			out[k] = dials(tier)[key]
	return out


static func threat_text(tier := HARD, world := 1) -> String:
	var hard := row(tier)
	var words := "Threat: %d%% more crowd, %d%% shorter intervals" % [roundi((hard.cap_weight - 1.0) * 100.0), roundi((1.0 - hard.interval_weight) * 100.0)]
	if hard.has("elite_stats"):
		words += ", plated elite brutes"
	var d := dials_for_world(tier, world)
	if d.has("warden.pulse_damage_mult"):
		words += ", harder hits and Warden pulse"
	var boss_prefix := String(BOSS_PREFIX_BY_WORLD.get(world, "brindle."))
	if world > 1 and d.has(boss_prefix + "punish_mult"):
		words += ", tighter boss openings"
	if d.has("pilot.regen_delay_mult") or d.has("pilot.regen_rate_mult"):
		words += ", slower regen"
	return words

static func pay_text(tier := HARD) -> String:
	return "Pay: %d%% more event cores and rare weight; gain cap %.1fx" % [roundi((row(tier).event_core_multiplier - 1.0) * 100.0), PAY_GAIN_CAP]

# A rung's contract in words, a line each, for the start card to show for the rung being looked at.
static func contract_lines(tier: int, world := 1) -> PackedStringArray:
	if tier <= BASE:
		return PackedStringArray(["The standard shift."])
	return PackedStringArray([threat_text(tier, world), pay_text(tier)])

# What each gauge reads, as a multiple of the base tier. Every dial in LADDER and a row's cap,
# interval and pay are read by one of them, so a rung that turns any of those moves a gauge:
#   Crowd: how many may stand at once over how long the next pack takes to come.
#   Hits: damage times how often it comes, averaged over the three that hit (the mobs with their
#     elite repeat rate, the Warden's pulse, and that world's boss).
#   Regen: the rate over the wait before it starts.
#   Pay: event cores (rare weight steps with it in every row).
# The plating rungs 1 up give their elite plated brutes (combat.gd) is the same on every rung, so it
# is no gauge's; threat_text says it.
static func _readings(tier: int, world := 1) -> Dictionary:
	var d := dials(tier)
	var r := row(tier)
	var mobs := float(d.get("mobs.damage_mult", 1.0)) * float(d.get("mobs.elite_rate_mult", 1.0))
	var pulse := float(d.get("warden.pulse_damage_mult", 1.0)) / float(d.get("warden.pulse_cycle_mult", 1.0))
	var boss_prefix := String(BOSS_PREFIX_BY_WORLD.get(world, "brindle."))
	var boss := float(d.get(boss_prefix + "damage_mult", 1.0)) / float(d.get(boss_prefix + "period_mult", 1.0))
	return {
		"Crowd": float(r.cap_weight) / (float(r.interval_weight) * float(d.get("mobs.interval_scale_mult", 1.0))),
		"Hits": (mobs + pulse + boss) / 3.0,
		"Regen": float(d.get("pilot.regen_rate_mult", 1.0)) / float(d.get("pilot.regen_delay_mult", 1.0)),
		"Pay": float(r.event_core_multiplier),
	}

# A rung's contract as four gauges for the start card (start_pick_card.gd): what the works gains
# (crowd, hits) and what the pilot keeps (regen) or is paid. `fill` and `base` are shares of the gauge's
# length, the top rung's reading being the whole of it: `base` is the base tier's reading, so the length
# past it is what the rung adds and a length short of it is what the rung takes. A gauge is a glance;
# the numbers are contract_lines.
static func meters(tier: int, world := 1) -> Array:
	var now := _readings(tier, world)
	var top := _readings(TOP, world)
	var out := []
	for name in ["Crowd", "Hits", "Regen", "Pay"]:
		var whole := maxf(1.0, float(top[name]))
		out.append({"name": name, "yours": name in ["Regen", "Pay"], "fill": float(now[name]) / whole, "base": 1.0 / whole})
	return out


static func validate(ladder: Dictionary = LADDER) -> Array[String]:
	var problems: Array[String] = []
	var seen_keys := {}
	for tier in range(HARD, TOP + 1):
		if not ladder.has(tier) or not (ladder[tier] is Dictionary):
			problems.append("rung %d: missing dictionary" % tier)
			continue
		var d: Dictionary = ladder[tier]
		for key in d:
			var k := String(key)
			seen_keys[k] = true
			for suffix in BANNED_DIAL_SUFFIXES:
				if k.ends_with(suffix) or k.contains(suffix):
					problems.append("rung %d: banned enemy health/plating dial %s" % [tier, k])
			if not ChallengeDials.DEFAULTS.has(k):
				problems.append("rung %d: dial %s is not in ChallengeDials.DEFAULTS" % [tier, k])
			if not (d[key] is int or d[key] is float) or float(d[key]) <= 0.0:
				problems.append("rung %d: dial %s must be a positive number" % [tier, k])
	for k in seen_keys:
		var up: bool = k.ends_with(".damage_mult") or k.ends_with(".pulse_damage_mult") or k.ends_with(".elite_rate_mult") or k.ends_with(".regen_delay_mult")
		var down: bool = k.ends_with(".period_mult") or k.ends_with(".punish_mult") or k.ends_with(".pulse_cycle_mult") or k.ends_with(".interval_scale_mult") or k.ends_with(".regen_rate_mult")
		if not up and not down:
			continue
		var prev := 1.0
		for tier in range(HARD, TOP + 1):
			if not (ladder.get(tier) is Dictionary):
				continue
			var cur := float(ladder[tier].get(k, 1.0))
			if up and cur < prev - 0.0001:
				problems.append("rung %d: dial %s regressed from %.3f to %.3f" % [tier, k, prev, cur])
			if down and cur > prev + 0.0001:
				problems.append("rung %d: dial %s eased from %.3f to %.3f" % [tier, k, prev, cur])
			prev = cur
	return problems


static func stage_row(stage: Dictionary, tier: int) -> Dictionary:
	if tier == BASE:
		return stage
	var out := stage.duplicate(true)
	out["run_tier"] = tier
	return out
