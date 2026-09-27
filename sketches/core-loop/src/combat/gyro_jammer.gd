extends "res://src/combat/counter.gd"

# The gyro jammer (DESIGN-V2 section 15.4): a crew figure hunched under a tall aerial.
# It throws your gyroscope off. The warning is an instant ring laid over the ball;
# live, a ball inside the field is held in a drift: a sideways push across its line,
# swinging left and right at DRIFT_HZ, so the steering wanders while the screen and the
# camera stay exactly where they are (never nauseating). It never slows you; it steals
# your line. Rolling out of the field ends it, and a jump, a boost or a smash breaks it.

const FIELD_RADIUS := 7.0
const DRIFT := 11.0
const DRIFT_HZ := 0.7
const HP := 40.0

var _aerial: MeshInstance3D
var _phase0 := 0.0


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = 1.0
	live_seconds = 3.0
	rest_seconds = 3.8
	attack_range = 20.0


func _build_tool() -> void:
	_aerial = _cylinder(0.07, 3.4, Palette.CHARCOAL, Vector3(0.0, CREW_HALF + 1.5, -0.2))
	for i in 3:
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.45 - i * 0.1
		hoop.outer_radius = 0.55 - i * 0.1
		_accent(hoop, Palette.HAZARD, 0.8, Vector3(0.0, 0.6 + i * 0.5, 0.0), _aerial)


func _commit(_to_ball: Vector3) -> Node3D:
	return _commit_ring(Threat.Type.INSTANT, _ball(), FIELD_RADIUS, 4.0)


func _go_live() -> void:
	_phase0 = float(get_instance_id() % 628) * 0.01


func _live(_delta: float) -> bool:
	var field := telegraph()
	if field == null:
		return false
	var player = _player()
	if not field.contains(_real_ball()):
		if _holding():
			_release("left")
		return true
	if not _holding() and not _catch():
		return true
	var v: Vector3 = player.planar_velocity()
	var across := v.cross(Vector3.UP).normalized() if v.length() > 1.0 else Vector3.RIGHT
	_pull(across * DRIFT * sin(_phase0 + _t * TAU * DRIFT_HZ))
	return true


func _pose() -> void:
	if _aerial != null:
		_aerial.rotation.y += 0.3 if phase == Phase.LIVE else 0.05
