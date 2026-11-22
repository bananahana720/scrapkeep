extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Hud := preload("res://src/ui/hud.gd")
const RadioDial := preload("res://src/ui/radio_dial.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const T := preload("res://tests/support/t.gd")

# W46-10, the HUD findings, on a real game in play.
#   MG-10  Ctrl with no line on a ball at rest, and E with nothing in reach, are refused on the tick
#          of the press (verb_failed haul/no_line and interact/nothing, the sounds that already exist),
#          and the Ctrl chip shakes. Controls: Ctrl on a rolling ball brakes and is not refused; E while
#          Moss's bubble reads the key (talk_claim) is not refused.
#   PF-21  the bar points at the slot a tip names: the active's tip names the active's chip, and a
#          chevron stands over that chip; a slot the bar does not hold points at nothing.
#   PF-19  the radio chip folds to its knob and bars once its words have stood PEEK seconds, opens
#          again when it swells, and every line it draws is cut to the plate with an ellipsis.

var _t := T.new("w46_hud_findings_test")
var _fails: Array = []
var _game
var _script: Intent.Scripted


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
	_script = Intent.Scripted.new()
	_game.player.source = _script
	_game.run.set_max_hp(99999.0)
	_game.events.verb_failed.connect(func(verb: String, reason: String, _at: Vector3): _fails.append([verb, reason]))
	await _physics(90)
	await _refusals()
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


func _pressed(press: Dictionary) -> Array:
	_fails.clear()
	_script.press = press
	await _physics(2)
	return _fails.duplicate()


func _refusals() -> void:
	var player = _game.player
	var hud = _game.hud
	var grounded: bool = await _rest()
	var ctrl: Array = await _pressed({"brake_held": true})
	_t.check("Ctrl with no line on a ball at rest is refused on the press's tick", grounded and ctrl.has(["haul", "no_line"]),
		"grounded %s, speed %.2f, fails %s" % [grounded, player.planar_velocity().length(), ctrl])
	_t.check("and the Ctrl chip shakes", hud.ability_bar.flash_color("smash").a > 0.0)
	await _physics(30)

	grounded = await _rest()
	var forward: Vector3 = -_game.camera.cam.global_basis.z
	forward.y = 0.0
	player.reset_to(player.ball_position(), forward.normalized() * 10.0)
	await physics_frame
	var rolling: Array = await _pressed({"brake_held": true})
	_t.check("control: Ctrl on a rolling ball brakes and is not refused", not rolling.has(["haul", "no_line"]),
		"speed %.2f, fails %s" % [player.planar_velocity().length(), rolling])
	await _physics(30)

	await _rest()
	var e: Array = await _pressed({"mount_pressed": true})
	_t.check("E with nothing in reach is refused on the press's tick", e.has(["interact", "nothing"]), str(e))
	var claim: Callable = player.talk_claim
	player.talk_claim = func() -> bool: return true
	var talk: Array = await _pressed({"mount_pressed": true})
	player.talk_claim = claim
	_t.check("control: E while the talk bubble reads the key is not refused", not talk.has(["interact", "nothing"]), str(talk))
	_t.check("the HUD wired the talk claim", claim.is_valid())


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
