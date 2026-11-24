extends SceneTree
# 2026-10-11 (PD-TARN fix round 3, docs/decisions.tsv 2026-10-11 w13-PD, Tarn 17): the Pod copper
# fold is vetoed, so Pod keeps a copper surface beside paint (the lap bar is the ultimate control
# and paint never tints it, ROSTER-LOOK section 6), and Tarn carries a documented 17-draw
# exception to the 16 cap (four articulated two-surface jaws). The shell is pinned to exactly
# SHELL_DRAWS surfaces and the registry exception must match it.
# 2026-10-10 (PD-TARN fix round 2, the 16-draw cap in docs/decisions.tsv w13-PD): the pull drum
# is symmetric and untextured, so it rides the Pod mesh and PullDrum becomes an empty at its
# axle; the registry exception (16 draws) is the shell budget the check reads.
# 2026-10-10 (PD-TARN fix round): each claw jaw is a paint body plus a class_accent tooth strip
# (P-UNITS PD-TARN "jaw-tooth edges are the only class_accent"; hero.png bone jaws).
# 2026-10-10 (PD-TARN): the shell is the Hoberman mecha (shell_tarn.py on shell_base.hoberman()):
# sockets move to the claw arms' gap brackets (ClawPivot, ClawTip), the low rear pull drum
# (PullExit) and the base's yokes (Control.Grip); the shell budget reads its registry exception
# and the copper slot replaces glass; the envelope check becomes Core inside 0.985, every mesh
# inside 1.25 and nothing past 1.0 below Y -0.6; the base's Pilot placeholder is an empty;
# the blades ride WeaponRing. The pilot gains one mesh node, Cap, rigid on head, so the skin
# check expects the Pilot and Cap meshes.
# 2026-11-23 (W46 E2-04): the claws hinge outboard at radius 1.04, 18 degrees below 3 and 9
# o'clock with no lean, so jaws and rams read beside the ball from the chase camera; ClawPivot
# and ClawTip move there and the envelope cap becomes the weapon reach cap, 1.35 (PILOT-CADENCE
# section 5.1).

const T := preload("res://tests/support/t.gd")
const PILOT := "res://assets/models/pilot_tarn_anim.glb"
const SHELL := "res://assets/models/world_one/shell_tarn.glb"
const CLIPS := {"drop_land": 2.1666667, "big_cheer": 2.8, "wince": 0.5, "slump": 1.5, "phew": 0.8, "brace": 0.6, "heave": 0.8}
const PARENTS := {
	"root": "", "pelvis": "root", "spine_01": "pelvis", "spine_02": "spine_01", "neck": "spine_02", "head": "neck",
	"snout": "head", "goggles": "head", "ear.R": "head", "ear.L": "head", "crest": "head", "jaw": "head",
	"shoulder.R": "spine_02", "shoulder.L": "spine_02", "upper_arm.R": "shoulder.R", "upper_arm.L": "shoulder.L",
	"lower_arm.R": "upper_arm.R", "lower_arm.L": "upper_arm.L", "hand.R": "lower_arm.R", "hand.L": "lower_arm.L",
	"curl.R": "hand.R", "curl.L": "hand.L", "tail.01": "pelvis", "tail.02": "tail.01", "tool.R": "hand.R",
}
const SOCKETS := {"Control.Grip.R": Vector3(.32, .05, -.4), "Control.Grip.L": Vector3(-.32, .05, -.4),
	"ClawPivot.R": Vector3(.98910, -.32138, 0), "ClawPivot.L": Vector3(-.98910, -.32138, 0),
	"ClawTip.R": Vector3(1.23637, -.40172, 0), "ClawTip.L": Vector3(-1.23637, -.40172, 0),
	"PullExit": Vector3(0, -.54, .552), "RendContact": Vector3(0, -.79, -.23)}
const SHELL_ID := "shell_tarn"
const SHELL_DRAWS := 17
const CORE_LIMIT := .985
const REACH := 1.35

var _t := T.new("pilot_tarn_asset_test")
var _done := false


func _load_asset(path: String, variable: String) -> Node:
	var scratch := OS.get_environment(variable)
	if not scratch.is_empty():
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(scratch, state)
		_t.eq("scratch load", error, OK)
		return document.generate_scene(state) if error == OK else Node3D.new()
	var packed := load(path) as PackedScene
	_t.check("loads " + path, packed != null, "Godot imports a PackedScene")
	return packed.instantiate() if packed != null else Node3D.new()


func _meshes(scene: Node) -> Array:
	var found := []
	var todo := [scene]
	while not todo.is_empty():
		var node: Node = todo.pop_back()
		todo.append_array(node.get_children())
		if node is MeshInstance3D and node.mesh != null:
			found.append(node)
	return found


func _budget(scene: Node, label: String, cap: Dictionary, allowed: Array) -> int:
	var tris := 0
	var verts := 0
	var draws := 0
	var slots := {}
	var wrong := []
	for mi: MeshInstance3D in _meshes(scene):
		for surface in mi.mesh.get_surface_count():
			draws += 1
			var arrays: Array = mi.mesh.surface_get_arrays(surface)
			verts += arrays[Mesh.ARRAY_VERTEX].size()
			var indices = arrays[Mesh.ARRAY_INDEX]
			tris += int((indices.size() if indices != null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3)
			var material := mi.mesh.surface_get_material(surface)
			var slot := material.resource_name if material != null else "<missing>"
			slots[slot] = true
			if not slot in allowed:
				wrong.append(slot)
	_t.check(label + " budget", tris > 0 and tris <= int(cap.tris) and verts <= int(cap.verts) and draws <= int(cap.draws),
		"%d triangles / %d vertices / %d surfaces; caps %d / %d / %d" % [tris, verts, draws, cap.tris, cap.verts, cap.draws])
	_t.check(label + " materials", slots.size() <= 5 and wrong.is_empty(), "slots %s; wrong %s" % [slots.keys(), wrong])
	print("TARN_BUDGET %s: %d T / %d V / %d surfaces" % [label, tris, verts, draws])
	return draws


func _rig(scene: Node) -> void:
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	var actual := {}
	var skeleton: Skeleton3D = skeletons[0] if skeletons.size() == 1 else null
	if skeleton != null:
		for index in skeleton.get_bone_count():
			var parent := skeleton.get_bone_parent(index)
			actual[skeleton.get_bone_name(index)] = skeleton.get_bone_name(parent) if parent >= 0 else ""
	_t.check("exact 25 bones", skeletons.size() == 1 and actual == PARENTS,
		"%d skeleton, %d bones; names and parents match pilot-v1: %s" % [skeletons.size(), actual.size(), actual == PARENTS])
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clips: Array = Array(player.get_animation_list()) if player != null else []
	clips.erase("RESET")
	var wanted := CLIPS.keys()
	# 2026-10-18: src/presentation/clips/tarn.json lists idle_loop only, so the GLB carries the seven
	# kept clips plus that loop (it loops, by its _loop name).
	wanted.append("idle_loop")
	clips.sort()
	wanted.sort()
	_t.check("exact seven clips plus idle_loop", clips == wanted, "got %s; expected %s" % [clips, wanted])
	if player == null or skeleton == null:
		return
	_t.check("rig scale", scene.scale.is_equal_approx(Vector3.ONE) and skeleton.scale.is_equal_approx(Vector3.ONE), "scale 1")
	var rigid_vertices := []
	for mi: MeshInstance3D in _meshes(scene):
		if mi.skin == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX].size():
				var bind: int = arrays[Mesh.ARRAY_BONES][vertex * 4]
				var bone := mi.skin.get_bind_bone(bind)
				if bone < 0:
					bone = skeleton.find_bone(mi.skin.get_bind_name(bind))
				if bone >= 0:
					rigid_vertices.append([bone, mi.skin.get_bind_pose(bind) * arrays[Mesh.ARRAY_VERTEX][vertex]])
	_t.check("sampleable skin", rigid_vertices.size() > 0, "%d rigid vertices sampled in bone space" % rigid_vertices.size())
	for clip in CLIPS:
		if not player.has_animation(clip):
			continue
		var animation := player.get_animation(clip)
		_t.near("duration " + clip, animation.length, CLIPS[clip], .001)
		_t.eq("one shot " + clip, animation.loop_mode, Animation.LOOP_NONE)
		player.play(clip)
		for time in [0.0, animation.length]:
			player.seek(time, true)
			player.advance(0)
			var error := 0.0
			for index in skeleton.get_bone_count():
				var got := skeleton.get_bone_pose(index)
				var rest := skeleton.get_bone_rest(index)
				error = maxf(error, got.origin.distance_to(rest.origin))
				for axis in 3:
					error = maxf(error, got.basis[axis].distance_to(rest.basis[axis]))
			_t.check("neutral " + clip + " at " + str(time), error < .0001, "bone-rest error %.7f" % error)
		# Imported playback samples the full clip, including between exported keys.
		var drift := 0.0
		var grip := 0.0
		var radius := 0.0
		var root_error := 0.0
		var pelvis := skeleton.find_bone("pelvis")
		var origin_bone := skeleton.find_bone("root")
		for half in range(int(round(animation.length * 60)) + 1):
			player.seek(float(half) / 60, true)
			player.advance(0)
			drift = maxf(drift, skeleton.get_bone_global_pose(pelvis).origin.distance_to(Vector3(0, -.3, 0)))
			if origin_bone >= 0:
				var got := skeleton.get_bone_pose(origin_bone)
				var rest := skeleton.get_bone_rest(origin_bone)
				root_error = maxf(root_error, got.origin.distance_to(rest.origin))
				for axis in 3:
					root_error = maxf(root_error, got.basis[axis].distance_to(rest.basis[axis]))
			var transforms := []
			for index in skeleton.get_bone_count():
				transforms.append(skeleton.get_bone_global_pose(index))
			for vertex in rigid_vertices:
				var point: Vector3 = transforms[vertex[0]] * vertex[1]
				radius = maxf(radius, point.length())
			var sides: Array = ["R", "L"] if clip == "brace" else ["L"] if clip == "heave" else ["R"] if clip == "phew" else []
			for side in sides:
				var hand := skeleton.find_bone("hand." + side)
				if hand >= 0:
					grip = maxf(grip, skeleton.get_bone_global_pose(hand).origin.distance_to(SOCKETS["Control.Grip." + side]))
		_t.check("anchored " + clip, drift < .0001 and grip < .004, "pelvis drift %.7f; grip error %.7f" % [drift, grip])
		_t.check("glass and root " + clip, radius < .98 and root_error < .0001, "half-frame vertex radius %.7f m; root motion/scale error %.7f" % [radius, root_error])
	player.stop()
	var skinned := 0
	var bad := 0
	for mi: MeshInstance3D in _meshes(scene):
		if mi.skin != null:
			skinned += 1
		for surface in mi.mesh.get_surface_count():
			var weights = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_WEIGHTS]
			if weights == null or weights.is_empty():
				bad += 1
				continue
			for i in range(0, weights.size(), 4):
				var ones := 0
				for j in 4:
					if absf(weights[i + j] - 1) < .00001:
						ones += 1
					elif absf(weights[i + j]) > .00001:
						bad += 1
				if ones != 1:
					bad += 1
	_t.check("one rigid skin", skinned == 2 and bad == 0, "%d skinned meshes (Pilot and Cap), %d invalid weights" % [skinned, bad])
	var cap := scene.find_child("Cap", true, false) as MeshInstance3D
	var off_head := -1
	if cap != null and cap.skin != null:
		off_head = 0
		for surface in cap.mesh.get_surface_count():
			var arrays: Array = cap.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX].size():
				var bind: int = arrays[Mesh.ARRAY_BONES][vertex * 4]
				var bone := cap.skin.get_bind_bone(bind)
				var bone_name: String = skeleton.get_bone_name(bone) if bone >= 0 else cap.skin.get_bind_name(bind)
				if bone_name != "head":
					off_head += 1
	_t.check("cap node", cap != null and cap.mesh.get_surface_count() == 1 and off_head == 0,
		"one Cap mesh rigid on head (%d vertices off head)" % off_head)


func _shell(scene: Node) -> void:
	var core := scene.find_child("Core", true, false) as MeshInstance3D
	var pod := scene.find_child("Pod", true, false) as Node3D
	var dome := scene.find_child("Dome", true, false) as Node3D
	_t.check("Core Pod Dome Gyro", core != null and pod != null and dome != null and core.get_parent() == pod.get_parent()
		and dome.get_parent() == pod and dome.transform.is_equal_approx(Transform3D.IDENTITY)
		and pod.get_node_or_null("Gyro") != null, "sphere-centred rolling Core and upright Pod > Dome/Gyro")
	_t.check("separate pilot", not (scene.find_child("Pilot", true, false) is MeshInstance3D) and scene.find_children("*", "Skeleton3D", true, false).is_empty(), "Pilot is the base's empty placeholder; no shell skeleton")
	if pod == null or core == null:
		return
	for name in SOCKETS:
		# Godot replaces periods in glTF node names; bone names retain their periods.
		var node := pod.get_node_or_null(NodePath(name.replace(".", "_"))) as Node3D
		_t.check("socket " + name, node != null and node.position.distance_to(SOCKETS[name]) < .0001, "named non-bone endpoint at " + str(SOCKETS[name]))
	for side in ["R", "L"]:
		for kind in ["Upper", "Lower"]:
			var jaw := pod.get_node_or_null("Claw" + kind + "_" + side) as MeshInstance3D
			var slots := []
			if jaw != null:
				for s in jaw.mesh.get_surface_count():
					slots.append(jaw.mesh.surface_get_material(s).resource_name)
				slots.sort()
			_t.check("claw " + kind + side, slots == ["class_accent", "paint"], "independent jaw: paint body, class_accent tooth strip; got %s" % [slots])
		var blade := pod.get_node_or_null("WeaponRing/Blade_" + side) as MeshInstance3D
		_t.check("blade " + side, blade != null and blade.mesh.get_surface_count() == 1, "single-material blade under WeaponRing")
	var pod_slots := []
	if pod is MeshInstance3D:
		for s in (pod as MeshInstance3D).mesh.get_surface_count():
			pod_slots.append((pod as MeshInstance3D).mesh.surface_get_material(s).resource_name)
		pod_slots.sort()
	_t.check("pod copper", pod_slots == ["copper", "paint"],
		"Pod keeps its copper surface beside paint, so paint never tints the lap bar (ROSTER-LOOK section 6); got %s" % [pod_slots])
	var drum := pod.get_node_or_null("PullDrum") as Node3D
	_t.check("pull drum", drum != null and not (drum is MeshInstance3D) and drum.position.y < -.4,
		"PullDrum is an empty at the low rear axle; the drum rides the Pod mesh")
	var far := 0.0
	var core_far := 0.0
	var low := 0
	for mi: MeshInstance3D in _meshes(scene):
		var transform: Transform3D = scene.global_transform.affine_inverse() * mi.global_transform
		for surface in mi.mesh.get_surface_count():
			for vertex in mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = transform * vertex
				far = maxf(far, point.length())
				if mi == core:
					core_far = maxf(core_far, point.length())
				if point.y < -.6 and point.length() > 1.0:
					low += 1
	_t.check("resting envelope", core_far <= CORE_LIMIT + .0001 and far <= REACH and low == 0,
		"Core %.4f m (limit %.3f); every mesh %.4f m (cap %.2f); %d vertices past 1.0 below Y -0.6" % [core_far, CORE_LIMIT, far, REACH, low])


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var budgets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_budgets.json"))
	var pilot := _load_asset(PILOT, "SCRAPKEEP_TEST_RIG")
	var shell := _load_asset(SHELL, "SCRAPKEEP_TEST_SHELL")
	root.add_child(pilot)
	root.add_child(shell)
	_budget(pilot, "pilot", budgets.classes.pilot, ["pilot", "rubber", "bare_metal"])
	var shell_cap: Dictionary = budgets.classes.shell.duplicate()
	var fragment = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registry.d/shell_tarn.json"))
	for row in fragment.assets:
		if row.get("id", "") == SHELL_ID:
			shell_cap.merge(row.get("exception", {}), true)
	var shell_draws := _budget(shell, "shell", shell_cap, ["paint", "copper", "bare_metal", "rubber", "class_accent"])
	_t.check("shell draws pinned", shell_draws == SHELL_DRAWS and int(shell_cap.draws) == SHELL_DRAWS,
		"%d surfaces, registry exception %d; both must be %d (Tarn 17, 2026-10-11 w13-PD)" % [shell_draws, int(shell_cap.draws), SHELL_DRAWS])
	_rig(pilot)
	_shell(shell)
	pilot.free()
	shell.free()
	quit(_t.verdict())
	return true
