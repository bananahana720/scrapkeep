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
	"stinger_unseal": 4,
	"class_up": 2,
	"class_down": 2,
	"threat_up": 1,
	"synergy_fanfare": 4,
	"warden_theme_in": 4,
	"boss_arena_in": 4,
	"boss_phase": 2,
	"stinger_boss_defeated": 8,
	"build_riser": 8,
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
	"stinger_unseal": -3.0, "class_up": -3.0, "clank": -6.0, "scrap_rip": -4.0, "threat_up": -6.0,
	"core_socket": -3.0, "synergy_fanfare": 0.0, "found_chime": -6.0, "element_resolved": -8.0,
	"ice_form": -7.0, "zap_hum": -8.0, "shatter": -5.0, "warden_theme_in": -6.0, "class_down": -6.0,
	"boss_arena_in": -3.0, "boss_phase": -4.0, "boss_telegraph": -4.0, "boss_weak_hit": -7.0,
	"stinger_boss_defeated": -1.0,
	"womp": -8.0, "build_riser": -4.0, "stage_fade": -12.0,
	"vault_rise": -6.0, "vault_drop": -2.0, "synergy_hit": -10.0,
	"threat_tick": -7.0, "threat_whoosh": -6.0, "threat_whistle": -8.0, "threat_hum": -7.0,
}

static var _samples := {}
# The live key and level a keyed or themed bake is for (see samples_at).
static var _shift := 0
static var _theme := 0
static var _lock := Mutex.new()
# Cues whose notes depend on the level (the synergy fanfare quotes its motif).
const THEMED := ["synergy_fanfare"]
static var _streams := {}


static func has_recipe(id: String) -> bool:
	return TRIM_DB.has(id)


static func trim_db(id: String) -> float:
	return TRIM_DB.get(id, -8.0)


static func samples(id: String) -> PackedFloat32Array:
	if not _samples.has(id):
		_samples[id] = Synth.normalize(_bake(id), 0.9)
	return _samples[id]


# A grid stinger baked on another tempo's grid, for the boss tempo. Cues that are not
# written on the grid are the same at any tempo.
static func samples_at(id: String, step: int, shift := 0, theme := 0) -> PackedFloat32Array:
	var themed := id in THEMED
	if (step == Harmony.STEP or not STINGER_BEATS.has(id)) and shift == 0 and (not themed or theme == 0):
		return samples(id)
	var key := "%s@%d@%d@%d" % [id, step if STINGER_BEATS.has(id) else Harmony.STEP, shift, theme if themed else 0]
	if _samples.has(key):
		return _samples[key]
	# A worker warms keyed variants while the band may ask for one: one bake at a time.
	_lock.lock()
	if not _samples.has(key):
		if STINGER_BEATS.has(id):
			Synth.score_step = step
		Synth.score_transpose = shift
		_shift = shift
		_theme = theme
		_samples[key] = Synth.normalize(_bake(id), 0.9)
		Synth.score_step = Harmony.STEP
		Synth.score_transpose = 0
		_shift = 0
		_theme = 0
	_lock.unlock()
	return _samples[key]


# Every tonal recipe reads pitches through these, so a keyed bake transposes it whole.
static func _hz(midi: float) -> float:
	return Harmony.hz(midi + _shift)


static func _n(instrument: String, midi: int) -> PackedFloat32Array:
	return Synth.note(instrument, midi + _shift)


static func stream(id: String) -> AudioStreamWAV:
	if not _streams.has(id):
		_streams[id] = Synth.to_wav(samples(id))
	return _streams[id]


static func bake_all(ids: Array) -> void:
	for id in ids:
		stream(id)
	for id in STINGER_BEATS:
		samples_at(id, Harmony.BOSS_STEP)


static func _bake(id: String) -> PackedFloat32Array:
	match id:
		"ui_tick":
			return _tone(0.03, _hz(86), _hz(86), "sine", 120.0)
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
			return _fm(0.24, _hz(81), 3.5, 5.0, 16.0)
		"grapple_release":
			return _fm(0.15, _hz(76), 2.0, 1.5, 24.0, -2.0)
		"pylon_plant":
			return _mix([[_tone(0.16, 130.0, 55.0, "sine", 22.0), 0, 1.0], [_fm(0.3, _hz(62), 2.76, 4.0, 12.0), 0, 0.6],
				[_tone(0.2, 440.0, 880.0, "sine", 8.0), Synth.seconds(0.1), 0.25]])
		"pylon_eject":
			return _boing()
		"enemy_arrive":
			return _mix([[_tone(0.16, _hz(40), _hz(40), "saw_dark", 6.0), 0, 1.0],
				[_tone(0.2, _hz(41), _hz(41), "saw_dark", 6.0), Synth.seconds(0.14), 1.0]])
		"hit_thwack":
			return _mix([[_noise(0.14, 1300.0, 700.0, 30.0), 0, 0.8], [_tone(0.14, 230.0, 85.0, "sine", 26.0), 0, 1.0]], true)
		"weapon_zap":
			return _fm_sweep(0.1, 1500.0, 480.0, 4.0, 30.0)
		"special_fire":
			return _special()
		"kill_pop":
			return _mix([[_tone(0.05, 500.0, 1300.0, "sine", 50.0), 0, 0.6], [_n("bell", 81), 0, 0.8]])
		"hurt":
			return _mix([[_tone(0.13, _hz(53), _hz(53), "square_dark", 8.0), 0, 1.0],
				[_tone(0.2, _hz(50), _hz(48), "square_dark", 9.0), Synth.seconds(0.11), 1.0],
				[_noise(0.1, 900.0, 300.0, 30.0), 0, 0.5]], true)
		"death":
			return _death()
		"scrap_tick":
			return _mix([[_cut(_n("bell", 74), 0.16), 0, 1.0], [_noise(0.01, 6000.0, 6000.0, 300.0), 0, 0.2]])
		"part_get":
			return _arpeggio([74, 77, 81, 86], 0.05, "bell", 0.8)
		"beacon_hum":
			return _hum()
		"gate_through":
			return _mix([[_noise(0.3, 800.0, 3600.0, 10.0, 0.03), 0, 0.6], [_n("bell", 81), Synth.seconds(0.04), 0.6],
				[_n("bell", 86), Synth.seconds(0.04), 0.5], [_n("bell", 89), Synth.seconds(0.04), 0.4]])
		"launch_roar":
			return _mix([[_noise(1.1, 300.0, 4200.0, 2.4, 0.5), 0, 1.0], [_tone(1.0, 90.0, 720.0, "saw_dark", 2.2), 0, 0.5]], true)
		"klaxon":
			return _klaxon()
		"event_start":
			return _mix([[Synth.kick(), 0, 1.0], [_n("keys", 50), 0, 0.5], [_n("keys", 53), 0, 0.5],
				[_n("keys", 57), 0, 0.5], [_n("keys", 63), 0, 0.4]], true, 0.8)
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
		"stinger_unseal":
			return _unseal()
		"class_up":
			return Synth.render_score(_score_class_up(), 0.9)
		"class_down":
			return _mix([[Synth.render_score(_score_class_down(), 0.7), 0, 1.0], [_noise(0.18, 3500.0, 1500.0, 14.0), Synth.seconds(0.05), 0.25]])
		"clank":
			return _clank()
		"scrap_rip":
			return _rip()
		"threat_up":
			return _mix([[_tone(0.07, _hz(62), _hz(62), "square_dark", 18.0), 0, 0.9],
				[_tone(0.12, _hz(65), _hz(67), "square_dark", 14.0), Synth.seconds(0.08), 1.0]], true)
		"core_socket":
			return _core_socket()
		"synergy_fanfare":
			return Synth.render_score(_score_synergy(), 1.4)
		"found_chime":
			return _mix([[_cut(_n("mallet", 77), 0.35), 0, 0.8], [_fm(0.5, _hz(86), 3.5, 1.2, 6.0, 0.3), Synth.seconds(0.12), 0.7]])
		"element_resolved":
			return _mix([[_cut(_n("bell", 81), 0.3), 0, 0.7], [_noise(0.25, 2000.0, 5000.0, 14.0, 0.01), 0, 0.5]])
		"warden_theme_in":
			return _warden_in()
		"womp":
			return _womp()
		"build_riser":
			return _build_riser()
		"ice_form":
			return _ice()
		"zap_hum":
			return _zap_hum()
		"shatter":
			return _shatter()
		"stage_fade":
			return _stage_fade()
		"vault_rise":
			return _mix([[_noise(0.32, 600.0, 4200.0, 3.0, 0.2), 0, 0.6], [_tone(0.32, _hz(62), _hz(74), "saw_dark", 4.0), 0, 0.6]])
		"vault_drop":
			return Synth.render_score([[0, 0, 2, "kick", 1.0], [0, 0, 8, "crash", 0.6], [0, 38, 8, "sub", 0.8],
				[0, 62, 4, "bell", 0.5], [0, 66, 4, "bell", 0.45], [0, 69, 4, "bell", 0.45], [2, 74, 6, "bell", 0.55]], 0.6)
		"synergy_hit":
			return _mix([[_fm(0.22, _hz(81), 3.5, 1.4, 14.0), 0, 0.8], [_noise(0.06, 5000.0, 3000.0, 60.0), 0, 0.2]])
		"boss_arena_in":
			return _brindle_in()
		"boss_phase":
			return Synth.render_score([[0, 0, 2, "boom", 1.0], [0, 0, 2, "anvil", 0.9], [0, 50, 6, "brass", 0.5],
				[0, 53, 6, "brass", 0.5], [0, 57, 6, "brass", 0.5], [0, 63, 6, "brass", 0.5], [4, 0, 1, "anvil", 0.7],
				[6, 0, 1, "anvil", 0.8], [6, 62, 2, "brass", 0.6], [6, 74, 2, "brass", 0.45]], 0.6)
		"boss_telegraph":
			return _boss_telegraph()
		"boss_weak_hit":
			return _mix([[_fm(0.28, _hz(79), 3.5, 3.0, 13.0), 0, 0.9], [_tone(0.1, 180.0, 90.0, "sine", 30.0), 0, 0.6],
				[_noise(0.03, 4500.0, 2500.0, 120.0), 0, 0.4]])
		"stinger_boss_defeated":
			return _boss_defeated()
		"threat_tick":
			return _threat_tick()
		"threat_whoosh":
			return _threat_whoosh()
		"threat_whistle":
			return _threat_whistle()
		"threat_hum":
			return _threat_hum()
	# A kind added after this bank still gets a sound: a small blip pitched from its
	# name, flagged by presentation_sfx_test so it gets a real recipe.
	return _tone(0.12, _hz(62 + Harmony.pentatonic_step(absi(id.hash()) % 8)), 0.0, "sine", 20.0)


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


# Three notes that climb: A, D, A an octave up. It says "bigger" in the band's key.
static func _score_class_up() -> Array:
	return [[0, 0, 2, "kick", 0.7], [0, 69, 2, "mallet", 0.8], [0, 69, 2, "bell", 0.35], [2, 74, 2, "mallet", 0.85],
		[2, 74, 2, "bell", 0.4], [4, 81, 4, "mallet", 0.9], [4, 81, 4, "bell", 0.5], [4, 38, 4, "sub", 0.6],
		[4, 0, 2, "open_hat", 0.4], [4, 38, 2, "fbass", 0.7]]


# A heft class lost to a crane: the climb played back down, A F D, lighter and softer.
# It lands on home, not below it, because the spill trail pays the mass back.
static func _score_class_down() -> Array:
	return [[0, 81, 2, "mallet", 0.7], [2, 77, 2, "mallet", 0.65], [4, 74, 3, "mallet", 0.7], [4, 74, 3, "bell", 0.25]]


# The discovery: a bebop run up the Dorian scale with a chromatic lean on C#, landing
# on high D over the home chord with a crash. The most exciting short cue in the game.
static func _score_synergy() -> Array:
	# The run climbs into the current level's motif, its first four notes an octave up.
	var head: Array = Harmony.MOTIF_HEADS[clampi(_theme, 0, 2)]
	var run := [[0, 69], [1, 72], [2, 74], [3, 76], [4, head[0] + 12 if head[0] < 74 else head[0]], [5, head[1] + (12 if head[0] < 74 else 0)],
		[6, head[2] + (12 if head[0] < 74 else 0)], [7, 85]]
	var score := []
	for note in run:
		score.append([note[0], note[1], 1, "lead", 0.6])
		score.append([note[0], note[1] + 12, 1, "bell", 0.25])
	score.append_array([[6, 0, 1, "snare", 0.6], [7, 0, 1, "snare", 0.8], [8, 0, 2, "kick", 1.0], [8, 0, 16, "crash", 0.6],
		[8, 86, 8, "lead", 0.75], [8, 98, 8, "bell", 0.45], [8, 53, 8, "keys", 0.4], [8, 57, 8, "keys", 0.4],
		[8, 60, 8, "keys", 0.4], [8, 64, 8, "keys", 0.4], [8, 38, 8, "sub", 0.6], [12, 81, 2, "bell", 0.35],
		[13, 86, 3, "bell", 0.35]])
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
		parts.append([_cut(_n(instrument, notes[i]), tail), Synth.seconds(gap * i), 1.0 - 0.1 * i])
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
		parts.append([_cut(_n("bell", 74 + Harmony.pentatonic_step(rung)), 0.3), Synth.seconds(0.03 * i), 0.45])
		rung += 1
	return _mix(parts)


static func _death() -> PackedFloat32Array:
	var parts := []
	var line := [57, 53, 50]
	for i in line.size():
		parts.append([_tone(0.2, _hz(line[i]), _hz(line[i]), "square_dark", 5.0), Synth.seconds(0.17 * i), 0.8])
	# The power-down: a low D that sags a fourth as it dies.
	parts.append([_tone(0.9, _hz(38), _hz(31), "saw_dark", 3.0), Synth.seconds(0.51), 1.0])
	return _mix(parts, true)


static func _hum() -> PackedFloat32Array:
	var n := Synth.seconds(0.32)
	var buf := Synth.buffer(n)
	var f := _hz(62)
	for i in n:
		var t := i * Synth.INV_RATE
		var env := sin(PI * float(i) / n)
		buf[i] = (sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.5 * t) + 0.25 * sin(TAU * f * 2.0 * t)) * env * (0.8 + 0.2 * sin(TAU * 18.0 * t))
	return buf


# Two falling minor-third "WAH"s, one beat each: low, minor, impossible to miss.
static func _klaxon() -> PackedFloat32Array:
	var parts := []
	var beat := Synth.score_step * Harmony.STEPS_PER_BEAT
	for pulse in 2:
		parts.append([_tone(beat * 1.9 / RATE, _hz(53), _hz(50), "square_dark", 1.2), beat * 2 * pulse, 1.0])
		parts.append([_tone(beat * 1.9 / RATE, _hz(41), _hz(38), "saw_dark", 1.2), beat * 2 * pulse, 0.6])
	return _mix(parts, true)


# The Warden breaks: a clamp tearing loose, then the band hits and bells climb out.
static func _unseal() -> PackedFloat32Array:
	var score := [[0, 0, 2, "kick", 1.0], [0, 0, 16, "crash", 0.7], [0, 74, 1, "bell", 0.5], [1, 81, 1, "bell", 0.5],
		[2, 86, 1, "bell", 0.5], [3, 89, 1, "bell", 0.5], [4, 93, 4, "bell", 0.55], [4, 86, 10, "lead", 0.7],
		[4, 65, 10, "keys", 0.4], [4, 69, 10, "keys", 0.4], [4, 72, 10, "keys", 0.4], [4, 76, 10, "keys", 0.4],
		[4, 38, 10, "sub", 0.7], [8, 0, 1, "snare", 0.5], [10, 0, 1, "snare", 0.6], [12, 0, 1, "snare", 0.7],
		[13, 0, 1, "snare", 0.8], [14, 0, 1, "snare", 0.9], [15, 0, 1, "snare", 1.0]]
	var band := Synth.render_score(score, 1.0)
	var release := _mix([[_fm(0.5, 150.0, 1.41, 6.0, 7.0, -5.0), 0, 1.0], [_noise(0.35, 3000.0, 300.0, 9.0), 0, 0.8]], true)
	return _mix([[band, 0, 1.0], [release, 0, 0.6]])


# A plated hit that bounced: a bright ringing plate an octave above the punch, with
# no low body, so it reads as "not through" next to hit_thwack's meaty thud.
static func _clank() -> PackedFloat32Array:
	return _mix([[_fm(0.3, _hz(76), 1.41, 1.6, 11.0), 0, 1.0], [_fm(0.22, _hz(83), 2.76, 1.2, 16.0), 0, 0.55],
		[_tone(0.03, 1800.0, 1200.0, "sine", 90.0), 0, 0.3]])


# Torn metal: a zipper of teeth sweeping down while a saw sags.
static func _rip() -> PackedFloat32Array:
	var n := Synth.seconds(0.45)
	var teeth := _noise(0.45, 4200.0, 500.0, 3.0, 0.005)
	for i in n:
		var t := i * Synth.INV_RATE
		var rate := lerpf(70.0, 18.0, float(i) / n)
		teeth[i] *= 0.4 + 0.6 * maxf(0.0, sin(TAU * rate * t))
	return _mix([[teeth, 0, 1.0], [_tone(0.4, 820.0, 180.0, "saw_dark", 5.0), 0, 0.5]], true)


# The lock-in: a click, a thud, and a clean fifth on D that rings out.
static func _core_socket() -> PackedFloat32Array:
	return _mix([[_noise(0.02, 5000.0, 5000.0, 250.0), 0, 0.5], [_tone(0.12, 140.0, 80.0, "sine", 28.0), 0, 0.8],
		[_n("bell", 74), Synth.seconds(0.05), 0.7], [_n("bell", 81), Synth.seconds(0.05), 0.6],
		[_cut(_n("bell", 86), 0.6), Synth.seconds(0.16), 0.45]])


# The Warden wakes: a low anvil strike and a Neapolitan brass swell (Eb over D), the
# sound of the band turning toward the boss groove.
static func _warden_in() -> PackedFloat32Array:
	var score := [[0, 0, 2, "kick", 1.0], [0, 38, 16, "sub", 0.7], [0, 51, 12, "brass", 0.45], [0, 55, 12, "brass", 0.45],
		[0, 58, 12, "brass", 0.45], [4, 0, 2, "kick", 0.8], [8, 0, 2, "kick", 0.9], [12, 0, 2, "kick", 1.0],
		[12, 0, 1, "snare", 0.7], [13, 0, 1, "snare", 0.8], [14, 0, 1, "snare", 0.9], [15, 0, 1, "snare", 1.0]]
	var band := Synth.render_score(score, 0.8)
	return _mix([[band, 0, 1.0], [_fm(0.9, _hz(38), 2.71, 5.0, 3.5), 0, 0.5]], true)


# The slam womp: a sub that drops out of the floor with a thump on top, instant.
static func _womp() -> PackedFloat32Array:
	var n := Synth.seconds(0.62)
	var buf := Synth.buffer(n)
	var phase := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		phase += TAU * (34.0 + 52.0 * exp(-t * 9.0)) * Synth.INV_RATE
		buf[i] = tanh(2.0 * sin(phase)) * minf(1.0, t * 400.0) * exp(-t * 3.2)
	return _mix([[buf, 0, 1.0], [_noise(0.08, 900.0, 200.0, 40.0), 0, 0.3]], true)


# Two bars of rising noise and pitch, the build's riser (on the grid it is baked for).
static func _build_riser() -> PackedFloat32Array:
	var n := Synth.score_step * Harmony.STEPS_PER_BAR * 2
	var noise := _noise(float(n) / RATE, 300.0, 6000.0, 0.0, 0.001)
	var phase := 0.0
	for i in n:
		var x := float(i) / n
		phase += TAU * lerpf(110.0, 880.0, x * x) * Synth.INV_RATE
		noise[i] = (noise[i] * 0.8 + sin(phase) * 0.35) * x * x
	return Synth.normalize(noise, 0.9)


static func _ice() -> PackedFloat32Array:
	var parts: Array = [[_noise(0.3, 6000.0, 6000.0, 12.0, 0.002), 0, 0.35]]
	var notes := [86, 93, 88, 98, 91]
	for i in notes.size():
		parts.append([_fm(0.3, _hz(notes[i]), 3.5, 1.5, 10.0), Synth.seconds(0.035 * i), 0.5])
	return _mix(parts)


static func _zap_hum() -> PackedFloat32Array:
	var n := Synth.seconds(0.6)
	var buf := Synth.buffer(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var phase := 0.0
	var low := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		phase = fposmod(phase + _hz(45) * Synth.INV_RATE, 1.0)
		low += ((2.0 * phase - 1.0) - low) * 0.25
		var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.02 else 0.0
		buf[i] = (low * (0.6 + 0.4 * sin(TAU * 60.0 * t)) + crackle * 0.8) * minf(1.0, t * 80.0) * exp(-t * 4.0)
	return Synth.declick(buf, 16, 600)


static func _shatter() -> PackedFloat32Array:
	var parts: Array = [[_noise(0.25, 5000.0, 2500.0, 16.0, 0.001), 0, 0.8]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		parts.append([_fm(0.18, rng.randf_range(2200.0, 6000.0), 2.3, 1.0, 26.0), Synth.seconds(rng.randf_range(0.0, 0.12)), 0.35])
	return _mix(parts)


# Admiral Brindle's arrival: two anvil strikes and a brass fanfare that climbs D, F,
# A and lands on the flat second, Eb, the Phrygian colour of his whole arena.
static func _brindle_in() -> PackedFloat32Array:
	var score := [[0, 0, 2, "boom", 1.0], [0, 0, 2, "anvil", 1.0], [0, 38, 16, "sub", 0.6], [2, 0, 2, "anvil", 0.8],
		[4, 62, 2, "brass", 0.6], [6, 65, 2, "brass", 0.6], [8, 69, 2, "brass", 0.65], [8, 0, 2, "kick", 0.9],
		[10, 75, 6, "brass", 0.7], [10, 51, 6, "brass", 0.4], [10, 55, 6, "brass", 0.4], [10, 58, 6, "brass", 0.4],
		[10, 0, 16, "crash", 0.5], [12, 0, 1, "snare", 0.6], [13, 0, 1, "snare", 0.7], [14, 0, 1, "snare", 0.85],
		[15, 0, 1, "snare", 1.0]]
	return Synth.render_score(score, 0.9)


# The stage's ambience drawn out before the arena: a soft breath of air that falls
# and fades, with a low D under it. Quiet on purpose; the arena music is the event.
static func _stage_fade() -> PackedFloat32Array:
	var air := _noise(0.7, 2600.0, 400.0, 0.0, 0.08)
	var n := air.size()
	for i in n:
		var x := float(i) / n
		air[i] *= (1.0 - x) * (1.0 - x)
	return _mix([[air, 0, 1.0], [_tone(0.6, _hz(50), _hz(50), "sine", 4.0), 0, 0.35]], false, 0.6)


# A wind-up: two low minor-second pulses (D, Eb) with a rising noise, over in 0.4 s so
# it never masks the hit it warns about.
static func _boss_telegraph() -> PackedFloat32Array:
	return _mix([[_tone(0.12, _hz(50), _hz(50), "square_dark", 10.0), 0, 0.9],
		[_tone(0.18, _hz(51), _hz(52), "square_dark", 8.0), Synth.seconds(0.13), 1.0],
		[_noise(0.35, 600.0, 3000.0, 3.0, 0.2), 0, 0.35]], true)


# Brindle routed: the brass fanfare in D major, a bell run to the top, and the
# rice-cooker resolution on high D over a held D major chord.
static func _boss_defeated() -> PackedFloat32Array:
	var score := [[0, 0, 2, "boom", 1.0], [0, 0, 16, "crash", 0.7], [0, 62, 2, "brass", 0.6], [2, 66, 2, "brass", 0.6],
		[4, 69, 2, "brass", 0.65], [6, 74, 2, "brass", 0.7], [8, 0, 2, "kick", 1.0], [8, 78, 4, "brass", 0.7],
		[12, 76, 2, "brass", 0.6], [14, 73, 2, "brass", 0.65], [16, 0, 2, "kick", 1.0], [16, 0, 16, "crash", 0.6],
		[16, 74, 16, "brass", 0.75], [16, 86, 16, "bell", 0.5], [16, 50, 16, "keys", 0.4], [16, 54, 16, "keys", 0.4],
		[16, 57, 16, "keys", 0.4], [16, 62, 16, "keys", 0.4], [16, 38, 16, "sub", 0.7]]
	for i in 8:
		score.append([8 + i, 0, 1, "hat", 0.4])
		score.append([8 + i, [74, 78, 81, 86, 90, 93, 98, 93][i], 1, "bell", 0.3])
	return Synth.render_score(score, 1.6)


# A one-beat reverse swell that ends exactly on the next downbeat.
static func _riser() -> PackedFloat32Array:
	var n := Synth.score_step * Harmony.STEPS_PER_BEAT
	var noise := _noise(float(n) / RATE, 400.0, 5000.0, 0.0, 0.001)
	for i in n:
		var x := float(i) / n
		noise[i] *= x * x * x
	return Synth.normalize(noise, 0.9)


# The four threat warnings (combat/threat_grammar.gd), one per attack type, each short
# enough to finish well before the hit it warns about.
# Instant: two dry ticks, a timer running out.
static func _threat_tick() -> PackedFloat32Array:
	var parts := []
	for i in 2:
		parts.append([_noise(0.04, 5200.0, 3400.0, 110.0), Synth.seconds(0.09 * i), 0.8])
		parts.append([_tone(0.05, _hz(74), _hz(74), "square_dark", 70.0), Synth.seconds(0.09 * i), 0.6 + 0.2 * i])
	return _mix(parts)


# Wave: a whoosh that rises as the front builds, over a climbing growl.
static func _threat_whoosh() -> PackedFloat32Array:
	return _mix([[_noise(0.5, 300.0, 2800.0, 2.0, 0.3), 0, 1.0], [_tone(0.5, _hz(38), _hz(50), "saw_dark", 3.0), 0, 0.5]])


# Projectile: a falling whistle, the shell coming down.
static func _threat_whistle() -> PackedFloat32Array:
	return _mix([[_tone(0.6, _hz(91), _hz(79), "sine", 1.5), 0, 1.0], [_noise(0.6, 2200.0, 1300.0, 2.5, 0.05), 0, 0.2]])


# Lane: a buzzing charge that climbs toward the release.
static func _threat_hum() -> PackedFloat32Array:
	return _mix([[_tone(0.5, _hz(38), _hz(45), "saw_dark", 1.0), 0, 0.8], [_tone(0.5, _hz(50), _hz(57), "square_dark", 1.4), 0, 0.6]], true)
