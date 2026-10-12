# 2026-10-12 (PC-SABLE round 4): Pin 22 checks for bite, haul and Bank Shot order.
extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Augments := preload("res://src/movement/augments.gd")
const T := preload("res://tests/support/t.gd")
const EXPECTED_CHECKS := 22
const DT := 1.0 / 90.0

var _t := T.new("sable_bot_hands_test")
var _game
var _player
var _driver
var _casts: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _never() -> bool:
	return false


func _fresh(line_id: String) -> void:
	_player.kit.drop_line("reset")
	_player.kit.rewind_left = 0.0
	_player.chain.reset()
	_player.abilities.swap(AbilityState.LINE, line_id)
	_player.abilities.refill()
	_player.abilities.snap_back("test")
	_player._fire_latched = false
	_player._brake_was_held = false
	_player.set_velocity_now(Vector3.RIGHT * 20.0)
	_player.state.grounded = true
	_game.combat._line_load = {}
	_game.combat._bite_pending = false
	_driver = BotDriver.new(_game, "skipper", 0)
	_driver._off_line = BotDriver.DROP_MEMORY + DT
	_player.source = _driver.source
	_casts.clear()


# Use the same order as _ram_laps, _act and _drive, then the real player/router/combat.
func _hand(target: Node3D) -> void:
	_driver.source.press.clear()
	_driver.source.hold.clear()
	_driver._harpoon_hand(target, DT)
	_driver._line_hands()
	if _driver._harpoon_held:
		_driver.source.hold["harpoon_held"] = true
	if _driver._harpoon_commit:
		_driver.source.hold["brake_held"] = true
	_driver._cast_hands()
	_driver.source.poll(_player.intent)
	_player._route_slots(DT)


func _consume() -> void:
	_player._read_grammar()
	_game.combat._step_line(_player.intent, DT)


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_player = _game.player
	for i in 36:
		await physics_frame
	_player.set_physics_process(false)
	_game.combat.set_physics_process(false)
	_game.combat.ultimate.set_physics_process(false)
	_game.events.slot_cast.connect(func(slot: String, _id: String, _at: Vector3):
		if slot == AbilityState.LINE:
			_casts.append(_player.kit.line_state))
	var target: Node3D = _game.combat.spawn_enemy("chaser", _player.ball_position() + Vector3(9.0, 1.0, 0.0))
	target.live = _never
	target.hp = 5000.0
	target.max_hp = 5000.0
	_fresh("bank_shot")
	_t.eq("Bank Shot equipped through AbilityState", _player.abilities.id_of(AbilityState.LINE), "bank_shot")
	_player.kit.aim = {"state": Augments.AIM_BODY, "body": target, "point": target.global_position, "normal": Vector3.LEFT}
	_hand(target)
	_t.check("planned body bite presses RMB", _player.intent.harpoon_pressed)
	_t.check("planned body bite does not cast slot 3", not _player.intent.line_pressed)
	_consume()
	_t.check("plain bite keeps its body line", _player.kit.hooked and _player.kit.on_body)
	_t.eq("no Bank Shot cast before haul", _casts, [])
	_player._brake_was_held = true
	_hand(target)
	_t.check("held Ctrl must come up before the haul", not _driver._harpoon_commit)
	_t.check("standing-line hand cannot bank on the Ctrl release tick", not _player.intent.line_pressed)
	_consume()
	_t.eq("Ctrl release leaves the latch intact", _player.kit.line_state, Augments.LINE_LATCHED)
	_hand(target)
	_t.check("next tick presses Ctrl", _driver._harpoon_commit)
	_t.check("Bank Shot waits until the smash is observed", not _player.intent.line_pressed)
	_consume()
	_t.eq("real Ctrl grammar commits the smash", _player.kit.line_state, Augments.LINE_SMASH)
	_hand(target)
	_t.check("observed smash casts Bank Shot", _player.intent.line_pressed)
	_consume()
	_t.eq("every Bank Shot cast sees a committed smash", _casts, [Augments.LINE_SMASH])
	_t.check("Bank Shot leaves the committed haul standing", _player.kit.hooked and not _player._bank_pending.is_empty())
	_t.check("real landing consumes the committed line", _player._begin_landing(target))
	_player._finish_landing(target, 20.0)
	_t.check("landing pays the deferred Bank Shot exit", _player._bank_pending.is_empty() and _player.kit.line_end == "bank")
	_fresh("bank_shot")
	_player.grapple_to(target.global_position, Vector3.LEFT, target)
	_hand(target)
	_player.kit.drop_line("snip")
	_hand(target)
	_t.eq("a cut clears the waiting cast", _driver._cast_phase, "")
	_t.check("a special can cast after the cut", _driver._cast(2))
	for id in ["line_reel", "claw_drag", "link_clips"]:
		_fresh(id)
		_player.kit.aim = {"state": Augments.AIM_BODY, "body": target, "point": target.global_position, "normal": Vector3.LEFT}
		_hand(target)
		_t.check("%s still loads slot 3 on its planned bite" % id, _player.intent.line_pressed and _player.intent.harpoon_pressed)
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())
