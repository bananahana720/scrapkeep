extends SceneTree

const Probe := preload("res://tests/support/lighting_harness.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("hunt_hl_world_lighting_test")


func _initialize() -> void:
	# The lighting is pinned with a smash-per-frame fight, not the fight's length: the PHASE_MIN_SECONDS hold
	# (waking.gd; tests/boss_phase_hold_test.gd) is multiplied out so the Waking falls inside the frame cap.
	ChallengeDials.set_overrides({"waking.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0]})
	call_deferred("_run")


func _run() -> void:
	var game = await Probe.boot(self)
	if not _t.check("HL02 game booted", game.flow != null):
		game.free()
		quit(_t.verdict())
		return
	var before := Probe.lighting(game)
	Harness.enter_world(game, 2)
	_t.eq("HL02 real Waking applies pit ambient", Probe.lighting(game).ambient, WorldLook.ARENAS["waking"]["ambient"])
	var fight := await Harness.fight(game, Harness.module(game, 2), 5400)
	if _t.check("HL02 real Waking fight reaches victory", fight.defeated and fight.victory_state == "victory"):
		game.flow.physics_step(game.flow.VICTORY_SECONDS + 0.1)
		_t.eq("HL02 victory advances to Highdraft stage 5", game.run.stage, 5)
		# 2026-10-13: KE7 merge 4cb6571, PARK.md:429,629 enters stage 5 at golden hour.
		var after := Probe.lighting(game)
		_t.eq("HL02 Waking teardown preserves Highdraft golden ambient", after.ambient, Color("e0b58a"))
		_t.eq("HL02 Waking teardown preserves golden ambient energy", after.energy, 0.25)
		_t.eq("HL02 Waking teardown preserves golden key", after.sun_color, Color("ffa35c"))
		_t.eq("HL02 Waking teardown preserves golden sun direction", after.sun_rotation, Vector3(-16.0, 20.0, 0.0))
		_t.eq("HL02 Waking teardown restores sky background for Highdraft", Probe.lighting(game).background, before.background)
		game.flow.new_run()
		Probe.check_lighting(_t, "HL02 new run restores original world lighting", game, before)
	game.free()
	quit(_t.verdict())
