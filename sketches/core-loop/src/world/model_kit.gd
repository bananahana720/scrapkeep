extends RefCounted

const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")

const ROUGH := {"device_metal": 0.68, "device_marks": 0.85}

const LOD_M := [60.0, 150.0]

static var _kits: Dictionary = {}
static var _flat: StandardMaterial3D
static var _device_kits: Dictionary = {}


static func reset_for_tests() -> void:
	_device_kits.clear()


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


static func _slot_material(slot: String) -> StandardMaterial3D:
	if slot not in ["device_concrete", "device_metal", "device_marks"]:
		return null
	var mat := PaletteMaterials.solid(Color.WHITE)
	mat.resource_name = slot
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95 if slot == "device_concrete" else 0.85
	if slot == "device_metal":
		mat.roughness = 0.68
		mat.metallic = 0.28
	return mat


static func device_parts(path: String, required: Array, owner_tag: String, finish := Callable()) -> Array:
	if _device_kits.has(path):
		return _device_kits[path]
	var parts: Array = []
	_device_kits[path] = parts
	var packed: PackedScene
	if ResourceLoader.exists(path):
		packed = load(path) as PackedScene
	if packed != null:
		var scene := packed.instantiate()
		if scene == null:
			push_warning("%s: %s cannot instantiate; keeping greybox" % [owner_tag, path])
			return parts
		var valid := scene is Node3D
		var found := {}
		for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if view.mesh == null or view.mesh.get_surface_count() == 0:
				valid = false
				break
			var mesh := view.mesh.duplicate() as Mesh
			for s in mesh.get_surface_count():
				var source := mesh.surface_get_material(s)
				var mat := _slot_material(String(source.resource_name)) if source != null else null
				var arrays := mesh.surface_get_arrays(s)
				if (mat == null or arrays.size() != Mesh.ARRAY_MAX
					or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_VERTEX].is_empty()
					or arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].size() != arrays[Mesh.ARRAY_VERTEX].size()):
					valid = false
					break
				var finished: Material = finish.call(mat, arrays[Mesh.ARRAY_VERTEX]) if finish.is_valid() else mat
				mesh.surface_set_material(s, finished)
			var xf := Transform3D.IDENTITY
			var walk: Node = view
			while walk != scene and walk != null:
				if walk is Node3D:
					xf = (walk as Node3D).transform * xf
				walk = walk.get_parent()
			found[String(view.name)] = true
			parts.append({"name": String(view.name), "mesh": mesh, "xform": xf})
		valid = valid and found.size() == required.size()
		for req in required:
			valid = valid and found.has(req)
		scene.free()
		if not valid:
			parts.clear()
	if parts.is_empty():
		push_warning("%s: %s missing or malformed; keeping greybox" % [owner_tag, path])
	return parts


static func attach_part(parts: Array, part_name: String, parent: Node3D) -> MeshInstance3D:
	for part in parts:
		if part.name == part_name:
			var view := MeshInstance3D.new()
			view.name = part.name
			view.mesh = part.mesh
			view.transform = part.xform
			parent.add_child(view)
			return view
	return null
