# smoke: solo (traversal and bot batches with isolated children, bounded to 85 seconds)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const BOT_TICKS := 30


func _initialize() -> void:
	var t := T.new("seed_isolation_test")
	var base := OS.get_user_data_dir().path_join("seed-isolation-%d" % OS.get_process_id())
	var jobs := []
	for mode in ["batch", "isolated"]:
		jobs.append({"script": "res://tools/traversal_line.gd", "args": [
			"--pilot=sable", "--seeds=1,2" if mode == "batch" else "--seeds=2",
			"--trace", "--out=" + base.path_join(mode)]})
	for mode in ["bot-batch", "bot-isolated"]:
		jobs.append({"script": "res://tools/bot_run.gd", "state": base.path_join(mode + "-state"), "args": [
			"--pilot=pylon_engineer", "--policy=brawler", "--table=slice",
			"--seeds=1,2" if mode == "bot-batch" else "--seeds=2", "--trace-ticks=1",
			"--ticks=%d" % BOT_TICKS, "--out=" + base.path_join(mode)]})
	var results := _run(jobs, base, 85.0)
	var hashes: Array[String] = []
	var traces: Array = []
	for i in jobs.size():
		var result: Dictionary = results[i]
		var errors: Array = ChildRuns.summary(result)["errors"]
		t.check("child %d completed" % i, result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
			"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], errors])
		var mode: String = ["batch", "isolated", "bot-batch", "bot-isolated"][i]
		var path := base.path_join(mode).path_join("sable-seed-2-trace.json" if i < 2 else "trace-2.ndjson")
		var source := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var ticks: Array = []
		if i < 2:
			var doc = JSON.parse_string(source) if not source.is_empty() else null
			ticks = doc.get("ticks", []) if doc is Dictionary else []
		else:
			for line in source.split("\n", false):
				ticks.append(JSON.parse_string(line))
		t.check("child %d measured run" % i, ticks.size() > 100 if i < 2 else ticks.size() == BOT_TICKS,
			"%d ticks" % ticks.size())
		traces.append(ticks)
		hashes.append(JSON.stringify(ticks).sha256_text())
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
		t.check("%s second seed repeats every tick" % ("traversal" if offset == 0 else "bot"),
			not a.is_empty() and hashes[offset] == hashes[offset + 1],
			"batch %s, isolated %s, first differing tick %d; evidence %s" % [hashes[offset], hashes[offset + 1], first, base])
	var code := t.verdict()
	print("seed_isolation_test: %s" % ("PASS" if code == 0 else "FAIL"))
	quit(code)


# Launch with per-job XDG state, then wait on all children under one deadline.
func _run(jobs: Array, base: String, timeout_s: float) -> Array:
	var running := []
	DirAccess.make_dir_recursive_absolute(base)
	for i in jobs.size():
		var job: Dictionary = jobs[i]
		var previous := {}
		if job.has("state"):
			for kind in ["DATA", "CONFIG", "CACHE"]:
				var key: String = "XDG_%s_HOME" % kind
				previous[key] = OS.get_environment(key)
				OS.set_environment(key, String(job["state"]).path_join(kind.to_lower()))
		var log_path := base.path_join("child-%d.log" % i)
		var args: Array = ["--headless", "--fixed-fps", "90", "--log-file", log_path, "--path",
			ProjectSettings.globalize_path("res://"), "--script", job["script"], "--"] + job["args"]
		running.append({"pid": OS.create_process(OS.get_executable_path(), PackedStringArray(args)), "log": log_path})
		for key in previous:
			if previous[key].is_empty():
				OS.unset_environment(key)
			else:
				OS.set_environment(key, previous[key])
	var start := Time.get_ticks_msec()
	while running.any(func(r): return OS.is_process_running(r["pid"])) and Time.get_ticks_msec() - start < timeout_s * 1000.0:
		OS.delay_msec(200)
	var results := []
	for child in running:
		var timed_out := OS.is_process_running(child["pid"])
		if timed_out:
			OS.kill(child["pid"])
		results.append({"code": -1 if timed_out else OS.get_process_exit_code(child["pid"]),
			"log": FileAccess.get_file_as_string(child["log"]), "timed_out": timed_out})
	return results
