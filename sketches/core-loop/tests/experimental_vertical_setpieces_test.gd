extends SceneTree

const T := preload("res://tests/support/t.gd")
const ChunkSockets := preload("res://src/experimental/arena_chunk_socket.gd")
const DynamicSetpieces := preload("res://src/experimental/dynamic_setpieces.gd")


const CHUNK_PATH := "res://src/experimental/smelter_crane_chunk.tscn"
const DT := 1.0 / 30.0

var t := T.new("experimental_vertical_setpieces_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _check_chunk_instantiation_and_validation()
	await _check_planted_validator_faults()
	await _check_socket_snapping_and_elevated_chunk()
	await _check_em_crane_sweep_magnetic_and_cover_relocation()
	await _check_interactive_prop_pairings()
	await _check_slag_pour_berm_cycle_and_cross_pillar_quench()
	await _check_compactor_vents_momentum_first()
	await _check_moved_rotated_chunk_world_space_contract()
	await _check_teardown_and_repeat_determinism()
	quit(t.verdict())


func _load_chunk() -> Node3D:
	var packed := load(CHUNK_PATH) as PackedScene
	t.check("chunk_packed_loaded", packed != null, CHUNK_PATH)
	if packed == null:
		return null
	var inst := packed.instantiate() as Node3D
	t.check("chunk_instantiated_node3d", inst != null, "root is Node3D")
	return inst


func _check_chunk_instantiation_and_validation() -> void:
	var chunk := _load_chunk()
	if chunk == null:
		return
	root.add_child(chunk)
	await process_frame

	var sockets := ChunkSockets.discover_sockets(chunk)
	t.check("sockets_discovered", sockets.size() >= 18, "found %d sockets" % sockets.size())
	for kind in ChunkSockets.SOCKET_KINDS:
		var of_kind := ChunkSockets.sockets_of_kind(chunk, kind)
		t.check("has_socket_kind_" + String(kind), of_kind.size() >= 1, "count=%d" % of_kind.size())

	var report := ChunkSockets.validate_chunk(chunk)
	t.check("chunk_passes_validator", bool(report["ok"]), "errors=%s" % [str(report["errors"])])
	var m: Dictionary = report["metrics"]
	t.eq("populated_tiers_is_3", int(m["populated_tiers"]), 3)
	t.check("vertical_span_ge_12m", float(m["vertical_span_m"]) >= 12.0, "span=%.2f" % float(m["vertical_span_m"]))
	t.eq("zero_clearance_violations", int(m["clearance_violations"]), 0)
	t.check("hard_cover_present_incl_compactor_housings", int(m["hard_cover_count"]) >= 4, "hard_cover=%d" % int(m["hard_cover_count"]))
	t.eq("zero_bad_cover_layers", int(m["bad_cover_layer"]), 0)
	t.eq("zero_bad_static_masks", int(m["bad_static_mask"]), 0)
	t.check("nav_region_3tier_non_floating",
		bool(m["nav_valid"]) and int(m["nav_polygon_count"]) == 6 and int(m["nav_tiers_covered"]) == 3
		and int(m["nav_link_count"]) >= 3 and int(m["nav_floating_polygons"]) == 0,
		"polys=%d tiers=%d links=%d floating=%d" % [int(m["nav_polygon_count"]), int(m["nav_tiers_covered"]), int(m["nav_link_count"]), int(m["nav_floating_polygons"])])
	t.check("high_ground_vantages_present", int(m["vantage_count"]) >= 2, "vantages=%d" % int(m["vantage_count"]))
	t.check("landmark_sight_ge_85pct", float(m["sight_share"]) >= 0.85, "sight=%.2f" % float(m["sight_share"]))
	t.check("landmark_prominence_ge_10m", float(m["landmark_prominence_m"]) >= 10.0, "prom=%.2f" % float(m["landmark_prominence_m"]))
	t.check("bowl_depth_ge_2m", float(m["bowl_depth_m"]) >= 2.0, "depth=%.2f" % float(m["bowl_depth_m"]))
	t.check("three_tier_loop_closed", bool(m["has_three_tier_cycle"]), "cycle=%s" % [str(m["has_three_tier_cycle"])])
	t.eq("zero_dead_ends", int(m["dead_end_count"]), 0)
	t.check("floor_escape_ok", bool(m["floor_escape_ok"]), "escape=%s" % [str(m["floor_escape_ok"])])

	for rim_name in ["RimNorth", "RimSouth", "RimWest", "RimEast"]:
		var rim_body := chunk.get_node_or_null("Tier0_Basin/" + rim_name) as StaticBody3D
		t.check("has_rim_" + rim_name, rim_body != null and rim_body.collision_layer == 1, rim_name)
	t.eq("chunk_has_zero_light3d", chunk.find_children("*", "Light3D", true, false).size(), 0)

	root.remove_child(chunk)
	chunk.free()
	await process_frame


func _check_planted_validator_faults() -> void:
	var chunk := _load_chunk()
	root.add_child(chunk)
	await process_frame

	var blocker := StaticBody3D.new()
	blocker.name = "PlantedLowBlocker"
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	blocker.set_meta(ChunkSockets.META_COVER_KIND, "hard")
	blocker.position = Vector3(-22.0, 9.2, 4.0)
	var bshape := CollisionShape3D.new()
	var bbox := BoxShape3D.new()
	bbox.size = Vector3(4.0, 2.5, 4.0)
	bshape.shape = bbox
	blocker.add_child(bshape)
	chunk.add_child(blocker)
	var r1 := ChunkSockets.validate_chunk(chunk)
	t.check("plant_clearance_caught", not bool(r1["ok"]) and int(r1["metrics"]["clearance_violations"]) >= 1,
		"violations=%d" % int(r1["metrics"]["clearance_violations"]))
	chunk.remove_child(blocker)
	blocker.free()

	var floor_sock := ChunkSockets.find_socket(chunk, "floor_loop_south")
	var floor_marker: Marker3D = floor_sock["node"]
	var saved_links: Variant = floor_marker.get_meta(ChunkSockets.META_ROUTE_LINKS)
	floor_marker.set_meta(ChunkSockets.META_ROUTE_LINKS, PackedStringArray())
	var r2 := ChunkSockets.validate_chunk(chunk)
	t.check("plant_dead_end_pit_caught", not bool(r2["ok"]) and not bool(r2["metrics"]["floor_escape_ok"]),
		"dead_ends=%d escape=%s" % [int(r2["metrics"]["dead_end_count"]), str(r2["metrics"]["floor_escape_ok"])])
	floor_marker.set_meta(ChunkSockets.META_ROUTE_LINKS, saved_links)

	var roof := StaticBody3D.new()
	roof.name = "PlantedOcclusionRoof"
	roof.collision_layer = 1
	roof.collision_mask = 0
	roof.set_meta(ChunkSockets.META_COVER_KIND, "hard")
	roof.position = Vector3(0.0, 28.0, -15.0)
	var rshape := CollisionShape3D.new()
	var rbox := BoxShape3D.new()
	rbox.size = Vector3(90.0, 2.5, 90.0)
	rshape.shape = rbox
	roof.add_child(rshape)
	chunk.add_child(roof)
	var r3 := ChunkSockets.validate_chunk(chunk)
	t.check("plant_landmark_occlusion_caught", not bool(r3["ok"]) and float(r3["metrics"]["sight_share"]) < 0.85,
		"sight_share=%.2f" % float(r3["metrics"]["sight_share"]))
	chunk.remove_child(roof)
	roof.free()

	var nav_region := chunk.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	var saved_nav := nav_region.navigation_mesh
	var bad_nav := NavigationMesh.new()
	bad_nav.agent_radius = 1.0
	bad_nav.vertices = PackedVector3Array([
		Vector3(-10.0, 7.6, -10.0), Vector3(10.0, 7.6, -10.0),
		Vector3(10.0, 7.6, 10.0), Vector3(-10.0, 7.6, 10.0),
	])
	bad_nav.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_region.navigation_mesh = bad_nav
	var r4 := ChunkSockets.validate_chunk(chunk)
	t.check("plant_floating_nav_quad_caught", not bool(r4["ok"]) and int(r4["metrics"]["nav_floating_polygons"]) >= 1,
		"floating=%d" % int(r4["metrics"]["nav_floating_polygons"]))
	nav_region.navigation_mesh = saved_nav

	chunk.remove_child(nav_region)
	nav_region.free()
	var r5 := ChunkSockets.validate_chunk(chunk)
	t.check("plant_missing_navigation_caught", not bool(r5["ok"]) and not bool(r5["metrics"]["nav_valid"]),
		"nav_valid=%s" % [str(r5["metrics"]["nav_valid"])])

	root.remove_child(chunk)
	chunk.free()
	await process_frame


func _check_socket_snapping_and_elevated_chunk() -> void:
	var chunk_a := _load_chunk()
	var chunk_b := _load_chunk()
	chunk_a.position = Vector3(50.0, 42.0, -30.0)
	chunk_a.rotation = Vector3(0.0, PI * 0.25, 0.0)
	chunk_b.position = Vector3(-120.0, 19.0, 75.0)
	chunk_b.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	root.add_child(chunk_a)
	root.add_child(chunk_b)
	await process_frame

	var elevated_report := ChunkSockets.validate_chunk(chunk_a)
	t.check("elevated_rotated_chunk_passes_validator", bool(elevated_report["ok"]),
		"errors=%s" % [str(elevated_report["errors"])])

	var south_a := ChunkSockets.find_socket(chunk_a, "floor_loop_south")
	var north_b := ChunkSockets.find_socket(chunk_b, "rail_mid_north")
	var attached := ChunkSockets.snap_transform(south_a, Vector3(0.0, 1.5, 0.0))
	t.near("snap_offset_y", attached.origin.y, float((south_a["position"] as Vector3).y) + 1.5, 0.001)

	var mated_xform := ChunkSockets.compute_chunk_snap(south_a, north_b)
	chunk_b.global_transform = mated_xform
	await process_frame
	var north_b_after := ChunkSockets.find_socket(chunk_b, "rail_mid_north")
	t.near("non_identity_chunk_mate_distance",
		(north_b_after["position"] as Vector3).distance_to(south_a["position"] as Vector3), 0.0, 0.001)

	root.remove_child(chunk_b)
	root.remove_child(chunk_a)
	chunk_b.free()
	chunk_a.free()
	await process_frame


func _check_em_crane_sweep_magnetic_and_cover_relocation() -> void:
	var chunk := _load_chunk()
	var setpieces := DynamicSetpieces.new()
	root.add_child(chunk)
	root.add_child(setpieces)
	await process_frame

	var info := setpieces.setup_from_chunk(chunk, {"seed": 101})
	t.check("crane_cover_slots_discovered", int(info["cover_slot_count"]) >= 3, "slots=%d" % int(info["cover_slot_count"]))
	var s0: Dictionary = setpieces.snapshot()["crane"]
	var start_slot := String(s0["slot_id"])
	t.eq("crane_hull_starts_on_layer1", int(s0["hull_layer"]), 1)

	var emitted_tags: Array[Dictionary] = []
	setpieces.env_tag_emitted.connect(func(p: Dictionary) -> void: emitted_tags.append(p))

	t.check("crane_player_trigger_accepted", setpieces.trigger_setpiece(String(info["crane_id"]), "player"), "triggered")
	t.check("crane_telegraph_visible_immediately", bool(setpieces.snapshot()["crane"]["telegraph_visible"]), "telegraph on")

	var scrap_actor := {
		"id": "loose_barrel_1",
		"kind": "barrel",
		"position": Vector3(-5.0, 0.5, 4.0),
		"velocity": Vector3.ZERO,
		"magnetic_pullable": true,
	}
	var dest_slot_pos: Vector3 = ChunkSockets.find_socket(chunk, "cover_slot_east")["position"]
	var start_to_dest := Vector2(scrap_actor["position"].x - dest_slot_pos.x, scrap_actor["position"].z - dest_slot_pos.z).length()

	var saw_bridge_open := false
	var saw_magnetic_tag := false
	var saw_relocated := false
	var warn_duration := 0.0
	var tested_hold_guard := false
	var max_simultaneous_crane_tags := 0

	for i in 230:
		var ball_pos := Vector3(30.0, 0.5, 30.0)
		var csnap: Dictionary = setpieces.snapshot()["crane"]
		if String(csnap["state"]) == "relocate_drop" and not tested_hold_guard:
			ball_pos = dest_slot_pos + Vector3(3.8, 1.0, 0.0)
			if i > 155:
				tested_hold_guard = true
		var facts := setpieces.step(DT, ball_pos, Vector3(15.0, 0.0, 0.0), 2, [scrap_actor])
		var active_crane_tags := 0
		for atag in setpieces.active_env_tags():
			if atag["tag"] == DynamicSetpieces.TAG_MAGNETIC:
				active_crane_tags += 1
		max_simultaneous_crane_tags = maxi(max_simultaneous_crane_tags, active_crane_tags)
		for f in facts:
			match String(f.get("kind", "")):
				"harpoon_bridge_opened":
					saw_bridge_open = true
					warn_duration = float(setpieces.snapshot()["crane"]["warn_elapsed"])
				"env_tag_emitted":
					var payload: Dictionary = f["payload"]
					if payload["tag"] == DynamicSetpieces.TAG_MAGNETIC:
						saw_magnetic_tag = true
						t.eq("magnetic_payload_valid", DynamicSetpieces.validate_env_tag(payload), "")
				"cover_relocated":
					saw_relocated = true

	var s1: Dictionary = setpieces.snapshot()["crane"]
	t.check("crane_warn_ge_fairness_floor", warn_duration >= DynamicSetpieces.MIN_WARN_FLOOR_S, "warn=%.2f s" % warn_duration)
	t.check("crane_opened_harpoon_bridge", saw_bridge_open, "bridge opened")
	t.check("crane_closed_harpoon_bridge_after_drop", not bool(s1["harpoon_bridge_open"]), "bridge closed cleanly")
	t.check("crane_emitted_magnetic_tag", saw_magnetic_tag and emitted_tags.size() > 0, "tags=%d" % emitted_tags.size())
	t.eq("crane_active_tags_deduped_to_1", max_simultaneous_crane_tags, 1)
	var end_to_dest := Vector2(scrap_actor["position"].x - dest_slot_pos.x, scrap_actor["position"].z - dest_slot_pos.z).length()
	t.check("crane_pulled_loose_barrel", end_to_dest < start_to_dest * 0.4,
		"dist_to_dest before=%.2f after=%.2f" % [start_to_dest, end_to_dest])
	t.check("crane_relocated_cover_slot", saw_relocated and String(s1["slot_id"]) != start_slot and int(s1["relocations"]) == 1,
		"from=%s to=%s" % [start_slot, String(s1["slot_id"])])
	t.eq("crane_hull_restored_layer1", int(s1["hull_layer"]), 1)

	setpieces.teardown()
	root.remove_child(setpieces)
	root.remove_child(chunk)
	setpieces.free()
	chunk.free()
	await process_frame


func _check_interactive_prop_pairings() -> void:
	var chunk := _load_chunk()
	var setpieces := DynamicSetpieces.new()
	root.add_child(chunk)
	root.add_child(setpieces)
	await process_frame

	var info := setpieces.setup_from_chunk(chunk, {"seed": 404})
	var prop_signals: Array[String] = []
	setpieces.prop_interaction_triggered.connect(func(pid: String, kind: String, _o: Vector3) -> void:
		prop_signals.append(pid + ":" + kind)
	)

	t.check("pairing1_trigger_crane", setpieces.trigger_setpiece(String(info["crane_id"]), "player"), "crane started")
	for _i in 65:
		setpieces.step(DT, Vector3(30.0, 0.5, 30.0), Vector3.ZERO, 2)
	t.eq("pairing1_crane_in_sweep", String(setpieces.snapshot()["crane"]["state"]), "sweep_active")

	var bridge_pos: Vector3 = setpieces.snapshot()["crane"]["harpoon_bridge_pos"]
	var enemy_under := {
		"id": "fleet_brute_under_crane",
		"kind": "enemy",
		"position": Vector3(bridge_pos.x, 0.5, bridge_pos.z),
		"velocity": Vector3.ZERO,
		"hp": 100.0,
	}
	var drop_facts := setpieces.strike_crane_magnet([enemy_under], Vector3(30.0, 0.5, 30.0))
	var saw_drop_crush := false
	var saw_elec_burst := false
	for f in drop_facts:
		if String(f.get("kind", "")) == "crane_magnet_drop_crush":
			saw_drop_crush = true
		elif String(f.get("kind", "")) == "env_tag_emitted" and f["payload"]["tag"] == DynamicSetpieces.TAG_ELECTRIFIED:
			saw_elec_burst = true
	t.check("pairing1_magnet_drop_crushed_enemy", saw_drop_crush and float(enemy_under["hp"]) == 35.0,
		"enemy_hp=%.1f" % float(enemy_under["hp"]))
	t.eq("pairing1_magnet_drop_grounded_cover_layer1", int(setpieces.snapshot()["crane"]["hull_layer"]), 1)
	t.check("pairing1_magnet_drop_emitted_electrified", saw_elec_burst, "electrified burst")

	t.check("pairing2_trigger_furnace", setpieces.trigger_setpiece(String(info["furnace_id"]), "player"), "furnace started")
	for _i in 60:
		setpieces.step(DT, Vector3(30.0, 0.5, 30.0), Vector3.ZERO, 1)
	t.eq("pairing2_furnace_molten", String(setpieces.snapshot()["furnace"]["state"]), "molten_pour")

	t.check("pairing2_trigger_cryo_via_trigger_setpiece", setpieces.trigger_setpiece(String(info["cryo_pipe_id"]), "player"), "cryo triggered")
	t.eq("pairing2_cryo_froze_molten_slag", String(setpieces.snapshot()["furnace"]["state"]), "cooling_berms")
	t.eq("pairing2_frozen_berms_tier1", int(setpieces.snapshot()["furnace"]["berm_tiers"][0]), 1)
	t.eq("pairing2_cryo_cooldown_blocks_spam", setpieces.rupture_cryo_pipe(String(info["cryo_pipe_id"])).size(), 0)
	t.eq("pairing_signals_fired", prop_signals.size(), 2)

	setpieces.teardown()
	root.remove_child(setpieces)
	root.remove_child(chunk)
	setpieces.free()
	chunk.free()
	await process_frame


func _check_slag_pour_berm_cycle_and_cross_pillar_quench() -> void:
	var chunk := _load_chunk()
	var setpieces := DynamicSetpieces.new()
	root.add_child(chunk)
	root.add_child(setpieces)
	await process_frame

	var info := setpieces.setup_from_chunk(chunk, {"seed": 202})
	var fid := String(info["furnace_id"])

	t.check("furnace_trigger_ok", setpieces.trigger_setpiece(fid, "player"), "triggered")
	t.check("furnace_telegraph_visible", bool(setpieces.snapshot()["furnace"]["telegraph_visible"]), "telegraph visible")

	var saw_slag_tag := false
	var saw_burn_tag := false
	var stalled_burned := false
	var fast_burned := false
	var formed_positions: Array[Vector3] = []
	var ram_shattered := false

	for _i in 60:
		var step_facts := setpieces.step(DT, Vector3(30.0, 0.5, 30.0), Vector3.ZERO, 2)
		for f in step_facts:
			if String(f.get("kind", "")) == "env_tag_emitted":
				var tag: StringName = f["payload"]["tag"]
				if tag == DynamicSetpieces.TAG_SLAG_COATED:
					saw_slag_tag = true
				elif tag == DynamicSetpieces.TAG_BURNING:
					saw_burn_tag = true

	t.eq("furnace_entered_molten", String(setpieces.snapshot()["furnace"]["state"]), "molten_pour")
	var basin_tags := setpieces.tags_at(Vector3(0.0, 0.5, 0.0))
	t.eq("slag_tags_deduped_to_2_in_basin", basin_tags.size(), 2)

	var fast_facts := setpieces.step(DT, Vector3(2.0, 0.5, 0.0), Vector3(16.0, 0.0, 0.0), 2)
	for f in fast_facts:
		if String(f.get("kind", "")) == "slag_stall_burn":
			fast_burned = true
	var stall_facts := setpieces.step(DT, Vector3(2.0, 0.5, 0.0), Vector3(1.0, 0.0, 0.0), 2)
	for f in stall_facts:
		if String(f.get("kind", "")) == "slag_stall_burn":
			stalled_burned = true

	t.check("slag_emits_slag_coated_and_burning", saw_slag_tag and saw_burn_tag, "slag=%s burn=%s" % [str(saw_slag_tag), str(saw_burn_tag)])
	t.check("slag_spares_fast_ball", not fast_burned, "fast ball spared")
	t.check("slag_punishes_stalled_ball", stalled_burned, "stalled ball burned")

	for _i in 150:
		var facts := setpieces.step(DT, Vector3(30.0, 0.5, 30.0), Vector3.ZERO, 2)
		for f in facts:
			if String(f.get("kind", "")) == "slag_berm_formed":
				formed_positions.append(f["position"] as Vector3)
		if String(setpieces.snapshot()["furnace"]["state"]) == "cooling_berms":
			break

	t.eq("slag_formed_3_cover_berms", formed_positions.size(), DynamicSetpieces.SLAG_BERM_COUNT)
	t.eq("slag_berms_intact_count", int(setpieces.snapshot()["furnace"]["intact_berms"]), DynamicSetpieces.SLAG_BERM_COUNT)

	var ram_facts := setpieces.step(DT, formed_positions[0], Vector3(15.0, 0.0, 0.0), 2)
	for f in ram_facts:
		if String(f.get("kind", "")) == "slag_berm_shattered" and String(f.get("by", "")) == "ram":
			ram_shattered = true
	t.check("slag_berm_shattered_by_heft_ram", ram_shattered, "shattered by ram")
	t.eq("slag_berms_left_after_ram", int(setpieces.snapshot()["furnace"]["intact_berms"]), 2)

	var saw_cycle_cleared := false
	for _i in 300:
		var facts := setpieces.step(DT, Vector3(30.0, 0.5, 30.0), Vector3.ZERO, 2)
		for f in facts:
			if String(f.get("kind", "")) == "slag_cycle_cleared":
				saw_cycle_cleared = true
		if saw_cycle_cleared:
			break
	t.check("slag_berms_crumble_cleanly", saw_cycle_cleared and bool(setpieces.snapshot()["furnace"]["basin_clear"]),
		"basin_clear=%s" % [str(setpieces.snapshot()["furnace"]["basin_clear"])])

	t.check("furnace_cycle2_trigger", setpieces.trigger_setpiece(fid, "player"), "cycle 2 triggered")
	for _i in 60:
		setpieces.step(DT, Vector3(30.0, 0.5, 30.0), Vector3.ZERO, 1)
	var coolant_payload := DynamicSetpieces.make_env_tag(
		DynamicSetpieces.TAG_COOLANT_BRITTLE, Vector3(0.0, 0.5, 0.0), 8.0, "exp_ecology:cryo_vent", 1.0, 2.0
	)
	var reaction_facts := setpieces.apply_external_tag(coolant_payload)
	var saw_quench := false
	for f in reaction_facts:
		if String(f.get("kind", "")) == "slag_flash_quenched":
			saw_quench = true
	t.check("cross_pillar_coolant_flash_quenches_slag", saw_quench, "quenched into cooling_berms")
	t.eq("quenched_berm_tier_is_1", int(setpieces.snapshot()["furnace"]["berm_tiers"][0]), 1)
	t.eq("quench_reaction_bounded_once", setpieces.apply_external_tag(coolant_payload).size(), 0)

	var blast_facts := setpieces.on_blast(Vector3(0.0, 1.0, 0.0), 12.0, 1, 1)
	t.eq("blast_shatters_quenched_berms", blast_facts.size(), DynamicSetpieces.SLAG_BERM_COUNT)
	t.eq("all_quenched_berms_cleared", int(setpieces.snapshot()["furnace"]["intact_berms"]), 0)

	setpieces.teardown()
	root.remove_child(setpieces)
	root.remove_child(chunk)
	setpieces.free()
	chunk.free()
	await process_frame


func _check_compactor_vents_momentum_first() -> void:
	var chunk := _load_chunk()
	var setpieces := DynamicSetpieces.new()
	root.add_child(chunk)
	root.add_child(setpieces)
	await process_frame

	var info := setpieces.setup_from_chunk(chunk, {"seed": 303})
	var cid := String(info["compactor_id"])
	var vent_pos: Vector3 = ChunkSockets.find_socket(chunk, "setpiece_compactor_vent")["position"]

	t.check("compactor_trigger_ok", setpieces.trigger_setpiece(cid, "player"), "triggered")
	for _i in 32:
		setpieces.step(DT, Vector3(30.0, 0.5, 30.0), Vector3.ZERO, 2)
	t.check("compactor_lane_opened", bool(setpieces.snapshot()["compactor"]["lane_open"]), "open")
	t.eq("compactor_ram_collider_off_when_open", int(setpieces.snapshot()["compactor"]["ram_layer"]), 0)

	var boost_facts := setpieces.step(DT, vent_pos, Vector3(0.0, 0.0, 16.0), 2)
	var saw_boost := false
	for f in boost_facts:
		if String(f.get("kind", "")) == "ball_momentum_boost":
			saw_boost = true
	t.check("compactor_boosts_fast_ball", saw_boost, "fast ball boosted")

	var stalled_enemy := {
		"id": "fleet_chaser_01",
		"kind": "enemy",
		"position": vent_pos,
		"velocity": Vector3(0.5, 0.0, 0.0),
		"hp": 100.0,
	}
	var saw_enemy_crush := false
	var saw_ball_eject := false
	var saw_ball_crush := false
	var fast_ram_held_clear := false
	for _i in 170:
		var facts := setpieces.step(DT, vent_pos, Vector3(0.0, 0.0, 16.0), 2, [stalled_enemy])
		for f in facts:
			if String(f.get("kind", "")) == "compactor_crush_punish":
				if String(f.get("target_id", "")) == "fleet_chaser_01":
					saw_enemy_crush = true
				elif String(f.get("target_id", "")) == "ball":
					saw_ball_crush = true
			elif String(f.get("kind", "")) == "ball_momentum_boost" and String(setpieces.snapshot()["compactor"]["state"]) == "crush_snap":
				saw_ball_eject = true
				fast_ram_held_clear = int(setpieces.snapshot()["compactor"]["ram_layer"]) == 0

	t.check("compactor_crushes_stalled_enemy", saw_enemy_crush and float(stalled_enemy["hp"]) < 100.0, "enemy_hp=%.1f" % float(stalled_enemy["hp"]))
	t.check("compactor_never_crushes_fast_ball", not saw_ball_crush and saw_ball_eject and fast_ram_held_clear,
		"fast ball ejected cleanly with ram_layer held at 0")
	var clamped_tag := DynamicSetpieces.make_env_tag(DynamicSetpieces.TAG_MAGNETIC, Vector3.ZERO, 5.0, "clamp_check", 0.0, 1.0)
	t.eq("make_env_tag_clamps_positive_intensity", DynamicSetpieces.validate_env_tag(clamped_tag), "")

	setpieces.teardown()
	root.remove_child(setpieces)
	root.remove_child(chunk)
	setpieces.free()
	chunk.free()
	await process_frame


func _check_moved_rotated_chunk_world_space_contract() -> void:
	var chunk := _load_chunk()
	chunk.position = Vector3(100.0, 12.0, -50.0)
	chunk.rotation = Vector3(0.0, PI * 0.5, 0.0)
	var setpieces := DynamicSetpieces.new()
	chunk.add_child(setpieces)
	root.add_child(chunk)
	await process_frame

	var info := setpieces.setup_from_chunk(chunk, {"seed": 505})
	var furnace_world: Vector3 = ChunkSockets.find_socket(chunk, "setpiece_slag_furnace")["position"]
	var east_world: Vector3 = ChunkSockets.find_socket(chunk, "cover_slot_east")["position"]
	t.near("moved_chunk_furnace_world_x", furnace_world.x, 100.0, 0.01)

	setpieces.trigger_setpiece(String(info["furnace_id"]), "player")
	var emitted_world_origin := Vector3.ZERO
	for _i in 60:
		var facts := setpieces.step(DT, furnace_world + Vector3(30.0, 0.0, 30.0), Vector3.ZERO, 2)
		for f in facts:
			if String(f.get("kind", "")) == "env_tag_emitted" and f["payload"]["tag"] == DynamicSetpieces.TAG_SLAG_COATED:
				emitted_world_origin = f["payload"]["origin"]
	t.check("moved_chunk_tag_origin_is_world_space",
		emitted_world_origin.distance_to(furnace_world) < 0.5,
		"emitted=%s want~%s" % [str(emitted_world_origin), str(furnace_world)])
	t.check("moved_chunk_tags_at_world_point_finds_slag", setpieces.tags_at(furnace_world).size() >= 2,
		"count=%d" % setpieces.tags_at(furnace_world).size())

	var ext_coolant := DynamicSetpieces.make_env_tag(
		DynamicSetpieces.TAG_COOLANT_BRITTLE, furnace_world, 8.0, "exp_ecology:remote_cryo", 1.0, 2.0
	)
	var q_facts := setpieces.apply_external_tag(ext_coolant)
	var quenched_moved := false
	for f in q_facts:
		if String(f.get("kind", "")) == "slag_flash_quenched":
			quenched_moved = true
	t.check("moved_chunk_world_external_tag_quenches", quenched_moved, "moved furnace quenched")

	var b_facts := setpieces.on_blast(furnace_world, 12.0, 1, 1)
	t.eq("moved_chunk_world_blast_shatters_berms", b_facts.size(), DynamicSetpieces.SLAG_BERM_COUNT)

	var relocated_out: Array[Vector3] = []
	setpieces.cover_relocated.connect(func(_a: String, _b: String, wp: Vector3) -> void: relocated_out.append(wp))
	t.check("moved_chunk_crane_triggered", setpieces.trigger_setpiece(String(info["crane_id"]), "player"), "crane triggered")
	for _i in 210:
		setpieces.step(DT, furnace_world + Vector3(30.0, 0.0, 30.0), Vector3.ZERO, 2)
	t.eq("moved_chunk_cover_relocated_emitted", relocated_out.size(), 1)
	if not relocated_out.is_empty():
		var relocated_world := relocated_out[0]
		t.near("moved_chunk_cover_relocated_world_xz",
			Vector2(relocated_world.x - east_world.x, relocated_world.z - east_world.z).length(), 0.0, 0.05)

	setpieces.teardown()
	root.remove_child(chunk)
	chunk.free()
	await process_frame


func _check_teardown_and_repeat_determinism() -> void:
	var results: Array[Dictionary] = []
	for _run_idx in 2:
		var chunk := _load_chunk()
		var setpieces := DynamicSetpieces.new()
		root.add_child(chunk)
		root.add_child(setpieces)
		await process_frame
		setpieces.setup_from_chunk(chunk, {"seed": 777})
		for _i in 180:
			setpieces.step(DT, Vector3(25.0, 0.5, 25.0), Vector3(14.0, 0.0, 0.0), 2)
		results.append(setpieces.snapshot())
		setpieces.teardown()
		t.eq("teardown_empties_children", setpieces.get_child_count(), 0)
		t.eq("teardown_empties_active_tags", setpieces.active_env_tags().size(), 0)
		root.remove_child(setpieces)
		root.remove_child(chunk)
		setpieces.free()
		chunk.free()
		await process_frame

	t.eq("repeat_run_crane_deterministic", results[0]["crane"], results[1]["crane"])
	t.eq("repeat_run_furnace_deterministic", results[0]["furnace"], results[1]["furnace"])
	t.eq("repeat_run_compactor_deterministic", results[0]["compactor"], results[1]["compactor"])
