# smoke: solo timeout=120s (wave 37 unit D7: hull regenerates only while the ball rolls in the cruise tier or above)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RunState := preload("res://src/core/run_state.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const T := preload("res://tests/support/t.gd")

# Ruling cu, call 1: health regenerates only while the ball rolls at cruise or above. World 1 ships
# pilot.regen_rolling_by_stage on (1/1/0/0/0/0). The rule on a bare run state, then the wiring on the real
# game: a ball parked on the dam does not heal, and the same parked ball with the dial off (the planted case,
# the game before this unit) does. The wait after a hit and the rate are what they were.

const REGEN_OFF := {"pilot.regen_rolling_by_stage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}
const H := 1.0 / 60.0

var _t := T.new("regen_rolling_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


# Hull healed over `seconds` from half health, the last hit long past.
func _healed(run, seconds: float, rolling: bool) -> float:
	run.hp = run.max_hp * 0.5
	run.since_damage = 99.0
	for i in int(seconds / H):
		run.advance(H, rolling)
	return run.hp - run.max_hp * 0.5


func _rules() -> void:
	_t.eq("01 the rule ships across all stages", ChallengeDials.value("pilot.regen_rolling_by_stage"), [1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
	_t.eq("02 it is a plain tune: ruled, so no --tune-unruled", ChallengeDials.parse("pilot.regen_rolling_by_stage=0/0/0/0/0/0").size(), 1)
	ChallengeDials.quiet = true
	_t.eq("03 the unruled pilot dials are still refused", ChallengeDials.parse("pilot.regen_rate_mult=2").size(), 0)
	ChallengeDials.quiet = false
	ChallengeDials.reset()
	var run = RunState.new()
	run.stage = 1
	_t.check("04 the dam heals only a rolling ball", run.regen_needs_roll())
	_t.near("05 a rolling ball heals at the old rate", _healed(run, 2.0, true), RunState.REGEN_RATE * 2.0, 0.2)
	_t.near("06 a ball below the cruise tier heals nothing", _healed(run, 10.0, false), 0.0)
	# The wait after a hit runs at any speed: parked through it, then rolling, heals at once.
	run.hp = run.max_hp * 0.5
	run.since_damage = 0.0
	for i in int((RunState.REGEN_DELAY + 1.0) / H):
		run.advance(H, false)
	var before: float = run.hp
	for i in int(1.0 / H):
		run.advance(H, true)
	_t.near("07 the wait after a hit runs while parked; rolling then heals at once", run.hp - before, RunState.REGEN_RATE, 0.2)
	_t.near("08 a caller with no ball heals as before", _default_arg(run), RunState.REGEN_RATE * 2.0, 0.2)
	run.stage = 3
	_t.check("09 the Dig inherits the rolling-regen rule", run.regen_needs_roll())
	_t.near("10 a parked ball does not heal in the Dig", _healed(run, 2.0, false), 0.0)
	# The planted case: the dial off is the game before this unit; the parked ball on the dam must heal, or
	# check 06 says nothing about the rule.
	run.stage = 1
	ChallengeDials.set_overrides(REGEN_OFF)
	_t.near("11 planted: with the dial off a parked ball heals on the dam", _healed(run, 2.0, false), RunState.REGEN_RATE * 2.0, 0.2)
	ChallengeDials.set_overrides({})
	_t.eq("12 the wait and the rate are what they were", [RunState.REGEN_DELAY, RunState.REGEN_RATE], [5.0, 6.0])


func _default_arg(run) -> float:
	run.hp = run.max_hp * 0.5
	run.since_damage = 99.0
	for i in int(2.0 / H):
		run.advance(H)
	return run.hp - run.max_hp * 0.5


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


# Holds the ball still for `count` frames: the dam's slope would roll a ball that is only let go.
func _park(count: int) -> void:
	for i in count:
		_game.player.set_velocity_now(Vector3.ZERO, "parked")
		await physics_frame


# The real game, a ball parked on the dam: hull gained over three seconds, the last hit long past.
func _parked_gain() -> float:
	_game.run.hp = _game.run.max_hp * 0.5
	_game.run.since_damage = 99.0
	var before: float = _game.run.hp
	await _park(3 * Engine.physics_ticks_per_second)
	return _game.run.hp - before


func _run() -> void:
	ChallengeDials.reset()
	_rules()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _frames(90)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	await _park(30)
	_t.check("13 the parked ball is below the cruise tier and the run is in stage 1", _game.player.speed_tier() < SpeedTier.CRUISE and _game.run.stage == 1 and _game.flow.in_play(),
		"tier %d, stage %d, in play %s" % [_game.player.speed_tier(), _game.run.stage, _game.flow.in_play()])
	var parked: float = await _parked_gain()
	_t.near("14 a ball parked on the dam does not heal", parked, 0.0)
	ChallengeDials.set_overrides(REGEN_OFF)
	var planted: float = await _parked_gain()
	ChallengeDials.set_overrides({})
	_t.check("15 planted: with the dial off the same parked ball heals", planted > RunState.REGEN_RATE * 2.0, "healed %.1f hull in 3 s" % planted)
	ChallengeDials.reset()
	quit(_t.verdict())
