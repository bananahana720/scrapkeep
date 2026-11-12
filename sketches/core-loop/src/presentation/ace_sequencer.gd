extends RefCounted

const MusicRows := preload("res://src/presentation/music_rows.gd")
const TuneMoments := preload("res://src/presentation/tune_moments.gd")

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
# Parameter joins use the same duration starting at their committed boundary.

const RATE := 44100
const LEAD_IN := 2
const GEN_LEAD := 130
const QUEUE_TARGET := 3072
const MANIFEST: String = MusicRows.ROWS["1-1"]["ace_manifest"]
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
# The Warden's guard (0 to 100): see guard_state.
const GUARD_TIGHT := 75.0
const GUARD_LOOSE := 50.0
# The ultimate meter's pressure step: a full meter at rest pressure still reaches travel.
const ULTIMATE_STEP := 0.4
# The momentum faders (INTEGRATION section 2): speed is a fraction of top speed.
const DRUMS_IN_SPEED := 0.25
const DRUMS_FULL_SPEED := 0.5
# The lead's level on a level's shelf with nothing lifting it: about half (-6 dB), so the calm
# stretches of a run carry the tune (ruling bt). Threat, the approach and the chain lift it from
# here to full.
const LEAD_FLOOR := 0.5
# The directed sections that end a Warden break: the kill cadence and the walk home carry the
# lead whole, and the break's release stops stripping it from the cadence on.
const LEAD_RETURN := ["return", "home"]
# The Warden fight's held breath and its drop carry the lead whole, whatever the threat feed,
# the fight floor or low armour say: the breath is the lead alone, so a lead at nothing is
# silence, and the drop is the payoff.
const LEAD_WHOLE := ["open", "drop"]
const PROTECTED := ["pivot", "drop", "break", "return", "home"]
const SHELF_CLIPS := ["calm", "travel"]


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
	# A shelf voice whose harmony has cleared for the pivot: nothing raises it again.
	var cleared := false


var manifest := {}
# A single-loop pack (phase_music.gd): one looping clip, section "main", no Warden sections.
var flat := false
# The resolved manifest selected for this band, even when its Oggs are absent.
var manifest_source := ""
var clips := {}
var sections := {}
var streams := {}
var stems: Array = []
# The streams of the last packages read, by resolved manifest path, so a band going back to a
# package it just left reads none of its Oggs again: when the Warden engages, the dam's landmark
# tune ends and the stage pack comes back, and its 24 load_from_file calls were 13 ms of the 4080's
# engage tick (#512 comment 6507862519). A stream is shared, not played: each voice instantiates
# its own playback. audio.gd also builds a band on a worker, hence the lock.
const KEPT_PACKAGES := 3
static var _kept := {}
static var _kept_order: Array[String] = []
static var _kept_lock := Mutex.new()
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
var trims := {}
var rendered := 0
# Stem voices opened and the time opening them took: each one seeks its recording on the
# frame that asks for the section, so a call that opens more than one section's stems shows here.
# Both are running totals for this sequencer, and a change of pack makes a new sequencer that
# counts from zero: a frame's cost is the change across that frame, never the figure itself.
var opened := 0
var open_usec := 0

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
var ultimate_lift := false
var parameter_enabled := false
var parameters := {}
var parameter_released := false
# The kill cadence has answered a Warden break (ruling bt): set as the break piece's return
# section enters. The release stops stripping the lead from there, and audio.gd takes the mark on
# its next pump (_answer_release): from then on the release no longer reaches this band.
var lead_returned := false
var parameter_layer_log: Array = []
var _parameter_danger_floor := 0.0
# The band engine's fight floor (music_engine PRESSURE_FLOOR: warden, miniboss, brindle:1..3),
# set by audio.gd while a fight plays: the melody stem stays up through it, not only under threat.
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


# Where the manifest is on disk: the editor or source tree path first, then the sidecar
# music_ace/ folder beside the executable (an exported game keeps res:// inside its pack,
# so the stems ship beside it, scripts/sketch-export.mjs). "" when neither exists.
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


static func _keep(path: String, read: Dictionary) -> void:
	_kept_lock.lock()
	_kept[path] = read
	_kept_order.erase(path)
	_kept_order.append(path)
	while _kept_order.size() > KEPT_PACKAGES:
		_kept.erase(_kept_order.pop_front())
	_kept_lock.unlock()


# --ace-check: one line saying whether the band found its stems (the export proof reads it).
func _report() -> void:
	if "--ace-check" in OS.get_cmdline_args() or "--ace-check" in OS.get_cmdline_user_args():
		print("ACE_CHECK ready=%s clips=%d streams=%d missing=%s" % [ready(), clips.size(), streams.size(), missing])


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
# full join, so no one-shot is left without a follower. With `fight`, the band is coming back
# into a Warden fight already under way (after a radio hold or an ultimate): it enters on the
# pivot and goes on to the build, and the shelf's recordings are never opened.
func start_level(at: int, fight := false) -> void:
	# A begun join's voices fade over the full ramp too, and calm waits out its join.
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


# The band stops: every voice fades over ramp frames (a beat when a launch takes the
# music, STOP_RAMP otherwise).
func stop(ramp := STOP_RAMP) -> void:
	# Voices of a begun join fade over the same ramp as the rest.
	_cancel_pending(ramp)
	actions.clear()
	mode = "off"
	for v: Voice in voices:
		_ramp_to(v, 0.0, ramp)
		fading.append(v)
	voices.clear()
	section = ""
	trims = {}
	events_log.append(["stop", clock, ""])


# Menus keep their chosen outcome; systemic pressure never changes a lost summary.
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


# The band stops at transport sample at: the sounding section plays to it and fades over
# ramp frames from there (a set piece heard through a launch's flight, then handed to the
# synth on the landing's beat). Anything that restarts or stops the band cancels it.
func stop_at(at: int, ramp := STOP_RAMP) -> void:
	if mode == "off":
		return
	_add({"at": maxi(at, clock), "type": "stop", "ramp": ramp})


# The set director's trims (set_director.gd): one gain per stem, at or under 1, on top of the
# section's profile and the faders, from transport sample at over frames. An empty dict puts every
# stem back. The directed sections (PROTECTED) and the Warden's breath and drop ignore them, so the
# director can never thin a payoff. Starting or stopping the band clears them.
func trim_at(at: int, next: Dictionary, frames: int) -> void:
	_add({"at": maxi(at, clock), "type": "trim", "trims": next.duplicate(), "frames": maxi(frames, 1)})


# One bar of trims: the cut is full on bar line at, the stems are back on the next, each ramp
# ending on its edge so the downbeat sounds at its own level.
func trim_bar(at: int, next: Dictionary, bar: int, ramp: int) -> void:
	trim_at(at - ramp, next, ramp)
	trim_at(at + bar - ramp, {}, ramp)


# Only the stems a trim changes move; a fall or breath ramp in flight on another stem keeps its pace.
func _trim_voices(list: Array, name: String, stems: Array, frames: int) -> void:
	var gains := _profile(name)
	for v: Voice in list:
		if v.stem in stems and gains.has(v.stem):
			_ramp_to(v, _gain_of(gains[v.stem], v.stem, name), frames)


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


# A change of fight floor reopens or settles the live melody stem over STOP_RAMP.
func set_fight_floor(value: float) -> void:
	if value == fight_floor:
		return
	fight_floor = value
	if section != "":
		_retarget(STOP_RAMP)


# The arena clears a Warden break's release at once (audio.gd stage_content_cleared): the
# queued commits stop carrying it, and the live stems reopen over STOP_RAMP.
func clear_release() -> void:
	for action in actions:
		if action["type"] == "parameters":
			action["released"] = false
	if parameter_released:
		_run({"type": "parameters", "values": parameters, "released": false, "lift": ultimate_lift, "reason": "arena", "timing": {}})


# Demucs's other stem carries the melodic roles; drums and bass retain their profiles.
# At full threat/approach the recorded mix is unchanged. Low armour removes other, and so does a
# Warden break's release until the kill cadence brings it back (LEAD_RETURN).
# Two momentum faders ride on top when the feed carries them (INTEGRATION section 2):
# drums follow rolling speed, in from a quarter of top speed and full at half, and the
# lead (other) also opens with the kill chain: a third of the way at chain 2 (the sax hook),
# full at 4. On a level's shelf the lead starts from LEAD_FLOOR, not from silence.
# Boss sections keep the full kit: the duel does not breathe with the ball's speed.
# at names the section the gain is for, for voices that join ahead of it; "" is the live one.
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
		# The landmark's own moment begins at LANDMARK_IN: the lead is whole from there on, not
		# only at the landmark's foot.
		approach = clampf(approach / TuneMoments.LANDMARK_IN, 0.0, 1.0)
	var open := maxf(maxf(pressure + (ULTIMATE_STEP if ultimate_lift else 0.0), maxf(_parameter_danger_floor, fight_floor)), approach)
	var lift := clampf(maxf(open, float(parameters.get("chain", 0.0))), 0.0, 1.0)
	return lerpf(LEAD_FLOOR, 1.0, lift) if mode == "level" else lift


# Low armour strips the lead anywhere. A Warden break's release strips it through the break's
# held breath only: the kill cadence returns it, and it stays back.
func _lead_stripped(cadence := false) -> bool:
	if parameters.has("armour") and float(parameters.armour) < 0.3:
		return true
	return parameter_released and not lead_returned and not cadence


# A full ultimate meter is one pressure step for the ACE band, as set_ultimate_lift is one
# intensity step for the synth (SKILL-BAR section 4, music). The landing or a spent cancel
# releases it. It sits on top of the systemic pressure; set_pressure keeps its own value.
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


# The ball committed to a drop line, or the Warden engaged: the pivot at the next bar.
func commit_warden() -> void:
	if flat or mode != "level":
		return
	mode = "warden"
	_cancel_pending(GAP_RAMP, true)
	_schedule("pivot", _landing("pivot", false))


func set_warden_state(state: String) -> void:
	warden_state = state
	_follow()


# The Warden's guard as its posture fight reports it (0 to 100, rising toward the break).
# The tight build ("telegraph") enters at GUARD_TIGHT and holds until the guard drains under
# GUARD_LOOSE, so a guard that hovers at the line never flutters; a stagger is the held
# breath ("open"); anything else is the build ("closed").
static func guard_state(was: String, posture: float, staggered: bool) -> String:
	if staggered:
		return "open"
	if posture >= GUARD_TIGHT or (was == "telegraph" and posture >= GUARD_LOOSE):
		return "telegraph"
	return "closed"


# The fight follows the guard: its state from guard_state, and `landed` (the hit that
# shattered a chunk) the drop. Returns the drop's transport sample, or -1 when none is
# booked. Outside a Warden fight it does nothing.
func follow_guard(posture: float, staggered: bool, landed: bool) -> int:
	if mode != "warden":
		return -1
	var state := guard_state(warden_state, posture, staggered)
	if landed:
		# The drop is the answer, and the build comes back as the drop's own follower. Asking
		# for the build first would open its three stems on this frame only to throw them away
		# (10 ms on the hit's frame, measured on the PC).
		warden_state = state
		return drop_now()
	if state != warden_state:
		set_warden_state(state)
	return -1


# Contact on the core: the render head goes quiet now and the drop enters on the next
# beat. Returns the drop's transport sample, or -1 when nothing plays or the break has
# begun.
func drop_now() -> int:
	if flat or mode in ["off", "menu"] or (mode == "piece" and not piece_after_drop and section in ["break", "return", "home"]):
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
	if flat or mode in ["off", "piece", "menu"]:
		return
	mode = "piece"
	lead_returned = false
	if pending.get("section", "") == "drop" or (section == "drop" and pending.is_empty()):
		piece_after_drop = true
		return
	var at := _landing("break", false)
	if section == "drop":
		# The drop's follower is already scheduled: the break takes its place, on the
		# first bar of the drop's grid at or after it (a follower may sit on a beat).
		at = next_bar(maxi(int(pending["at"]), clock + _join_frames("break")))
		# The drop's stems run out at their exit: a break placed after that plays the
		# gap as silence, so it enters there with the join it has left.
		for v: Voice in voices:
			if not v.loop:
				at = mini(at, clock + v.exit - v.pos)
	# A follower whose join has begun keeps sounding until the break's own join replaces
	# it, so the wait for the bar is never silent.
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


# The cue the band dipped under has stopped early: the band comes back from this frame.
func free_duck() -> void:
	duck_until = clock
	duck_target = 1.0


# --- The grid -------------------------------------------------------------------------

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
		# Before the first commit the section about to enter owns the grid.
		var clip: Dictionary = clips[sections[String(pending["section"])]["clip"]]
		grid_origin = int(pending["at"]) - posmod(int(pending["entry"]) - int(clip["entry"]), int(clip["bar"]))
		step = int(clip["beat"]) if unit == grid_beat else int(clip["bar"])
	return grid_origin + int(ceil(float(base - grid_origin) / step)) * step


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


# Moves toward what the game asks for, at the first moment a change is allowed: never
# inside a hold, never over a protected entry, never during the directed piece.
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
	# A drop or pivot is heard to its end before the build comes back.
	if want == "build" and section in ["drop", "pivot"]:
		return ""
	_cancel_pending()
	if want == section:
		return ""
	return want


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


# Parameter joins start on the committed boundary. Other joins end on their section edge.
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


# The roaming shelf and the Warden's combat clips need not share a key (the rebuilt zone packs
# cut the shelf from the world's roaming take, key_check.py reads it a fifth or a relative
# away). So the shelf's bass and lead fade out over the beat before the pivot's downbeat and
# only the drums cross it: two keys never sound together.
func _clear_harmony(at: int) -> void:
	var frames := mini(grid_beat, maxi(at - clock, 1))
	for v: Voice in voices:
		if v.stem != "drums":
			_add({"at": maxi(clock, at - frames), "type": "clear", "voice": v, "frames": frames, "serial": _serial + 1})


func _open(clip: Dictionary, stem: String, from: int, gains: Dictionary, ramp: int, name: String) -> Voice:
	var began := Time.get_ticks_usec()
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


# The live voices move to the current profile: the bay, or a breath style flipped mid-open.
func _retarget(frames: int) -> void:
	var gains := _profile(section)
	for v: Voice in voices:
		var row: Dictionary = gains[v.stem]
		_ramp_to(v, _gain_of(row, v.stem), frames)
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


# The momentum faders rise over one beat and fall over two bars, so one bump of speed or
# a single broken link never makes the band stutter (INTEGRATION section 2). Only voices
# already sounding move, and only when their own momentum factor changed: a join's new
# voices, the threat and armour retargets and the Warden release keep their own ramps.
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


# Drops the pending section. Once its join has begun the old section is already fading
# out and the pending voices are the ones sounding, so they must not vanish: with keep
# they stay in voices and the replacement's own begin fades them (the replacement
# schedules itself right after); otherwise they fade over ramp, as for a gap or a stop.
# Returns true when a begun join's voices were faded or kept.
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
			# Only for the pivot it was scheduled for: a cancelled pivot leaves the shelf whole.
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
		"trim":
			var stems: Array = trims.keys()
			trims = action.trims
			for stem in trims:
				if not stem in stems:
					stems.append(stem)
			# Inside a begun join the live voices already belong to the incoming section, and
			# voices opened for a join not yet begun are levelled by their own section's rules.
			var begun := bool(pending.get("begun", false))
			var live := String(pending["section"]) if begun else section
			if live != "":
				_trim_voices(voices, live, stems, int(action.frames))
			if not pending.is_empty() and not begun:
				_trim_voices(pending["voices"], String(pending["section"]), stems, int(action.frames))
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
