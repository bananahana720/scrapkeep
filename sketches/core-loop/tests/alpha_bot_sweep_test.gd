# smoke: bots timeout=1200s (five bot_run children at once on the default table; a loaded machine slows them. On a 4-core cloud box on 2026-10-23 the five children took 140 to 210 s wall side by side and the test 242 to 251 s, so the 170 s cap never fitted there; 600 s cap, moved to the bot tier with alpha_posture_bands_test)
# Completionist seed 2 dropped after two six-child runs exceeded 150 s (170.50 s, 170.48 s).
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const RUNS := [
	{"policy": "skipper", "seed": 1},
	{"policy": "skipper", "seed": 2},
	{"policy": "completionist", "seed": 1},
	{"policy": "random", "seed": 1},
	{"policy": "camper", "seed": 1},
]
const BAD_OUTCOMES := ["stalled", "boss_stalled", "broken", "boss"]


func _initialize() -> void:
	var t := T.new("alpha_bot_sweep_test")
	var folder := OS.get_user_data_dir().path_join("alpha-bot-sweep-%d" % OS.get_process_id())
	var jobs := []
	for run in RUNS:
		jobs.append({"script": "res://tools/bot_run.gd", "args": [
			"--out=" + folder.path_join("%s-%d" % [run["policy"], run["seed"]]),
			"--policy=" + run["policy"], "--seeds=%d" % run["seed"],
			"--table=default", "--ticks=27000"]})
	var results := ChildRuns.run(jobs, 600.0)
	for i in RUNS.size():
		var run: Dictionary = RUNS[i]
		var label := "%s seed %d" % [run["policy"], run["seed"]]
		var result: Dictionary = results[i]
		var errors: Array = ChildRuns.summary(result)["errors"]
		t.check(label + " child", result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
			"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], errors])
		var path := folder.path_join("%s-%d" % [run["policy"], run["seed"]]).path_join("bots.ndjson")
		var rows := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
		var record = JSON.parse_string(rows[0]) if rows.size() == 1 else null
		if not t.check(label + " record", record is Dictionary, "%d rows in %s" % [rows.size(), path]):
			continue
		t.eq(label + " policy", record.get("policy"), run["policy"])
		t.eq(label + " seed", record.get("seed"), run["seed"])
		var stall_state := "none"
		var broke_warden := false
		for note in record.get("stages", []):
			if note.has("stall_state"):
				stall_state = String(note["stall_state"])
			if note.get("warden_broken_s") != null:
				broke_warden = true
		print("%s: %s at stage %d, %.2f s game, %.2f s wall, stall_state %s" % [
			label, record.get("outcome", "missing"), int(record.get("stage_reached", 0)),
			float(record.get("game_seconds", 0.0)), float(record.get("wall_seconds", 0.0)), stall_state])
		# The camper never closes by design; once it breaks a Warden it must also avoid a stall.
		if run["policy"] != "camper" or broke_warden:
			if run["policy"] == "camper":
				print(label + " broke a Warden; applying the non-camper outcome rule")
			t.check(label + " outcome", not record.get("outcome", "missing") in BAD_OUTCOMES,
				String(record.get("outcome", "missing")))
			t.check(label + " reached a stage", int(record.get("stage_reached", 0)) >= 1)
	if t.failures == 0:
		_remove_tree(folder)
	else:
		print("alpha_bot_sweep_test evidence: " + folder)
	quit(t.verdict())


static func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
