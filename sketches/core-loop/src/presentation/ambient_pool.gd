extends RefCounted

const AmbientKinds := preload("res://src/core/ambient_kinds.gd")

const ADMIT_M := 160.0
const ADMIT_EVERY_S := 0.5
const FADE_IN_S := 0.4
const FADE_OUT_S := 0.3
const BOSS_FADE_S := 0.3
const REDUCED_FADE_S := 0.4
const REDUCED_CAP := 12
const REDUCED_LOOP := 0.6
const LEASH_MULT := 2.5
const LEASH_MIN_M := 3.0
const JITTER_RAD := 0.5236
const HIDE_RUN_S := 1.5
const AWAY_MIN := 0.0
const BOXED_IN := 0.7
const BOXED_AWAY := 0.6
const HIDE_SINK_S := 0.5
const DUCK_HOLD_S := 0.5
const SCATTER_CLIMB := Vector2(12.0, 18.0)
const SCATTER_CLIMB_RATE := 6.0
const SCATTER_ORBIT_M := 8.0
const SCATTER_ORBIT_SPREAD := Vector2(0.7, 1.3)
const SOUND_GAP_S := 2.0
const FLEE_CLEAR := 1.5
const FLIGHT_LIFT := 1.8
const PERCH_LIFT := 0.3
const HANG_LIFT := 2.5
const SINK_M := 0.4


class Member:
	extends RefCounted
	var id := 0
	var kind := ""
	var row: Dictionary
	var home: Vector2
	var home_index := 0
	var offset := Vector2.ZERO
	var spot: Vector2
	var perch := "ground"
	var hang := HANG_LIFT
	var live := false
	var leaving := false
	var state := "idle"
	var t := 0.0
	var target := Vector2.ZERO
	var dir := Vector2.ZERO
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var facing := 0.0
	var loop := "idle"
	var loop_speed := 1.0
	var fade := 0.0
	var lift := 0.0
	var alt := 0.0
	var alt_goal := 0.0
	var jitter := 0.0
	var jitter_t := 0.0
	var call_t := 0.0
	var calm_t := 0.0
	var return_after := 8.0
	var react_kind := ""
	var orbit := Vector3.ZERO
	var orbit_r := 0.0
	var orbit_rate := 0.0
	var placed := false
	var wants_call := false
	var wants_react_sound := false


var members: Array[Member] = []
var clock := 0.0
var boss_lock := false
var reduced := false
var hushed := false
var _rng := RandomNumberGenerator.new()
var _admit_t := 0.0
var _last_react_sound := {}
var _wanted := {}


func setup(homes: Array, seed_number: int) -> void:
	_rng.seed = seed_number
	members.clear()
	clock = 0.0
	_admit_t = 0.0
	boss_lock = false
	_last_react_sound = {}
	for h in homes.size():
		var home: Dictionary = homes[h]
		var row: Dictionary = AmbientKinds.row(String(home["kind"]))
		for offset: Vector2 in home["members"]:
			var m := Member.new()
			m.id = members.size()
			m.kind = String(home["kind"])
			m.row = row
			m.home = home["at"]
			m.home_index = h
			m.offset = offset
			m.spot = m.home + offset
			m.perch = String(home.get("perch", "ground"))
			m.pos = Vector3(m.spot.x, 0.0, m.spot.y)
			m.call_t = _rng.randf_range(0.0, 1.0) * float(row["call_every"][1])
			m.hang = float(home["roof"]) if home.has("roof") else HANG_LIFT
			members.append(m)


func reset() -> void:
	boss_lock = false
	_admit_t = 0.0
	for m in members:
		_park(m)


func live_count() -> int:
	var n := 0
	for m in members:
		if m.live:
			n += 1
	return n


func drawn() -> Array[Member]:
	var out: Array[Member] = []
	for m in members:
		if m.live and m.fade > 0.001:
			out.append(m)
	return out


func cap() -> int:
	return REDUCED_CAP if reduced else AmbientKinds.CAP


func step(dt: float, input: Dictionary) -> void:
	clock += dt
	reduced = bool(input.get("reduced", false))
	if bool(input.get("boss", false)):
		boss_lock = true
	var player: Vector3 = input["player"]
	hushed = false
	for t: Vector3 in input.get("telegraphs", []):
		if _flat(t).distance_to(_flat(player)) <= AmbientKinds.HUSH_M:
			hushed = true
			break
	_admit_t -= dt
	if _admit_t <= 0.0:
		_admit_t = ADMIT_EVERY_S
		_admit(player)
	for m in members:
		if m.live:
			_tick(m, dt, input)


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _admit(player: Vector3) -> void:
	var order: Array[Member] = members.duplicate()
	var here := _flat(player)
	order.sort_custom(func(a: Member, b: Member):
		var da := a.home.distance_squared_to(here)
		var db := b.home.distance_squared_to(here)
		return da < db if da != db else a.id < b.id)
	_wanted.clear()
	for m in order:
		if _wanted.size() >= cap() or m.home.distance_to(here) > ADMIT_M:
			break
		_wanted[m.id] = true
	var live := live_count()
	for m in order:
		if m.live:
			m.leaving = not _wanted.has(m.id)
		elif _wanted.has(m.id) and not boss_lock and live < cap():
			_enter(m)
			live += 1


func _enter(m: Member) -> void:
	_park(m)
	m.live = true
	m.fade = 0.0
	m.t = _rng.randf_range(1.0, 3.0)
	m.pos = Vector3(m.spot.x, 0.0, m.spot.y)
	m.placed = false
	m.facing = _rng.randf_range(-PI, PI)
	m.call_t = _rng.randf_range(float(m.row["call_every"][0]), float(m.row["call_every"][1]))


func _park(m: Member) -> void:
	m.live = false
	m.leaving = false
	m.state = "idle"
	m.fade = 0.0
	m.alt = 0.0
	m.calm_t = 0.0
	m.vel = Vector3.ZERO
	m.loop = "idle"
	m.wants_call = false
	m.wants_react_sound = false
	m.pos = Vector3(m.spot.x, m.pos.y, m.spot.y)


func _tick(m: Member, dt: float, input: Dictionary) -> void:
	m.wants_call = false
	m.wants_react_sound = false
	var ground: Callable = input["ground"]
	var player := _flat(input["player"])
	var flat := Vector2(m.pos.x, m.pos.z)
	if not m.placed:
		m.placed = true
		m.lift = _rest_lift(m)
		m.pos.y = float(ground.call(flat.x, flat.y)) + m.lift
	var before := m.pos
	if boss_lock:
		m.state = "hidden"
		m.fade = move_toward(m.fade, 0.0, dt / BOSS_FADE_S)
		m.calm_t = 0.0
		_finish(m, dt, flat, ground, before)
		return
	var speed_row := float(m.row["speed"])
	var d_ball := flat.distance_to(player)
	var nearest := _nearest_threat(flat, input.get("threats", []))
	var combat: bool = nearest.x <= AmbientKinds.COMBAT_M
	if combat and m.state != "react" and m.state != "hidden":
		_react(m, flat, player, Vector2(nearest.y, nearest.z))
	elif not combat and d_ball < float(m.row["flee_m"]) and float(m.row["flee_speed"]) > 0.0 \
			and (m.state == "idle" or m.state == "perch" or m.state == "wander" or m.state == "sleep"):
		m.state = "flee"
		m.jitter_t = 0.0
	if m.state == "hidden" or (m.state == "react" and m.react_kind == "scatter"):
		if combat or d_ball <= float(m.row["flee_m"]) * FLEE_CLEAR:
			m.calm_t = 0.0
		else:
			m.calm_t += dt
			if m.calm_t >= m.return_after:
				_come_back(m)
				flat = Vector2(m.pos.x, m.pos.z)
	var fade_goal := 1.0
	m.loop_speed = 1.0
	match m.state:
		"idle", "perch":
			m.loop = "idle"
			m.t -= dt
			m.vel = Vector3.ZERO
			if m.t <= 0.0:
				_pick(m, speed_row)
		"sleep":
			m.loop = "idle"
			m.loop_speed = 0.35
			m.t -= dt
			m.vel = Vector3.ZERO
			if m.t <= 0.0:
				_idle(m)
		"wander":
			m.loop = "move"
			flat = _walk(m, flat, m.target, speed_row, dt)
			if flat.distance_to(m.target) < 0.3:
				_idle(m)
		"flee":
			m.loop = "move"
			m.loop_speed = 1.4
			var away := (flat - player).normalized() if flat != player else Vector2.from_angle(_rng.randf_range(0.0, TAU))
			m.jitter_t -= dt
			if m.jitter_t <= 0.0:
				m.jitter = _rng.randf_range(-JITTER_RAD, JITTER_RAD)
				m.jitter_t = 0.5
			var heading := away.rotated(m.jitter)
			flat += heading * float(m.row["flee_speed"]) * dt
			m.vel = Vector3(heading.x, 0.0, heading.y) * float(m.row["flee_speed"])
			m.facing = lerp_angle(m.facing, atan2(heading.x, heading.y), minf(1.0, dt * 10.0))
			var leash := maxf(float(m.row["wander_m"]), LEASH_MIN_M) * LEASH_MULT
			if flat.distance_to(m.home) > leash:
				_hide(m)
			elif d_ball > float(m.row["flee_m"]) * FLEE_CLEAR:
				m.target = _wander_target(m)
				m.state = "wander"
		"react":
			fade_goal = _react_tick(m, dt, flat)
			if m.react_kind == "hide" or m.react_kind == "scatter":
				flat = _react_flat(m, flat, dt)
		"hidden":
			m.loop = "idle"
			m.vel = Vector3.ZERO
			fade_goal = 0.0
		"return":
			m.loop = "move"
			if m.row["motion"] == "fly" and m.react_kind == "scatter":
				flat = _walk(m, flat, m.spot, float(m.row["flee_speed"]) * 0.6, dt)
				m.alt = move_toward(m.alt, 0.0, dt * SCATTER_CLIMB_RATE)
				if flat.distance_to(m.spot) < 0.5 and m.alt <= 0.05:
					m.state = "idle" if m.perch == "ground" else "perch"
					m.react_kind = ""
					m.t = _rng.randf_range(2.0, 4.0)
			else:
				m.loop = "idle"
				m.vel = Vector3.ZERO
				if m.fade >= 0.99:
					_idle(m)
	if not hushed and m.fade >= 0.9 and (m.state == "idle" or m.state == "perch" or m.state == "wander"):
		m.call_t -= dt
		if m.call_t <= 0.0:
			m.wants_call = true
			m.call_t = _rng.randf_range(float(m.row["call_every"][0]), float(m.row["call_every"][1]))
	var goal := 0.0 if m.leaving else fade_goal
	var rate := FADE_IN_S if goal > m.fade else (REDUCED_FADE_S if reduced and m.state == "react" else FADE_OUT_S)
	m.fade = move_toward(m.fade, goal, dt / rate)
	if reduced:
		m.loop_speed *= REDUCED_LOOP
	if m.leaving and m.fade <= 0.001:
		_park(m)
		return
	_finish(m, dt, flat, ground, before)


func _finish(m: Member, dt: float, flat: Vector2, ground: Callable, before: Vector3) -> void:
	var goal := _rest_lift(m)
	if m.state == "wander" and m.row["motion"] == "fly":
		goal += FLIGHT_LIFT
	if m.state == "react" and (m.react_kind == "hide" and m.t > HIDE_RUN_S):
		goal -= SINK_M
	if m.state == "react" and m.react_kind == "scatter":
		goal += FLIGHT_LIFT
	m.lift = move_toward(m.lift, goal, dt * 4.0)
	m.pos = Vector3(flat.x, float(ground.call(flat.x, flat.y)) + m.lift + m.alt, flat.y)
	if dt > 0.0:
		m.vel = (m.pos - before) / dt
	var heading := Vector2(m.vel.x, m.vel.z)
	if heading.length() > 0.2 and m.state != "flee":
		m.facing = lerp_angle(m.facing, atan2(heading.x, heading.y), minf(1.0, dt * 8.0))


func _rest_lift(m: Member) -> float:
	if m.perch == "ceiling":
		return m.hang
	if m.row["motion"] == "fly":
		return PERCH_LIFT
	return 0.0


func _nearest_threat(flat: Vector2, threats: Array) -> Vector3:
	var best := Vector3(INF, 0.0, 0.0)
	for t: Vector3 in threats:
		var d := flat.distance_to(Vector2(t.x, t.z))
		if d < best.x:
			best = Vector3(d, t.x, t.z)
	return best


func _idle(m: Member) -> void:
	m.state = "perch" if m.row["motion"] == "fly" else "idle"
	m.t = _rng.randf_range(2.0, 5.0)


func _pick(m: Member, speed: float) -> void:
	if _rng.randf() < float(m.row["sleep"]):
		m.state = "sleep"
		m.t = _rng.randf_range(6.0, 14.0)
	elif speed > 0.0 and float(m.row["wander_m"]) > 0.0 and _rng.randf() < 0.65:
		m.state = "wander"
		m.target = _wander_target(m)
	else:
		_idle(m)


func _wander_target(m: Member) -> Vector2:
	var reach := float(m.row["wander_m"])
	return m.spot + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(0.0, reach)


func _walk(m: Member, flat: Vector2, goal: Vector2, speed: float, dt: float) -> Vector2:
	var to := goal - flat
	var step := minf(speed * dt, to.length())
	var heading := to.normalized() if to.length() > 0.0001 else Vector2.ZERO
	m.vel = Vector3(heading.x, 0.0, heading.y) * speed
	return flat + heading * step


func _react(m: Member, flat: Vector2, player: Vector2, threat: Vector2) -> void:
	m.state = "react"
	m.t = 0.0
	m.calm_t = 0.0
	m.return_after = _rng.randf_range(AmbientKinds.RETURN_S.x, AmbientKinds.RETURN_S.y)
	m.react_kind = "fade" if reduced else String(m.row["react"])
	m.alt_goal = _rng.randf_range(SCATTER_CLIMB.x, SCATTER_CLIMB.y)
	m.orbit = Vector3.ZERO
	m.dir = flat - (player if m.react_kind == "scatter" else threat)
	if m.dir.length() < 0.001:
		m.dir = Vector2.from_angle(_rng.randf_range(0.0, TAU))
	m.dir = m.dir.normalized()
	var away := flat - player
	if away.length() > 0.001:
		away = away.normalized()
		var along := m.dir.dot(away)
		if along < -BOXED_IN:
			m.dir = (away.orthogonal() * (1.0 if _rng.randf() < 0.5 else -1.0) + away * BOXED_AWAY).normalized()
		elif along < AWAY_MIN:
			m.dir = (m.dir - away * along + away).normalized()
	if not hushed and clock - float(_last_react_sound.get(m.kind, -99.0)) >= SOUND_GAP_S:
		_last_react_sound[m.kind] = clock
		m.wants_react_sound = true


func _react_tick(m: Member, dt: float, _flat_pos: Vector2) -> float:
	m.t += dt
	match m.react_kind:
		"fade":
			m.loop = "react"
			m.vel = Vector3.ZERO
			m.loop_speed = 1.0
			if m.fade <= 0.001:
				_hide(m)
			return 0.0
		"duck":
			m.loop = "react"
			m.vel = Vector3.ZERO
			if m.t > DUCK_HOLD_S and m.fade <= 0.001:
				_hide(m)
			return 1.0 if m.t <= DUCK_HOLD_S else 0.0
		"hide":
			m.loop = "move" if m.t <= HIDE_RUN_S else "react"
			m.loop_speed = 1.4
			if m.t > HIDE_RUN_S + HIDE_SINK_S and m.fade <= 0.001:
				_hide(m)
			return 1.0 if m.t <= HIDE_RUN_S else 0.0
		_:
			m.loop = "move"
			m.loop_speed = 1.4
			return 1.0


func _react_flat(m: Member, flat: Vector2, dt: float) -> Vector2:
	var speed := float(m.row["flee_speed"])
	if m.react_kind == "hide":
		if m.t > HIDE_RUN_S:
			m.vel = Vector3.ZERO
			return flat
		flat += m.dir * speed * dt
		m.vel = Vector3(m.dir.x, 0.0, m.dir.y) * speed
		m.facing = lerp_angle(m.facing, atan2(m.dir.x, m.dir.y), minf(1.0, dt * 10.0))
		return flat
	if m.alt < m.alt_goal and m.orbit == Vector3.ZERO:
		m.alt = minf(m.alt + SCATTER_CLIMB_RATE * dt, m.alt_goal)
		flat += m.dir * speed * dt
		return flat
	if m.orbit == Vector3.ZERO:
		m.orbit_r = SCATTER_ORBIT_M * _rng.randf_range(SCATTER_ORBIT_SPREAD.x, SCATTER_ORBIT_SPREAD.y)
		m.orbit_rate = (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(SCATTER_ORBIT_SPREAD.x, SCATTER_ORBIT_SPREAD.y)
		var theta := m.dir.angle() - PI / 2.0 * signf(m.orbit_rate)
		var centre := flat - Vector2.from_angle(theta) * m.orbit_r
		m.orbit = Vector3(centre.x, centre.y, theta)
	m.orbit.z += m.orbit_rate * speed / m.orbit_r * dt
	return Vector2(m.orbit.x, m.orbit.y) + Vector2.from_angle(m.orbit.z) * m.orbit_r


func _hide(m: Member) -> void:
	m.state = "hidden"
	m.calm_t = 0.0
	m.return_after = _rng.randf_range(AmbientKinds.RETURN_S.x, AmbientKinds.RETURN_S.y)


func _come_back(m: Member) -> void:
	m.calm_t = 0.0
	m.state = "return"
	if not (m.row["motion"] == "fly" and m.react_kind == "scatter" and m.fade > 0.05):
		m.pos = Vector3(m.spot.x, m.pos.y, m.spot.y)
		m.react_kind = ""
		m.alt = 0.0
