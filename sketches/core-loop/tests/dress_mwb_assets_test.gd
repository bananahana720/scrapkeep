extends SceneTree

# "pilot": the glove fingers (2026-10-18 review F4), a matte vertex-colour slot kept off the enamel cap.
const SLOTS := ["ancient_enamel", "rubber", "ancient_light", "bare_metal", "mantle_tool", "pilot"]
const SEATS := [Vector3(1.735, 2.97, 0), Vector3(-0.665, 2.97, 1.385641), Vector3(-0.665, 2.97, -1.385641)]
const SPECS := [
	{"file": "warden_mantle_hand.glb", "root": "MantleHand", "cap": [6000, 11200, 5],
	"paths": ["MountBody", "MountBody/HandWrist", "MountBody/HandThreeFingers"]},
	{"file": "warden_mantle_choir.glb", "root": "MantleChoir", "cap": [1100, 1700, 7],
	"paths": ["MountBody", "MountBody/ChoirRearComb", "MountBody/ChoirFiveHorns", "MountArmL", "MountArmL/ChoirShoeL", "MountArmR", "MountArmR/ChoirShoeR"]}
]
var failures := 0
var failure_reasons: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		failure_reasons.append(label)
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _run() -> void:
	for spec in SPECS:
		_check_asset(spec)
	for reason in failure_reasons:
		print("MWB_FAILURE " + reason)
	print("dress_mwb_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check_asset(spec: Dictionary) -> void:
	# A scratch directory exercises failures without changing delivered assets.
	var directory := OS.get_environment("MWB_ASSET_DIR")
	if directory.is_empty():
		directory = ProjectSettings.globalize_path("res://assets/models")
	var path: String = directory.path_join(spec.file)
	_check(FileAccess.file_exists(path), spec.file + " exists")
	if not FileAccess.file_exists(path):
		return
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var err := document.append_from_file(path, state)
	_check(err == OK, spec.file + " GLTF import")
	if err != OK:
		return
	var imported := document.generate_scene(state) as Node3D
	_check(imported != null, spec.file + " scene generated")
	if imported == null:
		return
	root.add_child(imported)
	var scene := imported if String(imported.name) == spec.root else imported.get_node_or_null(NodePath(spec.root)) as Node3D
	_check(scene != null, spec.file + " authored root exists")
	if scene == null:
		imported.free()
		return
	_check(String(scene.name) == spec.root and scene.transform.is_equal_approx(Transform3D.IDENTITY), spec.file + " identity named root")
	for required: String in spec.paths:
		var node := scene.get_node_or_null(NodePath(required)) as Node3D
		_check(node != null, spec.file + " node/socket " + required)
		if node != null:
			_check(node.transform.is_equal_approx(Transform3D.IDENTITY), required + " identity attachment-local transform")
	var views := scene.find_children("*", "MeshInstance3D", true, false)
	_check(views.size() == (2 if spec.root == "MantleHand" else 4), spec.file + " exact named mesh count")
	_check(scene.find_children("*", "Skeleton3D", true, false).is_empty() and scene.find_children("*", "AnimationPlayer", true, false).is_empty() and scene.find_children("*", "CollisionObject3D", true, false).is_empty(), spec.file + " static scenery only")
	var surfaces := 0
	var triangles := 0
	var vertices := 0
	var materials := {}
	var clearance := INF
	var fingers := [AABB(), AABB(), AABB()]
	var finger_seen := [false, false, false]
	var finger_lanes_ok := true
	var horn_bounds := [AABB(), AABB(), AABB(), AABB(), AABB()]
	var horn_seen := [false, false, false, false, false]
	var horn_lanes_ok := true
	var working_horns := {}
	for view: MeshInstance3D in views:
		_check(not String(view.name).begins_with("Shutter"), "no reserved Shutter prefix")
		var attachment := Transform3D.IDENTITY
		if view.get_parent().name == "MountArmL":
			attachment.origin = Vector3(0, .6075, -.6075)
		elif view.get_parent().name == "MountArmR":
			attachment.origin = Vector3(0, .6075, .6075)
		for surface in view.mesh.get_surface_count():
			surfaces += 1
			var arrays := view.mesh.surface_get_arrays(surface)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			vertices += pos.size()
			triangles += indices.size() / 3 if not indices.is_empty() else pos.size() / 3
			var mat := view.mesh.surface_get_material(surface)
			_check(mat != null and mat.resource_name in SLOTS, "approved material slot")
			if mat != null:
				materials[mat.resource_name] = true
				_check(mat is BaseMaterial3D and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "opaque material")
			var faces: PackedVector3Array = view.mesh.get_faces() if view.mesh.get_surface_count() == 1 else _surface_faces(pos, indices)
			for j in range(0, faces.size(), 3):
				var a: Vector3 = attachment * view.global_transform * faces[j]
				var b: Vector3 = attachment * view.global_transform * faces[j + 1]
				var c: Vector3 = attachment * view.global_transform * faces[j + 2]
				for seat: Vector3 in SEATS:
					clearance = minf(clearance, _triangle_distance(seat, a, b, c) - 1.3)
			if view.name == "HandThreeFingers":
				for p: Vector3 in pos:
					var lane := roundi(p.z) + 1
					finger_lanes_ok = finger_lanes_ok and lane in [0, 1, 2] and absf(p.z - float(lane - 1)) <= .251
					if lane in [0, 1, 2]:
						fingers[lane] = fingers[lane].expand(p) if finger_seen[lane] else AABB(p, Vector3.ZERO)
						finger_seen[lane] = true
			if view.name == "ChoirFiveHorns":
				for p: Vector3 in pos:
					var lane := roundi(p.z / .88) + 2
					horn_lanes_ok = horn_lanes_ok and lane in [0, 1, 2, 3, 4] and absf(p.z - float(lane - 2) * .88) <= .351
					if lane in [0, 1, 2, 3, 4]:
						horn_bounds[lane] = horn_bounds[lane].expand(p) if horn_seen[lane] else AABB(p, Vector3.ZERO)
						horn_seen[lane] = true
						if mat != null and mat.resource_name == "mantle_tool":
							working_horns[lane] = true
	# Count actual exported accessors as well: Godot may weld identical vertices.
	var bytes := FileAccess.get_file_as_bytes(path)
	var gltf: Dictionary = JSON.parse_string(bytes.slice(20, 20 + bytes.decode_u32(12)).get_string_from_utf8())
	var exported := [0, 0, 0]
	for node: Dictionary in gltf.get("nodes", []):
		if not node.has("mesh"):
			continue
		var mesh: Dictionary = gltf.meshes[node.mesh]
		for primitive: Dictionary in mesh.primitives:
			exported[0] += int(gltf.accessors[primitive.indices].count) / 3
			exported[1] += int(gltf.accessors[primitive.attributes.POSITION].count)
			exported[2] += 1
	for i in 3:
		_check(exported[i] > 0 and exported[i] <= spec.cap[i] and exported[i] <= [6000, 11200, 18][i], "%s exported budget %d/%d" % [spec.file, exported[i], spec.cap[i]])
	_check(materials.size() <= 5 and materials.has("mantle_tool") and materials.has("ancient_light"), "five material maximum and separate tool/seam slots")
	_check(triangles == exported[0] and surfaces == exported[2] and vertices <= exported[1], "Godot geometry agrees with export")
	for material: Dictionary in gltf.get("materials", []):
		if material.name == "mantle_tool":
			var factor: Array = material.pbrMetallicRoughness.get("baseColorFactor", [1, 1, 1, 1])
			_check(factor.size() == 4 and is_zero_approx(float(factor[0])) and is_zero_approx(float(factor[1])) and is_zero_approx(float(factor[2])) and is_equal_approx(float(factor[3]), 1.0), "working pads rest dark until charge wiring")
	_check(gltf.get("skins", []).is_empty() and gltf.get("animations", []).is_empty(), "no exported rig or animation")
	_check(clearance >= .15 - .0001, "%s triangle lens-seat clearance %.4fm >= .15m" % [spec.file, clearance])
	if spec.root == "MantleHand":
		_check(finger_lanes_ok, "three separated finger lanes")
		var wrist := scene.get_node_or_null("MountBody/HandWrist") as MeshInstance3D
		if wrist != null:
			var wrist_faces := wrist.mesh.get_faces()
			for z in [-1.0, 0.0, 1.0]:
				var contact := INF
				for j in range(0, wrist_faces.size(), 3):
					contact = minf(contact, _triangle_distance(Vector3(-2.95, 3.7, z), wrist_faces[j], wrist_faces[j + 1], wrist_faces[j + 2]))
				_check(contact < .001, "finger %.0f contacts cast wrist sill" % z)
		for i in 3:
			_check(finger_seen[i] and absf(fingers[i].position.y - 1.6) < .001 and absf(fingers[i].end.y - 3.7) < .001 and fingers[i].size.z >= .45 and fingers[i].size.z <= .55, "finger %d height and cast width" % i)
		_check(fingers[1].position.z - fingers[0].end.z >= .45 and fingers[2].position.z - fingers[1].end.z >= .45, "finger daylight >= .45m")
	else:
		_check(horn_lanes_ok, "five separated horn lanes")
		for i in 5:
			_check(horn_seen[i] and absf(horn_bounds[i].position.y - 3.3) < .001 and absf(horn_bounds[i].end.y - (4.2 + .45 * i)) < .001 and absf(horn_bounds[i].size.z - .7) < .001, "horn %d stepped height and .7m diameter" % i)
		_check(working_horns.size() == 3 and working_horns.has(0) and working_horns.has(2) and working_horns.has(4), "only horns 0,2,4 carry working diaphragms")
	print("MWB_COUNTS %s T=%d V=%d D=%d M=%d" % [spec.file, exported[0], exported[1], exported[2], materials.size()])
	imported.free()


func _surface_faces(pos: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	if indices.is_empty():
		return pos
	for index: int in indices:
		result.append(pos[index])
	return result


func _triangle_distance(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := b - a
	var ac := c - a
	var normal := ab.cross(ac)
	var best := minf(p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b)), minf(p.distance_to(Geometry3D.get_closest_point_to_segment(p, b, c)), p.distance_to(Geometry3D.get_closest_point_to_segment(p, c, a))))
	if normal.length_squared() < .0000000001:
		return best
	normal = normal.normalized()
	var q := p - normal * (p - a).dot(normal)
	var denominator := ab.dot(ab) * ac.dot(ac) - ab.dot(ac) * ab.dot(ac)
	if absf(denominator) < .0000000001:
		return best
	var u := (ac.dot(ac) * (q - a).dot(ab) - ab.dot(ac) * (q - a).dot(ac)) / denominator
	var v := (ab.dot(ab) * (q - a).dot(ac) - ab.dot(ac) * (q - a).dot(ab)) / denominator
	if u >= 0 and v >= 0 and u + v <= 1:
		best = minf(best, p.distance_to(q))
	return best
