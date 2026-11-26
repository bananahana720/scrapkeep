extends Node3D

const SpeedTier := preload("res://src/movement/speed_tier.gd")
const BallState := preload("res://src/movement/ball_state.gd")
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
# A glance (glance_at): its default length, the flatter pitch it settles on so a tall subject
# fits, and the look input that ends it (mouse pixels moved since it began, stick deflection).
const GLANCE_SECONDS := 0.9
const GLANCE_PITCH := -0.16
const GLANCE_BREAK_PX := 6.0
const GLANCE_BREAK_STICK := 0.25
# A subject inside this share of the lens's half-width is in the picture and needs no glance.
const GLANCE_IN_VIEW := 0.7
# The longest wall step one frame gives the glance (see _process).
const GLANCE_STEP_CAP := 0.05
# A wall close behind the ball shortens the arm until the 1 m ball fills the lens (PF-06). The arm
# then tips up so the lens rises over the ball; the lens is turned back by the lift, so the aim stays
# the player's. How tight the view is comes from a probe of the arm's own unlifted direction (see
# _free_arm), never from the arm being turned, so the lift cannot change its own input.
# At 4 m the 1 m ball spans about 28 degrees, near half the 65 degree lens: where it starts to crowd.
const TIGHT_ARM := 4.0
# At 1.5 m of arm the lens is about 0.9 m off the ball's shell at the default pitch and the ball spans more
# than the 65 degree lens, so a shorter arm is no worse: the lift is whole from here.
const TIGHT_FULL := 1.5
# 0.6 rad lifts the lens about 1 m at a 2 m arm, enough to clear the top of the 1 m ball.
const TIGHT_LIFT := 0.6
# The arm never tips past this, just short of straight up (1.57), where the yaw frame would flip.
const MAX_ARM_PITCH := -1.5
# Physics layer 4: bodies only the camera sees, built to a boss's drawn body (the Warden's drum, Brindle's
# drawn boxes). They sit on no other layer and mask nothing, so no contact in play meets them.
const CAMERA_BODY_BIT := 8
# The arm's probe sphere. A camera-only body must stay clear of it where the ball touches what it covers
# (Warden.fit_camera_shell), or the cast starts inside it and skips it.
const PROBE_RADIUS := 0.3
# A lifted probe must free at least this much arm over the unlifted one, or the lift is not worth it.
const LIFT_GAIN := 0.3
const CONTACT_RANGE := 40.0
const CONTACT_FADE_START := 35.0
const CONTACT_BOW_FAR := 17.0
const CONTACT_BOW_NEAR := 10.0
const CONTACT_PERCH_FAR := -0.03
const CONTACT_PERCH_NEAR := -1.42
const CONTACT_LIFT_MAX := 0.4
const CONTACT_FLOOR_PINNED := 0.55
const CONTACT_FLOOR_FREE := 0.8
const CONTACT_LIFT_RATE := 16.0
# Situation rows. arm 0.0 means no opinion; pitch_bias tilts the arm without touching the
# player's pitch; shake_cap is the most total shake allowed while the row is active.
const PROFILES := {
	"falling": {"arm": 12.0, "pitch_bias": -0.21, "fov_add": 6.0, "shake_cap": 1.2},
	# A shut yard (stage_locks.gd, through juice.gd): the arm reaches out and up over the yard's rim so a
	# fight in a bowl (the dam's apron) sees its floor and its crew past the far wall.
	"locked": {"arm": 12.0, "pitch_bias": -0.21, "fov_add": 3.0, "shake_cap": 1.2},
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
# Reduced motion (the settings page): every punch, kick and shake is 0 whatever motion_scale says.
var reduced_motion := false

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
var _tight := 0.0
var _contact_subject: Node3D
var _contact_lift := 0.0
var _query := PhysicsShapeQueryParameters3D.new()
var _fov_add := 0.0
var _glance_subject: Node3D
var _glance_seconds := 0.0
var _glance_age := 0.0
var _glance_from := Vector2.ZERO
var _glance_drift := 0.0


# A body for a camera-only shape: layer 4, no mask, moved by its owner's node each tick.
static func camera_body() -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	body.collision_layer = CAMERA_BODY_BIT
	body.collision_mask = 0
	return body


func setup(target_ref, tuning_ref) -> void:
	target = target_ref
	tuning = tuning_ref
	arm = SpringArm3D.new()
	var probe := SphereShape3D.new()
	probe.radius = PROBE_RADIUS
	arm.shape = probe
	_query.shape = probe
	arm.spring_length = 8.0
	arm.margin = 0.25
	# SpringArm3D is a plain Node3D: only the raw mask is available, and it must see
	# the world (layer 1) and the camera-only bodies of what a boss draws (layer 4), without
	# catching the player ball (layer 2) or enemies (layer 3: a grunt rolling past would snap the arm in).
	arm.collision_mask = 1 | CAMERA_BODY_BIT
	_query.collision_mask = arm.collision_mask
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
	if _glance_subject != null:
		# A bumped mouse is not a look: the glance gives way once the hand has moved this far.
		_glance_drift += relative.length()
		if _glance_drift > GLANCE_BREAK_PX:
			_glance_subject = null
	yaw -= relative.x * mouse_sensitivity
	pitch = clampf(pitch - relative.y * mouse_sensitivity, -1.25, 0.55)


# The right stick, read each frame: `stick` is the look vector (x right, y down, as the mouse),
# each axis cubed so a small push aims finely; full deflection turns STICK_YAW and STICK_PITCH
# rad/s at the default sensitivity. Invert Y reverses stick pitch only. `on_target` is true while
# the crosshair is on a hookable surface or enemy (the harpoon's aim record): the turn then
# slows by aim_assist * AIM_ASSIST_SLOW. Mouse look is never slowed.
func look_stick(stick: Vector2, delta: float, on_target := false) -> void:
	if stick.length() > GLANCE_BREAK_STICK:
		_glance_subject = null
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
	_tight = 0.0
	_contact_lift = 0.0
	_glance_subject = null


# A glance: the view turns to a subject over `seconds` and stays there (a boss's entrance, where
# the bowl entry aims the camera down the track and the ship lands off to one side). It eases the
# player's own yaw and pitch, so the aim and the drive frame turn with the picture. The player's
# look always wins: a mouse move or a stick push ends it where it is, and a subject already in
# the picture starts none. Comfort settings that still the camera (reduced motion, motion scale
# 0) refuse it.
func glance_at(subject: Node3D, seconds := GLANCE_SECONDS) -> void:
	if subject == null or seconds <= 0.0 or _comfort_scale() <= 0.0 or in_view(subject.global_position):
		return
	_glance_subject = subject
	_glance_seconds = seconds
	_glance_age = 0.0
	_glance_drift = 0.0
	_glance_from = Vector2(yaw, pitch)


func glancing() -> bool:
	return _glance_subject != null


# Whether a point's bearing is inside the middle GLANCE_IN_VIEW of the lens's width, whatever its
# height: on a wide monitor more of the bowl is already in the picture.
func in_view(point: Vector3) -> bool:
	var to := point - global_position
	var forward := -yaw_basis().z
	var view := get_viewport().get_visible_rect().size
	var half := atan(tan(deg_to_rad(cam.fov) * 0.5) * view.x / maxf(view.y, 1.0))
	return absf(Vector2(forward.x, forward.z).angle_to(Vector2(to.x, to.z))) < half * GLANCE_IN_VIEW


# Whether a world point falls inside the lens's picture: in front of the lens and inside the
# viewport rectangle. The eye film logs it for the ball.
func shows(point: Vector3) -> bool:
	if cam == null or not cam.is_inside_tree() or cam.is_position_behind(point):
		return false
	return get_viewport().get_visible_rect().has_point(cam.unproject_position(point))


# What the arm is doing, for a log: the length it wants, the length it reached before it hit
# something, and the body that stopped it (its node path, or its name outside the tree; null
# when nothing did). The body comes from the arm's own shape cast, as _free_arm does, out past the
# arm's margin as the arm's own cast reaches. A short reach with nothing in the way is the arm
# easing back out after a wall (it lags the length it wants), logged as easing.
func arm_reading() -> Dictionary:
	var wanted := arm.spring_length
	var out := {"wanted": snappedf(wanted, 0.01), "hit": snappedf(arm.get_hit_length(), 0.01), "body": null, "easing": false}
	if not is_inside_tree() or arm.get_hit_length() >= wanted - 0.01:
		return out
	var space := get_world_3d().direct_space_state
	var dir: Vector3 = arm.global_basis * Vector3.BACK
	var reach := wanted + arm.margin
	_query.transform = Transform3D(Basis.IDENTITY, arm.global_position)
	_query.motion = dir * reach
	var fractions := space.cast_motion(_query)
	if fractions.size() < 2 or fractions[0] >= 1.0:
		out["easing"] = true
		return out
	_query.transform = Transform3D(Basis.IDENTITY, arm.global_position + dir * reach * fractions[1])
	_query.motion = Vector3.ZERO
	var rest := space.get_rest_info(_query)
	if rest.is_empty():
		return out
	var body = instance_from_id(int(rest["collider_id"]))
	if body is Node:
		out["body"] = String(body.get_path()) if body.is_inside_tree() else String(body.name)
	return out


func _step_glance(delta: float) -> void:
	if _glance_subject == null:
		return
	if not is_instance_valid(_glance_subject) or not _glance_subject.is_inside_tree():
		_glance_subject = null
		return
	_glance_age += delta
	var f := smoothstep(0.0, 1.0, _glance_age / _glance_seconds)
	var to := _glance_subject.global_position - global_position
	# A subject overhead or underfoot has no bearing worth turning to.
	if Vector2(to.x, to.z).length_squared() > 1.0:
		yaw = lerp_angle(_glance_from.x, atan2(-to.x, -to.z), f)
	pitch = lerpf(_glance_from.y, GLANCE_PITCH, f)
	if _glance_age >= _glance_seconds:
		_glance_subject = null


# A shut yard's centre (juice.gd, from stage_locks.gd), or null to release. A lock changes the arm, pitch bias and lens
# only; the player's yaw is never touched.
func set_lock(point) -> void:
	_locked = point != null


func set_boss_reach(on: bool) -> void:
	_boss_reach = on


# The fight that wants the ball and the floor kept in view near its tall body declares it here (Brindle's ship,
# the dam-face Warden). This is the opposite intent to set_boss_reach's far framing, so it is its own call. There is
# one slot for two owners: each owner ends its own with clear_contact_subject, and null here clears whoever holds it.
# A subject that has been freed is dropped.
func set_contact_subject(subject: Node3D) -> void:
	_contact_subject = subject


func clear_contact_subject(subject: Node3D) -> void:
	if _contact_subject == subject:
		_contact_subject = null


# 0..1: how far the free arm along `arm_pitch` is under TIGHT_ARM, or 0 when tipping the arm up
# would not free LIFT_GAIN metres of it (a roof). Reads two probes of its own, so the turn the arm
# is under does not feed back; an arm outside the tree or in a world with no walls reads free.
func _tight_target(arm_pitch: float) -> float:
	var free := _free_arm(arm_pitch)
	if free >= TIGHT_ARM:
		return 0.0
	if _free_arm(maxf(arm_pitch - TIGHT_LIFT, MAX_ARM_PITCH)) < free + LIFT_GAIN:
		return 0.0
	return clampf((TIGHT_ARM - free) / (TIGHT_ARM - TIGHT_FULL), 0.0, 1.0)


# Metres of arm free along a pitch from the pivot, up to TIGHT_ARM, and whether what stops it is a
# wall: the arm's own shape and mask, one query reused. Ground (a contact normal the ball
# itself calls floor, BallState.MAX_SLOPE_DOT) is no wall, so it reads as a free arm: looking up on
# open ground shortens the arm as it always did.
func _free_arm(arm_pitch: float, reach := TIGHT_ARM, ignore_floor := true) -> float:
	if not is_inside_tree():
		return reach
	var space := get_world_3d().direct_space_state
	var dir: Vector3 = yaw_basis() * Basis(Vector3.RIGHT, arm_pitch) * Vector3.BACK
	_query.transform = Transform3D(Basis.IDENTITY, global_position)
	_query.motion = dir * reach
	var fractions := space.cast_motion(_query)
	if fractions.size() < 2 or fractions[0] >= 1.0:
		return reach
	if not ignore_floor:
		return fractions[0] * reach
	# At the first contact the shape touches what stopped it; its normal says wall or floor.
	_query.transform = Transform3D(Basis.IDENTITY, global_position + dir * reach * fractions[1])
	_query.motion = Vector3.ZERO
	var rest := space.get_rest_info(_query)
	if not rest.is_empty() and (rest["normal"] as Vector3).y > BallState.MAX_SLOPE_DOT:
		return reach
	return fractions[0] * reach


func _boss_contact_lift(arm_pitch: float, subject: Node3D) -> float:
	if subject == null or shoulder_target > 0.0 or shoulder_blend > 0.0:
		return 0.0
	var distance := global_position.distance_to(subject.global_position)
	if distance >= CONTACT_RANGE or (distance >= CONTACT_BOW_FAR and not in_view(subject.global_position)):
		return 0.0
	var near_bow := 1.0 - smoothstep(CONTACT_BOW_NEAR, CONTACT_BOW_FAR, distance)
	var reach := arm.spring_length
	var normal_reach := _free_arm(arm_pitch, reach, false)
	var floor_press := (1.0 - smoothstep(CONTACT_FLOOR_PINNED, CONTACT_FLOOR_FREE, normal_reach / reach)) if arm_pitch > 0.0 else 0.0
	floor_press *= 1.0 - smoothstep(CONTACT_FADE_START, CONTACT_RANGE, distance)
	var perch := lerpf(CONTACT_PERCH_FAR, CONTACT_PERCH_NEAR, near_bow)
	var lift := minf(maxf(0.0, arm_pitch - perch), CONTACT_LIFT_MAX) * maxf(floor_press, near_bow)
	if lift <= 0.0 or _free_arm(arm_pitch - lift, reach, false) < normal_reach - LIFT_GAIN:
		return 0.0
	return lift


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
func _comfort_scale() -> float:
	return 0.0 if reduced_motion else motion_scale


# The shake now in the rig, before the 0.22 jitter factor; 0 under reduced motion.
func shake_amplitude() -> float:
	return _shake


func punch_fov(amount: float, time: float) -> void:
	_punch = clampf(_punch + amount * _comfort_scale(), -MAX_PUNCH, MAX_PUNCH)
	_punch_decay = absf(_punch) / maxf(0.01, time)


# Knocks the camera along a world direction; it springs back on its own.
func kick(direction: Vector3, amount: float) -> void:
	_kick += direction.normalized() * amount * _comfort_scale() if direction.length_squared() > 0.0001 else Vector3.ZERO


func shake(amount: float, time := 0.4) -> void:
	amount *= _comfort_scale()
	if amount > _shake:
		_shake = amount
		_shake_decay = amount / maxf(0.05, time)


func _process(delta: float) -> void:
	if target == null:
		return
	# The glance is the player's own look, so it keeps wall time when the world is slowed. The
	# engine scaled this delta by the scale the frame began with, so on the frame a slow motion
	# or a hit stop starts the division overshoots: the step is capped at a slow frame's worth.
	_step_glance(minf(delta / maxf(Engine.time_scale, 0.01), GLANCE_STEP_CAP))
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
	# The lift eases in but drops at once: the spring arm springs back to full length the frame a wall
	# goes, and a lift that lingered would throw the lens up with it (a pillar pass bobbed 1.9 m).
	var tight_target := _tight_target(pitch + _pitch_bias)
	_tight = tight_target if tight_target < _tight else lerpf(_tight, tight_target, profile_ease)
	var lift := maxf(-TIGHT_LIFT * _tight, MAX_ARM_PITCH - (pitch + _pitch_bias))
	arm.spring_length = lerpf(arm.spring_length, lerpf(speed_arm, SHOULDER_ARM, shoulder_blend), maxf(ease, shoulder_blend * 0.25))
	_punch = move_toward(_punch, 0.0, _punch_decay * delta)
	_base_fov = lerpf(_base_fov, lerpf(FOV_REST, FOV_FAST, fraction), ease)

	rotation = Vector3(0.0, yaw, 0.0)
	var arm_pitch := pitch + _pitch_bias + lift
	# A freed node compares equal to null, so the validity test must stand alone to drop it.
	if not is_instance_valid(_contact_subject):
		_contact_subject = null
	var subject := _contact_subject
	var contact_lift := _boss_contact_lift(arm_pitch, subject)
	_contact_lift = lerpf(_contact_lift, contact_lift, 1.0 - exp(-CONTACT_LIFT_RATE * delta))
	_contact_lift = minf(_contact_lift, arm_pitch - MAX_ARM_PITCH)
	arm.rotation = Vector3(arm_pitch - _contact_lift, 0.0, 0.0)

	var accel := (velocity - _previous_velocity) / maxf(delta, 0.0001)
	_previous_velocity = velocity
	var lateral := accel.dot(yaw_basis().x)
	_roll = lerpf(_roll, clampf(-lateral * 0.0022, -0.13, 0.13), 1.0 - exp(-8.0 * delta))

	_shake = maxf(_shake, clampf(target.state.impact / 30.0, 0.0, 1.2) * _comfort_scale())
	_shake = minf(maxf(0.0, _shake - delta * maxf(_shake_decay, 2.4)), shake_cap)
	_kick = _kick.lerp(Vector3.ZERO, 1.0 - exp(-KICK_RETURN * delta))
	var jitter := Vector3(_shake_rng.randf_range(-1.0, 1.0), _shake_rng.randf_range(-1.0, 1.0), 0.0) * _shake * 0.22
	cam.position = jitter + cam.get_parent().global_basis.inverse() * _kick
	cam.rotation = Vector3(pitch - arm.rotation.x, 0.0, _roll + jitter.x * 0.1)
	cam.fov = minf(_base_fov + _fov_add + _punch, FOV_CAP)


static func _seeded_shake_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5CA1E
	return rng
