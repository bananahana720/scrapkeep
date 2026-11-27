extends RefCounted

const PartDef := preload("res://src/build/part_def.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Items := preload("res://src/build/items.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Nemesis := preload("res://src/combat/nemesis.gd")
const Relics := preload("res://src/build/relics.gd")
const HotwireRules := preload("res://src/build/hotwire_rules.gd")
const Palette := preload("res://src/core/palette.gd")


const BURDEN_PAYOUT_CAP := 0.75
const BURDEN_PAYOUT_SLOPE := 0.25

const CATALOGUE := {
	"load_dividend": {"maker": "redjaw", "touches": "fire", "name": "Load Dividend", "verb": "Burdens add extra hit damage", "text": "Each burden adds hit damage, up to +%d%%" % roundi(BURDEN_PAYOUT_CAP * 100.0),
		"rarity": "rare", "tier": 2, "family": "weapon", "tags": ["mass"], "icon": "damage",
		"trigger": "on_hit", "stack": "hyperbolic", "cap": BURDEN_PAYOUT_CAP,
		"effect": {"do": "burden_payout", "per": BURDEN_PAYOUT_SLOPE}},
	"hot_rivets": {"maker": "fleet_surplus", "touches": "fire", "name": "Hot Rivets", "verb": "Hit harder", "text": "+4 punch, +12% weapon damage",
		"rarity": "common", "tier": 1, "family": "weapon", "tags": ["kinetic"], "punch": 4.0,
		"mods": {"weapon_damage": 1.12}, "stack": "capped", "cap": 3, "levels": [
			{"punch": 4.0, "mods": {"weapon_damage": 1.12}, "text": "+4 punch, +12% weapon damage"},
			{"punch": 8.0, "mods": {"weapon_damage": 1.25}, "text": "+8 punch, +25% weapon damage"},
			{"punch": 13.0, "mods": {"weapon_damage": 1.42}, "text": "+13 punch, +42% weapon damage"}]},
	"loose_trigger": {"maker": "highdraft_roosts", "touches": "fire", "name": "Loose Trigger", "verb": "Fire faster", "text": "+10% fire rate",
		"rarity": "common", "tier": 1, "family": "weapon", "tags": ["speed"],
		"mods": {"weapon_rate": 1.1}},
	"long_barrel": {"maker": "highdraft_roosts", "touches": "fire", "name": "Long Barrel", "verb": "Shoot farther", "text": "+12% weapon range",
		"rarity": "common", "tier": 1, "family": "weapon", "tags": ["anchor"],
		"mods": {"weapon_range": 1.12}},
	"long_spool": {"name": "Long Spool", "verb": "Harpoon reaches farther", "text": "+30% harpoon range",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["anchor"],
		"mods": {"rope_range": 1.3}},
	"tread_plating": {"name": "Tread Plating", "verb": "Roll faster", "text": "+8% cruise speed",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["speed"],
		"mods": {"cruise": 1.08}},
	"boost_coil": {"name": "Boost Coil", "verb": "Boost and dash refill sooner", "text": "Boost and dash refill 15% sooner",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["speed"],
		"cooldown_scale": 0.85},
	"dash_vane": {"name": "Dash Vane", "verb": "Dash harder", "text": "+15% air dash",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["speed"],
		"mods": {"dash_impulse": 1.15}},
	"rivet_plating": {"maker": "fleet_surplus", "touches": "roll", "name": "Rivet Hull", "verb": "Raise your max health", "text": "+15 max health",
		"rarity": "common", "tier": 1, "family": "stat", "tags": ["mass"],
		"max_hp_bonus": 15.0, "stack": "capped", "cap": 3, "levels": [
			{"max_hp_bonus": 15.0, "text": "+15 max health"},
			{"max_hp_bonus": 30.0, "text": "+30 max health"},
			{"max_hp_bonus": 48.0, "text": "+48 max health"}]},
	"magnet_spool": {"maker": "spillway_works", "touches": "roll", "name": "Magnet Spool", "verb": "Pull scrap from farther", "text": "scrap magnet reaches 50% further",
		"icon": "utility", "rarity": "common", "tier": 1, "family": "stat", "tags": ["mass"],
		"magnet": 1.5, "stack": "capped", "cap": 3, "levels": [
			{"magnet": 1.5, "text": "scrap magnet reaches 50% further"},
			{"magnet": 2.25, "text": "scrap magnet reaches 125% further"},
			{"magnet": 3.4, "text": "scrap magnet reaches 240% further"}]},
	"relay_convergence": {"name": "Relay Convergence", "verb": "Relay ring shrinks, charges faster", "pitch": "Ring pulls in, charge quickens",
		"text": "Tighter relay ring, faster charge", "icon": "utility",
		"rarity": "common", "tier": 1, "family": "stat", "tags": ["arc"], "needs": "relay.convergence",
		"stack": "capped", "cap": 3, "relay": {"radius_div": 2.0, "charge_per": 0.3}},
	"grip_tread": {"maker": "highdraft_roosts", "name": "Grip Tread", "verb": "Accelerate faster", "pitch": "Tread bites harder", "touches": "roll",
		"text": "+15% drive acceleration", "icon": "mobility",
		"rarity": "common", "tier": 1, "family": "mobility", "class_id": "runner_gunner", "tags": ["anchor"],
		"mods": {"drive_accel": 1.15}},
	"live_line": {"maker": "mind_glass", "name": "Live Line", "verb": "Harpoon locks on wider", "pitch": "Harpoon grabs wider", "touches": "harpoon",
		"text": "+25% harpoon lock cone", "icon": "mobility",
		"rarity": "common", "tier": 2, "family": "mobility", "tags": ["arc"],
		"mods": {"harpoon_lock_deg": 1.25}},
	"vent_baffle": {"maker": "spillway_works", "name": "Vent Baffle", "verb": "Boost again sooner", "pitch": "Boost breathes quicker", "touches": "boost",
		"text": "Boost refills 12% sooner", "icon": "mobility",
		"rarity": "common", "tier": 1, "family": "mobility", "class_id": "tally", "tags": ["speed"],
		"cooldown_scale": 0.88},
	"winch_pawl": {"maker": "redjaw", "name": "Winch Pawl", "verb": "Reel in faster", "pitch": "Winch hauls quicker", "touches": "harpoon",
		"text": "+25% winch top speed", "icon": "mobility",
		"rarity": "common", "tier": 1, "family": "mobility", "class_id": "tally", "tags": ["anchor"],
		"mods": {"reel_speed": 1.25}},
	"spring_shims": {"maker": "redjaw", "name": "Spring Shims", "verb": "Jump higher", "pitch": "Hop clears rails", "touches": "jump",
		"text": "+10% jump speed", "icon": "mobility",
		"rarity": "common", "tier": 1, "family": "mobility", "class_id": "pylon_engineer", "tags": ["spiral"],
		"mods": {"jump_speed": 1.1}},
	"drop_weight": {"maker": "moss", "name": "Drop Weight", "verb": "Post-smash, knocked machines hit 25% harder", "pitch": "Knocks hit harder", "touches": "haul",
		"text": "After a smash, knocked machines hit 25% harder", "icon": "mobility",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["mass"],
		"trigger": "on_smash", "stack": "linear", "cap": 3,
		"effect": {"do": "pin_bonus", "bonus": 0.25, "window": 1.5}},

	"slag_rounds": {"maker": "fleet_surplus", "touches": "fire", "name": "Slag Rounds", "verb": "Hit much harder", "text": "+10 punch, +25% weapon damage",
		"rarity": "common", "tier": 2, "family": "weapon", "tags": ["kinetic", "mass"], "punch": 10.0,
		"mods": {"weapon_damage": 1.25}},
	"double_feed": {"maker": "fleet_surplus", "touches": "fire", "name": "Double Feed", "verb": "Fire much faster", "text": "+3 punch, +25% fire rate",
		"rarity": "common", "tier": 2, "family": "weapon", "tags": ["speed", "split"], "punch": 3.0,
		"mods": {"weapon_rate": 1.25}},
	"focus_lens": {"maker": "mind_glass", "touches": "fire", "name": "Focus Lens", "verb": "Shoot much farther", "text": "+6 punch, +25% weapon range",
		"rarity": "common", "tier": 2, "family": "weapon", "tags": ["anchor"], "punch": 6.0,
		"mods": {"weapon_range": 1.25}},
	"cross_split": {"maker": "redjaw", "touches": "fire", "name": "Cross Split", "verb": "Split shots into a cross", "text": "shots split four ways on impact",
		"rarity": "common", "tier": 2, "family": "pattern", "tags": ["split"],
		"patterns": {"cross_split": 1}, "mods": {"weapon_damage": 0.6}},
	"spiral_wave": {"maker": "waking", "touches": "fire", "name": "Spiral Wave", "verb": "Spiral shots out in a wave", "text": "shots corkscrew outward",
		"rarity": "common", "tier": 2, "family": "pattern", "tags": ["spiral"],
		"patterns": {"spiral_wave": 1}},
	"chain_arc": {"maker": "mind_glass", "touches": "fire", "name": "Chain Arc", "verb": "Chain hits to a neighbour", "text": "a hit jumps to the nearest machine",
		"rarity": "common", "tier": 2, "family": "pattern", "tags": ["chain", "arc"],
		"patterns": {"chain_arc": 1}},
	"frost_vane": {"name": "Frost Vane", "verb": "Dash trails frost", "text": "air dash freezes water into road",
		"element": "frost", "rarity": "common", "tier": 2, "family": "mobility", "tags": ["frost", "speed"],
		"elements": {"dash": "frost"}, "mods": {"dash_impulse": 1.1}},
	"arc_coil": {"maker": "moss", "touches": "haul", "name": "Arc Coil", "verb": "Slams burst arcs nearby", "text": "Slams burst arcs at everything near",
		"element": "arc", "rarity": "common", "tier": 2, "family": "mobility", "tags": ["arc"],
		"elements": {"slam": "arc"}},
	"pylon_capacitor": {"maker": "spillway_works", "touches": "jump", "name": "Pylon Capacitor", "verb": "Launch harder off pylons", "text": "+8 punch, slingshot +50% boost",
		"icon": "mobility", "rarity": "common", "tier": 2, "family": "class", "class_id": "pylon_engineer", "tags": ["anchor", "arc"],
		"punch": 8.0, "mods": {"slingshot_boost": 1.5, "slingshot_keep": 1.1, "turret_damage": 1.4}},
	"runner_overclock": {"maker": "highdraft_roosts", "touches": "fire", "name": "Runner Overclock", "verb": "Fire faster, boost refills sooner", "text": "+35% fire rate, boost refills 20% sooner",
		"icon": "damage", "rarity": "common", "tier": 2, "family": "class", "class_id": "runner_gunner", "tags": ["speed"],
		"punch": 4.0, "mods": {"weapon_rate": 1.35}, "cooldown_scale": 0.8},

	"sunforged_core": {"maker": "waking", "touches": "fire", "name": "Sunforged Core", "verb": "Hit harder, power hit every 6s", "text": "+22 punch, +50% weapon damage, 6s power hit",
		"rarity": "rare", "tier": 3, "family": "weapon", "tags": ["kinetic", "mass"], "punch": 22.0,
		"mods": {"weapon_damage": 1.5}, "trigger": "timed",
		"effect": {"do": "arm_hit", "every": 6.0, "bonus": 1.0}},
	"gatling_heart": {"maker": "fleet_surplus", "touches": "fire", "name": "Gatling Heart", "verb": "Fire far faster", "text": "+5 punch, +50% fire rate",
		"rarity": "rare", "tier": 3, "family": "weapon", "tags": ["spiral", "speed"], "punch": 5.0,
		"mods": {"weapon_rate": 1.5}},
	"horizon_optic": {"maker": "highdraft_roosts", "touches": "fire", "name": "Horizon Optic", "verb": "Hit harder from much farther", "text": "+12 punch, +50% range, +15% weapon damage",
		"rarity": "rare", "tier": 3, "family": "weapon", "tags": ["anchor", "kinetic"], "punch": 12.0,
		"mods": {"weapon_range": 1.5, "weapon_damage": 1.15}},
	"rime_rounds": {"maker": "spillway_works", "touches": "fire", "name": "Rime Rounds", "verb": "Shots freeze water", "text": "+6 punch. Shots freeze water.",
		"element": "frost", "rarity": "rare", "tier": 3, "family": "weapon", "tags": ["frost", "kinetic"], "punch": 6.0,
		"elements": {"shot": "frost"}},
	"galvanic_rounds": {"maker": "mind_glass", "touches": "fire", "name": "Galvanic Rounds", "verb": "Shots electrify water", "text": "+6 punch. Shots electrify water.",
		"element": "arc", "rarity": "rare", "tier": 3, "family": "weapon", "tags": ["arc", "chain"], "punch": 6.0,
		"elements": {"shot": "arc"}},
	"ram_plow": {"maker": "fleet_surplus", "touches": "roll", "name": "Ram Plow", "verb": "Hit harder, gain 15 max health", "text": "+18 punch, +15 max health",
		"icon": "damage", "rarity": "rare", "tier": 3, "family": "stat", "tags": ["kinetic", "mass"], "punch": 18.0,
		"max_hp_bonus": 15.0},
	"spare_cell": {"maker": "moss", "name": "Spare Cell", "verb": "Kills refill your special", "touches": "special",
		"text": "+1 special charge. Kills refill it, 12s apart.", "icon": "charge",
		"rarity": "rare", "tier": 3, "family": "stat", "tags": ["mass"],
		"charges": {"special": 1}, "trigger": "on_kill",
		"effect": {"do": "grant_charge", "slot": "special", "every": 12.0}},

	"tempest_core": {"name": "Tempest Core", "verb": "Levels up spiral and chain shots", "text": "spiral +2, chain +1, +30% fire rate",
		"rarity": "relic", "tier": 3, "family": "milestone", "milestone_only": true, "tags": ["spiral", "chain"],
		"patterns": {"spiral_wave": 2, "chain_arc": 1}, "mods": {"weapon_rate": 1.3}},
	"rime_heart": {"name": "Rime Heart", "verb": "Freeze the water you roll on", "text": "Water under you freezes, +10% cruise speed",
		"icon": "mobility", "element": "frost", "rarity": "relic", "tier": 3, "family": "milestone", "milestone_only": true, "tags": ["frost", "mass"],
		"elements": {"roll_on_water": "frost"}, "mods": {"cruise": 1.1}},
	"scrap_gravity": {"name": "Scrap Gravity", "verb": "Pull scrap in, kills drop double", "text": "+8 punch, magnet x2.5, kills drop double scrap",
		"icon": "utility", "rarity": "relic", "tier": 3, "family": "milestone", "milestone_only": true, "tags": ["mass"],
		"punch": 8.0, "magnet": 2.5, "kill_scrap": 2.0},
}

const SOURCE_RARITIES := {
	"fabricator": ["common"],
	"vault": ["rare"],
	"milestone": ["relic"],
}

const WORLD_ESCALATION_STAGE_W2 := 3
const WORLD_ESCALATION_STAGE_W3 := 5

const SOURCE_RARITIES_BY_WORLD := {
	1: {"fabricator": ["common"], "vault": ["rare"], "milestone": ["relic"]},
	2: {"fabricator": ["common", "rare"], "vault": ["rare", "relic"], "milestone": ["relic"]},
	3: {"fabricator": ["common", "rare"], "vault": ["rare", "relic"], "milestone": ["relic"]},
}

const GATE_RARITIES_BY_WORLD := {
	1: [["common"], ["common", "rare"], ["rare", "relic"]],
	2: [["common", "rare"], ["rare"], ["rare", "relic"]],
	3: [["common", "rare"], ["rare", "relic"], ["rare", "relic"]],
}

const STAGE_RARE_MULT := {1: 1.0, 2: 2.8, 3: 5.5}

const VERB_EFFECTS := [
	"pike_fuse", "dash_wake", "reel_chain", "slam_crack", "second_bell", "line_leash",
	"boomerang_return", "orbital_satellites", "prism_refract", "coin_shot",
	"slag_zone", "pocket_aura", "seismic_cone", "air_static",
]

const WORLD_VERB_PARTS := [
	"slag_pike", "halo_rig", "backwash", "barbed_reel", "faultline_cap", "second_bell",
	"long_leash", "fan_spread", "helix_drill", "basalt_ram", "storm_capacitor",
	"boomerang_spool", "orbital_flywheel", "prism_splitter", "slag_furnace",
]

const MAKER_SET_PIECES := {
	"spillway_works": 3, "fleet_surplus": 3, "redjaw": 3, "highdraft_roosts": 3,
	"waking": 3, "mind_glass": 3, "moss": 2,
}

const ARCHETYPES := {
	"heavy_melee": {
		"makers": ["fleet_surplus", "waking", "moss"],
		"anchors": ["ram_plow", "basalt_ram", "drop_weight", "ballast_drum", "faultline_cap",
			"barbed_reel", "impact_driver", "winch_pawl", "ten_pin", "pin_setter",
			"warhead_slug", "orbital_flywheel", "brace_frame", "re_rack"],
		"grapple_muts": ["wrecking_flail", "tether_slam", "dragnet_siphon"],
	},
	"run_n_gun": {
		"makers": ["redjaw", "fleet_surplus", "highdraft_roosts"],
		"anchors": ["gatling_heart", "fan_spread", "helix_drill", "double_feed", "slag_pike",
			"halo_rig", "brass_drum", "heavy_breech", "cross_split", "spiral_wave",
			"chain_arc", "boomerang_spool", "prism_splitter", "slag_furnace", "runner_overclock"],
		"grapple_muts": ["det_cord", "sonic_snap_sling"],
	},
	"spell_cast": {
		"makers": ["spillway_works", "highdraft_roosts", "mind_glass"],
		"anchors": ["spare_cell", "storm_capacitor", "second_bell", "overcharge_coil",
			"echo_charge", "cap_relay", "quick_spool", "reserve_tank", "backwash",
			"long_leash", "galvanic_rounds", "rime_rounds", "arc_coil", "pylon_capacitor"],
		"grapple_muts": ["hot_wire", "live_bus"],
	},
}

const MILESTONE_FOR_EVENT := {
	"surge_run": "rime_heart",
	"hold_the_relay": "tempest_core",
}
const MILESTONE_ORDER := ["scrap_gravity", "tempest_core", "rime_heart"]

const SYNERGY_BAIT := 0.35
const HIGH_IMPACT_SYNERGY_BAIT := 0.50

const MAKER_NUDGE_AT := 2
const MAKER_NUDGE := 1.1
const ARCHETYPE_NUDGE_AT := 2
const ARCHETYPE_NUDGE := 1.45
const WORLD_VERB_NUDGE := 1.35
const WORLD_SIGNATURE_NUDGE := 1.6
static var maker_nudge_on := true
static var archetype_nudge_on := true

const ANSWERS := {
	"long_barrel": ["range"], "focus_lens": ["range"], "horizon_optic": ["range"],
	"tracer_round": ["range", "fuse"],
	"cross_split": ["spread"], "spiral_wave": ["spread"], "chain_arc": ["spread"], "fan_spread": ["spread"],
	"helix_drill": ["spread"], "ring_wave": ["spread"], "tempest_core": ["spread"], "arc_coil": ["spread"],
	"static_burr": ["spread"],
	"loose_trigger": ["fuse"], "double_feed": ["fuse"], "gatling_heart": ["fuse"],
	"brace_frame": ["cc"],
	"hot_rivets": ["plating"], "slag_rounds": ["plating"], "sunforged_core": ["plating"], "ram_plow": ["plating"],
	"overpressure": ["plating"], "warhead_slug": ["plating"], "clean_break": ["plating"], "ballast_drum": ["plating"],
}
static var answer_nudge_on := true

const MICRO_MUTATIONS := {
	"tread_plating": {
		"id": "wall_carve_move_refill",
		"part_id": "tread_plating",
		"name": "Wall-Carve Refill",
		"text": "Wall-carving refills movement 25% faster.",
		"rate_bonus": 0.25,
	},
	"long_spool": {
		"id": "grapple_air_steer_surge",
		"part_id": "long_spool",
		"name": "Release Air Surge",
		"text": "Harpoon release grants 0.4 s air-steer surge.",
		"duration_s": 0.4,
		"steer_mult": 1.65,
	},
	"dash_vane": {
		"id": "air_dash_shell_bat",
		"part_id": "dash_vane",
		"name": "Shell-Bat Dash",
		"text": "Air-dashing through a shell bats it back.",
		"window_s": 0.28,
		"reach_bonus": 0.6,
	},
	"loose_trigger": {
		"id": "cadence_window_extend",
		"part_id": "loose_trigger",
		"name": "Cadence Carry",
		"text": "Landing a skilled window extends the next +25%.",
		"window_extend": 0.25,
	},
	"long_barrel": {
		"id": "long_range_stagger",
		"part_id": "long_barrel",
		"name": "Long-Range Stagger",
		"text": "Hits past 20 m add +15% knockback stagger.",
		"min_range_m": 20.0,
		"knock_bonus": 0.15,
	},
	"boost_coil": {
		"id": "heft_break_cd_refresh",
		"part_id": "boost_coil",
		"name": "Smash Cooldown Cut",
		"text": "Boosting through heft props cuts cooldown 50%.",
		"window_s": 0.5,
		"cd_refresh": 0.5,
	},
}


const FLAT_MICRO_MUTATIONS := {
	"rivet_plating": {
		"id": "hull_shatter_pulse",
		"part_id": "rivet_plating",
		"name": "Rivet Shrapnel",
		"text": "Taking hull damage pulses 4.5 m steel shrapnel.",
		"radius_m": 4.5,
		"damage_base": 14.0,
		"knock": 7.0,
		"cooldown_s": 1.0,
	},
	"magnet_spool": {
		"id": "scrap_whip_arc",
		"part_id": "magnet_spool",
		"name": "Scrap Whip",
		"text": "Every 5th scrap whips an arc spark.",
		"every_scrap": 5,
		"reach_m": 10.0,
		"damage_base": 12.0,
	},
	"grip_tread": {
		"id": "brake_skid_flare",
		"part_id": "grip_tread",
		"name": "Skid Flare",
		"text": "Wall-carving sheds a 2.8 m friction flare.",
		"radius_m": 2.8,
		"damage_base": 12.0,
		"knock": 5.0,
		"cooldown_s": 0.6,
	},
	"live_line": {
		"id": "latch_arc_snap",
		"part_id": "live_line",
		"name": "Latch Snap",
		"text": "Harpoon bites snap a 7 m arc jump.",
		"reach_m": 7.0,
		"damage_base": 16.0,
		"cooldown_s": 0.5,
	},
	"vent_baffle": {
		"id": "boost_exhaust_gust",
		"part_id": "vent_baffle",
		"name": "Exhaust Gust",
		"text": "Boosting vents a 5 m rear steam gust.",
		"radius_m": 5.0,
		"damage_base": 12.0,
		"knock": 9.0,
	},
	"winch_pawl": {
		"id": "winch_haul_jolt",
		"part_id": "winch_pawl",
		"name": "Winch Jolt",
		"text": "Harpoon smashes shock machines within 4.5 m.",
		"radius_m": 4.5,
		"damage_base": 16.0,
		"knock": 7.0,
	},
	"spring_shims": {
		"id": "jump_pad_ripple",
		"part_id": "spring_shims",
		"name": "Spring Ripple",
		"text": "Ground jumps ripple a 4 m shock ring.",
		"radius_m": 4.0,
		"damage_base": 10.0,
		"knock": 6.0,
		"cooldown_s": 0.5,
	},
	"gatling_heart": {
		"id": "spool_overheat_vent",
		"part_id": "gatling_heart",
		"name": "Spool Vent",
		"text": "Every 12th shot vents a 5.5 m blast.",
		"every_shots": 12,
		"radius_m": 5.5,
		"damage_base": 18.0,
		"knock": 6.0,
	},
	"horizon_optic": {
		"id": "far_sight_ping",
		"part_id": "horizon_optic",
		"name": "Far-Sight Ping",
		"text": "Hits past 22 m add a 20% piercing ping.",
		"min_range_m": 22.0,
		"bonus_share": 0.20,
		"cooldown_s": 0.6,
	},
	"ram_plow": {
		"id": "plow_wake_cleave",
		"part_id": "ram_plow",
		"name": "Plow Cleave",
		"text": "Fast rams cleave a 4.5 m steel wake.",
		"radius_m": 4.5,
		"damage_base": 20.0,
		"knock": 9.0,
		"min_tier": 2,
		"cooldown_s": 0.4,
	},
}


static func micro_mutation(part_id: String) -> Dictionary:
	if MICRO_MUTATIONS.has(part_id):
		return (MICRO_MUTATIONS[part_id] as Dictionary).duplicate(true)
	if FLAT_MICRO_MUTATIONS.has(part_id):
		return (FLAT_MICRO_MUTATIONS[part_id] as Dictionary).duplicate(true)
	return {}


static func micro_mutation_ids() -> Array:
	return MICRO_MUTATIONS.keys()


static func all_micro_mutation_ids() -> Array:
	return MICRO_MUTATIONS.keys() + FLAT_MICRO_MUTATIONS.keys()


static func has_micro_mutation(held: Array, part_id: String) -> bool:
	return (MICRO_MUTATIONS.has(part_id) or FLAT_MICRO_MUTATIONS.has(part_id)) and part_id in held


static func active_micro_mutations(held: Array) -> Array:
	var out: Array = []
	for part_id in MICRO_MUTATIONS:
		if part_id in held:
			out.append((MICRO_MUTATIONS[part_id] as Dictionary).duplicate(true))
	for part_id in FLAT_MICRO_MUTATIONS:
		if part_id in held:
			out.append((FLAT_MICRO_MUTATIONS[part_id] as Dictionary).duplicate(true))
	return out


static func micro_mutation_problems() -> Array:
	var found: Array = []
	for part_id in MICRO_MUTATIONS:
		if not CATALOGUE.has(part_id):
			found.append("%s is not in CATALOGUE" % part_id)
			continue
		var cat: Dictionary = CATALOGUE[part_id]
		if String(cat.get("rarity", "")) != "common" or int(cat.get("tier", 0)) != 1:
			found.append("%s must stay a Tier-1 common part" % part_id)
		var row: Dictionary = MICRO_MUTATIONS[part_id]
		for key in ["id", "part_id", "name", "text"]:
			if String(row.get(key, "")).strip_edges().is_empty():
				found.append("%s micro-mutation missing %s" % [part_id, key])
		if String(row.get("part_id", "")) != part_id:
			found.append("%s micro-mutation part_id mismatch" % part_id)
	return found


static func all_micro_mutation_problems() -> Array:
	var found := micro_mutation_problems()
	var seen_ids := {}
	for pid in MICRO_MUTATIONS:
		seen_ids[String(MICRO_MUTATIONS[pid]["id"])] = pid
	for part_id in FLAT_MICRO_MUTATIONS:
		if not CATALOGUE.has(part_id):
			found.append("%s is not in CATALOGUE" % part_id)
			continue
		var row: Dictionary = FLAT_MICRO_MUTATIONS[part_id]
		for key in ["id", "part_id", "name", "text"]:
			if String(row.get(key, "")).strip_edges().is_empty():
				found.append("%s flat micro-mutation missing %s" % [part_id, key])
		if String(row.get("part_id", "")) != part_id:
			found.append("%s flat micro-mutation part_id mismatch" % part_id)
		var mid := String(row.get("id", ""))
		if seen_ids.has(mid):
			found.append("%s duplicate micro-mutation id %s" % [part_id, mid])
		seen_ids[mid] = part_id
	return found


const GRAPPLE_MUTATION_PREFIX := "grapple_mut:"
const GRAPPLE_SWAP_SLOTS := ["head", "line", "drive"]
const GRAPPLE_MUT_MODEL_DIR := "res://assets/models/grapple_muts/"

const GRAPPLE_MUTATIONS := {
	"hot_wire": {
		"id": "hot_wire",
		"part_id": "grapple_mut:hot_wire",
		"name": "Hot-Wire Arc Cutter",
		"family": "heat",
		"tags": ["heat"],
		"swaps": "line",
		"maker": "spillway_works",
		"maker_pieces": 3,
		"asset_id": "grapple_mut_hot_wire_line",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_hot_wire_line.glb",
		"color": Palette.AMBER,
		"uses_amber_glow": true,
		"actuator_bones": [],
		"text": "Taut amber line slices enemies, boom floats, and Tier 1-2 props.",
		"line_width_m": 1.6,
		"damage_base": 24.0,
		"max_destructible_tier": 2,
		"float_reach_m": 2.2,
		"hit_cooldown_s": 0.35,
	},
	"det_cord": {
		"id": "det_cord",
		"part_id": "grapple_mut:det_cord",
		"name": "Det-Cord Line",
		"family": "burst",
		"tags": ["split"],
		"swaps": "line",
		"maker": "redjaw",
		"maker_pieces": 3,
		"asset_id": "grapple_mut_det_cord_line",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_det_cord_line.glb",
		"color": Palette.COPPER,
		"uses_amber_glow": false,
		"actuator_bones": [],
		"text": "Release detonates sequenced shaped charges down the tether path.",
		"spacing_m": 3.5,
		"max_nodes": 6,
		"step_delay_s": 0.06,
		"blast_radius_m": 4.2,
		"damage_base": 22.0,
		"knock": 9.0,
		"tier_bonus": 1,
	},
	"dragnet_siphon": {
		"id": "dragnet_siphon",
		"part_id": "grapple_mut:dragnet_siphon",
		"name": "Dragnet Siphon",
		"family": "salvage",
		"tags": ["mass"],
		"swaps": "head",
		"maker": "moss",
		"maker_pieces": 2,
		"asset_id": "grapple_mut_dragnet_siphon_head",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_dragnet_siphon_head.glb",
		"color": Palette.STEEL,
		"uses_amber_glow": false,
		"actuator_bones": ["mouth"],
		"text": "Tether span vacuums scrap, cogs, and pocket consumables within 5 m.",
		"vacuum_radius_m": 5.0,
		"pull_speed": 26.0,
	},
	"sonic_snap_sling": {
		"id": "sonic_snap_sling",
		"part_id": "grapple_mut:sonic_snap_sling",
		"name": "Sonic Snap-Sling",
		"family": "speed",
		"tags": ["speed"],
		"swaps": "drive",
		"maker": "highdraft_roosts",
		"maker_pieces": 3,
		"asset_id": "grapple_mut_sonic_snap_sling_drive",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_sonic_snap_sling_drive.glb",
		"color": Palette.COPPER,
		"uses_amber_glow": false,
		"actuator_bones": ["pawl"],
		"text": "Pendulum apex release grants +12 m/s Blazing burst and Air-Jump.",
		"burst_speed": 12.0,
		"apex_vy_tol": 6.5,
		"min_drop_m": 0.5,
		"min_swing_s": 0.05,
	},
	"live_bus": {
		"id": "live_bus",
		"part_id": "grapple_mut:live_bus",
		"name": "Live-Bus Conductor",
		"family": "arc",
		"tags": ["arc", "chain"],
		"swaps": "head",
		"maker": "mind_glass",
		"maker_pieces": 3,
		"asset_id": "grapple_mut_live_bus_head",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_live_bus_head.glb",
		"color": Palette.AMBER,
		"uses_amber_glow": true,
		"actuator_bones": ["jaw.0", "jaw.1"],
		"text": "Latching powered world props charges next strike with amber bus current.",
		"bonus_mult": 1.65,
		"bonus_flat": 24.0,
		"charge_duration_s": 8.0,
		"arc_radius_m": 8.0,
	},
	"tether_slam": {
		"id": "tether_slam",
		"part_id": "grapple_mut:tether_slam",
		"name": "Tether-Slam Clutch",
		"family": "pull",
		"tags": ["kinetic"],
		"swaps": "drive",
		"maker": "waking",
		"maker_pieces": 3,
		"asset_id": "grapple_mut_tether_slam_drive",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_tether_slam_drive.glb",
		"color": Palette.COPPER,
		"uses_amber_glow": false,
		"actuator_bones": [],
		"text": "Smash while tethered yanks both ends to mid-point for 2x crush.",
		"crush_mult": 2.0,
		"slam_radius_m": 8.0,
		"damage_base": 32.0,
		"knock": 16.0,
		"yank_speed": 24.0,
		"armed_window_s": 1.2,
	},
	"wrecking_flail": {
		"id": "wrecking_flail",
		"part_id": "grapple_mut:wrecking_flail",
		"name": "Wrecking Flail",
		"family": "mass",
		"tags": ["mass"],
		"swaps": "head",
		"maker": "fleet_surplus",
		"maker_pieces": 3,
		"asset_id": "grapple_mut_wrecking_flail_head",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_wrecking_flail_head.glb",
		"color": Palette.STEEL,
		"uses_amber_glow": false,
		"actuator_bones": ["flail"],
		"text": "Taut swing through Heft props or armor adds +1 effective Heft tier.",
		"heft_bonus": 1,
		"armor_shred_bonus": 25.0,
		"swing_reach_m": 3.2,
		"min_speed": 8.0,
	},
}


static func grapple_mutation_ids() -> Array:
	return GRAPPLE_MUTATIONS.keys()


static func is_grapple_mutation_part(part_id: String) -> bool:
	return part_id.begins_with(GRAPPLE_MUTATION_PREFIX) and GRAPPLE_MUTATIONS.has(part_id.substr(GRAPPLE_MUTATION_PREFIX.length()))


static func grapple_mutation_id_of(part_id: String) -> String:
	if GRAPPLE_MUTATIONS.has(part_id):
		return part_id
	if part_id.begins_with(GRAPPLE_MUTATION_PREFIX):
		var stripped := part_id.substr(GRAPPLE_MUTATION_PREFIX.length())
		return stripped if GRAPPLE_MUTATIONS.has(stripped) else ""
	var from_item := Items.grapple_mutation_of(part_id)
	return from_item if GRAPPLE_MUTATIONS.has(from_item) else ""


static func grapple_mutation(id_or_part: String) -> Dictionary:
	var mid := grapple_mutation_id_of(id_or_part)
	if mid == "":
		return {}
	return (GRAPPLE_MUTATIONS[mid] as Dictionary).duplicate(true)


static func active_grapple_mutations(held: Array, maker_muts: Array = []) -> Dictionary:
	var by_slot := {}
	var makers_to_check := maker_muts
	if makers_to_check.is_empty() and not held.is_empty():
		var counted := maker_counts(held)
		makers_to_check = []
		for mid in GRAPPLE_MUTATIONS:
			var row: Dictionary = GRAPPLE_MUTATIONS[mid]
			var maker := String(row.get("maker", ""))
			var need := int(row.get("maker_pieces", 3))
			if maker != "" and int(counted.get(maker, 0)) >= need:
				makers_to_check.append(mid)
	for mid in makers_to_check:
		if GRAPPLE_MUTATIONS.has(mid):
			var row: Dictionary = GRAPPLE_MUTATIONS[mid]
			by_slot[String(row["swaps"])] = row.duplicate(true)
	for raw_id in held:
		var mid := grapple_mutation_id_of(String(raw_id))
		if mid != "":
			var row: Dictionary = GRAPPLE_MUTATIONS[mid]
			by_slot[String(row["swaps"])] = row.duplicate(true)
	return by_slot


static func has_grapple_mutation(held: Array, mut_id: String, maker_muts: Array = []) -> bool:
	var mid := grapple_mutation_id_of(mut_id)
	if mid == "":
		return false
	var active := active_grapple_mutations(held, maker_muts)
	for slot in active:
		if String(active[slot]["id"]) == mid:
			return true
	return false


static func grapple_mutation_problems() -> Array:
	var found: Array = []
	var allowed := [Palette.AMBER, Palette.COPPER, Palette.STEEL, Palette.SAND, Palette.VERDIGRIS]
	for mid in GRAPPLE_MUTATIONS:
		var row: Dictionary = GRAPPLE_MUTATIONS[mid]
		if String(row.get("id", "")) != mid:
			found.append("%s id mismatch" % mid)
		if not String(row.get("swaps", "")) in GRAPPLE_SWAP_SLOTS:
			found.append("%s swaps invalid slot %s" % [mid, row.get("swaps", "")])
		if String(row.get("glb_path", "")).strip_edges().is_empty():
			found.append("%s missing glb_path" % mid)
		var col: Color = row.get("color", Color.BLACK)
		var ok := false
		for a: Color in allowed:
			if col.is_equal_approx(a):
				ok = true
				break
		if not ok:
			found.append("%s uses disallowed colour" % mid)
		if mid in ["hot_wire", "live_bus"] and not col.is_equal_approx(Palette.AMBER):
			found.append("%s must use Palette.AMBER" % mid)
	return found

const PATTERN_PARTS := ["spiral_wave", "cross_split", "chain_arc"]
const PATTERN_GUARANTEE_STAGE := 2
const RUNG_FLOOR := 1

const GENERATED_SHARE := 0.25

const KITS := {
	"pylon_engineer": {"skill": ["arc", "anchor"], "defence": ["arc", "anchor", "kinetic"]},
	"runner_gunner": {"skill": ["speed"], "movement": ["speed"]},
	"demolitions_caster": {"weapon": ["arc", "chain", "frost", "spiral"], "movement": []},
	"tarn": {"weapon": ["kinetic"], "defence": ["kinetic", "anchor"]},
	"tally": {"weapon": ["split"], "defence": ["speed", "mass"]},
	"remembered_cannon": {"weapon": ["mass"], "skill": ["mass", "kinetic", "speed"]},
}
const KIT_SHARE := 0.7
const REST_OF_NEUTRAL := 0.15
const KIT_PART_CAP := 0.25
const MOVEMENT_SHARE := 0.12
const CLASS_MOVEMENT_SHARE := 0.06
const NEUTRAL_SHELF := ["hot_rivets", "loose_trigger", "long_barrel", "rivet_plating", "rivet_seam", "magnet_spool", "fast_hands"]
const NEUTRAL_LEAN := 4.0
const NEUTRAL_WEAPON_EASE := 0.1
const NEUTRAL_REPEAT_CAP := 2

const BURDEN_HP := 4.0
const BURDEN_SCRAP_LOSS := 0.05
const BURDEN_MAGNET_LOSS := 0.10
const HOTWIRE_CAP_WORLD_ONE := 1
const HOTWIRE_CAP_LATER := 2
const HOTWIRED := {
	"riveted_shell": {"name": "Riveted Shell", "tags": ["mass"], "maker": "fleet_surplus", "needs_armor": true, "recycle_commons": 2,
		"label": "{armor} armour. Air steering \u2212{steer}%.",
		"upside": {"icon": "cat_defense", "words": "{armor_x}x armour"},
		"downside": {"icon": "cat_mobility", "words": "Air steering \u2212{steer}%"}},
	"spark_tread": {"name": "Spark Tread", "tags": ["kinetic", "arc"], "maker": "spillway_works", "needs_armor": true, "recycle_commons": 3,
		"label": "Big signature hits. {wear} rolling wear.",
		"upside": {"icon": "cat_damage", "words": "+{bonus}% signature hit"},
		"downside": {"icon": "cat_defense", "words": "{wear_x}x rolling wear"}},
	"cracked_plating": {"name": "Cracked Hull", "tags": ["mass"], "burden": true, "recycle_commons": 1,
		"label": "Costs {hp} max health.",
		"downside": {"icon": "cat_defense", "words": "−{hp} max health"},
		"part": {"verb": "Costs max health", "family": "stat", "max_hp_bonus": -BURDEN_HP}},
	"thin_pickings": {"name": "Thin Pickings", "tags": ["anchor"], "burden": true, "recycle_commons": 1,
		"label": "Costs {scrap}% scrap per kill.",
		"downside": {"icon": "cat_utility", "words": "−{scrap}% kill scrap"},
		"part": {"verb": "Costs kill scrap", "family": "stat", "kill_scrap": 1.0 - BURDEN_SCRAP_LOSS}},
	"slack_coil": {"name": "Slack Coil", "tags": ["arc"], "burden": true, "recycle_commons": 1,
		"label": "Costs {magnet}% magnet reach.",
		"downside": {"icon": "cat_utility", "words": "−{magnet}% magnet reach"},
		"part": {"verb": "Costs magnet reach", "family": "stat", "magnet": 1.0 - BURDEN_MAGNET_LOSS}},
}
const RECYCLE_COMMON := 10

const EVOLVED := {
	"breaker_drive": {"name": "Breaker Drive", "verb": "Hit 35% harder, +8 punch", "text": "+8 punch, +35% weapon damage. From Wrecking Ball.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["kinetic", "speed"], "punch": 8.0,
		"mods": {"weapon_damage": 1.35}},
	"bladestorm_rotor": {"name": "Bladestorm Rotor", "verb": "Spiral level up, fire faster", "text": "Spiral level +1, +20% fire rate. From Pinwheel.",
		"rarity": "evolved", "tier": 3, "family": "pattern", "tags": ["spiral", "speed"], "patterns": {"spiral_wave": 1},
		"mods": {"weapon_rate": 1.2}},
	"storm_mast": {"name": "Storm Mast", "verb": "Fire 20% faster, +6 punch", "text": "+6 punch, +20% fire rate. From Tesla Pylon.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["anchor", "arc"], "punch": 6.0,
		"mods": {"weapon_rate": 1.2}},
	"grounding_spike": {"name": "Grounding Spike", "verb": "Hit 25% harder, +8 punch", "text": "+8 punch, +25% weapon damage. From Lightning Rod.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["arc", "mass"], "punch": 8.0,
		"mods": {"weapon_damage": 1.25}},
	"grapeshot_press": {"name": "Grapeshot Press", "verb": "Splits fly tight and knock back", "text": "Tight splits knock machines back. From Shrapnel Bloom.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["split", "kinetic"], "bits": []},
	"hoar_barrel": {"name": "Hoar Barrel", "verb": "Piercing shots frost and burst ice", "text": "Pierce frosts machines, bursts ice. From Shatter Crew.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["frost", "kinetic"], "bits": []},
	"fault_hammer": {"name": "Fault Hammer", "verb": "Slams ring a delayed aftershock", "text": "Half-damage aftershock shatters ice. From Thermal Shock.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["mass", "frost"], "bits": []},
}
const VERB_EVOLVED := ["grapeshot_press", "hoar_barrel", "fault_hammer"]

const EXPANSION_PARTS := {
	"boomerang_spool": {
		"maker": "moss", "touches": "fire", "base": "weapon", "name": "Boomerang Spool",
		"verb": "Shots pause and whip back once", "text": "Bolts pause 0.15s and return once",
		"rarity": "rare", "tier": 3, "tags": ["anchor", "split"], "bits": [],
		"stack": "linear", "cap": 5,
		"effect": {"do": "boomerang_return", "pause_s": 0.15, "damage_per_stack": 0.20, "width_per_stack": 0.25,
			"max_damage_mult": 2.0, "max_width_mult": 2.25},
	},
	"orbital_flywheel": {
		"maker": "waking", "touches": "roll", "base": "pattern", "name": "Orbital Flywheel",
		"verb": "Spin scrap satellites around you", "text": "Spawns 1 to 5 speed-scaled satellites",
		"rarity": "rare", "tier": 3, "tags": ["spiral", "mass"], "bits": [],
		"stack": "capped", "cap": 5,
		"effect": {"do": "orbital_satellites", "count": 1, "max_count": 5, "damage": 14.0, "base_radius": 3.0},
	},
	"prism_splitter": {
		"maker": "mind_glass", "touches": "fire", "base": "weapon", "name": "Prism Splitter",
		"verb": "Plated hits refract copper rays", "text": "Plated hits refract 3 to 5 rays",
		"rarity": "rare", "tier": 3, "tags": ["arc", "split"], "bits": [],
		"stack": "linear", "cap": 3,
		"effect": {"do": "prism_refract", "base_rays": 2, "per_stack": 1, "max_rays": 5,
			"reach": 10.0, "damage_share": 0.55},
	},
	"debt_collector": {
		"maker": "fleet_surplus", "touches": "roll", "base": "utility", "name": "Debt Collector",
		"verb": "Cog pickups fire brass coin shots", "text": "Cogs fire a coin shot, 0.35s gap",
		"rarity": "uncommon", "tier": 2, "tags": ["mass", "kinetic"], "bits": [],
		"stack": "hyperbolic", "cap": 0.75,
		"effect": {"do": "coin_shot", "cooldown_s": 0.35, "damage": 16.0, "scale_per": 0.35, "reach": 22.0},
	},
	"slag_furnace": {
		"maker": "redjaw", "touches": "fire", "base": "weapon", "name": "Slag Furnace",
		"verb": "Every fifth kill drops molten slag", "text": "5th kill drops 4s slag heat zone",
		"rarity": "rare", "tier": 3, "tags": ["kinetic", "mass"], "bits": ["heat"],
		"stack": "hyperbolic", "cap": 0.75,
		"effect": {"do": "slag_zone", "every_kills": 5, "duration_s": 4.0, "base_radius": 3.2,
			"radius_per": 0.45, "max_radius": 6.5, "dps": 18.0},
	},
	"patch_tether": {
		"maker": "moss", "touches": "roll", "base": "utility", "name": "Patch Tether",
		"verb": "Held pocket tool boosts hit damage", "text": "Holding a pocket tool adds +18% hit",
		"rarity": "uncommon", "tier": 2, "tags": ["anchor", "speed"], "bits": [],
		"stack": "hyperbolic", "cap": 0.65,
		"effect": {"do": "pocket_aura", "per": 0.22, "cap_bonus": 0.65},
	},
	"basalt_ram": {
		"maker": "waking", "touches": "haul", "base": "weapon", "name": "Basalt Ram",
		"verb": "Carving or breaking fires seismic cone", "text": "Wall-carves and breaches fire seismic cone",
		"rarity": "rare", "tier": 3, "world": 2, "tags": ["mass", "kinetic"], "bits": [],
		"stack": "linear", "cap": 4,
		"effect": {"do": "seismic_cone", "length": 11.0, "half_angle_deg": 24.0, "damage": 24.0,
			"per_stack": 0.25, "max_mult": 2.0, "cooldown_s": 0.75},
	},
	"storm_capacitor": {
		"maker": "highdraft_roosts", "touches": "jump", "base": "weapon", "name": "Storm Capacitor",
		"verb": "Air hits charge landing arc blast", "text": "Air hits bank static, release on land",
		"rarity": "rare", "tier": 3, "world": 3, "tags": ["arc", "speed"], "bits": [],
		"stack": "hyperbolic", "cap": 0.75,
		"effect": {"do": "air_static", "per_hit": 10.0, "max_charges": 8, "per_stack": 0.35, "radius": 8.5},
	},
}

const EVOLVED_W50 := {
	"gyro_foundry": {"name": "Gyro Foundry", "verb": "Satellites ring seismic shocks on hit", "text": "Orbital hits ring seismic shocks. From Storm Front.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["spiral", "mass"], "bits": []},
	"arc_prism": {"name": "Arc Prism", "verb": "Prism rays fire unplated and arc", "text": "Prism rays chain arc once. From Live Wire.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["arc", "split"], "bits": []},
	"whiplash_spool": {"name": "Whiplash Spool", "verb": "Returning bolts pull light machines inward", "text": "Boomerang return drags light machines. From Lightning Rod.",
		"rarity": "evolved", "tier": 3, "family": "weapon", "tags": ["anchor", "split"], "bits": []},
}
const VERB_EVOLVED_W50 := ["gyro_foundry", "arc_prism", "whiplash_spool"]

static var _defs := {}
static var _run_ref: WeakRef


static func bind_run(run) -> void:
	var held = _run_ref.get_ref() if _run_ref != null else null
	if held != null and held != run and held.get("events") != null and (run == null or run.get("events") == null):
		return
	_run_ref = weakref(run)


static func active_tier() -> int:
	var run = _run_ref.get_ref() if _run_ref != null else null
	return run.selected_run_tier() if run != null else 0


static func _pick_rarity(rng: RandomNumberGenerator, allowed: Array) -> String:
	return _pick_rarity_scaled(rng, allowed, 1.0)


static func _pick_rarity_scaled(rng: RandomNumberGenerator, allowed: Array, rare_mult := 1.0) -> String:
	var tier_mult: float = float(RunTier.row(active_tier()).rare_weight) if active_tier() != 0 else 1.0
	var combined_rare := tier_mult * rare_mult
	if is_equal_approx(combined_rare, 1.0):
		return ItemGen.pick_rarity(rng, allowed)
	var total := 0.0
	var weights := {}
	for rarity in allowed:
		weights[rarity] = ItemGen.weight_of(rarity) * (combined_rare if rarity == "rare" else 1.0)
		total += weights[rarity]
	var x := rng.randf() * total
	for rarity in allowed:
		x -= weights[rarity]
		if x < 0.0:
			return rarity
	return allowed[-1]

static var _rows := {}
static var _all_rows := {}
static var seams := {}
static var opened_items := {}


static func reset_for_tests() -> void:
	maker_nudge_on = true
	archetype_nudge_on = true
	answer_nudge_on = true
	_run_ref = null
	seams = {}
	opened_items = {}


static func rows() -> Dictionary:
	if _rows.is_empty():
		for key in CATALOGUE:
			_rows[key] = _settled(CATALOGUE[key])
		for key in Items.TABLE:
			_rows[key] = _settled(ItemGen.finish(key, Items.TABLE[key]))
		for key in Items.CELLS:
			_rows[key] = _settled(ItemGen.finish(key, Items.CELLS[key]))
	return _rows


static func all_rows() -> Dictionary:
	if _all_rows.is_empty():
		for key in rows():
			_all_rows[key] = rows()[key]
		for key in EXPANSION_PARTS:
			_all_rows[key] = _settled(ItemGen.finish(key, EXPANSION_PARTS[key]))
	return _all_rows


static func expansion_ids() -> Array:
	return EXPANSION_PARTS.keys()


static func all_evolved() -> Dictionary:
	var out := EVOLVED.duplicate(true)
	for key in EVOLVED_W50:
		out[key] = EVOLVED_W50[key]
	return out


static func all_verb_evolved() -> Array:
	return VERB_EVOLVED + VERB_EVOLVED_W50


static func _settled(spec: Dictionary) -> Dictionary:
	var out := spec.duplicate(true)
	var rarity := ItemGen.resolve_rarity(String(spec.get("rarity", "common")))
	out["rarity"] = rarity if rarity != "" else "common"
	if out["rarity"] != "common" and PartDef.from_row("_", out).percentage_only():
		out["rarity"] = "common"
	return out


static func rarity_of(part_id: String) -> String:
	return String(row(part_id).get("rarity", "common"))


static func row(part_id: String, tier := -1) -> Dictionary:
	var base := _base_row(part_id)
	return RunTier.effective_part(part_id, base, active_tier() if tier < 0 else tier)


static func _base_row(part_id: String) -> Dictionary:
	var authored: Dictionary = all_rows().get(part_id, {})
	if not authored.is_empty():
		return authored
	if EVOLVED.has(part_id):
		var evolved := _settled(EVOLVED[part_id])
		if part_id in VERB_EVOLVED:
			evolved["rarity"] = String(EVOLVED[part_id]["rarity"])
		return evolved
	if EVOLVED_W50.has(part_id):
		var evolved_w50 := _settled(EVOLVED_W50[part_id])
		if part_id in VERB_EVOLVED_W50:
			evolved_w50["rarity"] = String(EVOLVED_W50[part_id]["rarity"])
		return evolved_w50
	if is_burden(part_id):
		return _settled(_burden_spec(part_id))
	if Relics.is_relic(part_id):
		return Relics.part_row(part_id)
	if HOTWIRED.has(part_id):
		return _hotwired_spec(part_id)
	if is_grapple_mutation_part(part_id):
		return _grapple_mut_spec(part_id)
	var generated := ItemGen.generated_row(part_id)
	return _settled(generated) if not generated.is_empty() else generated


static func level_problems(part_id: String, r: Dictionary) -> Array:
	var levels: Array = r.get("levels", [])
	if levels.is_empty():
		return []
	var out: Array = []
	if levels.size() != PartDef.MAX_LEVEL:
		out.append("%s has %d levels, not %d" % [part_id, levels.size(), PartDef.MAX_LEVEL])
	if r.get("stack", "linear") != "capped" or int(r.get("cap", 0)) != PartDef.MAX_LEVEL:
		out.append("%s levels need a capped stack of %d" % [part_id, PartDef.MAX_LEVEL])
	var mods: Dictionary = r.get("mods", {})
	for i in levels.size():
		var lv: Dictionary = levels[i]
		for key in lv:
			if not key in PartDef.LEVEL_KEYS or not r.has(key):
				out.append("%s level %d sets %s, which the row does not" % [part_id, i + 1, key])
		for knob in lv.get("mods", {}):
			if not mods.has(knob):
				out.append("%s level %d moves %s, which the row does not" % [part_id, i + 1, knob])
		if i == 0:
			for key in lv:
				if lv[key] != r.get(key):
					out.append("%s level 1 %s is %s, the row says %s" % [part_id, key, lv[key], r.get(key)])
			continue
		var prev: Dictionary = levels[i - 1]
		for key in ["punch", "max_hp_bonus", "magnet"]:
			if lv.has(key) and float(lv[key]) < float(prev.get(key, r.get(key, lv[key]))):
				out.append("%s level %d %s falls" % [part_id, i + 1, key])
		for knob in lv.get("mods", {}):
			if float(lv["mods"][knob]) < float(prev.get("mods", mods).get(knob, 1.0)):
				out.append("%s level %d %s falls" % [part_id, i + 1, knob])
	return out


static func offer_def(part_id: String, held: Array) -> Resource:
	return def_at(part_id, next_level(part_id, held))


static func offer_headline(part_id: String, held: Array) -> String:
	return headline(part_id, next_level(part_id, held))


static func next_level(part_id: String, held: Array) -> int:
	return mini(level_of(part_id, held) + 1, PartDef.MAX_LEVEL)


static func level_of(part_id: String, held: Array) -> int:
	var d: Resource = def(part_id)
	if d == null or d.levels.is_empty():
		return 0
	return mini(held.count(part_id), PartDef.MAX_LEVEL)


static func maxed(part_id: String, held: Array) -> bool:
	return level_of(part_id, held) >= PartDef.MAX_LEVEL


static func stacked_out(part_id: String, held: Array) -> bool:
	if maxed(part_id, held):
		return true
	var d: Resource = def(part_id)
	if d == null or not d.levels.is_empty() or not d.stack_rule in ["linear", "capped"] or d.stack_cap < 1.0:
		return false
	return held.count(part_id) >= int(d.stack_cap)


static func _swap_stacked_out(rng: RandomNumberGenerator, class_id: String, held: Array, picks: Array, pool: Array,
		offered: Dictionary) -> Array:
	var out: Array = []
	var left: Array = _uncapped(class_id, pool, offered).filter(func(key): return not stacked_out(key, held) and not key in picks)
	for key in picks:
		if not stacked_out(key, held):
			out.append(key)
			continue
		var hard: bool = def(key).hits_harder()
		var shelf: bool = key in NEUTRAL_SHELF
		var kept: Array = left.filter(func(k): return (not hard or def(k).hits_harder()) and (not shelf or k in NEUTRAL_SHELF))
		if kept.is_empty():
			kept = left
		var bucket := bucket_of(key)
		var kit := in_kit(class_id, key)
		var same: Array = kept.filter(func(k): return bucket_of(k) == bucket and in_kit(class_id, k) == kit)
		if same.is_empty():
			same = kept.filter(func(k): return bucket_of(k) == bucket)
		if same.is_empty():
			same = kept
		if same.is_empty():
			continue
		var swap: String = same[rng.randi_range(0, same.size() - 1)]
		out.append(swap)
		left.erase(swap)
	return out


static func def_at(part_id: String, level: int) -> Resource:
	var base: Resource = def(part_id)
	if base == null or base.levels.is_empty():
		return base
	level = clampi(level, 1, base.levels.size())
	var key := "%d@%s:%s" % [active_tier(), level, part_id]
	if not _defs.has(key):
		var r := row(part_id).duplicate(true)
		r.merge(base.levels[level - 1], true)
		var d: Resource = PartDef.from_row(part_id, r)
		d.level = level
		_defs[key] = d
	return _defs[key]


static func def(part_id: String) -> Resource:
	var tier := active_tier()
	var key := "1:" + part_id if tier != RunTier.BASE and RunTier.ENHANCED.has(part_id) else part_id
	if not _defs.has(key):
		var r := row(part_id, tier)
		if r.is_empty():
			return null
		_defs[key] = PartDef.from_row(part_id, r)
	return _defs[key]


static func has(part_id: String) -> bool:
	return all_rows().has(part_id) or EVOLVED.has(part_id) or EVOLVED_W50.has(part_id) or HOTWIRED.has(part_id) or Relics.is_relic(part_id) \
		or is_grapple_mutation_part(part_id) \
		or (ItemGen.is_generated(part_id) and not ItemGen.parse(part_id).is_empty())


static func ids() -> Array:
	return rows().keys()


static func hotwired(part_id: String) -> Dictionary:
	return HOTWIRED.get(part_id, {})


static func hotwire_offer(armor_mode: bool, held: Array = [], world := 1) -> Array:
	var held_count := held.filter(func(key): return HOTWIRED.has(key) and not is_burden(key)).size()
	if held_count >= hotwire_cap(world):
		return []
	var out: Array = []
	for key in HOTWIRED:
		if is_burden(key) or key in held:
			continue
		if HOTWIRED[key].get("needs_armor", false) and not armor_mode:
			continue
		out.append(key)
	return out


static func hotwire_cap(world: int) -> int:
	return HOTWIRE_CAP_WORLD_ONE if world <= 1 else HOTWIRE_CAP_LATER


static func is_burden(part_id: String) -> bool:
	return bool(HOTWIRED.get(part_id, {}).get("burden", false))


static func burdens() -> Array:
	return HOTWIRED.keys().filter(func(key): return is_burden(key))


static func burden_cost(part_id: String) -> Dictionary:
	if not is_burden(part_id):
		return {}
	var cost: Dictionary = HOTWIRED[part_id]["downside"]
	return {"icon": cost["icon"], "words": _burden_fill(cost["words"], HOTWIRED[part_id]["part"])}


static func _burden_fill(text: String, part: Dictionary) -> String:
	return text.replace("{hp}", str(int(round(-float(part.get("max_hp_bonus", 0.0)))))) \
		.replace("{scrap}", str(int(round((1.0 - float(part.get("kill_scrap", 1.0))) * 100.0)))) \
		.replace("{magnet}", str(int(round((1.0 - float(part.get("magnet", 1.0))) * 100.0))))


static func _burden_spec(part_id: String) -> Dictionary:
	var hot: Dictionary = HOTWIRED[part_id]
	var spec: Dictionary = hot["part"].duplicate(true)
	spec["name"] = hot["name"]
	spec["tags"] = hot["tags"]
	spec["rarity"] = "rare"
	spec["tier"] = 1
	spec["icon"] = String(hot["downside"]["icon"]).trim_prefix("cat_")
	spec["text"] = _burden_fill(hot["label"], hot["part"])
	return spec


static func _hotwired_spec(part_id: String) -> Dictionary:
	var hot: Dictionary = HOTWIRED[part_id]
	var line := HotwireRules.fill(hot["label"])
	return {"name": hot["name"], "verb": line, "text": line, "tags": hot["tags"], "maker": hot["maker"],
		"rarity": "rare", "tier": 2, "family": "stat", "icon": String(hot["upside"]["icon"]).trim_prefix("cat_"),
		"cap": 1, "stack": "capped"}


static func _grapple_mut_spec(part_id: String) -> Dictionary:
	var m := grapple_mutation(part_id)
	if m.is_empty():
		return {}
	return {"name": String(m["name"]), "verb": String(m["text"]), "text": String(m["text"]),
		"tags": (m["tags"] as Array).duplicate(), "maker": String(m.get("maker", "")),
		"rarity": "rare", "tier": 2, "family": "mobility", "icon": "mobility",
		"cap": 1, "stack": "capped"}


static func hotwire_recycle(part_id: String) -> int:
	return int(hotwired(part_id).get("recycle_commons", 0)) * RECYCLE_COMMON


static func seam_met(need: String) -> bool:
	return need == "" or seams.get(need, false)


static func display_name(part_id: String) -> String:
	var d: Resource = def(part_id)
	if d != null:
		return d.display_name
	return String(token(part_id).get("name", part_id.replace("_", " ").capitalize()))


const TOKENS := {
	"admirals_crest": {"name": "Admiral's Crest", "verb": "Fleet property. Yours now.", "stamp": "TROPHY"},
}


static func token(part_id: String) -> Dictionary:
	return TOKENS.get(part_id, {})


static func tags_of(part_id: String) -> Array:
	var d: Resource = def(part_id)
	return d.tags if d != null else []


static func icon_of(part_id: String) -> String:
	var d: Resource = def(part_id)
	if d == null:
		return ""
	if d.element != "":
		return "el_" + d.element
	return "cat_" + (d.icon_category if d.icon_category != "" else "utility")


static func headline(part_id: String, level := 1) -> String:
	var d: Resource = def_at(part_id, level)
	if d == null:
		return display_name(part_id)
	var line := "%s: %s." % [d.display_name, d.verb]
	if d.punch > 0.0:
		line += " +%d punch" % int(d.punch)
	return line


static func shop_line(part_id: String, level := 1) -> String:
	var d: Resource = def_at(part_id, level)
	if d == null:
		return display_name(part_id)
	var line := "%s. %s" % [d.display_name, d.text.substr(0, 1).to_upper() + d.text.substr(1)]
	if d.punch > 0.0 and not "punch" in d.text.to_lower():
		line += ". +%d punch" % int(d.punch)
	return line


static func offer_shop_line(part_id: String, held: Array) -> String:
	return shop_line(part_id, next_level(part_id, held))


static func milestone_ids() -> Array:
	var list: Array = []
	for key in rows():
		if rows()[key].get("milestone_only", false):
			list.append(key)
	return list


static func tag_sets(held: Array) -> Array:
	var sets: Array = []
	for part_id in held:
		sets.append(tags_of(part_id))
	return sets


static var _maker_of := {}


static func maker_of(part_id: String) -> String:
	if not _maker_of.has(part_id):
		_maker_of[part_id] = String(row(part_id).get("maker", "")) if has(part_id) else ""
	return _maker_of[part_id]


static func priced_count(held: Array) -> int:
	return held.filter(func(part_id): return not Relics.is_relic(String(part_id))).size()


static func maker_counts(held: Array) -> Dictionary:
	var seen := {}
	var out := {}
	for part_id in held:
		var maker := maker_of(String(part_id))
		if maker == "" or seen.has(part_id):
			continue
		seen[part_id] = true
		out[maker] = int(out.get(maker, 0)) + 1
	return out


static func completed_by(part_id: String, held: Array) -> String:
	if part_id in held:
		return ""
	return Synergies.completed_by(maker_counts(held), maker_of(part_id))


static func started_by(part_id: String, held: Array) -> String:
	if part_id in held:
		return ""
	return Synergies.started_by(maker_counts(held), maker_of(part_id))


static func completing_part(held: Array, pool: Array) -> String:
	var counted := maker_counts(held)
	var wanted := {}
	for trick_id in Synergies.ROWS:
		var call := Synergies.callout(trick_id)
		if call.is_empty() or not Synergies.in_play(trick_id) or int(counted.get(Synergies.ROWS[trick_id]["maker"], 0)) != Synergies.AT - 1:
			continue
		if call["a"] in held and not call["b"] in held:
			wanted[call["b"]] = true
		elif call["b"] in held and not call["a"] in held:
			wanted[call["a"]] = true
	for key in pool:
		if wanted.has(key):
			return key
	return ""


static func floor_gate(rng: RandomNumberGenerator, picks: Array, class_id: String, held: Array,
		offered: Dictionary = {}, count := 2) -> Array:
	if picks.is_empty() or picks.any(func(key): return rung_of(key) >= RUNG_FLOOR and changes_behaviour(key)):
		return picks
	var out := picks.duplicate()
	var slot := -1
	for i in out.size():
		if rung_of(out[i]) == RUNG_FLOOR:
			slot = i
			break
	if slot < 0:
		slot = 0
		while slot < out.size() and (out[slot] in PATTERN_PARTS or rung_of(out[slot]) > RUNG_FLOOR):
			slot += 1
	if slot >= out.size() and out.size() >= count:
		if out.any(func(key): return rung_of(key) > RUNG_FLOOR):
			return picks
		slot = out.size()
		for i in range(out.size() - 1, -1, -1):
			if rung_of(out[i]) < RUNG_FLOOR:
				slot = i
				break
		if slot >= out.size():
			return picks
	var others: Array = out.filter(func(key): return key != out[slot]) if slot < out.size() else out
	var needs_hitter: bool = slot < out.size() and def(out[slot]) != null and def(out[slot]).hits_harder() \
		and not others.any(func(key): return def(key) != null and def(key).hits_harder())
	var plain: Array = offer_pool(class_id, ["rare"]).filter(func(key): return not changes_behaviour(key) \
		or (needs_hitter and not def(key).hits_harder()))
	var cobalt: Array = roll(rng, ["rare"], class_id, held, 1, picks + plain, offered)
	if cobalt.is_empty():
		var soft: Array = offer_pool(class_id, ["rare"]).filter(func(key): return needs_hitter and not def(key).hits_harder())
		cobalt = roll(rng, ["rare"], class_id, held, 1, picks + soft, offered)
	if cobalt.is_empty():
		return picks
	if slot < out.size():
		out[slot] = cobalt[0]
	else:
		out.append(cobalt[0])
	return out


static func changes_behaviour(part_id: String) -> bool:
	if is_grapple_mutation_part(part_id):
		return true
	var d: Resource = def(part_id)
	if d == null:
		return false
	return d.changes_behaviour() or String(d.effect.get("do", "")) in VERB_EFFECTS


static func is_high_impact(part_id: String) -> bool:
	if Relics.is_relic(part_id) or is_grapple_mutation_part(part_id) or changes_behaviour(part_id):
		return true
	if Items.grapple_mutation_of(part_id) != "":
		return true
	var d: Resource = def(part_id)
	return d != null and d.bits != 0 and rung_of(part_id) >= RUNG_FLOOR


static func world_for_stage(stage: int) -> int:
	return 1 if stage < WORLD_ESCALATION_STAGE_W2 else (2 if stage < WORLD_ESCALATION_STAGE_W3 else 3)


static func stage_rare_mult(stage: int) -> float:
	return float(STAGE_RARE_MULT.get(world_for_stage(stage), 1.0))


static func source_rarities(source: String, stage := 1) -> Array:
	var table: Dictionary = SOURCE_RARITIES_BY_WORLD.get(world_for_stage(stage), SOURCE_RARITIES)
	return (table.get(source, SOURCE_RARITIES.get(source, ["common"])) as Array).duplicate()


static func rung_of(part_id: String) -> int:
	var d: Resource = def(part_id)
	return maxi(0, ItemGen.RARITIES.find(ItemGen.resolve_rarity(String(d.rarity)))) if d != null else 0


static func gate_rarities(bonus_cores: int, stage := 1) -> Array:
	var tiers: Array = GATE_RARITIES_BY_WORLD.get(world_for_stage(stage), GATE_RARITIES_BY_WORLD[1])
	return (tiers[clampi(bonus_cores, 0, tiers.size() - 1)] as Array).duplicate()


static func listed_only() -> bool:
	return Synergies.table != null and Synergies.table.parts_listed()


static func offer_pool(class_id: String, rarities: Array) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var pool: Array = []
	var all := all_rows()
	var listed := listed_only()
	for key in all:
		var r: Dictionary = all[key]
		if listed and not Synergies.table.part_in_play(key) and not opened_items.has(key):
			continue
		if is_burden(key):
			continue
		if not r["rarity"] in rarities or r.get("shop_only", false) or not seam_met(r.get("needs", "")):
			continue
		var only: String = r.get("class_id", "")
		if only != "" and only != class_id:
			continue
		pool.append(key)
	return pool


static func bucket_of(part_id: String) -> String:
	var r := row(part_id)
	var family := String(r.get("family", ""))
	var touches := String(r.get("touches", ""))
	if touches in ["haul", "special"] or family == "class":
		return "skill"
	if family in ["weapon", "pattern"] or touches == "fire":
		return "weapon"
	if family == "mobility" or r.get("mods", {}).has("cruise"):
		return "movement"
	var shown: String = r.get("icon", PartDef.ICON_FOR_FAMILY.get(family, "utility"))
	match shown:
		"defense":
			return "defence"
		"damage", "transform":
			return "weapon"
		"mobility":
			return "movement"
	return "skill"


static func in_kit(class_id: String, part_id: String) -> bool:
	if not KITS.has(class_id):
		return false
	var r := row(part_id)
	if String(r.get("class_id", "")) == class_id:
		return true
	var tags: Array = KITS[class_id].get(bucket_of(part_id), [])
	return r.get("tags", []).any(func(tag): return tag in tags)


static func _neutral_slot(class_id: String, pool: Array, offered: Dictionary) -> Array:
	return pool.filter(func(key): return key in NEUTRAL_SHELF and not in_kit(class_id, key) \
		and int(offered.get(key, 0)) < NEUTRAL_REPEAT_CAP)


static func _uncapped(class_id: String, pool: Array, offered: Dictionary) -> Array:
	return pool.filter(func(key): return not key in NEUTRAL_SHELF or in_kit(class_id, key) \
		or int(offered.get(key, 0)) < NEUTRAL_REPEAT_CAP)


static func _lean_slot(rng: RandomNumberGenerator, rarity: String, class_id: String, pool: Array,
		offered: Dictionary, picks: Array, exclude: Array, nudge: Dictionary = {}) -> String:
	if not listed_only() and rng.randf() < (1.0 - KIT_SHARE) * GENERATED_SHARE:
		var recipe := ItemGen.roll_id(rng, rarity)
		return "" if recipe in picks or recipe in exclude else recipe
	var slot := slot_weights(rarity, class_id, pool, offered, nudge)
	if slot["candidates"].is_empty():
		return ""
	return _pick_weight(rng, slot["candidates"], slot["weights"])


static func slot_weights(rarity: String, class_id: String, pool: Array, offered: Dictionary,
		nudge: Dictionary = {}) -> Dictionary:
	var kit: Dictionary = KITS[class_id]
	var open := _uncapped(class_id, pool, offered)
	var all := all_rows()
	var candidates: Array = open.filter(func(key): return String(all.get(key, {}).get("rarity", "common")) == rarity)
	if candidates.is_empty():
		candidates = open
	if candidates.is_empty():
		return {"candidates": [], "weights": {}}
	var groups := {"moving": [], "still": [], "shelf": [], "rest": []}
	for key in candidates:
		if in_kit(class_id, key):
			groups["moving" if bucket_of(key) == "movement" else "still"].append(key)
		elif key in NEUTRAL_SHELF:
			groups["shelf"].append(key)
		else:
			groups["rest"].append(key)
	var moving := MOVEMENT_SHARE if kit.has("movement") \
		else minf(MOVEMENT_SHARE, CLASS_MOVEMENT_SHARE * groups["moving"].size())
	var neutral := 1.0 - KIT_SHARE
	var rest_share := neutral * REST_OF_NEUTRAL if not groups["rest"].is_empty() else 0.0
	var share := {"moving": moving, "still": KIT_SHARE - moving, "shelf": neutral - rest_share, "rest": rest_share}
	if groups["moving"].is_empty():
		share["still"] += share["moving"]
		share["moving"] = 0.0
	if groups["still"].is_empty():
		if not groups["shelf"].is_empty():
			share["shelf"] += share["still"]
		else:
			share["rest"] += share["still"]
		share["still"] = 0.0
	if groups["shelf"].is_empty():
		if not groups["still"].is_empty():
			share["still"] += share["shelf"]
		else:
			share["rest"] += share["shelf"]
		share["shelf"] = 0.0
	if groups["rest"].is_empty() and share["rest"] > 0.0:
		share["moving"] += share["rest"]
		share["rest"] = 0.0
	var weights := {}
	for name in groups:
		var raw := {}
		var sum := 0.0
		for key in groups[name]:
			var b := bucket_of(key)
			var lean := 1.0
			if name == "shelf" and kit.has(b) and (b != "weapon" or kit.has("movement")):
				lean = NEUTRAL_LEAN
			elif (name == "shelf" or (name == "rest" and not groups["shelf"].is_empty())) and b == "weapon" and not kit.has("weapon"):
				lean = NEUTRAL_WEAPON_EASE
			raw[key] = lean / (1.0 + offered.get(key, 0))
			sum += raw[key]
		for key in raw:
			weights[key] = share[name] * raw[key] / sum
	var excess := 0.0
	for key in groups["moving"] + groups["still"]:
		if weights[key] > KIT_PART_CAP:
			excess += weights[key] - KIT_PART_CAP
			weights[key] = KIT_PART_CAP
	for name in ["shelf", "rest"]:
		if excess > 0.0 and not groups[name].is_empty():
			var room := 0.0
			for key in groups[name]:
				room += weights[key]
			for key in groups[name]:
				weights[key] += excess * (weights[key] / room if room > 0.0 else 1.0 / groups[name].size())
			excess = 0.0
	if not nudge.is_empty():
		for name in groups:
			var part: Dictionary = {}
			for key in groups[name]:
				part[key] = weights[key]
			part = _nudged(part, nudge)
			for key in part:
				weights[key] = part[key]
	return {"candidates": candidates, "weights": weights}


static func _pick_weight(rng: RandomNumberGenerator, keys: Array, weights: Dictionary) -> String:
	var total := 0.0
	for key in keys:
		total += weights.get(key, 0.0)
	var x := rng.randf()
	if total <= 0.0:
		return keys[mini(int(x * keys.size()), keys.size() - 1)]
	x *= total
	for key in keys:
		x -= weights.get(key, 0.0)
		if x < 0.0:
			return key
	return keys[-1]


static func milestone_for(event_id: String, held: Array) -> String:
	if MILESTONE_FOR_EVENT.has(event_id):
		return MILESTONE_FOR_EVENT[event_id]
	for key in MILESTONE_ORDER:
		if not key in held:
			return key
	return MILESTONE_ORDER[0]


static func roll(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		exclude: Array = [], offered: Dictionary = {}) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var pool: Array = offer_pool(class_id, rarities).filter(func(key): return not key in exclude and not maxed(key, held))
	var picks: Array = []
	var leans := KITS.has(class_id)
	var nudge := answer_nudge(class_id, pool, maker_nudge(held, pool))
	var bait := _bait(class_id, held, pool, offered, count)
	if bait != "" and rng.randf() < SYNERGY_BAIT:
		picks.append(bait)
		pool.erase(bait)
	var tries := 0
	while picks.size() < count and not pool.is_empty() and tries < count * 8:
		tries += 1
		var rarity := _pick_rarity(rng, rarities)
		if leans:
			var slot := _lean_slot(rng, rarity, class_id, pool, offered, picks, exclude, nudge)
			if slot != "":
				picks.append(slot)
				pool.erase(slot)
			continue
		if not listed_only() and rng.randf() < GENERATED_SHARE:
			var recipe := ItemGen.roll_id(rng, rarity)
			if not recipe in picks and not recipe in exclude and not stacked_out(recipe, held):
				picks.append(recipe)
			continue
		var bucket: Array = pool.filter(func(key): return String(all_rows().get(key, {}).get("rarity", "common")) == rarity)
		if bucket.is_empty():
			bucket = pool
		var chosen := _weighted(rng, bucket, offered, {}, nudge)
		picks.append(chosen)
		pool.erase(chosen)
	if picks.size() >= 2 and not picks.any(func(key): return def(key).hits_harder()):
		var harder: Array = pool.filter(func(key): return def(key).hits_harder())
		if leans:
			var kit: Array = harder.filter(func(key): return in_kit(class_id, key))
			var still: Array = kit.filter(func(key): return bucket_of(key) != "movement")
			var shelf: Array = _neutral_slot(class_id, harder, offered)
			for side in [still, kit, shelf, _uncapped(class_id, harder, offered)]:
				if not side.is_empty():
					harder = side
					break
		var at := picks.size() - 1
		if leans:
			var first := 1 if picks[0] == bait else 0
			var prefer_kit: bool = not (KITS[class_id] as Dictionary).has("weapon") and not harder.is_empty() and in_kit(class_id, harder[0])
			var chosen := -1
			if prefer_kit:
				for i in range(picks.size() - 1, first - 1, -1):
					if in_kit(class_id, picks[i]) and bucket_of(picks[i]) != "movement":
						chosen = i
						break
			if chosen < 0:
				for i in range(picks.size() - 1, first - 1, -1):
					if not (in_kit(class_id, picks[i]) and bucket_of(picks[i]) == "movement"):
						chosen = i
						break
			if chosen >= 0:
				at = chosen
		if not harder.is_empty():
			picks[at] = harder[rng.randi_range(0, harder.size() - 1)]
	if leans:
		_keep_a_neutral(rng, class_id, picks, pool, offered, 1 if not picks.is_empty() and picks[0] == bait else 0)
	return _swap_stacked_out(rng, class_id, held, picks, pool, offered)


static func _keep_a_neutral(rng: RandomNumberGenerator, class_id: String, picks: Array, pool: Array,
		offered: Dictionary, first: int) -> void:
	if picks.size() < 2 or picks.any(func(key): return in_kit(class_id, key) or key in NEUTRAL_SHELF):
		return
	var shelf := _neutral_slot(class_id, pool.filter(func(key): return not key in picks), offered)
	if shelf.is_empty():
		return
	var hitters: Array = picks.filter(func(key): return def(key).hits_harder())
	for i in range(first, picks.size()):
		if rarity_of(picks[i]) != rarity_of(shelf[0]):
			continue
		if picks.size() < 2 or hitters.size() != 1 or picks[i] != hitters[0]:
			picks[i] = shelf[rng.randi_range(0, shelf.size() - 1)]
			return


static func _bait(class_id: String, held: Array, pool: Array, offered: Dictionary, count: int) -> String:
	if not KITS.has(class_id):
		return completing_part(held, pool)
	var open := _uncapped(class_id, pool, offered)
	var near := completing_part(held, _near(class_id, open))
	return near if near != "" or count >= 2 else completing_part(held, open)


static func _near(class_id: String, pool: Array) -> Array:
	return pool.filter(func(key): return in_kit(class_id, key) or key in NEUTRAL_SHELF)


static func maker_nudge(held: Array, pool: Array) -> Dictionary:
	if not maker_nudge_on:
		return {}
	var pieces := {}
	var table := all_rows()
	for part_id in held:
		var maker := String(table.get(part_id, {}).get("maker", ""))
		if maker != "":
			if not pieces.has(maker):
				pieces[maker] = {}
			pieces[maker][part_id] = true
	var out := {}
	for part_id in pool:
		var maker := String(table.get(part_id, {}).get("maker", ""))
		if maker != "" and (pieces.get(maker, {}) as Dictionary).size() >= MAKER_NUDGE_AT and not part_id in held:
			out[part_id] = MAKER_NUDGE
	return out


static func answers_of(part_id: String) -> Array:
	return ANSWERS.get(part_id, [])


static func answer_nudge(class_id: String, pool: Array, nudge: Dictionary) -> Dictionary:
	if not answer_nudge_on or Nemesis.of(class_id).is_empty():
		return nudge
	var answering := _answering(class_id)
	var out := nudge
	var copied := false
	for part_id in pool:
		if answering.has(part_id):
			if not copied:
				out = nudge.duplicate()
				copied = true
			out[part_id] = float(out.get(part_id, 1.0)) * Nemesis.OFFER_WEIGHT
	return out


static var _answering_by_class := {}


static func _answering(class_id: String) -> Dictionary:
	if not _answering_by_class.has(class_id):
		var ids := {}
		for part_id in ANSWERS:
			if Nemesis.answers(class_id, ANSWERS[part_id]):
				ids[part_id] = true
		_answering_by_class[class_id] = ids
	return _answering_by_class[class_id]


static func _nudged(raw: Dictionary, nudge: Dictionary) -> Dictionary:
	if nudge.is_empty():
		return raw
	var touched := false
	for key in nudge:
		if raw.has(key):
			touched = true
			break
	if not touched:
		return raw
	var before := {}
	var after := {}
	var out := {}
	var buckets := {}
	for key in raw:
		var b := bucket_of(key)
		buckets[key] = b
		out[key] = float(raw[key]) * float(nudge.get(key, 1.0))
		before[b] = float(before.get(b, 0.0)) + float(raw[key])
		after[b] = float(after.get(b, 0.0)) + out[key]
	for key in out:
		var b: String = buckets[key]
		if after[b] > 0.0:
			out[key] *= before[b] / after[b]
	return out


static func _weighted(rng: RandomNumberGenerator, bucket: Array, offered: Dictionary, lean: Dictionary = {},
		nudge: Dictionary = {}) -> String:
	var raw := {}
	var total := 0.0
	for key in bucket:
		raw[key] = lean.get(key, 1.0) / (1.0 + offered.get(key, 0))
	raw = _nudged(raw, nudge)
	for key in bucket:
		total += raw[key]
	var x := rng.randf() * total
	for key in bucket:
		x -= raw[key]
		if x < 0.0:
			return key
	return bucket[-1]


static func holds_pattern(held: Array) -> bool:
	return held.any(func(key): return def(key) != null and not def(key).patterns.is_empty())


static func dominant_archetype(held: Array) -> String:
	if held.is_empty():
		return ""
	var scores := {}
	var seen := {}
	for raw_id in held:
		var part_id := String(raw_id)
		if seen.has(part_id):
			continue
		seen[part_id] = true
		var gmut := grapple_mutation_id_of(part_id)
		var maker := maker_of(part_id)
		for arch in ARCHETYPES:
			var spec: Dictionary = ARCHETYPES[arch]
			var pts := 0
			if part_id in (spec["anchors"] as Array):
				pts += 2
			elif gmut != "" and gmut in (spec["grapple_muts"] as Array):
				pts += 2
			elif Relics.is_relic(part_id) and maker in (spec["makers"] as Array):
				pts += 1
			if pts > 0:
				scores[arch] = int(scores.get(arch, 0)) + pts
	var best_arch := ""
	var best_score := 0
	for arch in ARCHETYPES:
		var sc := int(scores.get(arch, 0))
		if sc >= ARCHETYPE_NUDGE_AT * 2 and sc > best_score:
			best_score = sc
			best_arch = arch
	return best_arch


static func archetype_nudge(held: Array, pool: Array) -> Dictionary:
	if not archetype_nudge_on:
		return {}
	var arch := dominant_archetype(held)
	if arch == "":
		return {}
	var spec: Dictionary = ARCHETYPES[arch]
	var anchors: Array = spec["anchors"]
	var gmuts: Array = spec["grapple_muts"]
	var out := {}
	for part_id in pool:
		var pid := String(part_id)
		if pid in held:
			continue
		var gm := Items.grapple_mutation_of(pid)
		if pid in anchors or (gm != "" and gm in gmuts):
			out[pid] = ARCHETYPE_NUDGE
	return out


static func world_nudge(stage: int, pool: Array) -> Dictionary:
	if stage < WORLD_ESCALATION_STAGE_W2:
		return {}
	var world := world_for_stage(stage)
	var table := all_rows()
	var out := {}
	for part_id in pool:
		var pid := String(part_id)
		var row_world := int(table.get(pid, {}).get("world", 0))
		if row_world == world:
			out[pid] = WORLD_SIGNATURE_NUDGE
		elif pid in WORLD_VERB_PARTS or changes_behaviour(pid):
			out[pid] = WORLD_VERB_NUDGE
	return out


static func _merge_nudges(base: Dictionary, extra: Dictionary) -> Dictionary:
	if extra.is_empty():
		return base
	var out := base.duplicate()
	for key in extra:
		out[key] = float(out.get(key, 1.0)) * float(extra[key])
	return out


static func completing_archetype_part(held: Array, pool: Array) -> String:
	var base := completing_part(held, pool)
	if base != "":
		return base
	var evos := Synergies.all_evolutions()
	for evo_id in evos:
		if evo_id in held:
			continue
		var pair: Array = evos[evo_id]
		if pair.size() != 2:
			continue
		if pair[0] in held and not pair[1] in held and pair[1] in pool:
			return String(pair[1])
		if pair[1] in held and not pair[0] in held and pair[0] in pool:
			return String(pair[0])
	var counted := maker_counts(held)
	for maker in MAKER_SET_PIECES:
		var need := int(MAKER_SET_PIECES[maker])
		if int(counted.get(maker, 0)) == need - 1:
			for key in pool:
				if not key in held and maker_of(String(key)) == maker:
					return String(key)
	return ""


static func roll_for_stage(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		stage := 1, exclude: Array = [], offered: Dictionary = {}, high_impact := false) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var full_pool: Array = offer_pool(class_id, rarities).filter(func(key): return not key in exclude and not maxed(key, held) and not stacked_out(key, held))
	if full_pool.is_empty():
		return []
	var pool := full_pool
	if high_impact:
		var impact_pool: Array = full_pool.filter(func(key): return is_high_impact(key))
		if impact_pool.size() >= count:
			pool = impact_pool
		elif not impact_pool.is_empty():
			pool = impact_pool
	var picks: Array = []
	var leans := KITS.has(class_id)
	var nudge := maker_nudge(held, pool)
	nudge = _merge_nudges(nudge, archetype_nudge(held, pool))
	nudge = _merge_nudges(nudge, world_nudge(stage, pool))
	nudge = answer_nudge(class_id, pool, nudge)
	var bait_pool := _near(class_id, _uncapped(class_id, pool, offered)) if leans else pool
	var bait := completing_archetype_part(held, bait_pool)
	if bait == "" and not bait_pool.is_empty():
		bait = completing_archetype_part(held, pool)
	var bait_chance := HIGH_IMPACT_SYNERGY_BAIT if high_impact else SYNERGY_BAIT
	if bait != "" and rng.randf() < bait_chance:
		picks.append(bait)
		pool.erase(bait)
	var rare_mult := stage_rare_mult(stage)
	var tries := 0
	while picks.size() < count and not pool.is_empty() and tries < count * 8:
		tries += 1
		var rarity := _pick_rarity_scaled(rng, rarities, rare_mult)
		if leans:
			var slot := _lean_slot(rng, rarity, class_id, pool, offered, picks, exclude, nudge)
			if slot != "":
				picks.append(slot)
				pool.erase(slot)
			continue
		if not listed_only() and rng.randf() < GENERATED_SHARE:
			var recipe := ItemGen.roll_id(rng, rarity)
			if not recipe in picks and not recipe in exclude and not stacked_out(recipe, held):
				picks.append(recipe)
			continue
		var bucket: Array = pool.filter(func(key): return String(all_rows().get(key, {}).get("rarity", "common")) == rarity)
		if bucket.is_empty():
			bucket = pool
		var chosen := _weighted(rng, bucket, offered, {}, nudge)
		picks.append(chosen)
		pool.erase(chosen)
	if picks.size() < count and pool != full_pool:
		var rest: Array = full_pool.filter(func(key): return not key in picks)
		for extra in roll(rng, rarities, class_id, held, count - picks.size(), exclude + picks, offered):
			if not extra in picks:
				picks.append(extra)
		if picks.size() < count and not rest.is_empty():
			for key in rest:
				if picks.size() >= count:
					break
				if not key in picks:
					picks.append(key)
	if picks.size() >= 2 and not picks.any(func(key): return def(key).hits_harder()):
		var harder: Array = pool.filter(func(key): return def(key).hits_harder())
		if leans:
			var kit: Array = harder.filter(func(key): return in_kit(class_id, key))
			var still: Array = kit.filter(func(key): return bucket_of(key) != "movement")
			var shelf: Array = _neutral_slot(class_id, harder, offered)
			for side in [still, kit, shelf, _uncapped(class_id, harder, offered)]:
				if not side.is_empty():
					harder = side
					break
		var at := picks.size() - 1
		if leans:
			var first := 1 if not picks.is_empty() and picks[0] == bait else 0
			var prefer_kit: bool = not (KITS[class_id] as Dictionary).has("weapon") and not harder.is_empty() and in_kit(class_id, harder[0])
			var chosen := -1
			if prefer_kit:
				for i in range(picks.size() - 1, first - 1, -1):
					if in_kit(class_id, picks[i]) and bucket_of(picks[i]) != "movement":
						chosen = i
						break
			if chosen < 0:
				for i in range(picks.size() - 1, first - 1, -1):
					if not (in_kit(class_id, picks[i]) and bucket_of(picks[i]) == "movement"):
						chosen = i
						break
			if chosen >= 0:
				at = chosen
		if not harder.is_empty():
			picks[at] = harder[rng.randi_range(0, harder.size() - 1)]
	if leans and not high_impact:
		_keep_a_neutral(rng, class_id, picks, pool, offered, 1 if not picks.is_empty() and picks[0] == bait else 0)
	return _swap_stacked_out(rng, class_id, held, picks, full_pool, offered)


static func roll_high_impact(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		exclude: Array = [], offered: Dictionary = {}, stage := 1, allow_pilot_relic := false, tree = null) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var picks: Array = []
	var slice_locked: bool = listed_only() and not Synergies.table.part_in_play("slag_pike")
	if allow_pilot_relic and not slice_locked and "relic" in rarities and count >= 1 and class_id in Relics.PILOTS:
		var world := world_for_stage(stage)
		var relic_pool := Relics.eligible_swaps(class_id, Relics.held(held), tree, world, stage >= WORLD_ESCALATION_STAGE_W2)
		if relic_pool.is_empty():
			relic_pool = Relics.eligible(class_id, Relics.held(held), tree, world, true)
		relic_pool = relic_pool.filter(func(id): return not Relics.part_of(id) in exclude)
		if not relic_pool.is_empty():
			var has_other := not offer_pool(class_id, rarities.filter(func(r): return r != "relic")).is_empty()
			var relic_chance := 0.45 if has_other else 1.0
			if rng.randf() < relic_chance:
				var chosen_relic := String(relic_pool[rng.randi_range(0, relic_pool.size() - 1)])
				picks.append(Relics.part_of(chosen_relic))
	var need := count - picks.size()
	if need > 0:
		var rolled := roll_for_stage(rng, rarities, class_id, held, need, stage, exclude + picks, offered, true)
		picks.append_array(rolled)
	return picks


static func roll_gate(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		stage: int, offered: Dictionary = {}) -> Array:
	rarities = ItemGen.resolve_rarities(rarities)
	var picks: Array = roll(rng, rarities, class_id, held, count, [], offered)
	if stage != PATTERN_GUARANTEE_STAGE or count < 1 or holds_pattern(held) \
			or picks.any(func(key): return key in PATTERN_PARTS):
		return picks
	var eligible: Array = PATTERN_PARTS.filter(func(key): return def(key).rarity in rarities)
	if eligible.is_empty():
		eligible = PATTERN_PARTS.duplicate()
	if KITS.has(class_id):
		var own: Array = eligible.filter(func(key): return in_kit(class_id, key))
		eligible = own if not own.is_empty() else eligible
	var pattern: String = eligible[rng.randi_range(0, eligible.size() - 1)]
	if picks.size() < count:
		picks.append(pattern)
	elif picks.size() >= 2 or picks[0] != _bait(class_id, held, offer_pool(class_id, rarities), offered, count):
		picks[picks.size() - 1] = pattern
	return picks
