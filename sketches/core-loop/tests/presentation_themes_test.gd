# smoke: solo (verdict reads wall time: cpu ratio cap on paired CPU-time runs)
extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const PlatformPin := preload("res://tests/support/platform_pin.gd")

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


# The music's cost is judged against a fixed reference workload timed in the same
# process right before and right after it. Contention from other runs on the machine
# slows both sides alike, so their ratio holds; a heavier arrangement moves only the
# music side. Each arrangement's ratio is the least of MEASURES paired runs. The
# absolute cost per second of music is printed as information, against the old 80 ms.
const MEASURES := 3
# Calibrated alone on this machine (DESIGN-NOTES integration call 18): the densest
# arrangement sits at about 85-90% of it.
const RATIO_CAP := 0.21
# 2026-11-17 (ruling eb, Mac gate; tests/support/platform_pin.gd): the Mac cap, 5 percent over its highest reading.
# The Mac Studio (M5 Max, Godot 4.7.2) has no /proc, so _measure reads wall time there. Five runs on
# w43/gate-mac-reds 30c61601, beside the posture sweeps (load average 21 to 33), read 0.204, 0.210, 0.214, 0.205 and
# 0.205 (densest arrangement, least of three paired runs); the wave 43 gate read 0.211 to 0.215. Highest 0.215.
const RATIO_CAP_MAC := 0.226
const ABSOLUTE_NOTE_MS := 80.0
# The reference: REF_VOICES fixed buffers mixed with a gain ramp into one block, the
# shape of the engine's own inner mixing loop, REF_BLOCKS times.
const REF_VOICES := 8
const REF_BLOCKS := 1200
const BLOCK := 735


func _cost() -> void:
	var worst := 0.0
	var name := ""
	var worst_runs: Array = []
	var ref := _reference_buffer()
	for spec in [["warden", 0, "drop"], ["brindle", 0, "3"], ["miniboss", 2, ""], ["level", 0, ""]]:
		# A throwaway engine plays eight bars first, so notes rendered on first use (the
		# game warms them on a worker behind stage 1) do not count as steady cost.
		var runs: Array = []
		for warm in MEASURES + 1:
			var engine := MusicEngine.new()
			engine.force_track(spec[0], spec[1], spec[2], spec[0] in ["warden", "brindle"])
			engine.set_pressure(1.0)
			engine.set_overcharge(2)
			engine.render(engine.bar_len() * (8 if warm == 0 else 1))
			if warm == 0:
				continue
			var before := _reference_ms(ref)
			var spent := _measure(func():
				for block in 300:
					engine.render(BLOCK))
			var after := _reference_ms(ref)
			var ms := spent / (300.0 * BLOCK / Harmony.RATE)
			runs.append({"ms": ms, "ref": (before + after) * 0.5, "ratio": ms / maxf(1.0, (before + after) * 0.5)})
		var least: Dictionary = runs[0]
		for r in runs:
			if r["ratio"] < least["ratio"]:
				least = r
		if least["ratio"] > worst:
			worst = least["ratio"]
			worst_runs = runs
			name = "%s %s" % [spec[0], spec[2]]
	var shown := ", ".join(worst_runs.map(func(r): return "%.0f ms / %.0f ms ref = %.3f" % [r["ms"], r["ref"], r["ratio"]]))
	var least_ms: float = worst_runs.map(func(r): return r["ms"]).min() if not worst_runs.is_empty() else 0.0
	var cap: float = PlatformPin.pick(RATIO_CAP, RATIO_CAP_MAC)
	_check("cpu", worst > 0.0 and worst < cap,
		"densest arrangement %s costs %.3f of the reference workload (cap %.3f), the least of %d paired runs [%s]; absolute %.0f ms of CPU per second of music, %.1f%% of one core (information only, was capped at %.0f ms)"
			% [name, worst, cap, MEASURES, shown, least_ms, least_ms / 10.0, ABSOLUTE_NOTE_MS])


# This process's own CPU time for the work, where the OS reports it (Linux /proc), so
# other agents' runs on a busy machine are not counted; wall time elsewhere.
func _measure(work: Callable) -> float:
	var cpu0 := _cpu_ms()
	var t := Time.get_ticks_usec()
	work.call()
	return _cpu_ms() - cpu0 if cpu0 >= 0.0 else (Time.get_ticks_usec() - t) / 1000.0


static func _reference_buffer() -> PackedFloat32Array:
	var src := PackedFloat32Array()
	src.resize(BLOCK)
	for i in BLOCK:
		src[i] = sin(TAU * 220.0 * i / Harmony.RATE) * 0.5
	return src


func _reference_ms(src: PackedFloat32Array) -> float:
	var dst := PackedFloat32Array()
	dst.resize(BLOCK)
	var inv_n := 1.0 / BLOCK
	return _measure(func():
		for block in REF_BLOCKS:
			dst.fill(0.0)
			for v in REF_VOICES:
				var g0 := 0.5 + 0.01 * v
				var g1 := g0 * 0.9
				for i in BLOCK:
					dst[i] += src[i] * (g0 + (g1 - g0) * i * inv_n) * 0.7)


# User plus system CPU of this process in ms, from /proc/self/stat (clock ticks of
# 10 ms), or -1 where that file does not exist.
func _cpu_ms() -> float:
	var f := FileAccess.open("/proc/self/stat", FileAccess.READ)
	if f == null:
		return -1.0
	# procfs reports a size of 0, so read a line rather than the "whole file".
	var line := f.get_line()
	var fields := line.substr(line.rfind(")") + 2).split(" ")
	if fields.size() < 13:
		return -1.0
	return (float(fields[11]) + float(fields[12])) * 10.0


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
