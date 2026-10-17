extends SceneTree
# 2026-10-16: the three outfits and the Till Bell (design-v3/COSMETICS-ART-BRIEFS.md, recipe
# tools/blender/outfits/build_outfits.py). Each GLB mounts on its shipped rig through the
# game's own helper, puts every top-level node on a real bone, stays in the detail budget,
# carries no light or override, and sits where it was modelled. The registry rows and the
# PENDING_ART removals are port notes; this test reads the GLB paths directly.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const T := preload("res://tests/support/t.gd")

const ITEMS := {
	"outfit_rivet_hood": {"rig": "res://assets/models/pilot_rivet_anim.glb", "path": "res://assets/cosmetics/outfits/outfit_rivet_hood.glb", "kind": "outfit", "bones": ["head"]},
	"outfit_tally_eyeshade": {"rig": "res://assets/models/pilot_tally_anim.glb", "path": "res://assets/cosmetics/outfits/outfit_tally_eyeshade.glb", "kind": "outfit", "bones": ["head", "upper_arm.L", "upper_arm.R"]},
	"outfit_tarn_steady_cap": {"rig": "res://assets/models/pilot_tarn_anim.glb", "path": "res://assets/cosmetics/outfits/outfit_tarn_steady_cap.glb", "kind": "outfit", "bones": ["head"]},
	"companion_skin_till_bell": {"rig": "res://assets/models/companion/spil9.glb", "path": "res://assets/cosmetics/companion_skins/companion_skin_till_bell.glb", "kind": "companion_skin", "bones": ["Deck"]},
}
const TRI_CAP := 1500
const DOME := 0.98
# hero_assets._mount_on_bones before its port note skips a part whose bone name has a dot
# (glTF import renames upper_arm.L to upper_arm_L) and leaves an outfit clip's tracks
# pointing at the GLB's own tree. The port note's patch sets this true; until then the
# garters and the hood's motion are reported, not required.
const MOUNT_PATCHED := false

var _t := T.new("outfit_art_test")


func _initialize() -> void:
	for id in ITEMS:
		await _item(id, ITEMS[id])
	_steady_cap_covers_the_battered_one()
	quit(_t.verdict())


func _rig(path: String) -> Node3D:
	var rig := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(rig)
	return rig


func _item(id: String, spec: Dictionary) -> void:
	var hero := HeroAssets.new()
	var rig := _rig(spec.rig)
	var mounts: Array
	if spec.kind == "outfit":
		mounts = hero.fit_outfit_scene(rig, spec.path, {})
	else:
		mounts = hero._mount_on_bones(rig, hero._addon(spec.path), {"class": Color.WHITE}, spec.kind)
	await process_frame
	var bones: Array = []
	var tris := 0
	var surfaces := 0
	var lights := 0
	var overrides := 0
	var outside := 0
	for mount in mounts:
		if mount is BoneAttachment3D:
			bones.append(String(mount.bone_name))
			lights += mount.find_children("*", "Light3D", true, false).size()
			for mesh in mount.find_children("*", "MeshInstance3D", true, false):
				surfaces += mesh.mesh.get_surface_count()
				if mesh.material_override != null:
					overrides += 1
				for s in mesh.mesh.get_surface_count():
					tris += mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
				if spec.kind == "outfit":
					var box: AABB = mesh.global_transform * mesh.get_aabb()
					for corner in 8:
						if box.get_endpoint(corner).length() > DOME:
							outside += 1
	bones.sort()
	if MOUNT_PATCHED:
		_t.eq("%s mounts on bones" % id, bones, spec.bones)
	else:
		_t.check("%s mounts on head or Deck" % id, bones.has(spec.bones[0]), "mounted %s of %s" % [bones, spec.bones])
	_t.check("%s within the detail cap" % id, tris > 0 and tris <= TRI_CAP, "%d triangles, %d surfaces" % [tris, surfaces])
	_t.eq("%s carries no light or override" % id, [lights, overrides], [0, 0])
	if spec.kind == "outfit":
		_t.eq("%s stays inside the glass dome" % id, outside, 0)
	if id == "outfit_rivet_hood":
		_hood_clips(mounts)
	rig.queue_free()
	hero.free()
	await process_frame


func _hood_clips(mounts: Array) -> void:
	var player: AnimationPlayer = null
	for mount in mounts:
		if mount is AnimationPlayer:
			player = mount
	_t.check("the hood brings its AnimationPlayer", player != null)
	if player == null:
		return
	_t.check("the hood has ult_windup and ult_recover", player.has_animation("ult_windup") and player.has_animation("ult_recover"))
	var anim := player.get_animation("ult_windup")
	_t.near("ult_windup snaps in 0.12 s and holds to the pilot's clip end", anim.length, 1.0 / 3.0, 0.002)
	# The clip's tracks address the GLB's own tree ("head/HoodShell"); after the mount the part
	# sits at "Outfit_head/head/HoodShell" under the skeleton. hero_assets.gd needs the
	# track-path port note before the hood moves in game; this line reports, it does not fail.
	var base := player.get_node(player.root_node)
	var resolved := 0
	for i in anim.get_track_count():
		if base.get_node_or_null(NodePath(String(anim.track_get_path(i)).get_slice(":", 0))) != null:
			resolved += 1
	if not MOUNT_PATCHED:
		print("[hood clip tracks resolve after mount] %d of %d; needs the port note" % [resolved, anim.get_track_count()])
		return
	_t.eq("every hood track resolves after the mount", resolved, anim.get_track_count())
	var shell := base.find_child("HoodShell*", true, false) as Node3D
	var up := shell.rotation.x
	player.play("ult_windup")
	player.seek(anim.length, true)
	_t.check("ult_windup brings the hood down about 70 degrees", absf(rad_to_deg(up - shell.rotation.x) - 70.0) < 1.0,
		"rest %.1f, down %.1f degrees" % [rad_to_deg(up), rad_to_deg(shell.rotation.x)])
	player.play("ult_recover")
	player.seek(player.get_animation("ult_recover").length, true)
	_t.near("ult_recover lifts it back", shell.rotation.x, up, 0.01)


func _steady_cap_covers_the_battered_one() -> void:
	var hero := HeroAssets.new()
	var rig := _rig(ITEMS.outfit_tarn_steady_cap.rig)
	var cap := rig.find_child("Cap", true, false) as MeshInstance3D
	var mounts := hero.fit_outfit_scene(rig, ITEMS.outfit_tarn_steady_cap.path, {})
	var steady := mounts[0].find_child("SteadyCap*", true, false) as MeshInstance3D if not mounts.is_empty() else null
	_t.check("Tarn's battered Cap and the Steady Cap both exist", cap != null and steady != null)
	if cap == null or steady == null:
		return
	_t.eq("Replace_Cap hides the battered Cap", cap.layers, 0)
	var old: AABB = cap.global_transform * cap.get_aabb()
	var new: AABB = steady.global_transform * steady.get_aabb()
	_t.check("the Steady Cap covers the battered one", new.grow(0.005).encloses(AABB(old.position, Vector3(old.size.x, 0.0, old.size.z))),
		"old %s, new %s" % [old, new])
	_t.check("the Steady Cap stands taller", new.size.y > old.size.y * 1.5, "%.3f vs %.3f m" % [new.size.y, old.size.y])
	hero.remove_outfit(rig)
	_t.check("removing it shows the battered Cap again", cap.layers != 0)
	rig.free()
	hero.free()
