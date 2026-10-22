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


# A LOOK rule for the park ground, not the pylon's: the six pit berms below stay bitable (a ball at their
# foot bites a flank: 101 of 108 flank and foot samples in the probe posted on #241 6345448625) but their ground colour is not tinted, by design, so
# the tint under-reports them (coordinator 6342820238 item 3, 6345347272 item 4, NEEDS 6350588099). The
# rows are named here and nowhere else, keyed by map id; any other map has no mask. A row's footprint
# is its own at/size/yaw frame (park_stamps.gd) padded by BERM_PAD_M on every side so the flank feet are covered.
const BERM_ROWS := {
	"park_pit": ["dump_berm_east", "dump_berm_west", "rim_road_berm", "haul_ramp_berm", "wash_berm", "bench3_west_berm"],
}
const BERM_PAD_M := 2.0
