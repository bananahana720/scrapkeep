extends SceneTree
# smoke: timeout=300s

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const T := preload("res://tests/support/t.gd")

# E1-05a (ruling ek, design-v3/WAYFINDING.md 2.2): the Dam's intake takeoff and the intake zip's catch. The takeoff
# is a launch slot cut into the crest top between x -154 and -148, in line with the zip, made of two ramp stamps in
# park_dam.json. intake_takeoff_ramp cuts the north half: its floor falls from crest level at z 176 to 0.4 m under it
# at z 182, gently, so a slow ball that drifts in off the crest's north wall rolls across it instead of being turned
# back (review r1 of PR #1225). intake_takeoff, the kicker, is deepest (about 0.55 m) at z 184 and rises evenly to
# the crest edge at z 190, which is its lip. Nothing stands above the crest, so a ball climbing the dam face meets
# the same edge as before. The zip's hook (intake_zip.from, radius 5.0) hangs over the face 9.5 m south of the lip.
#
# Read on the real dam, yard locks off, the ball unsteered. A snag is half the flat speed lost within 0.2 s from
# 0.5 x cruise or more (tools/qa/snag_probe.gd min_before); a turn-back is the ball's reach along its push falling
# 1 m short of its best. A lane the zip takes ends there: the cable, not the map, carries it on. Each lane drops any
# ride left over and holds the ball still past the cable's 1 s rest, so no lane starts on, or is spared by, the last.
#  - catch: a ball pushed south from z 166 down the slot, at its west edge, middle and east edge, at 0.6 to 2.0 x
#    cruise, is taken by the zip;
#  - back: a ball climbing the dam face north over the lip into the slot (at 0.9 x at its west edge, middle and east
#    edge; at 1.25 x in the middle), straight and 30 degrees either way, neither snags nor turns back;
#  - approach, sides and corners: a ball coming at the slot 30 and 60 degrees off its line, across it and
#    diagonally at its north corners neither snags nor turns back;
#  - crest: a ball crossing along the crest top beside the takeoff (z 186, 189) at 0.75 and 1.5 x is not taken
#    by the zip and does not snag;
#  - face: a ball crossing the dam face below the crest at 1.0 x does not snag; the zip may take it inside z 191..199
#    (the band moved up from the base's z 198..210 and is narrower), never at z 190 or z 202;
#  - drift: the slow crest crossers from review r1 (0.75 x, diagonally across the crest from z 165, glancing off the
#    north wall into the slot's north half) neither snag nor turn back.
# Planted: a ball pushed north at x -151 into the 6 m wall at the crest's north end (z 161) must read as a snag, so
# the detector is shown to catch one before its passes are trusted.

const SNAG_S := 0.2
const SNAG_FROM := 0.5
const BACK_M := 1.0
const RIDE_S := 8.0
# The ramp's centre line and the start of the south pushes.
const RAMP := Vector2(-151.0, 185.0)
const CATCH_X := [-154.0, -151.0, -148.0]
const CATCH_KS := [0.6, 0.75, 0.9, 1.0, 1.5, 2.0]
const BACK_X := [-153.0, -151.0, -149.0]

var _t := T.new("dam_takeoff_test")
var _game
var _rode := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(1)
	StageLocks.active = false
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

	var planted: Dictionary = await _roll(Vector2(-151.0, 170.0), Vector2(0.0, -1.0), 1.0, -150.0)
	_t.check("planted: a ball pushed north into the crest's north wall reads as a snag", planted["snag"] != "", str(planted))

	for x in CATCH_X:
		for k in CATCH_KS:
			var r: Dictionary = await _roll(Vector2(x, 166.0), Vector2(0.0, 1.0), k, 430.0)
			_t.check("catch: pushed south over the takeoff at x %d, %.2f x: the zip takes it" % [x, k], r["zip"], str(r))

	for k in [0.9, 1.25]:
		for x in BACK_X if k < 1.0 else [-151.0]:
			for off in [0.0, 30.0, -30.0]:
				var dir := Vector2(0.0, -1.0).rotated(deg_to_rad(off))
				var at := Vector2(x, 190.0) - dir * 4.0
				_clean("back: up the face over the lip at x %d, %d deg off north" % [x, off], await _roll(at, dir, k, at.dot(dir) + 14.0), k)

	for k in [0.75, 1.5]:
		for off in [30.0, -30.0, 60.0, -60.0]:
			var dir := Vector2(0.0, 1.0).rotated(deg_to_rad(off))
			var at := RAMP - dir * 14.0
			_clean("approach: south at the slot, %d deg off its line" % off, await _roll(at, dir, k, RAMP.dot(dir) + 10.0), k)
	for z in [183.0, 186.0]:
		_clean("side: west to east across the slot at z %d" % z, await _roll(Vector2(-162.0, z), Vector2(1.0, 0.0), 0.75, -140.0), 0.75)
		_clean("side: east to west across the slot at z %d" % z, await _roll(Vector2(-140.0, z), Vector2(-1.0, 0.0), 0.75, 162.0), 0.75)
	for corner in [Vector2(-156.0, 182.0), Vector2(-146.0, 182.0)]:
		var dir: Vector2 = (RAMP - corner).sign().normalized()
		var at: Vector2 = corner - dir * 14.0
		_clean("corner: diagonally in at %s" % corner, await _roll(at, dir, 1.0, corner.dot(dir) + 20.0), 1.0)

	for k in [0.75, 1.5]:
		for z in [186.0, 189.0]:
			for d in [1.0, -1.0]:
				var r: Dictionary = await _roll(Vector2(-151.0 - 12.0 * d, z), Vector2(d, 0.0), k, -151.0 * d + 12.0)
				_t.check("crest: along the crest top at z %d heading %s, %.2f x: no snag, not taken by the zip" % [z, _heading(d), k],
					r["snag"] == "" and not r["zip"], str(r))

	# x, heading in degrees from south (225 is north-east, 135 north-west), as in review r1's sweep: 20 m along it.
	for lane in [[-180.0, 225.0], [-176.0, 225.0], [-124.0, 135.0], [-120.0, 135.0]]:
		var dir := Vector2(0.0, 1.0).rotated(deg_to_rad(lane[1]))
		var at := Vector2(lane[0], 165.0)
		_clean("drift: across the crest from (%d, 165) heading %d" % [lane[0], lane[1]], await _roll(at, dir, 0.75, at.dot(dir) + 20.0), 0.75)

	for z in [190.0, 194.0, 198.0, 202.0]:
		for d in [1.0, -1.0]:
			var r: Dictionary = await _roll(Vector2(-151.0 - 12.0 * d, z), Vector2(d, 0.0), 1.0, -151.0 * d + 12.0)
			var in_band: bool = z > 191.0 and z < 199.0
			_t.check("face: across the dam face at z %d heading %s, 1.00 x: no snag%s" % [z, _heading(d), ", the zip may take it" if in_band else ", not taken by the zip"],
				r["snag"] == "" and (in_band or not r["zip"]), str(r))

	_game.queue_free()
	for i in 3:
		await process_frame
	StageLocks.active = true
	quit(_t.verdict())


func _heading(d: float) -> String:
	return "east" if d > 0.0 else "west"


# A lane passes when it never snags and never turns back. The zip may take it: the cable carries it on from there.
func _clean(name: String, r: Dictionary, k: float) -> void:
	_t.check("%s, %.2f x: no snag, no turn-back" % [name, k], r["snag"] == "" and r["back"] == "", str(r))


# A ball pushed along `dir` from `at` at k x cruise until its reach along `dir` passes `goal`, it turns back, it comes
# to rest, the zip takes it or RIDE_S runs out. Returns the snag ("" or where), the turn-back ("" or where), whether the
# zip took it (and where), whether the goal was reached, the furthest reach and the slowest flat speed over cruise.
func _roll(at: Vector2, dir: Vector2, k: float, goal: float) -> Dictionary:
	var cruise: float = _game.player.tuning.tier_cruise()
	# A zip ride outlives a teleport, and the cable then rests CABLE_REST (1 s) before it takes a ball again: drop the
	# ride and hold the ball still past that rest.
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
	var zip_at := ""
	var reach := -INF
	var slow := INF
	var rest_s := 0.0
	var t := 0.0
	while t < RIDE_S:
		await physics_frame
		t += tick_s
		var ball: Vector3 = _game.player.ball_position()
		var v: Vector3 = _game.player.state.velocity
		var flat := Vector2(v.x, v.z).length()
		if _game.world.ride != null:
			_rode = true
			zip_at = str(ball.snapped(Vector3.ONE * 0.1))
			break
		if t > 0.1:
			slow = minf(slow, flat)
		hist.append(flat)
		if hist.size() > span + 1:
			hist.pop_front()
		if hist.size() == span + 1 and hist[0] >= SNAG_FROM * cruise and snag == "" and flat <= 0.5 * hist[0]:
			snag = "(%.1f, %.1f, %.1f) %.2f -> %.2f x" % [ball.x, ball.y, ball.z, hist[0] / cruise, flat / cruise]
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
	return {"snag": snag, "back": back, "zip": _rode, "zip_at": zip_at, "passed": reach >= goal, "reach": snappedf(reach, 0.1),
		"slowest_x": snappedf(slow / cruise, 0.01), "end": _game.player.ball_position().snapped(Vector3.ONE * 0.1)}
