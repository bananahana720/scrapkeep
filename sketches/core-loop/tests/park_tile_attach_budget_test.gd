extends SceneTree

# Rule (dam f5773-5800 on the 4080, #499 rows): while a stage's terrain attaches during play, a
# frame starts a second collider tile only when the last tile's cost still fits the attach budget.
# A tile's add is Jolt building its mesh shape (about 7 ms on the 4080); two a frame held the dam at
# 18 ms of _process for 50 frames. The rule is checked on ParkTerrain.tile_fits with set numbers
# (no wall clock). Fixture: a ParkTerrain at its tile step whose first two tiles
# carry a real tile's 12,800 triangles and the rest one each; the landing's finish (deadline -1)
# still adds every tile.

const T := preload("res://tests/support/t.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")

var t := T.new("park_tile_attach_budget_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ground: Node3D = ParkTerrain.new()
	root.add_child(ground)
	ground._tiles_root = Node3D.new()
	ground.add_child(ground._tiles_root)
	ground._next_region = ground._regions.size()
	ground._next_map = ParkTerrain.MAP_TYPES.size()
	ground._faces.resize(ParkTerrain.TILE_COUNT)
	for i in ParkTerrain.TILE_COUNT:
		ground._faces[i] = _full_tile(i) if i < 2 else PackedVector3Array([Vector3(i, 0, 0), Vector3(i + 1, 0, 0), Vector3(i, 0, 1)])

	var budget := ParkTerrain.ATTACH_BUDGET_USEC
	t.check("the first tile of a frame goes in while the deadline stands, however costly the last",
		ParkTerrain.tile_fits(0, 1000, 1000 + budget, 2 * budget) and not ParkTerrain.tile_fits(0, 1001 + budget, 1000 + budget, 0))
	t.check("a later tile goes in only when the last one's cost still fits",
		ParkTerrain.tile_fits(1, 2000, 1000 + budget, 1000) and not ParkTerrain.tile_fits(1, 2000, 1000 + budget, budget))
	t.check("never more than TILES_PER_FRAME a frame", not ParkTerrain.tile_fits(ParkTerrain.TILES_PER_FRAME, 0, budget, 0))

	ground._attach_step(1 << 62)
	t.check("a roomy frame adds TILES_PER_FRAME and measures the tile it added",
		ground._next_tile == ParkTerrain.TILES_PER_FRAME and ground._tile_usec > 0, "%d tiles, last %d us" % [ground._next_tile, ground._tile_usec])
	ground._attach_step(-1)
	t.check("the landing's finish adds every tile at once, whatever the cost", ground._next_tile == ParkTerrain.TILE_COUNT and ground.tiles.size() == ParkTerrain.TILE_COUNT)

	ground.queue_free()
	await process_frame
	quit(t.verdict())


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
