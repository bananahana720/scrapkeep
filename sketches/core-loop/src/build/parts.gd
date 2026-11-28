extends RefCounted

const PartDef := preload("res://src/build/part_def.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Items := preload("res://src/build/items.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Relics := preload("res://src/build/relics.gd")
const HotwireRules := preload("res://src/build/hotwire_rules.gd")
const PartMutations := preload("res://src/build/part_mutations.gd")
const PartOffers := preload("res://src/build/part_offers.gd")


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

const SOURCE_RARITIES := PartOffers.SOURCE_RARITIES
const GRAPPLE_SWAP_SLOTS := PartMutations.GRAPPLE_SWAP_SLOTS
const GRAPPLE_MUTATIONS := PartMutations.GRAPPLE_MUTATIONS


static func micro_mutation(part_id: String) -> Dictionary:
	return PartMutations.micro_mutation(part_id)


static func has_micro_mutation(held: Array, part_id: String) -> bool:
	return PartMutations.has_micro_mutation(held, part_id)


static func grapple_mutation_id_of(part_id: String) -> String:
	return PartMutations.grapple_mutation_id_of(part_id)


static func grapple_mutation(id_or_part: String) -> Dictionary:
	return PartMutations.grapple_mutation(id_or_part)


static func active_grapple_mutations(held: Array, maker_muts: Array = []) -> Dictionary:
	return PartMutations.active_grapple_mutations(held, maker_muts, maker_counts)


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
	return PartOffers.pick_rarity_scaled(rng, allowed, rare_mult, active_tier())

static var _rows := {}
static var _all_rows := {}
static var seams := {}
static var opened_items := {}


static func set_seams(next: Dictionary) -> void:
	seams = next


static func set_opened_items(next: Dictionary) -> void:
	opened_items = next


static func reset_for_tests() -> void:
	PartOffers.reset_for_tests()
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
	if PartMutations.is_grapple_mutation_part(part_id):
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
		or PartMutations.is_grapple_mutation_part(part_id) \
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
	return PartMutations.grapple_mut_spec(part_id)


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


static func _offer_ops() -> Dictionary:
	return {
		"all_rows": all_rows,
		"row": row,
		"def": def,
		"is_burden": is_burden,
		"seam_met": seam_met,
		"opened_items": opened_items,
		"active_tier": active_tier,
		"maker_of": maker_of,
		"maker_counts": maker_counts,
		"maxed": maxed,
		"stacked_out": stacked_out,
		"rarity_of": rarity_of,
	}


static func completing_part(held: Array, pool: Array) -> String:
	return PartOffers.completing_part(held, pool, maker_counts)


static func floor_gate(rng: RandomNumberGenerator, picks: Array, class_id: String, held: Array,
		offered: Dictionary = {}, count := 2) -> Array:
	return PartOffers.floor_gate(rng, picks, class_id, held, offered, count, _offer_ops())


static func changes_behaviour(part_id: String) -> bool:
	return PartOffers.changes_behaviour(part_id, def)


static func is_high_impact(part_id: String) -> bool:
	return PartOffers.is_high_impact(part_id, def)


static func rung_of(part_id: String) -> int:
	return PartOffers.rung_of(part_id, def)


static func gate_rarities(bonus_cores: int, stage := 1) -> Array:
	return PartOffers.gate_rarities(bonus_cores, stage)


static func offer_pool(class_id: String, rarities: Array) -> Array:
	return PartOffers.offer_pool(class_id, rarities, _offer_ops())


static func odds_for(rarities: Array, class_id: String) -> Array:
	return PartOffers.odds_for(rarities, class_id, _offer_ops())


static func bucket_of(part_id: String) -> String:
	return PartOffers.bucket_of(part_id, row)


static func in_kit(class_id: String, part_id: String) -> bool:
	return PartOffers.in_kit(class_id, part_id, row)


static func slot_weights(rarity: String, class_id: String, pool: Array, offered: Dictionary,
		nudge: Dictionary = {}) -> Dictionary:
	return PartOffers.slot_weights(rarity, class_id, pool, offered, nudge, _offer_ops())


static func milestone_for(event_id: String, held: Array) -> String:
	return PartOffers.milestone_for(event_id, held)


static func roll(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		exclude: Array = [], offered: Dictionary = {}) -> Array:
	return PartOffers.roll(rng, rarities, class_id, held, count, exclude, offered, _offer_ops())


static func maker_nudge(held: Array, pool: Array) -> Dictionary:
	return PartOffers.maker_nudge(held, pool, _offer_ops())


static func _nudged(raw: Dictionary, nudge: Dictionary) -> Dictionary:
	return PartOffers.nudged(raw, nudge, row)


static func _weighted(rng: RandomNumberGenerator, bucket: Array, offered: Dictionary, lean: Dictionary = {},
		nudge: Dictionary = {}) -> String:
	return PartOffers.weighted(rng, bucket, offered, lean, nudge, row)


static func _keep_a_neutral(rng: RandomNumberGenerator, class_id: String, picks: Array, pool: Array,
		offered: Dictionary, first: int) -> void:
	PartOffers.keep_a_neutral(rng, class_id, picks, pool, offered, first, _offer_ops())


static func holds_pattern(held: Array) -> bool:
	return PartOffers.holds_pattern(held, def)


static func dominant_archetype(held: Array) -> String:
	return PartOffers.dominant_archetype(held, maker_of)


static func archetype_nudge(held: Array, pool: Array) -> Dictionary:
	return PartOffers.archetype_nudge(held, pool, _offer_ops())


static func completing_archetype_part(held: Array, pool: Array) -> String:
	return PartOffers.completing_archetype_part(held, pool, _offer_ops())


static func roll_for_stage(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		stage := 1, exclude: Array = [], offered: Dictionary = {}, high_impact := false) -> Array:
	return PartOffers.roll_for_stage(rng, rarities, class_id, held, count, stage, exclude, offered, high_impact, _offer_ops())


static func roll_high_impact(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		exclude: Array = [], offered: Dictionary = {}, stage := 1, allow_pilot_relic := false, tree = null) -> Array:
	return PartOffers.roll_high_impact(rng, rarities, class_id, held, count, exclude, offered, stage, allow_pilot_relic, tree, _offer_ops())


static func roll_gate(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		stage: int, offered: Dictionary = {}) -> Array:
	return PartOffers.roll_gate(rng, rarities, class_id, held, count, stage, offered, _offer_ops())
