extends SceneTree

const Schema := preload("res://src/world/park/park_schema.gd")
const TrialContext := preload("res://tools/blender/wgen/context.gd")

func _initialize() -> void:
	var schema_path := "res://src/world/park/park_schema.gd"
	var table_path := "res://src/core/park_defs.gd"
	var schema_hash := FileAccess.get_sha256(schema_path)
	var table_hash := FileAccess.get_sha256(table_path)
	var shipped: Dictionary = Schema.read_file("res://src/world/park/park_test.json")["data"]
	var before := Schema.validate(shipped)
	var map_id := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
	var trial: Dictionary = Schema.read_file("res://src/world/park/%s.json" % map_id)["data"]
	var unregistered := Schema.validate(trial)
	if unregistered.size() != 1 or unregistered[0]["rule"] != "reference":
		printerr("wgen: context test FAIL unregistered map must fail")
		quit(1)
		return
	TrialContext.install()
	var errors := Schema.validate(trial)
	var bad: Dictionary = trial.duplicate(true)
	bad["park_rows"][0]["stamp"] = "trial_unknown_stamp"
	var planted := Schema.validate(bad)
	var unchanged := Schema.validate(shipped) == before and FileAccess.get_sha256(schema_path) == schema_hash and FileAccess.get_sha256(table_path) == table_hash
	var passed := errors.is_empty() and not planted.is_empty() and unchanged
	print("wgen: context test %s registered errors %d, planted errors %d, shipped validation and disk hashes unchanged %s" % ["PASS" if passed else "FAIL", errors.size(), planted.size(), unchanged])
	quit(0 if passed else 1)
