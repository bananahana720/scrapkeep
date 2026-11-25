extends SceneTree

const AceSequencer := preload("res://src/presentation/ace_sequencer.gd")
const DeckMoves := preload("res://src/presentation/deck_moves.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")

# Offline bounce of one scripted Warden fight through AceSequencer.render():
#   4 bars build -> 4 bars telegraph (posture rising 75..100) -> 2 bars open
#   -> landed hit -> 4 bars drop -> 4 bars build (18 bars total).
#
# Usage:
#   godot --headless --path sketches/core-loop --script res://tools/deck_bounce.gd -- \
#     --deck=off|festival|viking [--stems=<sidecar dir>] --out=<wav path>

const BLOCK := 512


func _initialize() -> void:
	var args := _parse_args()
	var deck_mode := String(args.get("deck", "off"))
	if not deck_mode in ["off", "festival", "viking"]:
		printerr("deck_bounce: --deck must be off, festival or viking, got %s" % deck_mode)
		quit(2)
		return
	var out_path := String(args.get("out", ""))
	if out_path == "":
		printerr("deck_bounce: missing --out=<wav path>")
		quit(2)
		return
	var prev_stem_dir := MusicRows.stem_dir
	var stems_arg := String(args.get("stems", ""))
	if stems_arg != "":
		var sub := stems_arg.path_join("music_ace")
		MusicRows.stem_dir = sub if DirAccess.dir_exists_absolute(sub) else stems_arg
	else:
		AceStub.install()
	var manifest: String = MusicRows.ROWS["1-1"]["ace_manifest"]
	var seq := AceSequencer.new(manifest)
	if not seq.ready():
		MusicRows.stem_dir = prev_stem_dir
		printerr("deck_bounce: failed to load Spillway stems: %s" % seq.missing)
		quit(1)
		return

	var deck := DeckMoves.new()
	var room := {"style": deck_mode, "allow": true, "posture": 30.0, "staggered": false}

	# Preroll through the 1-bar pivot so recording begins sample-exact on build bar 0.
	seq.start_level(0, true)
	if deck_mode != "off":
		seq.set_pump(DeckMoves.pump_for(deck_mode))
	while seq.section != "build":
		if not seq.pending.is_empty() and String(seq.pending["section"]) == "build":
			var rem: int = int(seq.pending["at"]) - seq.clock
			if rem <= 0:
				break
			seq.render(mini(BLOCK, rem))
		else:
			seq.render(BLOCK)
	var bar: int = int(seq.clips["build"]["bar"])
	var beat: int = int(seq.clips["build"]["beat"])
	var t0: int = seq.clock
	var total_bars := 18
	var total_frames := total_bars * bar
	var recorded := PackedVector2Array()
	recorded.resize(total_frames)

	var tele_bar := 4
	var open_bar := 8
	var drop_bar := 10
	var tele_at := t0 + tele_bar * bar
	var open_at := t0 + open_bar * bar
	var drop_at_target := t0 + drop_bar * bar
	# Trigger transitions just ahead of their target bar so enter="beat" lands sample-exact on the bar line.
	var tele_trigger := tele_at - 1024
	var open_trigger := open_at - 1024
	var hit_trigger := drop_at_target - beat + 100
	var tele_triggered := false
	var open_triggered := false
	var hit_triggered := false
	var drop_booked_at := -1

	var written := 0
	while written < total_frames:
		var now: int = seq.clock
		if not tele_triggered and now >= tele_trigger:
			tele_triggered = true
			room["posture"] = 75.0
			seq.follow_guard(75.0, false, false)
		elif tele_triggered and not open_triggered:
			var frac := clampf(float(now - tele_at) / float(2.7 * bar), 0.0, 1.0)
			room["posture"] = 75.0 + 25.0 * frac
		if not open_triggered and now >= open_trigger:
			open_triggered = true
			room["posture"] = 100.0
			room["staggered"] = true
			seq.follow_guard(100.0, true, false)
		if not hit_triggered and now >= hit_trigger:
			hit_triggered = true
			room["posture"] = 0.0
			room["staggered"] = false
			drop_booked_at = seq.follow_guard(0.0, false, true)
			deck.tend(seq, room)
			deck.on_drop(seq, drop_booked_at, deck_mode)
		deck.tend(seq, room)

		var next_ev := t0 + total_frames
		if not tele_triggered:
			next_ev = mini(next_ev, tele_trigger)
		elif not open_triggered:
			next_ev = mini(next_ev, open_trigger)
		elif not hit_triggered:
			next_ev = mini(next_ev, hit_trigger)
		var step := mini(BLOCK, mini(total_frames - written, maxi(1, next_ev - now)))
		var chunk := seq.render(step)
		for i in step:
			recorded[written + i] = chunk[i]
		written += step

	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var wav := _to_stereo_wav(recorded, AceSequencer.RATE)
	var err := wav.save_to_wav(out_path)
	MusicRows.stem_dir = prev_stem_dir
	if err != OK:
		printerr("deck_bounce: save_to_wav(%s) failed with error %d" % [out_path, err])
		quit(1)
		return

	var bar_stats: Array = []
	var overall_peak := 0.0
	var overall_sq := 0.0
	var section_names := [
		"build", "build", "build", "build",
		"telegraph", "telegraph", "telegraph", "telegraph",
		"open", "open",
		"drop", "drop", "drop", "drop",
		"build", "build", "build", "build",
	]
	for b in total_bars:
		var start := b * bar
		var b_peak := 0.0
		var b_sq := 0.0
		for i in range(start, start + bar):
			var v := recorded[i]
			b_peak = maxf(b_peak, maxf(absf(v.x), absf(v.y)))
			b_sq += v.x * v.x + v.y * v.y
		overall_peak = maxf(overall_peak, b_peak)
		overall_sq += b_sq
		var b_rms := sqrt(b_sq / float(bar * 2) + 1e-18)
		bar_stats.append({
			"bar": b,
			"section": section_names[b],
			"peak_db": snappedf(_db(b_peak), 0.01),
			"rms_db": snappedf(_db(b_rms), 0.01),
		})
	var overall_rms := sqrt(overall_sq / float(total_frames * 2) + 1e-18)
	var drop_rms: float = bar_stats[drop_bar]["rms_db"]
	var breath_rms: float = bar_stats[drop_bar - 1]["rms_db"]
	var summary := {
		"deck": deck_mode,
		"stems": stems_arg if stems_arg != "" else "stub",
		"out": out_path,
		"seconds": snappedf(float(total_frames) / float(AceSequencer.RATE), 0.01),
		"drop_bar_sample_offset": drop_booked_at - drop_at_target,
		"peak_db": snappedf(_db(overall_peak), 0.01),
		"rms_db": snappedf(_db(overall_rms), 0.01),
		"drop_over_breath_db": snappedf(drop_rms - breath_rms, 0.01),
		"bars": bar_stats,
	}
	print(JSON.stringify(summary))
	quit(0)


static func _parse_args() -> Dictionary:
	var parsed := {}
	var raw := OS.get_cmdline_args()
	raw.append_array(OS.get_cmdline_user_args())
	for arg in raw:
		if arg.begins_with("--") and "=" in arg:
			var eq := arg.find("=")
			parsed[arg.substr(2, eq - 2)] = arg.substr(eq + 1)
	return parsed


static func _db(x: float) -> float:
	return 20.0 * log(maxf(x, 1e-9)) / log(10.0)


static func _to_stereo_wav(buf: PackedVector2Array, rate: int) -> AudioStreamWAV:
	var n := buf.size()
	var data := PackedByteArray()
	data.resize(n * 4)
	for i in n:
		var v := buf[i]
		var l := clampi(int(round(v.x * 32767.0)), -32768, 32767)
		var r := clampi(int(round(v.y * 32767.0)), -32768, 32767)
		var o := i * 4
		data[o] = l & 0xFF
		data[o + 1] = (l >> 8) & 0xFF
		data[o + 2] = r & 0xFF
		data[o + 3] = (r >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = rate
	wav.data = data
	return wav
