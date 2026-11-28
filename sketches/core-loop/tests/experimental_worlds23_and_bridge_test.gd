extends SceneTree


const T := preload("res://tests/support/t.gd")
const EnvTags := preload("res://src/experimental/env_tags.gd")
const PartResource := preload("res://src/experimental/part_resource.gd")
const JuryRig := preload("res://src/experimental/jury_rig_synergies.gd")
const Ecology := preload("res://src/experimental/ecology_actors.gd")
const AdversityDirector := preload("res://src/experimental/adversity_director.gd")
const RefurbishedElites := preload("res://src/experimental/refurbished_elites.gd")
const EncounterEngine := preload("res://src/experimental/encounter_engine.gd")
const LiveRunBridge := preload("res://src/experimental/live_run_bridge.gd")
const ExperimentalAudioBank := preload("res://src/presentation/experimental_audio_bank.gd")

const CHUNK_PATH := "res://src/experimental/smelter_crane_chunk.tscn"
const MC_SEEDS_PER_WORLD := 32
const MC_DURATION_S := 45.0
const MC_DT := 0.25
const MC_STEPS := int(MC_DURATION_S / MC_DT)
const ARENA_HALF_M := 27.0
const PLAYER_MAX_HP := 120.0

const ARCHETYPES: Array[StringName] = [&"staller", &"flow_runner", &"synergy_builder"]
const WORLD_SPECS: Array[Dictionary] = [
	{
		"biome_id": &"spillway",
		"stage_index": 1,
		"director_path": AdversityDirector.DEFAULT_CONFIG_PATH,
		"encounter_path": EncounterEngine.DEFAULT_CATALOG_PATH,
		"loadouts": [
			[&"magnetized_sawblades", &"arc_welder_dash", &"brine_tap_vent"],
			[&"magnetized_sawblades", &"slag_skid_crucible", &"thermite_flail_spool"],
			[&"choir_arc_lance", &"arc_welder_dash", &"overclock_capacitor_shunt"],
		],
	},
	{
		"biome_id": &"dig",
		"stage_index": 3,
		"director_path": AdversityDirector.DIG_CONFIG_PATH,
		"encounter_path": EncounterEngine.DIG_CATALOG_PATH,
		"loadouts": [
			[&"caustic_bore_auger", &"tremor_pile_driver", &"cryo_slurry_manifold"],
			[&"caustic_bore_auger", &"slag_skid_crucible", &"overclock_capacitor_shunt"],
			[&"magnetized_sawblades", &"tremor_pile_driver", &"brine_tap_vent"],
		],
	},
	{
		"biome_id": &"highdraft",
		"stage_index": 5,
		"director_path": AdversityDirector.HIGHDRAFT_CONFIG_PATH,
		"encounter_path": EncounterEngine.HIGHDRAFT_CATALOG_PATH,
		"loadouts": [
			[&"choir_arc_lance", &"gale_shear_slipstream", &"overclock_capacitor_shunt"],
			[&"choir_arc_lance", &"harpoon_grounding_spike", &"cryo_slurry_manifold"],
			[&"caustic_bore_auger", &"gale_shear_slipstream", &"thermite_flail_spool"],
		],
	},
]

const EXPECTED_AUDIO_EVENTS: Array[String] = [
	"smelter_ambience",
	"hazard_squall_alarm",
	"apex_lockdown",
	"pa_salvage_press_lockdown",
	"pa_foreman_rig_deployed",
	"pa_hazard_squall_incoming",
	"pa_airdrop_pod_inbound",
]

var t := T.new("experimental_worlds23_and_bridge_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ExperimentalAudioBank._reset()
	_test_worlds23_configs_elites_and_w4_clarity()
	_test_worlds23_hazards_and_encounters()
	_test_batch2_parts_and_cross_world_synergies()
	await _test_live_run_bridge_and_audio_bank()
	_test_graph_and_code_hygiene()
	_test_env_tag_bounds_table()
	_run_three_world_monte_carlo_proof()
	ExperimentalAudioBank._reset()
	quit(t.verdict())


func _test_worlds23_configs_elites_and_w4_clarity() -> void:
	var dig_dir_cfg := ResourceLoader.load(AdversityDirector.DIG_CONFIG_PATH)
	var dig_enc_cat := ResourceLoader.load(EncounterEngine.DIG_CATALOG_PATH)
	var hd_dir_cfg := ResourceLoader.load(AdversityDirector.HIGHDRAFT_CONFIG_PATH)
	var hd_enc_cat := ResourceLoader.load(EncounterEngine.HIGHDRAFT_CATALOG_PATH)

	t.check("dig_adversity_config.tres loads cleanly", dig_dir_cfg != null)
	t.check("dig_encounter_catalog.tres loads cleanly", dig_enc_cat != null)
	t.check("highdraft_adversity_config.tres loads cleanly", hd_dir_cfg != null)
	t.check("highdraft_encounter_catalog.tres loads cleanly", hd_enc_cat != null)
	if dig_dir_cfg == null or dig_enc_cat == null or hd_dir_cfg == null or hd_enc_cat == null:
		return

	t.eq("dig director biome id is dig", StringName(dig_dir_cfg.get("default_biome_id")), &"dig")
	t.eq("dig catalog biome id is dig", StringName(dig_enc_cat.get("default_biome_id")), &"dig")
	t.eq("highdraft director biome id is highdraft", StringName(hd_dir_cfg.get("default_biome_id")), &"highdraft")
	t.eq("highdraft catalog biome id is highdraft", StringName(hd_enc_cat.get("default_biome_id")), &"highdraft")

	var full_pool := RefurbishedElites.load_default_pool()
	t.eq("total authored Refurbished Elites is 10 (6 Spillway + 4 Dig/Highdraft)", full_pool.size(), 10)

	var new_ids := [&"corrosive_bore_warden", &"cryo_slurry_tanker", &"gale_shear_harrier", &"choir_resonator_pylon"]
	var pool_ids := RefurbishedElites.variant_ids(full_pool)
	for nid in new_ids:
		t.check("new elite %s present in pool" % String(nid), pool_ids.has(nid))

	var dig_pool_ids := RefurbishedElites.variant_ids(dig_dir_cfg.get("elite_pool"))
	t.check("dig config wires corrosive_bore_warden and cryo_slurry_tanker",
		dig_pool_ids.has(&"corrosive_bore_warden") and dig_pool_ids.has(&"cryo_slurry_tanker"),
		"dig_pool=%s" % str(dig_pool_ids))

	var hd_pool_ids := RefurbishedElites.variant_ids(hd_dir_cfg.get("elite_pool"))
	t.check("highdraft config wires gale_shear_harrier and choir_resonator_pylon",
		hd_pool_ids.has(&"gale_shear_harrier") and hd_pool_ids.has(&"choir_resonator_pylon"),
		"hd_pool=%s" % str(hd_pool_ids))

	var raw_tokens := ["soaked_conductive", "coolant_brittle", "slag_coated", "electrified", "burning", "magnetic"]
	var w4_violations: Array[String] = []
	var clarity_ok := true
	for res in full_pool:
		var spec: Dictionary = res.call("to_spec_dict")
		var cue := String(spec.get("counterplay_cue", ""))
		if cue == "" or String(spec.get("silhouette_cue", "")) == "" \
				or String(spec.get("movement_cadence", "")) == "" \
				or float(spec.get("tell_s", 0.0)) < RefurbishedElites.MIN_TELL_S \
				or not EnvTags.CANONICAL_TAGS.has(StringName(spec.get("ability_tag", &""))):
			clarity_ok = false
		for tok in raw_tokens:
			if cue.contains(tok):
				w4_violations.append("%s:%s" % [String(spec["id"]), tok])
	t.check("all 10 elites pass clarity, >=0.6s tell and canonical env tags", clarity_ok)
	t.eq("LEGIBILITY W4: zero raw tag tokens in any elite counterplay_cue", w4_violations, [])

	for world_row in [
		{"name": "dig", "cfg": dig_dir_cfg, "elite": &"corrosive_bore_warden"},
		{"name": "highdraft", "cfg": hd_dir_cfg, "elite": &"choir_resonator_pylon"},
	]:
		var wname := String(world_row["name"])
		var cfg: Resource = world_row["cfg"]
		var d := AdversityDirector.new(88, StringName(cfg.get("default_biome_id")), 1.15, cfg)
		var snap_early := d.behavioral_escalation_snapshot()
		var el_early := RefurbishedElites.spawn_instance(world_row["elite"], "early_" + wname, Vector3.ZERO, d.stage_threat)
		var pos := Vector3.ZERO
		for _s in 320:
			var vel := Vector3(15.0, 0.0, 0.0)
			pos += vel * 0.5
			d.advance(0.5, pos, vel, 3, 14.0, true)
		var snap_late := d.behavioral_escalation_snapshot()
		var el_late := RefurbishedElites.spawn_instance(world_row["elite"], "late_" + wname, Vector3.ZERO, d.stage_threat)
		t.check("%s escalates hazard_tier >= 4" % wname, int(snap_late["hazard_tier"]) >= 4, "tier=%d" % int(snap_late["hazard_tier"]))
		t.near("%s non-sponge: base_hull_hp_scale stays constant" % wname,
			float(snap_late["base_hull_hp_scale"]), float(snap_early["base_hull_hp_scale"]), 0.0001)
		t.near("%s non-sponge: elite max_hull_hp stays constant across tiers" % wname,
			el_late.max_hull_hp, el_early.max_hull_hp, 0.0001)
		t.check("%s unlocks more packs and hazards at higher tier" % wname,
			(snap_late["unlocked_packs"] as Array).size() > (snap_early["unlocked_packs"] as Array).size()
				and (snap_late["unlocked_hazards"] as Array).size() > (snap_early["unlocked_hazards"] as Array).size())


func _test_worlds23_hazards_and_encounters() -> void:
	var dig_cfg := ResourceLoader.load(AdversityDirector.DIG_CONFIG_PATH)
	var dig_cat := ResourceLoader.load(EncounterEngine.DIG_CATALOG_PATH)
	var dig_dir := AdversityDirector.new(202, &"dig", 1.0, dig_cfg)

	var base_sight := dig_dir.current_sightline_m()
	t.eq("dig corrosive_acid_squall starts cleanly", dig_dir.start_hazard(&"corrosive_acid_squall", Vector3.ZERO, 0.0), true)
	for _i in 90:
		dig_dir.advance(0.1, Vector3(12.0, 0.0, 0.0), Vector3(15.0, 0.0, 0.0), 2, 14.0, true)
		if dig_dir.hazard_phase == AdversityDirector.HazardPhase.PEAK:
			break
	t.eq("dig corrosive_acid_squall reaches PEAK", dig_dir.hazard_phase, AdversityDirector.HazardPhase.PEAK)
	t.check("dig corrosive_acid_squall compresses sightline and boosts close silhouettes",
		dig_dir.current_sightline_m() < base_sight * 0.35
			and dig_dir.close_silhouette_boost() > 1.5
			and dig_dir.telegraph_contrast_boost() > 1.35,
		"sight=%.1f base=%.1f sil=%.2f" % [dig_dir.current_sightline_m(), base_sight, dig_dir.close_silhouette_boost()])

	var dig_dir2 := AdversityDirector.new(203, &"dig", 1.0, dig_cfg)
	t.eq("dig subterranean_tremor starts cleanly", dig_dir2.start_hazard(&"subterranean_tremor", Vector3.ZERO, 0.0), true)
	for _i in 80:
		dig_dir2.advance(0.1, Vector3(8.0, 0.0, 0.0), Vector3(15.0, 0.0, 0.0), 2, 14.0, true)
		if dig_dir2.hazard_phase == AdversityDirector.HazardPhase.PEAK:
			break
	var fast_vel := Vector3(16.0, 0.0, 0.0)
	var tremor_fast := dig_dir2.compute_tremor_force(Vector3(6.0, 0.0, 2.0), fast_vel, 14.0)
	var tremor_slow := dig_dir2.compute_tremor_force(Vector3(6.0, 0.0, 2.0), Vector3(2.0, 0.0, 0.0), 14.0)
	t.check("dig subterranean_tremor jolts stalled ball and never brakes fast ball",
		tremor_slow.length() > 5.0 and tremor_fast.dot(fast_vel.normalized()) >= -0.001,
		"slow=%.2f fast_dot=%.3f" % [tremor_slow.length(), tremor_fast.dot(fast_vel.normalized())])

	var dig_enc := EncounterEngine.new(204, dig_cat)
	var dig_w_poor := dig_enc.evaluate_random_weights({"biome_id": &"dig", "elapsed_s": 30.0, "hazard_tier": 2, "unrefined_scrap": 20, "courier_bounty": 0})
	var dig_w_rich := dig_enc.evaluate_random_weights({"biome_id": &"dig", "elapsed_s": 30.0, "hazard_tier": 2, "unrefined_scrap": 240, "courier_bounty": 60})
	t.check("dig Rogue Compactor chase outweights Air-Drop Pod and Greed Swarm spikes on high scrap",
		float(dig_w_poor[&"rogue_compactor_chase"]) > float(dig_w_poor[&"airdrop_salvage_pod"])
			and float(dig_w_poor[&"greed_ambush_swarm"]) == 0.0
			and float(dig_w_rich[&"greed_ambush_swarm"]) > 2.5,
		"poor=%s rich=%s" % [str(dig_w_poor), str(dig_w_rich)])

	var dig_origin := Vector3(10.0, 0.0, 10.0)
	dig_enc.register_triggered_volume("dig_bore_beacon", &"scrap_beacon_lockdown", dig_origin, &"dig")
	var dig_act := dig_enc.activate_triggered("dig_bore_beacon", {"active_lockdown": false, "warden_awake": false})
	t.eq("dig Bore-Rig lockdown activates", bool(dig_act["started"]), true)
	for _w in 2:
		for _k in 6:
			dig_enc.report_encounter_kill(16.0, 14.0)
		for _s in 12:
			dig_enc.advance(0.25, {"ball_pos": dig_origin, "ball_vel": Vector3(15.0, 0.0, 0.0), "cruise_mps": 14.0, "warden_awake": false, "biome_id": &"dig"})
	var dig_vol: Dictionary = dig_enc.triggered_volumes["dig_bore_beacon"]
	t.eq("dig lockdown spawns Bore-Rig Apex Construct", dig_vol["state"], &"apex_active")
	t.check("Bore-Rig Apex Construct has expected name and 5 plates",
		dig_vol["apex"] != null and dig_vol["apex"].display_name == "Bore-Rig Apex Construct" and dig_vol["apex"].intact_plate_count() == 5,
		"name=%s plates=%d" % [dig_vol["apex"].display_name if dig_vol["apex"] != null else "null", dig_vol["apex"].intact_plate_count() if dig_vol["apex"] != null else -1])
	var dig_paid := false
	for _h in 30:
		var res := dig_enc.damage_apex_construct(90.0, 18.0, 14.0, [&"burning", &"coolant_brittle"])
		if not (res["payout"] as Dictionary).is_empty():
			dig_paid = true
		if not dig_enc.has_active_lockdown():
			break
	t.check("Bore-Rig Apex Construct settles cleanly and pays once", not dig_enc.has_active_lockdown() and dig_paid)

	var hd_cfg := ResourceLoader.load(AdversityDirector.HIGHDRAFT_CONFIG_PATH)
	var hd_cat := ResourceLoader.load(EncounterEngine.HIGHDRAFT_CATALOG_PATH)
	var hd_dir := AdversityDirector.new(303, &"highdraft", 1.0, hd_cfg)
	t.eq("highdraft gale_shear_crosswind starts cleanly", hd_dir.start_hazard(&"gale_shear_crosswind", Vector3.ZERO, 0.0), true)
	for _i in 80:
		hd_dir.advance(0.1, Vector3(6.0, 0.0, 0.0), Vector3(15.0, 0.0, 0.0), 2, 14.0, true)
		if hd_dir.hazard_phase == AdversityDirector.HazardPhase.PEAK:
			break
	var gale_ball := hd_dir.compute_crosswind_force(Vector3(6.0, 0.0, 0.0), fast_vel, &"player_ball", 14.0)
	var gale_scrap := hd_dir.compute_crosswind_force(Vector3(6.0, 0.0, 0.0), Vector3.ZERO, &"loose_scrap", 14.0)
	var gale_proj := hd_dir.compute_crosswind_force(Vector3(6.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0), &"metal_projectile", 14.0)
	t.check("highdraft gale_shear_crosswind deflects scrap/projectiles and never brakes fast ball",
		gale_scrap.length() > 5.0 and gale_proj.length() > 5.0 and gale_ball.length() > 5.0 and gale_ball.dot(fast_vel.normalized()) >= -0.001,
		"ball=%s scrap=%.1f proj=%.1f" % [str(gale_ball), gale_scrap.length(), gale_proj.length()])

	var harrier := RefurbishedElites.spawn_instance(&"gale_shear_harrier", "harrier_1", Vector3.ZERO, 1.0)
	var harrier_accel := Vector3.ZERO
	for _s in 30:
		var htick := harrier.step(0.1, Vector3(6.0, 0.0, 2.0), fast_vel, 14.0)
		if (htick["ball_accel"] as Vector3).length() > 0.1:
			harrier_accel = htick["ball_accel"]
			break
	t.check("gale_shear_harrier applies data-driven non-braking tether slingshot",
		harrier_accel.length() > 1.0 and harrier_accel.dot(fast_vel.normalized()) >= -0.001,
		"accel=%s" % str(harrier_accel))

	var hd_enc := EncounterEngine.new(304, hd_cat)
	var hd_w := hd_enc.evaluate_random_weights({"biome_id": &"highdraft", "elapsed_s": 30.0, "hazard_tier": 2, "unrefined_scrap": 10, "courier_bounty": 0})
	t.check("highdraft Air-Drop Salvage Pod outweights Rogue Compactor",
		float(hd_w[&"airdrop_salvage_pod"]) > float(hd_w[&"rogue_compactor_chase"]) * 2.0,
		"hd_weights=%s" % str(hd_w))

	var hd_origin := Vector3(-12.0, 0.0, 12.0)
	hd_enc.register_triggered_volume("hd_choir_beacon", &"scrap_beacon_lockdown", hd_origin, &"highdraft")
	hd_enc.activate_triggered("hd_choir_beacon", {"active_lockdown": false, "warden_awake": false})
	for _w in 2:
		for _k in 6:
			hd_enc.report_encounter_kill(16.0, 14.0)
		for _s in 12:
			hd_enc.advance(0.25, {"ball_pos": hd_origin, "ball_vel": Vector3(15.0, 0.0, 0.0), "cruise_mps": 14.0, "warden_awake": false, "biome_id": &"highdraft"})
	var hd_vol: Dictionary = hd_enc.triggered_volumes["hd_choir_beacon"]
	t.eq("highdraft lockdown spawns Sky-Dredge Choir Relay", hd_vol["state"], &"apex_active")
	t.check("Sky-Dredge Choir Relay has 6 plates and backfires on strip",
		hd_vol["apex"] != null and hd_vol["apex"].display_name == "Sky-Dredge Choir Relay" and hd_vol["apex"].intact_plate_count() == 6)
	var saw_backfire := false
	var hd_paid := false
	for _h in 35:
		var res := hd_enc.damage_apex_construct(95.0, 18.0, 14.0, [&"slag_coated", &"burning"])
		if bool((res["hit"] as Dictionary).get("backfire_friendly_fire", false)):
			saw_backfire = true
		if not (res["payout"] as Dictionary).is_empty():
			hd_paid = true
		if not hd_enc.has_active_lockdown():
			break
	t.check("Sky-Dredge Choir Relay backfires on plate strip, opens lockdown, and pays once",
		saw_backfire and not hd_enc.has_active_lockdown() and hd_paid,
		"backfire=%s paid=%s" % [str(saw_backfire), str(hd_paid)])


func _test_batch2_parts_and_cross_world_synergies() -> void:
	t.eq("Batch 1 catalogue remains 8 parts for compatibility", JuryRig.catalogue().size(), 8)
	t.eq("Batch 2 catalogue loads 6 new .tres parts", JuryRig.catalogue_batch2().size(), 6)
	t.eq("Combined catalogue loads 14 .tres parts", JuryRig.all_catalogue().size(), 14)
	t.eq("All 14 .tres PartResources pass validation", JuryRig.validate_all_catalogues(), [])

	var rig_src := FileAccess.get_file_as_string("res://src/experimental/jury_rig_synergies.gd")
	var pair_re := RegEx.new()
	var hardcoded_pair_hits: Array[String] = []
	for p in JuryRig.all_catalogue():
		var pid_s := String(p.id)
		pair_re.compile('(part\\.id\\s*==|has_part\\(|==\\s*)&"' + pid_s + '"')
		if pair_re.search(rig_src) != null:
			hardcoded_pair_hits.append(pid_s)
	t.eq("zero hardcoded part-ID pairwise checks in jury_rig_synergies.gd", hardcoded_pair_hits, [])

	var slot_counts := {0: 0, 1: 0, 2: 0}
	for p in JuryRig.catalogue_batch2():
		slot_counts[int(p.slot)] = int(slot_counts[int(p.slot)]) + 1
	t.eq("Batch 2 covers all 3 slots evenly (2 WEAPON, 2 DASH_LINE, 2 CORE_HUSK)", slot_counts, {0: 2, 1: 2, 2: 2})

	var f_trade := EnvTags.new()
	var r_trade := JuryRig.new(f_trade)
	r_trade.equip_by_id(&"caustic_bore_auger")
	var stall_fire := r_trade.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {"origin": Vector3.ZERO, "dir": Vector3.FORWARD, "ball_speed_mps": 3.0})
	var fast_fire := r_trade.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {"origin": Vector3.ZERO, "dir": Vector3.FORWARD, "ball_speed_mps": 16.0})
	t.check("caustic_bore_auger penalizes stalled fire with extra overpressure heat",
		float(stall_fire["fired"][0]["heat_delta"]) > float(fast_fire["fired"][0]["heat_delta"]) + 5.0,
		"stall=%.1f fast=%.1f" % [float(stall_fire["fired"][0]["heat_delta"]), float(fast_fire["fired"][0]["heat_delta"])])

	var f1 := EnvTags.new()
	var r1 := JuryRig.new(f1)
	var syn1: Array[Dictionary] = []
	r1.synergy_emerged.connect(func(s: Dictionary) -> void: syn1.append(s))
	r1.equip_by_id(&"cryo_slurry_manifold")
	r1.equip_by_id(&"tremor_pile_driver")
	r1.equip_by_id(&"caustic_bore_auger")
	var targets := [
		{"id": "t1", "pos": Vector3(1.0, 0.0, 0.0)},
		{"id": "t2", "pos": Vector3(-1.5, 0.0, 1.0)},
		{"id": "t3", "pos": Vector3(0.5, 0.0, -2.0)},
	]
	r1.dispatch(PartResource.TRIG_ON_PROP_RUPTURE, {"origin": Vector3.ZERO, "ball_speed_mps": 15.0})
	r1.dispatch(PartResource.TRIG_ON_SLAM, {"origin": Vector3.ZERO, "ball_speed_mps": 16.0})
	var auger_res := r1.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {
		"origin": Vector3(0.0, 0.0, 4.0), "dir": Vector3.FORWARD, "target_pos": Vector3.ZERO,
		"targets": targets, "ball_speed_mps": 16.0,
	})
	var has_dig_syn := syn1.any(func(s: Dictionary) -> bool:
		var prods: Array = s["producers"]
		return prods.has(&"cryo_slurry_manifold") and prods.has(&"tremor_pile_driver")
	)
	t.check("Synergy 1 (Dig Corrosive-Cryo Bore Cascade) emerges via tags without pairwise checks",
		has_dig_syn and auger_res["chain_hits"].size() >= 2,
		"synergies=%d auger_hits=%d" % [syn1.size(), auger_res["chain_hits"].size()])

	var f2 := EnvTags.new()
	var r2 := JuryRig.new(f2)
	var syn2: Array[Dictionary] = []
	r2.synergy_emerged.connect(func(s: Dictionary) -> void: syn2.append(s))
	r2.equip_by_id(&"gale_shear_slipstream")
	r2.equip_by_id(&"choir_arc_lance")
	r2.equip_by_id(&"overclock_capacitor_shunt")
	r2.dispatch(PartResource.TRIG_ON_DASH, {"origin": Vector3.ZERO, "dir": Vector3.FORWARD, "dash_length_m": 6.0, "ball_speed_mps": 17.0})
	var lance_res := r2.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {
		"origin": Vector3.ZERO, "dir": Vector3.FORWARD, "target_pos": Vector3(0.0, 0.0, -6.0),
		"targets": [
			{"id": "h1", "pos": Vector3(0.5, 0.0, -6.0)},
			{"id": "h2", "pos": Vector3(-1.0, 0.0, -5.5)},
			{"id": "h3", "pos": Vector3(1.5, 0.0, -6.5)},
		],
		"ball_speed_mps": 17.0,
	})
	var shunt_woke := (lance_res["fired"] as Array).any(func(fp: Dictionary) -> bool: return fp["part_id"] == &"overclock_capacitor_shunt")
	var has_hd_syn := syn2.any(func(s: Dictionary) -> bool:
		var prods: Array = s["producers"]
		return prods.has(&"choir_arc_lance") and (prods.has(&"gale_shear_slipstream") or prods.has(&"overclock_capacitor_shunt"))
	)
	t.check("Synergy 2 (Highdraft Gale-Choir Railstorm) chains dash -> lance -> reactive shunt",
		shunt_woke and has_hd_syn and lance_res["chain_hits"].size() >= 3,
		"shunt_woke=%s synergies=%d hits=%d" % [str(shunt_woke), syn2.size(), lance_res["chain_hits"].size()])

	var f3 := EnvTags.new()
	var r3 := JuryRig.new(f3)
	var syn3: Array[Dictionary] = []
	r3.synergy_emerged.connect(func(s: Dictionary) -> void: syn3.append(s))
	r3.equip_by_id(&"slag_skid_crucible")
	r3.equip_by_id(&"caustic_bore_auger")
	r3.equip_by_id(&"overclock_capacitor_shunt")
	r3.dispatch(PartResource.TRIG_ON_SLAM, {"origin": Vector3.ZERO, "ball_speed_mps": 16.0})
	var press_res := r3.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {
		"origin": Vector3(0.0, 0.0, 4.0), "dir": Vector3.FORWARD, "target_pos": Vector3.ZERO,
		"targets": targets, "ball_speed_mps": 16.0,
	})
	var saw_boiler_and_shunt := (press_res["reactions"] as Array).any(func(rx: Dictionary) -> bool: return rx["reaction_id"] == &"boiler_cloud") \
		and (press_res["fired"] as Array).any(func(fp: Dictionary) -> bool: return fp["part_id"] == &"overclock_capacitor_shunt")
	t.check("Synergy 3 (Cross-World Quench-Discharge Press) mixes Batch 1 + Batch 2 seamlessly",
		saw_boiler_and_shunt and syn3.size() >= 2,
		"boiler_and_shunt=%s synergies=%d" % [str(saw_boiler_and_shunt), syn3.size()])


func _test_live_run_bridge_and_audio_bank() -> void:
	t.eq("LiveRunBridge is OFF by default with empty args/env",
		LiveRunBridge.is_enabled(PackedStringArray(), {}), false)
	t.eq("LiveRunBridge enables with CLI opt-in flag",
		LiveRunBridge.is_enabled(PackedStringArray([LiveRunBridge.FLAG_ARG_ON]), {}), true)
	t.eq("LiveRunBridge enables with SCRAPKEEP_EXPERIMENTAL=1",
		LiveRunBridge.is_enabled(PackedStringArray(), {LiveRunBridge.ENV_VAR: "1"}), true)
	t.eq("LiveRunBridge explicit CLI off flag overrides env",
		LiveRunBridge.is_enabled(PackedStringArray([LiveRunBridge.FLAG_ARG_OFF]), {LiveRunBridge.ENV_VAR: "1"}), false)

	t.eq("stage 1 selects spillway", LiveRunBridge.profile_for_stage(1)["biome_id"], &"spillway")
	t.eq("stage 2 selects spillway", LiveRunBridge.profile_for_stage(2)["biome_id"], &"spillway")
	t.eq("stage 3 selects dig", LiveRunBridge.profile_for_stage(3)["biome_id"], &"dig")
	t.eq("stage 4 selects dig", LiveRunBridge.profile_for_stage(4)["biome_id"], &"dig")
	t.eq("stage 5 selects highdraft", LiveRunBridge.profile_for_stage(5)["biome_id"], &"highdraft")
	t.eq("stage 6 selects highdraft", LiveRunBridge.profile_for_stage(6)["biome_id"], &"highdraft")

	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	var packed := load(CHUNK_PATH) as PackedScene
	var chunk := packed.instantiate() as Node3D
	root.add_child(chunk)
	await process_frame

	var bridge := LiveRunBridge.new()
	root.add_child(bridge)
	var cues_seen: Array[String] = []
	var loops_stopped: Array[String] = []
	bridge.audio_cue_triggered.connect(func(c: Dictionary) -> void: cues_seen.append(String(c["event_id"])))
	bridge.audio_cue_stopped.connect(func(ev_id: String) -> void: loops_stopped.append(ev_id))

	var cfg_s1 := bridge.configure_stage(1, 5150, 1.0, chunk)
	t.eq("LiveRunBridge stage 1 biome is spillway with setpieces attached",
		cfg_s1["biome_id"] == &"spillway" and bool(cfg_s1["setpieces_attached"]), true)
	t.check("configure_stage starts smelter_ambience loop",
		cues_seen.has("smelter_ambience") and bridge.active_audio_loops().has("smelter_ambience"))
	t.eq("configure_stage wires both chunk jump pads as launch triggers",
		int((cfg_s1["setpiece_info"] as Dictionary).get("jump_pad_count", 0)), 2)

	bridge.director.start_hazard(&"corrosive_steam_squall", Vector3.ZERO, 0.0)
	t.check("hazard WARNING routes pa_hazard_squall_incoming", cues_seen.has("pa_hazard_squall_incoming"))
	var cd_check := bridge.trigger_audio_cue("pa_hazard_squall_incoming")
	t.eq("ExperimentalAudioBank cooldown blocks immediate PA re-trigger", String(cd_check.get("reason", "")), "cooldown")

	for _i in 60:
		bridge.step(0.1, {"ball_pos": Vector3(12.0, 0.0, 0.0), "ball_vel": Vector3(15.0, 0.0, 0.0)})
		if cues_seen.has("hazard_squall_alarm"):
			break
	t.check("hazard RAMP/PEAK routes hazard_squall_alarm loop",
		cues_seen.has("hazard_squall_alarm") and bridge.active_audio_loops().has("hazard_squall_alarm"))

	var beacon_pos := Vector3(0.0, 0.0, 16.0)
	bridge.encounters.register_triggered_volume("bridge_beacon", &"scrap_beacon_lockdown", beacon_pos, &"spillway")
	bridge.encounters.activate_triggered("bridge_beacon", {"active_lockdown": false, "warden_awake": false})
	t.check("lockdown activation routes pa_salvage_press_lockdown and apex_lockdown loop",
		cues_seen.has("pa_salvage_press_lockdown") and cues_seen.has("apex_lockdown") and bridge.active_audio_loops().has("apex_lockdown"))

	for _w in 2:
		for _k in 6:
			bridge.encounters.report_encounter_kill(16.0, 14.0)
		for _s in 12:
			bridge.step(0.25, {"ball_pos": beacon_pos, "ball_vel": Vector3(16.0, 0.0, 0.0)})
	t.check("apex construct spawn routes pa_foreman_rig_deployed", cues_seen.has("pa_foreman_rig_deployed"))
	bridge.encounters.abort_all(&"test_done")
	t.check("lockdown end stops apex_lockdown loop", loops_stopped.has("apex_lockdown") and not bridge.active_audio_loops().has("apex_lockdown"))

	var cfg_s5 := bridge.configure_stage(5, 9090, 1.0, null)
	t.eq("LiveRunBridge reconfigures cleanly to stage 5 highdraft", cfg_s5["biome_id"], &"highdraft")
	bridge.encounters.random_cooldown_s = 0.0
	for _try in 40:
		bridge.step(0.25, {"ball_pos": Vector3(20.0, 0.0, 20.0), "ball_vel": Vector3(16.0, 0.0, 0.0), "unrefined_scrap": 0, "courier_bounty": 0})
		if cues_seen.has("pa_airdrop_pod_inbound"):
			break
		if not bridge.encounters.active_random.is_empty():
			bridge.encounters.resolve_active_random(&"expired", {})
			bridge.encounters.random_cooldown_s = 0.0
	t.check("highdraft airdrop announcement routes pa_airdrop_pod_inbound", cues_seen.has("pa_airdrop_pod_inbound"))

	var missing_cues: Array[String] = []
	for ev_id in EXPECTED_AUDIO_EVENTS:
		if not cues_seen.has(ev_id):
			missing_cues.append(ev_id)
	t.eq("all 7 ExperimentalAudioBank cues routed cleanly via LiveRunBridge signals", missing_cues, [])

	var attempt_cues: Array = []
	for _attempt in 2:
		bridge.configure_stage(1, 5150, 1.0, chunk)
		bridge.director.start_hazard(&"corrosive_steam_squall", Vector3.ZERO, 0.0)
		for _i in 60:
			bridge.step(0.1, {"ball_pos": Vector3(12.0, 0.0, 0.0), "ball_vel": Vector3(15.0, 0.0, 0.0)})
		var names: Array[String] = []
		for cue in bridge.audio_cue_log():
			names.append(String(cue["event_id"]))
		attempt_cues.append(names)
	t.check("a stage retry still fires pa_hazard_squall_incoming and hazard_squall_alarm",
		(attempt_cues[1] as Array).has("pa_hazard_squall_incoming") and (attempt_cues[1] as Array).has("hazard_squall_alarm"),
		str(attempt_cues[1]))
	t.eq("a stage retry fires the same audio cues as the first attempt", attempt_cues[1], attempt_cues[0])
	bridge.teardown()
	t.eq("teardown clears the audio cooldowns", ExperimentalAudioBank.can_trigger("pa_hazard_squall_incoming", 0.0), true)

	bridge.teardown()
	root.remove_child(bridge)
	bridge.free()
	root.remove_child(chunk)
	chunk.free()
	await process_frame
	await physics_frame

	var orphans_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	t.eq("LiveRunBridge teardown leaves 0 orphan nodes", orphans_after - orphans_before, 0)


func _test_graph_and_code_hygiene() -> void:
	var scan_root := "res://src/experimental"
	var gd_files: Array[String] = []
	var unopened_dirs: Array[String] = []
	var pending_dirs: Array[String] = [scan_root]
	while not pending_dirs.is_empty():
		var dpath: String = pending_dirs.pop_back()
		var dir := DirAccess.open(dpath)
		if dir == null:
			unopened_dirs.append(dpath)
			continue
		for sub in dir.get_directories():
			pending_dirs.append(dpath.path_join(sub))
		for fname in dir.get_files():
			if fname.ends_with(".gd"):
				gd_files.append(dpath.path_join(fname))
	gd_files.sort()
	t.eq("every folder under %s opens" % scan_root, unopened_dirs, [])
	t.check("script walk of %s finds scripts" % scan_root, not gd_files.is_empty(), "found %d" % gd_files.size())
	t.check("script walk of %s finds env_tags.gd" % scan_root, gd_files.has("res://src/experimental/env_tags.gd"), "found %d" % gd_files.size())

	var preload_pattern := 'preload\\("([^"]+)"\\)'
	var preload_re := RegEx.new()
	t.eq("regex compiles: %s" % preload_pattern, preload_re.compile(preload_pattern), OK)
	var static_var_pattern := "(?m)^\\s*static\\s+var\\b"
	var static_var_re := RegEx.new()
	t.eq("regex compiles: %s" % static_var_pattern, static_var_re.compile(static_var_pattern), OK)
	var tag_const_pattern := "(?m)^\\s*const\\s+(ENV_TAGS|CANONICAL_TAGS|TAG_(ELECTRIFIED|BURNING|SLAG_COATED|MAGNETIC|COOLANT_BRITTLE|SOAKED_CONDUCTIVE))\\b"
	var tag_const_re := RegEx.new()
	t.eq("regex compiles: %s" % tag_const_pattern, tag_const_re.compile(tag_const_pattern), OK)
	var never_brake_pattern := "(?m)^\\s*(static\\s+)?func\\s+_?never_brake\\w*\\b"
	var never_brake_re := RegEx.new()
	t.eq("regex compiles: %s" % never_brake_pattern, never_brake_re.compile(never_brake_pattern), OK)

	var graph := {}
	var static_vars: Array[String] = []
	var comment_hits: Array[String] = []
	var tag_decl_dups: Array[String] = []
	var tag_vocab_dups: Array[String] = []
	var never_brake_dups: Array[String] = []
	var unreadable: Array[String] = []

	for path in gd_files:
		var text := FileAccess.get_file_as_string(path)
		var read_error := FileAccess.get_open_error()
		if read_error != OK or text == "":
			unreadable.append("%s (error %d, %d chars)" % [path, read_error, text.length()])
			continue
		var deps: Array[String] = []
		for m in preload_re.search_all(text):
			var dep := String(m.get_string(1))
			if dep.ends_with(".gd"):
				deps.append(dep)
		graph[path] = deps
		if static_var_re.search(text) != null:
			static_vars.append(path)
		if path != "res://src/experimental/env_tags.gd":
			if tag_const_re.search(text) != null:
				tag_decl_dups.append(path)
			var all_tags_present := true
			for tag_name in EnvTags.CANONICAL_TAGS:
				if not text.contains('&"' + String(tag_name) + '"'):
					all_tags_present = false
					break
			if all_tags_present:
				tag_vocab_dups.append(path)
		if never_brake_re.search(text) != null:
			never_brake_dups.append(path)
		var lines := text.split("\n")
		for idx in lines.size():
			var stripped := lines[idx].strip_edges()
			if stripped.begins_with("#"):
				comment_hits.append("%s:%d" % [path, idx + 1])

	t.eq("every script under %s reads as text" % scan_root, unreadable, [])
	var has_cycle := _has_directed_cycle(graph)
	t.eq("zero circular preload dependencies in src/experimental", has_cycle, false)
	t.eq("zero mutable static var in src/experimental", static_vars, [])
	t.eq("zero # comment lines in src/experimental", comment_hits, [])
	t.eq("env tag name constants declared only in env_tags.gd", tag_decl_dups, [])
	t.eq("canonical env tag vocabulary declared only in env_tags.gd", tag_vocab_dups, [])
	t.eq("zero duplicate never_brake helpers in src/experimental", never_brake_dups, [])


func _test_env_tag_bounds_table() -> void:
	var origin := Vector3(1.0, 2.0, 3.0)
	var rows: Array[Dictionary] = [
		{
			"name": "default",
			"bounds": EnvTags.BOUNDS_DEFAULT,
			"in_i": 1.2, "in_t": 2.5,
			"over_i": 10.0, "over_t": 3.0,
			"zero_i": 0.0, "zero_valid": true,
			"short_t": 0.01, "zero_ttl_valid": true,
			"str_tag_valid": true, "ws_source_valid": false,
		},
		{
			"name": "elite",
			"bounds": EnvTags.BOUNDS_ELITE,
			"in_i": 1.2, "in_t": 2.5,
			"over_i": 15.0, "over_t": 3.0,
			"zero_i": 0.0, "zero_valid": true,
			"short_t": 0.1, "zero_ttl_valid": false,
			"str_tag_valid": true, "ws_source_valid": true,
		},
		{
			"name": "setpiece",
			"bounds": EnvTags.BOUNDS_SETPIECE,
			"in_i": 1.2, "in_t": 2.5,
			"over_i": 2.0, "over_t": 3.0,
			"zero_i": 0.05, "zero_valid": false,
			"short_t": 0.05, "zero_ttl_valid": false,
			"str_tag_valid": false, "ws_source_valid": false,
		},
	]
	for row in rows:
		var label: String = row["name"]
		var bounds: Dictionary = row["bounds"]
		var p_in := EnvTags.make_payload(EnvTags.TAG_BURNING, origin, 4.0, "src", 1.2, 2.5, bounds)
		t.near("%s bounds in-range intensity" % label, float(p_in["intensity"]), float(row["in_i"]), 0.0001)
		t.near("%s bounds in-range ttl" % label, float(p_in["ttl_s"]), float(row["in_t"]), 0.0001)
		t.eq("%s bounds in-range valid" % label, EnvTags.is_valid_payload(p_in, bounds), true)

		var p_over := EnvTags.make_payload(EnvTags.TAG_BURNING, origin, 4.0, "src", 15.0, 3.0, bounds)
		t.near("%s bounds over-range intensity" % label, float(p_over["intensity"]), float(row["over_i"]), 0.0001)
		t.near("%s bounds over-range ttl" % label, float(p_over["ttl_s"]), float(row["over_t"]), 0.0001)
		t.eq("%s bounds over-range valid" % label, EnvTags.is_valid_payload(p_over, bounds), true)

		var p_zero := EnvTags.make_payload(EnvTags.TAG_BURNING, origin, 4.0, "src", 0.0, 1.0, bounds)
		t.near("%s bounds zero intensity clamp" % label, float(p_zero["intensity"]), float(row["zero_i"]), 0.0001)
		t.eq("%s bounds zero intensity built payload valid" % label, EnvTags.is_valid_payload(p_zero, bounds), true)

		var raw_zero_i := {"tag": EnvTags.TAG_BURNING, "origin": origin, "radius_m": 4.0, "source_id": "src", "intensity": 0.0, "ttl_s": 1.0}
		t.eq("%s bounds raw zero intensity validation" % label, EnvTags.is_valid_payload(raw_zero_i, bounds), bool(row["zero_valid"]))

		var p_short := EnvTags.make_payload(EnvTags.TAG_BURNING, origin, 4.0, "src", 1.0, 0.01, bounds)
		t.near("%s bounds short ttl clamp" % label, float(p_short["ttl_s"]), float(row["short_t"]), 0.0001)
		t.eq("%s bounds short ttl built payload valid" % label, EnvTags.is_valid_payload(p_short, bounds), true)

		var raw_zero_ttl := {"tag": EnvTags.TAG_BURNING, "origin": origin, "radius_m": 4.0, "source_id": "src", "intensity": 1.0, "ttl_s": 0.0}
		t.eq("%s bounds raw zero ttl validation" % label, EnvTags.is_valid_payload(raw_zero_ttl, bounds), bool(row["zero_ttl_valid"]))

		var raw_str_tag := {"tag": "burning", "origin": origin, "radius_m": 4.0, "source_id": "src", "intensity": 1.0, "ttl_s": 1.0}
		t.eq("%s bounds string tag validation" % label, EnvTags.is_valid_payload(raw_str_tag, bounds), bool(row["str_tag_valid"]))

		var raw_ws_src := {"tag": EnvTags.TAG_BURNING, "origin": origin, "radius_m": 4.0, "source_id": "   ", "intensity": 1.0, "ttl_s": 1.0}
		t.eq("%s bounds whitespace source_id validation" % label, EnvTags.is_valid_payload(raw_ws_src, bounds), bool(row["ws_source_valid"]))


func _has_directed_cycle(graph: Dictionary) -> bool:
	var state := {}
	for node in graph.keys():
		if int(state.get(node, 0)) == 0:
			if _dfs_cycle(String(node), graph, state):
				return true
	return false


func _dfs_cycle(node: String, graph: Dictionary, state: Dictionary) -> bool:
	state[node] = 1
	for nxt in graph.get(node, []):
		var ns := String(nxt)
		if not graph.has(ns):
			continue
		var st := int(state.get(ns, 0))
		if st == 1:
			return true
		if st == 0 and _dfs_cycle(ns, graph, state):
			return true
	state[node] = 2
	return false


func _run_three_world_monte_carlo_proof() -> void:
	print("=== WORLDS 1-3 CLOSED-LOOP MONTE-CARLO PROOF (%d seeds x %d worlds x %d archetypes = %d runs) ===" % [
		MC_SEEDS_PER_WORLD, WORLD_SPECS.size(), ARCHETYPES.size(), MC_SEEDS_PER_WORLD * WORLD_SPECS.size() * ARCHETYPES.size()
	])
	for wspec in WORLD_SPECS:
		var biome: StringName = wspec["biome_id"]
		var dir_cfg := ResourceLoader.load(String(wspec["director_path"]))
		var enc_cat := ResourceLoader.load(String(wspec["encounter_path"]))
		var loadouts: Array = wspec["loadouts"]

		var buckets := {}
		for arch in ARCHETYPES:
			buckets[arch] = {"scores": [] as Array[float], "cooked": [] as Array[float], "survived": 0}
		var deadlocks := 0
		var max_depth := 0
		var total_elites := 0
		var total_plates := 0
		var flow_gt_stall := 0
		var syn_gt_stall := 0
		var syn_gt_flow := 0

		for s_idx in MC_SEEDS_PER_WORLD:
			var seed_val := 4100 + s_idx + int(wspec["stage_index"]) * 100
			var loadout: Array = loadouts[s_idx % loadouts.size()]
			var seed_scores := {}
			for arch in ARCHETYPES:
				var out := _sim_world_run(seed_val, biome, dir_cfg, enc_cat, arch, loadout)
				deadlocks += int(out["deadlocks"])
				max_depth = maxi(max_depth, int(out["max_depth"]))
				total_elites += int(out["elites_spawned"])
				total_plates += int(out["plates_broken"])
				seed_scores[arch] = float(out["score"])
				var b: Dictionary = buckets[arch]
				(b["scores"] as Array[float]).append(float(out["score"]))
				(b["cooked"] as Array[float]).append(float(out["cooked"]))
				if bool(out["survived"]):
					b["survived"] = int(b["survived"]) + 1
			if float(seed_scores[&"flow_runner"]) > float(seed_scores[&"staller"]):
				flow_gt_stall += 1
			if float(seed_scores[&"synergy_builder"]) > float(seed_scores[&"staller"]):
				syn_gt_stall += 1
			if float(seed_scores[&"synergy_builder"]) > float(seed_scores[&"flow_runner"]):
				syn_gt_flow += 1

		var st_med := _median(buckets[&"staller"]["scores"])
		var fl_med := _median(buckets[&"flow_runner"]["scores"])
		var sy_med := _median(buckets[&"synergy_builder"]["scores"])
		var st_cook := _median(buckets[&"staller"]["cooked"])
		var fl_cook := _median(buckets[&"flow_runner"]["cooked"])
		var sy_cook := _median(buckets[&"synergy_builder"]["cooked"])
		print("  %-10s | med score st/fl/sy: %6.1f / %6.1f / %6.1f | paired fl>st:%2d/%d sy>st:%2d/%d sy>fl:%2d/%d | cook st/fl/sy: %.1f/%.1f/%.1f | elites:%d plates:%d" % [
			String(biome), st_med, fl_med, sy_med,
			flow_gt_stall, MC_SEEDS_PER_WORLD, syn_gt_stall, MC_SEEDS_PER_WORLD, syn_gt_flow, MC_SEEDS_PER_WORLD,
			st_cook, fl_cook, sy_cook, total_elites, total_plates
		])

		t.eq("mc_%s_zero_deadlocks" % String(biome), deadlocks, 0)
		t.check("mc_%s_cascade_depth_bounded" % String(biome), max_depth <= EnvTags.MAX_CASCADE_DEPTH, "depth=%d" % max_depth)
		t.check("mc_%s_elites_and_plates_exercised" % String(biome),
			total_elites >= 30 and total_plates >= 30,
			"elites=%d plates=%d" % [total_elites, total_plates])
		t.check("mc_%s_archetype_separation" % String(biome),
			flow_gt_stall >= int(MC_SEEDS_PER_WORLD * 0.85)
				and syn_gt_stall >= int(MC_SEEDS_PER_WORLD * 0.90)
				and syn_gt_flow >= int(MC_SEEDS_PER_WORLD * 0.65)
				and sy_med > fl_med and fl_med > st_med * 1.4,
			"fl>st=%d sy>st=%d sy>fl=%d meds=%.1f/%.1f/%.1f" % [flow_gt_stall, syn_gt_stall, syn_gt_flow, st_med, fl_med, sy_med])
		t.check("mc_%s_staller_cooks_while_flow_and_synergy_stay_clean" % String(biome),
			st_cook > 0.0 and fl_cook == 0.0 and sy_cook == 0.0,
			"cook=%.1f/%.1f/%.1f" % [st_cook, fl_cook, sy_cook])


func _sim_world_run(
		seed_val: int,
		biome: StringName,
		dir_cfg: Resource,
		enc_cat: Resource,
		arch: StringName,
		loadout: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 29 + int(ARCHETYPES.find(arch)) * 97
	var field := EnvTags.new()
	var rig := JuryRig.new(field)
	var eco := Ecology.new(field)
	var director := AdversityDirector.new(seed_val, biome, 1.0, dir_cfg)
	var encounters := EncounterEngine.new(seed_val, enc_cat)

	for pid in loadout:
		rig.equip_by_id(pid)

	var live_ids: Array[String] = []
	var state := {
		"ball_pos": Vector3.ZERO,
		"speed": 14.0,
		"dmg": 0.0,
		"kills": 0,
		"plates": 0,
		"elites": 0,
		"scrap": 0,
		"pressure": 0.0,
		"max_depth": 0,
	}

	var fref: WeakRef = weakref(field)
	var db := func(p: Dictionary) -> void:
		var f: Variant = fref.get_ref()
		if f != null:
			f.apply_tag(p)
	var eb := func(p: Dictionary) -> void:
		var f: Variant = fref.get_ref()
		if f != null:
			f.apply_tag(p)
	director.env_tag_emitted.connect(db)
	encounters.env_tag_emitted.connect(eb)

	var apply_dmg := func(origin: Vector3, rad: float, raw: float, kind: StringName) -> float:
		if raw <= 0.0:
			return 0.0
		var total := 0.0
		for eid in live_ids:
			var e := eco.enemy(eid)
			if e == null or e.is_dead():
				continue
			if Vector2(e.pos.x - origin.x, e.pos.z - origin.z).length() <= rad:
				var dres := eco.damage_enemy(eid, raw, origin, kind)
				total += float(dres.get("damage_dealt", 0.0))
				if bool(dres.get("dead", false)):
					state["kills"] = int(state["kills"]) + 1
					state["scrap"] = int(state["scrap"]) + 3
		for inst in director.active_elites:
			if inst.is_defeated():
				continue
			if Vector2(inst.origin.x - origin.x, inst.origin.z - origin.z).length() <= rad + 3.0:
				var tags: Array[StringName] = field.tags_at(inst.origin, 5.0)
				var eh: Dictionary = inst.apply_hit(raw, float(state["speed"]), 14.0, tags, state["ball_pos"] as Vector3)
				total += float(eh.get("hull_damage", 0.0)) + float(eh.get("plates_broken", 0)) * 28.0
				state["plates"] = int(state["plates"]) + int(eh.get("plates_broken", 0))
				if bool(eh.get("defeated", false)):
					state["kills"] = int(state["kills"]) + 1
					state["scrap"] = int(state["scrap"]) + int((eh["bounty"] as Dictionary).get("scrap", 0))
		return total

	var rx_cb := func(rx: Dictionary) -> void:
		state["max_depth"] = maxi(int(state["max_depth"]), int(rx.get("depth", 0)))
		var dealt: float = apply_dmg.call(rx.get("origin", Vector3.ZERO), float(rx.get("radius_m", 6.0)), float(rx.get("damage", 0.0)) * 0.55, &"arc")
		state["dmg"] = float(state["dmg"]) + dealt
	field.reaction_triggered.connect(rx_cb)

	var part_cb := func(rcpt: Dictionary) -> void:
		for ch in rcpt.get("chain_hits", []):
			var tid := String(ch.get("target_id", ""))
			var ch_dmg := float(ch.get("damage", 0.0))
			if tid.begins_with("enemy:"):
				var eid := tid.trim_prefix("enemy:")
				var e := eco.enemy(eid)
				if e != null and not e.is_dead():
					var dres := eco.damage_enemy(eid, ch_dmg, state["ball_pos"] as Vector3, &"arc")
					state["dmg"] = float(state["dmg"]) + float(dres.get("damage_dealt", 0.0))
					if bool(dres.get("dead", false)):
						state["kills"] = int(state["kills"]) + 1
						state["scrap"] = int(state["scrap"]) + 3
			elif tid.begins_with("elite:"):
				var iid := tid.trim_prefix("elite:")
				for inst in director.active_elites:
					if String(inst.instance_id) == iid and not inst.is_defeated():
						var tags: Array[StringName] = field.tags_at(inst.origin, 5.0)
						var eh: Dictionary = inst.apply_hit(ch_dmg, float(state["speed"]), 14.0, tags, state["ball_pos"] as Vector3)
						state["dmg"] = float(state["dmg"]) + float(eh.get("hull_damage", 0.0)) + float(eh.get("plates_broken", 0)) * 28.0
						state["plates"] = int(state["plates"]) + int(eh.get("plates_broken", 0))
						if bool(eh.get("defeated", false)):
							state["kills"] = int(state["kills"]) + 1
							state["scrap"] = int(state["scrap"]) + int((eh["bounty"] as Dictionary).get("scrap", 0))
						break
		var meta: Dictionary = rcpt.get("meta", {})
		var aoe_dmg := float(meta.get("quench_damage", 0.0)) + float(meta.get("vent_damage", 0.0))
		if aoe_dmg > 0.0:
			var dealt_aoe: float = apply_dmg.call(state["ball_pos"] as Vector3, 9.5, aoe_dmg, &"arc")
			state["dmg"] = float(state["dmg"]) + dealt_aoe
	rig.part_fired.connect(part_cb)

	var syn_cb := func(syn: Dictionary) -> void:
		var dealt: float = apply_dmg.call(state["ball_pos"] as Vector3, 18.0, float(syn.get("bonus_damage", 0.0)), &"arc")
		state["dmg"] = float(state["dmg"]) + dealt
	rig.synergy_emerged.connect(syn_cb)

	var serial := [0]
	var spawn_e := func(pos: Vector3, role: StringName) -> void:
		serial[0] = int(serial[0]) + 1
		var eid := "w_%d" % int(serial[0])
		eco.spawn_enemy(eid, role, Vector3(clampf(pos.x, -ARENA_HALF_M, ARENA_HALF_M), 0.0, clampf(pos.z, -ARENA_HALF_M, ARENA_HALF_M)))
		live_ids.append(eid)

	spawn_e.call(Vector3(9.0, 0.0, 2.0), Ecology.ROLE_SWARMER)
	spawn_e.call(Vector3(12.0, 0.0, -3.0), Ecology.ROLE_SHIELDED_BULWARK)
	spawn_e.call(Vector3(15.0, 0.0, 4.0), Ecology.ROLE_ARC_SNIPER)
	spawn_e.call(Vector3(10.0, 0.0, 5.0), Ecology.ROLE_WELD_HEALER)

	var ball_pos := Vector3.ZERO
	var heading := 0.0
	var hull_hp := PLAYER_MAX_HP
	var survived := true
	var deadlocks := 0
	var prop_seq := 0
	var sniper_aim := {}

	for tick in MC_STEPS:
		var t_s := float(tick) * MC_DT
		var speed := 14.0
		match arch:
			&"staller":
				speed = rng.randf_range(2.6, 4.2)
				heading = sin(t_s * 0.4) * 0.35
				ball_pos = Vector3(cos(t_s * 0.35) * 2.8, 0.2, sin(t_s * 0.35) * 2.8)
			&"flow_runner":
				speed = rng.randf_range(14.8, 17.6)
				heading += rng.randf_range(0.20, 0.35)
				ball_pos = Vector3(cos(heading) * 15.5, 0.2, sin(heading) * 15.5)
			&"synergy_builder":
				speed = rng.randf_range(15.4, 18.6)
				heading += rng.randf_range(0.22, 0.38)
				ball_pos = Vector3(cos(heading) * 14.0, 0.2, sin(heading) * 14.0)
		var ball_vel := Vector3(cos(heading) * speed, 0.0, sin(heading) * speed)
		state["ball_pos"] = ball_pos
		state["speed"] = speed

		var alive_kept: Array[String] = []
		for eid in live_ids:
			var e := eco.enemy(eid)
			if e != null and not e.is_dead():
				alive_kept.append(eid)
		live_ids = alive_kept
		var dir_res := director.advance(MC_DT, ball_pos, ball_vel, live_ids.size(), 14.0, true)
		for sp in dir_res["due_spawns"]:
			if live_ids.size() < director.alive_cap:
				spawn_e.call(sp.get("at", ball_pos + Vector3(12.0, 0.0, 0.0)), Ecology.ROLE_SWARMER)
		for el in dir_res["new_elites"]:
			el.origin = Vector3(clampf(el.origin.x, -ARENA_HALF_M, ARENA_HALF_M), 0.0, clampf(el.origin.z, -ARENA_HALF_M, ARENA_HALF_M))
			state["elites"] = int(state["elites"]) + 1
		for el in director.active_elites:
			if not el.is_defeated():
				var to_b := Vector3(ball_pos.x - el.origin.x, 0.0, ball_pos.z - el.origin.z)
				if to_b.length() > 4.5:
					el.origin += to_b.normalized() * 6.5 * MC_DT

		encounters.advance(MC_DT, {
			"ball_pos": ball_pos, "ball_vel": ball_vel, "cruise_mps": 14.0,
			"warden_awake": false, "biome_id": biome, "elapsed_s": t_s,
			"hazard_tier": director.hazard_tier, "unrefined_scrap": 0, "courier_bounty": 0,
		})

		var targets: Array[Dictionary] = []
		for eid in live_ids:
			var e := eco.enemy(eid)
			if e != null and not e.is_dead() and targets.size() < 4:
				targets.append({"id": "enemy:" + eid, "pos": e.pos})
		for el in director.active_elites:
			if not el.is_defeated() and targets.size() < 4:
				targets.append({"id": "elite:" + String(el.instance_id), "pos": el.origin})
		var combat_at: Vector3 = targets[0]["pos"] if not targets.is_empty() else (ball_pos + Vector3(cos(heading), 0.0, sin(heading)) * 3.0)
		var dir_vec := (combat_at - ball_pos)
		dir_vec.y = 0.0
		dir_vec = dir_vec.normalized() if dir_vec.length_squared() > 0.01 else Vector3.FORWARD

		var prev_pressure := float(state["pressure"])
		if arch == &"staller":
			if tick % 8 == 0:
				rig.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {"origin": ball_pos, "dir": dir_vec, "target_pos": combat_at, "targets": targets, "ball_speed_mps": speed})
			if tick % 10 == 0:
				rig.dispatch(PartResource.TRIG_ON_DASH, {"origin": ball_pos, "dir": dir_vec, "ball_speed_mps": speed})
				rig.dispatch(PartResource.TRIG_ON_SLAM, {"origin": ball_pos, "ball_speed_mps": speed})
			if tick % 12 == 0:
				rig.dispatch(PartResource.TRIG_ON_HARPOON_SNAP, {"origin": combat_at, "anchor_pos": combat_at, "clean_snap": false, "ball_speed_mps": speed})
		elif arch == &"flow_runner":
			if tick % 8 == 0:
				rig.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {"origin": ball_pos, "dir": dir_vec, "target_pos": combat_at, "targets": targets, "ball_speed_mps": speed})
			if tick % 12 == 3:
				rig.dispatch(PartResource.TRIG_ON_DASH, {"origin": ball_pos, "dir": dir_vec, "ball_speed_mps": speed})
			if tick % 16 == 5:
				rig.dispatch(PartResource.TRIG_ON_SLAM, {"origin": ball_pos, "ball_speed_mps": speed})
				rig.dispatch(PartResource.TRIG_ON_HARPOON_SNAP, {"origin": combat_at, "anchor_pos": combat_at, "clean_snap": true, "ball_speed_mps": speed})
			if rig.heat_band() == JuryRig.BAND_REDLINE:
				rig.attempt_redline_vent(combat_at, speed, &"slam")
		elif arch == &"synergy_builder":
			var ph := tick % 8
			if ph == 0:
				prop_seq += 1
				var pid_p := "p_%d" % prop_seq
				eco.spawn_prop(pid_p, Ecology.PROP_COOLANT_TANK if prop_seq % 2 == 0 else Ecology.PROP_SLAG_DRUM, combat_at)
				var rupt := eco.rupture_prop(pid_p, "synergy")
				state["scrap"] = int(state["scrap"]) + int(rupt.get("scrap", 0)) + int(rupt.get("cogs", 0)) * 2
				rig.dispatch(PartResource.TRIG_ON_PROP_RUPTURE, {"origin": combat_at, "targets": targets, "ball_speed_mps": speed})
			elif ph == 1:
				rig.dispatch(PartResource.TRIG_ON_DASH, {"origin": combat_at, "dir": dir_vec, "dash_length_m": 4.0, "ball_speed_mps": speed})
				rig.dispatch(PartResource.TRIG_ON_SLAM, {"origin": combat_at, "ball_speed_mps": speed})
			elif ph == 2:
				rig.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {"origin": ball_pos, "dir": dir_vec, "target_pos": combat_at, "targets": targets, "ball_speed_mps": speed})
			elif ph == 5:
				rig.dispatch(PartResource.TRIG_ON_HARPOON_SNAP, {"origin": combat_at, "anchor_pos": combat_at, "clean_snap": true, "ball_speed_mps": speed})
				rig.dispatch(PartResource.TRIG_ON_SCRAP_PICKUP, {"origin": combat_at, "amount": 2, "ball_speed_mps": speed})
			if rig.heat_band() == JuryRig.BAND_REDLINE:
				rig.attempt_redline_vent(combat_at, speed, &"slam")

		var rtick := rig.step(MC_DT, speed, ball_pos)
		eco.step(MC_DT, ball_pos, ball_vel)
		if speed < 6.0 and director.hazard_intensity() >= 0.45:
			state["pressure"] = float(state["pressure"]) + 10.0 * MC_DT
		for eid in live_ids:
			var e := eco.enemy(eid)
			if e == null or e.is_dead():
				sniper_aim.erase(eid)
				continue
			if e.state == Ecology.ST_DISRUPTED or e.state == Ecology.ST_ALERT_TELEGRAPH:
				continue
			var flat_d := Vector2(e.pos.x - ball_pos.x, e.pos.z - ball_pos.z).length()
			if e.role == Ecology.ROLE_ARC_SNIPER:
				if e.state == Ecology.ST_WINDUP and not sniper_aim.has(eid):
					sniper_aim[eid] = ball_pos
				elif e.state == Ecology.ST_STRIKE:
					var aimed: Vector3 = sniper_aim.get(eid, ball_pos)
					sniper_aim.erase(eid)
					if e.aim_deflected_rad < 0.2 and Vector2(ball_pos.x - aimed.x, ball_pos.z - aimed.z).length() <= 5.0:
						state["pressure"] = float(state["pressure"]) + 10.0
			elif flat_d <= 3.8:
				state["pressure"] = float(state["pressure"]) + 7.5
		for ef in dir_res["facts"]:
			if String(ef.get("kind", "")) == "elite_execute":
				var at_p: Vector3 = ef.get("at", Vector3.ZERO)
				if Vector2(ball_pos.x - at_p.x, ball_pos.z - at_p.z).length() <= 8.5:
					state["pressure"] = float(state["pressure"]) + 16.0

		var tick_dmg := float(rtick.get("cook_damage", 0.0)) + (float(state["pressure"]) - prev_pressure)
		hull_hp -= tick_dmg
		if is_nan(rig.heat) or is_inf(rig.heat) or is_nan(director.credit_pool):
			deadlocks += 1
		if hull_hp <= 0.0:
			survived = false
			break

	director.env_tag_emitted.disconnect(db)
	encounters.env_tag_emitted.disconnect(eb)
	field.reaction_triggered.disconnect(rx_cb)
	rig.part_fired.disconnect(part_cb)
	rig.synergy_emerged.disconnect(syn_cb)
	var score := float(state["dmg"]) + float(int(state["kills"])) * 40.0 + float(int(state["scrap"])) * 2.0 + maxf(0.0, hull_hp) * 5.0 - float(state["pressure"]) - rig.hull_cooked_total
	if is_nan(score) or is_inf(score):
		deadlocks += 1
	var cooked_total := rig.hull_cooked_total
	eco.dispose()
	rig.clear()
	field.clear()
	return {
		"score": score,
		"cooked": cooked_total,
		"survived": survived,
		"deadlocks": deadlocks,
		"max_depth": int(state["max_depth"]),
		"elites_spawned": int(state["elites"]),
		"plates_broken": int(state["plates"]),
	}


func _median(values: Array[float]) -> float:
	var s := values.duplicate()
	s.sort()
	if s.is_empty():
		return 0.0
	return float(s[s.size() / 2])
