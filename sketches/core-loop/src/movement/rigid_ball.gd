extends RigidBody3D

const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const Augments := preload("res://src/movement/augments.gd")
const Contact := preload("res://src/movement/contact.gd")
const TwinLines := preload("res://src/movement/twin_lines.gd")

signal enemy_touched(enemy: Node3D, normal: Vector3)
signal slammed(at: Vector3, speed: float, flatness: float)
signal pylon_planted(at: Vector3, banked_speed: float)
signal pylon_ejected(velocity: Vector3)
signal jumped(air: bool)
signal boosted(direction: Vector3)
# A fact one of the kit's static rules left: the bus signal's name and its arguments.
signal kit_fact(kind: String, args: Array)
signal landed(impact: float)

var tuning
var state
var drive_basis := Basis.IDENTITY
# Draw-side hooks (MOTION-SPEC row 210). Emitted before the body takes a velocity set, and
# before a teleport, so the drawn lattice can keep its spin through the forced floor roll the
# set applies below. Nothing here reads or changes the body.
signal velocity_setting
signal teleporting
var intent
var kit
# The off line, a prototype; null unless --twin-lines=on (twin_lines.gd).
var twin
# Pushes from the world (the flood's drag and current), an acceleration in m/s^2. The
# owner adds to it every physics tick and the ball spends and clears it once per step.
var external_accel := Vector3.ZERO
# The velocity handed to the solver on each of the last few ticks, newest last. A
# contact report arrives after the solver has already bounced the ball, so a contact
# is sized from these, not from the velocity it now has.
const VELOCITY_HISTORY := 4
var recent_velocities: Array[Vector3] = []

var _probe: ShapeCast3D
var _pending_position = null
var _pending_velocity = null
var _active := false
var _last_fall_speed := 0.0
var _settle_interpolation := 0
# True from a teleport until its interpolation reset has run. In that gap the interpolated
# transform still points at the old spot, so whoever draws from the ball reads the raw one
# (PlayerBall.shown_transform): a lens snapped in the same breath lands on the new spot.
var placing := false


func setup(tuning_ref, state_ref) -> void:
	tuning = tuning_ref
	state = state_ref
	mass = 6.0
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	custom_integrator = false
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.25
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.9
	physics_material.bounce = 0.25
	physics_material_override = physics_material
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, true)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	add_child(shape)
	_probe = Rules.make_probe(self)
	add_child(_probe)
	body_entered.connect(_on_body_entered)
	twin = TwinLines.create(self)


func set_active(active: bool) -> void:
	_active = active
	freeze = not active
	set_collision_layer_value(2, active)
	_probe.enabled = active
	sleeping = false


# A shove divided by a zero physics delta, or any other NaN, must never reach the body: once
# the ball's position is NaN no rescue can find it again. A non-finite velocity reads as rest.
static func _finite(v: Vector3) -> Vector3:
	return v if v.is_finite() else Vector3.ZERO


func set_velocity_now(new_velocity: Vector3) -> void:
	velocity_setting.emit()
	new_velocity = _finite(new_velocity)
	_pending_velocity = new_velocity
	state.velocity = new_velocity


func teleport(to: Vector3, new_velocity: Vector3) -> void:
	teleporting.emit()
	new_velocity = _finite(new_velocity)
	_pending_velocity = new_velocity
	state.velocity = new_velocity
	if not to.is_finite():
		push_warning("rigid_ball: teleport to a non-finite point refused")
		return
	_pending_position = to
	if twin != null:
		twin.clear()
	# The body takes its new place and speed now, so whoever reads the ball back in the same breath
	# (a lens snap, a rescue check, a ride that catches it) finds it there, moving as placed. A
	# frozen ball is a static body, which would read a speed as a conveyor's, so it waits for the
	# thaw. _integrate_forces sets the same point and speed again on the next tick, so the ball
	# leaves the spot on the tick it always did. The deferred reset runs before the next draw, so
	# no frame slides from the old spot.
	if is_inside_tree():
		global_position = to
	else:
		position = to
	if not freeze:
		linear_velocity = new_velocity
	placing = true
	_reset_placed.call_deferred()


func _reset_placed() -> void:
	placing = false
	reset_physics_interpolation()


# A teleport must not be drawn as a streak from the old spot. _integrate_forces sets the point
# again on the tick after the call, so the reset is repeated on the ticks that follow it.
func _physics_process(_delta: float) -> void:
	if _settle_interpolation > 0:
		_settle_interpolation -= 1
		reset_physics_interpolation()


func _integrate_forces(body_state: PhysicsDirectBodyState3D) -> void:
	if _pending_position != null:
		body_state.transform = Transform3D(body_state.transform.basis, _pending_position)
		_pending_position = null
		_settle_interpolation = 2
	if not body_state.linear_velocity.is_finite():
		body_state.linear_velocity = Vector3.ZERO
		body_state.angular_velocity = Vector3.ZERO
	if _pending_velocity != null:
		body_state.linear_velocity = _pending_velocity
		var axis := Rules.roll_axis(_pending_velocity, Vector3.UP)
		body_state.angular_velocity = axis / Tuning.RADIUS if axis != Vector3.ZERO else Vector3.ZERO
		_pending_velocity = null
	if not _active or intent == null:
		return

	var delta := body_state.step
	gravity_scale = tuning.f("gravity") / 9.8
	state.velocity = body_state.linear_velocity
	var origin := body_state.transform.origin
	Rules.tick_grip(state, tuning, delta)
	if tuning.on("legacy_spin_probe"):
		_probe.global_transform = body_state.transform
	else:
		_probe.global_transform = Transform3D(Basis.IDENTITY, origin)
		Rules.aim_probe(_probe, state, tuning)
	# Sable's vault kick and a falling slam own the faces the ball meets in the air, so a
	# wall is taken from the air only without them; carving up from the floor still grips,
	# and inside the coyote time a one-tick hop off a seam re-takes the wall.
	var take_speed := Rules.grip_speed(state, tuning)
	if not state.grounded and state.coyote <= 0.0 and kit != null and (kit.on(Augments.VAULT) or kit.slamming):
		take_speed = INF
	Rules.probe_ground(_probe, state, Rules.ground_dot(state, tuning), take_speed)
	Rules.grip_contact(state, tuning, body_state, take_speed)

	var spin = Rules.carve_spin(state, tuning)
	if spin != null:
		body_state.angular_velocity = spin

	var wish := Vector3.ZERO
	if not Augments.holding(kit):
		wish = Rules.wish_direction(intent, drive_basis, state)
		if wish != Vector3.ZERO:
			var head := Rules.drive_head(state, tuning, wish) * Rules.drive_scale(state, tuning, intent)
			# Torque is the honest way to drive a sphere; a small central force keeps it
			# from feeling like the ball is fighting its own contact patch.
			body_state.apply_torque(Vector3.UP.cross(wish) * tuning.f("rigid_torque") * head)
			body_state.apply_central_force(wish * tuning.f("drive_accel") * 0.3 * mass * head)

		if intent.brake_held and state.grounded:
			body_state.apply_central_force(-state.velocity.normalized() * Tuning.BRAKE_RESISTANCE * mass)
			body_state.angular_velocity *= 0.92
		elif state.grounded:
			body_state.apply_central_force(-state.velocity.normalized() * tuning.f("rolling_resistance") * mass)

		# The over-speed drag is an air rule on this ball (HOOK-FIX, 2026-10-09). On the ground
		# it pays only the rolling and brake forces above: that is the ball Andrew chose in play
		# for its speed and momentum (TADR-006 D1), and the designed rides up to the sky layer
		# and the two-hook apex need that momentum (stage_layers_test, bot_chain_hand_test).
		if not state.grounded:
			body_state.apply_central_impulse(Rules.over_speed_drag(state, tuning, delta) * mass)

		if external_accel != Vector3.ZERO:
			body_state.apply_central_force(external_accel * mass)

		# A ride that lifts the ball off its face (the reactor's sheet, a chute's assist) wins:
		# the press would hold the ball on the face the ride is carrying it up and away from.
		var press := Rules.downforce(state, tuning)
		if press != Vector3.ZERO and external_accel.dot(state.contact_normal) <= 0.0:
			body_state.apply_central_force(press * mass)
	external_accel = Vector3.ZERO

	# The augments run before jump and boost so a pylon jump or a vault kick can claim
	# the same key without the base rule firing as well.
	Augments.apply(kit, state, tuning, intent, drive_basis, body_state)
	if twin != null and kit != null and not Augments.holding(kit):
		twin.step(kit, state, tuning, intent, body_state)
	# The augments write the body's velocity directly; one that went non-finite reads as rest
	# here, as the entry check above does, so the state never carries NaN for a tick.
	if not body_state.linear_velocity.is_finite():
		body_state.linear_velocity = Vector3.ZERO
	_publish_kit(body_state)

	if Augments.holding(kit):
		_last_fall_speed = 0.0
		state.velocity = body_state.linear_velocity
		_remember(state.velocity)
		return

	var boost := Rules.boost(state, tuning, intent, wish, -drive_basis.z)
	if boost != Vector3.ZERO:
		body_state.apply_central_impulse(boost * mass)
		boosted.emit(boost.normalized())

	var was_grounded: bool = state.grounded or state.coyote > 0.0
	var jump := Rules.jump(state, tuning)
	if jump != Vector3.ZERO:
		body_state.apply_central_impulse(jump * mass)
		jumped.emit(not was_grounded)

	var falling := maxf(0.0, -body_state.linear_velocity.y)
	if state.grounded and _last_fall_speed > 4.0 and falling < _last_fall_speed * 0.5:
		state.impact = maxf(state.impact, _last_fall_speed)
		landed.emit(_last_fall_speed)
	_last_fall_speed = falling
	state.velocity = body_state.linear_velocity
	_remember(state.velocity)


func _remember(velocity: Vector3) -> void:
	recent_velocities.append(velocity)
	if recent_velocities.size() > VELOCITY_HISTORY:
		recent_velocities.pop_front()


# The augments are static rules with no signals of their own; they leave a flag on the
# kit and the ball turns each flag into one published fact.
func _publish_kit(body_state: PhysicsDirectBodyState3D) -> void:
	if kit == null:
		return
	if kit.slam_landed > 0.0:
		slammed.emit(body_state.transform.origin, kit.slam_landed, kit.slam_flat)
		kit.slam_landed = 0.0
	if kit.mount_planted:
		pylon_planted.emit(kit.mount_point, kit.mount_banked)
		kit.mount_planted = false
	if kit.dismount_fired:
		pylon_ejected.emit(kit.dismount_velocity)
		kit.dismount_fired = false
	if not kit.facts.is_empty():
		var facts: Array = kit.facts.duplicate()
		kit.facts.clear()
		for fact in facts:
			kit_fact.emit(fact[0], fact[1])


func _on_body_entered(body: Node) -> void:
	if _active and body.is_in_group("enemy"):
		enemy_touched.emit(body, Contact.normal_between(global_position, body.global_position))
