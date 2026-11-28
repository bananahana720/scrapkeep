extends SceneTree

const Game := preload("res://src/game.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Bindings := preload("res://src/core/bindings.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const T := preload("res://tests/support/t.gd")

# The harpoon line and the synergy motifs are heard (design-v3/LEGIBILITY.md sections 3 and 5):
#   HLs-1  every line sound and every verb refusal resolves in the bank; bite, clunk and dry tick differ
#   HLs-2  each line state requests its cue once on the bus; a bite is requested once, not twice
#   HLs-3  the hum stands with the line, ends within a tick of any end, and climbs an octave in
#   HLs-4  the dry tick sits 12 to 16 dB under the bite, by the RMS of the baked samples and the trims
#   HLs-5  a motif's first two notes on arming, its third on the first firing, then once per 4 s
#   HLs-6  each verb's refusal plays its cue, once per 0.25 s per verb
# The cue log and the audio clock, not speakers; the clock is stepped by hand, never read.

const STATES_WITH_SOUND := ["locked", "dry_fire", "latched_world", "latched_body", "smash_committed", "smash_lands",
	"let_go", "broke"]

var _t := T.new("line_sound_test")
var _game
var _audio
var _player
var _combat


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _sim(ticks: int) -> void:
	for i in ticks:
		await physics_frame


func _step(seconds: float) -> void:
	_audio.clock += seconds
	_audio._process(0.0)


func _fresh() -> void:
	_audio.cue_log.clear()
	_audio._last_start.clear()


func _count(sound: String, status := "") -> int:
	var total := 0
	for entry in _audio.cue_log:
		if entry[1] == sound and (status == "" or entry[2] == status):
			total += 1
	return total


func _level_db(id: String) -> float:
	return linear_to_db(Synth.peak(SfxBank.samples(id))) + SfxBank.trim_db(id)


# Loudness of a baked cue as the game plays it: the RMS of its samples plus its trim.
func _rms_db(id: String) -> float:
	return linear_to_db(Synth.rms(SfxBank.samples(id))) + SfxBank.trim_db(id)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_combat = _game.ctx.spawner
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(40)
	_audio = _game.presentation.audio
	_audio.bake_now()
	_resolves()
	_levels()
	_states()
	_fails()
	_motifs()
	await _hum()
	_game.free()
	quit(_t.verdict())


func _resolves() -> void:
	var missing: Array = []
	for state in EventKinds.LINE_ROWS:
		var id := EventKinds.line_sound(state)
		if id != EventKinds.NONE and not SfxBank.has_recipe(id):
			missing.append(id)
	for verb in Bindings.VERBS:
		var id := String(Bindings.VERBS[verb]["fail"])
		if id != "none" and not SfxBank.has_recipe(id):
			missing.append(id)
	_t.check("HLs-1 every id resolves", missing.is_empty(), "line sounds and refusals missing from the bank: %s" % [missing])
	var bite := EventKinds.line_sound("latched_body")
	var clunk := EventKinds.line_sound("latched_world")
	var dry := EventKinds.line_sound("dry_fire")
	var ids := [bite, clunk, dry]
	var distinct: bool = ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2]
	var waves: bool = SfxBank.samples(bite) != SfxBank.samples(clunk) and SfxBank.samples(clunk) != SfxBank.samples(dry) \
			and SfxBank.samples(bite) != SfxBank.samples(dry)
	_t.check("HLs-1 bite, clunk and dry tick differ", distinct and waves, "ids %s, waveforms differ %s" % [ids, waves])
	var fails: Array = []
	for verb in Bindings.VERBS:
		var id := String(Bindings.VERBS[verb]["fail"])
		if id != "none" and id != dry:
			fails.append(id)
	var same: Array = []
	for i in fails.size():
		if SfxBank.samples(fails[i]) == SfxBank.samples(dry):
			same.append(fails[i])
		for j in range(i + 1, fails.size()):
			if SfxBank.samples(fails[i]) == SfxBank.samples(fails[j]):
				same.append(fails[i] + "=" + fails[j])
	_t.check("HLs-1 refusals differ from the dry tick and each other", same.is_empty(), "identical waveforms %s of %d refusals" % [same, fails.size()])


func _levels() -> void:
	var bite := _level_db(EventKinds.line_sound("latched_body"))
	var rms_gap := _rms_db(EventKinds.line_sound("latched_body")) - _rms_db(EventKinds.line_sound("dry_fire"))
	_t.check("HLs-4 dry tick 12 to 16 dB under the bite", rms_gap >= 12.0 and rms_gap <= 16.0, "RMS gap %.1f dB (bite %.1f, dry tick %.1f)" % [rms_gap, _rms_db(EventKinds.line_sound("latched_body")), _rms_db(EventKinds.line_sound("dry_fire"))])
	var clunk := _level_db(EventKinds.line_sound("latched_world"))
	_t.check("the bite is louder than the world clunk", bite > clunk + 3.0, "bite %.1f dB, clunk %.1f dB" % [bite, clunk])
	var quiet: Array = []
	for verb in Bindings.VERBS:
		var id := String(Bindings.VERBS[verb]["fail"])
		if id != "none" and _level_db(id) > bite - 10.0:
			quiet.append(id)
		if id != "none" and SfxBank.samples(id).size() > Synth.seconds(0.3):
			quiet.append(id + " long")
	_t.check("refusals are quiet and short", quiet.is_empty(), "louder than 10 dB under the bite, or past 0.3 s: %s" % [quiet])
	var crack: bool = SfxBank.samples("smash_crack").size() > 0 and _level_db("smash_crack") > clunk
	_t.check("the crack is audible", crack, "crack %.1f dB against clunk %.1f dB" % [_level_db("smash_crack"), clunk])


func _states() -> void:
	var events = _game.events
	var wrong: Array = []
	for state in STATES_WITH_SOUND:
		_fresh()
		_step(0.3)
		events.line_state_changed.emit(state, null, Vector3.ZERO, "")
		var sound := EventKinds.line_sound(state)
		if _count(sound) != 1 or _count(sound, "now") != 1:
			wrong.append("%s %s x%d" % [state, sound, _count(sound)])
	_t.check("HLs-2 each state requests its cue once", wrong.is_empty(), "%d states; off: %s" % [STATES_WITH_SOUND.size(), wrong])
	_fresh()
	_step(0.3)
	events.line_state_changed.emit("smash_lands", null, Vector3.ZERO, "")
	_t.check("a smash lands with its own crack", _count("smash_crack", "now") == 1, "crack requested %d times" % _count("smash_crack"))
	for state in ["searching"]:
		_fresh()
		events.line_state_changed.emit(state, null, Vector3.ZERO, "")
		_t.check("searching is silent", _audio.cue_log.filter(func(e): return e[1] != "line_hum").is_empty(), "no cue for %s" % state)
	_fresh()
	_step(0.3)
	events.grapple_fired.emit(Vector3.ZERO)
	events.harpoon_bit.emit(null, Vector3.ZERO)
	events.line_state_changed.emit("latched_body", null, Vector3.ZERO, "")
	_t.check("HLs-2 bite once, not twice", _count("line_bite") == 1 and _count("grapple_clink") == 0, "grapple_fired, harpoon_bit and latched_body request the bite %d times, the old id %d" % [_count("line_bite"), _count("grapple_clink")])
	_t.check("the bite has its own id", EventKinds.line_sound("latched_body") == "line_bite", "latched_body plays %s" % EventKinds.line_sound("latched_body"))
	_t.check("grapple_clink is the old recipe", SfxBank.new()._bake("grapple_clink") == SfxBank._fm(0.24, SfxBank.new()._hz(81), 3.5, 5.0, 16.0), "grapple_clink changed")
	_t.check("the crack and the bite stay in the live key", "smash_crack" in Audio.KEYED_SOUNDS and "line_bite" in Audio.KEYED_SOUNDS, "keyed: crack %s, bite %s" % ["smash_crack" in Audio.KEYED_SOUNDS, "line_bite" in Audio.KEYED_SOUNDS])
	_fresh()
	_step(0.3)
	events.line_state_changed.emit("rewinding", null, Vector3.ZERO, "")
	_t.check("the dock click waits for the dock", _count("dock_click") == 0, "rewinding entry played %d clicks" % _count("dock_click"))
	_step(0.3)
	events.line_state_changed.emit("searching", null, Vector3.ZERO, "")
	_t.check("the dock click plays when the line leaves rewinding", _count("dock_click", "now") == 1, "%d clicks on leaving rewinding" % _count("dock_click"))
	_fresh()
	_step(0.3)
	events.grapple_released.emit()
	events.line_state_changed.emit("let_go", null, Vector3.ZERO, "")
	_t.check("a release is one zip", _count("line_zip") == 1 and _count("grapple_release") == 0, "zip %d, old release %d" % [_count("line_zip"), _count("grapple_release")])
	_fresh()
	_step(0.3)
	events.line_state_changed.emit("locked", null, Vector3.ZERO, "")
	events.line_state_changed.emit("locked", null, Vector3.ZERO, "")
	_step(0.1)
	events.line_state_changed.emit("locked", null, Vector3.ZERO, "")
	_step(0.2)
	events.line_state_changed.emit("locked", null, Vector3.ZERO, "")
	_t.check("the lock tick plays at most every 0.25 s", _count("lock_tick", "now") == 2, "four locks over 0.3 s played %d ticks" % _count("lock_tick", "now"))
	_fresh()
	_step(0.3)
	events.verb_failed.emit("harpoon", "no_aim", Vector3.ZERO)
	events.line_state_changed.emit("dry_fire", null, Vector3.ZERO, "")
	_t.check("a dry fire is one tick", _count("dry_tick") == 1, "refusal plus dry fire requested %d ticks" % _count("dry_tick"))


func _fails() -> void:
	var events = _game.events
	var wrong: Array = []
	for verb in Bindings.VERBS:
		var id := String(Bindings.VERBS[verb]["fail"])
		if id == "none":
			continue
		_fresh()
		_step(0.3)
		events.verb_failed.emit(verb, "x", Vector3.ZERO)
		events.verb_failed.emit(verb, "x", Vector3.ZERO)
		_step(0.1)
		events.verb_failed.emit(verb, "x", Vector3.ZERO)
		var early := _count(id)
		_step(0.2)
		events.verb_failed.emit(verb, "x", Vector3.ZERO)
		if early != 1 or _count(id) != 2:
			wrong.append("%s %s: %d then %d" % [verb, id, early, _count(id)])
	_t.check("HLs-6 one refusal per 0.25 s per verb", wrong.is_empty(), "off: %s" % [wrong])


func _notes(id: String) -> Array:
	var ids: Array = []
	for name in EventKinds.cause_motif(id):
		ids.append(SfxBank.cause_note_id(Harmony.note_midi(String(name))))
	return ids


func _logged(kind: String) -> Array:
	return _audio.cue_log.filter(func(e): return e[0] == kind and e[2] == "now").map(func(e): return e[1])


func _motifs() -> void:
	var events = _game.events
	var bad: Array = []
	for id in EventKinds.CAUSE_ROWS:
		events.run_started.emit("pylon_engineer")
		_step(5.0)
		var notes := _notes(id)
		_fresh()
		events.cause_armed.emit(id)
		_step(0.5)
		if _logged("cause_armed") != notes.slice(0, 2) or not _logged("cause_fired").is_empty():
			bad.append("%s armed %s want %s" % [id, _logged("cause_armed"), notes.slice(0, 2)])
		_fresh()
		events.cause_fired.emit(id, null, Vector3.ZERO)
		if _logged("cause_fired") != [notes[2]]:
			bad.append("%s first firing %s want %s" % [id, _logged("cause_fired"), [notes[2]]])
		_step(1.0)
		_fresh()
		events.cause_fired.emit(id, null, Vector3.ZERO)
		events.cause_fired.emit(id, null, Vector3.ZERO)
		if not _logged("cause_fired").is_empty():
			bad.append("%s second firing within 4 s played %s" % [id, _logged("cause_fired")])
		_step(4.0)
		events.cause_fired.emit(id, null, Vector3.ZERO)
		if _logged("cause_fired") != [notes[2]]:
			bad.append("%s later firing %s" % [id, _logged("cause_fired")])
		_fresh()
		events.run_started.emit("pylon_engineer")
		events.cause_fired.emit(id, null, Vector3.ZERO)
		if _logged("cause_fired") != [notes[2]]:
			bad.append("%s first firing of a new run %s" % [id, _logged("cause_fired")])
	_fresh()
	events.run_started.emit("pylon_engineer")
	_step(5.0)
	var first_id: String = EventKinds.CAUSE_ROWS.keys()[0]
	var phrase := _notes(first_id)
	_fresh()
	events.cause_armed.emit(first_id)
	events.cause_fired.emit(first_id, null, Vector3.ZERO)
	_step(0.5)
	var order: Array = _audio.cue_log.filter(func(e): return (e[0] == "cause_armed" or e[0] == "cause_fired") and e[2] == "now").map(func(e): return e[1])
	if order != phrase:
		bad.append("%s armed and fired together played %s want %s" % [first_id, order, phrase])
	_t.check("HLs-5 arm two notes, resolve on the first firing, then once per 4 s", bad.is_empty(), "%d motifs; off: %s" % [EventKinds.CAUSE_ROWS.size(), bad])


func _latch(distance: float) -> Node3D:
	var ball: Vector3 = _game.ctx.terrain.drop_point(-45.0, 6.0, 6.0)
	var target: Node3D = _combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(-45.0, 6.0 - distance, 1.5))
	target.live = func(): return false
	_player.reset_to(ball)
	_player.grapple_to(target.global_position, Vector3.UP, target)
	return target


func _hum() -> void:
	var far := Audio.hum_ratio(Audio.HUM_FAR)
	var near := Audio.hum_ratio(Audio.HUM_NEAR)
	_t.check("HLs-3 the hum climbs an octave", near / far >= 1.8 and near / far <= 2.2, "pitch at 3 m is %.2f times the pitch at 45 m" % [near / far])
	await _sim(2)
	var target := _latch(40.0)
	await _sim(1)
	_t.check("HLs-3 the hum is up one tick after a latch", _audio.hum_on and _count("line_hum", "now") >= 1, "hum_on %s" % _audio.hum_on)
	var first: float = _audio.hum_pitch
	await _sim(20)
	_t.check("HLs-3 the hum climbs as the gap closes", _audio.hum_pitch > first, "pitch %.3f then %.3f while the haul reels in" % [first, _audio.hum_pitch])
	_player.release_grapple()
	await _sim(1)
	_t.check("HLs-3 the hum is down one tick after a let go", not _audio.hum_on, "hum_on %s" % _audio.hum_on)
	_player.grapple_to(target.global_position, Vector3.UP, target)
	await _sim(1)
	_player.cut_line("hold")
	await _sim(1)
	_t.check("HLs-3 the hum is down one tick after a break", not _audio.hum_on, "hum_on %s" % _audio.hum_on)
	for state in ["smash_lands", "rewinding"]:
		_player.grapple_to(target.global_position, Vector3.UP, target)
		await _sim(1)
		var up: bool = _audio.hum_on
		_game.events.line_state_changed.emit(state, null, Vector3.ZERO, "")
		await _sim(1)
		_t.check("HLs-3 the hum is down one tick after %s" % state, up and not _audio.hum_on, "up before %s, hum_on %s after" % [up, _audio.hum_on])
		_player.release_grapple()
		await _sim(2)
	_player.grapple_to(target.global_position, Vector3.UP, target)
	await _sim(1)
	_player.kit.drop_line("reset")
	await process_frame
	_t.check("HLs-3 a silent reset stops the hum", not _audio.hum_on, "hum_on %s" % _audio.hum_on)
	await _sim(2)
	for route in ["frozen", "player_died", "run_ended"]:
		_player.grapple_to(target.global_position, Vector3.UP, target)
		await _sim(1)
		var up: bool = _audio.hum_on
		match route:
			"frozen":
				_player.set_frozen(true)
			"player_died":
				_game.events.player_died.emit()
			"run_ended":
				_game.events.run_ended.emit(true)
		await _sim(1)
		if route == "frozen":
			# Frozen has no event: only the audio's per-frame tender sees it. A physics tick is not a
			# rendered frame (two ticks can land in one frame under load), so run the tender by hand.
			_audio._process(0.0)
		_t.check("HLs-3 the hum is down one tick after %s" % route, up and not _audio.hum_on, "up before %s, hum_on %s after" % [up, _audio.hum_on])
		_player.set_frozen(false)
		if route == "frozen":
			await _sim(1)
			_audio._process(0.0)
			_t.check("HLs-3 the hum is back when the ball thaws on a standing line", _player.kit.hooked and _audio.hum_on,
				"hooked %s, hum_on %s" % [_player.kit.hooked, _audio.hum_on])
		_player.release_grapple()
		await _sim(2)
	target.queue_free()
	_audio.cue_log.clear()
	_game.events.line_state_changed.emit("rewinding", null, Vector3.ZERO, "")
	_game.events.stage_entered.emit(1, true)
	_game.events.line_state_changed.emit("searching", null, Vector3.ZERO, "")
	_t.eq("a reset during the rewind docks nothing", _count("dock_click", "now"), 0)
	var pivot: bool = _audio.engine.boss_pivot
	var f6 := InputEventKey.new()
	f6.physical_keycode = KEY_F6
	f6.pressed = true
	_game.dev = false
	_audio._unhandled_key_input(f6)
	var shut: bool = _audio.engine.boss_pivot == pivot
	_game.dev = true
	_audio._unhandled_key_input(f6)
	var open: bool = _audio.engine.boss_pivot != pivot
	_game.dev = false
	_audio.engine.boss_pivot = pivot
	_t.check("F6 answers only to a dev launch", shut and open, "unchanged without dev %s, toggled with it %s" % [shut, open])
