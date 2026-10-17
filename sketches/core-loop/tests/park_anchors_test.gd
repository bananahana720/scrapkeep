extends SceneTree
# Placeholder burndown: the anchors family (tools/blender/park/anchors.py), the harpoon anchor posts a greybox:anchor_field
# park row will draw through a MultiMesh instead of grey boxes.
# (a) Each of the 15 recipe GLBs (5 families x 3 variants) exists and loads.
# (b) Its render mesh is one mesh with one surface and at most 400 triangles (the instanced-post cap).
# (c) The render mesh's AABB stays inside the authoring contract: x and z in [-4.05, 4.05], y in [-1.05, 9.05].
# (d) It carries the <id>-col collision mesh (ledges.py convention; never drawn).
# Evidence limit: file shape and bounds only; no look, no loader integration (place_anchor_field still draws boxes).

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

const DIR := "res://assets/models/park/"
const FAMILIES := ["hoodoo", "basalt", "timber", "saguaro", "cairn"]
const VARIANTS := ["a", "b", "c"]
const MAX_TRIS := 400
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
	quit(_t.verdict())


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
