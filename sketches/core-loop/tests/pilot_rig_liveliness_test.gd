extends SceneTree

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const PilotGlance := preload("res://src/presentation/pilot_glance.gd")
const PilotReactions := preload("res://src/presentation/pilot_reactions.gd")
const PilotLiveliness := preload("res://src/presentation/pilot_liveliness.gd")
const PilotGearKit := preload("res://src/presentation/pilot_gear_kit.gd")
const AuditTool := preload("res://tools/asset_rig_craft_audit.gd")

var failed := false
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	failed = failed or not ok
	print(what, " -> ", "PASS" if ok else "FAIL")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_check_no_raw_primitives_in_gear_kit()
	_check_gear_kit_watertight_and_masks()
	_check_rig_audit_across_all_six_pilots()
	await _check_liveliness_motion_and_controls()
	await _check_glance_and_reactions_compatibility()
	print("pilot_rig_liveliness_test: ", "FAIL" if failed else "PASS", " (%d checks)" % checks)
	quit(1 if failed else 0)


func _check_no_raw_primitives_in_gear_kit() -> void:
	var src := FileAccess.get_file_as_string("res://src/presentation/pilot_gear_kit.gd")
	check(src.length() > 1000, "pilot_gear_kit.gd source readable")
	var forbidden := ["BoxMesh", "CylinderMesh", "SphereMesh", "CapsuleMesh", "TorusMesh", "PrismMesh", "PlaneMesh"]
	var clean := true
	for prim in forbidden:
		if src.contains(prim):
			clean = false
	check(clean, "zero raw primitive Mesh fallbacks in pilot_gear_kit.gd")
	check(PilotGearKit.GEAR_IDS.size() == 6, "PilotGearKit exposes 6 crafted wearable and cockpit gear pieces")


func _check_gear_kit_watertight_and_masks() -> void:
	for gear_id in PilotGearKit.GEAR_IDS:
		var mesh := PilotGearKit.build_gear(gear_id)
		var stats := PilotGearKit.inspect_mesh_watertight(mesh)
		var label := String(gear_id)
		check(stats.triangles >= 120 and stats.surfaces >= 2, "%s builds multi-surface sculpted ArrayMesh (%d tris, %d surfaces)" % [label, stats.triangles, stats.surfaces])
		check(stats.watertight and stats.boundary_edges == 0 and stats.non_manifold_edges == 0 and stats.degenerate_tris == 0, "%s is 100%% watertight manifold (bound=%d, nonman=%d, degen=%d)" % [label, stats.boundary_edges, stats.non_manifold_edges, stats.degenerate_tris])
		check(stats.outward_ratio > 0.995 and stats.finite_ok and stats.uv_ok and stats.tangent_ok, "%s has outward winding (%.4f), finite unit normals, UVs, and tangents" % [label, stats.outward_ratio])
		check(stats.r_low_ratio >= 0.08 and stats.r_high_ratio >= 0.15, "%s COLOR.r edge wear spans flat interiors (%.2f) and bright bevels (%.2f)" % [label, stats.r_low_ratio, stats.r_high_ratio])
		check(stats.g_low_ratio >= 0.10 and stats.g_high_ratio >= 0.08, "%s COLOR.g cavity grime spans exposed faces (%.2f) and recesses (%.2f)" % [label, stats.g_low_ratio, stats.g_high_ratio])
		if gear_id == PilotGearKit.GEAR_GOGGLES or gear_id == PilotGearKit.GEAR_GAUGES:
			check(stats.b_high_ratio > 0.005 and stats.b_zero_ratio >= 0.72, "%s COLOR.b emissive strictly localized to working lenses/dials (%.3f)" % [label, stats.b_high_ratio])
		else:
			check(stats.b_high_ratio == 0.0, "%s non-emissive hardware keeps COLOR.b == 0.0" % label)


func _check_rig_audit_across_all_six_pilots() -> void:
	var report := AuditTool.run_audit(root)
	var s: Dictionary = report.summary
	check(int(s.pilots_audited) == 6 and int(s.pilots_with_25_bones) == 6, "all 6 pilot GLBs audit cleanly with 25-bone canonical skeleton")
	check(int(s.pilots_with_continuous_idle_loop) == 6, "all 6 pilot GLBs have continuous seamless idle_loop")
	check(int(s.pilots_with_normalized_skin_weights) == 6, "all 6 pilot GLBs have normalized skin weights (sum == 1.0 +- 1e-4, 0 invalid bones)")
	check(float(s.pilot_mean_manifold_edge_ratio) >= 0.99, "pilot mean manifold edge ratio >= 0.99 (%.4f)" % float(s.pilot_mean_manifold_edge_ratio))
	check(int(s.gear_kit_watertight) == 6 and int(s.gear_kit_total) == 6, "all 6 PilotGearKit procedural meshes audit 100%% watertight")
	check(int(s.motion_60hz_audited) == 6 and int(s.motion_60hz_zero_snaps) == 6, "all 6 pilots pass 60 Hz 17-frame motion strip with zero snaps (worst=%.2f deg/f)" % float(s.motion_60hz_worst_ang_vel_deg))
	check(int(s.shells_audited) == 6 and int(s.weapons_audited) == 2 and int(s.enemies_audited) >= 16, "shells (6), weapons (2), and World 1 enemies (%d) audited" % int(s.enemies_audited))
	for cid in report.pilots:
		var p: Dictionary = report.pilots[cid]
		var rp: Dictionary = p.rest_pose
		check(bool(rp.symmetric_ok) and float(rp.max_lr_symmetry_err_m) <= 0.005, "%s rest pose has bilateral symmetry (err=%.4fm)" % [cid, float(rp.max_lr_symmetry_err_m)])
		check(bool(p.weights_normalized_ok) and int(p.weight_out_of_tol_verts) == 0 and int(p.invalid_bone_idx_verts) == 0, "%s raw GLB skin weights normalized ([%.5f..%.5f], badIdx=%d)" % [cid, float(p.weight_min_sum), float(p.weight_max_sum), int(p.invalid_bone_idx_verts)])
	for cid in report.motion_60hz:
		var m: Dictionary = report.motion_60hz[cid]
		check(bool(m.zero_snaps_ok) and float(m.max_bone_ang_vel_deg_per_frame) <= 25.0, "%s 60 Hz angular velocity within 25 deg/f ceiling (%.2f deg/f on %s)" % [cid, float(m.max_bone_ang_vel_deg_per_frame), String(m.max_bone_ang_vel_bone)])
		check(float(m.max_hand_yoke_err_m) <= 0.015 and float(m.min_head_dash_z_clearance_m) > 0.05, "%s 60 Hz 2-bone IK hand-yoke lock (max=%.4fm) and head-dash clearance (min=%.3fm)" % [cid, float(m.max_hand_yoke_err_m), float(m.min_head_dash_z_clearance_m)])


func _check_liveliness_motion_and_controls() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var painter := HeroAssets.new()
	stage.add_child(painter)

	for class_id in HeroAssets.PILOTS:
		var pod := Node3D.new()
		stage.add_child(pod)
		var fitted: Dictionary = painter.fit_pilot_into(pod, class_id, Color.WHITE)
		var pilot: Node3D = fitted.pilot
		var skel := pilot.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var live = PilotLiveliness.attach(pilot, class_id)
		live.reduced_motion_override = 0
		var wearables := PilotGearKit.mount_pilot_wearables(pilot)
		var cockpit := PilotGearKit.mount_cockpit_rig(pod)
		live.bind_cockpit_controls(cockpit)
		await process_frame

		check(wearables.size() == 3 and cockpit.has("yoke") and cockpit.has("gauges"), "%s mounts all 3 wearables and cockpit controls cleanly" % class_id)

		skel.reset_bone_poses()
		var spine2 := skel.find_bone("spine_02")
		var head := skel.find_bone("head")
		var ear_l := skel.find_bone("ear.L")
		var rest_spine := skel.get_bone_pose_rotation(spine2)
		var rest_head := skel.get_bone_pose_rotation(head)
		var rest_ear := skel.get_bone_pose_rotation(ear_l)

		for _i in 38:
			live.step_motion(1.0 / 60.0, Vector3.ZERO, 0.0, Vector3.FORWARD, 0.0, 0.0)
		skel.reset_bone_poses()
		live._process_modification()
		var breath_delta := rest_spine.angle_to(skel.get_bone_pose_rotation(spine2))
		check(breath_delta > 0.015, "%s breathing animates spine_02 cleanly (%.4f rad)" % [class_id, breath_delta])

		var yoke_rest: Transform3D = (cockpit.yoke as Node3D).transform
		live.reset_state()
		for _i in 45:
			live.step_motion(1.0 / 60.0, Vector3(4.0, 0.0, -18.0), 3.6, Vector3(0.65, 0.10, -0.75).normalized(), 0.0, 0.0)
		skel.reset_bone_poses()
		live._process_modification()
		var head_delta := rest_head.angle_to(skel.get_bone_pose_rotation(head))
		var ear_delta := rest_ear.angle_to(skel.get_bone_pose_rotation(ear_l))
		var yoke_roll := absf((cockpit.yoke as Node3D).rotation.z - yoke_rest.basis.get_euler().z)
		check(head_delta > 0.12 and ear_delta > 0.03 and yoke_roll > 0.08, "%s high-G bank drives head look-ahead (%.3f), secondary ear/crest (%.3f), and yoke roll (%.3f)" % [class_id, head_delta, ear_delta, yoke_roll])

		live.reset_state()
		var reacted: bool = live.trigger_reaction("shot_fired")
		for _i in 5:
			live.step_motion(1.0 / 60.0, Vector3.ZERO, 0.0, Vector3.FORWARD, 0.0, 0.0)
		var peak_recoil := absf(float(live.snapshot().recoil))
		for _i in 45:
			live.step_motion(1.0 / 60.0, Vector3.ZERO, 0.0, Vector3.FORWARD, 0.0, 0.0)
		var settled_recoil := absf(float(live.snapshot().recoil))
		check(reacted and peak_recoil > 0.04 and settled_recoil < peak_recoil * 0.25, "%s weapon recoil impulse peaks (%.3f) and settles cleanly (%.4f)" % [class_id, peak_recoil, settled_recoil])

		live.reduced_motion_override = 1
		live.trigger_recoil(1.5)
		live.trigger_landing(1.5)
		for _i in 35:
			live.step_motion(1.0 / 60.0, Vector3(4.0, -3.0, -18.0), 3.2, Vector3(0.5, 0.1, -0.85).normalized(), -18.0, 0.0)
		skel.reset_bone_poses()
		live._process_modification()
		var rm_spine := rest_spine.angle_to(skel.get_bone_pose_rotation(spine2))
		check(rm_spine < 0.0001 and (cockpit.yoke as Node3D).transform.is_equal_approx(yoke_rest), "%s reduced_motion leaves skeleton and cockpit neutral" % class_id)

		pod.free()

	painter.free()
	stage.free()


func _check_glance_and_reactions_compatibility() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var painter := HeroAssets.new()
	stage.add_child(painter)
	var pod := Node3D.new()
	stage.add_child(pod)
	var fitted: Dictionary = painter.fit_pilot_into(pod, "pylon_engineer", Color.WHITE)
	var glance := PilotGlance.seat(fitted.pilot, "pylon_engineer")
	check(glance != null and glance.get_parent() is Skeleton3D, "PilotGlance.seat() seats cleanly on Skeleton3D")
	var live = glance.call("liveliness")
	await process_frame
	check(live != null and live.get_parent() == glance.get_parent(), "PilotGlance.seat() attaches sibling PilotLiveliness on same skeleton")
	check(live.get_index() < glance.get_index(), "PilotLiveliness evaluates before PilotGlance so glance twists cleanly on top")
	live.reduced_motion_override = 0
	var skel := glance.get_parent() as Skeleton3D
	var behind_right := skel.global_transform * Vector3(2.0, 1.0, 6.0)
	for _i in int((PilotGlance.FIRST_AFTER + 0.6) * 60.0):
		glance.observe(true, behind_right, 1.0 / 60.0)
	check(glance.turn > 0.8 and live.glance_blend > 0.8, "PilotGlance.observe() drives glance turn and yields PilotLiveliness look-ahead")
	check(not PilotReactions.impulse_for("player_hit").is_empty() and not PilotReactions.impulse_for("drop_landed").is_empty(), "PilotReactions exposes reaction impulse table for liveliness")
	pod.free()
	painter.free()
	stage.free()
