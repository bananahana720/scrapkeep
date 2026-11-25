extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Augments := preload("res://src/movement/augments.gd")

const STYLES := {
	Augments.AIM_NONE: {"row": "searching", "shape": "cross", "word": ""},
	Augments.AIM_REACH: {"row": "locked", "shape": "ring", "word": "in reach"},
	Augments.AIM_ASSIST: {"row": "locked", "shape": "diamond", "word": "magnet assist"},
	Augments.AIM_BODY: {"row": "locked", "shape": "brackets", "word": ""},
}
const FAR_STYLE := {"shape": "hollow_ring", "word": "out of range"}


static func of(aim: Dictionary, far := false) -> Dictionary:
	var state: int = aim.get("state", Augments.AIM_NONE)
	if far and state == Augments.AIM_NONE:
		var style := FAR_STYLE.duplicate()
		style["color"] = EventKinds.role_color("slate")
		return style
	var style: Dictionary = STYLES[state].duplicate()
	style["color"] = EventKinds.line_color(style["row"])
	return style
