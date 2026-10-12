extends "res://src/game.gd"

# A private script instance for traversal only. Neither TABLES nor park_defs.gd is changed.
func _chosen_table():
	var map_id := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
	assert(map_id.begins_with("park_wgen_s") and FileAccess.file_exists("res://src/world/park/%s.json" % map_id))
	var trial := GDScript.new()
	trial.source_code = FileAccess.get_file_as_string("res://src/core/park_defs.gd").replace('"map": "park_dam"', '"map": "%s"' % map_id)
	assert(trial.reload() == OK)
	return trial
