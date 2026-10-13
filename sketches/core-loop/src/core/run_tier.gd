extends RefCounted

const Cards := preload("res://src/world/director_cards.gd")
const PAY_GAIN_CAP := 1.5
const BASE := 0
const HARD := 1
const UNLOCK := "first_win"

static func unlocked(profile) -> bool:
	return profile != null and profile.earned(UNLOCK)

static func row(tier: int) -> Dictionary:
	return Cards.RUN_TIERS[HARD if tier == HARD else BASE]

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
