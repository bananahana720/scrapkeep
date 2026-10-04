# smoke: solo (a skipper bot fights a world 2 stub boss; reads simulated time against a 120 s cap)
extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# A boss with no ship is the stub's one posture Warden on a flat pad (stub_boss.gd). The bot
# driver fights it with its stage Warden routine. The run starts normally, then jumps to the
# last stage of world 2 and enters its arena; the flow must leave the boss state with the
# module defeated inside the budget.
#
# Evidence limit: one seed and one class, entered with a placed ball; it says nothing about
# Brindle or about feel.

const SEED := 1
const JUMP_STAGE := 4
const BUDGET_SECONDS := 120
const TICK_LIMIT := BUDGET_SECONDS * 90

var _game
var _driver
var _t := T.new("bot_posture_boss_test")
var _ticks := 0
var _entered := false
var _module
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", SEED)
		_driver.start()
		return false
	if not _entered:
		if _game.flow.state_name() == "stage" and _game.run.stage == 1:
			_game.flow.enter_stage(JUMP_STAGE, Vector3(0.0, 0.0, 14.0), false)
			_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
			_module = _game.ctx.boss
			_entered = true
		else:
			_driver.tick(delta)
			return false
	_ticks += 1
	var over: bool = _driver.tick(delta)
	if over or _game.flow.state_name() != "boss" or _ticks > TICK_LIMIT:
		return _finish()
	return false


func _finish() -> bool:
	_done = true
	var seconds := float(_ticks) / float(Engine.physics_ticks_per_second)
	var left: bool = _game.flow.state_name() != "boss"
	_t.check("module is a ship-less stub", _module != null and _module.get("ship") == null,
		"boss module %s, ship %s" % [_module, _module.get("ship") if _module != null else "n/a"])
	_t.check("flow left the boss", left, "state %s after %.1f s of a %d s budget (bot outcome '%s')"
		% [_game.flow.state_name(), seconds, BUDGET_SECONDS, _driver.outcome])
	_t.check("module victorious", _module != null and _module.state == _module.DEFEATED, "module state %s, want %s"
		% [_module.state if _module != null else "n/a", _module.DEFEATED if _module != null else "n/a"])
	_game.free()
	quit(_t.verdict())
	return true
