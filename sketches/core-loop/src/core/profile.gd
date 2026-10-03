extends RefCounted

# The player's progress as one versioned document, saved as profile.json: unlocked
# pilots, worlds and cosmetics, earned achievements, equipped cosmetics, stats and the
# last pilot. Preferences live in settings_store.gd. The store knows no starters and
# reads no clock; the caller passes the time an achievement was earned. Mutators change
# memory and save() writes. A store cannot save until it has loaded, and a save that finds
# a newer generation on disk merges it in instead of replacing it. A file this build
# cannot read is never overwritten: unreadable files are kept as .bad, and a file from a
# newer build is left alone.

const SafeStore := preload("res://src/core/safe_store.gd")

const SCHEMA := 1

# From-version to the method that returns the document one version up.
const MIGRATIONS := {0: "_migrate_0"}

const SHAPE := {
	"pilots": SafeStore.STRINGS,
	"worlds": SafeStore.STRINGS,
	"cosmetics": SafeStore.STRINGS,
	"achievements": SafeStore.NUMBERS,
	"equipped": SafeStore.STRING_MAP,
	"stats": SafeStore.NUMBERS,
}

var path := ""
var last_error := ""
var can_save := false

var _doc := {}
var _refusal := ""
var _on_disk := false
var _loaded_generation := 0
var _backup_path := ""
var _backup_bytes := PackedByteArray()


func _init(file_path := "user://profile.json") -> void:
	path = file_path
	_refusal = "not saving: %s has not been loaded" % path
	_doc = _defaults()


func load_profile() -> bool:
	_doc = _defaults()
	last_error = ""
	_refusal = ""
	can_save = true
	_on_disk = false
	_loaded_generation = 0
	_backup_path = ""
	_backup_bytes = PackedByteArray()
	var read := _read()
	if read["state"] == "missing":
		return true
	if read["state"] == "newer":
		return _refuse("%s; playing without saving" % read["why"])
	if read["state"] != "ok":
		return _reject(read["why"])
	_doc = read["doc"]
	_on_disk = true
	_loaded_generation = int(_doc["generation"])
	if read["from_version"] < SCHEMA:
		_backup_path = "%s.v%d" % [path, read["from_version"]]
		_backup_bytes = read["bytes"]
	return true


func save() -> bool:
	if not can_save:
		last_error = _refusal
		return false
	var read := _read()
	var next := _doc.duplicate(true)
	var backup_path := _backup_path
	var backup_bytes := _backup_bytes
	if read["state"] == "newer":
		last_error = "not saving: %s was replaced by a newer build since it was loaded" % path
		return false
	if read["state"] != "missing" and read["state"] != "ok":
		last_error = "not saving: %s changed since it was loaded and cannot be read (%s)" % [path, read["why"]]
		return false
	if read["state"] == "ok" and (not _on_disk or int(read["doc"]["generation"]) != _loaded_generation):
		next = merge(next, read["doc"])
		if backup_path.is_empty() and read["from_version"] < SCHEMA:
			backup_path = "%s.v%d" % [path, read["from_version"]]
			backup_bytes = read["bytes"]
	if not backup_path.is_empty():
		var kept := _keep_backup(backup_path, backup_bytes)
		if kept != OK:
			last_error = "could not keep the old save as %s: %s" % [backup_path, error_string(kept)]
			return false
		_backup_path = ""
		_backup_bytes = PackedByteArray()
	next["generation"] = int(next["generation"]) + 1
	var err := SafeStore.write_atomic(path, JSON.stringify(next, "  ", true, true))
	if err != OK:
		last_error = "could not write %s: %s" % [path, error_string(err)]
		return false
	_doc = next
	_on_disk = true
	_loaded_generation = int(next["generation"])
	last_error = ""
	return true


# What two writers of one file both did, as one document: lists are the union,
# achievements keep the earliest time and stats the larger value, an equipped slot
# both hold and last_pilot are the saver's, and a slot or key only the other side
# holds is kept. The generation is the larger of the two.
static func merge(ours: Dictionary, theirs: Dictionary) -> Dictionary:
	var out := ours.duplicate(true)
	for key in ["pilots", "worlds", "cosmetics"]:
		for id in theirs.get(key, []):
			if not out[key].has(id):
				out[key].append(id)
	var times: Dictionary = theirs.get("achievements", {})
	for id in times:
		if not out["achievements"].has(id) or times[id] < out["achievements"][id]:
			out["achievements"][id] = times[id]
	var stats: Dictionary = theirs.get("stats", {})
	for stat_name in stats:
		if not out["stats"].has(stat_name) or stats[stat_name] > out["stats"][stat_name]:
			out["stats"][stat_name] = stats[stat_name]
	var worn: Dictionary = theirs.get("equipped", {})
	for slot in worn:
		if not out["equipped"].has(slot):
			out["equipped"][slot] = worn[slot]
	for key in theirs:
		if not out.has(key):
			out[key] = theirs[key]
	out["generation"] = maxi(int(ours.get("generation", 0)), int(theirs.get("generation", 0)))
	return out


func generation() -> int:
	return int(_doc["generation"])


func has_pilot(id: String) -> bool:
	return _doc["pilots"].has(id)


func unlock_pilot(id: String) -> void:
	_add(_doc["pilots"], id)


func has_world(id: String) -> bool:
	return _doc["worlds"].has(id)


func unlock_world(id: String) -> void:
	_add(_doc["worlds"], id)


func has_cosmetic(id: String) -> bool:
	return _doc["cosmetics"].has(id)


func unlock_cosmetic(id: String) -> void:
	_add(_doc["cosmetics"], id)


func earned(id: String) -> bool:
	return _doc["achievements"].has(id)


func earned_at(id: String) -> int:
	return int(_doc["achievements"].get(id, 0))


func earn(id: String, at: float) -> bool:
	if earned(id):
		return false
	_doc["achievements"][id] = int(floorf(at))
	return true


func equipped(pilot: String, slot: String) -> String:
	return String(_doc["equipped"].get("%s/%s" % [pilot, slot], ""))


func equip(pilot: String, slot: String, cosmetic_id: String) -> void:
	_doc["equipped"]["%s/%s" % [pilot, slot]] = cosmetic_id


func stat(stat_name: String) -> float:
	return float(_doc["stats"].get(stat_name, 0.0))


func add_stat(stat_name: String, amount := 1.0) -> void:
	_doc["stats"][stat_name] = stat(stat_name) + amount


func set_stat(stat_name: String, value: float) -> void:
	_doc["stats"][stat_name] = value


func last_pilot() -> String:
	return String(_doc["last_pilot"])


func set_last_pilot(id: String) -> void:
	_doc["last_pilot"] = id


func _add(list: Array, id: String) -> void:
	if not list.has(id):
		list.append(id)


func _refuse(why: String) -> bool:
	can_save = false
	_refusal = "not saving: %s" % why
	last_error = why
	return false


func _reject(why: String) -> bool:
	var kept := SafeStore.quarantine(path)
	if kept.is_empty():
		return _refuse("%s and could not be moved aside; not saving this session" % why)
	last_error = "%s; kept as %s" % [why, kept]
	return false


# Where the pending backup goes: the name itself, or the next free .1, .2 when that
# name holds different bytes. A name already holding these bytes is the backup.
func _keep_backup(base: String, bytes: PackedByteArray) -> Error:
	var target := base
	var n := 1
	while FileAccess.file_exists(target):
		if FileAccess.get_file_as_bytes(target) == bytes:
			return OK
		target = "%s.%d" % [base, n]
		n += 1
	return SafeStore.write_atomic(target, bytes.get_string_from_utf8())


# The file at path as a state: missing, unreadable, bad_schema, newer, wrong_type or
# ok. An ok read carries the migrated document, the schema it was written at and the
# bytes it came from; the other states carry why.
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
			return {"state": "bad_schema", "why": "%s has a schema that is not a number" % path}
		version = int(parsed["schema"])
	if version > SCHEMA:
		return {"state": "newer", "why": "%s is schema %d, written by a newer build; this build reads up to %d" % [path, version, SCHEMA]}
	if version < 0:
		return {"state": "bad_schema", "why": "%s has schema %d" % [path, version]}
	var from_version := version
	while version < SCHEMA:
		parsed = call(MIGRATIONS[version], parsed)
		version += 1
	if not _shape_ok(parsed):
		return {"state": "wrong_type", "why": "%s has fields of the wrong type" % path}
	var doc := _defaults()
	for key in parsed:
		doc[key] = parsed[key]
	doc["schema"] = SCHEMA
	doc["generation"] = int(doc["generation"])
	for id in doc["achievements"]:
		doc["achievements"][id] = int(floorf(doc["achievements"][id]))
	return {"state": "ok", "doc": doc, "from_version": from_version, "bytes": bytes}


func _shape_ok(doc: Dictionary) -> bool:
	if SafeStore.parse(JSON.stringify(doc), TYPE_DICTIONARY, SHAPE) == null:
		return false
	if doc.has("last_pilot") and typeof(doc["last_pilot"]) != TYPE_STRING:
		return false
	if doc.has("generation") and not (typeof(doc["generation"]) in [TYPE_INT, TYPE_FLOAT]):
		return false
	return true


func _defaults() -> Dictionary:
	return {
		"schema": SCHEMA,
		"generation": 0,
		"pilots": [],
		"worlds": [],
		"achievements": {},
		"cosmetics": [],
		"equipped": {},
		"stats": {},
		"last_pilot": "",
	}


func _migrate_0(doc: Dictionary) -> Dictionary:
	var out := _defaults()
	for key in doc:
		out[key] = doc[key]
	out["schema"] = 1
	return out
