extends "res://src/ui/choice_button.gd"

# A settings row that shows what it sets and its present value without a "Label: value" string: the label
# is the button's text, and the value is drawn on its right as its own mark. An on-off row wears a pip,
# filled when on and a ring when off, so the state reads by shape and not by tint alone. A row with named
# steps or a number draws that value as right-hand text. `data()` is what a test reads; nothing parses
# the drawn text. With no key the row is a plain plate with its label at the left, as the settings page
# lays it out; with a key it sits in a column of keyed rows (the pause menu's Radio and Breath).

const NONE := -1
const OFF := 0
const ON := 1
const PIP_R := 9.0

var words := ""
var value := ""
var pip := NONE


func _init(action_id := "", key_id := "", row_words := "") -> void:
	super(action_id, key_id, row_words)
	words = row_words


func _plates() -> void:
	if key != "":
		super()
		return
	var left := PAD * 1.5
	add_theme_stylebox_override("normal", plate(Palette.VERDIGRIS, 2, left))
	add_theme_stylebox_override("hover", plate(Palette.SAND, 2, left))
	add_theme_stylebox_override("pressed", plate(Palette.AMBER, 3, left))
	add_theme_stylebox_override("focus", plate(Palette.SAND, 4, left, false))
	add_theme_stylebox_override("disabled", plate(Color(Palette.VERDIGRIS, 0.5), 2, left))


# Shows the label and one value: a pip state (ON or OFF) or right-hand text, never both.
func show_row(row_words: String, shown_value := "", pip_state := NONE) -> void:
	words = row_words
	text = row_words
	value = shown_value
	pip = pip_state
	queue_redraw()


# The row as data: its label, its right-hand text ("" for a pip row) and its pip state (NONE, OFF or ON).
func data() -> Dictionary:
	return {"label": words, "value": value, "pip": pip}


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray([words])
	if value != "":
		out.append(value)
	return out


func _draw() -> void:
	if key != "":
		super()
	if pip == NONE and value == "":
		return
	var ink := Color(Palette.SAND, 0.4) if disabled else (Color.WHITE if is_hovered() or has_focus() else Palette.SAND)
	var edge := size.x - PAD * 1.5
	if pip != NONE:
		var centre := Vector2(edge - PIP_R, size.y * 0.5)
		if pip == ON:
			draw_circle(centre, PIP_R, ink)
		else:
			draw_arc(centre, PIP_R - 1.5, 0.0, TAU, 24, ink, 3.0)
		return
	var font := UiFonts.bold()
	var baseline := size.y * 0.5 + (font.get_ascent(22) - font.get_descent(22)) * 0.5
	draw_string(font, Vector2(edge - UiFonts.width(value, 22), baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
