extends Button

const Palette := preload("res://src/core/palette.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")

# A class choice: the class emblem large, its name, one line, and its number key. The
# card's edge is the class colour; hover and focus thicken it and lift the emblem.

const KEY_H := 28.0
const EMBLEM := 112.0

var def: Resource
var key := ""
var _emblem: TextureRect


func _init(class_def: Resource = null, key_id := "", width := 420.0) -> void:
	def = class_def
	key = key_id
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(width, 330.0)
	var color: Color = def.color if def != null else Palette.SAND
	add_theme_stylebox_override("normal", _plate(Color(color, 0.7), 2))
	add_theme_stylebox_override("hover", _plate(color, 4))
	add_theme_stylebox_override("pressed", _plate(Palette.AMBER, 4))
	add_theme_stylebox_override("focus", _plate(Color.WHITE, 3, false))
	add_theme_stylebox_override("disabled", _plate(Color(color, 0.3), 2))
	if def == null:
		return
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 22.0 + KEY_H
	box.offset_left = 22.0
	box.offset_right = -22.0
	box.offset_bottom = -18.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_emblem = TextureRect.new()
	var emblem_id := "cls_" + AbilitySlots.pilot_of(def)
	_emblem.texture = Icons.texture(emblem_id)
	_emblem.modulate = Icons.tint(emblem_id, color)
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem.custom_minimum_size = Vector2(EMBLEM, EMBLEM)
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_emblem)
	box.add_child(_text(def.display_name, 30, color))
	box.add_child(_text(one_line(def.pitch), 18, Palette.SAND))


# The class's pitch cut to its first sentence.
static func one_line(pitch: String) -> String:
	var stop := pitch.find(". ")
	return pitch.left(stop + 1) if stop >= 0 else pitch


func words() -> String:
	return "%s. %s" % [def.display_name, one_line(def.pitch)] if def != null else ""


func _text(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _plate(edge: Color, width: int, fill := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = fill
	box.bg_color = Color(Palette.CHARCOAL, 0.92)
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(8)
	box.corner_detail = 1
	return box


func _process(_delta: float) -> void:
	if _emblem != null:
		_emblem.scale = Vector2.ONE * (1.06 if is_hovered() or has_focus() else 1.0)
		_emblem.pivot_offset = _emblem.size * 0.5
	queue_redraw()


func _draw() -> void:
	Keycap.draw(self, Vector2(22.0 + Keycap.size_of(key, KEY_H).x * 0.5, 18.0 + KEY_H * 0.5), key,
		Color.WHITE if is_hovered() else Palette.SAND, KEY_H)
