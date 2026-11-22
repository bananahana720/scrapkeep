extends RefCounted

signal parameter_commit(at: int, values: Dictionary, released: bool, lift: bool, reason: String)

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")

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
# own character with a clean sub under it. Above it the texture is additive, in the
# spirit of a slow-building layered song: each pressure step brings a melodic layer
# (a warm pad, an arpeggiator shimmer, a wordless choir, the lead, a chopped echo of
# the lead, a counter-line that plays the lead's call two bars late), and every four
# bars the lines are re-voiced, so the texture evolves without new drops. Builds come
# from layers stacking and a low-pass opening; drops land on the downbeat after a
# beat of silence, and their payoff is the full texture plus the bass. A restrained
# grid-locked wobble is kept only inside the Warden and Brindle drops.

enum { KEYS, SUB, HATS, KICK, SNARE, REESE, LEAD, ARP, WARM, WOB, PAD, CHOIR, ECHO, COUNTER, FLEET, LANDMARK_HUM }
# Tone-pending placeholders reuse Brindle's score with a different lead timbre.
const BOSS_TRACKS := ["brindle", "waking", "mind"]
const BOSS_LEAD_VOICES := {"brindle": "brass", "waking": "mallet", "mind": "talk"}

const LAYER_NAMES := ["keys", "sub", "hats", "kick", "snare", "bass", "lead", "arp", "warm", "wobble", "pad", "choir", "echo", "counter", "fleet", "landmark_hum"]
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
	[0.0, 0.3, 0.5],
	[0.0, 0.0, 1.0],
	[0.0, 0.0, 1.0],
	[0.0, 0.1, 0.3],
	[0.0, 0.45, 0.65],
	[0.0, 0.7, 0.9],
	[0.0, 0.8, 1.0],
	[1.0, 0.0, 1.0],
	[0.0, 0.0, 1.0],
]
# The warm and wobble rows are placeholders: _retarget sets them from the overcharge
# and the drop; the fleet row is gated by the difficulty ticks instead (set_fleet_ticks).
# The melodic layers, in the order they enter: pad, arp, choir, lead, echo, counter.
const MELODIC := [PAD, ARP, CHOIR, LEAD, ECHO, COUNTER]
const LEVELS := [0.34, 0.54, 0.22, 0.68, 0.44, 0.46, 0.32, 0.13, 0.3, 0.32, 0.22, 0.2, 0.12, 0.18, 0.3, 1.0]
# The restrained wobble: only in the Warden's and Brindle's drops, at half level.
const WOB_DROP_GAIN := 0.5
# The warm layer is not pressure: it is the overcharge, one step per bonus core.
const OVERCHARGE_GAIN := [0.0, 0.7, 1.0]

enum { IDLE, PLAY, DEAD }
const MODE_NAMES := ["idle", "play", "dead"]
# What each mode lets through, per layer. Menus keep keys, sub, a light hat and the
# restrained bass riff; death keeps the keys alone, so the band waits with you.
const MODE_MASK := [
	[1.0, 0.7, 0.4, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.6, 0.0, 0.0, 0.0, 0.0, 0.0],
	[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	[0.6, 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0],
]
const BASS_LAYERS := [SUB, REESE, WOB]
# The build's own voices (riser, snare roll, launch tune) skip the tone filter.
const DRY := -2
# The tone filter: a low-pass over the band (never the bass, which sits far below it)
# that is darker when calm and opens with intensity; a build closes it to BUILD_LOW_HZ
# and opens it back up into the drop.
const TONE_CALM_HZ := 2800.0
const TONE_OPEN_HZ := 16000.0
const BUILD_LOW_HZ := 700.0

const RELEASE := 600
const DUCK_RELEASE := Harmony.BEAT
const RISER_SPACING := Harmony.BAR * 4
# Boss tracks move to 129 by metric modulation unless Andrew picks "held at 172".
const BOSS_PIVOT_DEFAULT := true
# AUDIO-V3 section 11: defaults for the lab; AU3 owns the bowl/clock listeners.
const WARDEN_PIVOT_ONCE_PER_STAGE := true
const WARDEN_OPEN_HELD_BREATH := true
const WARDEN_ESCALATE_FROM_SEGMENTS := true
const RULE_DOUBLE_CLAP := 1 << 0
const RULE_DEEP_PUMP := 1 << 1
const RULE_FLEET_ANSWER := 1 << 2
# presentation_v3_test: 30 voices across four dense states and all three themes,
# including evolution pins, rules and the reactor pedal; ceil(30 * 1.25) = 38.
const BAND_VOICE_CAP := 38
const OPEN_GAINS := [1.0, 1.0, 0.5, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
# Brindle's phase 3 runs at 150.
const PHASE3_STEP := 4410
# The sidechain pump: the pumped layers dip under each kick, hold a short pocket for
# the kick transient, and breathe back smoothly like a 2010s French-house / club limiter.
const PUMP_ATTACK := 220
const PUMP_HOLD_FRAC := 0.07
const PUMPED := [KEYS, SUB, REESE, LEAD, ARP, WARM, WOB, PAD, CHOIR, ECHO, COUNTER]
# Brindle's phases add layers: phase 1 at 0.8 (pad, arp, choir, lead, half the echo),
# phase 2 brings the echo and half the counter, phase 3 everything.
const PRESSURE_FLOOR := {"level": 0.0, "miniboss": 0.8, "warden:build": 0.55, "warden:open": 0.55, "warden:lift": 0.7, "warden:break": 0.85, "warden:drop": 1.0,
	"brindle:1": 0.8, "brindle:2": 0.9, "brindle:3": 1.0, "brindle:chase": 1.0, "brindle:victory": 1.0}
const LEAD_VOICE := ["lead", "brass", "talk"]
# The menu tracks play over the IDLE bed in IDLE mode: the title's main theme once a
# phrase, the won summary's victory line once, the lost summary on the DEAD mask's bed.
const MENU_TRACKS := ["title", "summary"]
const TITLE_LEAD_GAIN := 0.45
const SUMMARY_LEAD_GAIN := 0.5
const MENU_PHRASE_BARS := 8
# The Warden's escalation: half broken lifts the key a half step, three quarters
# starts the sinister break, whose build tightens with every hit until the unseal.
const WARDEN_LIFT_AT := 0.5
const WARDEN_BUILD_FROM := 0.75
# One heft class brightens the band this much intensity.
const HEFT_STEP := 0.12
# Brindle's key per section, in semitones above D: each phase lifts it.
const BRINDLE_KEY := {"1": 0, "2": 1, "3": 2, "chase": 2, "victory": 0}
const BOSS_SECTIONS := {
	"brindle": {
		"1": {"key": 0, "step": Harmony.BOSS_STEP},
		"2": {"key": 1, "step": Harmony.BOSS_STEP},
		"3": {"key": 2, "step": PHASE3_STEP},
		"chase": {"key": 2, "step": Harmony.STEP},
		"victory": {"key": 0, "step": Harmony.STEP},
	},
	"waking": {
		"1": {"key": 0, "step": Harmony.BOSS_STEP},
		"2": {"key": 0, "step": PHASE3_STEP},
		"3": {"key": 1, "step": Harmony.STEP},
		"victory": {"key": 0, "step": PHASE3_STEP},
	},
	"mind": {
		"1": {"key": 2, "step": PHASE3_STEP},
		"2": {"key": 1, "step": Harmony.BOSS_STEP},
		"3": {"key": 0, "step": PHASE3_STEP},
		"victory": {"key": 2, "step": Harmony.STEP},
	},
}

# Wobble rates in LFO cycles per beat. Each bar takes the next rate in its list.
const RATES := {"1/4": 1, "1/8": 2, "1/16": 4, "1/8T": 3, "1/16T": 6}
# Restrained: slow rates only, no sixteenth buzz.
const DROP_RATES := ["1/8", "1/4", "1/8", "1/8T"]
# Re-voicing, every four bars: which voice chops the lead's echo and at what interval,
# which voice plays the counter-line, what the choir sings (guide tones of the chord,
# or the lead's call from two bars back, answered in the current chord) and on which
# vowel, and the arpeggiator's shape and octave.
const ROTATIONS := [
	{"echo": 0, "shift": 12, "counter": "keys", "choir": "guide", "vowel": "ah", "arp": 0, "arp_oct": 12},
	{"echo": 1, "shift": 7, "counter": "choir_oo", "choir": "answer", "vowel": "ah", "arp": 1, "arp_oct": 24},
	{"echo": 0, "shift": 19, "counter": "bell", "choir": "guide", "vowel": "oo", "arp": 2, "arp_oct": 12},
	{"echo": 1, "shift": 12, "counter": "keys", "choir": "answer", "vowel": "oo", "arp": 0, "arp_oct": 24},
]
const ECHO_VOICES := [["bell", "mallet"], ["clav", "bell"], ["mallet", "bell"]]
const ARP_SHAPES := [[0, 1, 2, 3, 2, 1], [0, 2, 1, 3], [3, 2, 1, 0, 1, 2]]

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
# v2 W5 (SOUND-STORY.md section 2). The class motif seeds the counter-line on one of the
# four re-voicings, as a layer and never the lead; this is the rotation it takes.
const CLASS_ROTATION := 2
const CLASS_COUNTER_GAIN := 2.8
# Moss's lounge (SOUND-STORY.md section 8): a layer mask over the stage theme. Kick,
# hats, arp, choir, echo and counter out; brushes, the calm bass on the clean sub, keys
# on beats 1 and 3, the pad and the sax in, the whole about 7 LU under the full band so
# Moss's babble sits on top of it. The warm row keeps its overcharge.
const LOUNGE_GAINS := [0.5, 0.32, 0.0, 0.0, 0.7, 0.45, 0.9, 0.0, -1.0, 0.0, 0.7, 0.0, 0.0, 0.0, 0.0]
const LOUNGE_FLOOR := 0.15


class Voice:
	var buf: PackedFloat32Array
	var pos := 0
	var end := 0
	var gl := 0.7
	var gr := 0.7
	var layer := -1
	var to_stinger := false
	var mono := false
	var park_owned := false
	var park_owner := ""
	var park_rise := false
	# The bank id of the stinger this voice is, "" for any other voice.
	var stinger := ""


var park_cue_log: Array[Dictionary] = []
var _park_pcm := {}
# Park cue cells rendered on a worker before their beat, by signature.
static var _park_warm := {}
static var _park_warm_lock := Mutex.new()
# The worker task rendering each booked cell, by signature, until its beat takes it.
static var _park_tasks := {}

var clock := 0
var bar_origin := 0
var mode := IDLE
var pressure := 0.0
var applied_pressure := 0.0
const PARAMETER_SAMPLES_PER_BAR := 4
const ARMOUR_STRIP_AT := 0.3
var parameter_source := Callable()
var parameters := {}
var parameter_clamps := 0
var parameter_sample_count := 0
var parameter_sample_log: Array[Dictionary] = []
var parameter_layer_log: Array[Dictionary] = []
var parameter_layer_reads := {}
var _parameter_step := 0
var _parameter_phrase_due := false
var _parameter_danger := ""
var _parameter_danger_floor := 0.0
var _parameter_released := false
var _parameter_fleet_pending := 0
var _parameter_logged_fleet := -1
var landmark_hum_sound := ""
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
var warden_pivot_once_per_stage := WARDEN_PIVOT_ONCE_PER_STAGE
var warden_open_held_breath := WARDEN_OPEN_HELD_BREATH
var warden_escalate_from_segments := WARDEN_ESCALATE_FROM_SEGMENTS
var rules := 0
var _dominant_held := false
var _rotation_pins: Dictionary = {}
var _segment_fraction := -1.0
var _warden_rest_section := "build"
# [what, sample, detail] for every tempo, theme, track, key, build, gap and drop
# change, for the tests and the notes.
var events_log: Array = []
# The recent wobble cycles: [start_sample, rate, period, midi, grid_origin, step_len,
# bar_origin, bar].
var wob_log: Array = []
# Notes started per layer, so a test can tell a rhythmic figure from a held note.
var layer_starts := PackedInt32Array()
# Bass-figure notes per instrument (reese, fbass), so a test can name the bass line.
var bass_log := {}
# Tests solo layers to measure them alone.
var solo: Array = []

var _gains := PackedFloat32Array()
var _targets := PackedFloat32Array()
var _voices: Array = []
var band_voice_peak := 0
var band_voice_rejections := 0
var band_voice_steals := 0
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
var _lp := [0.0, 0.0, 0.0, 0.0]
var _cutoff := TONE_CALM_HZ
var _lp_on := false
# What the band is doing now, as a pressure: the applied pressure, the track's floor
# and a build's level, whichever is highest. The arrangements read it.
var _intensity := 0.0
var _rotation := 0
var _counter: Array = []
var _bar_queue: Array = []
var _transition := {}
var _lead_octave := 0
var _warden_lifted := false
var _warden_broken := false
# The B-arc on tracks without their own sections (miniboss, events, Brindle's phases,
# the chase): "" -> "lift" -> "break". Brindle's break plays the sinister half time.
var escalation := ""
# Heft class steps above the first: each lifts the band's intensity one step.
var heft_lift := 0
# A full ultimate meter adds one more step, the same size (SKILL-BAR section 4, music).
var ultimate_lift := false
var _requested_ultimate_lift := false
var _parameter_last_ultimate := false
var parameter_committed_values := {}
var parameter_committed_released := false
var parameter_committed_danger_floor := 0.0
var _mid := PackedFloat32Array()
var _left := PackedFloat32Array()
var _right := PackedFloat32Array()
var _sl := PackedFloat32Array()
var _sr := PackedFloat32Array()
var _dl := PackedFloat32Array()
var _dr := PackedFloat32Array()
var _hl := PackedFloat32Array()
var _hr := PackedFloat32Array()
var out_landmark := PackedVector2Array()
var _rng := RandomNumberGenerator.new()
var _stingers_live := false
# v2 W5 layers, each added on a real game-state threshold and never swapped in:
# the player's class motif in the counter rotation, the Fleet's reinforcement weight
# per difficulty tick (0..3), the reactor relic's Ab pedal while a vent charges, and
# Moss's lounge while the ball is in the bay.
var class_motif := ""
var fleet_ticks := 0
var reactor_pedal := false
var lounge := false
var _class_counter: Array = []
# One band at a time: while the ACE sequencer plays, the band starts no notes and mixes
# nothing, and stingers land on the ACE beat in its key (grid is the sequencer, which
# answers next_beat() and key_at() in this engine's transport samples).
var bot_skip_samples := false
# A played run sets it (Audio): a stinger queued for the next beat renders on a worker in the
# meantime, so a pilot's cue in a key the bake never reached (a boss fight's lift) never renders
# on the main thread when its beat comes.
var warm_stingers := false
# How often, in frames, a park cue cell held for its worker is checked again (_to_next_action).
const LATE_CHECK := 256
static var _stinger_tasks: Array[int] = []
var band_muted := false
var grid: Object = null


func _init() -> void:
	_gains.resize(LAYER_NAMES.size())
	_targets.resize(LAYER_NAMES.size())
	layer_starts.resize(LAYER_NAMES.size())
	_retarget()
	for i in _gains.size():
		_gains[i] = _targets[i]
	_lead = _make_track_lead()


# Spillway and the cadence: what the title needs, before the music starts.
static func prepare() -> void:
	_prepare_chords(Harmony.PROGRESSION + Harmony.CADENCE + [Harmony.MINOR_OF["G13"], Harmony.MINOR_OF["Cmaj9"], Harmony.MINOR_OF["Bbmaj9"]], ["lead"], 0)
	for drum in Synth.DRUMS:
		if SfxBank.bake_cancel:
			return
		Synth.drum(drum)
	for chord in Harmony.PROGRESSION:
		if SfxBank.bake_cancel:
			return
		Synth.note("reese", chord["root"] + 19)


# The rest of Spillway's band, which stage 1 plays once the run starts: the club layer,
# the layered lines, the lead voices and the Warden's half-step lift. Rendered on first
# use instead, each note costs 35 to 85 ms in one frame, so the run waits for this.
static func prepare_opening() -> void:
	_prepare_club(Harmony.PROGRESSION, 0, [12, 19, 22, 24])
	_prepare_chords(Harmony.PROGRESSION, ["brass", "talk"], 0)
	_prepare_chords(Harmony.PROGRESSION, ["lead", "brass", "talk"], 1)
	_prepare_club(Harmony.PROGRESSION, 1, [12, 18, 19, 22])
	for shift in [0, 1]:
		_prepare_club(Harmony.SINISTER + [Harmony.DOMINANT, Harmony.TRITONE], shift, [12, 18, 19, 22])
	# The layered lines and each pilot's counter-line: choir, echo chops and counter voices
	# across the lead's range.
	for midi in range(58, 88):
		if SfxBank.bake_cancel:
			return
		Synth.note("choir_ah", midi)
		Synth.note("choir_oo", midi)
		Synth.note("keys", midi)
		Synth.note("talk", midi)
		Synth.note("tom", midi)
		Synth.note("beep", midi)
	for midi in range(58, 104):
		if SfxBank.bake_cancel:
			return
		Synth.note("bell", midi)
		Synth.note("mallet", midi)
		Synth.note("clav", midi)
	# The bass lines walk and approach chromatically, so every pitch in their range, and
	# the reactor pedal's sub.
	for midi in range(34, 72):
		if SfxBank.bake_cancel:
			return
		Synth.note("fbass", midi)
		Synth.note("reese", midi + 10)
	for cell in Harmony.motif("reactor")["cells"]:
		Synth.note("sub", int(cell[1]))


# The house stabs, funk bass, reese and clav for each chord, shifted by semitones.
static func _prepare_club(chords: Array, shift: int, reese_offsets: Array) -> void:
	for chord in chords:
		if SfxBank.bake_cancel:
			return
		var voicing := _shift(chord["voicing"], shift)
		var root: int = int(chord["root"]) + shift
		Synth.stab_chord(voicing, false)
		Synth.stab_chord(voicing, true)
		for offset in [0, 7, 10, 12]:
			Synth.note("fbass", root + offset)
		if SfxBank.bake_cancel:
			return
		for offset in reese_offsets:
			Synth.note("reese", root + offset)
		for midi in voicing:
			if SfxBank.bake_cancel:
				return
			Synth.note("clav", midi)
			Synth.note("clav", midi + 12)
			Synth.note("clav", midi + 24)


# The other themes, keys and boss tracks: on a background worker behind stage 1.
# Anything asked for before it lands renders on demand.
# One thread bakes at a time; a second caller waits, then takes the cached pass. GDScript fills a
# line's untyped operator on first run without a lock for readers, so two threads running this cold
# in step can call a null evaluator: --warm-band=1 baked it on the main thread beside the game's own
# worker and crashed a 4080 bot run (SIGSEGV in _prepare_wobble, scrapkeep#587 comment 6510789416).
static var _rest_lock := Mutex.new()


static func prepare_rest() -> void:
	_rest_lock.lock()
	_bake_rest()
	_rest_lock.unlock()


static func _bake_rest() -> void:
	var chords: Array = []
	for list in [Harmony.SLUICE, Harmony.WEIR, Harmony.BRINDLE, Harmony.VICTORY, Harmony.MINOR_OF.values(), Harmony.BRINDLE_PHRYGIAN]:
		chords.append_array(list)
	_prepare_chords(chords, ["brass", "talk"], 0)
	_prepare_chords(Harmony.BRINDLE_PHRYGIAN, ["brass"], 1)
	_prepare_chords(Harmony.BRINDLE, ["brass"], 2)
	for list in [Harmony.WEIR, Harmony.BRINDLE, Harmony.MINOR_OF.values(), Harmony.BRINDLE_PHRYGIAN]:
		for chord in list:
			if SfxBank.bake_cancel:
				return
			Synth.organ_chord(chord["voicing"])
	# The boss phases that lift the key (BOSS_SECTIONS) hold an organ from phase 2 on.
	for pair in [[Harmony.BRINDLE_PHRYGIAN, 1], [Harmony.BRINDLE, 1], [Harmony.BRINDLE, 2]]:
		for chord in pair[0]:
			if SfxBank.bake_cancel:
				return
			Synth.organ_chord(_shift(chord["voicing"], pair[1]))
	for pair in [[Harmony.SLUICE, 0], [Harmony.WEIR, 0], [Harmony.VICTORY, 0], [Harmony.BRINDLE, 0],
			[Harmony.BRINDLE_PHRYGIAN, 1], [Harmony.BRINDLE, 1], [Harmony.BRINDLE, 2]]:
		_prepare_club(pair[0], pair[1], [12, 19, 22, 24])
	# The Warden's escalation: the lift a half step up, the sinister break and pivots.
	var lifted: Array = Harmony.PROGRESSION + Harmony.SLUICE + Harmony.WEIR + Harmony.SINISTER + [Harmony.DOMINANT, Harmony.TRITONE]
	_prepare_chords(lifted, ["lead", "brass", "talk"], 1)
	_prepare_chords(Harmony.SINISTER + [Harmony.DOMINANT, Harmony.TRITONE], [], 0)
	for shift in [0, 1]:
		for chord in lifted:
			if SfxBank.bake_cancel:
				return
			var voicing := _shift(chord["voicing"], shift)
			Synth.stab_chord(voicing, false)
			Synth.stab_chord(voicing, true)
			for offset in [0, 7, 10, 12]:
				Synth.note("fbass", int(chord["root"]) + shift + offset)
			if SfxBank.bake_cancel:
				return
			for offset in [12, 18, 19, 22]:
				Synth.note("reese", int(chord["root"]) + shift + offset)
	# Stingers in the lifted keys (a Warden lift, Brindle's phases), and the synergy
	# fanfare for each level, so a class-up after a lift never bakes on the audio thread.
	for shift in [0, 1, 2, 3]:
		for level in 3:
			if SfxBank.bake_cancel:
				return
			SfxBank.samples_at("synergy_fanfare", Harmony.STEP, shift, level)
			SfxBank.samples_at("synergy_fanfare", Harmony.BOSS_STEP, shift, level)
		if shift == 0:
			continue
		for id in ["class_up", "class_down", "stinger_milestone", "threat_up", "boss_phase"]:
			if SfxBank.bake_cancel:
				return
			SfxBank.samples_at(id, Harmony.STEP, shift)
			SfxBank.samples_at(id, Harmony.BOSS_STEP, shift)
	# Every recorded grid stinger on a boss grid, and the boss's defeat in each lifted key: a
	# recorded cue's variants share the file's one resample, so the Mind's grid (PHASE3_STEP)
	# and the fanfare's themes never resample it on the main thread mid-fight.
	for id in SfxBank.STINGER_BEATS:
		if SfxBank.bake_cancel:
			return
		if SfxBank.file_backed(id):
			for shift in [0, 1, 2, 3] if id == "stinger_boss_defeated" else [0]:
				SfxBank.samples_at(id, Harmony.BOSS_STEP, shift)
	# The restrained wobble of Brindle's drops.
	_prepare_wobble(Harmony.PROGRESSION + Harmony.SLUICE + Harmony.WEIR + Harmony.BRINDLE, [0], [Harmony.BOSS_STEP], ["wub"])
	_prepare_wobble(Harmony.BRINDLE_PHRYGIAN, [1], [Harmony.BOSS_STEP], ["wub"])
	_prepare_wobble(Harmony.BRINDLE, [2], [PHASE3_STEP], ["wub"])
	_prepare_wobble(Harmony.BRINDLE + Harmony.VICTORY, [0, 2], [Harmony.STEP], ["wub"])
	# A boss fight plays its chords in its section's key (BOSS_SECTIONS, 0 to 2) plus the escalation's
	# half-step lift, through the break's sinister chords and the dominant mask: every key to 3.
	# Its pads too: a pad rendered on first use costs 120 to 215 ms in one frame on the cloud.
	var boss_chords: Array = Harmony.BRINDLE + Harmony.BRINDLE_PHRYGIAN + Harmony.SINISTER + [Harmony.DOMINANT, Harmony.TRITONE]
	for shift in [0, 1, 2, 3]:
		for chord in boss_chords:
			if SfxBank.bake_cancel:
				return
			var voicing := _shift(chord["voicing"], shift)
			Synth.pad_chord(voicing)
			Synth.organ_chord(voicing)
			if SfxBank.bake_cancel:
				return
			Synth.stab_chord(voicing, false)
			Synth.stab_chord(voicing, true)
			Synth.chord(voicing)
			Synth.note("sub", int(chord["root"]) + shift)
	# The Mind's victory resolves in its own key (BOSS_SECTIONS), through _trigger_victory's voices.
	for chord in Harmony.VICTORY:
		if SfxBank.bake_cancel:
			return
		var voicing := _shift(chord["voicing"], int(BOSS_SECTIONS.mind.victory.key))
		Synth.chord(voicing)
		Synth.stab_chord(voicing, true)
		Synth.pad_chord(voicing)
		var root := int(chord["root"]) + int(BOSS_SECTIONS.mind.victory.key)
		Synth.note("sub", root)
		Synth.note("reese", root + 12)
		Synth.note("fbass", root)
		Synth.note("fbass", root + 12)
	# _start_riser's build riser, on both boss grids.
	for step in [Harmony.BOSS_STEP, PHASE3_STEP]:
		if SfxBank.bake_cancel:
			return
		SfxBank.samples_at("build_riser", step)


static func prepare_all() -> void:
	prepare()
	prepare_opening()
	prepare_rest()


static func _shift(voicing: Array, by: int) -> Array:
	var out := []
	for midi in voicing:
		out.append(int(midi) + by)
	return out


static func _prepare_chords(chords: Array, leads: Array, shift: int) -> void:
	for chord in chords:
		if SfxBank.bake_cancel:
			return
		var voicing := _shift(chord["voicing"], shift)
		Synth.note("sub", chord["root"] + shift)
		Synth.note("reese", chord["root"] + 12 + shift)
		Synth.chord(voicing)
		if SfxBank.bake_cancel:
			return
		Synth.pad_chord(voicing)
		for midi in voicing:
			Synth.note("bell", midi + 12)
			Synth.note("bell", midi + 24)
	for midi in range(60 + shift, 87 + shift):
		if SfxBank.bake_cancel:
			return
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
				for rate in DROP_RATES.map(func(r: String): return RATES[r]):
					for vowel in vowels:
						if SfxBank.bake_cancel:
							return
						Synth.wob(root + shift, int(step) * Harmony.STEPS_PER_BEAT / int(rate), vowel)


static func layer_gains(value: float) -> PackedFloat32Array:
	var gains := PackedFloat32Array()
	var p := clampf(value, 0.0, 1.0)
	for curve in CURVES:
		gains.append(curve[0] + (1.0 - curve[0]) * smoothstep(curve[1], curve[2], p))
	return gains


# How many melodic layers are in at a pressure: rises with it, never falls.
static func melodic_layers(value: float) -> int:
	var gains := layer_gains(value)
	var count := 0
	for layer in MELODIC:
		if gains[layer] > 0.05:
			count += 1
	return count


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
	for layer in [SNARE, LEAD, ARP, CHOIR]:
		if before[layer] < 0.05 and after[layer] >= 0.05:
			_riser_into(next_bar())
			break


func set_parameter_source(source: Callable) -> void:
	parameter_source = source
	_parameter_step = 0
	parameters.clear()
	parameter_committed_values.clear()


func _sample_parameters() -> void:
	var raw: Dictionary = parameter_source.call()
	parameters = {}
	for id in ["threat", "approach", "armour", "speed", "chain"]:
		if not raw.has(id):
			continue
		var value := float(raw[id])
		if not is_finite(value) or value < 0.0 or value > 1.0:
			parameter_clamps += 1
		parameters[id] = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	set_pressure(float(parameters.get("threat", 0.0)))
	parameter_sample_count += 1
	parameter_sample_log.append({"at": clock, "step": _parameter_step, "values": parameters.duplicate()})
	if parameter_sample_log.size() > 4096:
		parameter_sample_log.pop_front()


func parameter_danger(id: String) -> void:
	if not parameter_source.is_valid() or not MusicRows.danger(id):
		return
	_parameter_danger = id
	_parameter_danger_floor = 1.0
	_commit_parameters()
	_parameter_danger = ""


func parameters_warden_broken() -> void:
	_parameter_released = true


# True while a Warden break's release is set, committed or still waiting for its phrase.
func parameters_released() -> bool:
	return _parameter_released or parameter_committed_released


func parameters_stage_entered() -> void:
	_parameter_released = false
	_parameter_danger_floor = 0.0


# A new run reads nothing from the run before: the release a Warden's break left, and the armour
# reading a death left (below ARMOUR_STRIP_AT it strips the lead), are gone before the band's
# first stage primes from the committed values.
func parameters_run_started() -> void:
	parameters_stage_entered()
	parameter_committed_released = false
	parameter_committed_values.erase("armour")
	parameters.erase("armour")


# An arena has no landing phrase to wait for: the fight's band starts with the melody, so
# the committed release clears now as well, and the ACE player (audio.gd) is told the same.
func parameters_arena_entered() -> void:
	parameters_stage_entered()
	parameter_committed_released = false


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
	if grid != null:
		return grid.next_beat(from)
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
	_warm_stinger(id, start)
	return start


# home keeps the cue in D whatever key the band is in (a death's fall sits under the death cue,
# which is not keyed). step is the sixteenth a cue with notes of its own is made for, when the
# sounding band's is not this engine's (the recorded band); 0 is this engine's.
func schedule_stinger_at(id: String, at: int, db := 0.0, home := false, step := 0) -> void:
	_add_action(at, {"type": "stinger", "id": id, "db": db, "music": false, "home": home, "step": step})
	_warm_stinger(id, at, home, step)


# Takes a stinger back: its bookings are dropped and one already sounding is let go over a
# short release.
func cancel_stinger(id: String) -> void:
	_actions = _actions.filter(func(a): return a.get("type") != "stinger" or a.get("id", "") != id)
	for voice in _voices:
		if voice.stinger == id:
			voice.end = mini(voice.end, voice.pos + RELEASE)


# The key a stinger booked at transport sample at will sound in.
func stinger_key(at: int) -> int:
	return key if grid == null else grid.key_at(at)


# A stinger made ahead of its booking: a kill chain's landing is known a chain window before it
# is booked, and a note a sixteenth from its contact is made when its key arrives.
func warm_stinger(id: String, at: int, home := false, step := 0) -> void:
	_warm_stinger(id, at, home, step)


# The variant _run's "stinger" will ask for at `at`, on a worker, unless it is made already.
func _warm_stinger(id: String, at: int, home := false, made_for := 0) -> void:
	if not warm_stingers:
		return
	var shift: int = 0 if home else stinger_key(at)
	var step := made_for if made_for > 0 else step_len
	var theme_now := theme
	if SfxBank.cached_at(id, step, shift, theme_now):
		return
	_stinger_tasks = _stinger_tasks.filter(func(task): return not WorkerThreadPool.is_task_completed(task) or _settle_task(task))
	_stinger_tasks.append(WorkerThreadPool.add_task(func(): SfxBank.samples_at(id, step, shift, theme_now), true, "stinger warm"))


# Plain bank sounds a stage will ask for on a frame, decoded on a worker ahead of it.
func warm_samples(ids: Array[String]) -> void:
	if not warm_stingers or ids.is_empty():
		return
	_stinger_tasks = _stinger_tasks.filter(func(task): return not WorkerThreadPool.is_task_completed(task) or _settle_task(task))
	_stinger_tasks.append(WorkerThreadPool.add_task(_warm_samples.bind(ids), true, "riser warm"))


static func _warm_samples(ids: Array[String]) -> void:
	for id in ids:
		SfxBank.samples(id)


static func _settle_task(task: int) -> bool:
	WorkerThreadPool.wait_for_task_completion(task)
	return false


# Teardown: waits on every stinger still rendering.
static func settle_stingers() -> void:
	for task in _stinger_tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_stinger_tasks.clear()


static func stage_theme(stage = "default") -> int:
	return int(MusicRows.resolve(stage)["synth_theme"])


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
	for action in _actions:
		if action["type"] == "track" and action.get("track", "") == kind:
			return -1
	var first := "build" if kind == "warden" else "1"
	_warden_lifted = false
	_warden_broken = false
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


# Back into a boss fight after a death (the arena retry): the boss track restarts
# from its first section, home key and play mode on the next beat, at the boss tempo
# without the pivot (the level is not playing to pivot from).
func restart_boss(kind: String) -> int:
	var at := next_beat()
	_warden_lifted = false
	_warden_broken = false
	_add_action(at, {"type": "track", "track": kind, "section": "build" if kind == "warden" else "1", "key": 0,
		"step": Harmony.BOSS_STEP if boss_pivot else Harmony.STEP, "play": true})
	return at


# How broken the Warden is (0..1). The last quarter is the build: the snare roll
# tightens, the riser climbs and the high-pass opens with every hit.
func warden_charge(fraction: float) -> void:
	if track != "warden" or section == "drop":
		return
	escalate(fraction)


# A lap's window changes the arrangement without restarting the clock or B arc.
# Closing a missed window restores the earned section. The final break still uses
# unseal_drop(), and AU3 uses the pivot policy when deciding whether to end a lap.
func warden_section(name: String) -> int:
	if track != "warden" or name not in ["open", "build"]:
		return -1
	if name == "open" and not warden_open_held_breath:
		return drop_now(4, 1.0)
	if name == "open" and section != "open":
		_warden_rest_section = section if section in ["build", "lift", "break"] else "build"
	cancel_build()
	_drop = {}
	section = "open" if name == "open" else _warden_rest_section
	if name == "build" and _segment_fraction >= 0.0:
		escalate(_segment_fraction)
	_retarget()
	_release_all()
	events_log.append(["section", clock, section])
	return clock


# A shelf return is not a boss death. The lab's per-lap alternative uses the same
# cadence as before; the default keeps the earned club arrangement at 129.
func end_warden_lap() -> int:
	if track != "warden" or warden_pivot_once_per_stage:
		return -1
	return end_boss()


func hold_dominant(on: bool) -> void:
	_dominant_held = on
	events_log.append(["hold_dominant", clock, on])


# The ready pulse is already baked per class; AU2 may supply the dedicated recipe.
# Resolve the live key at playback, including a key change on this very sixteenth.
func door_tick() -> int:
	var at := _next_multiple(1)
	_add_action(at, {"type": "door_tick"})
	return at


func segments_cut(n: int, total: int) -> void:
	if not warden_escalate_from_segments or track != "warden" or total <= 0:
		return
	_segment_fraction = maxf(_segment_fraction, clampf(float(n) / total, 0.0, 1.0))
	escalate(_segment_fraction)


# Pins start at the next four-bar rotation. rotations=1 is the armed tease;
# rotations=0 persists until cleared with an empty shape (or a new engine).
# arp: {arp: 2, arp_oct: 12}; echo: {echo_voice: "bell", shift: 7};
# counter: {counter: "tom", class_counter: true, counter_oct: -12, counter_boom: true}.
func pin_rotation(slot: String, shape: Dictionary, rotations := 0) -> bool:
	var fields := {
		"arp": ["arp", "arp_oct"], "echo": ["echo_voice", "shift"],
		"counter": ["counter", "class_counter", "counter_oct", "counter_boom"],
		"choir": ["choir", "vowel"],
	}
	if not fields.has(slot) or rotations < 0:
		return false
	if shape.is_empty():
		_rotation_pins.erase(slot)
		return true
	for field in shape:
		if field not in fields[slot]:
			return false
	if shape.has("arp") and (int(shape["arp"]) < 0 or int(shape["arp"]) >= ARP_SHAPES.size()):
		return false
	_rotation_pins[slot] = {"shape": shape.duplicate(true), "from": _rotation + 1,
		"until": _rotation + 1 + rotations if rotations > 0 else -1}
	return true


func _rotation_state() -> Dictionary:
	var rot: Dictionary = ROTATIONS[_rotation % ROTATIONS.size()].duplicate()
	for pin in _rotation_pins.values():
		if _rotation >= int(pin["from"]) and (int(pin["until"]) < 0 or _rotation < int(pin["until"])):
			rot.merge(pin["shape"], true)
	if _dominant_held:
		rot["arp"] = 0
	return rot


# B's grammar, for any track (MUSIC-GEMS G11). fraction is how far the fight or event
# has gone (0..1), read from real game state. Half way lifts the key a half step
# through a pickup bar on the new key's dominant; three quarters starts the break
# (sinister half time where the track has one) and a build that tightens with the
# fraction; the payoff (the drop) is the caller's, on the gameplay moment.
func escalate(fraction: float, sinister := true) -> void:
	if not _drop.is_empty() or _cadence_bar >= 0 or mode != PLAY:
		return
	if fraction >= WARDEN_LIFT_AT and not _warden_lifted:
		_warden_lifted = true
		var lift := {"key": key + 1, "lead_octave": 12}
		if track in ["warden", "miniboss"]:
			lift["section"] = "lift"
		else:
			lift["esc"] = "lift"
		_queue(lift, {"chord": Harmony.DOMINANT, "key": key + 1})
		events_log.append(["lift_queued", clock, fraction])
	if fraction < WARDEN_BUILD_FROM:
		return
	if not _warden_broken:
		_warden_broken = true
		var break_key := key + (0 if _warden_lifted else 1)
		for item in _bar_queue:
			if (item["set"] as Dictionary).has("key"):
				break_key = int(item["set"]["key"])
		if sinister:
			var brk := {"lead_octave": 0, "key": break_key}
			if track in ["warden", "miniboss"]:
				brk["section"] = "break"
			else:
				brk["esc"] = "break"
			_queue(brk, {"chord": Harmony.TRITONE, "key": break_key})
		events_log.append(["break_queued", clock, fraction])
	if _build_level < 0.0:
		_start_riser()
		events_log.append(["build", clock, track])
	_build_level = clampf((fraction - WARDEN_BUILD_FROM) / (1.0 - WARDEN_BUILD_FROM), 0.0, 1.0)


# An event's end. A win drops home into the level on the next beat; a pass or a loss
# settles gracefully: the build fades and the key walks home through a pickup bar.
func resolve_event(won: bool) -> int:
	if won:
		return drop_now(4, 0.85, {}, theme)
	cancel_build()
	if key != 0:
		_queue({"key": 0, "esc": "", "lead_octave": 0}, {"chord": Harmony.DOMINANT, "key": 0})
	else:
		_queue({"esc": "", "lead_octave": 0})
	_reset_escalation(false)
	return -1


# The miniboss dies: the drop home on the next beat, then the cadence into the level.
func miniboss_drop() -> int:
	if track != "miniboss":
		return -1
	return drop_now(4, 0.9, {"type": "cadence", "then": {"track": "level", "section": "", "step": Harmony.STEP}}, theme)


# A fight that ends inside the bar before its track lands (begin_miniboss, begin_boss) takes
# the queued switch with it, so the band never enters a track whose fight is already over.
# True when a switch was dropped.
func drop_pending_track(kind: String) -> bool:
	var before := _actions.size()
	_actions = _actions.filter(func(a): return a.get("type") != "track" or a.get("track", "") != kind)
	if _actions.size() == before:
		return false
	events_log.append(["track_dropped", clock, kind])
	return true


# An event's escalation build (escalate's riser, with no start_build behind it) belongs to the
# track it rose on: a track change or restart ends it, so the next track never inherits its
# floor. A start_build or planned_drop build (launch, ultimate) carries on.
func _end_escalation_build() -> void:
	if _build_level >= 0.0 and _build_from < 0 and _pending_drop.is_empty():
		cancel_build()


func _reset_escalation(clear_esc := true) -> void:
	_warden_lifted = false
	_warden_broken = false
	_segment_fraction = -1.0
	if clear_esc:
		escalation = ""


# Heft classes above the first brighten the band from the next bar: a re-voice and
# one step more intensity per class; a drop steps it back.
func set_heft_lift(steps: int) -> void:
	var next := maxi(steps, 0)
	if next == heft_lift:
		return
	_queue({"heft": next})


# The ultimate meter is full: one intensity step from the next bar line, the step
# set_heft_lift uses. A layer is added, never swapped (MUSIC-GEMS.md G11); the landing's drop
# or a cancel that spends the meter releases it at the next bar.
func set_ultimate_lift(on: bool) -> void:
	_requested_ultimate_lift = on
	for item in _bar_queue:
		if (item["set"] as Dictionary).has("ult"):
			item["set"]["ult"] = on
			return
	if on == ultimate_lift:
		return
	_queue({"ult": on})


# The player's class motif (a Harmony.MOTIFS id) seeds the counter-line on its
# rotation: a layer, refitted to the chord it lands on.
func set_class_motif(id: String) -> void:
	class_motif = id
	_class_counter = _make_class_counter()


# The difficulty clock's ticks past the Warden break (threat_rose). Each adds a Fleet
# layer from the next bar line and never swaps one: 1 the anvil on beats 2 and 4, 2 the
# brass semitone lean answering the lead, 3 the anvil on every beat.
func set_fleet_ticks(ticks: int) -> int:
	if parameter_source.is_valid():
		_parameter_fleet_pending = clampi(ticks, 0, 3)
		return _next_multiple(Harmony.PHRASE_BARS * Harmony.STEPS_PER_BAR)
	var at := next_bar()
	_add_action(at, {"type": "fleet", "ticks": clampi(ticks, 0, 3)})
	return at


# A reactor relic's vent is charging: the sub takes the Ab pedal from the next bar
# line, under the bass figure, until the vent blows.
func set_reactor_pedal(on: bool) -> void:
	reactor_pedal = on


# The ball is banked in Moss's bay: the lounge from the next bar line. Leaving is the
# launch build and the landing drop, which ends the lounge on the beat.
func set_lounge(on: bool) -> int:
	var at := next_bar()
	_add_action(at, {"type": "lounge", "on": on})
	return at


# A death: on the next beat the band breaks (a boom, everything cut), then keys only.
func death_break() -> int:
	var at := next_beat()
	_add_action(at, {"type": "hit", "drums": ["boom", "crash"]})
	schedule_mode(at, DEAD)
	return at


# A retry: a snare pickup climbs into the restart. The restart is the beat after next,
# so there is always at least a beat to fill.
func retry_restart(next_mode: int, next_theme := -1) -> int:
	var at := next_beat(clock + beat_len())
	fill_into(at)
	schedule_restart(at, next_mode, next_theme)
	return at


func fill_into(at: int) -> void:
	var from := maxi(next_beat(), at - 8 * step_len)
	var steps := (at - from) / step_len
	for i in steps:
		_add_action(from + i * step_len, {"type": "roll", "gain": 0.4 + 0.6 * float(i + 1) / maxf(steps, 1)})
	events_log.append(["fill", from, at])


# Queues a change for a coming bar line. With a transition, the bar before it is a
# pickup: a snare fill and a pivot chord in the new key, so a key change is never a cut.
func _queue(change: Dictionary, transition := {}) -> void:
	var wait := 2 if not transition.is_empty() else 1
	for item in _bar_queue:
		wait = maxi(wait, int(item["in"]) + (2 if not transition.is_empty() else 1))
	_bar_queue.append({"in": wait, "set": change, "transition": transition})


# A drop on the next beat: the play head goes quiet until then, then the drop.
# next_theme >= 0 restarts the level phrase in that theme (a stage landing).
func drop_now(bars: int, weight: float, then := {}, next_theme := -1, change := {}) -> int:
	var at := next_beat()
	if at > clock:
		_add_action(clock, {"type": "gap"})
	_add_action(at, {"type": "drop", "bars": bars, "weight": weight, "then": then, "theme": next_theme, "set": change})
	return at


# The Warden breaks: the heaviest drop in the stage, eight bars back home in D, then
# the kill cadence resolves home to the level at 172.
func unseal_drop() -> int:
	parameters_warden_broken()
	return drop_now(8, 1.0, {"type": "cadence", "then": {"track": "level", "section": "", "step": Harmony.STEP}}, -1, {"unseal": true})


# The unseal drop at a given beat (kept for callers that pick the beat).
func drop_at(at: int) -> void:
	_add_action(at, {"type": "drop", "bars": 8, "weight": 1.0, "then": {"type": "cadence", "then": {"track": "level", "section": "", "step": Harmony.STEP}}, "theme": -1, "set": {"unseal": true}})


# The title or summary theme from the next bar line (or at a sample), leaving the mode
# alone. A repeat for the track and section already playing or queued returns -1.
func menu_theme(name: String, won := true, at := -1) -> int:
	var next_section := "" if name == "title" else ("won" if won else "lost")
	if track == name and section == next_section:
		return -1
	for action in _actions:
		if action["type"] == "track" and action["track"] == name and action.get("section", "") == next_section:
			return -1
	var start := next_bar() if at < 0 else at
	_add_action(start, {"type": "track", "track": name, "section": next_section, "step": Harmony.STEP, "key": 0})
	events_log.append(["menu", clock, name, next_section])
	return start


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
	if not track in BOSS_TRACKS or not BOSS_SECTIONS[track].has(name):
		return -1
	# The payoff lands on the gameplay moment: the phase change (or the catch) drops on
	# the next beat. The in-phase build (brindle_hp) has already done the building.
	var change: Dictionary = BOSS_SECTIONS[track][name].duplicate()
	change.merge({"track": track, "section": name})
	if track == "brindle" and name in ["1", "2"] and not boss_pivot:
		change["step"] = step_len
	var weight := 0.9
	match name:
		"chase":
			weight = 0.95
		"victory":
			weight = 1.2
	return drop_now(4, weight, {}, -1, change)


func set_boss_state(state: String) -> int:
	var parts := state.split(":")
	if parts.size() != 2 or parts[0] != track or not BOSS_SECTIONS.has(parts[0]):
		return -1
	var next_section := parts[1]
	if not BOSS_SECTIONS[track].has(next_section) or next_section == section:
		return -1
	for action in _actions:
		if action["type"] == "drop":
			var change: Dictionary = action.get("set", {})
			if change.get("track", "") == track and change.get("section", "") == next_section:
				return -1
	return brindle_section(next_section)


# Brindle's HP inside the current phase, as a fraction of the way from the phase's top
# to its floor, and whether the floor is held for the set piece (with its clock, 0..1).
# Half way lifts; the held floor is the sinister break tightening with the set piece.
func brindle_hp(in_phase: float, floor_held := false, piece := 0.0) -> void:
	if not track in BOSS_TRACKS or not section in ["1", "2", "3"]:
		return
	if floor_held:
		escalate(WARDEN_BUILD_FROM + (1.0 - WARDEN_BUILD_FROM) * clampf(piece, 0.0, 1.0))
	else:
		escalate(minf(in_phase, 0.74))


# The chase: the heartbeat climbs as the scooter's lead shrinks (closed 0..1). No
# sinister break: the chase is the run home.
func chase(closed: float) -> void:
	if not track in BOSS_TRACKS or section != "chase":
		return
	escalate(closed, false)


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
	if next_track in BOSS_TRACKS:
		action["key"] = BOSS_SECTIONS[next_track].get(next_section, {}).get("key", 0)
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
	_dominant_held = false
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
	_bar_queue.clear()
	_transition = {}
	# A dropped lift or break may be queued again by the next escalate.
	_warden_lifted = false
	_warden_broken = false
	cancel_build()
	for voice in _voices:
		if voice.layer < 0:
			voice.end = mini(voice.end, voice.pos + RELEASE)


# Pulls the band down under an important cue, then lets it back up.
func duck(amount: float, hold_seconds: float) -> void:
	# Preserve the requested depth at full intensity; soften it in the sparse band.
	var depth := lerpf(2.0 / 3.0, 1.0, clampf((_intensity - 0.3) / 0.7, 0.0, 1.0))
	_duck_target = minf(_duck_target, 1.0 - (1.0 - clampf(amount, 0.1, 1.0)) * depth)
	_duck_until = maxi(_duck_until, clock + int(hold_seconds * Harmony.RATE))


# The cue the band dipped under has stopped early: the band comes back from this frame, over
# a beat.
func free_duck() -> void:
	_duck_until = clock
	_duck_target = 1.0


# Pulls only the bass down, so a danger cue is never masked by the low end.
func duck_bass(amount: float, hold_seconds: float) -> void:
	_bass_duck_target = minf(_bass_duck_target, clampf(amount, 0.1, 1.0))
	_bass_duck_until = maxi(_bass_duck_until, clock + int(hold_seconds * Harmony.RATE))


# Breaking free: the bass comes back from this frame, over a beat.
func free_bass() -> void:
	_bass_duck_until = clock
	_bass_duck_target = 1.0


func pending_actions() -> int:
	return _actions.size()


func voice_count() -> int:
	return _voices.size()


# The caller supplies the director's landing sample, including any held landing.
func park_cue(id: String, lead_frames := 0, at := -1, context: Dictionary = {}, priority_db := 0.0, owner := "") -> int:
	var options := context.duplicate()
	options["theme"] = options.get("theme", theme)
	var row := MusicRows.cue(id, options)
	if row.is_empty():
		push_error("music: missing park cue " + id)
		return -1
	var start: int = clock if at < 0 else at
	if row.rise and row.get("stinger", false):
		_park_file_riser(id, row, options, lead_frames, start, priority_db, owner)
		return start
	if row.rise:
		var count: int = row.notes.size()
		for i in count:
			var from := roundi(float(lead_frames) * i / count)
			var until := roundi(float(lead_frames) * (i + 1) / count)
			_add_action(start + from, {"type": "park_cue", "id": id, "row": row, "cell": i,
				"length": maxi(1, until - from), "progress": float(i) / count, "priority_db": priority_db, "owner": owner})
	else:
		_add_action(start, {"type": "park_cue", "id": id, "row": row, "cell": 0,
			"length": beat_len() * 2, "progress": 1.0, "priority_db": priority_db, "owner": owner})
	return start


# A rendered riser ends exactly at the landing: it starts at landing minus its length, and
# the synth cells fill only the lead before it. A lead shorter than the file drops the file's
# first frames instead of moving the end.
func _park_file_riser(id: String, row: Dictionary, options: Dictionary, lead_frames: int, start: int, priority_db: float, owner: String) -> void:
	var length := SfxBank.samples_at(row.sound, step_len, 0, theme).size()
	var file_at := start + lead_frames - length
	var skip := 0
	if file_at < start:
		skip = start - file_at
		file_at = start
	var before := lead_frames - length
	if before > 0:
		var plain := options.duplicate()
		plain.erase("stage")
		var synth := MusicRows.cue(id, plain)
		var count: int = synth.notes.size()
		for i in count:
			var from := roundi(float(before) * i / count)
			var until := roundi(float(before) * (i + 1) / count)
			_add_action(start + from, {"type": "park_cue", "id": id, "row": synth, "cell": i,
				"length": maxi(1, until - from), "progress": float(i) / count, "priority_db": priority_db, "owner": owner})
	if skip < length:
		_add_action(file_at, {"type": "park_cue", "id": id, "row": row, "cell": 0, "skip": skip,
			"length": length - skip, "progress": 1.0, "priority_db": priority_db, "owner": owner})


func cancel_park_cue(owner: String) -> void:
	_actions = _actions.filter(func(a): return a.get("type") != "park_cue" or a.get("owner", "") != owner)
	for voice in _voices:
		if voice.park_owner == owner and voice.park_owned:
			voice.end = mini(voice.end, voice.pos + RELEASE)


func cancel_park_drop(owner: String) -> void:
	_actions = _actions.filter(func(a): return a.get("type") != "park_cue" or a.get("owner", "") != owner or a.row.rise)
	for voice in _voices:
		if voice.park_owned and voice.park_owner == owner and not voice.park_rise:
			voice.end = mini(voice.end, voice.pos + RELEASE)


func park_cue_samples(action: Dictionary, live_key: int) -> PackedFloat32Array:
	var signature := _park_signature(action, live_key, step_len)
	if _park_pcm.has(signature):
		return _park_pcm[signature]
	# A cell its worker has finished is taken. One still queued or rendering is not waited for: behind
	# the next stage's build at the Warden's engage it waited 1 s on the cloud (the 4080 receipt's
	# stage 1 spikes), where rendering it here costs 25 to 80 ms. The task stays listed for teardown.
	var task: int = _park_tasks.get(signature, -1)
	_park_tasks.erase(signature)
	if task >= 0 and _stinger_tasks.has(task) and WorkerThreadPool.is_task_completed(task):
		_stinger_tasks.erase(task)
		WorkerThreadPool.wait_for_task_completion(task)
	_park_warm_lock.lock()
	var buf: PackedFloat32Array = _park_warm.get(signature, PackedFloat32Array())
	_park_warm.erase(signature)
	_park_warm_lock.unlock()
	if buf.is_empty():
		buf = _render_park(action.row, action.cell, action.length, action.progress, int(action.get("skip", 0)), live_key, step_len, theme)
	if _park_pcm.size() >= 64:
		_park_pcm.clear()
	_park_pcm[signature] = buf
	return buf


# A synth cell does not depend on the grid's step, so a tempo change between its booking and its
# beat keeps its buffer; a cell that plays a baked sound does.
static func _park_signature(action: Dictionary, live_key: int, step: int) -> String:
	var row: Dictionary = action.row
	var stepped: bool = row.get("stinger", false) or row.has("sound")
	return str([row, action.cell, action.length, action.progress, live_key, step if stepped else 0, int(action.get("skip", 0))])


static func _render_park(row: Dictionary, cell: int, length: int, progress: float, skip: int, live_key: int, step: int, theme_now: int) -> PackedFloat32Array:
	var buf: PackedFloat32Array
	if row.get("stinger", false):
		buf = SfxBank.samples_at(row.sound, step, 0, theme_now)
		if skip > 0:
			buf = Synth.declick(buf.slice(skip))
	elif row.has("sound"):
		buf = SfxBank.samples_at(row.sound, step, live_key, theme_now)
	else:
		var n: int = length
		var midi: int = row.notes[cell] + live_key
		match row.voice:
			"lead": buf = Synth.lead(midi, n)
			"brass": buf = Synth.brass(midi, n)
			"talk": buf = Synth.talk(midi, n)
			"sub": buf = Synth.sub(midi, n)
			"buzz": buf = Synth.buzz(midi, n, 0.0)
			"chime": buf = Synth.chime(midi, n)
			"steam_whistle":
				buf = Synth.buffer(n)
				var phase := 0.0
				var step_hz := TAU * Harmony.hz(midi) / Harmony.RATE
				var bend := Harmony.ratio(2)
				var rng := RandomNumberGenerator.new()
				rng.seed = 0x57EA
				for i in n:
					phase += step_hz * lerpf(1.0, bend, float(i) / n)
					buf[i] = sin(phase) + 0.12 * rng.randf_range(-1.0, 1.0)
			_: buf = Synth.note(row.voice, midi).slice(0, n)
		if row.has("accent"):
			Synth.add_into(buf, Synth.drum(row.accent), 0, 0.35)
		buf = Synth.normalize(buf)
		if row.rise:
			for i in buf.size():
				buf[i] *= lerpf(0.25, 1.0, progress + float(i) / maxi(1, buf.size()) / row.notes.size())
		buf = Synth.declick(buf)
	return buf


func render(frames: int) -> void:
	out_music.resize(frames)
	out_stinger.resize(frames)
	out_landmark.resize(frames)
	_mid.resize(frames)
	_left.resize(frames)
	_right.resize(frames)
	_sl.resize(frames)
	_sr.resize(frames)
	_dl.resize(frames)
	_dr.resize(frames)
	_hl.resize(frames)
	_hr.resize(frames)
	_stingers_live = false
	_mid.fill(0.0)
	_left.fill(0.0)
	_right.fill(0.0)
	_sl.fill(0.0)
	_sr.fill(0.0)
	_dl.fill(0.0)
	_dr.fill(0.0)
	_hl.fill(0.0)
	_hr.fill(0.0)
	var done := 0
	while done < frames:
		_run_due()
		if posmod(clock - grid_origin, step_len) == 0 and _step_clock != clock:
			_on_step()
			_run_due()
		var n := mini(frames - done, step_len - posmod(clock - grid_origin, step_len))
		n = mini(n, _to_next_action())
		if _pump_depth > 0.0:
			var beat := beat_len()
			var in_beat := posmod(clock - grid_origin, beat)
			var hold := int(beat * PUMP_HOLD_FRAC)
			if in_beat < PUMP_ATTACK:
				n = mini(n, PUMP_ATTACK - in_beat)
			elif in_beat < hold:
				n = mini(n, hold - in_beat)
		n = maxi(n, 1)
		_mix(done, n)
		clock += n
		done += n
	_finish(frames)


# --- Sequencer ------------------------------------------------------------------------

func _add_action(at: int, action: Dictionary) -> void:
	action["at"] = at
	_actions.append(action)
	if action["type"] == "park_cue":
		_warm_park(action, at)


# Like _warm_stinger: render the cell on a worker so its beat only plays it. A cell due now (a riser's
# first, booked as its event is announced) renders there too and starts late, at the frame it would have
# reached (_late_cell_waits): stage 6 announces six events at once, and their first cells rendered in one
# frame took 13 to 73 ms each on the main thread (PR #372).
func _warm_park(action: Dictionary, at: int) -> void:
	if not warm_stingers:
		return
	if at <= clock:
		action["late"] = true
	var shift: int = key if grid == null else grid.key_at(at)
	var signature := _park_signature(action, shift, step_len)
	if _park_pcm.has(signature):
		return
	var row: Dictionary = action.row.duplicate(true)
	var cell: int = action.cell
	var length: int = action.length
	var progress: float = action.progress
	var skip := int(action.get("skip", 0))
	var step := step_len
	var theme_now := theme
	# A cell due within a second goes ahead of the band's low-priority renders: behind them a late cell lost up
	# to its whole length, and the next cells held the main thread 0.2 to 0.5 s (cloud, stage 6 risers).
	var urgent := at - clock < Harmony.RATE
	_stinger_tasks = _stinger_tasks.filter(func(task): return not WorkerThreadPool.is_task_completed(task) or _settle_task(task))
	if _park_tasks.size() >= 64:
		_park_tasks.clear()
	_park_tasks[signature] = WorkerThreadPool.add_task(func():
		var buf := _render_park(row, cell, length, progress, skip, shift, step, theme_now)
		_park_warm_lock.lock()
		if _park_warm.size() >= 64:
			_park_warm.clear()
		_park_warm[signature] = buf
		_park_warm_lock.unlock(), urgent, "park cue warm")
	_stinger_tasks.append(_park_tasks[signature])


func _to_next_action() -> int:
	var nearest := 1 << 30
	for action in _actions:
		var wait: int = action["at"] - clock
		if wait > 0:
			nearest = mini(nearest, wait)
		elif action.get("late", false):
			# A late cell waiting on its worker is checked every LATE_CHECK frames, so it loses little of its head.
			nearest = mini(nearest, LATE_CHECK)
	return nearest


func _run_due() -> void:
	var due: Array = []
	for action in _actions:
		if action["at"] <= clock:
			# Keyed cues on a step boundary hear the committed bar key.
			if action["type"] in ["door_tick", "park_cue"] and _step_clock != clock and posmod(clock - grid_origin, step_len) == 0:
				continue
			if action.get("late", false) and _late_cell_waits(action):
				continue
			# A cell booked ahead whose worker is still on it at its beat waits the same way: rendering it here held
			# the crown's spire telegraph frame 300 ms on the cloud (scrapkeep#241).
			if action["type"] == "park_cue" and _late_cell_waits(action):
				action["late"] = true
				continue
			due.append(action)
	for action in due:
		_actions.erase(action)
		_run(action)


# A cell booked late waits for its worker while the worker is still on it and the cell has frames left to
# play; past that, or with no worker for the key it now plays in, it renders here as before.
func _late_cell_waits(action: Dictionary) -> bool:
	if clock - int(action.at) >= int(action.length):
		return false
	var live_key: int = key if grid == null else grid.key_at(clock)
	var task: int = _park_tasks.get(_park_signature(action, live_key, step_len), -1)
	# A task no longer in _stinger_tasks has been waited on (_settle_task), and its ID is spent.
	return task >= 0 and _stinger_tasks.has(task) and not WorkerThreadPool.is_task_completed(task)


func _on_step() -> void:
	_step_clock = clock
	if parameter_source.is_valid():
		var phrase_steps := Harmony.PHRASE_BARS * Harmony.STEPS_PER_BAR
		var sample_steps := phrase_steps / (Harmony.PHRASE_BARS * PARAMETER_SAMPLES_PER_BAR)
		if _parameter_step % sample_steps == 0:
			_sample_parameters()
		_parameter_step += 1
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
		var lap: bool = _drop.get("lap", false)
		if lap:
			section = _drop["rest"]
			_bar_queue = _drop["queue"]
		_drop = {}
		if lap:
			escalate(_segment_fraction)
		_reset_bar()
		_step_clock = clock
		_new_phrase()
		_retarget()
		events_log.append(["drop_end", clock, track])
		if not then.is_empty():
			_run(then.duplicate())
			_step_clock = clock
	if parameter_source.is_valid():
		_parameter_phrase_due = _bar_step % (Harmony.PHRASE_BARS * Harmony.STEPS_PER_BAR) == 0
		if _parameter_phrase_due:
			if fleet_ticks != _parameter_fleet_pending:
				fleet_ticks = _parameter_fleet_pending
				events_log.append(["fleet", clock, fleet_ticks])
			_parameter_danger_floor = 0.0
			_commit_parameters()
		_parameter_phrase_due = false
	var s := _bar_step % Harmony.STEPS_PER_BAR
	var bar := _bar_step / Harmony.STEPS_PER_BAR
	# A build stacks layers as it rises.
	if building() and s % Harmony.STEPS_PER_BEAT == 0:
		_retarget()
	# The gap before a planned drop: the last eighth of the build is silence.
	if not _pending_drop.is_empty() and int(_pending_drop["bars"]) == 1 and s == Harmony.STEPS_PER_BAR - 2 and not _gap:
		_run({"type": "gap"})
	_bar_step += 1
	if _gap:
		return
	var chord := _chord(bar)
	if _targets[LANDMARK_HUM] > 0.0 and s % Harmony.STEPS_PER_BEAT == 0:
		var hum := SfxBank.samples(landmark_hum_sound)
		_start(hum, hum.size(), LANDMARK_HUM, db_to_linear(SfxBank.trim_db(landmark_hum_sound)), 0.0, false)
	if fleet_ticks > 0 and _targets[FLEET] > 0.0 and track == "level" and _cadence_bar < 0 and not _lounge_live():
		_fleet_layer(s, chord)
	if not _drop.is_empty():
		_trigger_drop(bar, s, chord)
		# A gate taken mid-drop (right after the unseal) builds over the drop.
		if building():
			_build_overlay(s)
		return
	if _cadence_bar >= 0:
		_trigger_dnb(bar, s, chord)
		return
	match _score_track():
		"warden":
			if section == "break":
				_trigger_break(bar, s, chord)
			else:
				_trigger_house(bar, s, chord)
		"brindle":
			if escalation == "break":
				_trigger_break(bar, s, chord)
			else:
				_trigger_brindle(bar, s, chord)
		"miniboss" when section == "break":
			_trigger_break(bar, s, chord)
		_:
			if _lounge_live():
				_trigger_lounge(bar, s, chord)
			else:
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
	if not _transition.is_empty():
		_fill(s)
	if building():
		_build_overlay(s)


func _run(action: Dictionary) -> void:
	match action["type"]:
		"door_tick":
			var id := "door_tick"
			var buf := SfxBank.samples_at(id, step_len, key, theme)
			_start(buf, buf.size(), -1, db_to_linear(SfxBank.trim_db(id)), 0.0, true)
			events_log.append(["door_tick", clock, id])
		"park_cue":
			parameter_danger(action.id)
			var live_key: int = key if grid == null else grid.key_at(clock)
			var buf := park_cue_samples(action, live_key)
			var row: Dictionary = action.row
			var db := SfxBank.trim_db(row.trim_sound) + float(action.priority_db)
			var voice := _start(buf, buf.size(), -1, db_to_linear(db), 0.0, true)
			# A cell that waited for its worker plays from where it would be by now, so the cells after it still land.
			if action.get("late", false):
				voice.pos = clampi(clock - int(action.at), 0, voice.end)
			voice.park_owned = true
			voice.park_owner = action.owner
			voice.park_rise = row.rise
			park_cue_log.append({"id": action.id, "at": clock, "scheduled": action.at, "end": clock + voice.end,
				"key": live_key, "pitch": Harmony.ratio(live_key), "db": linear_to_db(voice.gl), "trim_sound": row.trim_sound,
				"voice": row.voice, "cell": action.cell, "owner": action.owner})
			if park_cue_log.size() > 256:
				park_cue_log.pop_front()
		"stinger":
			# Pitched stingers sound in the live key, and a themed one in this level's motif.
			var music: bool = action.get("music", false)
			var live_key: int = key if grid == null else grid.key_at(clock)
			var made_for := int(action.get("step", 0))
			var buf := SfxBank.samples_at(action["id"], made_for if made_for > 0 else step_len, 0 if music or action.get("home", false) else live_key, theme)
			var gain := db_to_linear(SfxBank.trim_db(action["id"]) + float(action["db"]))
			var voice := _start(buf, buf.size(), -1, gain, 0.0, not action["music"])
			if voice != null:
				voice.stinger = action["id"]
			stinger_starts.append([action["id"], clock])
		"restart":
			parameters_stage_entered()
			_dominant_held = false
			_end_escalation_build()
			_reset_escalation()
			_bar_queue.clear()
			_transition = {}
			_lead_octave = 0
			if int(action.get("theme", -1)) >= 0:
				theme = int(action["theme"])
				events_log.append(["theme", clock, theme])
			_set_grid(Harmony.STEP)
			track = "level"
			section = ""
			lounge = false
			_set_key(0)
			_reset_bar()
			_cadence_bar = -1
			_pulse_until = -1
			_drop = {}
			mode = action["mode"]
			if ultimate_lift != _requested_ultimate_lift:
				ultimate_lift = _requested_ultimate_lift
				events_log.append(["ult", clock, ultimate_lift])
			_new_phrase()
			_release_all()
			_retarget()
		"cadence":
			_dominant_held = false
			# The cadence walks home in key 0: a lift or break still queued from the fight
			# would re-key it a bar later. A heft or ultimate lift change is not the fight's
			# and stays queued (the drop keeps the same hazard in mind for "ult").
			_bar_queue = _bar_queue.filter(func(item): return not ((item["set"] as Dictionary).has("key") \
					or (item["set"] as Dictionary).has("section") or (item["set"] as Dictionary).has("esc")))
			_transition = {}
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
				# A menu track's lead outlives the menu's own IDLE (title into class select).
				_release_layers([KICK, SNARE, REESE, ARP, WOB] if track in MENU_TRACKS else [KICK, SNARE, REESE, LEAD, ARP, WOB])
			elif track in MENU_TRACKS:
				track = "level"
				section = ""
				_new_phrase()
				events_log.append(["track", clock, "level:"])
			_retarget()
		"theme":
			theme = int(action["theme"])
			events_log.append(["theme", clock, theme])
			_new_phrase()
		"track":
			var next_track: String = action["track"]
			var next_section: String = action.get("section", "")
			if next_track in ["waking", "mind"]:
				action = action.duplicate()
				action.merge(BOSS_SECTIONS[next_track].get(next_section, {}), true)
			if action.has("step"):
				_set_grid(int(action["step"]))
			track = action["track"]
			section = action.get("section", "")
			lounge = false
			if action.get("play", false):
				mode = PLAY
			_set_key(int(action.get("key", 0)))
			_lead_octave = 0
			_bar_queue.clear()
			_transition = {}
			_end_escalation_build()
			_reset_escalation()
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
				var bass := Synth.note("reese", int(action["bass"]) + 12 + key)
				_start(bass, mini(bass.size(), bar_len() / 3), -1, LEVELS[REESE] * 1.1, 0.0, false)
			events_log.append(["hit", clock, action["drums"]])
		"echo":
			_start_note(action["voice"], int(action["midi"]), 1, ECHO, 0.9, float(action["pan"]))
		"fleet":
			if parameter_source.is_valid():
				_parameter_fleet_pending = int(action["ticks"])
			else:
				fleet_ticks = int(action["ticks"])
				events_log.append(["fleet", clock, fleet_ticks])
		"lounge":
			lounge = bool(action["on"])
			events_log.append(["lounge", clock, lounge])
			_new_phrase()
			_retarget()
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
			var change: Dictionary = action.get("set", {})
			var lap: bool = track == "warden" and _segment_fraction >= 0.0 and not change.get("unseal", false) and int(action.get("theme", -1)) < 0
			var saved_queue := _bar_queue.duplicate(true) if lap else []
			var rest := _warden_rest_section if section == "open" else section
			_dominant_held = false
			_gap = false
			lounge = false
			_build_from = -1
			_build_level = -1.0
			_build_tune = false
			_pending_drop = {}
			_bar_queue.clear()
			_transition = {}
			if not lap:
				_lead_octave = 0
				_reset_escalation()
			var next_theme := int(action.get("theme", -1))
			if next_theme >= 0:
				# A drop into the level is home: D, whatever the fight lifted it to.
				theme = next_theme
				track = "level"
				section = ""
				_set_key(0)
				_set_grid(Harmony.STEP)
				events_log.append(["theme", clock, theme])
			if change.has("step"):
				_set_grid(int(change["step"]))
			if change.has("track"):
				track = change["track"]
				section = change.get("section", section)
			if change.has("key"):
				_set_key(int(change["key"]))
			# The set piece's landing drop releases the meter's lift on its own beat: the drop
			# clears the bar queue, so a release queued for the next bar would be lost.
			if change.has("ult"):
				_requested_ultimate_lift = bool(change["ult"])
				if _requested_ultimate_lift != ultimate_lift:
					ultimate_lift = _requested_ultimate_lift
					events_log.append(["ult", clock, ultimate_lift])
			if track == "warden":
				section = "drop"
				if not lap:
					_set_key(0)
			_reset_bar()
			_drop = {"end_step": int(action["bars"]) * Harmony.STEPS_PER_BAR, "weight": float(action["weight"]), "then": action.get("then", {})}
			if lap:
				_drop.merge({"lap": true, "rest": rest, "queue": saved_queue})
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
	if parameter_source.is_valid():
		grid_origin = clock
	_bar_step = 0
	_step_clock = -1


func _new_phrase() -> void:
	phrase_index += 1
	_lead = _make_track_lead()
	_counter = _make_counter(_lead)
	_class_counter = _make_class_counter()


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
	elif track in BOSS_TRACKS and section == "victory" and _drop.is_empty() and bar >= Harmony.VICTORY.size():
		_run({"type": "track", "track": "level", "section": "", "step": Harmony.STEP})
		mode = IDLE
	# Bar-queued changes: a pickup bar, then the change on the next bar line.
	_transition = {}
	var applied: Array = []
	for item in _bar_queue:
		item["in"] = int(item["in"]) - 1
		if int(item["in"]) <= 0:
			applied.append(item)
		elif int(item["in"]) == 1 and not (item["transition"] as Dictionary).is_empty():
			_transition = item["transition"]
			events_log.append(["transition", clock, item["set"]])
	for item in applied:
		_bar_queue.erase(item)
		var change: Dictionary = item["set"]
		if change.has("key"):
			_set_key(int(change["key"]))
		if change.has("section"):
			if section == "open":
				_warden_rest_section = change["section"]
			else:
				section = change["section"]
			events_log.append(["section", clock, section])
		if change.has("lead_octave"):
			_lead_octave = int(change["lead_octave"])
		if change.has("esc"):
			escalation = change["esc"]
			events_log.append(["esc", clock, escalation])
		if change.has("heft"):
			heft_lift = int(change["heft"])
			events_log.append(["heft", clock, heft_lift])
			_revoice()
			_retarget()
		if change.has("ult") and bool(change["ult"]) != ultimate_lift:
			ultimate_lift = bool(change["ult"])
			events_log.append(["ult", clock, ultimate_lift])
			_retarget()
		_new_phrase()
	# A planned drop counts down its bars and lands on the downbeat.
	if not _pending_drop.is_empty():
		_pending_drop["bars"] = int(_pending_drop["bars"]) - 1
		if int(_pending_drop["bars"]) <= 0:
			var plan := _pending_drop
			_run({"type": "drop", "bars": plan["drop_bars"], "weight": plan["weight"], "set": plan["set"], "then": {}})
	var local := _bar_step / Harmony.STEPS_PER_BAR
	if local % 4 == 0:
		_revoice()
	if track == "miniboss" and local % 2 == 1:
		_riser_into(clock + bar_len())
	if track == "warden" and section == "build" and local % 4 == 3 and not building():
		_riser_into(clock + bar_len())
	if not parameter_source.is_valid():
		applied_pressure = pressure
	_retarget()
	if local % Harmony.PHRASE_BARS == 0:
		_groove = _rng.randi() % 3


# Resolve only the score source; transport and director retain the selected boss id.
func _score_track() -> String:
	return "brindle" if track in BOSS_TRACKS else track


func _floor() -> float:
	if not _drop.is_empty():
		return 1.0
	var score := _score_track()
	var key_name := score if not score in ["warden", "brindle"] else "%s:%s" % [score, section]
	if track == "miniboss":
		key_name = "miniboss"
	return PRESSURE_FLOOR.get(key_name, 0.0)


# Threat, approach and armour schedule their own phrase or flagged-danger commit.
# Shared retarget callers, including calm bay entry/exit (K1), retain their own boundaries.
func _commit_parameters() -> void:
	var previous := _targets.duplicate()
	parameter_committed_values = parameters.duplicate()
	parameter_committed_released = _parameter_released
	parameter_committed_danger_floor = _parameter_danger_floor
	applied_pressure = float(parameter_committed_values.get("threat", 0.0))
	_retarget()
	if previous != _targets or _parameter_logged_fleet != fleet_ticks:
		_parameter_logged_fleet = fleet_ticks
		parameter_layer_log.append({"at": clock, "step": _parameter_step, "phrase_step": _bar_step, "phrase": _parameter_phrase_due,
			"danger": _parameter_danger, "fleet_ticks": fleet_ticks, "targets": Array(_targets), "reads": parameter_layer_reads.duplicate()})
		if parameter_layer_log.size() > 4096:
			parameter_layer_log.pop_front()
	parameter_commit.emit(clock, parameter_committed_values, parameter_committed_released, ultimate_lift, _parameter_danger)


func _retarget() -> void:
	var ultimate_changed := ultimate_lift != _parameter_last_ultimate
	_parameter_last_ultimate = ultimate_lift
	var effective := maxf(applied_pressure, _floor()) if mode == PLAY else applied_pressure
	if parameter_source.is_valid():
		effective = maxf(effective, parameter_committed_danger_floor)
	if mode == PLAY and building():
		effective = maxf(effective, build_level())
	if mode == PLAY:
		effective = minf(1.0, effective + HEFT_STEP * (heft_lift + (1 if ultimate_lift else 0)))
	_intensity = effective
	var gains := layer_gains(effective)
	for layer in gains.size():
		_targets[layer] = gains[layer] * MODE_MASK[mode][layer]
	var warm: float = OVERCHARGE_GAIN[clampi(overcharge, 0, OVERCHARGE_GAIN.size() - 1)]
	if track == "warden" and section == "drop":
		warm = maxf(warm, 0.8)
	_targets[WARM] = warm * MODE_MASK[mode][WARM]
	_targets[WOB] = WOB_DROP_GAIN * MODE_MASK[mode][WOB] if not _drop.is_empty() and track in BOSS_TRACKS else 0.0
	# The sidechain pump is the club: the Warden's build, lift and drop, Brindle's set.
	_pump_depth = 0.0
	if mode == PLAY and _cadence_bar < 0:
		if track == "warden" and section != "break":
			_pump_depth = 0.8 if rules & RULE_DEEP_PUMP else 0.65
		elif track in BOSS_TRACKS:
			_pump_depth = 0.4
	if _lounge_live() and mode == PLAY and _drop.is_empty() and _cadence_bar < 0:
		for layer in LOUNGE_GAINS.size():
			if layer != WARM:
				_targets[layer] = LOUNGE_GAINS[layer]
		_intensity = maxf(LOUNGE_FLOOR, build_level())
	if track == "warden" and section == "open" and mode == PLAY and _cadence_bar < 0:
		for layer in OPEN_GAINS.size():
			_targets[layer] = OPEN_GAINS[layer]
	if track in MENU_TRACKS and mode == IDLE:
		var lost := section == "lost"
		if lost:
			for layer in gains.size():
				_targets[layer] = gains[layer] * MODE_MASK[DEAD][layer]
		_targets[LEAD] = 0.0 if lost else (TITLE_LEAD_GAIN if track == "title" else SUMMARY_LEAD_GAIN)
	_targets[LANDMARK_HUM] = 0.0
	landmark_hum_sound = ""
	if parameter_source.is_valid():
		parameter_layer_reads = {}
		if mode == PLAY:
			if parameter_committed_values.has("approach"):
				parameter_layer_reads["approach"] = true
				landmark_hum_sound = String(EventKinds.world_row("landmark_hum").get("sound", ""))
				if not landmark_hum_sound.is_empty():
					_targets[LANDMARK_HUM] = float(parameter_committed_values.approach)
			var strip := parameter_committed_released
			if parameter_committed_values.has("armour"):
				parameter_layer_reads["armour"] = true
				strip = strip or float(parameter_committed_values.armour) < ARMOUR_STRIP_AT
			if strip:
				for layer in [KEYS, LEAD, ARP, WARM, WOB, PAD, CHOIR, ECHO, COUNTER, FLEET, LANDMARK_HUM]:
					_targets[layer] = 0.0
		if ultimate_changed and not _parameter_phrase_due and _parameter_danger == "":
			parameter_layer_log.append({"at": clock, "step": _parameter_step, "phrase_step": _bar_step, "phrase": false,
				"danger": "", "ultimate": true, "fleet_ticks": fleet_ticks, "targets": Array(_targets), "reads": parameter_layer_reads.duplicate()})
			parameter_commit.emit(clock, parameter_committed_values, parameter_committed_released, ultimate_lift, "ultimate")


func _lounge_live() -> bool:
	return lounge and track == "level"


# Bonus cores this stage. The warm pad swells in on the next bar and stays until the
# stage ends, so an overcharged beacon sounds richer the whole way to the gates.
func set_overcharge(count: int) -> void:
	overcharge = maxi(count, 0)
	_retarget()


func _progression() -> Array:
	match _score_track():
		"miniboss":
			return Harmony.minor_progression(theme)
		"brindle":
			if escalation == "break":
				return Harmony.SINISTER
			match section:
				"victory":
					return Harmony.VICTORY
				"2":
					return Harmony.BRINDLE_PHRYGIAN
			return Harmony.BRINDLE
		"warden":
			if section == "break":
				return Harmony.SINISTER
	if track == "miniboss" and section == "break":
		return Harmony.SINISTER
	return Harmony.level_progression(theme)


func _chord(bar: int) -> Dictionary:
	if _cadence_bar >= 0:
		return Harmony.CADENCE[mini(bar, Harmony.CADENCE.size() - 1)]
	if not _transition.is_empty():
		return _transition["chord"]
	# A launch build sits on the dominant, A7b9, and the landing drop resolves it to
	# D: the rice-cooker cadence, carried by the flight.
	if _build_tune and _build_from >= 0:
		return Harmony.CADENCE[0]
	if _dominant_held:
		return _held_chord()
	var progression := _progression()
	if track in BOSS_TRACKS and section == "victory" and _drop.is_empty():
		return progression[mini(bar, progression.size() - 1)]
	return progression[bar % progression.size()]


# The chord the band will be on at transport sample at, as the bar that sample falls in reads now.
func chord_at(at: int) -> Dictionary:
	var base := _next_step()
	var ahead := maxi(0, floori(float(at - int(base[0])) / step_len))
	return _chord((int(base[1]) + ahead) / Harmony.STEPS_PER_BAR)


func _next_chord(bar: int) -> Dictionary:
	if _dominant_mask_live():
		return _held_chord()
	var progression := _progression()
	return progression[(bar + 1) % progression.size()]


func _voicing(chord: Dictionary) -> Array:
	if _dominant_mask_live():
		return _shift(_held_chord()["voicing"], _chord_key())
	return _shift(chord["voicing"], _chord_key())


func _dominant_mask_live() -> bool:
	return _dominant_held and _cadence_bar < 0 and _transition.is_empty() and not (_build_tune and _build_from >= 0)


func _held_chord() -> Dictionary:
	var chord := Harmony.DOMINANT.duplicate(true)
	chord["name"] = "A7sus4"
	chord["voicing"] = [55, 57, 62, 64]
	chord["tones"] = [57, 62, 64, 67]
	if section == "open" or (_build_from >= 0 and clock >= _build_from + _build_len - beat_len()):
		chord["name"] = "A7b9sus4"
		chord["voicing"].append(58)
		chord["tones"].append(58)
	return chord


# The pickup bar's pivot chord already sounds in the key it leads to.
func _chord_key() -> int:
	if not _transition.is_empty():
		return int(_transition.get("key", key))
	return key


func _make_track_lead() -> Array:
	match _score_track():
		"brindle":
			_lead_voice = BOSS_LEAD_VOICES.get(track, "brass")
			if section == "victory":
				return VICTORY_LEAD
			if section == "chase":
				return make_lead(phrase_index, MOTIF, Harmony.BRINDLE, 73)
			var quote := {"1": 2, "2": 1, "3": 0}.get(section, 0) as int
			return make_lead(phrase_index, [MOTIF, MOTIF_SLUICE, MOTIF_WEIR][quote], _progression(), 73)
		"title":
			_lead_voice = LEAD_VOICE[0]
			return MOTIF
		"summary":
			_lead_voice = "brass"
			return VICTORY_LEAD if section == "won" else []
		_:
			var progression := _progression()
			if _lounge_live():
				_lead_voice = "sax_lounge"
				return make_lounge_lead(phrase_index, [MOTIF, MOTIF_SLUICE, MOTIF_WEIR][theme], progression, [1] if theme == 2 else [0, 1])
			_lead_voice = LEAD_VOICE[theme]
			match theme:
				1:
					return make_lead(phrase_index, MOTIF_SLUICE, progression, 73)
				2:
					return make_lead(phrase_index, MOTIF_WEIR, progression, -1, [1])
			return make_lead(phrase_index, MOTIF, progression, 73)


# --- Arrangements -------------------------------------------------------------------

# Spillway: drum and bass. Also plays every cadence.
func _trigger_dnb(bar: int, s: int, chord: Dictionary) -> void:
	_rule_accents(s, chord)
	var cadence := _cadence_bar >= 0
	var phrase_bar := bar % Harmony.PHRASE_BARS
	var busy := _intensity >= 0.3 and mode == PLAY
	# Keys: a held chord when calm, syncopated stabs once the pressure is up.
	var stabs: Dictionary = {0: 16} if not busy or (cadence and bar == 1) else ([{0: 3, 6: 2, 10: 4}, {0: 2, 3: 2, 8: 3, 14: 2}, {0: 3, 6: 2, 10: 4}][_groove])
	if stabs.has(s):
		_release_layers([KEYS])
		var buf := Synth.chord(_voicing(chord))
		_start(buf, mini(buf.size(), int(stabs[s]) * step_len + RELEASE), KEYS, LEVELS[KEYS], 0.0, false)
	_sub_and_pad(s, chord)
	# Hats: eighths, then sixteenths under pressure, with an open hat to lift bar ends.
	if s % 2 == 0 or _intensity >= 0.4:
		var accent := 1.0 if s % 4 == 2 else (0.55 if s % 2 == 0 else 0.35)
		_hit("hat", HATS, accent, 0.25)
	if s == 14 and _intensity >= 0.5:
		_hit("open_hat", HATS, 0.7, 0.25)
	# Kick: half-time when calm, the two-step once the pressure is up.
	var kicks := [0, 10] if _intensity >= 0.35 or cadence else [0]
	if _groove == 1 and _intensity >= 0.35:
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
		if (phrase_bar == 7 or cadence) and s >= 8 and s != 12 and (s % 2 == 0 or _intensity >= 0.6):
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
	_melodic(bar, s, chord, "bell")


# Sluice: funk. The clav riff calls, the brass answers, the groove is a machine.
func _trigger_funk(bar: int, s: int, chord: Dictionary) -> void:
	var phrase_bar := bar % Harmony.PHRASE_BARS
	var busy := _intensity >= 0.3 and mode == PLAY
	var voicing := _voicing(chord)
	var riff := CLAV_BUSY if busy else CLAV_CALM
	if riff.has(s):
		var midi: int = voicing[int(riff[s]) % voicing.size()] + (12 if s % 4 == 2 else 0)
		var clav := Synth.note("clav", midi)
		_start(clav, mini(clav.size(), step_len + RELEASE), KEYS, LEVELS[KEYS] * 1.1, -0.3 if s % 2 == 0 else 0.3, false)
	if _intensity >= 0.35 and (s == 6 or s == 14):
		var stab := Synth.stab_chord(voicing, true)
		_start(stab, mini(stab.size(), 2 * step_len + RELEASE), KEYS, LEVELS[KEYS] * 0.9, 0.15, false)
	_sub_and_pad(s, chord)
	if busy or s % 2 == 0:
		_hit("hat", HATS, 0.85 if s % 4 == 1 or s % 4 == 3 else 0.45, 0.3)
	if (s == 7 or s == 15) and _intensity >= 0.5:
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
	_melodic(bar, s, chord, "clav")


# Weir: the halfpipe. Organ, a half-time roll, a bass that climbs and falls with the
# chords, and the talkbox.
func _trigger_halfpipe(bar: int, s: int, chord: Dictionary) -> void:
	var phrase_bar := bar % Harmony.PHRASE_BARS
	var busy := _intensity >= 0.3 and mode == PLAY
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
	if _intensity >= 0.6 and s == 12:
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
	_melodic(bar, s, chord, "bell")


# The Warden: the level rebuilt as club music. Four on the floor, funk bass, filtered
# stabs, a pump under every kick; the build waits for the drop.
func _trigger_house(bar: int, s: int, chord: Dictionary) -> void:
	# Round 2's club, as Andrew heard it: four on the floor, claps, open hats, the funk
	# octave bass, a sidechain pump, and filtered jazzy stabs, dark in the build and
	# bright in the drop. The lift (half broken) adds a snare to the clap, the lead an
	# octave up and the arp; the drop adds a crash every four bars and the full layers.
	var drop := section == "drop"
	var lifted := section == "lift"
	var open := section == "open"
	var phrase_bar := bar % Harmony.PHRASE_BARS
	if not open:
		_rule_accents(s, chord)
	if not open and s % 4 == 0:
		_hit("kick", KICK, 1.0, 0.0)
	if not open and (s == 4 or s == 12):
		_hit("clap", SNARE, 1.0, 0.1)
		if drop or lifted:
			_hit("snare", SNARE, 0.5, -0.1)
	if not open and not drop and phrase_bar % 4 == 3 and s >= 8:
		_hit("snare", SNARE, 0.3 + 0.08 * (s - 8), 0.0)
	if open:
		_hit("hat", HATS, 1.0 if s % 4 == 2 else 0.55, 0.25)
	elif s % 4 == 2:
		_hit("open_hat", HATS, 0.8, 0.25)
	elif s % 2 == 1:
		_hit("hat", HATS, 0.35, -0.25)
	if drop and s == 0 and phrase_bar % 4 == 0:
		_hit("crash", HATS, 1.0, -0.2)
	if drop and s == 0 and bar == 0:
		_hit("boom", KICK, 1.0, 0.0)
	var root: int = chord["root"]
	if HOUSE_BASS.has(s):
		_bass("fbass", root + int(HOUSE_BASS[s][0]), int(HOUSE_BASS[s][1]), 1.3)
	if s == 0:
		_start_sub(root, 0.8)
	# Under the funk bass, the level's own bass figure (round 3) on the reese, softer.
	var figure: Dictionary = [DNB_CALM, FUNK_CALM, WEIR_CALM][theme]
	if figure.has(s):
		_start_note("reese", root + 12 + int(figure[s][0]), int(figure[s][1]), SUB, 0.45, 0.0)
	if s in [2, 6, 10, 13]:
		var stab := Synth.stab_chord(_voicing(chord), drop or lifted)
		_start(stab, mini(stab.size(), step_len + RELEASE), KEYS, LEVELS[KEYS] * 1.1, 0.2 if s % 4 == 2 else -0.2, false)
	# Each level's own voice on the club, added over it: Sluice's clav on the offbeat
	# sixteenths, Weir's gospel organ chopped on the ands. Spillway's is the sax lead.
	var voicing := _voicing(chord)
	if theme == 1 and s in [3, 7, 11, 15]:
		var clav := Synth.note("clav", int(voicing[(s / 4) % voicing.size()]) + 12)
		_start(clav, mini(clav.size(), step_len + RELEASE), KEYS, LEVELS[KEYS] * (1.0 if drop or lifted else 0.7), 0.35, false)
	if theme == 2 and s in [4, 12]:
		var organ := Synth.organ_chord(voicing)
		_start(organ, mini(organ.size(), 2 * step_len + RELEASE), KEYS, LEVELS[KEYS] * (0.8 if drop or lifted else 0.55), -0.25, false)
	if s == 0 and (_targets[WARM] > 0.0 or _gains[WARM] > 0.0):
		var pad := Synth.pad_chord(voicing)
		_start(pad, mini(pad.size(), 16 * step_len + RELEASE), WARM, LEVELS[WARM], 0.0, false)
	if drop:
		_melodic(bar, s, chord, "bell")
	elif lifted:
		_play_lead(phrase_bar, s)
		_arp(bar, s, chord, "bell")
	elif _dominant_held and not open:
		_arp(bar, s, chord, "bell")


# Each rule adds at most one accent per bar. The second clap answers beat four
# one sixteenth later; the brass uses the existing Fleet layer and live harmony.
func _rule_accents(s: int, chord: Dictionary) -> void:
	if rules & RULE_DOUBLE_CLAP and s == 13:
		_hit("clap", SNARE, 0.7, -0.1)
	if rules & RULE_FLEET_ANSWER and s == 12:
		_start_note("brass", int(chord["root"]) + 24, 2, FLEET, 0.8, 0.25)


# The Warden at three quarters broken: half time, the bass walking the tritone, the
# melody leaning on the flat second, dark stabs; the build tightens with every hit.
func _trigger_break(bar: int, s: int, chord: Dictionary) -> void:
	var phrase_bar := bar % Harmony.PHRASE_BARS
	if s == 0 or (s == 10 and bar % 2 == 1):
		_hit("kick", KICK, 1.0, 0.0)
	if s == 0 and bar % 4 == 0:
		_hit("boom", KICK, 0.8, 0.0)
	if s == 8:
		_hit("snare", SNARE, 1.0, 0.0)
		_hit("clap", SNARE, 0.8, 0.1)
	if s % 4 == 2:
		_hit("hat", HATS, 0.5, 0.25)
	var root: int = chord["root"]
	if s == 0:
		_start_sub(root, 1.0)
		var stab := Synth.stab_chord(_voicing(chord), false)
		_start(stab, stab.size(), KEYS, LEVELS[KEYS] * 1.2, 0.0, false)
		_bass("reese", root + 12, 8, 1.0)
	elif s == 8:
		_bass("reese", root + 12 + 6, 6, 0.9)
	elif s == 14:
		_bass("fbass", root + 12, 2, 1.0)
	_play_lead(phrase_bar, s)
	_choir(bar, s, chord)


# A drop's payoff is the full layered texture plus the bass. A landing drops back
# into the stage's own theme with every layer in and a crash; the Warden drops into
# round 2's bright club drop; Brindle's drops are the same funk club with his anvils
# and a restrained wobble.
func _trigger_drop(bar: int, s: int, chord: Dictionary) -> void:
	var weight: float = _drop["weight"]
	var root: int = chord["root"]
	if track == "warden":
		_trigger_house(bar, s, chord)
		return
	if not track in BOSS_TRACKS:
		if s == 0 and (bar == 0 or bar % 4 == 0):
			_hit("crash", HATS, 1.0, -0.2)
		if s == 0 and bar == 0:
			_hit("boom", KICK, 0.9, 0.0)
		match theme:
			1:
				_trigger_funk(bar, s, chord)
			2:
				_trigger_halfpipe(bar, s, chord)
			_:
				_trigger_dnb(bar, s, chord)
		return
	if s % 4 == 0:
		_hit("kick", KICK, 1.0, 0.0)
	if s == 0 and (bar % 4 == 0 or weight >= 1.1):
		_hit("crash", HATS, 1.0, -0.2)
	if s == 0 and bar == 0:
		_hit("boom", KICK, 1.0, 0.0)
	if s == 4 or s == 12:
		_hit("clap", SNARE, 1.0, 0.1)
		_hit("snare", SNARE, 0.5, -0.1)
	if s == 6 or s == 14:
		_hit("anvil", SNARE, 0.7, -0.35 if s == 6 else 0.35)
	if s % 4 == 2:
		_hit("open_hat", HATS, 0.8, 0.25)
	elif s % 2 == 1:
		_hit("hat", HATS, 0.35, -0.25)
	if HOUSE_BASS.has(s):
		_bass("fbass", root + int(HOUSE_BASS[s][0]), int(HOUSE_BASS[s][1]), 1.3)
	if s == 0:
		_start_note("sub", root, 16, SUB, 1.0, 0.0)
	if s in [2, 6, 10, 13]:
		var stab := Synth.stab_chord(_voicing(chord), true)
		_start(stab, mini(stab.size(), step_len + RELEASE), KEYS, LEVELS[KEYS] * 1.1, 0.2 if s % 4 == 2 else -0.2, false)
	_wobble(bar, s, chord, DROP_RATES, "wub", 8, 1.0)
	_melodic(bar, s, chord, "bell")


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
	# Each phase adds layers (its pressure floor rises); no wobble outside the drops.
	_melodic(bar, s, chord, "bell")


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


# Moss's lounge: the stage theme re-voiced, same grid, half the feel. Brushes and a
# ride instead of kick and hats, the snare only on beat 3, the calm bass figure on the
# clean sub, keys on beats 1 and 3, the pad, and the sax at half speed. Sluice keeps its
# clav and Weir its organ, quietly.
func _trigger_lounge(bar: int, s: int, chord: Dictionary) -> void:
	var voicing := _voicing(chord)
	if s == 0 or s == 8:
		_release_layers([KEYS])
		var keys := Synth.chord(voicing)
		_start(keys, mini(keys.size(), 7 * step_len + RELEASE), KEYS, LEVELS[KEYS], 0.0, false)
		if theme == 1:
			var clav := Synth.note("clav", int(voicing[1]) + 12)
			_start(clav, mini(clav.size(), step_len + RELEASE), KEYS, LEVELS[KEYS] * 0.35, -0.3, false)
	if theme == 2 and s == 0:
		var organ := Synth.organ_chord(voicing)
		_start(organ, mini(organ.size(), 16 * step_len + RELEASE), KEYS, LEVELS[KEYS] * 0.3, 0.2, false)
	if s == 0:
		_start_sub(chord["root"], 1.0)
	if s % 4 == 0:
		_hit("brush", SNARE, 0.8 if s % 8 == 0 else 0.5, 0.25)
	if s in [0, 8, 14]:
		_hit("ride", SNARE, 0.3 if s == 14 else 0.45, -0.3)
	if s == 8:
		_hit("snare", SNARE, 0.3, 0.05)
	var figure: Dictionary = [DNB_CALM, FUNK_CALM, WEIR_CALM][theme]
	if figure.has(s):
		_bass("sub", int(chord["root"]) + 12 + int(figure[s][0]), int(figure[s][1]), 0.9)
	_melodic(bar, s, chord, "bell")


# The Fleet borrows Brindle's anvil and brass, one layer per difficulty tick: the anvil
# on beats 2 and 4 under the kick, then the brass semitone lean (root, a half step up,
# root) answering the lead in the second half of the bar, then the anvil on every beat.
func _fleet_layer(s: int, chord: Dictionary) -> void:
	if (fleet_ticks >= 3 and s % 4 == 0) or s == 4 or s == 12:
		_hit("anvil", FLEET, 1.3 if s == 4 or s == 12 else 1.0, -0.3 if s < 8 else 0.3)
	if fleet_ticks < 2:
		return
	var root: int = int(chord["root"]) + 12
	var lean := {8: [0, 2], 10: [1, 2], 12: [0, 3]}
	if lean.has(s):
		_start_note("brass", root + int(lean[s][0]), int(lean[s][1]), FLEET, 1.1, 0.25)
		_start_note("brass", root + 12 + int(lean[s][0]), int(lean[s][1]), FLEET, 0.45, 0.25)


# --- Pieces every arrangement shares ------------------------------------------------------

func _sub_and_pad(s: int, chord: Dictionary) -> void:
	if s != 0:
		return
	_start_sub(chord["root"], 1.0)
	if _targets[WARM] > 0.0 or _gains[WARM] > 0.0:
		var pad := Synth.pad_chord(_voicing(chord))
		_start(pad, mini(pad.size(), 16 * step_len + RELEASE), WARM, LEVELS[WARM], 0.0, false)


# The bar's held sub: the chord root, or while a reactor vent charges the Ab pedal on
# the tritone (and its octave, quieter) under whatever the bass figure plays.
func _start_sub(root: int, gain: float) -> void:
	if not reactor_pedal:
		_start_note("sub", root, 16, SUB, gain, 0.0)
		return
	var cells: Array = Harmony.motif("reactor")["cells"]
	_start_note("sub", int(cells[0][1]), 16, SUB, gain, 0.0)
	_start_note("sub", int(cells[1][1]), 16, SUB, gain * 0.3, 0.0)


# A bass-figure note: it cuts the previous one, so the riff stays tight.
func _bass(instrument: String, midi: int, steps: int, gain: float) -> void:
	bass_log[instrument] = int(bass_log.get(instrument, 0)) + 1
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
	if s < maxi(from_step, 0):
		return
	var rate: String = rates[bar % rates.size()]
	var count: int = RATES[rate]
	var beat := beat_len()
	var root: int = chord["root"]
	var midi := root + _chord_key()
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
			var midi: int = int(event[1]) + _lead_octave
			while midi > 86:
				midi -= 12
			if (section == "break" or escalation == "break") and at % 4 == 0 and posmod(midi - Harmony.HOME, 12) == 0:
				# The flat second leans on the root on strong beats.
				midi += 1
			_start_note(_lead_voice, midi, event[2], LEAD, 1.0, 0.1)
			# The chopped echo: each lead note comes back a dotted eighth later, cut
			# short and pitched up, on the rotation's voice.
			if _on(ECHO):
				var rot := _rotation_state()
				var voice: String = rot.get("echo_voice", ECHO_VOICES[theme][int(rot["echo"])])
				_add_action(clock + 3 * step_len, {"type": "echo", "voice": voice, "midi": int(event[1]) + int(rot["shift"]), "pan": -0.35 if event[0] % 8 < 4 else 0.35})
			if track == "miniboss":
				_start_note(_lead_voice, event[1] + 12, event[2], LEAD, 0.4, -0.1)


func _arp(bar: int, s: int, chord: Dictionary, instrument: String) -> void:
	if not _on(ARP):
		return
	if s % 2 == 0 or _intensity >= 0.9:
		var rot := _rotation_state()
		var tones: Array = chord["voicing"]
		var pattern: Array = ARP_SHAPES[int(rot["arp"])]
		var midi: int = tones[int(pattern[(s / 2 + bar % Harmony.PHRASE_BARS) % pattern.size()]) % tones.size()] + int(rot["arp_oct"])
		_start_note(instrument, midi, 2, ARP, 0.8, 0.45 if s % 4 == 0 else -0.45)


# The pickup bar before a key change: a snare run that climbs into the change.
func _fill(s: int) -> void:
	if s >= 8:
		_hit("snare", SNARE, 0.35 + 0.08 * (s - 8), 0.0)
	if s == 12:
		_hit("open_hat", HATS, 0.7, 0.2)


# The layered top every arrangement shares: the pad, the choir, the lead with its
# chopped echo, the counter-line and the arpeggiator. Silent layers trigger nothing.
func _melodic(bar: int, s: int, chord: Dictionary, arp_instrument: String) -> void:
	var phrase_bar := bar % Harmony.PHRASE_BARS
	# The title's theme comes round once a menu phrase; the won summary's line plays once.
	if track in MENU_TRACKS:
		phrase_bar = bar % MENU_PHRASE_BARS if track == "title" else bar
	if s == 0 and _on(PAD):
		var pad := Synth.pad_chord(_voicing(chord))
		_start(pad, mini(pad.size(), 16 * step_len + RELEASE), PAD, LEVELS[PAD], 0.0, false)
	_choir(bar, s, chord)
	_play_lead(phrase_bar, s)
	_play_counter(phrase_bar, s)
	_arp(bar, s, chord, arp_instrument)


func _on(layer: int) -> bool:
	return _targets[layer] > 0.001 or _gains[layer] > 0.001


# The choir sings twice a bar: either the chord's guide tones (top voice, then an
# inner voice), or the lead's call from two bars back, answered in the current chord
# (one line's fragment answering another).
func _choir(bar: int, s: int, chord: Dictionary) -> void:
	if not _on(CHOIR) or (s != 0 and s != 8):
		return
	var rot := _rotation_state()
	var tones: Array = chord["voicing"]
	var midi: int = int(tones[3 if s == 0 else 1]) + 12
	if rot["choir"] == "answer":
		var at := posmod((bar % Harmony.PHRASE_BARS) * Harmony.STEPS_PER_BAR + s - 32, 128)
		var heard := -1
		for event in _lead:
			if int(event[0]) <= at:
				heard = int(event[1])
		if heard > 0:
			midi = Harmony.nearest_tone(heard, chord["tones"])
	while midi > 79:
		midi -= 12
	while midi < 62:
		midi += 12
	if s == 0:
		_release_layers([CHOIR])
	_start_note("choir_" + String(rot["vowel"]), midi, 8, CHOIR, 1.0, -0.25 if s == 0 else 0.25)


func _play_counter(phrase_bar: int, s: int) -> void:
	if not _on(COUNTER):
		return
	var at := phrase_bar * Harmony.STEPS_PER_BAR + s
	var rot := _rotation_state()
	var voice: String = rot["counter"]
	var line := _counter
	var gain := 1.0
	var seeded: bool = not _class_counter.is_empty() and (rot.get("class_counter", false) or _rotation % ROTATIONS.size() == CLASS_ROTATION)
	if seeded:
		line = _class_counter
		voice = rot["counter"] if rot.get("class_counter", false) else Harmony.motif(class_motif)["band"]
		gain = CLASS_COUNTER_GAIN
	for event in line:
		if event[0] == at:
			_release_layers([COUNTER])
			var steps: int = int(event[2]) if seeded or voice == "keys" else mini(int(event[2]), 2)
			_start_note(voice, int(event[1]) + int(rot.get("counter_oct", 0)), steps, COUNTER, gain, -0.3)
			if seeded and rot.get("counter_boom", false):
				_start_note("sub", int(event[1]) - 24, steps, COUNTER, gain * 0.35, 0.0)


# The counter-line: the lead's own call, two bars late and a third lower, refitted to
# the chord it now lands on. Call over call: the lead answers while the counter calls.
func _make_counter(lead: Array) -> Array:
	var progression := _progression()
	var out: Array = []
	for event in lead:
		var step := (int(event[0]) + 32) % 128
		var chord: Dictionary = progression[(step / 16) % progression.size()]
		var midi := Harmony.scale_shift(int(event[1]), -2, Harmony.DORIAN)
		midi = Harmony.nearest_tone(midi, chord["tones"]) if step % 4 == 0 else Harmony.snap(midi, chord["scale"])
		while midi > 79:
			midi -= 12
		while midi < 57:
			midi += 12
		out.append([step, midi, event[2]])
	out.sort_custom(func(a: Array, b: Array): return a[0] < b[0])
	return out


# The class motif on the counter-line: once per two-bar call, ending just before the
# next call, moved to the chord tone nearest its first note and snapped into that
# chord's scale, so its shape survives and it never clashes.
func _make_class_counter() -> Array:
	var row := Harmony.motif(class_motif)
	if row.get("family", "") != "class":
		return []
	var cells: Array = row["cells"]
	var last: Array = cells[cells.size() - 1]
	var span: int = int(last[0]) + int(last[2])
	var octave: int = row.get("band_octave", 0)
	var progression := _progression()
	var out: Array = []
	for k in 4:
		var start := 32 * k + 30 - span
		var chord: Dictionary = progression[(start / 16) % progression.size()]
		var first: int = int(cells[0][1]) + octave
		var shift := Harmony.nearest_tone(first, chord["tones"]) - first
		for cell in cells:
			out.append([start + int(cell[0]), Harmony.snap(int(cell[1]) + octave + shift, chord["scale"]), int(cell[2])])
	return out


# Every four bars the lines trade voices, so the texture keeps evolving.
func _revoice() -> void:
	_rotation += 1
	var rot := _rotation_state()
	events_log.append(["revoice", clock, "echo:%s+%d counter:%s choir:%s/%s arp:%d" % [ECHO_VOICES[theme][int(rot["echo"])], rot["shift"], rot["counter"], rot["choir"], rot["vowel"], rot["arp"]]])


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
	_build_riser = _start(buf, buf.size(), DRY, db_to_linear(SfxBank.trim_db("build_riser")), 0.0, false)


# Pitched notes follow the key.
func _start_note(instrument: String, midi: int, steps: int, layer: int, gain: float, pan: float) -> void:
	if _dominant_mask_live() and layer in [LEAD, ECHO, COUNTER, ARP, CHOIR]:
		midi = Harmony.nearest_tone(midi, _held_chord()["tones"])
	var buf := Synth.note(instrument, midi + _chord_key())
	_start(buf, mini(buf.size(), steps * step_len + RELEASE), layer, gain * LEVELS[layer], pan, false)


# Drums. Inside the transition bar the half-note triplet pulse replaces kick and snare.
func _hit(instrument: String, layer: int, gain: float, pan: float) -> void:
	if (layer == KICK or layer == SNARE) and clock >= _pulse_from and clock < _pulse_until:
		return
	var buf := Synth.drum(instrument)
	_start(buf, buf.size(), layer, gain * LEVELS[layer], pan, false)


func _start(buf: PackedFloat32Array, length: int, layer: int, gain: float, pan: float, to_stinger: bool) -> Voice:
	if band_muted and not to_stinger and layer != LANDMARK_HUM:
		return null
	var band_count := 0
	if not to_stinger:
		var oldest: Voice
		for playing: Voice in _voices:
			if playing.to_stinger:
				continue
			band_count += 1
			if oldest == null and playing.layer == layer and layer not in BASS_LAYERS:
				oldest = playing
		if band_count >= BAND_VOICE_CAP:
			# If this layer has no stealable note, decline rather than steal bass or
			# another layer. The ordinary dense arrangement has measured headroom.
			if oldest == null:
				band_voice_rejections += 1
				return null
			_voices.erase(oldest)
			band_voice_steals += 1
			if oldest == _build_riser:
				_build_riser = null
			band_count -= 1
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
	if not to_stinger:
		band_voice_peak = maxi(band_voice_peak, band_count + 1)
	return voice


func _release_layers(layers: Array) -> void:
	for voice in _voices:
		if voice.layer in layers:
			voice.end = mini(voice.end, voice.pos + RELEASE)


func _release_all() -> void:
	for voice in _voices:
		if voice.layer >= 0:
			voice.end = mini(voice.end, voice.pos + RELEASE)


# --- Mixing ---------------------------------------------------------------------------

# The sidechain envelope at a sample: down fast under the kick, holds a short pocket
# for the kick body, and breathes back smoothly by two-thirds of the beat.
func _pump_at(sample: int) -> float:
	if _pump_depth <= 0.0:
		return 1.0
	var beat := beat_len()
	var pos := posmod(sample - grid_origin, beat)
	var low := 1.0 - _pump_depth
	if pos < PUMP_ATTACK:
		return lerpf(1.0, low, float(pos) / PUMP_ATTACK)
	var hold := int(beat * PUMP_HOLD_FRAC)
	if pos < hold:
		return low
	var x := clampf(float(pos - hold) / maxf(beat * 0.68 - hold, 1.0), 0.0, 1.0)
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
		if bot_skip_samples:
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
		if voice.mono and not voice.to_stinger and voice.layer not in [DRY, LANDMARK_HUM]:
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
			var left := _sl if voice.to_stinger else (_hl if voice.layer == LANDMARK_HUM else (_dl if voice.layer == DRY else _left))
			var right := _sr if voice.to_stinger else (_hr if voice.layer == LANDMARK_HUM else (_dr if voice.layer == DRY else _right))
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
	if band_muted:
		return
	# The duck envelope, the silence gate and the build's high-pass, per sub-block.
	if clock >= _duck_until:
		_duck_target = 1.0
	var duck_from := _duck
	var rate: float = float(n) / (DUCK_RELEASE if _duck_target > _duck else 400.0)
	_duck = move_toward(_duck, _duck_target, rate)
	var gate_from := _gate
	_gate = move_toward(_gate, 0.0 if _gap else 1.0, float(n) / 96.0)
	var level := master * pause_gain
	# The tone filter follows intensity, and a build closes it and opens it again.
	var target := TONE_CALM_HZ if _lounge_live() else lerpf(TONE_CALM_HZ, TONE_OPEN_HZ, smoothstep(0.0, 0.7, _intensity))
	if track == "warden" and section == "open":
		target = TONE_OPEN_HZ
	elif _build_from >= 0 or _build_level >= 0.0:
		var b := build_level()
		target = minf(target, lerpf(BUILD_LOW_HZ, TONE_OPEN_HZ, b * b))
	_cutoff = lerpf(_cutoff, target, minf(1.0, float(n) / 2048.0))
	if bot_skip_samples:
		return
	if _cutoff < TONE_OPEN_HZ * 0.95:
		# Two one-pole low-passes per side.
		var a := 1.0 - exp(-TAU * _cutoff / Harmony.RATE)
		var h := _lp
		if not _lp_on:
			# Re-engaging: start from the signal, not from stale state, so it never clicks.
			_lp_on = true
			h[0] = _left[offset] + _mid[offset]
			h[1] = h[0]
			h[2] = _right[offset] + _mid[offset]
			h[3] = h[2]
		for i in n:
			var d := (duck_from + (_duck - duck_from) * i * inv_n) * level * (gate_from + (_gate - gate_from) * i * inv_n)
			var m := _mid[offset + i]
			h[0] += a * (_left[offset + i] + m - h[0])
			h[1] += a * (h[0] - h[1])
			h[2] += a * (_right[offset + i] + m - h[2])
			h[3] += a * (h[2] - h[3])
			_left[offset + i] = (h[1] + _dl[offset + i]) * d
			_right[offset + i] = (h[3] + _dr[offset + i]) * d
	else:
		_lp_on = false
		for i in n:
			var d := (duck_from + (_duck - duck_from) * i * inv_n) * level * (gate_from + (_gate - gate_from) * i * inv_n)
			var m := _mid[offset + i]
			_left[offset + i] = (_left[offset + i] + m + _dl[offset + i]) * d
			_right[offset + i] = (_right[offset + i] + m + _dr[offset + i]) * d


func _finish(frames: int) -> void:
	if bot_skip_samples:
		return
	for i in frames:
		out_landmark[i] = Vector2(_hl[i], _hr[i]) * master * pause_gain
	if band_muted:
		out_music.fill(Vector2.ZERO)
	else:
		for i in frames:
			var l := _left[i] + out_landmark[i].x
			var r := _right[i] + out_landmark[i].y
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


# The lounge phrase: the stage motif at half speed, then its answer (inversion or
# retrograde), fitted to the same eight bars of chords.
static func make_lounge_lead(index: int, motif: Array, progression: Array, answers := [0, 1]) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260927 + index * 7919
	var slow: Array = []
	for cell in motif:
		slow.append([int(cell[0]) * 2, int(cell[1]), int(cell[2]) * 2])
	var notes: Array = _place(slow, 0)
	notes.append_array(_place(_answer(slow, answers[rng.randi() % answers.size()], 0), 64))
	var fitted: Array = []
	for event in notes:
		var step: int = event[0]
		if step >= 128:
			continue
		var chord: Dictionary = progression[(step / 16) % progression.size()]
		var midi: int = event[1]
		midi = Harmony.nearest_tone(midi, chord["tones"]) if step % 4 == 0 else Harmony.snap(midi, chord["scale"])
		while midi < 62:
			midi += 12
		while midi > 81:
			midi -= 12
		fitted.append([step, midi, mini(event[2], 128 - step)])
	if not fitted.is_empty():
		var last: Array = fitted[fitted.size() - 1]
		last[1] = Harmony.nearest_tone(last[1], progression[(int(last[0]) / 16) % progression.size()]["tones"])
	return fitted


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
