extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# All 96 end builds (16 per class) played with every key against enemies, one child
# process per class in parallel (tests/trees/tree_play_run.gd). A class passes when its
# child exits 0, every build leaves the ball and enemies finite, and its log holds no
# script error, so every node's code path that the rota reaches ran clean.
#
# Evidence limit: a fixed key rota in calm stage 1, 4 s per build. It exercises the
# code, not a player's choices, and it says nothing about feel or balance.

const TIMEOUT_S := 110.0


func _initialize() -> void:
	var jobs := []
	for index in ClassDef.all().size():
		jobs.append({"script": "res://tests/trees/tree_play_run.gd", "args": ["--class=%d" % index]})
	var results := ChildRuns.run(jobs, TIMEOUT_S)
	var failures := 0
	for i in results.size():
		var s := ChildRuns.summary(results[i])
		var ok: bool = results[i]["code"] == 0 and String(s["verdict"]).ends_with(": PASS") and s["errors"].is_empty()
		if not ok:
			failures += 1
		for line in s["checks"]:
			print("  ", line)
		for line in s["errors"].slice(0, 12):
			print("  child: ", line)
		print("[class %d builds] exit %d%s, %s, %d script errors -> %s" % [i, results[i]["code"],
			" (timed out)" if results[i]["timed_out"] else "", s["verdict"] if s["verdict"] != "" else "no verdict",
			s["errors"].size(), "PASS" if ok else "FAIL"])
	print("tree_play_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
