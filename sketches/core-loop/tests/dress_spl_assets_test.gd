extends SceneTree

# Loads fresh GLBs through Godot's importer, then checks rigid skin geometry at
# every exported animation sample. Pair files contain only the selected modules.
const DIR := "res://assets/models/companion/"
const PIECES := ["primer_coil", "primer_mesh", "ram_prow", "ram_spring", "escape_vent", "escape_rail"]
const HULL_NODES := ["Spil9", "Hull", "Deck", "LiftPlenum", "LiftWell.01", "LiftWell.02", "LiftWell.03",
	"Bumper", "ServiceBrow", "EscapeWitness", "Socket.01", "Socket.02", "TrailWitness"]
const MODULE_NODES := {
	"primer_coil": ["ModuleRoot", "Foot", "FootBlock", "CoilPivot", "CoilRing"],
	"primer_mesh": ["ModuleRoot", "Foot", "Stem", "MeshPivot", "MeshFrame"],
	"ram_prow": ["ModuleRoot", "Foot", "Adaptor", "ProwSlide", "ProwBeam", "Sleeve"],
	"ram_spring": ["ModuleRoot", "Foot", "Adaptor", "SpringSlide", "SpringCage", "Spring"],
	"escape_vent": ["ModuleRoot", "Foot", "FootBox", "VaneHinge.L", "VaneHinge.R", "Vanes.L", "Vanes.R"],
	"escape_rail": ["ModuleRoot", "Foot", "Carriage", "RailSlide.L", "RailSlide.R", "Rails.L", "Rails.R"],
}
const HULL_CLIPS := {"idle": 1.6, "follow": 0.18, "dock": 0.25, "empty": 0.25, "escape_spent": 0.14, "escape_rearm": 0.20,
	"assist_rise": 0.15, "assist_drop": 0.15, "assist_return": 0.45}
# The called assist is a whole-body act on BodyPose (squash, stretch, pitch); nothing held lives there.
const ASSIST_CLIPS := ["assist_rise", "assist_drop", "assist_return"]
const MODULE_CLIPS := {
	"primer_coil": {"primer_set": 0.12, "primer_consume": 0.16, "primer_expire": 0.12},
	"primer_mesh": {"primer_set": 0.12, "primer_consume": 0.16, "primer_expire": 0.12},
	"ram_prow": {"prow_response": 0.20},
	"ram_spring": {"spring_arm": 0.10, "spring_spend": 0.18},
	"escape_vent": {}, "escape_rail": {},
}
var failures := 0
var loaded := 0
var samples := 0
var minimum_gap := INF
var max_envelope := Vector3.ZERO
var max_height_above_root := 0.0
var asset_dir := DIR
var canonical_foot := {}
var checked_clips := 0
var held_state_checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("SPL violation: " + label)


func _json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check(false, "missing GLB " + path)
		return {}
	_check(file.get_32() == 0x46546c67 and file.get_32() == 2, "GLB header " + path)
	file.get_32()
	var size := file.get_32()
	_check(file.get_32() == 0x4e4f534a, "GLB JSON chunk " + path)
	var parsed = JSON.parse_string(file.get_buffer(size).get_string_from_utf8())
	_check(parsed is Dictionary, "GLB JSON " + path)
	return parsed if parsed is Dictionary else {}


func _names(scene: Node) -> Array:
	var names: Array = [String(scene.name)]
	for node in scene.find_children("*", "", true, false):
		names.append(String(node.name))
		if node is Skeleton3D:
			for i in node.get_bone_count():
				names.append(node.get_bone_name(i))
	return names


func _pose_vertices(scene: Node) -> Dictionary:
	var groups := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var skin := mesh.skin
		var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		_check(skin != null and skeleton != null, "rigid skin retained")
		if skin == null or skeleton == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride := bones.size() / vertices.size()
			for i in vertices.size():
				var bind := bones[i * stride]
				var bone := skin.get_bind_bone(bind)
				if bone < 0:
					bone = skeleton.find_bone(skin.get_bind_name(bind))
				_check(bone >= 0 and is_equal_approx(weights[i * stride], 1.0), "one rigid weight per vertex")
				if bone < 0:
					continue
				var name := skeleton.get_bone_name(bone)
				var p: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind) * vertices[i]
				if not groups.has(name):
					groups[name] = []
				groups[name].append(p)
	return groups


func _bounds(points: Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	return box


func _gap(a: AABB, b: AABB) -> float:
	var d := Vector3.ZERO
	for axis in 3:
		d[axis] = maxf(0.0, maxf(a.position[axis] - b.end[axis], b.position[axis] - a.end[axis]))
	return d.length()


func _geometry(scene: Node, pair: bool, label: String, whole_body := false) -> void:
	var groups := _pose_vertices(scene)
	var points: Array = []
	var left := {}
	var right := {}
	for name in groups:
		points.append_array(groups[name])
		if String(name).begins_with("M1."):
			left[name] = _bounds(groups[name])
		elif String(name).begins_with("M2."):
			right[name] = _bounds(groups[name])
	_check(not points.is_empty(), "nonempty posed geometry " + label)
	if points.is_empty():
		return
	# An assist moves and squashes the whole fitted assembly, so its envelope is the runtime's to place;
	# module clearance still holds at every sample.
	if pair and not whole_body:
		var bounds := _bounds(points)
		max_envelope = max_envelope.max(bounds.size)
		max_height_above_root = maxf(max_height_above_root, bounds.end.y)
		_check(bounds.size.x <= 1.65 + 0.0001 and bounds.end.y <= 1.20 + 0.0001 and bounds.size.z <= 0.90 + 0.0001,
			"fitted envelope " + label + " " + str(bounds))
	if pair:
		_check(not left.is_empty() and not right.is_empty(), "two selected modules " + label)
		for a in left:
			for b in right:
				var distance := _gap(left[a], right[b])
				minimum_gap = minf(minimum_gap, distance)
				_check(distance >= 0.06 - 0.0001, "clearance " + label + " " + a + "/" + b + " %.4f" % distance)
	samples += 1


func _combined_extremes(scene: Node, label: String) -> void:
	var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(skeleton != null, "mechanical skeleton for combined extremes")
	if skeleton == null:
		return
	for pitch in [-8.0, 0.0, 8.0]:
		for prime in [-20.0, 0.0, 20.0]:
			for compression in [0.7, 1.0]:
				for slide in [0.0, 0.12]:
					skeleton.reset_bone_poses()
					for i in skeleton.get_bone_count():
						var n := skeleton.get_bone_name(i)
						var rest_rotation := skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
						if n == "BodyPose":
							skeleton.set_bone_pose_rotation(i, rest_rotation * Quaternion(Vector3.RIGHT, deg_to_rad(pitch)))
						elif n.ends_with("CoilPivot") or n.ends_with("MeshPivot"):
							# Rest joint axes retain Blender Z up and Y forward beneath BodyPose.
							skeleton.set_bone_pose_rotation(i, rest_rotation * Quaternion(Vector3.BACK, deg_to_rad(prime)))
						elif n.ends_with("SpringSlide"):
							skeleton.set_bone_pose_scale(i, Vector3(compression, 1, 1))
						elif n.ends_with("ProwSlide"):
							skeleton.set_bone_pose_position(i, skeleton.get_bone_rest(i).origin + Vector3(0, -slide, 0))
					_geometry(scene, true, label + " combined %.0f/%.0f/%.1f/%.2f" % [pitch, prime, compression, slide])
	skeleton.reset_bone_poses()


func _feet(scene: Node, pair: bool, label: String) -> void:
	var groups := _pose_vertices(scene)
	for name in groups:
		if name != "Foot" and name != "M1.Foot" and name != "M2.Foot":
			continue
		var offset := Vector3.ZERO
		if pair:
			offset = Vector3(-0.29 if name == "M1.Foot" else 0.29, 0.225, 0.0)
		var positions := {}
		for p in groups[name]:
			var local: Vector3 = p - offset
			positions[Vector3i(roundi(local.x * 10000), roundi(local.y * 10000), roundi(local.z * 10000))] = true
		if canonical_foot.is_empty():
			canonical_foot = positions
		_check(positions.size() == canonical_foot.size(), "shared foot vertex count " + label)
		for key in positions:
			_check(canonical_foot.has(key), "shared foot orientation " + label + " " + name)


func _owns_channel(clip: String, node: String, path: String) -> bool:
	if clip in ASSIST_CLIPS:
		return node == "BodyPose" and path in ["translation", "rotation", "scale"]
	if clip in ["idle", "dock", "empty"]:
		return node == "BodyPose" and path == "translation"
	if clip == "follow":
		return node == "BodyPose" and path == "rotation"
	if clip.begins_with("primer_"):
		return (node.ends_with("CoilPivot") or node.ends_with("MeshPivot")) and path == "rotation"
	if clip == "prow_response":
		return node.ends_with("ProwSlide") and path == "translation"
	if clip in ["spring_arm", "spring_spend"]:
		return node.ends_with("SpringSlide") and path == "scale"
	if clip in ["escape_spent", "escape_rearm"]:
		return node == "EscapeWitness" and path == "rotation"
	return false


func _held_states(scene: Node, player: AnimationPlayer) -> void:
	var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or player == null:
		return
	if player.has_animation("escape_spent") and player.has_animation("idle"):
		var witness := skeleton.find_bone("EscapeWitness")
		player.play("escape_spent")
		player.seek(0.14, true)
		player.advance(0)
		player.stop(true)
		var spent := skeleton.get_bone_pose_rotation(witness)
		player.play("idle")
		player.seek(0.4, true)
		player.advance(0)
		_check(skeleton.get_bone_pose_rotation(witness).is_equal_approx(spent), "idle leaves the spent shutter unchanged")
		held_state_checks += 1
		player.stop(true)
	if player.has_animation("primer_set") and player.has_animation("spring_arm"):
		var prime := -1
		var spring := -1
		for i in skeleton.get_bone_count():
			var n := skeleton.get_bone_name(i)
			if n.ends_with("CoilPivot") or n.ends_with("MeshPivot"):
				prime = i
			elif n.ends_with("SpringSlide"):
				spring = i
		player.play("primer_set")
		player.seek(0.12, true)
		player.advance(0)
		player.stop(true)
		var primed := skeleton.get_bone_pose_rotation(prime)
		player.play("spring_arm")
		player.seek(0.10, true)
		player.advance(0)
		_check(skeleton.get_bone_pose_rotation(prime).is_equal_approx(primed), "arming spring preserves the held primer")
		held_state_checks += 1
		player.stop(true)
		var armed := skeleton.get_bone_pose_scale(spring)
		player.play("primer_consume")
		player.seek(0.16, true)
		player.advance(0)
		_check(skeleton.get_bone_pose_scale(spring).is_equal_approx(armed), "consuming primer preserves the armed spring")
		held_state_checks += 1
		player.stop(true)
	skeleton.reset_bone_poses()


func _asset(name: String, parts: Array, pair: bool, budget: Dictionary) -> void:
	var path := asset_dir + ("assembled/" if pair else "") + name + ".glb"
	var data := _json(path)
	if data.is_empty():
		return
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var err := document.append_from_file(path, state)
	_check(err == OK, "Godot GLB import " + path)
	if err != OK:
		return
	var scene := document.generate_scene(state)
	_check(scene != null, "Godot GLB scene " + path)
	if scene == null:
		return
	root.add_child(scene)
	loaded += 1
	var needed: Array = HULL_NODES.duplicate() if pair or name == "spil9" else []
	var clips: Dictionary = HULL_CLIPS.duplicate() if pair or name == "spil9" else {}
	for i in parts.size():
		for n in MODULE_NODES[parts[i]]:
			needed.append(("M%d." % (i + 1) if pair else "") + n)
		clips.merge(MODULE_CLIPS[parts[i]], true)
	var gltf_names: Array = []
	for node in data.get("nodes", []):
		gltf_names.append(String(node.get("name", "")))
	var runtime_names := _names(scene)
	_check(scene.find_children("*", "CollisionObject3D", true, false).is_empty(), "no companion combat collision")
	for n in needed:
		_check(gltf_names.has(n), "missing exported node " + path + " " + n)
		_check(runtime_names.has(n), "missing imported node/joint " + path + " " + n)
	var exported_clips: Array = []
	for animation in data.get("animations", []):
		checked_clips += 1
		exported_clips.append(String(animation.get("name", "")))
		_check(animation["channels"].size() == (3 if String(animation["name"]) in ASSIST_CLIPS else 1), "owned controls per clip " + path + " " + String(animation["name"]))
		for channel in animation["channels"]:
			var target: Dictionary = channel["target"]
			_check(_owns_channel(String(animation["name"]), String(data["nodes"][int(target["node"])]["name"]), String(target["path"])),
				"clip never resets another mechanism " + path + " " + String(animation["name"]))
	_check(not exported_clips.has("escape_release") and not exported_clips.has("escape_window"), "P-R7 removes escape-window clips")
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in clips:
		_check(exported_clips.has(clip), "missing exported clip " + path + " " + clip)
		_check(player != null and player.has_animation(clip), "missing imported clip " + path + " " + clip)
	var tris := 0
	var verts := 0
	var draws := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		draws += mesh.get_surface_count()
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			verts += arrays[Mesh.ARRAY_VERTEX].size()
			tris += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			var mat := mesh.surface_get_material(s) as StandardMaterial3D
			_check(mat != null and mat.resource_name in ["paint", "bare_metal", "rubber"], "three allowed materials " + path)
			if mat != null:
				_check(not mat.emission_enabled and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "opaque non-emissive hardware")
	var max_t := int(budget["tris"]) if pair else 620 if name == "spil9" else 240
	var max_v := int(budget["verts"]) if pair else 1140 if name == "spil9" else 480
	_check(tris > 0 and tris <= max_t and verts > 0 and verts <= max_v and draws > 0 and draws <= int(budget["draws"]),
		"budget " + path + " T/V/D %d/%d/%d" % [tris, verts, draws])
	print("SPL_BUDGET %s T=%d V=%d D=%d" % [name, tris, verts, draws])
	_geometry(scene, pair, name + " rest")
	if not parts.is_empty():
		_feet(scene, pair, name)
	var root_transform: Transform3D = (scene as Node3D).transform
	if player != null:
		for clip in clips:
			if not player.has_animation(clip):
				continue
			var animation := player.get_animation(clip)
			_check(absf(animation.length - float(clips[clip])) < 0.011, "duration " + name + " " + clip)
			# Sampling every exported 100 Hz key includes each mechanism extreme.
			var frames := roundi(animation.length * 100)
			for frame in frames + 1:
				player.play(clip)
				player.seek(float(frame) / 100, true)
				player.advance(0)
				_geometry(scene, pair, name + " " + clip + " %d" % frame, clip in ASSIST_CLIPS)
				_check((scene as Node3D).transform.is_equal_approx(root_transform), "no animation root motion " + clip)
			player.stop()
	if pair:
		_combined_extremes(scene, name)
	_held_states(scene, player)
	scene.free()


func _run() -> void:
	# A scratch GLB directory exercises missing-node/clip failures through the same importer.
	if OS.has_environment("SPL_ASSET_DIR"):
		asset_dir = OS.get_environment("SPL_ASSET_DIR").trim_suffix("/") + "/"
	var budgets = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_budgets.json"))
	_check(budgets is Dictionary and budgets.has("classes"), "budget source exists")
	if not (budgets is Dictionary and budgets.has("classes")):
		print("dress_spl_assets_test: FAIL")
		quit(1)
		return
	var enemy: Dictionary = budgets["classes"]["enemy"]
	# 2026-10-18 model polish raised the enemy class to 10000/19100/3 (tools/blender/POLISH.md); Spil-9 keeps its own
	# 620/1140 and 240/480 caps below.
	_check(enemy["tris"] == 10000 and enemy["verts"] == 19100 and enemy["draws"] == 3, "P-R7 enemy row 10000/19100/3")
	_asset("spil9", [], false, enemy)
	for p in PIECES:
		_asset(p, [p], false, enemy)
	var pair_count := 0
	for i in PIECES.size():
		for j in PIECES.size():
			if i / 2 == j / 2:
				continue
			_asset(PIECES[i] + "__" + PIECES[j], [PIECES[i], PIECES[j]], true, enemy)
			pair_count += 1
	_check(loaded == 31 and pair_count == 24 and samples > 1000, "7 sources, 12 pairs in both placements, nonzero pose samples")
	_check(checked_clips == 306 and held_state_checks == 33, "all clip controls and held-state checks ran")
	print("SPL_ANIMATION clips=%d held_state_checks=%d" % [checked_clips, held_state_checks])
	print("SPL_GEOMETRY loaded=%d pairs=%d samples=%d conservative_gap=%.4f max_envelope=%s height_above_root=%.4f" % [loaded, pair_count, samples, minimum_gap, max_envelope, max_height_above_root])
	print("dress_spl_assets_test: " + ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
