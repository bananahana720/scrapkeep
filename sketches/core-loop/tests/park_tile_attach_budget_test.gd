extends SceneTree

# Rule (dam f5773-5800 and flume f14928-14982 on the 4080, ruling ae): while a stage's terrain
# attaches during play, collider pieces go in inside COLLIDER_BUDGET_USEC a frame, and a frame starts
# another piece only when the last one's cost still fits. A piece's add is Jolt building its mesh
# shape; 80 by 80 cell tiles (about 7 ms on the 4080) held the dam at 18 ms of _process. The rule is
# checked on ParkTerrain.tile_fits with set numbers (no wall clock). Fixture: a ParkTerrain at its
# collider step whose first two pieces carry a real piece's 3,200 triangles and the rest one each;
# the landing's finish (deadline -1) still adds every piece.

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

	t.check("the collider pieces' frame budget is under the attach budget", ParkTerrain.COLLIDER_BUDGET_USEC < budget)
	ground._attach_step(1 << 62)
	t.check("a frame adds at least one piece and measures it",
		ground._next_tile >= 1 and ground._next_tile <= ParkTerrain.TILES_PER_FRAME and ground._tile_usec > 0, "%d pieces, last %d us" % [ground._next_tile, ground._tile_usec])
	var steps := 1
	var most: int = ground._next_tile
	while ground.phase != ParkTerrain.Phase.READY and steps < 2 * ParkTerrain.COLLIDER_COUNT:
		var before: int = ground._next_tile
		ground._attach_step(1 << 62)
		most = maxi(most, ground._next_tile - before)
		steps += 1
	t.check("frame by frame, the step drains every piece, never more than TILES_PER_FRAME a frame, and reports the ground built",
		ground.phase == ParkTerrain.Phase.READY and ground.tiles.size() == ParkTerrain.COLLIDER_COUNT and most <= ParkTerrain.TILES_PER_FRAME
		and steps >= ceili(float(ParkTerrain.COLLIDER_COUNT) / ParkTerrain.TILES_PER_FRAME), "%d steps, %d pieces" % [steps, ground.tiles.size()])
	ground.queue_free()

	var landing := _ground()
	landing._attach_step(-1)
	t.check("the landing's finish adds every tile at once, whatever the cost",
		landing.phase == ParkTerrain.Phase.READY and landing.tiles.size() == ParkTerrain.COLLIDER_COUNT)
	landing.queue_free()
	await process_frame
	quit(t.verdict())


func _ground() -> Node3D:
	var ground: Node3D = ParkTerrain.new()
	root.add_child(ground)
	ground._tiles_root = Node3D.new()
	ground.add_child(ground._tiles_root)
	ground._next_region = ground._regions.size()
	ground._next_map = ParkTerrain.MAP_TYPES.size()
	ground.phase = ParkTerrain.Phase.ATTACHING
	ground._faces.resize(ParkTerrain.COLLIDER_COUNT)
	for i in ParkTerrain.COLLIDER_COUNT:
		ground._faces[i] = _full_tile(i) if i < 2 else PackedVector3Array([Vector3(i, 0, 0), Vector3(i + 1, 0, 0), Vector3(i, 0, 1)])
	return ground


# A piece's worth of the grid's triangles (40 by 40 cells, two each), on a gentle wave.
func _full_tile(index: int) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var cells := ParkTerrain.COLLIDER_CELLS
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
