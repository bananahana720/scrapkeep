extends SceneTree
# 2026-10-10 (PD-TALLY): the shell is now the Hoberman mecha (ROSTER-LOOK section 0, P-UNITS
# PD-TALLY). Re-pinned only the shell half: slots trade glass for copper and the draw cap is the
# registry exception (13); the glass-radius check becomes the lattice check (Core 0.95 to
# 0.985 m) with machinery inside rule 6's 1.25 m; Flywheel.R/L keep 0.34 x 0.07 m and gain the
# four window indices in vertex alpha; the sockets move with the mecha (ReaderExit to the
# WeaponRing magazine, the card bays beside the right yoke, the drums to 3 and 9 o'clock over
# the band, StampContact to the bottom), Grip.R/L become Control.Grip.R/L and the CardTab,
# LapBar, Pedal and Trigger controls are pinned; the reader slot is the only class_accent.
# The pilot half is unchanged.
# 2026-10-11 (PD-TALLY fix round): the draw cap returns to the shell class's 10 (the gate
# refused the 13-draw exception; now the registry's 11 for DrumBrackets). Both drums now share one mesh, Flywheel.R, spinning on their
# common X axis (span 2 x 1.033 + 0.07 m); Flywheel.L is an empty at the left drum's centre.
# 2026-11-23 (wave 46 unit E2-05): each drum's flanges are brass at alpha 0 with an index notch and
# a charcoal index slot at alpha 0 (FLYWHEEL_MASKED), and DrumBrackets gains an index shoe per side
# (BRACKET_VERTICES 136 to 232). Window alphas are unchanged; alpha 0 is the paint take mask.

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
	"ReaderExit": Vector3(0, 0, -1.212),
	"CardBay.0": Vector3(0.52, -0.262, -0.42),
	"CardBay.1": Vector3(0.52, -0.262, -0.30),
	"CardBay.2": Vector3(0.52, -0.262, -0.18),
	"FlywheelAxis.R": Vector3(1.033, 0.23, 0),
	"FlywheelAxis.L": Vector3(-1.033, 0.23, 0),
	"ReturnExit": Vector3(0, -0.47, 0.27),
	"StampContact": Vector3(0, -0.985, 0),
	"LedgerMount": Vector3(-0.255, -0.20, -0.045),
	"Control.Grip.R": Vector3(0.32, 0.05, -0.40),
	"Control.Grip.L": Vector3(-0.32, 0.05, -0.40),
	"Control.Trigger": Vector3(0.32, 0.09, -0.43),
	"Control.CardTab.0": Vector3(0.52, -0.27, -0.42),
	"Control.CardTab.1": Vector3(0.52, -0.27, -0.30),
	"Control.CardTab.2": Vector3(0.52, -0.27, -0.18),
	"Control.LapBar": Vector3(0, -0.33, -0.05),
	"Control.Pedal.L": Vector3(-0.13, -0.62, -0.45),
	"Control.Pedal.R": Vector3(0.13, -0.62, -0.45),
}
# Window k of a drum face carries vertex alpha WINDOW_ALPHA[k] (shell_tally.py header).
const WINDOW_ALPHA := [0.2, 0.4, 0.6, 0.8]
const BRACKET_VERTICES := 232
# Flywheel.R's paint-proof vertices: both drums' brass flanges (352) and index slots (48).
const FLYWHEEL_MASKED := 400
const CORE_LIMIT := 0.985
const REACH := 1.25

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
	var expected_clips := preload("res://tests/support/pilot_clip_trigger.gd").required_clips(true)
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
		_check("loop suffix " + name, (animation.loop_mode != Animation.LOOP_NONE) == String(name).ends_with("_loop"))
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
	_budget("pilot", pilot, Vector3i(12000, 8100, 5), ["pilot", "rubber", "bare_metal"])


func _shell(shell: Node, document: Dictionary) -> void:
	# The registry exception sets the draws (DrumBrackets, its own mesh so the carrier bank tilts it); the
	# shell class cap is 10 and the Hoberman pilot mecha cap 16 (docs/decisions.tsv w13-PD).
	var draws := 10
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registry.json"))
	for entry in registry.get("assets", []):
		if entry is Dictionary and entry.get("id", "") == "shell_tally":
			draws = int(entry.get("exception", {}).get("draws", draws))
	_check("registry draw exception", draws == 11 and draws <= 16, "shell_tally exception %d draws, cap 16" % draws)
	_budget("shell", shell, Vector3i(11000, 11600, draws), ["paint", "rubber", "class_accent", "copper"])
	# The brackets paint on the paint surface in charcoal, as the Pod's folded rubber did; a rubber slot
	# here would be a second draw and a different material from the base.
	var brackets := shell.find_child("DrumBrackets", true, false) as MeshInstance3D
	# Charcoal is tools/blender common.py "charcoal" 242a28 in linear vertex colour (0.018, 0.023, 0.021); every vertex of the
	# one paint surface must carry it within 0.01 a channel, so a white bracket on paint fails.
	var charcoal_ok := false
	if brackets != null and brackets.mesh.get_surface_count() == 1:
		var bracket_cols = brackets.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		charcoal_ok = bracket_cols != null and bracket_cols.size() > 0
		if charcoal_ok:
			for c in bracket_cols:
				if absf(c.r - 0.018) > 0.01 or absf(c.g - 0.023) > 0.01 or absf(c.b - 0.021) > 0.01:
					charcoal_ok = false
					break
	_check("DrumBrackets vertices are charcoal", charcoal_ok, "every vertex within 0.01 of (0.018, 0.023, 0.021)")
	_check("DrumBrackets is paint only", brackets != null and brackets.get_parent() == shell.find_child("Pod", true, false)
		and brackets.mesh.get_surface_count() == 1
		and brackets.mesh.surface_get_material(0).resource_name == "paint",
		"surfaces %d" % (brackets.mesh.get_surface_count() if brackets != null else -1))
	# Paint take mask (PAINT_SHADER step(0.05, alpha)): the brackets' charcoal paint vertices carry alpha 0 so
	# paint never tints them; every other paint vertex is 1 or a window index, exactly as before.
	var masked := 0
	var wheel_masked := 0
	var bracket_alpha_ok := brackets != null
	var other_ok := true
	var other_bad := 0
	for mi in _meshes(shell):
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(i)
			if mat == null or mat.resource_name != "paint":
				continue
			var cols = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
			for c in Array(cols if cols != null else []):
				if String(mi.name) == "DrumBrackets":
					masked += 1
					if c.a != 0.0:
						bracket_alpha_ok = false
				elif String(mi.name) == "Flywheel_R" and c.a == 0.0:
					wheel_masked += 1
				elif absf(c.a - 1.0) > 0.001 and not WINDOW_ALPHA.any(func(w): return absf(c.a - w) < 0.01):
					other_ok = false
					other_bad += 1
	_check("DrumBrackets paint vertices have alpha 0", bracket_alpha_ok and masked == BRACKET_VERTICES,
		"%d masked vertices, expected %d, all alpha exactly 0" % [masked, BRACKET_VERTICES])
	_check("drum rims and index slots have alpha 0", wheel_masked == FLYWHEEL_MASKED,
		"%d masked vertices, expected %d" % [wheel_masked, FLYWHEEL_MASKED])
	_check("other Tally paint alpha is 1 or a window", other_ok, "%d stray vertices" % other_bad)
	_check("shell draws unchanged", _counts(shell).draws == 11, "%d draws, expected 11" % _counts(shell).draws)
	_check("shell has no skeleton", document.get("skins", []).is_empty())
	_check("no duplicate pilot", shell.find_child("Pilot", true, false) == null)
	var source_names: Array = document.get("nodes", []).map(func(n): return n.get("name", ""))
	for name in ["Core", "Pod", "Dome", "Gyro", "GyroInner", "WeaponRing", "ReaderCarriage", "Flywheel.R", "Flywheel.L", "Hub.00", "Gap.29"]:
		_check("shell node " + name, name in source_names and _shell_node(shell, name) != null)
	var pod := shell.find_child("Pod", true, false)
	var dome := shell.find_child("Dome", true, false) as Node3D
	_check("identity Dome", dome != null and dome.transform.is_equal_approx(Transform3D.IDENTITY))
	for name in ["Gyro", "WeaponRing", "ReaderCarriage", "Flywheel.R", "Flywheel.L", "Dome"]:
		var node := _shell_node(shell, name)
		_check("upright " + name, node != null and node.get_parent() == pod)
	var max_radius := 0.0
	var core_radius := 0.0
	var accents: Array = []
	for mi in _meshes(shell):
		var transform := _to_root(mi, shell)
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(i)
			if mat != null and mat.resource_name == "class_accent":
				accents.append(String(mi.name))
			for v in mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
				var radius: float = (transform * v).length()
				max_radius = maxf(max_radius, radius)
				if String(mi.name) == "Core":
					core_radius = maxf(core_radius, radius)
	_check("machinery reach", max_radius <= REACH, "%.4f m, rule 6 cap %.2f" % [max_radius, REACH])
	_check("lattice radius", core_radius >= 0.95 and core_radius <= CORE_LIMIT + 0.0001, "Core reaches %.4f m (0.95 to %.3f)" % [core_radius, CORE_LIMIT])
	_check("reader slot is the only accent", accents == ["WeaponRing"], "class_accent surfaces on %s" % [accents])
	for name in SOCKETS:
		var node := _shell_node(shell, name) as Node3D
		_check("socket " + name, name in source_names and node != null and (_to_root(node, shell).origin - SOCKETS[name]).length() < 0.00001,
			"expected %s" % SOCKETS[name])
	var bays := shell.find_children("CardBay_*", "", true, false)
	_check("exactly three card bays", bays.size() == 3, "bay count %d" % bays.size())
	var left := _shell_node(shell, "Flywheel.L") as Node3D
	_check("Flywheel.L marks the left drum", left != null and not (left is MeshInstance3D)
		and (_to_root(left, shell).origin - SOCKETS["FlywheelAxis.L"]).length() < 0.00001,
		"expected an empty at %s" % SOCKETS["FlywheelAxis.L"])
	var wheel := _shell_node(shell, "Flywheel.R") as MeshInstance3D
	_check("one drum mesh", wheel != null)
	if wheel != null:
		var bounds := wheel.mesh.get_aabb()
		# Both drums: 0.34 m across, 0.07 m deep each, outer faces 2 x 1.033 + 0.07 m apart.
		_check("flywheel diameter", absf(bounds.size.y - 0.34) < 0.001
			and absf(bounds.size.z - 0.34) < 0.001 and absf(bounds.size.x - 2.136) < 0.0001,
			"%s; wheel diameter 0.34 m; span 2.136 m" % bounds.size)
		# Pressure windows: one surface, four window indices in vertex alpha.
		var found := {}
		if wheel.mesh.get_surface_count() == 1:
			var cols = wheel.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			if cols != null:
				for c in cols:
					if c.a < 0.95 and c.a > 0.05:
						found[snappedf(c.a, 0.05)] = true
		var keys := found.keys()
		keys.sort()
		_check("drum windows", wheel.mesh.get_surface_count() == 1 and keys.size() == 4
			and keys.all(func(a): return WINDOW_ALPHA.any(func(w): return absf(a - w) < 0.01))
			and WINDOW_ALPHA.all(func(w): return keys.any(func(a): return absf(a - w) < 0.01)),
			"%d surface(s); window alphas %s" % [wheel.mesh.get_surface_count(), keys])


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
