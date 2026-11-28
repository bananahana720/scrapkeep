extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

# B's grammar everywhere (C4, MUSIC-GEMS G11). For each track family, game state
# crossing a threshold lands the lift or the break on a bar line and the payoff on
# the next beat, and the track's core voices keep playing through it. Then the live
# key: after a lift, reward cues and on-beat stingers transpose.

var _failures := 0
var _game
var _audio
var _step := 0
var _wait_until := 0


func _initialize() -> void:
	MusicPrebake.prepare()
	for theme in 3:
		_warden(theme)
		_miniboss(theme)
	_event()
	_brindle()
	_chase()
	_heft()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


# The lift lands on a bar line in the key a half step up; returns the key change.
func _lift_lands(engine: MusicEngine, fraction_call: Callable) -> bool:
	var before := engine.key
	fraction_call.call()
	engine.render(engine.bar_len() * 3)
	var keys: Array = engine.events_log.filter(func(e: Array): return e[0] == "key" and int(e[2]) == before + 1)
	return engine.key == before + 1 and keys.size() > 0 and posmod(int(keys[0][1]) - engine.grid_origin, engine.step_len) == 0 and posmod(int(keys[0][1]) - engine.bar_origin, engine.bar_len()) == 0


func _drop_on_beat(engine: MusicEngine, at: int) -> bool:
	var asked := engine.clock
	engine.render(maxi(at - engine.clock, 0) + 64)
	return at >= asked and at - asked <= engine.beat_len() and engine.in_drop()


func _warden(theme: int) -> void:
	var engine := MusicEngine.new()
	engine.force_track("warden", theme, "build", true)
	engine.render(engine.bar_len() + 999)
	var lifted := _lift_lands(engine, func(): engine.warden_charge(0.55))
	var lift_section := engine.section == "lift"
	var starts := engine.layer_starts.duplicate()
	engine.bass_log.clear()
	engine.warden_charge(0.8)
	engine.render(engine.bar_len() * 3)
	var broke := engine.section == "break" and engine.building() and engine.build_level() > 0.1
	var core: bool = int(engine.bass_log.get("fbass", 0)) + int(engine.bass_log.get("reese", 0)) > 0 and engine.layer_starts[MusicEngine.KICK] > starts[MusicEngine.KICK]
	var dropped := _drop_on_beat(engine, engine.unseal_drop())
	var home := engine.key == 0 and engine.section == "drop"
	_check("Warden B %s" % Harmony.THEMES[theme], lifted and lift_section and broke and core and dropped and home,
		"half broken lifts a half step on a bar line (%s), three quarters starts the sinister break with its build (%s), kick and bass keep playing (%s), the unseal drops home on the next beat (%s, key %d)" % [lifted, broke, core, dropped, engine.key])


func _miniboss(theme: int) -> void:
	var engine := MusicEngine.new()
	engine.schedule_restart(0, MusicEngine.PLAY, theme)
	engine.set_pressure(0.6)
	engine.render(1)
	engine.render(Harmony.BAR + 777)
	engine.begin_miniboss()
	engine.render(Harmony.BAR * 2)
	var lifted := _lift_lands(engine, func(): engine.escalate(0.5))
	var subs := engine.layer_starts[MusicEngine.SUB]
	engine.escalate(0.8)
	engine.render(Harmony.BAR * 3)
	var broke := engine.section == "break" and engine.building()
	var core := engine.layer_starts[MusicEngine.SUB] > subs
	var dropped := _drop_on_beat(engine, engine.miniboss_drop())
	var home := engine.track == "level" and engine.theme == theme and engine.key == 0
	engine.render(Harmony.BAR * 4 + 64)
	var cadence := engine.events_log.filter(func(e: Array): return e[0] == "cadence").size() > 0
	_check("miniboss B %s" % Harmony.THEMES[theme], lifted and broke and core and dropped and home and cadence,
		"50%% integrity lifts on a bar line (%s), 25%% starts the sinister break (%s) with the sub still on every bar, the kill drops home on the next beat (%s) and the cadence follows (%s)" % [lifted, broke, dropped, cadence])


func _event() -> void:
	var engine := MusicEngine.new()
	engine.schedule_restart(0, MusicEngine.PLAY, 1)
	engine.set_pressure(0.5)
	engine.render(1)
	engine.render(Harmony.BAR + 500)
	var lifted := _lift_lands(engine, func(): engine.escalate(0.55, false))
	engine.escalate(0.9, false)
	engine.render(Harmony.BEAT * 3)
	var building := engine.building() and engine.section == "" and engine.track == "level"
	var won := _drop_on_beat(engine, engine.resolve_event(true))
	var won_home := engine.key == 0 and engine.theme == 1
	var lost := MusicEngine.new()
	lost.schedule_restart(0, MusicEngine.PLAY, 1)
	lost.set_pressure(0.5)
	lost.render(1)
	lost.escalate(0.55, false)
	lost.render(Harmony.BAR * 3)
	lost.escalate(0.9, false)
	lost.render(Harmony.BEAT)
	var stingers := lost.stinger_starts.size()
	lost.resolve_event(false)
	lost.render(Harmony.BAR * 3)
	var graceful: bool = lost.key == 0 and not lost.building() and not lost.in_drop() and lost.stinger_starts.size() == stingers
	_check("event B", lifted and building and won and won_home and graceful,
		"half the event lifts (%s), three quarters builds without a sinister turn (%s), a win drops home on the next beat (%s); a loss walks the key home with no drop and no sting (%s)" % [lifted, building, won, graceful])


func _brindle() -> void:
	var engine := MusicEngine.new()
	engine.force_track("brindle", 0, "1", true)
	engine.render(engine.bar_len() + 321)
	var lifted := _lift_lands(engine, func(): engine.brindle_hp(0.55))
	engine.brindle_hp(1.0, true, 0.4)
	engine.render(engine.bar_len() * 3)
	var broke := engine.escalation == "break" and engine.building()
	var lead := engine._lead_voice == "brass"
	var dropped := _drop_on_beat(engine, engine.set_brindle_phase(2))
	var phase2 := engine.section == "2" and engine.key == 1 and engine.escalation == ""
	_check("Brindle B in phase", lifted and broke and lead and dropped and phase2,
		"half the phase lifts (%s), the held floor breaks and tightens with the set piece (%s), the phase change drops on the next beat into phase 2 up a half step (%s)" % [lifted, broke, dropped and phase2])


func _chase() -> void:
	var engine := MusicEngine.new()
	engine.force_track("brindle", 0, "chase", false)
	engine.render(Harmony.BAR + 111)
	var lifted := _lift_lands(engine, func(): engine.chase(0.6))
	engine.chase(0.9)
	engine.render(Harmony.BEAT * 2)
	var building := engine.building() and engine.escalation != "break"
	var dropped := _drop_on_beat(engine, engine.victory())
	var victory := engine.section == "victory" and engine.key == 0 and absf(engine.bpm() - 172.0) < 0.1
	_check("chase into victory", lifted and building and dropped and victory,
		"the closing gap lifts (%s) and builds with no sinister turn (%s); the catch drops the victory on the next beat, home in D at 172 (%s)" % [lifted, building, dropped and victory])


func _heft() -> void:
	var engine := MusicEngine.new()
	engine.schedule_restart(0, MusicEngine.PLAY, 0)
	engine.set_pressure(0.3)
	engine.render(1)
	engine.render(Harmony.BAR + 999)
	var before := engine._intensity
	var asked := engine.clock
	engine.set_heft_lift(1)
	engine.render(Harmony.BAR * 2)
	var heft: Array = engine.events_log.filter(func(e: Array): return e[0] == "heft")
	var on_bar: bool = heft.size() == 1 and int(heft[0][1]) > asked and posmod(int(heft[0][1]) - engine.bar_origin, Harmony.BAR) == 0
	var brighter := engine._intensity > before + 0.1
	var revoiced := engine.events_log.filter(func(e: Array): return e[0] == "revoice" and int(e[1]) == (int(heft[0][1]) if heft.size() > 0 else -1)).size() > 0
	engine.set_heft_lift(0)
	engine.render(Harmony.BAR * 2)
	var back := absf(engine._intensity - before) < 0.01
	_check("heft brightens", on_bar and brighter and revoiced and back, "a class-up re-voices the next bar one step brighter (%.2f to %.2f) and a drop steps it back" % [before, before + MusicEngine.HEFT_STEP])


func _process(_delta: float) -> bool:
	if _step < 3 and (_game == null or _game.flow == null):
		return false
	if Time.get_ticks_msec() < _wait_until:
		return false
	match _step:
		0:
			_game.tuning.set_option("music", "synth")
			_audio = _game.presentation.audio
			_audio.bake_now()
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_next(900)
		1:
			var engine: MusicEngine = _audio.engine
			_audio._last_start.clear()
			_game.events.scrap_collected.emit(1, Vector3.ZERO, 1)
			var home_pitch: float = _pitch("scrap_tick")
			engine._set_key(1)
			_audio._last_start.clear()
			_audio.scrap_streak.reset()
			_game.events.scrap_collected.emit(1, Vector3.ZERO, 2)
			var lifted_pitch: float = _pitch("scrap_tick")
			var ratio := lifted_pitch / maxf(home_pitch, 0.0001)
			var home: PackedFloat32Array = SfxBank.samples_at("class_up", Harmony.STEP, 0)
			var up: PackedFloat32Array = SfxBank.samples_at("class_up", Harmony.STEP, 1)
			# 2026-10-18: synergy_fanfare has been a recorded event-set cue since c4cffb6a (SOUND-INT), so it
			# no longer quotes each level's motif (the theme arg is ignored); it still follows the live key.
			var fanfares := [SfxBank.samples_at("synergy_fanfare", Harmony.STEP, 0, 0), SfxBank.samples_at("synergy_fanfare", Harmony.STEP, 1, 0)]
			engine.schedule_stinger("class_up")
			engine.render(engine.beat_len() + 64)
			var stinger_ok: bool = engine.stinger_starts.size() > 0 and engine.stinger_starts[engine.stinger_starts.size() - 1][0] == "class_up"
			_check("live key", absf(ratio - Harmony.ratio(1.0)) < 0.001 and home != up and fanfares[0] != fanfares[1] and stinger_ok,
				"after a lift to Eb a scrap chime sounds %.4f higher (a half step is %.4f); the class-up stinger is baked in the lifted key; the recorded synergy fanfare is moved up with the key" % [ratio, Harmony.ratio(1.0)])
			engine._set_key(0)
			# R in the arena: stage_content_cleared("arena_retry") restarts Brindle from phase 1.
			_game.events.boss_arena_entered.emit()
			for i in 200:
				if engine.track == "brindle":
					break
				engine.render(engine.step_len)
			engine.brindle_hp(0.6)
			engine.render(engine.bar_len() * 3)
			_game.events.player_died.emit()
			_next(50)
		2:
			var engine: MusicEngine = _audio.engine
			engine.render(engine.beat_len() * 2)
			var dead := engine.mode == MusicEngine.DEAD
			_game.events.stage_content_cleared.emit("arena_retry")
			var fills: Array = engine.events_log.filter(func(e: Array): return e[0] == "fill")
			engine.render(engine.beat_len() * 2 + 64)
			var back: bool = engine.mode == MusicEngine.PLAY and engine.track == "brindle" and engine.section == "1" and engine.key == 0 and engine.escalation == "" and fills.size() > 0
			_check("arena_retry", dead and back and engine.overcharge == 0, "a death drops to the keys; arena_retry brings Brindle back from phase 1 in D with a pickup fill (mode %s, %s:%s, key %d)" % [MusicEngine.MODE_NAMES[engine.mode], engine.track, engine.section, engine.key])
			_game.free()
			_game = null
			_step = 3
			_wait_until = Time.get_ticks_msec() + 300
		3:
			print("presentation_escalation_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _pitch(sound: String) -> float:
	var cues: Array = _audio.cue_log.filter(func(c: Array): return c[1] == sound and c[2] == "now")
	return float(cues[cues.size() - 1][4]) if cues.size() > 0 else 0.0


func _next(wait_ms: int) -> void:
	_step += 1
	_wait_until = Time.get_ticks_msec() + wait_ms


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
