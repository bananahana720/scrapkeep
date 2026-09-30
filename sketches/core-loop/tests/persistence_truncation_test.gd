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

	for d in DirAccess.get_directories_at("user://"):
		if d.begins_with("persist-trunc-%d" % OS.get_process_id()):
			var full := "user://" + d
			for n in DirAccess.get_files_at(full):
				DirAccess.remove_absolute(full.path_join(n))
			DirAccess.remove_absolute(full)

	print("persistence_truncation_test: %s (%d fails)" % ["FAIL" if _fails > 0 else "PASS", _fails])
	quit(1 if _fails > 0 else 0)
