extends RefCounted

# A field find's dressing as a model (W1-22): the crew notice board and its brass frame, the radio's
# whip aerial and one seep streak (tools/blender/world_one/find_kit.py). activities.gd places them;
# each part is built about its own origin. With the model missing or malformed every part is null and
# the caller keeps its plain shapes.

const MODEL := "res://assets/models/world_one/find_kit.glb"
const REQUIRED := ["FindBoardFrame", "FindBoard", "FindAerial", "FindSeep"]
const ROUGH := {"device_metal": 0.68, "device_marks": 0.85}

static var _meshes: Dictionary = {}
static var _loaded := false


# A new view of the named part on parent, or null when the model is missing.
static func part(part_name: String, parent: Node3D) -> MeshInstance3D:
	var mesh: Mesh = _parts().get(part_name)
	if mesh == null:
		return null
	var view := MeshInstance3D.new()
	view.name = part_name
	view.mesh = mesh
	parent.add_child(view)
	return view


static func _parts() -> Dictionary:
	if _loaded:
		return _meshes
	_loaded = true
	var packed := load(MODEL) as PackedScene if ResourceLoader.exists(MODEL) else null
	if packed == null:
		push_warning("find_kit: %s missing; finds keep their plain shapes" % MODEL)
		return _meshes
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
		_meshes[String(view.name)] = mesh
	scene.free()
	for required in REQUIRED:
		if not _meshes.has(required):
			push_warning("find_kit: %s lacks %s; finds keep their plain shapes" % [MODEL, required])
			_meshes.clear()
			break
	return _meshes
