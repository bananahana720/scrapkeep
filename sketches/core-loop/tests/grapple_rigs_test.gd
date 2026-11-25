extends SceneTree

const T := preload("res://tests/support/t.gd")
const Augments := preload("res://src/movement/augments.gd")
const ChainState := preload("res://src/combat/chain.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const GrappleRig := preload("res://src/presentation/grapple_rig.gd")
const Palette := preload("res://src/core/palette.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# W47-GRAPPLE-CODE: Proves G0 (single ChainState + universal HOOK-CHAIN), G1 (4-part hardware
# rig binding on existing line skills + drive-turn actuation + actuator bone motion), Tally
# copper alligator-clamp/patch-lead look alongside shell_tally, and TADR-008 committed geometry.

const DT := 1.0 / 60.0

var t := T.new("grapple_rigs_test")


class StubPlayer extends Node3D:
	var class_def: Resource
	var kit := preload("res://src/movement/augment_kit.gd").new()
	var chain := ChainState.new()
	var pos := Vector3(0.0, 2.0, 0.0)
	var vel := Vector3.ZERO

	func setup_class(def: Resource) -> void:
		class_def = def
		kit.enabled[Augments.GRAPPLE] = true
		kit.drop_line("reset")
		chain.reset()

	func shown_position() -> Vector3:
		return pos

	func ball_position() -> Vector3:
		return pos

	func active_line_id() -> String:
		return String(class_def.line_id) if class_def != null else "line_reel"

	func grapple_rig_state() -> Dictionary:
		return {
			"class_id": String(class_def.id) if class_def != null else "",
			"line_id": active_line_id(),
			"hooked": kit.hooked,
			"on_body": kit.on_body,
			"winching": kit.winching,
			"rope": kit.rope,
			"anchor": kit.anchor,
			"anchor_body": kit.anchor_body,
			"anchor_normal": kit.anchor_normal,
			"aim": kit.aim,
			"line_state": kit.line_state,
			"shown_position": pos,
			"velocity": vel,
			"chain": chain.snapshot(),
		}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_check_g0_single_chain_and_universal_hook_chain()
	_check_g1_all_six_pilots_and_glb_contracts()
	_check_drive_turn_payout_and_rewind()
	_check_actuator_bones_for_all_pilots()
	_check_tally_copper_palette_law()
	_check_tadr008_committed_geometry_before_hit()
	_check_real_player_ball_snapshot()
	quit(t.verdict())


func _check_g0_single_chain_and_universal_hook_chain() -> void:
	t.eq("G0 ChainState.MAX_CHAINS_PER_PILOT == 1", ChainState.MAX_CHAINS_PER_PILOT, 1)
	var classes := ClassDef.all()
	t.eq("all 6 pilots present", classes.size(), 6)
	var expected_lines := {
		"pylon_engineer": "bank_shot",
		"runner_gunner": "line_drive",
		"demolitions_caster": "cable_charge",
		"tarn": "claw_drag",
		"tally": "link_clips",
		"remembered_cannon": "cannon_lane_charge",
	}
	for def in classes:
		var cid := String(def.id)
		t.eq("pilot %s keeps live line_id" % cid, String(def.line_id), String(expected_lines[cid]))
		var stub := StubPlayer.new()
		root.add_child(stub)
		stub.setup_class(def)
		var ev := GameEvents.new()
		var rig := GrappleRig.new()
		root.add_child(rig)
		rig.setup_standalone(stub, ev)
		t.eq("G0 pilot %s owns strictly one hardware rig" % cid, int(rig.parts()["rig_count"]), 1)
		# Universal HOOK-CHAIN: anchor pivot + enemy link + enemy link climbs combo & multiplier.
		stub.chain.link(false, false)
		stub.chain.link(true, false)
		stub.chain.link(true, false)
		var snap: Dictionary = stub.chain.snapshot()
		t.check("G0 pilot %s universal HOOK-CHAIN active" % cid,
			bool(snap["active"]) and int(snap["links"]) == 2 and int(snap["pivots"]) == 1 and float(snap["multiplier"]) > 1.0,
			str(snap))
		rig.free()
		ev.free()
		stub.free()


func _check_g1_all_six_pilots_and_glb_contracts() -> void:
	var expected_frames := {
		"pylon_engineer": "Pod",
		"runner_gunner": "Pod/WeaponRing",
		"demolitions_caster": "Pod",
		"tarn": "Pod/WeaponRing",
		"tally": "Pod",
		"remembered_cannon": "Pod",
	}
	for def in ClassDef.all():
		var cid := String(def.id)
		var spec := GrappleRig.spec_for(cid, String(def.line_id))
		t.eq("spec frame for %s" % cid, String(spec["frame"]), String(expected_frames[cid]))
		var stub := StubPlayer.new()
		root.add_child(stub)
		stub.setup_class(def)
		var ev := GameEvents.new()
		var rig := GrappleRig.new()
		root.add_child(rig)
		rig.setup_standalone(stub, ev)
		var p := rig.parts()
		t.check("4 parts present for %s" % cid,
			p["mount"] != null and p["drive"] != null and p["line"] != null and p["head"] != null,
			str(p.keys()))
		t.check("3 sockets present for %s" % cid,
			p["socket_drive"] != null and p["socket_line"] != null and p["socket_head"] != null,
			"sockets bound")
		if String(spec["kind"]) == "glb":
			var paths := GrappleRig.glb_paths_for(String(spec["pilot"]))
			for part_key in ["mount", "drive", "line", "head"]:
				t.check("%s %s GLB exists" % [cid, part_key], ResourceLoader.exists(String(paths[part_key])), String(paths[part_key]))
			var mskel: Skeleton3D = p["mount_skeleton"]
			var hskel: Skeleton3D = p["head_skeleton"]
			t.check("%s has MountRig and HeadRig skeletons" % cid, mskel != null and hskel != null,
				"mount=%s head=%s" % [mskel != null, hskel != null])
			if mskel != null:
				t.check("%s mount bone %s found" % [cid, spec["mount_bone"]],
					mskel.find_bone(String(spec["mount_bone"])) >= 0, String(spec["mount_bone"]))
			if hskel != null:
				for hb in spec["head_bones"]:
					t.check("%s head bone %s found" % [cid, hb], hskel.find_bone(String(hb)) >= 0, String(hb))
		else:
			t.check("tally hardware has copper clamp jaws",
				(p["head"] as Node).find_child("JawTop", true, false) != null and (p["head"] as Node).find_child("JawBot", true, false) != null,
				"JawTop + JawBot")
		rig.free()
		ev.free()
		stub.free()


func _check_drive_turn_payout_and_rewind() -> void:
	var sable := _class_by_id("pylon_engineer")
	var stub := StubPlayer.new()
	root.add_child(stub)
	stub.setup_class(sable)
	var ev := GameEvents.new()
	var rig := GrappleRig.new()
	root.add_child(rig)
	rig.setup_standalone(stub, ev)

	# Rest: line hidden, drive stationary.
	rig.step(DT)
	t.check("line hidden at rest", not rig.line_node.visible, "visible=%s" % rig.line_node.visible)
	t.eq("drive idle at rest", rig.drive_direction, 0)

	# Hook & payout: anchor far away and paying out -> positive +X drive spin.
	var anchor := Vector3(0.0, 4.0, -14.0)
	Augments.attach(stub.kit, stub.pos, anchor, Vector3.BACK, null)
	ev.grapple_fired.emit(anchor)
	var before_angle := rig.drive_angle
	for _i in 6:
		stub.pos += Vector3(0.0, 0.0, 0.25)
		rig.step(DT)
	t.check("line visible while hooked", rig.line_node.visible, "visible=%s" % rig.line_node.visible)
	t.check("payout turns drive positively about +X", rig.drive_angle > before_angle and rig.drive_direction == 1,
		"before=%.3f after=%.3f dir=%d rot_x=%.3f" % [before_angle, rig.drive_angle, rig.drive_direction, rig.drive_node.rotation.x])
	t.near("drive_node.rotation.x tracks drive_angle", rig.drive_node.rotation.x, rig.drive_angle, 0.001)

	# Rewind / winch: winching in -> negative -X drive spin.
	var peak_angle := rig.drive_angle
	stub.kit.winching = true
	for _i in 8:
		stub.pos = stub.pos.move_toward(anchor, 0.3)
		rig.step(DT)
	t.check("winch/rewind turns drive negatively about -X", rig.drive_angle < peak_angle and rig.drive_direction == -1,
		"peak=%.3f after=%.3f dir=%d rot_x=%.3f" % [peak_angle, rig.drive_angle, rig.drive_direction, rig.drive_node.rotation.x])

	# Clean reset returns drive to 0 and hides line.
	stub.kit.drop_line("let_go")
	rig.reset()
	t.near("reset clears drive_angle", rig.drive_angle, 0.0, 0.0001)
	t.check("reset hides line", not rig.line_node.visible, "visible=%s" % rig.line_node.visible)

	rig.free()
	ev.free()
	stub.free()


func _check_actuator_bones_for_all_pilots() -> void:
	# 1. Sable: lever bites -18 deg on hook, latch opens on release.
	var sable_res := _drive_pilot("pylon_engineer")
	t.near("sable lever bites -18 deg", float(sable_res["hooked"]["lever_deg"]), -18.0, 0.01)
	t.check("sable latch opens on release", float(sable_res["released"]["latch_deg"]) > 10.0, str(sable_res["released"]))

	# 2. Rivet: toggle flips +90 deg on bite, guide traverses with drum spin.
	var rivet_res := _drive_pilot("runner_gunner")
	t.near("rivet toggle flips +90 deg on bite", float(rivet_res["hooked"]["toggle_deg"]), 90.0, 0.01)
	t.check("rivet guide traverses non-zero on drum turn", absf(float(rivet_res["hooked"]["guide_m"])) > 0.001, str(rivet_res["hooked"]))

	# 3. Kest: flukes fold -50 deg on dry-fire flight, open 0 deg on bite; trolley slides on cable_charge.
	var kest_res := _drive_pilot("demolitions_caster")
	t.near("kest flukes fold -50 deg in flight", float(kest_res["dry"]["fluke_deg"]), -50.0, 0.01)
	t.near("kest flukes open 0 deg on bite", float(kest_res["hooked"]["fluke_deg"]), 0.0, 0.01)
	t.check("kest trolley slides on cable_charge", float(kest_res["skill"]["trolley_m"]) > 0.01, str(kest_res["skill"]))

	# 4. Tarn: pawl lifts +20 deg while winding, talons clamp +35 deg on bite.
	var tarn_res := _drive_pilot("tarn")
	t.near("tarn pawl lifts +20 deg while winding", float(tarn_res["hooked"]["pawl_deg"]), 20.0, 0.01)
	t.near("tarn talons clamp +35 deg on bite", float(tarn_res["hooked"]["talon_deg"]), 35.0, 0.01)

	# 5. Cannon: lock turns -25 deg while hooked, cap pops +0.25 m on release.
	var cannon_res := _drive_pilot("remembered_cannon")
	t.near("cannon lock turns -25 deg while hooked", float(cannon_res["hooked"]["lock_deg"]), -25.0, 0.01)
	t.check("cannon cap pops on release", float(cannon_res["released"]["cap_m"]) > 0.05, str(cannon_res["released"]))

	# 6. Tally: jaws clamp closed on bite and open wider on release.
	var tally_res := _drive_pilot("tally")
	t.check("tally jaws clamp tighter on bite than release",
		float(tally_res["hooked"]["jaw_deg"]) < float(tally_res["released"]["jaw_deg"]),
		"hooked=%s released=%s" % [tally_res["hooked"], tally_res["released"]])


func _drive_pilot(class_id: String) -> Dictionary:
	var def := _class_by_id(class_id)
	var stub := StubPlayer.new()
	root.add_child(stub)
	stub.setup_class(def)
	var ev := GameEvents.new()
	var rig := GrappleRig.new()
	root.add_child(rig)
	rig.setup_standalone(stub, ev)

	# Dry-fire beat
	ev.line_state_changed.emit("dry_fire", null, stub.pos, "")
	rig.step(DT)
	var dry_state := rig.actuator_state()

	# Hooked + payout beat
	var anchor := Vector3(0.0, 3.0, -12.0)
	Augments.attach(stub.kit, stub.pos, anchor, Vector3.BACK, null)
	ev.grapple_fired.emit(anchor)
	rig.step(DT)
	rig.step(DT)
	var hooked_state := rig.actuator_state()

	# Line skill fired beat
	ev.line_skill_fired.emit(String(def.line_id), null, anchor, "world")
	rig.step(0.1)
	var skill_state := rig.actuator_state()

	# Release beat
	stub.kit.drop_line("let_go")
	ev.grapple_released.emit()
	ev.line_state_changed.emit("let_go", null, anchor, "")
	rig.step(DT)
	var released_state := rig.actuator_state()

	rig.free()
	ev.free()
	stub.free()
	return {"dry": dry_state, "hooked": hooked_state, "skill": skill_state, "released": released_state}


func _check_tally_copper_palette_law() -> void:
	var tally := _class_by_id("tally")
	var stub := StubPlayer.new()
	root.add_child(stub)
	stub.setup_class(tally)
	var ev := GameEvents.new()
	var rig := GrappleRig.new()
	root.add_child(rig)
	rig.setup_standalone(stub, ev)
	var forbidden := [Palette.HAZARD, Palette.KINDNESS, Palette.ANCIENT]
	var bad_found := false
	var copper_or_amber := 0
	for part in [rig.mount_node, rig.drive_node, rig.line_node, rig.head_node]:
		for node in (part as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var mat := mi.material_override as StandardMaterial3D
			if mat == null:
				continue
			if mat.albedo_color.is_equal_approx(Palette.COPPER) or mat.albedo_color.is_equal_approx(Palette.AMBER):
				copper_or_amber += 1
			for f: Color in forbidden:
				if mat.albedo_color.is_equal_approx(f):
					bad_found = true
	t.check("tally hardware uses warm copper/amber and zero HAZARD/KINDNESS/ANCIENT",
		copper_or_amber >= 4 and not bad_found, "copper_amber=%d bad=%s" % [copper_or_amber, bad_found])
	rig.free()
	ev.free()
	stub.free()


func _check_tadr008_committed_geometry_before_hit() -> void:
	var sable := _class_by_id("pylon_engineer")
	var stub := StubPlayer.new()
	root.add_child(stub)
	stub.setup_class(sable)
	var ev := GameEvents.new()
	var rig := GrappleRig.new()
	root.add_child(rig)
	rig.setup_standalone(stub, ev)

	# No aim -> hidden.
	stub.kit.aim = Augments.no_aim()
	rig.step(DT)
	t.eq("no aim hides committed geometry", String(rig.committed_geometry()["phase"]), "none")

	# Aim locked BEFORE hit -> visible committed aim geometry matching kit.aim.point verbatim.
	var aim_pt := Vector3(3.0, 5.0, -11.0)
	stub.kit.aim = {"state": Augments.AIM_REACH, "point": aim_pt, "normal": Vector3.BACK}
	rig.step(DT)
	var pre := rig.committed_geometry()
	t.check("TADR-008 draws committed aim geometry BEFORE hit",
		bool(pre["visible"]) and String(pre["phase"]) == "aim" and (pre["point"] as Vector3).is_equal_approx(aim_pt),
		str(pre))

	# Hooked -> latched committed geometry matching kit.anchor verbatim.
	var anchor := Vector3(3.0, 5.0, -11.0)
	Augments.attach(stub.kit, stub.pos, anchor, Vector3.BACK, null)
	rig.step(DT)
	var latched := rig.committed_geometry()
	t.check("TADR-008 draws committed latched geometry at anchor",
		bool(latched["visible"]) and String(latched["phase"]) == "latched" and (latched["point"] as Vector3).is_equal_approx(anchor),
		str(latched))

	rig.free()
	ev.free()
	stub.free()


func _check_real_player_ball_snapshot() -> void:
	var ev := GameEvents.new()
	var pb := PlayerBall.new()
	root.add_child(pb)
	pb.setup(Tuning.new(), ev, Vector3.ZERO)
	pb.fit_class(_class_by_id("runner_gunner"))
	var snap := pb.grapple_rig_state()
	t.eq("PlayerBall.active_line_id matches Rivet line_drive", pb.active_line_id(), "line_drive")
	t.eq("PlayerBall.grapple_rig_state class_id", String(snap["class_id"]), "runner_gunner")
	t.eq("PlayerBall.grapple_rig_state line_id", String(snap["line_id"]), "line_drive")
	t.check("PlayerBall.grapple_rig_state exposes single chain snapshot", snap["chain"] is Dictionary and snap["chain"].has("combo"), str(snap["chain"]))
	pb.free()
	ev.free()


static func _class_by_id(id: String) -> Resource:
	for def in ClassDef.all():
		if String(def.id) == id:
			return def
	return ClassDef.all()[0]
