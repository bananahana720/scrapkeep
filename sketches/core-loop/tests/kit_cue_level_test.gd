extends SceneTree

const Events := preload("res://src/core/game_events.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Music := preload("res://src/presentation/music_engine.gd")
const Augments := preload("res://src/movement/augments.gd")
const LIVE_KEY := 3
const CHECKS_PER_PATH := 3
# Six table rows: four mandatory paths and one override-coverage check each, plus
# two controls, population, nonempty and final count checks. Extra paths add three.
# 2026-10-12, PC-RIVET r4, coordinator ruling: 83 -> 95 base checks
# (122 -> 134 measured total), both Rivet line branches and their admission.
const EXPECTED_CHECKS := 99
const CORE_KINDS := ["line_skill_fired", "special_used", "ultimate_peak", "ultimate_landed"]
# Shared, non-kit exception: audio.gd:1027 -> on_beat at :966 schedules the generic
# ultimate_peak cue at bank trim. A kit override never receives this offset. Since wave 44 that generic
# cue is the row's own motif_stinger (it was the shared special_fire).
const SHARED_DB_MODIFIERS := {"ultimate_peak|motif_stinger": 3.0}

class Ctx:
	extends RefCounted
	var events: Node
	var player: RefCounted
	var spawner: RefCounted

class TallyCombat:
	extends RefCounted
	var tally_last_settle := {}
	var ultimate = null
	var tally_piece := ""

class Player:
	extends RefCounted
	var chain := {"combo": 1}
	var state := {"velocity": Vector3.ZERO}
	var kit := {"line_state": Augments.LINE_IDLE}

var _audio
var _events
var _checks := 0
var _failures := 0
var _cue_count := 0
var _extra_paths := 0
var _source := ""
var _heard := {}
var _shared_peak := false


func _initialize() -> void:
	_source = FileAccess.get_file_as_string("res://src/presentation/audio.gd")
	_events = Events.new()
	var ctx := Ctx.new()
	ctx.events = _events
	ctx.player = Player.new()
	_audio = Audio.new()
	_audio.setup(ctx)
	_audio.bake_now()
	_controls()
	var classes := ClassDef.all()
	_check("class table is nonempty", not classes.is_empty(), str(classes.size()))
	for def in classes:
		_heard.clear()
		_events.run_started.emit(def.id)
		_audio.engine.key = LIVE_KEY
		for kind in CORE_KINDS:
			_begin()
			match kind:
				"line_skill_fired":
					_events.line_skill_fired.emit(def.line_id, null, Vector3.ZERO, "world")
				"special_used":
					_events.special_used.emit(def.special_id, Vector3.ZERO)
				"ultimate_peak":
					# Only the inherited generic beat cue has the existing exception.
					# A pilot registering special_fire as its own override loses it.
					_shared_peak = not _registered_sounds(def).has("special_fire")
					_events.ultimate_peak.emit(def.ultimate_id, Vector3.ZERO)
				"ultimate_landed":
					_events.ultimate_landed.emit(def.ultimate_id, Vector3.ZERO, 1, 60.0)
			# A line with no audio override on this revision may be silent. A registered
			# ability id must sound, including Tarn's claw_drag and Sable's bank_shot.
			var required: bool = kind != "line_skill_fired" or _line_override(def)
			_path(def.id, kind, required)
		if def.id == "tally":
			_tally_settles(def)
		_kit_calls(def)
		_kit_events(def)
		if def.id == "runner_gunner":
			_rivet_lines(def)
		var missing: Array = []
		for sound in _registered_sounds(def):
			if not _heard.has(sound):
				missing.append(sound)
		_check(def.id + " registered overrides observed", missing.is_empty(), str(missing))
	_check("mixer selection is nonempty", _cue_count > 0, str(_cue_count))
	var expected := EXPECTED_CHECKS + CHECKS_PER_PATH * _extra_paths
	_check("exact check count", _checks + 1 == expected, "%d expected, %d actual, %d extra paths" % [expected, _checks + 1, _extra_paths])
	print("kit_cue_level_test counts: classes=%d cues=%d checks=%d expected=%d" % [classes.size(), _cue_count, _checks, expected])
	# CONTRACTS.md: the run ends on "NAME: PASS" or "NAME: FAIL", which the smoke runner reads.
	print("kit_cue_level_test: PASS (%d checks)" % _checks if _failures == 0 else "kit_cue_level_test: FAIL (%d of %d checks)" % [_failures, _checks])
	_audio.free()
	_events.free()
	quit(0 if _failures == 0 else 1)


func _begin() -> void:
	_shared_peak = false
	_audio.cue_log.clear()
	_audio._last_start.clear()
	_audio.engine._actions.clear()
	_audio.engine._voices.clear()
	_audio.engine.key = LIVE_KEY
	_audio.engine.grid = null
	_audio.engine.mode = Music.PLAY
	_audio.engine.clock = 0
	_audio.clock = 0.0


func _controls() -> void:
	_begin()
	_audio._grammar_cue("line_skill_fired", "line_bite")
	var grammar := _observe("line_skill_fired")
	_check("control grammar bypass flagged", grammar.size() == 1 and not _errors(grammar[0]).level.is_empty(), str(grammar))
	_begin()
	_audio._start("line_skill_fired", "line_bite", Bank.stream("line_bite"), Bank.trim_db("line_bite") + Audio.PRIORITY_DB[Rows.priority("line_skill_fired")], 1.0, "SFX")
	var root_pitch := _observe("line_skill_fired")
	_check("control keyed pitch 1.0 flagged", root_pitch.size() == 1 and not _errors(root_pitch[0]).pitch.is_empty(), str(root_pitch))


func _line_override(def: Resource) -> bool:
	for connection in _events.get_signal_connection_list("line_skill_fired"):
		var name: String = connection.callable.get_method()
		var start := _source.find("func " + name + "(")
		if start < 0:
			continue
		var end := _source.find("\nfunc ", start + 1)
		var body := _source.substr(start, end - start if end >= 0 else -1)
		if body.contains('"' + def.line_id + '"') or body.contains(def.motif.to_upper() + "_SOUNDS"):
			return true
	return false


func _registered_sounds(def: Resource) -> Array:
	var sounds: Array = []
	var script: Script = Audio
	var constants := script.get_script_constant_map()
	for name in constants:
		var record = constants[name]
		if not record is Dictionary:
			continue
		if name == def.motif.to_upper() + "_SOUNDS":
			for sound in record.values():
				if sound is String and not sound in sounds:
					sounds.append(sound)
		elif def.id == "runner_gunner" and name == "RIVET_LINE":
			for field in ["punch", "arrive"]:
				sounds.append(record[field])
		elif record.get("motif", "") == def.motif and record.has("sound"):
			sounds.append(record.sound)
	return sounds


# --- Rivet (PC-RIVET) begin ---
func _rivet_lines(def: Resource) -> void:
	for branch in {"body": "punch", "world": "arrive"}:
		var field: String = "punch" if branch == "body" else "arrive"
		var sound: String = Audio.RIVET_LINE[field]
		_begin()
		_events.line_skill_fired.emit(def.line_id, null, Vector3.ZERO, branch)
		_path(def.id, "line_skill_fired", true, "line " + branch)
		var heard: Array = _audio.cue_log.filter(func(row): return row[0] == "line_skill_fired" and row[1] == sound and row[2] == "now")
		_check(def.id + " line " + branch + " owns its cue", heard.size() == 1, str(heard))
		_check(def.id + " line " + branch + " admitted", _audio._last_start.has(sound), str(_audio._last_start))
		_begin()
		_audio.sound_ready = false
		_events.line_skill_fired.emit(def.line_id, null, Vector3.ZERO, branch)
		_audio.sound_ready = true
		var skipped: Array = _audio.cue_log.filter(func(row): return row[1] == sound and row[2] == "skip")
		_check(def.id + " line " + branch + " respects admission", _observe("line_skill_fired").is_empty() and skipped.size() == 1, str(_audio.cue_log))
# --- Rivet (PC-RIVET) end ---


# Named pilot listeners also register kit events. New listeners are exercised with
# typed neutral arguments and must produce a cue; an unsuitable fixture fails loud.
func _kit_events(def: Resource) -> void:
	for signal_info in _events.get_signal_list():
		var kind := String(signal_info.name)
		if kind in CORE_KINDS or kind == "run_started":
			continue
		var owned := false
		for connection in _events.get_signal_connection_list(kind):
			var method: String = connection.callable.get_method()
			owned = owned or method.begins_with("_" + def.motif + "_") or method.begins_with("_on_" + def.motif + "_")
		if not owned:
			continue
		var args: Array = [kind]
		for arg in signal_info.args:
			match int(arg.type):
				TYPE_STRING: args.append(def.ultimate_id)
				TYPE_INT: args.append(1)
				TYPE_FLOAT: args.append(1.0)
				TYPE_BOOL: args.append(true)
				TYPE_VECTOR3: args.append(Vector3.ZERO)
				TYPE_ARRAY: args.append([])
				TYPE_DICTIONARY: args.append({})
				_: args.append(null)
		_begin()
		_events.callv("emit_signal", args)
		_extra_paths += 1
		_path(def.id, kind, true)


# Public pilot-prefixed audio entry points are registrations too: combat/ultimate
# call these directly instead of using the event bus. Discover from Audio, not a
# list of pilots. An unfamiliar entry fails until it has an executable fixture.
func _kit_calls(def: Resource) -> void:
	for method in _audio.get_method_list():
		var name := String(method.name)
		if not name.begins_with(def.motif + "_"):
			continue
		match name.trim_prefix(def.motif + "_"):
			"note":
				for mode in [Music.PLAY, Music.IDLE]:
					_begin()
					_audio.engine.mode = mode
					_audio.call(name, "stake", 1)
					_extra_paths += 1
					_path(def.id, "ultimate_peak", true, name + (" PLAY" if mode == Music.PLAY else " IDLE"))
			"line":
				for combo in [1, 5]:
					_begin()
					_audio.call(name, combo)
					_extra_paths += 1
					_path(def.id, "line_skill_fired", true, name + " combo=" + str(combo))
			"family":
				var attacks: Script = load("res://src/boss/mind_attacks.gd")
				var families: Array = attacks.get_script_constant_map().get("FAMILIES", [])
				if families.is_empty():
					_begin()
					_extra_paths += 1
					_path(def.id, "special_used", true, name + " empty family registration")
				for family in families:
					_begin()
					_audio.call(name, family)
					_extra_paths += 1
					_path(def.id, "special_used", true, name + " " + family)
			"motif":
				_begin()
				_audio.call(name, def.motif + "_recital")
				_extra_paths += 1
				_path(def.id, "special_used", true, name)
			"cue":
				# A pilot's own cue entry (kind, sound, grid), as Kest's kit calls it: its first
				# listed sound plays now, its second on the beat grid.
				var audio_script: Script = Audio
				var sounds: Array = audio_script.get_script_constant_map().get(def.motif.to_upper() + "_SOUNDS", [])
				for i in mini(2, sounds.size()):
					_begin()
					_audio.call(name, "line_skill_fired", String(sounds[i]), "now" if i == 0 else "beat")
					_extra_paths += 1
					_path(def.id, "line_skill_fired", true, name + " " + String(sounds[i]))
			"roll":
				_begin()
				_audio.call(name, 62)
				_extra_paths += 1
				_path(def.id, "ultimate_peak", true, name + " 62")
			_:
				_extra_paths += 1
				_begin()
				_path(def.id, name, true, "missing driver for registered " + name)


func _tally_settles(def: Resource) -> void:
	_begin()
	var combat := TallyCombat.new()
	var ids: Array = []
	for step in Audio.TALLY_CUES["tally_settle"]["steps"].size():
		ids.append(step + 1)
	combat.tally_last_settle = {"at": Vector3.ZERO, "hits": 1, "settles": ids.size(), "ids": ids}
	_audio.ctx.spawner = combat
	_events.ultimate_landed.emit(def.ultimate_id, Vector3.ZERO, 1 + ids.size(), 60.0)
	for note in _audio._tally_notes:
		_audio.clock = maxf(_audio.clock, float(note[0]))
	_audio._tend_tally()
	var settles: Array = _audio.cue_log.filter(func(row): return row[1] == "settle_tally" and row[2] == "now")
	_check("tally settle steps observed", settles.size() == ids.size(), "%d expected, %d observed" % [ids.size(), settles.size()])
	_path(def.id, "ultimate_landed", true, "tally_settle")
	_audio.ctx.spawner = null


func _path(class_id: String, kind: String, required: bool, label := "") -> void:
	var cues := _observe(kind)
	_cue_count += cues.size()
	var level_errors: Array = []
	var pitch_errors: Array = []
	for cue in cues:
		_heard[cue.sound] = true
		# Procedural pilot voices name their pitched stream <motif>:<notes>.
		# They must carry the live key even before a kit gives them a bank recipe.
		cue["procedural_keyed"] = cue.sound.begins_with(ClassDef.by_id(class_id).motif + ":")
		var errors := _errors(cue)
		level_errors.append_array(errors.level)
		pitch_errors.append_array(errors.pitch)
	var prefix := class_id + "/" + (label if label != "" else kind)
	_check(prefix + " observed", not required or not cues.is_empty(), "%d cues required=%s %s" % [cues.size(), required, cues])
	_check(prefix + " level", level_errors.is_empty(), str(level_errors))
	_check(prefix + " live key", pitch_errors.is_empty(), str(pitch_errors))


# _start already records the exact mixer arguments as [kind,sound,now,at,pitch,db].
# Beat voices bypass _start; execute their queued action and inspect the real Voice
# gain and PCM buffer before rendering can retire it. No production recording seam.
func _observe(driven_kind: String) -> Array:
	var cues: Array = []
	# A pilot may queue its direct cues against Audio's clock, outside the band's
	# actions. Advance that clock to the latest registered due time before observing.
	if _audio.has_method("_step_cannon_cues"):
		for row in _audio.get("_cannon_queue"):
			_audio.clock = maxf(_audio.clock, float(row.due))
		_audio.call("_step_cannon_cues")
	for row in _audio.cue_log:
		if row[2] == "now":
			cues.append({"kind": row[0], "sound": row[1], "db": row[5], "pitch": row[4], "key": _audio.live_key(), "buffer_keyed": false, "shared": false})
	for queued in _audio.engine._actions.duplicate(true):
		var action: Dictionary = queued
		if action.get("type") != "stinger" or action.get("music", false):
			continue
		_audio.engine._voices.clear()
		_audio.engine._run(action)
		var sound := String(action.id)
		var kind := driven_kind
		for row in _audio.cue_log:
			if row[1] == sound and row[2] in ["beat", "grid"]:
				kind = row[0]
		if _audio.engine._voices.is_empty():
			continue
		var voice = _audio.engine._voices.back()
		var expected := Bank.samples_at(sound, _audio.engine.step_len, LIVE_KEY, _audio.engine.theme)
		cues.append({"kind": kind, "sound": sound, "db": linear_to_db(voice.gl), "pitch": Harmony.ratio(LIVE_KEY) if voice.buf == expected else 1.0, "key": LIVE_KEY, "buffer_keyed": true, "shared": _shared_peak})
	return cues


func _errors(cue: Dictionary) -> Dictionary:
	var expected_db: float = Bank.trim_db(cue.sound) + Audio.PRIORITY_DB[Rows.priority(cue.kind)]
	if cue.shared:
		expected_db += float(SHARED_DB_MODIFIERS.get(cue.kind + "|" + cue.sound, 0.0))
	var level: Array = []
	var pitch: Array = []
	if absf(float(cue.db) - expected_db) > 0.01:
		level.append("%s/%s db=%.2f expected=%.2f" % [cue.kind, cue.sound, cue.db, expected_db])
	if (cue.sound in Audio.KEYED_SOUNDS or cue.buffer_keyed or cue.get("procedural_keyed", false)) and absf(float(cue.pitch) - Harmony.ratio(cue.key)) > 0.0001:
		pitch.append("%s/%s pitch=%.5f expected=%.5f" % [cue.kind, cue.sound, cue.pitch, Harmony.ratio(cue.key)])
	return {"level": level, "pitch": pitch}


func _check(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
