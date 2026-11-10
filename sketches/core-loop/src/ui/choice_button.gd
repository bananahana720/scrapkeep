extends Button

const Palette := preload("res://src/core/palette.gd")
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


func _init(action_id := "", key_id := "", words := "") -> void:
	action = action_id
	key = key_id
	text = words
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override("font", UiFonts.bold())
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_pressed_color", Palette.AMBER)
	set_asking(false)
	add_theme_color_override("font_disabled_color", Color(Palette.SAND, 0.4))
	_plates()
	custom_minimum_size = Vector2(0.0, 52.0)


# A choice that asks before it acts (the pause menu's Restart run and Quit) words itself in the hazard
# colour while it asks.
func set_asking(asking: bool) -> void:
	add_theme_color_override("font_color", Palette.HAZARD if asking else Palette.SAND)
	add_theme_color_override("font_hover_color", Palette.HAZARD if asking else Color.WHITE)
	add_theme_color_override("font_focus_color", Palette.HAZARD if asking else Color.WHITE)


# The same choice under another key: the cap and the plate's inset follow it.
func set_key(key_id: String) -> void:
	if key_id == key:
		return
	key = key_id
	_plates()
	queue_redraw()


func _plates() -> void:
	var left := PAD + Keycap.size_of(key, KEY_H).x + PAD
	add_theme_stylebox_override("normal", plate(Palette.VERDIGRIS, 2, left))
	add_theme_stylebox_override("hover", plate(Palette.SAND, 2, left))
	add_theme_stylebox_override("pressed", plate(Palette.AMBER, 3, left))
	add_theme_stylebox_override("focus", plate(Palette.SAND, 4, left, false))
	add_theme_stylebox_override("disabled", plate(Color(Palette.VERDIGRIS, 0.5), 2, left))


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
		tint = Color.WHITE
	Keycap.draw(self, Vector2(PAD + Keycap.size_of(key, KEY_H).x * 0.5, size.y * 0.5), key, tint, KEY_H)
