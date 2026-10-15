extends SceneTree
# 2026-10-10 (w13 KC9): the six contraption skins (design-v3/PARK.md section 4, contraption_rows `recipe`; unit notes: GLBs under
# assets/models/park/contraptions/, recipes under tools/blender/park/contraptions/).
# (a) Files: each recipe id ships <id>.glb, <id>_detail1.glb and <id>_detail2.glb (the trebuchet also its arm); each loads, holds
#     meshes and no light, no -col mesh (a contraption keeps its primitive collider), and wears the enamel slot only.
# (b) Budget: every GLB is inside its class in assets/asset_budgets.json (triangles, vertices, draws). Base class by size.
# (c) Convention: +Y up, +Z the aim, origin at the contraption's code anchor; the gauge face stays clear of the needle, the lift
#     deck top is the collider top, the barge floor is y 1.0, the geyser collar stays inside the ring, and the trebuchet frame
#     stays out of the arm's swing.
# (d) The draw path: a contraption row with a recipe draws its GLB views (tagged with meta contraption_recipe), a row without
#     draws the primitive it draws today, a recipe whose GLB is missing falls back to the primitive; colliders, positions and
#     animation are the same either way over 4.5 s (behaviour unchanged).
# Evidence limit: headless geometry and node checks; no look, feel or ride claim (the ride facts are untouched).

const Contraptions := preload("res://src/world/contraptions.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const T := preload("res://tests/support/t.gd")

const DIR := "res://assets/models/park/contraptions/"
const META := "contraption_recipe"
const META_ID := "contraption_id"
const BUDGETS := "res://assets/asset_budgets.json"
const EPS := 0.06
# recipe id -> [base class, extra base GLBs]
const RECIPES := {
	"gauge": ["detail", []],
	"geyser_vent": ["detail", []],
	"lift_platform": ["detail", []],
	"cannon": ["landform", []],
	"trebuchet": ["landform", ["trebuchet_arm"]],
	"barge": ["landform", []],
}

var _t := T.new("park_recipes_contraptions_test")
var _classes: Dictionary


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_classes = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS))["classes"]
	_check_files()
	_check_convention()
	_check_draw_path()
	quit(_t.verdict())


func _files(recipe: String) -> Array:
	var out := [[recipe, RECIPES[recipe][0]], [recipe + "_detail1", "detail"], [recipe + "_detail2", "detail"]]
	for extra: String in RECIPES[recipe][1]:
		out.append([extra, "detail"])
	return out


func _scene(file: String) -> Node:
	var path := DIR + file + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _meshes(scene: Node) -> Array:
	return scene.find_children("*", "MeshInstance3D", true, false)


func _xf(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf


# Every vertex of every mesh in the scene, in the scene's space.
func _points(scene: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	for m: MeshInstance3D in _meshes(scene):
		if m.mesh == null:
			continue
		var xf := _xf(m, scene)
		for s in m.mesh.get_surface_count():
			for v: Vector3 in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				out.append(xf * v)
	return out


func _aabb(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	return box


func _check_files() -> void:
	for recipe: String in RECIPES:
		for row: Array in _files(recipe):
			var file: String = row[0]
			var scene := _scene(file)
			if not _t.check("(a) %s.glb loads" % file, scene != null):
				continue
			var meshes := _meshes(scene)
			var no_light := scene.find_children("*", "Light3D", true, false).is_empty()
			var no_col := meshes.all(func(m): return not String(m.name).ends_with("-col"))
			_t.check("(a) %s has meshes, no light and no -col mesh" % file, not meshes.is_empty() and no_light and no_col)
			var tris := 0
			var verts := 0
			var draws := 0
			var enamel := true
			for m: MeshInstance3D in meshes:
				for s in m.mesh.get_surface_count():
					var arrays := m.mesh.surface_get_arrays(s)
					var count: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
					tris += (count if count > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
					verts += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
					draws += 1
					var mat := m.mesh.surface_get_material(s)
					enamel = enamel and mat != null and mat.resource_name == "enamel"
			var cap: Dictionary = _classes[row[1]]
			_t.check("(b) %s is inside the %s class" % [file, row[1]], tris <= int(cap["tris"]) and verts <= int(cap["verts"])
				and draws <= int(cap["draws"]), "%d tris, %d verts, %d draws" % [tris, verts, draws])
			_t.check("(a) %s wears the enamel slot only" % file, enamel)
			scene.free()


func _box(file: String) -> AABB:
	var scene := _scene(file)
	if scene == null:
		return AABB(Vector3(INF, INF, INF), Vector3.ZERO)
	var pts := _points(scene)
	scene.free()
	return _aabb(pts) if not pts.is_empty() else AABB(Vector3(INF, INF, INF), Vector3.ZERO)


func _pts(file: String) -> PackedVector3Array:
	var scene := _scene(file)
	if scene == null:
		return PackedVector3Array()
	var pts := _points(scene)
	scene.free()
	return pts


func _check_convention() -> void:
	# Gauge: stands on the ground under the post; the face centre is (0, 3.4, 0); nothing inside the needle's reach
	# (radius 1.0 round the face centre) rises past z 0.09, where the code needle starts at 0.095.
	var gauge := _box("gauge")
	_t.check("(c) gauge stands on y 0, 4.5 to 4.9 tall, centred in x", absf(gauge.position.y) < EPS and gauge.end.y > 4.5
		and gauge.end.y < 4.9 and absf(gauge.get_center().x) < 0.1, str(gauge))
	var clear := true
	var any := false
	for p in _pts("gauge"):
		any = true
		if Vector2(p.x, p.y - 3.4).length() < 1.0 and p.z > 0.09:
			clear = false
	_t.check("(c) gauge face leaves the needle's reach clear", any and clear)
	# Geyser: the origin is the mouth, the ground at y -1; the collar stays inside the ring's inner radius 2.9 and under the
	# ring's tube, and the steam column's base (radius 1.6) is not capped.
	var geyser := _pts("geyser_vent")
	var rmax := 0.0
	var hmax := -INF
	var hmin := INF
	var capped := false
	for p in geyser:
		rmax = maxf(rmax, Vector2(p.x, p.z).length())
		hmax = maxf(hmax, p.y)
		hmin = minf(hmin, p.y)
		if Vector2(p.x, p.z).length() < 1.5 and p.y > -0.7:
			capped = true
	_t.check("(c) geyser vent: ground at y -1, collar inside the ring, column mouth open", not geyser.is_empty()
		and absf(hmin + 1.0) < EPS and rmax <= 2.9 and hmax <= 3.0 and not capped, "r %s, y %s..%s, capped %s" % [rmax, hmin, hmax, capped])
	# Lift: the origin is the plate's centre; the deck top is the collider top (y +0.5) and nothing rises past it; radius 4.5.
	var lift := _box("lift_platform")
	_t.check("(c) lift deck top is the collider top, radius 4.5", absf(lift.end.y - 0.5) < 0.02 and absf(lift.size.x - 9.0) < 0.3
		and absf(lift.size.z - 9.0) < 0.3 and absf(lift.get_center().x) < 0.1, str(lift))
	# Barge: the origin is the collider's centre; the floor is flat at y 1.0 under the ball and the hull hangs to -3.6.
	var barge := _pts("barge")
	var floor_ok := false
	var low := INF
	var high := -INF
	for p in barge:
		low = minf(low, p.y)
		high = maxf(high, p.y)
		if absf(p.y - 1.0) < 0.01 and absf(p.x) > 5.0 and absf(p.z) > 5.0:
			floor_ok = true
	var barge_box := _aabb(barge) if not barge.is_empty() else AABB()
	_t.check("(c) barge floor at y 1.0, hull to -3.6, wall under 2.2, 14 to 16 m square", floor_ok and absf(low + 3.6) < 0.2 and high <= 2.2
		and barge_box.size.x >= 14.0 and barge_box.size.x <= 16.0 and barge_box.size.z >= 14.0 and barge_box.size.z <= 16.0, str(barge_box))
	# Cannon: the origin is the mouth (ground at y -1); pad on the ground, barrel up and forward, symmetric in x.
	var cannon := _box("cannon")
	_t.check("(c) cannon: ground at y -1, barrel rises past y 4, centred in x, muzzle forward of the pad", absf(cannon.position.y + 1.0) < EPS
		and cannon.end.y > 4.0 and absf(cannon.get_center().x) < 0.2 and cannon.end.z > -4.0 and cannon.position.z < -6.0, str(cannon))
	# Trebuchet: the frame is the pair of posts at z -6, x +-3, ground at y -1, tops at y 11; the arm is centred on its pivot,
	# the throwing end at -z, 20 m long. Nothing of the frame stands in the arm's swing round the pivot (0, 10.5, -6).
	var frame := _box("trebuchet")
	_t.check("(c) trebuchet frame: ground at y -1, top at 11, 6 to 8 m wide", absf(frame.position.y + 1.0) < EPS and absf(frame.end.y - 11.0) < 0.4
		and frame.size.x >= 6.0 and frame.size.x <= 8.0, str(frame))
	var arm := _box("trebuchet_arm")
	_t.check("(c) trebuchet arm: 20 m along z about its pivot, under 3 m wide and tall", absf(arm.position.z + 10.0) < 0.3 and absf(arm.end.z - 10.0) < 0.3
		and arm.size.x < 3.0 and arm.size.y < 3.0 and absf(arm.get_center().x) < 0.1, str(arm))
	var swing_clear := true
	for p in _pts("trebuchet"):
		var d := Vector2(p.y - 10.5, p.z + 6.0).length()
		if absf(p.x) < 1.4 and d > 1.4 and d < 10.3:
			swing_clear = false
	_t.check("(c) trebuchet frame stays out of the arm's swing", frame.size.x > 0.0 and swing_clear)
	for recipe: String in RECIPES:
		for suffix in ["_detail1", "_detail2"]:
			var shell := _box(recipe + suffix)
			var base := _box(recipe)
			if recipe == "trebuchet":
				base = base.merge(_box("trebuchet_arm"))
			_t.check("(c) %s%s stays inside the base's bounds grown by 0.3" % [recipe, suffix], shell.size != Vector3.ZERO
				and base.grow(0.3).encloses(shell), "%s vs %s" % [shell, base])


# ---- the draw path ----

func _ground(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, 5.0 + lift, z)


func _specs(with_recipes: bool) -> Array:
	var barge_a := {"kind": "barge", "id": "barge_skin", "a": Vector3(0, 4, 0), "b": Vector3(30, 4, 0), "size": Vector3(14, 1.2, 14),
		"travel": 9.0, "dwell": 3.0, "offset": 0.0}
	var barge_b := barge_a.duplicate()
	barge_b["id"] = "barge_plain"
	barge_b["a"] = Vector3(0, 4, 100)
	barge_b["b"] = Vector3(30, 4, 100)
	var lift_a := {"kind": "lift", "id": "lift_skin", "at": Vector2(200, 0), "radius": 4.5, "rise": 13.0, "charge": 3.2, "offset": 0.0}
	var lift_b := lift_a.duplicate()
	lift_b["id"] = "lift_plain"
	lift_b["at"] = Vector2(200, 100)
	var out := [barge_a, barge_b, lift_a, lift_b]
	var k := 0
	for style in ["cannon", "trebuchet", "geyser"]:
		for variant in ["skin", "plain"]:
			out.append({"kind": "launcher", "id": "%s_%s" % [style, variant], "style": style, "at": Vector2(400 + k * 60, 0),
				"radius": 3.5, "target": Vector3(400 + k * 60, 20, 100), "floor": 20.0, "min_flight": 2.5, "charge": 3.0})
			k += 1
	out.append({"kind": "launcher", "id": "cannon_east", "style": "cannon", "at": Vector2(900, 0), "radius": 4.0,
		"target": Vector3(1000, 20, 0), "floor": 20.0, "min_flight": 2.5, "charge": 3.0})
	if with_recipes:
		var recipe_of := {"cannon_east": "cannon", "barge_skin": "barge", "lift_skin": "lift_platform", "cannon_skin": "cannon", "trebuchet_skin": "trebuchet",
			"geyser_skin": "geyser_vent"}
		for spec: Dictionary in out:
			if recipe_of.has(spec["id"]):
				spec["recipe"] = recipe_of[spec["id"]]
			else:
				spec["recipe"] = ""
	return out


func _make(specs: Array) -> Node:
	var map = Gorge.new()
	map.contraptions = specs
	var c = Contraptions.new()
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(c)
	c.setup(map, Callable(self, "_ground"), 14.0, 26.0)
	return c


func _views(c: Node, id: String, recipe: String) -> Array:
	return c.find_children("*", "MeshInstance3D", true, false).filter(func(v):
		return v.has_meta(META) and v.get_meta(META) == recipe and v.get_meta(META_ID) == id)


func _tagged(c: Node) -> Array:
	return c.find_children("*", "MeshInstance3D", true, false).filter(func(v): return v.has_meta(META))


func _primitive_count(c: Node, id: String, mesh_class: String) -> int:
	var holder: Node = c.find_child(id, true, false)
	if holder == null:
		return -1
	return holder.find_children("*", "MeshInstance3D", true, false).filter(func(v): return v.mesh != null and v.mesh.get_class() == mesh_class).size()


func _check_draw_path() -> void:
	var c = _make(_specs(true))
	var twin = _make(_specs(false))
	for pair in [["barge_skin", "barge"], ["lift_skin", "lift_platform"], ["cannon_skin", "cannon"], ["trebuchet_skin", "trebuchet"],
			["geyser_skin", "geyser_vent"]]:
		_t.check("(d) %s draws the %s GLB (base and both shells)" % pair, _views(c, pair[0], pair[1]).size() >= 3,
			"%d views" % _views(c, pair[0], pair[1]).size())
	for id in ["barge_plain", "lift_plain", "cannon_plain", "trebuchet_plain", "geyser_plain"]:
		_t.check("(d) %s draws no recipe view" % id, c.find_children("*", "MeshInstance3D", true, false).filter(
			func(v): return v.has_meta(META_ID) and v.get_meta(META_ID) == id).is_empty())
	_t.check("(d) the twin without recipes draws no recipe view at all", _tagged(twin).is_empty())
	# The GLB's +Z is the launcher's aim: a cannon aimed along +x stands with its pad (the GLB's -z side) to the west of the mouth.
	var east := _views(c, "cannon_east", "cannon")
	var box := AABB()
	for k in east.size():
		var v := east[k] as MeshInstance3D
		var b := v.global_transform * v.mesh.get_aabb()
		box = b if k == 0 else box.merge(b)
	_t.check("(d) a cannon aimed along +x lies west of its mouth, centred on the aim line", not east.is_empty() and box.get_center().x < 900.0 - 3.0
		and absf(box.get_center().z) < 1.0, str(box))
	# The primitive stays for the row without a recipe and goes for the row with one.
	_t.check("(d) cannon_plain keeps its cylinder barrel", _primitive_count(c, "cannon_plain", "CylinderMesh") == 1)
	_t.check("(d) cannon_skin drops the cylinder barrel", _primitive_count(c, "cannon_skin", "CylinderMesh") == 0)
	_t.check("(d) trebuchet_plain keeps its box posts and arm", _primitive_count(c, "trebuchet_plain", "BoxMesh") == 3)
	_t.check("(d) trebuchet_skin drops the box posts and arm", _primitive_count(c, "trebuchet_skin", "BoxMesh") == 0)
	_t.check("(d) the trebuchet arm is still posed by the code", c.launchers[3]["arm"] != null and c.launchers[2]["arm"] != null)
	# Behaviour unchanged: same colliders, same positions, same animation over 4.5 s.
	var same_bodies := true
	for list in ["barges", "lifts"]:
		for i in c.get(list).size():
			var a: AnimatableBody3D = c.get(list)[i]["body"]
			var b: AnimatableBody3D = twin.get(list)[i]["body"]
			var sa: Shape3D = (a.get_child(0) as CollisionShape3D).shape
			var sb: Shape3D = (b.get_child(0) as CollisionShape3D).shape
			same_bodies = same_bodies and sa.get_class() == sb.get_class() and a.position == b.position
			if sa is BoxShape3D:
				same_bodies = same_bodies and (sa as BoxShape3D).size == (sb as BoxShape3D).size
			if sa is CylinderShape3D:
				same_bodies = same_bodies and is_equal_approx((sa as CylinderShape3D).radius, (sb as CylinderShape3D).radius) \
					and is_equal_approx((sa as CylinderShape3D).height, (sb as CylinderShape3D).height)
	_t.check("(d) barge and lift colliders and bodies are the same with a recipe", same_bodies)
	var facts_match := true
	var poses_match := true
	var far := Vector3(5000, 500, 5000)
	for tick in 90:
		facts_match = facts_match and c.step(0.05, far, Vector3(20, 0, 0), null, false) == twin.step(0.05, far, Vector3(20, 0, 0), null, false)
		for i in c.barges.size():
			poses_match = poses_match and c.barge_position(i) == twin.barge_position(i)
		for i in c.lifts.size():
			poses_match = poses_match and is_equal_approx(c.lift_top(i), twin.lift_top(i))
		for i in c.launchers.size():
			var arm_a: MeshInstance3D = c.launchers[i]["arm"]
			var arm_b: MeshInstance3D = twin.launchers[i]["arm"]
			if arm_a != null and arm_b != null:
				poses_match = poses_match and arm_a.basis.is_equal_approx(arm_b.basis)
	_t.check("(d) 4.5 s of steps give the same facts", facts_match)
	_t.check("(d) 4.5 s of steps give the same barge, lift and arm poses", poses_match)
	# A recipe whose GLB is missing draws the primitive.
	var missing = _specs(false)
	for spec: Dictionary in missing:
		if spec["id"] == "cannon_skin":
			spec["recipe"] = "no_such_contraption"
	var m = _make(missing)
	_t.check("(d) a missing recipe GLB falls back to the primitive barrel", _tagged(m).is_empty() and _primitive_count(m, "cannon_skin", "CylinderMesh") == 1)
	c.queue_free()
	twin.queue_free()
	m.queue_free()
