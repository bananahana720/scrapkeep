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
# hud       toast wording, "" for none. Placeholders: {stage} {part} {event} {percent}.
# objective standing objective while the flow state this kind leads to is live, or "".
# priority  0 ambient (music only), 1 feedback (sound and small VFX), 2 notable (toast),
#           3 critical (big toast, stinger on the beat).

const GROUPS := ["movement", "combat", "economy", "flow", "event"]
const SHAPES := ["ring", "diamond", "square", "chevron", "arrow", "burst", "bar", "star", "cross", "wave", "none"]
const FIELDS := ["group", "color", "shape", "sound", "hud", "objective", "priority"]
const TOAST_PRIORITY := 2

const ROWS := {
	"run_started": {"group": "flow", "color": Palette.SAND, "shape": "star", "sound": "stinger_run", "hud": "Run started", "objective": "", "priority": 3},
	"flow_changed": {"group": "flow", "color": Palette.SAND, "shape": "none", "sound": "ui_tick", "hud": "", "objective": "", "priority": 0},
	"stage_entered": {"group": "flow", "color": Palette.SAND, "shape": "chevron", "sound": "stinger_stage", "hud": "Stage {stage}", "objective": "Roll to the beacon ({distance} m). Scrap and events are optional.", "priority": 3},
	"stage_cleared": {"group": "flow", "color": Palette.ARC, "shape": "star", "sound": "stinger_clear", "hud": "Stage {stage} clear", "objective": "", "priority": 3},
	"run_ended": {"group": "flow", "color": Palette.ARC, "shape": "star", "sound": "stinger_run_end", "hud": "Run complete", "objective": "", "priority": 3},
	"beacon_charge_changed": {"group": "flow", "color": Palette.ARC, "shape": "ring", "sound": "beacon_hum", "hud": "", "objective": "Charge the beacon: {percent}%. Keep rolling inside its ring.", "priority": 1},
	"scrap_collected": {"group": "economy", "color": Palette.ARC, "shape": "square", "sound": "scrap_tick", "hud": "", "objective": "", "priority": 1},
	"part_gained": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "part_get", "hud": "New part: {part}", "objective": "", "priority": 2},
	"player_hit": {"group": "combat", "color": Palette.RUST, "shape": "burst", "sound": "hurt", "hud": "", "objective": "", "priority": 2},
	"player_died": {"group": "combat", "color": Palette.RUST, "shape": "cross", "sound": "death", "hud": "Scrapped", "objective": "", "priority": 3},
	"enemy_killed": {"group": "combat", "color": Palette.COPPER, "shape": "burst", "sound": "kill_pop", "hud": "", "objective": "", "priority": 1},
	"milestone_won": {"group": "event", "color": Palette.AMBER, "shape": "star", "sound": "stinger_milestone", "hud": "Milestone won: {event}", "objective": "", "priority": 3},
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
	"reward_offered": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "gates_open", "hud": "Reward gates ahead", "objective": "Roll through a gate to take its part.", "priority": 3},
	"reward_chosen": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "gate_through", "hud": "Took {part}", "objective": "Launch pad engaged.", "priority": 3},
	"event_announced": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "klaxon", "hud": "{event} incoming", "objective": "", "priority": 3},
	"event_started": {"group": "event", "color": Palette.HAZARD, "shape": "wave", "sound": "event_start", "hud": "{event}", "objective": "", "priority": 2},
	"event_ended": {"group": "event", "color": Palette.VERDIGRIS, "shape": "wave", "sound": "event_end", "hud": "{event} over", "objective": "", "priority": 2},
	"launched": {"group": "flow", "color": Palette.ARC, "shape": "arrow", "sound": "launch_roar", "hud": "Launch!", "objective": "In flight. Hold your line.", "priority": 3},
	"pressure_changed": {"group": "event", "color": Palette.RUST, "shape": "wave", "sound": "music_pressure", "hud": "", "objective": "", "priority": 0},
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
