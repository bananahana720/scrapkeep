extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")

# The audio director through the real game, on the dummy audio driver: player actions
# sound at once, announcements wait for the beat, a flow burst becomes one phrase,
# rapid pickups climb the pentatonic ladder, a held trigger is voice-limited, pressure
# reaches the band, and death drops the band to the keys. Cue decisions and the
# engine's state are checked, not speakers.

var _game
var _audio
var _failures := 0
var _step := 0
var _wait_until := 0
var _player: AudioStreamPlayer


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _step < 4 and (_game == null or _game.flow == null):
		return false
	if Time.get_ticks_msec() < _wait_until:
		return false
	match _step:
		0:
			_audio = _game.presentation.audio
			_audio.bake_now()
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_next(50)
		1:
			var run := _cues("run_started")
			var stage := _cues("stage_entered")
			var engine: MusicEngine = _audio.engine
			var on_beat: bool = run.size() == 1 and run[0][2] == "beat" and int(run[0][3]) % Harmony.BEAT == 0
			_check("run phrase", on_beat and stage.is_empty(), "run start is one stinger on beat %d; stage 1's hit folds into it" % (int(run[0][3]) / Harmony.BEAT if run.size() > 0 else -1))
			_audio.cue_log.clear()
			_game.events.jumped.emit(false)
			_audio._last_start.erase("hop")
			_game.events.jumped.emit(true)
			var jumps := _cues("jumped")
			_check("actions now", jumps.size() == 2 and jumps[0][2] == "now" and jumps[1][2] == "now" and jumps[1][4] > jumps[0][4], "a jump sounds at once; the air jump sings a fifth higher (pitch %.2f)" % (jumps[1][4] if jumps.size() > 1 else 0.0))
			for i in 4:
				_game.events.scrap_collected.emit(1, Vector3.ZERO, i + 1)
				_audio._last_start.erase("scrap_tick")
			var pitches: Array = _cues("scrap_collected").map(func(c: Array): return c[4])
			var climbing := pitches.size() == 4
			for i in range(1, pitches.size()):
				climbing = climbing and pitches[i] > pitches[i - 1]
			_check("combo climbs", climbing, "four quick pickups climb the pentatonic ladder: %s" % [pitches.map(func(p: float): return snappedf(p, 0.01))])
			for i in 10:
				_game.events.shot_fired.emit("arc_caster", Vector3.ZERO, Vector3.FORWARD)
			var shots := _cues("shot_fired")
			var played := shots.filter(func(c: Array): return c[2] == "now").size()
			_check("voice limit", played == 1 and shots.size() == 10, "ten shots in one frame play %d; the rest are gated so fire never turns to mush" % played)
			_game.events.event_announced.emit("flood", 5.0)
			var klaxon := _cues("event_announced")
			_check("klaxon on beat", klaxon.size() == 1 and klaxon[0][2] == "beat" and int(klaxon[0][3]) % Harmony.BEAT == 0 and int(klaxon[0][3]) >= engine.clock, "the klaxon waits for the next beat (sample %d, play head %d)" % [int(klaxon[0][3]) if klaxon.size() > 0 else -1, engine.clock])
			_game.events.pressure_changed.emit(0.9)
			_check("pressure", is_equal_approx(engine.pressure, 0.9), "pressure_changed reaches the band (%.2f), applied on the next bar" % engine.pressure)
			_audio.cue_log.clear()
			# A stage clear and the next stage in one frame: jingle, then the stage hits.
			_game.events.stage_cleared.emit(1)
			_game.events.stage_entered.emit(2, false)
			_next(50)
		2:
			var clear := _cues("stage_cleared")
			var stage := _cues("stage_entered")
			var ok: bool = clear.size() == 1 and stage.size() == 1 and int(stage[0][3]) == int(clear[0][3]) + 8 * Harmony.BEAT
			_check("clear phrase", ok, "the clear jingle, then stage 2's hits exactly two bars later, when the cadence resolves")
			_game.events.player_died.emit()
			_next(50)
		3:
			var died := _cues("player_died")
			var engine: MusicEngine = _audio.engine
			var dead_mode := false
			for frames in 20:
				engine.render(Harmony.BEAT / 4)
				dead_mode = dead_mode or engine.mode == MusicEngine.DEAD
			_check("death", died.size() == 1 and died[0][2] == "now" and dead_mode, "the death cue plays at once and the band drops to the keys on the next beat")
			_check("band clock", engine.clock > 0, "the band ran %d samples on the %s driver (live output %s)" % [engine.clock, AudioServer.get_driver_name(), _audio.live_output])
			# The output path the game uses on a real device: render into a generator.
			var generator := AudioStreamGenerator.new()
			generator.mix_rate = Harmony.RATE
			generator.buffer_length = 0.1
			_player = AudioStreamPlayer.new()
			_player.stream = generator
			root.add_child(_player)
			_player.play()
			var playback := _player.get_stream_playback() as AudioStreamGeneratorPlayback
			var room := playback.get_frames_available()
			engine.render(mini(room, 2048))
			var pushed := playback.can_push_buffer(engine.out_music.size()) and playback.push_buffer(engine.out_music)
			_check("generator push", pushed and playback.get_frames_available() == room - engine.out_music.size(), "%d stereo frames pushed into a %d-frame generator" % [engine.out_music.size(), room])
			_player.stop()
			_player.queue_free()
			_game.free()
			_next(300)
		4:
			# Quit after the audio server has released the stopped playbacks.
			print("presentation_audio_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _cues(kind: String) -> Array:
	return _audio.cue_log.filter(func(c: Array): return c[0] == kind)


func _next(wait_ms: int) -> void:
	_step += 1
	_wait_until = Time.get_ticks_msec() + wait_ms


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
