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
	return found
