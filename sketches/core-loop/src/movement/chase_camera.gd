extends Node3D

const SpeedTier := preload("res://src/movement/speed_tier.gd")
const SENSITIVITY := 0.0022
const STICK_YAW := 2.6
const STICK_PITCH := 1.6
# The most the stick turn slows over a target, at aim assist 1.
const AIM_ASSIST_SLOW := 0.8
# The shoulder view: a shorter arm with the ball off to the left of the crosshair, so
# a mounted turret can see what it is shooting (entry 6).
const SHOULDER_ARM := 4.2
const SHOULDER_SIDE := 1.5
const SHOULDER_UP := 0.7
const SHOULDER_RATE := 12.0
const KICK_RETURN := 14.0
const MAX_PUNCH := 20.0
# A wide lens at speed reads as a fisheye, so base, profile add and punch share one ceiling.
const FOV_CAP := 88.0
const FOV_REST := 65.0
const FOV_FAST := 80.0
const FALL_SPEED := -8.0
const BIAS_LIMIT := 0.21
const PROFILE_EASE := 5.0
# Situation rows. arm 0.0 means no opinion; pitch_bias tilts the arm without touching the
# player's pitch; shake_cap is the most total shake allowed while the row is active.
const PROFILES := {
	"falling": {"arm": 12.0, "pitch_bias": -0.21, "fov_add": 6.0, "shake_cap": 1.2},
	"locked": {"arm": 0.0, "pitch_bias": 0.035, "fov_add": 3.0, "shake_cap": 1.2},
	"boss": {"arm": 12.0, "pitch_bias": 0.07, "fov_add": 0.0, "shake_cap": 0.6},
}

var target
var tuning
# Spawn looks down the run, so W drives you into the hill rather than up it.
var yaw := PI
var pitch := -0.30
var stick_sensitivity := STICK_YAW
var mouse_sensitivity := SENSITIVITY
var invert_y := false
# 0..1, scaled by AIM_ASSIST_SLOW in look_stick; the stick only.
var aim_assist := 0.5

# Hooks for the modules; see CONTRACTS.md. Combat sets shoulder_target (0..1) while
# mounted, presentation calls punch_fov, kick and shake. Nothing else writes the rig.
var shoulder_target := 0.0
var shoulder_blend := 0.0
# The viewer's comfort (the pause menu's Screen shake row): scales every punch, kick and
# shake, the landing shake included. 0 holds the camera still.
var motion_scale := 1.0

var arm: SpringArm3D
var cam: Camera3D

var _roll := 0.0
var _previous_velocity := Vector3.ZERO
var _shake := 0.0
# Shake has its own stream. Drawn from the global one, any visual's randf() or particle
# restart moved the picture the simulation reads, and a seeded run stopped repeating.
var _shake_rng := _seeded_shake_rng()
var _shake_decay := 2.4
var _punch := 0.0
var _punch_decay := 0.0
var _kick := Vector3.ZERO
var _base_fov := FOV_REST
var _locked := false
var _boss_reach := false
var _pitch_bias := 0.0
var _fov_add := 0.0


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


func apply_look_settings(store) -> void:
	stick_sensitivity = store.stick_sensitivity()
	mouse_sensitivity = store.mouse_sensitivity()
	invert_y = store.invert_y()
	aim_assist = store.aim_assist()
	# Input.get_vector applies the radial deadzone once, before look_stick cubes the axes.
	for action in ["cl_look_left", "cl_look_right", "cl_look_up", "cl_look_down"]:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, store.stick_deadzone())


func look(relative: Vector2) -> void:
	yaw -= relative.x * mouse_sensitivity
	pitch = clampf(pitch - relative.y * mouse_sensitivity, -1.25, 0.55)


# The right stick, read each frame: `stick` is the look vector (x right, y down, as the mouse),
# each axis cubed so a small push aims finely; full deflection turns STICK_YAW and STICK_PITCH
# rad/s at the default sensitivity. Invert Y reverses stick pitch only. `on_target` is true while
# the crosshair is on a hookable surface or enemy (the harpoon's aim record): the turn then
# slows by aim_assist * AIM_ASSIST_SLOW. Mouse look is never slowed.
func look_stick(stick: Vector2, delta: float, on_target := false) -> void:
	var shaped := Vector2(pow(stick.x, 3.0), pow(stick.y, 3.0))
	if on_target:
		shaped *= 1.0 - assist_friction()
	yaw -= shaped.x * stick_sensitivity * delta
	var pitch_rate := STICK_PITCH * (stick_sensitivity / STICK_YAW)
	var pitch_sign := -1.0 if invert_y else 1.0
	pitch = clampf(pitch - shaped.y * pitch_rate * delta * pitch_sign, -1.25, 0.55)


func assist_friction() -> float:
	return clampf(aim_assist, 0.0, 1.0) * AIM_ASSIST_SLOW


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


# A harpoon lock point, or null to release. A lock changes the arm, pitch bias and lens
# only; the player's yaw is never touched.
func set_lock(point) -> void:
	_locked = point != null


func set_boss_reach(on: bool) -> void:
	_boss_reach = on


func active_profiles() -> Array:
	var rows := []
	if target != null and not target.state.grounded and target.state.velocity.y < FALL_SPEED:
		rows.append("falling")
	if _locked:
		rows.append("locked")
	if _boss_reach:
		rows.append("boss")
	return rows


# The lens rest, before jitter and kick (:239): shots never move with the picture (W16-1).
func aim_origin() -> Vector3:
	return (cam.get_parent() as Node3D).global_position


func aim_forward() -> Vector3:
	return -cam.global_basis.z


# Adds degrees of field of view that bleed away over time seconds.
func punch_fov(amount: float, time: float) -> void:
	_punch = clampf(_punch + amount * motion_scale, -MAX_PUNCH, MAX_PUNCH)
	_punch_decay = absf(_punch) / maxf(0.01, time)


# Knocks the camera along a world direction; it springs back on its own.
func kick(direction: Vector3, amount: float) -> void:
	_kick += direction.normalized() * amount * motion_scale if direction.length_squared() > 0.0001 else Vector3.ZERO


func shake(amount: float, time := 0.4) -> void:
	amount *= motion_scale
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
	var rows := active_profiles()
	var bias_target := 0.0
	var add_target := 0.0
	var shake_cap := INF
	for row in rows:
		var profile: Dictionary = PROFILES[row]
		speed_arm = maxf(speed_arm, profile["arm"])
		bias_target += profile["pitch_bias"]
		add_target = maxf(add_target, profile["fov_add"])
		shake_cap = minf(shake_cap, profile["shake_cap"])
	var profile_ease := 1.0 - exp(-PROFILE_EASE * delta)
	_pitch_bias = lerpf(_pitch_bias, clampf(bias_target, -BIAS_LIMIT, BIAS_LIMIT), profile_ease)
	_fov_add = lerpf(_fov_add, add_target, profile_ease)
	arm.spring_length = lerpf(arm.spring_length, lerpf(speed_arm, SHOULDER_ARM, shoulder_blend), maxf(ease, shoulder_blend * 0.25))
	_punch = move_toward(_punch, 0.0, _punch_decay * delta)
	_base_fov = lerpf(_base_fov, lerpf(FOV_REST, FOV_FAST, fraction), ease)

	rotation = Vector3(0.0, yaw, 0.0)
	arm.rotation = Vector3(pitch + _pitch_bias, 0.0, 0.0)

	var accel := (velocity - _previous_velocity) / maxf(delta, 0.0001)
	_previous_velocity = velocity
	var lateral := accel.dot(yaw_basis().x)
	_roll = lerpf(_roll, clampf(-lateral * 0.0022, -0.13, 0.13), 1.0 - exp(-8.0 * delta))

	_shake = maxf(_shake, clampf(target.state.impact / 30.0, 0.0, 1.2) * motion_scale)
	_shake = minf(maxf(0.0, _shake - delta * maxf(_shake_decay, 2.4)), shake_cap)
	_kick = _kick.lerp(Vector3.ZERO, 1.0 - exp(-KICK_RETURN * delta))
	var jitter := Vector3(_shake_rng.randf_range(-1.0, 1.0), _shake_rng.randf_range(-1.0, 1.0), 0.0) * _shake * 0.22
	cam.position = jitter + cam.get_parent().global_basis.inverse() * _kick
	# The lens turns back by the bias so the view direction, and with it the aim, stays the player's.
	cam.rotation = Vector3(-_pitch_bias, 0.0, _roll + jitter.x * 0.1)
	cam.fov = minf(_base_fov + _fov_add + _punch, FOV_CAP)


static func _seeded_shake_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5CA1E
	return rng
