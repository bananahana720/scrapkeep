extends RefCounted

# The element x material table (TADR-009): one data table, keyed by element id and
# material id, that every source consults, whether a part's dash, a slam or a stage
# event. A pair with no row does nothing (default-deny). A row names a reviewed
# behaviour and its numbers; element_field.gd owns the three behaviours:
#
#   create_surface  a temporary StaticBody3D on the world layer: the ball, the grapple
#                   and the camera all treat it as ground.
#   electrify       the water carries the arc for a few seconds: enemies standing in it
#                   take arc hits on a fixed beat.
#   shatter         created ice bursts into a shard nova that strikes enemies near it.

# kinetic is what every slam carries, whatever parts you hold.
const ELEMENTS := ["frost", "arc", "kinetic"]
const MATERIALS := ["water", "ice"]

const SURFACES := {
	# thickness is the slab's depth below its top face; seconds is its effect window.
	"ice": {"material": "ice", "radius": 3.6, "thickness": 0.9, "seconds": 9.0, "fade": 1.5},
}

# found is the plain description the codex's Found list gets the first time the row
# fires in a run (DEMO-SPEC: accidental synergies are unnamed).
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


# SG2 fusion rows (comps/W13-INTEGRATION-3.md SG2; comps/gunfire/elements-and-fusion.md). An
# element that reaches an enemy leaves it a status for STATUS_SECONDS: an arc strike, a slam
# (kinetic) or frost the field applies within TOUCH_RADIUS. A second, different element on an
# enemy holding a status fuses once into the row for the pair, the same in either order, and
# spends both statuses. element_field.gd owns the three behaviours:
#
#   lock      control: holds every enemy in the area still for seconds. Elites and bosses are
#             immune, as stated on the card; there is no roll.
#   overload  burst: one strike of damage on every enemy in the area.
#   grind     sustained: strikes every enemy in the area on a beat for seconds; elites and
#             bosses take elite_share of it.
#
# The area is committed when the pair fuses and drawn for FUSION_LEAD_FRAMES before any damage;
# damage and hold read that same committed area. Numbers are start values, tuned from play.
const STATUS_SECONDS := 5.0
const TOUCH_RADIUS := 2.0
# Strike kinds that leave a status, by the element they carry. Frost reaches enemies only
# through the field (TOUCH_ELEMENTS).
const STATUS_KINDS := {"arc": "arc", "slam": "kinetic"}
const TOUCH_ELEMENTS := ["frost"]
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

# SG2 one layer table (comps/gunfire/heroes-and-ascensions.md, the 150 / 100 / 75 shape): what
# each defence bar class (defence_bars.gd) takes from each element. Each layer has one weak
# element and one resisted one, and no two layers share a weak element. A hit with no element
# is 100% everywhere. Every layer reads this table and no other.
const LAYER_MULT := {
	"armour": {"kinetic": 1.5, "frost": 1.0, "arc": 0.75},
	"shield": {"arc": 1.5, "frost": 1.0, "kinetic": 0.75},
	"health": {"frost": 1.5, "kinetic": 1.0, "arc": 0.75},
}


static func layer_mult(layer_id: String, element_id: String) -> float:
	return float(LAYER_MULT.get(layer_id, {}).get(element_id, 1.0))


static func fusion_key(a: String, b: String) -> String:
	return "%s+%s" % [a, b] if a < b else "%s+%s" % [b, a]


# The one fusion lookup: the row for two different elements, or {} (default-deny).
static func fuse(a: String, b: String) -> Dictionary:
	if a == b:
		return {}
	return FUSIONS.get(fusion_key(a, b), {})


# What the codex card says the first time a fusion fires: the find, then its elite rule, so the
# card's immunity text is the row's.
static func card_text(row: Dictionary) -> String:
	return "%s %s" % [row.get("found", ""), row.get("immunity", "")]


# Elites (any member of the director's elite pack, or an elite affix) and bosses take no
# control effect and only elite_share of a sustained one.
static func elite_rules(kind: String, elite: bool) -> bool:
	return elite or kind in BOSS_KINDS or kind.begins_with("brindle")


static func key(element_id: String, material_id: String) -> String:
	return "%s:%s" % [element_id, material_id]


# The one lookup. Returns the row, or {} when the pair does nothing.
static func resolve(element_id: String, material_id: String) -> Dictionary:
	return ROWS.get(key(element_id, material_id), {})


# Admission (TADR-009): every row names a known element, material and surface. Returns
# the problems found; an empty list means the table is admissible.
static func problems() -> Array[String]:
	var found: Array[String] = []
	for row_key in ROWS:
		var pair: PackedStringArray = String(row_key).split(":")
		if pair.size() != 2 or not pair[0] in ELEMENTS or not pair[1] in MATERIALS:
			found.append("row %s names an unknown element or material" % row_key)
		var row: Dictionary = ROWS[row_key]
		if row.get("behaviour", "") == "create_surface" and not SURFACES.has(row.get("surface", "")):
			found.append("row %s names a missing surface" % row_key)
	for fusion_id in FUSIONS:
		var parts: PackedStringArray = String(fusion_id).split("+")
		var fusion: Dictionary = FUSIONS[fusion_id]
		if parts.size() != 2 or not parts[0] in ELEMENTS or not parts[1] in ELEMENTS or fusion_key(parts[0], parts[1]) != fusion_id \
				or parts[0] == parts[1]:
			found.append("fusion %s is not a pair of two different elements in key order" % fusion_id)
		if FUSION_KINDS.get(fusion.get("behaviour", ""), "") != fusion.get("kind", "?"):
			found.append("fusion %s names an unknown behaviour or the wrong kind" % fusion_id)
		if String(fusion.get("immunity", "")) == "":
			found.append("fusion %s states no elite rule" % fusion_id)
		if fusion.get("kind", "") == "sustained" and not float(fusion.get("elite_share", 1.0)) <= 0.1:
			found.append("fusion %s lets elites take more than 10%% of it" % fusion_id)
	return found
