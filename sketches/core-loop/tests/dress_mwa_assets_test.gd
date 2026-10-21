extends SceneTree

# Raw export counts guard the direction-sheet ceilings; Godot imports every GLB.
# MWA_ASSET_DIR permits a scratch-copy mutation without changing delivered assets.
const ASSETS := [
	{"file": "warden_mantle_meltdown.glb", "root": "MantleMeltdown", "cap": [1000, 1600, 12],
		"parts": {"MountBody/MeltRearShell": ["ancient_enamel", "rubber", "ancient_light"],
			"MountVent0/MeltVentBell0": ["ancient_enamel", "rubber", "mantle_tool"],
			"MountVent1/MeltVentBell1": ["ancient_enamel", "rubber", "mantle_tool"],
			"MountVent2/MeltVentBell2": ["ancient_enamel", "rubber", "mantle_tool"]}},
	{"file": "warden_mantle_brood.glb", "root": "MantleBrood", "cap": [1300, 1400, 5],
		"parts": {"MountBody/BroodRibs": ["ancient_enamel", "rubber", "ancient_light"],
			"MountBody/BroodLaunchRail": ["ancient_enamel", "mantle_tool"]}},
]
var failures := 0


func check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
		print("MWA rejected: " + label)


func _initialize() -> void:
	var budget = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_budgets.json"))
	check("warden_kit budget row exists", budget is Dictionary and budget.get("classes", {}).has("warden_kit"))
	if not budget is Dictionary or not budget.get("classes", {}).has("warden_kit"):
		print("dress_mwa_assets_test: FAIL")
		quit(1)
		return
	for spec in ASSETS:
		inspect(spec, budget.classes.warden_kit)
	print("dress_mwa_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func inspect(spec: Dictionary, kit_budget: Dictionary) -> void:
	var folder := OS.get_environment("MWA_ASSET_DIR")
	if folder.is_empty():
		folder = "res://assets/models"
	var path := folder.path_join(spec.file)
	check("missing GLB " + path, FileAccess.file_exists(path))
	if not FileAccess.file_exists(path):
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	check("GLB header " + spec.file, bytes.size() >= 28 and bytes.decode_u32(0) == 0x46546c67)
	if bytes.size() < 28 or bytes.decode_u32(0) != 0x46546c67:
		return
	var json_size := bytes.decode_u32(12)
	check("GLB chunks " + spec.file, bytes.decode_u32(4) == 2 and bytes.decode_u32(8) == bytes.size()
		and bytes.decode_u32(16) == 0x4e4f534a and 20 + json_size + 8 <= bytes.size())
	if 20 + json_size + 8 > bytes.size():
		return
	var parsed = JSON.parse_string(bytes.slice(20, 20 + json_size).get_string_from_utf8())
	check("valid JSON " + spec.file, parsed is Dictionary)
	if not parsed is Dictionary:
		return
	var g: Dictionary = parsed
	check("no animation, skin or cameras " + spec.file, g.get("animations", []).is_empty()
		and g.get("skins", []).is_empty() and g.get("cameras", []).is_empty())
	var t := 0
	var v := 0
	var d := 0
	for mesh in g.get("meshes", []):
		for primitive in mesh.primitives:
			check("triangles only " + spec.file, int(primitive.get("mode", 4)) == 4)
			var count := int(g.accessors[int(primitive.indices)].count)
			check("triangle indices divisible by three", count % 3 == 0)
			t += count / 3
			v += int(g.accessors[int(primitive.attributes.POSITION)].count)
			d += 1
	check("unit budget " + spec.file, t > 0 and t <= int(spec.cap[0]) and v <= int(spec.cap[1]) and d <= int(spec.cap[2]))
	check("warden_kit budget " + spec.file, t <= int(kit_budget.tris) and v <= int(kit_budget.verts) and d <= int(kit_budget.draws))
	check("five materials maximum " + spec.file, g.get("materials", []).size() <= 5)
	var allowed := ["ancient_enamel", "rubber", "ancient_light", "bare_metal", "mantle_tool"]
	for material in g.get("materials", []):
		check("material name " + str(material.get("name", "")), material.get("name", "") in allowed)
		if material.get("name", "") == "mantle_tool":
			check("striped working texture", material.get("pbrMetallicRoughness", {}).has("baseColorTexture"))
			var factor: Array = material.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])
			check("working throats dark at rest", maxf(float(factor[0]), maxf(float(factor[1]), float(factor[2]))) <= .005
				and material.get("emissiveFactor", [0, 0, 0]) == [0, 0, 0])
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
	var imported := document.append_from_file(ProjectSettings.globalize_path(path), state)
	check("Godot imports " + spec.file, imported == OK)
	if imported != OK:
		return
	var scene := document.generate_scene(state)
	check("Godot generated scene " + spec.file, scene != null)
	if scene == null:
		return
	var mantle := scene if str(scene.name) == spec.root else scene.find_child(spec.root, true, false)
	check("root " + spec.root, mantle is Node3D)
	if not mantle is Node3D:
		scene.free()
		return
	check("root identity " + spec.root, mantle.transform.is_equal_approx(Transform3D.IDENTITY))
	var mounts := {}
	var imported_t := 0
	var imported_v := 0
	var imported_d := 0
	for part_path in spec.parts:
		var mount_name: String = part_path.get_slice("/", 0)
		mounts[mount_name] = true
		var mount := mantle.get_node_or_null(mount_name) as Node3D
		check("socket " + mount_name, mount != null)
		if mount != null:
			check("socket identity " + mount_name, mount.transform.is_equal_approx(Transform3D.IDENTITY))
		var part := mantle.get_node_or_null(part_path) as MeshInstance3D
		check("part " + part_path, part != null and part.mesh != null)
		if part == null or part.mesh == null:
			continue
		check("part identity " + part_path, part.transform.is_equal_approx(Transform3D.IDENTITY))
		var actual_slots := []
		for s in part.mesh.get_surface_count():
			var material := part.mesh.surface_get_material(s)
			actual_slots.append(str(material.resource_name) if material != null else "")
			var arrays := part.mesh.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			imported_t += (indices.size() if not indices.is_empty() else points.size()) / 3
			imported_v += points.size()
			imported_d += 1
		actual_slots.sort()
		var expected: Array = spec.parts[part_path].duplicate()
		expected.sort()
		check("exact material slots " + part_path, actual_slots == expected)
		if part_path.contains("MeltVentBell"):
			check_bore(part)
		if part_path.ends_with("BroodLaunchRail"):
			check_queen_aperture(part)
	check("only specified mounts", mantle.get_child_count() == mounts.size())
	check("only specified meshes", mantle.find_children("*", "MeshInstance3D", true, false).size() == spec.parts.size())
	check("no collider or animation", mantle.find_children("*", "CollisionObject3D", true, false).is_empty()
		and mantle.find_children("*", "CollisionShape3D", true, false).is_empty()
		and mantle.find_children("*", "AnimationPlayer", true, false).is_empty())
	check("import preserves geometry counts", imported_t == t and imported_d == d)
	check("Godot vertex budget", imported_v <= int(spec.cap[1]))
	print("MWA measured %s T=%d V=%d primitives=%d materials=%d importedV=%d" % [spec.file, t, v, d, g.materials.size(), imported_v])
	scene.free()


func triangles(part: MeshInstance3D) -> Array:
	var out := []
	for s in part.mesh.get_surface_count():
		var arrays := part.mesh.surface_get_arrays(s)
		var p: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, idx.size(), 3):
			out.append([p[idx[i]], p[idx[i+1]], p[idx[i+2]]])
	return out


func check_bore(part: MeshInstance3D) -> void:
	# Actual triangle interiors must not occlude any sampled line in the .60 m bore.
	var clear := true
	var tri := triangles(part)
	for ring in [0.0, .15, .299]:
		for k in 24:
			var angle := TAU * k / 24.0
			var a := Vector3(ring*cos(angle), -.1, ring*sin(angle))
			var b := a + Vector3.UP*1.8
			for f in tri:
				if Geometry3D.segment_intersects_triangle(a, b, f[0], f[1], f[2]) != null:
					clear = false
	check(".60m clear vent bore " + str(part.name), clear)


func check_queen_aperture(part: MeshInstance3D) -> void:
	# Queen's 1.30m frontal aperture stays clear through triangle interiors.
	var clear := true
	var tri := triangles(part)
	for ring in [0.0, .325, .649]:
		for k in 32:
			var angle := TAU * k / 32.0
			var a := Vector3(-.1, 1.215 + ring*cos(angle), ring*sin(angle))
			var b := a + Vector3.RIGHT*2
			for f in tri:
				if Geometry3D.segment_intersects_triangle(a, b, f[0], f[1], f[2]) != null:
					clear = false
	check("1.30m queen aperture", clear)
