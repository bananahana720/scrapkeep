extends SceneTree

const Game := preload("res://src/game.gd")
const RecipeProps := preload("res://src/presentation/recipe_props.gd")
# The dressing cabinet's footprint in Barge space (GLB vertex probe: x -6.99..-4.85, y 0..3.22, z 7.91..9.29), kept
# clear of the teal apron, whose corners sit at x -7.25/-4.75 and z 5.75/8.25.
const CABINET := AABB(Vector3(-7.2, -0.05, 7.85), Vector3(2.4, 3.4, 1.5))

# 2026-10-09 JUKEBOX-SHOW (wave 12-F follow-up): the recipe jukebox is the one the player sees at the bay (Andrew,
# task #7, "B: show the recipe jukebox"). moss_workshop.glb is one mesh (CabinDress) whose triangles include its own
# domed jukebox cabinet at the teal pad, and that cabinet enclosed the recipe jukebox. _dress_bay now draws CabinDress
# without the triangles inside that cabinet's footprint. Checked here, all in Barge space:
# Visibility is read up to the Barge, which parks hidden until a dock.
# - A1: no visible workshop triangle lies wholly inside the cabinet footprint, while the workshop keeps its node count,
#   surface count and every triangle outside the footprint (counted against a fresh instance of the GLB).
# - A2: the moss_jukebox_ base views and its two Detail shells are present and visible, and above the pad top no other
#   visible mesh under the Barge has a vertex in the pad and cabinet column.
# `--mutate=keep-cabinet` restores the original CabinDress mesh and must make the run fail.

const WORKSHOP := "res://assets/models/moss_workshop.glb"
const PAD_TOP := 0.135

var _game
var _ticks := 0
var _failures := 0
var _mutate := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mutate="):
			_mutate = arg.trim_prefix("--mutate=")
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
		printerr("jukebox_show_test FAIL: %s %s" % [label, detail])


func _physics_process(_delta: float) -> bool:
	_ticks += 1
	if _ticks < 10:
		return false
	var bay: Node = _game.find_child("MossBay", true, false)
	_check("bay exists", bay != null)
	if bay != null:
		_run(bay)
	print("jukebox_show_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return false


func _run(bay: Node) -> void:
	var barge: Node3D = bay.find_child("Barge", true, false)
	var workshop: Node3D = barge.get_node_or_null("HeroWorkshop")
	_check("workshop dressing attached", workshop != null)
	if workshop == null:
		return
	var fresh: Node3D = (load(WORKSHOP) as PackedScene).instantiate()
	var cut := CABINET
	# A1. Same nodes; per surface, the same triangles outside the cut and none inside it.
	var live_nodes := workshop.find_children("*", "", true, false)
	var fresh_nodes := fresh.find_children("*", "", true, false)
	_check("workshop node count unchanged", live_nodes.size() == fresh_nodes.size(), "%d vs %d" % [live_nodes.size(), fresh_nodes.size()])
	var live_meshes := workshop.find_children("*", "MeshInstance3D", true, false)
	var fresh_meshes := fresh.find_children("*", "MeshInstance3D", true, false)
	_check("workshop mesh count unchanged", live_meshes.size() == fresh_meshes.size())
	var inside_total := 0
	var fresh_total := 0
	for k in mini(live_meshes.size(), fresh_meshes.size()):
		var live := live_meshes[k] as MeshInstance3D
		var orig := fresh_meshes[k] as MeshInstance3D
		_check("same mesh node " + str(orig.name), live.name == orig.name)
		_check("workshop mesh visible", _shown(live, barge))
		var mesh: Mesh = orig.mesh if _mutate == "keep-cabinet" else live.mesh
		_check("surface count unchanged", mesh.get_surface_count() == orig.mesh.get_surface_count())
		var to_barge: Transform3D = barge.global_transform.affine_inverse() * live.global_transform
		for s in mini(mesh.get_surface_count(), orig.mesh.get_surface_count()):
			var now := _split(mesh, s, to_barge, cut)
			var was := _split(orig.mesh, s, orig.transform, cut)
			_check("surface %d keeps every triangle outside the cabinet" % s, now[1] == was[1], "%d vs %d" % [now[1], was[1]])
			inside_total += now[0]
			fresh_total += was[0]
	print("jukebox_show_test: workshop nodes %d, cabinet triangles left %d of %d in the GLB" % [live_nodes.size(), inside_total, fresh_total])
	_check("dressing cabinet absent", inside_total == 0, str(inside_total))
	_check("dressing cabinet exists in the GLB", fresh_total > 300, str(fresh_total))
	fresh.free()
	# A2. The recipe jukebox is present and visible, and nothing else stands in the pad and cabinet column.
	var column := AABB(Vector3(-7.25, PAD_TOP, 5.75), Vector3(2.5, 6.0, 3.6))
	var shell_meshes: Array[Mesh] = []
	for row: Array in RecipeProps.shell_rows("moss_jukebox"):
		var scene: Node = (load(row[0]) as PackedScene).instantiate()
		for source in scene.find_children("*", "MeshInstance3D", true, false):
			shell_meshes.append((source as MeshInstance3D).mesh)
		scene.free()
	var juke_views := 0
	var shells := 0
	var intruders: Array[String] = []
	for node in barge.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not _shown(mi, barge):
			continue
		var to_barge: Transform3D = barge.global_transform.affine_inverse() * mi.global_transform
		var mesh: Mesh = mi.mesh
		if _mutate == "keep-cabinet" and workshop.is_ancestor_of(mi):
			mesh = load(WORKSHOP).instantiate().find_child("CabinDress", true, false).mesh
		var hits := _vertices_in(mesh, to_barge, column)
		var name := str(mi.name)
		var is_juke := name.begins_with("moss_jukebox_")
		var is_shell := mi.mesh in shell_meshes
		if is_juke:
			juke_views += 1
			_check(name + " inside the column", hits > 0)
		elif is_shell:
			shells += 1
			_check("jukebox shell inside the column", hits > 0)
		elif hits > 0:
			intruders.append("%s(%d)" % [name, hits])
	print("jukebox_show_test: jukebox base views %d, shells %d, other meshes in the column %s" % [juke_views, shells, intruders])
	_check("three jukebox base views", juke_views == 3, str(juke_views))
	_check("two jukebox shells", shells == 2, str(shells))
	_check("jukebox views are the only meshes above the pad", intruders.is_empty(), str(intruders))


## Drawn when the Barge is shown: visible up to the Barge (which parks hidden between docks) and on a render layer.
func _shown(mi: MeshInstance3D, barge: Node3D) -> bool:
	if mi.layers == 0:
		return false
	var node: Node = mi
	while node != null and node != barge:
		if node is Node3D and not (node as Node3D).visible:
			return false
		node = node.get_parent()
	return node == barge


## [triangles wholly inside cut, triangles not wholly inside] of one surface, in Barge space.
func _split(mesh: Mesh, surface: int, xform: Transform3D, cut: AABB) -> Array:
	var arrays := mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var inside := 0
	var outside := 0
	for t in range(0, index.size(), 3):
		if cut.has_point(xform * verts[index[t]]) and cut.has_point(xform * verts[index[t + 1]]) and cut.has_point(xform * verts[index[t + 2]]):
			inside += 1
		else:
			outside += 1
	return [inside, outside]


## Drawn vertices (those an index references) inside box, in Barge space.
func _vertices_in(mesh: Mesh, xform: Transform3D, box: AABB) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index = arrays[Mesh.ARRAY_INDEX]
		var used := {}
		if index == null:
			for i in verts.size():
				used[i] = true
		else:
			for i in index as PackedInt32Array:
				used[i] = true
		for i in used:
			if box.has_point(xform * verts[i]):
				n += 1
	return n
