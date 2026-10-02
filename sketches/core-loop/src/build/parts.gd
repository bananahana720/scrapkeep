extends RefCounted

const PartDef := preload("res://src/build/part_def.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Items := preload("res://src/build/items.gd")
const ItemGen := preload("res://src/build/item_gen.gd")

# The parts catalogue (TADR-008): one row per part, turned into typed PartDef resources
# once and cached. Each row has a verb (what it makes you do), punch (flat per-hit
# weapon damage it adds), one or two tags from PartDef.TAGS, and a rarity set by where
# it comes from. Effects are multipliers on named knobs, pattern levels, element
# triggers and pickup dials, so build_sheet.gd can fold any list of held parts into
# the same sheet every time. SEAMS.md lists the ids combat reads.
#
# Rules (DEMO-SPEC): only a common part may be percentage-only; every other rarity
# brings punch, a pattern, an element or a behaviour. Of every gate pair, at least one
# part raises punch or transforms a pattern. Tier drives the fabricator price.
#
# Scaling: tier 1 is +10 to 15%, tier 2 +25%, tier 3 +50%, and copies multiply;
# pattern levels and punch add. A stage-1 build is modest and a late one absurd
# (build_parts_test measures it); combat caps what is drawn.

const CATALOGUE := {
	# Common: gate fodder. Only these may be plain percentages.
	"hot_rivets": {"name": "Hot Rivets", "verb": "Hit harder", "text": "+4 punch, +12% weapon damage",
		"rarity": "common", "tier": 1, "family": "weapon", "tags": ["kinetic"], "punch": 4.0,
		"mods": {"weapon_damage": 1.12}},
	"loose_trigger": {"name": "Loose Trigger", "verb": "Fire faster", "text": "+10% fire rate",
		"rarity": "common", "tier": 1, "family": "weapon", "tags": ["speed"],
		"mods": {"weapon_rate": 1.1}},
	"long_barrel": {"name": "Long Barrel", "verb": "Shoot farther", "text": "+12% weapon range",
		"rarity": "common", "tier": 1, "family": "weapon", "tags": ["anchor"],
		"mods": {"weapon_range": 1.12}},
	"long_spool": {"name": "Long Spool", "verb": "Grapple farther", "text": "+30% grapple range",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["anchor"],
		"mods": {"rope_range": 1.3}},
	"tread_plating": {"name": "Tread Plating", "verb": "Roll faster", "text": "+8% cruise speed",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["speed"],
		"mods": {"cruise": 1.08}},
	"boost_coil": {"name": "Boost Coil", "verb": "Recharge boost sooner", "text": "boost and dash recharge 15% faster",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["speed"],
		"cooldown_scale": 0.85},
	"dash_vane": {"name": "Dash Vane", "verb": "Dash harder", "text": "+15% air dash",
		"rarity": "common", "tier": 1, "family": "mobility", "tags": ["speed"],
		"mods": {"dash_impulse": 1.15}},
	"rivet_plating": {"name": "Rivet Plating", "verb": "Bolt on armour", "text": "+15 max health",
		"rarity": "common", "tier": 1, "family": "stat", "tags": ["mass"],
		"max_hp_bonus": 15.0},
	"magnet_spool": {"name": "Magnet Spool", "verb": "Pull scrap from farther", "text": "scrap magnet reaches 50% further",
		"icon": "utility", "rarity": "common", "tier": 1, "family": "stat", "tags": ["mass"],
		"magnet": 1.5},

	# Uncommon: gates and fabricators. Punch, a pattern or an element on every row.
	"slag_rounds": {"name": "Slag Rounds", "verb": "Shots land heavy", "text": "+10 punch, +25% weapon damage",
		"rarity": "uncommon", "tier": 2, "family": "weapon", "tags": ["kinetic", "mass"], "punch": 10.0,
		"mods": {"weapon_damage": 1.25}},
	"double_feed": {"name": "Double Feed", "verb": "Feed two rounds a trigger", "text": "+3 punch, +25% fire rate",
		"rarity": "uncommon", "tier": 2, "family": "weapon", "tags": ["speed", "split"], "punch": 3.0,
		"mods": {"weapon_rate": 1.25}},
	"focus_lens": {"name": "Focus Lens", "verb": "Focus the beam", "text": "+6 punch, +25% weapon range",
		"rarity": "uncommon", "tier": 2, "family": "weapon", "tags": ["anchor"], "punch": 6.0,
		"mods": {"weapon_range": 1.25}},
	# Pattern transformers. The part id is the pattern id, and each copy adds a level.
	"cross_split": {"name": "Cross Split", "verb": "Split shots into a cross", "text": "shots split four ways on impact",
		"rarity": "uncommon", "tier": 2, "family": "pattern", "tags": ["split"],
		"patterns": {"cross_split": 1}},
	"spiral_wave": {"name": "Spiral Wave", "verb": "Spiral shots out in a wave", "text": "shots corkscrew outward",
		"rarity": "uncommon", "tier": 2, "family": "pattern", "tags": ["spiral"],
		"patterns": {"spiral_wave": 1}},
	"chain_arc": {"name": "Chain Arc", "verb": "Chain hits to a neighbour", "text": "a hit jumps to the nearest enemy",
		"rarity": "uncommon", "tier": 2, "family": "pattern", "tags": ["chain", "arc"],
		"patterns": {"chain_arc": 1}},
	"frost_vane": {"name": "Frost Vane", "verb": "Dash trails frost", "text": "air dash freezes water into road",
		"element": "frost", "rarity": "uncommon", "tier": 2, "family": "mobility", "tags": ["frost", "speed"],
		"elements": {"dash": "frost"}, "mods": {"dash_impulse": 1.1}},
	# Arc Coil and Runner Overclock carry one tag: kinetic was not their identity, and on
	# them it put Wrecking Ball over the 60% discovery cap (balance loop, B4).
	"arc_coil": {"name": "Arc Coil", "verb": "Slam discharges an arc", "text": "slams burst arc at everything near",
		"element": "arc", "rarity": "uncommon", "tier": 2, "family": "mobility", "tags": ["arc"],
		"elements": {"slam": "arc"}},
	# Class mods: offered only to their class.
	"pylon_capacitor": {"name": "Pylon Capacitor", "verb": "Bank a bigger plant", "text": "+8 punch, slingshot +50% boost",
		"icon": "mobility", "rarity": "uncommon", "tier": 2, "family": "class", "class_id": "pylon_engineer", "tags": ["anchor", "arc"],
		"punch": 8.0, "mods": {"slingshot_boost": 1.5, "slingshot_keep": 1.1, "turret_damage": 1.4}},
	"runner_overclock": {"name": "Runner Overclock", "verb": "Overclock the gun on the run", "text": "+4 punch, +35% fire rate",
		"icon": "damage", "rarity": "uncommon", "tier": 2, "family": "class", "class_id": "runner_gunner", "tags": ["speed"],
		"punch": 4.0, "mods": {"weapon_rate": 1.35}, "cooldown_scale": 0.8},

	# Rare: vaults, and gates with one bonus core.
	"sunforged_core": {"name": "Sunforged Core", "verb": "Forge every hit white-hot", "text": "+22 punch, +50% weapon damage",
		"rarity": "rare", "tier": 3, "family": "weapon", "tags": ["kinetic", "mass"], "punch": 22.0,
		"mods": {"weapon_damage": 1.5}},
	"gatling_heart": {"name": "Gatling Heart", "verb": "Spin up a gatling stream", "text": "+5 punch, +50% fire rate",
		"rarity": "rare", "tier": 3, "family": "weapon", "tags": ["spiral", "speed"], "punch": 5.0,
		"mods": {"weapon_rate": 1.5}},
	"horizon_optic": {"name": "Horizon Optic", "verb": "Snipe to the horizon", "text": "+12 punch, +50% range",
		"rarity": "rare", "tier": 3, "family": "weapon", "tags": ["anchor", "kinetic"], "punch": 12.0,
		"mods": {"weapon_range": 1.5, "weapon_damage": 1.15}},
	"rime_rounds": {"name": "Rime Rounds", "verb": "Shots freeze what they hit", "text": "+6 punch; shots freeze water",
		"element": "frost", "rarity": "rare", "tier": 3, "family": "weapon", "tags": ["frost", "kinetic"], "punch": 6.0,
		"elements": {"shot": "frost"}},
	"galvanic_rounds": {"name": "Galvanic Rounds", "verb": "Shots carry a live arc", "text": "+6 punch; shots electrify water",
		"element": "arc", "rarity": "rare", "tier": 3, "family": "weapon", "tags": ["arc", "chain"], "punch": 6.0,
		"elements": {"shot": "arc"}},
	"ram_plow": {"name": "Ram Plow", "verb": "Plough through the line", "text": "+18 punch, +15 max health",
		"icon": "damage", "rarity": "rare", "tier": 3, "family": "stat", "tags": ["kinetic", "mass"], "punch": 18.0,
		"max_hp_bonus": 15.0},

	# Rare-plus: won events, and gates with two or more bonus cores.
	"tempest_core": {"name": "Tempest Core", "verb": "Call a spiral storm", "text": "spiral +2, chain +1, +30% fire rate",
		"rarity": "rare_plus", "tier": 3, "family": "milestone", "milestone_only": true, "tags": ["spiral", "chain"],
		"patterns": {"spiral_wave": 2, "chain_arc": 1}, "mods": {"weapon_rate": 1.3}},
	"rime_heart": {"name": "Rime Heart", "verb": "Freeze the water you roll on", "text": "water under you turns to ice",
		"icon": "mobility", "element": "frost", "rarity": "rare_plus", "tier": 3, "family": "milestone", "milestone_only": true, "tags": ["frost", "mass"],
		"elements": {"roll_on_water": "frost"}, "mods": {"cruise": 1.1}},
	"scrap_gravity": {"name": "Scrap Gravity", "verb": "Drag the scrapfield in", "text": "+8 punch, magnet x2.5, double kill scrap",
		"icon": "utility", "rarity": "rare_plus", "tier": 3, "family": "milestone", "milestone_only": true, "tags": ["mass"],
		"punch": 8.0, "magnet": 2.5, "kill_scrap": 2.0},
}

# Which rarities each source grants (DEMO-SPEC "Engagement tiers" and "Cores").
const SOURCE_RARITIES := {
	"fabricator": ["uncommon"],
	"vault": ["rare"],
	"milestone": ["rare_plus"],
}

# Which milestone part each participatory event awards. An event not listed here
# awards the first milestone part the run does not hold yet, in MILESTONE_ORDER.
const MILESTONE_FOR_EVENT := {
	"surge_run": "rime_heart",
	"hold_the_relay": "tempest_core",
}
const MILESTONE_ORDER := ["scrap_gravity", "tempest_core", "rime_heart"]

# How often an offer slot is spent on the part that completes a synergy, when one is
# a single part away. Isaac's "one more piece" pull, kept off a sure thing.
const SYNERGY_BAIT := 0.5

# The pattern guarantee (balance loop, B4): a run that reaches stage 2's gates holding no
# pattern transformer is offered one of these in that pair. Bots without a pattern took
# 117 to 204 s on Warden III against 19 to 81 s with one, a split HP tuning cannot close.
# The other gate stays a free choice.
const PATTERN_PARTS := ["spiral_wave", "cross_split", "chain_arc"]
const PATTERN_GUARANTEE_STAGE := 2

# v2 W4 loot: how often an offer slot is a freshly generated recipe (item_gen.gd)
# instead of an authored row. The rest of the pool is the catalogue above plus the
# item table (items.gd).
const GENERATED_SHARE := 0.25

# Hot-wired parts (BUILD-SYSTEMS.md, Two hot-wired parts). Not in CATALOGUE, so they never
# enter rows(), ids(), offer_pool() or roll(): a hot-wired part is offered by authorship,
# never drawn as loot. Each row names both consequences with an icon id and at most three
# words; "{armor}", "{armor_x}" and "{steer}" are resolved from Build and RunState by hotwire_choice.gd,
# so the words follow the tuning. Fitting still comes from --hotwire-shell; nothing here
# equips a part.
const HOTWIRED := {
	"riveted_shell": {"name": "Riveted Shell", "tags": ["mass"], "needs_armor": true,
		"label": "{armor} armour. Air steering \u2212{steer}%.",
		"upside": {"icon": "cat_defense", "words": "{armor_x}x armour"},
		"downside": {"icon": "cat_mobility", "words": "Air steering \u2212{steer}%"}},
}

static var _defs := {}
static var _rows := {}
# Seams other modules offer ("spawner.extend_cloak"). A row whose needs is not here is
# never offered; build fills this at setup from what the live modules answer.
static var seams := {}


# Every authored row: the catalogue above, the v2 item table and Moss's cells, finished
# by the generator. Generated recipes are not listed; row() builds them on demand.
static func rows() -> Dictionary:
	if _rows.is_empty():
		for key in CATALOGUE:
			_rows[key] = CATALOGUE[key]
		for key in Items.TABLE:
			_rows[key] = ItemGen.finish(key, Items.TABLE[key])
		for key in Items.CELLS:
			_rows[key] = ItemGen.finish(key, Items.CELLS[key])
	return _rows


static func row(part_id: String) -> Dictionary:
	var authored: Dictionary = rows().get(part_id, {})
	return authored if not authored.is_empty() else ItemGen.generated_row(part_id)


static func def(part_id: String) -> Resource:
	if not _defs.has(part_id):
		var r := row(part_id)
		if r.is_empty():
			return null
		_defs[part_id] = PartDef.from_row(part_id, r)
	return _defs[part_id]


static func has(part_id: String) -> bool:
	return rows().has(part_id) or ItemGen.is_generated(part_id) and not ItemGen.parse(part_id).is_empty()


# The authored pool, catalogue first. Generated recipes are unbounded and not listed.
static func ids() -> Array:
	return rows().keys()


# The hot-wired row for an id, or {} when the id is not hot-wired.
static func hotwired(part_id: String) -> Dictionary:
	return HOTWIRED.get(part_id, {})


# The hot-wired parts an offer may show. A part that needs armour mode (Riveted Shell is a
# pure downside without it, DESIGN-NOTES H1) is left out when armor_mode is false. At most
# one hot-wired part is held, so nothing is offered once one is. Pure: read armor_mode from
# tuning.armor() or RunState.armor_mode.
static func hotwire_offer(armor_mode: bool, held: Array = []) -> Array:
	if held.any(func(key): return HOTWIRED.has(key)):
		return []
	var out: Array = []
	for key in HOTWIRED:
		if HOTWIRED[key].get("needs_armor", false) and not armor_mode:
			continue
		out.append(key)
	return out


static func seam_met(need: String) -> bool:
	return need == "" or seams.get(need, false)


static func display_name(part_id: String) -> String:
	var d: Resource = def(part_id)
	return d.display_name if d != null else part_id.replace("_", " ").capitalize()


static func tags_of(part_id: String) -> Array:
	var d: Resource = def(part_id)
	return d.tags if d != null else []


# The gate label's first line: "{name}: {verb}. Punch +{n}".
static func headline(part_id: String) -> String:
	var d: Resource = def(part_id)
	if d == null:
		return display_name(part_id)
	var line := "%s: %s." % [d.display_name, d.verb]
	if d.punch > 0.0:
		line += " Punch +%d" % int(d.punch)
	return line


static func milestone_ids() -> Array:
	var list: Array = []
	for key in rows():
		if rows()[key].get("milestone_only", false):
			list.append(key)
	return list


# One tag list per held part, in order: what the synergy rules read.
static func tag_sets(held: Array) -> Array:
	var sets: Array = []
	for part_id in held:
		sets.append(tags_of(part_id))
	return sets


# The named synergy taking part_id now would complete, or "".
static func completed_by(part_id: String, held: Array) -> String:
	return Synergies.completed_by(held, tag_sets(held), part_id, tags_of(part_id))


# The part in pool that would complete a named synergy, or "".
static func completing_part(held: Array, pool: Array) -> String:
	var sets := tag_sets(held)
	for key in pool:
		if Synergies.completed_by(held, sets, key, tags_of(key)) != "":
			return key
	return ""


# The not-yet-live named synergy whose hint card shows part_id as its ingredient, or "".
static func ingredient_of(part_id: String, held: Array) -> String:
	var live := Synergies.active(held, tag_sets(held))
	for key in Synergies.ROWS:
		if Synergies.in_play(key) and Synergies.ROWS[key]["shown"] == part_id and not key in live:
			return key
	return ""


# Gate tiers by overcharge: 0 bonus cores offer common or uncommon, 1 uncommon or
# rare, 2 or more rare or rare-plus.
static func gate_rarities(bonus_cores: int) -> Array:
	if bonus_cores >= 2:
		return ["rare", "rare_plus"]
	if bonus_cores == 1:
		return ["uncommon", "rare"]
	return ["common", "uncommon"]


# True while the build runs on a table that names its parts (the slice). Then the pool is
# that list, no slot is a generated recipe and the shop never falls back to one.
static func listed_only() -> bool:
	return Synergies.table != null and Synergies.table.parts_listed()


# The parts a source may offer this class, at these rarities. Never another class's mod.
static func offer_pool(class_id: String, rarities: Array) -> Array:
	var pool: Array = []
	var all := rows()
	var listed := listed_only()
	for key in all:
		var r: Dictionary = all[key]
		if listed and not Synergies.table.part_in_play(key):
			continue
		if not r["rarity"] in rarities or r.get("shop_only", false) or not seam_met(r.get("needs", "")):
			continue
		var only: String = r.get("class_id", "")
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


# Picks count distinct parts from the pool at these rarities. One slot may go to the
# part that completes a synergy the run is one piece from. Every other slot draws its
# rarity by the rarity weights (common 60, uncommon 27, rare 10, rare_plus 3), then is
# a generated recipe GENERATED_SHARE of the time, else an authored row of that rarity,
# weighted down by how often offered (id to count this stage) has shown it, so a stage
# rarely shows the same part twice. A pair always holds at least one part that raises
# punch or transforms a pattern.
static func roll(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		exclude: Array = [], offered: Dictionary = {}) -> Array:
	var pool: Array = offer_pool(class_id, rarities).filter(func(key): return not key in exclude)
	var picks: Array = []
	var bait: String = completing_part(held, pool)
	if bait != "" and rng.randf() < SYNERGY_BAIT:
		picks.append(bait)
		pool.erase(bait)
	var tries := 0
	while picks.size() < count and not pool.is_empty() and tries < count * 8:
		tries += 1
		var rarity := ItemGen.pick_rarity(rng, rarities)
		if not listed_only() and rng.randf() < GENERATED_SHARE:
			var recipe := ItemGen.roll_id(rng, rarity)
			if not recipe in picks and not recipe in exclude:
				picks.append(recipe)
			continue
		var bucket: Array = pool.filter(func(key): return rows()[key]["rarity"] == rarity)
		if bucket.is_empty():
			bucket = pool
		var chosen := _weighted(rng, bucket, offered)
		picks.append(chosen)
		pool.erase(chosen)
	if picks.size() >= 2 and not picks.any(func(key): return def(key).hits_harder()):
		var harder: Array = pool.filter(func(key): return def(key).hits_harder())
		if not harder.is_empty():
			picks[picks.size() - 1] = harder[rng.randi_range(0, harder.size() - 1)]
	return picks


static func _weighted(rng: RandomNumberGenerator, bucket: Array, offered: Dictionary) -> String:
	var total := 0.0
	for key in bucket:
		total += 1.0 / (1.0 + offered.get(key, 0))
	var x := rng.randf() * total
	for key in bucket:
		x -= 1.0 / (1.0 + offered.get(key, 0))
		if x < 0.0:
			return key
	return bucket[-1]


# True when a held part transforms a weapon pattern (the three pattern parts, Tempest Core).
static func holds_pattern(held: Array) -> bool:
	return held.any(func(key): return def(key) != null and not def(key).patterns.is_empty())


# A reward gate pair: roll(), then the pattern guarantee. On stage 2, when nothing held
# transforms a pattern and neither offer is a pattern part, the last slot becomes one.
# That slot is never the synergy bait (always first), and a pattern part hits harder, so
# the pair keeps both rules. The pattern part comes from the gate's own rarities when one
# fits; at two or more bonus cores (rare and rare-plus) none does, and only that slot
# drops to uncommon. Any other stage, or a build that already holds a pattern, gets
# exactly what roll() gives for the same seed.
static func roll_gate(rng: RandomNumberGenerator, rarities: Array, class_id: String, held: Array, count: int,
		stage: int, offered: Dictionary = {}) -> Array:
	var picks: Array = roll(rng, rarities, class_id, held, count, [], offered)
	if stage != PATTERN_GUARANTEE_STAGE or count < 1 or holds_pattern(held) \
			or picks.any(func(key): return key in PATTERN_PARTS):
		return picks
	var eligible: Array = PATTERN_PARTS.filter(func(key): return def(key).rarity in rarities)
	if eligible.is_empty():
		eligible = PATTERN_PARTS.duplicate()
	var pattern: String = eligible[rng.randi_range(0, eligible.size() - 1)]
	if picks.size() < count:
		picks.append(pattern)
	else:
		picks[picks.size() - 1] = pattern
	return picks
