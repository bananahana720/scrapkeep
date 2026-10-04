# smoke: solo (six bot runs in child processes at once, 30000 ticks each; a loaded machine slows them)
# F6 2026-10-04: no row picks a fight; posture is the only rule.
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")

# The alpha table's two zone Wardens, one row each (tools/posture_sweep.md, "Alpha Wardens"). The
# alpha rows are played by tools/bot_run.gd on --table=alpha, one process per seed and policy, from
# the run's start: the skipper goes straight to each Warden, the completionist does each stage's
# activities first. A fight's seconds are the stage clock at the break less the bot's turn to the
# Warden (warden_fight_s). The bots.ndjson stage notes carry both. Seeds 1 to 3, 30000 ticks (enough
# to clear stage 2 for both policies: the two-hook completionist breaks seed 2's Reach Warden at about
# 26700); the window is the sweep's three-seed median, widened.
# Three seeds take about 118 s solo; the smoke's per-test cap is 180 s (2026-10-04).
const ALPHA_SEEDS := [1, 2, 3]
const ALPHA_TICKS := 30000
const SPILLWAY_SKIPPER_S := Vector2(45.0, 90.0)
const REACH_SKIPPER_S := Vector2(30.0, 80.0)
# The Reach completionist's median fight is at most this many times the skipper's.
const REACH_COMPLETIONIST_FACTOR := 1.25


func _initialize() -> void:
	var t := T.new("alpha_posture_bands_test")
	var folder := OS.get_user_data_dir().path_join("alpha-posture-bands-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var jobs := []
	for policy in ["skipper", "completionist"]:
		for run_seed in ALPHA_SEEDS:
			jobs.append({"script": "res://tools/bot_run.gd", "args": ["--out=" + folder.path_join("alpha-%s-%d" % [policy, run_seed]),
				"--policy=" + policy, "--seeds=%d" % run_seed, "--ticks=%d" % ALPHA_TICKS, "--table=alpha"]})
	var results := ChildRuns.run(jobs, 900.0)
	_alpha(t, folder, results)
	if t.failures == 0:
		_remove_tree(folder)
	quit(t.verdict())


# One fight's seconds per stage and seed: the break less the bot's turn to the Warden.
func _fights(folder: String, policy: String, stage: int) -> Array:
	var out := []
	for run_seed in ALPHA_SEEDS:
		var path := folder.path_join("alpha-%s-%d" % [policy, run_seed]).path_join("bots.ndjson")
		var line := FileAccess.get_file_as_string(path).split("\n", false)
		var fight := -1.0
		if not line.is_empty():
			var record = JSON.parse_string(line[0])
			for note in record.get("stages", []) if record is Dictionary else []:
				if int(note.get("stage", 0)) == stage and note.get("warden_broken_s") != null:
					fight = float(note["warden_broken_s"]) - float(note.get("warden_fight_s", 0.0))
		out.append(fight)
	return out


static func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2]) if not sorted.is_empty() else -1.0


# The alpha Wardens' rows: the skipper's median fight inside each Warden's window, and the Reach
# completionist no slower than the skipper by more than a stated factor.
func _alpha(t, folder: String, results: Array) -> void:
	for i in range(results.size()):
		t.check("alpha bot run %d ran" % i, results[i]["code"] == 0 and not results[i]["timed_out"],
			"exit %s, timed out %s" % [results[i]["code"], results[i]["timed_out"]])
	var spillway := _fights(folder, "skipper", 1)
	var reach := _fights(folder, "skipper", 2)
	var reach_full := _fights(folder, "completionist", 2)
	t.check("every alpha fight broke its Warden", not spillway.has(-1.0) and not reach.has(-1.0) and not reach_full.has(-1.0),
		"spillway %s, reach %s, reach completionist %s" % [spillway, reach, reach_full])
	var posture_rows := AlphaDefs.DEFS.all(func(row): return not row.has("warden_fight"))
	t.check("both alpha Wardens are posture rows", posture_rows, "alpha rows")
	var spillway_median := _median(spillway)
	var reach_median := _median(reach)
	var full_median := _median(reach_full)
	t.check("Spillway skipper breaks it in %d to %d s" % [SPILLWAY_SKIPPER_S.x, SPILLWAY_SKIPPER_S.y],
		spillway_median >= SPILLWAY_SKIPPER_S.x and spillway_median <= SPILLWAY_SKIPPER_S.y, "median %.1f s of %s" % [spillway_median, spillway])
	t.check("Reach skipper breaks it in %d to %d s" % [REACH_SKIPPER_S.x, REACH_SKIPPER_S.y],
		reach_median >= REACH_SKIPPER_S.x and reach_median <= REACH_SKIPPER_S.y, "median %.1f s of %s" % [reach_median, reach])
	t.check("Reach completionist is no slower than %.2f times the skipper" % REACH_COMPLETIONIST_FACTOR,
		reach_median > 0.0 and full_median > 0.0 and full_median <= REACH_COMPLETIONIST_FACTOR * reach_median,
		"completionist median %.1f s of %s, skipper %.1f s" % [full_median, reach_full, reach_median])


static func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
