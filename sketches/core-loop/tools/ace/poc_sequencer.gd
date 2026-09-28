extends RefCounted

# Scratch sequencer for the ACE runtime proof (ACE-MUSIC-REVIEW section 3). Outside the
# engine and without ACE audio: it plays the impulse Oggs in poc_fixtures/ through one
# pull mixer, and tests/presentation_sequencer_test.gd holds it to exact samples. It is
# a proof, not the migration; music_engine.gd and audio.gd are untouched.
#
# What it proves the real sequencer must do:
#   - Pull every stem with mix_audio(AudioServer.get_mix_rate() / RATE, n), so a
#     44.1 kHz asset advances n source frames per n output frames at any mixer rate.
#   - Discard the decoder's LEAD_IN frames when a playback opens, and ship one-shots
#     with a post-roll past their exit so the last frames before the exit come out.
#   - Seek with (sample + 0.5) / RATE; sample / RATE lands a frame early on some bars.
#   - Keep the generator ring at a numeric depth (QUEUE_TARGET) instead of full.
#   - Log every key commit by transport sample and read cues at the audible sample.
#     audible_sample() is exact only while the mixer runs at RATE and the device pulls
#     whole 128-frame resampler chunks; at any other mixer rate (48 kHz measured) it
#     trails the sounding sample by 0 to GEN_CHUNK - 1 transport frames.
# No preloads or class_name: the mix48 child project loads it by absolute path.

const RATE := 44100
# Frames of silence a fresh AudioStreamPlaybackOggVorbis emits before sample 0 of its
# seek position (Godot 4.7.2, measured by the test).
const LEAD_IN := 2
# Frames between a sample leaving the generator ring and reaching the device: the
# resampler's 128-frame internal chunk, pre-filled with zeros because a player starts
# the generator on an empty ring, plus the same 2-frame lead-in. Measured by signal.
# At a mixer rate other than RATE this is still 130 transport frames, but a transport
# sample then sounds at a fractional device frame: see transport_at().
const GEN_LEAD := 130
# The resampler's internal chunk: the generator ring drains in steps of this size.
const GEN_CHUNK := 128
# Generator ring depth the pump keeps. See the test's skip sweep: the smallest target
# with zero skips at steady 26 ms frames and through a 50 ms hitch, on 512- and
# 1024-frame device periods.
const QUEUE_TARGET := 3072

var beat := 15384
var bar := 61536
var rate_scale := 1.0
var rows := {}
var streams := {}
# Transport samples rendered so far: the render head.
var clock := 0
# The section sounding at the render head: {"ids", "key", "start", "voices"}. A voice is
# {"id", "pb", "pos", "exit", "loop", "count"}; pos is the next file sample it outputs.
var section := {}
# Scheduled changes, sorted by "at": {"at", "type": "enter"|"gap", ...}.
var actions: Array = []
var gap := false
# [transport sample, key] for every key commit, in order.
var key_log: Array = []
var events_log: Array = []
var short_reads := 0
var misses := 0
# Frames discarded when a decoder opens. The test sets 0 once as a negative control.
var lead_in := LEAD_IN


func _init(fixture_dir: String) -> void:
	rate_scale = AudioServer.get_mix_rate() / float(RATE)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_dir.path_join("manifest.json")))
	beat = int(manifest["beat_samples"])
	bar = int(manifest["bar_samples"])
	for row in manifest["files"]:
		var id: String = row["id"]
		rows[id] = row
		# Loop points come from the manifest at load; *.import files are not committed.
		var stream := AudioStreamOggVorbis.load_from_file(fixture_dir.path_join(id + ".ogg"))
		stream.loop = bool(row["loop"])
		stream.loop_offset = float(row["loop_offset"]) / RATE
		streams[id] = stream


# A decoder positioned so its next output frame is file sample entry.
func open_voice(id: String, entry: int) -> Dictionary:
	var pb: AudioStreamPlayback = streams[id].instantiate_playback()
	pb.start((entry + 0.5) / RATE)
	if lead_in > 0:
		var lead := pb.mix_audio(rate_scale, lead_in)
		if lead.size() != lead_in:
			short_reads += 1
	var row: Dictionary = rows[id]
	return {"id": id, "pb": pb, "pos": entry, "exit": int(row["exit"]), "loop": bool(row["loop"]), "count": int(row["sample_count"])}


# Starts ids at file sample entry right now, at the render head.
func start(ids: Array, entry := 0) -> void:
	_commit({"at": clock, "type": "enter", "ids": ids, "voices": _open(ids, entry)})


# Prepares ids at file sample entry and schedules them to take over at transport
# sample at. Decoders open (seek plus lead-in discard) now, before the boundary.
func schedule_enter(at: int, ids: Array, entry := 0) -> void:
	_add({"at": at, "type": "enter", "ids": ids, "voices": _open(ids, entry)})


# The next beat at or after the render head, or after from.
func next_beat(from := -1) -> int:
	var base := maxi(clock, from)
	return int(ceil(float(base) / beat)) * beat


# Contact: the render head goes quiet now and ids enter on the next beat.
func drop_now(ids: Array, entry := 0) -> int:
	var at := next_beat()
	if at > clock:
		_add({"at": clock, "type": "gap"})
	schedule_enter(at, ids, entry)
	return at


# The key sounding at transport sample s, from the commit log.
func key_at(s: int) -> int:
	var key := 0
	for entry in key_log:
		if int(entry[0]) > s:
			break
		key = int(entry[1])
	return key


# The key at the render head: what audio.gd's engine.key reads today.
func render_key() -> int:
	return key_at(clock - 1) if clock > 0 else key_at(0)


# The next transport sample to reach the speaker, given the generator ring's queued
# frames. The ring drains in GEN_CHUNK steps, so this is the start of the chunk the
# resampler is playing: exact when the mixer runs at RATE and the device period is a
# multiple of GEN_CHUNK; otherwise it trails the sounding sample by 0 to GEN_CHUNK - 1
# transport frames (under 2.9 ms), bound measured at 48 kHz by the test. The device
# adds its output latency on top.
func audible_sample(queued: int) -> int:
	return clock - queued - GEN_LEAD - int(round(AudioServer.get_output_latency() * RATE))


# Tops the generator ring up to target queued frames. capacity is the ring's
# get_frames_available() when empty. Returns the frames pushed.
func pump(gp: AudioStreamGeneratorPlayback, capacity: int, target := QUEUE_TARGET) -> int:
	var queued := capacity - gp.get_frames_available()
	var n := mini(target - queued, gp.get_frames_available())
	if n <= 0:
		return 0
	gp.push_buffer(render(n))
	return n


# Renders n transport frames, splitting at every scheduled action and file exit so
# each change lands on its exact sample. Every voice is pulled by the same count.
func render(n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(n)
	var done := 0
	while done < n:
		while not actions.is_empty() and int(actions[0]["at"]) <= clock:
			_commit(actions.pop_front())
		var span := n - done
		if not actions.is_empty():
			span = mini(span, int(actions[0]["at"]) - clock)
		var voices: Array = section.get("voices", [])
		for v in voices:
			if not v["loop"]:
				span = mini(span, int(v["exit"]) - int(v["pos"]))
		if span <= 0:
			# A one-shot reached its exit with nothing queued: keep time in silence.
			misses += 1
			events_log.append(["miss", clock, section.get("ids", [])])
			section = {}
			continue
		_mix_into(out, done, span, voices)
		done += span
		clock += span
	return out


func _mix_into(out: PackedVector2Array, at: int, span: int, voices: Array) -> void:
	var blocks: Array = []
	for v in voices:
		var got: PackedVector2Array = v["pb"].mix_audio(rate_scale, span)
		if got.size() != span:
			short_reads += 1
			got.resize(span)
		v["pos"] = (int(v["pos"]) + span) % int(v["count"]) if v["loop"] else int(v["pos"]) + span
		blocks.append(got)
	if gap or blocks.is_empty():
		for i in span:
			out[at + i] = Vector2.ZERO
		return
	var first: PackedVector2Array = blocks[0]
	if blocks.size() == 1:
		for i in span:
			out[at + i] = first[i]
		return
	if blocks.size() == 3:
		var second: PackedVector2Array = blocks[1]
		var third: PackedVector2Array = blocks[2]
		for i in span:
			out[at + i] = first[i] + second[i] + third[i]
		return
	for i in span:
		var s := first[i]
		for b in range(1, blocks.size()):
			s += blocks[b][i]
		out[at + i] = s


func _open(ids: Array, entry: int) -> Array:
	var voices: Array = []
	for id in ids:
		voices.append(open_voice(id, entry))
	return voices


func _add(action: Dictionary) -> void:
	var i := 0
	while i < actions.size() and int(actions[i]["at"]) <= int(action["at"]):
		i += 1
	actions.insert(i, action)


func _commit(action: Dictionary) -> void:
	match action["type"]:
		"gap":
			gap = true
			events_log.append(["gap", clock, ""])
		"enter":
			gap = false
			var ids: Array = action["ids"]
			var key := int(rows[ids[0]]["key_offset"])
			section = {"ids": ids, "key": key, "start": clock, "voices": action["voices"]}
			if key_log.is_empty() or int(key_log[-1][1]) != key:
				key_log.append([clock, key])
			events_log.append(["enter", clock, ids])


# --- Proof helpers, shared by the test and the mix48 child ------------------------------

const STEMS := ["stem_drums", "stem_bass", "stem_other"]


# Transport positions of the clicks in one channel (0 = L, 1 = R) of buf: the peak of
# each run above threshold, searched 8 frames ahead. base offsets the positions.
static func find_clicks(buf: PackedVector2Array, ch: int, base := 0, threshold := 0.4) -> PackedInt64Array:
	var out := PackedInt64Array()
	var n := buf.size()
	var i := 0
	while i < n:
		var v: float = absf(buf[i].x if ch == 0 else buf[i].y)
		if v <= threshold:
			i += 1
			continue
		var best := i
		var j := i + 1
		while j < mini(n, i + 9):
			var w: float = absf(buf[j].x if ch == 0 else buf[j].y)
			if w > v:
				best = j
				v = w
			j += 1
		out.append(base + best)
		i = best + 9
	return out


# The join timeline: stems from bar 0 through a native loop wrap, the lift at bar 18,
# the landing at bar 19 and the stems again at bar 23 entering mid-file at file bar 5,
# rendered to bar 26 in 1,150-frame blocks. Returns the clicks and counters.
static func join_timeline(fixture_dir: String, lead := LEAD_IN) -> Dictionary:
	var seq = load(fixture_dir.get_base_dir().path_join("poc_sequencer.gd")).new(fixture_dir)
	seq.lead_in = lead
	var b: int = seq.bar
	seq.start(STEMS)
	seq.schedule_enter(18 * b, ["lift"])
	seq.schedule_enter(19 * b, ["landing"])
	seq.schedule_enter(23 * b, STEMS, 5 * b)
	var total := 26 * b
	var buf := PackedVector2Array()
	while buf.size() < total:
		buf.append_array(seq.render(mini(1150, total - buf.size())))
	return {"frames": buf.size(), "l": find_clicks(buf, 0), "r": find_clicks(buf, 1), "short_reads": seq.short_reads,
		"misses": seq.misses, "key_log": seq.key_log, "rate_scale": seq.rate_scale}


# --- Device model, shared by the test (44.1 kHz) and the mix48 child (48 kHz) -----------
#
# A virtual device pulls the generator playback in fixed periods of mixer frames, as a
# player would. Godot's AudioStreamPlaybackResampled steps through the ring's frames by
# gen_step() / 65536 per device frame (16.16 fixed point, truncated) and plays chunk
# frame pos - 2 by cubic interpolation behind a first chunk of zeros, so device frame d
# sounds transport position d * step / 65536 - GEN_LEAD. At RATE the step is exactly
# 65536; at 48 kHz it is 60211, not 44100 / 48000 * 65536 = 60211.2, so the generator
# plays 3.3 ppm slow and the nominal ratio drifts off the device by a frame every ~6.8 s.
# The clicks in the proof anchor this model: each lands on the frame it predicts.


# The generator's resampler step per device frame at the current mixer rate.
static func gen_step() -> int:
	return int(float(RATE) / AudioServer.get_mix_rate() * 65536.0)


# The transport sample (integer part) sounding at device frame d.
static func transport_at(d: int, step: int) -> int:
	return ((d * step) >> 16) - GEN_LEAD


# The device frame nearest to where transport sample s sounds: a click's peak.
static func device_frame_near(s: int, step: int) -> int:
	return int(((s + GEN_LEAD) * 131072 + step) / (2 * step))


# The first device frame at or past transport sample s.
static func device_frame_from(s: int, step: int) -> int:
	return int(((s + GEN_LEAD) * 65536 + step - 1) / step)


# Contact times in microseconds: one every ~7.37 s from 3 s, the last leaving room for
# its landing before seconds.
static func contact_times(seconds: float) -> Array:
	var out := []
	var t := 3.0e6
	while t < seconds * 1e6 - 6.5e6:
		out.append(t)
		t += 7370011.0
	return out


# One simulated run: stems play, 26 ms game frames pump the ring to target (target < 0
# is the current engine, which pushes whatever the ring takes), and each contact gaps the
# render head and drops the landing on the next beat, stems again 4 bars later. Every
# game frame compares audible_sample() with transport_at(). Hitch adds hitch_us to every
# hitch_every-th frame.
static func device_run(fixture_dir: String, target: int, period: int, contacts: Array, seconds: float, frame_us: float,
		gen_buffer: float, hitch_us := 0.0, hitch_every := 97) -> Dictionary:
	var seq = load(fixture_dir.get_base_dir().path_join("poc_sequencer.gd")).new(fixture_dir)
	var step := gen_step()
	var mix_rate := AudioServer.get_mix_rate()
	seq.start(STEMS)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = gen_buffer
	var gp: AudioStreamGeneratorPlayback = gen.instantiate_playback()
	gp.start(0.0)
	var capacity := gp.get_frames_available()
	var fill := capacity if target < 0 else target
	var end_us := seconds * 1e6
	var exact := step == 65536
	var t_game := 0.0
	var game_frames := 0
	var tick := 0
	var dev := 0
	var ci := 0
	var pending := []
	var done := []
	var max_q := 0
	var min_q := capacity
	var gap_nonzero := 0
	var err_lo := 1 << 30
	var err_hi := -(1 << 30)
	var err_frames := 0
	while true:
		var t_dev := tick * period * 1e6 / mix_rate
		if t_game >= end_us and t_dev >= end_us:
			break
		if t_game <= t_dev:
			if ci < contacts.size() and float(contacts[ci]) <= t_game:
				var q := capacity - gp.get_frames_available()
				var gap_at: int = seq.clock
				var at: int = seq.drop_now(["landing"])
				seq.schedule_enter(at + 4 * seq.bar, STEMS)
				pending.append({"t_c": float(contacts[ci]), "gap": gap_at, "drop": at, "queued": q, "gap_us": -1.0, "drop_us": -1.0,
					"click": false, "click_frame": device_frame_near(at, step), "nominal_frame": int(round((at + GEN_LEAD) * mix_rate / RATE))})
				ci += 1
			seq.pump(gp, capacity, fill)
			var err: int = seq.audible_sample(capacity - gp.get_frames_available()) - transport_at(dev, step)
			err_lo = mini(err_lo, err)
			err_hi = maxi(err_hi, err)
			err_frames += 1
			max_q = maxi(max_q, capacity - gp.get_frames_available())
			game_frames += 1
			t_game += frame_us + (hitch_us if game_frames % hitch_every == 0 else 0.0)
			continue
		min_q = mini(min_q, capacity - gp.get_frames_available())
		var out := gp.mix_audio(1.0, period)
		var still := []
		for p in pending:
			var g: int = p["gap"]
			var d: int = p["drop"]
			var dg := device_frame_from(g, step)
			if float(p["gap_us"]) < 0.0 and dg < dev + period:
				p["gap_us"] = (dg - dev) * 1e6 / mix_rate + t_dev - float(p["t_c"])
			# Silent where the interpolation reads only gap samples: at RATE the output is
			# exactly one sample, elsewhere it reads one before and two after.
			var lo := g if exact else g + 1
			var hi := d if exact else d - 2
			for i in range(maxi(dev, device_frame_from(lo, step)), mini(dev + period, device_frame_from(hi, step))):
				if out[i - dev] != Vector2.ZERO:
					gap_nonzero += 1
			var dc: int = p["click_frame"]
			if dc >= dev and dc < dev + period:
				p["drop_us"] = (dc - dev) * 1e6 / mix_rate + t_dev - float(p["t_c"])
				var v := absf(out[dc - dev].x)
				var before := absf(out[dc - dev - 1].x) if dc > dev else 0.0
				var after := absf(out[dc - dev + 1].x) if dc + 1 < dev + period else 0.0
				p["click"] = v > 0.4 and v > before and v > after
				done.append(p)
			else:
				still.append(p)
		pending = still
		dev += period
		tick += 1
	return {"skips": gp.get_skips(), "max_q": max_q, "min_q": min_q, "contacts": done, "gap_nonzero": gap_nonzero,
		"short": seq.short_reads, "misses": seq.misses, "frames": dev, "err_lo": err_lo, "err_hi": err_hi, "err_frames": err_frames, "step": step}


# A keyed cue fired every game frame across a lift (Eb at bar 2, the landing in D at bar
# 3, stems at bar 7): the key at audible_sample() against the key at transport_at(), the
# key the device is sounding. A misread is "chunk" when a key change sits between the
# two, the only place the ring's 128-frame granularity can hide one.
static func keyed_cue_run(fixture_dir: String, period: int, frame_us: float, gen_buffer: float) -> Dictionary:
	var seq = load(fixture_dir.get_base_dir().path_join("poc_sequencer.gd")).new(fixture_dir)
	var step := gen_step()
	var mix_rate := AudioServer.get_mix_rate()
	var b: int = seq.bar
	seq.start(STEMS)
	seq.schedule_enter(2 * b, ["lift"])
	seq.schedule_enter(3 * b, ["landing"])
	seq.schedule_enter(7 * b, STEMS)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = gen_buffer
	var gp: AudioStreamGeneratorPlayback = gen.instantiate_playback()
	gp.start(0.0)
	var capacity := gp.get_frames_available()
	var end_us := 8.0e6
	var t_game := 0.0
	var tick := 0
	var dev := 0
	var frames := 0
	var cue_wrong := 0
	var cue_wrong_chunk := 0
	var head_wrong := 0
	var accounting_off := 0
	var err_lo := 1 << 30
	var err_hi := -(1 << 30)
	var in_lift := 0
	var lift_click := false
	var landing_click := false
	var lift_frame := device_frame_near(2 * b, step)
	var landing_frame := device_frame_near(3 * b, step)
	while true:
		var t_dev := tick * period * 1e6 / mix_rate
		if t_game >= end_us and t_dev >= end_us:
			break
		if t_game <= t_dev:
			seq.pump(gp, capacity)
			var audible: int = seq.audible_sample(capacity - gp.get_frames_available())
			var truth_s := transport_at(dev, step)
			var truth: int = seq.key_at(truth_s)
			frames += 1
			in_lift += 1 if truth == 1 else 0
			var err := audible - truth_s
			err_lo = mini(err_lo, err)
			err_hi = maxi(err_hi, err)
			accounting_off += 0 if err == 0 else 1
			if seq.key_at(audible) != truth:
				cue_wrong += 1
				for entry in seq.key_log:
					if int(entry[0]) > audible and int(entry[0]) <= truth_s:
						cue_wrong_chunk += 1
						break
			head_wrong += 0 if seq.render_key() == truth else 1
			t_game += frame_us
			continue
		var out := gp.mix_audio(1.0, period)
		if lift_frame >= dev and lift_frame < dev + period:
			lift_click = absf(out[lift_frame - dev].x) > 0.4
		if landing_frame >= dev and landing_frame < dev + period:
			landing_click = absf(out[landing_frame - dev].x) > 0.4
		dev += period
		tick += 1
	return {"frames": frames, "in_lift": in_lift, "cue_wrong": cue_wrong, "cue_wrong_chunk": cue_wrong_chunk, "head_wrong": head_wrong,
		"accounting_off": accounting_off, "err_lo": err_lo, "err_hi": err_hi, "lift_click": lift_click, "landing_click": landing_click,
		"skips": gp.get_skips(), "key_log": seq.key_log, "step": step}
