extends "res://tests/doubles/stage_table_base.gd"

const COUNT := 6

const DEFS := [
	{"stage": 1, "world": 1, "music": {"theme": 0, "ace": "spillway"}, "warden_family": "reactor", "name": "Spillway: the top shelf", "map": "spillway", "threat": 1.0, "unlock_base": 2, "ancient": "reactor_relic",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 45.0, "warden_hp": 800.0, "warden_lesson": "", "warden_hint": "Break its guard, then smash the core."},
	{"stage": 2, "world": 1, "music": {"theme": 1, "ace": ""}, "warden_family": "swarm", "name": "The Cable Reach", "map": "gorge", "threat": 1.25, "unlock_base": 4, "ancient": "swarm_remnant",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.2, "beacon_seconds": 30.0, "beacon_radius": 30.0,
		"warden_plating": 80.0, "warden_hp": 2200.0, "warden_lesson": "", "warden_hint": "Bowl through its guard rack, then smash the core."},
	{"stage": 3, "world": 1, "music": {"theme": 2, "ace": ""}, "warden_family": "mind", "name": "Double: relay approach", "map": "spillway", "threat": 2.1, "unlock_base": 6, "ancient": "mind_hand",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.4, "beacon_seconds": 35.0, "beacon_radius": 28.0,
		"warden_plating": 140.0, "warden_hp": 7500.0, "warden_lesson": "", "warden_hint": "Break its guard, then smash the core."},
	{"stage": 4, "world": 2, "music": {"theme": 0, "ace": "spillway"}, "warden_family": "reactor", "name": "Double: the top shelf", "map": "spillway", "threat": 2.4, "unlock_base": 3, "ancient": "mind_hand",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.4, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 140.0, "warden_hp": 7500.0, "warden_lesson": "", "warden_hint": "Break its guard, then smash the core."},
	{"stage": 5, "world": 2, "music": {"theme": 1, "ace": ""}, "warden_family": "swarm", "name": "Double: the Cable Reach", "map": "gorge", "threat": 2.7, "unlock_base": 5, "ancient": "reactor_relic",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.5, "beacon_seconds": 30.0, "beacon_radius": 30.0,
		"warden_plating": 160.0, "warden_hp": 8500.0, "warden_lesson": "", "warden_hint": "Bowl through its guard rack, then smash the core."},
	{"stage": 6, "world": 2, "music": {"theme": 2, "ace": ""}, "warden_family": "mind", "name": "Double: relay return", "map": "spillway", "threat": 3.0, "unlock_base": 7, "ancient": "swarm_remnant",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.6, "beacon_seconds": 35.0, "beacon_radius": 28.0,
		"warden_plating": 180.0, "warden_hp": 9500.0, "warden_lesson": "", "warden_hint": "Break its guard, then smash the core."},
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


static func packs() -> Array:
	return []


static func elite() -> Dictionary:
	return {}


static func elite_arrival() -> int:
	return 0


const FIRST_WORLD_DEFS := [
	{"stage": 1, "world": 1, "music": {"theme": 0, "ace": "spillway"}, "warden_family": "reactor", "name": "Spillway: the top shelf", "map": "spillway", "threat": 1.0, "unlock_base": 2, "ancient": "reactor_relic",
		"event_mix": {"flood": 1.0, "scrap_stampede": 1.0}, "scrap_density": 1.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 45.0, "warden_hp": 800.0, "warden_lesson": "", "warden_hint": "Break its guard, then smash the core."},
	{"stage": 2, "world": 1, "music": {"theme": 1, "ace": ""}, "warden_family": "swarm", "name": "The Cable Reach", "map": "gorge", "threat": 1.25, "unlock_base": 4, "ancient": "swarm_remnant",
		"event_mix": {"flood": 1.0, "dust_squall": 0.6, "surge_run": 0.8, "cave_in": 1.0, "impact": 1.0}, "scrap_density": 1.2, "beacon_seconds": 30.0, "beacon_radius": 30.0,
		"warden_plating": 80.0, "warden_hp": 2200.0, "warden_lesson": "", "warden_hint": "Bowl through its guard rack, then smash the core."},
	{"stage": 3, "world": 1, "music": {"theme": 2, "ace": ""}, "warden_family": "mind", "name": "Double: relay approach", "map": "spillway", "threat": 2.1, "unlock_base": 6, "ancient": "mind_hand",
		"event_mix": {"flood": 1.0, "dust_squall": 1.0, "surge_run": 1.0, "hold_the_relay": 1.0}, "scrap_density": 1.4, "beacon_seconds": 35.0, "beacon_radius": 28.0,
		"warden_plating": 140.0, "warden_hp": 7500.0, "warden_lesson": "", "warden_hint": "Break its guard, then smash the core."},
]


class FirstWorld extends "res://tests/doubles/stage_table_base.gd":
	const COUNT := 3
	const DEFS := FIRST_WORLD_DEFS

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

	static func packs() -> Array:
		return []

	static func elite() -> Dictionary:
		return {}

	static func elite_arrival() -> int:
		return 0
