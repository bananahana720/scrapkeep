extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const Bindings := preload("res://src/core/bindings.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")

# The settings page both hosts show: the pause menu in place of its first page, the title
# through its Settings button. Three pages behind a tab strip, switched by LB and RB, Q and E
# or a click, the last one kept for the session: Display (fullscreen, quality, reduced motion,
# reduce flashes), Controls (a key row and a pad row per verb, Reset keys, the two fixed
# verbs) and Look (stick speed, invert Y, dead zone, mouse speed, aim assist, each stepped by
# Enter, A or a click and by left and right). Back sits under every page. A key row waits for the next key or mouse
# button, a pad row for the next pad button (and a trigger for fire and harpoon); Esc or B
# cancels; a press another verb already holds is refused with "Taken".
# A new binding goes to the store and to the InputMap at once (game.apply_binding, the same
# call boot makes), so a later launch reads what play just used. The host feeds its input
# events to handle(); the page never reads the keyboard itself.

signal back_requested

# The rows a player can rebind, in the order they read: one per verb, and the pick's three keys
# a row each (select_1 to select_3, design-v3/SKILL-BAR.md section 6). The F special retired.
const VERBS := ["jump", "fire", "harpoon", "haul", "boost", "select_1", "select_2", "select_3", "ultimate", "interact"]
const SELECT_ROW := "select_"
const FIXED := ["roll", "look"]
const PAGES := ["display", "controls", "look"]
const PAGE_WORDS := {"display": "Display", "controls": "Controls", "look": "Look"}
# The verbs a trigger can fire, and how far a trigger is pulled before it counts as a press.
const TRIGGER_VERBS := ["fire", "harpoon"]
const TRIGGER_PULL := 0.6
# Stick clicks are bindable on top of the glyphed buttons; the table has no pad glyph for
# them, so the row draws a plain L3 or R3 cap. The d-pad has its own glyphs (Glyphs.PAD_BUTTONS).
const PAD_EXTRA := {JOY_BUTTON_LEFT_STICK: "key_l3", JOY_BUTTON_RIGHT_STICK: "key_r3"}
# The look rows: the setting each steps, its words, its values low to high, and what a shown
# percent is measured against (0 shows on/off).
const LOOK := [
	{"id": SettingsStore.STICK_SENSITIVITY, "words": "Stick speed", "steps": [1.3, 1.95, 2.6, 3.25, 3.9], "per": 2.6},
	{"id": SettingsStore.INVERT_Y, "words": "Invert Y", "steps": [0.0, 1.0], "per": 0.0},
	{"id": SettingsStore.STICK_DEADZONE, "words": "Dead zone", "steps": [0.1, 0.15, 0.2, 0.25, 0.3], "per": 1.0},
	{"id": SettingsStore.MOUSE_SENSITIVITY, "words": "Mouse speed", "steps": [0.0011, 0.00165, 0.0022, 0.00275, 0.0033], "per": 0.0022},
	{"id": SettingsStore.AIM_ASSIST, "words": "Aim assist", "steps": [0.0, 0.25, 0.5, 0.75, 1.0], "per": 1.0},
]
const WIDTH := 500.0
const HALF := 248.0
const WORD_BUDGET := 70
# Mouse buttons a press may bind: left, right, middle and the two side buttons. The wheel
# is not a button press a player means.
const MOUSE_OK := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]

# The page the last settings page showed, kept for the session across both hosts.
static var last_page := 0

var back: Button
var rows := {}

var _game
var _back_key := "key_esc"
var _order: Array = []
var _page_ids := {}
var _boxes := {}
var _tabs := {}
var _page_index := 0
var _capturing := ""
var _taken := ""


func _init() -> void:
	name = "SettingsPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(game_ref, back_key := "key_esc") -> void:
	_game = game_ref
	_back_key = back_key
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 4)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	for i in PAGES.size():
		var tab := _tab_button(PAGES[i])
		tab.pressed.connect(_tab_pressed.bind(i))
		strip.add_child(tab)
		_tabs[PAGES[i]] = tab
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		_boxes[PAGES[i]] = box
		_page_ids[PAGES[i]] = []
	_build_display()
	_build_controls()
	_build_look()
	back = ChoiceButton.new("back", _back_key, "Back")
	back.custom_minimum_size = Vector2(WIDTH, 40.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows["back"] = back
	add_child(back)
	back.pressed.connect(press.bind("back"))
	refresh()


func _build_display() -> void:
	for id in ["fullscreen", "quality", "reduced_motion", "reduce_flashes"]:
		_add_plain(id, "display")


func _build_controls() -> void:
	for verb in VERBS:
		var pair := HBoxContainer.new()
		pair.alignment = BoxContainer.ALIGNMENT_CENTER
		pair.add_theme_constant_override("separation", 4)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boxes["controls"].add_child(pair)
		for id in [verb, "pad_" + verb]:
			var button := _bind_button(id)
			button.custom_minimum_size = Vector2(HALF, 40.0)
			rows[id] = button
			_page_ids["controls"].append(id)
			pair.add_child(button)
	_add_plain("reset", "controls")
	for verb in FIXED:
		_add_fixed(verb)


func _build_look() -> void:
	for spec in LOOK:
		_add_plain(String(spec["id"]), "look")


func _tab_button(page: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.text = PAGE_WORDS[page]
	button.add_theme_font_override("font", UiFonts.bold())
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", ChoiceButton.plate(Palette.VERDIGRIS, 2, ChoiceButton.PAD))
	button.add_theme_stylebox_override("hover", ChoiceButton.plate(Palette.SAND, 2, ChoiceButton.PAD))
	button.add_theme_stylebox_override("pressed", ChoiceButton.plate(Palette.AMBER, 3, ChoiceButton.PAD))
	button.custom_minimum_size = Vector2(WIDTH / 3.0 - 3.0, 36.0)
	return button


func _store():
	return _game.settings_store()


func row(id: String) -> Control:
	return rows.get(id)


func capturing() -> bool:
	return _capturing != ""


func current_page() -> String:
	return PAGES[_page_index]


# The ids the d-pad walks on the shown page, Back last.
func page_ids() -> Array:
	return _order.duplicate()


# Shows a page by index (wrapping) and keeps it for the session; a pending capture ends.
func show_page(index: int) -> void:
	_clear_notice()
	_capture_end()
	_page_index = posmod(index, PAGES.size())
	last_page = _page_index
	for i in PAGES.size():
		var id: String = PAGES[i]
		_boxes[id].visible = i == _page_index
		var tab: Button = _tabs[id]
		var tint := Palette.AMBER if i == _page_index else Palette.SAND
		tab.add_theme_color_override("font_color", tint)
		tab.add_theme_color_override("font_hover_color", Color.WHITE)
	_order = _page_ids[PAGES[_page_index]].duplicate()
	_order.append("back")


func focused_id() -> String:
	for id in _order:
		if rows[id].has_focus():
			return id
	return ""


# Focuses a row; a row on a page that is not shown sends focus to the shown page's first row.
func focus(id: String) -> void:
	if not is_visible_in_tree():
		return
	if not id in _order:
		id = _order[0]
	rows[id].grab_focus()


func focus_first() -> void:
	focus(_order[0])


func _tab_pressed(index: int) -> void:
	show_page(index)
	focus_first()


# The action a row binds: a verb's one action, or the pick key a select row names.
static func action_of(row: String) -> String:
	var bare := row_of(row)
	var n := _select_number(bare)
	if n > 0:
		return String(Bindings.SELECT_ACTIONS[n - 1])
	return String(Bindings.VERBS[bare]["actions"].keys()[0])


# The row a key row or a pad row ("pad_jump", "pad_select_2") stands for.
static func row_of(id: String) -> String:
	return id.trim_prefix("pad_")


# The bindings verb a row binds: select for the three pick rows.
static func verb_of(id: String) -> String:
	var bare := row_of(id)
	return "select" if _select_number(bare) > 0 else bare


# 1 to 3 for a select row, else 0.
static func _select_number(row: String) -> int:
	if not row.begins_with(SELECT_ROW):
		return 0
	var n := row.substr(SELECT_ROW.length()).to_int()
	return n if n >= 1 and n <= Bindings.SELECT_ACTIONS.size() else 0


# The cap a pad button draws on a row, or "" for a button no row binds.
static func pad_cap(button: int) -> String:
	return String(Glyphs.PAD_BUTTONS.get(button, PAD_EXTRA.get(button, "")))


# The glyph id of the key or button the verb's action holds in the InputMap right now.
func glyph_of(verb: String) -> String:
	for event in InputMap.action_get_events(action_of(verb)):
		if event is InputEventKey:
			return "key_" + OS.get_keycode_string(event.physical_keycode).to_lower().replace(" ", "")
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					return "key_lmb"
				MOUSE_BUTTON_RIGHT:
					return "key_rmb"
			return "key_m%d" % event.button_index
	var n := _select_number(row_of(verb))
	return "key_%d" % n if n > 0 else Bindings.glyph(verb_of(verb))


# The pad glyph id of the verb's pad row: the pad button or trigger the player saved last,
# else the table's default.
func pad_glyph_of(verb: String) -> String:
	var saved := []
	for event in _store().binding_events(action_of(verb)):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			saved.append(event)
	if not saved.is_empty():
		var last: InputEvent = saved[-1]
		if last is InputEventJoypadButton:
			return pad_cap(last.button_index) if pad_cap(last.button_index) != "" else "pad_a"
		return String(Glyphs.PAD_TRIGGERS.get(last.axis, "pad_rt"))
	var record: Dictionary = Bindings.VERBS[verb_of(verb)]["actions"][action_of(verb)]
	if record.has("pad"):
		return String(Glyphs.PAD_BUTTONS.get(record["pad"], "pad_a"))
	if record.has("axis"):
		return String(Glyphs.PAD_TRIGGERS.get(record["axis"][0], "pad_rt"))
	return "pad_a"


# Rereads every row's words from the store and the InputMap; clears a pending capture and
# shows the page the session last used.
func refresh() -> void:
	_capturing = ""
	_taken = ""
	var store = _store()
	rows["fullscreen"].text = "Fullscreen: %s" % ("on" if store.fullscreen() else "off")
	rows["quality"].text = "Quality: %s" % ("Low" if store.quality() == 1 else "High")
	rows["reduced_motion"].text = "Reduced motion: %s" % ("on" if store.reduced_motion() else "off")
	rows["reduce_flashes"].text = "Reduce flashes: %s" % ("on" if store.reduce_flashes() else "off")
	for verb in VERBS:
		_rebuild(verb)
		_rebuild("pad_" + verb)
	for spec in LOOK:
		_show_look(spec)
	show_page(last_page)


func _add_plain(id: String, page: String) -> void:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", UiFonts.bold())
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Palette.SAND)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Palette.AMBER)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	var left := ChoiceButton.PAD * 1.5
	button.add_theme_stylebox_override("normal", ChoiceButton.plate(Palette.VERDIGRIS, 2, left))
	button.add_theme_stylebox_override("hover", ChoiceButton.plate(Palette.SAND, 2, left))
	button.add_theme_stylebox_override("pressed", ChoiceButton.plate(Palette.AMBER, 3, left))
	button.add_theme_stylebox_override("focus", ChoiceButton.plate(Palette.SAND, 4, left, false))
	button.custom_minimum_size = Vector2(WIDTH, 40.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.text = "Reset keys" if id == "reset" else id.capitalize()
	button.pressed.connect(press.bind(id))
	rows[id] = button
	_page_ids[page].append(id)
	_boxes[page].add_child(button)


# A key row or a pad row; the pad row's glyph is a pad button or trigger.
func _bind_button(id: String) -> Button:
	var row := row_of(id)
	var glyph := pad_glyph_of(row) if id.begins_with("pad_") else glyph_of(row)
	var button := ChoiceButton.new(id, glyph, _caption(id))
	button.pressed.connect(press.bind(id))
	return button


# A fixed verb shows its keys and takes no input.
func _add_fixed(verb: String) -> void:
	var button := ChoiceButton.new(verb, Bindings.glyph(verb), "%s: %s" % [verb.capitalize(), Bindings.label(verb)])
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows[verb] = button
	button.custom_minimum_size = Vector2(WIDTH, 40.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boxes["controls"].add_child(button)


# A bind row's cap is fixed when it is built, so a new key makes a new row in its place.
func _rebuild(id: String) -> void:
	var old: Button = rows[id]
	var had_focus := old.has_focus()
	var parent := old.get_parent()
	var fresh := _bind_button(id)
	fresh.custom_minimum_size = Vector2(HALF, 40.0)
	parent.add_child(fresh)
	parent.move_child(fresh, old.get_index())
	parent.remove_child(old)
	old.queue_free()
	rows[id] = fresh
	if had_focus:
		focus(id)


func _look_spec(id: String) -> Dictionary:
	for spec in LOOK:
		if spec["id"] == id:
			return spec
	return {}


func _show_look(spec: Dictionary) -> void:
	var value := float(_store().look.get(spec["id"], SettingsStore.LOOK_DEFAULTS[spec["id"]]))
	var shown := ""
	if float(spec["per"]) <= 0.0:
		shown = "on" if value >= 0.5 else "off"
	else:
		shown = "%d%%" % roundi(value / float(spec["per"]) * 100.0)
	rows[spec["id"]].text = "%s: %s" % [spec["words"], shown]


# Moves a look row to the next listed value near its current one: wrapping for a press,
# stopping at the ends for left and right.
func _step_look(id: String, direction: int, wrap: bool) -> void:
	var spec := _look_spec(id)
	var steps: Array = spec["steps"]
	var value := float(_store().look.get(id, SettingsStore.LOOK_DEFAULTS[id]))
	var at := 0
	for i in steps.size():
		if absf(float(steps[i]) - value) < absf(float(steps[at]) - value):
			at = i
	at = posmod(at + direction, steps.size()) if wrap else clampi(at + direction, 0, steps.size() - 1)
	_store().set_look(id, float(steps[at]))
	_game.apply_look()
	_show_look(spec)


func press(id: String) -> void:
	_clear_notice()
	if _capturing != "":
		return
	match id:
		"fullscreen":
			var on: bool = not _store().fullscreen()
			_store().set_comfort(SettingsStore.FULLSCREEN, 1.0 if on else 0.0)
			_game.set_fullscreen(on)
			rows["fullscreen"].text = "Fullscreen: %s" % ("on" if on else "off")
		"quality":
			var level: int = 1 - _store().quality()
			_store().set_comfort(SettingsStore.QUALITY, float(level))
			_game.set_quality(level)
			rows["quality"].text = "Quality: %s" % ("Low" if level == 1 else "High")
		"reduced_motion":
			var calm: bool = not _store().reduced_motion()
			_store().set_comfort(SettingsStore.REDUCED_MOTION, 1.0 if calm else 0.0)
			_game.set_reduced_motion(calm)
			rows["reduced_motion"].text = "Reduced motion: %s" % ("on" if calm else "off")
		"reduce_flashes":
			var dim: bool = not _store().reduce_flashes()
			_store().set_comfort(SettingsStore.REDUCE_FLASHES, 1.0 if dim else 0.0)
			_game.set_reduce_flashes(dim)
			rows["reduce_flashes"].text = "Reduce flashes: %s" % ("on" if dim else "off")
		"reset":
			_game.reset_bindings()
			refresh()
		"back":
			back_requested.emit()
			return
		_:
			if not _look_spec(id).is_empty():
				_step_look(id, 1, true)
			elif row_of(id) in VERBS:
				_capturing = id
				rows[id].text = "%s: press" % _caption(id)
	focus(id)


# A row's words: the verb, or "Slot 2" for a pick row.
func _caption(id: String) -> String:
	var n := _select_number(row_of(id))
	return "Slot %d" % n if n > 0 else verb_of(id).capitalize()


func _clear_notice() -> void:
	if _taken != "":
		var id := _taken
		_taken = ""
		rows[id].text = _caption(id)


func _capture_end() -> void:
	if _capturing != "":
		rows[_capturing].text = _caption(_capturing)
		_capturing = ""


# Takes one input event from the host. True when the page used it; every key and pad
# button press counts, so nothing under the page hears it.
func handle(event: InputEvent) -> bool:
	if _capturing != "":
		return _capture(event)
	if event is InputEventKey:
		if not event.pressed:
			return false
		var code: int = event.physical_keycode
		if code == KEY_W or code == KEY_UP:
			_move(-1)
		elif code == KEY_S or code == KEY_DOWN:
			_move(1)
		elif event.echo:
			pass
		elif code == KEY_Q:
			_tab_pressed(_page_index - 1)
		elif code == KEY_E:
			_tab_pressed(_page_index + 1)
		elif code == KEY_A or code == KEY_LEFT:
			_nudge(-1)
		elif code == KEY_D or code == KEY_RIGHT:
			_nudge(1)
		elif code == KEY_ESCAPE:
			_clear_notice()
			back_requested.emit()
		elif code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
			_accept()
		return true
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_tab_pressed(_page_index - 1)
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_tab_pressed(_page_index + 1)
		elif event.is_action_pressed("ui_up", true):
			_move(-1)
		elif event.is_action_pressed("ui_down", true):
			_move(1)
		elif event.is_action_pressed("ui_left"):
			_nudge(-1)
		elif event.is_action_pressed("ui_right"):
			_nudge(1)
		elif event.is_action_pressed("ui_accept"):
			_accept()
		elif event.is_action_pressed("ui_cancel"):
			_clear_notice()
			back_requested.emit()
		return true
	return false


func _capture(event: InputEvent) -> bool:
	var id := _capturing
	var pad_row := id.begins_with("pad_")
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				_cancel()
			elif not pad_row:
				var key := InputEventKey.new()
				key.physical_keycode = event.physical_keycode
				_commit(id, key)
		return true
	if event is InputEventMouseButton:
		if event.pressed and not pad_row and event.button_index in MOUSE_OK:
			var click := InputEventMouseButton.new()
			click.button_index = event.button_index
			_commit(id, click)
			return true
		return event.pressed
	if event is InputEventJoypadButton:
		if event.pressed:
			if event.button_index == JOY_BUTTON_B:
				_cancel()
			elif pad_row and pad_cap(event.button_index) != "":
				var pad := InputEventJoypadButton.new()
				pad.button_index = event.button_index
				_commit(id, pad)
		return true
	if event is InputEventJoypadMotion:
		if pad_row and verb_of(id) in TRIGGER_VERBS and event.axis in Bindings.TRIGGER_AXES and event.axis_value >= TRIGGER_PULL:
			var trigger := InputEventJoypadMotion.new()
			trigger.axis = event.axis
			trigger.axis_value = 1.0
			_commit(id, trigger)
			return true
	return false


func _cancel() -> void:
	_capture_end()


# True when an action other than this verb's already holds this key or button in the
# InputMap, the pause and retry actions included. A trigger is never Taken: fire and harpoon
# swap triggers instead (_commit_trigger).
func _held_elsewhere(row: String, event: InputEvent) -> bool:
	var own := action_of(row)
	for action in Bindings.actions():
		if action == own:
			continue
		for held in InputMap.action_get_events(action):
			if event is InputEventKey and held is InputEventKey and held.physical_keycode == event.physical_keycode:
				return true
			if event is InputEventMouseButton and held is InputEventMouseButton and held.button_index == event.button_index:
				return true
			if event is InputEventJoypadButton and held is InputEventJoypadButton and held.button_index == event.button_index:
				return true
	return false


func _commit(id: String, event: InputEvent) -> void:
	_capturing = ""
	var verb := verb_of(id)
	if _held_elsewhere(row_of(id), event):
		_taken = id
		rows[id].text = "%s: Taken" % _caption(id)
		return
	var action := action_of(row_of(id))
	if event is InputEventJoypadMotion:
		_hand_over_trigger(verb, event.axis)
	_store().merge_binding(action, [event])
	_game.apply_binding(action, _store().binding_events(action))
	_rebuild(id)


# The trigger axis an action holds in the InputMap, or -1.
func _trigger_axis(action: String) -> int:
	for held in InputMap.action_get_events(action):
		if held is InputEventJoypadMotion and held.axis in Bindings.TRIGGER_AXES:
			return held.axis
	return -1


# Fire and harpoon share two triggers: when `verb` takes the trigger the other holds, the
# other gets the one `verb` leaves.
func _hand_over_trigger(verb: String, axis: int) -> void:
	var leaving := _trigger_axis(action_of(verb))
	for other in TRIGGER_VERBS:
		var other_action := action_of(other)
		if other == verb or leaving == -1 or _trigger_axis(other_action) != axis:
			continue
		var moved := InputEventJoypadMotion.new()
		moved.axis = leaving
		moved.axis_value = 1.0
		_store().merge_binding(other_action, [moved])
		_game.apply_binding(other_action, [moved])
		_rebuild("pad_" + other)


func _move(direction: int) -> void:
	_clear_notice()
	var index := _order.find(focused_id())
	index = 0 if index < 0 else posmod(index + direction, _order.size())
	rows[_order[index]].grab_focus()


# Left and right step the focused look row down and up, stopping at the ends.
func _nudge(direction: int) -> void:
	_clear_notice()
	var id := focused_id()
	if not _look_spec(id).is_empty():
		_step_look(id, direction, false)


func _accept() -> void:
	var id := focused_id()
	if id != "":
		press(id)
