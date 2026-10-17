extends SceneTree
# Physics check for camp_skee_lane.glb, outside the game project so nothing imports: rolls a 1 m-radius ball with
# rigid_ball.gd's mass, friction, bounce and damping (Jolt, 90 ticks) up the lane at a sweep of speeds and lateral offsets
# and reports where each roll ends. PASS needs every roll from 11 to 18 m/s to end in a cup or at the return within 12 s,
# and no roll to come to rest anywhere else (on the board, in the trough, in the gutter).
#   $GODOT_BIN --headless --path scripts/cloud/skee_lab -s lab.gd -- "$PWD/sketches/core-loop/assets/models/camp/camp_skee_lane.glb"
var cups := {}
var start := Vector3.ZERO
var ret := Vector3.ZERO
var results := []
var queue := []
var ball: RigidBody3D
var t := 0.0
var cur := {}

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
	print("collision meshes ", col_count, " cups ", cups.keys())
	var speeds := [9.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.5, 18.0, 20.0]
	var xs := [-1.5, 0.0, 1.5]
	if args.size() > 1 and args[1] == "fine":   # optional second argument: a denser sweep for tuning
		speeds = []
		for i in range(19):
			speeds.append(9.0 + 0.5 * i)
		xs = [-1.5, -0.75, 0.0, 0.75, 1.5]
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
			if r.speed >= 11.0 and r.speed <= 18.0 and not r.ok:
				fails += 1
		print("cups reached: ", seen.keys().size(), " ", seen.keys())
		print("SKEE_LAB %s: %d of %d rolls in the 11-18 m/s band failed" % ["PASS" if fails == 0 else "FAIL", fails, results.size()])
		quit(1 if fails else 0)
		return
	cur = queue.pop_front()
	rest_t = 0.0
	ball = RigidBody3D.new()
	ball.mass = 6.0
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
	ball.position = start + Vector3(cur.x, 0.15, 2.0)
	ball.linear_velocity = Vector3(0, 0, -cur.speed)
	ball.angular_velocity = Vector3(-cur.speed, 0, 0)
	t = 0.0

# Cup opening radii (m), copied from skee.py's CUPS table (the header documents them): a roll counts as "in a cup" only when the
# ball centre is within that radius of the cup axis and below the board surface. The cup node sits at the floor centre, the
# board surface is DEPTH along the board normal above it, and the board is inclined 35 degrees.
const RADII := {"cup_10": 2.0, "cup_20": 1.4, "cup_30": 1.3, "cup_40": 1.3, "cup_50": 1.25, "cup_100_l": 1.25, "cup_100_r": 1.25}
const DEPTH := 1.5
const TILT := 35.0
const REST_SPEED := 0.3
const REST_TIME := 0.6
var rest_t := 0.0

func _which(p: Vector3) -> String:
	var n := Vector3(0, cos(deg_to_rad(TILT)), sin(deg_to_rad(TILT)))
	for k in cups:
		var c: Vector3 = cups[k].position
		var d := p - c
		var h := d.dot(n)
		var lateral := (d - n * h).length()
		if lateral < RADII[k] and h < DEPTH:
			return k
	return "stuck"

func _physics_process(delta: float) -> bool:
	if ball == null or not is_instance_valid(ball):
		return false
	t += delta
	var p := ball.position
	var home: bool = Vector2(p.x - ret.x, p.z - ret.z).length() < 3.0 and p.x > 3.0 and p.y < 2.4   # in the gutter, not on the lane or board
	# Rest means sustained: a ball turning round at the top of a rise is not stuck.
	if int(t*90)%30==0 and cur.speed==16.0 and cur.x==-1.5 and t>99.0: print('T ',snappedf(t,0.1),p,ball.linear_velocity,ball.angular_velocity)
	rest_t = rest_t + delta if ball.linear_velocity.length() < REST_SPEED else 0.0
	if t > 0.5 and (rest_t >= REST_TIME or t > 12.0 or home):
		var where := _which(p)
		if home:
			where = "return"
		var ok := where != "stuck"
		results.append({"speed": cur.speed, "ok": ok, "where": where,
			"line": "v=%5.1f x=%4.1f  -> %-10s at (%.1f, %.1f, %.1f) t=%.1f" % [cur.speed, cur.x, where, p.x, p.y, p.z, t]})
		_next()
	return false
