extends SceneTree

const Poc := preload("res://tools/ace/poc_sequencer.gd")

# The ACE runtime proof (ACE-MUSIC-REVIEW section 3), held to exact samples: the POC
# sequencer plays committed impulse Oggs (tools/ace/make_poc_fixtures.py) through one
# pull mixer into an AudioStreamGenerator. Simulated time drives a virtual device that
# pulls the generator playback directly, so get_skips() counts Godot's own underrun path
# deterministically on the headless Dummy driver. Not ears: transport truth only. The
# device model and runs live in poc_sequencer.gd so the 48 kHz child runs the same code.

const FIXTURES := "res://tools/ace/poc_fixtures"
const GEN_BUFFER := 0.1  # audio.gd:26, the ring the current engine keeps full
const FRAME_US := 26000.0  # the synthetic frame load
const SIM_SECONDS := 180.0
const DEVICE_MS := 38.0  # PulseAudio output latency, receipt cap-44605a412e4922d6
const PERIODS := [512, 1024]
const TARGETS := [2048, 2560, 3072]
# One 50 ms frame (26 + 24) in every 97: the stress the chosen depth must also survive.
const HITCH_US := 24000.0
const HITCH_EVERY := 97

var _failures := 0
var _dir := ""
var _rows := {}
var _bar := 0
var _beat := 0


func _initialize() -> void:
	_dir = ProjectSettings.globalize_path(FIXTURES)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_dir.path_join("manifest.json")))
	for row in manifest["files"]:
		_rows[row["id"]] = row
	_bar = int(manifest["bar_samples"])
	_beat = int(manifest["beat_samples"])
	var t0 := Time.get_ticks_msec()
	_lead_in_and_seek()
	_loop_wrap()
	var joins := _joins()
	_skips_and_latency()
	_keyed_cue_across_lift()
	_mix48(joins)
	await _dummy_skips()
	print("presentation_sequencer_test: %s (%.1f s)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0 if _failures == 0 else 1)


# 1b and 2. The decoder's lead-in, measured; every bar of every stem entered mid-file
# with a (sample + 0.5) / rate seek lands on its bar's clicks exactly.
func _lead_in_and_seek() -> void:
	var raw := AudioStreamOggVorbis.load_from_file(_dir.path_join("stem_drums.ogg"))
	var pb := raw.instantiate_playback()
	pb.start(0.0)
	var head := pb.mix_audio(1.0, 4096)
	var measured: int = Poc.find_clicks(head, 0)[0]
	var tail := 0
	while true:
		var block := pb.mix_audio(1.0, 4096)
		tail += block.size()
		if block.size() < 4096:
			break
	var decoded := 4096 + tail
	_check("decoder lead-in", measured == Poc.LEAD_IN and decoded == int(_rows["stem_drums"]["sample_count"]),
		"a fresh playback puts file sample 0 at output %d (POC discards %d); a full pull returns %d frames, so the last %d file frames never come out without a post-roll" % [measured, Poc.LEAD_IN, decoded, measured])

	var seq = Poc.new(_dir)
	var exact := 0
	var naive_off := 0
	var total := 0
	var detail := []
	for id in Poc.STEMS:
		var fid := int(_rows[id]["file_id"])
		for bar in 16:
			total += 1
			var v: Dictionary = seq.open_voice(id, bar * _bar)
			var buf: PackedVector2Array = v["pb"].mix_audio(1.0, 8192)
			var l := Poc.find_clicks(buf, 0)
			var r := Poc.find_clicks(buf, 1)
			if l == PackedInt64Array([0, 4096 + 256 * bar]) and r == PackedInt64Array([64 * (fid + 1)]):
				exact += 1
			elif detail.size() < 3:
				detail.append("%s bar %d L%s R%s" % [id, bar, l, r])
			var naive: AudioStreamPlayback = seq.streams[id].instantiate_playback()
			naive.start(float(bar * _bar) / Poc.RATE)
			var nb := naive.mix_audio(1.0, 4096)
			if Poc.find_clicks(nb, 0)[0] != Poc.LEAD_IN:
				naive_off += 1
	# Off-grid entries too: d frames before beat m (never a bar's first beat, so no bar-ID
	# click sits between) puts that beat's click at output d.
	for pair in [[6, 1], [10, 777], [35, 3], [62, 15000]]:
		total += 1
		var entry: int = int(pair[0]) * _beat - int(pair[1])
		var v: Dictionary = seq.open_voice("stem_bass", entry)
		var l := Poc.find_clicks(v["pb"].mix_audio(1.0, 16384), 0)
		if l.size() > 0 and l[0] == int(pair[1]):
			exact += 1
		elif detail.size() < 3:
			detail.append("entry %d L%s" % [entry, l])
	_check("bar-boundary mid-file entry", exact == total and seq.short_reads == 0,
		"%d/%d entries (48 bar starts over 3 stems, 4 off-grid) land exactly after the lead-in discard; sample / rate seeks miss %d of the 48 by a frame %s" % [exact, total, naive_off, detail])


# 1. Native loop=true wraps with no seam: two passes plus two bars through the POC in
# 1,024-frame blocks, every click where the file says, no short read.
func _loop_wrap() -> void:
	var seq = Poc.new(_dir)
	seq.start(Poc.STEMS)
	var count := int(_rows["stem_drums"]["sample_count"])
	var total := 2 * count + 2 * _bar
	var buf := PackedVector2Array()
	while buf.size() < total:
		buf.append_array(seq.render(mini(1024, total - buf.size())))
	var want := _expected([[0, total, Poc.STEMS, 0]])
	var l := Poc.find_clicks(buf, 0)
	var r := Poc.find_clicks(buf, 1)
	var ok: bool = l == want[0] and r == want[1] and buf.size() == total and seq.short_reads == 0 and seq.clock == total
	_check("native loop wrap", ok,
		"%d frames over two wraps: %d/%d L and %d/%d R clicks exact (tail click at N-32 then bar 0 at N, last frame N-1 in R), short reads %d" % [
		buf.size(), _matches(l, want[0]), want[0].size(), _matches(r, want[1]), want[1].size(), seq.short_reads])


# 1. Joins: stems through a wrap, lift at bar 18, landing at 19, stems again at 23
# from file bar 5. Lead-in discarded and one-shot post-roll: every click exact, no
# post-roll heard, the last frame before each exit present. Lead-in kept (control):
# the joins shift and the lift's last frame drops.
func _joins() -> Dictionary:
	var r: Dictionary = Poc.join_timeline(_dir)
	var b := _bar
	var want := _expected([[0, 18 * b, Poc.STEMS, 0], [18 * b, 19 * b, ["lift"], 0], [19 * b, 23 * b, ["landing"], 0], [23 * b, 26 * b, Poc.STEMS, 5 * b]])
	var l: PackedInt64Array = r["l"]
	var rr: PackedInt64Array = r["r"]
	var post_roll_heard: bool = l.has(19 * b + 16) or l.has(23 * b + 16)
	var last_frames: bool = rr.has(19 * b - 1) and rr.has(23 * b - 1)
	var keys: bool = str(r["key_log"]) == str([[0, 0], [18 * b, 1], [19 * b, 0]])
	var ok: bool = l == want[0] and rr == want[1] and not post_roll_heard and last_frames and int(r["short_reads"]) == 0 and int(r["misses"]) == 0 and keys and int(r["frames"]) == 26 * b
	_check("joins at exact samples", ok,
		"%d frames, %d/%d L and %d/%d R clicks exact; post-roll heard %s; last frames before the lift and landing exits present %s; key log %s; short reads %d, misses %d" % [
		r["frames"], _matches(l, want[0]), want[0].size(), _matches(rr, want[1]), want[1].size(), post_roll_heard, last_frames, r["key_log"], r["short_reads"], r["misses"]])
	var control: Dictionary = Poc.join_timeline(_dir, 0)
	var cl: PackedInt64Array = control["l"]
	var cr: PackedInt64Array = control["r"]
	var wrong: int = (want[0].size() - _matches(cl, want[0])) + (want[1].size() - _matches(cr, want[1]))
	_check("lead-in control", wrong > 0 and not cr.has(19 * b - 1),
		"without the discard %d expected clicks move (each join shifts by the lead-in) and the lift's last frame is lost" % wrong)
	return r


# 3 and 5. A virtual device pulls the generator in fixed periods while 26 ms game
# frames pump it; a contact every ~7.37 s gaps the render head and drops the landing on
# the next beat. Same contacts under the current engine's full ring for the latency bar.
func _skips_and_latency() -> void:
	var contacts := Poc.contact_times(SIM_SECONDS)
	var sweep := []
	var chosen := {}
	var chosen_skips := 0
	var chosen_err := []
	var smallest_steady := -1
	var smallest_hitch := -1
	for target in TARGETS:
		var steady_zero := true
		var hitch_zero := true
		for period in PERIODS:
			for hitch in [0.0, HITCH_US]:
				var s := _simulate(target, int(period), contacts, hitch)
				if target == Poc.QUEUE_TARGET:
					chosen_err.append_array([s["err_lo"], s["err_hi"]])
				if hitch == 0.0:
					steady_zero = steady_zero and int(s["skips"]) == 0
				else:
					hitch_zero = hitch_zero and int(s["skips"]) == 0
				sweep.append("D%d/p%d%s skips %d q %d..%d" % [target, period, "/hitch" if hitch > 0.0 else "", s["skips"], s["min_q"], s["max_q"]])
				if target == Poc.QUEUE_TARGET:
					chosen_skips += int(s["skips"])
					if period == 512 and hitch == 0.0:
						chosen = s
		if steady_zero and smallest_steady < 0:
			smallest_steady = target
		if steady_zero and hitch_zero and smallest_hitch < 0:
			smallest_hitch = target
	var current := _simulate(-1, 512, contacts)
	var current_1024 := _simulate(-1, 1024, contacts)
	print("  skip sweep, %.0f s each at %.0f ms frames: %s; current engine p512 skips %d q %d..%d, p1024 skips %d" % [
		SIM_SECONDS, FRAME_US / 1000.0, ", ".join(sweep), current["skips"], current["min_q"], current["max_q"], current_1024["skips"]])

	var clean: bool = chosen_skips == 0 and int(chosen["gap_nonzero"]) == 0 and int(chosen["short"]) == 0 and int(chosen["misses"]) == 0
	var err_exact: bool = chosen_err.min() == 0 and chosen_err.max() == 0
	_check("skips over 3 minutes", clean and smallest_hitch == Poc.QUEUE_TARGET and err_exact,
		"QUEUE_TARGET %d: get_skips() %d summed over its four runs (512/1024 periods, steady and hitched), %d device frames each (%.0f s), queued %d..%d frames at p512; smallest zero-skip target steady %d, with the 50 ms hitch %d; audible_sample() minus the sounding sample %d..%d on every game frame of the four runs (44.1 kHz mixer, periods multiples of %d)" % [
		Poc.QUEUE_TARGET, chosen_skips, chosen["frames"], SIM_SECONDS, chosen["min_q"], chosen["max_q"], smallest_steady, smallest_hitch, chosen_err.min(), chosen_err.max(), Poc.GEN_CHUNK])

	var poc: Array = chosen["contacts"]
	var cur: Array = current["contacts"]
	var no_worse := poc.size() == contacts.size() and cur.size() == contacts.size()
	var clicks := 0
	for i in mini(poc.size(), cur.size()):
		no_worse = no_worse and float(poc[i]["gap_us"]) <= float(cur[i]["gap_us"]) and float(poc[i]["drop_us"]) <= float(cur[i]["drop_us"])
		clicks += 1 if poc[i]["click"] else 0
	var pg := _stats(poc, "gap_us")
	var pd := _stats(poc, "drop_us")
	var pq := _stats(poc, "queued")
	var cg := _stats(cur, "gap_us")
	var cd := _stats(cur, "drop_us")
	var cq := _stats(cur, "queued")
	_check("contact -> gap -> next-beat drop", no_worse and clicks == poc.size() and int(chosen["gap_nonzero"]) == 0 and int(current["gap_nonzero"]) == 0,
		"%d contacts; landing click heard at exactly drop sample + %d every time (%d/%d); gap silent to the sample. Queued at contact POC %s frames, current %s. Contact->gap audible POC %s ms, current %s ms; contact->drop audible POC %s ms, current %s ms (add %.0f ms device latency to each); POC no worse on every contact: %s" % [
		poc.size(), Poc.GEN_LEAD, clicks, poc.size(), _fmt(pq, 1.0), _fmt(cq, 1.0), _fmt(pg, 0.001), _fmt(cg, 0.001), _fmt(pd, 0.001), _fmt(cd, 0.001), DEVICE_MS, no_worse])


# One simulated run at this project's 44.1 kHz mixer. target < 0 is the current engine.
func _simulate(target: int, period: int, contacts: Array, hitch_us := 0.0) -> Dictionary:
	return Poc.device_run(_dir, target, period, contacts, SIM_SECONDS, FRAME_US, GEN_BUFFER, hitch_us, HITCH_EVERY)


# 4. A keyed cue fired every frame reads the key at the audible sample from the commit
# log. The lift (Eb) enters at bar 2 and the landing (D) at bar 3; the render head is
# QUEUE_TARGET frames ahead, so reading it (what audio.gd:348 does today) is wrong
# around each change. The accounting matches the device to the sample.
func _keyed_cue_across_lift() -> void:
	var k: Dictionary = Poc.keyed_cue_run(_dir, 512, FRAME_US, GEN_BUFFER)
	var ok: bool = k["cue_wrong"] == 0 and k["accounting_off"] == 0 and k["head_wrong"] > 0 and k["in_lift"] > 0 and k["lift_click"] and k["landing_click"] and k["skips"] == 0
	_check("keyed cue at the audible sample", ok,
		"%d frames, %d inside the audible lift; key at audible sample wrong on %d, render-head key wrong on %d; audible_sample() == device frame - %d on every frame (%d off), anchored by the lift and landing clicks sounding at exactly their logged sample + %d: %s/%s; key log %s" % [
		k["frames"], k["in_lift"], k["cue_wrong"], k["head_wrong"], Poc.GEN_LEAD, k["accounting_off"], Poc.GEN_LEAD, k["lift_click"], k["landing_click"], k["key_log"]])


# 6. A child project with audio/driver/mix_rate=48000 runs the same join timeline, then
# the same generator, device, contact and keyed-cue runs. The generator at 44.1 kHz is
# resampled to the device there, so a transport sample sounds at a fractional device
# frame and the ring's 128-frame steps no longer fall on device periods.
const MIX48_PERIODS := [480, 512, 1024]


func _mix48(joins: Dictionary) -> void:
	var child := ProjectSettings.globalize_path("res://tools/ace/poc_mix48")
	var params := {"seconds": SIM_SECONDS, "frame_us": FRAME_US, "gen_buffer": GEN_BUFFER, "target": Poc.QUEUE_TARGET,
		"periods": MIX48_PERIODS, "hitch_us": HITCH_US, "hitch_every": HITCH_EVERY}
	var output := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", child, "--script", "res://run.gd", "--",
		"--fixtures=" + _dir, "--params=" + Marshalls.utf8_to_base64(JSON.stringify(params))], output, true)
	var line := ""
	var data = null
	for chunk in output:
		for l in str(chunk).split("\n"):
			if l.begins_with("mix48 "):
				line = l
			elif l.begins_with("mix48json "):
				data = JSON.parse_string(l.trim_prefix("mix48json "))
	var fields := {}
	for part in line.split(" "):
		var kv := part.split("=")
		if kv.size() == 2:
			fields[kv[0]] = kv[1]
	var count := int(_rows["stem_drums"]["sample_count"])
	var ok: bool = code == 0 and fields.get("rate", "") == "48000" and int(fields.get("frames", "-1")) == int(joins["frames"]) \
		and fields.get("l", "") == str(joins["l"]).md5_text() and fields.get("r", "") == str(joins["r"]).md5_text() \
		and fields.get("short", "") == "0" and fields.get("misses", "") == "0" and int(fields.get("scaled", "-1")) == count and int(fields.get("unscaled", "-1")) != count
	_check("mix_rate 48000 frame counts", ok,
		"child exit %d: %s; 44.1 kHz run %d frames. Clicks identical by md5 L %s R %s" % [code, line if line != "" else "no mix48 line", joins["frames"],
		fields.get("l", "") == str(joins["l"]).md5_text(), fields.get("r", "") == str(joins["r"]).md5_text()])

	if not data is Dictionary:
		_check("mix_rate 48000 generator and device", false, "no mix48json line from the child (exit %d)" % code)
		return
	# Contacts land on the device frame the fixed-point model predicts, in every run; the
	# nominal 44100 / 48000 ratio would miss some of them.
	var contacts := Poc.contact_times(SIM_SECONDS).size()
	var runs_ok := true
	var skips := 0
	var err_lo := 1 << 30
	var err_hi := -(1 << 30)
	var drift := 0
	var q_lo := 1 << 30
	var q_hi := 0
	var detail := []
	for run in data["runs"]:
		skips += int(run["skips"])
		err_lo = mini(err_lo, int(run["err_lo"]))
		err_hi = maxi(err_hi, int(run["err_hi"]))
		drift = maxi(drift, int(run["nominal_drift"]))
		q_lo = mini(q_lo, int(run["min_q"]))
		q_hi = maxi(q_hi, int(run["max_q"]))
		var good: bool = int(run["step"]) == 60211 and int(run["skips"]) == 0 and int(run["contacts"]) == contacts and int(run["clicks"]) == contacts \
			and int(run["gap_nonzero"]) == 0 and int(run["short"]) == 0 and int(run["misses"]) == 0
		runs_ok = runs_ok and good
		if not good and detail.size() < 3:
			detail.append(str(run))
	var bound_ok := err_lo >= -(Poc.GEN_CHUNK - 1) and err_hi <= 0
	var lat: Dictionary = data["latency"]
	_check("mix_rate 48000 generator and device", runs_ok and bound_ok and bool(lat["no_worse"]),
		"QUEUE_TARGET %d at periods %s steady and hitched, %.0f s each: get_skips() %d summed, queued %d..%d; every landing click (%d contacts x %d runs) peaks on the device frame nearest (drop + %d) * 65536 / 60211, the fixed-point step, and gaps are silent; the nominal ratio misses by up to %d device frames by the end. audible_sample() minus the sounding sample %d..%d transport frames (bound 0..-%d, %.2f ms), so exact only at 44.1 kHz. Contact->gap audible POC %s ms, current %s ms; contact->drop POC %s ms, current %s ms; queued at contact POC %s, current %s; POC no worse on every contact: %s %s" % [
		Poc.QUEUE_TARGET, MIX48_PERIODS, SIM_SECONDS, skips, q_lo, q_hi, contacts, data["runs"].size(), Poc.GEN_LEAD, drift, err_lo, err_hi, Poc.GEN_CHUNK - 1,
		(Poc.GEN_CHUNK - 1) * 1000.0 / Poc.RATE, _fmt(lat["poc"]["gap_us"], 1.0), _fmt(lat["current"]["gap_us"], 1.0), _fmt(lat["poc"]["drop_us"], 1.0),
		_fmt(lat["current"]["drop_us"], 1.0), _fmt(lat["poc"]["queued"], 1.0), _fmt(lat["current"]["queued"], 1.0), lat["no_worse"], detail])

	# The keyed cue at 48 kHz: every misread sits where a key change falls inside the chunk
	# audible_sample() cannot see into, and the clicks land where the model says.
	var cues_ok := true
	var parts := []
	for k in data["cues"]:
		var good: bool = int(k["cue_wrong"]) == int(k["cue_wrong_chunk"]) and bool(k["lift_click"]) and bool(k["landing_click"]) and int(k["skips"]) == 0 \
			and int(k["err_lo"]) >= -(Poc.GEN_CHUNK - 1) and int(k["err_hi"]) <= 0 and int(k["in_lift"]) > 0
		cues_ok = cues_ok and good
		parts.append("p%d: %d frames, %d in the lift, cue wrong %d (inside a chunk after a key change %d), render-head wrong %d, error %d..%d, clicks %s/%s" % [
			k["period"], k["frames"], k["in_lift"], k["cue_wrong"], k["cue_wrong_chunk"], k["head_wrong"], k["err_lo"], k["err_hi"], k["lift_click"], k["landing_click"]])
	_check("mix_rate 48000 keyed cue", cues_ok, "; ".join(parts))


# 5, how skips show on the Dummy driver: it mixes on its own thread in real time, so a
# player-attached generator left unfed counts one skip per 128-frame internal read.
func _dummy_skips() -> void:
	var player := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = Poc.RATE
	gen.buffer_length = GEN_BUFFER
	player.stream = gen
	root.add_child(player)
	await process_frame
	player.play()
	var gp: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var t0 := Time.get_ticks_msec()
	await create_timer(0.3).timeout
	var skips := gp.get_skips()
	var ms := Time.get_ticks_msec() - t0
	gp = null
	player.stop()
	root.remove_child(player)
	player.free()
	# The audio server releases the stopped playback on a later mix.
	await create_timer(0.05).timeout
	_check("Dummy driver skips are live", AudioServer.get_driver_name() == "Dummy" and skips > 0,
		"driver %s, output latency %.3f s: an unfed generator on a player counted %d skips in %d ms of wall time (~%d frames per skip); the 3-minute proof pulls the generator from a virtual device instead" % [
		AudioServer.get_driver_name(), AudioServer.get_output_latency(), skips, ms, int(ms * Poc.RATE / 1000.0 / maxi(skips, 1))])


# Expected click positions for a list of [t0, t1, ids, entry] segments, from the
# manifest and the fixture layout in make_poc_fixtures.py. Returns [L, R], sorted.
func _expected(segments: Array) -> Array:
	var l := {}
	var r := {}
	for seg in segments:
		var t0: int = seg[0]
		var t1: int = seg[1]
		var entry: int = seg[3]
		for id in seg[2]:
			var row: Dictionary = _rows[id]
			var fid := int(row["file_id"])
			var bars := int(row["bars"])
			var ex := int(row["exit"])
			var loop := bool(row["loop"])
			var count := int(row["sample_count"])
			var fl := []
			var fr := [ex - 1]
			for b in bars * 4:
				fl.append(b * _beat)
				fr.append(b * _beat + 64 * (fid + 1))
			for bar in bars:
				fl.append(bar * _bar + 4096 + 256 * (int(row["first_bar_id"]) + bar))
			fl.append(ex - 32 if loop else ex + 16)
			for pair in [[fl, l], [fr, r]]:
				for c in pair[0]:
					var t: int = t0 + int(c) - entry
					if loop:
						t = t0 + posmod(int(c) - entry, count)
						while t < t1:
							pair[1][t] = true
							t += count
					elif t >= t0 and t < t1:
						pair[1][t] = true
	var ls := l.keys()
	var rs := r.keys()
	ls.sort()
	rs.sort()
	return [PackedInt64Array(ls), PackedInt64Array(rs)]


func _matches(got: PackedInt64Array, want: PackedInt64Array) -> int:
	var n := 0
	for x in want:
		if got.has(x):
			n += 1
	return n


func _stats(rows: Array, key: String) -> Array:
	var lo := INF
	var hi := -INF
	var sum := 0.0
	for row in rows:
		var v := float(row[key])
		lo = minf(lo, v)
		hi = maxf(hi, v)
		sum += v
	return [lo, sum / maxi(rows.size(), 1), hi]


func _fmt(s: Array, scale: float) -> String:
	return "min %.1f mean %.1f max %.1f" % [float(s[0]) * scale, float(s[1]) * scale, float(s[2]) * scale]


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
