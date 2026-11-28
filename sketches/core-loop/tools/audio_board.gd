extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const VoiceSynth := preload("res://src/presentation/voice_synth.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Rows := preload("res://src/presentation/rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")


const TARGET_LUFS := -14.0
const CEILING := 0.8913
const MAX_LIMIT_DB := 8.0
const DEFAULT_OUT := "../../artifacts/local/v2-primer/audio"

const DEMOS := [
	["01", "sable-leitmotif"], ["02", "rivet-leitmotif"], ["03", "kest-leitmotif"], ["04", "fleet-motif"],
	["05", "reactor-relic"], ["06", "swarm-remnant"], ["07", "mind-quote"], ["08", "stage-theme-escalation"],
	["09", "moss-lounge-and-drop"], ["10", "threat-reel"], ["11", "cc-chain-break-free"], ["12", "moss-babble"],
	["13", "ui-utility-reel"], ["14", "fleet-difficulty-ticks"],
]
const RELEASE := {"sable": "sable_arpeggio", "rivet": "rivet_hihat_roll", "kest": "kest_low_thump", "tarn": "tarn_latch_tear", "tally": "tally_balance_due", "cannon": "cannon_recall"}
const MOSS_LINES := [
	"The hook. Everyone looks at the hook. Shelf's the thing for sale.",
	"No. It'd shear your axle the first bump you took.",
	"Still no. The shelf has three answers. Pick one.",
	"Read the dial. One notch short. Come back heavier.",
	"Don't give me the look. I like the look. Still no.",
	"Try the scrapper past the rapids. Sells lighter. Sells worse.",
]
const MOSS_RELENT := "Fine. You're heavy enough. Don't come back lighter."


class Take:
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	var engine: MusicEngine
	var band_at := 0
	var cursor := 0
	var music_gain := db_to_linear(Audio.BUSES["Music"])
	var sfx_gain := db_to_linear(Audio.BUSES["SFX"])
	var ui_gain := db_to_linear(Audio.BUSES["UI"])
	var cues: Array = []

	func _grow(n: int) -> void:
		if left.size() < n:
			var from := left.size()
			left.resize(n)
			right.resize(n)
			for i in range(from, n):
				left[i] = 0.0
				right[i] = 0.0

	func band(theme: int, pressure: float, at := 0) -> MusicEngine:
		engine = MusicEngine.new()
		engine.schedule_restart(0, MusicEngine.PLAY, theme)
		engine.set_pressure(pressure)
		band_at = at
		cursor = at
		return engine

	func to(sample: int) -> void:
		if engine == null:
			return
		while cursor < sample:
			var n := mini(2048, sample - cursor)
			engine.render(n)
			_grow(cursor + n)
			var music := engine.out_music
			var sting := engine.out_stinger
			for i in n:
				left[cursor + i] += music[i].x * music_gain + sting[i].x * sfx_gain
				right[cursor + i] += music[i].y * music_gain + sting[i].y * sfx_gain
			cursor += n

	func bar(k: float) -> int:
		return band_at + int(round(k * Harmony.BAR))

	func sec(s: float) -> int:
		return int(round(s * Harmony.RATE))

	func add(buf: PackedFloat32Array, at: int, gain: float, pan := 0.0) -> void:
		_grow(at + buf.size())
		var angle := (clampf(pan, -1.0, 1.0) + 1.0) * PI * 0.25
		var gl := cos(angle) * 1.41 * gain
		var gr := sin(angle) * 1.41 * gain
		for i in buf.size():
			left[at + i] += buf[i] * gl
			right[at + i] += buf[i] * gr

	func play(id: String, at: int, priority := 1, db := 0.0, shift := 0, pan := 0.0, bus := "SFX", ducks := true) -> void:
		to(at)
		var buf := SfxBank.samples_at(id, Harmony.STEP, shift)
		var gain := db_to_linear(SfxBank.trim_db(id) + Audio.PRIORITY_DB[priority] + db) * (ui_gain if bus == "UI" else sfx_gain)
		add(buf, at, gain, pan)
		if engine != null and ducks:
			if priority >= 2:
				engine.duck(0.55, 0.35)
			if id in Audio.DANGER_SOUNDS:
				engine.duck_bass(0.3, 0.45)
		cues.append([at, id])

	func on_beat(id: String, at: int, db := 0.0) -> int:
		to(at)
		var start := engine.schedule_stinger(id, db)
		var hold := float(start - engine.clock + SfxBank.STINGER_BEATS.get(id, 1) * Harmony.BEAT) / Harmony.RATE
		engine.duck(0.6, hold)
		if id in Audio.DANGER_SOUNDS:
			engine.duck_bass(0.3, hold)
		cues.append([band_at + start, id])
		return band_at + start

	func hold(kind: String, from: int, until: int, strain := 0.0) -> void:
		to(from)
		var id := "hold_" + kind
		var gain := db_to_linear(SfxBank.trim_db(id) + Audio.PRIORITY_DB[2]) * sfx_gain
		add(SfxBank.hold(kind, until - from, strain), from, gain, 0.0)
		cues.append([from, id])

	func finish(length: int) -> void:
		to(length)
		_grow(length)
		left.resize(length)
		right.resize(length)
		var fade := mini(length, Harmony.RATE / 20)
		for i in fade:
			var g := float(i) / fade
			left[length - 1 - i] *= g
			right[length - 1 - i] *= g


static func render_demo(number: String) -> Take:
	match number:
		"01":
			return _class_demo("sable")
		"02":
			return _class_demo("rivet")
		"03":
			return _class_demo("kest")
		"04":
			return _fleet_demo()
		"05":
			return _reactor_demo()
		"06":
			return _swarm_demo()
		"07":
			return _mind_demo()
		"08":
			return _stage_theme()
		"09":
			return _lounge_demo()
		"10":
			return _threat_reel()
		"11":
			return _cc_chain()
		"12":
			return _babble_demo()
		"13":
			return _ui_reel()
		"14":
			return _fleet_ticks()
	return null


static func _class_demo(id: String) -> Take:
	var t := Take.new()
	var row := Harmony.motif(id)
	var bare := SfxBank.motif_score(id, 0, row["voice"], 0.8)
	if row.get("roll", false):
		for step in 4:
			bare.append([step, 0, 1, "hat", 0.5])
	if row.get("boom", false):
		var last: Array = row["cells"][row["cells"].size() - 1]
		bare.append([int(last[0]), int(last[1]) - 12, 6, "sub808", 0.85])
	var tune := Synth.normalize(Synth.render_score(bare, 0.8), 0.9)
	var gain := db_to_linear(SfxBank.trim_db(RELEASE[id])) * t.sfx_gain
	t.add(tune, t.sec(0.3), gain)
	t.add(tune, t.sec(0.3) + Harmony.BAR, gain)
	t.play(RELEASE[id], t.sec(0.3) + 2 * Harmony.BAR, 2)
	t.band(0, 0.45, t.sec(0.3) + 3 * Harmony.BAR + Harmony.BEAT * 2)
	t.play(id + "_ready", t.bar(1.0) + t.sec(0.05), 1)
	t.play(RELEASE[id], t.bar(2.6), 2)
	t.play(id + "_ready", t.bar(4.3), 1)
	t.play(RELEASE[id], t.bar(5.45), 2)
	t.play(RELEASE[id], t.bar(7.0), 2)
	t.finish(t.bar(8.6))
	return t


static func _fleet_demo() -> Take:
	var t := Take.new()
	t.play("fleet_motif", t.sec(0.3), 2)
	t.play("fleet_motif", t.sec(0.3) + Harmony.BAR, 2)
	t.band(0, 0.45, t.sec(0.3) + 2 * Harmony.BAR + Harmony.BEAT * 2)
	for k in [1.2, 3.2, 5.2]:
		t.play("callout_chime", t.bar(k), 3, 0.0, 0, 0.0, "UI")
		t.on_beat("fleet_motif", t.bar(k) + t.sec(0.1))
	t.finish(t.bar(7.0))
	return t


static func _reactor_demo() -> Take:
	var t := Take.new()
	var engine := t.band(0, 0.5)
	t.to(t.bar(1.8))
	engine.set_reactor_pedal(true)
	var start := t.bar(2.0)
	var blow := t.bar(6.0)
	var at := start
	while at < blow - t.sec(0.03):
		var charge := float(at - start) / (blow - start)
		t.play("reactor_tick", at, 2, lerpf(-6.0, 0.0, charge), 0, lerpf(-0.3, 0.3, fposmod(charge * 7.0, 1.0)), "SFX", at == start)
		at += t.sec(lerpf(0.34, 0.035, pow(charge, 0.7)))
	t.play("reactor_erupt", blow, 2)
	engine.set_reactor_pedal(false)
	t.finish(t.bar(8.3))
	return t


static func _swarm_demo() -> Take:
	var t := Take.new()
	t.band(0, 0.35)
	for k in 2:
		var at := t.bar(1.0 + 3.0 * k)
		t.play("swarm_buzz", at, 2, 0.0, 0, -0.2)
		t.play("swarm_buzz", at + t.sec(0.55), 2, 0.0, 0, 0.2)
		t.play("swarm_lock", at + t.sec(1.1), 2)
		t.play("swarm_scatter", at + t.sec(2.75), 2)
	t.finish(t.bar(7.4))
	return t


static func _mind_demo() -> Take:
	var t := Take.new()
	t.band(0, 0.35)
	for k in Harmony.CLASS_MOTIFS.size():
		var id: String = Harmony.CLASS_MOTIFS[k]
		t.play(RELEASE[id], t.bar(0.9 + 2.3 * k), 2)
		t.play("mind_" + id, t.bar(1.9 + 2.3 * k), 2)
	t.finish(t.bar(1.9 + 2.3 * (Harmony.CLASS_MOTIFS.size() - 1) + 2.4))
	return t


static func _stage_theme() -> Take:
	var t := Take.new()
	var engine := t.band(0, 0.55)
	engine.set_class_motif("sable")
	t.to(t.bar(3.5))
	engine.set_pressure(1.0)
	for bar in range(6, 24):
		t.to(t.bar(bar - 0.1))
		engine.escalate(minf(0.6, (bar - 6) / 8.0), false)
	t.finish(t.bar(24.3))
	return t


static func _lounge_demo() -> Take:
	var t := Take.new()
	var engine := t.band(0, 0.6)
	t.play(Rows.sound("mounted"), t.bar(1.55), Rows.priority("mounted"))
	engine.set_lounge(true)
	t.play("shop_bell", t.bar(6.6), 2)
	var launch := t.bar(9.7)
	t.play("sable_arpeggio", launch, 2, 0.0, 0)
	t.play(Rows.sound("launched"), launch, Rows.priority("launched"))
	engine.start_build(Audio.LAUNCH_BUILD_SECONDS, true)
	var touchdown := launch + t.sec(Audio.LAUNCH_BUILD_SECONDS)
	t.play(Rows.sound("landed"), touchdown, Rows.priority("landed"))
	engine.drop_now(4, 0.85, {}, 0)
	t.finish(t.bar(16.2))
	return t


static func _threat_reel() -> Take:
	var t := Take.new()
	t.band(0, 0.5)
	var kinds := ["threat_instant", "threat_wave", "threat_projectile", "threat_lane"]
	for k in kinds.size():
		var row: Dictionary = EventKinds.THREAT_ROWS[kinds[k]]
		t.play(row["sound"], t.sec(1.0 + 2.25 * k), int(row["priority"]))
	t.finish(t.sec(10.9))
	return t


static func _cc_chain() -> Take:
	var t := Take.new()
	var engine := t.band(0, 0.6)
	var a := t.bar(1.0)
	t.play("threat_tick", a, 2)
	t.play("threat_whistle", a + t.sec(0.15), 2)
	var free := a + t.sec(2.45)
	t.hold("pit", a + t.sec(0.75), free)
	engine.duck_bass(0.3, 30.0)
	t.hold("bola", a + t.sec(1.05), free)
	engine.duck_bass(0.15, 30.0)
	t.hold("tether", a + t.sec(1.35), free, 1.0)
	t.hold("net", a + t.sec(1.65), free)
	t.hold("riser", a + t.sec(1.85), free)
	t.to(free)
	engine.free_bass()
	t.play("sable_break", free, 2)
	t.play("boost_whoosh", free, 1)
	var b := t.bar(5.0)
	t.play("threat_tick", b, 2)
	t.play("threat_whistle", b + t.sec(0.15), 2)
	var tenacity := b + t.sec(0.75 + 1.8)
	t.hold("pit", b + t.sec(0.75), tenacity)
	engine.duck_bass(0.3, 30.0)
	t.hold("bola", b + t.sec(1.05), tenacity)
	engine.duck_bass(0.15, 30.0)
	t.hold("riser", b + t.sec(1.95), tenacity)
	t.to(tenacity)
	engine.free_bass()
	t.play("tenacity_choke", tenacity, 2)
	t.play("sable_break", tenacity + t.sec(0.06), 2)
	t.finish(t.bar(8.8))
	return t


static func _babble_demo() -> Take:
	var t := Take.new()
	var engine := t.band(0, 0.0)
	engine.set_lounge(true)
	t.play("bench_clank", t.sec(0.6), 1)
	var at := t.sec(1.4)
	var gain := db_to_linear(VoiceSynth.trim_db("babble")) * t.sfx_gain
	for beat in 7:
		t.play("sable_ready", at, 1)
		var line: PackedFloat32Array
		if beat < 6:
			line = VoiceSynth.babble(MOSS_LINES[beat], beat + 1)
		else:
			line = VoiceSynth.babble(MOSS_RELENT, VoiceSynth.BABBLE_RELENT)
		t.to(at + t.sec(0.3))
		t.add(line, at + t.sec(0.3), gain, 0.15)
		at += t.sec(0.3) + line.size() + t.sec(0.7)
	t.play("shop_bell", at - t.sec(0.3), 2)
	t.finish(at + t.sec(1.4))
	return t


static func _ui_reel() -> Take:
	var t := Take.new()
	t.band(0, 0.2)
	var at := t.sec(0.8)
	for id in Harmony.CLASS_MOTIFS:
		t.play(id + "_ready", at, 1)
		at += t.sec(1.0)
	t.play("callout_chime", at, 3, 0.0, 0, 0.0, "UI")
	at += t.sec(1.2)
	t.play("shop_bell", at, 2)
	at += t.sec(1.3)
	t.play("bench_clank", at, 1)
	at += t.sec(1.0)
	var start := t.on_beat(Rows.sound("milestone_won"), at)
	t.finish(start + t.sec(2.6))
	return t


static func _fleet_ticks() -> Take:
	var t := Take.new()
	var engine := t.band(0, 0.6)
	for tick in 3:
		var at := t.bar(2.5 + 3.0 * tick)
		t.on_beat(Rows.sound("threat_rose"), at)
		t.to(at)
		engine.set_fleet_ticks(tick + 1)
	t.finish(t.bar(12.2))
	return t


static func loudness(left: PackedFloat32Array, right: PackedFloat32Array) -> float:
	var zl := _k_squares(left)
	var zr := _k_squares(right)
	var n := left.size()
	var block := int(0.4 * Harmony.RATE)
	var hop := int(0.1 * Harmony.RATE)
	var sums := PackedFloat64Array()
	sums.resize(n + 1)
	sums[0] = 0.0
	for i in n:
		sums[i + 1] = sums[i] + zl[i] + zr[i]
	var blocks := PackedFloat64Array()
	var start := 0
	while start + block <= n:
		blocks.append((sums[start + block] - sums[start]) / block)
		start += hop
	if blocks.is_empty():
		blocks.append(sums[n] / maxi(n, 1))
	var gated := PackedFloat64Array()
	for z in blocks:
		if _lufs(z) > -70.0:
			gated.append(z)
	if gated.is_empty():
		return -INF
	var relative := _lufs(_mean(gated)) - 10.0
	var kept := PackedFloat64Array()
	for z in gated:
		if _lufs(z) > relative:
			kept.append(z)
	return _lufs(_mean(kept))


static func _lufs(z: float) -> float:
	return -0.691 + 10.0 * log(maxf(z, 1e-20)) / log(10.0)


static func _mean(values: PackedFloat64Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxi(values.size(), 1)


static func _k_squares(x: PackedFloat32Array) -> PackedFloat64Array:
	var fs := float(Harmony.RATE)
	var k := tan(PI * 1681.974450955533 / fs)
	var q := 0.7071752369554196
	var vh := pow(10.0, 3.999843853973347 / 20.0)
	var vb := pow(vh, 0.4996667741545416)
	var a0 := 1.0 + k / q + k * k
	var sb0 := (vh + vb * k / q + k * k) / a0
	var sb1 := 2.0 * (k * k - vh) / a0
	var sb2 := (vh - vb * k / q + k * k) / a0
	var sa1 := 2.0 * (k * k - 1.0) / a0
	var sa2 := (1.0 - k / q + k * k) / a0
	k = tan(PI * 38.13547087602444 / fs)
	q = 0.5003270373238773
	a0 = 1.0 + k / q + k * k
	var ha1 := 2.0 * (k * k - 1.0) / a0
	var ha2 := (1.0 - k / q + k * k) / a0
	var out := PackedFloat64Array()
	out.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var u1 := 0.0
	var u2 := 0.0
	var w1 := 0.0
	var w2 := 0.0
	for i in x.size():
		var x0 := x[i]
		var y0 := sb0 * x0 + sb1 * x1 + sb2 * x2 - sa1 * y1 - sa2 * y2
		x2 = x1
		x1 = x0
		y2 = y1
		y1 = y0
		var w0 := y0 - 2.0 * u1 + u2 - ha1 * w1 - ha2 * w2
		u2 = u1
		u1 = y0
		w2 = w1
		w1 = w0
		out[i] = w0 * w0
	return out


static func peak(left: PackedFloat32Array, right: PackedFloat32Array) -> float:
	var top := 0.0
	for i in left.size():
		top = maxf(top, maxf(absf(left[i]), absf(right[i])))
	return top


static func master(take: Take) -> Dictionary:
	var before := loudness(take.left, take.right)
	var gain_db := TARGET_LUFS - before if is_finite(before) else 0.0
	var top := peak(take.left, take.right) * db_to_linear(gain_db)
	var over := linear_to_db(top / CEILING)
	if over > MAX_LIMIT_DB:
		gain_db -= over - MAX_LIMIT_DB
	var g := db_to_linear(gain_db)
	for i in take.left.size():
		take.left[i] *= g
		take.right[i] *= g
	var limited := _limit(take.left, take.right)
	return {"lufs": loudness(take.left, take.right), "peak_db": linear_to_db(peak(take.left, take.right)),
		"limit_db": limited, "gain_db": gain_db, "seconds": float(take.left.size()) / Harmony.RATE}


static func _limit(left: PackedFloat32Array, right: PackedFloat32Array) -> float:
	var n := left.size()
	var window := int(0.0015 * Harmony.RATE)
	var need := PackedFloat32Array()
	need.resize(n)
	for i in n:
		var a := maxf(absf(left[i]), absf(right[i]))
		need[i] = minf(1.0, CEILING / maxf(a, 1e-9))
	var held := _window_min(need, window)
	var release := 1.0 - exp(-1.0 / (0.08 * Harmony.RATE))
	var level := 1.0
	for j in n:
		level = minf(held[j], level + (1.0 - level) * release)
		held[j] = level
	var deepest := 1.0
	var running := 0.0
	for i in n:
		running += held[i]
		if i >= window:
			running -= held[i - window]
		var g := minf(running / mini(i + 1, window), need[i])
		deepest = minf(deepest, g)
		left[i] *= g
		right[i] *= g
	return -linear_to_db(deepest)


static func _window_min(a: PackedFloat32Array, w: int) -> PackedFloat32Array:
	var n := a.size()
	var pre := a.duplicate()
	var suf := a.duplicate()
	for i in n:
		if i % w != 0:
			pre[i] = minf(pre[i], pre[i - 1])
	for i in range(n - 2, -1, -1):
		if (i + 1) % w != 0:
			suf[i] = minf(suf[i], suf[i + 1])
	var out := PackedFloat32Array()
	out.resize(n)
	for j in n:
		out[j] = minf(suf[j], pre[mini(j + w - 1, n - 1)])
	return out


static func to_wav(take: Take) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(take.left.size() * 4)
	for i in take.left.size():
		bytes.encode_s16(i * 4, int(round(clampf(take.left[i], -1.0, 1.0) * 32767.0)))
		bytes.encode_s16(i * 4 + 2, int(round(clampf(take.right[i], -1.0, 1.0) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = Harmony.RATE
	wav.stereo = true
	wav.data = bytes
	return wav


static func default_out() -> String:
	return ProjectSettings.globalize_path("res://").path_join(DEFAULT_OUT).simplify_path()


static func write_all(out_dir: String, only: Array = []) -> Array:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var report: Array = []
	for demo in DEMOS:
		if not only.is_empty() and not demo[0] in only:
			continue
		var take := render_demo(demo[0])
		var stats := master(take)
		var name := "%s-%s.wav" % [demo[0], demo[1]]
		var err := to_wav(take).save_to_wav(out_dir.path_join(name))
		report.append([name, stats, err])
	return report


func _initialize() -> void:
	var out := default_out()
	var only: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(",", false))
	var failed := 0
	var started := Time.get_ticks_msec()
	for row in write_all(out, only):
		var stats: Dictionary = row[1]
		if int(row[2]) != OK:
			failed += 1
		print("%s  %5.1f s  %6.1f LUFS  peak %5.1f dBFS  limiter %4.1f dB  %s" % [row[0], stats["seconds"], stats["lufs"],
			stats["peak_db"], stats["limit_db"], "written" if int(row[2]) == OK else "FAILED %d" % row[2]])
	print("audio_board: %s to %s in %.1f s" % ["done" if failed == 0 else "FAIL (%d)" % failed, out, (Time.get_ticks_msec() - started) / 1000.0])
	quit(0 if failed == 0 else 1)
