extends SceneTree

const MusicRows := preload("res://src/presentation/music_rows.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Game := preload("res://src/game.gd")
const IDS := ["riser_natural", "drop_flood", "riser_fleet", "drop_fleet", "riser_ancient", "drop_ancient", "riser_industrial", "drop_industrial"]
const LEAD := Harmony.BAR * 5
var _failures := 0
var _checks := 0
var _game
var _ticks := 0
var _announcements := {}
var _starts := {}
var _routed := {}
var _director_times := {}
var _sample_due := {}
var _land_samples := {}
var _grid_due := {}

func _initialize() -> void:
	var row_script: Script = MusicRows
	var constants: Dictionary = row_script.get_script_constant_map()
	var cues: Dictionary = constants.get("CUES", {})
	for id in IDS:
		_check(id + " row exists", cues.has(id), str(cues.get(id, {})))
	var e = MusicEngine.new()
	if not e.has_method("park_cue") or not MusicRows.new().has_method("cue"):
		_check("timing key and timbre hooks", false, "park_cue/cue absent")
		_finish()
		return
	_fixture_checks()
	_key_change_checks()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)

func _fixture_checks() -> void:
	var signatures := []
	var sounds := []
	for family in ["natural", "fleet", "ancient", "industrial"]:
		var id: String = "riser_" + family
		var row: Dictionary = MusicRows.new().call("cue", id, {"ancient": "reactor", "theme": 0, "motif": "sable"})
		var signature := str([row.voice, row.notes, row.get("accent", ""), row.get("sound", "")])
		_check(family + " measurable family distinctness", not signature in signatures, signature)
		signatures.append(signature)
		var e = MusicEngine.new()
		e.key = 3
		e.band_muted = true
		e.call("park_cue", id, LEAD, 0, {}, Audio.PRIORITY_DB[Rows.priority("event_announced")])
		var actions: Array = e._actions.filter(func(a): return a.get("type") == "park_cue")
		_check(id + " full lead scheduled", not actions.is_empty() and actions[0].at == 0 and actions[-1].at + actions[-1].length == LEAD,
			str(actions.map(func(a): return [a.at, a.length])))
		if actions.is_empty():
			continue
		var first_pcm := PackedFloat32Array()
		for a in actions:
			e.clock = a.at
			e._voices.clear()
			e._run(a)
			_check(id + " voice observed", e._voices.size() == 1, str(e._voices.size()))
			if e._voices.is_empty():
				continue
			var voice = e._voices[0]
			_check_voice_key(id, voice.buf, a, 3, e.step_len, e.theme)
			var trim: float = Bank.trim_db(a.row.trim_sound) + Audio.PRIORITY_DB[Rows.priority("event_announced")]
			_check(id + " trim plus priority", absf(linear_to_db(voice.gl) - trim) < 0.01, "%.3f vs %.3f" % [linear_to_db(voice.gl), trim])
			if first_pcm.is_empty():
				first_pcm = voice.buf
		_check(family + " rendered family distinctness", not first_pcm in sounds, "first rising note PCM differs")
		sounds.append(first_pcm)
		e._actions.clear()
		e._voices.clear()
		e.park_cue_log.clear()
		e.clock = 0
		e.call("park_cue", id, LEAD, 0, {}, 0.0)
		# Render through the actual sequencer. This detects a one-beat late start,
		# rather than trusting the queued row's declared lead.
		e.render(LEAD + 1)
		var log: Array = e.get("park_cue_log")
		_check(id + " rise timing", not log.is_empty() and log[0].at == 0 and abs(log[-1].end - LEAD) <= Harmony.BEAT,
			str(log.map(func(a): return [a.at, a.end])))
		var land: String = "drop_flood" if family == "natural" else "drop_" + family
		var drop_engine = MusicEngine.new()
		drop_engine.key = 3
		drop_engine.band_muted = true
		drop_engine.park_cue(land, 0, 0, {}, Audio.PRIORITY_DB[Rows.priority("event_started")])
		var drop_action: Dictionary = drop_engine._actions[0]
		drop_engine._run(drop_action)
		_check(land + " voice observed", drop_engine._voices.size() == 1, str(drop_engine._voices.size()))
		if not drop_engine._voices.is_empty():
			var drop_voice = drop_engine._voices[0]
			_check_voice_key(land, drop_voice.buf, drop_action, 3, drop_engine.step_len, drop_engine.theme)
			var trim: float = Bank.trim_db(drop_action.row.trim_sound) + Audio.PRIORITY_DB[Rows.priority("event_started")]
			_check(land + " trim plus priority", absf(linear_to_db(drop_voice.gl) - trim) < 0.01, "%.3f vs %.3f" % [linear_to_db(drop_voice.gl), trim])
		e.call("park_cue", land, 0, LEAD + Harmony.BAR, {}, Audio.PRIORITY_DB[Rows.priority("event_started")])
		e.render(Harmony.BAR + Harmony.BEAT * 3)
		var drops: Array = e.get("park_cue_log").filter(func(a): return a.id == land)
		_check(land + " director downbeat", drops.size() == 1 and drops[0].at == LEAD + Harmony.BAR, str(drops))
		_check(land + " live key and level", drops.size() == 1 and drops[0].key == 3 and absf(drops[0].pitch - Harmony.ratio(3)) < 0.00001
			and absf(drops[0].db - Bank.trim_db(drops[0].trim_sound) - Audio.PRIORITY_DB[Rows.priority("event_started")]) < 0.01, str(drops))
	for ancient in ["reactor", "swarm", "mind"]:
		var options := {"ancient": ancient, "motif": "tarn"}
		var rise: Dictionary = MusicRows.new().call("cue", "riser_ancient", options)
		var drop: Dictionary = MusicRows.new().call("cue", "drop_ancient", options)
		_check(ancient + " existing identity", rise.voice == Harmony.motif(ancient).voice and not rise.notes.is_empty() and drop.sound == {"reactor": "reactor_erupt", "swarm": "swarm_lock", "mind": "mind_tarn"}[ancient], str([rise, drop]))
	# Look up every authored park cue, including aliases beyond the eight examples.
	var park = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_dam.json"))
	for event in park.event_rows:
		for phase in event.music_cue:
			_check(event.id + "/" + phase + " authored cue resolves", not MusicRows.new().call("cue", event.music_cue[phase], {}).is_empty(), event.music_cue[phase])


func _key_change_checks() -> void:
	for id in ["riser_natural", "drop_flood", "riser_fleet", "drop_fleet"]:
		var e = MusicEngine.new()
		e.band_muted = true
		e.render(1)
		var boundary: int = e.step_len * Harmony.STEPS_PER_BAR
		e._queue({"key": 3})
		var rising: bool = id.begins_with("riser_")
		var priority: float = Audio.PRIORITY_DB[Rows.priority("event_announced" if rising else "event_started")]
		e.park_cue(id, LEAD if rising else 0, boundary, {}, priority, id)
		var action: Dictionary = e._actions.filter(func(a): return a.get("type") == "park_cue")[0]
		e.render(boundary - e.clock)
		e.render(1)
		var label: String = id + " key-changing downbeat"
		var voices: Array = e._voices.filter(func(v): return v.park_owned and v.park_owner == id)
		_check(label + " new band key", e.key == 3, str(e.key))
		_check(label + " exact sample", e.park_cue_log.size() == 1 and e.park_cue_log[0].at == boundary, str(e.park_cue_log))
		_check(label + " actual voice", voices.size() == 1, str(voices.size()))
		if voices.is_empty():
			continue
		var voice = voices[0]
		_check_voice_key(label, voice.buf, action, 3, e.step_len, e.theme)
		var previous_pcm := Bank.samples_at(action.row.sound, e.step_len, 0, e.theme) if action.row.has("sound") else _recipe_pcm(action, 0)
		_check(label + " rejects previous-key PCM", voice.buf != previous_pcm, "started buffer differs from previous key zero")
		var expected_db: float = Bank.trim_db(action.row.trim_sound) + priority
		_check(label + " trim plus priority", absf(linear_to_db(voice.gl) - expected_db) < 0.01, str([linear_to_db(voice.gl), expected_db]))


func _check_voice_key(id: String, pcm: PackedFloat32Array, action: Dictionary, live_key: int, step: int, theme: int) -> void:
	if action.row.has("sound"):
		var expected := Bank.samples_at(action.row.sound, step, live_key, theme)
		var root_pcm := Bank.samples_at(action.row.sound, step, 0, theme)
		_check(id + " live key", pcm == expected and pcm != root_pcm, "actual bank voice PCM at live key versus key zero")
	elif action.row.voice == "steam_whistle":
		var expected_hz := Harmony.hz(action.row.notes[action.cell]) * Harmony.ratio(live_key) * lerpf(1.0, Harmony.ratio(2), 0.5)
		var measured := _peak_frequency(pcm, expected_hz)
		_check(id + " live key", absf(measured / expected_hz - 1.0) < 0.035, "actual whistle PCM %.2f Hz versus live-key sweep %.2f Hz" % [measured, expected_hz])
	else:
		var expected := _recipe_pcm(action, live_key)
		var root_pcm := _recipe_pcm(action, 0)
		_check(id + " live key", not expected.is_empty() and pcm == expected and pcm != root_pcm, "actual Synth recipe PCM transposed by Harmony.ratio versus key zero")


func _recipe_pcm(action: Dictionary, live_key: int) -> PackedFloat32Array:
	var row: Dictionary = action.row
	var hz := Harmony.hz(row.notes[action.cell]) * Harmony.ratio(live_key)
	var midi := roundi(69.0 + 12.0 * log(hz / 440.0) / log(2.0))
	var pcm := PackedFloat32Array()
	match row.voice:
		"lead": pcm = Synth.lead(midi, action.length)
		"brass": pcm = Synth.brass(midi, action.length)
		"talk": pcm = Synth.talk(midi, action.length)
		"sub": pcm = Synth.sub(midi, action.length)
		"buzz": pcm = Synth.buzz(midi, action.length, 0.0)
		"chime": pcm = Synth.chime(midi, action.length)
	if row.has("accent"):
		Synth.add_into(pcm, Synth.drum(row.accent), 0, 0.35)
	pcm = Synth.normalize(pcm)
	if row.rise:
		for i in pcm.size():
			pcm[i] *= lerpf(0.25, 1.0, float(action.progress) + float(i) / maxi(1, pcm.size()) / row.notes.size())
	return Synth.declick(pcm)


func _peak_frequency(pcm: PackedFloat32Array, expected_hz: float) -> float:
	var n := mini(4096, pcm.size())
	var start := (pcm.size() - n) / 2
	var peak := -1.0
	var frequency := 0.0
	for bin in 121:
		var hz := expected_hz * (0.72 + float(bin) * 0.0035)
		var coefficient := 2.0 * cos(TAU * hz / Harmony.RATE)
		var s1 := 0.0
		var s2 := 0.0
		for i in n:
			var window := 0.5 - 0.5 * cos(TAU * i / maxi(1, n - 1))
			var s0 := float(pcm[start + i]) * window + coefficient * s1 - s2
			s2 = s1
			s1 = s0
		var power := s1 * s1 + s2 * s2 - coefficient * s1 * s2
		if power > peak:
			peak = power
			frequency = hz
	return frequency

func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	var audio = _game.presentation.audio
	if _ticks == 0:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_game.events.event_announced.connect(func(id, seconds, _at):
			_announcements[id] = seconds
			_routed[id] = audio.engine._actions.filter(func(a): return a.get("type") == "park_cue").duplicate(true)
			_director_times[id] = _game.world.events.stage_time
			_sample_due[id] = audio.engine.clock + roundi(seconds * Harmony.RATE)
			var bar: int = audio.engine.bar_len()
			var origin: int = audio.engine.bar_origin
			_grid_due[id] = origin + ceili(float(_sample_due[id] - origin) / bar) * bar
			if audio.engine.grid != null:
				_grid_due[id] = audio.engine.grid.next_bar(_sample_due[id]))
		_game.events.event_started.connect(func(id):
			_starts[id] = _game.world.events.stage_time
			_land_samples[id] = (audio.engine.park_cue_log + audio.engine._actions.filter(func(a): return a.get("type") == "park_cue" and not a.row.rise)).duplicate(true))
		audio.bake_now()
		# The real director's public tier input unlocks unchanged park_dam rows.
		_game.world.director.stage_time = _game.world.director.TIER_SECONDS
	_ticks += 1
	if _ticks < 760:
		return false
	_check("real Game park_dam", _game.ctx.terrain.map().title == "park_dam", _game.ctx.terrain.map().title)
	var heard: Array = audio.engine.get("park_cue_log")
	var queued: Array = audio.engine._actions.filter(func(a): return a.get("type") == "park_cue")
	_check("real Game director telegraph reaches engine", _announcements.has("plunge_pool_flood") and _routed.get("plunge_pool_flood", []).any(func(a): return a.id == "riser_dam_siren"), str([_announcements, heard.size(), queued.size()]))
	_check("real Game director landing reaches engine", _starts.has("plunge_pool_flood") and (heard + queued).any(func(a): return a.id == "drop_flood_horn"), str(_starts))
	var drops: Array = _land_samples.get("plunge_pool_flood", []).filter(func(a): return a.id == "drop_flood_horn")
	_check("real Game mapped director downbeat", drops.size() == 1 and drops[0].at == _sample_due.get("plunge_pool_flood", -1)
		and _sample_due.get("plunge_pool_flood", -1) == _grid_due.get("plunge_pool_flood", -2)
		and heard.any(func(a): return a.id == "drop_flood_horn" and a.at == _sample_due.get("plunge_pool_flood", -1)),
		str([drops.map(func(a): return a.at), _sample_due, _grid_due, audio.park_cue_late]))
	_check("real Game shared transport grid", _sample_due.get("plunge_pool_flood", -1) == _grid_due.get("plunge_pool_flood", -2), str([_sample_due, _grid_due]))
	_check("real Game drop actually rendered", heard.any(func(a): return a.id == "drop_flood_horn" and a.at == _sample_due.get("plunge_pool_flood", -1)), str(heard.filter(func(a): return a.id == "drop_flood_horn")))
	_check("real Game drop prebooked", _routed.get("plunge_pool_flood", []).any(func(a): return a.id == "drop_flood_horn" and a.at == _sample_due.get("plunge_pool_flood", -1)), str(_routed.get("plunge_pool_flood", [])))
	_check("real Game director lead", _starts.has("plunge_pool_flood") and _starts["plunge_pool_flood"] >= _director_times["plunge_pool_flood"] + _announcements["plunge_pool_flood"], str([_starts, _director_times]))
	_game.queue_free()
	_game = null
	_finish()
	return true

func _check(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	_failures += int(not ok)
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])

func _finish() -> void:
	print("park_music_cues_test: %s (%d checks, %d failures)" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
