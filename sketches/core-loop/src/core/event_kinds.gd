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

const GROUPS := ["movement", "combat", "economy", "flow", "event"]
const SHAPES := ["ring", "diamond", "square", "chevron", "arrow", "burst", "bar", "star", "cross", "wave", "core", "none"]
const FIELDS := ["group", "color", "shape", "sound", "hud", "objective", "priority"]
const TOAST_PRIORITY := 2

const ROWS := {
	"run_started": {"group": "flow", "color": Palette.SAND, "shape": "star", "sound": "stinger_run", "hud": "Run started", "objective": "", "priority": 3},
	"flow_changed": {"group": "flow", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"stage_entered": {"group": "flow", "color": Palette.SAND, "shape": "chevron", "sound": "stinger_stage", "hud": "Stage {stage}", "objective": "Break the Warden at the beacon ({distance} m). Punch {punch} / plating {plating}. {hint}", "priority": 3},
	"stage_cleared": {"group": "flow", "color": Palette.ARC, "shape": "star", "sound": "stinger_clear", "hud": "Stage {stage} clear", "objective": "", "priority": 3},
	"run_ended": {"group": "flow", "color": Palette.ARC, "shape": "star", "sound": "stinger_run_end", "hud": "Run complete", "objective": "", "priority": 3},
	"beacon_charge_changed": {"group": "flow", "color": Palette.ARC, "shape": "ring", "sound": "beacon_hum", "hud": "", "objective": "Warden {percent}% broken. Punch {punch} / plating {plating}. {hint}", "priority": 1},
	"warden_engaged": {"group": "flow", "color": Palette.HAZARD, "shape": "cross", "sound": "warden_theme_in", "hud": "The Warden wakes", "objective": "", "priority": 2},
	"stage_content_cleared": {"group": "flow", "color": Palette.SAND, "shape": "none", "sound": "stage_fade", "hud": "", "objective": "", "priority": 0},
	"beacon_unsealed": {"group": "flow", "color": Palette.ARC, "shape": "star", "sound": "stinger_unseal", "hud": "Warden broken: gates open", "objective": "Charge the beacon", "priority": 3},
	"scrap_collected": {"group": "economy", "color": Palette.ARC, "shape": "square", "sound": "scrap_tick", "hud": "", "objective": "", "priority": 1},
	"part_gained": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "part_get", "hud": "+ {part}", "objective": "", "priority": 2},
	"player_hit": {"group": "combat", "color": Palette.RUST, "shape": "burst", "sound": "hurt", "hud": "", "objective": "", "priority": 2},
	"player_died": {"group": "combat", "color": Palette.RUST, "shape": "cross", "sound": "death", "hud": "Scrapped", "objective": "", "priority": 3},
	"enemy_killed": {"group": "combat", "color": Palette.COPPER, "shape": "burst", "sound": "kill_pop", "hud": "", "objective": "", "priority": 1},
	"milestone_won": {"group": "event", "color": Palette.AMBER, "shape": "star", "sound": "stinger_milestone", "hud": "{event} won", "objective": "", "priority": 3},
	"heft_class_changed": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "class_up", "hud": "Heft {class}", "objective": "", "priority": 3},
	"heft_class_dropped": {"group": "economy", "color": Palette.RUST, "shape": "chevron", "sound": "class_down", "hud": "Heft {class}", "objective": "", "priority": 2},
	"scrap_lost": {"group": "economy", "color": Palette.RUST, "shape": "cross", "sound": "scrap_rip", "hud": "Chase your scrap", "objective": "", "priority": 2},
	"core_gained": {"group": "economy", "color": Palette.ARC, "shape": "core", "sound": "core_socket", "hud": "Bonus core: gates overcharged", "objective": "", "priority": 3},
	"synergy_discovered": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "synergy_fanfare", "hud": "SYNERGY: {name}", "objective": "", "priority": 3},
	"interaction_found": {"group": "event", "color": Palette.SANDSTONE, "shape": "diamond", "sound": "found_chime", "hud": "", "objective": "", "priority": 1},
	"jumped": {"group": "movement", "color": Palette.SAND, "shape": "chevron", "sound": "hop", "hud": "", "objective": "", "priority": 1},
	"boosted": {"group": "movement", "color": Palette.AMBER, "shape": "arrow", "sound": "boost_whoosh", "hud": "", "objective": "", "priority": 1},
	"dashed": {"group": "movement", "color": Palette.AMBER, "shape": "arrow", "sound": "dash_whoosh", "hud": "", "objective": "", "priority": 1},
	"landed": {"group": "movement", "color": Palette.SANDSTONE, "shape": "ring", "sound": "land_thud", "hud": "", "objective": "", "priority": 1},
	"slammed": {"group": "movement", "color": Palette.AMBER, "shape": "ring", "sound": "slam_boom", "hud": "", "objective": "", "priority": 1},
	"grapple_fired": {"group": "movement", "color": Palette.AMBER, "shape": "diamond", "sound": "grapple_clink", "hud": "", "objective": "", "priority": 1},
	"grapple_released": {"group": "movement", "color": Palette.SAND, "shape": "none", "sound": "grapple_release", "hud": "", "objective": "", "priority": 1},
	"mounted": {"group": "movement", "color": Palette.AMBER, "shape": "square", "sound": "pylon_plant", "hud": "", "objective": "", "priority": 1},
	"dismounted": {"group": "movement", "color": Palette.AMBER, "shape": "arrow", "sound": "pylon_eject", "hud": "", "objective": "", "priority": 1},
	"enemy_spawned": {"group": "combat", "color": Palette.RUST, "shape": "chevron", "sound": "enemy_arrive", "hud": "", "objective": "", "priority": 1},
	"enemy_struck": {"group": "combat", "color": Palette.COPPER, "shape": "burst", "sound": "hit_thwack", "hud": "", "objective": "", "priority": 1},
	"shot_fired": {"group": "combat", "color": Palette.ARC, "shape": "bar", "sound": "weapon_zap", "hud": "", "objective": "", "priority": 1},
	"special_used": {"group": "combat", "color": Palette.ARC, "shape": "star", "sound": "special_fire", "hud": "", "objective": "", "priority": 2},
	"strike_deflected": {"group": "combat", "color": Palette.SAND, "shape": "square", "sound": "clank", "hud": "", "objective": "", "priority": 1},
	"reward_offered": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "gates_open", "hud": "Reward gates ahead", "objective": "Roll through a gate", "priority": 3},
	"reward_chosen": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "gate_through", "hud": "Took {part}", "objective": "Hold your line", "priority": 3},
	"element_resolved": {"group": "event", "color": Palette.ARC, "shape": "wave", "sound": "element_resolved", "hud": "", "objective": "", "priority": 1},
	"event_announced": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "klaxon", "hud": "{event} incoming", "objective": "", "priority": 3},
	"event_started": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "event_start", "hud": "{event}", "objective": "", "priority": 2},
	"event_ended": {"group": "event", "color": Palette.VERDIGRIS, "shape": "wave", "sound": "event_end", "hud": "{event} lost", "objective": "", "priority": 2},
	# Quiet: presentation drives the event's music from it and plays no cue, so the
	# sound id is only the schema's placeholder.
	"event_progress": {"group": "event", "color": Palette.VERDIGRIS, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"launched": {"group": "flow", "color": Palette.ARC, "shape": "arrow", "sound": "launch_roar", "hud": "Launch!", "objective": "Hold your line", "priority": 3},
	"pressure_changed": {"group": "event", "color": Palette.RUST, "shape": "wave", "sound": "music_pressure", "hud": "", "objective": "", "priority": 0},
	"boss_arena_entered": {"group": "event", "color": Palette.BRASS, "shape": "star", "sound": "boss_arena_in", "hud": "Admiral Brindle", "objective": "Break Brindle's Requisition. Punch {punch} / hull plating {plating}.", "priority": 3},
	"boss_phase_changed": {"group": "event", "color": Palette.BRASS, "shape": "chevron", "sound": "boss_phase", "hud": "{name}", "objective": "", "priority": 3},
	"boss_attack_telegraphed": {"group": "combat", "color": Palette.BRASS, "shape": "wave", "sound": "boss_telegraph", "hud": "", "objective": "", "priority": 2},
	"boss_weak_point_hit": {"group": "combat", "color": Palette.BRASS, "shape": "burst", "sound": "boss_weak_hit", "hud": "", "objective": "", "priority": 1},
	"boss_defeated": {"group": "flow", "color": Palette.BRASS, "shape": "star", "sound": "stinger_boss_defeated", "hud": "Brindle routed", "objective": "", "priority": 3},
	"threat_rose": {"group": "event", "color": Palette.RUST, "shape": "chevron", "sound": "threat_up", "hud": "Threat rising", "objective": "", "priority": 2},
	# v2 W3 characters. A class's own facts wear its colour and shape from class_def.gd;
	# shared facts (contact, gauge) wear neutral ones. `sound` is an existing synth id
	# standing in; `sound_next` names the SOUND-STORY section 3 cue W5 is to bake. The
	# motif_* cues resolve through the class row's motif id. Sable's two discharges
	# differ by ear: the gauge release is gauge_released (the motif resolved), the free
	# plant discharge rides mounted (the plant clack and the motif's first notes).
	"enemy_rebounded": {"group": "combat", "color": Palette.SAND, "shape": "chevron", "sound": "clank", "sound_next": "rebound_spring_snap", "hud": "", "objective": "", "priority": 1},
	"enemy_pinned": {"group": "combat", "color": Palette.COPPER, "shape": "burst", "sound": "hit_thwack", "sound_next": "pin_double_thwack", "hud": "", "objective": "", "priority": 1},
	"vault_kicked": {"group": "movement", "color": ClassDef.SABLE_COLOR, "shape": "ring", "sound": "pylon_eject", "sound_next": "sable_octave_leap", "hud": "", "objective": "", "priority": 1},
	"gauge_charging": {"group": "combat", "color": Palette.SAND, "shape": "ring", "sound": "beacon_hum", "sound_next": "motif_accumulate", "hud": "", "objective": "", "priority": 1},
	"gauge_released": {"group": "combat", "color": Palette.SAND, "shape": "star", "sound": "found_chime", "sound_next": "motif_release", "hud": "", "objective": "", "priority": 1},
	"gauge_cancelled": {"group": "combat", "color": Palette.SAND, "shape": "cross", "sound": "ui_tick", "sound_next": "gauge_dry_click", "hud": "", "objective": "", "priority": 1},
	"sprint_started": {"group": "movement", "color": ClassDef.RIVET_COLOR, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "rivet_hat_roll", "hud": "", "objective": "", "priority": 1},
	"cc_ignored": {"group": "combat", "color": ClassDef.RIVET_COLOR, "shape": "chevron", "sound": "clank", "sound_next": "rivet_cymbal_choke", "hud": "", "objective": "", "priority": 1},
	"cloak_started": {"group": "combat", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "stage_fade", "sound_next": "kest_muffled_thump", "hud": "", "objective": "", "priority": 1},
	"cloak_broken": {"group": "combat", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "shatter", "sound_next": "kest_snare_crack", "hud": "", "objective": "", "priority": 1},
	"sticky_detonated": {"group": "combat", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "slam_boom", "sound_next": "kest_kick_thump", "hud": "", "objective": "", "priority": 1},
	"rocket_jumped": {"group": "movement", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "boost_whoosh", "sound_next": "kest_blast_lift", "hud": "", "objective": "", "priority": 1},
	"blink_used": {"group": "movement", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "dash_whoosh", "sound_next": "kest_blink_thump", "hud": "", "objective": "", "priority": 1},
	"arc_slammed": {"group": "movement", "color": ClassDef.SABLE_COLOR, "shape": "ring", "sound": "zap_hum", "sound_next": "sable_root_fifth", "hud": "", "objective": "", "priority": 1},
	"skid_smashed": {"group": "movement", "color": ClassDef.RIVET_COLOR, "shape": "chevron", "sound": "slam_boom", "sound_next": "rivet_snare_flam", "hud": "", "objective": "", "priority": 1},
	"demo_slammed": {"group": "movement", "color": ClassDef.KEST_COLOR, "shape": "burst", "sound": "slam_boom", "sound_next": "kest_falling_triad", "hud": "", "objective": "", "priority": 1},
	# v2 W7 enemies. Danger is HAZARD; a break, tenacity and the shield vault are yours,
	# so they wear bone here and the class colour where they draw (holds.gd). A hold's
	# loop and a pack's motif depend on who holds or arrives: `sound` is the stand-in and
	# `sound_next` names the SOUND-STORY section 3 cue, resolved through roster.gd's row
	# (`hold`) or faction (`arrival`). pack_arrived's `icon` is the Fleet's edge-marker
	# badge; an ancient pack shows its family's fac_ icon from the roster. Cherenkov
	# blue (3d8bff) is the ancients' light, so a weak point opening is its seam.
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
	# because every pilot picks (amber is Kest's and the rare rarity); the pick UI tints it
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
}

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
	"enemy_struck": {"stop_ms": 10.0, "stop_per_damage": 0.4, "stop_min_ms": 12.0, "stop_cap_ms": 40.0, "sparks": 8, "shake": 0.1,
		"crit": {"stop_mult": 1.4, "sparks": 16, "shake": 0.22, "color": Palette.BRASS, "sound": "crit_ping"},
		"heavy": {"stop_add_ms": 10.0, "kick": 0.45, "shake": 0.3, "dust": 12}},
	"enemy_rebounded": {"kick": 0.55, "shake": 0.35, "dust": 14},
	"enemy_killed": {"pop": 14, "debris": 10, "chain_ms": 1500, "chain_cap": 7, "multi_ms": 90, "multi_stop_ms": 30.0, "pips": 8},
	"scrap_collected": {"chain_ms": 700, "chain_cap": 9, "pulse": 0.05, "pulse_cap": 0.16},
	"part_gained": {"fountain": 18, "element": {"frost": Palette.ANCIENT, "arc": Palette.ARC, "kinetic": Palette.SAND}},
	"core_gained": {"fountain": 24},
	# Your own shots and throws: a camera kick against the aim and a recoil squash on the
	# ball, per weapon; both are camera and shell only, never the ball's velocity.
	"shot_fired": {"weapons": {"rapid_laser": {"kick": 0.05, "recoil": 0.04}, "arc_caster": {"kick": 0.12, "recoil": 0.08},
			"pylon_turret": {"kick": 0.08, "recoil": 0.0}, "sticky_charge": {"kick": 0.16, "recoil": 0.12}},
		"throw": {"sound": "dash_whoosh", "pitch": 1.5, "db": -4.0}, "stick": {"sound": "grapple_clink", "pitch": 0.7, "sparks": 8}},
	# Kest's bomb: a flash, a shockwave ring and debris; the punch grows with each enemy the
	# blast catches. Inside near_m of the ball it kicks the camera and squashes the shell.
	"sticky_detonated": {"punch_fov": 3.0, "punch_per_enemy": 1.5, "punch_cap": 10.0, "debris": 12, "dust": 14, "shake": 0.35,
		"near_m": 6.0, "near_kick": 0.6},
	"rocket_jumped": {"kick": 0.8, "punch_fov": 8.0, "squash": 0.35},
	"near_miss": {"stop_ms": 45.0, "punch_fov": -5.0, "grace_ms": 250},
	"player_hit": {"edge_s": 0.4, "edge_alpha": 0.65, "shake": 0.5, "shake_s": 0.25, "color": Palette.HAZARD},
	"scrap_lost": {"pulse": -0.22},
	"beacon_unsealed": {"stop_ms": 50.0, "punch_fov": 9.0},
}
# Rapid fire never stutters. Every stop, whatever asked for it, draws on one shared
# budget: a stop starts at least STOP_GAP_MS after the last one ended, at most
# STOP_WINDOW_BUDGET_MS of stop falls in any STOP_WINDOW_MS, and at most STOP_BUDGET_MS in
# any second. The hits of one frame coalesce into one stop.
const STOP_GAP_MS := 90
const STOP_WINDOW_MS := 300
const STOP_WINDOW_BUDGET_MS := 60.0
const STOP_BUDGET_MS := 100.0
const STOP_PER_EXTRA_HIT_MS := 2.0


static func juice(kind: String) -> Dictionary:
	return JUICE.get(kind, {})

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
	return ROWS.has(kind)


static func row(kind: String) -> Dictionary:
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
	"ability_ready": {"group": "combat", "color": Palette.SAND, "shape": "ring", "sound": "class_motif", "hud": "", "objective": "", "priority": 1},
	"ability_cooling": {"group": "combat", "color": Palette.VERDIGRIS, "shape": "ring", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"ability_active": {"group": "combat", "color": Palette.SAND, "shape": "star", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"ability_unavailable": {"group": "combat", "color": Palette.SANDSTONE, "shape": "cross", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"key_glyph": {"group": "flow", "color": Palette.SAND, "shape": "square", "sound": "ui_tick", "hud": "", "objective": "", "priority": 1},
	"run_timer": {"group": "flow", "color": Palette.SAND, "shape": "ring", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"callout_scrap": {"group": "economy", "color": Palette.ARC, "shape": "square", "sound": "callout_chime", "hud": "Scrap = heft", "objective": "", "priority": 2},
	"callout_warden": {"group": "flow", "color": Palette.HAZARD, "shape": "cross", "sound": "callout_chime", "hud": "Break it", "objective": "", "priority": 2},
	"callout_gates": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "callout_chime", "hud": "Roll through", "objective": "", "priority": 2},
	"callout_notes": {"group": "flow", "color": Palette.SAND, "shape": "square", "sound": "callout_chime", "hud": "Hold {key_tab}: notes", "objective": "", "priority": 2},
}
# The HUD's words for the three objective rows that stay flow's full readout (punch and
# plating as numbers, which combat's and the arena's tests read). On screen the gauges
# carry the numbers, so the objective shows only these words; every other row's wording
# is short already.
const OBJECTIVE_SHORT := {
	"stage_entered": "Break the Warden",
	"beacon_charge_changed": "Break the Warden",
	"boss_arena_entered": "Break Brindle's Requisition",
}
# Each Warden lesson (stage_defs warden_lesson) as the objective once the Warden is near,
# worded for the stage's family: stage 1's reactor opens its core as it vents, stage
# 2's hive stands behind a guard rack.
const LESSON_SHORT := {
	"plate": "Ram it as it vents",
	"caps": "Bowl its guard, slam caps",
	"magnet": "Shoot its magnet while pulled",
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
	"shop_charge": {"group": "economy", "color": Palette.ARC, "shape": "core", "sound": "core_socket", "sound_next": "shop_bell", "hud": "", "objective": "", "priority": 2},
	"shop_rerolled": {"group": "economy", "color": Palette.SANDSTONE, "shape": "square", "sound": "clank", "sound_next": "bench_clank", "hud": "", "objective": "", "priority": 1},
	"shop_sold": {"group": "economy", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "scrap_tick", "sound_next": "bench_clank", "hud": "", "objective": "", "priority": 1},
	"shop_refused": {"group": "economy", "color": Palette.SAND, "shape": "cross", "sound": "ui_tick", "sound_next": "moss_grumble", "hud": "", "objective": "", "priority": 1},
	"moss_beat": {"group": "economy", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "sound_next": "moss_babble", "hud": "", "objective": "", "priority": 1},
	"moss_relent": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "found_chime", "sound_next": "moss_babble_sigh", "hud": "", "objective": "", "priority": 2},
	"item_proc": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "found_chime", "sound_next": "trigger_tick", "hud": "", "objective": "", "priority": 0},
	"par_split": {"group": "flow", "color": Palette.SAND, "shape": "bar", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
}


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
	"lift_fired": {"group": "event", "color": Palette.SAND, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "lift_chuff_clank", "hud": "", "objective": "", "priority": 1},
	"launcher_charging": {"group": "event", "color": Palette.SAND, "shape": "ring", "sound": "beacon_hum", "sound_next": "steam_whistle_rise", "hud": "", "objective": "", "priority": 0},
	"cannon_fired": {"group": "event", "color": Palette.SAND, "shape": "arrow", "sound": "launch_roar", "sound_next": "cannon_bang_rail_whoosh", "hud": "", "objective": "", "priority": 1},
	"trebuchet_fired": {"group": "event", "color": Palette.SAND, "shape": "arrow", "sound": "launch_roar", "sound_next": "trebuchet_creak_whoosh", "hud": "", "objective": "", "priority": 1},
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
	"ride_grapple_line": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "grapple_clink", "sound_next": "ride_cable_clink", "hud": "", "objective": "", "priority": 1},
	"ride_glide_drop": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "dash_whoosh", "sound_next": "ride_glide_wind", "hud": "", "objective": "", "priority": 1},
	"ride_skylight": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "ride_rail_hum", "hud": "", "objective": "", "priority": 1},
	"ride_chute": {"group": "event", "color": Palette.SANDSTONE, "shape": "chevron", "sound": "boost_whoosh", "sound_next": "ride_rolling_metal", "hud": "", "objective": "", "priority": 1},
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
}


static func world_row(kind: String) -> Dictionary:
	return WORLD_ROWS.get(kind, {})
