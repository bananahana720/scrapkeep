extends VBoxContainer

const Secrets := preload("res://src/core/secrets.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const ShiftVariants := preload("res://src/core/shift_variants.gd")
const Palette := preload("res://src/core/palette.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Icons := preload("res://src/core/icons.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const Comfort := preload("res://src/core/comfort.gd")


const COLUMNS := 2
const ROW_WIDTH := 600.0
const VARIANT_WIDTH := 396.0
const PLATE_PAD := 10.0
const HIDDEN_NAME := "???"
const HIDDEN_TEXT := "Keep playing."
const BOARD_SERIAL := 49
const FLAP_SECONDS := 0.36
const FLAP_STAGGER := 0.08
const HIRED := "HIRED"
const TIMECARD := Vector2(76.0, 34.0)
const PUNCH := 3.0

signal work_orders_requested
signal logbook_requested

var back: Button
var orders_button: Button
var logbook_button: Button
var rows := {}
var variant_cards := {}
var world_act_cards := {}

var _grid: GridContainer
var _plate: PanelContainer
var _scroll: ScrollContainer
var _board: VBoxContainer
var _board_frame: PanelContainer
var _flaps: Tween


func _init() -> void:
	name = "AchievementsPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_frame = PanelContainer.new()
	_board_frame.name = "ShiftBoardFrame"
	_board_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cast = ScrapFrame.hand_plate(UiTokens.Hand.OLD_WORKS, BOARD_SERIAL)
	cast.content_margin_left = UiTokens.GAP_L
	cast.content_margin_right = UiTokens.GAP_L
	cast.content_margin_top = UiTokens.GAP_M
	cast.content_margin_bottom = UiTokens.GAP_XL
	_board_frame.add_theme_stylebox_override("panel", cast)
	add_child(_board_frame)
	_board = VBoxContainer.new()
	_board.name = "ShiftBoard"
	_board.add_theme_constant_override("separation", UiTokens.GAP_XS)
	_board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_frame.add_child(_board)
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
	var footer := HBoxContainer.new()
	footer.name = "FooterActions"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", UiTokens.GAP_M)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	orders_button = ChoiceButton.new("work_orders", "key_o", "Work orders")
	orders_button.focus_mode = Control.FOCUS_ALL
	orders_button.pressed.connect(func(): work_orders_requested.emit())
	footer.add_child(orders_button)
	logbook_button = ChoiceButton.new("logbook", "key_l", "Logbook")
	logbook_button.focus_mode = Control.FOCUS_ALL
	logbook_button.pressed.connect(func(): logbook_requested.emit())
	footer.add_child(logbook_button)
	back = ChoiceButton.new("back", "key_esc", "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	footer.add_child(back)
	var bottom := Control.new()
	bottom.custom_minimum_size.y = 16.0
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)


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
	_scroll.scroll_vertical = 0
	_focus_first.call_deferred()


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


static func variant_entries(profile, sitting := false) -> Array:
	return ShiftVariants.board_entries(profile, sitting)


func _fill_board(profile, sitting: bool) -> void:
	for child in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	variant_cards.clear()
	world_act_cards.clear()
	var lines := board_lines(profile, sitting)
	var flaps: Array[Label] = []
	for i in lines.size():
		var label: Label
		if i == 1:
			label = chalk(lines[i])
		else:
			label = flap(lines[i], UiTokens.LABEL if i == 0 else UiTokens.BODY)
			flaps.append(label)
		label.name = ["Count", "Next", "Card"][i]
		_board.add_child(label)
	_settle(flaps)
	_fill_world_acts(profile, sitting)
	var variants := variant_entries(profile, sitting)
	if variants.is_empty():
		return
	var strip := HBoxContainer.new()
	strip.name = "Variants"
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	strip.add_theme_constant_override("separation", UiTokens.GAP_M)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry in variants:
		var card := _variant_card(entry)
		strip.add_child(card)
		variant_cards[String(entry["id"])] = card
	_board.add_child(strip)


func _fill_world_acts(profile, sitting: bool) -> void:
	var acts_shown: Array = []
	for act in [2, 3]:
		var rungs := ShiftBoard.act_rungs(act, profile, sitting)
		if not rungs.is_empty():
			acts_shown.append([act, rungs])
	if acts_shown.is_empty():
		return
	var strip := HBoxContainer.new()
	strip.name = "WorldActs"
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	strip.add_theme_constant_override("separation", UiTokens.GAP_M)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry in acts_shown:
		var act: int = entry[0]
		var rungs: Array = entry[1]
		var stamped := 0
		var next_name := ""
		for raw_id in rungs:
			var rid := String(raw_id)
			if ShiftBoard.world_rung_stamped(rid, profile):
				stamped += 1
			elif next_name == "":
				var row: Dictionary = ShiftBoard.WORLD_RUNGS.get(rid, {})
				next_name = String(row.get("name", rid))
		var title := "Act II The Dig" if act == 2 else "Act III Highdraft"
		var summary := "%s   %d of %d stamped" % [title, stamped, rungs.size()]
		if next_name != "":
			summary += "   Next %s" % next_name
		var lbl := chalk(summary, UiTokens.CAPTION)
		lbl.name = "Act_%d" % act
		strip.add_child(lbl)
		world_act_cards[act] = lbl
	_board.add_child(strip)


static func flap(text: String, font_size: int) -> Label:
	var works: Dictionary = UiTokens.HANDS[UiTokens.Hand.OLD_WORKS]
	var label := _word(text, UiFonts.face(UiTokens.Hand.OLD_WORKS, true), font_size, works.ink)
	var cell := StyleBoxFlat.new()
	cell.bg_color = Color(works.fill.darkened(0.45), 1.0)
	cell.content_margin_left = UiTokens.GAP_S
	cell.content_margin_right = UiTokens.GAP_S
	cell.content_margin_top = UiTokens.GAP_XS
	cell.content_margin_bottom = UiTokens.GAP_XS
	label.add_theme_stylebox_override("normal", cell)
	label.draw.connect(_hinges.bind(label))
	return label


static func _hinges(label: Label) -> void:
	var works: Dictionary = UiTokens.HANDS[UiTokens.Hand.OLD_WORKS]
	var y := label.size.y * 0.5
	var reach := float(UiTokens.GAP_XS)
	label.draw_line(Vector2(0.0, y), Vector2(reach, y), works.edge, 2.0)
	label.draw_line(Vector2(label.size.x - reach, y), Vector2(label.size.x, y), works.edge, 2.0)


static func chalk(text: String, font_size := UiTokens.BODY) -> Label:
	return _word(text, UiFonts.face(UiTokens.Hand.KEEPER), font_size, UiTokens.HANDS[UiTokens.Hand.KEEPER].ink)


static func _word(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _settle(flaps: Array[Label]) -> void:
	if _flaps != null:
		_flaps.kill()
		_flaps = null
	if Comfort.reduced_motion or not is_inside_tree():
		for flap in flaps:
			flap.visible_ratio = 1.0
		return
	_flaps = create_tween().set_parallel(true).set_trans(UiTokens.hand(UiTokens.Hand.OLD_WORKS).trans)
	for i in flaps.size():
		flaps[i].visible_ratio = 0.0
		_flaps.tween_property(flaps[i], "visible_ratio", 1.0, FLAP_SECONDS).set_delay(FLAP_STAGGER * i)


static func hires(id: String) -> bool:
	for rung in ShiftBoard.RUNGS.values():
		if String(rung["stamp"]) == HIRED and String((rung["when"] as Dictionary).get("earned", "")) == id:
			return true
	return false


func _timecard() -> Control:
	var card := Control.new()
	card.name = "Timecard"
	card.custom_minimum_size = TIMECARD
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.draw.connect(func():
		var face := Rect2(Vector2.ZERO, card.size)
		card.draw_rect(face, Palette.LEDGER_CREAM)
		for i in 3:
			card.draw_circle(Vector2(card.size.x * (i + 1) / 4.0, UiTokens.GAP_XS + PUNCH), PUNCH, UiTokens.INK)
		var font := UiFonts.face(UiTokens.Hand.OLD_WORKS, true)
		var wide := font.get_string_size(HIRED, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.CAPTION).x
		card.draw_string(font, Vector2((card.size.x - wide) * 0.5, card.size.y - UiTokens.GAP_XS - font.get_descent(UiTokens.CAPTION)), HIRED,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.CAPTION, UiTokens.INK))
	return card


func _variant_card(entry: Dictionary) -> PanelContainer:
	var open := bool(entry["open"])
	var card := PanelContainer.new()
	card.name = String(entry["id"])
	card.custom_minimum_size = Vector2(VARIANT_WIDTH, 0.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTokens.INK, UiTokens.PLATE_ALPHA)
	style.border_color = UiTokens.ACCENT if open else UiTokens.LINE
	style.set_border_width_all(UiTokens.EDGE)
	style.set_corner_radius_all(UiTokens.RADIUS)
	style.corner_detail = 1
	style.content_margin_left = UiTokens.GAP_M
	style.content_margin_right = UiTokens.GAP_M
	style.content_margin_top = UiTokens.GAP_S
	style.content_margin_bottom = UiTokens.GAP_S
	card.add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", UiTokens.GAP_XS)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTokens.GAP_S)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(head)
	var mark := TextureRect.new()
	mark.texture = Icons.shape("star" if open else "ring")
	mark.modulate = UiTokens.ACCENT if open else UiTokens.quiet(UiTokens.TEXT)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(UiTokens.BODY, UiTokens.BODY)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(mark)
	var rung := _label(String(entry["rung_name"]), UiTokens.BODY, UiTokens.ACCENT if open else UiTokens.TEXT)
	rung.name = "Rung"
	head.add_child(rung)
	var text := _label(String(entry["text"]), UiTokens.CAPTION, UiTokens.TEXT if open else UiTokens.quiet(UiTokens.TEXT))
	text.name = "Text"
	text.custom_minimum_size = Vector2(VARIANT_WIDTH - 2.0 * (UiTokens.GAP_M + UiTokens.EDGE), 0.0)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text)
	return card


func _focus_first() -> void:
	if is_visible_in_tree() and not rows.is_empty():
		rows.values()[0].grab_focus()
		_scroll.scroll_vertical = 0
		_scroll.set_deferred("scroll_vertical", 0)


func _move(direction: int) -> void:
	var controls: Array = rows.values() + [back]
	var index := controls.find(get_viewport().gui_get_focus_owner())
	controls[0 if index < 0 else posmod(index + direction, controls.size())].grab_focus()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var footer_buttons: Array = [orders_button, logbook_button, back]
	var held := get_viewport().gui_get_focus_owner()
	var foot_idx := footer_buttons.find(held)
	var direction := 0
	var horiz := 0
	if event is InputEventKey and event.pressed:
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if not event.echo and code == KEY_O:
			work_orders_requested.emit()
			get_viewport().set_input_as_handled()
			return
		if not event.echo and code == KEY_L:
			logbook_requested.emit()
			get_viewport().set_input_as_handled()
			return
		if code in [KEY_DOWN, KEY_S]:
			direction = 1
		elif code in [KEY_UP, KEY_W]:
			direction = -1
		elif code == KEY_RIGHT:
			horiz = 1
		elif code == KEY_LEFT:
			horiz = -1
	elif event.is_action_pressed("ui_down", true):
		direction = 1
	elif event.is_action_pressed("ui_up", true):
		direction = -1
	elif event.is_action_pressed("ui_right", true):
		horiz = 1
	elif event.is_action_pressed("ui_left", true):
		horiz = -1
	if horiz != 0:
		if foot_idx >= 0:
			footer_buttons[posmod(foot_idx + horiz, footer_buttons.size())].grab_focus()
		else:
			_move(horiz)
		get_viewport().set_input_as_handled()
	elif direction != 0:
		if foot_idx >= 0:
			var controls: Array = rows.values() + [back]
			controls[0 if direction > 0 else controls.size() - 2].grab_focus()
		else:
			_move(direction)
		get_viewport().set_input_as_handled()
	elif foot_idx >= 0 and event.is_action_pressed("ui_accept"):
		footer_buttons[foot_idx].pressed.emit()
		get_viewport().set_input_as_handled()


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
	var text := _label(read["text"], UiTokens.BODY, Color(shade, 0.9))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(text)
	if earned and hires(id):
		box.add_child(_timecard())
	if read["note"] != "":
		var note := _label(read["note"], UiTokens.BODY, Palette.AMBER if earned else Palette.SAND)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		note.name = "Note"
		box.add_child(note)
	box.add_child(_pad())
	return box


func _pad() -> Control:
	var pad := Control.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pad


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
