extends SceneTree
# 2026-10-10 (w13 KC4): the tunnels family builds four recipe ids as GLBs placed through park_recipes.gd
# (design-v3/PARK.md section 4: lava_tube_run, adit_mouth, shaft_drop, spillway_tunnel; park_large; hole true at the mouths).
# Convention (tools/blender/park/tunnels.py header): +Y up, ride +Z along the fall line, origin at the entry lip on the ground.
# (a) Every GLB exists with its two detail shells; the base holds the drawn mesh <id>, the collision mesh <id>-col and a
#     socket_exit node at the exit lip; no light nodes.
# (b) Budgets per segment: render mesh, -col mesh and shells stay under the per-segment targets that keep a 36-segment chain of
#     lava_tube_run inside park_large times 36 (printed per segment).
# (c) Mouths: no face above the ball's band on the entry lip stands steeply against the incoming ball (n.z under -0.75) (roof lips bevel back 3 m, TRAVERSAL.md:110).
# (d) Placement: park_recipes.place makes one trimesh body from the -col mesh and draws the base plus both shells.
# (e) A headless roll from a ground apron: the row's ride fact publishes once, the ball leaves through the exit, and its speed never
#     stays under 2 m/s for more than 0.5 s (the dead-stop rule, PARK.md section 8).
# (f) A chain: lava_tube_run, its two 30 degree bends and straights placed end to end by socket_exit have matching end rings and
#     one ball rolls the whole chain without a dead stop.
# Evidence limit: headless Godot physics with the 4.7.2 trimesh; no feel, look or render claim.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# id -> {fact, size [length, interior height, interior width], exit [x, y, z, yaw_deg]}
const RECIPES := {
	"lava_tube_run": {"fact": "ride_chute", "size": [48.0, 12.0, 16.0], "exit": [0.0, -5.045, 48.0, 0.0]},
	"lava_tube_run_bend_p30": {"fact": "ride_chute", "size": [48.0, 12.0, 16.0], "exit": [12.28, -5.045, 45.84, 30.0]},
	"lava_tube_run_bend_n30": {"fact": "ride_chute", "size": [48.0, 12.0, 16.0], "exit": [-12.28, -5.045, 45.84, -30.0]},
	"adit_mouth": {"fact": "ride_chute", "size": [56.0, 6.0, 8.0], "exit": [0.0, -3.915, 56.0, 0.0]},
	"shaft_drop": {"fact": "ride_drop", "size": [26.0, 18.0, 12.0], "exit": [0.0, -21.53, 26.0, 0.0]},
	"spillway_tunnel": {"fact": "ride_drop", "size": [90.0, 9.0, 11.0], "exit": [0.0, -35.5, 90.0, 0.0]},
}
const CHAIN := ["lava_tube_run", "lava_tube_run_bend_p30", "lava_tube_run", "lava_tube_run_bend_n30", "lava_tube_run"]
const GLB_DIR := "res://assets/models/park/"
const RENDER_TRI_CAP := 4500
const COL_TRI_CAP := 3500
const SHELL_TRI_CAP := 1500
const FILE_TRI_CAP := 16000
const CHAIN_LEN := 36
const SPACING := 500.0
# The ball arrives at cruise speed (14 m/s, PARK.md section 8); the drift at 4 degrees is the slowest recipe.
const START_SPEED := 14.0
const ROLL_FRAMES := 900
# The exit counts when the ball crosses the exit plane within this distance of the exit lip's floor centre.
const EXIT_REACH := 8.0
const DEAD_SPEED := 2.0
const DEAD_SECONDS := 0.5
const EPS := 0.05
# A face whose normal is within 41 degrees of -Z stands against a ball coming along +Z; the 3 m bevel keeps lips at 45 degrees (n.z -0.71).
const MOUTH_STEEP := 0.75
# A shaft has no roof at its mouth: its entry lip is the ground edge, so it needs no bevelled faces to show.
const NO_ROOF := ["shaft_drop"]

var _t := T.new("park_recipes_tunnels_test")
var _facts: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_files()
	_check_budgets()
	_check_mouths()
	_check_placement()
	await _check_rolls()
	await _check_chain()
	quit(_t.verdict())


func _scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _meshes(scene: Node) -> Array:
	return scene.find_children("*", "MeshInstance3D", true, false)


func _tris(mesh: MeshInstance3D) -> int:
	return mesh.mesh.get_faces().size() / 3


func _check_files() -> void:
	for id: String in RECIPES:
		var scene := _scene(GLB_DIR + id + ".glb")
		if not _t.check("(a) %s.glb loads" % id, scene != null):
			continue
		var names := {}
		for m: MeshInstance3D in _meshes(scene):
			names[String(m.name)] = m
		_t.check("(a) %s holds the mesh %s and %s-col" % [id, id, id], names.has(id) and names.has(id + "-col"), str(names.keys()))
		_t.check("(a) %s has a socket_exit node" % id, scene.find_child("socket_exit", true, false) != null)
		var lights := scene.find_children("*", "Light3D", true, false)
		_t.check("(a) %s carries no light" % id, lights.is_empty())
		scene.free()
		for k in [1, 2]:
			var shell := _scene(GLB_DIR + "%s_detail%d.glb" % [id, k])
			_t.check("(a) %s detail shell %d loads with one drawn mesh" % [id, k], shell != null and _meshes(shell).size() == 1)
			if shell != null:
				shell.free()
		var exit_row: Array = RECIPES[id]["exit"]
		var reload := _scene(GLB_DIR + id + ".glb")
		if reload == null:
			continue
		var socket := reload.find_child("socket_exit", true, false) as Node3D
		if socket != null:
			var yaw := rad_to_deg(socket.transform.basis.get_euler().y)
			_t.check("(a) %s exit lip at %s" % [id, exit_row],
				socket.position.distance_to(Vector3(exit_row[0], exit_row[1], exit_row[2])) < 0.2 and absf(yaw - exit_row[3]) < 0.5,
				"%s yaw %.2f" % [socket.position, yaw])
		reload.free()


func _check_budgets() -> void:
	for id: String in RECIPES:
		var scene := _scene(GLB_DIR + id + ".glb")
		if scene == null:
			_t.check("(b) %s measurable" % id, false, "no GLB")
			continue
		var render := 0
		var col := 0
		for m: MeshInstance3D in _meshes(scene):
			if String(m.name).ends_with("-col"):
				col += _tris(m)
			else:
				render += _tris(m)
		scene.free()
		print("PER_SEGMENT %s render %d col %d (x%d chain: %d render tris)" % [id, render, col, CHAIN_LEN, render * CHAIN_LEN])
		_t.check("(b) %s render mesh is %d to %d triangles (cap %d)" % [id, 1, render, RENDER_TRI_CAP], render > 0 and render <= RENDER_TRI_CAP)
		_t.check("(b) %s -col mesh is %d triangles (cap %d)" % [id, col, COL_TRI_CAP], col > 0 and col <= COL_TRI_CAP)
		_t.check("(b) %s file stays under park_large %d" % [id, FILE_TRI_CAP], render + col <= FILE_TRI_CAP)
		for k in [1, 2]:
			var shell := _scene(GLB_DIR + "%s_detail%d.glb" % [id, k])
			if shell == null:
				_t.check("(b) %s shell %d measurable" % [id, k], false, "no GLB")
				continue
			var tris := 0
			for m: MeshInstance3D in _meshes(shell):
				tris += _tris(m)
			shell.free()
			_t.check("(b) %s shell %d is %d triangles (cap %d)" % [id, k, tris, SHELL_TRI_CAP], tris > 0 and tris <= SHELL_TRI_CAP)
	var straight := _scene(GLB_DIR + "lava_tube_run.glb")
	if straight != null:
		var total := 0
		for m: MeshInstance3D in _meshes(straight):
			total += _tris(m)
		straight.free()
		_t.check("(b) %d lava_tube_run segments fit park_large x %d" % [CHAIN_LEN, CHAIN_LEN], total * CHAIN_LEN <= FILE_TRI_CAP * CHAIN_LEN)


# Faces of the -col mesh whose centroid is above the ball's band and within 3.2 m of the entry plane must not stand steeply
# against a ball coming along +Z: a roof facing the ball in flight is a wall.
func _check_mouths() -> void:
	for id: String in RECIPES:
		var scene := _scene(GLB_DIR + id + ".glb")
		if scene == null:
			_t.check("(c) %s mouth measurable" % id, false, "no GLB")
			continue
		var bad := 0
		var seen := 0
		for m: MeshInstance3D in _meshes(scene):
			if not String(m.name).ends_with("-col"):
				continue
			var faces: PackedVector3Array = m.mesh.get_faces()
			for i in range(0, faces.size(), 3):
				var a := m.transform * faces[i]
				var b := m.transform * faces[i + 1]
				var c := m.transform * faces[i + 2]
				var n := (b - a).cross(c - a)
				if n.length() < 1e-6:
					continue
				n = n.normalized()
				var centre := (a + b + c) / 3.0
				if centre.z < -0.5 or centre.z > 3.2 or centre.y < 4.0:
					continue
				seen += 1
				if n.z < -MOUTH_STEEP:
					bad += 1
		scene.free()
		_t.check("(c) %s entry lip has %d faces above the ball band and none stand against it" % [id, seen],
			(seen > 0 or id in NO_ROOF) and bad == 0, "%d steep" % bad)


# The test names where a GLB's entry-lip origin goes; a row's at is its footprint's centre (PARK.md:77), so the row's at is
# that point moved by the loader's own conversion (park_recipes.gd ride_frame), turned by the row's yaw.
func _centre(row: Dictionary) -> Dictionary:
	var o: Vector3 = ParkRecipes.ride_frame(row)["origin"]
	var yaw := deg_to_rad(float(row["yaw_deg"]))
	row["at"] = [float(row["at"][0]) - sin(yaw) * o.z, float(row["at"][1]) - cos(yaw) * o.z]
	return row


func _row(id: String, at: Vector3, yaw := 0.0) -> Dictionary:
	var spec: Dictionary = RECIPES[id]
	var size: Array = spec["size"]
	return _centre({"id": "t_" + id, "element": "tunnel", "at": [at.x, at.z], "y": at.y, "size": size, "yaw_deg": yaw,
		"ride_fact": spec["fact"], "recipe": id, "budget": "park_large", "hole": true})


func _check_placement() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	for id: String in RECIPES:
		var node := ParkRecipes.place(_row(id, Vector3.ZERO), parent)
		if not _t.check("(d) %s places" % id, node != null and node.has_meta("park_recipe")):
			continue
		var bodies := node.find_children("*", "StaticBody3D", true, false)
		var shapes := node.find_children("*", "CollisionShape3D", true, false).filter(func(s): return s.get_parent() is StaticBody3D)
		_t.check("(d) %s: one body, trimesh shapes only" % id, bodies.size() == 1 and not shapes.is_empty()
			and shapes.all(func(s): return s.shape is ConcavePolygonShape3D), "%d bodies, %d shapes" % [bodies.size(), shapes.size()])
		var views := node.find_children("*", "MeshInstance3D", true, false)
		_t.check("(d) %s: base and two shells drawn, -col never" % id, views.size() == 3
			and views.all(func(v): return not String(v.name).ends_with("-col")), "%d views" % views.size())
		var greybox := node.find_child("Greybox", true, false)
		_t.check("(d) %s is the GLB, not the greybox stand-in" % id, greybox == null)
		parent.remove_child(node)
		node.free()
	parent.free()


func _ball(parent: Node3D, at: Vector3, velocity: Vector3) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.set_collision_layer_value(2, true)
	ball.set_collision_mask_value(1, true)
	ball.gravity_scale = Tuning.new().f("gravity") / 9.8
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	ball.position = at
	ball.linear_velocity = velocity
	parent.add_child(ball)
	return ball


# The apron the ball rolls in on: a world-layer slab whose top is the ground at y 0, ending at the entry lip (z 0).
func _apron(parent: Node3D, x: float, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 0
	body.set_collision_layer_value(1, true)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 2, 60)
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.position = Vector3(x, -1.0, -30.0)
	body.rotation.y = yaw


func _watch(ball: RigidBody3D, goal: Vector3, heading: Vector3, out: Dictionary) -> void:
	out["ball"] = ball
	out["goal"] = goal
	out["heading"] = heading
	out["slow"] = 0.0
	out["worst"] = 0.0
	out["done"] = false
	out["steps"] = 0
	out["armed"] = false


func _step_watch(w: Dictionary) -> void:
	var ball: RigidBody3D = w["ball"]
	if w["done"]:
		return
	w["steps"] += 1
	if ball.position.z > 0.5 or w["armed"]:
		w["armed"] = true
	if not w["armed"]:
		return
	# Through the exit: past the exit plane, inside the tube's width and within a ball's reach of the exit lip's height.
	var heading: Vector3 = w["heading"]
	var from_exit: Vector3 = ball.position - (w["goal"] as Vector3)
	var along: float = from_exit.dot(heading)
	var lateral: float = (from_exit - heading * along).length()
	if along > 0.0 and lateral < EXIT_REACH:
		w["done"] = true
		return
	if ball.linear_velocity.length() < DEAD_SPEED:
		w["slow"] += 1.0 / 60.0
		w["worst"] = maxf(w["worst"], w["slow"])
	else:
		w["slow"] = 0.0


func _check_rolls() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var publish := func(kind: String, at: Vector3) -> void: _facts.append([kind, at])
	var watches := {}
	var i := 0
	for id: String in RECIPES:
		var x := i * SPACING
		i += 1
		var node := ParkRecipes.place(_row(id, Vector3(x, 0, 0)), parent, Callable(), publish)
		_apron(parent, x)
		var exit_row: Array = RECIPES[id]["exit"]
		var w := {}
		var ball := _ball(parent, Vector3(x, Tuning.RADIUS + 0.05, -10.0), Vector3(0, 0, START_SPEED))
		var yaw := deg_to_rad(float(exit_row[3]))
		_watch(ball, Vector3(x + exit_row[0], exit_row[1], exit_row[2]), Vector3(sin(yaw), 0, cos(yaw)), w)
		w["x"] = x
		w["node"] = node
		watches[id] = w
	for f in ROLL_FRAMES:
		await physics_frame
		for id in watches:
			_step_watch(watches[id])
	for id in watches:
		var w: Dictionary = watches[id]
		var fact: String = RECIPES[id]["fact"]
		var near := _facts.filter(func(e): return absf(e[1].x - w["x"]) < SPACING * 0.5)
		var kinds := near.map(func(e): return e[0])
		_t.check("(e) a roll through %s publishes %s once" % [id, fact], kinds.count(fact) == 1 and kinds.size() == 1, str(kinds))
		_t.check("(e) the ball leaves %s through its exit" % id, w["done"], "ball at %s, goal %s" % [(w["ball"] as RigidBody3D).position, w["goal"]])
		_t.check("(e) %s: speed under %.0f m/s for at most %.1f s (worst %.2f s)" % [id, DEAD_SPEED, DEAD_SECONDS, w["worst"]], w["worst"] <= DEAD_SECONDS)
	parent.free()


# Matching end rings: the points of A's -col mesh in the end plane (through socket_exit, normal along its heading) equal the
# points of B's -col mesh at its own z 0, once B is placed at A's exit.
func _ring(scene: Node, xf: Transform3D, plane_origin: Vector3, plane_normal: Vector3) -> Array:
	var out := {}
	for m: MeshInstance3D in _meshes(scene):
		if not String(m.name).ends_with("-col"):
			continue
		for v in m.mesh.get_faces():
			var p := xf * (m.transform * v)
			if absf((p - plane_origin).dot(plane_normal)) < 0.01:
				out["%d,%d,%d" % [roundi(p.x * 100.0), roundi(p.y * 100.0), roundi(p.z * 100.0)]] = p
	return out.values()


func _check_chain() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var publish := func(kind: String, at: Vector3) -> void: _facts.append([kind, at])
	_facts.clear()
	var at := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	var first_xf := at
	var ring_ok := true
	var ring_detail := ""
	var prev_ring: Array = []
	var last_socket := Vector3.ZERO
	for n in CHAIN.size():
		var id: String = CHAIN[n]
		var scene := _scene(GLB_DIR + id + ".glb")
		if scene == null:
			_t.check("(f) chain piece %d (%s) loads" % [n, id], false)
			parent.free()
			return
		var socket := scene.find_child("socket_exit", true, false) as Node3D
		var start_ring := _ring(scene, at, at.origin, at.basis * Vector3(0, 0, 1))
		if n > 0:
			var matched := start_ring.size() > 8 and prev_ring.size() == start_ring.size()
			if matched:
				for p: Vector3 in start_ring:
					var hit := false
					for q: Vector3 in prev_ring:
						if p.distance_to(q) < EPS:
							hit = true
							break
					if not hit:
						matched = false
						break
			ring_ok = ring_ok and matched
			ring_detail += " [%d: %d vs %d points]" % [n, prev_ring.size(), start_ring.size()]
		var end_xf: Transform3D = at * socket.transform
		prev_ring = _ring(scene, at, end_xf.origin, end_xf.basis * Vector3(0, 0, 1))
		var row := _row(id, at.origin, rad_to_deg(at.basis.get_euler().y))
		row["id"] = "chain_%d" % n
		ParkRecipes.place(row, parent, Callable(), publish if n == 0 else Callable())
		scene.free()
		at = end_xf
		last_socket = end_xf.origin
	_t.check("(f) chained end rings match point for point", ring_ok, ring_detail)
	var apron := StaticBody3D.new()
	apron.collision_layer = 0
	apron.set_collision_layer_value(1, true)
	apron.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 2, 60)
	shape.shape = box
	apron.add_child(shape)
	parent.add_child(apron)
	apron.position = Vector3(0, -1.0, -30.0)
	var ball := _ball(parent, Vector3(0, Tuning.RADIUS + 0.05, -10.0), Vector3(0, 0, START_SPEED))
	var w := {}
	_watch(ball, last_socket, at.basis * Vector3(0, 0, 1), w)
	for f in ROLL_FRAMES * 2:
		await physics_frame
		_step_watch(w)
	_t.check("(f) one ball rolls the five-piece chain to its last exit", w["done"], "ball %s, goal %s" % [ball.position, last_socket])
	_t.check("(f) the chain has no dead stop (worst %.2f s)" % w["worst"], w["worst"] <= DEAD_SECONDS)
	_t.check("(f) the first piece publishes ride_chute once", _facts.filter(func(e): return e[0] == "ride_chute").size() == 1, str(_facts.size()))
	parent.free()
