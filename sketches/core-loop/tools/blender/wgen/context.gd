extends RefCounted

const Schema := preload("res://src/world/park/park_schema.gd")

# Only this trial process resolves an experimental id to the world-1 validation context.
static func install() -> String:
	var map_id := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
	assert(map_id in ["park_wgen_s1", "park_wgen_s2", "park_wgen_s3", "park_wgen_s4", "park_wgen_s5", "park_wgen_s6", "park_wgen_s7", "park_wgen_s8"])
	# GDScript constant dictionaries are frozen. Use the fixture runner's script-reload
	# mechanism, confined to this process, to add exactly one trial context.
	var schema: GDScript = load("res://src/world/park/park_schema.gd")
	var source := FileAccess.get_file_as_string("res://src/world/park/park_schema.gd")
	var marker := '"park_test": 1,'
	assert(source.contains(marker))
	schema.source_code = source.replace(marker, marker + '\n\t"%s": 1,' % map_id)
	assert(schema.reload() == OK)
	return map_id
