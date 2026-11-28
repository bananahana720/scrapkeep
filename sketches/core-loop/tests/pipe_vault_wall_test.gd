extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Library := preload("res://src/world/pockets/pocket_library.gd")
const RunLog := preload("res://src/core/run_log.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
var t := T.new("pipe_vault_wall_test")

# PARK-PIPEVAULT. A stage-5 floor run (SQ9 round 5) crossed the pipe vault's corner at 20 m/s and
# the traversal detector counted a dead stop on a terrain block's vertical face. The wall now has
# no friction and a small bounce: glancing (60) and 22 degree hits keep moving, a head-on hit stays a wall.
# Each case runs on the real pipe_vault site (its terrain block and its cache's cracked face),
# rolled 20 m/s at the face, scored with RunLog.Traversal.
const SPEED := 20.0
const GLANCING := 60.0
const STRIKE := 22.0 # the SQ9 round-5 trace: 22 degrees off the face normal, red at the base
const HEAD_ON := 10.0
const WINDOW_S := 0.15

var game
var floor_body: StaticBody3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	game.world.set_physics_process(false)
	game.flow.set_physics_process(false)
	game.player.set_physics_process(false)
	var acts = game.world.activities
	acts.set_physics_process(false)
	acts.clear()
	await physics_frame
	var entry: Dictionary = Library.rows().filter(func(row): return row.id == "pipe_vault")[0]
	var site = acts._build(entry.activity, Vector2(0, 0), Library.site_spec(entry))
	acts.sites.append(site)
	site.global_position = Vector3(0, 400, 0)
	site.rotation.y = -PI * 0.5
	floor_body = StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(400, 2, 400)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	floor_body.global_position = Vector3(0, 399, 0)
	acts._activate_interior_collision(site)
	await physics_frame
	var block: Dictionary = entry.terrain[0]
	# The block's local -z face is world +x here; the cracked face's local +z face is world -x.
	var block_face: Vector3 = site.to_global(Vector3(block.at[0], 1.0, block.at[1] - float(block.size[2]) * 0.5))
	var block_normal: Vector3 = site.global_basis * Vector3(0, 0, -1)
	var cache_face: Vector3 = site.to_global(Vector3(0, 1.0, 0.5))
	var cache_normal: Vector3 = site.global_basis * Vector3(0, 0, 1)
	t.near("the block face points world +x", block_normal.x, 1.0, 0.001)
	t.near("the cache face points world -x", cache_normal.x, -1.0, 0.001)
	for case in [["block", block_face, block_normal], ["cache wall", cache_face, cache_normal]]:
		var glance := await _strike(case[1], case[2], GLANCING)
		t.check("%s glancing (%d degrees): kept %.0f%% of its planar speed, %d dead stops, %.1f m/s rebound" % [case[0], GLANCING, glance.kept * 100.0, glance.dead_stops, glance.rebound],
			glance.reached and glance.kept >= 0.8 and glance.dead_stops == 0)
		var strike := await _strike(case[1], case[2], STRIKE)
		t.check("%s strike (%d degrees): %d dead stops, kept %.0f%%, %.1f m/s rebound" % [case[0], STRIKE, strike.dead_stops, strike.kept * 100.0, strike.rebound],
			strike.reached and strike.dead_stops == 0)
		var head := await _strike(case[1], case[2], HEAD_ON)
		t.check("%s head-on (%d degrees): rebound %.1f m/s of %.0f, kept %.0f%%" % [case[0], HEAD_ON, head.rebound, SPEED, head.kept * 100.0],
			head.reached and head.rebound <= 0.4 * SPEED)
	game.free()
	quit(t.verdict())

# Rolls the ball at the face from `degrees` off its normal. The ball's centre meets the face
# plane a radius out, at the face point. Scores the 0.15 s after the first contact.
func _strike(face: Vector3, normal: Vector3, degrees: float) -> Dictionary:
	var ball = game.player.body()
	var along := normal.cross(Vector3.UP)
	var direction := (-normal * cos(deg_to_rad(degrees)) + along * sin(deg_to_rad(degrees))).normalized()
	var velocity := direction * SPEED
	var meet := face + normal * 1.0
	meet.y = 401.0
	ball.freeze = false
	ball.global_position = meet - direction * 8.0
	ball.linear_velocity = velocity
	ball.angular_velocity = Vector3.UP.cross(velocity) / 1.0
	ball.set_active(true)
	ball.set_velocity_now(velocity)
	var cruise: float = game.player.tuning.f("cruise")
	var detector := RunLog.Traversal.new(Engine.physics_ticks_per_second, cruise)
	var contact_tick := -1
	var window := int(round(WINDOW_S * Engine.physics_ticks_per_second))
	var result := {"reached": false, "kept": 0.0, "dead_stops": 0, "rebound": 0.0}
	for i in int(Engine.physics_ticks_per_second * 1.2):
		await physics_frame
		var planar := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
		detector.step(SpeedTier.of(planar, cruise), planar, false, false)
		var gap: float = (ball.global_position - face).dot(normal)
		if contact_tick < 0 and gap < 1.05:
			contact_tick = i
			result.reached = true
		if contact_tick >= 0 and i == contact_tick + window:
			result.kept = planar / SPEED
			result.rebound = maxf(0.0, ball.linear_velocity.dot(normal))
			break
	result.dead_stops = detector.dead_stops
	ball.set_active(false)
	ball.freeze = true
	return result
