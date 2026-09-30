extends SceneTree

# A user file cut short mid-save must never be replaced by an empty store: the loader
# keeps the unreadable file as a .bad copy, and saves go through a temp file and rename.

const Codex := preload("res://src/core/codex.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
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

	for d in DirAccess.get_directories_at("user://"):
		if d.begins_with("persist-trunc-%d" % OS.get_process_id()):
			var full := "user://" + d
			for n in DirAccess.get_files_at(full):
				DirAccess.remove_absolute(full.path_join(n))
			DirAccess.remove_absolute(full)

	print("persistence_truncation_test: %s (%d fails)" % ["FAIL" if _fails > 0 else "PASS", _fails])
	quit(1 if _fails > 0 else 0)
