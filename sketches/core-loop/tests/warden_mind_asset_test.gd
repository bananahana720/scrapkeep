extends SceneTree

# KF7, the Mind's hand body (design-v3/wardens/mind.md sections 1 and 5; tools/blender/warden_mind.py).
# Loads warden_mind.glb through the import and checks:
#   clips     every section 5 row by name, its length within 0.05 s (plus the per-finger chunk_lost
#             and per-knuckle shrug variants the loader picks from).
#   collider  warden.gd RADIUS 2.8 and HALF_HEIGHT 1.6 at the Warden's centre, 1.6 m above the
#             GLB origin (the stalk root). Below 2 m above the stalk root nothing passes r = 2.8;
#             no finger or thumb vertex passes 1 m beyond the collider's silhouette in the approach
#             view (|x| <= 3.8, -1.0 <= y <= 4.2). Both poses: the rest (the island hang) and the
#             rest moved by the PosePerch marker's transform (the perch: palm down, a half turn
#             about Z through the Palm bone at y 2.9).
#   held      the poses that stay on screen: the end frame of every chunk_lost clip (a lost finger
#             stays folded) in both poses, and the held perch clip in the perch, skinned from the
#             imported skeleton, keep every finger and thumb vertex inside the same band. A
#             positive control first: the lost finger's tip really moved.
#   point     the lens (the open weak point) 8 m under the Warden's centre in the hang (lens at 72 m
#             under an 80 m anchor, mind.md section 3.1); in the perch, with the perch clip held,
#             6 m above the grip (the fingers' palm-side face on the perch top, mind.md section 1)
#             and PERCH_LENS_OFFSET_Y above the Warden's centre; WeakPoint and Hardpoint0..2 present.
#   seams     four finger seam materials the loader can put out one at a time, plus the thumb's.
#   budget    tris, verts and draws within the registry row's class in assets/asset_budgets.json.
#   no light  no Light3D anywhere in the imported scene.
# A missing GLB fails loud.

const GLB := "res://assets/models/warden_mind.glb"
const REGISTRY := "res://assets/registry.json"
const BUDGETS := "res://assets/asset_budgets.json"
const ID := "warden_mind"
const RADIUS := 2.8
const HALF_HEIGHT := 1.6
const LOW_BAND := 2.0
const REACH := 1.0
const LENS_OFFSET_Y := -8.0
const PERCH_PIVOT_Y := 2.9
const GRIP_TO_LENS := 6.0
const PERCH_LENS_OFFSET_Y := 6.086
const CLIPS := {
	"idle": 4.0, "pulse_warn": 2.0, "pulse": 0.3, "active": 0.5, "chunk_lost": 1.0, "shrug": 0.4,
	"quote": 1.4, "grip_falter": 0.5, "takeoff": 0.6, "glide": 3.0, "land": 0.5, "knocked_down": 1.0,
	"final_quiet": 2.0,
	"chunk_lost_ring": 1.0, "chunk_lost_middle": 1.0, "chunk_lost_index": 1.0, "shrug_1": 0.4, "shrug_2": 0.4,
	"perch": 1.0,
}
# The chunk_lost clips by the finger they fold (Finger0 index .. Finger3 little).
const LOST := {"chunk_lost": 3, "chunk_lost_ring": 2, "chunk_lost_middle": 1, "chunk_lost_index": 0}
const SEAMS := ["ancient_light_seam0", "ancient_light_seam1", "ancient_light_seam2", "ancient_light_seam3",
	"ancient_light_thumb"]

var failures := 0


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s -> %s" % [label, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	# Deferred so the tree is live: the held poses need the AnimationPlayer inside it.
	call_deferred("_run")


func _run() -> void:
	if not ResourceLoader.exists(GLB):
		_check(false, "warden_mind.glb missing at %s" % GLB)
		_finish()
		return
	var packed := load(GLB) as PackedScene
	_check(packed != null, "warden_mind.glb imports as a scene")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate() as Node3D
	_clips(scene)
	var m := _measure(scene)
	_budget(m)
	_collider(scene, m)
	_point(scene)
	_held(scene, m)
	_seams(m)
	_check(scene.find_children("*", "Light3D", true, false).is_empty(), "no light node in the GLB")
	scene.free()
	_finish()


func _finish() -> void:
	print("warden_mind_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _clips(scene: Node) -> void:
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	_check(players.size() == 1, "one AnimationPlayer (found %d)" % players.size())
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	for clip in CLIPS:
		if not player.has_animation(clip):
			_check(false, "clip %s present" % clip)
			continue
		var got := player.get_animation(clip).length
		_check(absf(got - float(CLIPS[clip])) <= 0.05, "clip %s is %.3f s, wants %.2f within 0.05" % [clip, got, CLIPS[clip]])


func _xf_to(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var at: Node = node
	while at != root and at is Node3D:
		xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf


func _bone_name(mi: MeshInstance3D, bind: int) -> String:
	var skin := mi.skin
	if skin == null:
		return ""
	var name := String(skin.get_bind_name(bind))
	if name != "":
		return name
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if skel != null and skin.get_bind_bone(bind) >= 0:
		return skel.get_bone_name(skin.get_bind_bone(bind))
	return ""


# Every vertex in the GLB frame, whether it rides a finger or the thumb, and per-surface counts.
func _measure(scene: Node3D) -> Dictionary:
	var out := {"tris": 0, "verts": 0, "draws": 0, "points": PackedVector3Array(), "finger": [], "slots": [],
		"local": PackedVector3Array(), "bind": PackedInt32Array(), "bone": [], "mesh": []}
	for found in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := _xf_to(mi, scene)
		for s in mi.mesh.get_surface_count():
			out.draws += 1
			var mat := mi.mesh.surface_get_material(s)
			out.slots.append(mat.resource_name if mat != null else "")
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ix = arrays[Mesh.ARRAY_INDEX]
			out.verts += vs.size()
			out.tris += (ix.size() if ix != null else vs.size()) / 3
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			var per: int = 0 if bones == null else bones.size() / maxi(vs.size(), 1)
			for i in vs.size():
				out.points.append(xf * vs[i])
				out.local.append(vs[i])
				out.mesh.append(mi)
				var finger := false
				var bone := ""
				var bind := -1
				if per > 0:
					var best := 0
					for k in per:
						if weights[i * per + k] > weights[i * per + best]:
							best = k
					bind = int(bones[i * per + best])
					bone = _bone_name(mi, bind)
					finger = bone.begins_with("Finger") or bone.begins_with("Thumb")
				out.finger.append(finger)
				out.bind.append(bind)
				out.bone.append(bone)
	return out


func _budget(m: Dictionary) -> void:
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	var row := {}
	for r in registry.get("assets", []):
		if r.get("id", r.get("path", "")) == ID:
			row = r
	_check(not row.is_empty(), "registry row %s folded" % ID)
	if row.is_empty():
		return
	_check(row.get("path", "") == GLB and row.get("class", "") == "warden_base", "registry row: path %s, class warden_base (%s)" % [GLB, row.get("class", "")])
	_check(not row.has("exception"), "no budget exception on %s" % ID)
	var budgets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS)).classes
	var cap: Dictionary = budgets.get(row.get("class", ""), {})
	_check(not cap.is_empty(), "budget class %s exists" % row.get("class", ""))
	for key in ["tris", "verts", "draws"]:
		_check(int(m[key]) <= int(cap.get(key, -1)), "%s %d within %d" % [key, m[key], cap.get(key, -1)])


func _rule(points: PackedVector3Array, finger: Array, base_y: float, label: String) -> void:
	var low_r := 0.0
	var fx := 0.0
	var fy0 := INF
	var fy1 := -INF
	var fingers := 0
	for i in points.size():
		var p := points[i]
		if p.y >= base_y and p.y < base_y + LOW_BAND:
			low_r = maxf(low_r, Vector2(p.x, p.z).length())
		if finger[i]:
			fingers += 1
			fx = maxf(fx, absf(p.x))
			fy0 = minf(fy0, p.y)
			fy1 = maxf(fy1, p.y)
	# The silhouette band is relative to the collider's centre, 1.6 m above the GLB origin.
	_check(fingers > 0, "%s: finger and thumb vertices found by bone (%d)" % [label, fingers])
	_check(low_r <= RADIUS + 0.001, "%s: below 2 m above the stalk root, radius %.3f within %.1f" % [label, low_r, RADIUS])
	_check(fx <= RADIUS + REACH + 0.001, "%s: fingers reach |x| %.3f within %.1f" % [label, fx, RADIUS + REACH])
	_check(fy0 >= -REACH - 0.001, "%s: fingers' lowest y %.3f at or above %.1f" % [label, fy0, -REACH])
	_check(fy1 <= 2.0 * HALF_HEIGHT + REACH + 0.001, "%s: fingers' highest y %.3f at or below %.1f" % [label, fy1, 2.0 * HALF_HEIGHT + REACH])


func _collider(scene: Node3D, m: Dictionary) -> void:
	_rule(m.points, m.finger, 0.0, "hang")
	var perch := scene.find_child("PosePerch", true, false) as Node3D
	var pose := scene.find_child("Pose", true, false) as Node3D
	_check(perch != null and pose != null and perch.get_parent() == pose.get_parent(), "Pose and PosePerch nodes present, siblings")
	if perch == null or pose == null:
		return
	_check(_xf_to(pose.get_parent() as Node3D, scene).is_equal_approx(Transform3D.IDENTITY), "the GLB root sits at the scene origin")
	_check(pose.transform.is_equal_approx(Transform3D.IDENTITY), "the rest pose is the hang (Pose at identity)")
	var xf := perch.transform
	var moved := PackedVector3Array()
	for p in m.points:
		moved.append(xf * p)
	_check((xf * Vector3(0, PERCH_PIVOT_Y, 0)).is_equal_approx(Vector3(0, PERCH_PIVOT_Y, 0))
		and (xf * Vector3(0, PERCH_PIVOT_Y + 1.0, 0)).is_equal_approx(Vector3(0, PERCH_PIVOT_Y - 1.0, 0)),
		"the perch is a half turn about the Palm bone (y %.1f): palm down, the palm in the collider" % PERCH_PIVOT_Y)
	_rule(moved, m.finger, (xf * Vector3.ZERO).y, "perch")


func _point(scene: Node3D) -> void:
	var skels := scene.find_children("*", "Skeleton3D", true, false)
	_check(skels.size() == 1, "one Skeleton3D")
	if skels.is_empty():
		return
	var skel := skels[0] as Skeleton3D
	var lens := skel.find_bone("Lens")
	_check(lens >= 0, "Lens bone present")
	if lens >= 0:
		var at := _xf_to(skel, scene) * skel.get_bone_global_rest(lens).origin
		var offset := at - Vector3(0, HALF_HEIGHT, 0)
		_check(absf(offset.y - LENS_OFFSET_Y) <= 0.1 and Vector2(offset.x, offset.z).length() <= 0.01,
			"the lens sits %s from the Warden's centre (wants 0, %.1f, 0)" % [offset, LENS_OFFSET_Y])
	for i in 4:
		for s in 3:
			_check(skel.find_bone("Finger%d_%d" % [i, s]) >= 0, "bone Finger%d_%d" % [i, s])
	for name in ["WeakPoint", "Hardpoint0", "Hardpoint1", "Hardpoint2"]:
		_check(not scene.find_children(name, "Node3D", true, false).is_empty(), "socket %s present" % name)


# Every vertex skinned by the skeleton's current pose, in the GLB frame (rigid skin: its one bone).
func _skinned(scene: Node3D, skel: Skeleton3D, m: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	var to_scene := _xf_to(skel, scene)
	for i in m.local.size():
		var mi := m.mesh[i] as MeshInstance3D
		var bind: int = m.bind[i]
		if mi.skin == null or bind < 0:
			out.append(m.points[i])
			continue
		var bone := skel.find_bone(String(m.bone[i]))
		out.append(to_scene * skel.get_bone_global_pose(bone) * mi.skin.get_bind_pose(bind) * m.local[i])
	return out


func _pose_at_end(player: AnimationPlayer, clip: String) -> void:
	player.play(clip)
	player.seek(player.get_animation(clip).length, true)
	player.advance(0)


func _band(points: PackedVector3Array, finger: Array, label: String) -> void:
	var fx := 0.0
	var fy0 := INF
	var fy1 := -INF
	for i in points.size():
		if finger[i]:
			fx = maxf(fx, absf(points[i].x))
			fy0 = minf(fy0, points[i].y)
			fy1 = maxf(fy1, points[i].y)
	var ok := fx <= RADIUS + REACH + 0.001 and fy0 >= -REACH - 0.001 and fy1 <= 2.0 * HALF_HEIGHT + REACH + 0.001
	_check(ok, "%s: fingers |x| %.3f, y %.3f..%.3f inside |x| <= %.1f, %.1f..%.1f" % [label, fx, fy0, fy1,
		RADIUS + REACH, -REACH, 2.0 * HALF_HEIGHT + REACH])


func _tip(points: PackedVector3Array, m: Dictionary, bone: String) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for i in points.size():
		if m.bone[i] == bone:
			sum += points[i]
			n += 1
	return sum / maxf(n, 1)


func _held(scene: Node3D, m: Dictionary) -> void:
	var skels := scene.find_children("*", "Skeleton3D", true, false)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	var perch := scene.find_child("PosePerch", true, false) as Node3D
	if skels.size() != 1 or players.size() != 1 or perch == null:
		_check(false, "held poses: one skeleton, one player and PosePerch")
		return
	var skel := skels[0] as Skeleton3D
	var player := players[0] as AnimationPlayer
	# The mixer applies a seek only inside the tree.
	root.add_child(scene)
	var rest := _skinned(scene, skel, m)
	var drift := 0.0
	for i in rest.size():
		drift = maxf(drift, rest[i].distance_to(m.points[i]))
	_check(drift <= 0.01, "skinning the rest pose reproduces the mesh (worst %.4f m)" % drift)
	for clip in LOST:
		if not player.has_animation(clip):
			_check(false, "held %s: clip present" % clip)
			continue
		_pose_at_end(player, clip)
		var pts := _skinned(scene, skel, m)
		var bone := "Finger%d_2" % LOST[clip]
		var moved := _tip(pts, m, bone).distance_to(_tip(rest, m, bone))
		_check(moved >= 1.0, "held %s: positive control, the lost finger's last segment moved %.2f m" % [clip, moved])
		_band(pts, m.finger, "held %s end, hang" % clip)
		var turned := PackedVector3Array()
		for p in pts:
			turned.append(perch.transform * p)
		_band(turned, m.finger, "held %s end, perch" % clip)
	if not player.has_animation("perch"):
		_check(false, "held perch: clip present")
		return
	_pose_at_end(player, "perch")
	var pts := _skinned(scene, skel, m)
	var turned := PackedVector3Array()
	for p in pts:
		turned.append(perch.transform * p)
	_band(turned, m.finger, "held perch, perch")
	var grip := INF
	for i in turned.size():
		var b := String(m.bone[i])
		if b.begins_with("Finger") and b.ends_with("_0"):
			grip = minf(grip, turned[i].y)
	var lens := perch.transform * (_xf_to(skel, scene) * skel.get_bone_global_pose(skel.find_bone("Lens")).origin)
	var offset := lens - Vector3(0, HALF_HEIGHT, 0)
	_check(absf(lens.y - grip - GRIP_TO_LENS) <= 0.1, "held perch: the lens %.3f m above the grip (wants %.1f)" % [lens.y - grip, GRIP_TO_LENS])
	_check(absf(offset.y - PERCH_LENS_OFFSET_Y) <= 0.1 and Vector2(offset.x, offset.z).length() <= 0.01,
		"held perch: the lens sits %s from the Warden's centre (wants 0, %.3f, 0)" % [offset, PERCH_LENS_OFFSET_Y])
	player.stop()
	root.remove_child(scene)


func _seams(m: Dictionary) -> void:
	for slot in SEAMS:
		_check(m.slots.count(slot) == 1, "seam material %s is its own surface" % slot)
