extends RefCounted

const Palette := preload("res://src/core/palette.gd")

const BASE := "res://assets/models/warden_clamp_base.glb"
const KITS := {"reactor": "reactor", "swarm": "hive", "mind": "mind"}
const MANTLES := {
	2: {"family": "reactor", "path": "res://assets/models/warden_mantle_meltdown.glb"},
	4: {"family": "swarm", "path": "res://assets/models/warden_mantle_brood.glb"},
	5: {"family": "mind", "path": "res://assets/models/warden_mantle_hand.glb"},
	6: {"family": "mind", "path": "res://assets/models/warden_mantle_choir.glb"},
}
const BODIES := {
	"reactor": {"body": "res://assets/models/warden_reactor.glb", "kits": [], "point": "WeakPoint",
		"mount_parts": {"dam_face": ["GateL", "GateR"], "flume": ["PourLip"]}},
	"swarm": {"body": "res://assets/models/warden_swarm.glb", "kits": ["res://assets/models/warden_swarm_kit_drones.glb"],
		"point": "WeakPoint", "hang": "Suspension", "grips": ["Grip0", "Grip1", "Grip2"],
		"shed_rings": ["Ring5", "Ring4", "Ring3", "Ring2"]},
	"mind": {"body": "res://assets/models/warden_mind.glb", "kits": [], "point": "WeakPoint"},
}
const BODY_BLENDS := {
	"reactor": {"idle": 1.0, "pulse_warn": 0.5, "pulse": 0.1, "active": 0.5, "chunk_lost": 0.8, "chunk_lost_1": 0.8,
		"chunk_lost_2": 0.8, "chunk_lost_3": 0.8, "shrug": 0.2, "gates_open": 0.3, "pour": 0.3, "final_quiet": 2.0},
	"swarm": {"idle": 1.0, "pulse": 0.1, "active": 0.5, "hoist_ride": 0.3, "snip": 0.2, "stagger_open": 0.5,
		"chunk_shed": 0.8, "brood_dark": 0.5, "break": 2.0},
	"mind": {"idle": 1.0, "pulse_warn": 0.5, "pulse": 0.1, "active": 0.5, "chunk_lost": 0.8, "chunk_lost_ring": 0.8,
		"chunk_lost_middle": 0.8, "chunk_lost_index": 0.8, "shrug": 0.2, "grip_falter": 0.5, "takeoff": 0.3,
		"glide": 0.3, "land": 0.2, "knocked_down": 0.2, "final_quiet": 2.0},
}
const BODY_CHARGE := {"reactor": "pulse_warn", "swarm": "pulse", "mind": "pulse_warn"}
const BODY_FINAL := {"reactor": "final_quiet", "swarm": "break", "mind": "final_quiet"}
const REACTOR_PULSE_EXTRA := {"dam_face": "gates_open", "flume": "pour"}
const MIND_CHUNK_FINGERS := [
	{"clip": "chunk_lost", "seam": "ancient_light_seam3"},
	{"clip": "chunk_lost_ring", "seam": "ancient_light_seam2"},
	{"clip": "chunk_lost_middle", "seam": "ancient_light_seam1"},
	{"clip": "chunk_lost_index", "seam": "ancient_light_seam0"},
]
const MIND_LENS_BONES := ["Lens", "LensIris", "SmallLens0", "SmallLens1", "SmallLens2", "SmallLens3", "SmallLens4"]
const MIND_FLIGHT_CLIPS := ["takeoff", "glide", "land", "knocked_down"]
const MANTLE_MOUNTS := {
	"MountBody": "Body", "MountVent0": "Vent0", "MountVent1": "Vent1", "MountVent2": "Vent2",
	"MountArmL": "ArmL", "MountArmR": "ArmR",
}


static func wears_body(warden) -> bool:
	return BODIES.has(warden.family) and bool(warden.get("harpoon_anchor"))


static func driver_count(warden, key: String) -> int:
	var driver = warden.mount_driver
	if driver == null or not (key in driver):
		return 0
	return int(driver.get(key))


static func own_clip(player: AnimationPlayer, clip: String) -> void:
	var shared := player.get_animation_library(&"")
	if shared == null or not shared.has_animation(clip):
		return
	var own := AnimationLibrary.new()
	for clip_name in shared.get_animation_list():
		var anim := shared.get_animation(clip_name)
		own.add_animation(clip_name, anim.duplicate() if clip_name == clip else anim)
	player.remove_animation_library(&"")
	player.add_animation_library(&"", own)


static func rig_mind_body(warden, rec: Dictionary) -> void:
	var body: Node3D = rec.body
	var skel: Skeleton3D = rec.skeleton
	rec.pose = body.find_child("Pose", true, false) as Node3D
	rec.lens = skel.find_bone("Lens") if skel != null else -1
	if rec.weak.get_parent() is BoneAttachment3D:
		rec.weak.position = Vector3.ZERO
	if warden.mounting == "spires":
		var perch := body.find_child("PosePerch", true, false) as Node3D
		if perch != null and rec.pose != null:
			rec.pose.transform = perch.transform
			rec.pose_base = perch.transform
		var player: AnimationPlayer = rec.players[0]
		if player.has_animation("perch"):
			rec.perch_pose = clip_end_pose(player.get_animation("perch"), skel, MIND_LENS_BONES, true)
		else:
			push_error("hero_assets: mind body has no clip 'perch'")


static func clip_end_pose(anim: Animation, skel: Skeleton3D, names: Array, exclude := false) -> Dictionary:
	var out := {}
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if path.get_subname_count() == 0:
			continue
		var bone_name := String(path.get_subname(0))
		if (bone_name in names) == exclude:
			continue
		var bone := skel.find_bone(bone_name)
		if bone < 0:
			continue
		var entry: Dictionary = out.get(bone, {})
		match anim.track_get_type(t):
			Animation.TYPE_POSITION_3D:
				entry["position"] = anim.position_track_interpolate(t, anim.length)
			Animation.TYPE_ROTATION_3D:
				entry["rotation"] = anim.rotation_track_interpolate(t, anim.length)
			Animation.TYPE_SCALE_3D:
				entry["scale"] = anim.scale_track_interpolate(t, anim.length)
		out[bone] = entry
	return out


static func set_bone_pose(skel: Skeleton3D, bone: int, entry: Dictionary) -> void:
	if entry.has("position"):
		skel.set_bone_pose_position(bone, entry.position)
	if entry.has("rotation"):
		skel.set_bone_pose_rotation(bone, entry.rotation)
	if entry.has("scale"):
		skel.set_bone_pose_scale(bone, entry.scale)


static func play_body(rec: Dictionary, clips: Array, backwards := false) -> void:
	rec.queue = clips.slice(1)
	start_body_clip(rec, String(clips[0]), backwards)


static func start_body_clip(rec: Dictionary, clip: String, backwards := false) -> void:
	var blend: float = BODY_BLENDS[rec.body_kind].get(clip, -1.0)
	for p in rec.players:
		var player := p as AnimationPlayer
		if not player.has_animation(clip):
			push_error("hero_assets: %s Warden body player %s has no clip '%s'" % [rec.body_kind, player.get_parent().name, clip])
			continue
		if backwards:
			player.play_backwards(clip, blend)
		else:
			player.play(clip, blend)


static func drive_body(rec: Dictionary) -> void:
	var warden = rec.warden
	var seen: Dictionary = rec.seen
	var kind: String = rec.body_kind
	var staggered: bool = warden.staggered()
	if staggered != seen.staggered:
		seen.staggered = staggered
		body_stagger(rec, staggered)
	var charging: bool = warden.state_name() == "charging"
	if charging and not seen.charging:
		play_body(rec, [BODY_CHARGE[kind]])
	seen.charging = charging
	if warden.pulses != seen.pulses:
		seen.pulses = warden.pulses
		body_pulse(rec)
	var chunks: int = warden.chunks_left()
	if chunks < seen.chunks:
		for n in range(5 - seen.chunks, 5 - chunks):
			body_chunk(rec, n)
		seen.chunks = chunks
	if kind == "swarm":
		var rides := driver_count(warden, "rides")
		if rides != seen.rides:
			seen.rides = rides
			play_body(rec, ["hoist_ride"])


static func body_pulse(rec: Dictionary) -> void:
	var warden = rec.warden
	match rec.body_kind:
		"swarm":
			var player: AnimationPlayer = rec.players[0]
			if player.current_animation == "pulse":
				rec.queue = ["active"]
			else:
				play_body(rec, ["active"])
		"reactor":
			var clips := ["pulse"]
			if REACTOR_PULSE_EXTRA.has(warden.mounting):
				clips.append(REACTOR_PULSE_EXTRA[warden.mounting])
			clips.append("active")
			play_body(rec, clips)
		"mind":
			play_body(rec, ["pulse", "active"])


static func body_stagger(rec: Dictionary, open: bool) -> void:
	var warden = rec.warden
	match rec.body_kind:
		"reactor":
			if open:
				play_body(rec, ["active"])
		"swarm":
			if open:
				play_body(rec, ["stagger_open"])
		"mind":
			if warden.mounting == "spires":
				var driver = warden.mount_driver
				var flying: bool = driver != null and driver.has_method("flying") and driver.flying()
				if open:
					play_body(rec, ["knocked_down" if flying else "active"])
			elif open:
				play_body(rec, ["grip_falter"])
			elif rec.players[0].assigned_animation == "grip_falter":
				play_body(rec, ["grip_falter", "idle"], true)


static func body_chunk(rec: Dictionary, n: int) -> void:
	var body: Node3D = rec.body
	var clip := ""
	var entry := {}
	match rec.body_kind:
		"reactor":
			clip = "chunk_lost" if n == 1 else "chunk_lost_%d" % (n - 1)
			entry = {"node": body.find_child("Jacket%d" % (n - 1), true, false)}
		"swarm":
			var ring: String = BODIES.swarm.shed_rings[n - 1]
			clip = "chunk_shed"
			filter_shed(rec.players[0], ring)
			entry = {"bone": rec.skeleton.find_bone(ring) if rec.skeleton != null else -1}
		"mind":
			var finger: Dictionary = MIND_CHUNK_FINGERS[n - 1]
			clip = finger.clip
			var digit := String(finger.seam).right(1)
			var bones := ["Finger%s_0" % digit, "Finger%s_1" % digit, "Finger%s_2" % digit]
			var player: AnimationPlayer = rec.players[0]
			if player.has_animation(clip):
				entry = {"pose": clip_end_pose(player.get_animation(clip), rec.skeleton, bones)}
			rec.dark.append(finger.seam)
	entry["clip"] = clip
	rec.lost.append(entry)
	var clips := [clip]
	if n >= 4:
		rec.final = true
		clips.append(BODY_FINAL[rec.body_kind])
		if rec.body_kind == "mind":
			rec.dark.append("ancient_light_thumb")
	play_body(rec, clips)


static func filter_shed(player: AnimationPlayer, ring: String) -> void:
	if not player.has_animation("chunk_shed"):
		return
	var anim := player.get_animation("chunk_shed")
	var rings: Array = BODIES.swarm.shed_rings
	for t in anim.get_track_count():
		var bone := String(anim.track_get_path(t)).get_slice(":", 1)
		if bone in rings:
			anim.track_set_enabled(t, bone == ring)


static func hold_mind(rec: Dictionary, current: String, falling: int) -> void:
	var warden = rec.warden
	var skel: Skeleton3D = rec.skeleton
	if skel == null:
		return
	var moving: Dictionary = rec.lost[falling].get("pose", {}) if falling >= 0 else {}
	if not rec.perch_pose.is_empty() and not current in MIND_FLIGHT_CLIPS:
		for bone in rec.perch_pose:
			if not moving.has(bone):
				set_bone_pose(skel, bone, rec.perch_pose[bone])
	for i in rec.lost.size():
		if i != falling:
			var held: Dictionary = rec.lost[i].get("pose", {})
			for bone in held:
				set_bone_pose(skel, bone, held[bone])
	var to_ball: Vector3 = warden.flat_to_ball()
	if rec.pose != null and to_ball.length() > 0.1:
		var yaw: float = atan2(-to_ball.x, -to_ball.z) - rec.body.global_rotation.y
		rec.pose.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * rec.pose_base
	track_lens(rec)


static func track_lens(rec: Dictionary) -> void:
	var skel: Skeleton3D = rec.skeleton
	var lens: int = rec.lens
	var target = rec.warden.target
	if lens < 0 or target == null or not target.has_method("ball_position"):
		return
	var parent := skel.get_bone_parent(lens)
	var parent_pose := skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var origin: Vector3 = parent_pose * skel.get_bone_pose_position(lens)
	var dir: Vector3 = skel.global_transform.affine_inverse() * (target.ball_position() as Vector3) - origin
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	var look := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
	var turned := parent_pose.basis.orthonormalized().inverse() * look * skel.get_bone_global_rest(lens).basis.orthonormalized()
	skel.set_bone_pose_rotation(lens, turned.get_rotation_quaternion())


static func update_mantle(rec: Dictionary) -> void:
	var tool := rec.mantle_tool as StandardMaterial3D
	if tool == null:
		return
	var warden = rec.warden
	var lit: float = 0.0 if warden.staggered() else warden.charge_fraction()
	tool.emission_energy_multiplier = lit * 2.0
	if tool.albedo_texture != null:
		tool.emission = Color.WHITE
		var brightness := lerpf(0.03, 1.0, lit)
		tool.albedo_color = Color(brightness, brightness, brightness)
	else:
		tool.albedo_color = Palette.HAZARD.lerp(Palette.CHARCOAL, 1.0 - lit)


static func rig_warden_jaws(base: Node3D, rec: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		var jaw := base.get_node("JawL" if side < 0 else "JawR") as MeshInstance3D
		var bounds := jaw.mesh.get_aabb()
		var edge := Vector3(0.0, bounds.position.y, bounds.position.z if side < 0 else bounds.end.z)
		rec.jaws.append({"node": jaw, "rest": jaw.transform, "pivot": jaw.transform * edge, "out": side})
	for key in ["ancient_light_base", "ancient_light"]:
		rec.light_rest[key] = (rec.materials[key] as StandardMaterial3D).emission


static func adapt_warden_tower(tower: MeshInstance3D, shift: Vector3, top: float) -> void:
	var adapted := ArrayMesh.new()
	for surface in tower.mesh.get_surface_count():
		var arrays := tower.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var y := vertices[i].y + tower.position.y
			if y > 2.2:
				vertices[i] += shift * ((y - 2.2) / (top - 2.2))
				var shear := Basis(Vector3.RIGHT, Vector3.UP + shift / (top - 2.2), Vector3.BACK)
				normals[i] = (shear.inverse().transposed() * normals[i]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		adapted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		adapted.surface_set_material(surface, tower.mesh.surface_get_material(surface))
	tower.mesh = adapted


static func has_warden_chunk_nodes(base: Node3D) -> bool:
	for path in ["CoreAssembly", "JawL/InnerL", "JawR/InnerR"]:
		if not base.has_node(path):
			return false
	for i in 4:
		if base.find_child("ArmourSegment%d" % i, true, false) == null:
			return false
	return true


static func move_warden_fragment(seconds: float, flight: Dictionary) -> void:
	if not is_instance_valid(flight.node):
		return
	var pose: Transform3D = flight.start
	pose.origin += flight.normal * (14.0 * seconds) + Vector3.DOWN * (18.0 * seconds * seconds)
	var turn := Basis(flight.normal.cross(Vector3.UP), seconds * 5.0)
	var offset: Vector3 = flight.centre - flight.start.origin
	pose.origin += offset - turn * offset
	pose.basis = turn * pose.basis
	flight.node.global_transform = pose
	flight.node.visible = seconds < 0.18
