extends RefCounted

const MaterialSlots := preload("res://src/presentation/material_slots.gd")

# One row per picture-driven recipe object. shells: [[glb_path, visibility_range_end, visibility_range_end_margin], ...],
# metres, proven on the render rig under the no-pop rule (tools/w12_recipe_cart_side.gd LAYER_RANGE). The game camera
# differs from the rig camera, so this is the one place to retune a range. A swap unit adds a row and one call.
const ROWS := {
	"ore_cart": {"shells": [["res://assets/models/ore_cart_detail1.glb", 40.0, 4.0], ["res://assets/models/ore_cart_detail2.glb", 15.0, 3.0]]},
	"lantern_beacon": {"shells": [["res://assets/models/lantern_beacon_detail1.glb", 60.0, 8.0], ["res://assets/models/lantern_beacon_detail2.glb", 35.0, 5.0]]},
}


# The one slot lookup: a shared slot resource by role name, null and an error for a name that is no resource slot.
static func slot_material(slot_name: String) -> Material:
	if not is_slot_role(slot_name):
		push_error("recipe_props: '%s' is not a material slot role" % slot_name)
		return null
	return load(String(MaterialSlots.row(slot_name)["path"])) as Material


static func is_slot_role(slot_name: String) -> bool:
	return MaterialSlots.row(slot_name).get("kind", "") == "resource"


static func shell_rows(key: String) -> Array:
	return ROWS.get(key, {}).get("shells", [])


# One MeshInstance3D per shell under parent at xform, each surface in the slot named by its GLB material, faded out
# by the row's range end and margin. A shell that cannot load is skipped with a warning.
static func shells(key: String, parent: Node3D, xform: Transform3D) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for shell: Array in shell_rows(key):
		var path: String = shell[0]
		var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
		if packed == null:
			push_warning("recipe_props: %s missing, that shell stays out" % path)
			continue
		var scene := packed.instantiate()
		for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if source.mesh == null:
				continue
			var view := MeshInstance3D.new()
			view.name = source.name
			view.mesh = source.mesh
			for i in source.mesh.get_surface_count():
				var original := source.mesh.surface_get_material(i)
				var material := slot_material(String(original.resource_name) if original != null else "")
				if material != null:
					view.set_surface_override_material(i, material)
			view.visibility_range_end = shell[1]
			view.visibility_range_end_margin = shell[2]
			view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			parent.add_child(view)
			view.transform = xform * _relative(source, scene)
			out.append(view)
		scene.free()
	return out


static func _relative(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf
