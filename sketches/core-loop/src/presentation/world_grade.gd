extends RefCounted

const WorldLook := preload("res://src/presentation/world_look.gd")

const BASE := {
	"tonemap_mode": Environment.TONE_MAPPER_AGX,
	"tonemap_agx_white": 16.29,
	"tonemap_agx_contrast": 1.25,
	"adjustment_enabled": true,
	"glow_intensity": 0.18,
	"glow_hdr_threshold": 1.5,
}


static func menu(env: Environment, exposure: float) -> void:
	for key in BASE:
		env.set(key, BASE[key])
	env.tonemap_exposure = exposure
	env.adjustment_saturation = WorldLook.ROWS[1].saturation
