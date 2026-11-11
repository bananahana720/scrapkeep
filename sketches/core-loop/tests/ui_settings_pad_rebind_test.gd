extends SceneTree

const Game := preload("res://src/game.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Intent := preload("res://src/movement/intent.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const T := preload("res://tests/support/t.gd")

# IN3: pad rebinding on the settings page's Controls page. A pad row waits for a pad button
# (B cancels) and, for fire and harpoon, a trigger; the button commits as a pad:<n> token
# through the store and apply_binding; a button another verb holds reads Taken; the row
# shows the pad cap. A key row ignores the pad. Fire and harpoon swap triggers.

var _t := T.new("ui_settings_pad_rebind_test")
var _game
var _page


func _initialize() -> void:
	var dir := "user://test-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	var file := dir.path_join(SettingsStore.FILE)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _saved() -> SettingsStore:
	return SettingsStore.new(_game.storage_dir)


func _button(button: int) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event)


func _pull(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	root.push_input(event)


func _pads(action: String) -> Array:
	var out := []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			out.append(event.button_index)
	out.sort()
	return out


func _triggers(action: String) -> Array:
	var out := []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			out.append(event.axis)
	out.sort()
	return out


func _has_key(action: String, code: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == code:
			return true
	return false


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game._screen_key(KEY_S)
	_page = _game.screens.settings_page()
	_page.show_page(1)
	_t.check("the settings page is open on Controls", _game.screens.settings_open() and _page.current_page() == "controls", "page %s" % _page.current_page())

	_t.eq("start: jump holds pad A", _pads("cl_jump"), [JOY_BUTTON_A])
	_t.eq("start: the jump pad row shows A", _page.row("pad_jump").key, "pad_a")
	_t.eq("start: the fire pad row shows RT", _page.row("pad_fire").key, "pad_rt")
	_t.eq("start: the harpoon pad row shows LT", _page.row("pad_harpoon").key, "pad_lt")

	# A free button commits as pad:<n>.
	_page.press("pad_jump")
	_t.check("a pad row waits for a button", _page.capturing(), "capturing")
	_button(JOY_BUTTON_LEFT_STICK)
	_t.eq("L3 commits as pad:7 in the file", _saved().binding("cl_jump"), "pad:%d" % JOY_BUTTON_LEFT_STICK)
	_t.eq("L3 is on cl_jump at once and A is not", _pads("cl_jump"), [JOY_BUTTON_LEFT_STICK])
	_t.check("the row shows the new cap", _page.row("pad_jump").key == "key_l3" and not _page.capturing(), "key %s" % _page.row("pad_jump").key)
	_t.check("the key row still holds Space", _has_key("cl_jump", KEY_SPACE), "events")
	_t.eq("the run did not start under the page", _game.flow.state_name(), "title")

	# B cancels.
	_page.press("pad_haul")
	_button(JOY_BUTTON_B)
	_t.check("B cancels and changes nothing", not _page.capturing() and _pads("cl_haul") == [JOY_BUTTON_X] and _saved().binding("cl_haul") == "" and _page.row("pad_haul").text == "", "pads %s text %s" % [_pads("cl_haul"), _page.row("pad_haul").text])

	# Taken against held pad buttons.
	_page.press("pad_boost")
	_button(JOY_BUTTON_X)
	_t.check("a button another verb holds reads Taken", _page.row("pad_boost").text.contains("Taken") and _pads("cl_boost") == [JOY_BUTTON_B] and _saved().binding("cl_boost") == "", "text %s" % _page.row("pad_boost").text)
	_page.press("pad_boost")
	_button(JOY_BUTTON_START)
	_t.check("the pause button is Taken too", _page.row("pad_boost").text.contains("Taken") and _pads("cl_boost") == [JOY_BUTTON_B], "text %s" % _page.row("pad_boost").text)
	_page.press("pad_boost")
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	_t.check("the retry button is Taken too", _page.row("pad_boost").text.contains("Taken"), "text %s" % _page.row("pad_boost").text)

	# The freed A can be taken.
	_page.press("pad_boost")
	_button(JOY_BUTTON_A)
	_t.check("the button jump left is free", _pads("cl_boost") == [JOY_BUTTON_A] and _saved().binding("cl_boost") == "pad:%d" % JOY_BUTTON_A and _page.row("pad_boost").key == "pad_a", "pads %s" % [_pads("cl_boost")])
	_t.eq("the run still did not start", _game.flow.state_name(), "title")

	# A key row ignores the pad; a pad row ignores keys.
	_page.press("haul")
	_button(JOY_BUTTON_RIGHT_STICK)
	_t.check("a key row ignores a pad button", _page.capturing() and _pads("cl_haul") == [JOY_BUTTON_X], "capturing %s" % _page.capturing())
	_button(JOY_BUTTON_B)
	_t.check("B cancels a key row too", not _page.capturing(), "capturing")
	_page.press("pad_haul")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_G
	key.pressed = true
	_page.handle(key)
	_t.check("a pad row ignores a key", _page.capturing() and not _has_key("cl_haul", KEY_G), "capturing %s" % _page.capturing())
	_button(JOY_BUTTON_B)

	# A key rebind keeps the saved pad rebind, and the file reads back whole.
	_page.press("jump")
	_page.handle(key)
	var saved := _saved()
	_t.check("a key rebind keeps the pad token", saved.binding("cl_jump").contains("pad:7") and saved.binding("cl_jump").contains("key:G"), "saved %s" % saved.binding("cl_jump"))
	_t.check("the file decodes to both", saved.binding_events("cl_jump").size() == 2, "events %d" % saved.binding_events("cl_jump").size())

	# Triggers: fire and harpoon only, a real pull only.
	_page.press("pad_jump")
	_pull(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_t.check("a trigger does not bind jump", _page.capturing() and _triggers("cl_jump") == [], "triggers %s" % [_triggers("cl_jump")])
	_button(JOY_BUTTON_B)
	_page.press("pad_fire")
	_pull(JOY_AXIS_TRIGGER_LEFT, 0.3)
	_pull(JOY_AXIS_RIGHT_X, 1.0)
	_t.check("a light pull and a stick are ignored", _page.capturing(), "capturing")
	_pull(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_t.check("LT binds fire", _triggers("cl_fire") == [JOY_AXIS_TRIGGER_LEFT] and _saved().binding("cl_fire") == "axis:%d" % JOY_AXIS_TRIGGER_LEFT and not _page.capturing(), "triggers %s saved %s" % [_triggers("cl_fire"), _saved().binding("cl_fire")])
	_t.check("harpoon takes the trigger fire left", _triggers("cl_harpoon") == [JOY_AXIS_TRIGGER_RIGHT] and _saved().binding("cl_harpoon") == "axis:%d" % JOY_AXIS_TRIGGER_RIGHT, "triggers %s" % [_triggers("cl_harpoon")])
	_t.check("the rows show LT on fire and RT on harpoon", _page.row("pad_fire").key == "pad_lt" and _page.row("pad_harpoon").key == "pad_rt", "%s %s" % [_page.row("pad_fire").key, _page.row("pad_harpoon").key])
	_t.check("the mouse button on fire stays", _has_mouse("cl_fire", MOUSE_BUTTON_LEFT), "events")
	_page.press("pad_fire")
	_button(JOY_BUTTON_RIGHT_STICK)
	_t.check("a button on fire adds beside the trigger", _pads("cl_fire") == [JOY_BUTTON_RIGHT_STICK] and _triggers("cl_fire") == [JOY_AXIS_TRIGGER_LEFT] and _page.row("pad_fire").key == "key_r3", "pads %s key %s" % [_pads("cl_fire"), _page.row("pad_fire").key])

	# Tokens round trip.
	var text := Bindings.encode([_pad(JOY_BUTTON_Y), _trigger(JOY_AXIS_TRIGGER_RIGHT)])
	_t.eq("encode writes pad and axis tokens", text, "pad:%d,axis:%d" % [JOY_BUTTON_Y, JOY_AXIS_TRIGGER_RIGHT])
	var back := Bindings.decode(text + ",axis:0")
	_t.check("decode reads them and refuses a stick axis", back.size() == 2 and back[0] is InputEventJoypadButton and back[1] is InputEventJoypadMotion, "decoded %d" % back.size())

	# Reset keys restores every default, triggers included.
	_page.press("reset")
	_t.check("Reset keys restores the pad defaults", _pads("cl_jump") == [JOY_BUTTON_A] and _pads("cl_boost") == [JOY_BUTTON_B] and _triggers("cl_fire") == [JOY_AXIS_TRIGGER_RIGHT] and _triggers("cl_harpoon") == [JOY_AXIS_TRIGGER_LEFT] and _saved().bindings.is_empty(), "bindings %s" % [_saved().bindings])
	_t.check("the rows show the defaults again", _page.row("pad_jump").key == "pad_a" and _page.row("pad_fire").key == "pad_rt", "%s" % _page.row("pad_jump").key)

	_game.queue_free()
	await process_frame
	quit(_t.verdict())


func _pad(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _trigger(axis: int) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	return event


func _has_mouse(action: String, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false
