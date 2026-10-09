extends SceneTree
# 2026-10-09 (w12 SWAP-BASE): every row of recipe_props.gd ROWS loads, and shells() puts one fading view per shell under
# a parent with its slot materials. Broken-rule guard: a row whose shell path is missing fails the load check.

const RecipeProps := preload("res://src/presentation/recipe_props.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("recipe_props_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_t.check("table has rows", RecipeProps.ROWS.size() > 0, str(RecipeProps.ROWS.size()))
	for consumer in ["ore_cart", "lantern_beacon"]:
		_t.check("%s is a row" % consumer, RecipeProps.ROWS.has(consumer))
	for key: String in RecipeProps.ROWS:
		var rows := RecipeProps.shell_rows(key)
		_t.check("%s has shells" % key, rows.size() > 0, str(rows.size()))
		for row: Array in rows:
			var path: String = row[0]
			_t.check("%s shell exists and loads: %s" % [key, path.get_file()], ResourceLoader.exists(path) and load(path) is PackedScene)
		var parent := Node3D.new()
		root.add_child(parent)
		var views := RecipeProps.shells(key, parent, Transform3D(Basis.IDENTITY, Vector3(1, 2, 3)))
		_t.eq("%s one view per shell" % key, views.size(), rows.size())
		for i in views.size():
			var view := views[i]
			_t.eq("%s shell %d end" % [key, i], view.visibility_range_end, float(rows[i][1]))
			_t.eq("%s shell %d margin" % [key, i], view.visibility_range_end_margin, float(rows[i][2]))
			_t.eq("%s shell %d fade mode" % [key, i], view.visibility_range_fade_mode, GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF)
			_t.eq("%s shell %d casts no shadow" % [key, i], view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			_t.check("%s shell %d carries the fade meta" % [key, i], view.has_meta(RecipeProps.META_FADE))
			_t.eq("%s shell %d at the transform" % [key, i], view.position, Vector3(1, 2, 3))
			var mesh := (view as MeshInstance3D).mesh
			var slots := 0
			for s in mesh.get_surface_count():
				var material: Material = view.get_active_material(s)
				if material != null and Palette.is_slot_resource(material):
					slots += 1
			_t.eq("%s shell %d every surface a slot resource" % [key, i], slots, mesh.get_surface_count())
		parent.free()
	_t.check("a name that is no slot role fails loud", not RecipeProps.is_slot_role("not_a_slot"))
	_t.check("a real role resolves", RecipeProps.slot_material("steel") != null)
	quit(_t.verdict())
