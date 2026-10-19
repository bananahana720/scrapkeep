# smoke: solo (RunState.damage on a bare run; no scene)
extends SceneTree

const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

# The base-tier one-shot guard (RunState.ONE_SHOT_GUARD, the 19 Oct ruling): a hit that would kill
# a pilot at full health leaves 1.0, in the plain path and on the hull step of armour mode. From
# anything under full a lethal hit still kills, and a non-lethal hit subtracts as before.

var _t := T.new("one_shot_guard_test")
var _events: Array = []


func _initialize() -> void:
	for armored in [false, true]:
		_cases(armored)
	for events in _events:
		events.free()
	quit(_t.verdict())


func _run(armored: bool) -> RunState:
	var events := GameEvents.new()
	_events.append(events)
	var run := RunState.new(events)
	run.armor_mode = armored
	return run


func _cases(armored: bool) -> void:
	var tag := "armour" if armored else "plain"
	var run := _run(armored)
	run.damage(run.max_hp * 3.0, "test")
	_t.near("%s: full hp, hit of 3x max_hp leaves 1.0" % tag, run.hp, 1.0)
	_t.check("%s: and the pilot is alive" % tag, run.alive())
	run = _run(armored)
	run.damage(run.max_hp, "test")
	_t.near("%s: full hp, hit of exactly max_hp leaves 1.0" % tag, run.hp, 1.0)
	run = _run(armored)
	run.hp = run.max_hp * 0.5
	run.damage(run.max_hp * 3.0, "test")
	_t.check("%s: half hp, lethal hit kills" % tag, run.hp <= 0.0 and not run.alive())
	run = _run(armored)
	run.damage(23.0, "test")
	_t.near("%s: full hp, non-lethal hit subtracts" % tag, run.hp, run.max_hp - 23.0)
	run = _run(armored)
	run.hp = run.max_hp - 0.5
	run.damage(run.max_hp * 3.0, "test")
	_t.check("%s: just under full, lethal hit kills" % tag, not run.alive())
