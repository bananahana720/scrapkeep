extends Node


const PAD_LOST := "Controller disconnected"
const CLICK_GUARD_MS := 250

var game
var guard_until_ms := 0
var _pad := -1
var _owed := false
var _owed_reason := ""


func _init() -> void:
	name = "AutoPause"
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(game_ref) -> void:
	game = game_ref
	set_process(false)
	Input.joy_connection_changed.connect(pad_changed)


# Deferred because Godot focus notifications can arrive while parent children are locked.
func _stay_last() -> void:
	if get_parent() == game:
		game.move_child(self, -1)


func _notification(what: int) -> void:
	if game == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focus_back()


func pause(reason := "") -> bool:
	if game.bot_driven or game.flow == null or not game.flow.in_play():
		return false
	var menu = _menu()
	if menu == null:
		return false
	_stay_last.call_deferred()
	menu.open()
	if not menu.is_open():
		if reason != "" or not _owed:
			_owed_reason = reason
		_owed = true
		set_process(true)
		return false
	_owed = false
	if reason != "":
		menu.note(reason)
	return true


func owed() -> bool:
	return _owed


func _process(_delta: float) -> void:
	if _owed and (game.flow == null or not game.flow.in_play() or (_owed_reason == PAD_LOST and game.last_device != "pad")):
		_owed = false
	if _owed:
		pause(_owed_reason)
	set_process(_owed)


func focus_back() -> void:
	if game.bot_driven:
		return
	if _owed_reason == "":
		_owed = false
	var menu = _menu()
	if menu != null and menu.is_open():
		guard_until_ms = Time.get_ticks_msec() + CLICK_GUARD_MS


func pad_changed(device: int, connected: bool) -> void:
	if connected:
		if _owed_reason == PAD_LOST:
			_owed = false
		var menu = _menu()
		if menu != null and menu.note_text() == PAD_LOST:
			menu.note("")
	elif game.last_device == "pad" and (device == _pad or _pad < 0):
		pause(PAD_LOST)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.2):
		_pad = event.device
	elif event is InputEventMouseButton and event.pressed and Time.get_ticks_msec() < guard_until_ms:
		get_viewport().set_input_as_handled()


func _menu():
	return game.get_node_or_null("PauseMenu")
