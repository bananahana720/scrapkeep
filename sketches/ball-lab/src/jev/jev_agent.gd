extends "res://src/intent.gd".Source

# The Jev player's hands (plan section 2, "Input seam" and "Steering at 90 Hz"). It is
# installed as `player.source` and polled once per physics tick, so it only ever
# produces the same stick, jump, boost and brake input a person would. Installing
# itself is its one write; everything else it only reads.
#
# Usage: `var agent := JevAgent.new(lab)`, `agent.install()`, then `agent.hold(id, goal)`
# whenever an intent is applied. `goal` is optional: {"point": Vector3} or
# {"waypoints": [Vector3, ...]} for push_objective, {"enemy": index} for the others.
# hold() reads the ball's position, so call it at least one physics tick after
# `Scenarios.place()`: a rigid teleport lands a tick late (JL-10 review, N1).

const Field := preload("res://src/field.gd")
const Tuning := preload("res://src/tuning.gd")
const SpeedTier := preload("res://src/speed_tier.gd")
const Scenarios := preload("res://src/jev/scenarios.gd")

const INTENTS := ["push_objective", "hit_kicker", "stomp_target", "ram_target", "evade_hazard"]

const WAYPOINT_RADIUS := 3.0
const ARRIVE_RADIUS := 1.5
# The deceleration an arrival plans for: well inside drive plus brake on flat ground.
const ARRIVE_DECEL := 8.0
const BRAKE_MIN_SPEED := 3.0
# Velocity more than 60 degrees off the line to the aim is an overshoot.
const OVERSHOOT_COS := 0.5
# Boost only when the velocity is within 8 degrees of the aim (cos 8° = 0.990).
const BOOST_ALIGN_COS := 0.990
# Boost on a leg longer than this; a boost into a ramp's foot only bounces the ball.
const PUSH_BOOST_LEG := 25.0
# A waypoint this far above the ball and this close is a step to jump, not a slope.
const STEP_UP := 2.0
const STEP_REACH := 6.5
# Dummies chase the ball, so a push steers round any inside this corridor ahead.
const AVOID_AHEAD := 9.0
const AVOID_WIDTH := 3.5
# A held jump wish presses again after this many ticks, inside the 0.14 s jump buffer,
# so a grounded flag that flickers (rigid mode) still catches one.
const JUMP_REPEAT := 12
# Rigid mode's probe misses the ground often while rolling; within this height of the
# field the ball is treated as on it.
const NEAR_GROUND := 1.4

# Stuck: on the ground, under STUCK_MOVE metres in STUCK_WINDOW ticks while the aim is
# further away than that. It ends once the ball is UNSTUCK_MOVE metres from where it
# stuck.
const STUCK_WINDOW := 45
const STUCK_MOVE := 1.0
const UNSTUCK_MOVE := 2.5
const UNSTICK_TICKS := 40

const STOMP_JUMP_MIN := 3.0
const STOMP_JUMP_PER_SPEED := 0.7
# Ball centre above the dummy's centre when it comes down on the capsule's top.
const STOMP_CLEAR := 2.5
const STOMP_ABOVE := 1.0
# A ram needs fast tier at contact: boost when that boost lands the hit within this
# long, with this much speed to spare.
const RAM_BOOST_WINDOW := 0.6
const RAM_MARGIN := 3.0
# A rigid ball kept rolling holds 5/7 of a central impulse once it spins up; the plan
# uses that share in both modes.
const BOOST_KEPT := 5.0 / 7.0
const RAM_RUNUP := 8.0
const EVADE_CARROT := 20.0
const EVADE_RANGE := 60.0

# The steep kicker, as field.gd _build_props builds it: box size and tilt about +x.
# Scenarios.STEEP_KICKER is its origin. JevState.KICKER_AT is that origin too, the ramp's
# centre; hit_kicker aims at the lip computed here instead.
const KICKER_SIZE := Vector3(15.0, 1.6, 19.0)
const KICKER_TILT_DEG := -34.0
# The run-up starts where scenarios.gd kicker_gap spawns: the southmost flat on the
# kicker's axis before the banked ring's outer lip.
const KICKER_RUNUP_Z := 28.0
const KICKER_LANE := 1.2
const KICKER_LANE_LOST := 3.0

var lab
var intent_id := ""
var goal := {}
var stuck := false
var phase := ""

var _waypoints: Array = []
var _next := 0
var _from := Vector3.ZERO
var _evade_dir := Vector3.ZERO
var _stomp_flight := false
var _since_jump := JUMP_REPEAT
var _trail := PackedVector3Array()
var _stuck_at := Vector3.ZERO
var _stuck_ticks := 0
var _unstick_side := 1.0

var _at := Vector3.ZERO
var _v := Vector3.ZERO
var _state
var _basis := Basis.IDENTITY
var _cruise := 14.0


func _init(lab_ref) -> void:
	lab = lab_ref


func install() -> void:
	lab.player.source = self


# Applies an intent. Everything the previous intent was doing is dropped.
func hold(id: String, goal_ref := {}) -> void:
	assert(INTENTS.has(id), "jev_agent: ball-lab cannot execute %s" % id)
	intent_id = id
	goal = goal_ref
	phase = ""
	_waypoints = []
	_next = 0
	_from = lab.player.ball_position()
	_evade_dir = Vector3.ZERO
	_stomp_flight = false
	_trail.clear()
	stuck = false
	_stuck_ticks = 0
	if id == "push_objective":
		var points: Array = goal.get("waypoints", [])
		if points.is_empty():
			points = route_to(_from, goal.get("point", _pad_point()))
		_waypoints = points


func poll(out) -> void:
	out.clear()
	if lab == null or lab.player == null or intent_id == "":
		return
	var player = lab.player
	_state = player.state
	_at = player.ball_position()
	_v = _state.velocity
	_basis = player.drive_basis
	_cruise = lab.tuning.f("cruise")
	var aim := _at
	match intent_id:
		"push_objective":
			aim = _push(out)
		"hit_kicker":
			aim = _kicker(out)
		"stomp_target":
			aim = _stomp(out)
		"ram_target":
			aim = _ram(out)
		"evade_hazard":
			aim = _evade(out)
	if _track_stuck(aim):
		_unstick(out, aim)
	var want_jump: bool = out.jump_pressed
	# Jump is an edge: one tick pressed, then released until JUMP_REPEAT ticks pass.
	out.jump_pressed = want_jump and _since_jump >= JUMP_REPEAT
	_since_jump = 0 if out.jump_pressed else _since_jump + 1


# --- the shared steering ---------------------------------------------------------

# The stick that makes ball_rules.gd wish_direction (line 48) return `direction`:
# wish = B.x·move.x − B.z·move.y, so move = (d·B.x, −d·B.z) for a yaw basis.
static func stick_for(direction: Vector3, drive_basis: Basis) -> Vector2:
	return Vector2(direction.dot(drive_basis.x), -direction.dot(drive_basis.z))


# Steers toward `point` on the ground plane. `arrive` sheds speed to stop inside
# ARRIVE_RADIUS; otherwise the ball keeps any speed above cruise and only corrects
# sideways. Brakes when the velocity overshoots the line. Returns the unit direction
# to the point, for boost and jump decisions.
func seek(out, point: Vector3, arrive := false, avoid := false) -> Vector3:
	var to := _flat(point - _at)
	var dist := to.length()
	if dist < 0.05:
		return Vector3.ZERO
	var dir := to / dist
	if avoid:
		dir = _around_enemies(dir, minf(dist, AVOID_AHEAD))
	var vh := _flat(_v)
	var speed := vh.length()
	var want := maxf(_cruise, speed)
	if arrive:
		want = minf(_cruise, sqrt(2.0 * ARRIVE_DECEL * maxf(0.0, dist - ARRIVE_RADIUS)))
	var steer := dir * want - vh
	var heading := steer.normalized() if steer.length() > 0.5 else dir
	out.move = stick_for(heading, _basis)
	var closing := vh.dot(dir)
	var overshoot := speed > BRAKE_MIN_SPEED and closing < speed * OVERSHOOT_COS
	var too_fast := arrive and closing > want + 1.5
	out.brake_held = _state.grounded and (overshoot or too_fast)
	return dir


# Bends `dir` away from every dummy in the corridor `ahead` metres long in front of the
# ball, harder the closer and more central it is.
func _around_enemies(dir: Vector3, ahead: float) -> Vector3:
	var bent := dir
	for enemy in lab.enemies:
		var rel := _flat(enemy.global_position - _at)
		var along := rel.dot(dir)
		if along <= 0.0 or along >= ahead:
			continue
		var lateral := rel - dir * along
		var off := lateral.length()
		if off >= AVOID_WIDTH:
			continue
		var side := -lateral / off if off > 0.01 else Vector3.UP.cross(dir)
		bent += side * 2.0 * (1.0 - off / AVOID_WIDTH) * (1.0 - along / ahead)
	return bent.normalized()


# Steers the planar velocity toward `want` (used in the air, where there is no line).
func steer_velocity(out, want: Vector3) -> void:
	var steer := want - _flat(_v)
	if steer.length() > 0.3:
		out.move = stick_for(steer.normalized(), _basis)


func _near_ground() -> bool:
	return _state.grounded or (_at.y - Field.height(_at.x, _at.z) < NEAR_GROUND and absf(_v.y) < 2.0)


func boost_if_aligned(out, dir: Vector3, min_speed: float) -> void:
	var vh := _flat(_v)
	var speed := vh.length()
	if _state.boost_cooldown <= 0.0 and speed >= min_speed and vh.dot(dir) >= speed * BOOST_ALIGN_COS:
		out.boost_pressed = true


# --- intents ------------------------------------------------------------------------

func _push(out) -> Vector3:
	while _next < _waypoints.size() - 1 and _passed(_next):
		_next += 1
	var point: Vector3 = _waypoints[_next]
	var last := _next == _waypoints.size() - 1
	var climb := point.y - _at.y
	var level := absf(climb) < STEP_UP
	var dir := seek(out, point, last, level)
	var leg := _flat(point - _at).length()
	if level and leg > PUSH_BOOST_LEG and _state.grounded:
		boost_if_aligned(out, dir, _cruise * 0.9)
	if climb > STEP_UP and leg < STEP_REACH:
		out.jump_pressed = true
	phase = "waypoint %d/%d" % [_next + 1, _waypoints.size()]
	return point


# Reached, or overshot along the leg into it, at the waypoint's own height: a ball
# that fell off a ramp beside a waypoint has not passed it.
func _passed(i: int) -> bool:
	var point: Vector3 = _waypoints[i]
	if absf(point.y - _at.y) >= STEP_UP:
		return false
	var offset := _flat(_at - point)
	if offset.length() <= WAYPOINT_RADIUS:
		return true
	var before: Vector3 = _from if i == 0 else _waypoints[i - 1]
	var leg := _flat(point - before).normalized()
	return offset.dot(leg) > 0.0 and (offset - leg * offset.dot(leg)).length() <= WAYPOINT_RADIUS


# The run-up: line up on the kicker's axis at the run-up point, drive straight at the
# lip with every aligned boost, then hold the heading in the air. At the top of the
# flight the air jump is spent if the ballistic landing falls short of the bench.
func _kicker(out) -> Vector3:
	var frame := kicker_frame()
	var lip: Vector3 = frame["lip"]
	var axis: Vector3 = frame["axis"]
	var runup: Vector3 = frame["runup"]
	var along := _flat(_at - runup).dot(axis)
	var lateral := _flat(_at - runup - axis * along).length()
	if phase == "air" and _state.grounded:
		phase = "landed"
	if phase == "landed":
		seek(out, Scenarios.Geo.bench_point(), true)
		return Scenarios.Geo.bench_point()
	if phase == "run" and not _state.grounded and _flat(_at - lip).dot(axis) > -3.0:
		phase = "air"
	if phase == "air":
		out.move = stick_for(axis, _basis)
		# Just off the lip the coyote window still allows a ground jump, straight up and
		# without spending the air jump.
		if _state.coyote > 0.0:
			out.jump_pressed = true
		elif _v.y <= 0.0 and _state.air_actions > 0 and _landing_z(Field.BENCH_TOP + 1.0) < _bench_near_edge() + 3.0:
			out.jump_pressed = true
		return lip
	if phase == "run" and lateral > KICKER_LANE_LOST:
		phase = ""
	if phase != "run":
		phase = "line_up"
		seek(out, runup, true)
		if _flat(_at - runup).length() <= KICKER_LANE * 2.0 and _flat(_v).length() < 3.0:
			phase = "run"
		return runup
	var dir := seek(out, lip)
	boost_if_aligned(out, dir, 2.5)
	return lip


# Where the ball comes down through `height` along +z, the kicker's axis.
func _landing_z(height: float) -> float:
	var g: float = lab.tuning.f("gravity")
	var drop := _at.y - height
	var t := (_v.y + sqrt(maxf(0.0, _v.y * _v.y + 2.0 * g * drop))) / g
	return _at.z + _v.z * t


func _bench_near_edge() -> float:
	return Field.BENCH_CENTER.y - Field.BENCH_HALF.y


func _stomp(out) -> Vector3:
	var enemy = _enemy()
	if enemy == null:
		return _at
	var target: Vector3 = enemy.global_position
	var offset := _flat(target - _at)
	# The ground probe also finds a dummy's head, so a ball above the dummy is falling
	# onto it, not approaching.
	if _near_ground() and _at.y < target.y + STOMP_ABOVE:
		phase = "approach"
		var dir := seek(out, target)
		var closing := (_flat(_v) - _flat(enemy.velocity)).dot(dir)
		if closing > 1.0 and offset.length() <= maxf(STOMP_JUMP_MIN, STOMP_JUMP_PER_SPEED * closing):
			out.jump_pressed = true
			_stomp_flight = true
		return target
	# In the air, steer so the ball is over the dummy when it comes down to stomp
	# height. Once a stomp jump has been pressed, sinking past that height beside the
	# dummy spends the air jump to try again.
	phase = "air"
	var t := _time_to_height(target.y + STOMP_CLEAR)
	steer_velocity(out, offset / maxf(t, 0.1))
	var missed := _v.y < 0.0 and _at.y < target.y + STOMP_CLEAR - 0.8 and offset.length() > 1.5
	if _stomp_flight and missed and _state.air_actions > 0:
		out.jump_pressed = true
	return target


# Seconds until the ball's centre comes down through `height`, or 0 if it never will.
func _time_to_height(height: float) -> float:
	var g: float = lab.tuning.f("gravity")
	var disc := _v.y * _v.y + 2.0 * g * (_at.y - height)
	if disc < 0.0:
		return 0.0
	return maxf(0.0, (_v.y + sqrt(disc)) / g)


# Aims where the target will be when the ball arrives. The boost is timed so the hit
# lands at fast tier or above; too close and too slow for that, it backs off first.
func _ram(out) -> Vector3:
	var enemy = _enemy()
	if enemy == null:
		return _at
	var target: Vector3 = enemy.global_position
	var dist := _flat(target - _at).length()
	var speed := _flat(_v).length()
	var fast := _cruise * SpeedTier.MULTIPLES[SpeedTier.FAST]
	var reserve := Tuning.BOOST_IMPULSE if _state.boost_cooldown <= 0.0 else 0.0
	if phase == "back_off" and dist >= RAM_RUNUP:
		phase = ""
	if phase == "back_off" or (dist < RAM_RUNUP * 0.5 and speed + reserve < fast + RAM_MARGIN):
		phase = "back_off"
		var away := _flat(_at - target).normalized() if dist > 0.1 else -_basis.z
		seek(out, target + away * RAM_RUNUP * 1.5)
		return target + away * RAM_RUNUP * 1.5
	phase = "lead"
	var lead: Vector3 = target + _flat(enemy.velocity) * (dist / maxf(speed, _cruise))
	var dir := seek(out, lead)
	var boosted := speed + Tuning.BOOST_IMPULSE * BOOST_KEPT
	var timed := boosted >= fast + RAM_MARGIN and dist <= boosted * RAM_BOOST_WINDOW
	if _near_ground() and (speed >= _cruise * 0.9 or timed):
		boost_if_aligned(out, dir, 2.5)
	return lead


# Breaks off at right angles to the line from the threat, which is a homing chaser's
# approach, and keeps that heading for the whole hold so the chaser cannot turn it into
# a circle. The side is the one the ball is already moving toward, else the left.
func _evade(out) -> Vector3:
	var enemy = _enemy()
	if enemy == null:
		return _at
	if _evade_dir == Vector3.ZERO:
		var line := _flat(_at - enemy.global_position)
		if line.length() < 0.1:
			line = -_basis.z
		_evade_dir = Vector3.UP.cross(line.normalized())
		if _evade_dir.dot(_flat(_v)) < -1.0:
			_evade_dir = -_evade_dir
	var carrot := _at + _evade_dir * EVADE_CARROT
	var dir := seek(out, carrot)
	if _near_ground():
		boost_if_aligned(out, dir, 2.5)
	phase = "break"
	return carrot


# The goal's enemy, or the nearest within EVADE_RANGE (closing first, for evade).
func _enemy():
	if goal.has("enemy"):
		var i: int = goal["enemy"]
		return lab.enemies[i] if i >= 0 and i < lab.enemies.size() else null
	var best = null
	var best_d := EVADE_RANGE
	for enemy in lab.enemies:
		var offset: Vector3 = enemy.global_position - _at
		var d := offset.length()
		if intent_id == "evade_hazard" and offset.dot(enemy.velocity - _v) >= 0.0:
			d += EVADE_RANGE
		if d < best_d:
			best_d = d
			best = enemy
	return best


# --- unstick ------------------------------------------------------------------------

func _track_stuck(aim: Vector3) -> bool:
	_trail.append(_at)
	if _trail.size() > STUCK_WINDOW:
		_trail.remove_at(0)
	if stuck:
		if _at.distance_to(_stuck_at) >= UNSTUCK_MOVE:
			stuck = false
			_trail.clear()
		return stuck
	var wants_move := _flat(aim - _at).length() > STUCK_MOVE + ARRIVE_RADIUS
	if wants_move and _near_ground() and _trail.size() == STUCK_WINDOW and _at.distance_to(_trail[0]) < STUCK_MOVE:
		stuck = true
		_stuck_at = _at
		_stuck_ticks = 0
	return stuck


# Backs off to one side with a jump for UNSTICK_TICKS, then lets the intent's own
# steering try again for a stuck window; each attempt takes the other side.
func _unstick(out, aim: Vector3) -> void:
	var k := _stuck_ticks % (UNSTICK_TICKS + STUCK_WINDOW)
	_stuck_ticks += 1
	if k >= UNSTICK_TICKS:
		return
	if k == 0:
		_unstick_side = -_unstick_side
	var to := _flat(aim - _at)
	var away := -to.normalized() if to.length() > 0.01 else _basis.z
	var side := Vector3.UP.cross(away) * _unstick_side
	out.move = stick_for((side + away * 0.5).normalized(), _basis)
	out.brake_held = false
	out.boost_pressed = false
	out.jump_pressed = k < 4


# --- field geometry -----------------------------------------------------------------

# The steep kicker's lip (top edge of the ramp surface), its heel, the horizontal axis
# it launches along and the run-up point on that axis, from field.gd's box and tilt.
static func kicker_frame() -> Dictionary:
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(KICKER_TILT_DEG))
	var origin: Vector3 = Scenarios.STEEP_KICKER
	var lip := origin + tilt * Vector3(0.0, KICKER_SIZE.y * 0.5, KICKER_SIZE.z * 0.5)
	var heel := origin + tilt * Vector3(0.0, KICKER_SIZE.y * 0.5, -KICKER_SIZE.z * 0.5)
	var axis := Vector3(lip.x - heel.x, 0.0, lip.z - heel.z).normalized()
	var runup := Field.drop_point(origin.x, KICKER_RUNUP_Z, 1.0)
	return {"lip": lip, "heel": heel, "axis": axis, "runup": runup}


# Waypoints to `point`. A point on the bench from below goes by the service ramp:
# the flat short of its foot, near its top, then onto the bench's north-east corner.
static func route_to(from: Vector3, point: Vector3) -> Array:
	var bench := Vector2(point.x, point.z) - Field.BENCH_CENTER
	var on_bench := absf(bench.x) <= Field.BENCH_HALF.x and absf(bench.y) <= Field.BENCH_HALF.y \
		and point.y >= Field.BENCH_TOP
	if not on_bench or from.y >= Field.BENCH_TOP:
		return [point]
	var ramp: Vector3 = Scenarios.SERVICE_RAMP
	var half: Vector2 = Scenarios.SERVICE_RAMP_HALF
	return [
		Field.drop_point(ramp.x, ramp.z - half.y - 4.0, 1.0),
		# On the landing at the ramp's top; its south face stands above the ramp, so
		# the ball jumps onto it (STEP_UP).
		Vector3(ramp.x, Field.BENCH_TOP + 1.0, ramp.z + half.y - 7.0),
		Vector3(Field.BENCH_CENTER.x + Field.BENCH_HALF.x - 2.0, Field.BENCH_TOP + 1.0,
			Field.BENCH_CENTER.y + Field.BENCH_HALF.y - 2.0),
		point,
	]


static func _pad_point() -> Vector3:
	return Field.drop_point(Field.PAD_CENTER.x, Field.PAD_CENTER.y, 1.0)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
