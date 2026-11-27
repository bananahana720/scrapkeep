extends SceneTree

const Game := preload("res://src/game.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("camp_interact_rebind_test")
var _game
var _hub
var _screens


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _put_in(id: String) -> void:
	var centre: Vector3 = _hub.zone_position(id)
	var toward: Vector3 = _hub.root.global_position - centre
	toward.y = 0.0
	var at: Vector3 = centre + toward.normalized() * 1.5
	at.y = 1.3
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	await _physics(4)


func _set_interact_events(events: Array) -> void:
	InputMap.action_erase_events("cl_interact")
	for ev in events:
		InputMap.action_add_event("cl_interact", ev)


func _send(event: InputEvent) -> void:
	for down in [true, false]:
		var sent: InputEvent = event.duplicate()
		sent.pressed = down
		Input.parse_input_event(sent)
		Input.flush_buffered_events()


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = Vector2(800, 450)
	event.global_position = event.position
	return event


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(4)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_screens = _game.screens
	_hub = _game.camp_hub
	var saved_events: Array = InputMap.action_get_events("cl_interact").duplicate()
	var saved_device := Glyphs.device

	_game._screen_key(KEY_K)
	await _frames(3)
	_t.check("walk entered for rebind test", _screens.walk_live() and _hub.walking)

	var interact_stations := ["camp_ring", "sandbox_call_box", "camp_skee", "camp_trial"]
	for sid in interact_stations:
		_t.eq("%s binds to the interact verb" % sid, String(_hub._zones[sid].get("verb", "")), "interact")

	Glyphs.device = "kbm"
	await _put_in("camp_trial")
	_t.eq("default Interact glyph on camp_trial is key_e", _hub.card_for("camp_trial").key, "key_e")

	var key_g := InputEventKey.new()
	key_g.physical_keycode = KEY_G
	var pad_y := InputEventJoypadButton.new()
	pad_y.button_index = JOY_BUTTON_Y
	_set_interact_events([key_g, pad_y])
	await _frames(2)
	_t.eq("rebound Interact to G updates camp_trial prompt glyph to key_g", _hub.card_for("camp_trial").key, "key_g")
	_t.eq("confirm_key reflects rebound G", _hub.confirm_key(), KEY_G)
	var trial = _hub.root.get_node("CampTrial")
	_t.check("old E no longer triggers camp_trial after rebinding to G", not _hub.press_key(KEY_E) and trial.run.state == trial.State.IDLE)
	_t.check("rebound G triggers camp_trial", _hub.press_key(KEY_G) and trial.run.state == trial.State.ARMED)
	trial.abort()
	await _frames(2)

	Glyphs.device = "pad"
	_send(_pad(JOY_BUTTON_X))
	await _frames(1)
	_t.eq("a pad button Interact is not bound to leaves camp_trial idle", trial.run.state, trial.State.IDLE)
	_send(_pad(JOY_BUTTON_Y))
	await _frames(1)
	_t.eq("pad Y sent through the engine arms camp_trial on the drawn pad_y prompt", trial.run.state, trial.State.ARMED)
	trial.abort()
	await _frames(2)
	Glyphs.device = "kbm"
	var key_g_press := InputEventKey.new()
	key_g_press.physical_keycode = KEY_G
	_send(key_g_press)
	await _frames(1)
	_t.eq("rebound G sent through the engine arms camp_trial", trial.run.state, trial.State.ARMED)
	trial.abort()
	await _frames(2)

	Glyphs.device = "pad"
	await _frames(2)
	_t.eq("pad mode shows pad_y on camp_trial prompt", _hub.card_for("camp_trial").key, "pad_y")
	var pad_l3 := InputEventJoypadButton.new()
	pad_l3.button_index = JOY_BUTTON_LEFT_STICK
	_set_interact_events([key_g, pad_l3])
	await _frames(2)
	_t.eq("pad L3 rebind shows key_l3 instead of falling back to E", _hub.card_for("camp_trial").key, "key_l3")

	Glyphs.device = "kbm"
	var mmb := InputEventMouseButton.new()
	mmb.button_index = MOUSE_BUTTON_MIDDLE
	_set_interact_events([mmb, pad_y])
	await _frames(2)
	_t.eq("middle mouse Interact binding draws key_mmb instead of key_e", Glyphs.of("interact"), "key_mmb")
	_send(_mouse(MOUSE_BUTTON_MIDDLE))
	await _frames(1)
	_t.eq("middle mouse sent through the engine arms camp_trial when Interact is bound to it", trial.run.state, trial.State.ARMED)
	trial.abort()
	await _frames(2)
	var mb4 := InputEventMouseButton.new()
	mb4.button_index = MOUSE_BUTTON_XBUTTON1
	_set_interact_events([mb4, pad_y])
	_t.eq("mouse button 4 Interact binding draws key_mb4 instead of key_e", Glyphs.of("interact"), "key_mb4")

	_set_interact_events(saved_events)
	Glyphs.device = saved_device
	_game._screen_key(KEY_K)
	await _frames(2)
	_game.free()
	quit(_t.verdict())
