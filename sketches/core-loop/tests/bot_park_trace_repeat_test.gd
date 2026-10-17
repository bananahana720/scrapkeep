# smoke: bots timeout=720s (two separate bot children, about 100 s each at --stages=2)
# 2026-10-17 TRACE-DIV: seed 1 skipper on --table=park, traced and untraced, first diverged at
# tick 18263 (stage 2, gates) while the next park stage's build attached on wall-clock frames.
# terrain.gd now builds park stages whole in the prepare frame under SimClock.ticks. Stage 2 ends
# about tick 18670, past that divergence.
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const STAGES := 2
const MIN_TICKS := 18300
const SEED := 1


func _initialize() -> void:
	var t := T.new("bot_park_trace_repeat_test")
	var traces: Array[String] = []
	var rows: Array = []
	var base := OS.get_user_data_dir().path_join("bot-park-trace-%d" % OS.get_process_id())
	for i in 2:
		var folder := base.path_join(str(i))
		var previous := {}
		for kind in ["DATA", "CONFIG", "CACHE"]:
			var key: String = "XDG_%s_HOME" % kind
			previous[key] = OS.get_environment(key)
			OS.set_environment(key, folder.path_join(kind.to_lower()))
		var args := ["--out=" + folder, "--policy=skipper", "--seeds=%d" % SEED, "--pilot=pylon_engineer",
			"--table=park", "--trace-ticks=1", "--stages=%d" % STAGES]
		# The second child also prints the --trace lines; that must not move the game.
		if i == 1:
			args.append("--trace=1")
		var results := ChildRuns.run([{"script": "res://tools/bot_run.gd", "args": args}], 300.0)
		for key in previous:
			if previous[key].is_empty():
				OS.unset_environment(key)
			else:
				OS.set_environment(key, previous[key])
		var result: Dictionary = results[0]
		var errors: Array = ChildRuns.summary(result)["errors"]
		t.check("child %d (%s)" % [i, "traced" if i == 1 else "untraced"], result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
			"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], errors.slice(0, 3)])
		var path := folder.path_join("trace-%d.ndjson" % SEED)
		var trace := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		traces.append(trace)
		var lines := trace.split("\n", false)
		var first_row = JSON.parse_string(lines[0]) if not lines.is_empty() else null
		t.check("child %d trace passes tick %d from tick 1" % [i, MIN_TICKS], lines.size() >= MIN_TICKS
			and first_row is Dictionary and first_row.get("tick") == 1, "%d ticks" % lines.size())
		var bots := FileAccess.get_file_as_string(folder.path_join("bots.ndjson")).split("\n", false)
		var row = JSON.parse_string(bots[0]) if bots.size() == 1 else null
		rows.append(row)
		t.check("child %d wrote one bots row ending stages_done" % i, row is Dictionary and row.get("outcome") == "stages_done",
			"%d rows, %s" % [bots.size(), row.get("outcome") if row is Dictionary else null])
	var a := traces[0].split("\n", false)
	var b := traces[1].split("\n", false)
	var first := 0
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			first = i + 1
			break
	t.check("traced and untraced runs repeat every tick", not traces[0].is_empty() and traces[0].sha256_text() == traces[1].sha256_text(),
		"first differing tick %d of %d and %d; evidence %s" % [first, a.size(), b.size(), base])
	var ticks := []
	for row in rows:
		ticks.append(row.get("ticks") if row is Dictionary else null)
	t.check("traced and untraced runs end on the same tick", ticks[0] != null and ticks[0] == ticks[1], str(ticks))
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
