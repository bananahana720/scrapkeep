extends SceneTree

const T := preload("res://tests/support/t.gd")
const Profile := preload("res://src/core/profile.gd")
const SafeStore := preload("res://src/core/safe_store.gd")

const FIXTURES := "res://tests/fixtures/profile/"
const DIR := "user://profile_store_test/"
# 2026-10-17 w16: user:// is shared by every worktree of this sketch, so each run writes under its
# own process folder; a sibling run's start-of-run clear can no longer delete this run's files.
var _dir := "%s%d/" % [DIR, OS.get_process_id()]
# Re-pinned 2026-10-10 (w13 B5, CUSTOMIZE.md section 5): schema 4 adds the seen list.
const KNOWN_FIELDS := ["schema", "generation", "pilots", "worlds", "achievements", "cosmetics", "equipped", "stats", "last_pilot", "settled", "companion", "rewards_settled", "seen"]
const V1_FIXTURE := "res://tests/fixtures/profile_v1.json"
const V3_FIXTURE := "res://tests/fixtures/profile_v3.json"

var _t := T.new("profile_store_test")
var _n := 0


func _initialize() -> void:
	_clear_dir()
	DirAccess.make_dir_recursive_absolute(_dir)
	_round_trip()
	_rule_1_missing()
	_rule_2_unreadable()
	_rule_3_newer()
	_rule_4_older()
	_rule_5_unknown_kept()
	_rule_6_wrong_type()
	_rule_6_every_known_field()
	_interrupted_save()
	_earn_and_idempotence()
	_save_needs_a_load()
	_disable_saving()
	_two_stores_one_path()
	_merge_is_pure()
	_second_backup_kept()
	_numbers_round_trip()
	_errors_name_their_cause()
	_fixtures()
	_v1_migrates_to_2()
	_companion_and_settled_round_trip()
	_schema_3_never_saves()
	_v3_migrates_to_4()
	_v3_seen_already_present()
	_seen_merge()
	_retired_cosmetic_swapped()
	_source_is_clean()
	_clear_dir()
	quit(_t.verdict())


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(_dir):
		return
	# The failed-write check plants a folder where a profile file goes; remove folders too, or a
	# leftover folder at pN.json blocks a later run's successful save at the same path.
	for sub in DirAccess.get_directories_at(_dir):
		DirAccess.remove_absolute(_dir + sub)
	for file_name in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir + file_name)
	DirAccess.remove_absolute(_dir)
	DirAccess.remove_absolute(DIR)


# The shipped future fixture was schema 2; this build reads 2, so the future file is schema 3.
func _future_bytes() -> PackedByteArray:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "future.json"))
	doc["schema"] = Profile.SCHEMA + 1
	return JSON.stringify(doc).to_utf8_buffer()


func _fresh_path() -> String:
	_n += 1
	return "%sp%d.json" % [_dir, _n]


func _copy_fixture(name: String) -> String:
	var dest := _fresh_path()
	_write(dest, _future_bytes() if name == "future.json" else FileAccess.get_file_as_bytes(FIXTURES + name))
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
	p.load_profile()
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
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	_t.check("A2-2 rule 4 file is schema 1", saved is Dictionary and saved.get("schema") == Profile.SCHEMA and saved.get("generation") == 1 and not FileAccess.file_exists(path + ".v1"), str(saved))
	_t.check("A2-2 rule 4 resave keeps the same backup", p.save() and _bytes(path + ".v0") == original and not FileAccess.file_exists(path + ".v0.1"))
	var q := Profile.new(path)
	q.load_profile()
	_t.check("A2-2 rule 4 current file needs no backup", q.save() and not FileAccess.file_exists(path + ".v1") and _bytes(path + ".v0") == original and not FileAccess.file_exists(path + ".v0.1"))


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


func _rule_6_every_known_field() -> void:
	var wrong := {
		"schema": "one", "generation": "two", "pilots": "runner_gunner", "worlds": [4], "cosmetics": {"a": "b"},
		"achievements": {"a": "late"}, "equipped": {"a": 4}, "stats": {"a": "many"}, "last_pilot": 4,
		"settled": [3], "companion": [], "rewards_settled": "yes", "seen": [7],
	}
	for field in KNOWN_FIELDS:
		_t.check("F3-4 rule 6 has a case for %s" % field, wrong.has(field))
		var doc := {"schema": Profile.SCHEMA}
		doc[field] = wrong.get(field)
		var path := _fresh_path()
		var bytes := JSON.stringify(doc).to_utf8_buffer()
		_write(path, bytes)
		var p := Profile.new(path)
		_t.check("F3-4 rule 6 %s refused" % field, not p.load_profile() and p.can_save and not p.last_error.is_empty(), p.last_error)
		_t.check("F3-4 rule 6 %s quarantined whole" % field, not FileAccess.file_exists(path) and _bytes(path + ".bad") == bytes)


func _interrupted_save() -> void:
	var path := _fresh_path()
	var p := Profile.new(path)
	p.load_profile()
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
	p.load_profile()
	_t.check("A2-4 first earn", p.earn("rout_brindle", 10.0))
	_t.check("A2-4 second earn", not p.earn("rout_brindle", 20.0))
	_t.check("A2-4 first time kept", p.earn("other", 1.0) and p._doc["achievements"]["rout_brindle"] == 10.0)
	for i in 3:
		p.unlock_pilot("runner_gunner")
		p.unlock_world("orchard")
		p.unlock_cosmetic("paint_verdigris")
		p.equip("runner_gunner", "paint", "paint_verdigris")
	_t.check("A2-4 lists do not grow", p._doc["pilots"].size() == 1 and p._doc["worlds"].size() == 1 and p._doc["cosmetics"].size() == 1 and p._doc["equipped"].size() == 1)


func _save_needs_a_load() -> void:
	var cases := {
		"newer-schema": _future_bytes(),
		"unparseable": _bytes(FIXTURES + "broken.json"),
		"good": JSON.stringify({"schema": 1, "generation": 7, "pilots": ["keeper"]}).to_utf8_buffer(),
	}
	for label in cases:
		var path := _fresh_path()
		_write(path, cases[label])
		var files := DirAccess.get_files_at(_dir).size()
		var p := Profile.new(path)
		p.unlock_pilot("runner_gunner")
		p.earn("rout_brindle", 5.0)
		p.add_stat("runs")
		p.equip("runner_gunner", "paint", "paint_verdigris")
		p.set_last_pilot("runner_gunner")
		_t.check("F3-1 %s: save before load refused" % label, not p.save() and not p.last_error.is_empty(), p.last_error)
		_t.check("F3-1 %s: bytes unchanged" % label, _bytes(path) == cases[label])
		_t.check("F3-1 %s: nothing else written" % label, DirAccess.get_files_at(_dir).size() == files, str(DirAccess.get_files_at(_dir)))
	var fresh := Profile.new(_fresh_path())
	_t.check("F3-1 missing file: save before load refused", not fresh.save() and not FileAccess.file_exists(fresh.path))


func _disable_saving() -> void:
	var path := _fresh_path()
	var p := Profile.new(path)
	p.load_profile()
	_t.check("disable_saving setup saves", p.save(), p.last_error)
	var before := _bytes(path)
	var reason := "sitting profile: this session does not save"
	p.disable_saving(reason)
	_t.check("disable_saving clears can_save", not p.can_save)
	_t.eq("disable_saving records reason", p.last_error, reason)
	p.unlock_pilot("runner_gunner")
	_t.check("disable_saving blocks save", not p.save())
	_t.eq("disable_saving sets refusal error on save", p.last_error, "not saving: " + reason)
	_t.check("disable_saving leaves file untouched", _bytes(path) == before)


func _two_stores_one_path() -> void:
	var path := _fresh_path()
	var seed_store := Profile.new(path)
	seed_store.load_profile()
	seed_store.unlock_pilot("base")
	seed_store.set_stat("runs", 3.0)
	seed_store.save()
	var start := seed_store.generation()
	var a := Profile.new(path)
	var b := Profile.new(path)
	a.load_profile()
	b.load_profile()
	a.unlock_pilot("pilot_x")
	a.earn("shared_deed", 40.0)
	a.set_stat("runs", 9.0)
	a.set_last_pilot("pilot_x")
	_t.check("F3-2 A saves", a.save(), a.last_error)
	b.unlock_cosmetic("paint_y")
	b.earn("shared_deed", 70.0)
	b.set_stat("runs", 5.0)
	b.set_last_pilot("base")
	_t.check("F3-2 B saves", b.save(), b.last_error)
	var c := Profile.new(path)
	c.load_profile()
	_t.check("F3-2 third store has both unlocks", c.has_pilot("pilot_x") and c.has_cosmetic("paint_y") and c.has_pilot("base"))
	_t.eq("F3-2 generation is 2 above start", c.generation(), start + 2)
	_t.check("F3-2 earlier achievement time kept", c._doc["achievements"]["shared_deed"] == 40, str(c._doc["achievements"]))
	_t.near("F3-2 larger stat kept", c.stat("runs"), 9.0)
	_t.eq("F3-2 saver's last pilot wins", c.last_pilot(), "base")
	_t.check("F3-2 B holds the merged result", b.has_pilot("pilot_x") and b.generation() == start + 2)
	var d := Profile.new(path)
	d.load_profile()
	d.unlock_world("orchard")
	var future_bytes := _future_bytes()
	_write(path, future_bytes)
	_t.check("F3-2 newer schema since load refuses", not d.save() and _bytes(path) == future_bytes and d.last_error.contains("newer build"), d.last_error)
	var broken_bytes := _bytes(FIXTURES + "broken.json")
	_write(path, broken_bytes)
	_t.check("F3-2 unreadable since load refuses", not d.save() and _bytes(path) == broken_bytes and d.last_error.contains("cannot be read"), d.last_error)
	_t.check("F3-2 refusal leaves no quarantine", not FileAccess.file_exists(path + ".bad"))
	var late := _fresh_path()
	var e := Profile.new(late)
	e.load_profile()
	e.unlock_pilot("mine")
	_write(late, _bytes(FIXTURES + "v0.json"))
	_t.check("F3-2 older file that appeared since load is merged", e.save() and e.has_pilot("runner_gunner") and e.has_pilot("mine"), e.last_error)
	_t.check("F3-2 and its bytes are kept as a backup", _bytes(late + ".v0") == _bytes(FIXTURES + "v0.json"))
	var f := Profile.new(_fresh_path())
	f.load_profile()
	f.unlock_pilot("f_one")
	f.save()
	f.unlock_pilot("f_two")
	f.save()
	var other := Profile.new(_fresh_path())
	other.load_profile()
	other.unlock_pilot("other_one")
	other.save()
	_write(f.path, _bytes(other.path))
	f.unlock_cosmetic("f_paint")
	_t.check("F3-2 a replaced file behind this store's generation is merged", f.save() and f.has_pilot("other_one") and f.has_pilot("f_two") and f.has_cosmetic("f_paint"),
		"generation %d after the save, other_one %s, error '%s'" % [f.generation(), f.has_pilot("other_one"), f.last_error])


func _merge_is_pure() -> void:
	var ours := {
		"schema": 1, "generation": 4, "pilots": ["a"], "worlds": [], "cosmetics": ["c1"], "achievements": {"x": 10, "y": 50},
		"equipped": {"a/paint": "c1", "a/trail": "t1"}, "stats": {"runs": 2, "wins": 9}, "last_pilot": "a", "shared": "ours",
	}
	var theirs := {
		"schema": 1, "generation": 6, "pilots": ["b", "a"], "worlds": ["w"], "cosmetics": ["c2"], "achievements": {"x": 20, "y": 30, "z": 5},
		"equipped": {"b/paint": "c2", "a/trail": "t9"}, "stats": {"runs": 7, "wins": 1, "kills": 3}, "last_pilot": "b", "shared": "theirs", "only_theirs": {"k": 1},
	}
	var ours_before := ours.duplicate(true)
	var theirs_before := theirs.duplicate(true)
	var merged := Profile.merge(ours, theirs)
	_t.check("F3-2 merge leaves its inputs alone", ours == ours_before and theirs == theirs_before)
	_t.eq("F3-2 merge lists are the union", [merged["pilots"], merged["worlds"], merged["cosmetics"]], [["a", "b"], ["w"], ["c1", "c2"]])
	_t.eq("F3-2 merge keeps the earliest time", merged["achievements"], {"x": 10, "y": 30, "z": 5})
	_t.eq("F3-2 merge keeps the larger stat", merged["stats"], {"runs": 7, "wins": 9, "kills": 3})
	_t.check("F3-2 merge keeps every equipped slot, the saver's where both hold one, and the saver's last pilot",
		merged["equipped"] == {"a/paint": "c1", "a/trail": "t1", "b/paint": "c2"} and merged["last_pilot"] == "a", str(merged["equipped"]))
	_t.check("F3-2 merge keeps their unknown key but not over ours", merged["only_theirs"] == {"k": 1} and merged["shared"] == "ours")
	_t.eq("F3-2 merge generation is the larger", merged["generation"], 6)
	_t.eq("F3-2 merge is the same both times", Profile.merge(ours, theirs), merged)


func _second_backup_kept() -> void:
	var path := _copy_fixture("v0.json")
	var first := _bytes(path)
	var p := Profile.new(path)
	p.load_profile()
	p.save()
	var second := '{"pilots": ["someone_else"], "legacy_note": "different"}'.to_utf8_buffer()
	_write(path, second)
	var q := Profile.new(path)
	q.load_profile()
	_t.check("F3-3 second v0 saves", q.save(), q.last_error)
	_t.check("F3-3 both originals recoverable", _bytes(path + ".v0") == first and _bytes(path + ".v0.1") == second)
	_write(path, second)
	var r := Profile.new(path)
	r.load_profile()
	r.save()
	_t.check("F3-3 identical backup is not repeated", not FileAccess.file_exists(path + ".v0.2"))
	var third := '{"pilots": ["third"]}'.to_utf8_buffer()
	_write(path, third)
	var s := Profile.new(path)
	s.load_profile()
	s.save()
	_t.check("F3-3 third different file counts up", _bytes(path + ".v0.2") == third)


func _numbers_round_trip() -> void:
	var path := _fresh_path()
	var p := Profile.new(path)
	p.load_profile()
	p.earn("deed", 1790000000.9)
	p.set_stat("big", 1790000000.0)
	p.set_stat("fraction", 0.1 + 0.2)
	p.set_stat("long_fraction", 1234567.891234567)
	p.save()
	var q := Profile.new(path)
	q.load_profile()
	var stored = q._doc["achievements"]["deed"]
	_t.check("F3-5 time is whole seconds, rounded down", typeof(stored) == TYPE_INT and stored == 1790000000, var_to_str(stored))
	var text := FileAccess.get_file_as_string(path)
	_t.check("F3-5 time is written without a fraction", text.contains('"deed": 1790000000\n'), text)
	_t.check("F3-5 whole stat equal", q.stat("big") == 1790000000.0)
	_t.check("F3-5 fractional stats equal", q.stat("fraction") == 0.1 + 0.2 and q.stat("long_fraction") == 1234567.891234567, "%s %s" % [q.stat("fraction"), q.stat("long_fraction")])


func _errors_name_their_cause() -> void:
	var never := Profile.new(_fresh_path())
	never.save()
	_t.check("F3-5 never loaded names itself", never.last_error.contains("not been loaded"), never.last_error)
	var future := Profile.new(_copy_fixture("future.json"))
	future.load_profile()
	future.save()
	_t.check("F3-5 newer build named", future.last_error.contains("newer build"), future.last_error)
	var good := Profile.new(_fresh_path())
	good.load_profile()
	good.last_error = "old load error"
	_t.check("F3-5 successful save clears the error", good.save() and good.last_error.is_empty(), good.last_error)
	var blocked := Profile.new(_fresh_path())
	blocked.load_profile()
	DirAccess.make_dir_recursive_absolute(blocked.path)
	_t.check("F3-5 failed write names the write", not blocked.save() and not blocked.last_error.contains("newer build") and not blocked.last_error.is_empty(), blocked.last_error)


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


func _v1_migrates_to_2() -> void:
	var path := _fresh_path()
	var original := FileAccess.get_file_as_bytes(V1_FIXTURE)
	_write(path, original)
	var p := Profile.new(path)
	_t.check("META-7 v1 loads", p.load_profile(), p.last_error)
	_t.check("META-7 v1 pilots kept", p.has_pilot("pylon_engineer") and p.has_pilot("runner_gunner"))
	_t.check("META-7 v1 worlds kept", p.has_world("orchard") and p.has_world("slag_bowl"))
	_t.check("META-7 v1 achievements kept", p.earned("rout_brindle") and p.earned("first_win") and p.earned_at("first_win") == 1790000500 and p._doc["achievements"].size() == 2)
	_t.check("META-7 v1 cosmetics kept", p.has_cosmetic("paint_verdigris") and p.has_cosmetic("paint_rust") and p._doc["cosmetics"].size() == 2)
	_t.check("META-7 v1 equipped, stats, last pilot kept", p.equipped("pylon_engineer", "paint") == "paint_verdigris" and p.stat("runs") == 9.0 and p.stat("ach.rout_brindle") == 1.0 and p.last_pilot() == "runner_gunner")
	_t.check("META-7 v1 gets the new fields empty", p.companion().is_empty() and p.settled_ids().is_empty() and not p.rewards_settled())
	_t.check("META-7 v1 no backup before save", not FileAccess.file_exists(path + ".v1"))
	_t.check("META-7 v1 saves", p.save(), p.last_error)
	_t.check("META-7 v1 backup holds the original bytes", _bytes(path + ".v1") == original)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	# Re-pinned 2026-10-10 (w13 B5): the literal 3 became Profile.SCHEMA; schema 4 chains v1 to v4
	# and counts the v1 file's two owned cosmetics as seen.
	_t.check("META-7 v1 file is now the current schema, generation 13, unknown key kept", saved is Dictionary and saved.get("schema") == Profile.SCHEMA and saved.get("generation") == 13 and saved.get("kept_from_a_tool", {}).get("note") == "unknown keys ride through", str(saved))
	_t.check("B5 v1 cosmetics count as seen", p.is_seen("paint_verdigris") and p.is_seen("paint_rust") and p.seen_ids().size() == 2, str(p.seen_ids()))
	var q := Profile.new(path)
	q.load_profile()
	_t.check("META-7 v2 reload keeps every unlock", q.has_pilot("runner_gunner") and q.has_cosmetic("paint_rust") and q.earned("first_win") and q.has_world("slag_bowl"))
	_t.check("META-7 v2 resave needs no second backup", q.save() and _bytes(path + ".v1") == original and not FileAccess.file_exists(path + ".v1.1"))


func _companion_and_settled_round_trip() -> void:
	var path := _fresh_path()
	var p := Profile.new(path)
	p.load_profile()
	var comp := {"chassis": "spil9", "owned": ["primer_coil", "escape_vent", "ram_prow"], "sockets": ["primer_coil", "escape_vent"], "escape_ready": false, "escape_spent": true}
	p.set_companion(comp)
	_t.check("RS4 settle is true once", p.settle("first_win_paint") and not p.settle("first_win_paint"))
	p.settle("hotwire_offer")
	_t.check("META-7 rewards_settled marks once", p.mark_rewards_settled() and not p.mark_rewards_settled())
	_t.check("META-7 companion save", p.save(), p.last_error)
	var q := Profile.new(path)
	q.load_profile()
	_t.eq("META-7 companion round trip", q.companion(), comp)
	_t.eq("META-7 owned pieces", q.companion()["owned"], ["primer_coil", "escape_vent", "ram_prow"])
	_t.eq("META-7 sockets", q.companion()["sockets"], ["primer_coil", "escape_vent"])
	_t.check("META-7 escape flag", q.companion()["escape_spent"] == true and q.companion()["escape_ready"] == false)
	_t.eq("RS4 settled list round trip", q.settled_ids(), ["first_win_paint", "hotwire_offer"])
	_t.check("META-7 rewards_settled round trip", q.rewards_settled())
	var a := Profile.new(path)
	var b := Profile.new(path)
	a.load_profile()
	b.load_profile()
	a.settle("only_a")
	a.set_companion({"chassis": "spil9", "owned": ["primer_coil", "escape_vent", "ram_prow", "ram_spring"], "sockets": [], "escape_ready": true, "escape_spent": false})
	b.settle("only_b")
	a.save()
	b.save()
	var c := Profile.new(path)
	c.load_profile()
	_t.check("RS4 two writers union their settled ids", c.is_settled("only_a") and c.is_settled("only_b") and c.is_settled("hotwire_offer"), str(c.settled_ids()))
	_t.check("META-7 two writers union owned pieces and keep an assembly", c.companion()["owned"].size() == 4 and c.companion()["sockets"].size() == 2, str(c.companion()))


# Re-labelled 2026-10-10 (w13 B5): the file is SCHEMA + 1, so the label says "newer schema"
# instead of a number that goes stale on every bump. Logic unchanged.
func _schema_3_never_saves() -> void:
	var path := _fresh_path()
	var bytes := _future_bytes()
	_write(path, bytes)
	var p := Profile.new(path)
	p.load_profile()
	p.settle("x")
	p.set_companion({"chassis": "spil9"})
	_t.check("META-7 newer schema refuses to save", not p.can_save and not p.save() and p.last_error.contains("newer build"), p.last_error)
	_t.check("META-7 newer schema bytes and backups untouched", _bytes(path) == bytes and not FileAccess.file_exists(path + ".v2") and not FileAccess.file_exists(path + ".v1"))


# CUSTOMIZE.md section 5: a wave 12 save loads losslessly, its owned cosmetics count as seen,
# and the first save keeps the original bytes as .v3.
func _v3_migrates_to_4() -> void:
	var path := _fresh_path()
	var original := FileAccess.get_file_as_bytes(V3_FIXTURE)
	var source: Dictionary = JSON.parse_string(original.get_string_from_utf8())
	_write(path, original)
	var p := Profile.new(path)
	_t.check("B5 v3 loads", p.load_profile() and p.can_save, p.last_error)
	_t.eq("B5 v3 pilots kept", p._doc["pilots"], source["pilots"])
	_t.eq("B5 v3 worlds kept", p._doc["worlds"], source["worlds"])
	_t.eq("B5 v3 cosmetics kept", p._doc["cosmetics"], source["cosmetics"])
	_t.check("B5 v3 achievements and times kept", p.earned_at("warden_broken") == 1790100000 and p.earned_at("kills_100") == 1790100900 and p._doc["achievements"].size() == 2)
	_t.check("B5 v3 equipped kept", p.equipped("pylon_engineer", "paint") == "paint_any_night" and p.equipped("pylon_engineer", "trail") == "trail_salt_skip" and p.equipped("spil9", "companion_paint") == "companion_paint_night" and p._doc["equipped"].size() == 3)
	_t.check("B5 v3 stats kept", p.stat("runs") == 14.0 and p.stat("ach.kills_100") == 100.0 and p.stat("ach.ach_d7_paw") == 37.0)
	_t.eq("B5 v3 settled kept", p.settled_ids(), source["settled"])
	_t.eq("B5 v3 companion kept", p.companion(), source["companion"])
	_t.check("B5 v3 rewards_settled and last pilot kept", p.rewards_settled() and p.last_pilot() == "pylon_engineer")
	_t.eq("B5 v3 owned cosmetics count as seen", p.seen_ids(), source["cosmetics"])
	_t.check("B5 v3 no backup before save", not FileAccess.file_exists(path + ".v3"))
	_t.check("B5 v3 saves", p.save(), p.last_error)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	_t.check("B5 v3 file is schema 4, generation +1", saved is Dictionary and saved.get("schema") == 4 and saved.get("generation") == 22, str(saved))
	_t.check("B5 v3 unknown key rides through", saved is Dictionary and saved.get("kept_from_a_tool", {}).get("note") == "unknown keys ride through")
	_t.check("B5 v3 backup holds the original bytes", _bytes(path + ".v3") == original)
	var q := Profile.new(path)
	_t.check("B5 v4 reload", q.load_profile(), q.last_error)
	_t.check("B5 v4 reload keeps all", q._doc["cosmetics"] == source["cosmetics"] and q.seen_ids() == source["cosmetics"] and q.settled_ids() == source["settled"] and q.companion() == source["companion"] and q.equipped("spil9", "companion_paint") == "companion_paint_night" and q.earned("kills_100"))
	_t.check("B5 v4 resave makes no second backup", q.save() and _bytes(path + ".v3") == original and not FileAccess.file_exists(path + ".v3.1"))


func _v3_seen_already_present() -> void:
	var path := _fresh_path()
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(V3_FIXTURE))
	doc["seen"] = ["x", "trail_salt_skip"]
	_write(path, JSON.stringify(doc).to_utf8_buffer())
	var p := Profile.new(path)
	_t.check("B5 v3 with seen loads", p.load_profile(), p.last_error)
	var seen := p.seen_ids()
	var dupes := false
	for id in seen:
		if seen.count(id) > 1:
			dupes = true
	_t.check("B5 v3 seen keeps x plus every owned id, no duplicates", seen.has("x") and seen.size() == 6 and not dupes and seen.has("companion_paint_night"), str(seen))
	_t.check("B5 mark_seen is true once", p.mark_seen("y") and not p.mark_seen("y") and p.is_seen("y"))


func _seen_merge() -> void:
	var path := _fresh_path()
	var base := Profile.new(path)
	base.load_profile()
	base.save()
	var a := Profile.new(path)
	var b := Profile.new(path)
	a.load_profile()
	b.load_profile()
	a.mark_seen("trail_any_downbeat")
	b.mark_seen("decal_curtain_call")
	_t.check("B5 seen merge writers save", a.save() and b.save(), b.last_error)
	var c := Profile.new(path)
	c.load_profile()
	_t.check("B5 two writers union their seen ids", c.is_seen("trail_any_downbeat") and c.is_seen("decal_curtain_call") and c.seen_ids().size() == 2, str(c.seen_ids()))
	var merged := Profile.merge({"seen": ["a"], "pilots": [], "worlds": [], "cosmetics": [], "settled": [], "achievements": {}, "stats": {}, "equipped": {}}, {"seen": ["b", "a"]})
	_t.eq("B5 merge unions seen", merged["seen"], ["a", "b"])


# 2026-10-16: a save that earned the cut Rigger Harness owns Rigger Blue on its next load, the
# new paint glows as unseen, the outfit slot that wore the harness is cleared, and the swap
# survives a save and a merge with a file that still holds the old id.
func _retired_cosmetic_swapped() -> void:
	var path := _fresh_path()
	var doc := {"schema": 4, "generation": 3, "cosmetics": ["paint_any_night", "outfit_kest_rigger"],
		"seen": ["paint_any_night", "outfit_kest_rigger"], "achievements": {"ach_kest_homecoming": 1790100000},
		"equipped": {"demolitions_caster/outfit": "outfit_kest_rigger", "demolitions_caster/paint": "paint_any_night"}}
	_write(path, JSON.stringify(doc).to_utf8_buffer())
	var p := Profile.new(path)
	_t.check("RIG loads", p.load_profile() and p.can_save, p.last_error)
	_t.check("RIG harness swapped for Rigger Blue", p.has_cosmetic("paint_kest_rigger") and not p.has_cosmetic("outfit_kest_rigger") and p.has_cosmetic("paint_any_night"))
	_t.check("RIG Rigger Blue is new", not p.is_seen("paint_kest_rigger") and not p.is_seen("outfit_kest_rigger") and p.is_seen("paint_any_night"))
	_t.check("RIG outfit slot cleared, paint kept", p.equipped("demolitions_caster", "outfit") == "" and p.equipped("demolitions_caster", "paint") == "paint_any_night")
	_t.check("RIG earn time kept", p.earned_at("ach_kest_homecoming") == 1790100000)
	_write(path, JSON.stringify(doc).to_utf8_buffer())
	_t.check("RIG saves over a file that still holds the old id", p.save(), p.last_error)
	var reloaded := Profile.new(path)
	reloaded.load_profile()
	_t.check("RIG the swap survives save and merge", reloaded.has_cosmetic("paint_kest_rigger") and not reloaded.has_cosmetic("outfit_kest_rigger")
		and reloaded._doc["cosmetics"].count("paint_kest_rigger") == 1)


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
