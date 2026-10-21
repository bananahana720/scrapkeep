extends Control

const Palette := preload("res://src/core/palette.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const Bindings := preload("res://src/core/bindings.gd")

const CAPTIONS := {
	"breach": "Breach · Slam the Dig's cracked plates.",
	"lift": "Lift · Glide through Highdraft thermals.",
	"companion": "SPIL-9 · Next ram calls it in.",
}
const PICTURE_SIZE := Vector2(410.0, 158.0)

var mechanic := ""


func _init(id: String = "breach") -> void:
	mechanic = id
	name = id.capitalize() + "Picture"
	custom_minimum_size = PICTURE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_style_box(ScrapFrame.plate(Color(Palette.VERDIGRIS, 0.7), mechanic.hash(), Color(Palette.CHARCOAL, 0.94), 2), Rect2(Vector2.ZERO, size))
	draw_set_transform(Vector2.ZERO, 0.0, size / PICTURE_SIZE)
	match mechanic:
		"breach":
			_breach()
		"lift":
			_lift()
		"companion":
			_companion()
	draw_set_transform(Vector2.ZERO)


func drawn_words() -> PackedStringArray:
	match mechanic:
		"breach":
			return Keycap.words(Bindings.glyph("haul"))
		"lift":
			var words := Keycap.words(Bindings.glyph("jump"))
			words.append("hold to glide")
			return words
		"companion":
			return PackedStringArray(["2 sockets", "Primer", "Ram", "Escape"])
	return PackedStringArray()


func _breach() -> void:
	var stone := Palette.SANDSTONE.darkened(0.3)
	_plate(Rect2(22, 109, 101, 27), stone)
	_plate(Rect2(275, 109, 113, 27), stone)
	# Two torn halves leave a visible shaft; the crack and the downward path share the opening.
	var left := PackedVector2Array([Vector2(122, 105), Vector2(177, 110), Vector2(164, 120), Vector2(139, 118)])
	var right := PackedVector2Array([Vector2(215, 112), Vector2(275, 104), Vector2(257, 118), Vector2(231, 123)])
	draw_colored_polygon(left, Palette.COPPER)
	draw_colored_polygon(right, Palette.COPPER)
	draw_polyline(PackedVector2Array([Vector2(176, 98), Vector2(191, 108), Vector2(180, 116)]), Palette.ARC, 3.0, true)
	draw_polyline(PackedVector2Array([Vector2(216, 98), Vector2(206, 106), Vector2(222, 120)]), Palette.ARC, 3.0, true)
	_ball(Vector2(199, 42), 21.0)
	_arrow(Vector2(199, 68), Vector2(199, 96), Palette.ARC)
	for i in 3:
		draw_line(Vector2(187 + i * 11, 129), Vector2(191 + i * 9, 145), Palette.COPPER, 3.0, true)
	Keycap.draw(self, Vector2(59, 42), Bindings.glyph("haul"), Palette.SAND, 25.0)
	_arrow(Vector2(280, 67), Vector2(235, 92), Palette.ARC)


func _lift() -> void:
	_plate(Rect2(24, 124, 100, 12), Palette.VERDIGRIS)
	_plate(Rect2(282, 34, 104, 16), Palette.VERDIGRIS)
	# A vent, rising air and a bank onto the upper island, rather than a jump arrow.
	_plate(Rect2(148, 135, 85, 8), Palette.COPPER)
	for i in 3:
		var points := PackedVector2Array()
		for j in 13:
			points.append(Vector2(159 + i * 29 + sin(j * 0.7 + i) * 6.0, 124 - j * 7))
		draw_polyline(points, Color(Palette.SAND, 0.7), 2.0, true)
		_arrow(Vector2(159 + i * 29, 32), Vector2(159 + i * 29, 19), Palette.SAND)
	_ball(Vector2(197, 68), 17.0)
	draw_line(Vector2(172, 59), Vector2(181, 70), Palette.SAND, 3.0, true)
	draw_line(Vector2(222, 59), Vector2(213, 70), Palette.SAND, 3.0, true)
	_arrow(Vector2(228, 72), Vector2(279, 42), Palette.ARC)
	Keycap.draw(self, Vector2(68, 39), Bindings.glyph("jump"), Palette.SAND, 24.0)
	_words("hold to glide", Vector2(22, 77), 16, Palette.SAND)


func _companion() -> void:
	# Three families feed two sockets. The unused family stays visibly outside the chassis.
	var body := Rect2(154, 29, 101, 42)
	draw_style_box(ScrapFrame.plate(Palette.VERDIGRIS.lightened(0.3), 9, Palette.VERDIGRIS, 2), body)
	draw_arc(Vector2(204, 76), 40, 0.2, PI - 0.2, 24, Color(Palette.SAND, 0.5), 2.0, true)
	for x in [180.0, 229.0]:
		draw_rect(Rect2(x - 12, 14, 24, 24), Palette.CHARCOAL)
		draw_rect(Rect2(x - 12, 14, 24, 24), Palette.ARC, false, 2.0)
	_words("2 sockets", Vector2(273, 52), 16, Palette.SAND)
	var centers := [Vector2(69, 110), Vector2(204, 110), Vector2(339, 110)]
	for at in centers:
		draw_rect(Rect2(at - Vector2(23, 18), Vector2(46, 36)), Palette.VERDIGRIS.darkened(0.3))
		draw_rect(Rect2(at - Vector2(23, 18), Vector2(46, 36)), Palette.COPPER, false, 2.0)
	# Primer coil, ram brace and escape corridor: each has a working shape.
	for i in 3:
		draw_arc(centers[0], 6 + i * 4, -PI * 0.75, PI * 0.75, 16, Palette.ARC, 2.0, true)
	draw_polyline(PackedVector2Array([centers[1] + Vector2(-13, -9), centers[1] + Vector2(10, -9), centers[1] + Vector2(17, 0), centers[1] + Vector2(10, 9), centers[1] + Vector2(-13, 9)]), Palette.COPPER, 4.0, true)
	_arrow(centers[2] + Vector2(-15, -6), centers[2] + Vector2(14, -6), Palette.SAND)
	_arrow(centers[2] + Vector2(-15, 6), centers[2] + Vector2(14, 6), Palette.SAND)
	draw_dashed_line(centers[0] + Vector2(0, -24), Vector2(177, 39), Color(Palette.ARC, 0.6), 2.0, 5.0, true)
	draw_dashed_line(centers[1] + Vector2(0, -24), Vector2(227, 39), Color(Palette.ARC, 0.6), 2.0, 5.0, true)
	for i in 3:
		_words(["Primer", "Ram", "Escape"][i], centers[i] + Vector2(-27, 36), 15, Palette.SAND)


func _ball(at: Vector2, radius: float) -> void:
	draw_circle(at, radius, Palette.VERDIGRIS)
	draw_arc(at, radius, 0.0, TAU, 32, Palette.ARC, 2.5, true)
	draw_arc(at, radius * 0.72, -PI * 0.8, PI * 0.15, 20, Palette.COPPER, 3.0, true)
	draw_circle(at + Vector2(0, -radius * 0.25), radius * 0.32, Palette.SAND)


func _plate(rect: Rect2, color: Color) -> void:
	draw_style_box(ScrapFrame.plate(color.lightened(0.15), int(rect.position.x), color, 2), rect)


func _arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var along := (to - from).normalized()
	var side := Vector2(-along.y, along.x)
	draw_line(from, to, color, 3.0, true)
	draw_colored_polygon(PackedVector2Array([to, to - along * 10 + side * 5, to - along * 10 - side * 5]), color)


func _words(text: String, at: Vector2, font_size: int, color: Color) -> void:
	draw_string(UiFonts.bold(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
