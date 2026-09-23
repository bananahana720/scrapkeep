extends SceneTree

const Stage := preload("res://src/stage.gd")
const Layout := preload("res://src/layout.gd")
const Rules := preload("res://src/rules.gd")
const RunState := preload("res://src/run_state.gd")

const TEST_CHARGE := 4.0
const AWAY_WINDOW := 1.5
const TIMEOUT := 12.0

var _stage
var _started := false
var _phase := 0
var _clock := 0.0
var _away_charge := -1.0
var _charged_at := -1.0


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


func _process(delta: float) -> bool:
	if not _started:
		if _stage.run == null:
			return false
		_started = true
		_stage.run.charge_seconds = TEST_CHARGE
		# Start it from outside the apron: leaving must stall the charge.
		_stage.player.reset_to(Layout.drop_at(Vector2(120.0, -60.0), 2.0))
		_stage.run.start_charge()
		return false

	_clock += delta
	if _phase == 0:
		if _clock < AWAY_WINDOW:
			return false
		_away_charge = _stage.run.charge
		_stage.player.reset_to(Layout.forge_point() + Vector3.UP * 2.0)
		_phase = 1
		_clock = 0.0
		return false

	# The ball is parked on the exit, so the stage takes it the instant the charge
	# fills: READY and CLEAR both mean the charge finished.
	if _stage.run.charge_fraction() >= 1.0 and _charged_at < 0.0:
		_charged_at = _clock
	if _charged_at < 0.0 and _clock < TIMEOUT:
		return false

	var stalled: bool = _away_charge <= 0.01
	var completed: bool = _charged_at >= 0.0
	var default_ok: bool = Rules.CHARGE_SECONDS == 60.0
	var phase_ok: bool = _stage.run.phase == RunState.Phase.READY or _stage.run.phase == RunState.Phase.CLEAR
	print("[forge] %.1fs outside the %.0f m ring added %.2fs of charge (needs 0) -> %s"
		% [AWAY_WINDOW, Rules.CHARGE_RADIUS, maxf(0.0, _away_charge), "PASS" if stalled else "FAIL"])
	print("[forge] holding the ball in the zone finished a %.0fs charge after %.2fs -> %s"
		% [TEST_CHARGE, _charged_at, "PASS" if completed else "FAIL"])
	print("[forge] shipped charge length is %.0fs -> %s"
		% [Rules.CHARGE_SECONDS, "PASS" if default_ok else "FAIL"])
	print("[forge] phase after the charge: %s -> %s"
		% [_stage.run.phase_name(), "PASS" if phase_ok else "FAIL"])
	var ok: bool = stalled and completed and default_ok and phase_ok
	print("exit_charge_test: %s" % ("PASS" if ok else "FAIL"))
	_stage.free()
	quit(0 if ok else 1)
	return true
