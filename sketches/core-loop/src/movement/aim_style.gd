extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Augments := preload("res://src/movement/augments.gd")

# Each grapple aim state has its own shape as well as its own colour, so it reads for anyone who
# cannot separate the colours. Every colour is a LINE_ROWS row's (the row names the harpoon
# state the aim stands for), so the reticle and the line in the world cannot drift apart. A
# surface past the line's reach is its own style: a hollow slate ring, not yet.
const OUT_OF_RANGE := -1
const STYLES := {
	Augments.AIM_NONE: {"row": "searching", "shape": "cross", "word": ""},
	Augments.AIM_REACH: {"row": "locked", "shape": "ring", "word": "in reach"},
	Augments.AIM_ASSIST: {"row": "locked", "shape": "diamond", "word": "magnet assist"},
	Augments.AIM_BODY: {"row": "locked", "shape": "brackets", "word": ""},
}
const FAR_STYLE := {"shape": "hollow_ring", "word": "out of range"}


# The style for an aim record; `far` says the aim found nothing but a surface beyond reach.
static func of(aim: Dictionary, far := false) -> Dictionary:
	var state: int = aim.get("state", Augments.AIM_NONE)
	if far and state == Augments.AIM_NONE:
		var style := FAR_STYLE.duplicate()
		style["color"] = EventKinds.role_color("slate")
		return style
	var style: Dictionary = STYLES[state].duplicate()
	style["color"] = EventKinds.line_color(style["row"])
	return style
