extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Roster := preload("res://src/combat/roster.gd")


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

const ELEMENT_SOUNDS := {"freeze": "ice_form", "ice": "ice_form", "frost": "ice_form", "chill": "ice_form",
	"electr": "zap_hum", "zap": "zap_hum", "arc": "zap_hum", "shock": "zap_hum", "charge": "zap_hum",
	"shatter": "shatter", "break": "shatter", "crack": "shatter"}


static func row(kind: String) -> Dictionary:
	if EventKinds.has(kind):
		return EventKinds.row(kind)
	for table in [EventKinds.UI_ROWS, EventKinds.LOOT_ROWS, EventKinds.WORLD_ROWS, FALLBACK]:
		if table.has(kind):
			return table[kind]
	return {}


static func sound(kind: String, context := {}) -> String:
	return heard(row(kind), context)


static func heard(entry: Dictionary, context := {}) -> String:
	var next := resolve(String(entry.get("sound_next", "")), context)
	if next != "" and SfxBank.has_recipe(next):
		return next
	return resolve(String(entry.get("sound", "")), context)


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
		"motif_accumulate", "motif_line", "motif_stinger":
			return SfxBank.motif_cue_id(id, motif) if motif != "" else id
	return id


static func _baked(id: String) -> String:
	return id if SfxBank.has_recipe(id) else ""


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
