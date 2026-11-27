extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const ClassDef := preload("res://src/core/class_def.gd")

const HANG_GUARD_S := 360.0
const PARALLEL := 3


func _initialize() -> void:
	var base := OS.get_user_data_dir().path_join("tree-play-%d" % OS.get_process_id())
	var jobs := []
	for index in ClassDef.all().size():
		jobs.append({
			"script": "res://tests/trees/tree_play_run.gd",
			"home": base.path_join("class-%d" % index),
			"args": ["--class=%d" % index],
		})
	var results := ChildRuns.run(jobs, HANG_GUARD_S, PARALLEL)
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
		print("[class %d builds] exit %d%s, %.1f s, %s, %d script errors -> %s" % [i, results[i]["code"],
			" (timed out)" if results[i]["timed_out"] else "", float(results[i].get("seconds", 0.0)),
			s["verdict"] if s["verdict"] != "" else "no verdict",
			s["errors"].size(), "PASS" if ok else "FAIL"])
	if failures == 0:
		_remove(base)
	print("tree_play_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for folder in DirAccess.get_directories_at(path):
		_remove(path.path_join(folder))
	DirAccess.remove_absolute(path)
