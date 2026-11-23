extends SceneTree
# smoke: solo timeout=900s

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const T := preload("res://tests/support/t.gd")

# E1-05 (ruling ek, design-v3/WAYFINDING.md 2.2): the dam's intake takeoff (park_dam.json intake_takeoff, a 1.1 m ramp
# on the crest at about x -154..-148, z 180..190, turned 8 degrees east, whose lip is the crest edge) and the Sunken
# Pump Yard shelf (pump_yard_shelf*, three nested 0.45 m steps one 2 m cell apart, so each side is one even 13 degree
# slope up to a 1.35 m flat top at x 156..166, z 500..548, beside the powerhouse's east wall and south of its north
# face) must never snag or turn back a rolling ball from any side (ruling
# ct point 8c; ruling cu: hardness may slow a ball, never stop one that still rolls), and the takeoff must put a ball on
# the intake zip while a ball crossing the crest beside it is not taken. Read on the real dam, yard locks off, the ball
# unsteered. A snag is half the flat speed lost within 0.2 s from 0.5 x cruise or more (tools/qa/snag_probe.gd
# min_before); a turn-back is the ball's reach along its push falling 1 m short of its best.
#  - zip: a ball pushed south over the takeoff at 1.0, 1.5 and 2.0 x cruise is carried by the zip (8 m or more over
#    the ground between z 260 and 430);
#  - shelf ride: pushed south from z 340 down the east descent at x 161 (1.0 and 1.5 x), the ball rides the top
#    (2 m or more up for nine tenths of z 504..528) with no snag;
#  - shelf crossings at 0.75, 0.9, 0.95, 1.0 and 1.5 x cruise: west to east and east to west at z 510, north into the
#    south end and south into the north end (x 161 on the top's line; x 152, on its west slope, into the north end,
#    the corner that would push a ball toward the powerhouse). No lane
#    snags or turns back, and from 1.0 x each clears the shelf; below 1.0 x a ball may come to rest on the top but
#    never rolls back off the side it climbed;
#  - two balls heading south-south-east out of the north-west yard at 1.0 and 1.2 x (the round 2 review's lanes past
#    the powerhouse's north face) do not snag;
#  - the takeoff's sides at z 185 and 188 (1.0 and 1.5 x): no snag, the ball gets past the ramp, and the zip
#    does not take it;
#  - crossings at 0.75 and 1.5 x along the crest top beside the ramp (z 186, 189) are never taken by the zip; on
#    the dam face just below (z 190, 196) the zip's hook (intake_zip.from, 4.6 m) may take a ball, as the base
#    head on the face did, and no lane snags.
# Planted: a ball pushed south at x 140 into the powerhouse's north face, a face square to its path, must read as a
# snag, so the detector is shown to catch one before its passes are trusted. Each lane's detail carries its slowest
# flat speed over cruise.

const SNAG_S := 0.2
const SNAG_FROM := 0.5
const BACK_M := 1.0
const RIDE_S := 8.0
const SHELF_KS := [0.75, 0.9, 0.95, 1.0, 1.5]
const KS := [1.0, 1.5]
const SHELF_Z := [510.0]
const END_X := [161.0]
const RAMP_Z := [185.0, 188.0]
const CREST_Z := [186.0, 189.0]
const FACE_Z := [190.0, 196.0]

var _t := T.new("dam_ride_crossing_test")
var _game
var _rode := false


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


func _drop() -> void:
	_game.queue_free()
	for i in 3:
		await process_frame


func _run() -> void:
	seed(1)
	StageLocks.active = false
	for k in [1.0, 1.5, 2.0]:
		await _boot()
		await _zip(k)
		await _drop()
	await _boot()
	var planted: Dictionary = await _roll(Vector2(140.0, 460.0), Vector2(0.0, 1.0), 1.0, 500.0)
	_t.check("planted: a ball pushed into the powerhouse's north face reads as a snag", planted["snag"] != "", str(planted))
	for k in KS:
		for x in [161.0]:
			var r: Dictionary = await _roll(Vector2(x, 340.0), Vector2(0.0, 1.0), k, 530.0, true)
			_t.check("shelf ride x %d at %.2f x: no snag, rides the top to z 530" % [x, k],
				r["snag"] == "" and r["top_share"] >= 0.9 and r["passed"], str(r))
	for k in SHELF_KS:
		for z in SHELF_Z:
			var west := 140.0 if z < 490.0 else 145.0
			_lane("shelf west to east z %d" % z, await _roll(Vector2(west, z), Vector2(1.0, 0.0), k, 174.0), k)
			_lane("shelf east to west z %d" % z, await _roll(Vector2(185.0, z), Vector2(-1.0, 0.0), k, -150.0), k)
		for x in END_X:
			_lane("shelf south end x %d northward" % x, await _roll(Vector2(x, 562.0), Vector2(0.0, -1.0), k, -510.0), k)
		for x in END_X + [152.0]:
			_lane("shelf north end x %d southward" % x, await _roll(Vector2(x, 470.0), Vector2(0.0, 1.0), k, 520.0), k)
	for k in [1.0, 1.2]:
		for lane in [[Vector2(146.0, 436.0), 19.0], [Vector2(149.0, 436.0), 10.0]]:
			var dir := Vector2(sin(deg_to_rad(lane[1])), cos(deg_to_rad(lane[1])))
			var at: Vector2 = lane[0]
			var r: Dictionary = await _roll(at, dir, k, at.dot(dir) + 60.0)
			_t.check("yard lane from %s heading %d deg east of south at %.2f x: no snag" % [at, lane[1], k], r["snag"] == "", str(r))
	for k in KS:
		for z in RAMP_Z:
			_takeoff_side("takeoff side west to east z %d" % z, await _roll(Vector2(-163.0, z), Vector2(1.0, 0.0), k, -140.0), k,
				-155.0, z == 188.0)
			_takeoff_side("takeoff side east to west z %d" % z, await _roll(Vector2(-139.0, z), Vector2(-1.0, 0.0), k, 162.0), k,
				147.0, z == 188.0)
	for k in [0.75, 1.5]:
		for z in CREST_Z + FACE_Z:
			for dir in [1.0, -1.0]:
				var r: Dictionary = await _roll(Vector2(-151.0 - 12.0 * dir, z), Vector2(dir, 0.0), k, 151.0 * -dir + 12.0)
				var heading := "east" if dir > 0.0 else "west"
				if z in CREST_Z:
					_t.check("crest crossing z %d heading %s at %.2f x: no snag, not taken by the zip" % [z, heading, k],
						r["snag"] == "" and not r["zip"], str(r))
				else:
					_t.check("dam face crossing z %d heading %s at %.2f x: no snag (the zip may take it)" % [z, heading, k],
						r["snag"] == "", str(r))
	await _drop()
	StageLocks.active = true
	quit(_t.verdict())


# A shelf lane passes when it never snags and never turns back; from 1.0 x cruise it must also clear the shelf. Below
# 1.0 x a ball that comes to rest on the top has been slowed by the climb, which ruling cu allows.
func _lane(name: String, r: Dictionary, k: float) -> void:
	var ok: bool = r["snag"] == "" and r["back"] == "" and (k < 1.0 or r["passed"])
	_t.check("%s at %.2f x: no snag, no turn-back%s" % [name, k, "" if k < 1.0 else ", clears"], ok, str(r))


# A takeoff lane passes when it never snags, gets past the ramp's near side (`climb`) and is not taken by the zip; at
# 1.5 x it must clear the ramp too, unless it rolled off the crest's south edge (the z 188 lane runs 2 m from it).
func _takeoff_side(name: String, r: Dictionary, k: float, climb: float, edge: bool) -> void:
	var off_crest: bool = edge and r["end"].z > 192.0
	var ok: bool = r["snag"] == "" and r["reach"] >= climb and not r["zip"] and (k < 1.5 or r["passed"] or off_crest)
	_t.check("%s at %.2f x: no snag, not taken by the zip, %s" % [name, k, "climbs on" if k < 1.5 else "crosses"], ok, str(r))


# A ball pushed along `dir` from `at` at k x cruise until its reach along `dir` (the dot of its ground position with
# `dir`) passes `goal`, it turns back, it comes to rest or RIDE_S runs out. Returns the snag ("" or where), the
# turn-back ("" or where), whether the goal was reached, the furthest reach, the slowest flat speed over cruise after
# the push, the worst 0.2 s drop (from -> to, x cruise, among windows that start at SNAG_FROM x or more), whether a zip
# took it, the most it stood over the ground and, with `top`, the share of z 504..528 samples 2 m up.
func _roll(at: Vector2, dir: Vector2, k: float, goal: float, top := false) -> Dictionary:
	var cruise: float = _game.player.tuning.tier_cruise()
	# A zip ride outlives a teleport, and the cable then rests CABLE_REST (1 s) before it takes a ball again: drop the
	# ride and hold the ball still past that rest, so no lane starts on, or is spared by, the one before it.
	var hold := 2
	if _game.world.ride != null or _rode:
		_game.world.ride = null
		hold = 100
	for i in hold:
		_game.player.set_velocity_now(Vector3.ZERO, "probe")
		_game.player.body().global_position = _game.ctx.terrain.drop_point(at.x, at.y, 1.0)
		await physics_frame
	_rode = false
	_game.player.body().global_position = _game.ctx.terrain.drop_point(at.x, at.y, 1.0)
	_game.player.set_velocity_now(Vector3(dir.x, 0.0, dir.y) * cruise * k, "probe")
	var tick_s := 1.0 / float(Engine.physics_ticks_per_second)
	var span := maxi(1, roundi(SNAG_S / tick_s))
	var hist: Array[float] = []
	var snag := ""
	var back := ""
	var worst := Vector2.ZERO
	var worst_ratio := INF
	var reach := -INF
	var slow := INF
	var clear_max := 0.0
	var rest_s := 0.0
	var top_n := 0
	var top_on := 0
	var t := 0.0
	while t < RIDE_S:
		await physics_frame
		t += tick_s
		var ball: Vector3 = _game.player.ball_position()
		var v: Vector3 = _game.player.state.velocity
		var flat := Vector2(v.x, v.z).length()
		if _game.world.ride != null:
			_rode = true
		if t > 0.1:
			slow = minf(slow, flat)
		hist.append(flat)
		if hist.size() > span + 1:
			hist.pop_front()
		if hist.size() == span + 1 and hist[0] >= SNAG_FROM * cruise:
			if flat / hist[0] < worst_ratio:
				worst_ratio = flat / hist[0]
				worst = Vector2(hist[0], flat)
			if snag == "" and flat <= 0.5 * hist[0]:
				snag = "(%.1f, %.1f, %.1f) %.2f -> %.2f x" % [ball.x, ball.y, ball.z, hist[0] / cruise, flat / cruise]
		clear_max = maxf(clear_max, ball.y - 1.0 - _game.ctx.terrain.height(ball.x, ball.z))
		if top and ball.z >= 504.0 and ball.z <= 528.0:
			top_n += 1
			if ball.y >= 2.0:
				top_on += 1
		var here := Vector2(ball.x, ball.z).dot(dir)
		reach = maxf(reach, here)
		if reach >= goal:
			break
		if here < reach - BACK_M:
			back = "(%.1f, %.1f, %.1f) after reach %.1f" % [ball.x, ball.y, ball.z, reach]
			break
		rest_s = rest_s + tick_s if flat < 0.05 * cruise else 0.0
		if rest_s > 0.5:
			break
	return {"snag": snag, "back": back, "zip": _rode, "passed": reach >= goal, "reach": snappedf(reach, 0.1),
		"slowest_x": snappedf(slow / cruise, 0.01), "worst": "%.2f -> %.2f x" % [worst.x / cruise, worst.y / cruise],
		"clear_max": snappedf(clear_max, 0.1), "top_share": snappedf(float(top_on) / maxf(top_n, 1.0), 0.01),
		"end": _game.player.ball_position().snapped(Vector3.ONE * 0.1)}


func _zip(k: float) -> void:
	var cruise: float = _game.player.tuning.tier_cruise()
	_game.player.body().global_position = _game.ctx.terrain.drop_point(-151.0, 166.0, 1.0)
	_game.player.set_velocity_now(Vector3(0.0, 0.0, cruise * k), "probe")
	var clear := 0.0
	var t := 0.0
	while t < 9.0:
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
		var ball: Vector3 = _game.player.ball_position()
		if ball.z > 260.0 and ball.z < 430.0:
			clear = maxf(clear, ball.y - _game.ctx.terrain.height(ball.x, ball.z))
		if ball.z > 430.0:
			break
	_t.check("takeoff at %.1f x cruise: the intake zip carries the ball" % k, clear >= 8.0, "%.1f m over the ground" % clear)
