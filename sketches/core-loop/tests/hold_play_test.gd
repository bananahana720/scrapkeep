extends SceneTree

const T := preload("res://tests/support/t.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Intent := preload("res://src/movement/intent.gd")
const RewardCeremony := preload("res://src/presentation/reward_ceremony.gd")
const Workshop := preload("res://src/ui/workshop.gd")

# Headless cannot capture a mouse, so MouseGame keeps the capture flag game.gd asks for.

class MouseGame extends "res://src/game.gd":
	var captured := true

	func capture_mouse(capture: bool) -> void:
		captured = capture

	func mouse_captured() -> bool:
		return captured


const PLAY_FRAMES := 600

var t := T.new("hold_play_test")
var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = MouseGame.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.flow._begin_run(ClassDef.all()[0])
	var waited := 0
	while not game.flow.in_play() and waited < PLAY_FRAMES:
		await process_frame
		waited += 1
	if not t.check("the run reaches play", game.flow.in_play(), "state %s after %d frames" % [game.flow.state_name(), waited]):
		_finish()
		return
	game.keyboard = Intent.Keyboard.new()
	_ceremony_under_pick()
	_ceremony_over_counter()
	_pause_keys_under_a_hold()
	_flow_change_under_a_hold()
	_repeats_and_strangers()
	_finish()


func _free() -> void:
	game.captured = true
	game.keyboard.enabled = true
	t.check("no hold is left over", not game.menu_held() and not paused, "menu held %s, paused %s" % [game.menu_held(), paused])


func _state() -> String:
	return "paused %s, keyboard %s, mouse captured %s, menu held %s" % [paused, game.keyboard.enabled, game.captured, game.menu_held()]


func _ceremony_under_pick() -> void:
	_free()
	game.player.set_velocity_now(Vector3(4.0, 0.0, 3.0))
	var v0: Vector3 = game.player.body().linear_velocity
	game.hold_play("ceremony", true, RewardCeremony.HOLD)
	t.check("ceremony: holds the tree and the keys, leaves the mouse", paused and not game.keyboard.enabled and game.captured and game.menu_held(), _state())
	game.hold_play("workshop", true, Workshop.PICK_HOLD)
	t.check("pick over the ceremony: frees the mouse too", paused and not game.keyboard.enabled and not game.captured, _state())
	game.player.set_velocity_now(Vector3.ZERO)
	game.hold_play("ceremony", false)
	t.check("the ceremony lets go first: the pick still holds the tree, the keys and the mouse",
		paused and not game.keyboard.enabled and not game.captured and game.menu_held(), _state())
	t.check("and the ball gets its velocity back as the ceremony lets go",
		v0.length() > 0.5 and game.player.body().linear_velocity == v0 and game.player.state.velocity == v0,
		"body %s, state %s, held %s" % [game.player.body().linear_velocity, game.player.state.velocity, v0])
	game.hold_play("workshop", false)
	t.check("the pick lets go last: play resumes", not paused and game.keyboard.enabled and game.captured and not game.menu_held(), _state())


func _ceremony_over_counter() -> void:
	_free()
	game.hold_play("workshop", true, Workshop.COUNTER_HOLD)
	t.check("counter: holds the keys and the mouse, not the tree", not paused and not game.keyboard.enabled and not game.captured, _state())
	game.hold_play("ceremony", true, RewardCeremony.HOLD)
	t.check("ceremony over the counter: holds the tree too", paused and not game.keyboard.enabled and not game.captured, _state())
	game.hold_play("workshop", false)
	t.check("the counter lets go first: the ceremony still holds the tree, the keys and the menu, and the mouse comes back",
		paused and not game.keyboard.enabled and game.captured and game.menu_held(), _state())
	game.hold_play("ceremony", false)
	t.check("the ceremony lets go last: play resumes", not paused and game.keyboard.enabled and game.captured and not game.menu_held(), _state())


func _pause_keys_under_a_hold() -> void:
	_free()
	game.hold_play("ceremony", true, RewardCeremony.HOLD)
	game.toggle_pause()
	game.toggle_pause()
	t.check("pause on and off under the ceremony keeps the tree held", paused and game.menu_held(), _state())
	game.hold_notes(true)
	game.hold_notes(false)
	t.check("notes held and let go under the ceremony keep the tree held", paused, _state())
	game.freeze_for_dev(true)
	game.hold_play("ceremony", false)
	t.check("the dev freeze outlasts the ceremony", paused and game.keyboard.enabled and not game.menu_held(), _state())
	game.freeze_for_dev(false)
	t.check("and lets go after it", not paused, _state())
	game.toggle_pause()
	game.hold_play("workshop", true, Workshop.PICK_HOLD)
	game.toggle_pause()
	t.check("the pause menu closing over the pick keeps the tree held", paused and game.pause_wanted(), _state())
	game.hold_play("workshop", false)
	t.check("the pick letting go resumes play", not paused and not game.pause_wanted(), _state())


func _flow_change_under_a_hold() -> void:
	_free()
	game.hold_play("workshop", true, Workshop.COUNTER_HOLD)
	game._on_flow_changed(game.flow.state_name())
	t.check("a flow change into play leaves a held keyboard and mouse held", not game.keyboard.enabled and not game.captured, _state())
	game.walk_input(true)
	t.check("walk input leaves them held too", not game.keyboard.enabled and not game.captured, _state())
	game.hold_play("workshop", false)
	t.check("letting go gives them back", game.keyboard.enabled and game.captured and not game.menu_held(), _state())
	game.keyboard.walk = false


func _repeats_and_strangers() -> void:
	_free()
	game.hold_play("workshop", true, Workshop.COUNTER_HOLD)
	game.keyboard.enabled = true
	game.hold_play("workshop", true, Workshop.COUNTER_HOLD)
	t.check("holding again with the same effects does nothing", game.keyboard.enabled, _state())
	game.hold_play("workshop", true, Workshop.PICK_HOLD)
	t.check("holding again with more effects adds them", paused, _state())
	game.hold_play("ceremony", false)
	t.check("a holder that never held lets go of nothing", paused and game.menu_held(), _state())
	game.hold_play("workshop", false)
	t.check("the last holder lets go", not paused and not game.menu_held(), _state())


func _finish() -> void:
	paused = false
	game.free()
	quit(t.verdict())
