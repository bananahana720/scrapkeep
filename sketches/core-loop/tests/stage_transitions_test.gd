extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Gorge := preload("res://src/world/map_gorge.gd")

# No momentum trap across the gorge (DESIGN-V2 section 8; I3 test 2). Each of the five
# transitions between heights, and each launcher, is ridden on the real map with the
# real ball: planar speed a moment after it lands must be at least 85% of the speed it
# went in with (a gain is a gift), and a second later it must still be rolling. The
# steam lift is held to its job: a ball on the plate when it fires goes up to the shelf.
#
# Evidence limit: calm, one line per transition, no enemies; feel is Andrew's.

const TOLERANCE := 0.15
const SETTLE := 0.3
const STILL_ROLLING := 3.0
const SIM_SCALE := 2.0
const LIMIT := 14.0

# 2026-10-04: the authored gorge route remains on a test double after the alpha repoint.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _source := Intent.Scripted.new()
var _cases: Array = []
var _case := {}
var _phase := "boot"
var _clock := 0.0
var _facts: Array = []


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _build_cases() -> void:
	var marble := []
	for p in Gorge.MARBLE:
		marble.append(p)
	_cases = [
		{"name": "glide drop off the rim", "at": Vector2(0.0, -114.0), "v": Vector3(0.0, 0.0, 18.0), "until": "undercroft", "ride": "ride_glide_drop"},
		{"name": "grapple line to the east shelf", "at": Vector2(44.0, -114.0), "v": Vector3(0.0, 0.0, 14.0), "until": "rail", "ride": "ride_grapple_line"},
		{"name": "skylight halfpipe to the undercroft", "at": Vector2(Gorge.SKYLIGHT_X, 30.0), "v": Vector3(0.0, 0.0, 16.0), "until": "undercroft",
			"open": "skylight_valve", "ride": "ride_skylight"},
		{"name": "geyser up to the crown dish", "at": Vector2(-22.0, 14.0), "v": Vector3(0.0, 0.0, 14.0), "until": "rail", "ride": "geyser_fired"},
		{"name": "marble-run chutes to the cannon", "at": marble[0], "v": _toward(marble[0], marble[1]) * 12.0, "until": "fact",
			"fact": "cannon_fired", "steer": marble.slice(1), "ride": "cannon_fired"},
		{"name": "cannon across the gorge", "at": Vector2(-72.0, -38.0), "v": _toward(Vector2(-72.0, -38.0), Gorge.MARBLE[-1]) * 16.0,
			"until": "rail", "ride": "cannon_fired"},
		{"name": "trebuchet up to the crown dish", "at": Vector2(96.0, 30.0), "v": Vector3(0.0, 0.0, 14.0), "until": "rail", "ride": "trebuchet_fired"},
	]


static func _toward(a: Vector2, b: Vector2) -> Vector3:
	var d := (b - a).normalized()
	return Vector3(d.x, 0.0, d.y)


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	var player = _game.player
	match _phase:
		"boot":
			_game.ctx.calm = true
			player.source = _source
			_game.events.world_fact.connect(func(kind: String, _at: Vector3): _facts.append(kind))
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "enter"
		"enter":
			_game.flow.enter_stage(2, Vector3.ZERO, false)
			_build_cases()
			_phase = "next"
			Engine.time_scale = SIM_SCALE
		"next":
			if _cases.is_empty():
				return _lift()
			_case = _cases.pop_front()
			_facts.clear()
			if _case.has("open"):
				for v in _game.world.contraptions[2].valves:
					if v["spec"]["id"] == _case["open"]:
						v["open"] = true
			for l in _game.world.contraptions[2].launchers:
				l["cycle"].phase = l["cycle"].READY
			var xz: Vector2 = _case["at"]
			var at: Vector3 = _game.ctx.terrain.drop_point(xz.x, xz.y, 1.05)
			player.reset_to(at, _case["v"])
			player.body().global_position = at
			_game.world.ride = null
			_case["before"] = (_case["v"] as Vector3).length()
			_case["pre"] = _case["before"]
			_case["stage"] = "go"
			_source.hold = {}
			_clock = 0.0
			_phase = "run"
		"run":
			_clock += delta
			_step_case()
	return false


func _step_case() -> void:
	var player = _game.player
	var ball: Vector3 = player.ball_position()
	var planar: float = player.planar_velocity().length()
	if _case.has("steer") and _case["stage"] == "go":
		var path: Array = _case["steer"]
		while not path.is_empty() and Vector2(ball.x, ball.z).distance_to(path[0]) < 6.0:
			path.pop_front()
		if not path.is_empty():
			_steer(Vector3(path[0].x, 0.0, path[0].y))
	match _case["stage"]:
		"go":
			if _game.world.ride == null:
				_case["pre"] = planar
			var arrived := false
			match _case["until"]:
				"undercroft":
					arrived = player.state.grounded and _game.ctx.terrain.layer_at(ball) == "undercroft" and _clock > 0.3
				"rail":
					arrived = _case.get("rode", false) and _game.world.ride == null and player.state.grounded
					if _game.world.ride != null:
						_case["rode"] = true
				"fact":
					arrived = _facts.has(_case["fact"])
			if arrived:
				_source.hold = {}
				_case["stage"] = "settle"
				_case["t"] = _clock
				_case["from"] = _case["pre"] if _case["until"] == "fact" else _case["before"]
		"settle":
			if _clock - _case["t"] >= SETTLE and _case["until"] != "fact":
				_case["after"] = planar
				_case["stage"] = "rolling"
			elif _case["until"] == "fact":
				_case["after"] = _case["pre"]
				_case["from"] = _case["before"]
				_case["stage"] = "rolling"
		"rolling":
			if _clock - _case["t"] >= SETTLE + 1.0:
				var from: float = _case["from"]
				var after: float = _case["after"]
				var ride_heard: bool = _facts.has(_case["ride"])
				_report(_case["name"], after >= from * (1.0 - TOLERANCE) and planar >= STILL_ROLLING and ride_heard,
					"in at %.1f m/s, %.1f m/s after, still rolling at %.1f m/s a second on; now at %s in the %s; heard %s: %s"
						% [from, after, planar, _v(ball), _game.ctx.terrain.layer_at(ball), _case["ride"], ride_heard])
				_phase = "next"
	if _clock > LIMIT and _phase == "run":
		_report(_case["name"], false, "stalled in stage %s at %s after %.1f s; facts %s" % [_case["stage"], _v(ball), _clock, _facts])
		_phase = "next"


func _steer(target: Vector3) -> void:
	var player = _game.player
	var ball: Vector3 = player.ball_position()
	var dir := Vector3(target.x - ball.x, 0.0, target.z - ball.z).normalized()
	_game.camera.yaw = atan2(-dir.x, -dir.z)
	var v: Vector3 = player.planar_velocity()
	var change := dir * maxf(v.length(), 12.0) - v
	var want := dir if change.length() < 0.5 else change.normalized()
	var yaw: float = _game.camera.yaw
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	_source.hold = {"move": Vector2(want.dot(right), want.dot(forward)).normalized()}


# The west lift: a ball resting on the plate a moment before it fires is thrown up to
# shelf height.
var _lift_start := INF
var _lift_top := -INF


func _lift() -> bool:
	var lift: Dictionary = _game.world.contraptions[2].lifts[0]
	var player = _game.player
	if _lift_start == INF:
		lift["cycle"].phase = lift["cycle"].CHARGING
		lift["cycle"].t = lift["cycle"].charge - 0.4
		var top: Vector3 = (lift["body"] as Node3D).global_position + Vector3.UP * 1.6
		player.reset_to(top, Vector3(0.0, 0.0, 0.0))
		player.body().global_position = top
		_lift_start = top.y
		_clock = 0.0
		return false
	_clock += 1.0 / 90.0 * SIM_SCALE
	_lift_top = maxf(_lift_top, player.ball_position().y)
	if _clock < 2.5:
		return false
	var shelf := Gorge.flank(-56.0)
	_report("the steam lift throws the ball to the shelf", _lift_top - _lift_start >= 10.0 and _lift_top >= shelf - 3.0 and _facts.has("lift_fired"),
		"resting on the plate at %.1f m when it fired, the ball rose to %.1f m (shelf %.1f m); lift_fired %s"
			% [_lift_start, _lift_top, shelf, _facts.has("lift_fired")])
	Engine.time_scale = 1.0
	print("stage_transitions_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


static func _v(p: Vector3) -> String:
	return "(%.0f, %.1f, %.0f)" % [p.x, p.y, p.z]
