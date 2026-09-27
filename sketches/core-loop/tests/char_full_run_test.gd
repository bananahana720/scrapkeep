extends SceneTree

# The scripted full run (spine_run_test) reaches the summary for every class, not only
# the engineer it runs as by default. Each other class runs the same script in its own
# headless process with "--class=N", so the run is the real flow from title to summary.
#
# Evidence limit: calm scripted runs through the seams; they say nothing about feel or
# about fighting as the class.

const CLASSES := [1, 2]


func _initialize() -> void:
	var failures := 0
	var project := ProjectSettings.globalize_path("res://")
	for index in CLASSES:
		var output := []
		var code := OS.execute(OS.get_executable_path(),
			["--headless", "--path", project, "--script", "res://tests/spine_run_test.gd", "--", "--class=%d" % index], output, true)
		var text := "\n".join(output)
		var verdict := ""
		for line in text.split("\n"):
			if line.begins_with("spine_run_test"):
				verdict = line
		var ok := code == 0 and verdict.ends_with(": PASS") and not text.contains("SCRIPT ERROR")
		if not ok:
			failures += 1
			for line in text.split("\n"):
				if line.contains("-> FAIL") or line.contains("SCRIPT ERROR"):
					print("  ", line)
		print("[class %d full run] exit %d, %s -> %s" % [index, code, verdict if verdict != "" else "no verdict", "PASS" if ok else "FAIL"])
	print("char_full_run_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
