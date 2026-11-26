extends Button

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const KeycapView := preload("res://src/ui/keycap_view.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const CosmeticWear := preload("res://src/core/cosmetic_wear.gd")
const Achievements := preload("res://src/core/achievements.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")


const KEY_H := 28.0
const MIN_ICON_SIDE := 28.0
const HEIGHT := 648.0
const PAD := 18.0
const PREVIEW_H := 260.0
const PREVIEW_MIN := 150.0
const LIFT := 0.06
const BACK := 0.04
const RATE := 9.0
const CELL_ICON := 40.0
const CELL_CAP := 26.0
const MOUSE_CAP := 36.0
const PIP := 9.0
const CHIP_ICON := 24.0
const CHIP_CAP := 20.0
const TRADEOFF_H := 48.0
const WORD_SIZE := UiTokens.CAPTION
const SHAKE := 0.25
const HINT_GAP := 2.0
const HINT_INSET := 4.0
const LOCK_DIM := 0.4
const GREY := """shader_type canvas_item;
uniform float level = 0.4;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(vec3(dot(c.rgb, vec3(0.299, 0.587, 0.114)) * level), c.a);
}
"""


class LockGlyph extends Control:
	var tint := Color.WHITE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_arc(Vector2(w * 0.5, h * 0.4), w * 0.24, PI, TAU, 16, tint, 3.0)
		draw_line(Vector2(w * 0.26, h * 0.4), Vector2(w * 0.26, h * 0.5), tint, 3.0)
		draw_line(Vector2(w * 0.74, h * 0.4), Vector2(w * 0.74, h * 0.5), tint, 3.0)
		draw_rect(Rect2(w * 0.14, h * 0.48, w * 0.72, h * 0.44), tint)


class Swatch extends Control:
	const FACE := 26.0
	const TARGET := 44.0
	var color := Color.WHITE
	var edge := Color.WHITE
	signal clicked

	func _draw() -> void:
		var face := Rect2((size - Vector2(FACE, FACE)) * 0.5, Vector2(FACE, FACE))
		draw_rect(face, color)
		draw_rect(face, edge, false, 2.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()
			accept_event()

static var reduced_motion := false

var def: Resource
var key := ""
var openness := 0.0
var preview
var _details: Array[CanvasItem] = []
var _cells: Array = []
var _keys_row: VBoxContainer
var _rows_shown: Array = []
var _box: VBoxContainer
var _fade_rect: ColorRect
var _preview_h := PREVIEW_H
var _name_label: Label
var _role_label: Label
var _line: Label
var _tradeoff: Label
var _serial := 0
var locked := false
var hint_text := ""
var _glyph: TextureRect
var _lock
var _hint: Label
var _paint_row: HBoxContainer
var _swatch
var _paint_label: Label
var _alt_row: HBoxContainer
var _alt_button: Button
var _profile
var _sitting := false
var _shake := 0.0
var _styles := {}


func _init(class_def: Resource = null, key_id := "", width := 420.0) -> void:
	def = class_def
	key = key_id
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(width, HEIGHT)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	accessibility_name = String(def.display_name) if def != null else ""
	var color: Color = ClassDef.screen_color(def.color) if def != null else Palette.SAND
	_serial = hash(def.id) if def != null else 0
	add_theme_stylebox_override("normal", _frame(Color(color, 0.6), 2))
	add_theme_stylebox_override("hover", _frame(color, 3))
	add_theme_stylebox_override("pressed", _frame(Palette.AMBER, 4))
	add_theme_stylebox_override("focus", _frame(color.lightened(0.35), 4, false))
	add_theme_stylebox_override("disabled", _frame(Color(color, 0.3), 2))
	mouse_entered.connect(_on_hover)
	pressed.connect(_on_pressed)
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
	_box = box
	preview = ClassPreview.new(def, Vector2(width - 2.0 * PAD, PREVIEW_H))
	box.add_child(preview)
	_fade_rect = _fade(width)
	add_child(_fade_rect)
	_build_overlay(width, color)
	box.add_child(_name_row(color, width))
	var _tag_row := HBoxContainer.new()
	_tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tag_row.add_theme_constant_override("separation", UiTokens.GAP_S)
	_tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_tag_row)
	var role := _tagged(_text(ClassKit.role_line(def), UiTokens.CAPTION, Color(Palette.SAND, 0.8)), color, _serial + 1)
	if role.get_combined_minimum_size().x > width - 2.0 * PAD:
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role.custom_minimum_size.x = width - 2.0 * PAD
	_role_label = role
	_tag_row.add_child(role)
	_details.append(role)
	_build_alt_row(_tag_row, color)
	var line := _text(ClassKit.fantasy(def), UiTokens.BODY, Palette.SAND)
	line.custom_minimum_size = Vector2(0.0, 58.0)
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line = line
	box.add_child(line)
	var tradeoff_slot := Control.new()
	tradeoff_slot.custom_minimum_size.y = TRADEOFF_H
	tradeoff_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tradeoff_slot)
	_tradeoff = _text(ClassKit.tradeoff(def), WORD_SIZE, Palette.SAND)
	_tradeoff.name = "Tradeoff"
	_tradeoff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tradeoff.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tradeoff.clip_text = true
	tradeoff_slot.add_child(_tradeoff)
	_tradeoff.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_details.append(_tradeoff)
	var keys := VBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_BEGIN
	keys.add_theme_constant_override("separation", 4)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(keys)
	_keys_row = keys
	var records := ClassKit.card_keys(def)
	var bar := records.filter(func(r): return r.get("row", "bar") == "bar")
	var chips := records.filter(func(r): return r.get("row", "bar") != "bar")
	for row_records in [bar, chips]:
		if row_records.is_empty():
			continue
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		keys.add_child(row)
		var chip: bool = row_records == chips
		var room: float = width - 2.0 * PAD - 4.0 * (row_records.size() - 1)
		var fit := _fit_cells(row_records, room / maxf(1.0, row_records.size()), floorf(room))
		var layout := {} if chip else _cell_layout(row_records, floorf(room), fit["scale"])
		var keys_in_row: Array = []
		for i in row_records.size():
			var record: Dictionary = row_records[i]
			row.add_child(_chip(record, color, fit["scale"]) if chip else _cell(record, color, float(layout["widths"][i]), fit["scale"], int(layout["word_size"]), bool(layout["wrap"])))
			keys_in_row.append(record["key"])
		_rows_shown.append(keys_in_row)
	_apply()


func keys_shown() -> Array:
	return _cells.map(func(c): return {"key": c["key"], "icon": c["icon"], "words": c["words"]})


func key_rows() -> Array:
	return _rows_shown.duplicate(true)


func key_cells() -> Array:
	var out := []
	if _keys_row == null:
		return out
	for row in _keys_row.get_children():
		out.append_array(row.get_children())
	return out


func name_label() -> Label:
	return _name_label


func role_label() -> Label:
	return _role_label


func fantasy_label() -> Label:
	return _line


func laid_out() -> bool:
	return _box == null or (_box.size.x > 1.0 and _line.size.x > 1.0)


func tradeoff_text() -> String:
	return _tradeoff.text if _tradeoff != null else ""


func overflow() -> float:
	if _box == null:
		return 0.0
	return maxf(0.0, _box.get_combined_minimum_size().y - (HEIGHT - (PAD + KEY_H + 8.0) - PAD))


func shrink_preview(by: float) -> void:
	if preview == null or by <= 0.0:
		return
	_preview_h = maxf(PREVIEW_MIN, PREVIEW_H - by)
	preview.custom_minimum_size.y = _preview_h
	var top := PAD + KEY_H + 8.0 + _preview_h - 40.0
	_seat_hint()
	_paint_row.position.y = top
	_fade_rect.position.y = PAD + KEY_H + 8.0 + _preview_h - UiTokens.EDGE
	queue_redraw()


func is_open() -> bool:
	return has_focus()


func reset() -> void:
	openness = 0.0
	_shake = 0.0
	rotation = 0.0
	_apply()
	if preview != null:
		preview.reset()


func words() -> String:
	return "%s, %s. %s" % [def.display_name, ClassKit.role_line(def), ClassKit.fantasy(def)] if def != null else ""


func _build_overlay(width: float, color: Color) -> void:
	var top := PAD + KEY_H + 8.0 + PREVIEW_H - 40.0
	var span := Vector2(width - 2.0 * PAD, 34.0)
	_hint = _text("", UiTokens.CAPTION, Color(Palette.SAND, 0.9))
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var plate := ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, _serial + 2)
	plate.content_margin_left = 6.0
	plate.content_margin_right = 6.0
	plate.content_margin_top = 3.0
	plate.content_margin_bottom = 3.0
	_hint.add_theme_stylebox_override("normal", plate)
	_hint.add_theme_constant_override("line_spacing", -2)
	_hint.position.x = HINT_INSET
	_hint.size.x = width - 2.0 * HINT_INSET
	_hint.visible = false
	add_child(_hint)
	_seat_hint()
	_details.append(_hint)
	_paint_row = HBoxContainer.new()
	_paint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_paint_row.add_theme_constant_override("separation", 8)
	_paint_row.position = Vector2(PAD, top)
	_paint_row.size = span
	_paint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint_row.visible = false
	add_child(_paint_row)
	_swatch = Swatch.new()
	_swatch.custom_minimum_size = Vector2(Swatch.TARGET, Swatch.TARGET)
	_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_swatch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_swatch.clicked.connect(func(): if openness > 0.5: cycle_paint())
	_paint_row.add_child(_swatch)
	_paint_label = _text("", UiTokens.BODY, Palette.SAND)
	_paint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_paint_row.add_child(_paint_label)
	_details.append(_paint_row)


func _build_alt_row(parent: HBoxContainer, color: Color) -> void:
	_alt_row = HBoxContainer.new()
	_alt_row.name = "AltLoadoutRow"
	_alt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_alt_row.add_theme_constant_override("separation", UiTokens.GAP_XS)
	_alt_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_alt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alt_row.visible = false
	parent.add_child(_alt_row)
	var alt_cap := KeycapView.new("key_l", Palette.SAND, 20.0)
	alt_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_alt_row.add_child(alt_cap)
	_alt_button = Button.new()
	_alt_button.name = "AltLoadoutButton"
	_alt_button.focus_mode = Control.FOCUS_ALL
	_alt_button.expand_icon = true
	_alt_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_alt_button.add_theme_font_override("font", UiFonts.bold())
	_alt_button.add_theme_font_size_override("font_size", UiTokens.CAPTION)
	_alt_button.add_theme_color_override("font_color", Palette.LEDGER_CREAM)
	_alt_button.add_theme_color_override("font_hover_color", UiTokens.TEXT)
	_alt_button.add_theme_color_override("font_focus_color", UiTokens.TEXT)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var tag = ScrapFrame.hand_tag(UiTokens.Hand.KEEPER, _serial + 5)
		tag.border_color = Palette.AMBER if st in ["hover", "pressed", "focus"] else Color(color, 0.75)
		_alt_button.add_theme_stylebox_override(st, tag)
	_alt_button.pressed.connect(func(): if openness > 0.5: cycle_alt_loadout())
	_alt_row.add_child(_alt_button)
	_details.append(_alt_row)


func _seat_hint() -> void:
	var foot := PAD + KEY_H + 8.0 + _preview_h - HINT_GAP
	_hint.offset_bottom = foot
	_hint.offset_top = foot - 34.0


func hint_rect() -> Rect2:
	return _hint.get_global_rect() if _hint.visible else Rect2()


func set_locked(is_locked: bool, hint := "") -> void:
	locked = is_locked
	hint_text = hint
	if def == null:
		return
	var color: Color = ClassDef.screen_color(def.color)
	var edge := Palette.SLATE if locked else color
	if _styles.is_empty():
		for state in ["normal", "hover", "pressed", "focus"]:
			_styles[state] = get_theme_stylebox(state)
	if locked:
		add_theme_stylebox_override("normal", _frame(Color(edge, 0.7), 2))
		add_theme_stylebox_override("hover", _frame(edge, 3))
		add_theme_stylebox_override("pressed", _frame(edge, 3))
		add_theme_stylebox_override("focus", _frame(edge.lightened(0.3), 4, false))
	else:
		for state in _styles:
			add_theme_stylebox_override(state, _styles[state])
	_glyph.visible = not locked
	_lock.visible = locked
	_hint.text = hint_text if hint_text != "" else "Locked"
	_hint.visible = locked
	if locked:
		var shade := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = GREY
		shade.shader = shader
		shade.set_shader_parameter("level", LOCK_DIM)
		preview.material = shade
	else:
		preview.material = null
	_paint_row.visible = not locked and owns_paint()
	if _alt_row != null:
		_alt_row.visible = not locked and owns_alt()
	_apply()


func bind_profile(profile, sitting := false) -> void:
	_profile = profile
	_sitting = sitting
	if def == null:
		return
	_paint_row.visible = not locked and owns_paint()
	_show_paint()
	_show_alt()


func alt_options() -> Array:
	var out: Array = [""]
	if _profile == null or def == null:
		return out
	for id in MetaOptions.alt_loadouts_for(String(def.id)):
		if MetaOptions.alt_loadout_open(id, _profile, _sitting):
			out.append(id)
	return out


func owns_alt() -> bool:
	return alt_options().size() > 1


func alt_shown() -> String:
	if _profile == null or def == null:
		return ""
	var eq := MetaOptions.equipped_alt_loadouts(_profile, String(def.id), false, _sitting)
	for slot in eq:
		return String(eq[slot])
	return ""


func cycle_alt_loadout() -> String:
	if locked or not owns_alt() or _profile == null or def == null:
		return ""
	var opts := alt_options()
	var current := alt_shown()
	var next: String = opts[(opts.find(current) + 1) % opts.size()]
	var eq := MetaOptions.equipped_alt_loadouts(_profile, String(def.id), false, _sitting)
	for slot in eq.keys():
		MetaOptions.clear_alt_loadout(_profile, String(def.id), String(slot))
	if next != "":
		MetaOptions.equip_alt_loadout(_profile, next, _sitting)
	if _profile.can_save:
		_profile.save()
	_show_alt()
	return next


func _show_alt() -> void:
	if _alt_row == null or _alt_button == null:
		return
	var has := not locked and owns_alt()
	_alt_row.visible = has
	var current := alt_shown()
	var icon_id := "rel_alt_loadout" if current == "" else ("rel_" + current)
	_alt_button.icon = Icons.texture(icon_id)
	if current == "":
		_alt_button.text = "Stock kit"
	else:
		_alt_button.text = String(MetaOptions.alt_loadout(current).get("name", current))
	_refresh_alt_cells()


func _refresh_alt_cells() -> void:
	if def == null or _cells.is_empty():
		return
	var recs := ClassKit.card_keys_for(def, _profile, _sitting)
	for i in mini(recs.size(), _cells.size()):
		var rec: Dictionary = recs[i]
		var cell: Dictionary = _cells[i]
		cell["icon"] = String(rec["icon"])
		if cell.has("icon_node") and is_instance_valid(cell["icon_node"]):
			var icon_node: TextureRect = cell["icon_node"]
			icon_node.texture = Icons.texture(cell["icon"])
			icon_node.modulate = Icons.tint(cell["icon"], cell.get("color", Palette.SAND))
		if cell.has("label_node") and is_instance_valid(cell["label_node"]):
			var words := String(rec["words"])
			cell["words"] = words
			var gap := words.find(" ")
			(cell["label_node"] as Label).text = words if gap < 0 else words.left(gap) + "\n" + words.substr(gap + 1)


func paint_options() -> Array:
	var out: Array = [""]
	for id in Cosmetics.for_slot("paint", def.id):
		if CosmeticWear.owns(_profile, id):
			out.append(id)
	return out


func owns_paint() -> bool:
	if _profile == null or def == null:
		return false
	if paint_shown() != "":
		return true
	for id in Cosmetics.for_slot("paint", def.id):
		if not Cosmetics.row(id)["starter"] and CosmeticWear.owns(_profile, id):
			return true
	return false


func paint_shown() -> String:
	return CosmeticWear.worn(_profile, def.id, "paint")


func cycle_paint() -> String:
	if locked or not owns_paint():
		return ""
	var options := paint_options()
	var next: String = options[(options.find(paint_shown()) + 1) % options.size()]
	_profile.equip(def.id, "paint", next)
	_profile.save()
	_show_paint()
	return next


func _show_paint() -> void:
	var id := paint_shown()
	preview.paint_id = id
	if id == "":
		_swatch.color = Color(Palette.SAND, 0.15)
		_swatch.edge = Color(Palette.SAND, 0.7)
		_paint_label.visible = false
	else:
		_swatch.color = Cosmetics.row(id)["tint"]
		_swatch.edge = Palette.SAND
		_paint_label.text = Cosmetics.row(id)["name"]
		_paint_label.visible = true
	_swatch.queue_redraw()


static func unlock_hint(def, progress) -> String:
	if def.starter:
		return ""
	var unlock: Dictionary = def.unlock
	if unlock.is_empty() and ClassDef.by_id(def.id) != null:
		unlock = ClassDef.by_id(def.id).unlock
	var label := String(unlock.get("label", ""))
	if label == "":
		return ""
	var id: String = ClassDef.unlock_row(String(unlock.get("by", "")))
	var need := int(Achievements.row(id).get("count", 1))
	if need <= 1:
		return label
	var have := mini(int(progress.count_of(id)) if progress != null else 0, need)
	return "%s (%d/%d)" % [label, have, need]


func _on_pressed() -> void:
	if locked:
		_shake = SHAKE


func _gui_input(event: InputEvent) -> void:
	if _look_input(event):
		accept_event()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X and is_open() and not locked:
		cycle_paint()
		accept_event()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y and is_open() and not locked and owns_alt():
		cycle_alt_loadout()
		accept_event()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P and is_open() and not locked:
		cycle_paint()
		accept_event()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L and is_open() and not locked and owns_alt():
		cycle_alt_loadout()
		accept_event()


func _look_input(event: InputEvent) -> bool:
	if preview == null or not preview.has_method("look_drag"):
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			preview.look_dragging = event.pressed
			preview.look_drag(Vector2.ZERO)
			return true
		if preview.look_dragging and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			preview.look_zoom(1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
			return true
	elif event is InputEventMouseMotion and preview.look_dragging:
		preview.look_drag(event.relative)
		return true
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y] and absf(event.axis_value) > 0.2:
		var push := Vector2(event.axis_value, 0.0) if event.axis == JOY_AXIS_RIGHT_X else Vector2(0.0, event.axis_value)
		preview.look_drag(push * 18.0)
		return true
	return false


func _name_row(color: Color, width: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := TextureRect.new()
	_glyph = glyph
	var icon_id := Icons.class_icon_id(def.id)
	var portrait := Icons.from_file(icon_id)
	glyph.texture = Icons.texture(icon_id) if portrait else Icons.shape(def.shape)
	glyph.modulate = Icons.tint(icon_id, color) if portrait else color
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.custom_minimum_size = Vector2(MIN_ICON_SIDE, MIN_ICON_SIDE)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	_lock = LockGlyph.new()
	_lock.tint = Palette.SLATE
	_lock.custom_minimum_size = Vector2(28.0, 28.0)
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock.visible = false
	row.add_child(_lock)
	var font_size := UiTokens.HEADING
	if UiFonts.bold().get_string_size(def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 38.0 > width - 2.0 * PAD:
		font_size = UiTokens.LABEL
	var name_label := _text(def.display_name, font_size, color)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name_label = name_label
	row.add_child(name_label)
	return row


func _fit_cells(records: Array, cell_w: float, room: float) -> Dictionary:
	var scale := 1.0
	while scale > 0.5 and _caps_width(records, scale, 0.0) > room:
		scale -= 0.05
	var side := cell_w
	while side > MIN_ICON_SIDE and _caps_width(records, scale, side) > room:
		side = ceilf(side) - 1.0
	return {"side": side, "scale": scale}


func _caps_width(records: Array, scale: float, side: float) -> float:
	var total := 0.0
	for record in records:
		total += maxf(side, Keycap.size_of(record["key"], _cap_height(record["key"]) * scale).x)
	return total


func _cap_height(key_name: String) -> float:
	return MOUSE_CAP if Keycap.is_mouse(key_name) else CELL_CAP


func _chip(record: Dictionary, color: Color, _cap_scale: float) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", UiTokens.GAP_XS)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = Icons.texture(record["icon"])
	icon.modulate = Icons.tint(record["icon"], color)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(CHIP_ICON, CHIP_ICON)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	var cap := KeycapView.new(record["key"], ScrapFrame.wear(color, _serial + record["key"].hash()), CHIP_CAP)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(cap)
	_details.append(cap)
	_cells.append({"key": record["key"], "icon": record["icon"], "words": "", "icon_node": icon, "color": color})
	return cell


func _cell_layout(records: Array, room: float, cap_scale: float) -> Dictionary:
	var font := UiFonts.bold()
	var word_size := WORD_SIZE
	var need: Array = []
	var total := 0.0
	while word_size >= 10:
		need.clear()
		total = 0.0
		for record in records:
			var words := String(record["words"])
			var gap := words.find(" ")
			var lines: Array = [words] if gap < 0 else [words.left(gap), words.substr(gap + 1)]
			var text_w := 0.0
			for part in lines:
				text_w = maxf(text_w, ceilf(font.get_string_size(String(part), HORIZONTAL_ALIGNMENT_LEFT, -1, word_size).x) + 2.0)
			var cap_w := Keycap.size_of(String(record["key"]), _cap_height(String(record["key"])) * cap_scale).x
			var w := maxf(maxf(MIN_ICON_SIDE, cap_w), text_w)
			need.append(w)
			total += w
		if total <= room or word_size == 10:
			break
		word_size -= 1
	var out: Array = []
	var wrap := total > room
	if not wrap:
		var extra := (room - total) / maxf(1.0, float(need.size()))
		for w in need:
			out.append(floorf(float(w) + extra))
	else:
		var scale := room / maxf(total, 1.0)
		for w in need:
			out.append(maxf(MIN_ICON_SIDE, floorf(float(w) * scale)))
	return {"widths": out, "word_size": word_size, "wrap": wrap}


func _cell(record: Dictionary, color: Color, width: float, cap_scale := 1.0, word_size := WORD_SIZE, wrap := false) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(width, 0.0)
	cell.add_theme_constant_override("separation", 4)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = Icons.texture(record["icon"])
	icon.modulate = Icons.tint(record["icon"], color)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var side := minf(CELL_ICON, width)
	icon.custom_minimum_size = Vector2(side, side)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	var cap := KeycapView.new(record["key"], ScrapFrame.wear(color, _serial + record["key"].hash()), _cap_height(record["key"]) * cap_scale)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cap.custom_minimum_size.y = maxf(cap.custom_minimum_size.y, MOUSE_CAP)
	cell.add_child(cap)
	_details.append(cap)
	var words: String = record["words"]
	var gap := words.find(" ")
	var label := _text(words if gap < 0 else words.left(gap) + "\n" + words.substr(gap + 1), word_size, Palette.SAND)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.y = UiFonts.bold().get_height(WORD_SIZE) * 2.0
	label.max_lines_visible = 2
	cell.add_child(label)
	_details.append(label)
	_cells.append({"key": record["key"], "icon": record["icon"], "words": words, "icon_node": icon, "label_node": label, "color": color})
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


func _fade(width: float) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = UiTokens.LINE
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.position = Vector2(PAD, PAD + KEY_H + 8.0 + PREVIEW_H - UiTokens.EDGE)
	rule.size = Vector2(width - 2.0 * PAD, UiTokens.EDGE)
	return rule


func _backdrop(tint: Color) -> void:
	var top := PAD + KEY_H + 8.0
	var rect := Rect2(Vector2(PAD, top), Vector2(size.x - 2.0 * PAD, _preview_h))
	var sky := Palette.VERDIGRIS.lerp(Palette.SAND, 0.35)
	var warm := Palette.SANDSTONE.darkened(0.45).lerp(tint, 0.15 + 0.1 * openness)
	var mid := rect.size.y * 0.55
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, mid)), sky)
	draw_rect(Rect2(rect.position + Vector2(0.0, mid), Vector2(rect.size.x, rect.size.y - mid)), warm)


func _frame(edge: Color, width: int, fill := true) -> StyleBox:
	return keeper_plate(edge, _serial, width, fill)


static func keeper_plate(edge: Color, serial: int, width: int, fill := true) -> StyleBox:
	var box = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, serial)
	box.border_color = edge
	box.border_width = width
	box.tape = 0.5
	if not fill:
		box.bg_color = Color(box.bg_color, 0.0)
		box.rivets = false
		box.halftone = false
		box.tape = -1.0
	return box


func _tagged(label: Label, color: Color, serial: int) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tag = ScrapFrame.hand_tag(UiTokens.Hand.KEEPER, serial)
	tag.border_color = Color(color, 0.55)
	label.add_theme_stylebox_override("normal", tag)
	return label


func _on_hover() -> void:
	if not has_focus():
		grab_focus()


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
	_shake = maxf(0.0, _shake - delta)
	rotation = 0.0 if reduced_motion else sin(_shake * 70.0) * 0.035 * (_shake / SHAKE)
	openness = move_toward(openness, 1.0 if is_open() else 0.0, delta * RATE * (0.35 + openness))
	if _swatch != null:
		_swatch.mouse_filter = Control.MOUSE_FILTER_STOP if openness > 0.5 else Control.MOUSE_FILTER_IGNORE
	if _alt_button != null:
		_alt_button.mouse_filter = Control.MOUSE_FILTER_STOP if openness > 0.5 else Control.MOUSE_FILTER_IGNORE
	_apply()
	queue_redraw()


func _apply() -> void:
	var k := smoothstep(0.0, 1.0, openness)
	var rival := _rival_open()
	pivot_offset = size * 0.5
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
	var tint: Color = ClassDef.screen_color(def.color) if def != null else Palette.SAND
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
