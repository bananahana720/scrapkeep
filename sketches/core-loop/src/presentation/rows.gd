extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Roster := preload("res://src/combat/roster.gd")

# The event_kinds row for a fact, as presentation reads it. The spine's table wins.
# Until the spine lands the demo-spec rows, these fallbacks carry the same fields
# the reconciled change requests name, so audio and VFX read one source either way.

const FALLBACK := {
	"beacon_unsealed": {"group": "flow", "color": Palette.ARC, "shape": "star", "sound": "stinger_unseal", "priority": 3},
	"heft_class_changed": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "class_up", "priority": 3},
	"scrap_lost": {"group": "economy", "color": Palette.RUST, "shape": "cross", "sound": "scrap_rip", "priority": 2},
	"strike_deflected": {"group": "combat", "color": Palette.SAND, "shape": "square", "sound": "clank", "priority": 1},
	"threat_rose": {"group": "event", "color": Palette.RUST, "shape": "chevron", "sound": "threat_up", "priority": 2},
	"core_gained": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "core_socket", "priority": 2},
	"synergy_discovered": {"group": "economy", "color": Palette.ARC, "shape": "star", "sound": "synergy_fanfare", "priority": 3},
	"interaction_found": {"group": "event", "color": Palette.SAND, "shape": "diamond", "sound": "found_chime", "priority": 2},
	"element_resolved": {"group": "event", "color": Palette.ARC, "shape": "burst", "sound": "element_resolved", "priority": 1},
}

# element_resolved picks its voice by what the element did to the material.
const ELEMENT_SOUNDS := {"freeze": "ice_form", "ice": "ice_form", "frost": "ice_form", "chill": "ice_form",
	"electr": "zap_hum", "zap": "zap_hum", "arc": "zap_hum", "shock": "zap_hum", "charge": "zap_hum",
	"shatter": "shatter", "break": "shatter", "crack": "shatter"}


static func row(kind: String) -> Dictionary:
	if EventKinds.has(kind):
		return EventKinds.row(kind)
	for table in [EventKinds.UI_ROWS, EventKinds.LOOT_ROWS, FALLBACK]:
		if table.has(kind):
			return table[kind]
	return {}


# The sound a kind is heard as. context carries who is involved: "motif" (the player's
# class motif id), "hold" (hold_started's kind, a roster mechanic) and "faction".
static func sound(kind: String, context := {}) -> String:
	return heard(row(kind), context)


# A row's baked sound_next when the bank has it, else its stand-in `sound`. Either may
# be symbolic and resolve through the class or roster row (resolve).
static func heard(entry: Dictionary, context := {}) -> String:
	var next := resolve(String(entry.get("sound_next", "")), context)
	if next != "" and SfxBank.has_recipe(next):
		return next
	return resolve(String(entry.get("sound", "")), context)


# A symbolic sound id as the bank id it means in this context, or the id itself when it
# is concrete; "" when the context lacks what the id needs.
#   class_motif      the class's ready pulse (<motif>_ready): the HUD's class tune
#   class_break      the class's break-free (<motif>_break)
#   motif_release    the class's whole motif resolved (release_of)
#   hold_by_kind     the holding unit's loop (hold_of)
#   faction_arrival  the faction's roster arrival, voiced for the class
#   mind_quote       the Mind playing the class motif back (Roster.voiced)
static func resolve(id: String, context := {}) -> String:
	var motif := String(context.get("motif", ""))
	match id:
		"class_motif":
			return _baked(motif + "_ready") if motif != "" else ""
		"class_break":
			return _baked(motif + "_break") if motif != "" else ""
		"motif_release":
			return release_of(motif)
		"hold_by_kind":
			return hold_of(String(context.get("hold", "")))
		"faction_arrival":
			if not context.has("faction"):
				return ""
			return Roster.voiced(String(Roster.faction(String(context["faction"]))["arrival"]), motif)
		"mind_quote":
			return Roster.voiced(id, motif) if motif != "" else ""
	return id


static func _baked(id: String) -> String:
	return id if SfxBank.has_recipe(id) else ""


# A class's release is the one bank recipe named for its motif that is neither a
# variant (<motif>_ready, <motif>_break) nor a cue an event row names for itself
# (vault_kicked's sable_octave_leap, once baked, stays vault_kicked's). A second
# candidate plays the stand-in, and audio_cue_resolution_test fails on it.
static func release_of(motif: String) -> String:
	var found := releases(motif)
	return found[0] if found.size() == 1 else ""


static func releases(motif: String) -> Array:
	var found: Array = []
	if motif == "":
		return found
	var named := _named_by_rows()
	for id in SfxBank.TRIM_DB:
		if id.begins_with(motif + "_") and not id in [motif + "_ready", motif + "_break"] and not id in named:
			found.append(id)
	return found


# Every sound any event_kinds table plans, in `sound` or `sound_next`: a row's own planned sound
# is never a class's release, whichever table the row sits in.
static func _named_by_rows() -> Array:
	var named: Array = []
	for table in (EventKinds as GDScript).get_script_constant_map().values():
		if not table is Dictionary:
			continue
		for row in table.values():
			if row is Dictionary:
				named.append(String(row.get("sound_next", "")))
				named.append(String(row.get("sound", "")))
	return named


# The hold loop of the roster unit whose mechanic is kind: the first of its `hold` and
# `tag` that is a baked hold loop (the netcaster's `hold` still names the zap stand-in;
# its tag is the net), else its `hold` stand-in. "" for a kind no unit holds with.
static func hold_of(kind: String) -> String:
	for id in Roster.ROWS:
		var unit: Dictionary = Roster.ROWS[id]
		if unit["mechanic"] != kind:
			continue
		for candidate in [String(unit.get("hold", "")), String(unit.get("tag", ""))]:
			if candidate.begins_with("hold_") and SfxBank.has_recipe(candidate):
				return candidate
		return String(unit.get("hold", ""))
	return ""


static func priority(kind: String) -> int:
	return int(row(kind).get("priority", 1))


static func color(kind: String) -> Color:
	return row(kind).get("color", Palette.SAND)


static func shape(kind: String) -> String:
	return String(row(kind).get("shape", "none"))


static func element_sound(behaviour: String) -> String:
	var lowered := behaviour.to_lower()
	for key in ELEMENT_SOUNDS:
		if lowered.contains(key):
			return ELEMENT_SOUNDS[key]
	return "element_resolved"


# Every sound id the bank must bake: the spine's rows plus the fallbacks and the
# element variants, so a new row never plays silence.
static func sound_ids() -> Array:
	var ids := []
	for kind in EventKinds.ROWS:
		var id: String = EventKinds.ROWS[kind]["sound"]
		if not id in ids:
			ids.append(id)
	for kind in FALLBACK:
		var id: String = FALLBACK[kind]["sound"]
		if not id in ids:
			ids.append(id)
	for id in ["ice_form", "zap_hum", "shatter", "class_down"]:
		if not id in ids:
			ids.append(id)
	return ids
