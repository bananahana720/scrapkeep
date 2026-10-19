extends SceneTree

const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const T := preload("res://tests/support/t.gd")

# Every built ambient GLB against its row in ambient_kinds.gd: triangles inside the row's band and the ambient class
# (800 to 6,000), exactly the three clips idle, move and react on one AnimationPlayer (each 1 to 3 s), no collision object,
# standing height within 15% of height_m, and one surface with one material (one draw). Kinds whose GLB is not built yet
# are skipped; the count line says how many were read.

const HEIGHT_TOL := 0.15
const CLIP_S := Vector2(1.0, 3.0)

var _t := T.new("ambient_assets_test")


func _initialize() -> void:
	_run()
	quit(_t.verdict())


func _run() -> void:
	var built := 0
	for id in AmbientKinds.KINDS:
		var row: Dictionary = AmbientKinds.KINDS[id]
		var path: String = row.model
		if not ResourceLoader.exists(path):
			continue
		built += 1
		var packed := load(path) as PackedScene
		if not _t.check("%s imports as a scene" % id, packed != null, path):
			continue
		var node := packed.instantiate()
		_triangles(id, row, node)
		_clips(id, node)
		_t.eq("%s has no collision object" % id, node.find_children("*", "CollisionObject3D", true, false).size() + (1 if node is CollisionObject3D else 0), 0)
		_height(id, row, node)
		_one_draw(id, node)
		node.free()
	print("ambient assets read: %d of %d kinds" % [built, AmbientKinds.KINDS.size()])


func _meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false).filter(func(m): return (m as MeshInstance3D).mesh != null)


func _triangles(id: String, row: Dictionary, node: Node) -> void:
	var tris := 0
	for mi: MeshInstance3D in _meshes(node):
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	var band: Array = row.tris
	_t.check("%s triangles inside its row band" % id, tris >= band[0] and tris <= band[1], "%d, band %d to %d" % [tris, band[0], band[1]])
	_t.check("%s triangles inside the ambient class" % id, tris >= AmbientKinds.TRIS[0] and tris <= AmbientKinds.TRIS[1],
		"%d, class %d to %d" % [tris, AmbientKinds.TRIS[0], AmbientKinds.TRIS[1]])


func _clips(id: String, node: Node) -> void:
	var players := node.find_children("*", "AnimationPlayer", true, false)
	if not _t.eq("%s has one AnimationPlayer" % id, players.size(), 1):
		return
	var player := players[0] as AnimationPlayer
	var names := Array(player.get_animation_list())
	names.sort()
	var want := AmbientKinds.LOOPS.values()
	want.sort()
	_t.eq("%s has exactly the clips idle, move, react" % id, names, want)
	for clip in names:
		var length := player.get_animation(clip).length
		_t.check("%s %s runs 1 to 3 s" % [id, clip], length >= CLIP_S.x - 0.001 and length <= CLIP_S.y + 0.001, "%.2f s" % length)
		_t.check("%s %s keys at least one track" % [id, clip], player.get_animation(clip).get_track_count() > 0)


# The standing height: the rest pose of every mesh, taken from its bounding box in the scene root's frame.
func _height(id: String, row: Dictionary, node: Node) -> void:
	var low := INF
	var high := -INF
	for mi: MeshInstance3D in _meshes(node):
		var xf := Transform3D.IDENTITY
		var walker: Node = mi
		while walker != null and walker != node:
			if walker is Node3D:
				xf = (walker as Node3D).transform * xf
			walker = walker.get_parent()
		var box := mi.mesh.get_aabb()
		for corner in 8:
			var y := (xf * box.get_endpoint(corner)).y
			low = minf(low, y)
			high = maxf(high, y)
	var height := high - low
	var want: float = row.height_m
	_t.check("%s stands within %d%% of %.2f m" % [id, int(HEIGHT_TOL * 100.0), want], absf(height - want) <= want * HEIGHT_TOL,
		"%.3f m" % height)


func _one_draw(id: String, node: Node) -> void:
	var surfaces := 0
	var materials := {}
	for mi: MeshInstance3D in _meshes(node):
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			materials[mi.mesh.surface_get_material(s)] = true
	_t.eq("%s has one surface" % id, surfaces, 1)
	_t.eq("%s has one material" % id, materials.size(), 1)
