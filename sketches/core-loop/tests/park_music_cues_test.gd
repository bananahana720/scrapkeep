extends SceneTree

const MusicRows := preload("res://src/presentation/music_rows.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
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
			var expected: PackedFloat32Array = e.call("park_cue_samples", a, 3)
			_check(id + " live key", voice.buf == expected and voice.buf != e.call("park_cue_samples", a, 0), "key 3 PCM and root control")
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

func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	var audio = _game.presentation.audio
	if _ticks == 0:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_game.events.event_announced.connect(func(id, seconds):
			_announcements[id] = seconds
			_routed[id] = audio.engine._actions.filter(func(a): return a.get("type") == "park_cue").duplicate(true)
			_director_times[id] = _game.world.events.stage_time
			_sample_due[id] = audio.engine.clock + roundi(seconds * Harmony.RATE))
		_game.events.event_started.connect(func(id):
			_starts[id] = _game.world.events.stage_time
			_land_samples[id] = audio.engine._actions.filter(func(a): return a.get("type") == "park_cue" and not a.row.rise).duplicate(true))
		audio.bake_now()
		# The real director's public tier input unlocks unchanged park_dam rows.
		_game.world.events.set_clock_tier(1)
	_ticks += 1
	if _ticks < 760:
		return false
	_check("real Game park_dam", _game.ctx.terrain.map().title == "park_dam", _game.ctx.terrain.map().title)
	var heard: Array = audio.engine.get("park_cue_log")
	var queued: Array = audio.engine._actions.filter(func(a): return a.get("type") == "park_cue")
	_check("real Game director telegraph reaches engine", _announcements.has("plunge_pool_flood") and _routed.get("plunge_pool_flood", []).any(func(a): return a.id == "riser_natural"), str([_announcements, heard.size(), queued.size()]))
	_check("real Game director landing reaches engine", _starts.has("plunge_pool_flood") and (heard + queued).any(func(a): return a.id == "drop_flood"), str(_starts))
	var drops: Array = _land_samples.get("plunge_pool_flood", []).filter(func(a): return a.id == "drop_flood")
	_check("real Game mapped director downbeat", drops.size() == 1 and drops[0].at == _sample_due.get("plunge_pool_flood", -1), str([drops.map(func(a): return a.at), _sample_due, audio.park_cue_late]))
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
