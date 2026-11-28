extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")

const PALETTE := "res://src/core/palette.gd"
const ANNOTATION := "(?:@[a-z0-9_]+(?:\\([^)]*\\))?\\s+)*"
const FORBIDDEN := "(?m)\\b(?:pre)?load\\s*\\(|^\\s*" + ANNOTATION + "static\\s+" + ANNOTATION + "var\\b"


func _hits(t, body: String) -> Array[String]:
	var out: Array[String] = []
	for hit in SourceScan.search(t, body, FORBIDDEN):
		out.append(hit.get_string().strip_edges())
	return out


func run(t) -> void:
	t.eq("fixture control: a static var is found", _hits(t, "static var _cache := {}\n"), ["static var"])
	t.eq("fixture control: an annotated static var is found", _hits(t, "@warning_ignore(\"unused\") static var _n := 0\n"), ["@warning_ignore(\"unused\") static var"])
	t.eq("fixture control: a preload is found", _hits(t, "const Slots := preload(\"res://x.gd\")\n"), ["preload("])
	t.eq("fixture control: a load in a function is found", _hits(t, "static func f():\n\treturn load(\"res://y.tres\")\n"), ["load("])
	t.eq("fixture control: a colour constant and a pure function pass", _hits(t, "const SAND := Color(\"d2c5a5\")\n\n\nstatic func live(_c = null) -> Color:\n\treturn SAND\n"), [])
	var source := SourceScan.text(t, PALETTE)
	t.check("core palette reads", not source.is_empty(), PALETTE)
	t.eq("core palette holds no preload, load or static var", _hits(t, source), [])
