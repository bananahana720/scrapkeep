extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const TelegraphRecord := preload("res://src/combat/telegraph_record.gd")

enum State { FORMING, LOCKED, DIVING, SCATTERED }

const RACK := [1, 2, 3]
const GUARD_RACK := [1, 2, 3, 4]
const SPACING := 1.7
const ROW_GAP := 1.5
const STANDOFF := 16.0
const GUARD_RADIUS := 9.0
const FORM_SPEED := 9.0
const IN_SLOT := 1.0
const FORM_MAX := 3.0
const LOCK_WARN := 1.2
const DIVE_SPEED := 20.0
const DIVE_TIME := 1.1
const REST := 2.0
const SCATTER_SPEED := 10.0
const SCATTER_KNOCK := 6.0
const FOLLOW := 2.0
const LANE_WIDTH := 5.0

var drones: Array = []
var state := State.FORMING
var centre := Vector3.ZERO
var facing := Vector3.FORWARD
var home = null
var rows: Array = RACK
var fleet
var t := 0.0
var scatters := 0
var dives := 0
var locks := 0
var stung := false
var recovery_seconds := TelegraphRecord.RECOVERY
var recover_left := 0.0
var last_scatter_at := Vector3.ZERO

var _frame := -1
var _rest := 0.0
var _lane: Node3D


func _init(fleet_ref, guard_home = null) -> void:
	fleet = fleet_ref
	home = guard_home
	rows = GUARD_RACK if guard_home != null else RACK


func size() -> int:
	var n := 0
	for r in rows:
		n += int(r)
	return n


func add(drone: Node3D) -> int:
	if drones.is_empty():
		centre = drone.global_position
	drones.append(drone)
	return drones.size() - 1


func alive() -> Array:
	return drones.filter(func(d): return is_instance_valid(d) and not d.is_dead())


func lead():
	var live := alive()
	return live[0] if not live.is_empty() else null


func following() -> bool:
	return state == State.SCATTERED


func recovering() -> bool:
	return recover_left > 0.0


func flying_high() -> bool:
	return state == State.SCATTERED or (state == State.FORMING and _rest > 0.0)


func lane() -> Node3D:
	return _lane if is_instance_valid(_lane) else null


func slot(index: int) -> Vector3:
	if recovering() and index < drones.size() and is_instance_valid(drones[index]):
		return drones[index].global_position
	var side := facing.cross(Vector3.UP).normalized()
	var i := index
	var row := 0
	while row < rows.size() and i >= int(rows[row]):
		i -= int(rows[row])
		row += 1
	var in_row := int(rows[mini(row, rows.size() - 1)])
	var depth := (rows.size() - 1) * ROW_GAP * 0.5
	return centre + facing * (depth - row * ROW_GAP) + side * (i - (in_row - 1) * 0.5) * SPACING


func step(delta: float, ball: Vector3, ball_speed: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _frame:
		return
	_frame = frame
	if recovering():
		recover_left = maxf(0.0, recover_left - delta)
		_rest = maxf(0.0, _rest - delta)
		return
	t += delta
	_rest = maxf(0.0, _rest - delta)
	var to_ball := Vector3(ball.x - centre.x, 0.0, ball.z - centre.z)
	match state:
		State.FORMING, State.LOCKED:
			if to_ball.length() <= _radius() and ball_speed >= SCATTER_SPEED:
				scatter(ball)
				return
	match state:
		State.FORMING:
			if to_ball.length() > 0.1:
				facing = to_ball.normalized()
			var want := _post(ball)
			centre = centre.move_toward(Vector3(want.x, centre.y, want.z), FORM_SPEED * delta)
			if _rest <= 0.0 and (_in_slots() or t >= FORM_MAX) and to_ball.length() < STANDOFF * 1.8:
				_lock(ball)
		State.LOCKED:
			var lane := lane()
			if lane == null:
				_reform()
				return
			lane.set_progress(t / LOCK_WARN)
			if t >= LOCK_WARN:
				state = State.DIVING
				dives += 1
				t = 0.0
				stung = false
		State.DIVING:
			var lane := lane()
			if lane == null or t >= DIVE_TIME:
				_reform()
				return
			centre += lane.dir * DIVE_SPEED * delta
		State.SCATTERED:
			if t >= FOLLOW:
				_reform()


func scatter(at: Vector3) -> void:
	if state == State.SCATTERED:
		return
	state = State.SCATTERED
	t = 0.0
	scatters += 1
	last_scatter_at = at
	_clear_lane()
	var live := alive()
	for d in live:
		var out: Vector3 = d.global_position - at
		out.y = 0.0
		d.knock((out.normalized() if out.length() > 0.1 else Vector3.RIGHT) + Vector3.UP * 0.3, SCATTER_KNOCK * float(d.weight))
		d.set_seamless(true)
	if fleet != null:
		fleet.on_swarm_scattered(self, at, live.size())


func end_dive() -> void:
	if state == State.DIVING:
		_reform()


func _reform() -> void:
	recover_left = recovery_seconds if state == State.DIVING and home == null else 0.0
	_clear_lane()
	state = State.FORMING
	t = 0.0
	_rest = REST
	for d in alive():
		d.set_seamless(false)


func _lock(ball: Vector3) -> void:
	var first = lead()
	if first == null:
		return
	var to_ball := Vector3(ball.x - centre.x, 0.0, ball.z - centre.z)
	_lane = first.commit_formation_lane(centre - facing * (rows.size() * ROW_GAP * 0.5), to_ball,
		to_ball.length() + STANDOFF * 0.6, LANE_WIDTH)
	state = State.LOCKED
	locks += 1
	t = 0.0


func _clear_lane() -> void:
	var first = lead()
	if first != null:
		first.drop_formation_lane()
	elif is_instance_valid(_lane):
		_lane.queue_free()
	_lane = null


func _post(ball: Vector3) -> Vector3:
	if home is Vector3:
		var out := Vector3(ball.x - home.x, 0.0, ball.z - home.z)
		return home + (out.normalized() if out.length() > 0.1 else Vector3.FORWARD) * GUARD_RADIUS
	var back := Vector3(centre.x - ball.x, 0.0, centre.z - ball.z)
	return ball + (back.normalized() if back.length() > 0.1 else Vector3.FORWARD) * STANDOFF


func _radius() -> float:
	return maxf(2.5, rows.size() * ROW_GAP * 0.5 + 1.2)


func _in_slots() -> bool:
	for i in drones.size():
		var d = drones[i]
		if not is_instance_valid(d) or d.is_dead():
			continue
		var s := slot(i)
		if Vector2(d.global_position.x - s.x, d.global_position.z - s.z).length() > IN_SLOT:
			return false
	return true
