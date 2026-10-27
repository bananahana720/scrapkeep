extends RefCounted

const Cards := preload("res://src/world/director_cards.gd")
const PAY_GAIN_CAP := 1.5
const DAMAGE_DIAL_CAP := 1.3
const REST_DIAL_FLOOR := 0.75
const BASE := 0
const HARD := 1
# The highest tier a run can pick (the HARD ladder's top rung). scripts/challenge/lib.mjs MAX_RUN_TIER mirrors it.
const TOP := 5
# The HARD ladder (Andrew 27 Oct, option 3; DECISIONS section 5): tiers 1 to TOP are its rungs. Rung 1 is the
# old HARD. Each rung's pace and pay live in Cards.RUN_TIERS; these are its attack dials, which multiply on top
# of ChallengeDials (ChallengeDials.set_rung), cumulative up the ladder. Only allowed levers: hit damage,
# attack cadence and pilot regen, which only the top rungs cut. Difficulty never raises enemy health (ruling al).
const LADDER := {
	1: {},
	2: {"mobs.damage_mult": 1.15, "warden.pulse_damage_mult": 1.15, "brindle.damage_mult": 1.1},
	3: {"mobs.damage_mult": 1.25, "warden.pulse_damage_mult": 1.25, "brindle.damage_mult": 1.2, "brindle.period_mult": 0.9,
		"mobs.elite_rate_mult": 1.25},
	4: {"mobs.damage_mult": 1.35, "warden.pulse_damage_mult": 1.35, "brindle.damage_mult": 1.3, "brindle.period_mult": 0.85,
		"mobs.elite_rate_mult": 1.5, "warden.pulse_cycle_mult": 0.9, "pilot.regen_delay_mult": 1.5},
	5: {"mobs.damage_mult": 1.5, "warden.pulse_damage_mult": 1.5, "brindle.damage_mult": 1.4, "brindle.period_mult": 0.8,
		"mobs.elite_rate_mult": 1.75, "warden.pulse_cycle_mult": 0.8, "pilot.regen_delay_mult": 2.0, "pilot.regen_rate_mult": 0.6},
}
const UNLOCK := "first_win"
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


# Rungs above HARD have no unlock yet (the ladder's unlock is the next PR); the bots reach them with --run-tier.
static func unlocked(profile, tier := HARD) -> bool:
	return tier == HARD and profile != null and profile.earned(UNLOCK)

static func row(tier: int) -> Dictionary:
	return Cards.RUN_TIERS[clampi(tier, BASE, TOP)]

static func dials(tier: int) -> Dictionary:
	return LADDER.get(tier, {})

static func threat_text() -> String:
	var hard := row(HARD)
	return "Threat: %d%% more crowd, %d%% shorter intervals" % [roundi((hard.cap_weight - 1.0) * 100.0), roundi((1.0 - hard.interval_weight) * 100.0)]

static func pay_text() -> String:
	return "Pay: %d%% more event cores and rare weight; gain cap %.1fx" % [roundi((row(HARD).event_core_multiplier - 1.0) * 100.0), PAY_GAIN_CAP]

static func stage_row(stage: Dictionary, tier: int) -> Dictionary:
	if tier == BASE:
		return stage
	var out := stage.duplicate(true)
	out["run_tier"] = tier
	return out
