extends SceneTree
# 2026-10-23 (Greybox lane): the five lab pockets Challenge's pocket-against-mobility sweeps load (board #241, Challenge
# option (a)). Lab-only geometry under tools/lab_pockets/, built by tools/lab_pockets/build.py from mojulo recipes.
# (a) Each <shape>.glb exists, imports at runtime, stays under 50k triangles, matches build.json, and ships nowhere: the
#     folder carries .gdignore and no registry file names it.
# (b) The half pipe's section is half_pipe_concrete's, measured on both models: crest to crest, wall over the floor, and
#     the floor's 3% fall, so a sweep in the lab and a ride in the park see the same channel.
# (c) Ride paths: the rail grove's rails keep their underside at least 3.52 m over the walkable floor (DECISIONS, map
#     design veto pass, 23 Oct). Chokes: the crevice's guide walls are slick (friction 0 in the lab scene).
# (d) Every proof in tools/lab_pockets/proofs.json: a 0.92 m ball under gravity 26, no damping, launched rolling at the
#     stated speed. Pass cases must pass and each control must fail, so a proof whose control passes decides nothing.
# Evidence limit: headless Jolt, a bare rigid ball and the trimesh only; no player controller, enemies, feel or look.

const T := preload("res://tests/support/t.gd")
const DIR := "res://tools/lab_pockets/"
const PARK_HALF_PIPE := "res://assets/models/park/half_pipe_concrete.glb"
const SHAPES := ["half_pipe", "rolling_wall", "crevice", "hazard_field", "rail_grove"]
const MAX_TRIS := 50000
const BALL_R := 0.92
const GRAVITY := 26.0
const SPACING := 1000.0
const SLOW_S := 0.5
const SECTION_TOL := 0.3
const GRADE_TOL := 0.003

var _t := T.new("lab_pockets_test")
var _proofs: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_proofs = JSON.parse_string(FileAccess.get_file_as_string(DIR + "proofs.json"))
	_check_files()
	await _check_half_pipe()
	_check_rules()
	await _check_rolls()
	quit(_t.verdict())


# mojulo's frame (x along travel, y lateral, z up) to Godot's; build.py keeps mojulo's root node, which does the same.
func _g(p: Array) -> Vector3:
	return Vector3(float(p[0]), float(p[2]), -float(p[1]))


func _m(v: Vector3) -> Vector3:
	return Vector3(v.x, -v.z, v.y)


func _load(name: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(DIR + name + ".glb", state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


func _meshes(node: Node) -> Array:
	var out: Array = []
	for child in node.find_children("*", "MeshInstance3D", true, false):
		out.append(child)
	return out


func _tris(scene: Node) -> int:
	var n := 0
	for mi in _meshes(scene):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			n += (idx.size() if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func _check_files() -> void:
	var build: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "build.json"))
	_t.check("(a) tools/lab_pockets carries .gdignore, so Godot neither imports nor exports it", FileAccess.file_exists(DIR + ".gdignore"))
	for name in SHAPES:
		var scene := _load(name)
		if not _t.check("(a) %s.glb imports" % name, scene != null):
			continue
		var tris := _tris(scene)
		_t.check("(a) %s has %d triangles, under %d" % [name, tris, MAX_TRIS], tris > 0 and tris < MAX_TRIS)
		_t.eq("(a) %s triangles match build.json" % name, tris, int(build.get(name, {}).get("triangles", -1)))
		_t.check("(a) %s has a recipe and proofs" % name, FileAccess.file_exists(DIR + "recipes/%s.json" % name) and _proofs["shapes"].has(name))
		scene.free()
	var named := []
	for path in ["res://assets/registry.json"] + Array(DirAccess.get_files_at("res://assets/registry.d")).map(func(f): return "res://assets/registry.d/" + f):
		if FileAccess.get_file_as_string(path).contains("lab_pockets"):
			named.append(path)
	_t.check("(a) no registry file names lab_pockets", named.is_empty(), str(named))


# Surface heights across the channel at one station, by ray, in the lab's own frame.
func _section(space: PhysicsDirectSpaceState3D, x: float, offset: Vector3) -> Dictionary:
	var heights := {}
	for i in range(-160, 161):
		var y := i * 0.1
		var from := offset + _g([x, y, 40.0])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -80, 0)))
		if not hit.is_empty():
			heights[snappedf(y, 0.1)] = hit["position"].y - offset.y
	return heights


func _collide(scene: Node3D, slick := false) -> void:
	for mi in _meshes(scene):
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = (mi as MeshInstance3D).mesh.create_trimesh_shape()
		body.add_child(shape)
		if slick and String(mi.name).begins_with("slick"):
			var mat := PhysicsMaterial.new()
			mat.friction = 0.0
			body.physics_material_override = mat
			body.set_meta("slick", true)
		(mi as Node3D).add_child(body)


func _check_half_pipe() -> void:
	var meta: Dictionary = _proofs["meta"]["half_pipe"]
	var lab := _load("half_pipe")
	var holder := Node3D.new()
	root.add_child(holder)
	var offset := Vector3(-5000, 0, 0)
	holder.add_child(lab)
	lab.position = offset
	_collide(lab)
	await physics_frame
	await physics_frame
	var space := (holder.get_world_3d() as World3D).direct_space_state
	var stations := {}
	for x in [8.0, 32.0, 56.0]:
		var h := _section(space, x, offset)
		var floor_h: float = h.get(0.0, NAN)
		var top := -1e9
		for y in h:
			top = maxf(top, h[y])
		var crest := 0.0
		for y in h:
			if h[y] >= top - 0.05 and absf(y) > crest and absf(y) < 15.0:
				crest = absf(y)
		var crest_in := 1e9
		for y in h:
			if h[y] >= top - 0.05:
				crest_in = minf(crest_in, absf(y))
		stations[x] = {"floor": floor_h, "wall": top - floor_h, "crest_half": crest_in}
	var mid: Dictionary = stations[32.0]
	_t.near("(b) lab half pipe wall over its floor (m)", mid["wall"], float(meta["wall_m"]), 0.15)
	_t.near("(b) lab half pipe crest half width (m)", mid["crest_half"], float(meta["crest_half_m"]), 0.15)
	var grade := (float(stations[8.0]["floor"]) - float(stations[56.0]["floor"])) / 48.0
	_t.near("(b) lab half pipe floor falls 3% along its length", grade, float(meta["grade"]), GRADE_TOL)
	holder.free()

	var park := (load(PARK_HALF_PIPE) as PackedScene).instantiate()
	var gl := park.find_child("gauge_l", true, false) as Node3D
	var gr := park.find_child("gauge_r", true, false) as Node3D
	var ex := park.find_child("socket_exit", true, false) as Node3D
	if _t.check("(b) the park half pipe names gauge_l, gauge_r and socket_exit", gl != null and gr != null and ex != null):
		root.add_child(park)
		var width := Vector2(gl.global_position.x - gr.global_position.x, gl.global_position.z - gr.global_position.z).length()
		var wall := gl.global_position.y - ex.global_position.y
		_t.near("(b) lab crest to crest matches the park's (m)", 2.0 * float(mid["crest_half"]), width, SECTION_TOL)
		_t.near("(b) lab wall matches the park's (m)", float(mid["wall"]), wall, SECTION_TOL)
		print("PARK_SECTION ", JSON.stringify({"park_width": width, "park_wall": wall, "lab_width": 2.0 * float(mid["crest_half"]), "lab_wall": mid["wall"], "lab_grade": grade}))
	park.free()


func _check_rules() -> void:
	var grove := _load("rail_grove")
	var lowest := 1e9
	var rails := 0
	for mi in _meshes(grove):
		if String(mi.name).begins_with("rail") and not String(mi.name).begins_with("rail_post"):
			rails += 1
			var xf := (mi as Node3D).global_transform if (mi as Node3D).is_inside_tree() else _xf(mi, grove)
			for v in (mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				lowest = minf(lowest, (xf * v).y)
	_t.check("(c) the rail grove has its rail mesh", rails > 0)
	var clear: float = _proofs["meta"]["ride_clear_m"]
	_t.check("(c) rail underside %.2f m over the floor, at least %.2f m" % [lowest, clear], lowest >= clear - 0.01)
	grove.free()
	var crevice := _load("crevice")
	var slick := _meshes(crevice).filter(func(mi): return String(mi.name).begins_with("slick"))
	_t.check("(c) the crevice's choke has slick guide walls", slick.size() >= 2, str(slick.map(func(mi): return String(mi.name))))
	crevice.free()


func _xf(node: Node, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return (top as Node3D).transform * xf


func _ball(parent: Node3D, at: Vector3, velocity: Vector3) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	ball.gravity_scale = GRAVITY / 9.8
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp = 0.0
	ball.continuous_cd = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_R
	shape.shape = sphere
	ball.add_child(shape)
	parent.add_child(ball)
	ball.global_position = at
	ball.linear_velocity = velocity
	# Launched already rolling, as the game's ball is at speed: spin with no slip at the contact.
	ball.angular_velocity = Vector3.UP.cross(velocity) / BALL_R
	return ball


func _inside(p: Vector3, b: Array) -> bool:
	return p.x >= b[0][0] and p.x <= b[1][0] and p.y >= b[0][1] and p.y <= b[1][1] and p.z >= b[0][2] and p.z <= b[1][2]


func _check_rolls() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var runs: Array = []
	var k := 0
	for name in SHAPES:
		for case in _proofs["shapes"][name]["cases"]:
			var c: Dictionary = _proofs["shapes"][name]["cases"][case]
			var scene := _load(name)
			var offset := Vector3(k * SPACING, 0, 0)
			parent.add_child(scene)
			scene.position = offset
			_collide(scene, true)
			runs.append({"shape": name, "case": case, "c": c, "offset": offset, "scene": scene, "frames": int(float(c["seconds"]) * Engine.physics_ticks_per_second),
				"why": [], "peak": -1e9, "slow": 0, "worst_slow": 0, "exited": false, "left": false, "hit_avoid": false})
			k += 1
	await physics_frame
	for run in runs:
		var c: Dictionary = run["c"]
		run["ball"] = _ball(parent, run["offset"] + _g(c["start"]), _g(c["vel"]))
	var longest := 0
	for run in runs:
		longest = maxi(longest, run["frames"])
	var tps := Engine.physics_ticks_per_second
	for f in longest:
		await physics_frame
		for run in runs:
			if f >= run["frames"]:
				continue
			var ball: RigidBody3D = run["ball"]
			var p := _m(ball.global_position - run["offset"])
			var c: Dictionary = run["c"]
			var rules: Dictionary = c["pass"]
			run["peak"] = maxf(run["peak"], p.z)
			if rules.has("exit_box") and _inside(p, rules["exit_box"]):
				run["exited"] = true
			if rules.has("stay_box") and not run["exited"] and not _inside(p, rules["stay_box"]):
				run["left"] = true
			for b in rules.get("avoid_boxes", []):
				if _inside(p, b):
					run["hit_avoid"] = true
			if c.has("min_speed") and not run["exited"]:
				if ball.linear_velocity.length() < float(c["min_speed"]):
					run["slow"] += 1
					run["worst_slow"] = maxi(run["worst_slow"], run["slow"])
				else:
					run["slow"] = 0
			run["last"] = p
	for run in runs:
		var c: Dictionary = run["c"]
		var rules: Dictionary = c["pass"]
		var why: Array = []
		if rules.has("exit_box") and not run["exited"]:
			why.append("never reached its exit")
		if run["left"]:
			why.append("left the pocket before its exit")
		if run["hit_avoid"]:
			why.append("entered a hazard")
		if rules.has("min_peak_z") and run["peak"] < float(rules["min_peak_z"]):
			why.append("peak %.2f m under %.2f m" % [run["peak"], float(rules["min_peak_z"])])
		if c.has("min_speed") and run["worst_slow"] > int(SLOW_S * tps):
			why.append("under %.0f m/s for %.2f s" % [float(c["min_speed"]), float(run["worst_slow"]) / tps])
		var passed := why.is_empty()
		var expect: String = c.get("expect", "pass")
		var last: Vector3 = run.get("last", Vector3.ZERO)
		print("PROOF ", JSON.stringify({"shape": run["shape"], "case": run["case"], "expect": expect, "passed": passed, "why": why,
			"peak_z": snappedf(run["peak"], 0.01), "end": [snappedf(last.x, 0.1), snappedf(last.y, 0.1), snappedf(last.z, 0.1)]}))
		var label := "(d) %s %s %s" % [run["shape"], run["case"], "passes" if expect == "pass" else "fails (control)"]
		_t.check(label, passed == (expect == "pass"), ", ".join(why) if not why.is_empty() else "all rules held")
	parent.free()
