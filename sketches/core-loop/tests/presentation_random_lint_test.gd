extends SceneTree

const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	var t := T.new("presentation_random_lint_test")
	# All of src: one stray global draw anywhere shifts seeded runs or player luck.
	var paths: Array[String] = []
	_collect("res://src", paths)
	var seed_sites := ["res://src/game.gd", "res://src/core/run_state.gd"]
	var bare := RegEx.create_from_string("(?<![A-Za-z0-9_.])(?:randf|randi|randf_range|randi_range|randfn|shuffle|pick_random)\\s*\\(")
	var array_draw := RegEx.create_from_string("\\.(?:shuffle|pick_random)\\s*\\(")
	var reseed := RegEx.create_from_string("(?<![A-Za-z0-9_.])(?:seed|randomize)\\(")
	var violations := []
	var session_seeds := 0
	for path in paths:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var code := lines[i].split("#", true, 1)[0]
			# A global reseed is allowed only where a fixed route asks for it.
			if reseed.search(code) != null and not (path == "res://src/build/build.gd" and lines[i].ends_with("# lint: route seed")):
				violations.append("%s:%d" % [path, i + 1])
			if bare.search(code) != null or array_draw.search(code) != null:
				# Game takes the session seed at creation; a bare RunState takes its own.
				if path in seed_sites and lines[i].ends_with("# lint: session seed"):
					session_seeds += 1
				else:
					violations.append("%s:%d" % [path, i + 1])
	t.check("presentation uses private random streams", violations.is_empty(), ", ".join(violations))
	t.check("the session seed is drawn in exactly two marked places", session_seeds == 2, "%d marked draws" % session_seeds)
	quit(t.verdict())


func _collect(folder: String, paths: Array[String]) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			paths.append(folder.path_join(file))
	for child in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(child), paths)
