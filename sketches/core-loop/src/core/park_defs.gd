extends RefCounted

const Worlds := preload("res://src/core/worlds.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")

# The park table (`--table=park`, PARK.md section 10, unit KD0): the alpha rows with the six park map
# ids (park_dam, park_flume, park_pit, park_sinkhole, park_islands, park_crown) in place of the old
# maps, and the KF0 Warden columns as alpha_defs.gd carries them (one kind per world; stage 2 its
# meltdown variant, stage 4 its brood, stage 6 its choir). Edits to these rows are the coordinator's
# (through KD7, which deletes this file once alpha_defs.gd names the park maps). Terrain builds a
# park id from its park file (terrain.gd) and falls back to the stage's old map until that stage's
# park file lands.

# Same shape as slice_defs.gd. It repeats that file's two lookups because a base script's
# static functions would read the base's own DEFS, not this one's. Rows 3 to 6 scale rows 1
# and 2's numbers as a starting point. Like the slice it has no timed events and no vault, and its
# enemies arrive as the authored packs below, drawn by the director instead of its
# clock, its build tilt and its unlock rules.

const BOSS := "brindle"

const COUNT := 6

# The maker tricks (synergies.gd) this table keeps: shared with AlphaDefs so a default launch
# plays the same 14 tricks as the alpha table (wave 45 B1).
const SYNERGIES := AlphaDefs.SYNERGIES

# The parts every source on this table offers, and the only ones: the alpha table's 45 (its
# SQ19b kit lean, the five maker sets complete from them, alpha_defs.gd says why each is
# there) and its burden parts, which no pool offers but a pocket's pay can name. This was an
# eighteen-part wave 11 list until 24 Oct (Codex world 1 review, design #2): on it 27 of the
# 45 never dropped and three maker sets could not complete.
const PARTS := AlphaDefs.PARTS
const BURDEN_PARTS := AlphaDefs.BURDEN_PARTS
# Earned parts this table offers beside the alpha list. Spare Frame is the earned save ("No
# free retry", 22 Oct: "a rare earned item ... can save one death"); its rare_plus row is a
# relic, so it drops where a relic does (a source's relic weight, an overcharged gate).
const EARNED_PARTS := ["spare_frame"]

# A rise to a heft class the run has not been rewarded for opens one upgrade tree pick.
const PICK_ON_CLASS_UP := true

# World 1's first two packs, the table's fallback (packs()); stages 1 and 2 name their own below. KF0 2026-10-10: the deflector's `rebound` pack left
# world 1, so harpoon-spam answers enter from world 2 (decisions.tsv, "The deflector's rebound pack
# leaves world 1"; PARK.md section 13 item 2).
const PACKS := [
	{"id": "run_down", "kinds": ["chaser", "chaser", "chaser", "lobber"]},
	{"id": "grounded", "kinds": ["mag_trapper", "lobber", "lobber"]},
]
const ELITE := {"id": "elite", "kinds": ["plated_brute", "winch_drone"]}
# The Spillway's own roster (design-v3/SPILLWAY-ROSTER.md, wave 19): five packs on the dam and
# six on the flume, each Flow lesson taught on the dam and remixed harder on the flume. Speed is
# the answer the world teaches: the jolt layer's mat misses a fast ball, the hooker's tether
# snaps on speed, a boost or a bite on another post, and a sluice flap launches a fast ball.
const PACKS_DAM := [
	{"id": "run_down", "kinds": ["chaser", "chaser", "chaser", "lobber"]},
	{"id": "grounded", "kinds": ["mag_trapper", "lobber", "lobber"]},
	{"id": "live_wire", "kinds": ["jolt_layer", "chaser", "chaser"]},
	{"id": "sluice_line", "kinds": ["hooker", "chaser", "lobber"]},
	{"id": "flap_run", "kinds": ["ramp_flipper", "boom_tender", "chaser"]},
]
# The flume: two mats to thread at speed, a tether in front of the brute's slam, two flaps under
# a lobber's shells, and the Foreman's shift crew.
const PACKS_FLUME := [
	{"id": "run_down", "kinds": ["chaser", "chaser", "chaser", "lobber"]},
	{"id": "grounded", "kinds": ["mag_trapper", "lobber", "lobber"]},
	{"id": "shift_crew", "kinds": ["foreman", "plated_brute", "chaser", "chaser"]},
	{"id": "crossed_wires", "kinds": ["jolt_layer", "jolt_layer", "boom_tender"]},
	{"id": "weir_strung", "kinds": ["dispatcher", "hooker", "chaser"]},
	{"id": "flap_line", "kinds": ["ramp_flipper", "ramp_flipper", "lobber"]},
]
# The Spillway's own elite on stages 1 and 2: the tether drags you back into the live mat while
# the brute's slab comes down. Speed snaps the line and slips the mat in one move.
const ELITE_SPILLWAY := {"id": "elite", "kinds": ["hooker", "jolt_layer", "plated_brute"]}
# The Dig's own elite (design-v3/WORLD-ROSTERS.md): two plated rigs and a jaw, so the floor is
# the danger and the wall the lane. The Foreman joins it once it merges.
const DIG_ELITE := {"id": "dig_elite", "kinds": ["drill_crew", "drill_crew", "pit_jaw"]}
# The Highdraft's own elite on stages 5 and 6 (design-v3/WORLD-ROSTERS.md): a heavy to ring out
# under two kites riding the thermals above it.
const ELITE_HIGHDRAFT := {"id": "elite_highdraft", "kinds": ["ballast_heavy", "kite_drone", "kite_drone"]}
# The arrival of each stage that is the elite pack.
const ELITE_ARRIVAL := 3

# The run's pressure curve (GP3), one row per stage, each key a multiplier on a constant that
# stays where it lives: pack_scale on the director's crowd cap and pack share (PACK_MAX stays
# the ceiling), interval_scale on its spawn interval, elite_rate on its elite repeat chance,
# posture_curve on the Warden's posture exponent (the row's "posture" below reads it), and
# boss_phase_scale on the world boss's attack pace. Pack density and elite rate climb every
# stage from the Spillway to the crown; the default Breath plays them as written and gentle eases
# them (director.gd BREATH).
const POSTURE_CURVE := 2.0
# The stage 3 hive (Andrew's option 1 on the swarm hive card, 23 Oct: grown builds hit it harder,
# ordinary pilots stay at about 75 s): a heavy stagger. In one a ram opened at 0.7x the plating or more,
# a smashing ram takes two chunks (boss_posture.gd heavy_ratio). 24 seeds a side on stage w18: small
# 72.89 s, grown 33.95 s, 2.15x (was 75.69 / 40.67, 1.86x); posture_bands_swarm_test holds it.
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
			# w18 nemesis packs, mirrors alpha_defs.gd.
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
		"posture": {"curve": POSTURE_CURVE * PRESSURE[4]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 10.0, "contact_gain_floor": 0.35, "drain_rate": 0.5}, "pressure": PRESSURE[4], "warden_hint": "Break its guard, then smash the core.",
		"packs": [
			{"id": "draft_cut", "kinds": ["line_cutter", "line_cutter", "kite_drone"]},
			{"id": "draft_anchor", "kinds": ["ballast_heavy", "line_cutter"]},
			{"id": "draft_kites", "kinds": ["kite_drone", "kite_drone", "gap_net"]},
			{"id": "draft_plate", "kinds": ["foreman", "plated_brute", "catch_trap"]},
			{"id": "draft_dispatch", "kinds": ["dispatcher", "gap_net", "ballast_heavy"]},
			# w18: presses the plating axis, mirrors alpha_defs.gd.
			{"id": "plate_press_draft", "kinds": ["plated_brute", "swatter"]},
		], "elite": ELITE_HIGHDRAFT, "warden_variant": ""},
	{"stage": 6, "world": 3, "music": {"theme": 2, "ace": "highdraft_crown"}, "warden_family": "mind", "name": "Highdraft, the crown", "map": "park_crown", "threat": 1.4,
		"unlock_base": 4, "ancient": "mind_hand",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 5.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 190.0, "warden_hp": 1400.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[5]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 10.0, "contact_gain_floor": 0.35, "drain_rate": 0.5}, "pressure": PRESSURE[5], "warden_hint": "Break its guard, then smash the core.",
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
	return part_id in PARTS or part_id in BURDEN_PARTS or part_id in EARNED_PARTS


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
