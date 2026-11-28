extends RefCounted


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := root.path_join(name)
		if dir.current_is_dir():
			out.append_array(_gd_files(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _declares(path: String, pattern: String) -> bool:
	var re := RegEx.new()
	re.compile(pattern)
	return re.search(FileAccess.get_file_as_string(path)) != null


func run(t) -> void:
	var capture_state := "(?m)^(static\\s+)?(var|const)\\s+(_busy|_shots|shot_dir|SHOT_DIR|SHEET_[A-Z_]+|SAME_LUMA)\\b"
	var capture_calls := "(?m)^(static\\s+)?func\\s+(shot|shot_detailed|qa_pack_detailed|contact_sheet|sheet_detailed|sheet_ids|sheet_grid)\\("
	t.check("dev_console.gd declares no still, QA-pack or sheet state", not _declares("res://src/dev/dev_console.gd", capture_state))
	t.check("dev_console.gd declares no capture call", not _declares("res://src/dev/dev_console.gd", capture_calls))
	t.check("dev_capture.gd owns the capture state", _declares("res://src/dev/dev_capture.gd", capture_state))

	var craft_caches := "(?m)^(static\\s+)?var\\s+(_mesh_cache|_fx_mats)\\b"
	t.check("live_world_actors.gd declares no mesh or material cache", not _declares("res://src/experimental/live_world_actors.gd", craft_caches))
	t.check("live_world_actors.gd declares no mesh builder", not _declares("res://src/experimental/live_world_actors.gd", "(?m)^(static\\s+)?func\\s+\\w+_mesh\\("))
	t.check("live_world_actor_craft.gd owns the mesh and material caches", _declares("res://src/experimental/live_world_actor_craft.gd", craft_caches))

	var cooldowns := "(?m)^static\\s+var\\s+_last_trigger_s\\b"
	t.eq("no script under src/ keeps audio cooldowns in a static var",
		_gd_files("res://src").filter(func(path: String) -> bool: return _declares(path, cooldowns)), [])
