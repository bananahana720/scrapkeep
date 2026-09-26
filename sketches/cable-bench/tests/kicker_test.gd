extends SceneTree

const Stage := preload("res://src/stage.gd")
const Layout := preload("res://src/layout.gd")
const SpeedTier := preload("res://src/speed_tier.gd")

const MESA := 0
const FAST_SPEED := 26.0
const SLOW_SPEED := 9.0
const FLIGHT := 4.0
# A teleport lands on the next physics step, so the first frames of a run still
# report the previous run's position. Ignore them.
const SETTLE := 0.15

var _stage
var _runs := [FAST_SPEED, SLOW_SPEED]
var _index := 0
var _started := false
var _clock := 0.0
var _landed := [false, false]
var _peak := [0.0, 0.0]
var _finish := [Vector3.ZERO, Vector3.ZERO]
var _first := [Vector3.ZERO, Vector3.ZERO]


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


func _begin() -> void:
	var entry := Layout.kicker_entry(MESA)
	var run_dir := Layout.kicker_run_direction(MESA)
	_stage.player.reset_to(entry)
	_stage.player.active_body().set_velocity_now(run_dir * _runs[_index])
	_clock = 0.0


func _on_mesa() -> bool:
	var at: Vector3 = _stage.player.ball_position()
	var centre: Vector2 = Layout.MESAS[MESA]["centre"]
	var flat := Vector2(at.x, at.z).distance_to(centre)
	return flat < Layout.MESA_RADIUS and at.y > Layout.mesa_top(MESA) - 1.5


func _process(delta: float) -> bool:
	if not _started:
		if _stage.player == null:
			return false
		_started = true
		# A cableway sweep or a spawned foe would make a ballistics measurement
		# nondeterministic; each has its own test.
		for cableway in _stage.cableways:
			cableway.set_physics_process(false)
		_stage.director.set_physics_process(false)
		_begin()
		return false
	_clock += delta
	if _clock < SETTLE:
		return false
	if _on_mesa():
		_landed[_index] = true
	var at: Vector3 = _stage.player.ball_position()
	if _first[_index] == Vector3.ZERO:
		_first[_index] = at
	_peak[_index] = maxf(_peak[_index], at.y)
	_finish[_index] = at
	if _clock < FLIGHT:
		return false

	_index += 1
	if _index < _runs.size():
		_begin()
		return false

	var cruise: float = _stage.tuning.f("cruise")
	var fast_tier: bool = SpeedTier.of(FAST_SPEED, cruise) >= SpeedTier.FAST
	var slow_tier: bool = SpeedTier.of(SLOW_SPEED, cruise) < SpeedTier.FAST
	print("[kicker] launch speeds: %.0f m/s is tier '%s', %.0f m/s is tier '%s'"
		% [FAST_SPEED, SpeedTier.label(SpeedTier.of(FAST_SPEED, cruise)),
			SLOW_SPEED, SpeedTier.label(SpeedTier.of(SLOW_SPEED, cruise))])
	var entry := Layout.kicker_entry(MESA)
	var started_right := true
	for i in _runs.size():
		var offset: float = _first[i].distance_to(entry)
		if offset > 5.0:
			started_right = false
		print("[kicker] launch %.0f m/s: began %.2f m from the kicker entry, peak %.2f m, ended at %s (mesa top %.2f)"
			% [_runs[i], offset, _peak[i], _finish[i], Layout.mesa_top(MESA)])
	print("[kicker] both launches started on the kicker run-up -> %s" % ["PASS" if started_right else "FAIL"])
	print("[kicker] fast launch at %.0f m/s reaches '%s' -> %s"
		% [FAST_SPEED, Layout.MESAS[MESA]["name"], "PASS" if _landed[0] else "FAIL"])
	print("[kicker] slow launch at %.0f m/s stays below -> %s"
		% [SLOW_SPEED, "PASS" if not _landed[1] else "FAIL"])
	var ok: bool = _landed[0] and not _landed[1] and fast_tier and slow_tier and started_right
	print("kicker_test: %s" % ("PASS" if ok else "FAIL"))
	_stage.free()
	quit(0 if ok else 1)
	return true
