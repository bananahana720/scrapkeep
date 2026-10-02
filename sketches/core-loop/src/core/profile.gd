extends RefCounted

# The player's progress as one versioned document, saved as profile.json: unlocked
# pilots, worlds and cosmetics, earned achievements, equipped cosmetics, stats and the
# last pilot. Preferences live in settings_store.gd. The store knows no starters and
# reads no clock; the caller passes the time an achievement was earned. Mutators change
# memory and save() writes, replacing the file whole. A file this build cannot read is
# never overwritten: unreadable files are kept as .bad, and a save from a newer build is
# left alone for the session.

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
var can_save := true

var _doc := {}
var _backup_path := ""
var _backup_bytes := PackedByteArray()


func _init(file_path := "user://profile.json") -> void:
	path = file_path
	_doc = _defaults()


func load_profile() -> bool:
	_doc = _defaults()
	last_error = ""
	can_save = true
	_backup_path = ""
	_backup_bytes = PackedByteArray()
	if not FileAccess.file_exists(path):
		return true
	var bytes := FileAccess.get_file_as_bytes(path)
	var parsed = SafeStore.parse(bytes.get_string_from_utf8(), TYPE_DICTIONARY)
	if parsed == null:
		return _reject("unreadable %s" % path)
	var version := 0
	if parsed.has("schema"):
		if not (typeof(parsed["schema"]) in [TYPE_INT, TYPE_FLOAT]):
			return _reject("%s has a schema that is not a number" % path)
		version = int(parsed["schema"])
	if version > SCHEMA:
		can_save = false
		last_error = "%s is schema %d and this build reads up to %d; playing without saving" % [path, version, SCHEMA]
		return false
	if version < 0:
		return _reject("%s has schema %d" % [path, version])
	var from_version := version
	while version < SCHEMA:
		parsed = call(MIGRATIONS[version], parsed)
		version += 1
	if not _shape_ok(parsed):
		return _reject("%s has fields of the wrong type" % path)
	_doc = _defaults()
	for key in parsed:
		_doc[key] = parsed[key]
	_doc["schema"] = SCHEMA
	_doc["generation"] = int(_doc["generation"])
	if from_version < SCHEMA:
		_backup_path = "%s.v%d" % [path, from_version]
		_backup_bytes = bytes
	return true


func save() -> bool:
	if not can_save:
		last_error = "not saving: %s was written by a newer build" % path
		return false
	if not _backup_path.is_empty():
		if not FileAccess.file_exists(_backup_path):
			var kept := SafeStore.write_atomic(_backup_path, _backup_bytes.get_string_from_utf8())
			if kept != OK:
				last_error = "could not keep the old save as %s: %s" % [_backup_path, error_string(kept)]
				return false
		_backup_path = ""
		_backup_bytes = PackedByteArray()
	var next := _doc.duplicate()
	next["generation"] = int(_doc["generation"]) + 1
	var err := SafeStore.write_atomic(path, JSON.stringify(next, "  "))
	if err != OK:
		last_error = error_string(err)
		return false
	_doc["generation"] = next["generation"]
	return true


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


func earn(id: String, at: float) -> bool:
	if earned(id):
		return false
	_doc["achievements"][id] = at
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


func _reject(why: String) -> bool:
	var kept := SafeStore.quarantine(path)
	if kept.is_empty():
		can_save = false
		last_error = "%s and could not be moved aside; not saving this session" % why
	else:
		last_error = "%s; kept as %s" % [why, kept]
	return false


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
