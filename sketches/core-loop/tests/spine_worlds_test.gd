extends SceneTree

const GameScript := preload("res://src/game.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")
const T := preload("res://tests/support/t.gd")

# A run across two worlds on the six-stage double: each world's last stage clears into
# that world's boss, the next world's first stage follows, and the run ends won after
# the last world's boss. Scenario A builds both boss rows; scenario B leaves world two's
# row as worlds.gd has it (unbuilt), so its stages run with no arena. Each stage is
# cleared by calling flow's own finish step, so the test pins the flow's routing, not the
# beacon, which spine_run_test covers.

const TICK_LIMIT := 60 * 60

# The game with the six-stage table in place of the default one.
class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld

var _t := T.new("spine_worlds_test")
var _game
var _boss
var _built := true
var _ticks := 0
var _started := false
var _scenario := 0
var _done := false
var _worlds: Array[int] = []
var _entered: Array[int] = []
var _events: Array[String] = []
var _ended := false
var _won := false
var _last_stage := -1


func _initialize() -> void:
	_boot()


func _boot() -> void:
	_game = TwoWorldGame.new()
	_game.test_mode = true
	root.add_child(_game)
	_started = false
	_ticks = 0
	_worlds = []
	_entered = []
	_events = []
	_ended = false
	_won = false
	_last_stage = -1


func _physics_process(_delta: float) -> bool:
	if _done:
		return true
	if not _started:
		if _game.flow == null:
			return false
		_start()
		return false
	_ticks += 1
	if _ticks > TICK_LIMIT:
		_t.check("timeout", false, "scenario %d stalled in %s at stage %d" % [_scenario, _game.flow.state_name(), _game.run.stage])
		return _conclude()
	var flow = _game.flow
	match flow.state_name():
		"stage", "beacon", "gates", "launch":
			if _game.run.stage != _last_stage:
				_last_stage = _game.run.stage
				flow._finish_stage()
		"boss":
			_boss.defeat()
	if _ended:
		return _conclude()
	return false


func _start() -> void:
	_started = true
	var events = _game.events
	events.world_entered.connect(func(w: int):
		_worlds.append(w)
		_events.append("world %d" % w))
	events.stage_entered.connect(func(s: int, _retry: bool):
		_entered.append(s)
		_events.append("stage %d" % s))
	events.boss_arena_entered.connect(func(): _events.append("arena"))
	events.run_ended.connect(func(won: bool):
		_ended = true
		_won = won)
	_boss = BossDouble.new()
	_game.add_child(_boss)
	_boss.setup(_game.ctx)
	_game.ctx.calm = true
	if _built:
		_game.flow.boss_row_override[2] = Worlds_boss(1)
	_game.flow.press_start()
	_game.flow.choose_class(0)


static func Worlds_boss(world: int) -> Dictionary:
	return preload("res://src/core/worlds.gd").boss_of(world)


func _conclude() -> bool:
	var flow = _game.flow
	var label := "built" if _built else "unbuilt"
	var warnings := 0
	for key in flow._warned:
		if String(key).begins_with("boss_unbuilt"):
			warnings += 1
	_t.eq("%s: world_entered" % label, _worlds, [1, 2])
	_t.eq("%s: stage_entered" % label, _entered, [1, 2, 3, 4, 5, 6])
	_t.check("%s: run ends won in the summary" % label, _ended and _won and flow.state_name() == "summary",
		"ended %s, won %s, state %s" % [_ended, _won, flow.state_name()])
	print("%s order: %s" % [label, " > ".join(_events)])
	if _built:
		_t.eq("built: two boss arenas", _boss.entries, 2)
		_t.eq("built: order", _events, [
			"world 1", "stage 1", "stage 2", "stage 3", "arena",
			"world 2", "stage 4", "stage 5", "stage 6", "arena"])
		_t.eq("built: no skip warning", warnings, 0)
	else:
		_t.eq("unbuilt: one arena, world one's", _boss.entries, 1)
		_t.eq("unbuilt: order", _events, [
			"world 1", "stage 1", "stage 2", "stage 3", "arena",
			"world 2", "stage 4", "stage 5", "stage 6"])
		_t.eq("unbuilt: one skip warning", warnings, 1)
	_t.eq("%s: replay key is stage 6" % label, flow.final_stage(), 6)
	_game.free()
	_scenario += 1
	if _scenario == 1:
		_built = false
		_boot()
		return false
	_done = true
	quit(_t.verdict())
	return true
