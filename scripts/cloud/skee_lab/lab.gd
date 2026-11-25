extends SceneTree
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
const GRAVITY := 26.0
const ROLLING_RESISTANCE := 0.30
const MAX_SLOPE_DOT := 0.45
const QUAD_DRAG := 0.0045
const FAST_SPEED := 14.0 * 1.15
const CRUISE := 14.0
const DRIVE_ACCEL := 34.0
const RIGID_TORQUE := 220.0
const AIR_CONTROL := 0.25
var lip_z := INF
var released := false
const BOOST_IMPULSE := 11.0
const BOOST_COOLDOWN := 1.1
var boost_cd := 0.0
var boost_fired := false
const TIME_LIMIT := 60.0
const MIN_CUPS := 3
const HOME_R := 1.0
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
		elif String(n.name) == "lip":
			lip_z = (n as Node3D).position.z
	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	gs.shape = WorldBoundaryShape3D.new()
	ground.add_child(gs)
	root.add_child(ground)
	print("collision meshes ", col_count, " cups ", cups.keys(), " return_exit ", ret)
	assert(ret.z > 0.0 and ret.z < 3.5, "return_exit must sit beside the lane's foot")
	assert(lip_z != INF, "the lane needs a lip socket: forward is held until the ball passes it")
	probe = ShapeCast3D.new()
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
	if args.size() > 1 and args[1] == "fine":
		speeds = []
		for i in range(19):
			speeds.append(9.0 + 0.5 * i)
		xs = [-1.5, -0.75, 0.0, 0.75, 1.5]
	lo_speed = speeds.min()
	hi_speed = speeds.max()
	for speed in speeds:
		for x in xs:
			for boost in [false, true]:
				queue.append({"speed": speed, "x": x, "boost": boost})
	_next()

func _next() -> void:
	if ball:
		ball.queue_free()
		ball = null
	if queue.is_empty():
		var fails := 0
		var seen := {}
		var seen_set := {false: {}, true: {}}
		for r in results:
			print(r.line)
			if r.where.begins_with("cup_"):
				seen[r.where] = true
				seen_set[r.boost][r.where] = true
			if not r.ok:
				fails += 1
		var keys := seen.keys()
		keys.sort()
		var enough: bool = keys.size() >= MIN_CUPS
		for b in [false, true]:
			var ks: Array = seen_set[b].keys()
			ks.sort()
			print("cups reached, %s: %s" % ["boost held" if b else "forward held", ks])
		print("cups reached: ", keys.size(), " ", keys)
		var pass_all: bool = fails == 0 and enough
		print("SKEE_LAB %s: %d of %d rolls (%.0f-%.0f m/s, every roll gated) failed; %d distinct cups reached (need %d)" % [
			"PASS" if pass_all else "FAIL", fails, results.size(), lo_speed, hi_speed, keys.size(), MIN_CUPS])
		quit(0 if pass_all else 1)
		return
	cur = queue.pop_front()
	rest_t = 0.0
	released = false
	boost_cd = 0.0
	boost_fired = false
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
	ball.position = start + Vector3(cur.x, 0.0, 2.0)
	ball.linear_velocity = Vector3(0, 0, -cur.speed)
	ball.angular_velocity = Vector3(-cur.speed, 0, 0)
	t = 0.0

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
	var normal := Vector3.UP
	for i in probe.get_collision_count():
		var n := probe.get_collision_normal(i)
		if n.y > best:
			best = n.y
			normal = n
	var grounded := best > MAX_SLOPE_DOT
	var v := ball.linear_velocity
	var speed := v.length()
	if not released and lip_z != INF and p.z < lip_z:
		released = true
	if not released and ball.is_inside_tree():
		var wish := Vector3(0, 0, -1)
		if grounded:
			wish = wish - normal * wish.dot(normal)
			wish = wish.normalized() if wish.length_squared() >= 0.0001 else Vector3.ZERO
		if wish != Vector3.ZERO:
			var head := clampf(1.0 - v.dot(wish) / CRUISE, 0.0, 1.0) * (1.0 if grounded else AIR_CONTROL)
			ball.apply_torque(Vector3.UP.cross(wish) * RIGID_TORQUE * head)
			ball.apply_central_force(wish * DRIVE_ACCEL * 0.3 * ball.mass * head)
	boost_cd = maxf(0.0, boost_cd - delta)
	if cur.boost and not released and not boost_fired and boost_cd <= 0.0 and ball.is_inside_tree():
		var bdir := v.normalized() if speed > 2.5 else Vector3(0, 0, -1)
		ball.apply_central_impulse(bdir * BOOST_IMPULSE * ball.mass)
		boost_cd = BOOST_COOLDOWN
		boost_fired = true
	if speed > 1e-3 and ball.is_inside_tree():
		if grounded:
			ball.apply_central_force(-v / speed * ROLLING_RESISTANCE * ball.mass)
		elif speed > FAST_SPEED:
			var loss := QUAD_DRAG * (speed - FAST_SPEED) * (speed - FAST_SPEED) * delta
			ball.apply_central_impulse(-v / speed * minf(speed, loss) * ball.mass)
	var home: bool = Vector2(p.x - ret.x, p.z - ret.z).length() < HOME_R and absf(p.y - ret.y) < HOME_DY
	rest_t = rest_t + delta if ball.linear_velocity.length() < REST_SPEED else 0.0
	var where := _which(p)
	var cup := where != "stuck"
	if t > 0.5 and (home or (cup and rest_t >= REST_TIME) or (not cup and rest_t >= STUCK_TIME) or t > TIME_LIMIT):
		if home:
			where = "return"
		elif not cup and rest_t < REST_TIME:
			where = "rolling"
		var ok := where != "stuck" and where != "rolling"
		results.append({"speed": cur.speed, "ok": ok, "where": where, "boost": cur.boost,
			"line": "%s v=%5.1f x=%4.1f  -> %-10s at (%.1f, %.1f, %.1f) t=%.1f" % [
				"boost  " if cur.boost else "forward", cur.speed, cur.x, where, p.x, p.y, p.z, t]})
		_next()
	return false
