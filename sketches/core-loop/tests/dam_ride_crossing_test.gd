extends SceneTree
# smoke: solo timeout=420s

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const T := preload("res://tests/support/t.gd")

# E1-05 (ruling ek, design-v3/WAYFINDING.md 2.2): the dam's intake takeoff (park_dam.json intake_takeoff, a 1.1 m ramp
# on the crest at about x -154..-148, z 180..190, turned 8 degrees east, whose lip is the crest edge) and the Sunken
# Pump Yard shelf (pump_yard_shelf*, two stacked 1.15 m steps to a 2.3 m flat top at x 156..164, z 470..546) must
# never snag a rolling ball (ruling ct point 8c: a ball that loses half its flat speed within 0.2 s), from any side, and
# the takeoff must still put a ball on the intake zip. Read on the real dam with the yard locks off, the ball unsteered:
#  - zip: a ball pushed south over the takeoff at 1.0, 1.5 and 2.0 x cruise is carried by the zip (it hangs 8 m or more
#    over the ground between z 260 and 430);
#  - shelf ride: a ball pushed south from z 340 down the east descent at x 158..162 rides the shelf's top (3 m or more
#    up for nine tenths of z 480..520) with no snag, at 1.0 and 1.5 x cruise;
#  - crossings at 1.0 and 1.5 x cruise (see _lane): across the shelf west to east and east to west at z 456 to 530,
#    north into its south end, and across the takeoff's sides at z 182..188 and the dam face below its lip at z 196, 200.
# Planted: a ball pushed south at x 140 into the powerhouse's north face, a face square to its path, must read as a
# snag, so the detector is shown to catch one before its passes are trusted. The first cut of this change (104d803c7:
# a sheer 2.5 m shelf and 6.5 m takeoff sides) fails 29 of these checks; the base (49b4dbbb5) snags in no lane.

const SNAG_S := 0.2
const RIDE_S := 8.0
const KS := [1.0, 1.5]
const SHELF_Z := [456.0, 480.0, 510.0, 530.0]
const RAMP_Z := [182.0, 185.0, 188.0, 196.0, 200.0]

var _t := T.new("dam_ride_crossing_test")
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
		for x in [158.0, 160.0, 162.0]:
			var r: Dictionary = await _roll(Vector2(x, 340.0), Vector2(0.0, 1.0), k, 520.0, true)
			_t.check("shelf ride x %d at %.1f x: no snag, rides the top to z 520" % [x, k],
				r["snag"] == "" and r["top_share"] >= 0.9 and r["passed"], str(r))
		for z in SHELF_Z:
			var west := 140.0 if z < 490.0 else 151.5
			_lane("shelf west to east z %d" % z, await _roll(Vector2(west, z), Vector2(1.0, 0.0), k, 172.0), k, 157.0)
			_lane("shelf east to west z %d" % z, await _roll(Vector2(185.0, z), Vector2(-1.0, 0.0), k, -152.0), k, -163.0)
		for x in [156.0, 160.0, 164.0]:
			_lane("shelf south end x %d northward" % x, await _roll(Vector2(x, 562.0), Vector2(0.0, -1.0), k, -520.0), k, -540.0)
		for z in RAMP_Z:
			_lane("takeoff side west to east z %d" % z, await _roll(Vector2(-163.0, z), Vector2(1.0, 0.0), k, -140.0), k, -155.0, z == 188.0)
			_lane("takeoff side east to west z %d" % z, await _roll(Vector2(-139.0, z), Vector2(-1.0, 0.0), k, 162.0), k, 147.0, z == 188.0)
	await _drop()
	StageLocks.active = true
	quit(_t.verdict())


# A crossing passes when it never snags and the ball gets over the piece's first face (`climb`, a signed reach along its
# path); at 1.5 x cruise it must clear the whole piece too, unless it rolled off the crest's south edge on the way (the
# z 188 lane runs 2 m from that edge, and the dam face takes the ball down: that is the dam, not a face stopping it).
# A 1.0 x ball may coast to a stop on the shelf's top after the 2.3 m climb: the climb slows it, which ruling cu
# allows, and no face stops it.
func _lane(name: String, r: Dictionary, k: float, climb: float, edge := false) -> void:
	var off_crest: bool = edge and r["end"].z > 192.0
	var ok: bool = r["snag"] == "" and r["reach"] >= climb and (k < 1.5 or r["passed"] or off_crest)
	_t.check("%s at %.1f x: no snag, %s" % [name, k, "climbs on" if k < 1.5 else "crosses"], ok, str(r))


# A ball pushed along `dir` from `at` at k x cruise until its signed reach along `dir` passes `goal` (a coordinate on the
# axis of travel, negated for a ball heading -x or -z) or RIDE_S runs out. Returns the snag ("" or where), whether the
# goal was reached, the furthest signed reach, the worst 0.2 s drop (from -> to, x cruise, among windows that start above
# 0.6 x) and, with `top`, the share of z 480..540 samples 3 m up.
func _roll(at: Vector2, dir: Vector2, k: float, goal: float, top := false) -> Dictionary:
	var cruise: float = _game.player.tuning.tier_cruise()
	_game.player.set_velocity_now(Vector3.ZERO, "probe")
	_game.player.body().global_position = _game.ctx.terrain.drop_point(at.x, at.y, 1.0)
	for i in 2:
		await physics_frame
	_game.player.body().global_position = _game.ctx.terrain.drop_point(at.x, at.y, 1.0)
	_game.player.set_velocity_now(Vector3(dir.x, 0.0, dir.y) * cruise * k, "probe")
	var span := maxi(1, roundi(SNAG_S * Engine.physics_ticks_per_second))
	var hist: Array[float] = []
	var snag := ""
	var worst := Vector2(0.0, 0.0)
	var worst_ratio := INF
	var reach := -INF
	var top_n := 0
	var top_on := 0
	var t := 0.0
	while t < RIDE_S:
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
		var ball: Vector3 = _game.player.ball_position()
		var v: Vector3 = _game.player.state.velocity
		var flat := Vector2(v.x, v.z).length()
		hist.append(flat)
		if hist.size() > span + 1:
			hist.pop_front()
		if hist.size() == span + 1 and hist[0] > 0.6 * cruise:
			if flat / hist[0] < worst_ratio:
				worst_ratio = flat / hist[0]
				worst = Vector2(hist[0], flat)
			if snag == "" and flat <= 0.5 * hist[0]:
				snag = "(%.1f, %.1f, %.1f) %.2f -> %.2f x" % [ball.x, ball.y, ball.z, hist[0] / cruise, flat / cruise]
		if top and ball.z >= 480.0 and ball.z <= 540.0:
			top_n += 1
			if ball.y >= 3.0:
				top_on += 1
		reach = maxf(reach, Vector2(ball.x, ball.z).dot(dir))
		if reach >= goal:
			break
	return {"snag": snag, "passed": reach >= goal, "reach": snappedf(reach, 0.1),
		"worst": "%.2f -> %.2f x" % [worst.x / cruise, worst.y / cruise],
		"top_share": snappedf(float(top_on) / maxf(top_n, 1.0), 0.01), "end": _game.player.ball_position().snapped(Vector3.ONE * 0.1)}


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
