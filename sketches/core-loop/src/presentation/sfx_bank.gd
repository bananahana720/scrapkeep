extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")
const PositionalCueRows := preload("res://src/presentation/positional_cue_rows.gd")
const SetDirector := preload("res://src/presentation/set_director.gd")


const RATE := Harmony.RATE

const EVENT_DIR := "res://assets/audio/event_set/"
const EVENT_CUES := [
	"achievement_chime", "armor_shed", "boost_whoosh", "boss_arena_in", "boss_phase", "boss_weak_hit",
	"callout_chime", "crit_ping", "dash_whoosh", "death", "found_chime", "hit_thwack", "hop", "hurt",
	"kill_chain_tier_1", "kill_chain_tier_2", "kill_chain_tier_3", "kill_chain_tier_4", "kill_chain_tier_5",
	"kill_pop", "land_thud", "lore_found", "near_whoosh", "part_get", "pickup_fountain", "pilot_unlocked",
	"rarity_bell_common", "rarity_bell_epic", "rarity_bell_rare", "rescue_fanfare", "scrap_tick_1",
	"scrap_tick_2", "scrap_tick_3", "scrap_tick_4", "scrap_tick_5", "shop_bell", "slam_boom", "smash_crack",
	"stinger_boss_defeated", "stinger_clear", "stinger_milestone", "stinger_run_end", "stinger_run",
	"stinger_stage", "stinger_world", "synergy_fanfare", "threat_whistle", "ui_tick", "verb_fail",
	"weapon_zap", "clank",
]
const TIER_CUES := {
	"scrap_tick": ["scrap_tick_1", "scrap_tick_2", "scrap_tick_3", "scrap_tick_4", "scrap_tick_5"],
	"kill_chain_tier": ["kill_chain_tier_1", "kill_chain_tier_2", "kill_chain_tier_3", "kill_chain_tier_4", "kill_chain_tier_5"],
	"rarity_bell": ["rarity_bell_common", "rarity_bell_rare", "rarity_bell_epic"],
}

const STINGER_BEATS := {
	"stinger_run": 4,
	"stinger_stage": 1,
	"stinger_clear": 8,
	"stinger_run_end": 12,
	"stinger_milestone": 4,
	"gates_open": 4,
	"klaxon": 4,
	"music_pressure": 1,
	"stinger_unseal": 4,
	"class_up": 2,
	"class_down": 2,
	"threat_up": 1,
	"synergy_fanfare": 4,
	"warden_theme_in": 4,
	"boss_arena_in": 4,
	"boss_phase": 2,
	"hype_drop": 7,
	"stinger_boss_defeated": 8,
	"build_riser": 8,
	"stinger_world": 2,
	"stinger_world_down5": 2,
	"stinger_world_up5": 2,
}

const WORLD_STINGER := "stinger_world"
const WORLD_STEPS := [0, -5, 5]

const VOICE_LIMIT := MixRows.VOICE_LIMIT
const MIN_GAP_MS := MixRows.MIN_GAP_MS
const DANGER_SOUNDS := ["hurt", "enemy_arrive", "boss_telegraph", "ratchet_cue", "klaxon", "threat_up", "death",
	"threat_tick", "threat_whoosh", "threat_whistle", "threat_hum", "threat_tear", "hold_pit", "hold_bola", "hold_tether", "hold_net", "heat_kettle",
	"warn_burrow", "warn_bore", "warn_lure", "warn_cut", "warn_winch", "warn_dive", "warn_tether", "warn_flap", "warn_reel",
	"jolt_layer_tell", "flank_call", "boil_rumble", "reactor_tick",
	"prop_crew_strain", "cave_in_rumble", "arena_wave_whistle",
	"tele_crane_sweep", "tele_slag_ring", "tele_charge", "tele_charge_wall", "tele_eject",
	"flood_falling_pure", "fleet_falling_pure", "boiler_falling_pure", "lightning_falling_pure", "ancient_falling_pure",
	"rock_grind_dust_hiss",
	"sluice_valve_warning"]
const KEYED_SOUNDS := ["panel_note", "panel_jackpot", "line_claw_drag", "armor_reclaim", "scrap_tick", "cog_tick", "part_get", "core_socket", "found_chime", "gate_through",
	"rivet_line_punch", "rivet_line_arrive",
	"grapple_clink", "grapple_release", "pylon_plant", "beacon_hum", 
	"enemy_arrive", "element_resolved", "ice_form", "vault_rise", "synergy_hit",
	"sable_arpeggio", "rivet_hihat_roll", "kest_low_thump", "tarn_latch_tear", "tally_balance_due", "cannon_recall", "sable_ready", "rivet_ready", "kest_ready", "tarn_ready", "tally_ready", "cannon_ready",
	"sable_break", "rivet_break", "kest_break", "tarn_break", "tally_break", "cannon_break", "fleet_motif", "reactor_erupt", "swarm_buzz", "swarm_lock",
	"swarm_scatter", "mind_sable", "mind_rivet", "mind_kest", "mind_tarn", "mind_tally", "mind_cannon", "hold_pit", "hold_bola", "hold_tether", "hold_net",
	"hold_riser", "callout_chime", "shop_bell", "rarity_tick", "rarity_bell", "rung_coil", "reveal_clank", "ceremony_build",
	"ceremony_resolve", "line_bite", "smash_crack", "achievement_chime", "rescue_fanfare",
	"bet_clunk", "bet_crack", "bet_refusal", "sunken_bell", "ally_hum_sable", "ally_hum_rivet", "ally_hum_kest",
	"ally_wake", "fight_arm_stamp", "near_miss_whip_sable", "near_miss_whip_rivet", "near_miss_whip_kest",
	"drop_landing", "return_launch_arpeggio", "crater_hold", "shell_spring",
	"core_slam", "ultimate_land", "kest_demo_knock", "rivet_skid_plate",
	"active_cutting_torch",
	"sluice_siren_two_tone", "ride_cable_clink", "steam_whistle_rise",
	"lounge_flip", "bay_bell_ring", "marble_tick_ladder", "bay_lounge_in", "menu_move", "menu_confirm", "menu_back",
	"ultimate_ready", "found_twinkle", "beacon_open_chime", "callout_warden_chime",
	"flood_falling_pure", "fleet_falling_pure", "boiler_falling_pure", "lightning_falling_pure", "ancient_falling_pure",
	"fleet_anvil_brass_drop", "steam_whistle_percussion_drop", "ancient_family_drop", "companion_chirp_escape",
	"kest_falling_triad", "kest_muffled_thump", "line_load", "motif_accumulate", "motif_line", "motif_stinger",
	"pin_double_thwack", "rebound_spring_snap", "sable_root_fifth", "rivet_snare_flam",
	"motif_accumulate_sable", "motif_accumulate_rivet", "motif_accumulate_kest", "motif_accumulate_tarn", "motif_accumulate_tally", "motif_accumulate_cannon",
	"motif_line_sable", "motif_line_rivet", "motif_line_kest", "motif_line_tarn", "motif_line_tally", "motif_line_cannon",
	"motif_stinger_sable", "motif_stinger_rivet", "motif_stinger_kest", "motif_stinger_tarn", "motif_stinger_tally", "motif_stinger_cannon",
	"plate_tally", "clip_tally", "stroke_tally", "settle_tally",
	"kindness_chime", "sluice_valve_warning", "quick_sync_horn",
	"cadence_tarn_window", "cadence_cannon_lock", "site_flip",
]
const KEST_SOUNDS := ["cable_kest_fizz", "cable_kest_set", "cable_kest_blast", "raid_kest_tick",
	"tick_kest_62", "tick_kest_57", "tick_kest_53", "raid_kest_stinger", "raid_kest_boom", "raid_kest_roll"]

const TRIM_DB := {
	"ui_tick": -8.0, "hop": -10.0, "boost_whoosh": -6.0, "dash_whoosh": -5.0, "carve_release": -8.0,
	"land_thud": -6.0, "slam_boom": -1.0, "grapple_clink": -7.0, "grapple_release": -11.0,
	"core_slam": -1.0, "ultimate_land": -1.0, "kest_demo_knock": -4.0, "rivet_skid_plate": -4.0,
	"grown_sub": -4.0, "grown_crack": -7.0, "grown_tail": -10.0, "grown_rattle": -11.0,
	"pylon_plant": -3.0, "pylon_eject": -4.0, "enemy_arrive": -9.0, "hit_thwack": -1.0,
	"weapon_zap": -9.0, "special_fire": -4.0, "kill_pop": -5.0, "hurt": -3.0,
	"death": 0.0, "scrap_tick": -10.0, "cog_tick": -10.0, "part_get": -3.0, "beacon_hum": -12.0,
	"gate_through": -3.0, "launch_roar": -2.0, "event_start": -3.0, "event_end": -6.0,
	"klaxon": -3.0, "stinger_run": -3.0, "stinger_stage": -4.0, "stinger_clear": -2.0,
	"stinger_run_end": -2.0, "stinger_milestone": -2.0, "gates_open": -4.0,
	"music_pressure": -9.0,
	"stinger_unseal": -3.0, "class_up": -3.0, "clank": -6.0, "scrap_rip": -4.0, "threat_up": -6.0,
	"core_socket": -3.0, "synergy_fanfare": 0.0, "found_chime": -6.0, "achievement_chime": -6.0, "rescue_fanfare": -3.0, "element_resolved": -8.0,
	"ice_form": -7.0, "zap_hum": -8.0, "shatter": -5.0, "warden_theme_in": -6.0, "class_down": -6.0,
	"boss_arena_in": -3.0, "boss_phase": -4.0, "boss_telegraph": -4.0, "ratchet_cue": -4.0, "boss_weak_hit": -7.0,
	"stinger_boss_defeated": -1.0,
	"womp": -8.0, "build_riser": -4.0, "stage_fade": -12.0,
	"vault_rise": -6.0, "vault_drop": -2.0, "synergy_hit": -10.0,
	"slow_dip": -9.0, "slow_rise": -9.0,
	"threat_tick": -7.0, "threat_whoosh": -6.0, "threat_whistle": -8.0, "threat_hum": -7.0, "threat_tear": -7.0,
	"warn_burrow": -7.0, "warn_bore": -7.0, "warn_lure": -7.0,
	"warn_cut": -7.0, "warn_winch": -7.0, "warn_dive": -7.0,
	"warn_tether": -7.0, "warn_flap": -7.0, "warn_reel": -7.0,
	"flank_call": -6.0, "boil_rumble": -5.0,
	"breach_crack": -4.0,
	"sable_arpeggio": -3.0, "rivet_hihat_roll": -3.0, "kest_low_thump": -2.0, "tarn_latch_tear": -3.0, "tally_balance_due": -3.0, "cannon_recall": -3.0,
	"sable_ready": -5.0, "rivet_ready": -5.0, "kest_ready": -4.0, "tarn_ready": -5.0, "tally_ready": -5.0, "cannon_ready": -5.0,
	"sable_break": -3.0, "rivet_break": -3.0, "kest_break": -3.0, "tarn_break": -3.0, "tally_break": -3.0, "cannon_break": -3.0,
	"fleet_motif": -4.0, "reactor_tick": -6.0, "reactor_erupt": -2.0, "swarm_buzz": -9.0, "swarm_lock": -6.0, "swarm_scatter": -8.0,
	"mind_sable": -5.0, "mind_rivet": -5.0, "mind_kest": -5.0, "mind_tarn": -5.0, "mind_tally": -5.0, "mind_cannon": -5.0,
	"fleet_anvil": -3.0, "boiler_burst": -3.0,
	"mind_wrong_sable": -5.0, "mind_wrong_rivet": -5.0, "mind_wrong_kest": -5.0, "mind_wrong_tarn": -5.0, "mind_wrong_tally": -5.0, "mind_wrong_cannon": -5.0,
	"active_glass_lance": -7.0,
	"hold_pit": -13.0, "hold_bola": -14.5, "hold_tether": -13.0, "hold_net": -9.0, "hold_riser": -9.0, "tenacity_choke": -4.0,
	"callout_chime": -8.0, "shop_bell": -6.0, "bench_clank": -7.0,
	"near_whoosh": -6.0, "crit_ping": -5.0, "kest_kick_thump": 0.0,
	"rarity_tick": -9.0, "rarity_bell": -5.0, "reveal_clank": -4.0, "ceremony_build": -3.0, "ceremony_resolve": -1.0,
	"rung_coil": -9.0,
	"panel_ratchet": -9.0, "panel_note": -8.0, "panel_jackpot": -5.0, "panel_cache": -16.0,
	"bet_roll": -7.0, "bet_clunk": -4.0, "bet_crack": -2.0, "bet_refusal": -6.0,
	"sunken_bell": -6.0, "ally_hum_sable": -14.0, "ally_hum_rivet": -14.0, "ally_hum_kest": -14.0,
	"ally_wake": -6.0, "fight_arm_stamp": -4.0,
	"near_miss_whip_sable": -6.0, "near_miss_whip_rivet": -6.0, "near_miss_whip_kest": -6.0,
	"near_miss_whip_tarn": -6.0, "near_miss_whip_tally": -6.0, "near_miss_whip_cannon": -6.0,
	"pickup_fountain": -8.0, "synergy_fired": -6.0, "evolution_fired": -5.0, "lore_found": -10.0,
	"pilot_unlocked": -9.0, "pilot_unlocked_sable": -9.0, "pilot_unlocked_rivet": -9.0, "pilot_unlocked_kest": -9.0,
	"pilot_unlocked_tarn": -9.0, "pilot_unlocked_tally": -9.0, "pilot_unlocked_cannon": -9.0,
	"kill_chain_tier": 0.0, "chain_crash": -12.0, "drop_landing": -3.0, "door_tick": -9.0,
	"return_launch_arpeggio": -4.0, "lift_hiss": -9.0, "crater_hold": -12.0,
	"arena_lock_slam": -2.0, "arena_wave_whistle": -6.0, "arena_unlock_bells": -4.0, "warden_gate_pip": -7.0,
	"warden_gate_clunk": -10.0, "warden_gate_release": -3.0,
	"call_ink": -6.0, "call_drop": -8.0, "heat_kettle": -9.0,
	"overtime_offer": -8.0, "overtime_ring": -5.0, "overtime_pay": -6.0,
	"heat_rise": -8.0, "heat_cool": -10.0, "heat_hot_hit": -6.0,
	"tele_crane_sweep": -4.0, "tele_slag_ring": -4.0, "tele_charge": -4.0, "tele_charge_wall": -4.0, "tele_eject": -4.0,
	"sluice_siren_two_tone": -6.0, "ride_rolling_metal": -9.0, "ride_bowl_carve": -9.0, "ride_drop_swoop": -8.0,
	"ride_ledge_scuff": -10.0, "ride_hop_lift": -10.0, "ride_cable_clink": -9.0, "ride_sheet_swell": -9.0,
	"steam_whistle_rise": -8.0, "cannon_bang_rail_whoosh": -3.0, "sluice_gush_roar": -5.0,
	"lounge_flip": -7.0, "bay_bell_ring": -6.0, "marble_tick_ladder": -10.0, "pins_crash": -5.0, "bay_lounge_in": -8.0,
	"bay_slingshot_out": -7.0, "menu_move": -13.0, "menu_confirm": -10.0, "menu_back": -10.0, "ultimate_ready": -5.0,
	"found_twinkle": -8.0, "verb_fail": -9.0, "gauge_dry_click": -10.0,
	"drop_thud": -7.0, "drop_whiff": -11.0, "guard_creak": -6.0, "beacon_open_chime": -9.0, "callout_warden_chime": -8.0,
	"flood_falling_pure": -8.0, "fleet_falling_pure": -8.0, "boiler_falling_pure": -8.0, "lightning_falling_pure": -8.0,
	"ancient_falling_pure": -8.0, "rock_grind_dust_hiss": -7.0,
	"flood_drop": -3.0, "fleet_anvil_brass_drop": -3.0, "lightning_strike": -4.0, "rockfall_boom": -3.0,
	"crater_crump_sub_boom": -3.0, "steam_whistle_percussion_drop": -3.0, "ancient_family_drop": -3.0,
	"cracked_wall_crumble": -5.0, "kest_snare_crack": -5.0, "companion_chirp_escape": -9.0, "kest_blast_lift": -6.0,
	"kest_falling_triad": -4.0, "kest_muffled_thump": -12.0, "line_load": -22.0, "motif_accumulate": -12.0,
	"motif_line": -7.0, "motif_stinger": -4.0, "pin_double_thwack": -3.0, "rebound_spring_snap": -9.0,
	"rivet_cymbal_choke": -4.0, "rivet_snare_flam": -4.0, "sable_root_fifth": -8.0,
	"armor_shed_small": -6.0, "armor_shed": -5.0, "armor_shed_big": -4.0, "armor_reclaim": -7.0,
	"armor_deflect": -10.0,
	"wear_sputter": -14.0,
	"shell_spring": -9.0,
	"companion_chirp_ready": -8.0, "companion_chirp_spent": -9.0,
	"lock_tick": -22.0, "dry_tick": -25.0, "line_bite": -7.0, "anchor_clunk": -12.0, "smash_whistle": -9.0, "smash_crack": -3.0,
	"seal_ratchet": -16.0,
	"dock_click": -15.0, "line_zip": -10.0, "line_twang": -9.0, "line_hum": -17.0, "find_drip": -14.0, "find_radio": -12.0,
	"verb_fail_jump": -18.0, "verb_fail_fire": -18.0, "verb_fail_haul": -18.0, "verb_fail_boost": -18.0,
	"verb_fail_special": -18.0, "verb_fail_interact": -18.0,
	"verb_fail_select": -18.0, "verb_fail_ultimate": -18.0, "verb_fail_active": -18.0,
	"verb_fail_roll": -18.0,
	"active_scrap_rocket": -8.0,
	"active_cutting_torch": -10.0, "active_cutting_torch_heat": -14.0,
	"active_silo_battery": -6.0,
	"active_quake_knock": -7.0,
	"active_lift_pulse": -7.0,
	"cable_kest_fizz": -12.0, "cable_kest_set": -9.0, "cable_kest_blast": -3.0,
	"raid_kest_tick": -12.0, "tick_kest_62": -12.0, "tick_kest_57": -12.0, "tick_kest_53": -12.0,
	"raid_kest_stinger": -3.0, "raid_kest_boom": -2.0, "raid_kest_roll": -9.0,
	"plate_tally": CAUSE_NOTE_DB, "clip_tally": CAUSE_NOTE_DB,
	"stroke_tally": CAUSE_NOTE_DB, "settle_tally": CAUSE_NOTE_DB,
	"chunk_low": -2.0,
	"foreman_presence": PositionalCueRows.ROWS["foreman_presence"]["db"],
	"foreman_tell": -4.0, "foreman_break": -3.0, "foreman_spawn": -6.0,
	"dispatcher_presence": PositionalCueRows.ROWS["dispatcher_presence"]["db"],
	"dispatcher_tell": -4.0, "dispatcher_break": -3.0, "dispatcher_spawn": -6.0,
	"splitter_presence": PositionalCueRows.ROWS["splitter_presence"]["db"],
	"splitter_tell": -4.0, "splitter_break_split": -3.0, "splitter_break_clean": -3.0,
	"splitter_spawn": -6.0,
	"linker_presence": PositionalCueRows.ROWS["linker_presence"]["db"],
	"linker_tell": -4.0, "linker_break": -3.0, "linker_spawn": -6.0,
	"hype_drop": -3.0,
	"jolt_layer_presence": PositionalCueRows.ROWS["jolt_layer_presence"]["db"],
	"jolt_layer_tell": PositionalCueRows.ROWS["jolt_layer_tell"]["db"],
	"jolt_layer_jam": PositionalCueRows.ROWS["jolt_layer_jam"]["db"],
	"jolt_layer_fizzle": PositionalCueRows.ROWS["jolt_layer_fizzle"]["db"],
	"jolt_layer_break": PositionalCueRows.ROWS["jolt_layer_break"]["db"],
	"music_layer_crown_hoodoos": -8.0, "music_layer_crown_alcove": -8.0, "music_layer_crown_toppled": -8.0,
	"music_layer_crown_ramp": -8.0,
	"music_layer_mind_quote_spillway": -8.0,
	"lift_cage_arrive": PositionalCueRows.ROWS["lift_cage_arrive"]["db"],
	"zipline_whine": PositionalCueRows.ROWS["zipline_whine"]["db"],
	"zipline_snap": PositionalCueRows.ROWS["zipline_snap"]["db"],
	"cave_in_rumble": PositionalCueRows.ROWS["cave_in_rumble"]["db"],
	"cave_in_debris": PositionalCueRows.ROWS["cave_in_debris"]["db"],
	"prop_crew_presence": PositionalCueRows.ROWS["prop_crew_presence"]["db"],
	"prop_crew_strain": PositionalCueRows.ROWS["prop_crew_strain"]["db"],
	"prop_crew_collapse": PositionalCueRows.ROWS["prop_crew_collapse"]["db"],
	"destructible_wood": -7.0, "destructible_scrap": -6.0, "destructible_masonry": -4.0, "destructible_steel": -5.0,
	"ballast_brace_tell": -4.0, "ballast_brace_slam": -2.0, "gap_net_charge_tell": -6.0, "gap_net_charge_live": -4.0,
	"ring_out_fall": -8.0,
	"stinger_world": -5.0, "stinger_world_down5": -5.0, "stinger_world_up5": -5.0,
	"kindness_chime": -6.0, "sluice_valve_warning": -8.0, "sluice_valve_open": -3.0,
	"quick_sync_horn": -5.0, "shift_over_sigh": -5.0,
	"cadence_rivet_notch_open": -11.0, "cadence_rivet_notch_hit": -6.0, "cadence_rivet_spent": -11.0,
	"cadence_sable_full": -8.0, "cadence_sable_bolt": -5.0,
	"cadence_kest_window": -9.0, "cadence_kest_snap": -4.0,
	"cadence_tarn_window": -8.0, "cadence_tarn_rend": -4.0,
	"cadence_tally_beat": -10.0, "cadence_tally_paid": -5.0,
	"cadence_cannon_lock": -7.0, "cadence_cannon_rail": -4.0, "cadence_cannon_barrage": -5.0,
	"rail_rise": -10.0, "rail_sink": -11.0,
	"site_flip": -7.0,
}
const BREAK_PHRASES := [
	{"notes": ["D4", "F4", "A4", "D5"], "gaps": [0.16, 0.16, 0.16], "chord_gap": 0.3},
	{"notes": ["D4", "G4", "C5", "F5"], "gaps": [0.2, 0.2, 0.2], "chord_gap": 0.3},
	{"notes": ["D4", "F4", "G4", "A4"], "gaps": [0.26, 0.17, 0.11], "chord_gap": 0.42},
]
const CAUSE_NOTE := "cause_note_"
const GRID_NOTE := "grid_note_"
const GRID_NOTE_DB := -8.0
const GRID_NOTE_SECONDS := 0.5
const GRID_UNDER_DB := -3.0
const PILOT_QUOTE := "pilot_quote_"
const PILOT_QUOTE_DB := -6.0
const PILOT_QUOTE_FLOOR := 69
const SET_ANSWER := "set_answer_"
const SET_ANSWER_DB := -8.0
const DEATH_FALL_DB := -6.0
const KILL_POP_MIDI := 86
const BITE_MIDI := 81
const WHIP_SECOND := {"tarn": 2}
const CAUSE_NOTE_DB := -8.0

const ASSIST_STING := "companion_assist_"
const ASSIST_MOVES := ["bonk", "arc", "pile", "slip", "anvil", "static", "bulldozer"]
const ASSIST_STING_DB := -7.0

static var _samples := {}
static var _lock := Mutex.new()
const THEMED := ["synergy_fanfare"]
static var _streams := {}
const RENDERED_DIR := "res://assets/audio/sfx/"
static var _rendered := {}
static var _cache_lock := Mutex.new()
static var bake_cancel := false

var _step := Harmony.STEP
var _shift := 0
var _theme := 0


func _init(step := Harmony.STEP, shift := 0, theme := 0) -> void:
	_step = step
	_shift = shift
	_theme = theme


static func reset_for_tests() -> void:
	bake_cancel = false


static func break_midis(variant := 0) -> Array:
	var midis: Array = []
	for note in BREAK_PHRASES[variant]["notes"]:
		midis.append(Harmony.note_midi(String(note)))
	return midis


static func has_recipe(id: String) -> bool:
	return (TRIM_DB.has(id) or id.begins_with(CAUSE_NOTE) or id.begins_with(GRID_NOTE) or id.begins_with(PILOT_QUOTE)
		or (id.begins_with(SET_ANSWER) and SetDirector.has_answer(id.trim_prefix(SET_ANSWER)))
		or _assist_parts(id).size() > 0 or id in EVENT_CUES or _motif_cue_parts(id).size() > 0)


static func plays_own(id: String) -> bool:
	if FILE_SOUNDS.has(id) or id.begins_with(STINGER_PREFIX):
		return file_exists(id)
	return has_recipe(id)


static func trim_db(id: String) -> float:
	if id.begins_with(CAUSE_NOTE):
		return CAUSE_NOTE_DB
	if id.begins_with(GRID_NOTE):
		return GRID_NOTE_DB
	if id.begins_with(PILOT_QUOTE):
		return PILOT_QUOTE_DB
	if id.begins_with(SET_ANSWER):
		return SET_ANSWER_DB
	if id.begins_with(ASSIST_STING):
		return ASSIST_STING_DB
	var motif_cue := _motif_cue_parts(id)
	if not motif_cue.is_empty():
		return float(TRIM_DB[motif_cue[0]])
	return TRIM_DB.get(id, TRIM_DB.get(base_key(id), -8.0))


static func base_key(id: String) -> String:
	for base in TIER_CUES:
		if id in TIER_CUES[base]:
			return base
	return id


static func event_path(id: String) -> String:
	return EVENT_DIR + id + ".wav"


static func resolve(sound: String, pitch: float) -> Dictionary:
	if not TIER_CUES.has(sound) or pitch <= 0.0:
		return {"id": sound, "pitch": pitch}
	var files: Array = TIER_CUES[sound]
	var rung := ladder_rung(pitch)
	var index := clampi(rung, 0, files.size() - 1)
	if sound == "rarity_bell":
		index = 0 if rung <= 0 else (1 if rung < 5 else 2)
	if not _has_file(files[index]):
		return {"id": sound, "pitch": pitch}
	return {"id": files[index], "pitch": 1.0}


static var _file_present := {}


static func _has_file(id: String) -> bool:
	if not _cache_has(_file_present, id):
		_cache_put(_file_present, id, ResourceLoader.exists(event_path(id)))
	return _cache_get(_file_present, id)


static func _cache_has(cache: Dictionary, key: String) -> bool:
	_cache_lock.lock()
	var hit := cache.has(key)
	_cache_lock.unlock()
	return hit


static func _cache_get(cache: Dictionary, key: String) -> Variant:
	_cache_lock.lock()
	var value = cache.get(key)
	_cache_lock.unlock()
	return value


static func _cache_put(cache: Dictionary, key: String, value: Variant) -> Variant:
	_cache_lock.lock()
	if not cache.has(key):
		cache[key] = value
	var held = cache[key]
	_cache_lock.unlock()
	return held


static func ladder_rung(pitch: float) -> int:
	var steps := 12.0 * log(maxf(pitch, 0.001)) / log(2.0)
	var best := 0
	for rung in range(0, 12):
		if absf(float(Harmony.pentatonic_step(rung)) - steps) < absf(float(Harmony.pentatonic_step(best)) - steps):
			best = rung
	return best


static func _event_samples(id: String, shift := 0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var path := event_path(id)
	if not ResourceLoader.exists(path):
		return out
	var wav := ResourceLoader.load(path, "AudioStreamWAV", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamWAV
	if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS or wav.stereo:
		return out
	var data := wav.data
	var count := data.size() / 2
	var step := float(wav.mix_rate) / float(RATE) * pow(2.0, float(shift) / 12.0)
	var length := int(floor(float(count - 1) / step)) + 1
	out.resize(length)
	for i in length:
		var at := float(i) * step
		var lo := int(at)
		var hi := mini(lo + 1, count - 1)
		var a := data.decode_s16(lo * 2) / 32768.0
		var b := data.decode_s16(hi * 2) / 32768.0
		out[i] = lerpf(a, b, at - lo)
	return out


static func world_stinger(world: int) -> String:
	var step: int = WORLD_STEPS[clampi(world, 1, WORLD_STEPS.size()) - 1]
	if step == 0:
		return WORLD_STINGER
	return "%s_%s%d" % [WORLD_STINGER, "up" if step > 0 else "down", absi(step)]


static func assist_sting_id(move: String, heft_class: int, motif := "") -> String:
	if not move in ASSIST_MOVES:
		return ""
	var tier := 1 if heft_class <= 2 else (2 if heft_class <= 4 else 3)
	var id := "%s%s_t%d" % [ASSIST_STING, move, tier]
	return id + "_" + (motif if Harmony.MOTIFS.has(motif) else Harmony.CLASS_MOTIFS[0]) if tier == 3 else id


static func _assist_parts(id: String) -> Array:
	if not id.begins_with(ASSIST_STING):
		return []
	var bits := id.trim_prefix(ASSIST_STING).split("_")
	if bits.size() < 2 or not bits[0] in ASSIST_MOVES or not bits[1] in ["t1", "t2", "t3"]:
		return []
	var tier := int(bits[1].substr(1))
	var motif := bits[2] if bits.size() > 2 else ""
	if (tier == 3) != (motif != "") or (motif != "" and not Harmony.MOTIFS.has(motif)):
		return []
	return [bits[0], tier, motif]


static func cause_note_id(midi: int) -> String:
	return CAUSE_NOTE + str(midi)


static func grid_note_id(voice: String, midi: int) -> String:
	return "%s%s_%d" % [GRID_NOTE, voice, midi]


static func pilot_quote_id(class_id: String) -> String:
	return PILOT_QUOTE + class_id


static func pilot_quote_score(class_id: String) -> Array:
	var cells: Array = Harmony.motif_or_first(class_id)["cells"]
	var top := 0
	for cell in cells:
		top = maxi(top, int(cell[1]))
	var octave := 12 if top < PILOT_QUOTE_FLOOR else 0
	var score: Array = []
	for cell in cells:
		score.append([2 * int(cell[0]), int(cell[1]) + octave, 2 * int(cell[2]), "lead", 0.8])
	if score.is_empty():
		return score
	var last: Array = score.back()
	score.append([last[0], int(last[1]) - 12, last[2], "brass", 0.45])
	score.append([last[0], 0, 1, "kick", 0.6])
	return score


static func whip_notes(class_id: String) -> Array:
	var row := Harmony.motif_or_first(class_id)
	var cells: Array = row["cells"]
	return [String(row["voice"]), int(cells[0][1]) + 12, int(cells[WHIP_SECOND.get(class_id, 1)][1]) + 12]


const SFX_DIR := PositionalCueRows.DIR
const SPECIALS := ["foreman", "dispatcher", "splitter", "linker"]
const FILE_SOUNDS := {
	"foreman_presence": PositionalCueRows.ROWS["foreman_presence"]["file"],
	"foreman_tell": "specials/foreman_tell.wav",
	"foreman_break": "specials/foreman_break.wav", "foreman_spawn": "specials/foreman_spawn.wav",
	"dispatcher_presence": PositionalCueRows.ROWS["dispatcher_presence"]["file"],
	"dispatcher_tell": "specials/dispatcher_tell.wav",
	"dispatcher_break": "specials/dispatcher_break.wav", "dispatcher_spawn": "specials/dispatcher_spawn.wav",
	"splitter_presence": PositionalCueRows.ROWS["splitter_presence"]["file"],
	"splitter_tell": "specials/splitter_tell.wav",
	"splitter_break_split": "specials/splitter_break_split.wav", "splitter_break_clean": "specials/splitter_break_clean.wav",
	"splitter_spawn": "specials/splitter_spawn.wav",
	"linker_presence": PositionalCueRows.ROWS["linker_presence"]["file"],
	"linker_tell": "specials/linker_tell.wav",
	"linker_break": "specials/linker_break.wav", "linker_spawn": "specials/linker_spawn.wav",
	"hype_drop": "hype_drop.wav",
	"jolt_layer_presence": PositionalCueRows.ROWS["jolt_layer_presence"]["file"],
	"jolt_layer_tell": PositionalCueRows.ROWS["jolt_layer_tell"]["file"],
	"jolt_layer_jam": PositionalCueRows.ROWS["jolt_layer_jam"]["file"],
	"jolt_layer_fizzle": PositionalCueRows.ROWS["jolt_layer_fizzle"]["file"],
	"jolt_layer_break": PositionalCueRows.ROWS["jolt_layer_break"]["file"],
	"music_layer_crown_hoodoos": "layers/music_layer_crown_hoodoos.wav", "music_layer_crown_alcove": "layers/music_layer_crown_alcove.wav",
	"music_layer_crown_toppled": "layers/music_layer_crown_toppled.wav", "music_layer_crown_ramp": "layers/music_layer_crown_ramp.wav",
	"music_layer_mind_quote_spillway": "layers/music_layer_mind_quote_spillway.wav",
	"lift_cage_arrive": PositionalCueRows.ROWS["lift_cage_arrive"]["file"],
	"zipline_whine": PositionalCueRows.ROWS["zipline_whine"]["file"],
	"zipline_snap": PositionalCueRows.ROWS["zipline_snap"]["file"],
	"cave_in_rumble": PositionalCueRows.ROWS["cave_in_rumble"]["file"],
	"cave_in_debris": PositionalCueRows.ROWS["cave_in_debris"]["file"],
	"prop_crew_presence": PositionalCueRows.ROWS["prop_crew_presence"]["file"],
	"prop_crew_strain": PositionalCueRows.ROWS["prop_crew_strain"]["file"],
	"prop_crew_collapse": PositionalCueRows.ROWS["prop_crew_collapse"]["file"],
	"ballast_brace_tell": "foley/ballast_brace_tell.wav", "ballast_brace_slam": "foley/ballast_brace_slam.wav",
	"gap_net_charge_tell": "foley/gap_net_charge_tell.wav", "gap_net_charge_live": "foley/gap_net_charge_live.wav",
	"ring_out_fall": "foley/ring_out_fall.wav",
}
const HYPE_DROP_LEAD_SECONDS := 2.0


const STINGER_PREFIX := "stinger:"


static func stinger_id(zone: String, cue: String) -> String:
	return "%s%s/%s" % [STINGER_PREFIX, zone.replace("-", "_"), cue]


static func file_path(id: String) -> String:
	if id.begins_with(STINGER_PREFIX):
		return SFX_DIR + "stingers/" + id.substr(STINGER_PREFIX.length()) + ".wav"
	return SFX_DIR + String(FILE_SOUNDS[id])


static func file_exists(id: String) -> bool:
	var path := file_path(id)
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


# Headless Godot runs without an import cache, falling back to raw 16-bit RIFF.
static func file_samples(id: String, shift := 0) -> PackedFloat32Array:
	if not FILE_SOUNDS.has(id) and not id.begins_with(STINGER_PREFIX):
		return _event_samples(id, shift)
	var path := file_path(id)
	var out := PackedFloat32Array()
	# Uncached on worker: Godot cached loads on a worker leave resources alive at exit.
	var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) if ResourceLoader.exists(path) else null
	if res is AudioStreamWAV and (res as AudioStreamWAV).format == AudioStreamWAV.FORMAT_16_BITS:
		return _pcm16(res.data, res.stereo)
	var bytes := FileAccess.get_file_as_bytes(path)
	var at := 12
	while at + 8 <= bytes.size():
		var size := bytes.decode_u32(at + 4)
		if bytes.slice(at, at + 4).get_string_from_ascii() == "data":
			return _pcm16(bytes.slice(at + 8, at + 8 + size), false)
		at += 8 + size + (size & 1)
	return out


static func _pcm16(data: PackedByteArray, stereo: bool) -> PackedFloat32Array:
	var frames := data.size() / (4 if stereo else 2)
	var out := PackedFloat32Array()
	out.resize(frames)
	for i in frames:
		if stereo:
			out[i] = (data.decode_s16(i * 4) + data.decode_s16(i * 4 + 2)) / 65536.0
		else:
			out[i] = data.decode_s16(i * 2) / 32768.0
	return out


const LOOPED := ["line_hum", "panel_cache", "find_drip", "find_radio",
	"foreman_presence", "dispatcher_presence", "splitter_presence", "linker_presence"]

static func loop_stream(id: String) -> AudioStreamWAV:
	assert(id in LOOPED, "a looped sound must be listed in SfxBank.LOOPED: " + id)
	var key := id + "@loop"
	if _cache_has(_streams, key):
		return _cache_get(_streams, key)
	var wav := stream(id).duplicate() as AudioStreamWAV
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = wav.data.size() / 2
	return _cache_put(_streams, key, wav)


static func hum_stream() -> AudioStreamWAV:
	if _cache_has(_streams, "line_hum"):
		return _cache_get(_streams, "line_hum")
	var wav := Synth.to_wav(samples("line_hum"))
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = wav.data.size() / 2
	return _cache_put(_streams, "line_hum", wav)


static func samples(id: String) -> PackedFloat32Array:
	if _cache_has(_samples, id):
		return _cache_get(_samples, id)
	_lock.lock()
	var buf: PackedFloat32Array = _cache_get(_samples, id) if _cache_has(_samples, id) else _cache_put(_samples, id, Synth.normalize(new()._bake(id), 0.9))
	_lock.unlock()
	return buf


static func samples_at(id: String, step: int, shift := 0, theme := 0) -> PackedFloat32Array:
	if _plain(id, step, shift, theme):
		return samples(id)
	var key := _key_at(id, step, shift, theme)
	if _cache_has(_samples, key):
		return _cache_get(_samples, key)
	_lock.lock()
	if not _cache_has(_samples, key) and id in EVENT_CUES and not FILE_SOUNDS.has(id) and not id.begins_with(STINGER_PREFIX):
		var shared := "%s@file@%d" % [id, shift]
		if not _cache_has(_samples, shared):
			var recorded := file_samples(id, shift)
			if not recorded.is_empty():
				_cache_put(_samples, shared, Synth.normalize(recorded, 0.9))
		if _cache_has(_samples, shared):
			_cache_put(_samples, key, _cache_get(_samples, shared))
	if not _cache_has(_samples, key):
		_cache_put(_samples, key, Synth.normalize(new(step if _gridded(id) else Harmony.STEP, shift, theme)._bake(id), 0.9))
	_lock.unlock()
	return _cache_get(_samples, key)


static func cached_at(id: String, step: int, shift := 0, theme := 0) -> bool:
	return _cache_has(_samples, id if _plain(id, step, shift, theme) else _key_at(id, step, shift, theme))


static func _plain(id: String, step: int, shift: int, theme: int) -> bool:
	return (step == Harmony.STEP or not _gridded(id)) and shift == 0 and (not id in THEMED or theme == 0)


static func _key_at(id: String, step: int, shift: int, theme: int) -> String:
	return "%s@%d@%d@%d" % [id, step if _gridded(id) else Harmony.STEP, shift, theme if id in THEMED else 0]


static func _gridded(id: String) -> bool:
	return STINGER_BEATS.has(id) or id.begins_with(PILOT_QUOTE) or id.begins_with(SET_ANSWER)


func _hz(midi: float) -> float:
	return Harmony.hz(midi + _shift)


func _n(instrument: String, midi: int) -> PackedFloat32Array:
	return Synth.note(instrument, midi + _shift)


func _score(score: Array, tail_seconds := 1.0) -> PackedFloat32Array:
	return Synth.render_score(score, tail_seconds, _step, _shift)


static func stream(id: String) -> AudioStreamWAV:
	if id == "line_hum":
		return hum_stream()
	if _cache_has(_streams, id):
		return _cache_get(_streams, id)
	return _cache_put(_streams, id, Synth.to_wav(samples(id)))


static func rendered(id: String) -> AudioStream:
	if _cache_has(_rendered, id):
		return _cache_get(_rendered, id)
	var path := RENDERED_DIR + id + ".wav"
	return _cache_put(_rendered, id, load(path) if ResourceLoader.exists(path) else null)


static func file_backed(id: String) -> bool:
	return id in EVENT_CUES or FILE_SOUNDS.has(id) or id.begins_with(STINGER_PREFIX)


static func bake_all(ids: Array) -> void:
	for id in ids:
		if bake_cancel:
			return
		stream(id)
	for id in STINGER_BEATS:
		if bake_cancel:
			return
		samples_at(id, Harmony.BOSS_STEP)


func _bake(id: String) -> PackedFloat32Array:
	if FILE_SOUNDS.has(id) or id.begins_with(STINGER_PREFIX):
		var file := file_samples(id)
		if file.size() > 0:
			return file
		return _tone(0.12, _hz(62), _hz(62), "sine", 20.0)
	if id in EVENT_CUES:
		var recorded := file_samples(id, _shift)
		if not recorded.is_empty():
			return recorded
		if base_key(id) != id:
			return _bake(base_key(id))
	if id in ["plate_tally", "clip_tally", "stroke_tally", "settle_tally"]:
		return tally_recipe(id)
	if id.begins_with("cable_kest_") or id.begins_with("raid_kest_") or id.begins_with("tick_kest_"):
		if id == "cable_kest_fizz":
			return _mix([[_noise(0.5, 1800.0, 4800.0, 4.0), 0, 0.6], [_tone(0.5, _hz(62), _hz(63), "sine", 4.0), 0, 0.4]])
		return _score(kest_score(id), 0.7)
	match id:
		"ui_tick":
			return _tone(0.03, _hz(86), _hz(86), "sine", 120.0)
		"hop":
			return _mix([[_tone(0.11, 380.0, 640.0, "sine", 28.0), 0, 1.0], [_noise(0.02, 3000.0, 3000.0, 200.0), 0, 0.3]])
		"boost_whoosh":
			return _mix([[_noise(0.42, 500.0, 3200.0, 7.0, 0.06), 0, 1.0], [_tone(0.12, 90.0, 55.0, "sine", 25.0), 0, 0.7]])
		"carve_release":
			return _mix([[_noise(0.18, 5200.0, 1600.0, 16.0, 0.004), 0, 0.9], [_tone(0.14, 220.0, 520.0, "saw", 18.0), Synth.seconds(0.03), 0.22],
				[_tone(0.08, 140.0, 90.0, "sine", 30.0), 0, 0.5]])
		"dash_whoosh":
			return _mix([[_noise(0.28, 1400.0, 5200.0, 11.0, 0.02), 0, 1.0], [_tone(0.2, 300.0, 950.0, "saw", 14.0), 0, 0.18]])
		"land_thud":
			return _mix([[_tone(0.2, 95.0, 42.0, "sine", 20.0), 0, 1.0], [_noise(0.05, 800.0, 400.0, 60.0), 0, 0.4]])
		"slam_boom":
			return _slam()
		"core_slam":
			return _core_slam()
		"grown_sub":
			return _mix([[_tone(0.5, 62.0, 34.0, "sine", 5.0), 0, 1.0], [_tone(0.03, 140.0, 70.0, "sine", 60.0), 0, 0.3]])
		"grown_crack":
			return _mix([[_noise(0.03, 4200.0, 1800.0, 110.0, 0.0005), 0, 1.0],
				[_tone(0.07, 190.0, 85.0, "saw_dark", 38.0), 0, 0.8]], true)
		"grown_tail":
			return _mix([[_tone(1.2, 48.0, 38.0, "sine", 2.4), 0, 0.8], [_noise(1.3, 420.0, 120.0, 2.6, 0.02), 0, 0.6]])
		"grown_rattle":
			return _mix([[_noise(0.03, 3200.0, 2000.0, 80.0), 0, 0.7], [_noise(0.03, 2600.0, 1700.0, 80.0), Synth.seconds(0.06), 0.5],
				[_noise(0.03, 3600.0, 2200.0, 80.0), Synth.seconds(0.13), 0.38], [_noise(0.03, 2400.0, 1500.0, 80.0), Synth.seconds(0.22), 0.26]])
		"ultimate_land":
			return _ultimate_land()
		"kest_demo_knock":
			return _kest_demo_knock()
		"rivet_skid_plate":
			return _rivet_skid_plate()
		"grapple_clink":
			return _fm(0.24, _hz(81), 3.5, 5.0, 16.0)
		"line_bite":
			return bite(0)
		"smash_crack":
			return crack(0)
		"lock_tick":
			return _fm(0.04, _hz(93), 1.0, 0.5, 80.0)
		"seal_ratchet":
			return _mix([[_noise(0.015, 1200.0, 700.0, 160.0), 0, 0.9], [_tone(0.04, 180.0, 130.0, "square_dark", 60.0), 0, 1.0], [_noise(0.015, 1100.0, 650.0, 160.0), Synth.seconds(0.05), 0.7], [_tone(0.04, 170.0, 125.0, "square_dark", 60.0), Synth.seconds(0.05), 0.8]])
		"dry_tick":
			return _mix([[_tone(0.05, 320.0, 240.0, "sine", 70.0), 0, 1.0], [_noise(0.025, 700.0, 450.0, 120.0), 0, 0.5]])
		"anchor_clunk":
			return clunk()
		"smash_whistle":
			return _mix([[_tone(0.55, 700.0, 2400.0, "sine", 2.5), 0, 1.0], [_noise(0.55, 1500.0, 4800.0, 3.0, 0.05), 0, 0.35]])
		"dock_click":
			return _mix([[_noise(0.012, 3800.0, 2600.0, 260.0), 0, 0.8], [_tone(0.07, 600.0, 420.0, "square_dark", 55.0), 0, 1.0]])
		"line_zip":
			return zip()
		"line_twang":
			return twang()
		"line_hum":
			return _line_hum()
		"find_drip":
			return _find_drip()
		"find_radio":
			return _find_radio()
		"verb_fail_jump":
			return _mix([[_tone(0.06, _hz(70), _hz(70), "sine", 40.0), 0, 1.0], [_tone(0.08, _hz(65), _hz(64), "sine", 35.0), Synth.seconds(0.07), 0.9]])
		"verb_fail_fire":
			return _mix([[_noise(0.015, 2200.0, 1500.0, 200.0), 0, 1.0], [_noise(0.015, 2200.0, 1500.0, 200.0), Synth.seconds(0.07), 0.8],
				[_tone(0.03, 900.0, 600.0, "square_dark", 80.0), 0, 0.4]])
		"verb_fail_haul":
			return _mix([[_tone(0.14, 110.0, 80.0, "square_dark", 20.0), 0, 1.0], [_noise(0.04, 500.0, 250.0, 60.0), 0, 0.5]])
		"verb_fail_boost":
			return _mix([[_tone(0.18, 420.0, 120.0, "saw_dark", 14.0), 0, 1.0], [_noise(0.16, 2500.0, 700.0, 18.0, 0.01), 0, 0.5]])
		"verb_fail_special":
			return _fm(0.2, _hz(67), 2.0, 2.0, 18.0, -3.0)
		"verb_fail_interact":
			return _mix([[_tone(0.09, 520.0, 330.0, "sine", 32.0), 0, 1.0], [_noise(0.01, 2500.0, 2000.0, 300.0), 0, 0.4]])
		"verb_fail_select":
			return _mix([[_tone(0.05, 300.0, 260.0, "square_dark", 45.0), 0, 1.0], [_noise(0.01, 1800.0, 1200.0, 250.0), 0, 0.3]])
		"verb_fail_roll":
			return _mix([[_noise(0.06, 700.0, 300.0, 45.0), 0, 1.0], [_tone(0.07, 95.0, 70.0, "sine", 38.0), 0, 0.8],
				[_noise(0.012, 3200.0, 2400.0, 280.0), Synth.seconds(0.05), 0.35], [_noise(0.012, 2800.0, 2000.0, 280.0), Synth.seconds(0.11), 0.25]])
		"verb_fail_active":
			return _mix([[_fm(0.12, _hz(67), 1.5, 2.0, 24.0, -2.0), 0, 1.0], [_noise(0.05, 900.0, 600.0, 40.0), 0, 0.3]])
		"active_scrap_rocket":
			return _mix([[_noise(0.16, 2400.0, 5200.0, 14.0, 0.004), 0, 0.7], [_tone(0.09, 120.0, 60.0, "sine", 30.0), 0, 0.8],
				[_tone(0.34, 900.0, 2600.0, "sine", 6.0), Synth.seconds(0.06), 0.35], [_noise(0.3, 1200.0, 3600.0, 8.0, 0.02), Synth.seconds(0.06), 0.4]])
		"active_cutting_torch":
			return _mix([[_noise(0.05, 3200.0, 1400.0, 60.0, 0.001), 0, 0.9], [_tone(0.07, 200.0, 90.0, "sine", 40.0), 0, 0.7],
				[_tone(1.6, _hz(38), _hz(38), "saw_dark", 1.4), Synth.seconds(0.04), 0.6], [_tone(1.6, _hz(45), _hz(45), "square_dark", 1.6), Synth.seconds(0.04), 0.25],
				[_noise(1.6, 2800.0, 2200.0, 1.2, 0.03), Synth.seconds(0.04), 0.3]])
		"active_cutting_torch_heat":
			return _mix([[_noise(0.14, 3400.0, 5200.0, 18.0, 0.004), 0, 1.0], [_noise(0.08, 1800.0, 2600.0, 30.0), Synth.seconds(0.02), 0.4]])
		"active_silo_battery":
			return _mix([[_tone(0.07, 740.0, 720.0, "square_dark", 12.0), 0, 0.45], [_tone(0.07, 990.0, 960.0, "square_dark", 12.0), Synth.seconds(0.07), 0.45],
				[_fm(0.2, _hz(43), 2.76, 3.0, 16.0), Synth.seconds(0.12), 0.8], [_noise(0.05, 3200.0, 1800.0, 60.0), Synth.seconds(0.12), 0.5],
				[_tone(0.3, 2600.0, 900.0, "sine", 2.0), Synth.seconds(0.15), 0.28], [_tone(0.26, 2200.0, 760.0, "sine", 2.0), Synth.seconds(0.19), 0.24],
				[_tone(0.45, 95.0, 36.0, "sine", 6.0), Synth.seconds(0.45), 1.0], [_noise(0.4, 900.0, 180.0, 8.0, 0.003), Synth.seconds(0.45), 0.8],
				[_noise(0.06, 4200.0, 2200.0, 50.0), Synth.seconds(0.45), 0.4]], true)
		"active_quake_knock":
			return _mix([[_noise(0.1, 420.0, 200.0, 30.0), 0, 0.9], [_tone(0.5, _hz(39), _hz(34), "saw_dark", 3.5), 0, 0.85],
				[_noise(0.035, 5200.0, 2200.0, 85.0), Synth.seconds(0.05), 0.9], [_fm(0.1, _hz(63), 2.3, 4.0, 26.0), Synth.seconds(0.05), 0.5],
				[_noise(0.03, 4400.0, 2000.0, 90.0), Synth.seconds(0.12), 0.6], [_noise(0.4, 1300.0, 200.0, 5.0, 0.02), Synth.seconds(0.1), 0.7]], true)
		"active_lift_pulse":
			return _mix([[_tone(0.3, 95.0, 42.0, "sine", 12.0), 0, 1.0], [_noise(0.22, 1600.0, 300.0, 14.0, 0.004), 0, 0.6],
				[_fm_sweep(0.26, 180.0, 720.0, 1.2, 4.0), Synth.seconds(0.02), 0.4], [_noise(0.28, 500.0, 2600.0, 6.0, 0.06), Synth.seconds(0.02), 0.3]])
		"verb_fail_ultimate":
			return _mix([[_fm(0.16, _hz(62), 1.5, 2.5, 20.0, -2.0), 0, 1.0], [_tone(0.06, 180.0, 150.0, "sine", 30.0), Synth.seconds(0.05), 0.6]])
		"grapple_release":
			return _fm(0.15, _hz(76), 2.0, 1.5, 24.0, -2.0)
		"pylon_plant":
			return _mix([[_tone(0.16, 130.0, 55.0, "sine", 22.0), 0, 1.0], [_fm(0.3, _hz(62), 2.76, 4.0, 12.0), 0, 0.6],
				[_tone(0.2, 440.0, 880.0, "sine", 8.0), Synth.seconds(0.1), 0.25]])
		"pylon_eject":
			return _boing()
		"enemy_arrive":
			return _mix([[_tone(0.16, _hz(40), _hz(40), "saw_dark", 6.0), 0, 1.0],
				[_tone(0.2, _hz(41), _hz(41), "saw_dark", 6.0), Synth.seconds(0.14), 1.0]])
		"hit_thwack":
			return _mix([[_noise(0.14, 1300.0, 700.0, 30.0), 0, 0.8], [_tone(0.14, 230.0, 85.0, "sine", 26.0), 0, 1.0]], true)
		"weapon_zap":
			return _fm_sweep(0.1, 1500.0, 480.0, 4.0, 30.0)
		"special_fire":
			return _special()
		"kill_pop":
			return _mix([[_tone(0.05, 500.0, 1300.0, "sine", 50.0), 0, 0.6], [_n("bell", 81), 0, 0.8]])
		"hurt":
			return _mix([[_tone(0.13, _hz(53), _hz(53), "square_dark", 8.0), 0, 1.0],
				[_tone(0.2, _hz(50), _hz(48), "square_dark", 9.0), Synth.seconds(0.11), 1.0],
				[_noise(0.1, 900.0, 300.0, 30.0), 0, 0.5]], true)
		"armor_shed_small":
			return _shed(2)
		"armor_shed":
			return _shed(3)
		"armor_shed_big":
			return _shed(5)
		"armor_reclaim":
			return _reclaim()
		"armor_deflect":
			return _deflect()
		"wear_sputter":
			return _sputter()
		"shell_spring":
			return _shell_spring()
		"death":
			return _death()
		"scrap_tick":
			return _mix([[_cut(_n("bell", 74), 0.16), 0, 1.0], [_noise(0.01, 6000.0, 6000.0, 300.0), 0, 0.2]])
		"cog_tick":
			return _mix([[_cut(_n("bell", 74), 0.16), 0, 1.0], [_cut(_n("brass", 62), 0.09), 0, 0.45], [_noise(0.01, 6000.0, 6000.0, 300.0), 0, 0.15]])
		"part_get":
			return _arpeggio([74, 77, 81, 86], 0.05, "bell", 0.8)
		"panel_ratchet":
			return _mix([[_noise(0.012, 5200.0, 5200.0, 260.0), 0, 0.7], [_noise(0.012, 4600.0, 4600.0, 260.0), Synth.seconds(0.035), 0.6],
				[_noise(0.012, 4000.0, 4000.0, 260.0), Synth.seconds(0.07), 0.5], [_cut(_n("mallet", 86), 0.08), Synth.seconds(0.07), 0.35]])
		"panel_note":
			return _cut(_n("mallet", 74), 0.22)
		"panel_jackpot":
			return _mix([[_arpeggio([74, 81, 86, 93], 0.04, "bell", 0.9), 0, 0.92],
				[_cut(_n("keys", 62), 0.65, 1800), Synth.seconds(0.12), 0.28],
				[_cut(_n("keys", 69), 0.65, 1800), Synth.seconds(0.12), 0.26],
				[_cut(_n("keys", 76), 0.65, 1800), Synth.seconds(0.12), 0.22]])
		"panel_cache":
			var chime := _mix([[_cut(_n("bell", 86), 0.3), 0, 0.8], [_cut(_n("bell", 93), 0.4), Synth.seconds(0.233), 0.6]])
			chime.resize(Synth.seconds(1.86))
			return chime
		"beacon_hum":
			return _hum()
		"gate_through":
			return _mix([[_noise(0.3, 800.0, 3600.0, 10.0, 0.03), 0, 0.6], [_n("bell", 81), Synth.seconds(0.04), 0.6],
				[_n("bell", 86), Synth.seconds(0.04), 0.5], [_n("bell", 89), Synth.seconds(0.04), 0.4]])
		"launch_roar":
			return _mix([[_noise(1.1, 300.0, 4200.0, 2.4, 0.5), 0, 1.0], [_tone(1.0, 90.0, 720.0, "saw_dark", 2.2), 0, 0.5]], true)
		"klaxon":
			return _klaxon()
		"event_start":
			return _mix([[Synth.kick(), 0, 1.0], [_n("keys", 50), 0, 0.5], [_n("keys", 53), 0, 0.5],
				[_n("keys", 57), 0, 0.5], [_n("keys", 63), 0, 0.4]], true, 0.8)
		"event_end":
			return _arpeggio([69, 65, 62], 0.09, "mallet", 0.7)
		"music_pressure":
			return _riser()
		"stinger_run":
			return _score(_score_run(0), 0.8)
		"stinger_stage":
			return _score([[0, 0, 2, "kick", 1.0], [0, 0, 2, "open_hat", 0.6], [0, 62, 2, "keys", 0.5],
				[0, 65, 2, "keys", 0.5], [0, 69, 2, "keys", 0.5], [0, 72, 2, "keys", 0.5], [0, 74, 2, "lead", 0.6]], 0.5)
		"stinger_world", "stinger_world_down5", "stinger_world_up5":
			for world in range(1, WORLD_STEPS.size() + 1):
				if world_stinger(world) == id:
					return _score(_score_world(WORLD_STEPS[world - 1]), 0.6)
			return _score(_score_world(0), 0.6)
		"stinger_clear":
			return _score(_score_clear(0), 1.4)
		"stinger_run_end":
			var finale := _score_run(0)
			finale.append_array(_score_clear(16))
			return _score(finale, 2.0)
		"stinger_milestone":
			return _score(_score_milestone(), 1.2)
		"gates_open":
			return _score([[0, 62, 2, "bell", 0.5], [1, 65, 2, "bell", 0.54], [2, 69, 2, "bell", 0.58],
				[3, 72, 2, "bell", 0.6], [4, 76, 6, "bell", 0.64], [4, 76, 8, "lead", 0.38], [4, 38, 10, "sub", 0.45],
				[4, 57, 12, "keys", 0.36], [4, 60, 12, "keys", 0.36],
				[4, 64, 12, "keys", 0.36], [4, 65, 12, "keys", 0.36], [4, 0, 2, "open_hat", 0.48]], 1.0)
		"stinger_unseal":
			return _unseal()
		"class_up":
			return _score(_score_class_up(), 0.9)
		"class_down":
			return _mix([[_score(_score_class_down(), 0.7), 0, 1.0], [_noise(0.18, 3500.0, 1500.0, 14.0), Synth.seconds(0.05), 0.25]])
		"clank":
			return _clank()
		"scrap_rip":
			return _rip()
		"threat_up":
			return _mix([[_tone(0.07, _hz(62), _hz(62), "square_dark", 18.0), 0, 0.9],
				[_tone(0.12, _hz(65), _hz(67), "square_dark", 14.0), Synth.seconds(0.08), 1.0]], true)
		"core_socket":
			return _core_socket()
		"synergy_fanfare":
			return _score(_score_synergy(), 1.4)
		"achievement_chime":
			return _mix([[_cut(_n("bell", 84), 0.45), 0, 0.8], [_cut(_n("bell", 91), 0.4), Synth.seconds(0.08), 0.6]])
		"rescue_fanfare":
			return _mix([[_noise(0.02, 5000.0, 5000.0, 250.0), 0, 0.5], [_tone(0.07, 220.0, 110.0, "square_dark", 30.0), 0, 0.7],
				[_cut(_n("bell", 74), 0.35), Synth.seconds(0.08), 0.6], [_cut(_n("bell", 79), 0.35), Synth.seconds(0.17), 0.6],
				[_cut(_n("bell", 83), 0.35), Synth.seconds(0.26), 0.65], [_cut(_n("bell", 86), 0.45), Synth.seconds(0.35), 0.7]])
		"companion_chirp_ready":
			return _mix([[_cut(_n("mallet", 79), 0.16), 0, 0.7], [_cut(_n("mallet", 86), 0.22), Synth.seconds(0.07), 0.75]])
		"companion_chirp_spent":
			return _mix([[_cut(_n("mallet", 84), 0.14), 0, 0.6], [_tone(0.12, _hz(76), _hz(64), "sine", 30.0), Synth.seconds(0.06), 0.5]])
		"found_chime":
			return _mix([[_cut(_n("mallet", 77), 0.35), 0, 0.8], [_fm(0.5, _hz(86), 3.5, 1.2, 6.0, 0.3), Synth.seconds(0.12), 0.7]])
		"element_resolved":
			return _mix([[_cut(_n("bell", 81), 0.3), 0, 0.7], [_noise(0.25, 2000.0, 5000.0, 14.0, 0.01), 0, 0.5]])
		"warden_theme_in":
			return _warden_in()
		"womp":
			return _womp()
		"build_riser":
			return _build_riser()
		"ice_form":
			return _ice()
		"zap_hum":
			return _zap_hum()
		"shatter":
			return _shatter()
		"destructible_wood", "destructible_scrap", "destructible_masonry", "destructible_steel":
			return _destructible(id.trim_prefix("destructible_"))
		"chunk_low":
			return _mix([[_tone(0.55, 120.0, 36.0, "sine", 7.0), 0, 1.0], [_tone(0.3, 75.0, 40.0, "square_dark", 12.0), 0, 0.3],
				[_noise(0.08, 700.0, 200.0, 40.0), 0, 0.5]])
		"stage_fade":
			return _stage_fade()
		"vault_rise":
			return _mix([[_noise(0.32, 600.0, 4200.0, 3.0, 0.2), 0, 0.6], [_tone(0.32, _hz(62), _hz(74), "saw_dark", 4.0), 0, 0.6]])
		"slow_dip":
			return _mix([[_tone(0.7, _hz(74), _hz(57), "sine", 3.5), 0, 0.7], [_tone(0.7, _hz(74), _hz(57), "saw_dark", 5.0), 0, 0.25],
				[_noise(0.6, 3200.0, 500.0, 5.0, 0.02), 0, 0.35]])
		"slow_rise":
			return _cut(_mix([[_tone(0.3, _hz(57), _hz(74), "sine", -8.0), 0, 0.7], [_noise(0.3, 500.0, 3600.0, 2.0, 0.2), 0, 0.45]]), 0.3, 1800)
		"vault_drop":
			return _score([[0, 0, 2, "kick", 1.0], [0, 0, 8, "crash", 0.6], [0, 38, 8, "sub", 0.8],
				[0, 62, 4, "bell", 0.5], [0, 66, 4, "bell", 0.45], [0, 69, 4, "bell", 0.45], [2, 74, 6, "bell", 0.55]], 0.6)
		"synergy_hit":
			return _mix([[_fm(0.22, _hz(81), 3.5, 1.4, 14.0), 0, 0.8], [_noise(0.06, 5000.0, 3000.0, 60.0), 0, 0.2]])
		"boss_arena_in":
			return _brindle_in()
		"boss_phase":
			return _score([[0, 0, 2, "boom", 1.0], [0, 0, 2, "anvil", 0.9], [0, 50, 6, "brass", 0.5],
				[0, 53, 6, "brass", 0.5], [0, 57, 6, "brass", 0.5], [0, 63, 6, "brass", 0.5], [4, 0, 1, "anvil", 0.7],
				[6, 0, 1, "anvil", 0.8], [6, 62, 2, "brass", 0.6], [6, 74, 2, "brass", 0.45]], 0.6)
		"boss_telegraph":
			return _boss_telegraph()
		"ratchet_cue":
			return _ratchet_cue()
		"boss_weak_hit":
			return _mix([[_fm(0.28, _hz(79), 3.5, 3.0, 13.0), 0, 0.9], [_tone(0.1, 180.0, 90.0, "sine", 30.0), 0, 0.6],
				[_noise(0.03, 4500.0, 2500.0, 120.0), 0, 0.4]])
		"stinger_boss_defeated":
			return _boss_defeated()
		"threat_tick":
			return _threat_tick()
		"near_whoosh":
			return _mix([[_noise(0.22, 700.0, 4800.0, 9.0, 0.04), 0, 0.9], [_noise(0.16, 4200.0, 1500.0, 14.0), Synth.seconds(0.1), 0.5],
				[_cut(_n("bell", 81), 0.35), Synth.seconds(0.09), 0.7]])
		"kest_kick_thump":
			return _mix([[Synth.kick(), 0, 1.0], [_n("tom", 50), 0, 0.85], [_noise(0.06, 5600.0, 2000.0, 60.0), 0, 0.75],
				[_noise(0.35, 900.0, 200.0, 9.0), Synth.seconds(0.02), 0.35], [_tone(0.55, 72.0, 33.0, "sine", 5.5), 0, 0.9]], true)
		"crit_ping":
			return _mix([[_fm(0.2, _hz(86), 3.0, 2.2, 20.0), 0, 0.9], [_noise(0.02, 7000.0, 5000.0, 200.0), 0, 0.45]])
		"threat_whoosh":
			return _threat_whoosh()
		"threat_whistle":
			return _threat_whistle()
		"threat_hum":
			return _threat_hum()
		"threat_tear":
			return _threat_tear()
		"warn_burrow":
			return _warn_burrow()
		"warn_bore":
			return _warn_bore()
		"warn_lure":
			return _warn_lure()
		"warn_cut":
			return _warn_cut()
		"warn_winch":
			return _warn_winch()
		"warn_dive":
			return _warn_dive()
		"warn_tether":
			return _warn_tether()
		"warn_flap":
			return _warn_flap()
		"warn_reel":
			return _warn_reel()
		"flank_call":
			return _flank_call()
		"boil_rumble":
			return _boil_rumble()
		"breach_crack":
			return _breach_crack()
		"sable_arpeggio":
			return _sable_release()
		"rivet_hihat_roll":
			return _rivet_release()
		"kest_low_thump":
			return _kest_release()
		"tarn_latch_tear":
			return _tarn_release()
		"tally_balance_due":
			return _tally_release()
		"cannon_recall":
			return _cannon_release()
		"sable_ready", "rivet_ready", "kest_ready", "tarn_ready", "tally_ready", "cannon_ready":
			return _ready_pulse(id.get_slice("_", 0))
		"sable_break", "rivet_break", "kest_break", "tarn_break", "tally_break", "cannon_break":
			return _break_free(id.get_slice("_", 0))
		"fleet_motif":
			return _fleet_motif()
		"reactor_tick":
			return Synth.drum("geiger")
		"reactor_erupt":
			return _reactor_erupt()
		"swarm_buzz":
			return _cut(_n("buzz", 79), 0.6)
		"swarm_lock":
			return _swarm_lock()
		"swarm_scatter":
			return _swarm_scatter()
		"mind_sable", "mind_rivet", "mind_kest", "mind_tarn", "mind_tally", "mind_cannon":
			return _mind_quote(id.get_slice("_", 1))
		"mind_wrong_sable", "mind_wrong_rivet", "mind_wrong_kest", "mind_wrong_tarn", "mind_wrong_tally", "mind_wrong_cannon":
			return _mind_wrong(id.get_slice("_", 2))
		"fleet_anvil":
			return _fleet_anvil()
		"boiler_burst":
			return _boiler_burst()
		"active_glass_lance":
			return _glass_lance()
		"hold_pit", "hold_bola", "hold_tether", "hold_net", "hold_riser":
			return hold(id.get_slice("_", 1), _step * Harmony.STEPS_PER_BEAT * 2)
		"tenacity_choke":
			return Synth.drum("choke")
		"callout_chime":
			return _mix([[_cut(_n("mallet", 81), 0.08), 0, 0.8], [_cut(_n("mallet", 86), 0.14), Synth.seconds(0.07), 0.9],
				[_noise(0.01, 6000.0, 6000.0, 400.0), 0, 0.25]])
		"shop_bell":
			return _shop_bell()
		"bench_clank":
			return _mix([[_fm(0.35, 196.0, 1.41, 4.0, 9.0), 0, 0.8], [_tone(0.12, 120.0, 60.0, "sine", 30.0), 0, 0.9],
				[_noise(0.05, 2500.0, 900.0, 60.0), 0, 0.6], [_fm(0.25, 523.0, 2.76, 2.0, 14.0), Synth.seconds(0.06), 0.35]], true)
		"rarity_tick":
			return _mix([[_cut(_n("mallet", 74), 0.14), 0, 0.9], [_noise(0.015, 7000.0, 5000.0, 250.0), 0, 0.3]])
		"rarity_bell":
			return _mix([[_cut(_n("bell", 74), 0.3), 0, 0.7], [_cut(_n("bell", 81), 0.3), Synth.seconds(0.06), 0.8],
				[_cut(_n("bell", 86), 0.5), Synth.seconds(0.12), 1.0], [_fm(0.5, _hz(98), 3.5, 1.0, 7.0), Synth.seconds(0.12), 0.25]])
		"rung_coil":
			return _mix([[_fm_sweep(0.22, _hz(62), _hz(81), 1.4, 5.0), 0, 0.5], [_tone(0.22, _hz(74), _hz(93), "saw_dark", 6.0), 0, 0.35],
				[_noise(0.012, 5200.0, 5200.0, 280.0), Synth.seconds(0.22), 0.8], [_cut(_n("mallet", 86), 0.1), Synth.seconds(0.22), 0.6]])
		"reveal_clank":
			return _mix([[_fm(0.25, 196.0, 1.41, 3.0, 14.0), 0, 0.6], [_tone(0.1, 140.0, 70.0, "sine", 30.0), 0, 0.8],
				[_noise(0.04, 3000.0, 1200.0, 70.0), 0, 0.4], [_cut(_n("mallet", 81), 0.2), Synth.seconds(0.07), 0.8],
				[_cut(_n("bell", 86), 0.45), Synth.seconds(0.15), 0.9]])
		"ceremony_build":
			return _ceremony_build()
		"ceremony_resolve":
			return _score(_score_ceremony_resolve(), 1.2)
		"bet_roll":
			return _bet_roll()
		"bet_clunk":
			return _bet_clunk()
		"bet_crack":
			return _bet_crack()
		"bet_refusal":
			return _bet_refusal()
		"sunken_bell":
			return _sunken_bell()
		"ally_hum_sable", "ally_hum_rivet", "ally_hum_kest":
			return _ally_hum(id.get_slice("_", 2))
		"ally_wake":
			return _ally_wake()
		"fight_arm_stamp":
			return _fight_arm_stamp()
		"near_miss_whip_sable", "near_miss_whip_rivet", "near_miss_whip_kest", "near_miss_whip_tarn", "near_miss_whip_tally", "near_miss_whip_cannon":
			return _near_miss_whip(id.get_slice("_", 3))
		"pickup_fountain":
			return _pickup_fountain()
		"synergy_fired":
			return _synergy_fired()
		"evolution_fired":
			return _evolution_fired()
		"lore_found":
			return _lore_found()
		"pilot_unlocked":
			return _pilot_unlocked("sable")
		"pilot_unlocked_sable", "pilot_unlocked_rivet", "pilot_unlocked_kest", "pilot_unlocked_tarn", "pilot_unlocked_tally", "pilot_unlocked_cannon":
			return _pilot_unlocked(id.get_slice("_", 2))
		"kill_chain_tier":
			return _kill_chain_tier()
		"chain_crash":
			return _mix([[Synth.drum("crash"), 0, 1.0]])
		"drop_landing":
			return _drop_landing()
		"door_tick":
			return _door_tick()
		"return_launch_arpeggio":
			return _return_launch_arpeggio()
		"lift_hiss":
			return _lift_hiss()
		"crater_hold":
			return hold("crater", _step * Harmony.STEPS_PER_BEAT * 2)
		"arena_lock_slam":
			return _arena_lock_slam()
		"arena_wave_whistle":
			return _arena_wave_whistle()
		"arena_unlock_bells":
			return _arena_unlock_bells()
		"warden_gate_pip":
			return _warden_gate_pip()
		"warden_gate_clunk":
			return _warden_gate_clunk()
		"warden_gate_release":
			return _warden_gate_release()
		"call_ink":
			return _call_ink()
		"call_drop":
			return _call_drop()
		"heat_kettle":
			return _heat_kettle()
		"overtime_offer":
			return _overtime_offer()
		"overtime_ring":
			return _overtime_ring()
		"overtime_pay":
			return _overtime_pay()
		"heat_rise":
			return _heat_rise()
		"heat_cool":
			return _heat_cool()
		"heat_hot_hit":
			return _heat_hot_hit()
		"tele_crane_sweep":
			return _tele_crane_sweep()
		"tele_slag_ring":
			return _tele_slag_ring()
		"tele_charge":
			return _tele_charge()
		"tele_charge_wall":
			return _tele_charge_wall()
		"tele_eject":
			return _tele_eject()
		"sluice_siren_two_tone":
			return _sluice_siren_two_tone()
		"ride_rolling_metal":
			return _ride_rolling_metal()
		"ride_bowl_carve":
			return _ride_bowl_carve()
		"ride_drop_swoop":
			return _ride_drop_swoop()
		"ride_ledge_scuff":
			return _ride_ledge_scuff()
		"ride_hop_lift":
			return _ride_hop_lift()
		"ride_cable_clink":
			return _ride_cable_clink()
		"ride_sheet_swell":
			return _ride_sheet_swell()
		"steam_whistle_rise":
			return _steam_whistle_rise()
		"cannon_bang_rail_whoosh":
			return _cannon_bang_rail_whoosh()
		"sluice_gush_roar":
			return _sluice_gush_roar()
		"lounge_flip":
			return _lounge_flip()
		"bay_bell_ring":
			return _bay_bell_ring()
		"marble_tick_ladder":
			return _marble_tick_ladder()
		"pins_crash":
			return _pins_crash()
		"bay_lounge_in":
			return _bay_lounge_in()
		"bay_slingshot_out":
			return _bay_slingshot_out()
		"menu_move":
			return _mix([[_cut(_n("mallet", 79), 0.09), 0, 0.9], [_cut(_n("bell", 91), 0.08), 0, 0.16]])
		"menu_confirm":
			return _mix([[_cut(_n("mallet", 74), 0.18), 0, 0.72], [_cut(_n("mallet", 81), 0.24), Synth.seconds(0.065), 0.82],
				[_cut(_n("keys", 62), 0.24), Synth.seconds(0.065), 0.2], [_cut(_n("bell", 93), 0.2), Synth.seconds(0.065), 0.2]])
		"menu_back":
			return _mix([[_cut(_n("mallet", 81), 0.18), 0, 0.7], [_cut(_n("mallet", 77), 0.22), Synth.seconds(0.065), 0.72],
				[_cut(_n("keys", 57), 0.22), Synth.seconds(0.065), 0.16]])
		"ultimate_ready":
			return _ultimate_ready()
		"found_twinkle":
			return _found_twinkle()
		"gauge_dry_click":
			return _gauge_dry_click()
		"drop_thud":
			return _drop_thud()
		"drop_whiff":
			return _drop_whiff()
		"guard_creak":
			return _guard_creak()
		"beacon_open_chime":
			return _beacon_open_chime()
		"callout_warden_chime":
			return _callout_warden_chime()
	var cadence := _cadence_rail_flip(id)
	if not cadence.is_empty():
		return cadence
	var own := _world1_own(id)
	if not own.is_empty():
		return own
	if id.begins_with(CAUSE_NOTE):
		return _mix([[_cut(_n("mallet", int(id.trim_prefix(CAUSE_NOTE))), 0.6), 0, 1.0]])
	if id.begins_with(GRID_NOTE):
		var bits := id.trim_prefix(GRID_NOTE).rsplit("_", true, 1)
		return _mix([[_cut(_n(bits[0], int(bits[1])), GRID_NOTE_SECONDS), 0, 1.0]])
	if id.begins_with(PILOT_QUOTE):
		return _score(pilot_quote_score(id.trim_prefix(PILOT_QUOTE)), 0.5)
	if id.begins_with(SET_ANSWER):
		return _score(SetDirector.answer_score(id.trim_prefix(SET_ANSWER)), 0.5)
	if _assist_parts(id).size() > 0:
		return _assist_sting(_assist_parts(id))
	return _tone(0.12, _hz(62 + Harmony.pentatonic_step(absi(id.hash()) % 8)), 0.0, "sine", 20.0)


func _assist_base(move: String) -> Array:
	match move:
		"bonk":
			return [[_fm(0.22, _hz(74), 1.0, 2.5, 18.0, -7.0), 0, 0.8], [_tone(0.16, 140.0, 55.0, "sine", 24.0), 0, 0.9]]
		"arc":
			return [[_fm_sweep(0.18, 300.0, 2400.0, 3.0, 14.0), 0, 0.6], [_cut(_n("bell", 81), 0.4), Synth.seconds(0.08), 0.7]]
		"pile":
			return [[_fm(0.12, _hz(57), 1.41, 3.0, 26.0), 0, 0.7], [_fm(0.12, _hz(62), 1.41, 3.0, 26.0), Synth.seconds(0.06), 0.7],
				[_fm(0.2, _hz(69), 1.41, 3.0, 18.0), Synth.seconds(0.12), 0.75]]
		"slip":
			return [[_noise(0.4, 600.0, 4800.0, 8.0, 0.05), 0, 0.9], [_tone(0.08, _hz(86), _hz(91), "sine", 30.0), Synth.seconds(0.3), 0.4]]
		"anvil":
			return [[_fm(0.6, _hz(69), 1.41, 6.0, 6.0), 0, 0.8], [_noise(0.85, 400.0, 90.0, 3.5, 0.03), Synth.seconds(0.03), 0.9]]
		"static":
			return [[_noise(0.25, 3500.0, 6000.0, 16.0, 0.002), 0, 0.6], [_tone(0.1, _hz(81), _hz(81), "saw", 22.0), Synth.seconds(0.05), 0.35]]
		"bulldozer":
			return [[_tone(0.35, 55.0, 95.0, "saw_dark", 6.0), 0, 0.8], [_noise(0.12, 900.0, 300.0, 30.0), Synth.seconds(0.28), 0.8]]
	return []


func _assist_sting(parts: Array) -> PackedFloat32Array:
	var layers := _assist_base(String(parts[0]))
	if int(parts[1]) >= 2:
		layers.append([_tone(0.7, _hz(38), _hz(31), "sine", 4.5), 0, 0.85])
	if int(parts[1]) >= 3:
		var notes := Harmony.motif_notes(String(parts[2]))
		for i in mini(3, notes.size()):
			layers.append([_cut(_n("sax_lounge", int(notes[i])), 0.18), Synth.seconds(0.1 + 0.07 * i), 0.55])
	return _cut(_mix(layers, int(parts[1]) >= 2), 0.95)


func bite(variant: int) -> PackedFloat32Array:
	match variant:
		1:
			return _mix([[_tone(0.14, 260.0, 90.0, "saw_dark", 24.0), 0, 1.0], [_noise(0.025, 3500.0, 2000.0, 140.0), 0, 0.5],
				[_fm(0.3, _hz(81), 2.0, 3.0, 10.0), 0, 0.8], [_fm(0.3, _hz(88), 2.0, 2.0, 10.0), Synth.seconds(0.02), 0.4]])
		2:
			return _mix([[_tone(0.1, 180.0, 70.0, "sine", 30.0), 0, 1.0], [_fm(0.22, _hz(81), 1.41, 5.0, 18.0), 0, 0.9],
				[_noise(0.04, 5000.0, 2500.0, 80.0), 0, 0.35]])
	return _mix([[_tone(0.12, 200.0, 90.0, "sine", 30.0), 0, 0.9], [_noise(0.02, 3000.0, 3000.0, 200.0), 0, 0.4],
		[_fm(0.24, _hz(81), 3.5, 5.0, 16.0), 0, 1.0]])


func crack(variant: int) -> PackedFloat32Array:
	match variant:
		1:
			return _mix([[_tone(0.3, _hz(74), _hz(74), "saw_dark", 9.0), 0, 0.8], [_noise(0.06, 5000.0, 1800.0, 60.0), 0, 0.9],
				[_tone(0.16, 130.0, 55.0, "sine", 20.0), 0, 0.9]])
		2:
			return _mix([[_fm(0.34, _hz(74), 1.5, 4.0, 11.0), 0, 1.0], [_noise(0.05, 6000.0, 2500.0, 80.0), 0, 0.8],
				[_tone(0.12, 150.0, 60.0, "sine", 26.0), 0, 0.6]])
	return _mix([[_fm(0.3, _hz(74), 3.5, 4.0, 14.0), 0, 1.0], [_noise(0.05, 5500.0, 2000.0, 70.0), 0, 0.8],
		[_tone(0.12, 120.0, 60.0, "sine", 24.0), 0, 0.8]])


static func clunk() -> PackedFloat32Array:
	return _mix([[_tone(0.2, 150.0, 60.0, "sine", 18.0), 0, 1.0], [_noise(0.06, 900.0, 350.0, 45.0), 0, 0.7],
		[_tone(0.3, 200.0, 170.0, "saw_dark", 9.0), Synth.seconds(0.05), 0.35]])


static func zip() -> PackedFloat32Array:
	return _mix([[_noise(0.16, 5500.0, 800.0, 16.0, 0.004), 0, 1.0], [_tone(0.14, 1700.0, 500.0, "sine", 22.0), 0, 0.35]])


func twang() -> PackedFloat32Array:
	var n := Synth.seconds(0.6)
	var buf := Synth.buffer(n)
	var f := _hz(52)
	var phase := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		phase += TAU * f * (1.0 + 0.08 * exp(-t * 16.0)) * (1.0 + 0.012 * sin(TAU * 7.0 * t)) * Synth.INV_RATE
		buf[i] = (sin(phase) + 0.5 * sin(2.0 * phase) + 0.25 * sin(3.0 * phase)) * minf(1.0, t * 1500.0) * exp(-t * 6.0)
	return _mix([[Synth.declick(buf, 8, 300), 0, 1.0], [_noise(0.025, 3000.0, 1500.0, 120.0), 0, 0.5]])


func _line_hum() -> PackedFloat32Array:
	var length := 0.6
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var f := roundf(_hz(46) * length) / length
	for i in n:
		var t := i * Synth.INV_RATE
		buf[i] = (sin(TAU * f * t) + 0.5 * sin(TAU * 2.0 * f * t) + 0.3 * sin(TAU * 3.0 * f * t)) * (0.85 + 0.15 * sin(TAU * 10.0 * t))
	return buf


func _find_drip() -> PackedFloat32Array:
	var length := 1.8
	return _mix([[Synth.buffer(Synth.seconds(length)), 0, 0.0],
		[_tone(0.14, _hz(97), _hz(90), "sine", 38.0), 0, 1.0],
		[_tone(0.1, _hz(94), _hz(88), "sine", 46.0), Synth.seconds(1.05), 0.6]])


func _find_radio() -> PackedFloat32Array:
	var score := [[0, 62, 16, "keys", 0.3], [0, 65, 16, "keys", 0.3], [0, 69, 16, "keys", 0.3], [0, 72, 16, "keys", 0.3],
		[16, 55, 16, "keys", 0.3], [16, 58, 16, "keys", 0.3], [16, 62, 16, "keys", 0.3], [16, 65, 16, "keys", 0.3],
		[0, 74, 2, "lead", 0.6], [2, 77, 2, "lead", 0.6], [4, 81, 3, "lead", 0.65], [7, 79, 1, "lead", 0.55],
		[8, 77, 4, "lead", 0.6], [12, 76, 2, "lead", 0.55], [14, 74, 2, "lead", 0.55], [16, 72, 3, "lead", 0.6],
		[19, 70, 1, "lead", 0.5], [20, 69, 4, "lead", 0.6], [24, 67, 2, "lead", 0.55], [26, 69, 2, "lead", 0.55],
		[28, 62, 4, "lead", 0.5], [4, 0, 1, "brush", 0.3], [12, 0, 1, "brush", 0.3], [20, 0, 1, "brush", 0.3], [28, 0, 1, "brush", 0.3]]
	var music := _score(score, 0.0)
	var n := 32 * _step
	var buf := Synth.buffer(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fade := Synth.seconds(0.04)
	for i in mini(n, music.size()):
		var t := i * Synth.INV_RATE
		var crackle := rng.randf_range(-1.0, 1.0) * (0.5 if rng.randf() < 0.002 else 0.04)
		buf[i] = (music[i] * (0.8 + 0.2 * sin(TAU * 2.5 * t)) + crackle) * minf(1.0, minf(i, n - 1 - i) / float(fade))
	return buf


static func _score_run(at: int) -> Array:
	return [[at, 0, 2, "kick", 1.0], [at, 0, 16, "crash", 0.55], [at, 62, 2, "lead", 0.7], [at + 2, 69, 2, "lead", 0.7],
		[at + 4, 72, 1, "lead", 0.7], [at + 5, 74, 3, "lead", 0.75], [at + 8, 77, 2, "lead", 0.75], [at + 10, 76, 2, "lead", 0.7],
		[at + 12, 74, 4, "lead", 0.75], [at, 53, 3, "keys", 0.35], [at, 57, 3, "keys", 0.35], [at, 60, 3, "keys", 0.35],
		[at, 64, 3, "keys", 0.35], [at + 10, 53, 4, "keys", 0.35], [at + 10, 57, 4, "keys", 0.35], [at + 10, 60, 4, "keys", 0.35],
		[at + 10, 64, 4, "keys", 0.35], [at + 4, 0, 1, "snare", 0.7], [at + 12, 0, 1, "snare", 0.8], [at + 10, 0, 1, "kick", 0.8]]


static func _score_clear(at: int) -> Array:
	var tune := [[0, 69], [2, 73], [4, 76], [6, 81], [8, 79], [10, 76], [12, 73], [14, 76]]
	var score := []
	for note in tune:
		score.append([at + note[0], note[1], 2, "mallet", 0.8])
		score.append([at + note[0], note[1], 2, "beep", 0.25])
	score.append_array([[at + 16, 74, 8, "mallet", 0.9], [at + 16, 74, 8, "beep", 0.3], [at + 16, 86, 8, "bell", 0.5],
		[at + 16, 0, 16, "crash", 0.4], [at + 24, 78, 2, "mallet", 0.6], [at + 26, 81, 2, "mallet", 0.6],
		[at + 28, 86, 4, "mallet", 0.8], [at + 28, 86, 4, "beep", 0.3]])
	return score


static func _score_milestone() -> Array:
	var score := []
	var rung := 0
	for step in 8:
		score.append([step, 74 + Harmony.pentatonic_step(rung), 1, "bell", 0.55])
		rung += 1
	score.append_array([[8, 0, 2, "kick", 1.0], [8, 0, 16, "crash", 0.6], [8, 53, 8, "keys", 0.4], [8, 57, 8, "keys", 0.4],
		[8, 60, 8, "keys", 0.4], [8, 64, 8, "keys", 0.4], [8, 86, 8, "lead", 0.6], [12, 0, 1, "snare", 0.8]])
	return score


static func _score_world(step: int) -> Array:
	var score := [[0, 0, 1, "hat", 0.3], [4, 0, 1, "brush", 0.4], [4, 50 + step, 4, "keys", 0.3]]
	for note in [[0, 74, 1, "clav", 0.55], [1, 72, 1, "clav", 0.5], [2, 69, 1, "clav", 0.5], [3, 74, 1, "clav", 0.55],
			[4, 81, 4, "chime", 0.6], [4, 69, 4, "bell", 0.35]]:
		score.append([note[0], note[1] + step, note[2], note[3], note[4]])
	return score


static func _score_class_up() -> Array:
	return [[0, 0, 2, "kick", 0.7], [0, 69, 2, "mallet", 0.8], [0, 69, 2, "bell", 0.35], [2, 74, 2, "mallet", 0.85],
		[2, 74, 2, "bell", 0.4], [4, 81, 4, "mallet", 0.9], [4, 81, 4, "bell", 0.5], [4, 38, 4, "sub", 0.6],
		[4, 0, 2, "open_hat", 0.4], [4, 38, 2, "fbass", 0.7]]


static func _score_class_down() -> Array:
	return [[0, 81, 2, "mallet", 0.7], [2, 77, 2, "mallet", 0.65], [4, 74, 3, "mallet", 0.7], [4, 74, 3, "bell", 0.25]]


func _score_synergy() -> Array:
	var head: Array = Harmony.MOTIF_HEADS[clampi(_theme, 0, 2)]
	var run := [[0, 69], [1, 72], [2, 74], [3, 76], [4, head[0] + 12 if head[0] < 74 else head[0]], [5, head[1] + (12 if head[0] < 74 else 0)],
		[6, head[2] + (12 if head[0] < 74 else 0)], [7, 85]]
	var score := []
	for note in run:
		score.append([note[0], note[1], 1, "lead", 0.6])
		score.append([note[0], note[1] + 12, 1, "bell", 0.25])
	score.append_array([[6, 0, 1, "snare", 0.6], [7, 0, 1, "snare", 0.8], [8, 0, 2, "kick", 1.0], [8, 0, 16, "crash", 0.6],
		[8, 86, 8, "lead", 0.75], [8, 98, 8, "bell", 0.45], [8, 53, 8, "keys", 0.4], [8, 57, 8, "keys", 0.4],
		[8, 60, 8, "keys", 0.4], [8, 64, 8, "keys", 0.4], [8, 38, 8, "sub", 0.6], [12, 81, 2, "bell", 0.35],
		[13, 86, 3, "bell", 0.35]])
	return score


func _ceremony_build() -> PackedFloat32Array:
	var score := []
	for t in [[0, 45], [4, 47], [8, 50], [10, 52], [12, 53], [13, 55], [14, 57], [15, 60]]:
		score.append([t[0], t[1], 1, "tom", 0.55 + 0.017 * t[0]])
	for s in range(8, 12):
		score.append([s, 0, 1, "hat", 0.25])
	for s in range(12, 16):
		score.append([s, 0, 1, "snare", 0.3 + 0.12 * (s - 12)])
	var climb := [62, 65, 67, 69, 72, 74, 77, 79]
	for i in climb.size():
		score.append([i * 2, climb[i], 2, "bell", 0.28 + 0.04 * i])
	var n := _step * 16
	var air := _noise(float(n) / RATE, 400.0, 5200.0, 0.0, 0.001)
	for i in n:
		var x := float(i) / n
		air[i] *= x * x
	return _mix([[_score(score, 0.05), 0, 1.0], [air, 0, 0.3]])


static func _score_ceremony_resolve() -> Array:
	return [[0, 0, 2, "kick", 1.0], [0, 0, 12, "crash", 0.6], [0, 38, 10, "sub", 0.72],
		[0, 62, 10, "keys", 0.42], [0, 69, 10, "keys", 0.4], [0, 74, 10, "keys", 0.4], [0, 77, 10, "keys", 0.4], [0, 76, 10, "keys", 0.3],
		[0, 86, 2, "bell", 0.5], [2, 81, 1, "mallet", 0.68], [3, 83, 1, "mallet", 0.72], [4, 84, 1, "mallet", 0.78],
		[5, 86, 6, "bell", 0.84], [5, 74, 6, "lead", 0.52], [5, 62, 6, "brass", 0.28], [5, 98, 6, "bell", 0.26]]


static func _mix(parts: Array, saturate := false, target := 0.9) -> PackedFloat32Array:
	var length := 0
	for part in parts:
		length = maxi(length, int(part[1]) + (part[0] as PackedFloat32Array).size())
	var buf := Synth.buffer(length)
	for part in parts:
		Synth.add_into(buf, part[0], int(part[1]), float(part[2]))
	if saturate:
		for i in buf.size():
			buf[i] = tanh(buf[i] * 1.4)
	return Synth.declick(Synth.normalize(buf, target), 16, 400)


static func _cut(buf: PackedFloat32Array, length_seconds: float, fade := 600) -> PackedFloat32Array:
	var cut := buf.slice(0, mini(buf.size(), Synth.seconds(length_seconds)))
	return Synth.declick(cut, 8, fade)


static func _tone(length: float, f0: float, f1: float, shape: String, decay: float) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var phase := 0.0
	var low := 0.0
	var end := f1 if f1 > 0.0 else f0
	for i in n:
		var t := i * Synth.INV_RATE
		var f := f0 * pow(end / f0, float(i) / n)
		phase = fposmod(phase + f * Synth.INV_RATE, 1.0)
		var x := 0.0
		match shape:
			"sine":
				x = sin(TAU * phase)
			"saw":
				x = 2.0 * phase - 1.0
			"saw_dark":
				low += ((2.0 * phase - 1.0) - low) * 0.08
				x = low * 2.0
			"square_dark":
				low += ((1.0 if phase < 0.5 else -1.0) - low) * 0.1
				x = low
		buf[i] = x * minf(1.0, t * 600.0) * exp(-t * decay)
	return Synth.declick(buf, 8, 300)


static func _noise(length: float, f0: float, f1: float, decay: float, attack := 0.002) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 7.0 + f1)
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var cutoff := minf(f0 * pow(f1 / f0, float(i) / n), 6000.0)
		var g := 2.0 * sin(PI * cutoff * Synth.INV_RATE)
		var x := rng.randf_range(-1.0, 1.0)
		low += g * band
		var high := x - low - 0.9 * band
		band += g * high
		var env := minf(1.0, t / attack) * exp(-maxf(0.0, t - attack) * decay)
		buf[i] = band * env
	return Synth.declick(buf, 16, 300)


static func _fm(length: float, f: float, ratio: float, index: float, decay: float, bend := 0.0) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var phase := 0.0
	var mod := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var freq := f * Harmony.ratio(bend * float(i) / n)
		phase += TAU * freq * Synth.INV_RATE
		mod += TAU * freq * ratio * Synth.INV_RATE
		buf[i] = sin(phase + index * exp(-t * decay * 1.5) * sin(mod)) * minf(1.0, t * 900.0) * exp(-t * decay)
	return Synth.declick(buf, 8, 300)


static func _fm_sweep(length: float, f0: float, f1: float, index: float, decay: float) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var phase := 0.0
	var mod := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var f := f0 * pow(f1 / f0, float(i) / n)
		phase += TAU * f * Synth.INV_RATE
		mod += TAU * f * 1.5 * Synth.INV_RATE
		buf[i] = sin(phase + index * exp(-t * 20.0) * sin(mod)) * minf(1.0, t * 1500.0) * exp(-t * decay)
	return Synth.declick(buf, 4, 200)


func _arpeggio(notes: Array, gap: float, instrument: String, tail: float) -> PackedFloat32Array:
	var parts := []
	for i in notes.size():
		parts.append([_cut(_n(instrument, notes[i]), tail), Synth.seconds(gap * i), 1.0 - 0.1 * i])
	return _mix(parts)


static func _slam() -> PackedFloat32Array:
	var n := Synth.seconds(0.85)
	var buf := Synth.buffer(n)
	var phase := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var f := 28.0 + 60.0 * exp(-t * 14.0)
		phase += TAU * f * Synth.INV_RATE
		buf[i] = tanh(2.2 * sin(phase)) * exp(-t * 4.5)
	return _mix([[buf, 0, 1.0], [_noise(0.3, 1200.0, 200.0, 12.0), 0, 0.8], [_cut(Synth.crash(), 0.8), 0, 0.25]], true)


static func _core_slam() -> PackedFloat32Array:
	return _mix([[_tone(0.9, 105.0, 55.0, "sine", 2.2), 0, 1.0],
		[_fm(0.12, 165.0, 1.41, 1.2, 22.0), Synth.seconds(0.004), 0.18],
		[_noise(0.09, 950.0, 280.0, 30.0, 0.006), 0, 0.22]], true)


func _ultimate_land() -> PackedFloat32Array:
	return _mix([[_tone(1.25, _hz(38), _hz(26), "sine", 3.2), 0, 1.0],
		[_fm(0.12, _hz(62), 2.0, 1.6, 28.0), 0, 0.2],
		[_fm(0.1, _hz(65), 2.0, 1.4, 30.0), 0, 0.16],
		[_fm(0.09, _hz(69), 2.0, 1.2, 32.0), 0, 0.14],
		[_fm(0.08, _hz(72), 2.0, 1.0, 35.0), 0, 0.12],
		[_noise(0.018, 4200.0, 1800.0, 120.0), 0, 0.18]])


func _kest_demo_knock() -> PackedFloat32Array:
	var parts := [[_fm(0.1, _hz(57), 1.41, 2.0, 45.0), 0, 0.85],
		[_tone(0.08, _hz(53), _hz(41), "sine", 38.0), 0, 0.45],
		[_noise(0.012, 1800.0, 900.0, 150.0), 0, 0.3]]
	for i in 3:
		var at := Synth.seconds(0.11 + 0.1 * i)
		var note: int = [86, 89, 93][i]
		parts.append([_fm(0.09, _hz(note), 1.0, 0.45, 48.0), at, 0.36 - 0.03 * i])
		parts.append([_noise(0.008, 5200.0, 3500.0, 250.0), at, 0.12])
	return _mix(parts)


func _rivet_skid_plate() -> PackedFloat32Array:
	var at := Synth.seconds(0.055)
	return _mix([[_noise(0.065, 3600.0, 1100.0, 14.0), 0, 0.55],
		[_fm(0.35, _hz(45), 2.76, 3.2, 14.0), at, 0.8],
		[_tone(0.3, _hz(43), _hz(31), "sine", 13.0), at, 1.0],
		[_noise(0.025, 2400.0, 600.0, 95.0), at, 0.45]], true)


static func _boing() -> PackedFloat32Array:
	var n := Synth.seconds(0.36)
	var buf := Synth.buffer(n)
	var phase := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var f := 180.0 * pow(1100.0 / 180.0, minf(1.0, t / 0.22)) * (1.0 + 0.06 * sin(TAU * 32.0 * t) * exp(-t * 8.0))
		phase += TAU * f * Synth.INV_RATE
		buf[i] = sin(phase) * minf(1.0, t * 500.0) * exp(-t * 7.0)
	return _mix([[buf, 0, 0.8], [_noise(0.3, 900.0, 4200.0, 9.0, 0.03), 0, 0.6]])


func _special() -> PackedFloat32Array:
	var parts: Array = [[_fm_sweep(0.35, 2200.0, 300.0, 6.0, 8.0), 0, 0.7]]
	var rung := 0
	for i in 6:
		parts.append([_cut(_n("bell", 74 + Harmony.pentatonic_step(rung)), 0.3), Synth.seconds(0.03 * i), 0.45])
		rung += 1
	return _mix(parts)


func _death() -> PackedFloat32Array:
	var parts := []
	var line := [57, 53, 50]
	for i in line.size():
		parts.append([_tone(0.2, _hz(line[i]), _hz(line[i]), "square_dark", 5.0), Synth.seconds(0.17 * i), 0.8])
	parts.append([_tone(0.9, _hz(38), _hz(31), "saw_dark", 3.0), Synth.seconds(0.51), 1.0])
	return _mix(parts, true)


func _hum() -> PackedFloat32Array:
	var n := Synth.seconds(0.32)
	var buf := Synth.buffer(n)
	var f := _hz(62)
	for i in n:
		var t := i * Synth.INV_RATE
		var env := sin(PI * float(i) / n)
		buf[i] = (sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.5 * t) + 0.25 * sin(TAU * f * 2.0 * t)) * env * (0.8 + 0.2 * sin(TAU * 18.0 * t))
	return buf


func _klaxon() -> PackedFloat32Array:
	var parts := []
	var beat := _step * Harmony.STEPS_PER_BEAT
	for pulse in 2:
		parts.append([_tone(beat * 1.9 / RATE, _hz(53), _hz(50), "square_dark", 1.2), beat * 2 * pulse, 1.0])
		parts.append([_tone(beat * 1.9 / RATE, _hz(41), _hz(38), "saw_dark", 1.2), beat * 2 * pulse, 0.6])
	return _mix(parts, true)


func _unseal() -> PackedFloat32Array:
	var score := [[0, 0, 2, "kick", 1.0], [0, 0, 16, "crash", 0.7], [0, 74, 1, "bell", 0.5], [1, 81, 1, "bell", 0.5],
		[2, 86, 1, "bell", 0.5], [3, 89, 1, "bell", 0.5], [4, 93, 4, "bell", 0.55], [4, 86, 10, "lead", 0.7],
		[4, 65, 10, "keys", 0.4], [4, 69, 10, "keys", 0.4], [4, 72, 10, "keys", 0.4], [4, 76, 10, "keys", 0.4],
		[4, 38, 10, "sub", 0.7], [8, 0, 1, "snare", 0.5], [10, 0, 1, "snare", 0.6], [12, 0, 1, "snare", 0.7],
		[13, 0, 1, "snare", 0.8], [14, 0, 1, "snare", 0.9], [15, 0, 1, "snare", 1.0]]
	var band := _score(score, 1.0)
	var release := _mix([[_fm(0.5, 150.0, 1.41, 6.0, 7.0, -5.0), 0, 1.0], [_noise(0.35, 3000.0, 300.0, 9.0), 0, 0.8]], true)
	return _mix([[band, 0, 1.0], [release, 0, 0.6]])


func _clank() -> PackedFloat32Array:
	return _mix([[_fm(0.3, _hz(76), 1.41, 1.6, 11.0), 0, 1.0], [_fm(0.22, _hz(83), 2.76, 1.2, 16.0), 0, 0.55],
		[_tone(0.03, 1800.0, 1200.0, "sine", 90.0), 0, 0.3]])


func _shed(plates: int) -> PackedFloat32Array:
	var notes := [86, 81, 84, 77, 79]
	var parts: Array = [[_noise(0.03 + 0.012 * plates, 4800.0, 2400.0, 90.0 / plates), 0, 0.35]]
	for i in plates:
		parts.append([_fm(0.13 + 0.02 * plates, _hz(notes[i]), 2.76, 1.5, 24.0 - 2.0 * plates), Synth.seconds(0.038 * i), 0.9 - 0.08 * i])
	if plates >= 3:
		parts.append([_tone(0.1 + 0.02 * plates, 170.0, 62.0, "sine", 22.0), 0, 0.5 + 0.1 * plates])
	return _mix(parts)


func _reclaim() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 81), 0.2), 0, 0.75], [_cut(_n("bell", 86), 0.32), Synth.seconds(0.075), 0.95],
		[_noise(0.01, 6000.0, 6000.0, 300.0), 0, 0.12]])


func _deflect() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 91), 0.11), 0, 0.8], [_noise(0.012, 7000.0, 5000.0, 250.0), 0, 0.15]])


static func _sputter() -> PackedFloat32Array:
	return _mix([[_noise(0.06, 2600.0, 900.0, 60.0, 0.004), 0, 0.5], [_tone(0.05, 300.0, 180.0, "sine", 40.0), 0, 0.5]])


static func _rip() -> PackedFloat32Array:
	var n := Synth.seconds(0.45)
	var teeth := _noise(0.45, 4200.0, 500.0, 3.0, 0.005)
	for i in n:
		var t := i * Synth.INV_RATE
		var rate := lerpf(70.0, 18.0, float(i) / n)
		teeth[i] *= 0.4 + 0.6 * maxf(0.0, sin(TAU * rate * t))
	return _mix([[teeth, 0, 1.0], [_tone(0.4, 820.0, 180.0, "saw_dark", 5.0), 0, 0.5]], true)


func _core_socket() -> PackedFloat32Array:
	return _mix([[_noise(0.02, 5000.0, 5000.0, 250.0), 0, 0.5], [_tone(0.12, 140.0, 80.0, "sine", 28.0), 0, 0.8],
		[_n("bell", 74), Synth.seconds(0.05), 0.7], [_n("bell", 81), Synth.seconds(0.05), 0.6],
		[_cut(_n("bell", 86), 0.6), Synth.seconds(0.16), 0.45]])


func _warden_in() -> PackedFloat32Array:
	var score := [[0, 0, 2, "kick", 1.0], [0, 38, 16, "sub", 0.7], [0, 51, 12, "brass", 0.45], [0, 55, 12, "brass", 0.45],
		[0, 58, 12, "brass", 0.45], [4, 0, 2, "kick", 0.8], [8, 0, 2, "kick", 0.9], [12, 0, 2, "kick", 1.0],
		[12, 0, 1, "snare", 0.7], [13, 0, 1, "snare", 0.8], [14, 0, 1, "snare", 0.9], [15, 0, 1, "snare", 1.0]]
	var band := _score(score, 0.8)
	return _mix([[band, 0, 1.0], [_fm(0.9, _hz(38), 2.71, 5.0, 3.5), 0, 0.5]], true)


static func _womp() -> PackedFloat32Array:
	var n := Synth.seconds(0.62)
	var buf := Synth.buffer(n)
	var phase := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		phase += TAU * (34.0 + 52.0 * exp(-t * 9.0)) * Synth.INV_RATE
		buf[i] = tanh(2.0 * sin(phase)) * minf(1.0, t * 400.0) * exp(-t * 3.2)
	return _mix([[buf, 0, 1.0], [_noise(0.08, 900.0, 200.0, 40.0), 0, 0.3]], true)


func _build_riser() -> PackedFloat32Array:
	var n := _step * Harmony.STEPS_PER_BAR * 2
	var noise := _noise(float(n) / RATE, 300.0, 6000.0, 0.0, 0.001)
	var phase := 0.0
	for i in n:
		var x := float(i) / n
		phase += TAU * lerpf(110.0, 880.0, x * x) * Synth.INV_RATE
		noise[i] = (noise[i] * 0.8 + sin(phase) * 0.35) * x * x
	return Synth.normalize(noise, 0.9)


func _ice() -> PackedFloat32Array:
	var parts: Array = [[_noise(0.3, 6000.0, 6000.0, 12.0, 0.002), 0, 0.35]]
	var notes := [86, 93, 88, 98, 91]
	for i in notes.size():
		parts.append([_fm(0.3, _hz(notes[i]), 3.5, 1.5, 10.0), Synth.seconds(0.035 * i), 0.5])
	return _mix(parts)


func _zap_hum() -> PackedFloat32Array:
	var n := Synth.seconds(0.6)
	var buf := Synth.buffer(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var phase := 0.0
	var low := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		phase = fposmod(phase + _hz(45) * Synth.INV_RATE, 1.0)
		low += ((2.0 * phase - 1.0) - low) * 0.25
		var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.02 else 0.0
		buf[i] = (low * (0.6 + 0.4 * sin(TAU * 60.0 * t)) + crackle * 0.8) * minf(1.0, t * 80.0) * exp(-t * 4.0)
	return Synth.declick(buf, 16, 600)


func _destructible(family: String) -> PackedFloat32Array:
	match family:
		"wood":
			return _mix([[_fm(0.16, _hz(74), 1.0, 2.5, 18.0, -7.0), 0, 0.8], [_noise(0.16, 2200.0, 700.0, 20.0), 0, 0.55],
				[_noise(0.08, 3600.0, 1400.0, 34.0, 0.001), Synth.seconds(0.05), 0.4]])
		"scrap":
			return _mix([[_clank(), 0, 0.8], [_noise(0.22, 4600.0, 1800.0, 15.0), 0, 0.5], [_tone(0.16, 200.0, 95.0, "square_dark", 16.0), 0, 0.35]])
		"masonry":
			return _mix([[_tone(0.32, 115.0, 42.0, "sine", 11.0), 0, 0.95], [_noise(0.3, 950.0, 220.0, 9.0, 0.001), 0, 0.7],
				[_noise(0.18, 2800.0, 1000.0, 20.0), Synth.seconds(0.06), 0.35]])
	return _mix([[_fm(0.4, _hz(55), 2.76, 2.0, 9.0), 0, 0.7], [_noise(0.14, 5400.0, 2400.0, 26.0), 0, 0.5], [_tone(0.26, 95.0, 48.0, "sine", 13.0), 0, 0.7]])


static func _shatter() -> PackedFloat32Array:
	var parts: Array = [[_noise(0.25, 5000.0, 2500.0, 16.0, 0.001), 0, 0.8]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		parts.append([_fm(0.18, rng.randf_range(2200.0, 6000.0), 2.3, 1.0, 26.0), Synth.seconds(rng.randf_range(0.0, 0.12)), 0.35])
	return _mix(parts)


func _brindle_in() -> PackedFloat32Array:
	var score := [[0, 0, 2, "boom", 1.0], [0, 0, 2, "anvil", 1.0], [0, 38, 16, "sub", 0.6], [2, 0, 2, "anvil", 0.8],
		[4, 62, 2, "brass", 0.6], [6, 65, 2, "brass", 0.6], [8, 69, 2, "brass", 0.65], [8, 0, 2, "kick", 0.9],
		[10, 75, 6, "brass", 0.7], [10, 51, 6, "brass", 0.4], [10, 55, 6, "brass", 0.4], [10, 58, 6, "brass", 0.4],
		[10, 0, 16, "crash", 0.5], [12, 0, 1, "snare", 0.6], [13, 0, 1, "snare", 0.7], [14, 0, 1, "snare", 0.85],
		[15, 0, 1, "snare", 1.0]]
	return _score(score, 0.9)


func _stage_fade() -> PackedFloat32Array:
	var air := _noise(0.7, 2600.0, 400.0, 0.0, 0.08)
	var n := air.size()
	for i in n:
		var x := float(i) / n
		air[i] *= (1.0 - x) * (1.0 - x)
	return _mix([[air, 0, 1.0], [_tone(0.6, _hz(50), _hz(50), "sine", 4.0), 0, 0.35]], false, 0.6)


func _boss_telegraph() -> PackedFloat32Array:
	return _mix([[_tone(0.12, _hz(50), _hz(50), "square_dark", 10.0), 0, 0.9],
		[_tone(0.18, _hz(51), _hz(52), "square_dark", 8.0), Synth.seconds(0.13), 1.0],
		[_noise(0.35, 600.0, 3000.0, 3.0, 0.2), 0, 0.35]], true)


func _ratchet_cue() -> PackedFloat32Array:
	return _mix([[_tone(0.05, _hz(62), _hz(62), "square_dark", 30.0), 0, 0.8],
		[_tone(0.05, _hz(65), _hz(65), "square_dark", 30.0), Synth.seconds(0.11), 0.85],
		[_tone(0.05, _hz(69), _hz(69), "square_dark", 30.0), Synth.seconds(0.22), 0.9],
		[_cut(_n("bell", 86), 0.3), Synth.seconds(0.33), 0.7]], true)


func _boss_defeated() -> PackedFloat32Array:
	var score := [[0, 0, 2, "boom", 1.0], [0, 0, 16, "crash", 0.7], [0, 62, 2, "brass", 0.6], [2, 66, 2, "brass", 0.6],
		[4, 69, 2, "brass", 0.65], [6, 74, 2, "brass", 0.7], [8, 0, 2, "kick", 1.0], [8, 78, 4, "brass", 0.7],
		[12, 76, 2, "brass", 0.6], [14, 73, 2, "brass", 0.65], [16, 0, 2, "kick", 1.0], [16, 0, 16, "crash", 0.6],
		[16, 74, 16, "brass", 0.75], [16, 86, 16, "bell", 0.5], [16, 50, 16, "keys", 0.4], [16, 54, 16, "keys", 0.4],
		[16, 57, 16, "keys", 0.4], [16, 62, 16, "keys", 0.4], [16, 38, 16, "sub", 0.7]]
	for i in 8:
		score.append([8 + i, 0, 1, "hat", 0.4])
		score.append([8 + i, [74, 78, 81, 86, 90, 93, 98, 93][i], 1, "bell", 0.3])
	return _score(score, 1.6)


func _riser() -> PackedFloat32Array:
	var n := _step * Harmony.STEPS_PER_BEAT
	var noise := _noise(float(n) / RATE, 400.0, 5000.0, 0.0, 0.001)
	for i in n:
		var x := float(i) / n
		noise[i] *= x * x * x
	return Synth.normalize(noise, 0.9)


func _threat_tick() -> PackedFloat32Array:
	var parts := []
	var at := 0.0
	var gap := 0.1
	for i in 7:
		parts.append([_noise(0.025, 4200.0, 2800.0, 150.0), Synth.seconds(at), 0.55 + 0.05 * i])
		parts.append([_tone(0.03, _hz(63), _hz(63), "square_dark", 90.0), Synth.seconds(at), 0.35])
		at += gap
		gap *= 0.88
	parts.append([_fm(0.4, _hz(75), 1.41, 3.0, 9.0), Synth.seconds(at), 1.0])
	parts.append([_noise(0.06, 5000.0, 3000.0, 60.0), Synth.seconds(at), 0.5])
	return _mix(parts)


func _threat_whoosh() -> PackedFloat32Array:
	return _mix([[_noise(0.6, 300.0, 2800.0, 1.5, 0.35), 0, 1.0], [_tone(0.6, _hz(51), _hz(58), "saw_dark", 2.0), 0, 0.55]])


func _threat_whistle() -> PackedFloat32Array:
	return _mix([[_tone(0.1, 110.0, 50.0, "sine", 28.0), 0, 1.0], [_noise(0.06, 900.0, 300.0, 40.0), 0, 0.5],
		[_tone(0.65, _hz(82), _hz(75), "sine", 1.2), Synth.seconds(0.08), 0.8], [_noise(0.65, 2200.0, 1300.0, 2.5, 0.05), Synth.seconds(0.08), 0.15]])


const THREAT_HUM_HOLD := 3.0

func _threat_hum() -> PackedFloat32Array:
	return _mix([[_tone(THREAT_HUM_HOLD, _hz(44), _hz(44), "saw_dark", 0.15), 0, 0.8],
		[_tone(THREAT_HUM_HOLD, _hz(56), _hz(56), "square_dark", 0.2), 0, 0.5]], true)


func _threat_tear() -> PackedFloat32Array:
	return _mix([[_noise(0.18, 1800.0, 5200.0, 10.0), 0, 0.9], [_tone(0.18, _hz(56), _hz(51), "saw", 12.0), 0, 0.6]], true)


func _warn_burrow() -> PackedFloat32Array:
	return _mix([[_tone(0.38, _hz(39), _hz(51), "saw_dark", 3.0), 0, 0.8],
		[_noise(0.09, 350.0, 180.0, 35.0), 0, 0.7],
		[_noise(0.1, 500.0, 250.0, 28.0), Synth.seconds(0.14), 1.0]])


func _warn_bore() -> PackedFloat32Array:
	var parts := []
	for at in [0.0, 0.12, 0.2]:
		parts.append([_noise(0.035, 1800.0, 800.0, 80.0), Synth.seconds(at), 0.7])
		parts.append([_tone(0.06, _hz(44), _hz(44), "square_dark", 35.0), Synth.seconds(at), 0.5])
	parts.append([_fm(0.18, _hz(56), 1.41, 3.0, 16.0), Synth.seconds(0.28), 1.0])
	return _mix(parts)


func _breach_crack() -> PackedFloat32Array:
	return _mix([[_noise(0.03, 5200.0, 2400.0, 90.0), 0, 0.9],
		[_fm(0.08, _hz(63), 2.3, 4.0, 30.0), 0, 0.55],
		[_noise(0.36, 1400.0, 220.0, 6.0, 0.02), Synth.seconds(0.06), 0.75],
		[_tone(0.34, _hz(46), _hz(39), "saw_dark", 5.0), Synth.seconds(0.1), 0.8]])


func _warn_lure() -> PackedFloat32Array:
	return _mix([[_noise(0.52, 250.0, 1400.0, 3.0, 0.18), 0, 0.9],
		[_tone(0.52, _hz(44), _hz(44), "sine", 2.0), 0, 0.65],
		[_tone(0.4, _hz(51), _hz(51), "sine", 3.0), Synth.seconds(0.08), 0.45]])


func _warn_cut() -> PackedFloat32Array:
	return _mix([[_noise(0.025, 4200.0, 1800.0, 120.0), 0, 0.8],
		[_fm(0.29, _hz(58), 2.71, 5.0, 12.0, -12.0), 0, 1.0]])


func _warn_winch() -> PackedFloat32Array:
	var parts := [[_tone(0.43, _hz(46), _hz(46), "square_dark", 2.0), 0, 0.6]]
	for at in [0.0, 0.13, 0.26]:
		parts.append([_fm(0.1, _hz(46), 3.5, 4.0, 28.0), Synth.seconds(at), 1.0])
		parts.append([_noise(0.03, 1200.0, 500.0, 90.0), Synth.seconds(at), 0.45])
	return _mix(parts)


func _warn_dive() -> PackedFloat32Array:
	return _mix([[_noise(0.56, 1800.0, 350.0, 4.0, 0.06), 0, 0.45],
		[_tone(0.56, _hz(58), _hz(51), "sine", 1.8), 0, 1.0]])


func _warn_tether() -> PackedFloat32Array:
	return _mix([[_noise(0.03, 2600.0, 1200.0, 90.0), 0, 0.6],
		[_noise(0.03, 3200.0, 1500.0, 90.0), Synth.seconds(0.12), 0.7],
		[_fm(0.32, _hz(58), 1.5, 3.0, 7.0, 4.0), Synth.seconds(0.2), 1.0],
		[_noise(0.2, 700.0, 300.0, 9.0, 0.03), Synth.seconds(0.2), 0.35]])


func _warn_flap() -> PackedFloat32Array:
	return _mix([[_tone(0.42, _hz(51), _hz(56), "saw_dark", 2.5), 0, 0.7],
		[_fm(0.42, _hz(63), 2.1, 1.5, 3.0, 5.0), 0, 0.35],
		[_noise(0.4, 600.0, 1600.0, 3.0, 0.12), Synth.seconds(0.05), 0.6]])


func _warn_reel() -> PackedFloat32Array:
	var parts := [[_tone(0.7, _hz(39), _hz(41), "saw_dark", 3.0), 0, 0.5]]
	for i in 5:
		parts.append([_noise(0.025, 1800.0 + 350.0 * i, 900.0, 90.0), Synth.seconds(0.11 * i), 0.55 + 0.05 * i])
	parts.append([_fm(0.3, _hz(70), 2.0, 1.2, 4.0, 6.0), Synth.seconds(0.5), 0.45])
	return _mix(parts)


func _flank_call() -> PackedFloat32Array:
	return _mix([[_tone(0.16, _hz(81), _hz(88), "sine", 4.0), 0, 0.8],
		[_tone(0.2, _hz(88), _hz(86), "sine", 7.0), Synth.seconds(0.15), 0.85],
		[_noise(0.3, 5200.0, 4400.0, 9.0, 0.01), 0, 0.12]])


func _boil_rumble() -> PackedFloat32Array:
	return _mix([[_fm(0.9, _hz(31), 1.5, 2.5, 2.0, 3.0), 0, 0.9],
		[_noise(0.8, 300.0, 900.0, 2.5, 0.08), Synth.seconds(0.1), 0.5],
		[_noise(0.06, 1400.0, 700.0, 40.0), Synth.seconds(0.5), 0.35],
		[_noise(0.06, 1700.0, 800.0, 40.0), Synth.seconds(0.72), 0.3]])


static func motif_score(id: String, at: int, instrument: String, gain: float, octave := 0) -> Array:
	var score: Array = []
	for cell in Harmony.motif(id).get("cells", []):
		score.append([at + int(cell[0]), int(cell[1]) + octave, int(cell[2]), instrument, gain])
	return score


func tally_recipe(id: String, midi := -1, total := false) -> PackedFloat32Array:
	if midi < 0:
		midi = 50 if id == "plate_tally" else 62
	var score: Array = [[0, midi, 1, "keys", 0.8]]
	if id == "plate_tally":
		score.append([0, midi + 12, 2, "bell", 0.25])
	elif total:
		score.append([0, midi, 3, "bell", 0.35])
	elif id == "stroke_tally":
		score.append([0, midi, 1, "beep", 0.2])
	elif id == "settle_tally":
		score.append([0, midi, 1, "bell", 0.2])
	var punch := _mix([[_noise(0.018, 2600.0, 900.0, 180.0), 0, 0.7],
		[_tone(0.025, _hz(midi + 12), _hz(midi), "sine", 100.0), 0, 0.25]])
	return Synth.normalize(_mix([[_score(score, 0.7), 0, 1.0], [punch, 0, 0.4]]), 0.9)


static func kest_score(id: String) -> Array:
	if id == "raid_kest_stinger" or id == "raid_kest_roll":
		return motif_score("kest", 0, "tom", 0.85).slice(0, 3)
	if id == "raid_kest_boom" or id == "cable_kest_blast":
		return [[0, 50, 4, "tom", 0.85], [0, 50, 4, "sub", 0.65]]
	var note := 62
	if id.begins_with("tick_kest_"):
		note = int(id.trim_prefix("tick_kest_"))
	return [[0, note, 1, "tom", 0.6]]


func _sable_release() -> PackedFloat32Array:
	var score := motif_score("sable", 0, "mallet", 0.8)
	score.append_array(motif_score("sable", 0, "bell", 0.3, 12))
	for midi in [65, 69, 72, 76]:
		score.append([6, midi + 12, 6, "bell", 0.3])
	score.append_array([[6, 53, 6, "keys", 0.3], [6, 57, 6, "keys", 0.3], [6, 60, 6, "keys", 0.3], [6, 64, 6, "keys", 0.3],
		[6, 88, 6, "bell", 0.25], [6, 0, 2, "open_hat", 0.35]])
	return _score(score, 0.9)


func _rivet_release() -> PackedFloat32Array:
	var step := _step
	var score := motif_score("rivet", 0, "clav", 0.8)
	score.append_array(motif_score("rivet", 0, "clav", 0.35, 12))
	score.append_array([[4, 0, 8, "crash", 0.45], [4, 0, 2, "open_hat", 0.7], [4, 0, 2, "kick", 0.6]])
	var parts: Array = [[_score(score, 0.8), 0, 1.0]]
	var hits := [0.0, 1.0, 2.0, 2.5, 3.0, 3.25, 3.5, 3.75]
	for i in hits.size():
		parts.append([Synth.drum("hat"), int(hits[i] * step), 0.45 + 0.07 * i])
	return _mix(parts)


func _kest_release() -> PackedFloat32Array:
	var score := motif_score("kest", 0, "tom", 0.85)
	var cells: Array = Harmony.motif("kest")["cells"]
	var last: Array = cells[cells.size() - 1]
	score.append([int(last[0]), int(last[1]) - 12, 8, "sub808", 0.9])
	score.append([int(last[0]), 0, 2, "kick", 0.5])
	return _score(score, 1.0)


func _tarn_release() -> PackedFloat32Array:
	var step := _step
	var score := motif_score("tarn", 0, "reese", 0.8)
	score.append_array([[4, 45, 6, "sub808", 0.7], [4, 0, 2, "kick", 0.6], [4, 0, 8, "crash", 0.45]])
	var parts: Array = [[_score(score, 0.9), 0, 1.0]]
	for at in [0, 2]:
		parts.append([Synth.drum("anvil"), int(at * step), 0.7])
	return _mix(parts)


func _tally_release() -> PackedFloat32Array:
	var step := _step
	var score := motif_score("tally", 0, "keys", 0.8)
	score.append_array([[5, 86, 6, "bell", 0.4], [5, 50, 6, "sub808", 0.6], [5, 0, 2, "kick", 0.5]])
	var parts: Array = [[_score(score, 0.9), 0, 1.0]]
	for i in 4:
		parts.append([Synth.drum("clap"), int(i * step), 0.4 + 0.08 * i])
	parts.append([Synth.drum("snare"), int(5 * step), 0.8])
	return _mix(parts)


func _cannon_release() -> PackedFloat32Array:
	var step := _step
	var score := motif_score("cannon", 0, "chime", 0.7)
	score.append_array(motif_score("cannon", 0, "talk", 0.35, -12))
	score.append_array([[0, 0, 2, "kick", 0.6], [4, 0, 2, "kick", 0.6], [4, 0, 8, "crash", 0.45], [4, 50, 6, "sub808", 0.6]])
	var parts: Array = [[_score(score, 1.6), 0, 1.0]]
	parts.append([Synth.drum("snare"), int(2 * step), 0.6])
	parts.append([Synth.drum("hat"), int(3 * step), 0.5])
	return _mix(parts)


func _ready_pulse(id: String) -> PackedFloat32Array:
	var first: int = int(Harmony.motif_or_first(id)["cells"][0][1])
	match id:
		"rivet":
			return _mix([[Synth.drum("hat"), 0, 0.8], [_cut(_n("clav", first + 12), 0.08), 0, 0.7]])
		"kest":
			return _mix([[_cut(_n("tom", first), 0.14), 0, 1.0]])
		"tarn":
			return _mix([[Synth.drum("anvil"), 0, 0.7], [_cut(_n("reese", first + 12), 0.1), 0, 0.8]])
		"tally":
			return _mix([[Synth.drum("clap"), 0, 0.6], [_cut(_n("keys", first + 12), 0.1), 0, 0.8]])
		"cannon":
			return _mix([[Synth.drum("ride"), 0, 0.5], [_cut(_n("chime", first + 12), 0.12), 0, 0.9]])
	return _mix([[_cut(_n("mallet", first + 12), 0.12), 0, 1.0], [_cut(_n("bell", first + 24), 0.12), 0, 0.3]])


func _break_free(id: String) -> PackedFloat32Array:
	var row := Harmony.motif_or_first(id)
	var cells: Array = row["cells"]
	var a: int = int(cells[0][1]) + 12
	var b: int = int(cells[cells.size() - 1][1] if id in ["rivet", "tarn", "tally"] else cells[1][1]) + 12
	var voice: String = row["voice"]
	var gap := _step
	return _mix([[_noise(0.18, 5200.0, 2600.0, 14.0, 0.001), 0, 0.55], [_cut(_n(voice, a), 0.2), 0, 0.85],
		[_cut(_n(voice, b), 0.35), gap, 0.9], [_cut(_n("bell", b + 12), 0.4), gap, 0.3]])


func _fleet_motif() -> PackedFloat32Array:
	var score := motif_score("fleet", 0, "brass", 0.6)
	score.append_array(motif_score("fleet", 0, "brass", 0.35, 12))
	for stamp in Harmony.motif("fleet")["stamps"]:
		score.append([int(stamp), 0, 2, "anvil", 0.9])
		score.append([int(stamp), 0, 2, "kick", 0.55])
	return _score(score, 0.9)


func _reactor_erupt() -> PackedFloat32Array:
	var pedal: int = int(Harmony.motif("reactor")["cells"][0][1])
	return _mix([[Synth.drum("boom"), 0, 1.0], [_noise(1.1, 3800.0, 350.0, 2.6, 0.004), 0, 0.8],
		[_n("sub808", pedal), 0, 0.8], [Synth.drum("crash"), 0, 0.35]], true)


func _swarm_lock() -> PackedFloat32Array:
	var row := Harmony.motif("swarm")
	var unison: int = int(row["cells"][0][1])
	var snap := Synth.seconds(0.3)
	var parts: Array = [[_cut(_n("buzz", unison), 0.32), 0, 1.0], [_noise(0.02, 5000.0, 5000.0, 300.0), snap, 0.5]]
	for midi in row["chord"]:
		parts.append([_cut(_n("buzz", int(midi)), 1.5), snap, 0.6])
	return _mix(parts)


func _swarm_scatter() -> PackedFloat32Array:
	var chord: Array = Harmony.motif("swarm")["chord"]
	var parts: Array = []
	for i in chord.size():
		parts.append([_cut(_n("buzz_loose", int(chord[i])), 0.5 - 0.08 * i), Synth.seconds(0.11 * i), 0.8 - 0.12 * i])
	return _mix(parts)


func _mind_quote(class_id: String) -> PackedFloat32Array:
	var score: Array = []
	for cell in Harmony.mind_quote(class_id):
		score.append([int(cell[0]), int(cell[1]) + 12, int(cell[2]) + 2, "chime", 0.7])
	return _score(score, 2.4)


func _mind_wrong(class_id: String) -> PackedFloat32Array:
	var quote: Array = Harmony.mind_quote(class_id)
	var wrong: int = (int(quote[-1][1]) if not quote.is_empty() else 61) + 12
	return _mix([[_cut(_n("bell", wrong), 1.6), 0, 0.8], [_fm(1.6, _hz(wrong - 6), 1.0, 0.4, 1.6, -1.0), 0, 0.5],
		[_tone(1.2, _hz(wrong - 18), _hz(wrong - 19), "sine", 2.0), Synth.seconds(0.1), 0.6], [Synth.drum("crash"), 0, 0.25]])


func _fleet_anvil() -> PackedFloat32Array:
	var gap := Synth.seconds(0.17)
	return _mix([[Synth.drum("anvil"), 0, 1.0], [Synth.drum("anvil"), gap, 0.8], [Synth.drum("boom"), 0, 0.6],
		[_cut(_n("brass", 50), 0.7), gap, 0.6], [_cut(_n("brass", 57), 0.7), gap, 0.5], [_cut(_n("brass", 68), 0.7), gap, 0.4],
		[_fm_sweep(0.6, _hz(79), _hz(91), 1.5, 5.0), gap * 2, 0.2]], true)


func _boiler_burst() -> PackedFloat32Array:
	var pop := Synth.seconds(0.22)
	return _mix([[_noise(0.3, 900.0, 4200.0, 1.0, 0.25), 0, 0.5], [Synth.drum("boom"), pop, 1.0],
		[_noise(0.9, 5000.0, 600.0, 3.0, 0.003), pop, 0.7], [_tone(0.25, 70.0, 40.0, "sine", 12.0), pop, 0.8],
		[_tone(0.7, _hz(74), _hz(76), "sine", 3.5), pop, 0.35], [_tone(0.7, _hz(80), _hz(82), "sine", 3.5), pop, 0.25]], true)
func _glass_lance() -> PackedFloat32Array:
	var quote: Array = Harmony.mind_quote("sable")
	var parts: Array = [[_fm(0.06, _hz(int(quote[0][1]) + 36), 3.5, 3.0, 45.0), 0, 0.5]]
	for i in 3:
		parts.append([_cut(_n("chime", int(quote[i][1]) + 24), 0.14), Synth.seconds(0.02 + 0.045 * i), 0.7])
	var wrong := int(quote[quote.size() - 1][1]) + 36
	parts.append([_tone(0.9, _hz(wrong), _hz(wrong), "sine", 4.5), Synth.seconds(0.15), 0.55])
	return _mix(parts)


func hold(kind: String, n: int, strain := 0.0) -> PackedFloat32Array:
	var buf := Synth.buffer(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var phase := 0.0
	var low := 0.0
	var band := 0.0
	var tone := 0.0
	var grain := 0.0
	var next_grain := 0
	match kind:
		"pit":
			var f := _hz(50)
			for i in n:
				var t := i * Synth.INV_RATE
				var grind := 0.5 + 0.5 * sin(TAU * 2.5 * t)
				if i >= next_grain:
					grain = rng.randf_range(0.4, 1.0)
					next_grain = i + int(Synth.seconds(lerpf(0.03, 0.008, grind) * rng.randf_range(0.6, 1.4)))
				grain *= 0.992
				var x := rng.randf_range(-1.0, 1.0) * grain
				var g := 2.0 * sin(PI * 3600.0 * Synth.INV_RATE)
				low += g * band
				band += g * (x - low - 0.7 * band)
				phase = fposmod(phase + f * Synth.INV_RATE, 1.0)
				tone += ((2.0 * phase - 1.0) - tone) * 0.06
				buf[i] = band * 0.5 + tone * 1.4 * (0.7 + 0.3 * grind)
		"bola":
			var f := _hz(46)
			for i in n:
				var t := i * Synth.INV_RATE
				var whip := fposmod(t, 0.16) / 0.16
				var x := rng.randf_range(-1.0, 1.0)
				var cutoff := lerpf(900.0, 3400.0, whip)
				var g := 2.0 * sin(PI * cutoff * Synth.INV_RATE)
				low += g * band
				band += g * (x - low - 0.6 * band)
				phase = fposmod(phase + f * Synth.INV_RATE, 1.0)
				tone += ((1.0 if phase < 0.5 else -1.0) - tone) * 0.1
				buf[i] = band * exp(-whip * 6.0) * 0.6 + tone * (0.55 + 0.45 * signf(sin(TAU * 14.0 * t)))
		"tether":
			for i in n:
				var t := i * Synth.INV_RATE
				var f := _hz(51.0 + 2.0 * strain * float(i) / n) * (1.0 + 0.004 * sin(TAU * 7.0 * t))
				phase = fposmod(phase + f * Synth.INV_RATE, 1.0)
				var x := 2.0 * phase - 1.0
				var g := 2.0 * sin(PI * f * 3.0 * Synth.INV_RATE)
				low += g * band
				band += g * (x - low - 0.25 * band)
				var creak := rng.randf_range(-1.0, 1.0) * 0.08 if rng.randf() < 0.004 else 0.0
				buf[i] = band + creak
		"net":
			var f := _hz(44)
			for i in n:
				var t := i * Synth.INV_RATE
				phase = fposmod(phase + f * Synth.INV_RATE, 1.0)
				tone += ((2.0 * phase - 1.0) - tone) * 0.25
				var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.02 else 0.0
				buf[i] = tone * (0.6 + 0.4 * sin(TAU * 60.0 * t)) + crackle * 0.6
		"riser":
			var p2 := 0.0
			for i in n:
				var x := float(i) / n
				var f := _hz(lerpf(56.0, 74.0, x * x))
				phase += TAU * f * Synth.INV_RATE
				p2 += TAU * f * 1.5 * Synth.INV_RATE
				var shimmer := 0.75 + 0.25 * sin(TAU * lerpf(4.0, 16.0, x) * i * Synth.INV_RATE)
				buf[i] = (sin(phase) + 0.5 * sin(p2)) * shimmer * (0.2 + 0.8 * x)
		"crater":
			var f := _hz(56)
			for i in n:
				var t := i * Synth.INV_RATE
				var burn := 0.6 + 0.4 * sin(TAU * 1.1 * t)
				if i >= next_grain:
					grain = rng.randf_range(0.5, 1.0)
					next_grain = i + int(Synth.seconds(lerpf(0.05, 0.02, burn) * rng.randf_range(0.7, 1.3)))
				grain *= 0.993
				var x := rng.randf_range(-1.0, 1.0) * grain
				var g := 2.0 * sin(PI * 4200.0 * Synth.INV_RATE)
				low += g * band
				band += g * (x - low - 0.65 * band)
				phase = fposmod(phase + f * Synth.INV_RATE, 1.0)
				tone += ((2.0 * phase - 1.0) - tone) * 0.05
				buf[i] = band * 0.55 + tone * 1.3
	for i in mini(n, 400):
		buf[i] *= float(i) / 400.0
	return Synth.declick(Synth.normalize(buf, 0.9), 64, 600)


func _shop_bell() -> PackedFloat32Array:
	return _mix([[_fm(0.6, _hz(93), 3.5, 2.0, 5.0), 0, 0.6], [_cut(_n("beep", 86), 0.12), Synth.seconds(0.16), 0.9],
		[_cut(_n("mallet", 86), 0.12), Synth.seconds(0.16), 0.5], [_cut(_n("beep", 86), 0.2), Synth.seconds(0.34), 0.9],
		[_cut(_n("mallet", 86), 0.2), Synth.seconds(0.34), 0.5]])


func _bet_clunk() -> PackedFloat32Array:
	return _mix([[Synth.drum("anvil"), 0, db_to_linear(-6.0)], [_cut(_n("fbass", 38), 0.16), 0, 0.9],
		[_cut(_n("fbass", 44), 0.22), Synth.seconds(0.1), 0.9]])


static func _bet_roll() -> PackedFloat32Array:
	var parts := []
	var at := 0.0
	var gap := 0.174
	var i := 0
	while at < 0.35:
		parts.append([Synth.drum("snare"), Synth.seconds(at), 0.5 + 0.05 * i])
		at += gap
		gap = maxf(0.0435, gap * 0.78)
		i += 1
	return _mix(parts)


func _bet_crack() -> PackedFloat32Array:
	return _mix([[Synth.drum("snare"), 0, 1.0], [_cut(_n("fbass", 45), 0.24), 0, 0.9],
		[_cut(_n("beep", 81), 0.12), Synth.seconds(0.1), 0.8], [_cut(_n("mallet", 81), 0.12), Synth.seconds(0.1), 0.45],
		[_cut(_n("beep", 86), 0.2), Synth.seconds(0.26), 0.9], [_cut(_n("mallet", 86), 0.2), Synth.seconds(0.26), 0.5]])


func _bet_refusal() -> PackedFloat32Array:
	return _mix([[_noise(0.04, 3000.0, 3000.0, 150.0), 0, 0.5], [_cut(_n("fbass", 43), 0.3), 0, 0.85]])


func _sunken_bell() -> PackedFloat32Array:
	var bell := _mix([[_n("bell", 69), 0, 0.85], [_n("bell", 62), Synth.seconds(0.22), 1.0]])
	var low := 0.0
	var g := 2.0 * sin(PI * 900.0 * Synth.INV_RATE)
	for i in bell.size():
		low += g * (bell[i] - low)
		bell[i] = low
	return _cut(bell, 2.0)


func _ally_hum(class_id: String) -> PackedFloat32Array:
	return _score(motif_score(class_id, 0, "chime", 0.7, 12), 1.4)


func _ally_wake() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 86), 0.1), 0, 0.8], [_cut(_n("bell", 81), 0.12), Synth.seconds(0.04), 0.7],
		[_cut(_n("bell", 86), 0.16), Synth.seconds(0.08), 0.9]])


func _fight_arm_stamp() -> PackedFloat32Array:
	return _mix([[Synth.drum("anvil"), 0, 1.0], [_n("brass", 50), 0, 0.5],
		[_n("brass", 51), Synth.seconds(0.12), 0.4]], true)


func _near_miss_whip(class_id: String) -> PackedFloat32Array:
	var notes := whip_notes(class_id)
	return _mix([[_noise(0.22, 700.0, 4800.0, 9.0, 0.04), 0, 0.85],
		[_cut(_n(notes[0], notes[1]), 0.16), 0, 0.8], [_cut(_n(notes[0], notes[2]), 0.22), Synth.seconds(0.09), 0.85]])


func _pickup_fountain() -> PackedFloat32Array:
	var step := Synth.seconds(0.075)
	var parts: Array = []
	var notes := [74, 77, 79, 81]
	for i in notes.size():
		parts.append([_cut(_n("mallet", notes[i]), 0.2), i * step, 0.75 + 0.07 * i])
		parts.append([_cut(_n("bell", notes[i] + 12), 0.2), i * step, 0.25])
	parts.append([_noise(0.08, 5200.0, 3200.0, 30.0), 3 * step, 0.3])
	return _mix(parts)


func _synergy_fired() -> PackedFloat32Array:
	var score := [[0, 69, 2, "mallet", 0.72], [1, 86, 2, "bell", 0.62], [3, 77, 5, "mallet", 0.85], [3, 77, 5, "bell", 0.44],
		[3, 77, 5, "lead", 0.34], [3, 65, 5, "keys", 0.38], [3, 62, 5, "keys", 0.34], [3, 69, 5, "keys", 0.3]]
	return _score(score, 0.05)


func _evolution_fired() -> PackedFloat32Array:
	var score := [[0, 69, 2, "mallet", 0.72], [2, 74, 2, "mallet", 0.82], [4, 86, 4, "mallet", 0.9], [4, 86, 4, "bell", 0.54],
		[4, 74, 4, "lead", 0.36], [4, 62, 4, "brass", 0.28], [4, 74, 4, "keys", 0.36], [4, 62, 4, "sub808", 0.45]]
	return _score(score, 0.05)


func _lore_found() -> PackedFloat32Array:
	return _mix([[_noise(0.14, 3000.0, 1200.0, 18.0, 0.03), 0, 0.3],
		[_cut(_n("keys", 81), 0.3), 0, 0.8], [_cut(_n("keys", 77), 0.4), Synth.seconds(0.2), 0.7],
		[_cut(_n("bell", 74), 0.45), Synth.seconds(0.42), 0.35]])


func _pilot_unlocked(class_id: String) -> PackedFloat32Array:
	var row := Harmony.motif_or_first(class_id)
	var score := motif_score(class_id, 0, row["voice"], 0.8)
	score.append_array(motif_score(class_id, 0, "bell", 0.25, 12))
	return _cut(_score(score, 0.4), 0.85, Synth.seconds(0.12))


func _kill_chain_tier() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 74), 0.14), 0, 0.85], [_cut(_n("bell", 77), 0.14), 0, 0.7],
		[_noise(0.03, 5500.0, 4000.0, 130.0), 0, 0.4]])


func _drop_landing() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 74), 0.3), 0, 0.85], [_tone(0.12, 260.0, 620.0, "sine", 26.0), Synth.seconds(0.02), 0.7],
		[_noise(0.03, 5000.0, 3000.0, 120.0), 0, 0.4]])


static func _shell_spring() -> PackedFloat32Array:
	return _mix([[_tone(0.16, 240.0, 620.0, "sine", 14.0), 0, 0.9], [_tone(0.22, 620.0, 410.0, "sine", 16.0), Synth.seconds(0.05), 0.6],
		[_noise(0.02, 4500.0, 3000.0, 200.0), 0, 0.3]])


func _door_tick() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 86), 0.08), 0, 0.8], [_noise(0.015, 6500.0, 6500.0, 250.0), 0, 0.35]])


func _return_launch_arpeggio() -> PackedFloat32Array:
	return _arpeggio(Harmony.LAUNCH_TUNE, 0.07, "mallet", 0.5)


func _arena_lock_slam() -> PackedFloat32Array:
	return _mix([[_noise(0.5, 180.0, 60.0, 7.0), 0, 1.0],
		[_tone(0.7, _hz(38), _hz(31), "sine", 4.0), 0, 0.9],
		[_tone(0.18, _hz(62), 0.0, "square_dark", 9.0), Synth.seconds(0.06), 0.45],
		[_tone(0.36, _hz(59), 0.0, "square_dark", 6.0), Synth.seconds(0.22), 0.5],
		[_noise(0.06, 3200.0, 1800.0, 60.0), Synth.seconds(0.02), 0.35]], true)


func _arena_wave_whistle() -> PackedFloat32Array:
	return _mix([[_tone(0.9, _hz(86), _hz(74), "sine", 2.0), 0, 0.8],
		[_noise(0.04, 1400.0, 900.0, 60.0), 0, 0.4], [_noise(0.04, 1400.0, 900.0, 60.0), Synth.seconds(0.45), 0.4]])


func _arena_unlock_bells() -> PackedFloat32Array:
	var score := [[0, 69, 1, "mallet", 0.62], [1, 72, 1, "mallet", 0.68], [2, 74, 4, "bell", 0.82],
		[2, 86, 4, "bell", 0.32], [2, 62, 4, "keys", 0.28], [2, 69, 4, "keys", 0.24]]
	return _mix([[_noise(0.04, 2800.0, 1400.0, 80.0), 0, 0.5],
		[_score(score, 0.05), Synth.seconds(0.04), 1.0]])


func _warden_gate_pip() -> PackedFloat32Array:
	return _mix([[_fm(0.32, _hz(74), 2.0, 1.4, 9.0), 0, 1.0], [_noise(0.03, 3600.0, 2400.0, 90.0), 0, 0.3]])


func _warden_gate_clunk() -> PackedFloat32Array:
	return _mix([[_noise(0.12, 420.0, 260.0, 30.0), 0, 1.0], [_tone(0.14, _hz(45), _hz(43), "square_dark", 22.0), 0, 0.6]])


func _warden_gate_release() -> PackedFloat32Array:
	var parts := []
	for i in 6:
		parts.append([_noise(0.03, 2200.0 + 300.0 * i, 1200.0, 80.0), Synth.seconds(0.05 * i), 0.5])
	var chord := [[0, 62, 6, "keys", 0.45], [0, 66, 6, "keys", 0.4], [0, 69, 6, "keys", 0.4], [0, 76, 6, "keys", 0.3],
		[0, 74, 6, "bell", 0.62], [0, 86, 6, "bell", 0.3], [0, 38, 6, "sub", 0.62]]
	parts.append([_score(chord, 0.05), Synth.seconds(0.3), 1.0])
	return _mix(parts)


func _call_ink() -> PackedFloat32Array:
	var score := [[0, 62, 1, "brass", 0.6], [1, 69, 3, "brass", 0.75]]
	return _mix([[_noise(0.06, 900.0, 500.0, 45.0), 0, 0.7], [_tone(0.08, _hz(38), _hz(36), "sine", 30.0), 0, 0.6],
		[_score(score, 0.05), Synth.seconds(0.03), 1.0]])


func _call_drop() -> PackedFloat32Array:
	return _mix([[_tone(0.34, _hz(57), _hz(52), "square_dark", 9.0), 0, 0.8], [_noise(0.05, 600.0, 300.0, 50.0), 0, 0.3]])


func _heat_kettle() -> PackedFloat32Array:
	var n := Synth.seconds(2.0)
	var whistle := _tone(2.0, _hz(86), _hz(92), "sine", 0.0)
	var breath := _noise(2.0, 5200.0, 7400.0, 0.0, 0.3)
	for i in n:
		var swell := 0.25 + 0.75 * float(i) / n
		whistle[i] *= swell
		breath[i] *= swell
	return _mix([[whistle, 0, 0.8], [breath, 0, 0.18]])


func _overtime_offer() -> PackedFloat32Array:
	var score := [[0, 69, 1, "mallet", 0.6], [1, 72, 1, "mallet", 0.65], [2, 76, 3, "bell", 0.55]]
	return _mix([[_score(score, 0.1), 0, 1.0]])


func _overtime_ring() -> PackedFloat32Array:
	var toll := [[0, 50, 6, "bell", 0.8], [0, 38, 6, "sub", 0.6], [3, 62, 3, "bell", 0.6], [3, 68, 3, "bell", 0.5]]
	return _mix([[_score(toll, 0.15), 0, 1.0], [_noise(0.5, 500.0, 3600.0, 0.0, 0.3), 0, 0.35]])


func _overtime_pay() -> PackedFloat32Array:
	var parts := []
	for i in 5:
		parts.append([_noise(0.025, 3600.0 + 400.0 * i, 2400.0, 90.0), Synth.seconds(0.04 * i), 0.4])
	var chord := [[0, 62, 5, "keys", 0.5], [0, 66, 5, "keys", 0.4], [0, 69, 5, "keys", 0.4], [0, 76, 5, "keys", 0.3],
		[0, 78, 5, "bell", 0.55], [0, 86, 5, "bell", 0.32]]
	parts.append([_score(chord, 0.1), Synth.seconds(0.2), 1.0])
	return _mix(parts)


func _heat_rise() -> PackedFloat32Array:
	var sweep := _fm_sweep(0.5, 180.0, 900.0, 2.5, 3.0)
	var hiss := _noise(0.5, 1200.0, 5200.0, 0.0, 0.3)
	var n := hiss.size()
	for i in n:
		hiss[i] *= float(i) / n
	var tail := [[0, 69, 2, "brass", 0.55]]
	return _mix([[sweep, 0, 0.7], [hiss, 0, 0.25], [_score(tail, 0.1), Synth.seconds(0.35), 0.8]])


static func _heat_cool() -> PackedFloat32Array:
	var sweep := _fm_sweep(0.55, 700.0, 150.0, 1.5, 4.0)
	return _mix([[sweep, 0, 0.6], [_noise(0.5, 4200.0, 900.0, 5.0, 0.01), 0, 0.3]])


func _heat_hot_hit() -> PackedFloat32Array:
	return _mix([[_fm(0.3, _hz(60), 1.41, 5.0, 12.0), 0, 0.9], [_noise(0.3, 6200.0, 2600.0, 10.0, 0.002), 0, 0.5],
		[_tone(0.14, _hz(40), _hz(36), "sine", 20.0), 0, 0.7]])


static func _arch(buf: PackedFloat32Array, peak := 0.5) -> PackedFloat32Array:
	var n := buf.size()
	for i in n:
		var x := float(i) / n
		buf[i] *= x / peak if x < peak else (1.0 - x) / (1.0 - peak)
	return buf


func _tele_open() -> PackedFloat32Array:
	return _mix([[_tone(0.1, _hz(50), _hz(50), "square_dark", 12.0), 0, 0.8],
		[_tone(0.14, _hz(51), _hz(52), "square_dark", 10.0), Synth.seconds(0.11), 0.85]], true)


func _tele_crane_sweep() -> PackedFloat32Array:
	var air := _arch(_noise(0.55, 500.0, 3200.0, 0.0, 0.05), 0.45)
	var sweep := _arch(_tone(0.5, _hz(62), _hz(74), "saw_dark", 0.0), 0.5)
	return _mix([[_tele_open(), 0, 0.8], [air, Synth.seconds(0.12), 0.6], [sweep, Synth.seconds(0.12), 0.25]])


func _tele_slag_ring() -> PackedFloat32Array:
	var bubble := _arch(_noise(0.5, 160.0, 420.0, 0.0, 0.1), 0.4)
	for i in bubble.size():
		bubble[i] *= 0.6 + 0.4 * sin(TAU * 16.0 * i * Synth.INV_RATE)
	return _mix([[_tele_open(), 0, 0.8], [bubble, Synth.seconds(0.1), 0.7],
		[_tone(0.4, _hz(38), _hz(43), "sine", 3.0), Synth.seconds(0.1), 0.6],
		[_cut(_n("bell", 74), 0.3), Synth.seconds(0.28), 0.5], [_cut(_n("bell", 81), 0.3), Synth.seconds(0.4), 0.45]])


func _tele_charge() -> PackedFloat32Array:
	var parts := [[_tele_open(), 0, 0.8]]
	var at := 0.3
	var gap := 0.11
	for i in 6:
		parts.append([_tone(0.05, _hz(45 + i * 2), _hz(45 + i * 2), "square_dark", 30.0), Synth.seconds(at), 0.7])
		at += gap
		gap *= 0.8
	parts.append([_tone(0.25, _hz(57), _hz(69), "saw_dark", 5.0), Synth.seconds(at), 0.5])
	return _mix(parts, true)


func _tele_charge_wall() -> PackedFloat32Array:
	var parts := [[_tele_open(), 0, 0.8]]
	var at := 0.3
	for i in 4:
		parts.append([_tone(0.06, _hz(48 - i * 2), _hz(48 - i * 2), "square_dark", 26.0), Synth.seconds(at), 0.7])
		at += 0.12
	parts.append([_fm(0.4, _hz(46), 1.41, 4.0, 9.0), Synth.seconds(at), 0.9])
	parts.append([_tone(0.16, _hz(38), _hz(34), "sine", 14.0), Synth.seconds(at), 0.7])
	return _mix(parts, true)


func _tele_eject() -> PackedFloat32Array:
	return _mix([[_tele_open(), 0, 0.8], [_fm_sweep(0.4, 450.0, 1900.0, 0.6, 2.5), Synth.seconds(0.28), 0.55],
		[_tone(0.07, _hz(86), _hz(74), "sine", 40.0), Synth.seconds(0.66), 0.7]], true)


func _sluice_siren_two_tone() -> PackedFloat32Array:
	var parts := [[_arch(_noise(0.9, 300.0, 1100.0, 0.0, 0.2), 0.6), 0, 0.22]]
	for i in 4:
		parts.append([_fm(0.2, _hz(74 if i % 2 == 0 else 67), 1.0, 1.2, 6.0), Synth.seconds(i * 0.21), 0.8])
	return _mix(parts)


func _ride_rolling_metal() -> PackedFloat32Array:
	var rumble := _noise(0.5, 250.0, 900.0, 0.0, 0.05)
	for i in rumble.size():
		rumble[i] *= 0.55 + 0.45 * sin(TAU * 22.0 * i * Synth.INV_RATE)
	return _mix([[_arch(rumble, 0.3), 0, 0.8], [_arch(_tone(0.5, _hz(43), _hz(43), "saw_dark", 0.0), 0.3), 0, 0.35]])


func _ride_bowl_carve() -> PackedFloat32Array:
	return _mix([[_arch(_noise(0.55, 700.0, 1800.0, 0.0, 0.1), 0.5), 0, 0.5],
		[_arch(_tone(0.55, _hz(55), _hz(64), "sine", 0.0), 0.5), 0, 0.8]])


static func _ride_drop_swoop() -> PackedFloat32Array:
	return _mix([[_fm_sweep(0.45, 1500.0, 220.0, 0.8, 4.0), 0, 0.8], [_noise(0.4, 3200.0, 500.0, 5.0, 0.02), 0, 0.4]])


func _ride_ledge_scuff() -> PackedFloat32Array:
	return _mix([[_noise(0.2, 1800.0, 800.0, 14.0, 0.004), 0, 0.8], [_tone(0.1, _hz(45), _hz(41), "sine", 25.0), 0, 0.5]])


static func _ride_hop_lift() -> PackedFloat32Array:
	return _mix([[_tone(0.16, 330.0, 760.0, "sine", 9.0), 0, 0.8], [_noise(0.05, 3000.0, 5000.0, 40.0, 0.001), 0, 0.3]])


func _ride_cable_clink() -> PackedFloat32Array:
	return _mix([[_fm(0.16, _hz(86), 2.76, 2.0, 22.0), 0, 0.8], [_fm(0.2, _hz(91), 2.76, 2.0, 20.0), Synth.seconds(0.08), 0.7]])


func _ride_sheet_swell() -> PackedFloat32Array:
	var water := _noise(0.7, 350.0, 1900.0, 0.0, 0.3)
	var n := water.size()
	for i in n:
		water[i] *= float(i) / n
	return _mix([[water, 0, 0.7], [_tone(0.7, _hz(50), _hz(57), "sine", -2.0), 0, 0.5]])


static func _steam_whistle_rise() -> PackedFloat32Array:
	return _mix([[_fm(0.7, 520.0, 1.0, 0.5, 0.0, 7.0), 0, 0.8], [_noise(0.7, 4200.0, 5500.0, 0.0, 0.2), 0, 0.2]])


func _cannon_bang_rail_whoosh() -> PackedFloat32Array:
	return _mix([[_noise(0.1, 2400.0, 900.0, 25.0, 0.001), 0, 0.9], [_tone(0.2, _hz(45), _hz(33), "sine", 12.0), 0, 0.9],
		[_arch(_noise(0.5, 900.0, 3800.0, 0.0, 0.05), 0.25), Synth.seconds(0.08), 0.5]], true)


func _sluice_gush_roar() -> PackedFloat32Array:
	return _mix([[_noise(0.95, 220.0, 1700.0, 2.2, 0.04), 0, 0.9], [_tone(0.8, _hz(40), _hz(34), "sine", 2.5), 0, 0.8]])


func _lounge_flip() -> PackedFloat32Array:
	var parts := [[_noise(0.9, 3000.0, 5000.0, 3.0, 0.01), 0, 0.12], [_tone(0.09, _hz(43), _hz(38), "sine", 30.0), 0, 0.8],
		[_noise(0.03, 2000.0, 900.0, 80.0, 0.001), 0, 0.5]]
	var tune := [[69, 0.12, 0.22], [74, 0.26, 0.22], [77, 0.4, 0.22], [76, 0.54, 0.16], [74, 0.68, 0.48]]
	for note in tune:
		parts.append([_cut(_n("keys", note[0]), note[2]), Synth.seconds(note[1]), 0.62])
	for chord_midi in [50, 57, 65, 69]:
		parts.append([_cut(_n("keys", chord_midi), 0.48, 1800), Synth.seconds(0.68), 0.22])
	return _mix(parts)


func _bay_bell_ring() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 79), 1.0, 2400), 0, 0.8], [_fm(0.9, _hz(86), 2.76, 1.2, 4.5), 0, 0.35],
		[_noise(0.01, 3000.0, 3000.0, 200.0, 0.001), 0, 0.3]])


func _marble_tick_ladder() -> PackedFloat32Array:
	return _mix([[_fm(0.12, _hz(91), 3.5, 1.0, 26.0), 0, 0.8], [_noise(0.012, 5000.0, 4000.0, 200.0, 0.001), 0, 0.3]])


func _pins_crash() -> PackedFloat32Array:
	var parts := [[_noise(0.12, 2600.0, 1100.0, 22.0, 0.001), 0, 0.9], [_tone(0.22, _hz(46), _hz(38), "sine", 12.0), 0, 0.6]]
	var at := 0.06
	for i in 4:
		parts.append([_noise(0.05, 1800.0 - i * 220.0, 900.0, 40.0, 0.001), Synth.seconds(at), 0.6 - i * 0.08])
		at += 0.05 + i * 0.025
	return _mix(parts, true)


func _bay_lounge_in() -> PackedFloat32Array:
	return _mix([[_arch(_noise(0.5, 400.0, 1500.0, 0.0, 0.05), 0.5), 0, 0.15], [_cut(_n("keys", 67), 0.35), 0, 0.6],
		[_cut(_n("keys", 74), 0.52, 1800), Synth.seconds(0.1), 0.68],
		[_cut(_n("keys", 62), 0.52, 1800), Synth.seconds(0.1), 0.26],
		[_cut(_n("keys", 69), 0.52, 1800), Synth.seconds(0.1), 0.24]])


func _bay_slingshot_out() -> PackedFloat32Array:
	return _mix([[_tone(0.16, _hz(62), _hz(55), "saw_dark", 6.0), 0, 0.4], [_fm_sweep(0.3, 300.0, 2500.0, 0.6, 7.0), Synth.seconds(0.16), 0.7],
		[_noise(0.25, 800.0, 4000.0, 9.0, 0.01), Synth.seconds(0.16), 0.35]])


func _ultimate_ready() -> PackedFloat32Array:
	var parts := []
	var notes := [74, 77, 81, 86]
	for i in notes.size():
		parts.append([_cut(_n("mallet", notes[i]), 0.26), Synth.seconds(i * 0.06), 0.65 + 0.07 * i])
	for chord_midi in [62, 69, 76]:
		parts.append([_cut(_n("keys", chord_midi), 0.55, 1600), Synth.seconds(0.18), 0.28])
	parts.append([_cut(_n("bell", 86), 0.8, 2400), Synth.seconds(0.2), 0.85])
	parts.append([_cut(_n("bell", 93), 0.6, 2400), Synth.seconds(0.24), 0.36])
	parts.append([_fm_sweep(0.24, 300.0, 1400.0, 0.5, 6.0), 0, 0.28])
	return _mix(parts)


func _found_twinkle() -> PackedFloat32Array:
	return _mix([[_cut(_n("mallet", 86), 0.2), 0, 0.7], [_cut(_n("mallet", 89), 0.2), Synth.seconds(0.07), 0.72],
		[_cut(_n("bell", 93), 0.5, 1800), Synth.seconds(0.14), 0.82],
		[_cut(_n("keys", 74), 0.45, 1600), Synth.seconds(0.14), 0.24],
		[_cut(_n("keys", 81), 0.45, 1600), Synth.seconds(0.14), 0.22],
		[_noise(0.15, 6000.0, 6000.0, 22.0, 0.002), Synth.seconds(0.14), 0.15]])


func _drop_thud() -> PackedFloat32Array:
	return _mix([[_tone(0.16, _hz(55), _hz(41), "sine", 22.0), 0, 0.9], [_noise(0.05, 1400.0, 600.0, 60.0, 0.001), 0, 0.35],
		[_cut(_n("mallet", 62), 0.12), Synth.seconds(0.02), 0.3]])


func _drop_whiff() -> PackedFloat32Array:
	return _mix([[_noise(0.22, 3200.0, 900.0, 14.0, 0.02), 0, 0.5], [_tone(0.2, _hz(67), _hz(60), "sine", 14.0), Synth.seconds(0.03), 0.5]])


func _guard_creak() -> PackedFloat32Array:
	return _mix([[_tone(0.45, _hz(38), _hz(45), "saw_dark", 4.0), 0, 0.8], [_fm_sweep(0.4, 380.0, 1700.0, 0.7, 6.0), Synth.seconds(0.04), 0.5],
		[_noise(0.04, 3500.0, 2500.0, 90.0, 0.001), Synth.seconds(0.3), 0.5]])


func _callout_warden_chime() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 77), 0.4, 1800), 0, 0.8], [_cut(_n("bell", 74), 0.55, 1800), Synth.seconds(0.1), 0.75]])


func _beacon_open_chime() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 81), 0.5, 1800), 0, 0.8], [_cut(_n("bell", 88), 0.7, 2200), Synth.seconds(0.12), 0.85],
		[_cut(_n("bell", 93), 0.5, 2200), Synth.seconds(0.2), 0.3]])


func _gauge_dry_click() -> PackedFloat32Array:
	return _mix([[_noise(0.012, 3200.0, 2200.0, 160.0, 0.001), 0, 0.7], [_noise(0.012, 2800.0, 1800.0, 160.0, 0.001), Synth.seconds(0.07), 0.55],
		[_tone(0.1, _hz(55), _hz(50), "sine", 30.0), Synth.seconds(0.07), 0.5]])


static func _lift_hiss() -> PackedFloat32Array:
	var hiss := _noise(1.2, 500.0, 3200.0, 0.0, 0.05)
	var n := hiss.size()
	for i in n:
		var x := float(i) / n
		hiss[i] *= x * x
	return Synth.declick(Synth.normalize(hiss, 0.85), 64, 300)


func _pure_tone(midi: int, length: float) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var f := _hz(midi)
	for i in n:
		buf[i] = sin(TAU * f * i * Synth.INV_RATE) * minf(1.0, minf(i, n - 1 - i) / 130.0)
	return buf


func _world1_own(id: String) -> PackedFloat32Array:
	var motif_cue := _motif_cue_parts(id)
	if not motif_cue.is_empty():
		return _motif_cue(String(motif_cue[0]), String(motif_cue[1]))
	if id in MOTIF_CUES:
		return _motif_cue(id, "")
	var buf := _world1_recipe(id)
	return _cut(buf, LANDING_S, 2400) if id in LANDINGS else buf


const MOTIF_CUES := ["motif_accumulate", "motif_line", "motif_stinger"]
const LANDINGS := ["flood_drop", "fleet_anvil_brass_drop", "lightning_strike", "rockfall_boom", "crater_crump_sub_boom",
	"steam_whistle_percussion_drop", "ancient_family_drop", "sluice_valve_open"]
const LANDING_S := 0.8
const NEUTRAL_MOTIF := {"cells": [[0, 62, 1], [1, 69, 1], [2, 74, 2]], "voice": "mallet"}


static func motif_cue_id(cue: String, motif: String) -> String:
	return "%s_%s" % [cue, motif]


static func motif_cue_ids() -> Array:
	var ids: Array = []
	for cue in MOTIF_CUES:
		for motif in Harmony.CLASS_MOTIFS:
			ids.append(motif_cue_id(cue, motif))
	return ids


static func _motif_cue_parts(id: String) -> Array:
	for cue in MOTIF_CUES:
		var motif := id.trim_prefix(String(cue) + "_")
		if id.begins_with(String(cue) + "_") and motif in Harmony.CLASS_MOTIFS:
			return [cue, motif]
	return []


static func motif_cue_notes(motif: String) -> Array:
	var row: Dictionary = Harmony.MOTIFS.get(motif, NEUTRAL_MOTIF)
	return (row["cells"] as Array).map(func(cell): return int(cell[1]))


func _motif_cue(cue: String, motif: String) -> PackedFloat32Array:
	var row: Dictionary = Harmony.MOTIFS.get(motif, NEUTRAL_MOTIF)
	var voice := String(row["voice"])
	var notes := motif_cue_notes(motif)
	var unique: Array = []
	for note in notes:
		if not note in unique:
			unique.append(note)
	var root: int = unique.min()
	match cue:
		"motif_accumulate":
			var gap := 0.6 / float(maxi(1, notes.size() - 1))
			var parts: Array = [[_tone(0.9, _hz(root - 12), _hz(root - 12), "sine", 1.0), 0, 0.25]]
			for i in notes.size():
				parts.append([_cut(_n(voice, notes[i]), 0.3), Synth.seconds(gap * i), 0.45 + 0.5 * float(i) / float(notes.size())])
			return _mix(parts)
		"motif_line":
			var second: int = unique[1] if unique.size() > 1 else unique[0] + 12
			return _mix([[_fm(0.05, _hz(81), 2.0, 3.0, 60.0), 0, 0.6], [_noise(0.015, 3000.0, 2000.0, 200.0), 0, 0.4],
				[_cut(_n(voice, notes[0]), 0.15), Synth.seconds(0.02), 0.7], [_cut(_n(voice, second), 0.25), Synth.seconds(0.09), 0.8]])
		_:
			var parts: Array = [[_noise(0.03, 5000.0, 2500.0, 90.0, 0.0005), 0, 0.5], [_cut(Synth.crash(), 0.8, 2400), 0, 0.3],
				[_tone(0.6, _hz(root - 12), _hz(root - 12), "sine", 4.0), 0, 0.5]]
			for note in unique:
				parts.append([_cut(_n(voice, note), 0.7, 2400), 0, 0.5])
				parts.append([_cut(_n("bell", note + 12), 0.7, 2400), 0, 0.25])
			return _mix(parts)


func _world1_recipe(id: String) -> PackedFloat32Array:
	match id:
		"flood_falling_pure":
			return _mix([[_pure_fall(1.0, 70, 63, 1.4, 5.0, 0.25), 0, 1.0], [_noise(1.0, 250.0, 700.0, 2.0, 0.15), 0, 0.3]])
		"fleet_falling_pure":
			return _mix([[_cut(Synth.drum("anvil"), 0.1), 0, 0.45], [_cut(Synth.drum("anvil"), 0.1), Synth.seconds(0.09), 0.4],
				[_pure_fall(0.8, 80, 68, 1.8), Synth.seconds(0.15), 1.0]])
		"boiler_falling_pure":
			return _mix([[_pure_fall(0.75, 94, 87, 2.0, 7.0, 0.12), 0, 1.0]])
		"lightning_falling_pure":
			var parts: Array = [[_pure_fall(0.6, 94, 75, 3.0), 0, 1.0]]
			var rng := RandomNumberGenerator.new()
			rng.seed = 7311
			for i in 6:
				parts.append([_noise(0.008, 6000.0, 4000.0, 300.0, 0.0005), Synth.seconds(rng.randf_range(0.0, 0.5)), 0.35])
			return _mix(parts)
		"ancient_falling_pure":
			return _mix([[_pure_fall(1.2, 75, 68, 1.2), 0, 1.0], [_tone(1.2, _hz(44), _hz(44), "sine", 1.5), 0, 0.2]])
		"rock_grind_dust_hiss":
			return _rock_grind_dust_hiss()
		"flood_drop":
			return _mix([[_tone(0.3, 80.0, 38.0, "sine", 9.0), 0, 1.0], [_noise(0.9, 2200.0, 300.0, 3.5, 0.01), 0, 0.8],
				[_noise(0.4, 600.0, 1800.0, 6.0, 0.03), Synth.seconds(0.05), 0.4]], true)
		"fleet_anvil_brass_drop":
			var gap := 0.12
			return _mix([[Synth.drum("anvil"), 0, 1.0], [Synth.drum("boom"), 0, 0.7], [_cut(_n("brass", 51), 0.25), Synth.seconds(gap), 0.6],
				[_cut(_n("brass", 50), 0.5), Synth.seconds(gap + 0.22), 0.6]], true)
		"lightning_strike":
			return _mix([[_noise(0.05, 6000.0, 3000.0, 60.0, 0.0005), 0, 1.0], [_tone(0.25, _hz(45), _hz(43), "saw", 10.0), 0, 0.4],
				[_noise(0.8, 300.0, 90.0, 4.0, 0.01), Synth.seconds(0.03), 0.7], [_tone(0.4, 70.0, 35.0, "sine", 8.0), 0, 0.7]], true)
		"rockfall_boom":
			return _rockfall_boom()
		"crater_crump_sub_boom":
			return _mix([[_noise(0.18, 700.0, 140.0, 14.0, 0.001), 0, 1.0], [_tone(0.12, 160.0, 70.0, "square_dark", 25.0), 0, 0.5],
				[_tone(0.95, 52.0, 27.0, "sine", 3.2), Synth.seconds(0.02), 1.0]], true)
		"steam_whistle_percussion_drop":
			return _mix([[Synth.drum("boom"), 0, 0.9], [_cut(Synth.drum("snare"), 0.25), 0, 0.6], [_noise(0.6, 4800.0, 2000.0, 4.0, 0.005), 0, 0.4],
				[_pure_fall(0.55, 80, 75, 3.0), Synth.seconds(0.03), 0.45]], true)
		"ancient_family_drop":
			var parts: Array = [[_tone(0.25, 90.0, 45.0, "sine", 10.0), 0, 0.8], [_tone(1.2, _hz(44), _hz(44), "sine", 2.2), 0, 0.6]]
			for midi in [68, 75, 80]:
				parts.append([_tone(1.2, _hz(midi), _hz(midi), "sine", 2.0), Synth.seconds(0.02), 0.35])
			return _mix(parts)
		"cracked_wall_crumble":
			return _cracked_wall_crumble()
		"kest_snare_crack":
			return _mix([[_cut(Synth.drum("snare"), 0.18), 0, 1.0], [_fm(0.14, _hz(93), 3.0, 2.5, 22.0), 0, 0.6],
				[_noise(0.02, 7000.0, 5000.0, 200.0), 0, 0.4]])
		"companion_chirp_escape":
			return _mix([[_cut(_n("mallet", 79), 0.1), 0, 0.6], [_cut(_n("mallet", 86), 0.1), Synth.seconds(0.05), 0.65],
				[_cut(_n("mallet", 91), 0.18), Synth.seconds(0.1), 0.7], [_noise(0.2, 1500.0, 5000.0, 12.0, 0.02), 0, 0.25]])
		"kest_blast_lift":
			return _mix([[Synth.kick(), 0, 0.8], [_noise(0.05, 4000.0, 1500.0, 70.0, 0.001), 0, 0.6],
				[_noise(0.45, 500.0, 3500.0, 6.0, 0.04), Synth.seconds(0.03), 0.8], [_tone(0.35, 55.0, 110.0, "sine", 6.0), Synth.seconds(0.03), 0.5]])
		"kest_falling_triad":
			return _mix([[_cut(_n("tom", 62), 0.3), 0, 0.8], [_cut(_n("tom", 57), 0.3), Synth.seconds(0.09), 0.85],
				[_cut(_n("tom", 53), 0.35), Synth.seconds(0.18), 0.95], [_tone(0.35, _hz(38), _hz(36), "sine", 6.0), Synth.seconds(0.18), 0.6]])
		"kest_muffled_thump":
			return _mix([[_tone(0.17, _hz(50), _hz(45), "sine", 18.0), 0, 1.0], [_noise(0.05, 350.0, 200.0, 40.0), 0, 0.3]])
		"line_load":
			return _mix([[_noise(0.01, 2600.0, 1800.0, 250.0, 0.0005), 0, 0.6], [_noise(0.01, 2200.0, 1500.0, 250.0, 0.0005), Synth.seconds(0.04), 0.5],
				[_fm(0.1, _hz(81), 1.0, 0.8, 40.0), Synth.seconds(0.04), 0.7]])
		"pin_double_thwack":
			return _mix([[_noise(0.1, 1300.0, 700.0, 35.0), 0, 0.7], [_tone(0.1, 230.0, 85.0, "sine", 30.0), 0, 1.0],
				[_noise(0.1, 1750.0, 900.0, 35.0), Synth.seconds(0.09), 0.7], [_tone(0.12, 307.0, 113.0, "sine", 28.0), Synth.seconds(0.09), 1.0]], true)
		"rebound_spring_snap":
			return _mix([[_tone(0.05, 180.0, 120.0, "sine", 40.0), 0, 0.6], [_noise(0.04, 800.0, 400.0, 60.0), 0, 0.3],
				[_tone(0.06, _hz(74), _hz(86), "sine", 25.0), Synth.seconds(0.04), 0.9], [_fm(0.14, _hz(86), 1.0, 0.6, 22.0), Synth.seconds(0.08), 0.5],
				[_noise(0.015, 5000.0, 3500.0, 250.0), Synth.seconds(0.04), 0.3]])
		"rivet_cymbal_choke":
			return _mix([[_cut(Synth.crash(), 0.09, 900), 0, 0.9], [_cut(Synth.drum("hat"), 0.05), Synth.seconds(0.06), 0.4]])
		"rivet_snare_flam":
			return _mix([[_cut(Synth.drum("snare"), 0.2), 0, 0.45], [_cut(Synth.drum("snare"), 0.25), Synth.seconds(0.03), 1.0],
				[_noise(0.2, 3000.0, 900.0, 14.0, 0.005), 0, 0.3]])
		"sable_root_fifth":
			return _mix([[_cut(_n("mallet", 50), 0.45, 1200), 0, 0.9], [_cut(_n("mallet", 57), 0.45, 1200), Synth.seconds(0.03), 0.8],
				[_cut(_n("mallet", 62), 0.35), Synth.seconds(0.06), 0.35]])
		"kindness_chime":
			var step_s := float(Harmony.STEP) / float(Harmony.RATE)
			return _mix([[_pure_tone(74, step_s * 0.7), 0, 0.85],
				[_pure_tone(81, step_s * 0.7), Synth.seconds(step_s), 0.9],
				[_pure_tone(86, step_s * 1.4), Synth.seconds(step_s * 2.0), 0.75]])
		"sluice_valve_warning":
			return _mix([[_noise(0.025, 3200.0, 1800.0, 110.0, 0.002), 0, 0.55],
				[_noise(0.025, 3600.0, 2000.0, 110.0, 0.002), Synth.seconds(0.08), 0.55],
				[_noise(0.7, 1600.0, 3200.0, 2.2, 0.08), Synth.seconds(0.04), 0.35],
				[_pure_fall(0.72, 80, 75, 1.9, 6.0, 0.18), Synth.seconds(0.06), 1.0]])
		"sluice_valve_open":
			return _mix([[_fm(0.09, 340.0, 2.7, 3.0, 28.0), 0, 0.75],
				[_tone(0.28, 95.0, 40.0, "sine", 9.5), 0, 0.95],
				[_noise(0.75, 2600.0, 450.0, 3.8, 0.015), Synth.seconds(0.02), 0.85],
				[_noise(0.45, 500.0, 1600.0, 5.0, 0.04), Synth.seconds(0.08), 0.45]], true)
		"quick_sync_horn":
			return _mix([[_noise(0.02, 2800.0, 1400.0, 120.0, 0.002), 0, 0.45],
				[_cut(_n("brass", 62), 0.14, 1200), 0, 0.85],
				[_cut(_n("brass", 69), 0.14, 1200), Synth.seconds(0.06), 0.9],
				[_cut(_n("brass", 74), 0.24, 1600), Synth.seconds(0.12), 0.95]])
		"shift_over_sigh":
			return _mix([[_noise(0.68, 3600.0, 650.0, 3.2, 0.04), 0, 0.75],
				[_pure_fall(0.58, 72, 60, 2.8), Synth.seconds(0.02), 0.55],
				[_fm(0.04, 1480.0, 2.3, 1.5, 45.0), Synth.seconds(0.03), 0.55],
				[_fm(0.045, 1340.0, 2.3, 1.5, 42.0), Synth.seconds(0.13), 0.5],
				[_fm(0.055, 1180.0, 2.3, 1.5, 36.0), Synth.seconds(0.26), 0.42],
				[_fm(0.07, 1020.0, 2.3, 1.5, 30.0), Synth.seconds(0.43), 0.35]])
	return PackedFloat32Array()


func _pure_fall(length: float, from_midi: float, to_midi: float, decay: float, wobble_hz := 0.0, wobble := 0.0) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var f0 := _hz(from_midi)
	var f1 := _hz(to_midi)
	var phase := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		var f := f0 * pow(f1 / f0, float(i) / n) * Harmony.ratio(wobble * sin(TAU * wobble_hz * t))
		phase = fposmod(phase + f * Synth.INV_RATE, 1.0)
		buf[i] = sin(TAU * phase) * minf(1.0, t * 40.0) * exp(-t * decay)
	return Synth.declick(buf, 8, 600)


func _rock_grind_dust_hiss() -> PackedFloat32Array:
	var grind := _noise(1.3, 150.0, 380.0, 0.8, 0.15)
	for i in grind.size():
		var t := i * Synth.INV_RATE
		grind[i] *= 0.6 + 0.4 * sin(TAU * 7.0 * t + 2.0 * sin(TAU * 2.3 * t))
	return _mix([[grind, 0, 1.0], [_noise(1.3, 3500.0, 6000.0, 0.5, 0.6), 0, 0.35], [_tone(1.2, _hz(44), _hz(43), "saw_dark", 2.0), 0, 0.25]])


static func _rockfall_boom() -> PackedFloat32Array:
	var parts: Array = [[_tone(0.6, 65.0, 30.0, "sine", 5.5), 0, 1.0], [_noise(0.12, 1400.0, 500.0, 25.0, 0.001), 0, 0.7],
		[_noise(0.9, 3000.0, 1500.0, 3.0, 0.1), Synth.seconds(0.1), 0.15]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in 6:
		var f := rng.randf_range(700.0, 1300.0)
		parts.append([_noise(0.06, f, f * 0.6, 45.0, 0.001), Synth.seconds(0.05 + 0.1 * i + rng.randf_range(0.0, 0.04)), 0.5 - 0.04 * i])
	return _mix(parts, true)


static func _cracked_wall_crumble() -> PackedFloat32Array:
	var parts: Array = [[_noise(0.04, 3200.0, 1500.0, 70.0, 0.0005), 0, 0.9], [_tone(0.2, 110.0, 55.0, "sine", 14.0), Synth.seconds(0.06), 0.6],
		[_noise(0.7, 2500.0, 1200.0, 3.5, 0.08), Synth.seconds(0.1), 0.2]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	for i in 7:
		var f := rng.randf_range(900.0, 1500.0)
		parts.append([_noise(0.07, f, 400.0, 35.0, 0.001), Synth.seconds(0.04 + 0.07 * i + rng.randf_range(0.0, 0.03)), 0.55 - 0.04 * i])
	return _mix(parts)


func _cadence_rail_flip(id: String) -> PackedFloat32Array:
	match id:
		"cadence_rivet_notch_open":
			return _mix([
				[_noise(0.022, 4200.0, 2600.0, 150.0, 0.001), 0, 0.85],
				[_fm(0.068, 2240.0, 2.76, 1.4, 52.0), 0, 0.72],
			])
		"cadence_rivet_notch_hit":
			return _mix([
				[_noise(0.028, 4800.0, 2200.0, 115.0, 0.001), 0, 0.9],
				[_fm(0.085, 1680.0, 2.41, 2.6, 36.0, 2.0), 0, 0.85],
				[_fm(0.145, 2960.0, 1.5, 1.1, 24.0), Synth.seconds(0.02), 0.75],
				[_tone(0.075, 290.0, 145.0, "sine", 42.0), 0, 0.55],
			])
		"cadence_rivet_spent":
			return _mix([
				[_noise(0.03, 1250.0, 520.0, 85.0, 0.002), 0, 0.85],
				[_tone(0.088, 210.0, 118.0, "sine", 34.0), 0, 0.7],
				[_fm(0.055, 640.0, 1.83, 0.8, 48.0, -3.0), Synth.seconds(0.012), 0.45],
			])
		"cadence_sable_full":
			return _mix([
				[_noise(0.018, 5600.0, 3800.0, 180.0, 0.001), 0, 0.6],
				[_fm(0.105, 2680.0, 2.0, 1.8, 34.0, 3.0), 0, 0.92],
				[_tone(0.082, 1340.0, 1780.0, "sine", 36.0), Synth.seconds(0.015), 0.55],
			])
		"cadence_sable_bolt":
			return _mix([
				[_noise(0.04, 5800.0, 2000.0, 75.0, 0.001), 0, 0.9],
				[_fm_sweep(0.19, 1950.0, 420.0, 3.4, 15.0), 0, 0.9],
				[_tone(0.16, 260.0, 95.0, "saw_dark", 18.0), Synth.seconds(0.01), 0.65],
				[_noise(0.14, 3400.0, 5200.0, 20.0, 0.01), Synth.seconds(0.085), 0.35],
			], true)
		"cadence_kest_window":
			return _mix([
				[_noise(0.02, 5200.0, 3200.0, 165.0, 0.001), 0, 0.78],
				[_fm(0.092, 1980.0, 3.12, 1.7, 42.0), 0, 0.85],
				[_tone(0.045, 520.0, 760.0, "sine", 55.0), 0, 0.42],
			])
		"cadence_kest_snap":
			return _mix([
				[_noise(0.048, 4600.0, 1400.0, 62.0, 0.001), 0, 0.95],
				[_tone(0.18, 175.0, 52.0, "sine", 14.0), 0, 1.0],
				[_fm(0.11, 1320.0, 2.6, 2.8, 30.0, -4.0), Synth.seconds(0.008), 0.72],
				[_noise(0.18, 2200.0, 680.0, 14.0, 0.006), Synth.seconds(0.065), 0.45],
			], true)
		"cadence_tarn_window":
			return _mix([
				[_noise(0.055, 2400.0, 4400.0, 36.0, 0.004), 0, 0.45],
				[_fm(0.09, _hz(74), 2.0, 1.2, 34.0), 0, 0.8],
				[_fm(0.115, _hz(81), 2.0, 1.0, 28.0), Synth.seconds(0.03), 0.88],
			])
		"cadence_tarn_rend":
			return _mix([
				[_noise(0.075, 2800.0, 780.0, 28.0, 0.002), 0, 0.9],
				[_tone(0.24, 155.0, 46.0, "saw_dark", 10.5), 0, 0.95],
				[_fm_sweep(0.22, 680.0, 180.0, 3.2, 12.0), Synth.seconds(0.015), 0.82],
				[_tone(0.285, 110.0, 48.0, "sine", 9.0), 0, 0.75],
			], true)
		"cadence_tally_beat":
			return _mix([
				[_noise(0.016, 4900.0, 2900.0, 190.0, 0.001), 0, 0.72],
				[_fm(0.078, 2460.0, 1.62, 1.2, 46.0), 0, 0.84],
			])
		"cadence_tally_paid":
			return _mix([
				[_tone(0.11, 185.0, 68.0, "sine", 24.0), 0, 0.95],
				[_noise(0.036, 1900.0, 760.0, 68.0, 0.001), 0, 0.82],
				[_fm(0.165, 2120.0, 2.0, 0.9, 22.0), Synth.seconds(0.04), 0.74],
				[_fm(0.13, 3180.0, 1.5, 0.6, 26.0), Synth.seconds(0.065), 0.48],
			])
		"cadence_cannon_lock":
			return _mix([
				[_noise(0.02, 3400.0, 1800.0, 130.0, 0.001), 0, 0.48],
				[_fm(0.11, _hz(69), 2.0, 1.3, 30.0), 0, 0.76],
				[_fm(0.135, _hz(74), 2.0, 1.1, 24.0), Synth.seconds(0.015), 0.86],
				[_fm(0.125, _hz(81), 1.5, 0.8, 26.0), Synth.seconds(0.03), 0.65],
			])
		"cadence_cannon_rail":
			return _mix([
				[_noise(0.045, 5600.0, 1900.0, 65.0, 0.001), 0, 0.98],
				[_fm_sweep(0.24, 2400.0, 320.0, 3.8, 12.0), 0, 0.92],
				[_tone(0.21, 145.0, 44.0, "sine", 11.0), 0, 0.88],
				[_fm(0.22, 1840.0, 2.75, 1.6, 14.0), Synth.seconds(0.045), 0.55],
			], true)
		"cadence_cannon_barrage":
			return _mix([
				[_tone(0.14, 135.0, 48.0, "sine", 15.0), 0, 0.92],
				[_noise(0.065, 2200.0, 620.0, 34.0, 0.002), 0, 0.8],
				[_tone(0.18, 120.0, 42.0, "sine", 12.0), Synth.seconds(0.095), 0.98],
				[_noise(0.14, 1900.0, 480.0, 18.0, 0.003), Synth.seconds(0.095), 0.76],
				[_tone(0.18, 220.0, 90.0, "saw_dark", 14.0), Synth.seconds(0.115), 0.52],
			], true)
		"rail_rise":
			return _mix([
				[_noise(0.016, 2600.0, 1400.0, 170.0, 0.001), 0, 0.72],
				[_fm(0.045, 920.0, 2.3, 1.4, 58.0), 0, 0.65],
				[_noise(0.018, 3800.0, 2100.0, 155.0, 0.001), Synth.seconds(0.026), 0.84],
				[_fm(0.056, 1380.0, 2.1, 1.1, 48.0), Synth.seconds(0.026), 0.78],
			])
		"rail_sink":
			return _mix([
				[_noise(0.018, 3000.0, 1500.0, 155.0, 0.001), 0, 0.74],
				[_fm(0.05, 1140.0, 2.2, 1.1, 52.0), 0, 0.68],
				[_noise(0.022, 1800.0, 780.0, 120.0, 0.001), Synth.seconds(0.032), 0.8],
				[_tone(0.062, 310.0, 165.0, "sine", 42.0), Synth.seconds(0.032), 0.65],
			])
		"site_flip":
			return _mix([
				[_noise(0.11, 2200.0, 4200.0, 22.0, 0.012), 0, 0.32],
				[_fm(0.14, _hz(74), 2.0, 0.9, 20.0), 0, 0.72],
				[_fm(0.15, _hz(77), 2.0, 0.85, 18.0), Synth.seconds(0.055), 0.78],
				[_fm(0.165, _hz(81), 2.0, 0.75, 15.0), Synth.seconds(0.11), 0.88],
			])
	return PackedFloat32Array()
