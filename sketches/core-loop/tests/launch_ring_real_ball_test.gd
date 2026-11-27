extends SceneTree

const Game := preload("res://src/game.gd")
const Launch := preload("res://src/world/launch.gd")

# The guide rings sit where the real ball goes. A launch is fired through the real world and the real rigid ball
# at a 5 m/s entry, straight and turned. The ball's place is read at the start of every physics tick, which is
# after as many steps as ticks have passed since the launch, and the distance to each ring's centre is taken at
# the ring's own time (linearly between the two ticks around it).

const ENTRY := 5.0
const NEAR := 0.1
const SETTLE := 5
const TICK_LIMIT := 90 * 60

var _game
var _started := false
var _in_stage := false
var _settle := 0
var _failures := 0
var _case := 0
var _cases := [
	{"label": "5 m/s entry, straight", "heading": Vector3.ZERO},
	{"label": "5 m/s entry, turned", "heading": Vector3(0.6, 0.0, -0.8)},
]
var _firing := false
var _rings: Array = []
var _samples: Array[Vector3] = []
var _times: Array[float] = []
var _ticks := 0
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	_ticks += 1
	if _ticks > TICK_LIMIT:
		_fail("timed out before the launches finished")
		return _finish()
	if not _started:
		if _game.flow == null:
			return false
		_started = true
		_game.events.stage_entered.connect(func(_stage: int, _retry: bool): _in_stage = true)
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if not _in_stage:
		return false
	if _firing:
		return _sample()
	_settle += 1
	if _settle == 1:
		var start: Vector3 = _game.player.ball_position()
		var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
		_game.player.reset_to(at, _game.ctx.heading() * ENTRY)
	elif _settle >= SETTLE:
		_fire()
	return false


func _fire() -> void:
	var player = _game.player
	var launch = _game.world.launch
	var facing: Vector3 = _game.ctx.heading()
	player.set_velocity_now(facing * ENTRY)
	launch.aim(_cases[_case]["heading"], _game.camera)
	_game.world._on_reward_chosen("")
	_rings = launch.ring_nodes()
	_samples = [player.ball_position()]
	_times = [0.0]
	_firing = true


func _sample() -> bool:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	_samples.append(_game.player.ball_position())
	_times.append(_samples.size() * dt - dt)
	var last_ring := Launch.RING_FIRST + (Launch.RINGS - 1) * Launch.RING_STEP
	if _times[-1] < last_ring + dt:
		return false
	_report_case(_cases[_case]["label"])
	_game.world.launch.stop()
	_firing = false
	_case += 1
	_settle = 0
	if _case >= _cases.size():
		return _finish()
	return false


func _report_case(label: String) -> void:
	if _rings.size() != Launch.RINGS:
		_fail("%s: want %d rings, got %d" % [label, Launch.RINGS, _rings.size()])
		return
	if not _game.world.launch._turn == 0.0 and _cases[_case]["heading"] == Vector3.ZERO:
		_fail("%s: the launch turned" % label)
	if _cases[_case]["heading"] != Vector3.ZERO and _game.world.launch._turn == 0.0:
		_fail("%s: the launch did not turn" % label)
	print("%s (turn %.3f rad)" % [label, _game.world.launch._turn])
	var worst := 0.0
	for i in Launch.RINGS:
		var t := Launch.RING_FIRST + i * Launch.RING_STEP
		var k := 0
		while k + 1 < _times.size() - 1 and _times[k + 1] < t:
			k += 1
		var span: float = _times[k + 1] - _times[k]
		var here := _samples[k].lerp(_samples[k + 1], (t - _times[k]) / span)
		var gap := here.distance_to(_rings[i].position)
		worst = maxf(worst, gap)
		print("  ring %d  time %.3f s  ball to ring %.3f m" % [i, t, gap])
		if gap > NEAR:
			_fail("%s: ring %d is %.3f m from the real ball at its time" % [label, i, gap])
	print("  worst %.3f m (bound %.3f m)" % [worst, NEAR])


func _finish() -> bool:
	_done = true
	print("launch_ring_real_ball_test: %s" % ("FAIL" if _failures > 0 else "PASS"))
	_game.free()
	quit(1 if _failures > 0 else 0)
	return true


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
	print("FAIL ", message)
