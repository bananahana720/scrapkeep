extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# Looks only, never power. A row may carry nothing but the ALLOWED keys, so a stat
# cannot ride in on a cosmetic. A tint is a new colour, never a hostile hue: those mean
# danger on screen (Palette.HAZARD for threats, BRASS for the boss).
#
# slot    one of SLOTS (design-v3/CUSTOMIZE.md section 2); OWNERS slots belong to SPIL-9 or the bay
# pilot   a pilot id, or "" for any pilot; required on a PILOT_ONLY slot, forbidden on an OWNERS slot
# name    the label shown on the class card's paint picker and the customize page's card
# starter owned from the first run; only a paint may be a starter
# tint    a Color, required; also the card's swatch
# asset   art id; required on every slot but paint. A shell row's asset is its GLB stem
# mask    decal atlas tile, zero-based, below MASK_TILES; forbidden on other slots

const SLOTS := ["paint", "trail", "decal", "companion_paint", "outfit", "shell", "companion_skin", "bay_decor"]
# Slots worn by someone other than the pilot. Every other slot is worn per pilot.
const OWNERS := {"companion_paint": "spil9", "companion_skin": "spil9", "bay_decor": "bay"}
# Slots whose rows must name a pilot: they fit one body.
const PILOT_ONLY := ["outfit", "shell"]
# Slots that mount a scene (resolve to a PackedScene with no light and no collision).
const SCENE_SLOTS := ["trail", "outfit", "shell", "companion_skin", "bay_decor"]
const MASK_TILES := 16
# Row ids whose art has not landed. The page hides them; a grant still records them.
# The art unit removes its id here, as PENDING_PILOTS works (achievements.gd).
const PENDING_ART := []
# Test-only: ids treated as extra PENDING_ART so tests reach the pending paths while the list is
# empty. Production never sets it; a test that sets it clears it before it finishes.
static var _test_pending: Array[String] = []


static func reset_for_tests() -> void:
	_test_pending.clear()
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
	# Four paints for the activity and discovery grants that paid head starts no screen shows
	# (systems audit pass D, row 31, 11 Nov 2026). Tint only, so no art is owed.
	"paint_any_shift": {"slot": "paint", "pilot": "", "name": "Shift Denim", "starter": false, "tint": Color("4a6a8c")},
	"paint_any_mortar": {"slot": "paint", "pilot": "", "name": "Mortar Dust", "starter": false, "tint": Color("b8ab95")},
	"paint_any_cache": {"slot": "paint", "pilot": "", "name": "Cache Green", "starter": false, "tint": Color("4e8a6c")},
	"paint_any_spark": {"slot": "paint", "pilot": "", "name": "Spark Teal", "starter": false, "tint": Color("39a8c9")},
	# Eleven paints for the content-family records that paid nothing (feature-fit.md row 30, 12 Nov 2026).
	# Tint only, so no art is owed; none is mint, cobalt, pearl, gold or the Mind's purple.
	"paint_any_jolt": {"slot": "paint", "pilot": "", "name": "Rubber Mat", "starter": false, "tint": Color("444a52")},
	"paint_any_sluice": {"slot": "paint", "pilot": "", "name": "Sluice Foam", "starter": false, "tint": Color("cfe3dc")},
	"paint_any_tether": {"slot": "paint", "pilot": "", "name": "Tether Oxblood", "starter": false, "tint": Color("6e2a2a")},
	"paint_any_soaked": {"slot": "paint", "pilot": "", "name": "Soaked Navy", "starter": false, "tint": Color("23406b")},
	"paint_any_float": {"slot": "paint", "pilot": "", "name": "Boom Teak", "starter": false, "tint": Color("7a5236")},
	"paint_any_foreman": {"slot": "paint", "pilot": "", "name": "Foreman Khaki", "starter": false, "tint": Color("8c7d4f")},
	"paint_any_signal": {"slot": "paint", "pilot": "", "name": "Signal Steel", "starter": false, "tint": Color("7d8b96")},
	"paint_any_tape": {"slot": "paint", "pilot": "", "name": "Tape Umber", "starter": false, "tint": Color("3e2c22")},
	"paint_any_stake": {"slot": "paint", "pilot": "", "name": "Stake Clay", "starter": false, "tint": Color("9a7a62")},
	"paint_any_maker": {"slot": "paint", "pilot": "", "name": "Workshop Olive", "starter": false, "tint": Color("6b6b2e")},
	"paint_any_overflow": {"slot": "paint", "pilot": "", "name": "Overflow Sea", "starter": false, "tint": Color("2f6f7f")},
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
	"decal_fern": {"slot": "decal", "pilot": "", "name": "Fern", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_fern_mask.png", "mask": 0},
	"decal_patch": {"slot": "decal", "pilot": "", "name": "Patch", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_patch_mask.png", "mask": 1},
	"decal_snail_shell": {"slot": "decal", "pilot": "", "name": "Snail Shell", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_snail_shell_mask.png", "mask": 2},
	"decal_thimble": {"slot": "decal", "pilot": "", "name": "Thimble", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_thimble_mask.png", "mask": 3},
	"decal_mushroom": {"slot": "decal", "pilot": "", "name": "Mushroom", "starter": false, "tint": Color("906681"), "asset": "decal_mushroom_mask.png", "mask": 4},
	"decal_paw": {"slot": "decal", "pilot": "", "name": "Paw", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_paw_mask.png", "mask": 5},
	"decal_seashell": {"slot": "decal", "pilot": "", "name": "Seashell", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_seashell_mask.png", "mask": 6},
	"decal_moth": {"slot": "decal", "pilot": "", "name": "Moth", "starter": false, "tint": Color("906681"), "asset": "decal_moth_mask.png", "mask": 7},
	"companion_paint_night": {"slot": "companion_paint", "pilot": "", "name": "Night Slate", "starter": false, "tint": Color("2b3a4a"), "asset": "companion_paint_night"},
	"companion_paint_forge": {"slot": "companion_paint", "pilot": "", "name": "Forge Blue", "starter": false, "tint": Color("3a6fb0"), "asset": "companion_paint_forge"},
	"companion_paint_plum": {"slot": "companion_paint", "pilot": "", "name": "Ember Plum", "starter": false, "tint": Color("8a3f6e"), "asset": "companion_paint_plum"},
	"companion_paint_salt": {"slot": "companion_paint", "pilot": "", "name": "Salt White", "starter": false, "tint": Color("e9ecea"), "asset": "companion_paint_salt"},
	"companion_paint_dusk": {"slot": "companion_paint", "pilot": "", "name": "Dusk Pink", "starter": false, "tint": Color("d68ab0"), "asset": "companion_paint_dusk"},
	"companion_paint_moth": {"slot": "companion_paint", "pilot": "", "name": "Moth Grey", "starter": false, "tint": Color("a39cb3"), "asset": "companion_paint_moth"},
	# Shared: the skill bar's three earned items (CUSTOMIZE.md section 8). Art delivered.
	"trail_any_downbeat": {"slot": "trail", "pilot": "", "name": "Downbeat", "starter": false, "tint": Color("8a5a3a"), "asset": "trail_any_downbeat"},
	"decal_curtain_call": {"slot": "decal", "pilot": "", "name": "Curtain Call", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_curtain_call_mask.png", "mask": 9},
	"companion_skin_till_bell": {"slot": "companion_skin", "pilot": "", "name": "Till Bell", "starter": false, "tint": Color("8a5a3a"), "asset": "companion_skin_till_bell"},
	# --- pylon_engineer (Sable): P-C Sable adds its rows here ---
	"trail_sable_cable": {"slot": "trail", "pilot": "pylon_engineer", "name": "Cable Stitch", "starter": false, "tint": Color("8bf0d3"), "asset": "trail_sable_cable"},
	"decal_sable_spool": {"slot": "decal", "pilot": "pylon_engineer", "name": "Spool and Wrench", "starter": false, "tint": Color("d2c5a5"), "asset": "decal_sable_spool_mask.png", "mask": 8},
	"shell_sable_felt": {"slot": "shell", "pilot": "pylon_engineer", "name": "Felt Rig", "starter": false, "tint": Color("8c8577"), "asset": "shell_sable_felt"},
	# --- end pylon_engineer ---
	# --- runner_gunner (Rivet): P-C Rivet adds its rows here ---
	"trail_rivet_swarf": {"slot": "trail", "pilot": "runner_gunner", "name": "Swarf Curl", "starter": false, "tint": Color("ae7240"), "asset": "trail_rivet_swarf"},
	"outfit_rivet_hood": {"slot": "outfit", "pilot": "runner_gunner", "name": "Welding Hood", "starter": false, "tint": Color("d2c5a5"), "asset": "outfit_rivet_hood"},
	"shell_rivet_calibrated": {"slot": "shell", "pilot": "runner_gunner", "name": "Calibrated", "starter": false, "tint": Color("d2c5a5"), "asset": "shell_rivet_calibrated"},
	# --- end runner_gunner ---
	# --- demolitions_caster (Kest): P-C Kest adds its rows here ---
	"trail_kest_fuse_smoke": {"slot": "trail", "pilot": "demolitions_caster", "name": "Fuse Smoke", "starter": false, "tint": Color("8c8577"), "asset": "trail_kest_fuse_smoke"},
	# Rigger Harness (outfit_kest_rigger) cut for alpha, Andrew 2026-10-16: the pod and ring hide a body outfit
	# and its straps clash with the wing fans (COSMETICS-ART-BRIEFS.md). Homecoming pays this paint instead.
	"paint_kest_rigger": {"slot": "paint", "pilot": "demolitions_caster", "name": "Rigger Blue", "starter": false, "tint": Color("4f6f9a")},
	"shell_kest_roost": {"slot": "shell", "pilot": "demolitions_caster", "name": "Roost Frame", "starter": false, "tint": Color("8c8577"), "asset": "shell_kest_roost"},
	# --- end demolitions_caster ---
	# --- tarn (Tarn): P-C Tarn adds its rows here ---
	"trail_tarn_claw_marks": {"slot": "trail", "pilot": "tarn", "name": "Claw Marks", "starter": false, "tint": Color("d2c5a5"), "asset": "trail_tarn_claw_marks"},
	"shell_tarn_redjaw_teeth": {"slot": "shell", "pilot": "tarn", "name": "Redjaw Teeth", "starter": false, "tint": Color("d2c5a5"), "asset": "shell_tarn_redjaw_teeth"},
	"outfit_tarn_steady_cap": {"slot": "outfit", "pilot": "tarn", "name": "Steady Cap", "starter": false, "tint": Color("d2c5a5"), "asset": "outfit_tarn_steady_cap"},
	# --- end tarn ---
	# --- tally (Tally): P-C Tally adds its rows here ---
	# Ledger cream tape, a mulberry eyeshade with a copper rim, a copper abacus lattice; never brass.
	"trail_tally_punch_tape": {"slot": "trail", "pilot": "tally", "name": "Punch Tape", "starter": false, "tint": Color("f7f1e3"), "asset": "trail_tally_punch_tape"},
	"outfit_tally_eyeshade": {"slot": "outfit", "pilot": "tally", "name": "Eyeshade", "starter": false, "tint": Color("7a3b5c"), "asset": "outfit_tally_eyeshade"},
	"shell_tally_abacus": {"slot": "shell", "pilot": "tally", "name": "Abacus Lattice", "starter": false, "tint": Color("7a3b5c"), "asset": "shell_tally_abacus"},
	# --- end tally ---
	# --- remembered_cannon (the Cannon): P-C Cannon adds its rows here ---
	"trail_cannon_recital": {"slot": "trail", "pilot": "remembered_cannon", "name": "Recital", "starter": false, "tint": Color("6fb3a6"), "asset": "trail_cannon_recital"},
	"paint_cannon_lens": {"slot": "paint", "pilot": "remembered_cannon", "name": "Lens Glass", "starter": false, "tint": Color("d4f2b0")},
	"shell_cannon_choir": {"slot": "shell", "pilot": "remembered_cannon", "name": "Choir Barrel", "starter": false, "tint": Color("6fb3a6"), "asset": "shell_cannon_choir"},
	# --- end remembered_cannon ---
	# First-win secrets (secrets.gd PAINTS, Andrew's Q8 "A few secrets", 17 Oct): one alternate paint per
	# pilot, each named for that pilot's own crew-log beat. Their grant rows are hidden until a run is won.
	"paint_sable_overtime": {"slot": "paint", "pilot": "pylon_engineer", "name": "Overtime Arc", "starter": false, "tint": Color("b9a6ff")},
	"paint_rivet_inside_job": {"slot": "paint", "pilot": "runner_gunner", "name": "Inside Job", "starter": false, "tint": Color("9be564")},
	"paint_kest_knock_back": {"slot": "paint", "pilot": "demolitions_caster", "name": "Knocked Back", "starter": false, "tint": Color("4fd1d9")},
	"paint_tarn_unissued": {"slot": "paint", "pilot": "tarn", "name": "Unissued Red", "starter": false, "tint": Color("9e1b3b")},
	"paint_tally_carbon": {"slot": "paint", "pilot": "tally", "name": "Carbon Copy", "starter": false, "tint": Color("3d5a99")},
	"paint_cannon_velvet": {"slot": "paint", "pilot": "remembered_cannon", "name": "Curtain Velvet", "starter": false, "tint": Color("8e1f4f")},
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
			if not (r.get("mask") is int) or int(r.get("mask", -1)) < 0 or int(r.get("mask", -1)) > MASK_TILES - 1:
				problems.append("%s: decal needs a mask tile from 0 to %d" % [id, MASK_TILES - 1])
		elif r.has("mask"):
			problems.append("%s: mask belongs only to a decal" % id)
		if OWNERS.has(slot) and r.get("pilot", "") != "":
			problems.append("%s: %s is worn by %s and cannot name a pilot" % [id, slot, OWNERS[slot]])
		var pilot = r.get("pilot")
		if not (pilot is String) or (pilot != "" and not pilots.has(pilot)):
			problems.append("%s: pilot %s is neither empty nor a real pilot" % [id, pilot])
		elif PILOT_ONLY.has(slot) and pilot == "":
			problems.append("%s: %s fits one body and must name a pilot" % [id, slot])
		if r.get("starter", false) == true and slot != "paint":
			problems.append("%s: only a paint can be a starter" % id)
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
	# Table-level: content_registry validates one row at a time and skips "table:" problems.
	for id in PENDING_ART + _test_pending:
		if not rows.has(id):
			problems.append("table: PENDING_ART id %s is not a row" % id)
		elif rows[id].get("starter", false) == true:
			problems.append("table: PENDING_ART id %s is a starter" % id)
	return problems


static func is_pending(id: String) -> bool:
	return PENDING_ART.has(id) or _test_pending.has(id)


static func owner_for(pilot: String, slot: String) -> String:
	return OWNERS.get(slot, pilot)


static func fits(id: String, owner: String, slot: String) -> bool:
	var r := row(id)
	if r.is_empty() or r["slot"] != slot:
		return false
	if OWNERS.has(slot):
		return owner == OWNERS[slot]
	return owner != "" and not OWNERS.values().has(owner) and (r["pilot"] == "" or r["pilot"] == owner)


# Consumers supply art ids mapped to imported resources or resource paths. Empty means
# the slot's unmodified appearance; a missing optional asset is warned once per art id.
var _warned := {}
static var _warning_counts := {}
var _resolved := {}


static func asset_paths() -> Dictionary:
	var paths := {}
	var registry = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registry.json"))
	if registry is Dictionary:
		for entry in registry.get("assets", []):
			if entry is Dictionary and entry.has("id") and entry.has("path"):
				paths[entry["id"]] = entry["path"]
	# Materials and AtlasTextures are delivered in the cosmetics manifest, beside the GLBs.
	var manifest := art_manifest()
	for group in ["trails", "decals", "paints"]:
		for entry in manifest.get(group, []):
			paths[entry["id"]] = "res://assets/cosmetics/" + entry["path"]
	return paths


static func art_manifest() -> Dictionary:
	var doc = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cosmetics/cua_manifest.json"))
	return doc if doc is Dictionary else {}


func resolve(id: String, assets: Dictionary) -> Dictionary:
	var r := row(id)
	if r.is_empty():
		if id != "":
			_warn(id)
		return {}
	if not r.has("asset"):
		return r
	var asset_id: String = r["asset"]
	var source = assets.get(asset_id)
	if _resolved.has(asset_id) and typeof(_resolved[asset_id]["source"]) == typeof(source) and _resolved[asset_id]["source"] == source:
		return _resolved[asset_id]["row"]
	var resource = source
	if resource is String:
		resource = load(resource) if ResourceLoader.exists(resource) else null
	var valid: bool = (SCENE_SLOTS.has(r["slot"]) and resource is PackedScene) or (r["slot"] == "decal" and resource is Texture2D) or (r["slot"] == "companion_paint" and resource is StandardMaterial3D)
	if valid and resource is PackedScene and resource.get_state().get_node_count() == 0:
		valid = false
	if valid and resource is PackedScene:
		var scene: Node = resource.instantiate()
		valid = scene is Node3D
		var stack: Array[Node] = [scene]
		var meshes := 0
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			stack.append_array(node.get_children())
			if node is CollisionObject3D or node is Light3D:
				valid = false
			if node is MeshInstance3D:
				if node.mesh == null or node.mesh.get_surface_count() == 0:
					valid = false
				else:
					meshes += 1
					for surface in node.mesh.get_surface_count():
						if node.get_active_material(surface) == null:
							valid = false
		valid = valid and meshes > 0
		scene.free()
	if not valid:
		_warn(asset_id)
		_resolved[asset_id] = {"source": source, "row": {}}
		return {}
	var out := r.duplicate()
	out["resource"] = resource
	_resolved[asset_id] = {"source": source, "row": out}
	return out


func _warn(asset_id: String) -> void:
	if _warned.has(asset_id):
		return
	_warned[asset_id] = true
	if _warning_counts.has(asset_id):
		return
	_warning_counts[asset_id] = 1
	push_warning("cosmetics: missing asset %s; using default appearance" % asset_id)
