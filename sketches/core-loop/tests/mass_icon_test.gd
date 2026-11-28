extends SceneTree

const Icons := preload("res://src/ui/icons.gd")

# The cog means money and nothing else: in the three UI files that once drew it for mass
# too, res_scrap stands only where cogs are meant, res_mass stands where mass is meant,
# and in the run summary (summary_rows.gd, which shows the scrap and not the cogs) no chip
# shares the cog's or the heap's glyph.

# file: the lines that may name res_scrap (cogs) and the lines that must name res_mass.
const FILES := {
	"res://src/ui/hud.gd": {
		"cog": ['const ICON := "res_scrap"'],
		"mass": ['Gauge.new("res_mass", ARMOR_BAR, true, ARMOR_WORD)'],
	},
	"res://src/ui/growth_sheet.gd": {
		"cog": ['draw_texture_rect(Icons.texture("res_scrap"), Rect2(rect.get_center()'],
		"mass": ['"scrap": {"at": Vector2(90.0, 84.0), "icon": "res_mass"'],
	},
	"res://src/ui/summary_rows.gd": {
		"cog": [],
		"mass": ['["res_mass", str(s["scrap"]), "scrap", LOST]'],
	},
}

var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	for path in FILES:
		var text := FileAccess.get_file_as_string(path)
		var allowed: Array = FILES[path]["cog"]
		var stray: Array[String] = []
		for line in text.split("\n"):
			if line.contains("res_scrap") and not allowed.any(func(want): return line.contains(want)):
				stray.append(line.strip_edges())
		var missing: Array = (allowed + FILES[path]["mass"]).filter(func(want): return not text.contains(want))
		_report("cog only for cogs: " + path.get_file(), text != "" and stray.is_empty() and missing.is_empty(),
			"res_scrap outside a cog context %s; expected lines missing %s" % [stray, missing])

	var screens := FileAccess.get_file_as_string("res://src/ui/summary_rows.gd")
	var start := screens.find("var out := [")
	# The whole of rows(): the list and the side-job and save rows a run that earned one adds after it.
	var block := screens.substr(start, screens.find("return out", start) - start) if start >= 0 else ""
	var ids: Array[String] = []
	for m in RegEx.create_from_string("\\[\"([a-z0-9_]+)\",").search_all(block):
		ids.append(m.get_string(1))
	# The cog and the heap each stand alone; other chips draw their own SVGs.
	var apart := [Icons.glyph_of("res_scrap"), Icons.glyph_of("res_mass")]
	var shared := ids.filter(func(id): return not id in ["res_scrap", "res_mass"] and Icons.glyph_of(id) in apart)
	var unique := ids.filter(func(id): return ids.count(id) == 1).size() == ids.size()
	_report("summary chips: cogs and mass apart", ids.size() >= 6 and unique and not "res_scrap" in ids and "res_mass" in ids and shared.is_empty(),
		"chips %s; ids unique %s; sharing the cog or heap glyph %s" % [ids, unique, shared])

	var mass := Icons.glyph_of("res_mass")
	_report("mass has its own glyph", mass != Icons.glyph_of("res_scrap") and mass != Icons.glyph_of("res_heft")
			and Icons.texture("res_mass").get_width() > 0 and Icons.from_file("res_mass"),
		"res_mass %s, res_scrap %s, res_heft %s, SVG loaded %s" % [mass, Icons.glyph_of("res_scrap"), Icons.glyph_of("res_heft"), Icons.from_file("res_mass")])

	print("mass_icon_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
