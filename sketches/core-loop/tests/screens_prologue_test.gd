extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const PrologueRows := preload("res://src/core/prologue_rows.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const Push := preload("res://tests/support/push.gd")

# ST5-1: the prologue on a fresh profile.
#   - every row is a speaker and at most LINE_WORD_CAP words;
#   - the first Start shows line one over pilot select with the cards hidden, the interact
#     key (E) advances through all three lines, and after the last the cards show;
#   - the profile records it, so the second Start (and a fresh read of the store) shows none;
#   - on another fresh profile, fire skips what is left at once;
#   - a record heard while the prologue is up waits for its cards to close (PF-19).

var _t := preload("res://tests/support/t.gd").new("screens_prologue_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _boot() -> void:
	if _game != null:
		_game.free()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.screens.prologue_enabled = true
	await _frames(3)


func _cards_shown() -> bool:
	var cards: Array = _game.screens.class_cards()
	return not cards.is_empty() and cards[0].is_visible_in_tree()


func _run() -> void:
	for row in PrologueRows.ROWS:
		_t.check("row %s within cap" % row["speaker"], String(row["speaker"]) != "" and PrologueRows.words(row["text"]) <= PrologueRows.LINE_WORD_CAP,
			"%d words: %s" % [PrologueRows.words(row["text"]), row["text"]])
	_t.eq("three rows", PrologueRows.ROWS.size(), 3)

	await _boot()
	_t.check("fresh profile has not seen it", not _game.hud.profile.seen(PrologueRows.ID), "")
	_game.flow.press_start()
	await _frames(2)
	_t.check("first Start shows line one", _game.screens.prologue_showing() and _game.screens.prologue_line() == 0
			and _game.screens.body_text().contains(PrologueRows.ROWS[0]["text"]) and not _cards_shown(),
		"state %s; body \"%s\"; cards shown %s" % [_game.flow.state_name(), _game.screens.body_text().get_slice("\n", 0), _cards_shown()])
	_game.hud.tune_found("Lights On")
	await _frames(4)
	_t.check("a record heard over the prologue waits for it (PF-19)", _game.ctx.screen_busy.busy() and _game.hud.ach_toasts().is_empty()
			and _game.hud.tune_waiting().size() == 1, "busy %s; on screen %s; waiting %s" % [_game.ctx.screen_busy.busy(), _game.hud.ach_toasts(), _game.hud.tune_waiting()])
	for i in range(1, PrologueRows.ROWS.size()):
		Push.key(root, KEY_E)
		await _frames(1)
		_t.check("E shows line %d" % (i + 1), _game.screens.prologue_line() == i and _game.screens.body_text().contains(PrologueRows.ROWS[i]["text"]),
			"line %d; body \"%s\"" % [_game.screens.prologue_line(), _game.screens.body_text().get_slice("\n", 0)])
	Push.key(root, KEY_E)
	await _frames(2)
	_t.check("E after the last line shows the cards", not _game.screens.prologue_showing() and _cards_shown()
			and _game.flow.state_name() == "class_select", "showing %s; cards %s" % [_game.screens.prologue_showing(), _cards_shown()])
	await _frames(1)
	var first = _game.screens.class_cards().filter(func(c): return not c.locked).front()
	_t.check("and opens the first pilot the profile can take (PF-40)", first != null and first.has_focus(),
		"focus %s" % root.gui_get_focus_owner())
	_t.check("with the prologue closed the screen is free for the record", not _game.ctx.screen_busy.busy(), "")
	_t.check("the profile records it", _game.hud.profile.seen(PrologueRows.ID) and UiProfile.new(_game.storage_dir).seen(PrologueRows.ID), "")

	_game.flow.show_title()
	await _frames(1)
	_game.flow.press_start()
	await _frames(2)
	_t.check("second Start shows no prologue", not _game.screens.prologue_showing() and _cards_shown(),
		"showing %s; cards %s" % [_game.screens.prologue_showing(), _cards_shown()])

	await _boot()
	_game.flow.press_start()
	await _frames(2)
	var before: bool = _game.screens.prologue_showing()
	var fire := InputEventAction.new()
	fire.action = "cl_fire"
	fire.pressed = true
	root.push_input(fire)
	await _frames(2)
	_t.check("fire skips the rest", before and not _game.screens.prologue_showing() and _cards_shown(),
		"showing before %s, after %s" % [before, _game.screens.prologue_showing()])

	_game.free()
	quit(_t.verdict())
