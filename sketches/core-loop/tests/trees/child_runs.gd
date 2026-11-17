extends RefCounted

const TeardownNoise := preload("res://tests/support/teardown_noise.gd")


# A clock regression can elapse wall time without advancing the caller's scene tree.
static func elapse_wall(msec: int) -> void:
	OS.delay_msec(msec)


# Runs headless child scripts side by side, each at a fixed 90 fps (the physics rate, so
# the same ticks as real time, but not held to the clock) and logging to its own file.
# Returns one {code, log, timed_out, seconds} per job, in order. A job is {script, args}.
# With parallel > 0, at most that many children run at once, each starting as one ends, and
# timeout_s runs from each child's own start; at 0 every child starts together.
static func run(jobs: Array, timeout_s: float, parallel := 0) -> Array:
	var project := ProjectSettings.globalize_path("res://")
	var dir := OS.get_user_data_dir().path_join("tree-children-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	var running := []
	var limit: int = jobs.size() if parallel <= 0 else parallel
	var next := 0
	while next < jobs.size() or running.any(func(r): return r["live"]):
		for r in running.filter(func(r): return r["live"]):
			# A child that never started (pid -1) must not reach waitpid(-1) or kill(-1).
			r["timed_out"] = r["pid"] > 0 and OS.is_process_running(r["pid"])
			if not r["timed_out"]:
				r["live"] = false
			elif Time.get_ticks_msec() - r["start"] >= timeout_s * 1000.0:
				OS.kill(r["pid"])
				r["live"] = false
			if not r["live"]:
				r["seconds"] = (Time.get_ticks_msec() - r["start"]) / 1000.0
		while next < jobs.size() and running.filter(func(r): return r["live"]).size() < limit:
			running.append(_start(jobs[next], dir.path_join("child-%d.log" % next), project))
			next += 1
		OS.delay_msec(200)
	var out := []
	for r in running:
		var timed_out: bool = r["timed_out"]
		out.append({"code": -1 if timed_out or r["pid"] <= 0 else OS.get_process_exit_code(r["pid"]),
			"log": FileAccess.get_file_as_string(r["log"]), "timed_out": timed_out, "seconds": r.get("seconds", 0.0)})
		DirAccess.remove_absolute(r["log"])
	DirAccess.remove_absolute(dir)
	return out


# Launches the game itself (the main scene, no --script) once a job, at most `parallel` at a time, each
# with its own XDG data, config and cache under `base` and its own log, as a player's install has. A job
# is {name, args}; args follow "--" (the game's launch flags). Returns one {code, timed_out, seconds,
# text, data} per job, in order: text is the child's log and data its XDG data folder, left in place
# for the caller to read saves from. timeout_s runs from each child's own start; budget_s (when over 0)
# is the wall all the children share from the first start, so a late child's hang is still killed
# inside the caller's own limit: at the budget every live child is killed and none left is started
# (both read as timed_out).
static func run_launched(jobs: Array, base: String, timeout_s: float, parallel: int, budget_s := 0.0) -> Array:
	var project := ProjectSettings.globalize_path("res://")
	var began := Time.get_ticks_msec()
	var runs := []
	for job in jobs:
		var home := base.path_join(String(job["name"]))
		for dir in ["data", "config", "cache"]:
			DirAccess.make_dir_recursive_absolute(home.path_join(dir))
		runs.append({"args": job.get("args", []), "home": home, "log": home.path_join("run.log"), "pid": 0, "start": 0, "live": false,
			"done": false, "timed_out": false, "seconds": 0.0})
	var next := 0
	while runs.any(func(r): return not r["done"]):
		for r in runs.filter(func(r): return r["live"]):
			var running: bool = OS.is_process_running(r["pid"])
			r["seconds"] = (Time.get_ticks_msec() - int(r["start"])) / 1000.0
			if running and r["seconds"] < timeout_s and not _spent(began, budget_s):
				continue
			if running:
				OS.kill(r["pid"])
				r["timed_out"] = true
			r["live"] = false
			r["done"] = true
		while next < runs.size() and runs.filter(func(r): return r["live"]).size() < maxi(1, parallel):
			var r: Dictionary = runs[next]
			next += 1
			if _spent(began, budget_s):
				r["timed_out"] = true
				r["done"] = true
				continue
			var home: String = r["home"]
			var args: Array = ["XDG_DATA_HOME=" + home.path_join("data"), "XDG_CONFIG_HOME=" + home.path_join("config"),
				"XDG_CACHE_HOME=" + home.path_join("cache"), OS.get_executable_path(), "--headless", "--fixed-fps", "90",
				"--log-file", r["log"], "--path", project, "--"] + r["args"]
			r["pid"] = OS.create_process("env", PackedStringArray(args))
			r["start"] = Time.get_ticks_msec()
			# A child that never started (pid -1) must not reach waitpid(-1) or kill(-1).
			r["live"] = r["pid"] > 0
			r["done"] = r["pid"] <= 0
		OS.delay_msec(250)
	var out := []
	for r in runs:
		out.append({"code": -1 if r["timed_out"] or r["pid"] <= 0 else OS.get_process_exit_code(r["pid"]), "timed_out": r["timed_out"],
			"seconds": r["seconds"], "text": FileAccess.get_file_as_string(r["log"]), "data": String(r["home"]).path_join("data")})
	return out


# run_launched, then one second go, inside the same wall budget, for each job whose first result
# settled.call(result) calls false and for which again.call(job) gives a job ({name, args}; null
# for a job that gets no second go). settled is the caller's rule for a result that stands as it
# is, good or bad: only the endings the caller names as play (not a fault) earn a second go.
# Returns {"first": the results in job order, "again": {job index: its second result}}. A second
# go started with the budget spent reads as timed_out.
static func run_launched_twice(jobs: Array, base: String, timeout_s: float, parallel: int, budget_s: float, settled: Callable, again: Callable) -> Dictionary:
	var began := Time.get_ticks_msec()
	var out := {"first": run_launched(jobs, base, timeout_s, parallel, budget_s), "again": {}}
	var redo := []
	var at := []
	for i in jobs.size():
		var job = null if settled.call(out["first"][i]) else again.call(jobs[i])
		if job != null:
			redo.append(job)
			at.append(i)
	if redo.is_empty():
		return out
	# What is left of the budget; never 0, which run_launched reads as no wall at all.
	var left := maxf(1.0, budget_s - (Time.get_ticks_msec() - began) / 1000.0)
	var second := run_launched(redo, base, timeout_s, parallel, left)
	for k in redo.size():
		out["again"][at[k]] = second[k]
	return out


static func _spent(began: int, budget_s: float) -> bool:
	return budget_s > 0.0 and (Time.get_ticks_msec() - began) / 1000.0 >= budget_s


# Runs jobs one at a time inside a shared wall budget. Each child's hang guard is an equal share
# of what is left, so a slow box spends more of the budget and a hung child is still killed inside
# it. A job's optional "env" is set for its child only. Each result also carries "seconds" and "wall".
static func run_shared(jobs: Array, budget_s: float) -> Array:
	var started := Time.get_ticks_msec()
	var out := []
	for i in jobs.size():
		var job: Dictionary = jobs[i]
		var wall := (budget_s - (Time.get_ticks_msec() - started) / 1000.0) / (jobs.size() - i)
		var previous := {}
		for key in job.get("env", {}):
			previous[key] = OS.get_environment(key)
			OS.set_environment(key, job["env"][key])
		var child_start := Time.get_ticks_msec()
		var result: Dictionary = run([job], wall)[0]
		result["seconds"] = (Time.get_ticks_msec() - child_start) / 1000.0
		result["wall"] = wall
		for key in previous:
			if previous[key].is_empty():
				OS.unset_environment(key)
			else:
				OS.set_environment(key, previous[key])
		out.append(result)
	return out


static func _start(job: Dictionary, log_path: String, project: String) -> Dictionary:
	var args: Array = ["--headless", "--fixed-fps", "90", "--log-file", log_path, "--path", project,
		"--script", job["script"], "--"] + job.get("args", [])
	if job["script"] in ["res://tools/bot_run.gd", "res://tools/posture_sweep.gd",
		"res://tests/posture_bands_mind_test.gd", "res://tests/posture_bands_reactor_test.gd",
		"res://tests/posture_bands_swarm_test.gd"]:
		args.append("--gate=1")
	return {"pid": OS.create_process(OS.get_executable_path(), PackedStringArray(args)), "log": log_path,
		"start": Time.get_ticks_msec(), "live": true, "timed_out": false}


# The child's check lines and verdict, and any script error it logged.
static func summary(result: Dictionary) -> Dictionary:
	var checks := []
	var errors := []
	var verdict := ""
	var verdict_line := RegEx.create_from_string("^[\\w.-]+( \\([^)]*\\))?: (PASS|FAIL)\\b")
	for line in String(result["log"]).split("\n"):
		if line.begins_with("["):
			checks.append(line)
		elif (line.contains("SCRIPT ERROR") or line.begins_with("ERROR")) and not TeardownNoise.is_noise(line):
			errors.append(line.strip_edges())
		elif verdict_line.search(line) != null:
			# A trailing note after PASS is dropped, so callers can still test ends_with(": PASS").
			var found := verdict_line.search(line)
			verdict = found.get_string() if found.get_string(2) == "PASS" else line.strip_edges()
	return {"checks": checks, "errors": errors, "verdict": verdict}
