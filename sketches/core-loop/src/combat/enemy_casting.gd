class_name EnemyCasting
extends RefCounted

const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")

static var _warned: Dictionary = {}


static func parts(authored: String, tag: String, bake_parents := false) -> Array:
	var path := ModelVariants.path(authored)
	if not ResourceLoader.exists(path):
		return []
	var packed := load(path) as PackedScene
	if packed == null:
		return []
	var out: Array = []
	var scene := packed.instantiate()
	var painted := PaletteMaterials.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var flash := -1
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned.has(tag):
				_warned[tag] = true
				push_warning("%s: surface has no material; using default finish" % tag)
			if surface_material != null and surface_material.resource_name == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, painted)
		var xform := mi.transform
		if bake_parents:
			var parent := mi.get_parent() as Node3D
			while parent != null and parent != scene:
				xform = parent.transform * xform
				parent = parent.get_parent() as Node3D
		out.append({"name": mi.name, "mesh": mesh, "xform": xform, "flash": flash})
	scene.free()
	return out
