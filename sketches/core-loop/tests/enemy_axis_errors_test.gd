extends SceneTree

# PR 995's rendered sitting run logged 3,276 "The axis ... must be normalized" engine errors from
# the crews' model motion (board #934, 14 Nov 2026), each about 10 to 18 us of error printing:
#   - a landed death piece's spin was skidded every tick toward 1e-22, where normalized() is no
#     longer unit, so Basis.rotated refused it (enemy_motion.gd);
#   - the gait followed the ground normal by slerp, whose axis is the cross of two nearly equal
#     normals and normalises off unit length (enemy_gait.gd).
# Both run here with the gait on headless, and no engine error may be logged.
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const EnemyGait := preload("res://src/presentation/enemy_gait.gd")
const T := preload("res://tests/support/t.gd")


class ErrorLog:
	extends Logger
	var axis := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			rationale: String, _editor_notify: bool, _error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if "must be normalized" in rationale:
			axis += 1


var _t := T.new("enemy_axis_errors_test")
var _log := ErrorLog.new()


func _initialize() -> void:
	OS.add_logger(_log)
	_run.call_deferred()


func _run() -> void:
	EnemyMotion.headless_idle = true
	_settled_ground()
	await _resting_pieces()
	EnemyMotion.headless_idle = false
	OS.remove_logger(_log)
	quit(_t.verdict())


# A crew steps off a slope onto the flat and stands: its followed normal closes on UP until the
# slope's last trace is a few 1e-20, where slerp's axis no longer normalises.
func _settled_ground() -> void:
	var body := Node3D.new()
	root.add_child(body)
	var gait := EnemyGait.new()
	var slope := Vector3(0.3, 0.9, 0.2).normalized()
	var unit := true
	var before := _log.axis
	for i in 3000:
		var under := slope if i < 60 else Vector3.UP
		gait.step(1.0 / 60.0, body, Vector3.ZERO, 0.6, true, under, 0.5)
		unit = unit and gait._ground.is_normalized()
	_t.eq("a crew settling on the flat logs no axis error", _log.axis - before, 0)
	_t.check("the followed ground stays a unit normal and reaches the flat", unit and gait._ground.is_equal_approx(Vector3.UP), str(gait._ground))
	body.free()


# A death's pieces land on flat ground and rest there until the scatter ends.
func _resting_pieces() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var body := Node3D.new()
	holder.add_child(body)
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var before := _log.axis
	var made = EnemyMotion.scatter(body, "hooker", Vector3.FORWARD, flat)
	_t.check("a walking crew's death lands", made != null and made.ground.is_valid())
	if made == null:
		holder.free()
		return
	var ref: WeakRef = weakref(made)
	var spins := []
	var ticks := 0
	while ref.get_ref() != null and ticks < 600:
		await physics_frame
		ticks += 1
		var live = ref.get_ref()
		if live != null:
			for piece in live._pieces:
				spins.append((piece.spin as Vector3).length())
	_t.eq("resting death pieces log no axis error", _log.axis - before, 0)
	var creeping := spins.filter(func(s: float): return s > 0.0 and s < EnemyMotion.SPIN_STILL)
	_t.check("a resting piece's spin stops instead of shrinking forever", creeping.is_empty() and spins.has(0.0),
		"%d creeping of %d samples" % [creeping.size(), spins.size()])
	holder.free()
