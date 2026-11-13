extends RefCounted

const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

# A walking crew's body language between attacks, on its model's pivot only: it turns to
# watch where it means to strike, leans with its own weight when it starts and stops, and
# steps instead of sliding. Before this the body snapped to face the ball on the commit
# frame, stood frozen at that old heading while it circled, and glided at full speed from
# a standstill with no step, which read as a prop on a rail rather than a crew.
#
# Presentation only. The body's yaw, velocity, colliders, hit spheres and telegraphs are the
# kind's own and never read this. While an attack is open the model carries no turn of its
# own: a kind that faces at its commit closes the gap in CATCH seconds (the wind-up lead is
# longer), and a kind that does not face holds the heading it had. Off in headless runs like
# the idle, so tests and bots see the exact body; reduced motion keeps the turn and drops the
# lean and steps.
#
# The owner calls aim(yaw) on each tick it is free to look (the yaw its _facing would set),
# committed() when its _facing sets the body's yaw, and step() once a physics tick; then it
# composes `tilt` outside its other poses and `turn` inside them. glance(yaw) turns the head
# to something that happened (a crewmate going down) for a beat, and hop() is a small cheer.

# Turn speed, radians a second: a crew tracks a rolling ball at its circling range.
const TURN_RATE := 6.0
# Time constant of the catch-up after a commit snap, seconds.
const CATCH := 0.04
# Lean into travel at walking speed, and the lag against a change of speed.
const WALK_REF := 3.8
const LEAN_TRAVEL := 0.07
const LEAN_LAG := 0.09
const LEAN_MAX := 0.16
# How fast the felt speed follows the real one, and the tilt follows its goal (1/s).
const SPEED_FOLLOW := 6.0
const TILT_FOLLOW := 14.0
# Below this lean (radians) with nothing pushing, the body stands exactly upright.
const SETTLED := 0.002
# Steps: two a stride, a small lift and a side roll, faded in by speed.
const STEP_LENGTH := 0.7
const STEP_LIFT := 0.06
const STEP_ROLL := 0.08
# How fast the model settles onto a new slope (1/s), and the steepest it follows (radians).
const GROUND_FOLLOW := 12.0
const GROUND_MAX := 0.6
# A glance holds the look on something for this long, then the aim takes it back.
const GLANCE := 0.6
# The cheer: a hop this high, this long.
const HOP_LIFT := 0.14
const HOP := 0.3

var steps := true
# Composed by the owner: tilt (body-local, about the feet) outside its poses, turn inside.
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


func committed() -> void:
	_catching = true
	_aim = NAN


# `walking`: the body is on its feet under its own drive (not knocked or falling), so it steps.
# `ground`: the floor's normal under it; the model sits flat on a slope instead of standing
# upright into it (Andrew, 13 Nov: "the enemies are clipping into the terrain"). `girth` is the
# body's radius: a round foot on a slope stands a little proud of the ground below its centre.
func step(delta: float, body: Node3D, velocity: Vector3, foot: float, walking := true, ground := Vector3.UP, girth := 0.0) -> void:
	tilt = Transform3D.IDENTITY
	turn = Transform3D.IDENTITY
	if not EnemyMotion.active() or delta <= 0.0:
		_aim = NAN
		return
	var root_yaw := body.global_basis.get_euler().y
	if not is_nan(_root_yaw):
		# The model's world heading is continuous when the body's yaw jumps (the commit snap).
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
	var scale := EnemyMotion.motion_scale
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
	_ground = _ground.slerp(ground.normalized(), 1.0 - exp(-GROUND_FOLLOW * delta)) if ground.length_squared() > 0.0 else _ground
	var slope := minf(_ground.angle_to(Vector3.UP), GROUND_MAX)
	if slope > 0.001:
		# Lay the model on the slope about its feet, and drop it by the round foot's standoff.
		var up := body.global_basis.inverse() * _ground
		lay = Basis(Vector3.UP.cross(up).normalized(), slope)
		sink = girth * (1.0 / cos(slope) - 1.0)
	var angle := _tilt.length() * scale
	var lean := Basis.IDENTITY
	if angle > 0.0001:
		# Tilt toward the lean vector, about the feet, in the body's own frame.
		var local := body.global_basis.inverse() * _tilt
		lean = Basis(Vector3.UP.cross(local).normalized(), angle)
	if slope > 0.001 or angle > 0.0001:
		tilt = Transform3D(Basis.IDENTITY, pivot + Vector3.DOWN * sink) * Transform3D(lay * lean, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)


# The turn the model carries now, radians (tests).
func yaw() -> float:
	return _yaw
