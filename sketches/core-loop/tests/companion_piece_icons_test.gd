extends SceneTree

const Icons := preload("res://src/ui/icons.gd")
const PanelScript := preload("res://src/ui/companion_panel.gd")
const Companion := preload("res://src/core/companion.gd")

# Every companion piece draws its own generated icon, and the two pieces of one family share
# one backplate (the family trait: circle, rounded square, hex) so "One of each kind" reads
# from the marks. The generator's data is Python and not reachable here, so the trait is read
# from the committed SVG: its first drawn element is the backplate.

var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _plate(id: String) -> String:
	var svg := FileAccess.get_file_as_string("res://assets/icons/%s.svg" % id)
	var at := svg.find('viewBox="0 0 64 64">')
	if at < 0:
		return ""
	var start := at + 20
	return svg.substr(start, svg.find("/>", start) + 2 - start)


# The problems with a piece-to-icon map; empty when it is sound.
func _audit(map: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	var plate_of := {}
	for p in Companion.PIECES:
		var piece: String = p["id"]
		if not map.has(piece):
			out.append("%s has no icon" % piece)
			continue
		var id: String = map[piece]
		if not (Icons.has(id) or Icons.EXTRA.has(id)):
			out.append("%s: %s is not a registry id" % [piece, id])
		if not FileAccess.file_exists("res://assets/icons/%s.svg" % id):
			out.append("%s: %s has no SVG file" % [piece, id])
			continue
		if seen.has(id):
			out.append("%s and %s share %s" % [seen[id], piece, id])
		seen[id] = piece
		var fam: String = p["family"]
		var plate := _plate(id)
		if plate_of.has(fam) and plate_of[fam] != plate:
			out.append("%s: backplate differs inside family %s" % [piece, fam])
		plate_of[fam] = plate
	var plates := {}
	for fam in plate_of:
		plates[plate_of[fam]] = true
	if plate_of.size() > 0 and plates.size() != plate_of.size():
		out.append("two families share a backplate")
	return out


func _initialize() -> void:
	var real: Dictionary = PanelScript.PIECE_ICONS
	_report("eight pieces", Companion.PIECES.size() == 8 and real.size() == 8, "%d pieces, %d icons" % [Companion.PIECES.size(), real.size()])
	var problems := _audit(real)
	_report("the panel's map is sound", problems.is_empty(), str(problems))
	var from_file := true
	for piece in real:
		from_file = from_file and Icons.from_file(real[piece])
	_report("each icon loads from its SVG, no fallback glyph", from_file, str(real.values()))
	# Planted failures: each broken copy must be caught.
	var missing := real.duplicate()
	missing["ram_prow"] = "cmp_no_such_file"
	_report("planted: an id with no file is caught", not _audit(missing).is_empty(), str(_audit(missing)))
	var dup := real.duplicate()
	dup["ram_spring"] = real["ram_prow"]
	_report("planted: a shared id is caught", not _audit(dup).is_empty(), str(_audit(dup)))
	var cross := real.duplicate()
	cross["escape_rail"] = real["ram_spring"]
	_report("planted: a piece wearing another family's plate is caught", not _audit(cross).is_empty(), str(_audit(cross)))
	print("companion_piece_icons_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
