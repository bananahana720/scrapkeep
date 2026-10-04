extends RefCounted

const THEME_COUNT := 3
const ROWS := {
	"default": {"synth_theme": 0, "ace_manifest": ""},
	"1-1": {"synth_theme": 0, "ace_manifest": "res://assets/music_ace/spillway/manifest.json"},
	"1-2": {"synth_theme": 1, "ace_manifest": ""},
	"brindle": {"synth_theme": 0, "ace_manifest": ""},
}


# A zone/boss id or a stage row. Existing {theme, ace} stage music overrides the pack.
static func resolve(stage = "default", sidecar_dir := "") -> Dictionary:
	var id := str(stage)
	var override := {}
	if stage is Dictionary:
		id = "%d-%d" % [int(stage.get("world", 1)), int(stage["stage"])] if stage.has("stage") else "default"
		id = str(stage.get("id", id))
		if stage.get("music") is Dictionary:
			override = stage["music"]
	var pack: Dictionary = ROWS.get(id, ROWS["default"]).duplicate()
	pack["synth_theme"] = int(override.get("theme", pack["synth_theme"]))
	if override.has("ace"):
		var ace := str(override["ace"])
		pack["ace_manifest"] = "" if ace == "" else "res://assets/music_ace/%s/manifest.json" % ace
	return resolve_pack(pack, sidecar_dir)


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
