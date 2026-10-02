extends SceneTree

# I01 limits (landmark class I: 9,000 V, 3,000 T, 3 D): the dam facade GLB replaces the 252 BlockFaces boxes (3,024 T) at the
# wall's front face plane, Godot z = 236, with no silhouette enlargement.
const PATH := "res://assets/models/world_one/dam.glb"
const FACE_Z := 236.0
const OLD_STAND_OFF := 1.225
const MAX_TRIS := 3000
const MAX_VERTS := 9000
const MAX_SURFACES := 3
const SLOTS := ["paint", "bare_metal", "rubber"]
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _run() -> void:
	var state := GLTFState.new()
	var doc := GLTFDocument.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(PATH), state)
	_check(err == OK, "dam.glb loads")
	var scene := doc.generate_scene(state) as Node3D
	root.add_child(scene)
	var views := scene.find_children("*", "MeshInstance3D", true, false)
	_check(views.size() == 1, "one mesh object")
	var tris := 0
	var verts := 0
	var surfaces := 0
	var box := AABB()
	var first := true
	var slots_ok := true
	var opaque := true
	for view: MeshInstance3D in views:
		surfaces += view.mesh.get_surface_count()
		for s in view.mesh.get_surface_count():
			var arrays := view.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3
			verts += pos.size()
			for v in pos:
				var w := view.global_transform * v
				box = AABB(w, Vector3.ZERO) if first else box.expand(w)
				first = false
			var mat := view.mesh.surface_get_material(s)
			slots_ok = slots_ok and mat != null and mat.resource_name in SLOTS
			if mat is BaseMaterial3D:
				opaque = opaque and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	_check(tris >= 1500 and tris <= MAX_TRIS, "%d triangles within 1500..%d (old blocks 3024)" % [tris, MAX_TRIS])
	_check(verts <= MAX_VERTS, "%d vertices within %d" % [verts, MAX_VERTS])
	_check(surfaces <= MAX_SURFACES, "%d colour-pass surfaces within %d" % [surfaces, MAX_SURFACES])
	_check(slots_ok, "material slots are paint, bare_metal, rubber only")
	_check(opaque, "no alpha surface")
	print("bounds x %.2f..%.2f y %.2f..%.2f z %.3f..%.3f" % [box.position.x, box.end.x, box.position.y, box.end.y, FACE_Z + box.position.z, FACE_Z + box.end.z])
	_check(box.position.z >= -OLD_STAND_OFF - 0.001 and box.end.z <= 0.15,
		"no vertex stands off the face more than the old blocks' %.3f m (plane z %.3f)" % [OLD_STAND_OFF, FACE_Z - OLD_STAND_OFF])
	_check(box.position.x >= -133.0 and box.end.x <= 133.0 and box.position.y >= 26.0 and box.end.y <= 116.0,
		"inside the wall's extent: x within 133 m of centre, height 26..116 m")
	scene.free()
	var source := FileAccess.get_file_as_string("res://src/presentation/spillway_scenery.gd")
	_check(not source.contains("BlockFaces") and source.contains("_dam_detail(scenery)"),
		"the 252 BlockFaces boxes are gone from spillway_scenery.gd and the dam asset is placed")
	var stage := Node3D.new()
	var built = load("res://src/presentation/spillway_scenery.gd").build(stage)
	var dam: MeshInstance3D = built.find_child("DamDetail", true, false)
	var want := {"paint": 0.8, "bare_metal": 0.45, "rubber": 0.95}
	var got := {}
	if dam != null:
		for surface in dam.mesh.get_surface_count():
			var material: StandardMaterial3D = dam.mesh.surface_get_material(surface)
			got[material.resource_name] = material.roughness
	var rough_ok := got.size() == want.size()
	for slot in want:
		rough_ok = rough_ok and got.has(slot) and absf(got[slot] - want[slot]) < 0.005
	print("dam surfaces %s" % got)
	_check(dam != null and dam.material_override == null and dam.mesh.get_surface_count() <= 3 and rough_ok,
		"the dam is its own node of at most 3 draws, roughness per slot as the sheet sets it")
	stage.free()
	print("dam_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
