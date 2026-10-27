extends RefCounted

const Triggers := preload("res://src/build/triggers.gd")
const Palette := preload("res://src/core/palette.gd")

# The item generator: base x affix x element x trigger (I2 section 2, DESIGN-V2 section
# 7). Every axis is a lookup, never a formula with a hidden constant, so a generated
# item is as inspectable as a hand-written row.
#
# - base: the family archetype. It names the noun, the cat_ icon, the accretion family
#   and the stat every copy brings (punch for a weapon, health for defense...).
# - affix: the catalogue's existing tier scaling, set by rarity: +12% common, +50% rare,
#   and relic doubles.
# - element: frost, arc, kinetic or none (TADR-009). It colours the effect and applies
#   the element table where the effect lands.
# - trigger: one of the twelve kinds, with its effect template.
#
# A generated item's id is its recipe, "gen:<base>:<rarity>:<element>:<trigger>", so
# the run's part list, a retry and the run log all hold something that rebuilds the
# same item every time, and two copies of one recipe stack like any part.
#
# The same generator finishes the authored rows in items.gd: it fills the name, tier,
# icon, family and tags a row leaves out, and holds every description to eight words.

const PREFIX := "gen"
# The one tier-weight row (SG13). The roll (pick_rarity) and every readout (odds) read these
# numbers and no others; RARITY["weight"] below points here. 87 / 10 / 3 are this game's start
# values, not RoR2's 0.8 / 0.2 / 0.01 (comps/ror2/items-and-stacking.md), which is the shape of
# the idea only: a visible weight per tier. Evolved stays 0 until a unit rolls it.
const TIER_WEIGHTS := {"common": 87.0, "rare": 10.0, "relic": 3.0, "evolved": 0.0}
# The one rarity table (RR1). Every reader resolves a rarity through it: colour, roll
# weight, stamp glyph, ladder rung 0..3, tier and the affix scale. The colours are the item
# ladder's rungs (23 Oct 19:28Z; grey is the panels' own): common is the green field kit in
# field mint, rare the blue fleet grade in cobalt, relic gold in amber (its mint heart is the
# gate's and the frame's), so the ids keep their meaning and only the read changes. Uncommon folded into
# common and rare_plus became relic; evolved is the top rung, reserved for the two
# evolutions a later unit builds, so it carries weight 0 and nothing rolls it yet.
const RARITY := {
	"common": {"color": Palette.ARC, "weight": TIER_WEIGHTS["common"], "stamp": "COMMON", "rung": 0, "tier": 1, "affix": 1.12},
	"rare": {"color": Palette.COBALT, "weight": TIER_WEIGHTS["rare"], "stamp": "RARE", "rung": 1, "tier": 3, "affix": 1.5},
	"relic": {"color": Palette.AMBER, "weight": TIER_WEIGHTS["relic"], "stamp": "RELIC", "rung": 2, "tier": 3, "affix": 2.0},
	"evolved": {"color": Palette.ANCIENT, "weight": TIER_WEIGHTS["evolved"], "stamp": "EVOLVED", "rung": 3, "tier": 3, "affix": 2.0},
}
const RARITIES := ["common", "rare", "relic", "evolved"]
# Old ids that a saved recipe id or a stale caller may still carry, resolved on read.
const RARITY_ALIASES := {"uncommon": "common", "rare_plus": "relic", "evolution": "evolved"}
# Authored uncommon rows keep the tier they had before they folded into common.
const LEGACY_TIER := {"uncommon": 2}
const ELEMENTS := ["", "frost", "arc", "kinetic"]
const MAX_WORDS := 8

const BASES := {
	"weapon": {"icon": "damage", "family": "weapon", "tag": "kinetic", "nouns": ["Rounds", "Slug", "Barb"],
		"stat": {"punch": [3.0, 6.0, 10.0]}},
	"pattern": {"icon": "transform", "family": "pattern", "tag": "spiral", "nouns": ["Coil"], "stat": {}},
	"mobility": {"icon": "mobility", "family": "mobility", "tag": "speed", "nouns": ["Vane", "Bearing", "Spring"],
		"stat": {"cruise": [1.03, 1.05, 1.08]}},
	"defense": {"icon": "defense", "family": "stat", "tag": "mass", "nouns": ["Plating", "Liner", "Skin"],
		"stat": {"max_hp_bonus": [8.0, 12.0, 20.0]}},
	"utility": {"icon": "utility", "family": "stat", "tag": "anchor", "nouns": ["Lamp", "Hook", "Drone"],
		"stat": {"magnet": [1.1, 1.2, 1.35]}},
	"charge": {"icon": "charge", "family": "class", "tag": "arc", "nouns": ["Cell", "Spool", "Capacitor"],
		"stat": {"special_charges": [0.0, 0.0, 1.0]}},
}
# Pattern transformers need combat to draw them, so the generator never invents one.
const GENERATED_BASES := ["weapon", "mobility", "defense", "utility", "charge"]
const PLUS_NOUNS := ["Core", "Heart"]
const ELEMENT_WORDS := {"frost": "Frost", "arc": "Arc", "kinetic": "Kinetic"}
const TRIGGER_WORDS := {
	"on_hit": "Spur", "on_kill": "Scrapper", "on_smash": "Smash", "on_rebound": "Rebound", "on_vault": "Vault",
	"on_charge_release": "Charged", "on_cloak_break": "Smoke", "on_land": "Landing", "on_speed_tier_up": "Redline",
	"on_pickup": "Magnet", "on_damage_taken": "Dented", "timed": "Clockwork",
}
# When the effect happens, as the first words of a description.
const TRIGGER_WHEN := {
	"on_hit": "On hit", "on_kill": "On kill", "on_smash": "On smash", "on_rebound": "On rebound",
	"on_vault": "On vault", "on_charge_release": "On release", "on_cloak_break": "Cloak breaks", "on_land": "On landing",
	"on_speed_tier_up": "Speeding up", "on_pickup": "On pickup", "on_damage_taken": "When hurt", "timed": "Every {every}s",
}
# One effect template per trigger; the affix scales its numbers.
const TEMPLATES := {
	"on_hit": {"do": "zap", "chance": 0.08, "damage": 6.0, "reach": 10.0},
	"on_kill": {"do": "burst", "radius": 5.0, "damage": 8.0},
	"on_smash": {"do": "burst", "radius": 6.0, "damage": 10.0},
	"on_rebound": {"do": "speed", "gain": 0.08, "max_speed": 40.0},
	"on_vault": {"do": "speed", "gain": 0.04, "max_speed": 45.0},
	"on_charge_release": {"do": "burst", "radius": 7.0, "damage": 10.0},
	"on_cloak_break": {"do": "burst", "radius": 5.0, "damage": 12.0},
	"on_land": {"do": "burst", "radius": 5.0, "damage": 6.0, "min_impact": 9.0},
	"on_speed_tier_up": {"do": "grant_charge", "slot": "movement", "every": 6},
	"on_pickup": {"do": "zap", "chance": 0.04, "damage": 5.0, "reach": 10.0},
	"on_damage_taken": {"do": "return_arc", "share": 0.5, "reach": 12.0},
	"timed": {"do": "arm_hit", "every": 10, "bonus": 0.3},
}
# Which numbers the affix scales, and the ceilings it may not pass.
const SCALED := ["chance", "damage", "gain", "bonus", "share"]
const CEILINGS := {"chance": 0.25, "gain": 0.2, "bonus": 1.0, "share": 1.0}
const GEN_CAP := 3


static func is_generated(part_id: String) -> bool:
	return part_id.begins_with(PREFIX + ":")


static func make_id(base: String, rarity: String, element: String, trigger: String) -> String:
	return ":".join([PREFIX, base, rarity, element if element != "" else "none", trigger])


# A rarity id or an old alias to one of RARITIES; "" when it is neither.
static func resolve_rarity(rarity: String) -> String:
	var id: String = RARITY_ALIASES.get(rarity, rarity)
	return id if RARITY.has(id) else ""


# A list of rarity ids or aliases as RARITIES ids, no repeats, unknown ids dropped.
static func resolve_rarities(rarities: Array) -> Array:
	var out: Array = []
	for r in rarities:
		var id := resolve_rarity(String(r))
		if id != "" and not id in out:
			out.append(id)
	return out


# Parses a recipe id; {} when it is not a well-formed recipe.
static func parse(part_id: String) -> Dictionary:
	var bits := part_id.split(":")
	if bits.size() != 5 or bits[0] != PREFIX:
		return {}
	var element := bits[3] if bits[3] != "none" else ""
	var rarity := resolve_rarity(bits[2])
	if not bits[1] in GENERATED_BASES or rarity == "" or not element in ELEMENTS \
			or Triggers.kind_of(bits[4]) < 0:
		return {}
	return {"base": bits[1], "rarity": rarity, "element": element, "trigger": bits[4]}


# A new recipe at this rarity, drawn from rng: a base, an element, a trigger.
static func roll_id(rng: RandomNumberGenerator, rarity: String) -> String:
	var base: String = GENERATED_BASES[rng.randi_range(0, GENERATED_BASES.size() - 1)]
	var element: String = ELEMENTS[rng.randi_range(0, ELEMENTS.size() - 1)]
	var trigger: String = Triggers.NAMES[rng.randi_range(0, Triggers.NAMES.size() - 1)]
	return make_id(base, rarity, element, trigger)


# A rarity from the allowed list, weighted by RARITY.
static func pick_rarity(rng: RandomNumberGenerator, allowed: Array) -> String:
	allowed = resolve_rarities(allowed)
	if allowed.is_empty():
		return "common"
	var total := 0.0
	for r in allowed:
		total += weight_of(r)
	var x := rng.randf() * total
	for r in allowed:
		x -= weight_of(r)
		if x < 0.0:
			return r
	return allowed[-1]


# A rarity's roll weight, from the one weight row.
static func weight_of(rarity: String) -> float:
	return float(TIER_WEIGHTS[resolve_rarity(rarity)])


# What a table can contain, as the roll sees it: one {rarity, weight, share} per resolved
# rarity in the table's order, the weight from TIER_WEIGHTS and the share its part of the
# table's total (0 for every row when the total is 0). An empty or unknown table is [].
static func odds(allowed: Array) -> Array:
	var ids := resolve_rarities(allowed)
	var total := 0.0
	for r in ids:
		total += weight_of(r)
	var out: Array = []
	for r in ids:
		out.append({"rarity": r, "weight": weight_of(r), "share": weight_of(r) / total if total > 0.0 else 0.0})
	return out


# The catalogue row for a recipe id, or {} for an id that is not one.
static func generated_row(part_id: String) -> Dictionary:
	var recipe := parse(part_id)
	if recipe.is_empty():
		return {}
	var base: String = recipe["base"]
	var rarity: String = recipe["rarity"]
	var element: String = recipe["element"]
	var trigger: String = recipe["trigger"]
	var effect := scaled_effect(TEMPLATES[trigger], rarity)
	if element != "":
		effect["element"] = element
	var row := {"base": base, "rarity": rarity, "trigger": trigger, "element": element, "stack": "capped",
		"cap": GEN_CAP, "effect": effect, "name": name_for(base, rarity, element, trigger)}
	row["verb"] = "%s %s" % [TRIGGER_WHEN[trigger].format(effect), _effect_verb(effect)]
	row["text"] = describe(trigger, effect)
	return finish(part_id, row)


static func scaled_effect(template: Dictionary, rarity: String) -> Dictionary:
	var out := template.duplicate()
	var affix: float = RARITY[rarity]["affix"]
	for key in SCALED:
		if out.has(key):
			var v: float = out[key] * affix
			out[key] = minf(v, CEILINGS[key]) if CEILINGS.has(key) else v
	return out


# "{modifier} {noun}": the element's word, else the trigger's; relic takes Core or
# Heart as its noun, like Sunforged Core and Rime Heart.
static func name_for(base: String, rarity: String, element: String, trigger: String) -> String:
	var modifier: String = ELEMENT_WORDS.get(element, TRIGGER_WORDS.get(trigger, "Plain"))
	var nouns: Array = PLUS_NOUNS if rarity == "relic" else BASES[base]["nouns"]
	var noun: String = nouns[(trigger.length() + element.length()) % nouns.size()]
	return "%s %s" % [modifier, noun]


# "{when}, {effect}", held to eight words.
static func describe(trigger: String, effect: Dictionary) -> String:
	return clip("%s, %s" % [TRIGGER_WHEN[trigger].format(effect), effect_phrase(effect)])


static func effect_phrase(effect: Dictionary) -> String:
	var el: String = ELEMENT_WORDS.get(effect.get("element", ""), "").to_lower()
	match effect.get("do", ""):
		"zap":
			return "%d%% chance to %szap" % [roundi(effect["chance"] * 100.0), el + " " if el != "" else ""]
		"burst":
			return "%sburst %d m" % [el + " " if el != "" else "", roundi(effect["radius"])]
		"speed":
			return "+%d%% speed" % roundi(effect["gain"] * 100.0)
		"grant_charge":
			return "refill a %s charge" % effect.get("slot", "movement")
		"return_arc":
			return "arc %d%% back" % roundi(effect["share"] * 100.0)
		"arm_hit":
			return "next hit +%d%%" % roundi(effect["bonus"] * 100.0)
	return "something happens"


static func _effect_verb(effect: Dictionary) -> String:
	match effect.get("do", ""):
		"zap":
			return "zaps"
		"burst":
			return "bursts"
		"speed":
			return "surges"
		"grant_charge":
			return "recharges"
		"return_arc":
			return "arcs back"
		"arm_hit":
			return "primes a hit"
	return "works"


# Past MAX_WORDS a description is cut and ends in an ellipsis; the catalogue test
# holds every row to it.
static func clip(text: String) -> String:
	var words := text.split(" ", false)
	if words.size() <= MAX_WORDS:
		return text
	return " ".join(words.slice(0, MAX_WORDS)) + "..."


static func word_count(text: String) -> int:
	return text.split(" ", false).size()


# Fills what an authored or generated row leaves out: name from the id, tier from the
# rarity, family and icon from the base, a tag from the element or the base, and the
# eight-word ceiling on the description.
static func finish(part_id: String, spec: Dictionary) -> Dictionary:
	var row := spec.duplicate(true)
	var base: String = spec.get("base", "utility")
	var b: Dictionary = BASES.get(base, BASES["utility"])
	var raw: String = spec.get("rarity", "common")
	var rarity := resolve_rarity(raw)
	if rarity == "":
		rarity = "common"
	row["rarity"] = rarity
	row["name"] = spec.get("name", part_id.replace("_", " ").capitalize())
	row["tier"] = LEGACY_TIER.get(raw, RARITY[rarity]["tier"])
	row["family"] = b["family"]
	row["icon"] = b["icon"]
	row["text"] = clip(spec.get("text", ""))
	if spec.has("class"):
		row["class_id"] = spec["class"]
	var tags: Array = spec.get("tags", [])
	if tags.is_empty():
		var element: String = spec.get("element", "")
		tags = [element] if element != "" else []
		if not b["tag"] in tags:
			tags.append(b["tag"])
	row["tags"] = tags
	if is_generated(part_id):
		_apply_base_stat(row, b, rarity)
	return row


# A generated item's base brings its stat every copy (a weapon hits harder, a plate
# adds health), so every generated part hits harder or helps outright, not only when
# its trigger fires.
static func _apply_base_stat(row: Dictionary, b: Dictionary, rarity: String) -> void:
	var rung: int = RARITY[rarity]["rung"]
	var stat: Dictionary = b["stat"]
	for key in stat:
		var value: float = stat[key][mini(rung, stat[key].size() - 1)]
		match key:
			"cruise":
				row["mods"] = {"cruise": value}
			"special_charges":
				if value > 0.0:
					row["charges"] = {"special": int(value)}
			_:
				row[key] = value
