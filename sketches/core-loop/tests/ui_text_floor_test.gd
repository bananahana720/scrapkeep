extends SceneTree

const UiTokens := preload("res://src/ui/ui_tokens.gd")
const T := preload("res://tests/support/t.gd")

# Text is readable on the smallest screen (UI principle P4, design-v3/ui-audit/principles.json).
# The type scale is set on the project canvas; the canvas stretch scales it with the window, so
# a step's size on a real screen is step * window height / canvas height.
#   - the smallest step is 9 px or more on the smallest supported window (1280x720; the Steam
#     Deck compatibility rule's hard minimum at 1280x800, which draws the same canvas scale);
#   - BODY, the default for a bare Label, is 18 px or more at 1080p (Xbox Accessibility
#     Guideline 101: PC text at 1080p is 18 px or more);
#   - CAPTION is under that 18 px today (finding UF-01). Until it is raised, the number of
#     places that use CAPTION may fall and never rise, so no new small text lands;
#   - planted: a 10 px step fails the Deck floor.
# ui_tokens_test already fails a literal size off the scale, so no step below CAPTION exists.

const SMALLEST_WINDOW_H := 720.0
const DECK_FLOOR_PX := 9.0
const PC_FLOOR_PX := 18.0
# Uses of UiTokens.CAPTION under src/, counted 13 Nov 2026 on stage/alpha-w40. Lower it when a
# use goes; the test fails a count above it and a ceiling left above the count.
const CAPTION_USES := 34

var _t := T.new("ui_text_floor_test")


func _initialize() -> void:
	var canvas_h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var small := SMALLEST_WINDOW_H / canvas_h
	var hd := 1080.0 / canvas_h
	_t.check("the smallest step holds the Deck floor on the smallest window", on_screen(UiTokens.TYPE.min(), small) >= DECK_FLOOR_PX, "%.1f px" % on_screen(UiTokens.TYPE.min(), small))
	_t.check("BODY holds the PC floor at 1080p", on_screen(UiTokens.BODY, hd) >= PC_FLOOR_PX, "%.1f px" % on_screen(UiTokens.BODY, hd))
	_t.eq("the theme's default size is BODY", UiTokens.theme().default_font_size, UiTokens.BODY)
	if on_screen(UiTokens.CAPTION, hd) >= PC_FLOOR_PX:
		_t.check("CAPTION now holds the PC floor: delete CAPTION_USES and close UF-01", CAPTION_USES == 0)
	else:
		var uses := _count("res://src", "UiTokens.CAPTION")
		_t.check("no new use of CAPTION (%.1f px at 1080p, under %.0f)" % [on_screen(UiTokens.CAPTION, hd), PC_FLOOR_PX], uses <= CAPTION_USES, "%d uses, ceiling %d" % [uses, CAPTION_USES])
		_t.check("the ceiling follows the count down", uses >= CAPTION_USES, "%d uses, ceiling %d: lower CAPTION_USES" % [uses, CAPTION_USES])
	_t.check("planted: a 10 px step fails the Deck floor", on_screen(10, small) < DECK_FLOOR_PX)
	quit(_t.verdict())


static func on_screen(step: float, scale: float) -> float:
	return step * scale


func _count(dir: String, needle: String) -> int:
	var total := 0
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			total += FileAccess.get_file_as_string(dir.path_join(name)).count(needle)
	for sub in DirAccess.get_directories_at(dir):
		total += _count(dir.path_join(sub), needle)
	return total
