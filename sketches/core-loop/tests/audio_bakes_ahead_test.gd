extends SceneTree

const Game := preload("res://src/game.gd")
const Audio := preload("res://src/presentation/audio.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const T := preload("res://tests/support/t.gd")
# A wait for a worker is capped in frames, not time (sketch-lint L1). Headless frames run unpaced, so the cap is
# set far above any bake seen; the smoke runner's own timeout stops a hang first.
const WAIT_FRAMES := 600000

# A drawn game bakes its band and warms its stingers on workers whether or not it has a sound
# device (Audio.bakes_ahead). On the dummy driver of a drawn game, the silent self-play frame
# reading among them, the band once rendered each chord, riser and stinger on the main thread
# the frame its bar first asked: 25 to 45 ms frames in stage play and 40 to 120 ms in the boss
# fight on the Mac Studio. A headless game still renders on demand, so no test waits on a worker.

var _t := T.new("audio_bakes_ahead_test")
var _game


# A drawn game as setup() would find it, for the one place a headless test cannot be one.
class DrawnAudio extends Audio:
	func _drawn_with_workers() -> bool:
		return true


func _initialize() -> void:
	_t.check("BA-1 a device bakes ahead", Audio.bakes_ahead_on("CoreAudio", "headless"), "a sound device always bakes ahead")
	_t.check("BA-1 a drawn game with no device bakes ahead", Audio.bakes_ahead_on("Dummy", "macOS") and Audio.bakes_ahead_on("Dummy", "X11"),
		"the dummy driver of a drawn game must bake on workers, not on the frame its bar asks")
	_t.check("BA-1 a headless game renders on demand", not Audio.bakes_ahead_on("Dummy", "headless"), "a headless test must not start workers")
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await process_frame
	var audio = _game.audio()
	_t.check("BA-2 this headless game does not bake ahead", not audio.bakes_ahead and not audio.engine.warm_stingers,
		"bakes_ahead %s, warm_stingers %s" % [audio.bakes_ahead, audio.engine.warm_stingers])
	_t.check("BA-2 no band bake was started", not Audio.band_bakes()["held"], "bakes %s" % [Audio.band_bakes()])
	# setup() hands the stinger warming whatever it found for baking ahead: a drawn game warms them.
	var drawn := DrawnAudio.new()
	drawn.setup(_game.ctx)
	var drawn_ok: bool = drawn.bakes_ahead and drawn.engine.warm_stingers
	root.add_child(drawn)
	root.remove_child(drawn)
	_t.check("BA-2 setup warms the stingers of a game that bakes ahead", drawn_ok, "bakes_ahead %s, warm_stingers %s" % [drawn.bakes_ahead, drawn.engine.warm_stingers])
	drawn.free()
	# The drawn dummy-driver game: its bank ready, the band bakes start on workers.
	audio.bakes_ahead = true
	audio.sound_ready = false
	for i in WAIT_FRAMES:
		if audio.sound_ready:
			break
		await process_frame
	var bank_late: bool = not audio.sound_ready
	_t.check("BA-3 a game that bakes ahead starts the band bakes when its bank is ready", audio.sound_ready and Audio.band_bakes()["held"],
		"%sready %s, bakes %s" % ["TIMED OUT: " if bank_late else "", audio.sound_ready, Audio.band_bakes()])
	# Moss's bay line rendered 30 to 45 ms on the frame the ball rolled in: it renders on a worker
	# and sounds the frame it is done, so the frame that asks for it does no synth work.
	var line := "Pad's hot. Go on, before the clock notices."
	var cues: int = audio.cue_log.size()
	var spoke: bool = audio.speak("shop_left", line, 0)
	_t.check("BA-4 a babble line is asked for without rendering it on the asking frame",
		spoke and audio.babble_state(line, 0) == "rendering" and audio.cue_log.size() == cues,
		"spoke %s, state %s, cues %d -> %d" % [spoke, audio.babble_state(line, 0), cues, audio.cue_log.size()])
	var late: bool = await _settle(audio, line, 0)
	var said: Array = audio.cue_log.back() if audio.cue_log.size() > cues else []
	_t.check("BA-4 it sounds once its worker is done, and is kept", said.size() >= 3 and said[0] == "shop_left" and said[1] == "babble" and said[2] == "now"
		and audio.babble_state(line, 0) == "ready", "%scue %s, state %s" % ["TIMED OUT: " if late else "", said, audio.babble_state(line, 0)])
	cues = audio.cue_log.size()
	audio.speak("shop_left", line, 0)
	_t.check("BA-4 a kept line sounds on the frame it is asked for", audio.cue_log.size() == cues + 1, "cues %d -> %d" % [cues, audio.cue_log.size()])
	# A stage change drops a line still rendering: it never sounds.
	var gone := "Back again. The Warden keeps your last shell."
	audio.speak("shop_entered", gone, 0)
	cues = audio.cue_log.size()
	_game.events.stage_entered.emit(2, false)
	late = await _settle(audio, gone, 0)
	var babbled: Array = audio.cue_log.slice(cues).filter(func(row: Array): return row[1] == "babble" and row[2] == "now")
	_t.check("BA-5 a line whose stage changed before it rendered stays silent, and is still rendered and kept",
		babbled.is_empty() and audio.babble_state(gone, 0) == "ready", "%sbabble cues after: %s, state %s" % ["TIMED OUT: " if late else "", babbled, audio.babble_state(gone, 0)])
	# A call card closing is no business of a bay line: the line plays out (call_end ends a caller only).
	var kept := "Shelf's there. Hook's not for sale."
	audio.speak("shop_entered", kept, 0)
	cues = audio.cue_log.size()
	audio.call_end()
	late = await _settle(audio, kept, 0)
	babbled = audio.cue_log.slice(cues).filter(func(row: Array): return row[1] == "babble" and row[2] == "now")
	_t.check("BA-6 a call card closing does not silence a bay line still rendering", babbled.size() == 1, "%sbabble cues after: %s" % ["TIMED OUT: " if late else "", babbled])
	root.remove_child(_game)
	_t.check("BA-3 leaving the tree lets go of them", not Audio.band_bakes()["held"], "bakes %s" % [Audio.band_bakes()])
	_game.free()
	_game = null
	quit(_t.verdict())


# Frames pass until the line is rendered and kept, which is the frame it sounds; WAIT_FRAMES is the cap.
# True when the cap was hit.
func _settle(audio, text: String, beat: int) -> bool:
	for i in WAIT_FRAMES:
		if audio.babble_state(text, beat) != "rendering":
			return false
		await process_frame
	return audio.babble_state(text, beat) == "rendering"
