extends RefCounted

const Augments := preload("res://src/movement/augments.gd")

# Each grapple aim state has its own shape as well as its own colour, so it reads for
# anyone who cannot separate the colours. The HUD reticle and the world marker both
# draw from this table. Orange matches the rope, so "in reach" means "a rope goes here";
# cyan is the electromagnet pulling the hook onto something you nearly aimed at.
const STYLES := {
	Augments.AIM_NONE: {"color": Color(0.85, 0.88, 0.92, 0.55), "shape": "cross", "word": ""},
	Augments.AIM_REACH: {"color": Color(1.0, 0.72, 0.30), "shape": "ring", "word": "in reach"},
	Augments.AIM_ASSIST: {"color": Color(0.35, 0.90, 1.0), "shape": "diamond", "word": "magnet assist"},
}


static func of(aim: Dictionary) -> Dictionary:
	return STYLES[aim.get("state", Augments.AIM_NONE)]
