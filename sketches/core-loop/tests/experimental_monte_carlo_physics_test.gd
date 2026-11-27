extends SceneTree

const T := preload("res://tests/support/t.gd")
const EnvTags := preload("res://src/experimental/env_tags.gd")
const PartResource := preload("res://src/experimental/part_resource.gd")
const JuryRig := preload("res://src/experimental/jury_rig_synergies.gd")
const Ecology := preload("res://src/experimental/ecology_actors.gd")
const AdversityDirector := preload("res://src/experimental/adversity_director.gd")
const RefurbishedElites := preload("res://src/experimental/refurbished_elites.gd")
const EncounterEngine := preload("res://src/experimental/encounter_engine.gd")
const DynamicSetpieces := preload("res://src/experimental/dynamic_setpieces.gd")
const ChunkSockets := preload("res://src/experimental/arena_chunk_socket.gd")


const CHUNK_PATH := "res://src/experimental/smelter_crane_chunk.tscn"
const MC_SEEDS := 50
const RUN_DURATION_S := 45.0
const SIM_DT := 0.25
const SIM_STEPS := int(RUN_DURATION_S / SIM_DT)

const WEAPON_PARTS: Array[StringName] = [&"magnetized_sawblades", &"requisition_leech"]
const DASH_PARTS: Array[StringName] = [&"arc_welder_dash", &"harpoon_grounding_spike", &"slag_skid_crucible"]
const CORE_PARTS: Array[StringName] = [&"brine_tap_vent", &"hoard_coil_ballast", &"thermite_flail_spool"]
const ARCHETYPES: Array[StringName] = [&"staller", &"flow_runner", &"greedy_hoarder", &"synergy_builder"]
const ENEMY_KILL_SCRAP := 3
const PLAYER_MAX_HULL_HP := 120.0
const ARENA_HALF_EXTENT_M := 27.0

var t := T.new("experimental_monte_carlo_physics_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_run_monte_carlo_balance_sweep()
	await _run_navigation_server_3d_proof()
	await _run_physics_server_3d_proof()
	quit(t.verdict())



func _run_monte_carlo_balance_sweep() -> void:
	var all_loadouts: Array[Array] = []
	for w in WEAPON_PARTS:
		for d in DASH_PARTS:
			for c in CORE_PARTS:
				all_loadouts.append([w, d, c])

	var metrics_by_arch := {}
	for arch in ARCHETYPES:
		metrics_by_arch[arch] = {
			"scores": [] as Array[float],
			"damages": [] as Array[float],
			"kills": [] as Array[float],
			"reactions": [] as Array[float],
			"synergies": [] as Array[float],
			"cooked": [] as Array[float],
			"stall_peaks": [] as Array[float],
			"greed_peaks": [] as Array[float],
			"scrap_yields": [] as Array[float],
			"pressure_dmg": [] as Array[float],
			"elites_seen": [] as Array[float],
			"plates_broken": [] as Array[float],
			"survived_s": [] as Array[float],
			"survived_count": 0,
		}

	var part_scores := {}
	var part_direct_dmg := {}
	var part_fires := {}
	for pid in WEAPON_PARTS + DASH_PARTS + CORE_PARTS:
		part_scores[pid] = [] as Array[float]
		part_direct_dmg[pid] = [] as Array[float]
		part_fires[pid] = [] as Array[float]

	var total_runs := 0
	var total_deadlocks := 0
	var max_cascade_depth_seen := 0
	var total_elites_spawned := 0
	var total_plates_broken := 0
	var flow_beats_staller_seeds := 0
	var synergy_beats_staller_seeds := 0
	var synergy_beats_flow_seeds := 0

	for s_idx in MC_SEEDS:
		var seed_val := 1001 + s_idx
		var seed_scores := {}
		for arch in ARCHETYPES:
			var loadout: Array = _pick_loadout_for(arch, s_idx, all_loadouts)
			var run_out := _simulate_archetype_run(seed_val, arch, loadout)
			total_runs += 1
			total_deadlocks += int(run_out["deadlocks"])
			max_cascade_depth_seen = maxi(max_cascade_depth_seen, int(run_out["max_cascade_depth"]))
			total_elites_spawned += int(run_out["elites_spawned"])
			total_plates_broken += int(run_out["plates_broken"])
			seed_scores[arch] = float(run_out["score"])

			var bucket: Dictionary = metrics_by_arch[arch]
			(bucket["scores"] as Array[float]).append(float(run_out["score"]))
			(bucket["damages"] as Array[float]).append(float(run_out["damage_dealt"]))
			(bucket["kills"] as Array[float]).append(float(run_out["enemies_killed"]))
			(bucket["reactions"] as Array[float]).append(float(run_out["reactions"]))
			(bucket["synergies"] as Array[float]).append(float(run_out["synergies"]))
			(bucket["cooked"] as Array[float]).append(float(run_out["hull_cooked"]))
			(bucket["stall_peaks"] as Array[float]).append(float(run_out["stall_peak"]))
			(bucket["greed_peaks"] as Array[float]).append(float(run_out["greed_peak"]))
			(bucket["scrap_yields"] as Array[float]).append(float(run_out["scrap_yield"]))
			(bucket["pressure_dmg"] as Array[float]).append(float(run_out["pressure_damage"]))
			(bucket["elites_seen"] as Array[float]).append(float(run_out["elites_spawned"]))
			(bucket["plates_broken"] as Array[float]).append(float(run_out["plates_broken"]))
			(bucket["survived_s"] as Array[float]).append(float(run_out["survived_s"]))
			if bool(run_out["survived"]):
				bucket["survived_count"] = int(bucket["survived_count"]) + 1

			if arch == &"synergy_builder":
				var fire_map: Dictionary = run_out["part_fires"]
				var dmg_map: Dictionary = run_out["part_direct_dmg"]
				for pid in loadout:
					(part_scores[pid] as Array[float]).append(float(run_out["score"]))
					(part_direct_dmg[pid] as Array[float]).append(float(dmg_map.get(pid, 0.0)))
					(part_fires[pid] as Array[float]).append(float(fire_map.get(pid, 0)))

		if float(seed_scores[&"flow_runner"]) > float(seed_scores[&"staller"]):
			flow_beats_staller_seeds += 1
		if float(seed_scores[&"synergy_builder"]) > float(seed_scores[&"staller"]):
			synergy_beats_staller_seeds += 1
		if float(seed_scores[&"synergy_builder"]) > float(seed_scores[&"flow_runner"]):
			synergy_beats_flow_seeds += 1

	print("=== CLOSED-LOOP MONTE-CARLO TELEMETRY (%d seeds x %d archetypes = %d runs, %.0f s/run) ===" % [
		MC_SEEDS, ARCHETYPES.size(), total_runs, RUN_DURATION_S
	])
	var summary := {}
	for arch in ARCHETYPES:
		var b: Dictionary = metrics_by_arch[arch]
		var s_pct := _percentiles(b["scores"])
		var d_pct := _percentiles(b["damages"])
		var k_pct := _percentiles(b["kills"])
		var r_pct := _percentiles(b["reactions"])
		var syn_pct := _percentiles(b["synergies"])
		var c_pct := _percentiles(b["cooked"])
		var st_pct := _percentiles(b["stall_peaks"])
		var gr_pct := _percentiles(b["greed_peaks"])
		var sc_pct := _percentiles(b["scrap_yields"])
		var pr_pct := _percentiles(b["pressure_dmg"])
		var el_pct := _percentiles(b["elites_seen"])
		var pl_pct := _percentiles(b["plates_broken"])
		var sv_pct := _percentiles(b["survived_s"])
		var surv_rate := 100.0 * float(int(b["survived_count"])) / float(MC_SEEDS)
		summary[arch] = {
			"score": s_pct, "damage": d_pct, "kills": k_pct, "reactions": r_pct, "synergies": syn_pct,
			"cooked": c_pct, "stall": st_pct, "greed": gr_pct, "scrap": sc_pct, "pressure": pr_pct,
			"elites": el_pct, "plates": pl_pct, "survived_s": sv_pct, "surv_rate": surv_rate,
		}
		print("  %-16s | surv:%5.1f%% (t=%.1fs) | score p10/med/p90: %6.1f / %6.1f / %6.1f | dmg:%6.1f | kills:%4.1f | rx:%4.1f | syn:%4.1f | cook:%5.1f | stall:%.2f | greed:%.2f | scrap:%5.1f | pressure:%5.1f | elites:%3.1f | plates:%3.1f" % [
			String(arch), surv_rate, sv_pct["p50"],
			s_pct["p10"], s_pct["p50"], s_pct["p90"],
			d_pct["p50"], k_pct["p50"], r_pct["p50"], syn_pct["p50"],
			c_pct["p50"], st_pct["p50"], gr_pct["p50"],
			sc_pct["p50"], pr_pct["p50"], el_pct["p50"], pl_pct["p50"],
		])

	print("=== PER-PART BALANCE TELEMETRY (Synergy Builder across all 18 3-slot .tres combos) ===")
	var part_med_score := {}
	var part_med_direct := {}
	var part_med_fires := {}
	for pid in WEAPON_PARTS + DASH_PARTS + CORE_PARTS:
		var ps := _percentiles(part_scores[pid])
		var pd := _percentiles(part_direct_dmg[pid])
		var pf := _percentiles(part_fires[pid])
		part_med_score[pid] = float(ps["p50"])
		part_med_direct[pid] = float(pd["p50"])
		part_med_fires[pid] = float(pf["p50"])
		print("  %-26s | run_score p10/med/p90: %6.1f / %6.1f / %6.1f | direct_dmg med:%6.1f | fires med:%4.1f (n=%d)" % [
			String(pid), ps["p10"], ps["p50"], ps["p90"], pd["p50"], pf["p50"], (part_scores[pid] as Array).size()
		])

	t.eq("mc_total_runs_200", total_runs, MC_SEEDS * ARCHETYPES.size())
	t.eq("mc_zero_deadlocks_across_200_runs", total_deadlocks, 0)
	t.check("mc_cascade_depth_bounded", max_cascade_depth_seen <= EnvTags.MAX_CASCADE_DEPTH,
		"max_depth=%d cap=%d" % [max_cascade_depth_seen, EnvTags.MAX_CASCADE_DEPTH])
	t.check("mc_refurbished_elites_exercised_and_plates_shattered",
		total_elites_spawned >= 100 and total_plates_broken >= 100,
		"elites_spawned=%d plates_broken=%d" % [total_elites_spawned, total_plates_broken])

	var staller: Dictionary = summary[&"staller"]
	var flow: Dictionary = summary[&"flow_runner"]
	var greed: Dictionary = summary[&"greedy_hoarder"]
	var syn: Dictionary = summary[&"synergy_builder"]

	print("  [paired A/B win rates across %d seeds] flow>staller: %d/%d | synergy>staller: %d/%d | synergy>flow: %d/%d" % [
		MC_SEEDS, flow_beats_staller_seeds, MC_SEEDS, synergy_beats_staller_seeds, MC_SEEDS, synergy_beats_flow_seeds, MC_SEEDS
	])

	t.check("mc_flow_and_synergy_survive_while_staller_dies_to_real_cook_and_pressure",
		float(flow["surv_rate"]) >= 90.0
		and float(syn["surv_rate"]) >= 95.0
		and float(staller["surv_rate"]) <= 20.0
		and float(flow["kills"]["p50"]) >= float(staller["kills"]["p50"]) * 3.0
		and float(syn["kills"]["p50"]) >= float(staller["kills"]["p50"]) * 4.0,
		"flow_surv=%.1f%% syn_surv=%.1f%% staller_surv=%.1f%% kills(f/s/st)=%.1f/%.1f/%.1f" % [
			float(flow["surv_rate"]), float(syn["surv_rate"]), float(staller["surv_rate"]),
			float(flow["kills"]["p50"]), float(syn["kills"]["p50"]), float(staller["kills"]["p50"]),
		])
	t.check("mc_flow_paired_beats_staller_on_90pct_seeds",
		flow_beats_staller_seeds >= int(MC_SEEDS * 0.90)
		and float(flow["score"]["p50"]) > float(staller["score"]["p50"]) * 1.5,
		"flow_wins=%d/%d flow_med=%.1f staller_med=%.1f" % [
			flow_beats_staller_seeds, MC_SEEDS, float(flow["score"]["p50"]), float(staller["score"]["p50"])
		])
	t.check("mc_synergy_beats_staller_on_96pct_seeds_and_p10_gt_staller_p90",
		synergy_beats_staller_seeds >= int(MC_SEEDS * 0.96)
		and float(syn["score"]["p10"]) > float(staller["score"]["p90"])
		and float(syn["score"]["p50"]) > float(staller["score"]["p50"]) * 2.0,
		"syn_wins=%d/%d syn_p10=%.1f syn_med=%.1f staller_med=%.1f staller_p90=%.1f" % [
			synergy_beats_staller_seeds, MC_SEEDS,
			float(syn["score"]["p10"]), float(syn["score"]["p50"]),
			float(staller["score"]["p50"]), float(staller["score"]["p90"]),
		])
	t.check("mc_synergy_median_beats_flow",
		synergy_beats_flow_seeds >= int(MC_SEEDS * 0.70)
		and float(syn["score"]["p50"]) > float(flow["score"]["p50"]),
		"syn_gt_flow=%d/%d syn_med=%.1f flow_med=%.1f" % [
			synergy_beats_flow_seeds, MC_SEEDS,
			float(syn["score"]["p50"]), float(flow["score"]["p50"]),
		])
	t.check("mc_synergy_drives_more_reactions_and_synergies_than_staller",
		float(syn["reactions"]["p50"]) > float(staller["reactions"]["p50"])
		and float(syn["synergies"]["p50"]) > float(staller["synergies"]["p50"]),
		"syn_rx=%.1f staller_rx=%.1f syn_syn=%.1f staller_syn=%.1f" % [
			float(syn["reactions"]["p50"]), float(staller["reactions"]["p50"]),
			float(syn["synergies"]["p50"]), float(staller["synergies"]["p50"]),
		])
	t.check("mc_staller_triggers_stall_meter_and_real_pressure_while_flow_stays_clear",
		float(staller["stall"]["p50"]) >= 0.85
		and float(flow["stall"]["p50"]) <= 0.05
		and float(staller["pressure"]["p50"]) > float(flow["pressure"]["p50"]) * 2.0,
		"staller_stall=%.2f flow_stall=%.2f staller_p=%.1f flow_p=%.1f" % [
			float(staller["stall"]["p50"]), float(flow["stall"]["p50"]),
			float(staller["pressure"]["p50"]), float(flow["pressure"]["p50"]),
		])
	t.check("mc_staller_cooks_naturally_from_real_part_heat_while_flow_and_synergy_vent",
		float(staller["cooked"]["p50"]) > 0.0
		and float(flow["cooked"]["p50"]) == 0.0
		and float(syn["cooked"]["p50"]) == 0.0,
		"staller_cook=%.1f flow_cook=%.1f syn_cook=%.1f" % [
			float(staller["cooked"]["p50"]), float(flow["cooked"]["p50"]), float(syn["cooked"]["p50"])
		])

	t.check("mc_greed_hoarder_earns_more_real_scrap_than_flow_and_staller",
		float(greed["scrap"]["p50"]) > float(flow["scrap"]["p50"])
		and float(greed["scrap"]["p50"]) > float(staller["scrap"]["p50"]),
		"greed_scrap=%.1f flow_scrap=%.1f staller_scrap=%.1f" % [
			float(greed["scrap"]["p50"]), float(flow["scrap"]["p50"]), float(staller["scrap"]["p50"])
		])
	t.check("mc_greed_hoarder_spikes_ambush_weight_and_real_enemy_pressure",
		float(greed["greed"]["p50"]) > float(flow["greed"]["p50"]) + 1.5
		and float(greed["pressure"]["p50"]) > float(flow["pressure"]["p50"]),
		"greed_w=%.2f flow_w=%.2f greed_p=%.1f flow_p=%.1f" % [
			float(greed["greed"]["p50"]), float(flow["greed"]["p50"]),
			float(greed["pressure"]["p50"]), float(flow["pressure"]["p50"]),
		])

	var slot_groups := {
		"WEAPON": WEAPON_PARTS,
		"DASH_LINE": DASH_PARTS,
		"CORE_HUSK": CORE_PARTS,
	}
	for slot_name in slot_groups:
		var ids: Array[StringName] = slot_groups[slot_name]
		var lo := INF
		var hi := -INF
		for pid in ids:
			var med_s: float = float(part_med_score[pid])
			var med_f: float = float(part_med_fires[pid])
			var med_d: float = float(part_med_direct[pid])
			t.check("mc_part_active_" + String(pid), med_f >= 1.0 and med_s > 0.0,
				"fires_med=%.1f direct_dmg_med=%.1f score_med=%.1f" % [med_f, med_d, med_s])
			lo = minf(lo, med_s)
			hi = maxf(hi, med_s)
		var ratio := hi / maxf(1.0, lo)
		t.check("mc_slot_balanced_" + slot_name, ratio <= 1.65,
			"slot=%s hi=%.1f lo=%.1f ratio=%.2fx (limit 1.65x)" % [slot_name, hi, lo, ratio])


func _pick_loadout_for(arch: StringName, seed_idx: int, all_loadouts: Array[Array]) -> Array:
	if arch == &"greedy_hoarder":
		var w: StringName = &"requisition_leech" if (seed_idx % 2 == 0) else &"magnetized_sawblades"
		var d: StringName = DASH_PARTS[seed_idx % DASH_PARTS.size()]
		var c: StringName = &"hoard_coil_ballast" if (seed_idx % 2 == 0) else CORE_PARTS[seed_idx % CORE_PARTS.size()]
		return [w, d, c]
	return all_loadouts[seed_idx % all_loadouts.size()]


func _map_fleet_kind_to_eco_role(kind: StringName) -> StringName:
	match kind:
		&"chaser":
			return Ecology.ROLE_SWARMER
		&"plated_brute", &"boom_tender":
			return Ecology.ROLE_SHIELDED_BULWARK
		&"lobber", &"jolt_layer", &"hooker":
			return Ecology.ROLE_ARC_SNIPER
		&"winch_drone", &"dispatcher":
			return Ecology.ROLE_WELD_HEALER
		_:
			return Ecology.ROLE_SWARMER


func _clamp_arena(pos: Vector3) -> Vector3:
	return Vector3(
		clampf(pos.x, -ARENA_HALF_EXTENT_M, ARENA_HALF_EXTENT_M),
		0.0,
		clampf(pos.z, -ARENA_HALF_EXTENT_M, ARENA_HALF_EXTENT_M)
	)


func _simulate_archetype_run(seed_val: int, arch: StringName, loadout: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 31 + int(ARCHETYPES.find(arch)) * 101

	var field := EnvTags.new()
	var rig := JuryRig.new(field)
	var eco := Ecology.new(field)
	var director := AdversityDirector.new(seed_val, &"smelter_pit", 1.0)
	var encounters := EncounterEngine.new(seed_val)
	var elite_pool: Array = RefurbishedElites.load_default_pool()

	for pid in loadout:
		rig.equip_by_id(pid)

	var live_enemy_ids: Array[String] = []
	var encounter_elites: Array = []
	var sniper_aim_pos := {}
	var elite_tells := {}
	var state_ref := {
		"ball_pos": Vector3.ZERO,
		"speed": 14.0,
		"damage_dealt": 0.0,
		"enemies_killed": 0,
		"plates_broken": 0,
		"elites_spawned": 0,
		"scrap_carried": 0,
		"scrap_banked": 0,
		"courier_bounty": 0,
		"pressure_damage": 0.0,
		"max_cascade_depth": 0,
		"synergies": 0,
		"hoards_unbanked": arch == &"greedy_hoarder",
	}
	var part_fires := {}
	var part_direct_dmg := {}

	var grant_scrap := func(amount: int) -> void:
		if amount <= 0:
			return
		state_ref["scrap_banked"] = int(state_ref["scrap_banked"]) + amount
		if bool(state_ref["hoards_unbanked"]):
			state_ref["scrap_carried"] = int(state_ref["scrap_carried"]) + amount
		else:
			state_ref["scrap_carried"] = mini(40, int(state_ref["scrap_carried"]) + amount)

	var apply_combat_damage := func(origin: Vector3, radius_m: float, raw_dmg: float, dmg_kind: StringName) -> float:
		if raw_dmg <= 0.0:
			return 0.0
		var dealt_total := 0.0
		for eid in live_enemy_ids:
			var e := eco.enemy(eid)
			if e == null or e.is_dead():
				continue
			if Vector2(e.pos.x - origin.x, e.pos.z - origin.z).length() <= radius_m:
				var was_dead := e.is_dead()
				var d_res := eco.damage_enemy(eid, raw_dmg, origin, dmg_kind)
				var dealt := float(d_res.get("damage_dealt", 0.0))
				dealt_total += dealt
				if not was_dead and bool(d_res.get("dead", false)):
					state_ref["enemies_killed"] = int(state_ref["enemies_killed"]) + 1
					grant_scrap.call(ENEMY_KILL_SCRAP)
		var all_elites: Array = []
		all_elites.append_array(director.active_elites)
		all_elites.append_array(encounter_elites)
		for inst in all_elites:
			if inst.is_defeated():
				continue
			if Vector2(inst.origin.x - origin.x, inst.origin.z - origin.z).length() <= radius_m + 2.5:
				var live_tags: Array[StringName] = field.tags_at(inst.origin, 4.5)
				var ehit: Dictionary = inst.apply_hit(raw_dmg, float(state_ref["speed"]), 14.0, live_tags, state_ref["ball_pos"] as Vector3)
				var edmg := float(ehit.get("plate_damage", 0.0)) + float(ehit.get("hull_damage", 0.0))
				dealt_total += edmg
				state_ref["plates_broken"] = int(state_ref["plates_broken"]) + int(ehit.get("plates_broken", 0))
				for ptag in ehit.get("env_tags", []):
					field.apply_tag(ptag)
				var bounty: Dictionary = ehit.get("bounty", {})
				if not bounty.is_empty():
					state_ref["enemies_killed"] = int(state_ref["enemies_killed"]) + 1
					grant_scrap.call(int(bounty.get("scrap", 0)))
		return dealt_total

	var fref: WeakRef = weakref(field)
	var dir_bridge := func(p: Dictionary) -> void:
		var f: Variant = fref.get_ref()
		if f != null:
			f.apply_tag(p)
	var enc_bridge := func(p: Dictionary) -> void:
		var f: Variant = fref.get_ref()
		if f != null:
			f.apply_tag(p)
	director.env_tag_emitted.connect(dir_bridge)
	encounters.env_tag_emitted.connect(enc_bridge)

	var rx_cb := func(rx: Dictionary) -> void:
		state_ref["max_cascade_depth"] = maxi(int(state_ref["max_cascade_depth"]), int(rx.get("depth", 0)))
		var r_dmg := float(rx.get("damage", 0.0))
		var r_origin: Vector3 = rx.get("origin", Vector3.ZERO)
		var r_rad := float(rx.get("radius_m", 6.0))
		var hits_eco := 0
		for eid in live_enemy_ids:
			var e := eco.enemy(eid)
			if e != null and not e.is_dead() and Vector2(e.pos.x - r_origin.x, e.pos.z - r_origin.z).length() <= r_rad:
				hits_eco += 1
		if hits_eco > 0:
			state_ref["damage_dealt"] = float(state_ref["damage_dealt"]) + r_dmg * 0.5 * float(hits_eco)
		var all_elites: Array = []
		all_elites.append_array(director.active_elites)
		all_elites.append_array(encounter_elites)
		for inst in all_elites:
			if inst.is_defeated():
				continue
			if Vector2(inst.origin.x - r_origin.x, inst.origin.z - r_origin.z).length() <= r_rad + 2.5:
				var live_tags: Array[StringName] = field.tags_at(inst.origin, 4.5)
				var ehit: Dictionary = inst.apply_hit(r_dmg * 0.6, float(state_ref["speed"]), 14.0, live_tags, r_origin)
				var edmg := float(ehit.get("plate_damage", 0.0)) + float(ehit.get("hull_damage", 0.0))
				state_ref["damage_dealt"] = float(state_ref["damage_dealt"]) + edmg
				state_ref["plates_broken"] = int(state_ref["plates_broken"]) + int(ehit.get("plates_broken", 0))
				var bounty: Dictionary = ehit.get("bounty", {})
				if not bounty.is_empty():
					state_ref["enemies_killed"] = int(state_ref["enemies_killed"]) + 1
					grant_scrap.call(int(bounty.get("scrap", 0)))
	field.reaction_triggered.connect(rx_cb)

	var part_cb := func(rcpt: Dictionary) -> void:
		var pid: StringName = rcpt.get("part_id", &"")
		part_fires[pid] = int(part_fires.get(pid, 0)) + 1
		var p_dmg := float(rcpt.get("damage", 0.0))
		var origin: Vector3 = rcpt.get("origin", state_ref["ball_pos"] as Vector3)
		var dealt: float = apply_combat_damage.call(origin, 11.0, p_dmg, &"arc")
		state_ref["damage_dealt"] = float(state_ref["damage_dealt"]) + dealt
		part_direct_dmg[pid] = float(part_direct_dmg.get(pid, 0.0)) + dealt
		var bonus_scrap := int(rcpt.get("bonus_scrap", 0))
		if bonus_scrap > 0:
			grant_scrap.call(bonus_scrap)
	rig.part_fired.connect(part_cb)

	var syn_cb := func(syn: Dictionary) -> void:
		state_ref["synergies"] = int(state_ref["synergies"]) + 1
		var s_dmg := float(syn.get("bonus_damage", 0.0))
		var dealt: float = apply_combat_damage.call(state_ref["ball_pos"] as Vector3, 18.0, s_dmg, &"arc")
		state_ref["damage_dealt"] = float(state_ref["damage_dealt"]) + dealt
		var prods: Array = syn.get("producers", [])
		if not prods.is_empty():
			var share := dealt / float(prods.size())
			for prod_id in prods:
				var sn := StringName(prod_id)
				part_direct_dmg[sn] = float(part_direct_dmg.get(sn, 0.0)) + share
	rig.synergy_emerged.connect(syn_cb)

	var spawn_serial := [0]
	var add_live_enemy := func(role: StringName, pos: Vector3) -> void:
		spawn_serial[0] = int(spawn_serial[0]) + 1
		var eid := "e_%d" % int(spawn_serial[0])
		eco.spawn_enemy(eid, role, _clamp_arena(pos))
		live_enemy_ids.append(eid)

	add_live_enemy.call(Ecology.ROLE_SWARMER, Vector3(9.0, 0.0, 2.0))
	add_live_enemy.call(Ecology.ROLE_SHIELDED_BULWARK, Vector3(12.0, 0.0, -3.0))
	add_live_enemy.call(Ecology.ROLE_ARC_SNIPER, Vector3(16.0, 0.0, 5.0))
	add_live_enemy.call(Ecology.ROLE_WELD_HEALER, Vector3(11.0, 0.0, 4.0))
	eco.spawn_prop("cool_init", Ecology.PROP_COOLANT_TANK, Vector3(8.0, 0.0, -1.0))
	eco.spawn_prop("drum_init", Ecology.PROP_SLAG_DRUM, Vector3(10.0, 0.0, 2.5))
	eco.spawn_prop("pile_init", Ecology.PROP_SCRAP_PILE, Vector3(13.0, 0.0, 0.5))

	var ball_pos := Vector3(0.0, 0.2, 0.0)
	var heading := 0.0
	var hull_hp := PLAYER_MAX_HULL_HP
	var survived := true
	var survived_s := RUN_DURATION_S
	var stall_peak := 0.0
	var greed_peak := 0.0
	var deadlocks := 0
	var prop_respawn_serial := 0
	var courier_serial := 0
	var enc_elite_serial := 0

	for tick in SIM_STEPS:
		var t_s := float(tick) * SIM_DT
		var tick_pressure_before := float(state_ref["pressure_damage"])
		var speed := 14.0
		match arch:
			&"staller":
				speed = rng.randf_range(2.8, 4.4)
				heading = sin(t_s * 0.4) * 0.35
				ball_pos = Vector3(cos(t_s * 0.35) * 3.0, 0.2, sin(t_s * 0.35) * 3.0)
			&"flow_runner":
				speed = rng.randf_range(14.8, 17.6)
				heading += rng.randf_range(0.20, 0.36)
				var y_flow := 7.6 if (director.active_hazard_id == &"rising_slag_tide" and not director.is_slag_floor_clear()) else 0.2
				ball_pos = Vector3(cos(heading) * 16.0, y_flow, sin(heading) * 16.0)
			&"greedy_hoarder":
				speed = rng.randf_range(12.2, 14.5)
				heading += rng.randf_range(0.14, 0.26)
				var y_greed := 7.6 if (director.active_hazard_id == &"rising_slag_tide" and not director.is_slag_floor_clear() and rng.randf() > 0.35) else 0.2
				ball_pos = Vector3(cos(heading) * 12.0, y_greed, sin(heading) * 12.0)
			&"synergy_builder":
				speed = rng.randf_range(15.2, 18.6)
				heading += rng.randf_range(0.22, 0.38)
				var y_syn := 7.6 if (director.active_hazard_id == &"rising_slag_tide" and not director.is_slag_floor_clear()) else 0.2
				ball_pos = Vector3(cos(heading) * 14.5, y_syn, sin(heading) * 14.5)

		var ball_vel := Vector3(cos(heading) * speed, 0.0, sin(heading) * speed)
		state_ref["ball_pos"] = ball_pos
		state_ref["speed"] = speed

		var kept_ids: Array[String] = []
		for eid in live_enemy_ids:
			var e_chk := eco.enemy(eid)
			if e_chk != null and not e_chk.is_dead():
				kept_ids.append(eid)
		live_enemy_ids = kept_ids
		var live_elite_count := 0
		for inst in director.active_elites:
			if not inst.is_defeated():
				live_elite_count += 1
		for inst in encounter_elites:
			if not inst.is_defeated():
				live_elite_count += 1
		var alive_enemies := live_enemy_ids.size() + live_elite_count

		var dir_res := director.advance(SIM_DT, ball_pos, ball_vel, alive_enemies, 14.0, ball_pos.y < 1.5)
		stall_peak = maxf(stall_peak, director.stall_meter)
		for sp in dir_res["due_spawns"]:
			if live_enemy_ids.size() < director.alive_cap:
				var sp_pos: Vector3 = sp.get("at", ball_pos + Vector3(14.0, 0.0, 0.0))
				add_live_enemy.call(_map_fleet_kind_to_eco_role(StringName(sp.get("kind", &"chaser"))), sp_pos)
		for new_el in dir_res["new_elites"]:
			new_el.origin = _clamp_arena(new_el.origin)
			state_ref["elites_spawned"] = int(state_ref["elites_spawned"]) + 1

		var w_map := encounters.evaluate_random_weights({
			"biome_id": &"smelter_pit",
			"elapsed_s": t_s,
			"hazard_tier": director.hazard_tier,
			"unrefined_scrap": int(state_ref["scrap_carried"]),
			"courier_bounty": int(state_ref["courier_bounty"]),
		})
		greed_peak = maxf(greed_peak, float(w_map.get(&"greed_ambush_swarm", 0.0)))
		var enc_res := encounters.advance(SIM_DT, {
			"ball_pos": ball_pos,
			"ball_vel": ball_vel,
			"cruise_mps": 14.0,
			"warden_awake": false,
			"biome_id": &"smelter_pit",
			"elapsed_s": t_s,
			"hazard_tier": director.hazard_tier,
			"unrefined_scrap": int(state_ref["scrap_carried"]),
			"courier_bounty": int(state_ref["courier_bounty"]),
		})
		for esp in enc_res["spawns"]:
			var ekind := StringName(esp.get("kind", &"chaser"))
			var epos: Vector3 = _clamp_arena(esp.get("at", ball_pos + Vector3(10.0, 0.0, 0.0)))
			if ekind == &"refurbished_elite":
				enc_elite_serial += 1
				var v_id := StringName(esp.get("variant_id", &"magnetic_tow_winch"))
				var enc_inst := RefurbishedElites.spawn_instance(v_id, "enc_el_%d" % enc_elite_serial, epos, 1.0, elite_pool)
				if enc_inst != null:
					encounter_elites.append(enc_inst)
					state_ref["elites_spawned"] = int(state_ref["elites_spawned"]) + 1
			elif live_enemy_ids.size() < director.alive_cap + 6:
				add_live_enemy.call(_map_fleet_kind_to_eco_role(ekind), epos)

		var elite_facts: Array = []
		elite_facts.append_array(dir_res["facts"])
		for inst in director.active_elites:
			if not inst.is_defeated():
				var to_b := Vector3(ball_pos.x - inst.origin.x, 0.0, ball_pos.z - inst.origin.z)
				if to_b.length() > 5.0:
					inst.origin = _clamp_arena(inst.origin + to_b.normalized() * 6.0 * SIM_DT)
		for inst in encounter_elites:
			if not inst.is_defeated():
				var to_b2 := Vector3(ball_pos.x - inst.origin.x, 0.0, ball_pos.z - inst.origin.z)
				if to_b2.length() > 5.0:
					inst.origin = _clamp_arena(inst.origin + to_b2.normalized() * 6.5 * SIM_DT)
				var etick: Dictionary = inst.step(SIM_DT, ball_pos, ball_vel, 14.0)
				for ptag in etick["env_tags"]:
					field.apply_tag(ptag)
				elite_facts.append_array(etick["facts"])

		for ef in elite_facts:
			var fkind := String(ef.get("kind", ""))
			if fkind == "elite_telegraph":
				elite_tells[String(ef.get("instance_id", ""))] = float(ef.get("radius_m", 7.0))
			elif fkind == "elite_execute":
				var iid := String(ef.get("instance_id", ""))
				var hit_r := float(elite_tells.get(iid, 7.5))
				var at_pos: Vector3 = ef.get("at", Vector3.ZERO)
				if Vector2(ball_pos.x - at_pos.x, ball_pos.z - at_pos.z).length() <= hit_r and ball_pos.y < 3.0:
					state_ref["pressure_damage"] = float(state_ref["pressure_damage"]) + 18.0

		if director.active_hazard_id == &"rising_slag_tide" and not director.is_slag_floor_clear() and ball_pos.y < 1.5:
			state_ref["pressure_damage"] = float(state_ref["pressure_damage"]) + DynamicSetpieces.SLAG_STALL_DAMAGE_PER_S * SIM_DT

		var real_targets := _collect_real_targets(eco, live_enemy_ids, director.active_elites, encounter_elites, ball_pos)
		var combat_origin: Vector3 = real_targets[0]["pos"] if not real_targets.is_empty() else (ball_pos + Vector3(cos(heading), 0.0, sin(heading)) * 3.0)

		if arch == &"staller":
			if tick % 8 == 0:
				rig.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {
					"origin": combat_origin, "targets": real_targets, "ball_speed_mps": speed,
				})
			if tick % 10 == 0:
				rig.dispatch(PartResource.TRIG_ON_DASH, {
					"start": ball_pos, "end": combat_origin, "ball_speed_mps": speed,
				})
				rig.dispatch(PartResource.TRIG_ON_SLAM, {
					"origin": ball_pos, "ball_speed_mps": speed,
				})
			if tick % 12 == 0:
				rig.dispatch(PartResource.TRIG_ON_HARPOON_SNAP, {
					"origin": combat_origin, "anchor_pos": combat_origin, "clean_snap": false, "ball_speed_mps": speed,
				})
			if tick % 18 == 0:
				prop_respawn_serial += 1
				var st_prop := "stprop_%d" % prop_respawn_serial
				eco.spawn_prop(st_prop, Ecology.PROP_SLAG_DRUM, combat_origin)
				var rupt_st: Dictionary = eco.rupture_prop(st_prop, "staller")
				grant_scrap.call(int(rupt_st.get("scrap", 0)) + int(rupt_st.get("cogs", 0)) * 2)
				rig.dispatch(PartResource.TRIG_ON_PROP_RUPTURE, {
					"origin": combat_origin, "targets": real_targets, "ball_speed_mps": speed,
				})
				rig.dispatch(PartResource.TRIG_ON_SCRAP_PICKUP, {
					"origin": ball_pos, "amount": 1, "ball_speed_mps": speed,
				})
		elif arch == &"flow_runner":
			if tick % 8 == 0:
				rig.dispatch(PartResource.TRIG_ON_DASH, {
					"start": ball_pos, "end": combat_origin, "ball_speed_mps": speed,
				})
			if tick % 8 == 0:
				rig.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {
					"origin": combat_origin, "targets": real_targets, "ball_speed_mps": speed,
				})
			if tick % 14 == 0:
				rig.dispatch(PartResource.TRIG_ON_HARPOON_SNAP, {
					"origin": combat_origin, "anchor_pos": combat_origin, "clean_snap": true, "ball_speed_mps": speed,
				})
			if tick % 16 == 0:
				rig.dispatch(PartResource.TRIG_ON_SLAM, {
					"origin": combat_origin, "ball_speed_mps": speed,
				})
			if tick % 18 == 0:
				prop_respawn_serial += 1
				var fprop := "fprop_%d" % prop_respawn_serial
				eco.spawn_prop(fprop, Ecology.PROP_COOLANT_TANK, combat_origin)
				var rupt_f: Dictionary = eco.rupture_prop(fprop, "flow_runner")
				grant_scrap.call(int(rupt_f.get("scrap", 0)) + int(rupt_f.get("cogs", 0)) * 2)
				rig.dispatch(PartResource.TRIG_ON_PROP_RUPTURE, {
					"origin": combat_origin, "targets": real_targets, "ball_speed_mps": speed,
				})
				rig.dispatch(PartResource.TRIG_ON_SCRAP_PICKUP, {
					"origin": ball_pos, "amount": 2, "ball_speed_mps": speed,
				})
			if rig.heat_band() == JuryRig.BAND_REDLINE:
				rig.attempt_redline_vent(combat_origin, speed, &"slam")
		elif arch == &"greedy_hoarder":
			if tick % 8 == 0:
				rig.dispatch(PartResource.TRIG_ON_DASH, {
					"start": ball_pos, "end": combat_origin, "ball_speed_mps": speed,
				})
				rig.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {
					"origin": combat_origin, "targets": real_targets, "ball_speed_mps": speed,
				})
			if tick % 10 == 0:
				prop_respawn_serial += 1
				var pid_prop := "gprop_%d" % prop_respawn_serial
				var pkind: StringName = Ecology.PROP_SCRAP_PILE if (prop_respawn_serial % 2 == 0) else Ecology.PROP_COOLANT_TANK
				eco.spawn_prop(pid_prop, pkind, combat_origin)
				var rupt_g: Dictionary = eco.rupture_prop(pid_prop, "greed_hoarder")
				grant_scrap.call(int(rupt_g.get("scrap", 0)) + int(rupt_g.get("cogs", 0)) * 2)
				rig.dispatch(PartResource.TRIG_ON_PROP_RUPTURE, {
					"origin": combat_origin, "targets": real_targets, "ball_speed_mps": speed,
				})
				rig.dispatch(PartResource.TRIG_ON_SCRAP_PICKUP, {
					"origin": ball_pos, "amount": 2, "ball_speed_mps": speed,
				})
				eco.broadcast_aggro_ping(combat_origin, 24.0, ball_pos, "requisition_leech")
			if tick % 24 == 0:
				courier_serial += 1
				var cid := "haul_g_%d" % courier_serial
				eco.spawn_courier(cid, Ecology.COURIER_HAULER_DRONE, combat_origin, combat_origin + Vector3(35.0, 0.0, 0.0))
				var ckill := eco.strike_courier(cid, 120.0, ball_pos, true)
				var real_bounty := int(ckill.get("spilled_scrap", 0)) \
					+ int(ckill.get("spilled_cogs", 0)) * 2 \
					+ int(ckill.get("spilled_cores", 0)) * 25
				state_ref["courier_bounty"] = int(state_ref["courier_bounty"]) + real_bounty
				grant_scrap.call(real_bounty)
			if rig.heat_band() == JuryRig.BAND_REDLINE:
				rig.attempt_redline_vent(combat_origin, speed, &"dash")
		elif arch == &"synergy_builder":
			var phase := tick % 10
			if phase == 0:
				rig.dispatch(PartResource.TRIG_ON_DASH, {
					"start": ball_pos, "end": combat_origin, "ball_speed_mps": speed,
				})
			elif phase == 2:
				rig.dispatch(PartResource.TRIG_ON_SLAM, {
					"origin": combat_origin, "ball_speed_mps": speed,
				})
			elif phase == 4:
				rig.dispatch(PartResource.TRIG_ON_SCRAP_PICKUP, {
					"origin": combat_origin, "amount": 2, "ball_speed_mps": speed,
				})
			elif phase == 6:
				rig.dispatch(PartResource.TRIG_ON_WEAPON_FIRE, {
					"origin": combat_origin, "targets": real_targets, "ball_speed_mps": speed,
				})
			elif phase == 8:
				rig.dispatch(PartResource.TRIG_ON_HARPOON_SNAP, {
					"origin": combat_origin, "anchor_pos": combat_origin, "clean_snap": true, "ball_speed_mps": speed,
				})
				prop_respawn_serial += 1
				var spid := "sprop_%d" % prop_respawn_serial
				var skind: StringName = Ecology.PROP_COOLANT_TANK if (prop_respawn_serial % 2 == 0) else Ecology.PROP_SLAG_DRUM
				eco.spawn_prop(spid, skind, combat_origin)
				var rupt_s: Dictionary = eco.rupture_prop(spid, "synergy_builder")
				grant_scrap.call(int(rupt_s.get("scrap", 0)) + int(rupt_s.get("cogs", 0)) * 2)
				rig.dispatch(PartResource.TRIG_ON_PROP_RUPTURE, {
					"origin": combat_origin, "targets": real_targets, "ball_speed_mps": speed,
				})
			if rig.heat_band() == JuryRig.BAND_REDLINE:
				rig.attempt_redline_vent(combat_origin, speed, &"slam")

		var rig_tick := rig.step(SIM_DT, speed, ball_pos)
		eco.step(SIM_DT, ball_pos, ball_vel)

		for eid in live_enemy_ids:
			var e := eco.enemy(eid)
			if e == null or e.is_dead():
				sniper_aim_pos.erase(eid)
				continue
			if e.state == Ecology.ST_DISRUPTED or e.state == Ecology.ST_ALERT_TELEGRAPH:
				continue
			var flat_d := Vector2(e.pos.x - ball_pos.x, e.pos.z - ball_pos.z).length()
			match e.role:
				Ecology.ROLE_SWARMER:
					if e.state == Ecology.ST_WINDUP and flat_d <= 3.8 and ball_pos.y < 3.0:
						state_ref["pressure_damage"] = float(state_ref["pressure_damage"]) + 6.5
				Ecology.ROLE_SHIELDED_BULWARK:
					if flat_d <= 3.6 and ball_pos.y < 3.0:
						state_ref["pressure_damage"] = float(state_ref["pressure_damage"]) + 9.0
				Ecology.ROLE_ARC_SNIPER:
					if e.state == Ecology.ST_WINDUP and not sniper_aim_pos.has(eid):
						sniper_aim_pos[eid] = ball_pos
					elif e.state == Ecology.ST_STRIKE:
						var aimed: Vector3 = sniper_aim_pos.get(eid, ball_pos)
						sniper_aim_pos.erase(eid)
						if e.aim_deflected_rad < 0.2 and Vector2(ball_pos.x - aimed.x, ball_pos.z - aimed.z).length() <= 5.0:
							state_ref["pressure_damage"] = float(state_ref["pressure_damage"]) + 10.0

		var tick_dmg := float(rig_tick.get("cook_damage", 0.0)) + (float(state_ref["pressure_damage"]) - tick_pressure_before)
		hull_hp -= tick_dmg
		if is_nan(rig.heat) or is_inf(rig.heat) or is_nan(float(state_ref["pressure_damage"])) or is_nan(director.credit_pool):
			deadlocks += 1
		if hull_hp <= 0.0:
			survived = false
			survived_s = t_s + SIM_DT
			break

	director.env_tag_emitted.disconnect(dir_bridge)
	encounters.env_tag_emitted.disconnect(enc_bridge)
	field.reaction_triggered.disconnect(rx_cb)
	rig.part_fired.disconnect(part_cb)
	rig.synergy_emerged.disconnect(syn_cb)

	var total_reactions := int(field.stats()["reactions"])
	var total_dmg := float(state_ref["damage_dealt"])
	var scrap_val := float(state_ref["scrap_banked"])
	var pressure_val := float(state_ref["pressure_damage"])
	var cooked_val := rig.hull_cooked_total
	var remaining_hp := maxf(0.0, hull_hp)
	var score := total_dmg + float(int(state_ref["enemies_killed"])) * 40.0 + scrap_val * 2.0 + remaining_hp * 5.0 - pressure_val - cooked_val
	if is_nan(score) or is_inf(score):
		deadlocks += 1

	eco.dispose()
	rig.clear()
	field.clear()

	return {
		"score": score,
		"damage_dealt": total_dmg,
		"enemies_killed": int(state_ref["enemies_killed"]),
		"reactions": total_reactions,
		"synergies": int(state_ref["synergies"]),
		"hull_cooked": cooked_val,
		"stall_peak": stall_peak,
		"greed_peak": greed_peak,
		"scrap_yield": scrap_val,
		"pressure_damage": pressure_val,
		"elites_spawned": int(state_ref["elites_spawned"]),
		"plates_broken": int(state_ref["plates_broken"]),
		"survived": survived,
		"survived_s": survived_s,
		"part_fires": part_fires,
		"part_direct_dmg": part_direct_dmg,
		"deadlocks": deadlocks,
		"max_cascade_depth": int(state_ref["max_cascade_depth"]),
	}


func _collect_real_targets(
		eco: RefCounted,
		enemy_ids: Array[String],
		dir_elites: Array,
		enc_elites: Array,
		ball_pos: Vector3) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for eid in enemy_ids:
		var e: Ecology.EcologyEnemy = eco.enemy(eid)
		if e != null and not e.is_dead():
			entries.append({
				"id": "enemy:" + eid,
				"pos": e.pos,
				"d": Vector2(e.pos.x - ball_pos.x, e.pos.z - ball_pos.z).length(),
			})
	for inst in dir_elites:
		if not inst.is_defeated():
			entries.append({
				"id": "elite:" + String(inst.instance_id),
				"pos": inst.origin,
				"d": Vector2(inst.origin.x - ball_pos.x, inst.origin.z - ball_pos.z).length(),
			})
	for inst in enc_elites:
		if not inst.is_defeated():
			entries.append({
				"id": "elite:" + String(inst.instance_id),
				"pos": inst.origin,
				"d": Vector2(inst.origin.x - ball_pos.x, inst.origin.z - ball_pos.z).length(),
			})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["d"]) < float(b["d"])
	)
	var out: Array[Dictionary] = []
	for i in mini(4, entries.size()):
		out.append({"id": entries[i]["id"], "pos": entries[i]["pos"]})
	return out


func _percentiles(values: Array[float]) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n == 0:
		return {"p10": 0.0, "p50": 0.0, "p90": 0.0}
	return {
		"p10": float(sorted[clampi(int(floor(float(n - 1) * 0.10)), 0, n - 1)]),
		"p50": float(sorted[clampi(int(floor(float(n - 1) * 0.50)), 0, n - 1)]),
		"p90": float(sorted[clampi(int(floor(float(n - 1) * 0.90)), 0, n - 1)]),
	}



func _sync_nav_map(nav_map: RID, prev_iter: int, probe_point: Vector3) -> void:
	for _i in 30:
		await process_frame
		await physics_frame
		NavigationServer3D.map_force_update(nav_map)
		if NavigationServer3D.map_get_iteration_id(nav_map) > prev_iter \
				and NavigationServer3D.map_get_regions(nav_map).size() >= 1 \
				and NavigationServer3D.map_get_links(nav_map).size() >= 3:
			var closest := NavigationServer3D.map_get_closest_point(nav_map, probe_point)
			if closest.distance_to(probe_point) < 2.0:
				return


func _run_navigation_server_3d_proof() -> void:
	var packed := load(CHUNK_PATH) as PackedScene
	t.check("nav_chunk_loaded", packed != null, CHUNK_PATH)
	if packed == null:
		return
	var chunk := packed.instantiate() as Node3D
	var nav_root_map := root.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(nav_root_map)
	var prev_iter_0 := NavigationServer3D.map_get_iteration_id(nav_root_map)
	root.add_child(chunk)
	var nav_map: RID = chunk.get_world_3d().navigation_map
	await _sync_nav_map(nav_map, prev_iter_0, Vector3(0.0, 0.2, 0.0))

	var regions: Array[RID] = NavigationServer3D.map_get_regions(nav_map)
	var links: Array[RID] = NavigationServer3D.map_get_links(nav_map)
	t.check("nav3d_map_has_region_and_links", regions.size() >= 1 and links.size() >= 3,
		"regions=%d links=%d" % [regions.size(), links.size()])

	var p_t0_t1_start := Vector3(0.0, 0.2, 0.0)
	var p_t0_t1_end := Vector3(-22.0, 7.6, 0.0)
	var path_t0_t1: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, p_t0_t1_start, p_t0_t1_end, true)
	t.check("nav3d_tier0_to_tier1_west_path_valid",
		path_t0_t1.size() >= 2
		and path_t0_t1[0].distance_to(p_t0_t1_start) < 2.0
		and path_t0_t1[path_t0_t1.size() - 1].distance_to(p_t0_t1_end) < 2.0
		and (path_t0_t1[path_t0_t1.size() - 1].y - path_t0_t1[0].y) >= 6.5,
		"pts=%d start=%s end=%s" % [path_t0_t1.size(), str(path_t0_t1[0] if path_t0_t1.size() > 0 else Vector3.ZERO), str(path_t0_t1[path_t0_t1.size() - 1] if path_t0_t1.size() > 0 else Vector3.ZERO)])

	var p_t0_t2_start := Vector3(4.0, 0.2, 4.0)
	var p_t0_t2_end := Vector3(12.0, 16.1, 18.0)
	var path_t0_t2: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, p_t0_t2_start, p_t0_t2_end, true)
	var saw_mid_tier := false
	for pt in path_t0_t2:
		if pt.y >= 6.5 and pt.y <= 9.0:
			saw_mid_tier = true
	t.check("nav3d_tier0_to_tier2_gantry_multi_tier_climb",
		path_t0_t2.size() >= 4
		and path_t0_t2[0].distance_to(p_t0_t2_start) < 2.0
		and path_t0_t2[path_t0_t2.size() - 1].distance_to(p_t0_t2_end) < 2.0
		and saw_mid_tier
		and (path_t0_t2[path_t0_t2.size() - 1].y - path_t0_t2[0].y) >= 15.0,
		"pts=%d saw_mid=%s start=%s end=%s" % [
			path_t0_t2.size(), str(saw_mid_tier),
			str(path_t0_t2[0] if path_t0_t2.size() > 0 else Vector3.ZERO),
			str(path_t0_t2[path_t0_t2.size() - 1] if path_t0_t2.size() > 0 else Vector3.ZERO),
		])

	var p_t2_t0_end := Vector3(14.0, 0.2, -10.0)
	var path_t2_t0: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, p_t0_t2_end, p_t2_t0_end, true)
	t.check("nav3d_tier2_to_tier0_descent_valid",
		path_t2_t0.size() >= 4
		and path_t2_t0[0].distance_to(p_t0_t2_end) < 2.0
		and path_t2_t0[path_t2_t0.size() - 1].distance_to(p_t2_t0_end) < 2.0
		and (path_t2_t0[0].y - path_t2_t0[path_t2_t0.size() - 1].y) >= 15.0,
		"pts=%d start=%s end=%s" % [
			path_t2_t0.size(),
			str(path_t2_t0[0] if path_t2_t0.size() > 0 else Vector3.ZERO),
			str(path_t2_t0[path_t2_t0.size() - 1] if path_t2_t0.size() > 0 else Vector3.ZERO),
		])

	var p_t1_west := Vector3(-22.0, 7.6, 0.0)
	var p_t1_north := Vector3(0.0, 7.6, -22.0)
	var path_t1_loop: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, p_t1_west, p_t1_north, true)
	var stays_on_tier1 := true
	for pt in path_t1_loop:
		if pt.y < 6.0:
			stays_on_tier1 = false
	print("  [nav3d] Tier0->Tier1 pts=%d | Tier0->Tier2 pts=%d | Tier2->Tier0 pts=%d | Catwalk West->North pts=%d stays_t1=%s" % [
		path_t0_t1.size(), path_t0_t2.size(), path_t2_t0.size(), path_t1_loop.size(), str(stays_on_tier1)
	])
	t.check("nav3d_tier1_catwalk_west_to_north_connected",
		path_t1_loop.size() >= 2
		and path_t1_loop[0].distance_to(p_t1_west) < 2.0
		and path_t1_loop[path_t1_loop.size() - 1].distance_to(p_t1_north) < 2.0
		and stays_on_tier1,
		"pts=%d stays_t1=%s end=%s" % [
			path_t1_loop.size(), str(stays_on_tier1),
			str(path_t1_loop[path_t1_loop.size() - 1] if path_t1_loop.size() > 0 else Vector3.ZERO),
		])

	root.remove_child(chunk)
	chunk.free()
	await process_frame
	await physics_frame
	NavigationServer3D.map_force_update(nav_map)

	var chunk_moved := packed.instantiate() as Node3D
	chunk_moved.position = Vector3(60.0, 12.0, -40.0)
	chunk_moved.rotation = Vector3(0.0, PI * 0.5, 0.0)
	var prev_iter_1 := NavigationServer3D.map_get_iteration_id(nav_map)
	root.add_child(chunk_moved)
	var nav_map_moved: RID = chunk_moved.get_world_3d().navigation_map
	var xf := chunk_moved.global_transform
	var w_start := xf * p_t0_t2_start
	var w_end := xf * p_t0_t2_end
	await _sync_nav_map(nav_map_moved, prev_iter_1, w_start)
	var path_moved: PackedVector3Array = NavigationServer3D.map_get_path(nav_map_moved, w_start, w_end, true)
	t.check("nav3d_translated_rotated_chunk_tier0_to_tier2",
		path_moved.size() >= 4
		and path_moved[0].distance_to(w_start) < 1.0
		and path_moved[path_moved.size() - 1].distance_to(w_end) < 1.0,
		"pts=%d start_err=%.2f end_err=%.2f" % [
			path_moved.size(),
			path_moved[0].distance_to(w_start) if path_moved.size() > 0 else 999.0,
			path_moved[path_moved.size() - 1].distance_to(w_end) if path_moved.size() > 0 else 999.0,
		])

	root.remove_child(chunk_moved)
	chunk_moved.free()
	await physics_frame



func _run_physics_server_3d_proof() -> void:
	var packed := load(CHUNK_PATH) as PackedScene
	var chunk := packed.instantiate() as Node3D
	root.add_child(chunk)
	await physics_frame

	var space: PhysicsDirectSpaceState3D = chunk.get_world_3d().direct_space_state
	t.check("phys3d_space_state_valid", space != null, "PhysicsDirectSpaceState3D ready")

	var q_floor := PhysicsRayQueryParameters3D.create(Vector3(0.0, 5.0, 0.0), Vector3(0.0, -5.0, 0.0), 1)
	var hit_floor := space.intersect_ray(q_floor)
	t.check("phys3d_ray_hits_basin_floor_y0",
		not hit_floor.is_empty() and absf(float((hit_floor["position"] as Vector3).y) - 0.0) < 0.05,
		"hit=%s" % str(hit_floor.get("position", "none")))

	var q_catwalk := PhysicsRayQueryParameters3D.create(Vector3(-22.0, 12.0, 0.0), Vector3(-22.0, 4.0, 0.0), 1)
	var hit_catwalk := space.intersect_ray(q_catwalk)
	t.check("phys3d_ray_hits_tier1_catwalk_y7p5",
		not hit_catwalk.is_empty() and absf(float((hit_catwalk["position"] as Vector3).y) - 7.5) < 0.05,
		"hit=%s" % str(hit_catwalk.get("position", "none")))

	var q_gantry := PhysicsRayQueryParameters3D.create(Vector3(0.0, 20.0, 18.0), Vector3(0.0, 12.0, 18.0), 1)
	var hit_gantry := space.intersect_ray(q_gantry)
	t.check("phys3d_ray_hits_tier2_gantry_y16p0",
		not hit_gantry.is_empty() and absf(float((hit_gantry["position"] as Vector3).y) - 16.0) < 0.05,
		"hit=%s" % str(hit_gantry.get("position", "none")))

	var heft_sphere := SphereShape3D.new()
	heft_sphere.radius = 2.05
	var clearance_hits := 0
	for sock_id in ["floor_loop_south", "rail_mid_west", "rail_mid_north", "rail_upper_gantry"]:
		var sock := ChunkSockets.find_socket(chunk, sock_id)
		var pos: Vector3 = sock["position"]
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = heft_sphere
		sq.collision_mask = 1
		sq.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0.0, 2.25, 0.0))
		var overlaps := space.intersect_shape(sq, 4)
		clearance_hits += overlaps.size()
	t.eq("phys3d_heft_class_v_zero_traversal_overlaps", clearance_hits, 0)

	var setpieces := DynamicSetpieces.new()
	root.add_child(setpieces)
	await physics_frame
	var info := setpieces.setup_from_chunk(chunk, {"seed": 777})
	await physics_frame

	var low_friction := PhysicsMaterial.new()
	low_friction.friction = 0.05
	low_friction.bounce = 0.1

	var ball := RigidBody3D.new()
	ball.name = "LiveGyrosphere"
	ball.mass = 1.0
	ball.linear_damp = 0.0
	ball.physics_material_override = low_friction
	ball.collision_layer = 2
	ball.collision_mask = 1
	var bshape := CollisionShape3D.new()
	var bsphere := SphereShape3D.new()
	bsphere.radius = 1.0
	bshape.shape = bsphere
	ball.add_child(bshape)
	ball.position = Vector3(14.0, 1.02, 0.0)
	ball.linear_velocity = Vector3(0.0, 0.0, 15.0)
	root.add_child(ball)

	var scrap_crate := RigidBody3D.new()
	scrap_crate.name = "LiveLooseScrap"
	scrap_crate.mass = 1.0
	scrap_crate.linear_damp = 0.0
	scrap_crate.physics_material_override = low_friction
	scrap_crate.collision_layer = 4
	scrap_crate.collision_mask = 1
	var cshape := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(1.2, 1.2, 1.2)
	cshape.shape = cbox
	scrap_crate.add_child(cshape)
	scrap_crate.position = Vector3(14.0, 0.65, -8.0)
	root.add_child(scrap_crate)
	await physics_frame

	var director := AdversityDirector.new(42, &"smelter_pit", 1.0)
	director.start_hazard(&"magnetic_storm", Vector3.ZERO, 0.0)
	for _s in 75:
		director.advance(0.1, ball.global_position, ball.linear_velocity, 2, 14.0, true)
		if director.hazard_phase == AdversityDirector.HazardPhase.PEAK:
			break
	t.eq("phys3d_magnetic_storm_at_peak", director.hazard_phase, AdversityDirector.HazardPhase.PEAK)

	var ball_speed_before := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
	var scrap_dist_before := Vector2(scrap_crate.global_position.x, scrap_crate.global_position.z).length()
	var dt_phys := 1.0 / float(Engine.physics_ticks_per_second)
	for _p in 24:
		var f_ball := director.compute_magnetic_force(ball.global_position, ball.linear_velocity, &"player_ball", 14.0)
		var f_scrap := director.compute_magnetic_force(scrap_crate.global_position, scrap_crate.linear_velocity, &"loose_scrap", 14.0)
		PhysicsServer3D.body_apply_central_impulse(ball.get_rid(), f_ball * dt_phys)
		PhysicsServer3D.body_apply_central_impulse(scrap_crate.get_rid(), f_scrap * dt_phys)
		await physics_frame

	var ball_speed_after := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
	var scrap_dist_after := Vector2(scrap_crate.global_position.x, scrap_crate.global_position.z).length()
	print("  [phys3d] Ball speed %.2f -> %.2f m/s (y=%.2f) | Scrap dist to pole %.2f -> %.2f m" % [
		ball_speed_before, ball_speed_after, ball.global_position.y, scrap_dist_before, scrap_dist_after
	])
	t.check("phys3d_ball_stays_grounded_on_basin_floor",
		ball.global_position.y >= 0.85 and ball.global_position.y <= 1.35,
		"ball_y=%.3f" % ball.global_position.y)
	t.check("phys3d_magnetic_slingshot_accelerates_fast_ball_via_physics_server",
		ball_speed_after > ball_speed_before + 1.0,
		"before=%.2f after=%.2f" % [ball_speed_before, ball_speed_after])
	t.check("phys3d_magnetic_storm_pulls_loose_scrap_rigidbody_inward",
		scrap_dist_after < scrap_dist_before - 0.5,
		"before=%.2f after=%.2f" % [scrap_dist_before, scrap_dist_after])

	t.check("phys3d_trigger_furnace", setpieces.trigger_setpiece(String(info["furnace_id"]), "player"), "furnace")
	var berm_created := false
	for _step in 260:
		setpieces.step(1.0 / 30.0, Vector3(26.0, 0.5, 26.0), Vector3(15.0, 0.0, 0.0), 2)
		if int(setpieces.snapshot()["furnace"]["intact_berms"]) >= 3:
			berm_created = true
			break
	await physics_frame
	t.check("phys3d_slag_berms_spawned", berm_created, "berms=%d" % int(setpieces.snapshot()["furnace"]["intact_berms"]))

	var berm_hit_pos := Vector3.ZERO
	var berm_rays_hit := 0
	for k in 24:
		var ang := float(k) * (TAU / 24.0)
		var ray_from := Vector3(0.0, 1.2, 0.0)
		var ray_to := Vector3(cos(ang) * 10.5, 1.2, sin(ang) * 10.5)
		var rq := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
		var rhit := space.intersect_ray(rq)
		if not rhit.is_empty():
			berm_rays_hit += 1
			if berm_hit_pos == Vector3.ZERO:
				berm_hit_pos = rhit["position"]
	t.check("phys3d_cooled_slag_berms_block_layer1_rays", berm_rays_hit >= 3,
		"berm_rays_hit=%d first=%s" % [berm_rays_hit, str(berm_hit_pos)])

	setpieces.on_blast(Vector3.ZERO, 12.0, 2)
	await physics_frame
	var berm_rays_after := 0
	for k in 24:
		var ang := float(k) * (TAU / 24.0)
		var rq2 := PhysicsRayQueryParameters3D.create(Vector3(0.0, 1.2, 0.0), Vector3(cos(ang) * 10.5, 1.2, sin(ang) * 10.5), 1)
		if not space.intersect_ray(rq2).is_empty():
			berm_rays_after += 1
	t.eq("phys3d_shattered_slag_berms_clear_layer1_colliders", berm_rays_after, 0)

	setpieces.teardown()
	root.remove_child(ball)
	root.remove_child(scrap_crate)
	root.remove_child(setpieces)
	root.remove_child(chunk)
	ball.free()
	scrap_crate.free()
	setpieces.free()
	chunk.free()
	await physics_frame
