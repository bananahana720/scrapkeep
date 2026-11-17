# smoke: solo timeout=180s (one fixed-90-fps child, its own 120 s wall budget)
extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const Game := preload("res://src/game.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const RunState := preload("res://src/core/run_state.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const T := preload("res://tests/support/t.gd")

# The Flume's warden exit (design-v3/park/stages/2-park_flume.md, route warden_exit; card BOT-LINE).
# After a stage-2 break the gates stand on the ground east of the head-house drum, 13 m over its
# floor. The service grade cuts through the north end of the drum's east wall. The other way out is
# drum_lip_kicker, a 28 m wedge rising 14 m to its east lip. Since 2026-10-25 the lip is x 272, on the terrace edge at the terrace's
# height (it was x 267 with a 5 m gap, then x 270.07 with a 1.93 m notch that wedged a resting ball off the
# ground, park_flume_lip_notch_probe_test). The heights tools/bot_driver.gd
# _climb_route reads do not hold the wedge (it is a placed collider), so on 540a55a4 the route came
# back empty and runner_gunner seed 1 sat against the wall from t=120 to the stage limit.
# Pins, from the ball's stall point on that run, (269, -13, 462):
#   route   _climb_route to the gate's run-in point climbs the service grade and ends within LEVEL_BAND of the gate's height;
#   exit    from each of STARTS, the bot's own climb steering (_fight_way_up, then _act) puts the
#           ball on the ground east of the drum wall, within LEVEL_BAND of the gate's height,
#           inside EXIT_S;
#   heavy   a ball of heft HEAVY_HEFT, started on the drum floor where the Warden breaks or partway up the kicker's climb, driven by
#           _to_gate itself, gets out the same way. A heavy ball leaves the lip slow and drops short of
#           the gate lip with its air jump unspent (seed 1 demolitions_caster stalled 12 times in a stage).
#           Before the jump at the lip (_kicker_jump), runner_gunner seed 1's full run
#           reached the top four times and dropped into the gap each time.

const STALL := Vector3(269.0, -12.0, 462.0)
# The exit leg starts from the stall point and from the kicker's south side, where the first head
# of this card wedged runner_gunner seed 1 against the ramp's side face (248 to 258, -13, 462).
const STARTS := [STALL, Vector3(250.0, -12.0, 462.0)]
# Each is [position, velocity]: the floor where the Warden breaks, then a point on the kicker's
# climb (from a demolitions_caster run at heft 2.36) with the speed that run had there; before the
# air jump, this start left the lip short and fell back until the limit.
const HEAVY_STARTS := [
	[Vector3(240.0, -12.0, 472.0), Vector3.ZERO],
	[Vector3(252.05, -9.86, 485.64), Vector3(9.1, 4.3, -6.2)],
]
const HEAVY_HEFT := 2.3
# Out means past the terrace edge (x 272), where the lip now meets the terrace.
const EXIT_X := 272.5
const EXIT_S := 40.0
const SETTLE_TICKS := 30
const KICKER := "drum_lip_kicker"
const GRADE_RISE_M := 7.0

var _t := T.new("bot_flume_exit_test")
var _game
var _driver
var _ticks := 0
var _seconds := 0.0
var _target := Vector3.ZERO
var _gate_y := 0.0
var _peak := -INF
var _out_at := -1.0
var _leg := 0
var _gate_facing := Vector3.ZERO
var _gate_at := Vector3.ZERO
var _done := false


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--child"):
		var results := ChildRuns.run([{"script": "res://tests/bot_flume_exit_test.gd", "args": ["--child"]}], 120.0)
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
		_driver = BotDriver.new(_game, "skipper", 1)
		_driver.class_index = BotDriver.class_index_for(1, "runner_gunner")
		_driver.start()
		_game.flow.enter_stage(2, Vector3.ZERO, false)
		return false
	_ticks += 1
	if _ticks < SETTLE_TICKS:
		return false
	if _ticks == SETTLE_TICKS:
		_game.ctx.calm = true
		_game.run.set_max_hp(99999.0)
		var map = _game.ctx.terrain.map()
		_t.eq("stage 2 is the Flume", String(_game.ctx.stages.DEFS[1]["map"]), "park_flume")
		var slot: Dictionary = map.gate_slots[0]
		var gate := Vector3(slot["at"].x, 0.0, slot["at"].y)
		_gate_y = _game.ctx.terrain.height(gate.x, gate.z)
		_target = Vector3(gate.x, _gate_y, gate.z) - (slot["facing"] as Vector3) * 9.0
		_gate_at = Vector3(gate.x, _gate_y, gate.z)
		_gate_facing = slot["facing"]
		# The lip from the placed node and its park row: the top of the wedge's facing end.
		var lip := Vector3.INF
		var node = _game.ctx.terrain.geometry_root(_game.ctx.terrain.stage).find_child("Park_" + KICKER, true, false)
		for row in map.park["park_rows"]:
			if row["id"] == KICKER and node is Node3D:
				lip = (node as Node3D).global_transform * Vector3(0.0, float(row["size"][1]), float(row["size"][0]) * 0.5)
		_t.check("%s stands as a kicker" % KICKER, lip != Vector3.INF, str(lip))
		var route: Array[Vector3] = _driver._climb_route(STALL, _target)
		var floor_y: float = _game.ctx.terrain.height(STALL.x, STALL.z)
		var end_y: float = _game.ctx.terrain.height(route.back().x, route.back().z) if not route.is_empty() else -INF
		print("exit route from %s to %s: %d points, ends at ground %.1f (gate %.1f): %s" % [
			STALL, _target, route.size(), end_y, _gate_y, route])
		_t.check("a climb route to the gates exists", not route.is_empty(), "%d points" % route.size())
		_t.check("the route climbs the service grade", end_y - floor_y >= GRADE_RISE_M, "ground rises %.1f m" % (end_y - floor_y))
		_t.check("the route ends at the gates' level", _gate_y - end_y <= BotDriver.LEVEL_BAND, "ground %.1f, gate %.1f" % [end_y, _gate_y])
		_start_leg()
		return false
	_seconds += delta
	var ball: Vector3 = _game.player.ball_position()
	_peak = maxf(_peak, ball.y)
	if _out_at < 0.0 and ball.x > EXIT_X and _game.player.state.grounded and _gate_y - ball.y <= BotDriver.LEVEL_BAND:
		_out_at = _seconds
	# The tick count and boost clock tick() runs before it acts, so the boost comes back as in a run.
	_driver.ticks += 1
	_driver._boost_clock -= delta
	var steer := _target
	if _leg >= STARTS.size():
		_driver._to_gate(delta)
	else:
		steer = _driver._fight_way_up(ball, _target, delta) if _driver._climbing(ball, _target) else _target
		_driver._act(steer, null, delta, null, false)
	if OS.get_cmdline_user_args().has("--trace") and _driver.ticks % 30 == 0:
		print("  t=%.2f ball=(%.1f, %.1f, %.1f) speed=%.1f grounded=%s steer=(%.1f, %.1f, %.1f)" % [_seconds, ball.x, ball.y, ball.z,
			_game.player.planar_velocity().length(), _game.player.state.grounded, steer.x, steer.y, steer.z])
	if _out_at >= 0.0 or _seconds >= EXIT_S:
		var start: Vector3 = _start_of(_leg)
		var who := "the heavy bot (heft %.1f) rolls" % _game.run.heft() if _leg >= STARTS.size() else "the bot rolls"
		print("exit leg from %s: out of the drum at %.1f s, peak height %.1f, ball %s" % [start, _out_at, _peak, ball])
		_t.check("from %s %s out of the drum to the gates' level inside %.0f s" % [start, who, EXIT_S], _out_at >= 0.0,
			"ball %s after %.1f s, peak %.1f" % [ball, _seconds, _peak])
		_leg += 1
		if _leg < STARTS.size() + HEAVY_STARTS.size():
			_start_leg()
			return false
		_done = true
		_game.free()
		quit(_t.verdict())
	return false


func _start_leg() -> void:
	_seconds = 0.0
	_peak = -INF
	_out_at = -1.0
	_driver._fight_climb.clear()
	_driver._fight_climb_clock = 0.0
	if _leg >= STARTS.size():
		_game.run.mass = (HEAVY_HEFT - 1.0) / RunState.HEFT_PER_MASS
		_driver._offers = [{"at": _gate_at, "facing": _gate_facing}]
		_driver._gate_pick = 0
		_driver._gate_time = 0.0
		_driver._gate_hop = 0.0
		_driver._gate_run = ""
		_game.player.reset_to(_start_of(_leg), HEAVY_STARTS[_leg - STARTS.size()][1])
		return
	_game.player.reset_to(STARTS[_leg])


func _start_of(leg: int) -> Vector3:
	return STARTS[leg] if leg < STARTS.size() else HEAVY_STARTS[leg - STARTS.size()][0]
