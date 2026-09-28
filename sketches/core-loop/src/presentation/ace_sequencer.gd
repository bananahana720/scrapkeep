extends RefCounted

# The ACE band for Spillway (design-v3 ACE-MUSIC-SYSTEM; the runtime rules proven by the
# POC sequencer, core-loop-v3-seq 43453ab). ACE-Step performed the music; this plays its
# Demucs stems (drums, bass, other) from the clips tools/ace/package_music.py cut, and
# follows the game by switching sections on its own bar and beat grid.
#
# The music follows the player in systemic play: calm or travel on the shelf, the pivot
# on the drop-line commit, the Warden build looping bars 9 to 16, the telegraph, the open
# as a held breath, and the drop on the next beat after contact. A Warden break is the
# one directed passage: break, return and home play start to finish whatever the game
# does, then systemic play resumes.
#
# The rules copied from the POC, each measured there:
#   - every stem is pulled with mix_audio(mix_rate / RATE, n), the same n for every stem,
#     split at every scheduled action and one-shot exit;
#   - a decoder opens with start((sample + 0.5) / RATE) and drops its LEAD_IN frames;
#   - loops are native, loop and loop_offset from the manifest;
#   - the ring is pumped to QUEUE_TARGET queued frames, not full;
#   - every key change is logged by transport sample, and keyed SFX read the key at the
#     audible sample, clock - queued - GEN_LEAD - output latency;
#   - a contact starts the gap at the render head and drops on the next beat after it.
# Section edges crossfade over the manifest's join (10 ms) or the breath style's ramp,
# ending on the edge, so a downbeat always lands at its full level.

const RATE := 44100
const LEAD_IN := 2
const GEN_LEAD := 130
const QUEUE_TARGET := 3072
const MANIFEST := "res://assets/music_ace/spillway/manifest.json"
const BREATHS := ["raw", "hard", "gentle"]
# The render head goes quiet over this many frames when a contact starts the gap.
const GAP_RAMP := 96
const STOP_RAMP := 441
const DUCK_DOWN := 400.0
const PAUSE_RAMP := 2048.0
const BAY_RAMP := 8820
# Pressure that moves the shelf from calm to travel, and back.
const TRAVEL_UP := 0.4
const TRAVEL_DOWN := 0.2
const TRAVEL_THREAT := 2
const PROTECTED := ["pivot", "drop", "break", "return", "home"]


class Voice:
	var stem := ""
	var pb: AudioStreamPlayback
	var pos := 0
	var exit := 0
	var count := 0
	var loop := false
	var loop_offset := 0
	var gain := 0.0
	var target := 0.0
	var step := 0.0
	var lp := PackedFloat64Array()
	var z := PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0])
	var wet := 0.0
	var wet_target := 0.0
	var wet_step := 0.0


var manifest := {}
var clips := {}
var sections := {}
var streams := {}
var stems: Array = []
# The first file the package lacks, or "" when every file loaded.
var missing := ""
var rate_scale := 1.0
var level := 1.0

var clock := 0
var out := PackedVector2Array()
# [transport sample, key offset from D] at every key change.
var key_log: Array = []
# [kind, transport sample, detail]: enter, gap, then, release, miss, stop.
var events_log: Array = []
var short_reads := 0
var misses := 0
var render_usec := 0
var rendered := 0

# The section sounding at the render head, its grid and voices.
var section := ""
var origin := 0
var grid_bar := 61536
var grid_beat := 15384
var voices: Array = []
var fading: Array = []
var actions: Array = []
var pending := {}
var solo: Array = []

var breath := "hard"
var mode := "off"
var warden_state := "closed"
var pressure := 0.0
var threat := 0
var in_bay := false
var built := false
var hold_until := -1
var piece_after_drop := false

var duck_level := 1.0
var duck_target := 1.0
var duck_until := 0
var pause_gain := 1.0
var pause_level := 1.0
var _serial := 0


func _init(manifest_path := MANIFEST) -> void:
	rate_scale = AudioServer.get_mix_rate() / float(RATE)
	var path := ProjectSettings.globalize_path(manifest_path)
	if not FileAccess.file_exists(path):
		missing = path
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.has("clips"):
		missing = path + " (unreadable)"
		return
	manifest = parsed
	clips = manifest["clips"]
	sections = manifest["sections"]
	stems = manifest["stems"]
	level = db_to_linear(float(manifest.get("level_db", 0.0)))
	breath = String(manifest.get("breath_default", "hard"))
	var dir := path.get_base_dir()
	for id in clips:
		var clip: Dictionary = clips[id]
		for stem in stems:
			var file := dir.path_join(String(clip["files"][stem]))
			if not FileAccess.file_exists(file):
				missing = file
				return
			var stream := AudioStreamOggVorbis.load_from_file(file)
			if stream == null:
				missing = file + " (not Ogg Vorbis)"
				return
			stream.loop = bool(clip["loop"])
			stream.loop_offset = float(clip["loop_offset"]) / RATE
			streams[file] = stream
			clip["paths"] = clip.get("paths", {})
			clip["paths"][stem] = file


func ready() -> bool:
	return missing == "" and not clips.is_empty()


# Something is sounding or about to: the director renders the band while this is true.
func active() -> bool:
	return mode != "off" or not voices.is_empty() or not fading.is_empty()


# The transport sample the band first sounds from: now when voices play, the pending
# section's fade-in when one is waiting, -1 when nothing is on the way. The synth band
# hands over here.
func sound_from() -> int:
	if mode == "off":
		return -1
	if not voices.is_empty():
		return clock
	if not pending.is_empty():
		return int(pending["begin"])
	return -1


# --- Facts the audio director hands over ------------------------------------------------

# A stage starts on the shelf: calm (or travel) from bar 1 at transport sample at. A
# restart while the band sounds fades the old section out and gives the new one its
# full join, so no one-shot is left without a follower.
func start_level(at: int) -> void:
	_cancel_pending()
	actions.clear()
	var earliest := clock
	if not voices.is_empty():
		for v: Voice in voices:
			_ramp_to(v, 0.0, STOP_RAMP)
			fading.append(v)
		voices.clear()
		earliest = clock + _ramp_frames(float(manifest.get("join_ms", 10.0)))
	section = ""
	mode = "level"
	built = false
	piece_after_drop = false
	hold_until = -1
	warden_state = "closed"
	threat = 0
	_schedule(_desired(), maxi(at, earliest))


# The band stops: every voice fades over ramp frames (a beat when a launch takes the
# music, STOP_RAMP otherwise).
func stop(ramp := STOP_RAMP) -> void:
	_cancel_pending()
	actions.clear()
	mode = "off"
	for v: Voice in voices:
		_ramp_to(v, 0.0, ramp)
		fading.append(v)
	voices.clear()
	section = ""
	events_log.append(["stop", clock, ""])


func set_pressure(value: float) -> void:
	pressure = value
	_follow()


func threat_rose(tier: int) -> void:
	threat = maxi(threat, tier)
	_follow()


func set_bay(on: bool) -> void:
	in_bay = on
	if section in ["calm", "travel"]:
		_retarget(BAY_RAMP)


# The ball committed to a drop line, or the Warden engaged: the pivot at the next bar.
func commit_warden() -> void:
	if mode != "level":
		return
	mode = "warden"
	_cancel_pending()
	_schedule("pivot", _landing("pivot", false))


func set_warden_state(state: String) -> void:
	warden_state = state
	_follow()


# Contact on the core: the render head goes quiet now and the drop enters on the next
# beat. Returns the drop's transport sample, or -1 when nothing plays or the break has
# begun.
func drop_now() -> int:
	if mode == "off" or (mode == "piece" and not piece_after_drop and section in ["break", "return", "home"]):
		return -1
	if mode == "piece" and pending.get("section", "") == "break":
		piece_after_drop = true
	if mode == "level":
		mode = "warden"
	_cancel_pending()
	# The next beat with room for the drop's full fade-in: a contact on (or just before)
	# a beat drops on the one after, never with a one-frame join.
	var at := next_beat(clock + maxi(GAP_RAMP, _ramp_frames(float(manifest.get("join_ms", 10.0)))))
	for v: Voice in voices:
		_ramp_to(v, 0.0, GAP_RAMP)
		fading.append(v)
	voices.clear()
	events_log.append(["gap", clock, section])
	_schedule("drop", at)
	return at


# The Warden broke: the directed set piece, once. After a drop still sounding, it waits
# for the drop's end; otherwise it enters on the next bar.
func warden_broken() -> void:
	if mode == "off" or mode == "piece":
		return
	mode = "piece"
	if pending.get("section", "") == "drop" or (section == "drop" and pending.is_empty()):
		piece_after_drop = true
		return
	var at := _landing("break", false)
	if section == "drop":
		# The drop's follower is already scheduled: the break takes its place, on the
		# first bar of the drop's grid at or after it (a follower may sit on a beat).
		at = next_bar(maxi(int(pending["at"]), clock + _join_frames("break")))
	_cancel_pending()
	_schedule("break", at)


func set_breath(style: String) -> void:
	if not style in BREATHS:
		return
	breath = style
	if section in ["open", "break"]:
		_retarget(_ramp_frames(float(manifest["breath"][breath]["ramp_in_ms"])))


func duck(amount: float, hold_seconds: float) -> void:
	duck_target = minf(duck_target, clampf(amount, 0.1, 1.0))
	duck_until = maxi(duck_until, clock + int(hold_seconds * RATE))


# --- The grid -------------------------------------------------------------------------

func next_beat(from := -1) -> int:
	return _next(grid_beat, from)


func next_bar(from := -1) -> int:
	return _next(grid_bar, from)


func _next(unit: int, from: int) -> int:
	var base := maxi(clock, from)
	if section == "":
		return base
	return origin + int(ceil(float(base - origin) / unit)) * unit


# The first bar (or beat) far enough ahead for name's whole crossfade: a change asked on
# the grid itself, or inside the join before it, lands on the next grid point.
func _landing(name: String, on_beat: bool) -> int:
	var from := clock + _join_frames(name)
	return next_beat(from) if on_beat else next_bar(from)


func key_at(s: int) -> int:
	var key := 0
	for entry in key_log:
		if int(entry[0]) > s:
			break
		key = int(entry[1])
	return key


# The next transport sample to reach the speaker, given the ring's queued frames. Exact
# at a 44.1 kHz mixer; at other rates it trails by under GEN_CHUNK frames (POC 43453ab).
func audible_sample(queued: int) -> int:
	return clock - queued - GEN_LEAD - int(round(AudioServer.get_output_latency() * RATE))


# The frames that top the ring up to target queued frames. capacity is the ring's frames
# available when empty.
func frames_to_pump(gp: AudioStreamGeneratorPlayback, capacity: int, target := QUEUE_TARGET) -> int:
	return clampi(target - (capacity - gp.get_frames_available()), 0, gp.get_frames_available())


# --- Rendering ------------------------------------------------------------------------

# Advances the transport without decoding: the band is not playing.
func advance(n: int) -> void:
	clock += n


func render(n: int) -> PackedVector2Array:
	var t0 := Time.get_ticks_usec()
	out.resize(n)
	var done := 0
	while done < n:
		while not actions.is_empty() and int(actions[0]["at"]) <= clock:
			_run(actions.pop_front())
		var span := n - done
		if not actions.is_empty():
			span = mini(span, int(actions[0]["at"]) - clock)
		var ended: Voice = null
		var faded: Voice = null
		for list in [voices, fading]:
			for v: Voice in list:
				if not v.loop:
					var left := v.exit - v.pos
					if left <= 0:
						if list == voices:
							ended = v
						else:
							faded = v
					span = mini(span, left)
				if v.gain != v.target:
					span = mini(span, maxi(1, int(ceil(absf(v.target - v.gain) / v.step - 0.001))))
				if v.wet != v.wet_target:
					span = mini(span, maxi(1, int(ceil(absf(v.wet_target - v.wet) / v.wet_step - 0.001))))
		if faded != null:
			# A one-shot fading out under its follower reached its exit: nothing is lost.
			fading.erase(faded)
			continue
		if ended != null:
			# A one-shot reached its exit with nothing scheduled: keep time in silence.
			misses += 1
			events_log.append(["miss", clock, ended.stem])
			voices.erase(ended)
			continue
		_mix(done, span)
		done += span
		clock += span
	fading = fading.filter(func(v: Voice) -> bool: return v.gain > 0.0 or v.target > 0.0)
	render_usec += Time.get_ticks_usec() - t0
	rendered += n
	return out


func _mix(at: int, span: int) -> void:
	if clock >= duck_until:
		duck_target = 1.0
	var d0 := duck_level
	duck_level = move_toward(duck_level, duck_target, span / (float(grid_beat) if duck_target > duck_level else DUCK_DOWN))
	var p0 := pause_level
	pause_level = move_toward(pause_level, pause_gain, span / PAUSE_RAMP)
	var l0 := level * d0 * p0
	var l1 := level * duck_level * pause_level
	var heard: Array = []
	var starts := PackedFloat64Array()
	var ends := PackedFloat64Array()
	var plain := true
	for list in [voices, fading]:
		for v: Voice in list:
			var got: PackedVector2Array = v.pb.mix_audio(rate_scale, span)
			if got.size() != span:
				short_reads += 1
				got.resize(span)
			v.pos += span
			if v.loop and v.pos >= v.count:
				v.pos = v.loop_offset + (v.pos - v.count)
			var g0 := v.gain
			v.gain = move_toward(v.gain, v.target, v.step * span)
			if absf(v.gain - v.target) < 1e-9:
				v.gain = v.target
			var w0 := v.wet
			v.wet = move_toward(v.wet, v.wet_target, v.wet_step * span)
			if (not solo.is_empty() and not v.stem in solo) or (g0 <= 0.00001 and v.gain <= 0.00001):
				continue
			if w0 > 0.0 or v.wet > 0.0:
				_lowpass(got, v, w0)
			heard.append(got)
			starts.append(g0 * l0)
			ends.append(v.gain * l1)
			var last := starts.size() - 1
			plain = plain and starts[last] == ends[last] and starts[last] == starts[0]
	if heard.is_empty():
		for i in span:
			out[at + i] = Vector2.ZERO
		return
	if plain:
		var g := starts[0]
		var a: PackedVector2Array = heard[0]
		if heard.size() == 3:
			var b: PackedVector2Array = heard[1]
			var c: PackedVector2Array = heard[2]
			for i in span:
				out[at + i] = (a[i] + b[i] + c[i]) * g
			return
		for i in span:
			out[at + i] = a[i] * g
		for k in range(1, heard.size()):
			var b: PackedVector2Array = heard[k]
			for i in span:
				out[at + i] += b[i] * g
		return
	var inv := 1.0 / span
	for k in heard.size():
		var b: PackedVector2Array = heard[k]
		var g0 := starts[k]
		var dg := (ends[k] - g0) * inv
		if k == 0:
			for i in span:
				out[at + i] = b[i] * (g0 + dg * i)
		else:
			for i in span:
				out[at + i] += b[i] * (g0 + dg * i)


# Second-order Butterworth low-pass, direct form I, mixed wet over dry as the breath asks.
func _lowpass(buf: PackedVector2Array, v: Voice, w0: float) -> void:
	var c := v.lp
	var b0 := c[0]
	var b1 := c[1]
	var b2 := c[2]
	var a1 := c[3]
	var a2 := c[4]
	var z := v.z
	var xl1 := z[0]
	var xl2 := z[1]
	var yl1 := z[2]
	var yl2 := z[3]
	var xr1 := z[4]
	var xr2 := z[5]
	var yr1 := z[6]
	var yr2 := z[7]
	var n := buf.size()
	var dw := (v.wet - w0) / n
	for i in n:
		var x := buf[i]
		var yl := b0 * x.x + b1 * xl1 + b2 * xl2 - a1 * yl1 - a2 * yl2
		var yr := b0 * x.y + b1 * xr1 + b2 * xr2 - a1 * yr1 - a2 * yr2
		xl2 = xl1
		xl1 = x.x
		yl2 = yl1
		yl1 = yl
		xr2 = xr1
		xr1 = x.y
		yr2 = yr1
		yr1 = yr
		var w := w0 + dw * i
		buf[i] = Vector2(x.x + (yl - x.x) * w, x.y + (yr - x.y) * w)
	v.z = PackedFloat64Array([xl1, xl2, yl1, yl2, xr1, xr2, yr1, yr2])


static func lowpass_coeffs(hz: float) -> PackedFloat64Array:
	var w := TAU * hz / RATE
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * sqrt(0.5))
	var a0 := 1.0 + alpha
	return PackedFloat64Array([(1.0 - cw) * 0.5 / a0, (1.0 - cw) / a0, (1.0 - cw) * 0.5 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0])


# --- Sections -------------------------------------------------------------------------

# What systemic play asks for now.
func _desired() -> String:
	match mode:
		"level":
			var up: bool = section == "travel" or pending.get("section", "") == "travel"
			if pressure >= TRAVEL_UP or threat >= TRAVEL_THREAT or (up and pressure >= TRAVEL_DOWN):
				return "travel"
			return "calm"
		"warden":
			if warden_state == "telegraph" or warden_state == "open":
				return warden_state
			return "build"
	return ""


# Moves toward what the game asks for, at the first moment a change is allowed: never
# inside a hold, never over a protected entry, never during the directed piece.
func _follow() -> void:
	if mode == "off" or mode == "piece":
		return
	if hold_until > clock:
		return
	if not pending.is_empty():
		if String(pending["section"]) in PROTECTED or bool(pending.get("begun", false)):
			return
	var want := _desired()
	if want == "" or want == pending.get("section", ""):
		return
	if pending.is_empty() and (want == section or _continues(want)):
		return
	# A drop or pivot is heard to its end before the build comes back.
	if want == "build" and section in ["drop", "pivot"]:
		return
	_cancel_pending()
	if want == section:
		return
	var row: Dictionary = sections[want]
	_schedule(want, _landing(want, row["enter"] == "beat"))


# home and calm share a clip: the release from home into calm plays on without a join.
func _continues(want: String) -> bool:
	if section == "" or not sections.has(want):
		return false
	if sections[want]["clip"] != sections[section]["clip"] or voices.is_empty():
		return false
	section = want
	_retarget(BAY_RAMP)
	return true


func _profile(name: String) -> Dictionary:
	var row: Dictionary = sections[name]
	if row["profile"] == "breath":
		return manifest["breath"][breath]["stems"]
	if in_bay and name in ["calm", "travel"]:
		return manifest["profiles"]["lounge"]
	return manifest["profiles"][row["profile"]]


func _ramp_frames(ms: float) -> int:
	return maxi(1, int(round(ms * RATE / 1000.0)))


# The crossfade into name: the join, or longer where the breath style ramps longer.
func _join_frames(name: String) -> int:
	var ms := float(manifest.get("join_ms", 10.0))
	var b: Dictionary = manifest["breath"][breath]
	if sections[name]["profile"] == "breath":
		ms = maxf(ms, float(b["ramp_in_ms"]))
	if section != "" and sections[section]["profile"] == "breath":
		ms = maxf(ms, float(b["ramp_out_ms"]))
	return mini(_ramp_frames(ms), int(manifest.get("pre_roll", 4096)))


# Schedules name to take over at transport sample at: its decoders open now, positioned
# so their fade-in ends on at.
func _schedule(name: String, at: int) -> void:
	var row: Dictionary = sections[name]
	var clip: Dictionary = clips[row["clip"]]
	var entry := int(clip["entry"])
	if name == "build" and built:
		entry += (int(row.get("reenter_bar", 1)) - 1) * int(clip["bar"])
	if row["phase"] == "keep" and section != "" and int(clip["beat"]) == grid_beat:
		var beat_in_bar := posmod(int(round(float(at - origin) / grid_beat)), int(clip["beats_per_bar"]))
		entry += beat_in_bar * int(clip["beat"])
	var begin := maxi(clock, at - _join_frames(name))
	var fresh: Array = []
	var gains := _profile(name)
	for stem in stems:
		fresh.append(_open(clip, stem, entry - (at - begin), gains[stem], at - begin))
	_serial += 1
	pending = {"section": name, "at": at, "begin": begin, "entry": entry, "voices": fresh, "serial": _serial}
	_add({"at": begin, "type": "begin", "serial": _serial})
	_add({"at": at, "type": "commit", "serial": _serial})


func _open(clip: Dictionary, stem: String, from: int, gains: Dictionary, ramp: int) -> Voice:
	var v := Voice.new()
	v.stem = stem
	v.pb = streams[clip["paths"][stem]].instantiate_playback()
	v.pb.start((from + 0.5) / RATE)
	var lead := v.pb.mix_audio(rate_scale, LEAD_IN)
	if lead.size() != LEAD_IN:
		short_reads += 1
	v.pos = from
	v.exit = int(clip["exit"])
	v.count = int(clip["sample_count"])
	v.loop = bool(clip["loop"])
	v.loop_offset = int(clip["loop_offset"])
	var g := _gain_of(gains)
	var hz = gains.get("lowpass_hz")
	if hz != null:
		v.lp = lowpass_coeffs(float(hz))
		v.wet = 1.0
		v.wet_target = 1.0
		v.wet_step = 1.0
	if ramp <= 0:
		v.gain = g
		v.target = g
		v.step = 1.0
	else:
		_ramp_to(v, g, ramp)
	return v


func _gain_of(stem_row: Dictionary) -> float:
	var db := float(stem_row["volume_db"])
	return 0.0 if db <= float(manifest.get("silent_db", -80.0)) else db_to_linear(db)


func _ramp_to(v: Voice, g: float, frames: int) -> void:
	v.target = g
	v.step = maxf(absf(g - v.gain), 0.000001) / maxf(frames, 1)


# The live voices move to the current profile: the bay, or a breath style flipped mid-open.
func _retarget(frames: int) -> void:
	var gains := _profile(section)
	for v: Voice in voices:
		var row: Dictionary = gains[v.stem]
		_ramp_to(v, _gain_of(row), frames)
		var hz = row.get("lowpass_hz")
		if hz != null:
			if v.lp.is_empty() or v.wet_target == 0.0:
				v.lp = lowpass_coeffs(float(hz))
				v.z = PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0])
				v.wet = 0.0
			v.wet_target = 1.0
		else:
			v.wet_target = 0.0
		v.wet_step = 1.0 / maxf(frames, 1)


func _add(action: Dictionary) -> void:
	var i := 0
	while i < actions.size() and int(actions[i]["at"]) <= int(action["at"]):
		i += 1
	actions.insert(i, action)


func _cancel_pending() -> void:
	if pending.is_empty():
		return
	var serial: int = pending["serial"]
	actions = actions.filter(func(a: Dictionary) -> bool: return int(a.get("serial", -1)) != serial)
	if bool(pending.get("begun", false)):
		for v: Voice in pending["voices"]:
			voices.erase(v)
			_ramp_to(v, 0.0, GAP_RAMP)
			fading.append(v)
	pending = {}


func _run(action: Dictionary) -> void:
	match action["type"]:
		"begin":
			if pending.is_empty() or int(pending["serial"]) != int(action["serial"]):
				return
			pending["begun"] = true
			var ramp := int(pending["at"]) - clock
			for v: Voice in voices:
				_ramp_to(v, 0.0, maxi(ramp, 1))
				fading.append(v)
			voices = (pending["voices"] as Array).duplicate()
		"commit":
			if pending.is_empty() or int(pending["serial"]) != int(action["serial"]):
				return
			_commit()
		"then":
			if int(action["serial"]) == _serial and pending.is_empty() and section == action["section"]:
				_then(action)
		"release":
			if section == action["section"] and mode == "piece":
				events_log.append(["release", clock, section])
				mode = "level"
				_follow()
		"follow":
			_follow()


func _commit() -> void:
	var name: String = pending["section"]
	var row: Dictionary = sections[name]
	var clip: Dictionary = clips[row["clip"]]
	var entry: int = pending["entry"]
	pending = {}
	fading = fading.filter(func(v: Voice) -> bool: return v.gain > 0.0 or v.target > 0.0)
	section = name
	grid_bar = int(clip["bar"])
	grid_beat = int(clip["beat"])
	origin = clock - posmod(entry - int(clip["entry"]), grid_bar)
	var key := int(clip.get("key_offset", 0))
	if key_log.is_empty() or int(key_log[-1][1]) != key:
		key_log.append([clock, key])
	events_log.append(["enter", clock, name])
	if name == "build":
		built = true
	hold_until = clock + int(row.get("hold_bars", 0)) * grid_bar if row.has("hold_bars") else -1
	var length := -1
	if row.has("bars"):
		length = int(row["bars"]) * grid_bar
	elif not bool(clip["loop"]):
		length = int(clip["exit"]) - entry
	if length > 0 and row.has("then"):
		var end := clock + length
		if row["then"] == "release":
			_add({"at": end, "type": "release", "section": name})
		elif row["then"] == "follow":
			_add({"at": maxi(clock, end - int(manifest.get("pre_roll", 4096))), "type": "then", "section": name,
				"end": end, "serial": _serial})
		else:
			_schedule(String(row["then"]), end)
	if hold_until > clock:
		_add({"at": hold_until, "type": "follow"})
	_follow()


# A one-shot ends: the drop hands to the break when the Warden broke under it, otherwise
# to whatever the game asks for now.
func _then(action: Dictionary) -> void:
	var end: int = action["end"]
	if mode == "piece":
		piece_after_drop = false
		_schedule("break", end)
		return
	var want := _desired()
	if want == "":
		return
	_schedule(want, end)
