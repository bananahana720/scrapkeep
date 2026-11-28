extends SceneTree

const T := preload("res://tests/support/t.gd")
const Tile := preload("res://src/ui/caller_tile.gd")
const Palette := preload("res://src/core/palette.gd")
const Icons := preload("res://src/ui/icons.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")

# The caller's plate beside the speech bubble (caller_tile.gd): one glance says who is on the
# line.
#   W1  every named caller has a look, and the four kinds of hands are told apart by shape:
#       Moss is the hatch, a site crew a keeper's plate, Brindle a Fleet plate, the Mind the works.
#   W2  no two named callers share a colour and a mark.
#   P1  a pilot's plate wears the pilot's own colour and emblem.
#   P2  a pilot answers to their name ("sable") as well as their class id; Sable's plate wears her
#       screen colour, not mint (class_def.gd SABLE_SCREEN).
#   U1  a caller nobody drew stays down, so the bubble keeps the name in its words.
#   V1  the plate babbles for as long as the voice lasts and no longer.
#   S1  keeper and hatch share the rounded plate, the works' is a lozenge, and Brindle's is the Fleet's
#       scrap_frame hand plate.
#   C1  clear takes it down.

var _t := T.new("ui_caller_tile_test")


class Pilot:
	var id := ""
	var display_name := ""
	var color := Color.WHITE

	func _init(pilot_id: String, pilot_name: String, pilot_color: Color) -> void:
		id = pilot_id
		display_name = pilot_name
		color = pilot_color


func _initialize() -> void:
	var tile = Tile.new()
	root.add_child(tile)
	tile.pilots = [Pilot.new("tarn", "Tarn", Palette.RUST), Pilot.new("pylon_engineer", "Sable", Palette.ARC)]

	var hands := {}
	var seen := {}
	var twins := ""
	for id in Tile.CALLERS:
		var look: Dictionary = tile.look_of(id)
		hands[id] = String(look.get("hands", ""))
		var key := "%s/%s" % [look.get("icon", ""), Color(look.get("color", Color.BLACK)).to_html()]
		if seen.has(key):
			twins = "%s and %s" % [seen[key], id]
		seen[key] = id
	_t.check("W1 whose hands a caller is shows in the plate's shape", hands.get("moss") == "hatch" and hands.get("pump_crew") == "keeper"
			and hands.get("brindle") == "fleet" and hands.get("mind") == "works" and not hands.values().has(""), str(hands))
	_t.check("W2 no two named callers share a colour and a mark", twins == "", twins)

	var tarn: Dictionary = tile.look_of("tarn")
	_t.check("P1 a pilot's plate wears the pilot's colour and emblem", tarn.get("hands") == "keeper" and tarn.get("color") == Palette.RUST
			and tarn.get("icon") == Icons.class_icon_id("tarn"), str(tarn))

	var sable: Dictionary = tile.look_of("sable")
	_t.check("P2 a pilot answers to their name as well as their class", sable == tile.look_of("pylon_engineer") and sable.get("color") == ClassDef.SABLE_SCREEN
			and sable.get("icon") == Icons.class_icon_id("pylon_engineer"), str(sable))

	var up: bool = tile.present("nobody_drew_this", "Nobody", 2.0)
	_t.check("U1 a caller nobody drew stays down", not up and not tile.visible and tile.speaker == "", "up %s" % up)

	up = tile.present("brindle", "Brindle", 1.0)
	var at_once: bool = tile.talking()
	tile._process(0.5)
	var midway: bool = tile.talking()
	tile._process(0.6)
	_t.check("V1 the plate babbles while the voice lasts and no longer", up and tile.visible and at_once and midway and not tile.talking()
			and tile.hands() == "fleet", "at once %s, midway %s, after %s" % [at_once, midway, tile.talking()])

	var outlines := {}
	for whose in ["keeper", "hatch", "works"]:
		outlines[whose] = tile._plate(whose).size()
	var fleet: Array = tile._framed.map(func(box): return box.hand)
	_t.check("S1 keeper and hatch share the rounded plate, the works' lozenge is its own, and Brindle's is the Fleet's hand",
		outlines["keeper"] == outlines["hatch"] and outlines["works"] != outlines["keeper"] and fleet == [UiTokens.Hand.FLEET, UiTokens.Hand.FLEET],
		"%s fleet %s" % [outlines, fleet])

	tile.clear()
	_t.check("C1 clear takes it down", not tile.visible and tile.hands() == "" and not tile.talking(), "")
	var code: int = _t.verdict()
	tile.free()
	quit(code)
