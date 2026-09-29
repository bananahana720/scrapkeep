extends RefCounted

# What the HUD has already taught this profile, saved beside the codex as
# ui-profile.json: how many times each contextual key glyph's action succeeded, and
# which first-run callouts have shown. Storage failures never throw; the profile keeps
# working in memory, as the codex does.

const FILE := "ui-profile.json"

var path := ""
var glyph_uses := {}
var callouts_seen: Array = []
# Ids of the synergies, parts and finds whose first-discovery picture card has shown
# (--discovery=cards); a repeat only gets the quick glyph-and-name pop.
var discoveries_seen: Array = []
var last_error := ""


func _init(storage_dir := "user://") -> void:
	path = storage_dir.path_join(FILE)
	load_saved()


func load_saved() -> void:
	glyph_uses = {}
	callouts_seen = []
	discoveries_seen = []
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
	var found = parsed.get("discoveries_seen", [])
	if found is Array:
		for id in found:
			discoveries_seen.append(String(id))


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


func discovered(discovery_id: String) -> bool:
	return discovery_id in discoveries_seen


func mark_discovered(discovery_id: String) -> void:
	if discovered(discovery_id):
		return
	discoveries_seen.append(discovery_id)
	save()


# Two owners (the HUD and the banner) may hold the same file; a save keeps what the
# other one wrote instead of dropping it.
func _merge_disk() -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return
	for id in parsed.get("callouts_seen", []):
		if not String(id) in callouts_seen:
			callouts_seen.append(String(id))
	for id in parsed.get("discoveries_seen", []):
		if not String(id) in discoveries_seen:
			discoveries_seen.append(String(id))
	var uses = parsed.get("glyph_uses", {})
	if uses is Dictionary:
		for action in uses:
			glyph_uses[String(action)] = maxi(int(uses[action]), int(glyph_uses.get(String(action), 0)))


func save() -> void:
	_merge_disk()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = error_string(FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"glyph_uses": glyph_uses, "callouts_seen": callouts_seen, "discoveries_seen": discoveries_seen}, "  "))
	file.close()
