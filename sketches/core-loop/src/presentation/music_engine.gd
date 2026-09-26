extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

# The band. A sample-exact sequencer that mixes pre-rendered notes from synth.gd on a
# grid it can re-tempo and re-key. It knows nothing about the game: the audio director
# tells it the pressure, the mode, the level theme, the Warden's damage, when a boss
# arrives or changes phase, and which stingers to play; it renders stereo frames on
# demand. render(n) is pure over its own state, so the tests drive it headless.
#
# Every track shares one harmonic language, jazzy extended chords with D as home:
#   Spillway  D Dorian drum and bass: electric piano, reese, the sax lead.
#   Sluice    funk: a clavinet riff, brass stabs and hook, a mechanical groove.
#   Weir      the halfpipe: organ and a talkbox lead that climbs and rolls back.
#   Miniboss  the level darkened: minor chords, a doubled lead, a riser every 2 bars.
#   Warden    the level as four-on-the-floor club music at 129, reached through a bar
#             of half-note triplets. Its last quarter of integrity is the build; the
#             unseal is the heaviest drop of the stage.
#   Brindle   anvil and industrial drums and brass. Every phase change is a built
#             drop and lifts the key; the victory is the biggest drop, then home.
#
# A bass figure never leaves: every theme at every pressure has a rhythmic riff in its
# own character with a clean sub under it, and from mid pressure an LFO wobble locked
# to the grid (1/4, 1/8, 1/16 and triplets, switching per bar) with talking growls.
# Drops are built: a riser, an accelerating snare roll and a high-pass sweep, a short
# silence, then the drop on the downbeat.

enum { KEYS, SUB, HATS, KICK, SNARE, REESE, LEAD, ARP, WARM, WOB }
const LAYER_NAMES := ["keys", "sub", "hats", "kick", "snare", "bass", "lead", "arp", "warm", "wobble"]
# gain = floor + (1 - floor) * smoothstep(from, to, pressure). Each curve is monotonic.
# The bass figure (layer 5) has a floor: it never leaves.
const CURVES := [
	[0.85, 0.0, 0.5],
	[0.75, 0.0, 0.4],
	[0.35, 0.05, 0.3],
	[0.5, 0.1, 0.35],
	[0.0, 0.2, 0.45],
	[0.6, 0.0, 0.45],
	[0.0, 0.55, 0.8],
	[0.0, 0.75, 1.0],
]
const WOB_CURVE := [0.0, 0.5, 0.8]
const LEVELS := [0.34, 0.5, 0.22, 0.62, 0.42, 0.36, 0.36, 0.14, 0.3, 0.3]
# The warm layer is not pressure: it is the overcharge, one step per bonus core.
const OVERCHARGE_GAIN := [0.0, 0.7, 1.0]

enum { IDLE, PLAY, DEAD }
const MODE_NAMES := ["idle", "play", "dead"]
# What each mode lets through, per layer. Menus keep keys, sub, a light hat and the
# restrained bass riff; death keeps the keys alone, so the band waits with you.
const MODE_MASK := [
	[1.0, 0.7, 0.4, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0],
	[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	[0.6, 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
]
const BASS_LAYERS := [SUB, REESE, WOB]
# The build's own voices (riser, snare roll, launch tune) skip the high-pass sweep, so
# the build gets louder while the band thins out under it.
const DRY := -2
# The sweep's top: the kick and bass thin out, the snares and riser stay bright.
const SWEEP_TOP_HZ := 600.0

const RELEASE := 600
const DUCK_RELEASE := Harmony.BEAT
const RISER_SPACING := Harmony.BAR * 4
# Boss tracks move to 129 by metric modulation unless Andrew picks "held at 172".
const BOSS_PIVOT_DEFAULT := true
# Brindle's phase 3 runs at 150.
const PHASE3_STEP := 4410
# The sidechain pump: the pumped layers dip under each kick and breathe back.
const PUMP_ATTACK := 400
const PUMPED := [KEYS, SUB, REESE, LEAD, ARP, WARM, WOB]
const PRESSURE_FLOOR := {"level": 0.0, "miniboss": 0.8, "warden:build": 0.55, "warden:drop": 1.0, "brindle": 1.0}
const LEAD_VOICE := ["lead", "brass", "talk"]
# The Warden's build starts when it is three quarters broken.
const WARDEN_BUILD_FROM := 0.75
# Brindle's key per section, in semitones above D: each phase lifts it.
const BRINDLE_KEY := {"1": 0, "2": 1, "3": 2, "chase": 2, "victory": 0}

# Wobble rates in LFO cycles per beat. Each bar takes the next rate in its list.
const RATES := {"1/4": 1, "1/8": 2, "1/16": 4, "1/8T": 3, "1/16T": 6}
const THEME_RATES := [
	["1/8", "1/8", "1/16T", "1/8", "1/4", "1/16", "1/8T", "1/16"],
	["1/16", "1/8", "1/16", "1/8T", "1/16", "1/8", "1/16T", "1/16"],
	["1/8T", "1/4", "1/8T", "1/8", "1/8T", "1/4", "1/16T", "1/8"],
]
const DROP_RATES := ["1/8", "1/16T", "1/8", "1/16", "1/4", "1/8T", "1/16", "1/16T"]
const HALF_RATES := ["1/4", "1/8T", "1/4", "1/8"]
const THEME_VOWEL := ["wub", "yoi", "wub"]

const MOTIF := [[2, 69, 2], [4, 72, 1], [5, 74, 1], [6, 76, 2], [8, 74, 2], [10, 72, 1], [11, 69, 3],
	[16, 67, 2], [18, 65, 2], [20, 69, 6]]
const MOTIF_SLUICE := [[0, 74, 1], [2, 77, 1], [3, 79, 1], [5, 81, 3], [8, 84, 2], [10, 81, 1], [11, 79, 1],
	[12, 77, 2], [14, 74, 2], [16, 72, 2], [18, 74, 4], [24, 77, 1], [25, 79, 1], [26, 74, 4]]
const MOTIF_WEIR := [[0, 62, 2], [2, 65, 2], [4, 69, 2], [6, 72, 2], [8, 74, 3], [11, 76, 1], [12, 77, 4],
	[16, 76, 2], [18, 74, 2], [20, 72, 6]]
const VICTORY_LEAD := [[0, 74, 2], [2, 77, 2], [4, 81, 4], [8, 79, 2], [10, 77, 2], [12, 76, 4], [16, 72, 2],
	[18, 76, 2], [20, 79, 4], [24, 77, 2], [26, 76, 2], [28, 73, 4], [32, 74, 4], [36, 81, 4], [40, 86, 8]]
# Clavinet riffs: step -> voicing index. The busy riff is the Sluice hook.
const CLAV_CALM := {0: 0, 3: 2, 8: 1, 11: 3}
const CLAV_BUSY := {0: 0, 2: 2, 3: 1, 5: 3, 7: 2, 8: 0, 10: 1, 11: 3, 13: 2, 15: 1}
# Bass figures: step -> [semitones above the root, length in steps].
const DNB_CALM := {0: [0, 3], 6: [0, 1], 10: [7, 3]}
const FUNK_BASS := {0: [0, 2], 2: [12, 1], 3: [0, 1], 6: [7, 1], 7: [10, 1], 8: [12, 1], 10: [0, 2], 12: [12, 1]}
const FUNK_CALM := {0: [0, 2], 3: [12, 1], 10: [0, 2], 13: [7, 1]}
const WEIR_CALM := {0: [0, 4], 6: [7, 2], 8: [12, 4], 14: [10, 2]}
const HOUSE_BASS := {0: [0, 1], 2: [12, 1], 3: [0, 1], 6: [12, 1], 7: [10, 1], 10: [0, 1], 11: [12, 1], 14: [7, 1]}
const BRINDLE_BASS := {0: [0, 6], 6: [0, 2], 8: [12, 2], 10: [0, 4], 14: [1, 2]}


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
var overcharge := 0
var phrase_index := 0
var out_music := PackedVector2Array()
var out_stinger := PackedVector2Array()
# [id, start_sample] each time a stinger actually starts, for tests and the notes.
var stinger_starts: Array = []
var lane_free_at := 0
# The grid: one sixteenth is step_len samples, counted from grid_origin.
var step_len := Harmony.STEP
var grid_origin := 0
var theme := 0
var track := "level"
var section := ""
# Semitones above D the band is playing in.
var key := 0
var boss_pivot := BOSS_PIVOT_DEFAULT
# [what, sample, detail] for every tempo, theme, track, key, build, gap and drop
# change, for the tests and the notes.
var events_log: Array = []
# The recent wobble cycles: [start_sample, rate, period, midi, grid_origin, step_len,
# bar_origin, bar].
var wob_log: Array = []
# Notes started per layer, so a test can tell a rhythmic figure from a held note.
var layer_starts := PackedInt32Array()
# Tests solo layers to measure them alone.
var solo: Array = []

var _gains := PackedFloat32Array()
var _targets := PackedFloat32Array()
var _voices: Array = []
var _actions: Array = []
var _step_clock := -1
var _bar_step := 0
var _lead: Array = []
var _lead_voice := "lead"
var _cadence_bar := -1
var _cadence_then := {}
var _groove := 0
var _duck := 1.0
var _duck_target := 1.0
var _duck_until := 0
var _bass_duck := 1.0
var _bass_duck_target := 1.0
var _bass_duck_until := 0
var _last_riser := -RISER_SPACING
var _pulse_from := -1
var _pulse_until := -1
var _pump_depth := 0.0
var _ramp := {}
var _build_from := -1
var _build_len := 1
var _build_level := -1.0
var _build_tune := false
var _build_riser: Voice
var _pending_drop := {}
var _gap := false
var _gate := 1.0
var _drop := {}
var _hp := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _mid := PackedFloat32Array()
var _left := PackedFloat32Array()
var _right := PackedFloat32Array()
var _sl := PackedFloat32Array()
var _sr := PackedFloat32Array()
var _dl := PackedFloat32Array()
var _dr := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _stingers_live := false


func _init() -> void:
	_gains.resize(LAYER_NAMES.size())
	_targets.resize(LAYER_NAMES.size())
	layer_starts.resize(LAYER_NAMES.size())
	_retarget()
	for i in _gains.size():
		_gains[i] = _targets[i]
	_lead = _make_track_lead()


# Spillway and the cadence: what the title and stage 1 need, before the music starts.
static func prepare() -> void:
	_prepare_chords(Harmony.PROGRESSION + Harmony.CADENCE + [Harmony.MINOR_OF["G13"], Harmony.MINOR_OF["Cmaj9"], Harmony.MINOR_OF["Bbmaj9"]], ["lead"], 0)
	for drum in Synth.DRUMS:
		Synth.drum(drum)
	for chord in Harmony.PROGRESSION:
		Synth.note("reese", chord["root"] + 19)
		Synth.note("growl", chord["root"])
		Synth.note("growl_wub", chord["root"])
		Synth.note("growl_wub", chord["root"] + 12)
	_prepare_wobble(Harmony.PROGRESSION, [0], [Harmony.STEP], ["wub", "yoi"])


# The other themes, keys and boss tracks: on a background worker behind stage 1.
# Anything asked for before it lands renders on demand.
static func prepare_rest() -> void:
	var chords: Array = []
	for list in [Harmony.SLUICE, Harmony.WEIR, Harmony.BRINDLE, Harmony.VICTORY, Harmony.MINOR_OF.values(), Harmony.BRINDLE_PHRYGIAN]:
		chords.append_array(list)
	_prepare_chords(chords, ["brass", "talk"], 0)
	_prepare_chords(Harmony.BRINDLE_PHRYGIAN, ["brass"], 1)
	_prepare_chords(Harmony.BRINDLE, ["brass"], 2)
	for list in [Harmony.WEIR, Harmony.BRINDLE, Harmony.MINOR_OF.values(), Harmony.BRINDLE_PHRYGIAN]:
		for chord in list:
			Synth.organ_chord(chord["voicing"])
	for pair in [[Harmony.PROGRESSION, 0], [Harmony.SLUICE, 0], [Harmony.WEIR, 0], [Harmony.VICTORY, 0], [Harmony.BRINDLE, 0],
			[Harmony.BRINDLE_PHRYGIAN, 1], [Harmony.BRINDLE, 2]]:
		var shift: int = pair[1]
		for chord in pair[0]:
			var voicing := _shift(chord["voicing"], shift)
			var root: int = int(chord["root"]) + shift
			Synth.stab_chord(voicing, false)
			Synth.stab_chord(voicing, true)
			for offset in [0, 7, 10, 12]:
				Synth.note("fbass", root + offset)
			for offset in [12, 19, 22, 24]:
				Synth.note("reese", root + offset)
			for offset in [0, 7, 12]:
				Synth.note("growl", root + offset)
				Synth.note("growl_wub", root + offset)
			for midi in voicing:
				Synth.note("clav", midi)
				Synth.note("clav", midi + 12)
				Synth.note("clav", midi + 24)
	_prepare_wobble(Harmony.SLUICE, [0], [Harmony.STEP], ["yoi"])
	_prepare_wobble(Harmony.WEIR, [0], [Harmony.STEP], ["wub"])
	_prepare_wobble(Harmony.PROGRESSION + Harmony.SLUICE + Harmony.WEIR, [0], [Harmony.BOSS_STEP], ["wub", "yoi"])
	_prepare_wobble(Harmony.BRINDLE, [0], [Harmony.BOSS_STEP], ["wub"])
	_prepare_wobble(Harmony.BRINDLE_PHRYGIAN, [1], [Harmony.BOSS_STEP], ["wub", "yoi"])
	_prepare_wobble(Harmony.BRINDLE, [2], [PHASE3_STEP], ["wub", "yoi"])
	_prepare_wobble(Harmony.BRINDLE + Harmony.VICTORY, [0, 2], [Harmony.STEP], ["wub", "yoi"])


static func prepare_all() -> void:
	prepare()
	prepare_rest()


static func _shift(voicing: Array, by: int) -> Array:
	var out := []
	for midi in voicing:
		out.append(int(midi) + by)
	return out


static func _prepare_chords(chords: Array, leads: Array, shift: int) -> void:
	for chord in chords:
		var voicing := _shift(chord["voicing"], shift)
		Synth.note("sub", chord["root"] + shift)
		Synth.note("reese", chord["root"] + 12 + shift)
		Synth.chord(voicing)
		Synth.pad_chord(voicing)
		for midi in voicing:
			Synth.note("bell", midi + 12)
			Synth.note("bell", midi + 24)
	for midi in range(60 + shift, 87 + shift):
		for voice in leads:
			Synth.note(voice, midi)


static func _prepare_wobble(chords: Array, shifts: Array, steps: Array, vowels: Array) -> void:
	var roots := {}
	for chord in chords:
		roots[int(chord["root"])] = true
		roots[int(chord["root"]) - 1] = true
	for root in roots:
		for shift in shifts:
			for step in steps:
				for rate in RATES.values():
					for vowel in vowels:
						Synth.wob(root + shift, int(step) * Harmony.STEPS_PER_BEAT / int(rate), vowel)


static func layer_gains(value: float) -> PackedFloat32Array:
	var gains := PackedFloat32Array()
	var p := clampf(value, 0.0, 1.0)
	for curve in CURVES:
		gains.append(curve[0] + (1.0 - curve[0]) * smoothstep(curve[1], curve[2], p))
	return gains


static func wobble_gain(value: float) -> float:
	return WOB_CURVE[0] + (1.0 - WOB_CURVE[0]) * smoothstep(WOB_CURVE[1], WOB_CURVE[2], clampf(value, 0.0, 1.0))


func layer_gain(layer: int) -> float:
	return _gains[layer]


func layer_target(layer: int) -> float:
	return _targets[layer]


func beat_len() -> int:
	return step_len * Harmony.STEPS_PER_BEAT


func bar_len() -> int:
	return step_len * Harmony.STEPS_PER_BAR


func bpm() -> float:
	return 60.0 * Harmony.RATE / beat_len()


func building() -> bool:
	return _build_from >= 0 or _build_level >= 0.0 or not _pending_drop.is_empty()


func in_drop() -> bool:
	return not _drop.is_empty()


func set_pressure(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	var before := layer_gains(applied_pressure)
	var after := layer_gains(next)
	pressure = next
	if mode != PLAY or track != "level":
		return
	# A layer about to enter gets a one-beat riser that lands on its downbeat.
	for layer in [SNARE, LEAD, ARP]:
		if before[layer] < 0.05 and after[layer] >= 0.05:
			_riser_into(next_bar())
			break


func _riser_into(bar: int) -> void:
	if bar - beat_len() > clock and bar - _last_riser >= RISER_SPACING:
		_last_riser = bar
		_add_action(bar - beat_len(), {"type": "stinger", "id": "music_pressure", "db": 0.0, "music": true})


# --- The grid ---------------------------------------------------------------------------

# The next unprocessed step boundary: [sample, its step index from the bar origin].
func _next_step() -> Array:
	if _step_clock == clock:
		return [clock + step_len, _bar_step]
	var into := posmod(clock - grid_origin, step_len)
	if into == 0:
		return [clock, _bar_step]
	return [clock + step_len - into, _bar_step]


func _next_multiple(steps_per: int, from := -1) -> int:
	var base := _next_step()
	var at: int = base[0]
	var index: int = base[1]
	if from > at:
		var ahead := int(ceil(float(from - at) / step_len))
		at += ahead * step_len
		index += ahead
	return at + posmod(-index, steps_per) * step_len


# The next beat at or after the play head (or a later sample). A stinger asked for
# mid-beat waits for the beat; one asked for exactly on an unplayed beat starts on it.
func next_beat(from := -1) -> int:
	return _next_multiple(Harmony.STEPS_PER_BEAT, from)


func next_bar() -> int:
	return _next_multiple(Harmony.STEPS_PER_BAR)


# --- Scheduling -------------------------------------------------------------------------

# Starts a stinger on the next beat and returns its start sample. lane queues it
# behind the flow stinger already playing; repeats plays it again an eighth apart.
func schedule_stinger(id: String, db := 0.0, lane := false, repeats := 1) -> int:
	var start := next_beat()
	if lane:
		start = maxi(start, next_beat(lane_free_at))
		lane_free_at = start + SfxBank.STINGER_BEATS.get(id, 1) * beat_len() + (repeats - 1) * 2 * step_len
	for i in repeats:
		_add_action(start + i * 2 * step_len, {"type": "stinger", "id": id, "db": db - 2.0 * i, "music": false})
	return start


func schedule_stinger_at(id: String, at: int, db := 0.0) -> void:
	_add_action(at, {"type": "stinger", "id": id, "db": db, "music": false})


# The phrase restarts from bar 1 at a beat, in a mode, back on the level track at the
# band tempo: a new run, a stage (with its theme), a retry.
func schedule_restart(at: int, next_mode: int, next_theme := -1) -> void:
	_add_action(at, {"type": "restart", "mode": next_mode, "theme": next_theme})


# The stage-clear resolution: A7b9 then D major, held, starting at a beat.
func schedule_cadence(at: int, then := {}) -> void:
	_add_action(at, {"type": "cadence", "then": then})


func schedule_mode(at: int, next_mode: int) -> void:
	_add_action(at, {"type": "mode", "mode": next_mode})


# A new level theme, from the next downbeat.
func set_theme(next_theme: int) -> int:
	var at := next_bar()
	_add_action(at, {"type": "theme", "theme": clampi(next_theme, 0, 2)})
	return at


# --- Boss tracks -----------------------------------------------------------------------

# The miniboss darkens the level from the next bar, at the band tempo.
func begin_miniboss() -> int:
	if track != "level":
		return -1
	var at := next_bar()
	_add_action(at, {"type": "track", "track": "miniboss", "section": ""})
	return at


# Warden or Brindle. From the next bar, either the metric modulation (one bar of
# half-note triplets, whose pulse becomes the 129 quarter) or, held at 172, straight
# in. Returns the sample the boss music begins.
func begin_boss(kind: String) -> int:
	if track == kind:
		return -1
	var first := "build" if kind == "warden" else "1"
	var at := next_bar()
	if boss_pivot and step_len != Harmony.BOSS_STEP:
		var span := bar_len()
		var pulse := span / 3
		var root: int = _chord(_bar_step / Harmony.STEPS_PER_BAR)["root"]
		for k in 3:
			_add_action(at + k * pulse, {"type": "hit", "drums": ["kick", "open_hat", "crash"] if k == 0 else ["kick", "open_hat"], "bass": root + [0, 7, 12][k]})
		_add_action(at, {"type": "pulse", "until": at + span})
		_add_action(at + span, {"type": "track", "track": kind, "section": first, "step": Harmony.BOSS_STEP})
	else:
		_add_action(at, {"type": "track", "track": kind, "section": first})
	return at


# How broken the Warden is (0..1). The last quarter is the build: the snare roll
# tightens, the riser climbs and the high-pass opens with every hit.
func warden_charge(fraction: float) -> void:
	if track != "warden" or section != "build":
		return
	if fraction < WARDEN_BUILD_FROM:
		return
	if _build_level < 0.0:
		_start_riser()
		events_log.append(["build", clock, "warden"])
	_build_level = clampf((fraction - WARDEN_BUILD_FROM) / (1.0 - WARDEN_BUILD_FROM), 0.0, 1.0)


# A drop on the next beat: the play head goes quiet until then, then the drop.
# next_theme >= 0 restarts the level phrase in that theme (a stage landing).
func drop_now(bars: int, weight: float, then := {}, next_theme := -1) -> int:
	var at := next_beat()
	if at > clock:
		_add_action(clock, {"type": "gap"})
	_add_action(at, {"type": "drop", "bars": bars, "weight": weight, "then": then, "theme": next_theme})
	return at


# The Warden breaks: the heaviest drop in the stage, eight bars back home in D, then
# the kill cadence resolves home to the level at 172.
func unseal_drop() -> int:
	return drop_now(8, 1.0, {"type": "cadence", "then": {"track": "level", "section": "", "step": Harmony.STEP}})


# The unseal drop at a given beat (kept for callers that pick the beat).
func drop_at(at: int) -> void:
	_add_action(at, {"type": "drop", "bars": 8, "weight": 1.0, "then": {"type": "cadence", "then": {"track": "level", "section": "", "step": Harmony.STEP}}, "theme": -1})


# A boss dies: cadence home from the next beat, then the level theme at 172.
func end_boss() -> int:
	if track == "level":
		return -1
	var at := next_beat()
	schedule_cadence(at, {"track": "level", "section": "", "step": Harmony.STEP})
	return at


# Brindle's arc. Every change is a built drop on the second bar line from now: phase 2
# into Phrygian half time a half step up, phase 3 a whole step up with the tempo
# rising to 150 across the build, the chase back up to 172, and the victory the
# biggest drop of the game, resolving home in D.
func brindle_section(name: String) -> int:
	if track != "brindle":
		return -1
	var change := {"track": "brindle", "section": name, "key": BRINDLE_KEY.get(name, 0)}
	var ramp := {}
	var weight := 0.9
	var build := 1
	match name:
		"3":
			ramp = {"to": PHASE3_STEP}
		"chase":
			ramp = {"to": Harmony.STEP}
			weight = 0.95
		"victory":
			ramp = {"to": Harmony.STEP} if step_len != Harmony.STEP else {}
			weight = 1.2
			build = 2
	if not ramp.is_empty():
		ramp["beats"] = build * 4
	return planned_drop(build, 4, weight, change, ramp)


func set_brindle_phase(phase: int) -> int:
	return brindle_section(str(clampi(phase, 1, 3)) if phase <= 3 else "chase")


func victory() -> int:
	return brindle_section("victory")


# A drop on the downbeat build_bars bars after the next bar line. The build starts now;
# the last eighth before the drop is silence. Returns the drop's sample at the current
# tempo (a tempo ramp moves it; the drop itself is counted in bars).
func planned_drop(build_bars: int, drop_bars: int, weight: float, change := {}, ramp := {}) -> int:
	var first := next_bar()
	_pending_drop = {"bars": build_bars + 1, "drop_bars": drop_bars, "weight": weight, "set": change}
	_build_from = clock
	_build_len = maxi(1, first + build_bars * bar_len() - clock)
	_build_level = -1.0
	_build_tune = false
	_start_riser()
	if not ramp.is_empty():
		_ramp = ramp.duplicate()
		events_log.append(["ramp", clock, ramp["to"]])
	events_log.append(["build", clock, "planned"])
	return first + build_bars * bar_len()


# A build with no known end, such as a launch; the landing calls drop_now.
func start_build(expected_seconds: float, tune := false) -> void:
	_build_from = clock
	_build_len = maxi(1, int(expected_seconds * Harmony.RATE))
	_build_level = -1.0
	_build_tune = tune
	_start_riser()
	events_log.append(["build", clock, "open"])


func cancel_build() -> void:
	_build_from = -1
	_build_level = -1.0
	_build_tune = false
	_pending_drop = {}
	_ramp = {}
	_gap = false
	if _build_riser != null:
		_build_riser.end = mini(_build_riser.end, _build_riser.pos + RELEASE * 4)
		_build_riser = null


# Puts a track in place now, for previews and tests. "drop" is the Warden's unseal.
func force_track(next_track: String, next_theme: int, next_section := "", boss_tempo := false) -> void:
	theme = clampi(next_theme, 0, 2)
	var action := {"type": "track", "track": next_track, "section": "build" if next_section == "drop" else next_section}
	action["step"] = Harmony.BOSS_STEP if boss_tempo else Harmony.STEP
	if next_track == "brindle":
		action["key"] = BRINDLE_KEY.get(next_section, 0)
		if next_section == "3":
			action["step"] = PHASE3_STEP
	_run(action)
	if next_section == "drop":
		_run({"type": "drop", "bars": 8, "weight": 1.0, "then": {"type": "cadence", "then": {"track": "level", "section": "", "step": Harmony.STEP}}})
	mode = PLAY
	_retarget()


# Drops every stinger and phrase change not yet played and fades the ones playing:
# a retry or a new run starts clean instead of finishing the old announcements.
func cancel_pending() -> void:
	var keep: Array = []
	for action in _actions:
		if (action["type"] == "stinger" and action.get("music", false)) or action["type"] == "wob":
			keep.append(action)
	_actions = keep
	lane_free_at = 0
	_cadence_bar = -1
	_pulse_from = -1
	_pulse_until = -1
	_drop = {}
	cancel_build()
	for voice in _voices:
		if voice.layer < 0:
			voice.end = mini(voice.end, voice.pos + RELEASE)


# Pulls the band down under an important cue, then lets it back up.
func duck(amount: float, hold_seconds: float) -> void:
	_duck_target = minf(_duck_target, clampf(amount, 0.1, 1.0))
	_duck_until = maxi(_duck_until, clock + int(hold_seconds * Harmony.RATE))


# Pulls only the bass down, so a danger cue is never masked by the low end.
func duck_bass(amount: float, hold_seconds: float) -> void:
	_bass_duck_target = minf(_bass_duck_target, clampf(amount, 0.1, 1.0))
	_bass_duck_until = maxi(_bass_duck_until, clock + int(hold_seconds * Harmony.RATE))


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
	_dl.resize(frames)
	_dr.resize(frames)
	_stingers_live = false
	_mid.fill(0.0)
	_left.fill(0.0)
	_right.fill(0.0)
	_sl.fill(0.0)
	_sr.fill(0.0)
	_dl.fill(0.0)
	_dr.fill(0.0)
	var done := 0
	while done < frames:
		_run_due()
		if posmod(clock - grid_origin, step_len) == 0 and _step_clock != clock:
			_on_step()
			_run_due()
		var n := mini(frames - done, step_len - posmod(clock - grid_origin, step_len))
		n = mini(n, _to_next_action())
		if _pump_depth > 0.0:
			var in_beat := posmod(clock - grid_origin, beat_len())
			if in_beat < PUMP_ATTACK:
				n = mini(n, PUMP_ATTACK - in_beat)
		n = maxi(n, 1)
		_mix(done, n)
		clock += n
		done += n
	_finish(frames)


# --- Sequencer ------------------------------------------------------------------------

func _add_action(at: int, action: Dictionary) -> void:
	action["at"] = at
	_actions.append(action)


func _to_next_action() -> int:
	var nearest := 1 << 30
	for action in _actions:
		var wait: int = action["at"] - clock
		if wait > 0:
			nearest = mini(nearest, wait)
	return nearest


func _run_due() -> void:
	var due: Array = []
	for action in _actions:
		if action["at"] <= clock:
			due.append(action)
	for action in due:
		_actions.erase(action)
		_run(action)


func _on_step() -> void:
	_step_clock = clock
	# A tempo ramp moves one beat at a time, so every beat starts where the last ended.
	if _bar_step % Harmony.STEPS_PER_BEAT == 0 and not _ramp.is_empty():
		var left: int = _ramp["beats"]
		var next := int(round(step_len + float(int(_ramp["to"]) - step_len) / maxi(left, 1)))
		_ramp["beats"] = left - 1
		if int(_ramp["beats"]) <= 0:
			next = int(_ramp["to"])
			_ramp = {}
		_set_grid(next)
	if _bar_step % Harmony.STEPS_PER_BAR == 0:
		_on_bar()
		_step_clock = clock
	# A drop that has run its bars hands over to what follows it.
	if not _drop.is_empty() and _bar_step >= int(_drop["end_step"]):
		var then: Dictionary = _drop["then"]
		_drop = {}
		_reset_bar()
		_step_clock = clock
		_new_phrase()
		_retarget()
		events_log.append(["drop_end", clock, track])
		if not then.is_empty():
			_run(then.duplicate())
			_step_clock = clock
	var s := _bar_step % Harmony.STEPS_PER_BAR
	var bar := _bar_step / Harmony.STEPS_PER_BAR
	# The gap before a planned drop: the last eighth of the build is silence.
	if not _pending_drop.is_empty() and int(_pending_drop["bars"]) == 1 and s == Harmony.STEPS_PER_BAR - 2 and not _gap:
		_run({"type": "gap"})
	_bar_step += 1
	if _gap:
		return
	var chord := _chord(bar)
	if not _drop.is_empty():
		_trigger_drop(bar, s, chord)
		# A gate taken mid-drop (right after the unseal) builds over the drop.
		if building():
			_build_overlay(s)
		return
	if _cadence_bar >= 0:
		_trigger_dnb(bar, s, chord)
		return
	match track:
		"warden":
			_trigger_house(bar, s, chord)
		"brindle":
			_trigger_brindle(bar, s, chord)
		_:
			match theme:
				1:
					_trigger_funk(bar, s, chord)
				2:
					_trigger_halfpipe(bar, s, chord)
				_:
					_trigger_dnb(bar, s, chord)
	if track == "miniboss" and (s % 2 == 1) and applied_pressure >= 0.5:
		# The miniboss's denser top: the arpeggio fills every sixteenth.
		var tones: Array = chord["voicing"]
		_start_note("bell", tones[(s + bar) % tones.size()] + 24, 1, ARP, 0.6, -0.4 if s % 4 == 1 else 0.4)
	if building():
		_build_overlay(s)


func _run(action: Dictionary) -> void:
	match action["type"]:
		"stinger":
			var buf := SfxBank.samples_at(action["id"], step_len)
			var gain := db_to_linear(SfxBank.trim_db(action["id"]) + float(action["db"]))
			_start(buf, buf.size(), -1, gain, 0.0, not action["music"])
			stinger_starts.append([action["id"], clock])
		"restart":
			if int(action.get("theme", -1)) >= 0:
				theme = int(action["theme"])
				events_log.append(["theme", clock, theme])
			_set_grid(Harmony.STEP)
			track = "level"
			section = ""
			_set_key(0)
			_reset_bar()
			_cadence_bar = -1
			_pulse_until = -1
			_drop = {}
			mode = action["mode"]
			_new_phrase()
			_release_all()
			_retarget()
		"cadence":
			_reset_bar()
			_cadence_bar = 0
			_cadence_then = action.get("then", {})
			_drop = {}
			_set_key(0)
			_release_all()
			_retarget()
			events_log.append(["cadence", clock, track])
		"mode":
			mode = action["mode"]
			if mode != PLAY:
				_release_layers([KICK, SNARE, REESE, LEAD, ARP, WOB])
			_retarget()
		"theme":
			theme = int(action["theme"])
			events_log.append(["theme", clock, theme])
			_new_phrase()
		"track":
			if action.has("step"):
				_set_grid(int(action["step"]))
			track = action["track"]
			section = action.get("section", "")
			_set_key(int(action.get("key", 0)))
			_reset_bar()
			_cadence_bar = -1
			_pulse_until = -1
			_new_phrase()
			_release_all()
			_retarget()
			events_log.append(["track", clock, "%s:%s" % [track, section]])
		"pulse":
			_pulse_from = clock
			_pulse_until = int(action["until"])
			events_log.append(["pulse", clock, _pulse_until])
		"hit":
			for drum in action["drums"]:
				var layer := KICK if drum == "kick" else HATS
				_start(Synth.drum(drum), Synth.drum(drum).size(), -1, LEVELS[layer] * (0.8 if drum == "crash" else 1.0), 0.0, false)
			if action.has("bass"):
				# The pivot's bass rides the triplet pulse: root, fifth, octave, into 129.
				var growl := Synth.note("growl_wub", int(action["bass"]) + key)
				_start(growl, mini(growl.size(), bar_len() / 3), -1, LEVELS[REESE] * 1.1, 0.0, false)
			events_log.append(["hit", clock, action["drums"]])
		"roll":
			_start(Synth.drum("snare"), Synth.drum("snare").size(), DRY, LEVELS[SNARE] * float(action["gain"]), 0.0, false)
		"wob":
			var buf := Synth.wob(int(action["midi"]), int(action["period"]), action["vowel"])
			_start(buf, mini(buf.size(), int(action["len"])), WOB, LEVELS[WOB] * float(action["gain"]), 0.0, false)
		"gap":
			_gap = true
			if _build_riser != null:
				_build_riser.end = mini(_build_riser.end, _build_riser.pos + RELEASE)
				_build_riser = null
			_release_all()
			events_log.append(["gap", clock, ""])
		"drop":
			_gap = false
			_build_from = -1
			_build_level = -1.0
			_build_tune = false
			_pending_drop = {}
			var next_theme := int(action.get("theme", -1))
			if next_theme >= 0:
				theme = next_theme
				track = "level"
				section = ""
				_set_grid(Harmony.STEP)
				events_log.append(["theme", clock, theme])
			var change: Dictionary = action.get("set", {})
			if change.has("track"):
				track = change["track"]
				section = change.get("section", section)
			if change.has("key"):
				_set_key(int(change["key"]))
			if track == "warden":
				section = "drop"
				_set_key(0)
			_reset_bar()
			_drop = {"end_step": int(action["bars"]) * Harmony.STEPS_PER_BAR, "weight": float(action["weight"]), "then": action.get("then", {})}
			_cadence_bar = -1
			_new_phrase()
			_release_all()
			_retarget()
			events_log.append(["drop", clock, float(action["weight"])])


# A tempo change lands on the play head, which every caller keeps on a beat.
func _set_grid(step: int) -> void:
	if step == step_len:
		return
	step_len = step
	grid_origin = clock
	events_log.append(["tempo", clock, step])


func _set_key(next: int) -> void:
	if next == key:
		return
	key = next
	events_log.append(["key", clock, key])


func _reset_bar() -> void:
	bar_origin = clock
	_bar_step = 0
	_step_clock = -1


func _new_phrase() -> void:
	phrase_index += 1
	_lead = _make_track_lead()


func _on_bar() -> void:
	var bar := _bar_step / Harmony.STEPS_PER_BAR
	if _cadence_bar >= 0 and bar >= Harmony.CADENCE.size():
		# The cadence is over: the band picks the loop up again, or moves to what the
		# cadence was leading to (home from a boss, at the band tempo).
		_cadence_bar = -1
		if not _cadence_then.is_empty():
			var then := _cadence_then.duplicate()
			then["type"] = "track"
			_cadence_then = {}
			_run(then)
		else:
			_reset_bar()
			_new_phrase()
	elif track == "brindle" and section == "victory" and _drop.is_empty() and bar >= Harmony.VICTORY.size():
		_run({"type": "track", "track": "level", "section": "", "step": Harmony.STEP})
		mode = IDLE
	# A planned drop counts down its bars and lands on the downbeat.
	if not _pending_drop.is_empty():
		_pending_drop["bars"] = int(_pending_drop["bars"]) - 1
		if int(_pending_drop["bars"]) <= 0:
			var plan := _pending_drop
			_run({"type": "drop", "bars": plan["drop_bars"], "weight": plan["weight"], "set": plan["set"], "then": {}})
	var local := _bar_step / Harmony.STEPS_PER_BAR
	if track == "miniboss" and local % 2 == 1:
		_riser_into(clock + bar_len())
	if track == "warden" and section == "build" and local % 4 == 3 and not building():
		_riser_into(clock + bar_len())
	applied_pressure = pressure
	_retarget()
	if local % Harmony.PHRASE_BARS == 0:
		_groove = _rng.randi() % 3


func _floor() -> float:
	if not _drop.is_empty():
		return 1.0
	var key_name := track if track != "warden" else "warden:%s" % section
	return PRESSURE_FLOOR.get(key_name, 0.0)


func _retarget() -> void:
	var effective := maxf(applied_pressure, _floor()) if mode == PLAY else applied_pressure
	var gains := layer_gains(effective)
	for layer in gains.size():
		_targets[layer] = gains[layer] * MODE_MASK[mode][layer]
	var warm: float = OVERCHARGE_GAIN[clampi(overcharge, 0, OVERCHARGE_GAIN.size() - 1)]
	if track == "warden" and section == "drop":
		warm = maxf(warm, 0.8)
	_targets[WARM] = warm * MODE_MASK[mode][WARM]
	_targets[WOB] = wobble_gain(effective) * MODE_MASK[mode][WOB]
	_pump_depth = 0.0
	if mode == PLAY and _cadence_bar < 0 and _drop.is_empty():
		if track == "warden":
			_pump_depth = 0.65
		elif track == "brindle":
			_pump_depth = 0.4


# Bonus cores this stage. The warm pad swells in on the next bar and stays until the
# stage ends, so an overcharged beacon sounds richer the whole way to the gates.
func set_overcharge(count: int) -> void:
	overcharge = maxi(count, 0)
	_retarget()


func _progression() -> Array:
	match track:
		"miniboss":
			return Harmony.minor_progression(theme)
		"brindle":
			match section:
				"victory":
					return Harmony.VICTORY
				"2":
					return Harmony.BRINDLE_PHRYGIAN
			return Harmony.BRINDLE
	return Harmony.level_progression(theme)


func _chord(bar: int) -> Dictionary:
	if _cadence_bar >= 0:
		return Harmony.CADENCE[mini(bar, Harmony.CADENCE.size() - 1)]
	var progression := _progression()
	if track == "brindle" and section == "victory" and _drop.is_empty():
		return progression[mini(bar, progression.size() - 1)]
	return progression[bar % progression.size()]


func _next_chord(bar: int) -> Dictionary:
	var progression := _progression()
	return progression[(bar + 1) % progression.size()]


func _voicing(chord: Dictionary) -> Array:
	return _shift(chord["voicing"], key)


func _make_track_lead() -> Array:
	match track:
		"brindle":
			_lead_voice = "brass"
			if section == "victory":
				return VICTORY_LEAD
			if section == "chase":
				return make_lead(phrase_index, MOTIF, Harmony.BRINDLE, 73)
			var quote := {"1": 2, "2": 1, "3": 0}.get(section, 0) as int
			return make_lead(phrase_index, [MOTIF, MOTIF_SLUICE, MOTIF_WEIR][quote], _progression(), 73)
		_:
			_lead_voice = LEAD_VOICE[theme]
			var progression := _progression()
			match theme:
				1:
					return make_lead(phrase_index, MOTIF_SLUICE, progression, 73)
				2:
					return make_lead(phrase_index, MOTIF_WEIR, progression, -1, [1])
			return make_lead(phrase_index, MOTIF, progression, 73)


# --- Arrangements -------------------------------------------------------------------

# Spillway: drum and bass. Also plays every cadence.
func _trigger_dnb(bar: int, s: int, chord: Dictionary) -> void:
	var cadence := _cadence_bar >= 0
	var phrase_bar := bar % Harmony.PHRASE_BARS
	var busy := applied_pressure >= 0.3 and mode == PLAY
	# Keys: a held chord when calm, syncopated stabs once the pressure is up.
	var stabs: Dictionary = {0: 16} if not busy or (cadence and bar == 1) else ([{0: 3, 6: 2, 10: 4}, {0: 2, 3: 2, 8: 3, 14: 2}, {0: 3, 6: 2, 10: 4}][_groove])
	if stabs.has(s):
		_release_layers([KEYS])
		var buf := Synth.chord(_voicing(chord))
		_start(buf, mini(buf.size(), int(stabs[s]) * step_len + RELEASE), KEYS, LEVELS[KEYS], 0.0, false)
	_sub_and_pad(s, chord)
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
	# The bass never leaves: a restrained root-and-fifth roll when calm; busy, the
	# reese line with its octave pop and a chromatic approach into the next chord.
	var root: int = chord["root"]
	if cadence:
		if s == 0:
			_bass("reese", root + 12, 12, 0.9)
		return
	var next_root: int = _next_chord(bar)["root"]
	var line := {0: [0, 3], 3: [12, 1], 6: [0, 2], 10: [7, 3], 14: [next_root - root - 1, 2]} if busy else DNB_CALM
	if line.has(s):
		_bass("reese", root + 12 + int(line[s][0]), int(line[s][1]), 1.0)
	_wobble(bar, s, chord, THEME_RATES[0], THEME_VOWEL[0])
	_play_lead(phrase_bar, s)
	_arp(bar, s, chord, "bell")


# Sluice: funk. The clav riff calls, the brass answers, the groove is a machine.
func _trigger_funk(bar: int, s: int, chord: Dictionary) -> void:
	var phrase_bar := bar % Harmony.PHRASE_BARS
	var busy := applied_pressure >= 0.3 and mode == PLAY
	var voicing := _voicing(chord)
	var riff := CLAV_BUSY if busy else CLAV_CALM
	if riff.has(s):
		var midi: int = voicing[int(riff[s]) % voicing.size()] + (12 if s % 4 == 2 else 0)
		var clav := Synth.note("clav", midi)
		_start(clav, mini(clav.size(), step_len + RELEASE), KEYS, LEVELS[KEYS] * 1.1, -0.3 if s % 2 == 0 else 0.3, false)
	if applied_pressure >= 0.35 and (s == 6 or s == 14):
		var stab := Synth.stab_chord(voicing, true)
		_start(stab, mini(stab.size(), 2 * step_len + RELEASE), KEYS, LEVELS[KEYS] * 0.9, 0.15, false)
	_sub_and_pad(s, chord)
	if busy or s % 2 == 0:
		_hit("hat", HATS, 0.85 if s % 4 == 1 or s % 4 == 3 else 0.45, 0.3)
	if (s == 7 or s == 15) and applied_pressure >= 0.5:
		_hit("open_hat", HATS, 0.55, 0.3)
	if s in ([0, 3, 10] if busy else [0, 10]):
		_hit("kick", KICK, 1.0, 0.0)
	if s == 4 or s == 12:
		_hit("snare", SNARE, 1.0, 0.0)
	elif busy and s in [6, 9, 14]:
		_hit("snare", SNARE, 0.25, 0.0)
	if phrase_bar == 7 and s >= 12:
		_hit("snare", SNARE, 0.5 + 0.12 * (s - 12), 0.0)
	# The slap bass: octave pops when busy, a sparse root-octave figure when calm.
	var root: int = chord["root"]
	var line := FUNK_BASS if busy else FUNK_CALM
	if line.has(s):
		_bass("fbass", root + int(line[s][0]), int(line[s][1]), 1.2)
	elif busy and s == 14:
		_bass("fbass", int(_next_chord(bar)["root"]) - 1, 2, 1.2)
	_wobble(bar, s, chord, THEME_RATES[1], THEME_VOWEL[1])
	_play_lead(phrase_bar, s)
	_arp(bar, s, chord, "clav")


# Weir: the halfpipe. Organ, a half-time roll, a bass that climbs and falls with the
# chords, and the talkbox.
func _trigger_halfpipe(bar: int, s: int, chord: Dictionary) -> void:
	var phrase_bar := bar % Harmony.PHRASE_BARS
	var busy := applied_pressure >= 0.3 and mode == PLAY
	var chops: Dictionary = {0: 16} if not busy else {0: 3, 6: 2, 10: 2, 14: 2}
	if chops.has(s):
		_release_layers([KEYS])
		var organ := Synth.organ_chord(_voicing(chord))
		_start(organ, mini(organ.size(), int(chops[s]) * step_len + RELEASE), KEYS, LEVELS[KEYS] * 0.8, 0.0, false)
	_sub_and_pad(s, chord)
	if s % 2 == 0:
		_hit("hat", HATS, 0.75 if s % 4 == 2 else 0.4, 0.25)
	if busy and s in [0, 4, 7, 8, 12, 15]:
		_hit("ride", SNARE, 0.5 if s % 4 == 0 else 0.3, -0.3)
	if s in ([0, 7, 10] if busy else [0, 10]):
		_hit("kick", KICK, 1.0, 0.0)
	if s == 8:
		_hit("snare", SNARE, 1.0, 0.0)
	elif busy and s in [3, 14]:
		_hit("snare", SNARE, 0.25, 0.0)
	if applied_pressure >= 0.6 and s == 12:
		_hit("snare", SNARE, 0.6, 0.0)
	if phrase_bar == 7 and s >= 12:
		_hit("snare", SNARE, 0.5 + 0.12 * (s - 12), 0.0)
	# The ladder: busy, the bass climbs root-fifth-seventh-octave for four bars and
	# rolls back down for four; calm, a slow swing between root and octave.
	var root: int = chord["root"]
	if busy:
		if s % 4 == 0:
			var ladder := [0, 7, 10, 12] if phrase_bar < 4 else [12, 10, 7, 0]
			_bass("reese", root + 12 + ladder[s / 4], 3, 1.0)
		elif s % 4 == 3:
			_bass("reese", root + 12 + (7 if phrase_bar < 4 else 0), 1, 0.6)
	elif WEIR_CALM.has(s):
		_bass("reese", root + 12 + int(WEIR_CALM[s][0]), int(WEIR_CALM[s][1]), 1.0)
	_wobble(bar, s, chord, THEME_RATES[2], THEME_VOWEL[2])
	_play_lead(phrase_bar, s)
	_arp(bar, s, chord, "bell")


# The Warden: the level rebuilt as club music. Four on the floor, funk bass, filtered
# stabs, a pump under every kick; the build waits for the drop.
func _trigger_house(bar: int, s: int, chord: Dictionary) -> void:
	var phrase_bar := bar % Harmony.PHRASE_BARS
	if s % 4 == 0:
		_hit("kick", KICK, 1.0, 0.0)
	if s == 4 or s == 12:
		_hit("clap", SNARE, 1.0, 0.1)
	if phrase_bar % 4 == 3 and s >= 8:
		_hit("snare", SNARE, 0.3 + 0.08 * (s - 8), 0.0)
	if s % 4 == 2:
		_hit("open_hat", HATS, 0.8, 0.25)
	elif s % 2 == 1:
		_hit("hat", HATS, 0.35, -0.25)
	var root: int = chord["root"]
	if HOUSE_BASS.has(s):
		_bass("fbass", root + int(HOUSE_BASS[s][0]), int(HOUSE_BASS[s][1]), 1.3)
	if s == 0:
		_start_note("sub", root, 16, SUB, 0.8, 0.0)
	if s in [2, 6, 10, 13]:
		var stab := Synth.stab_chord(_voicing(chord), false)
		_start(stab, mini(stab.size(), step_len + RELEASE), KEYS, LEVELS[KEYS] * 1.1, 0.2 if s % 4 == 2 else -0.2, false)
	if s == 0 and (_targets[WARM] > 0.0 or _gains[WARM] > 0.0):
		var pad := Synth.pad_chord(_voicing(chord))
		_start(pad, mini(pad.size(), 16 * step_len + RELEASE), WARM, LEVELS[WARM], 0.0, false)


# The brostep drop: half-time drums, the wobble changing rate every bar, talking
# growls on the offbeats, the sub and a reese under it all, bright jazzy stabs.
func _trigger_drop(bar: int, s: int, chord: Dictionary) -> void:
	var weight: float = _drop["weight"]
	var root: int = chord["root"]
	if s == 0:
		_hit("kick", KICK, 1.0, 0.0)
		if bar == 0 or bar % 4 == 0 or weight >= 1.1:
			_hit("crash", HATS, 1.0, -0.2)
		if bar == 0:
			_hit("boom", KICK, 1.0, 0.0)
		_start_note("sub", root, 16, SUB, 1.1, 0.0)
		_bass("reese", root + 12, 16, 0.55)
		var stab := Synth.stab_chord(_voicing(chord), true)
		_start(stab, stab.size(), KEYS, LEVELS[KEYS] * 1.1, 0.0, false)
	if s == 10 and (weight >= 1.0 or bar % 2 == 1):
		_hit("kick", KICK, 0.9, 0.0)
	if s == 3 and bar % 2 == 1:
		_hit("kick", KICK, 0.7, 0.0)
	if s == 8:
		_hit("snare", SNARE, 1.0, 0.0)
		_hit("clap", SNARE, 0.9, 0.1)
	if s % 2 == 0:
		_hit("hat", HATS, 0.55 if s % 4 == 2 else 0.35, 0.25)
	if s == 14:
		_hit("open_hat", HATS, 0.6, 0.25)
	if s == 10 and weight >= 1.0:
		var stab := Synth.stab_chord(_voicing(chord), true)
		_start(stab, mini(stab.size(), 2 * step_len + RELEASE), KEYS, LEVELS[KEYS] * 0.9, 0.2, false)
	_wobble(bar, s, chord, DROP_RATES, "wub" if bar % 2 == 0 else "yoi", 0, 1.15)
	if s == 6:
		_start_note("growl", root, 2, WOB, 0.9, -0.15)
	if s == 14:
		_start_note("growl_wub", root + (12 if bar % 2 == 1 else 0), 2, WOB, 0.9, 0.15)
	if s == 11 and weight >= 1.0:
		_start_note("growl", root + 7, 1, WOB, 0.7, 0.0)
	if weight >= 1.0 and track == "warden":
		_play_lead(bar % Harmony.PHRASE_BARS, s)
	if weight >= 1.1:
		_arp(bar, s, chord, "bell")


# Brindle: anvil and industrial drums under a brass fanfare that quotes the level the
# phase was taught in. Phase 2 is half time; phase 3 adds everything; the chase is
# drum and bass again; the victory resolves home.
func _trigger_brindle(bar: int, s: int, chord: Dictionary) -> void:
	if section == "victory":
		_trigger_victory(bar, s, chord)
		return
	if section == "chase":
		_trigger_dnb(bar, s, chord)
		if s == 6 or s == 14:
			_hit("anvil", SNARE, 0.6, 0.3)
		return
	var phase := int(section) if section.is_valid_int() else 3
	var phrase_bar := bar % Harmony.PHRASE_BARS
	var half := phase == 2
	if s == 0:
		_hit("boom", KICK, 1.0, 0.0)
	var kicks := [0, 10] if half else ([0, 3, 6, 8, 10, 14] if phase >= 3 else [0, 3, 8, 10])
	if s in kicks:
		_hit("kick", KICK, 0.9, 0.0)
	if (s == 8) if half else (s == 4 or s == 12):
		_hit("clap", SNARE, 1.0, 0.1)
		if half:
			_hit("snare", SNARE, 1.0, 0.0)
	if s in ([6, 11, 14] if phase >= 2 else [6, 14]):
		_hit("anvil", SNARE, 0.8, -0.35 if s < 10 else 0.35)
	_hit("hat", HATS, 0.7 if s % 4 == 2 else 0.35, 0.2)
	var root: int = chord["root"]
	if BRINDLE_BASS.has(s):
		_bass("reese", root + 12 + int(BRINDLE_BASS[s][0]), int(BRINDLE_BASS[s][1]), 1.1)
	if s == 0:
		_start_note("sub", root, 16, SUB, 0.9, 0.0)
	if s == 0 or s == 10:
		_release_layers([KEYS])
		var stab := Synth.stab_chord(_voicing(chord), true)
		_start(stab, stab.size(), KEYS, LEVELS[KEYS] * 1.2, 0.0, false)
	if s == 0 and phase >= 2:
		var organ := Synth.organ_chord(_voicing(chord))
		_start(organ, mini(organ.size(), 16 * step_len + RELEASE), WARM, LEVELS[WARM] * 0.8, 0.0, false)
	# Each phase adds a layer: the wobble answers in phase 1 and fills the bar after.
	_wobble(bar, s, chord, HALF_RATES if half else DROP_RATES, "yoi" if half else "wub", 8 if phase == 1 else 0)
	_play_lead(phrase_bar, s)
	if phase >= 3:
		_arp(bar, s, chord, "bell")


func _trigger_victory(bar: int, s: int, chord: Dictionary) -> void:
	var last := bar >= Harmony.VICTORY.size() - 1
	if last:
		if s == 0:
			_hit("crash", HATS, 1.0, 0.0)
			_hit("kick", KICK, 1.0, 0.0)
			_start_note("sub", chord["root"], 16, SUB, 1.0, 0.0)
			_bass("reese", int(chord["root"]) + 12, 16, 0.7)
			var held := Synth.chord(_voicing(chord))
			_start(held, held.size(), KEYS, LEVELS[KEYS] * 1.2, 0.0, false)
			var pad := Synth.pad_chord(_voicing(chord))
			_start(pad, pad.size(), WARM, LEVELS[WARM], 0.0, false)
	else:
		if s % 4 == 0:
			_hit("kick", KICK, 1.0, 0.0)
		if s == 4 or s == 12:
			_hit("clap", SNARE, 1.0, 0.0)
		if bar == Harmony.VICTORY.size() - 2 and s >= 8:
			_hit("snare", SNARE, 0.4 + 0.08 * (s - 8), 0.0)
		if s == 0:
			_start_note("sub", chord["root"], 16, SUB, 0.9, 0.0)
			var stab := Synth.stab_chord(_voicing(chord), true)
			_start(stab, stab.size(), KEYS, LEVELS[KEYS] * 1.2, 0.0, false)
		if s in [0, 3, 6, 10]:
			_bass("fbass", int(chord["root"]) + (12 if s == 6 else 0), 2, 1.1)
		_hit("hat", HATS, 0.6 if s % 4 == 2 else 0.3, 0.2)
	_play_lead(bar, s)


# --- Pieces every arrangement shares ------------------------------------------------------

func _sub_and_pad(s: int, chord: Dictionary) -> void:
	if s != 0:
		return
	_start_note("sub", chord["root"], 16, SUB, 1.0, 0.0)
	if _targets[WARM] > 0.0 or _gains[WARM] > 0.0:
		var pad := Synth.pad_chord(_voicing(chord))
		_start(pad, mini(pad.size(), 16 * step_len + RELEASE), WARM, LEVELS[WARM], 0.0, false)


# A bass-figure note: it cuts the previous one, so the riff stays tight.
func _bass(instrument: String, midi: int, steps: int, gain: float) -> void:
	_release_layers([REESE])
	_start_note(instrument, midi, steps, REESE, gain, 0.0)


# The wobble: on each beat it schedules that beat's LFO cycles, all locked to the
# grid (a triplet rate puts three cycles on the beat, and every beat starts one).
# from_step keeps the first half of the bar for the riff: call and response.
func _wobble(bar: int, s: int, chord: Dictionary, rates: Array, vowel: String, from_step := -1, gain := 1.0) -> void:
	if s % Harmony.STEPS_PER_BEAT != 0:
		return
	if _targets[WOB] <= 0.001 and _gains[WOB] <= 0.001:
		return
	var start := from_step
	if start < 0:
		start = 8 if applied_pressure < 0.8 and _drop.is_empty() else 0
	if s < start:
		return
	var rate: String = rates[bar % rates.size()]
	var count: int = RATES[rate]
	var beat := beat_len()
	var root: int = chord["root"]
	# The last beat of an odd bar walks into the next root from a half step below.
	if s == 12 and bar % 2 == 1 and _drop.is_empty():
		root = int(_next_chord(bar)["root"]) - 1
	var midi := root + key
	for k in count:
		var at := clock + int(round(float(k) * beat / count))
		var next := clock + int(round(float(k + 1) * beat / count))
		_add_action(at, {"type": "wob", "midi": midi, "period": beat / count, "vowel": vowel, "gain": gain, "len": next - at})
		wob_log.append([at, rate, beat / count, midi, grid_origin, step_len, bar_origin, bar])
	if wob_log.size() > 512:
		wob_log = wob_log.slice(wob_log.size() - 512)


func _play_lead(phrase_bar: int, s: int) -> void:
	var at := phrase_bar * Harmony.STEPS_PER_BAR + s
	for event in _lead:
		if event[0] == at:
			_release_layers([LEAD])
			_start_note(_lead_voice, event[1], event[2], LEAD, 1.0, 0.1)
			if track == "miniboss":
				_start_note(_lead_voice, event[1] + 12, event[2], LEAD, 0.4, -0.1)


func _arp(bar: int, s: int, chord: Dictionary, instrument: String) -> void:
	if s % 2 == 0 or applied_pressure >= 0.9:
		var tones: Array = chord["voicing"]
		var pattern := [0, 1, 2, 3, 2, 1]
		var midi: int = tones[pattern[(s / 2 + bar % Harmony.PHRASE_BARS) % pattern.size()] % tones.size()] + 12
		_start_note(instrument, midi, 2, ARP, 0.8, 0.45 if s % 4 == 0 else -0.45)


# The build over whatever is playing: a snare roll that accelerates from quarters to
# sixteenths to thirty-seconds, the riser, and for a launch the rice-cooker climb up
# the A7 while you fly. The high-pass sweep is in the mix.
func _build_overlay(s: int) -> void:
	var level := build_level()
	# A long build (the Warden's last quarter) climbs riser after riser.
	if s == 0 and _build_riser == null:
		_start_riser()
	var every := 4 if level < 0.34 else (2 if level < 0.67 else 1)
	if s % every == 0:
		_run({"type": "roll", "gain": 0.5 + 0.9 * level})
		if level >= 0.85:
			_add_action(clock + step_len / 2, {"type": "roll", "gain": 0.6 + 0.8 * level})
	if _build_tune and s % 2 == 0 and _build_from >= 0:
		var count := (clock - _build_from) / (step_len * 2)
		var midi: int = Harmony.LAUNCH_TUNE[count % Harmony.LAUNCH_TUNE.size()] + (12 if count >= Harmony.LAUNCH_TUNE.size() else 0)
		var buf := Synth.note("mallet", midi + key)
		_start(buf, mini(buf.size(), 2 * step_len + RELEASE), DRY, 0.32, 0.2, false)


func build_level() -> float:
	if _build_level >= 0.0:
		return _build_level
	if _build_from < 0:
		return 0.0
	return clampf(float(clock - _build_from) / _build_len, 0.0, 1.0)


func _start_riser() -> void:
	if _build_riser != null:
		return
	var buf := SfxBank.samples_at("build_riser", step_len)
	_start(buf, buf.size(), DRY, db_to_linear(SfxBank.trim_db("build_riser")), 0.0, false)
	_build_riser = _voices[_voices.size() - 1]


# Pitched notes follow the key.
func _start_note(instrument: String, midi: int, steps: int, layer: int, gain: float, pan: float) -> void:
	var buf := Synth.note(instrument, midi + key)
	_start(buf, mini(buf.size(), steps * step_len + RELEASE), layer, gain * LEVELS[layer], pan, false)


# Drums. Inside the transition bar the half-note triplet pulse replaces kick and snare.
func _hit(instrument: String, layer: int, gain: float, pan: float) -> void:
	if (layer == KICK or layer == SNARE) and clock >= _pulse_from and clock < _pulse_until:
		return
	var buf := Synth.drum(instrument)
	_start(buf, buf.size(), layer, gain * LEVELS[layer], pan, false)


func _start(buf: PackedFloat32Array, length: int, layer: int, gain: float, pan: float, to_stinger: bool) -> void:
	var voice := Voice.new()
	voice.buf = buf
	voice.end = length
	voice.layer = layer
	voice.to_stinger = to_stinger
	if layer >= 0:
		layer_starts[layer] += 1
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

# The sidechain envelope at a sample: down fast under the kick, back by three-quarters
# of the beat.
func _pump_at(sample: int) -> float:
	if _pump_depth <= 0.0:
		return 1.0
	var beat := beat_len()
	var pos := posmod(sample - grid_origin, beat)
	var low := 1.0 - _pump_depth
	if pos < PUMP_ATTACK:
		return lerpf(1.0, low, float(pos) / PUMP_ATTACK)
	var x := clampf(float(pos - PUMP_ATTACK) / (beat * 0.75 - PUMP_ATTACK), 0.0, 1.0)
	return low + (1.0 - low) * (1.0 - (1.0 - x) * (1.0 - x))


func _mix(offset: int, n: int) -> void:
	var start_gains := _gains.duplicate()
	var step := float(n) / Harmony.BEAT
	for layer in _gains.size():
		_gains[layer] = move_toward(_gains[layer], _targets[layer], step)
	var inv_n := 1.0 / n
	var pump0 := _pump_at(clock)
	var pump1 := _pump_at(clock + n)
	# The bass ducks under danger cues: down in 300 samples, back over a beat.
	if clock >= _bass_duck_until:
		_bass_duck_target = 1.0
	var bd0 := _bass_duck
	_bass_duck = move_toward(_bass_duck, _bass_duck_target, float(n) / (DUCK_RELEASE if _bass_duck_target > _bass_duck else 300.0))
	var bass_ducked := bd0 < 1.0 or _bass_duck < 1.0
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
			if (pump0 < 1.0 or pump1 < 1.0) and voice.layer in PUMPED:
				g0 *= pump0
				g1 *= pump1
			if bass_ducked and voice.layer in BASS_LAYERS:
				g0 *= bd0
				g1 *= _bass_duck
			if not solo.is_empty() and not voice.layer in solo:
				g0 = 0.0
				g1 = 0.0
		elif not solo.is_empty():
			g0 = 0.0
			g1 = 0.0
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
		if voice.mono and not voice.to_stinger and voice.layer != DRY:
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
			var left := _sl if voice.to_stinger else (_dl if voice.layer == DRY else _left)
			var right := _sr if voice.to_stinger else (_dr if voice.layer == DRY else _right)
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
		if voice == _build_riser:
			_build_riser = null
	# The duck envelope, the silence gate and the build's high-pass, per sub-block.
	if clock >= _duck_until:
		_duck_target = 1.0
	var duck_from := _duck
	var rate: float = float(n) / (DUCK_RELEASE if _duck_target > _duck else 400.0)
	_duck = move_toward(_duck, _duck_target, rate)
	var gate_from := _gate
	_gate = move_toward(_gate, 0.0 if _gap else 1.0, float(n) / 96.0)
	var level := master * pause_gain
	var sweep := build_level() if (_build_from >= 0 or _build_level >= 0.0) else 0.0
	if sweep > 0.001:
		# Two one-pole high-passes per side: 20 Hz rising to SWEEP_TOP_HZ.
		var cutoff := 20.0 + (SWEEP_TOP_HZ - 20.0) * sweep * sweep
		var a := 1.0 / (1.0 + TAU * cutoff / Harmony.RATE)
		var h := _hp
		for i in n:
			var d := (duck_from + (_duck - duck_from) * i * inv_n) * level * (gate_from + (_gate - gate_from) * i * inv_n)
			var m := _mid[offset + i]
			var l := _left[offset + i] + m
			var r := _right[offset + i] + m
			h[1] = a * (h[1] + l - h[0])
			h[0] = l
			h[3] = a * (h[3] + h[1] - h[2])
			h[2] = h[1]
			h[5] = a * (h[5] + r - h[4])
			h[4] = r
			h[7] = a * (h[7] + h[5] - h[6])
			h[6] = h[5]
			_left[offset + i] = (h[3] + _dl[offset + i]) * d
			_right[offset + i] = (h[7] + _dr[offset + i]) * d
	else:
		for i in n:
			var d := (duck_from + (_duck - duck_from) * i * inv_n) * level * (gate_from + (_gate - gate_from) * i * inv_n)
			var m := _mid[offset + i]
			_left[offset + i] = (_left[offset + i] + m + _dl[offset + i]) * d
			_right[offset + i] = (_right[offset + i] + m + _dr[offset + i]) * d


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
# One eight-bar phrase from a motif: a two-bar call, an answer, the call sequenced up
# two scale steps, and an answer that ends on the leading tone (or the nearest chord
# tone). The answers and ornaments change every loop from a seeded stream, so it
# never repeats exactly and a run replays the same way.

static func make_lead(index: int, motif := MOTIF, progression := Harmony.PROGRESSION, ending := 73, answers := [0, 1, 2]) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260926 + index * 7919
	var shift: int = [0, 1, 2, -1][rng.randi() % 4]
	var pick := rng.randi() % answers.size()
	var notes := []
	notes.append_array(_place(_transpose(motif, shift), 0))
	notes.append_array(_place(_answer(motif, answers[pick], shift), 32))
	notes.append_array(_place(_transpose(motif, shift + 2), 64))
	notes.append_array(_place(_answer(motif, answers[(pick + 1) % answers.size()], shift), 96))
	var span := progression.size() * 16
	var fitted := []
	for event in notes:
		var step: int = event[0]
		if step >= mini(128, span * 2):
			continue
		var chord: Dictionary = progression[(step / 16) % progression.size()]
		var midi: int = event[1]
		midi = Harmony.nearest_tone(midi, chord["tones"]) if step % 4 == 0 else Harmony.snap(midi, chord["scale"])
		while midi < 62:
			midi += 12
		while midi > 84:
			midi -= 12
		fitted.append([step, midi, mini(event[2], 128 - step)])
	if not fitted.is_empty():
		var last: Array = fitted[fitted.size() - 1]
		if ending >= 0:
			last[1] = ending
		else:
			var chord: Dictionary = progression[(int(last[0]) / 16) % progression.size()]
			last[1] = Harmony.nearest_tone(last[1], chord["tones"])
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
			# Retrograde: the call's pitches backwards over its own rhythm (for the
			# halfpipe, the climb played back down).
			for i in source.size():
				answer.append([source[i][0], source[source.size() - 1 - i][1], source[i][2]])
		_:
			# Displaced echo: an eighth late and two steps lower.
			for event in source:
				if event[0] + 2 < 32:
					answer.append([event[0] + 2, Harmony.scale_shift(event[1], -2, Harmony.DORIAN), event[2]])
	return answer
