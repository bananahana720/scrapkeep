extends SceneTree
# 2026-10-09 (w12 SWAP-BASE): every row of recipe_props.gd ROWS loads, and shells() puts one fading view per shell under
# a parent with its slot materials. Broken-rule guard: a row whose shell path is missing fails the load check.
# 2026-10-09 (w12 SWAP-LOADER): rows name their base GLBs and shell list; base() puts one shadowed, unfaded view per base
# mesh node with every surface in its slot. The seven live alpha objects are rows, the valve as two frames.

const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Beacon := preload("res://src/core/beacon.gd")
const T := preload("res://tests/support/t.gd")
const LIVE := ["ore_cart", "lantern_beacon", "valve_wheel", "valve_wheel_mount", "barge", "kicker_wedge", "moss_jukebox",
		"moss_hover_barge", "fabricator_hoop", "cottonwood"]
const AT := Vector3(1, 2, 3)

var _t := T.new("recipe_props_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_t.check("table has rows", RecipeProps.ROWS.size() > 0, str(RecipeProps.ROWS.size()))
	for consumer in LIVE:
		_t.check("%s is a row" % consumer, RecipeProps.ROWS.has(consumer))
	var wheel_shells := RecipeProps.shell_rows("valve_wheel").map(func(r): return String(r[0]).get_file())
	var foot_shells := RecipeProps.shell_rows("valve_wheel_mount").map(func(r): return String(r[0]).get_file())
	_t.check("valve wheel frame names its own shells", wheel_shells == ["valve_wheel_detail1.glb", "valve_wheel_detail2.glb"], str(wheel_shells))
	_t.check("valve foot frame names its own shell", foot_shells == ["valve_wheel_detail1m.glb"], str(foot_shells))
	var xform := Transform3D(Basis.IDENTITY, AT)
	for key: String in RecipeProps.ROWS:
		_check_shells(key, xform)
		_check_base(key, xform)
	_check_beacon()
	_t.check("a name that is no slot role fails loud", not RecipeProps.is_slot_role("not_a_slot"))
	_t.check("a real role resolves", RecipeProps.slot_material("steel") != null)
	quit(_t.verdict())


func _check_shells(key: String, xform: Transform3D) -> void:
	var rows := RecipeProps.shell_rows(key)
	_t.check("%s has shells" % key, rows.size() > 0, str(rows.size()))
	for row: Array in rows:
		var path: String = row[0]
		_t.check("%s shell exists and loads: %s" % [key, path.get_file()], ResourceLoader.exists(path) and load(path) is PackedScene)
	var parent := Node3D.new()
	root.add_child(parent)
	var views := RecipeProps.shells(key, parent, xform)
	_t.eq("%s one view per shell" % key, views.size(), rows.size())
	for i in views.size():
		var view := views[i]
		_t.eq("%s shell %d end" % [key, i], view.visibility_range_end, float(rows[i][1]))
		_t.eq("%s shell %d margin" % [key, i], view.visibility_range_end_margin, float(rows[i][2]))
		_t.eq("%s shell %d fade mode" % [key, i], view.visibility_range_fade_mode, GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
		_t.eq("%s shell %d casts no shadow" % [key, i], view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_t.check("%s shell %d carries the fade meta" % [key, i], view.has_meta(RecipeProps.META_FADE))
		_t.eq("%s shell %d at the transform" % [key, i], view.position, AT)
		_t.eq("%s shell %d every surface a slot resource" % [key, i], _slots(view), (view as MeshInstance3D).mesh.get_surface_count())
	parent.free()


func _check_base(key: String, xform: Transform3D) -> void:
	var paths := RecipeProps.base_paths(key)
	_t.check("%s has base GLBs" % key, paths.size() > 0, str(paths.size()))
	var expected: Array[Transform3D] = []
	var names: Array[String] = []
	for path: String in paths:
		var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
		_t.check("%s base exists and loads: %s" % [key, path.get_file()], packed != null)
		if packed == null:
			continue
		var scene := packed.instantiate()
		for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if source.mesh != null:
				expected.append(xform * _relative(source, scene))
				names.append("%s_%s" % [key, source.name])
		scene.free()
	var parent := Node3D.new()
	root.add_child(parent)
	var views := RecipeProps.base(key, parent, xform)
	_t.eq("%s one base view per base mesh node" % key, views.size(), expected.size())
	for i in mini(views.size(), expected.size()):
		var view := views[i]
		_t.eq("%s base %d named key_node" % [key, i], String(view.name), names[i])
		_t.eq("%s base %d casts shadow" % [key, i], view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		_t.check("%s base %d carries no fade meta" % [key, i], not view.has_meta(RecipeProps.META_FADE))
		_t.eq("%s base %d never fades" % [key, i], view.visibility_range_end, 0.0)
		_t.check("%s base %d placed like the GLB node" % [key, i], view.transform.is_equal_approx(expected[i]), str(view.transform))
		_t.eq("%s base %d every surface a slot resource" % [key, i], _slots(view), (view as MeshInstance3D).mesh.get_surface_count())
	if key in ["lantern_beacon", "fabricator_hoop"]:
		_t.check("%s has steel base views for the state tint" % key, RecipeProps.steel_views(views).size() > 0)
	parent.free()


# 2026-10-10 (w13 LANTERN-SHELLS): the game's beacon carries the base GLB (frame and lens) and both lantern detail shells
# in the scene tree, each shell with the visibility range of its ROWS row.
func _check_beacon() -> void:
	var beacon := Beacon.new()
	root.add_child(beacon)
	beacon.setup(PaletteMaterials)
	_t.check("beacon carries the frame GLB", beacon.get_node_or_null("LanternFrame") != null)
	_t.check("beacon carries the lens GLB", beacon.get_node_or_null("LanternLens") != null)
	var wanted: Dictionary = {}
	for row: Array in RecipeProps.shell_rows("lantern_beacon"):
		wanted[String(row[0]).get_file()] = row
	_t.eq("lantern has two detail shells in its row", wanted.size(), 2)
	var found := {}
	for shell: Array in RecipeProps.shell_rows("lantern_beacon"):
		var scene := (load(shell[0]) as PackedScene).instantiate()
		var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
		for view in beacon.get_children():
			if not view is MeshInstance3D or not view.has_meta(RecipeProps.META_FADE):
				continue
			for source: MeshInstance3D in meshes:
				if view.mesh == source.mesh:
					found[String(shell[0]).get_file()] = found.get(String(shell[0]).get_file(), 0) + 1
					_t.eq("%s view range end from the table" % String(shell[0]).get_file(), view.visibility_range_end, float(shell[1]))
					_t.eq("%s view range margin from the table" % String(shell[0]).get_file(), view.visibility_range_end_margin, float(shell[2]))
					_t.eq("%s view fades itself" % String(shell[0]).get_file(), view.visibility_range_fade_mode, GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
		scene.free()
	for key: String in wanted:
		_t.check("beacon carries %s in the tree" % key, found.get(key, 0) > 0)
	_t.check("beacon base views never fade", beacon.get_node("LanternFrame").find_children("*", "MeshInstance3D", true, false).all(func(v): return v.visibility_range_end == 0.0))
	beacon.free()


func _slots(view: GeometryInstance3D) -> int:
	var slots := 0
	for s in (view as MeshInstance3D).mesh.get_surface_count():
		var material: Material = view.get_active_material(s)
		if material != null and PaletteMaterials.is_slot_resource(material):
			slots += 1
	return slots


static func _relative(node: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf
