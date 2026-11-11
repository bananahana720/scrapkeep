extends Control

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")

# One mixer bus or comfort level as a menu row, on the same charcoal plate as a
# ChoiceButton: a drawn glyph where a choice has its key (a beamed note for music, a
# speaker for effects, a jittered frame for screen shake, a frozen burst for hit-stop),
# one word, then a down arrow, ten level segments and an up arrow. A click on an arrow
# steps a tenth, a click or drag on the segments sets the level there, the wheel steps,
# and the pause menu steps the focused row with left and right. It changes nothing
# itself: `changed` carries the new level to whoever owns the bus.

signal changed(level: float)

const STEPS := 10
const SEG_W := 12.0
const SEG_GAP := 4.0
const ARROW := 56.0
const PAD := float(UiTokens.GAP_L)
const GLYPH := 26.0
const HEIGHT := UiTokens.TARGET

var bus := ""
var words := ""
var glyph := ""
var level := 0.0
var _hover := false
var _dragging := false
# The settings form's layout (stack): the word above, the field (glyph, arrows, bar) below it.
var _top := 0.0


func _init(bus_name := "", row_words := "", glyph_id := "", width := 420.0) -> void:
	bus = bus_name
	words = row_words
	glyph = glyph_id
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(width, HEIGHT)
	accessibility_name = row_words
	mouse_entered.connect(func():
		_hover = true
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		_dragging = false
		queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func drawn_words() -> PackedStringArray:
	return PackedStringArray([words])


func show_level(value: float) -> void:
	if is_equal_approx(value, level):
		return
	level = value
	accessibility_description = "%d of %d" % [steps_filled(), STEPS]
	queue_redraw()


func set_level(value: float) -> void:
	var next := clampf(snappedf(value, 1.0 / STEPS), 0.0, 1.0)
	if is_equal_approx(next, level):
		return
	level = next
	accessibility_description = "%d of %d" % [steps_filled(), STEPS]
	queue_redraw()
	changed.emit(level)


func step(direction: int) -> void:
	set_level(roundf(level * STEPS + direction) / STEPS)


func steps_filled() -> int:
	return roundi(level * STEPS)


func _bar_width() -> float:
	return STEPS * SEG_W + (STEPS - 1) * SEG_GAP


# Puts the word above the field, as the settings form lays out every row; LABEL_H is SettingRow's.
func stack(label_h: float) -> void:
	_top = label_h
	custom_minimum_size.y = label_h + HEIGHT
	queue_redraw()


func _field() -> Rect2:
	return Rect2(0.0, _top, size.x, size.y - _top)


func up_rect() -> Rect2:
	return Rect2(size.x - PAD - ARROW, _top, ARROW, size.y - _top)


func bar_rect() -> Rect2:
	return Rect2(up_rect().position.x - SEG_GAP * 2.0 - _bar_width(), _top, _bar_width(), size.y - _top)


func down_rect() -> Rect2:
	return Rect2(bar_rect().position.x - SEG_GAP * 2.0 - ARROW, _top, ARROW, size.y - _top)


# The level a click at x on the segments asks for: the segment under it, filled.
func level_at(x: float) -> float:
	var bar := bar_rect()
	var index := floori((x - bar.position.x) / (SEG_W + SEG_GAP))
	return clampf(float(index + 1) / STEPS, 0.0, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			if button.button_index == MOUSE_BUTTON_LEFT:
				_dragging = false
			return
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				grab_focus()
				var x := button.position.x
				if up_rect().has_point(Vector2(x, _top + 1.0)):
					step(1)
				elif down_rect().has_point(Vector2(x, _top + 1.0)):
					step(-1)
				elif x >= bar_rect().position.x - SEG_GAP and x <= bar_rect().end.x + SEG_GAP:
					_dragging = true
					set_level(level_at(x))
			MOUSE_BUTTON_WHEEL_UP:
				step(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				step(-1)
			_:
				return
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		set_level(level_at((event as InputEventMouseMotion).position.x))
		accept_event()


func _draw() -> void:
	var left := PAD + GLYPH + PAD
	var field := _field()
	var mid := field.get_center().y
	var edge := UiTokens.TEXT if _hover else UiTokens.LINE
	draw_style_box(ChoiceButton.plate(edge, 2, left), field)
	if has_focus():
		draw_style_box(UiTokens.focus_ring(), field)
	var ink := UiTokens.TEXT
	_draw_glyph(Vector2(PAD + GLYPH * 0.5, mid), ink)
	var font := UiFonts.bold()
	if _top > 0.0:
		var top_line := (font.get_ascent(UiTokens.BODY) - font.get_descent(UiTokens.BODY)) * 0.5 + (_top - UiTokens.GAP_S) * 0.5
		draw_string(font, Vector2(0.0, top_line), words, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.BODY, ink)
	else:
		var baseline := mid + (font.get_ascent(UiTokens.LABEL) - font.get_descent(UiTokens.LABEL)) * 0.5
		draw_string(font, Vector2(left, baseline), words, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.LABEL, ink)
	_draw_arrow(down_rect(), -1.0, ink if level > 0.0 else Color(ink, 0.3))
	_draw_arrow(up_rect(), 1.0, ink if level < 1.0 else Color(ink, 0.3))
	var bar := bar_rect()
	var filled := steps_filled()
	for i in STEPS:
		var h := 10.0 + 14.0 * float(i) / (STEPS - 1)
		var seg := Rect2(bar.position.x + i * (SEG_W + SEG_GAP), mid + 12.0 - h, SEG_W, h)
		if i < filled:
			draw_rect(seg, UiTokens.ACCENT if has_focus() else ink)
		else:
			draw_rect(seg, UiTokens.LINE, false, 2.0)


func _draw_arrow(rect: Rect2, direction: float, color: Color) -> void:
	var c := rect.get_center()
	var w := 7.0
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(direction * w, 0.0), c + Vector2(-direction * w, -w * 1.2), c + Vector2(-direction * w, w * 1.2)]), color)


func _draw_glyph(c: Vector2, color: Color) -> void:
	match glyph:
		"music":
			draw_circle(c + Vector2(-6.0, 8.0), 4.5, color)
			draw_circle(c + Vector2(7.0, 6.0), 4.5, color)
			draw_line(c + Vector2(-2.0, 8.0), c + Vector2(-2.0, -10.0), color, 2.5)
			draw_line(c + Vector2(11.0, 6.0), c + Vector2(11.0, -12.0), color, 2.5)
			draw_line(c + Vector2(-2.0, -10.0), c + Vector2(11.0, -12.0), color, 4.0)
		"effects":
			draw_rect(Rect2(c + Vector2(-11.0, -4.0), Vector2(6.0, 8.0)), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5.0, -4.0), c + Vector2(2.0, -10.0),
				c + Vector2(2.0, 10.0), c + Vector2(-5.0, 4.0)]), color)
			draw_arc(c + Vector2(2.0, 0.0), 6.0, -0.9, 0.9, 8, color, 2.0)
			draw_arc(c + Vector2(2.0, 0.0), 11.0, -0.9, 0.9, 10, color, 2.0)
		"shake":
			draw_rect(Rect2(c + Vector2(-8.0, -7.0), Vector2(16.0, 14.0)), color, false, 2.5)
			for side in [-1.0, 1.0]:
				draw_line(c + Vector2(side * 12.0, -5.0), c + Vector2(side * 12.0, 5.0), color, 2.0)
				draw_line(c + Vector2(side * 15.5, -3.0), c + Vector2(side * 15.5, 3.0), color, 2.0)
		"hitstop":
			for i in 4:
				var a := PI * 0.25 + PI * 0.5 * i
				draw_line(c + Vector2(cos(a), sin(a)) * 5.0, c + Vector2(cos(a), sin(a)) * 12.0, color, 2.5)
			draw_rect(Rect2(c + Vector2(-3.5, -3.5), Vector2(7.0, 7.0)), color)
