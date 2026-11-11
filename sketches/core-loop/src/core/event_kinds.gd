extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# One row per GameEvents signal, keyed by the signal's name. Form mirrors function: the
# HUD toast, the objective line, the VFX shape and colour, the synthesized sound and
# the field-notes legend all read the same row, so a fact looks, sounds and reads the
# same way everywhere it shows up.
#
# group     movement | combat | economy | flow | event: the family, so music and VFX
#           can treat a family alike (all movement cues share the amber family).
# color     the one colour for this fact on screen.
# shape     ring | diamond | square | chevron | arrow | burst | bar | star | cross | wave
#           | none: the silhouette a VFX or HUD glyph uses, so colour is never alone.
# sound     the id writer C synthesizes; kinds may share an id on purpose.
# hud       toast wording, "" for none. Placeholders: {stage} {part} {event} {class}
#           {name}.
# objective standing objective while the flow state this kind leads to is live, or "".
#           Placeholders: {distance} {percent} {punch} {plating} {hint}. Never the word
#           "optional": what a stage wants is the Warden, the rest lives in the notes.
# priority  0 ambient (music only), 1 feedback (sound and small VFX), 2 notable (toast),
#           3 critical (big toast, stinger on the beat).

# The natural event kinds whose swap overlay hides park_rows named by hide_on (natural.gd builds their swap entry, a
# cave_in entry is a roof that never reaches apply_swap; park_schema.gd reads this too).
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
	# Silent and unprinted: Moss's Warden line and the flume reveal card are the cue (flow.gd).
	"warden_sighted": {"group": "flow", "color": Palette.HAZARD, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"warden_engaged": {"group": "flow", "color": Palette.HAZARD, "shape": "cross", "sound": "warden_theme_in", "hud": "The Warden wakes", "objective": "", "priority": 2},
	"stage_content_cleared": {"group": "flow", "color": Palette.SAND, "shape": "none", "sound": "stage_fade", "hud": "", "objective": "", "priority": 0},
	"beacon_unsealed": {"group": "flow", "color": Palette.AMBER, "shape": "star", "sound": "stinger_unseal", "hud": "", "objective": "Charge the beacon", "priority": 3},
	"scrap_collected": {"group": "economy", "color": Palette.AMBER, "shape": "square", "sound": "scrap_tick", "hud": "", "objective": "", "priority": 1},
	"cogs_collected": {"group": "economy", "color": Palette.AMBER, "shape": "square", "sound": "cog_tick", "hud": "", "objective": "", "priority": 1},
	"part_gained": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "part_get", "hud": "+ {part}", "objective": "", "priority": 2},
	# Grey panels (build/panels.gd): worn bone, the common rung's colour; the ratchet tick under the pickup phrase.
	"panel_gained": {"group": "economy", "color": Palette.SAND, "shape": "square", "sound": "panel_ratchet", "hud": "", "objective": "", "priority": 1},
	"player_hit": {"group": "combat", "color": Palette.RUST, "shape": "burst", "sound": "hurt", "hud": "", "objective": "", "priority": 2},
	# The HUD pip and chirps read run.companion, not this signal, so the row stays quiet and listed in GRAMMAR_SIGNALS.
	"escape_window": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"player_died": {"group": "combat", "color": Palette.RUST, "shape": "cross", "sound": "death", "hud": "Scrapped", "objective": "", "priority": 3},
	"enemy_killed": {"group": "combat", "color": Palette.COPPER, "shape": "burst", "sound": "kill_pop", "hud": "", "objective": "", "priority": 1},
	"milestone_won": {"group": "event", "color": Palette.AMBER, "shape": "star", "sound": "stinger_milestone", "hud": "{event} won", "objective": "", "priority": 3},
	"heft_class_changed": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "class_up", "hud": "Heft {class}", "objective": "", "priority": 3},
	"heft_class_dropped": {"group": "economy", "color": Palette.RUST, "shape": "chevron", "sound": "class_down", "hud": "Heft {class}", "objective": "", "priority": 2},
	"scrap_lost": {"group": "economy", "color": Palette.RUST, "shape": "cross", "sound": "scrap_rip", "hud": "Chase your scrap", "objective": "", "priority": 2},
	"core_gained": {"group": "economy", "color": Palette.AMBER, "shape": "core", "sound": "core_socket", "hud": "Gates may offer rares", "objective": "", "priority": 3},
	"synergy_discovered": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "synergy_fanfare", "hud": "Synergy {name}", "objective": "", "priority": 3},
	"interaction_found": {"group": "event", "color": Palette.SANDSTONE, "shape": "diamond", "sound": "found_chime", "hud": "", "objective": "", "priority": 1},
	"jumped": {"group": "movement", "color": Palette.SAND, "shape": "chevron", "sound": "hop", "hud": "", "objective": "", "priority": 1},
	"boosted": {"group": "movement", "color": Palette.AMBER, "shape": "arrow", "sound": "boost_whoosh", "hud": "", "objective": "", "priority": 1},
	"dashed": {"group": "movement", "color": Palette.AMBER, "shape": "arrow", "sound": "dash_whoosh", "hud": "", "objective": "", "priority": 1},
	"landed": {"group": "movement", "color": Palette.SANDSTONE, "shape": "ring", "sound": "land_thud", "hud": "", "objective": "", "priority": 1},
	"slammed": {"group": "movement", "color": Palette.AMBER, "shape": "ring", "sound": "core_slam", "hud": "", "objective": "", "priority": 1},
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
	# Quiet: presentation drives the event's music from it and plays no cue, so the
	# sound id is only the schema's placeholder.
	"event_progress": {"group": "event", "color": Palette.VERDIGRIS, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"launched": {"group": "flow", "color": Palette.AMBER, "shape": "arrow", "sound": "launch_roar", "hud": "", "objective": "Hold your line", "priority": 3},
	"pressure_changed": {"group": "event", "color": Palette.RUST, "shape": "wave", "sound": "music_pressure", "hud": "", "objective": "", "priority": 0},
	"boss_arena_entered": {"group": "event", "color": Palette.BRASS, "shape": "star", "sound": "boss_arena_in", "hud": "Admiral Brindle", "objective": "Break Brindle's Requisition. Punch {punch} / hull plating {plating}.", "priority": 3},
	"boss_phase_changed": {"group": "event", "color": Palette.BRASS, "shape": "chevron", "sound": "boss_phase", "hud": "{name}", "objective": "", "priority": 3},
	"boss_attack_telegraphed": {"group": "combat", "color": Palette.BRASS, "shape": "wave", "sound": "boss_telegraph", "hud": "", "objective": "", "priority": 2},
	"fight_phase_changed": {"group": "event", "color": Palette.BRASS, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"attack_cued": {"group": "combat", "color": Palette.BRASS, "shape": "wave", "sound": "ratchet_cue", "hud": "", "objective": "", "priority": 2},
	"boss_weak_point_hit": {"group": "combat", "color": Palette.BRASS, "shape": "burst", "sound": "boss_weak_hit", "hud": "", "objective": "", "priority": 1},
	"boss_defeated": {"group": "flow", "color": Palette.BRASS, "shape": "star", "sound": "stinger_boss_defeated", "hud": "", "objective": "", "priority": 3},
	"threat_rose": {"group": "event", "color": Palette.RUST, "shape": "chevron", "sound": "threat_up", "hud": "Threat rising", "objective": "", "priority": 2},
	# v2 W3 characters. A class's own facts wear its colour and shape from class_def.gd;
	# shared facts (contact, gauge) wear neutral ones. `sound` is an existing synth id
	# standing in; `sound_next` names the SOUND-STORY section 3 cue W5 is to bake. The
	# motif_* cues resolve through the class row's motif id. Sable's two discharges
	# differ by ear: the gauge release is gauge_released (the motif resolved), the free
	# plant discharge rides mounted (the plant clack and the motif's first notes).
	"enemy_rebounded": {"group": "combat", "color": Palette.SAND, "shape": "chevron", "sound": "shell_spring", "sound_next": "rebound_spring_snap", "hud": "", "objective": "", "priority": 1},
	"enemy_pinned": {"group": "combat", "color": Palette.COPPER, "shape": "burst", "sound": "hit_thwack", "sound_next": "pin_double_thwack", "hud": "", "objective": "", "priority": 1},
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
	# v2 W7 enemies. Danger is HAZARD; a break, tenacity and the shield vault are yours,
	# so they wear bone here and the class colour where they draw (holds.gd). A hold's
	# loop and a pack's motif depend on who holds or arrives: `sound` is the stand-in and
	# `sound_next` names the SOUND-STORY section 3 cue, resolved through roster.gd's row
	# (`hold`) or faction (`arrival`). pack_arrived's `icon` is the Fleet's edge-marker
	# badge; an ancient pack shows its family's fac_ icon from the roster. Cherenkov
	# green (9dff3c, uranium glass) is the ancients' light, so a weak point opening is its seam.
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
	# The upgrade tree (upgrade_tree.gd): a pick is offered at class select and after
	# stages 1-3, and taken. A diamond, since a pick is growth you choose, in neutral bone
	# because every pilot picks (amber is Kest's and the relic rung); the pick UI tints it
	# with the class row. motif_fork is the class motif's first note answered by two
	# notes, one per branch; motif_pick resolves the chosen one onto the motif head. The
	# shop bell stays purchases only. The pick UI (W1) and the bay (W6) own the words.
	"tree_offered": {"group": "economy", "color": Palette.SAND, "shape": "diamond", "sound": "found_chime", "sound_next": "motif_fork", "hud": "", "objective": "", "priority": 1},
	"tree_picked": {"group": "economy", "color": Palette.SAND, "shape": "diamond", "sound": "part_get", "sound_next": "motif_pick", "hud": "", "objective": "", "priority": 1},
	# v2 W6 world. The bay banks speed like the pylon mount and the pad slingshots it
	# back, so entry and exit stand in with the plant and eject cues (SOUND-STORY
	# section 7, Moss's workshop). world_fact is quiet here: each kind's own row is in
	# WORLD_ROWS at the end of this file.
	"bay_entered": {"group": "flow", "color": Palette.SANDSTONE, "shape": "square", "sound": "pylon_plant", "sound_next": "bay_lounge_in", "hud": "Moss's workshop", "objective": "", "priority": 2},
	"bay_left": {"group": "flow", "color": Palette.SANDSTONE, "shape": "arrow", "sound": "pylon_eject", "sound_next": "bay_slingshot_out", "hud": "", "objective": "", "priority": 1},
	"world_fact": {"group": "event", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	# v3 W11 juice. A dodge: the ball stood in a committed threat while it warned and was
	# clear when it landed. Amber, because it is your own move, on the chevron of motion
	# past; a rising whoosh that ends on a bright fifth, never the danger family.
	"near_miss": {"group": "combat", "color": Palette.AMBER, "shape": "chevron", "sound": "near_whoosh", "hud": "", "objective": "", "priority": 1},
	# v3 interact. Each fact is heard and drawn in its family's register and colour
	# (world/interactables.gd FAMILIES); these rows are the schema's stand-ins. No toast:
	# the device, its dial and the core facts carry the result, inside the word budget.
	"interact_armed": {"group": "event", "color": Palette.AMBER, "shape": "ring", "sound": "ui_tick", "hud": "", "objective": "", "priority": 1},
	"interact_fired": {"group": "event", "color": Palette.AMBER, "shape": "burst", "sound": "found_chime", "hud": "", "objective": "", "priority": 1},
	"ambush_ended": {"group": "combat", "color": Palette.HAZARD, "shape": "cross", "sound": "event_end", "hud": "", "objective": "", "priority": 2},
	"bet_resolved": {"group": "economy", "color": Palette.COPPER, "shape": "star", "sound": "clank", "hud": "", "objective": "", "priority": 2},
	# A standing activity finished (world/activities.gd). The site's own ACTIVITY_ROWS row says
	# which shape and sound; this is the schema's stand-in. No toast: the pay appears at the spot.
	"activity_done": {"group": "event", "color": Palette.AMBER, "shape": "diamond", "sound": "found_chime", "hud": "", "objective": "", "priority": 1},
	# The legibility grammar's signals carry no presentation of their own: each reads its row in
	# LINE_ROWS, STATE_ROWS, Bindings.VERBS or CAUSE_ROWS, so these are the quiet stand-ins the
	# schema asks for.
	"line_state_changed": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"verb_failed": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	# The key-prompt rising edge the run log counts; the prompt has its own HUD motion, so the row is quiet (no listener, listed in GRAMMAR_SIGNALS).
	"prompt_shown": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"cause_armed": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"cause_fired": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"drop_landed": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"missed_drop": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"evolution_fired": {"group": "economy", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"posture_changed": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "drop_landing", "hud": "", "objective": "", "priority": 0},
	# The skill bar and the ultimate (design-v3/SKILL-BAR.md section 7). `sound` is a baked id
	# standing in; `sound_next` names the new cue the ultimate unit bakes. Live mint is "your
	# verb works now" (LEGIBILITY.md:23); a pick and a cast are neutral bone, since the bar
	# itself draws them. No toasts: the bar and the reticle carry every one.
	"slot_selected": {"group": "combat", "color": Palette.SAND, "shape": "square", "sound": "ui_tick", "hud": "", "objective": "", "priority": 1},
	"slot_cast": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"line_skill_loaded": {"group": "combat", "color": Palette.SAND, "shape": "ring", "sound": "lock_tick", "sound_next": "line_load", "hud": "", "objective": "", "priority": 1},
	"line_skill_fired": {"group": "combat", "color": Palette.SAND, "shape": "burst", "sound": "line_bite", "sound_next": "motif_line", "hud": "", "objective": "", "priority": 1},
	"line_skill_expired": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "dry_tick", "hud": "", "objective": "", "priority": 1},
	# The active on F. Its sound is the active's own (audio.gd, "active_" + id); this is the fallback.
	"active_fired": {"group": "combat", "color": Palette.AMBER, "shape": "burst", "sound": "active_scrap_rocket", "hud": "", "objective": "", "priority": 1},
	# The Cutting Torch's heat tick (cutting_torch.gd): audio.gd climbs its sizzle with the heat; it lands no hit.
	"active_heat": {"group": "combat", "color": Palette.AMBER, "shape": "burst", "sound": "active_cutting_torch_heat", "hud": "", "objective": "", "priority": 1},
	"ultimate_ready": {"group": "combat", "color": Palette.ARC, "shape": "ring", "sound": "found_chime", "sound_next": "ultimate_ready", "hud": "", "objective": "", "priority": 1},
	"ultimate_started": {"group": "combat", "color": Palette.ARC, "shape": "lane", "sound": "launch_roar", "hud": "", "objective": "", "priority": 1},
	"ultimate_peak": {"group": "combat", "color": Palette.ARC, "shape": "star", "sound": "special_fire", "sound_next": "motif_stinger", "hud": "", "objective": "", "priority": 1},
	"ultimate_landed": {"group": "combat", "color": Palette.AMBER, "shape": "burst", "sound": "ultimate_land", "hud": "", "objective": "", "priority": 1},
	"ultimate_cancelled": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "dry_tick", "hud": "", "objective": "", "priority": 1},
	# Achievement facts (w20): quiet stand-ins; the achievement toast is the player's cue, listed in GRAMMAR_SIGNALS.
	"special_broken": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"radio_take_found": {"group": "flow", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"relay_stake_paid": {"group": "event", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"maker_set_completed": {"group": "economy", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"overflow_cashed": {"group": "combat", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	# A trade taken: a quiet fact; the device's own cue and the caller's line (LoreRows.CALLS) are the player's.
	"trade_taken": {"group": "event", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
}

# The grammar's bus signals that have no presentation listener. A unit that wires a listener
# for one removes it from this list. The skill-bar signals wait for wave P-B's HUD and
# ultimate units (design-v3/SKILL-BAR.md section 10), which wire their listeners.
const GRAMMAR_SIGNALS := ["prompt_shown", "escape_window", "slot_selected", "slot_cast", "line_skill_expired",
	"special_broken", "radio_take_found", "relay_stake_paid", "maker_set_completed", "overflow_cashed", "trade_taken"]

# v3 W11 juice
# How hard a fact lands, keyed by the ROWS kind it dresses, so a fact's stop, shake,
# particles and streak window sit beside its colour, shape and sound. Milliseconds for
# times, particles per burst for counts. presentation (juice.gd, vfx.gd, audio.gd) reads
# these; the pause menu's Screen shake and Hit-stop rows scale every shake, kick, punch
# and stop here.
#   stop_ms, stop_per_damage, stop_min_ms, stop_cap_ms   hit-stop: base + per damage point,
#       clamped; crit multiplies, heavy (a ram, stomp or slam) adds
#   sparks, dust, pop, debris, fountain   particles in the burst
#   shake, kick, punch_fov   camera: shake amplitude, kick metres along travel, fov degrees
#   chain_ms, chain_cap   a streak: the window that keeps it alive and its top rung
#   pulse   the ball's squash for the fact (negative shrinks: a heft loss)
const JUICE := {
	"enemy_struck": {"stop_ms": 10.0, "stop_per_damage": 0.4, "stop_min_ms": 12.0, "stop_cap_ms": 40.0,
		"crit": {"stop_mult": 1.4, "shake": 0.22, "color": Palette.BRASS, "sound": "crit_ping",
			"fx": {"crit_core": 24, "crit_halo": 24}},
		"heavy": {"stop_add_ms": 10.0, "kick": 0.45, "dust": 12}, "fx": {"spark_core": 16, "spark_halo": 16}},
	"enemy_rebounded": {"kick": 0.55, "shake": 0.35, "dust": 14},
	"enemy_killed": {"pop": 14, "debris": 10, "chain_ms": 1500, "chain_cap": 7, "multi_ms": 90, "multi_stop_ms": 30.0, "pips": 8},
	# A scrap trail's pieces are 9.8 m apart (ruling cd), 700 ms at the 14 m/s cruise: the window holds the run down to
	# about 10 m/s, and a trail's rest (four empty beats, 2.8 s at cruise) still ends it.
	"scrap_collected": {"chain_ms": 1000, "chain_cap": 9, "pulse": 0.05, "pulse_cap": 0.16},
	# Recovered spill clusters arrive further apart than pickups, so the run's window is wider.
	"armor_reclaim": {"chain_ms": 900, "chain_cap": 7},
	"part_gained": {"fountain": 18, "element": {"frost": Palette.ANCIENT, "arc": Palette.ARC, "kinetic": Palette.SAND}},
	"core_gained": {"fountain": 24},
	# Your own shots and throws: a camera kick against the aim and a recoil squash on the
	# ball, per weapon; both are camera and shell only, never the ball's velocity.
	"shot_fired": {"weapons": {"rapid_laser": {"kick": 0.05, "recoil": 0.04}, "arc_caster": {"kick": 0.12, "recoil": 0.08},
			"pylon_turret": {"kick": 0.08, "recoil": 0.0}, "sticky_charge": {"kick": 0.16, "recoil": 0.12},
			"claw_sweep": {"kick": 0.14, "recoil": 0.10},
			# Tally's cards climb toward the cash-out; the cannon lane is the heaviest kick
			# (one shot a second). Both land after W16-1, so a kick never moves a shot.
			"gather_plate": {"kick": 0.06, "recoil": 0.04}, "link_clips": {"kick": 0.07, "recoil": 0.05},
			"balance_due": {"kick": 0.10, "recoil": 0.08}, "cannon_lane": {"kick": 0.2, "recoil": 0.14}},
		"throw": {"sound": "dash_whoosh", "pitch": 1.5, "db": -4.0}, "stick": {"sound": "grapple_clink", "pitch": 0.7}},
	# Kest's bomb: a flash, a shockwave ring and debris; the punch grows with each enemy the
	# blast catches. Inside near_m of the ball it kicks the camera and squashes the shell.
	"sticky_detonated": {"punch_fov": 3.0, "punch_per_enemy": 1.5, "punch_cap": 10.0, "debris": 12, "dust": 14, "shake": 0.35,
		"near_m": 6.0, "near_kick": 0.6},
	"rocket_jumped": {"kick": 0.8, "punch_fov": 8.0, "squash": 0.35},
	"near_miss": {"stop_ms": 45.0, "punch_fov": -5.0, "grace_ms": 250},
	"player_hit": {"edge_s": 0.4, "edge_alpha": 0.65, "squash": 0.18, "color": Palette.HAZARD},
	"scrap_lost": {"pulse": -0.22},
	"beacon_unsealed": {"stop_ms": 50.0, "punch_fov": 9.0},
	# W12 VX-FX: GPU effects (presentation/fx_library.gd SPECS). "fx" is {spec id: particles};
	# rolling plays continuously while the ball rolls at speed, its count per second. A
	# "low" sub-dict gives the low preset's counts; "motes" and "streaks" are [idle, occupied].
	"rolling": {"fx": {"roll_dust": 90}, "min_speed": 9.0},
	"slammed": {"fx": {"slam_ring": 48, "slam_dust": 24}},
	"harpoon_bit": {"fx": {"latch_ring": 24, "latch_halo": 24, "latch_pulse": 12}},
	"wall_crumbled": {"fx": {"crack_debris": 28, "slam_dust": 14}},
	"sticky_stuck": {"fx": {"spark_core": 8, "spark_halo": 8}},
	"breach_opened": {"fx": {"dig_debris": 10, "dig_dust": 12}, "low": {"dig_debris": 4, "dig_dust": 5}},
	"cache_spent": {"fx": {"cache_ember": 24, "cache_wisp": 6}},
	"net_caught": {"fx": {"net_dust": 14}},
	"thermal_ride": {"motes": [9, 27], "streaks": [6, 18]},
}
# What one hit of each kind does, in one place: the shove and lift combat gives the enemy,
# the stop and shake presentation gives the screen, and how the enemy should answer.
# Keyed by the strike kind combat passes to _hit and the contact kinds the player makes,
# plus the sources that share a kind with another hit but throw differently: burst (the
# pylon discharge), overdrive (the runner's blast, whose strike kind is the laser's),
# spill (the discharge's second jump) and proc (a blink cut).
#   knock   m/s before the enemy's weight divides it
#   lift    the upward share added to the shove's direction
#   stop    "none" (a gun: it never freezes time), "hit" (a bomb or blast), "heavy" (a ram,
#           stomp or slam: hit plus the heavy add, kick and dust of the enemy_struck row)
#   shake   camera shake for one hit; a crit raises it to the crit row's, never on "none"
#   react   "flinch", "stagger" or "launch": how the enemy should answer (data only)
# Damage taken has no row: it never shakes the camera (FEEL-READABILITY 3.1).
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
	# The Scrap Rocket Rack's blast (src/combat/actives/scrap_rockets.gd): a bomb's stop, a lighter shove.
	"rocket": {"knock": 14.0, "lift": 0.3, "stop": "hit", "shake": 0.08, "react": "stagger"},
	# The Glass Lance's pierce and its Chain Arc jumps (src/combat/actives/glass_lance.gd): a quick
	# cut's stop and stagger, so a jumped machine reads like the pierced one.
	"lance": {"knock": 8.0, "lift": 0.3, "stop": "hit", "shake": 0.1, "react": "stagger"},
}
# Degrees and seconds; enemy weight divides angles by sqrt(max(weight, 1)).
const REACTIONS := {
	"flinch": {"angle": 10.0, "rise": 0.03, "hold": 0.0, "recover": 0.09, "overshoot": 0.0, "tumble": 0.0, "limit": 0.15},
	"stagger": {"angle": 28.0, "rise": 0.05, "hold": 0.07, "recover": 0.24, "overshoot": 0.18, "tumble": 0.0, "limit": 0.45},
	"launch": {"angle": 65.0, "rise": 0.05, "hold": 0.0, "recover": 0.18, "overshoot": 0.0, "tumble": 220.0, "limit": 0.9},
}
const IMPACT_STOPS := ["none", "hit", "heavy"]
const IMPACT_REACTS := ["flinch", "stagger", "launch"]
# A strike kind with no row (a shell, a ring, a boss's own) lands as a plain hit.
const IMPACT_FALLBACK := {"knock": 0.0, "lift": 0.0, "stop": "hit", "shake": 0.1, "react": "flinch"}

# Rapid fire never stutters. Every stop, whatever asked for it, draws on one shared
# budget: a stop starts at least STOP_GAP_MS after the last one ended, at most
# STOP_WINDOW_BUDGET_MS of stop falls in any STOP_WINDOW_MS, and at most STOP_BUDGET_MS in
# any second. The hits of one frame coalesce into one stop.
const STOP_GAP_MS := 90
const STOP_WINDOW_MS := 300
const STOP_WINDOW_BUDGET_MS := 60.0
const STOP_BUDGET_MS := 100.0
const STOP_PER_EXTRA_HIT_MS := 2.0

# One weight record feeds impact visuals, camera and sound. Stop words delegate to
# Juice.stop_ms_for; body pitch changes register and length, never loudness.
const WEIGHT := {
	"none": {"stop_ms": 0.0, "shake": 0.0, "kick": 0.0, "punch_fov": 0.0, "fx_scale": 0.8, "body": "", "body_st": 0.0},
	"hit": {"stop_ms": "hit", "shake": 0.1, "kick": 0.1, "punch_fov": 0.0, "fx_scale": 1.0, "body": "", "body_st": 0.0},
	"heavy": {"stop_ms": "heavy", "shake": 0.3, "kick": 0.45, "punch_fov": -4.0, "fx_scale": 1.4, "body": "womp", "body_st": 0.0},
	"massive": {"stop_ms": 55.0, "shake": 0.4, "kick": 0.6, "punch_fov": -6.0, "fx_scale": 1.9, "body": "chunk_low", "body_st": -12.0},
	"climax": {"stop_ms": 60.0, "shake": 0.5, "kick": 0.6, "punch_fov": 9.0, "fx_scale": 2.5, "body": "chunk_low", "body_st": -17.0},
}

# Empty visual uses ROWS or the fact's FxLibrary effects. The posture sub-fact uses
# an existing spark spec. Sound always resolves through Rows.sound.
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


# args are values, not actors: kind, damage/force, crit, fraction, amount,
# staggered, chunks_lost and optional strength. The caller detects posture edges.
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

# v2 W2 threat grammar
# One row per enemy attack type (combat/threat_grammar.gd), in the ROWS schema. They sit
# outside ROWS because ROWS is keyed by bus signal and a threat is a committed telegraph,
# not a signal. Presentation can give each type its own warning by playing `sound` when
# a node in the group "threat" enters the tree.
const THREAT_ROWS := {
	"threat_instant": {"group": "combat", "color": Palette.HAZARD, "shape": "ring", "sound": "threat_tick", "hud": "", "objective": "", "priority": 2},
	"threat_wave": {"group": "combat", "color": Palette.HAZARD, "shape": "wave", "sound": "threat_whoosh", "hud": "", "objective": "", "priority": 2},
	"threat_projectile": {"group": "combat", "color": Palette.HAZARD, "shape": "cross", "sound": "threat_whistle", "hud": "", "objective": "", "priority": 2},
	"threat_lane": {"group": "combat", "color": Palette.HAZARD, "shape": "bar", "sound": "threat_hum", "hud": "", "objective": "", "priority": 2},
}

# v3 attack reads, prerequisite A (design-v3/research/attack-reads/ATTACK-READS.md)
# One row per attack ID in that document (E enemy, W Warden, B Brindle, P pilot), so the
# body pose, the sounds, the codex and the floor support of an attack read one fact. The
# rows are a frozen contract: nothing consumes them yet, and an actor reads its row
# instead of carrying its own colour, cue or label.
#
# label      the codex wording, not floating combat text.
# threat     the THREAT_ROWS key the attack's committed telegraph uses, or "" when it has
#            none (player attacks, a non-damaging read, a crater with no advance warning).
#            A key, not Threat.Type, because roster.gd loads the threat grammar.
# glyph      a SHAPES entry. A pilot's own attacks wear their class shape (ClassDef).
# color      the allegiance colour: HAZARD for hostile, the class colour for a pilot's own
#            (ClassDef), a palette colour for a neutral read (harmless lift is bone).
# pose       the presentation key for the attacker's body. It picks a pose, never a timer.
# warn       the cue id at wind-up start; release: the cue id on the live transition. Ids
#            are reserved names Audio bakes later, "atk_<id>_warn" and "atk_<id>_release";
#            NONE where the document gives that beat no cue.
# floor      L thin boundary, H haze, B both, none no floor marking.
# group      enemy | warden | brindle | pilot. owner_kind and owner name the voice by
#            reference: a roster id (Roster.ROWS), a faction (Roster.FACTIONS), the boss,
#            or a class id (ClassDef) or "any" for an all-pilot row. No palette or motif
#            is copied here. allegiance: hostile | player | neutral.
# open       the fields still holding a stand-in the document leaves undecided. A field
#            equal to PLACEHOLDER is always listed; a concrete stand-in may be too.
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
	# The declared world 2 and 3 kinds (roster_dig.gd, roster_highdraft.gd): pose and floor
	# stay open until each kind's script lands. The Dig's floor threats (E19, E20, E30) have.
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
	# Kill-first specials (roster_specials.gd). E25's pose is the pod's seam glow blinking
	# faster as the fuse burns (splitter_pod.gd _pose); its ring marks the floor both ways.
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
	# Rogue fleet mini-bosses (combat/rogue.gd, Q-P25): owned by the rogue rows, not the roster.
	# Each pose is the machine's own bone work in rogue.gd _pose_model (WIRE-OR-CUT).
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

# Codex categories: each has its own colour, glyph shape and label, so the Tab codex
# pages, a discovery banner and a found-list line all dress a category the same way.
# npc and coop are reserved: the demo is solo, but the schema already carries them.
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


# Wording with its placeholders filled; unknown placeholders are left visible so a
# missing field shows up in play instead of silently vanishing.
static func hud(kind: String, fields := {}) -> String:
	return String(row(kind).get("hud", "")).format(fields)


static func objective(kind: String, fields := {}) -> String:
	return String(row(kind).get("objective", "")).format(fields)


static func category(id: String) -> Dictionary:
	return CODEX_CATEGORIES.get(id, CODEX_CATEGORIES["build"])


# v3 attack reads accessors: read a row by attack ID; an unknown ID reads as empty.
static func has_attack(id: String) -> bool:
	return ATTACK_ROWS.has(id)


static func attack_row(id: String) -> Dictionary:
	return ATTACK_ROWS.get(id, {})


# Attack IDs in document order, optionally only one group.
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


# The fields of a row still on a stand-in value.
static func attack_open(id: String) -> Array:
	return attack_row(id).get("open", [])


# The legibility grammar (design-v3/LEGIBILITY.md). Four tables, each id presented in exactly
# one of them; a test fails when an id shows up in two. A colour is a role name, never a
# Color, and role_color is the one place a role becomes one.
#
# color     hazard | live | amber | slate | rust, the colour law's five meanings, or neutral
#           for ink that carries none (COLOR_ROLES).
# motion    pulse | steady | none (MOTIONS). A lock pulses and a latch is steady on purpose.
# shape     a SHAPES entry.
# sound     the cue id, or "none". Ids a later unit bakes are reserved names.
# verb      the Bindings.VERBS id whose prompt rides this state, or "none".
# word      the first-times wording, three words or fewer, or "".
const COLOR_ROLES := ["hazard", "live", "amber", "slate", "rust", "neutral"]
const MOTIONS := ["pulse", "steady", "none"]
const MAX_WORDS := 3
const STATE_FIELDS := ["color", "motion", "shape", "sound", "verb", "word"]
const LINE_FIELDS := STATE_FIELDS

# Each harpoon state of LEGIBILITY section 3.
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
	# The harpoon chain (HOOK-CHAIN.md), published by the player from its ChainState.
	"chain_link": {"color": "live", "motion": "none", "shape": "diamond", "sound": "line_bite", "verb": NONE, "word": ""},
	"chain_pivot": {"color": "live", "motion": "none", "shape": "square", "sound": NONE, "verb": NONE, "word": ""},
	"chain_end": {"color": "slate", "motion": "none", "shape": "chevron", "sound": "line_zip", "verb": NONE, "word": ""},
	"chain_miss": {"color": "slate", "motion": "none", "shape": "bar", "sound": "dry_tick", "verb": NONE, "word": ""},
}
# Bus signals whose presentation is a LINE_ROWS state; row() and has() answer for them.
const LINE_SIGNALS := {"harpoon_bit": "latched_body", "harpoon_smashed": "smash_lands"}
const LINE_SIGNAL_GROUP := "movement"
const LINE_SIGNAL_PRIORITY := 1

# Target and ball states of LEGIBILITY section 2, and the Warden's posture facts of section 4:
# a step of its guard, the open core a stagger leaves, a health chunk shattering. No amber on
# the Warden, and the live colour only while it is open.
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
	"beacon_open": {"color": "amber", "motion": "steady", "shape": "ring", "sound": NONE, "verb": NONE, "word": ""},
	"wearing": {"color": "rust", "motion": "steady", "shape": "chevron", "sound": NONE, "verb": NONE, "word": ""},
	# Damage families (FIELDS-AND-CASTS section 6): the first resisted and weak hit on an armour
	# class each run stamp their word; once its codex entry is known the class wears its icon.
	"dented": {"color": "slate", "motion": "none", "shape": "square", "sound": NONE, "verb": NONE, "word": "DENT"},
	"zzapped": {"color": "live", "motion": "none", "shape": "cross", "sound": NONE, "verb": NONE, "word": "ZZAP!"},
	"plated": {"color": "slate", "motion": "steady", "shape": "square", "sound": NONE, "verb": NONE, "word": ""},
}

# The five synergies the slice keeps, keyed by their ids in build/synergies.gd, which owns the
# names. Presentation only: each has its own shape and a three-note motif as note names.
const CAUSE_FIELDS := ["color", "shape", "motif"]
const CAUSE_ROWS := {
	"wrecking_ball": {"color": "amber", "shape": "ring", "motif": ["C3", "G3", "C4"]},
	"tesla_pylon": {"color": "amber", "shape": "cross", "motif": ["D4", "A4", "F4"]},
	"pinwheel": {"color": "amber", "shape": "star", "motif": ["E4", "G4", "B4"]},
	"shrapnel_bloom": {"color": "amber", "shape": "burst", "motif": ["A3", "E4", "A4"]},
	"lightning_rod": {"color": "amber", "shape": "arrow", "motif": ["G4", "D5", "B4"]},
}

# The cause glyph of each synergy tag (LEGIBILITY section 5, Callout), one vocabulary for the
# callout's two ingredients and the link at the ball. arc and kinetic wear the element icons'
# bolt and disc (icons.gd). No tag glyph equals an effect shape in CAUSE_ROWS. Frost is not on
# the slice and its element icon is a burst, an effect shape, so it borrows the diamond until
# frost returns and is owed a glyph of its own.
const TAG_GLYPHS := {
	"arc": "bolt", "kinetic": "disc", "mass": "core", "anchor": "bar", "speed": "chevron",
	"spiral": "wave", "split": "diamond", "chain": "square", "frost": "diamond",
}

# The four standing activities (LEGIBILITY section 9, wave R3): an amber beam and ring from stage
# start with the family glyph on top. No timer and no toast.
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


# A LINE_ROWS row in the ROWS schema, for a bus signal whose presentation lives there.
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


# The glyphs of a synergy's tags in order; empty when any tag has none.
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


# v2 W1 UI
# Facts the HUD shows that no bus signal carries: ability slot states, key glyphs, the
# run clock and the first-run callouts. Same fields as ROWS, so colour, shape, sound and
# wording still come from one place; they live apart from ROWS because ROWS holds one
# row per bus signal. Sounds are ids for presentation to bake. A slot's state reads by
# shape first (frame weight, wedge, doubled frame, strike); active wears the class
# colour, since class colour means yours. "class_motif" is not a synth id: it names the
# class row's ready pulse (<motif>_ready, resolved in rows.gd), so the ready swell plays
# the class's tune (SOUND-STORY section 7, W1).
const UI_ROWS := {
	# A presentation sub-fact of posture_changed, not another bus signal.
	"posture_break": {"group": "combat", "color": Palette.SAND, "shape": "burst", "sound": "drop_landing", "hud": "", "objective": "", "priority": 1},
	"ability_ready": {"group": "combat", "color": Palette.SAND, "shape": "ring", "sound": "class_motif", "hud": "", "objective": "", "priority": 1},
	"ability_cooling": {"group": "combat", "color": Palette.VERDIGRIS, "shape": "ring", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"ability_active": {"group": "combat", "color": Palette.SAND, "shape": "star", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"ability_unavailable": {"group": "combat", "color": Palette.SANDSTONE, "shape": "cross", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	# SQ6: a hit landed or taken moved the mobility chip's cooldown along (ability_state
	# combat_refund, read through drain_refunds). The chip flashes once per record; the chevron
	# says the wedge jumped forward.
	"cooldown_refunded": {"group": "combat", "color": Palette.SAND, "shape": "chevron", "sound": "ui_tick", "hud": "", "objective": "", "priority": 1},
	"key_glyph": {"group": "flow", "color": Palette.SAND, "shape": "square", "sound": "ui_tick", "hud": "", "objective": "", "priority": 1},
	"run_timer": {"group": "flow", "color": Palette.SAND, "shape": "ring", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"callout_scrap": {"group": "economy", "color": Palette.AMBER, "shape": "square", "sound": "callout_chime", "hud": "Scrap = heft", "objective": "", "priority": 2},
	"callout_warden": {"group": "flow", "color": Palette.HAZARD, "shape": "cross", "sound": "callout_chime", "hud": "Break it", "objective": "", "priority": 2},
	"callout_gates": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "callout_chime", "hud": "Roll through", "objective": "", "priority": 2},
	"callout_notes": {"group": "flow", "color": Palette.SAND, "shape": "square", "sound": "callout_chime", "hud": "Hold {key_tab} for notes", "objective": "", "priority": 2},
	# A fight's own hint, toasted whenever its boss module asks (hud.gd _step_fight_hint). Brindle's
	# Scuttle asks while a build too light to hit its way in has not yet stunned him.
	"hint_wall_bait": {"group": "flow", "color": Palette.BRASS, "shape": "chevron", "sound": "callout_chime", "hud": "Make him hit walls", "objective": "", "priority": 3},
	# The SPIL-9 escape charge as the HUD pip reads it from run.companion: a lit diamond
	# when armed, an empty ring when spent.
	"companion_ready": {"group": "combat", "color": Palette.VERDIGRIS, "shape": "diamond", "sound": "companion_chirp_ready", "hud": "", "objective": "", "priority": 1},
	"companion_spent": {"group": "combat", "color": Palette.SANDSTONE, "shape": "ring", "sound": "companion_chirp_spent", "hud": "", "objective": "", "priority": 1},
	# The escape piece acting (combat.gd escape_acted): the body's flare or rail flick and its
	# chirp read this row. Companion verdigris, an outward arrow; the rising ready pair stands in
	# until companion_chirp_escape is baked.
	"escape_acted": {"group": "combat", "color": Palette.VERDIGRIS, "shape": "arrow", "sound": "companion_chirp_ready", "sound_next": "companion_chirp_escape", "hud": "", "objective": "", "priority": 1},
}

# v2 W7 enemies
# Each faction's fac_ icon, so the pack_arrived edge marker and any faction badge read
# one table: the Fleet's requisition tag, or the ancient family's own mark.
const FACTION_ICONS := {"fleet": "fac_fleet", "reactor": "fac_reactor", "swarm": "fac_swarm", "mind": "fac_mind"}


static func faction_icon(faction: String) -> String:
	return FACTION_ICONS.get(faction, "fac_fleet")


# v2 W4 loot
# Facts from Moss's shop and the item triggers that are not bus signals: build publishes
# them in its shop results and item_procs(), and W1, W5 and W6 read their look and sound
# here, in the ROWS schema. They sit outside ROWS for the same reason as UI_ROWS: ROWS is
# one row per bus signal, and a new signal would need presentation wiring this unit does
# not own. `sound` is an existing synth id standing in; `sound_next` names the cue W5 is
# to bake (DESIGN-V2 section 12: a workbench clank, a shop bell, a grumble when he
# refuses). Entering and leaving the bay reuse the mount and slingshot cues (SOUND-STORY
# section 7), because the bay banks speed like a pylon. A refusal is one dry
# interruption, never a damage alarm, so it is bone, not rust.
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
	# v3 W13 reward ceremony. How a part find is presented, one row per tier, read by
	# presentation/reward_ceremony.gd; the tier comes from REWARD_TIER_BY_RARITY and the
	# find's context. A tier's colour is its ring and card edge before the rarity tints
	# it; `pause` is never (in the flow) or calm (only when nothing hostile is near).
	# Times in seconds. The payoff is the one-time accent the first time a revealed or
	# ceremonial part's effect fires, ringing the same rarity bell it arrived with.
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
	# The durability prototype (--scrap=armor), facts that are not bus signals: run_state's
	# armor_hit and the scrap field's recovered. The shed is the same amber as the HUD's
	# armour flash (hud.gd), so the plate that flashes is the plate that clatters; it is
	# priority 1 (no music duck, no bass duck) because a hit the scrap absorbed is not a
	# hull hit. `sound` is the mid clatter; audio picks a small or big one by the scrap
	# removed. The reclaim is scrap's own mint square, a rising two-note chime.
	"armor_hit": {"group": "combat", "color": Palette.AMBER, "shape": "burst", "sound": "armor_shed", "hud": "", "objective": "", "priority": 1},
	"armor_reclaim": {"group": "economy", "color": Palette.AMBER, "shape": "square", "sound": "armor_reclaim", "hud": "", "objective": "", "priority": 1},
	# A hit turned aside entirely (mitigation or a deflect item: no scrap, no hull). Steel
	# sand, a small square: quieter and plainer than the amber shed. Audio's own fact.
	"armor_deflect": {"group": "combat", "color": Palette.SAND, "shape": "square", "sound": "armor_deflect", "hud": "", "objective": "", "priority": 1},
}

# v3 W13 reward ceremony. The ladder: the tier a rarity is presented at before the
# find's context raises it (a first find or a completed synergy raises common and rare
# to the reveal card). Evolution is the ladder's top rung, a ceremony wherever it drops.
const REWARD_TIERS := ["common", "rare", "reveal", "ceremony"]
const REWARD_TIER_BY_RARITY := {"common": "common", "rare": "rare", "relic": "reveal", "evolved": "ceremony", "evolution": "ceremony"}
# part_gained sources that are a ceremony whatever the rarity: the gate the Warden's break
# opens, Brindle's crest, a vault, and the cracked-wall cache, the cage on the mast and
# evolution rewards once their sources publish.
const CEREMONY_SOURCES := ["gate", "boss", "vault", "cache", "cage", "warden", "evolution"]
# Each rarity's bell on the reward ladder (Harmony.pentatonic_step), so a rarer find rings higher.
const REWARD_RUNGS := {"common": 0, "rare": 4, "relic": 5, "evolved": 7, "evolution": 7}
# A rung's own voice, played under its bell on every find of that rung (the item ladder's
# sound per rung). Cobalt is a coil whine and click; the other rungs keep their bell alone.
const REWARD_RUNG_CUES := {"rare": "rung_coil"}


static func reward_row(tier: String) -> Dictionary:
	return LOOT_ROWS.get("reward_" + tier, {})


# v2 W6 world
# One row per world_fact kind, in the ROWS schema. `sound` is an existing synth id
# standing in; `sound_next` names the SOUND-STORY section 3 cue W5 is to bake. Colour
# follows VISUAL-LANGUAGE section 11: contraptions read by their bone gauge (SAND), a
# terrain change by the hostile telegraph family (HAZARD) until it lands, the gorge's
# layers and rides by the world's own sandstone, the landmark by the ancients' blue.
# Rising and breathy means a ride; falling and pure means incoming: the launchers'
# charge whistle rises, the impact's falls (SOUND-STORY section 7, W6 must).
const ANCIENT_LIGHT := Palette.ANCIENT
const WORLD_ROWS := {
	# PARK section 5: hostile warnings fall with a pure tone; landed forms keep
	# the same family's colour. Priority is consumed by the existing audio grammar.
	"ground_slump": {"group": "event", "color": Palette.HAZARD, "shape": "bar", "pattern": "dust_crack", "dust_height_m": 3.0, "crack_width_m": 0.3, "sound": "threat_tick", "sound_next": "rock_grind_dust_hiss", "hud": "", "objective": "", "priority": 2},
	"ground_slump_landed": {"group": "event", "color": Palette.HAZARD, "shape": "bar", "pattern": "dust_crack", "dust_height_m": 3.0, "crack_width_m": 0.3, "sound": "slam_boom", "sound_next": "rockfall_boom", "hud": "", "objective": "", "priority": 2},
	"flood_rising": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "threat_whistle", "sound_next": "flood_falling_pure", "hud": "", "objective": "", "priority": 2},
	"flood_landed": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "slam_boom", "sound_next": "flood_drop", "hud": "", "objective": "", "priority": 2},
	"fleet_inbound": {"group": "event", "color": Palette.HAZARD, "shape": "cross", "sound": "threat_whistle", "sound_next": "fleet_falling_pure", "hud": "", "objective": "", "priority": 2},
	"fleet_landed": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "slam_boom", "sound_next": "fleet_anvil_brass_drop", "hud": "", "objective": "", "priority": 2},
	# The Dig's lift cage climbs its shaft (a lift's clank under the tick); the Highdraft's zipline
	# trolley falls down its cable with the Fleet's pure whistle. World-native sounds are requested.
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
	# KE-FORMS: authored park telegraph forms with no record (PARK section 5). Hostile warnings fall with a pure
	# tone and take the hazard colour; the drain opens a route, so it is a ride in sandstone with a rising breath.
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
	# The flume's head gate (the surge course, activities.gd): the sluice siren winds up on the bar, then the gate
	# opens and the water comes. It chases you but never hurts you, so it rises in water verdigris on the chevron of
	# motion, never the hazard family; the landed gush is a whoosh, the tailwind you are about to ride.
	"sluice_siren": {"group": "event", "color": Palette.VERDIGRIS, "shape": "chevron", "sound": "beacon_hum", "sound_next": "sluice_siren_two_tone", "hud": "", "objective": "", "priority": 2},
	"sluice_landed": {"group": "event", "color": Palette.VERDIGRIS, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "sluice_gush_roar", "hud": "", "objective": "", "priority": 2},
	# The shell's resolved air factor moved (Build.shell_air_changed): one fact for S4, K5 and R6. The ring on the
	# hero pod, its colour and the released-spring sound read this row; direction is the ring's motion and the pitch.
	"shell_air_shift": {"group": "movement", "color": Palette.AMBER, "shape": "ring", "sound": "shell_spring", "hud": "", "objective": "", "priority": 1},
	"lift_fired": {"group": "event", "color": Palette.SAND, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "lift_chuff_clank", "hud": "", "objective": "", "priority": 1},
	"launcher_charging": {"group": "event", "color": Palette.SAND, "shape": "ring", "sound": "beacon_hum", "sound_next": "steam_whistle_rise", "hud": "", "objective": "", "priority": 0},
	"cannon_fired": {"group": "event", "color": Palette.SAND, "shape": "arrow", "sound": "launch_roar", "sound_next": "cannon_bang_rail_whoosh", "hud": "", "objective": "", "priority": 1},
	"trebuchet_fired": {"group": "event", "color": Palette.SAND, "shape": "arrow", "sound": "launch_roar", "sound_next": "trebuchet_creak_whoosh", "hud": "", "objective": "", "priority": 1},
	# The sinkhole's floor is lava (cinder_heat.gd): the cinders glow as the grace runs out, sizzle while they burn, and
	# hiss as a hot ball leaves them.
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
	# The crown's place layers (design-v3/park/stages/6-park_crown.md section 12), published by a park row's music_layer.
	# Stand-in tick until the music thread renders each layer.
	"layer_crown_hoodoos": {"group": "event", "color": Palette.SANDSTONE, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_crown_hoodoos", "hud": "", "objective": "", "priority": 0},
	"layer_crown_alcove": {"group": "event", "color": Palette.SANDSTONE, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_crown_alcove", "hud": "", "objective": "", "priority": 0},
	"layer_crown_toppled": {"group": "event", "color": Palette.SANDSTONE, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_crown_toppled", "hud": "", "objective": "", "priority": 0},
	"layer_crown_ramp": {"group": "event", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_crown_ramp", "hud": "", "objective": "", "priority": 0},
	# The Mind's first musical quote (Andrew's Q9, "A musical quote"): the dam's eye_mouth row publishes it as its ride
	# fact as the ball leaves the Eye, which every line crosses once and downhill; its file renders on the music PR (#12),
	# and until then ui_tick stands in.
	"layer_mind_quote_spillway": {"group": "event", "color": ANCIENT_LIGHT, "shape": "none", "sound": "ui_tick", "sound_next": "music_layer_mind_quote_spillway", "hud": "", "objective": "", "priority": 0},
	"ride_grapple_line": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "grapple_clink", "sound_next": "ride_cable_clink", "hud": "", "objective": "", "priority": 1},
	"ride_glide_drop": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "dash_whoosh", "sound_next": "ride_glide_wind", "hud": "", "objective": "", "priority": 1},
	"ride_skylight": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "ride_rail_hum", "hud": "", "objective": "", "priority": 1},
	"ride_chute": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "ride_rolling_metal", "hud": "", "objective": "", "priority": 1},
	# w13 KC0: the park's ride facts (design-v3/PARK.md section 4), published by park_recipes.gd's ride sensor. Rides,
	# so rising and breathy; the shape is the piece: a bowl's ring, a drop's arrow, a ledge's bar, a hop's chevron.
	"ride_bowl": {"group": "event", "color": Palette.SANDSTONE, "shape": "ring", "sound": "boost_whoosh", "sound_next": "ride_bowl_carve", "hud": "", "objective": "", "priority": 1},
	"ride_drop": {"group": "event", "color": Palette.SANDSTONE, "shape": "arrow", "sound": "dash_whoosh", "sound_next": "ride_drop_swoop", "hud": "", "objective": "", "priority": 1},
	"ride_ledge": {"group": "event", "color": Palette.SANDSTONE, "shape": "bar", "sound": "boost_whoosh", "sound_next": "ride_ledge_scuff", "hud": "", "objective": "", "priority": 1},
	"ride_hop": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "dash_whoosh", "sound_next": "ride_hop_lift", "hud": "", "objective": "", "priority": 1},
	# w13 KF2: the dam face's spillway sheet (design-v3/wardens/reactor.md section 3.1), published by warden_reactor.gd
	# when a ball starts riding it. The chute's chevron (a road up), and the sheet's white-noise swell (section 6).
	"ride_sheet": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "ride_sheet_swell", "hud": "", "objective": "", "priority": 1},
	# w13 KF3: the swarm Warden's mountings (design-v3/wardens/swarm.md section 3), published by
	# warden_swarm.gd. hoist_ride: a ball rode the headframe hoist's rise and the stop threw it, a
	# lift like ride_hop's chevron, the winch whine tuned to G (section 6). pool_swell: the sinkhole
	# pool's 2 s swell before its floor rises a step, a wave, a pitchless low water swell.
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
	# v3 fun lab: the Spillway loop's return (map_spillway.gd), a ride, so rising and
	# breathy like the geyser; the launch arpeggio is the cue to bake.
	"steam_lift_fired": {"group": "event", "color": Palette.SAND, "shape": "arrow", "sound": "launch_roar", "sound_next": "return_launch_arpeggio", "hud": "", "objective": "", "priority": 1},
	# Alpha wave 10: a Dig breach plate broken by a slam (world.gd _on_slammed, breach.gd ROW).
	"breach_opened": {"group": "event", "color": Palette.HAZARD, "shape": "burst", "sound": "breach_crack", "sound_next": "plate_crack_rubble_fall", "hud": "", "objective": "", "priority": 1},
	# Alpha wave 14: Moss takes a ledger leaf (progress.gd return_leaves).
	"ledger_returned": {"group": "event", "color": Palette.SAND, "shape": "star", "sound": "found_chime", "hud": "", "objective": "", "priority": 1},
	# The Spillway's arena locks and Warden gates (src/world/stage_locks.gd, lock_rows.gd). Sound is the fairness
	# channel: the yard shutting falls (hazard), opening climbs; the clamp counts a crew with a ping, answers a hit
	# while gated with a dull clank that never sounds like progress, and lets go on a chord.
	"arena_locked": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "slam_boom", "sound_next": "arena_lock_slam", "hud": "", "objective": "", "priority": 2},
	"arena_wave": {"group": "event", "color": Palette.HAZARD, "shape": "cross", "sound": "threat_whistle", "sound_next": "arena_wave_whistle", "hud": "", "objective": "", "priority": 2},
	"arena_unlocked": {"group": "event", "color": Palette.SANDSTONE, "shape": "ring", "sound": "found_chime", "sound_next": "arena_unlock_bells", "hud": "", "objective": "", "priority": 2},
	"warden_gate_pip": {"group": "event", "color": Palette.BRASS, "shape": "square", "sound": "found_chime", "sound_next": "warden_gate_pip", "hud": "", "objective": "", "priority": 1},
	"warden_gate_refused": {"group": "event", "color": Palette.HAZARD, "shape": "square", "sound": "clank", "sound_next": "warden_gate_clunk", "hud": "", "objective": "", "priority": 1},
	"warden_gate_opened": {"group": "event", "color": Palette.BRASS, "shape": "burst", "sound": "found_chime", "sound_next": "warden_gate_release", "hud": "", "objective": "", "priority": 2},
	# Reservoir (src/world/overtime.gd, docs/design/loops.md Spec 2): a won yard lights a keeper's bell; a
	# ring calls overtime (its crew lands on arena_wave's whistle); the pot pays on the till; the sluice
	# warns on the whistle for its whole lead, then the water comes down with the lock's slam.
	"overtime_offered": {"group": "event", "color": Palette.BRASS, "shape": "ring", "sound": "found_chime", "sound_next": "warden_gate_pip", "hud": "", "objective": "", "priority": 1},
	"overtime_rung": {"group": "event", "color": Palette.BRASS, "shape": "burst", "sound": "found_chime", "sound_next": "arena_unlock_bells", "hud": "", "objective": "", "priority": 2},
	"overtime_paid": {"group": "event", "color": Palette.BRASS, "shape": "star", "sound": "found_chime", "sound_next": "warden_gate_release", "hud": "", "objective": "", "priority": 2},
	"sluice_warning": {"group": "event", "color": Palette.HAZARD, "shape": "arrow", "sound": "threat_whistle", "sound_next": "arena_wave_whistle", "hud": "", "objective": "", "priority": 2},
	"sluice_open": {"group": "event", "color": Palette.HAZARD, "shape": "ring", "sound": "slam_boom", "sound_next": "arena_lock_slam", "hud": "", "objective": "", "priority": 2},
}


static func world_row(kind: String) -> Dictionary:
	return WORLD_ROWS.get(kind, {})
