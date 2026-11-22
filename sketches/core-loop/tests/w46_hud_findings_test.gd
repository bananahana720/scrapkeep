extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Hud := preload("res://src/ui/hud.gd")
const RadioDial := preload("res://src/ui/radio_dial.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const T := preload("res://tests/support/t.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# Sable's mount wall stands beside the open spot where E found nothing, its face 1.5 times the base reach out.
const WALL_OUT := Tuning.RADIUS + Augments.FACE_REACH * 1.5 + 0.5

# W46-10, the HUD findings, on a real game in play. Keys go in as real input events (the game's input
# path, the keyboard source, Moss's bubble's own listener), as a player presses them.
#   MG-10  Ctrl with no line on a ball at rest, and E with nothing in reach, are refused on the tick
#          of the press (verb_failed haul/no_line and interact/nothing, the sounds that already exist),
#          once for a key held down, and the Ctrl chip shakes. Not refused: Ctrl on a rolling ball (the
#          brake) or in the air (the slam every pilot carries); E on each line of Moss's exchange, the
#          press that closes its last line and the press that closes an intro (the bubble clears itself
#          before the ball reads the key); E where Sable's doubled mount reach plants her at 1.5 times
#          the base reach. Refused: E with nothing in reach while a call-in talks or a
#          bark is up (neither reads E), and E at 1.5 times the base reach without the upgrade (the
#          control for the wall's place). The run's opening and Moss's stage 1 hello are put away
#          before any key goes in (MossBubble.stand_down).
#   PF-21  the bar points at the slot a tip names: the active's tip names the active's chip, and a
#          chevron stands over that chip; a slot the bar does not hold points at nothing.
#   PF-19  the radio chip folds to its knob and bars once its words have stood PEEK seconds, opens
#          again when it swells, and every line it draws is cut to the plate with an ellipsis.

var _t := T.new("w46_hud_findings_test")
var _fails: Array = []
var _game
var _wall: StaticBody3D
# Where E with nothing in reach was refused: open ground with no face in reach.
var _open_at := Vector3.INF


func _initialize() -> void:
	_run.call_deferred()


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	_pure()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.player.source = Intent.Keyboard.new()
	_game.run.set_max_hp(99999.0)
	_game.events.verb_failed.connect(func(verb: String, reason: String, _at: Vector3): _fails.append([verb, reason]))
	await _physics(90)
	await _quiet()
	await _refusals()
	# Sable's reach is read while nothing speaks, so only her reach can keep E from being refused.
	await _sable_reach()
	await _talk()
	_pointer()
	await _radio()
	quit(_t.verdict())


func _pure() -> void:
	var width := 120.0
	var long := "New signal: the longest track the band ever cut"
	var cut := RadioDial.fit(long, width, UiTokens.CAPTION)
	_t.check("a line too long for the plate is cut with an ellipsis and fits", cut.ends_with(RadioDial.ELLIPSIS)
		and UiFonts.width(cut, UiTokens.CAPTION) <= width and cut.length() < long.length(), cut)
	_t.eq("a line that fits stays whole", RadioDial.fit("Live", width, UiTokens.CAPTION), "Live")
	var slots := [{"id": "blaster", "slot": "weapon"}, {"id": "active_scrap_rocket", "group": "chip"}]
	_t.eq("the active's tip names the active's chip", Hud.tip_slot("active", slots), "active_scrap_rocket")
	_t.eq("a tip that names no slot points at nothing", Hud.tip_slot("jam", slots), "")
	_t.eq("no active racked, the active's tip points at nothing", Hud.tip_slot("active", slots.slice(0, 1)), "")


# Rests the ball where it is and waits until it is on the ground again, at most 40 ticks.
func _rest() -> bool:
	var player = _game.player
	player.reset_to(player.ball_position(), Vector3.ZERO)
	for i in 40:
		await physics_frame
		if player.state.grounded:
			player.reset_to(player.ball_position(), Vector3.ZERO)
			await physics_frame
			return player.state.grounded
	return false


func _act(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


# Presses `action` as a player does, holds it `ticks` physics ticks and lets go: the refusals heard.
func _press(action: String, ticks := 1) -> Array:
	_fails.clear()
	_act(action, true)
	await _physics(ticks)
	_act(action, false)
	await _physics(3)
	return _fails.duplicate()


func _count(fails: Array, row: Array) -> int:
	return fails.filter(func(f): return f == row).size()


func _refusals() -> void:
	var player = _game.player
	var hud = _game.hud
	var grounded: bool = await _rest()
	var ctrl: Array = await _press("cl_haul", 12)
	_t.check("Ctrl with no line on a ball at rest is refused, once for a key held 12 ticks", grounded and _count(ctrl, ["haul", "no_line"]) == 1,
		"grounded %s, speed %.2f, fails %s" % [grounded, player.planar_velocity().length(), ctrl])
	_t.check("and the Ctrl chip shakes", hud.ability_bar.flash_color("smash").a > 0.0)
	await _physics(30)

	await _rest()
	var forward: Vector3 = -_game.camera.cam.global_basis.z
	forward.y = 0.0
	player.reset_to(player.ball_position(), forward.normalized() * 10.0)
	await physics_frame
	var rolling: Array = await _press("cl_haul")
	_t.check("not refused: Ctrl on a rolling ball brakes", _count(rolling, ["haul", "no_line"]) == 0,
		"speed %.2f, fails %s" % [player.planar_velocity().length(), rolling])
	await _physics(30)

	await _rest()
	player.reset_to(player.ball_position() + Vector3.UP * 8.0, Vector3.ZERO)
	await _physics(3)
	var airborne: bool = not player.state.grounded and player.kit.on(Augments.SLAM)
	var air: Array = await _press("cl_haul")
	_t.check("not refused: Ctrl in the air starts the slam", airborne and _count(air, ["haul", "no_line"]) == 0,
		"airborne with slam %s, fails %s" % [airborne, air])
	await _physics(120)

	await _rest()
	_open_at = player.ball_position()
	var e: Array = await _press("cl_interact", 12)
	_t.check("E with nothing in reach is refused, once for a key held 12 ticks", _count(e, ["interact", "nothing"]) == 1, str(e))


func _bubble():
	return _game.get_node("Workshop").bubble


# The run's opening, its cold open card and Moss's stage 1 hello are put away before any key goes
# in: a key would skip the cold open and bring the hello up, and E would then be the hello's.
func _quiet() -> void:
	var presentation = _game.presentation
	_game.opening.finish()
	if presentation != null:
		presentation.flourish.stop_all()
	var bubble = _bubble()
	bubble.stand_down()
	var settled := func(): return not bubble.takes_interact() and not bubble.showing() and (presentation == null or not presentation.reading())
	var quiet: bool = await _until(settled)
	_t.check("the opening and Moss's hello are put away before any key goes in", quiet and not _game.opening.live)


func _until(condition: Callable, ticks := 180) -> bool:
	for i in ticks:
		if condition.call():
			return true
		await physics_frame
	return condition.call()


# Moss's bubble, live: an exchange pressed through to its end, a boss's intro closed with E, a call-in and a bark.
func _talk() -> void:
	var bubble = _bubble()
	await _rest()
	bubble._zones_played.clear()
	bubble._begin_exchange(_game.run.stage)
	var up: bool = await _until(func(): return not bubble._exchange.is_empty() and bubble.showing())
	var lines: int = bubble._exchange.size()
	var heard: Array = []
	var presses := 0
	while not bubble._exchange.is_empty() and presses < lines + 2:
		heard.append_array(await _press("cl_interact"))
		presses += 1
	_t.check("not refused: E on each of the exchange's lines, the last one closing it", up and lines >= 2 and presses == lines
		and bubble._exchange.is_empty() and not bubble.showing() and _count(heard, ["interact", "nothing"]) == 0,
		"up %s, lines %d, presses %d, fails %s" % [up, lines, presses, heard])

	await _rest()
	bubble._queue_intro("1-1", false)
	var intro: bool = await _until(func(): return bubble._intro_showing and bubble.showing())
	var closed: Array = await _press("cl_interact")
	_t.check("not refused: E that closes a boss's intro line", intro and not bubble._intro_showing and _count(closed, ["interact", "nothing"]) == 0,
		"intro up %s, fails %s" % [intro, closed])

	await _rest()
	var caller: Dictionary = bubble.call_caused("evolution_fired", [])
	var calling: bool = await _until(func(): return bubble.mood == "call" and bubble.showing())
	var call: Array = await _press("cl_interact")
	_t.check("refused: E with nothing in reach while a call-in talks (it never reads E)", calling
		and _count(call, ["interact", "nothing"]) == 1, "call %s, up %s, fails %s" % [caller.get("id", ""), calling, call])
	bubble.hush()
	await _until(func(): return not bubble.showing())

	await _rest()
	bubble.bark({"text": "Mind the sluice."}, "shop_bought")
	var barking: bool = await _until(func(): return bubble.showing())
	var bark: Array = await _press("cl_interact")
	_t.check("refused: E with nothing in reach while a bark is up (it never reads E)", barking
		and _count(bark, ["interact", "nothing"]) == 1, "up %s, fails %s" % [barking, bark])
	bubble.hush()


# Sable at a wall whose face is 1.5 times the base reach out, on the open spot where E found nothing: E plants her with the doubled reach
# (s_beachhead, mount_reach 2.0) and is not refused; without it E does nothing and is refused.
func _sable_reach() -> void:
	var player = _game.player
	var def: Resource = ClassDef.by_id("pylon_engineer")
	_game.run.class_def = def
	player.fit_class(def)
	_wall = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 40.0, 40.0)
	shape.shape = box
	_wall.add_child(shape)
	_wall.collision_layer = 1
	_game.ctx.root.add_child(_wall)
	var quiet: bool = await _until(func(): return not _bubble().showing())
	_t.check("nothing speaks while Sable's reach is read", quiet)
	for doubled in [false, true]:
		_game.ctx.tuning.set_option("world_one_builds", "on")
		var tree = player.tree
		tree.reset("pylon_engineer")
		tree.max_depth = 2
		tree.world_one = true
		if doubled:
			tree.open_checkpoint()
			tree.pick("s_beachhead")
		player.kit.mounted = false
		player.kit.mount_block = 0.0
		player.reset_to(_open_at, Vector3.ZERO)
		await _physics(2)
		player.reset_to(player.ball_position(), Vector3.ZERO)
		_wall.global_position = player.ball_position() + Vector3(WALL_OUT, 0.0, 0.0)
		await physics_frame
		var reach: float = tree.knob("mount_reach")
		var where := "ball %s, face in the ball's reach %s" % [player.ball_position(), player.face_in_reach()]
		var fails: Array = await _press("cl_interact")
		var mounted: bool = player.kit.mounted
		if doubled:
			_t.check("not refused: E at 1.5 times the base reach plants Sable with the doubled reach", is_equal_approx(reach, 2.0) and mounted
				and _count(fails, ["interact", "nothing"]) == 0, "reach %.1f, mounted %s, fails %s, %s" % [reach, mounted, fails, where])
		else:
			_t.check("control: at base reach the same wall is out of reach, and E is refused", is_equal_approx(reach, 1.0) and not mounted
				and _count(fails, ["interact", "nothing"]) == 1, "reach %.1f, mounted %s, fails %s, %s" % [reach, mounted, fails, where])
		player.kit.mounted = false
	_wall.queue_free()
	player.reset_to(_open_at, Vector3.ZERO)
	await _physics(30)


func _pointer() -> void:
	var bar = _game.hud.ability_bar
	var rects: Dictionary = bar.slot_rects()
	bar.point_at("line")
	var rect: Rect2 = bar.pointer_rect()
	var slot: Rect2 = rects.get("line", Rect2())
	_t.check("a named slot wears the chevron over it", rect.has_area() and slot.has_area() and rect.end.y <= slot.position.y
		and absf(rect.get_center().x - slot.get_center().x) < 0.5, "pointer %s slot %s" % [rect, slot])
	bar.point_at("no_such_slot")
	_t.check("a slot the bar does not hold points at nothing", not bar.pointer_rect().has_area())
	bar.point_at("")


func _radio() -> void:
	var dial = _game.radio_deck.dial
	var waited := 0.0
	while dial.says() and waited < RadioDial.PEEK + RadioDial.SWELL + 2.0:
		await process_frame
		waited += _game.get_process_delta_time()
	_t.check("the chip folds to its knob and bars once its words have stood", not dial.says() and dial.target_size() == RadioDial.FOLDED,
		"says %s after %.2f s, target %s" % [dial.says(), waited, dial.target_size()])
	dial.swell()
	_t.check("a swell opens it with its words", dial.says() and dial.target_size() == RadioDial.SWOLLEN)
