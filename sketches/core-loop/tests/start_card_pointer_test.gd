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
#   camera, a click does not recapture), and engaging stage 1's Warden gives look back.
# Real pointer capture on a desktop is a hands-on check (alpha-status/sitting-watch-list.md).

class PointerGame extends "res://src/game.gd":
	var captured := false

	func _capture_mouse(capture: bool) -> void:
		captured = capture

	func _mouse_captured() -> bool:
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
	await _rung()
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
	game.flow._engage()
	await _frames(2)
	t.check("rung: engaging stage 1's Warden closes the tier, the card stays", not game.run.run_tier_open() and card.showing() and not card.wants_pointer())
	t.check("rung: look comes back", game.captured and not game.get_meta("menu_held", false))
	yaw = game.camera.yaw
	await _send(_motion())
	t.check("rung: mouse motion turns the camera again", not is_equal_approx(game.camera.yaw, yaw))
	game.test_mode = true
