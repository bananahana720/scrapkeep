extends RefCounted


const SafeStore := preload("res://src/core/safe_store.gd")

const FILE := "ui-profile.json"

var path := ""
var glyph_uses := {}
var callouts_seen: Array = []
var discoveries_seen: Array = []
var last_error := ""
var _save_blocked := false


func _init(storage_dir := "user://") -> void:
	path = storage_dir.path_join(FILE)
	load_saved()


func load_saved() -> void:
	glyph_uses = {}
	callouts_seen = []
	discoveries_seen = []
	if not FileAccess.file_exists(path):
		return
	var parsed = _read_disk()
	if parsed == null:
		return
	var uses: Dictionary = parsed.get("glyph_uses", {})
	for action in uses:
		glyph_uses[String(action)] = int(uses[action])
	for id in parsed.get("callouts_seen", []):
		callouts_seen.append(String(id))
	for id in parsed.get("discoveries_seen", []):
		discoveries_seen.append(String(id))


func _read_disk() -> Variant:
	var parsed = SafeStore.parse(FileAccess.get_file_as_string(path), TYPE_DICTIONARY, {"glyph_uses": SafeStore.NUMBERS, "callouts_seen": SafeStore.STRINGS, "discoveries_seen": SafeStore.STRINGS})
	if parsed == null:
		var kept := SafeStore.quarantine(path)
		if kept.is_empty():
			_save_blocked = true
			last_error = "unreadable %s and could not be moved aside; not saving this session" % path
		else:
			last_error = "unreadable %s; kept as %s" % [path, kept]
	else:
		_save_blocked = false
	return parsed


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


func _merge_disk() -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed = _read_disk()
	if parsed == null:
		return
	for id in parsed.get("callouts_seen", []):
		if not String(id) in callouts_seen:
			callouts_seen.append(String(id))
	for id in parsed.get("discoveries_seen", []):
		if not String(id) in discoveries_seen:
			discoveries_seen.append(String(id))
	var uses: Dictionary = parsed.get("glyph_uses", {})
	for action in uses:
		glyph_uses[String(action)] = maxi(int(uses[action]), int(glyph_uses.get(String(action), 0)))


func save() -> void:
	if _save_blocked:
		return
	_merge_disk()
	if _save_blocked:
		return
	var err := SafeStore.write_atomic(path, JSON.stringify({"glyph_uses": glyph_uses, "callouts_seen": callouts_seen, "discoveries_seen": discoveries_seen}, "  "))
	if err != OK:
		last_error = error_string(err)
