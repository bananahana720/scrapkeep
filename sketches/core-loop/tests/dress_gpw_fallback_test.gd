extends SceneTree

const StageMap := preload("res://src/world/stage_map.gd")
const Bay := preload("res://src/world/bay.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var original_path: String = StageMap.surface_shader_path
	StageMap.surface_shader_path = "res://assets/materials/gpw_missing_shader.gdshader"
	var scene := Node3D.new()
	root.add_child(scene)
	for k in 2:
		StageMap.pylon_wall(scene, Vector3.ZERO, 12.0, 7.0, 0.0)
		var bay := Bay.new()
		scene.add_child(bay)
		bay.setup(26.0, 14.0)
		var barge := bay.get_node("Barge")
		_check("deck keeps original vertex-colour ground", barge.get_node("BayDeck").get_child(1).material_override == PaletteMaterials.ground_material())
		# W1-23: the cabin and yard wall wear bay_kit.glb, which the surface kit never paints, so a broken shader leaves them as they are.
		_check("cabin wears its model", barge.get_node("MossCabin").get_child(1).name == "BayCabin" and barge.get_node("MossCabin").get_child(1).material_override == null)
		_check("yard wall wears its model", barge.get_node("YardWall").get_child(1).name == "BayYardWall" and barge.get_node("YardWall").get_child(1).material_override == null)
		for entry in [[Vector3(Bay.JUKEBOX.x, 0.05, Bay.JUKEBOX.y), Palette.AMBER],
				[Vector3(Bay.MARBLE_TOY.x, 0.05, Bay.MARBLE_TOY.y), Palette.SAND],
				[Vector3(Bay.PAD.x, 0.06, Bay.PAD.y), Palette.AMBER],
				[Vector3(0.0, 0.02 + Bay.deck_height(0.0, -(Bay.TRACK_R - 1.0)), -(Bay.TRACK_R - 1.0)), Palette.SAND]]:
			var found := false
			for mesh in barge.get_children():
				if mesh is MeshInstance3D and mesh.position.is_equal_approx(entry[0]):
					found = _old_stripes(mesh.material_override, entry[1])
			_check("original striped pad or mat", found)
	_check("stage wall fallback", _old_stripes(scene.get_child(0).get_child(1).material_override, Palette.VERDIGRIS))
	_check("one warning for shared broken path", StageMap._surface_warnings.size() == 1)
	StageMap.surface_shader_path = original_path
	_check("healthy path recovers", StageMap.dressed_surface(Palette.VERDIGRIS, 0, Vector3(12, 7, 1.6)) is ShaderMaterial)
	scene.free()
	print("dress_gpw_fallback_test: " + ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _old_stripes(mat: Material, color: Color) -> bool:
	if not mat is StandardMaterial3D or mat.albedo_texture == null:
		return false
	var image: Image = mat.albedo_texture.get_image()
	return mat.uv1_triplanar and mat.uv1_scale == Vector3(0.25, 0.25, 0.25) and is_equal_approx(mat.roughness, 0.75) and image.get_width() == 64 and image.get_pixel(0, 0).is_equal_approx(color) and image.get_pixel(16, 0).is_equal_approx(Palette.CHARCOAL)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		print(label + " -> FAIL")
