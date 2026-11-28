extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")
const LOWER_DIRS: Array[String] = [
	"res://src/core", "res://src/build", "res://src/combat", "res://src/boss", "res://src/movement", "res://src/world",
]
const UI_DIR := "res://src/ui/"
const UI_LEAVES: Array[String] = ["glyphs.gd", "word_budget.gd", "why_callout.gd"]
const FLOW_PATH := "res://src/core/flow.gd"


func run(t) -> void:
	t.check("glyphs.gd lives in src/core", FileAccess.file_exists("res://src/core/glyphs.gd"))
	t.check("glyphs.gd is gone from src/ui", not FileAccess.file_exists(UI_DIR + "glyphs.gd"))
	t.check("word_budget.gd lives in src/core", FileAccess.file_exists("res://src/core/word_budget.gd"))
	for name in UI_LEAVES:
		var leaf: String = UI_DIR + name
		var quoted := "[\"']" + leaf.replace(".", "\\.") + "[\"']"
		for root in LOWER_DIRS:
			t.eq("no %s names %s" % [root, leaf], SourceScan.matching(t, [root], quoted), [])

	var declares := "(?m)^\\s*(static\\s+)?func\\s+warden_fight_live\\b"
	t.eq("flow.gd declares warden_fight_live", SourceScan.matching(t, ["res://src/core"], declares).filter(
		func(p: String) -> bool: return p == FLOW_PATH), [FLOW_PATH])
	var others := SourceScan.matching(t, ["res://src", "res://tools"], declares).filter(
		func(p: String) -> bool: return p != FLOW_PATH)
	t.eq("only flow.gd declares warden_fight_live", others, [])
