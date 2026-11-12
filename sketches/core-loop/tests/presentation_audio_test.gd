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
var _wait_frames := 0
var _player: AudioStreamPlayer


class ThreatEnemy extends Node3D:
	func is_dead() -> bool:
		return false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _step < 4 and (_game == null or _game.flow == null):
		return false
	if _wait_frames > 0:
		_wait_frames -= 1
		return false
	match _step:
		0:
			_game.tuning.set_option("music", "synth")
			_audio = _game.presentation.audio
			_audio.bake_now()
			_audio.set_process(false)
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
			# A stage's resting weather is announced with no lead and then starts: no alarm.
			_game.events.event_announced.emit("dawn_still", 0.0, Vector3.INF)
			_game.events.event_started.emit("dawn_still")
			_check("calm weather is no alarm", _cues("event_announced").is_empty() and _cues("event_started").is_empty(),
				"an announcement with no lead plays no klaxon and no start cue: %s" % [_cues("event_announced") + _cues("event_started")])
			_game.events.event_announced.emit("flood", 5.0, Vector3.INF)
			var klaxon := _cues("event_announced")
			_check("klaxon on beat", klaxon.size() == 1 and klaxon[0][2] == "beat" and int(klaxon[0][3]) % Harmony.BEAT == 0 and int(klaxon[0][3]) >= engine.clock, "the klaxon waits for the next beat (sample %d, play head %d)" % [int(klaxon[0][3]) if klaxon.size() > 0 else -1, engine.clock])
			_check_pressure(engine)
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
			var engine2: MusicEngine = _audio.engine
			_audio.cue_log.clear()
			var boss := Node3D.new()
			_game.add_child(boss)
			_game.events.enemy_spawned.emit(boss, "miniboss")
			var mini_pending := engine2.pending_actions()
			if _game.events.has_signal("warden_engaged"):
				_game.events.warden_engaged.emit(2)
			var warden := _cues("warden_engaged")
			var bar_ok: bool = warden.size() == 1 and warden[0][2] == "bar" and warden[0][1] == "warden_theme_in"
			_check("boss triggers", mini_pending > 0 and bar_ok, "a miniboss spawn darkens the level on the next bar; warden_engaged starts the Warden's metric modulation on a bar with its cue")
			if _game.events.has_signal("heft_class_changed"):
				_game.events.heft_class_changed.emit(3, 2.5)
				_game.events.heft_class_changed.emit(2, 1.8)
			var heft: Array = _cues("heft_class_changed").map(func(c: Array): return c[1])
			_check("class up and down", heft == ["class_up", "class_down"], "a class gained climbs, a class lost to the crane falls: %s" % [heft])
			_game.events.player_died.emit()
			_next(50)
		3:
			var died := _cues("player_died")
			var engine: MusicEngine = _audio.engine
			var dead_mode := false
			for frames in 20:
				engine.render(Harmony.BEAT / 4)
				dead_mode = dead_mode or engine.mode == MusicEngine.DEAD
			# The cue on the death's frame, then the fall's three notes booked on the grid from the boom's beat.
			var cues_now: Array = died.filter(func(c: Array): return c[2] == "now")
			var fall: Array = died.filter(func(c: Array): return c[2] == "grid")
			_check("death", cues_now.size() == 1 and fall.size() == died.size() - 1 and fall.size() == 3 and dead_mode, "the death cue plays at once (%d), the fall is booked on the grid (%d notes) and the band drops to the keys on the next beat" % [cues_now.size(), fall.size()])
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


# 2026-10-13: KE10 merge f725a69, K-UNITS.md:366 replaces director pressure with live
# proximity/facing threat; the merge commits that snapshot on phrases, not the next bar.
func _check_pressure(engine: MusicEngine) -> void:
	var enemy := ThreatEnemy.new()
	_game.add_child(enemy)
	enemy.add_to_group("enemy")
	enemy.global_position = _game.player.ball_position() + _game.ctx.aim_forward() * _audio.parameter_threat_range * 0.1
	var before := engine.applied_pressure
	var sampled_before := engine.pressure
	_game.events.pressure_changed.emit(0.2)
	_check("director pressure stays a cue", _cues("pressure_changed").size() == 1 and engine.pressure == sampled_before,
		"the director fact is recorded without replacing the live threat feed")
	var skip := engine.bot_skip_samples
	engine.bot_skip_samples = true
	var phrase := engine.bar_len() * Harmony.PHRASE_BARS
	var origin := engine.grid_origin + ceili(float(engine.bar_origin - engine.grid_origin) / engine.step_len) * engine.step_len
	var boundary := origin + (floori(float(engine.clock - origin) / phrase) + 1) * phrase
	_advance(engine, boundary)
	_check("pressure sampled on transport", absf(engine.pressure - 0.9) <= 0.0001,
		"the enemy at one tenth of threat range supplies %.4f, expected 0.9000" % engine.pressure)
	_check("pressure waits for phrase", engine.applied_pressure == before,
		"no pending threat is applied through the sample before the phrase")
	engine.render(1)
	_check("pressure reaches band on phrase", absf(engine.applied_pressure - 0.9) <= 0.0001
		and absf(float(engine.parameter_committed_values.get("threat", -1.0)) - 0.9) <= 0.0001,
		"live threat %.4f commits at sample %d" % [engine.applied_pressure, boundary])
	engine.bot_skip_samples = skip
	enemy.free()


func _advance(engine: MusicEngine, at: int) -> void:
	while engine.clock < at:
		engine.render(mini(4096, at - engine.clock))


func _next(wait_ms: int) -> void:
	_step += 1
	# Render the wait in samples; only deferred tree cleanup needs idle frames.
	if _step < 4:
		_audio._flush_flow()
		_audio.engine.render(int(wait_ms * Harmony.RATE / 1000.0))
	_wait_frames = 3


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
