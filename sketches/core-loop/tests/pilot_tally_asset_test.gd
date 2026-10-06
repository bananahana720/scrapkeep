extends SceneTree

const PILOT := "res://assets/models/pilot_tally_anim.glb"
const SHELL := "res://assets/models/world_one/shell_tally.glb"
const BONES := [
	"root", "pelvis", "spine_01", "spine_02", "neck", "head", "snout", "goggles",
	"ear.R", "ear.L", "crest", "jaw", "shoulder.R", "shoulder.L",
	"upper_arm.R", "upper_arm.L", "lower_arm.R", "lower_arm.L", "hand.R", "hand.L",
	"curl.R", "curl.L", "tail.01", "tail.02", "tool.R",
]
const PARENTS := {
	"root": "", "pelvis": "root", "spine_01": "pelvis", "spine_02": "spine_01",
	"neck": "spine_02", "head": "neck", "snout": "head", "goggles": "head",
	"ear.R": "head", "ear.L": "head", "crest": "head", "jaw": "head",
	"shoulder.R": "spine_02", "shoulder.L": "spine_02",
	"upper_arm.R": "shoulder.R", "upper_arm.L": "shoulder.L",
	"lower_arm.R": "upper_arm.R", "lower_arm.L": "upper_arm.L",
	"hand.R": "lower_arm.R", "hand.L": "lower_arm.L",
	"curl.R": "hand.R", "curl.L": "hand.L", "tail.01": "pelvis",
	"tail.02": "tail.01", "tool.R": "hand.R",
}
const CLIPS := {"drop_land": 2.1666667, "big_cheer": 2.8, "wince": 0.5,
	"slump": 1.5, "phew": 0.8, "brace": 0.6, "heave": 0.8}
const KEY_POSES := {"drop_land": 16.0 / 30, "big_cheer": 24.0 / 30, "wince": 2.0 / 30,
	"slump": 22.0 / 30, "phew": 9.0 / 30, "brace": 5.0 / 30, "heave": 6.0 / 30}
const SOCKETS := {
	"ReaderExit": Vector3(0, -0.32, -0.81),
	"CardBay.0": Vector3(-0.23, -0.32, -0.80),
	"CardBay.1": Vector3(0, -0.32, -0.80),
	"CardBay.2": Vector3(0.23, -0.32, -0.80),
	"FlywheelAxis.R": Vector3(0.50, -0.28, 0.35),
	"FlywheelAxis.L": Vector3(-0.50, -0.28, 0.35),
	"ReturnExit": Vector3(0, -0.48, -0.72),
	"StampContact": Vector3(0, -0.82, -0.12),
	"LedgerMount": Vector3(-0.255, -0.20, -0.045),
	"Grip.R": Vector3(0.32, 0.05, -0.40),
	"Grip.L": Vector3(-0.32, 0.05, -0.40),
}

var _failures := 0
var _checks := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _doc(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 20:
		_check("GLB bytes", false, path)
		return {}
	var result = JSON.parse_string(bytes.slice(20, 20 + bytes.decode_u32(12)).get_string_from_utf8())
	return result if result is Dictionary else {}


func _load_asset(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var error := doc.append_from_file(path, state)
	_check("GLTF load", error == OK, "%s error %d" % [path, error])
	if error != OK:
		return Node.new()
	return doc.generate_scene(state)


func _meshes(node: Node, out: Array = []) -> Array:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_meshes(child, out)
	return out


func _to_root(node: Node, asset: Node) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current := node
	while current != null and current != asset:
		if current is Node3D:
			transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform


func _shell_node(asset: Node, name: String) -> Node:
	# Godot sanitizes periods in non-bone glTF node names to underscores.
	return asset.find_child(name.replace(".", "_"), true, false)


func _counts(asset: Node) -> Dictionary:
	var counts := {"triangles": 0, "vertices": 0, "draws": 0, "slots": []}
	for mi in _meshes(asset):
		for i in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(i)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index = arrays[Mesh.ARRAY_INDEX]
			counts.vertices += vs.size()
			counts.triangles += int((index.size() if index != null else vs.size()) / 3)
			counts.draws += 1
			var mat: Material = mi.mesh.surface_get_material(i)
			var slot := mat.resource_name if mat != null else "<missing>"
			if not slot in counts.slots:
				counts.slots.append(slot)
	return counts


func _budget(label: String, asset: Node, limit: Vector3i, allowed: Array) -> void:
	var counts := _counts(asset)
	_check(label + " budget", counts.triangles > 0 and counts.triangles <= limit.x
		and counts.vertices <= limit.y and counts.draws <= limit.z,
		"%d triangles / %d vertices / %d draws; caps %d / %d / %d" % [
			counts.triangles, counts.vertices, counts.draws, limit.x, limit.y, limit.z])
	_check(label + " materials", counts.slots.size() <= 5 and counts.slots.all(func(s): return s in allowed),
		"slots %s" % [counts.slots])


func _pilot(pilot: Node, document: Dictionary) -> void:
	var skins: Array = document.get("skins", [])
	_check("one skin", skins.size() == 1, "skin count %d" % skins.size())
	var skeletons := pilot.find_children("*", "Skeleton3D", true, false)
	_check("one skeleton", skeletons.size() == 1, "skeleton count %d" % skeletons.size())
	if skeletons.size() != 1:
		_check("25 named bones", false, "no usable skeleton")
		_check("seven named clips", false, "no usable skeleton")
		return
	var skeleton := skeletons[0] as Skeleton3D
	var rig := pilot.find_child("TallyRig", true, false) as Node3D
	_check("identity rig root", rig != null and rig.transform.is_equal_approx(Transform3D.IDENTITY))
	var names: Array = []
	for i in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(i))
	names.sort()
	var expected := BONES.duplicate()
	expected.sort()
	_check("25 named bones", names.size() == 25 and names == expected,
		"count=%d missing=%s extra=%s" % [names.size(), expected.filter(func(n): return not n in names),
			names.filter(func(n): return not n in expected)])
	for name in names:
		var index := skeleton.find_bone(name)
		var parent := skeleton.get_bone_parent(index)
		var parent_name := skeleton.get_bone_name(parent) if parent >= 0 else ""
		_check("parent " + name, PARENTS.get(name, "<unknown>") == parent_name, parent_name)
	if not skins.is_empty():
		_check("25 exported joints", skins[0].get("joints", []).size() == 25,
			"GLB skin includes unused controls")
	var player := pilot.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips: Array = Array(player.get_animation_list()) if player != null else []
	clips.erase("RESET")
	clips.sort()
	var expected_clips := CLIPS.keys()
	expected_clips.sort()
	_check("seven named clips", clips == expected_clips,
		"expected %s; imported %s" % [expected_clips, clips])
	for name in CLIPS:
		if player == null or not player.has_animation(name):
			_check("clip " + name, false, "missing required clip")
			continue
		var animation := player.get_animation(name)
		_check("duration " + name, absf(animation.length - CLIPS[name]) < 0.001,
			"%.6f seconds" % animation.length)
		_check("one-shot " + name, animation.loop_mode == Animation.LOOP_NONE)
		for time in [0.0, animation.length]:
			player.play(name)
			player.seek(time, true)
			player.advance(0.0)
			var error := 0.0
			for i in skeleton.get_bone_count():
				var delta := skeleton.get_bone_rest(i).affine_inverse() * skeleton.get_bone_pose(i)
				error = maxf(error, delta.origin.length())
				error = maxf(error, delta.basis.get_rotation_quaternion().angle_to(Quaternion.IDENTITY))
				error = maxf(error, (delta.basis.get_scale() - Vector3.ONE).length())
			_check("neutral %s %.3f" % [name, time], error < 0.0001, "pose component error %.8f" % error)
		player.play(name)
		player.seek(KEY_POSES[name], true)
		player.advance(0.0)
		var movement := 0.0
		for i in skeleton.get_bone_count():
			var delta := skeleton.get_bone_rest(i).affine_inverse() * skeleton.get_bone_pose(i)
			movement = maxf(movement, delta.origin.length())
			movement = maxf(movement, (delta.basis.x - Vector3.RIGHT).length())
			movement = maxf(movement, (delta.basis.y - Vector3.UP).length())
			movement = maxf(movement, (delta.basis.z - Vector3.BACK).length())
		_check("key pose " + name, movement > 0.01, "bone transform difference %.6f" % movement)
		var root_motion := 0.0
		for frame in range(ceili(animation.length * 60) + 1):
			player.seek(minf(frame / 60.0, animation.length), true)
			player.advance(0.0)
			for bone in ["root", "pelvis"]:
				var i := skeleton.find_bone(bone)
				if i >= 0:
					var delta := skeleton.get_bone_rest(i).affine_inverse() * skeleton.get_bone_pose(i)
					root_motion = maxf(root_motion, delta.origin.length())
		_check("no root motion " + name, root_motion < 0.00001, "60 Hz translation error %.8f" % root_motion)
		player.stop()
	for mi in _meshes(pilot):
		_check("skinned " + String(mi.name), mi.skin != null and not mi.skeleton.is_empty())
		for surface in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(surface)
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var rigid := not weights.is_empty()
			for i in range(0, weights.size(), 4):
				var active := 0
				var total := 0.0
				for j in 4:
					active += 1 if weights[i + j] > 0.001 else 0
					total += weights[i + j]
				rigid = rigid and active == 1 and absf(total - 1.0) < 0.001
			_check("rigid weights " + str(surface), rigid, "one full weight per vertex")
	_budget("pilot", pilot, Vector3i(4600, 3100, 5), ["pilot", "rubber", "bare_metal"])


func _shell(shell: Node, document: Dictionary) -> void:
	_budget("shell", shell, Vector3i(11000, 11600, 10), ["paint", "bare_metal", "rubber", "class_accent", "glass"])
	_check("shell has no skeleton", document.get("skins", []).is_empty())
	_check("no duplicate pilot", shell.find_child("Pilot", true, false) == null)
	var source_names: Array = document.get("nodes", []).map(func(n): return n.get("name", ""))
	for name in ["Core", "Pod", "Dome", "Gyro", "ReaderCarriage", "Flywheel.R", "Flywheel.L"]:
		_check("shell node " + name, name in source_names and _shell_node(shell, name) != null)
	var pod := shell.find_child("Pod", true, false)
	var dome := shell.find_child("Dome", true, false) as Node3D
	_check("identity Dome", dome != null and dome.transform.is_equal_approx(Transform3D.IDENTITY))
	for name in ["Gyro", "ReaderCarriage", "Flywheel.R", "Flywheel.L", "Dome"]:
		var node := _shell_node(shell, name)
		_check("upright " + name, node != null and node.get_parent() == pod)
	var max_radius := 0.0
	var glass_radius := 0.0
	for mi in _meshes(shell):
		var transform := _to_root(mi, shell)
		for i in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
				var radius: float = (transform * v).length()
				max_radius = maxf(max_radius, radius)
				if String(mi.name) == "Core":
					glass_radius = maxf(glass_radius, radius)
	_check("resting radius", max_radius <= 0.98501, "%.6f m, cap 0.985" % max_radius)
	_check("glass radius", absf(glass_radius - 0.98) < 0.0001, "%.6f m; imported vertex tolerance 0.1 mm" % glass_radius)
	for name in SOCKETS:
		var node := _shell_node(shell, name) as Node3D
		_check("socket " + name, name in source_names and node != null and (_to_root(node, shell).origin - SOCKETS[name]).length() < 0.00001,
			"expected %s" % SOCKETS[name])
	var bays := shell.find_children("CardBay_*", "", true, false)
	_check("exactly three card bays", bays.size() == 3, "bay count %d" % bays.size())
	for side in ["R", "L"]:
		var wheel := _shell_node(shell, "Flywheel." + side) as MeshInstance3D
		if wheel != null:
			var bounds := wheel.mesh.get_aabb()
			_check("flywheel diameter " + side, absf(bounds.size.y - 0.34) < 0.001
				and absf(bounds.size.z - 0.34) < 0.001 and absf(bounds.size.x - 0.07) < 0.0001,
				"%s; wheel diameter 0.34 m; axial depth 0.07 m" % bounds.size)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Scratch overrides load GLBs directly. Negative checks never alter delivered bytes.
	var pilot_path := OS.get_environment("SCRAPKEEP_TEST_TALLY_PILOT")
	if pilot_path.is_empty():
		pilot_path = PILOT
	var shell_path := OS.get_environment("SCRAPKEEP_TEST_TALLY_SHELL")
	if shell_path.is_empty():
		shell_path = SHELL
	var pilot := _load_asset(pilot_path)
	var shell := _load_asset(shell_path)
	root.add_child(pilot)
	root.add_child(shell)
	_pilot(pilot, _doc(pilot_path))
	_shell(shell, _doc(shell_path))
	pilot.free()
	shell.free()
	print("pilot_tally_asset_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
	print("tally asset checks: %d, failures: %d" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
