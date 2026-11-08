extends SceneTree

const Game := preload("res://src/game.gd")
const Profile := preload("res://src/core/profile.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")

# The stage 1 start-pick card and the mouse (w22 first-timer red team edge 3), driven as a player:
# every event goes through Input.parse_input_event to the real input chain (game.gd, the card, the
# pause menu, the workshop's per-frame sync). Headless cannot capture a mouse, so PointerGame keeps
# the capture flag game.gd asks for and reads it back; everything past that flag is the real code.
# - fresh profile (no rung to choose): a click captures with the card up, mouse motion turns the
#   camera, Esc opens the pause menu and the card takes nothing under it, 1 takes the pick;
# - a rung unlocked: the card frees the cursor while the tier is open (motion does not turn the
#   camera, a click does not recapture), Esc, P and pad Start open the pause menu over the tier
#   choice and close it again with the cursor left free for the tier (w23 cautious red team watch 3),
#   and engaging stage 1's Warden gives look back;
# - the run summary: Esc goes to the camp, as K does, and never quits (w23 cautious watch 4); under
#   the summary's input latch it does nothing.
# Real pointer capture on a desktop is a hands-on check (alpha-status/sitting-watch-list.md).

class PointerGame extends "res://src/game.gd":
	var captured := false
	var grabs := 0
	var quits := 0

	func _quit() -> void:
		quits += 1

	func capture_mouse(capture: bool) -> void:
		captured = capture
		if capture:
			grabs += 1

	func mouse_captured() -> bool:
		return captured


var t := T.new("start_card_pointer_test")
var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = PointerGame.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	await _fresh()
	await _counter()
	await _rung()
	await _summary()
	game.free()
	quit(t.verdict())


func _profile(won: bool):
	var p := Profile.new("user://start_card_pointer_test/unused.json")
	p.load_profile()
	p.can_save = false
	if won:
		p.earn("first_win", 1.0)
	return p


# A new run at stage 1 with the card up, played as a human from here on.
func _begin(won: bool) -> void:
	game.ctx.profile = _profile(won)
	game.ctx.calm = true
	game.flow._begin_run(ClassDef.all()[0])
	game.test_mode = false
	game.bot_driven = false
	game.flow.show_start_card()
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)


func _key(code: int) -> InputEventKey:
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = code
	key.physical_keycode = code
	return key


func _click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	# Off the card (it spans the top band): where a player clicks to take the camera.
	click.position = Vector2(800.0, 700.0)
	click.global_position = click.position
	return click


func _motion() -> InputEventMouseMotion:
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(60.0, 0.0)
	move.position = Vector2(860.0, 700.0)
	move.global_position = move.position
	return move


func _fresh() -> void:
	await _begin(false)
	var card = game.flow.start_card
	t.check("fresh: the card is up and wants no pointer", card.showing() and not card.wants_pointer())
	t.check("fresh: the card holds no menu", not game.get_meta("menu_held", false))
	game.captured = false
	await _send(_click())
	t.check("fresh: a click takes the camera with the card up", game.captured)
	var yaw: float = game.camera.yaw
	await _send(_motion())
	t.check("fresh: mouse motion turns the camera with the card up", not is_equal_approx(game.camera.yaw, yaw), "yaw %.4f -> %.4f" % [yaw, game.camera.yaw])
	var menu = game.get_node_or_null("PauseMenu")
	t.check("fresh: the pause menu exists", menu != null)
	await _send(_key(KEY_ESCAPE))
	t.check("fresh: Esc opens the pause menu over the card", menu != null and menu.is_open() and card.showing())
	await _send(_key(KEY_1))
	t.check("fresh: 1 under the pause menu takes nothing", String(game.run.start_pick.get("taken", "")) == "" and card.showing())
	if menu != null and menu.is_open():
		menu.close()
		await _frames(2)
	t.check("fresh: the pause menu closes", menu != null and not menu.is_open())
	var first: String = String(game.run.start_pick_options()[0])
	await _send(_key(KEY_1))
	t.eq("fresh: 1 takes the first pick", String(game.run.start_pick.get("taken", "")), first)
	t.check("fresh: the card goes and look stays", not card.showing() and game.captured)


func _pad(button: int) -> InputEventJoypadButton:
	var press := InputEventJoypadButton.new()
	press.pressed = true
	press.button_index = button
	return press


func _counter() -> void:
	await _begin(false)
	var card = game.flow.start_card
	var ws = game.get_node("Workshop")
	ws.armed = true
	game.build.shop.enter()
	await _frames(2)
	for leave in [["Esc", _key(KEY_ESCAPE)], ["pad B", _pad(JOY_BUTTON_B)]]:
		ws.open_counter()
		await _frames(2)
		t.check("counter: it opens with the start card up (%s)" % leave[0], ws.counter.is_open() and card.showing())
		await _send(leave[1])
		t.check("counter: %s leaves it with the pick untaken" % leave[0], not ws.counter.is_open())
		t.eq("counter: %s quits nothing" % leave[0], game.quits, 0)
	# Moss's tree pick, opened from the counter's plate: the card keeps its keys over it, as it
	# does over any tree pick (run_tier_test), so V rerolls and no tree pick is taken.
	ws.open_counter()
	await _frames(2)
	var tree = ws.tree()
	var nodes: Array = tree.offered(tree.class_id, 1) if tree != null else []
	t.check("counter: the class tree offers a first pick", nodes.size() == 2)
	if nodes.size() == 2:
		var rerolls: int = card.rerolls_left()
		var picks: Array = game.player.tree.picks.duplicate()
		ws.pick.open(tree.class_id, 1, nodes, tree.path(), Color.WHITE)
		await _frames(2)
		await _send(_key(KEY_V))
		t.check("counter: V under the tree pick rerolls the start card", card.rerolls_left() == rerolls - 1 and card.showing())
		var first: String = String(game.run.start_pick_options()[0])
		await _send(_key(KEY_1))
		t.eq("counter: 1 under the tree pick takes the first start pick", String(game.run.start_pick.get("taken", "")), first)
		t.check("counter: 1 under the tree pick takes no tree pick", game.player.tree.picks == picks)
		ws.close_pick()
		ws.close_counter()
		await _frames(2)
	game.build.shop.leave()
	ws.armed = false
	await _frames(2)


func _rung() -> void:
	game.test_mode = true
	await _begin(true)
	var card = game.flow.start_card
	t.check("rung: the open tier wants the pointer", card.showing() and card.wants_pointer())
	t.check("rung: the cursor is free and the menu held", not game.captured and game.get_meta("menu_held", false))
	await _send(_click())
	t.check("rung: a click does not take the cursor from the card", not game.captured)
	var yaw: float = game.camera.yaw
	await _send(_motion())
	t.check("rung: the free cursor does not turn the camera", is_equal_approx(game.camera.yaw, yaw))
	var ws = game.get_node("Workshop")
	ws.armed = true
	game.build.shop.enter()
	await _frames(2)
	ws.open_counter()
	await _frames(2)
	var grabs: int = game.grabs
	await _send(_key(KEY_ESCAPE))
	t.check("rung: Esc leaves the counter", not ws.counter.is_open())
	t.check("rung: leaving the counter keeps the cursor free for the tier", not game.captured and game.get_meta("menu_held", false) and card.wants_pointer())
	t.eq("rung: leaving the counter never grabs the cursor, even for a frame", game.grabs, grabs)
	game.build.shop.leave()
	ws.armed = false
	await _frames(2)
	var menu = game.get_node("PauseMenu")
	for toggle in [["Esc", _key(KEY_ESCAPE)], ["P", _key(KEY_P)], ["pad Start", _pad(JOY_BUTTON_START)]]:
		grabs = game.grabs
		await _send(toggle[1])
		t.check("rung: %s opens the pause menu over the tier choice" % toggle[0], menu.is_open() and card.showing() and card.wants_pointer())
		t.check("rung: the pause menu holds the tree (%s)" % toggle[0], paused and game.pause_toggled())
		await _send(_key(KEY_1))
		t.check("rung: 1 under the pause menu takes nothing (%s)" % toggle[0], String(game.run.start_pick.get("taken", "")) == "" and card.showing())
		await _send(toggle[1])
		t.check("rung: %s closes the pause menu" % toggle[0], not menu.is_open() and not paused)
		t.check("rung: closing the pause menu leaves the cursor free for the tier (%s)" % toggle[0],
			not game.captured and game.get_meta("menu_held", false) and card.wants_pointer())
		t.eq("rung: pause over the tier never grabs the cursor (%s)" % toggle[0], game.grabs, grabs)
	t.eq("rung: pausing over the tier quits nothing", game.quits, 0)
	# A click on a tier button with pause open: pause's root takes it, and the card's route refuses a press
	# that gets through anyway; Next rung steps nothing under it either.
	var tier_button: Button = card._tier_buttons.get(1)
	t.check("rung: the card shows a Tier 1 button", tier_button != null)
	if tier_button != null:
		await _send(_key(KEY_P))
		t.check("rung: P opens the pause menu for the tier click", menu.is_open())
		var at := tier_button.get_global_rect().get_center()
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = at
		down.global_position = at
		var up := down.duplicate()
		up.pressed = false
		await _send(down)
		await _send(up)
		t.eq("rung: a real click on a tier under the pause menu reaches nothing", game.run.selected_run_tier(), 0)
		tier_button.pressed.emit()
		await _frames(2)
		t.eq("rung: a tier click under the pause menu changes nothing", game.run.selected_run_tier(), 0)
		# Rung 2 open, so Next rung has somewhere to step; it is set back before the pause closes.
		game.ctx.profile.set_stat("hard_ladder_best", 1.0)
		var shown: int = card.shown_rung()
		card.step_rung()
		t.eq("rung: Next rung under the pause menu steps nothing", card.shown_rung(), shown)
		game.ctx.profile.set_stat("hard_ladder_best", 0.0)
		await _send(_key(KEY_P))
		t.check("rung: pause closed again", not menu.is_open())
	ws.armed = true
	game.build.shop.enter()
	await _frames(2)
	ws.open_counter()
	await _frames(2)
	await _send(_key(KEY_P))
	t.check("rung: P at Moss's counter still opens no pause menu", not menu.is_open() and ws.counter.is_open())
	ws.close_counter()
	game.build.shop.leave()
	ws.armed = false
	await _frames(2)
	game.flow._engage()
	await _frames(2)
	t.check("rung: engaging stage 1's Warden closes the tier, the card stays", not game.run.run_tier_open() and card.showing() and not card.wants_pointer())
	t.check("rung: look comes back", game.captured and not game.get_meta("menu_held", false))
	yaw = game.camera.yaw
	await _send(_motion())
	t.check("rung: mouse motion turns the camera again", not is_equal_approx(game.camera.yaw, yaw))
	game.test_mode = true


func _summary() -> void:
	await _begin(false)
	var quits: int = game.quits
	game.flow._end_run(false)
	await _frames(3)
	t.eq("summary: a lost run ends on the summary", game.flow.state_name(), "summary")
	game.summary_latched = true
	await _send(_key(KEY_ESCAPE))
	t.eq("summary: Esc under the input latch stays on the summary", game.flow.state_name(), "summary")
	game.summary_latched = false
	await _send(_key(KEY_ESCAPE))
	t.eq("summary: Esc quits nothing", game.quits, quits)
	t.check("summary: Esc lands on the title with the camp open, as K does",
		game.flow.state_name() == "title" and game.screens.camp_open(), game.flow.state_name())
	await _send(_key(KEY_ESCAPE))
	t.check("summary: a second Esc leaves the camp for the title", game.flow.state_name() == "title" and not game.screens.camp_open())
	t.eq("summary: and still quits nothing", game.quits, quits)
	game.test_mode = true
