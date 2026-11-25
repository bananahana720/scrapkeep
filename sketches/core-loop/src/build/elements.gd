extends RefCounted


const ELEMENTS := ["frost", "arc", "kinetic"]
const ELEMENTS_W50 := ["frost", "arc", "kinetic", "heat"]
const MATERIALS := ["water", "ice"]

const SURFACES := {
	"ice": {"material": "ice", "radius": 3.6, "thickness": 0.9, "seconds": 9.0, "fade": 1.5},
}

const ROWS := {
	"frost:water": {"behaviour": "create_surface", "surface": "ice",
		"found": "Frost on water freezes into a road you can drive."},
	"arc:water": {"behaviour": "electrify", "radius": 8.0, "seconds": 3.0, "interval": 0.25, "damage": 8.0,
		"found": "Arc on water electrifies it: anything standing in it gets shocked."},
	"arc:ice": {"behaviour": "shatter", "radius": 6.5, "damage": 26.0,
		"found": "Arc cracks ice into a burst of shards."},
	"kinetic:ice": {"behaviour": "shatter", "radius": 5.0, "damage": 20.0,
		"found": "Frost, then a heavy hit: slamming ice shatters it into shrapnel."},
}

const ROWS_W50 := {
	"heat:water": {"behaviour": "steam_cloud", "radius": 6.0, "seconds": 4.0, "updraft": 14.0, "damage": 16.0,
		"found": "Heat on water raises a scalding steam updraft."},
	"heat:ice": {"behaviour": "flash_melt", "radius": 6.5, "damage": 34.0,
		"found": "Heat on ice triggers an explosive flash-melt nova."},
}


const STATUS_SECONDS := 5.0
const TOUCH_RADIUS := 2.0
const STATUS_KINDS := {"arc": "arc", "slam": "kinetic"}
const TOUCH_ELEMENTS := ["frost"]
const TOUCH_ELEMENTS_W50 := ["frost", "heat"]
const FUSION_LEAD_FRAMES := 15
const FUSION_STRIKE := "fusion"
const FUSION_KINDS := {"lock": "control", "overload": "burst", "grind": "sustained"}
const BOSS_KINDS := ["miniboss", "warden", "vault", "rogue_crane", "rogue_skip", "rogue_tender", "waking", "mind"]

const FUSIONS := {
	"arc+frost": {"behaviour": "lock", "kind": "control", "radius": 4.0, "seconds": 2.0, "damage": 10.0,
		"found": "Arc meets frost: everything near locks in place.",
		"immunity": "Elites and bosses never lock."},
	"arc+kinetic": {"behaviour": "overload", "kind": "burst", "radius": 5.0, "seconds": 0.0, "damage": 30.0,
		"found": "Arc meets a heavy hit: the charge overloads in a burst.",
		"immunity": "Elites and bosses take the full burst."},
	"frost+kinetic": {"behaviour": "grind", "kind": "sustained", "radius": 4.5, "seconds": 3.0, "interval": 0.5,
		"damage": 6.0, "elite_share": 0.1,
		"found": "Frost meets a heavy hit: the chill grinds everything near.",
		"immunity": "Elites and bosses take a tenth of the grind."},
}

const FUSIONS_W50 := {
	"frost+heat": {"behaviour": "overload", "kind": "burst", "radius": 5.5, "seconds": 0.0, "damage": 36.0,
		"found": "Heat meets frost: thermal shock bursts everything near.",
		"immunity": "Elites and bosses take the full burst."},
	"arc+heat": {"behaviour": "grind", "kind": "sustained", "radius": 5.0, "seconds": 3.0, "interval": 0.5,
		"damage": 7.5, "elite_share": 0.1,
		"found": "Arc meets heat: superheated plasma burns on a beat.",
		"immunity": "Elites and bosses take a tenth of the grind."},
}

const LAYER_MULT := {
	"armour": {"kinetic": 1.5, "frost": 1.0, "arc": 0.75},
	"shield": {"arc": 1.5, "frost": 1.0, "kinetic": 0.75},
	"health": {"frost": 1.5, "kinetic": 1.0, "arc": 0.75},
}
const LAYER_MULT_W50 := {
	"armour": {"heat": 1.25},
	"shield": {"heat": 1.0},
	"health": {"heat": 1.25},
}


static func all_elements() -> Array:
	return ELEMENTS_W50.duplicate()


static func all_rows() -> Dictionary:
	return ROWS.merged(ROWS_W50, true)


static func all_fusions() -> Dictionary:
	return FUSIONS.merged(FUSIONS_W50, true)


static func layer_mult(layer_id: String, element_id: String) -> float:
	var base: Dictionary = LAYER_MULT.get(layer_id, {})
	if base.has(element_id):
		return float(base[element_id])
	return float(LAYER_MULT_W50.get(layer_id, {}).get(element_id, 1.0))


static func fusion_key(a: String, b: String) -> String:
	return "%s+%s" % [a, b] if a < b else "%s+%s" % [b, a]


static func fuse(a: String, b: String) -> Dictionary:
	if a == b:
		return {}
	var k := fusion_key(a, b)
	if FUSIONS.has(k):
		return FUSIONS[k]
	return FUSIONS_W50.get(k, {})


static func card_text(row: Dictionary) -> String:
	return "%s %s" % [row.get("found", ""), row.get("immunity", "")]


static func elite_rules(kind: String, elite: bool) -> bool:
	return elite or kind in BOSS_KINDS or kind.begins_with("brindle")


static func key(element_id: String, material_id: String) -> String:
	return "%s:%s" % [element_id, material_id]


static func resolve(element_id: String, material_id: String) -> Dictionary:
	var k := key(element_id, material_id)
	if ROWS.has(k):
		return ROWS[k]
	return ROWS_W50.get(k, {})


static func problems() -> Array[String]:
	return _validate_tables(ELEMENTS, ROWS, FUSIONS)


static func all_problems() -> Array[String]:
	return _validate_tables(ELEMENTS_W50, all_rows(), all_fusions())


static func _validate_tables(elements: Array, rows: Dictionary, fusions: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for row_key in rows:
		var pair: PackedStringArray = String(row_key).split(":")
		if pair.size() != 2 or not pair[0] in elements or not pair[1] in MATERIALS:
			found.append("row %s names an unknown element or material" % row_key)
		var row: Dictionary = rows[row_key]
		if row.get("behaviour", "") == "create_surface" and not SURFACES.has(row.get("surface", "")):
			found.append("row %s names a missing surface" % row_key)
	for fusion_id in fusions:
		var parts: PackedStringArray = String(fusion_id).split("+")
		var fusion: Dictionary = fusions[fusion_id]
		if parts.size() != 2 or not parts[0] in elements or not parts[1] in elements or fusion_key(parts[0], parts[1]) != fusion_id \
				or parts[0] == parts[1]:
			found.append("fusion %s is not a pair of two different elements in key order" % fusion_id)
		if FUSION_KINDS.get(fusion.get("behaviour", ""), "") != fusion.get("kind", "?"):
			found.append("fusion %s names an unknown behaviour or the wrong kind" % fusion_id)
		if String(fusion.get("immunity", "")) == "":
			found.append("fusion %s states no elite rule" % fusion_id)
		if fusion.get("kind", "") == "sustained" and not float(fusion.get("elite_share", 1.0)) <= 0.1:
			found.append("fusion %s lets elites take more than 10%% of it" % fusion_id)
	return found
