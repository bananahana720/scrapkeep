extends RefCounted

# The viewer's settings, saved beside the codex and the UI profile as settings.json:
# the music and effects levels and the comfort levels (screen shake, hit-stop) the pause
# menu set. Only levels a player chose are stored, so an untouched game keeps the
# defaults. Storage failures never throw; the settings keep working in memory, as the
# UI profile does.

const SafeStore := preload("res://src/core/safe_store.gd")

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
	var parsed = SafeStore.parse(FileAccess.get_file_as_string(path), TYPE_DICTIONARY, {"volumes": SafeStore.NUMBERS, "comfort": SafeStore.NUMBERS})
	if parsed == null:
		last_error = "unreadable %s; kept as %s" % [path, SafeStore.quarantine(path)]
		return
	var saved: Dictionary = parsed.get("volumes", {})
	for bus in saved:
		volumes[String(bus)] = clampf(float(saved[bus]), 0.0, 1.0)
	var feel: Dictionary = parsed.get("comfort", {})
	for id in feel:
		comfort[String(id)] = clampf(float(feel[id]), 0.0, 1.0)


func set_volume(bus: String, level: float) -> void:
	volumes[bus] = clampf(level, 0.0, 1.0)
	save()


func set_comfort(id: String, level: float) -> void:
	comfort[id] = clampf(level, 0.0, 1.0)
	save()


func save() -> void:
	var err := SafeStore.write_atomic(path, JSON.stringify({"volumes": volumes, "comfort": comfort}, "  "))
	if err != OK:
		last_error = error_string(err)
