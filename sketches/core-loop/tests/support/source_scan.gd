extends RefCounted

const DECLARATION := "(?m)^\\s*(?:static\\s+|@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*"


static func matching(t, roots: Array, pattern: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(captures(t, roots, pattern).keys())
	return out


static func captures(t, roots: Array, pattern: String) -> Dictionary:
	var out := {}
	var re := _compile(t, pattern)
	if re == null:
		return out
	var texts := sources(t, roots)
	for path in texts:
		var found := re.search_all(texts[path])
		if found.is_empty():
			continue
		var rows: Array[PackedStringArray] = []
		for hit in found:
			rows.append(hit.strings)
		out[path] = rows
	return out


static func sources(t, roots: Array) -> Dictionary:
	var out := {}
	if roots.is_empty():
		t.check("source scan has roots", false, "no root folder")
		return out
	var paths: Array[String] = []
	for root in roots:
		var files: Array[String] = []
		if not _walk(t, String(root), files):
			continue
		if files.is_empty():
			t.check("source scan finds scripts under " + String(root), false, "no .gd file")
			continue
		paths.append_array(files)
	paths.sort()
	for path in paths:
		var body := text(t, path)
		if not body.is_empty():
			out[path] = body
	return out


static func text(t, path: String) -> String:
	var body := FileAccess.get_file_as_string(path)
	var err := FileAccess.get_open_error()
	if err != OK or body.is_empty():
		t.check("source scan reads " + path, false, "error %d, %d characters" % [err, body.length()])
		return ""
	return body


static func search(t, body: String, pattern: String) -> Array[RegExMatch]:
	var re := _compile(t, pattern)
	if re == null:
		var none: Array[RegExMatch] = []
		return none
	return re.search_all(body)


static func _compile(t, pattern: String) -> RegEx:
	var re := RegEx.new()
	if re.compile(pattern, false) != OK or not re.is_valid():
		t.check("source scan pattern compiles", false, pattern)
		return null
	return re


static func _walk(t, root: String, out: Array[String]) -> bool:
	var dir := DirAccess.open(root)
	if dir == null:
		t.check("source scan opens " + root, false, "error %d" % DirAccess.get_open_error())
		return false
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := root.path_join(name)
			if dir.current_is_dir():
				_walk(t, full, out)
			elif name.ends_with(".gd"):
				out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return true
