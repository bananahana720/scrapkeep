extends SceneTree

const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const T := preload("res://tests/support/t.gd")

# Text is readable on the smallest screen (UI principle P4, design-v3/ui-audit/principles.json).
# The type scale is set on the project canvas; the canvas stretch scales it with the window, so
# a step's size on a real screen is step * window height / canvas height.
#   - every type step is 18 px or more at 1080p (Xbox Accessibility Guideline 101: PC text at
#     1080p is 18 px or more);
#   - every step is 12 px or more on the smallest supported window (1280x720; the Steam Deck
#     compatibility rule recommends 12 px at 1280x800, which draws the same canvas scale, and
#     never under 9);
#   - a keycap's letters are never smaller than the smallest step, whatever height a caller
#     asks for, and the cap is tall enough to hold them (finding UF-05);
#   - planted: a 14 px step fails the PC floor and a 10 px step the Deck minimum.
# ui_tokens_test already fails a literal size off the scale, so no step below CAPTION exists.

const SMALLEST_WINDOW_H := 720.0
const DECK_MIN_PX := 9.0
const DECK_PX := 12.0
const PC_FLOOR_PX := 18.0

var _t := T.new("ui_text_floor_test")


func _initialize() -> void:
	var canvas_h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var small := SMALLEST_WINDOW_H / canvas_h
	var hd := 1080.0 / canvas_h
	var least: int = UiTokens.TYPE.min()
	_t.eq("CAPTION is the smallest step", least, UiTokens.CAPTION)
	_t.check("the smallest step holds the PC floor at 1080p", least * hd >= PC_FLOOR_PX, "%.1f px" % (least * hd))
	_t.check("the smallest step holds the Deck's recommended size on the smallest window", least * small >= DECK_PX, "%.1f px" % (least * small))
	_t.eq("the theme's default size is BODY", UiTokens.theme().default_font_size, UiTokens.BODY)
	for height in [8.0, 15.0, 20.0, 24.0, 30.0, 48.0]:
		var letters := Keycap.font_size(height)
		_t.check("a %.0f px keycap's letters hold the smallest step" % height, letters >= least, "%d px" % letters)
		_t.check("a %.0f px keycap is tall enough for its letters" % height, Keycap.size_of("key_ctrl", height).y >= letters, "%.0f px tall" % Keycap.size_of("key_ctrl", height).y)
	_t.check("planted: a 14 px step fails the PC floor", 14 * hd < PC_FLOOR_PX)
	_t.check("planted: a 10 px step fails the Deck minimum", 10 * small < DECK_MIN_PX)
	quit(_t.verdict())
