extends "res://src/ui/choice_button.gd"


const NONE := -1
const OFF := 0
const ON := 1
const PIP_R := 9.0
const LABEL_H := 28.0
const SWITCH := Vector2(44.0, 24.0)
const CHEVRON := 7.0

var words := ""
var value := ""
var pip := NONE
var stacked := false


func _init(action_id := "", key_id := "", row_words := "") -> void:
	super(action_id, key_id, row_words)
	words = row_words


func stack() -> void:
	stacked = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_font_size_override("font_size", UiTokens.BODY)
	custom_minimum_size.y = LABEL_H + UiTokens.TARGET
	_plates()


func field_rect() -> Rect2:
	if not stacked:
		return Rect2(Vector2.ZERO, size)
	return Rect2(0.0, LABEL_H, size.x, size.y - LABEL_H)


func _plates() -> void:
	if stacked:
		for pair in [["normal", _edge(), UiTokens.EDGE if _edge() == UiTokens.LINE else UiTokens.FOCUS_EDGE, true],
				["hover", UiTokens.TEXT if _edge() == UiTokens.LINE else _edge(), UiTokens.EDGE if _edge() == UiTokens.LINE else UiTokens.FOCUS_EDGE, true],
				["pressed", UiTokens.ACCENT, UiTokens.FOCUS_EDGE, true],
				["focus"],
				["disabled", UiTokens.disabled(UiTokens.LINE), UiTokens.EDGE, true]]:
			var box := UiTokens.focus_ring(0.0) if pair[0] == "focus" else UiTokens.plate(pair[1], pair[2], pair[3])
			box.expand_margin_top = -LABEL_H
			box.content_margin_left = 0.0
			box.content_margin_right = 0.0
			box.content_margin_top = 0.0
			box.content_margin_bottom = UiTokens.TARGET
			if pair[0] == "focus":
				box.expand_margin_top = -LABEL_H + UiTokens.FOCUS_EDGE + 1.0
			add_theme_stylebox_override(pair[0], box)
		return
	if key != "":
		super()
		return
	var left := PAD * 1.5
	add_theme_stylebox_override("normal", plate(UiTokens.LINE, 2, left))
	add_theme_stylebox_override("hover", plate(Palette.SAND, 2, left))
	add_theme_stylebox_override("pressed", plate(Palette.AMBER, 3, left))
	add_theme_stylebox_override("focus", UiTokens.focus_ring(left))
	add_theme_stylebox_override("disabled", plate(UiTokens.disabled(UiTokens.LINE), 2, left))


func show_row(row_words: String, shown_value := "", pip_state := NONE) -> void:
	words = row_words
	text = row_words
	value = shown_value
	pip = pip_state
	accessibility_name = row_words
	accessibility_description = value if pip == NONE else ("on" if pip == ON else "off")
	queue_redraw()


func data() -> Dictionary:
	return {"label": words, "value": value, "pip": pip}


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray([words])
	if value != "":
		out.append(value)
	return out


func _draw() -> void:
	if stacked:
		_draw_field()
		return
	if key != "":
		super()
	if pip == NONE and value == "":
		return
	var ink := UiTokens.disabled(UiTokens.TEXT) if disabled else (UiTokens.TEXT if is_hovered() or has_focus() else Palette.SAND)
	var edge := size.x - PAD * 1.5
	if pip != NONE:
		var centre := Vector2(edge - PIP_R, size.y * 0.5)
		if pip == ON:
			draw_circle(centre, PIP_R, ink)
		else:
			draw_arc(centre, PIP_R - 1.5, 0.0, TAU, 24, ink, 3.0)
		return
	var font := UiFonts.bold()
	var baseline := size.y * 0.5 + (font.get_ascent(UiTokens.LABEL) - font.get_descent(UiTokens.LABEL)) * 0.5
	draw_string(font, Vector2(edge - UiFonts.width(value, UiTokens.LABEL), baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.LABEL, ink)


func _draw_field() -> void:
	var field := field_rect()
	var mid := field.position.y + field.size.y * 0.5
	var ink := UiTokens.disabled(UiTokens.TEXT) if disabled else UiTokens.TEXT
	var x := UiTokens.GAP_L
	if pip != NONE:
		var track := Rect2(Vector2(x, mid - SWITCH.y * 0.5), SWITCH)
		var r := SWITCH.y * 0.5
		var on := pip == ON
		_capsule(track, ink if on else Color(UiTokens.INK, 0.0), ink)
		var knob := Vector2(track.end.x - r if on else track.position.x + r, mid)
		draw_circle(knob, r - 5.0, UiTokens.INK if on else ink)
		return
	if waiting:
		_draw_dots_at(Vector2(x, mid))
		return
	var font := UiFonts.bold()
	var baseline := mid + (font.get_ascent(UiTokens.LABEL) - font.get_descent(UiTokens.LABEL)) * 0.5
	if value != "":
		draw_string(font, Vector2(x, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.LABEL, ink)
	if disabled:
		_padlock(Vector2(field.end.x - UiTokens.GAP_L - 16.0, mid - 9.0), ink)
	elif value != "":
		var right := field.end.x - UiTokens.GAP_L
		_chevron(Vector2(right - CHEVRON * 3.0, mid), -1, ink)
		_chevron(Vector2(right, mid), 1, ink)


func _capsule(rect: Rect2, fill: Color, edge: Color) -> void:
	var r := rect.size.y * 0.5
	var points := PackedVector2Array()
	for i in 13:
		points.append(Vector2(rect.end.x - r, rect.position.y + r) + Vector2.from_angle(-PI * 0.5 + PI * i / 12.0) * r)
	for i in 13:
		points.append(Vector2(rect.position.x + r, rect.position.y + r) + Vector2.from_angle(PI * 0.5 + PI * i / 12.0) * r)
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, edge, 2.0)


func _chevron(tip: Vector2, direction: int, ink: Color) -> void:
	var back := tip - Vector2(CHEVRON * direction, 0.0)
	draw_polyline(PackedVector2Array([back + Vector2(0.0, -CHEVRON), tip, back + Vector2(0.0, CHEVRON)]), ink, 2.5)


func _padlock(at: Vector2, ink: Color) -> void:
	draw_arc(at + Vector2(8.0, 7.0), 5.0, PI, TAU, 12, ink, 2.5)
	draw_rect(Rect2(at + Vector2(1.0, 7.0), Vector2(14.0, 11.0)), ink)


func _draw_dots_at(at: Vector2) -> void:
	var lit := 3 if _less_motion() else int(_dots * 3.0) % 3 + 1
	for i in 3:
		draw_circle(at + Vector2(6.0 + i * 14.0, 0.0), 4.0, UiTokens.ACCENT if i < lit else UiTokens.disabled(UiTokens.ACCENT))
