extends SceneTree
## Headless load check for the image-to-3D trial GLBs.
## godot --headless --path sketches/core-loop --import
## godot --headless --path sketches/core-loop --script res://tools/img3d/godot_check.gd

const MODELS := [
	"res://assets/models/trial_img3d_warden.glb",
	"res://assets/models/trial_img3d_cliff.glb",
	"res://assets/models/trial_img3d_prop.glb",
]


func _init() -> void:
	var failures := 0
	for path in MODELS:
		var packed := load(path) as PackedScene
		if packed == null:
			print("IMG3D_CHECK FAIL %s did not load as PackedScene" % path)
			failures += 1
			continue
		var root := packed.instantiate()
		var counts := {"meshes": 0, "surfaces": 0, "triangles": 0, "cull": []}
		_count(root, counts)
		var aabb := _aabb(root, Transform3D.IDENTITY)
		print("IMG3D_CHECK OK %s meshes=%d surfaces=%d triangles=%d size=%s base_y=%.3f cull=%s" % [
			path, counts.meshes, counts.surfaces, counts.triangles, aabb.size, aabb.position.y, counts.cull])
		root.free()
	quit(1 if failures > 0 else 0)


func _count(node: Node, counts: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		counts.meshes += 1
		var mesh: Mesh = node.mesh
		counts.surfaces += mesh.get_surface_count()
		for s in mesh.get_surface_count():
			var material := mesh.surface_get_material(s) as BaseMaterial3D
			counts.cull.append("none" if material == null else ["back", "front", "disabled"][material.cull_mode])
			var arrays := mesh.surface_get_arrays(s)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				counts.triangles += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			else:
				counts.triangles += indices.size() / 3
	for child in node.get_children():
		_count(child, counts)


func _aabb(node: Node, parent: Transform3D) -> AABB:
	var xform := parent
	if node is Node3D:
		xform = parent * (node as Node3D).transform
	var box := AABB()
	var has_box := false
	if node is MeshInstance3D and node.mesh != null:
		box = xform * node.mesh.get_aabb()
		has_box = true
	for child in node.get_children():
		var child_box := _aabb(child, xform)
		if child_box.size != Vector3.ZERO:
			box = child_box if not has_box else box.merge(child_box)
			has_box = true
	return box
