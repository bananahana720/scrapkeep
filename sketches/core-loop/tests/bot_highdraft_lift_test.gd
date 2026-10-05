# smoke: solo (isolated fixed-90-fps children; 100 s wall budget)
extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")

class HighdraftGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/highdraft_table_defs.gd")

var _t := T.new("bot_highdraft_lift_test")
var _game
var _driver
var _pilot := ""
var _seconds := 0.0
var _facts := 0
var _minimum := INF
var _maximum := -INF
var _ride_gain := false
var _previous_height := INF
var _ride_start_height := INF
var _ride_peak_height := -INF
var _started := 0
var _done := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pilot="):
			_pilot = arg.trim_prefix("--pilot=")
	if _pilot.is_empty():
		var started := _wall_msec()
		var results := ChildRuns.run([
			{"script": "res://tests/bot_highdraft_lift_test.gd", "args": ["--pilot=Kest"]},
			{"script": "res://tests/bot_highdraft_lift_test.gd", "args": ["--pilot=Sable"]}], 100.0)
		for i in results.size():
			var result: Dictionary = results[i]
			print(result["log"])
			_t.check("isolated pilot %d" % i, result["code"] == 0 and not result["timed_out"]
				and ChildRuns.summary(result)["errors"].is_empty())
		print("bot_highdraft_lift_test wall: %.3f s" % ((_wall_msec() - started) / 1000.0))
		_done = true
		quit(_t.verdict())
		return
	SimClock.ticks = true
	seed(1)
	_started = _wall_msec()
	_game = HighdraftGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", 1)
		for i in ClassDef.all().size():
			if ClassDef.all()[i].display_name == _pilot:
				_driver.class_index = i
		_driver.start()
		_game.ctx.calm = true
		_game.run.set_max_hp(99999.0)
		_t.eq("glide capability follows smoke_blink", _game.player.kit.on("glide"), _pilot == "Kest")
		_game.events.world_fact.connect(func(fact: String, at: Vector3):
			if fact == "thermal_ride":
				_facts += 1
				if _ride_start_height == INF:
					_ride_start_height = at.y)
		_game.player.reset_to(Vector3(Highdraft.THERMAL_A.x, Highdraft.NET_H + 1.0, Highdraft.THERMAL_A.y))
		return false
	_seconds += delta
	var height: float = _game.player.ball_position().y
	_minimum = minf(_minimum, height)
	_maximum = maxf(_maximum, height)
	if _game.player.kit.gliding and height > _previous_height:
		_ride_gain = true
	_previous_height = height
	if _facts > 0 and Vector2(_game.player.ball_position().x, _game.player.ball_position().z).distance_to(Highdraft.THERMAL_A) <= 5.0:
		_ride_peak_height = maxf(_ride_peak_height, height)
	_driver._act(_game.flow.beacon.global_position, null, delta, null, false)
	if _seconds >= 30.0:
		_done = true
		_t.check("bot driven", _game.bot_driven)
		if _pilot == "Kest":
			_t.check("thermal_ride world fact within 30 s", _facts > 0, str(_facts))
			_t.check("thermal_rides stage note", _driver._note["thermal_rides"] >= 1, str(_driver._note["thermal_rides"]))
		else:
			_t.eq("Sable has zero thermal rides", _driver._note["thermal_rides"], 0)
			_t.eq("Sable has zero thermal facts", _facts, 0)
		_t.check("ball stays above net minus 1 m", _minimum >= Highdraft.NET_H - 1.0, "min %.3f" % _minimum)
		print("Highdraft %s: simulated %.3f s, wall %.3f s, height %.3f..%.3f, upward gliding tick %s" % [
			_pilot, _seconds, (_wall_msec() - _started) / 1000.0, _minimum, _maximum, _ride_gain])
		if _facts > 0:
			print("Thermal observation: start %.3f, peak %.3f, net gain %.3f m" % [_ride_start_height, _ride_peak_height, _ride_peak_height - _ride_start_height])
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
