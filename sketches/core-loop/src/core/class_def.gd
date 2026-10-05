extends Resource

const Palette := preload("res://src/core/palette.gd")

# A class is data (TADR-008). One row carries every layer's reading of the character:
# the four ability ids the bar keys on (weapon, movement, special, smash), which combat,
# movement and the ability state dispatch by, and the colour, shape and sound the HUD,
# VFX, audio and icons read. Event rows that belong to one class take its colour from
# the constants below, so a class looks the same in every layer. The names are
# candidates from the Bible's class vocabulary (DESIGN-V2 section 2). The pilots are
# animals, the reigning species after humans were lost.

const SABLE_COLOR := Palette.ARC
const RIVET_COLOR := Palette.COPPER
const KEST_COLOR := Palette.AMBER
const TARN_COLOR := Palette.RUST

@export var id := ""
@export var display_name := ""
@export var role := ""
@export var species := ""
@export var pitch := ""
@export var weapon_id := ""
@export var movement_id := ""
@export var special_id := ""
@export var smash_id := ""
@export var color := Color.WHITE
# An event_kinds shape: ring (area), chevron (motion) or burst (explosive, drawn as a
# starburst). The indicator's rim ticks take it too.
@export var shape := ""
# The leitmotif id (SOUND-STORY section 2). The notes, rhythm and instrument live in
# W5's motif table in harmony.gd under this id; every class cue is built from them.
@export var motif := ""
# The synth id the class's cues stand in with until the motif cues are baked.
@export var sound := ""
@export var bible_home := ""
@export var synergy_hooks: PackedStringArray = []
# Playable from a fresh profile. Sable is the only starter; every other pilot is named by one
# achievement row's pilot reward (achievements.gd).
@export var starter := false


static func make(row: Dictionary) -> Resource:
	var def: Resource = load("res://src/core/class_def.gd").new()
	for key in row:
		def.set(key, row[key])
	return def


static func all() -> Array[Resource]:
	var list: Array[Resource] = [
		make({"id": "pylon_engineer", "display_name": "Sable", "role": "Pylon engineer", "species": "fox",
			"pitch": "Plant a beachhead, then launch off it like a cannonball. Grapple, vault off steep faces, mount a pylon and turret.",
			"weapon_id": "arc_caster", "movement_id": "grapple", "special_id": "detonation_gauge", "smash_id": "arc_slam",
			"color": SABLE_COLOR, "shape": "ring", "motif": "sable", "sound": "pylon_plant",
			"bible_home": "Sable, displacement and traversal",
			"starter": true, "synergy_hooks": PackedStringArray(["on_vault_kick", "on_pylon_discharge", "on_mount_planted"])}),
		make({"id": "runner_gunner", "display_name": "Rivet", "role": "Runner-gunner", "species": "mole machinist",
			"pitch": "An unstoppable laser sprinter. Hold the sprint through crowd control, then blast the crowd off you.",
			"weapon_id": "rapid_laser", "movement_id": "overdrive_sprint", "special_id": "overdrive_blast", "smash_id": "shockwave_skid",
			"color": RIVET_COLOR, "shape": "chevron", "motif": "rivet", "sound": "boost_whoosh",
			"bible_home": "Rivet, precision and controlled corridors",
			"starter": true, "synergy_hooks": PackedStringArray(["on_sprint_start", "on_blast_release", "on_cc_ignored"])}),
		make({"id": "demolitions_caster", "display_name": "Kest", "role": "Demolitions caster", "species": "bird",
			"pitch": "Vanish in your own smoke, then drop a line of fire where they least expect it.",
			"weapon_id": "sticky_charge", "movement_id": "smoke_blink", "special_id": "detonation_line", "smash_id": "demo_slam",
			"color": KEST_COLOR, "shape": "burst", "motif": "kest", "sound": "slam_boom",
			"bible_home": "Fuse, directed casting and local pressure",
			"starter": false, "synergy_hooks": PackedStringArray(["on_cloak_crit", "on_rocket_jump", "on_chain_detonation"])}),
		# Motif, sound and shape stay on Rivet's until the look and sound unit (wave 15) lands.
		make({"id": "tarn", "display_name": "Tarn", "role": "Claw bruiser", "species": "tiger",
			"pitch": "Plant a claw and pull yourself into the fight. Clamp what is close, then rend it with heavy sweeps.",
			"weapon_id": "claw_sweep", "movement_id": "claw_pull", "special_id": "clamp", "smash_id": "rend_slam",
			"color": TARN_COLOR, "shape": "chevron", "motif": "rivet", "sound": "boost_whoosh",
			"bible_home": "Tarn, articulated claw melee",
			"starter": false, "synergy_hooks": PackedStringArray(["on_claw_pull", "on_clamp_catch", "on_rend_landing"])}),
	]
	return list


static func by_id(wanted: String) -> Resource:
	for def in all():
		if def.id == wanted:
			return def
	return null
