extends SceneTree

# Runs the POC under this project's 48 kHz mixer and prints lines the parent test checks:
# "mix48 ..." compares the join timeline with the parent's 44.1 kHz run; "mix48json ..."
# carries the generator and device runs (skips, contact clicks, audible_sample() error,
# keyed cue). Args after "--": --fixtures=<abs dir> --params=<base64 JSON from the parent>.
# The device runs need period 512 among the params' periods for the latency comparison.


func _initialize() -> void:
	var fixtures := ""
	var params := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixtures="):
			fixtures = arg.trim_prefix("--fixtures=")
		elif arg.begins_with("--params="):
			# Base64 JSON: OS.execute runs through sh -c and does not escape inner quotes.
			var parsed = JSON.parse_string(Marshalls.base64_to_utf8(arg.trim_prefix("--params=")))
			if not parsed is Dictionary:
				printerr("mix48: unreadable --params")
				quit(1)
				return
			params = parsed
	var poc = load(fixtures.get_base_dir().path_join("poc_sequencer.gd"))
	var r: Dictionary = poc.join_timeline(fixtures)
	# The contrast: one stem pulled at rate_scale 1.0 is resampled to the mixer rate.
	var stream := AudioStreamOggVorbis.load_from_file(fixtures.path_join("stem_drums.ogg"))
	var counts := []
	for scale in [1.0, AudioServer.get_mix_rate() / 44100.0]:
		var pb := stream.instantiate_playback()
		pb.start(0.0)
		var got := 0
		while true:
			var block := pb.mix_audio(scale, 4096)
			got += block.size()
			if block.size() < 4096:
				break
		counts.append(got)
	print("mix48 rate=%d scale=%.6f frames=%d l=%s r=%s short=%d misses=%d unscaled=%d scaled=%d" % [
		int(AudioServer.get_mix_rate()), r["rate_scale"], r["frames"], str(r["l"]).md5_text(), str(r["r"]).md5_text(),
		r["short_reads"], r["misses"], counts[0], counts[1]])
	if params.is_empty():
		quit(0)
		return

	var seconds := float(params["seconds"])
	var frame_us := float(params["frame_us"])
	var gen_buffer := float(params["gen_buffer"])
	var contacts: Array = poc.contact_times(seconds)
	var runs := []
	var poc512 := {}
	for period in params["periods"]:
		for hitch in [0.0, float(params["hitch_us"])]:
			var s: Dictionary = poc.device_run(fixtures, int(params["target"]), int(period), contacts, seconds, frame_us, gen_buffer, hitch, int(params["hitch_every"]))
			var clicks := 0
			var drift := 0
			for c in s["contacts"]:
				clicks += 1 if c["click"] else 0
				drift = maxi(drift, absi(int(c["click_frame"]) - int(c["nominal_frame"])))
			runs.append({"period": int(period), "hitch": hitch > 0.0, "skips": s["skips"], "min_q": s["min_q"], "max_q": s["max_q"],
				"contacts": s["contacts"].size(), "clicks": clicks, "gap_nonzero": s["gap_nonzero"], "short": s["short"], "misses": s["misses"],
				"err_lo": s["err_lo"], "err_hi": s["err_hi"], "err_frames": s["err_frames"], "nominal_drift": drift, "step": s["step"]})
			if int(period) == 512 and hitch == 0.0:
				poc512 = s
	if poc512.is_empty():
		printerr("mix48: periods must include 512")
		quit(1)
		return
	var current: Dictionary = poc.device_run(fixtures, -1, 512, contacts, seconds, frame_us, gen_buffer)
	var latency := {"no_worse": poc512["contacts"].size() == contacts.size() and current["contacts"].size() == contacts.size(),
		"current_skips": current["skips"], "poc": _lat(poc512["contacts"]), "current": _lat(current["contacts"])}
	for i in mini(poc512["contacts"].size(), current["contacts"].size()):
		var a: Dictionary = poc512["contacts"][i]
		var b: Dictionary = current["contacts"][i]
		latency["no_worse"] = latency["no_worse"] and float(a["gap_us"]) <= float(b["gap_us"]) and float(a["drop_us"]) <= float(b["drop_us"])
	var cues := []
	for period in params["periods"]:
		var k: Dictionary = poc.keyed_cue_run(fixtures, int(period), frame_us, gen_buffer)
		k["period"] = int(period)
		cues.append(k)
	print("mix48json " + JSON.stringify({"contacts": contacts.size(), "runs": runs, "latency": latency, "cues": cues}))
	quit(0)


# [min, mean, max] of gap_us, drop_us and queued over the contacts, in ms and frames.
func _lat(rows: Array) -> Dictionary:
	var out := {}
	for key in ["gap_us", "drop_us", "queued"]:
		var lo := INF
		var hi := -INF
		var sum := 0.0
		for row in rows:
			var v := float(row[key]) / (1000.0 if key != "queued" else 1.0)
			lo = minf(lo, v)
			hi = maxf(hi, v)
			sum += v
		out[key] = [lo, sum / maxi(rows.size(), 1), hi]
	return out
