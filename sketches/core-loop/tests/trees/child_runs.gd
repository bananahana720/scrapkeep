extends RefCounted


# A clock regression can elapse wall time without advancing the caller's scene tree.
static func elapse_wall(msec: int) -> void:
	OS.delay_msec(msec)


# Runs headless child scripts side by side, each at a fixed 90 fps (the physics rate, so
# the same ticks as real time, but not held to the clock) and logging to its own file.
# Returns one {code, log, timed_out} per job, in order. A job is {script, args}.
static func run(jobs: Array, timeout_s: float) -> Array:
	var project := ProjectSettings.globalize_path("res://")
	var dir := OS.get_user_data_dir().path_join("tree-children-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	var running := []
	for i in jobs.size():
		var log_path := dir.path_join("child-%d.log" % i)
		var args: Array = ["--headless", "--fixed-fps", "90", "--log-file", log_path, "--path", project,
			"--script", jobs[i]["script"], "--"] + jobs[i].get("args", [])
		if jobs[i]["script"] in ["res://tools/bot_run.gd", "res://tools/posture_sweep.gd",
			"res://tests/posture_bands_mind_test.gd", "res://tests/posture_bands_reactor_test.gd",
			"res://tests/posture_bands_swarm_test.gd"]:
			args.append("--gate=1")
		running.append({"pid": OS.create_process(OS.get_executable_path(), PackedStringArray(args)), "log": log_path})
	var start := Time.get_ticks_msec()
	while running.any(func(r): return OS.is_process_running(r["pid"])) and Time.get_ticks_msec() - start < timeout_s * 1000.0:
		OS.delay_msec(200)
	var out := []
	for r in running:
		var timed_out := OS.is_process_running(r["pid"])
		if timed_out:
			OS.kill(r["pid"])
		out.append({"code": -1 if timed_out else OS.get_process_exit_code(r["pid"]),
			"log": FileAccess.get_file_as_string(r["log"]), "timed_out": timed_out})
		DirAccess.remove_absolute(r["log"])
	DirAccess.remove_absolute(dir)
	return out


# The child's check lines and verdict, and any script error it logged.
static func summary(result: Dictionary) -> Dictionary:
	var checks := []
	var errors := []
	var verdict := ""
	var verdict_line := RegEx.create_from_string("^[\\w.-]+( \\([^)]*\\))?: (PASS|FAIL)\\b")
	for line in String(result["log"]).split("\n"):
		if line.begins_with("["):
			checks.append(line)
		elif line.contains("SCRIPT ERROR") or line.begins_with("ERROR"):
			errors.append(line.strip_edges())
		elif verdict_line.search(line) != null:
			# A trailing note after PASS is dropped, so callers can still test ends_with(": PASS").
			var found := verdict_line.search(line)
			verdict = found.get_string() if found.get_string(2) == "PASS" else line.strip_edges()
	return {"checks": checks, "errors": errors, "verdict": verdict}
