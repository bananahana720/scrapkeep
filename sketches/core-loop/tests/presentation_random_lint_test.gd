extends SceneTree

const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	var t := T.new("presentation_random_lint_test")
	var paths: Array[String] = ["res://src/combat/effects.gd", "res://src/world/contraptions.gd", "res://src/core/run_state.gd"]
	_collect("res://src/presentation", paths)
	_collect("res://src/ui", paths)
	var bare := RegEx.create_from_string("(?<![A-Za-z0-9_.])(?:randf|randi|randf_range|randi_range|randfn|shuffle|pick_random)\\s*\\(")
	var array_draw := RegEx.create_from_string("\\.(?:shuffle|pick_random)\\s*\\(")
	var violations := []
	for path in paths:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].split("#", true, 1)[0]
			if bare.search(code) != null or array_draw.search(code) != null:
				violations.append("%s:%d" % [path, i + 1])
	t.check("presentation uses private random streams", violations.is_empty(), ", ".join(violations))
	quit(t.verdict())


func _collect(folder: String, paths: Array[String]) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			paths.append(folder.path_join(file))
	for child in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(child), paths)
