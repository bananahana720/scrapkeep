extends SceneTree

const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const T := preload("res://tests/support/t.gd")

# Every built ambient GLB against its row in ambient_kinds.gd: triangles inside the row's band and the ambient class
# (800 to 6,000), exactly the three clips idle, move and react on one AnimationPlayer (each 1 to 3 s), no collision object,
# standing height within 15% of height_m, and one surface with one material (one draw). Kinds whose GLB is not built yet
# are skipped; the count line says how many were read.
# The mesh audit (AMBITION-BRIEF, models row) welds positions and asks for no open edge, no edge shared by more than two
# faces and no face whose winding disagrees with its normals. The loop-seam check (rigs and motion row) samples every
# track: idle and move end on their first pose, and react's last pose equals its pose at REACT_HOLD_S (the hold loop).

const HEIGHT_TOL := 0.15
const CLIP_S := Vector2(1.0, 3.0)
const WELD := 1e5
# Seam tolerance in metres or radians: one 30 fps key of sampling drift, far under a visible pop.
const SEAM := 0.002
const HOLD := 0.003

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
		_mesh_audit(id, node)
		_seams(id, node)
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


func _mesh_audit(id: String, node: Node) -> void:
	var open := 0
	var over := 0
	var flipped := 0
	for mi: MeshInstance3D in _meshes(node):
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var weld := {}
			var key := PackedInt32Array()
			for p in verts:
				var k := Vector3i((p * WELD).round())
				if not weld.has(k):
					weld[k] = weld.size()
				key.append(weld[k])
			var edges := {}
			for f in idx.size() / 3:
				var i := [idx[f * 3], idx[f * 3 + 1], idx[f * 3 + 2]]
				# Godot front faces wind clockwise, so the cross product points against the outward normal.
				var winding := (verts[i[1]] - verts[i[0]]).cross(verts[i[2]] - verts[i[0]])
				if winding.dot(normals[i[0]] + normals[i[1]] + normals[i[2]]) > 0.0:
					flipped += 1
				for e in 3:
					var a := key[i[e]]
					var b := key[i[(e + 1) % 3]]
					var edge := Vector2i(mini(a, b), maxi(a, b))
					edges[edge] = edges.get(edge, 0) + 1
			for edge in edges:
				open += 1 if edges[edge] == 1 else 0
				over += 1 if edges[edge] > 2 else 0
	_t.eq("%s has no open edge" % id, open, 0)
	_t.eq("%s has no edge on more than two faces" % id, over, 0)
	_t.eq("%s has no face wound against its normals" % id, flipped, 0)


func _seams(id: String, node: Node) -> void:
	var players := node.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1:
		return
	var player := players[0] as AnimationPlayer
	for clip in [AmbientKinds.LOOPS["idle"], AmbientKinds.LOOPS["move"]]:
		if player.has_animation(clip):
			var anim := player.get_animation(clip)
			var gap := _gap(anim, 0.0, anim.length)
			_t.check("%s %s loops without a seam" % [id, clip], gap <= SEAM, "%.5f" % gap)
	if player.has_animation(AmbientKinds.LOOPS["react"]):
		var react := player.get_animation(AmbientKinds.LOOPS["react"])
		var gap := _gap(react, AmbientKinds.REACT_HOLD_S, react.length)
		_t.check("%s react holds from %.1f s without a seam" % [id, AmbientKinds.REACT_HOLD_S], gap <= HOLD, "%.5f" % gap)


# The largest difference between two times over every transform track (metres for position and scale, radians for rotation).
func _gap(anim: Animation, a: float, b: float) -> float:
	var worst := 0.0
	for t in anim.get_track_count():
		match anim.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				worst = maxf(worst, anim.position_track_interpolate(t, a).distance_to(anim.position_track_interpolate(t, b)))
			Animation.TYPE_ROTATION_3D:
				worst = maxf(worst, anim.rotation_track_interpolate(t, a).angle_to(anim.rotation_track_interpolate(t, b)))
			Animation.TYPE_SCALE_3D:
				worst = maxf(worst, anim.scale_track_interpolate(t, a).distance_to(anim.scale_track_interpolate(t, b)))
	return worst
