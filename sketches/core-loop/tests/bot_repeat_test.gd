# smoke: solo timeout=240s (two separate bot children; at most 90 seconds each)
# 2026-10-14 DET-HEFT: full-field traces take 35-37 s directly; the 40 s harness cap
# cut both isolated children short. Only the wall budget changes, not the 6000-tick comparison.
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const TICKS := 6000


func _initialize() -> void:
	var t := T.new("bot_repeat_test")
	var traces: Array[String] = []
	var base := OS.get_user_data_dir().path_join("bot-repeat-%d" % OS.get_process_id())
	for i in 2:
		var folder := base.path_join(str(i))
		var previous := {}
		for kind in ["DATA", "CONFIG", "CACHE"]:
			var key: String = "XDG_%s_HOME" % kind
			previous[key] = OS.get_environment(key)
			OS.set_environment(key, folder.path_join(kind.to_lower()))
		var results := ChildRuns.run([{"script": "res://tools/bot_run.gd", "args": [
			"--out=" + folder, "--policy=brawler", "--seeds=3", "--table=slice",
			"--trace-ticks=1", "--ticks=%d" % TICKS, "--allocation-noise=%d" % i]}], 90.0)
		for key in previous:
			if previous[key].is_empty():
				OS.unset_environment(key)
			else:
				OS.set_environment(key, previous[key])
		var result: Dictionary = results[0]
		var errors: Array = ChildRuns.summary(result)["errors"]
		for line in String(result["log"]).split("\n"):
			if line.begins_with("FAIL"):
				errors.append(line)
		t.check("child %d" % i, result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
			"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], errors])
		var path := folder.path_join("trace-3.ndjson")
		var trace := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		traces.append(trace)
		t.check("child %d trace length" % i, trace.split("\n", false).size() == TICKS,
			"%d ticks, want %d" % [trace.split("\n", false).size(), TICKS])
		var rows := trace.split("\n", false)
		var first_row = JSON.parse_string(rows[0]) if not rows.is_empty() else null
		var last_row = JSON.parse_string(rows[-1]) if not rows.is_empty() else null
		t.check("child %d real tick span" % i, first_row is Dictionary and last_row is Dictionary
			and first_row.get("tick") == 1 and last_row.get("tick") == TICKS and last_row.get("mass", 0.0) > 0.0,
			"first %s, last %s" % [first_row.get("tick") if first_row is Dictionary else null,
				last_row.get("tick") if last_row is Dictionary else null])
	var first := 0
	var a := traces[0].split("\n", false)
	var b := traces[1].split("\n", false)
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			first = i + 1
			break
	t.check("separate processes repeat every tick", not traces[0].is_empty() and traces[0] == traces[1],
		"first differing tick %d; evidence %s" % [first, base])
	if t.failures == 0:
		_remove(base)
	quit(t.verdict())


# The two traces are evidence only when the check fails.
func _remove(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for folder in DirAccess.get_directories_at(path):
		_remove(path.path_join(folder))
	DirAccess.remove_absolute(path)
