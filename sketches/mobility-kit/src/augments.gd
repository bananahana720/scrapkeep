extends RefCounted

const Tuning := preload("res://src/tuning.gd")

# One row per augment. The number keys, the HUD list and the kit's enabled flags all
# read this table, so a sixth augment is one row here plus its force function below.
const GRAPPLE := "grapple"
const DASH := "dash"
const GLIDE := "glide"
const SLAM := "slam"
const CLING := "cling"

const SPECS := [
	{"key": GRAPPLE, "label": "Grapple", "hint": "RMB fire/release · Q or wheel reels"},
	{"key": DASH, "label": "Air dash", "hint": "Shift while airborne, refreshed on landing"},
	{"key": GLIDE, "label": "Glide", "hint": "hold Space falling, after the air jump"},
	{"key": SLAM, "label": "Slam", "hint": "Ctrl while airborne"},
	{"key": CLING, "label": "Mag-cling", "hint": "hold E near a steep face"},
]

const MIN_ROPE := 2.5
const CLING_REACH := 1.5
# sin 60 deg: the face leans less than 60 degrees off vertical, so the magnet holds.
const CLING_MAX_TILT := 0.866
const CLING_GRIP := 3.0
const CLING_COOLDOWN := 0.25
const CLING_RAYS := 8
const CLING_WALL_MASK := 1
const SLAM_RAMP := 4.0
const SLAM_RADIUS := 9.0
const SLAM_KNOCK := 26.0
const SLOPE_CONVERT := 0.55


static func apply(kit, state, tuning, intent, aim: Basis, body_state) -> void:
	if kit == null:
		return
	var step: float = body_state.step
	kit.tick_timers(step)
	_dash(kit, state, tuning, intent, aim, body_state)
	_cling(kit, state, tuning, intent, body_state, step)
	_slam(kit, state, tuning, intent, body_state, step)
	_glide(kit, state, tuning, intent, aim, body_state, step)
	_grapple(kit, tuning, intent, body_state, step)


# Airborne Shift belongs to the dash while it is fitted; on the ground Shift is still
# the boost, and the boost rule must not also fire or the two would stack.
static func claims_boost(kit, state) -> bool:
	return kit != null and kit.on(DASH) and not state.grounded


static func attach(kit, from: Vector3, point: Vector3) -> void:
	kit.hooked = true
	kit.anchor = point
	kit.rope = maxf(MIN_ROPE, from.distance_to(point))


static func _dash(kit, state, tuning, intent, aim: Basis, body_state) -> void:
	if state.grounded:
		kit.dash_ready = true
		return
	if not kit.on(DASH) or not intent.boost_pressed or not kit.dash_ready:
		return
	# Shift is one charge: a ground boost spends the dash and the dash spends the
	# boost, so the same key never pays out twice inside one cooldown.
	if state.boost_cooldown > 0.0:
		return
	kit.dash_ready = false
	state.boost_cooldown = Tuning.BOOST_COOLDOWN
	body_state.linear_velocity += _flat_forward(aim, body_state.linear_velocity) * tuning.f("dash_impulse")


static func _glide(kit, state, tuning, intent, aim: Basis, body_state, step: float) -> void:
	var v: Vector3 = body_state.linear_velocity
	kit.gliding = kit.on(GLIDE) and intent.jump_held and not state.grounded \
		and state.air_actions <= 0 and v.y < 0.0 and not kit.slamming and not kit.clinging
	if not kit.gliding:
		return
	# The engine has already pulled a full step of gravity into the velocity, so hand
	# part of it back instead of fighting it with an opposing force.
	v.y += tuning.f("gravity") * (1.0 - tuning.f("glide_gravity")) * step
	var trade: float = maxf(0.0, -v.y) * clampf(tuning.f("glide_lift") * step, 0.0, 1.0)
	v.y += trade
	v += _flat_forward(aim, v) * trade
	body_state.linear_velocity = v


static func _slam(kit, state, tuning, intent, body_state, step: float) -> void:
	var v: Vector3 = body_state.linear_velocity
	if kit.slamming:
		if state.grounded:
			kit.slamming = false
			kit.slam_landed = kit.slam_fall
			var n: Vector3 = state.contact_normal
			var along: Vector3 = Vector3.DOWN - n * Vector3.DOWN.dot(n)
			if along.length() > 0.05:
				# A slam into a slope should spend itself along the slope rather than
				# die against it, so a slammed landing exits faster than it arrived.
				body_state.linear_velocity = v + along.normalized() * kit.slam_fall * SLOPE_CONVERT
			return
		kit.slam_fall = maxf(0.0, -v.y)
		v.y = move_toward(v.y, -tuning.f("slam_speed"), tuning.f("slam_speed") * SLAM_RAMP * step)
		body_state.linear_velocity = v
		return
	if kit.on(SLAM) and intent.brake_held and not state.grounded and not kit.clinging:
		kit.slamming = true
		kit.slam_fall = maxf(0.0, -v.y)


static func _cling(kit, state, tuning, intent, body_state, step: float) -> void:
	if not kit.on(CLING) or not intent.cling_held or state.grounded or kit.cling_block > 0.0:
		kit.clinging = false
		return
	var face := _steepest_face(body_state)
	if face.is_empty():
		kit.clinging = false
		return
	kit.clinging = true
	kit.cling_normal = face["normal"]
	var n: Vector3 = kit.cling_normal
	var v: Vector3 = body_state.linear_velocity
	# The magnet carries most of the weight; what is left is the slide along the face.
	v.y += tuning.f("gravity") * tuning.f("cling_strength") * step
	v -= n * (v.dot(n) + CLING_GRIP * step)
	if state.jump_buffer > 0.0:
		state.jump_buffer = 0.0
		state.coyote = 0.0
		kit.clinging = false
		kit.cling_block = CLING_COOLDOWN
		v += (n + Vector3.UP * 0.65).normalized() * tuning.f("jump_speed")
	body_state.linear_velocity = v


static func _grapple(kit, tuning, intent, body_state, step: float) -> void:
	if not kit.hooked:
		return
	if not kit.on(GRAPPLE):
		kit.hooked = false
		return
	if intent.reel_held:
		kit.rope = maxf(MIN_ROPE, kit.rope - tuning.f("reel_speed") * step)
	var to_anchor: Vector3 = kit.anchor - body_state.transform.origin
	var dist := to_anchor.length()
	if dist < 0.001 or dist <= kit.rope:
		return
	var dir: Vector3 = to_anchor / dist
	var v: Vector3 = body_state.linear_velocity
	# A rope does not stretch: cancelling only the outward component leaves the
	# tangential speed alone, which is what turns a fall into a pendulum.
	var outward := -v.dot(dir)
	if outward > 0.0:
		v += dir * outward
	v += dir * (dist - kit.rope) * tuning.f("rope_spring")
	body_state.linear_velocity = v


static func _steepest_face(body_state) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = body_state.get_space_state()
	var origin: Vector3 = body_state.transform.origin
	var reach: float = Tuning.RADIUS + CLING_REACH
	var best := {}
	var flattest := 2.0
	for i in CLING_RAYS:
		var angle := TAU * float(i) / float(CLING_RAYS)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var hit: Dictionary = space.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, CLING_WALL_MASK))
		if hit.is_empty():
			continue
		var tilt: float = absf((hit["normal"] as Vector3).y)
		if tilt >= CLING_MAX_TILT or tilt >= flattest:
			continue
		flattest = tilt
		best = {"normal": hit["normal"], "point": hit["position"]}
	return best


static func _flat_forward(aim: Basis, velocity: Vector3) -> Vector3:
	var dir: Vector3 = -aim.z
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		return dir.normalized()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	return flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
