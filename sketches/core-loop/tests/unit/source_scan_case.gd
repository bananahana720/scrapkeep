extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")


class Recorder:
	var failed: Array[String] = []

	func check(label: String, ok: bool, _detail: String = "") -> bool:
		if not ok:
			failed.append(label)
		return ok


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _scan(roots: Array, pattern: String) -> Dictionary:
	var rec := Recorder.new()
	var found := SourceScan.matching(rec, roots, pattern)
	return {"failed": rec.failed, "found": found}


func run(t) -> void:
	var tmp := OS.get_temp_dir().path_join("source_scan_case_%d" % OS.get_process_id())
	var no_scripts := tmp.path_join("no_scripts")
	var blank := tmp.path_join("blank")
	var good := tmp.path_join("good")
	for dir in [no_scripts, blank, good]:
		DirAccess.make_dir_recursive_absolute(dir)
	_write(no_scripts.path_join("notes.txt"), "func marker_here()\n")
	_write(blank.path_join("blank.gd"), "")
	_write(good.path_join("deep.gd"), "func marker_here() -> void:\n\tpass\n")

	var missing := tmp.path_join("missing")
	var got := _scan([missing], "marker_here")
	t.eq("a root that does not open fails the scan", got["failed"], ["source scan opens " + missing])

	got = _scan([no_scripts], "marker_here")
	t.eq("a root with no .gd file fails the scan", got["failed"], ["source scan finds scripts under " + no_scripts])

	got = _scan([blank], "marker_here")
	t.eq("an empty read fails the scan", got["failed"], ["source scan reads " + blank.path_join("blank.gd")])

	got = _scan([good], "(")
	t.eq("a pattern that does not compile fails the scan", got["failed"], ["source scan pattern compiles"])

	got = _scan([good], "(?m)^func marker_here\\b")
	t.eq("a clean scratch scan records no failure", got["failed"], [])
	t.eq("a clean scratch scan finds its file", got["found"], [good.path_join("deep.gd")])

	got = _scan(["res://src/core"], "(?m)^func warden_fight_live\\b")
	t.eq("a clean scan of src/core records no failure", got["failed"], [])
	t.eq("a clean scan of src/core finds flow.gd", got["found"], ["res://src/core/flow.gd"])

	DirAccess.remove_absolute(no_scripts.path_join("notes.txt"))
	DirAccess.remove_absolute(blank.path_join("blank.gd"))
	DirAccess.remove_absolute(good.path_join("deep.gd"))
	for dir in [no_scripts, blank, good, tmp]:
		DirAccess.remove_absolute(dir)
	t.check("source scan scratch folder is removed", not DirAccess.dir_exists_absolute(tmp), tmp)
