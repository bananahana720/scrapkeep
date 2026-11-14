extends StyleBox

const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Palette := preload("res://src/core/palette.gd")

# The salvage look for UI frames ("HUD look: scrapped together, clean to read"): the
# ball culture built its screens from scrap, so a panel is a cut plate with uneven
# corners, a heavier lip on one side, rivets and a strip of tape where parts join, and
# words sit on small stamped tags. Roughness lives on the frame only; nothing here
# draws over an icon, number, key letter or glyph. Wear is a value shift of the frame's
# own colour, never a new hue, so the class colour stays the one "yours" accent. A
# serial fixes a frame's quirks, so it looks the same on every redraw.
#
# Use it anywhere a StyleBoxFlat was used: as a theme stylebox override, or through
# draw_style_box(). plate() and tag() build the two kinds; stamp() draws words on a tag
# for controls that draw their own text; wear() shifts a colour for mismatched parts such
# as keycaps; draw_tape() tapes anything else.

enum Kind { PLATE, TAG }

const TAPE := Vector2(40.0, 13.0)

var kind := Kind.PLATE
var border_color := Palette.SAND
var bg_color := Color(UiTokens.INK, UiTokens.PLATE_ALPHA)
var border_width := 2.0
var serial := 0
var rivets := true
# Where along the top edge a strip of tape joins the plate, 0 to 1; below 0, none.
var tape := -1.0
# A tag's punched hole, on its left end.
var hole := true
# Every colour the frame draws, rivets and tape included, times this alpha: a frame
# fading in or out with the thing it holds (the reward card).
var fade := 1.0


static func plate(edge: Color, serial_value: int, fill := Color(Palette.CHARCOAL, 0.94), width := 2.0, tape_at := -1.0) -> StyleBox:
	var box = new()
	box.border_color = edge
	box.bg_color = fill
	box.border_width = width
	box.serial = serial_value
	box.tape = tape_at
	return box


static func tag(edge: Color, serial_value: int, punched := true) -> StyleBox:
	var box = new()
	box.kind = Kind.TAG
	box.border_color = edge
	box.bg_color = Palette.CHARCOAL.lerp(Color(edge, 1.0), 0.14)
	box.border_width = 1.0
	box.serial = serial_value
	box.rivets = false
	box.hole = punched
	box.content_margin_left = 14.0 if punched else 5.0
	box.content_margin_right = 6.0 if punched else 5.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 2.0
	return box


# Words stamped on a tag, for controls that draw their own text. `at` is the tag's
# centre, or its right or left middle when aligned that way. Returns the tag's rect.
static func stamp(canvas: CanvasItem, text: String, font: Font, font_size: int, color: Color, edge: Color, serial_value: int,
		at: Vector2, align := HORIZONTAL_ALIGNMENT_CENTER) -> Rect2:
	var box := tag(edge, serial_value)
	var rect := stamp_rect(box, text, font, font_size, at, align)
	canvas.draw_style_box(box, rect)
	canvas.draw_string(font, rect.position + Vector2(box.content_margin_left, box.content_margin_top + font.get_ascent(font_size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return rect


# Where stamp() puts a tag: sized to the words plus the tag's margins.
static func stamp_rect(box: StyleBox, text: String, font: Font, font_size: int, at: Vector2, align := HORIZONTAL_ALIGNMENT_CENTER) -> Rect2:
	var inner := Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, font.get_height(font_size))
	var size := inner + Vector2(box.content_margin_left + box.content_margin_right, box.content_margin_top + box.content_margin_bottom)
	var anchor := 1.0 if align == HORIZONTAL_ALIGNMENT_RIGHT else (0.0 if align == HORIZONTAL_ALIGNMENT_LEFT else 0.5)
	return Rect2(Vector2(at.x - size.x * anchor, at.y - size.y * 0.5), size)


# A part from a different set: the same hue and saturation, a little lighter or darker.
static func wear(color: Color, serial_value: int, amount := 0.1) -> Color:
	return Color.from_hsv(color.h, color.s, clampf(color.v * (1.0 + amount * (2.0 * quirk(serial_value, 7) - 1.0)), 0.0, 1.0), color.a)


# A stable 0 to 1 value per serial and slot.
static func quirk(serial_value: int, slot: int) -> float:
	return fposmod(sin(float(posmod(serial_value, 9973)) * 12.9898 + float(slot) * 78.233) * 43758.5453, 1.0)


# A strip of tape centred on `at`, low contrast, with torn ends.
static func draw_tape(item: RID, at: Vector2, angle: float, size := TAPE, alpha := 1.0) -> void:
	var along := Vector2.from_angle(angle)
	var across := Vector2(-along.y, along.x)
	var half := size * 0.5
	var points := PackedVector2Array()
	for i in 4:
		points.append(at + along * (half.x - (3.0 if i % 2 == 1 else 0.0)) + across * lerpf(-half.y, half.y, i / 3.0))
	for i in 4:
		points.append(at - along * (half.x - (3.0 if i % 2 == 0 else 0.0)) + across * lerpf(half.y, -half.y, i / 3.0))
	RenderingServer.canvas_item_add_polygon(item, points, PackedColorArray([Color(Palette.SAND, 0.42 * alpha)]))
	RenderingServer.canvas_item_add_line(item, at - along * (half.x - 4.0) - across * (half.y - 2.5),
		at + along * (half.x - 4.0) - across * (half.y - 2.5), Color(Palette.SAND, 0.3 * alpha), 1.0)


func _draw(item: RID, rect: Rect2) -> void:
	var small := minf(rect.size.x, rect.size.y)
	var base := clampf(small * 0.18, 2.0, 9.0) if kind == Kind.PLATE else clampf(small * 0.22, 2.0, 5.0)
	var cut := []
	for i in 4:
		cut.append(base * (0.45 + 1.1 * quirk(serial, i)))
	var p := rect.position
	var e := rect.end
	var outline := PackedVector2Array([
		Vector2(p.x + cut[0], p.y), Vector2(e.x - cut[1], p.y), Vector2(e.x, p.y + cut[1]), Vector2(e.x, e.y - cut[2]),
		Vector2(e.x - cut[2], e.y), Vector2(p.x + cut[3], e.y), Vector2(p.x, e.y - cut[3]), Vector2(p.x, p.y + cut[0]),
	])
	if bg_color.a > 0.0:
		RenderingServer.canvas_item_add_polygon(item, outline, PackedColorArray([Color(bg_color, bg_color.a * fade)]))
	if kind == Kind.PLATE and bg_color.a > 0.0:
		var lip := 2.0 + 2.0 * quirk(serial, 4)
		RenderingServer.canvas_item_add_polygon(item, PackedVector2Array([
			Vector2(p.x + cut[3], e.y - lip), Vector2(e.x - cut[2], e.y - lip), outline[4], outline[5],
		]), PackedColorArray([Color(Palette.CHARCOAL.darkened(0.5), 0.55 * fade)]))
		var shine := Color.from_hsv(border_color.h, border_color.s * 0.5, minf(border_color.v * 1.25, 1.0), 0.18 * fade)
		var inset := border_width + 1.0 + quirk(serial, 5)
		RenderingServer.canvas_item_add_polyline(item, PackedVector2Array([
			Vector2(p.x + inset, e.y - cut[3] - inset), Vector2(p.x + inset, p.y + cut[0] + inset),
			Vector2(p.x + cut[0] + inset, p.y + inset), Vector2(e.x - cut[1] - inset, p.y + inset),
		]), PackedColorArray([shine]), 1.5)
	var closed := outline.duplicate()
	closed.append(outline[0])
	RenderingServer.canvas_item_add_polyline(item, closed, PackedColorArray([Color(border_color, border_color.a * fade)]), border_width, true)
	if kind == Kind.TAG:
		if hole:
			var at := Vector2(p.x + 6.5, rect.get_center().y)
			RenderingServer.canvas_item_add_circle(item, at, 2.4, Color(border_color, 0.7 * fade))
			RenderingServer.canvas_item_add_circle(item, at, 1.5, Color(Palette.CHARCOAL.darkened(0.5), fade))
		return
	if rivets and small >= 48.0:
		var corners := [p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)]
		for i in 4:
			var inward: Vector2 = (rect.get_center() - corners[i]).sign()
			var at: Vector2 = corners[i] + inward * (cut[i] * 0.5 + border_width + 5.0)
			RenderingServer.canvas_item_add_circle(item, at, 3.6, Color.from_hsv(border_color.h, border_color.s, border_color.v * 0.55, fade))
			RenderingServer.canvas_item_add_circle(item, at - Vector2(1.0, 1.0), 1.4, Color(Palette.SAND, 0.55 * fade))
	if tape >= 0.0:
		var x := lerpf(p.x + cut[0] + TAPE.x * 0.5, e.x - cut[1] - TAPE.x * 0.5, tape)
		draw_tape(item, Vector2(x, p.y + 1.0), (quirk(serial, 6) - 0.5) * 0.24, TAPE, fade)
