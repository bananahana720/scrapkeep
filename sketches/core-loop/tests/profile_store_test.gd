extends SceneTree

const T := preload("res://tests/support/t.gd")
const Profile := preload("res://src/core/profile.gd")
const SafeStore := preload("res://src/core/safe_store.gd")

const FIXTURES := "res://tests/fixtures/profile/"
const DIR := "user://profile_store_test/"

var _t := T.new("profile_store_test")
var _n := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_round_trip()
	_rule_1_missing()
	_rule_2_unreadable()
	_rule_3_newer()
	_rule_4_older()
	_rule_5_unknown_kept()
	_rule_6_wrong_type()
	_interrupted_save()
	_earn_and_idempotence()
	_fixtures()
	_source_is_clean()
	quit(_t.verdict())


func _fresh_path() -> String:
	_n += 1
	return "%sp%d.json" % [DIR, _n]


func _copy_fixture(name: String) -> String:
	var dest := _fresh_path()
	_write(dest, FileAccess.get_file_as_bytes(FIXTURES + name))
	return dest


func _write(file_path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _bytes(file_path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(file_path)


func _round_trip() -> void:
	var path := _fresh_path()
	var p := Profile.new(path)
	p.unlock_pilot("runner_gunner")
	p.unlock_world("orchard")
	p.unlock_cosmetic("paint_verdigris")
	p.earn("rout_brindle", 1790000000.0)
	p.equip("pylon_engineer", "paint", "paint_verdigris")
	p.add_stat("runs", 2.0)
	p.add_stat("runs")
	p.set_stat("wins", 1.0)
	p.set_last_pilot("pylon_engineer")
	_t.check("A2-1 first save", p.save() and p.generation() == 1, "generation %d" % p.generation())
	_t.check("A2-1 second save", p.save() and p.generation() == 2, "generation %d" % p.generation())
	var q := Profile.new(path)
	_t.check("A2-1 load", q.load_profile(), q.last_error)
	_t.eq("A2-1 generation", q.generation(), 2)
	_t.check("A2-1 pilot", q.has_pilot("runner_gunner"))
	_t.check("A2-1 world", q.has_world("orchard"))
	_t.check("A2-1 cosmetic", q.has_cosmetic("paint_verdigris"))
	_t.check("A2-1 achievement", q.earned("rout_brindle"))
	_t.eq("A2-1 equipped", q.equipped("pylon_engineer", "paint"), "paint_verdigris")
	_t.near("A2-1 runs", q.stat("runs"), 3.0)
	_t.near("A2-1 wins", q.stat("wins"), 1.0)
	_t.eq("A2-1 last pilot", q.last_pilot(), "pylon_engineer")
	_t.check("A2-1 save after load", q.save() and q.generation() == 3, "generation %d" % q.generation())


func _rule_1_missing() -> void:
	var path := _fresh_path()
	var p := Profile.new(path)
	_t.check("A2-2 rule 1 loads", p.load_profile())
	_t.check("A2-2 rule 1 can save", p.can_save)
	_t.check("A2-2 rule 1 writes nothing", not FileAccess.file_exists(path))
	_t.eq("A2-2 rule 1 fresh", p.generation(), 0)


func _rule_2_unreadable() -> void:
	var path := _copy_fixture("broken.json")
	var original := _bytes(path)
	var p := Profile.new(path)
	_t.check("A2-2 rule 2 not loaded", not p.load_profile())
	_t.check("A2-2 rule 2 can save", p.can_save)
	_t.check("A2-2 rule 2 quarantined", not FileAccess.file_exists(path) and _bytes(path + ".bad") == original)
	_t.check("A2-2 rule 2 says why", p.last_error.contains("unreadable"), p.last_error)
	_t.check("A2-2 rule 2 saves fresh", p.save() and Profile.new(path).load_profile())


func _rule_3_newer() -> void:
	var path := _copy_fixture("future.json")
	var before := _bytes(path)
	var p := Profile.new(path)
	p.load_profile()
	_t.check("A2-2 rule 3 cannot save", not p.can_save)
	_t.check("A2-2 rule 3 says why", not p.last_error.is_empty(), p.last_error)
	_t.check("A2-2 rule 3 contents not loaded", not p.has_pilot("runner_gunner") and p.generation() == 0)
	p.unlock_pilot("runner_gunner")
	_t.check("A2-2 rule 3 save refused", not p.save())
	_t.check("A2-2 rule 3 bytes identical", _bytes(path) == before)


func _rule_4_older() -> void:
	var path := _copy_fixture("v0.json")
	var original := _bytes(path)
	var p := Profile.new(path)
	_t.check("A2-2 rule 4 loads", p.load_profile(), p.last_error)
	_t.check("A2-2 rule 4 migrated values", p.has_pilot("runner_gunner") and p.earned("rout_brindle") and p.stat("runs") == 3.0 and p.last_pilot() == "runner_gunner")
	_t.check("A2-2 rule 4 defaults added", not p.has_world("orchard") and p.equipped("pylon_engineer", "paint") == "")
	_t.check("A2-2 rule 4 no backup before save", not FileAccess.file_exists(path + ".v0"))
	_t.check("A2-2 rule 4 saves", p.save())
	_t.check("A2-2 rule 4 backup holds original", _bytes(path + ".v0") == original)
	var q := Profile.new(path)
	q.load_profile()
	_t.check("A2-2 rule 4 file is schema 1", q.has_pilot("runner_gunner") and q.generation() == 1 and not FileAccess.file_exists(path + ".v1"))
	_t.check("A2-2 rule 4 backup kept once", q.save() and _bytes(path + ".v0") == original)


func _rule_5_unknown_kept() -> void:
	var path := _fresh_path()
	var doc := {
		"schema": Profile.SCHEMA, "generation": 1, "pilots": ["mystery_pilot"], "achievements": {"future_deed": 5.0},
		"equipped": {"mystery_pilot/hat": "hat_x"}, "stats": {"odd_stat": 2.0}, "from_newer_build": {"a": "kept"},
	}
	_write(path, JSON.stringify(doc).to_utf8_buffer())
	var p := Profile.new(path)
	p.load_profile()
	p.unlock_pilot("runner_gunner")
	p.save()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	_t.check("A2-2 rule 5 top-level key", saved.get("from_newer_build", {}).get("a") == "kept")
	_t.check("A2-2 rule 5 unknown achievement", saved["achievements"].get("future_deed") == 5.0)
	_t.check("A2-2 rule 5 unknown list id", saved["pilots"] == ["mystery_pilot", "runner_gunner"])
	_t.check("A2-2 rule 5 unknown map ids", saved["equipped"].get("mystery_pilot/hat") == "hat_x" and saved["stats"].get("odd_stat") == 2.0)


func _rule_6_wrong_type() -> void:
	var path := _copy_fixture("wrong_type.json")
	var p := Profile.new(path)
	_t.check("A2-2 rule 6 not loaded", not p.load_profile())
	_t.check("A2-2 rule 6 quarantined", not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".bad"))
	_t.check("A2-2 rule 6 can save", p.can_save and not p.last_error.is_empty(), p.last_error)
	var text_path := _fresh_path()
	_write(text_path, '{"schema": 1, "last_pilot": 4}'.to_utf8_buffer())
	var q := Profile.new(text_path)
	_t.check("A2-2 rule 6 last_pilot type", not q.load_profile() and FileAccess.file_exists(text_path + ".bad"))


func _interrupted_save() -> void:
	var path := _fresh_path()
	var p := Profile.new(path)
	p.unlock_pilot("runner_gunner")
	p.save()
	_write(SafeStore.tmp_path(path), "{half a sav".to_utf8_buffer())
	var q := Profile.new(path)
	_t.check("A2-3 good file loads beside stale temp", q.load_profile() and q.has_pilot("runner_gunner"), q.last_error)
	q.unlock_world("orchard")
	_t.check("A2-3 next save succeeds", q.save(), q.last_error)
	var r := Profile.new(path)
	r.load_profile()
	_t.check("A2-3 data survives", r.has_pilot("runner_gunner") and r.has_world("orchard") and r.generation() == 2)


func _earn_and_idempotence() -> void:
	var p := Profile.new(_fresh_path())
	_t.check("A2-4 first earn", p.earn("rout_brindle", 10.0))
	_t.check("A2-4 second earn", not p.earn("rout_brindle", 20.0))
	_t.check("A2-4 first time kept", p.earn("other", 1.0) and p._doc["achievements"]["rout_brindle"] == 10.0)
	for i in 3:
		p.unlock_pilot("runner_gunner")
		p.unlock_world("orchard")
		p.unlock_cosmetic("paint_verdigris")
		p.equip("runner_gunner", "paint", "paint_verdigris")
	_t.check("A2-4 lists do not grow", p._doc["pilots"].size() == 1 and p._doc["worlds"].size() == 1 and p._doc["cosmetics"].size() == 1 and p._doc["equipped"].size() == 1)


func _fixtures() -> void:
	var names := []
	for file_name in DirAccess.get_files_at(FIXTURES):
		if file_name.ends_with(".json"):
			names.append(file_name)
	_t.check("A2-5 at least 5 fixtures", names.size() >= 5, "%d found" % names.size())
	for file_name in names:
		var path := _copy_fixture(file_name)
		var p := Profile.new(path)
		var loaded := p.load_profile()
		if file_name == "broken.json" or file_name == "wrong_type.json":
			_t.check("A2-5 %s is refused and kept" % file_name, not loaded and p.can_save and FileAccess.file_exists(path + ".bad"))
		elif file_name == "future.json":
			_t.check("A2-5 %s plays read-only" % file_name, not loaded and not p.can_save)
		else:
			_t.check("A2-5 %s loads" % file_name, loaded and p.can_save, p.last_error)


func _source_is_clean() -> void:
	var source := FileAccess.get_file_as_string("res://src/core/profile.gd")
	var found := []
	for word in ["Node", "event_bus", "EventBus", "class_def", "ClassDef", "achievements.gd", "cosmetics.gd"]:
		if source.contains(word):
			found.append(word)
	var loads := []
	for line in source.split("\n"):
		if line.contains("res://") and not line.contains("res://src/core/safe_store.gd"):
			loads.append(line)
	_t.check("A2-6 no banned references", found.is_empty(), str(found))
	_t.check("A2-6 only safe_store is loaded", loads.is_empty(), str(loads))
	_t.check("A2-6 loads headless", load("res://src/core/profile.gd") != null)
