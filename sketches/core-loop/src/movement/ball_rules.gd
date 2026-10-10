extends RefCounted

const Tuning := preload("res://src/movement/tuning.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

# Both modes share one rule set: the kinematic ball adds these results to its own
# velocity, the rigid ball turns the same numbers into impulses and forces. Jump,
# boost, brake and slope handling therefore cannot drift apart between modes.


static func make_probe(owner_body: CollisionObject3D) -> ShapeCast3D:
	var probe := ShapeCast3D.new()
	var shape := SphereShape3D.new()
	shape.radius = Tuning.RADIUS * 0.92
	probe.shape = shape
	probe.target_position = Vector3(0.0, -(Tuning.RADIUS * 0.08 + Tuning.SKIN + 0.06), 0.0)
	probe.max_results = 6
	probe.collision_mask = 0
	probe.set_collision_mask_value(1, true)
	probe.set_collision_mask_value(3, true)
	probe.add_exception(owner_body)
	# The cast must point at the world's down, not the ball's: as a plain child of the
	# rolling body it turned with the spin and found the ground on only 38% of ticks
	# rolling on flat ground. The owner places it every step instead.
	probe.top_level = true
	return probe


static func probe_ground(probe: ShapeCast3D, state) -> void:
	probe.force_shapecast_update()
	var best := -1.0
	var normal := Vector3.UP
	if probe.is_colliding():
		for i in probe.get_collision_count():
			var n: Vector3 = probe.get_collision_normal(i)
			if n.y > best:
				best = n.y
				normal = n
	if best > Tuning.MAX_SLOPE_DOT:
		state.grounded = true
		state.contact_normal = normal
		state.coyote = Tuning.COYOTE_TIME
		state.air_actions = 1
	else:
		state.grounded = false
		state.contact_normal = Vector3.UP


static func wish_direction(intent, drive_basis: Basis, state) -> Vector3:
	if intent.move.length_squared() < 0.02:
		return Vector3.ZERO
	var flat: Vector3 = (drive_basis.x * intent.move.x) - (drive_basis.z * intent.move.y)
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return Vector3.ZERO
	var dir: Vector3 = flat.normalized()
	if state.grounded:
		var n: Vector3 = state.contact_normal
		dir = dir - n * dir.dot(n)
		if dir.length_squared() < 0.0001:
			return Vector3.ZERO
		dir = dir.normalized()
	return dir


# Drive fades out as speed along the input reaches cruise, so it never removes
# speed the slope or a boost gave you; it only refuses to add more.
static func drive_head(state, tuning, wish: Vector3) -> float:
	if wish == Vector3.ZERO:
		return 0.0
	return clampf(1.0 - state.velocity.dot(wish) / (tuning.f("cruise") * state.cruise_boost), 0.0, 1.0)


static func drive_scale(state, tuning, intent) -> float:
	if not state.grounded:
		return tuning.f("air_control")
	return Tuning.BRAKE_TURN_BOOST if intent.brake_held else 1.0


static func drive_accel(state, tuning, wish: Vector3, intent) -> Vector3:
	if wish == Vector3.ZERO:
		return Vector3.ZERO
	return wish * tuning.f("drive_accel") * drive_head(state, tuning, wish) * drive_scale(state, tuning, intent)


static func slope_gravity(state, tuning) -> Vector3:
	var g: Vector3 = Vector3.DOWN * tuning.f("gravity")
	if not state.grounded:
		return g
	var n: Vector3 = state.contact_normal
	return g - n * g.dot(n)


static func resistance(state, tuning, intent, delta: float) -> Vector3:
	var speed: float = state.velocity.length()
	if speed <= 0.001:
		return Vector3.ZERO
	var dir: Vector3 = state.velocity / speed
	var loss := _over_speed_loss(speed, tuning, delta)
	if state.grounded:
		var rate: float = Tuning.BRAKE_RESISTANCE if intent.brake_held else tuning.f("rolling_resistance")
		loss += rate * delta
	return -dir * minf(speed, loss)


# The quadratic part of resistance alone. The rigid ball pays rolling and brake
# resistance as forces of its own, and this term as an impulse in the air only; on the
# ground the rigid ball, the game's authority (TADR-006), keeps its over-cruise speed.
static func over_speed_drag(state, tuning, delta: float) -> Vector3:
	var speed: float = state.velocity.length()
	if speed <= 0.001:
		return Vector3.ZERO
	return -state.velocity / speed * minf(speed, _over_speed_loss(speed, tuning, delta))


static func _over_speed_loss(speed: float, tuning, delta: float) -> float:
	var fast: float = tuning.f("cruise") * SpeedTier.MULTIPLES[SpeedTier.FAST]
	if speed <= fast:
		return 0.0
	var excess := speed - fast
	return Tuning.QUAD_DRAG * excess * excess * delta


static func stick(state, delta: float) -> Vector3:
	if not state.grounded:
		return Vector3.ZERO
	var n: Vector3 = state.contact_normal
	var outward: float = state.velocity.dot(n)
	if outward > 0.0:
		# Below the launch speed a crest must not throw you; above it, it should.
		if state.velocity.length() < Tuning.STICK_SPEED:
			return -n * minf(outward, Tuning.STICK_ACCEL * delta)
		return Vector3.ZERO
	return -n * Tuning.STICK_ACCEL * delta * 0.12


static func boost(state, tuning, intent, wish: Vector3, fallback: Vector3) -> Vector3:
	if not intent.boost_pressed or state.boost_cooldown > 0.0:
		return Vector3.ZERO
	var dir: Vector3
	if state.velocity.length() > 2.5:
		dir = state.velocity.normalized()
	elif wish != Vector3.ZERO:
		dir = wish
	else:
		dir = fallback
	state.boost_cooldown = tuning.boost_cooldown()
	return dir * Tuning.BOOST_IMPULSE


static func jump(state, tuning) -> Vector3:
	if state.jump_buffer <= 0.0:
		return Vector3.ZERO
	var from_ground: bool = state.grounded or state.coyote > 0.0
	if not from_ground and state.air_actions <= 0:
		return Vector3.ZERO
	var n: Vector3 = state.contact_normal if from_ground else Vector3.UP
	var dir := (n + Vector3.UP).normalized()
	if not from_ground:
		state.air_actions -= 1
	state.jump_buffer = 0.0
	state.coyote = 0.0
	state.grounded = false
	# Keep the horizontal run: only the component along the jump direction is set.
	var along: float = state.velocity.dot(dir)
	return dir * maxf(0.0, tuning.f("jump_speed") - along)


static func roll_axis(velocity: Vector3, normal: Vector3) -> Vector3:
	var tangential := velocity - normal * velocity.dot(normal)
	if tangential.length_squared() < 0.0001:
		return Vector3.ZERO
	return normal.cross(tangential)
