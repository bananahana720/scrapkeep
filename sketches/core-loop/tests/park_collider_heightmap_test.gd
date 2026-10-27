extends SceneTree

# Rule (ruling ae, 27 Oct): every park tile without a hole cell collides as a HeightMapShape3D (Jolt builds it
# in about 0.5 ms against 13-14 ms for the mesh), a tile with one keeps the mesh, and on every tile of every
# park the collider and Terrain.height() are one surface: downward rays at seeded points in each tile, off the
# hole cells, agree within 1 cm. Rays judge the tiles alone (every other body excluded). The faces the rivet
# carve reads from a height-map tile (RivetKit.height_map_faces through the shape's transform) are the mesh
# tile's faces, triangle for triangle.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const RivetKit := preload("res://src/combat/rivet_kit.gd")

const PARKS := ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]
const PER_TILE := 24
const SEED := 20261027
const TOLERANCE := 0.01

var t := T.new("park_collider_heightmap_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for id in PARKS:
		await _check_park(id)
	quit(t.verdict())


func _check_park(id: String) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	var terrain = Terrain.new({"DEFS": [{"stage": 1, "world": 1, "map": id}]})
	terrain.build(holder)
	terrain.use(1)
	var ground = terrain.park_ground(1)
	await physics_frame
	await physics_frame
	var holes: PackedByteArray = ground.holes
	var maps := 0
	var right_kind := 0
	for k in ground.tiles.size():
		var shape: Shape3D = ground.tiles[k].get_child(0).shape
		var holed: bool = ground._tile_has_hole((k % ParkTerrain.TILES_PER_SIDE) * ParkTerrain.TILE_CELLS, (k / ParkTerrain.TILES_PER_SIDE) * ParkTerrain.TILE_CELLS)
		maps += int(shape is HeightMapShape3D)
		right_kind += int(shape is ConcavePolygonShape3D if holed else shape is HeightMapShape3D)
	t.eq("%s: every tile is a height map unless it has a hole cell" % id, right_kind, ParkTerrain.TILE_COUNT)
	var face_misses := 0
	for k in [0, 45, ParkTerrain.TILE_COUNT - 1]:
		var collider: CollisionShape3D = ground.tiles[k].get_child(0)
		if not collider.shape is HeightMapShape3D:
			continue
		var got: PackedVector3Array = collider.transform * RivetKit.height_map_faces(collider.shape)
		var want: PackedVector3Array = ground._tile_faces((k % ParkTerrain.TILES_PER_SIDE) * ParkTerrain.TILE_CELLS, (k / ParkTerrain.TILES_PER_SIDE) * ParkTerrain.TILE_CELLS)
		if got.size() != want.size():
			face_misses += 1
			continue
		for v in want.size():
			if not got[v].is_equal_approx(want[v]) and got[v].distance_to(want[v]) > 0.0001:
				face_misses += 1
				break
	t.eq("%s: a height-map tile's carve faces are its mesh faces" % id, face_misses, 0)
	var tile_rids := {}
	for tile in ground.tiles:
		tile_rids[(tile as CollisionObject3D).get_rid()] = true
	var others: Array[RID] = []
	for body in holder.find_children("*", "CollisionObject3D", true, false):
		if not tile_rids.has((body as CollisionObject3D).get_rid()):
			others.append((body as CollisionObject3D).get_rid())
	var space := holder.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var sampled := 0
	var misses := 0
	var tiles_missed := {}
	var worst := 0.0
	var first_bad := ""
	for k in ParkTerrain.TILE_COUNT:
		var x0 := -ParkTerrain.HALF + (k % ParkTerrain.TILES_PER_SIDE) * ParkTerrain.TILE_M
		var z0 := -ParkTerrain.HALF + (k / ParkTerrain.TILES_PER_SIDE) * ParkTerrain.TILE_M
		for n in PER_TILE:
			var x := clampf(x0 + rng.randf() * ParkTerrain.TILE_M, -799.99, 799.99)
			var z := clampf(z0 + rng.randf() * ParkTerrain.TILE_M, -799.99, 799.99)
			var i := clampi(int(floorf((x + ParkTerrain.HALF) / ParkTerrain.STEP)), 0, ParkTerrain.CELLS - 1)
			var j := clampi(int(floorf((z + ParkTerrain.HALF) / ParkTerrain.STEP)), 0, ParkTerrain.CELLS - 1)
			if not holes.is_empty() and holes[j * ParkTerrain.CELLS + i] == 1:
				continue
			sampled += 1
			var want: float = terrain.height(x, z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, want + 20.0, z), Vector3(x, want - 20.0, z), 0xFFFFFFFF, others))
			var err := INF if hit.is_empty() else absf(float(hit["position"].y) - want)
			worst = maxf(worst, err)
			if err > TOLERANCE:
				misses += 1
				tiles_missed[k] = true
				if first_bad.is_empty():
					first_bad = "tile %d (%.2f, %.2f) height %.4f hit %s" % [k, x, z, want, str(hit.get("position"))]
	print("park_collider_heightmap_test: %s %d height-map tiles, %d points, worst %.5f m %s" % [id, maps, sampled, worst, first_bad])
	t.check("%s: points land on every tile" % id, sampled > ParkTerrain.TILE_COUNT * PER_TILE * 0.95, "%d" % sampled)
	t.eq("%s: collider and height() agree within 1 cm on every tile" % id, tiles_missed.size(), 0)
	holder.queue_free()
	await process_frame
	await process_frame
