extends "res://src/combat/enemy.gd"

# The chaser runs you down and lunges. The lunge is committed: at wind-up it lays a
# lane on the ground from where it stands toward where you are, and only that lane
# can hurt you, only while it is lunging down it. Roll off the lane, jump it, or hit
# the chaser hard enough during the wind-up to break it (a knock at INTERRUPT or more
# cancels the lunge and its lane together). Touching a chaser that is not lunging
# costs nothing but the bump.

const SPEED := 4.8
const LUNGE_RANGE := 10.0
const WINDUP := 0.6
const LUNGE_TIME := 0.34
const LUNGE_LENGTH := 11.0
const LUNGE_WIDTH := 2.8
const RECOVER := 0.9
const REST := 0.8
const DAMAGE := 9.0
const SHOVE := 6.0
const INTERRUPT := 10.0
const HP := 40.0
const SCRAP := 3

enum State { CHASE, WINDUP, LUNGE, RECOVER }

var state := State.CHASE
var lunges := 0

var _clock := 0.0
var _rest := 0.0
var _landed := false
var _mesh: MeshInstance3D


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	_setup_common(target_ref, terrain_ref, root_ref, live_ref, spec_ref)
	kind = "chaser"
	_set_health(HP * threat)
	scrap_value = SCRAP
	weight = 1.0
	radius = 1.0
	half_height = 1.5
	_mesh = _add_capsule(radius, half_height * 2.0, Palette.RUST)


func state_name() -> String:
	return ["chase", "windup", "lunge", "recover"][state]


func _physics_process(delta: float) -> void:
	_update_flash(delta)
	if not _in_play() or target == null:
		_move(delta, Vector3.ZERO)
		return
	_clock += delta
	_rest = maxf(0.0, _rest - delta)
	var to_ball := _flat_to_ball()
	match state:
		State.CHASE:
			var desired := Vector3.ZERO
			if to_ball.length() > radius + 1.4:
				desired = to_ball.normalized() * SPEED
			_move(delta, desired)
			if _rest <= 0.0 and to_ball.length() < LUNGE_RANGE and is_on_floor() and _knocked_speed() < 1.0:
				_begin_windup(to_ball)
		State.WINDUP:
			_move(delta, Vector3.ZERO)
			var lane := telegraph()
			if lane != null:
				lane.set_progress(_clock / WINDUP)
			if _knocked_speed() >= INTERRUPT or lane == null:
				_end_attack(State.RECOVER)
			elif _clock >= WINDUP:
				state = State.LUNGE
				_clock = 0.0
		State.LUNGE:
			var lane := telegraph()
			if lane == null:
				_end_attack(State.RECOVER)
				return
			_move(delta, lane.dir * LUNGE_LENGTH / LUNGE_TIME)
			_check_hit(lane)
			var along: float = (global_position - lane.center).dot(lane.dir)
			if _clock >= LUNGE_TIME or along >= lane.length:
				_end_attack(State.RECOVER)
		State.RECOVER:
			_move(delta, Vector3.ZERO)
			if _clock >= RECOVER:
				state = State.CHASE
				_clock = 0.0
	_pose()


func _begin_windup(to_ball: Vector3) -> void:
	state = State.WINDUP
	_clock = 0.0
	_landed = false
	_commit_lane(global_position, to_ball, LUNGE_LENGTH, LUNGE_WIDTH)


# The ball is hit when it is inside the committed lane and the chaser's body has
# reached it. Both halves read the same lane the player was shown.
func _check_hit(lane: Node3D) -> void:
	if _landed:
		return
	var ball := _ball()
	var flat := Vector3(ball.x - global_position.x, 0.0, ball.z - global_position.z)
	if flat.length() > radius + 1.4 or not lane.contains(ball):
		return
	_landed = true
	hit_player.emit(DAMAGE, lane.dir * SHOVE + Vector3.UP * 2.0)


func _end_attack(next: int) -> void:
	if state == State.LUNGE:
		lunges += 1
	state = next
	_clock = 0.0
	_rest = REST
	_clear_telegraph()


# The wind-up crouches and swells: a body read to match the ground read.
func _pose() -> void:
	if _mesh == null:
		return
	match state:
		State.WINDUP:
			var t := clampf(_clock / WINDUP, 0.0, 1.0)
			_mesh.scale = Vector3(1.0 + 0.2 * t, 1.0 - 0.25 * t, 1.0 + 0.2 * t)
		State.LUNGE:
			_mesh.scale = Vector3(0.85, 1.15, 0.85)
		_:
			_mesh.scale = Vector3.ONE
