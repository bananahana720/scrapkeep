extends SceneTree
# 2026-10-09 re-pin (VX-WIRE): the shipped high carries set dressing and air motes (presentation.gd reads the
# preset switches, not "target"), so high is the dressed baseline and low the bare one.

const Game := preload("res://src/game.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Dressing := preload("res://src/presentation/set_dressing.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Reach := preload("res://src/world/map_reach.gd")
const Features := preload("res://src/world/features.gd")
const TraversalLine := preload("res://tools/traversal_line.gd")
const Intent := preload("res://src/movement/intent.gd")
var failed := false

func check(ok: bool, what: String) -> void:
	failed = failed or not ok
	print(what, " -> ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	_run.call_deferred()

func _baked_tuft_checks() -> void:
	var source := FileAccess.get_file_as_string("res://src/presentation/set_dressing.gd")
	check(not source.contains("_dry_grass") and not source.contains("Mesh.ARRAY_COLOR"), "KC-4 set dressing has no runtime tuft recolour")
	var dressing := Dressing.new()
	var meshes := dressing._kit_meshes()
	var scene := (load(Dressing.KIT_PATH) as PackedScene).instantiate()
	var tufts := 0
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if not String(view.name).begins_with("tuft_"):
			continue
		tufts += 1
		var mesh: ArrayMesh = meshes[String(view.name)]
		var same := mesh.get_surface_count() == view.mesh.get_surface_count()
		var roots := 0.0
		var tips := 0.0
		var root_count := 0
		var tip_count := 0
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var baked := view.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			same = same and colours == baked[Mesh.ARRAY_COLOR] and colours.size() == points.size()
			for i in mini(points.size(), colours.size()):
				if points[i].y < 0.01:
					roots += colours[i].get_luminance()
					root_count += 1
				elif points[i].y > mesh.get_aabb().size.y * 0.75:
					tips += colours[i].get_luminance()
					tip_count += 1
		check(same, "KC-4 %s placed vertex colours exactly equal the baked colours" % view.name)
		check(root_count > 0 and tip_count > 0 and tips / maxf(tip_count, 1) > roots / maxf(root_count, 1) + 0.01, "KC-4 %s baked straw has darker roots" % view.name)
	check(tufts == 2, "KC-4 both baked tufts checked")
	scene.free()
	dressing.free()

func _run() -> void:
	_baked_tuft_checks()
	Preset.apply("high")
	var game := Game.new()
	game.test_mode = true
	game.table = "default"
	root.add_child(game)
	await process_frame
	await process_frame
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.source = Intent.Scripted.new()
	for i in 120:
		await physics_frame
	paused = true
	var high_nodes := _node_count(game)
	check(not game.find_children("TargetSetDressing", "", true, false).is_empty(), "shipped high carries the dressing and air nodes")
	Preset.apply("low")
	var original_nodes := _node_count(game)
	check(original_nodes < high_nodes and game.find_children("TargetSetDressing", "", true, false).is_empty(), "low has fewer nodes and zero dressing/air")
	Preset.apply("target")
	var dressing = game.presentation.set_dressing
	check(dressing != null and dressing.map_id == "spillway" and dressing.seed_value == "spillway".hash(), "target dressing seeded from map id")
	check(dressing.find_children("*", "MultiMeshInstance3D", true, false).size() == 13, "target has ten clutter batches, broken rock and two air batches")
	check(dressing.find_children("*", "CollisionObject3D", true, false).is_empty() and dressing.find_children("*", "CollisionShape3D", true, false).is_empty(), "all dressing and air have no collision")
	var snapshot := _snapshot(dressing)
	var clutter := _clutter_checks(game, dressing, 1)
	check(clutter.count > 300, "spillway clutter stands: " + str(clutter.count) + " pieces")
	var large_count := 0
	var ground: Callable = game.ctx.terrain.ground_callable(1)
	for batch: MultiMeshInstance3D in dressing.batches:
		var multi := batch.multimesh
		check(batch.get_meta("instance_buffer").size() == multi.instance_count * (12 if batch.has_meta("clutter") else 16), "exact submitted instance buffer covers every placement")
		check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "dressing, clutter and air cannot change gameplay shadows: " + String(batch.name))
		if batch.has_meta("clutter"):
			continue
		check(batch.material_override.shader.get_shader_uniform_list().any(func(row): return row.name == "protected_count"), "engine parses dressing/air shader and protection include")
		if batch.name == "BrokenRock":
			for i in multi.instance_count:
				var tr := _instance(batch, i)
				var at := Vector2(tr.origin.x, tr.origin.z)
				check(not game.ctx.terrain.map().play_rect.grow(8.0).has_point(at) and _normal(ground, at).y < Tuning.MAX_SLOPE_DOT, "large rock on unclimbable ground outside playable apron")
				var low := Vector3(INF, INF, INF)
				var high := Vector3(-INF, -INF, -INF)
				for vertex in multi.mesh.get_faces():
					var point: Vector3 = tr * vertex
					low = low.min(point)
					high = high.max(point)
				var size := maxf(high.x - low.x, high.z - low.z)
				check(size >= 0.5 and size <= 2.0, "placed broken-rock extent in 0.5 to 2 m range")
				large_count += 1
		elif batch.name == "DustMotes":
			check(multi.instance_count == 160, "160 sparse motes")
			for i in multi.instance_count:
				check(-_instance(batch, i).origin.z < 30.0, "mote seeded in first 30 m ahead of camera")
		elif batch.name == "SandStreaks":
			check(multi.instance_count > 0, "open-ground sand streaks placed")
			for i in multi.instance_count:
				var tr := _instance(batch, i)
				check(tr.basis.x.normalized().dot(Vector3(Dressing.WIND.x, 0.0, Dressing.WIND.y).normalized()) > 0.999, "all streaks follow one wind direction")
	check(large_count > 0, "broken rocks exist on steep slopes")
	var spill_rows := _surfaces(game.ctx.terrain.map_for(1), false)
	var spill_near := _nearest(dressing, spill_rows)
	check(spill_near.size() == spill_rows.size() and spill_rows.size() >= 4, "every spillway place is measured independently: " + str(spill_rows.size()))
	for key in spill_near:
		check(spill_near[key] >= CLEAR, "no spillway clutter within 3 m of the " + key + ": nearest " + str(snappedf(spill_near[key], 0.1)) + " m")
	_route_checks()
	print("Placed ", clutter.count, " clutter pieces on the Spillway; ", large_count, " broken rocks")
	Preset.apply("target")
	dressing = game.presentation.set_dressing
	check(_snapshot(dressing) == snapshot, "repeated preset produces identical seeded transforms, shades and phases")
	var cam: Camera3D = game.camera.cam
	cam.global_position = game.ctx.terrain.drop_point(-80, -101, 6.0)
	cam.look_at(game.ctx.terrain.drop_point(-80, -80, 1.0))
	var enemy = game.ctx.spawner.spawn_enemy("chaser", game.ctx.terrain.drop_point(-80, -80, 1.2))
	dressing._update_protection(cam)
	var protected: Array = dressing._materials[0].get_shader_parameter("protected_rects")
	var point := cam.unproject_position(enemy.global_position) / cam.get_viewport().get_visible_rect().size
	check(protected.any(func(rect): return point.x >= rect.x and point.y >= rect.y and point.x <= rect.z and point.y <= rect.w), "enemy feet are inside dressing/air screen exclusion")
	for batch in dressing.batches:
		if batch.has_meta("clutter"):
			var live := false
			for surface in batch.multimesh.mesh.get_surface_count():
				var mat := batch.multimesh.mesh.surface_get_material(surface) as ShaderMaterial
				live = mat != null and mat.get_shader_parameter("protected_count") > 0
				check(live, "every clutter surface shares live gameplay exclusion: " + String(batch.name) + " " + str(surface))
		else:
			check(batch.material_override.get_shader_parameter("protected_count") > 0, "every shader batch shares live gameplay exclusion")
	var shot_camera := Camera3D.new()
	game.add_child(shot_camera)
	shot_camera.global_transform = cam.global_transform.translated(Vector3(10, 3, 5))
	dressing.sync_camera(shot_camera)
	check(dressing._dust.global_transform == shot_camera.global_transform, "frozen capture camera refresh places motes at the active view")
	shot_camera.free()
	var crowd := []
	for i in 65:
		var actor := Node3D.new()
		game.add_child(actor)
		actor.global_position = enemy.global_position
		actor.add_to_group("enemy")
		crowd.append(actor)
	dressing.sync_camera(cam)
	check(not dressing.visible, "protection overflow hides all dressing and air")
	for actor in crowd:
		actor.free()
	dressing.sync_camera(cam)
	check(dressing.visible, "frozen camera refresh restores dressing after protection overflow clears")
	var tiny := Dressing.protection_rect(cam, cam.global_position + -cam.global_basis.z, 2.5)
	check(tiny == Vector4(0, 0, 1, 1), "near-camera overlap protects the entire screen")
	var straddle := Dressing.protection_rect(cam, cam.global_position + cam.global_basis.x * 150.0 - cam.global_basis.z * 1.0, 2.5)
	check(straddle.z < 0.0, "a box straddling the camera plane wholly outside the frame protects nothing: " + str(straddle))
	var wide := Camera3D.new()
	wide.fov = 88.0
	game.add_child(wide)
	wide.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 500, 0))
	var edge := Dressing.protection_rect(wide, wide.global_position + Vector3(9.76, 0.0, -2.4), 2.5)
	check(edge.z >= 1.0 and edge.x < 1.0 and edge.x >= 0.0 and edge.y >= 0.0 and edge.w <= 1.0,
		"a box straddling the camera plane that enters the frame's edge is protected out to that edge: " + str(edge))
	wide.free()
	Preset.apply("high")
	# The enemy is the only deliberately added gameplay node in this test.
	enemy.free()
	check(not game.find_children("TargetSetDressing", "", true, false).is_empty() and _node_count(game) == high_nodes, "target to high restores the high node count")
	Preset.apply("target")
	Preset.apply("low")
	check(game.find_children("TargetSetDressing", "", true, false).is_empty() and _node_count(game) == original_nodes, "target to low restores the low node count")
	game.free()
	Preset.apply("high")
	await _reach_checks()
	print("set_dressing_test: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _node_count(child)
	return count

func _snapshot(dressing: Node) -> Dictionary:
	var result := {}
	for batch: MultiMeshInstance3D in dressing.batches:
		result[batch.name] = batch.get_meta("instance_buffer")
	return result

func _normal(ground: Callable, at: Vector2) -> Vector3:
	var dx: float = (ground.call(at.x + 0.25, at.y, 0.0) as Vector3).y - (ground.call(at.x - 0.25, at.y, 0.0) as Vector3).y
	var dz: float = (ground.call(at.x, at.y + 0.25, 0.0) as Vector3).y - (ground.call(at.x, at.y - 0.25, 0.0) as Vector3).y
	return Vector3(-dx, 0.5, -dz).normalized()


func _instance(batch: MultiMeshInstance3D, index: int, stride := 16) -> Transform3D:
	var buffer: PackedFloat32Array = batch.get_meta("instance_buffer")
	var n := index * stride
	return Transform3D(Basis(Vector3(buffer[n], buffer[n + 4], buffer[n + 8]),
		Vector3(buffer[n + 1], buffer[n + 5], buffer[n + 9]),
		Vector3(buffer[n + 2], buffer[n + 6], buffer[n + 10])),
		Vector3(buffer[n + 3], buffer[n + 7], buffer[n + 11]))


# Every clutter piece against the map's own keepout rows: a piece's origin keeps each row's
# clear distance, the footprint having been added when it was placed. Returns the count.
func _clutter_checks(game, dressing, stage: int) -> Dictionary:
	var map = game.ctx.terrain.map_for(stage)
	var ground: Callable = game.ctx.terrain.ground_callable(stage)
	var rows: Array = Dressing.keepouts(map, stage)
	var count := 0
	var worst := {}
	var tall := 0
	var tallest := 0.0
	var floating := 0.0
	var stand := true
	var names := {}
	for batch: MultiMeshInstance3D in dressing.batches:
		if not batch.has_meta("clutter"):
			continue
		var height := batch.multimesh.mesh.get_aabb().size.y
		for surface in batch.multimesh.mesh.get_surface_count():
			var mat := batch.multimesh.mesh.surface_get_material(surface) as ShaderMaterial
			stand = stand and mat != null and mat.shader.resource_path == "res://src/presentation/clutter.gdshader" \
				and mat.shader.get_shader_uniform_list().any(func(row): return row.name == "protected_rects")
		for i in batch.multimesh.instance_count:
			var tr := _instance(batch, i, 12)
			var at := Vector2(tr.origin.x, tr.origin.z)
			count += 1
			names[batch.name] = true
			var blocker := Dressing.blocked(rows, at, 0.0)
			if blocker != "":
				worst[blocker] = at
			var standing := height * tr.basis.y.length()
			tall += 1 if standing > 1.0 else 0
			tallest = maxf(tallest, standing)
			floating = maxf(floating, tr.origin.y - (ground.call(at.x, at.y, 0.0) as Vector3).y)
	check(worst.is_empty(), "no clutter inside a keepout row (" + str(rows.size()) + " rows): " + str(worst))
	check(stand and names.size() == 10, "every kit mesh is placed and uses the clutter shader with the screen-space protection")
	check(floating <= 0.0, "no clutter floats above the ground under its centre: " + str(floating))
	check(tall >= 3 and tallest > 2.0, "pieces vary: " + str(tall) + " over 1 m, tallest " + str(tallest) + " m")
	return {"count": count}

# The Cable Reach and the Spillway: each map's own surfaces, read independently of the
# keepout rows. A piece's origin must be 3 m clear of every riding surface, measured from the
# surface and not from a centreline.
const CLEAR := 3.0

func _reach_checks() -> void:
	Preset.apply("high")
	var game := Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	await process_frame
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.source = Intent.Scripted.new()
	for i in 10:
		await physics_frame
	Preset.apply("target")
	var dressing = game.presentation.set_dressing
	var map = game.ctx.terrain.map()
	check(dressing != null and dressing.map_id == "reach" and map.get_script() == Reach, "target dressing seeded on the Cable Reach")
	check(dressing.find_children("*", "CollisionObject3D", true, false).is_empty(), "reach clutter has no collision")
	var result := _clutter_checks(game, dressing, 1)
	check(result.count > 300, "reach clutter stands: " + str(result.count) + " pieces")
	var surfaces := _surfaces(map, true)
	var expected: int = TraversalLine.PILOTS.size() + Reach.TUNNELS.size() + 1 + map.kickers.size() + 2 + 3
	check(surfaces.size() == expected, "every ramp, kicker, tunnel and route is measured: " + str(surfaces.size()) + " of " + str(expected))
	var nearest := _nearest(dressing, surfaces)
	for key in nearest:
		check(nearest[key] >= CLEAR, "no reach clutter within 3 m of the " + key + ": nearest " + str(snappedf(nearest[key], 0.1)) + " m")
	check(nearest.size() == expected, "every measured surface met a piece: " + str(nearest.size()))
	game.free()
	Preset.apply("high")


# The gap in metres from a point to each riding surface or authored place of the map. Each row
# is {name, gap: Callable(Vector2) -> float}, the gap measured from the surface itself.
func _surfaces(map, reach: bool) -> Array:
	var rows := []
	rows.append(["reward gate slot", func(at: Vector2) -> float: return _to_points(at, map.gate_slots.map(func(row): return row.at))])
	rows.append(["activity site", func(at: Vector2) -> float: return _to_points(at, map.activity_sites.map(func(row): return row.at))])
	rows.append(["Warden bowl", func(at: Vector2) -> float: return at.distance_to(map.beacon) - Features.BOWL_FLAT])
	if not reach:
		for k in map.scrap_lines.size():
			var line: Array = map.scrap_lines[k]
			rows.append(["scrap line " + str(k), func(at: Vector2) -> float: return _to_line(at, line)])
		return rows
	var routes := TraversalLine.load_routes()
	for pilot in TraversalLine.PILOTS:
		var line := TraversalLine.route_of(routes, pilot)
		rows.append(["ride line " + pilot, func(at: Vector2) -> float: return _to_line(at, line)])
	for id in Reach.TUNNELS:
		var ends: Array = Reach.TUNNELS[id]
		rows.append(["tunnel floor " + id, func(at: Vector2) -> float: return _to_line(at, ends) - Reach.TUNNEL_HALF])
	var dive := [Reach.MOUTH + Reach.DIVE_DIR * Reach.DIVE_FROM, Reach.MOUTH + Reach.DIVE_DIR * (Reach.DIVE_TO + Reach.DIVE_OUT)]
	rows.append(["dive ramp", func(at: Vector2) -> float: return _to_line(at, dive) - (Reach.DIVE_HALF + Reach.DIVE_SIDE)])
	for k in map.kickers.size():
		var kicker: Dictionary = map.kickers[k]
		rows.append(["kicker " + str(k), func(at: Vector2) -> float: return _to_rect(at, kicker.at, kicker.dir, Reach.KICKER_LENGTH, Reach.KICKER_WIDTH)])
	rows.append(["sweeper ramp", func(at: Vector2) -> float: return _to_arc(at, Reach.SWEEP_CENTRE, Reach.SWEEP_ARC, Reach.SWEEP_WIDTH + Reach.SWEEP_BANK, Reach.SWEEP_FROM, Reach.SWEEP_TO)])
	rows.append(["berm ramp", func(at: Vector2) -> float: return _to_arc(at, Reach.BERM_CENTRE, Reach.BERM_RADIUS, Reach.BERM_WIDTH + Reach.BERM_BANK, Reach.BERM_FROM, Reach.BERM_TO)])
	return rows


func _nearest(dressing, surfaces: Array) -> Dictionary:
	var nearest := {}
	for batch: MultiMeshInstance3D in dressing.batches:
		if not batch.has_meta("clutter"):
			continue
		for i in batch.multimesh.instance_count:
			var origin := _instance(batch, i, 12).origin
			var at := Vector2(origin.x, origin.z)
			for row in surfaces:
				nearest[row[0]] = minf(nearest.get(row[0], INF), row[1].call(at))
	return nearest


func _to_points(at: Vector2, points: Array) -> float:
	var best := INF
	for point: Vector2 in points:
		best = minf(best, at.distance_to(point))
	return best


func _to_line(at: Vector2, line: Array) -> float:
	var best := INF
	for k in line.size() - 1:
		best = minf(best, at.distance_to(Geometry2D.get_closest_point_to_segment(at, line[k], line[k + 1])))
	return best


# Distance to a kicker's footprint: from `length` behind its foot to the lip, half its width each side.
func _to_rect(at: Vector2, foot: Vector2, dir: Vector2, length: float, width: float) -> float:
	var rel := at - foot
	var along := rel.dot(dir)
	var across := absf(rel.dot(Vector2(-dir.y, dir.x)))
	return Vector2(maxf(maxf(-length - along, along), 0.0), maxf(across - width * 0.5, 0.0)).length()


# Distance to a banked arc's surface: the radial band [radius, radius + band] within its
# angular span, the end caps measured to the band's corners.
func _to_arc(at: Vector2, centre: Vector2, radius: float, band: float, from_deg: float, to_deg: float) -> float:
	var rel := at - centre
	var span := wrapf(to_deg - from_deg, 0.0, 360.0)
	var into := wrapf(rad_to_deg(atan2(rel.y, rel.x)) - from_deg, 0.0, 360.0)
	var length := rel.length()
	if into <= span:
		return maxf(maxf(radius - length, length - radius - band), 0.0)
	var best := INF
	for end in [from_deg, to_deg]:
		var direction := Vector2.from_angle(deg_to_rad(end))
		best = minf(best, at.distance_to(Geometry2D.get_closest_point_to_segment(at, centre + direction * radius, centre + direction * (radius + band))))
	return best


# The Reach's route rows live under src/world, because tools/ is left out of the export, and
# must equal the matching rows of the tools file the bots read.
func _route_checks() -> void:
	var local = JSON.parse_string(FileAccess.get_file_as_string(Dressing.ROUTES))
	var tools := TraversalLine.load_routes()
	check(local is Dictionary and local.get("pilots") is Dictionary, "the reach route file is a Dictionary of pilots: " + Dressing.ROUTES)
	if not local is Dictionary:
		return
	check(not Dressing.ROUTES.begins_with("res://tools/"), "the runtime route file is not under tools/")
	var same: bool = local.get("pilots", {}).size() == TraversalLine.PILOTS.size()
	for pilot in TraversalLine.PILOTS:
		same = same and local.get("pilots", {}).get(pilot, {}).get("waypoints") == tools.get("pilots", {}).get(pilot, {}).get("waypoints") \
			and tools.get("pilots", {}).get(pilot, {}).get("waypoints", []).size() > 1
	check(same, "reach_routes.json rows equal the matching rows of tools/traversal_lines.json")
	Dressing._route_warned = false
	check(Dressing.pilot_rows(null).is_empty() and Dressing.pilot_rows("x").is_empty() and Dressing.pilot_rows([]).is_empty(), "a missing or non-Dictionary route file places no pilot keep-outs")
	check(Dressing._route_warned, "and warns")
	check(Dressing.pilot_rows(local).size() == TraversalLine.PILOTS.size(), "a good route file gives one keep-out row per pilot")
