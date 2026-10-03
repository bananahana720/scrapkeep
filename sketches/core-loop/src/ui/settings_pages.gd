extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const Bindings := preload("res://src/core/bindings.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

# The settings page both hosts show: the pause menu in place of its first page, the title
# through its Settings button. Fullscreen and quality, then one rebind row per verb, then
# Reset keys, then the two fixed verbs and Back. A rebind row waits for the next key or
# mouse button (Esc cancels); a press another verb already holds is refused with "Taken".
# A new binding goes to the store and to the InputMap at once (game.apply_binding, the same
# call boot makes), so a later launch reads what play just used. The host feeds its input
# events to handle(); the page never reads the keyboard itself.

signal back_requested

# The seven verbs a player can rebind, in the order the rows read.
const VERBS := ["jump", "fire", "harpoon", "haul", "boost", "special", "interact"]
const FIXED := ["roll", "look"]
const WIDTH := 500.0
const WORD_BUDGET := 70
# Mouse buttons a press may bind: left, right, middle and the two side buttons. The wheel
# is not a button press a player means.
const MOUSE_OK := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]

var back: Button
var rows := {}

var _game
var _back_key := "key_esc"
var _order: Array = []
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
	for id in ["fullscreen", "quality"]:
		_add_plain(id)
	for verb in VERBS:
		_add_bind(verb)
	_add_plain("reset")
	for verb in FIXED:
		_add_fixed(verb)
	back = ChoiceButton.new("back", _back_key, "Back")
	_place(back, "back")
	back.pressed.connect(press.bind("back"))
	refresh()


func _store():
	return _game.settings_store()


func row(id: String) -> Control:
	return rows.get(id)


func capturing() -> bool:
	return _capturing != ""


func focused_id() -> String:
	for id in _order:
		if rows[id].has_focus():
			return id
	return ""


func focus(id: String) -> void:
	if rows.has(id) and is_visible_in_tree():
		rows[id].grab_focus()


# The action a verb's one row binds.
static func action_of(verb: String) -> String:
	return String(Bindings.VERBS[verb]["actions"].keys()[0])


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
	return Bindings.glyph(verb)


# Rereads every row's words from the store and the InputMap; clears a pending capture.
func refresh() -> void:
	_capturing = ""
	_taken = ""
	var store = _store()
	rows["fullscreen"].text = "Fullscreen: %s" % ("on" if store.fullscreen() else "off")
	rows["quality"].text = "Quality: %s" % ("Low" if store.quality() == 1 else "High")
	for verb in VERBS:
		_rebuild(verb)


func _add_plain(id: String) -> void:
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
	button.text = "Reset keys" if id == "reset" else id.capitalize()
	button.pressed.connect(press.bind(id))
	_place(button, id)


func _add_bind(verb: String) -> void:
	var button := _bind_button(verb)
	_place(button, verb)


func _bind_button(verb: String) -> Button:
	var button := ChoiceButton.new(verb, glyph_of(verb), verb.capitalize())
	button.pressed.connect(press.bind(verb))
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
	add_child(button)


func _place(node: Button, id: String) -> void:
	node.custom_minimum_size = Vector2(WIDTH, 40.0)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows[id] = node
	_order.append(id)
	add_child(node)


# A rebind row's cap is fixed when it is built, so a new key makes a new row in its place.
func _rebuild(verb: String) -> void:
	var old: Button = rows[verb]
	var had_focus := old.has_focus()
	var fresh := _bind_button(verb)
	fresh.custom_minimum_size = Vector2(WIDTH, 40.0)
	fresh.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(fresh)
	move_child(fresh, old.get_index())
	remove_child(old)
	old.queue_free()
	rows[verb] = fresh
	if had_focus:
		focus(verb)


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
		"reset":
			_game.reset_bindings()
			refresh()
		"back":
			back_requested.emit()
			return
		_:
			if id in VERBS:
				_capturing = id
				rows[id].text = "%s: press a key" % id.capitalize()
	focus(id)


func _clear_notice() -> void:
	if _taken != "":
		var verb := _taken
		_taken = ""
		rows[verb].text = verb.capitalize()


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
		elif code == KEY_ESCAPE:
			_clear_notice()
			back_requested.emit()
		elif code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
			_accept()
		return true
	if event is InputEventJoypadButton and event.pressed:
		if event.is_action_pressed("ui_up", true):
			_move(-1)
		elif event.is_action_pressed("ui_down", true):
			_move(1)
		elif event.is_action_pressed("ui_accept"):
			_accept()
		elif event.is_action_pressed("ui_cancel"):
			_clear_notice()
			back_requested.emit()
		return true
	return false


func _capture(event: InputEvent) -> bool:
	var verb := _capturing
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				_cancel()
			else:
				var key := InputEventKey.new()
				key.physical_keycode = event.physical_keycode
				_commit(verb, key)
		return true
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in MOUSE_OK:
			var click := InputEventMouseButton.new()
			click.button_index = event.button_index
			_commit(verb, click)
			return true
		return event.pressed
	if event is InputEventJoypadButton:
		if event.pressed and event.button_index == JOY_BUTTON_B:
			_cancel()
		return true
	return false


func _cancel() -> void:
	var verb := _capturing
	_capturing = ""
	rows[verb].text = verb.capitalize()


# True when another verb's action already holds this key or button in the InputMap.
func _held_elsewhere(verb: String, event: InputEvent) -> bool:
	for other in Bindings.VERBS:
		if other == verb:
			continue
		for action in Bindings.VERBS[other]["actions"]:
			for held in InputMap.action_get_events(action):
				if event is InputEventKey and held is InputEventKey and held.physical_keycode == event.physical_keycode:
					return true
				if event is InputEventMouseButton and held is InputEventMouseButton and held.button_index == event.button_index:
					return true
	return false


func _commit(verb: String, event: InputEvent) -> void:
	_capturing = ""
	if _held_elsewhere(verb, event):
		_taken = verb
		rows[verb].text = "%s: Taken" % verb.capitalize()
		return
	var action := action_of(verb)
	_store().set_binding(action, [event])
	_game.apply_binding(action, _store().binding_events(action))
	_rebuild(verb)


func _move(direction: int) -> void:
	_clear_notice()
	var index := _order.find(focused_id())
	index = 0 if index < 0 else posmod(index + direction, _order.size())
	rows[_order[index]].grab_focus()


func _accept() -> void:
	var id := focused_id()
	if id != "":
		press(id)
