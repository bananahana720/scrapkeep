extends SceneTree

const Board := preload("res://tools/audio_board.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Rows := preload("res://src/presentation/rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# Core-loop v3 dense-fight measurement: 16 bars of Spillway in four band states under a
# synthetic cue stream admitted by audio.gd's gap and voice rules, rendered as band only,
# cues only and their sum. Reports voices, loudness, threat audibility over the band and
# the sub-120 Hz share with and without the bass duck. A measurement, not game code.
# The engine cannot reach the sinister break inside 16 bars after the Warden drop
# (ENGINE_NOTES), so the measured S4 forces the break section at bar 13 through engine
# fields; a third run with public calls only (engine_path_probe) records where
# escalate(0.8) actually lands it.
#
#   godot --headless --path sketches/core-loop --script res://tools/audio_density_sim.gd
# Output: <repo>/artifacts/local/v3-audio (density.json and three mastered WAVs).

const OUT := "../../artifacts/local/v3-audio"
const BARS := 16
const SEED := 172
const LEAD := 64
const BLOCK := 512
const WINDOW := 4410
const GRID := 441
const STATES := [
	{"name": "S1", "label": "lap, mid snowball", "from": 0},
	{"name": "S2", "label": "lap, full snowball", "from": 4},
	{"name": "S3", "label": "Warden club drop, full snowball", "from": 8},
	{"name": "S4", "label": "sinister break under a dense fight", "from": 12},
]
# [sound, the row kind whose priority it plays at, period s, phase s, handler dB,
# handler pitch, the combo ladder's top rung or -1]. The dB and pitch are what audio.gd's
# handler passes: _on_scrap +0.6 dB (one scrap) on the pentatonic ladder to rung 9,
# _on_kill on the ladder to rung 7, _on_struck's non-contact hit at -5 dB and x1.15.
# _on_shot's per-weapon pitch and random cents are left out (1.0).
const STREAMS := [
	["weapon_zap", "shot_fired", 0.045, 0.0, 0.0, 1.0, -1],
	["scrap_tick", "scrap_collected", 0.125, 0.013, 0.6, 1.0, 9],
	["kill_pop", "enemy_killed", 0.25, 0.071, 0.0, 1.0, 7],
	["hit_thwack", "enemy_struck", 1.0 / 6.0, 0.029, -5.0, 1.15, -1],
	["enemy_arrive", "enemy_spawned", 2.0, 0.5, 0.0, 1.0, -1],
	["threat_tick", "threat_instant", 2.0, 1.5, 0.0, 1.0, -1],
]
const THREATS := ["threat_tick", "threat_up", "enemy_arrive"]
# Two stacked holds per held state, each 2 bars: the pit on the bar line, the bola from
# beat 3, cut at the state's end. S2 is bars 4-7 and S4 bars 12-15.
const HOLD_BARS := [4, 6, 12, 14]
# The womp at slam weight 0.75 (audio._on_slammed: lerp(-12, 0, weight) dB, pitched
# ratio(lerp(0, -5, weight)) semitones).
const WOMP_DB := -3.0
const WOMP_SEMITONES := -3.75
const BASS_HZ := 120.0
# Bars the engine-path probe renders past the window, to see where escalate lands.
const PROBE_EXTRA := 3
# What the engine does with the contract's order, cited against music_engine.gd.
const ENGINE_NOTES := [
	"escalate() returns at once while a drop plays (music_engine.gd:597). The S3 drop runs bars 9-12, so escalate(0.8) before S3 ends is a no-op.",
	"The drop action clears the bar queue and resets lift and break (1172, 1176) and sets the Warden section to drop (1194-1195). A drop with then={} ends without moving the section (995-1004), so bars 13+ play _trigger_house with its drop flag (1024-1029, 1561).",
	"From the first bar line after the drop, escalate(0.8) queues the lift two bar lines out and the break two after that (599-622, _queue 724-728): see engine_path_probe for where they land.",
	"Fleet layers play only on the level track (1018): fleet ticks 3 sound through the pivot bar 8 and are silent on the Warden track from bar 9.",
	"The reactor pedal moves the held sub (_start_sub 1817-1823). _trigger_drop (1642-1689) starts no sub, so the pedal is silent in the drop bars 9-12; house (1584) and break (1626) carry it.",
	"begin_boss(warden) from the level at 172 plays the pivot bar (three half-note-triplet hits and the pulse, 558-568) and switches to the Warden at the 129 step on the next bar line (569).",
	"set_heft_lift queues for the next bar line (660-665); each step adds HEFT_STEP 0.12 intensity (1314).",
]


class Sim:
	var engine: MusicEngine
	var duck_bass_on := true
	var band = Board.Take.new()
	var sting = Board.Take.new()
	var offset := 0
	var cursor := 0
	var length := 0
	var blocks: Array = []
	var bar_lines: Array = []
	var bars: Array = []
	var voices: Array = []
	var live: Array = []
	var attempts: Array = []
	var last_ms := {}
	var threats: Array = []
	var notes: Array = []
	# True: S4's break is forced into the engine at bar 13 (the measured take). False:
	# public calls only (the engine-path probe).
	var forced := true
	var pitched := {}

	func _init(bass_duck: bool, force_break := true) -> void:
		duck_bass_on = bass_duck
		forced = force_break
		engine = MusicEngine.new()
		engine._rng.seed = SEED
		engine.schedule_restart(0, MusicEngine.PLAY, 0)
		engine.set_pressure(0.6)
		_discard(Harmony.BAR - LEAD)
		engine.set_pressure(0.6)
		engine.set_heft_lift(1)
		engine.set_class_motif("rivet")
		engine.set_fleet_ticks(1)
		_discard(Harmony.BAR)
		offset = engine.clock

	func _discard(until: int) -> void:
		while engine.clock < until:
			engine.render(mini(BLOCK, until - engine.clock))

	func to(t: int) -> void:
		while cursor < t:
			var n := mini(BLOCK, t - cursor)
			engine.render(n)
			band._grow(cursor + n)
			sting._grow(cursor + n)
			var music: PackedVector2Array = engine.out_music
			var st: PackedVector2Array = engine.out_stinger
			for i in n:
				band.left[cursor + i] = music[i].x * band.music_gain
				band.right[cursor + i] = music[i].y * band.music_gain
				sting.left[cursor + i] = st[i].x * sting.sfx_gain
				sting.right[cursor + i] = st[i].y * sting.sfx_gain
			var band_voices := 0
			for v in engine._voices:
				if not v.to_stinger:
					band_voices += 1
			blocks.append([cursor, n, engine.voice_count(), band_voices])
			cursor += n

	func sec(s: float) -> int:
		return int(round(s * Harmony.RATE))

	# One bar-line row: the engine's state just after the line.
	func _bar_row(k: int, line: int) -> Dictionary:
		return {"bar": k, "t": float(line) / Harmony.RATE, "bpm": 60.0 * Harmony.RATE / engine.beat_len(), "track": engine.track,
			"section": engine.section, "key": engine.key, "heft": engine.heft_lift, "fleet": engine.fleet_ticks,
			"pedal": engine.reactor_pedal, "drop": engine.in_drop(), "intensity": engine._intensity, "cutoff_hz": engine._cutoff}

	# The band alone past the window, recording each bar line (no cues, no measurement).
	func extend(extra: int) -> void:
		var line := length
		for j in extra:
			to(line)
			to(line + 1)
			bars.append(_bar_row(BARS + j, line))
			line += engine.bar_len()

	func run() -> void:
		var next := {}
		var fired := {}
		for s in STREAMS:
			next[s[0]] = float(s[3])
			fired[s[0]] = 0
		var line := 0
		for k in BARS:
			if k > 0:
				to(line - LEAD)
				_before_line(k)
			to(line)
			_on_line(k)
			to(line + 1)
			_after_line(k)
			var bl: int = engine.bar_len()
			var bt: int = engine.beat_len()
			bar_lines.append(line)
			bars.append(_bar_row(k, line))
			var end := line + bl
			var events: Array = []
			for s in STREAMS:
				while sec(next[s[0]]) < end:
					# The combo climbs on every fact inside its window, admitted or not.
					var pitch: float = s[5]
					if int(s[6]) >= 0:
						pitch *= Harmony.ratio(Harmony.pentatonic_step(mini(int(fired[s[0]]), int(s[6]))))
					events.append([sec(next[s[0]]), events.size(), "cue", s[0], row_priority(s[1]), float(s[4]), pitch])
					fired[s[0]] = int(fired[s[0]]) + 1
					next[s[0]] += float(s[2])
			if k in HOLD_BARS:
				var state_end := line + (4 - k % 4) * bl
				events.append([line, events.size(), "hold", "pit", line + 2 * bl])
				events.append([line + 2 * bt, events.size(), "hold", "bola", mini(line + 2 * bt + 2 * bl, state_end)])
			events.append([line + int(1.5 * bt), events.size(), "womp", "womp", Rows.priority("slammed")])
			events.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
			for e in events:
				to(e[0])
				match e[2]:
					"cue":
						play(e[3], e[0], e[4], e[5], e[6])
					"hold":
						hold(e[3], e[0], e[4])
					"womp":
						play("womp", e[0], e[4], WOMP_DB, Harmony.ratio(WOMP_SEMITONES))
			line = end
		to(line)
		bar_lines.append(line)
		length = line

	func _before_line(k: int) -> void:
		match k:
			4:
				engine.set_pressure(1.0)
				engine.set_heft_lift(2)
				engine.set_fleet_ticks(3)
				engine.set_reactor_pedal(true)
			8:
				var at: int = engine.begin_boss("warden")
				notes.append("begin_boss(warden) before bar 8: music begins at t=%.3f s" % [float(at - offset) / Harmony.RATE])
			12:
				# The contract's call: the sinister break, before S3 ends.
				var before: int = engine.events_log.size()
				engine.escalate(0.8)
				notes.append("escalate(0.8) %d samples before the bar 12 line (S3's end), inside the drop: %d events logged, in_drop=%s, build_level %.2f" % [
					LEAD, engine.events_log.size() - before, engine.in_drop(), engine.build_level()])
			13:
				if forced:
					# What escalate's break would set (music_engine.gd 612-622): the break
					# section in key +1 (unlifted), the lead down. Written into the engine
					# because no public call reaches it inside the window.
					engine.section = "break"
					engine._set_key(1)
					engine._lead_octave = 0
					notes.append("FORCED: %d samples before the bar 13 line, section set to break in key +1 through engine fields (not a public call)" % LEAD)

	func _on_line(k: int) -> void:
		if k % 4 == 0:
			on_beat_threat()
		if k == 9:
			var at: int = engine.drop_now(4, 1.0, {}, -1)
			notes.append("drop_now(4, 1.0) at the bar 9 line: lands t=%.3f s, clock t=%.3f s, step %d" % [float(at - offset) / Harmony.RATE,
				float(engine.clock - offset) / Harmony.RATE, engine.step_len])

	func _after_line(k: int) -> void:
		if k == 13:
			var before: int = engine.events_log.size()
			if forced:
				# The break is in place; mark it so escalate adds only the build riser.
				engine._warden_lifted = true
				engine._warden_broken = true
			engine.escalate(0.8)
			var added: Array = engine.events_log.slice(before).map(func(e): return str(e[0]))
			notes.append("escalate(0.8) 1 sample after the bar 13 line, the drop over: events %s, build level %.2f%s" % [
				added, engine.build_level(), " (lift and break flags pre-set by the forcing)" if forced else ""])

	# A threat warns at its threat row's priority (audio._warn_threat, which offsets the
	# dB from Rows.priority and ducks the band itself), within 20 m so no distance cut.
	# Everything else plays at its event row's priority.
	static func row_priority(kind: String) -> int:
		if EventKinds.THREAT_ROWS.has(kind):
			return int(EventKinds.THREAT_ROWS[kind]["priority"])
		return Rows.priority(kind)

	# The cue at a playback pitch, resampled as the polyphonic player does, cached.
	func _pitched(id: String, pitch: float) -> PackedFloat32Array:
		var buf := SfxBank.samples_at(id, Harmony.STEP, 0)
		if absf(pitch - 1.0) < 1e-4:
			return buf
		var key := "%s|%.5f" % [id, pitch]
		if not pitched.has(key):
			pitched[key] = resample(buf, pitch)
		return pitched[key]

	# audio.play: the gap, then _start's voice limit (steal the oldest) and the polyphony.
	# A keyed sound follows the live key by pitch (audio.play multiplies ratio(key)).
	func play(id: String, t: int, priority: int, db := 0.0, pitch := 1.0) -> void:
		if not _admit(id, t):
			return
		if id in Audio.KEYED_SOUNDS:
			pitch *= Harmony.ratio(engine.key)
		var started := _start(id, t, _pitched(id, pitch), SfxBank.trim_db(id) + Audio.PRIORITY_DB[priority] + db)
		if priority >= 2:
			engine.duck(0.55, 0.35)
		if id in Audio.DANGER_SOUNDS and duck_bass_on:
			engine.duck_bass(0.3, 0.45)
		if id in THREATS and started:
			threats.append([t, id])

	# A hold as the game starts it: play("hold_started") with the hold's sound, row priority.
	# The game loops the hold at the key's pitch; here the loop is baked long enough that
	# the pitched copy spans the hold.
	func hold(kind: String, from: int, until: int) -> void:
		var id := "hold_" + kind
		if not _admit(id, from):
			return
		var priority := Rows.priority("hold_started")
		var pitch := Harmony.ratio(engine.key) if id in Audio.KEYED_SOUNDS else 1.0
		var buf := SfxBank.hold(kind, int(ceil((until - from) * pitch)) + 1)
		if absf(pitch - 1.0) >= 1e-4:
			buf = resample(buf, pitch)
		_start(id, from, buf.slice(0, until - from), SfxBank.trim_db(id) + Audio.PRIORITY_DB[priority])
		if priority >= 2:
			engine.duck(0.55, 0.35)
		if id in Audio.DANGER_SOUNDS and duck_bass_on:
			engine.duck_bass(0.3, 0.45)

	# audio.on_beat("threat_rose") at tier 0: the band's stinger lane, ducked to its end.
	func on_beat_threat() -> void:
		var start: int = engine.schedule_stinger("threat_up", 0.0)
		var hold_s := float(start - engine.clock + SfxBank.STINGER_BEATS["threat_up"] * Harmony.BEAT) / Harmony.RATE
		engine.duck(0.6, hold_s)
		if duck_bass_on:
			engine.duck_bass(0.3, hold_s)
		threats.append([start - offset, "threat_up"])
		attempts.append([start - offset, "threat_up", "admitted"])

	func _admit(id: String, t: int) -> bool:
		var ms := int(floor(t * 1000.0 / Harmony.RATE))
		if ms - int(last_ms.get(id, -100000)) < int(Audio.MIN_GAP_MS.get(id, 0)):
			attempts.append([t, id, "gap"])
			return false
		last_ms[id] = ms
		return true

	func _start(id: String, t: int, buf: PackedFloat32Array, db: float) -> bool:
		live = live.filter(func(v): return v["end"] > t)
		var mine := live.filter(func(v): return v["id"] == id)
		if mine.size() >= int(Audio.VOICE_LIMIT.get(id, 3)):
			var oldest: Dictionary = mine[0]
			oldest["end"] = t
			live.erase(oldest)
			attempts.append([t, id, "stolen"])
		if live.size() >= Audio.POLYPHONY:
			attempts.append([t, id, "poly"])
			return false
		var v := {"id": id, "start": t, "end": t + buf.size(), "buf": buf, "gain": db_to_linear(db) * band.sfx_gain}
		voices.append(v)
		live.append(v)
		attempts.append([t, id, "admitted"])
		return true

	# Linear-interpolated playback at a pitch ratio (shorter when higher), as pitch_scale plays it.
	static func resample(buf: PackedFloat32Array, pitch: float) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		if buf.size() < 2:
			return buf
		out.resize(int(floor((buf.size() - 1) / pitch)) + 1)
		for i in out.size():
			var x := i * pitch
			var j := mini(int(x), buf.size() - 2)
			var f := x - j
			out[i] = buf[j] * (1.0 - f) + buf[j + 1] * f
		return out


static func cut_add(take, v: Dictionary) -> void:
	var buf: PackedFloat32Array = v["buf"]
	var n: int = v["end"] - v["start"]
	if n < buf.size():
		buf = buf.slice(0, n)
		var fade := mini(64, n)
		for i in fade:
			buf[n - 1 - i] *= float(i) / fade
	take.add(buf, v["start"], v["gain"], 0.0)


static func fit(take, n: int) -> void:
	take._grow(n)
	take.left.resize(n)
	take.right.resize(n)


static func summed(a, b):
	var t = Board.Take.new()
	fit(t, a.left.size())
	for i in a.left.size():
		t.left[i] = a.left[i] + b.left[i]
		t.right[i] = a.right[i] + b.right[i]
	return t


static func k_prefix(take) -> PackedFloat64Array:
	var zl := Board._k_squares(take.left)
	var zr := Board._k_squares(take.right)
	var p := PackedFloat64Array()
	p.resize(zl.size() + 1)
	p[0] = 0.0
	for i in zl.size():
		p[i + 1] = p[i] + zl[i] + zr[i]
	return p


static func short_term(p: PackedFloat64Array, at: int) -> float:
	var b := mini(at + int(0.4 * Harmony.RATE), p.size() - 1)
	return Board._lufs((p[b] - p[at]) / maxi(b - at, 1))


static func low_share(take, a: int, b: int) -> float:
	var k := 1.0 - exp(-TAU * BASS_HZ / Harmony.RATE)
	var yl := 0.0
	var yr := 0.0
	var low := 0.0
	var all := 0.0
	for i in b:
		yl += k * (take.left[i] - yl)
		yr += k * (take.right[i] - yr)
		if i >= a:
			low += yl * yl + yr * yr
			all += take.left[i] * take.left[i] + take.right[i] * take.right[i]
	return low / maxf(all, 1e-20)


static func stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	var median: float = sorted[mid] if sorted.size() % 2 == 1 else (sorted[mid - 1] + sorted[mid]) * 0.5
	return {"n": sorted.size(), "min": sorted[0], "median": median, "max": sorted[sorted.size() - 1]}


static func section(sim: Sim, duckless: Sim, takes: Dictionary, prefixes: Dictionary, sounding: PackedInt32Array, a: int, b: int) -> Dictionary:
	var vmax := 0
	var vsum := 0.0
	var bmax := 0
	var bsum := 0.0
	var weight := 0
	for blk in sim.blocks:
		if blk[0] >= a and blk[0] < b:
			vmax = maxi(vmax, blk[2])
			bmax = maxi(bmax, blk[3])
			vsum += blk[2] * blk[1]
			bsum += blk[3] * blk[1]
			weight += blk[1]
	var wmax := 0
	var wmean := 0.0
	var windows := 0
	var w := a
	while w + WINDOW <= b:
		var top := 0
		var total := 0.0
		for g in range(w / GRID, (w + WINDOW) / GRID):
			top = maxi(top, sounding[g])
			total += sounding[g]
		wmax = maxi(wmax, top)
		wmean += total / (WINDOW / GRID)
		windows += 1
		w += WINDOW
	var cues := {}
	for row in sim.attempts:
		if row[0] >= a and row[0] < b:
			var c: Dictionary = cues.get(row[1], {"admitted": 0, "gap": 0, "poly": 0, "stolen": 0})
			c[row[2]] += 1
			cues[row[1]] = c
	var audible := []
	var own := []
	var by_id := {}
	for th in sim.threats:
		if th[0] >= a and th[0] < b and th[0] < sim.length:
			var band_st := short_term(prefixes["band"], th[0])
			var d := short_term(prefixes["cues"], th[0]) - band_st
			audible.append(d)
			own.append(short_term(prefixes["threat"], th[0]) - band_st)
			var list: Array = by_id.get(th[1], [])
			list.append(d)
			by_id[th[1]] = list
	var per_id := {}
	for id in by_id:
		per_id[id] = stats(by_id[id])
	var peak_sum := 0.0
	for i in range(a, b):
		peak_sum = maxf(peak_sum, maxf(absf(takes["sum"].left[i]), absf(takes["sum"].right[i])))
	var lufs := {}
	for name in ["band", "cues", "sum", "sum_no_bass_duck"]:
		var t = takes[name]
		lufs[name] = Board.loudness(t.left.slice(a, b), t.right.slice(a, b))
	return {
		"seconds": float(b - a) / Harmony.RATE,
		"band_voices": {"max": vmax, "mean": vsum / maxi(weight, 1), "band_only_max": bmax, "band_only_mean": bsum / maxi(weight, 1)},
		"band_voices_no_bass_duck_max": _max_voices(duckless, a, b),
		"sfx_voices_per_100ms": {"max": wmax, "mean": wmean / maxi(windows, 1), "windows": windows},
		"cues": cues,
		"lufs": lufs,
		"sum_peak_dbfs": linear_to_db(peak_sum),
		"threat_lu_cues_minus_band": stats(audible),
		"threat_lu_own_minus_band": stats(own),
		"threat_lu_by_id": per_id,
		"bass_share_below_120hz": {"duck": low_share(takes["sum"], a, b), "no_bass_duck": low_share(takes["sum_no_bass_duck"], a, b),
			"band_duck": low_share(takes["band"], a, b), "band_no_bass_duck": low_share(takes["band_no_bass_duck"], a, b)},
	}


static func _max_voices(sim: Sim, a: int, b: int) -> int:
	var top := 0
	for blk in sim.blocks:
		if blk[0] >= a and blk[0] < b:
			top = maxi(top, blk[2])
	return top


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var out := ProjectSettings.globalize_path("res://").path_join(OUT).simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var sim := Sim.new(true)
	sim.run()
	var duckless := Sim.new(false)
	duckless.run()
	# The same timeline with public engine calls only, run past the window.
	var probe := Sim.new(true, false)
	probe.run()
	probe.extend(PROBE_EXTRA)
	var n := sim.length
	var cues = Board.Take.new()
	var threat = Board.Take.new()
	fit(cues, n)
	fit(threat, n)
	for i in n:
		cues.left[i] = sim.sting.left[i]
		cues.right[i] = sim.sting.right[i]
		threat.left[i] = sim.sting.left[i]
		threat.right[i] = sim.sting.right[i]
	for v in sim.voices:
		cut_add(cues, v)
		if v["id"] in THREATS:
			cut_add(threat, v)
	fit(cues, n)
	fit(threat, n)
	fit(sim.band, n)
	fit(duckless.band, n)
	var takes := {"band": sim.band, "cues": cues, "sum": summed(sim.band, cues), "band_no_bass_duck": duckless.band,
		"sum_no_bass_duck": summed(duckless.band, cues)}
	var prefixes := {"band": k_prefix(sim.band), "cues": k_prefix(cues), "threat": k_prefix(threat)}
	var sounding := PackedInt32Array()
	sounding.resize(n / GRID + 2)
	sounding.fill(0)
	for v in sim.voices:
		var first := int(ceil(float(v["start"]) / GRID))
		var last := mini(int(ceil(float(v["end"]) / GRID)) - 1, sounding.size() - 2)
		if first <= last:
			sounding[first] += 1
			sounding[last + 1] -= 1
	for g in range(1, sounding.size()):
		sounding[g] += sounding[g - 1]
	var priorities := {"womp": Rows.priority("slammed"), "hold_pit": Rows.priority("hold_started"), "hold_bola": Rows.priority("hold_started"),
		"threat_up": Rows.priority("threat_rose")}
	for s in STREAMS:
		priorities[s[0]] = Sim.row_priority(s[1])
	var report := {"bars": sim.bars, "bar_lines_s": sim.bar_lines.map(func(x): return float(x) / Harmony.RATE), "notes": sim.notes,
		"s4_break_forced": sim.forced, "engine_notes": ENGINE_NOTES, "priorities": priorities,
		"cue_starts_match_between_runs": sim.attempts == duckless.attempts, "states": {}}
	var probe_log: Array = []
	for e in probe.engine.events_log:
		if e[1] >= probe.offset:
			probe_log.append([e[0], float(e[1] - probe.offset) / Harmony.RATE, str(e[2])])
	report["engine_path_probe"] = {"bars": probe.bars, "notes": probe.notes, "events": probe_log}
	for st in STATES:
		var a: int = sim.bar_lines[st["from"]]
		var b: int = sim.bar_lines[st["from"] + 4]
		var row := section(sim, duckless, takes, prefixes, sounding, a, b)
		row["label"] = st["label"]
		report["states"][st["name"]] = row
	report["overall"] = section(sim, duckless, takes, prefixes, sounding, 0, n)
	var log: Array = []
	for e in sim.engine.events_log:
		if e[1] >= sim.offset:
			log.append([e[0], float(e[1] - sim.offset) / Harmony.RATE, str(e[2])])
	report["engine_events"] = log
	for i in 3:
		var fade := mini(n, Harmony.RATE / 20)
		var t = [takes["band"], takes["cues"], takes["sum"]][i]
		for j in fade:
			t.left[n - 1 - j] *= float(j) / fade
			t.right[n - 1 - j] *= float(j) / fade
	var wavs := {}
	for name in ["band", "cues", "sum"]:
		var stats_row := Board.master(takes[name])
		var file := out.path_join("density-%s.wav" % name)
		stats_row["error"] = Board.to_wav(takes[name]).save_to_wav(file)
		stats_row["path"] = file
		wavs[name] = stats_row
	report["wavs"] = wavs
	var f := FileAccess.open(out.path_join("density.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	_print(report)
	print("audio_density_sim: done to %s in %.1f s" % [out, (Time.get_ticks_msec() - started) / 1000.0])
	quit(0)


func _print(report: Dictionary) -> void:
	print("bar  t(s)    bpm   track/section    key heft fleet pedal drop  cutoff")
	for b in report["bars"]:
		print("%2d  %6.2f  %5.1f  %-16s %3d %4d %5d %5s %5s %7.0f" % [b["bar"], b["t"], b["bpm"], "%s/%s" % [b["track"], b["section"]],
			b["key"], b["heft"], b["fleet"], b["pedal"], b["drop"], b["cutoff_hz"]])
	print("state  secs  bandV max/mean  sfxV max/mean  LUFS band/cues/sum  peak   threat LU min/med/max (own med)  bass<120 duck/noduck")
	for name in ["S1", "S2", "S3", "S4", "overall"]:
		var s: Dictionary = report["states"][name] if name != "overall" else report["overall"]
		var th: Dictionary = s["threat_lu_cues_minus_band"]
		var own: Dictionary = s["threat_lu_own_minus_band"]
		print("%-7s %4.1f  %3d / %5.1f    %3d / %5.1f   %5.1f/%5.1f/%5.1f   %5.1f   %5.1f/%5.1f/%5.1f (%5.1f)   %.3f/%.3f" % [name, s["seconds"],
			s["band_voices"]["max"], s["band_voices"]["mean"], s["sfx_voices_per_100ms"]["max"], s["sfx_voices_per_100ms"]["mean"],
			s["lufs"]["band"], s["lufs"]["cues"], s["lufs"]["sum"], s["sum_peak_dbfs"], th.get("min", NAN), th.get("median", NAN),
			th.get("max", NAN), own.get("median", NAN), s["bass_share_below_120hz"]["duck"], s["bass_share_below_120hz"]["no_bass_duck"]])
	print("cue            admitted  gap  poly  stolen")
	var cues: Dictionary = report["overall"]["cues"]
	for id in cues:
		print("%-14s %8d %4d %5d %7d" % [id, cues[id]["admitted"], cues[id]["gap"], cues[id]["poly"], cues[id]["stolen"]])
	for line in report["notes"]:
		print("note: " + line)
	var probe: Dictionary = report["engine_path_probe"]
	for line in probe["notes"]:
		print("probe: " + line)
	var path := []
	for b in probe["bars"]:
		if int(b["bar"]) >= 12:
			path.append("%d %s/%s key %d" % [b["bar"], b["track"], b["section"], b["key"]])
	print("probe bars: " + ", ".join(path))
	for e in probe["events"]:
		if e[0] in ["lift_queued", "break_queued", "build", "transition", "section", "drop_end", "key"]:
			print("probe event %.3f s  %s  %s" % [e[1], e[0], e[2]])
	for name in report["wavs"]:
		var w: Dictionary = report["wavs"][name]
		print("density-%s.wav  %5.1f s  %6.1f LUFS  peak %5.1f dBFS  limiter %4.1f dB  gain %5.1f dB  %s" % [name, w["seconds"], w["lufs"],
			w["peak_db"], w["limit_db"], w["gain_db"], "written" if int(w["error"]) == OK else "FAILED %d" % w["error"]])
