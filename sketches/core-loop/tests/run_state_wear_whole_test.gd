extends SceneTree

const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

# BUGFIX-CORE F001 (2026-10-09): wear takes whole units of mass only. A fractional mass
# (a hit's absorb path leaves one, wear_fraction_debt_test shows 0.5) must not cap a
# step at the fraction: mass 1.5 with 3 units of wear due takes 1 and emits wear_taken(1).

var _t := T.new("run_state_wear_whole_test")


func _initialize() -> void:
	var events := GameEvents.new()
	var run := RunState.new(events)
	run.begin(load("res://src/core/class_def.gd").new())
	run.armor_mode = true
	run.wear_on = true
	var taken: Array = []
	run.wear_taken.connect(func(removed: float): taken.append(removed))
	run.grant_start_mass(1.5)
	# WEAR_PER_MINUTE at cruise is 0.5 a second, so 6 s at cruise is 3 units due at once.
	run.wear_step(6.0, 14.0, 14.0, true)
	_t.eq("one wear emission", taken.size(), 1)
	_t.near("wear_taken is a whole unit", float(taken[0]) if taken.size() > 0 else -1.0, 1.0)
	_t.near("mass keeps its fraction", run.mass, 0.5)
	# 2.5 mass and 3 due: two whole units, not 2.5.
	taken.clear()
	run.grant_start_mass(2.5)
	run.wear_step(6.0, 14.0, 14.0, true)
	_t.near("2.5 mass loses 2 whole units", float(taken[0]) if taken.size() > 0 else -1.0, 2.0)
	_t.near("2.5 mass ends at 0.5", run.mass, 0.5)
	events.free()
	quit(_t.verdict())
