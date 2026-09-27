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
	"weak_point_opened": {"group": "combat", "color": Color("3d8bff"), "shape": "core", "sound": "beacon_hum", "hud": "", "objective": "", "priority": 1},
}

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
# class row's own sound (sound_next, else sound), so the ready swell and a charge pip
# filling play the class's tune (SOUND-STORY section 7, W1).
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
# Each Warden lesson (stage_defs warden_lesson) as the objective once the Warden is near.
const LESSON_SHORT := {
	"plate": "Ram it hard",
	"caps": "Slam its vent caps",
	"magnet": "Shoot its magnet while pulled",
}


# v2 W7 enemies
# Each faction's fac_ icon, so the pack_arrived edge marker and any faction badge read
# one table: the Fleet's requisition tag, or the ancient family's own mark.
const FACTION_ICONS := {"fleet": "fac_fleet", "reactor": "fac_reactor", "swarm": "fac_swarm", "mind": "fac_mind"}


static func faction_icon(faction: String) -> String:
	return FACTION_ICONS.get(faction, "fac_fleet")
