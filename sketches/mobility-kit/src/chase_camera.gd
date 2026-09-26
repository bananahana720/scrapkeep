extends Node3D

const SpeedTier := preload("res://src/speed_tier.gd")
const SENSITIVITY := 0.0022

var target
var tuning
# Spawn looks down the run, so W drives you into the hill rather than up it.
var yaw := PI
var pitch := -0.30

var arm: SpringArm3D
var cam: Camera3D

var _roll := 0.0
var _previous_velocity := Vector3.ZERO
var _shake := 0.0


func setup(target_ref, tuning_ref) -> void:
	target = target_ref
	tuning = tuning_ref
	arm = SpringArm3D.new()
	var probe := SphereShape3D.new()
	probe.radius = 0.3
	arm.shape = probe
	arm.spring_length = 8.0
	arm.margin = 0.25
	# SpringArm3D is a plain Node3D: only the raw mask is available, and it must see
	# the world (layer 1) without catching the player ball (layer 2).
	arm.collision_mask = 1
	add_child(arm)
	# The arm rewrites its direct child's transform every physics tick, so shake and
	# roll go on a grandchild; writing them on the arm's child snapped the camera to
	# the pivot on every frame between ticks.
	var mount := Node3D.new()
	arm.add_child(mount)
	cam = Camera3D.new()
	cam.fov = 65.0
	cam.far = 700.0
	cam.current = true
	mount.add_child(cam)
	global_position = target.ball_position()


func look(relative: Vector2) -> void:
	yaw -= relative.x * SENSITIVITY
	pitch = clampf(pitch - relative.y * SENSITIVITY, -1.25, 0.55)


func yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	if target == null:
		return
	var velocity: Vector3 = target.state.velocity
	var fraction := SpeedTier.fraction(velocity.length(), tuning.f("cruise"))

	# Speed pulls the camera back and widens the lens; the lag tightens so the ball
	# does not slide off screen once it is quick.
	var follow := 1.0 - exp(-lerpf(6.0, 15.0, fraction) * delta)
	global_position = global_position.lerp(target.ball_position() + Vector3.UP * 0.8, follow)
	var ease := 1.0 - exp(-4.0 * delta)
	arm.spring_length = lerpf(arm.spring_length, lerpf(7.5, 10.5, fraction), ease)
	cam.fov = lerpf(cam.fov, lerpf(65.0, 82.0, fraction), ease)

	rotation = Vector3(0.0, yaw, 0.0)
	arm.rotation = Vector3(pitch, 0.0, 0.0)

	var accel := (velocity - _previous_velocity) / maxf(delta, 0.0001)
	_previous_velocity = velocity
	var lateral := accel.dot(yaw_basis().x)
	_roll = lerpf(_roll, clampf(-lateral * 0.0022, -0.13, 0.13), 1.0 - exp(-8.0 * delta))

	_shake = maxf(_shake, clampf(target.state.impact / 30.0, 0.0, 1.2))
	_shake = maxf(0.0, _shake - delta * 2.4)
	var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.22
	cam.position = jitter
	cam.rotation = Vector3(0.0, 0.0, _roll + jitter.x * 0.1)
