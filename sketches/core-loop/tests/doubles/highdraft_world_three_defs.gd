extends RefCounted

# A one-stage Highdraft table in world 3 (ring-outs on), without timed events. Same statics as stage_defs.gd.

const Worlds := preload("res://src/core/worlds.gd")

const BOSS := "brindle"

const COUNT := 1

const PACKS := [{"id": "table_lobbers", "kinds": ["lobber"]}]

const DEFS := [
	{"stage": 1, "world": 3, "music": {"theme": 0, "ace": ""}, "warden_family": "mind", "name": "Highdraft", "map": "highdraft", "threat": 1.0, "unlock_base": 2, "ancient": "reactor_relic",
		"event_mix": {}, "scrap_density": 1.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 45.0, "warden_hp": 800.0, "warden_lesson": "", "warden_hint": "Break its guard, then smash the core."},
]


static func of(stage: int) -> Dictionary:
	return DEFS[clampi(stage, 1, COUNT) - 1]


static func is_last(stage: int) -> bool:
	return stage >= COUNT


static func world_of(stage: int) -> int:
	return Worlds.world_of(DEFS, stage)


static func local(stage: int) -> int:
	return Worlds.local(DEFS, stage)


static func first_of(world: int) -> int:
	return Worlds.first_of(DEFS, world)


static func last_of(world: int) -> int:
	return Worlds.last_of(DEFS, world)


static func worlds() -> Array:
	return Worlds.worlds(DEFS)


static func is_world_last(stage: int) -> bool:
	return Worlds.is_world_last(DEFS, stage)


static func is_run_last(stage: int) -> bool:
	return Worlds.is_run_last(DEFS, stage)


static func synergy_in_play(_synergy_id: String) -> bool:
	return true


static func part_in_play(_part_id: String) -> bool:
	return true


static func parts_listed() -> bool:
	return false


const PICK_ON_CLASS_UP := false


static func packs() -> Array:
	return PACKS


static func elite() -> Dictionary:
	return {"id": "table_elite", "kinds": ["lobber", "lobber"]}


static func elite_arrival() -> int:
	return 3


static func has_vault() -> bool:
	return true
