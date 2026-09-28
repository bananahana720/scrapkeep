extends RefCounted

# The viewer's settings, saved beside the codex and the UI profile as settings.json:
# the music and effects levels and the comfort levels (screen shake, hit-stop) the pause
# menu set. Only levels a player chose are stored, so an untouched game keeps the
# defaults. Storage failures never throw; the settings keep working in memory, as the
# UI profile does.

const FILE := "settings.json"

var path := ""
var volumes := {}
var comfort := {}
var last_error := ""


func _init(storage_dir := "user://") -> void:
	path = storage_dir.path_join(FILE)
	load_saved()


func load_saved() -> void:
	volumes = {}
	comfort = {}
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		last_error = "unreadable %s" % path
		return
	var saved = parsed.get("volumes", {})
	if saved is Dictionary:
		for bus in saved:
			volumes[String(bus)] = clampf(float(saved[bus]), 0.0, 1.0)
	var feel = parsed.get("comfort", {})
	if feel is Dictionary:
		for id in feel:
			comfort[String(id)] = clampf(float(feel[id]), 0.0, 1.0)


func set_volume(bus: String, level: float) -> void:
	volumes[bus] = clampf(level, 0.0, 1.0)
	save()


func set_comfort(id: String, level: float) -> void:
	comfort[id] = clampf(level, 0.0, 1.0)
	save()


func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = error_string(FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"volumes": volumes, "comfort": comfort}, "  "))
	file.close()
