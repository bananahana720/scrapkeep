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

static func stage_row(stage: Dictionary, tier: int) -> Dictionary:
	if tier == BASE:
		return stage
	var out := stage.duplicate(true)
	out["run_tier"] = tier
	return out
