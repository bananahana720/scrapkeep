# smoke: solo timeout=360s (eight fresh fixture processes plus bot replay)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const TeardownNoise := preload("res://tests/support/teardown_noise.gd")
const BOT_TICKS := 30
const TRAVERSAL_TICKS := 180


func _initialize() -> void:
	var t := T.new("seed_isolation_test")
	var base := OS.get_user_data_dir().path_join("seed-isolation-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(base)
	_check_failed_trace(t, base.path_join("failed-trace"))
	if t.failures > 0:
		quit(t.verdict())
		return
	var jobs := []
	for mode in ["batch", "isolated"]:
		jobs.append({"script": "res://tools/traversal_line.gd", "args": [
			"--table=park", "--stage=0", "--pilot=sable",
			"--seeds=1,2,3,4,5,6,7,8" if mode == "batch" else "--seeds=8",
			"--ticks=%d" % TRAVERSAL_TICKS, "--trace", "--out=" + base.path_join(mode)]})
	for mode in ["bot-batch", "bot-isolated"]:
		var launcher := base.path_join(mode + ".gd")
		var file := FileAccess.open(launcher, FileAccess.WRITE)
		file.store_string(_bot_launcher(base.path_join(mode + "-state")))
		file.close()
		jobs.append({"script": launcher, "args": [
			"--pilot=pylon_engineer", "--policy=brawler", "--table=slice",
			"--seeds=1,2" if mode == "bot-batch" else "--seeds=2", "--trace-ticks=1",
			"--ticks=%d" % BOT_TICKS, "--out=" + base.path_join(mode)]})
	var results := ChildRuns.run(jobs, 340.0)
	var hashes: Array[String] = []
	var traces: Array = []
	for i in jobs.size():
		var result: Dictionary = results[i]
		var errors: Array = ChildRuns.summary(result)["errors"].filter(func(line: String) -> bool: return not TeardownNoise.is_noise(line))
		t.check("child %d completed" % i, result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
			"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], errors])
		var mode: String = ["batch", "isolated", "bot-batch", "bot-isolated"][i]
		var path := base.path_join(mode).path_join("sable-seed-8-trace.json" if i < 2 else "trace-2.ndjson")
		var source := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var ticks: Array = []
		if i < 2:
			var doc = JSON.parse_string(source) if not source.is_empty() else null
			ticks = doc.get("ticks", []) if doc is Dictionary else []
		else:
			for line in source.split("\n", false):
				ticks.append(JSON.parse_string(line))
		t.check("child %d measured run" % i, ticks.size() == TRAVERSAL_TICKS if i < 2 else ticks.size() == BOT_TICKS,
			"%d ticks" % ticks.size())
		traces.append(ticks)
		hashes.append(JSON.stringify(ticks).sha256_text())
	var batch := _runs(base.path_join("batch/sable.json"))
	var solo := _runs(base.path_join("isolated/sable.json"))
	var eighth: Dictionary = batch[7] if batch.size() == 8 else {}
	var alone: Dictionary = solo[0] if solo.size() == 1 else {}
	t.check("position eight has a byte-identical full result to solo", not eighth.is_empty() and JSON.stringify(eighth) == JSON.stringify(alone),
		"batch %s, solo %s; evidence %s" % [JSON.stringify(eighth).sha256_text(), JSON.stringify(alone).sha256_text(), base])
	for i in 8:
		var rows := _runs(base.path_join("batch/children/%d-seed-%d/sable.json" % [i + 1, i + 1]))
		t.check("position %d ran one seed in its own child" % (i + 1), rows.size() == 1 and int(rows[0].get("seed", -1)) == i + 1)
	for offset in [0, 2]:
		var first := 0
		var a: Array = traces[offset]
		var b: Array = traces[offset + 1]
		for i in mini(a.size(), b.size()):
			if a[i] != b[i]:
				first = i + 1
				break
		if first == 0 and a.size() != b.size():
			first = mini(a.size(), b.size()) + 1
		t.check("%s second seed repeats every tick" % ("traversal position eight" if offset == 0 else "bot"),
			not a.is_empty() and hashes[offset] == hashes[offset + 1],
			"batch %s, isolated %s, first differing tick %d; evidence %s" % [hashes[offset], hashes[offset + 1], first, base])
	var code := t.verdict()
	print("seed_isolation_test: %s" % ("PASS" if code == 0 else "FAIL"))
	quit(code)


# A small launcher gives each bot job clean saved state while ChildRuns owns the deadline.
func _bot_launcher(state_dir: String) -> String:
	return """extends SceneTree
func _initialize() -> void:
	for kind in ["DATA", "CONFIG", "CACHE"]:
		OS.set_environment("XDG_%%s_HOME" %% kind, %s.path_join(kind.to_lower()))
	var args := PackedStringArray(["--headless", "--fixed-fps", "90", "--path", %s,
		"--script", "res://tools/bot_run.gd", "--"])
	args.append_array(OS.get_cmdline_user_args())
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	for chunk in output:
		print(String(chunk).strip_edges())
	quit(code)
""" % [JSON.stringify(state_dir), JSON.stringify(ProjectSettings.globalize_path("res://"))]


func _runs(path: String) -> Array:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return doc.get("runs", []) if doc is Dictionary else []


func _check_failed_trace(t, out: String) -> void:
	var child_out := out.path_join("children/1-seed-8")
	DirAccess.make_dir_recursive_absolute(child_out)
	var name := "sable-seed-8-trace.json"
	for path in [out.path_join(name), child_out.path_join(name), child_out.path_join("sable.json")]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string('{"pilot":"sable","seed":8,"ticks":[{"stale":true}]}')
		file.close()
	var result: Dictionary = ChildRuns.run([{"script": "res://tools/traversal_line.gd", "args": [
		"--table=park", "--stage=0", "--pilot=sable", "--seeds=8", "--trace",
		"--ticks=1000000000", "--child-timeout=0.001", "--out=" + out]}], 15.0)[0]
	t.check("failed traced rerun exits 3 within its bound", result["code"] == 3 and not result["timed_out"])
	var path := out.path_join("sable.json")
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	t.check("failed traced rerun is INCONCLUSIVE", doc is Dictionary and doc.get("status") == "INCONCLUSIVE"
		and doc.get("inconclusive", []).size() == 1 and doc["inconclusive"][0].get("status") == "INCONCLUSIVE")
	t.check("failed traced rerun has no result row", doc is Dictionary and doc.get("runs", [null]).is_empty())
	t.check("failed traced rerun leaves no consumable top-level trace", not FileAccess.file_exists(out.path_join(name)), out)
	t.check("failed traced rerun leaves no consumable child trace", not FileAccess.file_exists(child_out.path_join(name)), child_out)
