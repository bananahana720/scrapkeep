# smoke: solo (verdict reads wall time: 33 ms main-thread frame cap during park streaming)
extends SceneTree

# Rule (K-UNITS KB4, PARK.md sections 3 "Streaming" and 9): the next park stage's regions and
# collider build on worker threads while the current stage plays, with no main-thread frame
# over 33 ms; the swap applies on the launch landing (terrain.use(), as the flow runs it on
# stage_entered), and the ball lands on the next stage's collider. Only the active stage and
# the next one stay resident. Fixture: a three-stage table of park_test; a new run back on stage 1
# (use(1) with stages 2 and 3 resident) frees stage 3 first so stage 1 gets a render node.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_test"}, {"stage": 2, "world": 1, "map": "park_test"},
	{"stage": 3, "world": 1, "map": "park_test"}]}
const FRAME_CAP_MS := 33.0
const BUILD_FRAMES_MAX := 6000
const LAND_FRAMES_MAX := 1200

var t := T.new("park_swap_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	# Terrain3D follows the active camera, as the game's; without one it prints an error each run.
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	var terrain = Terrain.new(TABLE)
	if not t.check("terrain has the park streaming API", terrain.has_method("park_ground") and terrain.has_method("is_ready") and terrain.has_method("prepare")):
		quit(t.verdict())
		return
	# Setup (the load screen, not play): stage 1 builds and the two Terrain3D render nodes take
	# their first frame (about 135 ms each, park_terrain.gd), so setup is not capped.
	terrain.build(holder)
	for n in 3:
		await process_frame
	t.check("stage 1 is ready at setup", terrain.is_ready(1))
	t.check("stage 2 is not built at setup", not terrain.is_ready(2) and terrain.park_ground(2) == null)

	# Landing on stage 1 starts stage 2's build. park_terrain.gd times every whole main-thread
	# frame while it builds (frame_usec_max) and terrain.gd times use() itself (last_use_usec).
	terrain.use(1)
	terrain.prepare(2)
	var use_ms: float = terrain.last_use_usec / 1000.0
	t.check("landing on stage 1 starts stage 2's build", terrain.park_ground(2) != null and not terrain.is_ready(2))
	var frames := 0
	while not terrain.is_ready(2) and frames < BUILD_FRAMES_MAX:
		await process_frame
		frames += 1
	var next = terrain.park_ground(2)
	var worst: float = next.frame_usec_max / 1000.0 if next != null else INF
	print("park_swap_test: stage 2 built over %d frames, use(1) %.2f ms, worst main-thread frame %.2f ms, slowest step %.2f ms at %s, %d pieces on worker threads"
		% [frames, use_ms, worst, next.slowest_usec / 1000.0 if next != null else -1.0, next.slowest_step if next != null else "", next.worker_pieces if next != null else -1])
	t.check("stage 2 finished building", terrain.is_ready(2), "%d frames" % frames)
	t.check("the build spanned frames (not one blocking call)", frames > 1, "%d frames" % frames)
	t.check("regions and tiles were built off the main thread", next != null and next.worker_pieces == 104, "%d pieces" % (next.worker_pieces if next != null else -1))
	t.check("the build's frames were timed", worst > 0.0, "%.2f ms" % worst)
	t.check("no main-thread frame over 33 ms while stage 2 builds", worst < FRAME_CAP_MS and use_ms < FRAME_CAP_MS, "worst %.2f ms, use(1) %.2f ms" % [worst, use_ms])
	# frame_usec_max never sees the frame of the last attach step (built, then the props, then
	# processing stops), so the slowest single step, timed around the whole pump, is capped too.
	t.check("slowest main-thread step under 33 ms", next != null and next.slowest_usec / 1000.0 < FRAME_CAP_MS,
		"%.2f ms at %s" % [next.slowest_usec / 1000.0 if next != null else -1.0, next.slowest_step if next != null else ""])
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
	ball.linear_velocity = Vector3(0.0, 14.0, 0.0)
	var swapped := false
	var swap_ms := 0.0
	var landed_frames := 0
	var after_frames := 0
	for n in LAND_FRAMES_MAX:
		await physics_frame
		if not swapped and ball.linear_velocity.y < 0.0:
			terrain.use(2)
			swap_ms = terrain.last_use_usec / 1000.0
			swapped = true
		elif swapped:
			after_frames += 1
		if swapped and ball.linear_velocity.length() < 0.05:
			landed_frames += 1
			if landed_frames > 30 and after_frames > 60:
				break
	var after_worst: float = next.frame_usec_max / 1000.0
	print("park_swap_test: use(2) %.2f ms, worst frame over the %d physics frames after the swap %.2f ms" % [swap_ms, after_frames, after_worst])
	t.check("the swap ran on the way down", swapped)
	t.check("the swap itself is under 33 ms", swap_ms < FRAME_CAP_MS, "%.2f ms" % swap_ms)
	t.check("the frames after the swap were timed", after_worst > 0.0 and after_frames > 60, "%d frames" % after_frames)
	t.check("no main-thread frame over 33 ms after the swap", after_worst < FRAME_CAP_MS, "worst %.2f ms" % after_worst)
	t.eq("stage 2 is active", terrain.stage, 2)
	# Stage 2's scatter (terrain.gd starts it when the ground is done) attached during the flight and the
	# landing; its own frame meter and the step meter are capped like the ground's (KB5b).
	var scatter: Node = terrain.geometry_root(2).get_node_or_null("GroundScatter")
	t.check("stage 2 carries a chunked scatter", scatter != null and scatter.has_method("is_ready"))
	var scatter_frames := 0
	while scatter != null and not scatter.is_ready() and scatter_frames < BUILD_FRAMES_MAX:
		await process_frame
		scatter_frames += 1
	t.check("stage 2's scatter finished attaching", scatter != null and scatter.is_ready(), "%d extra frames" % scatter_frames)
	t.eq("stage 2's scatter holds 100 chunks", scatter.get_child_count() if scatter != null else -1, 100)
	var scatter_frame_ms: float = scatter.frame_usec_max / 1000.0 if scatter != null else INF
	var scatter_step_ms: float = scatter.slowest_usec / 1000.0 if scatter != null else INF
	print("park_swap_test: scatter attaching during the flight: worst main-thread frame %.2f ms (ground meter %.2f ms), slowest scatter step %.2f ms at %s"
		% [scatter_frame_ms, after_worst, scatter_step_ms, scatter.slowest_step if scatter != null else ""])
	t.check("no main-thread frame over 33 ms with the scatter attaching", scatter_frame_ms < FRAME_CAP_MS, "scatter %.2f ms (ground meter %.2f ms)" % [scatter_frame_ms, after_worst])
	t.check("no scatter step over 8 ms", scatter_step_ms < 8.0, "%.2f ms" % scatter_step_ms)
	# Stage 2's park rows (KB9) placed beside the scatter: GLBs and slot materials on the loader thread, then a few rows a
	# frame on the main thread (a row makes meshes and shapes, which stay off workers); the slowest step is capped like
	# the scatter's.
	var rows: Node = terrain.park_rows(2)
	var row_frames := 0
	while rows != null and not rows.is_ready() and row_frames < BUILD_FRAMES_MAX:
		await process_frame
		row_frames += 1
	var row_step_ms: float = rows.slowest_usec / 1000.0 if rows != null else INF
	var row_frame_ms: float = rows.frame_usec_max / 1000.0 if rows != null else INF
	print("park_swap_test: stage 2 rows placed (%d extra frames): %d nodes, %d loads on the loader thread, placed over %d frames, costliest row %.2f ms, worst frame %.2f ms, slowest step %.2f ms at %s"
		% [row_frames, rows.get_child_count() if rows != null else -1, rows.threaded_loads if rows != null else -1, rows.build_frames if rows != null else -1, rows.row_usec_max / 1000.0 if rows != null else -1.0,
		row_frame_ms, row_step_ms, rows.slowest_step if rows != null else ""])
	t.check("stage 2 places its park rows", rows != null and rows.is_ready() and rows.get_child_count() > 0, "%d extra frames" % row_frames)
	# Headless (the dummy rasterizer, whose mesh RID owner is not thread-safe) the rows load on the main thread instead.
	if DisplayServer.get_name() != "headless":
		t.check("stage 2's recipe GLBs and materials load on the loader thread", rows != null and rows.threaded_loads > 0, str(rows.threaded_loads if rows != null else -1))
	else:
		t.check("headless, stage 2's recipe GLBs and materials load on the main thread, none on the loader", rows != null and rows.threaded_loads == 0 and rows.get_child_count() > 0, str(rows.threaded_loads if rows != null else -1))
	t.check("stage 2's rows place over several frames, not in one", rows != null and rows.build_frames > 1, "%d frames" % (rows.build_frames if rows != null else -1))
	t.check("no main-thread frame over 33 ms with the rows placing", row_frame_ms < FRAME_CAP_MS, "%.2f ms" % row_frame_ms)
	t.check("no row placement step over 8 ms", row_step_ms < 8.0, "%.2f ms at %s" % [row_step_ms, rows.slowest_step if rows != null else ""])
	t.check("stage 1 left memory (only the active and next stage stay)", terrain.park_ground(1) == null and holder.get_node_or_null("Stage1") == null)
	# terrain.gd's Reaper frees a swapped-out stage over frames, under a new name; it must finish.
	t.check("stage 1's freed nodes are all gone", _freed_left(holder).is_empty(), str(_freed_left(holder)))
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

	# A new run after dying on stage 2 (flow.gd _begin_run reuses the terrain): stages 2 and 3
	# hold both render nodes, and use(1) must free stage 3 before stage 1 builds, so stage 1
	# draws instead of standing as a bare collider. Stage 3 started building when stage 2's
	# Warden woke (world.gd calls prepare on warden_engaged; KB4b), as stage 2 did above.
	terrain.prepare(3)
	for n in 3:
		await process_frame
	t.check("before the new run, stages 2 and 3 hold both render nodes", terrain._render_owner.has(1) and terrain._render_owner.has(2),
		str(terrain._render_owner))
	terrain.use(1)
	var first = terrain.park_ground(1)
	t.check("the new run's stage 1 is built and ready", first != null and terrain.is_ready(1))
	t.check("the new run's stage 1 draws into a Terrain3D node", first != null and first.terrain3d != null, str(terrain._render_owner))
	t.check("a render node belongs to stage 1", terrain._render_owner.has(0), str(terrain._render_owner))
	t.check("stage 3 left memory on the new run", terrain.park_ground(3) == null)
	t.check("stage 2 stays as the next stage", terrain.park_ground(2) != null)
	var shown := 0
	for node in terrain._render:
		if node.visible:
			shown += 1
			t.check("the shown render node is stage 1's", terrain._render_owner[terrain._render.find(node)] == 0)
	t.eq("one render node shows on the new run", shown, 1)

	# The swap while a stage's rows are still placing (KB9): stage 3 builds, and use(3) lands the frame its ground is
	# ready, before its rows have all attached; the swap stays under the cap and the rows finish on their own. use(3)
	# frees stages 1 and 2 in the one swap, as a new run's use(1) can, so two freed stages empty at once.
	terrain.prepare(3)
	var ground_frames := 0
	while not terrain.is_ready(3) and ground_frames < BUILD_FRAMES_MAX:
		await process_frame
		ground_frames += 1
	var placing: Node = terrain.park_rows(3)
	var placing_at_swap: bool = placing != null and not placing.is_ready()
	terrain.use(3)
	var placing_swap_ms: float = terrain.last_use_usec / 1000.0
	var tail := 0
	while placing != null and not placing.is_ready() and tail < BUILD_FRAMES_MAX:
		await process_frame
		tail += 1
	var placing_step_ms: float = placing.slowest_usec / 1000.0 if placing != null else INF
	print("park_swap_test: use(3) with its rows placing %s: %.2f ms; rows done %d frames later, worst frame %.2f ms, slowest step %.2f ms at %s, slowest headless load %.2f ms"
		% [placing_at_swap, placing_swap_ms, tail, placing.frame_usec_max / 1000.0 if placing != null else -1.0, placing_step_ms, placing.slowest_step if placing != null else "",
		placing.main_load_usec_max / 1000.0 if placing != null else -1.0])
	t.check("the swap lands while the stage's rows are still placing", placing_at_swap)
	t.check("the swap with rows placing is under 33 ms", placing_swap_ms < FRAME_CAP_MS, "%.2f ms" % placing_swap_ms)
	t.check("the rows finish placing after the swap", placing != null and placing.is_ready(), "%d frames" % tail)
	t.check("no row placement step over 8 ms across the swap", placing_step_ms < 8.0, "%.2f ms" % placing_step_ms)
	t.check("no main-thread frame over 33 ms while rows place across the swap", placing != null and placing.frame_usec_max / 1000.0 < FRAME_CAP_MS,
		"%.2f ms" % (placing.frame_usec_max / 1000.0 if placing != null else -1.0))
	var reap_frames := 0
	while not _freed_left(holder).is_empty() and reap_frames < BUILD_FRAMES_MAX:
		await process_frame
		reap_frames += 1
	t.check("the stages freed across the swap are all gone", _freed_left(holder).is_empty(), "%s after %d frames" % [_freed_left(holder), reap_frames])
	for n in 3:
		await process_frame
	holder.queue_free()
	await process_frame
	quit(t.verdict())


# The freed stage roots still under holder (terrain.gd Reaper names them Freed<name> until they are gone).
func _freed_left(holder: Node) -> Array:
	return holder.get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("Freed")).map(func(n: Node) -> String: return String(n.name))
