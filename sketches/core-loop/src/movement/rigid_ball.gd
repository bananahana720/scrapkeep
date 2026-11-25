extends RigidBody3D

const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const Augments := preload("res://src/movement/augments.gd")
const Contact := preload("res://src/movement/contact.gd")

signal enemy_touched(enemy: Node3D, normal: Vector3)
signal slammed(at: Vector3, speed: float, flatness: float)
signal pylon_planted(at: Vector3, banked_speed: float)
signal pylon_ejected(velocity: Vector3)
signal jumped(air: bool)
signal boosted(direction: Vector3)
signal kit_fact(kind: String, args: Array)
signal landed(impact: float)
signal bumped(at: Vector3, normal: Vector3, speed: float)

var tuning
var state
var drive_basis := Basis.IDENTITY
signal velocity_setting
signal teleporting
var intent
var kit
var external_accel := Vector3.ZERO
const VELOCITY_HISTORY := 4
var recent_velocities: Array[Vector3] = []

var _probe: ShapeCast3D
var _pending_position = null
var _pending_velocity = null
var _active := false
var _last_fall_speed := 0.0
var _settle_interpolation := 0
var placing := false
const CARVE_MIN_S := 0.3
var _carve_s := 0.0
var _bump_wait := 0.0
var _touching := {}
var _met: Array = []
var _told := {}


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


func set_active(active: bool) -> void:
	_active = active
	_carve_s = 0.0
	freeze = not active
	set_collision_layer_value(2, active)
	_probe.enabled = active
	sleeping = false


static func _finite(v: Vector3) -> Vector3:
	return v if v.is_finite() else Vector3.ZERO


func set_velocity_now(new_velocity: Vector3) -> void:
	velocity_setting.emit()
	new_velocity = _finite(new_velocity)
	_pending_velocity = new_velocity
	state.velocity = new_velocity


func teleport(to: Vector3, new_velocity: Vector3) -> void:
	teleporting.emit()
	_carve_s = 0.0
	new_velocity = _finite(new_velocity)
	_pending_velocity = new_velocity
	state.velocity = new_velocity
	if not to.is_finite():
		push_warning("rigid_ball: teleport to a non-finite point refused")
		return
	_pending_position = to
	# A frozen RigidBody3D acts like a static body and reads linear_velocity as a conveyor speed.
	# Deferred reset_physics_interpolation prevents a streak from the old spot before the next draw.
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
	_note_enemies(body_state)
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
	_watch_bumps(body_state, origin, delta)
	Rules.tick_grip(state, tuning, delta)
	if tuning.on("legacy_spin_probe"):
		_probe.global_transform = body_state.transform
	else:
		_probe.global_transform = Transform3D(Basis.IDENTITY, origin)
		Rules.aim_probe(_probe, state, tuning)
	var take_speed := Rules.grip_speed(state, tuning)
	if not state.grounded and state.coyote <= 0.0 and kit != null and (kit.on(Augments.VAULT) or kit.slamming):
		take_speed = INF
	Rules.probe_ground(_probe, state, Rules.ground_dot(state, tuning), take_speed)
	Rules.grip_contact(state, tuning, body_state, take_speed)
	_track_carve(origin, delta)

	var spin = Rules.carve_spin(state, tuning)
	if spin != null:
		body_state.angular_velocity = spin

	var wish := Vector3.ZERO
	if not Augments.holding(kit):
		wish = Rules.wish_direction(intent, drive_basis, state)
		if wish != Vector3.ZERO:
			var head := Rules.drive_head(state, tuning, wish) * Rules.drive_scale(state, tuning, intent)
			body_state.apply_torque(Vector3.UP.cross(wish) * tuning.f("rigid_torque") * head)
			body_state.apply_central_force(wish * tuning.f("drive_accel") * 0.3 * mass * head)

		if intent.brake_held and state.grounded:
			body_state.apply_central_force(-state.velocity.normalized() * Tuning.BRAKE_RESISTANCE * mass)
			body_state.angular_velocity *= 0.92
		elif state.grounded:
			body_state.apply_central_force(-state.velocity.normalized() * tuning.f("rolling_resistance") * mass)

		if not state.grounded:
			body_state.apply_central_impulse(Rules.over_speed_drag(state, tuning, delta) * mass)

		if external_accel != Vector3.ZERO:
			body_state.apply_central_force(external_accel * mass)

		var press := Rules.downforce(state, tuning)
		if press != Vector3.ZERO and external_accel.dot(state.contact_normal) <= 0.0:
			body_state.apply_central_force(press * mass)
	external_accel = Vector3.ZERO

	Augments.apply(kit, state, tuning, intent, drive_basis, body_state)
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


func _watch_bumps(body_state: PhysicsDirectBodyState3D, origin: Vector3, delta: float) -> void:
	_bump_wait = maxf(0.0, _bump_wait - delta)
	if _bump_wait > 0.0 or recent_velocities.is_empty():
		return
	var handed: Vector3 = recent_velocities.back()
	var best := 0.0
	var normal := Vector3.ZERO
	var at := origin
	for i in body_state.get_contact_count():
		if not Rules.world_face(body_state.get_contact_collider_object(i)):
			continue
		var n := body_state.get_contact_local_normal(i)
		var closing := Contact.bump_closing(handed, n)
		if closing > best:
			best = closing
			normal = n
			at = body_state.get_contact_local_position(i)
	if best < Contact.BUMP_MIN_SPEED:
		return
	_bump_wait = Contact.BUMP_GAP_S
	bumped.emit(at, normal, best)


func _track_carve(at: Vector3, delta: float) -> void:
	if state.carving:
		_carve_s += delta
		return
	if _carve_s >= CARVE_MIN_S and kit != null:
		kit.facts.append(["carved", [at, _carve_s, state.velocity.length()]])
	_carve_s = 0.0


func _remember(velocity: Vector3) -> void:
	recent_velocities.append(velocity)
	if recent_velocities.size() > VELOCITY_HISTORY:
		recent_velocities.pop_front()


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


# PhysicsServer3D reports contacts and body_entered in worker-thread order; sort deterministically.
func _note_enemies(body_state: PhysicsDirectBodyState3D) -> void:
	var now := {}
	_met.clear()
	_told.clear()
	for i in body_state.get_contact_count():
		var body = body_state.get_contact_collider_object(i)
		if not (body is Node3D and body.is_in_group("enemy")) or now.has(body.get_instance_id()):
			continue
		now[body.get_instance_id()] = true
		if not _touching.has(body.get_instance_id()):
			_met.append(body)
	_touching = now
	if _met.size() > 1:
		_met.sort_custom(Contact.meets_first.bind(body_state.transform.origin, Augments.landing_body(kit)))


func _on_body_entered(body: Node) -> void:
	var met := _met.duplicate()
	_met.clear()
	if not _told.has(body.get_instance_id()) and not met.has(body):
		met.append(body)
	for enemy in met:
		if not _active or not is_instance_valid(enemy) or not enemy.is_in_group("enemy"):
			continue
		_told[enemy.get_instance_id()] = true
		enemy_touched.emit(enemy, Contact.normal_between(global_position, enemy.global_position))
