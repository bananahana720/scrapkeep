extends RefCounted

# Which ground a pylon can bite, and how strongly it reads as concrete. The old maps' ground mesh
# (terrain.gd) and the park ground's colour map (park_terrain.gd) both tint by this rule, so they
# share it here: park_terrain.gd cannot preload terrain.gd, which preloads it.

# A face steeper than this (the normal's y below it) takes the pylon tint: the ball's
# pylon bites a face that leans less than 60 degrees off vertical (augments.gd).
const FACE := 0.866

const Palette := preload("res://src/core/palette.gd")


# The colour a bitable face is tinted toward.
static func tint() -> Color:
	return Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.25)


# How far a vertex whose normal has this y moves toward tint(): 0 on a face a pylon cannot bite.
static func weight(n_y: float) -> float:
	if n_y >= FACE:
		return 0.0
	return clampf((FACE - n_y) * 6.0, 0.0, 0.8)
