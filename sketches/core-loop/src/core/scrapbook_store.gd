extends RefCounted


const SafeStore := preload("res://src/core/safe_store.gd")

const MAX_PAGES := 60
const FOLDER := "scrapbook"

var dir := ""
var last_error := ""


func _init(storage_dir := "user://") -> void:
	dir = storage_dir.path_join(FOLDER)


func save(page: Dictionary) -> String:
	last_error = ""
	var id := safe_id(String(page.get("run_id", "")))
	if id.is_empty():
		last_error = "page has no run_id"
		return ""
	var made := DirAccess.make_dir_recursive_absolute(dir)
	if made != OK:
		last_error = "could not make %s: %s" % [dir, error_string(made)]
		return ""
	var doc := page.duplicate(true)
	var panels: Array = []
	var raw_panels = page.get("panels", [])
	for i in (raw_panels.size() if raw_panels is Array else 0):
		var panel: Dictionary = (raw_panels[i] as Dictionary).duplicate(true) if raw_panels[i] is Dictionary else {}
		var shot = panel.get("shot")
		var png := "%s_%d.png" % [id, i]
		panel["shot"] = ""
		if shot is Image and not (shot as Image).is_empty():
			if _write_png(shot, dir.path_join(png)) == OK:
				panel["shot"] = png
		else:
			_remove(dir.path_join(png))
		panels.append(panel)
	doc["panels"] = panels
	var path := dir.path_join(id + ".json")
	var err := SafeStore.write_atomic(path, JSON.stringify(doc, "  ", true, true))
	if err != OK:
		last_error = "could not write %s: %s" % [path, error_string(err)]
		return ""
	prune()
	return path


func load_all(with_shots := true) -> Array:
	var entries := _entries()
	_prune_entries(entries)
	var out: Array = []
	for i in mini(entries.size(), MAX_PAGES):
		out.append(_page_from(entries[i]["doc"], with_shots))
	return out


func summaries() -> Array:
	return load_all(false)


func load_shots(page: Dictionary) -> Dictionary:
	var panels = page.get("panels", [])
	if not panels is Array:
		return page
	for panel in panels:
		if panel is Dictionary and panel.get("shot") == null:
			panel["shot"] = _load_shot(String(panel.get("shot_file", "")), String(page.get("run_id", "")))
	return page


static func is_won(page: Dictionary) -> bool:
	if page.has("outcome"):
		return String(page["outcome"]) == "won"
	return bool(page.get("won", false))


func prune() -> int:
	return _prune_entries(_entries())


func _prune_entries(entries: Array) -> int:
	var gone := 0
	for i in range(MAX_PAGES, entries.size()):
		var id: String = entries[i]["id"]
		_remove(dir.path_join(id + ".json"))
		for file in DirAccess.get_files_at(dir):
			if _is_shot_of(file, id):
				_remove(dir.path_join(file))
		gone += 1
	return gone


static func _is_shot_of(file: String, id: String) -> bool:
	if not (file.begins_with(id + "_") and file.ends_with(".png")):
		return false
	var middle := file.substr(id.length() + 1, file.length() - id.length() - 5)
	return middle.is_valid_int() and not middle.begins_with("-") and not middle.begins_with("+")


static func safe_id(run_id: String) -> String:
	var out := ""
	for ch in run_id:
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch in "-_" else "_"
	return out


func _entries() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".json"):
			continue
		var doc = SafeStore.parse(FileAccess.get_file_as_string(dir.path_join(file)), TYPE_DICTIONARY)
		if doc == null:
			continue
		out.append({"id": file.get_basename(), "doc": doc, "ended": float(doc.get("ended_unix", 0.0)) if (doc.get("ended_unix") is float or doc.get("ended_unix") is int) else 0.0})
	out.sort_custom(func(a, b): return a["ended"] > b["ended"] or (a["ended"] == b["ended"] and a["id"] > b["id"]))
	return out


func _page_from(doc: Dictionary, with_shots: bool) -> Dictionary:
	doc = doc.duplicate(true)
	var panels = doc.get("panels", [])
	if not panels is Array:
		panels = []
	var run_id := String(doc.get("run_id", ""))
	for panel in panels:
		if not panel is Dictionary:
			continue
		var name = panel.get("shot", "")
		panel["shot_file"] = name if name is String else ""
		panel["shot"] = _load_shot(panel["shot_file"], run_id) if with_shots else null
	doc["panels"] = panels
	return doc


func _load_shot(name: String, run_id: String) -> Image:
	if name.is_empty() or name != name.get_file():
		return null
	var id := safe_id(run_id)
	if id.is_empty() or not _is_shot_of(name, id):
		return null
	var path := dir.path_join(name)
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(path)


func _write_png(image: Image, path: String) -> Error:
	var tmp := SafeStore.tmp_path(path)
	var err := image.save_png(tmp)
	if err != OK:
		return err
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		_remove(tmp)
	return err


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
