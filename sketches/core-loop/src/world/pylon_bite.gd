extends RefCounted


const FACE := 0.866

const Palette := preload("res://src/core/palette.gd")


static func tint() -> Color:
	return Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.25)


static func weight(n_y: float) -> float:
	if n_y >= FACE:
		return 0.0
	return clampf((FACE - n_y) * 6.0, 0.0, 0.8)


const BERM_ROWS := {
	"park_pit": ["dump_berm_east", "dump_berm_west", "rim_road_berm", "haul_ramp_berm", "wash_berm", "bench3_west_berm"],
}
const BERM_PAD_M := 2.0
