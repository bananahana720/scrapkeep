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

	got = _scan([], "marker_here")
	t.eq("a scan with no root fails", got["failed"], ["source scan has roots"])

	got = _scan([no_scripts], "marker_here")
	t.eq("a root with no .gd file fails the scan", got["failed"], ["source scan finds scripts under " + no_scripts])

	got = _scan([blank], "marker_here")
	t.eq("an empty read fails the scan", got["failed"], ["source scan reads " + blank.path_join("blank.gd")])

	got = _scan([good], "(")
	t.eq("a pattern that does not compile fails the scan", got["failed"], ["source scan pattern compiles"])

	got = _scan([good], "(?m)^func marker_here\\b")
	t.eq("a clean scratch scan records no failure", got["failed"], [])
	t.eq("a clean scratch scan finds its file", got["found"], [good.path_join("deep.gd")])

	_write(good.path_join("deep.gd"), "func marker_here() -> void:\n\tpass\n\nfunc marker_there() -> void:\n\tpass\n")
	var rec := Recorder.new()
	var rows: Dictionary = SourceScan.captures(rec, [good], "(?m)^func (marker_\\w+)\\(")
	t.eq("captures records no failure on a clean scan", rec.failed, [])
	t.eq("captures names each file that matches", rows.keys(), [good.path_join("deep.gd")])
	var wholes: Array[String] = []
	var names: Array[String] = []
	for row in rows.get(good.path_join("deep.gd"), []):
		wholes.append(row[0] if row.size() > 0 else "")
		names.append(row[1] if row.size() > 1 else "")
	t.eq("captures returns every whole match", wholes, ["func marker_here(", "func marker_there("])
	t.eq("captures returns every match with its groups", names, ["marker_here", "marker_there"])
	rec = Recorder.new()
	rows = SourceScan.captures(rec, [good], "(?m)^func no_such_marker\\(")
	t.eq("captures records no failure when nothing matches", rec.failed, [])
	t.eq("captures leaves out a file with no match", rows, {})
	rec = Recorder.new()
	rows = SourceScan.captures(rec, [blank], "marker_here")
	t.eq("captures fails on an empty read", rec.failed, ["source scan reads " + blank.path_join("blank.gd")])
	t.eq("captures returns nothing from an empty read", rows, {})

	var late := tmp.path_join("z_late")
	var early := tmp.path_join("a_early")
	for dir in [late, early]:
		DirAccess.make_dir_recursive_absolute(dir)
	_write(late.path_join("zeta.gd"), "func marker_here()\n")
	_write(late.path_join("alpha.gd"), "func marker_here()\n")
	_write(early.path_join("mid.gd"), "func marker_here()\n")
	rec = Recorder.new()
	rows = SourceScan.captures(rec, [late, early], "marker_here")
	t.eq("captures records no failure across two roots", rec.failed, [])
	t.eq("captures lists its files in sorted order, whatever the roots' or the folder's order", rows.keys(),
		[early.path_join("mid.gd"), late.path_join("alpha.gd"), late.path_join("zeta.gd")])

	rec = Recorder.new()
	var body := SourceScan.text(rec, missing.path_join("gone.gd"))
	t.eq("text fails on a file that does not open", rec.failed, ["source scan reads " + missing.path_join("gone.gd")])
	t.eq("text returns nothing from a file that does not open", body, "")
	rec = Recorder.new()
	body = SourceScan.text(rec, blank.path_join("blank.gd"))
	t.eq("text fails on an empty read", rec.failed, ["source scan reads " + blank.path_join("blank.gd")])
	rec = Recorder.new()
	body = SourceScan.text(rec, good.path_join("deep.gd"))
	t.eq("text records no failure on a good read", rec.failed, [])
	t.check("text returns the script's source", body.begins_with("func marker_here() -> void:"), body)

	rec = Recorder.new()
	var texts := SourceScan.sources(rec, [missing])
	t.eq("sources fails on a root that does not open", rec.failed, ["source scan opens " + missing])
	t.eq("sources returns nothing from a root that does not open", texts, {})
	rec = Recorder.new()
	texts = SourceScan.sources(rec, [])
	t.eq("sources fails with no root", rec.failed, ["source scan has roots"])
	rec = Recorder.new()
	texts = SourceScan.sources(rec, [no_scripts])
	t.eq("sources fails on a root with no .gd file", rec.failed, ["source scan finds scripts under " + no_scripts])
	rec = Recorder.new()
	texts = SourceScan.sources(rec, [blank, good])
	t.eq("sources fails on an empty read", rec.failed, ["source scan reads " + blank.path_join("blank.gd")])
	t.eq("sources keeps every script it read, in sorted order", texts.keys(), [good.path_join("deep.gd")])
	rec = Recorder.new()
	texts = SourceScan.sources(rec, [late, early])
	t.eq("sources records no failure on a clean scan", rec.failed, [])
	t.eq("sources returns each script's text by path, sorted", texts,
		{early.path_join("mid.gd"): "func marker_here()\n", late.path_join("alpha.gd"): "func marker_here()\n",
			late.path_join("zeta.gd"): "func marker_here()\n"})

	rec = Recorder.new()
	var hits := SourceScan.search(rec, "func a()\nfunc b()\n", "(")
	t.eq("search fails on a pattern that does not compile", rec.failed, ["source scan pattern compiles"])
	t.eq("search returns no match from a pattern that does not compile", hits.size(), 0)
	rec = Recorder.new()
	hits = SourceScan.search(rec, "func a()\nfunc b()\n", "(?m)^func (\\w+)")
	t.eq("search records no failure on a clean search", rec.failed, [])
	t.eq("search returns every match in order", hits.map(func(hit: RegExMatch) -> String: return hit.get_string(1)), ["a", "b"])
	rec = Recorder.new()
	hits = SourceScan.search(rec, "func a()\n", "no_such_marker")
	t.eq("search records no failure when nothing matches", rec.failed, [])
	t.eq("search returns no match when nothing matches", hits.size(), 0)

	var declared := "var plain := 1\n\tvar inner := 2\nstatic var shared := 3\n@export var shown := 4\n" \
		+ "@export_range(0, 10) var ranged := 5\n@onready @export var stacked := 6\n# var noted := 7\nconst fixed := 8\n"
	rec = Recorder.new()
	var vars := SourceScan.search(rec, declared, SourceScan.DECLARATION + "var\\s+(\\w+)")
	t.eq("DECLARATION compiles", rec.failed, [])
	t.eq("DECLARATION allows static, an annotation and indentation, and skips a comment",
		vars.map(func(hit: RegExMatch) -> String: return hit.get_string(1)), ["plain", "inner", "shared", "shown", "ranged", "stacked"])

	got = _scan(["res://src/core"], "(?m)^func warden_fight_live\\b")
	t.eq("a clean scan of src/core records no failure", got["failed"], [])
	t.eq("a clean scan of src/core finds flow.gd", got["found"], ["res://src/core/flow.gd"])

	DirAccess.remove_absolute(no_scripts.path_join("notes.txt"))
	DirAccess.remove_absolute(blank.path_join("blank.gd"))
	DirAccess.remove_absolute(good.path_join("deep.gd"))
	for path in [late.path_join("zeta.gd"), late.path_join("alpha.gd"), early.path_join("mid.gd")]:
		DirAccess.remove_absolute(path)
	for dir in [no_scripts, blank, good, late, early, tmp]:
		DirAccess.remove_absolute(dir)
	t.check("source scan scratch folder is removed", not DirAccess.dir_exists_absolute(tmp), tmp)
