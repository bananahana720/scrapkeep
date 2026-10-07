extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const DISTANT := ["sky_mesa.glb", "sky_loom.glb", "sky_blades.glb", "sky_cradle.glb"]
static var _pieces := {}

static func for_piece(file: String, source: Material) -> Material:
	if not file.begins_with("prop_") or file in ["prop_lamp_glass.glb", "prop_sail.glb"] or not source is BaseMaterial3D:
		return source
	var key := source.get_instance_id()
	if not _pieces.has(key):
		var finish := source.duplicate() as BaseMaterial3D
		finish.albedo_color = Palette.SAND.lerp(Color.WHITE, 0.45)
		finish.roughness = 0.9
		finish.metallic_specular = 0.2
		_pieces[key] = finish
	return _pieces[key]

static func aerial_mesh(source: Mesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var bounds := source.get_aabb()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in colors.size():
			var height := clampf((vertices[i].y - bounds.position.y) / maxf(bounds.size.y, 0.01), 0.0, 1.0)
			var sky := Color("798c9e").lerp(Color("a9b6c0"), height).srgb_to_linear()
			colors[i] = colors[i].lerp(sky, lerpf(0.75, 0.55, height))
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		var material := source.surface_get_material(surface).duplicate() as BaseMaterial3D
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.95
		material.metallic_specular = 0.0
		mesh.surface_set_material(surface, material)
	return mesh
