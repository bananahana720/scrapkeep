extends SceneTree

const PILOT := "res://assets/models/pilot_cannon_anim.glb"
const SHELL := "res://assets/models/world_one/shell_cannon.glb"
const BUDGETS := "res://tools/asset_budgets.json"
const CLIPS := {"drop_land": 2.1666667, "big_cheer": 2.8, "wince": 0.5, "slump": 1.5, "phew": 0.8, "brace": 0.6, "heave": 0.8}
const PARENTS := {
	"root": "", "pelvis": "root", "spine_01": "pelvis", "spine_02": "spine_01",
	"neck": "spine_02", "head": "neck", "snout": "head", "goggles": "head",
	"ear.R": "head", "ear.L": "head", "crest": "head", "jaw": "head",
	"shoulder.R": "spine_02", "shoulder.L": "spine_02",
	"upper_arm.R": "shoulder.R", "upper_arm.L": "shoulder.L",
	"lower_arm.R": "upper_arm.R", "lower_arm.L": "upper_arm.L",
	"hand.R": "lower_arm.R", "hand.L": "lower_arm.L",
	"curl.R": "hand.R", "curl.L": "hand.L",
	"tail.01": "pelvis", "tail.02": "tail.01", "tool.R": "hand.R",
}
const SOCKETS := {
	"LaneMuzzle": Vector3(0, -.29, -.85), "BarrelPivot": Vector3(0, -.29, -.44),
	"SplitExit.R": Vector3(.32, -.30, .71), "SplitExit.L": Vector3(-.32, -.30, .71),
	"SectorPivot": Vector3(0, -.56, -.60), "RushContact": Vector3(0, -.81, 0),
	"Grip.R": Vector3(.32, .05, -.40), "Grip.L": Vector3(-.32, .05, -.40),
}
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func glb_json(path: String) -> Dictionary:
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() < 20 or data.decode_u32(0) != 0x46546c67:
		check("GLB header", false, path)
		return {}
	var parsed = JSON.parse_string(data.slice(20, 20 + data.decode_u32(12)).get_string_from_utf8())
	check("GLB JSON", parsed is Dictionary, path)
	return parsed if parsed is Dictionary else {}


func load_pilot(path: String) -> Node3D:
	if path == PILOT:
		var packed := load(path) as PackedScene
		return packed.instantiate() as Node3D if packed != null else null
	# Negative controls load a damaged GLB outside production assets.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	check("fixture loads", error == OK, path)
	return document.generate_scene(state) if error == OK else null


func meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false)


func counts(node: Node) -> Dictionary:
	var result := {"tris": 0, "verts": 0, "draws": 0}
	for mi: MeshInstance3D in meshes(node):
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			result.tris += (indices.size() if indices != null else vertices.size()) / 3
			result.verts += vertices.size()
			result.draws += 1
	return result


func to_root(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != ancestor and current != null:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func check_budget(label: String, node: Node, cap: Dictionary) -> void:
	var actual := counts(node)
	for field in ["tris", "verts", "draws"]:
		check(label + " " + field, actual[field] <= cap[field], "%d <= %d" % [actual[field], cap[field]])
	print("PCN_BUDGET %s: %d triangles, %d vertices, %d draws" % [label, actual.tris, actual.verts, actual.draws])


func check_rig(pilot: Node3D, raw: Dictionary) -> void:
	var skeletons := pilot.find_children("*", "Skeleton3D", true, false)
	check("one skeleton", skeletons.size() == 1)
	if skeletons.size() != 1:
		return
	var skeleton := skeletons[0] as Skeleton3D
	var names := []
	for i in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(i))
	var missing := PARENTS.keys().filter(func(name): return not name in names)
	var extra := names.filter(func(name): return not PARENTS.has(name))
	check("exact 25 bones", names.size() == 25 and missing.is_empty() and extra.is_empty(), "count %d missing %s extra %s" % [names.size(), missing, extra])
	for name in PARENTS:
		var index := skeleton.find_bone(name)
		if index < 0:
			continue
		var parent := skeleton.get_bone_parent(index)
		var parent_name := skeleton.get_bone_name(parent) if parent >= 0 else ""
		check("parent " + name, parent_name == PARENTS[name], parent_name)
	check("one exported skin", raw.get("skins", []).size() == 1)
	if raw.get("skins", []).size() == 1:
		check("25 exported joints", raw.skins[0].joints.size() == 25)
	var players := pilot.find_children("*", "AnimationPlayer", true, false)
	check("one animation player", players.size() == 1)
	if players.size() != 1:
		return
	var player := players[0] as AnimationPlayer
	var clips := Array(player.get_animation_list()).filter(func(name): return name != "RESET")
	var lost := CLIPS.keys().filter(func(name): return not name in clips)
	var unexpected := clips.filter(func(name): return not CLIPS.has(name))
	check("exact seven clips", clips.size() == 7 and lost.is_empty() and unexpected.is_empty(), "count %d missing %s extra %s" % [clips.size(), lost, unexpected])
	var raw_names := []
	for animation in raw.get("animations", []):
		raw_names.append(animation.get("name", ""))
	check("seven exported clips", raw_names.size() == 7 and CLIPS.keys().all(func(name): return name in raw_names))
	var rigid := true
	var skins := {}
	for mi: MeshInstance3D in meshes(pilot):
		check("skinned " + str(mi.name), mi.skin != null)
		if mi.skin == null:
			continue
		skins[mi.skin.get_instance_id()] = true
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var stride := weights.size() / vertices.size()
			for v in vertices.size():
				var nonzero := 0
				var total := 0.0
				for k in stride:
					var weight := weights[v * stride + k]
					nonzero += int(weight > .00001)
					total += weight
				rigid = rigid and nonzero == 1 and absf(total - 1) < .00001
	check("one imported skin", skins.size() == 1)
	check("one rigid weight per vertex", rigid)
	check("pilot root identity", pilot.transform.is_equal_approx(Transform3D.IDENTITY))
	# Godot retains the glTF axis conversion in the root bone's neutral pose.
	var neutral := []
	player.play("drop_land")
	player.seek(0, true)
	player.advance(0)
	for index in skeleton.get_bone_count():
		neutral.append([skeleton.get_bone_pose_position(index), skeleton.get_bone_pose_rotation(index)])
	var root_index := skeleton.find_bone("root")
	var root_pose := skeleton.get_bone_global_pose(root_index) if root_index >= 0 else Transform3D.IDENTITY
	player.stop()
	for clip in CLIPS:
		if not clip in clips:
			continue
		var animation := player.get_animation(clip)
		check("duration " + clip, absf(animation.length - CLIPS[clip]) < .001, "%.6f seconds" % animation.length)
		player.play(clip)
		var scale_error := 0.0
		var pelvis_drift := 0.0
		var root_drift := 0.0
		var grip_error := 0.0
		var neutral_error := 0.0
		for half in int(round(animation.length * 60)) + 1:
			var seconds := half / 60.0
			player.seek(seconds, true)
			player.advance(0)
			for index in skeleton.get_bone_count():
				scale_error = maxf(scale_error, (skeleton.get_bone_pose_scale(index) - Vector3.ONE).length())
				if half == 0 or half == int(round(animation.length * 60)):
					neutral_error = maxf(neutral_error, (skeleton.get_bone_pose_position(index) - neutral[index][0]).length())
					var actual := Basis(skeleton.get_bone_pose_rotation(index))
					var expected := Basis(neutral[index][1])
					neutral_error = maxf(neutral_error, (actual.x - expected.x).length())
					neutral_error = maxf(neutral_error, (actual.y - expected.y).length())
					neutral_error = maxf(neutral_error, (actual.z - expected.z).length())
			var pelvis := skeleton.find_bone("pelvis")
			if root_index >= 0:
				var current_root := skeleton.get_bone_global_pose(root_index)
				root_drift = maxf(root_drift, (current_root.origin - root_pose.origin).length())
				root_drift = maxf(root_drift, (current_root.basis.x - root_pose.basis.x).length())
				root_drift = maxf(root_drift, (current_root.basis.y - root_pose.basis.y).length())
				root_drift = maxf(root_drift, (current_root.basis.z - root_pose.basis.z).length())
			if pelvis >= 0:
				pelvis_drift = maxf(pelvis_drift, (skeleton.get_bone_global_pose(pelvis).origin - Vector3(0, -.30, 0)).length())
			for side in ["R", "L"]:
				if clip in ["brace", "drop_land"] or (clip == "phew" and side == "R") or (clip == "heave" and side == "L"):
					var hand := skeleton.find_bone("hand." + side)
					if hand >= 0:
						grip_error = maxf(grip_error, (skeleton.get_bone_global_pose(hand).origin - SOCKETS["Grip." + side]).length())
		check("rigid scales " + clip, scale_error < .00001, "error %.8f" % scale_error)
		check("no root motion " + clip, pelvis_drift < .00001, "pelvis drift %.8f" % pelvis_drift)
		check("fixed root transform " + clip, root_drift < .00001, "error %.8f" % root_drift)
		check("neutral endpoints " + clip, neutral_error < .00001, "error %.8f" % neutral_error)
		check("fixed grips " + clip, grip_error < .0015, "error %.8f, import tolerance .0015 m" % grip_error)
		player.stop()


func check_shell(shell: Node3D) -> void:
	var core := shell.find_child("Core", true, false) as MeshInstance3D
	var pod := shell.find_child("Pod", true, false) as Node3D
	var dome := shell.find_child("Dome", true, false) as Node3D
	check("Core Pod Dome Gyro", core != null and pod != null and dome != null and shell.find_child("Gyro", true, false) != null)
	if core == null or pod == null or dome == null:
		return
	check("Core rolling sibling", core.get_parent() == pod.get_parent())
	check("Dome identity under Pod", dome.get_parent() == pod and dome.transform.is_equal_approx(Transform3D.IDENTITY))
	check("no duplicate pilot", shell.find_child("Pilot", true, false) == null)
	var radius := 0.0
	var glass_error := 0.0
	var materials := {}
	for mi: MeshInstance3D in meshes(shell):
		var transform := to_root(mi, shell)
		for surface in mi.mesh.get_surface_count():
			materials[mi.mesh.surface_get_material(surface).resource_name] = true
			for v in mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var distance: float = (transform * v).length()
				radius = maxf(radius, distance)
				if mi == core:
					glass_error = maxf(glass_error, absf(distance - .98))
	check("resting sphere bound", radius <= .985001, "radius %.6f <= .985" % radius)
	check("0.98 glass sphere", glass_error < .0001, "error %.8f, imported vertex tolerance .0001 m" % glass_error)
	check("five shell material slots", materials.size() <= 5 and materials.keys().all(func(name): return name in ["paint", "ancient_enamel", "rubber", "ancient_light", "glass"]), str(materials.keys()))
	for name in SOCKETS:
		var socket := shell.find_child(name.replace(".", "_"), true, false) as Node3D
		check("socket " + name, socket != null)
		if socket != null:
			var transform := to_root(socket, shell)
			check("socket position " + name, (transform.origin - SOCKETS[name]).length() < .00001)
			var direction := Vector3.DOWN if name == "RushContact" else Vector3.FORWARD
			if name.begins_with("SplitExit"):
				direction = Vector3(.22 if name.ends_with("R") else -.22, 0, 1).normalized()
			check("socket direction " + name, (transform.basis * Vector3.FORWARD - direction).length() < .00001)
	for name in ["MainBarrel", "SplitPorts", "SectorShutter"]:
		var hardware := shell.find_child(name, true, false)
		check("kit " + name, hardware != null and hardware.get_parent() == pod)


func _run() -> void:
	var path := OS.get_environment("SCRAPKEEP_PCN_TEST_RIG")
	if path == "":
		path = PILOT
	var pilot := load_pilot(path)
	var packed := load(SHELL) as PackedScene
	var shell := packed.instantiate() as Node3D if packed != null else null
	check("both assets load", pilot != null and shell != null)
	if pilot != null and shell != null:
		root.add_child(pilot)
		root.add_child(shell)
		var budgets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS))
		check_budget("pilot", pilot, budgets.classes.pilot)
		check_budget("shell", shell, budgets.classes.shell)
		check_rig(pilot, glb_json(path))
		check_shell(shell)
		pilot.free()
		shell.free()
	print("pilot_cannon_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
