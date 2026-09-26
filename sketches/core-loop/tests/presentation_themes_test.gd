extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")

# The level themes and boss tiers, driven directly. Every theme and boss track renders
# non-silent without clipping; the metric modulation lands on a beat boundary and
# turns a half-note triplet at 172 into the quarter at 129; a theme switch happens on
# the next downbeat; held at 172 the boss comes straight in; a boss kill cadences
# home to the level at 172; the densest arrangement stays in its CPU budget.

var _failures := 0


func _initialize() -> void:
	MusicEngine.prepare_all()
	_tracks()
	_pivot()
	_theme_switch()
	_held()
	_home()
	_cost()
	print("presentation_themes_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _tracks() -> void:
	var specs := []
	for theme in 3:
		specs.append(["level", theme, "", false, 0.0])
		specs.append(["level", theme, "", false, 1.0])
		specs.append(["miniboss", theme, "", false, 1.0])
		specs.append(["warden", theme, "build", true, 1.0])
		specs.append(["warden", theme, "drop", true, 1.0])
	for section in ["1", "2", "3", "victory"]:
		specs.append(["brindle", 0, section, true, 1.0])
	var failing: Array = []
	var lines: Array = []
	for spec in specs:
		var engine := MusicEngine.new()
		engine.force_track(spec[0], spec[1], spec[2], spec[3])
		engine.set_pressure(spec[4])
		engine.set_overcharge(2 if spec[0] == "warden" else 0)
		engine.render(engine.bar_len())
		engine.render(engine.bar_len() * 3)
		var sum := 0.0
		var top := 0.0
		var hot := 0
		for frame in engine.out_music:
			sum += frame.x * frame.x + frame.y * frame.y
			var a := maxf(absf(frame.x), absf(frame.y))
			top = maxf(top, a)
			if a > 0.97:
				hot += 1
		var rms := sqrt(sum / (2.0 * engine.out_music.size()))
		var name := "%s %s %s p%.0f" % [spec[0], Harmony.THEMES[spec[1]] if spec[0] != "brindle" else "", spec[2], spec[4]]
		lines.append("%s rms %.3f peak %.2f" % [name.strip_edges(), rms, top])
		if rms < 0.03 or top >= 1.0 or hot > engine.out_music.size() / 1000:
			failing.append(name)
	_check("tracks render", failing.is_empty(), "%d tracks over 3 bars each, non-silent, peak below full scale; failing %s" % [specs.size(), failing])
	for line in lines:
		print("  %s" % line)


func _pivot() -> void:
	var engine := _level(0)
	engine.render(Harmony.BAR + Harmony.BEAT * 2 + 1234)
	var asked := engine.clock
	var begin := engine.begin_boss("warden")
	engine.render(begin - engine.clock + Harmony.BAR * 3)
	var tempo := engine.events_log.filter(func(e: Array): return e[0] == "tempo")
	var hits: Array = engine.events_log.filter(func(e: Array): return e[0] == "hit").map(func(e: Array): return e[1])
	var pivot: int = tempo[0][1] if tempo.size() > 0 else -1
	var on_beat := pivot > asked and pivot % Harmony.BEAT == 0 and pivot == begin + Harmony.BAR
	var triplets := hits == [begin, begin + Harmony.BOSS_BEAT, begin + 2 * Harmony.BOSS_BEAT] and begin + 3 * Harmony.BOSS_BEAT == pivot
	var new_grid := engine.step_len == Harmony.BOSS_STEP and engine.grid_origin == pivot and absf(engine.bpm() - 129.0) < 0.01
	_check("pivot on the beat", on_beat and triplets and new_grid,
		"asked mid-bar at %d; the transition bar at %d pulses half-note triplets %s; the pivot at %d is a 172 beat boundary and beat 0 of the %.1f BPM grid" % [asked, begin, hits, pivot, engine.bpm()])
	var track_log := engine.events_log.filter(func(e: Array): return e[0] == "track")
	_check("warden in", track_log.size() == 1 and track_log[0][2] == "warden:build" and track_log[0][1] == pivot, "the Warden build starts on the pivot")
	var drop_at := engine.next_beat()
	engine.drop_at(drop_at)
	engine.render(drop_at - engine.clock + 1)
	_check("drop on the beat", engine.section == "drop" and engine.bar_origin == drop_at and (drop_at - engine.grid_origin) % engine.beat_len() == 0,
		"the unseal drop lands on a 129 beat and becomes its downbeat")


func _theme_switch() -> void:
	var engine := _level(0)
	engine.render(Harmony.BAR * 2 + Harmony.BEAT + 777)
	var asked := engine.clock
	var at := engine.set_theme(1)
	engine.render(at - engine.clock - 1)
	var early := engine.theme
	engine.render(2)
	var switched := engine.events_log.filter(func(e: Array): return e[0] == "theme" and e[2] == 1)
	var ok: bool = early == 0 and engine.theme == 1 and switched.size() == 1 and switched[0][1] == at and (at - engine.bar_origin) % Harmony.BAR == 0 and at > asked and at - asked < Harmony.BAR
	_check("theme on the downbeat", ok, "asked at %d, mid-bar; Spillway plays to sample %d and Sluice starts on that downbeat" % [asked, at])
	var start := engine.next_beat()
	engine.schedule_restart(start, MusicEngine.PLAY, 2)
	engine.render(start - engine.clock + 1)
	_check("stage restart", engine.theme == 2 and engine.bar_origin == start and engine.track == "level", "a stage entry restarts the phrase on its stinger beat in the stage's theme (Weir)")


func _held() -> void:
	var engine := _level(1)
	engine.boss_pivot = false
	engine.render(Harmony.BAR + 5000)
	var begin := engine.begin_boss("warden")
	engine.render(begin - engine.clock + Harmony.BEAT)
	var tempo := engine.events_log.filter(func(e: Array): return e[0] == "tempo")
	_check("held at 172", tempo.is_empty() and engine.track == "warden" and absf(engine.bpm() - 172.0) < 0.1 and engine.bar_origin == begin,
		"with F6's held option the Warden comes straight in at 172 on the next bar")


func _home() -> void:
	var engine := MusicEngine.new()
	engine.force_track("warden", 0, "drop", true)
	engine.render(Harmony.BOSS_BEAT * 5 + 999)
	var cadence := engine.end_boss()
	engine.render(cadence - engine.clock + Harmony.BOSS_BEAT * 4 * 2 + 10)
	var tempo := engine.events_log.filter(func(e: Array): return e[0] == "tempo")
	var back: int = tempo[tempo.size() - 1][1] if tempo.size() > 0 else -1
	var grid_start := cadence - posmod(cadence, Harmony.BOSS_BEAT)
	var ok: bool = engine.track == "level" and absf(engine.bpm() - 172.0) < 0.1 and back == cadence + Harmony.BOSS_BEAT * 8 and engine.grid_origin == back
	_check("home after the kill", ok and grid_start == cadence,
		"the kill cadences for two bars at 129 from beat %d, then the level returns at 172 on a beat (sample %d)" % [cadence, back])


func _cost() -> void:
	var worst := 0.0
	var name := ""
	for spec in [["warden", 0, "drop"], ["brindle", 0, "3"], ["miniboss", 2, ""], ["level", 0, ""]]:
		# A throwaway engine plays eight bars first, so notes rendered on first use (the
		# game warms them on a worker behind stage 1) do not count as steady cost.
		for warm in 2:
			var engine := MusicEngine.new()
			engine.force_track(spec[0], spec[1], spec[2], spec[0] in ["warden", "brindle"])
			engine.set_pressure(1.0)
			engine.set_overcharge(2)
			engine.render(engine.bar_len() * (8 if warm == 0 else 1))
			if warm == 0:
				continue
			var t := Time.get_ticks_usec()
			for block in 300:
				engine.render(735)
			var ms := (Time.get_ticks_usec() - t) / 1000.0 / (300.0 * 735.0 / Harmony.RATE)
			if ms > worst:
				worst = ms
				name = "%s %s" % [spec[0], spec[2]]
	_check("cpu", worst < 80.0, "densest arrangement %s costs %.0f ms of main-thread time per second of music (%.1f%% of one core)" % [name, worst, worst / 10.0])


func _level(theme: int) -> MusicEngine:
	var engine := MusicEngine.new()
	engine.schedule_restart(0, MusicEngine.PLAY, theme)
	engine.set_pressure(0.8)
	engine.render(1)
	return engine


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
