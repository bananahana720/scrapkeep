extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Music := preload("res://src/presentation/music_engine.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const T := preload("res://tests/support/t.gd")

# The flume Warden's break strips the band's melodic layers until the next stage entry
# (music_engine parameters_warden_broken). Brindle's arena is entered from the flume and
# never enters a stage, so before this test his whole fight, retries included, played with
# pad, arp, choir, lead, echo and counter muted (Codex review of main d561e6eb, top ten #1).
# Arena entry and arena retry now reset the release like a stage entry does.
#
# Driven through the real seams: flow.enter_stage(2), flow._unseal (beacon_unsealed),
# flow.enter_boss, then Brindle's phases 2 and 3 and an arena retry, rendering the engine
# two phrases after each step so the phrase commit has run.

var t := T.new("music_brindle_release_test")


func _initialize() -> void:
	_run.call_deferred()


func _render_phrases(engine, phrases: int) -> void:
	var deadline: int = engine.clock + engine.step_len * Harmony.STEPS_PER_BAR * Harmony.PHRASE_BARS * phrases
	while engine.clock <= deadline:
		engine.render(mini(4096, deadline + 1 - engine.clock))


func _melodic(engine) -> Dictionary:
	var out := {}
	for layer in Music.MELODIC:
		out[layer] = engine.layer_target(layer)
	return out


func _audible(engine, label: String) -> void:
	var targets := _melodic(engine)
	t.check("%s: release is off" % label, not engine.parameter_committed_released, "track=%s section=%s" % [engine.track, engine.section])
	t.check("%s: melodic layers audible" % label, targets.values().any(func(v): return v > 0.0) and engine.layer_target(Music.LEAD) > 0.0,
		"track=%s section=%s mode=%d targets=%s" % [engine.track, engine.section, engine.mode, targets])
	if _ace != null:
		t.check("%s: ACE stems follow the release" % label, not _ace.parameter_released)


var _ace = null


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	var engine = audio.engine
	game.ctx.calm = true
	Harness.start_run(game)
	audio._flush_flow()
	game.flow.enter_stage(2, Vector3.ZERO, false)
	audio._flush_flow()
	# Full plating, so the armour feed (mass over its run peak) never strips the band itself.
	game.run.mass = 100.0
	_render_phrases(engine, 1)
	t.check("parameter feed is live", engine.parameter_source.is_valid())

	game.flow._unseal()
	audio._flush_flow()
	_render_phrases(engine, 1)
	t.check("flume Warden break strips the melody (fixture control)", engine.parameter_committed_released and Music.MELODIC.all(func(l): return engine.layer_target(l) == 0.0),
		"targets=%s" % [_melodic(engine)])

	game.flow.enter_boss(Vector3.ZERO)
	audio._flush_flow()
	game.boss.set_physics_process(false)
	t.check("boss entry clears the release", not engine._parameter_released)
	_render_phrases(engine, 2)
	_ace = audio.ace if audio.ace_playing() else null
	t.check("arena plays Brindle's band", engine.track in Music.BOSS_TRACKS, "track=%s" % engine.track)
	_audible(engine, "phase 1")
	for phase in [2, 3]:
		game.boss.jump_to_phase(phase)
		audio._flush_flow()
		_render_phrases(engine, 2)
		_audible(engine, "phase %d" % phase)

	# A Warden-style release inside the arena (any later caller) is cleared by an arena retry too.
	engine.parameters_warden_broken()
	game.flow._retry_arena()
	audio._flush_flow()
	t.check("arena retry clears the release", not engine._parameter_released)
	_render_phrases(engine, 2)
	_audible(engine, "after retry")

	game.queue_free()
	await process_frame
	quit(t.verdict())
