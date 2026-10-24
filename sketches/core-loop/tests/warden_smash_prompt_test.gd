extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const KeyGlyphs := preload("res://src/ui/key_glyphs.gd")
const T := preload("res://tests/support/t.gd")

# Codex review w18 (feel #1): on a Warden line the haul prompt read SMASH while Ctrl did nothing
# until the Warden staggered. Through a real Game and a real Warden line: before the stagger the
# haul is not ready, the HUD's view of the ball says so, and a Ctrl press is refused out loud
# (verb_failed "unstaggered") with the line still latched; the SMASH prompt is drawn within a few
# ticks of the stagger opening (the stand wait ran while the line stood, and the early press does
# not restart it); inside the stagger the same press commits the smash. A Ctrl on a stake line
# is refused with its own reason, "stake".

var _t := T.new("warden_smash_prompt_test")
var _game
var _player
var _warden
var _source := Intent.Scripted.new()
var _fails: Array = []


class FakeStake extends StaticBody3D:
	func anchor_point(point: Vector3, _from = null) -> Vector3:
		return point
	func anchor_velocity() -> Vector3:
		return Vector3.ZERO


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _press_ctrl() -> void:
	_source.hold = {"harpoon_held": true, "brake_held": true}
	await _frames(2)
	_source.hold = {"harpoon_held": true}
	await _frames(1)


func _haul_ready() -> Array:
	return [_player.verb_ready("haul"), bool(KeyGlyphs.view_of(_player)["ready"]["haul"])]


func _bite() -> void:
	_player.reset_to(_game.ctx.terrain.drop_point(_warden.global_position.x + 14.0, _warden.global_position.z, 1.5))
	_source.hold = {"harpoon_held": true}
	await _frames(3)
	_player.grapple_to(_warden.global_position + Vector3.UP * 2.0, Vector3.UP, _warden)
	await _frames(2)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_player = _game.player
	_player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(24)
	_game.run.set_max_hp(99999.0)
	_warden = _game.flow.warden
	if not is_instance_valid(_warden):
		print("warden_smash_prompt_test: FAIL (no Warden on the slice table)")
		quit(1)
		return
	for enemy in get_nodes_in_group("enemy"):
		if enemy != _warden and enemy.get("kind") != "vault":
			enemy.queue_free()
	_warden.set_harpoon_anchor(true)
	_game.events.verb_failed.connect(func(verb: String, reason: String, _at: Vector3): _fails.append([verb, reason]))
	var kit = _player.kit

	await _bite()
	await _frames(150)
	_t.check("a Warden line stands", kit.hooked and kit.on_body and Augments.anchor_line(kit.anchor_body)
		and kit.line_state == Augments.LINE_LATCHED, "hooked %s state %s" % [kit.hooked, kit.line_state])
	_t.check("the Warden is not staggered", not _warden.staggered())
	_t.eq("no smash before the stagger: player and prompt view", _haul_ready(), [false, false])
	_fails.clear()
	await _press_ctrl()
	_t.check("Ctrl before the stagger is refused out loud", _fails.has(["haul", "unstaggered"]), str(_fails))
	_t.eq("the line holds latched", kit.line_state, Augments.LINE_LATCHED)

	_t.check("no SMASH drawn before the stagger", not _game.hud.key_glyphs.shown_verbs().has("haul"),
		str(_game.hud.key_glyphs.shown_verbs()))
	_warden._posture.staggered = true
	_warden._posture.stagger_left = 5.0
	await _frames(1)
	_t.check("the Warden is staggered", _warden.staggered())
	var drawn_at := -1
	for i in 6:
		if _game.hud.key_glyphs.shown_verbs().has("haul"):
			drawn_at = i
			break
		await _frames(1)
	_t.check("SMASH is drawn as the stagger opens", drawn_at >= 0, "tick %d of 6" % drawn_at)
	_t.eq("inside the stagger the smash is ready: player and prompt view", _haul_ready(), [true, true])
	_fails.clear()
	await _press_ctrl()
	_t.check("Ctrl inside the stagger commits the smash", kit.line_state == Augments.LINE_SMASH or not kit.hooked,
		"state %s hooked %s" % [kit.line_state, kit.hooked])
	_t.check("and is not refused", not _fails.has(["haul", "unstaggered"]), str(_fails))
	await _frames(240)
	_source.hold = {}
	await _frames(10)

	var stake := FakeStake.new()
	stake.add_to_group(Augments.STAKE_GROUP)
	stake.add_to_group(Augments.ANCHOR_GROUP)
	_game.add_child(stake)
	_player.reset_to(_game.ctx.terrain.drop_point(_warden.global_position.x + 40.0, _warden.global_position.z, 1.5))
	stake.global_position = _player.ball_position() + Vector3(6.0, 1.0, 0.0)
	_source.hold = {"harpoon_held": true}
	await _frames(3)
	_player.grapple_to(stake.global_position, Vector3.UP, stake)
	await _frames(2)
	_t.check("a stake line stands", kit.hooked and kit.anchor_body == stake, "hooked %s" % kit.hooked)
	_t.eq("no smash on a stake line", _haul_ready(), [false, false])
	_fails.clear()
	await _press_ctrl()
	_t.check("Ctrl on a stake line is refused as a stake", _fails.has(["haul", "stake"]), str(_fails))
	_game.free()
	quit(_t.verdict())
