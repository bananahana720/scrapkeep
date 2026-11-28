extends "res://tests/doubles/stage_table_base.gd"

const COUNT := 1

const DEFS := [
	{"stage": 1, "world": 3, "music": {"theme": 0, "ace": ""}, "warden_family": "mind", "name": "Highdraft", "map": "highdraft", "threat": 1.0, "unlock_base": 2, "ancient": "reactor_relic",
		"event_mix": {}, "scrap_density": 1.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 45.0, "warden_hp": 800.0, "warden_lesson": "", "warden_hint": "Break its guard, then smash the core."},
]


static func of(stage: int) -> Dictionary:
	return of_defs(DEFS, stage)


static func is_last(stage: int) -> bool:
	return stage >= COUNT


static func world_of(stage: int) -> int:
	return StageTable.world_of(DEFS, stage)


static func local(stage: int) -> int:
	return StageTable.local(DEFS, stage)


static func first_of(world: int) -> int:
	return StageTable.first_of(DEFS, world)


static func last_of(world: int) -> int:
	return StageTable.last_of(DEFS, world)


static func worlds() -> Array:
	return StageTable.worlds(DEFS)


static func is_world_last(stage: int) -> bool:
	return StageTable.is_world_last(DEFS, stage)


static func is_run_last(stage: int) -> bool:
	return StageTable.is_last(DEFS, stage)
