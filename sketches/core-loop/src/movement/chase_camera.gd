extends Node3D

const SpeedTier := preload("res://src/movement/speed_tier.gd")
const SENSITIVITY := 0.0022
# The shoulder view: a shorter arm with the ball off to the left of the crosshair, so
# a mounted turret can see what it is shooting (entry 6).
const SHOULDER_ARM := 4.2
const SHOULDER_SIDE := 1.5
const SHOULDER_UP := 0.7
const SHOULDER_RATE := 12.0
const KICK_RETURN := 14.0
const MAX_PUNCH := 20.0

var target
var tuning
# Spawn looks down the run, so W drives you into the hill rather than up it.
var yaw := PI
var pitch := -0.30

# Hooks for the modules; see CONTRACTS.md. Combat sets shoulder_target (0..1) while
# mounted, presentation calls punch_fov, kick and shake. Nothing else writes the rig.
var shoulder_target := 0.0
var shoulder_blend := 0.0

var arm: SpringArm3D
var cam: Camera3D

var _roll := 0.0
var _previous_velocity := Vector3.ZERO
var _shake := 0.0
var _shake_decay := 2.4
var _punch := 0.0
var _punch_decay := 0.0
var _kick := Vector3.ZERO
var _base_fov := 65.0


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
	global_position = target.shown_position()
	# The camera is placed per frame from the ball's shown (interpolated) position, so
	# the renderer must not interpolate it a second time.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func look(relative: Vector2) -> void:
	yaw -= relative.x * SENSITIVITY
	pitch = clampf(pitch - relative.y * SENSITIVITY, -1.25, 0.55)


func yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


# Faces the camera down a heading and jumps it to the ball, for a stage entry or a
# retry; without it the lag would sweep the view across the map.
func snap(heading: Vector3, pitch_value := -0.30) -> void:
	var flat := Vector3(heading.x, 0.0, heading.z)
	if flat.length_squared() > 0.0001:
		yaw = atan2(-flat.x, -flat.z)
	pitch = pitch_value
	global_position = target.shown_position() + Vector3.UP * 0.8
	_previous_velocity = target.state.velocity
	_kick = Vector3.ZERO


func aim_origin() -> Vector3:
	return cam.global_position


func aim_forward() -> Vector3:
	return -cam.global_basis.z


# Adds degrees of field of view that bleed away over time seconds.
func punch_fov(amount: float, time: float) -> void:
	_punch = clampf(_punch + amount, -MAX_PUNCH, MAX_PUNCH)
	_punch_decay = absf(_punch) / maxf(0.01, time)


# Knocks the camera along a world direction; it springs back on its own.
func kick(direction: Vector3, amount: float) -> void:
	_kick += direction.normalized() * amount if direction.length_squared() > 0.0001 else Vector3.ZERO


func shake(amount: float, time := 0.4) -> void:
	if amount > _shake:
		_shake = amount
		_shake_decay = amount / maxf(0.05, time)


func _process(delta: float) -> void:
	if target == null:
		return
	var velocity: Vector3 = target.state.velocity
	var fraction := SpeedTier.fraction(velocity.length(), tuning.f("cruise"))
	shoulder_blend = move_toward(shoulder_blend, clampf(shoulder_target, 0.0, 1.0), SHOULDER_RATE * delta)

	# Speed pulls the camera back and widens the lens; the lag tightens so the ball
	# does not slide off screen once it is quick.
	var follow := 1.0 - exp(-lerpf(6.0, 15.0, fraction) * delta)
	var shoulder := yaw_basis().x * SHOULDER_SIDE + Vector3.UP * SHOULDER_UP
	var anchor: Vector3 = target.shown_position() + Vector3.UP * 0.8 + shoulder * shoulder_blend
	global_position = global_position.lerp(anchor, lerpf(follow, 1.0, shoulder_blend * 0.5))
	var ease := 1.0 - exp(-4.0 * delta)
	var speed_arm := lerpf(7.5, 10.5, fraction)
	arm.spring_length = lerpf(arm.spring_length, lerpf(speed_arm, SHOULDER_ARM, shoulder_blend), maxf(ease, shoulder_blend * 0.25))
	_punch = move_toward(_punch, 0.0, _punch_decay * delta)
	_base_fov = lerpf(_base_fov, lerpf(65.0, 82.0, fraction), ease)

	rotation = Vector3(0.0, yaw, 0.0)
	arm.rotation = Vector3(pitch, 0.0, 0.0)

	var accel := (velocity - _previous_velocity) / maxf(delta, 0.0001)
	_previous_velocity = velocity
	var lateral := accel.dot(yaw_basis().x)
	_roll = lerpf(_roll, clampf(-lateral * 0.0022, -0.13, 0.13), 1.0 - exp(-8.0 * delta))

	_shake = maxf(_shake, clampf(target.state.impact / 30.0, 0.0, 1.2))
	_shake = maxf(0.0, _shake - delta * maxf(_shake_decay, 2.4))
	_kick = _kick.lerp(Vector3.ZERO, 1.0 - exp(-KICK_RETURN * delta))
	var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake * 0.22
	cam.position = jitter + cam.get_parent().global_basis.inverse() * _kick
	cam.rotation = Vector3(0.0, 0.0, _roll + jitter.x * 0.1)
	cam.fov = _base_fov + _punch
