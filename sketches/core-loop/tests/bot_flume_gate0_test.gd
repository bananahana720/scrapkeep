# smoke: solo timeout=180s (one fixed-90-fps child, its own 120 s wall budget)
extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const Game := preload("res://src/game.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const RunState := preload("res://src/core/run_state.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const T := preload("res://tests/support/t.gd")

# The Flume's gate 0 on its lip (park_flume gate_slots[0] at (300, 466), facing east; the gate_lip
# ground row under it). With the arena lock on, completionist seed 10 (tally, heft 3.7) came up the
# drum lip onto the gate lip beside the gate and swung across its line, side to side between z 450
# and 473, never inside the 2.5 m _to_gate needs to roll through, for 300 s (99beaf80 seeds 4 and 5
# the same, at (292, 460)). Nothing on the lip stops the ball: the bot drove its heavy ball at the
# run-in point at full speed, overshot it, turned and overshot it again. The fix eases up near any
# gate still untaken after GATE_HOP_SECONDS (GATE_CALM_SPEED), as the bot already did on the
# islands' beacon tops, and near the run-in point but off the line steers for the line ahead of
# the ball (GATE_LINE_LEAD) instead of the point. These replays do not hold the whole run (items,
# kit, director), so judged by reward_gates' take the stage driver also gets through from each of
# them; the 24-seed sweeps on #437 are the evidence, and this test guards the steering. The legs drive _to_gate against one hand-built offer with the game's
# tick bookkeeping (ticks, boost clock), not a full gates flow; "through" is reward_gates' own take
# (step(): the along sign flips inside WIDTH / 2 + 1 of the line and HEIGHT + 4 of the gate's
# ground, the offer standing on drop_point as _fixed_spots places it). Pins:
#   clear   from the run-in point, lined up, a straight roll east takes the gate (no collider in
#           the arch or on its line);
#   swing   from each of SWING_STARTS (seed 10's own ball on the lip: position, velocity and the
#           leg's clock), a ball of that run's heft driven by _to_gate itself rolls through the gate
#           inside THROUGH_S.

const HEAVY_HEFT := 3.7
const SEED6_HEFT := 4.6
# [position, velocity, seconds into the gates leg, gate slot]: from a seed 10 debug trace on
# 26b1e3f4, the north turn, the south turn and mid-swing at gate 0, each a grounded tick of the
# swing; then completionist seed 6 (pylon_engineer, heft 4.6) parked on gate 1's run-in point 4-5 m
# off its line, rocking side to side, once the bot eased up near the gate but still steered for the point.
const SWING_STARTS := [
	[Vector3(289.92, 1.0, 469.91), Vector3(4.79, 0.0, -17.38), 20.6, 0],
	[Vector3(295.25, 1.0, 450.58), Vector3(-0.36, 0.0, 1.31), 22.0, 0],
	[Vector3(293.09, 1.0, 458.42), Vector3(-3.06, 0.0, 11.09), 23.5, 0],
	[Vector3(291.0, 1.0, 475.3), Vector3(0.0, 0.0, 7.0), 30.0, 1],
]
const THROUGH_S := 30.0
const SETTLE_TICKS := 30

var _t := T.new("bot_flume_gate0_test")
var _game
var _driver
var _ticks := 0
var _seconds := 0.0
var _leg := -1
var _gate_at := Vector3.ZERO
var _gate_facing := Vector3.ZERO
var _through_at := -1.0
var _last_along := 0.0
var _done := false


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--child"):
		var results := ChildRuns.run([{"script": "res://tests/bot_flume_gate0_test.gd", "args": ["--child"]}], 120.0)
		var result: Dictionary = results[0]
		print(result["log"])
		_t.check("child ran clean", result["code"] == 0 and not result["timed_out"] and ChildRuns.summary(result)["errors"].is_empty(),
			"exit %s, timed out %s" % [result["code"], result["timed_out"]])
		quit(_t.verdict())
		return
	SimClock.ticks = true
	seed(1)
	node_added.connect(func(node: Node):
		if node is Game:
			node.table = "park")
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "completionist", 10)
		_driver.class_index = BotDriver.class_index_for(10, "tally")
		_driver.start()
		_game.flow.enter_stage(2, Vector3.ZERO, false)
		return false
	_ticks += 1
	if _ticks < SETTLE_TICKS:
		return false
	if _ticks == SETTLE_TICKS:
		_game.ctx.calm = true
		_game.run.set_max_hp(99999.0)
		_t.eq("stage 2 is the Flume", String(_game.ctx.terrain.map().title), "park_flume")
		_aim(0)
		_game.run.mass = (HEAVY_HEFT - 1.0) / RunState.HEFT_PER_MASS
		_start_leg(0)
		return false
	_seconds += delta
	var ball: Vector3 = _game.player.ball_position()
	var rel := ball - _gate_at
	var along := rel.dot(_gate_facing)
	var side := RewardGates.sideways(rel, _gate_facing)
	if _through_at < 0.0 and _last_along < 0.0 and along >= 0.0 and RewardGates.inside_arch(rel, _gate_facing):
		_through_at = _seconds
	_last_along = along
	_driver.ticks += 1
	_driver._boost_clock -= delta
	if _leg == 0:
		_driver._act(_gate_at + _gate_facing * 10.0, null, delta, null, false)
	else:
		_driver._to_gate(delta)
	if OS.get_cmdline_user_args().has("--trace") and _driver.ticks % 45 == 0:
		print("  leg %d t=%.2f ball=(%.1f, %.1f, %.1f) speed=%.1f along=%.1f side=%.1f" % [_leg, _seconds, ball.x, ball.y, ball.z,
			_game.player.planar_velocity().length(), along, side])
	if _through_at >= 0.0 or _seconds >= THROUGH_S:
		if _leg == 0:
			_t.check("lined up on the lip, a straight roll takes gate 0 (nothing in the arch)", _through_at >= 0.0,
				"ball %s after %.1f s" % [ball, _seconds])
		else:
			var start: Array = SWING_STARTS[_leg - 1]
			print("swing leg from %s: through at %.1f s, ball %s" % [start[0], _through_at, ball])
			_t.check("from %s at %.0f m/s the heavy bot (heft %.1f) rolls through gate %d inside %.0f s" % [start[0], start[1].length(),
				_game.run.heft(), int(start[3]), THROUGH_S], _through_at >= 0.0, "ball %s, along %.1f, side %.1f" % [ball, along, side])
		if _leg < SWING_STARTS.size():
			_start_leg(_leg + 1)
			return false
		_done = true
		_game.free()
		quit(_t.verdict())
	return false


func _aim(slot_index: int) -> void:
	var slot: Dictionary = _game.ctx.terrain.map().gate_slots[slot_index]
	_gate_facing = slot["facing"]
	_gate_at = _game.ctx.terrain.drop_point(slot["at"].x, slot["at"].y, 0.0)


func _start_leg(leg: int) -> void:
	_leg = leg
	_seconds = 0.0
	_through_at = -1.0
	_last_along = -INF
	_driver._fight_climb.clear()
	_driver._fight_climb_clock = 0.0
	_driver._offers = [{"at": _gate_at, "facing": _gate_facing}]
	_driver._gate_pick = 0
	_driver._gate_time = 0.0
	_driver._gate_hop = 0.0
	_driver._gate_run = ""
	if leg == 0:
		var run_in := _gate_at - _gate_facing * 9.0
		_game.player.reset_to(Vector3(run_in.x, 4.0, run_in.z), Vector3.ZERO)
		return
	var start: Array = SWING_STARTS[leg - 1]
	_aim(int(start[3]))
	_driver._offers = [{"at": _gate_at, "facing": _gate_facing}]
	_game.run.mass = ((SEED6_HEFT if int(start[3]) == 1 else HEAVY_HEFT) - 1.0) / RunState.HEFT_PER_MASS
	_driver._gate_time = start[2]
	_game.player.reset_to(start[0], start[1])
