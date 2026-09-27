extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")

# The ball keeps moving in the Slag Bowl. The run reaches the arena the way play does,
# through a gate and stage 3's launch rail, then the ball is driven around the arena for
# 30 s on the real rigid ball, weaving between 40 and 52 m out across the floor-to-bank
# seam, while the fight runs. Every half second it must have moved, and its vertical
# speed must stay bounded. The failure this guards: a launch rail still setting the
# ball's velocity in the arena, which pinned it to the floor while v.y fell to -499.

const SECONDS := 30.0
const WINDOW := 0.5
const MIN_MOVE := 0.5
const MAX_VY := 30.0
const RADII := [40.0, 44.0, 47.0, 50.0, 52.0]

var _game
var _boss
var _source := Intent.Scripted.new()
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	Harness.install(_game)
	_boss = _game.boss
	_game.player.source = _source
	Harness.start_run(_game)
	var flow = _game.flow
	flow.enter_stage(3, Vector3(0.0, 0.0, 16.0), false)
	for _i in 30:
		await physics_frame
	flow._set_state(flow.GATES)
	_game.events.reward_chosen.emit("test_gate")
	var waited := 0
	while flow.state_name() != "boss" and waited < 300:
		await physics_frame
		waited += 1
	_report("arena through the launch", flow.state_name() == "boss",
		"a gate taken on stage 3 fired the launch rail and flow entered %s %.2f s later" % [flow.state_name(), waited / float(Engine.physics_ticks_per_second)])
	var ticks := int(SECONDS * Engine.physics_ticks_per_second)
	var window := int(WINDOW * Engine.physics_ticks_per_second)
	var last: Vector3 = _game.player.ball_position()
	var still_windows := 0
	var worst_vy := 0.0
	var worst_at := ""
	var r_min := INF
	var r_max := 0.0
	var laps := 0.0
	var prev_angle: float = _boss.arena.angle_of(last)
	for i in ticks:
		var ball: Vector3 = _game.player.ball_position()
		var r: float = _boss.arena.radius_of(ball)
		var angle: float = _boss.arena.angle_of(ball)
		laps += absf(angle_difference(prev_angle, angle)) / TAU
		prev_angle = angle
		var want: float = RADII[int(i / (3 * Engine.physics_ticks_per_second)) % RADII.size()]
		var ahead: Vector3 = _boss.arena.point_at(angle + 0.35, want)
		var flat := Vector3(ahead.x - ball.x, 0.0, ahead.z - ball.z)
		if flat.length() > 0.3:
			_game.camera.yaw = atan2(-flat.x, -flat.z)
		_source.hold = {"move": Vector2(0.0, 1.0), "boost_pressed": i % 180 == 0}
		await physics_frame
		_game.run.heal(1000.0)
		var now: Vector3 = _game.player.ball_position()
		var vy: float = absf(_game.player.body().linear_velocity.y)
		if vy > worst_vy:
			worst_vy = vy
			worst_at = "r %.1f, %.1f m above the arena ground, grounded %s" % [r, now.y - _boss.arena.ground(now), _game.player.state.grounded]
		r_min = minf(r_min, r)
		r_max = maxf(r_max, r)
		if (i + 1) % window == 0:
			if now.distance_to(last) < MIN_MOVE:
				still_windows += 1
			last = now
	_report("ball keeps moving", still_windows == 0,
		"%.0f s driven around the bowl between %.1f and %.1f m out (%.1f laps): %d half-second windows with under %.1f m of travel"
			% [SECONDS, r_min, r_max, laps, still_windows, MIN_MOVE])
	_report("vertical speed bounded", worst_vy < MAX_VY,
		"largest |v.y| %.1f m/s (limit %.0f), at %s" % [worst_vy, MAX_VY, worst_at])
	print("boss_ring_drive_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
