extends SceneTree

const DIRECTORY := "res://assets/models/bosses/"
const KIT_NAMES := ["CraneMasts", "CranePort", "CraneStarboard", "MagnetSocketPort", "MagnetSocketStarboard", "CableSpans", "CablePort", "CableStarboard", "CapSocket0", "CapSocket1", "CapSocket2", "AdmiralSeat"]
const SHIP_CLIPS := {"idle_roll": 1.2, "crane_warn": 1.4, "crane_sweep": 1.2, "magnet_hold_drip": 0.2, "enter_furnace": 0.6, "slag_warn": 9.0, "drone_deploy": 1.0, "enter_scuttle": 0.8, "charge_warn": 1.4, "wall_stun": 3.0, "eject": 2.5}
const SCOOTER_CLIPS := {"eject": 2.5, "chase": 1.0}
const CLIP_CONTROLS := {
	"idle_roll": ["Hull", "DrumL0", "DrumL1", "DrumL2", "DrumL3", "DrumR0", "DrumR1", "DrumR2", "DrumR3"],
	"crane_warn": ["CranePort", "CraneStarboard", "MagnetPort", "MagnetStarboard"],
	"crane_sweep": ["CranePort", "CraneStarboard", "MagnetPort", "MagnetStarboard"],
	"magnet_hold_drip": ["MagnetPort", "MagnetStarboard"],
	"enter_furnace": ["CraneMasts", "CableSpans", "CranePort", "CraneStarboard", "MagnetPort", "MagnetStarboard", "Cap0", "Cap1", "Cap2"],
	"slag_warn": ["SlagThroat", "Cap0", "Cap1", "Cap2"], "drone_deploy": ["HatchL", "HatchR"],
	"enter_scuttle": ["Armour0", "Armour1", "Armour2", "Armour3", "CockpitShield"],
	"charge_warn": ["BowRam", "Hull"], "wall_stun": ["Hull", "CockpitShield"],
	"eject": ["ScooterSeat"], "chase": ["ScooterSeat", "Drums"],
}
const FAMILIES := ["M0_workshop_steel", "M1_ancient_enamel", "M2_dark_joint", "M3_glass", "M4_signal_surface"]
const CAP_SPOTS := [Vector3(0, 5.4, -4.5), Vector3(-2.6, 5.4, 0.8), Vector3(2.6, 5.4, 0.8)]
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("BRI violation: " + label)


func _find(scene: Node, named: String) -> Node:
	if String(scene.name) == named:
		return scene
	return scene.find_child(named, true, false)


func _read_glb(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	_check(bytes.size() >= 28, "GLB exists and is nonempty: " + path)
	if bytes.size() < 28:
		return {}
	_check(bytes.decode_u32(0) == 0x46546c67 and bytes.decode_u32(4) == 2, "GLB v2 header")
	_check(bytes.decode_u32(8) == bytes.size(), "GLB declared byte size")
	var length := bytes.decode_u32(12)
	var parsed = JSON.parse_string(bytes.slice(20, 20 + length).get_string_from_utf8())
	_check(parsed is Dictionary, "GLB JSON parses")
	return parsed if parsed is Dictionary else {}


func _load_glb(path: String) -> Node3D:
	# The ordinary import is checked too. Scratch copies deliberately bypass its cache.
	if path.begins_with("res://"):
		var imported := load(path) as PackedScene
		_check(imported != null, "Godot PackedScene import: " + path)
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var error := document.append_from_file(path, state)
	_check(error == OK, "GLTFDocument loads: " + path)
	if error != OK:
		return null
	var scene := document.generate_scene(state)
	_check(scene != null, "GLTFDocument generates scene: " + path)
	if scene != null:
		root.add_child(scene)
	return scene


func _kit(node: Node, scooter: bool) -> bool:
	if scooter:
		return true
	var ancestor := node
	while ancestor != null:
		if String(ancestor.name) in KIT_NAMES:
			return true
		ancestor = ancestor.get_parent()
	return false


func _counts(scene: Node, scooter: bool) -> Dictionary:
	var rows := {"body": Vector3i.ZERO, "kit": Vector3i.ZERO}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		_check(mesh != null, "mesh assigned: " + String(node.name))
		if mesh == null:
			continue
		var allocation := "kit" if _kit(node, scooter) else "body"
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			var triangles := int((indices.size() if indices != null and indices.size() > 0 else vertices.size()) / 3)
			rows[allocation] += Vector3i(triangles, vertices.size(), 1)
			var material := mesh.surface_get_material(surface)
			_check(material != null and material.resource_name in FAMILIES, "shared material family: " + String(node.name))
	_check(scene.find_children("*", "CollisionObject3D", true, false).is_empty(), "assets have no gameplay colliders")
	_check(scene.find_children("*", "Skeleton3D", true, false).is_empty(), "rigid parts, no deformation skeleton")
	return rows


func _raw_counts(data: Dictionary, scooter: bool) -> Dictionary:
	var rows := {"body": Vector3i.ZERO, "kit": Vector3i.ZERO}
	if data.is_empty():
		return rows
	for scene in data.scenes:
		for index in scene.nodes:
			_raw_visit(data, int(index), scooter, rows)
	return rows


func _raw_visit(data: Dictionary, index: int, kit: bool, rows: Dictionary) -> void:
	var node: Dictionary = data.nodes[index]
	kit = kit or node.get("name", "") in KIT_NAMES
	if node.has("mesh"):
		for primitive in data.meshes[node.mesh].primitives:
			rows["kit" if kit else "body"] += Vector3i(int(data.accessors[primitive.indices].count / 3), int(data.accessors[primitive.attributes.POSITION].count), 1)
	for child in node.get("children", []):
		_raw_visit(data, int(child), kit, rows)


func _nodes(scene: Node, required: Array) -> void:
	for named in required:
		_check(_find(scene, named) is Node3D, "required node " + named)


func _animations(scene: Node, data: Dictionary, required: Dictionary) -> AnimationPlayer:
	var player := _find(scene, "AnimationPlayer") as AnimationPlayer
	_check(player != null, "AnimationPlayer exists")
	if player == null:
		return null
	var exported: Array = []
	_check(data.get("skins", []).is_empty(), "GLB has no deformation skin")
	_check(data.get("images", []).is_empty(), "untextured vertex colours satisfy 2048 px texture cap")
	for animation in data.get("animations", []):
		exported.append(animation.get("name", ""))
		_check(not animation.channels.is_empty(), "nonempty GLB animation " + animation.name)
		var controls: Array = []
		for channel in animation.channels:
			var named: String = data.nodes[channel.target.node].name
			controls.append(named)
			_check(not (named.ends_with("Root") or named.begins_with("CapSocket") or named.begins_with("MagnetSocket") or named.begins_with("CranePivot") or named.begins_with("DroneSocket") or named == "EjectSocket" or named in ["CablePort", "CableStarboard"]), "code-owned transform unanimated: " + named)
		for named in CLIP_CONTROLS.get(animation.name, []):
			_check(named in controls, "required animated control " + animation.name + "/" + named)
	for clip in required:
		_check(clip in exported, "required exported clip " + clip)
		_check(player.has_animation(clip), "required imported clip " + clip)
		if player.has_animation(clip):
			var animation := player.get_animation(clip)
			_check(absf(animation.length - required[clip]) < 0.002, "clip duration " + clip)
	return player


func _bounds(scene: Node3D, meshes: Array) -> AABB:
	var bounds := AABB()
	var started := false
	for mi: MeshInstance3D in meshes:
		var transform := scene.global_transform.affine_inverse() * mi.global_transform
		for surface in mi.mesh.get_surface_count():
			var vertices: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point: Vector3 = transform * vertex
				if not started:
					bounds = AABB(point, Vector3.ZERO)
					started = true
				else:
					bounds = bounds.expand(point)
	return bounds


func _near(a: Vector3, b: Vector3, label: String) -> void:
	_check(a.distance_to(b) < 0.003, label + " expected=" + str(b) + " actual=" + str(a))


func _rib_exposed(hull: MeshInstance3D, side: float) -> bool:
	var start := Vector3(side * 10, 3, 3.5)
	var end := Vector3(0, 3, 3.5)
	var nearest := INF
	var hit_x := 0.0
	for surface in hull.mesh.get_surface_count():
		var arrays := hull.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in range(0, indices.size(), 3):
			var point = Geometry3D.segment_intersects_triangle(start, end,
				hull.global_transform * vertices[indices[index]],
				hull.global_transform * vertices[indices[index + 1]],
				hull.global_transform * vertices[indices[index + 2]])
			if point is Vector3 and start.distance_to(point) < nearest:
				nearest = start.distance_to(point)
				hit_x = point.x
	return absf(hit_x - side * 4.495) < 0.002


func _sample(scene: Node3D, player: AnimationPlayer, clip: String, seconds: float, rest: Dictionary) -> void:
	player.stop()
	for node in rest:
		node.transform = rest[node]
	player.play(clip)
	player.seek(seconds, true)
	player.advance(0)
	var authored_root := _find(scene, "BrindleRoot") as Node3D
	if authored_root == null:
		authored_root = _find(scene, "ScooterRoot") as Node3D
	_check(authored_root != null and authored_root.transform.is_equal_approx(Transform3D.IDENTITY), "root motion disabled: " + clip)


func _run() -> void:
	var directory := OS.get_environment("BRI_ASSET_DIR")
	if directory.is_empty():
		directory = DIRECTORY
	var ship_path := directory.path_join("boss_brindle.glb")
	var scooter_path := directory.path_join("boss_brindle_scooter.glb")
	var ship_json := _read_glb(ship_path)
	var scooter_json := _read_glb(scooter_path)
	var ship := _load_glb(ship_path)
	var scooter := _load_glb(scooter_path)
	if ship == null or scooter == null:
		_finish()
		return
	var named: Array = ["BrindleRoot", "Hull", "DeckDressing", "CraneMasts", "BowRam", "CockpitShield", "AdmiralSeat", "Admiral", "ScooterSeat", "CranePort", "CraneStarboard", "CraneElbowPort", "CraneElbowStarboard", "CranePivotPort", "CranePivotStarboard", "MagnetPort", "MagnetStarboard", "MagnetSocketPort", "MagnetSocketStarboard", "CablePort", "CableStarboard", "CableSpans", "SlagThroat", "HatchL", "HatchR", "DroneSocketL", "DroneSocketR", "EjectSocket"]
	for k in range(4):
		named.append("Armour%d" % k)
		named.append("DrumL%d" % k)
		named.append("DrumR%d" % k)
	for k in range(3):
		named.append("Cap%d" % k)
		named.append("CapSocket%d" % k)
	_nodes(ship, named)
	_nodes(scooter, ["ScooterRoot", "ScooterSeat", "ScooterBody", "Drums"])
	var counts := _counts(ship, false)
	var scooter_counts := _counts(scooter, true)
	# Godot may weld identical exported vertices. Triangles/draws must stay exact,
	# and import must not increase vertices. Both exported and imported caps apply.
	var raw := _raw_counts(ship_json, false)
	var raw_scooter := _raw_counts(scooter_json, true)
	for allocation in ["body", "kit"]:
		_check(counts[allocation].x == raw[allocation].x and counts[allocation].z == raw[allocation].z and counts[allocation].y <= raw[allocation].y, "import preserves triangles/draws and may weld vertices: " + allocation)
	_check(scooter_counts.kit.x == raw_scooter.kit.x and scooter_counts.kit.z == raw_scooter.kit.z and scooter_counts.kit.y <= raw_scooter.kit.y, "scooter import preserves triangles/draws and may weld vertices")
	var body: Vector3i = counts.body
	var kit: Vector3i = counts.kit + scooter_counts.kit
	_check(body.x <= 14500 and body.y <= 11500 and body.z <= 32, "polished warden_base cap 14500/11500/32")
	_check(kit.x <= 5000 and kit.y <= 5000 and kit.z <= 18, "polished combined warden_kit cap 5000/5000/18")
	_check(raw.body.x <= 14500 and raw.body.y <= 11500 and raw.body.z <= 32, "exported warden_base cap")
	var raw_kit: Vector3i = raw.kit + raw_scooter.kit
	_check(raw_kit.x <= 5000 and raw_kit.y <= 5000 and raw_kit.z <= 18, "exported combined warden_kit cap")
	print("BRI budget: body %s; ship kit %s; scooter %s; combined kit %s (tris, verts, draws)" % [body, counts.kit, scooter_counts.kit, kit])
	var hull := _find(ship, "Hull") as MeshInstance3D
	if hull != null:
		var bounds := _bounds(ship, [hull])
		_near(bounds.size, Vector3(9, 5, 14), "Hull envelope")
		_near(bounds.get_center(), Vector3(0, 2.5, 0), "Hull ground-centred")
	var scooter_bounds := _bounds(scooter, scooter.find_children("*", "MeshInstance3D", true, false))
	_near(scooter_bounds.size, Vector3(2, 1, 2.8), "scooter visible envelope")
	for k in range(4):
		var panel := _find(ship, "Armour%d" % k) as MeshInstance3D
		if panel != null:
			_near(_bounds(ship, [panel]).size, Vector3(0.4, 3.2, 6), "armour envelope %d" % k)
		for side in ["L", "R"]:
			var drum := _find(ship, "Drum%s%d" % [side, k]) as MeshInstance3D
			if drum != null:
				_near(_bounds(ship, [drum]).size, Vector3(0.8, 1.5, 1.5), "drum envelope %s%d" % [side, k])
	for tag in ["Port", "Starboard"]:
		var magnet := _find(ship, "Magnet" + tag) as MeshInstance3D
		if magnet != null:
			_near(_bounds(ship, [magnet]).size, Vector3(2.8, 0.9, 2.8), "magnet envelope " + tag)
	for k in range(3):
		var cap := _find(ship, "Cap%d" % k) as MeshInstance3D
		if cap != null:
			_near(_bounds(ship, [cap]).size, Vector3(2.2, 0.8, 2.2), "cap envelope %d" % k)
	var shield := _find(ship, "CockpitShield") as MeshInstance3D
	if shield != null:
		_near(_bounds(ship, [shield]).size, Vector3(3, 2.2, 3), "cockpit shield envelope")
		_near(shield.position, Vector3(0, 5, 6.3), "cockpit stern hinge")
	var bow := _find(ship, "BowRam") as MeshInstance3D
	if bow != null:
		_near(_bounds(ship, [bow]).size, Vector3(9, 3.2, 0.35), "bow envelope")
	var admiral := _find(ship, "Admiral") as MeshInstance3D
	if admiral != null:
		_near(_bounds(ship, [admiral]).size, Vector3(1.2, 1, 1), "admiral and seat envelope")
	for tag in ["L", "R"]:
		var hatch := _find(ship, "Hatch" + tag) as MeshInstance3D
		if hatch != null:
			_near(_bounds(ship, [hatch]).size, Vector3(0.2, 1.8, 2.2), "2.2 m hatch turned onto ship's side " + tag)
	for pair in [["CranePivotPort", Vector3(-4.5, 7.5, -2)], ["CranePivotStarboard", Vector3(4.5, 7.5, 2)], ["EjectSocket", Vector3(0, 6.5, 4.8)], ["DroneSocketL", Vector3(-9, 0, 0)], ["DroneSocketR", Vector3(9, 0, 0)]]:
		var part := _find(ship, pair[0]) as Node3D
		if part != null:
			_near(part.global_position - ship.global_position, pair[1], "socket " + pair[0])
	for k in range(3):
		var socket := _find(ship, "CapSocket%d" % k) as Node3D
		if socket != null:
			_near(socket.global_position - ship.global_position, CAP_SPOTS[k], "cap socket %d" % k)
	var player := _animations(ship, ship_json, SHIP_CLIPS)
	var scooter_player := _animations(scooter, scooter_json, SCOOTER_CLIPS)
	# Missing nodes or clips are reported above; do not crash instead of printing FAIL.
	if failures.is_empty() and player != null and scooter_player != null:
		var rest := {}
		for node in ship.find_children("*", "Node3D", true, false):
			rest[node] = node.transform
		_sample(ship, player, "enter_furnace", 0.6, rest)
		for k in range(3):
			_near((_find(ship, "Cap%d" % k) as Node3D).position, Vector3(0, 0.25, 0), "cap lifted exactly 0.25 m")
		for tag in ["Port", "Starboard"]:
			_check((_find(ship, "Crane" + tag) as Node3D).scale.x < 0.002, "crane removed during Furnace")
		_check((_find(ship, "CraneMasts") as Node3D).scale.x < 0.002, "crane masts removed during Furnace")
		_check((_find(ship, "CableSpans") as Node3D).scale.x < 0.002, "static crane cables removed during Furnace")
		_check((_find(ship, "CableSpans") as Node3D).position.is_zero_approx() and (_find(ship, "CableSpans") as Node3D).rotation.is_zero_approx(), "static cable span only changes visibility")
		_sample(ship, player, "enter_scuttle", 0.8, rest)
		for k in range(4):
			_check((_find(ship, "Armour%d" % k) as Node3D).scale.x < 0.002, "four panels shed")
		_check(_rib_exposed(hull, -1) and _rib_exposed(hull, 1), "Scuttle exposes structural ribs instead of a solid wall")
		_sample(ship, player, "drone_deploy", 0.9, rest)
		_near((_find(ship, "HatchR") as Node3D).basis.y, Vector3.RIGHT, "starboard hatch opens about +Z hinge")
		_near((_find(ship, "HatchL") as Node3D).basis.y, Vector3.LEFT, "port hatch opens about +Z hinge")
		_sample(ship, player, "wall_stun", 3, rest)
		_check(_bounds(ship, [shield]).get_center().z > 6.3, "shield holds open aft of its stern hinge for 3 s")
		for clip in SHIP_CLIPS:
			_sample(ship, player, clip, float(SHIP_CLIPS[clip]) * 0.5, rest)
		var scooter_rest := {}
		for node in scooter.find_children("*", "Node3D", true, false):
			scooter_rest[node] = node.transform
		for clip in SCOOTER_CLIPS:
			_sample(scooter, scooter_player, clip, float(SCOOTER_CLIPS[clip]) * 0.5, scooter_rest)
	ship.free()
	scooter.free()
	_finish()


func _finish() -> void:
	print("dress_bri_assets_test: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
