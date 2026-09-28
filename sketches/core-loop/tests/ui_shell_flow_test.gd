extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GameMap := preload("res://src/core/game_map.gd")
const LoopMode := preload("res://src/core/loop_mode.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Flow := preload("res://src/core/flow.gd")

# The shell must not cost the run anything (principle 2, quick to start and restart):
#   - Space on the title reaches class select in one press, and the lab row (Start, Help,
#     Loop, Gun) is where and what it was, H, L and G behaving as before;
#   - with the home open, H, L and G wait and Space still starts;
#   - the dead, summary and victory screens keep their keys and their routes;
#   - the victory screen carries the registry's one-line teaser for the world after
#     Brindle;
#   - the calm-screen word budget (40 words) holds on the title, the home, a list and a
#     placeholder page.

const BUDGET := 40

var _game
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _process(_delta: float) -> bool:
	if _game.flow == null or _game.get_meta("shell_test_started", false):
		return false
	_game.set_meta("shell_test_started", true)
	_run()
	return false


func _run() -> void:
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	await _frames(30)
	await _title_keys()
	await _shell_holds_keys()
	await _budget()
	await _end_screens()
	print("ui_shell_flow_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _title_keys() -> void:
	var order := []
	for child in _game.screens._actions.get_children():
		order.append(child.action)
	_report("lab row", order == ["start", "help", "loop", "gun", "menu"] and _game.screens.button_for("loop").text.begins_with("Loop: ")
		and _game.screens.button_for("gun").text.begins_with("Gun: "), "title actions read %s; Start, Help, Loop and Gun lead, Menu follows" % [order])
	var loop_before := LoopMode.mode(_game.tuning)
	var handled: bool = _game._screen_key(KEY_L)
	var loop_after := LoopMode.mode(_game.tuning)
	var gun_before := LoopMode.gun_role(_game.tuning)
	var handled_g: bool = _game._screen_key(KEY_G)
	var gun_after := LoopMode.gun_role(_game.tuning)
	_report("L and G", handled and handled_g and loop_after != loop_before and gun_after != gun_before
		and _game.screens.button_for("loop").text == "Loop: %s" % loop_after and _game.screens.button_for("gun").text == "Gun: %s" % gun_after,
		"L cycles %s to %s and G %s to %s, the buttons follow" % [loop_before, loop_after, gun_before, gun_after])
	var handled_h: bool = _game._screen_key(KEY_H)
	var opened: bool = _game.screens.help_open()
	_game._screen_key(KEY_H)
	_report("H", handled_h and opened and not _game.screens.help_open(), "H opens the how-to-play page (%s) and closes it" % opened)
	var space: bool = _game._screen_key(KEY_SPACE)
	_report("Space starts in one press", space and _game.flow.state_name() == "class_select" and not _game.screens.shell_open(),
		"one Space on the title leaves the flow at %s" % _game.flow.state_name())
	_game.flow.show_title()
	await _frames(2)
	var enter: bool = _game._screen_key(KEY_ENTER)
	_report("Enter starts", enter and _game.flow.state_name() == "class_select", "one Enter reaches %s" % _game.flow.state_name())
	_game.flow.show_title()
	await _frames(2)


func _shell_holds_keys() -> void:
	_game._screen_key(KEY_O)
	var open: bool = _game.screens.shell_open()
	var loop_before := LoopMode.mode(_game.tuning)
	var gun_before := LoopMode.gun_role(_game.tuning)
	_game._screen_key(KEY_L)
	_game._screen_key(KEY_G)
	_game._screen_key(KEY_H)
	_report("home holds the lab keys", open and LoopMode.mode(_game.tuning) == loop_before and LoopMode.gun_role(_game.tuning) == gun_before
		and not _game.screens.help_open(), "with the home open, L, G and H change nothing")
	_game._screen_key(KEY_ESCAPE)
	var closed: bool = not _game.screens.shell_open() and _game.flow.state_name() == "title"
	_game._screen_key(KEY_O)
	_game._screen_key(KEY_SPACE)
	_report("Esc and Space", closed and _game.flow.state_name() == "class_select" and not _game.screens.shell_open(),
		"Esc leaves the home for the title; Space from the home starts a run (%s)" % _game.flow.state_name())
	_game.flow.show_title()
	await _frames(2)


func _words() -> int:
	return WordBudget.count(_game.screens)["hud"]


func _budget() -> void:
	await _frames(30)
	await create_timer(0.5).timeout
	var counts := {}
	counts["title"] = _words()
	_game._screen_key(KEY_O)
	await create_timer(0.5).timeout
	counts["home"] = _words()
	_game._screen_key(KEY_P)
	await create_timer(0.5).timeout
	counts["list"] = _words()
	_game._screen_key(KEY_ESCAPE)
	_game._screen_key(KEY_K)
	await create_timer(0.5).timeout
	counts["kit tree page"] = _words()
	_game._screen_key(KEY_ESCAPE)
	_game._screen_key(KEY_Q)
	await create_timer(0.5).timeout
	counts["credits page"] = _words()
	var over := PackedStringArray()
	for k in counts:
		if counts[k] > BUDGET:
			over.append(k)
	_report("word budget", over.is_empty(), "words on screen: %s (limit %d)" % [counts, BUDGET])
	_game.flow.show_title()
	await _frames(2)


func _die() -> void:
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(20)
	_game.run.damage(99999.0, "test")
	await _frames(40)


func _end_screens() -> void:
	await _die()
	_report("dead screen", _game.flow.state_name() == "dead", "the ball died and the flow is %s" % _game.flow.state_name())
	var keys := {}
	var order := []
	for child in _game.screens._actions.get_children():
		order.append("%s:%s" % [child.action, child.key])
	# N, R, C in turn, each from a fresh death.
	var n_ok: bool = _game._screen_key(KEY_N) and _game.flow.in_play()
	keys["N"] = n_ok
	await _frames(20)
	_game.run.damage(99999.0, "test")
	await _frames(40)
	var retries: int = _game.run.retries
	var r_ok: bool = _game._screen_key(KEY_R) and _game.flow.in_play()
	keys["R"] = r_ok
	await _frames(20)
	_game.run.damage(99999.0, "test")
	await _frames(40)
	var c_ok: bool = _game._screen_key(KEY_C) and _game.flow.state_name() == "class_select"
	keys["C"] = c_ok
	_report("dead keys", n_ok and r_ok and c_ok and order.slice(0, 3) == ["retry:key_r", "new:key_n", "class:key_c"],
		"R, N and C keep their routes (%s); actions %s" % [keys, order])
	# Summary: Space and N after the guard.
	_game.flow.show_title()
	await _die()
	_game.flow._set_state(Flow.SUMMARY)
	await _frames(5)
	_game.summary_guard_left = 0.0
	var summary_actions := []
	for child in _game.screens._actions.get_children():
		summary_actions.append("%s:%s" % [child.action, child.key])
	var again: bool = _game._screen_key(KEY_N) and _game.flow.in_play()
	await _frames(20)
	_game.flow._set_state(Flow.SUMMARY)
	await _frames(5)
	_game.summary_guard_left = 0.0
	var space_ok: bool = _game._screen_key(KEY_SPACE) and _game.flow.state_name() == "class_select"
	_report("summary keys", again and space_ok and summary_actions == ["again:key_n", "class:key_space"],
		"N runs again and Space reaches class select; actions %s" % [summary_actions])
	# Victory: no key, the registry's teaser under the line.
	_game.flow.show_title()
	await _frames(2)
	_game.flow._victory_left = 99.0
	_game.flow._set_state(Flow.VICTORY)
	await _frames(5)
	var body: String = _game.screens._body.text
	var no_keys: bool = not _game._screen_key(KEY_SPACE) and not _game._screen_key(KEY_O) and not _game.screens.shell_open()
	_report("victory screen", no_keys and body.contains(GameMap.after_brindle()) and body.contains("World 2: ???")
		and _game.screens._actions.get_child_count() == 0,
		"victory keeps no keys and no buttons; its body reads \"%s\"" % body.replace("\n", " / "))
