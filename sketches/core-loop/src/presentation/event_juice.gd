extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")

const JUICE := {
	"enemy_struck": {"stop_ms": 10.0, "stop_per_damage": 0.4, "stop_min_ms": 12.0, "stop_cap_ms": 40.0,
		"crit": {"stop_mult": 1.4, "shake": 0.22, "color": Palette.BRASS, "sound": "crit_ping",
			"fx": {"crit_core": 24, "crit_halo": 24}},
		"heavy": {"stop_add_ms": 10.0, "kick": 0.45, "dust": 12}, "fx": {"spark_core": 16, "spark_halo": 16}},
	"enemy_rebounded": {"kick": 0.55, "shake": 0.35, "dust": 14},
	"enemy_killed": {"debris": 10, "fx": {"kill_shards": 16}, "chain_ms": 1500, "chain_cap": 7, "multi_ms": 90, "multi_stop_ms": 30.0, "pips": 8},
	"scrap_collected": {"chain_ms": 1000, "chain_cap": 9, "pulse": 0.05, "pulse_cap": 0.16},
	"armor_reclaim": {"chain_ms": 900, "chain_cap": 7},
	"part_gained": {"fountain": 18, "element": {"frost": Palette.ANCIENT, "arc": Palette.ARC, "kinetic": Palette.SAND}},
	"core_gained": {"fountain": 24},
	"shot_fired": {"weapons": {"rapid_laser": {"kick": 0.05, "recoil": 0.04}, "arc_caster": {"kick": 0.12, "recoil": 0.08},
			"pylon_turret": {"kick": 0.08, "recoil": 0.0}, "sticky_charge": {"kick": 0.16, "recoil": 0.12},
			"claw_sweep": {"kick": 0.14, "recoil": 0.10},
			"gather_plate": {"kick": 0.06, "recoil": 0.04}, "link_clips": {"kick": 0.07, "recoil": 0.05},
			"balance_due": {"kick": 0.10, "recoil": 0.08}, "cannon_lane": {"kick": 0.2, "recoil": 0.14}},
		"throw": {"sound": "dash_whoosh", "pitch": 1.5, "db": -4.0}, "stick": {"sound": "grapple_clink", "pitch": 0.7}},
	"sticky_detonated": {"punch_fov": 3.0, "punch_per_enemy": 1.5, "punch_cap": 10.0, "debris": 12, "dust": 14, "shake": 0.35,
		"near_m": 6.0, "near_kick": 0.6},
	"rocket_jumped": {"kick": 0.8, "punch_fov": 8.0, "squash": 0.35},
	"near_miss": {"punch_fov": -5.0, "grace_ms": EventKinds.NEAR_MISS_GRACE_MS},
	"player_hit": {"edge_s": 0.4, "edge_alpha": 0.65, "squash": 0.18, "color": Palette.HAZARD},
	"scrap_lost": {"pulse": -0.22},
	"beacon_unsealed": {"punch_fov": 9.0},
	"quick_break": {"fountain": 28, "rise": 7.0},
	"rolling": {"fx": {"roll_dust": 90}, "min_speed": 9.0},
	"slammed": {"fx": {"slam_ring": 48, "slam_dust": 24}},
	"harpoon_bit": {"fx": {"latch_ring": 24, "latch_halo": 24, "latch_pulse": 12}},
	"wall_crumbled": {"fx": {"crack_debris": 28, "slam_dust": 14}},
	"prop_kicked": {"fly": {"sound": "land_thud", "metal": "clank", "pitch": [1.5, 1.15], "db": -9.0, "dust": 8},
		"shove": {"sound": "land_thud", "metal": "clank", "pitch": [0.95, 0.75], "db": -7.0, "dust": 10},
		"bend": {"sound": "", "metal": "", "pitch": [1.0, 1.0], "db": 0.0, "dust": 4}},
	"bumped": {"min_speed": 9.0, "full_speed": 30.0, "squash": 0.34, "kick": 0.45, "shake": 0.3, "shake_from": 0.5,
		"db": [-10.0, 1.0], "pitch": [1.2, 0.8], "fx": {"slam_dust": 18, "crack_debris": 12}},
	"enemy_walled": {"min_speed": 8.0, "full_speed": 30.0, "shake": 0.14, "near_m": 14.0,
		"db": [-12.0, -2.0], "pitch": [1.05, 0.75], "fx": {"slam_dust": 12, "crack_debris": 8}},
	"sticky_stuck": {"fx": {"spark_core": 8, "spark_halo": 8}},
	"breach_opened": {"fx": {"dig_debris": 10, "dig_dust": 12}, "low": {"dig_debris": 4, "dig_dust": 5}},
	"cache_spent": {"fx": {"cache_ember": 24, "cache_wisp": 6}},
	"net_caught": {"fx": {"net_dust": 14}},
	"thermal_ride": {"motes": [9, 27], "streaks": [6, 18]},
}

const STOP_GAP_MS := 90
const STOP_WINDOW_MS := 300
const STOP_WINDOW_BUDGET_MS := 60.0
const STOP_BUDGET_MS := 100.0
const STOP_PER_EXTRA_HIT_MS := 2.0
const SPINE_CAP_MS := 60.0

const WEIGHT := {
	"none": {"stop_ms": 0.0, "shake": 0.0, "kick": 0.0, "punch_fov": 0.0, "fx_scale": 0.8, "body": "", "body_st": 0.0},
	"hit": {"stop_ms": "hit", "shake": 0.1, "kick": 0.1, "punch_fov": 0.0, "fx_scale": 1.0, "body": "", "body_st": 0.0},
	"heavy": {"stop_ms": "heavy", "shake": 0.3, "kick": 0.45, "punch_fov": -4.0, "fx_scale": 1.4, "body": "womp", "body_st": 0.0},
	"massive": {"stop_ms": 55.0, "shake": 0.4, "kick": 0.6, "punch_fov": -6.0, "fx_scale": 1.9, "body": "chunk_low", "body_st": -12.0},
	"climax": {"stop_ms": 60.0, "shake": 0.5, "kick": 0.6, "punch_fov": 9.0, "fx_scale": 2.5, "body": "chunk_low", "body_st": -17.0},
}

const WEIGHTED := {
	"enemy_struck": {"rule": "strike", "allegiance": "player", "visual": ""},
	"enemy_killed": {"rule": "death_parts", "allegiance": "player", "visual": ""},
	"gauge_released": {"rule": "gauge", "allegiance": "player", "visual": ""},
	"player_hit": {"rule": "amount", "allegiance": "hostile", "visual": ""},
	"posture_changed": {"rule": "posture", "allegiance": "player", "visual": "spark_core"},
	"posture_break": {"class": "massive", "allegiance": "player", "visual": "spark_core"},
	"ultimate_landed": {"class": "massive", "allegiance": "player", "visual": ""},
	"boss_defeated": {"class": "climax", "allegiance": "player", "visual": ""},
	"boss_weak_point_hit": {"class": "heavy", "allegiance": "player", "visual": ""},
	"player_died": {"class": "massive", "allegiance": "hostile", "visual": ""},
	"slammed": {"class": "heavy", "allegiance": "player", "visual": ""},
	"sticky_detonated": {"class": "heavy", "allegiance": "player", "visual": ""},
	"enemy_rebounded": {"class": "heavy", "allegiance": "player", "visual": ""},
	"cloak_broken": {"class": "hit", "allegiance": "player", "visual": ""},
	"hold_broken": {"class": "hit", "allegiance": "player", "visual": ""},
	"swarm_scattered": {"class": "hit", "allegiance": "player", "visual": ""},
	"enemy_pinned": {"class": "hit", "allegiance": "player", "visual": ""},
	"enemy_ringed_out": {"class": "heavy", "allegiance": "player", "visual": ""},
	"arc_slammed": {"class": "none", "allegiance": "player", "visual": ""},
	"skid_smashed": {"class": "none", "allegiance": "player", "visual": ""},
	"demo_slammed": {"class": "none", "allegiance": "player", "visual": ""},
	"cloak_started": {"class": "none", "allegiance": "player", "visual": ""},
	"sprint_started": {"class": "none", "allegiance": "motion", "visual": ""},
	"cc_ignored": {"class": "none", "allegiance": "player", "visual": ""},
	"blink_used": {"class": "none", "allegiance": "motion", "visual": ""},
	"vault_kicked": {"class": "none", "allegiance": "motion", "visual": ""},
}

const WEIGHT_EXEMPT := {
	"line_skill_fired": "The line skill's bite; its landed strike is enemy_struck.",
	"active_fired": "The active's launch cue; its landed strikes are enemy_struck.",
	"active_heat": "A building heat tick under the active's sound row; it lands no hit, its cut is enemy_struck.",
	"achievement_earned": "Reward and economy ladders own the cue; rewards never stop time.",
	"activity_done": "World, interaction and activity rows own their contextual glyph and sound.",
	"ambush_ended": "World, interaction and activity rows own their contextual glyph and sound.",
	"bay_entered": "World, interaction and activity rows own their contextual glyph and sound.",
	"bay_left": "World, interaction and activity rows own their contextual glyph and sound.",
	"beacon_charge_changed": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"beacon_unsealed": "The beacon is a reward with no stop; the breaking strike is posture_break.",
	"bet_resolved": "World, interaction and activity rows own their contextual glyph and sound.",
	"boosted": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"boss_arena_entered": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"boss_attack_telegraphed": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"boss_phase_changed": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"boss_reeled": "Reward and economy ladders own the cue; rewards never stop time. Its strike is enemy_struck.",
	"cause_armed": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"cause_fired": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"cogs_collected": "Reward and economy ladders own the cue; rewards never stop time.",
	"core_gained": "Reward and economy ladders own the cue; rewards never stop time.",
	"dashed": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"dismounted": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"element_resolved": "World, interaction and activity rows own their contextual glyph and sound.",
	"enemy_spawned": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"event_announced": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"event_ended": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"event_progress": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"event_started": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"flow_changed": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"gauge_cancelled": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"gauge_charging": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"grapple_fired": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"grapple_released": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"harpoon_bit": "Latch feedback owns its dedicated stop and glyph; damage is weighted through enemy_struck.",
	"harpoon_smashed": "Harpoon contact owns its latch glyph; damage is weighted through enemy_struck.",
	"heft_class_changed": "Reward and economy ladders own the cue; rewards never stop time.",
	"heft_class_dropped": "Reward and economy ladders own the cue; rewards never stop time.",
	"hold_ended": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"hold_started": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"interact_armed": "World, interaction and activity rows own their contextual glyph and sound.",
	"interact_fired": "World, interaction and activity rows own their contextual glyph and sound.",
	"interaction_found": "World, interaction and activity rows own their contextual glyph and sound.",
	"jumped": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"landed": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"bumped": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"enemy_walled": "A thrown body stopped by a wall deals no damage; its thud, dust and stagger are juice.gd's and enemy.gd's.",
	"launched": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"line_skill_loaded": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"line_state_changed": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"milestone_won": "Reward and economy ladders own the cue; rewards never stop time.",
	"mind_adapted": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"mounted": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"near_miss": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"pack_arrived": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"part_gained": "Reward and economy ladders own the cue; rewards never stop time.",
	"panel_gained": "Reward and economy ladders own the cue; rewards never stop time.",
	"pressure_changed": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"rescue_completed": "Reward and economy ladders own the cue; rewards never stop time.",
	"reward_chosen": "Reward and economy ladders own the cue; rewards never stop time.",
	"reward_offered": "Reward and economy ladders own the cue; rewards never stop time.",
	"rocket_jumped": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"run_ended": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"run_started": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"scrap_collected": "Reward and economy ladders own the cue; rewards never stop time.",
	"scrap_lost": "Reward and economy ladders own the cue; rewards never stop time.",
	"shield_vaulted": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"carved": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"shot_fired": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"special_used": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"stage_cleared": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"stage_content_cleared": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"stage_entered": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"strike_deflected": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"synergy_discovered": "Reward and economy ladders own the cue; rewards never stop time.",
	"tenacity_gained": "Reward and economy ladders own the cue; rewards never stop time.",
	"threat_rose": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"tree_offered": "Reward and economy ladders own the cue; rewards never stop time.",
	"tree_picked": "Reward and economy ladders own the cue; rewards never stop time.",
	"ultimate_cancelled": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"special_broken": "Achievement facts own no impact; the earned toast is the cue.",
	"radio_take_found": "Achievement facts own no impact; the earned toast is the cue.",
	"relay_stake_paid": "Achievement facts own no impact; the earned toast is the cue.",
	"maker_set_completed": "Achievement facts own no impact; the earned toast is the cue.",
	"overflow_cashed": "Achievement facts own no impact; the earned toast is the cue.",
	"trade_taken": "World, interaction and activity rows own their contextual glyph and sound.",
	"ultimate_peak": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"ultimate_ready": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"ultimate_started": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"vent_charging": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"vent_erupted": "Hostile floor eruption owns its danger geometry and reactor cue; it never shakes, kicks or stops the screen.",
	"verb_failed": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"warden_engaged": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"warden_sighted": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"weak_point_opened": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"world_entered": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"world_fact": "World, interaction and activity rows own their contextual glyph and sound.",
}


static func juice(kind: String) -> Dictionary:
	return JUICE.get(kind, {})


static func stop_ms_for(damage: float, crit := false, heavy := false) -> float:
	var row := juice("enemy_struck")
	var ms := clampf(float(row["stop_ms"]) + float(row["stop_per_damage"]) * maxf(damage, 0.0), float(row["stop_min_ms"]), float(row["stop_cap_ms"]))
	if crit:
		ms *= float(row["crit"]["stop_mult"])
	if heavy:
		ms += float(row["heavy"]["stop_add_ms"])
	return minf(ms, SPINE_CAP_MS)


static func weigh(fact: String, args: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = WEIGHTED.get(fact, {})
	var weight := String(entry.get("class", "none"))
	var strength := 1.0
	var damage := maxf(float(args.get("damage", args.get("force", 0.0))), 0.0)
	match String(entry.get("rule", "")):
		"strike":
			weight = String(EventKinds.impact(String(args.get("kind", "")))["stop"])
			strength = damage / 30.0
		"death_parts":
			var kind := String(args.get("kind", ""))
			var parts := int(WindupRows.ROWS.get(kind, {}).get("death", {}).get("parts", 4))
			weight = "climax" if kind == "warden" else ("massive" if parts >= 8 else ("heavy" if parts >= 5 else "hit"))
		"gauge":
			strength = float(args.get("fraction", 0.0))
			weight = "heavy" if strength >= 1.0 else "hit"
		"amount":
			var amount := float(args.get("amount", 0.0))
			weight = "massive" if amount >= 20.0 else ("heavy" if amount >= 10.0 else "hit")
			strength = amount / 25.0
		"posture":
			var lost := maxi(int(args.get("chunks_lost", 0)), 0)
			weight = "massive" if bool(args.get("staggered", false)) else ("heavy" if lost > 0 else "none")
			if lost > 0:
				strength = float(lost) / BossPosture.CHUNKS
	strength = clampf(float(args.get("strength", strength)), 0.0, 1.0)
	var profile: Dictionary = WEIGHT[weight]
	var allegiance := String(entry.get("allegiance", "motion" if String(EventKinds.ROWS.get(fact, {}).get("group", "")) == "movement" or fact == "launched" else "reward"))
	var stop := 0.0
	if profile.stop_ms is String:
		stop = stop_ms_for(damage, bool(args.get("crit", false)), profile.stop_ms == "heavy")
	else:
		stop = float(profile.stop_ms)
	var rows_script = load("res://src/presentation/rows.gd")
	return {
		"fact": fact, "weight": weight, "allegiance": allegiance, "strength": strength,
		"stop_ms": stop if allegiance == "player" else 0.0,
		"shake": 0.0 if allegiance == "hostile" else float(profile.shake) * strength,
		"kick": 0.0 if allegiance == "hostile" else float(profile.kick) * strength,
		"punch_fov": float(profile.punch_fov) * strength, "fx_scale": float(profile.fx_scale),
		"body": String(profile.body), "body_ratio": pow(2.0, float(profile.body_st) / 12.0), "body_db": 0.0,
		"visual": String(entry.get("visual", "")), "sound": rows_script.sound(fact),
	}
