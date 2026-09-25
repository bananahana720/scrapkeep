extends "res://src/intent.gd".Source

# The Jev player's hands on Spillway Drop (JL-27; ball-lab's jev_agent.gd is the
# reference: seek, boost, stomp, ram, the break-off and unstick are carried over
# unchanged, and waypoint passing is widened for the chutes). It is installed as
# `player.source` and polled once per physics tick, so it only ever produces the stick,
# jump, boost and brake input a person would. Installing itself is its one write.
#
# Usage: `var agent := JevAgent.new(stage, view)`, `agent.install()`, then
# `agent.hold(id, goal)` whenever an intent is applied. `goal` is {"point": Vector3}
# for push_objective and hit_kicker; the others find their target each tick. `view` is
# the trial's JevState, read for the enemies still in play and the flood, so the agent
# targets exactly what the state shows.
#
# Intents:
#   push_objective  the guaranteed ground route (geo.gd ground_route): the bypass ramp
#                   going up, the straight line otherwise.
#   hit_kicker      commit to the chute toward the objective's shelf (geo.gd
#                   chute_route), boosting whenever aligned, up or down it.
#   sweep_scrap     the nearest scrap piece, re-picked every tick.
#   stomp_target, ram_target  ball-lab's, on the nearest enemy in play.
#   evade_hazard    out of the flood's reach by geo.gd refuge_route when the flood
#                   targets the ball, else ball-lab's break-off from the nearest threat.
#   retreat_regen   away from every enemy within range, still rolling at cruise.

const Terrain := preload("res://src/terrain.gd")
const Tuning := preload("res://src/tuning.gd")
const SpeedTier := preload("res://src/speed_tier.gd")
const Geo := preload("res://src/jev/geo.gd")

const INTENTS := ["push_objective", "hit_kicker", "sweep_scrap", "stomp_target", "ram_target", "evade_hazard",
	"retreat_regen"]

const WAYPOINT_RADIUS := 3.0
const ARRIVE_RADIUS := 1.5
const ARRIVE_DECEL := 8.0
const BRAKE_MIN_SPEED := 3.0
const OVERSHOOT_COS := 0.5
const BOOST_ALIGN_COS := 0.990
const PUSH_BOOST_LEG := 25.0
const STEP_UP := 2.0
const STEP_REACH := 6.5
const AVOID_AHEAD := 9.0
const AVOID_WIDTH := 3.5
const JUMP_REPEAT := 12
const NEAR_GROUND := 1.4

const STUCK_WINDOW := 45
const STUCK_MOVE := 1.0
const UNSTUCK_MOVE := 2.5
const UNSTICK_TICKS := 40

const STOMP_JUMP_MIN := 3.0
const STOMP_JUMP_PER_SPEED := 0.7
const STOMP_CLEAR := 2.5
const STOMP_ABOVE := 1.0
const RAM_BOOST_WINDOW := 0.6
const RAM_MARGIN := 3.0
const BOOST_KEPT := 5.0 / 7.0
const RAM_RUNUP := 8.0
const EVADE_CARROT := 20.0
const EVADE_RANGE := 60.0
const RETREAT_RANGE := 60.0
# A waypoint on a slope is passed within this height of the ball, not STEP_UP: the
# chute and ramp waypoints sit on the deck, and a ball on the bank beside one is level
# with it within a few metres.
const SLOPE_PASS := 4.0
const KERB_LOOK := 4.0

var stage
var view
var intent_id := ""
var goal := {}
var stuck := false
var phase := ""

var _waypoints: Array = []
var _next := 0
var _from := Vector3.ZERO
var _evade_dir := Vector3.ZERO
# True while evade_hazard is heading out of the flood by geo.gd refuge_route.
var _refuge := false
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


func _init(stage_ref, view_ref = null) -> void:
	stage = stage_ref
	view = view_ref


func install() -> void:
	stage.player.source = self


# Applies an intent. Everything the previous intent was doing is dropped.
func hold(id: String, goal_ref := {}) -> void:
	assert(INTENTS.has(id), "jev_agent: spillway-drop cannot execute %s" % id)
	intent_id = id
	goal = goal_ref
	phase = ""
	_waypoints = []
	_next = 0
	_from = stage.player.ball_position()
	_evade_dir = Vector3.ZERO
	_refuge = false
	_stomp_flight = false
	_trail.clear()
	stuck = false
	_stuck_ticks = 0
	var point: Vector3 = goal.get("point", _from)
	match id:
		"push_objective":
			_waypoints = Geo.ground_route(_from, point)
		"hit_kicker":
			_waypoints = Geo.chute_route(_from, point)
			if _waypoints.is_empty():
				_waypoints = Geo.ground_route(_from, point)
		"evade_hazard":
			if view != null and _flood_targets_ball():
				_waypoints = Geo.refuge_route(_from)
				_refuge = true


func poll(out) -> void:
	out.clear()
	if stage == null or stage.player == null or intent_id == "":
		return
	var player = stage.player
	_state = player.state
	_at = player.ball_position()
	_v = _state.velocity
	_basis = player.drive_basis
	_cruise = stage.tuning.f("cruise")
	var aim := _at
	match intent_id:
		"push_objective", "hit_kicker":
			aim = _follow(out, intent_id == "hit_kicker")
		"sweep_scrap":
			aim = _sweep(out)
		"stomp_target":
			aim = _stomp(out)
		"ram_target":
			aim = _ram(out)
		"evade_hazard":
			aim = _evade(out)
		"retreat_regen":
			aim = _retreat(out)
	if _track_stuck(aim):
		_unstick(out, aim)
	var want_jump: bool = out.jump_pressed
	out.jump_pressed = want_jump and _since_jump >= JUMP_REPEAT
	_since_jump = 0 if out.jump_pressed else _since_jump + 1


# --- the shared steering (ball-lab's, unchanged) ------------------------------------

static func stick_for(direction: Vector3, drive_basis: Basis) -> Vector2:
	return Vector2(direction.dot(drive_basis.x), -direction.dot(drive_basis.z))


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


func _around_enemies(dir: Vector3, ahead: float) -> Vector3:
	var bent := dir
	for enemy in _targets():
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


func steer_velocity(out, want: Vector3) -> void:
	var steer := want - _flat(_v)
	if steer.length() > 0.3:
		out.move = stick_for(steer.normalized(), _basis)


func _near_ground() -> bool:
	return _state.grounded or (_at.y - Terrain.height(_at.x, _at.z) < NEAR_GROUND and absf(_v.y) < 2.0)


func boost_if_aligned(out, dir: Vector3, min_speed: float) -> void:
	var vh := _flat(_v)
	var speed := vh.length()
	if _state.boost_cooldown <= 0.0 and speed >= min_speed and vh.dot(dir) >= speed * BOOST_ALIGN_COS:
		out.boost_pressed = true


# --- intents ------------------------------------------------------------------------

# Waypoint following for both routes. The chute commits: it boosts whenever aligned on
# any leg, including up the slope, where a boost is the only way to carry speed in.
func _follow(out, commit: bool) -> Vector3:
	while _next < _waypoints.size() - 1 and _passed(_next):
		_next += 1
	var point: Vector3 = _waypoints[_next]
	var last := _next == _waypoints.size() - 1
	var climb := point.y - _at.y
	var level := absf(climb) < STEP_UP
	var dir := seek(out, point, last, level)
	var leg := _flat(point - _at).length()
	if _near_ground() and ((level and leg > PUSH_BOOST_LEG) or (commit and not last)):
		boost_if_aligned(out, dir, _cruise * 0.5 if commit else _cruise * 0.9)
	if (climb > STEP_UP and leg < STEP_REACH) or _kerb_ahead(dir):
		out.jump_pressed = true
	phase = "waypoint %d/%d" % [_next + 1, _waypoints.size()]
	return point


# A rise of more than STEP_UP within KERB_LOOK metres along `dir`, taken slowly: the
# bypass deck's raised side (terrain.gd _bypass, up to 6 m at about 52 degrees) stands
# between the ramp and every shelf, and a slow rigid ball rides up its face and falls
# back (JL-27 probe) unless it jumps.
func _kerb_ahead(dir: Vector3) -> bool:
	if dir == Vector3.ZERO or not _near_ground() or _flat(_v).length() > _cruise:
		return false
	var ahead := _at + dir * KERB_LOOK
	return Terrain.height(ahead.x, ahead.z) - Terrain.height(_at.x, _at.z) > STEP_UP


# Ball-lab's rule, widened for the U-section chutes: within SLOPE_PASS of the
# waypoint's height, and up to twice WAYPOINT_RADIUS off the leg when overshooting.
func _passed(i: int) -> bool:
	var point: Vector3 = _waypoints[i]
	if absf(point.y - _at.y) >= SLOPE_PASS:
		return false
	var offset := _flat(_at - point)
	if offset.length() <= WAYPOINT_RADIUS:
		return true
	var before: Vector3 = _from if i == 0 else _waypoints[i - 1]
	var leg := _flat(point - before).normalized()
	return offset.dot(leg) > 0.0 and (offset - leg * offset.dot(leg)).length() <= WAYPOINT_RADIUS * 2.0


func _sweep(out) -> Vector3:
	var field = stage.scrap
	var best := _at
	var best_d := INF
	for i in field.count():
		var p: Vector3 = field.item_position(i)
		var d := _at.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	if best_d == INF:
		return _at
	var dir := seek(out, best, false, true)
	if _near_ground() and best_d > PUSH_BOOST_LEG:
		boost_if_aligned(out, dir, _cruise * 0.9)
	phase = "scrap"
	return best


func _stomp(out) -> Vector3:
	var enemy = _enemy()
	if enemy == null:
		return _at
	var target: Vector3 = enemy.global_position
	var offset := _flat(target - _at)
	if _near_ground() and _at.y < target.y + STOMP_ABOVE:
		phase = "approach"
		var dir := seek(out, target)
		var closing := (_flat(_v) - _flat(_enemy_velocity(enemy))).dot(dir)
		if closing > 1.0 and offset.length() <= maxf(STOMP_JUMP_MIN, STOMP_JUMP_PER_SPEED * closing):
			out.jump_pressed = true
			_stomp_flight = true
		return target
	phase = "air"
	var t := _time_to_height(target.y + STOMP_CLEAR)
	steer_velocity(out, offset / maxf(t, 0.1))
	var missed := _v.y < 0.0 and _at.y < target.y + STOMP_CLEAR - 0.8 and offset.length() > 1.5
	if _stomp_flight and missed and _state.air_actions > 0:
		out.jump_pressed = true
	return target


func _time_to_height(height: float) -> float:
	var g: float = stage.tuning.f("gravity")
	var disc := _v.y * _v.y + 2.0 * g * (_at.y - height)
	if disc < 0.0:
		return 0.0
	return maxf(0.0, (_v.y + sqrt(disc)) / g)


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
	var lead: Vector3 = target + _flat(_enemy_velocity(enemy)) * (dist / maxf(speed, _cruise))
	var dir := seek(out, lead)
	var boosted := speed + Tuning.BOOST_IMPULSE * BOOST_KEPT
	var timed := boosted >= fast + RAM_MARGIN and dist <= boosted * RAM_BOOST_WINDOW
	if _near_ground() and (speed >= _cruise * 0.9 or timed):
		boost_if_aligned(out, dir, 2.5)
	return lead


# Out of the flood by the refuge route picked at hold() when the flood targets the ball; else
# ball-lab's break-off at right angles to the nearest closing threat, kept for the hold.
func _evade(out) -> Vector3:
	if _refuge:
		var aim := _follow(out, false)
		phase = "refuge " + phase
		return aim
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


# Away from every live enemy in range, weighted by closeness, at cruise; a standing ball
# is what the lobbers punish, so it never stops while anything is near.
func _retreat(out) -> Vector3:
	var away := Vector3.ZERO
	for enemy in _targets():
		var rel := _flat(_at - enemy.global_position)
		var d := rel.length()
		if d < 0.1 or d > RETREAT_RANGE:
			continue
		away += rel / (d * d)
	if away.length() < 0.0001:
		phase = "rest"
		out.brake_held = _state.grounded
		return _at
	var carrot := _at + away.normalized() * EVADE_CARROT
	seek(out, carrot, false, true)
	phase = "retreat"
	return carrot


# The nearest enemy in play within EVADE_RANGE; for evade, closing ones first.
func _enemy():
	var best = null
	var best_d := EVADE_RANGE
	for enemy in _targets():
		var offset: Vector3 = enemy.global_position - _at
		var d := offset.length()
		if intent_id == "evade_hazard" and offset.dot(_enemy_velocity(enemy) - _v) >= 0.0:
			d += EVADE_RANGE
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _targets() -> Array:
	if view != null:
		return view.live_targets()
	var out := []
	for node in stage.get_tree().get_nodes_in_group("enemy"):
		if stage.is_ancestor_of(node):
			out.append(node)
	return out


static func _enemy_velocity(enemy) -> Vector3:
	return enemy.velocity if enemy is CharacterBody3D else Vector3.ZERO


func _flood_targets_ball() -> bool:
	var flood: Dictionary = view.flood_threat()
	return not flood.is_empty() and flood["targets_current_position"]


# --- unstick (ball-lab's) -----------------------------------------------------------

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


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
