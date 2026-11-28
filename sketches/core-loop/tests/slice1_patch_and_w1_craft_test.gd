extends SceneTree


const T := preload("res://tests/support/t.gd")
const AuditTool := preload("res://tools/asset_rig_craft_audit.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const BallLooks := preload("res://src/presentation/ball_looks.gd")
const PilotGlance := preload("res://src/presentation/pilot_glance.gd")
const PilotLiveliness := preload("res://src/presentation/pilot_liveliness.gd")
const PilotGearKit := preload("res://src/presentation/pilot_gear_kit.gd")
const CraftedBallGear := preload("res://src/presentation/crafted_ball_gear.gd")
const WeaponRigFx := preload("res://src/presentation/weapon_rig_fx.gd")
const PropMeshes := preload("res://src/presentation/craft_prop_meshes.gd")
const SpillwayScenery := preload("res://src/presentation/spillway_scenery.gd")
const ShowcaseAssembly := preload("res://src/presentation/craft/craft_showcase_assembly.gd")
const ArenaBowlYard := preload("res://src/presentation/arena_bowl_yard.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const Palette := preload("res://src/core/palette.gd")

const PATCH_COLOR := Color("ea7fa0")

var _t := T.new("slice1_patch_and_w1_craft_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_check_patch_pilot_rig_and_clips()
	await _check_patch_liveliness_and_60hz_strip()
	await _check_patch_shell_and_weapon_rig()
	_check_world1_craft_meshes_and_materials()
	_check_source_zero_greybox_invariants()
	_check_showcase_gantry_and_yard_upgrades()
	ShowcaseAssembly.reset_for_tests()
	PropMeshes.reset_for_tests()
	CraftedBallGear.clear_cache()
	WeaponRigFx.clear_cache()
	quit(_t.verdict())


func _check_patch_pilot_rig_and_clips() -> void:
	var p := AuditTool.audit_scene("res://assets/models/pilot_patch_anim.glb", true)
	_t.check("pilot_patch_anim.glb loads without error", not p.get("missing", false) and not p.get("load_error", false), str(p))
	_t.eq("pilot_patch_anim.glb has 4 meshes (Pilot, TailBase, TailTip, Tool)", int(p.get("meshes", 0)), 4)
	_t.eq("pilot_patch_anim.glb has canonical 25-bone skeleton", int(p.get("bone_count", 0)), 25)
	_t.eq("pilot_patch_anim.glb has 8 animation clips", int(p.get("clip_count", 0)), 8)
	_t.check("pilot_patch_anim.glb is 100% watertight closed manifold",
		bool(p.get("watertight", false)) and int(p.get("boundary_edges", 1)) == 0
		and int(p.get("non_manifold_edges", 1)) == 0 and int(p.get("degenerate_tris", 1)) == 0
		and int(p.get("inverted_normal_tris", 1)) == 0 and int(p.get("non_unit_normals", 1)) == 0,
		str(p))
	_t.check("pilot_patch_anim.glb has normalized skin weights (sum == 1.0 +- 1e-4)",
		bool(p.get("weights_normalized_ok", false)) and int(p.get("weight_out_of_tol_verts", 1)) == 0
		and int(p.get("zero_weight_verts", 1)) == 0 and int(p.get("invalid_bone_idx_verts", 1)) == 0,
		str(p))
	var rp: Dictionary = p.get("rest_pose", {})
	_t.check("pilot_patch_anim.glb rest pose has bilateral symmetry <= 0.005m",
		bool(rp.get("symmetric_ok", false)) and float(rp.get("max_lr_symmetry_err_m", 1.0)) <= 0.005,
		str(rp))
	_t.check("pilot_patch_anim.glb has seamless continuous idle_loop", bool(p.get("idle_loop_continuous", false)), str(p.get("idle_seam", {})))

	var inst := (load("res://assets/models/pilot_patch_anim.glb") as PackedScene).instantiate()
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var want_clips := ["idle_loop", "brace", "drop_land", "heave", "big_cheer", "phew", "slump", "wince"]
	for clip in want_clips:
		_t.check("pilot_patch_anim has clip %s" % clip, ap != null and ap.has_animation(clip), clip)
	inst.free()


func _check_patch_liveliness_and_60hz_strip() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var painter := HeroAssets.previewing()
	stage.add_child(painter)

	var strip := AuditTool.audit_60hz_motion_strip(stage, painter, "line_splicer")
	_t.check("Patch 60Hz motion strip has zero bone snaps (<= 25 deg/frame)",
		bool(strip.get("zero_snaps_ok", false)) and float(strip.get("max_bone_ang_vel_deg_per_frame", 99.0)) <= 25.0,
		str(strip))
	_t.check("Patch 60Hz 2-bone IK locks hands to yoke (<= 0.015m) and clears dash (> 0.05m)",
		float(strip.get("max_hand_yoke_err_m", 1.0)) <= 0.015 and float(strip.get("min_head_dash_z_clearance_m", 0.0)) > 0.05,
		str(strip))

	var pod := Node3D.new()
	stage.add_child(pod)
	var fitted: Dictionary = painter.fit_pilot_into(pod, "line_splicer", PATCH_COLOR)
	_t.check("HeroAssets.fit_pilot_into seats line_splicer cleanly", not fitted.is_empty() and fitted.pilot != null, str(fitted.keys()))
	var anim: AnimationPlayer = fitted.animator
	_t.check("fit_pilot_into configures idle_loop as linear looping",
		anim != null and anim.get_animation("idle_loop").loop_mode == Animation.LOOP_LINEAR)

	var glance := PilotGlance.seat(fitted.pilot, "line_splicer")
	var live = glance.call("liveliness")
	await process_frame
	_t.check("PilotLiveliness has dedicated line_splicer species profile",
		PilotLiveliness.SPECIES_PROFILES.has("line_splicer") and live != null and live.get("pilot_class") == "line_splicer")

	var wear_no_dup := PilotGearKit.mount_pilot_wearables(fitted.pilot, PATCH_COLOR, true)
	_t.check("PilotGearKit skip_existing_goggles avoids duplicate forehead goggles on goggled pilots",
		wear_no_dup.size() == 2 and not wear_no_dup.has("goggles") and wear_no_dup.has("harness") and wear_no_dup.has("belt"),
		str(wear_no_dup.keys()))
	for ba in wear_no_dup.values():
		var mi := (ba as Node).get_node_or_null("Mesh") as MeshInstance3D
		var sm := mi.get_surface_override_material(0) as StandardMaterial3D if mi != null else null
		_t.check("PilotGearKit wearable surface uses weathered triplanar texture", sm != null and sm.albedo_texture != null)

	pod.free()
	painter.free()
	stage.free()


func _check_patch_shell_and_weapon_rig() -> void:
	var s := AuditTool.audit_scene("res://assets/models/world_one/shell_patch.glb", false)
	_t.check("shell_patch.glb is 100% watertight closed manifold within budget",
		bool(s.get("watertight", false)) and int(s.get("boundary_edges", 1)) == 0
		and int(s.get("non_manifold_edges", 1)) == 0 and int(s.get("inverted_normal_tris", 1)) == 0
		and int(s.get("triangles", 99999)) <= 6500 and int(s.get("surfaces", 99)) <= 10,
		str(s))

	var raw_shell := (load("res://assets/models/world_one/shell_patch.glb") as PackedScene).instantiate()
	for sub_name in ["Core", "Pod", "Dome", "PilotSeat", "Gyro", "GyroInner", "SpliceDish", "CableSpool", "WeaponRing", "RopeExit"]:
		_t.check("shell_patch contains sub-assembly %s" % sub_name, raw_shell.find_child(sub_name, true, false) != null, sub_name)
	raw_shell.free()

	var stage := Node3D.new()
	root.add_child(stage)
	var painter := HeroAssets.previewing()
	stage.add_child(painter)
	var ball := Node3D.new()
	stage.add_child(ball)

	var rec: Dictionary = painter.fit_shell_into(ball, "line_splicer", "", 1, {"class": PATCH_COLOR})
	_t.check("HeroAssets.fit_shell_into mounts line_splicer shell", not rec.is_empty() and rec.has("core") and rec.has("pod"))
	var pod: Node3D = rec.pod
	var core: Node3D = rec.core
	var fitted: Dictionary = painter.fit_pilot_into(pod, "line_splicer", PATCH_COLOR)
	_t.check("Patch pilot seats inside shell_patch Pod without hiding SpliceDish or CableSpool",
		not fitted.is_empty() and pod.get_node_or_null("SpliceDish") != null and pod.get_node_or_null("CableSpool") != null)

	for hc in [1, 2, 3, 4, 5]:
		painter.set_heft_class(rec, hc, false)
	_t.eq("shell_patch cycles cleanly across heft classes 1..5", int(rec.get("heft", 0)), 5)

	BallLooks.dress("cutaway", rec)
	var gyro := pod.get_node_or_null("Gyro") as Node3D
	core.rotation = Vector3(0.35, 0.25, 0.0)
	await process_frame
	HeroAssets.counter_tilt(pod, gyro, core)
	_t.check("shell_patch Gyro and GyroInner counter-tilt cleanly",
		gyro != null and absf(gyro.rotation.x) > 0.1 and absf((gyro.get_node("GyroInner") as Node3D).rotation.y) > 0.1)

	var mods := WeaponRigFx.mods_for(0, ["splice"])
	_t.check("WeaponRigFx maps splice tag to chain_arc prongs", mods.has("chain_arc"), str(mods))
	var ring := pod.get_node_or_null("WeaponRing") as Node3D
	var wrig = WeaponRigFx.ensure_on(ring)
	wrig.set_build_mods(0, ["kinetic", "splice", "frost", "split", "spiral"])
	wrig.on_shot_fired("charged", 1.2)
	wrig.step(1.0 / 60.0, {}, false)
	_t.check("WeaponRigFx mounts all 5 mods on shell_patch WeaponRing cleanly", wrig.active_mods().size() == 5 and wrig.recoil_offset() > 0.0)

	var splice_part := CraftedBallGear.part_mesh("splice_tap", "class")
	_t.check("CraftedBallGear builds splice_tap class mesh", splice_part != null and splice_part.get_surface_count() > 0)

	var cue_ring := PropMeshes.air_cue_ring(HeroAssets.AIR_CUE_RADIUS)
	_t.check("HeroAssets air_cue ring is sculpted ArrayMesh", cue_ring is ArrayMesh and cue_ring.get_faces().size() >= 96)

	ball.free()
	painter.free()
	stage.free()


func _check_world1_craft_meshes_and_materials() -> void:
	var crafted := {
		"mend_ward_monolith": PropMeshes.mend_ward_monolith(Vector3(0.9, 2.4, 0.9)),
		"survey_stake_pole": PropMeshes.survey_stake_pole(3.2),
		"survey_pennant_plate": PropMeshes.survey_pennant_plate(),
		"weighbridge_plate": PropMeshes.weighbridge_plate(Vector3(8.0, 0.12, 4.0)),
		"furnace_smoke_wisp": PropMeshes.furnace_smoke_wisp(),
		"bay_bell_mesh": PropMeshes.bay_bell_mesh(),
		"bay_mug_mesh": PropMeshes.bay_mug_mesh(0.2, 0.22, 0.4),
		"bay_marble_orb": PropMeshes.bay_marble_orb(0.22),
		"bay_pin_mesh": PropMeshes.bay_pin_mesh(),
		"bay_part_trophy": PropMeshes.bay_part_trophy(),
		"gantry_column_mesh": PropMeshes.gantry_column_mesh(1.8, 27.0, 1.8),
		"cantilever_gusset_bracket": PropMeshes.cantilever_gusset_bracket(),
	}
	for label in crafted:
		var m: ArrayMesh = crafted[label]
		_t.check("%s is non-empty ArrayMesh with UVs and normals" % label,
			m != null and m.get_surface_count() == 1 and m.get_faces().size() >= 36,
			label)
	_t.check("survey_stake_pole exceeds 3.0m height contract", crafted["survey_stake_pole"].get_aabb().size.y > 3.0)
	var smoke_mat := PropMeshes.furnace_smoke_material()
	_t.check("furnace_smoke_material uses rim-faded unshaded ShaderMaterial",
		smoke_mat is ShaderMaterial and smoke_mat.shader != null and smoke_mat.shader.code.contains("fog_disabled"))

	var dest := Destructibles.new()
	root.add_child(dest)
	dest.build([{"id": "d1", "tier": 2, "at": Vector3(0, 1.5, 0), "size": Vector3(2, 3, 4)}], {"root": root, "cruise": 14.0})
	dest.finish_build()
	var dmat := dest.material()
	_t.check("Destructibles material uses weathered triplanar plate texture",
		dmat != null and dmat.albedo_texture != null and dmat.uv1_triplanar and dmat.vertex_color_use_as_albedo)
	dest.teardown()
	dest.free()

	var stage_root := Node3D.new()
	root.add_child(stage_root)
	var scenery := SpillwayScenery.build(stage_root)
	var dam_detail := scenery.get_node_or_null("DamDetail") as MeshInstance3D
	if dam_detail != null and dam_detail.mesh != null and dam_detail.mesh.get_surface_count() > 0:
		var dsm := dam_detail.mesh.surface_get_material(0) as StandardMaterial3D
		_t.check("SpillwayScenery DamDetail uses weathered triplanar texture", dsm != null and dsm.albedo_texture != null and dsm.uv1_triplanar)
	stage_root.free()


func _check_source_zero_greybox_invariants() -> void:
	var zero_prim_files := [
		"res://src/world/survey_posts.gd",
		"res://src/world/bowl_approach.gd",
		"res://src/world/bay.gd",
		"res://src/world/activities.gd",
	]
	var prim_tokens := ["BoxMesh.new()", "CylinderMesh.new()", "SphereMesh.new()", "PrismMesh.new()", "TorusMesh.new()", "CapsuleMesh.new()", "PaletteMaterials.striped("]
	for path in zero_prim_files:
		var src := FileAccess.get_file_as_string(path)
		var hits: Array[String] = []
		for tok in prim_tokens:
			if src.contains(tok):
				hits.append(tok)
		_t.check("%s has zero primitive Mesh.new() or PaletteMaterials.striped calls" % path.get_file(), hits.is_empty(), str(hits))

	var bay_src := FileAccess.get_file_as_string("res://src/world/bay.gd")
	_t.check("bay.gd has zero flat PaletteMaterials.solid calls", not bay_src.contains("PaletteMaterials.solid("))

	var spill_src := FileAccess.get_file_as_string("res://src/presentation/spillway_scenery.gd")
	_t.check("spillway_scenery.gd has zero BoxMesh.new() or SphereMesh.new()",
		not spill_src.contains("BoxMesh.new()") and not spill_src.contains("SphereMesh.new()"))

	var hero_src := FileAccess.get_file_as_string("res://src/presentation/hero_assets.gd")
	_t.check("hero_assets.gd has zero BoxMesh.new() or TorusMesh.new()",
		not hero_src.contains("BoxMesh.new()") and not hero_src.contains("TorusMesh.new()"))


func _check_showcase_gantry_and_yard_upgrades() -> void:
	var yard := ArenaBowlYard.new()
	var stands := MeshInstance3D.new()
	stands.name = "FleetStands"
	var stands_mesh := PropMeshes.bevel_prop_box(Vector3(2.0, 1.0, 2.0))
	var raw_mat := StandardMaterial3D.new()
	raw_mat.vertex_color_use_as_albedo = true
	stands_mesh.surface_set_material(0, raw_mat)
	stands.mesh = stands_mesh
	yard.add_child(stands)
	yard.melt_material = StandardMaterial3D.new()
	yard.melt_material.emission_enabled = true
	root.add_child(yard)
	yard.bind(null)
	var stands_override := stands.get_surface_override_material(0) as StandardMaterial3D
	_t.check("ArenaBowlYard weathers FleetStands surface with triplanar texture",
		stands_override != null and stands_override.albedo_texture != null and stands_override.uv1_triplanar)
	_t.check("ArenaBowlYard weathers melt_material with triplanar texture",
		yard.melt_material.albedo_texture != null and yard.melt_material.uv1_triplanar)
	yard.free()

	var packed := load(ShowcaseAssembly.SHOWCASE_SCENE_PATH) as PackedScene
	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	var receipt := ShowcaseAssembly.assemble_into(arena)
	_t.eq("CraftShowcaseAssembly still populates all 4 hero sockets", int(receipt.get("sockets_populated", 0)), 4)
	var col_nw := arena.get_node_or_null("IndustrialPerimeterFraming/OverheadGantryTruss/Column_NW") as MeshInstance3D
	_t.check("Gantry Column_NW uses bottom-origin ArrayMesh with smooth grime gradient",
		col_nw != null and col_nw.mesh is ArrayMesh and is_equal_approx(col_nw.position.y, 0.0)
		and col_nw.material_override is ShaderMaterial)
	var chord := arena.get_node_or_null("IndustrialPerimeterFraming/OverheadGantryTruss/Chord_NorthLow") as MeshInstance3D
	var chord_mat := chord.material_override as ShaderMaterial if chord != null else null
	_t.check("Gantry upper chord disables foot_grime_height step",
		chord_mat != null and is_equal_approx(float(chord_mat.get_shader_parameter("foot_grime_height")), 0.0))
	var gussets := arena.get_node_or_null("IndustrialPerimeterFraming/CatwalkGussetBrackets")
	_t.check("CraftShowcaseAssembly mounts 12 cantilevered catwalk gusset brackets",
		gussets != null and gussets.get_child_count() == 12)
	arena.free()
