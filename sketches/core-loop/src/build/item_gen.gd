extends RefCounted

const Triggers := preload("res://src/build/triggers.gd")
const Palette := preload("res://src/core/palette.gd")
const PartDef := preload("res://src/build/part_def.gd")


const PREFIX := "gen"
const TIER_WEIGHTS := {"common": 87.0, "rare": 10.0, "relic": 3.0, "evolved": 0.0}
const RARITY := {
	"common": {"color": Palette.ARC, "weight": TIER_WEIGHTS["common"], "stamp": "FIELD KIT", "rung": 0, "tier": 1, "affix": 1.12},
	"rare": {"color": Palette.COBALT, "weight": TIER_WEIGHTS["rare"], "stamp": "FLEET GRADE", "rung": 1, "tier": 3, "affix": 1.5},
	"relic": {"color": Palette.AMBER, "weight": TIER_WEIGHTS["relic"], "stamp": "RELIC", "rung": 2, "tier": 3, "affix": 2.0},
	"evolved": {"color": Palette.ANCIENT, "weight": TIER_WEIGHTS["evolved"], "stamp": "EVOLVED", "rung": 3, "tier": 3, "affix": 2.0},
}
const RARITIES := PartDef.RARITIES
const RARITY_ALIASES := {"uncommon": "common", "rare_plus": "relic", "evolution": "evolved"}
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
const GENERATED_BASES := ["weapon", "mobility", "defense", "utility", "charge"]
const PLUS_NOUNS := ["Core", "Heart"]
const ELEMENT_WORDS := {"frost": "Frost", "arc": "Arc", "kinetic": "Kinetic"}
const TRIGGER_WORDS := {
	"on_hit": "Spur", "on_kill": "Scrapper", "on_smash": "Smash", "on_rebound": "Rebound", "on_vault": "Vault",
	"on_charge_release": "Charged", "on_cloak_break": "Smoke", "on_land": "Landing", "on_speed_tier_up": "Redline",
	"on_pickup": "Magnet", "on_damage_taken": "Dented", "timed": "Clockwork",
}
const TRIGGER_WHEN := {
	"on_hit": "On hit", "on_kill": "On kill", "on_smash": "On smash", "on_rebound": "On rebound",
	"on_vault": "On vault", "on_charge_release": "On release", "on_cloak_break": "Cloak breaks", "on_land": "On landing",
	"on_speed_tier_up": "Speeding up", "on_pickup": "On pickup", "on_damage_taken": "When hurt", "timed": "Every {every}s",
}
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
const SCALED := ["chance", "damage", "gain", "bonus", "share"]
const CEILINGS := {"chance": 0.25, "gain": 0.2, "bonus": 1.0, "share": 1.0}
const GEN_CAP := 3
const ODDS_SEPARATOR := " / "


static func is_generated(part_id: String) -> bool:
	return part_id.begins_with(PREFIX + ":")


static func make_id(base: String, rarity: String, element: String, trigger: String) -> String:
	return ":".join([PREFIX, base, rarity, element if element != "" else "none", trigger])


static func resolve_rarity(rarity: String) -> String:
	var id: String = RARITY_ALIASES.get(rarity, rarity)
	return id if RARITY.has(id) else ""


static func resolve_rarities(rarities: Array) -> Array:
	var out: Array = []
	for r in rarities:
		var id := resolve_rarity(String(r))
		if id != "" and not id in out:
			out.append(id)
	return out


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


static func roll_id(rng: RandomNumberGenerator, rarity: String) -> String:
	var base: String = GENERATED_BASES[rng.randi_range(0, GENERATED_BASES.size() - 1)]
	var element: String = ELEMENTS[rng.randi_range(0, ELEMENTS.size() - 1)]
	var trigger: String = Triggers.NAMES[rng.randi_range(0, Triggers.NAMES.size() - 1)]
	return make_id(base, rarity, element, trigger)


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


static func weight_of(rarity: String) -> float:
	return float(TIER_WEIGHTS[resolve_rarity(rarity)])


static func odds(allowed: Array) -> Array:
	var ids := resolve_rarities(allowed)
	var total := 0.0
	for r in ids:
		total += weight_of(r)
	var out: Array = []
	for r in ids:
		out.append({"rarity": r, "weight": weight_of(r), "share": weight_of(r) / total if total > 0.0 else 0.0})
	return out


static func odds_rows(shares: Array) -> Array:
	var out: Array = []
	for row in shares:
		if float(row["share"]) <= 0.0:
			continue
		var rarity: String = row["rarity"]
		out.append({"rarity": rarity, "label": RARITY[rarity]["stamp"], "percent": roundi(float(row["share"]) * 100.0),
			"color": RARITY[rarity]["color"]})
	return out


static func odds_text(shares: Array) -> String:
	var bits: Array = []
	for row in odds_rows(shares):
		bits.append("%s %d%%" % [row["label"], row["percent"]])
	return ODDS_SEPARATOR.join(bits)


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


static func name_for(base: String, rarity: String, element: String, trigger: String) -> String:
	var modifier: String = ELEMENT_WORDS.get(element, TRIGGER_WORDS.get(trigger, "Plain"))
	var nouns: Array = PLUS_NOUNS if rarity == "relic" else BASES[base]["nouns"]
	var noun: String = nouns[(trigger.length() + element.length()) % nouns.size()]
	return "%s %s" % [modifier, noun]


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


static func clip(text: String) -> String:
	var words := text.split(" ", false)
	if words.size() <= MAX_WORDS:
		return text
	return " ".join(words.slice(0, MAX_WORDS)) + "..."


static func word_count(text: String) -> int:
	return text.split(" ", false).size()


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
	row["tier"] = int(spec.get("tier", LEGACY_TIER.get(raw, RARITY[rarity]["tier"])))
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
