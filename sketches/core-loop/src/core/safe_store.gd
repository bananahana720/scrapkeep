extends RefCounted

# Shared file handling for the user:// stores (codex, UI profile, settings, reward
# ceremony). A save goes through a temp file in the same directory and a rename, so a
# save cut short leaves the old file whole. A load that cannot parse keeps the file as a
# .bad copy, so the next save cannot replace it with an empty store.


static func tmp_path(path: String) -> String:
	return path + ".tmp"


static func write_atomic(path: String, text: String) -> Error:
	var tmp := tmp_path(path)
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
	return err


# The parsed value when the text is JSON of the wanted type (TYPE_DICTIONARY or
# TYPE_ARRAY), else null.
static func parse(text: String, type: int) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	if typeof(json.data) != type:
		return null
	return json.data


# Moves an unreadable file aside and returns where it went, or "" when it could not.
static func quarantine(path: String) -> String:
	var bad := path + ".bad"
	var n := 1
	while FileAccess.file_exists(bad):
		bad = "%s.bad%d" % [path, n]
		n += 1
	if DirAccess.rename_absolute(path, bad) != OK:
		return ""
	return bad
