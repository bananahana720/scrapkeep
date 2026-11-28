extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")


const OUTLINE := Color(0.0, 0.0, 0.0, 0.85)
const TRACK := Color(0.14, 0.16, 0.16, 0.85)
const ICON_EDGE := 1.5
const CHAMFER := 6.0


static func text(canvas: CanvasItem, x: float, y: float, value: String, font_size: int, color: Color, numbers := false) -> float:
	var font := UiFonts.mono() if numbers else UiFonts.bold()
	var at := Vector2(x, y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	canvas.draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, OUTLINE)
	canvas.draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return UiFonts.width(value, font_size, numbers)


static func label(font_size: int, color: Color, words := "") -> Label:
	var node := Label.new()
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", UiFonts.bold())
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.text = words
	return node


static func icon(canvas: CanvasItem, texture: Texture2D, rect: Rect2, tint: Color) -> void:
	for i in 8:
		canvas.draw_texture_rect(texture, Rect2(rect.position + Vector2.RIGHT.rotated(TAU * i / 8.0) * ICON_EDGE, rect.size), false, OUTLINE)
	canvas.draw_texture_rect(texture, rect, false, tint)


static func bar(canvas: CanvasItem, rect: Rect2, fraction: float, color: Color) -> void:
	canvas.draw_rect(rect.grow(1.5), OUTLINE)
	canvas.draw_rect(rect, TRACK)
	var fill := Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y))
	if fill.size.x > 0.0:
		canvas.draw_rect(fill, color)


static func panel(canvas: CanvasItem, rect: Rect2) -> void:
	var c := CHAMFER
	var outline := PackedVector2Array([
		rect.position + Vector2(c, 0.0), Vector2(rect.end.x - c, rect.position.y), Vector2(rect.end.x, rect.position.y + c),
		rect.end - Vector2(0.0, c), rect.end - Vector2(c, 0.0), Vector2(rect.position.x + c, rect.end.y),
		Vector2(rect.position.x, rect.end.y - c), rect.position + Vector2(0.0, c)])
	canvas.draw_colored_polygon(outline, Color(Palette.CHARCOAL, 0.88))
	var inner := PackedVector2Array()
	for p in outline:
		inner.append(p + (rect.get_center() - p).normalized() * 3.0)
	inner.append(inner[0])
	canvas.draw_polyline(inner, UiTokens.LINE, 2.0)
	for corner in [rect.position + Vector2(c, c), Vector2(rect.end.x - c, rect.position.y + c), rect.end - Vector2(c, c), Vector2(rect.position.x + c, rect.end.y - c)]:
		canvas.draw_circle(corner, 2.0, Palette.SAND)
