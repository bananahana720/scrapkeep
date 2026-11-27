extends SceneTree


const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const PilotLiveliness := preload("res://src/presentation/pilot_liveliness.gd")
const PilotGearKit := preload("res://src/presentation/pilot_gear_kit.gd")

const EXPECTED_PILOT_BONES := 25
const WELD_QUANT := 10000.0
const LOOP_ROT_TOL_DEG := 0.5
const LOOP_POS_TOL_M := 0.002
const WEIGHT_SUM_TOL := 0.0001
const MAX_FRAME_ANG_VEL_DEG := 25.0

const ENEMY_GLBS := [
	"res://assets/models/world_one/enemy_chaser.glb",
	"res://assets/models/world_one/enemy_lobber.glb",
	"res://assets/models/world_one/enemy_foreman.glb",
	"res://assets/models/world_one/enemy_dispatcher.glb",
	"res://assets/models/world_one/enemy_hooker.glb",
	"res://assets/models/world_one/enemy_plated_brute.glb",
	"res://assets/models/world_one/enemy_boom_tender.glb",
	"res://assets/models/world_one/enemy_mag_trapper.glb",
	"res://assets/models/world_one/enemy_netcaster.glb",
	"res://assets/models/world_one/enemy_splitter.glb",
	"res://assets/models/world_one/enemy_linker.glb",
	"res://assets/models/world_one/enemy_jolt_layer.glb",
	"res://assets/models/world_one/enemy_catch_trap.glb",
	"res://assets/models/world_one/enemy_deflector.glb",
	"res://assets/models/world_one/enemy_bola_thrower.glb",
	"res://assets/models/world_one/enemy_swarm_remnant.glb",
	"res://assets/models/warden_reactor.glb",
	"res://assets/models/bosses/boss_brindle.glb",
]

const PROP_GLBS := [
	"res://assets/models/chunks.glb",
	"res://assets/models/reward_gate.glb",
	"res://assets/models/world_one/ambush_altar.glb",
	"res://assets/models/world_one/bet_crate.glb",
	"res://assets/models/world_one/cracked_cache.glb",
	"res://assets/models/world_one/dam.glb",
	"res://assets/models/world_one/ball_look_cutaway.glb",
	"res://assets/models/world_one/ball_look_cutaway_cockpit.glb",
]

var _out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var report := run_audit(root)
	var json_text := JSON.stringify(report, "  ")
	if not _out.is_empty():
		var dir := _out.get_base_dir()
		if not dir.is_empty():
			DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(_out, FileAccess.WRITE)
		if f != null:
			f.store_string(json_text)
			f.close()
	print("ASSET_RIG_CRAFT_AUDIT_SUMMARY ", JSON.stringify(report.summary))
	_print_tables(report)
	quit(0)


static func run_audit(motion_parent: Node = null) -> Dictionary:
	var pilots := {}
	var bone_union := {}
	for class_id: String in HeroAssets.PILOTS:
		var path: String = HeroAssets.PILOTS[class_id]
		var entry := audit_scene(path, true)
		entry["class_id"] = class_id
		pilots[class_id] = entry
		for bn in entry.get("bone_names", []):
			bone_union[String(bn)] = int(bone_union.get(String(bn), 0)) + 1

	var gear_kit := audit_pilot_gear_kit()
	var motion_60hz := {}
	if motion_parent != null:
		var stage := Node3D.new()
		motion_parent.add_child(stage)
		var painter := HeroAssets.new()
		stage.add_child(painter)
		for class_id: String in HeroAssets.PILOTS:
			motion_60hz[class_id] = audit_60hz_motion_strip(stage, painter, class_id)
		painter.free()
		stage.free()

	var shells := {}
	for class_id: String in HeroAssets.SHELLS:
		var entry := audit_scene(HeroAssets.SHELLS[class_id], false)
		entry["class_id"] = class_id
		shells[class_id] = entry

	var weapons := {}
	for class_id: String in HeroAssets.WEAPONS:
		var entry := audit_scene(HeroAssets.WEAPONS[class_id], false)
		entry["class_id"] = class_id
		weapons[class_id] = entry

	var enemies := {}
	for path: String in ENEMY_GLBS:
		if ResourceLoader.exists(path):
			enemies[path.get_file()] = audit_scene(path, false)

	var props := {}
	for path: String in PROP_GLBS:
		if ResourceLoader.exists(path):
			props[path.get_file()] = audit_scene(path, false)

	var greybox := scan_greybox_primitives("res://src")
	var pilot_25_ok := 0
	var pilot_loop_ok := 0
	var pilot_weights_ok := 0
	var pilot_watertight_ratio_sum := 0.0
	for cid in pilots:
		var p: Dictionary = pilots[cid]
		if int(p.get("bone_count", 0)) == EXPECTED_PILOT_BONES:
			pilot_25_ok += 1
		if bool(p.get("idle_loop_continuous", false)):
			pilot_loop_ok += 1
		if bool(p.get("weights_normalized_ok", false)):
			pilot_weights_ok += 1
		pilot_watertight_ratio_sum += float(p.get("manifold_edge_ratio", 0.0))

	var gear_watertight_ok := 0
	for gid in gear_kit:
		if bool((gear_kit[gid] as Dictionary).get("watertight", false)):
			gear_watertight_ok += 1

	var motion_zero_snaps_ok := 0
	var worst_ang_vel_deg := 0.0
	var worst_hand_err_m := 0.0
	for cid in motion_60hz:
		var m: Dictionary = motion_60hz[cid]
		if bool(m.get("zero_snaps_ok", false)):
			motion_zero_snaps_ok += 1
		worst_ang_vel_deg = maxf(worst_ang_vel_deg, float(m.get("max_bone_ang_vel_deg_per_frame", 0.0)))
		worst_hand_err_m = maxf(worst_hand_err_m, float(m.get("max_hand_yoke_err_m", 0.0)))

	var summary := {
		"pilots_audited": pilots.size(),
		"pilots_with_25_bones": pilot_25_ok,
		"pilots_with_continuous_idle_loop": pilot_loop_ok,
		"pilots_with_normalized_skin_weights": pilot_weights_ok,
		"pilot_mean_manifold_edge_ratio": snappedf(pilot_watertight_ratio_sum / maxf(float(pilots.size()), 1.0), 0.0001),
		"gear_kit_watertight": gear_watertight_ok,
		"gear_kit_total": gear_kit.size(),
		"motion_60hz_audited": motion_60hz.size(),
		"motion_60hz_zero_snaps": motion_zero_snaps_ok,
		"motion_60hz_worst_ang_vel_deg": snappedf(worst_ang_vel_deg, 0.01),
		"motion_60hz_worst_hand_yoke_err_m": snappedf(worst_hand_err_m, 0.0005),
		"shells_audited": shells.size(),
		"weapons_audited": weapons.size(),
		"enemies_audited": enemies.size(),
		"props_audited": props.size(),
		"greybox_primitive_sites": int(greybox.total_sites),
		"greybox_files_count": (greybox.by_file as Dictionary).size(),
	}
	return {
		"summary": summary,
		"pilots": pilots,
		"pilot_bone_census": bone_union,
		"pilot_gear_kit": gear_kit,
		"motion_60hz": motion_60hz,
		"shells": shells,
		"weapons": weapons,
		"enemies": enemies,
		"props": props,
		"greybox": greybox,
	}


static func audit_pilot_gear_kit() -> Dictionary:
	var out := {}
	for gid in PilotGearKit.GEAR_IDS:
		var mesh := PilotGearKit.build_gear(gid)
		var stats := PilotGearKit.inspect_mesh_watertight(mesh)
		var inv_tris := int(round((1.0 - float(stats.outward_ratio)) * float(stats.triangles)))
		stats["inverted_normals"] = inv_tris
		out[String(gid)] = stats
	return out


static func audit_60hz_motion_strip(stage: Node3D, painter, class_id: String) -> Dictionary:
	var pod := Node3D.new()
	pod.name = "Audit60Hz_" + class_id
	stage.add_child(pod)
	var fitted: Dictionary = painter.fit_pilot_into(pod, class_id, Color.WHITE)
	var pilot: Node3D = fitted.pilot
	var anim: AnimationPlayer = fitted.animator
	if anim != null:
		anim.stop()
	var skel := pilot.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	skel.reset_bone_poses()
	var live = PilotLiveliness.attach(pilot, class_id)
	live.reduced_motion_override = 0
	var cockpit := PilotGearKit.mount_cockpit_rig(pod, Color.WHITE)
	live.bind_cockpit_controls(cockpit)
	var yoke_node := cockpit.yoke as Node3D
	var gauges_node := cockpit.gauges as Node3D

	var bone_count := skel.get_bone_count()
	var prev_rots: Array[Quaternion] = []
	var max_ang_vel := 0.0
	var max_ang_bone := ""
	var snaps_over_25 := 0
	var max_hand_err := 0.0
	var hand_err_sum := 0.0
	var hand_err_samples := 0
	var min_head_dash_z := 999.0
	var frame_rows := {}

	var hand_l := skel.find_bone("hand.L")
	var hand_r := skel.find_bone("hand.R")
	var head_i := skel.find_bone("head")

	for frame in 17:
		if frame == 4:
			live.trigger_recoil(1.35)
		elif frame == 8:
			live.trigger_landing(1.25)
		if frame > 0:
			var vel := Vector3(3.5, 0.0, -16.0) if frame < 8 else Vector3(-2.0, -3.0, -14.0)
			var turn := 3.2 if frame < 8 else -2.0
			var aim := Vector3(0.55, 0.08, -0.82).normalized() if frame < 8 else Vector3(-0.35, 0.05, -0.92).normalized()
			var vacc := -16.0 if frame == 8 else 0.0
			live.step_motion(1.0 / 60.0, vel, turn, aim, vacc, 0.0)
		else:
			live.step_motion(1.0 / 60.0, Vector3.ZERO, 0.0, Vector3.FORWARD, 0.0, 0.0)

		skel.reset_bone_poses()
		live._process_modification()

		var frame_max_deg := 0.0
		var frame_max_bone := ""
		var cur_rots: Array[Quaternion] = []
		cur_rots.resize(bone_count)
		for bi in bone_count:
			var q := skel.get_bone_pose_rotation(bi)
			cur_rots[bi] = q
			if frame > 0:
				var d_deg := rad_to_deg(prev_rots[bi].angle_to(q))
				if d_deg > frame_max_deg:
					frame_max_deg = d_deg
					frame_max_bone = String(skel.get_bone_name(bi))
				if d_deg > MAX_FRAME_ANG_VEL_DEG:
					snaps_over_25 += 1
				if d_deg > max_ang_vel:
					max_ang_vel = d_deg
					max_ang_bone = String(skel.get_bone_name(bi))
		prev_rots = cur_rots

		var yxf := yoke_node.global_transform
		var grip_l_w := yxf * PilotGearKit.YOKE_GRIP_LOCAL_L
		var grip_r_w := yxf * PilotGearKit.YOKE_GRIP_LOCAL_R
		var hl_w := skel.global_transform * skel.get_bone_global_pose(hand_l).origin
		var hr_w := skel.global_transform * skel.get_bone_global_pose(hand_r).origin
		var err_l := hl_w.distance_to(grip_l_w)
		var err_r := hr_w.distance_to(grip_r_w)
		var err_max := maxf(err_l, err_r)
		max_hand_err = maxf(max_hand_err, err_max)
		hand_err_sum += (err_l + err_r) * 0.5
		hand_err_samples += 1

		var head_w := skel.global_transform * skel.get_bone_global_pose(head_i).origin
		var dash_w := gauges_node.global_transform.origin
		var clear_z := head_w.z - dash_w.z
		min_head_dash_z = minf(min_head_dash_z, clear_z)

		if frame in [0, 1, 2, 4, 8, 16]:
			frame_rows["t%d" % frame] = {
				"max_ang_vel_deg": snappedf(frame_max_deg, 0.01),
				"peak_bone": frame_max_bone,
				"hand_l_err_m": snappedf(err_l, 0.0005),
				"hand_r_err_m": snappedf(err_r, 0.0005),
				"head_dash_z_clearance_m": snappedf(clear_z, 0.001),
			}

	pod.free()
	return {
		"frames_total": 17,
		"max_bone_ang_vel_deg_per_frame": snappedf(max_ang_vel, 0.01),
		"max_bone_ang_vel_bone": max_ang_bone,
		"snaps_over_25deg": snaps_over_25,
		"zero_snaps_ok": snaps_over_25 == 0 and max_ang_vel <= MAX_FRAME_ANG_VEL_DEG,
		"max_hand_yoke_err_m": snappedf(max_hand_err, 0.0005),
		"mean_hand_yoke_err_m": snappedf(hand_err_sum / maxf(float(hand_err_samples), 1.0), 0.0005),
		"min_head_dash_z_clearance_m": snappedf(min_head_dash_z, 0.001),
		"sampled_frames": frame_rows,
	}


static func audit_scene(path: String, is_pilot: bool) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {"path": path, "missing": true}
	var packed := load(path) as PackedScene
	if packed == null:
		return {"path": path, "load_error": true}
	var inst := packed.instantiate()
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	var skeletons := inst.find_children("*", "Skeleton3D", true, false)
	var anims := inst.find_children("*", "AnimationPlayer", true, false)

	var tri_total := 0
	var vert_total := 0
	var surface_total := 0
	var boundary_edges := 0
	var shared_edges := 0
	var non_manifold_edges := 0
	var degenerate_tris := 0
	var inverted_normal_tris := 0
	var non_unit_normals := 0
	var has_uv := false
	var has_color := false
	var has_weights := false
	var skinned_verts := 0
	var weight_min_sum := 999.0
	var weight_max_sum := 0.0
	var weight_out_of_tol_verts := 0
	var zero_weight_verts := 0
	var invalid_bone_idx_verts := 0
	var skel_bone_count := (skeletons[0] as Skeleton3D).get_bone_count() if not skeletons.is_empty() else 0
	var aabb := AABB()
	var has_aabb := false

	for node in meshes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var m := mi.mesh
		var m_aabb := m.get_aabb()
		if not has_aabb:
			aabb = m_aabb
			has_aabb = true
		else:
			aabb = aabb.merge(m_aabb)
		for s in m.get_surface_count():
			surface_total += 1
			var arr := m.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms = arr[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			var uvs = arr[Mesh.ARRAY_TEX_UV]
			var cols = arr[Mesh.ARRAY_COLOR]
			var wts = arr[Mesh.ARRAY_WEIGHTS]
			var bns = arr[Mesh.ARRAY_BONES]
			vert_total += verts.size()
			if uvs is PackedVector2Array and (uvs as PackedVector2Array).size() == verts.size():
				has_uv = true
			if cols is PackedColorArray and (cols as PackedColorArray).size() == verts.size():
				has_color = true
			var has_norms: bool = norms is PackedVector3Array and (norms as PackedVector3Array).size() == verts.size()
			if has_norms:
				var nv: PackedVector3Array = norms
				for ni in nv.size():
					var n := nv[ni]
					if not n.is_finite() or absf(n.length() - 1.0) > 0.05:
						non_unit_normals += 1
			if wts is PackedFloat32Array and (wts as PackedFloat32Array).size() > 0 and verts.size() > 0:
				has_weights = true
				var wf: PackedFloat32Array = wts
				var bi_arr: PackedInt32Array = bns if bns is PackedInt32Array else PackedInt32Array()
				var influences := int(wf.size() / verts.size())
				if influences > 0:
					for vi in verts.size():
						skinned_verts += 1
						var wsum := 0.0
						var bad_idx := false
						var base := vi * influences
						for k in influences:
							var wv := wf[base + k]
							wsum += wv
							if wv > 1e-6 and base + k < bi_arr.size() and skel_bone_count > 0:
								var bidx := bi_arr[base + k]
								if bidx < 0 or bidx >= skel_bone_count:
									bad_idx = true
						weight_min_sum = minf(weight_min_sum, wsum)
						weight_max_sum = maxf(weight_max_sum, wsum)
						if wsum <= 1e-6:
							zero_weight_verts += 1
						if absf(wsum - 1.0) > WEIGHT_SUM_TOL:
							weight_out_of_tol_verts += 1
						if bad_idx:
							invalid_bone_idx_verts += 1

			var tri_n := int(floor(float(idx.size()) / 3.0)) if idx.size() > 0 else int(floor(float(verts.size()) / 3.0))
			tri_total += tri_n
			var edge_counts := {}
			for ti in tri_n:
				var i0 := idx[ti * 3] if idx.size() > 0 else ti * 3
				var i1 := idx[ti * 3 + 1] if idx.size() > 0 else ti * 3 + 1
				var i2 := idx[ti * 3 + 2] if idx.size() > 0 else ti * 3 + 2
				var v0 := verts[i0]
				var v1 := verts[i1]
				var v2 := verts[i2]
				var geo := (v2 - v0).cross(v1 - v0)
				if geo.length_squared() < 1e-12:
					degenerate_tris += 1
					continue
				if has_norms:
					var nv2: PackedVector3Array = norms
					var avg_n := nv2[i0] + nv2[i1] + nv2[i2]
					if avg_n.length_squared() > 1e-10 and geo.dot(avg_n) < 0.0:
						inverted_normal_tris += 1
				var k0 := _quant_key(v0)
				var k1 := _quant_key(v1)
				var k2 := _quant_key(v2)
				for pair in [[k0, k1], [k1, k2], [k2, k0]]:
					var a: String = pair[0]
					var b: String = pair[1]
					if a == b:
						continue
					var ek := (a + "|" + b) if a < b else (b + "|" + a)
					edge_counts[ek] = int(edge_counts.get(ek, 0)) + 1
			for ek in edge_counts:
				var cnt: int = edge_counts[ek]
				if cnt == 2:
					shared_edges += 1
				elif cnt == 1:
					boundary_edges += 1
				else:
					non_manifold_edges += 1

	var total_edges := shared_edges + boundary_edges + non_manifold_edges
	var manifold_ratio := float(shared_edges) / maxf(float(total_edges), 1.0)
	if skinned_verts == 0:
		weight_min_sum = 0.0
	var weights_norm_ok := skinned_verts > 0 and weight_out_of_tol_verts == 0 and zero_weight_verts == 0 and invalid_bone_idx_verts == 0

	var bone_names: Array[String] = []
	var rest_audit := {}
	if not skeletons.is_empty():
		var skel := skeletons[0] as Skeleton3D
		for bi in skel.get_bone_count():
			bone_names.append(String(skel.get_bone_name(bi)))
		if is_pilot:
			rest_audit = _audit_pilot_rest_pose(skel)

	var clip_names: Array[String] = []
	var idle_seam := {}
	var idle_ok := false
	if not anims.is_empty():
		var ap := anims[0] as AnimationPlayer
		for cn in ap.get_animation_list():
			clip_names.append(String(cn))
		if ap.has_animation("idle_loop"):
			idle_seam = _check_loop_seam(ap.get_animation("idle_loop"))
			idle_ok = bool(idle_seam.get("continuous", false))
		elif ap.has_animation("idle"):
			idle_seam = _check_loop_seam(ap.get_animation("idle"))
			idle_ok = bool(idle_seam.get("continuous", false))

	var control_nodes: Array[String] = []
	for cname in ["Pod", "Core", "WeaponRing", "Yoke", "GaugeLever", "Lever", "FusePlunger", "ClampLever", "PlateCrank", "Pedal_L", "Pedal_R"]:
		if inst.find_child(cname, true, false) != null:
			control_nodes.append(cname)

	inst.free()
	return {
		"path": path,
		"meshes": meshes.size(),
		"surfaces": surface_total,
		"vertices": vert_total,
		"triangles": tri_total,
		"degenerate_tris": degenerate_tris,
		"inverted_normal_tris": inverted_normal_tris,
		"non_unit_normals": non_unit_normals,
		"shared_edges": shared_edges,
		"boundary_edges": boundary_edges,
		"non_manifold_edges": non_manifold_edges,
		"manifold_edge_ratio": snappedf(manifold_ratio, 0.0001),
		"watertight": boundary_edges == 0 and non_manifold_edges == 0 and total_edges > 0,
		"has_uv": has_uv,
		"has_color": has_color,
		"has_weights": has_weights,
		"skinned_verts": skinned_verts,
		"weight_min_sum": snappedf(weight_min_sum, 0.00001),
		"weight_max_sum": snappedf(weight_max_sum, 0.00001),
		"weight_out_of_tol_verts": weight_out_of_tol_verts,
		"zero_weight_verts": zero_weight_verts,
		"invalid_bone_idx_verts": invalid_bone_idx_verts,
		"weights_normalized_ok": weights_norm_ok,
		"aabb_size": [snappedf(aabb.size.x, 0.001), snappedf(aabb.size.y, 0.001), snappedf(aabb.size.z, 0.001)],
		"bone_count": bone_names.size(),
		"bone_names": bone_names,
		"rest_pose": rest_audit,
		"clip_count": clip_names.size(),
		"idle_loop_continuous": idle_ok,
		"idle_seam": idle_seam,
		"control_nodes": control_nodes,
	}


static func _quant_key(v: Vector3) -> String:
	return "%d,%d,%d" % [int(round(v.x * WELD_QUANT)), int(round(v.y * WELD_QUANT)), int(round(v.z * WELD_QUANT))]


static func _audit_pilot_rest_pose(skel: Skeleton3D) -> Dictionary:
	skel.reset_bone_poses()
	var sym_pairs := [
		["shoulder.L", "shoulder.R"],
		["upper_arm.L", "upper_arm.R"],
		["lower_arm.L", "lower_arm.R"],
		["hand.L", "hand.R"],
		["ear.L", "ear.R"],
		["thigh.L", "thigh.R"],
	]
	var max_sym_err_m := 0.0
	var checked_pairs := 0
	for pair in sym_pairs:
		var bl := skel.find_bone(String(pair[0]))
		var br := skel.find_bone(String(pair[1]))
		if bl < 0 or br < 0:
			continue
		checked_pairs += 1
		var pl := skel.get_bone_global_rest(bl).origin
		var pr := skel.get_bone_global_rest(br).origin
		var mirrored := Vector3(-pl.x, pl.y, pl.z)
		max_sym_err_m = maxf(max_sym_err_m, mirrored.distance_to(pr))

	var head_idx := skel.find_bone("head")
	var pelvis_idx := skel.find_bone("pelvis")
	if pelvis_idx < 0:
		pelvis_idx = skel.find_bone("root")
	var head_y := skel.get_bone_global_rest(head_idx).origin.y if head_idx >= 0 else 0.0
	var pelvis_y := skel.get_bone_global_rest(pelvis_idx).origin.y if pelvis_idx >= 0 else 0.0
	var head_x := skel.get_bone_global_rest(head_idx).origin.x if head_idx >= 0 else 0.0

	var u_l := skel.find_bone("upper_arm.L")
	var l_l := skel.find_bone("lower_arm.L")
	var arm_angle_deg := 0.0
	var rest_pose_kind := "seated_cockpit_rest"
	if u_l >= 0 and l_l >= 0:
		var arm_v := (skel.get_bone_global_rest(l_l).origin - skel.get_bone_global_rest(u_l).origin).normalized()
		arm_angle_deg = rad_to_deg(acos(clampf(absf(arm_v.x), 0.0, 1.0)))
		if arm_angle_deg < 20.0:
			rest_pose_kind = "canonical_t_pose"
		elif arm_angle_deg < 55.0:
			rest_pose_kind = "a_pose"

	var anchors := {}
	for bn in ["pelvis", "spine_01", "spine_02", "neck", "head", "goggles", "snout", "ear.L", "ear.R", "crest", "shoulder.L", "shoulder.R", "hand.L", "hand.R", "tail.01"]:
		var bi := skel.find_bone(bn)
		if bi >= 0:
			var o := skel.get_bone_global_rest(bi).origin
			anchors[bn] = [snappedf(o.x, 0.001), snappedf(o.y, 0.001), snappedf(o.z, 0.001)]

	return {
		"checked_symmetry_pairs": checked_pairs,
		"max_lr_symmetry_err_m": snappedf(max_sym_err_m, 0.0005),
		"head_centered_x_m": snappedf(absf(head_x), 0.0005),
		"spine_height_m": snappedf(head_y - pelvis_y, 0.001),
		"upper_arm_from_horizontal_deg": snappedf(arm_angle_deg, 0.2),
		"rest_pose_kind": rest_pose_kind,
		"symmetric_ok": max_sym_err_m <= 0.015 and absf(head_x) <= 0.015,
		"anchors": anchors,
	}


static func _check_loop_seam(anim: Animation) -> Dictionary:
	var max_pos_m := 0.0
	var max_rot_deg := 0.0
	var tracks := 0
	for i in anim.get_track_count():
		var ty := anim.track_get_type(i)
		if ty == Animation.TYPE_POSITION_3D:
			tracks += 1
			var a := anim.position_track_interpolate(i, 0.0)
			var b := anim.position_track_interpolate(i, anim.length)
			max_pos_m = maxf(max_pos_m, a.distance_to(b))
		elif ty == Animation.TYPE_ROTATION_3D:
			tracks += 1
			var qa := anim.rotation_track_interpolate(i, 0.0)
			var qb := anim.rotation_track_interpolate(i, anim.length)
			max_rot_deg = maxf(max_rot_deg, rad_to_deg(qa.angle_to(qb)))
	return {
		"length_s": snappedf(anim.length, 0.001),
		"loop_mode": anim.loop_mode,
		"tracks": tracks,
		"max_pos_gap_m": snappedf(max_pos_m, 0.0005),
		"max_rot_gap_deg": snappedf(max_rot_deg, 0.01),
		"continuous": anim.loop_mode != Animation.LOOP_NONE and max_pos_m <= LOOP_POS_TOL_M and max_rot_deg <= LOOP_ROT_TOL_DEG,
	}


static func scan_greybox_primitives(root_dir: String) -> Dictionary:
	var patterns := ["BoxMesh.new(", "CylinderMesh.new(", "SphereMesh.new(", "PrismMesh.new(", "CapsuleMesh.new("]
	var by_file := {}
	var total := 0
	var stack := [root_dir]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not entry.begins_with("."):
				var full := dir_path.path_join(entry)
				if dir.current_is_dir():
					stack.append(full)
				elif entry.ends_with(".gd"):
					var text := FileAccess.get_file_as_string(full)
					var count := 0
					for line in text.split("\n"):
						var trimmed := line.strip_edges()
						if trimmed.begins_with("#"):
							continue
						for pat in patterns:
							if trimmed.contains(pat):
								count += 1
					if count > 0:
						by_file[full] = count
						total += count
			entry = dir.get_next()
		dir.list_dir_end()
	return {"total_sites": total, "by_file": by_file}


func _print_tables(report: Dictionary) -> void:
	print("\n--- PILOTS (RAW GLB SKIN WEIGHTS, MANIFOLD, NORMALS, LOOP SEAM) ---")
	for cid in report.pilots:
		var p: Dictionary = report.pilots[cid]
		var rp: Dictionary = p.get("rest_pose", {})
		var ls: Dictionary = p.get("idle_seam", {})
		print("%s | tris=%d degen=%d invN=%d bones=%d manifold=%.4f (bound=%d nonman=%d) wsum=[%.5f..%.5f] outTol=%d zeroW=%d badIdx=%d sym=%.4fm arm=%.1fdeg (%s) idle_gap=%.2fdeg/%.4fm cont=%s" % [
			cid, int(p.triangles), int(p.degenerate_tris), int(p.inverted_normal_tris), int(p.bone_count),
			float(p.manifold_edge_ratio), int(p.boundary_edges), int(p.non_manifold_edges),
			float(p.weight_min_sum), float(p.weight_max_sum), int(p.weight_out_of_tol_verts),
			int(p.zero_weight_verts), int(p.invalid_bone_idx_verts),
			float(rp.get("max_lr_symmetry_err_m", 0.0)), float(rp.get("upper_arm_from_horizontal_deg", 0.0)),
			String(rp.get("rest_pose_kind", "")), float(ls.get("max_rot_gap_deg", 0.0)),
			float(ls.get("max_pos_gap_m", 0.0)), str(p.idle_loop_continuous)
		])
	print("BONES: ", JSON.stringify(report.pilot_bone_census))
	print("\n--- PILOT GEAR KIT (PROCEDURAL ARRAYMESH TOPOLOGY) ---")
	for gid in report.pilot_gear_kit:
		var g: Dictionary = report.pilot_gear_kit[gid]
		print("%s | tris=%d bound=%d nonman=%d degen=%d invN=%d outward=%.4f watertight=%s" % [
			gid, int(g.triangles), int(g.boundary_edges), int(g.non_manifold_edges),
			int(g.degenerate_tris), int(g.inverted_normals), float(g.outward_ratio), str(g.watertight)
		])
	if not (report.motion_60hz as Dictionary).is_empty():
		print("\n--- 60 HZ LIVE MOTION STRIP (t=0..16, ZERO-SNAP & HAND-YOKE REGISTRATION) ---")
		for cid in report.motion_60hz:
			var m: Dictionary = report.motion_60hz[cid]
			print("%s | max_vel=%.2fdeg/f (%s) snaps>25=%d hand_err_max=%.4fm mean=%.4fm head_dash_clear=%.3fm ok=%s" % [
				cid, float(m.max_bone_ang_vel_deg_per_frame), String(m.max_bone_ang_vel_bone),
				int(m.snaps_over_25deg), float(m.max_hand_yoke_err_m), float(m.mean_hand_yoke_err_m),
				float(m.min_head_dash_z_clearance_m), str(m.zero_snaps_ok)
			])
	print("\n--- SHELLS & WEAPONS ---")
	for cid in report.shells:
		var s: Dictionary = report.shells[cid]
		print("shell:%s | tris=%d manifold=%.4f bound=%d controls=%s" % [cid, int(s.triangles), float(s.manifold_edge_ratio), int(s.boundary_edges), str(s.control_nodes)])
	for cid in report.weapons:
		var w: Dictionary = report.weapons[cid]
		print("weapon:%s | tris=%d bones=%d manifold=%.4f bound=%d" % [cid, int(w.triangles), int(w.bone_count), float(w.manifold_edge_ratio), int(w.boundary_edges)])
	print("\n--- ENEMIES (sample summary) ---")
	for k in report.enemies:
		var e: Dictionary = report.enemies[k]
		print("%s | tris=%d bones=%d manifold=%.4f bound=%d nonman=%d clips=%d" % [k, int(e.triangles), int(e.bone_count), float(e.manifold_edge_ratio), int(e.boundary_edges), int(e.non_manifold_edges), int(e.clip_count)])
	print("\n--- GREYBOX PRIMITIVES IN src/ ---")
	print("total=%d files=%s" % [int(report.greybox.total_sites), JSON.stringify(report.greybox.by_file)])
