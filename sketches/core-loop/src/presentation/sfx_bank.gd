extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")

# One baked sound per event_kinds `sound` id. Each recipe is built from the shared
# rack in synth.gd and pitched from harmony.gd, so the families mean something:
#   rewards and pickups ring bright bells that climb the D minor pentatonic;
#   danger is low, minor and buzzy (squares and saws under D);
#   movement is air and wood: whooshes, chirps and thuds with no fixed pitch;
#   flow stingers are little band hits written on the band's own grid.
# Everything is baked once per process at startup and cached.

const RATE := Harmony.RATE

# Stingers written on the grid. The audio director starts them on a beat through the
# music engine; beats is how long they hold the stinger lane.
const STINGER_BEATS := {
	"stinger_run": 4,
	"stinger_stage": 1,
	"stinger_clear": 8,
	"stinger_run_end": 12,
	"stinger_milestone": 4,
	"gates_open": 4,
	"klaxon": 4,
	"music_pressure": 1,
}

# Per-cue trim in dB against the 0.9 peak every cue is normalized to. Rapid, small
# facts sit low so a firefight never turns to mush; rare facts sit at the top.
const TRIM_DB := {
	"ui_tick": -14.0, "hop": -10.0, "boost_whoosh": -6.0, "dash_whoosh": -5.0,
	"land_thud": -6.0, "slam_boom": -1.0, "grapple_clink": -7.0, "grapple_release": -11.0,
	"pylon_plant": -3.0, "pylon_eject": -4.0, "enemy_arrive": -9.0, "hit_thwack": -5.0,
	"weapon_zap": -15.0, "special_fire": -4.0, "kill_pop": -8.0, "hurt": -3.0,
	"death": 0.0, "scrap_tick": -10.0, "part_get": -3.0, "beacon_hum": -12.0,
	"gate_through": -3.0, "launch_roar": -2.0, "event_start": -3.0, "event_end": -6.0,
	"klaxon": -3.0, "stinger_run": -3.0, "stinger_stage": -4.0, "stinger_clear": -2.0,
	"stinger_run_end": -2.0, "stinger_milestone": -2.0, "gates_open": -4.0,
	"music_pressure": -9.0,
}

static var _samples := {}
static var _streams := {}


static func has_recipe(id: String) -> bool:
	return TRIM_DB.has(id)


static func trim_db(id: String) -> float:
	return TRIM_DB.get(id, -8.0)


static func samples(id: String) -> PackedFloat32Array:
	if not _samples.has(id):
		_samples[id] = Synth.normalize(_bake(id), 0.9)
	return _samples[id]


static func stream(id: String) -> AudioStreamWAV:
	if not _streams.has(id):
		_streams[id] = Synth.to_wav(samples(id))
	return _streams[id]


static func bake_all(ids: Array) -> void:
	for id in ids:
		stream(id)


static func _bake(id: String) -> PackedFloat32Array:
	match id:
		"ui_tick":
			return _tone(0.03, Harmony.hz(86), Harmony.hz(86), "sine", 120.0)
		"hop":
			return _mix([[_tone(0.11, 380.0, 640.0, "sine", 28.0), 0, 1.0], [_noise(0.02, 3000.0, 3000.0, 200.0), 0, 0.3]])
		"boost_whoosh":
			return _mix([[_noise(0.42, 500.0, 3200.0, 7.0, 0.06), 0, 1.0], [_tone(0.12, 90.0, 55.0, "sine", 25.0), 0, 0.7]])
		"dash_whoosh":
			return _mix([[_noise(0.28, 1400.0, 5200.0, 11.0, 0.02), 0, 1.0], [_tone(0.2, 300.0, 950.0, "saw", 14.0), 0, 0.18]])
		"land_thud":
			return _mix([[_tone(0.2, 95.0, 42.0, "sine", 20.0), 0, 1.0], [_noise(0.05, 800.0, 400.0, 60.0), 0, 0.4]])
		"slam_boom":
			return _slam()
		"grapple_clink":
			return _fm(0.24, Harmony.hz(81), 3.5, 5.0, 16.0)
		"grapple_release":
			return _fm(0.15, Harmony.hz(76), 2.0, 1.5, 24.0, -2.0)
		"pylon_plant":
			return _mix([[_tone(0.16, 130.0, 55.0, "sine", 22.0), 0, 1.0], [_fm(0.3, Harmony.hz(62), 2.76, 4.0, 12.0), 0, 0.6],
				[_tone(0.2, 440.0, 880.0, "sine", 8.0), Synth.seconds(0.1), 0.25]])
		"pylon_eject":
			return _boing()
		"enemy_arrive":
			return _mix([[_tone(0.16, Harmony.hz(40), Harmony.hz(40), "saw_dark", 6.0), 0, 1.0],
				[_tone(0.2, Harmony.hz(41), Harmony.hz(41), "saw_dark", 6.0), Synth.seconds(0.14), 1.0]])
		"hit_thwack":
			return _mix([[_noise(0.14, 1300.0, 700.0, 30.0), 0, 0.8], [_tone(0.14, 230.0, 85.0, "sine", 26.0), 0, 1.0]], true)
		"weapon_zap":
			return _fm_sweep(0.1, 1500.0, 480.0, 4.0, 30.0)
		"special_fire":
			return _special()
		"kill_pop":
			return _mix([[_tone(0.05, 500.0, 1300.0, "sine", 50.0), 0, 0.6], [Synth.note("bell", 81), 0, 0.8]])
		"hurt":
			return _mix([[_tone(0.13, Harmony.hz(53), Harmony.hz(53), "square_dark", 8.0), 0, 1.0],
				[_tone(0.2, Harmony.hz(50), Harmony.hz(48), "square_dark", 9.0), Synth.seconds(0.11), 1.0],
				[_noise(0.1, 900.0, 300.0, 30.0), 0, 0.5]], true)
		"death":
			return _death()
		"scrap_tick":
			return _mix([[_cut(Synth.note("bell", 74), 0.16), 0, 1.0], [_noise(0.01, 6000.0, 6000.0, 300.0), 0, 0.2]])
		"part_get":
			return _arpeggio([74, 77, 81, 86], 0.05, "bell", 0.8)
		"beacon_hum":
			return _hum()
		"gate_through":
			return _mix([[_noise(0.3, 800.0, 3600.0, 10.0, 0.03), 0, 0.6], [Synth.note("bell", 81), Synth.seconds(0.04), 0.6],
				[Synth.note("bell", 86), Synth.seconds(0.04), 0.5], [Synth.note("bell", 89), Synth.seconds(0.04), 0.4]])
		"launch_roar":
			return _mix([[_noise(1.1, 300.0, 4200.0, 2.4, 0.5), 0, 1.0], [_tone(1.0, 90.0, 720.0, "saw_dark", 2.2), 0, 0.5]], true)
		"klaxon":
			return _klaxon()
		"event_start":
			return _mix([[Synth.kick(), 0, 1.0], [Synth.note("keys", 50), 0, 0.5], [Synth.note("keys", 53), 0, 0.5],
				[Synth.note("keys", 57), 0, 0.5], [Synth.note("keys", 63), 0, 0.4]], true, 0.8)
		"event_end":
			return _arpeggio([69, 65, 62], 0.09, "mallet", 0.7)
		"music_pressure":
			return _riser()
		"stinger_run":
			return Synth.render_score(_score_run(0), 0.8)
		"stinger_stage":
			return Synth.render_score([[0, 0, 2, "kick", 1.0], [0, 0, 2, "open_hat", 0.6], [0, 62, 2, "keys", 0.5],
				[0, 65, 2, "keys", 0.5], [0, 69, 2, "keys", 0.5], [0, 72, 2, "keys", 0.5], [0, 74, 2, "lead", 0.6]], 0.5)
		"stinger_clear":
			return Synth.render_score(_score_clear(0), 1.4)
		"stinger_run_end":
			var finale := _score_run(0)
			finale.append_array(_score_clear(16))
			return Synth.render_score(finale, 2.0)
		"stinger_milestone":
			return Synth.render_score(_score_milestone(), 1.2)
		"gates_open":
			return Synth.render_score([[0, 62, 2, "bell", 0.5], [1, 65, 2, "bell", 0.5], [2, 69, 2, "bell", 0.5],
				[3, 72, 2, "bell", 0.5], [4, 76, 6, "bell", 0.6], [4, 57, 12, "keys", 0.35], [4, 60, 12, "keys", 0.35],
				[4, 64, 12, "keys", 0.35], [4, 65, 12, "keys", 0.35], [4, 0, 2, "open_hat", 0.5]], 1.0)
	# A kind added after this bank still gets a sound: a small blip pitched from its
	# name, flagged by presentation_sfx_test so it gets a real recipe.
	return _tone(0.12, Harmony.hz(62 + Harmony.pentatonic_step(absi(id.hash()) % 8)), 0.0, "sine", 20.0)


# --- Scores ----------------------------------------------------------------------------

static func _score_run(at: int) -> Array:
	return [[at, 0, 2, "kick", 1.0], [at, 0, 16, "crash", 0.55], [at, 62, 2, "lead", 0.7], [at + 2, 69, 2, "lead", 0.7],
		[at + 4, 72, 1, "lead", 0.7], [at + 5, 74, 3, "lead", 0.75], [at + 8, 77, 2, "lead", 0.75], [at + 10, 76, 2, "lead", 0.7],
		[at + 12, 74, 4, "lead", 0.75], [at, 53, 3, "keys", 0.35], [at, 57, 3, "keys", 0.35], [at, 60, 3, "keys", 0.35],
		[at, 64, 3, "keys", 0.35], [at + 10, 53, 4, "keys", 0.35], [at + 10, 57, 4, "keys", 0.35], [at + 10, 60, 4, "keys", 0.35],
		[at + 10, 64, 4, "keys", 0.35], [at + 4, 0, 1, "snare", 0.7], [at + 12, 0, 1, "snare", 0.8], [at + 10, 0, 1, "kick", 0.8]]


# The end-of-cycle melody. It climbs the A7 chord, turns, and lands on D, then the
# two little "done" beeps land on the home note an octave up.
static func _score_clear(at: int) -> Array:
	var tune := [[0, 69], [2, 73], [4, 76], [6, 81], [8, 79], [10, 76], [12, 73], [14, 76]]
	var score := []
	for note in tune:
		score.append([at + note[0], note[1], 2, "mallet", 0.8])
		score.append([at + note[0], note[1], 2, "beep", 0.25])
	score.append_array([[at + 16, 74, 8, "mallet", 0.9], [at + 16, 74, 8, "beep", 0.3], [at + 16, 86, 8, "bell", 0.5],
		[at + 16, 0, 16, "crash", 0.4], [at + 24, 78, 2, "mallet", 0.6], [at + 26, 81, 2, "mallet", 0.6],
		[at + 28, 86, 4, "mallet", 0.8], [at + 28, 86, 4, "beep", 0.3]])
	return score


static func _score_milestone() -> Array:
	var score := []
	var rung := 0
	for step in 8:
		score.append([step, 74 + Harmony.pentatonic_step(rung), 1, "bell", 0.55])
		rung += 1
	score.append_array([[8, 0, 2, "kick", 1.0], [8, 0, 16, "crash", 0.6], [8, 53, 8, "keys", 0.4], [8, 57, 8, "keys", 0.4],
		[8, 60, 8, "keys", 0.4], [8, 64, 8, "keys", 0.4], [8, 86, 8, "lead", 0.6], [12, 0, 1, "snare", 0.8]])
	return score


# --- Recipe helpers --------------------------------------------------------------------

static func _mix(parts: Array, saturate := false, target := 0.9) -> PackedFloat32Array:
	var length := 0
	for part in parts:
		length = maxi(length, int(part[1]) + (part[0] as PackedFloat32Array).size())
	var buf := Synth.buffer(length)
	for part in parts:
		Synth.add_into(buf, part[0], int(part[1]), float(part[2]))
	if saturate:
		for i in buf.size():
			buf[i] = tanh(buf[i] * 1.4)
	return Synth.declick(Synth.normalize(buf, target), 16, 400)


static func _cut(buf: PackedFloat32Array, length_seconds: float) -> PackedFloat32Array:
	var cut := buf.slice(0, mini(buf.size(), Synth.seconds(length_seconds)))
	return Synth.declick(cut, 8, 600)


# An oscillator with an exponential pitch sweep and exponential decay.
static func _tone(length: float, f0: float, f1: float, shape: String, decay: float) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var phase := 0.0
	var low := 0.0
	var end := f1 if f1 > 0.0 else f0
	for i in n:
		var t := i * Synth.INV_RATE
		var f := f0 * pow(end / f0, float(i) / n)
		phase = fposmod(phase + f * Synth.INV_RATE, 1.0)
		var x := 0.0
		match shape:
			"sine":
				x = sin(TAU * phase)
			"saw":
				x = 2.0 * phase - 1.0
			"saw_dark":
				low += ((2.0 * phase - 1.0) - low) * 0.08
				x = low * 2.0
			"square_dark":
				low += ((1.0 if phase < 0.5 else -1.0) - low) * 0.1
				x = low
		buf[i] = x * minf(1.0, t * 600.0) * exp(-t * decay)
	return Synth.declick(buf, 8, 300)


# Noise through a resonant band-pass that sweeps f0 to f1, with an attack and decay.
static func _noise(length: float, f0: float, f1: float, decay: float, attack := 0.002) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 7.0 + f1)
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var cutoff := minf(f0 * pow(f1 / f0, float(i) / n), 6000.0)
		var g := 2.0 * sin(PI * cutoff * Synth.INV_RATE)
		var x := rng.randf_range(-1.0, 1.0)
		low += g * band
		var high := x - low - 0.9 * band
		band += g * high
		var env := minf(1.0, t / attack) * exp(-maxf(0.0, t - attack) * decay)
		buf[i] = band * env
	return Synth.declick(buf, 16, 300)


static func _fm(length: float, f: float, ratio: float, index: float, decay: float, bend := 0.0) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var phase := 0.0
	var mod := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var freq := f * Harmony.ratio(bend * float(i) / n)
		phase += TAU * freq * Synth.INV_RATE
		mod += TAU * freq * ratio * Synth.INV_RATE
		buf[i] = sin(phase + index * exp(-t * decay * 1.5) * sin(mod)) * minf(1.0, t * 900.0) * exp(-t * decay)
	return Synth.declick(buf, 8, 300)


static func _fm_sweep(length: float, f0: float, f1: float, index: float, decay: float) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var phase := 0.0
	var mod := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var f := f0 * pow(f1 / f0, float(i) / n)
		phase += TAU * f * Synth.INV_RATE
		mod += TAU * f * 1.5 * Synth.INV_RATE
		buf[i] = sin(phase + index * exp(-t * 20.0) * sin(mod)) * minf(1.0, t * 1500.0) * exp(-t * decay)
	return Synth.declick(buf, 4, 200)


static func _arpeggio(notes: Array, gap: float, instrument: String, tail: float) -> PackedFloat32Array:
	var parts := []
	for i in notes.size():
		parts.append([_cut(Synth.note(instrument, notes[i]), tail), Synth.seconds(gap * i), 1.0 - 0.1 * i])
	return _mix(parts)


static func _slam() -> PackedFloat32Array:
	var n := Synth.seconds(0.85)
	var buf := Synth.buffer(n)
	var phase := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var f := 28.0 + 60.0 * exp(-t * 14.0)
		phase += TAU * f * Synth.INV_RATE
		buf[i] = tanh(2.2 * sin(phase)) * exp(-t * 4.5)
	return _mix([[buf, 0, 1.0], [_noise(0.3, 1200.0, 200.0, 12.0), 0, 0.8], [_cut(Synth.crash(), 0.8), 0, 0.25]], true)


static func _boing() -> PackedFloat32Array:
	var n := Synth.seconds(0.36)
	var buf := Synth.buffer(n)
	var phase := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var f := 180.0 * pow(1100.0 / 180.0, minf(1.0, t / 0.22)) * (1.0 + 0.06 * sin(TAU * 32.0 * t) * exp(-t * 8.0))
		phase += TAU * f * Synth.INV_RATE
		buf[i] = sin(phase) * minf(1.0, t * 500.0) * exp(-t * 7.0)
	return _mix([[buf, 0, 0.8], [_noise(0.3, 900.0, 4200.0, 9.0, 0.03), 0, 0.6]])


static func _special() -> PackedFloat32Array:
	var parts: Array = [[_fm_sweep(0.35, 2200.0, 300.0, 6.0, 8.0), 0, 0.7]]
	var rung := 0
	for i in 6:
		parts.append([_cut(Synth.note("bell", 74 + Harmony.pentatonic_step(rung)), 0.3), Synth.seconds(0.03 * i), 0.45])
		rung += 1
	return _mix(parts)


static func _death() -> PackedFloat32Array:
	var parts := []
	var line := [57, 53, 50]
	for i in line.size():
		parts.append([_tone(0.2, Harmony.hz(line[i]), Harmony.hz(line[i]), "square_dark", 5.0), Synth.seconds(0.17 * i), 0.8])
	# The power-down: a low D that sags a fourth as it dies.
	parts.append([_tone(0.9, Harmony.hz(38), Harmony.hz(31), "saw_dark", 3.0), Synth.seconds(0.51), 1.0])
	return _mix(parts, true)


static func _hum() -> PackedFloat32Array:
	var n := Synth.seconds(0.32)
	var buf := Synth.buffer(n)
	var f := Harmony.hz(62)
	for i in n:
		var t := i * Synth.INV_RATE
		var env := sin(PI * float(i) / n)
		buf[i] = (sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.5 * t) + 0.25 * sin(TAU * f * 2.0 * t)) * env * (0.8 + 0.2 * sin(TAU * 18.0 * t))
	return buf


# Two falling minor-third "WAH"s, one beat each: low, minor, impossible to miss.
static func _klaxon() -> PackedFloat32Array:
	var parts := []
	for pulse in 2:
		parts.append([_tone(Harmony.BEAT * 1.9 / RATE, Harmony.hz(53), Harmony.hz(50), "square_dark", 1.2), Harmony.BEAT * 2 * pulse, 1.0])
		parts.append([_tone(Harmony.BEAT * 1.9 / RATE, Harmony.hz(41), Harmony.hz(38), "saw_dark", 1.2), Harmony.BEAT * 2 * pulse, 0.6])
	return _mix(parts, true)


# A one-beat reverse swell that ends exactly on the next downbeat.
static func _riser() -> PackedFloat32Array:
	var n := Harmony.BEAT
	var noise := _noise(float(n) / RATE, 400.0, 5000.0, 0.0, 0.001)
	for i in n:
		var x := float(i) / n
		noise[i] *= x * x * x
	return Synth.normalize(noise, 0.9)
