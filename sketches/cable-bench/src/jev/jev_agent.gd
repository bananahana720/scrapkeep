extends "res://src/intent.gd".Source

# The Jev player's hands on Cable Bench (JL-26; ball-lab's jev_agent.gd is the
# reference, and seek, boost, stomp, ram, evade and unstick are its code with the
# stage's names). It is installed as `player.source` and polled once per physics tick,
# so it only produces the stick, jump, boost and brake a person would. The E key is the
# one input the stage reads outside the source: take_cache and start_exit press it by
# calling stage.interact(), the body of stage.gd's KEY_E handler.
#
# Usage: `var agent := JevAgent.new(stage, view)`, `agent.install()`, then
# `agent.hold(id, goal)` whenever an intent is applied. `goal` is optional: {"point":
# Vector3} for push_objective, {"cache": node}, {"mesa": index}, {"foe": node} or
# {"threat": JevState entry}. Call hold() at least one physics tick after
# `Scenarios.place()`: a rigid teleport lands a tick late (JL-10 review, N1).

const Layout := preload("res://src/layout.gd")
const Tuning := preload("res://src/tuning.gd")
const SpeedTier := preload("res://src/speed_tier.gd")
const RunState := preload("res://src/run_state.gd")
const JevState := preload("res://src/jev/jev_state.gd")

const INTENTS := ["push_objective", "sweep_scrap", "take_cache", "hit_kicker", "stomp_target",
	"ram_target", "evade_hazard", "retreat_regen", "start_exit"]

# The switchbacks: from anywhere on bench k, these points cross it and climb road k to
# bench k + 1. Each crossing keeps 22 m or more off the bench's mesa on its wall side
# and 5 m or more off the horseshoe of plate on bench 2.
const ROUTE := [
	[Vector2(-126.0, 148.0), Vector2(-130.0, 102.0)],
	[Vector2(100.0, 102.0), Vector2(126.0, 84.0), Vector2(130.0, 36.0)],
	[Vector2(-110.0, 36.0), Vector2(-124.0, 12.0), Vector2(-124.0, -30.0)],
	[Vector2(110.0, -30.0), Vector2(126.0, -50.0), Vector2(130.0, -96.0)],
	[Vector2(10.0, -98.0), Vector2(0.0, -110.0), Vector2(0.0, -150.0)],
]

const WAYPOINT_RADIUS := 4.0
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
# Mesas are walled on every side but the chute, so a line past one bends round it.
const MESA_AHEAD := 40.0
const MESA_CLEAR := 22.0
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
const TARGET_RANGE := 60.0
const SWEEP_REACH := 60.0
const RETREAT_CARROT := 30.0
const RETREAT_EDGE := 150.0
# The kicker: start the run when this close to the run-up point; give it up and line
# up again when this far off the axis or this slow on the ground.
const KICKER_START := 6.0
const KICKER_LANE_LOST := 6.0
const KICKER_STALL := 3.0
# Past this far along the run-up a slow ball has stalled rather than not started.
const KICKER_STALL_ALONG := 30.0
# The charge circle: inside the 30 m ring with room to spare, aiming this far round.
const RING_RADIUS := 18.0
const RING_LEAD := 0.7

var stage
var view
var intent_id := ""
var goal := {}
var stuck := false
var phase := ""
# E presses this trial: {tick, intent, said}.
var presses: Array = []

var _waypoints: Array = []
var _next := 0
var _from := Vector3.ZERO
var _evade_dir := Vector3.ZERO
var _retreat_dir := Vector3.ZERO
var _stomp_flight := false
var _since_jump := JUMP_REPEAT
var _trail := PackedVector3Array()
var _stuck_at := Vector3.ZERO
var _stuck_ticks := 0
var _unstick_side := 1.0
var _pressed := false

var _at := Vector3.ZERO
var _v := Vector3.ZERO
var _state
var _basis := Basis.IDENTITY
var _cruise := 14.0


func _init(stage_ref, view_ref) -> void:
	stage = stage_ref
	view = view_ref


func install() -> void:
	stage.player.source = self


# Applies an intent. A new intent, or the same one on another target, drops everything
# the previous one was doing. The same intent on the same target continues: a kicker
# run-up spans several holds, and restarting it at every snapshot brakes the ball back
# to the run-up point.
func hold(id: String, goal_ref := {}) -> void:
	assert(INTENTS.has(id), "jev_agent: cable-bench cannot execute %s" % id)
	if id == intent_id and _continues(id, goal_ref):
		goal = goal_ref
		return
	intent_id = id
	goal = goal_ref
	phase = ""
	_waypoints = []
	_next = 0
	_from = stage.player.ball_position()
	_evade_dir = Vector3.ZERO
	_retreat_dir = Vector3.ZERO
	_stomp_flight = false
	_pressed = false
	_trail.clear()
	stuck = false
	_stuck_ticks = 0
	if id == "push_objective" or id == "start_exit":
		_waypoints = route_to(_from, goal.get("point", forge_point()))


func _continues(id: String, goal_ref: Dictionary) -> bool:
	match id:
		"hit_kicker":
			return goal_ref.get("mesa", -1) == goal.get("mesa", -1)
		"retreat_regen":
			return true
	return false


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
	if not stage.run.live():
		return
	var aim := _at
	match intent_id:
		"push_objective":
			aim = _push(out)
		"sweep_scrap":
			aim = _sweep(out)
		"take_cache":
			aim = _cache(out)
		"hit_kicker":
			aim = _kicker(out)
		"stomp_target":
			aim = _stomp(out)
		"ram_target":
			aim = _ram(out)
		"evade_hazard":
			aim = _evade(out)
		"retreat_regen":
			aim = _retreat(out)
		"start_exit":
			aim = _exit(out)
	if _track_stuck(aim):
		_unstick(out, aim)
	var want_jump: bool = out.jump_pressed
	out.jump_pressed = want_jump and _since_jump >= JUMP_REPEAT
	_since_jump = 0 if out.jump_pressed else _since_jump + 1


# --- the shared steering -----------------------------------------------------------

static func stick_for(direction: Vector3, drive_basis: Basis) -> Vector2:
	return Vector2(direction.dot(drive_basis.x), -direction.dot(drive_basis.z))


func seek(out, point: Vector3, arrive := false, avoid := false) -> Vector3:
	var to := _flat(point - _at)
	var dist := to.length()
	if dist < 0.05:
		return Vector3.ZERO
	var dir := to / dist
	if avoid:
		dir = _around_foes(dir, minf(dist, AVOID_AHEAD))
	dir = _around_mesas(dir, minf(dist, MESA_AHEAD))
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


func _around_foes(dir: Vector3, ahead: float) -> Vector3:
	var bent := dir
	for foe in view.foes(true):
		var rel := _flat(foe.global_position - _at)
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


# Bends round a mesa on the ball's line, unless the ball is on it or the line ends on
# it (a kicker or cache target).
func _around_mesas(dir: Vector3, ahead: float) -> Vector3:
	if JevState.mesa_under(_at) >= 0 or intent_id == "hit_kicker":
		return dir
	var bent := dir
	for m in Layout.MESAS:
		var centre: Vector2 = m["centre"]
		var rel := Vector3(centre.x - _at.x, 0.0, centre.y - _at.z)
		var along := rel.dot(dir)
		if along <= 0.0 or along >= ahead + MESA_CLEAR:
			continue
		var lateral := rel - dir * along
		var off := lateral.length()
		if off >= MESA_CLEAR:
			continue
		var side := -lateral / off if off > 0.01 else Vector3.UP.cross(dir)
		bent += side * 1.5 * (1.0 - off / MESA_CLEAR)
	return bent.normalized()


func steer_velocity(out, want: Vector3) -> void:
	var steer := want - _flat(_v)
	if steer.length() > 0.3:
		out.move = stick_for(steer.normalized(), _basis)


func _near_ground() -> bool:
	return _state.grounded or (_at.y - Layout.height(_at.x, _at.z) < NEAR_GROUND and absf(_v.y) < 2.0)


func boost_if_aligned(out, dir: Vector3, min_speed: float) -> void:
	var vh := _flat(_v)
	var speed := vh.length()
	if _state.boost_cooldown <= 0.0 and speed >= min_speed and vh.dot(dir) >= speed * BOOST_ALIGN_COS:
		out.boost_pressed = true


# Presses E once per hold; the stage decides what it does.
func _press(tick_note: String) -> void:
	if _pressed:
		return
	_pressed = true
	var said: String = stage.interact()
	presses.append({"tick": view.tick if view != null else -1, "intent": tick_note, "said": said})


# --- intents -----------------------------------------------------------------------

func _follow(out) -> Vector3:
	while _next < _waypoints.size() - 1 and _passed(_next):
		_next += 1
	var point: Vector3 = _waypoints[_next]
	var last := _next == _waypoints.size() - 1
	var climb := point.y - _at.y
	var dir := seek(out, point, last, true)
	var leg := _flat(point - _at).length()
	if leg > PUSH_BOOST_LEG and _state.grounded:
		boost_if_aligned(out, dir, _cruise * 0.9)
	if climb > STEP_UP and leg < STEP_REACH:
		out.jump_pressed = true
	phase = "waypoint %d/%d" % [_next + 1, _waypoints.size()]
	return point


func _push(out) -> Vector3:
	var goal_kind: String = view.objective()["kind"] if view != null and view.run != null else ""
	if goal_kind in ["forge", "exit"] and stage.run.phase != RunState.Phase.RUNNING:
		return _ring(out)
	return _follow(out)


# Passed when reached, or overshot along the leg into it. Roads climb, so height is not
# part of the test.
func _passed(i: int) -> bool:
	var point: Vector3 = _waypoints[i]
	var offset := _flat(_at - point)
	if offset.length() <= WAYPOINT_RADIUS:
		return true
	var before: Vector3 = _from if i == 0 else _waypoints[i - 1]
	var leg := _flat(point - before).normalized()
	return offset.dot(leg) > 0.0 and (offset - leg * offset.dot(leg)).length() <= WAYPOINT_RADIUS * 2.0


# Rolls through the nearest scrap on the ball's level; the 6 m magnet does the rest.
func _sweep(out) -> Vector3:
	var best = null
	var best_d := SWEEP_REACH
	for item in view.scrap_items():
		var p: Vector3 = item.position
		if absf(p.y - _at.y) > JevState.SWEEP_DROP:
			continue
		var d := _flat(p - _at).length()
		if d < best_d:
			best_d = d
			best = p
	if best == null:
		phase = "nothing"
		seek(out, _at + _flat(_v), true)
		return _at
	phase = "sweep"
	seek(out, best, false, true)
	return best


func _cache(out) -> Vector3:
	var cache = goal.get("cache")
	if cache == null or not is_instance_valid(cache) or cache.opened:
		phase = "done"
		seek(out, _at + _flat(_v), true)
		return _at
	var at: Vector3 = cache.global_position
	if cache.in_reach(_at):
		phase = "open"
		_press("take_cache")
		seek(out, at, true)
		return _at
	phase = "drive"
	seek(out, at, true, true)
	return at


# The run-up: line up on the kicker's axis at the run-up point, drive straight at the
# mesa with every aligned boost, hold the heading in the air, and roll to the mesa's
# cache once down on the top. A run that stalls on the ramp lines up again.
func _kicker(out) -> Vector3:
	var index: int = goal.get("mesa", -1)
	if index < 0:
		index = view.kicker_offer(_at)
	if index < 0:
		phase = "none"
		return _at
	var m: Dictionary = Layout.MESAS[index]
	var centre2: Vector2 = m["centre"]
	var top := Vector3(centre2.x, Layout.mesa_top(index) + Tuning.RADIUS, centre2.y)
	var axis := _flat(Layout.kicker_run_direction(index)).normalized()
	var runup := JevState.kicker_runup(index)
	var along := _flat(_at - runup).dot(axis)
	var lateral := (_flat(_at - runup) - axis * along).length()
	var xform := Layout.kicker_transform(index)
	var lip: Vector3 = xform.origin + xform.basis * Vector3(0.0, Layout.KICKER_SIZE.y * 0.5, Layout.KICKER_SIZE.z * 0.5)
	var past_lip := _flat(_at - lip).dot(axis) > -3.0
	if JevState.mesa_under(_at) == index and _state.grounded:
		phase = "landed"
	if phase == "landed":
		seek(out, top, true)
		return top
	if phase == "run" and not _state.grounded and past_lip:
		phase = "air"
	if phase == "air":
		out.move = stick_for(axis, _basis)
		var over := Vector2(_at.x, _at.z).distance_to(centre2) <= Layout.MESA_RADIUS
		if _state.coyote > 0.0:
			out.jump_pressed = true
		elif _v.y <= 0.0 and _state.air_actions > 0 and not over and _at.y < top.y + 1.0:
			out.jump_pressed = true
		if _state.grounded:
			phase = "run"
		return top
	if phase == "run" and (lateral > KICKER_LANE_LOST or (_state.grounded and along > KICKER_STALL_ALONG
			and _flat(_v).length() < KICKER_STALL)):
		phase = ""
	if phase != "run":
		phase = "line_up"
		seek(out, runup, true)
		var slow := _flat(_v).length() < 4.0
		if _flat(_at - runup).length() <= KICKER_START and (slow or _flat(_v).dot(axis) > 0.0):
			phase = "run"
		return runup
	var dir := seek(out, top)
	boost_if_aligned(out, dir, 2.5)
	return top



func _stomp(out) -> Vector3:
	var foe = _foe()
	if foe == null:
		return _at
	var target: Vector3 = foe.global_position
	var scale: float = foe.body_radius
	var offset := _flat(target - _at)
	# Ball-lab's test was height over the dummy alone, which on Cable Bench's slopes
	# reads a ball uphill of a foe as already in the air over it; so a ball on the
	# ground is approaching unless it is sitting on the foe's head.
	var on_head := offset.length() <= scale + Tuning.RADIUS and _at.y >= target.y + STOMP_ABOVE * scale
	if _near_ground() and not on_head:
		phase = "approach"
		var dir := seek(out, target)
		var closing := (_flat(_v) - _flat(foe.velocity)).dot(dir)
		if closing > 1.0 and offset.length() <= maxf(STOMP_JUMP_MIN * scale, STOMP_JUMP_PER_SPEED * closing):
			out.jump_pressed = true
			_stomp_flight = true
		return target
	phase = "air"
	var t := _time_to_height(target.y + STOMP_CLEAR * scale)
	steer_velocity(out, offset / maxf(t, 0.1))
	var missed := _v.y < 0.0 and _at.y < target.y + STOMP_CLEAR * scale - 0.8 and offset.length() > 1.5
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
	var foe = _foe()
	if foe == null:
		return _at
	var target: Vector3 = foe.global_position
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
	var lead: Vector3 = target + _flat(foe.velocity) * (dist / maxf(speed, _cruise))
	var dir := seek(out, lead)
	var boosted := speed + Tuning.BOOST_IMPULSE * BOOST_KEPT
	var timed := boosted >= fast + RAM_MARGIN and dist <= boosted * RAM_BOOST_WINDOW
	if _near_ground() and (speed >= _cruise * 0.9 or timed):
		boost_if_aligned(out, dir, 2.5)
	return lead


# Breaks off at right angles: to a foe's line of approach, off a cable's line, or away
# from a shot's landing point, and keeps that heading for the whole hold.
func _evade(out) -> Vector3:
	if _evade_dir == Vector3.ZERO:
		_evade_dir = _evade_heading()
	var carrot := _at + _evade_dir * EVADE_CARROT
	var dir := seek(out, carrot)
	if _near_ground():
		boost_if_aligned(out, dir, 2.5)
	phase = "break"
	return carrot


func _evade_heading() -> Vector3:
	var entry = goal.get("threat")
	if entry == null or not is_instance_valid(entry.get("node")):
		entry = view.evade_threat()
	var line := Vector3.ZERO
	if entry != null:
		match entry["kind"]:
			"cableway":
				var cw = entry["node"]
				var along := _flat(cw._to - cw._from).normalized()
				var side := Vector3.UP.cross(along)
				if _flat(_at - cw._from).dot(side) < 0.0:
					side = -side
				return side
			"lob":
				var away := _flat(_at - entry["point"])
				return away.normalized() if away.length() > 0.1 else -_basis.z
			_:
				line = _flat(_at - entry["node"].global_position)
	if line.length() < 0.1:
		line = -_basis.z
	var heading := Vector3.UP.cross(line.normalized())
	if heading.dot(_flat(_v)) < -1.0:
		heading = -heading
	return heading


# Backs away along the bench, away from the foes' side, so regen (5 s after the last
# hit) can start; boosts only when a foe is on top of the ball.
func _retreat(out) -> Vector3:
	if _retreat_dir == Vector3.ZERO:
		var pull := 0.0
		for foe in view.foes(true):
			var rel := _flat(foe.global_position - _at)
			if rel.length() <= TARGET_RANGE:
				pull += rel.x / maxf(1.0, rel.length())
		var sign_x := -1.0 if pull > 0.0 else 1.0
		if absf(_at.x) > RETREAT_EDGE:
			sign_x = -signf(_at.x)
		_retreat_dir = Vector3(sign_x, 0.0, 0.0)
	var carrot := _at + _retreat_dir * RETREAT_CARROT
	var dir := seek(out, carrot, false, true)
	var hunted := false
	for foe in view.foes(true):
		if foe.global_position.distance_to(_at) < 6.0:
			hunted = true
	if hunted and _near_ground():
		boost_if_aligned(out, dir, 2.5)
	phase = "retreat"
	return carrot


# Rolls to the rig and presses E there to start the charge, then keeps the ring (see
# _ring); the stage takes the exit itself once the charge is full and the ball is on
# the rig.
func _exit(out) -> Vector3:
	if stage.run.phase == RunState.Phase.RUNNING and stage.forge.at_exit(_at):
		_press("start_exit")
	if stage.run.phase != RunState.Phase.RUNNING:
		return _ring(out)
	phase = "to rig"
	return _follow(out)


# While the forge charges, the ball circles inside the ring rather than parking, since
# the charge only needs the ball inside it and a parked ball is where the spiked
# director's foes converge. Once the charge is full it rolls onto the rig.
func _ring(out) -> Vector3:
	var centre := forge_point()
	if stage.run.phase != RunState.Phase.CHARGING:
		phase = "to rig"
		seek(out, centre, true)
		return centre
	phase = "circle"
	var offset := _flat(_at - centre)
	var angle := atan2(offset.z, offset.x) if offset.length() > 0.5 else 0.0
	angle += RING_LEAD
	var carrot := centre + Vector3(cos(angle), 0.0, sin(angle)) * RING_RADIUS
	seek(out, carrot, false, true)
	return carrot


# The goal's foe while it is live and not knocked, else the nearest such foe.
func _foe():
	var foe = goal.get("foe")
	if foe != null and is_instance_valid(foe) and not foe.is_queued_for_deletion() \
			and not view.knocked.has(String(foe.name)):
		return foe
	var best = null
	var best_d := TARGET_RANGE
	for candidate in view.foes():
		var d: float = candidate.global_position.distance_to(_at)
		if d < best_d:
			best_d = d
			best = candidate
	return best


# --- unstick -----------------------------------------------------------------------

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


# --- stage geometry ----------------------------------------------------------------

# Waypoints to `point`: off a mesa by its chute first, then the rest of each bench's
# switchback up to the point's bench. A point on the ball's bench or below is driven
# to directly.
static func route_to(from: Vector3, point: Vector3) -> Array:
	var out := []
	var here := Vector2(from.x, from.z)
	var mesa := JevState.mesa_under(from)
	if mesa >= 0:
		var m: Dictionary = Layout.MESAS[mesa]
		var chute: Vector2 = (m["chute"] as Vector2).normalized()
		var foot: Vector2 = (m["centre"] as Vector2) + chute * (Layout.MESA_RADIUS + Layout.MESA_CHUTE + 3.0)
		out.append(Layout.drop_at(foot, Tuning.RADIUS))
		here = foot
	var level := Layout.level_of(here.y)
	var goal_level := Layout.level_of(point.z)
	while level < goal_level and level < ROUTE.size():
		var legs: Array = ROUTE[level]
		var start := 0
		while start < legs.size() - 1:
			var this_leg: float = legs[start].distance_to(legs[start + 1])
			var skip_a: bool = here.distance_to(legs[start + 1]) < this_leg
			var skip_b: bool = here.distance_to(legs[start + 1]) < here.distance_to(legs[start])
			if not (skip_a or skip_b):
				break
			start += 1
		for i in range(start, legs.size()):
			out.append(Layout.drop_at(legs[i], Tuning.RADIUS))
		here = legs[legs.size() - 1]
		level += 1
	out.append(point)
	return out


static func forge_point() -> Vector3:
	return Layout.drop_at(Layout.FORGE, Tuning.RADIUS)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
