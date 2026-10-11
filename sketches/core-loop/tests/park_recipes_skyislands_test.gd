extends SceneTree
# 2026-10-10 (w13 KC8): the sky-island family's three recipe GLBs place through park_recipes.gd and ride
# (design-v3/PARK.md section 4, row "Sky-island hops"; sketches/core-loop/tools/blender/park/skyislands.py).
# Convention (same for the whole family): +Y up, the ride direction +Z, x centred, origin at the entry lip with y 0 at the
# ridden surface there, so a park row places a recipe with position, y, size and yaw and its deck height is the row's y.
#   mesa_lip_kicker  12 m long, 2.5 m high at the lip, 14 m wide (the sizes of the stage 3 pit rows); the top is the
#                    parabola y = H * (z / L)^2, flush with the ground at z 0 and 22.6 degrees at the lip.
#   net_deck         one 80 m cell of the net lattice, x -40..40, z 0..80; the net hangs from y 0 at the four 16 m posts
#                    and sags 3.5 m at its middle.
#   floating_island  the Hanging Isle: deck 180 m across (x -90..90, z 0..180) at y 0, the tip 318 m under the deck.
# (a) Each recipe ships its base GLB and two detail shells; the base carries one -col trimesh and the render mesh.
# (b) Placed through park_recipes.place the node has one trimesh collider, never draws the -col mesh, views the base and
#     both shells, and the collider's extent is the recipe's convention.
# (c) Budgets as asset_registry_test counts them after import: base triangles within the class, shells within detail.
# (d) A headless roll: a ball runs off mesa_lip_kicker, leaves the ground at the lip (kicker_launch, the codex's own
#     off-kicker test, StageMap.near_kicker_lip) at the angle the row's height and length set, and lands on net_deck 20 m
#     below (ride_hop); the speed never stays under 2 m/s for more than 0.5 s (PARK.md section 8, the dead-stop rule).
# (e) A ball rolls across the floating_island deck and publishes ride_hop with no dead stop.
# Evidence limit: headless Jolt physics on a 1 m ball; no feel, look or camera claim.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const StageMap := preload("res://src/world/stage_map.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

const EPS := 0.02
const DEAD_SPEED := 2.0
const DEAD_FRAMES := 30
const GL := 26.0

# id -> {budget, extent: AABB of the -col mesh in the node's space}. A row's at is its footprint's centre (PARK.md:77):
# the loader puts each entry-lip GLB's origin half a length behind it (park_recipes.gd ride_frame).
const KICKER := AABB(Vector3(-7, 0, -6), Vector3(14, 2.5, 12))
const NET_X := 40.6   # the 40 m cell plus the corner posts' 0.6 m radius
const NET_Z0 := -40.6
const NET_Z := 81.2
const NET_POST := 16.0
const NET_SAG := 3.5
const ISLE_R := 90.0
const ISLE_DROP := 318.0
const RECIPES := {
	"mesa_lip_kicker": {"budget": "landform", "tris": 8000},
	"net_deck": {"budget": "landform", "tris": 8000},
	"floating_island": {"budget": "park_large", "tris": 16000},
}
const DETAIL_TRIS := 1500

var _t := T.new("park_recipes_skyislands_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_files()
	_check_placed()
	_check_budgets()
	await _check_kicker_roll()
	await _check_island_roll()
	quit(_t.verdict())


func _row(id: String, element: String, at: Vector2, y: Variant, size: Vector3, recipe: String, fact: String, budget := "landform") -> Dictionary:
	return {"id": id, "element": element, "at": [at.x, at.y], "y": y, "size": [size.x, size.y, size.z], "yaw_deg": 0.0,
		"ride_fact": fact, "recipe": recipe, "budget": budget}


func _check_files() -> void:
	for id: String in RECIPES:
		var p := ParkRecipes.paths(id, RECIPES[id]["budget"])
		_t.check("(a) %s base GLB ships" % id, ResourceLoader.exists(p["base"]), p["base"])
		for shell: String in p["shells"]:
			_t.check("(a) %s shell ships" % id, ResourceLoader.exists(shell), shell)
		_t.eq("(a) %s is in the recipe registry as sky_islands" % id, ParkRecipes.ROWS[id]["family"], "sky_islands")
		var scene := _scene(p["base"])
		if scene == null:
			continue
		var names: Array = scene.find_children("*", "MeshInstance3D", true, false).map(func(m): return String(m.name))
		_t.check("(a) %s base holds the render mesh and its -col mesh" % id, names.has(id) and names.has(id + ParkRecipes.COL_SUFFIX)
			and names.size() == 2, str(names))
		scene.free()


func _scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


# The collider extent and view count of a placed recipe.
func _placed(id: String, row: Dictionary, parent: Node3D) -> Dictionary:
	var node := ParkRecipes.place(row, parent)
	var shapes := node.find_children("*", "CollisionShape3D", true, false).filter(func(s): return s.get_parent() is StaticBody3D)
	var box := AABB()
	var trimeshes := 0
	for k in shapes.size():
		var s := shapes[k] as CollisionShape3D
		if s.shape is ConcavePolygonShape3D:
			trimeshes += 1
		var faces: PackedVector3Array = s.shape.get_faces() if s.shape is ConcavePolygonShape3D else PackedVector3Array()
		if faces.is_empty():
			continue
		var local := AABB(faces[0], Vector3.ZERO)
		for v in faces:
			local = local.expand(v)
		var b := s.transform * local
		box = b if k == 0 else box.merge(b)
	var views := node.find_children("*", "MeshInstance3D", true, false)
	return {"node": node, "box": box, "shapes": shapes.size(), "trimeshes": trimeshes, "views": views,
		"drawn_col": views.filter(func(v): return String(v.name).ends_with(ParkRecipes.COL_SUFFIX)).size()}


func _near_box(label: String, got: AABB, want: AABB) -> void:
	var ok := got.position.distance_to(want.position) <= EPS and got.size.distance_to(want.size) <= EPS
	_t.check(label, ok, "got %s, want %s" % [got, want])


func _check_placed() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var kicker := _placed("mesa_lip_kicker", _row("k", "kicker", Vector2.ZERO, 0.0, Vector3(12, 2.5, 14), "mesa_lip_kicker", "kicker_launch"), parent)
	_t.check("(b) mesa_lip_kicker: one trimesh collider, -col never drawn, base and two shells viewed", kicker["trimeshes"] == 1 and kicker["shapes"] == 1
		and kicker["drawn_col"] == 0 and kicker["views"].size() == 3, "%s trimeshes, %s shapes, %s views" % [kicker["trimeshes"], kicker["shapes"], kicker["views"].size()])
	_near_box("(b) mesa_lip_kicker collider is 14 x 2.5 x 12 centred on the row's at", kicker["box"], KICKER)
	var net := _placed("net_deck", _row("n", "sky_island", Vector2(500, 0), 0.0, Vector3(80, 14, 80), "net_deck", "ride_hop"), parent)
	_t.check("(b) net_deck: one trimesh collider, -col never drawn, base and two shells viewed", net["trimeshes"] == 1 and net["shapes"] == 1
		and net["drawn_col"] == 0 and net["views"].size() == 3, "%s trimeshes, %s shapes, %s views" % [net["trimeshes"], net["shapes"], net["views"].size()])
	var nb: AABB = net["box"]
	_t.check("(b) net_deck spans x -40..40 and z -40..40 plus the posts' radius, posts to 16 m, sag to -3.5 m", absf(nb.position.x + NET_X) <= EPS and absf(nb.size.x - 2.0 * NET_X) <= EPS
		and absf(nb.position.z - NET_Z0) <= EPS and absf(nb.size.z - NET_Z) <= EPS and absf(nb.end.y - NET_POST) <= EPS and absf(nb.position.y + NET_SAG) <= 0.1, str(nb))
	var isle := _placed("floating_island", _row("i", "sky_island", Vector2(1000, 0), 0.0, Vector3(180, ISLE_DROP, 180), "floating_island", "ride_hop", "park_large"), parent)
	_t.check("(b) floating_island: one trimesh collider, -col never drawn, base and two shells viewed", isle["trimeshes"] == 1 and isle["shapes"] == 1
		and isle["drawn_col"] == 0 and isle["views"].size() == 3, "%s trimeshes, %s shapes, %s views" % [isle["trimeshes"], isle["shapes"], isle["views"].size()])
	var ib: AABB = isle["box"]
	_t.check("(b) floating_island deck is 180 m across at y 0 and the tip is 318 m under it", absf(ib.position.x + ISLE_R) <= 0.5 and absf(ib.size.x - 2.0 * ISLE_R) <= 0.5
		and absf(ib.position.z + ISLE_R) <= 0.5 and absf(ib.size.z - 2.0 * ISLE_R) <= 0.5 and absf(ib.end.y) <= 0.5 and absf(ib.position.y + ISLE_DROP) <= 0.5, str(ib))
	parent.free()


func _measure(path: String) -> Dictionary:
	var node := _scene(path)
	if node == null:
		return {}
	var tris := 0
	var draws := 0
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	node.free()
	return {"tris": tris, "draws": draws}


func _check_budgets() -> void:
	for id: String in RECIPES:
		var p := ParkRecipes.paths(id, RECIPES[id]["budget"])
		var m := _measure(p["base"])
		_t.check("(c) %s base is %s with a render and a -col draw within %d triangles" % [id, RECIPES[id]["budget"], RECIPES[id]["tris"]],
			not m.is_empty() and m["tris"] <= RECIPES[id]["tris"] and m["draws"] == 2, str(m))
		for shell: String in p["shells"]:
			var s := _measure(shell)
			_t.check("(c) %s shell is one draw within %d triangles" % [shell.get_file(), DETAIL_TRIS], not s.is_empty() and s["tris"] <= DETAIL_TRIS and s["draws"] == 1, str(s))


func _ball(parent: Node3D, at: Vector3, velocity: Vector3) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	ball.contact_monitor = true
	ball.max_contacts_reported = 4
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.set_collision_layer_value(2, true)
	ball.set_collision_mask_value(1, true)
	ball.gravity_scale = Tuning.new().f("gravity") / 9.8
	# the game ball's own damping and surface (rigid_ball.gd:48-55), rolling without slip at the start
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp = 0.25
	var surface := PhysicsMaterial.new()
	surface.friction = 0.9
	surface.bounce = 0.25
	ball.physics_material_override = surface
	ball.angular_velocity = Vector3(velocity.z, 0.0, -velocity.x) / Tuning.RADIUS
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	ball.position = at
	ball.linear_velocity = velocity
	parent.add_child(ball)
	return ball


# The longest run of physics frames under DEAD_SPEED, over a ball's recorded speeds.
func _dead_run(speeds: Array) -> int:
	var best := 0
	var run := 0
	for v: float in speeds:
		run = run + 1 if v < DEAD_SPEED else 0
		best = maxi(best, run)
	return best


func _check_kicker_roll() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var events: Array = []
	var publish := func(kind: String, _at: Vector3) -> void: events.append(kind)
	# A 60 m runway whose top is y 0, the kicker at its end, and the net 20 m under the lip.
	ParkRecipes.place(_row("runway", "ground", Vector2(0, -30), -1.0, Vector3(60, 1, 40), "greybox:ground", ""), parent)
	# Rows are centred: the kicker's footprint runs z 0..12 (at z 6) and the net's z 14..94 (at z 54).
	var kicker_row := _row("k", "kicker", Vector2(0, KICKER.size.z * 0.5), 0.0, Vector3(12, 2.5, 14), "mesa_lip_kicker", "kicker_launch")
	ParkRecipes.place(kicker_row, parent, Callable(), publish)
	ParkRecipes.place(_row("n", "sky_island", Vector2(0, 54), -20.0, Vector3(80, 14, 80), "net_deck", "ride_hop"), parent, Callable(), publish)
	var map := StageMap.new()
	# The lip comes from park_map's own rule for the row, so the test fails loud if the two drift apart.
	var lip: Dictionary = ParkMap.kicker_lip(kicker_row)
	_t.check("(d) park_map puts the recipe kicker's lip at the footprint's far edge, where the GLB's lip lands", (lip["at"] as Vector2).distance_to(Vector2(0, KICKER.size.z)) < EPS, str(lip["at"]))
	map.kickers = [lip]
	var ball := _ball(parent, Vector3(0, 1.05, -50), Vector3(0, 0, 20))
	var speeds: Array = []
	var launched := false
	var angle := -1.0
	var grounded_before := false
	for f in 600:
		await physics_frame
		var p := ball.position
		var grounded := ball.get_contact_count() > 0
		if not launched and grounded_before and not grounded and map.near_kicker_lip(Vector2(p.x, p.z)):
			launched = true
			events.append("kicker_launch")
			var v := ball.linear_velocity
			angle = rad_to_deg(atan2(v.y, Vector2(v.x, v.z).length()))
		grounded_before = grounded
		if p.z > -45.0 and p.z < 80.0:
			speeds.append(ball.linear_velocity.length())
	var want := rad_to_deg(atan2(2.0 * KICKER.size.y, KICKER.size.z))
	# The net is a bowl: the ball may roll out of the sensor box and back in, which publishes ride_hop again.
	_t.check("(d) the roll publishes kicker_launch once, then ride_hop", events.slice(0, 2) == ["kicker_launch", "ride_hop"] and events.count("kicker_launch") == 1,
		str(events))
	_t.check("(d) the ball leaves the ground at the lip at the angle the row's height and length set", launched and absf(angle - want) <= 6.0,
		"left at %.1f degrees, row sets %.1f" % [angle, want])
	_t.check("(d) the ball lands on the net 20 m down", ball.position.y < -18.0 and ball.position.y > -25.0 and ball.position.z > 14.0, str(ball.position))
	_t.check("(d) no dead stop from the runway to the far edge of the net: under 2 m/s for at most 0.5 s", _dead_run(speeds) <= DEAD_FRAMES, "%d frames under 2 m/s" % _dead_run(speeds))
	parent.free()


func _check_island_roll() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var events: Array = []
	var publish := func(kind: String, _at: Vector3) -> void: events.append(kind)
	ParkRecipes.place(_row("i", "sky_island", Vector2(0, ISLE_R), 0.0, Vector3(180, ISLE_DROP, 180), "floating_island", "ride_hop", "park_large"), parent, Callable(), publish)
	var ball := _ball(parent, Vector3(0, 1.6, 6), Vector3(0, 0, 16))
	var speeds: Array = []
	for f in 480:
		await physics_frame
		speeds.append(ball.linear_velocity.length())
	_t.eq("(e) the roll over the deck publishes ride_hop once", events, ["ride_hop"])
	_t.check("(e) the ball stays on the deck", ball.position.y > -1.0 and ball.position.z > 60.0, str(ball.position))
	_t.check("(e) no dead stop: under 2 m/s for at most 0.5 s", _dead_run(speeds) <= DEAD_FRAMES, "%d frames under 2 m/s" % _dead_run(speeds))
	parent.free()
