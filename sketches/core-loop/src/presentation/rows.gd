extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")

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
	return FALLBACK.get(kind, {})


static func sound(kind: String) -> String:
	return String(row(kind).get("sound", ""))


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
