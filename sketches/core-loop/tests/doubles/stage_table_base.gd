extends RefCounted

const Worlds := preload("res://src/core/worlds.gd")

const BOSS := "brindle"
const PICK_ON_CLASS_UP := false
const PACKS := [{"id": "table_lobbers", "kinds": ["lobber"]}]


static func of_defs(defs: Array, stage: int) -> Dictionary:
	return defs[clampi(stage, 1, defs.size()) - 1]


static func synergy_in_play(_synergy_id: String) -> bool:
	return true


static func part_in_play(_part_id: String) -> bool:
	return true


static func parts_listed() -> bool:
	return false


static func packs() -> Array:
	return PACKS


static func elite() -> Dictionary:
	return {"id": "table_elite", "kinds": ["lobber", "lobber"]}


static func elite_arrival() -> int:
	return 3


static func has_vault() -> bool:
	return true
