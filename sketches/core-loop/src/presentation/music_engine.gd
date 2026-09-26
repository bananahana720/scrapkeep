extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

# The band. A sample-exact sequencer that mixes pre-rendered notes from synth.gd on a
# 172 BPM grid in D Dorian. It knows nothing about the game: the audio director tells
# it the pressure, the mode and which stingers to play, and it renders blocks of
# stereo frames on demand. render(n) is pure over its own state, so the tests drive it
# without a sound card.
#
# Layers enter with pressure (0..1). Calm leaves space: keys, sub and a light hat.
# Pressure brings the kick up, then snare and ride, the reese bass, the sax lead and
# finally a bell arpeggio. New pressure takes effect on the next bar, so layers enter
# on a downbeat. Stingers start on the next beat; flow stingers queue behind each
# other in one lane so they never talk over each other.

enum { KEYS, SUB, HATS, KICK, SNARE, REESE, LEAD, ARP }
const LAYER_NAMES := ["keys", "sub", "hats", "kick", "snare", "reese", "lead", "arp"]
# gain = floor + (1 - floor) * smoothstep(from, to, pressure). Each curve is monotonic.
const CURVES := [
	[0.85, 0.0, 0.5],
	[0.7, 0.0, 0.4],
	[0.35, 0.05, 0.3],
	[0.5, 0.1, 0.35],
	[0.0, 0.2, 0.45],
	[0.0, 0.35, 0.6],
	[0.0, 0.55, 0.8],
	[0.0, 0.75, 1.0],
]
const LEVELS := [0.34, 0.5, 0.22, 0.62, 0.42, 0.3, 0.36, 0.14]

enum { IDLE, PLAY, DEAD }
const MODE_NAMES := ["idle", "play", "dead"]
# What each mode lets through, per layer: menus keep the keys and sub, death keeps
# the keys alone, so the band waits with you instead of stopping.
const MODE_MASK := [
	[1.0, 0.7, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0],
	[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	[0.6, 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
]

const RELEASE := 600
const DUCK_RELEASE := Harmony.BEAT
const RISER_SPACING := Harmony.BAR * 4

const MOTIF := [[2, 69, 2], [4, 72, 1], [5, 74, 1], [6, 76, 2], [8, 74, 2], [10, 72, 1], [11, 69, 3],
	[16, 67, 2], [18, 65, 2], [20, 69, 6]]


class Voice:
	var buf: PackedFloat32Array
	var pos := 0
	var end := 0
	var gl := 0.7
	var gr := 0.7
	var layer := -1
	var to_stinger := false
	var mono := false


var clock := 0
var bar_origin := 0
var mode := IDLE
var pressure := 0.0
var applied_pressure := 0.0
var master := 0.8
var pause_gain := 1.0
var phrase_index := 0
var out_music := PackedVector2Array()
var out_stinger := PackedVector2Array()
# [id, start_sample] each time a stinger actually starts, for tests and the notes.
var stinger_starts: Array = []
var lane_free_at := 0

var _gains := PackedFloat32Array()
var _targets := PackedFloat32Array()
var _voices: Array = []
var _actions: Array = []
var _last_step_at := -1
var _lead: Array = []
var _cadence := []
var _cadence_bar := -1
var _groove := 0
var _duck := 1.0
var _duck_target := 1.0
var _duck_until := 0
var _last_riser := -RISER_SPACING
var _mid := PackedFloat32Array()
var _left := PackedFloat32Array()
var _right := PackedFloat32Array()
var _sl := PackedFloat32Array()
var _sr := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _stingers_live := false


func _init() -> void:
	_gains.resize(LAYER_NAMES.size())
	_targets.resize(LAYER_NAMES.size())
	_retarget()
	for i in _gains.size():
		_gains[i] = _targets[i]
	_lead = make_lead(phrase_index)


# Every note the band can play, rendered up front so the first bars never hitch.
static func prepare() -> void:
	for chord in Harmony.PROGRESSION + Harmony.CADENCE:
		Synth.note("sub", chord["root"])
		Synth.note("reese", chord["root"] + 12)
		Synth.chord(chord["voicing"])
		for midi in chord["voicing"]:
			Synth.note("bell", midi + 12)
	for drum in Synth.DRUMS:
		Synth.drum(drum)
	for midi in range(60, 86):
		Synth.note("lead", midi)


static func layer_gains(value: float) -> PackedFloat32Array:
	var gains := PackedFloat32Array()
	var p := clampf(value, 0.0, 1.0)
	for curve in CURVES:
		gains.append(curve[0] + (1.0 - curve[0]) * smoothstep(curve[1], curve[2], p))
	return gains


func layer_gain(layer: int) -> float:
	return _gains[layer]


func layer_target(layer: int) -> float:
	return _targets[layer]


func set_pressure(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	var before := layer_gains(applied_pressure)
	var after := layer_gains(next)
	pressure = next
	if mode != PLAY:
		return
	# A layer about to enter gets a one-beat riser that lands on its downbeat.
	for layer in [SNARE, REESE, LEAD, ARP]:
		if before[layer] < 0.05 and after[layer] >= 0.05:
			var bar := next_bar()
			if bar - Harmony.BEAT > clock and bar - _last_riser >= RISER_SPACING:
				_last_riser = bar
				_add_action(bar - Harmony.BEAT, {"type": "stinger", "id": "music_pressure", "db": 0.0, "music": true})
			break


# The next beat boundary at or after the play head. A stinger asked for mid-beat waits
# for the beat; one asked for exactly on an unplayed beat starts on it.
func next_beat(from := -1) -> int:
	var at := clock if from < 0 else from
	var beat := int(ceil(float(at) / Harmony.BEAT)) * Harmony.BEAT
	if beat == clock and _last_step_at == clock:
		beat += Harmony.BEAT
	return beat


func next_bar() -> int:
	var rel := clock - bar_origin
	var bar := bar_origin + int(ceil(float(rel) / Harmony.BAR)) * Harmony.BAR
	if bar == clock and _last_step_at == clock:
		bar += Harmony.BAR
	return bar


# Starts a stinger on the next beat and returns its start sample. lane queues it
# behind the flow stinger already playing; offsets_steps repeats it (stage 3 = 3 hits).
func schedule_stinger(id: String, db := 0.0, lane := false, repeats := 1) -> int:
	var start := next_beat()
	if lane:
		start = maxi(start, next_beat(lane_free_at))
		lane_free_at = start + SfxBank.STINGER_BEATS.get(id, 1) * Harmony.BEAT + (repeats - 1) * 2 * Harmony.STEP
	for i in repeats:
		_add_action(start + i * 2 * Harmony.STEP, {"type": "stinger", "id": id, "db": db - 2.0 * i, "music": false})
	return start


# The phrase restarts from bar 1 at a beat, in a mode: a new run, a stage, a retry.
func schedule_restart(at: int, next_mode: int) -> void:
	_add_action(at, {"type": "restart", "mode": next_mode})


# The stage-clear resolution: A7b9 then D major, held, starting at a beat.
func schedule_cadence(at: int) -> void:
	_add_action(at, {"type": "cadence"})


func schedule_mode(at: int, next_mode: int) -> void:
	_add_action(at, {"type": "mode", "mode": next_mode})


# Drops every stinger and phrase change not yet played and fades the ones playing:
# a retry or a new run starts clean instead of finishing the old announcements.
func cancel_pending() -> void:
	var keep: Array = []
	for action in _actions:
		if action["type"] == "stinger" and action.get("music", false):
			keep.append(action)
	_actions = keep
	lane_free_at = 0
	_cadence_bar = -1
	for voice in _voices:
		if voice.layer < 0:
			voice.end = mini(voice.end, voice.pos + RELEASE)


# Pulls the band down under an important cue, then lets it back up.
func duck(amount: float, hold_seconds: float) -> void:
	_duck_target = minf(_duck_target, clampf(amount, 0.1, 1.0))
	_duck_until = maxi(_duck_until, clock + int(hold_seconds * Harmony.RATE))


func pending_actions() -> int:
	return _actions.size()


func voice_count() -> int:
	return _voices.size()


func render(frames: int) -> void:
	out_music.resize(frames)
	out_stinger.resize(frames)
	_mid.resize(frames)
	_left.resize(frames)
	_right.resize(frames)
	_sl.resize(frames)
	_sr.resize(frames)
	_stingers_live = false
	_mid.fill(0.0)
	_left.fill(0.0)
	_right.fill(0.0)
	_sl.fill(0.0)
	_sr.fill(0.0)
	var done := 0
	while done < frames:
		if clock % Harmony.STEP == 0 and _last_step_at != clock:
			_last_step_at = clock
			_on_step()
		var n := mini(frames - done, Harmony.STEP - clock % Harmony.STEP)
		_mix(done, n)
		clock += n
		done += n
	_finish(frames)


# --- Sequencer ------------------------------------------------------------------------

func _add_action(at: int, action: Dictionary) -> void:
	action["at"] = at
	_actions.append(action)


func _on_step() -> void:
	var due: Array = []
	for action in _actions:
		if action["at"] <= clock:
			due.append(action)
	for action in due:
		_actions.erase(action)
		_run(action)
	var steps := (clock - bar_origin) / Harmony.STEP
	var s := steps % Harmony.STEPS_PER_BAR
	var bar := steps / Harmony.STEPS_PER_BAR
	if s == 0:
		_on_bar(bar)
	var chord := _chord(bar)
	_trigger(bar, s, chord)


func _run(action: Dictionary) -> void:
	match action["type"]:
		"stinger":
			var buf := SfxBank.samples(action["id"])
			var gain := db_to_linear(SfxBank.trim_db(action["id"]) + float(action["db"]))
			_start(buf, buf.size(), -1, gain, 0.0, not action["music"])
			stinger_starts.append([action["id"], clock])
		"restart":
			bar_origin = clock
			_cadence_bar = -1
			mode = action["mode"]
			phrase_index += 1
			_lead = make_lead(phrase_index)
			_release_all()
			_retarget()
		"cadence":
			bar_origin = clock
			_cadence_bar = 0
			_release_all()
		"mode":
			mode = action["mode"]
			if mode != PLAY:
				_release_layers([KICK, SNARE, REESE, LEAD, ARP])
			_retarget()


func _on_bar(bar: int) -> void:
	if _cadence_bar >= 0 and bar >= Harmony.CADENCE.size():
		# The cadence is over: the band picks the loop up again from the top.
		_cadence_bar = -1
		bar_origin = clock
		phrase_index += 1
		_lead = make_lead(phrase_index)
	applied_pressure = pressure
	_retarget()
	if bar % Harmony.PHRASE_BARS == 0:
		_groove = _rng.randi() % 3


func _retarget() -> void:
	var gains := layer_gains(applied_pressure)
	for layer in _targets.size():
		_targets[layer] = gains[layer] * MODE_MASK[mode][layer]


func _chord(bar: int) -> Dictionary:
	if _cadence_bar >= 0:
		return Harmony.CADENCE[mini(bar, Harmony.CADENCE.size() - 1)]
	return Harmony.PROGRESSION[bar % Harmony.PHRASE_BARS]


func _trigger(bar: int, s: int, chord: Dictionary) -> void:
	var cadence := _cadence_bar >= 0
	var phrase_bar := bar % Harmony.PHRASE_BARS
	var busy := applied_pressure >= 0.3 and mode == PLAY
	# Keys: a held chord when calm, syncopated stabs once the pressure is up.
	var stabs: Dictionary = {0: 16} if not busy or (cadence and bar == 1) else ([{0: 3, 6: 2, 10: 4}, {0: 2, 3: 2, 8: 3, 14: 2}, {0: 3, 6: 2, 10: 4}][_groove])
	if stabs.has(s):
		_release_layers([KEYS])
		var buf := Synth.chord(chord["voicing"])
		_start(buf, mini(buf.size(), int(stabs[s]) * Harmony.STEP + RELEASE), KEYS, LEVELS[KEYS], 0.0, false)
	if s == 0:
		_note("sub", chord["root"], 16, SUB, 1.0, 0.0)
	# Hats: eighths, then sixteenths under pressure, with an open hat to lift bar ends.
	if s % 2 == 0 or applied_pressure >= 0.4:
		var accent := 1.0 if s % 4 == 2 else (0.55 if s % 2 == 0 else 0.35)
		_hit("hat", HATS, accent, 0.25)
	if s == 14 and applied_pressure >= 0.5:
		_hit("open_hat", HATS, 0.7, 0.25)
	# Kick: half-time when calm, the two-step once the pressure is up.
	var kicks := [0, 10] if applied_pressure >= 0.35 or cadence else [0]
	if _groove == 1 and applied_pressure >= 0.35:
		kicks = [0, 10, 11]
	if cadence and bar == 1:
		kicks = [0]
	if s in kicks:
		_hit("kick", KICK, 1.0, 0.0)
	if cadence and bar == 1 and s == 0:
		_hit("crash", KICK, 0.8, -0.2)
	# Snare, ghosts and a jazz ride; the last bar of a phrase rolls into the top.
	if not (cadence and bar == 1):
		if s == 4 or s == 12:
			_hit("snare", SNARE, 1.0, 0.05)
		elif (s == 7 or s == 15 or (_groove == 2 and s == 9)) and not cadence:
			_hit("snare", SNARE, 0.28, 0.05)
		if (phrase_bar == 7 or cadence) and s >= 8 and s != 12 and (s % 2 == 0 or applied_pressure >= 0.6):
			_hit("snare", SNARE, 0.35 + 0.08 * (s - 8), 0.05)
		if s in [0, 4, 7, 8, 12, 15]:
			_hit("ride", SNARE, 0.55 if s % 4 == 0 else 0.35, -0.3)
	if cadence:
		return
	# Reese: root, octave pop, root, and a chromatic approach into the next bar's root.
	var root: int = chord["root"] + 12
	var next_root: int = Harmony.PROGRESSION[(bar + 1) % Harmony.PHRASE_BARS]["root"] + 12
	var line := {0: [root, 3], 3: [root + 12, 1], 6: [root, 2], 10: [root + 7, 3], 14: [next_root - 1, 2]}
	if line.has(s):
		_release_layers([REESE])
		_note("reese", line[s][0], line[s][1], REESE, 1.0, 0.0)
	# Lead: this phrase's line.
	var at := phrase_bar * Harmony.STEPS_PER_BAR + s
	for event in _lead:
		if event[0] == at:
			_release_layers([LEAD])
			_note("lead", event[1], event[2], LEAD, 1.0, 0.1)
	# Arp: chord tones an octave up, alternating sides.
	if s % 2 == 0 or applied_pressure >= 0.9:
		var tones: Array = chord["voicing"]
		var pattern := [0, 1, 2, 3, 2, 1]
		var midi: int = tones[pattern[(s / 2 + phrase_bar) % pattern.size()] % tones.size()] + 12
		_note("bell", midi, 2, ARP, 0.8, 0.45 if s % 4 == 0 else -0.45)


func _note(instrument: String, midi: int, steps: int, layer: int, gain: float, pan: float) -> void:
	var buf := Synth.note(instrument, midi)
	_start(buf, mini(buf.size(), steps * Harmony.STEP + RELEASE), layer, gain * LEVELS[layer], pan, false)


func _hit(instrument: String, layer: int, gain: float, pan: float) -> void:
	var buf := Synth.drum(instrument)
	_start(buf, buf.size(), layer, gain * LEVELS[layer], pan, false)


func _start(buf: PackedFloat32Array, length: int, layer: int, gain: float, pan: float, to_stinger: bool) -> void:
	var voice := Voice.new()
	voice.buf = buf
	voice.end = length
	voice.layer = layer
	voice.to_stinger = to_stinger
	var angle := (clampf(pan, -1.0, 1.0) + 1.0) * PI * 0.25
	voice.gl = cos(angle) * gain * 1.41
	voice.gr = sin(angle) * gain * 1.41
	# A centred voice mixes once into the mono sum, half the work of a panned one.
	voice.mono = absf(pan) < 0.05
	if voice.mono:
		voice.gl = gain
	_voices.append(voice)


func _release_layers(layers: Array) -> void:
	for voice in _voices:
		if voice.layer in layers:
			voice.end = mini(voice.end, voice.pos + RELEASE)


func _release_all() -> void:
	for voice in _voices:
		if voice.layer >= 0:
			voice.end = mini(voice.end, voice.pos + RELEASE)


# --- Mixing ---------------------------------------------------------------------------

func _mix(offset: int, n: int) -> void:
	var start_gains := _gains.duplicate()
	var step := float(n) / Harmony.BEAT
	for layer in _gains.size():
		_gains[layer] = move_toward(_gains[layer], _targets[layer], step)
	var inv_n := 1.0 / n
	var finished: Array = []
	for voice: Voice in _voices:
		var count := mini(n, voice.end - voice.pos)
		if count <= 0:
			finished.append(voice)
			continue
		var g0 := 1.0
		var g1 := 1.0
		if voice.layer >= 0:
			g0 = start_gains[voice.layer]
			g1 = _gains[voice.layer]
		if g0 <= 0.0001 and g1 <= 0.0001:
			voice.pos += count
			if voice.pos >= voice.end:
				finished.append(voice)
			continue
		var buf := voice.buf
		var pos := voice.pos
		var release_at := voice.end - RELEASE if voice.end < buf.size() else voice.end
		var gl := voice.gl
		var gr := voice.gr
		var flat := g0 == g1 and pos + count <= release_at
		if voice.mono and not voice.to_stinger:
			if flat:
				var m := gl * g0
				for i in count:
					_mid[offset + i] += buf[pos + i] * m
			else:
				for i in count:
					var k := pos + i
					var g := g0 + (g1 - g0) * i * inv_n
					if k >= release_at:
						g *= float(voice.end - k) / RELEASE
					_mid[offset + i] += buf[k] * g * gl
		else:
			if voice.to_stinger:
				_stingers_live = true
			var left := _sl if voice.to_stinger else _left
			var right := _sr if voice.to_stinger else _right
			if voice.mono:
				gr = gl
			for i in count:
				var k := pos + i
				var g := g0
				if not flat:
					g = g0 + (g1 - g0) * i * inv_n
					if k >= release_at:
						g *= float(voice.end - k) / RELEASE
				var x := buf[k] * g
				left[offset + i] += x * gl
				right[offset + i] += x * gr
		voice.pos += count
		if voice.pos >= voice.end:
			finished.append(voice)
	for voice in finished:
		_voices.erase(voice)
	# The duck envelope, per sub-block.
	if clock >= _duck_until:
		_duck_target = 1.0
	var duck_from := _duck
	var rate: float = float(n) / (DUCK_RELEASE if _duck_target > _duck else 400.0)
	_duck = move_toward(_duck, _duck_target, rate)
	var level := master * pause_gain
	for i in n:
		var d := (duck_from + (_duck - duck_from) * i * inv_n) * level
		var m := _mid[offset + i]
		_left[offset + i] = (_left[offset + i] + m) * d
		_right[offset + i] = (_right[offset + i] + m) * d


func _finish(frames: int) -> void:
	for i in frames:
		var l := _left[i]
		var r := _right[i]
		if l > 0.75 or l < -0.75:
			l = _soft(l)
		if r > 0.75 or r < -0.75:
			r = _soft(r)
		out_music[i] = Vector2(l, r)
	if _stingers_live:
		for i in frames:
			out_stinger[i] = Vector2(_soft(_sl[i]), _soft(_sr[i]))
	else:
		out_stinger.fill(Vector2.ZERO)


# Clean below 0.75, then a tanh knee that never passes full scale.
static func _soft(x: float) -> float:
	var a := absf(x)
	if a <= 0.75:
		return x
	return signf(x) * (0.75 + 0.25 * tanh((a - 0.75) * 4.0))


# --- The lead ---------------------------------------------------------------------------
# One eight-bar phrase: a two-bar call, a two-bar answer, the call sequenced up, and
# an answer that ends on C#, the leading tone that pulls back to D at the top. The
# answer and the ornaments change every loop from a seeded stream, so it never
# repeats exactly and a run replays the same way.

static func make_lead(index: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260926 + index * 7919
	var shift: int = [0, 1, 2, -1][rng.randi() % 4]
	var answer := rng.randi() % 3
	var notes := []
	notes.append_array(_place(_transpose(MOTIF, shift), 0))
	notes.append_array(_place(_answer(MOTIF, answer, shift), 32))
	notes.append_array(_place(_transpose(MOTIF, shift + 2), 64))
	var ending := _place(_answer(MOTIF, (answer + 1) % 3, shift), 96)
	notes.append_array(ending)
	var fitted := []
	for event in notes:
		var step: int = event[0]
		if step >= 128:
			continue
		var chord: Dictionary = Harmony.PROGRESSION[step / 16]
		var midi: int = event[1]
		midi = Harmony.nearest_tone(midi, chord["tones"]) if step % 4 == 0 else Harmony.snap(midi, chord["scale"])
		while midi < 62:
			midi += 12
		while midi > 84:
			midi -= 12
		fitted.append([step, midi, mini(event[2], 128 - step)])
	if not fitted.is_empty():
		var last: Array = fitted[fitted.size() - 1]
		last[1] = 73
	# Chromatic approach tones: a sixteenth a half step below a strong-beat target.
	var taken := {}
	for event in fitted:
		taken[event[0]] = true
	var ornamented := []
	for event in fitted:
		if event[0] % 4 == 0 and event[0] > 0 and not taken.has(event[0] - 1) and rng.randf() < 0.35:
			ornamented.append([event[0] - 1, event[1] - 1, 1])
		ornamented.append(event)
	return ornamented


static func _place(cell: Array, offset: int) -> Array:
	var placed := []
	for event in cell:
		placed.append([event[0] + offset, event[1], event[2]])
	return placed


static func _transpose(cell: Array, steps: int) -> Array:
	var moved := []
	for event in cell:
		moved.append([event[0], Harmony.scale_shift(event[1], steps, Harmony.DORIAN) if steps != 0 else event[1], event[2]])
	return moved


static func _answer(cell: Array, kind: int, shift: int) -> Array:
	var source := _transpose(cell, shift)
	var answer := []
	match kind:
		0:
			# Inversion: the call's contour upside down around its first note.
			var pivot: int = source[0][1]
			for event in source:
				answer.append([event[0], Harmony.snap(2 * pivot - event[1], Harmony.DORIAN), event[2]])
		1:
			# Retrograde: the call's pitches backwards over its own rhythm.
			for i in source.size():
				answer.append([source[i][0], source[source.size() - 1 - i][1], source[i][2]])
		_:
			# Displaced echo: an eighth late and two steps lower.
			for event in source:
				if event[0] + 2 < 32:
					answer.append([event[0] + 2, Harmony.scale_shift(event[1], -2, Harmony.DORIAN), event[2]])
	return answer
