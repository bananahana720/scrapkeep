extends SceneTree


const EnvTags := preload("res://src/experimental/env_tags.gd")
const PartResource := preload("res://src/experimental/part_resource.gd")
const JuryRig := preload("res://src/experimental/jury_rig_synergies.gd")
const Ecology := preload("res://src/experimental/ecology_actors.gd")
const ChunkSockets := preload("res://src/experimental/arena_chunk_socket.gd")
const DynamicSetpieces := preload("res://src/experimental/dynamic_setpieces.gd")
const AdversityDirector := preload("res://src/experimental/adversity_director.gd")
const RefurbishedElites := preload("res://src/experimental/refurbished_elites.gd")
const EncounterEngine := preload("res://src/experimental/encounter_engine.gd")
const T := preload("res://tests/support/t.gd")

const SMELTER_CHUNK_SCENE := preload("res://src/experimental/smelter_crane_chunk.tscn")

var _t := T.new("experimental_cross_pillar_test")


func _initialize() -> void:
	_test_schema_parity_and_emitter_subtag_rules()
	_test_setpieces_builds_ecology_live_composition()
	_test_director_elites_encounters_builds_ecology_composition()
	quit(_t.verdict())


func _test_schema_parity_and_emitter_subtag_rules() -> void:
	var tag_names: Array[String] = []
	for tag in EnvTags.CANONICAL_TAGS:
		tag_names.append(String(tag))
	_t.eq("EnvTags lists exactly the six canonical tags", tag_names,
		["electrified", "burning", "slag_coated", "magnetic", "coolant_brittle", "soaked_conductive"])
	_t.eq("EnvTags knows each canonical tag and refuses an unknown one",
		EnvTags.CANONICAL_TAGS.all(func(tag: StringName) -> bool: return EnvTags.is_canonical_tag(tag))
			and not EnvTags.is_canonical_tag(&"not_a_tag"),
		true)

	var p_setpiece := EnvTags.make_payload(
		EnvTags.TAG_MAGNETIC, Vector3(1, 2, 3), 10.0, "crane_test", 1.2, 2.0, EnvTags.BOUNDS_SETPIECE
	)
	_t.eq("a setpiece-bounds payload validates cleanly in EnvTags", EnvTags.validate_payload(p_setpiece), [])

	var p_elite := EnvTags.make_payload(
		&"slag_coated", Vector3(4, 0, 5), 6.0, "elite_test", 1.1, 3.0, EnvTags.BOUNDS_ELITE
	)
	_t.eq("an elite-bounds payload validates cleanly in EnvTags", EnvTags.validate_payload(p_elite), [])
	_t.eq("a default-bounds payload is valid in EnvTags",
		EnvTags.is_valid_payload(
			EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, Vector3.ZERO, 5.0, "part:test", 1.0, 4.0),
			EnvTags.BOUNDS_ELITE
		), true)

	var field := EnvTags.new()
	field.apply_tag(EnvTags.make_payload(EnvTags.TAG_MAGNETIC, Vector3.ZERO, 4.0, "setpiece:crane:0", 1.0, 5.0))
	var distinct_res := field.apply_tag(EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, Vector3.ZERO, 4.0, "setpiece:crane:1", 1.0, 5.0))
	_t.check("distinct 3-segment entities (setpiece:crane:0 vs :1) react cleanly",
		(distinct_res["reactions"] as Array).any(func(r: Dictionary) -> bool: return r["reaction_id"] == &"rail_surge"),
		"reactions=%d" % (distinct_res["reactions"] as Array).size())


func _test_setpieces_builds_ecology_live_composition() -> void:
	var field := EnvTags.new()
	var rig := JuryRig.new(field)
	var eco := Ecology.new(field)

	var chunk := SMELTER_CHUNK_SCENE.instantiate() as Node3D
	root.add_child(chunk)
	var val := ChunkSockets.validate_chunk(chunk)
	_t.eq("smelter_crane_chunk.tscn passes 10-point spatial validator", val["ok"], true)

	var setpieces := DynamicSetpieces.new()
	chunk.add_child(setpieces)
	var info := setpieces.setup_from_chunk(chunk, {"seed": 4242, "cruise_speed": 14.0})
	_t.check("DynamicSetpieces discovers crane, furnace, and cover slots",
		info["crane_id"] != "" and info["furnace_id"] != "" and int(info["cover_slot_count"]) >= 2,
		"info=%s" % str(info))

	var fref: WeakRef = weakref(field)
	var spref: WeakRef = weakref(setpieces)
	var setpiece_tags_seen := [0]
	var bridged_setpiece_facts: Array[Dictionary] = []

	var sp_to_env := func(payload: Dictionary) -> void:
		var f: Variant = fref.get_ref()
		if f != null:
			setpiece_tags_seen[0] += 1
			f.apply_tag(payload)
	setpieces.env_tag_emitted.connect(sp_to_env)

	var env_to_sp := func(payload: Dictionary) -> void:
		var sp: Variant = spref.get_ref()
		if sp == null:
			return
		var src := String(payload.get("source_id", ""))
		if src.begins_with("em_crane:") or src.begins_with("slag_furnace:") \
				or src.begins_with("cryo_pipe:") or src.begins_with("crane_magnet_drop:"):
			return
		var facts: Array[Dictionary] = sp.apply_external_tag(payload)
		bridged_setpiece_facts.append_array(facts)
	field.tag_applied.connect(env_to_sp)

	_t.check("equip magnetized_sawblades.tres", rig.equip_by_id(&"magnetized_sawblades")["ok"])
	_t.check("equip harpoon_grounding_spike.tres", rig.equip_by_id(&"harpoon_grounding_spike")["ok"])
	_t.check("equip brine_tap_vent.tres", rig.equip_by_id(&"brine_tap_vent")["ok"])

	var crane_ok := setpieces.trigger_setpiece(String(info["crane_id"]))
	_t.eq("EM Crane triggered cleanly", crane_ok, true)
	for _i in 18:
		setpieces.step(0.1, Vector3(20, 0, 20), Vector3(14, 0, 0), 2)
	var mag_zones: Array[Dictionary] = field.zones_at(Vector3.ZERO, 20.0, EnvTags.TAG_MAGNETIC)
	_t.check("EM Crane sweep emits world-space &'magnetic' into shared EnvTags",
		not mag_zones.is_empty() and setpiece_tags_seen[0] > 0,
		"mag_zones=%d seen=%d" % [mag_zones.size(), setpiece_tags_seen[0]])

	var crane_mag_origin: Vector3 = mag_zones[0]["origin"]
	var bulk := eco.spawn_enemy("basin_bulwark", Ecology.ROLE_SHIELDED_BULWARK, crane_mag_origin)
	for _i in 5:
		setpieces.step(0.1, Vector3(20, 0, 20), Vector3(14, 0, 0), 2)
	eco.step(0.1, Vector3(20, 0, 20), Vector3(14, 0, 0))
	_t.eq("EM Crane magnetic field pulls Ecology Shielded Bulwark into DISRUPTED",
		bulk.state, Ecology.ST_DISRUPTED)

	bridged_setpiece_facts.clear()
	var snap_res := rig.dispatch(PartResource.TRIG_ON_HARPOON_SNAP, {
		"origin": crane_mag_origin,
		"anchor_pos": crane_mag_origin,
		"clean_snap": true,
		"ball_speed_mps": 16.0,
	})
	_t.check("Harpoon Grounding Spike triggers rail_surge off EM Crane's &'magnetic' zone",
		(snap_res["reactions"] as Array).any(func(r: Dictionary) -> bool: return r["reaction_id"] == &"rail_surge"),
		"reactions=%d" % (snap_res["reactions"] as Array).size())
	_t.check("live JuryRig -> EnvTags -> DynamicSetpieces bridge supercharges active EM Crane magnet",
		bridged_setpiece_facts.any(func(f: Dictionary) -> bool: return String(f.get("kind", "")) == "crane_magnet_supercharged"),
		"bridged_facts=%s" % str(bridged_setpiece_facts))

	field.step(6.0)
	var furn_ok := setpieces.trigger_setpiece(String(info["furnace_id"]))
	_t.eq("Slag-Pour Furnace triggered cleanly", furn_ok, true)
	for _i in 22:
		setpieces.step(0.1, Vector3(22, 8.0, 22), Vector3(14, 0, 0), 2)
	var basin_tags: Array[StringName] = field.tags_at(Vector3.ZERO, 8.0)
	_t.check("Slag-Pour Furnace pours &'slag_coated' + &'burning' into shared EnvTags",
		basin_tags.has(EnvTags.TAG_SLAG_COATED) and basin_tags.has(EnvTags.TAG_BURNING),
		"basin_tags=%s" % str(basin_tags))

	var targets := [
		{"id": "sw_a", "pos": Vector3(1.0, 0.2, 0.0)},
		{"id": "sw_b", "pos": Vector3(-1.5, 0.2, 1.0)},
		{"id": "sw_c", "pos": Vector3(2.0, 0.2, -1.5)},
		{"id": "sw_d", "pos": Vector3(-2.0, 0.2, -1.0)},
	]
	var saw_res := rig.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {
		"origin": Vector3(0, 0.2, 8.0),
		"dir": Vector3.FORWARD,
		"target_pos": Vector3(0.0, 0.2, 0.0),
		"targets": targets,
		"ball_speed_mps": 16.0,
	})
	_t.check("Magnetized Sawblades chain lightning off Slag-Pour Furnace's molten basin",
		saw_res["chain_hits"].size() >= 3
			and (saw_res["reactions"] as Array).any(func(r: Dictionary) -> bool: return r["reaction_id"] == &"conductive_arc_chain"),
		"hits=%d" % saw_res["chain_hits"].size())

	bridged_setpiece_facts.clear()
	rig.add_heat(95.0)
	_t.eq("rig reaches REDLINE before vent", rig.heat_band(), JuryRig.BAND_REDLINE)
	var vent := rig.attempt_redline_vent(Vector3(0.0, 0.2, 0.0), 16.0, &"slam")
	_t.check("Brine-Tap redline vent triggers thermal_shatter_steam against Furnace &'burning'",
		vent["vented"] and (vent["reactions"] as Array).any(func(r: Dictionary) -> bool: return r["reaction_id"] == &"thermal_shatter_steam"),
		"vent_reactions=%d" % (vent["reactions"] as Array).size())
	var fsnap: Dictionary = setpieces.snapshot()["furnace"]
	_t.check("live Brine-Tap -> EnvTags -> DynamicSetpieces bridge flash-quenches Furnace into Tier-1 berms",
		bridged_setpiece_facts.any(func(f: Dictionary) -> bool: return String(f.get("kind", "")) == "slag_flash_quenched")
			and int(fsnap["intact_berms"]) == 3
			and (fsnap["berm_tiers"] as Array).all(func(t_val: int) -> bool: return t_val == 1),
		"berms=%s tiers=%s facts=%d" % [str(fsnap["intact_berms"]), str(fsnap["berm_tiers"]), bridged_setpiece_facts.size()])

	field.tag_applied.disconnect(env_to_sp)
	setpieces.env_tag_emitted.disconnect(sp_to_env)
	setpieces.teardown()
	root.remove_child(chunk)
	chunk.free()
	eco.dispose()
	rig.clear()
	field.clear()


func _test_director_elites_encounters_builds_ecology_composition() -> void:
	var field := EnvTags.new()
	var rig := JuryRig.new(field)
	var eco := Ecology.new(field)
	var director := AdversityDirector.new(777, &"spillway", 1.0)
	var encounters := EncounterEngine.new(777)

	var fref: WeakRef = weakref(field)
	var dir_tags := [0]
	var enc_tags := [0]
	var dir_bridge := func(payload: Dictionary) -> void:
		var f: Variant = fref.get_ref()
		if f != null:
			dir_tags[0] += 1
			f.apply_tag(payload)
	var enc_bridge := func(payload: Dictionary) -> void:
		var f: Variant = fref.get_ref()
		if f != null:
			enc_tags[0] += 1
			f.apply_tag(payload)
	director.env_tag_emitted.connect(dir_bridge)
	encounters.env_tag_emitted.connect(enc_bridge)

	_t.check("equip harpoon_grounding_spike.tres for combat composition", rig.equip_by_id(&"harpoon_grounding_spike")["ok"])
	_t.check("equip brine_tap_vent.tres for combat composition", rig.equip_by_id(&"brine_tap_vent")["ok"])

	var tank := eco.spawn_prop("spillway_tank", Ecology.PROP_COOLANT_TANK, Vector3(0.0, 0.0, 0.0))
	var slag_started := director.start_hazard(&"rising_slag_tide", Vector3.ZERO, 0.0)
	_t.eq("AdversityDirector starts rising_slag_tide", slag_started, true)
	for _i in 32:
		director.advance(0.25, Vector3(12.0, 8.0, 0.0), Vector3(16.0, 0.0, 0.0), 2, 14.0, false)
		eco.step(0.25, Vector3(12.0, 8.0, 0.0), Vector3(16.0, 0.0, 0.0))
	_t.check("Rising Slag Tide emits canonical tags into shared EnvTags and ruptures basin Coolant Tank",
		dir_tags[0] > 0 and not tank.intact
			and int(field.stats()["max_depth_seen"]) <= EnvTags.MAX_CASCADE_DEPTH,
		"dir_tags=%d tank_intact=%s max_depth=%d" % [dir_tags[0], str(tank.intact), int(field.stats()["max_depth_seen"])])

	for _i in 120:
		if director.hazard_phase == AdversityDirector.HazardPhase.IDLE or director.hazard_phase == AdversityDirector.HazardPhase.COOLDOWN:
			break
		director.advance(0.25, Vector3(12.0, 8.0, 0.0), Vector3(16.0, 0.0, 0.0), 2, 14.0, false)
	var mag_started := director.start_hazard(&"magnetic_storm", Vector3(20.0, 0.0, 0.0), 0.0)
	_t.eq("AdversityDirector starts magnetic_storm after slag cycle recedes", mag_started, true)
	for _i in 24:
		director.advance(0.25, Vector3(10.0, 0.0, 0.0), Vector3(16.0, 0.0, 0.0), 2, 14.0, true)
	var fast_vel := Vector3(16.0, 0.0, 0.0)
	var storm_force := director.compute_magnetic_force(Vector3(10.0, 0.0, 5.0), fast_vel, &"player_ball", 14.0)
	_t.check("Magnetic Storm applies non-braking slingshot acceleration to fast ball (Rule 9)",
		storm_force.length() > 0.1 and storm_force.dot(fast_vel.normalized()) >= -0.001,
		"force=%s" % str(storm_force))

	field.clear()
	var elite_pos := Vector3(60.0, 0.0, 60.0)
	var elite := RefurbishedElites.spawn_instance(&"slag_spill_exhaust", "elite_slag_1", elite_pos, 1.0)
	_t.check("RefurbishedElites spawns real .tres slag_spill_exhaust instance", elite != null)
	var elite_emitted := 0
	var reactions_before_elite := int(field.stats()["reactions"])
	for _i in 30:
		var etick: Dictionary = elite.step(0.1, elite_pos + Vector3(6.0, 0.0, 0.0), Vector3(14.0, 0.0, 0.0), 14.0)
		for tag_p in etick["env_tags"]:
			elite_emitted += 1
			field.apply_tag(tag_p)
		if elite_emitted >= 2:
			break
	var elite_tags: Array[StringName] = field.tags_at(elite_pos, 2.0)
	_t.check("Refurbished Elite co-emits slag_coated + burning into EnvTags with 0 self-consumption",
		elite_emitted >= 2
			and elite_tags.has(EnvTags.TAG_SLAG_COATED)
			and elite_tags.has(EnvTags.TAG_BURNING)
			and int(field.stats()["reactions"]) == reactions_before_elite,
		"emitted=%d tags=%s self_reactions=%d" % [elite_emitted, str(elite_tags), int(field.stats()["reactions"]) - reactions_before_elite])

	rig.add_heat(95.0)
	rig.attempt_redline_vent(elite_pos, 16.0, &"slam")
	rig.dispatch(PartResource.TRIG_ON_HARPOON_SNAP, {
		"origin": elite_pos, "anchor_pos": elite_pos, "clean_snap": true, "ball_speed_mps": 16.0,
	})
	var live_elite_tags: Array[StringName] = field.tags_at(elite_pos, 4.0)
	var bounty_awarded := {}
	var plates_broken_total := 0
	for _h in 20:
		var ehit: Dictionary = elite.apply_hit(65.0, 16.0, 14.0, live_elite_tags, elite_pos)
		plates_broken_total += int(ehit["plates_broken"])
		for ptag in ehit["env_tags"]:
			field.apply_tag(ptag)
		if not (ehit["bounty"] as Dictionary).is_empty():
			bounty_awarded = ehit["bounty"]
		if elite.is_defeated():
			break
	var second_hit: Dictionary = elite.apply_hit(50.0, 16.0, 14.0, live_elite_tags, elite_pos)
	_t.check("JuryRig live EnvTags shatter Refurbished Elite plates and pay once-only bounty",
		elite.is_defeated() and plates_broken_total >= 2 and not bounty_awarded.is_empty()
			and (second_hit["bounty"] as Dictionary).is_empty(),
		"defeated=%s plates=%d bounty=%s" % [str(elite.is_defeated()), plates_broken_total, str(bounty_awarded)])

	field.clear()
	enc_tags[0] = 0
	var reactions_pre_pod := int(field.stats()["reactions"])
	var pod_ctx := {
		"ball_pos": Vector3(-50.0, 0.0, -50.0), "ball_vel": Vector3(14.0, 0.0, 0.0),
		"cruise_mps": 14.0, "warden_awake": false, "biome_id": &"spillway",
		"elapsed_s": 30.0, "hazard_tier": 1, "unrefined_scrap": 10, "courier_bounty": 0,
	}
	encounters.random_cooldown_s = 0.0
	var pod_started := false
	var pod_origin := Vector3.ZERO
	for _try in 30:
		encounters.advance(0.1, pod_ctx)
		if not encounters.active_random.is_empty():
			if encounters.active_random["kind"] == &"airdrop_salvage_pod":
				pod_origin = encounters.active_random["origin"]
				pod_started = true
				break
			encounters.resolve_active_random(&"expired", pod_ctx)
			encounters.random_cooldown_s = 0.0
	for _i in 50:
		encounters.advance(0.1, pod_ctx)
		if enc_tags[0] >= 2:
			break
	var pod_tags: Array[StringName] = field.tags_at(pod_origin, 3.0)
	_t.check("Air-Drop Salvage Pod emits burning + slag_coated via EncounterEngine with 0 self-consumption",
		pod_started and enc_tags[0] >= 2
			and pod_tags.has(EnvTags.TAG_BURNING) and pod_tags.has(EnvTags.TAG_SLAG_COATED)
			and int(field.stats()["reactions"]) == reactions_pre_pod,
		"started=%s enc_tags=%d pod_tags=%s self_reactions=%d" % [str(pod_started), enc_tags[0], str(pod_tags), int(field.stats()["reactions"]) - reactions_pre_pod])
	encounters.resolve_active_random(&"won", pod_ctx)

	var hauler := eco.spawn_courier("hauler_x", Ecology.COURIER_HAULER_DRONE, Vector3(40.0, 0.0, 0.0), Vector3(100.0, 0.0, 0.0))
	var guard_bulk := eco.spawn_enemy("guard_bulk", Ecology.ROLE_SHIELDED_BULWARK, Vector3(46.0, 0.0, 0.0))
	var kill_courier := eco.strike_courier("hauler_x", 100.0, Vector3(38.0, 0.0, 0.0), true)
	_t.eq("Hauler Courier disabled and triggers F1 ST_ALERT_TELEGRAPH on braced guard Bulwark",
		hauler.state == Ecology.ST_DISABLED and guard_bulk.state == Ecology.ST_ALERT_TELEGRAPH, true)

	var courier_bounty_val := int(kill_courier["spilled_scrap"]) * 10 + int(kill_courier["spilled_cores"]) * 60
	var weights_poor := encounters.evaluate_random_weights({
		"biome_id": &"spillway", "elapsed_s": 60.0, "hazard_tier": 2,
		"unrefined_scrap": 20, "courier_bounty": 0,
	})
	var weights_rich := encounters.evaluate_random_weights({
		"biome_id": &"spillway", "elapsed_s": 60.0, "hazard_tier": 2,
		"unrefined_scrap": 150, "courier_bounty": courier_bounty_val,
	})
	_t.check("Courier bounty + carried scrap dynamically spikes EncounterEngine Greed Ambush weight",
		float(weights_rich[&"greed_ambush_swarm"]) > float(weights_poor[&"greed_ambush_swarm"]) + 1.5,
		"poor=%.2f rich=%.2f" % [float(weights_poor[&"greed_ambush_swarm"]), float(weights_rich[&"greed_ambush_swarm"])])

	var beacon_pos := Vector3(0.0, 0.0, 30.0)
	encounters.register_triggered_volume("smelter_beacon", &"scrap_beacon_lockdown", beacon_pos, &"spillway")
	encounters.advance(0.1, {
		"ball_pos": Vector3(0.0, 16.1, 30.0), "ball_vel": Vector3(15.0, 0.0, 0.0),
		"cruise_mps": 14.0, "warden_awake": false, "biome_id": &"spillway",
	})
	_t.eq("rolling on Tier-2 gantry above Tier-0 beacon never triggers lockdown", encounters.has_active_lockdown(), false)

	encounters.advance(0.1, {
		"ball_pos": beacon_pos, "ball_vel": Vector3(15.0, 0.0, 0.0),
		"cruise_mps": 14.0, "warden_awake": false, "biome_id": &"spillway",
	})
	_t.eq("entering Tier-0 Scrap Beacon activates lockdown cleanly", encounters.has_active_lockdown(), true)

	for _wave in 2:
		for _kill in 8:
			encounters.report_encounter_kill(16.0, 14.0)
		for _step in 12:
			encounters.advance(0.25, {
				"ball_pos": beacon_pos, "ball_vel": Vector3(16.0, 0.0, 0.0),
				"cruise_mps": 14.0, "warden_awake": false, "biome_id": &"spillway",
			})

	field.clear()
	rig.add_heat(95.0)
	rig.attempt_redline_vent(beacon_pos, 16.0, &"slam")
	rig.dispatch(PartResource.TRIG_ON_HARPOON_SNAP, {
		"origin": beacon_pos, "anchor_pos": beacon_pos, "clean_snap": true, "ball_speed_mps": 16.0,
	})
	var live_apex_tags: Array[StringName] = field.tags_at(beacon_pos, 4.0)
	_t.check("JuryRig .tres parts populate live tags at beacon_pos for Apex Construct fight",
		live_apex_tags.has(EnvTags.TAG_COOLANT_BRITTLE) and live_apex_tags.has(EnvTags.TAG_ELECTRIFIED),
		"live_apex_tags=%s" % str(live_apex_tags))

	var payout_seen := false
	for _hit in 40:
		var apex_res := encounters.damage_apex_construct(80.0, 18.0, 14.0, live_apex_tags)
		if not (apex_res["payout"] as Dictionary).is_empty():
			payout_seen = true
		if not encounters.has_active_lockdown():
			break
	_t.check("Apex Construct defeated with live JuryRig EnvTags -> lockdown opens cleanly and pays once",
		not encounters.has_active_lockdown() and payout_seen,
		"locked=%s payout=%s" % [str(encounters.has_active_lockdown()), str(payout_seen)])

	director.env_tag_emitted.disconnect(dir_bridge)
	encounters.env_tag_emitted.disconnect(enc_bridge)
	eco.dispose()
	rig.clear()
	field.clear()
	_t.eq("final shared EnvTags clear leaves zero active zones", field.active_zone_count(), 0)
