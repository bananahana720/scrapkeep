extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")

# The Warden posture sweep (design-v3/LEGIBILITY.md section 4, tools/posture_sweep.md).
# For every cell of the grid it plays the brawler, the skipper and the camper on the slice
# over seeds 1 to 5 and writes one TSV row per cell. The seam is ctx.stages: after the game
# is built the sweep swaps in a Table whose of() returns the slice row with warden_plating
# and a posture dictionary replaced, so no source file changes between cells.
#
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/posture_sweep.gd \
#     -- --out=<abs tsv> [--runs=<abs tsv>] [--procs=6] [--seeds=1,2,3,4,5] [--cap=240]
#     [--plating=45,60] [--curve=1,2] [--shatter=true,false]
#
# A parent run (no --part) splits the cells over --procs child processes of this same
# script, waits for them and merges their rows in grid order. --part=<n>/<of> runs every
# <of>th cell from <n> and writes to --out as is. A run that never breaks the Warden counts
# as the cap in the medians and ranges.

const PLATINGS := [45.0, 60.0, 75.0, 90.0]
const CURVES := [1.0, 2.0, 3.0]
const SHATTERS := [true, false]
const POLICIES := ["brawler", "skipper", "camper"]
const HEADER := ["plating", "curve", "ram_shatters", "brawler_median_s", "brawler_min_s", "brawler_max_s",
		"skipper_median_s", "skipper_min_s", "skipper_max_s", "skipper_to_brawler", "camper_broke",
		"brawler_heft_median", "brawler_never", "skipper_never", "camper_never", "brawler_died", "skipper_died"]
const RUN_HEADER := ["plating", "curve", "ram_shatters", "policy", "seed", "outcome", "broke", "fight_s", "heft", "game_s"]


# The slice table with one Warden row changed. Every lookup the game makes on ctx.stages.
class Table extends RefCounted:
	const BOSS := SliceDefs.BOSS
	const COUNT := SliceDefs.COUNT
	const DEFS := SliceDefs.DEFS
	var plating := 45.0
	var posture := {}

	func of(stage: int) -> Dictionary:
		var row: Dictionary = SliceDefs.of(stage).duplicate(true)
		row["warden_plating"] = plating
		row["posture"] = posture
		return row

	func is_last(stage: int) -> bool:
		return SliceDefs.is_last(stage)

	func synergy_in_play(id: String) -> bool:
		return SliceDefs.synergy_in_play(id)

	func packs() -> Array:
		return SliceDefs.packs()

	func elite() -> Dictionary:
		return SliceDefs.elite()

	func elite_arrival() -> int:
		return SliceDefs.elite_arrival()

	func has_vault() -> bool:
		return SliceDefs.has_vault()


var _settings := {}
var _cells: Array = []
var _seeds: Array[int] = []
var _cap := 240.0
var _jobs: Array = []
var _job := -1
var _game
var _driver
var _table: Table
var _swapped := false
var _rows: Array[String] = []
var _run_rows: Array[String] = []
var _results := {}
var _pids: Array[int] = []
var _parts: Array[String] = []
var _parent := false


func _initialize() -> void:
	SimClock.ticks = true
	_settings = _parse(OS.get_cmdline_user_args())
	if not _settings.has("out"):
		printerr("posture_sweep: usage: -- --out=<abs tsv> [--runs=<abs tsv>] [--procs=6] [--seeds=1,2,3,4,5] [--cap=240]")
		quit(2)
		return
	for part in String(_settings.get("seeds", "1,2,3,4,5")).split(",", false):
		_seeds.append(int(part))
	_cap = float(_settings.get("cap", "240"))
	_cells = _grid()
	if not _settings.has("part"):
		_parent = true
		_launch_children()
		return
	var split := String(_settings["part"]).split("/")
	var mine: Array = []
	for i in _cells.size():
		if i % int(split[1]) == int(split[0]):
			mine.append(_cells[i])
	_cells = mine
	for cell in _cells:
		for policy in POLICIES:
			for seed_value in _seeds:
				_jobs.append({"cell": cell, "policy": policy, "seed": seed_value})
	_next()


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			out[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	return out


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


func _launch_children() -> void:
	var procs := clampi(int(_settings.get("procs", "6")), 1, 6)
	for n in procs:
		var out: String = String(_settings["out"]) + ".part%d" % n
		var args := PackedStringArray(["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"),
				"--script", "res://tools/posture_sweep.gd", "--", "--out=" + out, "--part=%d/%d" % [n, procs]])
		for key in ["seeds", "cap", "plating", "curve", "shatter"]:
			if _settings.has(key):
				args.append("--%s=%s" % [key, _settings[key]])
		if _settings.has("runs"):
			args.append("--runs=" + String(_settings["runs"]) + ".part%d" % n)
		_parts.append(out)
		_pids.append(OS.create_process(OS.get_executable_path(), args))


func _process(_delta: float) -> bool:
	if not _parent:
		return false
	for pid in _pids:
		if OS.is_process_running(pid):
			return false
	_merge()
	return false


func _merge() -> void:
	var rows := {}
	for path in _parts:
		for line in _read_lines(path):
			var cols: PackedStringArray = line.split("\t")
			rows["%s|%s|%s" % [cols[0], cols[1], cols[2]]] = line
		DirAccess.remove_absolute(path)
	var out := ["\t".join(HEADER)]
	for cell in _cells:
		var key := "%s|%s|%s" % [str(cell["plating"]), str(cell["curve"]), str(cell["ram_shatters"])]
		if rows.has(key):
			out.append(rows[key])
	_write(String(_settings["out"]), out)
	if _settings.has("runs"):
		var runs := ["\t".join(RUN_HEADER)]
		for n in _parts.size():
			var path := String(_settings["runs"]) + ".part%d" % n
			runs.append_array(_read_lines(path))
			DirAccess.remove_absolute(path)
		_write(String(_settings["runs"]), runs)
	print("posture_sweep: %d of %d cell(s) written to %s" % [out.size() - 1, _cells.size(), _settings["out"]])
	quit(0)


func _read_lines(path: String) -> Array:
	var out := []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	for line in file.get_as_text().split("\n", false):
		if not line.begins_with(HEADER[0]):
			out.append(line)
	return out


func _write(path: String, lines: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()


func _next() -> void:
	_job += 1
	if _job >= _jobs.size():
		_finish()
		return
	Engine.time_scale = 1.0
	seed(int(_jobs[_job]["seed"]))
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_driver = null
	_swapped = false


func _physics_process(delta: float) -> bool:
	if _parent or _game == null or _game.flow == null:
		return false
	var job: Dictionary = _jobs[_job]
	if _driver == null:
		if not _swapped:
			_table = Table.new()
			_table.plating = float(job["cell"]["plating"])
			_table.posture = {"curve": float(job["cell"]["curve"]), "ram_shatters": bool(job["cell"]["ram_shatters"])}
			_game.ctx.stages = _table
			_swapped = true
		_game.codex.storage_dir = "user://posture_sweep"
		_game.run_log.storage_dir = "user://posture_sweep"
		_driver = BotDriver.new(_game, String(job["policy"]), int(job["seed"]))
		_driver.stage_limit = _cap * 4.0
		_driver.fight_limit = _cap
		_driver.start()
		return false
	var over: bool = _driver.tick(delta)
	if not over and _driver._note.get("warden_broken_s") != null:
		_driver._end("broken")
		over = true
	if not over:
		return false
	_record(job)
	_game.free()
	_game = null
	_next()
	return false


func _record(job: Dictionary) -> void:
	var note: Dictionary = _driver.stage_notes[_driver.stage_notes.size() - 1] if not _driver.stage_notes.is_empty() else {}
	var broke: bool = note.get("warden_broken_s") != null and note.get("warden_fight_s") != null
	var fight := _cap
	if broke:
		fight = float(note["warden_broken_s"]) - float(note["warden_fight_s"])
	var cell: Dictionary = job["cell"]
	var key := _key(cell)
	if not _results.has(key):
		_results[key] = {}
	if not _results[key].has(job["policy"]):
		_results[key][job["policy"]] = []
	_results[key][job["policy"]].append({"broke": broke, "fight": fight, "heft": float(note.get("warden_fight_heft", 0.0)),
			"died": _driver.outcome == "died"})
	_run_rows.append("\t".join([str(cell["plating"]), str(cell["curve"]), str(cell["ram_shatters"]), job["policy"],
			str(job["seed"]), _driver.outcome, str(broke), "%.2f" % fight, str(note.get("warden_fight_heft", "")),
			"%.2f" % (float(_driver.ticks) / float(Engine.physics_ticks_per_second))]))
	print("posture_sweep: %s plating %s curve %s shatter %s %s seed %d -> %s, fight %.1f s" % [key, cell["plating"], cell["curve"],
			cell["ram_shatters"], job["policy"], job["seed"], _driver.outcome, fight])


func _key(cell: Dictionary) -> String:
	return "%s|%s|%s" % [str(cell["plating"]), str(cell["curve"]), str(cell["ram_shatters"])]


static func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return 0.0
	var n := sorted.size()
	return float(sorted[n / 2]) if n % 2 == 1 else (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) / 2.0


func _finish() -> void:
	var out := ["\t".join(HEADER)]
	for cell in _cells:
		var by: Dictionary = _results.get(_key(cell), {})
		var brawler := _column(by.get("brawler", []), "fight")
		var skipper := _column(by.get("skipper", []), "fight")
		var camper: Array = by.get("camper", [])
		var ratio := _median(skipper) / _median(brawler) if _median(brawler) > 0.0 else 0.0
		out.append("\t".join([str(cell["plating"]), str(cell["curve"]), str(cell["ram_shatters"]),
				"%.1f" % _median(brawler), "%.1f" % _low(brawler), "%.1f" % _high(brawler),
				"%.1f" % _median(skipper), "%.1f" % _low(skipper), "%.1f" % _high(skipper), "%.2f" % ratio,
				str(_count(camper, "broke", true)), "%.3f" % _median(_column(by.get("brawler", []), "heft")),
				str(_count(by.get("brawler", []), "broke", false)), str(_count(by.get("skipper", []), "broke", false)),
				str(_count(camper, "broke", false)), str(_count(by.get("brawler", []), "died", true)),
				str(_count(by.get("skipper", []), "died", true))]))
	_write(String(_settings["out"]), out)
	if _settings.has("runs"):
		_write(String(_settings["runs"]), _run_rows)
	quit(0)


static func _column(runs: Array, key: String) -> Array:
	var out := []
	for run in runs:
		out.append(run[key])
	return out


static func _low(values: Array) -> float:
	return float(values.min()) if not values.is_empty() else 0.0


static func _high(values: Array) -> float:
	return float(values.max()) if not values.is_empty() else 0.0


static func _count(runs: Array, key: String, want: bool) -> int:
	var n := 0
	for run in runs:
		if bool(run[key]) == want:
			n += 1
	return n
