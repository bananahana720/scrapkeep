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
	Harness.enter_world(game, 3)
	var mod = Harness.module(game, 3)
	if _t.check("HL03 real Mind dressing attached", mod._arena_dress != null):
		_cycle(game, "Mind")
		mod.exit_arena()
		_t.eq("HL03 Mind exit restores Highdraft ambient", Probe.lighting(game).ambient, Color("ece7da"))
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
