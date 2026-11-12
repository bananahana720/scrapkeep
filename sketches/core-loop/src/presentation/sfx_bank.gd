extends RefCounted

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")
const SetDirector := preload("res://src/presentation/set_director.gd")

# One baked sound per event_kinds `sound` id. Each recipe is built from the shared
# rack in synth.gd and pitched from harmony.gd, so the families mean something:
#   rewards and pickups ring bright bells that climb the D minor pentatonic;
#   danger is low, minor and buzzy (squares and saws under D);
#   movement is air and wood: whooshes, chirps and thuds with no fixed pitch;
#   flow stingers are little band hits written on the band's own grid.
# Everything is baked once per process at startup and cached.

const RATE := Harmony.RATE

# The 49 event-set WAVs (design-v3/sound/INTEGRATION.md section 7, item 2; renders in
# RENDERS.md), registered under their cue keys. A file cue replaces the recipe of the
# same key. The file is decoded to the bank's rate at bake time, so stingers, streams and
# the keyed bakes read it like any other cue. Peak -1 dBFS, like the recipes' 0.9.
const EVENT_DIR := "res://assets/audio/event_set/"
const FILE_RATE := 48000
const EVENT_CUES := [
	"achievement_chime", "armor_shed", "boost_whoosh", "boss_arena_in", "boss_phase", "boss_weak_hit",
	"callout_chime", "crit_ping", "dash_whoosh", "death", "found_chime", "hit_thwack", "hop", "hurt",
	"kill_chain_tier_1", "kill_chain_tier_2", "kill_chain_tier_3", "kill_chain_tier_4", "kill_chain_tier_5",
	"kill_pop", "land_thud", "lore_found", "near_whoosh", "part_get", "pickup_fountain", "pilot_unlocked",
	"rarity_bell_common", "rarity_bell_epic", "rarity_bell_rare", "rescue_fanfare", "scrap_tick_1",
	"scrap_tick_2", "scrap_tick_3", "scrap_tick_4", "scrap_tick_5", "shop_bell", "slam_boom", "smash_crack",
	"stinger_boss_defeated", "stinger_clear", "stinger_milestone", "stinger_run_end", "stinger_run",
	"stinger_stage", "stinger_world", "synergy_fanfare", "threat_whistle", "ui_tick", "verb_fail",
]
# Tiered cues: the base key keeps its recipe and its pitch-ladder callers; resolve() picks
# the tier's file from the rung the caller already sends (the scrap and kill ladders, and
# the rarity rung: common 0, rare up to 4, epic from the relic's 5).
const TIER_CUES := {
	"scrap_tick": ["scrap_tick_1", "scrap_tick_2", "scrap_tick_3", "scrap_tick_4", "scrap_tick_5"],
	"kill_chain_tier": ["kill_chain_tier_1", "kill_chain_tier_2", "kill_chain_tier_3", "kill_chain_tier_4", "kill_chain_tier_5"],
	"rarity_bell": ["rarity_bell_common", "rarity_bell_rare", "rarity_bell_epic"],
}

# Stingers written on the grid. The audio director starts them on a beat through the
# music engine; beats is how long they hold the stinger lane.
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
	# The world stinger, one id per WORLD_STEPS value (world_stinger names them).
	"stinger_world": 2,
	"stinger_world_down5": 2,
	"stinger_world_up5": 2,
}

# Crossing into a world plays the world stinger moved by that world's step in semitones,
# worlds 1 to 3: the Dig steps down a fourth, the Highdraft up a fourth.
const WORLD_STINGER := "stinger_world"
const WORLD_STEPS := [0, -5, 5]

# Simultaneous voices per cue and the shortest gap between two starts (mix_rows.gd).
const VOICE_LIMIT := MixRows.VOICE_LIMIT
const MIN_GAP_MS := MixRows.MIN_GAP_MS
# Danger sounds pull the bass down so the low end never masks a warning.
const DANGER_SOUNDS := ["hurt", "enemy_arrive", "boss_telegraph", "ratchet_cue", "klaxon", "threat_up", "death",
	"threat_tick", "threat_whoosh", "threat_whistle", "threat_hum", "threat_tear", "hold_pit", "hold_bola", "hold_tether", "hold_net", "heat_kettle"]
# Pitched cues that follow the live key (a lifted Warden plays its chimes in Eb).
const KEYED_SOUNDS := ["panel_note", "panel_jackpot", "line_claw_drag", "armor_reclaim", "scrap_tick", "cog_tick", "kill_pop", "part_get", "core_socket", "found_chime", "gate_through",
	"rivet_line_punch", "rivet_line_arrive",
	"grapple_clink", "grapple_release", "pylon_plant", "beacon_hum", "clank", "hit_thwack", "hurt",
	"enemy_arrive", "boss_weak_hit", "ui_tick", "element_resolved", "ice_form", "vault_rise", "synergy_hit",
	"sable_arpeggio", "rivet_hihat_roll", "kest_low_thump", "tarn_latch_tear", "tally_balance_due", "cannon_recall", "sable_ready", "rivet_ready", "kest_ready", "tarn_ready", "tally_ready", "cannon_ready",
	"sable_break", "rivet_break", "kest_break", "tarn_break", "tally_break", "cannon_break", "fleet_motif", "reactor_erupt", "swarm_buzz", "swarm_lock",
	"swarm_scatter", "mind_sable", "mind_rivet", "mind_kest", "mind_tarn", "mind_tally", "mind_cannon", "hold_pit", "hold_bola", "hold_tether", "hold_net",
	"hold_riser", "callout_chime", "shop_bell", "rarity_tick", "rarity_bell", "rung_coil", "reveal_clank", "ceremony_build",
	"ceremony_resolve", "line_bite", "smash_crack", "achievement_chime", "rescue_fanfare",
	# v3 AU2 bank: every pitched cue named in design-v3/AUDIO-V3.md sections 4, 5, 8.
	"bet_clunk", "bet_crack", "bet_refusal", "sunken_bell", "ally_hum_sable", "ally_hum_rivet", "ally_hum_kest",
	"ally_wake", "fight_arm_stamp", "near_miss_whip_sable", "near_miss_whip_rivet", "near_miss_whip_kest",
	"kill_chain_tier", "drop_landing", "return_launch_arpeggio", "crater_hold", "shell_spring",
	"core_slam", "ultimate_land", "kest_demo_knock", "rivet_skid_plate",
	"active_cutting_torch",
	# --- P-C Tally keyed sounds ---
	"plate_tally", "clip_tally", "stroke_tally", "settle_tally",
	# --- end Tally ---
]
# --- P-C Kest sounds ---
const KEST_SOUNDS := ["cable_kest_fizz", "cable_kest_set", "cable_kest_blast", "raid_kest_tick",
	"tick_kest_62", "tick_kest_57", "tick_kest_53", "raid_kest_stinger", "raid_kest_boom", "raid_kest_roll"]
# --- end Kest ---

# Per-cue trim in dB against the 0.9 peak every cue is normalized to. Rapid, small
# facts sit low so a firefight never turns to mush; rare facts sit at the top.
const TRIM_DB := {
	"ui_tick": -14.0, "hop": -10.0, "boost_whoosh": -6.0, "dash_whoosh": -5.0, "carve_release": -8.0,
	"land_thud": -6.0, "slam_boom": -1.0, "grapple_clink": -7.0, "grapple_release": -11.0,
	"core_slam": -1.0, "ultimate_land": -1.0, "kest_demo_knock": -4.0, "rivet_skid_plate": -4.0,
	"grown_sub": -4.0, "grown_crack": -7.0, "grown_tail": -10.0, "grown_rattle": -11.0,
	"pylon_plant": -3.0, "pylon_eject": -4.0, "enemy_arrive": -9.0, "hit_thwack": -5.0,
	"weapon_zap": -15.0, "special_fire": -4.0, "kill_pop": -7.0, "hurt": -3.0,
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
	# Pack pressure cues (combat/pack_pressure.gd): the flanker's whistle and the silt boil's rumble.
	"flank_call": -6.0, "boil_rumble": -5.0,
	"breach_crack": -4.0,
	# v2 W5: the leitmotifs, the crowd-control holds, the ancients and Moss's bench.
	"sable_arpeggio": -3.0, "rivet_hihat_roll": -3.0, "kest_low_thump": -2.0, "tarn_latch_tear": -3.0, "tally_balance_due": -3.0, "cannon_recall": -3.0,
	# The ultimate's ready pulse carries news: 4 dB up from -9 (-8 for Kest) after mixsim read
	# rivet_ready buried in a Warden fight (median -2.2 on the PC, -2.0 in the cloud; +2.0 here).
	"sable_ready": -5.0, "rivet_ready": -5.0, "kest_ready": -4.0, "tarn_ready": -5.0, "tally_ready": -5.0, "cannon_ready": -5.0,
	"sable_break": -3.0, "rivet_break": -3.0, "kest_break": -3.0, "tarn_break": -3.0, "tally_break": -3.0, "cannon_break": -3.0,
	"fleet_motif": -4.0, "reactor_tick": -6.0, "reactor_erupt": -2.0, "swarm_buzz": -9.0, "swarm_lock": -6.0, "swarm_scatter": -8.0,
	"mind_sable": -5.0, "mind_rivet": -5.0, "mind_kest": -5.0, "mind_tarn": -5.0, "mind_tally": -5.0, "mind_cannon": -5.0,
	# The Highdraft's own event drops (music_rows.gd): the anvil, the boiler and the Mind's wrong note.
	"fleet_anvil": -3.0, "boiler_burst": -3.0,
	"mind_wrong_sable": -5.0, "mind_wrong_rivet": -5.0, "mind_wrong_kest": -5.0, "mind_wrong_tarn": -5.0, "mind_wrong_tally": -5.0, "mind_wrong_cannon": -5.0,
	# --- Glass Lance sounds (src/combat/actives/glass_lance.gd) ---
	"active_glass_lance": -7.0,
	# --- end Glass Lance ---
	"hold_pit": -13.0, "hold_bola": -14.5, "hold_tether": -13.0, "hold_net": -9.0, "hold_riser": -9.0, "tenacity_choke": -4.0,
	"callout_chime": -8.0, "shop_bell": -6.0, "bench_clank": -7.0, "babble": -8.0,
	# v3 W11 juice: the dodge whoosh and the crit's bright ping over the thwack.
	"near_whoosh": -6.0, "crit_ping": -7.0, "kest_kick_thump": 0.0,
	# v3 W13 reward ceremony: the rarity tick and bell, the card's plate, the crate's build
	# and the burst's resolve.
	"rarity_tick": -9.0, "rarity_bell": -5.0, "reveal_clank": -4.0, "ceremony_build": -3.0, "ceremony_resolve": -1.0,
	# The cobalt rung's own voice under the bell (item ladder: blue is a coil whine and click).
	"rung_coil": -9.0,
	# IL-01 grey panels: the ratchet tick a panel bolts on with, the phrase note a pickup streak
	# climbs (keyed, pitched by the caller), and the pinball jackpot over a reel or dunk drop.
	"panel_ratchet": -9.0, "panel_note": -8.0, "panel_jackpot": -5.0, "panel_cache": -16.0,
	# v3 AU2 bank: bets, secrets, allies, opt-in fights, the escalation's ladder and the
	# ride's return (design-v3/AUDIO-V3.md sections 4, 5, 8, 11).
	"bet_roll": -7.0, "bet_clunk": -4.0, "bet_crack": -2.0, "bet_refusal": -6.0,
	"sunken_bell": -6.0, "ally_hum_sable": -14.0, "ally_hum_rivet": -14.0, "ally_hum_kest": -14.0,
	"ally_wake": -6.0, "fight_arm_stamp": -4.0,
	"near_miss_whip_sable": -6.0, "near_miss_whip_rivet": -6.0, "near_miss_whip_kest": -6.0,
	"near_miss_whip_tarn": -6.0, "near_miss_whip_tally": -6.0, "near_miss_whip_cannon": -6.0,
	"pickup_fountain": -8.0, "synergy_fired": -6.0, "evolution_fired": -5.0, "lore_found": -10.0,
	"pilot_unlocked": -9.0, "pilot_unlocked_sable": -9.0, "pilot_unlocked_rivet": -9.0, "pilot_unlocked_kest": -9.0,
	"pilot_unlocked_tarn": -9.0, "pilot_unlocked_tally": -9.0, "pilot_unlocked_cannon": -9.0,
	"kill_chain_tier": -5.0, "chain_crash": -12.0, "drop_landing": -3.0, "door_tick": -9.0,
	"return_launch_arpeggio": -4.0, "lift_hiss": -9.0, "crater_hold": -12.0,
	# The Spillway's arena locks and Warden gates (src/world/stage_locks.gd): the yard slams shut,
	# springs open, the Warden's clamp counts a crew, refuses a hit, and lets go.
	"arena_lock_slam": -2.0, "arena_wave_whistle": -6.0, "arena_unlock_bells": -4.0, "warden_gate_pip": -7.0,
	"warden_gate_clunk": -10.0, "warden_gate_release": -3.0,
	# Called Shot (loops.md Spec 3) and Heat (Spec 1), each its own sound (sound-gaps 12 Nov): the call
	# inks with a stamp that climbs, a miss drops dry, and a shell about to cook off whistles like a kettle.
	"call_ink": -6.0, "call_drop": -8.0, "heat_kettle": -9.0,
	# Durability prototype: the plate shed in three sizes and the reclaim chime.
	"armor_shed_small": -6.0, "armor_shed": -5.0, "armor_shed_big": -4.0, "armor_reclaim": -7.0,
	"armor_deflect": -10.0,
	# Rivet's wear trail: one soft sputter per patch (world one, --wear=on).
	"wear_sputter": -14.0,
	# The shell's air factor moved: a released spring, an up-and-settle boing (audio.gd plays it
	# up a fifth for the rise and down a fourth for the return).
	"shell_spring": -9.0,
	# The escape charge re-arms (a rising mallet pair) or is spent (a falling one).
	"companion_chirp_ready": -8.0, "companion_chirp_spent": -9.0,
	# The harpoon line's states (design-v3/LEGIBILITY.md section 3), its hum, and one refusal per
	# verb. The bite (line_bite, -7) is the reference: the dry tick sits 14 dB under it by RMS, the
	# lock tick and the refusals under that, the world clunk under the bite.
	"lock_tick": -22.0, "dry_tick": -25.0, "line_bite": -7.0, "anchor_clunk": -12.0, "smash_whistle": -9.0, "smash_crack": -3.0,
	# The Waking crew's seal timer (waking.gd SEAL_SOUND): a dry two-click ratchet kept apart from the harpoon's FM lock tick.
	"seal_ratchet": -16.0,
	"dock_click": -15.0, "line_zip": -10.0, "line_twang": -9.0, "line_hum": -17.0, "find_drip": -14.0, "find_radio": -12.0,
	"verb_fail_jump": -18.0, "verb_fail_fire": -18.0, "verb_fail_haul": -18.0, "verb_fail_boost": -18.0,
	"verb_fail_special": -18.0, "verb_fail_interact": -18.0,
	# The skill bar's refusals (SKILL-BAR section 2): a refused pick and a refused Q, each a dull
	# tick of its own.
	"verb_fail_select": -18.0, "verb_fail_ultimate": -18.0, "verb_fail_active": -18.0,
	# A roll into a cracked face under the ram's bar (activities.gd RULES cracked_cache refused): the
	# face shrugs the ball off with a dull thunk and two flecks of grit.
	"verb_fail_roll": -18.0,
	# The actives' launches (src/combat/actives), one per active: "active_" + its id.
	"active_scrap_rocket": -8.0,
	"active_cutting_torch": -10.0, "active_cutting_torch_heat": -14.0,
	"active_silo_battery": -6.0,
	"active_quake_knock": -7.0,
	"active_lift_pulse": -7.0,
	# Each pilot's line-skill and set-piece cues, one marked block per pilot (SKILL-BAR section 12,
	# item 4); a row here needs its recipe in _bake.
	# --- P-C Sable sounds ---
	# --- end Sable ---
	# --- P-C Rivet sounds ---
	# --- end Rivet ---
	# --- P-C Kest sounds ---
	"cable_kest_fizz": -12.0, "cable_kest_set": -9.0, "cable_kest_blast": -3.0,
	"raid_kest_tick": -12.0, "tick_kest_62": -12.0, "tick_kest_57": -12.0, "tick_kest_53": -12.0,
	"raid_kest_stinger": -3.0, "raid_kest_boom": -2.0, "raid_kest_roll": -9.0,
	# --- end Kest ---
	# --- P-C Tarn sounds ---
	# --- end Tarn ---
	# --- P-C Tally sounds ---
	"plate_tally": CAUSE_NOTE_DB, "clip_tally": CAUSE_NOTE_DB,
	"stroke_tally": CAUSE_NOTE_DB, "settle_tally": CAUSE_NOTE_DB,
	# --- end Tally ---
	# --- P-C Cannon sounds ---
	# --- end Cannon ---
	"chunk_low": -2.0,
	# The kill-first specials and the hype drop are rendered files (FILE_SOUNDS), not recipes.
	"foreman_presence": -14.0, "foreman_tell": -4.0, "foreman_break": -3.0, "foreman_spawn": -6.0,
	"dispatcher_presence": -14.0, "dispatcher_tell": -4.0, "dispatcher_break": -3.0, "dispatcher_spawn": -6.0,
	"splitter_presence": -14.0, "splitter_tell": -4.0, "splitter_break_split": -3.0, "splitter_break_clean": -3.0,
	"splitter_spawn": -6.0,
	"linker_presence": -14.0, "linker_tell": -4.0, "linker_break": -3.0, "linker_spawn": -6.0,
	"hype_drop": -3.0,
	"jolt_layer_presence": -14.0, "jolt_layer_tell": -4.0, "jolt_layer_jam": -3.0, "jolt_layer_fizzle": -6.0,
	"jolt_layer_break": -3.0,
	# The crown's place layers (tools/ace/cut_layers.py): two bars of the crown's own band, under it.
	"music_layer_crown_hoodoos": -8.0, "music_layer_crown_alcove": -8.0, "music_layer_crown_toppled": -8.0,
	"music_layer_crown_ramp": -8.0,
	# The Mind's first quote, its theme inverted over the Spillway's groove (tools/ace/mind_quote.py).
	"music_layer_mind_quote_spillway": -8.0,
	# The arrival forms and the prop crew (tools/ace/arrival_sfx.py); a tell ends on its landing frame.
	"lift_cage_arrive": -3.0, "zipline_whine": -5.0, "zipline_snap": -3.0, "cave_in_rumble": -4.0,
	"cave_in_debris": -3.0, "prop_crew_presence": -14.0, "prop_crew_strain": -4.0, "prop_crew_collapse": -2.0,
	# The Highdraft roster (tools/ace/roster_sfx.py); a tell ends on its landing frame.
	"ballast_brace_tell": -4.0, "ballast_brace_slam": -2.0, "gap_net_charge_tell": -6.0, "gap_net_charge_live": -4.0,
	"ring_out_fall": -8.0,
	"stinger_world": -5.0, "stinger_world_down5": -5.0, "stinger_world_up5": -5.0,
}
# The Warden's break phrase (LEGIBILITY section 4): four notes that climb with the guard,
# one per quarter, then the same notes together when it staggers. Variant 0 is wired in;
# 1 and 2 are sketches for the owner's ear (tools/sound_sketches.gd). notes are note names
# read through Harmony.note_midi; gaps are the seconds between one note and the next in
# the sketch, and chord_gap the pause before the chord.
const BREAK_PHRASES := [
	{"notes": ["D4", "F4", "A4", "D5"], "gaps": [0.16, 0.16, 0.16], "chord_gap": 0.3},
	{"notes": ["D4", "G4", "C5", "F5"], "gaps": [0.2, 0.2, 0.2], "chord_gap": 0.3},
	{"notes": ["D4", "F4", "G4", "A4"], "gaps": [0.26, 0.17, 0.11], "chord_gap": 0.42},
]
# A synergy's motif is three of these, one baked note per midi number (cause_note_<midi>).
const CAUSE_NOTE := "cause_note_"
# One note of a cue the audio director places on the band's grid (grid_note_<voice>_<midi>): a kill
# streak's landing, the near miss's two notes, the dunk's pair, a death's fall. One baked note per
# voice and midi number, like the cause notes, so the stinger lane keys each to the band.
const GRID_NOTE := "grid_note_"
const GRID_NOTE_DB := -8.0
const GRID_NOTE_SECONDS := 0.5
# Offsets on that trim: the voice under a landing and a long chain's restated last note, and a
# death's fall, which sits under the recorded death cue.
const GRID_UNDER_DB := -3.0
# The band answers a long kill chain by name (SOUND-BIBLE, "Pilot quotes"): pilot_quote_<class>, the
# pilot's motif on the sax with a brass and kick hit under its last note. It is made for the
# sounding band's step and key when a chain earns it, never at boot.
const PILOT_QUOTE := "pilot_quote_"
const PILOT_QUOTE_DB := -6.0
# A motif whose top note is under A4 (Kest's toms, Tarn's bass) goes up an octave so the sax sings it.
const PILOT_QUOTE_FLOOR := 69
# June's answer at the end of a phrase (set_director.gd, SOUND-BIBLE "The set"): set_answer_<phrase id>,
# one bar from the director's phrase book on the sax, made for the sounding band's step and key
# like the quote, and 2 dB under it so the quote stays the bigger moment.
const SET_ANSWER := "set_answer_"
const SET_ANSWER_DB := -8.0
const DEATH_FALL_DB := -6.0
# The note each climbing cue rings on, where its ladder starts (Harmony.ladder_ratio): the kill
# pop's bell is D6 and the line's bite A5, in the recipes here and in the event-set files.
const KILL_POP_MIDI := 86
const BITE_MIDI := 81
# The motif cell a class's whip lands on, when it is not the second (Tarn's first two are one note).
const WHIP_SECOND := {"tarn": 2}
const CAUSE_NOTE_DB := -8.0

# SPIL-9's called assists, one sting per move, landed on the next beat by audio.gd. Each
# grows with heft: two layers at heft class 1 or 2, an 808 sub under them at 3 or 4, and
# at 5 a sax stab on top quoting the pilot's motif. Ids: companion_assist_<move>_t<tier>,
# the top tier also _<motif id>. Every pitch reads _hz/_n, so the band's live key holds.
const ASSIST_STING := "companion_assist_"
const ASSIST_MOVES := ["bonk", "arc", "pile", "slip", "anvil", "static", "bulldozer"]
const ASSIST_STING_DB := -7.0
# Moss's babble roots (SOUND-STORY.md section 8), beats 1 to 6 of the conversation
# loop: ask, refuse, insist, double down, plead, send off. Barks and the relent sit on D3.
const BABBLE_ROOTS := [50, 52, 53, 55, 57, 48]
const BABBLE_LEVEL := 0
const BABBLE_RELENT := -1
const VOWELS := ["a", "e", "i", "o", "u"]
# A line on the call card (SOUND-STORY.md section 8, "Who talks on what"), baked by id like
# any keyed sound: say|<caller>|<the line>. Its voice follows whose hands the caller is.
# motif is the Harmony row its letters are drawn from and whose voice it talks on, unless
# voice names another; a caller with no motif talks on its root's Dorian triad. lift moves
# the notes in semitones, pace scales a letter's length, bend scoops up into a letter by
# that many semitones (a fall when negative), loose is how far a letter's length strays
# (CALL_LOOSE unless the row says), run closes the gaps between words, stop stretches the
# rest after a sentence, lean ends a sentence held on the flat second, and second has a
# second talker take every other word that many scale steps away. mouth gives the caller a
# mouth of that size (1 is a grown voice, more is a smaller creature): the chirp stays on the
# instrument, and the letters are said, drop semitones away from where the instrument would
# play them. grid is the Foreman alone: one note, every letter half a sixteenth, no bend,
# no mouth and nothing left to chance. bench is Moss alone: his call is his bench line after
# his bell, and a caller with no row gets his. db levels a voice against Moss's bench blips.
# Moss and Brindle, the two low voices, are said high (Andrew, 10 November 2026): Moss an
# octave over his old bench pitch, Brindle at his brass's. Moss's row is his voice everywhere,
# at his bench (babble) as on a call: {"bench": true} alone gives him his old blips back.
const SAY := "say|"
const MOSS := "moss"
const PURE := "pure"
const CALLERS := {
	"moss": {"bench": true, "mouth": 1.0, "drop": 12, "db": 3.5},
	"sable": {"motif": "sable", "voice": "bell", "lift": 12, "pace": 0.8, "bend": 2.0, "mouth": 1.4, "drop": -12, "db": 3.5},
	"rivet": {"motif": "rivet", "lift": 12, "pace": 0.7, "bend": 0.5, "run": true, "mouth": 1.3, "drop": -12, "db": 1.0},
	"kest": {"motif": "kest", "lift": 12, "pace": 1.15, "bend": -2.0, "stop": 1.6, "mouth": 1.15, "db": 4.5},
	"tarn": {"motif": "tarn", "voice": "fbass", "lift": 12, "pace": 1.3, "bend": 0.7, "mouth": 1.2, "db": 2.0},
	"tally": {"motif": "tally", "lift": 12, "bend": 0.5, "loose": 0.0, "mouth": 1.35, "drop": -12, "db": 4.0},
	"cannon": {"motif": "cannon", "lift": 12, "bend": 1.5},
	"pump_crew": {"root": 62, "voice": "mallet", "bend": 1.0, "second": -3, "mouth": 1.2, "db": 7.0},
	"flume_crew": {"root": 64, "voice": "mallet", "bend": 1.0, "second": -3, "mouth": 1.25, "db": 5.5},
	"signal_crew": {"root": 67, "voice": "mallet", "bend": 1.0, "second": -3, "mouth": 1.3, "db": 5.0},
	"brindle": {"motif": "fleet", "lift": 12, "pace": 1.7, "lean": true, "mouth": 0.95, "db": 3.5},
	"mind": {"root": 74, "voice": PURE, "grid": true, "db": -2.5},
}
# The incoming chirp: two notes a little under the voice, then the line starts this long after
# the first.
const CHIRP_NOTE_S := 0.12
const CHIRP_GAIN := 0.6
const CALL_TALK_S := 0.36
# A second talker comes in this long before the first has finished the word.
const CALL_OVERLAP_S := 0.06
const CALL_LOOSE := 0.15
# A mouth's two resonances for each vowel, in Hz for a grown voice, and the half-shut shape
# every consonant is said through. A letter rings on a little past its slot so speech joins up.
const MOUTH_VOWELS := {"a": [800.0, 1200.0], "e": [500.0, 1900.0], "i": [320.0, 2500.0], "o": [500.0, 900.0], "u": [350.0, 750.0]}
const MOUTH_SHUT := [420.0, 1400.0]
const MOUTH_HUM := [250.0, 1100.0]
const MOUTH_HUMMED := ["m", "n"]
const MOUTH_BREATHED := ["s", "f", "h", "z", "c", "x", "t", "k", "p"]
const MOUTH_RING := 1.25
# A said vowel's peak, so a mouth sits level with the instrument that chirps before it.
const MOUTH_PEAK := 0.8
# Moss's sigh (the relent) is said through a mouth this much larger than his own, and this
# much under his other lines, where the old sigh's softer blip sat.
const BENCH_SIGH := 0.9
const BENCH_SIGH_LEVEL := 0.75
# A caller id with no row, warned about once (say_id) and given Moss's voice.
static var unknown_callers := {}

static var _samples := {}
# The live key and level a keyed or themed bake is for (see samples_at).
static var _shift := 0
static var _theme := 0
static var _lock := Mutex.new()
# Cues whose notes depend on the level (the synergy fanfare quotes its motif).
const THEMED := ["synergy_fanfare"]
static var _streams := {}
# Sounds the music session renders to files rather than recipes: each plays once its file is
# in RENDERED_DIR, and the cue that wants it plays without it until then.
const RENDERED_DIR := "res://assets/audio/sfx/"
static var _rendered := {}
# Guards _samples, _streams, _file_present and _rendered: the startup bake fills them on a worker while the main thread
# reads and fills them too. It is held only to look up or store, never across a bake, so neither thread waits on the
# other's bake (when both bake one id, the first one stored is kept).
static var _cache_lock := Mutex.new()
# Set on the main thread to abandon a startup bake; the worker checks it between ids.
static var bake_cancel := false


# The midi numbers of a break phrase's four notes, lowest first.
static func break_midis(variant := 0) -> Array:
	var midis: Array = []
	for note in BREAK_PHRASES[variant]["notes"]:
		midis.append(Harmony.note_midi(String(note)))
	return midis


static func has_recipe(id: String) -> bool:
	return (TRIM_DB.has(id) or id.begins_with(CAUSE_NOTE) or id.begins_with(GRID_NOTE) or id.begins_with(PILOT_QUOTE) or id.begins_with(SAY)
		or (id.begins_with(SET_ANSWER) and SetDirector.has_answer(id.trim_prefix(SET_ANSWER)))
		or _assist_parts(id).size() > 0 or id in EVENT_CUES)


static func trim_db(id: String) -> float:
	if id.begins_with(CAUSE_NOTE):
		return CAUSE_NOTE_DB
	if id.begins_with(GRID_NOTE):
		return GRID_NOTE_DB
	if id.begins_with(PILOT_QUOTE):
		return PILOT_QUOTE_DB
	if id.begins_with(SET_ANSWER):
		return SET_ANSWER_DB
	if id.begins_with(SAY):
		return TRIM_DB["babble"] + float(_caller(_said(id)[0]).get("db", 0.0))
	if id == "babble":
		return TRIM_DB["babble"] + float(CALLERS[MOSS].get("db", 0.0))
	if id.begins_with(ASSIST_STING):
		return ASSIST_STING_DB
	return TRIM_DB.get(id, TRIM_DB.get(base_key(id), -8.0))


# The key a tier's file belongs to (scrap_tick_3 -> scrap_tick), else the id itself. A
# tier file keeps its base key's trim.
static func base_key(id: String) -> String:
	for base in TIER_CUES:
		if id in TIER_CUES[base]:
			return base
	return id


# The res:// path of an event-set cue.
static func event_path(id: String) -> String:
	return EVENT_DIR + id + ".wav"


# The file a sound id plays and the pitch it plays at. A tiered key reads the rung the
# caller already sends as its pitch (Harmony.ratio of a pentatonic step): the tier's file
# is already stepped, so it plays at 1.0. Every other id passes through.
static func resolve(sound: String, pitch: float) -> Dictionary:
	if not TIER_CUES.has(sound) or pitch <= 0.0:
		return {"id": sound, "pitch": pitch}
	var files: Array = TIER_CUES[sound]
	var rung := ladder_rung(pitch)
	var index := clampi(rung, 0, files.size() - 1)
	if sound == "rarity_bell":
		index = 0 if rung <= 0 else (1 if rung < 5 else 2)
	# A tier whose file is missing plays the base recipe on the caller's rung, pitch kept.
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


# Stores value unless the key is already there, and returns what the cache holds.
static func _cache_put(cache: Dictionary, key: String, value: Variant) -> Variant:
	_cache_lock.lock()
	if not cache.has(key):
		cache[key] = value
	var held = cache[key]
	_cache_lock.unlock()
	return held


# The pentatonic rung whose ratio is nearest this pitch ratio.
static func ladder_rung(pitch: float) -> int:
	var steps := 12.0 * log(maxf(pitch, 0.001)) / log(2.0)
	var best := 0
	for rung in range(0, 12):
		if absf(float(Harmony.pentatonic_step(rung)) - steps) < absf(float(Harmony.pentatonic_step(best)) - steps):
			best = rung
	return best


# An event-set WAV as float samples at the bank rate (linear resample from the file rate), moved shift semitones.
# Empty when the file is absent or is not 16-bit mono.
static func _event_samples(id: String, shift := 0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var path := event_path(id)
	if not ResourceLoader.exists(path):
		return out
	var wav := ResourceLoader.load(path, "AudioStreamWAV", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamWAV
	if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS or wav.stereo:
		return out
	# wav.data returns a copy on every read, so read it once, not twice a sample.
	var data := wav.data
	var count := data.size() / 2
	# A keyed bake (shift in semitones) is a varispeed of the file, like pitch_scale in play.
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


# The world stinger's id for a world: the plain row sound at step 0, else the step named.
static func world_stinger(world: int) -> String:
	var step: int = WORLD_STEPS[clampi(world, 1, WORLD_STEPS.size()) - 1]
	if step == 0:
		return WORLD_STINGER
	return "%s_%s%d" % [WORLD_STINGER, "up" if step > 0 else "down", absi(step)]


# The sting for a called assist at a heft class, or "" for a move without one. motif is
# the pilot's motif id (audio.gd's _motif); only the top tier quotes it.
static func assist_sting_id(move: String, heft_class: int, motif := "") -> String:
	if not move in ASSIST_MOVES:
		return ""
	var tier := 1 if heft_class <= 2 else (2 if heft_class <= 4 else 3)
	var id := "%s%s_t%d" % [ASSIST_STING, move, tier]
	return id + "_" + (motif if Harmony.MOTIFS.has(motif) else Harmony.CLASS_MOTIFS[0]) if tier == 3 else id


# [move, tier, motif] from a sting id, or [] when the id is not one.
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


# The quote's score, rows of [step, midi, steps, voice, gain] in sixteenths: the class motif's
# cells at half speed, so the sax sings in eighths what the cue sounds flick in sixteenths, then
# the brass an octave under the last note and a kick with it.
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


# The class whip's voice and its two notes, the class motif's first interval an octave up:
# [voice, first midi, second midi].
static func whip_notes(class_id: String) -> Array:
	var row := Harmony.motif_or_first(class_id)
	var cells: Array = row["cells"]
	return [String(row["voice"]), int(cells[0][1]) + 12, int(cells[WHIP_SECOND.get(class_id, 1)][1]) + 12]


# Rendered sounds (design-v3/sound/specials.py and extras.py), 44.1 kHz mono 16-bit WAVs under
# assets/sfx/. The four presence cues are seamless two-bar loops at 129 BPM.
const SFX_DIR := "res://assets/audio/"
const SPECIALS := ["foreman", "dispatcher", "splitter", "linker"]
const FILE_SOUNDS := {
	"foreman_presence": "specials/foreman_presence.wav", "foreman_tell": "specials/foreman_tell.wav",
	"foreman_break": "specials/foreman_break.wav", "foreman_spawn": "specials/foreman_spawn.wav",
	"dispatcher_presence": "specials/dispatcher_presence.wav", "dispatcher_tell": "specials/dispatcher_tell.wav",
	"dispatcher_break": "specials/dispatcher_break.wav", "dispatcher_spawn": "specials/dispatcher_spawn.wav",
	"splitter_presence": "specials/splitter_presence.wav", "splitter_tell": "specials/splitter_tell.wav",
	"splitter_break_split": "specials/splitter_break_split.wav", "splitter_break_clean": "specials/splitter_break_clean.wav",
	"splitter_spawn": "specials/splitter_spawn.wav",
	"linker_presence": "specials/linker_presence.wav", "linker_tell": "specials/linker_tell.wav",
	"linker_break": "specials/linker_break.wav", "linker_spawn": "specials/linker_spawn.wav",
	"hype_drop": "hype_drop.wav",
	"jolt_layer_presence": "specials/jolt_layer_presence.wav", "jolt_layer_tell": "specials/jolt_layer_tell.wav",
	"jolt_layer_jam": "specials/jolt_layer_jam.wav", "jolt_layer_fizzle": "specials/jolt_layer_fizzle.wav",
	"jolt_layer_break": "specials/jolt_layer_break.wav",
	"music_layer_crown_hoodoos": "layers/music_layer_crown_hoodoos.wav", "music_layer_crown_alcove": "layers/music_layer_crown_alcove.wav",
	"music_layer_crown_toppled": "layers/music_layer_crown_toppled.wav", "music_layer_crown_ramp": "layers/music_layer_crown_ramp.wav",
	"music_layer_mind_quote_spillway": "layers/music_layer_mind_quote_spillway.wav",
	"lift_cage_arrive": "foley/lift_cage_arrive.wav", "zipline_whine": "foley/zipline_whine.wav",
	"zipline_snap": "foley/zipline_snap.wav", "cave_in_rumble": "foley/cave_in_rumble.wav",
	"cave_in_debris": "foley/cave_in_debris.wav", "prop_crew_presence": "foley/prop_crew_presence.wav",
	"prop_crew_strain": "foley/prop_crew_strain.wav", "prop_crew_collapse": "foley/prop_crew_collapse.wav",
	"ballast_brace_tell": "foley/ballast_brace_tell.wav", "ballast_brace_slam": "foley/ballast_brace_slam.wav",
	"gap_net_charge_tell": "foley/gap_net_charge_tell.wav", "gap_net_charge_live": "foley/gap_net_charge_live.wav",
	"ring_out_fall": "foley/ring_out_fall.wav",
}
# hype_drop's drop lands this many seconds into the file: one 150 BPM bar of riser and a beat of silence.
const HYPE_DROP_LEAD_SECONDS := 2.0


# Per-stage park event stingers (tools/ace/cut_stingers.py) are ids of the form
# "stinger:<zone with _>/<cue>", for example "stinger:3_1/drop_boiler".
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


# The mono samples of a rendered file: the imported resource when the editor or export has
# one, else the raw RIFF (headless runs without an import cache). An id outside FILE_SOUNDS
# and the stingers is an event-set cue (EVENT_CUES), read at the bank rate and moved shift semitones.
static func file_samples(id: String, shift := 0) -> PackedFloat32Array:
	if not FILE_SOUNDS.has(id) and not id.begins_with(STINGER_PREFIX):
		return _event_samples(id, shift)
	var path := file_path(id)
	var out := PackedFloat32Array()
	# Uncached: this runs on the bake worker, and a cached load there leaves its load token
	# and stream alive at exit ("resources still in use"). samples() keeps the decoded copy.
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


# Every id the game plays as a loop, through loop_stream or hum_stream. A looped sound is held
# to a seam that tiles, not to ends at rest (tests/sound_edges_test.gd).
const LOOPED := ["line_hum", "panel_cache", "find_drip", "find_radio",
	"foreman_presence", "dispatcher_presence", "splitter_presence", "linker_presence"]

# A presence loop: the file as a forward-looping stream, whole file as the loop. It copies the
# stream the bake already encoded (bake_all), so a special's first spawn does not encode its
# two-bar loop again on the main thread (12-14 ms at the Dispatcher's first spawn on the cloud).
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


# The hum is the one looping cue: a whole number of cycles in its buffer, so it tiles.
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
	# A keyed bake on a worker sets the shared key and theme; the plain bake waits it out.
	_lock.lock()
	var buf: PackedFloat32Array = _cache_get(_samples, id) if _cache_has(_samples, id) else _cache_put(_samples, id, Synth.normalize(_bake(id), 0.9))
	_lock.unlock()
	return buf


# A grid stinger baked on another tempo's grid, for the boss tempo. Cues that are not
# written on the grid are the same at any tempo.
static func samples_at(id: String, step: int, shift := 0, theme := 0) -> PackedFloat32Array:
	if _plain(id, step, shift, theme):
		return samples(id)
	var key := _key_at(id, step, shift, theme)
	if _cache_has(_samples, key):
		return _cache_get(_samples, key)
	# A worker warms keyed variants while the band may ask for one: one bake at a time.
	_lock.lock()
	# A recorded event cue is the same file at any grid step or theme (_bake ignores both), so
	# its variants share one resample per key shift.
	if not _cache_has(_samples, key) and id in EVENT_CUES and not FILE_SOUNDS.has(id) and not id.begins_with(STINGER_PREFIX):
		var shared := "%s@file@%d" % [id, shift]
		if not _cache_has(_samples, shared):
			var recorded := file_samples(id, shift)
			if not recorded.is_empty():
				_cache_put(_samples, shared, Synth.normalize(recorded, 0.9))
		if _cache_has(_samples, shared):
			_cache_put(_samples, key, _cache_get(_samples, shared))
	if not _cache_has(_samples, key):
		if _gridded(id):
			Synth.score_step = step
		Synth.score_transpose = shift
		_shift = shift
		_theme = theme
		_cache_put(_samples, key, Synth.normalize(_bake(id), 0.9))
		Synth.score_step = Harmony.STEP
		Synth.score_transpose = 0
		_shift = 0
		_theme = 0
	_lock.unlock()
	return _cache_get(_samples, key)


# True when samples_at would return without a bake: the startup bank's own variant, or one already made.
static func baked_at(id: String, step: int, shift := 0, theme := 0) -> bool:
	return _plain(id, step, shift, theme) or _cache_has(_samples, _key_at(id, step, shift, theme))


# True when this variant is in memory, the plain one included (baked_at takes the plain one on
# trust: the boot bake makes every plain sound a row can name, but not a note named by its pitch).
static func cached_at(id: String, step: int, shift := 0, theme := 0) -> bool:
	return _cache_has(_samples, id if _plain(id, step, shift, theme) else _key_at(id, step, shift, theme))


static func _plain(id: String, step: int, shift: int, theme: int) -> bool:
	return (step == Harmony.STEP or not _gridded(id)) and shift == 0 and (not id in THEMED or theme == 0)


static func _key_at(id: String, step: int, shift: int, theme: int) -> String:
	return "%s@%d@%d@%d" % [id, step if _gridded(id) else Harmony.STEP, shift, theme if id in THEMED else 0]


# A sound written on the grid is made again for each step it sounds at: the listed stingers, and
# a pilot's quote, and a line from a caller who talks on the grid.
static func _gridded(id: String) -> bool:
	return STINGER_BEATS.has(id) or id.begins_with(PILOT_QUOTE) or id.begins_with(SET_ANSWER) or (id.begins_with(SAY) and caller_on_grid(_said(id)[0]))


# Every tonal recipe reads pitches through these, so a keyed bake transposes it whole.
static func _hz(midi: float) -> float:
	return Harmony.hz(midi + _shift)


static func _n(instrument: String, midi: int) -> PackedFloat32Array:
	return Synth.note(instrument, midi + _shift)


static func stream(id: String) -> AudioStreamWAV:
	if id == "line_hum":
		return hum_stream()
	if _cache_has(_streams, id):
		return _cache_get(_streams, id)
	return _cache_put(_streams, id, Synth.to_wav(samples(id)))


# A rendered sound's stream, or null while its file is not there yet.
static func rendered(id: String) -> AudioStream:
	if _cache_has(_rendered, id):
		return _cache_get(_rendered, id)
	var path := RENDERED_DIR + id + ".wav"
	return _cache_put(_rendered, id, load(path) if ResourceLoader.exists(path) else null)


# True when a bake of this id resamples a recorded file.
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


static func _bake(id: String) -> PackedFloat32Array:
	if FILE_SOUNDS.has(id) or id.begins_with(STINGER_PREFIX):
		var file := file_samples(id)
		if file.size() > 0:
			return file
		return _tone(0.12, _hz(62), _hz(62), "sine", 20.0)
	if id in EVENT_CUES:
		var recorded := file_samples(id, _shift)
		if not recorded.is_empty():
			return recorded
		# A missing or unreadable file never leaves the cue silent: a tier falls back to
		# its base recipe, a plain key to its own.
		if base_key(id) != id:
			return _bake(base_key(id))
	if id in ["plate_tally", "clip_tally", "stroke_tally", "settle_tally"]:
		return tally_recipe(id)
	if id.begins_with("cable_kest_") or id.begins_with("raid_kest_") or id.begins_with("tick_kest_"):
		if id == "cable_kest_fizz":
			return _mix([[_noise(0.5, 1800.0, 4800.0, 4.0), 0, 0.6], [_tone(0.5, _hz(62), _hz(63), "sine", 4.0), 0, 0.4]])
		return Synth.render_score(kest_score(id), 0.7)
	match id:
		"ui_tick":
			return _tone(0.03, _hz(86), _hz(86), "sine", 120.0)
		"hop":
			return _mix([[_tone(0.11, 380.0, 640.0, "sine", 28.0), 0, 1.0], [_noise(0.02, 3000.0, 3000.0, 200.0), 0, 0.3]])
		"boost_whoosh":
			return _mix([[_noise(0.42, 500.0, 3200.0, 7.0, 0.06), 0, 1.0], [_tone(0.12, 90.0, 55.0, "sine", 25.0), 0, 0.7]])
		# The carve letting go: the grind's bright rasp falls away under a short rising saw, so the
		# ride off a bank sounds like the shell springing free of the wall.
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
			# The low end under a grown hit: a 62-to-34 Hz drop that outlasts the thwack.
			return _mix([[_tone(0.5, 62.0, 34.0, "sine", 5.0), 0, 1.0], [_tone(0.03, 140.0, 70.0, "sine", 60.0), 0, 0.3]])
		"grown_crack":
			# A heavier transient: a sharp noise snap over a dark saw knock.
			return _mix([[_noise(0.03, 4200.0, 1800.0, 110.0, 0.0005), 0, 1.0],
				[_tone(0.07, 190.0, 85.0, "saw_dark", 38.0), 0, 0.8]], true)
		"grown_tail":
			# A long tail: low rumble and filtered air that ring on after the hit.
			return _mix([[_tone(1.2, 48.0, 38.0, "sine", 2.4), 0, 0.8], [_noise(1.3, 420.0, 120.0, 2.6, 0.02), 0, 0.6]])
		"grown_rattle":
			# Scrap settling off the shell: four ticks, each quieter.
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
		# A valve hiss, then a bottle rocket's rising whistle over a low thump: FWOOSH.
		"active_scrap_rocket":
			return _mix([[_noise(0.16, 2400.0, 5200.0, 14.0, 0.004), 0, 0.7], [_tone(0.09, 120.0, 60.0, "sine", 30.0), 0, 0.8],
				[_tone(0.34, 900.0, 2600.0, "sine", 6.0), Synth.seconds(0.06), 0.35], [_noise(0.3, 1200.0, 3600.0, 8.0, 0.02), Synth.seconds(0.06), 0.4]])
		# A gas torch catching: a pop and a hiss, then a buzz on the key's root and fifth that
		# burns as long as the beam. Keyed (audio.gd), so it sits in the world's key.
		"active_cutting_torch":
			return _mix([[_noise(0.05, 3200.0, 1400.0, 60.0, 0.001), 0, 0.9], [_tone(0.07, 200.0, 90.0, "sine", 40.0), 0, 0.7],
				[_tone(1.6, _hz(38), _hz(38), "saw_dark", 1.4), Synth.seconds(0.04), 0.6], [_tone(1.6, _hz(45), _hz(45), "square_dark", 1.6), Synth.seconds(0.04), 0.25],
				[_noise(1.6, 2800.0, 2200.0, 1.2, 0.03), Synth.seconds(0.04), 0.3]])
		# Hot metal spitting under the flame: a short sizzle; audio climbs it with the heat.
		"active_cutting_torch_heat":
			return _mix([[_noise(0.14, 3400.0, 5200.0, 18.0, 0.004), 0, 1.0], [_noise(0.08, 1800.0, 2600.0, 30.0), Synth.seconds(0.02), 0.4]])
		# A two-note klaxon chirp, the hatch's clank, two shells whistling down, and the landing
		# FALL (silo_battery.gd) after the hatch opens: KA-THOOM.
		"active_silo_battery":
			return _mix([[_tone(0.07, 740.0, 720.0, "square_dark", 12.0), 0, 0.45], [_tone(0.07, 990.0, 960.0, "square_dark", 12.0), Synth.seconds(0.07), 0.45],
				[_fm(0.2, _hz(43), 2.76, 3.0, 16.0), Synth.seconds(0.12), 0.8], [_noise(0.05, 3200.0, 1800.0, 60.0), Synth.seconds(0.12), 0.5],
				[_tone(0.3, 2600.0, 900.0, "sine", 2.0), Synth.seconds(0.15), 0.28], [_tone(0.26, 2200.0, 760.0, "sine", 2.0), Synth.seconds(0.19), 0.24],
				[_tone(0.45, 95.0, 36.0, "sine", 6.0), Synth.seconds(0.45), 1.0], [_noise(0.4, 900.0, 180.0, 8.0, 0.003), Synth.seconds(0.45), 0.8],
				[_noise(0.06, 4200.0, 2200.0, 50.0), Synth.seconds(0.45), 0.4]], true)
		# The Waking's own floor voice (warn_burrow's low Eb rumble, breach's dry crack), struck by
		# hand: a muffled knock under the plate, the rumble rolling out, then stone cracking. KRRAK
		"active_quake_knock":
			return _mix([[_noise(0.1, 420.0, 200.0, 30.0), 0, 0.9], [_tone(0.5, _hz(39), _hz(34), "saw_dark", 3.5), 0, 0.85],
				[_noise(0.035, 5200.0, 2200.0, 85.0), Synth.seconds(0.05), 0.9], [_fm(0.1, _hz(63), 2.3, 4.0, 26.0), Synth.seconds(0.05), 0.5],
				[_noise(0.03, 4400.0, 2000.0, 90.0), Synth.seconds(0.12), 0.6], [_noise(0.4, 1300.0, 200.0, 5.0, 0.02), Synth.seconds(0.1), 0.7]], true)
		# The deep thump of the pulse leaving the fan on the press (the shove lands with it), over the
		# turbine spooling up behind it (a rising whine and rushing air): WHUMP.
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
			# scrap_tick's shape in brass: the bell's attack over a short brass body, a touch lower in the noise.
			return _mix([[_cut(_n("bell", 74), 0.16), 0, 1.0], [_cut(_n("brass", 62), 0.09), 0, 0.45], [_noise(0.01, 6000.0, 6000.0, 300.0), 0, 0.15]])
		"part_get":
			return _arpeggio([74, 77, 81, 86], 0.05, "bell", 0.8)
		"panel_ratchet":
			# Three pawl clicks over a short steel ring: a socket wrench seating a plate.
			return _mix([[_noise(0.012, 5200.0, 5200.0, 260.0), 0, 0.7], [_noise(0.012, 4600.0, 4600.0, 260.0), Synth.seconds(0.035), 0.6],
				[_noise(0.012, 4000.0, 4000.0, 260.0), Synth.seconds(0.07), 0.5], [_cut(_n("mallet", 86), 0.08), Synth.seconds(0.07), 0.35]])
		"panel_note":
			return _cut(_n("mallet", 74), 0.22)
		"panel_jackpot":
			return _arpeggio([74, 81, 86, 93], 0.04, "bell", 0.9)
		"panel_cache":
			# A rib cache's call: two high bell notes, then rest, one 1.86 s bar at 129 BPM, looped.
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
			return Synth.render_score(_score_run(0), 0.8)
		"stinger_stage":
			return Synth.render_score([[0, 0, 2, "kick", 1.0], [0, 0, 2, "open_hat", 0.6], [0, 62, 2, "keys", 0.5],
				[0, 65, 2, "keys", 0.5], [0, 69, 2, "keys", 0.5], [0, 72, 2, "keys", 0.5], [0, 74, 2, "lead", 0.6]], 0.5)
		"stinger_world", "stinger_world_down5", "stinger_world_up5":
			for world in range(1, WORLD_STEPS.size() + 1):
				if world_stinger(world) == id:
					return Synth.render_score(_score_world(WORLD_STEPS[world - 1]), 0.6)
			return Synth.render_score(_score_world(0), 0.6)
		"stinger_clear":
			return Synth.render_score(_score_clear(0), 1.4)
		"stinger_run_end":
			var finale := _score_run(0)
			finale.append_array(_score_clear(16))
			return Synth.render_score(finale, 2.0)
		"stinger_milestone":
			return Synth.render_score(_score_milestone(), 1.2)
		"gates_open":
			return Synth.render_score([[0, 62, 2, "bell", 0.5], [1, 65, 2, "bell", 0.5], [2, 69, 2, "bell", 0.5],
				[3, 72, 2, "bell", 0.5], [4, 76, 6, "bell", 0.6], [4, 57, 12, "keys", 0.35], [4, 60, 12, "keys", 0.35],
				[4, 64, 12, "keys", 0.35], [4, 65, 12, "keys", 0.35], [4, 0, 2, "open_hat", 0.5]], 1.0)
		"stinger_unseal":
			return _unseal()
		"class_up":
			return Synth.render_score(_score_class_up(), 0.9)
		"class_down":
			return _mix([[Synth.render_score(_score_class_down(), 0.7), 0, 1.0], [_noise(0.18, 3500.0, 1500.0, 14.0), Synth.seconds(0.05), 0.25]])
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
			return Synth.render_score(_score_synergy(), 1.4)
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
		"chunk_low":
			return _mix([[_tone(0.55, 120.0, 36.0, "sine", 7.0), 0, 1.0], [_tone(0.3, 75.0, 40.0, "square_dark", 12.0), 0, 0.3],
				[_noise(0.08, 700.0, 200.0, 40.0), 0, 0.5]])
		"stage_fade":
			return _stage_fade()
		"vault_rise":
			return _mix([[_noise(0.32, 600.0, 4200.0, 3.0, 0.2), 0, 0.6], [_tone(0.32, _hz(62), _hz(74), "saw_dark", 4.0), 0, 0.6]])
		# The world slows for a close-up and comes back (audio.gd slowed): the air goes out of the
		# room down a fourth past the octave, D5 to A3, and comes back up it faster. Both stay
		# above 200 Hz: the entrance's own sound has the low end.
		"slow_dip":
			return _mix([[_tone(0.7, _hz(74), _hz(57), "sine", 3.5), 0, 0.7], [_tone(0.7, _hz(74), _hz(57), "saw_dark", 5.0), 0, 0.25],
				[_noise(0.6, 3200.0, 500.0, 5.0, 0.02), 0, 0.35]])
		"slow_rise":
			# A decay under zero is a swell: the tone grows into the return and lets go in 40 ms.
			return _cut(_mix([[_tone(0.3, _hz(57), _hz(74), "sine", -8.0), 0, 0.7], [_noise(0.3, 500.0, 3600.0, 2.0, 0.2), 0, 0.45]]), 0.3, 1800)
		"vault_drop":
			return Synth.render_score([[0, 0, 2, "kick", 1.0], [0, 0, 8, "crash", 0.6], [0, 38, 8, "sub", 0.8],
				[0, 62, 4, "bell", 0.5], [0, 66, 4, "bell", 0.45], [0, 69, 4, "bell", 0.45], [2, 74, 6, "bell", 0.55]], 0.6)
		"synergy_hit":
			return _mix([[_fm(0.22, _hz(81), 3.5, 1.4, 14.0), 0, 0.8], [_noise(0.06, 5000.0, 3000.0, 60.0), 0, 0.2]])
		"boss_arena_in":
			return _brindle_in()
		"boss_phase":
			return Synth.render_score([[0, 0, 2, "boom", 1.0], [0, 0, 2, "anvil", 0.9], [0, 50, 6, "brass", 0.5],
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
			# Air rushing past, then a bell on A, the fifth over the home D: danger went by.
			return _mix([[_noise(0.22, 700.0, 4800.0, 9.0, 0.04), 0, 0.9], [_noise(0.16, 4200.0, 1500.0, 14.0), Synth.seconds(0.1), 0.5],
				[_cut(_n("bell", 81), 0.35), Synth.seconds(0.09), 0.7]])
		"kest_kick_thump":
			# The bomb: a kick and Kest's tom landing on D, the motif's last note, a bright
			# crack on top and a sub that falls away under it.
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
			return hold(id.get_slice("_", 1), Synth.score_step * Harmony.STEPS_PER_BEAT * 2)
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
		"babble":
			return babble("Hm. Hm, hm.", BABBLE_LEVEL)
		"rarity_tick":
			# A common find: one mallet tick on D with a glassy top. Pitched up the reward
			# ladder by rarity, like every rarity cue.
			return _mix([[_cut(_n("mallet", 74), 0.14), 0, 0.9], [_noise(0.015, 7000.0, 5000.0, 250.0), 0, 0.3]])
		"rarity_bell":
			# A rare flare: bells climbing D, A, D with a shimmer on the last, rung higher the
			# rarer the part. The payoff rings the same bell, so the change sounds like the find.
			return _mix([[_cut(_n("bell", 74), 0.3), 0, 0.7], [_cut(_n("bell", 81), 0.3), Synth.seconds(0.06), 0.8],
				[_cut(_n("bell", 86), 0.5), Synth.seconds(0.12), 1.0], [_fm(0.5, _hz(98), 3.5, 1.0, 7.0), Synth.seconds(0.12), 0.25]])
		"rung_coil":
			# A cobalt find: a fleet coil charges from low D up to the A an octave and a fifth above, then its latch clicks
			# home on a high D. It sits under the rare bell, so the rung reads by ear as well.
			return _mix([[_fm_sweep(0.22, _hz(62), _hz(81), 1.4, 5.0), 0, 0.5], [_tone(0.22, _hz(74), _hz(93), "saw_dark", 6.0), 0, 0.35],
				[_noise(0.012, 5200.0, 5200.0, 280.0), Synth.seconds(0.22), 0.8], [_cut(_n("mallet", 86), 0.1), Synth.seconds(0.22), 0.6]])
		"reveal_clank":
			# The reveal card: a salvaged plate dropped on the bench, then its stamp rings a fifth.
			return _mix([[_fm(0.25, 196.0, 1.41, 3.0, 14.0), 0, 0.6], [_tone(0.1, 140.0, 70.0, "sine", 30.0), 0, 0.8],
				[_noise(0.04, 3000.0, 1200.0, 70.0), 0, 0.4], [_cut(_n("mallet", 81), 0.2), Synth.seconds(0.07), 0.8],
				[_cut(_n("bell", 86), 0.45), Synth.seconds(0.15), 0.9]])
		"ceremony_build":
			return _ceremony_build()
		"ceremony_resolve":
			return Synth.render_score(_score_ceremony_resolve(), 1.2)
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
			# The long kill chain's downbeat (AUDIO-V3 section 5 rule 5): the band's own crash.
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
			return hold("crater", Synth.score_step * Harmony.STEPS_PER_BEAT * 2)
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
	if id.begins_with(CAUSE_NOTE):
		return _mix([[_cut(_n("mallet", int(id.trim_prefix(CAUSE_NOTE))), 0.6), 0, 1.0]])
	if id.begins_with(GRID_NOTE):
		var bits := id.trim_prefix(GRID_NOTE).rsplit("_", true, 1)
		return _mix([[_cut(_n(bits[0], int(bits[1])), GRID_NOTE_SECONDS), 0, 1.0]])
	if id.begins_with(PILOT_QUOTE):
		return Synth.render_score(pilot_quote_score(id.trim_prefix(PILOT_QUOTE)), 0.5)
	if id.begins_with(SET_ANSWER):
		return Synth.render_score(SetDirector.answer_score(id.trim_prefix(SET_ANSWER)), 0.5)
	if id.begins_with(SAY):
		return _say(_said(id)[0], _said(id)[1])
	if _assist_parts(id).size() > 0:
		return _assist_sting(_assist_parts(id))
	# A kind added after this bank still gets a sound: a small blip pitched from its
	# name, flagged by presentation_sfx_test so it gets a real recipe.
	return _tone(0.12, _hz(62 + Harmony.pentatonic_step(absi(id.hash()) % 8)), 0.0, "sine", 20.0)


# --- Assist stings ------------------------------------------------------------------

# The two layers that say which move it was, short and a little silly.
static func _assist_base(move: String) -> Array:
	match move:
		"bonk":  # a cartoon bonk: a wooden knock bending down over a kick thump
			return [[_fm(0.22, _hz(74), 1.0, 2.5, 18.0, -7.0), 0, 0.8], [_tone(0.16, 140.0, 55.0, "sine", 24.0), 0, 0.9]]
		"arc":  # a zap that climbs into a bell
			return [[_fm_sweep(0.18, 300.0, 2400.0, 3.0, 14.0), 0, 0.6], [_cut(_n("bell", 81), 0.4), Synth.seconds(0.08), 0.7]]
		"pile":  # three clanks stacking up, low to high
			return [[_fm(0.12, _hz(57), 1.41, 3.0, 26.0), 0, 0.7], [_fm(0.12, _hz(62), 1.41, 3.0, 26.0), Synth.seconds(0.06), 0.7],
				[_fm(0.2, _hz(69), 1.41, 3.0, 18.0), Synth.seconds(0.12), 0.75]]
		"slip":  # a whoosh that slides past, and a little chirp after it
			return [[_noise(0.4, 600.0, 4800.0, 8.0, 0.05), 0, 0.9], [_tone(0.08, _hz(86), _hz(91), "sine", 30.0), Synth.seconds(0.3), 0.4]]
		"anvil":  # a ringing metal clang over a roll of thunder
			return [[_fm(0.6, _hz(69), 1.41, 6.0, 6.0), 0, 0.8], [_noise(0.85, 400.0, 90.0, 3.5, 0.03), Synth.seconds(0.03), 0.9]]
		"static":  # a crackle and a beep, like a radio catching
			return [[_noise(0.25, 3500.0, 6000.0, 16.0, 0.002), 0, 0.6], [_tone(0.1, _hz(81), _hz(81), "saw", 22.0), Synth.seconds(0.05), 0.35]]
		"bulldozer":  # a low growl that shoves forward, then the hit
			return [[_tone(0.35, 55.0, 95.0, "saw_dark", 6.0), 0, 0.8], [_noise(0.12, 900.0, 300.0, 30.0), Synth.seconds(0.28), 0.8]]
	return []


static func _assist_sting(parts: Array) -> PackedFloat32Array:
	var layers := _assist_base(String(parts[0]))
	if int(parts[1]) >= 2:  # heft class 3 and up: an 808 sub drop on home
		layers.append([_tone(0.7, _hz(38), _hz(31), "sine", 4.5), 0, 0.85])
	if int(parts[1]) >= 3:  # heft class 5: a sax stab quoting the pilot's motif, three notes
		var notes := Harmony.motif_notes(String(parts[2]))
		for i in mini(3, notes.size()):
			layers.append([_cut(_n("sax_lounge", int(notes[i])), 0.18), Synth.seconds(0.1 + 0.07 * i), 0.55])
	return _cut(_mix(layers, int(parts[1]) >= 2), 0.95)


# --- The harpoon line ------------------------------------------------------------------

# The bite to a body, two layers: a knock that lands and a ring over it. Variant 0 is the
# one wired in; 1 and 2 are sketches for the owner's ear (tools/sound_sketches.gd).
static func bite(variant: int) -> PackedFloat32Array:
	match variant:
		1:
			return _mix([[_tone(0.14, 260.0, 90.0, "saw_dark", 24.0), 0, 1.0], [_noise(0.025, 3500.0, 2000.0, 140.0), 0, 0.5],
				[_fm(0.3, _hz(81), 2.0, 3.0, 10.0), 0, 0.8], [_fm(0.3, _hz(88), 2.0, 2.0, 10.0), Synth.seconds(0.02), 0.4]])
		2:
			return _mix([[_tone(0.1, 180.0, 70.0, "sine", 30.0), 0, 1.0], [_fm(0.22, _hz(81), 1.41, 5.0, 18.0), 0, 0.9],
				[_noise(0.04, 5000.0, 2500.0, 80.0), 0, 0.35]])
	return _mix([[_tone(0.12, 200.0, 90.0, "sine", 30.0), 0, 0.9], [_noise(0.02, 3000.0, 3000.0, 200.0), 0, 0.4],
		[_fm(0.24, _hz(81), 3.5, 5.0, 16.0), 0, 1.0]])


# The smash's crack, tuned a fifth under the bite's ring (A5 to D5) so the pair resolves.
static func crack(variant: int) -> PackedFloat32Array:
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


# A cut cable: a plucked string settling from a sharp start, lower and longer than the zip.
static func twang() -> PackedFloat32Array:
	var n := Synth.seconds(0.6)
	var buf := Synth.buffer(n)
	var f := _hz(52)
	var phase := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		phase += TAU * f * (1.0 + 0.08 * exp(-t * 16.0)) * (1.0 + 0.012 * sin(TAU * 7.0 * t)) * Synth.INV_RATE
		buf[i] = (sin(phase) + 0.5 * sin(2.0 * phase) + 0.25 * sin(3.0 * phase)) * minf(1.0, t * 1500.0) * exp(-t * 6.0)
	return _mix([[Synth.declick(buf, 8, 300), 0, 1.0], [_noise(0.025, 3000.0, 1500.0, 120.0), 0, 0.5]])


# Whole cycles of every partial and of the tremolo fit the buffer, so it tiles as a loop.
static func _line_hum() -> PackedFloat32Array:
	var length := 0.6
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var f := roundf(_hz(46) * length) / length
	for i in n:
		var t := i * Synth.INV_RATE
		buf[i] = (sin(TAU * f * t) + 0.5 * sin(TAU * 2.0 * f * t) + 0.3 * sin(TAU * 3.0 * f * t)) * (0.85 + 0.15 * sin(TAU * 10.0 * t))
	return buf


# A field find's crack tell (secrets.gd): two drips off a wet face and the quiet between, one loop.
static func _find_drip() -> PackedFloat32Array:
	var length := 1.8
	return _mix([[Synth.buffer(Synth.seconds(length)), 0, 0.0],
		[_tone(0.14, _hz(97), _hz(90), "sine", 38.0), 0, 1.0],
		[_tone(0.1, _hz(94), _hz(88), "sine", 46.0), Synth.seconds(1.05), 0.6]])


# A field find's radio tell: two bars of the dance hour in D minor (the lost tape's key), keys under
# a lead, heard through a wall: a slow wobble and crackle over it. Trimmed to the bars and faded at
# both ends, so the loop's seam is a breath, not a click.
static func _find_radio() -> PackedFloat32Array:
	var score := [[0, 62, 16, "keys", 0.3], [0, 65, 16, "keys", 0.3], [0, 69, 16, "keys", 0.3], [0, 72, 16, "keys", 0.3],
		[16, 55, 16, "keys", 0.3], [16, 58, 16, "keys", 0.3], [16, 62, 16, "keys", 0.3], [16, 65, 16, "keys", 0.3],
		[0, 74, 2, "lead", 0.6], [2, 77, 2, "lead", 0.6], [4, 81, 3, "lead", 0.65], [7, 79, 1, "lead", 0.55],
		[8, 77, 4, "lead", 0.6], [12, 76, 2, "lead", 0.55], [14, 74, 2, "lead", 0.55], [16, 72, 3, "lead", 0.6],
		[19, 70, 1, "lead", 0.5], [20, 69, 4, "lead", 0.6], [24, 67, 2, "lead", 0.55], [26, 69, 2, "lead", 0.55],
		[28, 62, 4, "lead", 0.5], [4, 0, 1, "brush", 0.3], [12, 0, 1, "brush", 0.3], [20, 0, 1, "brush", 0.3], [28, 0, 1, "brush", 0.3]]
	var music := Synth.render_score(score, 0.0)
	var n := 32 * Synth.score_step
	var buf := Synth.buffer(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fade := Synth.seconds(0.04)
	for i in mini(n, music.size()):
		var t := i * Synth.INV_RATE
		var crackle := rng.randf_range(-1.0, 1.0) * (0.5 if rng.randf() < 0.002 else 0.04)
		buf[i] = (music[i] * (0.8 + 0.2 * sin(TAU * 2.5 * t)) + crackle) * minf(1.0, minf(i, n - 1 - i) / float(fade))
	return buf


# --- Scores ----------------------------------------------------------------------------

static func _score_run(at: int) -> Array:
	return [[at, 0, 2, "kick", 1.0], [at, 0, 16, "crash", 0.55], [at, 62, 2, "lead", 0.7], [at + 2, 69, 2, "lead", 0.7],
		[at + 4, 72, 1, "lead", 0.7], [at + 5, 74, 3, "lead", 0.75], [at + 8, 77, 2, "lead", 0.75], [at + 10, 76, 2, "lead", 0.7],
		[at + 12, 74, 4, "lead", 0.75], [at, 53, 3, "keys", 0.35], [at, 57, 3, "keys", 0.35], [at, 60, 3, "keys", 0.35],
		[at, 64, 3, "keys", 0.35], [at + 10, 53, 4, "keys", 0.35], [at + 10, 57, 4, "keys", 0.35], [at + 10, 60, 4, "keys", 0.35],
		[at + 10, 64, 4, "keys", 0.35], [at + 4, 0, 1, "snare", 0.7], [at + 12, 0, 1, "snare", 0.8], [at + 10, 0, 1, "kick", 0.8]]


# The end-of-cycle melody. It climbs the A7 chord, turns, and lands on D, then the
# two little "done" beeps land on the home note an octave up.
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


# Three notes that climb: A, D, A an octave up. It says "bigger" in the band's key.
# A door swinging open, two beats: a clav tumble down and back up on the eighths, then a
# chime with a bell an octave under on beat two. No kick, so it never reads as the stage hit.
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


# A heft class lost to a crane: the climb played back down, A F D, lighter and softer.
# It lands on home, not below it, because the spill trail pays the mass back.
static func _score_class_down() -> Array:
	return [[0, 81, 2, "mallet", 0.7], [2, 77, 2, "mallet", 0.65], [4, 74, 3, "mallet", 0.7], [4, 74, 3, "bell", 0.25]]


# The discovery: a bebop run up the Dorian scale with a chromatic lean on C#, landing
# on high D over the home chord with a crash. The most exciting short cue in the game.
static func _score_synergy() -> Array:
	# The run climbs into the current level's motif, its first four notes an octave up.
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


# The crate shakes for sixteen steps (about 1.4 s, the ceremony row's build_s): toms
# closing in, hats then a snare roll into the burst, and bells climbing the D minor
# pentatonic a rung every two steps, over a breath of air that swells to the lid.
static func _ceremony_build() -> PackedFloat32Array:
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
	var n := Synth.score_step * 16
	var air := _noise(float(n) / RATE, 400.0, 5200.0, 0.0, 0.001)
	for i in n:
		var x := float(i) / n
		air[i] *= x * x
	return _mix([[Synth.render_score(score, 0.05), 0, 1.0], [air, 0, 0.3]])


# The lid bursts on a D chord with a kick and a crash, then a little tune walks A, B, C up
# to the home D: a rice cooker's end-of-cycle song, resolved.
static func _score_ceremony_resolve() -> Array:
	return [[0, 0, 2, "kick", 1.0], [0, 0, 12, "crash", 0.6], [0, 38, 10, "sub", 0.7],
		[0, 62, 10, "keys", 0.4], [0, 69, 10, "keys", 0.4], [0, 74, 10, "keys", 0.4], [0, 77, 10, "keys", 0.4],
		[0, 86, 2, "bell", 0.5], [2, 81, 1, "mallet", 0.7], [3, 83, 1, "mallet", 0.7], [4, 84, 1, "mallet", 0.75],
		[5, 86, 6, "bell", 0.8], [5, 74, 6, "lead", 0.45], [5, 98, 6, "bell", 0.25]]


# --- Recipe helpers --------------------------------------------------------------------

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


# The first length_seconds of a buffer, faded out over `fade` samples. The default suits a
# tick or a stab; a held note or a phrase cut while it still rings wants a longer one.
static func _cut(buf: PackedFloat32Array, length_seconds: float, fade := 600) -> PackedFloat32Array:
	var cut := buf.slice(0, mini(buf.size(), Synth.seconds(length_seconds)))
	return Synth.declick(cut, 8, fade)


# An oscillator with an exponential pitch sweep and exponential decay.
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


# Noise through a resonant band-pass that sweeps f0 to f1, with an attack and decay.
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


static func _arpeggio(notes: Array, gap: float, instrument: String, tail: float) -> PackedFloat32Array:
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
	# Neutral planted mass: a 105-to-55 Hz sweep with a rounded attack, not Kest's bomb.
	return _mix([[_tone(0.9, 105.0, 55.0, "sine", 2.2), 0, 1.0],
		[_fm(0.12, 165.0, 1.41, 1.2, 22.0), Synth.seconds(0.004), 0.18],
		[_noise(0.09, 950.0, 280.0, 30.0, 0.006), 0, 0.22]], true)


static func _ultimate_land() -> PackedFloat32Array:
	# Shared downbeat: a D sub drop under a short Dm7 stab, no pilot motif.
	return _mix([[_tone(1.25, _hz(38), _hz(26), "sine", 3.2), 0, 1.0],
		[_fm(0.12, _hz(62), 2.0, 1.6, 28.0), 0, 0.2],
		[_fm(0.1, _hz(65), 2.0, 1.4, 30.0), 0, 0.16],
		[_fm(0.09, _hz(69), 2.0, 1.2, 32.0), 0, 0.14],
		[_fm(0.08, _hz(72), 2.0, 1.0, 35.0), 0, 0.12],
		[_noise(0.018, 4200.0, 1800.0, 120.0), 0, 0.18]])


static func _kest_demo_knock() -> PackedFloat32Array:
	var parts := [[_fm(0.1, _hz(57), 1.41, 2.0, 45.0), 0, 0.85],
		[_tone(0.08, _hz(53), _hz(41), "sine", 38.0), 0, 0.45],
		[_noise(0.012, 1800.0, 900.0, 150.0), 0, 0.3]]
	# Three discrete pips count the mini charges after the dry knock.
	for i in 3:
		var at := Synth.seconds(0.11 + 0.1 * i)
		var note: int = [86, 89, 93][i]
		parts.append([_fm(0.09, _hz(note), 1.0, 0.45, 48.0), at, 0.36 - 0.03 * i])
		parts.append([_noise(0.008, 5200.0, 3500.0, 250.0), at, 0.12])
	return _mix(parts)


static func _rivet_skid_plate() -> PackedFloat32Array:
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


static func _special() -> PackedFloat32Array:
	var parts: Array = [[_fm_sweep(0.35, 2200.0, 300.0, 6.0, 8.0), 0, 0.7]]
	var rung := 0
	for i in 6:
		parts.append([_cut(_n("bell", 74 + Harmony.pentatonic_step(rung)), 0.3), Synth.seconds(0.03 * i), 0.45])
		rung += 1
	return _mix(parts)


static func _death() -> PackedFloat32Array:
	var parts := []
	var line := [57, 53, 50]
	for i in line.size():
		parts.append([_tone(0.2, _hz(line[i]), _hz(line[i]), "square_dark", 5.0), Synth.seconds(0.17 * i), 0.8])
	# The power-down: a low D that sags a fourth as it dies.
	parts.append([_tone(0.9, _hz(38), _hz(31), "saw_dark", 3.0), Synth.seconds(0.51), 1.0])
	return _mix(parts, true)


static func _hum() -> PackedFloat32Array:
	var n := Synth.seconds(0.32)
	var buf := Synth.buffer(n)
	var f := _hz(62)
	for i in n:
		var t := i * Synth.INV_RATE
		var env := sin(PI * float(i) / n)
		buf[i] = (sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.5 * t) + 0.25 * sin(TAU * f * 2.0 * t)) * env * (0.8 + 0.2 * sin(TAU * 18.0 * t))
	return buf


# Two falling minor-third "WAH"s, one beat each: low, minor, impossible to miss.
static func _klaxon() -> PackedFloat32Array:
	var parts := []
	var beat := Synth.score_step * Harmony.STEPS_PER_BEAT
	for pulse in 2:
		parts.append([_tone(beat * 1.9 / RATE, _hz(53), _hz(50), "square_dark", 1.2), beat * 2 * pulse, 1.0])
		parts.append([_tone(beat * 1.9 / RATE, _hz(41), _hz(38), "saw_dark", 1.2), beat * 2 * pulse, 0.6])
	return _mix(parts, true)


# The Warden breaks: a clamp tearing loose, then the band hits and bells climb out.
static func _unseal() -> PackedFloat32Array:
	var score := [[0, 0, 2, "kick", 1.0], [0, 0, 16, "crash", 0.7], [0, 74, 1, "bell", 0.5], [1, 81, 1, "bell", 0.5],
		[2, 86, 1, "bell", 0.5], [3, 89, 1, "bell", 0.5], [4, 93, 4, "bell", 0.55], [4, 86, 10, "lead", 0.7],
		[4, 65, 10, "keys", 0.4], [4, 69, 10, "keys", 0.4], [4, 72, 10, "keys", 0.4], [4, 76, 10, "keys", 0.4],
		[4, 38, 10, "sub", 0.7], [8, 0, 1, "snare", 0.5], [10, 0, 1, "snare", 0.6], [12, 0, 1, "snare", 0.7],
		[13, 0, 1, "snare", 0.8], [14, 0, 1, "snare", 0.9], [15, 0, 1, "snare", 1.0]]
	var band := Synth.render_score(score, 1.0)
	var release := _mix([[_fm(0.5, 150.0, 1.41, 6.0, 7.0, -5.0), 0, 1.0], [_noise(0.35, 3000.0, 300.0, 9.0), 0, 0.8]], true)
	return _mix([[band, 0, 1.0], [release, 0, 0.6]])


# A plated hit that bounced: a bright ringing plate an octave above the punch, with
# no low body, so it reads as "not through" next to hit_thwack's meaty thud.
static func _clank() -> PackedFloat32Array:
	return _mix([[_fm(0.3, _hz(76), 1.41, 1.6, 11.0), 0, 1.0], [_fm(0.22, _hz(83), 2.76, 1.2, 16.0), 0, 0.55],
		[_tone(0.03, 1800.0, 1200.0, "sine", 90.0), 0, 0.3]])


# Plates knocked loose: `plates` inharmonic FM pings, each a little lower and later than
# the last, over a grit of noise. More plates also add a low thunk, so the size of the hit
# reads by how much falls, not only by loudness. Clatter, never a tune: it must not be
# mistaken for a pickup.
static func _shed(plates: int) -> PackedFloat32Array:
	var notes := [86, 81, 84, 77, 79]
	var parts: Array = [[_noise(0.03 + 0.012 * plates, 4800.0, 2400.0, 90.0 / plates), 0, 0.35]]
	for i in plates:
		parts.append([_fm(0.13 + 0.02 * plates, _hz(notes[i]), 2.76, 1.5, 24.0 - 2.0 * plates), Synth.seconds(0.038 * i), 0.9 - 0.08 * i])
	if plates >= 3:
		parts.append([_tone(0.1 + 0.02 * plates, 170.0, 62.0, "sine", 22.0), 0, 0.5 + 0.1 * plates])
	return _mix(parts)


# The scrap is back: a quick, bright, rising fourth (A to D on the bell), the tail of a
# rice cooker's melody. Audio climbs it up the pentatonic while recoveries keep coming.
static func _reclaim() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 81), 0.2), 0, 0.75], [_cut(_n("bell", 86), 0.32), Synth.seconds(0.075), 0.95],
		[_noise(0.01, 6000.0, 6000.0, 300.0), 0, 0.12]])


# A hit turned aside entirely: one short, soft, high metal tick (a single bell partial and
# a breath of grit, about 110 ms). No plates, no thunk and no second note, so it is not the
# shed's clatter, the reclaim's chime or the hurt's low square.
static func _deflect() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 91), 0.11), 0, 0.8], [_noise(0.012, 7000.0, 5000.0, 250.0), 0, 0.15]])


# A dry, soft crackle: a short filtered noise puff over a low ember tick.
static func _sputter() -> PackedFloat32Array:
	return _mix([[_noise(0.06, 2600.0, 900.0, 60.0, 0.004), 0, 0.5], [_tone(0.05, 300.0, 180.0, "sine", 40.0), 0, 0.5]])


# Torn metal: a zipper of teeth sweeping down while a saw sags.
static func _rip() -> PackedFloat32Array:
	var n := Synth.seconds(0.45)
	var teeth := _noise(0.45, 4200.0, 500.0, 3.0, 0.005)
	for i in n:
		var t := i * Synth.INV_RATE
		var rate := lerpf(70.0, 18.0, float(i) / n)
		teeth[i] *= 0.4 + 0.6 * maxf(0.0, sin(TAU * rate * t))
	return _mix([[teeth, 0, 1.0], [_tone(0.4, 820.0, 180.0, "saw_dark", 5.0), 0, 0.5]], true)


# The lock-in: a click, a thud, and a clean fifth on D that rings out.
static func _core_socket() -> PackedFloat32Array:
	return _mix([[_noise(0.02, 5000.0, 5000.0, 250.0), 0, 0.5], [_tone(0.12, 140.0, 80.0, "sine", 28.0), 0, 0.8],
		[_n("bell", 74), Synth.seconds(0.05), 0.7], [_n("bell", 81), Synth.seconds(0.05), 0.6],
		[_cut(_n("bell", 86), 0.6), Synth.seconds(0.16), 0.45]])


# The Warden wakes: a low anvil strike and a Neapolitan brass swell (Eb over D), the
# sound of the band turning toward the boss groove.
static func _warden_in() -> PackedFloat32Array:
	var score := [[0, 0, 2, "kick", 1.0], [0, 38, 16, "sub", 0.7], [0, 51, 12, "brass", 0.45], [0, 55, 12, "brass", 0.45],
		[0, 58, 12, "brass", 0.45], [4, 0, 2, "kick", 0.8], [8, 0, 2, "kick", 0.9], [12, 0, 2, "kick", 1.0],
		[12, 0, 1, "snare", 0.7], [13, 0, 1, "snare", 0.8], [14, 0, 1, "snare", 0.9], [15, 0, 1, "snare", 1.0]]
	var band := Synth.render_score(score, 0.8)
	return _mix([[band, 0, 1.0], [_fm(0.9, _hz(38), 2.71, 5.0, 3.5), 0, 0.5]], true)


# The slam womp: a sub that drops out of the floor with a thump on top, instant.
static func _womp() -> PackedFloat32Array:
	var n := Synth.seconds(0.62)
	var buf := Synth.buffer(n)
	var phase := 0.0
	for i in n:
		var t := i * Synth.INV_RATE
		phase += TAU * (34.0 + 52.0 * exp(-t * 9.0)) * Synth.INV_RATE
		buf[i] = tanh(2.0 * sin(phase)) * minf(1.0, t * 400.0) * exp(-t * 3.2)
	return _mix([[buf, 0, 1.0], [_noise(0.08, 900.0, 200.0, 40.0), 0, 0.3]], true)


# Two bars of rising noise and pitch, the build's riser (on the grid it is baked for).
static func _build_riser() -> PackedFloat32Array:
	var n := Synth.score_step * Harmony.STEPS_PER_BAR * 2
	var noise := _noise(float(n) / RATE, 300.0, 6000.0, 0.0, 0.001)
	var phase := 0.0
	for i in n:
		var x := float(i) / n
		phase += TAU * lerpf(110.0, 880.0, x * x) * Synth.INV_RATE
		noise[i] = (noise[i] * 0.8 + sin(phase) * 0.35) * x * x
	return Synth.normalize(noise, 0.9)


static func _ice() -> PackedFloat32Array:
	var parts: Array = [[_noise(0.3, 6000.0, 6000.0, 12.0, 0.002), 0, 0.35]]
	var notes := [86, 93, 88, 98, 91]
	for i in notes.size():
		parts.append([_fm(0.3, _hz(notes[i]), 3.5, 1.5, 10.0), Synth.seconds(0.035 * i), 0.5])
	return _mix(parts)


static func _zap_hum() -> PackedFloat32Array:
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


static func _shatter() -> PackedFloat32Array:
	var parts: Array = [[_noise(0.25, 5000.0, 2500.0, 16.0, 0.001), 0, 0.8]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		parts.append([_fm(0.18, rng.randf_range(2200.0, 6000.0), 2.3, 1.0, 26.0), Synth.seconds(rng.randf_range(0.0, 0.12)), 0.35])
	return _mix(parts)


# Admiral Brindle's arrival: two anvil strikes and a brass fanfare that climbs D, F,
# A and lands on the flat second, Eb, the Phrygian colour of his whole arena.
static func _brindle_in() -> PackedFloat32Array:
	var score := [[0, 0, 2, "boom", 1.0], [0, 0, 2, "anvil", 1.0], [0, 38, 16, "sub", 0.6], [2, 0, 2, "anvil", 0.8],
		[4, 62, 2, "brass", 0.6], [6, 65, 2, "brass", 0.6], [8, 69, 2, "brass", 0.65], [8, 0, 2, "kick", 0.9],
		[10, 75, 6, "brass", 0.7], [10, 51, 6, "brass", 0.4], [10, 55, 6, "brass", 0.4], [10, 58, 6, "brass", 0.4],
		[10, 0, 16, "crash", 0.5], [12, 0, 1, "snare", 0.6], [13, 0, 1, "snare", 0.7], [14, 0, 1, "snare", 0.85],
		[15, 0, 1, "snare", 1.0]]
	return Synth.render_score(score, 0.9)


# The stage's ambience drawn out before the arena: a soft breath of air that falls
# and fades, with a low D under it. Quiet on purpose; the arena music is the event.
static func _stage_fade() -> PackedFloat32Array:
	var air := _noise(0.7, 2600.0, 400.0, 0.0, 0.08)
	var n := air.size()
	for i in n:
		var x := float(i) / n
		air[i] *= (1.0 - x) * (1.0 - x)
	return _mix([[air, 0, 1.0], [_tone(0.6, _hz(50), _hz(50), "sine", 4.0), 0, 0.35]], false, 0.6)


# A wind-up: two low minor-second pulses (D, Eb) with a rising noise, over in 0.4 s so
# it never masks the hit it warns about.
static func _boss_telegraph() -> PackedFloat32Array:
	return _mix([[_tone(0.12, _hz(50), _hz(50), "square_dark", 10.0), 0, 0.9],
		[_tone(0.18, _hz(51), _hz(52), "square_dark", 8.0), Synth.seconds(0.13), 1.0],
		[_noise(0.35, 600.0, 3000.0, 3.0, 0.2), 0, 0.35]], true)


# A cued follow-up is coming (fight_phases.gd): three ratchet clicks climbing D, F, A and a
# high bell on D, all inside CUE_LEAD, so the ear has the warning before the eye's short tell.
static func _ratchet_cue() -> PackedFloat32Array:
	return _mix([[_tone(0.05, _hz(62), _hz(62), "square_dark", 30.0), 0, 0.8],
		[_tone(0.05, _hz(65), _hz(65), "square_dark", 30.0), Synth.seconds(0.11), 0.85],
		[_tone(0.05, _hz(69), _hz(69), "square_dark", 30.0), Synth.seconds(0.22), 0.9],
		[_cut(_n("bell", 86), 0.3), Synth.seconds(0.33), 0.7]], true)


# Brindle routed: the brass fanfare in D major, a bell run to the top, and the
# rice-cooker resolution on high D over a held D major chord.
static func _boss_defeated() -> PackedFloat32Array:
	var score := [[0, 0, 2, "boom", 1.0], [0, 0, 16, "crash", 0.7], [0, 62, 2, "brass", 0.6], [2, 66, 2, "brass", 0.6],
		[4, 69, 2, "brass", 0.65], [6, 74, 2, "brass", 0.7], [8, 0, 2, "kick", 1.0], [8, 78, 4, "brass", 0.7],
		[12, 76, 2, "brass", 0.6], [14, 73, 2, "brass", 0.65], [16, 0, 2, "kick", 1.0], [16, 0, 16, "crash", 0.6],
		[16, 74, 16, "brass", 0.75], [16, 86, 16, "bell", 0.5], [16, 50, 16, "keys", 0.4], [16, 54, 16, "keys", 0.4],
		[16, 57, 16, "keys", 0.4], [16, 62, 16, "keys", 0.4], [16, 38, 16, "sub", 0.7]]
	for i in 8:
		score.append([8 + i, 0, 1, "hat", 0.4])
		score.append([8 + i, [74, 78, 81, 86, 90, 93, 98, 93][i], 1, "bell", 0.3])
	return Synth.render_score(score, 1.6)


# A one-beat reverse swell that ends exactly on the next downbeat.
static func _riser() -> PackedFloat32Array:
	var n := Synth.score_step * Harmony.STEPS_PER_BEAT
	var noise := _noise(float(n) / RATE, 400.0, 5000.0, 0.0, 0.001)
	for i in n:
		var x := float(i) / n
		noise[i] *= x * x * x
	return Synth.normalize(noise, 0.9)


# The four threat warnings (combat/threat_grammar.gd), one per attack type, in the
# threat register of SOUND-STORY.md section 3: low, on the sinister degrees of D (Eb,
# Ab, Bb), never on the reward ladder. Each is a one-shot played on the frame the threat
# is declared, so it cannot stretch to the attack's own wind-up.
# Instant: ratchet clicks that speed up, the clock running out, then a clang on Eb.
static func _threat_tick() -> PackedFloat32Array:
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


# Wave: a whoosh that rises through the sinister set, Eb up to Bb, as the front comes on.
static func _threat_whoosh() -> PackedFloat32Array:
	return _mix([[_noise(0.6, 300.0, 2800.0, 1.5, 0.35), 0, 1.0], [_tone(0.6, _hz(51), _hz(58), "saw_dark", 2.0), 0, 0.55]])


# Projectile: a launch thunk, then a whistle falling from Bb to Eb as the shell comes down.
static func _threat_whistle() -> PackedFloat32Array:
	return _mix([[_tone(0.1, 110.0, 50.0, "sine", 28.0), 0, 1.0], [_noise(0.06, 900.0, 300.0, 40.0), 0, 0.5],
		[_tone(0.65, _hz(82), _hz(75), "sine", 1.2), Synth.seconds(0.08), 0.8], [_noise(0.65, 2200.0, 1300.0, 2.5, 0.05), Synth.seconds(0.08), 0.15]])


# Lane: a charge hum on Ab from the frame the lane is declared. It holds for
# THREAT_HUM_HOLD, longer than any lane's warning, and audio.gd cuts it on the frame the
# lane goes live, where the tear plays: the tear is its own one-shot because it means fire
# (SOUND-STORY section 7) and a warning's length varies (1.4 s charge, 0.6 s hook turn).
const THREAT_HUM_HOLD := 3.0

static func _threat_hum() -> PackedFloat32Array:
	return _mix([[_tone(THREAT_HUM_HOLD, _hz(44), _hz(44), "saw_dark", 0.15), 0, 0.8],
		[_tone(THREAT_HUM_HOLD, _hz(56), _hz(56), "square_dark", 0.2), 0, 0.5]], true)


# Lane release: the tearing buzz, sliding Ab down to F.
static func _threat_tear() -> PackedFloat32Array:
	return _mix([[_noise(0.18, 1800.0, 5200.0, 10.0), 0, 0.9], [_tone(0.18, _hz(56), _hz(51), "saw", 12.0), 0, 0.6]], true)


# Burrow: a low Eb rumble with two muffled knocks under the floor.
static func _warn_burrow() -> PackedFloat32Array:
	return _mix([[_tone(0.38, _hz(39), _hz(51), "saw_dark", 3.0), 0, 0.8],
		[_noise(0.09, 350.0, 180.0, 35.0), 0, 0.7],
		[_noise(0.1, 500.0, 250.0, 28.0), Synth.seconds(0.14), 1.0]])


# Bore: three accelerating teeth, then a short Ab rig clang.
static func _warn_bore() -> PackedFloat32Array:
	var parts := []
	for at in [0.0, 0.12, 0.2]:
		parts.append([_noise(0.035, 1800.0, 800.0, 80.0), Synth.seconds(at), 0.7])
		parts.append([_tone(0.06, _hz(44), _hz(44), "square_dark", 35.0), Synth.seconds(at), 0.5])
	parts.append([_fm(0.18, _hz(56), 1.41, 3.0, 16.0), Synth.seconds(0.28), 1.0])
	return _mix(parts)


# Breach: a dry crack across the plate, then the rubble falling away into a low Eb rumble.
static func _breach_crack() -> PackedFloat32Array:
	return _mix([[_noise(0.03, 5200.0, 2400.0, 90.0), 0, 0.9],
		[_fm(0.08, _hz(63), 2.3, 4.0, 30.0), 0, 0.55],
		[_noise(0.36, 1400.0, 220.0, 6.0, 0.02), Synth.seconds(0.06), 0.75],
		[_tone(0.34, _hz(46), _hz(39), "saw_dark", 5.0), Synth.seconds(0.1), 0.8]])


# Lure: a slow bloom of air over the beating Ab/Eb pair, with no reward bell.
static func _warn_lure() -> PackedFloat32Array:
	return _mix([[_noise(0.52, 250.0, 1400.0, 3.0, 0.18), 0, 0.9],
		[_tone(0.52, _hz(44), _hz(44), "sine", 2.0), 0, 0.65],
		[_tone(0.4, _hz(51), _hz(51), "sine", 3.0), Synth.seconds(0.08), 0.45]])


# Cutter: a dry snip followed by a fast, falling metallic spin on Bb.
static func _warn_cut() -> PackedFloat32Array:
	return _mix([[_noise(0.025, 4200.0, 1800.0, 120.0), 0, 0.8],
		[_fm(0.29, _hz(58), 2.71, 5.0, 12.0, -12.0), 0, 1.0]])


# Winch: three evenly spaced cable pawls over a low Bb tension buzz.
static func _warn_winch() -> PackedFloat32Array:
	var parts := [[_tone(0.43, _hz(46), _hz(46), "square_dark", 2.0), 0, 0.6]]
	for at in [0.0, 0.13, 0.26]:
		parts.append([_fm(0.1, _hz(46), 3.5, 4.0, 28.0), Synth.seconds(at), 1.0])
		parts.append([_noise(0.03, 1200.0, 500.0, 90.0), Synth.seconds(at), 0.45])
	return _mix(parts)


# Dive: a breath at the crest, then a sustained Bb-to-Eb falling whistle.
static func _warn_dive() -> PackedFloat32Array:
	return _mix([[_noise(0.56, 1800.0, 350.0, 4.0, 0.06), 0, 0.45],
		[_tone(0.56, _hz(58), _hz(51), "sine", 1.8), 0, 1.0]])


# Tether: the harpoon's spring cocking in two rising Bb ratchet clicks, then a taut wet twang.
static func _warn_tether() -> PackedFloat32Array:
	return _mix([[_noise(0.03, 2600.0, 1200.0, 90.0), 0, 0.6],
		[_noise(0.03, 3200.0, 1500.0, 90.0), Synth.seconds(0.12), 0.7],
		[_fm(0.32, _hz(58), 1.5, 3.0, 7.0, 4.0), Synth.seconds(0.2), 1.0],
		[_noise(0.2, 700.0, 300.0, 9.0, 0.03), Synth.seconds(0.2), 0.35]])


# Flap: a sluice hinge creaking up from Eb to Ab, with a gush of water under it.
static func _warn_flap() -> PackedFloat32Array:
	return _mix([[_tone(0.42, _hz(51), _hz(56), "saw_dark", 2.5), 0, 0.7],
		[_fm(0.42, _hz(63), 2.1, 1.5, 3.0, 5.0), 0, 0.35],
		[_noise(0.4, 600.0, 1600.0, 3.0, 0.12), Synth.seconds(0.05), 0.6]])


# Reel: the boom tender's reel ratcheting five clicks up, one per float lamp, over a low
# tug-engine chug, and a small brass lamp ping on the last.
static func _warn_reel() -> PackedFloat32Array:
	var parts := [[_tone(0.7, _hz(39), _hz(41), "saw_dark", 3.0), 0, 0.5]]
	for i in 5:
		parts.append([_noise(0.025, 1800.0 + 350.0 * i, 900.0, 90.0), Synth.seconds(0.11 * i), 0.55 + 0.05 * i])
	parts.append([_fm(0.3, _hz(70), 2.0, 1.2, 4.0, 6.0), Synth.seconds(0.5), 0.45])
	return _mix(parts)


# Flank call: a crew hand's two-finger whistle, up a fifth and down a step (A to E, then D): someone is
# cutting across your line.
static func _flank_call() -> PackedFloat32Array:
	return _mix([[_tone(0.16, _hz(81), _hz(88), "sine", 4.0), 0, 0.8],
		[_tone(0.2, _hz(88), _hz(86), "sine", 7.0), Synth.seconds(0.15), 0.85],
		[_noise(0.3, 5200.0, 4400.0, 9.0, 0.01), 0, 0.12]])


# Boil rumble: the silt belching up from below, a low wobble rising under a wet gurgle.
static func _boil_rumble() -> PackedFloat32Array:
	return _mix([[_fm(0.9, _hz(31), 1.5, 2.5, 2.0, 3.0), 0, 0.9],
		[_noise(0.8, 300.0, 900.0, 2.5, 0.08), Synth.seconds(0.1), 0.5],
		[_noise(0.06, 1400.0, 700.0, 40.0), Synth.seconds(0.5), 0.35],
		[_noise(0.06, 1700.0, 800.0, 40.0), Synth.seconds(0.72), 0.3]])


# --- The leitmotifs (SOUND-STORY.md section 2) ------------------------------------------
# Every class and faction cue reads its notes from Harmony.MOTIFS, so the class row,
# the band's counter-line and these cues can never disagree about the tune.

# A motif's cells as score events on an instrument, from a step, an octave up or down.
static func _motif_score(id: String, at: int, instrument: String, gain: float, octave := 0) -> Array:
	var score: Array = []
	for cell in Harmony.motif(id).get("cells", []):
		score.append([at + int(cell[0]), int(cell[1]) + octave, int(cell[2]), instrument, gain])
	return score


# A dry paper punch under ledger keys; the total adds a small till bell.
static func tally_recipe(id: String, midi := -1, total := false) -> PackedFloat32Array:
	var direct := midi >= 0
	var saved := []
	if direct:
		_lock.lock()
		saved = [Synth.score_step, Synth.score_transpose, _shift]
		Synth.score_step = Harmony.STEP
		Synth.score_transpose = 0
		_shift = 0
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
	var rendered := Synth.normalize(_mix([[Synth.render_score(score, 0.7), 0, 1.0], [punch, 0, 0.4]]), 0.9)
	if direct:
		Synth.score_step = int(saved[0])
		Synth.score_transpose = int(saved[1])
		_shift = int(saved[2])
		_lock.unlock()
	return rendered


static func kest_score(id: String) -> Array:
	if id == "raid_kest_stinger" or id == "raid_kest_roll":
		return _motif_score("kest", 0, "tom", 0.85).slice(0, 3)
	if id == "raid_kest_boom" or id == "cable_kest_blast":
		return [[0, 50, 4, "tom", 0.85], [0, 50, 4, "sub", 0.65]]
	var note := 62
	if id.begins_with("tick_kest_"):
		note = int(id.trim_prefix("tick_kest_"))
	return [[0, note, 1, "tom", 0.6]]


# Sable's release: the arpeggio reeled up in sixteenths, then the ninth resolving onto
# a bright chord of bells.
static func _sable_release() -> PackedFloat32Array:
	var score := _motif_score("sable", 0, "mallet", 0.8)
	score.append_array(_motif_score("sable", 0, "bell", 0.3, 12))
	for midi in [65, 69, 72, 76]:
		score.append([6, midi + 12, 6, "bell", 0.3])
	score.append_array([[6, 53, 6, "keys", 0.3], [6, 57, 6, "keys", 0.3], [6, 60, 6, "keys", 0.3], [6, 64, 6, "keys", 0.3],
		[6, 88, 6, "bell", 0.25], [6, 0, 2, "open_hat", 0.35]])
	return Synth.render_score(score, 0.9)


# Rivet's release: the hammered note over a closed-hat roll that doubles its rate, the
# fourth landing on the beat with an open-hat crash.
static func _rivet_release() -> PackedFloat32Array:
	var step := Synth.score_step
	var score := _motif_score("rivet", 0, "clav", 0.8)
	score.append_array(_motif_score("rivet", 0, "clav", 0.35, 12))
	score.append_array([[4, 0, 8, "crash", 0.45], [4, 0, 2, "open_hat", 0.7], [4, 0, 2, "kick", 0.6]])
	var parts: Array = [[Synth.render_score(score, 0.8), 0, 1.0]]
	var hits := [0.0, 1.0, 2.0, 2.5, 3.0, 3.25, 3.5, 3.75]
	for i in hits.size():
		parts.append([Synth.drum("hat"), int(hits[i] * step), 0.45 + 0.07 * i])
	return _mix(parts)


# Kest's release: tick, tick, tick, boom. The triad falls on the tuned tom in eighths
# and the last thump is doubled on the 808.
static func _kest_release() -> PackedFloat32Array:
	var score := _motif_score("kest", 0, "tom", 0.85)
	var cells: Array = Harmony.motif("kest")["cells"]
	var last: Array = cells[cells.size() - 1]
	score.append([int(last[0]), int(last[1]) - 12, 8, "sub808", 0.9])
	score.append([int(last[0]), 0, 2, "kick", 0.5])
	return Synth.render_score(score, 1.0)


# Tarn's release: tap, tap, creak, tear. Two Redjaw anvil taps test the latch on the
# reese, the Eb creaks, and the long low A tears it loose over the 808, a kick and a crash.
static func _tarn_release() -> PackedFloat32Array:
	var step := Synth.score_step
	var score := _motif_score("tarn", 0, "reese", 0.8)
	score.append_array([[4, 45, 6, "sub808", 0.7], [4, 0, 2, "kick", 0.6], [4, 0, 8, "crash", 0.45]])
	var parts: Array = [[Synth.render_score(score, 0.9), 0, 1.0]]
	for at in [0, 2]:
		parts.append([Synth.drum("anvil"), int(at * step), 0.7])
	return _mix(parts)


# Tally's release: four card punches count up the keys, then the total is struck.
# A snare stamp, kick, till bell and low D land together after the pen lifts.
static func _tally_release() -> PackedFloat32Array:
	var step := Synth.score_step
	var score := _motif_score("tally", 0, "keys", 0.8)
	score.append_array([[5, 86, 6, "bell", 0.4], [5, 50, 6, "sub808", 0.6], [5, 0, 2, "kick", 0.5]])
	var parts: Array = [[Synth.render_score(score, 0.9), 0, 1.0]]
	for i in 4:
		parts.append([Synth.drum("clap"), int(i * step), 0.4 + 0.08 * i])
	parts.append([Synth.drum("snare"), int(5 * step), 0.8])
	return _mix(parts)


# The rebuilt gun answers the Mind in reverse, climbing to the held D.
static func _cannon_release() -> PackedFloat32Array:
	var step := Synth.score_step
	var score := _motif_score("cannon", 0, "chime", 0.7)
	score.append_array(_motif_score("cannon", 0, "talk", 0.35, -12))
	score.append_array([[0, 0, 2, "kick", 0.6], [4, 0, 2, "kick", 0.6], [4, 0, 8, "crash", 0.45], [4, 50, 6, "sub808", 0.6]])
	var parts: Array = [[Synth.render_score(score, 1.6), 0, 1.0]]
	parts.append([Synth.drum("snare"), int(2 * step), 0.6])
	parts.append([Synth.drum("hat"), int(3 * step), 0.5])
	return _mix(parts)


# The ready pulse: the motif's first note on the class instrument, 120 ms, an octave up
# so it reads over the band ("F is back").
static func _ready_pulse(id: String) -> PackedFloat32Array:
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


# Breaking free: a bright burst in the class colour, then the class's first interval
# an octave up (Rivet's is the fourth its sprint arrives on).
static func _break_free(id: String) -> PackedFloat32Array:
	var row := Harmony.motif_or_first(id)
	var cells: Array = row["cells"]
	var a: int = int(cells[0][1]) + 12
	var b: int = int(cells[cells.size() - 1][1] if id in ["rivet", "tarn", "tally"] else cells[1][1]) + 12
	var voice: String = row["voice"]
	var gap := Synth.score_step
	return _mix([[_noise(0.18, 5200.0, 2600.0, 14.0, 0.001), 0, 0.55], [_cut(_n(voice, a), 0.2), 0, 0.85],
		[_cut(_n(voice, b), 0.35), gap, 0.9], [_cut(_n("bell", b + 12), 0.4), gap, 0.3]])


# The Fleet: stamp, stamp, decree. Two anvil hits on the beat, the brass lean D Eb D on
# the offbeat. Every Fleet unit is a small Brindle.
static func _fleet_motif() -> PackedFloat32Array:
	var score := _motif_score("fleet", 0, "brass", 0.6)
	score.append_array(_motif_score("fleet", 0, "brass", 0.35, 12))
	for stamp in Harmony.motif("fleet")["stamps"]:
		score.append([int(stamp), 0, 2, "anvil", 0.9])
		score.append([int(stamp), 0, 2, "kick", 0.55])
	return Synth.render_score(score, 0.9)


# A reactor vent blowing: a boom, a steam roar falling away, and the Ab pedal dropping
# out of the floor.
static func _reactor_erupt() -> PackedFloat32Array:
	var pedal: int = int(Harmony.motif("reactor")["cells"][0][1])
	return _mix([[Synth.drum("boom"), 0, 1.0], [_noise(1.1, 3800.0, 350.0, 2.6, 0.004), 0, 0.8],
		[_n("sub808", pedal), 0, 0.8], [Synth.drum("crash"), 0, 0.35]], true)


# The swarm locks: the unison buzz snaps into stacked fourths and holds.
static func _swarm_lock() -> PackedFloat32Array:
	var row := Harmony.motif("swarm")
	var unison: int = int(row["cells"][0][1])
	var snap := Synth.seconds(0.3)
	var parts: Array = [[_cut(_n("buzz", unison), 0.32), 0, 1.0], [_noise(0.02, 5000.0, 5000.0, 300.0), snap, 0.5]]
	for midi in row["chord"]:
		parts.append([_cut(_n("buzz", int(midi)), 1.5), snap, 0.6])
	return _mix(parts)


# Scattered: the chord falls apart into single detuned notes, then silence.
static func _swarm_scatter() -> PackedFloat32Array:
	var chord: Array = Harmony.motif("swarm")["chord"]
	var parts: Array = []
	for i in chord.size():
		parts.append([_cut(_n("buzz_loose", int(chord[i])), 0.5 - 0.08 * i), Synth.seconds(0.11 * i), 0.8 - 0.12 * i])
	return _mix(parts)


# The Mind's hand quotes your class motif back, inverted and one note wrong, on a pure
# sine that rings long.
static func _mind_quote(class_id: String) -> PackedFloat32Array:
	var score: Array = []
	for cell in Harmony.mind_quote(class_id):
		score.append([int(cell[0]), int(cell[1]) + 12, int(cell[2]) + 2, "chime", 0.7])
	return Synth.render_score(score, 2.4)


# The Mind's wrong note: the quote's flattened last note rung alone, with the floor a tritone
# under it sliding down a semitone more, so the Highdraft's G never arrives.
static func _mind_wrong(class_id: String) -> PackedFloat32Array:
	var quote: Array = Harmony.mind_quote(class_id)
	var wrong: int = (int(quote[-1][1]) if not quote.is_empty() else 61) + 12
	return _mix([[_cut(_n("bell", wrong), 1.6), 0, 0.8], [_fm(1.6, _hz(wrong - 6), 1.0, 0.4, 1.6, -1.0), 0, 0.5],
		[_tone(1.2, _hz(wrong - 18), _hz(wrong - 19), "sine", 2.0), Synth.seconds(0.1), 0.6], [Synth.drum("crash"), 0, 0.25]])


# The Fleet's mooring anvil (KLANG-KLANG), then its brass a fourth up with the Lydian sharp
# eleven on top and a pulley whirring away into the wind.
static func _fleet_anvil() -> PackedFloat32Array:
	var gap := Synth.seconds(0.17)
	return _mix([[Synth.drum("anvil"), 0, 1.0], [Synth.drum("anvil"), gap, 0.8], [Synth.drum("boom"), 0, 0.6],
		[_cut(_n("brass", 50), 0.7), gap, 0.6], [_cut(_n("brass", 57), 0.7), gap, 0.5], [_cut(_n("brass", 68), 0.7), gap, 0.4],
		[_fm_sweep(0.6, _hz(79), _hz(91), 1.5, 5.0), gap * 2, 0.2]], true)


# A boiler or burner giving way: a pressure hiss that swells, the valve pop with a thud under
# it, the steam roaring off and a two-pipe whistle on D and its tritone.
static func _boiler_burst() -> PackedFloat32Array:
	var pop := Synth.seconds(0.22)
	return _mix([[_noise(0.3, 900.0, 4200.0, 1.0, 0.25), 0, 0.5], [Synth.drum("boom"), pop, 1.0],
		[_noise(0.9, 5000.0, 600.0, 3.0, 0.003), pop, 0.7], [_tone(0.25, 70.0, 40.0, "sine", 12.0), pop, 0.8],
		[_tone(0.7, _hz(74), _hz(76), "sine", 3.5), pop, 0.35], [_tone(0.7, _hz(80), _hz(82), "sine", 3.5), pop, 0.25]], true)
# The Glass Lance: a glass flick, then the Mind's quote in miniature. The first three notes of its
# quote of Sable (D B G) ring fast on the chime two octaves up, and a clean sine holds the
# quote's wrong last note: TINNG. No vocals.
static func _glass_lance() -> PackedFloat32Array:
	var quote: Array = Harmony.mind_quote("sable")
	var parts: Array = [[_fm(0.06, _hz(int(quote[0][1]) + 36), 3.5, 3.0, 45.0), 0, 0.5]]
	for i in 3:
		parts.append([_cut(_n("chime", int(quote[i][1]) + 24), 0.14), Synth.seconds(0.02 + 0.045 * i), 0.7])
	var wrong := int(quote[quote.size() - 1][1]) + 36
	parts.append([_tone(0.9, _hz(wrong), _hz(wrong), "sine", 4.5), Synth.seconds(0.15), 0.55])
	return _mix(parts)


# A hold loop, n samples long. The four counter holds of SOUND-STORY.md section 3 sit
# on the sinister degrees around home, so a chain of them assembles D, Bb, Eb and Ab.
# "crater" (v3 AU2) is the reactor's own hold, the burning ring left by a missed pulse,
# on the family's Ab in its Geiger crackle. strain (0..1) raises the tether's pitch as
# the ball pulls against it. The riser is the one sound that means "this is about to be
# over".
static func hold(kind: String, n: int, strain := 0.0) -> PackedFloat32Array:
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


# The shop bell: a counter bell, then the rice cooker's two "done" beeps on high D.
static func _shop_bell() -> PackedFloat32Array:
	return _mix([[_fm(0.6, _hz(93), 3.5, 2.0, 5.0), 0, 0.6], [_cut(_n("beep", 86), 0.12), Synth.seconds(0.16), 0.9],
		[_cut(_n("mallet", 86), 0.12), Synth.seconds(0.16), 0.5], [_cut(_n("beep", 86), 0.2), Synth.seconds(0.34), 0.9],
		[_cut(_n("mallet", 86), 0.2), Synth.seconds(0.34), 0.5]])


# --- v3 AU2 bank: bets, secrets, allies, fights and the ride ---------------------------
# design-v3/AUDIO-V3.md sections 4 (interactables), 5 (W11's juice), 8 (this wave) and
# 11 (Andrew's ruling on the bet's pitch, option a).

# The bet's question: an anvil accent under the fbass leaping the tritone, D to Ab.
static func _bet_clunk() -> PackedFloat32Array:
	return _mix([[Synth.drum("anvil"), 0, db_to_linear(-6.0)], [_cut(_n("fbass", 38), 0.16), 0, 0.9],
		[_cut(_n("fbass", 44), 0.22), Synth.seconds(0.1), 0.9]])


# The 0.35 s hold: a snare roll accelerating from the eighth at 172 to the thirty-second.
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


# The win: the question resolves up a semitone, Ab to A, home's own dominant, with a
# snare crack and the rice-cooker's two "done" beeps a fifth up (A5 D6, not D6 D6).
static func _bet_crack() -> PackedFloat32Array:
	return _mix([[Synth.drum("snare"), 0, 1.0], [_cut(_n("fbass", 45), 0.24), 0, 0.9],
		[_cut(_n("beep", 81), 0.12), Synth.seconds(0.1), 0.8], [_cut(_n("mallet", 81), 0.12), Synth.seconds(0.1), 0.45],
		[_cut(_n("beep", 86), 0.2), Synth.seconds(0.26), 0.9], [_cut(_n("mallet", 86), 0.2), Synth.seconds(0.26), 0.5]])


# The loss: the question resolves down a semitone, Ab to G, and stops on a dry click.
static func _bet_refusal() -> PackedFloat32Array:
	return _mix([[_noise(0.04, 3000.0, 3000.0, 150.0), 0, 0.5], [_cut(_n("fbass", 43), 0.3), 0, 0.85]])


# The reward bell an octave down through a dark low-pass: the ladder's first interval
# reversed, a falling fourth A to D, something old rather than earned.
static func _sunken_bell() -> PackedFloat32Array:
	var bell := _mix([[_n("bell", 69), 0, 0.85], [_n("bell", 62), Synth.seconds(0.22), 1.0]])
	var low := 0.0
	var g := 2.0 * sin(PI * 900.0 * Synth.INV_RATE)
	for i in bell.size():
		low += g * (bell[i] - low)
		bell[i] = low
	return _cut(bell, 2.0)


# The ally quotes you right: the class motif straight on the Mind's own sine, an octave
# up, where the Mind's hand quotes it wrong (_mind_quote always inverts).
static func _ally_hum(class_id: String) -> PackedFloat32Array:
	return Synth.render_score(_motif_score(class_id, 0, "chime", 0.7, 12), 1.4)


# The wake: a Cherenkov flicker on bell, D6 A5 D6, 40 ms apart.
static func _ally_wake() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 86), 0.1), 0, 0.8], [_cut(_n("bell", 81), 0.12), Synth.seconds(0.04), 0.7],
		[_cut(_n("bell", 86), 0.16), Synth.seconds(0.08), 0.9]])


# The opt-in fight's arm: one anvil stamp on the beat, the Fleet's brass lean (D to Eb)
# under it, so a small fight still sounds like a small Brindle (SOUND-STORY section 2).
static func _fight_arm_stamp() -> PackedFloat32Array:
	return _mix([[Synth.drum("anvil"), 0, 1.0], [_n("brass", 50), 0, 0.5],
		[_n("brass", 51), Synth.seconds(0.12), 0.4]], true)


# The class-colour whip: a rising sweep plus the class motif's first interval, an
# octave up, on the class's own voice (SOUND-STORY section 5, "a reward, not a threat").
static func _near_miss_whip(class_id: String) -> PackedFloat32Array:
	var notes := whip_notes(class_id)
	return _mix([[_noise(0.22, 700.0, 4800.0, 9.0, 0.04), 0, 0.85],
		[_cut(_n(notes[0], notes[1]), 0.16), 0, 0.8], [_cut(_n(notes[0], notes[2]), 0.22), Synth.seconds(0.09), 0.85]])


# Four bright notes up the home key's pentatonic, D F G A, a fountain of scrap: a rising
# mallet line with a bell an octave over it and a spray of noise on the last note.
static func _pickup_fountain() -> PackedFloat32Array:
	var step := Synth.seconds(0.075)
	var parts: Array = []
	var notes := [74, 77, 79, 81]
	for i in notes.size():
		parts.append([_cut(_n("mallet", notes[i]), 0.2), i * step, 0.75 + 0.07 * i])
		parts.append([_cut(_n("bell", notes[i] + 12), 0.2), i * step, 0.25])
	parts.append([_noise(0.08, 5200.0, 3200.0, 30.0), 3 * step, 0.3])
	return _mix(parts)


# Two causes become one: A below and D above close in on F, the minor third of the home
# key, which rings as a chord of bells over the keys.
static func _synergy_fired() -> PackedFloat32Array:
	var score := [[0, 69, 2, "mallet", 0.7], [1, 86, 2, "bell", 0.6], [3, 77, 5, "mallet", 0.85], [3, 77, 5, "bell", 0.4],
		[3, 65, 5, "keys", 0.35], [3, 62, 5, "keys", 0.3]]
	return Synth.render_score(score, 0.05)


# Something became more: the fourth A to D, then the octave over it, ringing.
static func _evolution_fired() -> PackedFloat32Array:
	var score := [[0, 69, 2, "mallet", 0.7], [2, 74, 2, "mallet", 0.8], [4, 86, 4, "mallet", 0.9], [4, 86, 4, "bell", 0.5],
		[4, 74, 4, "keys", 0.35], [4, 62, 4, "sub808", 0.4]]
	return Synth.render_score(score, 0.05)


# A page turned and a note was written: a soft falling pair, A then F, a breath of
# paper under the first, one quiet low note after.
static func _lore_found() -> PackedFloat32Array:
	return _mix([[_noise(0.14, 3000.0, 1200.0, 18.0, 0.03), 0, 0.3],
		[_cut(_n("keys", 81), 0.3), 0, 0.8], [_cut(_n("keys", 77), 0.4), Synth.seconds(0.2), 0.7],
		[_cut(_n("bell", 74), 0.45), Synth.seconds(0.42), 0.35]])


# The pilot's own motif opening: its first phrase on its own voice, cut to under a second.
static func _pilot_unlocked(class_id: String) -> PackedFloat32Array:
	var row := Harmony.motif_or_first(class_id)
	var score := _motif_score(class_id, 0, row["voice"], 0.8)
	score.append_array(_motif_score(class_id, 0, "bell", 0.25, 12))
	return _cut(Synth.render_score(score, 0.4), 0.85, Synth.seconds(0.12))


# A two-note ladder stab, the kill chain's own accent so a tier never sounds like a lone
# kill_pop; resolved by rung through the same pitch ratio kill_pop already uses.
static func _kill_chain_tier() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 74), 0.14), 0, 0.85], [_cut(_n("bell", 77), 0.14), 0, 0.7],
		[_noise(0.03, 5500.0, 4000.0, 130.0), 0, 0.4]])


# The drop the player caused: the reward note on the ladder, then the rebound's own
# spring snap, resolved by segments cut the same way.
static func _drop_landing() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 74), 0.3), 0, 0.85], [_tone(0.12, 260.0, 620.0, "sine", 26.0), Synth.seconds(0.02), 0.7],
		[_noise(0.03, 5000.0, 3000.0, 120.0), 0, 0.4]])


# The shell's released spring: a sine that snaps up and settles back, with a small metal tick.
static func _shell_spring() -> PackedFloat32Array:
	return _mix([[_tone(0.16, 240.0, 620.0, "sine", 14.0), 0, 0.9], [_tone(0.22, 620.0, 410.0, "sine", 16.0), Synth.seconds(0.05), 0.6],
		[_noise(0.02, 4500.0, 3000.0, 200.0), 0, 0.3]])


# The held-door ready pulse, class-independent: a bright blip on the next sixteenth, so
# a hit reads as progress without borrowing whichever class happens to be playing.
static func _door_tick() -> PackedFloat32Array:
	return _mix([[_cut(_n("bell", 86), 0.08), 0, 0.8], [_noise(0.015, 6500.0, 6500.0, 250.0), 0, 0.35]])


# The return's launch grammar: the rice-cooker climb up A7, on the ride family's mallet,
# pitched by throw speed at playback (KEYED_SOUNDS carries it, same as every ride cue).
static func _return_launch_arpeggio() -> PackedFloat32Array:
	return _arpeggio(Harmony.LAUNCH_TUNE, 0.07, "mallet", 0.5)


# The bone gauge's pressure hiss, rising through the cycle: noise only, so it never
# competes with a pitched cue for the ear.
# --- Arena locks and Warden gates (src/world/stage_locks.gd) ---------------------------
# The yard shuts: an iron gate drops on a sub boom, and a square falls a minor third, D to B,
# so the room reads "closed" before the crew lands.
static func _arena_lock_slam() -> PackedFloat32Array:
	return _mix([[_noise(0.5, 180.0, 60.0, 7.0), 0, 1.0],
		[_tone(0.7, _hz(38), _hz(31), "sine", 4.0), 0, 0.9],
		[_tone(0.18, _hz(62), 0.0, "square_dark", 9.0), Synth.seconds(0.06), 0.45],
		[_tone(0.36, _hz(59), 0.0, "square_dark", 6.0), Synth.seconds(0.22), 0.5],
		[_noise(0.06, 3200.0, 1800.0, 60.0), Synth.seconds(0.02), 0.35]], true)


# The next wave is coming: a pure whistle falls an octave over a low tick, the same fall the
# hazard warnings use, so the 1.5 s before it lands reads as "incoming".
static func _arena_wave_whistle() -> PackedFloat32Array:
	return _mix([[_tone(0.9, _hz(86), _hz(74), "sine", 2.0), 0, 0.8],
		[_noise(0.04, 1400.0, 900.0, 60.0), 0, 0.4], [_noise(0.04, 1400.0, 900.0, 60.0), Synth.seconds(0.45), 0.4]])


# The yard opens: a latch clicks, then three bells climb the pentatonic to the home D, the
# same walk up as the ceremony's, short.
static func _arena_unlock_bells() -> PackedFloat32Array:
	var score := [[0, 69, 1, "mallet", 0.6], [1, 72, 1, "mallet", 0.65], [2, 74, 4, "bell", 0.8], [2, 86, 4, "bell", 0.3]]
	return _mix([[_noise(0.04, 2800.0, 1400.0, 80.0), 0, 0.5],
		[Synth.render_score(score, 0.05), Synth.seconds(0.04), 1.0]])


# One crew counted on the Warden's clamp: a single bright brass ping that climbs with the
# count (the caller pitches it), small enough to stack in a fight.
static func _warden_gate_pip() -> PackedFloat32Array:
	return _mix([[_fm(0.32, _hz(74), 2.0, 1.4, 9.0), 0, 1.0], [_noise(0.03, 3600.0, 2400.0, 90.0), 0, 0.3]])


# A hit on a gated Warden: a dull clank on the clamp, no ring, so it never sounds like progress.
static func _warden_gate_clunk() -> PackedFloat32Array:
	return _mix([[_noise(0.12, 420.0, 260.0, 30.0), 0, 1.0], [_tone(0.14, _hz(45), _hz(43), "square_dark", 22.0), 0, 0.6]])


# The clamp lets go: a chain rattles off and a D major chord blooms, the fight is on.
static func _warden_gate_release() -> PackedFloat32Array:
	var parts := []
	for i in 6:
		parts.append([_noise(0.03, 2200.0 + 300.0 * i, 1200.0, 80.0), Synth.seconds(0.05 * i), 0.5])
	var chord := [[0, 62, 6, "keys", 0.45], [0, 66, 6, "keys", 0.4], [0, 69, 6, "keys", 0.4], [0, 74, 6, "bell", 0.6], [0, 38, 6, "sub", 0.6]]
	parts.append([Synth.render_score(chord, 0.05), Synth.seconds(0.3), 1.0])
	return _mix(parts)


# A Called Shot is inked: a stamp thumps, then two brass notes climb D to A, a promise made. It
# shares nothing with the gate's dull clank, so placing a bet never sounds like being refused.
static func _call_ink() -> PackedFloat32Array:
	var score := [[0, 62, 1, "brass", 0.6], [1, 69, 3, "brass", 0.75]]
	return _mix([[_noise(0.06, 900.0, 500.0, 45.0), 0, 0.7], [_tone(0.08, _hz(38), _hz(36), "sine", 30.0), 0, 0.6],
		[Synth.render_score(score, 0.05), Synth.seconds(0.03), 1.0]])


# The call missed: one muted note sags from A down to E and stops dead, no ring and no chord, so a
# lost bet is heard as a let-down and never as a warning.
static func _call_drop() -> PackedFloat32Array:
	return _mix([[_tone(0.34, _hz(57), _hz(52), "square_dark", 9.0), 0, 0.8], [_noise(0.05, 600.0, 300.0, 50.0), 0, 0.3]])


# The shell at redline is about to cook off: a kettle whistle that climbs from D to the tritone
# above over two seconds and swells as it goes, so the last two seconds of the fuse are heard.
static func _heat_kettle() -> PackedFloat32Array:
	var n := Synth.seconds(2.0)
	var whistle := _tone(2.0, _hz(86), _hz(92), "sine", 0.0)
	var breath := _noise(2.0, 5200.0, 7400.0, 0.0, 0.3)
	for i in n:
		var swell := 0.25 + 0.75 * float(i) / n
		whistle[i] *= swell
		breath[i] *= swell
	return _mix([[whistle, 0, 0.8], [breath, 0, 0.18]])


static func _lift_hiss() -> PackedFloat32Array:
	var hiss := _noise(1.2, 500.0, 3200.0, 0.0, 0.05)
	var n := hiss.size()
	for i in n:
		var x := float(i) / n
		hiss[i] *= x * x
	return Synth.declick(Synth.normalize(hiss, 0.85), 64, 300)


# --- Moss's babble (SOUND-STORY.md section 8) --------------------------------------------
# One letter at a time, drawn from the beat root's Dorian triad and seeded by the line, so a
# line always babbles the same way. beat is 1 to 6 for the conversation loop, BABBLE_LEVEL
# for barks, BABBLE_RELENT for the sigh. Moss says his letters through the mouth his caller
# row gives him (Andrew, 10 November 2026: mouths for everyone alive), the sigh through a
# larger one; with no mouth on his row each letter is his old blip, a square through a
# 1.2 kHz low-pass.

static func babble(text: String, beat: int, shift := 0) -> PackedFloat32Array:
	var relent := beat == BABBLE_RELENT
	var laid := _babble_blips(text, beat)
	var buf := Synth.buffer(Synth.seconds(float(laid[1]) + 0.3))
	var row: Dictionary = CALLERS[MOSS]
	for blip in laid[0]:
		var piece: PackedFloat32Array
		if blip[5]:
			piece = _grumble(int(blip[1]) + shift)
		elif row.has("mouth"):
			piece = _mouth(int(blip[1]) + shift + int(row.get("drop", 0)), float(blip[2]), float(blip[4]), blip[6], float(row["mouth"]) * (BENCH_SIGH if relent else 1.0))
		else:
			piece = _blip(int(blip[1]) + shift, float(blip[2]), relent, float(blip[4]))
		Synth.add_into(buf, piece, Synth.seconds(float(blip[0])), float(blip[3]))
	return Synth.declick(Synth.normalize(buf, 0.9 * (BENCH_SIGH_LEVEL if relent and row.has("mouth") else 1.0)), 16, 600)


# A line laid out as Moss's blips [seconds, midi, seconds long, gain, glide, grumble, letter],
# and where the last one ends.
static func _babble_blips(text: String, beat: int) -> Array:
	var relent := beat == BABBLE_RELENT
	var root: int = BABBLE_ROOTS[beat - 1] if beat >= 1 and beat <= 6 else 50
	var triad := [root, Harmony.scale_shift(root, 2, Harmony.DORIAN), Harmony.scale_shift(root, 4, Harmony.DORIAN)]
	var speed := pow(0.92, maxi(beat - 1, 0)) * (1.25 if relent else 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = text.hash()
	var words := text.split(" ", false)
	var blips: Array = []
	var at := 0.0
	for w in words.size():
		var word: String = words[w]
		var letters := _letters(word)
		var slow := 1.6 if beat == 6 and w == words.size() - 1 else 1.0
		for l in letters.size():
			var vowel: bool = letters[l] in VOWELS
			var length := (0.08 if vowel else 0.04) * speed * slow
			var midi: int = triad[rng.randi() % 3]
			var gain := 1.0
			if l == 0:
				midi = Harmony.scale_shift(midi, 1, Harmony.DORIAN)
				gain = db_to_linear(3.0)
			if l == letters.size() - 1 and word.ends_with("?"):
				midi += 5
			blips.append([at, midi, length, gain, 0.0, false, letters[l]])
			at += length
		if w == 0 and beat in [2, 4, 6]:
			blips.append([0.0, root - 12, 0.2, 0.9, 0.0, true, ""])
		if word.ends_with(","):
			at += 0.12
		elif _ends_sentence(word):
			at += 0.25
		else:
			at += 0.03 * speed
	if relent and not blips.is_empty():
		var last: Array = blips[blips.size() - 1]
		last[2] = 0.32
		last[4] = -7.0
		at = maxf(at, float(last[0]) + 0.32)
	return [blips, at]


static func _letters(word: String) -> Array:
	var letters: Array = []
	for c in word:
		if c.to_lower() != c.to_upper():
			letters.append(c.to_lower())
	return letters


static func _ends_sentence(word: String) -> bool:
	return word.ends_with(".") or word.ends_with("?") or word.ends_with("!")


# One babble blip. glide bends it down that many semitones across its length (the
# relent's closing fifth). warm swaps the square for a softer triangle.
static func _blip(midi: int, length: float, warm: bool, glide: float) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	var phase := 0.0
	var low := 0.0
	var band := 0.0
	var g := 2.0 * sin(PI * (800.0 if warm else 1200.0) * Synth.INV_RATE)
	for i in n:
		var t := i * Synth.INV_RATE
		var x := float(i) / n
		phase = fposmod(phase + Harmony.hz(midi + glide * x) * Synth.INV_RATE, 1.0)
		var wave := (1.0 - 4.0 * absf(phase - 0.5)) if warm else (1.0 if phase < 0.5 else -1.0)
		low += g * band
		band += g * (wave - low - 0.9 * band)
		buf[i] = low * minf(1.0, t / 0.005) * (1.0 - 0.6 * x)
	return Synth.declick(buf, 8, 96)


# The refusal grumble: a dark saw burst on the beat root, under the first word.
static func _grumble(midi: int) -> PackedFloat32Array:
	return _tone(0.2, Harmony.hz(midi), Harmony.hz(midi - 1), "saw_dark", 6.0)


# --- Callers (SOUND-STORY.md section 8, "Who talks on what") -----------------------------

# The bank id of a caller's line. A caller with no row is warned about here, once, on the
# thread that asks for the line; the bake on a worker only reads the rows.
static func say_id(speaker: String, text: String) -> String:
	if not CALLERS.has(speaker) and not unknown_callers.has(speaker):
		unknown_callers[speaker] = true
		push_warning("sfx_bank: no caller row for '%s'; the line uses Moss's voice" % speaker)
	return "%s%s|%s" % [SAY, speaker, text]


# The caller and the line of a say id.
static func _said(id: String) -> Array:
	var parts := id.trim_prefix(SAY).split("|", true, 1)
	return [parts[0], parts[1] if parts.size() > 1 else ""]


# Drops every caller's line but this one's: a line is said and done, and a run of calls would
# otherwise keep each one for good.
static func keep_said(id: String) -> void:
	_cache_lock.lock()
	for key in _samples.keys():
		if key.begins_with(SAY) and key != id and not key.begins_with(id + "@"):
			_samples.erase(key)
	_cache_lock.unlock()


# The caller's row: its own, else Moss's.
static func _caller(speaker: String) -> Dictionary:
	return CALLERS.get(speaker, CALLERS[MOSS])


static func caller_on_grid(speaker: String) -> bool:
	return _caller(speaker).get("grid", false)


# The notes a caller's letters are drawn from, lowest first heard first: its motif's, lifted,
# or its root's Dorian triad.
static func _caller_notes(speaker: String) -> Array:
	var row := _caller(speaker)
	var notes: Array = []
	for midi in Harmony.motif_notes(row.get("motif", "")):
		if not (midi + int(row.get("lift", 0))) in notes:
			notes.append(midi + int(row.get("lift", 0)))
	if notes.is_empty():
		var root := int(row.get("root", 50))
		notes = [root, Harmony.scale_shift(root, 2, Harmony.DORIAN), Harmony.scale_shift(root, 4, Harmony.DORIAN)]
	return notes


static func _caller_voice(speaker: String) -> String:
	var row := _caller(speaker)
	return row.get("voice", Harmony.motif(row.get("motif", "")).get("voice", ""))


# How long a caller's line lasts, chirp included, at the band's sixteenth.
static func say_seconds(speaker: String, text: String, step := Harmony.STEP) -> float:
	return float(_say_plan(speaker, text, step)[1]) + 0.3


# A caller's line laid out as [seconds, midi, seconds long, gain, bend, voice, letter] and where
# the last one ends: the chirp (no letter), then one blip a letter. A line is laid out the same way every
# time it is said. voice "" is Moss's own blip.
static func _say_plan(speaker: String, text: String, step := Harmony.STEP) -> Array:
	var row := _caller(speaker)
	if row.get("bench", false):
		return _moss_call(text)
	var notes := _caller_notes(speaker)
	var voice := _caller_voice(speaker)
	var loose := float(row.get("loose", CALL_LOOSE))
	var grid: bool = row.get("grid", false)
	var unit := float(step) / Harmony.RATE
	var pace := float(row.get("pace", 1.0))
	var bend := float(row.get("bend", 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = (speaker + text).hash()
	var chirp := [notes[0], notes[0] + 7] if grid else [notes[0], notes[notes.size() - 1]]
	var blips: Array = []
	for i in 2:
		blips.append([i * (unit if grid else CHIRP_NOTE_S), chirp[i], unit * 0.7 if grid else CHIRP_NOTE_S, 1.0 if grid else CHIRP_GAIN, 0.0, voice, ""])
	var at := 4.0 * unit if grid else CALL_TALK_S
	var said := 0
	var joined := false
	for word in text.split(" ", false):
		var letters := _letters(word)
		if letters.is_empty():
			continue
		var other: bool = row.has("second") and said % 2 == 1
		if other and joined:
			at -= CALL_OVERLAP_S
		said += 1
		joined = not (word.ends_with(",") or _ends_sentence(word))
		for l in letters.size():
			var vowel: bool = letters[l] in VOWELS
			if grid:
				blips.append([at, notes[0], unit * 0.35, 1.0, 0.0, voice, letters[l]])
				at += unit * 0.5
				continue
			var length := (0.08 if vowel else 0.04) * pace * rng.randf_range(1.0 - loose, 1.0 + loose)
			var midi: int = notes[rng.randi() % notes.size()]
			if other:
				midi = Harmony.scale_shift(midi, int(row["second"]), Harmony.DORIAN)
			if l == letters.size() - 1 and word.ends_with("?"):
				midi += 5
			var last_of_sentence: bool = l == letters.size() - 1 and _ends_sentence(word)
			if last_of_sentence and row.get("lean", false):
				midi = int(notes[0]) + 1
				length = 0.28
			blips.append([at, midi, length, db_to_linear(3.0) if l == 0 else (0.7 if other else 1.0),
				bend if vowel or l == 0 else 0.0, voice, letters[l]])
			at += length
		if grid:
			at = (ceilf(at / unit + 0.499) + (2.0 if _ends_sentence(word) else (1.0 if word.ends_with(",") else 0.0))) * unit
		elif word.ends_with(","):
			at += 0.04 if row.get("run", false) else 0.12
		elif _ends_sentence(word):
			at += 0.25 * float(row.get("stop", 1.0))
		elif not (row.get("run", false) or row.has("second")):
			at += 0.03 * pace
	return [blips, at]


# Moss calling in: the bell on his counter twice, then the line in his bench voice.
static func _moss_call(text: String) -> Array:
	var blips: Array = []
	for i in 2:
		blips.append([i * 0.16, 86, CHIRP_NOTE_S, CHIRP_GAIN, 0.0, "mallet", ""])
	var laid := _babble_blips(text, BABBLE_LEVEL)
	for blip in laid[0]:
		blips.append([CALL_TALK_S + float(blip[0]), blip[1], blip[2], blip[3], blip[4], "", blip[6]])
	return [blips, CALL_TALK_S + float(laid[1])]


static func _say(speaker: String, text: String) -> PackedFloat32Array:
	var plan := _say_plan(speaker, text, Synth.score_step)
	var row := _caller(speaker)
	var buf := Synth.buffer(roundi((float(plan[1]) + 0.3) * Harmony.RATE))
	for blip in plan[0]:
		var voice: String = blip[5]
		var piece: PackedFloat32Array
		if row.has("mouth") and blip[6] != "":
			piece = _mouth(int(blip[1]) + int(row.get("drop", 0)) + _shift, float(blip[2]), float(blip[4]), blip[6], float(row["mouth"]))
		elif voice == "":
			piece = _blip(int(blip[1]) + _shift, float(blip[2]), false, float(blip[4]))
		else:
			piece = _letter(voice, int(blip[1]), float(blip[2]), float(blip[4]))
		Synth.add_into(buf, piece, roundi(float(blip[0]) * Harmony.RATE), float(blip[3]))
	return Synth.declick(buf, 16, 600)


# One letter said by a mouth: a reed at the note (in the key the caller passes; nothing here
# reads the bake's, so Moss's bench line can be said off a bake) through the letter's two
# resonances, scaled
# by the mouth's size, with the same scoop a played letter gets. A vowel is its own shape; a
# consonant is half shut and shorter of breath, m and n hum, and the hissed and stopped ones
# start as air. The air is seeded by the letter and the note, so a line is said the same
# way twice.
static func _mouth(midi: int, length: float, bend: float, letter: String, size: float) -> PackedFloat32Array:
	var n := Synth.seconds(length * MOUTH_RING)
	var buf := Synth.buffer(n)
	var vowel := MOUTH_VOWELS.has(letter)
	var shape: Array = MOUTH_VOWELS.get(letter, MOUTH_HUM if letter in MOUTH_HUMMED else MOUTH_SHUT)
	var g1 := 2.0 * sin(PI * float(shape[0]) * size * Synth.INV_RATE)
	var g2 := 2.0 * sin(PI * float(shape[1]) * size * Synth.INV_RATE)
	var air := 0.3 if letter in MOUTH_BREATHED else 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(letter) + midi
	var phase := 0.0
	var l1 := 0.0
	var b1 := 0.0
	var l2 := 0.0
	var b2 := 0.0
	for i in n:
		var x := float(i) / n
		var slot := minf(1.0, x * MOUTH_RING)
		phase = fposmod(phase + Harmony.hz(midi + (bend * (slot - 1.0) if bend > 0.0 else bend * slot)) * Synth.INV_RATE, 1.0)
		var reed := 2.0 * phase - 1.0
		if x < air:
			reed = lerpf(rng.randf_range(-1.0, 1.0), reed, x / air)
		l1 += g1 * b1
		b1 += g1 * (reed - l1 - 0.25 * b1)
		l2 += g2 * b2
		b2 += g2 * (reed - l2 - 0.2 * b2)
		buf[i] = (b1 + 0.6 * b2) * minf(1.0, i / 220.0) * (1.0 - 0.7 * x)
	return Synth.declick(Synth.normalize(buf, MOUTH_PEAK if vowel else MOUTH_PEAK * 0.6), 8, 200)


# One letter in a caller's voice: the front of that instrument's note, scooped up into its
# pitch by bend semitones (or falling away from it when bend is negative). The pure voice is
# a sine with square shoulders and no bend: it starts, holds and stops.
static func _letter(voice: String, midi: int, length: float, bend: float) -> PackedFloat32Array:
	var n := Synth.seconds(length)
	var buf := Synth.buffer(n)
	if voice == PURE:
		var f := _hz(midi)
		for i in n:
			buf[i] = sin(TAU * f * i * Synth.INV_RATE) * minf(1.0, minf(i, n - 1 - i) / 130.0)
		return buf
	var note := _n(voice, midi)
	var pos := 0.0
	for i in n:
		var x := float(i) / n
		var j := int(pos)
		if j + 1 >= note.size():
			break
		buf[i] = lerpf(note[j], note[j + 1], pos - j) * (1.0 - 0.6 * x)
		pos += pow(2.0, (bend * (x - 1.0) if bend > 0.0 else bend * x) / 12.0)
	return Synth.declick(buf, 8, 96)
