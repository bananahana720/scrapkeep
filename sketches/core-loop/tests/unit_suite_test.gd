# smoke: solo timeout=360s (the content registry case validates every fixture against all 27 tables, and _objective_ids walks 2,560 objective states per objective row: 154 s of the run beside one other Godot lane on a 4-core cloud box on 2026-10-19, so the 180 s batch cap killed it on the stage and on its merge base)
extends SceneTree

const T := preload("res://tests/support/t.gd")
const CASE_DIR := "res://tests/unit/"
const MIN_CASES := 3
const REQUIRED_CASES: Array[String] = ["weight_table_case.gd"]


func _initialize() -> void:
	var t := T.new("unit_suite_test")
	var names: Array[String] = REQUIRED_CASES.duplicate()
	for file in DirAccess.get_files_at(CASE_DIR):
		if file.ends_with("_case.gd") and not file in names:
			names.append(file)
	names.sort()
	t.check("enough cases", names.size() >= MIN_CASES, "%d cases found, need %d" % [names.size(), MIN_CASES])
	var ran := 0
	for file in names:
		var script = load(CASE_DIR + file)
		var instance = script.new() if script is GDScript and script.can_instantiate() else null
		if instance == null or not instance.has_method("run"):
			t.check("case loads " + file, false, "no loadable script with a run method")
			continue
		var before := t.checks
		instance.run(t)
		ran += 1
		print("case %s: %d checks" % [file.trim_suffix("_case.gd"), t.checks - before])
	if t.failures > 0:
		quit(t.verdict())
		return
	print("unit_suite_test: PASS (%d cases, %d checks)" % [ran, t.checks])
	quit(0)
