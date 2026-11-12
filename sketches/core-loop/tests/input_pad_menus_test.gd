extends SceneTree

const Game := preload("res://src/game.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Push := preload("res://tests/workshop/push.gd")
const T := preload("res://tests/support/t.gd")

# S5: a gamepad gets through every menu. Pad events are pushed into the viewport as the other
# menu tests push keys (the game skips its own _input in test mode, so the title, dead and
# summary screens' keys are read from pad_screen_key and fed to _screen_key).
#   S5-1 ui_accept holds pad A and the three keys, ui_cancel pad B and Escape;
#   S5-2 no Control holds focus in play, and a pad A there presses no button;
#   S5-3 title: d-pad then A presses the focused button, A with nothing focused starts the
#        run, B closes help or achievements and A does not start a run;
#   S5-4 class select by pad: d-pad, A picks (a locked card only shakes), X cycles the paint;
#   S5-5 dead and summary: Y class select, X replay, B new run (summary: A new run, B class select);
#   S5-6 workshop: Y talks while the counter is open; the upgrade pick's first A picks
#        nothing and the second picks, unless the d-pad moved focus first;
#   S5-7 field notes: Back held shows them, d-pad right turns a page, release hides them.

var _t := T.new("input_pad_menus_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= _game.get_process_delta_time()


func _pad(button: int, pressed := true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _kinds(action: String) -> Array:
	var out: Array = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			out.append("key:%d" % (event.keycode if event.keycode != 0 else event.physical_keycode))
		elif event is InputEventJoypadButton:
			out.append("pad:%d" % event.button_index)
	out.sort()
	return out


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	var flow = _game.flow
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	# S5-1
	var want_accept := ["key:%d" % KEY_ENTER, "key:%d" % KEY_KP_ENTER, "key:%d" % KEY_SPACE, "pad:%d" % JOY_BUTTON_A]
	want_accept.sort()
	_t.eq("S5-1 ui_accept", _kinds("ui_accept"), want_accept)
	_t.eq("S5-1 ui_cancel", _kinds("ui_cancel"), ["key:%d" % KEY_ESCAPE, "pad:%d" % JOY_BUTTON_B])
	# S5-3: overlays first, with the title untouched.
	_t.eq("S5-3 title", flow.state_name(), "title")
	_t.eq("S5-3 A with nothing focused is Space", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_SPACE)
	for page in ["toggle_help", "toggle_achievements"]:
		_game.screens.call(page)
		await _frames(2)
		_t.check("S5-3 %s opens" % page, _game.screens.overlay_open(), "")
		_t.eq("S5-3 A with an overlay open maps to no key", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_NONE)
		Push.pad(root, JOY_BUTTON_A)
		await _frames(2)
		_t.check("S5-3 A with %s open starts nothing" % page, flow.state_name() == "title" and _game.screens.overlay_open(), "state %s" % flow.state_name())
		Push.pad(root, JOY_BUTTON_B)
		await _frames(2)
		_t.check("S5-3 B closes %s" % page, not _game.screens.overlay_open() and flow.state_name() == "title", "state %s" % flow.state_name())
	Push.pad(root, JOY_BUTTON_DPAD_DOWN)
	await _frames(2)
	var held := _focus()
	_t.check("S5-3 d-pad down focuses a title button", held != null and held is Button, "focus %s" % held)
	if held != null:
		var presses := [0]
		held.pressed.connect(func(): presses[0] += 1)
		Push.pad(root, JOY_BUTTON_A)
		await _frames(2)
		_t.eq("S5-3 A presses the focused title button", presses[0], 1)
	# Leave the title with nothing focused before class select.
	if _focus() != null:
		_focus().release_focus()
	# S5-4: class select with a locked second pilot.
	var rivet: Resource = flow.classes[1]
	var locked_def := ClassDef.make({"id": rivet.id, "display_name": rivet.display_name, "starter": false})
	for prop in ["role", "species", "pitch", "weapon_id", "movement_id", "special_id", "smash_id", "color", "shape", "motif", "sound", "bible_home", "synergy_hooks"]:
		locked_def.set(prop, rivet.get(prop))
	flow.classes[1] = locked_def
	# Sable is the only starter now: earn every non-starter but the second so only the second card is locked.
	for i in range(2, flow.classes.size()):
		_game.ctx.profile.unlock_pilot(flow.classes[i].id)
	# A card draws its paint row only once the profile owns a paint beyond the starters (wave 36).
	_game.ctx.profile.unlock_cosmetic("paint_any_night")
	flow.open_class_select()
	_game.screens._on_flow_changed("class_select")
	await _settle(0.7)
	# PF-40: pilot select opens on the first pilot the profile can take, so its key words are up from the start.
	var opened: Array = _game.screens.class_cards()
	_t.check("S5-4 pilot select opens on the first unlocked card", not opened[0].locked and opened[0].has_focus(), "focus %s" % _focus())
	if _focus() != null:
		_focus().release_focus()
	Push.pad(root, JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	var cards: Array = _game.screens.class_cards()
	var first_id: String = cards[0].def.id
	var second_id: String = cards[1].def.id
	_t.check("S5-4 d-pad right lands on card 0", cards[0].has_focus(), "focus %s" % _focus())
	Push.pad(root, JOY_BUTTON_X)
	await _frames(2)
	var profile = _game.ctx.profile
	_t.eq("S5-4 X cycles the open card's paint", profile.equipped(first_id, "paint"), "paint_any_salt")
	var reloaded := preload("res://src/core/profile.gd").new(profile.path)
	reloaded.load_profile()
	_t.eq("S5-4 and saves it", reloaded.equipped(first_id, "paint"), "paint_any_salt")
	Push.pad(root, JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	_t.check("S5-4 d-pad right moves to the locked card", cards[1].has_focus(), "focus %s" % _focus())
	Push.pad(root, JOY_BUTTON_X)
	Push.pad(root, JOY_BUTTON_A)
	await _frames(2)
	_t.check("S5-4 A on a locked card starts nothing", flow.state_name() == "class_select" and cards[1]._shake > 0.0, "state %s shake %s locked %s" % [flow.state_name(), cards[1]._shake, cards[1].locked])
	_t.eq("S5-4 X on a locked card changes no paint", profile.equipped(second_id, "paint"), "")
	var third: String = cards[2].def.id
	Push.pad(root, JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	Push.pad(root, JOY_BUTTON_A)
	await _frames(3)
	_t.check("S5-4 d-pad right then A starts that pilot", flow.in_play() and _game.run.class_id() == third, "state %s class %s want %s" % [flow.state_name(), _game.run.class_id(), third])
	# S5-2: play holds no focus and a pad A in play presses nothing.
	await _frames(2)
	_t.check("S5-2 no focus after class select into play", _focus() == null, "focus %s" % _focus())
	Push.pad(root, JOY_BUTTON_A)
	await _frames(2)
	_t.check("S5-2 a pad A in play changes no screen", flow.in_play(), "state %s" % flow.state_name())
	# S5-5: dead and summary.
	_game.run.damage(99999.0, "test")
	await _frames(12)
	_t.eq("S5-5 dead", flow.state_name(), "dead")
	_t.eq("S5-5 A on death is N (the default)", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_N)
	_t.eq("S5-5 B on death is still N", _game.pad_screen_key(_pad(JOY_BUTTON_B)), KEY_N)
	_t.eq("S5-5 X on death is T", _game.pad_screen_key(_pad(JOY_BUTTON_X)), KEY_T)
	_t.eq("S5-5 Y on death is C", _game.pad_screen_key(_pad(JOY_BUTTON_Y)), KEY_C)
	_game._screen_key(_game.pad_screen_key(_pad(JOY_BUTTON_Y)))
	_t.eq("S5-5 Y opens class select", flow.state_name(), "class_select")
	flow.classes[1] = rivet
	flow.choose_class(0)
	await _frames(3)
	_game.run.damage(99999.0, "test")
	await _frames(12)
	_game._screen_key(_game.pad_screen_key(_pad(JOY_BUTTON_A)))
	await _frames(3)
	_t.check("S5-2 no focus after a new run from the death screen", flow.in_play() and _focus() == null, "state %s focus %s" % [flow.state_name(), _focus()])
	flow._set_state(flow.SUMMARY)
	_game.summary_latched = false
	_t.eq("S5-5 B on the summary is Space", _game.pad_screen_key(_pad(JOY_BUTTON_B)), KEY_SPACE)
	_t.eq("S5-5 A on the summary is N", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_N)
	_game._screen_key(_game.pad_screen_key(_pad(JOY_BUTTON_A)))
	_t.check("S5-5 A on the summary starts a new run", flow.in_play(), "state %s" % flow.state_name())
	_t.check("S5-2 no focus after a new run", _focus() == null, "focus %s" % _focus())
	# S5-6: the upgrade pick and the counter's talk.
	var ws = _game.get_node("Workshop")
	ws.armed = true
	_game.run.damage(99999.0, "test")
	await _frames(12)
	await _settle(0.5)
	flow.new_run()
	await _settle(0.8)
	var tree = _game.player.tree
	await _settle(0.5)
	var picks: Array = ws.pick.cards()
	_t.check("S5-6 the start pick is open", ws.pick.is_open() and picks.size() == 2, "open %s" % ws.pick.is_open())
	var offered: Array = tree.offered(tree.class_id, tree.path().size() + 1)
	if ws.pick.is_open():
		var before: Array = tree.path()
		# The pick focuses card 0 as it opens, so the guard must hold with focus already there.
		Push.pad(root, JOY_BUTTON_A)
		await _frames(2)
		_t.check("S5-6 a first A focuses card 0 and picks nothing", ws.pick.is_open() and picks[0].has_focus() and tree.path() == before, "open %s path %s" % [ws.pick.is_open(), tree.path()])
		Push.pad(root, JOY_BUTTON_A)
		await _frames(2)
		_t.check("S5-6 a second A picks it", not ws.pick.is_open() and tree.path().size() == before.size() + 1, "path %s" % [tree.path()])
		await _frames(2)
		_t.check("S5-2 no focus after the pick closes", _focus() == null, "focus %s" % _focus())
	# Moving focus is a deliberate press, so the A after it picks at once.
	var spare = ws.pick.get_script().new()
	root.add_child(spare)
	var chosen := []
	spare.chosen.connect(func(i): chosen.append(i))
	spare.open(tree.class_id, 1, offered, [], Color.WHITE)
	await _frames(2)
	spare.step_focus(1)
	spare.confirm_pad()
	_t.eq("S5-6 d-pad then A picks the focused card at once", chosen, [1])
	spare.queue_free()
	var shop = _game.build.shop
	shop.enter()
	ws.open_counter()
	await _frames(3)
	var beat_before: String = ws.bubble.text
	Push.pad(root, JOY_BUTTON_Y)
	await _frames(2)
	_t.check("S5-6 Y advances the shopkeeper's talk", ws.bubble.text != "" and ws.bubble.text != beat_before, "bubble \"%s\" was \"%s\"" % [ws.bubble.text, beat_before])
	ws.close_counter()
	await _frames(3)
	_t.check("S5-2 no focus after the counter closes", _focus() == null, "focus %s" % _focus())
	# At Moss's hatch with the counter closed, Y is the play verb (interact), so it does not
	# also talk. The talk key is shown by hand for the ball standing there; the push is
	# read at once, before the next frame recomputes it.
	# 2026-10-04: the zone-entry exchange (wave 4, C5) answers interact, so end it first.
	ws.bubble.dismiss_exchange()
	var beat_closed: String = ws.bubble.text
	ws.talk.visible = true
	Push.pad(root, JOY_BUTTON_Y)
	_t.check("S5-6 Y with the counter closed does not talk", ws.bubble.text == beat_closed, "bubble \"%s\" was \"%s\"" % [ws.bubble.text, beat_closed])
	# S5-7: field notes.
	_t.check("S5-7 notes start hidden", not _game.notes_held(), "")
	root.push_input(_pad(JOY_BUTTON_BACK))
	await _frames(2)
	_t.check("S5-7 Back held shows the notes", _game.notes_held(), "")
	var fn = _find_notes()
	var start_page: int = fn._page if fn != null else -1
	Push.pad(root, JOY_BUTTON_DPAD_RIGHT)
	await _frames(2)
	_t.check("S5-7 d-pad right turns a page", fn != null and fn._page == start_page + 1, "page %d to %d" % [start_page, fn._page if fn != null else -1])
	root.push_input(_pad(JOY_BUTTON_BACK, false))
	await _frames(2)
	_t.check("S5-7 releasing Back hides them", not _game.notes_held(), "")
	_game.queue_free()
	quit(_t.verdict())


func _find_notes() -> Node:
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if "_codex_page" in node and "_page" in node:
			return node
		stack.append_array(node.get_children())
	return null
