extends SceneTree

const DIR := "res://assets/models/dig_mechanical/"
const PROP := [270, 610, 1]
const SCENERY := [120, 110, 2]
const W50_EXTRA := ["timber_rock_strut.glb"]
const REQUIRED := {
	"impeller_rim_sector": ["RimSector", "socket_join_a", "socket_join_b"],
	"impeller_hub": ["Hub", "socket_vane_0", "socket_vane_1", "socket_vane_2", "socket_vane_3", "socket_vane_4"],
	"impeller_vane": ["Vane", "socket_hub"],
	"impeller_vane_chipped": ["VaneChipped", "socket_hub"],
	"intake_petal": ["Petal", "socket_throat"],
	"intake_throat": ["Throat", "socket_spine", "socket_bell"],
	"intake_spine_segment": ["Spine", "socket_next"],
	"strut_tall": ["Strut", "socket_wall", "socket_foot_l", "socket_foot_r"],
	"strut_bent": ["StrutBent", "socket_wall", "socket_foot"],
	"cart_body": ["Hopper", "Chassis", "socket_wheel_fl", "socket_wheel_fr", "socket_wheel_rl", "socket_wheel_rr", "socket_tow"],
	"cart_wheel": ["Tyre"],
	"lamp_straight_module": ["Rail", "Bracket", "Hood", "Lens", "socket_next", "socket_wall"],
	"lamp_curve_module": ["Rail", "Bracket", "Hood", "Lens", "socket_next", "socket_wall"],
	"shell_crescent": ["Crescent", "socket_ground"],
	"shell_saddle": ["Saddle", "socket_ground"],
	"breach_rim_sector": ["RimSector", "socket_join_a", "socket_join_b"],
	"breach_wedge_a": ["WedgeA", "socket_membrane"],
	"breach_wedge_b": ["WedgeB", "socket_membrane"],
	"breach_wedge_c": ["WedgeC", "socket_membrane"],
	"breach_tab": ["StateTab", "socket_mount"],
}
const SIZES := {
	"impeller_hub": Vector3(5, 5, 3),
	"impeller_vane": Vector3(3.6, 8, 1.2),
	"impeller_vane_chipped": Vector3(3.6, 8, 1.2),
	"intake_throat": Vector3(3, 2, 3),
	"intake_spine_segment": Vector3(2.2, 6, 2.2),
	"strut_tall": Vector3(2.4, 3, 0.6),
	"strut_bent": Vector3(2, 2, 0.6),
	"cart_body": Vector3(1.7, 1.4, 3),
	"cart_wheel": Vector3(0.22, 0.6, 0.6),
	"shell_crescent": Vector3(3, 1.3, 1.6),
	"shell_saddle": Vector3(2.2, 0.6, 1.8),
	"breach_tab": Vector3(0.9, 0.12, 0.55),
	"breach_rim_sector": Vector3(3.6, 0.35, 0.6),
}
var failures := 0
var asset_dir := ""
var scratch := false


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("MDM_CHECK %s -> FAIL" % label)


func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _run() -> void:
	asset_dir = OS.get_environment("MDM_ASSET_ROOT")
	scratch = not asset_dir.is_empty()
	if not scratch:
		asset_dir = ProjectSettings.globalize_path(DIR)
	var manifest_path := asset_dir.path_join("manifest.json")
	_check(FileAccess.file_exists(manifest_path), "manifest exists")
	if not FileAccess.file_exists(manifest_path):
		_done()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	_check(parsed is Dictionary, "manifest parses")
	if not parsed is Dictionary:
		_done()
		return
	var manifest: Dictionary = parsed
	var wanted := REQUIRED.duplicate(true)
	for size in ["12x12", "14x10"]:
		for c in ["a", "b", "c"]:
			wanted["breach_wedge_%s_%s" % [c, size]] = ["Wedge" + c.to_upper(), "socket_membrane"]
	var rows: Dictionary = manifest.get("assets", {})
	var expected := wanted.keys()
	var actual := rows.keys()
	expected.sort()
	actual.sort()
	_check(expected == actual, "exactly 26 contracted assets in manifest")
	var on_disk := Array(DirAccess.get_files_at(asset_dir)).filter(func(f: String) -> bool: return f.ends_with(".glb") and not f in W50_EXTRA)
	_check(on_disk.size() == wanted.size(), "all exported GLBs covered by test")
	for name: String in wanted:
		if not rows.has(name):
			_check(false, "missing manifest row " + name)
			continue
		_inspect(name, wanted[name], rows[name])
	_check_materials()
	_check_assemblies(manifest.get("assemblies", {}), rows)
	_done()


func _inspect(name: String, required: Array, row: Dictionary) -> void:
	var path := asset_dir.path_join(name + ".glb")
	_check(FileAccess.file_exists(path), "missing GLB " + name)
	if not FileAccess.file_exists(path):
		return
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	_check(err == OK, name + " parses")
	if err != OK:
		return
	var json := state.json
	var raw_nodes: Array = json.get("nodes", [])
	var names: Array = []
	for node: Dictionary in raw_nodes:
		var node_name: String = node.get("name", "")
		names.append(node_name)
		var loc := Vector3.ZERO
		if node.has("translation"):
			loc = _v(node["translation"])
		var is_reference: bool = node_name.begins_with("socket_") or row.get("merged_parts", {}).has(node_name)
		_check(is_reference or loc.length() < 0.0001, name + " mesh/root translations are identity")
		_check(not node.has("rotation") and not node.has("scale") and not node.has("matrix"), name + " mesh/root transforms applied")
		if row.get("sockets", {}).has(node_name):
			_check(loc.distance_to(_v(row["sockets"][node_name])) < 0.0001, name + " socket " + node_name)
	_check(name in names, name + " basename root")
	for required_name: String in required:
		_check(required_name in names, name + " required node " + required_name)
	_check(json.get("cameras", []).is_empty() and json.get("skins", []).is_empty(), name + " no camera or combat rig")
	_check(json.get("images", []).is_empty(), name + " texture-free baked vertex colour kit")
	for node_name: String in names:
		_check(not node_name.to_lower().contains("collision"), name + " cosmetic only")
	var raw_materials: Array = json.get("materials", [])
	var allowed := ["steel", "glass"] if name.begins_with("lamp_") else ["enamel"] if name.begins_with("impeller_") or name.begins_with("intake_") or name.begins_with("shell_") else ["elastomer"] if name == "cart_wheel" else ["steel"]
	var mat_names: Array = []
	for mat: Dictionary in raw_materials:
		mat_names.append(mat.get("name", ""))
	mat_names.sort()
	allowed.sort()
	_check(mat_names == allowed, name + " exact material slots")
	var limits: Array = SCENERY if name.begins_with("lamp_") else PROP
	var declared: Array = row.get("budget", [])
	_check(declared.size() == 3 and int(declared[0]) == limits[0] and int(declared[1]) == limits[1] and int(declared[2]) == limits[2], name + " spec caps independent of manifest")
	var scene := doc.generate_scene(state) as Node3D
	_check(scene != null, name + " generates scene")
	if scene == null:
		return
	root.add_child(scene)
	var metrics := _metrics(scene)
	_validate_metrics(name, metrics, limits, row)
	scene.free()
	if not scratch:
		var packed := load(DIR + name + ".glb") as PackedScene
		_check(packed != null, name + " Godot imported PackedScene loads")
		if packed != null:
			var imported := packed.instantiate() as Node3D
			root.add_child(imported)
			var imported_metrics := _metrics(imported)
			_validate_metrics(name, imported_metrics, limits, row)
			print("MDM_METRIC %s triangles=%d vertices=%d draws=%d materials=%d" % [name, imported_metrics.triangles, imported_metrics.vertices, imported_metrics.draws, mat_names.size()])
			imported.free()


func _metrics(scene: Node3D) -> Dictionary:
	var triangles := 0
	var vertices := 0
	var draws := 0
	var box := AABB()
	var first := true
	for item in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := item as MeshInstance3D
		for surface in mesh_node.mesh.get_surface_count():
			draws += 1
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			vertices += vs.size()
			triangles += (indices.size() if not indices.is_empty() else vs.size()) / 3
			var count := indices.size() if not indices.is_empty() else vs.size()
			var nondegenerate := true
			for i in range(0, count, 3):
				var a := vs[indices[i] if not indices.is_empty() else i]
				var b := vs[indices[i + 1] if not indices.is_empty() else i + 1]
				var c := vs[indices[i + 2] if not indices.is_empty() else i + 2]
				nondegenerate = nondegenerate and (b - a).cross(c - a).length() > 0.00000001
			_check(nondegenerate, "no zero-area exported triangles")
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			_check(colors.size() == vs.size(), "vertex colours baked")
			for pos in vs:
				var at := mesh_node.global_transform * pos
				box = AABB(at, Vector3.ZERO) if first else box.expand(at)
				first = false
	return {"triangles": triangles, "vertices": vertices, "draws": draws, "box": box}


func _validate_metrics(name: String, metrics: Dictionary, limits: Array, row: Dictionary) -> void:
	_check(metrics.triangles > 0 and metrics.triangles <= limits[0], name + " triangle cap")
	_check(metrics.vertices > 0 and metrics.vertices <= limits[1], name + " imported vertex cap")
	_check(metrics.draws > 0 and metrics.draws <= limits[2], name + " draw/material cap")
	_check(metrics.triangles == int(row.get("triangles", -1)), name + " measured triangles match manifest")
	var box: AABB = metrics.box
	_check(box.position.distance_to(_v(row.bounds.min)) < 0.001 and box.end.distance_to(_v(row.bounds.max)) < 0.001, name + " metre bounds match manifest")
	if SIZES.has(name):
		_check(box.size.distance_to(SIZES[name]) < 0.005, name + " exact specified dimensions " + str(box.size))
	if name == "breach_tab":
		_check(box.position.distance_to(Vector3(0, 0, -0.275)) < 0.001, "rear-edge tab hinge")


func _check_materials() -> void:
	var path := "res://assets/materials/dig_mechanical/"
	var files := Array(DirAccess.get_files_at(path)).filter(func(f: String) -> bool: return f.ends_with(".tres"))
	_check(files.size() == 4, "exactly four shared non-stone material resources")
	for slot in ["steel", "enamel", "elastomer", "glass"]:
		var resource := load(path + slot + ".tres") as Material
		_check(resource != null and resource.resource_name == slot, "shared material " + slot)


func _check_assemblies(assemblies: Dictionary, rows: Dictionary) -> void:
	for key in ["impeller_assembly", "intake_assembly", "cart_assembly", "lamp_straight_assembly", "lamp_curve_assembly", "breach_assembly_12x12", "breach_assembly_14x10"]:
		_check(assemblies.has(key), "required assembly " + key)
	for assembly: Dictionary in assemblies.values():
		for part: Dictionary in assembly.get("instances", []):
			_check(rows.has(str(part.get("file", "")).trim_suffix(".glb")), "assembly references existing component")
	if assemblies.has("impeller_assembly"):
		var a: Dictionary = assemblies.impeller_assembly
		_check(a.instances.size() == 14 and a.sockets.has("socket_wall") and a.sockets.has("socket_scale_ball"), "impeller eight sectors, hub, five vanes and sockets")
	if assemblies.has("intake_assembly"):
		var a: Dictionary = assemblies.intake_assembly
		_check(a.instances.size() == 8, "intake three petals, throat, four spine segments")
		for socket in ["socket_ceiling", "socket_waking_axis", "socket_bell"]:
			_check(a.sockets.has(socket), "intake assembly socket " + socket)
	for dims in [Vector2(12, 12), Vector2(14, 10)]:
		var key := "breach_assembly_%dx%d" % [int(dims.x), int(dims.y)]
		if not assemblies.has(key):
			continue
		var a: Dictionary = assemblies[key]
		_check(a.cover_rectangle == [dims.x, dims.y], "P-R6 current gameplay rectangle")
		_check(a.instances.size() == 15, "breach eight rim halves, three wedges, four tabs")
		var poses: Dictionary = a.get("poses", {})
		_check(poses.has("ready") and poses.has("rupture") and poses.has("spent") and not poses.has("unready"), "P-R6 mint state, rupture, no unready/slate")
		for socket in ["socket_tab_n", "socket_tab_e", "socket_tab_s", "socket_tab_w", "socket_approach", "socket_void"]:
			_check(a.sockets.has(socket), "breach assembly socket " + socket)
	if not scratch:
		for key: String in assemblies:
			_inspect_assembly(key, assemblies[key])


func _inspect_assembly(key: String, assembly: Dictionary) -> void:
	var display := Node3D.new()
	root.add_child(display)
	var cover_points: Array[Vector3] = []
	for part: Dictionary in assembly.instances:
		var packed := load(DIR + str(part.file)) as PackedScene
		if packed == null:
			_check(false, key + " missing component")
			continue
		var instance := packed.instantiate() as Node3D
		var degrees := _v(part.rotation_degrees)
		var rotation := Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))
		var local := Transform3D(Basis.from_euler(rotation, EULER_ORDER_YXZ) * Basis.from_scale(_v(part.scale)), _v(part.position))
		var assembly_scale := Transform3D(Basis.from_scale(_v(part.get("assembly_scale", [1, 1, 1]))), Vector3.ZERO)
		instance.transform = assembly_scale * local
		display.add_child(instance)
		if str(part.name).begins_with("tab_"):
			var front := instance.global_transform * Vector3(0.9, 0, 0)
			_check(absf(front.y - 0.4) < 0.001, "ready tab front rises exactly 0.4 m")
		if str(part.name).begins_with("wedge_"):
			for item in instance.find_children("*", "MeshInstance3D", true, false):
				var mesh_node := item as MeshInstance3D
				for surface in mesh_node.mesh.get_surface_count():
					var arrays := mesh_node.mesh.surface_get_arrays(surface)
					for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
						cover_points.append(mesh_node.global_transform * vertex)
	var metrics := _metrics(display)
	var box: AABB = metrics.box
	if key == "impeller_assembly":
		_check(box.size.distance_to(Vector3(24, 24, 3.0005)) < 0.005, "assembled impeller 24 m diameter, 3 m depth")
		_check(absf(box.position.y) < 0.005, "impeller bottom-centre origin")
	if key == "intake_assembly":
		_check(box.size.distance_to(Vector3(10, 24, 10)) < 0.005, "assembled intake 10 m diameter, 24 m spine")
	if key.begins_with("breach_assembly_"):
		_check(not cover_points.is_empty(), "assembled membrane geometry")
		if not cover_points.is_empty():
			var cover := AABB(cover_points[0], Vector3.ZERO)
			for point in cover_points:
				cover = cover.expand(point)
			var dims: Array = assembly.cover_rectangle
			_check(absf(cover.size.x - float(dims[0])) < 0.001 and absf(cover.size.z - float(dims[1])) < 0.001, "P-R6 actual membrane fits gameplay rectangle")
			_check(absf(cover.end.y) < 0.001 and cover.position.y >= -0.301, "membrane nominal top, 0.18 m dish and 0.12 m thickness")
	display.free()


func _done() -> void:
	print("dress_mdm_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
