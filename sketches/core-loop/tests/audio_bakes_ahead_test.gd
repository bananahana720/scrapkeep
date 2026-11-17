extends SceneTree

const Game := preload("res://src/game.gd")
const Audio := preload("res://src/presentation/audio.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const T := preload("res://tests/support/t.gd")

# A drawn game bakes its band and warms its stingers on workers whether or not it has a sound
# device (Audio.bakes_ahead). On the dummy driver of a drawn game, the silent self-play frame
# reading among them, the band once rendered each chord, riser and stinger on the main thread
# the frame its bar first asked: 25 to 45 ms frames in stage play and 40 to 120 ms in the boss
# fight on the Mac Studio. A headless game still renders on demand, so no test waits on a worker.

var _t := T.new("audio_bakes_ahead_test")
var _game


func _initialize() -> void:
	_t.check("BA-1 a device bakes ahead", Audio.bakes_ahead_on("CoreAudio", "headless"), "a sound device always bakes ahead")
	_t.check("BA-1 a drawn game with no device bakes ahead", Audio.bakes_ahead_on("Dummy", "macOS") and Audio.bakes_ahead_on("Dummy", "X11"),
		"the dummy driver of a drawn game must bake on workers, not on the frame its bar asks")
	_t.check("BA-1 a headless game renders on demand", not Audio.bakes_ahead_on("Dummy", "headless"), "a headless test must not start workers")
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	var audio = _game.audio()
	_t.check("BA-2 this headless game does not bake ahead", not audio.bakes_ahead and not audio.engine.warm_stingers,
		"bakes_ahead %s, warm_stingers %s" % [audio.bakes_ahead, audio.engine.warm_stingers])
	_t.check("BA-2 no band bake was started", Audio._opening_task == -1 and Audio._rest_task == -1,
		"opening %d, rest %d" % [Audio._opening_task, Audio._rest_task])
	# The drawn dummy-driver game: its bank ready, the band bakes start on workers.
	audio.bakes_ahead = true
	audio.sound_ready = false
	audio._on_ready()
	_t.check("BA-3 a game that bakes ahead starts the band bakes when its bank is ready", Audio._opening_task >= 0 and Audio._rest_task >= 0,
		"opening %d, rest %d" % [Audio._opening_task, Audio._rest_task])
	# Moss's bay line rendered 30 to 45 ms on the frame the ball rolled in: it renders on a worker
	# and sounds the frame it is done, so the frame that asks for it does no synth work.
	var line := "Pad's hot. Go on, before the clock notices."
	var cues: int = audio.cue_log.size()
	var spoke: bool = audio.speak("shop_left", line, 0)
	_t.check("BA-4 a babble line is asked for without rendering it on the asking frame",
		spoke and not audio._babble_job.is_empty() and audio.cue_log.size() == cues and audio._babble.is_empty(),
		"spoke %s, job %s, cues %d -> %d, cached %d" % [spoke, not audio._babble_job.is_empty(), cues, audio.cue_log.size(), audio._babble.size()])
	_settle(audio)
	var said: Array = audio.cue_log.back() if audio.cue_log.size() > cues else []
	_t.check("BA-4 it sounds once its worker is done, and is kept", said.size() >= 3 and said[0] == "shop_left" and said[1] == "babble" and said[2] == "now"
		and audio._babble_job.is_empty() and audio._babble.size() == 1, "cue %s, cached %d" % [said, audio._babble.size()])
	cues = audio.cue_log.size()
	audio.speak("shop_left", line, 0)
	_t.check("BA-4 a kept line sounds on the frame it is asked for", audio.cue_log.size() == cues + 1 and audio._babble_job.is_empty(),
		"cues %d -> %d" % [cues, audio.cue_log.size()])
	# A line still rendering when its bubble goes (the bubble ends its voice through call_end), or
	# when the stage changes, never sounds.
	for ending in ["bubble", "stage"]:
		var text := "Shelf's there. Hook's not for sale." if ending == "bubble" else "Back again. The Warden keeps your last shell."
		audio.speak("shop_entered", text, 0)
		cues = audio.cue_log.size()
		if ending == "bubble":
			audio.call_end()
		else:
			audio._on_stage_entered(2, false)
		_settle(audio)
		var babbled: Array = audio.cue_log.slice(cues).filter(func(row: Array): return row[1] == "babble" and row[2] == "now")
		_t.check("BA-5 a line whose %s went before it rendered stays silent" % ending, babbled.is_empty() and audio._babble_job.is_empty(),
			"babble cues after: %s" % [babbled])
	root.remove_child(_game)
	_t.check("BA-3 leaving the tree lets go of them", Audio._opening_task == -1 and Audio._rest_task == -1,
		"opening %d, rest %d" % [Audio._opening_task, Audio._rest_task])
	_game.free()
	_game = null
	quit(_t.verdict())
	return true


# Waits out the babble worker, then gives the audio the frame step that sounds a finished line.
func _settle(audio) -> void:
	# The worker is short (tens of ms); its own completion is the wait, polled, no clock read.
	while not audio._babble_job.is_empty() and not WorkerThreadPool.is_task_completed(audio._babble_job.task):
		pass
	audio._tend_babble()
