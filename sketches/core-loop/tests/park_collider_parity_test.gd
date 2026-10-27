extends SceneTree

# Rule (K-UNITS KB4, PARK.md section 3): a park_* map id with a bake loads as Terrain3D render
# regions (four regions of 1024 vertices at 1 m spacing, collision mode 0) and our own trimesh
# collider in 160 m tiles (100 for the 1.6 km park), and the collider and Terrain.height() are
# one surface: at 10,000 seeded points off the hole cells a downward ray on the collider and
# height() agree within 1 cm. The fixture is park_test (src/world/park/park_test.json, baked to
# assets/park/park_test/).
# 2026-10-11 (w13 KB9 round 3): the rays exclude the bodies under terrain.park_rows(1), so they judge the terrain
# collider alone.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_test"}]}
const BAKED := "res://assets/park/park_test"
const POINTS := 10000
const SEED := 20261010
const TOLERANCE := 0.01

var t := T.new("park_collider_parity_test")


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
	terrain.build(holder)
	terrain.use(1)
	var ground = terrain.park_ground(1) if terrain.has_method("park_ground") else null
	if not t.check("park_test loads a park ground", ground != null, "terrain.park_ground(1)"):
		quit(t.verdict())
		return

	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BAKED + "/bake.json"))
	var grid: Dictionary = info["grid"]
	var half := float(grid["half_m"])
	var want_regions: int = (grid["regions"] as Array).size()
	var want_tiles := int(pow(ceilf(2.0 * half / 160.0), 2.0))
	print("park_collider_parity_test: bake implies %d regions of %d and %d tiles of 160 m; got %d regions and %d tiles"
		% [want_regions, int(grid["region_size"]), want_tiles, ground.terrain3d.data.get_region_count(), ground.tiles.size()])
	t.eq("regions from the bake", ground.terrain3d.data.get_region_count(), want_regions)
	t.eq("four regions", want_regions, 4)
	t.eq("region size 1024", int(ground.terrain3d.region_size), 1024)
	t.near("vertex spacing 1 m", float(ground.terrain3d.vertex_spacing), 1.0, 0.0001)
	t.eq("Terrain3D collision stays off (mode 0)", int(ground.terrain3d.collision.mode), 0)
	t.eq("100 collider tiles", ground.tiles.size(), want_tiles)
	t.eq("the bake implies 100 tiles", want_tiles, 100)
	var sized := 0
	for tile in ground.tiles:
		var collider: CollisionShape3D = tile.get_child(0)
		var box: AABB = collider.transform * collider.shape.get_debug_mesh().get_aabb()
		if absf(box.size.x - 160.0) < 0.01 and absf(box.size.z - 160.0) < 0.01:
			sized += 1
	t.eq("every tile spans 160 m by 160 m", sized, want_tiles)
	t.check("contains the park corners", terrain.contains(Vector3(-790.0, 0.0, 790.0)) and terrain.contains(Vector3(790.0, 0.0, -790.0))
		and not terrain.contains(Vector3(805.0, 0.0, 0.0)), "half 800")

	# height() at grid vertices is the bake's ground.bin, read here with this test's own indexing.
	var raw := FileAccess.open_compressed(BAKED + "/ground.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var h := raw.get_buffer(801 * 801 * 4).to_float32_array()
	raw.close()
	var holes := FileAccess.get_file_as_bytes(BAKED + "/holes.bin")
	var vertex_misses := 0
	var render_misses := 0
	for k in 50:
		var i := (k * 97) % 801
		var j := (k * 53 + 11) % 801
		var x := -800.0 + 2.0 * i
		var z := -800.0 + 2.0 * j
		if _in_hole(holes, x, z):
			continue
		if absf(terrain.height(clampf(x, -799.99, 799.99), clampf(z, -799.99, 799.99)) - h[j * 801 + i]) > 0.001:
			vertex_misses += 1
		if absf(float(ground.terrain3d.data.get_height(Vector3(x, 0.0, z))) - h[j * 801 + i]) > 0.001:
			render_misses += 1
	t.eq("height() at grid vertices reads ground.bin", vertex_misses, 0)
	t.eq("Terrain3D regions draw ground.bin at grid vertices", render_misses, 0)

	await physics_frame
	await physics_frame
	var space := holder.get_world_3d().direct_space_state
	# The placed park rows (KB9) stand on the terrain; this test judges the terrain collider alone.
	var rows_rids: Array[RID] = []
	var rows_node: Node = terrain.park_rows(1)
	if rows_node != null:
		for body in rows_node.find_children("*", "CollisionObject3D", true, false):
			rows_rids.append((body as CollisionObject3D).get_rid())
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var sampled := 0
	var skipped := 0
	var misses := 0
	var worst := 0.0
	var first_bad := ""
	for n in POINTS:
		var x := rng.randf_range(-799.5, 799.5)
		var z := rng.randf_range(-799.5, 799.5)
		if _in_hole(holes, x, z):
			skipped += 1
			continue
		sampled += 1
		var want: float = terrain.height(x, z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, want + 20.0, z), Vector3(x, want - 20.0, z), 0xFFFFFFFF, rows_rids))
		var err := INF if hit.is_empty() else absf(float(hit["position"].y) - want)
		worst = maxf(worst, err)
		if err > TOLERANCE:
			misses += 1
			if first_bad.is_empty():
				first_bad = "(%.2f, %.2f) height %.4f hit %s" % [x, z, want, str(hit.get("position"))]
	print("park_collider_parity_test: %d points on ground, %d in hole cells skipped, worst %.5f m" % [sampled, skipped, worst])
	t.check("the seeded points are on the ground", sampled > 9800, "%d" % sampled)
	t.eq("collider and height() agree within 1 cm at every point", misses, 0)
	if not first_bad.is_empty():
		print("first miss: " + first_bad)
	holder.queue_free()
	await process_frame
	quit(t.verdict())


static func _in_hole(holes: PackedByteArray, x: float, z: float) -> bool:
	var i := clampi(int(floorf((x + 800.0) / 2.0)), 0, 799)
	var j := clampi(int(floorf((z + 800.0) / 2.0)), 0, 799)
	return holes[j * 800 + i] == 1
