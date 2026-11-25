extends RefCounted


const SafeStore := preload("res://src/core/safe_store.gd")

const SCHEMA := 1
const MIGRATIONS := {0: "_migrate_0"}

const REFUSED_NEWER := "newer_schema"
const REFUSED_QUARANTINE := "quarantine_failed"
const REFUSED_CHANGED := "changed_on_disk"
const REFUSED_BACKUP := "backup_failed"
const REFUSED_WRITE := "write_failed"
const REFUSED_ENDED := "run_ended"
const SAVE_BLOCKERS := [REFUSED_NEWER, REFUSED_QUARANTINE]
const SENTENCES := {
	REFUSED_NEWER: "This run was saved by a newer version of the game; update it to continue.",
	REFUSED_QUARANTINE: "The saved run is damaged and could not be set aside, so nothing will be saved until it is removed.",
	REFUSED_CHANGED: "The saved run was damaged, so it was set aside and cannot be continued.",
	REFUSED_ENDED: "Your last run is over; start a new one.",
}

var path := "user://run.json"
var last_error := ""
var refusal := ""
var _refusal_why := ""

var _doc := {}
var _generation := 0
var _backup_path := ""
var _backup_bytes := PackedByteArray()


func _init(file_path := "user://run.json") -> void:
	path = file_path


func generation() -> int:
	return _generation


func load() -> Dictionary:
	var set_aside := refusal == REFUSED_CHANGED
	last_error = ""
	refusal = ""
	_backup_path = ""
	_backup_bytes = PackedByteArray()
	var read := _read()
	var state: String = read["state"]
	if state == "missing":
		_generation = 0
		if set_aside:
			refusal = REFUSED_CHANGED
			last_error = _refusal_why
		return {}
	if state == "newer":
		return _refuse(REFUSED_NEWER, read["why"])
	if state == "tombstone":
		_generation = int(read["generation"])
		_doc = {}
		refusal = REFUSED_ENDED
		last_error = "the run in %s ended at generation %d" % [path, _generation]
		return {}
	if state != "ok":
		var bad := SafeStore.quarantine(path)
		if bad.is_empty():
			return _refuse(REFUSED_QUARANTINE, "%s and could not be moved aside" % read["why"])
		last_error = "%s; kept as %s" % [read["why"], bad]
		refusal = REFUSED_CHANGED
		_refusal_why = last_error
		_doc = {}
		_generation = 0
		return {}
	var disk_gen: int = read["generation"]
	var run: Dictionary = read["run"]
	if not _doc.is_empty() and disk_gen < _generation:
		run = merge(_doc, run)
	else:
		_generation = disk_gen
	if read["from_version"] < SCHEMA:
		_backup_path = "%s.v%d" % [path, read["from_version"]]
		_backup_bytes = read["bytes"]
	_doc = run.duplicate(true)
	return run.duplicate(true)


func save(doc: Dictionary) -> String:
	last_error = ""
	if SAVE_BLOCKERS.has(refusal):
		last_error = "not saving: %s" % _refusal_why
		return refusal
	refusal = ""
	var read := _read()
	var state: String = read["state"]
	if state == "newer":
		_refuse(REFUSED_NEWER, read["why"])
		return REFUSED_NEWER
	if state == "tombstone" and int(read["generation"]) > _generation:
		last_error = "not saving: the run in %s was ended at generation %d; this store holds %d" % [path, read["generation"], _generation]
		return REFUSED_ENDED
	if state != "missing" and state != "ok" and state != "tombstone":
		last_error = "not saving: %s changed since it was loaded (%s)" % [path, read["why"]]
		return REFUSED_CHANGED
	var next := doc.duplicate(true)
	var generation_now := _generation
	var backup_path := _backup_path
	var backup_bytes := _backup_bytes
	if state == "ok":
		if int(read["generation"]) > _generation:
			next = merge(next, read["run"])
			generation_now = int(read["generation"])
		if backup_path.is_empty() and read["from_version"] < SCHEMA:
			backup_path = "%s.v%d" % [path, read["from_version"]]
			backup_bytes = read["bytes"]
	if not backup_path.is_empty():
		if not FileAccess.file_exists(backup_path):
			var kept := SafeStore.write_atomic(backup_path, backup_bytes.get_string_from_utf8())
			if kept != OK:
				last_error = "could not keep the old run as %s: %s" % [backup_path, error_string(kept)]
				return REFUSED_BACKUP
		_backup_path = ""
		_backup_bytes = PackedByteArray()
	var file_doc := {"schema": SCHEMA, "generation": generation_now + 1, "run": next}
	var err := SafeStore.write_atomic(path, JSON.stringify(file_doc, "  ", true, true))
	if err != OK:
		last_error = "could not write %s: %s" % [path, error_string(err)]
		return REFUSED_WRITE
	_generation = generation_now + 1
	_doc = next
	return ""


func keep_prev() -> bool:
	last_error = ""
	var read := _read()
	if read["state"] != "ok":
		return true
	var held = get_script().new(path + ".prev")._read()
	if held["state"] == "newer":
		last_error = "kept the newer-schema %s.prev: %s" % [path, held["why"]]
		return false
	var err := SafeStore.write_atomic(path + ".prev", read["bytes"].get_string_from_utf8())
	if err != OK:
		last_error = "could not keep the old run as %s.prev: %s" % [path, error_string(err)]
		return false
	return true


func restore_prev() -> bool:
	last_error = ""
	var prev = get_script().new(path + ".prev")
	var back: Dictionary = prev._read()
	if back["state"] != "ok":
		last_error = "no run to restore from %s.prev: %s" % [path, back.get("why", back["state"])]
		return false
	var current := _read()
	if current["state"] == "newer":
		last_error = "kept the newer-schema run: %s" % current["why"]
		return false
	if current["state"] == "unreadable":
		var bad := SafeStore.quarantine(path)
		if bad.is_empty():
			last_error = "%s and could not be moved aside" % current["why"]
			return false
	var generation := maxi(int(back["generation"]), int(current.get("generation", 0))) + 1
	var file_doc := {"schema": SCHEMA, "generation": generation, "run": back["run"]}
	var tmp := path + ".prev.tmp"
	if current["state"] == "ok":
		var held := SafeStore.write_atomic(tmp, current["bytes"].get_string_from_utf8())
		if held != OK:
			last_error = "could not keep the replaced run as %s: %s" % [tmp, error_string(held)]
			return false
	var err := SafeStore.write_atomic(path, JSON.stringify(file_doc, "  ", true, true))
	if err != OK:
		DirAccess.remove_absolute(tmp)
		last_error = "could not write %s: %s" % [path, error_string(err)]
		return false
	_doc = {}
	_generation = 0
	refusal = ""
	if current["state"] == "ok":
		if DirAccess.rename_absolute(tmp, path + ".prev") != OK:
			last_error = "restored the run but could not keep the replaced one as %s.prev" % path
			return false
	else:
		DirAccess.remove_absolute(path + ".prev")
	return true


func clear() -> bool:
	var read := _read()
	var seen := maxi(_generation, int(read.get("generation", 0)))
	_doc = {}
	_generation = 0
	refusal = ""
	last_error = ""
	_backup_path = ""
	_backup_bytes = PackedByteArray()
	if not FileAccess.file_exists(path):
		return true
	if read["state"] == "ok" or read["state"] == "tombstone":
		var tomb := {"schema": SCHEMA, "generation": seen + 1, "ended": true}
		var wrote := SafeStore.write_atomic(path, JSON.stringify(tomb, "  ", true, true))
		if wrote != OK:
			last_error = "could not write %s: %s" % [path, error_string(wrote)]
			return false
		_generation = seen + 1
		return true
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		last_error = "could not remove %s: %s" % [path, error_string(err)]
		return false
	return true


static func merge(ours: Dictionary, theirs: Dictionary) -> Dictionary:
	var out := ours.duplicate(true)
	var spent: Dictionary = out.get("retries_spent", {}).duplicate()
	var other: Dictionary = theirs.get("retries_spent", {})
	for w in other:
		spent[str(w)] = maxi(int(spent.get(str(w), 0)), int(other[w]))
	if not spent.is_empty() or out.has("retries_spent"):
		out["retries_spent"] = spent
	if bool(theirs.get("ended", false)):
		out["ended"] = true
	if bool(theirs.get("death_save_spent", false)):
		out["death_save_spent"] = true
	var cleared: Array = out.get("worlds_cleared", []).duplicate()
	for w in theirs.get("worlds_cleared", []):
		if not cleared.has(w):
			cleared.append(w)
	if not cleared.is_empty() or out.has("worlds_cleared"):
		out["worlds_cleared"] = cleared
	return out


func refusal_sentence() -> String:
	return String(SENTENCES.get(refusal, ""))


func _refuse(cause: String, why: String) -> Dictionary:
	refusal = cause
	_refusal_why = why
	last_error = "not saving: %s" % why
	return {}


func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"state": "missing"}
	var bytes := FileAccess.get_file_as_bytes(path)
	var parsed = SafeStore.parse(bytes.get_string_from_utf8(), TYPE_DICTIONARY)
	if parsed == null:
		return {"state": "unreadable", "why": "unreadable %s" % path}
	var version := 0
	if parsed.has("schema"):
		if not (typeof(parsed["schema"]) in [TYPE_INT, TYPE_FLOAT]):
			return {"state": "unreadable", "why": "%s has a schema that is not a number" % path}
		version = int(parsed["schema"])
	if version > SCHEMA:
		return {"state": "newer", "why": "%s is schema %d, written by a newer build; this build reads up to %d" % [path, version, SCHEMA]}
	if version < 0:
		return {"state": "unreadable", "why": "%s has schema %d" % [path, version]}
	var from_version := version
	while version < SCHEMA:
		parsed = call(MIGRATIONS[version], parsed)
		version += 1
	if bool(parsed.get("ended", false)) and not parsed.has("run") and typeof(parsed.get("generation", 0)) in [TYPE_INT, TYPE_FLOAT]:
		return {"state": "tombstone", "generation": int(parsed.get("generation", 0))}
	if not (parsed.get("run") is Dictionary) or not (typeof(parsed.get("generation", 0)) in [TYPE_INT, TYPE_FLOAT]):
		return {"state": "unreadable", "why": "%s has no run document" % path}
	if not _whole_numbers(parsed["run"]):
		return {"state": "unreadable", "why": "%s has a retries_spent or worlds_cleared value that is not a number" % path}
	return {"state": "ok", "run": parsed["run"], "generation": int(parsed.get("generation", 0)), "from_version": from_version, "bytes": bytes}


func _migrate_0(doc: Dictionary) -> Dictionary:
	var run: Dictionary = doc.get("run", {}).duplicate(true) if doc.get("run") is Dictionary else {}
	var pairs = run.get("retries_spent")
	if pairs is Array:
		var spent := {}
		for pair in pairs:
			if pair is Array and pair.size() == 2 and _is_number(pair[0]) and _is_number(pair[1]):
				spent[str(int(pair[0]))] = int(pair[1])
		run["retries_spent"] = spent
	return {"schema": 1, "generation": int(doc.get("generation", 0)), "run": run}


static func _whole_numbers(run: Dictionary) -> bool:
	if run.has("retries_spent"):
		if not (run["retries_spent"] is Dictionary):
			return false
		for w in run["retries_spent"]:
			if not _is_number(run["retries_spent"][w]):
				return false
			run["retries_spent"][w] = int(run["retries_spent"][w])
	if run.has("worlds_cleared"):
		if not (run["worlds_cleared"] is Array):
			return false
		for i in run["worlds_cleared"].size():
			if not _is_number(run["worlds_cleared"][i]):
				return false
			run["worlds_cleared"][i] = int(run["worlds_cleared"][i])
	return true


static func _is_number(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
