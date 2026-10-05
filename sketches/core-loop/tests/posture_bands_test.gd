# smoke: solo (nine bot runs in child processes, up to six at once; a loaded machine slows them)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const T := preload("res://tests/support/t.gd")

# The slice Warden's numbers are held by a bot sweep (tools/posture_sweep.md): a class III ball
# breaks it in about half a minute, a class I ball takes at least twice as long and can still break
# it, and a ball that only shoots from range never does. The bands are defined on medians over five
# seeds, so they are checked on the committed sweep table (tools/posture_sweep.tsv, seeds 1, 2, 4, 5
# and 6). This test also plays the slice row as it stands on seeds 1, 2 and 4 and checks that those
# medians are within 10 percent of the ones the sweep recorded for the same seeds. Runs repeat exactly,
# so a larger move means the fight changed, and the sweep wants rerunning.
# The bot plays class seed % 4 (tools/bot_driver.gd): 1 Rivet, 2 Kest, 4 Sable. Seeds 3 and 7 play
# Tarn, who joined after the bands were set, so the sweep and this test leave them out.

# The cap is 150 s, the small arm's band, so a camper run ends sooner: the smoke run's limit is 120 s.
# A run that breaks before the cap measures the same at any cap.
const SEEDS := "1,2,4"
const PICK := {"plating": 110.0, "curve": 2.0, "ram_shatters": false}
# 2026-10-05 (wave 15): re-pinned for seeds 1, 2 and 4 after Tarn's claw kit took seed 3; bands unchanged
const EXPECT_SMALL_S := 70.9
const EXPECT_GROWN_S := 33.1
const SWEEP := "res://tools/posture_sweep.tsv"
const TOLERANCE := 0.10


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
	var results := ChildRuns.run([{"script": "res://tools/posture_sweep.gd", "args": ["--out=" + cells,
		"--runs=" + folder.path_join("runs.tsv"), "--procs=6", "--cap=150", "--seeds=" + SEEDS, "--arms=small,grown,camper",
		"--plating=%s" % plating, "--curve=%s" % curve, "--shatter=%s" % shatters]}], 600.0)
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
	if t.failures == 0:
		for file in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file))
		DirAccess.remove_absolute(folder)
	quit(t.verdict())


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
