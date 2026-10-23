extends SceneTree
# Headless ball proof for a greybox glTF.
# Usage: godot --headless --script ball_proof.gd -- <spec.json>
# Spec (mojulo frame: metres, z up): { glb, start:[x,y,z], vel:[x,y,z], seconds,
#   pass: { exit_box?:[[x0,y0,z0],[x1,y1,z1]], stay_box?:[[..],[..]], min_peak_z?, reach_box?:[[..],[..]] } }
# Prints one JSON line per 0.25 s and a final verdict line starting with "VERDICT ".

const HZ := 240

var spec: Dictionary
var ball: RigidBody3D
var tick := 0
var ready_done := false
var peak_z := -1e9
var left_stay_at := -1.0
var reached_at := -1.0
var exited_at := -1.0
var avoided_hit := ""
var trace: Array = []


func to_godot(p: Array) -> Vector3:
	return Vector3(float(p[0]), float(p[2]), -float(p[1]))


func to_moj(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(-v.z, 0.01), snappedf(v.y, 0.01)]


func in_box(p: Array, box: Array) -> bool:
	for i in 3:
		if p[i] < float(box[0][i]) or p[i] > float(box[1][i]):
			return false
	return true


func _initialize() -> void:
	Engine.physics_ticks_per_second = HZ
	Engine.max_physics_steps_per_frame = 64
	PhysicsServer3D.area_set_param(root.get_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, 26.0)
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.READ)
	spec = JSON.parse_string(f.get_as_text())
	_setup()


func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D and n.mesh:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)


func _setup() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(String(spec.glb), st)
	if err != OK:
		print("VERDICT {\"pass\": false, \"why\": \"import error %d\"}" % err)
		quit(2)
		return
	var scene: Node = doc.generate_scene(st)
	root.add_child(scene)
	await process_frame
	var ms := []
	_meshes(scene, ms)
	var body := StaticBody3D.new()
	root.add_child(body)
	var tris := 0
	var bb := AABB()
	for m in ms:
		var cs := CollisionShape3D.new()
		cs.shape = m.mesh.create_trimesh_shape()
		body.add_child(cs)
		cs.global_transform = m.global_transform
		tris += (cs.shape as ConcavePolygonShape3D).get_faces().size() / 3
		var mb: AABB = m.global_transform * m.mesh.get_aabb()
		bb = mb if bb.size == Vector3.ZERO else bb.merge(mb)
	print(JSON.stringify({"triangles": tris, "aabb_min_moj": to_moj(bb.position + Vector3(0, 0, bb.size.z)),
		"aabb_size_m": [snappedf(bb.size.x, 0.01), snappedf(bb.size.z, 0.01), snappedf(bb.size.y, 0.01)]}))
	ball = RigidBody3D.new()
	ball.continuous_cd = true
	ball.mass = 1.0
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp = 0.0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.6
	mat.bounce = 0.05
	ball.physics_material_override = mat
	var bcs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.92
	bcs.shape = sp
	ball.add_child(bcs)
	root.add_child(ball)
	ball.global_position = to_godot(spec.start)
	ball.linear_velocity = to_godot(spec.vel)
	# Rolling, not sliding, at the entry speed.
	var v: Vector3 = ball.linear_velocity
	ball.angular_velocity = Vector3.UP.cross(Vector3(v.x, 0, v.z)) / 0.92
	ready_done = true


func _physics_process(_d: float) -> bool:
	if not ready_done:
		return false
	tick += 1
	var t := float(tick) / HZ
	var p := to_moj(ball.global_position)
	peak_z = maxf(peak_z, p[2])
	var pass_spec: Dictionary = spec.get("pass", {})
	if pass_spec.has("stay_box") and left_stay_at < 0 and exited_at < 0 and not in_box(p, pass_spec.stay_box):
		left_stay_at = t
	if pass_spec.has("reach_box") and reached_at < 0 and in_box(p, pass_spec.reach_box):
		reached_at = t
	if pass_spec.has("exit_box") and exited_at < 0 and in_box(p, pass_spec.exit_box):
		exited_at = t
	if pass_spec.has("avoid_boxes") and avoided_hit == "":
		for b in pass_spec.avoid_boxes:
			if in_box(p, b):
				avoided_hit = "entered avoid box %s at %.2fs" % [str(b), t]
	if tick % (HZ / 4) == 0:
		var row := {"t": snappedf(t, 0.01), "pos": p, "speed": snappedf(ball.linear_velocity.length(), 0.1)}
		trace.append(row)
		print(JSON.stringify(row))
	if t >= float(spec.seconds):
		var ok := true
		var why: Array = []
		if pass_spec.has("stay_box"):
			if left_stay_at >= 0:
				ok = false
				why.append("left stay_box at %.2fs" % left_stay_at)
		if pass_spec.has("reach_box"):
			if reached_at < 0:
				ok = false
				why.append("never reached reach_box")
		if pass_spec.has("exit_box"):
			if exited_at < 0:
				ok = false
				why.append("never reached exit_box")
		if avoided_hit != "":
			ok = false
			why.append(avoided_hit)
		if pass_spec.has("min_peak_z") and peak_z < float(pass_spec.min_peak_z):
			ok = false
			why.append("peak z %.2f below %.2f" % [peak_z, float(pass_spec.min_peak_z)])
		print("VERDICT " + JSON.stringify({"pass": ok, "why": why, "peak_z": snappedf(peak_z, 0.01),
			"reached_at": snappedf(reached_at, 0.01), "exited_at": snappedf(exited_at, 0.01),
			"left_stay_at": snappedf(left_stay_at, 0.01), "final": p}))
		return true
	return false
