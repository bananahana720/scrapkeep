extends SceneTree
# SPIL-9's grown-mark add-ons and the called assist (tools/blender/companion/build_spil9.py,
# storyboard "SPIL-9 Grows Up"). The marks GLB seats through hero_assets' bone mount, the same
# path a companion skin takes, so each mark must land where it was drawn on the hull and ride
# BodyPose through the assist. The three assist clips chain pose to pose and come home on rest.

const T := preload("res://tests/support/t.gd")
const HeroAssetsScript := preload("res://src/presentation/hero_assets.gd")
const MARKS := ["Mk1Halo", "Mk2Fins", "Mk3Halo", "Mk4Exhaust", "Mk5CoreCrest"]
const ASSIST := {"assist_rise": 0.15, "assist_drop": 0.15, "assist_return": 0.45}
const SLOTS := ["paint", "bare_metal", "rubber", "field"]

var t := T.new("spil9_marks_test")


func _initialize() -> void:
	_run.call_deferred()


func _box(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in ([node] if node is MeshInstance3D else []) + node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _pose(rig: Skeleton3D) -> Array:
	var bone := rig.find_bone("BodyPose")
	return [rig.get_bone_pose_position(bone), rig.get_bone_pose_rotation(bone), rig.get_bone_pose_scale(bone)]


func _gap(a: Array, b: Array) -> float:
	return maxf(maxf((a[0] as Vector3).distance_to(b[0]), (a[1] as Quaternion).angle_to(b[1])), ((a[2] as Vector3) - (b[2] as Vector3)).length())


func _at(player: AnimationPlayer, rig: Skeleton3D, clip: String, at: float) -> Array:
	player.play(clip)
	player.seek(at, true)
	player.advance(0)
	return _pose(rig)


func _run() -> void:
	var model := (load("res://assets/models/companion/spil9.glb") as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var rig := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	t.check("spil9 rig and clips", rig != null and player != null)
	if rig == null or player == null:
		quit(t.verdict())
		return

	# Assist clips: lengths, chain continuity, rest at both ends, a real squash on the hit frame.
	var rest := [rig.get_bone_rest(rig.find_bone("BodyPose")).origin, rig.get_bone_rest(rig.find_bone("BodyPose")).basis.get_rotation_quaternion(), Vector3.ONE]
	for clip in ASSIST:
		t.check("has " + clip, player.has_animation(clip))
		if player.has_animation(clip):
			t.near(clip + " length", player.get_animation(clip).length, ASSIST[clip], 0.011)
	t.check("rise starts on rest", _gap(_at(player, rig, "assist_rise", 0.0), rest) < 0.01)
	var risen := _at(player, rig, "assist_rise", 0.15)
	t.check("rise lifts the body", (risen[0] as Vector3).y - (rest[0] as Vector3).y > 0.2, str(risen[0]))
	t.check("drop starts where rise ends", _gap(_at(player, rig, "assist_drop", 0.0), risen) < 0.01)
	var hit := _at(player, rig, "assist_drop", 0.4 / 3.0)
	t.check("drop squashes flat on the hit frame", (hit[2] as Vector3).z < 0.8 and (hit[2] as Vector3).x > 1.15, str(hit[2]))
	var landed := _at(player, rig, "assist_drop", 0.15)
	t.check("return starts where drop ends", _gap(_at(player, rig, "assist_return", 0.0), landed) < 0.01)
	t.check("return ends on rest", _gap(_at(player, rig, "assist_return", 0.45), rest) < 0.01)
	player.stop()
	rig.reset_bone_poses()

	# Marks: one Hull root, five parts, the shared material slots, seated by the real mount.
	var marks := (load("res://assets/models/companion/spil9_marks.glb") as PackedScene).instantiate()
	var tops: Array = []
	for child in marks.get_children():
		tops.append(String(child.name))
	t.check("marks GLB has one Hull root", tops == ["Hull"], str(tops))
	for mi: MeshInstance3D in marks.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			t.check(mi.name + " uses a shared slot", mat != null and mat.resource_name in SLOTS, str(mat.resource_name if mat else null))
	var assets := HeroAssetsScript.new()
	var mounts: Array = assets._mount_on_bones(model, marks, {"class": Color.WHITE}, "companion_marks")
	t.check("marks mount on the Hull bone", mounts.size() == 1 and (mounts[0] as BoneAttachment3D).bone_name == "Hull")
	if mounts.is_empty():
		assets.free()
		quit(t.verdict())
		return
	var part := {}
	for name in MARKS:
		var node := (mounts[0] as Node).find_child(name, true, false)
		t.check("mounted " + name, node != null)
		if node != null:
			part[name] = node
	if part.size() == MARKS.size():
		var hull := _box(model.find_child("CompanionMesh", true, false))
		var halo1 := _box(part["Mk1Halo"])
		var halo3 := _box(part["Mk3Halo"])
		t.check("Mk I halo hangs behind the sockets", halo1.get_center().distance_to(Vector3(0, 0.62, 0.40)) < 0.04 and halo1.position.z > 0.25, str(halo1))
		t.check("Mk III halo rings the first", halo3.get_center().distance_to(halo1.get_center()) < 0.05 and halo3.size.x > halo1.size.x, str(halo3))
		var fins := _box(part["Mk2Fins"])
		t.check("Mk II fins sweep out past both bumpers", fins.position.x < -0.7 and fins.end.x > 0.7 and fins.end.z > 0.4, str(fins))
		var exhaust := _box(part["Mk4Exhaust"])
		t.check("Mk IV exhaust sits behind the hull", exhaust.position.z > 0.3 and exhaust.end.z > hull.end.z, str(exhaust))
		var crest := _box(part["Mk5CoreCrest"])
		t.check("Mk V crest rises off the deck", crest.end.y > 0.45 and crest.position.y > 0.2, str(crest))
		# Marks ride BodyPose: at the top of the rise the halo has climbed with the body.
		var before := halo1.get_center()
		_at(player, rig, "assist_rise", 0.15)
		rig.force_update_all_bone_transforms()
		(mounts[0] as BoneAttachment3D).on_skeleton_update()
		t.check("marks ride the assist", _box(part["Mk1Halo"]).get_center().y - before.y > 0.2)
		player.stop()
	assets.free()
	model.queue_free()
	quit(t.verdict())
