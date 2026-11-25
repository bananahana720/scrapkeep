# smoke: timeout=300s (eight fixed-90-fps children of 20 s, bounded parallel batches)
extends SceneTree

# The item fuzzer's smoke slice (DESIGN-V2 section 7): 8 seeds x 20 s of tools/item_fuzz.gd
# at --fixed-fps 90, so it runs faster than real time. Each seed runs in its own isolated child
# process with bounded concurrency (SMOKE_CHILD_JOBS or up to 4 at a time), its own --out dir,
# and its own HOME/XDG dirs so seeds stay isolated while finishing in a fraction of serial wall
# time. The full 200 x 90 s run is the tool's job, not this test's.
#
# It fails on a hard invariant (a non-finite number, a bolt over the cap, a slot past its
# charge ceiling or under the cooldown floor, a trigger firing twice in one pass, damage
# reduction past its cap). Speed and kill outliers, stalls and slow ticks are anomalies
# for HAPPY-ACCIDENTS.md, printed but not failed.

const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
const SECONDS := 20
const DEFAULT_CONCURRENCY := 4
const CHILD_TIMEOUT_S := 180.0
const OUTLIER := 3.0
const HARD := ["non_finite_ball", "non_finite_enemy", "bolts", "guard", "reduction"]
const HARD_PREFIXES := ["charges_", "floor_"]

var _failures := 0
var _elapsed := 0.0


func _process(delta: float) -> bool:
	_elapsed += delta
	return false


func _child_jobs() -> int:
	var env_jobs := OS.get_environment("SMOKE_CHILD_JOBS").strip_edges()
	if env_jobs.is_valid_int() and int(env_jobs) >= 1:
		return mini(SEEDS.size(), int(env_jobs))
	return mini(DEFAULT_CONCURRENCY, maxi(1, OS.get_processor_count() / 2))


func _spawn_seed(project: String, out_root: String, seed_val: int) -> Dictionary:
	var seed_dir := out_root.path_join("seed-%d" % seed_val)
	var home_dir := seed_dir.path_join("home")
	var data_dir := home_dir.path_join("data")
	var config_dir := home_dir.path_join("config")
	var cache_dir := home_dir.path_join("cache")
	for d in [seed_dir, home_dir, data_dir, config_dir, cache_dir]:
		DirAccess.make_dir_recursive_absolute(d)
	var log_path := seed_dir.path_join("child.log")
	var exit_path := seed_dir.path_join("exit.code")
	var sh_cmd := (
		'HOME="$1" XDG_DATA_HOME="$2" XDG_CONFIG_HOME="$3" XDG_CACHE_HOME="$4" '
		+ '"$5" --headless --fixed-fps 90 --path "$6" --script res://tools/item_fuzz.gd -- '
		+ '--child=1 --seeds="$7" --seconds="$8" --out="$9" > "${10}" 2>&1; '
		+ 'printf "%d\\n" "$?" > "${11}"'
	)
	var args := PackedStringArray([
		"-c", sh_cmd, "_",
		home_dir, data_dir, config_dir, cache_dir,
		OS.get_executable_path(), project,
		str(seed_val), str(SECONDS), seed_dir,
		log_path, exit_path,
	])
	var pid := OS.create_process("/bin/sh", args)
	return {
		"seed": seed_val,
		"pid": pid,
		"dir": seed_dir,
		"log_path": log_path,
		"exit_path": exit_path,
		"started_s": _elapsed,
		"timed_out": false,
	}


func _read_seed_result(entry: Dictionary) -> Dictionary:
	var code := -1
	if entry["timed_out"]:
		code = 124
	elif FileAccess.file_exists(entry["exit_path"]):
		var raw_code := FileAccess.get_file_as_string(entry["exit_path"]).strip_edges()
		if raw_code.is_valid_int():
			code = int(raw_code)
	var log_text := FileAccess.get_file_as_string(entry["log_path"]) if FileAccess.file_exists(entry["log_path"]) else ""
	var records: Array = []
	var ndjson_path: String = String(entry["dir"]).path_join("fuzz.ndjson")
	var file := FileAccess.open(ndjson_path, FileAccess.READ)
	var json := JSON.new()
	while file != null and not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line != "" and json.parse(line) == OK and json.data is Dictionary:
			records.append(json.data)
	return {
		"seed": entry["seed"],
		"code": code,
		"log": log_text,
		"record": records[0] if records.size() == 1 and int(records[0].get("seed", -1)) == int(entry["seed"]) else null,
	}


func _rm_tree(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name in dir.get_files():
		DirAccess.remove_absolute(dir_path.path_join(file_name))
	for sub_name in dir.get_directories():
		_rm_tree(dir_path.path_join(sub_name))
	DirAccess.remove_absolute(dir_path)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var project := ProjectSettings.globalize_path("res://")
	var out := OS.get_user_data_dir().path_join("item-fuzz-smoke-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(out)
	var concurrency := _child_jobs()
	var pending: Array[int] = SEEDS.duplicate()
	var active: Array[Dictionary] = []
	var finished: Dictionary = {}
	while not pending.is_empty() or not active.is_empty():
		while active.size() < concurrency and not pending.is_empty():
			var next_seed: int = pending.pop_front()
			active.append(_spawn_seed(project, out, next_seed))
		var still_running: Array[Dictionary] = []
		for entry in active:
			var pid: int = entry["pid"]
			if pid <= 0:
				finished[entry["seed"]] = _read_seed_result(entry)
			elif not OS.is_process_running(pid):
				finished[entry["seed"]] = _read_seed_result(entry)
			elif _elapsed - float(entry["started_s"]) > CHILD_TIMEOUT_S:
				OS.kill(pid)
				entry["timed_out"] = true
				finished[entry["seed"]] = _read_seed_result(entry)
			else:
				still_running.append(entry)
		active = still_running
		if not active.is_empty():
			await process_frame

	var runs: Array = []
	var all_ok := true
	var worst_code := 0
	var script_error := false
	for s in SEEDS:
		var res: Dictionary = finished[s]
		if int(res["code"]) != 0:
			all_ok = false
			if worst_code == 0:
				worst_code = int(res["code"])
		if String(res["log"]).contains("SCRIPT ERROR"):
			script_error = true
		if res["record"] is Dictionary:
			runs.append(res["record"])
		else:
			all_ok = false

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
				hard.append("seed %d %s %s" % [int(a["seed"]), a["kind"], a["reading"]])
			else:
				soft.append("seed %d %s %s" % [int(a["seed"]), a["kind"], a["reading"]])
	# Mirror item_fuzz.gd cross-seed outlier detection across all 8 seeds.
	var buckets := {}
	for r in runs:
		var key := int(r["size"]) / 3
		var list: Array = buckets.get(key, [])
		list.append(r)
		buckets[key] = list
	for key in buckets:
		var list: Array = buckets[key]
		if list.size() < 5:
			continue
		for stat in ["peak_speed", "kills"]:
			var values: Array = list.map(func(r): return float(r[stat]))
			values.sort()
			var median: float = values[values.size() / 2]
			if median <= 0.0:
				continue
			for r in list:
				if float(r[stat]) > OUTLIER * median:
					soft.append("seed %d outlier_%s %s" % [int(r["seed"]), stat, r[stat]])

	var seconds_ok := runs.all(func(r): return int(r["ticks"]) >= SECONDS * 90 or String(r["ended"]) != "")
	var covered := {}
	for k in natural:
		covered[k] = true
	for k in injected:
		covered[k] = true
	# No wall clock decides this verdict: the seed list and --seconds are fixed, a seed
	# ends on physics ticks (the tool sets SimClock.ticks), and the tool's one wall-clock
	# read only feeds the soft frame_time anomaly.
	var code := 0 if all_ok else (worst_code if worst_code != 0 else 1)
	_report("fuzz slice ran", code == 0 and runs.size() == SEEDS.size() and not script_error and seconds_ok,
		"exit %d, %d seed records of %d s each, script error %s, every seed ran its span %s" % [code, runs.size(), SECONDS, script_error, seconds_ok])
	_report("every trigger reached", covered.size() == 12,
		"%d of 12 kinds fired, %d naturally %s, the rest injected %s" % [covered.size(), natural.size(), natural.keys(), injected.keys()])
	_report("hard invariants", hard.is_empty(), "violations %s" % [hard])
	print("[anomalies] %d soft anomalies for HAPPY-ACCIDENTS.md: %s -> PASS" % [soft.size(), soft])
	_rm_tree(out)
	print("item_fuzz_smoke_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
