extends SceneTree

const Game := preload("res://src/game.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")
const T := preload("res://tests/support/t.gd")

# The world slows for a close-up and comes back (game.slow_motion, ruling cf), and the sound
# marks both ends (audio.gd slowed): a falling sweep as it slows, the music and the ambience
# held under it, a rising sweep as the speed returns. The real Game on the park table; the
# sounds are read from the director's cue log and the mix from its bus levels, not from
# speakers.

var t := T.new("slow_motion_sound_test")
var _game
var _audio


func _initialize() -> void:
	_run.call_deferred()


func _heard() -> Array:
	return _audio.cue_log.filter(func(entry): return entry[0] == _audio.SLOW_KIND).map(func(entry): return entry[1])


func _settle() -> float:
	for i in 40:
		_audio._tend_mix(0.25)
	return float(_audio.mix_db["Music"]) - MixRows.state_db(_audio.mix_state(), "Music")


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.player.set_frozen(true)
	_audio = _game.presentation.audio
	_audio.bake_now()
	_audio.set_process(false)
	_audio._flush_flow()
	_audio.cue_log.clear()
	t.near("at full speed the music sits at its level", _settle(), 0.0, 0.01)

	_game.slow_motion(0.3)
	t.eq("slowing sounds the fall", _heard(), ["slow_dip"])
	t.near("the music is held under the slow motion", _settle(), float(MixRows.FOCUS["Music"]), 0.01)
	_game.slow_motion(0.3)
	_game.slow_motion(0.5)
	t.eq("a slow motion already on sounds nothing more", _heard(), ["slow_dip"])
	_game.slow_motion(1.0)
	t.eq("the return sounds the rise", _heard(), ["slow_dip", "slow_rise"])
	t.near("the music comes back", _settle(), 0.0, 0.01)
	_game.slow_motion(1.0)
	t.eq("full speed again sounds nothing", _heard(), ["slow_dip", "slow_rise"])

	# A pause lifts the slow motion and gives it back (flourish_cues.gd): the lift is silent,
	# and the fall sounds again as play resumes inside the window.
	_audio.cue_log.clear()
	_game.slow_motion(0.3)
	paused = true
	_game.slow_motion(1.0)
	t.eq("a pause lifts it without a sound", _heard(), ["slow_dip"])
	paused = false
	_game.slow_motion(0.3)
	_game.slow_motion(1.0)
	t.eq("resuming falls again, and the end rises", _heard(), ["slow_dip", "slow_dip", "slow_rise"])
	t.near("the game's speed is whole again", Engine.time_scale, 1.0)

	_game.queue_free()
	await process_frame
	quit(t.verdict())
