extends RefCounted

# UI principle P9 (design-v3/ui-audit/principles.json): no fact arrives by sound alone. This is
# the list tests/sound_twins_test.gd holds: every cue the sound bank (sfx_bank.gd) names is here
# once, as one of four kinds. The cue names are the bank's own; no sound setting is copied here.
#
# The rule for "act on". A cue is act-on when it tells the player to do something, or tells them
# something changed that they must respond to: an attack about to land, a boss turning phase, a
# hit taken, an ability ready to press, a gate or yard now open or shut, a timer running down.
# It is NOT act-on when it only echoes what the player just did (a hop, a hit, a pickup), pays a
# reward, scores a moment (stingers, music, a near miss, which is a reward), or lands after a
# warning that already sounded and showed (the slam after its tell). A cue that hangs on a
# second, separately-listed warning says so in its reason.
#
# The four kinds:
#   ACT      act-on, with a twin that draws or writes the same fact on screen. A twin names the
#            script, a token that must appear in that script's source (a func, signal or the
#            line that does the drawing), and, for a toast, the event kind the HUD toasts.
#   OPEN     act-on and NO twin found. Each names the line that plays it. The test prints these
#            and pins their count, so the list cannot grow silently. Closing one means building
#            the twin and moving the row to ACT.
#   UNWIRED  in the bank but with no caller found in src/. Not heard by a player today. When one
#            is wired it must be moved to ACT, OPEN or NOT_ACT; the test cannot see the wiring.
#   NOT_ACT  not act-on, with a short reason per group.

const OPEN_PINNED := 6

const ACT := [
	{"cues": ["klaxon"], "what": "the event toast \"<event> incoming\"",
		"script": "res://src/ui/hud.gd", "token": "func _on_event_announced("},
	{"cues": ["event_end"], "what": "the \"<event> lost\" toast",
		"script": "res://src/ui/hud.gd", "token": "func _on_event_ended("},
	{"cues": ["boss_phase"], "what": "the boss's phase burst and word, fired on the same call",
		"script": "res://src/presentation/machine_fx.gd", "token": "func boss_phase("},
	{"cues": ["boss_telegraph"], "what": "the floor hazard committed for the attack, drawn through its warning",
		"script": "res://src/boss/hazard.gd", "token": "func commit_annulus("},
	{"cues": ["ratchet_cue"], "what": "the miniboss raises its fists through the cue lead",
		"script": "res://src/combat/miniboss.gd", "token": "State.CUE:"},
	{"cues": ["threat_tick", "threat_whoosh", "threat_whistle", "threat_hum"],
		"what": "the hazard's floor mark, painted in the shared threat grammar while it warns",
		"script": "res://src/boss/hazard.gd", "token": "func _paint("},
	{"cues": ["threat_tear"], "what": "the lane's fill reaches its end as the hazard goes live",
		"script": "res://src/boss/hazard.gd", "token": "signal went_live"},
	{"cues": ["warn_burrow", "warn_bore", "warn_lure", "warn_cut", "warn_winch", "warn_dive", "warn_tether", "warn_flap", "warn_reel"],
		"what": "the enemy's windup glyph in its shape and hazard colour, drawn on the same call as the sound",
		"script": "res://src/presentation/presentation.gd", "token": "func _show_windup("},
	{"cues": ["flank_call", "boil_rumble"], "what": "a hazard chevron over the caller until the telegraph",
		"script": "res://src/presentation/presentation.gd", "token": "func _on_pressure_cue("},
	{"cues": ["heat_kettle"], "what": "the shell's rim turns white at redline, the cook-off warning",
		"script": "res://src/presentation/player_fx.gd", "token": "static func shell_color("},
	{"cues": ["seal_ratchet"], "what": "the crew casting's seam strip brightens with seal progress",
		"script": "res://src/combat/crew_fitter.gd", "token": "seal_progress"},
	{"cues": ["gates_open"], "what": "the objective line \"Roll through a gate\" and the open gates",
		"script": "res://src/core/flow.gd", "token": "EventKinds.objective(\"reward_offered\")"},
	{"cues": ["stinger_unseal"], "what": "the done-line tick for the sealed beacon and the objective \"Charge the beacon\"",
		"script": "res://src/ui/hud.gd", "token": "game.events.beacon_unsealed.connect("},
	{"cues": ["threat_up"], "what": "the threat tier on the run status line",
		"script": "res://src/ui/hud.gd", "token": "game.events.threat_rose.connect(func(tier: int): _threat = maxi(_threat, tier))"},
	{"cues": ["scrap_rip"], "what": "the toast \"Chase your scrap\"",
		"script": "res://src/ui/hud.gd", "token": "func toast_kinds(", "toast": "scrap_lost"},
	{"cues": ["hurt"], "what": "the screen-edge flash toward the hit, and the health reading's low state",
		"script": "res://src/presentation/juice.gd", "token": "func _on_player_hit("},
	{"cues": ["sable_ready", "rivet_ready", "kest_ready", "tarn_ready", "tally_ready", "cannon_ready"],
		"what": "the slot's ready swell on the ability bar, started on the same call",
		"script": "res://src/ui/ability_bar.gd", "token": "_pulses[id] = PULSE_SECONDS"},
	{"cues": ["verb_fail_select"], "what": "the refused slot shakes and flashes slate",
		"script": "res://src/ui/ability_bar.gd", "token": "func refuse("},
	{"cues": ["cave_in_rumble", "prop_crew_strain"], "what": "the committed floor warning under the falling slab",
		"script": "res://src/world/events/rubble_fall.gd", "token": "hazard.commit_annulus("},
	{"cues": ["zipline_whine"], "what": "the trolley itself, riding the line the whine is attached to",
		"script": "res://src/world/events/fleet.gd", "token": "FoleyAudio.player(\"zipline_whine\", trolley)"},
	{"cues": ["lift_cage_arrive"], "what": "the cage's landing mark the clank is placed on",
		"script": "res://src/world/events/fleet.gd", "token": "FoleyAudio.one_shot(\"lift_cage_arrive\", self, state.mark"},
	{"cues": ["foreman_tell", "dispatcher_tell", "splitter_tell", "linker_tell"],
		"what": "the special's tell effects and word, fired from the same special_tell signal as the sound",
		"script": "res://src/presentation/machine_fx.gd", "token": "func special_moment("},
	{"cues": ["jolt_layer_tell"], "what": "the telegraph's lead fill before each pulse",
		"script": "res://src/combat/jolt_layer.gd", "token": "tele.set_progress(field.lead_fraction())"},
	{"cues": ["arena_lock_slam"], "what": "the yard wall rises",
		"script": "res://src/world/stage_locks.gd", "token": "func _build_wall("},
	{"cues": ["arena_unlock_bells"], "what": "the yard wall drops",
		"script": "res://src/world/stage_locks.gd", "token": "func _drop_wall("},
	{"cues": ["warden_gate_clunk"], "what": "the objective line \"The Warden's clamp is shut: break N crews\"",
		"script": "res://src/world/stage_locks.gd", "token": "func objective("},
	{"cues": ["warden_gate_release"], "what": "the Warden's collar drops away",
		"script": "res://src/world/stage_locks.gd", "token": "func _drop_collar("},
	{"cues": ["fleet_motif"], "what": "the pack's edge marker with its faction icon",
		"script": "res://src/ui/edge_markers.gd", "token": "\"kind\": \"pack_arrived\""},
	{"cues": ["reactor_tick"], "what": "the vent's committed ring on the ground where it will blow",
		"script": "res://src/combat/reactor_relic.gd", "token": "var ring := _commit_ring(Threat.Type.INSTANT, aim, VENT_RADIUS"},
	{"cues": ["lock_tick"], "what": "the HOOK word at the harpoon key when the line locks",
		"script": "res://src/ui/key_glyphs.gd", "token": "EventKinds.LINE_ROWS[\"locked\"][\"word\"]"},
	{"cues": ["vault_rise"], "what": "the incoming shell's rim lights when the ball can bat it",
		"script": "res://src/combat/projectile.gd", "token": "const RIM_SIZE"},
]

# Act-on cues with no visible twin found by reading the code that plays them.
const OPEN := {
	"hold_pit": {"plays": "src/presentation/audio.gd:2305", "what": "a hold catches the ball; only audio listens to hold_started"},
	"hold_bola": {"plays": "src/presentation/audio.gd:2305", "what": "same hold_started listener, no screen consumer"},
	"hold_tether": {"plays": "src/presentation/audio.gd:2305", "what": "same hold_started listener, no screen consumer"},
	"hold_net": {"plays": "src/presentation/audio.gd:2305", "what": "same hold_started listener, no screen consumer"},
	"hold_riser": {"plays": "src/presentation/audio.gd:2305", "what": "the gyro jammer's hold, same hold_started listener, no screen consumer"},
	"arena_wave_whistle": {"plays": "src/world/stage_locks.gd:389", "what": "the next yard wave is coming; nothing on screen at the world_fact"},
}

# In the bank, called by no code in src/ (a literal search for the id, and for the family's composed ids).
const UNWIRED := {
	"ballast_brace_tell": "no caller in src/; the tell is only in the roster sound render",
	"gap_net_charge_tell": "no caller in src/; the tell is only in the roster sound render",
}

const NOT_ACT := [
	{"why": "echo of the player's own move or hit, seen as it happens",
		"cues": ["hop", "boost_whoosh", "dash_whoosh", "carve_release", "land_thud", "slam_boom", "core_slam", "ultimate_land",
			"kest_demo_knock", "rivet_skid_plate", "grapple_clink", "grapple_release", "pylon_plant", "pylon_eject",
			"hit_thwack", "weapon_zap", "special_fire", "kill_pop", "crit_ping", "kest_kick_thump", "smash_whistle",
			"smash_crack", "clank", "armor_deflect", "armor_shed", "armor_shed_small", "armor_shed_big", "shatter",
			"ice_form", "zap_hum", "element_resolved", "shell_spring", "womp", "chunk_low", "grown_sub", "grown_crack",
			"grown_tail", "grown_rattle", "synergy_hit", "breach_crack", "tenacity_choke", "boss_weak_hit", "vault_drop",
			"slow_dip", "slow_rise", "wear_sputter", "dock_click", "panel_ratchet", "ui_tick", "swarm_buzz",
			"rivet_line_arrive", "rivet_line_punch", "rivet_hihat_roll", "sable_arpeggio", "kest_low_thump",
			"tarn_latch_tear", "plate_tally", "clip_tally", "stroke_tally", "settle_tally", "tally_balance_due",
			"cable_kest_fizz", "cable_kest_set", "cable_kest_blast", "tick_kest_62", "tick_kest_57", "tick_kest_53",
			"raid_kest_tick", "raid_kest_stinger", "raid_kest_boom", "raid_kest_roll", "cannon_recall"]},
	{"why": "the harpoon line's own state, drawn by the line, and a refused press whose slot already shows cooling",
		"cues": ["line_bite", "line_claw_drag", "line_hum", "line_twang", "line_zip", "dry_tick", "anchor_clunk", "find_drip", "find_radio",
			"verb_fail", "verb_fail_jump", "verb_fail_fire", "verb_fail_haul", "verb_fail_boost", "verb_fail_special",
			"verb_fail_interact", "verb_fail_ultimate", "verb_fail_active", "verb_fail_roll"]},
	{"why": "the player's launch of an active, seen as the shot leaves",
		"cues": ["active_scrap_rocket", "active_cutting_torch", "active_cutting_torch_heat", "active_silo_battery",
			"active_quake_knock", "active_lift_pulse", "active_glass_lance"]},
	{"why": "a reward, a pickup or a score: pays the player, asks nothing",
		"cues": ["scrap_tick", "scrap_tick_1", "scrap_tick_2", "scrap_tick_3", "scrap_tick_4", "scrap_tick_5", "cog_tick",
			"part_get", "pickup_fountain", "panel_note", "panel_jackpot", "panel_cache", "found_chime", "achievement_chime",
			"rescue_fanfare", "synergy_fanfare", "synergy_fired", "evolution_fired", "lore_found", "pilot_unlocked",
			"pilot_unlocked_sable", "pilot_unlocked_rivet", "pilot_unlocked_kest", "pilot_unlocked_tarn",
			"pilot_unlocked_tally", "pilot_unlocked_cannon", "callout_chime", "shop_bell", "rarity_tick", "rarity_bell",
			"rarity_bell_common", "rarity_bell_rare", "rarity_bell_epic", "rung_coil", "ceremony_build", "ceremony_resolve",
			"reveal_clank", "core_socket", "gate_through", "kill_chain_tier", "kill_chain_tier_1", "kill_chain_tier_2",
			"kill_chain_tier_3", "kill_chain_tier_4", "kill_chain_tier_5", "chain_crash", "armor_reclaim", "bench_clank",
			"sunken_bell", "call_ink", "call_drop", "hype_drop", "warden_gate_pip", "class_up"]},
	{"why": "a near miss is a reward for a dodge already made",
		"cues": ["near_whoosh", "near_miss_whip_sable", "near_miss_whip_rivet", "near_miss_whip_kest",
			"near_miss_whip_tarn", "near_miss_whip_tally", "near_miss_whip_cannon"]},
	{"why": "an opt-in object or ally in the world: the player walks to it by sight, the sound only colours it",
		"cues": ["bet_roll", "bet_clunk", "bet_crack", "bet_refusal", "fight_arm_stamp", "ally_wake", "ally_hum_sable",
			"ally_hum_rivet", "ally_hum_kest", "companion_chirp_ready", "companion_chirp_spent"]},
	{"why": "music, a stinger or a mood layer: the matching state is already on a card, the HUD or the map",
		"cues": ["stinger_run", "stinger_stage", "stinger_clear", "stinger_run_end", "stinger_milestone",
			"stinger_boss_defeated", "stinger_world", "stinger_world_down5", "stinger_world_up5", "music_pressure",
			"music_layer_crown_alcove", "music_layer_crown_hoodoos", "music_layer_crown_ramp", "music_layer_crown_toppled",
			"music_layer_mind_quote_spillway", "build_riser", "warden_theme_in", "boss_arena_in", "stage_fade", "beacon_hum",
			"babble", "class_down", "mind_sable", "mind_rivet", "mind_kest", "mind_tarn", "mind_tally", "mind_cannon",
			"mind_wrong_sable", "mind_wrong_rivet", "mind_wrong_kest", "mind_wrong_tarn", "mind_wrong_tally",
			"mind_wrong_cannon", "sable_break", "rivet_break", "kest_break", "tarn_break", "tally_break", "cannon_break",
			"door_tick", "drop_landing", "return_launch_arpeggio", "crater_hold", "lift_hiss", "launch_roar", "death"]},
	{"why": "lands after a warning that sounded and showed first (see its warning's row), or is the result of the hit",
		"cues": ["reactor_erupt", "swarm_lock", "swarm_scatter", "fleet_anvil", "boiler_burst", "ballast_brace_slam",
			"gap_net_charge_live", "prop_crew_collapse", "cave_in_debris", "ring_out_fall", "zipline_snap",
			"jolt_layer_jam", "jolt_layer_fizzle", "event_start"]},
	{"why": "a special's or crew's presence loop, spawn or death sting: it is already in view",
		"cues": ["foreman_presence", "foreman_spawn", "foreman_break", "dispatcher_presence", "dispatcher_spawn",
			"dispatcher_break", "splitter_presence", "splitter_spawn", "splitter_break_clean", "splitter_break_split",
			"linker_presence", "linker_spawn", "linker_break", "jolt_layer_presence", "jolt_layer_break",
			"prop_crew_presence", "enemy_arrive"]},
]
