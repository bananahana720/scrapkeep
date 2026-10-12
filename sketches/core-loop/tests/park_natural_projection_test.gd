extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Schema := preload("res://src/world/park/park_schema.gd")
const T := preload("res://tests/support/t.gd")
var t := T.new("park_natural_projection_test")
var game
var phases := {}

func _initialize() -> void:
	_run.call_deferred()

func _triangles(node: Node3D, bins: Dictionary) -> void:
	if node is MeshInstance3D and node.visible:
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for k in vertices.size():
				indices.append(k)
		for k in range(0, indices.size(), 3):
			var tri := [node.global_transform * vertices[indices[k]], node.global_transform * vertices[indices[k + 1]], node.global_transform * vertices[indices[k + 2]]]
			var low := Vector2.INF
			var high := -Vector2.INF
			for p: Vector3 in tri:
				low = low.min(Vector2(p.x, p.z))
				high = high.max(Vector2(p.x, p.z))
			for j in range(floori(low.y / 2.0), floori(high.y / 2.0) + 1):
				for i in range(floori(low.x / 2.0), floori(high.x / 2.0) + 1):
					var cell := Vector2i(i, j)
					if not bins.has(cell):
						bins[cell] = []
					bins[cell].append(tri)
	for child in node.get_children():
		if child is Node3D:
			_triangles(child, bins)

func _heights(bins: Dictionary, point: Vector2) -> Array:
	var heights := []
	for tri in bins.get(Vector2i(floori(point.x / 2.0), floori(point.y / 2.0)), []):
		var a: Vector3 = tri[0]
		var b := Vector2(tri[1].x - a.x, tri[1].z - a.z)
		var c := Vector2(tri[2].x - a.x, tri[2].z - a.z)
		var offset := point - Vector2(a.x, a.z)
		var determinant := b.cross(c)
		if absf(determinant) < 0.0000001:
			continue
		var u := offset.cross(c) / determinant
		var v := b.cross(offset) / determinant
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			heights.append(a.y + u * (tri[1].y - a.y) + v * (tri[2].y - a.y))
	return heights

func _check_surface(label: String, node: Node3D, site: Dictionary, water := false) -> void:
	var bins := {}
	_triangles(node, bins)
	var half := Vector2(float(site.size[2]), float(site.size[0])) * 0.5
	var centre := Vector2(float(site.at[0]), float(site.at[1]))
	var yaw := deg_to_rad(float(site.yaw_deg))
	var probes: Array[Vector2] = []
	for z in range(ceili(-half.y), floori(half.y) + 1):
		for x in range(ceili(-half.x), floori(half.x) + 1):
			probes.append(Vector2(x, z).rotated(-yaw) + centre)
	# Walk the long outline itself; a rotated strip can fall between integer probes.
	for z in range(ceili(-half.y), floori(half.y) + 1):
		for x in [-half.x + 0.1, half.x - 0.1]:
			probes.append(Vector2(x, z).rotated(-yaw) + centre)
	if site.id == "west_wash":
		probes.append(Vector2(-77.996602, -69.957024))
	var count := 0
	var worst := INF
	var deepest := -INF
	for point in probes:
		for y in _heights(bins, point):
			var depth: float = y - game.ctx.terrain.height(point.x, point.y)
			worst = minf(worst, depth)
			deepest = maxf(deepest, depth)
			count += 1
	t.check(label + " dense 1 m rendered triangle probes exist", count > 0, str(count))
	t.check(label + " vertical clearance", deepest <= Schema.MAX_EVENT_WATER_M + 0.0001 if water else worst >= 0.1499, "min=%s max=%s points=%s" % [worst, deepest, count])
	if site.id == "west_wash" and not water:
		var point := Vector2(-77.996602, -69.957024)
		var ys := _heights(bins, point)
		t.check(label + " reported long-edge point stays above terrain", not ys.is_empty() and ys.all(func(y): return y >= game.ctx.terrain.height(point.x, point.y) + 0.1499), str(ys))

func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	await physics_frame
	await physics_frame
	game.player.set_frozen(true)
	var handler = game.world.event_families.natural
	Engine.time_scale = 10.0
	for frame in 4200:
		await physics_frame
		var state: Dictionary = handler.active.get("west_wash_flash_flood", {})
		if not state.is_empty():
			var phase: String = "telegraph" if state.phase == "telegraph" else "land"
			if not phases.has(phase):
				phases[phase] = true
				_check_surface("real Game west_wash " + phase, state.mark, state.site)
		if phases.size() == 2:
			break
	Engine.time_scale = 1.0
	t.check("real Game west_wash telegraph and landing both measured", phases.size() == 2, str(phases))
	# Supplement the reachable loop with every loaded natural row's actual prepared surfaces.
	for row in game.ctx.terrain.map().park.event_rows:
		if row.family != "natural":
			continue
		var prepared: Dictionary = handler._prepared[row.id]
		for landed in [false, true]:
			var mark: Node3D = handler._mark(row, prepared.geometry, landed)
			_check_surface(row.id + (" land" if landed else " telegraph"), mark, prepared.site)
			mark.free()
		if prepared.has("water_surface"):
			var view := MeshInstance3D.new()
			view.mesh = prepared.water_surface.mesh
			handler.add_child(view)
			view.position.y = minf(float(row.effect.depth_m), Schema.MAX_EVENT_WATER_M)
			_check_surface(row.id + " water", view, prepared.site, true)
			view.free()
		if prepared.overlay != null:
			var home: Vector3 = prepared.overlay.position
			prepared.overlay.position = handler._overlay_map.swaps[prepared.swap].home
			prepared.overlay.visible = true
			_check_surface(row.id + " overlay", prepared.overlay, prepared.site, true)
			prepared.overlay.position = home
			prepared.overlay.visible = false
	var source := FileAccess.get_file_as_string("res://src/world/events/natural.gd")
	var builders := source.count(".add_surface_from_arrays(") + source.count("LocalMesh.grid(")
	t.eq("one surface builder owns every natural surface", builders, 1)
	t.check("terrain projection helper owns the builder", source.contains("func _project_surface("))
	game.free()
	quit(t.verdict())
