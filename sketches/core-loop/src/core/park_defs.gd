extends RefCounted

const Worlds := preload("res://src/core/worlds.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")


const BOSS := "brindle"

const COUNT := 6

const SYNERGIES := AlphaDefs.SYNERGIES

const PARTS := AlphaDefs.PARTS
const BURDEN_PARTS := AlphaDefs.BURDEN_PARTS
const EARNED_PARTS := ["spare_frame"]

const PICK_ON_CLASS_UP := true

const PACKS := [
	{"id": "run_down", "kinds": ["chaser", "chaser", "chaser", "lobber"]},
	{"id": "grounded", "kinds": ["mag_trapper", "lobber", "lobber"]},
]
const ELITE := {"id": "elite", "kinds": ["plated_brute", "winch_drone"]}
const PACKS_DAM := [
	{"id": "run_down", "kinds": ["chaser", "chaser", "chaser", "lobber"]},
	{"id": "grounded", "kinds": ["mag_trapper", "lobber", "lobber"]},
	{"id": "live_wire", "kinds": ["jolt_layer", "chaser", "chaser"]},
	{"id": "sluice_line", "kinds": ["hooker", "chaser", "lobber"]},
	{"id": "flap_run", "kinds": ["ramp_flipper", "boom_tender", "chaser"]},
]
const PACKS_FLUME := [
	{"id": "run_down", "kinds": ["chaser", "chaser", "chaser", "lobber"]},
	{"id": "grounded", "kinds": ["mag_trapper", "lobber", "lobber"]},
	{"id": "shift_crew", "kinds": ["foreman", "plated_brute", "chaser", "chaser"]},
	{"id": "crossed_wires", "kinds": ["jolt_layer", "jolt_layer", "boom_tender"]},
	{"id": "weir_strung", "kinds": ["dispatcher", "hooker", "chaser"]},
	{"id": "flap_line", "kinds": ["ramp_flipper", "ramp_flipper", "lobber"]},
]
const ELITE_SPILLWAY := {"id": "elite", "kinds": ["hooker", "jolt_layer", "plated_brute"]}
const DIG_ELITE := {"id": "dig_elite", "kinds": ["drill_crew", "drill_crew", "pit_jaw"]}
const ELITE_HIGHDRAFT := {"id": "elite_highdraft", "kinds": ["ballast_heavy", "kite_drone", "kite_drone"]}
const ELITE_ARRIVAL := 3

const POSTURE_CURVE := 2.0
const HIVE_HEAVY_RATIO := 0.7
const PRESSURE := [
	{"pack_scale": 1.03, "interval_scale": 0.95, "elite_rate": 0.60, "posture_curve": 1.00, "boss_phase_scale": 1.00},
	{"pack_scale": 1.04, "interval_scale": 0.92, "elite_rate": 0.80, "posture_curve": 1.00, "boss_phase_scale": 1.10},
	{"pack_scale": 1.20, "interval_scale": 0.90, "elite_rate": 1.00, "posture_curve": 1.05, "boss_phase_scale": 1.15},
	{"pack_scale": 1.25, "interval_scale": 0.88, "elite_rate": 1.20, "posture_curve": 1.05, "boss_phase_scale": 1.20},
	{"pack_scale": 1.30, "interval_scale": 0.85, "elite_rate": 1.40, "posture_curve": 1.10, "boss_phase_scale": 1.25},
	{"pack_scale": 1.40, "interval_scale": 0.80, "elite_rate": 1.60, "posture_curve": 1.10, "boss_phase_scale": 1.30},
]

const DEFS := [
	{"stage": 1, "world": 1, "music": {"theme": 0, "ace": "spillway"}, "warden_family": "reactor", "name": "Spillway, the top shelf", "map": "park_dam", "threat": 1.0,
		"unlock_base": 2, "ancient": "reactor_relic",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 105.0, "warden_hp": 650.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[0]["posture_curve"], "ram_shatters": false}, "pressure": PRESSURE[0], "warden_hint": "Break its guard, then smash the core.",
		"packs": PACKS_DAM, "elite": ELITE_SPILLWAY, "warden_variant": ""},
	{"stage": 2, "world": 1, "music": {"theme": 1, "ace": "cable_reach"}, "warden_family": "reactor", "name": "Spillway, the flume", "map": "park_flume", "threat": 1.0,
		"unlock_base": 4, "ancient": "reactor_relic",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 110.0, "warden_hp": 800.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[1]["posture_curve"], "ram_shatters": false}, "pressure": PRESSURE[1], "warden_hint": "Break its guard, then smash the core.",
		"packs": PACKS_FLUME, "elite": ELITE_SPILLWAY, "warden_variant": "meltdown"},
	{"stage": 3, "world": 2, "music": {"theme": 1, "ace": "dig_upper"}, "warden_family": "swarm", "name": "Dig, the upper bench", "map": "park_pit", "threat": 1.1,
		"unlock_base": 2, "ancient": "swarm_remnant",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.5, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 130.0, "warden_hp": 950.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[2]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55, "heavy_ratio": HIVE_HEAVY_RATIO}, "pressure": PRESSURE[2], "warden_hint": "Bowl through its guard rack, then smash the core.",
		"packs": [
			{"id": "dig_shallow", "kinds": ["burrower", "burrower", "lamp_swarm"]},
			{"id": "dig_bore", "kinds": ["drill_crew", "burrower", "prop_crew"]},
			{"id": "dig_lamps", "kinds": ["lamp_swarm", "lamp_swarm", "drill_crew"]},
			{"id": "dig_shift", "kinds": ["foreman", "drill_crew", "drill_crew", "burrower"]},
			{"id": "dig_jaws", "kinds": ["pit_jaw", "pit_jaw", "burrower"]},
			{"id": "dig_rig", "kinds": ["plated_brute", "catch_trap", "splitter"]},
			{"id": "dig_dispatch", "kinds": ["dispatcher", "lobber", "burrower"]},
		], "elite": DIG_ELITE, "warden_variant": ""},
	{"stage": 4, "world": 2, "music": {"theme": 1, "ace": "dig_deep"}, "warden_family": "swarm", "name": "Dig, the deep works", "map": "park_sinkhole", "threat": 1.2,
		"unlock_base": 4, "ancient": "swarm_remnant",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.5, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 150.0, "warden_hp": 1100.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[3]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55}, "pressure": PRESSURE[3], "warden_hint": "Bowl through its guard rack, then smash the core.",
		"packs": [
			{"id": "deep_bore", "kinds": ["drill_crew", "burrower", "burrower"]},
			{"id": "deep_lamps", "kinds": ["lamp_swarm", "lamp_swarm", "burrower"]},
			{"id": "deep_crew", "kinds": ["drill_crew", "drill_crew", "lamp_swarm", "prop_crew"]},
			{"id": "deep_shift", "kinds": ["foreman", "drill_crew", "drill_crew", "burrower"]},
			{"id": "deep_jaws", "kinds": ["pit_jaw", "pit_jaw", "drill_crew", "burrower"]},
			{"id": "deep_guard", "kinds": ["deflector", "mag_trapper", "dispatcher"]},
			{"id": "deep_haul", "kinds": ["winch_drone", "splitter", "lamp_swarm"]},
		], "elite": DIG_ELITE, "warden_variant": "brood"},
	{"stage": 5, "world": 3, "music": {"theme": 2, "ace": "highdraft"}, "warden_family": "mind", "name": "Highdraft", "map": "park_islands", "threat": 1.3,
		"unlock_base": 2, "ancient": "mind_hand",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 5.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 170.0, "warden_hp": 1250.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[4]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 150.0, "contact_gain_floor": 0.50, "ranged_heft_scale": 2.5, "ranged_speed_floor": 0.15, "drain_engaged_pause": true}, "pressure": PRESSURE[4], "warden_hint": "Break its guard, then smash the core.",
		"packs": [
			{"id": "draft_cut", "kinds": ["line_cutter", "line_cutter", "kite_drone"]},
			{"id": "draft_anchor", "kinds": ["ballast_heavy", "line_cutter"]},
			{"id": "draft_kites", "kinds": ["kite_drone", "kite_drone", "gap_net"]},
			{"id": "draft_plate", "kinds": ["foreman", "plated_brute", "catch_trap"]},
			{"id": "draft_dispatch", "kinds": ["dispatcher", "gap_net", "ballast_heavy"]},
			{"id": "plate_press_draft", "kinds": ["plated_brute", "swatter"]},
		], "elite": ELITE_HIGHDRAFT, "warden_variant": ""},
	{"stage": 6, "world": 3, "music": {"theme": 2, "ace": "highdraft_crown"}, "warden_family": "mind", "name": "Highdraft, the crown", "map": "park_crown", "threat": 1.4,
		"unlock_base": 4, "ancient": "mind_hand",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 5.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 190.0, "warden_hp": 1400.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[5]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 150.0, "contact_gain_floor": 0.50, "ranged_heft_scale": 2.5, "ranged_speed_floor": 0.15, "drain_engaged_pause": true}, "pressure": PRESSURE[5], "warden_hint": "Break its guard, then smash the core.",
		"packs": [
			{"id": "crown_cut", "kinds": ["line_cutter", "kite_drone", "gap_net"]},
			{"id": "crown_anchor", "kinds": ["ballast_heavy", "ballast_heavy", "line_cutter"]},
			{"id": "crown_kites", "kinds": ["kite_drone", "kite_drone", "gap_net", "ballast_heavy"]},
			{"id": "crown_guard", "kinds": ["dispatcher", "deflector", "gap_net"]},
			{"id": "crown_trap", "kinds": ["foreman", "mag_trapper", "mag_trapper", "ballast_heavy"]},
			{"id": "plate_press_crown", "kinds": ["plated_brute", "swatter"]},
		], "elite": ELITE_HIGHDRAFT, "warden_variant": "choir"},
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
	return part_id in PARTS or part_id in BURDEN_PARTS or part_id in EARNED_PARTS


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
