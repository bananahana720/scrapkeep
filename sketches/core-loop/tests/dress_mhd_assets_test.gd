extends SceneTree

const ASSET := "res://assets/models/bosses/mind_hand.glb"
const CLIPS := {"still_track": 2.0, "quote_warn": 1.4, "exact_strike": 0.2,
	"brace": 5.0, "recover": 3.0, "lens_break": 0.6}
const REST := {"HandRoot": Vector3.ZERO, "Foot": Vector3(0, -1.55, 0),
	"Segment0": Vector3(0, -1.3, 0), "Segment1": Vector3(0, 0.3, 0),
	"Segment2": Vector3(0, 1.9, 0), "LensRoot": Vector3(0, 3.4, 0),
	"MainLens": Vector3(0, 3.4, 0), "SideLensL": Vector3(-0.75, 3.2, 0.2),
	"SideLensR": Vector3(0.75, 3.2, 0.2), "LensShutter": Vector3(0, 3.4, -0.46),
	"WeakPoint": Vector3(0, 3.4, 0)}
var failures := 0
var blob: PackedByteArray
var doc := {}
var binary_start := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("%s -> %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		failures += 1


func finish() -> void:
	print("dress_mhd_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func column(id: int) -> Array:
	var acc: Dictionary = doc.accessors[id]
	var view: Dictionary = doc.bufferViews[acc.bufferView]
	var width: int = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}.get(acc.type, 0)
	var size: int = {5121: 1, 5123: 2, 5125: 4, 5126: 4}.get(int(acc.componentType), 0)
	var offset: int = binary_start + int(view.get("byteOffset", 0)) + int(acc.get("byteOffset", 0))
	var stride: int = view.get("byteStride", width * size)
	var out := []
	for i in int(acc.count):
		var values := []
		for j in width:
			var at := offset + i * stride + j * size
			match int(acc.componentType):
				5121: values.append(blob.decode_u8(at))
				5123: values.append(blob.decode_u16(at))
				5125: values.append(blob.decode_u32(at))
				5126: values.append(blob.decode_float(at))
		out.append(values)
	return out


func _run() -> void:
	# Scratch GLBs exercise missing-node/clip failures without replacing the asset.
	var path := OS.get_environment("MHD_ASSET")
	if path.is_empty():
		path = ASSET
	blob = FileAccess.get_file_as_bytes(path)
	check(blob.size() >= 20 and blob.decode_u32(0) == 0x46546c67, "GLB exists and has glTF magic")
	if blob.size() < 20:
		finish()
		return
	var json_size := blob.decode_u32(12)
	doc = JSON.parse_string(blob.slice(20, 20 + json_size).get_string_from_utf8())
	binary_start = 20 + json_size + 8
	var node_names := []
	for node in doc.nodes:
		node_names.append(node.get("name", ""))
	for name in REST:
		check(name in node_names, "required GLB node " + name)
	var controls := ["HazardFace", "MintTarget", "SlateTarget", "Iris0", "Iris1", "Iris2", "Iris3", "Iris4", "Iris5"]
	for name in controls:
		check(name in node_names, "required mask control " + name)
	var clip_names := []
	for clip in doc.get("animations", []):
		clip_names.append(clip.get("name", ""))
	for name in CLIPS:
		check(name in clip_names, "required GLB clip " + name)
	check(clip_names.size() == CLIPS.size(), "exactly six assigned clips")
	check(doc.get("skins", []).size() == 1, "one skin")
	check(doc.meshes.size() == 1, "one batched skinned mesh")
	if failures > 0:
		finish()
		return
	var scene: Node3D
	if path == ASSET:
		var packed := load(path) as PackedScene
		check(packed != null, "Godot imported GLB loads")
		if packed != null:
			scene = packed.instantiate()
	else:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		check(document.append_from_file(path, state) == OK, "scratch GLB imports")
		scene = document.generate_scene(state)
	if scene == null:
		finish()
		return
	root.add_child(scene)
	check(scene.transform.is_equal_approx(Transform3D.IDENTITY), "identity metre root")
	check(scene.find_children("*", "CollisionObject3D", true, false).is_empty()
		and scene.find_children("*", "CollisionShape3D", true, false).is_empty(), "asset adds no collision")
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	check(skeletons.size() == 1, "Godot imports one skeleton")
	if skeletons.size() != 1:
		scene.free()
		finish()
		return
	var sk := skeletons[0] as Skeleton3D
	for name in REST:
		var index := sk.find_bone(name)
		check(index >= 0, "required runtime bone " + name)
		if index >= 0:
			check(sk.get_bone_global_rest(index).origin.distance_to(REST[name]) < 0.0001,
				"root-local rest socket " + name)
	for name in controls:
		check(sk.find_bone(name) >= 0, "required runtime mask control " + name)
	if failures > 0:
		scene.free()
		finish()
		return
	var vertices := 0
	var triangles := 0
	var draws := 0
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		check(mesh.skin != null, "mesh uses the skin")
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			vertices += arrays[Mesh.ARRAY_VERTEX].size()
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			draws += 1
			var mat: BaseMaterial3D = mesh.mesh.surface_get_material(surface)
			check(mat != null and mat.resource_name in ["M1_ancient_enamel__M2_dark_joint", "M4_signal_surface", "M3_glass"],
				"only shared material families")
			if mat != null and mat.albedo_texture != null:
				check(mat.albedo_texture.get_width() <= 2048 and mat.albedo_texture.get_height() <= 2048, "texture cap 2048")
	# Caps raised for the 2026-10-18 model polish (tools/blender/POLISH.md); draws unchanged.
	print("MHD_BUDGET tris=%d/4000 verts=%d/7600 draws=%d/3" % [triangles, vertices, draws])
	check(triangles > 0 and triangles <= 4000 and vertices > 0 and vertices <= 7600 and draws == 3, "enemy budget caps")
	# Actual weighted POSITION data checks the foot and lens envelopes, rather
	# than trusting labels or an author-written metadata budget.
	var bounds := {}
	var joints: Array = doc.skins[0].joints
	var rigid := true
	for mesh in doc.meshes:
		for primitive in mesh.primitives:
			var pos := column(primitive.attributes.POSITION)
			var bone_ids := column(primitive.attributes.JOINTS_0)
			var weights := column(primitive.attributes.WEIGHTS_0)
			for i in pos.size():
				rigid = rigid and is_equal_approx(float(weights[i][0]), 1.0)
				var name: String = doc.nodes[int(joints[int(bone_ids[i][0])])].name
				var v := Vector3(pos[i][0], pos[i][1], pos[i][2])
				if not bounds.has(name):
					bounds[name] = [v, v]
				bounds[name][0] = bounds[name][0].min(v)
				bounds[name][1] = bounds[name][1].max(v)
	check(rigid, "every vertex has one rigid weight")
	var raw_triangles := 0
	var raw_vertices := 0
	var raw_draws := 0
	for mesh in doc.meshes:
		for primitive in mesh.primitives:
			raw_triangles += int(doc.accessors[int(primitive.indices)].count) / 3
			raw_vertices += int(doc.accessors[int(primitive.attributes.POSITION)].count)
			raw_draws += 1
	# Caps raised for the 2026-10-18 model polish (tools/blender/POLISH.md); draws unchanged.
	print("MHD_GLB_BUDGET tris=%d/4000 verts=%d/7600 draws=%d/3" % [raw_triangles, raw_vertices, raw_draws])
	check(raw_triangles > 0 and raw_triangles <= 4000 and raw_vertices > 0 and raw_vertices <= 7600 and raw_draws == 3,
		"exported GLB budget caps")
	if bounds.has("Foot"):
		var lo: Vector3 = bounds.Foot[0]
		var hi: Vector3 = bounds.Foot[1]
		check(absf(lo.y + 1.8) < 0.001 and absf(hi.y + 1.3) < 0.001 and absf(hi.x - lo.x - 2.2) < 0.001,
			"foot D2.2 H0.5 contact y=-1.8")
	for name in ["MainLens", "SideLensL", "SideLensR"]:
		check(bounds.has(name), "weighted lens geometry " + name)
		if bounds.has(name):
			var diameter := 1.4 if name == "MainLens" else 0.5
			var size: Vector3 = bounds[name][1] - bounds[name][0]
			check(absf(size.x - diameter) < 0.001 and absf(size.y - diameter) < 0.001, "rest lens diameter " + name)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	check(players.size() == 1, "Godot imports AnimationPlayer")
	if players.size() == 1:
		var player := players[0] as AnimationPlayer
		for name in CLIPS:
			check(player.has_animation(name), "required runtime clip " + name)
			if not player.has_animation(name):
				continue
			var animation := player.get_animation(name)
			check(absf(animation.length - CLIPS[name]) < 0.0001, "clip duration " + name)
			for seconds in [0.0, animation.length / 2, animation.length]:
				player.play(name)
				player.seek(seconds, true)
				player.advance(0)
				var root_index := sk.find_bone("HandRoot")
				var root_rest := sk.get_bone_rest(root_index)
				check(sk.get_bone_pose_position(root_index).distance_to(root_rest.origin) < 0.0001
					and absf(sk.get_bone_pose_rotation(root_index).dot(root_rest.basis.get_rotation_quaternion())) > 0.99999,
					"no root motion %s at %.2f" % [name, seconds])
				if name in ["quote_warn", "brace", "exact_strike", "recover", "still_track"]:
					var lens_index := sk.find_bone("LensRoot")
					check(sk.get_bone_pose_position(lens_index).distance_to(sk.get_bone_rest(lens_index).origin) < 0.0001, "fixed lens target " + name)
			if name == "quote_warn":
				var angle := sk.get_bone_pose_rotation(sk.find_bone("Segment1")).get_euler().x
				check(absf(angle + 0.5) < 0.001, "warning middle hinge -0.5 radians")
				check(sk.get_bone_pose_scale(sk.find_bone("MainLens")).is_equal_approx(Vector3.ONE * 1.3), "warning lens scale 1.3")
			if name == "brace":
				check(sk.get_bone_pose_scale(sk.find_bone("MainLens")).is_equal_approx(Vector3.ONE * 1.5), "brace lens scale 1.5")
				check(sk.get_bone_pose_scale(sk.find_bone("MintTarget")).is_equal_approx(Vector3.ONE), "brace exposes mint target")
			if name in ["still_track", "recover"]:
				check(sk.get_bone_pose_scale(sk.find_bone("MintTarget")).x < 0.002
					and sk.get_bone_pose_scale(sk.find_bone("HazardFace")).x < 0.002, "rest clears combat masks " + name)
	scene.free()
	finish()
