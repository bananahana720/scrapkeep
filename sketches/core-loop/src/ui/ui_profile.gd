extends RefCounted

# What the HUD has already taught this profile, saved beside the codex as
# ui-profile.json: how many times each contextual key glyph's action succeeded, and
# which first-run callouts have shown. Storage failures never throw; the profile keeps
# working in memory, as the codex does.

const FILE := "ui-profile.json"

var path := ""
var glyph_uses := {}
var callouts_seen: Array = []
var last_error := ""


func _init(storage_dir := "user://") -> void:
	path = storage_dir.path_join(FILE)
	load_saved()


func load_saved() -> void:
	glyph_uses = {}
	callouts_seen = []
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		last_error = "unreadable %s" % path
		return
	var uses = parsed.get("glyph_uses", {})
	if uses is Dictionary:
		for action in uses:
			glyph_uses[String(action)] = int(uses[action])
	var seen = parsed.get("callouts_seen", [])
	if seen is Array:
		for id in seen:
			callouts_seen.append(String(id))


func uses(action: String) -> int:
	return int(glyph_uses.get(action, 0))


func add_use(action: String) -> int:
	glyph_uses[action] = uses(action) + 1
	save()
	return glyph_uses[action]


func seen(callout_id: String) -> bool:
	return callout_id in callouts_seen


func mark_seen(callout_id: String) -> void:
	if seen(callout_id):
		return
	callouts_seen.append(callout_id)
	save()


func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = error_string(FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"glyph_uses": glyph_uses, "callouts_seen": callouts_seen}, "  "))
	file.close()
