# smoke: solo timeout=300s (two separate completionist processes through the first park events)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const TICKS := 11000


func _initialize() -> void:
	var t := T.new("bot_completionist_repeat_test")
	var base := OS.get_user_data_dir().path_join("completionist-repeat-%d" % OS.get_process_id())
	var traces: Array[String] = []
	for i in 2:
		var folder := base.path_join(str(i))
		var previous := {}
		for kind in ["DATA", "CONFIG", "CACHE"]:
			var key: String = "XDG_%s_HOME" % kind
			previous[key] = OS.get_environment(key)
			OS.set_environment(key, folder.path_join(kind.to_lower()))
		var child: Dictionary = ChildRuns.run([{"script": "res://tools/bot_run.gd", "args": [
			"--out=" + folder, "--policy=completionist", "--seeds=2", "--table=park",
			"--from-stage=1", "--stages=1", "--trace-ticks=1", "--ticks=%d" % TICKS,
			"--allocation-noise=%d" % i]}], 140.0)[0]
		for key in previous:
			if previous[key].is_empty():
				OS.unset_environment(key)
			else:
				OS.set_environment(key, previous[key])
		t.check("child %d completed without errors" % i, child.code == 0 and not child.timed_out
			and ChildRuns.summary(child).errors.is_empty(), "exit %s, timeout %s, errors %s" % [
				child.code, child.timed_out, ChildRuns.summary(child).errors])
		var path := folder.path_join("trace-2.ndjson")
		var trace := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		traces.append(trace)
		var rows := trace.split("\n", false)
		t.eq("child %d state tick count" % i, rows.size(), TICKS)
		var first = JSON.parse_string(rows[0]) if not rows.is_empty() else null
		var last = JSON.parse_string(rows[-1]) if not rows.is_empty() else null
		t.check("child %d covers stage entry through live park events" % i,
			first is Dictionary and last is Dictionary and first.tick == 1 and last.tick == TICKS
			and first.stage == 1 and last.stage == 1 and last.heft > 1.0
			and last.enemies.any(func(e): return e.kind == "reactor_relic"), "evidence " + folder)
	var first_difference := 0
	var a := traces[0].split("\n", false)
	var b := traces[1].split("\n", false)
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			first_difference = i + 1
			break
	t.check("separate completionist processes repeat every state tick", not traces[0].is_empty()
		and traces[0] == traces[1], "first differing tick %d; evidence %s" % [first_difference, base])
	quit(t.verdict())
