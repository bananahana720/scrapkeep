extends RefCounted

const PartDef := preload("res://src/build/part_def.gd")
const Synergies := preload("res://src/build/synergies.gd")

# The parts catalogue (TADR-008): one row per part, turned into typed PartDef resources
# once and cached. Every effect is a multiplier on a named knob, a pattern level, an
# element trigger or a pickup dial, so build_sheet.gd can fold any list of held parts
# into the same sheet every time. The ids of the weapon-pattern transformers and the
# weapon knobs are the seam with combat; SEAMS.md lists them.
#
# The scaling curve lives in the numbers: tier 1 is +10 to 15%, tier 2 is +25%, tier 3
# is +50%, and copies stack multiplicatively. Pattern levels add. A stage-1 build is
# modest; ten late parts multiply into an absurd one (build_parts_test measures it).

const CATALOGUE := {
	# Weapon tiers: damage, rate and range, three tiers each.
	"hot_rivets": {"name": "Hot Rivets", "text": "+12% weapon damage", "rarity": "common", "tier": 1, "family": "weapon",
		"mods": {"weapon_damage": 1.12}},
	"slag_rounds": {"name": "Slag Rounds", "text": "+25% weapon damage", "rarity": "rare", "tier": 2, "family": "weapon",
		"mods": {"weapon_damage": 1.25}},
	"sunforged_core": {"name": "Sunforged Core", "text": "+50% weapon damage", "rarity": "epic", "tier": 3, "family": "weapon",
		"mods": {"weapon_damage": 1.5}},
	"loose_trigger": {"name": "Loose Trigger", "text": "+10% fire rate", "rarity": "common", "tier": 1, "family": "weapon",
		"mods": {"weapon_rate": 1.1}},
	"double_feed": {"name": "Double Feed", "text": "+25% fire rate", "rarity": "rare", "tier": 2, "family": "weapon",
		"mods": {"weapon_rate": 1.25}},
	"gatling_heart": {"name": "Gatling Heart", "text": "+50% fire rate", "rarity": "epic", "tier": 3, "family": "weapon",
		"mods": {"weapon_rate": 1.5}},
	"long_barrel": {"name": "Long Barrel", "text": "+12% weapon range", "rarity": "common", "tier": 1, "family": "weapon",
		"mods": {"weapon_range": 1.12}},
	"focus_lens": {"name": "Focus Lens", "text": "+25% weapon range", "rarity": "rare", "tier": 2, "family": "weapon",
		"mods": {"weapon_range": 1.25}},
	"horizon_optic": {"name": "Horizon Optic", "text": "+50% range, +15% damage", "rarity": "epic", "tier": 3, "family": "weapon",
		"mods": {"weapon_range": 1.5, "weapon_damage": 1.15}},

	# Weapon-pattern transformers. The part id is the pattern id, and each copy adds a
	# level. Combat owns what a level draws and caps it for clarity.
	"cross_split": {"name": "Cross Split", "text": "shots split into a cross", "rarity": "rare", "tier": 2, "family": "pattern",
		"patterns": {"cross_split": 1}},
	"spiral_wave": {"name": "Spiral Wave", "text": "shots spiral out in a wave", "rarity": "rare", "tier": 2, "family": "pattern",
		"patterns": {"spiral_wave": 1}},
	"chain_arc": {"name": "Chain Arc", "text": "hits chain to a nearby enemy", "rarity": "rare", "tier": 2, "family": "pattern",
		"patterns": {"chain_arc": 1}},

	# Mobility mods.
	"frost_vane": {"name": "Frost Vane", "text": "air dash leaves frost: freezes water", "rarity": "rare", "tier": 2, "family": "mobility",
		"elements": {"dash": "frost"}, "mods": {"dash_impulse": 1.1}},
	"long_spool": {"name": "Long Spool", "text": "+30% grapple range", "rarity": "common", "tier": 1, "family": "mobility",
		"mods": {"rope_range": 1.3}},
	"arc_coil": {"name": "Arc Coil", "text": "slam emits an arc burst", "rarity": "rare", "tier": 2, "family": "mobility",
		"elements": {"slam": "arc"}},
	# The spine's placeholder stat parts keep their ids, so old tests and saves still read.
	"tread_plating": {"name": "Tread Plating", "text": "+8% cruise speed", "rarity": "common", "tier": 1, "family": "mobility",
		"mods": {"cruise": 1.08}},
	"boost_coil": {"name": "Boost Coil", "text": "boost and dash recharge 15% faster", "rarity": "common", "tier": 1, "family": "mobility",
		"cooldown_scale": 0.85},
	"dash_vane": {"name": "Dash Vane", "text": "+15% air dash", "rarity": "common", "tier": 1, "family": "mobility",
		"mods": {"dash_impulse": 1.15}},
	"rivet_plating": {"name": "Rivet Plating", "text": "+15 max health", "rarity": "common", "tier": 1, "family": "stat",
		"max_hp_bonus": 15.0},
	"magnet_spool": {"name": "Magnet Spool", "text": "scrap magnet reaches 50% further", "rarity": "common", "tier": 1, "family": "stat",
		"magnet": 1.5},

	# Class mods: offered only to their class.
	"pylon_capacitor": {"name": "Pylon Capacitor", "text": "slingshot +50% boost, turret +40% damage", "rarity": "rare", "tier": 2,
		"family": "class", "class_id": "pylon_engineer",
		"mods": {"slingshot_boost": 1.5, "slingshot_keep": 1.1, "turret_damage": 1.4}},
	"runner_overclock": {"name": "Runner Overclock", "text": "+35% fire rate, boost recharges 20% faster", "rarity": "rare", "tier": 2,
		"family": "class", "class_id": "runner_gunner",
		"mods": {"weapon_rate": 1.35}, "cooldown_scale": 0.8},

	# Milestone parts: only a won event grants them (milestone_won).
	"tempest_core": {"name": "Tempest Core", "text": "spiral +2, chain +1, +30% fire rate", "rarity": "milestone", "tier": 3,
		"family": "milestone", "milestone_only": true,
		"patterns": {"spiral_wave": 2, "chain_arc": 1}, "mods": {"weapon_rate": 1.3}},
	"rime_heart": {"name": "Rime Heart", "text": "you freeze water you roll over", "rarity": "milestone", "tier": 3,
		"family": "milestone", "milestone_only": true,
		"elements": {"roll_on_water": "frost"}, "mods": {"cruise": 1.1}},
	"scrap_gravity": {"name": "Scrap Gravity", "text": "magnet x2.5, kills drop double scrap", "rarity": "milestone", "tier": 3,
		"family": "milestone", "milestone_only": true,
		"magnet": 2.5, "kill_scrap": 2.0, "mods": {"weapon_damage": 1.2}},
}

# Which milestone part each participatory event awards. An event not listed here
# awards the first milestone part the run does not hold yet, in MILESTONE_ORDER.
const MILESTONE_FOR_EVENT := {
	"surge_run": "rime_heart",
	"hold_the_relay": "tempest_core",
}
const MILESTONE_ORDER := ["scrap_gravity", "tempest_core", "rime_heart"]

# Offer weights by tier, per stage: a run starts modest and its offers climb.
const TIER_WEIGHTS := {
	1: {1: 6.0, 2: 2.0, 3: 0.3},
	2: {1: 3.0, 2: 4.0, 3: 1.2},
	3: {1: 1.0, 2: 4.0, 3: 3.5},
}
# How often an offer slot is spent on the part that completes a synergy, when one is
# a single part away. Isaac's "one more piece" pull, kept off a sure thing.
const SYNERGY_BAIT := 0.5

static var _defs := {}


static func def(part_id: String) -> Resource:
	if _defs.is_empty():
		for key in CATALOGUE:
			_defs[key] = PartDef.from_row(key, CATALOGUE[key])
	return _defs.get(part_id)


static func has(part_id: String) -> bool:
	return CATALOGUE.has(part_id)


static func ids() -> Array:
	return CATALOGUE.keys()


static func display_name(part_id: String) -> String:
	var d: Resource = def(part_id)
	return d.display_name if d != null else part_id.replace("_", " ").capitalize()


static func milestone_ids() -> Array:
	var list: Array = []
	for key in CATALOGUE:
		if CATALOGUE[key].get("milestone_only", false):
			list.append(key)
	return list


# The parts a gate or fabricator may offer this class: never a milestone part, never
# another class's mod.
static func offer_pool(class_id: String) -> Array:
	var pool: Array = []
	for key in CATALOGUE:
		var row: Dictionary = CATALOGUE[key]
		if row.get("milestone_only", false):
			continue
		var only: String = row.get("class_id", "")
		if only != "" and only != class_id:
			continue
		pool.append(key)
	return pool


static func milestone_for(event_id: String, held: Array) -> String:
	if MILESTONE_FOR_EVENT.has(event_id):
		return MILESTONE_FOR_EVENT[event_id]
	for key in MILESTONE_ORDER:
		if not key in held:
			return key
	return MILESTONE_ORDER[0]


# Picks count distinct parts, weighted by tier for the stage. One slot may go to the
# part that completes a synergy the run is one piece from.
static func roll(rng: RandomNumberGenerator, stage: int, class_id: String, held: Array, count: int,
		exclude: Array = []) -> Array:
	var pool: Array = offer_pool(class_id).filter(func(key): return not key in exclude)
	var picks: Array = []
	var bait: String = Synergies.completing_part(held, pool)
	if bait != "" and rng.randf() < SYNERGY_BAIT:
		picks.append(bait)
		pool.erase(bait)
	var weights: Dictionary = TIER_WEIGHTS[clampi(stage, 1, 3)]
	while picks.size() < count and not pool.is_empty():
		var total := 0.0
		for key in pool:
			total += weights[CATALOGUE[key]["tier"]]
		var ticket := rng.randf() * total
		var chosen: String = pool[pool.size() - 1]
		for key in pool:
			ticket -= weights[CATALOGUE[key]["tier"]]
			if ticket <= 0.0:
				chosen = key
				break
		picks.append(chosen)
		pool.erase(chosen)
	return picks
