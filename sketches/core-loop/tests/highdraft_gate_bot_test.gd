# smoke: solo (one isolated fixed-90-fps skipper child jumped to stage 5 on the alpha table; 240 s wall budget)
extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const T := preload("res://tests/support/t.gd")

# The w23 posture run's Highdraft gates stall: a skipper jumped to stage 5 on the alpha table
# breaks the Warden, then must roll through a gate before the driver's stage limit. Seed 2 is the
# repro: its ball leaves the beacon island after the break, and the arches stand on the island's
# top, 13 m over the net deck. The way back is the beacon ramp (map_highdraft.gd RAMPS), climbed
# by the bot's route; rolling straight at the arch presses the ball against the island's cliff.
#
# Evidence limit: one seed and one class on the alpha table; it says nothing about the other
# pilots, the completionist, or feel.

const SEED := 2
const JUMP_STAGE := 5
const WALL_BUDGET := 240.0

var _t := T.new("highdraft_gate_bot_test")
var _child := false
var _game
var _driver
var _seconds := 0.0
var _done := false
var _broke := false
var _scrap_serial := 0
var _counter_serial := 0


func _initialize() -> void:
	_child = "--child" in OS.get_cmdline_user_args()
	if not _child:
		var results := ChildRuns.run([{"script": "res://tests/highdraft_gate_bot_test.gd", "args": ["--child", "--table=alpha"]}], WALL_BUDGET)
		var result: Dictionary = results[0]
		print(result["log"])
		_t.check("isolated child", result["code"] == 0 and not result["timed_out"]
			and ChildRuns.summary(result)["errors"].is_empty())
		_done = true
		quit(_t.verdict())
		return
	SimClock.ticks = true
	node_added.connect(_on_node_added)
	seed(SEED)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", SEED)
		_game.presentation.audio.bake_now()
		_driver.start()
		_game.flow.enter_stage(JUMP_STAGE, Vector3.ZERO, false)
		return false
	_seconds += delta
	var over: bool = _driver.tick(delta)
	_broke = _broke or _driver.warden_broken()
	if over or _game.flow.state_name() == "launch" or _game.run.stage > JUMP_STAGE:
		_finish()
	return false


# The spawn-order signs tools/bot_run.gd sets, so the bot's strafe and scrap sides do not
# hang on object IDs and the run repeats.
func _on_node_added(node: Node) -> void:
	if _game == null or _game.build == null:
		return
	if "_strafe" in node:
		node.set_meta("bot_strafe", 1.0 if (_counter_serial + SEED) % 2 == 0 else -1.0)
		_counter_serial += 1
	if node.get_parent() == _game.build.scrap:
		node.set_meta("bot_side", 1.0 if (_scrap_serial + SEED) % 2 == 0 else -1.0)
		_scrap_serial += 1


func _finish() -> void:
	_done = true
	var ball: Vector3 = _game.player.ball_position()
	var state: String = _game.flow.state_name()
	var detail := "%.1f s, state '%s', stage %d, bot outcome '%s', goal '%s', ball (%.0f, %.0f, %.0f)" \
		% [_seconds, state, _game.run.stage, _driver.outcome, _driver._goal, ball.x, ball.y, ball.z]
	print("gate taken at stage time %.2f s" % _seconds if state == "launch" or _game.run.stage > JUMP_STAGE else "no gate: " + detail)
	_t.check("Warden broken", _broke, detail)
	_t.check("a gate taken within the %d s stage limit" % int(BotDriver.STAGE_LIMIT),
		state == "launch" or _game.run.stage > JUMP_STAGE, detail)
	_t.check("no stall", _driver.outcome != "stalled", detail)
	_game.free()
	quit(_t.verdict())
