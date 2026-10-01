extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")

# Real rigid contacts, no strike() shortcut: a ball dropped onto a target stomps it
# with the speed it fell at, a ball rolling into one at cruise rams it with the speed
# it rolled at, and a slam onto one reports the slam. The contact must be read from
# the ball's motion before the solver bounced it.

const DROP := 6.0
const ROLL_SPEED := 12.0
const ROLL_GAP := 10.0
const TOLERANCE := 0.10
const WINDOW := 150
const SPOTS := {"stomp": Vector2(-100.0, -130.0), "ram": Vector2(-60.0, -150.0), "slam": Vector2(-20.0, -130.0)}

var _game
var _double
var _source := Intent.Scripted.new()
var _failures := 0
var _started := false
var _order := ["stomp", "ram", "slam"]
var _case := ""
var _ticks := 0
var _target: Node3D
var _results := {}
var _last_down := 0.0
var _last_planar := 0.0
var _first_tick := -1


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_double = SpawnerDouble.new()
		_game.add_child(_double)
		_double.setup(_game.ctx)
		_game.ctx.spawner = _double
		_game.ctx.calm = true
		_game.player.source = _source
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_next_case()
		return false
	_ticks += 1
	# The slam is a fresh Ctrl press in the air: a brake held across a reset stays a
	# brake (DESIGN-NOTES integration call 16).
	if _case == "slam" and _ticks == 2:
		_source.hold = {"brake_held": true}
	var v: Vector3 = _game.player.state.velocity
	if _double.strikes.is_empty():
		_last_down = maxf(0.0, -v.y)
		_last_planar = Vector2(v.x, v.z).length()
	elif _first_tick < 0:
		_first_tick = _ticks
	if _ticks >= WINDOW or (_first_tick >= 0 and _ticks - _first_tick >= 30):
		_results[_case] = {"strikes": _double.strikes.duplicate(true), "down": _last_down, "planar": _last_planar}
		if _order.is_empty():
			return _finish()
		_next_case()
	return false


func _next_case() -> void:
	_case = _order.pop_front()
	_ticks = 0
	_first_tick = -1
	_double.strikes.clear()
	if is_instance_valid(_target):
		_target.queue_free()
	var spot: Vector2 = SPOTS[_case]
	var ground: Vector3 = _game.ctx.terrain.drop_point(spot.x, spot.y, 0.0)
	_target = _double.spawn_enemy("chaser", ground)
	var top: float = ground.y + 3.0
	var start: Vector3
	var velocity := Vector3.ZERO
	_source.hold = {}
	match _case:
		"stomp":
			start = Vector3(spot.x, top + 1.0 + DROP, spot.y)
		"slam":
			start = Vector3(spot.x, top + 1.0 + DROP, spot.y)
		"ram":
			start = _game.ctx.terrain.drop_point(spot.x - ROLL_GAP, spot.y, 1.0)
			velocity = Vector3.RIGHT * ROLL_SPEED
			_game.camera.snap(Vector3.RIGHT)
			_source.hold = {"move": Vector2(0.0, 1.0)}
	_game.player.reset_to(start, velocity)
	_game.player.body().global_position = start


static func _kinds(strikes: Array) -> Array:
	return strikes.map(func(s): return s["kind"])


func _finish() -> bool:
	var stomp: Dictionary = _results["stomp"]
	var first: Dictionary = stomp["strikes"][0] if not stomp["strikes"].is_empty() else {}
	var stomps: Array = stomp["strikes"].filter(func(s): return s["kind"] == "stomp")
	var fell: float = stomp["down"]
	_report("physical stomp", stomps.size() == 1 and first.get("kind", "") == "stomp" and absf(first["force"] - fell) <= fell * TOLERANCE,
		"dropped %.0f m onto a target: strikes %s, stomp force %.2f against %.2f m/s of fall (within %d%%)"
			% [DROP, _kinds(stomp["strikes"]), first.get("force", -1.0), fell, int(TOLERANCE * 100.0)])
	var ram: Dictionary = _results["ram"]
	var hit: Dictionary = ram["strikes"][0] if not ram["strikes"].is_empty() else {}
	var rolled: float = ram["planar"]
	_report("physical ram", hit.get("kind", "") == "ram" and absf(hit["force"] - rolled) <= rolled * TOLERANCE,
		"rolled into a target at cruise: strikes %s, ram force %.2f against %.2f m/s of planar speed"
			% [_kinds(ram["strikes"]), hit.get("force", -1.0), rolled])
	var slam: Dictionary = _results["slam"]
	_report("physical slam", "slam" in _kinds(slam["strikes"]),
		"slammed onto a target: strikes %s" % [_kinds(slam["strikes"])])
	print("spine_stomp_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
