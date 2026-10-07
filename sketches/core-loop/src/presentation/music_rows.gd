extends RefCounted

const StageDefs := preload("res://src/core/stage_defs.gd")

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
