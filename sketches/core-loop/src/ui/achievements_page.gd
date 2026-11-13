extends VBoxContainer

const Secrets := preload("res://src/core/secrets.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const Palette := preload("res://src/core/palette.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")

# The title's list of every achievement, in table order (Achievements.ROWS): an amber
# star, the name and the date for an earned row; a slate ring, the name and the words
# to do for one not earned yet. A hidden row stays "???" and "Keep playing." until it is
# earned. A first-win secret row (secrets.gd PAINT_ROWS) is left out until it is earned, so a
# fresh profile sees no hint of it. A row with a count shows how far along it is, from Progress.count_of. Nothing
# is written twice: every word is a table row. Back presses A, as A opened it.
# Above the list stands the shift board (shift_board.gd): how many stamps, the next rung and what it
# opens, and the time card's holes, so the wall always names one thing to go and do next.

const COLUMNS := 2
const ROW_WIDTH := 600.0
const PLATE_PAD := 10.0
const HIDDEN_NAME := "???"
const HIDDEN_TEXT := "Keep playing."

var back: Button
var rows := {}

var _grid: GridContainer
var _plate: PanelContainer
var _scroll: ScrollContainer
var _board: VBoxContainer


func _init() -> void:
	name = "AchievementsPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board = VBoxContainer.new()
	_board.name = "ShiftBoard"
	_board.add_theme_constant_override("separation", 4)
	_board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	# The list stands on its own plate in the middle of the screen, as wide as its two columns, so
	# the camp behind does not read through the words and the scroll bar sits beside the list.
	_plate = PanelContainer.new()
	_plate.name = "Plate"
	_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(UiTokens.INK, UiTokens.PLATE_ALPHA)
	plate.border_color = UiTokens.LINE
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(UiTokens.RADIUS)
	plate.corner_detail = 1
	plate.set_content_margin_all(PLATE_PAD)
	_plate.add_theme_stylebox_override("panel", plate)
	add_child(_plate)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_plate.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_grid)
	back = ChoiceButton.new("back", "key_esc", "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(back)
	var bottom := Control.new()
	bottom.custom_minimum_size.y = 16.0
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)


# Rebuilds the list from the saved profile and the progress node's counters.
func refresh(profile, progress, sitting := false) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	rows.clear()
	_fill_board(profile, sitting)
	for id in Achievements.ids():
		if Secrets.shut_row(id, profile):
			continue
		var row := _row(id, profile, progress)
		_grid.add_child(row)
		rows[id] = row
	_focus_first.call_deferred()


# The board's three lines, for a test and for the strip: the stamp count, the next rung, the card.
static func board_lines(profile, sitting := false) -> PackedStringArray:
	var read := ShiftBoard.reading(profile, sitting)
	var out := PackedStringArray()
	out.append("SHIFT BOARD  %d of %d stamped" % [read["stamped"], read["shown"]])
	if read["next"] != "":
		out.append("Next is %s. %s %s." % [read["next_name"], read["next_text"], read["next_pays"]])
	else:
		out.append("Board full. Moss wants a bigger board.")
	var holes := "".join(range(int(read["holes_max"])).map(func(i): return "●" if i < int(read["holes"]) else "○"))
	if read["card_next"] != "":
		out.append("Time card %s  Full card opens %s" % [holes, read["card_next"]])
	else:
		out.append("Time card %s  Every card paid" % holes)
	return out


func _fill_board(profile, sitting: bool) -> void:
	for child in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	var lines := board_lines(profile, sitting)
	for i in lines.size():
		var label := _label(lines[i], 26 if i == 0 else 18, Palette.AMBER if i == 0 else Palette.SAND)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.name = ["Count", "Next", "Card"][i]
		_board.add_child(label)


func _focus_first() -> void:
	if is_visible_in_tree() and not rows.is_empty():
		rows.values()[0].grab_focus()


func _move(direction: int) -> void:
	var controls: Array = rows.values() + [back]
	var index := controls.find(get_viewport().gui_get_focus_owner())
	controls[0 if index < 0 else posmod(index + direction, controls.size())].grab_focus()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var direction := 0
	if event is InputEventKey and event.pressed:
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if code in [KEY_DOWN, KEY_S, KEY_RIGHT]:
			direction = 1
		elif code in [KEY_UP, KEY_W, KEY_LEFT]:
			direction = -1
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("ui_right", true):
		direction = 1
	elif event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_left", true):
		direction = -1
	if direction != 0:
		_move(direction)
		get_viewport().set_input_as_handled()
	elif back.has_focus() and event.is_action_pressed("ui_accept"):
		back.pressed.emit()
		get_viewport().set_input_as_handled()


# The words one row shows, for a test and for the row itself: name, text, and state.
static func reading(id: String, profile, progress) -> Dictionary:
	var data := Achievements.row(id)
	var earned: bool = profile != null and profile.earned(id)
	var hidden := bool(data.get("hidden", false)) and not earned
	var out := {"earned": earned, "name": HIDDEN_NAME if hidden else String(data["name"]),
		"text": HIDDEN_TEXT if hidden else String(data["text"]), "note": ""}
	if earned:
		var at: int = progress.earned_at(id) if progress != null else 0
		out["note"] = Time.get_date_string_from_unix_time(at) if at > 0 else "Earned"
	elif not hidden and int(data.get("count", 1)) > 1 and progress != null:
		out["note"] = "%d / %d" % [mini(int(progress.count_of(id)), int(data["count"])), int(data["count"])]
	return out


func _row(id: String, profile, progress) -> Control:
	var read := reading(id, profile, progress)
	var earned: bool = read["earned"]
	var box := HBoxContainer.new()
	box.name = id
	box.custom_minimum_size = Vector2(ROW_WIDTH, 0.0)
	box.focus_mode = Control.FOCUS_ALL
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color.TRANSPARENT
	outline.border_color = Palette.AMBER
	outline.set_border_width_all(2)
	box.draw.connect(func():
		if box.has_focus():
			box.draw_style_box(outline, Rect2(Vector2.ZERO, box.size)))
	box.focus_entered.connect(box.queue_redraw)
	box.focus_exited.connect(box.queue_redraw)
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_pad())
	var star := TextureRect.new()
	star.texture = Icons.shape("star" if earned else "ring")
	star.modulate = Palette.AMBER if earned else Color(Palette.SLATE, 0.8)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.custom_minimum_size = Vector2(30.0, 30.0)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(star)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(words)
	var shade := Palette.SAND if earned else Palette.SLATE
	words.add_child(_label(read["name"], UiTokens.LABEL, Palette.AMBER if earned else shade))
	# A long line wraps inside its row, so both columns keep one width and the list fits a 1280 window.
	var text := _label(read["text"], UiTokens.BODY, Color(shade, 0.9))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(text)
	if read["note"] != "":
		var note := _label(read["note"], UiTokens.BODY, Palette.AMBER if earned else Palette.SAND)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		note.name = "Note"
		box.add_child(note)
	box.add_child(_pad())
	return box


# An empty first and last child, so the row's 12 px separation stands between its focus outline
# and what the row holds.
func _pad() -> Control:
	var pad := Control.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pad


# Where the list's plate sits on screen, for the layout checks.
func list_rect() -> Rect2:
	return _plate.get_global_rect()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
