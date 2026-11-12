extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RunClock := preload("res://src/build/run_clock.gd")
const T := preload("res://tests/support/t.gd")

# W1-62, a quick Warden break pays: a Warden broken within RunClock.QUICK_BREAK_SECONDS of its
# engagement adds one part roll to its gate. The clock counts the fight from the attempt's
# engagement to the first break, and a stage with no limit (0) never pays. In a booted run the
# gates open with the pair after a fight over the limit, and with the pair and one more arch
# after a fight under it.
# smoke: timeout=120s

var _game
var _build
var _ticks := 0
var _t := T.new("quick_break_gate_test")


func _initialize() -> void:
	_clock_rules()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _clock_rules() -> void:
	var clock := RunClock.new()
	clock.enter_stage(1)
	_t.eq("no fight before an engagement", clock.fight_seconds(), -1.0)
	clock.stage_seconds = 40.0
	clock.warden_engaged()
	clock.stage_seconds = 40.0 + RunClock.QUICK_BREAK_SECONDS[0]
	clock.warden_broken()
	_t.near("the fight runs from engagement to break", clock.fight_seconds(), RunClock.QUICK_BREAK_SECONDS[0])
	_t.check("a break at the limit is quick", clock.quick_break(), str(clock.fight_seconds()))
	clock.stage_seconds = 200.0
	clock.warden_engaged()
	_t.near("an engagement after the break does not move the fight", clock.fight_seconds(), RunClock.QUICK_BREAK_SECONDS[0])
	clock.enter_stage(1)
	clock.stage_seconds = 10.0
	clock.warden_engaged()
	clock.stage_seconds = 50.0
	clock.warden_engaged()
	clock.stage_seconds = 50.0 + RunClock.QUICK_BREAK_SECONDS[0] - 1.0
	clock.warden_broken()
	_t.check("a retried attempt counts from its own engagement", clock.quick_break(), str(clock.fight_seconds()))
	clock.enter_stage(2)
	clock.warden_engaged()
	clock.stage_seconds = RunClock.QUICK_BREAK_SECONDS[1] + 0.5
	clock.warden_broken()
	_t.check("a break over the limit is not quick", not clock.quick_break(), str(clock.fight_seconds()))
	clock.enter_stage(3)
	clock.warden_engaged()
	clock.warden_broken()
	_t.check("a stage with no limit never pays", not clock.quick_break(), "stage 3 limit %s" % RunClock.QUICK_BREAK_SECONDS[2])
	clock.enter_stage(1)
	clock.warden_broken()
	_t.check("a break with no engagement is not quick", not clock.quick_break(), str(clock.fight_seconds()))


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_build = _game.ctx.build
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if _ticks < 12:
		return false
	var slow := _arches(RunClock.QUICK_BREAK_SECONDS[0] + 5.0)
	var quick := _arches(RunClock.QUICK_BREAK_SECONDS[0] - 5.0)
	_t.check("a slow break opens the pair", slow >= 2, "%d arches" % slow)
	_t.eq("a quick break opens one more arch", quick, slow + 1)
	quit(_t.verdict())
	return true


# The arches the gates open with after a stage-1 Warden fight of these seconds.
func _arches(fight: float) -> int:
	_build.gates.close()
	var clock = _build.clock
	clock.enter_stage(1)
	clock.warden_engaged()
	clock.stage_seconds += fight
	clock.warden_broken()
	_game.events.flow_changed.emit("gates")
	var count: int = _build.gates.offers.size()
	_build.gates.close()
	return count
