extends SceneTree
# smoke: solo timeout=300s

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const T := preload("res://tests/support/t.gd")

# PF-46 (12 Nov): the dam's construction incline (23 degrees, z 190 to 420) crosses 200 m from the
# beacon mid-slope, and the yard lock used to shut there, so its spring wall stood on the slope at
# z ~416 and threw a ball riding down at 2 x cruise back up the hill. The yard now shuts on level
# ground, or on any ground inside the inner share of the circle (stage_locks.gd lock_arms):
# - rule: level ground arms in the circle; a slope or a gripped wall arms only in the inner share;
#   airborne or outside never arms;
# - ride: on the real dam a ball pushed at cruise down the incline at x -30 and x 0 (the PF-46 probe,
#   tools/sysaudit/roll_speed_probe.gd) never turns back before the apron, keeps at least 2 x cruise
#   through the foot, and the yard's centre lands on level ground past the foot.

const FOOT_Z := 420.0
const RIDE_S := 5.0

var _t := T.new("dam_incline_yard_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(1)
	_rule()
	for x in [-30.0, 0.0]:
		await _ride(x)
	quit(_t.verdict())


func _rule() -> void:
	var within := float(LockRows.row("park_dam")["lock"]["within_m"])
	var slope := cos(deg_to_rad(23.0))
	_t.check("level ground in the circle arms", StageLocks.lock_arms(true, 1.0, within - 1.0, within))
	_t.check("the incline in the outer circle does not arm", not StageLocks.lock_arms(true, slope, within - 1.0, within))
	_t.check("the incline in the inner share arms",
		StageLocks.lock_arms(true, slope, within * StageLocks.LOCK_ANY_SLOPE_SHARE - 1.0, within))
	_t.check("a gripped wall in the inner share arms",
		StageLocks.lock_arms(true, 0.1, within * StageLocks.LOCK_ANY_SLOPE_SHARE - 1.0, within))
	_t.check("airborne never arms", not StageLocks.lock_arms(false, 1.0, 10.0, within))
	_t.check("outside the circle never arms", not StageLocks.lock_arms(true, 1.0, within + 1.0, within))
	# The inner share must reach past the incline's foot on its whole width, so a ball that rides it
	# without touching level ground still shuts the yard on the apron, not on the slope.
	var beacon := Vector2(0.0, 575.0)
	for x in [-50.0, 0.0, 50.0]:
		_t.check("the inner share starts past the incline foot at x %d" % x,
			beacon.distance_to(Vector2(x, FOOT_Z)) > within * StageLocks.LOCK_ANY_SLOPE_SHARE)


func _ride(x: float) -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 120:
		await physics_frame
	game.ctx.calm = true
	game.run.set_max_hp(99999.0)
	var locks = game.flow.gate
	_t.eq("x %d: the yard is armed before the ride" % x, locks.lock_state, "armed")
	var cruise: float = game.player.tuning.tier_cruise()
	game.player.body().global_position = game.ctx.terrain.drop_point(x, 330.0, 1.0)
	game.player.set_velocity_now(Vector3(0.0, 0.0, cruise), "probe")
	var turned_at := INF
	var foot_speed := 0.0
	var locked_at := INF
	var t := 0.0
	while t < RIDE_S:
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
		var ball: Vector3 = game.player.ball_position()
		if locked_at == INF and locks.lock_state == "locked":
			locked_at = ball.z
		if ball.z < FOOT_Z + 6.0 and game.player.state.velocity.z < 0.0 and turned_at == INF and t > 0.2:
			turned_at = ball.z
		if ball.z >= FOOT_Z - 2.0 and ball.z <= FOOT_Z + 6.0:
			foot_speed = maxf(foot_speed, Vector2(game.player.state.velocity.x, game.player.state.velocity.z).length())
		if ball.z > FOOT_Z + 6.0:
			break
	_t.check("x %d: the ball never turns back up the incline" % x, turned_at == INF, "turned at z %.1f" % turned_at)
	_t.check("x %d: it keeps 2 x cruise through the foot" % x, foot_speed >= 2.0 * cruise,
		"%.2f x cruise" % (foot_speed / cruise))
	_t.check("x %d: the yard shuts past the foot, before the ride leaves it" % x, locked_at >= FOOT_Z and locked_at < INF,
		"locked at z %.1f" % locked_at)
	if locks.lock_state == "locked":
		var c: Vector3 = locks.lock_centre
		var rise: float = absf(game.ctx.terrain.height(c.x, c.z + 4.0) - game.ctx.terrain.height(c.x, c.z - 4.0)) / 8.0
		_t.check("x %d: the yard's centre is on level ground" % x, rise < 0.2, "grade %.2f at z %.1f" % [rise, c.z])
	game.queue_free()
	for i in 3:
		await process_frame
