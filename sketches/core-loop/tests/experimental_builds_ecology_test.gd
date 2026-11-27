extends SceneTree


const EnvTags := preload("res://src/experimental/env_tags.gd")
const PartResource := preload("res://src/experimental/part_resource.gd")
const JuryRig := preload("res://src/experimental/jury_rig_synergies.gd")
const Ecology := preload("res://src/experimental/ecology_actors.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("experimental_builds_ecology_test")


func _initialize() -> void:
	_test_env_tags_schema_and_reactions()
	_test_env_tags_bounded_cascade_and_reentrancy()
	_test_tres_part_catalogue_and_weld_chainsaw_synergy()
	_test_emergent_tag_and_signal_synergies_zero_hardcode()
	_test_overclock_vent_vs_stall_rule9()
	_test_interactive_props()
	_test_neutral_couriers_and_aggro_ping()
	_test_role_based_enemy_fsm_reactions()
	_test_qa_regressions_linear_reentrancy_telegraph()
	_test_clean_reset_and_repeatability()
	EnvTags.reset()
	PartResource.reset()
	JuryRig.reset()
	Ecology.reset()
	quit(_t.verdict())


func _test_env_tags_schema_and_reactions() -> void:
	_t.eq("canonical tag count is 6", EnvTags.CANONICAL_TAGS.size(), 6)
	var valid_p := EnvTags.make_payload(EnvTags.TAG_SLAG_COATED, Vector3(1, 0, 2), 4.0, "test_slag", 1.2, 5.0)
	_t.eq("valid payload passes schema check", EnvTags.validate_payload(valid_p), [])
	var bad_p := {"tag": &"unknown_tag", "origin": Vector3.ZERO}
	_t.check("invalid payload reports schema problems", EnvTags.validate_payload(bad_p).size() > 0, "missing keys caught")

	var field := EnvTags.new()
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_SLAG_COATED, Vector3.ZERO, 4.0, "slag_pool", 1.0, 5.0))
	var res_arc := field.apply_tag(EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, Vector3(1.0, 0.0, 0.0), 3.0, "arc_bolt", 1.0, 3.0))
	_t.check("slag + electrified triggers conductive_arc_chain",
		res_arc["reactions"].size() == 1 and res_arc["reactions"][0]["reaction_id"] == &"conductive_arc_chain",
		"reactions=%s" % str(res_arc["reactions"].size()))

	field.clear()
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, Vector3(10, 0, 0), 4.0, "coolant", 1.0, 5.0))
	var res_steam := field.apply_tag(EnvTags.make_payload(EnvTags.TAG_BURNING, Vector3(11, 0, 0), 3.5, "flame", 1.0, 3.0))
	_t.check("burning + coolant_brittle triggers thermal_shatter_steam",
		res_steam["reactions"].size() == 1 and res_steam["reactions"][0]["reaction_id"] == &"thermal_shatter_steam",
		"got %s" % str(res_steam["reactions"]))
	_t.check("thermal_shatter_steam emits bounded soaked_conductive condensate",
		field.tags_at(Vector3(10.5, 0, 0), 1.0).has(EnvTags.TAG_SOAKED_CONDUCTIVE),
		"tags=%s" % str(field.tags_at(Vector3(10.5, 0, 0), 1.0)))

	field.clear()
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_MAGNETIC, Vector3(20, 0, 0), 4.0, "coil", 1.0, 4.0))
	var res_rail := field.apply_tag(EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, Vector3(21, 0, 0), 3.0, "spike", 1.0, 3.0))
	_t.check("magnetic + electrified triggers rail_surge with momentum boost",
		res_rail["reactions"].size() == 1 and res_rail["reactions"][0]["reaction_id"] == &"rail_surge"
			and float(res_rail["reactions"][0]["ball_boost_mps"]) > 0.0,
		"rail=%s" % str(res_rail["reactions"]))

	field.step(10.0)
	_t.eq("TTL step expires all zones cleanly", field.active_zone_count(), 0)


func _test_env_tags_bounded_cascade_and_reentrancy() -> void:
	var field := EnvTags.new()
	for i in 10:
		var pos := Vector3(float(i % 3) * 0.8, 0.0, float(i / 3) * 0.8)
		var tag: StringName = EnvTags.TAG_COOLANT_BRITTLE if i % 2 == 0 else EnvTags.TAG_SLAG_COATED
		field.apply_tag(EnvTags.make_payload(tag, pos, 5.0, "seed_%d" % i, 1.0, 8.0))
	for a in 5:
		var aid := "actor_%d" % a
		field.register_actor(aid, Vector3(float(a) * 0.4, 0.0, 0.0), 1.0)
		field.apply_tag(EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, Vector3.ZERO, 2.0, "coat", 1.0, 6.0), aid, false)

	var burn_res := field.apply_tag(EnvTags.make_payload(EnvTags.TAG_BURNING, Vector3(0.5, 0.0, 0.5), 8.0, "mega_burn", 1.5, 4.0))
	_t.check("cascade stress completes deterministically with bounded depth",
		burn_res["ok"] and int(burn_res["max_depth_reached"]) <= EnvTags.MAX_CASCADE_DEPTH,
		"depth=%d max=%d" % [int(burn_res["max_depth_reached"]), EnvTags.MAX_CASCADE_DEPTH])
	_t.check("cascade stress respects MAX_REACTIONS_PER_PASS ceiling",
		burn_res["reactions"].size() <= EnvTags.MAX_REACTIONS_PER_PASS,
		"reactions=%d cap=%d" % [burn_res["reactions"].size(), EnvTags.MAX_REACTIONS_PER_PASS])

	field.clear()
	var counter := [0]
	var fref: WeakRef = weakref(field)
	field.reaction_triggered.connect(func(_ev: Dictionary) -> void:
		var f: Variant = fref.get_ref()
		if f == null:
			return
		counter[0] += 1
		f.apply_tag(EnvTags.make_payload(EnvTags.TAG_SLAG_COATED, Vector3.ZERO, 4.0, "re_slag_%d" % counter[0], 1.0, 4.0))
		f.apply_tag(EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, Vector3.ZERO, 4.0, "re_arc_%d" % counter[0], 1.0, 4.0))
	)
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_SLAG_COATED, Vector3.ZERO, 4.0, "root_slag", 1.0, 4.0))
	var re_res := field.apply_tag(EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, Vector3.ZERO, 4.0, "root_arc", 1.0, 4.0))
	_t.check("adversarial re-entrant listener stays strictly bounded",
		re_res["ok"] and int(re_res["max_depth_reached"]) <= EnvTags.MAX_CASCADE_DEPTH
			and int(field.stats()["reentrant_queued"]) > 0,
		"depth=%d queued=%d reactions=%d" % [int(re_res["max_depth_reached"]), int(field.stats()["reentrant_queued"]), re_res["reactions"].size()])


func _test_tres_part_catalogue_and_weld_chainsaw_synergy() -> void:
	_t.eq("all 8 .tres PartResources load and validate cleanly", JuryRig.validate_catalogue(), [])
	_t.eq("catalogue loads 8 .tres parts", JuryRig.catalogue().size(), 8)

	var field := EnvTags.new()
	var rig := JuryRig.new(field)
	var emerged: Array[Dictionary] = []
	rig.synergy_emerged.connect(func(s: Dictionary) -> void: emerged.append(s))

	_t.check("equip Arc Welder Dash .tres", rig.equip_by_id(&"arc_welder_dash")["ok"])
	_t.check("equip Magnetized Sawblades .tres", rig.equip_by_id(&"magnetized_sawblades")["ok"])

	var dash_res := rig.dispatch(PartResource.TRIG_ON_DASH, {
		"origin": Vector3.ZERO,
		"dir": Vector3.FORWARD,
		"dash_length_m": 8.0,
		"ball_speed_mps": 18.0,
	})
	_t.check("Arc Welder Dash lays intact conductive slag + electrified seam",
		field.tags_at(Vector3(0, 0, -4.0), 2.0).has(EnvTags.TAG_SLAG_COATED)
			and field.tags_at(Vector3(0, 0, -8.0), 1.5).has(EnvTags.TAG_ELECTRIFIED),
		"mid=%s tip=%s" % [str(field.tags_at(Vector3(0, 0, -4.0), 2.0)), str(field.tags_at(Vector3(0, 0, -8.0), 1.5))])
	_t.check("Arc Welder Dash adds line heat", dash_res["heat"] > 0.0, "heat=%.1f" % float(dash_res["heat"]))

	var targets := [
		{"id": "pig_1", "pos": Vector3(0.5, 0, -4.0)},
		{"id": "pig_2", "pos": Vector3(2.0, 0, -4.5)},
		{"id": "pig_3", "pos": Vector3(-1.5, 0, -5.0)},
		{"id": "pig_4", "pos": Vector3(3.0, 0, -3.5)},
	]
	var fire_res := rig.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {
		"origin": Vector3.ZERO,
		"dir": Vector3.FORWARD,
		"target_pos": Vector3(0.0, 0.0, -4.0),
		"targets": targets,
		"ball_speed_mps": 16.0,
	})
	_t.check("Magnetized Sawblades chain lightning across >= 3 targets over slag seam",
		fire_res["chain_hits"].size() >= 3,
		"chain_hits=%d" % fire_res["chain_hits"].size())
	var saw_synergy := emerged.any(func(s: Dictionary) -> bool:
		var prods: Array = s["producers"]
		return prods.has(&"arc_welder_dash") and prods.has(&"magnetized_sawblades")
	)
	_t.check("Arc Welder Dash + Magnetized Sawblades synergy emerges via tags/signals",
		saw_synergy, "emerged=%s" % str(emerged))


func _test_emergent_tag_and_signal_synergies_zero_hardcode() -> void:
	var field := EnvTags.new()
	var rig := JuryRig.new(field)
	rig.equip_by_id(&"hoard_coil_ballast")
	rig.equip_by_id(&"harpoon_grounding_spike")
	rig.add_heat(35.0)
	rig.dispatch(PartResource.TRIG_ON_SCRAP_PICKUP, {"origin": Vector3(5, 0, 5), "ball_speed_mps": 15.0})
	var heat_before := rig.heat
	var snap_res := rig.dispatch(PartResource.TRIG_ON_HARPOON_SNAP, {
		"origin": Vector3(5, 0, 5),
		"anchor_pos": Vector3(6, 0, 5),
		"clean_snap": true,
		"ball_speed_mps": 18.0,
	})
	_t.check("Harpoon Grounding Spike refunds heat on clean snap", rig.heat < heat_before,
		"before=%.1f after=%.1f" % [heat_before, rig.heat])
	var rail_syn: bool = (snap_res["synergies"] as Array).any(func(s: Dictionary) -> bool:
		return s["via"] == &"rail_surge" and (s["producers"] as Array).has(&"hoard_coil_ballast")
	)
	_t.check("Hoard-Coil + Grounding Spike rail_surge synergy emerges cleanly", rail_syn, "syn=%s" % str(snap_res["synergies"]))

	field.clear()
	rig.clear()
	rig.equip_by_id(&"slag_skid_crucible")
	rig.equip_by_id(&"brine_tap_vent")
	rig.add_heat(70.0)
	rig.dispatch(PartResource.TRIG_ON_SLAM, {"origin": Vector3.ZERO, "ball_speed_mps": 16.0})
	_t.check("Slag-Skid Crucible preserves BOTH burning and slag_coated on floor",
		field.tags_at(Vector3.ZERO, 1.0).has(EnvTags.TAG_BURNING)
			and field.tags_at(Vector3.ZERO, 1.0).has(EnvTags.TAG_SLAG_COATED),
		"tags=%s" % str(field.tags_at(Vector3.ZERO, 1.0)))
	_t.eq("Slag-Skid Crucible pushes rig into REDLINE", rig.heat_band(), JuryRig.BAND_REDLINE)
	var vent := rig.attempt_redline_vent(Vector3(0.5, 0.0, 0.0), 16.0, &"slam")
	_t.check("Brine-Tap redline vent triggers thermal_shatter_steam + emergent synergy",
		vent["vented"]
			and (vent["reactions"] as Array).any(func(r: Dictionary) -> bool: return r["reaction_id"] == &"thermal_shatter_steam")
			and (vent["synergies"] as Array).any(func(s: Dictionary) -> bool: return s["via"] == &"thermal_shatter_steam"),
		"reactions=%s" % str(vent["reactions"]))

	field.clear()
	rig.clear()
	rig.equip_by_id(&"requisition_leech")
	rig.equip_by_id(&"thermite_flail_spool")
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, Vector3(2, 0, 2), 4.0, "coolant_tank:t1", 1.0, 5.0))
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_BURNING, Vector3(12, 0, 2), 3.0, "slag_drum:d1", 1.0, 5.0))
	var rup := rig.dispatch(PartResource.TRIG_ON_PROP_RUPTURE, {
		"origin": Vector3(2, 0, 2),
		"targets": [{"id": "sniper_1", "pos": Vector3(12, 0, 2)}],
	})
	_t.check("Requisition Leech siphons coolant_brittle onto burning target and wakes Thermite Flail",
		rup["chain_hits"].size() == 1
			and (rup["reactions"] as Array).any(func(r: Dictionary) -> bool: return r["reaction_id"] == &"thermal_shatter_steam")
			and (rup["synergies"] as Array).any(func(s: Dictionary) -> bool: return s["kind"] == &"signal_chain_synergy"),
		"synergies=%s" % str(rup["synergies"]))

	field.clear()
	rig.clear()
	var custom_cryo := PartResource.from_dict({
		"id": &"custom_cryo_anchor",
		"display_name": "Cryo Anchor",
		"maker": &"spillway_works",
		"slot": PartResource.Slot.WEAPON,
		"rarity": &"jury_rigged",
		"trigger": PartResource.TRIG_ON_HARPOON_SNAP,
		"emits_tags": [EnvTags.TAG_COOLANT_BRITTLE],
		"consumes_tags": [EnvTags.TAG_SLAG_COATED],
		"heat_cost": -10.0,
		"effect_id": &"custom_cryo_emit",
		"params": {"radius_m": 5.5, "ttl_s": 4.0},
		"summary": "Harpoon snaps coat the anchor in brittle coolant.",
		"trade_off": "Requires a live anchor line before venting chill.",
		"visual_tell": "Ice ring around the snapped hook.",
		"audio_tell": "Sharp frost snap on cable release.",
	})
	_t.eq("custom 9th PartResource validates", custom_cryo.validate(), [])
	rig.equip_by_id(&"slag_skid_crucible")
	rig.equip(custom_cryo)
	rig.dispatch(PartResource.TRIG_ON_SLAM, {"origin": Vector3.ZERO, "ball_speed_mps": 16.0})
	var custom_res := rig.dispatch(PartResource.TRIG_ON_HARPOON_SNAP, {"origin": Vector3.ZERO, "anchor_pos": Vector3(0.5, 0, 0)})
	var custom_syn: bool = (custom_res["synergies"] as Array).any(func(s: Dictionary) -> bool:
		return (s["producers"] as Array).has(&"custom_cryo_anchor") and (s["producers"] as Array).has(&"slag_skid_crucible")
	)
	_t.check("unlisted custom PartResource composes with existing .tres part via tags alone",
		custom_syn, "synergies=%s" % str(custom_res["synergies"]))


func _test_overclock_vent_vs_stall_rule9() -> void:
	var field := EnvTags.new()
	var rig := JuryRig.new(field)
	_t.near("COOL overclock scale is 1.0", rig.overclock_scale(), 1.0)
	rig.add_heat(55.0)
	_t.eq("55 heat is HOT band", rig.heat_band(), JuryRig.BAND_HOT)
	_t.check("HOT amplifies overclock scale > 1.2", rig.overclock_scale() > 1.2, "scale=%.2f" % rig.overclock_scale())
	rig.add_heat(35.0)
	_t.eq("90 heat is REDLINE band", rig.heat_band(), JuryRig.BAND_REDLINE)
	_t.near("REDLINE peaks overclock scale at 1.75", rig.overclock_scale(), 1.75)

	var fast_step := rig.step(0.5, 16.0)
	_t.near("fast rolling at REDLINE cooks zero hull", fast_step["cook_damage"], 0.0)
	_t.check("fast rolling cools more than stalling", fast_step["cooled"] >= 4.0, "cooled=%.2f" % float(fast_step["cooled"]))

	rig.add_heat(20.0)
	var stall_step := rig.step(1.0, 1.0)
	_t.check("stalling at REDLINE cooks hull plating", stall_step["cook_damage"] > 5.0,
		"cook=%.2f" % float(stall_step["cook_damage"]))

	var bad_vent := rig.attempt_redline_vent(Vector3.ZERO, 4.0, &"slam")
	_t.eq("slow vent at REDLINE is refused", bad_vent["vented"], false)
	var good_vent := rig.attempt_redline_vent(Vector3.ZERO, 16.0, &"slam")
	_t.eq("fast slam vent at REDLINE succeeds", good_vent["vented"], true)
	_t.check("fast vent drops heat below REDLINE", rig.heat < JuryRig.HEAT_REDLINE_AT, "heat=%.1f" % rig.heat)


func _test_interactive_props() -> void:
	var field := EnvTags.new()
	var eco := Ecology.new(field)

	eco.spawn_prop("tank_1", Ecology.PROP_COOLANT_TANK, Vector3(0, 0, 0))
	var tank_res := eco.interact_prop_with_ball("tank_1", Vector3(10, 0, 0), false)
	_t.check("Coolant Tank rupture emits coolant_brittle & quench bonus",
		tank_res["ok"] and float(tank_res["quench_cool"]) >= 25.0
			and field.tags_at(Vector3.ZERO, 1.0).has(EnvTags.TAG_COOLANT_BRITTLE),
		"tags=%s" % str(field.tags_at(Vector3.ZERO, 1.0)))

	eco.spawn_prop("drum_1", Ecology.PROP_SLAG_DRUM, Vector3(20, 0, 0))
	var chain_tank := eco.spawn_prop("tank_chain", Ecology.PROP_COOLANT_TANK, Vector3(27.5, 0, 0))
	var drum_target := eco.spawn_enemy("drum_foe", Ecology.ROLE_SWARMER, Vector3(26, 0, 0))
	var punt_res := eco.interact_prop_with_ball("drum_1", Vector3(15, 0, 0), false)
	_t.eq("high-speed ball punts Slag Drum", punt_res["action"], &"punted")
	var detonated := false
	for _i in 12:
		var st := eco.step(0.05, Vector3(20, 0, 0), Vector3.ZERO)
		for hit in st["bowling_hits"]:
			if hit["kind"] == &"drum_detonate":
				detonated = true
	_t.check("punted Slag Drum detonates, chains into Coolant Tank, and flashes steam condensate",
		detonated and drum_target.hp < drum_target.max_hp
			and not chain_tank.intact
			and field.tags_at(drum_target.pos, 3.0).has(EnvTags.TAG_SOAKED_CONDUCTIVE),
		"detonated=%s hp=%.1f chain_tank_intact=%s tags=%s" % [str(detonated), drum_target.hp, str(chain_tank.intact), str(field.tags_at(drum_target.pos, 3.0))])

	eco.spawn_prop("pile_harvest", Ecology.PROP_SCRAP_PILE, Vector3(40, 0, 0))
	var harv := eco.interact_prop_with_ball("pile_harvest", Vector3(6, 0, 0), false)
	_t.check("gentle Scrap Pile touch harvests scrap and cogs",
		harv["action"] == &"harvested" and int(harv["scrap"]) == 4 and int(harv["cogs"]) == 1,
		"harv=%s" % str(harv))

	eco.spawn_prop("pile_bowl", Ecology.PROP_SCRAP_PILE, Vector3(50, 0, 0))
	var pin_foe := eco.spawn_enemy("pin_1", Ecology.ROLE_SWARMER, Vector3(54, 0, 0))
	var bowl_launch := eco.interact_prop_with_ball("pile_bowl", Vector3(16, 0, 0), true)
	_t.eq("slam-punt launches Scrap Pile as bowling pin", bowl_launch["action"], &"bowling_launched")
	var bowled := false
	for _i in 10:
		var st := eco.step(0.05, Vector3(50, 0, 0), Vector3.ZERO)
		for hit in st["bowling_hits"]:
			if hit["kind"] == &"scrap_bowl":
				bowled = true
	_t.check("bowling Scrap Pile damages enemy in its path", bowled and pin_foe.hp < pin_foe.max_hp,
		"bowled=%s hp=%.1f" % [str(bowled), pin_foe.hp])

	eco.spawn_prop("cond_1", Ecology.PROP_POWER_CONDUIT, Vector3(80, 0, 0))
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_SOAKED_CONDUCTIVE, Vector3(82, 0, 0), 4.0, "puddle", 1.0, 5.0))
	var cond_res := eco.trigger_conduit("cond_1", "test")
	_t.check("Live Power Conduit energizes adjacent soaked zone into spillway_discharge",
		cond_res["ok"] and (cond_res["reactions"] as Array).any(func(r: Dictionary) -> bool: return r["reaction_id"] == &"spillway_discharge"),
		"reactions=%s" % str(cond_res["reactions"]))
	_t.eq("Power Conduit respects bounded cooldown on immediate re-trigger",
		eco.trigger_conduit("cond_1", "spam")["ok"], false)


func _test_neutral_couriers_and_aggro_ping() -> void:
	var field := EnvTags.new()
	var eco := Ecology.new(field)
	var hauler := eco.spawn_courier("hauler_1", Ecology.COURIER_HAULER_DRONE, Vector3(0, 0, 0), Vector3(50, 0, 0))
	var start_pos := hauler.pos
	eco.step(0.3, Vector3(-40, 0, 0), Vector3.ZERO)
	_t.check("patrolling Hauler Drone moves along its patrol route", hauler.pos.distance_to(start_pos) > 0.5,
		"moved=%.2f" % hauler.pos.distance_to(start_pos))

	var near_bot := eco.spawn_enemy("fleet_near", Ecology.ROLE_SWARMER, Vector3(10, 0, 0))
	var far_bot := eco.spawn_enemy("fleet_far", Ecology.ROLE_SWARMER, Vector3(60, 0, 0))

	var hit := eco.strike_courier("hauler_1", 20.0, Vector3(-2, 0, 0), false)
	_t.eq("Hauler Drone switches to FLEEING when struck", hauler.state, Ecology.ST_FLEEING)
	_t.check("Hauler Drone spills loot immediately on hit",
		int(hit["spilled_scrap"]) > 0 and int(hit["spilled_cogs"]) > 0,
		"scrap=%d cogs=%d" % [int(hit["spilled_scrap"]), int(hit["spilled_cogs"])])
	_t.eq("Requisition Aggro Ping alerts nearby Fleet bot with >= 0.6s F1 telegraph",
		near_bot.alerted and near_bot.alert_telegraph_s >= 0.6, true)
	_t.eq("Requisition Aggro Ping ignores distant Fleet bot", far_bot.alerted, false)

	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, hauler.pos, 3.0, "arc_bolt", 1.0, 4.0))
	var pos_before := hauler.pos
	eco.step(0.2, Vector3(-20, 0, 0), Vector3.ZERO)
	_t.check("electrified Hauler Drone stalls its thruster", hauler.stalled_s > 0.0 and hauler.pos.distance_to(pos_before) < 0.01,
		"stalled=%.2f moved=%.3f" % [hauler.stalled_s, hauler.pos.distance_to(pos_before)])
	for _i in 8:
		eco.step(0.2, Vector3(-20, 0, 0), Vector3.ZERO)
	_t.check("Hauler Drone resumes fleeing after 1.5s stall despite lingering electrified TTL",
		hauler.pos.distance_to(pos_before) > 0.5,
		"moved_after_recovery=%.2f" % hauler.pos.distance_to(pos_before))

	var finish := eco.strike_courier("hauler_1", 80.0, Vector3(-1, 0, 0), true)
	_t.eq("disabled Hauler Drone drops unrefined core", int(finish["spilled_cores"]), 1)

	var cart := eco.spawn_courier("cart_1", Ecology.COURIER_SKITTER_CART, Vector3(0, 0, 20), Vector3(40, 0, 20))
	eco.strike_courier("cart_1", 5.0, Vector3(-5, 0, 20), false)
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, cart.pos, 3.0, "cryo", 1.0, 3.0))
	eco.step(0.2, Vector3(-30, 0, 20), Vector3.ZERO)
	_t.check("coolant_brittle slows fleeing Audit Skitter-Cart", cart.vel.length() < cart.speed_mps * 0.6,
		"vel=%.2f base=%.2f" % [cart.vel.length(), cart.speed_mps])


func _test_role_based_enemy_fsm_reactions() -> void:
	var field := EnvTags.new()
	var eco := Ecology.new(field)

	var sw := eco.spawn_enemy("sw_1", Ecology.ROLE_SWARMER, Vector3(5, 0, 0))
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_BURNING, sw.pos, 2.0, "fire", 1.0, 3.0))
	eco.step(0.1, Vector3.ZERO, Vector3.ZERO)
	_t.eq("burning Swarmer enters panic REPOSITION", sw.state, Ecology.ST_REPOSITION)

	var sw2 := eco.spawn_enemy("sw_2", Ecology.ROLE_SWARMER, Vector3(30, 0, 0))
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, sw2.pos, 2.0, "cryo", 1.0, 3.0))
	var brittle_hit := eco.damage_enemy("sw_2", 10.0, Vector3(28, 0, 0), &"kinetic")
	_t.near("coolant_brittle amplifies kinetic hit to 16.0", brittle_hit["damage_dealt"], 16.0)

	var bulk := eco.spawn_enemy("bulk_1", Ecology.ROLE_SHIELDED_BULWARK, Vector3(0, 0, 20))
	bulk.facing = Vector3(0, 0, -1)
	var front_hit := eco.damage_enemy("bulk_1", 20.0, Vector3(0, 0, 15), &"kinetic")
	_t.near("braced Shielded Bulwark blocks 75% frontal damage (deals 5)", front_hit["damage_dealt"], 5.0)
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_MAGNETIC, bulk.pos, 3.0, "coil", 1.0, 3.0))
	eco.step(0.1, Vector3(0, 0, 10), Vector3.ZERO)
	_t.eq("magnetic pulls Bulwark shield aside into DISRUPTED", bulk.state, Ecology.ST_DISRUPTED)

	var bulk2 := eco.spawn_enemy("bulk_2", Ecology.ROLE_SHIELDED_BULWARK, Vector3(40, 0, 20))
	bulk2.facing = Vector3(0, 0, -1)
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, bulk2.pos, 3.0, "cryo", 1.0, 4.0))
	var slam_shield := eco.damage_enemy("bulk_2", 20.0, Vector3(40, 0, 15), &"slam")
	_t.eq("coolant_brittle + slam shatters Bulwark shield", slam_shield["shield_intact"], false)

	var bulk3 := eco.spawn_enemy("bulk_3", Ecology.ROLE_SHIELDED_BULWARK, Vector3(60, 0, 20))
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_SLAG_COATED, bulk3.pos, 3.0, "slag_src", 1.0, 5.0))
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_BURNING, bulk3.pos, 3.0, "flame_src", 1.0, 4.0))
	_t.eq("molten_rekindle reaction drops Bulwark shield via EnvTags listener", bulk3.shield_intact, false)

	var sniper := eco.spawn_enemy("snip_1", Ecology.ROLE_ARC_SNIPER, Vector3(0, 0, 50))
	eco.step(0.1, Vector3(0, 0, 35), Vector3.ZERO)
	_t.eq("Arc Sniper enters WINDUP at range", sniper.state, Ecology.ST_WINDUP)
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_MAGNETIC, sniper.pos, 3.0, "coil", 1.0, 3.0))
	eco.step(0.1, Vector3(0, 0, 35), Vector3.ZERO)
	_t.check("magnetic deflects Arc Sniper aim", sniper.aim_deflected_rad > 0.2, "deflect=%.2f" % sniper.aim_deflected_rad)
	var sniper2 := eco.spawn_enemy("snip_2", Ecology.ROLE_ARC_SNIPER, Vector3(30, 0, 50))
	eco.step(0.1, Vector3(30, 0, 35), Vector3.ZERO)
	var hp_before := sniper2.hp
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, sniper2.pos, 3.0, "arc", 1.0, 4.5))
	eco.step(0.1, Vector3(30, 0, 35), Vector3.ZERO)
	var hp_after_once := sniper2.hp
	_t.check("electrified overloads Arc Sniper and cancels windup into DISRUPTED",
		sniper2.state == Ecology.ST_DISRUPTED and hp_after_once > 0.0 and hp_after_once < hp_before,
		"state=%s hp=%.1f" % [String(sniper2.state), hp_after_once])
	for _i in 12:
		eco.step(0.2, Vector3(30, 0, 35), Vector3.ZERO)
	_t.near("lingering electrified TTL never double-procs Arc Sniper overload", sniper2.hp, hp_after_once)

	var ally := eco.spawn_enemy("ally_1", Ecology.ROLE_SWARMER, Vector3(80, 0, 0))
	ally.hp = 20.0
	var healer := eco.spawn_enemy("heal_1", Ecology.ROLE_WELD_HEALER, Vector3(86, 0, 0))
	var st_heal := eco.step(0.5, Vector3(0, 0, 0), Vector3.ZERO)
	_t.eq("Weld-Healer enters TETHER_HEAL on wounded ally", healer.state, Ecology.ST_TETHER_HEAL)
	_t.check("Weld-Healer repairs wounded ally", ally.hp > 20.0 and st_heal["heals"].size() == 1,
		"ally_hp=%.1f" % ally.hp)

	var ally_hp_pre_snap := ally.hp
	var snap_sever := eco.apply_harpoon_snap("heal_1", Vector3(82, 0, 4))
	_t.check("harpoon snap severs Weld-Healer tether and feedback-jolts ally",
		snap_sever["action"] == &"tether_severed" and healer.state == Ecology.ST_DISRUPTED
			and ally.hp < ally_hp_pre_snap,
		"sever=%s ally_hp=%.1f" % [str(snap_sever), ally.hp])

	var ally2 := eco.spawn_enemy("ally_2", Ecology.ROLE_SWARMER, Vector3(110, 0, 0))
	ally2.hp = 20.0
	var healer2 := eco.spawn_enemy("heal_2", Ecology.ROLE_WELD_HEALER, Vector3(115, 0, 0))
	eco.step(0.2, Vector3(0, 0, 0), Vector3.ZERO)
	_t.eq("second Weld-Healer establishes tether", healer2.state, Ecology.ST_TETHER_HEAL)
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, healer2.pos, 3.0, "arc_zap", 1.0, 2.0))
	var st_elec := eco.step(0.1, Vector3(0, 0, 0), Vector3.ZERO)
	_t.check("electrified severs Weld-Healer tether into DISRUPTED",
		healer2.state == Ecology.ST_DISRUPTED and st_elec["tether_severs"].size() == 1,
		"severs=%s" % str(st_elec["tether_severs"]))

	var elite_sw := eco.spawn_enemy("elite_1", Ecology.ROLE_SWARMER, Vector3(140, 0, 0), true)
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_MAGNETIC, elite_sw.pos, 3.0, "m1", 1.0, 4.0))
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, elite_sw.pos, 3.0, "c1", 1.0, 4.0))
	_t.check("elite resists cryo_clamp heavy slow (clamped >= 0.85)", elite_sw.slow_mult >= Ecology.ELITE_SLOW_FLOOR,
		"slow=%.2f" % elite_sw.slow_mult)
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, elite_sw.pos, 3.0, "e1", 1.0, 3.0))
	eco.step(0.1, Vector3(130, 0, 0), Vector3.ZERO)
	_t.check("elite Swarmer resists electrified stun lock", elite_sw.state != Ecology.ST_DISRUPTED,
		"state=%s" % String(elite_sw.state))


func _test_qa_regressions_linear_reentrancy_telegraph() -> void:
	var field := EnvTags.new()
	var eco := Ecology.new(field)
	var pack: Array = []
	for i in 4:
		var e := eco.spawn_enemy("pack_%d" % i, Ecology.ROLE_SHIELDED_BULWARK, Vector3(float(i) * 0.5, 0, 0))
		e.shield_intact = false
		e.state = Ecology.ST_ADVANCE
		field.apply_tag(EnvTags.make_payload(EnvTags.TAG_SOAKED_CONDUCTIVE, e.pos, 1.5, "wet_%d" % i, 1.0, 5.0),
			"enemy:" + e.id, false)
		pack.append(e)
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, Vector3(0.75, 0, 0), 4.0, "arc_pack", 1.0, 3.0))
	for e in pack:
		var lost: float = e.max_hp - e.hp
		_t.near("packed enemy %s takes strictly linear 15.0 reaction damage" % e.id, lost, 15.0, 0.01)

	field.clear()
	var rig := JuryRig.new(field)
	rig.equip_by_id(&"slag_skid_crucible")
	rig.equip_by_id(&"brine_tap_vent")
	rig.add_heat(65.0)
	var rig_ref: WeakRef = weakref(rig)
	var reentrant_calls := [0]
	var vent_results: Array[Dictionary] = []
	rig.part_fired.connect(func(_r: Dictionary) -> void:
		var r_inst: Variant = rig_ref.get_ref()
		if r_inst == null:
			return
		reentrant_calls[0] += 1
		r_inst.dispatch(PartResource.TRIG_ON_SLAM, {"origin": Vector3.ZERO, "ball_speed_mps": 16.0})
	)
	rig.heat_band_changed.connect(func(_old: StringName, new_b: StringName) -> void:
		var r_inst: Variant = rig_ref.get_ref()
		if r_inst == null or new_b != JuryRig.BAND_REDLINE:
			return
		vent_results.append(r_inst.attempt_redline_vent(Vector3.ZERO, 16.0, &"slam"))
	)
	var disp := rig.dispatch(PartResource.TRIG_ON_SLAM, {"origin": Vector3.ZERO, "ball_speed_mps": 16.0})
	_t.check("re-entrant part_fired stays bounded and resolves slag_skid_crucible once",
		disp["fired"].size() <= 2 and reentrant_calls[0] <= 2,
		"fired=%d reentrant=%d" % [disp["fired"].size(), reentrant_calls[0]])
	_t.check("re-entrant attempt_redline_vent on heat_band_changed does not double-vent heat",
		rig.heat > 0.0 and rig.heat < JuryRig.HEAT_REDLINE_AT,
		"heat=%.1f vents=%d" % [rig.heat, vent_results.size()])

	eco.dispose()
	field.clear()
	eco = Ecology.new(field)
	var healer := eco.spawn_enemy("h_re", Ecology.ROLE_WELD_HEALER, Vector3(0, 0, 0))
	var wounded := eco.spawn_enemy("w_re", Ecology.ROLE_SWARMER, Vector3(3, 0, 0))
	wounded.hp = 15.0
	eco.step(0.2, Vector3(-20, 0, 0), Vector3.ZERO)
	_t.eq("healer tethers before spillway_discharge", healer.state, Ecology.ST_TETHER_HEAL)
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_SOAKED_CONDUCTIVE, healer.pos, 3.0, "puddle", 1.0, 5.0))
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, healer.pos, 3.0, "arc_long", 1.0, 4.5))
	_t.eq("spillway_discharge severs healer tether into DISRUPTED", healer.state, Ecology.ST_DISRUPTED)
	for _i in 13:
		eco.step(0.2, Vector3(-20, 0, 0), Vector3.ZERO)
	_t.check("healer recovers cleanly without re-stunning from lingering electrified serial",
		healer.state != Ecology.ST_DISRUPTED, "state=%s" % String(healer.state))

	eco.dispose()
	field.clear()
	eco = Ecology.new(field)
	var braced := eco.spawn_enemy("braced_bulk", Ecology.ROLE_SHIELDED_BULWARK, Vector3(5, 0, 0))
	var sniper := eco.spawn_enemy("active_snip", Ecology.ROLE_ARC_SNIPER, Vector3(10, 0, 0))
	eco.step(0.1, Vector3(25, 0, 0), Vector3.ZERO)
	_t.eq("Bulwark starts in ST_SHIELD_BRACE", braced.state, Ecology.ST_SHIELD_BRACE)
	_t.eq("Arc Sniper starts in ST_WINDUP", sniper.state, Ecology.ST_WINDUP)
	var alerted := eco.broadcast_aggro_ping(Vector3(6, 0, 0), 22.0, Vector3(0, 0, 0), "requisition_leech")
	_t.eq("public broadcast_aggro_ping alerts both Fleet bots", alerted.size(), 2)
	_t.eq("braced Bulwark enters F1 ST_ALERT_TELEGRAPH", braced.state, Ecology.ST_ALERT_TELEGRAPH)
	_t.eq("active Arc Sniper enters F1 ST_ALERT_TELEGRAPH", sniper.state, Ecology.ST_ALERT_TELEGRAPH)
	for _i in 4:
		eco.step(0.2, Vector3(25, 0, 0), Vector3.ZERO)
	_t.eq("Bulwark restores ST_SHIELD_BRACE after 0.65s telegraph expires", braced.state, Ecology.ST_SHIELD_BRACE)
	eco.dispose()


func _test_clean_reset_and_repeatability() -> void:
	var field := EnvTags.new()
	var rig := JuryRig.new(field)
	var eco := Ecology.new(field)
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_SLAG_COATED, Vector3.ZERO, 3.0, "s", 1.0, 5.0))
	rig.equip_by_id(&"arc_welder_dash")
	rig.add_heat(50.0)
	eco.spawn_prop("p1", Ecology.PROP_COOLANT_TANK, Vector3.ZERO)
	eco.clear()
	rig.clear()
	field.clear()
	_t.eq("EnvTags clear leaves zero zones", field.active_zone_count(), 0)
	_t.near("JuryRig clear resets heat to 0", rig.heat, 0.0)
	_t.eq("JuryRig clear empties equipped parts", rig.equipped_parts().size(), 0)
	_t.eq("Ecology clear removes props", eco.prop("p1"), null)
