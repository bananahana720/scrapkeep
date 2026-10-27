extends SceneTree

# Rule (dam f5773-5800 on the 4080, #499 rows): while a stage's terrain attaches during play, a
# frame starts a second collider tile only when the last tile's cost still fits the attach budget.
# A tile's add is Jolt building its mesh shape (about 7 ms on the 4080); two a frame held the dam at
# 18 ms of _process for 50 frames. Fixture: a ParkTerrain at its tile step whose first two tiles
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

	ground._attach_step(Time.get_ticks_usec() + ParkTerrain.ATTACH_BUDGET_USEC)
	var first_us: int = ground._tile_usec
	t.check("a frame whose full tile leaves too little of the budget adds just that one", ground._next_tile == 1, "%d tiles, the tile %d us" % [ground._next_tile, first_us])
	ground._attach_step(Time.get_ticks_usec() + ParkTerrain.ATTACH_BUDGET_USEC)
	t.check("the next frame adds the next, never none", ground._next_tile == 2, "%d tiles" % ground._next_tile)
	ground._attach_step(Time.get_ticks_usec() + ParkTerrain.ATTACH_BUDGET_USEC)
	t.check("cheap tiles still go up to five a frame", ground._next_tile == 2 + ParkTerrain.TILES_PER_FRAME, "%d tiles" % ground._next_tile)

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
