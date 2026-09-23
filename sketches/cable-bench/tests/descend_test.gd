extends SceneTree

const Stage := preload("res://src/stage.gd")
const Layout := preload("res://src/layout.gd")

const SETTLE := 0.5
const MEASURE := 2.5
const MAX_CLEARANCE := 6.0

var _stage
var _index := 0
var _started := false
var _measuring := false
var _clock := 0.0
var _start_y := 0.0
var _failures := 0


func _initialize() -> void:
	_stage = Stage.new()
	_stage.test_mode = true
	root.add_child(_stage)


func _begin() -> void:
	var x: float = Layout.ROAD_X[_index]
	var z: float = Layout.CLIFF_Z[_index] + 2.0
	_stage.player.reset_to(Layout.drop_point(x, z, 1.5))
	_measuring = false
	_clock = 0.0


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
	if not _measuring:
		if _clock < SETTLE:
			return false
		_start_y = _stage.player.ball_position().y
		_measuring = true
		_clock = 0.0
		return false
	if _clock < MEASURE:
		return false

	var at: Vector3 = _stage.player.ball_position()
	var drop := _start_y - at.y
	var clearance := at.y - Layout.height(at.x, at.z)
	var descended := drop > 1.0
	# Without the clearance check a ball that fell through the trimesh would pass
	# the descent assertion by free-falling into the void.
	var on_course := clearance < MAX_CLEARANCE and absf(at.x) < Layout.HALF and absf(at.z) < Layout.HALF
	print("[switchback %d] dropped %.2f m in %.1fs (needs > 1.0) -> %s"
		% [_index, drop, MEASURE, "PASS" if descended else "FAIL"])
	print("[switchback %d] %.2f m above the surface at (%.1f, %.1f) (needs < %.1f) -> %s"
		% [_index, clearance, at.x, at.z, MAX_CLEARANCE, "PASS" if on_course else "FAIL"])
	if not (descended and on_course):
		_failures += 1

	_index += 1
	if _index < Layout.ROAD_X.size():
		_begin()
		return false

	print("descend_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d road(s))" % _failures))
	_stage.free()
	quit(0 if _failures == 0 else 1)
	return true
