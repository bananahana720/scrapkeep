extends SceneTree

const ROOT := "res://assets/models/highdraft"
const PROP := Vector3i(1100, 800, 1)  # 2026-10-18 polish: was (270, 610, 1); prop class cap 2000 / 4600
const SCENERY := Vector3i(800, 500, 2)  # 2026-10-18 soft-toy polish: was (120, 110, 2); matches lift.py thermal_air cap
const ASSETS := {
	"thermal_vent": {"parts": ["MouthRim", "Grate", "DuctFoot"], "clips": {"idle": 0.1, "occupied": 0.1},
		"sockets": {"air_base": Vector3.ZERO, "entry": Vector3(0, 0, -3), "return_join": Vector3(0, 0, -4)},
		"bounds": Vector3(6, 1.8, 6)},
	"thermal_air": {"parts": ["AirColumn", "Crown"], "clips": {"rise_loop": 2.0},
		"sockets": {"exit": Vector3(0, 40, 0)}, "bounds": Vector3(13, 40, 13)},
	"net_tile": {"parts": ["Weave"], "clips": {"rest": 0.1, "catch": 0.4},
		"sockets": {"join_n": Vector3(0, 0, -2), "join_e": Vector3(2, 0, 0),
			"join_s": Vector3(0, 0, 2), "join_w": Vector3(-2, 0, 0)}, "bounds": Vector3(4, 0.06, 4)},
	"net_edge": {"parts": ["Pad", "Support"], "clips": {"rest": 0.1},
		"sockets": {"join_l": Vector3(-2, 0, 0), "join_r": Vector3(2, 0, 0), "shoe": Vector3(0, -0.2, 0)},
		"bounds": Vector3(4, 0.5, 0.5)},
	"net_shoe": {"parts": ["Foot", "Post", "CableCollar"], "clips": {"rest": 0.1},
		"sockets": {"cable": Vector3(0, 2, 0), "edge_join": Vector3(0, 1, 0)}, "bounds": Vector3(1, 2.4, 1)},
	"anchor_mast": {"parts": ["Foot", "Shaft", "ForkProng", "ForkProng_l", "ForkProng_r"], "clips": {"rest": 0.1},
		"sockets": {"eye_centre": Vector3(0, 16.6, 0), "stay_l": Vector3(-1.5, 0.4, 0), "stay_r": Vector3(1.5, 0.4, 0)},
		"bounds": Vector3(4.2, 18.4, 3)},
	"anchor_eye": {"parts": ["OuterRim", "Sleeve"], "clips": {"idle": 0.1, "ready": 0.1, "attached": 0.1},
		"sockets": {"rope_bite": Vector3(0, 0, -0.225), "collar_lb": Vector3(-1.2, -1.2, 0),
			"collar_lt": Vector3(-1.2, 1.2, 0), "collar_rb": Vector3(1.2, -1.2, 0), "collar_rt": Vector3(1.2, 1.2, 0)},
		"bounds": Vector3(3, 3, 0.45)},
	"anchor_collar": {"parts": ["Block"], "clips": {"close": 0.1, "open": 0.1},
		"sockets": {"slide_axis": Vector3.ZERO}, "bounds": Vector3(0.45, 0.45, 0.35)},
	"travel_vane": {"parts": ["Blade", "Stem", "VaneRig"], "clips": {"turn": 0.6},
		"sockets": {"mast_foot": Vector3.ZERO, "hinge": Vector3(0, 1.2, 0)}, "bounds": Vector3(2, 1.9, 0.2)}
}
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL MHL " + message)


func _glb(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	_check(file.get_32() == 0x46546c67, path + " GLB magic")
	_check(file.get_32() == 2, path + " GLB version")
	_check(file.get_32() == file.get_length(), path + " GLB length")
	var size := file.get_32()
	_check(file.get_32() == 0x4e4f534a, path + " JSON chunk")
	var parsed = JSON.parse_string(file.get_buffer(size).get_string_from_utf8())
	if not parsed is Dictionary:
		_check(false, path + " JSON parses")
		return {}
	var binary_size := file.get_32()
	_check(file.get_32() == 0x004e4942, path + " binary chunk")
	return {"doc": parsed, "binary": file.get_buffer(binary_size)}


func _floats(glb: Dictionary, id: int) -> Array:
	var doc: Dictionary = glb.doc
	var acc: Dictionary = doc.accessors[id]
	_check(int(acc.componentType) == 5126, "float accessor")
	var view: Dictionary = doc.bufferViews[int(acc.bufferView)]
	var widths := {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
	var width: int = widths[acc.type]
	var stride: int = int(view.get("byteStride", width * 4))
	var offset: int = int(view.get("byteOffset", 0)) + int(acc.get("byteOffset", 0))
	var data: PackedByteArray = glb.binary
	var rows: Array = []
	for i in int(acc.count):
		var row: Array = []
		for j in width:
			row.append(data.decode_float(offset + i * stride + j * 4))
		rows.append(row)
	return rows


func _node(root: Node, name: String) -> Node:
	if root.name == name:
		return root
	return root.find_child(name, true, false)


func _measure(root: Node) -> Dictionary:
	var total := Vector3i.ZERO
	var materials: Dictionary = {}
	var bounds := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		_check(mi.mesh != null, "imported mesh exists")
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			total.x += int((indices.size() if not indices.is_empty() else vertices.size()) / 3)
			total.y += vertices.size()
			total.z += 1
			var mat: Material = mi.mesh.surface_get_material(s)
			_check(mat != null, "surface material exists")
			if mat != null:
				materials[mat.get_instance_id()] = true
			for vertex in vertices:
				var pos: Vector3 = mi.global_transform * vertex
				if first:
					bounds = AABB(pos, Vector3.ZERO)
					first = false
				else:
					bounds = bounds.expand(pos)
	return {"counts": total, "materials": materials.size(), "bounds": bounds}


func _motion(glb: Dictionary, name: String, contract: Dictionary) -> void:
	var doc: Dictionary = glb.doc
	var clips: Dictionary = {}
	for clip in doc.get("animations", []):
		clips[clip.name] = clip
	for required in contract.clips:
		_check(clips.has(required), name + " clip " + required)
		if not clips.has(required):
			continue
		var clip: Dictionary = clips[required]
		_check(not clip.channels.is_empty(), name + " clip has channel")
		var times := _floats(glb, int(clip.samplers[0].input))
		_check(absf(float(times[-1][0]) - float(contract.clips[required])) < 0.00001,
			name + " " + required + " duration")
		for channel in clip.channels:
			_check(doc.nodes[int(channel.target.node)].name != name, name + " no root motion")
	if name == "anchor_collar" and clips.has("close"):
		var values := _floats(glb, int(clips.close.samplers[0].output))
		var a := Vector3(values[0][0], values[0][1], values[0][2])
		var b := Vector3(values[-1][0], values[-1][1], values[-1][2])
		_check(absf(a.distance_to(b) - 0.25) < 0.00001, "collar closes exactly 0.25 m")
		_check(clips.close.extras.tint == "8bf0d3" and clips.open.extras.tint == "596a7c", "collar state tint data")
	if name in ["net_tile", "thermal_air"]:
		var primitive: Dictionary = doc.meshes[0].primitives[0]
		var expected_targets := 1 if name == "net_tile" else 4
		_check(primitive.get("targets", []).size() == expected_targets, name + " vertex motion exists")
		if primitive.get("targets", []).size() == expected_targets:
			var delta := _floats(glb, int(primitive.targets[0].POSITION))
			var base := _floats(glb, int(primitive.attributes.POSITION))
			var moved := false
			for i in delta.size():
				moved = moved or absf(float(delta[i][1])) > 0.001
				if name == "net_tile":
					_check(absf(float(delta[i][1])) <= 0.15, "net deflection cap")
					_check(absf(float(base[i][1]) + float(delta[i][1])) <= 0.15, "net occupied contact plane")
			_check(moved, name + " motion is nonzero")
		if name == "thermal_air" and clips.has("rise_loop"):
			_check(float(clips.rise_loop.extras.upward_phase_metres_per_second) > 0, "air phase rises")
			var weights := _floats(glb, int(clips.rise_loop.samplers[0].output))
			_check(weights.slice(0, 4) == weights.slice(weights.size() - 4), "air phase loop is continuous")
	if name == "travel_vane":
		_check(doc.get("skins", []).size() == 1, "vane has one bone skin")
		var bone_names: Array = []
		for n in doc.nodes:
			bone_names.append(n.get("name", ""))
		_check("VaneHinge" in bone_names, "vane hinge bone")
	if name == "anchor_eye" and clips.has("idle"):
		_check(clips.idle.extras.sleeve_tint == "596a7c", "idle eye is slate")
		_check(clips.ready.extras.sleeve_tint == "8bf0d3" and clips.attached.extras.sleeve_tint == "8bf0d3", "live eye tint data")
	if name == "thermal_vent" and clips.has("idle") and clips.has("occupied"):
		_check(float(clips.occupied.extras.air_opacity) > float(clips.idle.extras.air_opacity), "occupied air is stronger, idle stays available")


func _playback(scene: Node, name: String, contract: Dictionary) -> void:
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	_check(players.size() == 1, name + " imported animation player")
	if players.size() != 1:
		return
	var player := players[0] as AnimationPlayer
	for clip in contract.clips:
		_check(player.has_animation(clip), name + " imported clip " + clip)
		if player.has_animation(clip):
			_check(absf(player.get_animation(clip).length - float(contract.clips[clip])) < 0.00001,
				name + " imported clip duration " + clip)
	if name == "net_tile" and player.has_animation("catch"):
		var weave := _node(scene, "Weave") as MeshInstance3D
		player.play("catch")
		player.advance(0.12)
		_check(weave.get_blend_shape_value(0) > 0.99, "Godot net catch reaches shallow settle")
		player.advance(0.28)
		_check(absf(weave.get_blend_shape_value(0)) < 0.0001, "Godot net catch returns without bounce")
	if name == "thermal_air" and player.has_animation("rise_loop"):
		var column := _node(scene, "AirColumn") as MeshInstance3D
		_check(column.mesh.get_blend_shape_count() == 4, "Godot air travelling phase targets")
		player.play("rise_loop")
		player.advance(0.5)
		_check(column.get_blend_shape_value(3) > 0.99, "Godot air advances its upward phase")
	if name == "anchor_collar" and player.has_animation("close"):
		var block := _node(scene, "Block") as MeshInstance3D
		player.play("close")
		player.advance(0.1)
		_check(block.position.length() < 0.0001, "Godot collar reaches closed socket")
		_check(block.get_blend_shape_value(0) > 0.99, "Godot closed collar displays mint")
		player.play("open")
		player.advance(0.1)
		_check(absf(block.position.length() - 0.25) < 0.0001, "Godot collar separates 0.25 m when idle")
		_check(absf(block.get_blend_shape_value(0)) < 0.0001, "Godot open collar displays slate")
	if name == "anchor_eye" and player.has_animation("ready"):
		var hardware := _node(scene, "Hardware") as MeshInstance3D
		for clip in ["ready", "attached", "idle"]:
			player.play(clip)
			player.advance(0.1)
			var expected := 0.0 if clip == "idle" else 1.0
			_check(absf(hardware.get_blend_shape_value(0) - expected) < 0.0001, "Godot eye sleeve state " + clip)
	if name == "travel_vane" and player.has_animation("turn"):
		var skeletons := scene.find_children("*", "Skeleton3D", true, false)
		_check(skeletons.size() == 1, "Godot vane skeleton")
		if skeletons.size() == 1:
			var skeleton := skeletons[0] as Skeleton3D
			var hinge := skeleton.find_bone("VaneHinge")
			_check(hinge >= 0, "Godot vane hinge bone")
			if hinge >= 0:
				player.play("turn")
				player.advance(0.3)
				var pose := skeleton.get_bone_global_pose(hinge)
				_check(pose.origin.distance_to(Vector3(0, 1.2, 0)) < 0.0001, "Godot vane turns at stem top")
				_check(pose.basis.is_equal_approx(Basis(Vector3.UP, PI / 2)), "Godot vane example turn is 90 degrees around Y")
	_check((scene as Node3D).transform.is_equal_approx(Transform3D.IDENTITY), name + " playback preserves root pivot")


func _asset(directory: String, name: String, contract: Dictionary) -> void:
	var path := directory.path_join(name + ".glb")
	_check(FileAccess.file_exists(path), name + ".glb must exist")
	if not FileAccess.file_exists(path):
		return
	var glb := _glb(path)
	if glb.is_empty():
		return
	var doc: Dictionary = glb.doc
	var raw_counts := Vector3i.ZERO
	for n in doc.nodes:
		if not n.has("mesh"):
			continue
		for primitive in doc.meshes[int(n.mesh)].primitives:
			raw_counts.x += int(doc.accessors[int(primitive.indices)].count) / 3
			raw_counts.y += int(doc.accessors[int(primitive.attributes.POSITION)].count)
			raw_counts.z += 1
	var cap := SCENERY if name == "thermal_air" else PROP
	_check(raw_counts.x > 0 and raw_counts.x <= cap.x and raw_counts.y > 0 and raw_counts.y <= cap.y and raw_counts.z <= cap.z,
		name + " exported budgets T/V/draws " + str(raw_counts))
	_check(doc.get("materials", []).size() == 1, name + " exactly one material")
	_check(doc.get("textures", []).is_empty() and doc.get("images", []).is_empty(), name + " no new surface atlas")
	_motion(glb, name, contract)
	var importer := GLTFDocument.new()
	var state := GLTFState.new()
	var err := importer.append_from_file(path, state)
	_check(err == OK, name + " Godot GLB import")
	if err != OK:
		return
	var scene := importer.generate_scene(state)
	_check(scene != null, name + " loaded scene")
	if scene == null:
		return
	root.add_child(scene)
	_check(scene is Node3D and scene.transform.is_equal_approx(Transform3D.IDENTITY), name + " identity root pivot")
	for part in contract.parts:
		_check(_node(scene, part) != null, name + " named part " + part)
	for socket in contract.sockets:
		var node := _node(scene, socket) as Node3D
		_check(node != null, name + " socket " + socket)
		if node != null:
			_check(node.global_position.distance_to(contract.sockets[socket]) < 0.0001, name + " socket position " + socket)
	_check(scene.find_children("*", "CollisionObject3D", true, false).is_empty(), name + " collision free")
	var measured := _measure(scene)
	var counts: Vector3i = measured.counts
	_check(counts.x > 0 and counts.x <= cap.x and counts.y > 0 and counts.y <= cap.y and counts.z <= cap.z,
		name + " imported budgets T/V/draws " + str(counts))
	_check(int(measured.materials) == 1, name + " imported material count")
	var actual: Vector3 = measured.bounds.size
	_check(actual.distance_to(contract.bounds) < 0.001, name + " metre bounds " + str(actual) + " expected " + str(contract.bounds))
	print("MHL_BUDGET %s T=%d V=%d draws=%d materials=%d" % [name, counts.x, counts.y, counts.z, measured.materials])
	_playback(scene, name, contract)
	scene.free()


func _run() -> void:
	var directory := OS.get_environment("MHL_ASSET_DIR")
	if directory.is_empty():
		directory = ROOT
	for name in ASSETS:
		_asset(directory, name, ASSETS[name])
	print("dress_mhl_assets_test: " + ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
