extends RefCounted


const WorldLook := preload("res://src/presentation/world_look.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")

var current := {}
var _env: Environment
var _saved := {}


func _init(env: Environment) -> void:
	_env = env


func hook(action: String, row: Dictionary, _ctx: Dictionary) -> void:
	if _env == null:
		return
	match action:
		"land":
			_saved = _fog_state(_env)
			apply(_env, row)
			current = look(row)
			WorldFx.lay_overlay(String(row.sky))
		"end":
			if not _saved.is_empty():
				_restore_fog(_env, _saved)
			_saved = {}
			current = {}
			WorldFx.lay_overlay("")


static func look(row: Dictionary) -> Dictionary:
	var fog: Dictionary = row.fog
	var sky: Dictionary = WorldLook.WEATHER_SKY.get(row.sky, {})
	return {
		"fog_density": float(fog.density),
		"fog_color": Color(String(fog.color)),
		"sky": row.sky,
		"sky_tint": sky.get("tint", Color.WHITE),
		"cloud": float(sky.get("cloud", 0.0)),
		"sound": row.sound,
		"music_layer": row.music_layer,
	}


static func apply(env: Environment, row: Dictionary) -> void:
	var values := look(row)
	env.fog_enabled = true
	env.fog_density = values.fog_density
	env.fog_light_color = values.fog_color


static func _fog_state(env: Environment) -> Dictionary:
	return {"enabled": env.fog_enabled, "density": env.fog_density, "color": env.fog_light_color}


static func _restore_fog(env: Environment, saved: Dictionary) -> void:
	env.fog_enabled = saved.enabled
	env.fog_density = saved.density
	env.fog_light_color = saved.color
