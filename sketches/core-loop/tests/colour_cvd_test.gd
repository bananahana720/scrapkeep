extends SceneTree

const Meanings := preload("res://src/core/colour_meanings.gd")
const Palette := preload("res://src/core/palette.gd")
const ShopTile := preload("res://src/ui/shop_tile.gd")
const T := preload("res://tests/support/t.gd")

# Colour never works alone (UI principle P2, design-v3/ui-audit/principles.json; WCAG 1.4.1).
# Every colour that carries a meaning (colour_meanings.gd: MEANINGS and REWARD_RUNGS) is compared
# with every other under full protanopia, deuteranopia and tritanopia (Machado, Oliveira and
# Fernandes 2009, severity 1.0, in linear RGB) and with normal sight. A pair whose CIE76
# difference falls under FLOOR for any eye reads as one colour to that eye, so the two facts
# need a second carrier (a shape, an icon, a pattern, a place). Such a pair must have a CLOSE
# row naming that carrier, or the open finding that asks for one.
#   - a close pair with no row fails: a new colour, or a moved one, cannot land silently;
#   - one colour named for two facts needs a SHARED row the same way;
#   - a row whose pair is no longer close fails, so a fixed pair deletes its row;
#   - planted: a made-up palette with each of those faults is failed by the same judge.
#
# FLOOR is ours, not a standard (inferred): 20 is about where two flat swatches a few pixels
# wide stop being told apart at a glance. palette.gd's 9 Oct cobalt measure used 31 for a rung
# that must read alone; 20 is the floor for "needs a second carrier".

const FLOOR := 20.0
const SIGHTS := {
	"normal": [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	"protan": [Vector3(0.152286, 1.052583, -0.204868), Vector3(0.114503, 0.786281, 0.099216), Vector3(-0.003882, -0.048116, 1.051998)],
	"deutan": [Vector3(0.367322, 0.860646, -0.227968), Vector3(0.280085, 0.672501, 0.047413), Vector3(-0.011820, 0.042940, 0.968881)],
	"tritan": [Vector3(1.255528, -0.076749, -0.178779), Vector3(-0.078411, 0.930809, 0.147602), Vector3(0.004733, 0.691367, 0.303900)],
}
# Pairs under FLOOR today (measured 13 Nov 2026 on stage/alpha-w40), keyed "A|B" in palette
# name order. `carrier` is what tells the two facts apart without colour; a row with no carrier
# yet names its finding in project-guide/handoff/UI-FINDINGS.tsv.
const CLOSE := {
	"AMBER|BRASS": {"carrier": "a relic reward's frame is doubled with bolt heads (shop_tile.gd RARITY, checked below); a boss's ground warning carries rim ticks (threat_grammar.gd, the owner mark)", "finding": ""},
	"AMBER|HAZARD": {"carrier": "", "finding": "UF-03"},
	"BRASS|HAZARD": {"carrier": "", "finding": "UF-03"},
	"ANCIENT|ARC": {"carrier": "ancient seams carry a pattern cue (material_slots.gd, the pattern field)", "finding": ""},
}

# One palette colour named for two facts: the same question with a difference of zero.
const SHARED := {
	"ARC": {"carrier": "the common reward is the one single-line frame on a tile (shop_tile.gd RARITY, checked below); live is drawn on an enemy part or a key, never in a frame", "finding": ""},
}

var _t := T.new("colour_cvd_test")


func _initialize() -> void:
	var palette: Dictionary = (Palette as GDScript).get_script_constant_map()
	var facts := {}
	for table in [Meanings.MEANINGS, Meanings.REWARD_RUNGS]:
		for fact in table:
			facts[fact] = table[fact]
	var colours := {}
	for fact in facts:
		colours[facts[fact]] = true
	_t.check("the meanings name seven or more colours", colours.size() >= 7, str(colours.size()))
	_t.eq("every close pair and shared colour has a row, and every row is still needed", faults(facts, palette, CLOSE, SHARED), [])
	# Planted, through the same judge: a close pair with no row, a shared colour with no row, a
	# row whose pair is far apart, and a row with neither a carrier nor a finding.
	var fake := {"A": Color("9dff3c"), "B": Color("a5f548"), "C": Color("0000ff")}
	var planted := faults({"one": "A", "two": "B", "three": "A", "four": "C"}, fake, {"A|C": {"carrier": "", "finding": ""}}, {})
	_t.eq("planted: the judge names four faults", planted.size(), 4)
	for want in ["A|B is close", "A carries one and three", "the CLOSE row A|C no longer", "the row A|C names neither"]:
		_t.check("planted: one fault reads \"%s\"" % want, planted.any(func(line: String) -> bool: return line.begins_with(want)))
	_t.check("planted: red and blue are not close", closest(Color("ff0000"), Color("0000ff"))["de"] >= FLOOR)
	# The carriers the rows above name, held here: every reward rung's frame differs from every
	# other by shape, the common rung is the only single line, and the relic rung has bolt heads.
	_t.eq("every reward rung has a frame", frame_faults(Meanings.REWARD_RUNGS.keys(), ShopTile.RARITY), [])
	_t.check("the common reward is the one single-line frame", _single_lines(ShopTile.RARITY) == ["common"], str(_single_lines(ShopTile.RARITY)))
	_t.eq("the relic reward's frame carries bolt heads", ShopTile.RARITY["relic"]["notches"], "bolt")
	var twins := {"a": {"color": Color.RED, "width": 2.0, "double": false, "notches": "", "dashed": false},
		"b": {"color": Color.BLUE, "width": 2.0, "double": false, "notches": "", "dashed": false}}
	_t.eq("planted: two frames that differ only by colour are named", frame_faults(["a", "b", "c"], twins), ["a and b differ by colour alone", "c has no frame"])
	quit(_t.verdict())


# facts is fact -> palette name. Every pair of names under FLOOR needs a close row, every name
# carrying two facts needs a shared row, and every row must still be needed and say what to do.
static func faults(facts: Dictionary, palette: Dictionary, close_rows: Dictionary, shared_rows: Dictionary) -> Array:
	var out := []
	var uses := {}
	for fact in facts:
		uses[facts[fact]] = uses.get(facts[fact], []) + [fact]
	var names := uses.keys()
	names.sort()
	var close := {}
	for i in names.size():
		for j in range(i + 1, names.size()):
			var worst := closest(palette[names[i]], palette[names[j]])
			if worst["de"] < FLOOR:
				close["%s|%s" % [names[i], names[j]]] = worst
	for key in close:
		if not close_rows.has(key):
			out.append("%s is close (%s %.1f) and has no CLOSE row" % [key, close[key]["sight"], close[key]["de"]])
	for name in names:
		if uses[name].size() > 1 and not shared_rows.has(name):
			out.append("%s carries %s and has no SHARED row" % [name, " and ".join(uses[name])])
	for key in close_rows:
		if not close.has(key):
			out.append("the CLOSE row %s no longer names a close pair: delete it" % key)
	for key in shared_rows:
		if uses.get(key, []).size() < 2:
			out.append("the SHARED row %s no longer names a colour with two facts: delete it" % key)
	for rows in [close_rows, shared_rows]:
		for key in rows:
			if rows[key]["carrier"] == "" and rows[key]["finding"] == "":
				out.append("the row %s names neither a carrier nor a finding" % key)
	return out


# Reward frames (shop_tile.gd RARITY rows): each rung needs one, and no two may differ by colour alone.
static func frame_faults(rungs: Array, frames: Dictionary) -> Array:
	var out := []
	var have := []
	for rung in rungs:
		if frames.has(rung):
			have.append(rung)
	for i in have.size():
		for j in range(i + 1, have.size()):
			if _shape(frames[have[i]]) == _shape(frames[have[j]]):
				out.append("%s and %s differ by colour alone" % [have[i], have[j]])
	for rung in rungs:
		if not frames.has(rung):
			out.append("%s has no frame" % rung)
	return out


static func _shape(frame: Dictionary) -> Array:
	return [frame["width"], frame["double"], frame["notches"], frame["dashed"]]


static func _single_lines(frames: Dictionary) -> Array:
	var out := []
	for rung in frames:
		if not frames[rung]["double"]:
			out.append(rung)
	return out


# The eye that separates two colours least, and by how much.
static func closest(a: Color, b: Color) -> Dictionary:
	var out := {"sight": "", "de": INF}
	for sight in SIGHTS:
		var de := _lab(_see(a, SIGHTS[sight])).distance_to(_lab(_see(b, SIGHTS[sight])))
		if de < out["de"]:
			out = {"sight": sight, "de": de}
	return out


static func _see(c: Color, m: Array) -> Vector3:
	var l := c.srgb_to_linear()
	var v := Vector3(l.r, l.g, l.b)
	return Vector3(clampf(m[0].dot(v), 0.0, 1.0), clampf(m[1].dot(v), 0.0, 1.0), clampf(m[2].dot(v), 0.0, 1.0))


# Linear RGB to CIE L*a*b* (D65).
static func _lab(v: Vector3) -> Vector3:
	var x := _f((0.4124 * v.x + 0.3576 * v.y + 0.1805 * v.z) / 0.95047)
	var y := _f(0.2126 * v.x + 0.7152 * v.y + 0.0722 * v.z)
	var z := _f((0.0193 * v.x + 0.1192 * v.y + 0.9505 * v.z) / 1.08883)
	return Vector3(116.0 * y - 16.0, 500.0 * (x - y), 200.0 * (y - z))


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
