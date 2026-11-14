extends SceneTree

const StageMap := preload("res://src/world/stage_map.gd")
const Bay := preload("res://src/world/bay.gd")
const Palette := preload("res://src/core/palette.gd")
# 2026-10-09 swap-wave 12-F bay: fixture re-recorded once after both swaps. The jukebox cabinet and grille boxes and the
# barge hull box and four jet cylinders gave way to the RecipeProps views of moss_jukebox and moss_hover_barge
# (bay.gd _build_toys, _build_deck); colliders and every other geometry row are unchanged.
# 2026-10-18 model polish (tools/blender/POLISH.md): re-recorded; only 11 mesh vertex hashes and 3 mesh bounds moved
# (the polished jukebox and hover barge, up to 0.16 m inward); colliders and transforms are unchanged.
const BASELINE := "res://tests/fixtures/dress_gpw_geometry.json"
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	for spec in [[12.0, 7.0, 0.0], [36.0, 15.0, 0.7], [8.0, 5.0, -1.2]]:
		StageMap.pylon_wall(scene, Vector3(3, 4, 5), spec[0], spec[1], spec[2])
	var bay := Bay.new()
	scene.add_child(bay)
	bay.setup(26.0, 14.0)
	var snapshot: Array = []
	_snapshot(scene, "root", snapshot)
	if OS.get_environment("GPW_RECORD_BASELINE") == "1":
		var file := FileAccess.open(BASELINE, FileAccess.WRITE)
		file.store_string(JSON.stringify(snapshot, "\t") + "\n")
		print("gpw baseline: %d geometry nodes" % snapshot.size())
		scene.free()
		quit(0)
		return
	var expected = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	# JSON decodes integers as floats, including layer and surface counts.
	snapshot = JSON.parse_string(JSON.stringify(snapshot))
	var geometry_same: bool = snapshot == expected
	_check("geometry count and transforms", geometry_same)
	if not geometry_same and expected is Array:
		for k in mini(snapshot.size(), expected.size()):
			if snapshot[k] != expected[k]:
				print("geometry expected: " + JSON.stringify(expected[k]))
				print("geometry actual: " + JSON.stringify(snapshot[k]))
				break
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var dressed := 0
	var concrete_faces := 0
	for mesh in meshes:
		var mat: Material = mesh.material_override
		_check("no checker at " + str(mesh.name), not (mat is StandardMaterial3D and mat.uv1_triplanar and mat.albedo_texture != null))
		if mat is ShaderMaterial and mat.resource_name.begins_with("gpw_"):
			dressed += 1
			_check("Godot compiles four surface uniforms", mat.shader.get_shader_uniform_list().size() == 4)
			if int(mat.get_shader_parameter("surface_kind")) == 0:
				concrete_faces += 1
				var color: Color = mat.get_shader_parameter("base_color")
				_check("verdigris hue 165-185 degrees", color.h * 360.0 >= 165.0 and color.h * 360.0 <= 185.0)
				_check("verdigris wash is dominant", color == Palette.VERDIGRIS and float(mat.get_shader_parameter("chip_width")) <= 0.08)
				var bounds: Vector3 = mat.get_shader_parameter("half_extents")
				var chip: float = mat.get_shader_parameter("chip_width")
				var face_area := bounds.x * bounds.y
				var washed_area := maxf(bounds.x - chip, 0.0) * maxf(bounds.y - chip, 0.0)
				_check("over 95 percent of slab face retains hue", washed_area / face_area > 0.95)
				var code: String = mat.shader.code
				_check("concrete shader preserves tint away from chips", code.contains("vec3 paint = base_color.rgb * COLOR.rgb;") and code.contains("finish = paint * (0.86 + wash * 0.19 + aggregate * 0.08 - seams * 0.17 - holes * 0.30);") and code.contains("finish = mix(finish, vec3(0.37, 0.39, 0.35), chips * 0.72);") and code.contains("ALBEDO = finish;"))
	# W1-23: the bay's props wear bay_kit.glb, so only the three pylon walls are concrete faces and the bay's
	# painted marks (mats, pad, chevrons, deck line) are what the surface kit still dresses (was 4 and 30).
	_check("three walls dressed", concrete_faces == 3)
	_check("both families dressed", dressed >= 8)
	var yard_wall := bay.get_node("Barge/YardWall")
	_check("the bay yard wall wears its model", yard_wall.get_child(1) is MeshInstance3D and not yard_wall.get_child(1).mesh is PrimitiveMesh)
	print("gpw geometry: %d nodes %s; %d meshes; %d dressed" % [snapshot.size(), "unchanged" if geometry_same else "DIFFER", meshes.size(), dressed])
	scene.free()
	print("dress_gpw_test: " + ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		print(label + " -> FAIL")


func _snapshot(node: Node, at: String, rows: Array) -> void:
	if node is CollisionObject3D or node is CollisionShape3D or node is MeshInstance3D:
		var row := {"path": at, "type": node.get_class(), "transform": var_to_str(node.transform)}
		if node is CollisionObject3D:
			row["layer"] = node.collision_layer
			row["mask"] = node.collision_mask
		if node is CollisionShape3D:
			row["disabled"] = node.disabled
			row["shape"] = node.shape.get_class()
			if node.shape is BoxShape3D:
				row["size"] = var_to_str(node.shape.size)
			elif node.shape is CylinderShape3D:
				row["size"] = [node.shape.radius, node.shape.height]
			elif node.shape is ConcavePolygonShape3D:
				row["faces"] = str(hash(node.shape.get_faces()))
		if node is MeshInstance3D:
			row["mesh"] = node.mesh.get_class()
			row["bounds"] = var_to_str(node.mesh.get_aabb())
			row["surfaces"] = node.mesh.get_surface_count()
			row["vertices"] = str(hash(node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]))
		rows.append(row)
	for k in node.get_child_count():
		_snapshot(node.get_child(k), at + "/" + str(k), rows)
