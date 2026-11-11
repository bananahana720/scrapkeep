extends Button

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

# A menu choice: its key's cap on the left and its words on a charcoal plate. Hover
# brightens the plate's edge to bone, keyboard focus thickens it, a press edges it
# amber. The key still works on its own (game.gd _screen_key); the button is the same
# choice for the mouse.

const KEY_H := 26.0
const PAD := 14.0

var key := ""
var action := ""
# The two states a field shows besides focus, hover and disabled: waiting for an input the player
# is about to give (amber edge, the cap gives way to three stepping dots), and refused (alert edge).
var waiting := false
var alert := false
var _dots := 0.0


func _init(action_id := "", key_id := "", words := "") -> void:
	action = action_id
	key = key_id
	text = words
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override("font", UiFonts.bold())
	add_theme_font_size_override("font_size", UiTokens.LABEL)
	add_theme_color_override("font_pressed_color", Palette.AMBER)
	set_asking(false)
	add_theme_color_override("font_disabled_color", UiTokens.disabled(UiTokens.TEXT))
	_plates()
	custom_minimum_size = Vector2(0.0, UiTokens.TARGET)
	_name_for_readers()


# A screen reader hears the choice's words, or the cap's name on a cap-only button.
func _name_for_readers() -> void:
	if accessibility_name == "" or accessibility_name == Keycap.label(key):
		accessibility_name = text if text != "" else Keycap.label(key)


# A choice that asks before it acts (the pause menu's Restart run and Quit) words itself in the hazard
# colour while it asks.
func set_asking(asking: bool) -> void:
	add_theme_color_override("font_color", Palette.HAZARD if asking else Palette.SAND)
	add_theme_color_override("font_hover_color", Palette.HAZARD if asking else UiTokens.TEXT)
	add_theme_color_override("font_focus_color", Palette.HAZARD if asking else UiTokens.TEXT)


# The same choice under another key: the cap and the plate's inset follow it.
func set_key(key_id: String) -> void:
	if key_id == key:
		return
	key = key_id
	_plates()
	_name_for_readers()
	queue_redraw()


# Waiting: the field takes the next input (a key binder listening). Alert: the field refused one.
# Each wears its own edge; the words that say what to do sit under the field, with its owner.
func set_waiting(on: bool) -> void:
	waiting = on
	if on:
		alert = false
	set_process(on)
	_plates()
	queue_redraw()


func set_alert(on: bool) -> void:
	alert = on
	if on:
		waiting = false
		set_process(false)
	for color in ["font_color", "font_hover_color", "font_focus_color"]:
		if on:
			add_theme_color_override(color, UiTokens.ALERT)
		else:
			remove_theme_color_override(color)
	if not on:
		set_asking(false)
	_plates()
	queue_redraw()


func _process(delta: float) -> void:
	_dots += delta
	queue_redraw()


func _edge() -> Color:
	if alert:
		return UiTokens.ALERT
	if waiting:
		return UiTokens.ACCENT
	return UiTokens.LINE


func _plates() -> void:
	var left := PAD + Keycap.size_of(key, KEY_H).x + PAD
	add_theme_stylebox_override("normal", plate(_edge(), 2 if _edge() == UiTokens.LINE else UiTokens.FOCUS_EDGE, left))
	add_theme_stylebox_override("hover", plate(Palette.SAND if _edge() == UiTokens.LINE else _edge(), 2 if _edge() == UiTokens.LINE else UiTokens.FOCUS_EDGE, left))
	add_theme_stylebox_override("pressed", plate(Palette.AMBER, 3, left))
	add_theme_stylebox_override("focus", UiTokens.focus_ring(left))
	add_theme_stylebox_override("disabled", plate(UiTokens.disabled(UiTokens.LINE), 2, left))


static func plate(edge: Color, width: int, left: float, fill := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = fill
	box.bg_color = Color(Palette.CHARCOAL, 0.9)
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.corner_detail = 1
	box.content_margin_left = left
	box.content_margin_right = PAD * 1.5
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


func _draw() -> void:
	var tint := Palette.SAND if not disabled else Color(Palette.SAND, 0.4)
	if is_hovered() and not disabled:
		tint = UiTokens.TEXT
	if waiting:
		_draw_dots()
		return
	Keycap.draw(self, Vector2(PAD + Keycap.size_of(key, KEY_H).x * 0.5, size.y * 0.5), key, tint, KEY_H)


# Three dots light one after another while the field waits; with less motion they hold still, all lit.
func _draw_dots() -> void:
	var still := _less_motion()
	var lit := 3 if still else int(_dots * 3.0) % 3 + 1
	for i in 3:
		var at := Vector2(PAD + 6.0 + i * 14.0, size.y * 0.5)
		draw_circle(at, 4.0, UiTokens.ACCENT if i < lit else UiTokens.disabled(UiTokens.ACCENT))


func _less_motion() -> bool:
	return UiTokens.reduced_motion
