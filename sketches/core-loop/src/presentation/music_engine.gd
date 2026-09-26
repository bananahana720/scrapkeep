extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

# The band. A sample-exact sequencer that mixes pre-rendered notes from synth.gd on a
# grid it can re-tempo. It knows nothing about the game: the audio director tells it
# the pressure, the mode, the level theme, when a boss arrives and which stingers to
# play, and it renders blocks of stereo frames on demand. render(n) is pure over its
# own state, so the tests drive it without a sound card.
#
# Every track shares one harmonic language, jazzy extended chords with D as home, so
# the reward ladder in the cues is in key whatever is playing:
#   Spillway  D Dorian drum and bass: electric piano, reese, the sax lead.
#   Sluice    funk: a clavinet riff, brass stabs and hook, a mechanical groove.
#   Weir      the halfpipe: organ and a talkbox lead that climbs and rolls back.
#   Miniboss  the level darkened: minor chords, a doubled lead, a riser every 2 bars.
#   Warden    the level as four-on-the-floor club music at 129: funk bass, sidechain
#             pump, filtered stabs; beacon_unsealed hits the drop.
#   Brindle   his own set: brass fanfare, anvil and industrial drums, a dramatic
#             mode; each phase quotes a level motif, and the victory resolves home.
#
# Layers enter with pressure (0..1): calm leaves space; pressure brings the kick up,
# then snare and ride, the bass, the lead and a bell arpeggio. Boss tracks hold a
# pressure floor. New pressure takes effect on the next bar. Stingers start on the
# next beat; flow stingers queue in one lane so they never talk over each other.

enum { KEYS, SUB, HATS, KICK, SNARE, REESE, LEAD, ARP, WARM }
const LAYER_NAMES := ["keys", "sub", "hats", "kick", "snare", "reese", "lead", "arp", "warm"]
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
const LEVELS := [0.34, 0.5, 0.22, 0.62, 0.42, 0.3, 0.36, 0.14, 0.3]
# The warm layer is not pressure: it is the overcharge, one step per bonus core.
const OVERCHARGE_GAIN := [0.0, 0.7, 1.0]

enum { IDLE, PLAY, DEAD }
const MODE_NAMES := ["idle", "play", "dead"]
# What each mode lets through, per layer: menus keep the keys and sub, death keeps
# the keys alone, so the band waits with you instead of stopping.
const MODE_MASK := [
	[1.0, 0.7, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	[1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
	[0.6, 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
]

const RELEASE := 600
const DUCK_RELEASE := Harmony.BEAT
const RISER_SPACING := Harmony.BAR * 4
# Boss tracks move to 129 by metric modulation unless Andrew picks "held at 172".
const BOSS_PIVOT_DEFAULT := true
# The sidechain pump: the pumped layers dip under each kick and breathe back.
const PUMP_ATTACK := 400
const PUMPED := [KEYS, SUB, REESE, LEAD, ARP, WARM]
const PRESSURE_FLOOR := {"level": 0.0, "miniboss": 0.8, "warden:build": 0.55, "warden:drop": 1.0, "brindle": 1.0}
const LEAD_VOICE := ["lead", "brass", "talk"]

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
const FUNK_BASS := {0: [0, 2], 2: [12, 1], 3: [0, 1], 6: [7, 1], 7: [10, 1], 8: [12, 1], 10: [0, 2], 12: [12, 1]}
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
var boss_pivot := BOSS_PIVOT_DEFAULT
# [what, sample, detail] for every tempo, theme, track and pulse change, for the tests.
var events_log: Array = []

var _gains := PackedFloat32Array()
var _targets := PackedFloat32Array()
var _voices: Array = []
var _actions: Array = []
var _last_step_at := -1
var _lead: Array = []
var _lead_voice := "lead"
var _cadence_bar := -1
var _cadence_then := {}
var _groove := 0
var _duck := 1.0
var _duck_target := 1.0
var _duck_until := 0
var _last_riser := -RISER_SPACING
var _pulse_from := -1
var _pulse_until := -1
var _pump_depth := 0.0
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
	_lead = _make_track_lead()


# Spillway and the cadence: what the title and stage 1 need. Rendered before the
# music starts.
static func prepare() -> void:
	_prepare_chords(Harmony.PROGRESSION + Harmony.CADENCE + [Harmony.MINOR_OF["G13"], Harmony.MINOR_OF["Cmaj9"], Harmony.MINOR_OF["Bbmaj9"]], ["lead"])
	for drum in Synth.DRUMS:
		Synth.drum(drum)


# The other themes and the boss tracks. Rendered on a background worker while stage 1
# plays; anything asked for before it lands renders on demand.
static func prepare_rest() -> void:
	var chords: Array = []
	for list in [Harmony.SLUICE, Harmony.WEIR, Harmony.BRINDLE, Harmony.VICTORY, Harmony.MINOR_OF.values()]:
		chords.append_array(list)
	_prepare_chords(chords, ["brass", "talk"])
	for list in [Harmony.WEIR, Harmony.BRINDLE, Harmony.MINOR_OF.values()]:
		for chord in list:
			Synth.organ_chord(chord["voicing"])
	for list in [Harmony.PROGRESSION, Harmony.SLUICE, Harmony.WEIR, Harmony.BRINDLE, Harmony.VICTORY]:
		for chord in list:
			Synth.stab_chord(chord["voicing"], false)
			Synth.stab_chord(chord["voicing"], true)
			Synth.note("fbass", chord["root"])
			Synth.note("fbass", chord["root"] + 12)
			for midi in chord["voicing"]:
				Synth.note("clav", midi)
				Synth.note("clav", midi + 12)
				Synth.note("clav", midi + 24)


static func prepare_all() -> void:
	prepare()
	prepare_rest()


static func _prepare_chords(chords: Array, leads: Array) -> void:
	for chord in chords:
		Synth.note("sub", chord["root"])
		Synth.note("reese", chord["root"] + 12)
		Synth.chord(chord["voicing"])
		Synth.pad_chord(chord["voicing"])
		for midi in chord["voicing"]:
			Synth.note("bell", midi + 12)
			Synth.note("bell", midi + 24)
	for midi in range(60, 87):
		for voice in leads:
			Synth.note(voice, midi)


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


func beat_len() -> int:
	return step_len * Harmony.STEPS_PER_BEAT


func bar_len() -> int:
	return step_len * Harmony.STEPS_PER_BAR


func bpm() -> float:
	return 60.0 * Harmony.RATE / beat_len()


func set_pressure(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	var before := layer_gains(applied_pressure)
	var after := layer_gains(next)
	pressure = next
	if mode != PLAY or track != "level":
		return
	# A layer about to enter gets a one-beat riser that lands on its downbeat.
	for layer in [SNARE, REESE, LEAD, ARP]:
		if before[layer] < 0.05 and after[layer] >= 0.05:
			_riser_into(next_bar())
			break


func _riser_into(bar: int) -> void:
	if bar - beat_len() > clock and bar - _last_riser >= RISER_SPACING:
		_last_riser = bar
		_add_action(bar - beat_len(), {"type": "stinger", "id": "music_pressure", "db": 0.0, "music": true})


# The next beat boundary at or after the play head. A stinger asked for mid-beat waits
# for the beat; one asked for exactly on an unplayed beat starts on it.
func next_beat(from := -1) -> int:
	var at := clock if from < 0 else from
	var beat := beat_len()
	var next := grid_origin + int(ceil(float(at - grid_origin) / beat)) * beat
	if next == clock and _last_step_at == clock:
		next += beat
	return next


func next_bar() -> int:
	var rel := clock - bar_origin
	var bar := bar_origin + int(ceil(float(rel) / bar_len())) * bar_len()
	if bar == clock and _last_step_at == clock:
		bar += bar_len()
	return bar


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
		for k in 3:
			_add_action(at + k * pulse, {"type": "hit", "drums": ["kick", "open_hat", "crash"] if k == 0 else ["kick", "open_hat"]})
		_add_action(at, {"type": "pulse", "until": at + span})
		_add_action(at + span, {"type": "track", "track": kind, "section": first, "step": Harmony.BOSS_STEP})
	else:
		_add_action(at, {"type": "track", "track": kind, "section": first})
	return at


# The Warden breaks: the drop starts at a beat, as its own downbeat.
func drop_at(at: int) -> void:
	_add_action(at, {"type": "track", "track": "warden", "section": "drop"})


# A boss dies: cadence home from the next beat, then the level theme at 172.
func end_boss() -> int:
	if track == "level":
		return -1
	var at := next_beat()
	schedule_cadence(at, {"track": "level", "section": "", "step": Harmony.STEP})
	return at


func set_brindle_phase(phase: int) -> int:
	if track != "brindle":
		return -1
	var at := next_bar()
	_add_action(at, {"type": "track", "track": "brindle", "section": str(clampi(phase, 1, 3))})
	return at


func victory() -> int:
	var at := next_beat()
	_add_action(at, {"type": "track", "track": "brindle", "section": "victory"})
	return at


# Puts a track in place now, for previews and tests.
func force_track(next_track: String, next_theme: int, next_section := "", boss_tempo := false) -> void:
	theme = clampi(next_theme, 0, 2)
	var action := {"type": "track", "track": next_track, "section": next_section}
	action["step"] = Harmony.BOSS_STEP if boss_tempo else Harmony.STEP
	_run(action)
	mode = PLAY
	_retarget()


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
	_pulse_from = -1
	_pulse_until = -1
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
		_run_due()
		var rel := clock - grid_origin
		if posmod(rel, step_len) == 0 and _last_step_at != clock:
			_last_step_at = clock
			_on_step()
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
	var steps := (clock - bar_origin) / step_len
	var s := steps % Harmony.STEPS_PER_BAR
	var bar := steps / Harmony.STEPS_PER_BAR
	if s == 0:
		_on_bar(bar)
		steps = (clock - bar_origin) / step_len
		s = steps % Harmony.STEPS_PER_BAR
		bar = steps / Harmony.STEPS_PER_BAR
	var chord := _chord(bar)
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
		_note("bell", tones[(s + bar) % tones.size()] + 24, 1, ARP, 0.6, -0.4 if s % 4 == 1 else 0.4)


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
			bar_origin = clock
			_cadence_bar = -1
			_pulse_until = -1
			mode = action["mode"]
			_new_phrase()
			_release_all()
			_retarget()
		"cadence":
			bar_origin = clock
			_cadence_bar = 0
			_cadence_then = action.get("then", {})
			_release_all()
			events_log.append(["cadence", clock, track])
		"mode":
			mode = action["mode"]
			if mode != PLAY:
				_release_layers([KICK, SNARE, REESE, LEAD, ARP])
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
			bar_origin = clock
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
			events_log.append(["hit", clock, action["drums"]])


# A tempo change lands on the play head, which every caller keeps on a beat.
func _set_grid(step: int) -> void:
	if step == step_len:
		return
	step_len = step
	grid_origin = clock
	_last_step_at = -1
	events_log.append(["tempo", clock, step])


func _new_phrase() -> void:
	phrase_index += 1
	_lead = _make_track_lead()


func _on_bar(bar: int) -> void:
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
			bar_origin = clock
			_new_phrase()
	elif track == "warden" and section == "drop" and bar >= 8:
		_cadence_bar = 0
		_cadence_then = {"track": "level", "section": "", "step": Harmony.STEP}
		bar_origin = clock
		_release_all()
		events_log.append(["cadence", clock, track])
	elif track == "brindle" and section == "victory" and bar >= Harmony.VICTORY.size():
		_run({"type": "track", "track": "level", "section": "", "step": Harmony.STEP})
		mode = IDLE
	var local := (clock - bar_origin) / bar_len()
	if track == "miniboss" and local % 2 == 1:
		_riser_into(clock + bar_len())
	if track == "warden" and section == "build" and local % 4 == 3:
		_riser_into(clock + bar_len())
	applied_pressure = pressure
	_retarget()
	if local % Harmony.PHRASE_BARS == 0:
		_groove = _rng.randi() % 3


func _floor() -> float:
	var key := track if track != "warden" else "warden:%s" % section
	return PRESSURE_FLOOR.get(key, 0.0)


func _retarget() -> void:
	var effective := maxf(applied_pressure, _floor()) if mode == PLAY else applied_pressure
	var gains := layer_gains(effective)
	for layer in gains.size():
		_targets[layer] = gains[layer] * MODE_MASK[mode][layer]
	var warm: float = OVERCHARGE_GAIN[clampi(overcharge, 0, OVERCHARGE_GAIN.size() - 1)]
	if track == "warden" and section == "drop":
		warm = maxf(warm, 0.8)
	_targets[WARM] = warm * MODE_MASK[mode][WARM]
	_pump_depth = 0.0
	if mode == PLAY and _cadence_bar < 0:
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
			return Harmony.VICTORY if section == "victory" else Harmony.BRINDLE
	return Harmony.level_progression(theme)


func _chord(bar: int) -> Dictionary:
	if _cadence_bar >= 0:
		return Harmony.CADENCE[mini(bar, Harmony.CADENCE.size() - 1)]
	var progression := _progression()
	if track == "brindle" and section == "victory":
		return progression[mini(bar, progression.size() - 1)]
	return progression[bar % progression.size()]


func _next_chord(bar: int) -> Dictionary:
	var progression := _progression()
	return progression[(bar + 1) % progression.size()]


func _make_track_lead() -> Array:
	match track:
		"brindle":
			_lead_voice = "brass"
			if section == "victory":
				return VICTORY_LEAD
			var quote := {"1": 2, "2": 1, "3": 0}.get(section, 0) as int
			return make_lead(phrase_index, [MOTIF, MOTIF_SLUICE, MOTIF_WEIR][quote], Harmony.BRINDLE, 73)
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
		var buf := Synth.chord(chord["voicing"])
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
	if cadence:
		return
	# Reese: root, octave pop, root, and a chromatic approach into the next bar's root.
	var root: int = chord["root"] + 12
	var next_root: int = _next_chord(bar)["root"] + 12
	var line := {0: [root, 3], 3: [root + 12, 1], 6: [root, 2], 10: [root + 7, 3], 14: [next_root - 1, 2]}
	if line.has(s):
		_release_layers([REESE])
		_note("reese", line[s][0], line[s][1], REESE, 1.0, 0.0)
	_play_lead(phrase_bar, s)
	_arp(bar, s, chord, "bell")


# Sluice: funk. The clav riff calls, the brass answers, the groove is a machine.
func _trigger_funk(bar: int, s: int, chord: Dictionary) -> void:
	var phrase_bar := bar % Harmony.PHRASE_BARS
	var busy := applied_pressure >= 0.3 and mode == PLAY
	var voicing: Array = chord["voicing"]
	var riff := CLAV_BUSY if busy else CLAV_CALM
	if riff.has(s):
		var midi: int = voicing[int(riff[s]) % voicing.size()] + (12 if s % 4 == 2 else 0)
		_note("clav", midi, 1, KEYS, 1.1, -0.3 if s % 2 == 0 else 0.3)
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
	var root: int = chord["root"]
	if FUNK_BASS.has(s):
		_release_layers([REESE])
		_note("fbass", root + int(FUNK_BASS[s][0]), int(FUNK_BASS[s][1]), REESE, 1.2, 0.0)
	elif s == 14:
		_release_layers([REESE])
		_note("fbass", int(_next_chord(bar)["root"]) - 1, 2, REESE, 1.2, 0.0)
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
		var organ := Synth.organ_chord(chord["voicing"])
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
	if s % 4 == 0:
		var ladder := [0, 7, 10, 12] if phrase_bar < 4 else [12, 10, 7, 0]
		_release_layers([REESE])
		_note("reese", int(chord["root"]) + 12 + ladder[s / 4], 4, REESE, 1.0, 0.0)
	_play_lead(phrase_bar, s)
	_arp(bar, s, chord, "bell")


# The Warden: the level rebuilt as club music. Four on the floor, funk bass, filtered
# stabs, a pump under every kick; the build waits for the drop.
func _trigger_house(bar: int, s: int, chord: Dictionary) -> void:
	var drop := section == "drop"
	var phrase_bar := bar % Harmony.PHRASE_BARS
	if s % 4 == 0:
		_hit("kick", KICK, 1.0, 0.0)
	if s == 4 or s == 12:
		_hit("clap", SNARE, 1.0, 0.1)
		if drop:
			_hit("snare", SNARE, 0.5, -0.1)
	if not drop and phrase_bar % 4 == 3 and s >= 8:
		_hit("snare", SNARE, 0.3 + 0.08 * (s - 8), 0.0)
	if s % 4 == 2:
		_hit("open_hat", HATS, 0.8, 0.25)
	elif s % 2 == 1:
		_hit("hat", HATS, 0.35, -0.25)
	if drop and s == 0 and phrase_bar % 4 == 0:
		_hit("crash", HATS, 1.0, -0.2)
	var root: int = chord["root"]
	if HOUSE_BASS.has(s):
		_release_layers([REESE])
		_note("fbass", root + int(HOUSE_BASS[s][0]), int(HOUSE_BASS[s][1]), REESE, 1.3, 0.0)
	if s == 0:
		_note("sub", root, 16, SUB, 0.8, 0.0)
	if s in [2, 6, 10, 13]:
		var stab := Synth.stab_chord(chord["voicing"], drop)
		_start(stab, mini(stab.size(), step_len + RELEASE), KEYS, LEVELS[KEYS] * 1.1, 0.2 if s % 4 == 2 else -0.2, false)
	if s == 0 and (_targets[WARM] > 0.0 or _gains[WARM] > 0.0):
		var pad := Synth.pad_chord(chord["voicing"])
		_start(pad, mini(pad.size(), 16 * step_len + RELEASE), WARM, LEVELS[WARM], 0.0, false)
	if drop:
		_play_lead(phrase_bar, s)
		_arp(bar, s, chord, "bell")


# Brindle: anvil and industrial drums under a brass fanfare that quotes the level the
# phase was taught in. Phase 3 adds everything; the victory resolves home.
func _trigger_brindle(bar: int, s: int, chord: Dictionary) -> void:
	var phase := int(section) if section.is_valid_int() else 3
	if section == "victory":
		_trigger_victory(bar, s, chord)
		return
	var phrase_bar := bar % Harmony.PHRASE_BARS
	if s == 0:
		_hit("boom", KICK, 1.0, 0.0)
	if s in ([0, 3, 8, 10, 6, 14] if phase >= 3 else [0, 3, 8, 10]):
		_hit("kick", KICK, 0.9, 0.0)
	if s == 4 or s == 12:
		_hit("clap", SNARE, 1.0, 0.1)
	if s in ([6, 11, 14] if phase >= 2 else [6, 14]):
		_hit("anvil", SNARE, 0.8, -0.35 if s < 10 else 0.35)
	_hit("hat", HATS, 0.7 if s % 4 == 2 else 0.35, 0.2)
	var root: int = chord["root"]
	if BRINDLE_BASS.has(s):
		_release_layers([REESE])
		_note("reese", root + 12 + int(BRINDLE_BASS[s][0]), int(BRINDLE_BASS[s][1]), REESE, 1.1, 0.0)
	if s == 0:
		_note("sub", root, 16, SUB, 0.9, 0.0)
	if s == 0 or s == 10:
		_release_layers([KEYS])
		var stab := Synth.stab_chord(chord["voicing"], true)
		_start(stab, stab.size(), KEYS, LEVELS[KEYS] * 1.2, 0.0, false)
	if s == 0 and phase >= 2:
		var organ := Synth.organ_chord(chord["voicing"])
		_start(organ, mini(organ.size(), 16 * step_len + RELEASE), WARM, LEVELS[WARM] * 0.8, 0.0, false)
	_play_lead(phrase_bar, s)
	if phase >= 3:
		_arp(bar, s, chord, "bell")


func _trigger_victory(bar: int, s: int, chord: Dictionary) -> void:
	var last := bar >= Harmony.VICTORY.size() - 1
	if last:
		if s == 0:
			_hit("crash", HATS, 1.0, 0.0)
			_hit("kick", KICK, 1.0, 0.0)
			_note("sub", chord["root"], 16, SUB, 1.0, 0.0)
			var held := Synth.chord(chord["voicing"])
			_start(held, held.size(), KEYS, LEVELS[KEYS] * 1.2, 0.0, false)
			var pad := Synth.pad_chord(chord["voicing"])
			_start(pad, pad.size(), WARM, LEVELS[WARM], 0.0, false)
	else:
		if s % 4 == 0:
			_hit("kick", KICK, 1.0, 0.0)
		if s == 4 or s == 12:
			_hit("clap", SNARE, 1.0, 0.0)
		if bar == Harmony.VICTORY.size() - 2 and s >= 8:
			_hit("snare", SNARE, 0.4 + 0.08 * (s - 8), 0.0)
		if s == 0:
			_note("sub", chord["root"], 16, SUB, 0.9, 0.0)
			var stab := Synth.stab_chord(chord["voicing"], true)
			_start(stab, stab.size(), KEYS, LEVELS[KEYS] * 1.2, 0.0, false)
		_hit("hat", HATS, 0.6 if s % 4 == 2 else 0.3, 0.2)
	_play_lead(bar, s)


func _sub_and_pad(s: int, chord: Dictionary) -> void:
	if s != 0:
		return
	_note("sub", chord["root"], 16, SUB, 1.0, 0.0)
	if _targets[WARM] > 0.0 or _gains[WARM] > 0.0:
		var pad := Synth.pad_chord(chord["voicing"])
		_start(pad, mini(pad.size(), 16 * step_len + RELEASE), WARM, LEVELS[WARM], 0.0, false)


func _play_lead(phrase_bar: int, s: int) -> void:
	var at := phrase_bar * Harmony.STEPS_PER_BAR + s
	for event in _lead:
		if event[0] == at:
			_release_layers([LEAD])
			_note(_lead_voice, event[1], event[2], LEAD, 1.0, 0.1)
			if track == "miniboss":
				_note(_lead_voice, event[1] + 12, event[2], LEAD, 0.4, -0.1)


func _arp(bar: int, s: int, chord: Dictionary, instrument: String) -> void:
	if s % 2 == 0 or applied_pressure >= 0.9:
		var tones: Array = chord["voicing"]
		var pattern := [0, 1, 2, 3, 2, 1]
		var midi: int = tones[pattern[(s / 2 + bar % Harmony.PHRASE_BARS) % pattern.size()] % tones.size()] + 12
		_note(instrument, midi, 2, ARP, 0.8, 0.45 if s % 4 == 0 else -0.45)


func _note(instrument: String, midi: int, steps: int, layer: int, gain: float, pan: float) -> void:
	var buf := Synth.note(instrument, midi)
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
			if pump0 < 1.0 or pump1 < 1.0:
				if voice.layer in PUMPED:
					g0 *= pump0
					g1 *= pump1
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
