extends SceneTree
# 2026-10-19 (wave 20 zero-placeholder bar, park_islands): ore_adit, tram_head, keel_rib_w and keel_rib_e got real pieces
# (tools/blender/park/islands_pieces.py). The coordinator's rule: the collider in game is identical to what the greybox
# stand-in gave, so the traversal lines do not move.
# (a) The four rows keep their at, y, size, yaw, element, stamp, budget and routes (pinned below); only recipe and fit moved.
# (b) For each row, the old row (greybox:<element>, no fit) and the new row are placed through place_row on one sloped
#     ground. Both nodes have the same global transform; both Collider bodies sit on the same layer and mask; both give
#     the same ride sensor (presence, box, transform).
# (c) Stamped rows (tram_head, ore_adit: a stamp and no absolute y): place_row drops a greybox stand-in's Collider, so the
#     old collider is none, and the new one is none as well: the GLB carries no -col and the row's drape fit keeps its node
#     on seat(). Zero collision shapes in both.
# (d) Keel ribs (stamp "", y null): the old Collider is one BoxShape3D of the row's extent standing on the ground; the new one
#     is the GLB's -col trimesh. Compared in the row node's frame: the trimesh has 12 triangles on exactly the box's eight
#     corners, every triangle lies in one box face, their areas add up to the box's surface, and the collision shape's
#     global transform is the old shape's within 1e-4.
# Evidence limit: shape type differs for the ribs (BoxShape3D versus a 12-triangle ConcavePolygonShape3D of the same surface),
# a trimesh being the only collider park_recipes.gd takes from a GLB; this test proves the geometry equal, not Jolt's contact
# response to it. No ride, look or feel claim.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

const EPS := 0.0001
const PARK := "res://src/world/park/park_islands.json"
# id: [element, at, y, size, yaw, stamp, budget, routes, recipe]
const PINNED := {
	"tram_head": ["ledge", [118, -398], null, [30, 3, 30], 0.0, "plateau", "landform", ["east", "fan_east"], "islands_tram_head"],
	"ore_adit": ["tunnel", [196, -62], null, [30, 0.01, 14], 0.0, "plateau", "park_large", ["east", "fan_east"], "islands_ore_adit"],
	"keel_rib_w": ["ledge", [-27.9, 465.8], null, [50, 12, 3], -156.5, "", "detail", [], "islands_keel_rib"],
	"keel_rib_e": ["ledge", [27.9, 465.8], null, [50, 12, 3], 156.5, "", "detail", [], "islands_keel_rib"],
}

var _t := T.new("park_islands_pieces_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rows := {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	for r: Dictionary in parsed["park_rows"]:
		rows[String(r["id"])] = r
	var parent := Node3D.new()
	root.add_child(parent)
	for id: String in PINNED:
		_check_row(id, rows, parent)
	parent.free()
	quit(_t.verdict())


func _ground(x: float, z: float) -> float:
	return 100.0 + 0.1 * x - 0.05 * z


func _check_row(id: String, rows: Dictionary, parent: Node3D) -> void:
	var want: Array = PINNED[id]
	if not _t.check("(a) %s is a park row" % id, rows.has(id)):
		return
	var row: Dictionary = rows[id]
	var same: bool = String(row["element"]) == want[0] and _nums(row["at"], want[1]) and row["y"] == want[2] and _nums(row["size"], want[3]) \
		and absf(float(row["yaw_deg"]) - float(want[4])) < EPS and String(row["stamp"]) == want[5] and String(row["budget"]) == want[6] \
		and str(row["routes"]) == str(want[7])
	_t.check("(a) %s keeps its at, y, size, yaw, element, stamp, budget and routes" % id, same, str(row))
	_t.eq("(a) %s recipe" % id, String(row["recipe"]), want[8])
	var stamped := String(row["stamp"]) != ""
	_t.eq("(a) %s fit" % id, String(row.get("fit", "")), "drape" if stamped else "")
	var old := row.duplicate(true)
	old["recipe"] = ParkRecipes.GREYBOX + String(row["element"])
	old.erase("fit")
	var published := func(_fact: String, _at: Vector3) -> void: pass
	var a := ParkRecipes.place_row(old, parent, _ground, published)
	var b := ParkRecipes.place_row(row, parent, _ground, published)
	if not _t.check("(b) %s places old and new" % id, a != null and b != null):
		return
	_t.check("(b) %s new row is the GLB, not a greybox stand-in" % id, b != null and not ParkRecipes.stands_in(row) and b.get_node_or_null("Greybox") == null)
	_t.check("(b) %s same node transform" % id, _same_xf(a.global_transform, b.global_transform), "%s vs %s" % [a.global_transform, b.global_transform])
	var ba := a.get_node_or_null("Collider") as StaticBody3D
	var bb := b.get_node_or_null("Collider") as StaticBody3D
	var shapes_a := _shapes(ba)
	var shapes_b := _shapes(bb)
	if bb != null:
		_t.check("(b) %s new Collider layer and mask" % id, bb.collision_layer == 1 and bb.collision_mask == 0, "%d/%d" % [bb.collision_layer, bb.collision_mask])
	if ba != null:
		_t.check("(b) %s old and new Collider share layer and mask" % id, bb != null and ba.collision_layer == bb.collision_layer and ba.collision_mask == bb.collision_mask)
	_check_sensor(id, a, b)
	if stamped:
		_t.eq("(c) %s old collision shapes (the stamp is the shape)" % id, shapes_a.size(), 0)
		_t.eq("(c) %s new collision shapes (a drape GLB has no -col)" % id, shapes_b.size(), 0)
		_t.check("(c) %s stamp_replaces still describes the old row" % id, ParkRecipes.stamp_replaces(old) and not ParkRecipes.stamp_replaces(row))
		return
	_t.eq("(d) %s old collision shapes" % id, shapes_a.size(), 1)
	_t.eq("(d) %s new collision shapes" % id, shapes_b.size(), 1)
	if shapes_a.size() != 1 or shapes_b.size() != 1:
		return
	var sa := shapes_a[0]
	var sb := shapes_b[0]
	_t.check("(d) %s old collider is a BoxShape3D" % id, sa.shape is BoxShape3D)
	_t.check("(d) %s new collider is the GLB's trimesh" % id, sb.shape is ConcavePolygonShape3D)
	if not (sa.shape is BoxShape3D and sb.shape is ConcavePolygonShape3D):
		return
	var size: Array = row["size"]
	var extent := Vector3(float(size[2]), float(size[1]), float(size[0]))
	var box := sa.shape as BoxShape3D
	_t.check("(d) %s old box is the row's extent %s" % [id, extent], box.size.is_equal_approx(extent), str(box.size))
	# Both shapes in the row node's frame: the box's eight corners and the trimesh's triangles.
	var inv := a.global_transform.affine_inverse()
	var corners: Array[Vector3] = []
	for sx in [-0.5, 0.5]:
		for sy in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				corners.append(inv * (sa.global_transform * (Vector3(sx, sy, sz) * box.size)))
	var faces := (sb.shape as ConcavePolygonShape3D).get_faces()
	var to_node := inv * sb.global_transform
	var tris := faces.size() / 3
	_t.eq("(d) %s trimesh triangles" % id, tris, 12)
	var on_corners := true
	var area := 0.0
	var in_face := true
	var seen := {}
	for t in tris:
		var p: Array[Vector3] = []
		for k in 3:
			var v := to_node * faces[t * 3 + k]
			p.append(v)
			var found := -1
			for c in corners.size():
				if corners[c].distance_to(v) <= EPS:
					found = c
			on_corners = on_corners and found >= 0
			if found >= 0:
				seen[found] = true
		area += 0.5 * (p[1] - p[0]).cross(p[2] - p[0]).length()
		# one face: the three corners agree on one local coordinate of the old box
		var local := p.map(func(v: Vector3) -> Vector3: return (sa.global_transform.affine_inverse() * (a.global_transform * v)) / box.size)
		var flat := false
		for axis in 3:
			flat = flat or (absf(local[0][axis] - local[1][axis]) <= EPS and absf(local[1][axis] - local[2][axis]) <= EPS and absf(absf(local[0][axis]) - 0.5) <= EPS)
		in_face = in_face and flat
	var surface := 2.0 * (extent.x * extent.y + extent.y * extent.z + extent.x * extent.z)
	_t.check("(d) %s every trimesh vertex is one of the box's eight corners, all eight used" % id, on_corners and seen.size() == 8)
	_t.check("(d) %s every triangle lies in one box face" % id, in_face)
	_t.check("(d) %s triangle areas add up to the box surface %.3f" % [id, surface], absf(area - surface) <= 0.001, "%.4f" % area)
	# the shapes' global places: the box's centre against the trimesh vertices' centre
	var centre_a := sa.global_position
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for k in faces.size():
		var w := sb.global_transform * faces[k]
		lo = lo.min(w)
		hi = hi.max(w)
	var centre_b := (lo + hi) * 0.5
	var old_world: Array[Vector3] = []
	for c in corners:
		old_world.append(a.global_transform * c)
	var olo := Vector3(INF, INF, INF)
	var ohi := Vector3(-INF, -INF, -INF)
	for w in old_world:
		olo = olo.min(w)
		ohi = ohi.max(w)
	_t.check("(d) %s global AABB of the collider is the old box's, within 1e-4" % id, olo.distance_to(lo) <= EPS and ohi.distance_to(hi) <= EPS, "%s %s vs %s %s" % [olo, ohi, lo, hi])
	_t.check("(d) %s old box centre is the node's ground point raised half the height" % id, centre_a.distance_to(a.global_transform * Vector3(0, extent.y * 0.5, 0)) <= EPS)
	_t.check("(d) %s node stands on the ground at its centre" % id, absf(a.global_position.y - _ground(a.global_position.x, a.global_position.z)) <= EPS)


func _nums(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in got.size():
		if absf(float(got[i]) - float(want[i])) > EPS:
			return false
	return true


func _shapes(body: StaticBody3D) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	if body != null:
		for c in body.get_children():
			if c is CollisionShape3D:
				out.append(c)
	return out


func _check_sensor(id: String, a: Node3D, b: Node3D) -> void:
	var ra := a.get_node_or_null("Ride") as Area3D
	var rb := b.get_node_or_null("Ride") as Area3D
	_t.eq("(b) %s ride sensor present in both or neither" % id, ra != null, rb != null)
	if ra == null or rb == null:
		return
	var sa := (ra.get_child(0) as CollisionShape3D)
	var sb := (rb.get_child(0) as CollisionShape3D)
	_t.check("(b) %s ride sensor box and transform match" % id, (sa.shape as BoxShape3D).size.is_equal_approx((sb.shape as BoxShape3D).size)
		and _same_xf(sa.global_transform, sb.global_transform))


func _same_xf(x: Transform3D, y: Transform3D) -> bool:
	return x.origin.distance_to(y.origin) <= EPS and x.basis.x.distance_to(y.basis.x) <= EPS and x.basis.y.distance_to(y.basis.y) <= EPS \
		and x.basis.z.distance_to(y.basis.z) <= EPS
