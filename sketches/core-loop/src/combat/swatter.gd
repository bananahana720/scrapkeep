extends "res://src/combat/counter.gd"

# The swatter (DESIGN-V2 section 15.4): a crew figure behind a long low paddle arm. The
# warning is a wedge swept by the paddle, low (PADDLE_REACH), so a jump clears it. When
# it fills the paddle swings: a ball the wedge contains is batted along the sweep, a
# hard sideways knock that throws it off its line but never slows it, and for BAT
# seconds the knock owns the ball. Boost inside that time and you ride it: the knock
# becomes your speed, with the break refund. The paddle never damages; its punishment
# is the line it takes from you, usually into its pack.

const SWEEP_RADIUS := 7.5
const SWEEP_HALF_DEG := 55.0
const PADDLE_REACH := 1.6
const BAT := 0.35
const KNOCK := 16.0
const HP := 45.0

var swats := 0
var _paddle: Node3D
var _sweep_dir := Vector3.RIGHT
var _swung := false


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.6
	walk_speed = 4.2
	keep_near = 3.0
	keep_far = 26.0
	attack_range = 7.0
	warn_seconds = 0.8
	live_seconds = BAT + 0.05
	rest_seconds = 2.4


func _build_tool() -> void:
	_paddle = Node3D.new()
	_paddle.position = Vector3(0.0, -CREW_HALF + 0.5, 0.0)
	add_child(_paddle)
	_box(Vector3(0.2, 0.2, 5.5), Palette.CHARCOAL, Vector3(0.0, 0.0, 2.9), 0.0, _paddle)
	_box(Vector3(0.3, 1.0, 1.6), Palette.RUST.darkened(0.2), Vector3(0.0, 0.2, 5.4), 0.0, _paddle)
	_box(Vector3(0.32, 0.18, 1.62), Palette.HAZARD, Vector3(0.0, 0.62, 5.4), 0.6, _paddle)


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	_swung = false
	var heading := to_ball.normalized() if to_ball.length() > 0.1 else Vector3.FORWARD
	_sweep_dir = heading.cross(Vector3.UP) * (1.0 if _strafe > 0.0 else -1.0)
	_clear_telegraph()
	_telegraph = Telegraph.wedge(world_root, terrain, Threat.Type.INSTANT, global_position, heading, SWEEP_RADIUS, SWEEP_HALF_DEG, PADDLE_REACH)
	return _telegraph


func _go_live() -> void:
	_swung = true
	swats += 1
	var wedge := telegraph()
	if wedge == null or not wedge.contains(_real_ball()):
		broken_by = "missed"
		return
	var step := get_physics_process_delta_time()
	_catch(BAT, _sweep_dir * KNOCK / step)


func _live(_delta: float) -> bool:
	return _holding()


func _pose() -> void:
	if _paddle == null:
		return
	var swing := 0.0
	if phase == Phase.WARN:
		swing = -0.6 * clampf(_t / warn_seconds, 0.0, 1.0)
	elif phase == Phase.LIVE:
		swing = 1.2
	_paddle.rotation.y = swing * (1.0 if _strafe > 0.0 else -1.0)
