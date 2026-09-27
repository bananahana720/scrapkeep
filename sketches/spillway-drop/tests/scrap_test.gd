extends SceneTree

const Stage := preload("res://src/stage.gd")

const PLACED_MIN := 60
const PLACED_MAX := 100
const SETTLE := 0.4

var _stage
var _started := false
var _placed := 0
var _scrap_before := 0
var _count_before := 0
var _ticks := 0


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


# Counted in physics ticks, not idle-frame seconds: the rigid reset lands on the
# next tick, and a starved machine fits less simulated time into a wall second.
func _physics_process(_delta: float) -> bool:
	if not _started:
		if _stage.player == null:
			return false
		_started = true
		_stage.director.paused = true
		_placed = _stage.scrap.count()
		_scrap_before = _stage.run.scrap
		_count_before = _placed
		# Drop the ball straight onto a pickup and let the real loop collect it.
		_stage.player.reset_to(_stage.scrap.item_position(0) + Vector3.UP * 0.2)
		return false

	_ticks += 1
	if _ticks < _to_ticks(SETTLE):
		return false

	var collected: int = _stage.run.scrap - _scrap_before
	var removed: int = _count_before - _stage.scrap.count()
	var in_range := _placed >= PLACED_MIN and _placed <= PLACED_MAX
	var picked := collected >= 1
	var consistent := removed >= collected
	print("scrap: %d pickups placed on the momentum lines (wants %d-%d) -> %s"
		% [_placed, PLACED_MIN, PLACED_MAX, "PASS" if in_range else "FAIL"])
	print("scrap: count went %d -> %d after rolling through a pickup -> %s"
		% [_scrap_before, _stage.run.scrap, "PASS" if picked else "FAIL"])
	print("scrap: %d pickups removed from the field for %d counted -> %s"
		% [removed, collected, "PASS" if consistent else "FAIL"])

	var ok := in_range and picked and consistent
	print("scrap_test: %s" % ("PASS" if ok else "FAILED"))
	_stage.free()
	quit(0 if ok else 1)
	return true


static func _to_ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)
