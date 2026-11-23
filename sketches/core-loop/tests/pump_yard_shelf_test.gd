# smoke: solo timeout=360s (about 80 ball lanes on the real dam at wall pace, about 160 s alone)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const T := preload("res://tests/support/t.gd")

# E1-05b (ruling ek, design-v3/WAYFINDING.md 2.2): the Sunken Pump Yard shelf (park_dam.json pump_yard_shelf*), a
# 0.45 m concrete shelf flush against the powerhouse's east wall (x 141), its top at x 142..152, flat from z 507 to
# 525, with a 20 m ramp down to the yard floor at each end (z 487 and z 545) and one 2 m step on its east side
# (foot x 154). It must never snag, turn back or feed into a wall a ball the base yard lets roll (ruling cu: hardness
# may slow a ball, never stop one that still rolls). Read on the real dam, yard locks off, the ball unsteered. A snag
# is half the flat speed lost within 0.2 s from 0.5 x cruise or more (tools/qa/snag_probe.gd min_before); a turn-back
# is the ball's reach along its push falling 1 m short of its best. Each lane first holds the ball still at its start
# for 0.2 s, so no lane starts on the one before it. This is a representative set; the PR's base-against-head sweep
# (4835 lanes over the yard) is the wide proof.
#  - ride: pushed south from z 478 along x 147 at 1.0 and 1.5 x (north from z 552 at 1.0 x), the ball rides the top
#    (0.4 m or more up for nine tenths of z 509..523) and rolls off the far ramp onto the yard floor, south at the
#    abutment's foot (the crest line up to the Warden), with no snag;
#  - roof: rolled east off the powerhouse roof at z 490, 502, 515, 528 and 541 (0.75, 1.0, 1.5 x), the ball lands on
#    the shelf or the floor past it and rolls on, never snagging or turning back (round 2's west slope stopped it);
#  - crossings into the east side (square, 30 and 60 degrees off square either way) and into each end (square, and
#    30 and 60 degrees off, the two ends mirrored), the corner diagonals, and runs along both ramps and the east
#    side: no snag, no turn-back, and from 1.0 x the ball reaches the far side. A crossing whose line meets the
#    powerhouse wall reaches its far side 4 m from the wall (x 145); from there the wall hit is its own check: a lane
#    at 45 degrees or shallower to the wall (the corner diagonals, the 60 degree east-side lanes, the wall grazes),
#    which the base wall turns without a snag, must not snag on the wall either (round 2's slopes turned such balls
#    square into it);
#  - two balls heading south-south-east past the powerhouse's north face at 1.0 and 1.2 x do not snag (round 1
#    turned them into the face).
# Planted: a ball pushed south at x 140 into the powerhouse's north face, a face square to its path, must read as a
# snag, so the detector is shown to catch one before its passes are trusted.

const SNAG_S := 0.2
const SNAG_FROM := 0.5
const BACK_M := 1.0
const KS := [0.75, 1.0, 1.5]
# The shelf's foot (x from the wall to the east step's foot, z from ramp end to ramp end) and its flat top.
const FOOT := Rect2(141.0, 487.0, 13.0, 58.0)
const TOP_Z := Vector2(509.0, 523.0)
const TOP_Y := 0.4
const RIDE_X := 147.0
const END_X := 150.0
# The powerhouse's east wall: x 141, z 485..545; a lane is at the wall within 4 m of it.
const WALL_X := 145.0
const WALL_Z := Vector2(484.0, 546.0)

var _t := T.new("pump_yard_shelf_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	await process_frame
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	for i in 120:
		await physics_frame
	_game.ctx.calm = true
	_game.run.set_max_hp(99999.0)


func _run() -> void:
	seed(1)
	StageLocks.active = false
	await _boot()
	var planted: Dictionary = await _roll(Vector2(140.0, 460.0), _dir(90.0), 1.0, 40.0)
	_t.check("planted: a ball pushed into the powerhouse's north face reads as a snag", planted["snag"] != "", str(planted))
	for k in [1.0, 1.5]:
		var south: Dictionary = await _roll(Vector2(RIDE_X, 478.0), _dir(90.0), k, 78.0, true)
		_t.check("ride south along x %d at %.2f x: no snag, rides the top, rolls off onto the floor at z 556" % [RIDE_X, k],
			south["snag"] == "" and south["back"] == "" and south["passed"] and south["top_share"] >= 0.9, str(south))
	var north: Dictionary = await _roll(Vector2(RIDE_X, 552.0), _dir(270.0), 1.0, 74.0, true)
	_t.check("ride north along x %d at 1.00 x: no snag, rides the top, rolls off onto the floor at z 478" % RIDE_X,
		north["snag"] == "" and north["back"] == "" and north["passed"] and north["top_share"] >= 0.9, str(north))
	for z in [490.0, 502.0, 515.0, 528.0, 541.0]:
		for k in KS:
			_lane("roof edge east at z %d" % z, await _roll(Vector2(134.0, z), _dir(0.0), k, 28.0), k, false)
	var c := FOOT.get_center()
	# [heading off square, speeds]: the east side takes both hands; the ends take one each, mirrored.
	for lane in [[0.0, [0.75, 1.5]], [30.0, [1.0]], [-30.0, [1.0]], [60.0, [0.75, 1.0]], [-60.0, [0.75, 1.0]]]:
		for k in lane[1]:
			_lane("east side at z %d, %+d deg" % [c.y, lane[0]], await _cross(Vector2(FOOT.end.x, c.y), _dir(180.0 + lane[0]), k), k,
				absf(lane[0]) >= 60.0)
	for lane in [[0.0, [0.75, 1.5]], [30.0, [1.0]], [-60.0, [0.75, 1.0]]]:
		for k in lane[1]:
			# Below cruise a square end lane is read up the ramp and onto the top (30 m), not over the whole shelf.
			var run_m := 30.0 if k < 1.0 and lane[0] == 0.0 else 0.0
			var into_north: Dictionary = await _cross(Vector2(END_X, FOOT.position.y), _dir(90.0 + lane[0]), k, run_m)
			_lane("north end at x %d, %+d deg" % [END_X, lane[0]], into_north, k, false)
			var into_south: Dictionary = await _cross(Vector2(END_X, FOOT.end.y), _dir(270.0 - lane[0]), k, run_m)
			_lane("south end at x %d, %+d deg" % [END_X, -lane[0]], into_south, k, false)
	for k in KS:
		_lane("north-east corner diagonal", await _cross(Vector2(FOOT.end.x, FOOT.position.y), _dir(135.0), k), k, true)
		_lane("south-east corner diagonal", await _cross(Vector2(FOOT.end.x, FOOT.end.y), _dir(225.0), k), k, true)
	for k in [0.75, 1.0]:
		_lane("along the north ramp eastward, z 491", await _cross(Vector2(143.0, 491.0), _dir(0.0), k, 24.0), k, false)
		_lane("along the south ramp eastward, z 541", await _cross(Vector2(143.0, 541.0), _dir(0.0), k, 24.0), k, false)
	for x in [FOOT.end.x - 2.0, FOOT.end.x + 2.0]:
		_lane("along the east side southward, x %d" % x, await _cross(Vector2(x, FOOT.position.y), _dir(90.0), 1.0, 40.0), 1.0, false)
		_lane("along the east side northward, x %d" % x, await _cross(Vector2(x, FOOT.end.y), _dir(270.0), 1.0, 40.0), 1.0, false)
	_lane("wall graze southward, 8 deg into the wall", await _roll(Vector2(148.0, 480.0), _dir(98.0), 1.0, -1.0), 1.0, true)
	_lane("wall graze northward, 8 deg into the wall", await _roll(Vector2(148.0, 552.0), _dir(262.0), 1.0, -1.0), 1.0, true)
	for k in [1.0, 1.2]:
		for lane in [[Vector2(146.0, 436.0), 19.0], [Vector2(149.0, 436.0), 10.0]]:
			var r: Dictionary = await _roll(lane[0], _dir(90.0 - lane[1]), k, 44.0)
			_t.check("yard lane from %s heading %d deg east of south at %.2f x: no snag" % [lane[0], lane[1], k], r["snag"] == "", str(r))
	StageLocks.active = true
	quit(_t.verdict())


# A lane passes when it never snags and never turns back before the far side; from 1.0 x it must also reach the far
# side. Below 1.0 x a ball that comes to rest on the top has been slowed by the climb, which ruling cu allows. With
# `wall_clean`, a lane that reaches the powerhouse wall must not snag on it either.
func _lane(name: String, r: Dictionary, k: float, wall_clean: bool) -> void:
	var ok: bool = r["snag"] == "" and r["back"] == "" and (k < 1.0 or r["passed"]) and (not wall_clean or r["wall_snag"] == "")
	_t.check("%s at %.2f x: no snag, no turn-back%s%s" % [name, k, "" if k < 1.0 else ", reaches the far side",
		", no snag on the wall" if wall_clean else ""], ok, str(r))


# 0 degrees is east (+x), 90 south (+z).
func _dir(deg: float) -> Vector2:
	return Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg)))


# A crossing: the ball starts 6 m before `entry`, where its line meets the foot, and its far side is where the line
# leaves the foot grown by 4 m, or the wall when the line meets it first (`run_m` < 0); a given `run_m` is a run along.
func _cross(entry: Vector2, dir: Vector2, k: float, run_m := 0.0) -> Dictionary:
	var start := entry - dir * 6.0
	if run_m > 0.0:
		return await _roll(start, dir, k, run_m)
	var far := FOOT.grow(4.0)
	var p := entry
	while far.has_point(p + dir * 0.5):
		p += dir * 0.5
		if p.x < WALL_X and p.y > WALL_Z.x and p.y < WALL_Z.y:
			return await _roll(start, dir, k, -1.0)
	return await _roll(start, dir, k, (p - start).length())


# A ball pushed along `dir` from `at` at k x cruise until its reach along `dir` passes `run_m` (or, with run_m < 0, it
# comes within 4 m of the powerhouse wall, after which it rolls 0.4 s more so its wall hit is read apart as wall_snag),
# it turns back, it comes to rest, it leaves the shelf's surroundings (10 m round the foot) after being in them, or
# time runs out. Returns the snag ("" or where), the turn-back, the wall snag, whether the far side was reached, the
# run, the slowest flat speed over cruise, the worst 0.2 s drop, the time and, with `top`, the share of samples over
# TOP_Z that stand TOP_Y or more up.
func _roll(at: Vector2, dir: Vector2, k: float, run_m: float, top := false) -> Dictionary:
	var cruise: float = _game.player.tuning.tier_cruise()
	# Held still at the start for 0.2 s, so a wall grip or carve left by the lane before has ended.
	for i in 18:
		_game.player.set_velocity_now(Vector3.ZERO, "probe")
		_game.player.body().global_position = _game.ctx.terrain.drop_point(at.x, at.y, 1.0)
		await physics_frame
	_game.player.body().global_position = _game.ctx.terrain.drop_point(at.x, at.y, 1.0)
	_game.player.set_velocity_now(Vector3(dir.x, 0.0, dir.y) * cruise * k, "probe")
	var tick_s := 1.0 / float(Engine.physics_ticks_per_second)
	var span := maxi(1, roundi(SNAG_S / tick_s))
	var hist: Array[float] = []
	var snag := ""
	var back := ""
	var wall_snag := ""
	var worst := Vector2.ZERO
	var worst_ratio := INF
	var start := at.dot(dir)
	var wall_bound := run_m < 0.0
	var goal := INF if wall_bound else start + run_m
	var reach := -INF
	var slow := INF
	var rest_s := 0.0
	var t_wall := -1.0
	var near := false
	var top_n := 0
	var top_on := 0
	var t := 0.0
	var limit := (60.0 if wall_bound else run_m) / (cruise * k) * 2.5 + 1.0
	while t < limit:
		await physics_frame
		t += tick_s
		var ball: Vector3 = _game.player.ball_position()
		var v: Vector3 = _game.player.state.velocity
		var flat := Vector2(v.x, v.z).length()
		if t > 0.1:
			slow = minf(slow, flat)
		if top and ball.z >= TOP_Z.x and ball.z <= TOP_Z.y:
			top_n += 1
			if _game.ctx.terrain.height(ball.x, ball.z) >= TOP_Y:
				top_on += 1
		hist.append(flat)
		if hist.size() > span + 1:
			hist.pop_front()
		if hist.size() == span + 1 and hist[0] >= SNAG_FROM * cruise:
			if flat / hist[0] < worst_ratio:
				worst_ratio = flat / hist[0]
				worst = Vector2(hist[0], flat)
			if flat <= 0.5 * hist[0]:
				var at_s := "(%.1f, %.1f, %.1f) %.2f -> %.2f x" % [ball.x, ball.y, ball.z, hist[0] / cruise, flat / cruise]
				if t_wall >= 0.0:
					if wall_snag == "":
						wall_snag = at_s
				elif snag == "":
					snag = at_s
		if wall_bound and t_wall < 0.0 and ball.x <= WALL_X and ball.z > WALL_Z.x and ball.z < WALL_Z.y:
			t_wall = t
		if t_wall >= 0.0 and t > t_wall + 0.4:
			break
		var here := Vector2(ball.x, ball.z).dot(dir)
		reach = maxf(reach, here)
		if reach >= goal:
			break
		if here < reach - BACK_M and t_wall < 0.0:
			back = "(%.1f, %.1f, %.1f) after a run of %.1f" % [ball.x, ball.y, ball.z, reach - start]
			break
		rest_s = rest_s + tick_s if flat < 0.05 * cruise else 0.0
		if rest_s > 0.5:
			break
		# A ball the shelf turned aside has left it once it is 10 m clear again: the lane has nothing more to say.
		var near_now := FOOT.grow(10.0).has_point(Vector2(ball.x, ball.z))
		if near and not near_now and not top:
			break
		near = near or near_now
	var out := {"snag": snag, "back": back, "wall_snag": wall_snag, "passed": reach >= goal or t_wall >= 0.0,
		"run": snappedf(reach - start, 0.1), "slowest_x": snappedf(slow / cruise, 0.01),
		"worst": "%.2f -> %.2f x" % [worst.x / cruise, worst.y / cruise], "t": snappedf(t, 0.1),
		"end": _game.player.ball_position().snapped(Vector3.ONE * 0.1)}
	if top:
		out["top_share"] = snappedf(float(top_on) / maxf(top_n, 1.0), 0.01)
	return out
