extends SceneTree

const Game := preload("res://src/game.gd")


const WARM := 1.25
const JUMP := 5.0

var _game
var _booted := false
var _ticks := 0
var _seconds := 4.0
var _speed := 40.0
var _interp := "default"
var _ball: Array[Vector3] = []
var _seen: Array[Vector3] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--interp="):
			_interp = arg.trim_prefix("--interp=")
		elif arg.begins_with("--speed="):
			_speed = float(arg.trim_prefix("--speed="))
		elif arg.begins_with("--seconds="):
			_seconds = float(arg.trim_prefix("--seconds="))
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_booted = true
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
		if _interp == "1":
			physics_interpolation = true
		elif _interp == "0":
			physics_interpolation = false
		return false
	if _game.player == null:
		return false
	_ticks += 1
	var velocity: Vector3 = _game.player.state.velocity
	_game.player.set_velocity_now(Vector3(_speed, velocity.y, 0.0), "probe")
	return false


func _process(_delta: float) -> bool:
	if not _booted or _game.player == null or _game.camera == null:
		return false
	if _ticks <= WARM * Engine.physics_ticks_per_second:
		return false
	var at: Vector3 = _game.player.shown_position()
	var lens: Transform3D = _game.camera.cam.global_transform
	_ball.append(at)
	_seen.append(lens.affine_inverse() * at)
	if _ticks <= (WARM + _seconds) * Engine.physics_ticks_per_second:
		return false
	print("JUDDER setup interp=%s tree_interpolation=%s fps=%d ticks=%d speed=%.1f frames=%d" % [
		_interp, physics_interpolation, Engine.max_fps if Engine.max_fps > 0 else roundi(1.0 / maxf(_delta, 0.0001)),
		Engine.physics_ticks_per_second, _speed, _ball.size()])
	var world := _steps(_ball)
	var scale := _mean(world)
	_report("ball_world_step_m", world, scale)
	_report("ball_from_lens_step_m", _steps(_seen), scale)
	quit(0)
	return true


func _steps(points: Array[Vector3]) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in range(1, points.size()):
		out.append(points[i].distance_to(points[i - 1]))
	return out


func _mean(steps: PackedFloat64Array) -> float:
	var total := 0.0
	var count := 0
	for step in steps:
		if step < JUMP:
			total += step
			count += 1
	return total / maxf(1.0, float(count))


func _report(label: String, steps: PackedFloat64Array, scale: float) -> void:
	var kept: Array[float] = []
	var jumps := 0
	var still := 0
	for step in steps:
		if step >= JUMP:
			jumps += 1
			continue
		kept.append(step)
		if step < 1e-6:
			still += 1
	kept.sort()
	var mean := _mean(steps)
	var spread := 0.0
	for step in kept:
		spread += (step - mean) * (step - mean)
	spread = sqrt(spread / maxf(1.0, float(kept.size())))
	print("JUDDER %s median=%.4f p95=%.4f max=%.4f spread=%.3f frozen_frames=%d of %d jumps=%d" % [
		label, kept[kept.size() / 2], kept[int(kept.size() * 0.95)], kept[-1],
		spread / maxf(scale, 1e-9), still, kept.size(), jumps])
