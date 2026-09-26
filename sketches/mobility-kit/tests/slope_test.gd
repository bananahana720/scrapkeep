extends SceneTree

const Lab := preload("res://src/lab.gd")
const PlayerBall := preload("res://src/player_ball.gd")
const Field := preload("res://src/field.gd")

const SETTLE := 0.6
const MEASURE := 3.0
const MIN_SPEED := 5.0
const MAX_CLEARANCE := 6.0

var _lab
var _modes := [PlayerBall.KINEMATIC, PlayerBall.RIGID]
var _index := 0
var _started := false
var _measuring := false
var _clock := 0.0
var _start_y := 0.0
var _failures := 0


func _initialize() -> void:
	_lab = Lab.new()
	_lab.test_mode = true
	root.add_child(_lab)


func _begin() -> void:
	_lab.player.set_mode(_modes[_index])
	_lab.player.reset_to(_lab.field.downhill_start)
	_measuring = false
	_clock = 0.0


func _process(delta: float) -> bool:
	# The lab's _ready runs after _initialize, so the first frame starts the run.
	if not _started:
		if _lab.player == null:
			return false
		_started = true
		_begin()
		return false
	_clock += delta
	if not _measuring:
		if _clock < SETTLE:
			return false
		_start_y = _lab.player.ball_position().y
		_measuring = true
		_clock = 0.0
		return false
	if _clock < MEASURE:
		return false

	var mode: String = _lab.player.mode_name()
	var speed: float = _lab.player.state.velocity.length()
	var at: Vector3 = _lab.player.ball_position()
	var drop := _start_y - at.y
	var clearance := at.y - Field.height(at.x, at.z)
	var gained := speed > MIN_SPEED
	var descended := drop > 0.0
	# Without this a ball that tunnels through the terrain would satisfy both
	# assertions by free-falling.
	var on_course := clearance < MAX_CLEARANCE and absf(at.x) < 125.0 and absf(at.z) < 125.0
	print("[%s] speed after %.1fs with no input: %.2f m/s (needs > %.1f) -> %s"
		% [mode, MEASURE, speed, MIN_SPEED, "PASS" if gained else "FAIL"])
	print("[%s] height change: %.2f m -> %.2f m, dropped %.2f m -> %s"
		% [mode, _start_y, at.y, drop, "PASS" if descended else "FAIL"])
	print("[%s] still on the surface: %.2f m above the field at (%.1f, %.1f) (needs < %.1f) -> %s"
		% [mode, clearance, at.x, at.z, MAX_CLEARANCE, "PASS" if on_course else "FAIL"])
	if not (gained and descended and on_course):
		_failures += 1

	_index += 1
	if _index < _modes.size():
		_begin()
		return false

	print("slope_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d mode(s))" % _failures))
	_lab.free()
	quit(0 if _failures == 0 else 1)
	return true
