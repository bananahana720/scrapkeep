extends SceneTree

# A user file cut short mid-save must never be replaced by an empty store: the loader
# keeps the unreadable file as a .bad copy, and saves go through a temp file and rename.

const Codex := preload("res://src/core/codex.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const SafeStore := preload("res://src/core/safe_store.gd")
const Ceremony := preload("res://src/presentation/reward_ceremony.gd")

var _fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _bad_copies(dir: String, file: String) -> Array:
	var out := []
	for name in DirAccess.get_files_at(dir):
		if name.begins_with(file + ".bad"):
			out.append(dir.path_join(name))
	return out


func _expect_kept(dir: String, file: String, original: String, label: String) -> void:
	var bad := _bad_copies(dir, file)
	_check(bad.size() == 1, "%s: one .bad copy kept (got %d)" % [label, bad.size()])
	if bad.size() == 1:
		_check(FileAccess.get_file_as_string(bad[0]) == original, "%s: .bad holds the original bytes" % label)
	_check(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file))) != null, "%s: rewritten file parses" % label)
	for name in DirAccess.get_files_at(dir):
		_check(not name.ends_with(".tmp"), "%s: no leftover temp file (%s)" % [label, name])

# A directory nothing can be renamed in, so a load cannot move its file aside. Mode 555 does
# it for a normal user; root ignores the mode, so the immutable flag does it there (chattr
# refuses for a normal user and the mode stands alone).
func _lock_dir(real: String) -> void:
	OS.execute("chmod", ["555", real])
	OS.execute("chattr", ["+i", real])


func _unlock_dir(real: String) -> void:
	OS.execute("chattr", ["-i", real])
	OS.execute("chmod", ["755", real])

var _case_n := 0


func _fresh_dir(text_file: String, text: String) -> String:
	_case_n += 1
	var dir := "user://persist-trunc-%d-case%d" % [OS.get_process_id(), _case_n]
	DirAccess.make_dir_recursive_absolute(dir)
	_write(dir.path_join(text_file), text)
	return dir


func _wrong_typed() -> void:
	var codex_cases := [
		'{"discovered": null, "found": ["ice bridge"], "found_categories": {"ice bridge": "world"}}',
		'{"discovered": ["a"], "found": null, "found_categories": {"a": "world"}}',
		'{"discovered": "ab", "found": ["x"]}',
		'{"discovered": ["a"], "found": ["x"], "found_categories": ["x"]}',
		'{"discovered": [1], "found": ["x"]}',
	]
	for i in codex_cases.size():
		var dir := _fresh_dir("codex.json", codex_cases[i])
		var events = GameEvents.new()
		var codex = Codex.new()
		codex.setup(events, null, null, dir)
		codex.mark_discovered("parting_shot")
		_expect_kept(dir, "codex.json", codex_cases[i], "codex wrong-typed %d" % i)
		events.free()
		codex.free()

	var settings_cases := [
		'{"volumes": {"music": [1], "sfx": 0.4}, "comfort": {"shake": 0.3}}',
		'{"volumes": {"music": "loud"}, "comfort": {"shake": 0.3}}',
		'{"volumes": {"music": 0.2}, "comfort": {"shake": null}}',
		'{"volumes": [0.2], "comfort": {"shake": 0.3}}',
		'{"volumes": {"music": 0.2}, "bindings": {"cl_jump": 5}}',
	]
	for i in settings_cases.size():
		var dir := _fresh_dir("settings.json", settings_cases[i])
		var settings = SettingsStore.new(dir)
		settings.set_volume("music", 0.9)
		_expect_kept(dir, "settings.json", settings_cases[i], "settings wrong-typed %d" % i)

	var ui_cases := [
		'{"glyph_uses": {"jump": [1], "dash": 3}, "callouts_seen": ["a"]}',
		'{"glyph_uses": {"dash": 3}, "callouts_seen": null}',
		'{"glyph_uses": {"dash": 3}, "discoveries_seen": [1, null]}',
		'{"glyph_uses": [3], "callouts_seen": ["a"]}',
	]
	for i in ui_cases.size():
		var dir := _fresh_dir("ui-profile.json", ui_cases[i])
		var profile = UiProfile.new(dir)
		profile.mark_discovered("x")
		_expect_kept(dir, "ui-profile.json", ui_cases[i], "ui_profile wrong-typed %d" % i)

	var finds_cases := ['[null, 1, [2], {"a": 1}, "shell"]', '["shell", 1]', '["shell", null]', '["shell", {"a": 1}]']
	for i in finds_cases.size():
		var dir := _fresh_dir(Ceremony.SEEN_FILE, finds_cases[i])
		var ceremony = Ceremony.new()
		ceremony._seen_path = dir.path_join(Ceremony.SEEN_FILE)
		ceremony._load_seen()
		ceremony._mark_seen("x")
		_expect_kept(dir, Ceremony.SEEN_FILE, finds_cases[i], "reward_ceremony wrong-typed %d" % i)
		ceremony.free()


func _well_formed_kept() -> void:
	var codex_text := '{"discovered": ["a"], "found": ["x"], "found_categories": {"x": "world"}}'
	var dir := _fresh_dir("codex.json", codex_text)
	var events = GameEvents.new()
	var codex = Codex.new()
	codex.setup(events, null, null, dir)
	_check(codex._found == ["x"] and codex._discovered.has("a"), "codex: a well-formed file loads")
	codex.mark_discovered("parting_shot")
	_check(_bad_copies(dir, "codex.json").is_empty(), "codex: a well-formed file is not quarantined")
	events.free()
	codex.free()

	var sdir := _fresh_dir("settings.json", '{"volumes": {"music": 0.2, "sfx": 1}, "comfort": {"shake": 0.3}}')
	var settings = SettingsStore.new(sdir)
	_check(is_equal_approx(float(settings.volumes.get("sfx", -1)), 1.0) and settings.comfort.has("shake"), "settings: a well-formed file loads")
	_check(_bad_copies(sdir, "settings.json").is_empty(), "settings: a well-formed file is not quarantined")

	var udir := _fresh_dir("ui-profile.json", '{"glyph_uses": {"jump": 2}, "callouts_seen": ["a"], "discoveries_seen": ["b"]}')
	var profile = UiProfile.new(udir)
	_check(profile.uses("jump") == 2 and profile.seen("a") and profile.discovered("b"), "ui_profile: a well-formed file loads")
	profile.mark_seen("c")
	_check(_bad_copies(udir, "ui-profile.json").is_empty(), "ui_profile: a well-formed file is not quarantined")


func _write_stays_atomic() -> void:
	var dir := _fresh_dir("keep.json", '{"good": true}')
	var path := dir.path_join("keep.json")
	DirAccess.make_dir_recursive_absolute(SafeStore.tmp_path(path))
	var err := SafeStore.write_atomic(path, '{"good": false, "padding": "xxxxxxxxxxxxxxxx"}')
	_check(err != OK, "write_atomic reports an error when the temp file cannot be made")
	_check(FileAccess.get_file_as_string(path) == '{"good": true}', "write_atomic leaves the target whole when the temp file cannot be made")
	DirAccess.remove_absolute(SafeStore.tmp_path(path))

	var other := dir.path_join("other.json")
	_check(SafeStore.write_atomic(other, "[1]") == OK and FileAccess.get_file_as_string(other) == "[1]", "write_atomic writes a new file")
	_check(not FileAccess.file_exists(SafeStore.tmp_path(other)), "write_atomic leaves no temp file after a save")
	_check(SafeStore.tmp_path(other) != other + ".tmp", "the temp name is per-process")


func _holds_bytes(dir: String, file: String, original: String) -> bool:
	for copy in _bad_copies(dir, file):
		if FileAccess.get_file_as_string(copy) == original:
			return true
	return false


func _store_cases() -> Array:
	return [
		{"label": "codex", "file": "codex.json", "make": func(dir: String) -> Variant:
			var events = GameEvents.new()
			var codex = Codex.new()
			codex.setup(events, null, null, dir)
			return [codex, events],
		"save": func(store: Variant) -> void: store[0].mark_discovered("parting_shot"),
		"error": func(store: Variant) -> String: return store[0].last_error,
		"free": func(store: Variant) -> void:
			store[1].free()
			store[0].free()},
		{"label": "settings_store", "file": "settings.json", "make": func(dir: String) -> Variant: return SettingsStore.new(dir),
		"save": func(store: Variant) -> void: store.set_volume("music", 0.5),
		"error": func(store: Variant) -> String: return store.last_error,
		"free": func(_store: Variant) -> void: pass},
		{"label": "ui_profile", "file": "ui-profile.json", "make": func(dir: String) -> Variant: return UiProfile.new(dir),
		"save": func(store: Variant) -> void: store.mark_discovered("x"),
		"error": func(store: Variant) -> String: return store.last_error,
		"free": func(_store: Variant) -> void: pass},
		{"label": "reward_ceremony", "file": Ceremony.SEEN_FILE, "make": func(dir: String) -> Variant:
			var ceremony = Ceremony.new()
			ceremony._seen_path = dir.path_join(Ceremony.SEEN_FILE)
			ceremony._load_seen()
			return ceremony,
		"save": func(store: Variant) -> void: store._mark_seen("x"),
		"error": func(store: Variant) -> String: return store.last_error,
		"free": func(store: Variant) -> void: store.free()},
	]


func _directory_at_bad() -> void:
	for c in _store_cases():
		var dir := _fresh_dir(c["file"], "{corrupt")
		DirAccess.make_dir_recursive_absolute(dir.path_join(c["file"] + ".bad"))
		var store = c["make"].call(dir)
		c["save"].call(store)
		_check(_holds_bytes(dir, c["file"], "{corrupt"), "%s: a directory at .bad does not cost the unreadable file" % c["label"])
		c["free"].call(store)


func _unmovable_file_survives() -> void:
	for c in _store_cases():
		var dir := _fresh_dir(c["file"], "{corrupt")
		var path := dir.path_join(c["file"])
		var real := ProjectSettings.globalize_path(dir)
		_lock_dir(real)
		var store = c["make"].call(dir)
		_unlock_dir(real)
		c["save"].call(store)
		_check(FileAccess.get_file_as_string(path) == "{corrupt", "%s: a file that could not be moved aside is not overwritten" % c["label"])
		_check(not String(c["error"].call(store)).is_empty(), "%s: the refused save is recorded" % c["label"])
		c["free"].call(store)


func _healthy_reload_cases() -> Array:
	return [
		{"label": "codex", "file": "codex.json", "healthy": '{"discovered": ["a"], "found": [], "found_categories": {}}', "marker": "parting_shot",
		"reload": func(store: Variant) -> void: store[0]._load()},
		{"label": "settings_store", "file": "settings.json", "healthy": '{"volumes": {"music": 0.2}, "comfort": {}}', "marker": "0.5",
		"reload": func(store: Variant) -> void: store.load_saved()},
		{"label": "ui_profile", "file": "ui-profile.json", "healthy": '{"glyph_uses": {}, "callouts_seen": ["a"], "discoveries_seen": []}', "marker": "\"x\"",
		"reload": func(store: Variant) -> void: store.load_saved()},
		{"label": "reward_ceremony", "file": Ceremony.SEEN_FILE, "healthy": '["a"]', "marker": "\"x\"",
		"reload": func(store: Variant) -> void: store._load_seen()},
	]


func _healthy_reload_unblocks() -> void:
	var stores := {}
	for c in _store_cases():
		stores[c["label"]] = c
	for h in _healthy_reload_cases():
		var c: Dictionary = stores[h["label"]]
		var dir := _fresh_dir(h["file"], "{corrupt")
		var path := dir.path_join(h["file"])
		var real := ProjectSettings.globalize_path(dir)
		_lock_dir(real)
		var store = c["make"].call(dir)
		_unlock_dir(real)
		_write(path, h["healthy"])
		h["reload"].call(store)
		c["save"].call(store)
		_check(FileAccess.get_file_as_string(path).contains(h["marker"]), "%s: a load that reads a healthy file lifts the save block" % h["label"])
		c["free"].call(store)


func _blocked_save_after_merge() -> void:
	var dir := "user://persist-trunc-%d-merge-block" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("ui-profile.json")
	var profile = UiProfile.new(dir)
	_write(path, "{corrupt")
	var real := ProjectSettings.globalize_path(dir)
	_lock_dir(real)
	profile.mark_discovered("x")
	_unlock_dir(real)
	_check(FileAccess.get_file_as_string(path) == "{corrupt", "ui_profile: the unreadable file is untouched by a save that finds it mid-merge")
	_check(profile.last_error.contains("could not be moved aside"), "ui_profile: a save blocked by its merge records the block (got \"%s\")" % profile.last_error)


func _save_error_survives_log_error() -> void:
	var dir := "user://persist-trunc-%d-nope/missing" % OS.get_process_id()
	var events = GameEvents.new()
	var codex = Codex.new()
	codex.setup(events, null, null, dir)
	codex.mark_discovered("parting_shot")
	_check(codex.last_error.contains("codex.json"), "codex: the save failure stays in last_error after the log append fails (got \"%s\")" % codex.last_error)
	_check(str(codex.get("log_error")).contains("codex-log.ndjson"), "codex: the log failure is kept as well")
	events.free()
	codex.free()


func _reload_replaces() -> void:
	var cases := [
		{"label": "codex", "file": "codex.json", "text": '{"discovered": ["a"], "found": ["f1"], "found_categories": {"f1": "world"}}',
		"make": func(dir: String) -> Variant:
			var events = GameEvents.new()
			var codex = Codex.new()
			codex.setup(events, null, null, dir)
			return [codex, events],
		"reload": func(store: Variant) -> void: store[0]._load(),
		"state": func(store: Variant) -> Array: return [store[0].found(), store[0].discovered()],
		"want": [["f1"], ["a"]],
		"free": func(store: Variant) -> void:
			store[1].free()
			store[0].free()},
		{"label": "settings_store", "file": "settings.json", "text": '{"volumes": {"music": 0.2}, "comfort": {"shake": 0.3}}',
		"make": func(dir: String) -> Variant: return SettingsStore.new(dir),
		"reload": func(store: Variant) -> void: store.load_saved(),
		"state": func(store: Variant) -> Array: return [store.volumes.keys(), store.comfort.keys()],
		"want": [["music"], ["shake"]],
		"free": func(_store: Variant) -> void: pass},
		{"label": "ui_profile", "file": "ui-profile.json", "text": '{"glyph_uses": {"jump": 2}, "callouts_seen": ["a"], "discoveries_seen": ["b"]}',
		"make": func(dir: String) -> Variant: return UiProfile.new(dir),
		"reload": func(store: Variant) -> void: store.load_saved(),
		"state": func(store: Variant) -> Array: return [store.callouts_seen, store.discoveries_seen, store.uses("jump")],
		"want": [["a"], ["b"], 2],
		"free": func(_store: Variant) -> void: pass},
		{"label": "reward_ceremony", "file": Ceremony.SEEN_FILE, "text": '["a"]',
		"make": func(dir: String) -> Variant:
			var ceremony = Ceremony.new()
			ceremony._seen_path = dir.path_join(Ceremony.SEEN_FILE)
			ceremony._load_seen()
			return ceremony,
		"reload": func(store: Variant) -> void: store._load_seen(),
		"state": func(store: Variant) -> Array: return [store._seen.keys()],
		"want": [["a"]],
		"free": func(store: Variant) -> void: store.free()},
	]
	for c in cases:
		var dir := _fresh_dir(c["file"], c["text"])
		var store = c["make"].call(dir)
		c["reload"].call(store)
		c["reload"].call(store)
		_check(c["state"].call(store) == c["want"], "%s: a reload replaces the in-memory state (got %s)" % [c["label"], str(c["state"].call(store))])
		c["free"].call(store)

	var dir := _fresh_dir("codex.json", cases[0]["text"])
	var store = cases[0]["make"].call(dir)
	store[0]._load()
	store[0].mark_discovered("parting_shot")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("codex.json")))
	_check(saved != null and saved["found"] == ["f1"], "codex: the save after a reload writes no duplicate")
	cases[0]["free"].call(store)


func _rm_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_rm_tree(path.path_join(sub))
	for n in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(n))
	DirAccess.remove_absolute(path)


func _initialize() -> void:
	var base := "user://persist-trunc-%d" % OS.get_process_id()
	var cases := {
		"codex.json": '{\n  "discovered": ["wrecking_ball", "counter_ram"],\n  "found": ["ice bri',
		"ui-profile.json": '{\n  "callouts_seen": ["jump", "dash"],\n  "discoveries_seen": ["shell_ret',
		"settings.json": '{\n  "volumes": {"music": 0.2},\n  "comfort": {"shake": 0.',
		Ceremony.SEEN_FILE: '["wrecking_ball", "counter_',
	}
	for file in cases:
		var dir: String = base + "-" + String(file).get_basename()
		DirAccess.make_dir_recursive_absolute(dir)
		_write(dir.path_join(file), cases[file])

	var cdir: String = base + "-codex"
	var events = GameEvents.new()
	var codex = Codex.new()
	codex.setup(events, null, null, cdir)
	codex.mark_discovered("parting_shot")
	_expect_kept(cdir, "codex.json", cases["codex.json"], "codex")
	events.free()
	codex.free()

	var udir: String = base + "-ui-profile"
	var profile = UiProfile.new(udir)
	profile.mark_discovered("x")
	_expect_kept(udir, "ui-profile.json", cases["ui-profile.json"], "ui_profile")

	var sdir: String = base + "-settings"
	var settings = SettingsStore.new(sdir)
	settings.set_volume("music", 0.5)
	_expect_kept(sdir, "settings.json", cases["settings.json"], "settings_store")

	var rdir: String = base + "-reward-finds"
	var ceremony = Ceremony.new()
	ceremony._seen_path = rdir.path_join(Ceremony.SEEN_FILE)
	ceremony._load_seen()
	ceremony._mark_seen("x")
	_expect_kept(rdir, Ceremony.SEEN_FILE, cases[Ceremony.SEEN_FILE], "reward_ceremony")
	ceremony.free()

	_wrong_typed()
	_well_formed_kept()
	_write_stays_atomic()
	_directory_at_bad()
	_unmovable_file_survives()
	_healthy_reload_unblocks()
	_blocked_save_after_merge()
	_save_error_survives_log_error()
	_reload_replaces()

	for d in DirAccess.get_directories_at("user://"):
		if d.begins_with("persist-trunc-%d" % OS.get_process_id()):
			_rm_tree("user://" + d)

	print("persistence_truncation_test: %s (%d fails)" % ["FAIL" if _fails > 0 else "PASS", _fails])
	quit(1 if _fails > 0 else 0)
