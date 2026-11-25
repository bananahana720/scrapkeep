extends RefCounted

const Worlds := preload("res://src/core/worlds.gd")

# The alpha table: three worlds of two zones each, every zone ending at a posture-fight
# Warden, then Brindle as the boss. World one is the Spillway (1-1) then the Cable Reach (1-2);
# stages 3 and 5 are the first zones of worlds two and three (the Dig, the Highdraft) and stages 4
# and 6 their second zones (the deep works, the crown), each with its own map, packs drawn from
# its world's kinds, and Warden variant key. Each world fights one Warden kind (PARK.md section 7,
# KF0 2026-10-10): world 1 the reactor relic (stage 2 its meltdown variant), world 2 the swarm
# remnant (stage 4 its brood), world 3 the Mind's hand (stage 6 its choir). The default table:
# stage_defs.gd re-exports these rows, and `--table=alpha` picks this file directly.
# Same shape as slice_defs.gd. It repeats that file's two lookups because a base script's
# static functions would read the base's own DEFS, not this one's. Rows 3 to 6 scale rows 1
# and 2's numbers as a starting point. Like the slice it has no timed events and no vault, and its
# enemies arrive as the authored packs below, drawn by the director instead of its
# clock, its build tilt and its unlock rules.

const BOSS := "brindle"

const COUNT := 6

# The maker tricks (synergies.gd) this table keeps: the five named synergies and the five
# former three-part sets, and since 2026-11-21 (wave 45 B1) the four that had stayed out
# (glacier_hull, storm_lattice, thermal_shock, linked_spiral), so all fourteen are live.
const SYNERGIES := ["wrecking_ball", "tesla_pylon", "pinwheel", "shrapnel_bloom", "lightning_rod",
	"ballast_rig", "shatter_crew", "live_wire", "hair_trigger", "storm_front",
	"glacier_hull", "storm_lattice", "thermal_shock", "linked_spiral"]

# The nineteen parts every source on this table offers, and the only ones. The five shown
# parts of the kept synergies, one carrier of each hidden tag they need (kinetic, speed, mass;
# arc comes from arc_coil, and the class mods carry it for the pylon pilot), the two class
# mods, and three heavy hitters so the shelf has a rare tier. Wave 11 GP2 adds one part per
# verb the pool barely touched (roll, harpoon, boost, special, jump, haul); Live Line and Drop
# Weight are the second ingredients of the Storm Mast and Grounding Spike evolutions. A
# synergy completes from this list for every pilot. Generated recipes and milestone parts are out.
# 2026-10-11 (alpha wave 13 SG5): Load Dividend joins the normal parts as the burden payout.
# 2026-10-15 (wave 14 SQ19b): 19 to 45 parts, so each pilot's offers lean to its own kit
# (Parts.KITS) by the 60 to 80% band on this list too; at 19 the kit share ran 0.12 to 0.69. The
# additions are existing commons that carry one pilot's kit tags, grouped by that pilot below,
# four more neutral shelf parts so a pilot's leftover slots spread instead of repeating the same
# three, and Tally's Winch Pawl. offer_weights_test asserts the band, the movement cap and a
# top-10 overlap of at most 0.40 between any two pilots on this list.
const PARTS := [
	"double_feed", "focus_lens", "spiral_wave", "cross_split", "arc_coil",
	"hot_rivets", "loose_trigger", "rivet_plating",
	"pylon_capacitor", "runner_overclock",
	"sunforged_core", "gatling_heart",
	"grip_tread", "live_line", "vent_baffle", "spare_cell", "spring_shims", "drop_weight",
	"load_dividend",
	# SQ19b neutral shelf (Parts.NEUTRAL_SHELF).
	"long_barrel", "rivet_seam", "magnet_spool", "fast_hands",
	# Sable: arc and anchor skill parts, and its own grapple coil.
	"cap_relay", "beacon_lamp", "echo_locator", "grapple_coil",
	# Rivet: its own sprint cell.
	"sprint_cell",
	# Kest: arc, frost and chain hitters, and its own glide vane.
	"static_burr", "frost_barb", "chain_arc", "glide_vane",
	# Tarn: kinetic hitters, and a kinetic plate it shares with Sable and Tally.
	"pin_setter", "hairline_fracture", "impact_driver", "slag_rounds", "brace_frame",
	# Tally: a split hitter, mass plates and its own winch.
	"barrage_spring", "deflect_plate", "ballast_drum", "scrap_armor", "winch_pawl",
	# The Cannon: a mass hitter and mass-carrying skill parts.
	"overpressure", "cache_key", "re_rack",
	# The cobalt rung (item ladder, wave 20): authored rares no unlock pays, so world 1's
	# guaranteed cobalt has rows to stay new. They roll only at rare and move no common share;
	# the two water rounds read on the Spillway's channels.
	"horizon_optic", "ram_plow", "rime_rounds", "galvanic_rounds",
	# 2026-11-21 (wave 45 B1): the two weapon-pattern transformers (Fan Spread, Helix Drill) and a
	# curated set of 13 high-identity authored rows from items.gd, each with a touch verb and
	# capped at cobalt (rare, ruling bn) so Spare Frame remains the park table's only relic. The
	# nine shift-board unlock rows, the burden parts, Spare Frame, Warden Ward (kept at rare_plus),
	# the three seam-gated non-pattern rows (Vault Battery, Anchor Spring, Feedback Loop), and
	# shared movement-changing rows (Slipstream, Long Lane, Reserve Tank, Gutter Guard, Tumbler
	# Bearing) stay out so movement belongs strictly to the pilot (BIBLE.md:537, DECISIONS.md:423).
	"fan_spread", "helix_drill", "domino_wire", "echo_charge", "overcharge_coil", "ten_pin",
	"synergy_lens", "crush_guard", "last_word", "par_chip",
	"cloak_flask", "jet_vent", "quick_spool", "tracer_round", "magnet_coil",
	# 2026-11-21 (wave 45 U6): Slag Pike (rare, cobalt) and Halo Rig, the two weapon-pattern items of
	# ABILITY-MUTATIONS.md C1 and C2; neither is a relic (ruling bn).
	"slag_pike", "halo_rig",
	# 2026-11-21 (wave 45 U7): the five verb items of ABILITY-MUTATIONS.md C3 to C7, green (uncommon) or
	# cobalt (rare) only; none is a relic (ruling bn).
	"backwash", "barbed_reel", "faultline_cap", "second_bell", "long_leash",
]

# SG4 burden parts: a second list beside PARTS, so the normal loot list (build_synergy_test pins
# its size and a touch verb on every entry) is unchanged. Never offered by a pool
# (Parts.offer_pool skips them); in play so a pocket's pay.named can name one.
const BURDEN_PARTS := ["cracked_plating", "thin_pickings", "slack_coil"]

# W50-ISAAC-PARTS: 8 transformational Worlds 1-3 parts with RoR2 duplicate-stacking curves.
# Kept beside PARTS so AlphaDefs.PARTS stays pinned at 71 while part_in_play() admits all 8.
const EXPANSION_PARTS := [
	"boomerang_spool",
	"orbital_flywheel",
	"prism_splitter",
	"debt_collector",
	"slag_furnace",
	"patch_tether",
	"basalt_ram",
	"storm_capacitor",
]

# A rise to a heft class the run has not been rewarded for opens one upgrade tree pick.
const PICK_ON_CLASS_UP := true

# The Linker (linker.gd) joins one pack a stage from world 2, beside the heaviest crew of that
# world's roster (a drill crew, then an anchor crew), so a quarter of authored arrivals there
# need a kill order (ENEMY-PRIORITY.md 6: none in stage 1, rising after).
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
	{"pack_scale": 1.25, "interval_scale": 0.90, "elite_rate": 1.00, "posture_curve": 1.05, "boss_phase_scale": 1.15},
	{"pack_scale": 1.30, "interval_scale": 0.88, "elite_rate": 1.20, "posture_curve": 1.05, "boss_phase_scale": 1.20},
	{"pack_scale": 1.40, "interval_scale": 0.85, "elite_rate": 1.50, "posture_curve": 1.10, "boss_phase_scale": 1.25},
	{"pack_scale": 1.50, "interval_scale": 0.80, "elite_rate": 1.70, "posture_curve": 1.10, "boss_phase_scale": 1.30},
]

const DEFS := [
	{"stage": 1, "world": 1, "music": {"theme": 0, "ace": "spillway"}, "warden_family": "reactor", "name": "Spillway: the top shelf", "map": "spillway", "threat": 1.0,
		"unlock_base": 2, "ancient": "reactor_relic",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 90.0, "warden_hp": 650.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[0]["posture_curve"], "ram_shatters": false}, "pressure": PRESSURE[0], "warden_hint": "Break its guard, then smash the core.",
		"packs": PACKS_DAM, "elite": ELITE_SPILLWAY, "warden_variant": ""},
	{"stage": 2, "world": 1, "music": {"theme": 1, "ace": "cable_reach"}, "warden_family": "reactor", "name": "The Cable Reach", "map": "reach", "threat": 1.0,
		"unlock_base": 4, "ancient": "reactor_relic",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 110.0, "warden_hp": 800.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[1]["posture_curve"], "ram_shatters": false}, "pressure": PRESSURE[1], "warden_hint": "Break its guard, then smash the core.",
		"packs": PACKS_FLUME, "elite": ELITE_SPILLWAY, "warden_variant": "meltdown"},
	{"stage": 3, "world": 2, "music": {"theme": 1, "ace": "dig_upper"}, "warden_family": "swarm", "name": "Dig: the upper bench", "map": "dig", "threat": 1.1,
		"unlock_base": 2, "ancient": "swarm_remnant",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.5, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 130.0, "warden_hp": 950.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[2]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55, "heavy_ratio": HIVE_HEAVY_RATIO}, "pressure": PRESSURE[2], "warden_hint": "Bowl through its guard rack, then smash the core.",
		"packs": [
			{"id": "dig_shallow", "kinds": ["burrower", "burrower", "lamp_swarm"]},
			{"id": "dig_bore", "kinds": ["drill_crew", "burrower", "prop_crew"]},
			{"id": "dig_lamps", "kinds": ["lamp_swarm", "lamp_swarm", "drill_crew"]},
			{"id": "dig_linked", "kinds": ["linker", "drill_crew", "burrower"]},
			{"id": "dig_shift", "kinds": ["foreman", "drill_crew", "drill_crew", "burrower"]},
			{"id": "dig_jaws", "kinds": ["pit_jaw", "pit_jaw", "burrower"]},
			# w18 nemesis packs: a plated rig over a catch cup (plating, cc) and a Dispatcher beside a
			# mortar (spread, range, fuse), so Sable, Tally, Rivet and Tarn each meet a lean here.
			{"id": "dig_rig", "kinds": ["plated_brute", "catch_trap", "splitter"]},
			{"id": "dig_dispatch", "kinds": ["dispatcher", "lobber", "burrower"]},
		], "elite": DIG_ELITE, "warden_variant": ""},
	{"stage": 4, "world": 2, "music": {"theme": 1, "ace": "dig_deep"}, "warden_family": "swarm", "name": "Dig: the deep works", "map": "dig_deep", "threat": 1.2,
		"unlock_base": 4, "ancient": "swarm_remnant",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 4.5, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 150.0, "warden_hp": 1100.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[3]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55}, "pressure": PRESSURE[3], "warden_hint": "Bowl through its guard rack, then smash the core.",
		"packs": [
			{"id": "deep_bore", "kinds": ["drill_crew", "burrower", "burrower"]},
			{"id": "deep_lamps", "kinds": ["lamp_swarm", "lamp_swarm", "burrower"]},
			{"id": "deep_crew", "kinds": ["drill_crew", "drill_crew", "lamp_swarm", "prop_crew"]},
			{"id": "deep_linked", "kinds": ["linker", "drill_crew", "lamp_swarm"]},
			{"id": "deep_shift", "kinds": ["foreman", "drill_crew", "drill_crew", "burrower"]},
			{"id": "deep_jaws", "kinds": ["pit_jaw", "pit_jaw", "drill_crew", "burrower"]},
			{"id": "deep_guard", "kinds": ["deflector", "mag_trapper", "dispatcher"]},
			{"id": "deep_haul", "kinds": ["winch_drone", "splitter", "lamp_swarm"]},
		], "elite": DIG_ELITE, "warden_variant": "brood"},
	{"stage": 5, "world": 3, "music": {"theme": 2, "ace": "highdraft"}, "warden_family": "mind", "name": "Highdraft", "map": "highdraft", "threat": 1.3,
		"unlock_base": 2, "ancient": "mind_hand",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 5.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 170.0, "warden_hp": 1250.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[4]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 10.0, "contact_gain_floor": 0.35, "drain_rate": 0.5}, "pressure": PRESSURE[4], "warden_hint": "Break its guard, then smash the core.",
		"packs": [
			{"id": "draft_cut", "kinds": ["line_cutter", "line_cutter", "kite_drone"]},
			{"id": "draft_anchor", "kinds": ["ballast_heavy", "line_cutter"]},
			{"id": "draft_kites", "kinds": ["kite_drone", "kite_drone", "gap_net"]},
			{"id": "draft_linked", "kinds": ["linker", "ballast_heavy", "kite_drone"]},
			# w18: the Highdraft's non-range nemesis packs (anchor_crew stays out: highdraft_roster_test HD-0).
			{"id": "draft_plate", "kinds": ["foreman", "plated_brute", "catch_trap"]},
			{"id": "draft_dispatch", "kinds": ["dispatcher", "gap_net", "ballast_heavy"]},
			# w18: presses the plating axis (Sable, Tally). The Dig cannot take it: its kill-first share would fall under 0.25.
			{"id": "plate_press_draft", "kinds": ["plated_brute", "swatter"]},
		], "elite": ELITE_HIGHDRAFT, "warden_variant": ""},
	{"stage": 6, "world": 3, "music": {"theme": 2, "ace": "highdraft_crown"}, "warden_family": "mind", "name": "Highdraft: the crown", "map": "highdraft_crown", "threat": 1.4,
		"unlock_base": 4, "ancient": "mind_hand",
		"event_mix": {}, "scrap_density": 1.0, "kill_scrap": 5.0, "beacon_seconds": 25.0, "beacon_radius": 30.0,
		"warden_plating": 190.0, "warden_hp": 1400.0, "warden_lesson": "",
		"posture": {"curve": POSTURE_CURVE * PRESSURE[5]["posture_curve"], "ram_shatters": false, "contact_gain_scale": 10.0, "contact_gain_floor": 0.35, "drain_rate": 0.5}, "pressure": PRESSURE[5], "warden_hint": "Break its guard, then smash the core.",
		"packs": [
			{"id": "crown_cut", "kinds": ["line_cutter", "kite_drone", "gap_net"]},
			{"id": "crown_anchor", "kinds": ["ballast_heavy", "ballast_heavy", "line_cutter"]},
			{"id": "crown_kites", "kinds": ["kite_drone", "kite_drone", "gap_net", "ballast_heavy"]},
			{"id": "crown_linked", "kinds": ["linker", "ballast_heavy", "line_cutter", "kite_drone"]},
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
	return part_id in PARTS or part_id in BURDEN_PARTS or part_id in EXPANSION_PARTS


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
