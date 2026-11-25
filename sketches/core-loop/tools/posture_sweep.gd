extends SceneTree

const Game := preload("res://src/game.gd")
const BotOptions := preload("res://tools/bot_options.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")


const ARMS := [
	{"name": "small", "policy": "skipper", "mass": 0.0},
	{"name": "mid", "policy": "skipper", "mass": 225.0},
	{"name": "grown", "policy": "skipper", "mass": 540.0},
	{"name": "camper", "policy": "camper", "mass": 0.0},
]
const PLATINGS := [70.0, 90.0, 110.0, 130.0]
const CURVES := [1.0, 2.0]
const SHATTERS := [true, false]
const RUN_HEADER := ["arm", "seed", "plating", "curve", "ram_shatters", "outcome", "broke", "engaged_s", "struck_s",
		"turn_s", "fight_s", "mass", "heft", "game_s", "note"]
const CELL_HEAD := ["plating", "curve", "ram_shatters"]
const CELL_TAIL := ["small_to_grown", "band_grown", "band_small", "band_mid", "band_camper", "pass"]
const C_BROKE := 6
const C_FIGHT := 10
const C_MASS := 11
const C_HEFT := 12
const WALL_LIMIT_S := 1500.0


class Table extends RefCounted:
	const BOSS := SliceDefs.BOSS
	const COUNT := SliceDefs.COUNT
	const PICK_ON_CLASS_UP := SliceDefs.PICK_ON_CLASS_UP
	const DEFS := SliceDefs.DEFS
	var plating := 45.0
	var posture := {}

	func of(stage: int) -> Dictionary:
		var row: Dictionary = SliceDefs.of(stage).duplicate(true)
		row["warden_plating"] = plating
		var numbers: Dictionary = row.get("posture", {})
		numbers.merge(posture, true)
		row["posture"] = numbers
		return row

	func is_last(stage: int) -> bool:
		return SliceDefs.is_last(stage)

	func world_of(stage: int) -> int:
		return SliceDefs.world_of(stage)

	func local(stage: int) -> int:
		return SliceDefs.local(stage)

	func first_of(world: int) -> int:
		return SliceDefs.first_of(world)

	func last_of(world: int) -> int:
		return SliceDefs.last_of(world)

	func worlds() -> Array:
		return SliceDefs.worlds()

	func is_world_last(stage: int) -> bool:
		return SliceDefs.is_world_last(stage)

	func is_run_last(stage: int) -> bool:
		return SliceDefs.is_run_last(stage)

	func synergy_in_play(id: String) -> bool:
		return SliceDefs.synergy_in_play(id)

	func part_in_play(id: String) -> bool:
		return SliceDefs.part_in_play(id)

	func parts_listed() -> bool:
		return SliceDefs.parts_listed()

	func packs() -> Array:
		return SliceDefs.packs()

	func elite() -> Dictionary:
		return SliceDefs.elite()

	func elite_arrival() -> int:
		return SliceDefs.elite_arrival()

	func has_vault() -> bool:
		return SliceDefs.has_vault()


var _settings := {}
var _bot_options
var _cap := 240.0
var _parent := false
var _done := false

var _cells: Array = []
var _arms: Array = []
var _seeds: Array[int] = []
var _queue: Array = []
var _running: Array = []
var _results := {}
var _procs := 6
var _total := 0
var _sweep_dir := ""

var _arm := {}
var _run_seed := 0
var _cell := {}
var _game
var _driver
var _swapped := false
var _struck_s := -1.0
var _struck_mass := 0.0
var _struck_heft := 0.0
var _scrap_serial := 0
var _counter_serial := 0


func _initialize() -> void:
	SimClock.ticks = true
	_settings = _parse(OS.get_cmdline_user_args())
	_bot_options = BotOptions.new(_settings, self)
	_cap = float(_settings.get("cap", "240"))
	if _settings.has("arm"):
		_begin_child()
		return
	if not _settings.has("out"):
		printerr("posture_sweep: usage: -- --out=<abs tsv> --runs=<abs tsv> [--procs=6] [--seeds=1,2,3,4,5] [--cap=240]")
		quit(2)
		return
	for part in String(_settings.get("seeds", "1,2,3,4,5")).split(",", false):
		_seeds.append(int(part))
	var wanted := String(_settings.get("arms", "")).split(",", false)
	for arm in ARMS:
		if wanted.is_empty() or arm["name"] in wanted:
			_arms.append(arm)
	_cells = _grid()
	_procs = clampi(int(_settings.get("procs", "6")), 1, 6)
	_sweep_dir = OS.get_user_data_dir().path_join("posture_sweep").path_join("p%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_sweep_dir)
	var n := 0
	for i in _cells.size():
		for arm in _arms:
			for seed_value in _seeds:
				_queue.append({"n": n, "cell": i, "arm": arm["name"], "seed": seed_value})
				n += 1
	_total = n
	_parent = true


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			out[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	return out


static func arm_named(name: String) -> Dictionary:
	for arm in ARMS:
		if arm["name"] == name:
			return arm
	return {}


func _list(key: String, fallback: Array) -> Array:
	if not _settings.has(key):
		return fallback
	var out := []
	for part in String(_settings[key]).split(",", false):
		out.append(part == "true" if fallback[0] is bool else float(part))
	return out


func _grid() -> Array:
	var cells := []
	for plating in _list("plating", PLATINGS):
		for curve in _list("curve", CURVES):
			for shatter in _list("shatter", SHATTERS):
				cells.append({"plating": plating, "curve": curve, "ram_shatters": shatter})
	return cells


func _process(_delta: float) -> bool:
	if not _parent or _done:
		return false
	for run in _running.duplicate():
		if not OS.is_process_running(run["pid"]):
			_reap(run, false)
		elif float(Time.get_ticks_msec() - int(run["started"])) / 1000.0 > WALL_LIMIT_S:
			OS.kill(run["pid"])
			_reap(run, true)
	while _running.size() < _procs and not _queue.is_empty():
		_spawn(_queue.pop_front())
	if _running.is_empty() and _queue.is_empty():
		_done = true
		_merge()
		return false
	OS.delay_msec(250)
	return false


func _spawn(job: Dictionary) -> void:
	var cell: Dictionary = _cells[job["cell"]]
	var home := _sweep_dir.path_join("job%d" % job["n"])
	DirAccess.make_dir_recursive_absolute(home)
	var args := child_args(_settings, job, cell, _cap, home)
	var previous := {}
	for kind in ["DATA", "CONFIG", "CACHE"]:
		var key: String = "XDG_%s_HOME" % kind
		previous[key] = OS.get_environment(key)
		OS.set_environment(key, home.path_join("state-" + kind.to_lower()))
	var pid := OS.create_process(OS.get_executable_path(), args)
	for key in previous:
		if previous[key].is_empty():
			OS.unset_environment(key)
		else:
			OS.set_environment(key, previous[key])
	job["pid"] = pid
	job["home"] = home
	job["started"] = Time.get_ticks_msec()
	_running.append(job)


static func child_args(settings: Dictionary, job: Dictionary, cell: Dictionary, cap: float, home: String) -> PackedStringArray:
	var arm := arm_named(job["arm"])
	var args := PackedStringArray(["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tools/posture_sweep.gd", "--", "--arm=" + String(job["arm"]), "--run-seed=%d" % job["seed"],
			"--plating=%s" % cell["plating"], "--curve=%s" % cell["curve"], "--shatter=%s" % cell["ram_shatters"],
			"--cap=%s" % cap, "--result=" + home.path_join("result.tsv"), "--home=" + home])
	if settings.get("gate", "0") == "1":
		args.append("--gate=1")
	for key in BotOptions.FAST_FLAGS:
		if settings.has(key):
			args.append("--%s=%s" % [key, settings[key]])
	if float(arm["mass"]) > 0.0:
		args.append("--start-mass=%d" % int(arm["mass"]))
	return args


func _reap(run: Dictionary, timed_out: bool) -> void:
	_running.erase(run)
	var home: String = run["home"]
	var cell: Dictionary = _cells[run["cell"]]
	var line := ""
	var path := home.path_join("result.tsv")
	if FileAccess.file_exists(path):
		line = FileAccess.get_file_as_string(path).rstrip("\n")
	if line.is_empty() or timed_out:
		line = "\t".join([run["arm"], str(run["seed"]), str(cell["plating"]), str(cell["curve"]), str(cell["ram_shatters"]),
				"wall_timeout" if timed_out else "no_result", "false", "", "", "", "%.2f" % _cap, "", "", "", ""])
	_results[run["n"]] = {"job": run, "line": line}
	_remove_tree(home)
	print("posture_sweep: %d of %d: %s" % [_results.size(), _total, line.replace("\t", " ")])


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _merge() -> void:
	var by_cell := {}
	var runs := ["\t".join(RUN_HEADER)]
	for n in _total:
		if not _results.has(n):
			continue
		var line: String = _results[n]["line"]
		runs.append(line)
		var job: Dictionary = _results[n]["job"]
		var key := "%d|%s" % [job["cell"], job["arm"]]
		if not by_cell.has(key):
			by_cell[key] = []
		by_cell[key].append(line.split("\t"))
	var out := ["\t".join(cell_header(_arms))]
	for i in _cells.size():
		var cell: Dictionary = _cells[i]
		var by_arm := {}
		for arm in _arms:
			by_arm[arm["name"]] = by_cell.get("%d|%s" % [i, arm["name"]], [])
		out.append("\t".join(cell_row(cell, by_arm, _arms)))
	_write(String(_settings["out"]), out)
	if _settings.has("runs"):
		_write(String(_settings["runs"]), runs)
	_remove_tree(_sweep_dir)
	print("posture_sweep: %d cell(s), %d run(s) written to %s" % [_cells.size(), runs.size() - 1, _settings["out"]])
	quit(0)


static func cell_header(arms: Array) -> Array:
	var head := CELL_HEAD.duplicate()
	for arm in arms:
		for column in ["median_s", "min_s", "max_s", "broke", "mass_median", "heft_median"]:
			head.append("%s_%s" % [arm["name"], column])
	head.append_array(CELL_TAIL)
	return head


static func cell_row(cell: Dictionary, by_arm: Dictionary, arms: Array) -> Array:
	var row := [str(cell["plating"]), str(cell["curve"]), str(cell["ram_shatters"])]
	var stats := {}
	for arm in arms:
		var runs: Array = by_arm.get(arm["name"], [])
		var fights := []
		var masses := []
		var hefts := []
		var broke := 0
		for cols in runs:
			fights.append(float(cols[C_FIGHT]))
			if cols[C_BROKE] == "true":
				broke += 1
			if cols[C_MASS] != "":
				masses.append(float(cols[C_MASS]))
			if cols[C_HEFT] != "":
				hefts.append(float(cols[C_HEFT]))
		stats[arm["name"]] = {"median": median(fights), "broke": broke, "runs": runs.size()}
		row.append_array(["%.1f" % median(fights), "%.1f" % _low(fights), "%.1f" % _high(fights), str(broke),
				"%.1f" % median(masses), "%.3f" % median(hefts)])
	row.append_array(bands(stats))
	return row


static func bands(stats: Dictionary) -> Array:
	if not (stats.has("small") and stats.has("grown")):
		return ["", "n/a", "n/a", "n/a", "n/a", "n/a"]
	var grown: float = stats["grown"]["median"]
	var small: float = stats["small"]["median"]
	var ratio := small / grown if grown > 0.0 else 0.0
	var band_grown := grown >= 25.0 and grown <= 45.0
	var band_small: bool = ratio >= 2.0 and small <= 150.0 and stats["small"]["broke"] == stats["small"]["runs"]
	var band_mid := "n/a"
	if stats.has("mid"):
		band_mid = "pass" if stats["mid"]["median"] > grown and stats["mid"]["median"] < small else "miss"
	var band_camper := "n/a"
	if stats.has("camper"):
		band_camper = "pass" if stats["camper"]["broke"] == 0 else "miss"
	var verdict := "pass"
	if not (band_grown and band_small and band_mid == "pass" and band_camper == "pass"):
		verdict = "miss"
	if band_mid == "n/a" or band_camper == "n/a":
		verdict = "n/a"
	return ["%.2f" % ratio, "pass" if band_grown else "miss", "pass" if band_small else "miss", band_mid, band_camper, verdict]


static func median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return 0.0
	var n := sorted.size()
	return float(sorted[n / 2]) if n % 2 == 1 else (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) / 2.0


static func _low(values: Array) -> float:
	return float(values.min()) if not values.is_empty() else 0.0


static func _high(values: Array) -> float:
	return float(values.max()) if not values.is_empty() else 0.0


func _write(path: String, lines: Array) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()


func _begin_child() -> void:
	_arm = arm_named(String(_settings["arm"]))
	if _arm.is_empty() or not _settings.has("result") or not _settings.has("home"):
		printerr("posture_sweep: a child needs a known --arm, --result and --home")
		quit(2)
		return
	_run_seed = int(_settings.get("run-seed", "1"))
	_cell = {"plating": float(_settings.get("plating", "45")), "curve": float(_settings.get("curve", "1")),
			"ram_shatters": String(_settings.get("shatter", "true")) == "true"}
	node_added.connect(_on_node_added)
	Engine.time_scale = 1.0
	seed(_run_seed)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _on_node_added(node: Node) -> void:
	if _game == null or _game.build == null:
		return
	if "_strafe" in node:
		node.set_meta("bot_strafe", 1.0 if (_counter_serial + _run_seed) % 2 == 0 else -1.0)
		_counter_serial += 1
	if node.get_parent() == _game.build.scrap:
		node.set_meta("bot_side", 1.0 if (_scrap_serial + _run_seed) % 2 == 0 else -1.0)
		_scrap_serial += 1


func _physics_process(_delta: float) -> bool:
	if _parent or _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		if not _swapped:
			var table := Table.new()
			table.plating = float(_cell["plating"])
			table.posture = {"curve": float(_cell["curve"]), "ram_shatters": bool(_cell["ram_shatters"])}
			_game.ctx.stages = table
			_swapped = true
		var home := String(_settings["home"])
		_game.codex.storage_dir = home
		_game.run_log.storage_dir = home
		_driver = BotDriver.new(_game, String(_arm["policy"]), _run_seed)
		_driver.stage_limit = _cap * 4.0
		_driver.fight_limit = _cap
		_game.presentation.audio.bake_now()
		_bot_options.apply_audio(_game.presentation.audio)
		_game.events.enemy_struck.connect(_on_struck)
		_game.run.run_seed_override = _run_seed
		_driver.start()
		return false
	var over: bool = _driver.tick(_delta)
	if not over and _driver.warden_broken():
		_driver._end("broken")
		over = true
	if not over:
		return false
	_done = true
	_record()
	_game.free()
	_game = null
	quit(0)
	return false


func _on_struck(enemy: Node3D, _kind: String, _force: float) -> void:
	if _struck_s >= 0.0 or not is_instance_valid(enemy) or _game.flow == null or enemy != _game.flow.warden:
		return
	_struck_s = _game.run.stage_time
	_struck_mass = _game.run.mass
	_struck_heft = _game.run.heft()


static func measure(note: Dictionary, cap: float, struck := -1.0) -> Dictionary:
	var broke: bool = note.get("warden_broken_s") != null
	var turned = note.get("warden_fight_s")
	var start = null
	if struck >= 0.0 and turned != null:
		start = maxf(struck, float(turned))
	elif struck >= 0.0:
		start = struck
	else:
		start = BotDriver.fight_start_of(note)
	var fight := cap
	if broke and start != null:
		fight = float(note["warden_broken_s"]) - float(start)
	return {"broke": broke, "fight": fight, "engaged": note.get("warden_engaged_s"), "turned": turned}


func _record() -> void:
	var note: Dictionary = _driver.stage_notes[_driver.stage_notes.size() - 1] if not _driver.stage_notes.is_empty() else {}
	var run := measure(note, _cap, _struck_s)
	var struck: bool = _struck_s >= 0.0
	var line := "\t".join([String(_arm["name"]), str(_run_seed), str(_cell["plating"]), str(_cell["curve"]),
			str(_cell["ram_shatters"]), _driver.outcome, str(run["broke"]),
			str(run["engaged"]) if run["engaged"] != null else "", "%.2f" % _struck_s if struck else "",
			str(run["turned"]) if run["turned"] != null else "", "%.2f" % float(run["fight"]),
			"%.1f" % _struck_mass if struck else "", "%.3f" % _struck_heft if struck else "",
			"%.2f" % (float(_driver.ticks) / float(Engine.physics_ticks_per_second)), _anomaly(note)])
	var file := FileAccess.open(String(_settings["result"]), FileAccess.WRITE)
	file.store_string(line + "\n")
	file.close()


func _anomaly(note: Dictionary) -> String:
	var parts: Array[String] = []
	for anomaly in _game.run.anomalies:
		parts.append(String(anomaly.get("kind", "")))
	if note.get("stall_state") != null:
		parts.append("stall_state=%s" % str(note["stall_state"]))
	return ",".join(parts)
