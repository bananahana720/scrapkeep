extends RefCounted

# A kit of separately placed model parts in one GLB (field finds, the radio cache): each named mesh
# loads once, wears a vertex-coloured material for its slot, and is handed out as a new view. A kit
# missing its file or any required part hands out nothing, so its caller keeps its plain shapes.

const ROUGH := {"device_metal": 0.68, "device_marks": 0.85}

static var _kits: Dictionary = {}


# A new view of the named part on parent, or null when the kit is missing or malformed.
static func part(path: String, required: Array, part_name: String, parent: Node3D) -> MeshInstance3D:
	var mesh: Mesh = _meshes(path, required).get(part_name)
	if mesh == null:
		return null
	var view := MeshInstance3D.new()
	view.name = part_name
	view.mesh = mesh
	parent.add_child(view)
	return view


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
