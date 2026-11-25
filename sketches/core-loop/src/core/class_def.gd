extends Resource

const Palette := preload("res://src/core/palette.gd")


const SABLE_COLOR := Palette.ARC
const RIVET_COLOR := Palette.COPPER
const KEST_COLOR := Palette.AMBER
const TARN_COLOR := Palette.RUST
const TALLY_COLOR := Palette.LEDGER
const CANNON_COLOR := Palette.ANCIENT
const SABLE_SCREEN := Color("a8c8f0")

@export var id := ""
@export var display_name := ""
@export var role := ""
@export var species := ""
@export var pitch := ""
@export var weapon_id := ""
@export var movement_id := ""
@export var special_id := ""
@export var smash_id := ""
@export var line_id := ""
@export var ultimate_id := ""
@export var color := Color.WHITE
@export var shape := ""
@export var motif := ""
@export var sound := ""
@export var bible_home := ""
@export var synergy_hooks: PackedStringArray = []
@export var unlock := {}
@export var starter := false
@export var base_hp := 100.0
@export var hp_growth := 10.0

const UNLOCK_BYS := ["start", "rescue:rivet", "rescue:dig", "rescue:isles", "boss:brindle", "leaves:3", "boss:mind"]
const UNLOCK_LABEL_WORDS := 9


static func make(row: Dictionary) -> Resource:
	var def: Resource = load("res://src/core/class_def.gd").new()
	for key in row:
		def.set(key, row[key])
	if row.has("unlock"):
		def.starter = String(row["unlock"].get("by", "")) == "start"
	return def


static func unlock_row(by: String) -> String:
	match by:
		"rescue:rivet":
			return "rivet_rescued"
		"rescue:dig":
			return "dig_rescued"
		"rescue:isles":
			return "isles_rescued"
		"boss:brindle":
			return "brindle_routed"
		"leaves:3":
			return "ledger_balanced"
		"boss:mind":
			return "mind_quieted"
	return ""


static func unlock_met(by: String, earned: Callable) -> bool:
	if by == "start":
		return true
	var row := unlock_row(by)
	return row != "" and bool(earned.call(row))


static func unlock_open(unlock: Dictionary, earned: Callable) -> bool:
	if unlock_met(String(unlock.get("by", "")), earned):
		return true
	return unlock.has("or") and unlock_met(String(unlock["or"]), earned)


static func all() -> Array[Resource]:
	var list: Array[Resource] = [
		make({"id": "pylon_engineer", "display_name": "Sable", "role": "Pylon engineer", "species": "fox",
			"pitch": "Plant a beachhead, then launch off it like a cannonball. Grapple, vault off steep faces, mount a pylon and turret.",
			"weapon_id": "arc_caster", "movement_id": "grapple", "special_id": "detonation_gauge", "smash_id": "arc_slam", "line_id": "bank_shot", "ultimate_id": "cable_run",
			"base_hp": 100.0, "hp_growth": 10.0,
			"color": SABLE_COLOR, "shape": "ring", "motif": "sable", "sound": "pylon_plant",
			"bible_home": "Sable, displacement and traversal",
			"unlock": {"by": "start", "label": "On the roster since the first shift."},
			"synergy_hooks": PackedStringArray(["on_vault_kick", "on_pylon_discharge", "on_mount_planted"])}),
		make({"id": "runner_gunner", "display_name": "Rivet", "role": "Runner-gunner", "species": "mole machinist",
			"pitch": "An unstoppable laser sprinter. Shrug off crowd control, punch force down the cable, then drive a measured cut.",
			"weapon_id": "rapid_laser", "movement_id": "overdrive_sprint", "special_id": "overdrive_blast", "smash_id": "shockwave_skid", "line_id": "line_drive", "ultimate_id": "foundry_cutter",
			"base_hp": 115.0, "hp_growth": 12.0,
			"color": RIVET_COLOR, "shape": "chevron", "motif": "rivet", "sound": "boost_whoosh",
			"bible_home": "Rivet, precision and controlled corridors",
			"unlock": {"by": "rescue:rivet", "label": "Open the cage. The runner never clocked out."},
			"synergy_hooks": PackedStringArray(["on_sprint_start", "on_blast_release", "on_cc_ignored"])}),
		make({"id": "demolitions_caster", "display_name": "Kest", "role": "Demolitions caster", "species": "bird",
			"pitch": "Vanish in your own smoke, then drop a line of fire where they least expect it.",
			"weapon_id": "sticky_charge", "movement_id": "smoke_blink", "special_id": "detonation_line", "smash_id": "demo_slam", "line_id": "cable_charge", "ultimate_id": "windhover",
			"base_hp": 80.0, "hp_growth": 7.0,
			"color": KEST_COLOR, "shape": "burst", "motif": "kest", "sound": "slam_boom",
			"bible_home": "Fuse, directed casting and local pressure",
			"unlock": {"by": "rescue:dig", "label": "Dig out whoever keeps knocking behind the wall."},
			"synergy_hooks": PackedStringArray(["on_cloak_crit", "on_rocket_jump", "on_chain_detonation"])}),
		make({"id": "tarn", "display_name": "Tarn", "role": "Claw bruiser", "species": "tiger",
			"pitch": "Plant a claw and pull yourself into the fight. Clamp what is close, then rend it with heavy sweeps.",
			"weapon_id": "claw_sweep", "movement_id": "claw_pull", "special_id": "clamp", "smash_id": "rend_slam", "line_id": "claw_drag", "ultimate_id": "redjaw_rend",
			"base_hp": 135.0, "hp_growth": 15.0,
			"color": TARN_COLOR, "shape": "cross", "motif": "tarn", "sound": "clank",
			"bible_home": "Tarn, articulated claw melee",
			"unlock": {"by": "boss:brindle", "label": "Rout Brindle. Somebody signs on the day he falls."},
			"synergy_hooks": PackedStringArray(["on_claw_pull", "on_clamp_catch", "on_rend_landing"])}),
		make({"id": "tally", "display_name": "Tally", "role": "Dispatch wire-tapper", "species": "pack rat",
			"pitch": "Tap the pack onto a live copper circuit, pull them to a forged beacon, and discharge at speed. Roll to refill pressure; Q rides home and settles every clip.",
			"weapon_id": "ledger_reader", "movement_id": "flywheel_surge", "special_id": "gather_plate", "smash_id": "stamp_slam",
			"line_id": "link_clips", "ultimate_id": "plate_return",
			"base_hp": 90.0, "hp_growth": 8.0,
			"color": TALLY_COLOR, "shape": "square", "motif": "tally", "sound": "cog_tick",
			"bible_home": "Tally, dispatch wire-tapper",
			"unlock": {"by": "leaves:3", "or": "rescue:isles", "label": "Open the Fleet's cage, or patch Moss's switchboard."},
			"synergy_hooks": PackedStringArray(["on_card_run", "on_link_arc", "on_stamp_contact"])}),
		make({"id": "remembered_cannon", "display_name": "Cannon", "role": "Boss-mirror cannon", "species": "rebuilt ancient",
			"pitch": "The Mind's own guns, remembered. Call a lane, cut a split behind you, plate what you hit, ring the ground when you land.",
			"weapon_id": "cannon_lane", "movement_id": "cannon_recoil", "special_id": "cannon_plate", "smash_id": "cannon_rush", "line_id": "cannon_lane_charge", "ultimate_id": "cannon_fire_mission",
			"base_hp": 105.0, "hp_growth": 10.0,
			"color": CANNON_COLOR, "shape": "lane", "motif": "cannon", "sound": "launch_roar",
			"bible_home": "Remembered cannon, the Mind's four families",
			"unlock": {"by": "boss:mind", "label": "Quiet the Mind. One of its guns remembers you."},
			"synergy_hooks": PackedStringArray(["on_lane_landed", "on_plate_exposed", "on_rush_ring"])}),
	]
	return list


static func by_id(wanted: String) -> Resource:
	for def in all():
		if def.id == wanted:
			return def
	return null


static func screen_color(pilot_color: Color) -> Color:
	return Color(SABLE_SCREEN, pilot_color.a) if Color(pilot_color, 1.0).is_equal_approx(SABLE_COLOR) else pilot_color
