extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")


const HIDING_NATURAL_KINDS := ["collapse", "impact"]
const GROUPS := ["movement", "combat", "economy", "flow", "event"]
const SHAPES := ["ring", "diamond", "square", "chevron", "arrow", "burst", "bar", "star", "cross", "wave", "core", "lane", "none"]
const FIELDS := ["group", "color", "shape", "sound", "hud", "objective", "priority"]
const TOAST_PRIORITY := 2

const ROWS := {
	"run_started": {"group": "flow", "color": Palette.SAND, "shape": "star", "sound": "stinger_run", "hud": "Run started", "objective": "", "priority": 3},
	"flow_changed": {"group": "flow", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"world_entered": {"group": "flow", "color": Palette.SAND, "shape": "none", "sound": "stinger_world", "hud": "World {world}", "objective": "", "priority": 3},
	"achievement_earned": {"group": "flow", "color": Palette.AMBER, "shape": "star", "sound": "achievement_chime", "hud": "", "objective": "", "priority": 1},
	"rescue_completed": {"group": "flow", "color": Palette.AMBER, "shape": "none", "sound": "rescue_fanfare", "hud": "", "objective": "", "priority": 2},
	"stage_entered": {"group": "flow", "color": Palette.SAND, "shape": "chevron", "sound": "stinger_stage", "hud": "Stage {stage}", "objective": "Break the Warden at the beacon ({distance} m). Punch {punch} / plating {plating}. {hint}", "priority": 3},
	"stage_cleared": {"group": "flow", "color": Palette.AMBER, "shape": "star", "sound": "stinger_clear", "hud": "Stage {stage} clear", "objective": "", "priority": 3},
	"run_ended": {"group": "flow", "color": Palette.AMBER, "shape": "star", "sound": "stinger_run_end", "hud": "Run complete", "objective": "", "priority": 3},
	"beacon_charge_changed": {"group": "flow", "color": Palette.ARC, "shape": "ring", "sound": "beacon_hum", "hud": "", "objective": "Warden {percent}% broken. Punch {punch} / plating {plating}. {hint}", "priority": 1},
	"warden_sighted": {"group": "flow", "color": Palette.HAZARD, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"warden_engaged": {"group": "flow", "color": Palette.HAZARD, "shape": "cross", "sound": "warden_theme_in", "hud": "The Warden wakes", "objective": "", "priority": 2},
	"stage_content_cleared": {"group": "flow", "color": Palette.SAND, "shape": "none", "sound": "stage_fade", "hud": "", "objective": "", "priority": 0},
	"beacon_unsealed": {"group": "flow", "color": Palette.AMBER, "shape": "star", "sound": "stinger_unseal", "hud": "", "objective": "Charge the beacon", "priority": 3},
	"quick_break": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "found_chime", "hud": "", "objective": "", "priority": 1},
	"scrap_collected": {"group": "economy", "color": Palette.AMBER, "shape": "square", "sound": "scrap_tick", "hud": "", "objective": "", "priority": 1},
	"cogs_collected": {"group": "economy", "color": Palette.AMBER, "shape": "square", "sound": "cog_tick", "hud": "", "objective": "", "priority": 1},
	"part_gained": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "part_get", "hud": "+ {part}", "objective": "", "priority": 2},
	"panel_gained": {"group": "economy", "color": Palette.SAND, "shape": "square", "sound": "panel_ratchet", "hud": "", "objective": "", "priority": 1},
	"player_hit": {"group": "combat", "color": Palette.RUST, "shape": "burst", "sound": "hurt", "hud": "", "objective": "", "priority": 2},
	"escape_window": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"player_died": {"group": "combat", "color": Palette.RUST, "shape": "cross", "sound": "death", "hud": "Scrapped", "objective": "", "priority": 3},
	"enemy_killed": {"group": "combat", "color": Palette.COPPER, "shape": "burst", "sound": "kill_pop", "hud": "", "objective": "", "priority": 1},
	"milestone_won": {"group": "event", "color": Palette.AMBER, "shape": "star", "sound": "stinger_milestone", "hud": "{event} won", "objective": "", "priority": 3},
	"heft_class_changed": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "class_up", "hud": "Heft {class}", "objective": "", "priority": 3},
	"heft_class_dropped": {"group": "economy", "color": Palette.RUST, "shape": "chevron", "sound": "class_down", "hud": "Heft {class}", "objective": "", "priority": 2},
	"scrap_lost": {"group": "economy", "color": Palette.RUST, "shape": "cross", "sound": "scrap_rip", "hud": "Chase your scrap", "objective": "", "priority": 2},
	"core_gained": {"group": "economy", "color": Palette.AMBER, "shape": "core", "sound": "core_socket", "hud": "Gates may offer rares", "objective": "", "priority": 3},
	"synergy_discovered": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "synergy_fanfare", "hud": "Synergy {name}", "objective": "", "priority": 3},
	"interaction_found": {"group": "event", "color": Palette.SANDSTONE, "shape": "diamond", "sound": "found_chime", "sound_next": "found_twinkle", "hud": "", "objective": "", "priority": 1},
	"jumped": {"group": "movement", "color": Palette.SAND, "shape": "chevron", "sound": "hop", "hud": "", "objective": "", "priority": 1},
	"boosted": {"group": "movement", "color": Palette.AMBER, "shape": "arrow", "sound": "boost_whoosh", "hud": "", "objective": "", "priority": 1},
	"dashed": {"group": "movement", "color": Palette.AMBER, "shape": "arrow", "sound": "dash_whoosh", "hud": "", "objective": "", "priority": 1},
	"landed": {"group": "movement", "color": Palette.SANDSTONE, "shape": "ring", "sound": "land_thud", "hud": "", "objective": "", "priority": 1},
	"bumped": {"group": "movement", "color": Palette.SANDSTONE, "shape": "burst", "sound": "land_thud", "hud": "", "objective": "", "priority": 1},
	"slammed": {"group": "movement", "color": Palette.AMBER, "shape": "ring", "sound": "core_slam", "hud": "", "objective": "", "priority": 1},
	"carved": {"group": "movement", "color": Palette.AMBER, "shape": "arrow", "sound": "carve_release", "hud": "", "objective": "", "priority": 1},
	"grapple_fired": {"group": "movement", "color": ClassDef.SABLE_COLOR, "shape": "diamond", "sound": "grapple_clink", "hud": "", "objective": "", "priority": 1},
	"grapple_released": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "grapple_release", "hud": "", "objective": "", "priority": 1},
	"mounted": {"group": "movement", "color": Palette.AMBER, "shape": "square", "sound": "pylon_plant", "hud": "", "objective": "", "priority": 1},
	"dismounted": {"group": "movement", "color": Palette.AMBER, "shape": "arrow", "sound": "pylon_eject", "hud": "", "objective": "", "priority": 1},
	"enemy_spawned": {"group": "combat", "color": Palette.RUST, "shape": "chevron", "sound": "enemy_arrive", "hud": "", "objective": "", "priority": 1},
	"enemy_struck": {"group": "combat", "color": Palette.COPPER, "shape": "burst", "sound": "hit_thwack", "hud": "", "objective": "", "priority": 1},
	"shot_fired": {"group": "combat", "color": Palette.ARC, "shape": "bar", "sound": "weapon_zap", "hud": "", "objective": "", "priority": 1},
	"special_used": {"group": "combat", "color": Palette.ARC, "shape": "star", "sound": "special_fire", "hud": "", "objective": "", "priority": 2},
	"strike_deflected": {"group": "combat", "color": Palette.SAND, "shape": "square", "sound": "clank", "hud": "", "objective": "", "priority": 1},
	"reward_offered": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "gates_open", "hud": "", "objective": "Roll through a gate", "priority": 3},
	"reward_chosen": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "gate_through", "hud": "Took {part}", "objective": "Hold your line", "priority": 3},
	"element_resolved": {"group": "event", "color": Palette.ARC, "shape": "wave", "sound": "element_resolved", "hud": "", "objective": "", "priority": 1},
	"event_announced": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "klaxon", "hud": "{event} incoming", "objective": "", "priority": 3},
	"event_started": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "event_start", "hud": "{event}", "objective": "", "priority": 2},
	"event_ended": {"group": "event", "color": Palette.VERDIGRIS, "shape": "wave", "sound": "event_end", "hud": "{event} lost", "objective": "", "priority": 2},
	"event_progress": {"group": "event", "color": Palette.VERDIGRIS, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"launched": {"group": "flow", "color": Palette.AMBER, "shape": "arrow", "sound": "launch_roar", "hud": "", "objective": "Hold your line", "priority": 3},
	"pressure_changed": {"group": "event", "color": Palette.RUST, "shape": "wave", "sound": "music_pressure", "hud": "", "objective": "", "priority": 0},
	"boss_arena_entered": {"group": "event", "color": Palette.BRASS, "shape": "star", "sound": "boss_arena_in", "hud": "Admiral Brindle", "objective": "Break Brindle's Requisition. Punch {punch} / hull plating {plating}.", "priority": 3},
	"boss_phase_changed": {"group": "event", "color": Palette.BRASS, "shape": "chevron", "sound": "boss_phase", "hud": "{name}", "objective": "", "priority": 3},
	"boss_attack_telegraphed": {"group": "combat", "color": Palette.BRASS, "shape": "wave", "sound": "boss_telegraph", "hud": "", "objective": "", "priority": 2},
	"fight_phase_changed": {"group": "event", "color": Palette.BRASS, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"attack_cued": {"group": "combat", "color": Palette.BRASS, "shape": "wave", "sound": "ratchet_cue", "hud": "", "objective": "", "priority": 2},
	"boss_weak_point_hit": {"group": "combat", "color": Palette.BRASS, "shape": "burst", "sound": "boss_weak_hit", "hud": "", "objective": "", "priority": 1},
	"boss_reeled": {"group": "economy", "color": Palette.AMBER, "shape": "square", "sound": "scrap_tick", "hud": "", "objective": "", "priority": 1},
	"boss_defeated": {"group": "flow", "color": Palette.BRASS, "shape": "star", "sound": "stinger_boss_defeated", "hud": "", "objective": "", "priority": 3},
	"threat_rose": {"group": "event", "color": Palette.RUST, "shape": "chevron", "sound": "threat_up", "hud": "Threat rising", "objective": "", "priority": 2},
	"enemy_rebounded": {"group": "combat", "color": Palette.SAND, "shape": "chevron", "sound": "shell_spring", "sound_next": "rebound_spring_snap", "hud": "", "objective": "", "priority": 1},
	"enemy_pinned": {"group": "combat", "color": Palette.COPPER, "shape": "burst", "sound": "hit_thwack", "sound_next": "pin_double_thwack", "hud": "", "objective": "", "priority": 1},
	"enemy_walled": {"group": "combat", "color": Palette.SANDSTONE, "shape": "burst", "sound": "land_thud", "hud": "", "objective": "", "priority": 1},
	"enemy_ringed_out": {"group": "combat", "color": Palette.COPPER, "shape": "arrow", "sound": "near_whoosh", "sound_next": "ring_out_fall", "hud": "", "objective": "", "priority": 1},
	"vault_kicked": {"group": "movement", "color": ClassDef.SABLE_COLOR, "shape": "ring", "sound": "pylon_eject", "sound_next": "sable_octave_leap", "hud": "", "objective": "", "priority": 1},
	"gauge_charging": {"group": "combat", "color": Palette.SAND, "shape": "ring", "sound": "beacon_hum", "sound_next": "motif_accumulate", "hud": "", "objective": "", "priority": 1},
	"gauge_released": {"group": "combat", "color": Palette.SAND, "shape": "star", "sound": "found_chime", "sound_next": "motif_release", "hud": "", "objective": "", "priority": 1},
	"gauge_cancelled": {"group": "combat", "color": Palette.SAND, "shape": "cross", "sound": "ui_tick", "sound_next": "gauge_dry_click", "hud": "", "objective": "", "priority": 1},
	"sprint_started": {"group": "movement", "color": ClassDef.RIVET_COLOR, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "rivet_hat_roll", "hud": "", "objective": "", "priority": 1},
	"cc_ignored": {"group": "combat", "color": ClassDef.RIVET_COLOR, "shape": "chevron", "sound": "tenacity_choke", "sound_next": "rivet_cymbal_choke", "hud": "", "objective": "", "priority": 1},
	"cloak_started": {"group": "combat", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "stage_fade", "sound_next": "kest_muffled_thump", "hud": "", "objective": "", "priority": 1},
	"cloak_broken": {"group": "combat", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "shatter", "sound_next": "kest_snare_crack", "hud": "", "objective": "", "priority": 1},
	"sticky_detonated": {"group": "combat", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "slam_boom", "sound_next": "kest_kick_thump", "hud": "", "objective": "", "priority": 1},
	"rocket_jumped": {"group": "movement", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "boost_whoosh", "sound_next": "kest_blast_lift", "hud": "", "objective": "", "priority": 1},
	"blink_used": {"group": "movement", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "dash_whoosh", "sound_next": "kest_blink_thump", "hud": "", "objective": "", "priority": 1},
	"arc_slammed": {"group": "movement", "color": ClassDef.SABLE_COLOR, "shape": "ring", "sound": "zap_hum", "sound_next": "sable_root_fifth", "hud": "", "objective": "", "priority": 1},
	"skid_smashed": {"group": "movement", "color": ClassDef.RIVET_COLOR, "shape": "chevron", "sound": "rivet_skid_plate", "sound_next": "rivet_snare_flam", "hud": "", "objective": "", "priority": 1},
	"demo_slammed": {"group": "movement", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "kest_demo_knock", "sound_next": "kest_falling_triad", "hud": "", "objective": "", "priority": 1},
	"hold_started": {"group": "combat", "color": Palette.HAZARD, "shape": "bar", "sound": "hold_pit", "sound_next": "hold_by_kind", "hud": "", "objective": "", "priority": 1},
	"hold_broken": {"group": "combat", "color": Palette.SAND, "shape": "burst", "sound": "shatter", "sound_next": "class_break", "hud": "", "objective": "", "priority": 1},
	"hold_ended": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"tenacity_gained": {"group": "combat", "color": Palette.SAND, "shape": "square", "sound": "tenacity_choke", "hud": "", "objective": "", "priority": 1},
	"pack_arrived": {"group": "event", "color": Palette.HAZARD, "shape": "diamond", "sound": "fleet_motif", "sound_next": "faction_arrival", "icon": "fac_fleet", "hud": "", "objective": "", "priority": 2},
	"shield_vaulted": {"group": "movement", "color": Palette.SAND, "shape": "chevron", "sound": "pylon_eject", "sound_next": "rebound_spring_snap", "hud": "", "objective": "", "priority": 1},
	"vent_charging": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "reactor_tick", "hud": "", "objective": "", "priority": 1},
	"vent_erupted": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "reactor_erupt", "hud": "", "objective": "", "priority": 2},
	"swarm_scattered": {"group": "combat", "color": Palette.SAND, "shape": "burst", "sound": "swarm_scatter", "hud": "", "objective": "", "priority": 1},
	"mind_adapted": {"group": "combat", "color": Palette.HAZARD, "shape": "ring", "sound": "mind_sable", "sound_next": "mind_quote", "hud": "", "objective": "", "priority": 2},
	"weak_point_opened": {"group": "combat", "color": Palette.ANCIENT, "shape": "core", "sound": "beacon_hum", "hud": "", "objective": "", "priority": 1},
	"tree_offered": {"group": "economy", "color": Palette.SAND, "shape": "diamond", "sound": "found_chime", "sound_next": "motif_fork", "hud": "", "objective": "", "priority": 1},
	"tree_picked": {"group": "economy", "color": Palette.SAND, "shape": "diamond", "sound": "part_get", "sound_next": "motif_pick", "hud": "", "objective": "", "priority": 1},
	"bay_entered": {"group": "flow", "color": Palette.SANDSTONE, "shape": "square", "sound": "pylon_plant", "sound_next": "bay_lounge_in", "hud": "Moss's workshop", "objective": "", "priority": 2},
	"bay_left": {"group": "flow", "color": Palette.SANDSTONE, "shape": "arrow", "sound": "pylon_eject", "sound_next": "bay_slingshot_out", "hud": "", "objective": "", "priority": 1},
	"world_fact": {"group": "event", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"near_miss": {"group": "combat", "color": Palette.AMBER, "shape": "chevron", "sound": "near_whoosh", "hud": "", "objective": "", "priority": 1},
	"interact_armed": {"group": "event", "color": Palette.AMBER, "shape": "ring", "sound": "ui_tick", "hud": "", "objective": "", "priority": 1},
	"interact_fired": {"group": "event", "color": Palette.AMBER, "shape": "burst", "sound": "found_chime", "hud": "", "objective": "", "priority": 1},
	"ambush_ended": {"group": "combat", "color": Palette.HAZARD, "shape": "cross", "sound": "event_end", "hud": "", "objective": "", "priority": 2},
	"bet_resolved": {"group": "economy", "color": Palette.COPPER, "shape": "star", "sound": "clank", "hud": "", "objective": "", "priority": 2},
	"activity_done": {"group": "event", "color": Palette.AMBER, "shape": "diamond", "sound": "found_chime", "hud": "", "objective": "", "priority": 1},
	"line_state_changed": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"verb_failed": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "sound_next": "verb_fail", "hud": "", "objective": "", "priority": 0},
	"prompt_shown": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"cause_armed": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"cause_fired": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"drop_landed": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "sound_next": "drop_thud", "hud": "", "objective": "", "priority": 1},
	"missed_drop": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "sound_next": "drop_whiff", "hud": "", "objective": "", "priority": 1},
	"evolution_fired": {"group": "economy", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "sound_next": "evolution_fired", "hud": "", "objective": "", "priority": 1},
	"posture_changed": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "drop_landing", "hud": "", "objective": "", "priority": 0},
	"slot_selected": {"group": "combat", "color": Palette.SAND, "shape": "square", "sound": "ui_tick", "hud": "", "objective": "", "priority": 1},
	"slot_cast": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"line_skill_loaded": {"group": "combat", "color": Palette.SAND, "shape": "ring", "sound": "lock_tick", "sound_next": "line_load", "hud": "", "objective": "", "priority": 1},
	"line_skill_fired": {"group": "combat", "color": Palette.SAND, "shape": "burst", "sound": "line_bite", "sound_next": "motif_line", "hud": "", "objective": "", "priority": 1},
	"line_skill_expired": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "dry_tick", "hud": "", "objective": "", "priority": 1},
	"active_fired": {"group": "combat", "color": Palette.AMBER, "shape": "burst", "sound": "active_scrap_rocket", "hud": "", "objective": "", "priority": 1},
	"active_heat": {"group": "combat", "color": Palette.AMBER, "shape": "burst", "sound": "active_cutting_torch_heat", "hud": "", "objective": "", "priority": 1},
	"ultimate_ready": {"group": "combat", "color": Palette.ARC, "shape": "ring", "sound": "found_chime", "sound_next": "ultimate_ready", "hud": "", "objective": "", "priority": 1},
	"ultimate_started": {"group": "combat", "color": Palette.ARC, "shape": "lane", "sound": "launch_roar", "hud": "", "objective": "", "priority": 1},
	"ultimate_peak": {"group": "combat", "color": Palette.ARC, "shape": "star", "sound": "special_fire", "sound_next": "motif_stinger", "hud": "", "objective": "", "priority": 1},
	"ultimate_landed": {"group": "combat", "color": Palette.AMBER, "shape": "burst", "sound": "ultimate_land", "hud": "", "objective": "", "priority": 1},
	"ultimate_cancelled": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "dry_tick", "hud": "", "objective": "", "priority": 1},
	"special_broken": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"radio_take_found": {"group": "flow", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"relay_stake_paid": {"group": "event", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"maker_set_completed": {"group": "economy", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"overflow_cashed": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"trade_taken": {"group": "event", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
}

const GRAMMAR_SIGNALS := ["prompt_shown", "escape_window", "slot_selected", "slot_cast", "line_skill_expired",
	"special_broken", "radio_take_found", "relay_stake_paid", "maker_set_completed", "overflow_cashed", "trade_taken"]

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
	"near_miss": {"punch_fov": -5.0, "grace_ms": 250},
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
const IMPACT_FIELDS := ["knock", "lift", "stop", "shake", "react"]
const IMPACT := {
	"runner": {"knock": 3.0, "lift": 0.25, "stop": "none", "shake": 0.0, "react": "flinch"},
	"arc": {"knock": 5.0, "lift": 0.25, "stop": "none", "shake": 0.0, "react": "flinch"},
	"turret": {"knock": 6.0, "lift": 0.25, "stop": "none", "shake": 0.0, "react": "flinch"},
	"sticky": {"knock": 26.0, "lift": 0.4, "stop": "hit", "shake": 0.1, "react": "launch"},
	"line": {"knock": 28.0, "lift": 0.5, "stop": "hit", "shake": 0.1, "react": "launch"},
	"burst": {"knock": 24.0, "lift": 0.4, "stop": "hit", "shake": 0.1, "react": "launch"},
	"spill": {"knock": 12.0, "lift": 0.3, "stop": "hit", "shake": 0.1, "react": "stagger"},
	"overdrive": {"knock": 34.0, "lift": 0.5, "stop": "hit", "shake": 0.1, "react": "launch"},
	"proc": {"knock": 8.0, "lift": 0.3, "stop": "hit", "shake": 0.1, "react": "stagger"},
	"ram": {"knock": 24.0, "lift": 0.35, "stop": "heavy", "shake": 0.3, "react": "launch"},
	"slam": {"knock": 26.0, "lift": 0.5, "stop": "heavy", "shake": 0.3, "react": "launch"},
	"stomp": {"knock": 7.0, "lift": 0.0, "stop": "heavy", "shake": 0.3, "react": "stagger"},
	"claw": {"knock": 8.0, "lift": 0.3, "stop": "hit", "shake": 0.1, "react": "stagger"},
	"clamp": {"knock": 10.0, "lift": 0.1, "stop": "hit", "shake": 0.1, "react": "stagger"},
	"ledger": {"knock": 6.0, "lift": 0.2, "stop": "hit", "shake": 0.05, "react": "stagger"},
	"flail": {"knock": 14.0, "lift": 0.3, "stop": "hit", "shake": 0.15, "react": "launch"},
	"cannon": {"knock": 9.0, "lift": 0.25, "stop": "hit", "shake": 0.15, "react": "stagger"},
	"rocket": {"knock": 14.0, "lift": 0.3, "stop": "hit", "shake": 0.08, "react": "stagger"},
	"lance": {"knock": 8.0, "lift": 0.3, "stop": "hit", "shake": 0.1, "react": "stagger"},
	"debris": {"knock": 0.0, "lift": 0.0, "stop": "none", "shake": 0.0, "react": "flinch"},
}
const REACTIONS := {
	"flinch": {"angle": 10.0, "rise": 0.03, "hold": 0.0, "recover": 0.09, "overshoot": 0.0, "tumble": 0.0, "limit": 0.15},
	"stagger": {"angle": 28.0, "rise": 0.05, "hold": 0.07, "recover": 0.24, "overshoot": 0.18, "tumble": 0.0, "limit": 0.45},
	"launch": {"angle": 65.0, "rise": 0.05, "hold": 0.0, "recover": 0.18, "overshoot": 0.0, "tumble": 220.0, "limit": 0.9},
}
const IMPACT_STOPS := ["none", "hit", "heavy"]
const IMPACT_REACTS := ["flinch", "stagger", "launch"]
const IMPACT_FALLBACK := {"knock": 0.0, "lift": 0.0, "stop": "hit", "shake": 0.1, "react": "flinch"}

const STOP_GAP_MS := 90
const STOP_WINDOW_MS := 300
const STOP_WINDOW_BUDGET_MS := 60.0
const STOP_BUDGET_MS := 100.0
const STOP_PER_EXTRA_HIT_MS := 2.0

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


static func weigh(fact: String, args: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = WEIGHTED.get(fact, {})
	var weight := String(entry.get("class", "none"))
	var strength := 1.0
	var damage := maxf(float(args.get("damage", args.get("force", 0.0))), 0.0)
	match String(entry.get("rule", "")):
		"strike":
			weight = String(impact(String(args.get("kind", "")))["stop"])
			strength = damage / 30.0
		"death_parts":
			var kind := String(args.get("kind", ""))
			var windup = load("res://src/presentation/windup_rows.gd")
			var parts := int(windup.ROWS.get(kind, {}).get("death", {}).get("parts", 4))
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
				var posture = load("res://src/combat/boss_posture.gd")
				strength = float(lost) / posture.CHUNKS
	strength = clampf(float(args.get("strength", strength)), 0.0, 1.0)
	var profile: Dictionary = WEIGHT[weight]
	var allegiance := String(entry.get("allegiance", "motion" if String(ROWS.get(fact, {}).get("group", "")) == "movement" or fact == "launched" else "reward"))
	var stop := 0.0
	if profile.stop_ms is String:
		var juice_script = load("res://src/presentation/juice.gd")
		stop = juice_script.stop_ms_for(damage, bool(args.get("crit", false)), profile.stop_ms == "heavy")
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


static func juice(kind: String) -> Dictionary:
	return JUICE.get(kind, {})


static func impact(kind: String) -> Dictionary:
	return IMPACT.get(kind, IMPACT_FALLBACK)

const THREAT_ROWS := {
	"threat_instant": {"group": "combat", "color": Palette.HAZARD, "shape": "ring", "sound": "threat_tick", "hud": "", "objective": "", "priority": 2},
	"threat_wave": {"group": "combat", "color": Palette.HAZARD, "shape": "wave", "sound": "threat_whoosh", "hud": "", "objective": "", "priority": 2},
	"threat_projectile": {"group": "combat", "color": Palette.HAZARD, "shape": "cross", "sound": "threat_whistle", "hud": "", "objective": "", "priority": 2},
	"threat_lane": {"group": "combat", "color": Palette.HAZARD, "shape": "bar", "sound": "threat_hum", "hud": "", "objective": "", "priority": 2},
}

const NONE := "none"
const PLACEHOLDER := "tbd"
const ATTACK_GROUPS := ["enemy", "warden", "brindle", "pilot"]
const ATTACK_FIELDS := ["label", "threat", "glyph", "color", "pose", "warn", "release", "floor"]
const FLOOR_MODES := ["L", "H", "B", NONE]
const ATTACK_ROWS := {
	"E01": {"label": "Chaser lunge", "group": "enemy", "owner_kind": "roster", "owner": "chaser", "allegiance": "hostile", "threat": "threat_lane", "glyph": "bar", "color": Palette.HAZARD,
		"pose": "e01_brace_back", "warn": "atk_e01_warn", "release": "atk_e01_release", "floor": "B", "open": []},
	"E02": {"label": "Lobber shell", "group": "enemy", "owner_kind": "roster", "owner": "lobber", "allegiance": "hostile", "threat": "threat_projectile", "glyph": "cross", "color": Palette.HAZARD,
		"pose": "e02_tube_raise", "warn": "atk_e02_warn", "release": "atk_e02_release", "floor": "B", "open": []},
	"E03": {"label": "Drop hammer leap slam", "group": "enemy", "owner_kind": "roster", "owner": "miniboss", "allegiance": "hostile", "threat": "threat_instant", "glyph": "burst", "color": Palette.HAZARD,
		"pose": "e03_leap_spread", "warn": "atk_e03_warn", "release": "atk_e03_release", "floor": "B", "open": []},
	"E04": {"label": "Drop hammer charge", "group": "enemy", "owner_kind": "roster", "owner": "miniboss", "allegiance": "hostile", "threat": "threat_lane", "glyph": "bar", "color": Palette.HAZARD,
		"pose": "e04_charge_close", "warn": "atk_e04_warn", "release": "atk_e04_release", "floor": "B", "open": []},
	"E05": {"label": "Mag trapper pit", "group": "enemy", "owner_kind": "roster", "owner": "mag_trapper", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "e05_stack_hoist", "warn": "atk_e05_warn", "release": "atk_e05_release", "floor": "B", "open": []},
	"E06": {"label": "Hooker harpoon", "group": "enemy", "owner_kind": "roster", "owner": "hooker", "allegiance": "hostile", "threat": "threat_lane", "glyph": "bar", "color": Palette.HAZARD,
		"pose": "e06_harpoon_draw", "warn": "atk_e06_warn", "release": "atk_e06_release", "floor": "L", "open": []},
	"E07": {"label": "Netcaster air net", "group": "enemy", "owner_kind": "roster", "owner": "netcaster", "allegiance": "hostile", "threat": "threat_instant", "glyph": "star", "color": Palette.HAZARD,
		"pose": "e07_net_umbrella", "warn": "atk_e07_warn", "release": "atk_e07_release", "floor": "L", "open": []},
	"E08": {"label": "Bola throw", "group": "enemy", "owner_kind": "roster", "owner": "bola_thrower", "allegiance": "hostile", "threat": "threat_projectile", "glyph": "cross", "color": Palette.HAZARD,
		"pose": "e08_loop_raise", "warn": "atk_e08_warn", "release": "atk_e08_release", "floor": "B", "open": []},
	"E09": {"label": "Plated brute slam", "group": "enemy", "owner_kind": "roster", "owner": "plated_brute", "allegiance": "hostile", "threat": "threat_instant", "glyph": "burst", "color": Palette.HAZARD,
		"pose": "e09_pads_raise", "warn": "atk_e09_warn", "release": "atk_e09_release", "floor": "B", "open": []},
	"E10": {"label": "Deflector brace", "group": "enemy", "owner_kind": "roster", "owner": "deflector", "allegiance": "hostile", "threat": "threat_lane", "glyph": "bar", "color": Palette.HAZARD,
		"pose": "e10_dish_wall", "warn": "atk_e10_warn", "release": "atk_e10_release", "floor": "L", "open": []},
	"E11": {"label": "Winch drone pull", "group": "enemy", "owner_kind": "roster", "owner": "winch_drone", "allegiance": "hostile", "threat": "threat_lane", "glyph": "bar", "color": Palette.HAZARD,
		"pose": "e11_cable_guide", "warn": "atk_e11_warn", "release": "atk_e11_release", "floor": "L", "open": []},
	"E12": {"label": "Gyro jammer field", "group": "enemy", "owner_kind": "roster", "owner": "gyro_jammer", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "e12_hoops_planes", "warn": "atk_e12_warn", "release": "atk_e12_release", "floor": "B", "open": []},
	"E13": {"label": "Swatter swing", "group": "enemy", "owner_kind": "roster", "owner": "swatter", "allegiance": "hostile", "threat": "threat_instant", "glyph": "chevron", "color": Palette.HAZARD,
		"pose": "e13_paddle_side", "warn": "atk_e13_warn", "release": "atk_e13_release", "floor": "B", "open": []},
	"E14": {"label": "Ramp flipper", "group": "enemy", "owner_kind": "roster", "owner": "ramp_flipper", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "e14_lip_raise", "warn": "atk_e14_warn", "release": "atk_e14_release", "floor": "B", "open": []},
	"E15": {"label": "Catch trap", "group": "enemy", "owner_kind": "roster", "owner": "catch_trap", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "e15_cup_splay", "warn": "atk_e15_warn", "release": "atk_e15_release", "floor": "B", "open": []},
	"E16": {"label": "Reactor relic eruption", "group": "enemy", "owner_kind": "roster", "owner": "reactor_relic", "allegiance": "hostile", "threat": "threat_instant", "glyph": "burst", "color": Palette.HAZARD,
		"pose": "e16_vents_open", "warn": "atk_e16_warn", "release": "atk_e16_release", "floor": "B", "open": []},
	"E17": {"label": "Swarm formation dive", "group": "enemy", "owner_kind": "roster", "owner": "swarm_remnant", "allegiance": "hostile", "threat": "threat_lane", "glyph": "arrow", "color": Palette.HAZARD,
		"pose": "e17_rack_bow", "warn": "atk_e17_warn", "release": "atk_e17_release", "floor": "B", "open": []},
	"E18": {"label": "Mind hand strike", "group": "enemy", "owner_kind": "roster", "owner": "mind_hand", "allegiance": "hostile", "threat": "threat_lane", "glyph": "bar", "color": Palette.HAZARD,
		"pose": "e18_elbow_telescope", "warn": "atk_e18_warn", "release": "atk_e18_release", "floor": "L", "open": []},
	"E19": {"label": "Burrower floor burst", "group": "enemy", "owner_kind": "roster", "owner": "burrower", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "e19_mound_rise", "warn": "atk_e19_warn", "release": "atk_e19_release", "floor": "B", "open": []},
	"E20": {"label": "Drill crew breach", "group": "enemy", "owner_kind": "roster", "owner": "drill_crew", "allegiance": "hostile", "threat": "threat_instant", "glyph": "square", "color": Palette.HAZARD,
		"pose": "e20_bit_lower", "warn": "atk_e20_warn", "release": "atk_e20_release", "floor": "B", "open": []},
	"E21": {"label": "Lamp swarm lure bloom", "group": "enemy", "owner_kind": "roster", "owner": "lamp_swarm", "allegiance": "hostile", "threat": "threat_wave", "glyph": "wave", "color": Palette.HAZARD,
		"pose": "e21_lamps_open", "warn": "atk_e21_warn", "release": "atk_e21_release", "floor": "L", "open": []},
	"E22": {"label": "Line cutter throw", "group": "enemy", "owner_kind": "roster", "owner": "line_cutter", "allegiance": "hostile", "threat": "threat_projectile", "glyph": "cross", "color": Palette.HAZARD,
		"pose": "e22_disc_cock", "warn": "atk_e22_warn", "release": "atk_e22_release", "floor": "B", "open": []},
	"E23": {"label": "Anchor crew winch", "group": "enemy", "owner_kind": "roster", "owner": "anchor_crew", "allegiance": "hostile", "threat": "threat_lane", "glyph": "arrow", "color": Palette.HAZARD,
		"pose": "e23_hook_swing", "warn": "atk_e23_warn", "release": "atk_e23_release", "floor": "L", "open": []},
	"E24": {"label": "Kite drone dive", "group": "enemy", "owner_kind": "roster", "owner": "kite_drone", "allegiance": "hostile", "threat": "threat_instant", "glyph": "diamond", "color": Palette.HAZARD,
		"pose": "e24_wings_fold", "warn": "atk_e24_warn", "release": "atk_e24_release", "floor": "B", "open": []},
	"E25": {"label": "Splitter pod fuse blast", "group": "enemy", "owner_kind": "roster", "owner": "splitter_pod", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "e25_pod_glow", "warn": "atk_e25_warn", "release": "atk_e25_release", "floor": "B", "open": []},
	"E26": {"label": "Dispatcher tube drop", "group": "enemy", "owner_kind": "roster", "owner": "dispatcher", "allegiance": "hostile", "threat": "threat_projectile", "glyph": "cross", "color": Palette.HAZARD,
		"pose": "e26_tube_suck", "warn": "atk_e26_warn", "release": "atk_e26_release", "floor": "B", "open": []},
	"E27": {"label": "Jolt layer mat", "group": "enemy", "owner_kind": "roster", "owner": "jolt_layer", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "e27_coil_swell", "warn": "atk_e27_warn", "release": "atk_e27_release", "floor": "B", "open": []},
	"E30": {"label": "Pit jaw bite", "group": "enemy", "owner_kind": "roster", "owner": "pit_jaw", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "e30_jaw_part", "warn": "atk_e30_warn", "release": "atk_e30_release", "floor": "B", "open": []},
	"E31": {"label": "Prop crew roof drop", "group": "enemy", "owner_kind": "roster", "owner": "prop_crew", "allegiance": "hostile", "threat": "threat_instant", "glyph": "burst", "color": Palette.HAZARD,
		"pose": "e31_prop_kicked", "warn": "atk_e31_warn", "release": "atk_e31_release", "floor": "B", "open": []},
	"E32": {"label": "Ballast heavy brace slam", "group": "enemy", "owner_kind": "roster", "owner": "ballast_heavy", "allegiance": "hostile", "threat": "threat_instant", "glyph": "burst", "color": Palette.HAZARD,
		"pose": "e32_claws_brace", "warn": "atk_e32_warn", "release": "atk_e32_release", "floor": "B", "open": []},
	"E33": {"label": "Gap net charge", "group": "enemy", "owner_kind": "roster", "owner": "gap_net", "allegiance": "hostile", "threat": "threat_lane", "glyph": "star", "color": Palette.HAZARD,
		"pose": "e33_net_crackle", "warn": "atk_e33_warn", "release": "atk_e33_release", "floor": "L", "open": []},
	"E34": {"label": "Gate crane sweep", "group": "enemy", "owner_kind": "rogue", "owner": "rogue_crane", "allegiance": "hostile", "threat": "threat_lane", "glyph": "wave", "color": Palette.HAZARD,
		"pose": "e34_hook_swing_out", "warn": "atk_e34_warn", "release": "atk_e34_release", "floor": "B", "open": []},
	"E35": {"label": "Gate crane leaf drop", "group": "enemy", "owner_kind": "rogue", "owner": "rogue_crane", "allegiance": "hostile", "threat": "threat_projectile", "glyph": "burst", "color": Palette.HAZARD,
		"pose": "e35_leaf_hoist", "warn": "atk_e35_warn", "release": "atk_e35_release", "floor": "B", "open": []},
	"E36": {"label": "Haul skip haul", "group": "enemy", "owner_kind": "rogue", "owner": "rogue_skip", "allegiance": "hostile", "threat": "threat_lane", "glyph": "arrow", "color": Palette.HAZARD,
		"pose": "e36_skip_route_brace", "warn": "atk_e36_warn", "release": "atk_e36_release", "floor": "B", "open": []},
	"E37": {"label": "Haul skip dump", "group": "enemy", "owner_kind": "rogue", "owner": "rogue_skip", "allegiance": "hostile", "threat": "threat_projectile", "glyph": "cross", "color": Palette.HAZARD,
		"pose": "e37_bucket_tip", "warn": "atk_e37_warn", "release": "atk_e37_release", "floor": "B", "open": []},
	"E38": {"label": "Cable tender harpoon", "group": "enemy", "owner_kind": "rogue", "owner": "rogue_tender", "allegiance": "hostile", "threat": "threat_lane", "glyph": "bar", "color": Palette.HAZARD,
		"pose": "e38_harpoon_run_out", "warn": "atk_e38_warn", "release": "atk_e38_release", "floor": "B", "open": []},
	"E39": {"label": "Cable tender whip", "group": "enemy", "owner_kind": "rogue", "owner": "rogue_tender", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "e39_spool_wind", "warn": "atk_e39_warn", "release": "atk_e39_release", "floor": "B", "open": []},
	"E40": {"label": "Boom tender boom sweep", "group": "enemy", "owner_kind": "roster", "owner": "boom_tender", "allegiance": "hostile", "threat": "threat_lane", "glyph": "bar", "color": Palette.HAZARD,
		"pose": "e40_reel_ratchet", "warn": "atk_e40_warn", "release": "atk_e40_release", "floor": "L", "open": []},
	"W01": {"label": "Warden pulse", "group": "warden", "owner_kind": "faction", "owner": "reactor", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "w01_vents_lift", "warn": "atk_w01_warn", "release": "atk_w01_release", "floor": "B", "open": []},
	"W02": {"label": "Hive Warden pulse", "group": "warden", "owner_kind": "faction", "owner": "swarm", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "w02_cells_retract", "warn": "atk_w02_warn", "release": "atk_w02_release", "floor": "B", "open": []},
	"W03": {"label": "Hive guard dive", "group": "warden", "owner_kind": "faction", "owner": "swarm", "allegiance": "hostile", "threat": "threat_lane", "glyph": "arrow", "color": Palette.HAZARD,
		"pose": "w03_cells_direct", "warn": "atk_e17_warn", "release": "atk_e17_release", "floor": "B", "open": []},
	"W04": {"label": "Mind Warden pulse", "group": "warden", "owner_kind": "faction", "owner": "mind", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "w04_mast_telescope", "warn": "atk_w04_warn", "release": "atk_w04_release", "floor": "B", "open": []},
	"W06": {"label": "Mind Warden adaptation", "group": "warden", "owner_kind": "faction", "owner": "mind", "allegiance": "neutral", "threat": "", "glyph": "core", "color": Palette.SAND,
		"pose": "w06_lens_stare", "warn": "atk_w06_warn", "release": "atk_w06_release", "floor": "none", "open": []},
	"W07": {"label": "Caught-pulse crater", "group": "warden", "owner_kind": "faction", "owner": "reactor", "allegiance": "hostile", "threat": "", "glyph": "burst", "color": Palette.HAZARD,
		"pose": "w07_crater_bowl", "warn": NONE, "release": "atk_w07_release", "floor": "B", "open": []},
	"B01": {"label": "Crane sweep", "group": "brindle", "owner_kind": "boss", "owner": "brindle", "allegiance": "hostile", "threat": "threat_wave", "glyph": "wave", "color": Palette.HAZARD,
		"pose": "b01_crane_windback", "warn": "atk_b01_warn", "release": "atk_b01_release", "floor": "B", "open": []},
	"B02": {"label": "Furnace slag", "group": "brindle", "owner_kind": "boss", "owner": "brindle", "allegiance": "hostile", "threat": "threat_instant", "glyph": "ring", "color": Palette.HAZARD,
		"pose": "b02_outlets_open", "warn": "atk_b02_warn", "release": "atk_b02_release", "floor": "B", "open": []},
	"B03": {"label": "Scuttle charge", "group": "brindle", "owner_kind": "boss", "owner": "brindle", "allegiance": "hostile", "threat": "threat_lane", "glyph": "bar", "color": Palette.HAZARD,
		"pose": "b03_prow_dip", "warn": "atk_b03_warn", "release": "atk_b03_release", "floor": "B", "open": []},
	"B04": {"label": "Drone deployment", "group": "brindle", "owner_kind": "boss", "owner": "brindle", "allegiance": "neutral", "threat": "", "glyph": "diamond", "color": Palette.AMBER,
		"pose": "b04_hatch_open", "warn": "atk_b04_warn", "release": NONE, "floor": "L", "open": []},
	"B05": {"label": "Ejection chase", "group": "brindle", "owner_kind": "boss", "owner": "brindle", "allegiance": "neutral", "threat": "", "glyph": "arrow", "color": Palette.BRASS,
		"pose": "b05_seat_compress", "warn": NONE, "release": "atk_b05_release", "floor": "none", "open": []},
	"P01": {"label": "Arc caster volley", "group": "pilot", "owner_kind": "class", "owner": "pylon_engineer", "allegiance": "player", "threat": "", "glyph": "ring", "color": ClassDef.SABLE_COLOR,
		"pose": "p01_prongs_aim", "warn": NONE, "release": "atk_p01_release", "floor": "L", "open": []},
	"P02": {"label": "Discharge and plant burst", "group": "pilot", "owner_kind": "class", "owner": "pylon_engineer", "allegiance": "player", "threat": "", "glyph": "ring", "color": ClassDef.SABLE_COLOR,
		"pose": "p02_coils_open", "warn": "atk_p02_warn", "release": "atk_p02_release", "floor": "L", "open": []},
	"P03": {"label": "Arc slam", "group": "pilot", "owner_kind": "class", "owner": "pylon_engineer", "allegiance": "player", "threat": "", "glyph": "ring", "color": ClassDef.SABLE_COLOR,
		"pose": "p03_prongs_down", "warn": "atk_p03_warn", "release": "atk_p03_release", "floor": "L", "open": []},
	"P04": {"label": "Rapid laser", "group": "pilot", "owner_kind": "class", "owner": "runner_gunner", "allegiance": "player", "threat": "", "glyph": "chevron", "color": ClassDef.RIVET_COLOR,
		"pose": "p04_barrel_shoulder", "warn": NONE, "release": "atk_p04_release", "floor": "L", "open": []},
	"P05": {"label": "Overdrive blast", "group": "pilot", "owner_kind": "class", "owner": "runner_gunner", "allegiance": "player", "threat": "", "glyph": "chevron", "color": ClassDef.RIVET_COLOR,
		"pose": "p05_vanes_flare", "warn": "atk_p05_warn", "release": "atk_p05_release", "floor": "L", "open": []},
	"P06": {"label": "Sprint ram and skid", "group": "pilot", "owner_kind": "class", "owner": "runner_gunner", "allegiance": "player", "threat": "", "glyph": "chevron", "color": ClassDef.RIVET_COLOR,
		"pose": "p06_brace_forward", "warn": "atk_p06_warn", "release": "atk_p06_release", "floor": "L", "open": []},
	"P07": {"label": "Sticky charge", "group": "pilot", "owner_kind": "class", "owner": "demolitions_caster", "allegiance": "player", "threat": "", "glyph": "burst", "color": ClassDef.KEST_COLOR,
		"pose": "p07_payload_raise", "warn": "atk_p07_warn", "release": "atk_p07_release", "floor": "B", "open": []},
	"P08": {"label": "Detonation line", "group": "pilot", "owner_kind": "class", "owner": "demolitions_caster", "allegiance": "player", "threat": "", "glyph": "burst", "color": ClassDef.KEST_COLOR,
		"pose": "p08_detonator_stretch", "warn": "atk_p08_warn", "release": "atk_p08_release", "floor": "B", "open": []},
	"P09": {"label": "Demo slam mini-charges", "group": "pilot", "owner_kind": "class", "owner": "demolitions_caster", "allegiance": "player", "threat": "", "glyph": "burst", "color": ClassDef.KEST_COLOR,
		"pose": "p09_rack_open", "warn": "atk_p09_warn", "release": "atk_p09_release", "floor": "B", "open": []},
	"P10": {"label": "Phantom blink cut", "group": "pilot", "owner_kind": "class", "owner": "demolitions_caster", "allegiance": "player", "threat": "", "glyph": "burst", "color": ClassDef.KEST_COLOR,
		"pose": "p10_tool_blink", "warn": NONE, "release": "atk_p10_release", "floor": "L", "open": []},
	"P11": {"label": "Ram, crush and stomp", "group": "pilot", "owner_kind": "pilot_any", "owner": "any", "allegiance": "player", "threat": "", "glyph": "arrow", "color": Palette.SAND,
		"pose": "p11_cockpit_tilt", "warn": "atk_p11_warn", "release": "atk_p11_release", "floor": "L", "open": []},
	"P12": {"label": "Batted shell and pins", "group": "pilot", "owner_kind": "pilot_any", "owner": "any", "allegiance": "player", "threat": "", "glyph": "ring", "color": Palette.AMBER,
		"pose": "p12_trail_stretch", "warn": NONE, "release": "atk_p12_release", "floor": "B", "open": []},
	"P13": {"label": "Pilot upgrade attacks", "group": "pilot", "owner_kind": "pilot_any", "owner": "any", "allegiance": "player", "threat": "", "glyph": "diamond", "color": Palette.SAND,
		"pose": "p13_parent_pose", "warn": NONE, "release": NONE, "floor": "L", "open": []},
}

const CODEX_CATEGORIES := {
	"build": {"label": "Build", "color": Palette.AMBER, "shape": "diamond", "reserved": false},
	"world": {"label": "World", "color": Palette.ARC, "shape": "wave", "reserved": false},
	"enemy": {"label": "Enemy", "color": Palette.RUST, "shape": "burst", "reserved": false},
	"npc": {"label": "NPC", "color": Palette.SANDSTONE, "shape": "square", "reserved": true},
	"coop": {"label": "Co-op", "color": Palette.COPPER, "shape": "chevron", "reserved": true},
}


static func has(kind: String) -> bool:
	return ROWS.has(kind) or LINE_SIGNALS.has(kind)


static func row(kind: String) -> Dictionary:
	if LINE_SIGNALS.has(kind):
		return line_as_row(LINE_SIGNALS[kind])
	return ROWS.get(kind, {})


static func color(kind: String) -> Color:
	return row(kind).get("color", Palette.SAND)


static func priority(kind: String) -> int:
	return row(kind).get("priority", 0)


static func hud(kind: String, fields := {}) -> String:
	return String(row(kind).get("hud", "")).format(fields)


static func objective(kind: String, fields := {}) -> String:
	return String(row(kind).get("objective", "")).format(fields)


static func category(id: String) -> Dictionary:
	return CODEX_CATEGORIES.get(id, CODEX_CATEGORIES["build"])


static func has_attack(id: String) -> bool:
	return ATTACK_ROWS.has(id)


static func attack_row(id: String) -> Dictionary:
	return ATTACK_ROWS.get(id, {})


static func attack_ids(group := "") -> Array[String]:
	var ids: Array[String] = []
	for id in ATTACK_ROWS:
		if group == "" or ATTACK_ROWS[id]["group"] == group:
			ids.append(id)
	return ids


static func attack_label(id: String) -> String:
	return String(attack_row(id).get("label", ""))


static func attack_threat(id: String) -> String:
	return String(attack_row(id).get("threat", ""))


static func attack_glyph(id: String) -> String:
	return String(attack_row(id).get("glyph", "none"))


static func attack_color(id: String) -> Color:
	return attack_row(id).get("color", Palette.SAND)


static func attack_pose(id: String) -> String:
	return String(attack_row(id).get("pose", ""))


static func attack_warn_cue(id: String) -> String:
	return String(attack_row(id).get("warn", NONE))


static func attack_release_cue(id: String) -> String:
	return String(attack_row(id).get("release", NONE))


static func attack_floor(id: String) -> String:
	return String(attack_row(id).get("floor", NONE))


static func attack_open(id: String) -> Array:
	return attack_row(id).get("open", [])


const COLOR_ROLES := ["hazard", "live", "amber", "slate", "rust", "neutral"]
const MOTIONS := ["pulse", "steady", "none"]
const MAX_WORDS := 3
const STATE_FIELDS := ["color", "motion", "shape", "sound", "verb", "word"]
const LINE_FIELDS := STATE_FIELDS

const LINE_ROWS := {
	"searching": {"color": "neutral", "motion": "none", "shape": "cross", "sound": NONE, "verb": NONE, "word": ""},
	"locked": {"color": "live", "motion": "pulse", "shape": "ring", "sound": "lock_tick", "verb": "harpoon", "word": "HOOK"},
	"dry_fire": {"color": "slate", "motion": "none", "shape": "bar", "sound": "dry_tick", "verb": "harpoon", "word": ""},
	"latched_world": {"color": "live", "motion": "steady", "shape": "square", "sound": "anchor_clunk", "verb": "haul", "word": ""},
	"latched_body": {"color": "live", "motion": "steady", "shape": "diamond", "sound": "line_bite", "verb": "haul", "word": "SMASH"},
	"smash_committed": {"color": "live", "motion": "none", "shape": "arrow", "sound": "smash_whistle", "verb": NONE, "word": ""},
	"smash_lands": {"color": "live", "motion": "none", "shape": "ring", "sound": "slam_boom", "verb": NONE, "word": ""},
	"rewinding": {"color": "live", "motion": "none", "shape": "chevron", "sound": "dock_click", "verb": NONE, "word": ""},
	"let_go": {"color": "live", "motion": "none", "shape": "chevron", "sound": "line_zip", "verb": "harpoon", "word": ""},
	"broke": {"color": "rust", "motion": "none", "shape": "burst", "sound": "line_twang", "verb": NONE, "word": ""},
	"chain_link": {"color": "live", "motion": "none", "shape": "diamond", "sound": "line_bite", "verb": NONE, "word": ""},
	"chain_pivot": {"color": "live", "motion": "none", "shape": "square", "sound": NONE, "verb": NONE, "word": ""},
	"chain_end": {"color": "slate", "motion": "none", "shape": "chevron", "sound": "line_zip", "verb": NONE, "word": ""},
	"chain_miss": {"color": "slate", "motion": "none", "shape": "bar", "sound": "dry_tick", "verb": NONE, "word": ""},
}
const LINE_SIGNALS := {"harpoon_bit": "latched_body", "harpoon_smashed": "smash_lands"}
const LINE_SIGNAL_GROUP := "movement"
const LINE_SIGNAL_PRIORITY := 1

const STATE_ROWS := {
	"posture_step": {"color": "neutral", "motion": "none", "shape": "chevron", "sound": "hit_thwack", "verb": NONE, "word": ""},
	"chunk_shatter": {"color": "live", "motion": "none", "shape": "burst", "sound": "shatter", "verb": NONE, "word": ""},
	"latched": {"color": "live", "motion": "steady", "shape": "diamond", "sound": NONE, "verb": NONE, "word": ""},
	"will_break": {"color": "live", "motion": "pulse", "shape": "bar", "sound": NONE, "verb": NONE, "word": ""},
	"open": {"color": "live", "motion": "steady", "shape": "core", "sound": "boss_weak_hit", "verb": NONE, "word": ""},
	"glancing": {"color": "slate", "motion": "none", "shape": "burst", "sound": "clank", "verb": NONE, "word": ""},
	"interrupted": {"color": "live", "motion": "none", "shape": "star", "sound": NONE, "verb": NONE, "word": ""},
	"held": {"color": "hazard", "motion": "steady", "shape": "bar", "sound": "hold_pit", "verb": NONE, "word": ""},
	"beacon_sealed": {"color": "slate", "motion": "none", "shape": "ring", "sound": NONE, "verb": NONE, "word": ""},
	"beacon_open": {"color": "amber", "motion": "steady", "shape": "ring", "sound": "beacon_open_chime", "verb": NONE, "word": ""},
	"wearing": {"color": "rust", "motion": "steady", "shape": "chevron", "sound": NONE, "verb": NONE, "word": ""},
	"dented": {"color": "slate", "motion": "none", "shape": "square", "sound": NONE, "verb": NONE, "word": "DENT"},
	"zzapped": {"color": "live", "motion": "none", "shape": "cross", "sound": NONE, "verb": NONE, "word": "ZZAP!"},
	"plated": {"color": "slate", "motion": "steady", "shape": "square", "sound": NONE, "verb": NONE, "word": ""},
}

const CAUSE_FIELDS := ["color", "shape", "motif"]
const CAUSE_ROWS := {
	"wrecking_ball": {"color": "amber", "shape": "ring", "motif": ["C3", "G3", "C4"]},
	"tesla_pylon": {"color": "amber", "shape": "cross", "motif": ["D4", "A4", "F4"]},
	"pinwheel": {"color": "amber", "shape": "star", "motif": ["E4", "G4", "B4"]},
	"shrapnel_bloom": {"color": "amber", "shape": "burst", "motif": ["A3", "E4", "A4"]},
	"lightning_rod": {"color": "amber", "shape": "arrow", "motif": ["G4", "D5", "B4"]},
}

const TAG_GLYPHS := {
	"arc": "bolt", "kinetic": "disc", "mass": "core", "anchor": "bar", "speed": "chevron",
	"spiral": "wave", "split": "diamond", "chain": "square", "frost": "diamond",
}

const ACTIVITY_FIELDS := ["color", "motion", "shape", "sound", "word"]
const ACTIVITY_ROWS := {
	"enemy_camp": {"color": "amber", "motion": "steady", "shape": "cross", "sound": "found_chime", "word": "Camp"},
	"surge_run": {"color": "amber", "motion": "steady", "shape": "chevron", "sound": "found_chime", "word": "Surge"},
	"ambush_altar": {"color": "amber", "motion": "steady", "shape": "cross", "sound": "found_chime", "word": "Ambush"},
	"cracked_cache": {"color": "amber", "motion": "steady", "shape": "diamond", "sound": "found_chime", "word": "Cache"},
	"hauler_bounty": {"color": "amber", "motion": "steady", "shape": "square", "sound": "found_chime", "word": "Bounty"},
	"hold_the_relay": {"color": "amber", "motion": "steady", "shape": "cross", "sound": "found_chime", "word": "Relay"},
}


static func role_color(role: String) -> Color:
	match role:
		"hazard":
			return Palette.HAZARD
		"live":
			return Palette.live()
		"amber":
			return Palette.AMBER
		"slate":
			return Palette.SLATE
		"rust":
			return Palette.RUST
		"neutral":
			return Palette.SAND
	push_error("EventKinds.role_color: no colour role named '%s'" % role)
	return Palette.SAND


static func line_row(state: String) -> Dictionary:
	return LINE_ROWS.get(state, {})


static func line_color(state: String) -> Color:
	return role_color(String(line_row(state).get("color", "")))


static func line_sound(state: String) -> String:
	return String(line_row(state).get("sound", NONE))


static func line_as_row(state: String) -> Dictionary:
	var entry := line_row(state)
	return {"group": LINE_SIGNAL_GROUP, "color": line_color(state), "shape": entry.get("shape", "none"), "sound": entry.get("sound", NONE),
		"hud": "", "objective": "", "priority": LINE_SIGNAL_PRIORITY}


static func state_row(id: String) -> Dictionary:
	return STATE_ROWS.get(id, {})


static func state_color(id: String) -> Color:
	return role_color(String(state_row(id).get("color", "")))


static func cause_row(id: String) -> Dictionary:
	return CAUSE_ROWS.get(id, {})


static func cause_color(id: String) -> Color:
	return role_color(String(cause_row(id).get("color", "")))


static func cause_motif(id: String) -> Array:
	return cause_row(id).get("motif", [])


static func tag_glyph(tag: String) -> String:
	return String(TAG_GLYPHS.get(tag, ""))


static func cause_glyphs(tags: Array) -> Array:
	var out: Array = []
	for tag in tags:
		var glyph := tag_glyph(String(tag))
		if glyph == "":
			return []
		out.append(glyph)
	return out


static func activity_row(id: String) -> Dictionary:
	return ACTIVITY_ROWS.get(id, {})


static func activity_color(id: String) -> Color:
	return role_color(String(activity_row(id).get("color", "")))


const UI_ROWS := {
	"posture_break": {"group": "combat", "color": Palette.SAND, "shape": "burst", "sound": "drop_landing", "hud": "", "objective": "", "priority": 1},
	"guard_critical": {"group": "combat", "color": Palette.SAND, "shape": "bar", "sound": "guard_creak", "hud": "", "objective": "", "priority": 2},
	"ability_ready": {"group": "combat", "color": Palette.SAND, "shape": "ring", "sound": "class_motif", "hud": "", "objective": "", "priority": 1},
	"ability_cooling": {"group": "combat", "color": Palette.VERDIGRIS, "shape": "ring", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"ability_active": {"group": "combat", "color": Palette.SAND, "shape": "star", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"ability_unavailable": {"group": "combat", "color": Palette.SANDSTONE, "shape": "cross", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"cooldown_refunded": {"group": "combat", "color": Palette.SAND, "shape": "chevron", "sound": "ui_tick", "hud": "", "objective": "", "priority": 1},
	"key_glyph": {"group": "flow", "color": Palette.SAND, "shape": "square", "sound": "ui_tick", "hud": "", "objective": "", "priority": 1},
	"run_timer": {"group": "flow", "color": Palette.SAND, "shape": "ring", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"callout_scrap": {"group": "economy", "color": Palette.AMBER, "shape": "square", "sound": "callout_chime", "hud": "Scrap = heft", "objective": "", "priority": 2},
	"callout_warden": {"group": "flow", "color": Palette.HAZARD, "shape": "cross", "sound": "callout_chime", "sound_next": "callout_warden_chime", "hud": "Break it", "objective": "", "priority": 2},
	"callout_gates": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "callout_chime", "hud": "Roll through", "objective": "", "priority": 2},
	"callout_notes": {"group": "flow", "color": Palette.SAND, "shape": "square", "sound": "callout_chime", "hud": "Hold {key_tab} for notes", "objective": "", "priority": 2},
	"hint_wall_bait": {"group": "flow", "color": Palette.BRASS, "shape": "chevron", "sound": "callout_chime", "hud": "Make him hit walls", "objective": "", "priority": 3},
	"companion_ready": {"group": "combat", "color": Palette.VERDIGRIS, "shape": "diamond", "sound": "companion_chirp_ready", "hud": "", "objective": "", "priority": 1},
	"companion_spent": {"group": "combat", "color": Palette.SANDSTONE, "shape": "ring", "sound": "companion_chirp_spent", "hud": "", "objective": "", "priority": 1},
	"escape_acted": {"group": "combat", "color": Palette.VERDIGRIS, "shape": "arrow", "sound": "companion_chirp_ready", "sound_next": "companion_chirp_escape", "hud": "", "objective": "", "priority": 1},
	"cadence_rivet_notch_open": {"group": "combat", "color": Palette.SAND, "shape": "ring", "sound": "cadence_rivet_notch_open", "hud": "", "objective": "", "priority": 1},
	"cadence_rivet_notch_hit": {"group": "combat", "color": ClassDef.RIVET_COLOR, "shape": "burst", "sound": "cadence_rivet_notch_hit", "hud": "", "objective": "", "priority": 1},
	"cadence_rivet_spent": {"group": "combat", "color": Palette.SLATE, "shape": "bar", "sound": "cadence_rivet_spent", "hud": "", "objective": "", "priority": 1},
	"cadence_sable_full": {"group": "combat", "color": Palette.SAND, "shape": "ring", "sound": "cadence_sable_full", "hud": "", "objective": "", "priority": 1},
	"cadence_sable_bolt": {"group": "combat", "color": Palette.COBALT, "shape": "burst", "sound": "cadence_sable_bolt", "hud": "", "objective": "", "priority": 1},
	"cadence_kest_window": {"group": "combat", "color": Palette.SAND, "shape": "ring", "sound": "cadence_kest_window", "hud": "", "objective": "", "priority": 1},
	"cadence_kest_snap": {"group": "combat", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "cadence_kest_snap", "hud": "", "objective": "", "priority": 1},
	"cadence_tarn_window": {"group": "combat", "color": Palette.SAND, "shape": "cross", "sound": "cadence_tarn_window", "hud": "", "objective": "", "priority": 1},
	"cadence_tarn_rend": {"group": "combat", "color": ClassDef.TARN_COLOR, "shape": "burst", "sound": "cadence_tarn_rend", "hud": "", "objective": "", "priority": 1},
	"cadence_tally_beat": {"group": "combat", "color": Palette.SAND, "shape": "square", "sound": "cadence_tally_beat", "hud": "", "objective": "", "priority": 1},
	"cadence_tally_paid": {"group": "combat", "color": Palette.LEDGER_CREAM, "shape": "square", "sound": "cadence_tally_paid", "hud": "", "objective": "", "priority": 1},
	"cadence_cannon_lock": {"group": "combat", "color": Palette.SAND, "shape": "lane", "sound": "cadence_cannon_lock", "hud": "", "objective": "", "priority": 1},
	"cadence_cannon_rail": {"group": "combat", "color": ClassDef.CANNON_COLOR, "shape": "lane", "sound": "cadence_cannon_rail", "hud": "", "objective": "", "priority": 1},
	"cadence_cannon_barrage": {"group": "combat", "color": Palette.SLATE, "shape": "lane", "sound": "cadence_cannon_barrage", "hud": "", "objective": "", "priority": 1},
	"rail_rise": {"group": "flow", "color": Palette.SAND, "shape": "bar", "sound": "rail_rise", "hud": "", "objective": "", "priority": 1},
	"rail_sink": {"group": "flow", "color": Palette.SLATE, "shape": "bar", "sound": "rail_sink", "hud": "", "objective": "", "priority": 1},
}

const FACTION_ICONS := {"fleet": "fac_fleet", "reactor": "fac_reactor", "swarm": "fac_swarm", "mind": "fac_mind"}


static func faction_icon(faction: String) -> String:
	return FACTION_ICONS.get(faction, "fac_fleet")


const LOOT_ROWS := {
	"shop_entered": {"group": "economy", "color": Palette.AMBER, "shape": "square", "sound": "pylon_plant", "hud": "", "objective": "", "priority": 1},
	"shop_left": {"group": "economy", "color": Palette.AMBER, "shape": "arrow", "sound": "pylon_eject", "hud": "", "objective": "", "priority": 1},
	"shop_bought": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "part_get", "sound_next": "shop_bell", "hud": "", "objective": "", "priority": 2},
	"shop_charge": {"group": "economy", "color": Palette.AMBER, "shape": "core", "sound": "core_socket", "sound_next": "shop_bell", "hud": "", "objective": "", "priority": 2},
	"shop_rerolled": {"group": "economy", "color": Palette.SANDSTONE, "shape": "square", "sound": "clank", "sound_next": "bench_clank", "hud": "", "objective": "", "priority": 1},
	"shop_sold": {"group": "economy", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "scrap_tick", "sound_next": "bench_clank", "hud": "", "objective": "", "priority": 1},
	"shop_refused": {"group": "economy", "color": Palette.SAND, "shape": "cross", "sound": "ui_tick", "sound_next": "moss_grumble", "hud": "", "objective": "", "priority": 1},
	"moss_beat": {"group": "economy", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "sound_next": "moss_babble", "hud": "", "objective": "", "priority": 1},
	"moss_relent": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "found_chime", "sound_next": "moss_babble_sigh", "hud": "", "objective": "", "priority": 2},
	"item_proc": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "found_chime", "sound_next": "trigger_tick", "hud": "", "objective": "", "priority": 0},
	"par_split": {"group": "flow", "color": Palette.SAND, "shape": "bar", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"reward_common": {"group": "economy", "color": Palette.SANDSTONE, "shape": "diamond", "sound": "rarity_tick", "hud": "", "objective": "", "priority": 1,
		"tier": "common", "pause": "never"},
	"reward_rare": {"group": "economy", "color": Palette.COBALT, "shape": "ring", "sound": "rarity_bell", "hud": "", "objective": "", "priority": 1,
		"tier": "rare", "pause": "never", "stop_ms": 45.0, "ring_m": 4.5, "flare_s": 0.5},
	"reward_reveal": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "reveal_clank", "sound_snap": "synergy_hit", "hud": "", "objective": "", "priority": 2,
		"tier": "reveal", "pause": "never", "heart": Palette.ARC, "in_s": 0.22, "hold_s": 2.4, "out_s": 0.25, "snap_s": 0.18, "words": 6,
		"stamps": {"common": "FIELD KIT", "rare": "FLEET GRADE", "relic": "RELIC", "evolved": "EVOLVED", "evolution": "EVOLVED", "first": "NEW"}},
	"reward_ceremony": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "ceremony_build", "sound_burst": "ceremony_resolve", "hud": "", "objective": "", "priority": 3,
		"tier": "ceremony", "pause": "calm", "burst_role": "class", "in_s": 0.25, "build_s": 1.4, "hold_s": 1.8, "out_s": 0.25,
		"calm_hold_s": 0.4, "threat_m": 30.0, "enemy_m": 24.0, "fall_speed": 4.0, "hull_slots": 8},
	"reward_payoff": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "rarity_bell", "hud": "", "objective": "", "priority": 1,
		"tier": "payoff", "pause": "never", "flash_s": 0.7},
	"armor_hit": {"group": "combat", "color": Palette.AMBER, "shape": "burst", "sound": "armor_shed", "hud": "", "objective": "", "priority": 1},
	"armor_reclaim": {"group": "economy", "color": Palette.AMBER, "shape": "square", "sound": "armor_reclaim", "hud": "", "objective": "", "priority": 1},
	"armor_deflect": {"group": "combat", "color": Palette.SAND, "shape": "square", "sound": "armor_deflect", "hud": "", "objective": "", "priority": 1},
}

const REWARD_TIERS := ["common", "rare", "reveal", "ceremony"]
const REWARD_TIER_BY_RARITY := {"common": "common", "rare": "rare", "relic": "reveal", "evolved": "ceremony", "evolution": "ceremony"}
const CEREMONY_SOURCES := ["gate", "boss", "vault", "cache", "cage", "warden", "evolution"]
const REWARD_RUNGS := {"common": 0, "rare": 4, "relic": 5, "evolved": 7, "evolution": 7}
const REWARD_RUNG_CUES := {"rare": "rung_coil"}


static func reward_row(tier: String) -> Dictionary:
	return LOOT_ROWS.get("reward_" + tier, {})


const ANCIENT_LIGHT := Palette.ANCIENT
const WORLD_ROWS := {
	"ground_slump": {"group": "event", "color": Palette.HAZARD, "shape": "bar", "pattern": "dust_crack", "dust_height_m": 3.0, "crack_width_m": 0.3, "sound": "threat_tick", "sound_next": "rock_grind_dust_hiss", "hud": "", "objective": "", "priority": 2},
	"ground_slump_landed": {"group": "event", "color": Palette.HAZARD, "shape": "bar", "pattern": "dust_crack", "dust_height_m": 3.0, "crack_width_m": 0.3, "sound": "slam_boom", "sound_next": "rockfall_boom", "hud": "", "objective": "", "priority": 2},
	"flood_rising": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "threat_whistle", "sound_next": "flood_falling_pure", "hud": "", "objective": "", "priority": 2},
	"flood_landed": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "slam_boom", "sound_next": "flood_drop", "hud": "", "objective": "", "priority": 2},
	"fleet_inbound": {"group": "event", "color": Palette.HAZARD, "shape": "cross", "sound": "threat_whistle", "sound_next": "fleet_falling_pure", "hud": "", "objective": "", "priority": 2},
	"fleet_landed": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "slam_boom", "sound_next": "fleet_anvil_brass_drop", "hud": "", "objective": "", "priority": 2},
	"cage_rising": {"group": "event", "color": Palette.HAZARD, "shape": "chevron", "sound": "threat_tick", "sound_next": "lift_chuff_clank", "hud": "", "objective": "", "priority": 2},
	"cage_landed": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "slam_boom", "sound_next": "fleet_anvil_brass_drop", "hud": "", "objective": "", "priority": 2},
	"zipline_inbound": {"group": "event", "color": Palette.HAZARD, "shape": "arrow", "sound": "threat_whistle", "sound_next": "fleet_falling_pure", "hud": "", "objective": "", "priority": 2},
	"zipline_landed": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "slam_boom", "sound_next": "fleet_anvil_brass_drop", "hud": "", "objective": "", "priority": 2},
	"ancient_stirring": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "threat_whistle", "sound_next": "ancient_falling_pure", "hud": "", "objective": "", "priority": 2},
	"ancient_erupted": {"group": "event", "color": ANCIENT_LIGHT, "shape": "burst", "sound": "slam_boom", "sound_next": "ancient_family_drop", "hud": "", "objective": "", "priority": 2},
	"boiler_pressure": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "threat_whistle", "sound_next": "boiler_falling_pure", "hud": "", "objective": "", "priority": 2},
	"boiler_landed": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "slam_boom", "sound_next": "steam_whistle_percussion_drop", "hud": "", "objective": "", "priority": 2},
	"lightning_charge": {"group": "event", "color": Palette.HAZARD, "shape": "cross", "sound": "threat_whistle", "sound_next": "lightning_falling_pure", "hud": "", "objective": "", "priority": 2},
	"lightning_landed": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "slam_boom", "sound_next": "lightning_strike", "hud": "", "objective": "", "priority": 2},
	"crust_crack": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "threat_tick", "sound_next": "rock_grind_dust_hiss", "hud": "", "objective": "", "priority": 2},
	"crust_crack_landed": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "slam_boom", "sound_next": "rockfall_boom", "hud": "", "objective": "", "priority": 2},
	"drain_gurgle": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "ride_glide_wind", "hud": "", "objective": "", "priority": 1},
	"drain_landed": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "found_chime", "sound_next": "found_chime", "hud": "", "objective": "", "priority": 1},
	"trestle_groan": {"group": "event", "color": Palette.HAZARD, "shape": "bar", "sound": "threat_tick", "sound_next": "rock_grind_dust_hiss", "hud": "", "objective": "", "priority": 2},
	"trestle_landed": {"group": "event", "color": Palette.HAZARD, "shape": "bar", "sound": "slam_boom", "sound_next": "rockfall_boom", "hud": "", "objective": "", "priority": 2},
	"lightning_mark": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "threat_whistle", "sound_next": "lightning_falling_pure", "hud": "", "objective": "", "priority": 2},
	"lightning_mark_landed": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "slam_boom", "sound_next": "lightning_strike", "hud": "", "objective": "", "priority": 2},
	"reactor_overload": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "threat_whistle", "sound_next": "boiler_falling_pure", "hud": "", "objective": "", "priority": 2},
	"reactor_landed": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "slam_boom", "sound_next": "crater_crump_sub_boom", "hud": "", "objective": "", "priority": 2},
	"sluice_siren": {"group": "event", "color": Palette.VERDIGRIS, "shape": "chevron", "sound": "beacon_hum", "sound_next": "sluice_siren_two_tone", "hud": "", "objective": "", "priority": 2},
	"sluice_landed": {"group": "event", "color": Palette.VERDIGRIS, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "sluice_gush_roar", "hud": "", "objective": "", "priority": 2},
	"shell_air_shift": {"group": "movement", "color": Palette.AMBER, "shape": "ring", "sound": "shell_spring", "hud": "", "objective": "", "priority": 1},
	"lift_fired": {"group": "event", "color": Palette.SAND, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "lift_chuff_clank", "hud": "", "objective": "", "priority": 1},
	"launcher_charging": {"group": "event", "color": Palette.SAND, "shape": "ring", "sound": "beacon_hum", "sound_next": "steam_whistle_rise", "hud": "", "objective": "", "priority": 0},
	"cannon_fired": {"group": "event", "color": Palette.SAND, "shape": "arrow", "sound": "launch_roar", "sound_next": "cannon_bang_rail_whoosh", "hud": "", "objective": "", "priority": 1},
	"trebuchet_fired": {"group": "event", "color": Palette.SAND, "shape": "arrow", "sound": "launch_roar", "sound_next": "trebuchet_creak_whoosh", "hud": "", "objective": "", "priority": 1},
	"glaze_skim": {"group": "event", "color": Palette.LEDGER, "shape": "wave", "sound": "line_zip", "sound_next": "glaze_skim_hiss", "hud": "", "objective": "", "priority": 0},
	"cinder_glow": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "threat_tick", "sound_next": "rock_grind_dust_hiss", "hud": "", "objective": "", "priority": 1},
	"cinder_burn": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "threat_tick", "sound_next": "valve_womp_hiss", "hud": "", "objective": "", "priority": 2},
	"cinder_cooled": {"group": "event", "color": Palette.SAND, "shape": "wave", "sound": "boost_whoosh", "sound_next": "valve_womp_hiss", "hud": "", "objective": "", "priority": 0},
	"geyser_fired": {"group": "event", "color": Palette.SAND, "shape": "arrow", "sound": "launch_roar", "sound_next": "geyser_whistle_bang", "hud": "", "objective": "", "priority": 1},
	"valve_smashed": {"group": "event", "color": Palette.SAND, "shape": "ring", "sound": "slam_boom", "sound_next": "valve_womp_hiss", "hud": "", "objective": "", "priority": 2},
	"route_opened": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "found_chime", "sound_next": "found_chime", "hud": "", "objective": "", "priority": 1},
	"cave_in_crumble": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "threat_tick", "sound_next": "rock_grind_dust_hiss", "hud": "", "objective": "", "priority": 2},
	"cave_in_swap": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "slam_boom", "sound_next": "rockfall_boom", "hud": "", "objective": "", "priority": 2},
	"impact_incoming": {"group": "event", "color": Palette.HAZARD, "shape": "cross", "sound": "threat_whistle", "sound_next": "far_thunk_falling_whistle", "hud": "", "objective": "", "priority": 2},
	"impact_swap": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "slam_boom", "sound_next": "crater_crump_sub_boom", "hud": "", "objective": "", "priority": 2},
	"crater_ride": {"group": "event", "color": Palette.SANDSTONE, "shape": "ring", "sound": "boost_whoosh", "sound_next": "rail_ride_whoosh", "hud": "", "objective": "", "priority": 1},
	"layer_undercroft": {"group": "event", "color": Palette.VERDIGRIS, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_reese_sub", "hud": "", "objective": "", "priority": 0},
	"layer_shelf": {"group": "event", "color": Palette.SANDSTONE, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_theme", "hud": "", "objective": "", "priority": 0},
	"layer_sky": {"group": "event", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_bells_arp", "hud": "", "objective": "", "priority": 0},
	"layer_crown_hoodoos": {"group": "event", "color": Palette.SANDSTONE, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_crown_hoodoos", "hud": "", "objective": "", "priority": 0},
	"layer_crown_alcove": {"group": "event", "color": Palette.SANDSTONE, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_crown_alcove", "hud": "", "objective": "", "priority": 0},
	"layer_crown_toppled": {"group": "event", "color": Palette.SANDSTONE, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_crown_toppled", "hud": "", "objective": "", "priority": 0},
	"layer_crown_ramp": {"group": "event", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_crown_ramp", "hud": "", "objective": "", "priority": 0},
	"layer_mind_quote_spillway": {"group": "event", "color": ANCIENT_LIGHT, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_mind_quote_spillway", "hud": "", "objective": "", "priority": 0},
	"ride_grapple_line": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "grapple_clink", "sound_next": "ride_cable_clink", "hud": "", "objective": "", "priority": 1},
	"ride_glide_drop": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "dash_whoosh", "sound_next": "ride_glide_wind", "hud": "", "objective": "", "priority": 1},
	"ride_skylight": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "ride_rail_hum", "hud": "", "objective": "", "priority": 1},
	"ride_chute": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "ride_rolling_metal", "hud": "", "objective": "", "priority": 1},
	"ride_bowl": {"group": "event", "color": Palette.SANDSTONE, "shape": "ring", "sound": "boost_whoosh", "sound_next": "ride_bowl_carve", "hud": "", "objective": "", "priority": 1},
	"ride_drop": {"group": "event", "color": Palette.SANDSTONE, "shape": "arrow", "sound": "dash_whoosh", "sound_next": "ride_drop_swoop", "hud": "", "objective": "", "priority": 1},
	"ride_ledge": {"group": "event", "color": Palette.SANDSTONE, "shape": "bar", "sound": "boost_whoosh", "sound_next": "ride_ledge_scuff", "hud": "", "objective": "", "priority": 1},
	"ride_hop": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "dash_whoosh", "sound_next": "ride_hop_lift", "hud": "", "objective": "", "priority": 1},
	"ride_sheet": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "ride_sheet_swell", "hud": "", "objective": "", "priority": 1},
	"hoist_ride": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "hoist_winch_g5", "hud": "", "objective": "", "priority": 1},
	"pool_swell": {"group": "event", "color": Palette.SANDSTONE, "shape": "wave", "sound": "boost_whoosh", "sound_next": "pool_low_swell", "hud": "", "objective": "", "priority": 1},
	"landmark_hum": {"group": "event", "color": ANCIENT_LIGHT, "shape": "wave", "sound": "beacon_hum", "sound_next": "landmark_sub_pulse", "hud": "", "objective": "", "priority": 0},
	"thermal_ride": {"group": "event", "color": Palette.SAND, "shape": "wave", "sound": "boost_whoosh", "sound_next": "thermal_updraft_swell", "hud": "", "objective": "", "priority": 1},
	"wall_crumbled": {"group": "event", "color": Palette.SANDSTONE, "shape": "burst", "sound": "shatter", "sound_next": "cracked_wall_crumble", "hud": "", "objective": "", "priority": 1},
	"reactor_vented": {"group": "event", "color": ANCIENT_LIGHT, "shape": "wave", "sound": "beacon_hum", "sound_next": "reactor_vent_sine_plume", "hud": "", "objective": "", "priority": 1},
	"bay_bell": {"group": "event", "color": Palette.SAND, "shape": "ring", "sound": "found_chime", "sound_next": "bay_bell_ring", "hud": "", "objective": "", "priority": 1},
	"bay_jukebox": {"group": "event", "color": Palette.AMBER, "shape": "wave", "sound": "ui_tick", "sound_next": "lounge_flip", "hud": "", "objective": "", "priority": 1},
	"bay_marble_note": {"group": "event", "color": Palette.SAND, "shape": "square", "sound": "scrap_tick", "sound_next": "marble_tick_ladder", "hud": "", "objective": "", "priority": 1},
	"bay_pins": {"group": "event", "color": Palette.SAND, "shape": "burst", "sound": "hit_thwack", "sound_next": "pins_crash", "hud": "", "objective": "", "priority": 1},
	"lap_started": {"group": "event", "color": Palette.SAND, "shape": "chevron", "sound": "ui_tick", "sound_next": "lap_start_tick", "hud": "", "objective": "", "priority": 1},
	"lap_checkpoint": {"group": "event", "color": Palette.SAND, "shape": "chevron", "sound": "scrap_tick", "sound_next": "lap_checkpoint_tick", "hud": "", "objective": "", "priority": 1},
	"lap_finished": {"group": "event", "color": Palette.SAND, "shape": "star", "sound": "found_chime", "sound_next": "lap_done_beeps", "hud": "Lap {seconds} s", "objective": "", "priority": 2},
	"steam_lift_fired": {"group": "event", "color": Palette.SAND, "shape": "arrow", "sound": "launch_roar", "sound_next": "return_launch_arpeggio", "hud": "", "objective": "", "priority": 1},
	"breach_opened": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "breach_crack", "sound_next": "plate_crack_rubble_fall", "hud": "", "objective": "", "priority": 1},
	"ledger_returned": {"group": "event", "color": Palette.SAND, "shape": "star", "sound": "found_chime", "hud": "", "objective": "", "priority": 1},
	"arena_locked": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "slam_boom", "sound_next": "arena_lock_slam", "hud": "", "objective": "", "priority": 2},
	"arena_wave": {"group": "event", "color": Palette.HAZARD, "shape": "cross", "sound": "threat_whistle", "sound_next": "arena_wave_whistle", "hud": "", "objective": "", "priority": 2},
	"arena_unlocked": {"group": "event", "color": Palette.SANDSTONE, "shape": "ring", "sound": "found_chime", "sound_next": "arena_unlock_bells", "hud": "", "objective": "", "priority": 2},
	"warden_gate_pip": {"group": "event", "color": Palette.BRASS, "shape": "square", "sound": "found_chime", "sound_next": "warden_gate_pip", "hud": "", "objective": "", "priority": 1},
	"warden_gate_refused": {"group": "event", "color": Palette.HAZARD, "shape": "square", "sound": "clank", "sound_next": "warden_gate_clunk", "hud": "", "objective": "", "priority": 1},
	"warden_gate_opened": {"group": "event", "color": Palette.BRASS, "shape": "burst", "sound": "found_chime", "sound_next": "warden_gate_release", "hud": "", "objective": "", "priority": 2},
	"overtime_offered": {"group": "event", "color": Palette.BRASS, "shape": "ring", "sound": "overtime_offer", "hud": "", "objective": "", "priority": 1},
	"overtime_rung": {"group": "event", "color": Palette.BRASS, "shape": "burst", "sound": "overtime_ring", "hud": "", "objective": "", "priority": 2},
	"overtime_paid": {"group": "event", "color": Palette.BRASS, "shape": "star", "sound": "overtime_pay", "hud": "", "objective": "", "priority": 2},
	"sluice_warning": {"group": "event", "color": Palette.HAZARD, "shape": "arrow", "sound": "threat_whistle", "sound_next": "sluice_valve_warning", "hud": "", "objective": "", "priority": 2},
	"call_window": {"group": "event", "color": Palette.BRASS, "shape": "square", "sound": "found_chime", "sound_next": "warden_gate_pip", "hud": "", "objective": "", "priority": 1},
	"shot_called": {"group": "event", "color": Palette.BRASS, "shape": "square", "sound": "clank", "sound_next": "call_ink", "hud": "", "objective": "", "priority": 2},
	"call_met": {"group": "event", "color": Palette.BRASS, "shape": "star", "sound": "found_chime", "sound_next": "warden_gate_release", "hud": "", "objective": "", "priority": 2},
	"call_missed": {"group": "event", "color": Palette.CHARCOAL, "shape": "square", "sound": "clank", "sound_next": "call_drop", "hud": "", "objective": "", "priority": 1},
	"sluice_open": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "slam_boom", "sound_next": "sluice_valve_open", "hud": "", "objective": "", "priority": 2},
	"kindness_offered": {"group": "event", "color": Palette.KINDNESS, "shape": "ring", "sound": "kindness_chime", "hud": "", "objective": "", "priority": 1},
	"quick_sync": {"group": "event", "color": Palette.BRASS, "shape": "ring", "sound": "quick_sync_horn", "hud": "", "objective": "", "priority": 2},
	"shift_over": {"group": "event", "color": Palette.AMBER, "shape": "burst", "sound": "shift_over_sigh", "hud": "", "objective": "", "priority": 2},
	"site_flip": {"group": "event", "color": Palette.SAND, "shape": "diamond", "sound": "site_flip", "hud": "", "objective": "", "priority": 1},
}


static func world_row(kind: String) -> Dictionary:
	return WORLD_ROWS.get(kind, {})
