extends SceneTree

const Probe := preload("res://tests/support/lighting_harness.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("hunt_hl_preset_lighting_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = await Probe.boot(self)
	if not _t.check("HL03 game booted", game.flow != null):
		game.free()
		quit(_t.verdict())
		return
	game.set_quality(0)
	var before := Probe.lighting(game)
	game.flow.enter_stage(5, Vector3.ZERO, false)
	_cycle(game, "Highdraft")
	# 2026-10-13: KE7 merge 4cb6571, PARK.md:430,629 enters stage 6 at dusk.
	# The Mind launches from the last Highdraft stage; retain that stage's complete lighting.
	game.flow.enter_stage(game.ctx.stages.last_of(3), Vector3.ZERO, false)
	var dusk := Probe.lighting(game)
	_t.eq("HL03 Mind departure stage is dusk", dusk.ambient, Color("5d6b86"))
	_t.eq("HL03 dusk ambient energy", dusk.energy, 0.16)
	_t.eq("HL03 dusk key", dusk.sun_color, Color("e06f4a"))
	_t.eq("HL03 dusk sun direction", dusk.sun_rotation, Vector3(-6.0, 60.0, 0.0))
	_cycle(game, "Highdraft dusk")
	game.flow.enter_boss(Vector3.ZERO)
	var mod = Harness.module(game, 3)
	if _t.check("HL03 real Mind dressing attached", mod._arena_dress != null):
		_cycle(game, "Mind")
		mod.exit_arena()
		Probe.check_lighting(_t, "HL03 Mind exit restores current Highdraft dusk lighting", game, dusk)
	game.flow.new_run()
	Probe.check_lighting(_t, "HL03 new run after preset changes restores original lighting", game, before)
	game.free()
	quit(_t.verdict())


func _cycle(game, label: String) -> void:
	var lighting := Probe.lighting(game)
	for preset in ["low", "high", "target", "low", "high"]:
		if preset == "target":
			Preset.apply(preset)
		else:
			game.set_quality(1 if preset == "low" else 0)
		Probe.check_lighting(_t, "HL03 %s lighting survives %s preset" % [label, preset], game, lighting)
		_t.eq("HL03 %s %s applies SSAO quality" % [label, preset], game.ctx.terrain.environment.ssao_enabled, preset != "low")
		_t.eq("HL03 %s %s applies MSAA quality" % [label, preset], root.msaa_3d, Viewport.MSAA_2X if preset == "low" else Viewport.MSAA_4X)
