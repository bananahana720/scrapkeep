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

# A class choice that sells its pilot. At rest: the hero shell turning on a plinth in
# the class colour, the class emblem and name, the fantasy line, a
# difficulty mark, and the pilot's keys as ability icons over keycaps. Hover or focus
# opens it: the card lifts, the others step back, the preview plays the signature
# move, and each key gains its two words and the role line fades in. Those words show
# only on the open card, so the screen stays calm until you ask about one pilot.
# Colour and shape come from the class row, keys and icons from class_kit.gd. The frame
# is scrap (scrap_frame.gd): a riveted plate taped at the top, the role line on a stamped
# tag, keycaps from mismatched sets; the words, icons and letters stay crisp.
#
# A locked pilot (set_locked) keeps the card clickable but wears a slate plate, a dimmed
# grey preview and a lock where the role glyph sits; its hint, the achievement that
# unlocks it, shows with the other details when the card is open, and a click shakes it.
# An unlocked card also shows its paint (bind_profile): a swatch and name over the
# preview's foot, cycled by a click on the swatch or P while the card is open. The cycle
# holds only paints this profile owns, plus none, and each pick is saved.
#
# The mouse opens a card by hovering it (hover takes focus, so there is one open card).
# The arrows move focus and Enter or Space picks it; the number keys pick at once
# (game._screen_key). With nothing focused, the first arrow focuses a card.

const KEY_H := 28.0
const MIN_ICON_SIDE := 28.0  # the smallest a key icon may shrink to at six cards (roster ruling R-B)
const HEIGHT := 648.0
const PAD := 18.0
const PREVIEW_H := 260.0
# A row too tall for the card takes height from the preview, never below this.
const PREVIEW_MIN := 160.0
const LIFT := 0.06
const BACK := 0.04
const RATE := 9.0
const CELL_ICON := 40.0
const CELL_CAP := 26.0
const MOUSE_CAP := 36.0
const PIP := 9.0
const CHIP_ICON := 24.0
const CHIP_CAP := 14.0
const TRADEOFF_H := 44.0
const WORD_SIZE := UiTokens.CAPTION
const SHAKE := 0.25
const LOCK_DIM := 0.4
const GREY := """shader_type canvas_item;
uniform float level = 0.4;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(vec3(dot(c.rgb, vec3(0.299, 0.587, 0.114)) * level), c.a);
}
"""


# A small padlock in the role glyph's slot.
class LockGlyph extends Control:
	var tint := Color.WHITE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_arc(Vector2(w * 0.5, h * 0.4), w * 0.24, PI, TAU, 16, tint, 3.0)
		draw_line(Vector2(w * 0.26, h * 0.4), Vector2(w * 0.26, h * 0.5), tint, 3.0)
		draw_line(Vector2(w * 0.74, h * 0.4), Vector2(w * 0.74, h * 0.5), tint, 3.0)
		draw_rect(Rect2(w * 0.14, h * 0.48, w * 0.72, h * 0.44), tint)


# The square paint swatch; a click on it cycles the paint.
class Swatch extends Control:
	var color := Color.WHITE
	var edge := Color.WHITE
	signal clicked

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), color)
		draw_rect(Rect2(Vector2.ZERO, size), edge, false, 2.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()
			accept_event()

# Reduced motion (Game.set_reduced_motion keeps it current): a locked card no longer shakes.
static var reduced_motion := false

var def: Resource
var key := ""
# How open the card is, 0 to 1, eased toward has_focus().
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
var _profile
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
	var color: Color = def.color if def != null else Palette.SAND
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
	var role := _tagged(_text(ClassKit.role_line(def), UiTokens.CAPTION, Color(Palette.SAND, 0.8)), color, _serial + 1)
	# A tag wider than the card wraps at the card's inner width instead of widening the column.
	if role.get_combined_minimum_size().x > width - 2.0 * PAD:
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role.custom_minimum_size.x = width - 2.0 * PAD
	_role_label = role
	box.add_child(role)
	_details.append(role)
	var line := _text(ClassKit.fantasy(def), UiTokens.BODY, Palette.SAND)
	# Two lines tall on every card, so the key rows line up across the three.
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
	# Two rows (design-v3/SKILL-BAR.md section 5): the bar as it plays (1, 2, 3, Q), then the
	# chips (RMB, Shift, Ctrl) and the Space extras, one short line of icons. The keycaps are the
	# same on every card, so they read on the open card only, beside the words; the icons sell
	# the pilot at rest.
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
		var keys_in_row: Array = []
		for record in row_records:
			row.add_child(_chip(record, color, fit["scale"]) if chip else _cell(record, color, fit["side"], fit["scale"]))
			keys_in_row.append(record["key"])
		_rows_shown.append(keys_in_row)
	_apply()


# The bar row's keys and the chip row's, then any Space extra, as {key, icon, words}.
func keys_shown() -> Array:
	return _cells.map(func(c): return {"key": c["key"], "icon": c["icon"], "words": c["words"]})


# The keys of each row: [[the bar], [the chips and extras]].
func key_rows() -> Array:
	return _rows_shown.duplicate(true)


# The key cells, both rows, for layout checks.
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


# True once the containers have given the column its width. Before that first sort a wrapped
# line measures one letter wide, so its height is no height to level a row by.
func laid_out() -> bool:
	return _box == null or (_box.size.x > 1.0 and _line.size.x > 1.0)


func tradeoff_text() -> String:
	return _tradeoff.text if _tradeoff != null else ""


# How far the built column runs past the card's floor; zero when it fits.
func overflow() -> float:
	if _box == null:
		return 0.0
	return maxf(0.0, _box.get_combined_minimum_size().y - (HEIGHT - (PAD + KEY_H + 8.0) - PAD))


# The preview gives up height so the column fits. The row passes one value to every card
# so every key row ends on the same bottom edge (the rows start at different heights because
# the role and fantasy text above them wrap differently).
func shrink_preview(by: float) -> void:
	if preview == null or by <= 0.0:
		return
	_preview_h = maxf(PREVIEW_MIN, PREVIEW_H - by)
	preview.custom_minimum_size.y = _preview_h
	var top := PAD + KEY_H + 8.0 + _preview_h - 40.0
	_hint.position.y = top
	_paint_row.position.y = top
	_fade_rect.position.y = PAD + KEY_H + 8.0 + _preview_h - UiTokens.EDGE
	queue_redraw()


func is_open() -> bool:
	return has_focus()


func words() -> String:
	return "%s, %s. %s" % [def.display_name, ClassKit.role_line(def), ClassKit.fantasy(def)] if def != null else ""


# The foot of the preview: the locked hint, or the paint swatch and name. Both are card
# details, so they read only on the open card and the calm screen keeps its word count.
func _build_overlay(width: float, color: Color) -> void:
	var top := PAD + KEY_H + 8.0 + PREVIEW_H - 40.0
	var span := Vector2(width - 2.0 * PAD, 34.0)
	_hint = _text("", UiTokens.CAPTION, Color(Palette.SAND, 0.9))
	_hint.position = Vector2(PAD, top)
	_hint.size = span
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.visible = false
	add_child(_hint)
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
	_swatch.custom_minimum_size = Vector2(26.0, 26.0)
	_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_swatch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_swatch.clicked.connect(func(): if openness > 0.5: cycle_paint())
	_paint_row.add_child(_swatch)
	_paint_label = _text("", UiTokens.BODY, Palette.SAND)
	_paint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_paint_row.add_child(_paint_label)
	_details.append(_paint_row)


# A locked pilot's card: still clickable (the gate refuses it), but slate, grey and quiet.
func set_locked(is_locked: bool, hint := "") -> void:
	locked = is_locked
	hint_text = hint
	if def == null:
		return
	var color: Color = def.color
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
	_apply()


# The profile whose owned paints this card may offer. The preview wears the equipped one.
func bind_profile(profile) -> void:
	_profile = profile
	if def == null:
		return
	_paint_row.visible = not locked and owns_paint()
	_show_paint()


# Paint ids this profile may wear on this pilot, none first: a starter row or a saved one.
func paint_options() -> Array:
	var out: Array = [""]
	for id in Cosmetics.for_slot("paint", def.id):
		if CosmeticWear.owns(_profile, id):
			out.append(id)
	return out


# Whether the card draws a paint row: the profile owns a paint beyond the starters, or one is worn.
# A fresh profile has nothing to choose here (the customize page still lists the starters).
func owns_paint() -> bool:
	if _profile == null or def == null:
		return false
	if paint_shown() != "":
		return true
	for id in Cosmetics.for_slot("paint", def.id):
		if not Cosmetics.row(id)["starter"] and CosmeticWear.owns(_profile, id):
			return true
	return false


# The equipped paint id, or "" when none or one this profile does not own.
func paint_shown() -> String:
	return CosmeticWear.worn(_profile, def.id, "paint")


# The next owned paint (or none), equipped and saved.
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


# What a locked pilot's card says: the class row's unlock label, with the lifetime count when
# the rule's achievement row needs more than one; a def made without unlock reads its id's row.
# Empty for a starter or a pilot with no label,
# so the card says only "Locked" and never something false. progress may be null (count 0).
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P and is_open() and not locked:
		cycle_paint()
		accept_event()


# Look closer at the pilot (class_preview.gd): right-drag or the right stick orbits, the wheel
# zooms while the right button is held. Locked pilots can be looked at too.
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
	# The name never wraps: it takes the heading step, or the label step when that does not fit
	# beside the 28 px glyph and gap.
	var font_size := UiTokens.HEADING
	if UiFonts.bold().get_string_size(def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 38.0 > width - 2.0 * PAD:
		font_size = UiTokens.LABEL
	var name_label := _text(def.display_name, font_size, color)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name_label = name_label
	row.add_child(name_label)
	return row


# Cells share the row evenly while every keycap fits its share. When the caps outgrow it
# (six cards), the cells without a wide cap narrow first, then every cap steps down 5%.
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


# A chip: a small icon over, on the open card, a small keycap, and no words, so the row under
# the bar stays short and the six-card row keeps its floor (roster_test R8). The chips are the
# shared grammar (harpoon, go verb, smash); the field notes' Keys page names them in words.
func _chip(record: Dictionary, color: Color, _cap_scale: float) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
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
	_cells.append({"key": record["key"], "icon": record["icon"], "words": ""})
	return cell


func _cell(record: Dictionary, color: Color, width: float, cap_scale := 1.0) -> VBoxContainer:
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
	# Letter caps sit in the mouse cap's height, so every key's words start on one line.
	cap.custom_minimum_size.y = maxf(cap.custom_minimum_size.y, MOUSE_CAP)
	cell.add_child(cap)
	_details.append(cap)
	# Every key's words stack on two lines, so no label wraps on its own and the row reads even.
	var words: String = record["words"]
	var gap := words.find(" ")
	var label := _text(words if gap < 0 else words.left(gap) + "\n" + words.substr(gap + 1), WORD_SIZE, Palette.SAND)
	# The words hold the type scale's smallest step; a word wider than its cell wraps, clipped at two lines.
	label.custom_minimum_size.y = UiFonts.bold().get_height(WORD_SIZE) * 2.0
	label.max_lines_visible = 2
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


# The preview ends on a flat rule in the plate's line colour (no gradients), so the words below sit
# on the card's own ground.
func _fade(width: float) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = UiTokens.LINE
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.position = Vector2(PAD, PAD + KEY_H + 8.0 + PREVIEW_H - UiTokens.EDGE)
	rule.size = Vector2(width - 2.0 * PAD, UiTokens.EDGE)
	return rule


# The key art's sky: two flat bands behind the sphere, a lit sky over a warm floor tinted by the
# pilot's colour. Flat fills only (no gradients); the opened card lifts the floor's tint.
func _backdrop(tint: Color) -> void:
	var top := PAD + KEY_H + 8.0
	var rect := Rect2(Vector2(PAD, top), Vector2(size.x - 2.0 * PAD, _preview_h))
	var sky := Palette.VERDIGRIS.lerp(Palette.SAND, 0.35)
	var warm := Palette.SANDSTONE.darkened(0.45).lerp(tint, 0.15 + 0.1 * openness)
	var mid := rect.size.y * 0.55
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, mid)), sky)
	draw_rect(Rect2(rect.position + Vector2(0.0, mid), Vector2(rect.size.x, rect.size.y - mid)), warm)


# Every state shares the card's serial, so the plate keeps its cuts, rivets and tape
# when it lights up.
func _frame(edge: Color, width: int, fill := true) -> StyleBox:
	return ScrapFrame.plate(edge, _serial, Color(Palette.CHARCOAL, 0.94 if fill else 0.0), width, 0.5)


# The tree pick's cards still draw this flat plate.
static func _plate(edge: Color, width: int, fill := true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = fill
	box.bg_color = Color(Palette.CHARCOAL, 0.94)
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(10)
	box.corner_detail = 3
	return box


# A label hugging its words on a stamped tag edged in the class colour.
func _tagged(label: Label, color: Color, serial: int) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.add_theme_stylebox_override("normal", ScrapFrame.tag(Color(color, 0.55), serial))
	return label


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
	_shake = maxf(0.0, _shake - delta)
	rotation = 0.0 if reduced_motion else sin(_shake * 70.0) * 0.035 * (_shake / SHAKE)
	openness = move_toward(openness, 1.0 if is_open() else 0.0, delta * RATE * (0.35 + openness))
	if _swatch != null:
		_swatch.mouse_filter = Control.MOUSE_FILTER_STOP if openness > 0.5 else Control.MOUSE_FILTER_IGNORE
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
