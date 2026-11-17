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
	var started := Time.get_ticks_usec()
	var spoke: bool = audio.speak("shop_left", line, 0)
	var asked_ms := (Time.get_ticks_usec() - started) / 1000.0
	_t.check("BA-4 a babble line is asked for without rendering it on the asking frame",
		spoke and not audio._babble_job.is_empty() and audio.cue_log.size() == cues and asked_ms < 10.0,
		"spoke %s, job %s, cues %d -> %d, the ask took %.1f ms" % [spoke, not audio._babble_job.is_empty(), cues, audio.cue_log.size(), asked_ms])
	var waited := 0
	while not WorkerThreadPool.is_task_completed(audio._babble_job.task) and waited < 5000:
		OS.delay_msec(5)
		waited += 5
	audio._tend_babble()
	var said: Array = audio.cue_log.back() if audio.cue_log.size() > cues else []
	_t.check("BA-4 it sounds once its worker is done, and is kept", said.size() >= 3 and said[0] == "shop_left" and said[1] == "babble" and said[2] == "now"
		and audio._babble_job.is_empty() and audio._babble.size() == 1, "cue %s, cached %d" % [said, audio._babble.size()])
	cues = audio.cue_log.size()
	audio.speak("shop_left", line, 0)
	_t.check("BA-4 a kept line sounds on the frame it is asked for", audio.cue_log.size() == cues + 1 and audio._babble_job.is_empty(),
		"cues %d -> %d" % [cues, audio.cue_log.size()])
	root.remove_child(_game)
	_t.check("BA-3 leaving the tree lets go of them", Audio._opening_task == -1 and Audio._rest_task == -1,
		"opening %d, rest %d" % [Audio._opening_task, Audio._rest_task])
	_game.free()
	_game = null
	quit(_t.verdict())
	return true
