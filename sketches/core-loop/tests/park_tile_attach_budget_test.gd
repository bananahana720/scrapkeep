extends SceneTree

# Rule (dam f5773-5800 on the 4080, #499 rows): while a stage's terrain attaches during play, a
# frame starts a second collider tile only when the last tile's cost still fits the attach budget.
# A cold tile add is Jolt building its mesh shape (about 7 ms on the 4080); two a frame held the dam at
# 18 ms of _process for 50 frames. The rule is checked on ParkTerrain.tile_fits with set numbers
# (no wall clock). A played attach builds the shapes on the pool first (rule below). Fixture: a ParkTerrain at its tile step whose first two tiles
# carry a real tile's 12,800 triangles and the rest one each; the landing's finish (deadline -1)
# still adds every tile.

const T := preload("res://tests/support/t.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")

var t := T.new("park_tile_attach_budget_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ground := _ground()

	var budget := ParkTerrain.ATTACH_BUDGET_USEC
	t.check("the first tile of a frame goes in while the deadline stands, however costly the last",
		ParkTerrain.tile_fits(0, 1000, 1000 + budget, 2 * budget) and not ParkTerrain.tile_fits(0, 1001 + budget, 1000 + budget, 0))
	t.check("a later tile goes in only when the last one's cost still fits",
		ParkTerrain.tile_fits(1, 2000, 1000 + budget, 1000) and not ParkTerrain.tile_fits(1, 2000, 1000 + budget, budget))
	t.check("never more than TILES_PER_FRAME a frame", not ParkTerrain.tile_fits(ParkTerrain.TILES_PER_FRAME, 0, budget, 0))

	# Rule (#512 4080 probe, w29 seed 3): a played attach adds no body until every tile's Jolt shape is built on the
	# pool. It makes TILES_PER_FRAME holders a step, starts the build on the step that makes the last, then adds
	# TILES_PER_FRAME bodies a step, which take the built shapes (no Jolt build on the main thread).
	var steps := 0
	var made_steps := 0
	while ground._next_shape < ParkTerrain.TILE_COUNT and steps < 2 * ParkTerrain.TILE_COUNT:
		var before: int = ground._next_shape
		ground._attach_step(1 << 62)
		steps += 1
		if ground._next_shape - before == ParkTerrain.TILES_PER_FRAME:
			made_steps += 1
	t.check("a roomy step makes TILES_PER_FRAME holders and adds no body while shapes are made",
		made_steps == ParkTerrain.TILE_COUNT / ParkTerrain.TILES_PER_FRAME and ground._next_tile == 0 and ground._shape_group != -1,
		"%d of %d steps made a full batch, %d tiles" % [made_steps, steps, ground._next_tile])
	var waits := 0
	var built_usec := 0
	while ground._next_tile == 0 and waits < 100000:
		var s0 := Time.get_ticks_usec()
		ground._attach_step(1 << 62)
		built_usec = Time.get_ticks_usec() - s0
		waits += 1
		if ground._next_tile == 0:
			OS.delay_usec(500)
	t.check("once the pool has built the shapes, a step adds TILES_PER_FRAME bodies and frees the build space",
		ground._next_tile == ParkTerrain.TILES_PER_FRAME and ground._shape_group == -1 and not ground._shape_space.is_valid(),
		"%d tiles" % ground._next_tile)
	var tile_steps := 1
	while ground.phase != ParkTerrain.Phase.READY and tile_steps < 2 * ParkTerrain.TILE_COUNT:
		ground._attach_step(1 << 62)
		tile_steps += 1
	# One more step than the tile frames: the ground reports built on a frame that adds no tile.
	t.check("frame by frame, the step drains every tile and reports the ground built a frame later",
		ground.phase == ParkTerrain.Phase.READY and ground.tiles.size() == ParkTerrain.TILE_COUNT and tile_steps == ceili(float(ParkTerrain.TILE_COUNT) / ParkTerrain.TILES_PER_FRAME) + 1,
		"%d steps, %d tiles" % [tile_steps, ground.tiles.size()])
	var first: CollisionShape3D = ground.tiles[0].get_child(0)
	t.check("a prebuilt tile carries its faces as built", (first.shape as ConcavePolygonShape3D).get_faces() == _full_tile(0) and ground._holders.all(func(h): return h == null))

	# The prebuilt tile collides as a cold one: rays down on the wave and across cell diagonals hit the same point and normal.
	var cold_twin := _ground()
	cold_twin._add_tile(0)
	var space := root.get_world_3d().direct_space_state
	var ray_misses := 0
	for k in 40:
		var at := Vector3(1.3 + k * 3.7, 20.0, 0.7 + k * 3.9)
		var hits := []
		for body: StaticBody3D in [ground.tiles[0], cold_twin.tiles[0]]:
			var other: StaticBody3D = cold_twin.tiles[0] if body == ground.tiles[0] else ground.tiles[0]
			var q := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 40.0)
			q.exclude = [other.get_rid()]
			hits.append(space.intersect_ray(q))
		if hits[0].is_empty() or hits[1].is_empty() or hits[0]["position"] != hits[1]["position"] or hits[0]["normal"] != hits[1]["normal"]:
			ray_misses += 1
	t.eq("a prebuilt tile's rays hit exactly where a cold tile's do (40 rays)", ray_misses, 0)
	cold_twin.queue_free()
	ground.queue_free()

	# The cold add of the same full tile, as finish() and every bot run do it: Jolt builds the shape at add_child.
	var again := _ground()
	var t0 := Time.get_ticks_usec()
	again._add_tile(0)
	var cold_usec := Time.get_ticks_usec() - t0
	t.check("the first body step (two full tiles prebuilt) costs under a quarter of one cold full tile (the Jolt build left the frame)",
		built_usec * 4 < cold_usec, "body step %d us, one cold full tile %d us" % [built_usec, cold_usec])
	again.queue_free()

	# A swap that reads the stage mid-make (finish) adds every tile at once: made holders as they are, the rest cold.
	var mid := _ground()
	for i in 3:
		mid._attach_step(1 << 62)
	mid.finish()
	t.check("finish mid-make adds every tile and leaves no build behind",
		mid.phase == ParkTerrain.Phase.READY and mid.tiles.size() == ParkTerrain.TILE_COUNT and mid._shape_group == -1 and not mid._shape_space.is_valid())
	mid.queue_free()

	# A stage freed while the pool builds its shapes waits for the build and frees the space (no RID leak at exit).
	var freed := _ground()
	while freed._shape_group == -1:
		freed._attach_step(1 << 62)
	freed.free()

	var landing := _ground()
	landing._attach_step(-1)
	t.check("the landing's finish adds every tile at once, whatever the cost",
		landing.phase == ParkTerrain.Phase.READY and landing.tiles.size() == ParkTerrain.TILE_COUNT)
	landing.queue_free()

	# Rule (flume Warden prebuild on the 4080, #512 probe rows): the region maps rebuild colour
	# first, each after MAP_GAP_FRAMES of the play attach; the landing's finish waits for none.
	var maps := _ground()
	maps._next_map = 0
	maps.terrain3d = FakeTerrain.new()
	maps.add_child(maps.terrain3d)
	var steps_at: Array[int] = []
	for step in 4 * (ParkTerrain.MAP_GAP_FRAMES + 1):
		var before: int = maps.terrain3d.data.calls.size()
		maps._attach_step(1 << 62)
		if maps.terrain3d.data.calls.size() > before:
			steps_at.append(step)
	t.check("the play attach rebuilds colour, height, control, one a step", maps.terrain3d.data.calls == [2, 0, 1], str(maps.terrain3d.data.calls))
	var gap := ParkTerrain.MAP_GAP_FRAMES
	t.check("each map waits MAP_GAP_FRAMES steps first", steps_at == [gap, 2 * gap + 1, 3 * gap + 2], str(steps_at))
	maps.queue_free()
	var finish := _ground()
	finish._next_map = 0
	finish.terrain3d = FakeTerrain.new()
	finish.add_child(finish.terrain3d)
	var calls := 0
	while finish.phase == ParkTerrain.Phase.ATTACHING and calls < 8:
		finish._attach_step(-1)
		calls += 1
	t.check("the landing's finish rebuilds every map without a wait", finish.terrain3d.data.calls == [2, 0, 1] and finish.phase == ParkTerrain.Phase.READY and calls == ParkTerrain.MAP_TYPES.size(), "%d calls" % calls)
	finish.queue_free()
	await process_frame
	quit(t.verdict())


class FakeMaps:
	extends RefCounted
	var calls: Array = []
	func update_maps(type: int, _all_regions: bool, _generate_mips: bool) -> void:
		calls.append(type)


class FakeTerrain:
	extends Node3D
	var data := FakeMaps.new()


func _ground() -> Node3D:
	var ground: Node3D = ParkTerrain.new()
	root.add_child(ground)
	ground._tiles_root = Node3D.new()
	ground.add_child(ground._tiles_root)
	ground._next_region = ground._regions.size()
	ground._next_map = ParkTerrain.MAP_TYPES.size()
	ground.phase = ParkTerrain.Phase.ATTACHING
	ground._faces.resize(ParkTerrain.TILE_COUNT)
	for i in ParkTerrain.TILE_COUNT:
		ground._faces[i] = _full_tile(i) if i < 2 else PackedVector3Array([Vector3(i, 0, 0), Vector3(i + 1, 0, 0), Vector3(i, 0, 1)])
	return ground


# A tile's worth of the grid's triangles (80 by 80 cells, two each), on a gentle wave.
func _full_tile(index: int) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var cells := ParkTerrain.TILE_CELLS
	var step := ParkTerrain.STEP
	var x0 := index * cells * step
	for j in cells:
		for i in cells:
			var a := Vector3(x0 + i * step, sin(i * 0.3), j * step)
			var b := Vector3(x0 + (i + 1) * step, sin((i + 1) * 0.3), j * step)
			var c := Vector3(x0 + i * step, sin(i * 0.3), (j + 1) * step)
			var d := Vector3(x0 + (i + 1) * step, sin((i + 1) * 0.3), (j + 1) * step)
			faces.append_array(PackedVector3Array([a, b, c, b, d, c]))
	return faces
