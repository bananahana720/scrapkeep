extends RefCounted

const Worlds := preload("res://src/core/worlds.gd")

# The alpha table: three worlds of two zones each, every zone ending at a posture-fight
# Warden, then Brindle as the boss. World one is the Spillway (1-1) then the Cable Reach (1-2);
# stages 3 and 5 are the first zones of worlds two and three (the Dig, the Highdraft) and stages 4
# and 6 their second zones (the deep works, the crown), each with its own map, packs drawn from
# its world's kinds, and Warden variant key. The default table:
# stage_defs.gd re-exports these rows, and `--table=alpha` picks this file directly.
# Same shape as slice_defs.gd. It repeats that file's two lookups because a base script's
# static functions would read the base's own DEFS, not this one's. Rows 3 to 6 scale rows 1
# and 2's numbers as a starting point. Like the slice it has no timed events and no vault, and its
# enemies arrive as the authored packs below, drawn by the director instead of its
# clock, its build tilt and its unlock rules.

const BOSS := "brindle"

const COUNT := 6

# The named synergies this table keeps. Any other synergy and every unnamed tag rule is out.
const SYNERGIES := ["wrecking_ball", "tesla_pylon", "pinwheel", "shrapnel_bloom", "lightning_rod"]

# The twelve parts every source on this table offers, and the only ones. The five shown
# parts of the kept synergies, one carrier of each hidden tag they need (kinetic, speed, mass;
# arc comes from arc_coil, and the class mods carry it for the pylon pilot), the two class
# mods, and three heavy hitters so the shelf has a rare tier. A synergy completes from this
# list for every pilot (tests/slice_parts_test.gd). Generated recipes and milestone parts are out.
const PARTS := [
	"double_feed", "focus_lens", "spiral_wave", "cross_split", "arc_coil",
	"hot_rivets", "loose_trigger", "rivet_plating",
	"pylon_capacitor", "runner_overclock",
	"sunforged_core", "gatling_heart",
]

# A rise to a heft class the run has not been rewarded for opens one upgrade tree pick.
const PICK_ON_CLASS_UP := true

const PACKS := [
	{"id": "run_down", "kinds": ["chaser", "chaser", "chaser", "lobber"]},
	{"id": "grounded", "kinds": ["mag_trapper", "lobber", "lobber"]},
	{"id": "rebound", "kinds": ["deflector", "chaser", "chaser"]},
]
const ELITE := {"id": "elite", "kinds": ["plated_brute", "winch_drone"]}
# The arrival of each stage that is the elite pack.
const ELITE_ARRIVAL := 3

# The run's pressure curve (GP3), one row per stage, each key a multiplier on a constant that
# stays where it lives: pack_scale on the director's crowd cap and pack share (PACK_MAX stays
# the ceiling), interval_scale on its spawn interval, elite_rate on its elite repeat chance,
# posture_curve on the Warden's posture exponent (the row's "posture" below reads it), and
# boss_phase_scale on the world boss's attack pace. Pack density and elite rate climb every
# stage from the Spillway to the crown; Breath hard multiplies on top (director.gd BREATH).
const POSTURE_CURVE := 2.0
const PRESSURE := [
	{"pack_scale": 1.10, "interval_scale": 0.95, "elite_rate": 0.60, "posture_curve": 1.00, "boss_phase_scale": 1.00},
	{"pack_scale": 1.15, "interval_scale": 0.92, "elite_rate": 0.80, "posture_curve": 1.00, "boss_phase_scale": 1.10},
	{"pack_scale": 1.20, "interval_scale": 0.90, "elite_rate": 1.00, "posture_curve": 1.05, "boss_phase_scale": 1.15},
	{"pack_scale": 1.25, "interval_scale": 0.88, "elite_rate": 1.20, "posture_curve": 1.05, "boss_phase_scale": 1.20},
	{"pack_scale": 1.30, "interval_scale": 0.85, "elite_rate": 1.40, "posture_curve": 1.10, "boss_phase_scale": 1.25},
	{"pack_scale": 1.40, "interval_scale": 0.80, "elite_rate": 1.60, "posture_curve": 1.10, "boss_phase_scale": 1.30},
]

const DEFS := [
	{"stage": 1, "world": 1, "music": {"theme": 0, "ace": "spillway"}, "warden_family": "reactor", "name": "Spillway: the top shelf", "map": "spillway", "threat": 1.0,
		"unlock_base": 2, "ancient": "reactor_relic",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 90.0, "warden_hp": 650.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[0]["posture_curve"], "ram_shatters": false}, "pressure": PRESSURE[0], "warden_hint": "Break its guard, then smash the core.",
		"packs": PACKS, "elite": ELITE, "warden_variant": ""},
	{"stage": 2, "world": 1, "music": {"theme": 1, "ace": "cable_reach"}, "warden_family": "swarm", "name": "The Cable Reach", "map": "reach", "threat": 1.0,
		"unlock_base": 4, "ancient": "swarm_remnant",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 110.0, "warden_hp": 800.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[1]["posture_curve"], "ram_shatters": false}, "pressure": PRESSURE[1], "warden_hint": "Bowl through its guard rack, then smash the core.",
		"packs": PACKS, "elite": ELITE, "warden_variant": ""},
	{"stage": 3, "world": 2, "music": {"theme": 1, "ace": "dig_upper"}, "warden_family": "reactor", "name": "Dig: the upper bench", "map": "dig", "threat": 1.1,
		"unlock_base": 2, "ancient": "reactor_relic",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.5, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 130.0, "warden_hp": 950.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[2]["posture_curve"], "ram_shatters": false}, "pressure": PRESSURE[2], "warden_hint": "Break its guard, then smash the core.",
		"packs": [
			{"id": "dig_shallow", "kinds": ["burrower", "burrower", "lamp_swarm"]},
			{"id": "dig_bore", "kinds": ["drill_crew", "burrower"]},
			{"id": "dig_lamps", "kinds": ["lamp_swarm", "lamp_swarm", "drill_crew"]},
		], "elite": ELITE, "warden_variant": "meltdown"},
	{"stage": 4, "world": 2, "music": {"theme": 1, "ace": "dig_deep"}, "warden_family": "swarm", "name": "Dig: the deep works", "map": "dig_deep", "threat": 1.2,
		"unlock_base": 4, "ancient": "swarm_remnant",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.5, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 150.0, "warden_hp": 1100.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[3]["posture_curve"], "ram_shatters": false}, "pressure": PRESSURE[3], "warden_hint": "Bowl through its guard rack, then smash the core.",
		"packs": [
			{"id": "deep_bore", "kinds": ["drill_crew", "burrower", "burrower"]},
			{"id": "deep_lamps", "kinds": ["lamp_swarm", "lamp_swarm", "burrower"]},
			{"id": "deep_crew", "kinds": ["drill_crew", "drill_crew", "lamp_swarm"]},
		], "elite": ELITE, "warden_variant": "brood"},
	{"stage": 5, "world": 3, "music": {"theme": 2, "ace": "highdraft"}, "warden_family": "mind", "name": "Highdraft", "map": "highdraft", "threat": 1.3,
		"unlock_base": 2, "ancient": "mind_hand",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 5.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 170.0, "warden_hp": 1250.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[4]["posture_curve"], "ram_shatters": false}, "pressure": PRESSURE[4], "warden_hint": "Break its guard, then smash the core.",
		"packs": [
			{"id": "draft_cut", "kinds": ["line_cutter", "line_cutter", "kite_drone"]},
			{"id": "draft_anchor", "kinds": ["anchor_crew", "line_cutter"]},
			{"id": "draft_kites", "kinds": ["kite_drone", "kite_drone", "anchor_crew"]},
		], "elite": ELITE, "warden_variant": "choir"},
	{"stage": 6, "world": 3, "music": {"theme": 2, "ace": "highdraft_crown"}, "warden_family": "mind", "name": "Highdraft: the crown", "map": "highdraft_crown", "threat": 1.4,
		"unlock_base": 4, "ancient": "mind_hand",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 5.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 190.0, "warden_hp": 1400.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[5]["posture_curve"], "ram_shatters": false}, "pressure": PRESSURE[5], "warden_hint": "Break its guard, then smash the core.",
		"packs": [
			{"id": "crown_cut", "kinds": ["line_cutter", "kite_drone", "kite_drone"]},
			{"id": "crown_anchor", "kinds": ["anchor_crew", "anchor_crew", "line_cutter"]},
			{"id": "crown_kites", "kinds": ["kite_drone", "kite_drone", "line_cutter", "anchor_crew"]},
		], "elite": ELITE, "warden_variant": "choir"},
]


static func of(stage: int) -> Dictionary:
	return DEFS[clampi(stage, 1, COUNT) - 1]


static func is_last(stage: int) -> bool:
	return stage >= COUNT


# World helpers (worlds.gd): which world a stage belongs to and where it ends.
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


# True when part_in_play restricts what sources offer (the pool, the generated share and
# the shop's fallback all read it).
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
