extends SceneTree

const Schema := preload("res://src/world/park/park_schema.gd")

func _initialize() -> void:
	var map_id := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
	var park := Schema.load_park("res://src/world/park/%s.json" % map_id, Schema.stage_context("park_dam"))
	var lines := Schema.read_file("res://tools/park_lines/%s.json" % map_id)
	var errors: Array = park["errors"] + lines["errors"]
	if errors.is_empty():
		# Trial world-1 context also checks mounting and home pack references.
		errors += Schema.validate(park["data"], Schema.stage_context("park_dam"))
		errors += Schema.validate_lines(lines["data"], park["data"])
	if not errors.is_empty():
		printerr("wgen: schema FAIL " + Schema.describe(errors))
		quit(1)
	else:
		print("wgen: schema PASS %s park + six pilot lines + floor + world-1 context" % map_id)
		quit(0)
