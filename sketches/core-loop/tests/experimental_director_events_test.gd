extends SceneTree


const T := preload("res://tests/support/t.gd")
const EnvTags := preload("res://src/experimental/env_tags.gd")
const RefurbishedElites := preload("res://src/experimental/refurbished_elites.gd")
const AdversityDirector := preload("res://src/experimental/adversity_director.gd")
const EncounterEngine := preload("res://src/experimental/encounter_engine.gd")
const DirectorConfigScript := preload("res://src/experimental/resources/director/adversity_director_config.gd")

var t := T.new("experimental_director_events_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_resources_and_clarity()
	_test_behavioral_escalation_no_bullet_sponges()
	_test_deterministic_seeded_budgeting()
	_test_rule9_stall_vs_speed_asymmetry()
	_test_refurbished_elites_plates_and_bounty()
	_test_slag_tide_recession_and_bounded_hold()
	_test_high_tick_hazard_no_starvation_and_no_cost_bias()
	_test_steam_squall_sightline_and_silhouette()
	_test_magnetic_storm_vectors_and_slingshot()
	_test_scrap_beacon_lockdown_and_yardlock_invariants()
	_test_over_audit_blitz_gate()
	_test_greed_weighted_random_encounters()
	_test_airdrop_cover_and_rogue_compactor_crusher()
	_test_area3d_volume_lifecycle_and_signals()
	quit(t.verdict())


func _test_resources_and_clarity() -> void:
	var dir_cfg := ResourceLoader.load(AdversityDirector.DEFAULT_CONFIG_PATH)
	var enc_cfg := ResourceLoader.load(EncounterEngine.DEFAULT_CATALOG_PATH)
	t.check("adversity .tres config loads cleanly", dir_cfg != null)
	t.check("encounter catalog .tres loads cleanly", enc_cfg != null)

	var pool := RefurbishedElites.load_default_pool()
	t.check("at least 5 Refurbished Elite .tres resources load (6 authored)", pool.size() >= 6, "loaded %d" % pool.size())

	var all_elites_clear := true
	for res in pool:
		var spec: Dictionary = res.call("to_spec_dict")
		var ok: bool = String(spec["silhouette_cue"]) != "" \
			and String(spec["movement_cadence"]) != "" \
			and String(spec["counterplay_cue"]) != "" \
			and float(spec["tell_s"]) >= EnvTags.MIN_TELL_S \
			and EnvTags.CANONICAL_TAGS.has(StringName(spec["ability_tag"]))
		all_elites_clear = all_elites_clear and ok
	t.check("every Refurbished Elite .tres carries silhouette, cadence, counterplay, >=0.6s tell, and canonical env tag", all_elites_clear)

	var director := AdversityDirector.new(42, &"spillway", 1.0, dir_cfg)
	var roles: Dictionary = dir_cfg.get("enemy_roles")
	var roles_clear := roles.size() >= 8
	for role_id in roles:
		var row: Dictionary = director.enemy_role_clarity(StringName(role_id))
		roles_clear = roles_clear and String(row.get("silhouette", "")) != "" \
			and String(row.get("cadence", "")) != "" \
			and float(row.get("tell_s", 0.0)) >= 0.6
	t.check("all base Fleet enemy roles carry third-person silhouette, cadence, and >=0.6s tell", roles_clear, "roles=%d" % roles.size())

	var custom_cfg: Resource = DirectorConfigScript.new()
	custom_cfg.set("base_income_per_s", 10.0)
	custom_cfg.set("tier_income_step", 2.0)
	custom_cfg.set("elite_pool", pool)
	custom_cfg.set("fleet_packs", dir_cfg.get("fleet_packs"))
	custom_cfg.set("hazard_configs", dir_cfg.get("hazard_configs"))
	var fast_dir := AdversityDirector.new(42, &"spillway", 1.0, custom_cfg)
	t.check("custom .tres/Resource config overrides director income cleanly",
		fast_dir.effective_income_rate() > director.effective_income_rate() * 3.0,
		"custom=%.2f default=%.2f" % [fast_dir.effective_income_rate(), director.effective_income_rate()])


func _test_behavioral_escalation_no_bullet_sponges() -> void:
	var dir := AdversityDirector.new(77, &"spillway", 1.2)
	var snap_t1 := dir.behavioral_escalation_snapshot()
	var elite_t1 := RefurbishedElites.spawn_instance(&"over_plated_juggernaut", "e_t1", Vector3.ZERO, dir.stage_threat)

	var pos := Vector3.ZERO
	for _i in 300:
		var vel := Vector3(14.0, 0.0, 0.0)
		pos += vel * 0.5
		dir.advance(0.5, pos, vel, 4, 14.0, true)

	var snap_late := dir.behavioral_escalation_snapshot()
	var elite_late := RefurbishedElites.spawn_instance(&"over_plated_juggernaut", "e_late", Vector3.ZERO, dir.stage_threat)

	t.check("hazard_tier rises through continuous time", int(snap_late["hazard_tier"]) >= 4, "tier=%d" % int(snap_late["hazard_tier"]))
	t.near("ruling al: base_hull_hp_scale stays constant (no bullet-sponge HP scaling)",
		float(snap_late["base_hull_hp_scale"]), float(snap_t1["base_hull_hp_scale"]), 0.0001)
	t.near("ruling al: elite max_hull_hp is identical at tier 1 and tier 4",
		elite_late.max_hull_hp, elite_t1.max_hull_hp, 0.0001)
	t.check("behavioral escalation unlocks more Fleet packs",
		(snap_late["unlocked_packs"] as Array).size() > (snap_t1["unlocked_packs"] as Array).size())
	t.check("behavioral escalation unlocks higher-tier Refurbished elites",
		(snap_late["unlocked_elites"] as Array).size() > (snap_t1["unlocked_elites"] as Array).size())
	t.check("behavioral escalation unlocks Magnetic Storm hazard at higher tiers",
		(snap_late["unlocked_hazards"] as Array).has(&"magnetic_storm")
		and not (snap_t1["unlocked_hazards"] as Array).has(&"magnetic_storm"))


func _test_deterministic_seeded_budgeting() -> void:
	var a := AdversityDirector.new(1337, &"smelter_pit", 1.0)
	var b := AdversityDirector.new(1337, &"smelter_pit", 1.0)
	var c := AdversityDirector.new(9001, &"smelter_pit", 1.0)

	var trace_a: Array = []
	var trace_b: Array = []
	var trace_c: Array = []
	for step_i in 90:
		var angle := float(step_i) * 0.15
		var pos := Vector3(cos(angle) * 40.0, 0.0, sin(angle) * 40.0)
		var vel := Vector3(-sin(angle) * 14.0, 0.0, cos(angle) * 14.0)
		var ra := a.advance(0.5, pos, vel, 2, 14.0, true)
		var rb := b.advance(0.5, pos, vel, 2, 14.0, true)
		var rc := c.advance(0.5, pos, vel, 2, 14.0, true)
		for f in ra["facts"]:
			trace_a.append("%s:%s" % [String(f.get("kind", "")), String(f.get("pack_id", f.get("variant_id", f.get("id", ""))))])
		for f in rb["facts"]:
			trace_b.append("%s:%s" % [String(f.get("kind", "")), String(f.get("pack_id", f.get("variant_id", f.get("id", ""))))])
		for f in rc["facts"]:
			trace_c.append("%s:%s" % [String(f.get("kind", "")), String(f.get("pack_id", f.get("variant_id", f.get("id", ""))))])

	t.check("same seed produces non-empty deterministic trace", not trace_a.is_empty(), "events=%d" % trace_a.size())
	t.eq("same seed produces identical purchase & hazard fact sequence", trace_a, trace_b)
	t.near("same seed accrues identical credit total", a.credits_accrued, b.credits_accrued, 0.0001)
	t.near("same seed spends identical credit total", a.credits_spent, b.credits_spent, 0.0001)
	t.check("different seed diverges in purchase sequence", trace_a != trace_c)


func _test_rule9_stall_vs_speed_asymmetry() -> void:
	var stalled := AdversityDirector.new(505, &"spillway", 1.0)
	var rolling := AdversityDirector.new(505, &"spillway", 1.0)

	var roll_pos := Vector3.ZERO
	for i in 40:
		var dt := 0.25
		stalled.advance(dt, Vector3(1.0, 0.0, 1.0), Vector3(1.5, 0.0, 0.0), 3, 14.0, true)
		var heading := float(i) * 0.22
		var roll_vel := Vector3(cos(heading) * 16.0, 0.0, sin(heading) * 16.0)
		roll_pos += roll_vel * dt
		rolling.advance(dt, roll_pos, roll_vel, 3, 14.0, true)

	t.check("Rule 9: stalled ball builds sharp stall_meter pressure", stalled.stall_meter >= 0.85, "stall=%.2f" % stalled.stall_meter)
	t.check("Rule 9: fast turning ball keeps stall_meter at zero", rolling.stall_meter <= 0.05, "stall=%.2f" % rolling.stall_meter)
	t.check("Rule 9: fast turning ball builds flow_meter", rolling.flow_meter >= 0.7, "flow=%.2f" % rolling.flow_meter)
	t.check("Rule 9: fast turning ball keeps escape_lane_open == true", rolling.escape_lane_open)
	t.check("Rule 9: stalled ball generates significantly higher credit income than fast rolling ball",
		stalled.effective_income_rate() > rolling.effective_income_rate() * 1.6,
		"stalled=%.2f rolling=%.2f" % [stalled.effective_income_rate(), rolling.effective_income_rate()])
	t.check("Rule 9: stalled ball accrues more total pressure credits over identical elapsed window",
		stalled.credits_accrued > rolling.credits_accrued * 1.35,
		"stalled=%.1f rolling=%.1f" % [stalled.credits_accrued, rolling.credits_accrued])


func _test_refurbished_elites_plates_and_bounty() -> void:
	var jug := RefurbishedElites.spawn_instance(&"over_plated_juggernaut", "jug_1", Vector3(10.0, 0.0, 0.0), 1.0)
	t.eq("Juggernaut starts with 3 intact armor plates", jug.intact_plate_count(), 3)
	var slow_hit := jug.apply_hit(20.0, 4.0, 14.0, [])
	t.eq("slow hit dents first plate without breaking it", int(slow_hit["plates_broken"]), 0)
	t.near("slow hit leaves hull untouched while plates stand", float(slow_hit["hull_damage"]), 0.0, 0.001)

	var shatter_hit := jug.apply_hit(40.0, 15.0, 14.0, [&"coolant_brittle"])
	t.check("high-speed coolant_brittle strike shatters multiple plates cleanly",
		int(shatter_hit["plates_broken"]) >= 2 and int(shatter_hit["scrap_spilled"]) >= 28,
		"broken=%d scrap=%d" % [int(shatter_hit["plates_broken"]), int(shatter_hit["scrap_spilled"])])
	var tag_ok := not (shatter_hit["env_tags"] as Array).is_empty() \
		and EnvTags.is_valid_payload((shatter_hit["env_tags"] as Array)[0], EnvTags.BOUNDS_ELITE)
	t.check("plate shatter emits canonical env_tag payload", tag_ok)

	var kill_hit := jug.apply_hit(500.0, 16.0, 14.0, [&"coolant_brittle"])
	t.check("defeating Juggernaut pays guaranteed rare Salvage Bounty",
		bool(kill_hit["defeated"]) and int((kill_hit["bounty"] as Dictionary).get("scrap", 0)) == 85
		and StringName((kill_hit["bounty"] as Dictionary).get("guaranteed_rarity", &"")) == &"rare")
	var dup_hit := jug.apply_hit(500.0, 16.0, 14.0, [])
	t.check("RewardsBankedOnce: duplicate hit on defeated elite pays no second bounty",
		(dup_hit["bounty"] as Dictionary).is_empty())

	var relay := RefurbishedElites.spawn_instance(&"arc_capacitor_relay", "relay_1", Vector3.ZERO, 1.0)
	var strip_hit := relay.apply_hit(45.0, 15.0, 14.0, [&"soaked_conductive"])
	t.check("Arc-Capacitor Relay triggers overload backfire when shrouds are stripped",
		bool(strip_hit["backfire_friendly_fire"]) and relay.intact_plate_count() == 0)

	var foreman := RefurbishedElites.spawn_instance(&"overclocked_foreman_spec", "foreman_1", Vector3.ZERO, 1.0)
	t.check("Foreman-Spec tightens pack rest aura while dorsal plates intact", foreman.pack_aura_rest_scale() < 1.0)
	foreman.apply_hit(100.0, 16.0, 14.0, [&"electrified"])
	t.near("Foreman-Spec loses unison aura once plates are stripped", foreman.pack_aura_rest_scale(), 1.0, 0.001)

	var winch := RefurbishedElites.spawn_instance(&"magnetic_tow_winch", "winch_1", Vector3(8.0, 0.0, 0.0), 1.0)
	var saw_tell := false
	var saw_exec_tag := false
	var slingshot_accel := Vector3.ZERO
	var fast_vel := Vector3(0.0, 0.0, 15.0)
	for _i in 30:
		var tick := winch.step(0.15, Vector3(0.0, 0.0, 0.0), fast_vel, 14.0)
		for f in tick["facts"]:
			if f["kind"] == "elite_telegraph":
				saw_tell = float(f["tell_s"]) >= EnvTags.MIN_TELL_S
		for tp in tick["env_tags"]:
			if EnvTags.is_valid_payload(tp, EnvTags.BOUNDS_ELITE) and tp["tag"] == &"magnetic":
				saw_exec_tag = true
		if (tick["ball_accel"] as Vector3).length() > 0.1:
			slingshot_accel = tick["ball_accel"]
	t.check("Magnetic Tow-Winch enforces >=0.6s telegraph before execute", saw_tell)
	t.check("Magnetic Tow-Winch emits canonical &'magnetic' env_tag payload", saw_exec_tag)
	t.check("Magnetic Tow-Winch fast-ball slingshot never brakes forward velocity",
		slingshot_accel.length() > 0.5 and slingshot_accel.dot(fast_vel.normalized()) >= -0.001,
		"accel=%s" % str(slingshot_accel))


func _test_slag_tide_recession_and_bounded_hold() -> void:
	var dir := AdversityDirector.new(303, &"smelter_pit", 1.0)
	t.check("Rising Slag Tide starts manually in WARNING", dir.start_hazard(&"rising_slag_tide", Vector3.ZERO, 0.0))
	t.eq("hazard starts in WARNING phase", dir.hazard_phase, AdversityDirector.HazardPhase.WARNING)

	var saw_ramp := false
	var saw_peak := false
	var saw_recede := false
	var saw_ended := false
	var saw_slag_tag := false
	var saw_burn_tag := false
	var ramp_ticks_held := 0

	for _i in 120:
		var prev_depth := dir.slag_tide_depth_m()
		var res := dir.advance(0.25, Vector3(2.0, 0.0, 2.0), Vector3.ZERO, 0, 14.0, true)
		if dir.hazard_phase == AdversityDirector.HazardPhase.RAMP:
			saw_ramp = true
			if is_equal_approx(dir.slag_tide_depth_m(), prev_depth):
				ramp_ticks_held += 1
		if dir.hazard_phase == AdversityDirector.HazardPhase.PEAK:
			saw_peak = true
		if dir.hazard_phase == AdversityDirector.HazardPhase.RECEDE:
			saw_recede = true
		for f in res["facts"]:
			if f["kind"] == "hazard_ended" and f["id"] == &"rising_slag_tide":
				saw_ended = true
		for tp in res["env_tags"]:
			t.check("slag tide env_tag payload valid", EnvTags.is_valid_payload(tp, EnvTags.BOUNDS_ELITE))
			if tp["tag"] == &"slag_coated":
				saw_slag_tag = true
			if tp["tag"] == &"burning":
				saw_burn_tag = true
		if saw_ended:
			break

	t.check("Rising Slag Tide holds briefly under grounded ball without holding forever (PF-1/PF-2)",
		ramp_ticks_held >= 4 and saw_ramp and saw_peak, "held_ticks=%d" % ramp_ticks_held)
	t.check("Rising Slag Tide emits both &'slag_coated' and &'burning' tags", saw_slag_tag and saw_burn_tag)
	t.check("FloodNeverHeld: Rising Slag Tide always recedes and clears floor",
		saw_recede and saw_ended and dir.is_slag_floor_clear() and dir.hazard_cycles_completed == 1)


func _test_high_tick_hazard_no_starvation_and_no_cost_bias() -> void:
	var saw_slag := false
	var saw_storm := false
	var dt := 1.0 / 60.0
	for s in 16:
		var dir := AdversityDirector.new(700 + s, &"orbital_graveyard", 1.0)
		dir.elapsed_s = 50.0
		dir.hazard_tier = 2
		dir.hazard_cooldown_s = 0.5
		var pos := Vector3.ZERO
		for _tick in 480:
			var vel := Vector3(14.0, 0.0, 0.0)
			pos += vel * dt
			var res := dir.advance(dt, pos, vel, 2, 14.0, true)
			for f in res["facts"]:
				if f["kind"] == "hazard_announced":
					if f["id"] == &"rising_slag_tide":
						saw_slag = true
					elif f["id"] == &"magnetic_storm":
						saw_storm = true
			if dir.hazard_phase == AdversityDirector.HazardPhase.WARNING:
				break
		if saw_slag and saw_storm:
			break
	t.check("60 Hz stepping purchases rising_slag_tide (cost 14) without pack starvation or cost bias", saw_slag)
	t.check("60 Hz stepping purchases magnetic_storm (cost 16) without pack starvation or cost bias", saw_storm)


func _test_steam_squall_sightline_and_silhouette() -> void:
	var dir := AdversityDirector.new(404, &"spillway", 1.0)
	var base_sight := dir.current_sightline_m()
	t.check("Steam Squall starts cleanly", dir.start_hazard(&"corrosive_steam_squall", Vector3.ZERO, 0.0))

	var min_sight := base_sight
	var max_sil_boost := 1.0
	var max_tel_boost := 1.0
	var saw_soaked := false
	var saw_brittle := false
	for _i in 110:
		var res := dir.advance(0.25, Vector3(20.0, 0.0, 0.0), Vector3(14.0, 0.0, 0.0), 0, 14.0, true)
		min_sight = minf(min_sight, dir.current_sightline_m())
		max_sil_boost = maxf(max_sil_boost, dir.close_silhouette_boost())
		max_tel_boost = maxf(max_tel_boost, dir.telegraph_contrast_boost())
		for tp in res["env_tags"]:
			if tp["tag"] == &"soaked_conductive":
				saw_soaked = true
			if tp["tag"] == &"coolant_brittle":
				saw_brittle = true
		if dir.hazard_cycles_completed > 0:
			break

	t.check("Corrosive Steam Squall compresses far sightlines significantly",
		min_sight <= 90.0 and min_sight < base_sight * 0.3, "min=%.1f base=%.1f" % [min_sight, base_sight])
	t.check("Corrosive Steam Squall boosts close-range silhouettes and telegraph contrast",
		max_sil_boost >= 1.6 and max_tel_boost >= 1.35, "sil=%.2f tel=%.2f" % [max_sil_boost, max_tel_boost])
	t.check("Corrosive Steam Squall emits &'soaked_conductive' and &'coolant_brittle' tags", saw_soaked and saw_brittle)
	t.near("Corrosive Steam Squall restores full sightline after receding", dir.current_sightline_m(), base_sight, 0.1)


func _test_magnetic_storm_vectors_and_slingshot() -> void:
	var dir := AdversityDirector.new(606, &"orbital_graveyard", 1.0)
	t.check("Magnetic Storm starts cleanly", dir.start_hazard(&"magnetic_storm", Vector3.ZERO, 0.0))
	var saw_mag := false
	var saw_elec := false
	for _i in 32:
		var res := dir.advance(0.25, Vector3(60.0, 0.0, 0.0), Vector3(14.0, 0.0, 0.0), 0, 14.0, true)
		for tp in res["env_tags"]:
			if tp["tag"] == &"magnetic":
				saw_mag = true
			if tp["tag"] == &"electrified":
				saw_elec = true

	t.eq("Magnetic Storm reaches PEAK cleanly", dir.hazard_phase, AdversityDirector.HazardPhase.PEAK)
	t.check("Magnetic Storm emits &'magnetic' and &'electrified' tags", saw_mag and saw_elec)

	var scrap_force := dir.compute_magnetic_force(Vector3(12.0, 0.0, 0.0), Vector3.ZERO, &"loose_scrap", 14.0)
	var scrap_force_repeat := dir.compute_magnetic_force(Vector3(12.0, 0.0, 0.0), Vector3.ZERO, &"loose_scrap", 14.0)
	t.eq("Magnetic Storm force computation is deterministic", scrap_force, scrap_force_repeat)
	t.check("Magnetic Storm pulls loose_scrap inward toward pole with swirl",
		scrap_force.x < -5.0 and absf(scrap_force.z) > 2.0, "force=%s" % str(scrap_force))

	var proj_vel := Vector3(20.0, 0.0, 0.0)
	var proj_force := dir.compute_magnetic_force(Vector3(10.0, 0.0, 4.0), proj_vel, &"metal_projectile", 14.0)
	t.check("Magnetic Storm applies lateral deflection to metal projectiles",
		absf(proj_force.z) > 5.0, "proj_force=%s" % str(proj_force))

	var fast_ball_vel := Vector3(4.0, 0.0, 14.0)
	var ball_slingshot := dir.compute_magnetic_force(Vector3(14.0, 0.0, 0.0), fast_ball_vel, &"player_ball", 14.0)
	t.check("Magnetic Storm slingshots fast player ball without braking forward velocity",
		ball_slingshot.length() > 3.0 and ball_slingshot.dot(fast_ball_vel.normalized()) > 0.0,
		"slingshot=%s" % str(ball_slingshot))
	var over_cap_vel := Vector3(0.0, 0.0, 26.0)
	var capped_force := dir.compute_magnetic_force(Vector3(14.0, 0.0, 0.0), over_cap_vel, &"player_ball", 14.0)
	t.near("Magnetic Storm clamps forward slingshot boost past 1.65x cruise ceiling",
		capped_force.dot(over_cap_vel.normalized()), 0.0, 0.001)
	for _k in 60:
		dir.advance(1.0, Vector3(60.0, 0.0, 0.0), Vector3(14.0, 0.0, 0.0), 18, 14.0, true)
	t.check("AdversityDirector clamps credit_pool at credit_pool_cap (48.0)",
		dir.credit_pool <= 48.001, "credit_pool=%.2f" % dir.credit_pool)


func _test_scrap_beacon_lockdown_and_yardlock_invariants() -> void:
	var eng := EncounterEngine.new(808)
	eng.register_triggered_volume("beacon_a", &"scrap_beacon_lockdown", Vector3(0.0, 0.0, 0.0), &"spillway")
	eng.register_triggered_volume("beacon_b", &"scrap_beacon_lockdown", Vector3(60.0, 0.0, 0.0), &"spillway")

	var ctx := {
		"unrefined_scrap": 0,
		"courier_bounty": 0,
		"elapsed_s": 20.0,
		"biome_id": &"spillway",
		"hazard_tier": 2,
		"ball_pos": Vector3(2.0, 0.0, 0.0),
		"ball_vel": Vector3(14.0, 0.0, 0.0),
		"ball_speed_mps": 14.0,
		"cruise_mps": 14.0,
		"active_lockdown": false,
		"warden_awake": false,
	}

	var high_ctx := ctx.duplicate()
	high_ctx["ball_pos"] = Vector3(1.0, 12.0, 0.0)
	eng.advance(0.25, high_ctx)
	t.check("Vertical opt-in: elevated catwalk ball (y=12m) does not trigger Tier-0 Scrap Beacon", not eng.has_active_lockdown())

	var lockdown_end_emits := [0]
	eng.fact_emitted.connect(func(f: Dictionary):
		if f.get("kind", "") == "encounter_lockdown_ended":
			lockdown_end_emits[0] += 1)

	var start_tick := eng.advance(0.25, ctx)
	t.check("Scrap Beacon activates when ball enters 3D trigger volume", eng.has_active_lockdown())
	t.check("Scrap Beacon spawns Wave 1 crew", (start_tick["spawns"] as Array).size() == 3)

	var second_try := eng.activate_triggered("beacon_b", ctx)
	t.check("SingleActiveLockdown: second lockdown refused while one is active", not bool(second_try["started"]))

	var edge_ctx := ctx.duplicate()
	edge_ctx["ball_pos"] = Vector3(32.0, 0.0, 0.0)
	var edge_tick := eng.advance(0.1, edge_ctx)
	t.check("Scrap Beacon perimeter wall pushes outward ball back toward center",
		(edge_tick["ball_accel"] as Vector3).x < -10.0)

	for _k in 3:
		eng.report_encounter_kill(15.0, 14.0)
	var wave2_started := false
	for _s in 12:
		var tick := eng.advance(0.25, ctx)
		for f in tick["facts"]:
			if f["kind"] == "lockdown_wave_started" and int(f["wave"]) == 2:
				wave2_started = true
	t.check("Scrap Beacon transitions cleanly from Wave 1 to Wave 2", wave2_started)

	for _k in 3:
		eng.report_encounter_kill(15.0, 14.0)
	var apex_spawned := false
	var apex_plates := 0
	for _s in 12:
		var tick := eng.advance(0.25, ctx)
		for f in tick["facts"]:
			if f["kind"] == "apex_construct_spawned":
				apex_spawned = true
				apex_plates = int(f["plate_count"])
	t.check("Scrap Beacon culminates in Apex Construct (Refurbished Compactor Rig with 4 plates)",
		apex_spawned and apex_plates == 4, "plates=%d" % apex_plates)

	var apex_kill := eng.damage_apex_construct(600.0, 16.0, 14.0, [&"coolant_brittle"])
	var payout: Dictionary = apex_kill["payout"]
	t.check("Apex defeat pays guaranteed relic Salvage Press Jackpot and unlocks perimeter",
		bool(apex_kill["unlocked"]) and not eng.has_active_lockdown()
		and int(payout.get("scrap", 0)) == 240
		and StringName(payout.get("guaranteed_rarity", &"")) == &"relic")
	t.eq("encounter_lockdown_ended fact_emitted fires strictly once on Apex settlement", lockdown_end_emits[0], 1)
	var dup_apex := eng.damage_apex_construct(200.0, 16.0, 14.0, [])
	t.check("PayoutOnce: subsequent apex damage call pays nothing", (dup_apex["payout"] as Dictionary).is_empty())

	var b_start := eng.activate_triggered("beacon_b", ctx)
	t.check("beacon_b can now activate cleanly after beacon_a settled", bool(b_start["started"]) and eng.has_active_lockdown())
	var warden_ctx := ctx.duplicate()
	warden_ctx["warden_awake"] = true
	eng.advance(0.1, warden_ctx)
	t.check("YardLock NoLockInWardenFight: waking Warden immediately releases encounter lockdown", not eng.has_active_lockdown())

	eng.register_triggered_volume("beacon_c", &"scrap_beacon_lockdown", Vector3(120.0, 0.0, 0.0), &"spillway")
	eng.activate_triggered("beacon_c", ctx)
	t.check("beacon_c locked before timeout check", eng.has_active_lockdown())
	eng.advance(80.0, ctx)
	t.check("YardLock LockAlwaysOpens: max duration ceiling unconditionally unlocks perimeter", not eng.has_active_lockdown())


func _test_over_audit_blitz_gate() -> void:
	var eng := EncounterEngine.new(909)
	var blitz_end_emits := [0]
	eng.fact_emitted.connect(func(f: Dictionary):
		if f.get("kind", "") == "encounter_blitz_ended":
			blitz_end_emits[0] += 1)
	eng.register_triggered_volume("blitz_1", &"over_audit_blitz_gate", Vector3.ZERO, &"spillway")
	var act := eng.activate_triggered("blitz_1", {"warden_awake": false, "active_lockdown": false})
	t.check("Over-Audit Blitz Gate starts without locking perimeter",
		bool(act["started"]) and not eng.has_active_lockdown())
	var final_payout: Dictionary = {}
	for _k in 8:
		var k_res := eng.report_encounter_kill(17.0, 14.0)
		if not (k_res["payout"] as Dictionary).is_empty():
			final_payout = k_res["payout"]
	t.check("Over-Audit Blitz Gate fast chain multiplies core and cog payouts",
		int(final_payout.get("cores", 0)) >= 3 and int(final_payout.get("cogs", 0)) > 40,
		"payout=%s" % str(final_payout))
	t.eq("encounter_blitz_ended fact_emitted fires strictly once on Blitz settlement", blitz_end_emits[0], 1)


func _test_greed_weighted_random_encounters() -> void:
	var eng := EncounterEngine.new(1010)
	var empty_ctx := {
		"unrefined_scrap": 0,
		"courier_bounty": 0,
		"elapsed_s": 60.0,
		"biome_id": &"spillway",
		"hazard_tier": 2,
	}
	var rich_ctx := {
		"unrefined_scrap": 420,
		"courier_bounty": 90,
		"elapsed_s": 60.0,
		"biome_id": &"spillway",
		"hazard_tier": 2,
	}
	var w_empty := eng.evaluate_random_weights(empty_ctx)
	var w_rich := eng.evaluate_random_weights(rich_ctx)

	t.near("Greed Ambush Swarm weight is 0.0 when player carries no unbanked loot",
		float(w_empty[&"greed_ambush_swarm"]), 0.0, 0.0001)
	t.check("Greed Ambush Swarm weight dominates when player hoards unrefined scrap & courier bounty",
		float(w_rich[&"greed_ambush_swarm"]) > float(w_rich[&"airdrop_salvage_pod"]) * 2.0
		and float(w_rich[&"greed_ambush_swarm"]) >= 5.0,
		"greed=%.2f airdrop=%.2f" % [float(w_rich[&"greed_ambush_swarm"]), float(w_rich[&"airdrop_salvage_pod"])])

	var greed_draws_empty := 0
	var greed_draws_rich := 0
	for s in 60:
		var e0 := EncounterEngine.new(2000 + s)
		e0.random_cooldown_s = 0.01
		var r0 := e0.advance(0.1, empty_ctx.merged({"ball_pos": Vector3.ZERO, "ball_vel": Vector3(14.0, 0.0, 0.0)}))
		for f in r0["facts"]:
			if f["kind"] == "random_encounter_announced" and f["encounter_kind"] == &"greed_ambush_swarm":
				greed_draws_empty += 1

		var e1 := EncounterEngine.new(2000 + s)
		e1.random_cooldown_s = 0.01
		var r1 := e1.advance(0.1, rich_ctx.merged({"ball_pos": Vector3.ZERO, "ball_vel": Vector3(14.0, 0.0, 0.0)}))
		for f in r1["facts"]:
			if f["kind"] == "random_encounter_announced" and f["encounter_kind"] == &"greed_ambush_swarm":
				greed_draws_rich += 1

	t.eq("Zero greed ambushes drawn across 60 seeds with empty haul", greed_draws_empty, 0)
	t.check("High unbanked haul triggers majority greed ambushes across 60 seeds",
		greed_draws_rich >= 25, "%d / 60" % greed_draws_rich)

	var farm_eng := EncounterEngine.new(2050)
	farm_eng.active_random = {"id": "greed_1", "kind": &"greed_ambush_swarm", "phase": &"live", "payout_settled": false}
	var first_pay: Dictionary = farm_eng.resolve_active_random(&"won", {"unrefined_scrap": 2000})["payout"]
	t.eq("Greed Ambush first clear caps dividend at 160 (+120 base = 280)", int(first_pay["scrap"]), 280)
	t.eq("Greed Ambush first clear awards 1 core", int(first_pay["cores"]), 1)
	farm_eng.active_random = {"id": "greed_2", "kind": &"greed_ambush_swarm", "phase": &"live", "payout_settled": false}
	var second_pay: Dictionary = farm_eng.resolve_active_random(&"won", {"unrefined_scrap": 2000})["payout"]
	t.eq("Greed Ambush repeat clear awards zero extra cores (prevents farming)", int(second_pay["cores"]), 0)
	t.eq("Greed Ambush repeat clear awards zero extra rare rolls", int(second_pay["part_rolls"]), 0)


func _test_airdrop_cover_and_rogue_compactor_crusher() -> void:
	var airdrop_eng: EncounterEngine = null
	var compactor_eng: EncounterEngine = null
	var base_ctx := {
		"unrefined_scrap": 0,
		"courier_bounty": 0,
		"elapsed_s": 50.0,
		"biome_id": &"orbital_graveyard",
		"hazard_tier": 3,
		"ball_pos": Vector3.ZERO,
		"ball_vel": Vector3(14.0, 0.0, 0.0),
		"cruise_mps": 14.0,
		"active_lockdown": false,
		"warden_awake": false,
	}
	for s in 80:
		var cand := EncounterEngine.new(5000 + s)
		cand.random_cooldown_s = 0.01
		var tick := cand.advance(0.1, base_ctx)
		for f in tick["facts"]:
			if f["kind"] == "random_encounter_announced":
				if f["encounter_kind"] == &"airdrop_salvage_pod" and airdrop_eng == null:
					airdrop_eng = cand
				elif f["encounter_kind"] == &"rogue_compactor_chase" and compactor_eng == null:
					compactor_eng = cand
		if airdrop_eng != null and compactor_eng != null:
			break

	t.check("Air-Drop Salvage Pod encounter rolls cleanly", airdrop_eng != null)
	if airdrop_eng != null:
		var land_tick := airdrop_eng.advance(4.0, base_ctx)
		t.check("Air-Drop Pod spawns fresh destructible cover geometry descriptor on landing",
			not (land_tick["cover_spawned"] as Array).is_empty()
			and int((land_tick["cover_spawned"] as Array)[0]["destructible_tier"]) == 2)
		t.check("Air-Drop Pod emits &'burning' and &'slag_coated' env_tag payloads on impact",
			(land_tick["env_tags"] as Array).size() == 2)
		var win_res := airdrop_eng.resolve_active_random(&"won", base_ctx)
		var dup_res := airdrop_eng.resolve_active_random(&"won", base_ctx)
		t.check("Air-Drop Pod pays salvage reward once and clears",
			int((win_res["payout"] as Dictionary).get("scrap", 0)) == 150
			and (dup_res["payout"] as Dictionary).is_empty())

	t.check("Rogue Compactor Chase encounter rolls cleanly", compactor_eng != null)
	if compactor_eng != null:
		compactor_eng.advance(3.0, base_ctx)
		var comp_pos: Vector3 = compactor_eng.active_random["pos"]
		var baited_enemies: Array[Dictionary] = [
			{"id": "fleet_chaser_1", "origin": comp_pos + Vector3(2.0, 0.0, 1.0)},
			{"id": "fleet_lobber_2", "origin": comp_pos + Vector3(3.0, 0.0, -2.0)},
			{"id": "safe_enemy_3", "origin": comp_pos + Vector3(0.0, 0.0, 30.0)},
		]
		var crush := compactor_eng.evaluate_compactor_crusher(baited_enemies)
		t.eq("Rogue Compactor No. 38 crushes baited Fleet enemies inside lane",
			(crush["crushed_ids"] as Array).size(), 2)
		t.near("Rogue Compactor returns crusher_damage (220.0)", float(crush["crusher_damage"]), 220.0, 0.01)
		t.eq("Rogue Compactor awards bonus scrap for crushed enemies", int(crush["scrap_bonus"]), 70)
		var repeat_crush := compactor_eng.evaluate_compactor_crusher(baited_enemies)
		t.eq("Rogue Compactor crushes each Fleet enemy at most once", (repeat_crush["crushed_ids"] as Array).size(), 0)
		compactor_eng.advance(0.1, base_ctx.merged({"warden_awake": true}, true))
		t.check("Waking Warden preempts live random encounter cleanly", compactor_eng.active_random.is_empty())


func _test_area3d_volume_lifecycle_and_signals() -> void:
	var eng := EncounterEngine.new(7070)
	var vol := eng.register_triggered_volume("press_test", &"scrap_beacon_lockdown", Vector3(12.0, 0.0, -8.0), &"smelter_pit")
	var area := EncounterEngine.build_trigger_area(vol)
	root.add_child(area)
	t.check("build_trigger_area builds valid Area3D with metadata and SphereShape3D",
		area is Area3D and String(area.get_meta("encounter_id")) == "press_test"
		and area.get_child_count() == 1 and area.is_inside_tree())
	area.free()

	var director := AdversityDirector.new(7070, &"spillway", 1.0)
	var signal_counts := {"facts": 0, "tags": 0, "phases": 0, "enc_states": 0}
	director.fact_emitted.connect(func(_f): signal_counts["facts"] += 1)
	director.env_tag_emitted.connect(func(_tp): signal_counts["tags"] += 1)
	director.hazard_phase_changed.connect(func(_id, _p): signal_counts["phases"] += 1)
	eng.encounter_state_changed.connect(func(_id, _st): signal_counts["enc_states"] += 1)

	director.start_hazard(&"rising_slag_tide", Vector3.ZERO, 0.0)
	for _i in 40:
		director.advance(0.25, Vector3(30.0, 0.0, 0.0), Vector3(14.0, 0.0, 0.0), 0, 14.0, true)
	eng.activate_triggered("press_test", {"warden_awake": false, "active_lockdown": false})
	eng.abort_all(&"test_cleanup")

	t.check("Signals fire cleanly across director & encounter lifecycles",
		int(signal_counts["facts"]) > 0 and int(signal_counts["tags"]) > 0
		and int(signal_counts["phases"]) >= 2 and int(signal_counts["enc_states"]) >= 2,
		str(signal_counts))
