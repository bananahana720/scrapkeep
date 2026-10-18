extends SceneTree

const DEFAULT_DIR := "res://assets/models/highdraft"
const LAND_CAP := [8000, 24000, 1]
const PROP_CAP := [400, 450, 1]  # 2026-10-18 polish: was [270, 610, 1]; prop class cap 2000 / 4600
const PIECES := {
	"island_small": ["StoneTop", "OffsetKeel"],
	"island_medium": ["StoneTop", "TwinKeel", "TwinKeel_l", "TwinKeel_r"],
	"island_large": ["StoneTop", "LobeKeel", "LobeKeel_1", "LobeKeel_2", "LobeKeel_3"],
	"island_rim": ["Nosing", "Fascia"],
	"island_rib": ["Beam", "BearingFoot"],
	"bridge_skin": ["TopBay", "EdgeStrip_l", "EdgeStrip_r"],
	"return_ramp_skin": ["RampBay", "EdgeStrip_l", "EdgeStrip_r"],
	"barge_skin": ["Top", "Belt"],
}
const SOCKETS := {
	"island_small": {"rim_n": Vector3(0, 0, -14), "rim_e": Vector3(14, 0, 0), "rim_s": Vector3(0, 0, 14), "rim_w": Vector3(-14, 0, 0), "fan_l": Vector3(-6, -3, 0), "fan_r": Vector3(6, -3, 0), "frame_root": Vector3(0, -1.2, 0)},
	"island_medium": {"rim_n": Vector3(0, 0, -18), "rim_e": Vector3(18, 0, 0), "rim_s": Vector3(0, 0, 18), "rim_w": Vector3(-18, 0, 0), "fan_l": Vector3(-8, -3, 0), "fan_r": Vector3(8, -3, 0), "frame_root": Vector3(0, -1.2, 0)},
	"island_large": {"rim_n": Vector3(0, 0, -22), "rim_e": Vector3(22, 0, 0), "rim_s": Vector3(0, 0, 22), "rim_w": Vector3(-22, 0, 0), "fan_1": Vector3(10, -3, 0), "fan_2": Vector3(-5, -3, 8.660254), "fan_3": Vector3(-5, -3, -8.660254), "frame_root": Vector3(0, -1.2, 0)},
	"island_rim": {"join_l": Vector3(-2, 0, 0), "join_r": Vector3(2, 0, 0), "cable_foot": Vector3(0, -1, 0)},
	"island_rib": {"join_a": Vector3.ZERO, "join_b": Vector3(4, 0, 0)},
	"bridge_skin": {"bay_n": Vector3(0, 0, -2), "bay_s": Vector3(0, 0, 2), "rim_l": Vector3(-4, 0, 0), "rim_r": Vector3(4, 0, 0)},
	"return_ramp_skin": {"bay_n": Vector3(0, 0, -2), "bay_s": Vector3(0, 0, 2), "net_join": Vector3(0, 0, 2)},
	"barge_skin": {"dock_l": Vector3(-7, 1, 0), "dock_r": Vector3(7, 1, 0), "vane": Vector3(0, 1.2, 5), "fan_l": Vector3(-4, -1, 0), "fan_r": Vector3(4, -1, 0)},
}
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s -> %s" % [label, "PASS" if ok else "FAIL"])


func _run() -> void:
	var directory := OS.get_environment("SCRAPKEEP_MHI_DIR")
	if directory.is_empty():
		directory = ProjectSettings.globalize_path(DEFAULT_DIR)
	for asset: String in PIECES:
		_test_asset(directory.path_join(asset + ".glb"), asset)
	print("dress_mhi_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _test_asset(path: String, asset: String) -> void:
	_check(FileAccess.file_exists(path), "%s GLB exists" % asset)
	if not FileAccess.file_exists(path):
		return
	var state := GLTFState.new()
	state.handle_binary_image_mode = GLTFState.HANDLE_BINARY_IMAGE_MODE_EMBED_AS_UNCOMPRESSED
	var document := GLTFDocument.new()
	var error := document.append_from_file(path, state)
	_check(error == OK, "%s GLB parses" % asset)
	if error != OK:
		return
	var land := asset in ["island_small", "island_medium", "island_large"]
	var cap: Array = LAND_CAP if land else PROP_CAP
	var family := "stone" if land else "steel"
	var raw: Dictionary = state.json
	_check(raw.get("meshes", []).size() == 1, "%s one mesh definition, no hidden variants" % asset)
	for mesh: Dictionary in raw.get("meshes", []):
		for primitive: Dictionary in mesh.get("primitives", []):
			_check(primitive.get("attributes", {}).has("COLOR_0"), "%s GLB carries the shared material tint mask" % asset)
	var materials: Array = raw.get("materials", [])
	_check(materials.size() == 1, "%s exactly one material family" % asset)
	if materials.size() == 1:
		_check(materials[0].get("name", "") == family, "%s uses %s only" % [asset, family])
	_check(raw.get("animations", []).is_empty(), "%s static rest, no root motion" % asset)
	_check(raw.get("skins", []).is_empty() and not raw.get("extensions", {}).has("KHR_lights_punctual"), "%s no skin or exported light" % asset)
	var names := {}
	for node: Dictionary in raw.get("nodes", []):
		var name: String = node.get("name", "")
		_check(not names.has(name), "%s unique node %s" % [asset, name])
		names[name] = node
		_check(not node.has("camera"), "%s no exported camera" % asset)
	for required: String in [asset] + PIECES[asset] + SOCKETS[asset].keys():
		_check(names.has(required), "%s named node %s exists" % [asset, required])
		if names.has(required):
			_check(not names[required].has("mesh"), "%s %s preserved as an empty marker" % [asset, required])
	if names.has(asset):
		_check(not names[asset].has("matrix") and not names[asset].has("translation") and not names[asset].has("rotation") and not names[asset].has("scale"), "%s identity root pivot" % asset)
	var scene := document.generate_scene(state)
	_check(scene != null, "%s generates a Godot scene" % asset)
	if scene == null:
		return
	root.add_child(scene)
	for socket: String in SOCKETS[asset]:
		var node := scene.find_child(socket, true, false) as Node3D
		_check(node != null, "%s imported socket %s" % [asset, socket])
		if node != null:
			_check(node.global_position.distance_to(SOCKETS[asset][socket]) < 0.0001, "%s socket %s exact metre position" % [asset, socket])
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var triangles := 0
	var vertices := 0
	var draws := 0
	var bounds := AABB()
	var first := true
	var all_points: Array[Vector3] = []
	var normals_ok := true
	var triangles_ok := true
	for mesh_node: MeshInstance3D in meshes:
		_check(mesh_node.transform.is_equal_approx(Transform3D.IDENTITY), "%s mesh identity transform" % asset)
		for surface in mesh_node.mesh.get_surface_count():
			draws += 1
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			vertices += positions.size()
			var count := indices.size() if not indices.is_empty() else positions.size()
			triangles += count / 3
			_check(colors.size() == positions.size(), "%s exported vertex tint and wear" % asset)
			var mat := mesh_node.get_active_material(surface) as StandardMaterial3D
			_check(mat != null and mat.resource_name == family and not mat.emission_enabled, "%s imported non-emissive %s family" % [asset, family])
			if mat != null:
				if not mat.vertex_color_use_as_albedo:
					print("MHI_INTEGRATION_NOTE %s: shared material must enable vertex_color_use_as_albedo; this Godot import leaves it disabled" % asset)
				var expected_roughness := 0.95 if land else 0.8
				_check(absf(mat.roughness - expected_roughness) < 0.001, "%s shared family roughness" % asset)
				var texture := mat.albedo_texture
				_check(texture != null and texture.get_width() <= 2048 and texture.get_height() <= 2048, "%s reused texture within 2048 px" % asset)
			for v in positions:
				var at := mesh_node.global_transform * v
				all_points.append(at)
				bounds = AABB(at, Vector3.ZERO) if first else bounds.expand(at)
				first = false
			for normal in normals:
				normals_ok = normals_ok and normal.is_finite() and absf(normal.length() - 1) < 0.01
			for i in range(0, count, 3):
				var a: Vector3 = positions[indices[i] if not indices.is_empty() else i]
				var b: Vector3 = positions[indices[i + 1] if not indices.is_empty() else i + 1]
				var c: Vector3 = positions[indices[i + 2] if not indices.is_empty() else i + 2]
				triangles_ok = triangles_ok and (b - a).cross(c - a).length() > 0.000001
	print("MHI_BUDGET %s triangles=%d/%d vertices=%d/%d draws=%d/%d materials=%d/1" % [asset, triangles, cap[0], vertices, cap[1], draws, cap[2], materials.size()])
	_check(triangles > 0 and triangles <= cap[0], "%s triangle budget" % asset)
	_check(vertices > 0 and vertices <= cap[1], "%s vertex budget" % asset)
	_check(draws == 1, "%s single merged surface" % asset)
	_check(normals_ok and triangles_ok, "%s finite unit normals and nondegenerate triangles" % asset)
	_check(scene.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s collision-free cosmetic GLB" % asset)
	_check(scene.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s no collision shapes" % asset)
	_geometry(asset, bounds, all_points)
	scene.free()


func _geometry(asset: String, bounds: AABB, points: Array[Vector3]) -> void:
	print("MHI_BOUNDS %s min=%s max=%s" % [asset, bounds.position, bounds.end])
	if asset in ["island_small", "island_medium", "island_large"]:
		var diameter: float = {"island_small": 28.0, "island_medium": 36.0, "island_large": 44.0}[asset]
		_check(bounds.size.is_equal_approx(Vector3(diameter, 8, diameter)), "%s exact disk diameter and 8 m keel depth" % asset)
		_check(absf(bounds.end.y) < 0.0001 and absf(bounds.position.y + 8) < 0.0001, "%s top at Y0 and keel bottom Y-8" % asset)
		var disk_ok := true
		var slab_ring := 0
		var top_edge := 0
		var max_disk_radius := 0.0
		for point in points:
			if point.y >= -1.2001:
				max_disk_radius = maxf(max_disk_radius, Vector2(point.x, point.z).length())
				# Godot's imported vertex compression moves the rim by less than 1 mm.
				disk_ok = disk_ok and Vector2(point.x, point.z).length() <= diameter / 2 + 0.002 and point.y <= 0.0001
				if absf(point.y + 1.2) < 0.0001:
					slab_ring += 1
				if absf(point.y) < 0.0001 and absf(Vector2(point.x, point.z).length() - diameter / 2) < 0.002:
					top_edge += 1
		_check(disk_ok and top_edge >= 128 and slab_ring >= 128, "%s full circular flat disk with 1.2 m slab, radius=%.6f, top=%d, bottom=%d" % [asset, max_disk_radius, top_edge, slab_ring])
	elif asset in ["bridge_skin", "return_ramp_skin"]:
		_check(bounds.size.is_equal_approx(Vector3(8, 0.15, 4)) and absf(bounds.end.y) < 0.0001, "%s 8 x 0.15 x 4 bay, flush top Y0" % asset)
	elif asset == "barge_skin":
		_check(bounds.size.is_equal_approx(Vector3(14, 1.95, 14)) and absf(bounds.end.y - 1) < 0.0001, "%s 14 m cradle, top Y1, 1.8 m belt beneath" % asset)
	elif asset == "island_rim":
		_check(absf(bounds.size.x - 4) < 0.0001 and absf(bounds.size.z - 0.7) < 0.0001 and absf(bounds.end.y) < 0.0001, "%s 4 m rim with top-inner-edge origin" % asset)
	elif asset == "island_rib":
		_check(absf(bounds.position.x) < 0.0001 and absf(bounds.end.x - 4) < 0.0001, "%s 4 m beam from join_a to join_b" % asset)
