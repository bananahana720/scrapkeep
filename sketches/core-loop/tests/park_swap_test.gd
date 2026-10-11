extends SceneTree

# Rule (K-UNITS KB4, PARK.md sections 3 "Streaming" and 9): the next park stage's regions and
# collider build on worker threads while the current stage plays, with no main-thread frame
# over 33 ms; the swap applies on the launch landing (terrain.use(), as the flow runs it on
# stage_entered), and the ball lands on the next stage's collider. Only the active stage and
# the next one stay resident. Fixture: a two-stage table of park_test.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_test"}, {"stage": 2, "world": 1, "map": "park_test"}]}
const FRAME_CAP_MS := 33.0
const BUILD_FRAMES_MAX := 6000
const LAND_FRAMES_MAX := 1200

var t := T.new("park_swap_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var terrain = Terrain.new(TABLE)
	terrain.build(holder)
	terrain.use(1)
	if not t.check("terrain has the park streaming API", terrain.has_method("park_ground") and terrain.has_method("is_ready") and terrain.has_method("prepare")):
		quit(t.verdict())
		return
	t.check("stage 1 is ready at setup", terrain.is_ready(1))
	t.check("stage 2 is not built synchronously at setup", not terrain.is_ready(2))

	# The next stage builds while stage 1 plays: every frame is timed on the main thread.
	var t0 := Time.get_ticks_usec()
	terrain.prepare(2)
	var prepare_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var worst := prepare_ms
	var frames := 0
	var last := Time.get_ticks_usec()
	while not terrain.is_ready(2) and frames < BUILD_FRAMES_MAX:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		frames += 1
	var next = terrain.park_ground(2)
	print("park_swap_test: stage 2 built over %d frames, prepare() %.2f ms, worst main-thread frame %.2f ms, %d pieces on worker threads"
		% [frames, prepare_ms, worst, next.worker_pieces if next != null else -1])
	t.check("stage 2 finished building", terrain.is_ready(2), "%d frames" % frames)
	t.check("the build spanned frames (not one blocking call)", frames > 1, "%d frames" % frames)
	t.check("regions and tiles were built off the main thread", next != null and next.worker_pieces == 104, "%d pieces" % (next.worker_pieces if next != null else -1))
	t.check("no main-thread frame over 33 ms while stage 2 builds", worst < FRAME_CAP_MS, "worst %.2f ms" % worst)
	t.eq("stage 2 is still parked while stage 1 plays", terrain.stage, 1)

	# The launch: the ball leaves stage 1, and the swap applies when it comes down to land.
	var ball := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	shape.shape = sphere
	ball.add_child(shape)
	var spawn: Vector3 = terrain.spawn_point(1)
	holder.add_child(ball)
	ball.global_position = spawn + Vector3.UP * 6.0
	ball.linear_velocity = Vector3(4.0, 14.0, 0.0)
	var swapped := false
	var swap_ms := 0.0
	var after_worst := 0.0
	var landed_frames := 0
	last = Time.get_ticks_usec()
	for n in LAND_FRAMES_MAX:
		await physics_frame
		var now := Time.get_ticks_usec()
		if swapped:
			after_worst = maxf(after_worst, float(now - last) / 1000.0)
		last = now
		if not swapped and ball.linear_velocity.y < 0.0:
			var s0 := Time.get_ticks_usec()
			terrain.use(2)
			swap_ms = float(Time.get_ticks_usec() - s0) / 1000.0
			swapped = true
			last = Time.get_ticks_usec()
		if swapped and ball.linear_velocity.length() < 0.05:
			landed_frames += 1
			if landed_frames > 30:
				break
	t.check("the swap ran on the way down", swapped)
	t.check("the swap itself is under 33 ms", swap_ms < FRAME_CAP_MS, "%.2f ms" % swap_ms)
	t.check("no main-thread frame over 33 ms after the swap", after_worst < FRAME_CAP_MS, "worst %.2f ms" % after_worst)
	t.eq("stage 2 is active", terrain.stage, 2)
	var at := ball.global_position
	var floor_y: float = terrain.height(at.x, at.z)
	t.check("the ball rests on stage 2's ground", landed_frames > 30 and absf(at.y - 0.5 - floor_y) < 0.05, "ball %s, ground %.3f" % [str(at), floor_y])
	var space := holder.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.0)
	query.exclude = [ball.get_rid()]
	var hit := space.intersect_ray(query)
	var owner_root: Node = terrain.geometry_root(2)
	t.check("the collider under the ball is a stage 2 tile", not hit.is_empty() and owner_root.is_ancestor_of(hit["collider"]),
		str(hit.get("collider")))
	t.check("contains the ball", terrain.contains(at))
	ball.queue_free()
	holder.queue_free()
	await process_frame
	quit(t.verdict())
