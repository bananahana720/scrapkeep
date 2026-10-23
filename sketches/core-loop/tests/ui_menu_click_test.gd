extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# Menus take the mouse (playtest entry 7). Real mouse events pushed into the viewport:
#   - hovering the title's start button lights it, and clicking it opens class select;
#   - class select shows one card per class, and clicking the second starts that class;
#   - the death screen ignores a click in its first beat (a held fire button), then a
#     click on retry puts the ball back in the stage;
#   - the keys still work beside the buttons.

var _game
var _failures := 0
var _phase := "boot"
var _wait := 0
var _clock := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	_clock += delta
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.ctx.profile.unlock_pilot(_game.flow.classes[1].id)
			_game.player.source = Intent.Scripted.new()
			_phase = "title"
			_wait = 0
		"title":
			if _wait == 30:
				var start: Button = _game.screens.button_for("start")
				_hover(start)
				var lit: bool = start != null and start.is_hovered()
				_click(start)
				_report("title start", lit and _game.flow.state_name() == "class_select",
					"hovered %s; after the click the flow is %s" % [lit, _game.flow.state_name()])
				_phase = "class"
				_wait = 0
		"class":
			if _wait == 30:
				var cards: Array = _game.screens.class_cards()
				_click(cards[1] if cards.size() > 1 else null)
				_report("class card", cards.size() == _game.flow.classes.size() and _game.flow.in_play()
						and _game.run.class_def != null and _game.run.class_def.id == _game.flow.classes[1].id,
					"%d cards for %d classes; the second card's click started %s"
						% [cards.size(), _game.flow.classes.size(), _game.run.class_def.id if _game.run.class_def != null else "nothing"])
				_phase = "die"
				_wait = 0
		"die":
			if _wait == 10:
				_game.run.damage(99999.0, "test")
				_click(_game.screens.button_for("new"))
				_report("death guard", _game.flow.state_name() == "dead",
					"a click in the death screen's first beat leaves the flow at %s" % _game.flow.state_name())
				_phase = "retry"
				_wait = 0
				_clock = 0.0
		"retry":
			if _clock >= 0.8 and _wait > 1:
				var gone: bool = _game.screens.button_for("retry") == null
				var before_id: String = _game.run.run_id
				_click(_game.screens.button_for("new"))
				_report("new run click", gone and _game.flow.in_play() and _game.run.run_id != before_id,
					"after the beat, no retry button (%s); clicking New run puts the flow at %s (run %s to %s)" % [gone, _game.flow.state_name(), before_id, _game.run.run_id])
				_game.run.damage(99999.0, "test")
				_phase = "keys"
				_wait = 0
		"keys":
			if _wait == 60:
				var handled: bool = _game._screen_key(KEY_C)
				_report("keys kept", handled and _game.flow.state_name() == "class_select",
					"C on the death screen opens %s" % _game.flow.state_name())
				print("ui_menu_click_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _hover(control: Control) -> void:
	if control == null:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)


func _click(control: Control) -> void:
	if control == null:
		return
	_hover(control)
	var at := control.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = at
	down.global_position = at
	root.push_input(down, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	up.global_position = at
	root.push_input(up, true)
