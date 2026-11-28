extends SceneTree

const Game := preload("res://src/game.gd")
const BotOptions := preload("res://tools/bot_options.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Roster := preload("res://src/combat/roster.gd")
const TelegraphScript := preload("res://src/combat/telegraph.gd")

const SPECIALS := [
	{"name": "foreman", "id": "foreman", "crew": ["hooker", "plated_brute", "plated_brute", "chaser", "chaser", "lobber"],
		"model": {"wipe_every": 5.0}},
	{"name": "dispatcher", "id": "dispatcher", "crew": ["chaser", "chaser", "chaser", "lobber", "lobber", "bola_thrower"],
		"model": {"spawn_every": 8.0, "spawn": "chaser", "alive_cap": 6}},
	{"name": "splitter", "id": "splitter", "crew": ["chaser", "chaser", "lobber", "lobber", "bola_thrower", "plated_brute"]},
	{"name": "linker", "id": "linker", "crew": ["plated_brute", "plated_brute", "lobber", "lobber", "chaser", "chaser"]},
	{"name": "control_mag_trapper", "id": "mag_trapper", "crew": ["bola_thrower", "bola_thrower", "chaser", "chaser", "lobber", "lobber"],
		"control": true},
]
const ARMS := ["target", "ignore"]
const TARGET_RATIO := 1.25
const MIN_HULL := 5.0
const MIN_DAMAGE := 10.0
const DODGE := 0.65
const CREW_RANGE := 22.0
const CREW_SPREAD := 5.0
const SPECIAL_BEHIND := 12.0
const MODEL_HP := 120.0
const SETTLE_S := 1.0
const WALL_LIMIT_S := 900.0


class PriorityDriver extends BotDriver:
	var arm := "target"
	var special: Node3D = null
	var crew: Array = []
	var dodge := 1.0
	var _dodge_rng := RandomNumberGenerator.new()
	var _answers := {}

	func _threats() -> Array:
		var out: Array = []
		for h in super._threats():
			var id: int = h.get_instance_id()
			if not _answers.has(id):
				_answers[id] = _dodge_rng.randf() < dodge
			if _answers[id]:
				out.append(h)
		return out

	func _roam(delta: float) -> void:
		var target := pick()
		if target == null:
			source.hold = {}
			return
		_fight(target, delta)

	func pick() -> Node3D:
		if arm == "target" and alive(special):
			return special
		var ball: Vector3 = game.player.ball_position()
		var best: Node3D = null
		var best_d := INF
		for enemy in crew:
			if not alive(enemy):
				continue
			var d := ball.distance_to(enemy.global_position)
			if d < best_d:
				best_d = d
				best = enemy
		if best == null and alive(special):
			return special
		return best

	static func alive(enemy) -> bool:
		return enemy != null and is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead())


var _settings := {}
var _bot_options
var _cap := 120.0
var _parent := false
var _done := false

var _queue: Array = []
var _running: Array = []
var _results: Array = []
var _rows: Array = []
var _procs := 4
var _total := 0
var _sweep_dir := ""

var _row := {}
var _mode := ""
var _run_seed := 0
var _game
var _driver
var _spawned := false
var _hull_start := 0.0
var _taken := 0.0
var _hits := 0
var _special_dead_s := -1.0
var _cleared_s := -1.0
var _wipes := 0
var _warnings := 0
var _dispatched := 0
var _joined := 0
var _encounter_up := false
var _special_split := false
var _model_clock := 0.0
var _scrap_serial := 0
var _counter_serial := 0


func _initialize() -> void:
	SimClock.ticks = true
	_settings = _parse(OS.get_cmdline_user_args())
	_bot_options = BotOptions.new(_settings, self)
	_cap = float(_settings.get("cap", "120"))
	if _settings.has("special"):
		_begin_child()
		return
	if not _settings.has("out"):
		printerr("priority_proof: usage: -- --out=<abs json> [--procs=4] [--seeds=1,...,8] [--cap=120] [--start-mass=0] [--dodge=0.65] [--hp-mult=1] [--specials=a,b]")
		quit(2)
		return
	var seeds: Array[int] = []
	for part in String(_settings.get("seeds", "1,2,3,4,5,6,7,8")).split(",", false):
		seeds.append(int(part))
	var wanted := String(_settings.get("specials", "")).split(",", false)
	var n := 0
	for row in SPECIALS:
		if not wanted.is_empty() and row["name"] not in wanted:
			continue
		var mode := mode_of(row)
		_rows.append({"row": row, "mode": mode})
		if mode == "not_built":
			continue
		for seed_value in seeds:
			for arm in ARMS:
				_queue.append({"n": n, "special": row["name"], "mode": mode, "arm": arm, "seed": seed_value})
				n += 1
	_total = n
	_procs = clampi(int(_settings.get("procs", "4")), 1, 8)
	_sweep_dir = OS.get_user_data_dir().path_join("priority_proof").path_join("p%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_sweep_dir)
	_parent = true


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			out[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	return out


static func row_named(name: String) -> Dictionary:
	for row in SPECIALS:
		if row["name"] == name:
			return row
	return {}


static func mode_of(row: Dictionary) -> String:
	if row.get("control", false) or (Roster.ROWS.has(row["id"]) and Roster.built(row["id"])):
		return "built"
	return "model" if row.has("model") else "not_built"


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
	var home := _sweep_dir.path_join("job%d" % job["n"])
	DirAccess.make_dir_recursive_absolute(home)
	var args := PackedStringArray(["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tools/priority_proof.gd", "--", "--special=" + String(job["special"]),
			"--mode=" + String(job["mode"]), "--arm=" + String(job["arm"]), "--run-seed=%d" % job["seed"],
			"--cap=%s" % _cap, "--result=" + home.path_join("result.json"), "--home=" + home,
			"--start-mass=%s" % _settings.get("start-mass", "0")])
	for key in ["dodge", "hp-mult", "spawn-every"]:
		if _settings.has(key):
			args.append("--%s=%s" % [key, _settings[key]])
	for key in BotOptions.FAST_FLAGS:
		if _settings.has(key):
			args.append("--%s=%s" % [key, _settings[key]])
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


func _reap(run: Dictionary, timed_out: bool) -> void:
	_running.erase(run)
	var home: String = run["home"]
	var path := home.path_join("result.json")
	var result = null
	if FileAccess.file_exists(path) and not timed_out:
		result = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not result is Dictionary:
		result = {"special": run["special"], "mode": run["mode"], "arm": run["arm"], "seed": run["seed"],
				"outcome": "wall_timeout" if timed_out else "no_result"}
	_results.append(result)
	_remove_tree(home)
	print("priority_proof: %d of %d: %s" % [_results.size(), _total, JSON.stringify(result)])


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _merge() -> void:
	var report := summarize(_rows, _results, _cap)
	var path := String(_settings["out"])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	for line in table(report):
		print(line)
	_remove_tree(_sweep_dir)
	quit(0)


static func summarize(rows: Array, results: Array, cap: float) -> Dictionary:
	var out := {"target_ratio": TARGET_RATIO, "cap_s": cap, "specials": []}
	for entry in rows:
		var row: Dictionary = entry["row"]
		var item := {"name": row["name"], "id": row["id"], "mode": entry["mode"], "control": row.get("control", false)}
		if entry["mode"] == "not_built":
			item["verdict"] = "not built"
			out["specials"].append(item)
			continue
		var by_arm := {"target": {}, "ignore": {}}
		for r in results:
			if r.get("special") == row["name"] and r.has("hull_lost"):
				by_arm[r["arm"]][int(r["seed"])] = r
		for arm in ARMS:
			var hull := []
			var damage := []
			var clear := []
			var warned := []
			var outcomes := {}
			for r in by_arm[arm].values():
				hull.append(float(r["hull_lost"]))
				damage.append(float(r.get("damage_taken", 0.0)))
				warned.append(float(r.get("warnings", 0)))
				clear.append(float(r["clear_s"]) if float(r["clear_s"]) >= 0.0 else cap)
				outcomes[r["outcome"]] = int(outcomes.get(r["outcome"], 0)) + 1
			item[arm] = {"runs": hull.size(), "hull_mean": snappedf(mean(hull), 0.1), "hull_median": snappedf(median(hull), 0.1),
					"damage_mean": snappedf(mean(damage), 0.1),
					"clear_mean_s": snappedf(mean(clear), 0.1), "warnings_mean": snappedf(mean(warned), 0.1),
					"outcomes": outcomes}
		var worse := 0
		var damage_worse := 0
		var paired := 0
		var seed_ratios := []
		for s in by_arm["target"]:
			if by_arm["ignore"].has(s):
				paired += 1
				var ti := float(by_arm["target"][s]["hull_lost"])
				var ii := float(by_arm["ignore"][s]["hull_lost"])
				if ii > ti:
					worse += 1
				seed_ratios.append(ii / ti if ti > 0.0 else (INF if ii > 0.0 else 1.0))
				if float(by_arm["ignore"][s].get("damage_taken", 0.0)) > float(by_arm["target"][s].get("damage_taken", 0.0)):
					damage_worse += 1
		item["paired_seeds"] = paired
		item["ignore_worse_seeds"] = worse
		item["ignore_damage_worse_seeds"] = damage_worse
		item["median_ratio"] = snappedf(median(seed_ratios), 0.01) if not seed_ratios.is_empty() else 1.0
		var t: float = item["target"]["hull_mean"]
		var i: float = item["ignore"]["hull_mean"]
		item["ratio"] = _ratio(i, t)
		item["verdict"] = _verdict(paired, i, item["ratio"], MIN_HULL)
		var dt: float = item["target"]["damage_mean"]
		var di: float = item["ignore"]["damage_mean"]
		item["damage_ratio"] = _ratio(di, dt)
		item["damage_verdict"] = _verdict(paired, di, item["damage_ratio"], MIN_DAMAGE)
		out["specials"].append(item)
	return out


static func _ratio(ignore: float, target: float) -> float:
	return snappedf(ignore / target, 0.01) if target > 0.0 else (INF if ignore > 0.0 else 1.0)


static func _verdict(paired: int, ignore: float, ratio: float, floor_value: float) -> String:
	if paired == 0:
		return "no runs"
	if ignore < floor_value:
		return "too little damage"
	return "pass" if ratio >= TARGET_RATIO else "miss"


static func table(report: Dictionary) -> Array:
	var lines := ["priority_proof: special | mode | target hull mean/median/clear | ignore hull mean/median/clear | ratio | median seed ratio | ignore worse | verdict"
		+ " | target/ignore damage | damage ratio | damage worse | damage verdict"]
	for item in report["specials"]:
		if item["verdict"] == "not built":
			lines.append("  %s | not built | - | - | - | - | - | not built | - | - | - | not built" % item["name"])
			continue
		lines.append("  %s | %s | %.1f / %.1f / %.1fs | %.1f / %.1f / %.1fs | %s | %s | %d of %d | %s | %.1f / %.1f | %s | %d of %d | %s" % [
				item["name"], item["mode"],
				item["target"]["hull_mean"], item["target"]["hull_median"], item["target"]["clear_mean_s"],
				item["ignore"]["hull_mean"], item["ignore"]["hull_median"], item["ignore"]["clear_mean_s"],
				str(item["ratio"]), str(item["median_ratio"]), item["ignore_worse_seeds"], item["paired_seeds"], item["verdict"],
				item["target"]["damage_mean"], item["ignore"]["damage_mean"], str(item["damage_ratio"]),
				item["ignore_damage_worse_seeds"], item["paired_seeds"], item["damage_verdict"]])
	return lines


static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	return float(sorted[mid]) if sorted.size() % 2 == 1 else (float(sorted[mid - 1]) + float(sorted[mid])) * 0.5


static func mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += float(v)
	return total / values.size()


func _begin_child() -> void:
	_row = row_named(String(_settings["special"]))
	_mode = String(_settings.get("mode", ""))
	if _row.is_empty() or _mode not in ["built", "model"] or not _settings.has("result") or not _settings.has("home"):
		printerr("priority_proof: a child needs a known --special, --mode=built|model, --result and --home")
		quit(2)
		return
	_run_seed = int(_settings.get("run-seed", "1"))
	node_added.connect(_on_node_added)
	seed(_run_seed)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _on_node_added(node: Node) -> void:
	if _game == null or _game.build == null:
		return
	if _spawned and node.get_script() == TelegraphScript and node.get_parent() == _game:
		_warnings += 1
	if "_strafe" in node:
		node.set_meta("bot_strafe", 1.0 if (_counter_serial + _run_seed) % 2 == 0 else -1.0)
		_counter_serial += 1
	if node.get_parent() == _game.build.scrap:
		node.set_meta("bot_side", 1.0 if (_scrap_serial + _run_seed) % 2 == 0 else -1.0)
		_scrap_serial += 1


func _physics_process(delta: float) -> bool:
	if _parent or _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_game.ctx.calm = true
		var home := String(_settings["home"])
		_game.codex.storage_dir = home
		_game.run_log.storage_dir = home
		_driver = PriorityDriver.new(_game, "skipper", _run_seed)
		_driver.arm = String(_settings.get("arm", "target"))
		_driver.dodge = float(_settings.get("dodge", str(DODGE)))
		_driver._dodge_rng.seed = hash(["dodge", _run_seed])
		_driver.stage_limit = INF
		_game.presentation.audio.bake_now()
		_bot_options.apply_audio(_game.presentation.audio)
		_game.events.player_hit.connect(func(amount: float, _source: String):
			if _spawned:
				_hits += 1
				_taken += amount)
		_game.ctx.events.enemy_spawned.connect(_on_enemy_spawned)
		_game.run.run_seed_override = _run_seed
		_driver.start()
		return false
	if not _spawned:
		_grounded_s = _grounded_s + delta if _game.flow.in_stage() and _game.player.state.grounded else 0.0
		if _grounded_s >= SETTLE_S:
			_spawn_encounter()
		else:
			_driver.source.hold = {}
			return false
	var over: bool = _driver.tick(delta)
	_step_model(delta)
	var t := _encounter_s()
	if _special_dead_s < 0.0 and not PriorityDriver.alive(_driver.special):
		_special_dead_s = t
	if not over and _cleared():
		_cleared_s = t
		_driver._end("cleared")
		over = true
	if not over and t >= _cap:
		_driver._end("capped")
		over = true
	if not over:
		return false
	_done = true
	_record()
	_game.free()
	_game = null
	quit(0)
	return false


var _start_s := 0.0
var _grounded_s := 0.0


func _on_enemy_spawned(enemy: Node3D, _kind: String) -> void:
	if _encounter_up and enemy not in _driver.crew:
		_driver.crew.append(_toughen(enemy))
		_joined += 1


func _encounter_s() -> float:
	return _game.run.stage_time - _start_s


func _cleared() -> bool:
	if not _game.get_tree().get_nodes_in_group("enemy_pending").is_empty():
		return false
	for enemy in _driver.crew:
		if PriorityDriver.alive(enemy):
			return false
	return not PriorityDriver.alive(_driver.special)


func _spawn_encounter() -> void:
	_spawned = true
	_start_s = _game.run.stage_time
	_hull_start = float(_game.run.metrics["hull_damage"])
	var ball: Vector3 = _game.player.ball_position()
	var forward: Vector3 = _game.ctx.aim_forward()
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	if forward.length() < 0.5:
		forward = Vector3.FORWARD
	var side := Vector3(-forward.z, 0.0, forward.x)
	var kinds: Array = _row["crew"]
	var spawner = _game.combat
	for i in kinds.size():
		var flat: Vector3 = ball + forward * CREW_RANGE + side * CREW_SPREAD * (i - (kinds.size() - 1) * 0.5)
		_driver.crew.append(_toughen(spawner.spawn_enemy(kinds[i], _drop(flat))))
	var at := _drop(ball + forward * (CREW_RANGE + SPECIAL_BEHIND))
	if _mode == "built":
		_driver.special = _toughen(spawner.spawn_enemy(String(_row["id"]), at))
		if _driver.special != null and _driver.special.has_signal("dispatched"):
			_driver.special.dispatched.connect(func(add: Node3D):
				_driver.crew.append(_toughen(add))
				_dispatched += 1)
		if _driver.special != null and _driver.special.has_signal("wiped"):
			_driver.special.wiped.connect(func(_members: Array): _wipes += 1)
		var special: Node3D = _driver.special
		if special != null and special.has_signal("died"):
			special.died.connect(func(_where: Vector3, _scrap: int): _special_split = bool(special.get_meta("split", false)))
	else:
		var body: Node3D = spawner.spawn_enemy("vault", at)
		body.plating = 0.0
		body._set_health(MODEL_HP * float(_settings.get("hp-mult", "1")))
		_driver.special = body
	_encounter_up = true


func _toughen(enemy: Node3D) -> Node3D:
	var mult := float(_settings.get("hp-mult", "1"))
	if mult != 1.0 and enemy != null:
		enemy._set_health(float(enemy.max_hp) * mult)
	return enemy


func _drop(flat: Vector3) -> Vector3:
	return _game.ctx.terrain.drop_point(flat.x, flat.z, 1.8)


func _step_model(delta: float) -> void:
	if _mode != "model" or not _spawned or not PriorityDriver.alive(_driver.special):
		return
	var model: Dictionary = _row["model"]
	_model_clock += delta
	if model.has("wipe_every") and _model_clock >= float(model["wipe_every"]):
		_model_clock = 0.0
		_wipes += 1
		for enemy in _driver.crew:
			if PriorityDriver.alive(enemy):
				_game.combat.wipe_shred(enemy)
	if model.has("spawn_every") and _model_clock >= float(_settings.get("spawn-every", model["spawn_every"])):
		_model_clock = 0.0
		var standing := 0
		for enemy in _driver.crew:
			if PriorityDriver.alive(enemy):
				standing += 1
		if standing < int(model["alive_cap"]):
			var from: Vector3 = _driver.special.global_position
			_game.combat.spawn_enemy(String(model["spawn"]), _drop(from + Vector3(2.5, 0.0, 0.0)))
			_dispatched += 1


func _record() -> void:
	var lost: float = float(_game.run.metrics["hull_damage"]) - _hull_start if _spawned else 0.0
	var killed := 0
	for enemy in _driver.crew:
		if not PriorityDriver.alive(enemy):
			killed += 1
	var row := {"special": _row["name"], "mode": _mode, "arm": _driver.arm, "seed": _run_seed,
			"class": _driver.class_id(), "outcome": _driver.outcome, "hull_lost": snappedf(lost, 0.1),
			"hits": _hits, "damage_taken": snappedf(_taken, 0.1), "clear_s": snappedf(_cleared_s, 0.01),
			"special_dead_s": snappedf(_special_dead_s, 0.01), "crew_spawned": _driver.crew.size(),
			"crew_killed": killed, "wipes": _wipes, "warnings": _warnings, "dispatched": _dispatched, "joined": _joined, "special_split": _special_split,
			"encounter_s": snappedf(_encounter_s() if _spawned else 0.0, 0.01)}
	for key in ["drops", "landed_hits"]:
		if is_instance_valid(_driver.special) and key in _driver.special:
			row[key] = int(_driver.special.get(key))
	var file := FileAccess.open(String(_settings["result"]), FileAccess.WRITE)
	file.store_string(JSON.stringify(row) + "\n")
	file.close()
