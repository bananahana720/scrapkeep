extends SceneTree

const SourceScan := preload("res://tests/support/source_scan.gd")
const T := preload("res://tests/support/t.gd")

const BARE := "(?<![A-Za-z0-9_.])(?:randf|randi|randf_range|randi_range|randfn|shuffle|pick_random)\\s*\\("
const ARRAY_DRAW := "\\.(?:shuffle|pick_random)\\s*\\("
const RESEED := "(?<![A-Za-z0-9_.])(?:seed|randomize)\\("


func _initialize() -> void:
	var t := T.new("presentation_random_lint_test")
	# All of src: one stray global draw anywhere shifts seeded runs or player luck.
	var sources := SourceScan.sources(t, ["res://src"])
	var seed_sites := ["res://src/game.gd", "res://src/core/run_state.gd"]
	var violations := []
	var session_seeds := 0
	for path in sources:
		var lines := String(sources[path]).split("\n")
		for i in lines.size():
			var code := lines[i].split("#", true, 1)[0]
			# A global reseed is allowed only where a fixed route asks for it.
			if not SourceScan.search(t, code, RESEED).is_empty() and not (path == "res://src/build/build.gd" and lines[i].ends_with("# lint: route seed")):
				violations.append("%s:%d" % [path, i + 1])
			if not SourceScan.search(t, code, BARE).is_empty() or not SourceScan.search(t, code, ARRAY_DRAW).is_empty():
				# Game takes the session seed at creation; a bare RunState takes its own.
				if path in seed_sites and lines[i].ends_with("# lint: session seed"):
					session_seeds += 1
				else:
					violations.append("%s:%d" % [path, i + 1])
	t.check("presentation uses private random streams", violations.is_empty(), ", ".join(violations))
	t.check("the session seed is drawn in exactly two marked places", session_seeds == 2, "%d marked draws" % session_seeds)
	quit(t.verdict())
