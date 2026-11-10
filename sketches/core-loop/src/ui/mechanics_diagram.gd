extends Control

const Palette := preload("res://src/core/palette.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")

const CAPTIONS := {
	"breach": "Slam the Dig's cracked plates.",
	"lift": "Glide through Highdraft thermals.",
	"grip": "Roll fast to climb walls.",
	"cast": "Big actives wind up before firing.",
	"jam": "A pulse locks picks 2 and 3 and recalls a wind-up.",
	"stake": "Hold at a relay mast to raise the bet.",
	"radio": "Change the pilot's station.",
	"halo": "Your next ram calls in SPIL-9, your companion.",
}
# The help page's picture pages, in the order its page button walks them.
const PAGES := [["breach", "lift", "companion"], ["grip", "cast", "jam"], ["stake", "radio", "halo"]]
const RADIO_ACTIONS := ["cl_radio_prev", "cl_radio_next", "cl_radio_skip", "cl_radio_pin"]
const PICTURE_SIZE := Vector2(410.0, 158.0)
# The torch's 0.3 s and the battery and quake's 0.5 s (active_defs.gd); the rest fire at once.
const CAST_TIMES := "0.3-0.5 s"

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
		"grip":
			_grip()
		"cast":
			_cast()
		"jam":
			_jam()
		"stake":
			_stake()
		"radio":
			_radio()
		"halo":
			_halo()
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
		"cast":
			var words := Keycap.words(Bindings.glyph("active"))
			words.append(CAST_TIMES)
			return words
		"jam":
			return PackedStringArray(["refund"])
		"stake":
			var words := Keycap.words(Bindings.glyph("interact"))
			words.append_array(["x1", "x2", "x3"])
			return words
		"radio":
			var words := PackedStringArray()
			for action in RADIO_ACTIONS:
				words.append_array(Keycap.words(radio_key(action)))
			return words
		"halo":
			return PackedStringArray(["Ram"])
	return PackedStringArray()


# The radio's keys from the live bindings: comma, period, slash and semicolon until rebound.
static func radio_key(action: String) -> String:
	return Glyphs.of_action(action, "key_" + OS.get_keycode_string(Bindings.EXTRA_ACTIONS[action]["keys"][0]).to_lower())


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


func _grip() -> void:
	# A fast ball curves off the floor and runs up along the wall's face, speed lines trailing
	# parallel to it; a head-on hit would still bounce, so the path meets the wall tangent.
	_plate(Rect2(22, 124, 300, 14), Palette.VERDIGRIS)
	_plate(Rect2(322, 14, 30, 124), Palette.SANDSTONE.darkened(0.3))
	_ball(Vector2(110, 106), 17.0)
	for i in 3:
		draw_line(Vector2(48 - i * 6, 96 + i * 9), Vector2(80 - i * 6, 96 + i * 9), Color(Palette.SAND, 0.7), 2.0, true)
	draw_arc(Vector2(264, 66), 46, PI * 0.5, PI * 0.02, 18, Palette.ARC, 3.0, true)
	_ball(Vector2(308, 40), 13.0)
	for i in 3:
		draw_line(Vector2(296 + i * 6, 58 + i * 4), Vector2(296 + i * 6, 84 + i * 4), Color(Palette.SAND, 0.7), 2.0, true)
	_arrow(Vector2(308, 24), Vector2(308, 10), Palette.ARC)


func _cast() -> void:
	# Press F, a ring fills round the ball (a big active's wind-up, timed underneath), then the
	# shot leaves.
	Keycap.draw(self, Vector2(52, 79), Bindings.glyph("active"), Palette.SAND, 26.0)
	_arrow(Vector2(78, 79), Vector2(118, 79), Palette.SAND)
	_ball(Vector2(172, 79), 20.0)
	draw_arc(Vector2(172, 79), 31, -PI * 0.5, PI * 0.9, 24, Palette.ARC, 4.0, true)
	draw_arc(Vector2(172, 79), 31, PI * 0.9, PI * 1.5, 12, Color(Palette.SAND, 0.3), 4.0, true)
	_words(CAST_TIMES, Vector2(136, 136), 16, Palette.SAND)
	_arrow(Vector2(212, 79), Vector2(320, 79), Palette.COPPER)
	for i in 6:
		var angle := TAU * i / 6.0
		draw_line(Vector2(352, 79) + Vector2.from_angle(angle) * 10, Vector2(352, 79) + Vector2.from_angle(angle) * 26, Palette.COPPER, 3.0, true)


func _jam() -> void:
	# Inside the pulsing field Q's half-filled wind-up is struck through; its charge comes back
	# (jolt_layer.gd _recall_q).
	draw_circle(Vector2(150, 79), 64, Color(Palette.ARC, 0.12))
	draw_arc(Vector2(150, 79), 64, 0.0, TAU, 40, Color(Palette.ARC, 0.7), 2.0, true)
	draw_arc(Vector2(150, 79), 48, 0.0, TAU, 32, Color(Palette.ARC, 0.4), 2.0, true)
	_ball(Vector2(150, 79), 18.0)
	draw_arc(Vector2(150, 79), 27, -PI * 0.5, PI * 0.3, 16, Palette.ARC, 4.0, true)
	draw_line(Vector2(126, 103), Vector2(174, 55), Palette.COPPER, 4.0, true)
	_arrow(Vector2(222, 79), Vector2(282, 79), Palette.SAND)
	draw_arc(Vector2(318, 79), 22, -PI * 0.2, PI * 1.6, 18, Palette.SAND, 3.0, true)
	_arrow(Vector2(318, 57) + Vector2(12, -2), Vector2(318, 57) + Vector2(18, 4), Palette.SAND)
	_words("refund", Vector2(292, 128), 16, Palette.SAND)


func _stake() -> void:
	# The post with its E, three stake chips stacking up, and the ring on the ground ahead.
	_plate(Rect2(22, 124, 366, 12), Palette.VERDIGRIS)
	_plate(Rect2(60, 44, 18, 80), Palette.COPPER)
	Keycap.draw(self, Vector2(69, 28), Bindings.glyph("interact"), Palette.SAND, 24.0)
	for i in 3:
		var at := Vector2(124 + i * 52, 104 - i * 14)
		draw_rect(Rect2(at - Vector2(18, 10), Vector2(36, 20)), Palette.CHARCOAL)
		draw_rect(Rect2(at - Vector2(18, 10), Vector2(36, 20)), Palette.AMBER, false, 2.0)
		_words("x%d" % (i + 1), at + Vector2(-11, 6), 15, Palette.AMBER)
	draw_arc(Vector2(330, 118), 44, PI * 1.08, PI * 1.92, 20, Palette.AMBER, 3.0, true)
	_ball(Vector2(330, 102), 14.0)


func _radio() -> void:
	# The HUD knob and its four keys in dial order: back, next, skip, pin.
	draw_circle(Vector2(96, 79), 40, Palette.CHARCOAL)
	draw_arc(Vector2(96, 79), 40, 0.0, TAU, 32, Palette.COPPER, 3.0, true)
	for i in 7:
		var angle := PI * (0.8 + i * 0.233)
		draw_line(Vector2(96, 79) + Vector2.from_angle(angle) * 44, Vector2(96, 79) + Vector2.from_angle(angle) * 52, Palette.SAND, 2.0, true)
	draw_line(Vector2(96, 79), Vector2(96, 79) + Vector2.from_angle(PI * 1.4) * 32, Palette.ARC, 4.0, true)
	var marks := ["<", ">", ">>", "*"]
	for i in RADIO_ACTIONS.size():
		var at := Vector2(196 + i * 56, 64)
		Keycap.draw(self, at, radio_key(RADIO_ACTIONS[i]), Palette.SAND, 30.0)
		_words(marks[i], at + Vector2(-6 - (marks[i].length() - 1) * 4, 46), 18, Palette.ARC)


func _halo() -> void:
	# SPIL-9's halo in segments, all lit; the next ram (the ball into a plate) calls the assist.
	var spil := Vector2(92, 74)
	for i in 12:
		var start := TAU * i / 12.0 - PI * 0.5
		draw_arc(spil, 36, start + 0.06, start + TAU / 12.0 - 0.06, 4, Palette.ARC, 6.0, true)
	draw_circle(spil, 20, Palette.VERDIGRIS.lightened(0.2))
	draw_circle(spil + Vector2(0, -3), 7, Palette.SAND)
	_ball(Vector2(214, 96), 18.0)
	_arrow(Vector2(236, 96), Vector2(300, 96), Palette.COPPER)
	_plate(Rect2(306, 60, 40, 72), Palette.SANDSTONE.darkened(0.3))
	draw_dashed_line(spil + Vector2(38, 4), Vector2(300, 84), Color(Palette.ARC, 0.6), 2.0, 6.0, true)
	_words("Ram", Vector2(248, 132), 16, Palette.SAND)


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
