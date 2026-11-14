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


# The grip clock, once per physics step: full at the fast tier, running down below it.
static func tick_grip(state, tuning, delta: float) -> void:
	if state.velocity.length() >= tuning.f("cruise") * SpeedTier.MULTIPLES[SpeedTier.FAST]:
		state.grip_hold = Tuning.GRIP_PEEL_S
	else:
		state.grip_hold = maxf(0.0, state.grip_hold - delta)


static func gripping(state, tuning) -> bool:
	return state.grip_hold > 0.0 and tuning.grip_on()


# The lowest contact normal y that counts as ground this step.
static func ground_dot(state, tuning) -> float:
	return Tuning.GRIP_SLOPE_DOT if gripping(state, tuning) else Tuning.MAX_SLOPE_DOT


# A downward cast misses a wall beside the ball, so while gripping a steep face the probe
# looks along that face's normal instead. Otherwise it looks at the world's down.
static func aim_probe(probe: ShapeCast3D, state, tuning) -> void:
	var dir := Vector3.DOWN
	if gripping(state, tuning) and state.grounded and state.contact_normal.y < Tuning.GRIP_FORCE_FROM:
		dir = -state.contact_normal
	probe.target_position = dir * (Tuning.RADIUS * 0.08 + Tuning.SKIN + 0.06)


# The press into a gripped face, as an acceleration along -normal: zero on floors and banks,
# full from MAX_SLOPE_DOT up the wall and over the lip of an overhang.
static func downforce(state, tuning) -> Vector3:
	if not state.grounded or not gripping(state, tuning):
		return Vector3.ZERO
	var n: Vector3 = state.contact_normal
	var weight := clampf((Tuning.GRIP_FORCE_FROM - n.y) / (Tuning.GRIP_FORCE_FROM - Tuning.MAX_SLOPE_DOT), 0.0, 1.0)
	return -n * Tuning.GRIP_DOWNFORCE * state.velocity.length() * weight


# The spin a gripping ball rolls along a wall with, or null off one. Matching it keeps the wall's
# contact from scrubbing the ball's speed into slip (Speed holds); floors and banks, ground
# without grip, keep the contact's own spin.
static func carve_spin(state, tuning):
	if not state.grounded or not gripping(state, tuning) or state.contact_normal.y > Tuning.MAX_SLOPE_DOT:
		return null
	return state.contact_normal.cross(state.velocity) / Tuning.RADIUS


# The speed along a face that lets a gripping ball take it, or INF when grip is off.
static func grip_speed(state, tuning) -> float:
	return tuning.f("cruise") * SpeedTier.MULTIPLES[SpeedTier.FAST] if gripping(state, tuning) else INF


# Floors and banks are always ground. A wall is ground only while gripping, and a ball takes
# a new wall only running along it at grip speed: a head-on hit runs along nothing, so it
# still bounces (the pipe vault's head-on bounce stays). A wall it already rides holds until
# the grip clock runs out. Only the world's faces are walls: an enemy's flank never is.
static func _takes(state, n: Vector3, floor_dot: float, take_speed: float, on_wall: bool, world: bool) -> bool:
	if n.y <= floor_dot:
		return false
	if n.y > Tuning.MAX_SLOPE_DOT:
		return true
	if not world:
		return false
	return on_wall or (state.velocity - n * state.velocity.dot(n)).length() >= take_speed


static func probe_ground(probe: ShapeCast3D, state, floor_dot := Tuning.MAX_SLOPE_DOT, take_speed := INF) -> void:
	probe.force_shapecast_update()
	var on_wall: bool = state.grounded and state.contact_normal.y <= Tuning.MAX_SLOPE_DOT
	var best := -INF
	var normal := Vector3.UP
	if probe.is_colliding():
		for i in probe.get_collision_count():
			var n: Vector3 = probe.get_collision_normal(i)
			if n.y > best and _takes(state, n, floor_dot, take_speed, on_wall, world_face(probe.get_collider(i))):
				best = n.y
				normal = n
	_set_ground(state, normal if best > -INF else null)


# Landing on a wall from the air, or meeting one beside the ball, never shows under a probe
# that looks down: while gripping, a touched world face is taken by the same rule.
static func grip_contact(state, tuning, body_state: PhysicsDirectBodyState3D, take_speed: float) -> void:
	if state.grounded or not gripping(state, tuning):
		return
	var best := -INF
	var found = null
	for i in body_state.get_contact_count():
		if not world_face(body_state.get_contact_collider_object(i)):
			continue
		var n := body_state.get_contact_local_normal(i)
		if (n.y > best or (n.y == best and _faced_first(n, found, state.velocity))) \
				and _takes(state, n, Tuning.GRIP_SLOPE_DOT, take_speed, false, true):
			best = n.y
			found = n
	if found != null:
		_set_ground(state, found)


# Of two touched faces equally steep (two upright walls in a corner), the one the ball is moving
# into harder, then the lower x and z of the normal: the server lists a tick's contacts in the
# order its threads found them, so "the first one listed" would differ between launches.
static func _faced_first(n: Vector3, other, velocity: Vector3) -> bool:
	if other == null:
		return true
	var into := velocity.dot(n)
	var other_into := velocity.dot(other)
	if into != other_into:
		return into < other_into
	return n.x < other.x if n.x != other.x else n.z < other.z


# A static face of the world. A boss hull is an AnimatableBody3D (a StaticBody3D) in the enemy
# group, and it stays a body to ram, never a wall to ride.
static func world_face(collider) -> bool:
	return collider is StaticBody3D and not (collider as Node).is_in_group("enemy")


static func _set_ground(state, normal) -> void:
	if normal != null:
		state.grounded = true
		state.contact_normal = normal
		state.coyote = Tuning.COYOTE_TIME
		state.air_actions = 1
	else:
		state.grounded = false
		state.contact_normal = Vector3.UP
	state.carving = state.grounded and state.grip_hold > 0.0 and state.contact_normal.y < Tuning.CARVE_DOT


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
	# Off a gripped wall the ball already climbs faster than the jump, so half up would add
	# nothing: the jump pushes straight off the face instead.
	if from_ground and n.y < Tuning.MAX_SLOPE_DOT:
		dir = n
	if not from_ground:
		state.air_actions -= 1
	state.jump_buffer = 0.0
	state.coyote = 0.0
	state.grounded = false
	state.carving = false
	# Keep the horizontal run: only the component along the jump direction is set.
	var along: float = state.velocity.dot(dir)
	return dir * maxf(0.0, tuning.f("jump_speed") - along)


static func roll_axis(velocity: Vector3, normal: Vector3) -> Vector3:
	var tangential := velocity - normal * velocity.dot(normal)
	if tangential.length_squared() < 0.0001:
		return Vector3.ZERO
	return normal.cross(tangential)
