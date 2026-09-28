extends SceneTree

const Ace := preload("res://src/presentation/ace_sequencer.gd")

# The ACE band (src/presentation/ace_sequencer.gd) on the packaged Spillway stems, driven
# by the facts the audio director hands it. Simulated time drives a virtual device that
# pulls an AudioStreamGenerator in fixed periods, as the POC test does (core-loop-v3-seq
# 43453ab), so get_skips() counts Godot's own underrun path. Transport truth and measured
# levels only; the feel is Andrew's to judge in play.
#   - fallback: a missing manifest or stem names the file and the sequencer stays unready;
#   - section changes land on the bar (or the manifest's beat) of the section sounding;
#   - the build wraps 16 -> 9 natively: the audio after the wrap is bar 9, not bar 1;
#   - contacts drop on the next beat: gap and drop reach the device no later than the POC's;
#   - zero skips over 180 s at QUEUE_TARGET with the Warden cycling, steady and hitched;
#   - each held-breath style's kick band in the open against the build;
#   - the break set piece plays through untouched by the game.
# Needs tools/ace/package_music.py to have run: without the Oggs the audio checks SKIP.

const FRAME_US := 26000.0
const GEN_BUFFER := 0.1
const SIM_SECONDS := 180.0
const HITCH_US := 24000.0
const HITCH_EVERY := 97
# The POC's receipts at 44.1 kHz and QUEUE_TARGET 3072 (fdf8cd1): contact to gap audible
# 49..82 ms. Its drop waited for a 172 BPM beat; the Warden's is 129, so the drop is held
# to its own beat plus the same ring: the wait to the beat, then the ring and GEN_LEAD.
const POC_GAP_MS_MAX := 82.0
const KICK_HZ := 120.0

var _failures := 0
var _skipped := 0


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	_fallback()
	var probe := Ace.new()
	if not probe.ready():
		_skipped += 1
		print("[ace package] %s is missing; run tools/ace/package_music.py -> SKIP" % probe.missing)
	else:
		_bar_locked()
		_build_wrap()
		_contacts_and_skips()
		_breath_levels()
		_set_piece()
	print("presentation_ace_test: %s (%.1f s, %d skipped)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, (Time.get_ticks_msec() - t0) / 1000.0, _skipped])
	quit(0 if _failures == 0 else 1)


# A package with no manifest, and a manifest whose stems are gone: each names the file.
func _fallback() -> void:
	var none := Ace.new("res://tests/no_such_package/manifest.json")
	var dir := OS.get_user_data_dir().path_join("ace_fallback_test")
	DirAccess.make_dir_recursive_absolute(dir)
	var src := ProjectSettings.globalize_path(Ace.MANIFEST)
	var copied := DirAccess.copy_absolute(src, dir.path_join("manifest.json")) == OK
	var bare := Ace.new(dir.path_join("manifest.json"))
	var named: bool = bare.missing.ends_with(".ogg") and bare.missing.begins_with(dir)
	_check("fallback on a missing file", not none.ready() and none.missing.ends_with("no_such_package/manifest.json") and copied and not bare.ready() and named,
		"no manifest: ready %s, missing %s; manifest without its Oggs: ready %s, missing %s" % [none.ready(), none.missing, bare.ready(), bare.missing])
	DirAccess.remove_absolute(dir.path_join("manifest.json"))
	DirAccess.remove_absolute(dir)


func _render_to(seq, sample: int, block := 1150) -> PackedVector2Array:
	var buf := PackedVector2Array()
	while seq.clock < sample:
		buf.append_array(seq.render(mini(block, sample - seq.clock)))
	return buf


func _enters(seq, from := 0) -> Array:
	return seq.events_log.filter(func(e: Array) -> bool: return e[0] == "enter" and int(e[1]) >= from)


# Calm from 0; pressure rises mid-bar (travel on the bar); the drop-line commit mid-bar
# (pivot on the bar, build one 172 bar later); telegraph and open mid-bar (each on the
# next 129 beat, keeping the bar's beat); closed (build on the next bar, at its bar 9).
func _bar_locked() -> void:
	var seq := Ace.new()
	var calm: Dictionary = seq.clips["calm"]
	var build: Dictionary = seq.clips["build"]
	var cbar := int(calm["bar"])
	var wbar := int(build["bar"])
	var wbeat := int(build["beat"])
	seq.start_level(0)
	var rows := []
	var ok := true
	_render_to(seq, 2 * cbar + 7777)
	var asked := seq.clock
	seq.set_pressure(0.9)
	_render_to(seq, 4 * cbar)
	var travel: Array = _enters(seq, 1).filter(func(e): return e[2] == "travel")
	ok = ok and travel.size() == 1 and int(travel[0][1]) == 3 * cbar
	rows.append("travel asked at %d, entered %s (bar 3 = %d)" % [asked, travel.map(func(e): return e[1]), 3 * cbar])
	_render_to(seq, 4 * cbar + 12345)
	asked = seq.clock
	seq.commit_warden()
	_render_to(seq, 8 * cbar)
	var got := _enters(seq, asked)
	var pivot_at := 5 * cbar
	ok = ok and got.size() >= 2 and got[0][2] == "pivot" and int(got[0][1]) == pivot_at and got[1][2] == "build" and int(got[1][1]) == pivot_at + cbar
	rows.append("commit at %d: %s (pivot at bar 5 = %d, build at %d)" % [asked, got.map(func(e): return "%s@%d" % [e[2], e[1]]), pivot_at, pivot_at + cbar])
	var origin := pivot_at + cbar
	_render_to(seq, origin + 2 * wbar + wbeat + 5000)
	asked = seq.clock
	seq.set_warden_state("telegraph")
	_render_to(seq, asked + 2 * wbar)
	var tele: Array = _enters(seq, asked)
	var want_tele := origin + int(ceil(float(asked - origin) / wbeat)) * wbeat
	ok = ok and tele.size() == 1 and tele[0][2] == "telegraph" and int(tele[0][1]) == want_tele
	var tele_beat := posmod(int((want_tele - origin) / wbeat), 4)
	var tv: Ace.Voice = seq.voices[0]
	var tele_entry: int = tv.pos - (seq.clock - want_tele)
	var tele_clip: Dictionary = seq.clips["telegraph"]
	ok = ok and tele_entry == int(tele_clip["entry"]) + tele_beat * wbeat
	rows.append("telegraph asked at %d entered %s (next beat %d, beat %d of its bar, file entry %d)" % [asked, tele.map(func(e): return e[1]), want_tele, tele_beat, tele_entry])
	asked = seq.clock + 3333
	_render_to(seq, asked)
	seq.set_warden_state("open")
	_render_to(seq, asked + wbar)
	var opened: Array = _enters(seq, asked)
	var want_open := origin + int(ceil(float(asked - origin) / wbeat)) * wbeat
	ok = ok and opened.size() == 1 and opened[0][2] == "open" and int(opened[0][1]) == want_open
	rows.append("open asked at %d entered %s (next beat %d)" % [asked, opened.map(func(e): return e[1]), want_open])
	asked = seq.clock + 999
	_render_to(seq, asked)
	seq.set_warden_state("closed")
	_render_to(seq, asked + 2 * wbar)
	var back: Array = _enters(seq, asked)
	var want_back := origin + int(ceil(float(asked - origin) / wbar)) * wbar
	var bv: Ace.Voice = seq.voices[0]
	var back_entry: int = bv.pos - (seq.clock - want_back)
	ok = ok and back.size() == 1 and back[0][2] == "build" and int(back[0][1]) == want_back and back_entry == int(build["entry"]) + 8 * wbar
	rows.append("closed at %d: build at %s (next bar %d) from file sample %d (bar 9 = %d)" % [asked, back.map(func(e): return e[1]), want_back, back_entry, int(build["entry"]) + 8 * wbar])
	ok = ok and seq.misses == 0 and seq.short_reads == 0
	_check("section changes bar-locked", ok, "; ".join(rows) + "; misses %d, short reads %d" % [seq.misses, seq.short_reads])


# The build from bar 1 through its end: the frames after the wrap are the file's bar 9
# decoded fresh, not bar 1.
func _build_wrap() -> void:
	var seq := Ace.new()
	var build: Dictionary = seq.clips["build"]
	var bar := int(build["bar"])
	seq.start_level(0)
	seq.commit_warden()
	_render_to(seq, 4 * int(seq.clips["calm"]["bar"]))
	var start := -1
	for e in _enters(seq):
		if e[2] == "build":
			start = int(e[1])
	var wrap_at := start + 16 * bar
	_render_to(seq, wrap_at)
	var after := _render_to(seq, wrap_at + 8192)
	var v: Ace.Voice = seq.voices[0]
	var at9 := _decoded(seq, "build", int(build["loop_offset"]), 8192)
	var at1 := _decoded(seq, "build", int(build["entry"]), 8192)
	var d9 := _max_diff(after, at9)
	var d1 := _max_diff(after, at1)
	_check("build loop wraps 16 -> 9", start > 0 and d9 < 0.001 and d1 > 0.05 and v.pos == int(build["loop_offset"]) + 8192 and seq.misses == 0,
		"build entered at %d; 8192 frames after the wrap at %d match file bar 9 to %.6f and bar 1 only to %.3f; voice at file sample %d (bar 9 + 8192 = %d)" % [
		start, wrap_at, d9, d1, v.pos, int(build["loop_offset"]) + 8192])


# The three stems of a clip decoded fresh from file sample from, at the full profile's gain.
func _decoded(seq, clip_id: String, from: int, n: int) -> PackedVector2Array:
	var clip: Dictionary = seq.clips[clip_id]
	var sum := PackedVector2Array()
	sum.resize(n)
	for stem in seq.stems:
		var pb: AudioStreamPlayback = seq.streams[clip["paths"][stem]].instantiate_playback()
		pb.start((from + 0.5) / Ace.RATE)
		pb.mix_audio(1.0, Ace.LEAD_IN)
		var got := pb.mix_audio(1.0, n)
		for i in n:
			sum[i] += got[i] * seq.level
	return sum


func _max_diff(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var m := 0.0
	for i in mini(a.size(), b.size()):
		m = maxf(m, maxf(absf(a[i].x - b[i].x), absf(a[i].y - b[i].y)))
	return m


# 180 s on the virtual device: the Warden cycles closed, telegraph, open every 6 s after
# the commit, and a contact every ~7.37 s drops. QUEUE_TARGET is held by the pump.
func _contacts_and_skips() -> void:
	var runs := []
	var ok := true
	for cfg in [[512, 0.0], [1024, HITCH_US]]:
		var r := _device_run(int(cfg[0]), float(cfg[1]))
		runs.append(r)
		ok = ok and int(r["skips"]) == 0 and int(r["misses"]) == 0 and int(r["short"]) == 0
	var r0: Dictionary = runs[0]
	var gaps: Array = r0["gap_ms"]
	var waits: Array = r0["over_beat_ms"]
	var beats_ok: bool = r0["on_beat"] == r0["contacts"] and r0["contacts"] > 20
	_check("zero skips over 180 s", ok, "QUEUE_TARGET %d: p512 steady skips %d, p1024 with a 50 ms frame every %d skips %d; queued %d..%d; %d section entries; misses %d, short reads %d; render %.3f ms per 1000 frames" % [
		Ace.QUEUE_TARGET, runs[0]["skips"], HITCH_EVERY, runs[1]["skips"], r0["min_q"], r0["max_q"], r0["enters"], r0["misses"], r0["short"], r0["usec_per_k"] / 1000.0])
	_check("drop on the next beat after contact", beats_ok and gaps.max() <= POC_GAP_MS_MAX and waits.max() <= POC_GAP_MS_MAX,
		"%d contacts, %d dropped on the next Warden beat after the render head (entry at the returned sample, within one beat); contact -> gap audible %.1f..%.1f ms (POC max %.0f); drop audible minus the wait for its beat %.1f..%.1f ms (the ring and GEN_LEAD, POC gap max %.0f); wait for the beat %.1f..%.1f ms" % [
		r0["contacts"], r0["on_beat"], gaps.min(), gaps.max(), POC_GAP_MS_MAX, waits.min(), waits.max(), POC_GAP_MS_MAX, (r0["wait_ms"] as Array).min(), (r0["wait_ms"] as Array).max()])


func _device_run(period: int, hitch_us: float) -> Dictionary:
	var seq := Ace.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = Ace.RATE
	gen.buffer_length = GEN_BUFFER
	var gp: AudioStreamGeneratorPlayback = gen.instantiate_playback()
	gp.start(0.0)
	var capacity := gp.get_frames_available()
	var mix_rate := AudioServer.get_mix_rate()
	seq.start_level(0)
	var end_us := SIM_SECONDS * 1e6
	var t_game := 0.0
	var tick := 0
	var dev := 0
	var frames := 0
	var min_q := capacity
	var max_q := 0
	var next_contact := 3.0e6
	var committed := false
	var state_at := 2.0e6
	var cycle := ["telegraph", "open", "closed"]
	var cycle_len := [2.0e6, 2.5e6, 1.5e6]
	var ci := 0
	var pending := []
	var gap_ms := []
	var over_beat := []
	var wait_ms := []
	var contacts := 0
	var on_beat := 0
	while true:
		var t_dev := tick * period * 1e6 / mix_rate
		if t_game >= end_us and t_dev >= end_us:
			break
		if t_game <= t_dev:
			if not committed and t_game >= 1.0e6:
				seq.commit_warden()
				committed = true
			if committed and t_game >= state_at:
				seq.set_warden_state(cycle[ci % 3])
				state_at += cycle_len[ci % 3]
				ci += 1
			if t_game >= next_contact and t_game < end_us - 3.0e6:
				var head: int = seq.clock
				var at: int = seq.drop_now()
				contacts += 1
				var beat: int = seq.grid_beat
				if at >= head and at - head <= beat:
					pending.append({"t": t_game, "head": head, "at": at, "gap": -1.0, "wait": (at - head) * 1000.0 / Ace.RATE})
				next_contact += 7370011.0
			var n: int = seq.frames_to_pump(gp, capacity)
			if n > 0:
				gp.push_buffer(seq.render(n))
			var q := capacity - gp.get_frames_available()
			max_q = maxi(max_q, q)
			frames += 1
			t_game += FRAME_US + (hitch_us if frames % HITCH_EVERY == 0 else 0.0)
			continue
		min_q = mini(min_q, capacity - gp.get_frames_available())
		gp.mix_audio(1.0, period)
		var still := []
		for p in pending:
			var gap_frame: int = int(p["head"]) + Ace.GEN_LEAD
			if float(p["gap"]) < 0.0 and gap_frame < dev + period:
				p["gap"] = (maxi(gap_frame - dev, 0)) * 1000.0 / mix_rate + t_dev / 1000.0 - float(p["t"]) / 1000.0
			var drop_frame: int = int(p["at"]) + Ace.GEN_LEAD
			if drop_frame < dev + period:
				var drop_ms: float = (drop_frame - dev) * 1000.0 / mix_rate + t_dev / 1000.0 - float(p["t"]) / 1000.0
				gap_ms.append(p["gap"])
				over_beat.append(drop_ms - float(p["wait"]))
				wait_ms.append(p["wait"])
				on_beat += 1 if _entered(seq, "drop", int(p["at"])) else 0
				continue
			still.append(p)
		pending = still
		dev += period
		tick += 1
	return {"skips": gp.get_skips(), "misses": seq.misses, "short": seq.short_reads, "min_q": min_q, "max_q": max_q,
		"enters": _enters(seq).size(), "gap_ms": gap_ms, "over_beat_ms": over_beat, "wait_ms": wait_ms, "contacts": contacts,
		"on_beat": on_beat, "usec_per_k": seq.render_usec * 1000.0 / maxi(seq.rendered, 1)}


func _entered(seq, name: String, at: int) -> bool:
	for e in seq.events_log:
		if e[0] == "enter" and e[2] == name and int(e[1]) == at:
			return true
	return false


# Per style: 8 bars of build from its bar 9, then the open for 4 bars. Kick band (< 120 Hz)
# RMS of the open against the build, on the drums stem alone and on the whole mix.
func _breath_levels() -> void:
	var rows := {}
	for style in Ace.BREATHS:
		rows[style] = {"drums": _open_vs_build(style, ["drums"]), "mix": _open_vs_build(style, [])}
	var raw: Dictionary = rows["raw"]
	var hard: Dictionary = rows["hard"]
	var gentle: Dictionary = rows["gentle"]
	var ok: bool = absf(float(raw["drums"])) <= 4.0 \
		and float(hard["drums"]) <= -40.0 and float(gentle["drums"]) - float(raw["drums"]) <= -10.0 and float(gentle["drums"]) - float(raw["drums"]) >= -14.0
	_check("held-breath kick band", ok,
		"open against the build, drums alone / whole mix: raw %.1f / %.1f dB, hard %.1f / %.1f dB, gentle %.1f / %.1f dB; gentle against raw %.1f dB on the drums" % [
		raw["drums"], raw["mix"], hard["drums"], hard["mix"], gentle["drums"], gentle["mix"], float(gentle["drums"]) - float(raw["drums"])])


func _open_vs_build(style: String, solo: Array) -> float:
	var seq := Ace.new()
	seq.set_breath(style)
	seq.solo = solo
	seq.start_level(0)
	seq.commit_warden()
	var cbar := int(seq.clips["calm"]["bar"])
	var wbar := int(seq.clips["build"]["bar"])
	var build_at := cbar
	_render_to(seq, build_at + 8 * wbar)
	var build_buf := _render_to(seq, build_at + 16 * wbar)
	_render_to(seq, seq.clock + wbar / 2)
	seq.set_warden_state("open")
	_render_to(seq, seq.next_beat() + wbar / 4)
	var open_buf := _render_to(seq, seq.clock + 3 * wbar)
	return _kick_db(open_buf) - _kick_db(build_buf)


func _kick_db(buf: PackedVector2Array) -> float:
	var c := Ace.lowpass_coeffs(KICK_HZ)
	var z := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var sum := 0.0
	for i in buf.size():
		var x := (buf[i].x + buf[i].y) * 0.5
		var y1: float = c[0] * x + c[1] * z[0] + c[2] * z[1] - c[3] * z[2] - c[4] * z[3]
		z[1] = z[0]
		z[0] = x
		z[3] = z[2]
		z[2] = y1
		var y2: float = c[0] * y1 + c[1] * z[4] + c[2] * z[5] - c[3] * z[6] - c[4] * z[7]
		z[5] = z[4]
		z[4] = y1
		z[7] = z[6]
		z[6] = y2
		sum += y2 * y2
	return 10.0 * log(maxf(sum / maxi(buf.size(), 1), 1e-20)) / log(10.0)


# The break at the next bar, then return and home, each on the previous one's end; every
# Warden fact, contact, pressure swing and second break during it changes nothing. After
# home the shelf plays on in calm from the same clip, with no new entry. A break under a
# drop waits for the drop's end.
func _set_piece() -> void:
	var seq := Ace.new()
	var calm: Dictionary = seq.clips["calm"]
	var wbar := int(seq.clips["build"]["bar"])
	seq.start_level(0)
	seq.commit_warden()
	_render_to(seq, 3 * int(calm["bar"]) + 4321)
	var asked := seq.clock
	seq.warden_broken()
	var break_at := seq.next_bar()
	var noise := [["telegraph"], ["open"], ["drop"], ["broken"], ["pressure"], ["closed"], ["commit"], ["calm"]]
	var ignored := 0
	var t := asked
	for i in noise.size():
		t += int(wbar * 1.2)
		_render_to(seq, t)
		match noise[i][0]:
			"telegraph", "open", "closed":
				seq.set_warden_state(noise[i][0])
			"drop":
				ignored += 1 if seq.drop_now() == -1 else 0
			"broken":
				seq.warden_broken()
			"pressure":
				seq.set_pressure(1.0)
			"calm":
				seq.set_pressure(0.0)
			"commit":
				seq.commit_warden()
	var home_end := break_at + 4 * wbar + 2 * wbar + 8 * int(calm["bar"])
	_render_to(seq, home_end + 2 * int(calm["bar"]))
	var got := _enters(seq, asked).map(func(e): return "%s@%d" % [e[2], e[1]])
	var want := ["break@%d" % break_at, "return@%d" % (break_at + 4 * wbar), "home@%d" % (break_at + 6 * wbar)]
	var released := seq.events_log.filter(func(e): return e[0] == "release")
	var ok: bool = got == want and released.size() == 1 and int(released[0][1]) == home_end and ignored == 1 and seq.section == "calm"
	var rows := "entries from the break to two bars past home %s (want %s); released at %s (home end %d); the contact during it returned -1 %s; after the release %s plays on with no new entry" % [
		got, want, released.map(func(e): return e[1]), home_end, ignored == 1, seq.section]
	var under := Ace.new()
	under.start_level(0)
	under.commit_warden()
	_render_to(under, 3 * int(calm["bar"]) + 999)
	var drop_at := under.drop_now()
	_render_to(under, drop_at + 5000)
	under.warden_broken()
	_render_to(under, drop_at + 6 * wbar)
	var seq2 := _enters(under, drop_at).map(func(e): return "%s@%d" % [e[2], e[1]])
	var want2 := ["drop@%d" % drop_at, "break@%d" % (drop_at + 4 * wbar)]
	ok = ok and seq2 == want2 and under.misses == 0 and seq.misses == 0
	_check("break set piece plays through", ok, rows + "; broken under a drop: %s (want %s)" % [seq2, want2])


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
