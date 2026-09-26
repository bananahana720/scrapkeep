extends RefCounted

const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")

# One row per augment. The number keys, the HUD list and the kit's enabled flags all
# read this table, so a sixth augment is one row here plus its force function below.
const GRAPPLE := "grapple"
const DASH := "dash"
const GLIDE := "glide"
const SLAM := "slam"
const PYLON := "pylon"

const SPECS := [
	{"key": GRAPPLE, "label": "Grapple", "hint": "RMB fire/release · hold Q winches · wheel pays out"},
	{"key": DASH, "label": "Air dash", "hint": "Shift while airborne, refreshed on landing"},
	{"key": GLIDE, "label": "Glide", "hint": "hold Space falling, after the air jump"},
	{"key": SLAM, "label": "Slam", "hint": "Ctrl while airborne; plants on flat, launches on slopes"},
	{"key": PYLON, "label": "Pylon", "hint": "E near a steep face or a close wall hook"},
]

# What the grapple would catch right now. The HUD reticle, the world marker and the
# fire action all read the one record grapple_target() returns, so they cannot differ.
const AIM_NONE := 0
const AIM_REACH := 1
const AIM_ASSIST := 2
const AIM_CAST := 90.0
const ASSIST_RINGS := [0.34, 0.67, 1.0]
const ASSIST_SPOKES := 16
const WORLD_MASK := 1

const MIN_ROPE := 2.5
const FACE_REACH := 1.5
# sin 60 deg: the face leans less than 60 degrees off vertical, so a pylon can bite.
const FACE_MAX_TILT := 0.866
const FACE_RAYS := 8
const SLAM_RAMP := 4.0
const SLAM_RADIUS := 9.0
const SLAM_KNOCK := 26.0
const PLANT_SPIN_DAMP := 0.5

const MOUNT_OFFSET := 2.2
const MOUNT_HOOK_REACH := 6.0
const MOUNT_COOLDOWN := 0.25
const MOUNT_REPEL_RADIUS := 8.0
const MOUNT_REPEL_KNOCK := 20.0


static func apply(kit, state, tuning, intent, aim: Basis, body_state) -> void:
	if kit == null:
		return
	var step: float = body_state.step
	kit.tick_timers(step)
	if _mount(kit, state, tuning, intent, aim, body_state):
		return
	if _hold_plant(kit, state, intent, body_state, step):
		return
	_dash(kit, state, tuning, intent, aim, body_state)
	_slam(kit, state, tuning, intent, body_state, step)
	if kit.plant_time > 0.0:
		return
	_glide(kit, state, tuning, intent, aim, body_state, step)
	_grapple(kit, tuning, intent, body_state, step)


# While the ball is planted by a slam or mounted on a pylon, drive, boost and jump
# stand down; the kit reads their intent and hands it back on release.
static func holding(kit) -> bool:
	return kit != null and (kit.mounted or kit.plant_time > 0.0)


# Airborne Shift belongs to the dash while it is fitted; on the ground Shift is still
# the boost, and the boost rule must not also fire or the two would stack.
static func claims_boost(kit, state) -> bool:
	return kit != null and kit.on(DASH) and not state.grounded


static func attach(kit, from: Vector3, point: Vector3, normal := Vector3.ZERO) -> void:
	kit.hooked = true
	kit.anchor = point
	kit.anchor_normal = normal
	kit.rope = maxf(MIN_ROPE, from.distance_to(point))


static func no_aim() -> Dictionary:
	return {"state": AIM_NONE, "point": Vector3.ZERO, "normal": Vector3.ZERO}


# The hook is electromagnetic: if the crosshair ray misses, it finds the nearest
# hookable surface inside a small cone around it. Range is the rope's, measured from
# the ball rather than from the camera behind it.
static func grapple_target(space: PhysicsDirectSpaceState3D, from: Vector3, forward: Vector3,
		ball: Vector3, reach: float, assist_deg: float) -> Dictionary:
	forward = forward.normalized()
	var centre := _hook_ray(space, from, forward, ball, reach)
	if not centre.is_empty():
		return {"state": AIM_REACH, "point": centre["position"], "normal": centre["normal"]}
	if assist_deg <= 0.0:
		return no_aim()
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = forward.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(forward).normalized()
	# Rings run from the inside out, so the first ring that catches anything is the one
	# closest to where you were aiming; inside it the nearest surface wins.
	for ring in ASSIST_RINGS:
		var spread := tan(deg_to_rad(assist_deg * float(ring)))
		var best := {}
		var nearest := INF
		for i in ASSIST_SPOKES:
			var spin := TAU * float(i) / float(ASSIST_SPOKES)
			var dir := (forward + (side * cos(spin) + up * sin(spin)) * spread).normalized()
			var hit := _hook_ray(space, from, dir, ball, reach)
			if hit.is_empty():
				continue
			var gap: float = (hit["position"] as Vector3).distance_to(ball)
			if gap < nearest:
				nearest = gap
				best = hit
		if not best.is_empty():
			return {"state": AIM_ASSIST, "point": best["position"], "normal": best["normal"]}
	return no_aim()


static func _hook_ray(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3,
		ball: Vector3, reach: float) -> Dictionary:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * AIM_CAST, WORLD_MASK))
	if hit.is_empty() or (hit["position"] as Vector3).distance_to(ball) > reach:
		return {}
	return hit


static func _dash(kit, state, tuning, intent, aim: Basis, body_state) -> void:
	if state.grounded:
		kit.dash_ready = true
		return
	if not kit.on(DASH) or not intent.boost_pressed or not kit.dash_ready:
		return
	if tuning.on("split_dash_cooldown"):
		if kit.dash_cooldown > 0.0:
			return
		kit.dash_cooldown = tuning.boost_cooldown()
	else:
		# Shift is one charge: a ground boost spends the dash and the dash spends the
		# boost, so the same key never pays out twice inside one cooldown.
		if state.boost_cooldown > 0.0:
			return
		state.boost_cooldown = tuning.boost_cooldown()
	kit.dash_ready = false
	var dir := _flat_forward(aim, body_state.linear_velocity)
	body_state.linear_velocity += dir * tuning.f("dash_impulse")
	kit.dash_fired = dir


static func _glide(kit, state, tuning, intent, aim: Basis, body_state, step: float) -> void:
	var v: Vector3 = body_state.linear_velocity
	kit.gliding = kit.on(GLIDE) and intent.jump_held and not state.grounded \
		and state.air_actions <= 0 and v.y < 0.0 and not kit.slamming
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
			_plant(kit, state, tuning, body_state)
			_hold_plant(kit, state, intent, body_state, step)
			return
		# The contact has usually eaten the impact by the time the probe reports ground,
		# so the plant works from the last airborne velocity instead.
		kit.slam_fall = maxf(0.0, -v.y)
		v.y = move_toward(v.y, -tuning.f("slam_speed"), tuning.f("slam_speed") * SLAM_RAMP * step)
		kit.slam_velocity = v
		body_state.linear_velocity = v
		return
	if kit.on(SLAM) and intent.brake_held and not state.grounded:
		kit.slamming = true
		kit.slam_fall = maxf(0.0, -v.y)
		kit.slam_velocity = v


# One rule for every landing angle. Flatness f = (n . up)^k splits the slam: f of the
# anchor time is spent planted, and 1 - f of the impact leaves downhill afterwards.
# The exit is the impact's tangential part plus the stopped normal part redirected
# downhill by slam_downhill, so flat ground plants hard and exits at zero while a
# steep slope barely plants and throws you down it.
static func _plant(kit, state, tuning, body_state) -> void:
	var n: Vector3 = state.contact_normal
	var flat := pow(clampf(n.dot(Vector3.UP), 0.0, 1.0), tuning.f("slam_flat_exp"))
	var hit: Vector3 = kit.slam_velocity
	var into := hit.dot(n)
	var exit := hit - n * into
	var downhill := Vector3.DOWN - n * Vector3.DOWN.dot(n)
	if downhill.length_squared() > 0.000001:
		exit += downhill.normalized() * maxf(0.0, -into) * tuning.f("slam_downhill")
	kit.plant_exit = exit * (1.0 - flat)
	kit.plant_normal = n
	kit.plant_at = body_state.transform.origin
	kit.plant_time = tuning.f("slam_anchor_max") * flat
	kit.plant_total = kit.plant_time
	kit.plant_jump = false
	kit.plant_boost = false
	kit.slam_landed = kit.slam_fall
	kit.slam_flat = flat
	state.impact = maxf(state.impact, kit.slam_fall * flat)


# Never a stun: a jump or boost pressed while planted is held and fires the tick the
# plant lets go, and drive simply resumes then.
static func _hold_plant(kit, state, intent, body_state, step: float) -> bool:
	if kit.plant_time <= 0.0:
		return false
	if state.jump_buffer > 0.0:
		kit.plant_jump = true
		state.jump_buffer = 0.0
	if intent.boost_pressed:
		kit.plant_boost = true
	kit.plant_time -= step
	if kit.plant_time > 0.0:
		_pin(body_state, kit.plant_at)
		return true
	kit.plant_time = 0.0
	body_state.linear_velocity = kit.plant_exit
	var axis: Vector3 = Rules.roll_axis(kit.plant_exit, kit.plant_normal)
	body_state.angular_velocity = axis / Tuning.RADIUS if axis != Vector3.ZERO else Vector3.ZERO
	if kit.plant_jump:
		state.jump_buffer = Tuning.JUMP_BUFFER
	if kit.plant_boost:
		intent.boost_pressed = true
	return false


# The pylon: E near a steep face, or near the wall your hook is in, drives a post into
# the surface and holds the ball on its end. The plant banks the speed you arrived with;
# Space slingshots you off along the face with it, E drops you off where you are.
static func _mount(kit, state, tuning, intent, aim: Basis, body_state) -> bool:
	if kit.mounted:
		if not kit.on(PYLON):
			kit.mounted = false
			return false
		if state.jump_buffer > 0.0:
			state.jump_buffer = 0.0
			state.coyote = 0.0
			_dismount(kit, _slingshot(kit, tuning, aim))
			body_state.linear_velocity = kit.dismount_velocity
			return false
		if intent.mount_pressed:
			_dismount(kit, Vector3.ZERO)
			body_state.linear_velocity = Vector3.ZERO
			return false
		_pin(body_state, kit.mount_point)
		return true
	if not kit.on(PYLON) or not intent.mount_pressed or kit.mount_block > 0.0:
		return false
	var spot := _mount_spot(kit, body_state)
	if spot.is_empty():
		return false
	kit.mounted = true
	kit.mount_banked = body_state.linear_velocity.length()
	kit.mount_face = spot["point"]
	kit.mount_normal = spot["normal"]
	kit.mount_point = kit.mount_face + kit.mount_normal * MOUNT_OFFSET
	kit.mount_planted = true
	kit.slamming = false
	kit.plant_time = 0.0
	kit.gliding = false
	kit.dash_ready = true
	state.air_actions = 1
	_pin(body_state, kit.mount_point)
	return true


static func _dismount(kit, velocity: Vector3) -> void:
	kit.mounted = false
	kit.mount_block = MOUNT_COOLDOWN
	kit.dismount_velocity = velocity
	kit.dismount_fired = true


# The eject runs along the face toward where you are looking, tipped off the wall and
# up, at the banked speed plus a boost; never slower than a plain jump off the face.
static func _slingshot(kit, tuning, aim: Basis) -> Vector3:
	var n: Vector3 = kit.mount_normal
	var look: Vector3 = -aim.z
	var along := look - n * look.dot(n)
	var dir: Vector3
	if along.length_squared() > 0.01:
		dir = (along.normalized() * 0.8 + n * 0.6 + Vector3.UP * 0.35).normalized()
	else:
		dir = (n + Vector3.UP * 0.65).normalized()
	var speed := maxf(tuning.f("jump_speed"), kit.mount_banked * tuning.f("slingshot_keep") + tuning.f("slingshot_boost"))
	return dir * speed


static func _mount_spot(kit, body_state) -> Dictionary:
	var face := _steepest_face(body_state)
	if not face.is_empty():
		return face
	if kit.hooked and kit.on(GRAPPLE) and absf(kit.anchor_normal.y) < FACE_MAX_TILT \
			and kit.anchor_normal != Vector3.ZERO \
			and body_state.transform.origin.distance_to(kit.anchor) <= MOUNT_HOOK_REACH:
		return {"point": kit.anchor, "normal": kit.anchor_normal.normalized()}
	return {}


static func _pin(body_state, at: Vector3) -> void:
	body_state.transform = Transform3D(body_state.transform.basis, at)
	body_state.linear_velocity = Vector3.ZERO
	body_state.angular_velocity *= PLANT_SPIN_DAMP


static func _grapple(kit, tuning, intent, body_state, step: float) -> void:
	if not kit.hooked:
		return
	if not kit.on(GRAPPLE):
		kit.hooked = false
		return
	var to_anchor: Vector3 = kit.anchor - body_state.transform.origin
	var dist := to_anchor.length()
	if dist < 0.001:
		return
	var dir: Vector3 = to_anchor / dist
	var v: Vector3 = body_state.linear_velocity
	if intent.reel_held:
		# A winch, not a shorter maximum: it hauls whether or not the rope is taut, and
		# the rope follows you in so no slack builds up behind the haul.
		kit.rope = maxf(MIN_ROPE, minf(kit.rope, dist))
		var closing := v.dot(dir)
		var head := clampf(1.0 - closing / tuning.f("reel_speed"), 0.0, 1.0)
		if dist > MIN_ROPE:
			v += dir * tuning.f("reel_force") * head * step
	if dist > kit.rope:
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
	var reach: float = Tuning.RADIUS + FACE_REACH
	var best := {}
	var flattest := 2.0
	for i in FACE_RAYS:
		var angle := TAU * float(i) / float(FACE_RAYS)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var hit: Dictionary = space.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, WORLD_MASK))
		if hit.is_empty():
			continue
		var tilt: float = absf((hit["normal"] as Vector3).y)
		if tilt >= FACE_MAX_TILT or tilt >= flattest:
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
