extends SceneTree

const RadioDial := preload("res://src/ui/radio_dial.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

# PF-34 (w37 film 012): the swollen radio plate cut its station's blurb mid-word ("Moss's stock
# of the house band, played however th"). Every station's blurb wraps at a word onto at most
# BLURB_LINES lines, the last line ends inside the plate, and the swollen plate still ends inside
# the top band at the project's 1600 x 900.

var _t := preload("res://tests/support/t.gd").new("radio_dial_blurb_test")


func _initialize() -> void:
	var font := UiFonts.bold()
	var line_h := font.get_height(UiTokens.CAPTION)
	var worst := 0
	var long := ""
	for id in RadioTakes.station_ids():
		var blurb := String(RadioTakes.station(id).get("blurb", ""))
		var lines := RadioDial.blurb_lines(blurb)
		if lines > worst:
			worst = lines
			long = blurb
	_t.check("planted: the longest blurb does not fit one line", font.get_string_size(long, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.CAPTION).x > RadioDial.SWOLLEN.x - 24.0, long)
	_t.check("every station's blurb fits its lines, wrapped at a word", worst >= 1 and worst <= RadioDial.BLURB_LINES, "%d lines: %s" % [worst, long])
	var bottom := RadioDial.BLURB_Y + (RadioDial.BLURB_LINES - 1) * line_h + font.get_descent(UiTokens.CAPTION)
	_t.check("the last blurb line ends inside the plate", bottom <= RadioDial.SWOLLEN.y, "line foot %.1f, plate %.1f" % [bottom, RadioDial.SWOLLEN.y])
	var top := ScreenRegions.rect("top", Vector2(1600.0, 900.0))
	# radio_dial.gd _process: the plate hangs 12 px under the top band's top edge.
	_t.check("the swollen plate ends inside the top band", top.position.y + 12.0 + RadioDial.SWOLLEN.y <= top.end.y, "plate foot %.1f, band %.1f" % [top.position.y + 12.0 + RadioDial.SWOLLEN.y, top.end.y])
	quit(_t.verdict())
