# smoke: solo (verdict reads wall time: cpu cap on main-thread ms per second of music)
extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")
const MusicPhrases := preload("res://src/presentation/music_phrases.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

# The band, driven directly: layer gains rise monotonically with pressure and calm
# leaves space; the band gets louder as pressure rises; a stinger asked for mid-beat
# starts exactly on the next beat; flow stingers queue in one lane; the stage clear
# resolves and hands back to the loop; the lead changes every loop and stays in key.

var _failures := 0


func _initialize() -> void:
	MusicPrebake.prepare()
	_gains()
	_loudness()
	_stinger_on_the_beat()
	_lane_and_cadence()
	_lead()
	_cost()
	print("presentation_music_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _gains() -> void:
	var monotonic := true
	var previous := MusicEngine.layer_gains(0.0)
	var totals: Array = []
	for i in range(0, 51):
		var p := i / 50.0
		var gains := MusicEngine.layer_gains(p)
		var total := 0.0
		for layer in gains.size():
			monotonic = monotonic and gains[layer] >= previous[layer] - 0.000001
			total += gains[layer]
		totals.append(total)
		previous = gains
	var calm := MusicEngine.layer_gains(0.0)
	var full := MusicEngine.layer_gains(1.0)
	# The bass figure never leaves (Andrew, round 2); the rest of the top waits.
	var space: bool = calm[MusicEngine.SNARE] == 0.0 and calm[MusicEngine.REESE] > 0.0 and calm[MusicEngine.LEAD] == 0.0 and calm[MusicEngine.ARP] == 0.0
	var all_in := true
	for g in full:
		all_in = all_in and g >= 0.99
	_check("gains monotonic", monotonic and totals[50] > totals[0], "%d layers over 51 pressure steps; summed gain %.2f at calm, %.2f at full" % [MusicEngine.CURVES.size(), totals[0], totals[50]])
	_check("calm leaves space", space and all_in, "at pressure 0 snare, lead and arp are silent and the bass figure stays; at 1 every layer is in")

	# The live gains follow a pressure rise without ever stepping back.
	var engine := _playing(0.0)
	engine.set_pressure(1.0)
	var rising := true
	var last := engine.layer_gain(MusicEngine.LEAD)
	for block in 160:
		engine.render(735)
		var now := engine.layer_gain(MusicEngine.LEAD)
		rising = rising and now >= last - 0.000001
		last = now
	_check("live gains rise", rising and last > 0.99, "the lead fades in over the next bar and never dips on the way (reached %.2f)" % last)


func _loudness() -> void:
	var levels: Array = []
	var peaks: Array = []
	for p in [0.0, 0.5, 1.0]:
		var engine := _playing(p)
		engine.render(Harmony.BAR * 2)
		var sum := 0.0
		var top := 0.0
		for frame in engine.out_music:
			sum += frame.x * frame.x + frame.y * frame.y
			top = maxf(top, maxf(absf(frame.x), absf(frame.y)))
		levels.append(sqrt(sum / (2.0 * engine.out_music.size())))
		peaks.append(top)
	var ok: bool = levels[0] < levels[1] and levels[1] < levels[2] and levels[0] > 0.01
	_check("pressure is louder", ok, "rms over two bars: calm %.3f, mid %.3f, full %.3f" % levels)
	_check("no clipping", peaks.max() <= 1.0, "peaks %.2f %.2f %.2f, soft-clipped below full scale" % peaks)


func _stinger_on_the_beat() -> void:
	var engine := MusicEngine.new()
	engine.render(Harmony.BEAT + Harmony.BEAT / 2 + 17)
	var asked := engine.clock
	var start := engine.schedule_stinger("stinger_stage")
	var on_grid := start % Harmony.BEAT == 0 and start > asked and start - asked < Harmony.BEAT
	engine.render(start - engine.clock - 1)
	var silent_before := engine.stinger_starts.is_empty()
	for frame in engine.out_stinger:
		silent_before = silent_before and frame == Vector2.ZERO
	engine.render(256)
	var started: bool = engine.stinger_starts.size() == 1 and engine.stinger_starts[0][1] == start
	var sounding := false
	for frame in engine.out_stinger:
		sounding = sounding or absf(frame.x) > 0.001
	_check("stinger on the beat", on_grid and silent_before and started and sounding,
		"asked at sample %d (%.2f beats), started at %d (beat %d), silent until then, sounding after" % [asked, float(asked) / Harmony.BEAT, start, start / Harmony.BEAT])

	# Asked exactly on a beat nobody has played yet: it starts on that beat.
	var exact := MusicEngine.new()
	exact.render(Harmony.BEAT * 2)
	var now := exact.schedule_stinger("stinger_stage", 0.0, false, 3)
	exact.render(Harmony.BEAT + Harmony.STEP)
	var starts: Array = exact.stinger_starts.map(func(item: Array): return item[1])
	var ok: bool = now == Harmony.BEAT * 2 and starts == [now, now + 2 * Harmony.STEP, now + 4 * Harmony.STEP]
	_check("stage hits", ok, "on-beat request starts at once; stage 3 plays three hits an eighth apart %s" % [starts])


func _lane_and_cadence() -> void:
	var engine := _playing(0.6)
	engine.render(Harmony.BEAT / 3)
	var clear := engine.schedule_stinger("stinger_clear", 0.0, true)
	engine.schedule_cadence(clear)
	var stage := engine.schedule_stinger("stinger_stage", 0.0, true, 2)
	engine.schedule_restart(stage, MusicEngine.PLAY)
	var queued := stage == clear + SfxBank.STINGER_BEATS["stinger_clear"] * Harmony.BEAT
	_check("lane queues", queued, "the stage stinger waits for the clear jingle: clear at beat %d, stage at beat %d" % [clear / Harmony.BEAT, stage / Harmony.BEAT])
	engine.render(clear - engine.clock + Harmony.BAR + Harmony.STEP)
	var in_cadence := engine.bar_origin == clear
	engine.render(stage - engine.clock + Harmony.STEP)
	var restarted := engine.bar_origin == stage and engine.mode == MusicEngine.PLAY
	_check("clear resolves", in_cadence and restarted, "A7b9 to D major from the clear's beat, then the loop restarts on the stage hit")


func _lead() -> void:
	var a := MusicPhrases.make_lead(1)
	var b := MusicPhrases.make_lead(2)
	var in_range := true
	var in_key := true
	for event in a + b:
		in_range = in_range and event[1] >= 61 and event[1] <= 85 and event[0] >= 0 and event[0] < 128
		var bar: Dictionary = Harmony.PROGRESSION[int(event[0]) / 16]
		# Strong beats land on chord tones; approach tones are the only chromatic notes.
		if int(event[0]) % 4 == 0:
			in_key = in_key and posmod(int(event[1]) - Harmony.HOME, 12) in bar["tones"].map(func(t: int): return posmod(t - Harmony.HOME, 12))
	var last: Array = a[a.size() - 1]
	_check("lead varies", a != b and in_range, "consecutive loops differ (%d and %d notes), all inside the sax range" % [a.size(), b.size()])
	_check("lead in key", in_key and last[1] == 73, "strong beats land on chord tones; the phrase ends on C#, the leading tone home")


func _cost() -> void:
	var engine := _playing(1.0)
	engine.render(Harmony.BAR)
	var t := Time.get_ticks_usec()
	for block in 300:
		engine.render(735)
	var ms := (Time.get_ticks_usec() - t) / 1000.0 / (300.0 * 735.0 / Harmony.RATE)
	_check("cpu", ms < 200.0, "%.0f ms of main-thread time per second of full-pressure music (%.1f%% of one core)" % [ms, ms / 10.0])


func _playing(pressure: float) -> MusicEngine:
	var engine := MusicEngine.new()
	engine.schedule_restart(0, MusicEngine.PLAY)
	engine.set_pressure(pressure)
	engine.render(1)
	engine.set_pressure(pressure)
	engine.render(Harmony.BAR - 1)
	return engine


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
