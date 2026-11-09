extends Node

# Nobody is at the controls: the window lost focus, or the pad in use dropped out. In play either
# one opens the pause menu (pause_menu.gd), and only the player closes it: the focus coming back,
# or the pad, never resumes the run. Andrew plays windowed on a two-monitor Hyprland desk, where a
# workspace switch takes the focus and the run used to carry on behind it.
#
# It opens the menu and nothing else, so every rule the menu has holds: outside play nothing
# happens, and while a screen that already holds the tree is up (the upgrade pick, the field
# notes, a hot-wire offer) the menu stays shut and the tree stays paused as it was. A bot's run
# (game.bot_driven: tests, bot_driver.gd, --self-play) never pauses itself, so a capture on the PC
# is not stopped by Andrew working on the other monitor.
#
# A dropped pad pauses only if it is the one that was last touched: a spare pad or a headset that
# registers as one can come and go while the keyboard or another pad plays. The menu says
# PAD_LOST under its title until a pad connects again.
#
# The click that brings a window back is not a press: for CLICK_GUARD_MS after the focus returns
# to an open menu, mouse presses are swallowed, so a click-to-focus cannot land on Quit or Restart.

const PAD_LOST := "Controller disconnected"
const CLICK_GUARD_MS := 250

var game
# The ticks (ms) until which a mouse press is swallowed; a test ends the guard by zeroing it.
var guard_until_ms := 0
var _pad := -1


func _init() -> void:
	name = "AutoPause"
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(game_ref) -> void:
	game = game_ref
	Input.joy_connection_changed.connect(pad_changed)


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
	menu.open()
	if not menu.is_open():
		return false
	if reason != "":
		menu.note(reason)
	return true


func focus_back() -> void:
	var menu = _menu()
	if menu != null and menu.is_open():
		guard_until_ms = Time.get_ticks_msec() + CLICK_GUARD_MS


func pad_changed(device: int, connected: bool) -> void:
	if connected:
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
