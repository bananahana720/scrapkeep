extends SceneTree

const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")

var _failures := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var events := GameEvents.new()
	var run := RunState.new(events)
	run.begin(load("res://src/core/class_def.gd").new())
	run.armor_mode = true
	run.wear_on = true
	run.grant_start_mass(100.0)
	run.mitigation = 0.005
	run.damage(10.0, "probe")
	_check(is_equal_approx(run.mass, 0.5), "a mitigated hit leaves mass 0.5, got %s" % run.mass)
	for i in 3600:
		run.wear_step(1.0 / 60.0, 14.0, 14.0, true)
	_check(is_equal_approx(run.mass, 0.5), "mass below one does not drain")
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	var snap_accum: float = run.snapshot_value("wear_accum")
	_check(snap_accum < 1.0, "debt while 0 < mass < 1 stays below one unit, got %s" % snap_accum)
	run.add_scrap(20, Vector3.ZERO)
	var before: float = run.mass
	run.wear_step(1.0 / 60.0, 14.0, 14.0, true)
	var lost: float = before - run.mass
	_check(lost <= 1.0, "one tick after a pickup took %s mass" % lost)
	events.free()
	if _failures > 0:
		quit(1)
	else:
		print("PASS")
		quit(0)
