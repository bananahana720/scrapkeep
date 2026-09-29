extends SceneTree

# G05 limits: replacement ceiling 180 V / 120 T / 2 D, opaque, and no growth past the five boxes
# the asset replaces (four 14 x 90 x 0.5 sheets at x -103/-47/37/93, and the 276 x 0.4 x 28 tailrace).
const CEILING_V := 180
const CEILING_T := 120
const CEILING_D := 2
const FALL_X := [-103.0, -47.0, 37.0, 93.0]
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _in_box(p: Vector3, center: Vector3, size: Vector3) -> bool:
	var half := size * 0.5 + Vector3.ONE * 0.001
	return absf(p.x - center.x) <= half.x and absf(p.y - center.y) <= half.y and absf(p.z - center.z) <= half.z


func _run() -> void:
	var packed := load("res://assets/models/world_one/water_edges.glb") as PackedScene
	_check(packed != null, "water_edges.glb loads")
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var verts := 0
	var tris := 0
	var surfaces_ok := true
	var bounds_ok := true
	var opaque_ok := true
	var names: Array[String] = []
	for m in meshes:
		var mi := m as MeshInstance3D
		names.append(String(mi.name))
		surfaces_ok = surfaces_ok and mi.mesh.get_surface_count() == 1
		var mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
		opaque_ok = opaque_ok and (mat == null or mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
		var arrays := mi.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		verts += vs.size()
		tris += idx.size() / 3
		var world := mi.global_transform
		for v in vs:
			var p := world * v
			if mi.name == "Tailrace":
				bounds_ok = bounds_ok and _in_box(p, Vector3(0, 28, 217), Vector3(276, 0.4, 28))
			else:
				var inside := false
				for fx in FALL_X:
					inside = inside or _in_box(p, Vector3(fx, 75, 227), Vector3(14, 90, 0.5))
				bounds_ok = bounds_ok and inside
	names.sort()
	_check(names == ["SpillSheets", "Tailrace"], "two batches named SpillSheets and Tailrace: %s" % str(names))
	_check(verts <= CEILING_V, "vertices %d <= %d" % [verts, CEILING_V])
	_check(tris <= CEILING_T and tris > 60, "triangles %d <= %d (and above the 60 T of the boxes)" % [tris, CEILING_T])
	_check(meshes.size() <= CEILING_D and surfaces_ok, "%d draws <= %d, one surface each" % [meshes.size(), CEILING_D])
	_check(opaque_ok, "no alpha surface")
	_check(bounds_ok, "every vertex inside the box it replaces (no silhouette growth)")
	scene.free()
	print("water_edges_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
