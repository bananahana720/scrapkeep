extends Control

const Keycap := preload("res://src/ui/keycap.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

# One line of keycaps and words ("1 to 6 choose · Enter start"), drawn with the title's
# keycap so a key looks the same on every screen. A part with a "cap" draws that key and
# says its "say"; a part with only "say" is plain words. The credits' skip hint and the
# class select's footer both read their words from the same part list they draw.

const CAP_H := 24.0
const FONT := UiTokens.BODY
const GAP := float(UiTokens.GAP_S)

var parts: Array = []


func setup(rows: Array) -> void:
	parts = rows
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_width(), CAP_H + 8.0)
	queue_redraw()


func text() -> String:
	var said := PackedStringArray()
	for part in parts:
		said.append(String(part["say"]))
	return " ".join(said)


func _width() -> float:
	var total := 0.0
	for part in parts:
		total += _part_width(part) + GAP
	return maxf(0.0, total - GAP)


func _part_width(part: Dictionary) -> float:
	if part.has("cap"):
		return Keycap.size_of(String(part["cap"]), CAP_H).x
	return UiFonts.width(String(part["say"]), FONT)


func _draw() -> void:
	var x := (size.x - _width()) * 0.5
	var mid := size.y * 0.5
	var font := UiFonts.bold()
	for part in parts:
		var w := _part_width(part)
		if part.has("cap"):
			Keycap.draw(self, Vector2(x + w * 0.5, mid), String(part["cap"]), Palette.SAND, CAP_H)
		else:
			var baseline := mid + (font.get_ascent(FONT) - font.get_descent(FONT)) * 0.5
			draw_string(font, Vector2(x, baseline), String(part["say"]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, Palette.SAND)
		x += w + GAP
