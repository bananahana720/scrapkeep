extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const Augments := preload("res://src/movement/augments.gd")

# Each grapple aim state has its own shape as well as its own colour, so it reads for
# anyone who cannot separate the colours. HUD and world markers share this table.
# Bone marks availability without claiming a class; mint marks magnetic assistance.
const STYLES := {
	Augments.AIM_NONE: {"color": Color(0.85, 0.88, 0.92, 0.55), "shape": "cross", "word": ""},
	Augments.AIM_REACH: {"color": Palette.SAND, "shape": "ring", "word": "in reach"},
	Augments.AIM_ASSIST: {"color": Palette.ARC, "shape": "diamond", "word": "magnet assist"},
}


static func of(aim: Dictionary) -> Dictionary:
	return STYLES[aim.get("state", Augments.AIM_NONE)]
