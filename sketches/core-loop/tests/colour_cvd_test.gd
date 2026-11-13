extends SceneTree

const Meanings := preload("res://src/core/colour_meanings.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

# Colour never works alone (UI principle P2, design-v3/ui-audit/principles.json; WCAG 1.4.1).
# Every colour that carries a meaning (colour_meanings.gd: MEANINGS and REWARD_RUNGS) is compared
# with every other under full protanopia, deuteranopia and tritanopia (Machado, Oliveira and
# Fernandes 2009, severity 1.0, in linear RGB) and with normal sight. A pair whose CIE76
# difference falls under FLOOR for any eye reads as one colour to that eye, so the two facts
# need a second carrier (a shape, an icon, a pattern, a place). Such a pair must have a CLOSE
# row naming that carrier, or the open finding that asks for one.
#   - a close pair with no row fails: a new colour, or a moved one, cannot land silently;
#   - a row whose pair is no longer close fails, so a fixed pair deletes its row;
#   - planted: two near-equal greens are caught, and red and blue are not.
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
	"AMBER|BRASS": {"carrier": "", "finding": "UF-02"},
	"AMBER|HAZARD": {"carrier": "", "finding": "UF-03"},
	"BRASS|HAZARD": {"carrier": "", "finding": "UF-03"},
	"ANCIENT|ARC": {"carrier": "ancient seams carry a pattern cue (material_slots.gd, the pattern field)", "finding": ""},
}

var _t := T.new("colour_cvd_test")


func _initialize() -> void:
	var names := {}
	for name in Meanings.MEANINGS.values() + Meanings.REWARD_RUNGS.values():
		names[name] = true
	var sorted := names.keys()
	sorted.sort()
	var palette: Dictionary = (Palette as GDScript).get_script_constant_map()
	_t.check("the meanings name seven or more palette colours", sorted.size() >= 7, str(sorted.size()))
	var close := {}
	for i in sorted.size():
		for j in range(i + 1, sorted.size()):
			var worst := closest(palette[sorted[i]], palette[sorted[j]])
			if worst["de"] < FLOOR:
				close["%s|%s" % [sorted[i], sorted[j]]] = worst
	for key in close:
		_t.check("%s is close (%s %.1f) and has a row" % [key, close[key]["sight"], close[key]["de"]], CLOSE.has(key))
	for key in CLOSE:
		_t.check("the row %s still names a close pair" % key, close.has(key), "delete the row when the pair is fixed")
		var row: Dictionary = CLOSE[key]
		_t.check("the row %s names a carrier or a finding" % key, row["carrier"] != "" or row["finding"] != "")
	_t.check("planted: two near-equal greens are close", closest(Color("9dff3c"), Color("a5f548"))["de"] < FLOOR)
	_t.check("planted: red and blue are not close", closest(Color("ff0000"), Color("0000ff"))["de"] >= FLOOR)
	quit(_t.verdict())


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
