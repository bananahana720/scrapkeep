extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")

const OWNER := "res://src/world/contraptions.gd"
const DISPATCH := "(?m)^[ \\t]*((?:\"[a-z_]+\",[ \\t]*)*\"[a-z_]+\"):[ \\t]*\\n[^\\n]*\\b_?build[a-z_]*\\("
const FILTER := "(?:\"kind\"[^\\n]*?|\\.kind[ \\t]*)==[ \\t]*\"([a-z_]+)\""


class Recorder:
	var failed: Array[String] = []

	func check(label: String, ok: bool, _detail: String = "") -> bool:
		if not ok:
			failed.append(label)
		return ok


static func builders(t, dispatch_roots: Array, filter_roots: Array) -> Dictionary:
	var out := {}
	for scan in [[dispatch_roots, DISPATCH], [filter_roots, FILTER]]:
		var rows: Dictionary = SourceScan.captures(t, scan[0], scan[1])
		for path: String in rows:
			for row: PackedStringArray in rows[path]:
				for kind in row[1].replace("\"", "").split(",", false):
					var key := kind.strip_edges()
					if not out.has(key):
						out[key] = []
					if not path in out[key]:
						out[key].append(path)
	for key in out:
		out[key].sort()
	return out


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func run(t) -> void:
	var found := builders(t, ["res://src"], ["res://src/world"])
	t.check("contraption kinds are listed", not ParkSchema.CONTRAPTION_KINDS.is_empty())
	for kind: String in ParkSchema.CONTRAPTION_KINDS:
		t.eq("the %s rows have exactly one builder: a match arm under src or a kind filter under src/world" % kind,
			found.get(kind, []), [OWNER])

	var tmp := OS.get_temp_dir().path_join("contraption_builders_case_%d" % OS.get_process_id())
	var two := tmp.path_join("two")
	var blank := tmp.path_join("blank")
	for dir in [two, blank]:
		DirAccess.make_dir_recursive_absolute(dir)
	_write(two.path_join("a.gd"), "func build_next(spec):\n\tmatch spec[\"kind\"]:\n\t\t\"barge\", \"lift\":\n\t\t\tbarges.append(_build_barge(spec))\n")
	_write(two.path_join("b.gd"), "func sync(m):\n\tfor spec in m.contraptions:\n\t\tif String(spec.get(\"kind\", \"\")) == \"barge\":\n\t\t\tspecs.append(spec)\n")
	_write(blank.path_join("blank.gd"), "")
	var rec := Recorder.new()
	var scratch := builders(rec, [two], [two])
	t.eq("a scratch scan records no failure", rec.failed, [])
	t.eq("a match arm and a kind filter both count as builders", scratch.get("barge", []), [two.path_join("a.gd"), two.path_join("b.gd")])
	t.eq("a match arm that lists two kinds builds both", scratch.get("lift", []), [two.path_join("a.gd")])
	rec = Recorder.new()
	scratch = builders(rec, [two], [blank])
	t.eq("a kind filter outside the filter roots is not counted", scratch.get("barge", []), [two.path_join("a.gd")])
	rec = Recorder.new()
	scratch = builders(rec, [blank], [blank])
	t.check("an empty read fails the builder scan", rec.failed.has("source scan reads " + blank.path_join("blank.gd")), str(rec.failed))
	t.eq("an empty read finds no builder", scratch, {})
	var missing := tmp.path_join("missing")
	rec = Recorder.new()
	scratch = builders(rec, [missing], [missing])
	t.check("a root that does not open fails the builder scan", rec.failed.has("source scan opens " + missing), str(rec.failed))
	t.eq("a root that does not open finds no builder", scratch, {})

	for path in [two.path_join("a.gd"), two.path_join("b.gd"), blank.path_join("blank.gd")]:
		DirAccess.remove_absolute(path)
	for dir in [two, blank, tmp]:
		DirAccess.remove_absolute(dir)
	t.check("the builder scan's scratch folder is removed", not DirAccess.dir_exists_absolute(tmp), tmp)
