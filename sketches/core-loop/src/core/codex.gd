extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")

# The codex: one registry of every synergy, trick and interaction the demo knows,
# saved across runs (the demo's only meta-progression, DEMO-SPEC). Owners declare
# their entries at setup and call the mutators when one fires; the codex publishes the
# bus fact, grants the treasure burst once per entry per run, and writes the developer
# log, so the UI, the stinger and the log read one record. Storage failures never
# throw: the codex keeps working in memory and notes last_error.

const CATEGORIES := ["build", "world", "enemy", "npc", "coop"]
const STATE_FILE := "codex.json"
const LOG_FILE := "codex-log.ndjson"

var events
var run
var flow
var storage_dir := "user://"
var last_error := ""

var _entries := {}
var _order: Array[String] = []
var _discovered := {}
var _found: Array[String] = []
var _found_category := {}
var _run_seen := {}
var _run_found := {}
var _run_discoveries: Array[String] = []


func setup(events_ref, run_ref, flow_ref, dir: String) -> void:
	name = "Codex"
	events = events_ref
	run = run_ref
	flow = flow_ref
	storage_dir = dir
	_load()
	events.run_started.connect(_on_run_started)


# Idempotent: a second declare of the same id updates its words, never duplicates it.
func declare(entry: Dictionary) -> void:
	var id := String(entry.get("id", ""))
	if id == "":
		return
	var category := String(entry.get("category", "build"))
	if not category in CATEGORIES:
		category = "build"
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


func category_of(id: String) -> String:
	return _entries[id]["category"] if _entries.has(id) else "build"


func entries(category := "") -> Array:
	var list: Array = []
	for id in _order:
		var entry: Dictionary = _entries[id]
		if category != "" and entry["category"] != category:
			continue
		var shown := entry.duplicate()
		shown["known"] = known(id)
		list.append(shown)
	return list


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
	if _run_seen.has(id):
		return first_time
	_run_seen[id] = true
	_run_discoveries.append(id)
	var category := category_of(id)
	_log({"kind": "discovered", "category": category, "id": id, "participants": participants})
	events.synergy_discovered.emit(id, category, first_time)
	if flow != null and flow.has_method("discovery_burst"):
		flow.discovery_burst(at)
	return first_time


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
	_log({"kind": "found", "category": category, "text": text, "participants": participants})
	events.interaction_found.emit(text)
	return first_time


func _on_run_started(_class_id: String) -> void:
	_run_seen = {}
	_run_found = {}
	_run_discoveries = []


func _log(fields: Dictionary) -> void:
	var line := fields.duplicate()
	line["run_id"] = run.run_id if run != null else ""
	line["stage"] = run.stage if run != null else 0
	line["stage_ticks"] = int(round(run.stage_time * Engine.physics_ticks_per_second)) if run != null else 0
	line["parts"] = run.parts.duplicate() if run != null else []
	line["heft"] = run.heft() if run != null else 1.0
	append_line(storage_dir.path_join(LOG_FILE), JSON.stringify(line))


func append_line(path: String, text: String) -> bool:
	var file: FileAccess
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())]
		return false
	file.store_line(text)
	file.close()
	return true


func _load() -> void:
	var path := storage_dir.path_join(STATE_FILE)
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		last_error = "codex file unreadable; starting empty"
		return
	for id in parsed.get("discovered", []):
		_discovered[String(id)] = true
	for text in parsed.get("found", []):
		_found.append(String(text))
	var categories = parsed.get("found_categories", {})
	if categories is Dictionary:
		_found_category = categories


func _save() -> void:
	var path := storage_dir.path_join(STATE_FILE)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "cannot save %s: %s" % [path, error_string(FileAccess.get_open_error())]
		return
	file.store_string(JSON.stringify({"discovered": _discovered.keys(), "found": _found, "found_categories": _found_category}, "  "))
	file.close()
