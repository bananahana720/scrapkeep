extends RefCounted

const SettingsStore := preload("res://src/ui/settings_store.gd")
const Bindings := preload("res://src/core/bindings.gd")

# Bindings ride in settings.json beside volumes and comfort: absent when empty, kept for
# actions this build does not know, and read back through the codec.


func _dir(name: String) -> String:
	var dir := "user://settings-bindings-%d-%s" % [OS.get_process_id(), name]
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _click(index: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = index
	return e


func _cleanup(dir: String) -> void:
	for n in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(n))
	DirAccess.remove_absolute(dir)


func _text(dir: String) -> String:
	return FileAccess.get_file_as_string(dir.path_join(SettingsStore.FILE))


func run(t) -> void:
	# S2-1: an older file has no bindings and saves none.
	var a := _dir("old")
	_write(a.path_join(SettingsStore.FILE), '{"volumes": {"music": 0.2}, "comfort": {"shake": 0.3}}')
	var old = SettingsStore.new(a)
	t.check("S2-1: a file without bindings loads with none", old.bindings.is_empty() and old.binding("cl_jump") == "", "bindings %s" % [old.bindings])
	old.set_volume("music", 0.4)
	t.check("S2-1: it saves with no bindings key", not JSON.parse_string(_text(a)).has("bindings"), _text(a))
	_cleanup(a)

	# S2-2: a binding survives a fresh store; clearing it drops the key.
	var b := _dir("roundtrip")
	var store = SettingsStore.new(b)
	store.set_binding("cl_jump", [_key(KEY_G)])
	var fresh = SettingsStore.new(b)
	var events: Array = fresh.binding_events("cl_jump")
	t.check("S2-2: a fresh store returns one G key event", events.size() == 1 and events[0] is InputEventKey and events[0].physical_keycode == KEY_G, "events %s text %s" % [events, _text(b)])
	t.check("S2-2: the file holds the bindings key", JSON.parse_string(_text(b)).has("bindings"), _text(b))
	fresh.clear_binding("cl_jump")
	t.check("S2-2: clearing leaves no bindings key", not JSON.parse_string(_text(b)).has("bindings"), _text(b))
	_cleanup(b)

	# S2-3: the codec round-trips every default.
	var all_ok := true
	var bad := ""
	var actions := Bindings.actions()
	for action in actions:
		var record: Dictionary = actions[action]
		var events_in := []
		for code in record.get("keys", []):
			events_in.append(_key(code))
		if record.has("button"):
			events_in.append(_click(record["button"]))
		if events_in.is_empty():
			continue
		var out := Bindings.decode(Bindings.encode(events_in))
		var same := out.size() == events_in.size()
		if same:
			for i in out.size():
				if out[i].get_class() != events_in[i].get_class():
					same = false
				elif out[i] is InputEventKey and out[i].physical_keycode != events_in[i].physical_keycode:
					same = false
				elif out[i] is InputEventMouseButton and out[i].button_index != events_in[i].button_index:
					same = false
		if not same:
			all_ok = false
			bad = action
	t.check("S2-3: decode(encode(x)) round-trips every default key and button action", all_ok, "failed at %s" % bad)

	var skipped := Bindings.decode("key:G,key:NoSuchKey,mouse:x,pad:A")
	t.check("S2-3: bad tokens are skipped, good ones kept", skipped.size() == 1 and skipped[0].physical_keycode == KEY_G, "got %d events" % skipped.size())
	Bindings.decode("key:NoSuchKey")
	t.check("S2-3: a bad token warns once", Bindings._warned_tokens.has("key:NoSuchKey") and Bindings._warned_tokens.size() >= 1, "warned %s" % [Bindings._warned_tokens])

	var c := _dir("unknown")
	var original := '{"volumes": {}, "comfort": {}, "bindings": {"cl_future": "key:Q"}}'
	_write(c.path_join(SettingsStore.FILE), original)
	var keeper = SettingsStore.new(c)
	t.check("S2-3: an unknown action decodes to nothing", keeper.binding_events("cl_future").is_empty(), "")
	keeper.set_volume("music", 0.5)
	var saved = JSON.parse_string(_text(c))
	t.check("S2-3: an unknown action's entry survives a load and a save", saved.get("bindings", {}).get("cl_future", "") == "key:Q", _text(c))
	_cleanup(c)
