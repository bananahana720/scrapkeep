extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")

# Regression for the balance loop's hang (2026-09-27): random seed 5 put stage 1's gate 1
# behind a Spillway chute kerb, the bot could not reach it, and the process ran for ever
# because only the Warden fight had a stall limit. The bot must end a run in any stage
# state, the gates included, once stage_time passes STAGE_LIMIT, and say which state ran
# out. The state is forced here so the test does not depend on the fight, which real-time
# hit-stop gaps make non-replayable across machine load.
#
# Evidence limit: harness behaviour only; play is not touched.

const SEED := 5
# Hard budget: a bot that never ends fails here instead of stalling the smoke run.
const TICK_BUDGET := 90 * 5

var _game
var _driver
var _failures := 0
var _ticks := 0
var _phase := "start"
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "random", SEED)
		_driver.start()
		return false
	_ticks += 1
	match _phase:
		"start":
			_driver.tick(delta)
			if _game.flow.state_name() == "stage":
				# Gates with no offers, as after a placement the bot never reached: below
				# the limit the run goes on.
				_game.flow.state = _game.flow.GATES
				_game.run.stage_time = BotDriver.STAGE_LIMIT - 1.0
				_report("gates below the limit", not _driver.tick(delta), "state %s at %.0f s, outcome '%s'"
					% [_game.flow.state_name(), _game.run.stage_time, _driver.outcome])
				_game.run.stage_time = BotDriver.STAGE_LIMIT + 1.0
				_phase = "gates"
				_ticks = 0
			elif _ticks > TICK_BUDGET:
				_report("reach play", false, "still %s after %d ticks" % [_game.flow.state_name(), _ticks])
				return _finish()
		"gates":
			if _driver.tick(delta):
				return _finish()
			if _ticks > TICK_BUDGET:
				_report("gates past the limit", false, "bot still running after %d ticks in %s at %.0f s"
					% [_ticks, _game.flow.state_name(), _game.run.stage_time])
				return _finish()
	return false


func _finish() -> bool:
	_done = true
	if _phase == "gates" and _driver.outcome != "":
		var record: Dictionary = _driver.record(0.0)
		var stages: Array = record["stages"]
		var note: Dictionary = stages[0] if stages.size() > 0 and stages[0] is Dictionary else {}
		_report("gates past the limit", _driver.outcome == "stalled" and _ticks <= TICK_BUDGET,
			"outcome '%s' after %d tick(s)" % [_driver.outcome, _ticks])
		_report("stall state noted", note.get("stall_state") == "gates", "stall_state %s" % note.get("stall_state", "missing"))
	print("loop_bot_hang_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
