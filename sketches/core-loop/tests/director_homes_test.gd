extends SceneTree

const Game := preload("res://src/game.gd")
const Director := preload("res://src/world/director.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Graph := preload("res://src/world/park/park_graph.gd")
const CLEARANCE := EventDirector.PARK_CORRIDOR_M

var _game
var _graph
var _ticks := 0
var _phase := 0
var _failures := 0
var _observed := 0
var _violations := 0
var _ball := Vector2.ZERO
var _home := {}
var _sites := {}
var _lines := []
var _stopped := ""
var _held := {}
var _pack_positions := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	_graph = Graph.read("res://assets/park/park_dam/graph.bin")


func _check(label: String, ok: bool, detail := "") -> void:
	_failures += int(not ok)
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _at(row: Dictionary) -> Vector2:
	return Vector2(float(row.at[0]), float(row.at[1]))


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _ticks == 0:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
	_ticks += 1
	if _ticks < 20:
		return false
	var d = _game.world.director
	if _phase == 0:
		var map = _game.ctx.terrain.map()
		_check("real Game uses park_dam", map is ParkMap and map.title == "park_dam")
		for site in map.park.park_rows:
			_sites[site.id] = site
		_lines = _game.world.events._park_pilot_lines
		_check("KE1 pilot lines present", not _lines.is_empty(), "%d lines" % _lines.size())
		_home = map.park.home_rows[0]
		_ball = _window_ball(_sites[_home.site])
		_check("real graph forward fixture", _ball != Vector2.INF, str(_ball))
		_game.player.body().freeze = true
		d.stage_time = 90.0
		_place_ball()
		d.arrivals.clear()
		d.packs.clear()
		d._arrivals_made = d.elite_arrival - 1
		d._next_pack = {}
		d._last_pack_id = "held-history"
		d._last_was_elite = false
		d._pack_seq = 0
		d._timer = 0.0
		_held = {"arrivals_made": d.elite_arrival - 1, "pack_seq": 0,
			"last_pack_id": "held-history", "last_was_elite": false}
		# Homeless members ride with the crew, so an elite is unavailable only when none of its
		# kinds may arrive: every one is stopped here, and released before the fallback phase.
		for kind in d.elite.kinds:
			d._stopped_kinds[kind] = true
		_phase = 5
		_ticks = 0
		return false
	_place_ball()
	if _phase == 5:
		if _ticks < 3:
			d._timer = 0.0
			return false
		_check("unavailable elite retains its arrival slot", d.arrivals.is_empty() and d.packs.is_empty()
			and d._arrivals_made == _held.arrivals_made and d._pack_seq == _held.pack_seq
			and d._last_pack_id == _held.last_pack_id and d._last_was_elite == _held.last_was_elite
			and d._next_pack == d.elite,
			"queued=%d packs=%d arrivals_made=%d seq=%d next=%s" % [d.arrivals.size(), d.packs.size(), d._arrivals_made, d._pack_seq, d._next_pack])
		d._stopped_kinds.clear()
		_ball = _game.ctx.terrain.map().beacon
		_place_ball()
		d._rng.seed = 913
		d._timer = 0.0
		_phase = 6
		_ticks = 0
		return false
	if _phase == 6:
		var queued_kinds := []
		for arrival in d.arrivals:
			queued_kinds.append(Director.KIND_NAMES[arrival.kind])
			_check_corridor(arrival.at)
		_check("retained elite schedules on corridor-safe ring fallback",
			queued_kinds == ["hooker", "jolt_layer", "plated_brute"] and d.packs.size() == 1
			and d.packs[0].id == "elite" and d._arrivals_made == _held.arrivals_made + 1
			and d._pack_seq == _held.pack_seq + 1 and d._next_pack.is_empty()
			and d._last_was_elite and d._last_pack_id == _held.last_pack_id, str(queued_kinds))
		_game.flow.enter_stage(1, Vector3.ZERO, false)
		d = _game.world.director
		d.stage_time = 90.0
		d._next_pack = d.authored[0].duplicate(true)
		_ball = _window_ball(_sites[_home.site])
		_phase = 1
		_ticks = 0
		return false
	if _phase in [1, 2, 3]:
		for a in d.arrivals:
			if a.left < Director.ARRIVAL - 0.00001:
				continue
			_observed += 1
			if _phase == 1:
				_violations += int(not _from_live_home(a, _game.ctx.terrain.map().park.home_rows))
				_violations += int(a.at.distance_to(_ball) < 25.0)
				if Director.KIND_NAMES[a.kind] == "chaser" and a.has("pack"):
					if not _pack_positions.has(a.pack):
						_pack_positions[a.pack] = []
					_pack_positions[a.pack].append(a.at)
			elif _phase == 2:
				_violations += int(Director.KIND_NAMES[a.kind] == _stopped)
			_check_corridor(a.at)
		# Keep normal Game stepping, but make enough scheduled arrivals to test every pack.
		d._timer = 0.0
		if _ticks < 180:
			return false
		if _phase == 1:
			_check("forward-window arrivals use live home rows", _observed > 0 and _violations == 0,
				"%d arrivals, %d wrong homes/window/kinds" % [_observed, _violations])
			_check_pack_spread()
			_check("break transition exists on live Game director", d.has_method("break_home"))
			if d.has_method("break_home"):
				d.break_home(_home.id)
			_stopped = _home.enemy
			# Near the landmark all homes are behind: exercise suppression on ring fallback too.
			_ball = _game.ctx.terrain.map().beacon
			d.arrivals.clear()
			_phase = 2
		elif _phase == 2:
			_check("broken home's kind never arrives again", _observed > 0 and _violations == 0,
				"%d later arrivals, %d stopped-kind violations" % [_observed, _violations])
			_phase = 3
			_legacy_ring(d, true)
		elif _phase == 3:
			_check("fallback Game arrivals exercised", _observed > 0, str(_observed))
			_game.flow.enter_stage(1, Vector3.ZERO, false)
			d = _game.world.director
			_check("stage entry resets broken homes", not d.has_method("home_live") or d.home_live(_home.id))
			_game.queue_free()
			_game = Game.new()
			_game.test_mode = true
			_game.table = "alpha"
			root.add_child(_game)
			_phase = 4
		_observed = 0
		_violations = 0
		_ticks = 0
		return false
	if _phase == 4:
		if _ticks == 1:
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
		if _ticks < 20:
			return false
		d = _game.world.director
		_legacy_ring(d, false)
		d.stage_time = 1000.0
		_check("legacy time tiers stay capped at two", d.tier() == 2, str(d.tier()))
		_game.queue_free()
		if _failures > 0:
			print("director_homes_test failure count: %d" % _failures)
		print("director_homes_test: PASS" if _failures == 0 else "director_homes_test: FAIL")
		quit(0 if _failures == 0 else 1)
		return true
	return false


func _check_pack_spread() -> void:
	var repeated := 0
	var separated := true
	for points in _pack_positions.values():
		if points.size() < 2:
			continue
		repeated += 1
		for i in points.size():
			for j in range(i + 1, points.size()):
				separated = separated and points[i].distance_to(points[j]) >= Director.PACK_SPREAD - 0.0001
	_check("home pack members preserve PACK_SPREAD", repeated > 0 and separated, str(_pack_positions))
	var centre := _at(_sites[_home.site])
	var heading := (centre - _ball).normalized()
	var side := Vector2(-heading.y, heading.x)
	var expected := []
	var fits := true
	for i in 3:
		var spot := centre + side * Director.PACK_SPREAD * (i - 1.5)
		expected.append(spot)
		var ahead: float = _graph.d_landmark(_ball) - _graph.d_landmark(spot)
		fits = fits and ParkMap.footprint_contains(_sites[_home.site], spot)
		fits = fits and ahead >= 60.0 and ahead <= 250.0 and spot.distance_to(_ball) >= 25.0
		for line in _lines:
			for j in range(1, line.size()):
				fits = fits and Geometry2D.get_closest_point_to_segment(spot, line[j - 1], line[j]).distance_to(spot) > CLEARANCE
	_check("fixture permits original side-by-side offsets", fits, str(expected))
	var matches := false
	for points in _pack_positions.values():
		if points.size() != expected.size():
			continue
		var same := true
		for i in expected.size():
			var actual_offset: Vector2 = points[i] - points[0]
			var expected_offset: Vector2 = expected[i] - expected[0]
			same = same and actual_offset.distance_to(expected_offset) < 0.0001
		matches = matches or same
	_check("home group keeps original relative offsets when footprint permits", fits and matches)


func _place_ball() -> void:
	var body = _game.player.body()
	body.global_position = _game.ctx.terrain.drop_point(_ball.x, _ball.y, 2.4)
	_game.player.state.velocity = Vector3.ZERO


func _window_ball(site: Dictionary) -> Vector2:
	var home_d: float = _graph.d_landmark(_at(site))
	for n in _graph.px.size():
		var p := Vector2(_graph.px[n], _graph.pz[n])
		var ahead: float = _graph.d_landmark_node(n) - home_d
		if ahead >= 120.0 and ahead <= 180.0 and p.distance_to(_at(site)) < 200.0:
			return p
	return Vector2.INF


# An arrival comes from a live window home of its own kind; a kind with no live home in the
# window rides with the crew from any live window home.
func _from_live_home(arrival: Dictionary, homes: Array) -> bool:
	var kind: String = Director.KIND_NAMES[arrival.kind]
	var housed := false
	for home in homes:
		housed = housed or (not home.dormant and home.enemy == kind and _window_home(home))
	for home in homes:
		if home.dormant or (housed and home.enemy != kind):
			continue
		var site: Dictionary = _sites[home.site]
		var ahead: float = _graph.d_landmark(_ball) - _graph.d_landmark(_at(site))
		var point_ahead: float = _graph.d_landmark(_ball) - _graph.d_landmark(arrival.at)
		if ahead >= 60.0 and ahead <= 250.0 and ParkMap.footprint_contains(site, arrival.at) and point_ahead >= 60.0 and point_ahead <= 250.0:
			return true
	return false


func _window_home(home: Dictionary) -> bool:
	var ahead: float = _graph.d_landmark(_ball) - _graph.d_landmark(_at(_sites[home.site]))
	return ahead >= 60.0 and ahead <= 250.0


func _check_corridor(at: Vector2) -> void:
	var clear := true
	for line in _lines:
		for i in range(1, line.size()):
			clear = clear and Geometry2D.get_closest_point_to_segment(at, line[i - 1], line[i]).distance_to(at) > CLEARANCE
	_check("arrival outside every pilot corridor", clear, str(at))


# Frozen independent pre-KE6 ring algorithm. Comparing serialized Vector2 values
# catches float changes as well as a changed range or RNG draw order.
func _old_ring(rng: RandomNumberGenerator, rect: Rect2, ball: Vector2, velocity: Vector2, forward: Vector2) -> Vector2:
	var heading := velocity.normalized() if velocity.length() > 3.0 else forward.normalized()
	var ahead := rng.randf() < 0.6
	for i in 8:
		var angle: float
		var dist: float
		if ahead:
			angle = rng.randf_range(-0.6108652, 0.6108652)
			dist = rng.randf_range(60.0, 90.0)
		else:
			angle = rng.randf_range(0.6108652, PI) * (1.0 if rng.randf() < 0.5 else -1.0)
			dist = rng.randf_range(45.0, 70.0)
		var spot := ball + heading.rotated(angle) * dist
		spot.x = clampf(spot.x, rect.position.x, rect.end.x)
		spot.y = clampf(spot.y, rect.position.y, rect.end.y)
		if spot.distance_to(ball) >= 25.0:
			return spot
	return Vector2.INF


func _legacy_ring(d, park: bool) -> void:
	var count := 0
	var different := 0
	for seed_value in [1, 2, 3, 4, 913]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		d._rng.seed = seed_value
		for i in 100:
			var ball := _ball if park else Vector2(0, 0)
			var v := Vector2(0, 20) if i % 2 == 0 else Vector2.ZERO
			var expected := _old_ring(rng, d.play_rect, ball, v, Vector2.DOWN)
			var actual: Vector2 = d.spawn_spot(ball, v, Vector2.DOWN)
			# Park fallback rejects unsafe ring points; outside corridors it keeps today's ring.
			if park:
				_check_corridor(actual)
				var point := {"at": [expected.x, expected.y], "size": [0.0, 0.0, 0.0], "yaw_deg": 0.0}
				var expected_clear := true
				for line in _lines:
					for j in range(1, line.size()):
						expected_clear = expected_clear and not ParkMap.footprint_contains(point, line[j - 1], CLEARANCE, line[j])
				if expected_clear:
					different += int(var_to_bytes(actual) != var_to_bytes(expected))
				_check("fallback stays on today's ring", actual.distance_to(ball) >= 45.0 and actual.distance_to(ball) <= 90.01)
				if actual != expected:
					rng.state = d._rng.state
			else:
				different += int(var_to_bytes(actual) != var_to_bytes(expected))
			count += 1
	_check("ring fallback exercised" if park else "legacy arrival points byte-identical to today's ring",
		count == 500 and different == 0, "%d seeds/points, %d differing bytes" % [count, different])
