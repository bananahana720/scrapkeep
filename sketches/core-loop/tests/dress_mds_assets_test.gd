extends SceneTree

const BASE := "res://assets/models/dig_stone"
const SPECS := {
	"cut_face_long": ["CutFace", Vector3(8, 4, 2), {"socket_chain_l": Vector3(-4, 0, 0), "socket_chain_r": Vector3(4, 0, 0)}],
	"cut_face_scoop": ["CutScoop", Vector3(6, 4, 2.5), {"socket_chain_l": Vector3(-3, 0, 0), "socket_chain_r": Vector3(3, 0, 0)}],
	"rubble_cluster": ["Rubble", Vector3(3, 1, 2.5), {"socket_ground": Vector3.ZERO}],
	"breach_socket": ["SocketCut", Vector3(8, 1, 8), {"socket_plate": Vector3.ZERO, "socket_landing_preview": Vector3(0, -5, -8)}],
	"bed_floor": ["FloorStudy", Vector3(8, 1, 8), {}],
	"bed_cut": ["CutStudy", Vector3(8, 4, 8), {}],
	"bed_rubble": ["RubbleStudy", Vector3(8, 1.8, 8), {}],
	"bed_recess": ["RecessStudy", Vector3(8, 4, 8), {}],
}
const BEDS := "const float BEDS[8] = float[8](1.7, 0.8, 2.6, 1.1, 0.6, 2.1, 1.4, 0.9);"
const W50_SCENERY := ["basalt_column_rib.glb", "copper_vein_face.glb", "moab_arch.glb"]
var failures := 0
var model_dir := BASE


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mds-model-dir="):
			model_dir = arg.trim_prefix("--mds-model-dir=")
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s -> %s" % [label, "PASS" if ok else "FAIL"])


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _contains_origin(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var p := Vector2(a.x, a.z)
	var u := Vector2(b.x, b.z) - p
	var v := Vector2(c.x, c.z) - p
	var determinant := u.cross(v)
	if absf(determinant) < 0.000001:
		return false
	var s := (-p).cross(v) / determinant
	var t := u.cross(-p) / determinant
	return s >= -0.00001 and t >= -0.00001 and s + t <= 1.00001


func _asset(name: String, manifest: Dictionary) -> void:
	var path := model_dir.path_join(name + ".glb")
	_check(FileAccess.file_exists(path), name + " GLB exists")
	if not FileAccess.file_exists(path):
		return
	var state := GLTFState.new()
	var doc := GLTFDocument.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(path), state)
	_check(err == OK, name + " GLB imports")
	if err != OK:
		return
	var scene := doc.generate_scene(state) as Node3D
	_check(scene != null, name + " scene generates")
	if scene == null:
		return
	root.add_child(scene)
	var nodes := _walk(scene)
	var named := {}
	var mesh_count := 0
	var triangles := 0
	var vertices := 0
	var draws := 0
	var materials := {}
	var bounds := AABB()
	var first := true
	var no_plug := true
	var min_radius := INF
	var floor_low := INF
	var floor_high := -INF
	for node in nodes:
		named[String(node.name)] = node
		_check(not (node is CollisionObject3D or node is CollisionShape3D or node is Light3D or node is Camera3D or node is AnimationPlayer), name + " cosmetic static node " + String(node.name))
		if node is MeshInstance3D:
			mesh_count += 1
			var view := node as MeshInstance3D
			_check(view.transform.is_equal_approx(Transform3D.IDENTITY), name + " applied mesh transform")
			for s in view.mesh.get_surface_count():
				draws += 1
				_check(view.mesh.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES, name + " triangle surface")
				var arrays := view.mesh.surface_get_arrays(s)
				var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var count := indices.size() if indices.size() > 0 else pos.size()
				triangles += count / 3
				vertices += pos.size()
				var mat := view.mesh.surface_get_material(s)
				_check(mat != null and mat.resource_name == "stone", name + " named stone slot")
				if mat != null:
					materials[mat.get_instance_id()] = true
					if mat is BaseMaterial3D:
						_check(absf(mat.roughness - 0.95) < 0.001, name + " roughness 0.95")
				for p in pos:
					var w := view.global_transform * p
					bounds = AABB(w, Vector3.ZERO) if first else bounds.expand(w)
					first = false
					min_radius = minf(min_radius, Vector2(w.x, w.z).length())
					if w.y > 0.85:
						floor_low = minf(floor_low, w.y)
						floor_high = maxf(floor_high, w.y)
				if name == "breach_socket":
					for k in range(0, count, 3):
						var a := indices[k] if indices.size() > 0 else k
						var b := indices[k + 1] if indices.size() > 0 else k + 1
						var c := indices[k + 2] if indices.size() > 0 else k + 2
						no_plug = no_plug and not _contains_origin(pos[a], pos[b], pos[c])
	var spec: Array = SPECS[name]
	_check(mesh_count == 1 and named.has(name) and named.has(spec[0]), name + " exact root/part and one mesh")
	_check(triangles > 0 and triangles <= 8000 and vertices > 0 and vertices <= 24000 and draws == 1 and materials.size() == 1,
		name + " landform budget 8000 triangles / 24000 imported vertices / 1 draw / 1 material")
	_check((bounds.size - spec[1]).length() < 0.005, name + " specified metre bounds")
	var want_min := -1.0 if name == "breach_socket" else 0.0
	_check(absf(bounds.position.y - want_min) < 0.002 and absf(bounds.get_center().x) < 0.002 and absf(bounds.get_center().z) < 0.002, name + " authored origin")
	for socket in spec[2]:
		_check(named.has(socket), name + " required " + socket)
		if named.has(socket):
			var socket_node := named[socket] as Node3D
			_check(socket_node != null and (socket_node.global_position - spec[2][socket]).length() < 0.002,
				name + " " + socket + " metre position")
	if name.begins_with("bed_"):
		_check(nodes.filter(func(n): return String(n.name).begins_with("socket_")).is_empty(), name + " study has no gameplay sockets")
	if name == "rubble_cluster":
		_check(triangles <= 600, "rubble target at most 600 triangles")
	if name == "bed_floor":
		_check(floor_high - floor_low <= 0.0801, "floor broad relief at most 0.08 m")
	if name == "breach_socket":
		_check(min_radius >= 2.999 and no_plug, "socket open 6 m throat, no floor plug")
	if manifest.has(name):
		var row: Dictionary = manifest[name]
		_check(row.get("sha256", "") == FileAccess.get_sha256(path), name + " manifest matches GLB bytes")
		_check(row.get("triangles", -1) == triangles and row.get("surfaces", -1) == draws, name + " manifest geometry counts")
	else:
		_check(false, name + " manifest row exists")
	print("MDS_BUDGET %s: %d triangles, %d imported vertices, %d draws, %d materials" % [name, triangles, vertices, draws, materials.size()])
	scene.free()


func _run() -> void:
	var manifest_path := model_dir.path_join("manifest.json")
	var rows := {}
	_check(FileAccess.file_exists(manifest_path), "manifest exists")
	if FileAccess.file_exists(manifest_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		_check(parsed is Dictionary and parsed.get("assets", []) is Array, "manifest parses")
		if parsed is Dictionary:
			for row in parsed.get("assets", []):
				rows[String(row.get("root", ""))] = row
	_check(rows.size() == 8, "manifest has eight required assets")
	var inventory := DirAccess.get_files_at(model_dir)
	var glbs := Array(inventory).filter(func(p): return p.ends_with(".glb") and not p in W50_SCENERY)
	_check(glbs.size() == 8, "every exported GLB is covered by this test")
	for name in SPECS:
		_asset(name, rows)
	var material := load("res://assets/materials/dig_stone/stone.tres") as ShaderMaterial
	_check(material != null and material.resource_name == "stone", "single shared stone material loads")
	if material != null:
		_check(material.shader != null and material.shader.code.contains(BEDS) and material.shader.code.contains("MODEL_MATRIX"), "shared eight-entry beds evaluate in world position")
		for parameter in ["tex_tone", "tex_grain"]:
			var texture := material.get_shader_parameter(parameter) as Texture2D
			_check(texture != null and texture.get_width() <= 2048 and texture.get_height() <= 2048, parameter + " existing texture at most 2048 px")
	print("dress_mds_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
