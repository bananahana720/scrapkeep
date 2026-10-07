extends SceneTree

const Probe := preload("res://tests/support/lighting_harness.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("hunt_hl_world_lighting_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = await Probe.boot(self)
	if not _t.check("HL02 game booted", game.flow != null):
		game.free()
		quit(_t.verdict())
		return
	var before := Probe.lighting(game)
	Harness.enter_world(game, 2)
	_t.eq("HL02 real Waking applies pit ambient", Probe.lighting(game).ambient, Color("9ba8a3"))
	var fight := await Harness.fight(game, Harness.module(game, 2), 5400)
	if _t.check("HL02 real Waking fight reaches victory", fight.defeated and fight.victory_state == "victory"):
		game.flow.physics_step(game.flow.VICTORY_SECONDS + 0.1)
		_t.eq("HL02 victory advances to Highdraft stage 5", game.run.stage, 5)
		_t.eq("HL02 Waking teardown preserves Highdraft ambient", Probe.lighting(game).ambient, Color("b4c0c9"))
		_t.eq("HL02 Waking teardown restores sky background for Highdraft", Probe.lighting(game).background, before.background)
		game.flow.new_run()
		Probe.check_lighting(_t, "HL02 new run restores original world lighting", game, before)
	game.free()
	quit(_t.verdict())
