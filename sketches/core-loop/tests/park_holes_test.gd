extends SceneTree

# Rule (K-UNITS KB4, PARK.md section 3 "Holes"): a cell marked in holes.bin has no triangles in
# its collider tile, so a downward ray through it finds no terrain; Terrain.height() there reads
# the under.bin floor and layer_at() says "under"; Terrain3D marks the cell's four 1 m vertices
# as holes. A cell beside the holes still collides and reads its own layer. Fixture park_test.
# 2026-10-11 (w13 KB9 round 3): the rays exclude the bodies under terrain.park_rows(1), so they judge the terrain
# collider alone; park_place_test owns the placed rows' hole-cell check.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_test"}]}
const BAKED := "res://assets/park/park_test"

var t := T.new("park_holes_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holes := FileAccess.get_file_as_bytes(BAKED + "/holes.bin")
	var under := FileAccess.get_file_as_bytes(BAKED + "/under.bin").to_float32_array()
	var cells: Array[Vector2i] = []
	for k in holes.size():
		if holes[k] == 1:
			cells.append(Vector2i(k % 800, k / 800))
	if not t.check("the fixture has hole cells", cells.size() > 700 and cells.size() == under.size(), "%d cells, %d floors" % [cells.size(), under.size()]):
		quit(t.verdict())
		return

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
	await physics_frame
	await physics_frame
	var space := holder.get_world_3d().direct_space_state
	# The placed park rows (KB9) stand on the terrain; this test judges the terrain collider alone.
	var rows_rids: Array[RID] = []
	var rows_node: Node = terrain.park_rows(1)
	if rows_node != null:
		for body in rows_node.find_children("*", "CollisionObject3D", true, false):
			rows_rids.append((body as CollisionObject3D).get_rid())

	var hits := 0
	var floor_misses := 0
	var layer_misses := 0
	var render_misses := 0
	var first_bad := ""
	for n in cells.size():
		var c: Vector2i = cells[n]
		var x := -800.0 + 2.0 * c.x + 1.0
		var z := -800.0 + 2.0 * c.y + 1.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 500.0, z), Vector3(x, -500.0, z), 0xFFFFFFFF, rows_rids))
		if not hit.is_empty():
			hits += 1
			if first_bad.is_empty():
				first_bad = "terrain hit at %s in hole cell %s" % [str(hit["position"]), str(c)]
		# Off the centre too: the whole cell reads the floor beneath.
		for off in [Vector2(-0.6, -0.6), Vector2(0.0, 0.0), Vector2(0.7, 0.4)]:
			if absf(terrain.height(x + off.x, z + off.y) - under[n]) > 0.001:
				floor_misses += 1
		if terrain.layer_at(Vector3(x, under[n], z)) != "under":
			layer_misses += 1
		for v in [Vector2(-1.0, -1.0), Vector2(0.0, -1.0), Vector2(-1.0, 0.0), Vector2(0.0, 0.0)]:
			if not ground.terrain3d.data.get_control_hole(Vector3(x + v.x, 0.0, z + v.y)):
				render_misses += 1
	if not first_bad.is_empty():
		print(first_bad)
	t.eq("no terrain collider in any hole cell", hits, 0)
	t.eq("height() in a hole cell is the under.bin floor", floor_misses, 0)
	t.eq("layer_at() in a hole cell is under", layer_misses, 0)
	t.eq("Terrain3D marks each hole cell's four 1 m vertices", render_misses, 0)

	# A ground cell well clear of the tube collides and is not under.
	var x0 := -300.0
	var z0 := 500.0
	var hit0 := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x0, 500.0, z0), Vector3(x0, -500.0, z0), 0xFFFFFFFF, rows_rids))
	t.check("a ground cell still collides", not hit0.is_empty() and absf(float(hit0["position"].y) - terrain.height(x0, z0)) < 0.01, str(hit0.get("position")))
	t.check("a ground cell is not under", terrain.layer_at(Vector3(x0, terrain.height(x0, z0), z0)) != "under", terrain.layer_at(Vector3(x0, 0.0, z0)))
	t.check("Terrain3D has no hole on a ground cell", not ground.terrain3d.data.get_control_hole(Vector3(x0, 0.0, z0)))
	holder.queue_free()
	await process_frame
	quit(t.verdict())
