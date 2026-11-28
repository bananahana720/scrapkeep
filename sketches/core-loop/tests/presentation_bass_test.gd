extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")

# The bass and the layers (Andrew, rounds 2 and 3): a rhythmic bass figure in every
# theme at every pressure; no wubs in the level themes, a restrained grid-locked
# wobble only in the Warden's and Brindle's drops; melodic layers that stack with
# pressure and re-voice every cycle; the launch builds and the landing drops within
# one beat of touchdown; a slam's womp sounds on the same audio frame as the slam;
# danger ducks the bass. Engine state and cue decisions on the dummy driver.

const PRESSURES := [0.0, 0.25, 0.5, 0.75, 1.0]
# The lead alone against the whole mix at full pressure. Measured 10 to 16 dB under on 10 Nov 2026;
# the floor leaves 6 dB for tuning and is well above a lead nobody can hear (a planted 20 dB cut
# reads 30 to 36 under). A tripwire for a silent tune, not a statement of the right level.
const LEAD_UNDER_DB := 22.0

var _game
var _audio
var _failures := 0
var _step := 0
var _wait_frames := 0


func _initialize() -> void:
	MusicPrebake.prepare()
	_bass_everywhere()
	_lead_heard()
	_wubs_reined_in()
	_layers_rise()
	_revoiced()
	_launch_from_drop()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _bass_everywhere() -> void:
	var failing: Array = []
	var lines: Array = []
	for theme in 3:
		for p in PRESSURES:
			var engine := MusicEngine.new()
			engine.schedule_restart(0, MusicEngine.PLAY, theme)
			engine.set_pressure(p)
			engine.render(1)
			engine.render(Harmony.BAR)
			engine.solo = [MusicEngine.SUB, MusicEngine.REESE, MusicEngine.WOB]
			var before := engine.layer_starts[MusicEngine.REESE]
			engine.render(Harmony.BAR * 2)
			var notes := engine.layer_starts[MusicEngine.REESE] - before
			var sum := 0.0
			for frame in engine.out_music:
				sum += frame.x * frame.x + frame.y * frame.y
			var rms := sqrt(sum / (2.0 * engine.out_music.size()))
			lines.append("%s p%.2f bass rms %.3f, %d figure notes in 2 bars" % [Harmony.THEMES[theme], p, rms, notes])
			if rms < 0.03 or notes < 6:
				failing.append("%s p%.2f" % [Harmony.THEMES[theme], p])
	_check("bass never leaves", failing.is_empty(), "3 themes x 5 pressures: the bass bus (sub, figure, wobble) is audible and the figure plays at least 3 notes a bar; failing %s" % [failing])
	for line in lines:
		print("  %s" % line)


# Melody first: at full pressure the lead plays notes and can be heard over the mix in every theme.
# The synth engine only; the PC's recorded stems go through ace_sequencer.gd (ruling bt) and are
# judged on a PC listen.
# The engine's groove pick is not seeded, so the whole-mix figure moves between runs: over five
# runs on 10 Nov 2026 the three themes read 11.4 to 11.7, 10.4 and 15.8 dB under, a 0.3 dB spread
# against 6 dB of room to the line, and the planted cut (the lead 20 dB down) read 30 to 36.
func _lead_heard() -> void:
	var failing: Array = []
	var lines: Array = []
	for theme in 3:
		var alone := 0.0
		var whole := 0.0
		var notes := 0
		for solo in [[MusicEngine.LEAD], []]:
			var engine := MusicEngine.new()
			engine.schedule_restart(0, MusicEngine.PLAY, theme)
			engine.set_pressure(1.0)
			engine.render(1)
			engine.render(Harmony.BAR * 8)
			engine.solo = solo
			var before := engine.layer_starts[MusicEngine.LEAD]
			engine.render(Harmony.BAR * 8)
			var sum := 0.0
			for frame in engine.out_music:
				sum += frame.x * frame.x + frame.y * frame.y
			var rms := sqrt(sum / (2.0 * engine.out_music.size()))
			if solo.is_empty():
				whole = rms
			else:
				alone = rms
				notes = engine.layer_starts[MusicEngine.LEAD] - before
		var under := -linear_to_db(alone / maxf(whole, 0.000001))
		lines.append("%s lead %.1f dB under the mix (rms %.3f of %.3f), %d notes in 8 bars" % [Harmony.THEMES[theme], under, alone, whole, notes])
		if under > LEAD_UNDER_DB or notes < 8:
			failing.append(Harmony.THEMES[theme])
	_check("the lead is heard", failing.is_empty(), "3 themes at full pressure: the lead alone is within %d dB of the whole mix and plays at least a note a bar; failing %s" % [int(LEAD_UNDER_DB), failing])
	for line in lines:
		print("  %s" % line)


func _wubs_reined_in() -> void:
	# No wobble voice (the growls were wobble voices too) in any level theme or the
	# miniboss, even at full pressure over eight bars.
	var loud: Array = []
	for spec in [["level", 0], ["level", 1], ["level", 2], ["miniboss", 0], ["miniboss", 2]]:
		var engine := MusicEngine.new()
		engine.schedule_restart(0, MusicEngine.PLAY, spec[1])
		engine.set_pressure(1.0)
		engine.render(1)
		if spec[0] == "miniboss":
			engine.begin_miniboss()
		engine.render(Harmony.BAR * 9)
		if engine.layer_starts[MusicEngine.WOB] > 0 or engine.layer_target(MusicEngine.WOB) > 0.0:
			loud.append("%s %s" % [spec[0], Harmony.THEMES[spec[1]]])
	_check("wubs reined in", loud.is_empty(), "no wobble or growl voice starts in the three level themes or the miniboss at full pressure over 8 bars; offenders %s" % [loud])
	# The Warden's drop is round 2's club again, with no wobble; Brindle's drops keep
	# a restrained one: half level, slow rates, every cycle on the grid.
	var warden := MusicEngine.new()
	warden.force_track("warden", 0, "drop", true)
	warden.render(warden.bar_len() * 4)
	var warden_clean := warden.layer_starts[MusicEngine.WOB] == 0
	var engine := MusicEngine.new()
	engine.force_track("brindle", 0, "1", true)
	engine.set_brindle_phase(2)
	while not engine.in_drop():
		engine.render(engine.step_len)
	engine.wob_log.clear()
	engine.render(engine.bar_len() * 4)
	var level := engine.layer_target(MusicEngine.WOB)
	var bad: Array = []
	var rates := {}
	for entry in engine.wob_log:
		var count: int = MusicEngine.RATES[entry[1]]
		var beat: int = int(entry[5]) * Harmony.STEPS_PER_BEAT
		var pos := posmod(int(entry[0]) - int(entry[4]), beat)
		var on_grid := false
		for k in count:
			on_grid = on_grid or pos == int(round(float(k) * beat / count))
		if not on_grid or not entry[1] in MusicEngine.DROP_RATES:
			bad.append(entry[0])
		rates[entry[1]] = true
	_check("drop wobble restrained", warden_clean and engine.wob_log.size() > 8 and bad.is_empty() and level <= MusicEngine.WOB_DROP_GAIN + 0.001,
		"the Warden drop has no wobble (%s); Brindle's drop has %d cycles at level %.2f (cap %.2f), rates %s, all on the grid; off %s" % [warden_clean, engine.wob_log.size(), level, MusicEngine.WOB_DROP_GAIN, rates.keys(), bad.slice(0, 4)])


# Pyramids-style layering: each pressure step adds melodic layers, never removes one.
func _layers_rise() -> void:
	var failing: Array = []
	var lines: Array = []
	var static_ok := true
	var last_static := -1
	for i in 11:
		var n := MusicEngine.melodic_layers(i / 10.0)
		static_ok = static_ok and n >= last_static
		last_static = n
	for theme in 3:
		var counts: Array = []
		for i in 6:
			var p := i / 5.0
			var engine := MusicEngine.new()
			engine.schedule_restart(0, MusicEngine.PLAY, theme)
			engine.set_pressure(p)
			engine.render(1)
			engine.render(Harmony.BAR)
			var before := engine.layer_starts.duplicate()
			engine.render(Harmony.BAR * 4)
			var sounding := 0
			for layer in MusicEngine.MELODIC:
				if engine.layer_starts[layer] > before[layer] and engine.layer_gain(layer) > 0.05:
					sounding += 1
			counts.append(sounding)
		lines.append("%s %s" % [Harmony.THEMES[theme], counts])
		var mono := true
		for i in range(1, counts.size()):
			mono = mono and counts[i] >= counts[i - 1]
		if not mono or counts[0] > 0 or counts[counts.size() - 1] < MusicEngine.MELODIC.size():
			failing.append(Harmony.THEMES[theme])
	_check("layers rise with pressure", static_ok and failing.is_empty(), "melodic layers sounding over 4 bars at pressure 0, 0.2 .. 1: %s (0 at calm, all %d at full, never fewer as pressure rises)" % [", ".join(lines), MusicEngine.MELODIC.size()])


# The texture evolves: at full pressure every 8-bar cycle re-voices the lines.
func _revoiced() -> void:
	var failing: Array = []
	var seen := 0
	for theme in 3:
		var engine := MusicEngine.new()
		engine.schedule_restart(0, MusicEngine.PLAY, theme)
		engine.set_pressure(1.0)
		engine.render(1)
		engine.events_log.clear()
		engine.render(Harmony.BAR * 24)
		var revoices: Array = engine.events_log.filter(func(e: Array): return e[0] == "revoice")
		seen += revoices.size()
		for cycle in 3:
			var inside := revoices.filter(func(e: Array): return int(e[1]) >= cycle * Harmony.BAR * 8 and int(e[1]) < (cycle + 1) * Harmony.BAR * 8)
			if inside.is_empty():
				failing.append("%s cycle %d" % [Harmony.THEMES[theme], cycle])
		for i in range(1, revoices.size()):
			if revoices[i][2] == revoices[i - 1][2]:
				failing.append("%s repeat at %d" % [Harmony.THEMES[theme], revoices[i][1]])
	_check("re-voiced every cycle", failing.is_empty(), "%d re-voicings over 24 bars of each theme at full pressure; every 8-bar cycle has at least one and none repeats the one before; failing %s" % [seen, failing])


# Players take the gate inside the Warden's unseal drop: the launch still builds over
# the drop and the landing drops into the next stage's theme at 172.
func _launch_from_drop() -> void:
	var engine := MusicEngine.new()
	engine.force_track("warden", 0, "drop", true)
	engine.render(engine.bar_len() * 2 + 999)
	engine.start_build(1.6, true)
	engine.render(engine.beat_len() * 3)
	var built := engine.building() and engine.in_drop() and engine.build_level() > 0.3
	var at := engine.drop_now(4, 0.85, {}, 2)
	engine.render(at - engine.clock + 64)
	var ok: bool = built and engine.in_drop() and engine.track == "level" and engine.theme == 2 and absf(engine.bpm() - 172.0) < 0.1 and engine.clock - at == 64
	_check("launch from the unseal drop", ok, "a gate taken mid-drop builds over the drop (level %.2f) and the landing drops into Weir at %.0f BPM" % [engine.build_level(), engine.bpm()])


func _process(_delta: float) -> bool:
	if _step < 3 and (_game == null or _game.flow == null):
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
			_next(900)
		1:
			var engine: MusicEngine = _audio.engine
			var playing: bool = engine.mode == MusicEngine.PLAY and engine.track == "level"
			# The womp: same audio frame as the slam, biggest for the flat full plant.
			var frame := engine.clock
			_game.events.slammed.emit(Vector3.ZERO, 1.0, 1.0)
			var big: Array = _audio.cue_log.filter(func(c: Array): return c[1] == "womp")
			_audio._last_start.clear()
			_game.events.slammed.emit(Vector3.ZERO, 0.5, 0.0)
			var womps: Array = _audio.cue_log.filter(func(c: Array): return c[1] == "womp")
			var instant: bool = big.size() == 1 and big[0][2] == "now" and int(big[0][3]) == frame
			var biggest: bool = womps.size() == 2 and womps[0][4] < womps[1][4]
			_check("womp on the slam frame", instant and biggest, "the slam at audio frame %d starts its womp at frame %d, unquantized; the flat full plant sits lower (pitch %.2f) than a half-strength tilted one (%.2f)" % [frame, int(big[0][3]) if big.size() > 0 else -1, womps[0][4] if womps.size() > 0 else 0.0, womps[1][4] if womps.size() > 1 else 0.0])
			# Danger pulls the bass down. Under armour a hit that sheds only mass is a deflect with
			# no danger cue, so the run takes a hit big enough to pass the scrap layer and reach the hull.
			_game.ctx.run.damage(_game.ctx.run.mass / _game.ctx.run.scrap_per_hp / (1.0 - _game.ctx.run.mitigation) + 5.0, "test")
			_check("danger ducks the bass", engine._bass_duck_target < 0.5, "a hit cue drops the bass bus to %.2f while it sounds" % engine._bass_duck_target)
			# The launch is the build.
			_game.events.launched.emit(Vector3(0.0, 12.0, 20.0))
			var built := engine.building()
			engine.render(Harmony.BEAT * 2 + 1111)
			var rising := engine.build_level() > 0.1
			_game.events.stage_cleared.emit(1)
			_game.events.stage_entered.emit(2, false)
			engine.render(Harmony.BEAT + 2222)
			var still := engine.building() and engine.track == "level"
			_check("launch builds", playing and built and rising and still, "launched starts the build (level %.2f after two beats) and it holds through the stage change until the landing" % engine.build_level())
			_next(30)
		2:
			var engine: MusicEngine = _audio.engine
			var touchdown := engine.clock
			_game.events.landed.emit(14.0)
			var drop_log: Array = _audio.drop_log
			var at: int = drop_log[drop_log.size() - 1][1] if drop_log.size() > 0 else -1
			var within := at >= touchdown and at - touchdown <= engine.beat_len()
			var on_beat := at >= 0 and posmod(at - engine.grid_origin, engine.beat_len()) == 0
			engine.render(maxi(at - engine.clock, 0) + 64)
			var drops: Array = engine.events_log.filter(func(e: Array): return e[0] == "drop")
			var gaps: Array = engine.events_log.filter(func(e: Array): return e[0] == "gap")
			var landed: bool = drops.size() > 0 and int(drops[drops.size() - 1][1]) == at and engine.in_drop() and engine.theme == 1 and not engine.building()
			var silence: bool = at == touchdown or (gaps.size() > 0 and int(gaps[gaps.size() - 1][1]) == touchdown)
			_check("landing drops", within and on_beat and landed and silence,
				"touchdown at %d, drop at %d (%.2f beats later, on the grid), in Sluice's theme, with silence from touchdown to the drop" % [touchdown, at, float(at - touchdown) / engine.beat_len()])
			_game.free()
			_next(300)
		3:
			print("presentation_bass_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _next(wait_ms: int) -> void:
	_step += 1
	# Render the wait in samples; only deferred tree cleanup needs idle frames.
	if _step < 3:
		_audio._flush_flow()
		_audio.engine.render(int(wait_ms * Harmony.RATE / 1000.0))
	_wait_frames = 3


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
