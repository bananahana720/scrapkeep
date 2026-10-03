extends RefCounted

# A six-stage table, two worlds of three, on the three existing maps, so a two-world run
# can be driven before world two exists. Same statics as stage_defs.gd.

const Worlds := preload("res://src/core/worlds.gd")

const BOSS := "brindle"

const COUNT := 6

const DEFS := [
	{"stage": 1, "world": 1, "music": {"theme": 0, "ace": "spillway"}, "warden_family": "reactor", "name": "Spillway: the top shelf", "map": "spillway", "threat": 1.0, "unlock_base": 2, "ancient": "reactor_relic",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 45.0, "warden_hp": 800.0, "warden_lesson": "plate", "warden_hint": "Ram it hard, right after it vents."},
	{"stage": 2, "world": 1, "music": {"theme": 1, "ace": ""}, "warden_family": "swarm", "name": "The Cable Reach", "map": "gorge", "threat": 1.25, "unlock_base": 4, "ancient": "swarm_remnant",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.2, "beacon_seconds": 30.0, "beacon_radius": 30.0,
		"warden_plating": 80.0, "warden_hp": 2200.0, "warden_lesson": "caps", "warden_hint": "Bowl through its guard rack and slam its caps."},
	{"stage": 3, "world": 1, "music": {"theme": 2, "ace": ""}, "warden_family": "mind", "name": "The Weir", "map": "weir", "threat": 2.1, "unlock_base": 6, "ancient": "mind_hand",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.4, "beacon_seconds": 35.0, "beacon_radius": 28.0,
		"warden_plating": 140.0, "warden_hp": 7500.0, "warden_lesson": "magnet", "warden_hint": "In its ring, shoot the magnet while it pulls you."},
	{"stage": 4, "world": 2, "music": {"theme": 0, "ace": "spillway"}, "warden_family": "reactor", "name": "Double: the top shelf", "map": "spillway", "threat": 2.4, "unlock_base": 3, "ancient": "mind_hand",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.4, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 140.0, "warden_hp": 7500.0, "warden_lesson": "plate", "warden_hint": "Ram it hard, right after it vents."},
	{"stage": 5, "world": 2, "music": {"theme": 1, "ace": ""}, "warden_family": "swarm", "name": "Double: the Cable Reach", "map": "gorge", "threat": 2.7, "unlock_base": 5, "ancient": "reactor_relic",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.5, "beacon_seconds": 30.0, "beacon_radius": 30.0,
		"warden_plating": 160.0, "warden_hp": 8500.0, "warden_lesson": "caps", "warden_hint": "Bowl through its guard rack and slam its caps."},
	{"stage": 6, "world": 2, "music": {"theme": 2, "ace": ""}, "warden_family": "mind", "name": "Double: the Weir", "map": "weir", "threat": 3.0, "unlock_base": 7, "ancient": "swarm_remnant",
		"event_mix": {"flood": 1.0}, "scrap_density": 1.6, "beacon_seconds": 35.0, "beacon_radius": 28.0,
		"warden_plating": 180.0, "warden_hp": 9500.0, "warden_lesson": "magnet", "warden_hint": "In its ring, shoot the magnet while it pulls you."},
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
	return []


static func elite() -> Dictionary:
	return {}


static func elite_arrival() -> int:
	return 0


static func has_vault() -> bool:
	return true
