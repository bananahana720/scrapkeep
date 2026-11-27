# smoke: solo timeout=360s (two separate bot children share the harness budget)
# 2026-10-14 DET-HEFT: full-field traces take 35-37 s directly; the 40 s harness cap
# cut both isolated children short. Only the wall budget changes, not the 6000-tick comparison.
# 2026-10-23 (w18 gate): a child now takes about 60 s on an idle 4-core cloud box and about 108 s
# on a loaded one (child 0 stopped at tick 4992 of 6000 at the old fixed 90 s wall). The wall is a
# hang guard, not a speed check: each child gets an equal share of what is left of BUDGET_S, so a
# slow box spends more of the fixed harness cap and a hung child is still killed before it.
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const TICKS := 6000
# The 360 s harness cap less a margin for boot, the trace compare and cleanup.
const BUDGET_S := 330.0


func _initialize() -> void:
	var t := T.new("bot_repeat_test")
	var traces: Array[String] = []
	var base := OS.get_user_data_dir().path_join("bot-repeat-%d" % OS.get_process_id())
	var jobs := []
	for i in 2:
		var folder := base.path_join(str(i))
		jobs.append({"script": "res://tools/bot_run.gd", "home": folder, "args": [
			"--out=" + folder, "--policy=brawler", "--seeds=3", "--table=slice",
			"--trace-ticks=1", "--ticks=%d" % TICKS, "--allocation-noise=%d" % i]})
	var results := ChildRuns.run_shared(jobs, BUDGET_S)
	for i in 2:
		var folder := base.path_join(str(i))
		var result: Dictionary = results[i]
		var errors: Array = ChildRuns.summary(result)["errors"]
		for line in String(result["log"]).split("\n"):
			if line.begins_with("FAIL"):
				errors.append(line)
		t.check("child %d" % i, result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
			"exit %s, timeout %s, %.1f s of a %.1f s wall, errors %s" % [result["code"], result["timed_out"],
				result["seconds"], result["wall"], errors])
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
