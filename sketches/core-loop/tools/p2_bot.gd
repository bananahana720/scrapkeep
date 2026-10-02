extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Map := preload("res://src/world/map_highdraft_probe.gd")

# Unit P2 (throwaway): the stock traversal bot on the Highdraft probe, island one to three.
#   godot --headless --fixed-fps 90 --path sketches/core-loop --script res://tools/p2_bot.gd -- [--seeds=1,2,3,4] [--swing=0|1]
# --swing=0 is the bot as it is. --swing=1 adds a hand on top of the bot's steering: when the
# ball is in the air with the next post inside the fire distance it aims the camera at the post,
# fires, holds Ctrl (the winch) and lets go once it is over the island, with the fire and
# release distances found by tools/p2_probe.gd. The bot's own stick, reaction delay and
# press gate are untouched. A seed reaches island two or three when the ball is grounded on it.
const SECONDS := 100.0
const ROUTE := [Vector2(2.0, -80.0), Vector2(14.0, -36.0), Vector2(0.0, 8.0), Vector2(-6.0, 22.0)]
# post target per island index: [fire distance, release distance]
const HAND := {1: [34.0, 18.0], 2: [28.0, 24.0]}

var _seeds: Array[int] = []
var _swing := false
var _index := -1
var _game
var _driver
var _ticks := 0
var _reached := {}
var _hooked_for := 0
var _results := []


func _initialize() -> void:
	SimClock.ticks = true
	var seeds := "1,2,3,4"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = a.trim_prefix("--seeds=")
		if a.begins_with("--swing="):
			_swing = a.trim_prefix("--swing=") == "1"
	for part in seeds.split(","):
		_seeds.append(int(part))
	_next()


func _next() -> void:
	_index += 1
	if _index >= _seeds.size():
		var ok := 0
		for r in _results:
			if r["reached_i3"]:
				ok += 1
		print("P2-5 swing=%s seeds=%d crossed_i1_to_i3=%d/%d" % [_swing, _results.size(), ok, _results.size()])
		quit(0)
		return
	seed(_seeds[_index])
	_game = Game.new()
	_game.test_mode = true
	_game.table = "probe_highdraft"
	root.add_child(_game)
	_driver = null
	_ticks = 0
	_reached = {}


func _on_island(b: Vector3) -> int:
	for i in 3:
		var c: Vector2 = Map.ISLANDS[i]["at"]
		if Vector2(b.x, b.z).distance_to(c) <= 12.0 and absf(b.y - float(Map.ISLANDS[i]["top"])) < 2.0:
			return i
	return -1


func _physics_process(delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "traversal", _seeds[_index])
		_driver.class_index = 0
		var r: Array[Vector2] = []
		for p in ROUTE:
			r.append(p)
		_driver.route = r
		_driver.start()
		return false
	var over: bool = _driver.tick(delta)
	_ticks += 1
	var player = _game.player
	var b: Vector3 = player.ball_position()
	if _swing:
		_hand(player, b)
	var isl := _on_island(b)
	if isl >= 0 and player.state.grounded and not _reached.has(isl):
		_reached[isl] = float(_ticks) / 90.0
	var done: bool = _reached.has(2) or float(_ticks) / 90.0 > SECONDS or over
	if not done:
		return false
	var res := {"seed": _seeds[_index], "reached_i2": _reached.has(1), "reached_i3": _reached.has(2), "t_i2": _reached.get(1, -1.0), "t_i3": _reached.get(2, -1.0),
		"end": b, "seconds": float(_ticks) / 90.0, "outcome": _driver.outcome}
	_results.append(res)
	print("P2-5 swing=%s seed %d: reached_i2=%s (%.1f s) reached_i3=%s (%.1f s) end=(%.1f, %.1f, %.1f) outcome=%s" % [_swing, res["seed"], res["reached_i2"], res["t_i2"], res["reached_i3"], res["t_i3"], b.x, b.y, b.z, res["outcome"]])
	_game.free()
	_game = null
	_next()
	return false


func _hand(player, b: Vector3) -> void:
	var kit = player.kit
	var src = _driver.source
	var cur := -1
	for i in [2, 1]:
		if not _reached.has(i):
			cur = i
	# the next post: island index 1 until island two is reached, then island three
	var target := 1 if not _reached.has(1) else 2
	if _reached.has(2):
		return
	var isl: Dictionary = Map.ISLANDS[target]
	var c: Vector2 = isl["at"]
	var pdata: Dictionary = (isl["posts"] as Array)[0]
	var pa: Vector2 = c + (pdata["at"] as Vector2)
	var post := Vector3(pa.x, float(isl["top"]) + float(pdata["height"]), pa.y)
	var flat := Vector2(post.x - b.x, post.z - b.z).length()
	var fire_d: float = HAND[target][0]
	var rel_d: float = HAND[target][1]
	var cam = _game.camera
	if kit.hooked:
		var d: Vector3 = post - cam.global_position
		cam.yaw = atan2(-d.x, -d.z)
		cam.pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.25, 0.55)
		src.hold["harpoon_held"] = true
		src.hold["brake_held"] = true
		if flat <= rel_d and b.y >= float(isl["top"]) + 0.5:
			src.press["harpoon_released"] = true
			src.hold.erase("harpoon_held")
			src.hold.erase("brake_held")
		return
	if not player.state.grounded and flat <= fire_d and flat > 8.0 and b.y > float(isl["top"]) - 12.0 and _hooked_for == 0:
		var d2: Vector3 = post - cam.global_position
		cam.yaw = atan2(-d2.x, -d2.z)
		cam.pitch = clampf(atan2(d2.y, Vector2(d2.x, d2.z).length()), -1.25, 0.55)
		src.press["harpoon_pressed"] = true
		src.hold["harpoon_held"] = true
