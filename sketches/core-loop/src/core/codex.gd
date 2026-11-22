extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const SafeStore := preload("res://src/core/safe_store.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")
const Parts := preload("res://src/build/parts.gd")

# The codex: one registry of every synergy, trick and interaction the demo knows,
# saved across runs (the demo's only meta-progression, DEMO-SPEC). Owners declare
# their entries at setup and call the mutators when one fires; the codex publishes the
# bus fact, grants the treasure burst once per entry per run, and writes the developer
# log, so the UI, the stinger and the log read one record. Storage failures never
# throw: the codex keeps working in memory, noting a save failure in last_error and a
# log append failure in log_error.

const CATEGORIES := ["build", "world", "enemy", "npc", "coop"]
const STATE_FILE := "codex.json"
const LOG_FILE := "codex-log.ndjson"
const STATUSES := ["none", "unencountered", "new", "available"]

# A new field note became known; the id is a LoreRows field_note row.
signal lore_found(id: String)

var events
var run
var flow
var storage_dir := "user://"
var last_error := ""
var log_error := ""
var _save_blocked := false

var _entries := {}
var _order: Array[String] = []
var _discovered := {}
var _found: Array[String] = []
var _found_category := {}
var _run_seen := {}
var _run_found := {}
var _run_discoveries: Array[String] = []
# What this stage attempt discovered. A retry rewinds the run to the stage start,
# burst scrap included, so it rewinds these too and they can fire and pay again.
var _attempt_seen: Array[String] = []
var _attempt_found: Array[String] = []
# Stage 3's attempt, set aside when the arena begins its own.
var _stage_seen_before_arena: Array[String] = []
var _stage_found_before_arena: Array[String] = []
var _warned := {}
var _zone := ""
var _guard_open := false


func setup(events_ref, run_ref, flow_ref, dir: String) -> void:
	name = "Codex"
	events = events_ref
	run = run_ref
	flow = flow_ref
	storage_dir = dir
	_load()
	events.run_started.connect(_on_run_started)
	events.stage_entered.connect(_on_stage_entered)
	events.stage_content_cleared.connect(_on_stage_content_cleared)
	_connect_lore()


# Idempotent: a second declare of the same id updates its words, never duplicates it.
func declare(entry: Dictionary) -> void:
	var id := String(entry.get("id", ""))
	if id == "":
		return
	var category := String(entry.get("category", ""))
	if not category in CATEGORIES:
		_warn_once("category:" + id, "codex: %s declares unknown category \"%s\"; not registered" % [id, category])
		return
	if not _entries.has(id):
		_order.append(id)
	_entries[id] = {
		"id": id,
		"category": category,
		"name": String(entry.get("name", id.replace("_", " ").capitalize())),
		"hint": String(entry.get("hint", "")),
		"clue": String(entry.get("clue", "")),
		"text": String(entry.get("text", "")),
	}


func known(id: String) -> bool:
	return _discovered.has(id)


func discovered() -> Array:
	return _discovered.keys()


func found() -> Array:
	return _found.duplicate()


func found_category(text: String) -> String:
	return _found_category.get(text, "world")


func discovered_this_run() -> Array:
	return _run_discoveries.duplicate()


func name_of(id: String) -> String:
	if _entries.has(id):
		return _entries[id]["name"]
	return id.replace("_", " ").capitalize()


# An undeclared id (warned at discovery) files under build everywhere: the bus fact,
# the log line and the pages read the same category.
func category_of(id: String) -> String:
	return _entries[id]["category"] if _entries.has(id) else "build"


func entries(category := "", profile = null) -> Array:
	var list: Array = []
	for id in _order:
		var entry: Dictionary = _entries[id]
		if category != "" and entry["category"] != category:
			continue
		var shown := entry.duplicate()
		shown["known"] = known(id)
		shown["status"] = status(id, profile)
		list.append(shown)
	return list


func status(id: String, profile = null) -> String:
	if not _entries.has(id):
		return "none"
	if not known(id):
		return "unencountered"
	var reader = profile if profile != null else _profile()
	return "available" if reader != null and reader.is_seen(id) else "new"


func open_entry(id: String, profile = null) -> bool:
	if not _entries.has(id) or not known(id):
		return false
	var reader = profile if profile != null else _profile()
	if reader == null or not reader.mark_seen(id):
		return false
	if reader.can_save and not reader.save():
		last_error = "logbook marker not saved: %s" % reader.last_error
	return true


func _profile():
	if flow != null and flow.get("ctx") != null:
		return flow.ctx.profile
	return null


func completion(category: String) -> float:
	var listed := entries(category)
	if listed.is_empty():
		return 0.0
	var got := 0
	for entry in listed:
		if entry["known"]:
			got += 1
	return float(got) / float(listed.size())


# A named entry fired. The first time in a run it publishes synergy_discovered, grants
# the treasure burst at the spot and logs; first_time says whether the saved codex had
# never seen it. Returns that same first_time.
func mark_discovered(id: String, at := Vector3.ZERO, participants: Array = ["player"]) -> bool:
	var first_time := not _discovered.has(id)
	if first_time:
		_discovered[id] = true
		_save()
	if not _entries.has(id):
		_warn_once("undeclared:" + id, "codex: %s was discovered but never declared" % id)
	if _run_seen.has(id):
		return first_time
	_run_seen[id] = true
	_run_discoveries.append(id)
	_attempt_seen.append(id)
	var category := category_of(id)
	_log({"kind": "discovered", "category": category, "id": id, "participants": participants})
	events.synergy_discovered.emit(id, category, first_time)
	if flow != null and flow.has_method("discovery_burst"):
		flow.discovery_burst(at)
	return first_time


# A trick told when it wakes (its own banner and chime, build.gd set_completed) becomes known
# like a discovery, without the discovery's card, chime or burst. Returns whether it was new.
func mark_known(id: String, participants: Array = ["player"]) -> bool:
	var first_time := not _discovered.has(id)
	if first_time:
		_discovered[id] = true
		_save()
	if not _run_seen.has(id):
		_run_seen[id] = true
		_run_discoveries.append(id)
		_attempt_seen.append(id)
		_log({"kind": "discovered", "category": category_of(id), "id": id, "participants": participants})
	return first_time


# A lore plate filed its field note: known as mark_known makes it (the run's list and its log line), and the HUD's
# note pulse the first time the profile has it. Returns whether it was new.
func file_note(id: String) -> bool:
	if not mark_known(id):
		return false
	lore_found.emit(id)
	return true


# An unnamed interaction fired: the first time in a run it logs and chimes. Returns
# whether the saved Found list had never seen it.
func mark_found(text: String, category := "world", participants: Array = ["player"]) -> bool:
	var first_time := not text in _found
	if first_time:
		_found.append(text)
		_found_category[text] = category
		_save()
	if _run_found.has(text):
		return first_time
	_run_found[text] = true
	_attempt_found.append(text)
	_log({"kind": "found", "category": category, "text": text, "participants": participants})
	events.interaction_found.emit(text)
	return first_time


func _on_run_started(_class_id: String) -> void:
	_run_seen = {}
	_run_found = {}
	_run_discoveries = []
	_attempt_seen = []
	_attempt_found = []
	_stage_seen_before_arena = []
	_stage_found_before_arena = []


# A stage retry (R, or T replaying stage 3 from its start) rewinds everything since
# the stage began, the arena attempt included.
func _on_stage_entered(stage: int, retry: bool) -> void:
	var profile = _profile()
	if run != null and profile != null:
		run.reconcile_tallies(profile.run_tallies(run.run_id))
	_enter_zone(stage)
	if retry:
		_rewind(_attempt_seen + _stage_seen_before_arena, _attempt_found + _stage_found_before_arena)
	_attempt_seen = []
	_attempt_found = []
	_stage_seen_before_arena = []
	_stage_found_before_arena = []


# The arena is its own attempt. Entering it sets the stage-3 attempt aside, so an arena
# retry rewinds only what the fight discovered; a T replay still rewinds both.
func _on_stage_content_cleared(reason: String) -> void:
	if reason == "arena":
		_stage_seen_before_arena.append_array(_attempt_seen)
		_stage_found_before_arena.append_array(_attempt_found)
	elif reason == "arena_retry":
		_rewind(_attempt_seen, _attempt_found)
	else:
		return
	_attempt_seen = []
	_attempt_found = []


func _rewind(seen: Array, found: Array) -> void:
	for id in seen:
		_run_seen.erase(id)
		_run_discoveries.erase(id)
	for text in found:
		_run_found.erase(text)


# The seven lore moments, one bus signal each: a standing activity done, a cracked wall
# opened, a rescue freed, a relic taken, a Warden's guard broken (rising edge of its
# stagger), the Warden killed (the beacon unsealing) and the stage cleared.
func _connect_lore() -> void:
	events.activity_done.connect(func(_id: String, _at: Vector3): _lore_moment())
	events.world_fact.connect(func(kind: String, _at: Vector3):
		if kind == "wall_crumbled":
			_lore_moment())
	events.rescue_completed.connect(func(_quest: String): _lore_moment())
	events.part_gained.connect(func(part_id: String, _source: String):
		var def: Resource = Parts.def(part_id)
		if def != null and def.rarity == "relic":
			_lore_moment())
	events.posture_changed.connect(_on_lore_posture)
	events.beacon_unsealed.connect(func(_stage: int): _lore_moment())
	events.stage_cleared.connect(func(_stage: int): _lore_moment())


func _on_lore_posture(_enemy, _posture: float, staggered: bool) -> void:
	if staggered and not _guard_open:
		_lore_moment()
	_guard_open = staggered


func _stage_table():
	if flow != null and flow.get("ctx") != null:
		return flow.ctx.stages
	return null


func _enter_zone(stage: int) -> void:
	var table = _stage_table()
	if table == null:
		return
	_zone = "%d-%d" % [table.world_of(stage), table.local(stage)]
	_guard_open = false
	for row in LoreRows.ROWS:
		if row["kind"] == "exchange" and row["zone"] == _zone:
			_mark_lore(row["id"], false)


# The next unknown note of this zone in row order, else the earliest unknown note of an
# earlier zone. A full codex does nothing.
func _lore_moment() -> void:
	var zones: Array[String] = []
	for row in LoreRows.ROWS:
		if not row["zone"] in zones:
			zones.append(row["zone"])
	var here := zones.find(_zone) if _zone in zones else zones.size()
	var earlier := ""
	for row in LoreRows.ROWS:
		if row["kind"] != "field_note" or _discovered.has(row["id"]):
			continue
		if row["zone"] == _zone:
			_mark_lore(row["id"])
			return
		if earlier == "" and zones.find(row["zone"]) < here:
			earlier = row["id"]
	if earlier != "":
		_mark_lore(earlier)


func _mark_lore(id: String, is_note := true) -> void:
	if _discovered.has(id):
		return
	_discovered[id] = true
	_save()
	if is_note:
		lore_found.emit(id)


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)


func _log(fields: Dictionary) -> void:
	var line := fields.duplicate()
	line["run_id"] = run.run_id if run != null else ""
	line["stage"] = run.stage if run != null else 0
	line["stage_ticks"] = int(round(run.stage_time * Engine.physics_ticks_per_second)) if run != null else 0
	line["parts"] = run.parts.duplicate() if run != null else []
	line["heft"] = run.heft() if run != null else 1.0
	append_line(storage_dir.path_join(LOG_FILE), JSON.stringify(line))


func append_line(path: String, text: String) -> bool:
	# RunLog already writes through this adapter. Keep its schema owner untouched while
	# adding SR12's shared run snapshot to death, completion and abandonment records.
	if path.get_file() == "runs.ndjson" and run != null:
		var line = JSON.parse_string(text)
		if line is Dictionary:
			var totals: Dictionary = run.tallies()
			line["tallies"] = totals
			text = JSON.stringify(line)
			var profile = _profile()
			if profile != null:
				var changed: bool = profile.record_run_tallies(run.run_id, totals)
				var settled := false
				var outcome := String(line.get("outcome", ""))
				if outcome in ["won", "died", "lost"] and (outcome != "died" or run.over):
					settled = profile.settle_run_tallies(run.run_id)
				if profile.can_save and (changed or settled or not profile.last_error.is_empty()) and not profile.save():
					last_error = "run tallies not saved: %s" % profile.last_error
	var file: FileAccess
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		log_error = "cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())]
		return false
	file.store_line(text)
	file.close()
	return true


func _load() -> void:
	var path := storage_dir.path_join(STATE_FILE)
	if not FileAccess.file_exists(path):
		return
	var parsed = SafeStore.parse(FileAccess.get_file_as_string(path), TYPE_DICTIONARY, {"discovered": SafeStore.STRINGS, "found": SafeStore.STRINGS, "found_categories": SafeStore.STRING_MAP})
	if parsed == null:
		var kept := SafeStore.quarantine(path)
		if kept.is_empty():
			_save_blocked = true
			last_error = "codex file unreadable and could not be moved aside; not saving this session"
		else:
			last_error = "codex file unreadable; kept as %s; starting empty" % kept
		return
	_save_blocked = false
	_discovered = {}
	_found = []
	for id in parsed.get("discovered", []):
		_discovered[String(id)] = true
	for text in parsed.get("found", []):
		_found.append(String(text))
	_found_category = parsed.get("found_categories", {})


func _save() -> void:
	if _save_blocked:
		return
	var path := storage_dir.path_join(STATE_FILE)
	var err := SafeStore.write_atomic(path, JSON.stringify({"discovered": _discovered.keys(), "found": _found, "found_categories": _found_category}, "  "))
	if err != OK:
		last_error = "cannot save %s: %s" % [path, error_string(err)]
