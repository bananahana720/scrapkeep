extends RefCounted

const StageTable := preload("res://src/core/stage_table.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")


const BOSS := "brindle"

const COUNT := 6

const SYNERGIES := AlphaDefs.SYNERGIES

const PARTS := AlphaDefs.PARTS
const BURDEN_PARTS := AlphaDefs.BURDEN_PARTS
const EARNED_PARTS := ["spare_frame"]

const PICK_ON_CLASS_UP := true

const PACKS := AlphaDefs.PACKS
const ELITE := AlphaDefs.ELITE
const PACKS_DAM := AlphaDefs.PACKS_DAM
const PACKS_FLUME := AlphaDefs.PACKS_FLUME
const ELITE_SPILLWAY := AlphaDefs.ELITE_SPILLWAY
const DIG_ELITE := AlphaDefs.DIG_ELITE
const ELITE_HIGHDRAFT := AlphaDefs.ELITE_HIGHDRAFT
const ELITE_ARRIVAL := AlphaDefs.ELITE_ARRIVAL

const POSTURE_CURVE := AlphaDefs.POSTURE_CURVE
const HIVE_HEAVY_RATIO := AlphaDefs.HIVE_HEAVY_RATIO
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
		"posture": {"curve": POSTURE_CURVE * PRESSURE[4]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55, "drain_rate": 10.5, "ranged_heft_scale": 2.5, "ranged_speed_floor": 0.15, "drain_engaged_pause": true}, "pressure": PRESSURE[4], "warden_hint": "Break its guard, then smash the core.",
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
		"posture": {"curve": POSTURE_CURVE * PRESSURE[5]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55, "drain_rate": 10.5, "ranged_heft_scale": 2.5, "ranged_speed_floor": 0.15, "drain_engaged_pause": true}, "pressure": PRESSURE[5], "warden_hint": "Break its guard, then smash the core.",
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
	return StageTable.of(DEFS, stage)


static func is_last(stage: int) -> bool:
	return StageTable.is_last(DEFS, stage)


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


static func synergy_in_play(synergy_id: String) -> bool:
	return synergy_id in SYNERGIES


static func part_in_play(part_id: String) -> bool:
	return StageTable.part_in_play(part_id, [PARTS, BURDEN_PARTS, EARNED_PARTS])


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
