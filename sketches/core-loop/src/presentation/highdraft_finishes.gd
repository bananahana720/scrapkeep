extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const DISTANT := ["sky_mesa.glb", "sky_loom.glb", "sky_blades.glb", "sky_cradle.glb"]
const WorldLook := preload("res://src/presentation/world_look.gd")
const LOOK := {
	"key": WorldLook.ROWS[3]["sun_color"],
	"key_rotation": WorldLook.ROWS[3]["sun_rotation"],
	"fill": WorldLook.ROWS[3]["fill_color"],
	"ambient": WorldLook.ROWS[3]["ambient"],
	"haze": WorldLook.ROWS[3]["haze"],
	"cloud": WorldLook.ROWS[3]["cloud"],
	"stone": Color("c8bda5"),
	"fascia": Color("8a8070"),
	"pillar": Color("9f9480"),
	"bone": Color("d2c5a5"),
	"petrol": Color("53686d"),
	"charcoal": Color("242a28"),
	"catch_edge": Color("e5a044"),
}
const PETROL_PROPS := ["prop_crate.glb", "prop_spool.glb", "prop_bench.glb", "prop_pot.glb", "prop_bearing.glb"]
static var _pieces := {}
static var _warned_aerial := false

static func for_piece(file: String, source: Material) -> Material:
	if not file.begins_with("prop_") or file in ["prop_lamp_glass.glb", "prop_sail.glb"] or not source is BaseMaterial3D:
		return source
	var key := "%d:%s" % [source.get_instance_id(), file]
	if not _pieces.has(key):
		var finish := source.duplicate() as BaseMaterial3D
		finish.albedo_color = prop_tint(file)
		finish.roughness = 0.9
		finish.metallic_specular = 0.2
		_pieces[key] = finish
	return _pieces[key]

static func prop_tint(file: String) -> Color:
	if file in PETROL_PROPS:
		return (LOOK["petrol"] as Color).lerp(Color.WHITE, 0.3)
	return (LOOK["bone"] as Color).lerp(Color.WHITE, 0.45)


static func aerial_mesh(source: Mesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var bounds := source.get_aabb()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var original := source.surface_get_material(surface) as BaseMaterial3D
		if arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].size() != arrays[Mesh.ARRAY_VERTEX].size() or original == null:
			if not _warned_aerial:
				_warned_aerial = true
				push_warning("highdraft_finishes: malformed aerial mesh; skipping piece")
			return null
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in colors.size():
			var height := clampf((vertices[i].y - bounds.position.y) / maxf(bounds.size.y, 0.01), 0.0, 1.0)
			var sky := (LOOK["haze"] as Color).lerp(LOOK["fill"], height).srgb_to_linear()
			var value := lerpf(0.5, 1.05, height)
			colors[i] = colors[i].lerp(sky, lerpf(0.55, 0.4, height)) * Color(value, value, value)
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		var material := original.duplicate() as BaseMaterial3D
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.95
		material.metallic_specular = 0.0
		mesh.surface_set_material(surface, material)
	return mesh
