extends SceneTree
# Physics check for camp_skee_lane.glb, outside the game project so nothing imports: rolls the game's ball up the lane at a
# sweep of speeds and lateral offsets and reports where each roll ends. The ball mirrors rigid_ball.gd with no input held
# (steering, drive torque, brake, boost, jump and the augment kit are input or kit actions and are left out):
#   - body: mass 6, sphere radius 1 (Tuning.RADIUS), friction 0.9, bounce 0.25, continuous CD, never sleeps (setup)
#   - damping: linear_damp 0 and angular_damp 0.25, both DAMP_MODE_REPLACE (setup)
#   - gravity: gravity_scale = tuning gravity 26 / 9.8, so the ball falls at 26 m/s^2 (_integrate_forces)
#   - grounded: rigid_ball's ground probe (ball_rules.gd make_probe/probe_ground: a 0.92 m sphere cast 0.26 m straight down,
#     grounded when the best contact normal has y above Tuning.MAX_SLOPE_DOT 0.45)
#   - grounded: rolling resistance, a force of rolling_resistance 0.30 * mass against the velocity (_integrate_forces)
#   - airborne: over-speed drag (ball_rules.gd over_speed_drag), an impulse of mass * min(speed, QUAD_DRAG 0.0045 *
#     (speed - cruise 14 * SpeedTier FAST 1.15)^2 * step) against the velocity, above 16.1 m/s only
#   - start: linear velocity v up the lane with the matching roll spin, as set_velocity_now hands it over (roll_axis)
# The ball has no downforce, ground speed cap or ground drag: rigid_ball.gd applies none (Rules.stick and Rules.resistance
# belong to the kinematic ball). external_accel is the flood's push and is zero in camp.
# A roll is "return" only when the ball centre reaches the return_exit socket beside the lane's foot (within HOME_R across,
# HOME_DY in height). The lane stands on a ground plane at y 0, and each roll starts on that ground 2 m in front of the foot.
# PASS needs every roll in the sweep (9 to 20 m/s) to end in a cup or at the return within TIME_LIMIT s, and at least
# MIN_CUPS distinct cups reached; a roll that comes to rest anywhere else (STUCK_TIME), or is still rolling at the limit, fails.
#   $GODOT_BIN --headless --path scripts/cloud/skee_lab -s lab.gd -- "$PWD/sketches/core-loop/assets/models/camp/camp_skee_lane.glb"
var cups := {}
var start := Vector3.ZERO
var ret := Vector3.ZERO
var results := []
var queue := []
var ball: RigidBody3D
var t := 0.0
var cur := {}
var probe: ShapeCast3D
var lo_speed := 0.0
var hi_speed := 0.0
const GRAVITY := 26.0              # tuning.gd "gravity"
const ROLLING_RESISTANCE := 0.30   # tuning.gd "rolling_resistance"
const MAX_SLOPE_DOT := 0.45        # tuning.gd Tuning.MAX_SLOPE_DOT
const QUAD_DRAG := 0.0045          # tuning.gd Tuning.QUAD_DRAG
const FAST_SPEED := 14.0 * 1.15    # tuning.gd "cruise" * speed_tier.gd MULTIPLES[FAST]
const TIME_LIMIT := 60.0
const MIN_CUPS := 3
const HOME_R := 1.0                # ball centre within this of return_exit (xz), and within HOME_DY in height
const HOME_DY := 0.6

func _initialize() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var args := OS.get_cmdline_user_args()
	var glb: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://../../../sketches/core-loop/assets/models/camp/camp_skee_lane.glb")
	var err := doc.append_from_file(glb, st)
	assert(err == OK)
	var scene: Node3D = doc.generate_scene(st)
	root.add_child(scene)
	var col_count := 0
	for n in scene.find_children("*", "", true, false):
		if n is MeshInstance3D and String(n.name).ends_with("-col-col"):
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			cs.shape = n.mesh.create_trimesh_shape()
			body.add_child(cs)
			n.add_child(body)
			col_count += 1
		elif n is Node3D and String(n.name).begins_with("cup_"):
			cups[String(n.name)] = n
		elif String(n.name) == "start":
			start = (n as Node3D).position
		elif String(n.name) == "return_exit":
			ret = (n as Node3D).position
	var ground := StaticBody3D.new()   # the camp ground the lane stands on (y 0)
	var gs := CollisionShape3D.new()
	gs.shape = WorldBoundaryShape3D.new()
	ground.add_child(gs)
	root.add_child(ground)
	print("collision meshes ", col_count, " cups ", cups.keys(), " return_exit ", ret)
	assert(ret.z > 0.0 and ret.z < 3.5, "return_exit must sit beside the lane's foot")
	probe = ShapeCast3D.new()   # ball_rules.gd make_probe
	var ps := SphereShape3D.new()
	ps.radius = 0.92
	probe.shape = ps
	probe.target_position = Vector3(0.0, -(0.08 + 0.12 + 0.06), 0.0)
	probe.max_results = 6
	probe.top_level = true
	probe.enabled = false
	root.add_child(probe)
	var speeds := [9.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.5, 18.0, 20.0]
	var xs := [-1.5, 0.0, 1.5]
	if args.size() > 1 and args[1] == "fine":   # optional second argument: a denser sweep for tuning
		speeds = []
		for i in range(19):
			speeds.append(9.0 + 0.5 * i)
		xs = [-1.5, -0.75, 0.0, 0.75, 1.5]
	lo_speed = speeds.min()
	hi_speed = speeds.max()
	for speed in speeds:
		for x in xs:
			queue.append({"speed": speed, "x": x})
	_next()

func _next() -> void:
	if ball:
		ball.queue_free()
		ball = null
	if queue.is_empty():
		var fails := 0
		var seen := {}
		for r in results:
			print(r.line)
			if r.where.begins_with("cup_"):
				seen[r.where] = true
			if not r.ok:
				fails += 1
		var keys := seen.keys()
		keys.sort()
		var enough: bool = keys.size() >= MIN_CUPS
		print("cups reached: ", keys.size(), " ", keys)
		var pass_all: bool = fails == 0 and enough
		print("SKEE_LAB %s: %d of %d rolls (%.0f-%.0f m/s, every roll gated) failed; %d distinct cups reached (need %d)" % [
			"PASS" if pass_all else "FAIL", fails, results.size(), lo_speed, hi_speed, keys.size(), MIN_CUPS])
		quit(0 if pass_all else 1)
		return
	cur = queue.pop_front()
	rest_t = 0.0
	ball = RigidBody3D.new()
	ball.mass = 6.0
	ball.gravity_scale = GRAVITY / 9.8
	ball.linear_damp = 0.0
	ball.continuous_cd = true
	ball.can_sleep = false
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp = 0.25
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.25
	ball.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.0
	cs.shape = sp
	ball.add_child(cs)
	root.add_child.call_deferred(ball)
	probe.clear_exceptions()
	probe.add_exception(ball)
	ball.position = start + Vector3(cur.x, 0.0, 2.0)   # on the ground 2 m in front of the foot
	ball.linear_velocity = Vector3(0, 0, -cur.speed)
	ball.angular_velocity = Vector3(-cur.speed, 0, 0)
	t = 0.0

# Cup opening radii (m), copied from skee.py's CUPS table (the header documents them): a roll counts as "in a cup" only when the
# ball centre is within that radius of the cup axis, below the board surface and above half a radius over the cup floor (a ball
# resting on the floor sits at 1.0; a ball under the board is not in a cup). The cup node sits at the floor centre, the board
# surface is DEPTH along the board normal above it, and the board is inclined 35 degrees.
const RADII := {"cup_10": 2.0, "cup_20": 1.4, "cup_30": 1.3, "cup_40": 1.3, "cup_50": 1.25, "cup_100_l": 1.25, "cup_100_r": 1.25}
const DEPTH := 1.5
const TILT := 35.0
const REST_SPEED := 0.3
const REST_TIME := 0.6
const STUCK_TIME := 3.0
var rest_t := 0.0

func _which(p: Vector3) -> String:
	var n := Vector3(0, cos(deg_to_rad(TILT)), sin(deg_to_rad(TILT)))
	for k in cups:
		var c: Vector3 = cups[k].position
		var d := p - c
		var h := d.dot(n)
		var lateral := (d - n * h).length()
		if lateral < RADII[k] and h < DEPTH and h > 0.5:
			return k
	return "stuck"

func _physics_process(delta: float) -> bool:
	if ball == null or not is_instance_valid(ball):
		return false
	t += delta
	var p := ball.position
	probe.global_transform = Transform3D(Basis.IDENTITY, p)
	probe.force_shapecast_update()
	var best := -1.0
	for i in probe.get_collision_count():
		best = maxf(best, probe.get_collision_normal(i).y)
	var v := ball.linear_velocity
	var speed := v.length()
	if speed > 1e-3 and ball.is_inside_tree():
		if best > MAX_SLOPE_DOT:
			ball.apply_central_force(-v / speed * ROLLING_RESISTANCE * ball.mass)
		elif speed > FAST_SPEED:
			var loss := QUAD_DRAG * (speed - FAST_SPEED) * (speed - FAST_SPEED) * delta
			ball.apply_central_impulse(-v / speed * minf(speed, loss) * ball.mass)
	var home: bool = Vector2(p.x - ret.x, p.z - ret.z).length() < HOME_R and absf(p.y - ret.y) < HOME_DY
	# Rest means sustained: a ball turning round at the top of a rise is not stuck. A ball at rest in a cup ends the roll after
	# REST_TIME; a ball at rest anywhere else ends it after STUCK_TIME (a fail); otherwise the roll runs to TIME_LIMIT.
	rest_t = rest_t + delta if ball.linear_velocity.length() < REST_SPEED else 0.0
	var where := _which(p)
	var cup := where != "stuck"
	if t > 0.5 and (home or (cup and rest_t >= REST_TIME) or (not cup and rest_t >= STUCK_TIME) or t > TIME_LIMIT):
		if home:
			where = "return"
		elif not cup and rest_t < REST_TIME:
			where = "rolling"   # still moving at the limit, not in a cup and not home
		var ok := where != "stuck" and where != "rolling"
		results.append({"speed": cur.speed, "ok": ok, "where": where,
			"line": "v=%5.1f x=%4.1f  -> %-10s at (%.1f, %.1f, %.1f) t=%.1f" % [cur.speed, cur.x, where, p.x, p.y, p.z, t]})
		_next()
	return false
