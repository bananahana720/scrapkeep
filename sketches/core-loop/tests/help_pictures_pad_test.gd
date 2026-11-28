extends SceneTree

const Game := preload("res://src/game.gd")
const Push := preload("res://tests/support/push.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("help_pictures_pad_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.screens.toggle_help()
	await process_frame
	await process_frame
	var help = game.screens._help
	_t.check("opening Help focuses its page button, so a pad lands on it", help.page_button.has_focus())
	Push.pad(root, JOY_BUTTON_A)
	await process_frame
	_t.check("gamepad A opens Pictures", help._mechanics.visible and not help.diagram.visible)
	_t.check("Help stays open after Pictures", game.screens.help_open())
	Push.pad(root, JOY_BUTTON_A)
	await process_frame
	_t.check("gamepad A turns to the next pictures", help.page == 2 and not help.diagram.visible)
	Push.pad(root, JOY_BUTTON_A)
	await process_frame
	Push.pad(root, JOY_BUTTON_A)
	await process_frame
	_t.check("gamepad A opens Rules", help._rules.visible and not help.pictures_showing())
	Push.pad(root, JOY_BUTTON_A)
	await process_frame
	_t.check("gamepad A returns to Controls", help.diagram.visible and not help.pictures_showing() and not help._rules.visible)
	help.back.grab_focus()
	Push.pad(root, JOY_BUTTON_A)
	await process_frame
	_t.check("gamepad A activates Back", not game.screens.help_open())
	_t.check("closing Help gives the pad back the Help button", game.screens.button_for("help").has_focus())
	game.screens.toggle_help()
	Push.pad(root, JOY_BUTTON_B)
	_t.check("gamepad B still closes Help", not game.screens.help_open())
	game.free()
	quit(_t.verdict())
