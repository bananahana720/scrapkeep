# smoke: solo (isolated fixed-90-fps children; 100 s wall budget)
extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Dig := preload("res://src/world/map_dig.gd")
const T := preload("res://tests/support/t.gd")

class DigGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/dig_table_defs.gd")

var _t := T.new("bot_dig_breach_test")
var _game
var _driver
var _case := ""
var _seed := 1
var _seconds := 0.0
var _started := 0
var _done := false
var _target := Vector3.ZERO


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			_case = arg.trim_prefix("--case=")
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
	if _case.is_empty():
		var started := _wall_msec()
		var jobs := []
		for n in [1, 2, 3]:
			jobs.append({"script": "res://tests/bot_dig_breach_test.gd", "args": ["--case=spawn", "--seed=%d" % n]})
		for name in ["plate", "same-tier"]:
			jobs.append({"script": "res://tests/bot_dig_breach_test.gd", "args": ["--case=" + name]})
		var results := ChildRuns.run(jobs, 100.0)
		for i in results.size():
			var result: Dictionary = results[i]
			print(result["log"])
			_t.check("isolated case %s" % [jobs[i]["args"]], result["code"] == 0 and not result["timed_out"]
				and ChildRuns.summary(result)["errors"].is_empty())
		print("bot_dig_breach_test wall: %.3f s" % ((_wall_msec() - started) / 1000.0))
		_done = true
		quit(_t.verdict())
		return
	SimClock.ticks = true
	seed(_seed)
	_started = _wall_msec()
	_game = DigGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", _seed)
		_driver.class_index = 0
		_driver.start()
		if _case != "spawn":
			var centre: Vector2 = Dig.BREACH_PLATES[0]["rect"].get_center()
			_game.player.reset_to(Vector3(centre.x, Dig.UPPER_H + 1.0, centre.y))
			_target = _game.flow.warden.global_position if _case == "plate" else Vector3(centre.x, Dig.UPPER_H + 1.0, centre.y + 20.0)
		return false
	_seconds += delta
	var over := false
	if _case == "spawn":
		over = _driver.tick(delta)
	else:
		# Controlled steering target; the real ball and slam input must break the floor.
		_driver._act(_target, null, delta, null, false)
	var reached: bool = _driver._note.get("warden_fight_s") != null
	var breached: bool = _game.world.breach.breached("plate_east")
	var below: bool = _game.player.ball_position().y < 6.0
	if (_case == "spawn" and (reached or over or _seconds >= 150.0)) or (_case != "spawn" and _seconds >= 20.0) \
			or (_case == "plate" and breached and below):
		_done = true
		_t.check("bot driven", _game.bot_driven)
		if _case == "spawn":
			_t.check("seed %d reaches warden_fight_s within 150 simulated seconds" % _seed, reached and _seconds <= 150.0,
				"warden_fight_s %s" % _driver._note.get("warden_fight_s"))
		elif _case == "plate":
			_t.check("plate_east breached by slam", breached and _driver._note["plate_slams"] >= 1,
				"slams %s" % _driver._note["plate_slams"])
			_t.check("ball drops below 6 m", below, "y %.3f" % _game.player.ball_position().y)
		else:
			_t.check("same tier leaves every plate intact", _game.world.breach.broken.is_empty(), str(_game.world.breach.broken))
			_t.eq("same tier has no plate slams", _driver._note["plate_slams"], 0)
		print("Dig %s seed %d: simulated %.3f s, wall %.3f s" % [_case, _seed, _seconds, (_wall_msec() - _started) / 1000.0])
		_game.free()
		quit(_t.verdict())
	return false


# Wall time is receipt data only; case budgets always use physics delta.
func _wall_msec() -> int:
	var ticking := SimClock.ticks
	SimClock.ticks = false
	var now := SimClock.msec()
	SimClock.ticks = ticking
	return now
