extends RefCounted


static func matching(t, roots: Array, pattern: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.new()
	if re.compile(pattern, false) != OK or not re.is_valid():
		t.check("source scan pattern compiles", false, pattern)
		return out
	if roots.is_empty():
		t.check("source scan has roots", false, "no root folder")
		return out
	for root in roots:
		var files: Array[String] = []
		if not _walk(t, String(root), files):
			continue
		if files.is_empty():
			t.check("source scan finds scripts under " + String(root), false, "no .gd file")
			continue
		for path in files:
			var text := FileAccess.get_file_as_string(path)
			var err := FileAccess.get_open_error()
			if err != OK or text.is_empty():
				t.check("source scan reads " + path, false, "error %d, %d characters" % [err, text.length()])
				continue
			if re.search(text) != null:
				out.append(path)
	out.sort()
	return out


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
