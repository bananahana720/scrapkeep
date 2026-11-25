extends RefCounted


const ORBIT_RADIUS := 14.0
const ORBIT_BAND := 3.0
const ORBIT_LEAD := 0.5
const ANCHOR_STEP := 7.0
const RING_RISE := 3.0
const RING_SAMPLES := 24
const ANCHOR_RINGS := 4
const CIRCLE_BREAK_S := 6.0
const CIRCLE_GAP_S := 1.0
const TERRAIN_LINE_REACH := 60.0
const LINE_HOME := 45.0
const POST_SWING_AT := 18.0
const LINE_TRY_S := 8.0
const SWING_TRY_S := 1.5
const LINE_GAP_S := 1.0
const RIDE_REST_S := 3.0
const LINE_FACTS := ["ride_grapple_line"]
const PARK_LINE_ELEMENTS := ["grind_line", "elevated_line", "flow_line", "rail"]

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
var _line_kind := ""
var _swing_toward := Vector3.ZERO
var _hook_counted := false
var _swung := false
var _park_lines: Array = []
var _park_lines_stage := -1


func _init(driver_ref) -> void:
	driver = driver_ref
	_dir = 1.0 if int(driver.seed_value) % 2 == 0 else -1.0


func _count_ride() -> void:
	var first_contact = driver._note.get("first_contact_s")
	if first_contact != null and float(driver.game.run.stage_time) - float(first_contact) <= driver.CONTACT_WINDOW_S:
		driver._count("line_rides")


func on_ride_fact(fact: String) -> void:
	if fact not in LINE_FACTS:
		return
	_count_ride()
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
	var want := ball
	if n > 0:
		want = sum / n
	else:
		var near := _pick(ball)
		if near != null:
			want = near.global_position
	var candidates: Array = []
	for centre in [want, ball]:
		candidates.append(centre)
		for ring in range(1, ANCHOR_RINGS + 1):
			for i in 8:
				var a := TAU * i / 8.0
				candidates.append(centre + Vector3(sin(a), 0.0, cos(a)) * ANCHOR_STEP * ring)
	candidates.sort_custom(func(p: Vector3, q: Vector3) -> bool: return driver._flat(p, want) < driver._flat(q, want))
	var best: Vector3 = want
	var best_rise := INF
	for c in candidates:
		var rise := _ring_rise(c)
		if rise < best_rise:
			best = c
			best_rise = rise
		if rise < RING_RISE:
			break
	driver._note["anchor_rise"] = snappedf(best_rise, 0.1)
	driver._note["anchor_off"] = snappedf(driver._flat(best, want), 0.1)
	return driver._ground_point(best.x, best.z)


func _ring_rise(at: Vector3) -> float:
	var terrain = driver.game.ctx.terrain
	var lo := INF
	var hi := -INF
	for radius in [ORBIT_RADIUS - ORBIT_BAND, ORBIT_RADIUS, ORBIT_RADIUS + ORBIT_BAND]:
		for i in RING_SAMPLES:
			var a := TAU * i / RING_SAMPLES
			var h: float = terrain.height(at.x + sin(a) * radius, at.z + cos(a) * radius)
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo


func _circle(delta: float, at: Vector3, radial: Vector3, d: float, evade: bool) -> void:
	var r := radial / d if d > 0.5 else Vector3.BACK
	var angle := atan2(r.x, r.z) + _dir * ORBIT_LEAD
	var steer: Vector3 = driver._ground_point(at.x + sin(angle) * ORBIT_RADIUS, at.z + cos(angle) * ORBIT_RADIUS)
	driver._goal = "orbit anchor"
	driver._cruise_hold = true
	driver._act(steer, _target, delta, null, evade)


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
				_line_kind = line["kind"]
				_state = "line"
				_state_clock = LINE_TRY_S
				return false
			_line_gap = LINE_GAP_S
			return false
		"line":
			if _state_clock <= 0.0:
				_miss()
				return false
			if _line_kind == "post" and driver._flat(ball, _line_goal) <= POST_SWING_AT:
				_start_swing(_line_goal)
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
					_count_ride()
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
			var away := Vector3(_swing_toward.x - ball.x, 0.0, _swing_toward.z - ball.z)
			away = away.normalized() if away.length() > 0.5 else Vector3.FORWARD
			var way: Vector3 = ball + away * 30.0
			var aim = driver._swing_hand(ball, way, delta)
			driver._goal = "swing"
			driver._act(way, aim if aim != null else _target, delta, null, true)
			return true
	return false


func _start_swing(toward: Vector3) -> void:
	_state = "swing"
	_state_clock = SWING_TRY_S
	_swing_toward = toward
	_hook_counted = false
	_swung = false


func _miss() -> void:
	driver._count("line_misses")
	_state = "circle"
	_circle_clock = 0.0
	_line_gap = LINE_GAP_S


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


func _nearest_line(ball: Vector3) -> Dictionary:
	var best := {}
	var best_d := TERRAIN_LINE_REACH
	var map = driver.game.ctx.terrain.map()
	if map != null and "contraptions" in map:
		for spec in map.contraptions:
			if spec["kind"] != "cable":
				continue
			var p: Vector3 = spec["from"]
			var end: Vector3 = spec["to"]
			if driver._flat(end, _anchor) > LINE_HOME:
				continue
			var d: float = driver._flat(ball, p)
			if d <= best_d and absf(p.y - ball.y) <= TERRAIN_LINE_REACH:
				best_d = d
				best = {"at": p, "kind": "cable"}
	for line in _lines_of_park():
		var p: Vector3 = line["at"]
		if driver._flat(p, _anchor) + float(line["half"]) > LINE_HOME:
			continue
		var d: float = driver._flat(ball, p)
		if d <= best_d:
			best_d = d
			best = {"at": p, "kind": line["kind"]}
	return best


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
		var post: bool = row.get("element") == "anchor_field"
		if (post or row.get("element") in PARK_LINE_ELEMENTS) and row.get("ride_fact") in LINE_FACTS:
			var at: Array = row["at"]
			var size: Array = row.get("size", [0.0, 0.0, 0.0])
			var half := 0.0 if post else maxf(float(size[0]), float(size[2])) * 0.5
			_park_lines.append({"at": driver._ground_point(float(at[0]), float(at[1])), "half": half, "kind": "post" if post else "park"})
	return _park_lines
