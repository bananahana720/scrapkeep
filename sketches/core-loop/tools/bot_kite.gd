extends RefCounted

# The anti-kiting gates' two measuring policies (card G-A; rules in scrapkeep#241 comment 6367573974).
# Bot-tool only: nothing here ships. They steer through the driver's own hands (bot_driver.gd _act and _drive), so a
# gate measures the game and not a blind spot.
#
#   orbit    rolls to the nearest live pack enemy or Warden until first contact, fixes an anchor there (the centroid of
#            the live pack within the contact radius of the ball, else the nearest enemy's position) and circles that
#            fixed ground at ORBIT_RADIUS at the tuned cruise speed (src/movement/speed_tier.gd CRUISE), never
#            re-anchoring. It never aims a ram and it does not dodge (_act with evade false, so _threats and _escape
#            are skipped). Ranged units hold 20 to 40 m and retreat, so a ring on an enemy cannot be held; a ring on
#            fixed ground can ("circle or shuttle over the same ground in the open").
#   terrain  the same anchor and ring with the driver's default dodging, but it breaks the circle onto the nearest
#            line within TERRAIN_LINE_REACH and rides it when a read telegraph would hit, or after CIRCLE_BREAK_S of
#            continuous circling, then returns to the ring. A line is a cable contraption on the map, a park grind
#            line (a row whose ride fact is ride_grapple_line), or a world anchor the driver's swing hand
#            (_swing_hand) can bite. It never perches: the perch field does not exist yet.
#
# Stage-note fields both write (the gates read them): fight_s, circle_s, circle_share, line_rides, lines_in_reach,
# line_misses. The contact fields (first_contact_s, first_hit_s, hull_lost_120s, alive_120s, telegraph_reads) are kept
# for every policy by the driver itself.
#
# circle_s: the seconds within ORBIT_BAND of the ring, from first contact to the window's end (CONTACT_WINDOW_S);
# the driver divides it by alive_120s (first contact to the window's end or death) for circle_share. fight_s, kept as a
# field, is the seconds the nearest enemy stood within the contact radius. A stage with no line within reach reports
# lines_in_reach 0: the instrument is void for that stage and the harness says so; a ride is never faked.

const ORBIT_RADIUS := 14.0
const ORBIT_BAND := 3.0
# How far round the ring (radians) the steering point leads the ball.
const ORBIT_LEAD := 0.5
const CIRCLE_BREAK_S := 6.0
# A ball out of the band for this long no longer counts as circling continuously.
const CIRCLE_GAP_S := 1.0
const TERRAIN_LINE_REACH := 60.0
# The line a break heads for is given this long to take the ball, the swing hand this long to bite.
const LINE_TRY_S := 8.0
const SWING_TRY_S := 1.5
const LINE_GAP_S := 1.0
const RIDE_REST_S := 3.0
# The cable fact and the park's grind-line fact: both are a line ride.
const LINE_FACTS := ["ride_grapple_line"]
const PARK_LINE_ELEMENTS := ["grind_line", "elevated_line", "flow_line", "rail"]
const COAST_ABOVE := 1.05

var driver
var _target: Node3D = null
var _anchor := Vector3.INF
var _note_ref = null
var _dir := 1.0
var _state := "circle"
var _state_clock := 0.0
var _circle_clock := 0.0
var _circle_gap := 0.0
var _line_gap := 0.0
var _line_goal := Vector3.INF
var _hook_counted := false
var _swung := false
var _park_lines: Array = []
var _park_lines_stage := -1


func _init(driver_ref) -> void:
	driver = driver_ref
	_dir = 1.0 if int(driver.seed_value) % 2 == 0 else -1.0


# A line ride happened (a world_fact the driver forwards): count it, and rest the break.
func on_ride_fact(fact: String) -> void:
	if fact not in LINE_FACTS:
		return
	driver._count("line_rides")
	if _state == "line":
		_state = "ride"
		_state_clock = RIDE_REST_S


func step(delta: float, terrain: bool) -> void:
	var game = driver.game
	driver._welcome_ring_at = Vector3.INF
	var ball: Vector3 = game.player.ball_position()
	if not is_same(_note_ref, driver._note):
		_note_ref = driver._note
		_anchor = Vector3.INF
		_state = "circle"
		_circle_clock = 0.0
	if not is_instance_valid(_target) or (_target.has_method("is_dead") and _target.is_dead()):
		_target = _pick(ball)
	var first_contact = driver._note.get("first_contact_s")
	if _anchor == Vector3.INF and first_contact != null:
		_anchor = _make_anchor(ball)
	if _anchor == Vector3.INF:
		# Before contact: roll to the nearest enemy, as a bot looking for a fight would.
		driver._goal = "orbit approach"
		_circle_clock = 0.0
		var heading: Vector3 = game.flow.beacon.global_position if _target == null else _target.global_position
		driver._act(heading, _target, delta, null, terrain)
		return
	var at: Vector3 = _anchor
	var radial := Vector3(ball.x - at.x, 0.0, ball.z - at.z)
	var d := radial.length()
	if driver.trace and driver.ticks % 90 == 0:
		print("    kite t=%.0f state=%s d=%.1f spd=%.1f ball=(%.0f,%.0f,%.0f) clk=%.1f" % [game.run.stage_time, _state, d, game.player.planar_velocity().length(), ball.x, ball.y, ball.z, _circle_clock])
	var in_band := absf(d - ORBIT_RADIUS) <= ORBIT_BAND
	if _target != null and driver._flat(ball, _target.global_position) <= driver.CONTACT_RADIUS:
		driver._count("fight_s", delta)
	# circle_share's numerator: seconds on the ring, from first contact to the window's end.
	if in_band and float(game.run.stage_time) - float(first_contact) <= driver.CONTACT_WINDOW_S:
		driver._count("circle_s", delta)
	if in_band:
		_circle_clock += delta
		_circle_gap = 0.0
	else:
		_circle_gap += delta
		if _circle_gap > CIRCLE_GAP_S:
			_circle_clock = 0.0
	if terrain:
		if driver._note.get("lines_in_reach") == null:
			driver._note["lines_in_reach"] = 0
		_line_gap -= delta
		if _terrain(delta, ball, at):
			return
	_circle(delta, at, radial, d, terrain)


# The anchor, fixed at first contact for the rest of the stage: the centroid of the live pack units within the contact
# radius of the ball at that tick, else the nearest live enemy's position (a hit from further off opened the contact).
func _make_anchor(ball: Vector3) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for node in driver.game.get_tree().get_nodes_in_group("enemy"):
		if not node is Node3D or not is_instance_valid(node) or node == driver.game.flow.warden:
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if ball.distance_to(node.global_position) <= driver.CONTACT_RADIUS:
			sum += node.global_position
			n += 1
	if n > 0:
		return sum / n
	var near := _pick(ball)
	return near.global_position if near != null else ball


# The circle: a steering point a little ahead round the ring, the gun on the nearest enemy, boost off and the stick held to cruise.
func _circle(delta: float, at: Vector3, radial: Vector3, d: float, evade: bool) -> void:
	var r := radial / d if d > 0.5 else Vector3.BACK
	var angle := atan2(r.x, r.z) + _dir * ORBIT_LEAD
	var steer: Vector3 = driver._ground_point(at.x + sin(angle) * ORBIT_RADIUS, at.z + cos(angle) * ORBIT_RADIUS)
	driver._goal = "orbit anchor"
	driver._cruise_hold = true
	driver._act(steer, _target, delta, null, evade)


# The terrain arm's break. Returns true when it steered this tick.
func _terrain(delta: float, ball: Vector3, at: Vector3) -> bool:
	var game = driver.game
	_state_clock -= delta
	match _state:
		"circle":
			var threatened: bool = not driver._threats().is_empty()
			if _line_gap > 0.0 or not (threatened or _circle_clock >= CIRCLE_BREAK_S):
				return false
			var line := _nearest_line(ball)
			if not line.is_empty():
				driver._note["lines_in_reach"] = maxi(int(driver._note["lines_in_reach"]), 1)
				_line_goal = line["at"]
				_state = "line"
				_state_clock = LINE_TRY_S
				return false
			_state = "swing"
			_state_clock = SWING_TRY_S
			_hook_counted = false
			_swung = false
			return false
		"line":
			if _state_clock <= 0.0:
				_miss()
				return false
			driver._goal = "line"
			driver._act(_line_goal, _target, delta, null, true)
			return true
		"ride":
			if _state_clock <= 0.0:
				_state = "circle"
				_circle_clock = 0.0
				return false
			driver._goal = "ride"
			driver._act(at, _target, delta, null, true)
			return true
		"swing":
			var kit = game.player.kit
			if kit.hooked and not kit.on_body:
				if not _hook_counted:
					_hook_counted = true
					_swung = true
					driver._count("line_rides")
					driver._note["lines_in_reach"] = maxi(int(driver._note["lines_in_reach"]), 1)
			else:
				_hook_counted = false
			if _state_clock <= 0.0 and not kit.hooked:
				if _swung:
					_state = "circle"
					_circle_clock = 0.0
					_line_gap = LINE_GAP_S
				else:
					_miss()
				return false
			var away := Vector3(ball.x - at.x, 0.0, ball.z - at.z)
			away = away.normalized() if away.length() > 0.5 else Vector3.FORWARD
			var way: Vector3 = ball + away * 30.0
			var aim = driver._swing_hand(ball, way, delta)
			if aim != null:
				driver._note["lines_in_reach"] = maxi(int(driver._note["lines_in_reach"]), 1)
			driver._goal = "swing"
			driver._act(way, aim if aim != null else _target, delta, null, true)
			return true
	return false


func _miss() -> void:
	driver._count("line_misses")
	_state = "circle"
	_circle_clock = 0.0
	_line_gap = LINE_GAP_S


# The nearest live enemy on the flat, a pack unit or the Warden.
func _pick(ball: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node in driver.game.get_tree().get_nodes_in_group("enemy"):
		if not node is Node3D or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		var d: float = driver._flat(ball, node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


# The nearest cable's high end or park grind line within TERRAIN_LINE_REACH. {} when there is none.
func _nearest_line(ball: Vector3) -> Dictionary:
	var best := {}
	var best_d := TERRAIN_LINE_REACH
	for mouth in driver._cable_mouths():
		var p: Vector3 = mouth["at"]
		var d: float = driver._flat(ball, p)
		if d <= best_d and absf(p.y - ball.y) <= TERRAIN_LINE_REACH:
			best_d = d
			best = {"at": p, "kind": "cable"}
	for p in _lines_of_park():
		var d: float = driver._flat(ball, p)
		if d <= best_d:
			best_d = d
			best = {"at": p, "kind": "park"}
	return best


# Ground points of this stage's park grind lines (rows whose ride fact is a cable ride).
func _lines_of_park() -> Array:
	var game = driver.game
	if _park_lines_stage == game.run.stage:
		return _park_lines
	_park_lines_stage = game.run.stage
	_park_lines = []
	var map = game.ctx.terrain.map()
	if map == null or not "park" in map:
		return _park_lines
	for row in map.park.get("park_rows", []):
		if row.get("element") in PARK_LINE_ELEMENTS and row.get("ride_fact") in LINE_FACTS:
			var at: Array = row["at"]
			_park_lines.append(driver._ground_point(float(at[0]), float(at[1])))
	return _park_lines
