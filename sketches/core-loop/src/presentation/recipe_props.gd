extends RefCounted

const MaterialSlots := preload("res://src/presentation/material_slots.gd")

# One row per picture-driven recipe object; this table is the single source for its GLBs and fade ranges.
# Row shape: key -> {"base": [glb_path, ...], "shells": [[glb_path, visibility_range_end, visibility_range_end_margin], ...]}.
# base: the object's base GLBs, placed by base() with shadows and no fade. shells: its detail shells, placed by shells()
# and faded out by range end and margin, metres, proven on the render rig under the no-pop rule
# (tools/w12_recipe_cart_side.gd LAYER_RANGE). An object authored in two frames (the valve's wheel and foot) is two rows,
# one per frame. The game camera differs from the rig camera, so this is the one place to retune a range.
# Set on every shell; GraphicsPreset leaves a view with this meta at its row's range.
const META_FADE := "recipe_fade"
const ROWS := {
	"ore_cart": {"base": ["res://assets/models/ore_cart_body.glb", "res://assets/models/ore_cart_wheel.glb"], "shells": [["res://assets/models/ore_cart_detail1.glb", 40.0, 4.0], ["res://assets/models/ore_cart_detail2.glb", 15.0, 3.0]]},
	"lantern_beacon": {"base": ["res://assets/models/lantern_beacon_frame.glb", "res://assets/models/lantern_beacon_lens.glb"], "shells": [["res://assets/models/lantern_beacon_detail1.glb", 60.0, 8.0], ["res://assets/models/lantern_beacon_detail2.glb", 35.0, 5.0]]},
	"valve_wheel": {"base": ["res://assets/models/valve_wheel_wheel.glb", "res://assets/models/valve_wheel_band.glb"], "shells": [["res://assets/models/valve_wheel_detail1.glb", 32.0, 4.0], ["res://assets/models/valve_wheel_detail2.glb", 18.0, 3.0]]},
	"valve_wheel_mount": {"base": ["res://assets/models/valve_wheel_mount.glb"], "shells": [["res://assets/models/valve_wheel_detail1m.glb", 32.0, 4.0]]},
	"barge": {"base": ["res://assets/models/barge.glb", "res://assets/models/barge_fenders.glb"], "shells": [["res://assets/models/barge_detail1.glb", 60.0, 8.0], ["res://assets/models/barge_detail2.glb", 35.0, 5.0]]},
	"kicker_wedge": {"base": ["res://assets/models/kicker_wedge.glb", "res://assets/models/kicker_wedge_stripes.glb"], "shells": [["res://assets/models/kicker_wedge_detail1.glb", 45.0, 10.0], ["res://assets/models/kicker_wedge_detail2.glb", 24.0, 6.0]]},
	"moss_jukebox": {"base": ["res://assets/models/moss_jukebox_cabinet.glb", "res://assets/models/moss_jukebox_trim.glb", "res://assets/models/moss_jukebox_feet.glb"], "shells": [["res://assets/models/moss_jukebox_detail1.glb", 30.0, 8.0], ["res://assets/models/moss_jukebox_detail2.glb", 14.0, 3.0]]},
	"moss_hover_barge": {"base": ["res://assets/models/moss_hover_barge.glb", "res://assets/models/moss_hover_barge_thrusters.glb"], "shells": [["res://assets/models/moss_hover_barge_detail1.glb", 130.0, 15.0], ["res://assets/models/moss_hover_barge_detail2.glb", 95.0, 10.0]]},
	"fabricator_hoop": {"base": ["res://assets/models/fabricator_hoop.glb"], "shells": [["res://assets/models/fabricator_hoop_detail1.glb", 45.0, 6.0], ["res://assets/models/fabricator_hoop_detail2.glb", 25.0, 4.0]]},
	"cottonwood": {"base": ["res://assets/models/cottonwood_trunk.glb", "res://assets/models/cottonwood_crown.glb"], "shells": [["res://assets/models/cottonwood_detail1.glb", 50.0, 10.0], ["res://assets/models/cottonwood_detail2.glb", 30.0, 4.0]]},
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


static func base_paths(key: String) -> Array:
	return ROWS.get(key, {}).get("base", [])


# One MeshInstance3D per mesh node of each base GLB under parent at xform, named "<key>_<node>", each surface in the
# slot named by its GLB material. Base views cast the shape's shadow and never fade. Steel views take the state tint
# (steel_views). A base GLB that cannot load is skipped with a warning.
static func base(key: String, parent: Node3D, xform: Transform3D) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for path: String in base_paths(key):
		for view in _place(path, parent, xform, key + "_"):
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			out.append(view)
	return out


# One MeshInstance3D per shell under parent at xform, each surface in the slot named by its GLB material, faded out
# by the row's range end and margin. Shells cast no shadow: the base mesh already casts the shape. A shell that cannot load is skipped with a warning.
static func shells(key: String, parent: Node3D, xform: Transform3D) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for shell: Array in shell_rows(key):
		for view in _place(shell[0], parent, xform, ""):
			view.visibility_range_end = shell[1]
			view.visibility_range_end_margin = shell[2]
			view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			view.set_meta(META_FADE, true)
			out.append(view)
	return out


# The views among these that wear the steel slot on any surface; a caller sets state_tint on them.
static func steel_views(views: Array[GeometryInstance3D]) -> Array[GeometryInstance3D]:
	var steel := slot_material("steel")
	var out: Array[GeometryInstance3D] = []
	for view in views:
		var mesh := (view as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			if (view as MeshInstance3D).get_surface_override_material(i) == steel:
				out.append(view)
				break
	return out


# The per-surface slot loop shared by base() and shells(): one view per mesh node of the GLB at path, every surface
# mapped through slot_material by its GLB material resource_name, placed at xform times the node's transform in the GLB.
static func _place(path: String, parent: Node3D, xform: Transform3D, prefix: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var sources := mesh_sources(path)
	if sources.is_empty():
		return out
	for source: Dictionary in sources:
		var view := MeshInstance3D.new()
		view.name = prefix + source.name
		view.mesh = source.mesh
		var slots: PackedStringArray = source.slots
		for i in slots.size():
			var material := slot_material(slots[i])
			if material != null:
				view.set_surface_override_material(i, material)
		parent.add_child(view)
		view.transform = xform * source.xform
		out.append(view)
	return out


# A GLB's mesh nodes as {name, mesh, slots (each surface's GLB material name), xform (in the GLB)}, read once a path:
# instancing the scene for every placement cost about 0.3 ms a shell, 56 shells on a Spillway stage entry. Main thread
# only, like every caller (contraptions' skins read them too). A GLB that cannot load is warned about once a call and gives [].
static var _source_cache := {}


# Teardown: the cached meshes go with the Game (activities.gd _exit_tree).
static func release_shared() -> void:
	_source_cache.clear()


static func mesh_sources(path: String) -> Array:
	if _source_cache.has(path):
		return _source_cache[path]
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if packed == null:
		push_warning("recipe_props: %s missing, it stays out" % path)
		return []
	var sources := []
	var scene := packed.instantiate()
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh == null:
			continue
		var slots := PackedStringArray()
		for i in source.mesh.get_surface_count():
			var original := source.mesh.surface_get_material(i)
			slots.append(String(original.resource_name) if original != null else "")
		sources.append({"name": String(source.name), "mesh": source.mesh, "slots": slots, "xform": _relative(source, scene)})
	scene.free()
	_source_cache[path] = sources
	return sources


static func _relative(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf
