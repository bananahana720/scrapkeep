extends RefCounted

const SourceScan := preload("res://tests/support/source_scan.gd")

const OWNER := "res://src/game.gd"
const HOLD_WRITE := "(?:\\bget_tree\\(\\)|\\btree\\(\\)|\\btree)\\s*\\.\\s*(?:paused\\s*=(?!=)|set_pause\\s*\\()|\\bkeyboard\\s*\\.\\s*enabled\\s*=(?!=)"
const WRITES := [
	"get_tree().paused = true",
	"\tget_tree().paused = pause or game.pause_toggled()",
	"tree.paused = false",
	"tree().paused=true",
	"get_tree().set_pause(true)",
	"game.keyboard.enabled = false",
	"\t\tkeyboard.enabled = ctx.flow.in_play()",
]
const READS := [
	"if get_tree().paused == true:",
	"var held := tree.paused",
	"clock.paused = shop.clock_paused()",
	"if keyboard.enabled == live:",
	"keyboard.held = on",
]


func run(t) -> void:
	t.eq("the only script under src that sets the tree's pause or the keyboard switch is the owner",
		SourceScan.matching(t, ["res://src"], HOLD_WRITE), [OWNER])
	var caught: Array[String] = []
	for line in WRITES:
		if not SourceScan.search(t, line, HOLD_WRITE).is_empty():
			caught.append(line)
	t.eq("the pattern catches every way a script sets them", caught, WRITES)
	var missed: Array[String] = []
	for line in READS:
		if not SourceScan.search(t, line, HOLD_WRITE).is_empty():
			missed.append(line)
	t.eq("the pattern passes reads, other clocks and the dev hold", missed, [])
