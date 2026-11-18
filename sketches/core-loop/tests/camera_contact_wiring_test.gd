extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# The chase camera lifts its arm near Brindle's ship and near the dam-face Warden only while those fights are on.
# Seen through the camera's arm angle in the real game: lifted when the ball is close to the body, level again once
# the arena is left, Brindle is beaten, or the Warden is beaten, freed or abandoned.

# The arm is raised more than this over the player's pitch when the contact lift is on (it reaches
# ChaseCamera.CONTACT_LIFT_MAX) and less when it is off. The ball falls out of the freed arena, and the camera's
# "falling" row tips the arm by 0.21 with no lift, so the line sits between that and the lift.
const LIFT_SEEN := 0.3
const SETTLE_FRAMES := 90
const DAM_LOOK_UP := 0.5

var _t := T.new("camera_contact_wiring_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _brindle()
	for ending in ["beaten", "abandoned", "freed"]:
		await _dam(ending)
	quit(_t.verdict())


func _settle(game) -> void:
	for i in SETTLE_FRAMES:
		await physics_frame
		await process_frame


# How far the arm is raised over the player's own pitch.
func _raised(game) -> float:
	var cam = game.ctx.camera
	return cam.pitch - cam.arm.rotation.x


func _brindle() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	await physics_frame
	game.player.source = Intent.Scripted.new()
	Harness.start_run(game)
	Harness.enter(game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	var boss = game.boss
	game.ctx.calm = true
	var near: Vector3 = boss.ship.global_position + Vector3(0.0, 2.0, 6.0)
	Harness.put_ball(game, near)
	game.ctx.camera.snap(Vector3.FORWARD)
	await _settle(game)
	_t.check("W1 in Brindle's arena the arm lifts when the ball is near the ship", _raised(game) > LIFT_SEEN, "raised %.3f rad" % _raised(game))
	boss.exit_arena()
	await _settle(game)
	_t.check("W2 leaving the arena puts the arm back", _raised(game) < LIFT_SEEN, "raised %.3f rad" % _raised(game))
	Harness.enter(game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	Harness.put_ball(game, boss.ship.global_position + Vector3(0.0, 2.0, 6.0))
	game.ctx.camera.snap(Vector3.FORWARD)
	await _settle(game)
	_t.check("W3 entering again lifts the arm again", _raised(game) > LIFT_SEEN, "raised %.3f rad" % _raised(game))
	Harness.defeat(game)
	await _settle(game)
	_t.check("W4 beating Brindle puts the arm back", _raised(game) < LIFT_SEEN, "raised %.3f rad" % _raised(game))
	game.free()


func _dam(ending: String) -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(1)
	for i in 40:
		await physics_frame
	var warden = game.flow.warden
	var ring: Vector3 = game.ctx.terrain.beacon_point(game.run.stage)
	game.player.reset_to(game.ctx.terrain.drop_point(ring.x, ring.z, Tuning.RADIUS), Vector3.ZERO)
	for i in 2:
		await physics_frame
	var at: Vector3 = warden.global_position + Vector3(0.0, 0.0, 6.0)
	Harness.put_ball(game, game.ctx.terrain.drop_point(at.x, at.z, Tuning.RADIUS))
	# The Warden stands high on the dam face, so the lift acts as it does for a player who looks up at it.
	var to_warden: Vector3 = warden.global_position - game.player.ball_position()
	game.ctx.camera.snap(Vector3(to_warden.x, 0.0, to_warden.z).normalized(), DAM_LOOK_UP)
	await _settle(game)
	_t.check("W5 the dam fight is on (%s)" % ending, game.flow.engaged() and warden.hp > 0.0, "engaged %s, hp %.1f" % [game.flow.engaged(), warden.hp])
	_t.check("W6 in the dam-face fight the arm lifts when the ball is near the Warden (%s)" % ending, _raised(game) > LIFT_SEEN, "raised %.3f rad, %.1f m off" % [_raised(game), game.ctx.camera.global_position.distance_to(warden.global_position)])
	match ending:
		"beaten":
			warden.hp = 0.0
		"abandoned":
			warden.live = func(): return false
		"freed":
			warden.queue_free()
	await _settle(game)
	_t.check("W7 the arm goes back when the Warden is %s" % ending, _raised(game) < LIFT_SEEN, "raised %.3f rad" % _raised(game))
	game.free()

