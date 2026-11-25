extends SceneTree

# W47-GRAPPLE-MUTS-CODE: Proves all 7 single-part-swap grapple build mutations (Master Bible §3.2,
# Rules G0 & G1, TADR-008, Andrew Call #4, Reviewer #60):
#   1. Hot-Wire Arc Cutter (heat · Line · AMBER #E5A044 glow, never HAZARD)
#   2. Det-Cord Line (burst/split · Line · sequenced depth-1 deferred charges, Destructibles.tla safe)
#   3. Dragnet Siphon (salvage · Head · 5 m tether vacuum for scrap, cogs, W47-C1 cradles)
#   4. Sonic Snap-Sling (speed · Drive · pendulum apex +12 m/s Blazing burst + Air-Jump refresh)
#   5. Live-Bus Conductor (arc/chain · Head · AMBER #E5A044 bus charge from powered props, zero mint/purple/HAZARD)
#   6. Tether-Slam Clutch (pull/kinetic · Drive · Smash while tethered yanks to midpoint for 2x crush)
#   7. Wrecking Flail (mass/heft · Head · taut swing +1 effective Heft tier, once-per-piece safe)
# Plus grapple_rig.gd single-part swap binding across all 6 pilots, per-instance mesh/material
# duplication with `amber_glow`, and bone-local Blender actuator verification (`mouth`, `pawl`,
# `jaw.0`/`jaw.1`, `flail`).

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const ChainState := preload("res://src/combat/chain.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const GrappleRig := preload("res://src/presentation/grapple_rig.gd")
const Palette := preload("res://src/core/palette.gd")
const Parts := preload("res://src/build/parts.gd")
const Items := preload("res://src/build/items.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const Consumables := preload("res://src/build/consumables.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")

const DT := 1.0 / 60.0

var _t := T.new("grapple_muts_test")
var _game
var _combat
var _player
var _build
var _source := Intent.Scripted.new()


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
	_check_tables_and_palette_contracts()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run_live.call_deferred()


func _sim(ticks: int) -> void:
	for _i in ticks:
		await physics_frame


func _check_tables_and_palette_contracts() -> void:
	var ids := Parts.grapple_mutation_ids()
	_t.eq("all 7 grapple mutations registered", ids.size(), 7)
	_t.eq("grapple_mutation_problems() is clean", Parts.grapple_mutation_problems(), [])
	_t.eq("G0 single ChainState preserved", ChainState.MAX_CHAINS_PER_PILOT, 1)

	var expected_swaps := {
		"hot_wire": "line",
		"det_cord": "line",
		"dragnet_siphon": "head",
		"sonic_snap_sling": "drive",
		"live_bus": "head",
		"tether_slam": "drive",
		"wrecking_flail": "head",
	}
	var all_glbs := true
	var swap_ok := true
	for mid in expected_swaps:
		var row := Parts.grapple_mutation(mid)
		if String(row.get("swaps", "")) != String(expected_swaps[mid]):
			swap_ok = false
		if not ResourceLoader.exists(String(row.get("glb_path", ""))):
			all_glbs = false
	_t.check("every mutation swaps exact G1 slot (Head/Line/Drive only)", swap_ok)
	_t.check("all 7 mutation GLBs exist on disk", all_glbs)

	# Cobalt item trigger and Maker Set resolution (single slot per swap; latest wins contested slot).
	var from_item := Parts.active_grapple_mutations(["sunforged_core"])
	_t.check("Cobalt item awakens hot_wire on line slot only",
		from_item.keys() == ["line"] and String(from_item["line"]["id"]) == "hot_wire", str(from_item))
	var contested := Parts.active_grapple_mutations(["sunforged_core", "warhead_slug"])
	_t.check("contested line slot resolves to strictly 1 mutation (latest pickup)",
		contested.keys() == ["line"] and String(contested["line"]["id"]) == "det_cord", str(contested))
	var multi_slot := Parts.active_grapple_mutations(["sunforged_core", "salvage_drone", "slipstream"])
	_t.check("distinct slots compose cleanly (head + line + drive)",
		multi_slot.size() == 3 and String(multi_slot["line"]["id"]) == "hot_wire"
		and String(multi_slot["head"]["id"]) == "dragnet_siphon"
		and String(multi_slot["drive"]["id"]) == "sonic_snap_sling", str(multi_slot))
	# All 7 Maker Sets map 1-to-1 to the 7 mutations.
	var maker_muts := {}
	for mk in MakerSets.SETS:
		var m := MakerSets.grapple_mutation_for_maker(mk)
		if m != "":
			maker_muts[m] = mk
	_t.eq("all 7 Maker Sets map 1-to-1 to the 7 grapple mutations", maker_muts.size(), 7)
	# 3 Spillway parts wake hot_wire via Maker Set.
	var spillway_live := MakerSets.live_grapple_mutations(["quick_spool", "cap_relay", "reserve_tank"])
	_t.check("3 Spillway Works pieces wake hot_wire via MakerSets", "hot_wire" in spillway_live, str(spillway_live))
	# 2 Moss pieces wake dragnet_siphon via Maker Set.
	var moss_live := MakerSets.live_grapple_mutations(["fast_hands", "cell_weapon"])
	_t.check("2 Moss's Spares pieces wake dragnet_siphon via MakerSets", "dragnet_siphon" in moss_live, str(moss_live))


func _check_rig_swaps_materials_and_actuators() -> void:
	# 1. Single-part swap across all 6 pilots (including Tally shell_hardware): swaps strictly 1 slot.
	var all_pilots_ok := true
	for def in ClassDef.all():
		var stub := StubPlayer.new()
		root.add_child(stub)
		stub.setup_class(def)
		stub.chain.set_mutations({"line": "hot_wire"})
		var ev := GameEvents.new()
		var rig := GrappleRig.new()
		root.add_child(rig)
		rig.setup_standalone(stub, ev)
		var p := rig.parts()
		if int(p["rig_count"]) != 1 or p["swapped_slots"] != ["line"] or String(p["active_mutations"].get("line", "")) != "hot_wire":
			all_pilots_ok = false
		rig.free()
		ev.free()
		stub.free()
	_t.check("all 6 pilots (including Tally) bind single-part swap via single ChainState", all_pilots_ok)

	# 2. `amber_glow` material slot + per-instance mesh/material duplication (never mutates PackedScene).
	var sable := _class_by_id("pylon_engineer")
	for mid in ["hot_wire", "live_bus"]:
		var stub_a := StubPlayer.new()
		var stub_b := StubPlayer.new()
		root.add_child(stub_a)
		root.add_child(stub_b)
		stub_a.setup_class(sable)
		stub_b.setup_class(sable)
		var ev_a := GameEvents.new()
		var ev_b := GameEvents.new()
		var rig_a := GrappleRig.new()
		var rig_b := GrappleRig.new()
		root.add_child(rig_a)
		root.add_child(rig_b)
		rig_a.setup_standalone(stub_a, ev_a)
		rig_b.setup_standalone(stub_b, ev_b)
		rig_a.set_mutation(mid)
		rig_b.set_mutation(mid)
		var target_node: Node3D = rig_a.line_node if mid == "hot_wire" else rig_a.head_node
		var target_node_b: Node3D = rig_b.line_node if mid == "hot_wire" else rig_b.head_node
		var found_amber := false
		var vcol_ok := true
		var bad_color := false
		var mi_a: MeshInstance3D = null
		var mi_b: MeshInstance3D = null
		for child in target_node.find_children("*", "MeshInstance3D", true, false):
			mi_a = child as MeshInstance3D
			for s in mi_a.mesh.get_surface_count():
				var mat := mi_a.mesh.surface_get_material(s) as StandardMaterial3D
				if mat == null:
					continue
				if not mat.vertex_color_use_as_albedo:
					vcol_ok = false
				if String(mat.resource_name) == "amber_glow":
					found_amber = mat.emission_enabled and absf(mat.emission_energy_multiplier - 1.65) < 0.05 \
						and mat.emission.is_equal_approx(Palette.AMBER.lightened(0.20))
					if mat.emission.is_equal_approx(Palette.HAZARD) or mat.emission.is_equal_approx(Palette.ARC) \
							or mat.emission.is_equal_approx(Palette.KINDNESS):
						bad_color = true
		for child in target_node_b.find_children("*", "MeshInstance3D", true, false):
			mi_b = child as MeshInstance3D
		var isolated := mi_a != null and mi_b != null and mi_a.mesh != mi_b.mesh
		# Verify cached PackedScene mesh was NOT mutated.
		var packed := load(GrappleRig.mutation_glb_path(mid)) as PackedScene
		var raw_inst := packed.instantiate()
		var raw_mi := raw_inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var packed_untouched := raw_mi.mesh != mi_a.mesh
		raw_inst.free()
		_t.check("%s wires amber_glow (AMBER #E5A044 emit 1.65, vertex colors, zero HAZARD/ARC/KINDNESS) with per-instance mesh copy" % mid,
			found_amber and vcol_ok and not bad_color and isolated and packed_untouched,
			"amber=%s vcol=%s bad=%s iso=%s packed=%s" % [found_amber, vcol_ok, bad_color, isolated, packed_untouched])
		# Committed TADR-008 geometry uses AMBER while hooked with hot_wire/live_bus.
		var anchor := Vector3(0.0, 4.0, -10.0)
		Augments.attach(stub_a.kit, stub_a.pos, anchor, Vector3.BACK, null)
		rig_a.step(DT)
		var cmat := rig_a.committed_mesh_node.material_override as StandardMaterial3D
		_t.check("%s committed geometry uses warm AMBER (never HAZARD)" % mid,
			cmat != null and absf(cmat.albedo_color.r - Palette.AMBER.r) < 0.02 and absf(cmat.albedo_color.g - Palette.AMBER.g) < 0.02)
		rig_a.free()
		rig_b.free()
		ev_a.free()
		ev_b.free()
		stub_a.free()
		stub_b.free()

	# 3. Bone-local Blender space actuator tests for all 4 skinned mutations.
	var anchor := Vector3(0.0, 4.0, -12.0)

	# 3a. Dragnet Siphon: `mouth` rotates -42 deg about Blender +X (Godot +X).
	var ds_stub := StubPlayer.new()
	root.add_child(ds_stub)
	ds_stub.setup_class(sable)
	var ds_ev := GameEvents.new()
	var ds_rig := GrappleRig.new()
	root.add_child(ds_rig)
	ds_rig.setup_standalone(ds_stub, ds_ev)
	ds_rig.set_mutation("dragnet_siphon")
	var m_idx := ds_rig.head_skeleton.find_bone("mouth")
	var m_rest := ds_rig.head_skeleton.get_bone_global_pose(m_idx).basis
	Augments.attach(ds_stub.kit, ds_stub.pos, anchor, Vector3.BACK, null)
	ds_rig.step(DT)
	var m_rel := m_rest.inverse() * ds_rig.head_skeleton.get_bone_global_pose(m_idx).basis
	_t.check("dragnet_siphon mouth bone rotates -42 deg about Blender +X",
		m_idx >= 0 and absf(float(ds_rig.actuator_state().get("mouth_deg", 0.0)) + 42.0) < 0.05
		and absf(m_rel.x.x - 1.0) < 0.001 and absf(m_rel.y.z) > 0.5,
		"state=%s rel_x=%s rel_y=%s" % [ds_rig.actuator_state(), m_rel.x, m_rel.y])
	ds_rig.free()
	ds_ev.free()
	ds_stub.free()

	# 3b. Sonic Snap-Sling: `DriveRig` bone `pawl` lifts/clicks about Blender +X.
	var ss_stub := StubPlayer.new()
	root.add_child(ss_stub)
	ss_stub.setup_class(sable)
	var ss_ev := GameEvents.new()
	var ss_rig := GrappleRig.new()
	root.add_child(ss_rig)
	ss_rig.setup_standalone(ss_stub, ss_ev)
	ss_rig.set_mutation("sonic_snap_sling")
	var p_idx := ss_rig.drive_skeleton.find_bone("pawl") if ss_rig.drive_skeleton != null else -1
	var p_rest := ss_rig.drive_skeleton.get_bone_global_pose(p_idx).basis if p_idx >= 0 else Basis.IDENTITY
	Augments.attach(ss_stub.kit, ss_stub.pos, anchor, Vector3.BACK, null)
	ss_ev.grapple_fired.emit(anchor)
	ss_rig.step(DT)
	ss_rig.step(DT)
	var p_rel := p_rest.inverse() * ss_rig.drive_skeleton.get_bone_global_pose(p_idx).basis if p_idx >= 0 else Basis.IDENTITY
	var p_deg := float(ss_rig.actuator_state().get("pawl_deg", 0.0))
	_t.check("sonic_snap_sling DriveRig pawl bone clicks about Blender +X",
		p_idx >= 0 and p_deg > 5.0 and p_deg <= 22.1 and absf(p_rel.x.x - 1.0) < 0.001 and absf(p_rel.y.z) > 0.08,
		"p_idx=%d deg=%.2f rel_x=%s rel_y=%s" % [p_idx, p_deg, p_rel.x, p_rel.y])
	ss_rig.free()
	ss_ev.free()
	ss_stub.free()

	# 3c. Live-Bus Conductor: `jaw.0` (-22) & `jaw.1` (+22) clamp symmetrically inward about Blender +Z (Godot +Y, zero Y drift).
	var lb_stub := StubPlayer.new()
	root.add_child(lb_stub)
	lb_stub.setup_class(sable)
	var lb_ev := GameEvents.new()
	var lb_rig := GrappleRig.new()
	root.add_child(lb_rig)
	lb_rig.setup_standalone(lb_stub, lb_ev)
	lb_rig.set_mutation("live_bus")
	var j0 := lb_rig.head_skeleton.find_bone("jaw.0")
	var j1 := lb_rig.head_skeleton.find_bone("jaw.1")
	var tip_local := Vector3(0.0, 0.20, 0.0) # Blender +Y = Godot -Z
	var j0_before: Vector3 = lb_rig.head_skeleton.get_bone_global_pose(j0) * tip_local
	var j1_before: Vector3 = lb_rig.head_skeleton.get_bone_global_pose(j1) * tip_local
	Augments.attach(lb_stub.kit, lb_stub.pos, anchor, Vector3.BACK, null)
	lb_rig.step(DT)
	var j0_after: Vector3 = lb_rig.head_skeleton.get_bone_global_pose(j0) * tip_local
	var j1_after: Vector3 = lb_rig.head_skeleton.get_bone_global_pose(j1) * tip_local
	# Left jaw (j0, x < 0) moves inward (+X), right jaw (j1, x > 0) moves inward (-X), zero vertical Y drift!
	var clamped_inward := (j0_after.x > j0_before.x + 0.04) and (j1_after.x < j1_before.x - 0.04)
	var zero_y_drift := absf(j0_after.y - j0_before.y) < 0.0005 and absf(j1_after.y - j1_before.y) < 0.0005
	_t.check("live_bus jaw.0/jaw.1 clamp symmetrically inward about Blender +Z (zero vertical Y drift)",
		j0 >= 0 and j1 >= 0 and clamped_inward and zero_y_drift,
		"j0=%s->%s j1=%s->%s" % [j0_before, j0_after, j1_before, j1_after])
	lb_rig.free()
	lb_ev.free()
	lb_stub.free()

	# 3d. Wrecking Flail: `flail` bone swings about Blender +X (Godot +X).
	var wf_stub := StubPlayer.new()
	root.add_child(wf_stub)
	wf_stub.setup_class(sable)
	wf_stub.vel = Vector3(14.0, 0.0, 0.0)
	var wf_ev := GameEvents.new()
	var wf_rig := GrappleRig.new()
	root.add_child(wf_rig)
	wf_rig.setup_standalone(wf_stub, wf_ev)
	wf_rig.set_mutation("wrecking_flail")
	var f_idx := wf_rig.head_skeleton.find_bone("flail")
	var f_rest := wf_rig.head_skeleton.get_bone_global_pose(f_idx).basis
	Augments.attach(wf_stub.kit, wf_stub.pos, anchor, Vector3.BACK, null)
	wf_ev.grapple_fired.emit(anchor)
	wf_rig.step(DT)
	var f_rel := f_rest.inverse() * wf_rig.head_skeleton.get_bone_global_pose(f_idx).basis
	var f_deg := float(wf_rig.actuator_state().get("flail_deg", 0.0))
	_t.check("wrecking_flail flail bone swings about Blender +X",
		f_idx >= 0 and absf(f_deg) > 5.0 and absf(f_deg) <= 28.05 and absf(f_rel.x.x - 1.0) < 0.001 and absf(f_rel.y.z) > 0.08,
		"f_idx=%d deg=%.2f rel_x=%s rel_y=%s" % [f_idx, f_deg, f_rel.x, f_rel.y])
	wf_rig.free()
	wf_ev.free()
	wf_stub.free()


func _run_live() -> void:
	while _game.flow == null:
		await physics_frame
	_check_rig_swaps_materials_and_actuators()
	_game.ctx.calm = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0) # Sable
	await _sim(6)
	_combat = _game.ctx.spawner
	_build = _game.ctx.build

	await _check_hot_wire_gameplay()
	await _check_det_cord_gameplay()
	await _check_dragnet_siphon_gameplay()
	await _check_sonic_snap_sling_gameplay()
	await _check_live_bus_gameplay()
	await _check_tether_slam_gameplay()
	await _check_wrecking_flail_gameplay()
	await _check_attempt_reset_hygiene()

	Consumables._reset()
	GrappleRig._reset()
	_game.free()
	quit(_t.verdict())


func _equip_only(part_ids: Array) -> void:
	_game.ctx.run.parts.assign(part_ids)
	_build.effects.refresh(_game.ctx.run.parts)
	_combat._rebuild_patterns()


func _check_hot_wire_gameplay() -> void:
	_combat._start_attempt()
	_equip_only(["grapple_mut:hot_wire"])
	await _sim(2)
	var ball_at: Vector3 = _player.ball_position()
	var anchor := ball_at + Vector3(0.0, 0.5, -12.0)

	# Ordinary enemy on tether line.
	var chaser = _combat.spawn_enemy("chaser", ball_at + Vector3(0.2, 0.0, -5.0))
	# Boom tender with floats crossing the tether line.
	var tender = _combat.spawn_enemy("boom_tender", ball_at + Vector3(0.0, 0.0, -9.0))
	# Tier 1, Tier 2, and Tier 3 Heft Destructibles along the tether.
	var dest := Destructibles.new()
	var rows := [
		{"id": "hw_t1", "tier": 1, "at": ball_at + Vector3(0.0, 0.5, -3.0), "size": Vector3(1.5, 1.5, 1.5)},
		{"id": "hw_t2", "tier": 2, "at": ball_at + Vector3(0.0, 0.5, -7.0), "size": Vector3(1.5, 1.5, 1.5)},
		{"id": "hw_t3", "tier": 3, "at": ball_at + Vector3(0.0, 0.5, -10.5), "size": Vector3(1.5, 1.5, 1.5)},
	]
	dest.build(rows, {"root": _game.ctx.root, "events": _game.ctx.events, "combat": _combat, "no_visuals": true, "run_id": "hw", "stage": 1})
	dest.finish_build()
	var prev_dest = _game.ctx.destructibles
	_game.ctx.destructibles = dest
	await _sim(2)

	# Align boom tender heading so float 0 lies directly on the tether segment.
	tender._origin = ball_at + Vector3(2.07, 0.0, -6.0)
	tender._heading = Vector3(-1.0, 0.0, 0.0)
	var hp_before: float = chaser.hp
	var pops_before: int = tender.pops

	Augments.attach(_player.kit, ball_at, anchor, Vector3.BACK, null)
	_game.ctx.events.grapple_fired.emit(anchor)
	await _sim(3)
	var chaser_sliced: bool = (not is_instance_valid(chaser)) or chaser.is_dead() or chaser.hp < hp_before
	var float_popped: bool = is_instance_valid(tender) and tender.pops > pops_before
	var t1_cut: bool = dest.state_of("hw_t1") == "shattered"
	var t2_cut: bool = dest.state_of("hw_t2") == "shattered"
	var t3_intact: bool = dest.state_of("hw_t3") == "intact"
	var loot_once := dest.loot()
	await _sim(3)
	var loot_twice := dest.loot()
	_t.check("1. Hot-Wire Arc Cutter slices enemy, pops boom float, cuts Tier 1-2 props (leaves Tier 3 intact, pays once)",
		chaser_sliced and float_popped and t1_cut and t2_cut and t3_intact and loot_once == loot_twice
		and _combat.last_grapple_mut.get("color", Color.BLACK).is_equal_approx(Palette.AMBER),
		"sliced=%s float=%s t1=%s t2=%s t3=%s" % [chaser_sliced, float_popped, t1_cut, t2_cut, t3_intact])

	_player.kit.drop_line("reset")
	_game.ctx.destructibles = prev_dest
	dest.teardown()
	dest.queue_free()
	for n in [chaser, tender]:
		if is_instance_valid(n):
			n.queue_free()
	await _sim(2)


func _check_det_cord_gameplay() -> void:
	_combat._start_attempt()
	_equip_only(["grapple_mut:det_cord"])
	await _sim(2)
	var ball_at: Vector3 = _player.ball_position()
	var anchor := ball_at + Vector3(0.0, 0.5, -14.0)

	var chaser = _combat.spawn_enemy("chaser", ball_at + Vector3(0.0, 0.0, -7.0))
	var dest := Destructibles.new()
	var rows := [{"id": "dc_t2", "tier": 2, "at": ball_at + Vector3(0.0, 0.5, -5.0), "size": Vector3(1.8, 1.8, 1.8)}]
	dest.build(rows, {"root": _game.ctx.root, "events": _game.ctx.events, "combat": _combat, "no_visuals": true, "run_id": "dc", "stage": 1})
	dest.finish_build()
	var prev_dest = _game.ctx.destructibles
	_game.ctx.destructibles = dest
	await _sim(2)

	var hp_before: float = chaser.hp
	Augments.attach(_player.kit, ball_at, anchor, Vector3.BACK, null)
	_game.ctx.events.grapple_fired.emit(anchor)
	await _sim(2)
	# Release tether -> enqueues sequenced shaped charges down tether path.
	_player.kit.drop_line("let_go")
	_game.ctx.events.grapple_released.emit()
	var queued: int = _combat.det_cord_pending()
	await _sim(30) # ~0.5 s for all sequenced nodes to detonate
	var damaged: bool = (not is_instance_valid(chaser)) or chaser.is_dead() or chaser.hp < hp_before
	var broke: bool = dest.state_of("dc_t2") == "shattered"
	var loot_once := dest.loot()
	var drained: bool = _combat.det_cord_pending() == 0
	# Second tick pass must never re-pay.
	await _sim(3)
	_t.check("2. Det-Cord Line detonates sequenced depth-1 charges on release and cracks destructibles once",
		queued >= 2 and drained and damaged and broke and dest.loot() == loot_once,
		"queued=%d drained=%s dmg=%s broke=%s" % [queued, drained, damaged, broke])

	_game.ctx.destructibles = prev_dest
	dest.teardown()
	dest.queue_free()
	if is_instance_valid(chaser):
		chaser.queue_free()
	await _sim(2)


func _check_dragnet_siphon_gameplay() -> void:
	_combat._start_attempt()
	_equip_only(["grapple_mut:dragnet_siphon"])
	_game.ctx.run.clear_consumables()
	await _sim(2)
	var ball_at: Vector3 = _player.ball_position()
	var anchor := ball_at + Vector3(0.0, 1.0, -14.0)
	var mid_spot := ball_at + Vector3(2.5, 0.0, -7.0) # 2.5 m off tether span (< 5 m radius), far from ball magnet

	var scrap_before: int = _game.ctx.run.scrap
	var cogs_before: int = _game.ctx.run.cogs
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	_build.scrap.drop(mid_spot, 3, rng)
	_build.scrap.drop_cogs(mid_spot, 2)
	var cradle = _combat.drop_consumable(Consumables.MOSS_PATCH, mid_spot + Vector3(0.0, 0.0, 1.0))
	var cradle_start: Vector3 = cradle.global_position
	await _sim(1)

	Augments.attach(_player.kit, ball_at, anchor, Vector3.BACK, null)
	_game.ctx.events.grapple_fired.emit(anchor)
	await _sim(25) # Pull along tether into ball
	var got_scrap: bool = _game.ctx.run.scrap > scrap_before
	var got_cogs: bool = _game.ctx.run.cogs > cogs_before
	var got_cons: bool = _game.ctx.run.peek_consumable() == Consumables.MOSS_PATCH \
		or (is_instance_valid(cradle) and cradle.global_position.distance_to(ball_at) < cradle_start.distance_to(ball_at) - 2.0)
	_t.check("3. Dragnet Siphon vacuums scrap, cogs, and W47-C1 pocket consumable cradle within 5 m of tether",
		got_scrap and got_cogs and got_cons and _combat.grapple_mut_count("dragnet_siphon") > 0,
		"scrap=%d->%d cogs=%d->%d belt=%s" % [scrap_before, _game.ctx.run.scrap, cogs_before, _game.ctx.run.cogs, _game.ctx.run.consumables])

	_player.kit.drop_line("reset")
	_game.ctx.run.clear_consumables()
	await _sim(2)


func _check_sonic_snap_sling_gameplay() -> void:
	_combat._start_attempt()
	_equip_only(["grapple_mut:sonic_snap_sling"])
	await _sim(2)
	# Pure apex predicate check: diving steeply is NOT apex; bottom of arc IS apex.
	_t.check("Sonic Snap-Sling rejects non-apex dive",
		not _combat.is_pendulum_apex(Vector3(0, 6, 0), Vector3(0, 14, -8), Vector3(0, -14, -8), 6.0, 0.25, false))
	_t.check("Sonic Snap-Sling accepts pendulum bottom apex",
		_combat.is_pendulum_apex(Vector3(0, 6, -8), Vector3(0, 14, -8), Vector3(0, 0.4, -12), 5.8, 0.25, true))

	var ball_at: Vector3 = _player.ball_position()
	var anchor := ball_at + Vector3(0.0, 10.0, -8.0)
	_player.state.air_actions = 0
	_player.set_velocity_now(Vector3(0.0, -0.5, -10.0), "test")
	Augments.attach(_player.kit, ball_at, anchor, Vector3.BACK, null)
	_game.ctx.events.grapple_fired.emit(anchor)
	await _sim(6) # >= 0.05 s swing time below anchor
	_player.set_velocity_now(Vector3(0.0, 0.2, -10.0), "test")
	var speed_before := Vector2(_player.state.velocity.x, _player.state.velocity.z).length()
	var blazing_floor: float = _player.tuning.f("cruise") * float(SpeedTier.MULTIPLES[SpeedTier.BLAZING])
	_player.kit.drop_line("let_go")
	_game.ctx.events.grapple_released.emit()
	await _sim(1)
	var speed_after := Vector2(_player.state.velocity.x, _player.state.velocity.z).length()
	_t.check("4. Sonic Snap-Sling apex release grants +12 m/s Blazing burst + Air-Jump refresh",
		speed_after >= speed_before + 11.5 and speed_after >= blazing_floor - 0.5 and _player.state.air_actions >= 1,
		"before=%.2f after=%.2f blazing=%.2f air=%d" % [speed_before, speed_after, blazing_floor, _player.state.air_actions])
	await _sim(2)


func _check_live_bus_gameplay() -> void:
	_combat._start_attempt()
	_equip_only(["grapple_mut:live_bus"])
	await _sim(2)
	var ball_at: Vector3 = _player.ball_position()

	# Plain wall latch must NOT charge Live-Bus.
	var plain_anchor := ball_at + Vector3(0.0, 3.0, -10.0)
	Augments.attach(_player.kit, ball_at, plain_anchor, Vector3.BACK, null)
	_game.ctx.events.grapple_fired.emit(plain_anchor)
	await _sim(2)
	var plain_charged: bool = _combat.live_bus_charged()
	_player.kit.drop_line("let_go")
	_game.ctx.events.grapple_released.emit()
	await _sim(1)

	# Powered world prop (sluice_valve_bite + WORLD_ANCHOR_GROUP) MUST charge Live-Bus in AMBER.
	var valve := StaticBody3D.new()
	valve.name = "TestSluiceValve"
	valve.add_to_group("sluice_valve_bite")
	valve.add_to_group(Augments.WORLD_ANCHOR_GROUP)
	_game.ctx.root.add_child(valve)
	valve.global_position = ball_at + Vector3(0.0, 3.0, -8.0)
	Augments.attach(_player.kit, ball_at, valve.global_position, Vector3.BACK, valve)
	_game.ctx.events.grapple_fired.emit(valve.global_position)
	await _sim(2)
	var powered_charged: bool = _combat.live_bus_charged()
	var charge_color: Color = _combat.last_grapple_mut.get("color", Color.BLACK)

	# Next strike on an enemy deals boosted 1.65x damage, discharges amber arc to neighbor, and consumes charge.
	var e1 = _combat.spawn_enemy("chaser", ball_at + Vector3(6.0, 0.0, 0.0))
	var e2 = _combat.spawn_enemy("chaser", ball_at + Vector3(9.0, 0.0, 0.0))
	await _sim(2)
	var mult_with_charge: float = _combat._strike_mult(e1, "arc_caster", "weapon")
	var e2_hp_before: float = e2.hp
	_combat.strike(e1, "arc_caster", 10.0, "", "weapon")
	await _sim(1)
	var consumed: bool = not _combat.live_bus_charged()
	var e2_zapped: bool = (not is_instance_valid(e2)) or e2.is_dead() or e2.hp < e2_hp_before
	_t.check("5. Live-Bus Conductor charges on powered prop only (AMBER #E5A044), boosts next strike 1.65x, arcs amber, consumes once",
		not plain_charged and powered_charged and charge_color.is_equal_approx(Palette.AMBER)
		and mult_with_charge >= 1.64 and consumed and e2_zapped,
		"plain=%s charged=%s mult=%.2f consumed=%s e2_zapped=%s" % [plain_charged, powered_charged, mult_with_charge, consumed, e2_zapped])

	_player.kit.drop_line("reset")
	valve.queue_free()
	for n in [e1, e2]:
		if is_instance_valid(n):
			n.queue_free()
	await _sim(2)


func _check_tether_slam_gameplay() -> void:
	_combat._start_attempt()
	_equip_only(["grapple_mut:tether_slam"])
	await _sim(2)
	var ball_at: Vector3 = _player.ball_position()
	var enemy = _combat.spawn_enemy("chaser", ball_at + Vector3(0.0, 0.0, -12.0))
	await _sim(2)
	var dist_before: float = enemy.global_position.distance_to(ball_at)
	Augments.attach(_player.kit, ball_at, enemy.global_position, Vector3.BACK, enemy)
	_game.ctx.events.grapple_fired.emit(enemy.global_position)
	await _sim(1)
	# Commit Smash while tethered (Ctrl on body line sets LINE_SMASH).
	Augments.commit_smash(_player.kit, _player.tuning, _player.state.velocity)
	await _sim(1)
	var dist_after: float = enemy.global_position.distance_to(ball_at)
	var mult_armed: float = _combat._strike_mult(enemy, "slam", "drop_or_slam")
	var hp_before: float = enemy.hp
	_combat.strike(enemy, "slam", 15.0, "", "drop_or_slam")
	await _sim(1)
	var mult_after: float = _combat._strike_mult(enemy, "slam", "drop_or_slam")
	_t.check("6. Tether-Slam Clutch yanks target and ball to midpoint for 2x crush slam (consumes once)",
		dist_after < dist_before - 2.0 and absf(mult_armed - 2.0) < 0.05 and absf(mult_after - 1.0) < 0.05
		and ((not is_instance_valid(enemy)) or enemy.is_dead() or enemy.hp < hp_before),
		"dist=%.2f->%.2f mult=%.2f->%.2f" % [dist_before, dist_after, mult_armed, mult_after])

	_player.kit.drop_line("reset")
	if is_instance_valid(enemy):
		enemy.queue_free()
	await _sim(2)


func _check_wrecking_flail_gameplay() -> void:
	_combat._start_attempt()
	_equip_only(["grapple_mut:wrecking_flail"])
	_player.set_velocity_now(Vector3.ZERO, "test")
	await _sim(2)
	_player.set_velocity_now(Vector3.ZERO, "test")
	var ball_at: Vector3 = _player.ball_position()
	var anchor := ball_at + Vector3(0.0, 8.0, -10.0)
	# Ensure player is at Heft Class I.
	var hc: int = _game.ctx.run.heft_class()
	var dest := Destructibles.new()
	var rows := [
		{"id": "wf_t2", "tier": hc + 1, "at": ball_at + Vector3(2.4, 0.5, 0.0), "size": Vector3(1.6, 1.6, 1.6)},
		{"id": "wf_t3", "tier": hc + 2, "at": ball_at + Vector3(-2.4, 0.5, 0.0), "size": Vector3(1.6, 1.6, 1.6)},
	]
	dest.build(rows, {"root": _game.ctx.root, "events": _game.ctx.events, "combat": _combat, "no_visuals": true, "run_id": "wf", "stage": 1})
	dest.finish_build()
	var prev_dest = _game.ctx.destructibles
	_game.ctx.destructibles = dest
	var brute = _combat.spawn_enemy("plated_brute", ball_at + Vector3(1.2, 0.0, 1.8))
	await _sim(2)
	var plates_before: int = brute.plates
	ball_at = _player.ball_position()
	anchor = ball_at + Vector3(0.0, 8.0, -10.0)
	_player.set_velocity_now(Vector3(16.0, 0.0, 0.0), "test")
	Augments.attach(_player.kit, ball_at, anchor, Vector3.BACK, null)
	_game.ctx.events.grapple_fired.emit(anchor)
	await _sim(3)
	var t_plus1_broke: bool = dest.state_of("wf_t2") == "shattered"
	var t_plus2_intact: bool = dest.state_of("wf_t3") == "intact"
	var loot_once := dest.loot()
	var plate_stripped: bool = is_instance_valid(brute) and brute.plates < plates_before
	await _sim(3)
	_t.check("7. Wrecking Flail adds strictly +1 effective Heft tier on taut swing (breaks Tier+1 once, spares Tier+2, strips armor)",
		t_plus1_broke and t_plus2_intact and dest.loot() == loot_once and plate_stripped,
		"hc=%d t+1=%s t+2=%s plates=%d->%d" % [hc, t_plus1_broke, t_plus2_intact, plates_before, brute.plates if is_instance_valid(brute) else -1])

	_player.kit.drop_line("reset")
	_game.ctx.destructibles = prev_dest
	dest.teardown()
	dest.queue_free()
	if is_instance_valid(brute):
		brute.queue_free()
	await _sim(2)


func _check_attempt_reset_hygiene() -> void:
	# Queue pending det_cord charges and live_bus charge, then cross attempt boundary -> all must clear!
	_equip_only(["grapple_mut:det_cord", "grapple_mut:live_bus"])
	var ball_at: Vector3 = _player.ball_position()
	_combat._enqueue_det_cord(ball_at, ball_at + Vector3(0.0, 0.0, -15.0))
	_combat._live_bus_charges = 1
	_combat._live_bus_charged_until = _combat._clock + 8.0
	var had_pending: bool = _combat.det_cord_pending() > 0 and _combat.live_bus_charged()
	_combat._start_attempt()
	await _sim(2)
	_t.check("attempt boundary clears pending det_cord queue and live_bus charge (DeferredEffects.tla)",
		had_pending and _combat.det_cord_pending() == 0 and not _combat.live_bus_charged())


static func _class_by_id(id: String) -> Resource:
	for def in ClassDef.all():
		if String(def.id) == id:
			return def
	return ClassDef.all()[0]
