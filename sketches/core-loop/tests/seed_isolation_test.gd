# smoke: solo (a traversal batch and an isolated child, bounded to 75 seconds)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	var t := T.new("seed_isolation_test")
	var base := OS.get_user_data_dir().path_join("seed-isolation-%d" % OS.get_process_id())
	var jobs := []
	for mode in ["batch", "isolated"]:
		jobs.append({"script": "res://tools/traversal_line.gd", "args": [
			"--pilot=sable", "--seeds=1,2" if mode == "batch" else "--seeds=2",
			"--trace", "--out=" + base.path_join(mode)]})
	var results := ChildRuns.run(jobs, 75.0)
	var hashes: Array[String] = []
	var traces: Array = []
	for i in jobs.size():
		var result: Dictionary = results[i]
		var errors: Array = ChildRuns.summary(result)["errors"]
		t.check("child %d completed" % i, result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
			"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], errors])
		var path := base.path_join("batch" if i == 0 else "isolated").path_join("sable-seed-2-trace.json")
		var doc = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		var ticks: Array = doc.get("ticks", []) if doc is Dictionary else []
		t.check("child %d measured traversal" % i, ticks.size() > 100, "%d ticks" % ticks.size())
		traces.append(ticks)
		hashes.append(JSON.stringify(ticks).sha256_text())
	var first := 0
	for i in mini(traces[0].size(), traces[1].size()):
		if traces[0][i] != traces[1][i]:
			first = i + 1
			break
	if first == 0 and traces[0].size() != traces[1].size():
		first = mini(traces[0].size(), traces[1].size()) + 1
	t.check("second seed repeats every tick in a fresh process", not traces[0].is_empty() and hashes[0] == hashes[1],
		"batch %s, isolated %s, first differing tick %d; evidence %s" % [hashes[0], hashes[1], first, base])
	var code := t.verdict()
	print("seed_isolation_test: %s" % ("PASS" if code == 0 else "FAIL"))
	quit(code)
