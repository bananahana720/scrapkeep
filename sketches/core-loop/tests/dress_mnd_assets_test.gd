extends SceneTree

const FOLDER := "res://assets/models/bosses/"
const BASE_NODES := ["MindRoot", "CrownFrame", "Mantle0", "Mantle1", "Mantle2", "Mantle3", "Mantle4", "Mantle5", "SupportL", "SupportR", "AxisSpine", "SeatTether", "CombatSeat", "KitMount"]
const KIT_NODES := ["MindKitRoot", "CombatSeat", "KitMount", "LensRoot", "LensSeat0", "LensSeat1", "LensSeat2", "WeakPoint", "MainLens", "OpenLens", "Shutter0", "Shutter1", "Shutter2", "Shutter3", "Shutter4", "Shutter5", "EmitterL", "EmitterR", "EmitterSocketL", "EmitterSocketR", "RushCollar", "PulseLip", "BracePlate", "BraceSocket", "HandSpawnReferenceL", "HandSpawnReferenceR"]
const BASE_CLIPS := {"phase_break": 1.0, "phase_break_2": 1.0, "phase_break_3": 1.0, "final_quiet": 2.0}
const KIT_CLIPS := {"attention": 4.0, "lane_warn": 1.4, "split_lane_warn": 1.6, "rush_warn": 1.5, "plate_warn": 1.8, "family_strike": 0.2, "recovery": 0.4, "pulse_warn": 2.0, "pulse": 0.3, "choir_change": 0.6, "choir_change_1_2": 0.6, "choir_change_2_0": 0.6, "stagger_open": 0.5, "hand_send": 0.6, "final_quiet": 2.0}
const MATERIALS := ["ancient_enamel", "dark_joint", "glass", "signal_surface"]
# Raised for the 2026-10-18 model polish (tools/blender/POLISH.md); draws unchanged.
const SPEC_CAPS := {"warden_base": Vector3i(20000, 38400, 32), "warden_kit": Vector3i(6000, 11200, 18)}

var failures := 0
var checks := 0
var fixture_dir := ""


func check(label: String, ok: bool) -> void:
	checks += 1
	print("[MND] %s -> %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mnd-fixture-dir="):
			fixture_dir = arg.trim_prefix("--mnd-fixture-dir=")
	var budgets = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_budgets.json"))
	for row in [["boss_mind_base.glb", BASE_NODES, BASE_CLIPS, "warden_base"], ["boss_mind_kit.glb", KIT_NODES, KIT_CLIPS, "warden_kit"]]:
		var cap: Dictionary = budgets.classes[row[3]]
		check(row[3] + " allocation matches BUILD-SPEC", Vector3i(cap.tris, cap.verts, cap.draws) == SPEC_CAPS[row[3]])
		inspect(row[0], row[1], row[2], budgets.classes[row[3]])
	print("MND_CHECKS %d failures=%d" % [checks, failures])
	print("dress_mnd_assets_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func named(scene: Node, part: String) -> Node3D:
	if scene.name == part:
		return scene as Node3D
	return scene.find_child(part, true, false) as Node3D


func raw_glb(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	check(path.get_file() + " GLB header", bytes.size() >= 28 and bytes.decode_u32(0) == 0x46546c67)
	if bytes.size() < 28:
		return {}
	check(path.get_file() + " complete GLB length", bytes.decode_u32(8) == bytes.size())
	var length := bytes.decode_u32(12)
	var value = JSON.parse_string(bytes.slice(20, 20 + length).get_string_from_utf8())
	check(path.get_file() + " embedded glTF JSON", value is Dictionary)
	return value if value is Dictionary else {}


func inspect(file: String, required_nodes: Array, clips: Dictionary, cap: Dictionary) -> void:
	var path := FOLDER + file if fixture_dir.is_empty() else fixture_dir.path_join(file)
	check(file + " exists", FileAccess.file_exists(path))
	if not FileAccess.file_exists(path):
		return
	var doc := raw_glb(path)
	if doc.is_empty():
		return
	var tris := 0
	var verts := 0
	var draws := 0
	for mesh in doc.meshes:
		for primitive in mesh.primitives:
			check(file + " indexed triangles", primitive.get("mode", 4) == 4 and primitive.has("indices"))
			tris += int(doc.accessors[primitive.indices].count) / 3
			verts += int(doc.accessors[primitive.attributes.POSITION].count)
			draws += 1
	print("MND_BUDGET %s tris=%d/%d verts=%d/%d draws=%d/%d" % [file, tris, cap.tris, verts, cap.verts, draws, cap.draws])
	check(file + " exported allocation", tris > 0 and tris <= cap.tris and verts <= cap.verts and draws <= cap.draws)
	for material in doc.materials:
		check(file + " material family " + material.name, material.name in MATERIALS)
		if material.name == "ancient_enamel":
			check(file + " enamel does not emit", not material.has("emissiveFactor") or material.emissiveFactor == [0, 0, 0])
		if material.name == "glass":
			check(file + " neutral glass is clear", material.get("alphaMode", "OPAQUE") == "BLEND" and float(material.pbrMetallicRoughness.baseColorFactor[3]) < 1.0)
	check(file + " no skin rig", doc.get("skins", []).is_empty())
	check(file + " embedded wear atlas", doc.get("images", []).size() == 1 and doc.images[0].has("bufferView"))
	var scene: Node3D
	if fixture_dir.is_empty():
		var packed = load(path)
		check(file + " Godot imported PackedScene", packed is PackedScene)
		if not packed is PackedScene:
			return
		scene = packed.instantiate()
	else:
		var importer := GLTFDocument.new()
		var state := GLTFState.new()
		var error := importer.append_from_file(path, state)
		check(file + " scratch GLB import", error == OK)
		if error != OK:
			return
		scene = importer.generate_scene(state)
	check(file + " generates scene", scene != null)
	if scene == null:
		return
	root.add_child(scene)
	check(file + " ground root identity", scene.transform.is_equal_approx(Transform3D.IDENTITY))
	check(file + " has no collision or target bodies", scene.find_children("*", "CollisionObject3D", true, false).is_empty() and scene.find_children("*", "CollisionShape3D", true, false).is_empty())
	for part in required_nodes:
		check("required node " + part, named(scene, part) != null)
	var import_counts := Vector3i.ZERO
	var bounds := AABB()
	var first := true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var transform := scene.global_transform.affine_inverse() * instance.global_transform
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			import_counts += Vector3i(indices.size() / 3, positions.size(), 1)
			var finite := true
			for point in positions:
				finite = finite and point.is_finite()
				var world: Vector3 = transform * point
				if first:
					bounds = AABB(world, Vector3.ZERO)
					first = false
				else:
					bounds = bounds.expand(world)
			for i in range(0, indices.size(), 3):
				finite = finite and (positions[indices[i + 1]] - positions[indices[i]]).cross(positions[indices[i + 2]] - positions[indices[i]]).length() > 0.0000001
			check(file + " finite nondegenerate " + String(instance.name) + " surface " + str(surface), finite)
			var material := instance.mesh.surface_get_material(surface) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				check(file + " atlas <=2048", material.albedo_texture.get_width() <= 2048 and material.albedo_texture.get_height() <= 2048)
	print("MND_IMPORTED %s tris=%d verts=%d surfaces=%d bounds=%s" % [file, import_counts.x, import_counts.y, import_counts.z, bounds])
	check(file + " Godot allocation", import_counts.x == tris and import_counts.y <= cap.verts and import_counts.z == draws)
	var animator := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(file + " has AnimationPlayer", animator != null)
	if animator != null:
		for clip in clips:
			check("required clip " + clip, animator.has_animation(clip))
			if not animator.has_animation(clip):
				continue
			var animation := animator.get_animation(clip)
			check(file + " " + clip + " duration", absf(animation.length - float(clips[clip])) < 0.035)
			var rigid_only := true
			var moves := false
			for track in animation.get_track_count():
				var target: NodePath = animation.track_get_path(track)
				var target_node := animator.get_node_or_null(animator.root_node).get_node_or_null(NodePath(String(target).split(":")[0]))
				rigid_only = rigid_only and target_node != scene and target_node != named(scene, "CombatSeat") and target_node != named(scene, "KitMount")
				rigid_only = rigid_only and target_node != named(scene, "MindRoot") and target_node != named(scene, "MindKitRoot")
				rigid_only = rigid_only and animation.track_get_type(track) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
				for key in range(1, animation.track_get_key_count(track)):
					moves = moves or animation.track_get_key_value(track, key) != animation.track_get_key_value(track, 0)
			check(file + " " + clip + " visual rigid tracks without root motion", rigid_only and moves)
		if required_nodes == BASE_NODES:
			check(file + " final boss envelope 32x30x12 metres", bounds.size.distance_to(Vector3(32,30,12)) < 0.002)
			for pair in [["phase_break", "Mantle0"], ["phase_break_2", "Mantle1"], ["phase_break_3", "Mantle2"]]:
				if named(scene, pair[1]) != null and animator.has_animation(pair[0]):
					seek(animator, pair[0], 1.0)
					check(pair[0] + " sheds only its assigned mantle", named(scene, pair[1]).scale.x < 0.03)
		else:
			check_kit(scene, animator)
	scene.free()


func seek(animator: AnimationPlayer, clip: String, fraction: float) -> void:
	animator.play(clip)
	animator.seek(animator.get_animation(clip).length * fraction, true)
	animator.advance(0.0)


func check_kit(scene: Node3D, animator: AnimationPlayer) -> void:
	if named(scene, "LensRoot") != null:
		check("rest lens matches selected choir seat", scene.to_local(named(scene, "LensRoot").global_position).distance_to(Vector3(1.6,9.2,0)) < 0.0001)
	for i in range(3):
		var seat := named(scene, "LensSeat%d" % i)
		if seat == null:
			continue
		var angle := TAU * i / 3.0
		var expected := Vector3(1.6, 0, 0).rotated(Vector3.UP, angle) + Vector3(0, 9.2, 0)
		check("choir seat %d matches family_point_at" % i, scene.to_local(seat.global_position).distance_to(expected) < 0.0001)
	for pair in [["EmitterSocketL", Vector3(-2,3,-1)], ["EmitterSocketR", Vector3(2,3,-1)], ["BraceSocket", Vector3(0,3,0)], ["RushSocket", Vector3(0,6,0)], ["PulseSocket", Vector3(0,2.2,0)]]:
		var socket := named(scene, pair[0])
		if socket != null:
			check("socket " + pair[0] + " in ground metres", scene.to_local(socket.global_position).distance_to(pair[1]) < 0.0001)
	var pulse := named(scene, "PulseLip")
	var rush := named(scene, "RushCollar")
	if pulse != null and rush != null and animator.has_animation("rush_warn") and animator.has_animation("pulse_warn"):
		var pulse_rest := pulse.position
		seek(animator, "rush_warn", 1.0)
		check("rush compresses collar while pulse stays independent", rush.position.y < -0.4 and pulse.position.is_equal_approx(pulse_rest))
		var rush_held := rush.position
		# Independent players prove both visual channels can run at once. A single
		# AnimationPlayer switching clips restores its previous animated properties.
		var pulse_player := AnimationPlayer.new()
		scene.add_child(pulse_player)
		var library := AnimationLibrary.new()
		var pulse_animation := animator.get_animation("pulse_warn").duplicate() as Animation
		var imported_rest_only := true
		# Godot fills absent glTF channels with immutable rest tracks. A concurrent
		# playback layer filters those tracks, as an AnimationTree filter would.
		for track in range(pulse_animation.get_track_count() - 1, -1, -1):
			if not String(pulse_animation.track_get_path(track)).ends_with("/PulseLip"):
				for key in range(1, pulse_animation.track_get_key_count(track)):
					imported_rest_only = imported_rest_only and pulse_animation.track_get_key_value(track, key) == pulse_animation.track_get_key_value(track, 0)
				pulse_animation.remove_track(track)
		check("filtered imported pulse channels are immutable rest only", imported_rest_only)
		library.add_animation("pulse_warn", pulse_animation)
		pulse_player.add_animation_library("", library)
		seek(pulse_player, "pulse_warn", 1.0)
		print("MND_OVERLAP pulse=%s rush=%s held=%s" % [pulse.position, rush.position, rush_held])
		check("pulse rises while held family cue survives", pulse.position.y > 0.4 and rush.position.is_equal_approx(rush_held))
		pulse_player.free()
	for pair in [["choir_change", 1], ["choir_change_1_2", 2], ["choir_change_2_0", 0]]:
		if animator.has_animation(pair[0]) and named(scene, "LensRoot") != null and named(scene, "LensSeat%d" % pair[1]) != null:
			seek(animator, pair[0], 1.0)
			check(pair[0] + " ends on actual choir seat", named(scene, "LensRoot").global_position.distance_to(named(scene, "LensSeat%d" % pair[1]).global_position) < 0.0001)
	if animator.has_animation("split_lane_warn") and named(scene, "EmitterSocketR") != null:
		seek(animator, "split_lane_warn", 1.0)
		check("split example uses seeded angle range", absf(absf(named(scene, "EmitterSocketR").rotation.y) - 0.525) < 0.001)
	if animator.has_animation("plate_warn") and named(scene, "BracePlate") != null:
		seek(animator, "plate_warn", 0.0)
		check("plate begins folded", absf(named(scene, "BracePlate").rotation.x) > 1.5)
		seek(animator, "plate_warn", 1.0)
		check("plate ends unfurled", absf(named(scene, "BracePlate").rotation.x) < 0.001)
	if animator.has_animation("stagger_open") and named(scene, "Shutter0") != null:
		seek(animator, "stagger_open", 1.0)
		check("stagger opens six radial shutters", absf(named(scene, "Shutter0").rotation.x) > 1.2)
