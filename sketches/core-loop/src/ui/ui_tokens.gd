extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

# The menu and HUD tokens: one spacing scale, one type scale and five colours. Every size and
# gap the UI sets names one of these (ui_tokens_test scans the literal ones), and every plate, word, edge and ring the menus draw wears
# one of the five colours (an alpha of one counts as that colour). No gradients.
#
# The colour law (design-v3/LEGIBILITY.md section 1) and the item tiers (grey, mint, cobalt,
# pearl, gold, purple for the Mind) are a separate, ruled palette of meanings in palette.gd. A
# pilot's colour, a tier or a hazard stripe inside a card is meaning, not chrome, and keeps it.
#
# Sizes are at the project's 1600x900 canvas; the canvas stretch scales them with the window.

# Spacing scale, in px. Gaps, padding and separations take one of these.
const GAP_XS := 4
const GAP_S := 8
const GAP_M := 12
const GAP_L := 16
const GAP_XL := 24
const GAP_XXL := 32
const GAP_XXXL := 48
# The scale as one list, for a check that a size sits on it.
const SPACE := [0, GAP_XS, GAP_S, GAP_M, GAP_L, GAP_XL, GAP_XXL, GAP_XXXL]

# Type scale, in px. Five steps; nothing smaller than CAPTION. CAPTION is 15 so the smallest
# word is 18 px at 1080p and 12 px on a 1280x720 window (Andrew's pick, 13 Nov 2026;
# tests/ui_text_floor_test.gd holds both floors).
const CAPTION := 15
const BODY := 18
const LABEL := 22
const HEADING := 32
const DISPLAY := 56
const TYPE := [CAPTION, BODY, LABEL, HEADING, DISPLAY]

# The five colours.
const INK := Palette.CHARCOAL # plates and the ground under words
const TEXT := Palette.SAND # words, key caps and neutral marks; the focus ring
const ACCENT := Palette.AMBER # the primary choice, the chosen tab, a press
const LINE := Color("5f8f8a") # a plate's edge: verdigris lifted to 4:1 on INK
const ALERT := Palette.HAZARD # an error or a choice that asks before it acts
const COLORS := [INK, TEXT, ACCENT, LINE, ALERT]
const THEME_PATH := "res://assets/ui/scrapkeep_theme.tres"

# Derived states, each one of the five at an alpha.
const PLATE_ALPHA := 0.92
const DISABLED_ALPHA := 0.45
# The smallest target a pointer or a touch screen gets: 56 px on the 1600x900 canvas, so it is 44 px or
# more on the smallest supported window (1280x720 and the Steam Deck's 1280x800 draw the canvas at 0.8).
const TARGET := 56.0
const RADIUS := 6
# Less motion (Game.set_reduced_motion keeps it current): menu motion that only celebrates or
# waits holds still.
static var reduced_motion := false
const EDGE := 2
const FOCUS_EDGE := 3


# Secondary words (a hint, a locked or unknown entry, the build stamp) step back to QUIET_ALPHA,
# the faintest a word may be and still hold 4.5:1 on a plate (TEXT at 0.7 is 4.98:1).
const QUIET_ALPHA := 0.7


static func quiet(color := TEXT) -> Color:
	return Color(color, QUIET_ALPHA)


static func disabled(color: Color) -> Color:
	return Color(color, DISABLED_ALPHA)


# The four hands (LEGIBILITY.md section 14.3, ruling ek): every screen, card and plate is drawn in the
# hand of whoever made the thing it shows, and ScrapFrame draws all four. A row is that hand's fill, edge,
# words ("ink", and "quiet" for secondary words), its smallest word and its motion: "tilt" is the most a
# plate leans, in radians, and "trans" the Tween transition its frames move on. The five colours above are
# the Keeper's menus; a row's colours are the only others a frame wears. Every ink and quiet holds 4.5:1
# on its fill (hand_frame_test).
#   - Mint (Palette.ARC) is press now, so no row has it.
#   - Brass is the Fleet's alone.
#   - Purple is the Kindness's alone: "kindness_seam", on an old-works frame that asks for it.
enum Hand { KEEPER, FLEET, OLD_WORKS, ROGUE }

const HANDS := {
	# Cut plates, rivets and tape, a little crooked: copper on charcoal, ledger cream words. Never brass.
	Hand.KEEPER: {"fill": Palette.CHARCOAL, "edge": Palette.COPPER, "ink": Palette.LEDGER_CREAM, "quiet": Palette.SAND,
		"caption": CAPTION, "tilt": 0.012, "trans": Tween.TRANS_BACK},
	# Standard issue: a brass bezel on iron oxide (RUST taken dark enough for words), one notched corner.
	Hand.FLEET: {"fill": Color("3e2219"), "edge": Palette.BRASS, "ink": Palette.SAND, "quiet": Palette.BRASS,
		"caption": CAPTION, "tilt": 0.0, "trans": Tween.TRANS_QUAD},
	# Cast in one piece: dark petrol enamel, a glass lip, a uranium-green seam, straight-line motion only.
	Hand.OLD_WORKS: {"fill": Color("10262a"), "edge": Color("4d8088"), "ink": Color("e6eeea"), "quiet": Palette.STEEL,
		"seam": Palette.ANCIENT, "kindness_seam": Palette.KINDNESS, "caption": CAPTION, "tilt": 0.0, "trans": Tween.TRANS_LINEAR},
	# A bare casting with a stencilled number: sand corner ticks on near black, no words.
	Hand.ROGUE: {"fill": Color("161918"), "edge": Palette.SAND, "ink": Palette.SAND, "quiet": Palette.STEEL,
		"caption": CAPTION, "tilt": 0.0, "trans": Tween.TRANS_LINEAR},
}


# A hand's row. With less motion on, nothing leans and nothing overshoots.
static func hand(which: int) -> Dictionary:
	var row: Dictionary = HANDS[which].duplicate()
	if reduced_motion:
		row.tilt = 0.0
		row.trans = Tween.TRANS_LINEAR
	return row


# The type step nearest a size, for a size that is computed rather than chosen.
static func type_step(px: float) -> int:
	var best: int = TYPE[0]
	for step in TYPE:
		if absf(step - px) < absf(best - px):
			best = step
	return best


# A plate: INK under an edge. Focus draws the ring alone, over the normal plate.
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


# The focus ring stands just outside the plate, so a field's own edge (waiting, refused) still shows
# inside it. Content margins match a plate's, so a button's words do not move when it takes focus.
static func focus_ring(left := float(GAP_L)) -> StyleBoxFlat:
	var box := plate(TEXT, FOCUS_EDGE, false)
	box.content_margin_left = left
	box.set_expand_margin_all(FOCUS_EDGE + 1.0)
	return box


# The theme every control starts from (THEME_PATH, the project's gui/theme/custom; write it with
# tools/ui_theme_build.gd after a token changes, and ui_tokens_test checks it matches). A control that sets its own
# override keeps it; one that sets nothing reads these, so a bare Label or Button made anywhere
# in the UI lands on the scale and the five colours.
static func theme() -> Theme:
	# No default font: a theme that holds the vendored font keeps it loaded past the engine's own
	# resource check at exit. Every word the UI draws names UiFonts itself.
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
	# Scroll bars: a line-coloured grabber in an ink track, wide enough to drag.
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


# The WCAG 2.2 contrast ratio of two opaque colours: 4.5:1 for words, 3:1 for edges and marks.
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)
