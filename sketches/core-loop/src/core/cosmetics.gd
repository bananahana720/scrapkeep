extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# Looks only, never power. A row may carry nothing but the ALLOWED keys, so a stat
# cannot ride in on a cosmetic. A tint is a new colour, never a hostile hue: those mean
# danger on screen (Palette.HAZARD for threats, BRASS for the boss).
#
# slot    always "paint": trail and topper were cut 2026-10-05 (alpha wave 14)
# pilot   a pilot id, or "" for any pilot
# name    the label shown on the class card's paint picker
# starter owned from the first run
# tint    a Color, required

const SLOTS := ["paint"]
const ALLOWED := ["slot", "pilot", "name", "starter", "tint"]
const HOSTILE := [Palette.HAZARD, Palette.BRASS]
const HOSTILE_DISTANCE := 0.2
const MIN_ROWS := 6

const ROWS := {
	"paint_any_salt": {"slot": "paint", "pilot": "", "name": "Salt White", "starter": true, "tint": Color("e9ecea")},
	"paint_any_night": {"slot": "paint", "pilot": "", "name": "Night Slate", "starter": false, "tint": Color("2b3a4a")},
	"paint_sable_lagoon": {"slot": "paint", "pilot": "pylon_engineer", "name": "Lagoon", "starter": true, "tint": Color("2fc6b5")},
	"paint_sable_violet": {"slot": "paint", "pilot": "pylon_engineer", "name": "Violet Static", "starter": false, "tint": Color("8a6bd6")},
	"paint_rivet_moss": {"slot": "paint", "pilot": "runner_gunner", "name": "Moss", "starter": true, "tint": Color("6f9a4a")},
	"paint_rivet_forge": {"slot": "paint", "pilot": "runner_gunner", "name": "Forge Blue", "starter": false, "tint": Color("3a6fb0")},
	"paint_kest_plum": {"slot": "paint", "pilot": "demolitions_caster", "name": "Ember Plum", "starter": true, "tint": Color("8a3f6e")},
	"paint_kest_dusk": {"slot": "paint", "pilot": "demolitions_caster", "name": "Dusk Pink", "starter": false, "tint": Color("d68ab0")},
	"paint_tarn_ash": {"slot": "paint", "pilot": "tarn", "name": "Redjaw Ash", "starter": true, "tint": Color("5e5a54")},
	"paint_tarn_dig": {"slot": "paint", "pilot": "tarn", "name": "Dig Ochre", "starter": false, "tint": Color("9a6a32")},
	"paint_tally_cream": {"slot": "paint", "pilot": "tally", "name": "Ledger Cream", "starter": true, "tint": Color("f7f1e3")},
	"paint_cannon_verdigris": {"slot": "paint", "pilot": "remembered_cannon", "name": "Old Verdigris", "starter": true, "tint": Color("4f7f7a")},
	"paint_any_kelp": {"slot": "paint", "pilot": "", "name": "Kelp", "starter": false, "tint": Color("3f6b4f")},
	"paint_any_cobalt": {"slot": "paint", "pilot": "", "name": "Cobalt", "starter": false, "tint": Color("2a4fd6")},
	"paint_any_brine": {"slot": "paint", "pilot": "", "name": "Brine", "starter": false, "tint": Color("7fb8c4")},
	"paint_any_ink": {"slot": "paint", "pilot": "", "name": "Ink", "starter": false, "tint": Color("1c1f2b")},
	"paint_any_sky": {"slot": "paint", "pilot": "", "name": "Highdraft Sky", "starter": false, "tint": Color("8fc4ec")},
	"paint_any_moth": {"slot": "paint", "pilot": "", "name": "Moth Grey", "starter": false, "tint": Color("a39cb3")},
}


static func ids() -> Array:
	return ROWS.keys()


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})


# The ids that fit a slot for a pilot: rows for any pilot and rows for that pilot.
static func for_slot(slot: String, pilot: String) -> Array:
	var out: Array = []
	for id in ROWS:
		var r: Dictionary = ROWS[id]
		if r["slot"] == slot and (r["pilot"] == "" or r["pilot"] == pilot):
			out.append(id)
	return out


static func is_hostile(tint: Color) -> bool:
	for hue in HOSTILE:
		var d := Vector3(tint.r - hue.r, tint.g - hue.g, tint.b - hue.b).length()
		if d < HOSTILE_DISTANCE:
			return true
	return false


# pilots: an array of pilot ids.
static func validate(rows: Dictionary, pilots: Array) -> Array:
	var problems: Array = []
	var starter_paints := 0
	if rows.size() < MIN_ROWS:
		problems.append("table: needs at least %d rows, has %d" % [MIN_ROWS, rows.size()])
	for id in rows:
		var r: Dictionary = rows[id]
		for key in r:
			if not ALLOWED.has(key):
				problems.append("%s: key %s is not allowed on a cosmetic" % [id, key])
		if not SLOTS.has(r.get("slot", "")):
			problems.append("%s: slot %s is not one of the slots" % [id, r.get("slot", "")])
		var pilot = r.get("pilot")
		if not (pilot is String) or (pilot != "" and not pilots.has(pilot)):
			problems.append("%s: pilot %s is neither empty nor a real pilot" % [id, pilot])
		if str(r.get("name", "")) == "":
			problems.append("%s: name is empty" % id)
		if not (r.get("starter") is bool):
			problems.append("%s: starter must be a bool" % id)
		if not r.has("tint"):
			problems.append("%s: needs a tint" % id)
		elif not (r["tint"] is Color):
			problems.append("%s: tint must be a Color" % id)
		elif is_hostile(r["tint"]):
			problems.append("%s: tint is a hostile hue" % id)
		if r.get("slot", "") == "paint" and r.get("starter", false) == true:
			starter_paints += 1
	if starter_paints < 1:
		problems.append("table: needs at least one starter paint")
	return problems
