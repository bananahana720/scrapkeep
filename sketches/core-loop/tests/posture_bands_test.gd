# smoke: solo (nine bot runs in child processes, up to six at once; a loaded machine slows them)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const T := preload("res://tests/support/t.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")

# The slice Warden's numbers are held by a bot sweep (tools/posture_sweep.md): a class III ball
# breaks it in about half a minute, a class I ball takes at least twice as long and can still break
# it, and a ball that only shoots from range never does. The bands are defined on medians over five
# seeds, so they are checked on the committed sweep table (tools/posture_sweep.tsv). This test also
# plays the slice row as it stands on seeds 1 to 3 and checks that those medians are within 10 percent
# of the ones the sweep recorded for the same seeds. Runs repeat exactly, so a larger move means the
# fight changed, and the sweep wants rerunning.

# The cap is 150 s, the small arm's band, so a camper run ends sooner: the smoke run's limit is 120 s.
# A run that breaks before the cap measures the same at any cap.
const SEEDS := "1,2,3"
const PICK := {"plating": 110.0, "curve": 2.0, "ram_shatters": false}
const EXPECT_SMALL_S := 73.75
const EXPECT_GROWN_S := 24.66
const SWEEP := "res://tools/posture_sweep.tsv"
const TOLERANCE := 0.10

# The alpha table's two zone Wardens, one row each (tools/posture_sweep.md, "Alpha Wardens"). The
# alpha rows are played by tools/bot_run.gd on --table=alpha, one process per seed and policy, from
# the run's start: the skipper goes straight to each Warden, the completionist does each stage's
# activities first. A fight's seconds are the stage clock at the break less the bot's turn to the
# Warden (warden_fight_s). The bots.ndjson stage notes carry both. Seeds 1 to 3, 24000 ticks (enough
# to clear stage 2 for both policies); the window is the sweep's three-seed median, widened.
const ALPHA_SEEDS := [1, 2, 3]
const ALPHA_TICKS := 24000
const SPILLWAY_SKIPPER_S := Vector2(45.0, 90.0)
const REACH_SKIPPER_S := Vector2(30.0, 80.0)
# The Reach completionist's median fight is at most this many times the skipper's.
const REACH_COMPLETIONIST_FACTOR := 1.25


func _initialize() -> void:
	var t := T.new("posture_bands_test")
	var row: Dictionary = SliceDefs.of(1)
	var posture: Dictionary = row.get("posture", {})
	var plating := float(row["warden_plating"])
	var curve := float(posture.get("curve", 1.0))
	var shatters := bool(posture.get("ram_shatters", true))
	t.check("the row is the picked cell", is_equal_approx(plating, float(PICK["plating"])) and is_equal_approx(curve, float(PICK["curve"]))
		and shatters == bool(PICK["ram_shatters"]), "row plating %s curve %s shatter %s, pick %s" % [plating, curve, shatters, PICK])
	var folder := OS.get_user_data_dir().path_join("posture-bands-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var cells := folder.path_join("cells.tsv")
	var jobs := [{"script": "res://tools/posture_sweep.gd", "args": ["--out=" + cells,
		"--runs=" + folder.path_join("runs.tsv"), "--procs=6", "--cap=150", "--seeds=" + SEEDS, "--arms=small,grown,camper",
		"--plating=%s" % plating, "--curve=%s" % curve, "--shatter=%s" % shatters]}]
	for policy in ["skipper", "completionist"]:
		for run_seed in ALPHA_SEEDS:
			jobs.append({"script": "res://tools/bot_run.gd", "args": ["--out=" + folder.path_join("alpha-%s-%d" % [policy, run_seed]),
				"--policy=" + policy, "--seeds=%d" % run_seed, "--ticks=%d" % ALPHA_TICKS, "--table=alpha"]})
	var results := ChildRuns.run(jobs, 900.0)
	var result: Dictionary = results[0]
	t.check("the sweep ran", result["code"] == 0 and not result["timed_out"], "exit %s, timed out %s" % [result["code"], result["timed_out"]])
	var swept := _picked(SWEEP, plating, curve, shatters)
	var swept_grown := float(swept.get("grown_median_s", "0"))
	t.check("the sweep table holds the picked cell and it passes every band", swept.get("pass", "") == "pass",
		"cell %s" % swept)
	t.check("over five seeds grown breaks it in 25 to 45 s", swept_grown >= 25.0 and swept_grown <= 45.0, "grown median %.1f s" % swept_grown)
	var cell := _cell(cells)
	var small := float(cell.get("small_median_s", "0"))
	var grown := float(cell.get("grown_median_s", "0"))
	t.check("small takes at least twice grown's time", grown > 0.0 and small >= 2.0 * grown, "small %.1f s, grown %.1f s" % [small, grown])
	t.eq("small breaks it in every run", cell.get("small_broke", ""), str(SEEDS.count(",") + 1))
	t.eq("the camper never breaks it", cell.get("camper_broke", ""), "0")
	t.check("small median within 10 percent of the sweep's", absf(small - EXPECT_SMALL_S) <= TOLERANCE * EXPECT_SMALL_S,
		"small %.1f s, sweep %.1f s" % [small, EXPECT_SMALL_S])
	t.check("grown median within 10 percent of the sweep's", absf(grown - EXPECT_GROWN_S) <= TOLERANCE * EXPECT_GROWN_S,
		"grown %.1f s, sweep %.1f s" % [grown, EXPECT_GROWN_S])
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
	for i in range(1, results.size()):
		t.check("alpha bot run %d ran" % i, results[i]["code"] == 0 and not results[i]["timed_out"],
			"exit %s, timed out %s" % [results[i]["code"], results[i]["timed_out"]])
	var spillway := _fights(folder, "skipper", 1)
	var reach := _fights(folder, "skipper", 2)
	var reach_full := _fights(folder, "completionist", 2)
	t.check("every alpha fight broke its Warden", not spillway.has(-1.0) and not reach.has(-1.0) and not reach_full.has(-1.0),
		"spillway %s, reach %s, reach completionist %s" % [spillway, reach, reach_full])
	var posture_rows := AlphaDefs.DEFS.all(func(row): return row["warden_fight"] == "posture")
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


# The sweep table's row for one cell as a column-name dictionary, or empty.
func _picked(path: String, plating: float, curve: float, shatters: bool) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	var head := lines[0].split("\t")
	for line in lines.slice(1):
		var cols := line.split("\t")
		var row := {}
		for i in mini(head.size(), cols.size()):
			row[head[i]] = cols[i]
		if is_equal_approx(float(row.get("plating", "0")), plating) and is_equal_approx(float(row.get("curve", "0")), curve) \
				and row.get("ram_shatters", "") == str(shatters):
			return row
	return {}


# The cell's one data row as a column-name dictionary.
func _cell(path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		return out
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	if lines.size() < 2:
		return out
	var head := lines[0].split("\t")
	var cols := lines[1].split("\t")
	for i in mini(head.size(), cols.size()):
		out[head[i]] = cols[i]
	return out
