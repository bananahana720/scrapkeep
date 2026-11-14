# smoke: solo (a 6 s siren runs at wall pace)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SurvivalCount := preload("res://src/world/survival_count.gd")

# The Stocktake muster on the flume (BACKLOG W1-101): the survival count as an event that comes to the ball.
# (a) with the launch flag on it is called on about one run seed in three, and on no seed with the flag off;
# (b) a called run builds one muster site, shown nowhere until it lands;
# (c) away from its row nothing happens; near it the siren announces it once and nothing starts for siren_s; a ball
#     the Warden has engaged is neither called on nor landed on;
# (d) when the siren ends the ring lands on the ground under the moving ball, away from its row, shows, and count 1 begins;
# (e) the ring then travels: it sets off the way the ball was heading and stays on the circle the site chose, and
#     every point of that circle is ground a ring fits on;
# (f) with the floor clear the gate opens, and rolling out of the travelling ring from inside banks pay(1);
# (g) a run seed that is not called builds no muster;
# (h) ground a ring fits on: not a crew's home, the Warden's ring, the map's edge, another site of this run or a place
#     a contraption names, and not round a rise (checked on this test's own finer grid); a landing with no clear
#     circle holds; round its row at least one landing in four fits at once and one in ten travels (the measure
#     BACKLOG W1-101 quotes is printed, for the row and for the ride line);
# (i) a ball on another fight's ground when the siren ends is not landed on until it is on clear ground; after
#     MUSTER_WAIT_S of that the muster stands down, and is called again near its row.

const SEED := 23
const EXPECTED_CHECKS := 17

var _game
var _t := preload("res://tests/support/t.gd").new("stocktake_muster_test")
var _source := Intent.Scripted.new()
var _announced := []
var _ended := []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _acts():
	return _game.world.activities


func _site():
	return _acts().site("stocktake_muster")


func _hold(at: Vector3) -> void:
	_game.player.reset_to(at, Vector3.ZERO)
	_game.player.set_velocity_now(Vector3.ZERO)
	await physics_frame


func _over(x: float, z: float) -> Vector3:
	return _game.ctx.terrain.drop_point(x, z, 1.05)


func _called(map) -> bool:
	return not _acts().survival_spec(map, "stocktake_muster").is_empty()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = SEED
	_game.player.source = _source
	_game.events.event_announced.connect(func(id: String, seconds: float, _at: Vector3): if id == "stocktake_muster": _announced.append(seconds))
	_game.events.event_ended.connect(func(id: String, outcome: String): if id == "stocktake_muster": _ended.append(outcome))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	var map = _game.ctx.terrain.map()
	var off := 0
	for run_seed in 60:
		_game.run.run_seed = run_seed
		off += int(_called(map))
	_game.ctx.tuning.set_option("stocktake", "on")
	var on := []
	var quiet := -1
	for run_seed in 60:
		_game.run.run_seed = run_seed
		if _called(map):
			on.append(run_seed)
		elif quiet < 0:
			quiet = run_seed
	_t.check("called on about one run seed in three with the flag on, none with it off", off == 0 and on.size() >= 12 and on.size() <= 28, "off %d, on %d of 60" % [off, on.size()])
	_game.run.run_seed = on[0]
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	await _muster()
	_game.run.run_seed = on[1]
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	await _waits()
	_game.run.run_seed = quiet
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	_t.check("a run seed that is not called builds no muster", _site() == null, "seed %d" % quiet)
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	_game.free()
	await _frames(2)
	quit(_t.verdict())


func _muster() -> void:
	var s = _site()
	_t.check("a called run builds one muster, shown nowhere until it lands", s != null and s.yard != null and not s.visible
		and not _game.hud.edge_markers.unfinished_sites().has(s) if s != null else false, "no site" if s == null else "visible %s" % s.visible)
	if s == null:
		return
	var row := Vector2(s.global_position.x, s.global_position.z)
	var call_m := float(s.rule["call_m"])
	for frame in 30:
		await _hold(_over(row.x - call_m - 40.0, row.y))
	var far_quiet: bool = _announced.is_empty() and not s.started
	var near: Vector3 = _over(row.x - call_m + 20.0, row.y)
	# Engaged by the Warden, the ball is not called on.
	_game.flow._engaged = true
	for frame in 30:
		await _hold(near)
	far_quiet = far_quiet and _announced.is_empty()
	_game.flow._engaged = false
	var siren := float(s.rule["siren_s"])
	for frame in int((siren - 0.5) * Engine.physics_ticks_per_second):
		await _hold(near)
	_t.check("away from its row nothing happens; near it the siren announces it once and nothing starts yet",
		far_quiet and _announced == [siren] and not s.started and not s.visible, "far quiet %s announced %s started %s" % [far_quiet, _announced, s.started])
	# The ball rolls east at 5 m/s as the siren ends, so the ring lands under it there and sets off east.
	var going := Vector3(5.0, 0.0, 0.0)
	var at := near
	for frame in Engine.physics_ticks_per_second:
		if s.started:
			break
		at = _over(at.x + going.x / Engine.physics_ticks_per_second, at.z)
		_game.player.reset_to(at, going)
		_game.player.set_velocity_now(going)
		await physics_frame
	var landed := Vector2(s.global_position.x, s.global_position.z)
	_t.check("when the siren ends the ring lands under the ball, shows, and count 1 begins", s.started and s.visible and s.yard.count == 1
		and _announced.size() == 1 and landed.distance_to(Vector2(at.x, at.z)) < 1.0 and landed.distance_to(row) > 20.0,
		"started %s visible %s count %d, %.1f m from the ball" % [s.started, s.visible, s.yard.count, landed.distance_to(Vector2(at.x, at.z))])
	# The ball rides with the ring, felling what arrives, and the ring travels the loop.
	var loop: Dictionary = SurvivalCount.MOVES["loop"]
	var furthest := 0.0
	var on_loop := true
	var opened := false
	var first_step := Vector2.ZERO
	# The site rides the first clear way: a circle of that radius, its centre to the right of the heading at landing
	# (east), which is south, for a positive way and to the left for a negative one.
	var ring := float(s.rule["ring"])
	var way: float = s.yard.way
	var centre := landed + Vector2(0.0, way)
	for frame in 6 * Engine.physics_ticks_per_second:
		await _hold(_over(s.global_position.x, s.global_position.z))
		var ring_at := Vector2(s.global_position.x, s.global_position.z)
		if frame == 20:
			first_step = ring_at - landed
		furthest = maxf(furthest, ring_at.distance_to(landed))
		on_loop = on_loop and absf(ring_at.distance_to(centre) - absf(way)) < 0.5
		for enemy in s.pack:
			if is_instance_valid(enemy):
				enemy.take_damage(100000.0)
		if s.yard.gate_open and s.yard_owed.is_empty():
			opened = true
			break
	_t.check("the ring sets off the way the ball was heading and stays on the circle the site chose", furthest > 5.0 and on_loop
		and first_step.x > 1.0 and absf(first_step.y) < first_step.x and absf(way) >= float(loop["tighter_m"][-1]),
		"way %.0f m, furthest %.1f m, first step %s" % [way, furthest, first_step])
	var course := SurvivalCount.course(landed, Vector2(going.x, going.z), way)
	var fits := course.size() > 8
	for p in course:
		fits = fits and _acts().clear_ground(PackedVector2Array([p]), ring, s)
	_t.check("every point of the chosen circle is ground a ring fits on", fits and _acts().clear_ground(course, ring, s), "%d points" % course.size())
	_t.check("a clear floor opens the gate on the travelling ring", opened and s.yard.cleared == 1, "opened %s cleared %d" % [opened, s.yard.cleared])
	await _hold(_over(s.global_position.x, s.global_position.z))
	var scrap_before: int = _game.run.scrap
	await _hold(_over(s.global_position.x + float(s.rule["ring"]) + 6.0, s.global_position.z))
	var pay: Dictionary = SurvivalCount.new().pay(1)
	_t.check("rolling out of the ring from inside banks pay(1)", _ended == ["won"] and s.done and _game.run.scrap - scrap_before == int(pay["scrap"]),
		"ended %s scrap %d of %d" % [_ended, _game.run.scrap - scrap_before, pay["scrap"]])


# The wasteway is a crew's home (ParkMap.fight_sites() wasteway_chasers).
const HOME := Vector2(85.0, 335.0)


func _waits() -> void:
	var s = _site()
	var acts = _acts()
	var map = _game.ctx.terrain.map()
	var ring := float(s.rule["ring"])
	var t = _game.ctx.terrain
	var one := func(p: Vector2) -> bool: return acts.clear_ground(PackedVector2Array([p]), ring, s)
	# Found on the map, not assumed: a spot whose only fault is a rise inside the ring, two neighbouring spots a ring
	# fits on with a wall or drop between them, and a spot that fits but has no clear circle at any heading.
	var rise := Vector2.INF
	var hemmed := Vector2.INF
	var open := []
	for gx in range(-30, 20):
		for gz in range(-30, 30):
			var at := Vector2(gx, gz) * 20.0
			var fault: String = acts.ground_fault(PackedVector2Array([at]), ring, s)
			if fault == "rise" and rise == Vector2.INF:
				rise = at
			if fault != "":
				continue
			open.append(at)
			if hemmed == Vector2.INF and at.distance_to(HOME) < 300.0 and _holds(at, ring):
				hemmed = at
	_t.check("a ring fits on open ground, not on a crew's home, the Warden's ring or the map's edge; a landing with no clear circle is found",
		hemmed != Vector2.INF and acts.ground_fault(PackedVector2Array([HOME]), ring, s) == "taken" and acts.ground_fault(PackedVector2Array([map.beacon]), ring, s) == "taken"
		and acts.ground_fault(PackedVector2Array([map.play_rect.position + Vector2(5.0, 5.0)]), ring, s) == "edge", "hemmed at %s" % hemmed)
	# Read here on a 3 m grid of this test's own: the ring of the spot found with a rise does hold ground past the
	# line, and no spot that fits holds ground 4 m past it (the rule reads every 6 m, so a narrow spike can slip by).
	var level := true
	for at in open:
		level = level and _steepest(at, ring) <= acts.RING_RISE_M + 4.0
	_t.check("no ring fits round a rise: a spot whose only fault is a rise has one, and every spot that fits is level across its ring",
		level and open.size() > 100 and rise != Vector2.INF and _steepest(rise, ring) > acts.RING_RISE_M,
		"%d spots fit, rise at %s of %.1f m" % [open.size(), rise, _steepest(rise, ring) if rise != Vector2.INF else 0.0])
	# Another site standing this run (a drawn pocket) and a built contraption keep the ring off by their own size.
	var others := []
	for other in acts.sites:
		if other != s and other.visible:
			others.append(Vector2(other.global_position.x, other.global_position.z))
	# The grade wall, the weir valve's door and cache, a cable's foot and a launcher's landing (park_flume.json).
	var built := [Vector2(-267.76, 187.76), Vector2(-152.0, -252.0), Vector2(-142.0, -238.0), Vector2(-290.0, -245.0), Vector2(-190.0, -20.0)]
	var off_sites: bool = not others.is_empty()
	for at in others + built:
		off_sites = off_sites and acts.ground_fault(PackedVector2Array([at]), ring, s) == "taken"
	_t.check("no ring fits on another site standing this run or on a place a contraption names", off_sites, "%d other sites" % others.size())
	# The measure BACKLOG W1-101 quotes: landings within 120 m of the row, at eight headings.
	var row_at := Vector2(s.global_position.x, s.global_position.z)
	var tally := {"wait": 0, 60: 0, 40: 0, 25: 0, 0: 0}
	var faults := {}
	var line_faults := {}
	var cases := 0
	for gx in range(-6, 7):
		for gz in range(-6, 7):
			var at := row_at + Vector2(gx, gz) * 20.0
			if at.distance_to(row_at) > 120.0:
				continue
			var why: String = acts.ground_fault(PackedVector2Array([at]), ring, s)
			var lands: bool = why == ""
			faults[why] = int(faults.get(why, 0)) + 1
			for k in 8:
				cases += 1
				if not lands:
					tally["wait"] += 1
					continue
				var count := SurvivalCount.new(1, "muster")
				count.begin(at, Vector2.RIGHT.rotated(TAU * k / 8.0), func(lap: PackedVector2Array) -> bool: return acts.clear_ground(lap, ring, s))
				tally[int(absf(count.way))] += 1
	var travels: int = tally[60] + tally[40] + tally[25]
	print("measure (run seed %d): row %s, %d cases, by circle %s" % [_game.run.run_seed, row_at, cases, tally])
	# The same along the ride line, every 20 m, heading along it.
	var line := {"wait": 0, 60: 0, 40: 0, 25: 0, 0: 0}
	var trail: PackedVector2Array = t.scrap_trail(2)["points"]
	var slowest := 0
	for i in trail.size() - 1:
		var seg: Vector2 = trail[i + 1] - trail[i]
		for j in maxi(1, int(seg.length() / 20.0)):
			var at: Vector2 = trail[i] + seg * j / maxi(1, int(seg.length() / 20.0))
			var why: String = acts.ground_fault(PackedVector2Array([at]), ring, s)
			line_faults[why] = int(line_faults.get(why, 0)) + 1
			if why != "":
				line["wait"] += 1
				continue
			var began := Time.get_ticks_usec()
			var count := SurvivalCount.new(1, "muster")
			count.begin(at, seg, func(lap: PackedVector2Array) -> bool: return acts.clear_ground(lap, ring, s))
			slowest = maxi(slowest, Time.get_ticks_usec() - began)
			line[int(absf(count.way))] += 1
	print("measure (run seed %d): ride line by circle %s, slowest choice of a way %.1f ms" % [_game.run.run_seed, line, slowest / 1000.0])
	print("measure: landing spots by fault (\"\" fits): round the row %s, on the ride line %s" % [faults, line_faults])
	_t.check("round its row at least one landing in four fits at once and one in ten travels", tally["wait"] * 4 < cases * 3 and travels * 10 > cases,
		"%d of %d wait, %d travel" % [tally["wait"], cases, travels])
	var row := Vector2(s.global_position.x, s.global_position.z)
	var near: Vector3 = _over(row.x - float(s.rule["call_m"]) + 20.0, row.y)
	_announced.clear()
	for frame in 30:
		await _hold(near)
	var siren := float(s.rule["siren_s"])
	for frame in int((siren + 1.0) * Engine.physics_ticks_per_second):
		await _hold(_over(HOME.x, HOME.y))
	var waited: bool = _announced == [siren] and not s.started and not s.visible
	# It waits MUSTER_WAIT_S and stands down; back near its row it is called again.
	for frame in int(acts.MUSTER_WAIT_S * Engine.physics_ticks_per_second):
		await _hold(_over(HOME.x, HOME.y))
	var stood_down: bool = not s.yard_called and not s.started and _announced.size() == 1
	for frame in 30:
		await _hold(near)
	_t.check("a muster that finds no clear ground in time stands down, and is called again near its row", stood_down and s.yard_called and _announced.size() == 2,
		"stood down %s, announced %d" % [stood_down, _announced.size()])
	for frame in int((siren + 0.5) * Engine.physics_ticks_per_second):
		await _hold(_over(hemmed.x, hemmed.y))
	var landed := Vector2(s.global_position.x, s.global_position.z)
	_t.check("a ball on a crew's home when the siren ends is landed on only once it is on clear ground",
		waited and s.started and s.visible and landed.distance_to(hemmed) < 1.0, "waited %s started %s, %.1f m from the clear spot" % [waited, s.started, landed.distance_to(hemmed)])
	await _frames(Engine.physics_ticks_per_second)
	_t.check("a landing with no clear circle holds where it landed", Vector2(s.global_position.x, s.global_position.z).distance_to(landed) < 0.01,
		"moved %.2f m" % Vector2(s.global_position.x, s.global_position.z).distance_to(landed))


# True when a muster landing on `at` has no clear circle at any of eight headings.
func _holds(at: Vector2, ring: float) -> bool:
	var acts = _acts()
	for k in 8:
		var count := SurvivalCount.new(1, "muster")
		count.begin(at, Vector2.RIGHT.rotated(TAU * k / 8.0), func(lap: PackedVector2Array) -> bool: return acts.clear_ground(lap, ring, _site()))
		if count.way != 0.0:
			return false
	return true


# How far the ground inside a ring of `ring` metres at `at` stands off an even slope through its centre, on a 3 m
# grid: the most that two spots straight across the centre from each other stand off the line between them.
func _steepest(at: Vector2, ring: float) -> float:
	var t = _game.ctx.terrain
	var here: float = t.height(at.x, at.y)
	var worst := 0.0
	for x in range(-8, 9):
		for z in range(0, 9):
			var off := Vector2(x, z) * 3.0
			if off.length() <= ring:
				worst = maxf(worst, absf(t.height(at.x + off.x, at.y + off.y) + t.height(at.x - off.x, at.y - off.y) - 2.0 * here))
	return worst
