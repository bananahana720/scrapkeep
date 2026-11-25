extends "res://tools/bot_run.gd"


var _census_game: Object = null
var _counts := {}
var _carve_s := 0.0
var _carves := 0
var _was_carving := false
var _done := false
var _run_time := 0.0
var _outcome := ""
var _rumble_log: Array = []
var _chains: Array = []
const TIMELINE_KINDS := ["carved", "near_miss", "player_hit", "slammed", "harpoon_bit"]
var _timeline: Array = []


func _bump(name: String) -> void:
	var stage := 0
	if _census_game != null and _census_game.run != null:
		stage = int(_census_game.run.stage)
	var row: Dictionary = _counts.get(name, {})
	row[str(stage)] = int(row.get(str(stage), 0)) + 1
	_counts[name] = row
	if name in TIMELINE_KINDS and _timeline.size() < 2000 and _census_game != null and _census_game.run != null:
		_timeline.append([snappedf(_census_game.run.run_time, 0.01), name, stage])


func _physics_process(delta: float) -> bool:
	var over := super(delta)
	if _game != null and _game != _census_game and _game.events != null:
		_census_game = _game
		for sig in _game.events.get_signal_list():
			var name := String(sig["name"])
			var argc: int = sig["args"].size()
			var count := (func(n: String): _bump(n)).bind(name)
			_game.events.connect(name, count.unbind(argc) if argc > 0 else count)
		_game.events.carved.connect(func(_at: Vector3, seconds: float, speed: float):
			if not _timeline.is_empty() and _timeline.back()[1] == "carved":
				_timeline.back().append({"seconds": snappedf(seconds, 0.01), "speed": snappedf(speed, 0.1)}))
	if _census_game != null and _census_game.player != null:
		var carving: bool = _census_game.player.state.carving
		if carving:
			_carve_s += delta
		if carving and not _was_carving:
			_carves += 1
		_was_carving = carving
	if _census_game != null and _census_game.run != null:
		_run_time = float(_census_game.run.run_time)
		var juice = _census_game.presentation.get("juice") if _census_game.presentation != null else null
		if juice != null and juice.get("rumble_log") != null:
			_rumble_log = juice.rumble_log
		if _census_game.player != null and _census_game.player.get("chain") != null:
			_chains = _census_game.player.chain.finished.duplicate()
		if _driver != null:
			_outcome = String(_driver.outcome)
	return over


func _finalize() -> void:
	if _done or _counts.is_empty():
		return
	_done = true
	var rumbles := {}
	for r in _rumble_log:
		var key := "%s %s" % [r[0], "sent" if r[4] else "held"]
		rumbles[key] = int(rumbles.get(key, 0)) + 1
	var seed := _seeds[0] if not _seeds.is_empty() else 0
	var f := FileAccess.open(_out.path_join("census-%d.json" % seed), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"seed": seed, "policy": String(_settings.get("policy", "")), "outcome": _outcome,
			"run_time": snappedf(_run_time, 0.01), "carve_seconds": snappedf(_carve_s, 0.01), "carves_started": _carves,
			"rumbles": rumbles, "chains": _chain_summary(), "timeline": _timeline, "events": _counts}, "\t"))
		f.close()


func _chain_summary() -> Dictionary:
	var paid_by_combo := {}
	var best := 0
	var unpaid := 0
	for c in _chains:
		var combo := int(c.get("combo", 0))
		best = maxi(best, combo)
		if c.get("paid", false):
			paid_by_combo[str(combo)] = int(paid_by_combo.get(str(combo), 0)) + 1
		else:
			unpaid += 1
	return {"total": _chains.size(), "best_combo": best, "unpaid": unpaid, "paid_by_combo": paid_by_combo}
