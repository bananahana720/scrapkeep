extends StyleBox

const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Palette := preload("res://src/core/palette.gd")

# The frame for every screen, card and plate, drawn in the hand of whoever made the thing it shows
# (LEGIBILITY.md section 14.3, ruling ek). This is the one module that draws all four hands.
#
# Keeper, the default and the look every plate() and tag() has always had ("HUD look: scrapped
# together, clean to read"): the ball culture built its screens from scrap, so a panel is a cut plate
# with uneven corners, a heavier lip on one side, rivets and a strip of tape where parts join, and words
# sit on small stamped tags. A hand_plate() Keeper also takes halftone corners and a slight lean.
# The Fleet: a brass bezel on iron oxide, one notched corner, ledger rules and a rubber stamp.
# The old works: cast in one piece, so no fastener, tape or lean, and a notched seam of uranium green
# (purple only on the Kindness).
# Rogues: a bare plate with stencil corner ticks, for a stencilled number.
#
# Roughness lives on the frame only; nothing here draws over an icon, number, key letter or glyph. Wear
# is a value shift of the frame's own colour, never a new hue, so the class colour stays the one "yours"
# accent. A serial fixes a frame's quirks, so it looks the same on every redraw.
#
# Use it anywhere a StyleBoxFlat was used: as a theme stylebox override, or through draw_style_box().
# plate() and tag() build the Keeper's two kinds and hand_plate() and hand_tag() any hand's; stamp()
# draws words on a tag for controls that draw their own text; wear() shifts a colour for mismatched parts
# such as keycaps; draw_tape() tapes anything else; lawful() says whether a colour may sit on a hand's
# frame. parts() lists what a frame draws, for a test or a capture.

enum Kind { PLATE, TAG }

const Hand := UiTokens.Hand
const TAPE := Vector2(40.0, 13.0)
# The Fleet's rubber stamp: its radius, and its gap to the bezel. It sits in the foot's right corner.
const STAMP := 11.0
const STAMP_GAP := 6.0

var kind := Kind.PLATE
var hand: int = Hand.KEEPER
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
# The Keeper's: how far the plate leans, in radians (none with less motion), and dots in two corners.
var tilt := 0.0
var halftone := false
# The Fleet's: ledger rules across the plate, each 0 (top) to 1 (bottom), and a rubber stamp in a corner.
var dividers := PackedFloat32Array()
var stamped := false
# The old works': the seam's colour.
var seam := Palette.ANCIENT


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


# A plate in a hand's own colours (UiTokens.HANDS). `kindness` turns an old-works seam purple, for the
# Kindness and nothing else; every other hand ignores it.
static func hand_plate(which: int, serial_value: int, kindness := false) -> StyleBox:
	var row: Dictionary = UiTokens.HANDS[which]
	var box = new()
	box.hand = which
	box.border_color = row.edge
	box.bg_color = Color(row.fill, UiTokens.PLATE_ALPHA)
	box.serial = serial_value
	box.rivets = which == Hand.KEEPER
	box.halftone = which == Hand.KEEPER
	box.tilt = row.tilt * (2.0 * quirk(serial_value, 8) - 1.0)
	box.stamped = which == Hand.FLEET
	if which == Hand.OLD_WORKS:
		box.seam = row.kindness_seam if kindness else row.seam
	return box


# A tag in a hand's own colours: the Keeper's punched tag, a brass Fleet tag, a cast old-works tag or a
# Rogue's bare one.
static func hand_tag(which: int, serial_value: int) -> StyleBox:
	var row: Dictionary = UiTokens.HANDS[which]
	var box = tag(row.edge, serial_value, which == Hand.KEEPER)
	box.hand = which
	box.bg_color = Color(row.fill, 1.0) if which != Hand.KEEPER else box.bg_color
	return box


# Whether a colour may sit on a hand's frame. Mint is press now and sits on none; brass is the Fleet's
# alone; purple only on the Kindness's old-works frame.
static func lawful(which: int, color: Color, kindness := false) -> bool:
	if _near(color, Palette.ARC):
		return false
	if _near(color, Palette.BRASS) and which != Hand.FLEET:
		return false
	if _near(color, Palette.KINDNESS) and not (which == Hand.OLD_WORKS and kindness):
		return false
	return true


static func _near(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.08


# How far in from a Fleet plate's right edge its stamp reaches, so the plate's own marks stop short of it.
static func stamp_reach(width := 2.0) -> float:
	return width + 3.0 + STAMP_GAP + 2.0 * STAMP


# Words stamped on a tag, for controls that draw their own text. `at` is the tag's
# centre, or its right or left middle when aligned that way. A Keeper tag takes `edge`; any other hand's
# tag is that hand's own. Returns the tag's rect.
static func stamp(canvas: CanvasItem, text: String, font: Font, font_size: int, color: Color, edge: Color, serial_value: int,
		at: Vector2, align := HORIZONTAL_ALIGNMENT_CENTER, which: int = Hand.KEEPER) -> Rect2:
	var box := tag(edge, serial_value) if which == Hand.KEEPER else hand_tag(which, serial_value)
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
	_emit(item, _tape_parts(at, angle, size, alpha))


static func _tape_parts(at: Vector2, angle: float, size: Vector2, alpha: float) -> Array:
	var along := Vector2.from_angle(angle)
	var across := Vector2(-along.y, along.x)
	var half := size * 0.5
	var points := PackedVector2Array()
	for i in 4:
		points.append(at + along * (half.x - (3.0 if i % 2 == 1 else 0.0)) + across * lerpf(-half.y, half.y, i / 3.0))
	for i in 4:
		points.append(at - along * (half.x - (3.0 if i % 2 == 0 else 0.0)) + across * lerpf(half.y, -half.y, i / 3.0))
	return [
		_poly("tape", points, Color(Palette.SAND, 0.42 * alpha)),
		_segment("tape", at - along * (half.x - 4.0) - across * (half.y - 2.5), at + along * (half.x - 4.0) - across * (half.y - 2.5),
			Color(Palette.SAND, 0.3 * alpha), 1.0),
	]


func _draw(item: RID, rect: Rect2) -> void:
	_emit(item, parts(rect))


# Everything the frame draws in `rect`, in order: each part is {role, shape, points, color, width, radius}.
# The shape is "poly", "line", "segment" or "circle" (centre in points[0]). Roles: fill, lip, shine,
# edge, hole, rivet, tape, halftone, notch, bezel, divider, stamp, seam, glass, tick.
func parts(rect: Rect2) -> Array:
	var out: Array
	match hand:
		Hand.FLEET:
			out = _fleet(rect)
		Hand.OLD_WORKS:
			out = _old_works(rect)
		Hand.ROGUE:
			out = _rogue(rect)
		_:
			out = _keeper(rect)
	# The Keeper's parts fade as they are made; every other hand's fade here.
	if fade < 1.0 and hand != Hand.KEEPER:
		for part in out:
			part.color = Color(part.color, part.color.a * fade)
	var lean := 0.0 if UiTokens.reduced_motion or hand != Hand.KEEPER else tilt
	if lean != 0.0:
		var centre := rect.get_center()
		for part in out:
			var turned := PackedVector2Array()
			for point in part.points:
				turned.append(centre + (point - centre).rotated(lean))
			part.points = turned
	return out


func _keeper(rect: Rect2) -> Array:
	var out := []
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
		out.append(_poly("fill", outline, Color(bg_color, bg_color.a * fade)))
	if kind == Kind.PLATE and bg_color.a > 0.0:
		var lip := 2.0 + 2.0 * quirk(serial, 4)
		out.append(_poly("lip", PackedVector2Array([
			Vector2(p.x + cut[3], e.y - lip), Vector2(e.x - cut[2], e.y - lip), outline[4], outline[5],
		]), Color(Palette.CHARCOAL.darkened(0.5), 0.55 * fade)))
		var shine := Color.from_hsv(border_color.h, border_color.s * 0.5, minf(border_color.v * 1.25, 1.0), 0.18 * fade)
		var inset := border_width + 1.0 + quirk(serial, 5)
		out.append(_line("shine", PackedVector2Array([
			Vector2(p.x + inset, e.y - cut[3] - inset), Vector2(p.x + inset, p.y + cut[0] + inset),
			Vector2(p.x + cut[0] + inset, p.y + inset), Vector2(e.x - cut[1] - inset, p.y + inset),
		]), shine, 1.5))
	if halftone and kind == Kind.PLATE and small >= 48.0:
		out.append_array(_halftone(rect, cut))
	var closed := outline.duplicate()
	closed.append(outline[0])
	out.append(_line("edge", closed, Color(border_color, border_color.a * fade), border_width, true))
	if kind == Kind.TAG:
		if hole:
			var at := Vector2(p.x + 6.5, rect.get_center().y)
			out.append(_circle("hole", at, 2.4, Color(border_color, 0.7 * fade)))
			out.append(_circle("hole", at, 1.5, Color(Palette.CHARCOAL.darkened(0.5), fade)))
		return out
	if rivets and small >= 48.0:
		var corners := [p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)]
		for i in 4:
			var inward: Vector2 = (rect.get_center() - corners[i]).sign()
			var at: Vector2 = corners[i] + inward * (cut[i] * 0.5 + border_width + 5.0)
			out.append(_circle("rivet", at, 3.6, Color.from_hsv(border_color.h, border_color.s, border_color.v * 0.55, fade)))
			out.append(_circle("rivet", at - Vector2(1.0, 1.0), 1.4, Color(Palette.SAND, 0.55 * fade)))
	if tape >= 0.0:
		var x := lerpf(p.x + cut[0] + TAPE.x * 0.5, e.x - cut[1] - TAPE.x * 0.5, tape)
		out.append_array(_tape_parts(Vector2(x, p.y + 1.0), (quirk(serial, 6) - 0.5) * 0.24, TAPE, fade))
	return out


# Printed dots fading out of the top-left and bottom-right corners, in the edge's own colour.
func _halftone(rect: Rect2, cut: Array) -> Array:
	var out := []
	var step := 5.0
	var dot := Color(border_color, 0.22 * fade)
	for corner in [0, 2]:
		var origin := rect.position if corner == 0 else rect.end
		var inward := Vector2.ONE if corner == 0 else -Vector2.ONE
		# Past the corner's rivet, so a dot never sits under it.
		var start: float = cut[corner] + border_width + 16.0
		for row in 4:
			for col in 4 - row:
				var at := origin + inward * Vector2(start + col * step, border_width + 4.0 + row * step)
				out.append(_circle("halftone", at, 1.6 - 0.3 * (row + col), dot))
	return out


func _fleet(rect: Rect2) -> Array:
	var out := []
	var p := rect.position
	var e := rect.end
	var notch := clampf(minf(rect.size.x, rect.size.y) * 0.2, 3.0, 10.0)
	# One notched corner, top right: a square bite out of the card.
	var outline := PackedVector2Array([
		p, Vector2(e.x - notch, p.y), Vector2(e.x - notch, p.y + notch), Vector2(e.x, p.y + notch), e, Vector2(p.x, e.y),
	])
	if bg_color.a > 0.0:
		out.append(_poly("fill", outline, bg_color))
	var closed := outline.duplicate()
	closed.append(outline[0])
	out.append(_line("edge", closed, border_color, border_width, true))
	if kind == Kind.TAG:
		return out
	var inset := border_width + 3.0
	var inner := PackedVector2Array([
		p + Vector2(inset, inset), Vector2(e.x - notch - inset, p.y + inset), Vector2(e.x - notch - inset, p.y + notch + inset),
		Vector2(e.x - inset, p.y + notch + inset), e - Vector2(inset, inset), Vector2(p.x + inset, e.y - inset), p + Vector2(inset, inset),
	])
	out.append(_line("bezel", inner, Color(border_color, 0.45), 1.0, true))
	for at in dividers:
		var y := lerpf(p.y + inset, e.y - inset, clampf(at, 0.0, 1.0))
		out.append(_segment("divider", Vector2(p.x + inset + 4.0, y), Vector2(e.x - inset - 4.0, y), Color(border_color, 0.5), 1.0))
	# The stamp goes down whole or not at all: a 44 px boss plate takes it, a tag does not.
	var stamp_side := 2.0 * (inset + STAMP + STAMP_GAP)
	if stamped and rect.size.x >= stamp_side and rect.size.y >= stamp_side:
		var radius := STAMP
		var at := e - Vector2(inset + radius + STAMP_GAP, inset + radius + STAMP_GAP)
		var ring := PackedVector2Array()
		for i in 25:
			ring.append(at + Vector2.from_angle(TAU * i / 24.0) * radius)
		var ink := Color(border_color, 0.5)
		out.append(_line("stamp", ring, ink, 1.5, true))
		var lean := Vector2.from_angle(-0.35 + 0.2 * quirk(serial, 9))
		out.append(_segment("stamp", at - lean * (radius - 3.0), at + lean * (radius - 3.0), ink, 2.0))
	return out


func _old_works(rect: Rect2) -> Array:
	var out := []
	var p := rect.position
	var e := rect.end
	var outline := PackedVector2Array([p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)])
	if bg_color.a > 0.0:
		out.append(_poly("fill", outline, bg_color))
	var closed := outline.duplicate()
	closed.append(outline[0])
	out.append(_line("edge", closed, border_color, 1.0, true))
	if kind == Kind.TAG:
		return out
	var inset := 4.0
	# The glass: one straight, even highlight under the top edge.
	out.append(_segment("glass", Vector2(p.x + inset, p.y + inset), Vector2(e.x - inset, p.y + inset), Color(UiTokens.HANDS[Hand.OLD_WORKS].ink, 0.12), 1.0))
	# The seam where a join would be, along the foot, with one notch at its middle.
	var y := e.y - inset - 1.0
	var mid := rect.get_center().x
	var half := clampf(rect.size.x * 0.04, 3.0, 8.0)
	out.append(_line("seam", PackedVector2Array([
		Vector2(p.x + inset, y), Vector2(mid - half, y), Vector2(mid - half, y - half), Vector2(mid + half, y - half),
		Vector2(mid + half, y), Vector2(e.x - inset, y),
	]), seam, 2.0))
	return out


func _rogue(rect: Rect2) -> Array:
	var out := []
	var p := rect.position
	var e := rect.end
	if bg_color.a > 0.0:
		out.append(_poly("fill", PackedVector2Array([p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)]), bg_color))
	# Stencil registration: an L at each corner and a short tick at the middle of the top and foot, no edge.
	var arm := clampf(minf(rect.size.x, rect.size.y) * 0.2, 4.0, 14.0)
	var corners := [p, Vector2(e.x, p.y), e, Vector2(p.x, e.y)]
	for at: Vector2 in corners:
		var inward := (rect.get_center() - at).sign()
		out.append(_line("tick", PackedVector2Array([at + Vector2(inward.x * arm, 0.0), at, at + Vector2(0.0, inward.y * arm)]), border_color, 2.0))
	if kind == Kind.PLATE:
		var mid := rect.get_center().x
		out.append(_segment("tick", Vector2(mid, p.y), Vector2(mid, p.y + arm * 0.5), border_color, 2.0))
		out.append(_segment("tick", Vector2(mid, e.y), Vector2(mid, e.y - arm * 0.5), border_color, 2.0))
	return out


static func _poly(role: String, points: PackedVector2Array, color: Color) -> Dictionary:
	return {"role": role, "shape": "poly", "points": points, "color": color, "width": 0.0, "radius": 0.0, "aa": false}


static func _line(role: String, points: PackedVector2Array, color: Color, width: float, aa := false) -> Dictionary:
	return {"role": role, "shape": "line", "points": points, "color": color, "width": width, "radius": 0.0, "aa": aa}


static func _segment(role: String, from: Vector2, to: Vector2, color: Color, width: float) -> Dictionary:
	return {"role": role, "shape": "segment", "points": PackedVector2Array([from, to]), "color": color, "width": width, "radius": 0.0, "aa": false}


static func _circle(role: String, at: Vector2, radius: float, color: Color) -> Dictionary:
	return {"role": role, "shape": "circle", "points": PackedVector2Array([at]), "color": color, "width": 0.0, "radius": radius, "aa": false}


static func _emit(item: RID, list: Array) -> void:
	for part in list:
		match part.shape:
			"poly":
				RenderingServer.canvas_item_add_polygon(item, part.points, PackedColorArray([part.color]))
			"line":
				RenderingServer.canvas_item_add_polyline(item, part.points, PackedColorArray([part.color]), part.width, part.aa)
			"segment":
				RenderingServer.canvas_item_add_line(item, part.points[0], part.points[1], part.color, part.width)
			"circle":
				RenderingServer.canvas_item_add_circle(item, part.points[0], part.radius, part.color)
