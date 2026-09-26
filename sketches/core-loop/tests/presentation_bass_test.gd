extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")

# Phase 1c, the bass (Andrew, round 2): a rhythmic bass figure in every theme at every
# pressure; a wobble whose LFO is locked to the beat grid at every tempo; the launch
# builds and the landing drops within one beat of touchdown; a slam's womp sounds on
# the same audio frame as the slam; danger ducks the bass. Engine state and cue
# decisions on the dummy driver, not speakers.

const PRESSURES := [0.0, 0.25, 0.5, 0.75, 1.0]

var _game
var _audio
var _failures := 0
var _step := 0
var _wait_until := 0


func _initialize() -> void:
	MusicEngine.prepare()
	_bass_everywhere()
	_wobble_locked()
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


func _wobble_locked() -> void:
	var specs := [["level", 0, ""], ["level", 1, ""], ["level", 2, ""], ["warden", 0, "drop"], ["brindle", 0, "2"], ["brindle", 0, "3"]]
	var bad: Array = []
	var total := 0
	var rates := {}
	var mixed_bars := 0
	for spec in specs:
		var engine := MusicEngine.new()
		if spec[0] == "level":
			engine.schedule_restart(0, MusicEngine.PLAY, spec[1])
			engine.set_pressure(1.0)
			engine.render(1)
			engine.render(Harmony.BAR)
		else:
			engine.force_track(spec[0], spec[1], spec[2], true)
		engine.wob_log.clear()
		engine.render(engine.bar_len() * 8)
		var bars := {}
		for entry in engine.wob_log:
			total += 1
			var at: int = entry[0]
			var count: int = MusicEngine.RATES[entry[1]]
			var beat: int = int(entry[5]) * Harmony.STEPS_PER_BEAT
			var pos := posmod(at - int(entry[4]), beat)
			var on_grid := false
			for k in count:
				on_grid = on_grid or pos == int(round(float(k) * beat / count))
			if not on_grid or int(entry[2]) != beat / count:
				bad.append("%s:%s %d" % [spec[0], spec[2], at])
			var bar_key := "%d:%d" % [entry[6], entry[7]]
			if bars.has(bar_key) and bars[bar_key] != entry[1]:
				mixed_bars += 1
			bars[bar_key] = entry[1]
			rates[entry[1]] = true
	_check("wobble on the grid", bad.is_empty() and mixed_bars == 0 and total > 100 and rates.size() == MusicEngine.RATES.size(),
		"%d LFO cycles over 8 bars each of 3 themes, the Warden drop (129) and Brindle phases 2 (129) and 3 (150): every cycle starts on a beat subdivision of its own rate, one rate per bar, %d rates used %s; off-grid %s" % [total, rates.size(), rates.keys(), bad.slice(0, 5)])


func _process(_delta: float) -> bool:
	if _step < 3 and (_game == null or _game.flow == null):
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
			# Danger pulls the bass down.
			_game.events.player_hit.emit(5.0, "test")
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
	_wait_until = Time.get_ticks_msec() + wait_ms


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
