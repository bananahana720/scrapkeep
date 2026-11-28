extends RefCounted

const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const Comfort := preload("res://src/core/comfort.gd")


const TURN_RATE := 6.0
const CATCH := 0.04
const WALK_REF := 3.8
const LEAN_TRAVEL := 0.07
const LEAN_LAG := 0.09
const LEAN_MAX := 0.16
const SPEED_FOLLOW := 6.0
const TILT_FOLLOW := 14.0
const SETTLED := 0.002
const STEP_LENGTH := 0.7
const STEP_LIFT := 0.06
const STEP_ROLL := 0.08
const GROUND_FOLLOW := 12.0
const GROUND_MAX := 0.6
const GLANCE := 0.6
const HOP_LIFT := 0.14
const HOP := 0.3

var steps := true
var tilt := Transform3D.IDENTITY
var turn := Transform3D.IDENTITY

var _yaw := 0.0
var _aim := NAN
var _catching := false
var _root_yaw := NAN
var _felt := Vector3.ZERO
var _tilt := Vector3.ZERO
var _travel := 0.0
var _step_mix := 0.0
var _glance := 0.0
var _glance_left := 0.0
var _hop_age := -1.0
var _ground := Vector3.UP


func aim(yaw: float) -> void:
	_aim = yaw
	_catching = false


func glance(yaw: float) -> void:
	_glance = yaw
	_glance_left = GLANCE


func hop() -> void:
	_hop_age = 0.0


func hold() -> void:
	_aim = NAN
	_glance_left = 0.0


func committed() -> void:
	_catching = true
	_aim = NAN


func step(delta: float, body: Node3D, velocity: Vector3, foot: float, walking := true, ground := Vector3.UP, girth := 0.0) -> void:
	tilt = Transform3D.IDENTITY
	turn = Transform3D.IDENTITY
	if not EnemyMotion.active() or delta <= 0.0:
		_aim = NAN
		return
	var root_yaw := body.global_basis.get_euler().y
	if not is_nan(_root_yaw):
		_yaw = wrapf(_yaw - angle_difference(_root_yaw, root_yaw), -PI, PI)
	_root_yaw = root_yaw
	_glance_left = maxf(0.0, _glance_left - delta)
	if _glance_left > 0.0 and not _catching:
		_aim = _glance
	if not is_nan(_aim):
		var want := angle_difference(root_yaw, _aim)
		_yaw += clampf(angle_difference(_yaw, want), -TURN_RATE * delta, TURN_RATE * delta)
	elif _catching:
		_yaw *= exp(-delta / CATCH)
		if absf(_yaw) < 0.001:
			_yaw = 0.0
	_aim = NAN
	var spin := Basis(Vector3.UP, _yaw)
	var scale := Comfort.motion_scale()
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	_felt = _felt.lerp(planar, 1.0 - exp(-SPEED_FOLLOW * delta))
	var goal := (_felt * LEAN_TRAVEL - (planar - _felt) * LEAN_LAG) / WALK_REF
	goal = goal.limit_length(LEAN_MAX)
	_tilt = _tilt.lerp(goal, 1.0 - exp(-TILT_FOLLOW * delta))
	if goal.length() < SETTLED and _tilt.length() < SETTLED:
		_tilt = Vector3.ZERO
		_felt = planar
	var speed := planar.length()
	_step_mix = move_toward(_step_mix, clampf(speed / WALK_REF, 0.0, 1.0) if steps and walking else 0.0, delta * 6.0)
	if walking:
		_travel = fmod(_travel + speed * delta, STEP_LENGTH * 2.0)
	var phase := PI * _travel / STEP_LENGTH
	var lift := STEP_LIFT * absf(sin(phase)) * _step_mix * scale
	if _hop_age >= 0.0:
		lift += HOP_LIFT * sin(PI * _hop_age / HOP) * scale
		_hop_age += delta
		if _hop_age >= HOP:
			_hop_age = -1.0
	var roll := STEP_ROLL * sin(phase) * _step_mix * scale
	turn = Transform3D(spin * Basis(Vector3.BACK, roll), Vector3(0.0, lift, 0.0))
	var pivot := Vector3(0.0, -foot, 0.0)
	var lay := Basis.IDENTITY
	var sink := 0.0
	if ground.length_squared() > 0.0:
		var followed := _ground.lerp(ground.normalized(), 1.0 - exp(-GROUND_FOLLOW * delta))
		_ground = followed.normalized() if followed.length_squared() > 0.000001 else ground.normalized()
	var slope := minf(_ground.angle_to(Vector3.UP), GROUND_MAX)
	if slope > 0.001:
		var up := body.global_basis.inverse() * _ground
		lay = Basis(Vector3.UP.cross(up).normalized(), slope)
		sink = girth * (1.0 / cos(slope) - 1.0)
	var angle := _tilt.length() * scale
	var lean := Basis.IDENTITY
	if angle > 0.0001:
		var local := body.global_basis.inverse() * _tilt
		lean = Basis(Vector3.UP.cross(local).normalized(), angle)
	if slope > 0.001 or angle > 0.0001:
		tilt = Transform3D(Basis.IDENTITY, pivot + Vector3.DOWN * sink) * Transform3D(lay * lean, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)


func yaw() -> float:
	return _yaw
