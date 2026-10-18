extends SceneTree

const DIRECTORY := "res://assets/models/highdraft/"
# Frozen BUILD-SPEC rows: every exported node/primitive contributes to the totals.
# 2026-10-18 polish (tools/blender/POLISH.md): cradle, loom and blades caps were [270, 610, 1].
const SPEC := {
	"sky_cloud": {"cap": [120, 110, 2], "slot": "glass", "size": Vector3(80, 12, 40), "bottom": -6.0,
		"parts": ["CloudHull"], "sockets": {"join_l": Vector3(-40, 0, 0), "join_r": Vector3(40, 0, 0)}},
	"sky_mesa": {"cap": [120, 110, 2], "slot": "M1_stone", "size": Vector3(60, 50, 40), "bottom": 0.0,
		"parts": ["MesaHull"], "sockets": {"crown": Vector3(0, 50, 0)}},
	"sky_cradle": {"cap": [500, 320, 1], "slot": "paint", "size": Vector3(30, 8, 22), "bottom": -8.0,
		"parts": ["CradleHull", "Deck", "Keel", "Rib_l", "Rib_r"],
		"sockets": {"hang_l": Vector3(-10, -2, 0), "hang_r": Vector3(10, -2, 0)}},
	"sky_loom": {"cap": [500, 320, 1], "slot": "paint", "size": Vector3(50, 60, 20), "bottom": 0.0,
		"parts": ["LoomHull", "Beam_l", "Beam_r", "Beam_back", "Weight"],
		"sockets": {"weight_hang": Vector3(0, 45, 0)}},
	"sky_blades": {"cap": [500, 320, 1], "slot": "ancient_enamel", "size": Vector3(24, 80, 3), "bottom": 0.0,
		"parts": ["BladeHull", "Blade_l", "Blade_r"],
		"sockets": {"blade_l": Vector3(-8, 0, 0), "blade_r": Vector3(8, 0, 0)}},
}
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s -> %s" % [label, "PASS" if ok else "FAIL"])


func _run() -> void:
	var override := OS.get_environment("SCRAPKEEP_MHS_ASSET_DIR")
	for name: String in SPEC:
		var path := ProjectSettings.globalize_path(DIRECTORY + name + ".glb") if override.is_empty() else override.path_join(name + ".glb")
		_check(FileAccess.file_exists(path), "%s GLB exists" % name)
		if not FileAccess.file_exists(path):
			continue
		var state := GLTFState.new()
		var document := GLTFDocument.new()
		var err := document.append_from_file(path, state)
		_check(err == OK, "%s GLB parses" % name)
		if err != OK:
			continue
		_raw(name, state.json)
		var scene := document.generate_scene(state) as Node3D
		_check(scene != null, "%s Godot scene generates" % name)
		if scene == null:
			continue
		root.add_child(scene)
		_scene(name, scene)
		scene.free()
		if override.is_empty():
			var packed := load(DIRECTORY + name + ".glb") as PackedScene
			_check(packed != null, "%s imported PackedScene loads" % name)
			if packed != null:
				var imported := packed.instantiate() as Node3D
				root.add_child(imported)
				_scene(name, imported)
				imported.free()
	print("dress_mhs_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _raw(name: String, doc: Dictionary) -> void:
	var spec: Dictionary = SPEC[name]
	var nodes: Array = doc.get("nodes", [])
	var meshes: Array = doc.get("meshes", [])
	var accessors: Array = doc.get("accessors", [])
	var materials: Array = doc.get("materials", [])
	var triangles := 0
	var vertices := 0
	var draws := 0
	var names := {}
	var referenced_meshes := {}
	for node: Dictionary in nodes:
		var label: String = node.get("name", "")
		_check(not names.has(label), "%s unique node %s" % [name, label])
		names[label] = true
		_check(not node.has("skin"), "%s %s is static" % [name, label])
		if not node.has("mesh"):
			continue
		referenced_meshes[int(node.mesh)] = true
		for primitive: Dictionary in meshes[node.mesh].primitives:
			draws += 1
			_check(int(primitive.get("mode", 4)) == 4 and primitive.has("indices"), "%s indexed triangles" % name)
			var position: Dictionary = accessors[primitive.attributes.POSITION]
			vertices += int(position.count)
			if primitive.has("indices"):
				var count := int(accessors[primitive.indices].count)
				_check(count % 3 == 0, "%s complete triangles" % name)
				triangles += count / 3
			_check(primitive.has("material") and int(primitive.get("material", -1)) < materials.size(), "%s assigned material" % name)
	var cap: Array = spec.cap
	_check(triangles > 0 and triangles <= cap[0], "%s triangles %d <= %d" % [name, triangles, cap[0]])
	_check(vertices > 0 and vertices <= cap[1], "%s vertices %d <= %d" % [name, vertices, cap[1]])
	_check(draws > 0 and draws <= cap[2], "%s draws %d <= %d" % [name, draws, cap[2]])
	_check(materials.size() == 1, "%s exactly one material family" % name)
	_check(referenced_meshes.size() == meshes.size(), "%s no uncounted mesh variants" % name)
	for material: Dictionary in materials:
		_check(material.get("name", "") == spec.slot, "%s slot %s" % [name, material.get("name", "")])
		var emission: Array = material.get("emissiveFactor", [0, 0, 0])
		_check(emission == [0, 0, 0] and not material.get("extensions", {}).has("KHR_materials_emissive_strength"), "%s no emitted cue" % name)
		if name == "sky_cloud":
			var factor: Array = material.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])
			_check(material.get("alphaMode", "OPAQUE") == "BLEND" and factor[3] > 0 and factor[3] < 1, "%s translucent M5-derived shell" % name)
	_check(doc.get("textures", []).is_empty() and doc.get("images", []).is_empty(), "%s no new surface atlas" % name)
	_check(doc.get("animations", []).is_empty() and doc.get("skins", []).is_empty(), "%s static rest pose" % name)
	_check(not doc.get("extensions", {}).has("KHR_lights_punctual"), "%s no reward/hazard light" % name)
	for part: String in spec.parts:
		_check(names.has(part), "%s named part %s" % [name, part])
	for label: String in spec.sockets:
		_check(names.has(label), "%s named socket %s" % [name, label])
	_check(names.has(name), "%s named root" % name)
	var expected_names := {name: true}
	for part: String in spec.parts:
		expected_names[part] = true
	for label: String in spec.sockets:
		expected_names[label] = true
	_check(names.size() == expected_names.size(), "%s only contracted nodes; no extra hard points" % name)
	print("MHS_RAW %s triangles=%d vertices=%d materials=%d draws=%d" % [name, triangles, vertices, materials.size(), draws])


func _scene(name: String, scene: Node3D) -> void:
	var spec: Dictionary = SPEC[name]
	var asset_root := scene.find_child(name, true, false) as Node3D
	_check(asset_root != null, "%s root survives import" % name)
	if asset_root != null:
		_check(asset_root.transform.is_equal_approx(Transform3D.IDENTITY), "%s identity origin and pivot" % name)
	var first := true
	var bounds := AABB()
	var triangles := 0
	var vertices := 0
	var draws := 0
	var geometry_normals_ok := true
	for mesh_node: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		_check(mesh_node.mesh != null, "%s %s has a mesh" % [name, mesh_node.name])
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			draws += 1
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			vertices += positions.size()
			triangles += (indices.size() if not indices.is_empty() else positions.size()) / 3
			_check(normals.size() == positions.size(), "%s normals exported" % name)
			for normal in normals:
				geometry_normals_ok = geometry_normals_ok and normal.is_finite() and absf(normal.length() - 1) < .01
			for position in positions:
				var p := mesh_node.global_transform * position
				geometry_normals_ok = geometry_normals_ok and p.is_finite()
				bounds = AABB(p, Vector3.ZERO) if first else bounds.expand(p)
				first = false
			var material := mesh_node.get_active_material(surface) as StandardMaterial3D
			_check(material != null and material.resource_name == spec.slot and not material.emission_enabled, "%s material survives import" % name)
	var cap: Array = spec.cap
	_check(not first and triangles > 0 and triangles <= cap[0] and vertices > 0 and vertices <= cap[1] and draws > 0 and draws <= cap[2], "%s imported geometry fits %s" % [name, cap])
	_check(geometry_normals_ok, "%s finite geometry and unit normals" % name)
	_check(bounds.size.distance_to(spec.size) < .01, "%s bounds %s match %s metres" % [name, bounds.size, spec.size])
	_check(absf(bounds.position.y - spec.bottom) < .01, "%s origin has bottom Y=%.2f" % [name, spec.bottom])
	_check(absf(bounds.get_center().x) < .01 and absf(bounds.get_center().z) < .01, "%s footprint centred" % name)
	for label: String in spec.sockets:
		var node := scene.find_child(label, true, false) as Node3D
		_check(node != null, "%s socket %s imports" % [name, label])
		if node != null:
			_check(node.global_position.distance_to(spec.sockets[label]) < .001 and node.global_basis.is_equal_approx(Basis.IDENTITY), "%s socket %s at %s with identity pivot" % [name, label, spec.sockets[label]])
	_check(scene.find_children("*", "CollisionObject3D", true, false).is_empty() and scene.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s collision-free scenery" % name)
	_check(scene.find_children("*", "Light3D", true, false).is_empty(), "%s no active light" % name)
	print("MHS_ENGINE %s triangles=%d vertices=%d draws=%d bounds=%s" % [name, triangles, vertices, draws, bounds])
