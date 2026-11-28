extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const Comfort := preload("res://src/core/comfort.gd")


const GAP_XS := 4
const GAP_S := 8
const GAP_M := 12
const GAP_L := 16
const GAP_XL := 24
const GAP_XXL := 32
const GAP_XXXL := 48
const SPACE := [0, GAP_XS, GAP_S, GAP_M, GAP_L, GAP_XL, GAP_XXL, GAP_XXXL]

const CAPTION := 15
const BODY := 18
const LABEL := 22
const HEADING := 32
const DISPLAY := 56
const TYPE := [CAPTION, BODY, LABEL, HEADING, DISPLAY]

const INK := Palette.CHARCOAL
const TEXT := Palette.SAND
const ACCENT := Palette.AMBER
const LINE := Color("5f8f8a")
const ALERT := Palette.HAZARD
const COLORS := [INK, TEXT, ACCENT, LINE, ALERT]
const THEME_PATH := "res://assets/ui/scrapkeep_theme.tres"

const TAG_INK := Color("121514")
const COMIC_INK := Color("242a28")
const BONE := Color("f3ecdc")
const GLASS_WARM := Color("2a2420")
const FLEET_FILL := Color("3e2219")
const OLD_WORKS_FILL := Color("10262a")
const OLD_WORKS_EDGE := Color("4d8088")
const OLD_WORKS_INK := Color("e6eeea")
const ROGUE_FILL := Color("161918")

const PLATE_ALPHA := 0.92
const DISABLED_ALPHA := 0.45
const TARGET := 56.0
const RADIUS := 6
const EDGE := 2
const FOCUS_EDGE := 3


const QUIET_ALPHA := 0.7


static func quiet(color := TEXT) -> Color:
	return Color(color, QUIET_ALPHA)


static func disabled(color: Color) -> Color:
	return Color(color, DISABLED_ALPHA)


enum Hand { KEEPER, FLEET, OLD_WORKS, ROGUE }

const HANDS := {
	Hand.KEEPER: {"fill": Palette.CHARCOAL, "edge": Palette.COPPER, "ink": Palette.LEDGER_CREAM, "quiet": Palette.SAND,
		"caption": CAPTION, "tilt": 0.012, "trans": Tween.TRANS_BACK},
	Hand.FLEET: {"fill": FLEET_FILL, "edge": Palette.BRASS, "ink": Palette.SAND, "quiet": Palette.BRASS,
		"caption": CAPTION, "tilt": 0.0, "trans": Tween.TRANS_QUAD},
	Hand.OLD_WORKS: {"fill": OLD_WORKS_FILL, "edge": OLD_WORKS_EDGE, "ink": OLD_WORKS_INK, "quiet": Palette.STEEL,
		"seam": Palette.ANCIENT, "kindness_seam": Palette.KINDNESS, "caption": CAPTION, "tilt": 0.0, "trans": Tween.TRANS_LINEAR},
	Hand.ROGUE: {"fill": ROGUE_FILL, "edge": Palette.SAND, "ink": Palette.SAND, "quiet": Palette.STEEL,
		"caption": CAPTION, "tilt": 0.0, "trans": Tween.TRANS_LINEAR},
}


static func hand(which: int) -> Dictionary:
	var row: Dictionary = HANDS[which].duplicate()
	if Comfort.reduced_motion:
		row.tilt = 0.0
		row.trans = Tween.TRANS_LINEAR
	return row


static func type_step(px: float) -> int:
	var best: int = TYPE[0]
	for step in TYPE:
		if absf(step - px) < absf(best - px):
			best = step
	return best


static func plate(edge: Color, width := EDGE, fill := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = fill
	box.bg_color = Color(INK, PLATE_ALPHA)
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(RADIUS)
	box.corner_detail = 1
	box.content_margin_left = GAP_L
	box.content_margin_right = GAP_L
	box.content_margin_top = GAP_S
	box.content_margin_bottom = GAP_S
	return box


static func focus_ring(left := float(GAP_L)) -> StyleBoxFlat:
	var box := plate(TEXT, FOCUS_EDGE, false)
	box.content_margin_left = left
	box.set_expand_margin_all(FOCUS_EDGE + 1.0)
	return box


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = BODY
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(INK, 0.85))
	for kind in ["Button", "CheckBox", "OptionButton"]:
		t.set_font_size("font_size", kind, LABEL)
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, TEXT)
		t.set_color("font_focus_color", kind, TEXT)
		t.set_color("font_pressed_color", kind, ACCENT)
		t.set_color("font_disabled_color", kind, disabled(TEXT))
		t.set_stylebox("normal", kind, plate(LINE))
		t.set_stylebox("hover", kind, plate(TEXT))
		t.set_stylebox("pressed", kind, plate(ACCENT, FOCUS_EDGE))
		t.set_stylebox("disabled", kind, plate(disabled(LINE)))
		t.set_stylebox("focus", kind, focus_ring())
	for bar in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(INK, PLATE_ALPHA)
		track.set_corner_radius_all(RADIUS)
		track.set_content_margin_all(GAP_XS)
		t.set_stylebox("scroll", bar, track)
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var grab := StyleBoxFlat.new()
			grab.bg_color = {"grabber": LINE, "grabber_highlight": TEXT, "grabber_pressed": ACCENT}[state]
			grab.set_corner_radius_all(RADIUS)
			grab.set_content_margin_all(GAP_XS)
			t.set_stylebox(state, bar, grab)
	var panel := plate(LINE)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	return t


static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)
