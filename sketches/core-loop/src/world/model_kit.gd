extends RefCounted


const ROUGH := {"device_metal": 0.68, "device_marks": 0.85}

const LOD_M := [60.0, 150.0]

static var _kits: Dictionary = {}
static var _flat: StandardMaterial3D


static func part(path: String, required: Array, part_name: String, parent: Node3D) -> MeshInstance3D:
	var mesh: Mesh = _meshes(path, required).get(part_name)
	if mesh == null:
		return null
	var view := MeshInstance3D.new()
	view.name = part_name
	view.mesh = mesh
	parent.add_child(view)
	return view


static func whole(path: String, parent: Node3D) -> MeshInstance3D:
	var first: MeshInstance3D = null
	var stems := [path, path.replace(".glb", "_lod1.glb"), path.replace(".glb", "_lod2.glb")]
	var have := stems.filter(func(stem: String) -> bool: return (stem == path or ResourceLoader.exists(stem)) and not _meshes(stem, []).is_empty())
	if have.is_empty() or have[0] != path:
		return null
	if _flat == null:
		_flat = StandardMaterial3D.new()
		_flat.vertex_color_use_as_albedo = true
		_flat.vertex_color_is_srgb = false
		_flat.roughness = 0.8
	for i in have.size():
		var view := MeshInstance3D.new()
		view.mesh = _meshes(have[i], []).values()[0]
		view.material_override = _flat
		if i > 0:
			view.visibility_range_begin = LOD_M[i - 1]
		if i < have.size() - 1:
			view.visibility_range_end = LOD_M[i]
		if first == null:
			first = view
			parent.add_child(view)
		else:
			first.add_child(view)
	return first


static func _meshes(path: String, required: Array) -> Dictionary:
	if _kits.has(path):
		return _kits[path]
	var meshes := {}
	_kits[path] = meshes
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed == null:
		push_warning("model_kit: %s missing; its parts stay plain shapes" % path)
		return meshes
	var scene := packed.instantiate()
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null or view.mesh.get_surface_count() == 0:
			continue
		var mesh := view.mesh.duplicate() as Mesh
		for s in mesh.get_surface_count():
			var source := mesh.surface_get_material(s)
			var slot := String(source.resource_name) if source != null else ""
			var mat := StandardMaterial3D.new()
			mat.resource_name = slot
			mat.vertex_color_use_as_albedo = true
			mat.roughness = ROUGH.get(slot, 0.8)
			mat.metallic = 0.28 if slot == "device_metal" else 0.0
			mesh.surface_set_material(s, mat)
		meshes[String(view.name)] = mesh
	scene.free()
	for name in required:
		if not meshes.has(name):
			push_warning("model_kit: %s lacks %s; its parts stay plain shapes" % [path, name])
			meshes.clear()
			break
	return meshes
