extends RefCounted


static func tmp_path(path: String) -> String:
	return "%s.%d.tmp" % [path, OS.get_process_id()]


static func write_atomic(path: String, text: String) -> Error:
	var tmp := tmp_path(path)
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_string(text)
	var write_err := file.get_error()
	file.close()
	if not stored or write_err != OK:
		DirAccess.remove_absolute(tmp)
		return write_err if write_err != OK else FAILED
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
	return err


static func append_line(path: String, line: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.seek_end()
	var stored := file.store_line(line)
	var err := file.get_error()
	file.close()
	return err if err != OK else (OK if stored else FAILED)


static func parse(text: String, type: int, shape := {}) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	if typeof(json.data) != type:
		return null
	for key in shape:
		if json.data.has(key) and not _shape_ok(json.data[key], shape[key]):
			return null
	return json.data


const STRINGS := "strings"
const NUMBERS := "numbers"
const STRING_MAP := "string_map"
const DICT := "dict"


static func is_strings(value: Variant) -> bool:
	return _shape_ok(value, STRINGS)


static func _shape_ok(value: Variant, kind: String) -> bool:
	if kind == STRINGS:
		return value is Array and _all(value, TYPE_STRING)
	if kind == NUMBERS:
		return value is Dictionary and _all(value.values(), TYPE_FLOAT, TYPE_INT)
	if kind == STRING_MAP:
		return value is Dictionary and _all(value.values(), TYPE_STRING)
	if kind == DICT:
		return value is Dictionary
	return false


static func _all(items: Array, type: int, alt := -1) -> bool:
	for item in items:
		if typeof(item) != type and typeof(item) != alt:
			return false
	return true


static func quarantine(path: String) -> String:
	var bad := path + ".bad"
	var n := 1
	while FileAccess.file_exists(bad) or DirAccess.dir_exists_absolute(bad):
		bad = "%s.bad%d" % [path, n]
		n += 1
	if DirAccess.rename_absolute(path, bad) != OK:
		return ""
	return bad
