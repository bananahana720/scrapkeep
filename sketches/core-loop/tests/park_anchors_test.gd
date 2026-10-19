extends SceneTree
# Placeholder burndown: the anchors family (tools/blender/park/anchors.py), the harpoon anchor posts an anchor field row
# with an anchors kit recipe (park_recipes.gd ANCHOR_KITS) draws through one MultiMesh instead of grey boxes.
# (a) Each of the 15 recipe GLBs (5 families x 3 variants) exists and loads.
# (b) Its render mesh is one mesh with one surface and at most 900 triangles (the instanced-post cap; 400 before the soft-toy pass).
# (c) The render mesh's AABB stays inside the authoring contract: x and z in [-4.05, 4.05], y in [-1.05, 9.05].
# (d) It carries the <id>-col collision mesh (ledges.py convention; never drawn).
# (e) A kit row places through place_row: the same posts and box colliders as greybox:anchor_field and one Posts view
#     (one draw) holding the row's variant mesh in the enamel slot, every post drawn once over its collider, stretched
#     along Y only by tall / 10 with authored y -1 on the collider's bottom, and square to its collider (quarter turns in
#     the row's space, on a row with a yaw of 30 degrees).
# (f) A kit row does not stand in, and its preload list is its three variants.
# Evidence limit: file shape, bounds and placement data only; no look (no render), no frame cost.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

const DIR := "res://assets/models/park/"
const FAMILIES := ["hoodoo", "basalt", "timber", "saguaro", "cairn"]
const VARIANTS := ["a", "b", "c"]
const MAX_TRIS := 900
const XZ_LIMIT := 4.05
const Y_MIN := -1.05
const Y_MAX := 9.05

var _t := T.new("park_anchors_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for fam: String in FAMILIES:
		for v: String in VARIANTS:
			_check("anchor_%s_%s" % [fam, v])
		_place("anchor_" + fam)
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
		and shapes.size() == posts and plain.find_children("*", "CollisionShape3D", true, false).size() == posts, "posts %d shapes %d" % [posts, shapes.size()])
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
	_t.check("(b) %s render mesh is at most %d triangles" % [id, MAX_TRIS], tris > 0 and tris <= MAX_TRIS, "tris %d" % tris)
	var lo := box.position
	var hi := box.end
	_t.check("(c) %s AABB inside x,z [-%.2f, %.2f] and y [%.2f, %.2f]" % [id, XZ_LIMIT, XZ_LIMIT, Y_MIN, Y_MAX],
		not render.is_empty() and lo.x >= -XZ_LIMIT and hi.x <= XZ_LIMIT and lo.z >= -XZ_LIMIT and hi.z <= XZ_LIMIT and lo.y >= Y_MIN and hi.y <= Y_MAX,
		"%s to %s" % [lo, hi])
	_t.check("(d) %s has a -col mesh named %s-col" % [id, id], scene.find_child(id + "-col", true, false) != null and not col.is_empty())
	scene.free()
