extends RefCounted

const Palette := preload("res://src/core/palette.gd")

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
	"beacon_unsealed": {"group": "flow", "color": Palette.ARC, "shape": "star", "sound": "stinger_unseal", "hud": "Warden broken: gates open", "objective": "Charge the beacon: {percent}%. Keep rolling inside its ring.", "priority": 3},
	"scrap_collected": {"group": "economy", "color": Palette.ARC, "shape": "square", "sound": "scrap_tick", "hud": "", "objective": "", "priority": 1},
	"part_gained": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "part_get", "hud": "New part: {part}", "objective": "", "priority": 2},
	"player_hit": {"group": "combat", "color": Palette.RUST, "shape": "burst", "sound": "hurt", "hud": "", "objective": "", "priority": 2},
	"player_died": {"group": "combat", "color": Palette.RUST, "shape": "cross", "sound": "death", "hud": "Scrapped", "objective": "", "priority": 3},
	"enemy_killed": {"group": "combat", "color": Palette.COPPER, "shape": "burst", "sound": "kill_pop", "hud": "", "objective": "", "priority": 1},
	"milestone_won": {"group": "event", "color": Palette.AMBER, "shape": "star", "sound": "stinger_milestone", "hud": "Milestone won: {event}", "objective": "", "priority": 3},
	"heft_class_changed": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "class_up", "hud": "Heft {class}", "objective": "", "priority": 3},
	"heft_class_dropped": {"group": "economy", "color": Palette.RUST, "shape": "chevron", "sound": "class_down", "hud": "Heft down to {class}", "objective": "", "priority": 2},
	"scrap_lost": {"group": "economy", "color": Palette.RUST, "shape": "cross", "sound": "scrap_rip", "hud": "Scrap torn loose: chase it down", "objective": "", "priority": 2},
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
	"reward_offered": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "gates_open", "hud": "Reward gates ahead", "objective": "Roll through a gate to take its part.", "priority": 3},
	"reward_chosen": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "gate_through", "hud": "Took {part}", "objective": "Launch pad engaged.", "priority": 3},
	"element_resolved": {"group": "event", "color": Palette.ARC, "shape": "wave", "sound": "element_resolved", "hud": "", "objective": "", "priority": 1},
	"event_announced": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "klaxon", "hud": "{event} incoming", "objective": "", "priority": 3},
	"event_started": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "event_start", "hud": "{event}", "objective": "", "priority": 2},
	"event_ended": {"group": "event", "color": Palette.VERDIGRIS, "shape": "wave", "sound": "event_end", "hud": "{event} lost: it comes round again", "objective": "", "priority": 2},
	# Quiet: presentation drives the event's music from it and plays no cue, so the
	# sound id is only the schema's placeholder.
	"event_progress": {"group": "event", "color": Palette.VERDIGRIS, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"launched": {"group": "flow", "color": Palette.ARC, "shape": "arrow", "sound": "launch_roar", "hud": "Launch!", "objective": "In flight. Hold your line.", "priority": 3},
	"pressure_changed": {"group": "event", "color": Palette.RUST, "shape": "wave", "sound": "music_pressure", "hud": "", "objective": "", "priority": 0},
	"boss_arena_entered": {"group": "event", "color": Palette.BRASS, "shape": "star", "sound": "boss_arena_in", "hud": "Admiral Brindle", "objective": "Break Brindle's Requisition. Punch {punch} / hull plating {plating}.", "priority": 3},
	"boss_phase_changed": {"group": "event", "color": Palette.BRASS, "shape": "chevron", "sound": "boss_phase", "hud": "{name}", "objective": "", "priority": 3},
	"boss_attack_telegraphed": {"group": "combat", "color": Palette.BRASS, "shape": "wave", "sound": "boss_telegraph", "hud": "", "objective": "", "priority": 2},
	"boss_weak_point_hit": {"group": "combat", "color": Palette.BRASS, "shape": "burst", "sound": "boss_weak_hit", "hud": "", "objective": "", "priority": 1},
	"boss_defeated": {"group": "flow", "color": Palette.BRASS, "shape": "star", "sound": "stinger_boss_defeated", "hud": "Brindle routed", "objective": "", "priority": 3},
	"threat_rose": {"group": "event", "color": Palette.RUST, "shape": "chevron", "sound": "threat_up", "hud": "Threat rising", "objective": "", "priority": 2},
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
