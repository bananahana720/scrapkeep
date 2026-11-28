extends RefCounted

const StageDefs := preload("res://src/core/stage_defs.gd")

const Harmony := preload("res://src/presentation/harmony.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

const CUES := {
	"riser_natural": {"family": "natural", "rise": true, "voice": "stage", "notes": [62, 65, 69, 72, 74, 77, 81, 86], "trim_sound": "build_riser"},
	"drop_flood": {"danger": true, "family": "natural", "rise": false, "voice": "stage", "notes": [50, 62, 57], "accent": "kick", "trim_sound": "slam_boom"},
	"riser_fleet": {"family": "fleet", "rise": true, "voice": "brass", "notes": [50, 51, 62, 63, 74, 75, 86, 87], "accent": "anvil", "trim_sound": "fleet_motif"},
	"drop_fleet": {"danger": true, "family": "fleet", "rise": false, "voice": "brass", "notes": [50], "sound": "fleet_motif", "trim_sound": "fleet_motif"},
	"riser_ancient": {"family": "ancient", "rise": true, "voice": "sub", "notes": [44, 56], "trim_sound": "reactor_erupt"},
	"drop_ancient": {"danger": true, "family": "ancient", "rise": false, "voice": "sub", "notes": [44], "sound": "reactor_erupt", "trim_sound": "reactor_erupt"},
	"riser_industrial": {"family": "industrial", "rise": true, "voice": "steam_whistle", "notes": [62, 65, 67, 69, 74, 77, 81, 86], "trim_sound": "threat_whistle"},
	"drop_industrial": {"danger": true, "family": "industrial", "rise": false, "voice": "steam_whistle", "notes": [50], "sound": "smash_crack", "trim_sound": "smash_crack"},
	"drop_flash_flood": {"danger": true, "family": "natural", "rise": false, "voice": "stage", "notes": [57, 50, 43], "accent": "crash", "trim_sound": "slam_boom"},
	"drop_fleet_anvil": {"danger": true, "family": "fleet", "rise": false, "voice": "brass", "notes": [50, 57, 68], "accent": "anvil", "sound": "fleet_anvil", "trim_sound": "fleet_anvil"},
	"riser_mind_quote": {"family": "ancient", "ancient": "mind", "rise": true, "voice": "sub", "notes": [44, 56], "accent": "brush", "trim_sound": "reactor_erupt"},
	"drop_mind_wrong": {"danger": true, "family": "ancient", "ancient": "mind", "drop_sound": "mind_wrong_", "rise": false, "voice": "sub", "notes": [44], "sound": "reactor_erupt", "trim_sound": "reactor_erupt"},
	"drop_boiler": {"danger": true, "family": "industrial", "rise": false, "voice": "steam_whistle", "notes": [50, 56], "sound": "boiler_burst", "trim_sound": "boiler_burst"},
	"stinger_lightning": {"danger": true, "family": "natural", "rise": false, "voice": "stage", "notes": [74, 62, 50], "accent": "crash", "trim_sound": "slam_boom"},
	"drop_collapse": {"danger": true, "family": "natural", "rise": false, "voice": "stage", "notes": [57, 50, 45], "accent": "crash", "trim_sound": "smash_crack"},
	"riser_dam_siren": {"family": "natural", "rise": true, "voice": "stage", "notes": [62, 64, 65, 67, 69, 71, 74, 76], "trim_sound": "build_riser"},
	"drop_flood_horn": {"danger": true, "family": "natural", "rise": false, "voice": "brass", "notes": [38, 45], "accent": "kick", "trim_sound": "slam_boom"},
	"drop_spill_dropship": {"danger": true, "family": "fleet", "rise": false, "voice": "brass", "notes": [50, 57, 62], "accent": "anvil", "sound": "fleet_motif", "trim_sound": "fleet_motif"},
	"drop_relic_wake": {"danger": true, "family": "ancient", "rise": false, "voice": "sub", "notes": [38], "sound": "reactor_erupt", "trim_sound": "reactor_erupt"},
	"drop_spill_boiler": {"danger": true, "family": "industrial", "rise": false, "voice": "steam_whistle", "notes": [50, 57], "sound": "boiler_burst", "trim_sound": "boiler_burst"},
	"drop_cracked_wall": {"danger": true, "family": "natural", "rise": false, "voice": "stage", "notes": [62, 57, 50, 38], "accent": "crash", "trim_sound": "smash_crack"},
	"drop_reactor_blow": {"danger": true, "family": "industrial", "rise": false, "voice": "steam_whistle", "notes": [38, 44], "sound": "reactor_erupt", "trim_sound": "reactor_erupt"},
	"drop_sluice_surge": {"danger": true, "family": "industrial", "rise": false, "voice": "steam_whistle", "notes": [45, 50, 57], "sound": "smash_crack", "trim_sound": "slam_boom"},
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
	var row := synth_cue(id, context)
	var zone := str(context.get("stage", ""))
	if row.is_empty() or zone == "":
		return row
	var sound := SfxBank.stinger_id(zone, id)
	if SfxBank.file_exists(sound):
		row["sound"] = sound
		row["stinger"] = true
	return row


static func synth_cue(id: String, context: Dictionary = {}) -> Dictionary:
	var row: Dictionary = CUES.get(id, {}).duplicate(true)
	if row.has("alias"):
		return synth_cue(row.alias, context)
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


const ACE_ROOT := "res://assets/music_ace/"
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
	"brindle-p1-requisition": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/brindle_p1_requisition/manifest.json"},
	"brindle-p2-furnace": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/brindle_p2_furnace/manifest.json"},
	"brindle-p3-scuttle": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/brindle_p3_scuttle/manifest.json"},
	"waking-final": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/waking_final/manifest.json"},
	"mind-final": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/mind_final/manifest.json"},
	"champion-hype": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/champion_hype/manifest.json"},
	"euro-brindle-p3": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/euro_brindle_p3/manifest.json"},
	"euro-waking-final": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/euro_waking_final/manifest.json"},
	"euro-mind-final": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/euro_mind_final/manifest.json"},
	"euro-champion": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/euro_champion/manifest.json"},
	"anthem-brindle": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/anthem_brindle/manifest.json"},
	"anthem-waking": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/anthem_waking/manifest.json"},
	"anthem-champion": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/anthem_champion/manifest.json"},
	"anthem-gate-crane-heavy": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/anthem_gate_crane_heavy/manifest.json"},
	"anthem-haul-skip-heavy": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/anthem_haul_skip_heavy/manifest.json"},
	"anthem-cable-tender-heavy": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/anthem_cable_tender_heavy/manifest.json"},
	"miniboss-heavy": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/miniboss_heavy/manifest.json"},
	"anthem-brindle-heavy": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/anthem_brindle_heavy/manifest.json"},
	"anthem-brindle-heavier": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/anthem_brindle_heavier/manifest.json"},
	"anthem-waking-heavy": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/anthem_waking_heavy/manifest.json"},
	"anthem-waking-heavier": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/anthem_waking_heavier/manifest.json"},
	"anthem-mind": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/anthem_mind/manifest.json"},
	"anthem-mind-heavy": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/anthem_mind_heavy/manifest.json"},
	"anthem-mind-heavier": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/anthem_mind_heavier/manifest.json"},
	"landmark-spillway-dam": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/landmark_spillway_dam/manifest.json"},
	"landmark-penstock": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/landmark_penstock/manifest.json"},
	"landmark-headframe": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/landmark_headframe/manifest.json"},
	"landmark-sinkhole": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/landmark_sinkhole/manifest.json"},
	"landmark-hanging-isle": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/landmark_hanging_isle/manifest.json"},
	"landmark-crown-spire": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/landmark_crown_spire/manifest.json"},
	"event-scrap-stampede": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/event_scrap_stampede/manifest.json"},
	"event-surge-run": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/event_surge_run/manifest.json"},
	"event-hold-relay": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/event_hold_relay/manifest.json"},
	"event-flood": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/event_flood/manifest.json"},
	"event-dust-squall": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/event_dust_squall/manifest.json"},
	"event-arena": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/event_arena/manifest.json"},
	"miniboss": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/miniboss/manifest.json"},
	"anthem-gate-crane": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/anthem_gate_crane/manifest.json"},
	"anthem-haul-skip": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/anthem_haul_skip/manifest.json"},
	"anthem-cable-tender": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/anthem_cable_tender/manifest.json"},
	"moss-shop": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/moss_shop/manifest.json"},
	"fabricator": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/fabricator/manifest.json"},
	"camp-course": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/camp_course/manifest.json"},
	"modifier-curse": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/modifier_curse/manifest.json"},
	"modifier-par": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/modifier_par/manifest.json"},
	"secret-lost-tape": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/secret_lost_tape/manifest.json"},
	"secret-after-hours": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/secret_after_hours/manifest.json"},
	"secret-brindle-swing": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/secret_brindle_swing/manifest.json"},
	"secret-chip-keepers": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/secret_chip_keepers/manifest.json"},
	"secret-highdraft-rain": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/secret_highdraft_rain/manifest.json"},
	"secret-dig-dub": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/secret_dig_dub/manifest.json"},
	"boss-brindle": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/boss_brindle/manifest.json"},
	"boss-waking": {"synth_theme": 1, "ace_manifest": "res://assets/music_ace/boss_waking/manifest.json"},
	"boss-mind": {"synth_theme": 2, "ace_manifest": "res://assets/music_ace/boss_mind/manifest.json"},
	"camp": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/camp/manifest.json"},
	"title": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/title/manifest.json"},
	"title-a": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/title_a/manifest.json"},
	"title-b": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/title_b/manifest.json"},
	"title-c": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/title_c/manifest.json"},
	"summary": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/summary/manifest.json"},
}


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
	var inherited: bool = (stage is Dictionary and stage.has("stage")
		and stages in [StageDefs, StageDefs.AlphaDefs]
		and stage == stages.of(int(stage["stage"]))
		and str(override.get("ace", "")) == "")
	if override.has("ace") and not inherited:
		var ace := str(override["ace"])
		pack["ace_manifest"] = "" if ace == "" else manifest_path(ace)
	return resolve_pack(pack, sidecar_dir)


static func manifest_path(dir: String) -> String:
	return "%s%s/manifest.json" % [ACE_ROOT, dir]


static func zone_id(stage: int, stages = StageDefs) -> String:
	return "%d-%d" % [stages.world_of(stage), stages.local(stage)]


static func stage_theme(stage = "default", stages = StageDefs) -> int:
	return int(resolve(stage, "", stages)["synth_theme"])


static func resolve_pack(row: Dictionary, sidecar_dir := "") -> Dictionary:
	return {
		"synth_theme": clampi(int(row.get("synth_theme", 0)), 0, THEME_COUNT - 1),
		"ace_manifest": resolve_manifest(str(row.get("ace_manifest", "")), sidecar_dir),
	}


static func take_manifest(id: String) -> String:
	var named := str(ROWS.get(id, {}).get("ace_manifest", ""))
	if named != "":
		return named
	if not id.begins_with("take-"):
		return ""
	for dir in [id.replace("-", "_"), id]:
		var path := manifest_path(dir)
		if resolve_manifest(path) != "":
			return path
	return ""


static func resolve_manifest(manifest: String, sidecar_dir := "") -> String:
	if manifest == "":
		return ""
	var source := ProjectSettings.globalize_path(manifest)
	if FileAccess.file_exists(source):
		return source
	if manifest.begins_with(ACE_ROOT):
		var base := sidecar_dir if sidecar_dir != "" else OS.get_executable_path().get_base_dir()
		var sidecar := base.path_join("music_ace").path_join(manifest.trim_prefix(ACE_ROOT))
		if FileAccess.file_exists(sidecar):
			return sidecar
	return ""


static var stem_dir := ""


static func stem_file(manifest_file: String, file: String) -> String:
	if stem_dir != "":
		return stem_dir.path_join(manifest_file.get_base_dir().get_file()).path_join(file)
	return manifest_file.get_base_dir().path_join(file)


static func pack_on_disk(manifest_path: String, sidecar_dir := "") -> bool:
	var path := resolve_manifest(manifest_path, sidecar_dir)
	if path == "":
		return false
	var m = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not m is Dictionary or (m.get("clips", {}) as Dictionary).is_empty():
		return false
	for clip in m["clips"].values():
		for file in (clip.get("files", {}) as Dictionary).values():
			if not FileAccess.file_exists(stem_file(path, String(file))):
				return false
	return true
