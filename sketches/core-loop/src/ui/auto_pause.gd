extends Node

# Nobody is at the controls: the window lost focus, or the pad in use dropped out. In play either
# one opens the pause menu (pause_menu.gd), and only the player closes it: the focus coming back,
# or the pad, never resumes the run. Andrew plays windowed on a two-monitor Hyprland desk, where a
# workspace switch takes the focus and the run used to carry on behind it.
#
# It opens the menu and nothing else, so every rule the menu has holds: outside play nothing
# happens, and while a screen that already holds the menu shut is up (the upgrade pick, the field
# notes, a hot-wire offer, a reward ceremony, Moss's counter) the menu stays shut. The pause is
# then owed: a ceremony ends on its own timer and would hand the run back to an empty chair, so
# the menu opens the frame that screen lets go, unless the focus or a pad came back first. A
# bot's run (game.bot_driven: tests, bot_driver.gd, --self-play) never pauses itself, so a capture
# on the PC is not stopped by Andrew working on the other monitor.
#
# A dropped pad pauses only if it is the one that was last touched: a spare pad or a headset that
# registers as one can come and go while the keyboard or another pad plays. The menu says
# PAD_LOST under its title until a pad connects again.
#
# The click that brings a window back is not a press: for CLICK_GUARD_MS after the focus returns
# to an open menu, mouse presses are swallowed, so a click-to-focus cannot land on Quit or Restart,
# or become a binding on the settings page. Input reaches the last child first and the pause menu
# is built after this node, so each pause moves this node last under the game, ahead of the menu.

const PAD_LOST := "Controller disconnected"
const CLICK_GUARD_MS := 250

var game
# The ticks (ms) until which a mouse press is swallowed; a test ends the guard by zeroing it.
var guard_until_ms := 0
var _pad := -1
# A pause a held screen kept from opening, and its line; _process runs only while one is owed.
var _owed := false
var _owed_reason := ""


func _init() -> void:
	name = "AutoPause"
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(game_ref) -> void:
	game = game_ref
	set_process(false)
	Input.joy_connection_changed.connect(pad_changed)


# Deferred by its caller: a focus notification arrives while the game is busy with its children.
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


# Opens the pause menu for a played run and says why under its title; true if the menu is open.
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


# True while a pause waits for a held screen to let go.
func owed() -> bool:
	return _owed


# Only while a pause is owed: it opens the frame the menu can, and is dropped if the run ended or
# the player went on by keyboard after the pad dropped.
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
