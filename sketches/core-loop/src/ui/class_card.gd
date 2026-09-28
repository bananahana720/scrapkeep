extends Button

const Palette := preload("res://src/core/palette.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const KeycapView := preload("res://src/ui/keycap_view.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")

# A class choice that sells its pilot. At rest: the hero shell turning on a plinth in
# the class colour, the role glyph (the row's shape) and name, the fantasy line, a
# difficulty mark, and the pilot's keys as ability icons over keycaps. Hover or focus
# opens it: the card lifts, the others step back, the preview plays the signature
# move, and each key gains its two words and the role line fades in. Those words show
# only on the open card, so the screen stays calm until you ask about one pilot.
# Colour and shape come from the class row, keys and icons from class_kit.gd.
#
# The mouse opens a card by hovering it (hover takes focus, so there is one open card).
# The arrows move focus and Enter or Space picks it; the number keys pick at once
# (game._screen_key). With nothing focused, the first arrow focuses a card.

const KEY_H := 28.0
const HEIGHT := 600.0
const PAD := 18.0
const PREVIEW_H := 260.0
const LIFT := 0.06
const BACK := 0.04
const RATE := 9.0
const CELL_ICON := 40.0
const CELL_CAP := 26.0
const MOUSE_CAP := 36.0
const PIP := 9.0

var def: Resource
var key := ""
# How open the card is, 0 to 1, eased toward has_focus().
var openness := 0.0
var preview
var _details: Array[CanvasItem] = []
var _cells: Array = []


func _init(class_def: Resource = null, key_id := "", width := 420.0) -> void:
	def = class_def
	key = key_id
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(width, HEIGHT)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var color: Color = def.color if def != null else Palette.SAND
	add_theme_stylebox_override("normal", _plate(Color(color, 0.6), 2))
	add_theme_stylebox_override("hover", _plate(color, 3))
	add_theme_stylebox_override("pressed", _plate(Palette.AMBER, 4))
	add_theme_stylebox_override("focus", _plate(color.lightened(0.35), 4, false))
	add_theme_stylebox_override("disabled", _plate(Color(color, 0.3), 2))
	mouse_entered.connect(_on_hover)
	if def == null:
		return
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = PAD
	box.offset_right = -PAD
	box.offset_top = PAD + KEY_H + 8.0
	box.offset_bottom = -PAD
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	preview = ClassPreview.new(def, Vector2(width - 2.0 * PAD, PREVIEW_H))
	box.add_child(preview)
	add_child(_fade(width))
	box.add_child(_name_row(color))
	var role := _text(ClassKit.role_line(def), 15, Color(Palette.SAND, 0.75))
	box.add_child(role)
	_details.append(role)
	var line := _text(ClassKit.fantasy(def), 18, Palette.SAND)
	# Two lines tall on every card, so the key rows line up across the three.
	line.custom_minimum_size = Vector2(0.0, 58.0)
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(line)
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 4)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(keys)
	var records := ClassKit.card_keys(def)
	var cell_w := (width - 2.0 * PAD - 4.0 * (records.size() - 1)) / maxf(1.0, records.size())
	for record in records:
		keys.add_child(_cell(record, color, cell_w))
	_apply()


# The four slots and any Space extra, as {key, icon, words} in the bar's order.
func keys_shown() -> Array:
	return _cells.map(func(c): return {"key": c["key"], "icon": c["icon"], "words": c["words"]})


func is_open() -> bool:
	return has_focus()


func words() -> String:
	return "%s, %s. %s" % [def.display_name, ClassKit.role_line(def), ClassKit.fantasy(def)] if def != null else ""


func _name_row(color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := TextureRect.new()
	glyph.texture = Icons.shape(def.shape)
	glyph.modulate = color
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(28.0, 28.0)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var name_label := _text(def.display_name, 30, color)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_label)
	return row


func _cell(record: Dictionary, color: Color, width: float) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(width, 0.0)
	cell.add_theme_constant_override("separation", 4)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = Icons.texture(record["icon"])
	icon.modulate = Icons.tint(record["icon"], color)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(CELL_ICON, CELL_ICON)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	var cap := KeycapView.new(record["key"], color, MOUSE_CAP if Keycap.is_mouse(record["key"]) else CELL_CAP)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(cap)
	# Every key's words stack on two lines, so no label wraps on its own and the row reads even.
	var words: String = record["words"]
	var gap := words.find(" ")
	var label := _text(words if gap < 0 else words.left(gap) + "\n" + words.substr(gap + 1), 13, Palette.SAND)
	cell.add_child(label)
	_details.append(label)
	_cells.append({"key": record["key"], "icon": record["icon"], "words": words})
	return cell


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


# The preview's lower edge sinks into the card, so the words sit on a quiet floor.
func _fade(width: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Palette.CHARCOAL, 0.0))
	gradient.set_color(1, Color(Palette.CHARCOAL, 0.94))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var fade := TextureRect.new()
	fade.texture = texture
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.position = Vector2(PAD, PAD + KEY_H + 8.0 + PREVIEW_H * 0.62)
	fade.size = Vector2(width - 2.0 * PAD, PREVIEW_H * 0.38 + 2.0)
	return fade


# The key art's sky: a lit upper half behind the sphere that fades into the card's dark
# lower region, where the words sit.
func _backdrop(tint: Color) -> void:
	var top := PAD + KEY_H + 8.0
	var rect := Rect2(Vector2(PAD, top), Vector2(size.x - 2.0 * PAD, PREVIEW_H))
	var sky := Palette.VERDIGRIS.lerp(Palette.SAND, 0.35)
	var warm := Palette.SANDSTONE.darkened(0.45).lerp(tint, 0.15)
	var floor_color := Color(Palette.CHARCOAL, 0.0)
	var mid := rect.position.y + rect.size.y * 0.55
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, mid), Vector2(rect.position.x, mid)]),
		PackedColorArray([sky, sky, warm, warm]))
	draw_polygon(PackedVector2Array([Vector2(rect.position.x, mid), Vector2(rect.end.x, mid), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([warm, warm, floor_color, floor_color]))
	var glow := rect.position + rect.size * Vector2(0.5, 0.4)
	for i in 6:
		draw_circle(glow, PREVIEW_H * (0.45 - 0.06 * i), Color(tint, 0.03 + 0.04 * openness))


static func _plate(edge: Color, width: int, fill := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = fill
	box.bg_color = Color(Palette.CHARCOAL, 0.94)
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(10)
	box.corner_detail = 3
	return box


func _on_hover() -> void:
	if not has_focus():
		grab_focus()


# With no card focused, the first arrow or accept lands on a card instead of nowhere.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or get_index() != 0 or get_viewport().gui_get_focus_owner() != null:
		return
	for action in ["ui_right", "ui_down", "ui_left", "ui_up", "ui_accept"]:
		if event.is_action_pressed(action):
			var cards := get_parent().get_children()
			(cards[-1] if action == "ui_left" else self).grab_focus()
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	openness = move_toward(openness, 1.0 if is_open() else 0.0, delta * RATE * (0.35 + openness))
	_apply()
	queue_redraw()


func _apply() -> void:
	var k := smoothstep(0.0, 1.0, openness)
	var rival := _rival_open()
	pivot_offset = Vector2(size.x * 0.5, size.y)
	scale = Vector2.ONE * (1.0 + LIFT * k - (BACK if rival else 0.0))
	modulate = Color(0.62, 0.62, 0.62) if rival else Color.WHITE
	for item in _details:
		item.modulate.a = k
	if preview != null:
		preview.open = openness


func _rival_open() -> bool:
	if get_parent() == null or is_open():
		return false
	for card in get_parent().get_children():
		if card != self and card.has_method("is_open") and card.is_open():
			return true
	return false


func _draw() -> void:
	var tint: Color = def.color if def != null else Palette.SAND
	Keycap.draw(self, Vector2(PAD + Keycap.size_of(key, KEY_H).x * 0.5, PAD + KEY_H * 0.5), key,
		Color.WHITE if is_open() else Palette.SAND, KEY_H)
	if def == null:
		return
	_backdrop(tint)
	var level := ClassKit.difficulty(def)
	var right := size.x - PAD - PIP
	for i in ClassKit.DIFFICULTY_MAX:
		var at := Vector2(right - (ClassKit.DIFFICULTY_MAX - 1 - i) * PIP * 2.4, PAD + KEY_H * 0.5)
		var diamond := PackedVector2Array([at + Vector2(0, -PIP), at + Vector2(PIP, 0), at + Vector2(0, PIP), at + Vector2(-PIP, 0)])
		if i < level:
			draw_colored_polygon(diamond, tint)
		diamond.append(diamond[0])
		draw_polyline(diamond, Color(tint, 0.9), 2.0)
	var icon_at := Vector2(right - (ClassKit.DIFFICULTY_MAX - 1) * PIP * 2.4 - PIP * 2.0 - 22.0, PAD + KEY_H * 0.5 - 11.0)
	draw_texture_rect(Icons.texture("res_difficulty"), Rect2(icon_at, Vector2(22.0, 22.0)), false,
		Icons.tint("res_difficulty", Color(Palette.SAND, 0.8)))
