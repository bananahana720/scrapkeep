extends SceneTree

# VX3-2: the Waking's CoreKey keeps a shadow on every preset. Low trims it to a tighter
# cone instead of switching it off (P-R20), so the core still drops a shadow on low.

const Probe := preload("res://tests/support/lighting_harness.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Dress := preload("res://src/presentation/arena_waking_dress.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("waking_core_key_shadow_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = await Probe.boot(self)
	Preset.apply("low")
	Harness.enter_world(game, 2)
	var mod = Harness.module(game, 2)
	var dress = mod._arena_dress
	if _t.check("Waking dress builds on low", dress != null):
		var key := dress.get_node("CoreKey") as SpotLight3D
		_t.check("CoreKey casts a shadow when the pit is entered on low", key.shadow_enabled and key.visible and key.light_energy > 0.0)
		_t.near("low trims the CoreKey cone", key.spot_angle, Dress.LIGHTS.core_key_low.angle)
		_t.check("the trimmed cone still reaches the core", key.spot_range > key.global_position.distance_to(mod.warden.family_point_at()))
		Preset.apply("high")
		_t.check("high keeps the CoreKey shadow on the full cone", key.shadow_enabled and is_equal_approx(key.spot_angle, Dress.LIGHTS.core_key.angle))
		Preset.apply("low")
		_t.check("switching to low mid-fight keeps the CoreKey shadow", key.shadow_enabled)
	mod.exit_arena()
	Preset.apply("high")
	game.free()
	quit(_t.verdict())
