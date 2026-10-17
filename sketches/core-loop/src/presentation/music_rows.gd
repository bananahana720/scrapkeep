extends RefCounted

const StageDefs := preload("res://src/core/stage_defs.gd")

const Harmony := preload("res://src/presentation/harmony.gd")

# Notes are home-key MIDI. Rise cells divide the full director lead evenly.
# trim_sound names an existing bank level; priority comes from the triggering fact.
const CUES := {
	"riser_natural": {"family": "natural", "rise": true, "voice": "stage", "notes": [62, 65, 69, 72, 74, 77, 81, 86], "trim_sound": "build_riser"},
	"drop_flood": {"danger": true, "family": "natural", "rise": false, "voice": "stage", "notes": [50, 62, 57], "accent": "kick", "trim_sound": "slam_boom"},
	"riser_fleet": {"family": "fleet", "rise": true, "voice": "brass", "notes": [50, 51, 62, 63, 74, 75, 86, 87], "accent": "anvil", "trim_sound": "fleet_motif"},
	"drop_fleet": {"danger": true, "family": "fleet", "rise": false, "voice": "brass", "notes": [50], "sound": "fleet_motif", "trim_sound": "fleet_motif"},
	"riser_ancient": {"family": "ancient", "rise": true, "voice": "sub", "notes": [44, 56], "trim_sound": "reactor_erupt"},
	"drop_ancient": {"danger": true, "family": "ancient", "rise": false, "voice": "sub", "notes": [44], "sound": "reactor_erupt", "trim_sound": "reactor_erupt"},
	"riser_industrial": {"family": "industrial", "rise": true, "voice": "steam_whistle", "notes": [62, 65, 67, 69, 74, 77, 81, 86], "trim_sound": "threat_whistle"},
	"drop_industrial": {"danger": true, "family": "industrial", "rise": false, "voice": "steam_whistle", "notes": [50], "sound": "smash_crack", "trim_sound": "smash_crack"},
	"drop_flash_flood": {"alias": "drop_flood"},
	# The Highdraft's own four (G home, Lydian lift; D-home notes, so G#/68 is the sharp eleven).
	# The mooring crew's anvil answers twice and the Fleet brass lifts onto the eleven.
	"drop_fleet_anvil": {"danger": true, "family": "fleet", "rise": false, "voice": "brass", "notes": [50, 57, 68], "accent": "anvil", "sound": "fleet_anvil", "trim_sound": "fleet_anvil"},
	# Always the Mind: the player's hook played back inverted, a brushed gust under each note.
	"riser_mind_quote": {"family": "ancient", "ancient": "mind", "rise": true, "voice": "sub", "notes": [44, 56], "accent": "brush", "trim_sound": "reactor_erupt"},
	# The quote's flattened last note held alone while the floor slides a tritone under it.
	"drop_mind_wrong": {"danger": true, "family": "ancient", "ancient": "mind", "drop_sound": "mind_wrong_", "rise": false, "voice": "sub", "notes": [44], "sound": "reactor_erupt", "trim_sound": "reactor_erupt"},
	# A pressure vessel giving: hiss swell, valve pop, a tritone steam shriek.
	"drop_boiler": {"danger": true, "family": "industrial", "rise": false, "voice": "steam_whistle", "notes": [50, 56], "sound": "boiler_burst", "trim_sound": "boiler_burst"},
	"stinger_lightning": {"danger": true, "family": "natural", "rise": false, "voice": "stage", "notes": [74, 62, 50], "accent": "crash", "trim_sound": "slam_boom"},
	"drop_collapse": {"danger": true, "family": "natural", "rise": false, "voice": "stage", "notes": [57, 50, 45], "accent": "crash", "trim_sound": "smash_crack"},
	"drop_cave_in": {"danger": true, "family": "natural", "rise": false, "voice": "stage", "notes": [50, 45, 38], "accent": "kick", "trim_sound": "land_thud"},
	"drop_drain": {"family": "natural", "rise": false, "voice": "stage", "notes": [62, 57, 50, 45], "trim_sound": "stage_fade"},
	"drop_impact": {"danger": true, "family": "natural", "rise": false, "voice": "stage", "notes": [38, 50], "accent": "kick", "trim_sound": "slam_boom"},
	"drop_lightning": {"alias": "stinger_lightning"},
	"drop_natural": {"alias": "drop_flood"},
}
const ANCIENT_VOICES := {"reactor_relic": "reactor", "swarm_remnant": "swarm", "mind_hand": "mind"}
const ANCIENT_DROPS := {"reactor": "reactor_erupt", "swarm": "swarm_lock", "mind": "mind_"}
const STAGE_VOICES := ["lead", "brass", "talk"]


const WARDEN_CUES := {"warden_engaged": {"danger": true}, "warden_charge": {"danger": true}, "boss_attack_telegraphed": {"danger": true}}


static func danger(id: String) -> bool:
	var row: Dictionary = CUES.get(id, WARDEN_CUES.get(id, {}))
	if row.has("alias"):
		return danger(row.alias)
	return bool(row.get("danger", false))


static func cue(id: String, context: Dictionary = {}) -> Dictionary:
	var row: Dictionary = CUES.get(id, {}).duplicate(true)
	if row.has("alias"):
		return cue(row.alias, context)
	if row.is_empty():
		return row
	if row.voice == "stage":
		row.voice = STAGE_VOICES[clampi(int(context.get("theme", 0)), 0, STAGE_VOICES.size() - 1)]
	if row.family == "ancient":
		var ancient: String = row.get("ancient", context.get("ancient", "reactor"))
		var motif := Harmony.motif(ancient)
		if motif.is_empty():
			return {}
		row.voice = motif.voice
		row.notes = []
		var cells: Array = Harmony.mind_quote(str(context.get("motif", "sable"))) if ancient == "mind" else motif.cells
		for cell in cells:
			row.notes.append(int(cell[1]))
		if ancient == "swarm":
			row.notes.append_array(motif.chord)
		if not row.rise:
			row.sound = String(row.get("drop_sound", ANCIENT_DROPS[ancient])) + (str(context.get("motif", "sable")) if ancient == "mind" else "")
		row.trim_sound = row.sound if row.has("sound") else {"reactor": "reactor_erupt", "swarm": "swarm_buzz", "mind": "mind_" + str(context.get("motif", "sable"))}[ancient]
	return row


const THEME_COUNT := 3
const ROWS := {
	"default": {"synth_theme": 0, "ace_manifest": ""},
	"1-1": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/spillway/manifest.json"},
	"1-2": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/cable_reach/manifest.json"},
	"2-1": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/dig_upper/manifest.json"},
	"2-2": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/dig_deep/manifest.json"},
	"3-1": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/highdraft/manifest.json"},
	"3-2": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/highdraft_crown/manifest.json"},
	"brindle": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/brindle/manifest.json"},
	"waking": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/waking/manifest.json"},
	"mind": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/mind/manifest.json"},
	"title": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/title/manifest.json"},
	"summary": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/summary/manifest.json"},
}


# A zone/boss id or a stage row. Existing {theme, ace} stage music overrides the pack.
static func resolve(stage = "default", sidecar_dir := "", stages = StageDefs) -> Dictionary:
	if stage is int:
		stage = stages.of(stage)
	var id := str(stage)
	var override := {}
	if stage is Dictionary:
		id = zone_id(int(stage["stage"]), stages) if stage.has("stage") else "default"
		id = str(stage.get("id", id))
		if stage.get("music") is Dictionary:
			override = stage["music"]
	var pack: Dictionary = ROWS.get(id, ROWS["default"]).duplicate()
	pack["synth_theme"] = int(override.get("theme", pack["synth_theme"]))
	# The canonical alpha rows predate the new packs. Their empty ACE fields inherit
	# ROWS; caller-authored overrides still explicitly select synth with an empty field.
	var inherited: bool = (stage is Dictionary and stage.has("stage")
		and stages in [StageDefs, StageDefs.AlphaDefs]
		and stage == stages.of(int(stage["stage"]))
		and str(override.get("ace", "")) == "")
	if override.has("ace") and not inherited:
		var ace := str(override["ace"])
		pack["ace_manifest"] = "" if ace == "" else "res://assets/music_ace/%s/manifest.json" % ace
	return resolve_pack(pack, sidecar_dir)


static func zone_id(stage: int, stages = StageDefs) -> String:
	return "%d-%d" % [stages.world_of(stage), stages.local(stage)]


static func stage_theme(stage = "default", stages = StageDefs) -> int:
	return int(resolve(stage, "", stages)["synth_theme"])


static func resolve_pack(row: Dictionary, sidecar_dir := "") -> Dictionary:
	return {
		"synth_theme": clampi(int(row.get("synth_theme", 0)), 0, THEME_COUNT - 1),
		"ace_manifest": resolve_manifest(str(row.get("ace_manifest", "")), sidecar_dir),
	}


# Source first, then the export's music_ace sidecar. Missing packs are silent synth fallback.
static func resolve_manifest(manifest_path: String, sidecar_dir := "") -> String:
	if manifest_path == "":
		return ""
	var source := ProjectSettings.globalize_path(manifest_path)
	if FileAccess.file_exists(source):
		return source
	var prefix := "res://assets/music_ace/"
	if manifest_path.begins_with(prefix):
		var base := sidecar_dir if sidecar_dir != "" else OS.get_executable_path().get_base_dir()
		var sidecar := base.path_join("music_ace").path_join(manifest_path.trim_prefix(prefix))
		if FileAccess.file_exists(sidecar):
			return sidecar
	return ""
