extends SceneTree
# Placeholder burndown: the anchors family (tools/blender/park/anchors.py), the harpoon anchor posts an anchor field row
# with an anchors kit recipe (park_recipes.gd ANCHOR_KITS) draws through one MultiMesh instead of grey boxes.
# (a) Each of the 15 recipe GLBs (5 families x 3 variants) exists and loads.
# (b) Its render mesh is one mesh with one surface and at most 1,000 triangles (the instanced-post cap; 700 before the 19 Oct ruling on #149, 400 before the soft-toy pass)
#     and carries vertex colour (not near-white) and normals, which the soft-toy bake and smooth shading write.
# (c) The render mesh's AABB stays inside the authoring contract: x and z in [-4.05, 4.05], y in [-1.05, 9.05].
# (d) It carries the <id>-col collision mesh (ledges.py convention; never drawn).
# (e) A kit row places through place_row: the same posts and box colliders as greybox:anchor_field and one Posts view
#     (one draw) holding the row's variant mesh in the enamel slot, every post drawn once over its collider, stretched
#     along Y only by tall / 10 with authored y -1 on the collider's bottom, and square to its collider (quarter turns in
#     the row's space, on a row with a yaw of 30 degrees).
# (f) A kit row does not stand in, and its preload list is its three variants.
# (g) Fitted colliders (anchors/anchor_fit.json, #241, hull option (a)): a row whose (variant, size[1]) is in the table has
#     posts x bands shapes. A band the drawn mesh enters is one ConvexPolygonShape3D, shared by every post, hull of the mesh
#     inside the band (its points within the band's h, +-0.01; its XZ extent inside the table box's plus HULL_IN_BOX_M);
#     a band the mesh never enters keeps its table box, turned and swapped. Every shape's basis is anchor_turn(row, k) (odd
#     turns present) and its origin is the post foot.
#     (h) no fitted box leaves the old 8 m footprint; (i) an unlisted pair keeps one 8 m box per post and a greybox row
#     is untouched; (j) the table's GLB sha256s match the GLBs on disk (a GLB rebuild without a table rebuild fails);
#     (k) a radius 1 sphere cast along a corner diagonal of a fitted post stops within 0.5 m of the drawn mesh.
# Evidence limit: file shape, bounds and placement data only; no look (no render), no frame cost.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

const DIR := "res://assets/models/park/"
const FAMILIES := ["hoodoo", "basalt", "timber", "saguaro", "cairn"]
const VARIANTS := ["a", "b", "c"]
const MAX_TRIS := 1000
# How far a hull's XZ extent may exceed its table box (measured over every listed row, printed by (g); the box was fit to the mesh).
const HULL_IN_BOX_M := 0.06
const XZ_LIMIT := 4.05
const Y_MIN := -1.05
const Y_MAX := 9.05

var _t := T.new("park_anchors_test")
var _worst_over := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for fam: String in FAMILIES:
		for v: String in VARIANTS:
			_check("anchor_%s_%s" % [fam, v])
		_place("anchor_" + fam)
	_fitted()
	_stale()
	_probe()
	quit(_t.verdict())


func _place(recipe: String) -> void:
	var row := {"id": "kit_" + recipe, "element": "anchor_field", "at": [0, 0], "y": null, "size": [120, 14, 90],
		"yaw_deg": 30, "ride_fact": "", "recipe": recipe, "stamp": "", "budget": "detail"}
	var grey := row.duplicate()
	grey["recipe"] = ParkRecipes.GREYBOX + "anchor_field"
	var parent := Node3D.new()
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var node: Node3D = ParkRecipes.place_row(row, parent, flat)
	var plain: Node3D = ParkRecipes.place_row(grey, parent, flat)
	var posts := int(node.get_meta("anchor_posts", 0))
	var shapes := node.find_children("*", "CollisionShape3D", true, false)
	_t.check("(e) %s keeps greybox's posts and colliders" % recipe, posts > 1 and posts == int(plain.get_meta("anchor_posts", -1))
		and shapes.size() == posts * maxi(1, ParkRecipes.anchor_fit_boxes(row).size()) and plain.find_children("*", "CollisionShape3D", true, false).size() == posts, "posts %d shapes %d" % [posts, shapes.size()])
	_t.check("(e) %s draws the kit, not grey posts" % recipe, node.get_meta("anchor_kit", false) and not plain.get_meta("anchor_kit", true))
	var tall := 14.0 + ParkRecipes.ANCHOR_SINK_M
	var bad := []
	var view := node.get_node_or_null("Posts") as MultiMeshInstance3D
	var scene := _scene(ParkRecipes.anchor_paths(recipe)[ParkRecipes.anchor_variant(row)])
	var want: Mesh = null
	for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if not String(m.name).ends_with(ParkRecipes.COL_SUFFIX):
			want = m.mesh
	scene.free()
	if view == null or view.multimesh.mesh != want or view.material_override == null or view.material_override.resource_name != "enamel":
		bad.append("Posts view, mesh or material")
	# The headless renderer keeps no MultiMesh instance data, so the transforms come from the one function that fills them.
	var draws := ParkRecipes.anchor_draws(row, ParkRecipes.anchor_posts(row), flat, node.transform, true)
	if view != null and view.multimesh.instance_count != draws.size():
		bad.append("Posts holds %d, want %d" % [view.multimesh.instance_count, draws.size()])
	var shapes_at := {}
	for shape: CollisionShape3D in shapes:
		shapes_at[Vector2(snappedf(shape.position.x, 0.01), snappedf(shape.position.z, 0.01))] = true
	for k in draws.size():
		var local: Transform3D = draws[k]
		var xf := node.transform * local
		if absf(xf.basis.y.length() - tall / 10.0) > 0.001 or absf(xf.basis.x.length() - 1.0) > 0.001 or absf(xf.basis.x.y) > 0.001:
			bad.append("post %d stretch %s" % [k, xf.basis])
		if absf(xf.origin.y - (-ParkRecipes.ANCHOR_SINK_M + tall / 10.0)) > 0.001:
			bad.append("post %d base %.3f" % [k, xf.origin.y])
		if not shapes_at.has(Vector2(snappedf(local.origin.x, 0.01), snappedf(local.origin.z, 0.01))):
			bad.append("post %d has no collider under it" % k)
		# Square to its collider, which turns with the row: a quarter turn in the node's space.
		var turn := fposmod(atan2(local.basis.x.z, local.basis.x.x), PI * 0.5)
		if minf(turn, PI * 0.5 - turn) > 0.001:
			bad.append("post %d turn %.3f" % [k, turn])
	_t.check("(e) %s draws every post once in its variant, stretched on Y over its collider" % recipe, draws.size() == posts and bad.is_empty(), "drawn %d of %d; %s" % [draws.size(), posts, str(bad.slice(0, 3))])
	_t.check("(f) %s does not stand in and preloads its three variants" % recipe, not ParkRecipes.stands_in(row) and ParkRecipes.row_paths(row) == ParkRecipes.anchor_paths(recipe))
	parent.free()


func _scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_INDEX] != null:
			n += arrays[Mesh.ARRAY_INDEX].size() / 3
		else:
			n += arrays[Mesh.ARRAY_VERTEX].size() / 3
	return n


# The node's transform relative to the scene root (the scene is not in the tree, so no global_transform).
func _local_to_root(node: Node3D, scene: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != scene:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _check(id: String) -> void:
	var scene := _scene(DIR + id + ".glb")
	if not _t.check("(a) %s.glb exists and loads" % id, scene != null):
		return
	var render: Array = []
	var col: Array = []
	for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		(col if String(m.name).ends_with(ParkRecipes.COL_SUFFIX) else render).append(m)
	var tris := 0
	var surfaces := 0
	var box := AABB()
	for k in render.size():
		var m: MeshInstance3D = render[k]
		tris += _tris(m.mesh)
		surfaces += m.mesh.get_surface_count()
		var b: AABB = _local_to_root(m, scene) * m.mesh.get_aabb()
		box = b if k == 0 else box.merge(b)
	_t.check("(b) %s has one render mesh with one surface" % id, render.size() == 1 and surfaces == 1, "meshes %d surfaces %d" % [render.size(), surfaces])
	var colours := 0
	var normals := 0
	var bright := 0
	var total := 0
	for m: MeshInstance3D in render:
		for si in m.mesh.get_surface_count():
			var arrays := m.mesh.surface_get_arrays(si)
			var cols = arrays[Mesh.ARRAY_COLOR]
			if cols != null and cols.size() > 0:
				colours += 1
				for c: Color in cols:
					total += 1
					if c.r > 0.95 and c.g > 0.95 and c.b > 0.95:
						bright += 1
			var nrm = arrays[Mesh.ARRAY_NORMAL]
			if nrm != null and nrm.size() > 0:
				normals += 1
	_t.check("(b) %s render mesh has ARRAY_COLOR, not uniformly near-white" % id, colours == surfaces and total > 0 and bright * 2 < total, "colour surfaces %d of %d, near-white %d of %d" % [colours, surfaces, bright, total])
	_t.check("(b) %s render mesh has ARRAY_NORMAL" % id, normals == surfaces and surfaces > 0, "normal surfaces %d of %d" % [normals, surfaces])
	_t.check("(b) %s render mesh is at most %d triangles" % [id, MAX_TRIS], tris > 0 and tris <= MAX_TRIS, "tris %d" % tris)
	var lo := box.position
	var hi := box.end
	_t.check("(c) %s AABB inside x,z [-%.2f, %.2f] and y [%.2f, %.2f]" % [id, XZ_LIMIT, XZ_LIMIT, Y_MIN, Y_MAX],
		not render.is_empty() and lo.x >= -XZ_LIMIT and hi.x <= XZ_LIMIT and lo.z >= -XZ_LIMIT and hi.z <= XZ_LIMIT and lo.y >= Y_MIN and hi.y <= Y_MAX,
		"%s to %s" % [lo, hi])
	_t.check("(d) %s has a -col mesh named %s-col" % [id, id], scene.find_child(id + "-col", true, false) != null and not col.is_empty())
	scene.free()


func _fit_row(recipe: String, size_y: float, fitted: bool) -> Dictionary:
	for n in 64:
		var row := {"id": "fit_%s_%d" % [recipe, n], "element": "anchor_field", "at": [0, 0], "y": null, "size": [120, size_y, 90],
			"yaw_deg": 30, "ride_fact": "", "recipe": recipe, "stamp": "", "budget": "detail"}
		if ParkRecipes.anchor_fit_boxes(row).is_empty() != fitted:
			return row
	return {}


func _fitted() -> void:
	var flat := func(_x: float, _z: float) -> float: return 3.0
	var rows := 0
	var posts_fitted := 0
	var total_posts := 0
	var inside := true
	var table: Dictionary = ParkRecipes.anchor_fit_table()
	for key: String in table["fits"]:
		for entry: Dictionary in table["fits"][key]:
			for b: Dictionary in entry["boxes"]:
				inside = inside and b["x"][0] >= -4.0 and b["x"][1] <= 4.0 and b["z"][0] >= -4.0 and b["z"][1] <= 4.0
	_t.check("(h) every fitted box lies inside the old 8 m footprint", inside and table["fits"].size() == 12)
	for fam: String in FAMILIES:
		var recipe := "anchor_" + fam
		for entry_size in [2.0, 6.0, 10.0, 14.0, 18.0, 4.0]:
			var row := _fit_row(recipe, entry_size, true)
			if row.is_empty():
				continue
			var parent := Node3D.new()
			var node: Node3D = ParkRecipes.place_row(row, parent, flat)
			var boxes := ParkRecipes.anchor_fit_boxes(row)
			var posts := ParkRecipes.anchor_posts(row)
			var shapes := node.find_children("*", "CollisionShape3D", true, false)
			rows += 1
			posts_fitted += posts.size()
			_t.check("(g) %s size %s: posts %d x boxes %d shapes" % [recipe, entry_size, posts.size(), boxes.size()],
				shapes.size() == posts.size() * boxes.size(), "shapes %d" % shapes.size())
			var inv := node.transform.affine_inverse()
			var bad := []
			var odd_seen := 0
			var hull_bands := 0
			var distinct := {}
			var per_band: Array = []
			per_band.resize(boxes.size())
			for i in boxes.size():
				per_band[i] = {}
			for k in posts.size():
				var turn := ParkRecipes.anchor_turn(row, k)
				var odd := ParkRecipes.anchor_quarters(row, k) % 2 == 1
				odd_seen += 1 if odd else 0
				var foot := inv * Vector3(posts[k].x, 3.0, posts[k].y)
				for i in boxes.size():
					var b: Dictionary = boxes[i]
					var shape: CollisionShape3D = shapes[k * boxes.size() + i]
					if shape.shape is ConvexPolygonShape3D:
						var hull := shape.shape as ConvexPolygonShape3D
						per_band[i][hull] = true
						distinct[hull] = true
						if not shape.transform.basis.is_equal_approx(turn) or shape.transform.origin.distance_to(foot) > 0.001:
							bad.append("post %d band %d frame" % [k, i])
						if k == 0:
							hull_bands += 1
							var lo := Vector3(INF, INF, INF)
							var hi := -lo
							for pt in hull.points:
								lo = lo.min(pt)
								hi = hi.max(pt)
							var over := maxf(maxf(float(b["x"][0]) - lo.x, hi.x - float(b["x"][1])), maxf(float(b["z"][0]) - lo.z, hi.z - float(b["z"][1])))
							_worst_over = maxf(_worst_over, over)
							if lo.y < float(b["h"][0]) - 0.01 or hi.y > float(b["h"][1]) + 0.01:
								bad.append("band %d h %.3f..%.3f outside %s" % [i, lo.y, hi.y, b["h"]])
							if over > HULL_IN_BOX_M:
								bad.append("band %d hull sticks %.3f m out of its box" % [i, over])
					else:
						var c := Vector3((b["x"][0] + b["x"][1]) * 0.5, (b["h"][0] + b["h"][1]) * 0.5, (b["z"][0] + b["z"][1]) * 0.5)
						var sx: float = b["x"][1] - b["x"][0]
						var sz: float = b["z"][1] - b["z"][0]
						var want_size := Vector3(sz, b["h"][1] - b["h"][0], sx) if odd else Vector3(sx, b["h"][1] - b["h"][0], sz)
						if not shape.shape is BoxShape3D or (shape.shape as BoxShape3D).size.distance_to(want_size) > 0.001 or shape.position.distance_to(foot + turn * c) > 0.001:
							bad.append("post %d band %d fallback box" % [k, i])
			var shared := true
			for i in boxes.size():
				shared = shared and (per_band[i].size() <= 2)
			_t.check("(g) %s size %s: %d hull bands, basis = anchor_turn (%d odd posts), hulls shared (%d distinct over %d posts)" % [recipe, entry_size, hull_bands, odd_seen, distinct.size(), posts.size()],
				bad.is_empty() and odd_seen > 0 and hull_bands > 0 and shared and distinct.size() <= boxes.size(), str(bad.slice(0, 3)))
			parent.free()
	print("hull XZ overshoot of the table box, worst over bands of the rows exercised: %.4f m" % _worst_over)
	_t.check("(g) fitted rows exercised (%d rows, %d posts)" % [rows, posts_fitted], rows >= 8)
	# (i) control: an unlisted height keeps one 8 m box per post; greybox is the same path as before.
	var control := _fit_row("anchor_hoodoo", 13.0, false)
	var parent2 := Node3D.new()
	var kit_node: Node3D = ParkRecipes.place_row(control, parent2, flat)
	var kit_shapes := kit_node.find_children("*", "CollisionShape3D", true, false)
	var kit_posts := int(kit_node.get_meta("anchor_posts", 0))
	var one := kit_posts > 1 and kit_shapes.size() == kit_posts
	for sh: CollisionShape3D in kit_shapes:
		one = one and (sh.shape as BoxShape3D).size == Vector3(8.0, 14.0, 8.0)
	_t.check("(i) an unlisted size keeps one 8 m box per post", one, "posts %d shapes %d" % [kit_posts, kit_shapes.size()])
	var grey := control.duplicate()
	grey["recipe"] = ParkRecipes.GREYBOX + "anchor_field"
	var grey_node: Node3D = ParkRecipes.place_row(grey, parent2, flat)
	var grey_shapes := grey_node.find_children("*", "CollisionShape3D", true, false)
	var grey_one := grey_shapes.size() == int(grey_node.get_meta("anchor_posts", -1)) and grey_shapes.size() > 1
	for sh: CollisionShape3D in grey_shapes:
		grey_one = grey_one and (sh.shape as BoxShape3D).size == Vector3(8.0, 14.0, 8.0)
	_t.check("(i) a greybox row keeps one 8 m box per post", grey_one)
	parent2.free()


func _stale() -> void:
	var glbs: Dictionary = ParkRecipes.anchor_fit_table().get("glbs", {})
	_t.check("(j) the table lists all 15 GLBs", glbs.size() == 15)
	for id: String in glbs:
		var path := DIR + id + ".glb"
		_t.check("(j) %s matches the table's sha256" % id, FileAccess.get_sha256(path) == String(glbs[id]), "GLB rebuilt without rebuilding anchor_fit.json")


# (k) A radius 1 sphere at h 2 is cast at a placed fitted hoodoo post along each corner diagonal of its table boxes (from 10 m out,
# the rolling-ball case the probe in park_anchor_corner_probe_test.gd forces). It must stop, and its surface must end within
# 0.5 m of the drawn mesh (the box head stopped 1.5 to 2.5 m short of it at such corners).
func _probe() -> void:
	var row := _fit_row("anchor_hoodoo", 10.0, true)
	var boxes := ParkRecipes.anchor_fit_boxes(row)
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var holder := Node3D.new()
	root.add_child(holder)
	var node: Node3D = ParkRecipes.place_row(row, holder, flat)
	var posts := ParkRecipes.anchor_posts(row)
	_t.check("(k) the fitted hoodoo size 10 places posts", posts.size() > 0 and not boxes.is_empty())
	var draws := ParkRecipes.anchor_draws(row, posts, flat, node.transform, true)
	var mesh: Mesh = (node.get_node("Posts") as MultiMeshInstance3D).multimesh.mesh
	var faces := mesh.get_faces()
	var space := holder.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 1.0
	var worst := 0.0
	var best := INF
	var casts := 0
	var bad := []
	for k in mini(posts.size(), 3):
		var xf: Transform3D = node.global_transform * (draws[k] as Transform3D)
		var world_faces := PackedVector3Array()
		for f in faces:
			world_faces.append(xf * f)
		var turn := ParkRecipes.anchor_turn(row, k)
		var foot: Vector3 = node.global_transform * (node.transform.affine_inverse() * Vector3(posts[k].x, 0.0, posts[k].y))
		for b: Dictionary in boxes:
			if float(b["h"][0]) > 2.0 or float(b["h"][1]) < 2.0:
				continue
			for sx in [0, 1]:
				for sz in [0, 1]:
					var corner: Vector3 = node.global_transform.basis * (turn * Vector3(b["x"][sx], 0.0, b["z"][sz]))
					var out := Vector3(corner.x, 0.0, corner.z).normalized()
					var aim := foot + corner
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = ball
					# From 10 m out, clear of the field's next post (20 m pitch); a start inside another post is skipped.
					query.transform = Transform3D(Basis.IDENTITY, Vector3(aim.x, 2.0, aim.z) + out * 10.0)
					query.motion = -out * 11.0
					if not space.intersect_shape(query, 1).is_empty():
						continue
					var rest := space.cast_motion(query)
					casts += 1
					var at := query.transform.origin + query.motion * rest[0]
					var gap := INF
					for i in range(0, world_faces.size(), 3):
						gap = minf(gap, _tri_dist(at, world_faces[i], world_faces[i + 1], world_faces[i + 2]))
					gap -= 1.0
					worst = maxf(worst, gap)
					best = minf(best, gap)
					if rest[0] >= 1.0 or gap > 0.5 or gap < -0.05:
						bad.append("post %d corner %s: rest %.3f air %.3f" % [k, aim, rest[0], gap])
	_t.check("(k) corner-diagonal casts stop within 0.5 m of the drawn mesh (%d casts, air %.3f to %.3f m)" % [casts, best, worst], casts >= 4 and bad.is_empty(), str(bad.slice(0, 3)))
	holder.free()


static func _tri_dist(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := b - a
	var ac := c - a
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return ap.length()
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return bp.length()
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return (p - (a + ab * (d1 / (d1 - d3)))).length()
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return cp.length()
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return (p - (a + ac * (d2 / (d2 - d6)))).length()
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return (p - (b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6))))).length()
	var denom := 1.0 / (va + vb + vc)
	return (p - (a + ab * (vb * denom) + ac * (vc * denom))).length()
