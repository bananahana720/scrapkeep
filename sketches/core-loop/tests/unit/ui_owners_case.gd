extends RefCounted

const ItemGen := preload("res://src/build/item_gen.gd")
const OddsReadout := preload("res://src/ui/odds_readout.gd")
const Parts := preload("res://src/build/parts.gd")

const UI_DIR := "res://src/ui/"
const LABEL_CEILING := 34


func _ui_sources() -> Dictionary:
	var out := {}
	for file in DirAccess.get_files_at(UI_DIR):
		if file.ends_with(".gd"):
			out[file] = FileAccess.get_file_as_string(UI_DIR + file)
	return out


func _count(pattern: String, text: String) -> int:
	var re := RegEx.new()
	re.compile(pattern)
	return re.search_all(text).size()


func run(t) -> void:
	var shop := FileAccess.get_file_as_string("res://src/build/shop.gd")
	t.check("shop.gd preloads nothing from src/ui", shop != "" and not 'preload("res://src/ui/' in shop)
	t.check("results_odds.gd is folded into odds_readout.gd", not FileAccess.file_exists(UI_DIR + "results_odds.gd"))
	var sources := _ui_sources()
	t.check("src/ui sources are readable", sources.size() > 0, "%d files" % sources.size())
	var widths := []
	var raw_colours := []
	var labels := 0
	for file in sources:
		var text: String = sources[file]
		if "UiDraw.width(" in text:
			widths.append(file)
		if file != "ui_tokens.gd" and 'Color("' in text:
			raw_colours.append(file)
		labels += _count("(?<![A-Za-z_])Label\\.new\\(\\)", text)
	widths.sort()
	raw_colours.sort()
	t.eq("UiDraw.width is gone; callers use UiFonts.width", widths, [])
	t.eq("ui_draw.gd has no width forwarder", _count("(?m)^static func width\\(", sources.get("ui_draw.gd", "")), 0)
	t.eq("raw Color(\"...\") literals in src/ui live only in ui_tokens.gd", raw_colours, [])
	t.check("Label.new() in src/ui stays at or under %d" % LABEL_CEILING, labels <= LABEL_CEILING, "%d sites" % labels)

	var cid := "rivet"
	t.eq("OddsReadout.odds_for forwards to Parts.odds_for", OddsReadout.odds_for(["common", "rare"], cid), Parts.odds_for(["common", "rare"], cid))
	var odds := ItemGen.odds(["common", "rare"])
	t.eq("OddsReadout.text forwards to ItemGen.odds_text", OddsReadout.text(odds), ItemGen.odds_text(odds))
	t.eq("an empty odds table reads empty", ItemGen.odds_text([]), "")
