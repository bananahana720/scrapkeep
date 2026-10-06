extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# Looks only, never power. A row may carry nothing but the ALLOWED keys, so a stat
# cannot ride in on a cosmetic. A tint is a new colour, never a hostile hue: those mean
# danger on screen (Palette.HAZARD for threats, BRASS for the boss).
#
# slot    paint, trail, decal or companion_paint; the latter belongs to SPIL-9
# pilot   a pilot id, or "" for any pilot
# name    the label shown on the class card's paint picker
# starter owned from the first run
# tint    a Color, required
# asset   optional art id; required for the three additional slots
# mask    decal atlas tile, zero-based; forbidden on other slots

const SLOTS := ["paint", "trail", "decal", "companion_paint"]
const ALLOWED := ["slot", "pilot", "name", "starter", "tint", "asset", "mask"]
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
	"trail_salt_skip": {"slot": "trail", "pilot": "", "name": "Salt Skip", "starter": false, "tint": Color("e9ecea"), "asset": "trail_salt_skip"},
	"trail_ink_stitch": {"slot": "trail", "pilot": "", "name": "Ink Stitch", "starter": false, "tint": Color("2b3a4a"), "asset": "trail_ink_stitch"},
	"trail_plum_curl": {"slot": "trail", "pilot": "", "name": "Plum Curl", "starter": false, "tint": Color("8a3f6e"), "asset": "trail_plum_curl"},
	"trail_forge_chips": {"slot": "trail", "pilot": "", "name": "Forge Chips", "starter": false, "tint": Color("3a6fb0"), "asset": "trail_forge_chips"},
	"trail_moth_tuft": {"slot": "trail", "pilot": "", "name": "Moth Tuft", "starter": false, "tint": Color("a39cb3"), "asset": "trail_moth_tuft"},
	"trail_rose_wash": {"slot": "trail", "pilot": "", "name": "Rose Wash", "starter": false, "tint": Color("d68ab0"), "asset": "trail_rose_wash"},
	"decal_fern": {"slot": "decal", "pilot": "", "name": "Fern", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_fern", "mask": 0},
	"decal_patch": {"slot": "decal", "pilot": "", "name": "Patch", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_patch", "mask": 1},
	"decal_snail_shell": {"slot": "decal", "pilot": "", "name": "Snail Shell", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_snail_shell", "mask": 2},
	"decal_thimble": {"slot": "decal", "pilot": "", "name": "Thimble", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_thimble", "mask": 3},
	"decal_mushroom": {"slot": "decal", "pilot": "", "name": "Mushroom", "starter": false, "tint": Color("906681"), "asset": "decal_mushroom", "mask": 4},
	"decal_paw": {"slot": "decal", "pilot": "", "name": "Paw", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_paw", "mask": 5},
	"decal_seashell": {"slot": "decal", "pilot": "", "name": "Seashell", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_seashell", "mask": 6},
	"decal_moth": {"slot": "decal", "pilot": "", "name": "Moth", "starter": false, "tint": Color("906681"), "asset": "decal_moth", "mask": 7},
	"companion_paint_night": {"slot": "companion_paint", "pilot": "", "name": "Night Slate", "starter": false, "tint": Color("2b3a4a"), "asset": "companion_paint_night"},
	"companion_paint_forge": {"slot": "companion_paint", "pilot": "", "name": "Forge Blue", "starter": false, "tint": Color("3a6fb0"), "asset": "companion_paint_forge"},
	"companion_paint_plum": {"slot": "companion_paint", "pilot": "", "name": "Ember Plum", "starter": false, "tint": Color("8a3f6e"), "asset": "companion_paint_plum"},
	"companion_paint_salt": {"slot": "companion_paint", "pilot": "", "name": "Salt White", "starter": false, "tint": Color("e9ecea"), "asset": "companion_paint_salt"},
	"companion_paint_dusk": {"slot": "companion_paint", "pilot": "", "name": "Dusk Pink", "starter": false, "tint": Color("d68ab0"), "asset": "companion_paint_dusk"},
	"companion_paint_moth": {"slot": "companion_paint", "pilot": "", "name": "Moth Grey", "starter": false, "tint": Color("a39cb3"), "asset": "companion_paint_moth"},
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
		var slot: String = str(r.get("slot", ""))
		if slot != "paint" and SLOTS.has(slot):
			if not (r.get("asset") is String) or str(r.get("asset", "")).strip_edges() == "":
				problems.append("%s: slot %s needs an asset id" % [id, slot])
		if r.has("asset") and (not (r["asset"] is String) or str(r["asset"]).strip_edges() == ""):
			problems.append("%s: asset must be a nonempty id" % id)
		if slot == "decal":
			if not (r.get("mask") is int) or int(r.get("mask", -1)) < 0 or int(r.get("mask", -1)) > 7:
				problems.append("%s: decal needs a mask tile from 0 to 7" % id)
		elif r.has("mask"):
			problems.append("%s: mask belongs only to a decal" % id)
		if slot == "companion_paint" and r.get("pilot", "") != "":
			problems.append("%s: companion paint cannot name a pilot" % id)
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


static func owner_for(pilot: String, slot: String) -> String:
	return "spil9" if slot == "companion_paint" else pilot


static func fits(id: String, owner: String, slot: String) -> bool:
	var r := row(id)
	if r.is_empty() or r["slot"] != slot:
		return false
	if slot == "companion_paint":
		return owner == "spil9"
	return owner != "spil9" and (r["pilot"] == "" or r["pilot"] == owner)


# Consumers supply art ids mapped to imported resources or resource paths. Empty means
# the slot's unmodified appearance; a missing optional asset is warned once per art id.
var _warned := {}


func resolve(id: String, assets: Dictionary) -> Dictionary:
	var r := row(id)
	if r.is_empty():
		if id != "":
			_warn(id)
		return {}
	if not r.has("asset"):
		return r
	var asset_id: String = r["asset"]
	var resource = assets.get(asset_id)
	if resource is String:
		resource = load(resource) if ResourceLoader.exists(resource) else null
	if not resource is Resource:
		_warn(asset_id)
		return {}
	var out := r.duplicate()
	out["resource"] = resource
	return out


func _warn(asset_id: String) -> void:
	if _warned.has(asset_id):
		return
	_warned[asset_id] = true
	push_warning("cosmetics: missing asset %s; using default appearance" % asset_id)
