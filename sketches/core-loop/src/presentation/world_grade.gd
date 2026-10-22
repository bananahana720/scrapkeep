extends RefCounted

const WorldLook := preload("res://src/presentation/world_look.gd")

# The game's base post grade, one source for every surface that shows the run's colours. These
# are the fixed fields graphics_preset.gd writes on the run's environment (world_grade_test
# WG-5 holds the two in step); the run adds its look's exposure, saturation and fog on top.
const BASE := {
	"tonemap_mode": Environment.TONE_MAPPER_AGX,
	"tonemap_agx_white": 16.29,
	"tonemap_agx_contrast": 1.25,
	"adjustment_enabled": true,
	"glow_intensity": 0.18,
	"glow_hdr_threshold": 1.5,
}


# A menu stage (class preview, customize bench) takes the run's grade so a colour picked there
# reads the same in the run. Glow stays as the caller had it: the menus do not turn it on.
static func menu(env: Environment, exposure: float) -> void:
	for key in BASE:
		env.set(key, BASE[key])
	env.tonemap_exposure = exposure
	env.adjustment_saturation = WorldLook.ROWS[1].saturation
