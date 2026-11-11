extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Push := preload("res://tests/workshop/push.gd")
const T := preload("res://tests/support/t.gd")

# The companion assembly screen (META-6). With --companion-stub on, one piece per family is
# owned at run start. The screen opens from the workshop on the death screen, by M or the
# pad's left bumper, and never while a stage is in play. Picking seats a piece, a pair of
# two families is accepted in either order, a third piece or a same-family pair is refused
# with one line, U (pad Y) empties both sockets, and every change writes run.companion as
# the model's to_dict. The escape corridor seated leaves the next zone's escape ready.
# The same key opens it on the run summary, the title and class select (where it edits the
# profile's companion), and over Moss's counter in the bay; never under an overlay or the
# summary guard. Closing it outside play writes the profile, so the next run starts with it.

const BUDGET := 50

var _t := T.new("ui_companion_panel_test")
var _game
var _ws


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# What the model says about a given owned list and seated pair.
func _doc(owned: Array, seated: Array) -> Dictionary:
	var m := Companion.new()
	for id in owned:
		m.acquire(id)
	if not seated.is_empty():
		m.assemble(seated)
	return m.to_dict()


func _escape_ready() -> bool:
	var m := Companion.new()
	return m.from_dict(_game.run.companion) and m.escape_ready()


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	var flow = _game.flow
	_ws = _game.get_node("Workshop")
	var panel = _ws.companion_panel
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_t.eq("stub default off", Tuning.new().option("companion_stub"), "off")
	_game.tuning.set_option("companion_stub", "on")
	var profile = _game.ctx.profile
	var all: Array = []
	for p in Companion.PIECES:
		all.append(p["id"])
	# The title, at boot: the profile's pieces.
	_ws.armed = true
	_t.eq("boot on the title", flow.state_name(), "title")
	profile.set_companion(_doc(all, []))
	_game.screens._on_flow_changed("title")
	_t.check("companion button on the title", _game.screens.button_for("companion") != null, "")
	await _frames(2)
	var room: Vector2 = root.get_visible_rect().size
	var band_w: float = _game.screens.NARROW_W - 2.0 * _game.screens.SIDE
	var band := Rect2((room.x - band_w) / 2.0, 0.0, band_w, room.y)
	var rects: Array = []
	for child in _game.screens._actions.get_children():
		if child is Button and child.visible:
			rects.append((child as Control).get_global_rect())
	var inside := rects.all(func(r): return band.grow(0.5).encloses(r))
	var apart := true
	for a in rects.size():
		for b in range(a + 1, rects.size()):
			apart = apart and not (rects[a] as Rect2).grow(-0.5).intersects((rects[b] as Rect2).grow(-0.5))
	_t.check("title row buttons sit inside the narrow band", rects.size() >= 5 and inside, "%d buttons, band %s, rects %s" % [rects.size(), band, rects])
	_t.check("title row buttons never overlap", apart, "%s" % [rects])
	Push.key(root, KEY_M)
	await _frames(2)
	_t.check("M on the title opens the profile's six", panel.is_open() and panel.model.owned.size() == 6, "")
	var words: int = WordBudget.count(panel)["hud"]
	_t.check("calm budget on the title", words <= BUDGET, "%d words, budget %d" % [words, BUDGET])
	Push.key(root, KEY_1)
	Push.key(root, KEY_3)
	await _frames(2)
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("Esc leaves to the title", not panel.is_open() and flow.state_name() == "title", "state %s" % flow.state_name())
	_t.eq("title edit reaches the profile", profile.companion(), _doc(all, ["primer_coil", "ram_prow"]))
	# Overlays on the title keep M.
	_game.screens.toggle_help()
	Push.key(root, KEY_M)
	await _frames(2)
	_t.check("M under help opens nothing", not panel.is_open(), "")
	_game.screens.toggle_help()
	_game.screens.toggle_settings()
	Push.key(root, KEY_M)
	await _frames(2)
	_t.check("M under settings opens nothing", not panel.is_open(), "")
	_game.screens.toggle_settings()
	await _frames(2)
	# An empty profile companion: no button, no panel.
	profile.set_companion({})
	_game.run.companion = {}
	_game.screens._on_flow_changed("title")
	_t.check("empty profile: no title button, no panel", _game.screens.button_for("companion") == null and not _ws.open_companion(), "")
	# Class select is outside a run too.
	profile.set_companion(_doc(all, []))
	flow.press_start()
	await _frames(2)
	Push.key(root, KEY_M)
	await _frames(2)
	_t.check("M on class select opens the panel", panel.is_open() and flow.state_name() == "class_select", "state %s" % flow.state_name())
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("Esc leaves to class select", not panel.is_open() and flow.state_name() == "class_select", "state %s" % flow.state_name())
	# The stub grants only into an empty run.companion.
	profile.set_companion({})
	_game.run.companion = {}
	_ws.armed = false
	flow.choose_class(1)
	await _frames(20)
	_ws.armed = true
	var stub := ["primer_coil", "ram_prow", "escape_vent"]
	_t.eq("stub: three pieces owned at run start", _game.run.companion, _doc(stub, []))
	# In play: no way in.
	_t.check("closed in play", not _ws.open_companion() and not panel.is_open(), "state %s" % flow.state_name())
	Push.key(root, KEY_M)
	await _frames(2)
	_t.check("M in play opens nothing", not panel.is_open(), "")
	# Between attempts: the death screen.
	_game.run.damage(99999.0, "test")
	await _frames(12)
	_t.eq("dead", flow.state_name(), "dead")
	_t.check("companion button on the death screen", _game.screens.button_for("companion") != null, "")
	Push.key(root, KEY_M)
	await _frames(2)
	_t.check("M opens the panel", panel.is_open(), "")
	Push.pad(root, JOY_BUTTON_B)
	await _frames(2)
	_t.check("pad B leaves", not panel.is_open() and flow.state_name() == "dead", "state %s" % flow.state_name())
	Push.pad(root, JOY_BUTTON_LEFT_SHOULDER)
	await _frames(2)
	_t.check("pad LB opens the panel", panel.is_open(), "")
	words = WordBudget.count(panel)["hud"]
	_t.check("calm budget", words <= BUDGET, "%d words, budget %d" % [words, BUDGET])
	# Either order.
	Push.key(root, KEY_1)
	Push.key(root, KEY_3)
	await _frames(2)
	var want := _doc(stub, ["primer_coil", "escape_vent"])
	_t.eq("coil then vent", _game.run.companion, want)
	_t.check("escape ready for the next zone", _escape_ready(), "")
	Push.key(root, KEY_U)
	await _frames(2)
	_t.eq("U empties the sockets", _game.run.companion, _doc(stub, []))
	_t.check("no escape unseated", not _escape_ready(), "")
	Push.key(root, KEY_3)
	Push.key(root, KEY_1)
	await _frames(2)
	_t.eq("vent then coil", _game.run.companion, want)
	# A third piece.
	Push.key(root, KEY_2)
	await _frames(2)
	_t.eq("third refused, nothing changes", _game.run.companion, want)
	_t.check("refusal is one visible line", panel.message == panel.LINE_FULL and panel.screen_text().contains(panel.LINE_FULL) and not panel.message.contains("\n"), panel.message)
	# Taking one out.
	Push.key(root, KEY_3)
	await _frames(2)
	_t.eq("a seated piece comes out and the other stays seated", _game.run.companion, _doc(stub, ["primer_coil"]))
	_t.eq("the other stays staged", panel.staged, ["primer_coil"] as Array[String])
	Push.key(root, KEY_2)
	await _frames(2)
	_t.eq("ram then coil", _game.run.companion, _doc(stub, ["primer_coil", "ram_prow"]))
	_t.check("no escape without the corridor", not _escape_ready(), "")
	# Pad: d-pad moves, A picks, Y empties.
	Push.pad(root, JOY_BUTTON_Y)
	await _frames(2)
	_t.eq("pad Y empties", _game.run.companion, _doc(stub, []))
	_t.eq("cursor on the last pick", panel.cursor, 1)
	Push.pad(root, JOY_BUTTON_DPAD_DOWN)
	Push.pad(root, JOY_BUTTON_A)
	Push.pad(root, JOY_BUTTON_DPAD_UP)
	Push.pad(root, JOY_BUTTON_DPAD_UP)
	Push.pad(root, JOY_BUTTON_A)
	await _frames(2)
	_t.eq("pad picks vent and coil", _game.run.companion, want)
	# A family twice, on a run that owns all six.
	panel.close()
	_game.run.companion = _doc(all, [])
	_t.check("reopens with six", _ws.open_companion() and panel.model.owned.size() == 6, "")
	await _frames(2)
	_t.check("every row leaves its icon 24 px, the longest name too", panel.icon_room().size() == 6 and panel.icon_room().min() >= 24.0, str(panel.icon_room()))
	_t.check("the screen behind does not read through the panel", panel._veil.color.a >= 0.95, str(panel._veil.color.a))
	Push.key(root, KEY_1)
	Push.key(root, KEY_2)
	await _frames(2)
	_t.eq("same family refused, the first stays seated", _game.run.companion, _doc(all, ["primer_coil"]))
	_t.check("family refusal line shown", panel.screen_text().contains(panel.LINE_FAMILY), panel.message)
	_t.check("no title and no socket text; two marks", not panel.screen_text().contains("COMPANION") and not panel.screen_text().contains("Socket") and panel.socket_icons().size() == 2, panel.screen_text())
	_t.eq("only the first piece staged", panel.staged, ["primer_coil"] as Array[String])
	Push.key(root, KEY_3)
	await _frames(2)
	_t.eq("a different family fits", _game.run.companion, _doc(all, ["primer_coil", "ram_prow"]))
	words = WordBudget.count(panel)["hud"]
	_t.check("calm budget with six owned", words <= BUDGET, "%d words, budget %d" % [words, BUDGET])
	# Leaving play closes it, and the companion rides through the retry.
	_game.run.companion = _doc(stub, ["primer_coil", "escape_vent"])
	panel.close()
	_t.check("reopens", _ws.open_companion(), "")
	flow.retry_stage()
	await _frames(3)
	_t.check("retry closes the panel", not panel.is_open() and flow.in_play(), "state %s" % flow.state_name())
	_t.check("closed again in play", not _ws.open_companion(), "")
	_t.check("escape ready in the next attempt", _escape_ready(), "")
	# A run with no companion has nothing to open.
	_game.run.companion = {}
	_game.run.damage(99999.0, "test")
	await _frames(12)
	_t.check("no companion, no panel", not _ws.open_companion() and _game.screens.button_for("companion") == null, "")
	# The run summary, after the guard.
	flow.new_run()
	await _frames(5)
	_game.run.companion = _doc(stub, [])
	flow._end_run(false)
	await _frames(5)
	_t.eq("summary", flow.state_name(), "summary")
	# Headless frames outrun the guard's wall-clock seconds; the Guard section below covers it.
	_game.summary_latched = false
	_t.check("companion button on the summary", _game.screens.button_for("companion") != null, "")
	Push.key(root, KEY_M)
	await _frames(2)
	_t.check("M on the summary opens the panel", panel.is_open(), "")
	Push.key(root, KEY_1)
	Push.key(root, KEY_3)
	await _frames(2)
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("Esc leaves to the summary", not panel.is_open() and flow.state_name() == "summary", "state %s" % flow.state_name())
	_t.eq("summary edit reaches the profile", _game.ctx.profile.companion(), want)
	flow.new_run()
	await _frames(5)
	_t.eq("new run keeps the summary assembly", _game.run.companion, want)
	# The latch: Space (a bound key) held as the summary arrives, and M pressed, opens nothing.
	_hold(KEY_SPACE, true)
	flow._end_run(false)
	await _frames(1)
	_t.check("latch up", _game.summary_latched, "latched %s" % _game.summary_latched)
	Push.key(root, KEY_M)
	await _frames(1)
	_t.check("M under the summary latch opens nothing", not panel.is_open(), "")
	_hold(KEY_SPACE, false)
	# Moss's counter in the bay: the in-run intermission.
	_game.summary_latched = false
	flow.new_run()
	await _frames(20)
	_game.run.companion = _doc(stub, [])
	_game.build.shop.enter()
	_ws.open_counter()
	await _frames(2)
	_t.check("counter open in the bay", _ws.counter.is_open() and flow.in_play(), "state %s" % flow.state_name())
	Push.key(root, KEY_M)
	await _frames(2)
	_t.check("M at the counter opens the panel over it", panel.is_open() and _ws.counter.is_open(), "")
	Push.key(root, KEY_1)
	Push.key(root, KEY_3)
	await _frames(2)
	_t.eq("bay seats coil and vent", _game.run.companion, want)
	Push.pad(root, JOY_BUTTON_B)
	await _frames(2)
	_t.check("pad B returns to the counter, ball still parked", not panel.is_open() and _ws.counter.is_open() and _game.player.frozen(), "")
	Push.pad(root, JOY_BUTTON_LEFT_SHOULDER)
	await _frames(2)
	_t.check("pad LB reopens it at the counter", panel.is_open(), "")
	_ws._on_bay_left()
	await _frames(2)
	_t.check("leaving the bay closes both", not panel.is_open() and not _ws.counter.is_open(), "")
	Push.key(root, KEY_M)
	await _frames(2)
	_t.check("counter shut in play: M opens nothing", not panel.is_open() and not _ws.open_companion() and flow.in_play(), "state %s" % flow.state_name())
	_game.queue_free()
	quit(_t.verdict())


# Holds or releases a physical key in the Input singleton, as a finger on it would.
func _hold(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
