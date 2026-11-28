extends SceneTree

# 2026-10-12 (PC-KEST round 4): every Kest cue uses live-key admission and row gain.

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")
const AceSequencer := preload("res://src/presentation/ace_sequencer.gd")
const T := preload("res://tests/support/t.gd")

# The set piece in the music (design-v3/SKILL-BAR.md section 4, "Music" and "Duration"),
# wave P-B unit B3, 2026-10-10. The flight rounds to whole beats inside 1.6 to 3.2 s at every
# tempo, 2.4 s with the music off; a full meter adds one intensity layer at the next bar line
# (a layer added, never a swap); the wind-up opens the launch build; the landing drops within
# one beat of touchdown, on the grid; the lift releases with the drop or a cancel; the set
# piece reads its beat from the band. Engine state on the dummy driver; the ACE band is not
# loaded here, so its pressure step is read from the value audio would send.

var _t := T.new("presentation_ultimate_music_test")
var _game
var _audio


func _initialize() -> void:
	MusicPrebake.prepare()
	_rounding()
	_lift_layer()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _rounding() -> void:
	var Ultimate = load("res://src/combat/ultimate.gd")
	var bad: Array = []
	for bpm in [172.0, 150.0, 129.0, 100.0]:
		var beat: float = 60.0 / bpm
		for length in [2.0, 20.0, 30.0, 45.0, 57.6, 70.0, 120.0]:
			var s: float = Ultimate.round_flight(length, beat)
			var beats: float = s / beat
			if s < 1.6 - 0.0001 or s > 3.2 + 0.0001 or absf(beats - roundf(beats)) > 0.0001:
				bad.append("%d bpm %.1f m -> %.3f s (%.2f beats)" % [bpm, length, s, beats])
	_t.check("01 every flight is whole beats inside 1.6 to 3.2 s at 172, 150, 129 and 100 BPM", bad.is_empty(), "off band %s" % [bad])
	_t.eq("02 with the music off the flight is 2.4 s", Ultimate.round_flight(30.0, 0.0), 2.4)


func _lift_layer() -> void:
	var engine := MusicEngine.new()
	engine.schedule_restart(0, MusicEngine.PLAY, 0)
	engine.set_pressure(0.3)
	engine.render(1)
	engine.render(Harmony.BAR)
	var before: float = engine._intensity
	var gains_before: Array = engine.layer_gains(before)
	engine.set_ultimate_lift(true)
	var waits: bool = not engine.ultimate_lift
	engine.render(Harmony.BAR + Harmony.STEP)
	var lifted: float = engine._intensity
	var logged: Array = engine.events_log.filter(func(e: Array): return e[0] == "ult")
	var on_bar: bool = logged.size() == 1 and posmod(int(logged[0][1]) - engine.grid_origin, engine.bar_len()) == 0
	_t.check("03 a full meter lifts one intensity step at the next bar line", waits and engine.ultimate_lift and on_bar
		and absf(lifted - (before + MusicEngine.HEFT_STEP)) < 0.0001, "intensity %.3f -> %.3f, logged %s" % [before, lifted, logged])
	var gains_after: Array = engine.layer_gains(lifted)
	var dropped := false
	for i in gains_before.size():
		if float(gains_before[i]) > 0.05 and float(gains_after[i]) < float(gains_before[i]) - 0.0001:
			dropped = true
	_t.check("04 the lift adds and never swaps: no sounding layer gets quieter", not dropped, "before %s after %s" % [gains_before, gains_after])
	engine.set_ultimate_lift(false)
	engine.render(Harmony.BAR + Harmony.STEP)
	_t.check("05 the lift releases at the next bar", not engine.ultimate_lift and absf(engine._intensity - before) < 0.0001, "intensity %.3f" % engine._intensity)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.tuning.set_option("music", "synth")
	_audio = _game.presentation.audio
	_audio.bake_now()
	_audio.set_process(false)
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for i in 3:
		await physics_frame
	_audio._flush_flow()
	_audio.engine.render(int(0.9 * Harmony.RATE))
	var engine: MusicEngine = _audio.engine
	var ult = _game.combat.get("ultimate")
	var ev = _game.events
	_t.check("06 the band plays the level", engine.mode == MusicEngine.PLAY and engine.track == "level", "mode %s track %s" % [engine.mode, engine.track])
	var beat: float = float(ult.beat_seconds.call()) if ult != null and ult.beat_seconds.is_valid() else -1.0
	_t.check("07 the set piece reads its beat from the band", absf(beat - 60.0 / engine.bpm()) < 0.0001, "beat %.4f s, band %.1f BPM" % [beat, engine.bpm()])

	# A level ACE band that ended for the flight keeps its sequencer: an off-mode stub stands
	# in for it, so the lift it holds can be read after the landing (fix round, 2026-10-11).
	var ace_stub := AceSequencer.new("")
	_audio.ace = ace_stub
	ev.ultimate_ready.emit("ult_default")
	_t.check("08a the stopped ACE band's sequencer hears the lift", ace_stub.ultimate_lift and ace_stub.mode == "off")
	_t.check("08 ultimate_ready queues the lift and sends the ACE band one pressure step", _audio.ace_pressure() > _audio.pressure_now() + 0.0001,
		"ace %.2f over %.2f" % [_audio.ace_pressure(), _audio.pressure_now()])
	engine.render(Harmony.BAR + Harmony.STEP)
	_t.check("09 the lift is on after the bar", engine.ultimate_lift)
	var cues: Array = _audio.cue_log.filter(func(c: Array): return c[0] == "ultimate_ready")
	_t.check("10 the ready cue sounds on the beat", cues.size() == 1 and String(cues[0][2]) == "beat", "cues %s" % [cues])

	ev.ultimate_started.emit("ult_default", "arc", Vector3.ZERO, Vector3(20.0, 0.0, 0.0), 2.75)
	var built: bool = engine.building()
	engine.render(Harmony.BEAT * 2 + 1111)
	_t.check("11 the wind-up opens the launch build", built and engine.build_level() > 0.0, "build %.2f" % engine.build_level())
	ev.ultimate_peak.emit("ult_default", Vector3.ZERO)
	var peak: Array = _audio.cue_log.filter(func(c: Array): return c[0] == "ultimate_peak")
	_t.check("12 the peak stinger is on the beat", peak.size() == 1 and String(peak[0][2]) == "beat", "cues %s" % [peak])
	var touchdown := engine.clock
	ev.ultimate_landed.emit("ult_default", Vector3.ZERO, 3, 180.0)
	var drop_log: Array = _audio.drop_log
	var at: int = drop_log[drop_log.size() - 1][1] if drop_log.size() > 0 else -1
	var within := at >= touchdown and at - touchdown <= engine.beat_len()
	var on_beat := at >= 0 and posmod(at - engine.grid_origin, engine.beat_len()) == 0
	engine.render(maxi(at - engine.clock, 0) + 64)
	_t.check("13 the landing drops within one beat of touchdown, on the grid", within and on_beat and engine.in_drop() and not engine.building(),
		"touchdown %d, drop %d (%.2f beats)" % [touchdown, at, float(at - touchdown) / engine.beat_len()])
	engine.render(Harmony.BAR + Harmony.STEP)
	_t.check("14 the lift and the ACE step release with the drop", not engine.ultimate_lift and absf(_audio.ace_pressure() - _audio.pressure_now()) < 0.0001)
	_t.check("14b the stopped ACE band's own lift clears with the landing", not ace_stub.ultimate_lift and absf(ace_stub.effective_pressure() - ace_stub.pressure) < 0.0001,
		"lift %s, effective %.2f over %.2f" % [ace_stub.ultimate_lift, ace_stub.effective_pressure(), ace_stub.pressure])

	ev.ultimate_ready.emit("ult_default")
	ev.ultimate_started.emit("ult_default", "hop", Vector3.ZERO, Vector3.ZERO, 1.95)
	ev.ultimate_cancelled.emit("ult_default", "recall", true)
	engine.render(Harmony.BAR + Harmony.STEP)
	_t.check("15 a recall cancels the build and keeps the lift (the meter is full again)", not engine.building() and engine.ultimate_lift)
	ev.ultimate_started.emit("ult_default", "hop", Vector3.ZERO, Vector3.ZERO, 1.95)
	ev.ultimate_cancelled.emit("ult_default", "bail", false)
	engine.render(Harmony.BAR + Harmony.STEP)
	_t.check("16 a bail cancels the build and releases the lift", not engine.building() and not engine.ultimate_lift)

	# --- A retry: the lift follows the restored meter (fix round, 2026-10-11) --------------
	# The handlers the stage_entered connection calls, ultimate's first; emitting the bus fact
	# would restart the stage.
	var stage: int = _game.ctx.run.stage
	ult.meter.locked = false
	ult.meter.reset()
	ult._on_stage_entered(stage, false)
	ult.meter.refund(ult.meter.CAP)
	ev.ultimate_ready.emit("ult_default")
	engine.render(Harmony.BAR + Harmony.STEP)
	var lift_before: bool = engine.ultimate_lift
	ult._on_stage_entered(stage, true)
	_audio._on_stage_entered(stage, true)
	await process_frame
	_t.eq("retry-to-empty director reads the restored meter before rendering", _audio._ult_lift, ult.meter.full())
	engine.render(Harmony.BAR + Harmony.STEP)
	_t.check("17 a retry to an empty entry value drops a lift the mid-stage fill raised", lift_before and not ult.meter.full() and not engine.ultimate_lift,
		"before %s, meter %.1f, lift %s" % [lift_before, ult.meter.value, engine.ultimate_lift])
	ult.meter.refund(ult.meter.CAP)
	ult._on_stage_entered(stage, false)
	ev.ultimate_cancelled.emit("ult_default", "death", false)
	engine.render(Harmony.BAR + Harmony.STEP)
	var cleared: bool = not engine.ultimate_lift
	ult._on_stage_entered(stage, true)
	_audio._on_stage_entered(stage, true)
	await process_frame
	_t.eq("retry-to-full director reads the restored meter before rendering", _audio._ult_lift, ult.meter.full())
	engine.render(Harmony.BAR + Harmony.STEP)
	_t.check("18 a retry to a full entry value brings back a lift the death cancel cleared", cleared and ult.meter.full() and engine.ultimate_lift,
		"cleared %s, meter %.1f, lift %s" % [cleared, ult.meter.value, engine.ultimate_lift])
	_kest_music()
	_kest_cue_contract()
	_game.free()
	quit(_t.verdict())


# 2026-10-11 (PC-KEST): Kest's motif stinger, low root and eighth-note roll join B3's cases.
func _kest_music() -> void:
	var bank = load("res://src/presentation/sfx_bank.gd")
	_t.eq("Kest peak motif is 62, 57, 53", bank.kest_score("raid_kest_stinger").map(func(e): return e[1]), [62, 57, 53])
	_t.eq("Kest touchdown boom is low root 50", bank.kest_score("raid_kest_boom")[0][1], 50)
	var engine: MusicEngine = _audio.engine
	_game.events.ultimate_started.emit("windhover", "arc", Vector3.ZERO, Vector3(30.0, 0.0, 0.0), 3.0)
	_game.events.ultimate_peak.emit("windhover", Vector3(30.0, 14.0, 0.0))
	var peak: Array = _audio.cue_log.filter(func(c): return c[0] == "ultimate_peak" and c[1] == "raid_kest_stinger")
	_t.check("Kest peak stinger uses the real music grid", peak.size() == 1 and peak[0][2] == "beat")
	var touchdown := engine.clock
	_game.events.ultimate_landed.emit("windhover", Vector3(30.0, 0.0, 0.0), 8, 600.0)
	var boom: Array = _audio.cue_log.filter(func(c): return c[1] == "raid_kest_boom")
	_t.check("Kest boom falls within one beat of touchdown", boom.size() == 1 and boom[0][3] >= touchdown and boom[0][3] - touchdown <= engine.beat_len())
	var eighth := engine.beat_len() / 2
	var roll := []
	for note in [62, 57, 53]:
		roll.append(_audio.kest_roll(note))
		engine.render(eighth)
	_t.check("Kest roll groups sound on successive eighths", roll[1] - roll[0] == eighth and roll[2] - roll[1] == eighth
		and posmod(roll[0] - engine.grid_origin, eighth) == 0, "samples %s" % [roll])


func _kest_cue_contract() -> void:
	var bank = load("res://src/presentation/sfx_bank.gd")
	var rows = load("res://src/presentation/rows.gd")
	_audio.engine._set_key(3)
	var keyed := true
	var leveled := true
	var admitted := true
	var details := []
	for sound in _audio.KEST_SOUNDS:
		_audio._last_start.erase(sound)
		var kind := "line_skill_fired" if sound.begins_with("cable_") else "ultimate_peak"
		_audio.engine._voices.clear()
		var before: int = _audio.cue_log_total
		if sound.begins_with("tick_kest_"):
			_audio.kest_roll(int(sound.get_slice("_", 2)))
		elif sound == "raid_kest_boom":
			kind = "ultimate_landed"
			_audio._on_ultimate_landed("windhover", Vector3.ZERO, 0, 0.0)
		elif sound == "raid_kest_stinger":
			_audio._on_ultimate_peak("windhover", Vector3.ZERO)
		else:
			_game.player.kit.cloaked = true
			_game.combat.ultimate._sound(sound, not sound.begins_with("cable_"))
		var emitted: Array = _audio.cues_since(before).filter(func(c): return c[1] == sound)
		var gain: float = bank.trim_db(sound) + _audio.PRIORITY_DB[rows.priority(kind)]
		if emitted.size() == 1 and emitted[0][2] == "now":
			keyed = keyed and absf(float(emitted[0][4]) - Harmony.ratio(_audio.live_key())) < 0.0001
			leveled = leveled and absf(float(emitted[0][5]) - gain) < 0.0001
		elif emitted.size() == 1:
			var at: int = emitted[0][3]
			_audio.engine.render(maxi(at - _audio.engine.clock, 0) + 1)
			var wanted = bank.samples_at(sound, _audio.engine.step_len, _audio.live_key(), _audio.engine.theme)
			var voices: Array = _audio.engine._voices.filter(func(v): return v.to_stinger and v.buf == wanted)
			keyed = keyed and voices.size() >= 1
			leveled = leveled and voices.size() >= 1 and absf(voices[0].gl - db_to_linear(gain)) < 0.0001
		else:
			keyed = false
			leveled = false
		admitted = admitted and _audio._last_start.has(sound)
		details.append([sound, emitted])
	_t.check("Every Kest cue follows the live key", keyed, str(details))
	_t.check("Every Kest cue uses trim plus row priority through admission", leveled and admitted, str(details))
