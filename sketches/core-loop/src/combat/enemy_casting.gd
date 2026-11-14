class_name EnemyCasting
extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# Reads an enemy's authored GLB (or its Tripo sibling under --models=tripo, model_variants.gd) into the parts its script casts into meshes: one
# {name, mesh, xform, flash} per MeshInstance3D, every surface set to one white
# vertex-coloured finish, flash = the surface whose source material is "fleet_paint"
# (-1 when none). Returns [] when the file is missing or is not a scene. The caller
# keeps the result in its own static cache. A surface with no material pushes
# "<tag>: surface has no material; using default finish" once per tag.
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
	var painted := Palette.solid(Color.WHITE)
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
