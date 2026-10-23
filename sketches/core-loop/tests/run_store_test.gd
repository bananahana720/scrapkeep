extends SceneTree

const RunState := preload("res://src/core/run_state.gd")
const RunStore := preload("res://src/core/run_store.gd")
const SafeStore := preload("res://src/core/safe_store.gd")

# The run store (RS2): one run document on disk, through SafeStore. Pure file logic.

const DIR := "user://run_store_test/"
const FIXTURE := "res://tests/fixtures/run_v0.json"

var _failures := 0
var _n := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: ", what)


func _path() -> String:
	_n += 1
	return "%sr%d.json" % [DIR, _n]


func _write(file_path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _bytes(file_path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(file_path)


func _doc() -> Dictionary:
	var r := RunState.new(null)
	r.run_id = "1760000000-004242"
	r.run_seed = 99
	r.world = 2
	r.stage = 4
	r.scrap = 31
	r.parts.assign(["plate", "coil"])
	r.retries_spent = {1: 2, 2: 1}
	r.snapshot(Vector3(1.5, 0.0, -2.0), Vector3(0, 0, -12), 0.5)
	return r.to_entrance_doc()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	_missing()
	_round_trip()
	_stale_save()
	_unreadable()
	_newer()
	_migration()
	_interrupted()
	_merge_case()
	print("run_store_test: PASS" if _failures == 0 else "run_store_test: FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)


func _missing() -> void:
	var s := RunStore.new(_path())
	_check(s.load().is_empty(), "missing file loads as no run")
	_check(s.refusal == "", "missing file is not a refusal")
	_check(s.clear(), "clear with no file is fine")


func _round_trip() -> void:
	var p := _path()
	var s := RunStore.new(p)
	var doc := _doc()
	_check(s.save(doc) == "", "first save: " + s.last_error)
	_check(s.generation() == 1, "generation 1 after first save")
	_check(s.save(doc) == "" and s.generation() == 2, "second save counts")
	var t := RunStore.new(p)
	var got := t.load()
	_check(t.generation() == 2, "loaded generation")
	var same: bool = got.keys() == JSON.parse_string(JSON.stringify(doc)).keys()
	for key in ["run_id", "scrap", "stage", "world", "parts", "entry_velocity"]:
		same = same and JSON.stringify(got[key]) == JSON.stringify(JSON.parse_string(JSON.stringify(doc))[key])
	_check(same, "doc survives the file unchanged")
	var back := RunState.new(null)
	_check(back.from_entrance_doc(got), "loaded doc passes RunState")
	_check(back.world == 2 and back.stage == 4 and back.retries_spent == {1: 2, 2: 1}, "RunState fields back")
	_check(t.clear() and FileAccess.file_exists(p), "clear leaves a tombstone")
	_check(t.load().is_empty(), "no run after clear")
	_check(t.save(doc) == "" and not RunStore.new(p).load().is_empty(), "a new run saves over the tombstone")


# A second store holding an older generation cannot resurrect an ended run.
func _stale_save() -> void:
	var p := _path()
	var a := RunStore.new(p)
	a.save(_doc())
	a.save(_doc())
	_check(a.save(_doc()) == "" and a.generation() == 3, "A saves generation 3")
	var b := RunStore.new(p)
	b.load()
	_check(b.clear(), "B clears the run")
	var late := a.save(_doc())
	_check(late == RunStore.REFUSED_ENDED, "A's stale save is refused as run_ended, got '%s'" % late)
	_check(RunStore.new(p).load().is_empty(), "load shows no run after the stale save")


func _unreadable() -> void:
	var p := _path()
	var junk := "{half a sav".to_utf8_buffer()
	_write(p, junk)
	var s := RunStore.new(p)
	_check(s.load().is_empty(), "unreadable loads as no run")
	_check(not FileAccess.file_exists(p), "unreadable file moved off the path")
	_check(FileAccess.file_exists(p + ".bad") and _bytes(p + ".bad") == junk, "one .bad keeps the original bytes")
	_check(s.refusal == RunStore.REFUSED_CHANGED, "unreadable is named changed_on_disk: " + s.refusal)
	_check(s.save(_doc()) == "", "next save proceeds: " + s.last_error)
	_check(s.refusal == "", "the save clears the load's refusal")
	_check(_bytes(p + ".bad") == junk, ".bad untouched by the save")


func _newer() -> void:
	var p := _path()
	var future := '{"schema": 9, "generation": 4, "run": {"x": 1}}'.to_utf8_buffer()
	_write(p, future)
	var s := RunStore.new(p)
	_check(s.load().is_empty(), "newer schema loads as no run")
	_check(s.refusal == RunStore.REFUSED_NEWER, "refusal is named")
	_check(s.save(_doc()) == RunStore.REFUSED_NEWER, "save refuses with the named cause")
	_check(_bytes(p) == future, "newer file byte-identical")
	_check(s.last_error.contains("newer"), "error names the cause")
	_check(s.clear() and not FileAccess.file_exists(p), "clear lifts it")
	_check(s.save(_doc()) == "", "save works after clear")


func _migration() -> void:
	var p := _path()
	var old := FileAccess.get_file_as_bytes(FIXTURE)
	_check(old.size() > 0, "fixture present")
	_write(p, old)
	var s := RunStore.new(p)
	var got := s.load()
	_check(got.get("retries_spent") == {"1": 2, "2": 1}, "v0 pairs become the string map: %s" % [got.get("retries_spent")])
	_check(got.get("stage") == 5 or got.get("stage") == 5.0, "v0 fields kept")
	_check(_bytes(p) == old, "load alone does not touch the file")
	_check(s.save(got) == "", "save after migration: " + s.last_error)
	_check(_bytes(p + ".v0") == old, ".v0 backup holds the old bytes")
	var parsed = JSON.parse_string(_bytes(p).get_string_from_utf8())
	_check(parsed["schema"] == 1 and int(parsed["generation"]) == 1, "file is v1 now")
	_check(JSON.stringify(RunStore.new(p).load()) == JSON.stringify(got), "v1 reloads the same")


func _interrupted() -> void:
	var p := _path()
	var s := RunStore.new(p)
	_check(s.save(_doc()) == "", "seed save")
	var whole := _bytes(p)
	var tmp := SafeStore.tmp_path(p)
	DirAccess.make_dir_recursive_absolute(tmp)  # the temp-file step cannot open
	var changed := _doc()
	changed["scrap"] = 500
	_check(s.save(changed) == RunStore.REFUSED_WRITE, "interrupted write reports write_failed")
	DirAccess.remove_absolute(tmp)
	_check(_bytes(p) == whole, "old file whole")
	for name in DirAccess.get_files_at(DIR):
		_check(not name.ends_with(".tmp"), "no stray .tmp: " + name)
	_check(s.generation() == 1, "generation not advanced by the failed save: %d" % s.generation())
	_check(s.save(changed) == "", "retry after the failure works")


func _merge_case() -> void:
	var p := _path()
	var a := RunStore.new(p)
	var base := _doc()
	base["ended"] = false
	base["worlds_cleared"] = [1]
	_check(a.save(base) == "", "a saves")
	a.load()
	# A second writer advances the file: more retries spent, run ended, world 2 cleared.
	var b := RunStore.new(p)
	b.load()
	var theirs := _doc()
	theirs["retries_spent"] = {"1": 5, "2": 1}
	theirs["ended"] = true
	theirs["worlds_cleared"] = [1, 2]
	_check(b.save(theirs) == "" and b.save(theirs) == "", "b advances the file twice")
	# a still holds generation 1 and an older run; saving merges what disk already has.
	var ours := _doc()
	ours["retries_spent"] = {"1": 3, "2": 4}
	ours["ended"] = false
	ours["worlds_cleared"] = [1]
	_check(a.save(ours) == "", "stale a saves: " + a.last_error)
	var got := RunStore.new(p).load()
	_check(got["retries_spent"] == {"1": 5, "2": 4}, "larger retries per world: %s" % [got["retries_spent"]])
	_check(got["ended"] == true, "ended never goes back to false")
	_check(got["worlds_cleared"].has(1) and got["worlds_cleared"].has(2), "cleared worlds kept")
	# The earned save, once spent, stays spent: merged in both orders.
	var spent_doc := _doc()
	spent_doc["death_save_spent"] = true
	var unspent_doc := _doc()
	unspent_doc["death_save_spent"] = false
	_check(RunStore.merge(unspent_doc, spent_doc).get("death_save_spent", false) == true, "death_save_spent: spent theirs onto unspent ours stays true")
	_check(RunStore.merge(spent_doc, unspent_doc).get("death_save_spent", false) == true, "death_save_spent: unspent theirs onto spent ours stays true")
	# Load meets an older document than memory: memory's gains survive.
	var c := RunStore.new(p)
	var held := c.load()
	held["retries_spent"] = {"1": 9, "2": 0}
	c.save(held)
	var stale := JSON.stringify({"schema": 1, "generation": 1, "run": {"retries_spent": {"1": 1, "2": 7}, "ended": true}})
	_write(p, stale.to_utf8_buffer())
	var merged := c.load()
	_check(merged["retries_spent"] == {"1": 9, "2": 7} and merged["ended"] == true, "load merges a lower generation: %s" % [merged])
