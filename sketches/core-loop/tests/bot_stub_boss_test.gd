# smoke: solo (world 2 stage entrance, gate and posture boss; 200 s simulated budget)
extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const T := preload("res://tests/support/t.gd")
# 2026-10-05: the Waking (waking.gd) drops a floor per chunk and re-seats the Warden. Sable
# (class 0) breaks it in 150.7 s of boss time, 155.1 s in all, following every drop; 120 s
# predated the floors. bot_posture_boss_test's seed-1 class wins in 87.5 s.
const BUDGET := 200.0

# Only the stage Warden is broken through the spawner seam. The gate, launch and
# boss are driven by ordinary inputs; no test strike ever touches the boss Warden.
var _game
var _driver
var _module
var _t := T.new("bot_stub_boss_test")
var _seconds := 0.0
var _boss_seconds := 0.0
var _contacts := 0
var _entered := false
var _done := false


func _initialize() -> void:
	SimClock.ticks = true
	# Weak points off whatever the Waking ships on: BUDGET is a fresh-kit Sable's dial-0 fight. On dial 1 its chipped
	# body hits run past 195 s; the dial-1 fight's pace is the band table's (challenge:bands), with each band's build.
	ChallengeDials.set_overrides({"waking.weak_points": 0.0})
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	var flow = _game.flow
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", 1)
		_driver.class_index = 0
		_driver.start()
		flow.enter_stage(_game.ctx.stages.last_of(2), Vector3.ZERO, false)
		_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float):
			if _entered and is_instance_valid(enemy) and enemy == _module.warden and kind in ["ram", "slam", "stomp"]:
				_contacts += 1)
		return false
	_seconds += delta
	if flow.state_name() in ["stage", "beacon"] and is_instance_valid(flow.warden):
		_game.player.smash_landing = flow.warden
		_game.ctx.spawner.strike(flow.warden, "slam", 1.0e6)
		_game.player.smash_landing = null
	if flow.state_name() == "boss":
		if not _entered:
			_module = _game.ctx.boss
			_entered = true
			_t.check("world 2 module", _module == flow._module_for(2) and _module.get("ship") == null,
				_module.get_script().resource_path)
		_boss_seconds += delta
	var over: bool = _driver.tick(delta)
	if flow.state_name() == "victory" or over or _seconds >= BUDGET:
		_done = true
		_t.check("victory through driver contacts", _entered and flow.state_name() == "victory" and _contacts > 0,
			"state %s, %d contacts, boss %.2f s, total %.2f s" % [flow.state_name(), _contacts, _boss_seconds, _seconds])
		_t.check("posture Warden broken", _entered and _module.state == _module.DEFEATED)
		_t.eq("world victory leaves run open", _driver.outcome, "")
		_game.free()
		ChallengeDials.reset()
		quit(_t.verdict())
		return true
	return false
