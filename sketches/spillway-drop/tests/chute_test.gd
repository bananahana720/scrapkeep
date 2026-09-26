extends SceneTree

const Stage := preload("res://src/stage.gd")
const Terrain := preload("res://src/terrain.gd")

const SETTLE := 0.7
const MEASURE := 3.0
const MIN_SPEED := 10.0
const MAX_CLEARANCE := 6.0

var _stage
var _index := 0
var _started := false
var _measuring := false
var _clock := 0.0
var _peak := 0.0
var _worst_clearance := 0.0
var _failures := 0


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


func _begin() -> void:
	_stage.director.paused = true
	_stage.player.reset_to(Terrain.chute_entry(_index))
	_measuring = false
	_clock = 0.0
	_peak = 0.0
	_worst_clearance = 0.0


func _process(delta: float) -> bool:
	if not _started:
		if _stage.player == null:
			return false
		_started = true
		_begin()
		return false

	_clock += delta
	if not _measuring:
		if _clock < SETTLE:
			return false
		_measuring = true
		_clock = 0.0
		return false

	var at: Vector3 = _stage.player.ball_position()
	_peak = maxf(_peak, _stage.player.state.velocity.length())
	_worst_clearance = maxf(_worst_clearance, at.y - Terrain.height(at.x, at.z))
	if _clock < MEASURE:
		return false

	var fast := _peak > MIN_SPEED
	# Without this a ball that tunnelled through the chute floor would satisfy the
	# speed assertion by free-falling instead of rolling.
	var on_surface := _worst_clearance < MAX_CLEARANCE
	print("chute %d: peak %.2f m/s in %.1f s with no input (needs > %.1f) -> %s"
		% [_index, _peak, MEASURE, MIN_SPEED, "PASS" if fast else "FAIL"])
	print("chute %d: worst clearance %.2f m above the surface (needs < %.1f), ended at (%.1f, %.1f, %.1f) -> %s"
		% [_index, _worst_clearance, MAX_CLEARANCE, at.x, at.y, at.z, "PASS" if on_surface else "FAIL"])
	if not (fast and on_surface):
		_failures += 1

	_index += 1
	if _index < Terrain.CHUTES.size():
		_begin()
		return false

	print("chute_test: %s" % ("PASS" if _failures == 0 else "FAILED on %d chute(s)" % _failures))
	_stage.free()
	quit(0 if _failures == 0 else 1)
	return true
