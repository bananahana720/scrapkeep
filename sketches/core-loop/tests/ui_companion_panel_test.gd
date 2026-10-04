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
	flow.press_start()
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
	var words: int = WordBudget.count(panel)["hud"]
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
	_t.eq("a seated piece comes out and opens both sockets", _game.run.companion, _doc(stub, []))
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
	var all: Array = []
	for p in Companion.PIECES:
		all.append(p["id"])
	_game.run.companion = _doc(all, [])
	_t.check("reopens with six", _ws.open_companion() and panel.model.owned.size() == 6, "")
	Push.key(root, KEY_1)
	Push.key(root, KEY_2)
	await _frames(2)
	_t.eq("same family refused, sockets stay empty", _game.run.companion, _doc(all, []))
	_t.check("family refusal line shown", panel.screen_text().contains(panel.LINE_FAMILY), panel.message)
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
	_game.queue_free()
	quit(_t.verdict())
