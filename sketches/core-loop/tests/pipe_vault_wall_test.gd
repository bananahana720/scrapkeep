extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Library := preload("res://src/world/pockets/pocket_library.gd")
const RunLog := preload("res://src/core/run_log.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
var t := T.new("pipe_vault_wall_test")

# PARK-PIPEVAULT. A stage-5 floor run (seed 8, SQ9 round 5) crossed the pipe vault's south-east
# corner at 20 m/s and the traversal detector counted a dead stop: the first terrain block's
# east face is a plain vertical box face, and the ball met it with the speed and direction below
# (planar velocity from the 35.50 s trace tick, 22 degrees off the face normal). The vault sat at
# the same stage spot rotated a quarter turn, so the face is the block's local -z face.
const APPROACH := Vector3(-18.46, 0.0, 7.65)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Game.new()
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
	var floor_body := StaticBody3D.new()
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
	var centre: Vector3 = site.to_global(Vector3(block.at[0], block.size[1] * 0.5, block.at[1]))
	t.near("block's east face is its local -z face, world +x", (site.global_basis * Vector3(0, 0, -1)).x, 1.0, 0.001)
	var face_x := centre.x + float(block.size[2]) * 0.5
	var ball = game.player.active_body()
	var direction := APPROACH.normalized()
	var strike := Vector3(face_x + 1.0, 401.0, centre.z)
	ball.freeze = false
	ball.global_position = strike - direction * 8.0
	ball.linear_velocity = APPROACH
	ball.angular_velocity = Vector3.UP.cross(APPROACH) / 1.0
	ball.set_active(true)
	ball.set_velocity_now(APPROACH)
	var cruise: float = game.player.tuning.f("cruise")
	var detector := RunLog.Traversal.new(Engine.physics_ticks_per_second, cruise)
	var peak := 0.0
	var slowest := INF
	var trace := []
	var struck := false
	for i in int(Engine.physics_ticks_per_second * 1.5):
		await physics_frame
		var planar := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
		detector.step(SpeedTier.of(planar, cruise), planar, false, false)
		peak = maxf(peak, planar)
		if ball.global_position.x < face_x + 1.6:
			struck = true
		if struck:
			if trace.size() < 14:
				slowest = minf(slowest, planar)
				trace.append("%.1f/%.1f" % [ball.linear_velocity.x, planar])
	print("strike ticks, x velocity / planar speed: ", ", ".join(trace))
	t.check("the ball reached the face", struck, "x %s" % ball.global_position.x)
	t.check("the approach was a real run (peak at least tier 1)", peak >= SpeedTier.MULTIPLES[1] * cruise, "peak %s" % peak)
	t.eq("the strike is no dead stop (peak %.1f, slowest in the 14 ticks after %.1f m/s)" % [peak, slowest], detector.dead_stops, 0)
	game.free()
	quit(t.verdict())
