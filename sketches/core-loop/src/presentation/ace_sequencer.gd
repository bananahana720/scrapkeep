extends RefCounted

const MusicRows := preload("res://src/presentation/music_rows.gd")
const TuneMoments := preload("res://src/presentation/tune_moments.gd")
const DeckMoves := preload("res://src/presentation/deck_moves.gd")


const RATE := 44100
const LEAD_IN := 2
const GEN_LEAD := 130
const QUEUE_TARGET := 3072
const MANIFEST: String = MusicRows.ROWS["1-1"]["ace_manifest"]
const BREATHS := ["raw", "hard", "gentle"]
const GAP_RAMP := 96
const STOP_RAMP := 441
const DUCK_DOWN := 400.0
const PAUSE_RAMP := 2048.0
const BAY_RAMP := 8820
const TRAVEL_UP := 0.4
const TRAVEL_DOWN := 0.2
const TRAVEL_THREAT := 2
const GUARD_TIGHT := 75.0
const GUARD_LOOSE := 50.0
const ULTIMATE_STEP := 0.4
const DRUMS_IN_SPEED := 0.25
const DRUMS_FULL_SPEED := 0.5
const LEAD_FLOOR := 0.5
const LEAD_RETURN := ["return", "home"]
const LEAD_WHOLE := ["open", "drop"]
const PROTECTED := ["pivot", "drop", "break", "return", "home"]
const SHELF_CLIPS := ["calm", "travel"]


class Voice:
	var stem := ""
	var section_name := ""
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
	var pump_depth := 0.0
	var pump_target := 0.0
	var pump_step := 0.0
	var cleared := false


class Shot:
	var at := 0
	var pcm: PackedVector2Array
	var tag := ""
	var gain := 1.0
	var env := 1.0
	var env_target := 1.0
	var env_step := 0.0


var manifest := {}
var flat := false
var manifest_source := ""
var clips := {}
var sections := {}
var streams := {}
var stems: Array = []
const KEPT_PACKAGES := 5
static var _kept := {}
static var _kept_order: Array[String] = []
static var _kept_lock := Mutex.new()
var missing := ""
var rate_scale := 1.0
var level := 1.0

var clock := 0
var out := PackedVector2Array()
var key_log: Array = []
var events_log: Array = []
var short_reads := 0
var misses := 0
var render_usec := 0
var trims := {}
var trim_epoch := 0
var _pump_depths := {}
var shots: Array = []
var sweep := 0.0
const SWEEP_HZ := 420.0
var rendered := 0
var opened := 0
var open_usec := 0

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
var ultimate_lift := false
var parameter_enabled := false
var parameters := {}
var parameter_released := false
var lead_returned := false
var parameter_layer_log: Array = []
var _parameter_danger_floor := 0.0
var fight_floor := 0.0
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


static func resolve_manifest(manifest_path: String, sidecar_dir := "") -> String:
	return MusicRows.resolve_manifest(manifest_path, sidecar_dir)


static func from_stage(stage = "default", sidecar_dir := "", stages = MusicRows.StageDefs) -> RefCounted:
	var pack := MusicRows.resolve(stage, sidecar_dir, stages)
	return load("res://src/presentation/ace_sequencer.gd").new(pack["ace_manifest"], sidecar_dir)


func _init(manifest_path := MANIFEST, sidecar_dir := "") -> void:
	rate_scale = AudioServer.get_mix_rate() / float(RATE)
	if manifest_path == "":
		return
	var path := resolve_manifest(manifest_path, sidecar_dir)
	manifest_source = path
	if path == "":
		missing = ProjectSettings.globalize_path(manifest_path)
		_report()
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.has("clips"):
		missing = path + " (unreadable)"
		_report()
		return
	manifest = parsed
	flat = bool(manifest.get("flat", false))
	clips = manifest["clips"]
	sections = manifest["sections"]
	stems = manifest["stems"]
	level = db_to_linear(float(manifest.get("level_db", 0.0)))
	breath = String(manifest.get("breath_default", "hard"))
	_kept_lock.lock()
	var kept: Dictionary = _kept.get(path, {})
	_kept_lock.unlock()
	for id in clips:
		var clip: Dictionary = clips[id]
		for stem in stems:
			var file := MusicRows.stem_file(path, String(clip["files"][stem]))
			var stream: AudioStreamOggVorbis = kept.get(file)
			if stream == null:
				if not FileAccess.file_exists(file):
					missing = file
					_report()
					return
				stream = AudioStreamOggVorbis.load_from_file(file)
				if stream == null:
					missing = file + " (not Ogg Vorbis)"
					_report()
					return
				stream.loop = bool(clip["loop"])
				stream.loop_offset = float(clip["loop_offset"]) / RATE
			streams[file] = stream
			clip["paths"] = clip.get("paths", {})
			clip["paths"][stem] = file
	_keep(path, streams)
	_report()


static func kept(manifest_path: String, sidecar_dir := "") -> bool:
	var path := resolve_manifest(manifest_path, sidecar_dir)
	_kept_lock.lock()
	var held := _kept.has(path)
	_kept_lock.unlock()
	return held


static func _keep(path: String, read: Dictionary) -> void:
	_kept_lock.lock()
	_kept[path] = read
	_kept_order.erase(path)
	_kept_order.append(path)
	while _kept_order.size() > KEPT_PACKAGES:
		_kept.erase(_kept_order.pop_front())
	_kept_lock.unlock()


func _report() -> void:
	if "--ace-check" in OS.get_cmdline_args() or "--ace-check" in OS.get_cmdline_user_args():
		print("ACE_CHECK ready=%s clips=%d streams=%d missing=%s" % [ready(), clips.size(), streams.size(), missing])


func ready() -> bool:
	return missing == "" and not clips.is_empty()


func active() -> bool:
	return mode != "off" or not voices.is_empty() or not fading.is_empty() or not shots.is_empty()


func sound_from() -> int:
	if mode == "off":
		return -1
	if not voices.is_empty():
		return clock
	if not pending.is_empty():
		return int(pending["begin"])
	return -1


func start_level(at: int, fight := false) -> void:
	var faded := _cancel_pending(STOP_RAMP)
	actions.clear()
	var earliest := clock
	if faded:
		earliest = clock + _ramp_frames(float(manifest.get("join_ms", 10.0)))
	if not voices.is_empty():
		for v: Voice in voices:
			_ramp_to(v, 0.0, STOP_RAMP)
			fading.append(v)
		voices.clear()
		earliest = clock + _ramp_frames(float(manifest.get("join_ms", 10.0)))
	section = ""
	trims = {}
	trim_epoch += 1
	sweep = 0.0
	cancel_shots("", STOP_RAMP)
	mode = "level"
	built = false
	lead_returned = false
	piece_after_drop = false
	hold_until = -1
	warden_state = "closed"
	threat = 0
	pressure = float(parameters.get("threat", 0.0)) if parameter_enabled else 0.0
	in_bay = false
	if fight and not flat:
		mode = "warden"
		_schedule("pivot", maxi(at, earliest))
		return
	_schedule(_desired(), maxi(at, earliest))


func stop(ramp := STOP_RAMP) -> void:
	_cancel_pending(ramp)
	actions.clear()
	mode = "off"
	for v: Voice in voices:
		_ramp_to(v, 0.0, ramp)
		fading.append(v)
	voices.clear()
	section = ""
	trims = {}
	trim_epoch += 1
	sweep = 0.0
	cancel_shots("", ramp)
	events_log.append(["stop", clock, ""])


func start_menu(at: int, won := true) -> void:
	start_level(at)
	_cancel_pending()
	actions.clear()
	mode = "menu"
	var name := "main" if flat else "calm"
	if flat:
		pass
	elif manifest.get("theme", "") == "summary":
		name = "return" if won else "travel"
	_schedule(name, maxi(at, clock + _join_frames(name)))


func start_boss(at: int) -> void:
	start_level(at)
	_cancel_pending()
	actions.clear()
	mode = "warden"
	var first := "main" if flat else "pivot"
	_schedule(first, maxi(at, clock + _join_frames(first)))


func stop_at(at: int, ramp := STOP_RAMP) -> void:
	if mode == "off":
		return
	_add({"at": maxi(at, clock), "type": "stop", "ramp": ramp})


func trim_at(at: int, next: Dictionary, frames: int, epoch := -1) -> void:
	_add({"at": maxi(at, clock), "type": "trim", "trims": next.duplicate(), "frames": maxi(frames, 1), "epoch": epoch})


func trim_bar(at: int, next: Dictionary, bar: int, ramp: int, depth := 0.0, epoch := -1) -> void:
	if not next.is_empty():
		trim_at(at - ramp, next, ramp, epoch)
	if depth > 0.0:
		_add({"at": maxi(at, clock), "type": "sweep", "depth": depth, "frames": maxi(bar - ramp, 1), "epoch": epoch})
	_add({"at": maxi(at + bar - ramp, clock), "type": "trim", "trims": {}, "frames": maxi(ramp, 1), "sweep": 0.0, "epoch": -1})


func invalidate_trims(ramp := STOP_RAMP) -> void:
	trim_epoch += 1
	actions = actions.filter(func(a: Dictionary) -> bool:
		var t := String(a.get("type", ""))
		if t == "sweep":
			return false
		if t == "trim" and not (a.get("trims", {}) as Dictionary).is_empty():
			return false
		return true)
	if not trims.is_empty() or sweep > 0.0:
		_add({"at": clock, "type": "trim", "trims": {}, "frames": maxi(ramp, 1), "sweep": 0.0, "epoch": -1})


func set_pump(depth_by_section: Dictionary) -> void:
	if depth_by_section == _pump_depths:
		return
	_pump_depths = depth_by_section.duplicate()
	var ramp := float(maxi(grid_beat, 1))
	for list in [voices, fading]:
		for v: Voice in list:
			var want := pump_depth_for(v.stem, v.section_name)
			if not is_equal_approx(want, v.pump_target):
				v.pump_target = want
				v.pump_step = maxf(absf(want - v.pump_depth), 0.000001) / ramp
	if not pending.is_empty() and not bool(pending.get("begun", false)):
		for v: Voice in pending["voices"]:
			var want := pump_depth_for(v.stem, v.section_name)
			v.pump_depth = want
			v.pump_target = want
			v.pump_step = 0.0


func pump_depth_for(stem: String, sec_name: String) -> float:
	if flat or not stem in DeckMoves.PUMP_STEMS:
		return 0.0
	return clampf(float(_pump_depths.get(sec_name, 0.0)), 0.0, 1.0)


func pump_active() -> bool:
	return not flat and not _pump_depths.is_empty()


func _has_active_pump() -> bool:
	for list in [voices, fading]:
		for v: Voice in list:
			if v.pump_depth > 0.0 or v.pump_target > 0.0:
				return true
	return false


func shot_at(at: int, pcm: PackedVector2Array, tag: String, gain := 1.0) -> void:
	if pcm.is_empty() or gain <= 0.0 or at + pcm.size() <= clock:
		return
	var s := Shot.new()
	s.at = at
	s.pcm = pcm
	s.tag = tag
	s.gain = gain
	shots.append(s)


func cancel_shots(tag := "", ramp := GAP_RAMP) -> void:
	if shots.is_empty():
		return
	var kept: Array = []
	for s: Shot in shots:
		if tag != "" and s.tag != tag:
			kept.append(s)
			continue
		if s.at >= clock or ramp <= 0:
			continue
		s.env_target = 0.0
		s.env_step = maxf(s.env_step, maxf(s.env, 0.000001) / float(maxi(ramp, 1)))
		if s.env > 0.0:
			kept.append(s)
	shots = kept


func _sweep_to(depth: float, frames: int) -> void:
	sweep = depth
	var begun := bool(pending.get("begun", false))
	var live := String(pending["section"]) if begun else section
	if live == "":
		return
	var gains := _profile(live)
	var reach := mode != "piece" and not live in PROTECTED and not live in LEAD_WHOLE
	for v: Voice in voices:
		var row: Dictionary = gains.get(v.stem, {})
		if row.get("lowpass_hz") != null:
			continue
		var want := depth if reach else 0.0
		if want > 0.0 and v.wet <= 0.0 and v.wet_target <= 0.0:
			v.lp = lowpass_coeffs(SWEEP_HZ)
			v.z = PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0])
		v.wet_target = want
		v.wet_step = maxf(absf(want - v.wet), 0.000001) / maxf(frames, 1)


func _trim_voices(list: Array, name: String, stems: Array, frames: int) -> void:
	var gains := _profile(name)
	for v: Voice in list:
		if v.stem in stems and gains.has(v.stem):
			var g := _gain_of(gains[v.stem], v.stem, name)
			if not is_equal_approx(g, v.target):
				_ramp_to(v, g, frames)


func trim_of(stem: String, at := "") -> float:
	var name := section if at == "" else at
	if mode == "piece" or name in PROTECTED or name in LEAD_WHOLE:
		return 1.0
	return clampf(float(trims.get(stem, 1.0)), 0.0, 1.0)


func set_pressure(value: float) -> void:
	pressure = value
	_follow()


func commit_parameters(at: int, values: Dictionary, released: bool, lift: bool, reason: String, timing: Dictionary = {}) -> void:
	parameter_enabled = true
	_add({"at": maxi(at, clock), "type": "parameters", "values": values.duplicate(), "released": released, "lift": lift, "reason": reason, "timing": timing.duplicate()})


func set_fight_floor(value: float) -> void:
	if value == fight_floor:
		return
	fight_floor = value
	if section != "":
		_retarget(STOP_RAMP)


func clear_release() -> void:
	for action in actions:
		if action["type"] == "parameters":
			action["released"] = false
	if parameter_released:
		_run({"type": "parameters", "values": parameters, "released": false, "lift": ultimate_lift, "reason": "arena", "timing": {}})


func parameter_gain(stem: String, at := "") -> float:
	if not parameter_enabled or not parameters.has("threat"):
		return 1.0
	if stem == "drums":
		if mode != "level" or not parameters.has("speed"):
			return 1.0
		return clampf(smoothstep(DRUMS_IN_SPEED, DRUMS_FULL_SPEED, float(parameters.speed)), 0.0, 1.0)
	if stem != "other":
		return 1.0
	var name := section if at == "" else at
	if mode == "warden" and name in LEAD_WHOLE:
		return 1.0
	var cadence := mode == "piece" and name in LEAD_RETURN
	if _lead_stripped(cadence):
		return 0.0
	if cadence:
		return 1.0
	var approach := float(parameters.get("approach", 0.0))
	if mode == "level":
		approach = clampf(approach / TuneMoments.LANDMARK_IN, 0.0, 1.0)
	var open := maxf(maxf(pressure + (ULTIMATE_STEP if ultimate_lift else 0.0), maxf(_parameter_danger_floor, fight_floor)), approach)
	var lift := clampf(maxf(open, float(parameters.get("chain", 0.0))), 0.0, 1.0)
	return lerpf(LEAD_FLOOR, 1.0, lift) if mode == "level" else lift


func _lead_stripped(cadence := false) -> bool:
	if parameters.has("armour") and float(parameters.armour) < 0.3:
		return true
	return parameter_released and not lead_returned and not cadence


func set_ultimate_lift(on: bool) -> void:
	ultimate_lift = on
	_follow()


func effective_pressure() -> float:
	return pressure + (ULTIMATE_STEP if ultimate_lift else 0.0)


func threat_rose(tier: int) -> void:
	threat = maxi(threat, tier)
	_follow()


func set_bay(on: bool) -> void:
	in_bay = on
	if section in ["calm", "travel"]:
		_retarget(BAY_RAMP)


func commit_warden() -> void:
	if flat or mode != "level":
		return
	mode = "warden"
	_cancel_pending(GAP_RAMP, true)
	_schedule("pivot", _landing("pivot", false))


func set_warden_state(state: String) -> void:
	warden_state = state
	_follow()


static func guard_state(was: String, posture: float, staggered: bool) -> String:
	if staggered:
		return "open"
	if posture >= GUARD_TIGHT or (was == "telegraph" and posture >= GUARD_LOOSE):
		return "telegraph"
	return "closed"


func follow_guard(posture: float, staggered: bool, landed: bool) -> int:
	if mode != "warden":
		return -1
	var state := guard_state(warden_state, posture, staggered)
	if landed:
		warden_state = state
		return drop_now()
	if state != warden_state:
		set_warden_state(state)
	return -1


func drop_now() -> int:
	if flat or mode in ["off", "menu"] or (mode == "piece" and not piece_after_drop and section in ["break", "return", "home"]):
		return -1
	if mode == "piece" and pending.get("section", "") == "break":
		piece_after_drop = true
	if mode == "level":
		mode = "warden"
	_cancel_pending()
	var at := next_beat(clock + maxi(GAP_RAMP, _ramp_frames(float(manifest.get("join_ms", 10.0)))))
	for v: Voice in voices:
		_ramp_to(v, 0.0, GAP_RAMP)
		fading.append(v)
	voices.clear()
	events_log.append(["gap", clock, section])
	_schedule("drop", at)
	return at


func warden_broken() -> void:
	if flat or mode in ["off", "piece", "menu"]:
		return
	mode = "piece"
	lead_returned = false
	if pending.get("section", "") == "drop" or (section == "drop" and pending.is_empty()):
		piece_after_drop = true
		return
	var at := _landing("break", false)
	if section == "drop":
		at = next_bar(maxi(int(pending["at"]), clock + _join_frames("break")))
		for v: Voice in voices:
			if not v.loop:
				at = mini(at, clock + v.exit - v.pos)
	_cancel_pending(GAP_RAMP, true)
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


func free_duck() -> void:
	duck_until = clock
	duck_target = 1.0


func next_beat(from := -1) -> int:
	return _next(grid_beat, from)


func next_bar(from := -1) -> int:
	return _next(grid_bar, from)


func _next(unit: int, from: int) -> int:
	var base := maxi(clock, from)
	var grid_origin := origin
	var step := unit
	if section == "":
		if pending.is_empty():
			return base
		var clip: Dictionary = clips[sections[String(pending["section"])]["clip"]]
		grid_origin = int(pending["at"]) - posmod(int(pending["entry"]) - int(clip["entry"]), int(clip["bar"]))
		step = int(clip["beat"]) if unit == grid_beat else int(clip["bar"])
	return grid_origin + int(ceil(float(base - grid_origin) / step)) * step


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


func audible_sample(queued: int) -> int:
	return clock - queued - GEN_LEAD - int(round(AudioServer.get_output_latency() * RATE))


func frames_to_pump(gp: AudioStreamGeneratorPlayback, capacity: int, target := QUEUE_TARGET) -> int:
	return clampi(target - (capacity - gp.get_frames_available()), 0, gp.get_frames_available())


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
		var pump_on := false
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
				if v.pump_depth > 0.0 or v.pump_target > 0.0:
					pump_on = true
					if v.pump_depth != v.pump_target:
						span = mini(span, maxi(1, int(ceil(absf(v.pump_target - v.pump_depth) / v.pump_step - 0.001))))
		if faded != null:
			fading.erase(faded)
			continue
		if ended != null:
			misses += 1
			events_log.append(["miss", clock, ended.stem])
			voices.erase(ended)
			continue
		if pump_on and grid_beat > 0:
			var k0 := posmod(clock - origin, grid_beat)
			span = mini(span, DeckMoves.next_pump_breakpoint(k0, grid_beat) - k0)
		if not shots.is_empty():
			var dead_shot: Shot = null
			for s: Shot in shots:
				if s.at > clock:
					span = mini(span, s.at - clock)
				else:
					var sleft := s.at + s.pcm.size() - clock
					if sleft <= 0 or (s.env <= 0.0 and s.env_target <= 0.0):
						dead_shot = s
						break
					span = mini(span, sleft)
					if s.env != s.env_target:
						span = mini(span, maxi(1, int(ceil(absf(s.env_target - s.env) / s.env_step - 0.001))))
			if dead_shot != null:
				shots.erase(dead_shot)
				continue
		_mix(done, span)
		done += span
		clock += span
	fading = fading.filter(func(v: Voice) -> bool: return v.gain > 0.0 or v.target > 0.0)
	if not shots.is_empty():
		shots = shots.filter(func(s: Shot) -> bool: return clock < s.at + s.pcm.size() and (s.env > 0.0 or s.env_target > 0.0))
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
	var pump_on := _has_active_pump() and grid_beat > 0
	var pump_s0 := 0.0
	var pump_s1 := 0.0
	if pump_on:
		var k0 := posmod(clock - origin, grid_beat)
		pump_s0 = DeckMoves.pump_share(k0, grid_beat)
		pump_s1 = DeckMoves.pump_share(k0 + span, grid_beat)
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
			var pd0 := v.pump_depth
			if pump_on and v.pump_depth != v.pump_target:
				v.pump_depth = move_toward(v.pump_depth, v.pump_target, v.pump_step * span)
				if absf(v.pump_depth - v.pump_target) < 1e-9:
					v.pump_depth = v.pump_target
			if (not solo.is_empty() and not v.stem in solo) or (g0 <= 0.00001 and v.gain <= 0.00001):
				continue
			if w0 > 0.0 or v.wet > 0.0:
				_lowpass(got, v, w0)
			heard.append(got)
			if pump_on and (pd0 > 0.0 or v.pump_depth > 0.0):
				starts.append(g0 * l0 * (1.0 - pd0 * pump_s0))
				ends.append(v.gain * l1 * (1.0 - v.pump_depth * pump_s1))
			else:
				starts.append(g0 * l0)
				ends.append(v.gain * l1)
			var last := starts.size() - 1
			plain = plain and starts[last] == ends[last] and starts[last] == starts[0]
	if heard.is_empty():
		for i in span:
			out[at + i] = Vector2.ZERO
	elif plain:
		var g := starts[0]
		var a: PackedVector2Array = heard[0]
		if heard.size() == 3:
			var b: PackedVector2Array = heard[1]
			var c: PackedVector2Array = heard[2]
			for i in span:
				out[at + i] = (a[i] + b[i] + c[i]) * g
		else:
			for i in span:
				out[at + i] = a[i] * g
			for k in range(1, heard.size()):
				var b: PackedVector2Array = heard[k]
				for i in span:
					out[at + i] += b[i] * g
	else:
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
	if not shots.is_empty():
		_mix_shots(at, span, l0, l1)


func _mix_shots(at: int, span: int, l0: float, l1: float) -> void:
	var inv := 1.0 / float(span)
	for s: Shot in shots:
		if s.at > clock:
			continue
		var offset := clock - s.at
		var e0 := s.env
		if s.env != s.env_target:
			s.env = move_toward(s.env, s.env_target, s.env_step * span)
			if absf(s.env - s.env_target) < 1e-9:
				s.env = s.env_target
		if e0 <= 0.00001 and s.env <= 0.00001:
			continue
		var g0 := s.gain * e0 * l0
		var g1 := s.gain * s.env * l1
		var pcm := s.pcm
		if g0 == g1:
			for i in span:
				out[at + i] += pcm[offset + i] * g0
		else:
			var dg := (g1 - g0) * inv
			for i in span:
				out[at + i] += pcm[offset + i] * (g0 + dg * i)


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


func _desired() -> String:
	if flat:
		return "main" if mode in ["level", "warden", "menu"] else ""
	match mode:
		"level":
			var up: bool = section == "travel" or pending.get("section", "") == "travel"
			var p := effective_pressure()
			if p >= TRAVEL_UP or threat >= TRAVEL_THREAT or (up and p >= TRAVEL_DOWN):
				return "travel"
			return "calm"
		"warden":
			if warden_state == "telegraph" or warden_state == "open":
				return warden_state
			return "build"
	return ""


func _follow() -> void:
	var want := _follow_target()
	if want != "":
		_schedule(want, _landing(want, sections[want]["enter"] == "beat"))


func _follow_parameters() -> void:
	var want := _follow_target()
	if want != "":
		_schedule(want, clock, true)


func _follow_target() -> String:
	if mode == "off" or mode == "piece":
		return ""
	if hold_until > clock:
		return ""
	if not pending.is_empty():
		if String(pending["section"]) in PROTECTED or bool(pending.get("begun", false)):
			return ""
	var want := _desired()
	if want == "" or want == pending.get("section", ""):
		return ""
	if pending.is_empty() and (want == section or _continues(want)):
		return ""
	if want == "build" and section in ["drop", "pivot"]:
		return ""
	_cancel_pending()
	if want == section:
		return ""
	return want


func _continues(want: String) -> bool:
	if section == "" or not sections.has(want):
		return false
	if sections[want]["clip"] != sections[section]["clip"] or voices.is_empty():
		return false
	section = want
	var ramp := float(maxi(grid_beat, 1))
	for v: Voice in voices:
		v.section_name = want
		var pd := pump_depth_for(v.stem, want)
		if not is_equal_approx(pd, v.pump_target):
			v.pump_target = pd
			v.pump_step = maxf(absf(pd - v.pump_depth), 0.000001) / ramp
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


func _join_frames(name: String) -> int:
	var ms := float(manifest.get("join_ms", 10.0))
	var b: Dictionary = manifest["breath"][breath]
	if sections[name]["profile"] == "breath":
		ms = maxf(ms, float(b["ramp_in_ms"]))
	if section != "" and sections[section]["profile"] == "breath":
		ms = maxf(ms, float(b["ramp_out_ms"]))
	return mini(_ramp_frames(ms), int(manifest.get("pre_roll", 4096)))


func _schedule(name: String, at: int, join_from_edge := false) -> void:
	var row: Dictionary = sections[name]
	var clip: Dictionary = clips[row["clip"]]
	var entry := int(clip["entry"])
	if name == "build" and built:
		entry += (int(row.get("reenter_bar", 1)) - 1) * int(clip["bar"])
	if row["phase"] == "keep" and section != "" and int(clip["beat"]) == grid_beat:
		var beat_in_bar := posmod(int(round(float(at - origin) / grid_beat)), int(clip["beats_per_bar"]))
		entry += beat_in_bar * int(clip["beat"])
	var join := _join_frames(name)
	var begin := at if join_from_edge else maxi(clock, at - join)
	var ramp := join if join_from_edge else at - begin
	if name == "pivot" and section != "" and String(sections[section]["clip"]) in SHELF_CLIPS:
		_clear_harmony(at)
	var fresh: Array = []
	var gains := _profile(name)
	for stem in stems:
		fresh.append(_open(clip, stem, entry - (at - begin), gains[stem], ramp, name))
	_serial += 1
	pending = {"section": name, "at": at, "begin": begin, "ramp": ramp, "entry": entry, "voices": fresh, "serial": _serial}
	_add({"at": begin, "type": "begin", "serial": _serial})
	_add({"at": at, "type": "commit", "serial": _serial})


func _clear_harmony(at: int) -> void:
	var frames := mini(grid_beat, maxi(at - clock, 1))
	for v: Voice in voices:
		if v.stem != "drums":
			_add({"at": maxi(clock, at - frames), "type": "clear", "voice": v, "frames": frames, "serial": _serial + 1})


func _open(clip: Dictionary, stem: String, from: int, gains: Dictionary, ramp: int, name: String) -> Voice:
	var began := Time.get_ticks_usec()
	var v := Voice.new()
	v.stem = stem
	v.section_name = name
	var pd := pump_depth_for(stem, name)
	v.pump_depth = pd
	v.pump_target = pd
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
	var g := _gain_of(gains, stem, name)
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
	opened += 1
	open_usec += Time.get_ticks_usec() - began
	return v


func _gain_of(stem_row: Dictionary, stem := "", at := "") -> float:
	var db := float(stem_row["volume_db"])
	return 0.0 if db <= float(manifest.get("silent_db", -80.0)) else db_to_linear(db) * parameter_gain(stem, at) * trim_of(stem, at)


func _ramp_to(v: Voice, g: float, frames: int) -> void:
	if v.cleared and g > 0.0:
		return
	v.target = g
	v.step = maxf(absf(g - v.gain), 0.000001) / maxf(frames, 1)


func _retarget(frames: int) -> void:
	var gains := _profile(section)
	for v: Voice in voices:
		var row: Dictionary = gains[v.stem]
		_ramp_to(v, _gain_of(row, v.stem), frames)
		var hz = row.get("lowpass_hz")
		var want := 0.0
		if hz != null:
			if v.lp.is_empty() or v.wet_target == 0.0:
				v.lp = lowpass_coeffs(float(hz))
				v.z = PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0])
				v.wet = 0.0
			want = 1.0
		elif not v.lp.is_empty() and mode != "piece" and not section in PROTECTED and not section in LEAD_WHOLE:
			want = sweep
		if want != v.wet_target:
			v.wet_target = want
			v.wet_step = 1.0 / maxf(frames, 1)


func _smooth_momentum(drums_before: float, chain_before: float, stripped_before: bool) -> void:
	var drums_moved := parameters.has("speed") and parameter_gain("drums") != drums_before
	var stripped := _lead_stripped()
	var lead_moved := parameters.has("chain") and float(parameters.chain) != chain_before and not stripped and not stripped_before
	var joining: Array = pending.get("voices", [])
	for v: Voice in voices:
		if v in joining or v.cleared:
			continue
		if (v.stem == "drums" and drums_moved) or (v.stem == "other" and lead_moved):
			_ramp_to(v, v.target, grid_beat if v.target > v.gain else grid_bar * 2)


func _add(action: Dictionary) -> void:
	var i := 0
	while i < actions.size() and int(actions[i]["at"]) <= int(action["at"]):
		i += 1
	actions.insert(i, action)


func _cancel_pending(ramp := GAP_RAMP, keep := false) -> bool:
	if pending.is_empty():
		return false
	var serial: int = pending["serial"]
	actions = actions.filter(func(a: Dictionary) -> bool: return int(a.get("serial", -1)) != serial)
	var begun := bool(pending.get("begun", false))
	if begun and not keep:
		for v: Voice in pending["voices"]:
			voices.erase(v)
			_ramp_to(v, 0.0, ramp)
			fading.append(v)
	pending = {}
	return begun


func _run(action: Dictionary) -> void:
	match action["type"]:
		"parameters":
			var previous_gain := parameter_gain("other")
			var drums_before := parameter_gain("drums")
			var chain_before := float(parameters.get("chain", 0.0))
			var stripped_before := _lead_stripped()
			var previous := parameters.duplicate()
			var previous_released := parameter_released
			var previous_lift := ultimate_lift
			parameters = action.values
			parameter_released = action.released
			if not parameter_released:
				lead_returned = false
			ultimate_lift = action.lift
			pressure = float(parameters.get("threat", 0.0))
			if action.reason != "ultimate":
				_parameter_danger_floor = 1.0 if MusicRows.danger(action.reason) else 0.0
			_follow_parameters()
			if section != "":
				_retarget(STOP_RAMP)
			if not pending.is_empty():
				var profile := _profile(String(pending.section))
				for voice: Voice in pending.voices:
					if voice.stem == "other" or voice.stem == "drums":
						var gain := _gain_of(profile[voice.stem], voice.stem, String(pending.section))
						if voice.target != gain:
							_ramp_to(voice, gain, STOP_RAMP)
			_smooth_momentum(drums_before, chain_before, stripped_before)
			if previous != parameters or previous_released != parameter_released or previous_lift != ultimate_lift or previous_gain != parameter_gain("other"):
				var targets := {}
				var performing: Array = pending.get("voices", voices) if int(pending.get("begin", -1)) == clock else voices
				for voice: Voice in performing:
					targets[voice.stem] = voice.target
				parameter_layer_log.append({"at": clock, "values": parameters.duplicate(), "released": parameter_released,
					"danger": action.reason if action.reason != "ultimate" else "", "ultimate": action.reason == "ultimate",
					"other_gain": parameter_gain("other"), "targets": targets, "timing": action.timing})
		"begin":
			if pending.is_empty() or int(pending["serial"]) != int(action["serial"]):
				return
			pending["begun"] = true
			var ramp := int(pending["ramp"])
			for v: Voice in voices:
				_ramp_to(v, 0.0, maxi(ramp, 1))
				fading.append(v)
			voices = (pending["voices"] as Array).duplicate()
		"commit":
			if pending.is_empty() or int(pending["serial"]) != int(action["serial"]):
				return
			_commit()
		"clear":
			var v: Voice = action["voice"]
			if not pending.is_empty() and int(pending["serial"]) == int(action["serial"]) and (v in voices or v in fading):
				_ramp_to(v, 0.0, int(action["frames"]))
				v.cleared = true
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
		"sweep":
			var sweep_epoch := int(action.get("epoch", -1))
			if sweep_epoch >= 0 and sweep_epoch != trim_epoch:
				return
			_sweep_to(float(action.depth), int(action.frames))
		"trim":
			var trim_action_epoch := int(action.get("epoch", -1))
			if not (action.trims as Dictionary).is_empty() and trim_action_epoch >= 0 and trim_action_epoch != trim_epoch:
				return
			if action.has("sweep"):
				_sweep_to(0.0, int(action.frames))
			var stems: Array = trims.keys()
			trims = action.trims
			for stem in trims:
				if not stem in stems:
					stems.append(stem)
			var begun := bool(pending.get("begun", false))
			var live := String(pending["section"]) if begun else section
			if live != "":
				_trim_voices(voices, live, stems, int(action.frames))
			if not pending.is_empty() and not begun:
				_trim_voices(pending["voices"], String(pending["section"]), stems, int(pending["ramp"]))
		"stop":
			stop(int(action["ramp"]))


func _commit() -> void:
	var name: String = pending["section"]
	var row: Dictionary = sections[name]
	var clip: Dictionary = clips[row["clip"]]
	var entry: int = pending["entry"]
	pending = {}
	fading = fading.filter(func(v: Voice) -> bool: return v.gain > 0.0 or v.target > 0.0)
	section = name
	trim_epoch += 1
	grid_bar = int(clip["bar"])
	grid_beat = int(clip["beat"])
	origin = clock - posmod(entry - int(clip["entry"]), grid_bar)
	var key := int(clip.get("key_offset", 0))
	if key_log.is_empty() or int(key_log[-1][1]) != key:
		key_log.append([clock, key])
	events_log.append(["enter", clock, name])
	if name == "build":
		built = true
	if name == "return" and mode == "piece":
		lead_returned = true
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
