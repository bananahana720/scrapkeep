extends SceneTree

const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")

# The scrap look's colour rule ("HUD look: scrapped together, clean to read"): wear is
# a value shift of a part's own colour, never a new hue, so the class colour stays the
# one "yours" accent; and a stamped tag holds its words whole.

var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	var worst_hue := 0.0
	var worst_sat := 0.0
	var worst_value := 0.0
	var tones := [Color("8bf0d3"), Color("b77843"), Color("e5a044"), Palette.SAND, Palette.HAZARD]
	for tone in tones:
		for serial in 60:
			var worn := ScrapFrame.wear(tone, serial * 7919)
			worst_hue = maxf(worst_hue, absf(angle_difference(worn.h * TAU, tone.h * TAU)) / TAU)
			worst_sat = maxf(worst_sat, absf(worn.s - tone.s))
			worst_value = maxf(worst_value, absf(worn.v / tone.v - 1.0))
	_report("wear keeps the hue", worst_hue < 0.002 and worst_sat < 0.002 and worst_value <= 0.1001,
		"over %d parts: hue moved %.4f, saturation %.4f, value up to %.1f%%" % [tones.size() * 60, worst_hue, worst_sat, worst_value * 100.0])

	var font := UiFonts.bold()
	var rect := ScrapFrame.stamp_rect(ScrapFrame.tag(Palette.AMBER, 3), "outpunch plating", font, 18, Vector2(200.0, 50.0))
	var text_w := font.get_string_size("outpunch plating", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	_report("tag holds its words", rect.size.x >= text_w + 10.0 and rect.size.y >= font.get_height(18) and absf(rect.get_center().x - 200.0) < 0.5,
		"tag %s for words %.0f px wide" % [rect, text_w])

	print("ui_scrap_frame_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
