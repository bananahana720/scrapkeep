extends RefCounted

const Tuning := preload("res://src/movement/tuning.gd")
const Rules := preload("res://src/movement/ball_rules.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

# One row per augment. The HUD list and the kit's enabled flags read this table. A class
# fits only its movement ability's augments (AbilityState.ABILITIES, `augments`); the
# smash is everyone's. Jump, double jump and boost are base rules, not augments. The
# shared air dash is gone: its redirect lives in each class's movement ability. Upgrade
# knobs are read from kit.knob() at the point of use.
const GRAPPLE := "grapple"
const PYLON := "pylon"
const VAULT := "vault"
const SPRINT := "sprint"
const BLINK := "blink"
const GLIDE := "glide"
const CLAW_PULL := "claw_pull"
const SURGE := "surge"
const RECOIL := "recoil"
const SLAM := "slam"

const SPECS := [
	{"key": GRAPPLE, "label": "Grapple", "hint": "RMB fires and holds the line · release lets go · Ctrl hauls"},
	{"key": PYLON, "label": "Pylon", "hint": "E near a steep face or a close wall hook; hold Space to slingshot"},
	{"key": VAULT, "label": "Vault kick", "hint": "Space in the air at a steep face"},
	{"key": SPRINT, "label": "Overdrive sprint", "hint": "hold Shift; crowd control slides off"},
	{"key": BLINK, "label": "Smoke blink", "hint": "Shift; 8 m through your own smoke"},
	{"key": GLIDE, "label": "Glide", "hint": "hold Space falling, after the air jump"},
	{"key": CLAW_PULL, "label": "Claw pull", "hint": "Shift; a planted claw pulls you along the aim"},
	{"key": SURGE, "label": "Flywheel surge", "hint": "Shift; steam surges you along your travel"},
	{"key": RECOIL, "label": "Recoil split", "hint": "Shift; fire behind you and ride the kick"},
	{"key": SLAM, "label": "Smash", "hint": "Ctrl while airborne; plants on flat, launches on slopes"},
]
const SHARED := [SLAM]
# A kit fitted with no class is the engineer's, the first class row.
const DEFAULT_MOVEMENT := "grapple"

# What the grapple would catch right now. The HUD reticle, the world marker and the
# fire action all read the one record grapple_target() returns, so they cannot differ.
const AIM_NONE := 0
const AIM_REACH := 1
const AIM_ASSIST := 2
# The harpoon's: an enemy under the centre ray or inside the soft-lock cone.
const AIM_BODY := 3
const AIM_CAST := 90.0
const ASSIST_RINGS := [0.34, 0.67, 1.0]
const ASSIST_SPOKES := 16
const WORLD_MASK := 1
const STAKE_MASK := 128
const STAKE_GROUP := "sable_stake"

const MIN_ROPE := 2.5
# A body joins this group to be a harpoon anchor (PARK.md section 7): its line rides as a
# world line that follows it. Warden.setup adds an anchor Warden, Sable's stakes join it, and so
# does a world solid that moves (WORLD_ANCHOR_GROUP).
const ANCHOR_GROUP := "harpoon_anchor"
# A moving world solid (the Hanging Isle's tip, isle_rig.gd): any hook ray or assist that lands on
# it bites the body, so the line rides the moving point; it is no enemy and links no chain.
const WORLD_ANCHOR_GROUP := "world_anchor"
# How long a right-mouse reel onto a body still counts as a reel impact once the line lets go.
const REEL_GRACE := 0.2
# A harpoon line is idle, latched to a world point or a body, or committed to a smash
# haul on a body. SMASH_MAX bounds a haul; a line stretched past BREAK_STRETCH times the
# rope range lets go; ground under this normal.y is walkable and cannot be hooked.
const LINE_IDLE := 0
const LINE_LATCHED := 1
const LINE_SMASH := 2
const SMASH_MAX := 1.2
const BREAK_STRETCH := 1.5
# Poles (POLES-FLAILS section 4, start values): brace after two laps at cruise, snap after the
# creak, the outward kick, the hull clearance and the exit bonus on a let-go.
const POLE_BRACE := 1.6
const POLE_SNAP := 0.4
const POLE_KICK := 4.0
const POLE_CLEAR := 1.5
const POLE_EXIT := 0.15
const POLE_EXIT_SABLE := 0.25
# The speed soft cap (Andrew, 2026-10-17 07:17Z): a pole exit never pushes the ball past it.
const POLE_EXIT_CAP := 60.0
const WALKABLE_Y := 0.7
const FACE_REACH := 1.5
# sin 60 deg: the face leans less than 60 degrees off vertical, so a pylon can bite.
const FACE_MAX_TILT := 0.866
const FACE_RAYS := 8
const SLAM_RAMP := 4.0
const SLAM_RADIUS := 9.0
const SLAM_KNOCK := 26.0
# A ram at cruise or faster: a heavy push, heavier than any gun and level with a blast.
const RAM_KNOCK := 24.0
const PLANT_SPIN_DAMP := 0.5

const MOUNT_OFFSET := 2.2
const MOUNT_HOOK_REACH := 6.0
const MOUNT_COOLDOWN := 0.25
const MOUNT_REPEL_RADIUS := 8.0
const MOUNT_REPEL_KNOCK := 20.0

# The slingshot is a hold-gauge-release on Space while mounted: a tap is the old eject,
# a full gauge adds SLINGSHOT_FULL on top.
const SLINGSHOT_CHARGE := 0.8
const SLINGSHOT_FULL := 1.3
# Sable's vault kick: exit = incoming x VAULT_GAIN, never slower than a jump, capped;
# each face locks for VAULT_FACE_COOLDOWN so two faces cannot ping-pong the speed up.
# The untouched gain; Octave Kick raises it through the vault_gain knob.
const VAULT_GAIN := 1.8
# Pole Vault lets the kick find enemies (collision layer 3) as faces too.
const ENEMY_MASK := 4
const VAULT_CAP := 45.0
# Mass-S (--world-one-builds): q = clamp(mass / MASS_FULL, 0, 1) adds up to MASS_BONUS m/s to a
# slingshot, vault or Coil Hook launch, one shared grant per MASS_GAP seconds. LAUNCH_CEILING
# bounds generated launch speed only: at or above it the bonus is nothing and the speed stays.
const MASS_FULL := 990.0
const MASS_BONUS := 8.0
# Heft per mass is 1/450 (run_state.gd HEFT_PER_MASS), so mass is heft - 1 times this.
const MASS_HEFT_DIVISOR := 450.0
const MASS_GAP := 1.0
const LAUNCH_CEILING := 45.0
const VAULT_FACE_COOLDOWN := 1.5
# Rivet's sprint raises the drive's cruise target while it runs.
const SPRINT_CRUISE := 1.25
# Kest's blink: this far along the aim, stopping short of the world.
const BLINK_DISTANCE := 8.0
const BLINK_BACKOFF := 0.5
# Tarn's claw pull: Shift plants a claw up to CLAW_PULL_REACH along the aim and pulls the
# ball at CLAW_PULL_SCALE times the dash floor, always with a little lift, so it lands as a ram.
const CLAW_PULL_REACH := 12.0
const CLAW_PULL_SCALE := 1.5
const CLAW_PULL_LIFT := 2.0
# Tally's flywheel surge: Shift drives the ball along its travel (the aim when nearly still)
# at SURGE_SCALE times the dash floor, keeping a faster speed and the vertical velocity.
const SURGE_MIN_SPEED := 2.0
const SURGE_SCALE := 1.3
# The remembered cannon's recoil: Shift fires behind and kicks the ball along the aim at
# RECOIL_SCALE times the dash floor (a faster speed is kept), never lower than RECOIL_LIFT up.
const RECOIL_SCALE := 1.3
const RECOIL_LIFT := 1.5
# Rivet's skid turns the slam's fall into forward speed instead of a plant; Bulldozer
# raises the share through the skid_keep knob.
const SKID_KEEP := 0.6


static func apply(kit, state, tuning, intent, aim: Basis, body_state) -> void:
	if kit == null:
		return
	var step: float = body_state.step
	kit.tick_timers(step)
	_sprint(kit, state, tuning, intent, aim, body_state, step)
	# The kick's aim is this tick's answer or none: a mount or a held plant returns before _vault
	# runs, and the last tick's record would keep the kick's mark drawn where no kick is on offer.
	kit.vault_aim = {}
	if _mount(kit, state, tuning, intent, aim, body_state, step):
		_keep_body_line(kit, tuning, body_state)
		return
	if _hold_plant(kit, state, intent, body_state, step):
		return
	_vault(kit, state, tuning, aim, body_state)
	_blink(kit, tuning, intent, aim, body_state)
	_claw_pull(kit, tuning, intent, aim, body_state)
	_surge(kit, tuning, intent, aim, body_state)
	_recoil(kit, tuning, intent, aim, body_state)
	_slam(kit, state, tuning, intent, body_state, step)
	if kit.plant_time > 0.0:
		return
	_glide(kit, state, tuning, intent, aim, body_state, step)
	_grapple(kit, tuning, intent, body_state, step)


# While the ball is planted by a slam or mounted on a pylon, drive, boost and jump
# stand down; the kit reads their intent and hands it back on release.
static func holding(kit) -> bool:
	return kit != null and (kit.mounted or kit.plant_time > 0.0)


# The mass bonus a launch at this speed could take right now; spends nothing. Zero with the
# verb off, while the shared grant is cooling, or at or above the ceiling.
static func mass_room(kit, speed: float) -> float:
	if kit == null or not kit.mass_on or kit.mass_gap > 0.0:
		return 0.0
	return minf(MASS_BONUS * kit.mass_q, maxf(0.0, LAUNCH_CEILING - speed))


# The bonus a launch takes: mass_room, and the one shared grant starts cooling only when
# something was granted, so a launch above the ceiling leaves the budget whole.
static func mass_spend(kit, speed: float) -> float:
	var add := mass_room(kit, speed)
	if add > 0.0:
		kit.mass_gap = MASS_GAP
	return add


# The vault kick's exit speed for an incoming speed; the cap holds whatever the gain.
static func vault_exit(incoming: float, jump_speed: float, gain := VAULT_GAIN) -> float:
	return minf(VAULT_CAP, maxf(jump_speed, incoming * gain))


# A face is its plane: the normal to about 17 degrees and the offset to 3 m, so a long
# wall is one face wherever you kick it and the two sides of a gap are two faces.
static func face_key(point: Vector3, normal: Vector3) -> String:
	var n := normal.normalized()
	return "%d,%d,%d:%d" % [roundi(n.x / 0.3), roundi(n.y / 0.3), roundi(n.z / 0.3), roundi(n.dot(point) / 3.0)]


# Sable's vault kick. In the air at a steep face that is not locked, Space kicks off it
# along the slingshot's eject line. kit.vault_aim is the aim cone's record, set on every
# tick a kick is available, so the drawn cone and the kick read one answer.
static func _vault(kit, state, tuning, aim: Basis, body_state) -> void:
	if not kit.on(VAULT) or state.grounded or kit.hooked:
		return
	var mask := WORLD_MASK | (ENEMY_MASK if kit.knob("vault_enemies") else 0)
	var face := _steepest_face(body_state, mask)
	if face.is_empty():
		return
	var key := face_key(face["point"], face["normal"])
	if kit.vault_faces.get(key, 0.0) > 0.0:
		return
	var incoming: float = body_state.linear_velocity.length()
	var dir := eject_direction(face["normal"], aim)
	var speed := vault_exit(incoming, tuning.f("jump_speed"), kit.knob("vault_gain"))
	# Mass-S: the cap never takes speed the ball arrived with, and the bonus rides on top.
	if kit.mass_on:
		speed = maxf(speed, incoming)
	kit.vault_aim = {"point": face["point"], "normal": face["normal"], "dir": dir, "speed": speed + mass_room(kit, speed)}
	if state.jump_buffer <= 0.0:
		return
	state.jump_buffer = 0.0
	state.coyote = 0.0
	speed += mass_spend(kit, speed)
	body_state.linear_velocity = dir * speed
	kit.vault_faces[key] = kit.knob("vault_lock")
	kit.last_vault_face = key
	if kit.knob("vault_air"):
		state.air_actions = 1
	kit.facts.append(["vault_kicked", [face["point"], speed]])
	kit.facts.append(["dashed", [dir]])


# Rivet's overdrive sprint: Shift held spends a charge and runs up to its duration, or
# until released. Its kick and its facts point along the roll (the aim when still). While it runs the drive aims past cruise and crowd control slides off
# (player_ball.crowd_control reads kit.sprinting).
static func _sprint(kit, state, tuning, intent, aim: Basis, body_state, step: float) -> void:
	if not kit.on(SPRINT):
		kit.sprinting = false
		state.cruise_boost = 1.0
		return
	var slot = kit.abilities.slot(AbilityState.MOVEMENT)
	if kit.sprinting:
		# Run and Gun drains slower while firing; Perpetual Motion not at all while fast.
		var drain: float = kit.knob("sprint_fire_drain") if intent.fire_held else 1.0
		if kit.knob("sprint_perpetual") and state.tier >= SpeedTier.FAST:
			drain = 0.0
		kit.sprint_left -= step * drain
		if kit.sprint_left <= 0.0 or not intent.movement_held:
			kit.sprinting = false
		elif not state.grounded and kit.knob("sprint_float") < 1.0:
			var v: Vector3 = body_state.linear_velocity
			v.y += tuning.f("gravity") * (1.0 - kit.knob("sprint_float")) * step
			body_state.linear_velocity = v
	elif intent.movement_pressed and kit.abilities.spend(AbilityState.MOVEMENT):
		kit.sprinting = true
		kit.sprint_left = slot.duration
		var v: Vector3 = body_state.linear_velocity
		var flat := Vector3(v.x, 0.0, v.z)
		var dir := flat.normalized() if flat.length_squared() > 0.0001 else _flat_forward(aim, v)
		if kit.knob("sprint_kick") > 0.0:
			body_state.linear_velocity += dir * kit.knob("sprint_kick")
		kit.facts.append(["sprint_started", [dir]])
		kit.facts.append(["dashed", [dir]])
	slot.active = kit.sprinting
	state.cruise_boost = SPRINT_CRUISE if kit.sprinting else 1.0


# Kest's smoke blink: Shift moves the ball BLINK_DISTANCE along the aim, stopping short of
# the world, and turns its planar speed onto the aim, never slower than the dash
# impulse. A fall is caught; a climb is kept. Dash Vane reaches further.
static func _blink(kit, tuning, intent, aim: Basis, body_state) -> void:
	if not kit.on(BLINK) or not intent.movement_pressed:
		return
	# Shadow Step: a blink out of the cloak is free.
	if not (kit.cloaked and kit.knob("cloak_free_blink")) and not kit.abilities.spend(AbilityState.MOVEMENT):
		return
	var v: Vector3 = body_state.linear_velocity
	var dir := _flat_forward(aim, v)
	var from: Vector3 = body_state.transform.origin
	var lift := Vector3.UP * 0.3
	var reach: float = BLINK_DISTANCE * tuning.mod("dash_impulse")
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS * 0.95
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, from + lift)
	query.motion = dir * reach
	query.collision_mask = WORLD_MASK
	var safe: PackedFloat32Array = body_state.get_space_state().cast_motion(query)
	var travel := reach * (safe[0] if safe.size() > 0 else 1.0)
	var to := from + lift + dir * _blink_clear(body_state.get_space_state(), query, dir, travel)
	body_state.transform = Transform3D(body_state.transform.basis, to)
	var speed := maxf(Vector2(v.x, v.z).length(), tuning.f("dash_impulse"))
	body_state.linear_velocity = Vector3(dir.x * speed, maxf(v.y, 0.0), dir.z * speed)
	kit.facts.append(["blink_used", [from, to]])
	kit.facts.append(["dashed", [dir]])


# The blink passes through enemies but never lands inside a static one: a boss part on the
# enemy layer (boss_target.gd, an AnimatableBody3D hull) would depenetrate the ball through a
# thin floor under it (Brindle's bowl). The landing backs off along the path in BLINK_BACKOFF
# steps until it overlaps none. Enemies proper (CharacterBody3D) are landed on as before.
static func _blink_clear(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D, dir: Vector3, travel: float) -> float:
	var start: Vector3 = query.transform.origin
	query.motion = Vector3.ZERO
	query.collision_mask = ENEMY_MASK
	var at := travel
	while at > 0.0:
		query.transform.origin = start + dir * at
		var solid := false
		for hit in space.intersect_shape(query, 8):
			if hit["collider"] is StaticBody3D:
				solid = true
				break
		if not solid:
			return at
		at -= BLINK_BACKOFF
	return 0.0


# Tarn's claw pull: Shift plants a claw where the aim meets the world within
# CLAW_PULL_REACH (or reaches along the flat aim) and pulls the ball toward it.
static func _claw_pull(kit, tuning, intent, aim: Basis, body_state) -> void:
	if not kit.on(CLAW_PULL) or not intent.movement_pressed:
		return
	if not kit.abilities.spend(AbilityState.MOVEMENT):
		return
	var v: Vector3 = body_state.linear_velocity
	var dir := _flat_forward(aim, v)
	var from: Vector3 = body_state.transform.origin
	var pull := dir
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * CLAW_PULL_REACH, WORLD_MASK)
	var hit: Dictionary = body_state.get_space_state().intersect_ray(query)
	if not hit.is_empty():
		var to_plant: Vector3 = (hit["position"] as Vector3) - from
		if to_plant.length_squared() > 0.0001:
			pull = to_plant.normalized()
	var speed := maxf(Vector2(v.x, v.z).length(), tuning.f("dash_impulse") * CLAW_PULL_SCALE)
	var velocity := pull * speed
	velocity.y = maxf(pull.y * speed, CLAW_PULL_LIFT)
	body_state.linear_velocity = velocity
	kit.facts.append(["dashed", [dir]])


static func _surge(kit, tuning, intent, aim: Basis, body_state) -> void:
	if not kit.on(SURGE) or not intent.movement_pressed:
		return
	if not kit.abilities.spend(AbilityState.MOVEMENT):
		return
	var v: Vector3 = body_state.linear_velocity
	var planar := Vector2(v.x, v.z).length()
	var dir := Vector3(v.x, 0.0, v.z) / planar if planar > SURGE_MIN_SPEED else _flat_forward(aim, v)
	var speed := maxf(planar, tuning.f("dash_impulse") * SURGE_SCALE)
	body_state.linear_velocity = Vector3(dir.x * speed, v.y, dir.z * speed)
	kit.facts.append(["dashed", [dir]])


static func _recoil(kit, tuning, intent, aim: Basis, body_state) -> void:
	if not kit.on(RECOIL) or not intent.movement_pressed:
		return
	if not kit.abilities.spend(AbilityState.MOVEMENT):
		return
	var v: Vector3 = body_state.linear_velocity
	var dir := _flat_forward(aim, v)
	var speed := maxf(Vector2(v.x, v.z).length(), tuning.f("dash_impulse") * RECOIL_SCALE)
	body_state.linear_velocity = Vector3(dir.x * speed, maxf(v.y, RECOIL_LIFT), dir.z * speed)
	kit.facts.append(["dashed", [dir]])


static func attach(kit, from: Vector3, point: Vector3, normal := Vector3.ZERO, body: Node3D = null) -> void:
	kit.hooked = true
	kit.anchor = point
	kit.anchor_normal = normal
	kit.on_body = body != null
	kit.anchor_body = body
	kit.anchor_offset = point - body.global_position if body != null else Vector3.ZERO
	# A Warden line rides from the hardpoint the bite takes (PARK.md section 7; warden.gd
	# anchor_point); the offset keeps the bite, so a committed haul still homes where it bit (_follow).
	var floor_rope := MIN_ROPE
	if anchor_line(body):
		kit.anchor = body.anchor_point(point, from)
		floor_rope = Tuning.ANCHOR_MIN_ROPE
	kit.rope = maxf(floor_rope, from.distance_to(kit.anchor))
	kit.line_state = LINE_LATCHED
	kit.smash_left = 0.0
	kit.slamming = false


# Ctrl on a body line: the haul homes on the body at no less than the speed it starts at.
# On an anchor line it commits only while the anchor is staggered: at the Warden the haul is
# the drop finisher, never a bowl hammer (principle 23, PARK.md section 7). Outside a
# stagger the press does nothing and the line holds.
static func commit_smash(kit, tuning, velocity: Vector3) -> void:
	if not haul_open(kit):
		return
	kit.line_state = LINE_SMASH
	kit.smash_left = SMASH_MAX
	kit.smash_floor = maxf(velocity.length(), tuning.f("harpoon_smash_speed"))
	kit.slamming = false


# The body a committed haul is landing on, or null: the one body whose contact pays the landing.
static func landing_body(kit):
	if kit == null or not kit.hooked or kit.line_state != LINE_SMASH or not is_instance_valid(kit.anchor_body):
		return null
	return kit.anchor_body


# Whether Ctrl may commit the haul on the line now: always on an enemy line, only inside the
# stagger on an anchor line, never on a flail line (the flail hangs behind the ball; its slam is
# a later unit, POLES-FLAILS section 5).
static func haul_open(kit) -> bool:
	if kit.grip == "flail":
		return false
	var body = kit.anchor_body
	return not (kit.on_body and anchor_line(body)) or (body.has_method("staggered") and body.staggered())


static func no_aim() -> Dictionary:
	return {"state": AIM_NONE, "point": Vector3.ZERO, "normal": Vector3.ZERO}


# The hook is electromagnetic: if the crosshair ray misses, it finds the nearest
# hookable surface inside a small cone around it. Range is the rope's, measured from
# the ball rather than from the camera behind it. The harpoon widens the centre ray to
# `mask` (world and enemies) and turns walkable ground away; the assist stays on world
# surfaces, so an enemy is only ever a skill shot or a lock.
static func grapple_target(space: PhysicsDirectSpaceState3D, from: Vector3, forward: Vector3,
		ball: Vector3, reach: float, assist_deg: float, mask := WORLD_MASK, walkable := true) -> Dictionary:
	forward = forward.normalized()
	var centre := _hook_ray(space, from, forward, ball, reach, mask, walkable)
	if not centre.is_empty():
		var body = centre["collider"]
		if mask != WORLD_MASK and body is Node3D and (body.is_in_group("enemy") or body.is_in_group(STAKE_GROUP)):
			return {"state": AIM_BODY, "point": centre["position"], "normal": centre["normal"], "body": body}
		return _world_aim(AIM_REACH, centre)
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
			var hit := _hook_ray(space, from, dir, ball, reach, WORLD_MASK, walkable)
			if hit.is_empty():
				continue
			var gap: float = (hit["position"] as Vector3).distance_to(ball)
			if gap < nearest:
				nearest = gap
				best = hit
		if not best.is_empty():
			return _world_aim(AIM_ASSIST, best)
	return no_aim()


# A world hit's aim record; one on a moving world solid carries it as the body the line rides.
static func _world_aim(state: int, hit: Dictionary) -> Dictionary:
	var out := {"state": state, "point": hit["position"], "normal": hit["normal"]}
	var body = hit.get("collider")
	if body is Node3D and body.is_in_group(WORLD_ANCHOR_GROUP):
		out["body"] = body
	return out


# An enemy the line can bite: alive, in the enemy group, and on the enemy layer so the ball can touch it.
static func hookable_body(body) -> bool:
	return body is CollisionObject3D and body.is_in_group("enemy") and (body.collision_layer & ENEMY_MASK) != 0 \
		and not (body.has_method("is_dead") and body.is_dead())


static func _hook_ray(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3,
		ball: Vector3, reach: float, mask := WORLD_MASK, walkable := true) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * AIM_CAST, mask)
	var skipped: Array[RID] = []
	var hit := {}
	# The camera sits behind the ball: an enemy between the two is not ahead of the ball,
	# so the ray looks past it.
	for i in 3:
		query.exclude = skipped
		hit = space.intersect_ray(query)
		if hit.is_empty() or mask == WORLD_MASK:
			break
		var behind: bool = ((hit["position"] as Vector3) - ball).dot(dir) <= 0.0
		if not (behind and hookable_body(hit["collider"])):
			break
		skipped.append(hit["rid"])
		hit = {}
	if hit.is_empty() or (hit["position"] as Vector3).distance_to(ball) > reach:
		return {}
	if hit["collider"] is Node3D and (hit["collider"] as Node3D).is_in_group("enemy"):
		return hit if hookable_body(hit["collider"]) else {}
	if not walkable and (hit["normal"] as Vector3).y > WALKABLE_Y and not (hit["collider"] as Node3D).is_in_group(STAKE_GROUP):
		return {}
	return hit


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
	# Brake and slam share a key, so only a press that begins in the air slams. A brake
	# held from the ground stays a brake over a bump until it is released: a slam there
	# would plant the ball, a stop the player did not ask for.
	if not intent.brake_held:
		kit.brake_from_ground = false
	elif state.grounded:
		kit.brake_from_ground = true
	if kit.on(SLAM) and intent.brake_held and not state.grounded and not kit.brake_from_ground \
			and not kit.hooked:
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
	if kit.smash_flavour == "skid":
		_skid(kit, n, hit, into, body_state)


# Rivet's shockwave skid: no plant. The fall goes forward along the ground, so a slam
# costs Rivet no time at all; the push ahead is the ball's (player_ball._on_slammed).
static func _skid(kit, n: Vector3, hit: Vector3, into: float, body_state) -> void:
	var along := hit - n * into
	var forward := Vector3(along.x, 0.0, along.z)
	if forward.length_squared() < 0.01:
		forward = Vector3(-body_state.transform.basis.z.x, 0.0, -body_state.transform.basis.z.z)
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	forward = (forward - n * forward.dot(n)).normalized()
	var speed: float = along.length() + maxf(0.0, -into) * kit.knob("skid_keep")
	kit.plant_time = 0.0
	kit.plant_total = 0.0
	kit.plant_exit = forward * speed
	body_state.linear_velocity = kit.plant_exit


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
static func _mount(kit, state, tuning, intent, aim: Basis, body_state, step: float) -> bool:
	if kit.mounted:
		var gauge = kit.slingshot
		if not kit.on(PYLON):
			kit.mounted = false
			gauge.cancel()
			return false
		if intent.mount_pressed:
			if gauge.cancel():
				kit.facts.append(["gauge_cancelled", ["slingshot", "dropped"]])
			_dismount(kit, Vector3.ZERO)
			body_state.linear_velocity = Vector3.ZERO
			return false
		if intent.cancel_pressed and gauge.cancel():
			kit.facts.append(["gauge_cancelled", ["slingshot", "cancel"]])
		if not gauge.charging and state.jump_buffer > 0.0:
			state.jump_buffer = 0.0
			state.coyote = 0.0
			gauge.begin()
			kit.facts.append(["gauge_charging", ["slingshot"]])
		if gauge.step(step, intent.jump_held):
			var launch := _slingshot(kit, tuning, aim, gauge.fired_fraction)
			if kit.mass_on:
				launch += launch.normalized() * mass_spend(kit, launch.length())
			_dismount(kit, launch)
			kit.facts.append(["gauge_released", ["slingshot", gauge.fired_fraction]])
			body_state.linear_velocity = kit.dismount_velocity
			return false
		kit.slingshot_aim = {"dir": mount_exit_direction(kit.mount_normal, aim),
			"speed": _slingshot_shown(kit, tuning, aim, gauge.fraction()), "fill": gauge.fraction()}
		_pin(body_state, kit.mount_point)
		return true
	if not kit.on(PYLON) or not intent.mount_pressed or kit.mount_block > 0.0:
		return false
	# A committed smash haul owns the ball until it lands: mounted, the haul would freeze
	# (apply returns before _grapple) and then overwrite the slingshot's launch.
	if kit.line_state == LINE_SMASH:
		return false
	var spot := _mount_spot(kit, body_state)
	if spot.is_empty():
		return false
	kit.mounted = true
	kit.mount_banked = body_state.linear_velocity.length()
	# Pylon Relay: a plant made while winching banks more.
	if kit.hooked and kit.winching:
		kit.mount_banked *= kit.knob("winch_bank")
	kit.mount_face = spot["point"]
	kit.mount_normal = spot["normal"]
	kit.mount_point = kit.mount_face + kit.mount_normal * MOUNT_OFFSET
	kit.mount_planted = true
	kit.slamming = false
	kit.plant_time = 0.0
	kit.gliding = false
	kit.sprinting = false
	state.air_actions = 1
	_pin(body_state, kit.mount_point)
	return true


static func _dismount(kit, velocity: Vector3) -> void:
	kit.mounted = false
	kit.mount_block = MOUNT_COOLDOWN
	kit.dismount_velocity = velocity
	kit.dismount_fired = true


# The eject runs along the face toward where you are looking, tipped off the wall and
# up, at the banked speed plus a boost; never slower than a plain jump off the face. A
# tap is exactly that; the gauge adds up to SLINGSHOT_FULL on top.
static func _slingshot(kit, tuning, aim: Basis, fraction := 0.0) -> Vector3:
	var speed := maxf(tuning.f("jump_speed"), kit.mount_banked * tuning.f("slingshot_keep") + tuning.f("slingshot_boost"))
	speed *= AbilityState.Gauge.scaled(fraction, 1.0, SLINGSHOT_FULL)
	return mount_exit_direction(kit.mount_normal, aim) * speed


# The speed the aim cone shows: the launch's, mass bonus included, spending nothing.
static func _slingshot_shown(kit, tuning, aim: Basis, fraction: float) -> float:
	var speed := _slingshot(kit, tuning, aim, fraction).length()
	return speed + mass_room(kit, speed)


# The one eject line off a face, shared by the slingshot and the vault kick: along the
# face toward the look, tipped off the wall and up.
static func eject_direction(normal: Vector3, aim: Basis) -> Vector3:
	var n := normal.normalized()
	var look: Vector3 = -aim.z
	var along := look - n * look.dot(n)
	if along.length_squared() > 0.01:
		return (along.normalized() * 0.8 + n * 0.6 + Vector3.UP * 0.35).normalized()
	return (n + Vector3.UP * 0.65).normalized()


static func _mount_spot(kit, body_state) -> Dictionary:
	return mount_face(kit, body_state.get_space_state(), body_state.transform.origin)


# The pylon's one test of where it would plant from `origin`: the steepest face within the ball's
# reach, or the wall the hook is in when the ball is close to it, both scaled by the mount_reach
# knob (Sable's depth-1 upgrade doubles it). {point, normal}, or {} when there is nowhere to plant.
# The mount and the ball's reading of E (player_ball.face_in_reach) ask this one test, so a press the
# pylon takes is never also refused.
static func mount_face(kit, space: PhysicsDirectSpaceState3D, origin: Vector3) -> Dictionary:
	var reach_scale: float = kit.knob("mount_reach")
	var face := _steepest_face_at(space, origin, WORLD_MASK, reach_scale)
	if not face.is_empty():
		return face
	if kit.hooked and kit.on(GRAPPLE) and not kit.on_body and absf(kit.anchor_normal.y) < FACE_MAX_TILT \
			and kit.anchor_normal != Vector3.ZERO \
			and origin.distance_to(kit.anchor) <= MOUNT_HOOK_REACH * reach_scale:
		return {"point": kit.anchor, "normal": kit.anchor_normal.normalized()}
	return {}


static func _pin(body_state, at: Vector3) -> void:
	body_state.transform = Transform3D(body_state.transform.basis, at)
	body_state.linear_velocity = Vector3.ZERO
	body_state.angular_velocity *= PLANT_SPIN_DAMP


# A mounted ball skips the grapple rule, but a line on a body still follows it and lets go
# when it dies; there is no swing, spring or winch while mounted.
static func _keep_body_line(kit, tuning, body_state) -> void:
	if kit.hooked and kit.on_body and kit.on(GRAPPLE):
		_follow(kit, tuning, body_state.transform.origin)


static func _grapple(kit, tuning, intent, body_state, step: float) -> void:
	if not kit.hooked:
		return
	var origin: Vector3 = body_state.transform.origin
	if kit.on_body:
		if not _follow(kit, tuning, origin):
			return
		if kit.line_state == LINE_SMASH:
			_haul(kit, tuning, intent, body_state, step)
		elif anchor_line(kit.anchor_body):
			_ride_anchor(kit, tuning, intent, body_state, step)
		elif pole_line(kit):
			_ride_pole(kit, tuning, intent, body_state, step)
		elif intent.harpoon_held and kit.grip != "flail":
			_winch_body(kit, tuning, body_state, step)
			# Only this haul onto a bitten body is a reel for the dunk (ruling bf); an anchor or
			# pole ride that reels to its floor rope is not.
			kit.reel_body = kit.anchor_body
			kit.reel_left = REEL_GRACE
		return
	var to_anchor: Vector3 = kit.anchor - origin
	var dist := to_anchor.length()
	if dist < 0.001:
		return
	var dir: Vector3 = to_anchor / dist
	var v: Vector3 = body_state.linear_velocity
	if kit.winching:
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


# A Warden is a harpoon anchor (PARK.md section 7): its line is a world line whose anchor
# moves with the body. Only a body in ANCHOR_GROUP is one; the authored boss arenas' Wardens
# never join it.
static func anchor_line(body) -> bool:
	return is_instance_valid(body) and body.is_in_group(ANCHOR_GROUP)


# A latched Warden line rides as a world line (_grapple's rope below): right mouse held
# winches it down to ANCHOR_MIN_ROPE, where the ball hangs or orbits, and the rope cancels the
# ball's outward speed measured against the moving anchor, so a moving mounting drags the
# ball on the rope's tension. The keyboard holds the harpoon for as long as the line stands.
static func _ride_anchor(kit, tuning, intent, body_state, step: float) -> void:
	_ride(kit, tuning, intent, body_state, step, kit.anchor_body.anchor_velocity(), Tuning.ANCHOR_MIN_ROPE)


# A pole (POLES-FLAILS section 4): a bitten enemy heavier than the ball rides as an anchor line
# on the body's own velocity, held off its hull at pole_rope. Unlike a Warden anchor the smash
# stays open (haul_open). After POLE_BRACE the body braces; POLE_SNAP later it snaps the line
# and kicks the ball outward at POLE_KICK.
static func _ride_pole(kit, tuning, intent, body_state, step: float) -> void:
	var body = kit.anchor_body
	kit.pole_time += step
	if kit.pole_time >= POLE_BRACE + POLE_SNAP:
		var away: Vector3 = body_state.transform.origin - body.global_position
		if away.length() > 0.01:
			body_state.linear_velocity += away.normalized() * POLE_KICK
		kit.drop_line("brace")
		return
	var carried: Vector3 = body.velocity if body is CharacterBody3D else Vector3.ZERO
	_ride(kit, tuning, intent, body_state, step, carried, pole_rope(body))


static func pole_line(kit) -> bool:
	return kit.on_body and kit.grip == "pole" and kit.line_state == LINE_LATCHED and not anchor_line(kit.anchor_body)


# The let-go velocity off a pole: `share` of the speed across the line added along it, capped
# at POLE_EXIT_CAP unless the ball was already faster.
static func pole_exit(v: Vector3, to_body: Vector3, share: float) -> Vector3:
	var across := v - to_body * v.dot(to_body)
	var out := v + across * share
	if out.length() > POLE_EXIT_CAP:
		out = out.normalized() * maxf(v.length(), POLE_EXIT_CAP)
	return out


static func pole_bracing(kit) -> bool:
	return pole_line(kit) and kit.pole_time >= POLE_BRACE


# The orbit radius: ANCHOR_MIN_ROPE, or clear of a wide hull.
static func pole_rope(body) -> float:
	var r = body.get("radius")
	return maxf(Tuning.ANCHOR_MIN_ROPE, (float(r) if r != null else 0.0) + Tuning.RADIUS + POLE_CLEAR)


static func _ride(kit, tuning, intent, body_state, step: float, carried: Vector3, floor_rope: float) -> void:
	var to_anchor: Vector3 = kit.anchor - body_state.transform.origin
	var dist := to_anchor.length()
	if dist < 0.001:
		return
	var dir := to_anchor / dist
	if intent.harpoon_held:
		_winch_body(kit, tuning, body_state, step, floor_rope)
		_arrive(kit, tuning, body_state, dir, dist, carried, floor_rope)
	if dist <= kit.rope:
		return
	var v: Vector3 = body_state.linear_velocity
	var outward := -(v - carried).dot(dir)
	if outward > 0.0:
		v += dir * outward
	v += dir * (dist - kit.rope) * tuning.f("rope_spring")
	body_state.linear_velocity = v


# The held winch brings the ball to ANCHOR_MIN_ROPE at rest along the line: its closing speed
# on the anchor is capped at what the winch's own pull could stop in the length left, so the
# reel ends hanging or orbiting there instead of carrying the reel speed into the body.
# Speed across the line is untouched, which is what keeps the orbit.
static func _arrive(kit, tuning, body_state, dir: Vector3, dist: float, carried: Vector3, floor_rope := Tuning.ANCHOR_MIN_ROPE) -> void:
	var v: Vector3 = body_state.linear_velocity
	var closing := (v - carried).dot(dir)
	var cap := sqrt(2.0 * tuning.f("reel_force") * maxf(0.0, dist - floor_rope))
	if closing > cap:
		body_state.linear_velocity = v - dir * (closing - cap)


# Moves the anchor with the body. The line lets go, keeping the ball's velocity, when
# the body is gone, stretched past BREAK_STRETCH ranges, or (latched only) passed inside
# the minimum rope and both radii, measured centre to centre whatever point the bite stored:
# an enemy line has no pendulum to dead-stop on. A Warden line has one (anchor_line), so
# it holds there and the ball orbits or hangs.
static func _follow(kit, tuning, origin: Vector3) -> bool:
	var body = kit.anchor_body
	if not is_instance_valid(body) or not body.is_inside_tree() or (body.has_method("is_dead") and body.is_dead()):
		kit.drop_line("body_died")
		return false
	kit.anchor = body.global_position + kit.anchor_offset
	if kit.line_state == LINE_LATCHED and anchor_line(body):
		kit.anchor = body.anchor_point(kit.anchor)
	var dist := origin.distance_to(kit.anchor)
	if dist > BREAK_STRETCH * tuning.f("rope_range"):
		kit.drop_line("out_of_reach")
		return false
	if kit.line_state == LINE_LATCHED and not anchor_line(body) and not kit.grip in ["pole", "flail"]:
		var radius = body.get("radius")
		var centre_dist := origin.distance_to(body.global_position)
		if centre_dist <= MIN_ROPE + Tuning.RADIUS + (float(radius) if radius != null else 0.0):
			kit.drop_line("passed")
			return false
	return true


# Right mouse held on a latched body line reels the ball in. The line only pulls the ball.
# `stop` is the length the pull stops at (an anchor line's ANCHOR_MIN_ROPE); an enemy line
# passes none and drops in _follow before it would matter.
static func _winch_body(kit, tuning, body_state, step: float, stop := 0.0) -> void:
	var to_anchor: Vector3 = kit.anchor - body_state.transform.origin
	var dist := to_anchor.length()
	if dist < 0.001:
		return
	var dir := to_anchor / dist
	var v: Vector3 = body_state.linear_velocity
	var head := clampf(1.0 - v.dot(dir) / tuning.f("reel_speed"), 0.0, 1.0)
	if dist > stop:
		v += dir * tuning.f("reel_force") * head * step
	kit.rope = maxf(maxf(MIN_ROPE, stop), minf(kit.rope, dist))
	body_state.linear_velocity = v


# The committed haul homes on the body and never slows the ball. A jump, boost or dash
# lets the line go; so does running out of SMASH_MAX. Contact is the ball's, which
# releases the line before the landing resolves (player_ball._land_harpoon).
static func _haul(kit, tuning, intent, body_state, step: float) -> void:
	kit.smash_left -= step
	if kit.smash_left <= 0.0:
		kit.drop_line("timeout")
		return
	if intent.jump_pressed or intent.boost_pressed or intent.movement_pressed:
		kit.drop_line()
		return
	var to_anchor: Vector3 = kit.anchor - body_state.transform.origin
	var dist := to_anchor.length()
	if dist < 0.001:
		return
	var dir := to_anchor / dist
	var v: Vector3 = body_state.linear_velocity
	var speed := maxf(v.length(), kit.smash_floor)
	v = dir * speed
	kit.rope = minf(kit.rope, dist)
	kit.line_closing = speed
	body_state.linear_velocity = v


static func _steepest_face(body_state, mask := WORLD_MASK, reach_scale := 1.0) -> Dictionary:
	return _steepest_face_at(body_state.get_space_state(), body_state.transform.origin, mask, reach_scale)


static func _steepest_face_at(space: PhysicsDirectSpaceState3D, origin: Vector3, mask := WORLD_MASK, reach_scale := 1.0) -> Dictionary:
	var reach: float = Tuning.RADIUS + FACE_REACH * reach_scale
	var best := {}
	var flattest := 2.0
	for i in FACE_RAYS:
		var angle := TAU * float(i) / float(FACE_RAYS)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var hit: Dictionary = space.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, mask))
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


# PC-SABLE: one preview and exit calculation, without spending the shared Mass-S grant.
static func bank_exit(v_in: float, anchor_to_ball: Vector3, aim: Basis, kit) -> Vector3:
	var speed := maxf(v_in, minf(LAUNCH_CEILING, maxf(v_in, 13.0) * 1.25 + 4.0))
	return eject_direction(anchor_to_ball, aim) * (speed + mass_room(kit, speed))


static func mount_exit_direction(normal: Vector3, aim: Basis) -> Vector3:
	if normal.y < WALKABLE_Y:
		return eject_direction(normal, aim)
	var flat := Vector3(-aim.z.x, 0.0, -aim.z.z)
	flat = flat.normalized() if flat.length_squared() > 0.001 else Vector3.FORWARD
	return flat * cos(deg_to_rad(12.0)) + Vector3.UP * sin(deg_to_rad(12.0))


static func mount_outpost(kit, state, at: Vector3, normal: Vector3, speed: float) -> void:
	kit.mounted = true
	kit.mount_banked = speed
	kit.mount_normal = normal
	kit.mount_face = at
	kit.mount_point = at + normal * MOUNT_OFFSET
	kit.mount_planted = false
	kit.slamming = false
	kit.plant_time = 0.0
	kit.gliding = false
	kit.sprinting = false
	state.air_actions = 1
