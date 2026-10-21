extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Schema := preload("res://src/world/park/park_schema.gd")
const T := preload("res://tests/support/t.gd")
const EventGround := preload("res://src/world/events/event_ground.gd")
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
		var bx: float = float(tri[1].x) - float(a.x)
		var bz: float = float(tri[1].z) - float(a.z)
		var cx: float = float(tri[2].x) - float(a.x)
		var cz: float = float(tri[2].z) - float(a.z)
		var dx: float = float(point.x) - float(a.x)
		var dz: float = float(point.y) - float(a.z)
		var determinant := bx * cz - bz * cx
		if absf(determinant) < 0.0000001:
			continue
		var u := (dx * cz - dz * cx) / determinant
		var v := (bx * dz - bz * dx) / determinant
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			heights.append(float(a.y) + u * (float(tri[1].y) - float(a.y)) + v * (float(tri[2].y) - float(a.y)))
	return heights

func _triangle_probes(node: Node3D, probes: Array[Vector2], rendered: Array) -> void:
	if node is MeshInstance3D and node.visible:
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for k in vertices.size():
				indices.append(k)
		for k in range(0, indices.size(), 3):
			var centre := [0.0, 0.0, 0.0]
			for index in [indices[k], indices[k + 1], indices[k + 2]]:
				var point: Vector3 = node.global_transform * vertices[index]
				centre[0] += float(point.x) / 3.0
				centre[1] += float(point.y) / 3.0
				centre[2] += float(point.z) / 3.0
				probes.append(Vector2(point.x, point.z))
				rendered.append([float(point.x), float(point.y), float(point.z)])
			probes.append(Vector2(centre[0], centre[2]))
			rendered.append(centre)
	for child in node.get_children():
		if child is Node3D:
			_triangle_probes(child, probes, rendered)

func _surface_stats(node: Node3D, site: Dictionary) -> Dictionary:
	var bins := {}
	_triangles(node, bins)
	var half := Vector2(float(site.size[2]), float(site.size[0])) * 0.5
	var centre := Vector2(float(site.at[0]), float(site.at[1]))
	var yaw := deg_to_rad(float(site.yaw_deg))
	var probes: Array[Vector2] = []
	var rendered: Array = []
	_triangle_probes(node, probes, rendered)
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
	for point in rendered:
		var depth: float = float(point[1]) - _ground(float(point[0]), float(point[2]))
		worst = minf(worst, depth)
		deepest = maxf(deepest, depth)
	for point in probes:
		for y in _heights(bins, point):
			var depth: float = y - _ground(point.x, point.y)
			worst = minf(worst, depth)
			deepest = maxf(deepest, depth)
			count += 1
	return {"count": count, "min": worst, "max": deepest, "bins": bins}

func _ground(x: float, z: float) -> float:
	var terrain = game.ctx.terrain
	return terrain._floor(terrain.stage - 1, x, z)

func _valid_surface(kind: String, stats: Dictionary) -> bool:
	match kind:
		"water":
			return stats.max <= Schema.MAX_EVENT_WATER_M + 0.0001
		"overlay":
			return stats.min >= -0.0001
	return stats.min >= 0.1499

func _check_surface(label: String, node: Node3D, site: Dictionary, kind := "marker") -> void:
	var stats := _surface_stats(node, site)
	t.check(label + " dense 1 m rendered triangle probes exist", stats.count > 0, str(stats.count))
	t.check(label + " vertical clearance", _valid_surface(kind, stats), "min=%s max=%s points=%s" % [stats.min, stats.max, stats.count])
	if site.id == "west_wash" and kind == "marker":
		var point := Vector2(-77.996602, -69.957024)
		var ys := _heights(stats.bins, point)
		t.check(label + " reported long-edge point stays above terrain", not ys.is_empty() and ys.all(func(y): return y >= _ground(point.x, point.y) + 0.1499), str(ys))

# A row naming an event in hide_on is found once, by prepare_overlay, and hides with the swap and comes back on revert,
# driven through set_overlay (the first-owner recapture and the last-owner revert), not a bare apply_swap.
func _hide_on_controls(handler) -> void:
	var live = game.world.terrain.map()
	var park_row: Dictionary = {}
	for candidate in live.park.park_rows:
		if String(candidate.get("recipe", "")) != "" and not String(candidate.recipe).begins_with("greybox:") \
				and game.world.terrain.geometry_root(game.world.terrain.stage).find_child("Park_" + String(candidate.id), true, false) != null:
			park_row = candidate
			break
	if not t.check("a placed GLB row exists to hide", not park_row.is_empty()):
		return
	park_row["hide_on"] = "hide_probe_event"
	var base: Dictionary = handler._prepared.projection_slump
	var row: Dictionary = {}
	for event in handler._original_map.park.event_rows:
		if event.id == "projection_slump":
			row = event.duplicate(true)
	row["id"] = "hide_probe_event"
	row["effect"]["swap"] = "hide_probe_ramp"
	var record: Dictionary = {"site": base.site, "at": base.at, "geometry": base.geometry.duplicate(), "overlay": null}
	var overlay_map = EventGround.prepare_overlay(game.world, handler, row, record, Callable(handler, "_collapse_target"))
	park_row.erase("hide_on")
	var hidden: Array = overlay_map.swaps.hide_probe_ramp.get("hidden", [])
	t.check("hide_on resolves the named row's node once, on the swap entry", hidden.size() == 1 and hidden[0].node.name == "Park_" + String(park_row.id), str(hidden))
	if hidden.size() != 1:
		return
	var node: Node3D = hidden[0].node
	var home: Vector3 = node.position
	var shown := node.visible
	var bodies := node.find_children("*", "StaticBody3D", true, false)
	EventGround.set_overlay(game.world, row, record, true)
	t.check("the swap hides the hide_on row and parks it down", not node.visible and node.position.y < home.y - 300.0, "%s -> %s" % [home, node.position])
	t.check("its collider body rides the parked node", not bodies.is_empty() and (bodies[0] as Node3D).global_position.y < home.y - 300.0, str(bodies))
	EventGround.set_overlay(game.world, row, record, false)
	t.check("revert restores the hide_on row", node.visible == shown and node.position.is_equal_approx(home), "%s visible %s" % [node.position, node.visible])
	overlay_map.swaps.erase("hide_probe_ramp")
	overlay_map.profiles.erase("hide_probe_ramp_after")
	record.overlay.free()


func _overlay_controls(handler) -> void:
	var record: Dictionary = handler._prepared.projection_slump
	var entry: Dictionary = handler._overlay_map.swaps[record.swap]
	var body: Node3D = record.overlay
	body.position = entry.home
	body.visible = true
	body.position.y -= 1.0
	var buried := _surface_stats(body, record.site)
	t.check("buried terrain-overlay control is rejected", buried.count > 0 and not _valid_surface("overlay", buried), str([buried.min, buried.max]))
	body.position.y += 1.0 + Schema.MAX_EVENT_WATER_M + 1.0
	var tall := _surface_stats(body, record.site)
	t.check("valid terrain overlay above water cap is accepted", tall.count > 0 and tall.min > Schema.MAX_EVENT_WATER_M and _valid_surface("overlay", tall), str([tall.min, tall.max]))
	body.position = entry.home
	handler._install_surface(record.swap, entry.target)
	_check_surface("real park_dam test-only slump completed overlay", body, record.site, "overlay")
	body.position += Vector3.DOWN * 5000.0
	body.visible = false


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	var park: Dictionary = game.ctx.terrain.maps[0].park
	var fixture_row: Dictionary = park.event_rows[0].duplicate(true)
	fixture_row.merge({"id": "projection_slump", "kind": "collapse", "trigger": {"on": "clock_tier", "value": 4},
		"telegraph": {"lead_s": 6.0, "form": "ground_slump", "on_bar": false},
		"effect": {"depth_m": 20.0, "fill_s": 4.0, "swap": "projection_slump_ramp",
			"face": {"at": [-70.0, -60.0], "size": [20.0, 20.0, 20.0], "yaw_deg": 0.0}}}, true)
	park.event_rows.append(fixture_row)
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
			_check_surface(row.id + " water", view, prepared.site, "water")
			view.free()
		if prepared.overlay != null:
			var home: Vector3 = prepared.overlay.position
			prepared.overlay.position = handler._overlay_map.swaps[prepared.swap].home
			prepared.overlay.visible = true
			_check_surface(row.id + " overlay", prepared.overlay, prepared.site, "overlay")
			prepared.overlay.position = home
			prepared.overlay.visible = false
	_hide_on_controls(handler)
	_overlay_controls(handler)
	var source := FileAccess.get_file_as_string("res://src/world/events/natural.gd")
	var pattern := RegEx.new()
	pattern.compile("(?:ArrayMesh|SphereMesh|BoxMesh|TorusMesh|PlaneMesh|ImmediateMesh|CylinderMesh|PrismMesh)\\.new\\(|LocalMesh\\.")
	var builders := pattern.search_all(source)
	t.eq("one surface builder owns every natural surface", builders.size(), 1)
	var start := source.find("func _project_surface(")
	var end := source.find("\n\nfunc ", start + 1)
	t.check("terrain projection helper owns every builder", start >= 0 and builders.all(func(found): return found.get_start() > start and found.get_start() < end))
	game.free()
	quit(t.verdict())
