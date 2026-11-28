extends RefCounted

const ItemGen := preload("res://src/build/item_gen.gd")
const OddsReadout := preload("res://src/ui/odds_readout.gd")
const Parts := preload("res://src/build/parts.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")

const UI_DIR := "res://src/ui/"
const LABEL_CEILING := 34


func run(t) -> void:
	var shop := SourceScan.text(t, "res://src/build/shop.gd")
	t.check("shop.gd preloads nothing from src/ui", shop != "" and not 'preload("res://src/ui/' in shop)
	t.check("results_odds.gd is folded into odds_readout.gd", not FileAccess.file_exists(UI_DIR + "results_odds.gd"))
	var sources := {}
	var texts := SourceScan.sources(t, [UI_DIR])
	for path in texts:
		sources[String(path).get_file()] = texts[path]
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
		labels += SourceScan.search(t, text, "(?<![A-Za-z_])Label\\.new\\(\\)").size()
	widths.sort()
	raw_colours.sort()
	t.eq("UiDraw.width is gone; callers use UiFonts.width", widths, [])
	t.eq("ui_draw.gd has no width forwarder", SourceScan.search(t, sources.get("ui_draw.gd", ""), "(?m)^static func width\\(").size(), 0)
	t.eq("raw Color(\"...\") literals in src/ui live only in ui_tokens.gd", raw_colours, [])
	t.check("Label.new() in src/ui stays at or under %d" % LABEL_CEILING, labels <= LABEL_CEILING, "%d sites" % labels)

	var cid := "rivet"
	t.eq("OddsReadout.odds_for forwards to Parts.odds_for", OddsReadout.odds_for(["common", "rare"], cid), Parts.odds_for(["common", "rare"], cid))
	var odds := ItemGen.odds(["common", "rare"])
	t.eq("OddsReadout.text forwards to ItemGen.odds_text", OddsReadout.text(odds), ItemGen.odds_text(odds))
	t.eq("an empty odds table reads empty", ItemGen.odds_text([]), "")
