extends RefCounted

const Worlds := preload("res://src/core/worlds.gd")


const BOSS := ""

const COUNT := 1

const SYNERGIES := ["wrecking_ball", "tesla_pylon", "pinwheel", "shrapnel_bloom", "lightning_rod",
	"ballast_rig", "shatter_crew", "live_wire", "hair_trigger", "storm_front"]

const PARTS := [
	"double_feed", "hot_rivets", "focus_lens", "live_line", "loose_trigger", "long_barrel",
	"cross_split", "pin_setter", "arc_coil", "drop_weight",
	"sunforged_core", "gatling_heart",
]

const PICK_ON_CLASS_UP := true

const PACKS := [
	{"id": "run_down", "kinds": ["chaser", "chaser", "chaser", "lobber"]},
	{"id": "grounded", "kinds": ["mag_trapper", "lobber", "lobber"]},
	{"id": "rebound", "kinds": ["deflector", "chaser", "chaser"]},
]
const ELITE := {"id": "elite", "kinds": ["plated_brute", "winch_drone"]}
const ELITE_ARRIVAL := 3

const DEFS := [
	{"stage": 1, "world": 1, "music": {"theme": 0, "ace": "spillway"}, "warden_family": "reactor", "name": "The Cable Reach", "map": "reach", "threat": 1.0,
		"unlock_base": 2, "ancient": "reactor_relic",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 110.0, "warden_hp": 800.0, "warden_lesson": "",
		"posture": {"curve": 2.0, "ram_shatters": false, "base": {"ram": 25.0},
			"contact_gain_scale": 4.0 / 7.0, "contact_gain_floor": 0.65}, "pressure": {"elite_rate": 0.0}, "warden_hint": "Break its guard, then smash the core."},
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


static func synergy_in_play(synergy_id: String) -> bool:
	return synergy_id in SYNERGIES


static func part_in_play(part_id: String) -> bool:
	return part_id in PARTS


static func parts_listed() -> bool:
	return true


static func packs() -> Array:
	return PACKS


static func elite() -> Dictionary:
	return ELITE


static func elite_arrival() -> int:
	return ELITE_ARRIVAL


static func has_vault() -> bool:
	return false
