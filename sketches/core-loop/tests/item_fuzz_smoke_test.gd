# smoke: timeout=300s (eight fixed-90-fps children of 20 s, one at a time)
extends SceneTree

# The item fuzzer's smoke slice (DESIGN-V2 section 7): 8 seeds x 20 s of tools/item_fuzz.gd
# at --fixed-fps 90, so it runs faster than real time. The tool runs each seed in its own
# child process, about 5 s of boot apiece, which is why this slice declares 300 s. The
# full 200 x 90 s run is the tool's job, not this test's.
#
# It fails on a hard invariant (a non-finite number, a bolt over the cap, a slot past its
# charge ceiling or under the cooldown floor, a trigger firing twice in one pass, damage
# reduction past its cap). Speed and kill outliers, stalls and slow ticks are anomalies
# for HAPPY-ACCIDENTS.md, printed but not failed.

const SEEDS := "1-8"
const SECONDS := 20
const HARD := ["non_finite_ball", "non_finite_enemy", "bolts", "guard", "reduction"]
const HARD_PREFIXES := ["charges_", "floor_"]

var _failures := 0


func _initialize() -> void:
	var project := ProjectSettings.globalize_path("res://")
	var out := OS.get_user_data_dir().path_join("item-fuzz-smoke-%d" % OS.get_process_id())
	var output := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--fixed-fps", "90", "--path", project, "--script",
		"res://tools/item_fuzz.gd", "--", "--seeds=%s" % SEEDS, "--seconds=%d" % SECONDS, "--out=%s" % out], output, true)
	var text := "\n".join(output)
	var runs: Array = []
	var file := FileAccess.open(out.path_join("fuzz.ndjson"), FileAccess.READ)
	var json := JSON.new()
	while file != null and not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line != "" and json.parse(line) == OK and json.data is Dictionary:
			runs.append(json.data)
	var hard: Array = []
	var soft: Array = []
	var natural := {}
	var injected := {}
	for r in runs:
		for k in r["natural"]:
			natural[k] = true
		for k in r["injected"]:
			injected[k] = true
		for a in r["anomalies"]:
			if a["kind"] in HARD or HARD_PREFIXES.any(func(p): return String(a["kind"]).begins_with(p)):
				hard.append("seed %d %s %s" % [a["seed"], a["kind"], a["reading"]])
			else:
				soft.append("seed %d %s %s" % [a["seed"], a["kind"], a["reading"]])
	var seconds_ok := runs.all(func(r): return int(r["ticks"]) >= SECONDS * 90 or String(r["ended"]) != "")
	var covered := {}
	for k in natural:
		covered[k] = true
	for k in injected:
		covered[k] = true
	# No wall clock decides this verdict: the seed list and --seconds are fixed, a seed
	# ends on physics ticks (the tool sets SimClock.ticks), and the tool's one wall-clock
	# read only feeds the soft frame_time anomaly.
	var script_error := text.contains("SCRIPT ERROR")
	_report("fuzz slice ran", code == 0 and runs.size() == 8 and not script_error and seconds_ok,
		"exit %d, %d seed records of %d s each, script error %s, every seed ran its span %s" % [code, runs.size(), SECONDS, script_error, seconds_ok])
	_report("every trigger reached", covered.size() == 12,
		"%d of 12 kinds fired, %d naturally %s, the rest injected %s" % [covered.size(), natural.size(), natural.keys(), injected.keys()])
	_report("hard invariants", hard.is_empty(), "violations %s" % [hard])
	print("[anomalies] %d soft anomalies for HAPPY-ACCIDENTS.md: %s -> PASS" % [soft.size(), soft])
	DirAccess.remove_absolute(out.path_join("fuzz.ndjson"))
	DirAccess.remove_absolute(out.path_join("anomalies.md"))
	DirAccess.remove_absolute(out)
	print("item_fuzz_smoke_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
