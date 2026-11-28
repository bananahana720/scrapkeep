extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AutoPause := preload("res://src/ui/auto_pause.gd")
const Push := preload("res://tests/support/push.gd")

# The game pauses itself when nobody is at the controls (auto_pause.gd). Focus changes arrive as
# the engine sends them, propagated from the root; pad drops as Input's joy_connection_changed.
#   - on the title a focus loss does nothing;
#   - in play a bot's run (bot_driven) ignores a focus loss;
#   - a played run opens the pause menu on a focus loss, paused, with Resume focused and no note;
#   - the focus coming back does not resume, and the click that brings it back is swallowed for
#     the guard; a click after the guard resumes;
#   - while the field notes hold the tree, a focus loss leaves the menu shut and the tree paused,
#     and nothing is owed once the focus is back;
#   - a held screen that lets go while the focus is still away (a reward ceremony ends on its own
#     timer) gets the pause it was owed on the next frame, and a rebind waiting on the settings page
#     does not take the click that brings the window back;
#   - a spare pad dropping does not pause; the pad in use dropping pauses and says so; a pad
#     connecting takes the line down and still does not resume; closing clears the line;
#   - a pad dropping while the keyboard plays does not pause.

const SETTLE := 0.45

var _t := preload("res://tests/support/t.gd").new("auto_pause_test")
var _game
var _menu
var _auto
var _phase := "boot"
var _clock := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _next(phase: String) -> void:
	_phase = phase
	_clock = 0.0


func _focus(has: bool) -> void:
	root.propagate_notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN if has else MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)


func _process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	if _clock < SETTLE and _phase != "boot":
		return false
	match _phase:
		"boot":
			_menu = _game.get_node("PauseMenu")
			_auto = _game.get_node("AutoPause")
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.bot_driven = false
			_focus(false)
			_t.check("title ignores a focus loss", not _menu.is_open() and not paused and _game.flow.state_name() == "title",
				"menu open %s, paused %s" % [_menu.is_open(), paused])
			_focus(true)
			Push.click(root, _game.screens.button_for("start"))
			_next("class")
		"class":
			Push.click(root, _game.screens.class_cards()[0])
			_next("bot")
		"bot":
			_game.bot_driven = true
			_focus(false)
			_t.check("a bot's run ignores a focus loss", _game.flow.in_play() and not _menu.is_open() and not paused,
				"in play %s, menu open %s, paused %s" % [_game.flow.in_play(), _menu.is_open(), paused])
			_focus(true)
			_game.bot_driven = false
			_focus(false)
			_t.check("focus loss pauses a played run", _menu.is_open() and paused and _game.pause_toggled()
					and _menu.focused_id() == "resume" and _menu.note_text() == "",
				"menu open %s, paused %s, focus %s, note \"%s\"" % [_menu.is_open(), paused, _menu.focused_id(), _menu.note_text()])
			_next("back")
		"back":
			_focus(true)
			var held: bool = _menu.is_open() and paused
			Push.click(root, _menu.row("resume"))
			var guarded: bool = _menu.is_open() and paused
			_t.check("focus back does not resume", held and guarded,
				"after focus in: open and paused %s; after the click that brought it back %s" % [held, guarded])
			_auto.guard_until_ms = 0
			Push.click(root, _menu.row("resume"))
			_t.check("a click after the guard resumes", not _menu.is_open() and not paused and not _game.pause_toggled(),
				"menu open %s, paused %s" % [_menu.is_open(), paused])
			_next("notes")
		"notes":
			_game.hold_notes(true)
			_focus(false)
			_t.check("a held screen keeps its own pause", not _menu.is_open() and paused,
				"notes held: menu open %s, paused %s" % [_menu.is_open(), paused])
			_focus(true)
			_game.hold_notes(false)
			_t.check("and gives the run back", not paused and not _menu.is_open() and not _auto.owed(), "paused %s, owed %s" % [paused, _auto.owed()])
			_next("owed")
		"owed":
			# The game's menu_held is what a reward ceremony, the upgrade pick and Moss's counter set.
			_game.set_menu_held(true)
			_focus(false)
			var shut: bool = not _menu.is_open() and _auto.owed()
			_game.set_menu_held(false)
			_t.check("a held screen leaves the pause owed", shut, "menu open %s, owed %s" % [_menu.is_open(), _auto.owed()])
			_next("owed_paid")
		"owed_paid":
			_t.check("and it is paid when the screen lets go", _menu.is_open() and paused and not _auto.owed(),
				"focus still away: menu open %s, paused %s, owed %s" % [_menu.is_open(), paused, _auto.owed()])
			_t.check("the node sits ahead of the pause menu for input", _auto.get_index() > _menu.get_index(),
				"AutoPause at %d, PauseMenu at %d" % [_auto.get_index(), _menu.get_index()])
			_menu.press("settings")
			var page = _menu.settings_page()
			page.show_page(1)
			page.press("jump")
			var waiting: bool = page.capturing()
			_focus(true)
			Push.click(root, _menu.row("resume"))
			_t.check("a waiting rebind does not take the click that brings the window back", waiting and page.capturing(),
				"capturing before %s, after the click %s" % [waiting, page.capturing()])
			_auto.guard_until_ms = 0
			Push.key(root, KEY_ESCAPE)
			_menu.close()
			_t.check("the run comes back", not _menu.is_open() and not paused, "menu open %s, paused %s" % [_menu.is_open(), paused])
			_next("pad")
		"pad":
			Push.pad(root, JOY_BUTTON_X)
			var on_pad: bool = _game.last_device == "pad"
			Input.joy_connection_changed.emit(3, false)
			var spare: bool = not _menu.is_open() and not paused
			Input.joy_connection_changed.emit(0, false)
			_t.check("the pad in use dropping pauses", on_pad and spare and _menu.is_open() and paused and _menu.note_text() == AutoPause.PAD_LOST,
				"on pad %s; a spare pad left the run going %s; then open %s, paused %s, note \"%s\""
					% [on_pad, spare, _menu.is_open(), paused, _menu.note_text()])
			_next("pad_back")
		"pad_back":
			var shown: bool = _menu._note.is_visible_in_tree()
			Input.joy_connection_changed.emit(0, true)
			_t.check("a pad connecting clears the line and does not resume", shown and _menu.note_text() == "" and _menu.is_open() and paused,
				"line on screen %s, then note \"%s\", open %s, paused %s" % [shown, _menu.note_text(), _menu.is_open(), paused])
			Input.joy_connection_changed.emit(0, false)
			var again: bool = _menu.note_text() == AutoPause.PAD_LOST
			_menu.close()
			_t.check("closing clears the line", again and _menu.note_text() == "" and not paused,
				"dropped again with the menu open: line back %s; after close \"%s\", paused %s" % [again, _menu.note_text(), paused])
			_next("kbm")
		"kbm":
			Push.key(root, KEY_F9)
			var on_keys: bool = _game.last_device == "kbm"
			Input.joy_connection_changed.emit(0, false)
			_t.check("a pad dropping under the keyboard does not pause", on_keys and not _menu.is_open() and not paused,
				"on keys %s, menu open %s, paused %s" % [on_keys, _menu.is_open(), paused])
			quit(_t.verdict())
	return false
