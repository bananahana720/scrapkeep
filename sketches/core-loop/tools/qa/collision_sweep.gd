extends SceneTree


const OffscreenWindow := preload("res://tools/offscreen_window.gd")
const UndrawnPlaces := preload("res://tools/qa/undrawn_places.gd")
const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

const BALL_MASK := 1 | 4
const VISUAL_LAYER := 1 << 23
const NEAR_M := 1.5
const BAND_LOW := 0.15
const BAND_HIGH := 12.0
const ROLL_HIGH := 2.5
var max_samples := 4000
const NEAR_BEGIN_M := 10.0
const FLAG_AREA_M2 := 1.0
const GAPS := [0.7, 1.0]

var area := ""
var out_dir := ""
var run_seed := 1
var step := 0.75
var tol := 0.4
var centre := Vector2.INF
var radius := INF
var game
var space: PhysicsDirectSpaceState3D
var ground_fn: Callable
var shapes: Array = []
var visual_count := 0
var identity_multimeshes := 0
var report_owners := {}
var owner_filter := ""
var bot_policy := ""
var bot_seconds := 600.0
var driver
var watching := false
var bot_over := false
var contact_ticks := 0
var contacts := {}
var contact_total := 0
var ball_body: RigidBody3D


func _initialize() -> void:
	OffscreenWindow.apply(root)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--area="):
			area = a.trim_prefix("--area=")
		elif a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
		elif a.begins_with("--seed="):
			run_seed = int(a.trim_prefix("--seed="))
		elif a.begins_with("--step="):
			step = float(a.trim_prefix("--step="))
		elif a.begins_with("--tol="):
			tol = float(a.trim_prefix("--tol="))
		elif a.begins_with("--centre="):
			var p := a.trim_prefix("--centre=").split(",")
			centre = Vector2(float(p[0]), float(p[1]))
		elif a.begins_with("--max-samples="):
			max_samples = int(a.trim_prefix("--max-samples="))
		elif a.begins_with("--bot="):
			bot_policy = a.trim_prefix("--bot=")
		elif a.begins_with("--seconds="):
			bot_seconds = float(a.trim_prefix("--seconds="))
		elif a.begins_with("--owner="):
			owner_filter = a.trim_prefix("--owner=")
		elif a.begins_with("--radius="):
			radius = float(a.trim_prefix("--radius="))
	if area == "" or out_dir == "":
		printerr("collision_sweep: pass --area=camp|<park map> --out=<absolute dir>")
		quit(2)
		return
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	seed(run_seed)
	if area == "wall_fixture":
		game = Node3D.new()
		root.add_child(game)
		_add_fixture_wall("Park_QAWall_Matched", 2000.0, 0.0, not OS.get_cmdline_user_args().has("--plant-wall"))
		_add_fixture_wall("Park_QAWall_Near", 2010.0, 1.05, true)
		_add_fixture_wall("Park_QAWall_Missing", 2020.0, 0.0, false)
		if OS.get_cmdline_user_args().has("--preview-wall"):
			var preview := SubViewport.new()
			preview.own_world_3d = true
			game.add_child(preview)
			var mesh: MeshInstance3D = game.get_node("Park_QAWall_Matched").find_children("*", "MeshInstance3D", true, false)[0]
			var at := mesh.global_transform
			mesh.reparent(preview)
			mesh.global_transform = at
		var camera := Camera3D.new()
		camera.cull_mask = 1
		game.add_child(camera)
		camera.position = Vector3(2005, 5, 2009)
		camera.look_at(Vector3(2005, 4, 2000))
		if OS.get_cmdline_user_args().has("--frame"):
			var light := DirectionalLight3D.new()
			game.add_child(light)
			light.rotation_degrees = Vector3(-40, 35, 0)
			camera.environment = Environment.new()
			camera.environment.background_mode = Environment.BG_SKY
			camera.environment.sky = Sky.new()
			camera.environment.sky.sky_material = ProceduralSkyMaterial.new()
		ground_fn = func(_x: float, _z: float) -> float: return 0.0
		if not await _save_frame_if_requested():
			quit(1)
			return
		await _physics(2)
		await _sweep_map("")
		return
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	if bot_policy != "":
		await _run_bot()
		return
	var places_unavailable := ""
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.run.run_seed_override = run_seed
	var stage_index := 0
	if area == "camp":
		game.camp_hub.enter_walk()
		await _frames(30)
		var o: Vector3 = game.camp_hub.HUB_ORIGIN
		if centre == Vector2.INF:
			centre = Vector2(o.x, o.z)
			radius = game.camp_hub.GROUND_R + 5.0
		ground_fn = func(_x: float, _z: float) -> float: return o.y
	elif area == "arena":
		game.flow.press_start()
		game.flow.choose_class(0)
		game.flow.enter_stage(2, Vector3.ZERO, false)
		var terrain = game.ctx.terrain
		var waited := 0
		while waited < 3000 and not (terrain.rows_ready(2) and terrain.is_ready(2) and game.flow.state_name() == "stage"):
			await process_frame
			waited += 1
		game.flow._finish_stage()
		var bowl: Node3D = null
		waited = 0
		while waited < 1200 and (bowl == null or not bowl.built()):
			await process_frame
			waited += 1
			bowl = game.find_child("SlagBowl", true, false) as Node3D
		if bowl == null:
			printerr("collision_sweep: no built SlagBowl after stage 2 finished (flow %s)" % game.flow.state_name())
			quit(1)
			return
		await _frames(240)
		if centre == Vector2.INF:
			centre = Vector2(bowl.global_position.x, bowl.global_position.z)
			radius = bowl.BANK_R + bowl.WALL_THICK + 4.0
		ground_fn = func(x: float, z: float) -> float: return bowl.ground(Vector3(x, 0.0, z))
	else:
		for row in ParkDefs.DEFS:
			if String(row.get("map", "")) == area:
				stage_index = int(row["stage"])
		if stage_index == 0:
			printerr("collision_sweep: %s is not a park table map" % area)
			quit(2)
			return
		game.flow.press_start()
		game.flow.choose_class(0)
		if stage_index != 1:
			game.flow.enter_stage(stage_index, Vector3.ZERO, false)
		var terrain = game.ctx.terrain
		var waited := 0
		while waited < 3000 and not (terrain.rows_ready(stage_index) and terrain.is_ready(stage_index) and game.flow.state_name() == "stage"):
			await process_frame
			waited += 1
		if not (terrain.rows_ready(stage_index) and terrain.is_ready(stage_index) and game.flow.state_name() == "stage"):
			places_unavailable = "the park stage did not finish loading"
		var pp = game.presentation.park_props
		if pp != null:
			pp.finish()
		await _frames(30)
		ground_fn = func(x: float, z: float) -> float: return terrain.height(x, z)
	if OS.get_cmdline_user_args().has("--terrain") and stage_index > 0:
		_terrain_check(stage_index)
		quit(0)
		return
	if not await _save_frame_if_requested():
		quit(1)
		return
	ball_body = game.player.body()
	ball_body.freeze = true
	ball_body.global_position = Vector3(0.0, -5000.0, 0.0)
	await _physics(2)
	await _sweep_map(places_unavailable)


func _save_frame_if_requested() -> bool:
	if not OS.get_cmdline_user_args().has("--frame"):
		return true
	if DisplayServer.get_name() == "headless":
		return false
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame == null or frame.is_empty() or DirAccess.make_dir_recursive_absolute(out_dir) != OK:
		return false
	return frame.save_png(out_dir.path_join("view.png")) == OK


func _sweep_map(places_unavailable: String) -> void:
	var blockers := _blockers()
	var made := _visual_bodies(blockers)
	await _physics(3)
	space = game.get_world_3d().direct_space_state
	var flagged: Array = []
	var bare_by_owner := {}
	var totals := {"shapes": 0, "samples": 0, "bare": 0, "invisible": 0}
	for b: Dictionary in blockers:
		var owner := _owner_label(b["body"])
		if not bare_by_owner.has(owner):
			bare_by_owner[owner] = PackedVector3Array()
		var r := _sweep_shape(b, bare_by_owner[owner])
		totals["shapes"] += 1
		totals["samples"] += int(r["samples"])
		totals["bare"] += int(r["bare"])
		totals["invisible"] += int(r["invisible"])
		if float(r["invisible_band_m2"]) >= FLAG_AREA_M2 or float(r["bare_band_m2"]) >= FLAG_AREA_M2 * 4.0:
			flagged.append(r)
	flagged.sort_custom(func(a, b): return float(a["invisible_band_m2"]) + 0.25 * float(a["bare_band_m2"]) > float(b["invisible_band_m2"]) + 0.25 * float(b["bare_band_m2"]))
	for body in made:
		body.queue_free()
	if identity_multimeshes > 0:
		printerr("collision_sweep: %d MultiMeshes read every instance at one transform (headless renderer?): run under xvfb-run --rendering-driver opengl3" % identity_multimeshes)
	if area != "wall_fixture" and DisplayServer.get_name() == "headless":
		places_unavailable = "map places require a real renderer for MultiMesh transforms"
	elif identity_multimeshes > 0 or visual_count == 0 or blockers.is_empty() or totals["samples"] == 0:
		places_unavailable = "incomplete blocker or visual geometry"
	var filters := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--centre=") or arg.begins_with("--radius=") or arg.begins_with("--owner="):
			filters.append(arg)
	var stem := "%s-s%d" % [area, run_seed]
	if not filters.is_empty():
		stem += "-partial-" + " ".join(filters).sha256_text().left(10)
	if not places_unavailable.is_empty():
		stem += "-unavailable"
	var report := {"area": area, "filters": filters, "max_samples_per_shape": max_samples, "identity_multimeshes": identity_multimeshes, "seed": run_seed, "step": step, "tol": tol, "near_m": NEAR_M, "visual_meshes": visual_count,
		"band": [BAND_LOW, BAND_HIGH], "totals": totals, "flagged": flagged}
	if places_unavailable.is_empty():
		report["places"] = UndrawnPlaces.cluster(bare_by_owner, step)
		print("collision_sweep: %d undrawn places" % report["places"].size())
	else:
		report["places"] = null
		report["places_unavailable"] = places_unavailable
		printerr("collision_sweep: no place count: " + places_unavailable)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join(stem + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("collision_sweep: %s seed %d: %d shapes, %d visual meshes, %d samples, %d bare, %d invisible; %d flagged -> %s" % [
		area, run_seed, totals["shapes"], visual_count, totals["samples"], totals["bare"], totals["invisible"], flagged.size(), path])
	var by_owner := {}
	for r: Dictionary in flagged:
		var o := String(r["owner"])
		if not by_owner.has(o):
			by_owner[o] = [0, 0.0, 0.0, 0.0, 0.0]
		by_owner[o][0] += 1
		by_owner[o][1] += float(r["invisible_band_m2"])
		by_owner[o][2] += float(r["bare_band_m2"])
		by_owner[o][3] += float(r["invisible_roll_m2"])
		by_owner[o][4] += float(r["bare_roll_m2"])
	report_owners = by_owner
	for o in by_owner:
		print("  owner %-44s shapes %3d  inv %8.1f m2  bare %8.1f m2  | rolling band inv %7.1f bare %7.1f" % [o.left(44), by_owner[o][0], by_owner[o][1], by_owner[o][2], by_owner[o][3], by_owner[o][4]])
	var of := FileAccess.open(out_dir.path_join(stem + "-owners.json"), FileAccess.WRITE)
	of.store_string(JSON.stringify(by_owner, "  "))
	of.close()
	for r: Dictionary in flagged.slice(0, 40):
		print("  %-58s inv %7.1f m2  bare %7.1f m2  at %s  (%s)" % [String(r["owner"]).left(58), r["invisible_band_m2"], r["bare_band_m2"], str(r["worst"]), r["shape"]])
	quit(0)


func _add_fixture_wall(label: String, x: float, mesh_offset_z: float, drawn: bool) -> void:
	var wall := StaticBody3D.new()
	wall.name = label
	wall.position = Vector3(x, 4, 2000)
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 2, 0.5)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	wall.add_child(collider)
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	view.mesh = mesh
	view.position.z = mesh_offset_z
	view.visible = drawn
	if label == "Park_QAWall_Matched":
		if OS.get_cmdline_user_args().has("--layer-zero-wall"):
			view.layers = 0
		elif OS.get_cmdline_user_args().has("--camera-masked-wall"):
			view.layers = 2
	wall.add_child(view)
	game.add_child(wall)


func _in_area(p: Vector3) -> bool:
	return centre == Vector2.INF or Vector2(p.x, p.z).distance_to(centre) <= radius


func _blockers() -> Array:
	var out: Array = []
	var skipped := {}
	var ball := ball_body
	for node in game.find_children("*", "CollisionObject3D", true, false):
		if node is Area3D or node == ball:
			continue
		if not (node is StaticBody3D or node is AnimatableBody3D or (node is RigidBody3D and (node as RigidBody3D).freeze)):
			continue
		var body := node as CollisionObject3D
		if body.collision_layer & BALL_MASK == 0 or not body.is_inside_tree():
			continue
		if body.get_parent() != null and String(body.get_parent().name) == "Tiles":
			continue
		if not PhysicsServer3D.body_get_space(body.get_rid()).is_valid():
			skipped["off_space"] = int(skipped.get("off_space", 0)) + 1
			continue
		for owner_id in body.get_shape_owners():
			if body.is_shape_owner_disabled(owner_id):
				continue
			var at := body.global_transform * body.shape_owner_get_transform(owner_id)
			var owner_obj := body.shape_owner_get_owner(owner_id)
			for i in body.shape_owner_get_shape_count(owner_id):
				var shape := body.shape_owner_get_shape(owner_id, i)
				if shape == null or shape is HeightMapShape3D or shape is WorldBoundaryShape3D:
					continue
				var faces := _shape_faces(shape)
				if faces.is_empty():
					continue
				var aabb := AABB(at * faces[0], Vector3.ZERO)
				for v in faces:
					aabb = aabb.expand(at * v)
				if not _in_area(aabb.get_center()) and not _in_area(aabb.position) and not _in_area(aabb.end):
					continue
				if owner_filter != "" and not _owner_label(body).contains(owner_filter):
					continue
				var label := str(game.get_path_to(owner_obj)) if owner_obj is Node and owner_obj != body else "%s#%d.%d" % [game.get_path_to(body), owner_id, i]
				out.append({"shape": shape, "label": label, "body": body, "xf": at, "faces": faces, "aabb": aabb})
	print("collision_sweep: %d blocking shapes, skipped %s" % [out.size(), skipped])
	if OS.get_cmdline_user_args().has("--census"):
		_census(ball)
	return out


func _shape_faces(shape: Shape3D) -> PackedVector3Array:
	if shape is ConcavePolygonShape3D:
		return (shape as ConcavePolygonShape3D).get_faces()
	var mesh := shape.get_debug_mesh()
	return mesh.get_faces() if mesh != null else PackedVector3Array()


func _rider_can_see(view: GeometryInstance3D) -> bool:
	var camera := root.get_camera_3d()
	return camera != null and view.get_world_3d() == camera.get_world_3d() and view.is_visible_in_tree() and (view.layers & camera.cull_mask) != 0


func _visual_bodies(blockers: Array) -> Array:
	var cell := 32.0
	var grid := {}
	for b: Dictionary in blockers:
		var bx: AABB = (b["aabb"] as AABB).grow(NEAR_M + 0.5)
		for i in range(floori(bx.position.x / cell), floori(bx.end.x / cell) + 1):
			for k in range(floori(bx.position.z / cell), floori(bx.end.z / cell) + 1):
				var key := Vector2i(i, k)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(bx)
	var near := func(box: AABB) -> bool:
		for i in range(floori(box.position.x / cell), floori(box.end.x / cell) + 1):
			for k in range(floori(box.position.z / cell), floori(box.end.z / cell) + 1):
				for bx: AABB in grid.get(Vector2i(i, k), []):
					if bx.intersects(box):
						return true
		return false
	var holder := Node3D.new()
	holder.name = "SweepVisuals"
	game.add_child(holder)
	var player_node: Node = game.player if ball_body != null else null
	var made: Array = [holder]
	for node in game.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if not _rider_can_see(gi) or gi.visibility_range_begin > NEAR_BEGIN_M:
			continue
		if (player_node != null and player_node.is_ancestor_of(gi)) or holder.is_ancestor_of(gi):
			continue
		var items: Array = []
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			items.append([(gi as MeshInstance3D).mesh, gi.global_transform])
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm.mesh == null or mm.transform_format != MultiMesh.TRANSFORM_3D:
				continue
			for x: Transform3D in _instances(gi as MultiMeshInstance3D):
				items.append([mm.mesh, gi.global_transform * x])
		for item: Array in items:
			var mesh: Mesh = item[0]
			var xf: Transform3D = item[1]
			var box: AABB = xf * mesh.get_aabb()
			if box.size.length() < 0.05 or not near.call(box):
				continue
			var faces := mesh.get_faces()
			if faces.is_empty():
				continue
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(xf * faces)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			var body := StaticBody3D.new()
			body.collision_layer = VISUAL_LAYER
			body.collision_mask = 0
			body.add_child(cs)
			holder.add_child(body)
			visual_count += 1
	return made


# reads them), else per instance. The headless dummy renderer keeps no instance data: run under xvfb-run with
# --rendering-driver opengl3, or every instance reads as the identity and drawn posts look missing.
func _instances(view: MultiMeshInstance3D) -> Array:
	var mm := view.multimesh
	var n := mm.instance_count if mm.visible_instance_count < 0 else mini(mm.visible_instance_count, mm.instance_count)
	var out: Array = []
	if n <= 0:
		return out
	var buf := mm.buffer
	if buf.size() < n * 12 and view.has_meta("instance_buffer"):
		buf = view.get_meta("instance_buffer")
	if buf.size() >= n * 12:
		var stride := buf.size() / mm.instance_count
		for i in n:
			var o := i * stride
			out.append(Transform3D(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
				Vector3(buf[o + 2], buf[o + 6], buf[o + 10]), Vector3(buf[o + 3], buf[o + 7], buf[o + 11])))
	else:
		for i in n:
			out.append(mm.get_instance_transform(i))
	if n > 1 and out.all(func(x): return x == out[0]):
		identity_multimeshes += 1
	return out


func _sweep_shape(b: Dictionary, bare_positions: PackedVector3Array) -> Dictionary:
	var shape: Shape3D = b["shape"]
	var body: CollisionObject3D = b["body"]
	var xf: Transform3D = b["xf"]
	var faces: PackedVector3Array = b["faces"]
	var total_area := 0.0
	var areas := PackedFloat32Array()
	areas.resize(faces.size() / 3)
	for t in areas.size():
		var a := xf * faces[t * 3]
		var bb := xf * faces[t * 3 + 1]
		var c := xf * faces[t * 3 + 2]
		areas[t] = (bb - a).cross(c - a).length() * 0.5
		total_area += areas[t]
	var s := step
	if total_area / (s * s) > max_samples:
		s = sqrt(total_area / max_samples)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(b["label"]))
	var probe := SphereShape3D.new()
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.collision_mask = VISUAL_LAYER
	q.collide_with_areas = false
	var pq := PhysicsPointQueryParameters3D.new()
	pq.collision_mask = BALL_MASK
	pq.exclude = [body.get_rid()]
	var samples := 0
	var bare := 0
	var invisible := 0
	var bare_band := 0
	var inv_band := 0
	var bare_roll := 0
	var gaps := {}
	var roll_points := 0
	var inv_roll := 0
	var points: Array = []
	var worst := Vector3.ZERO
	var worst_h := -1.0
	for t in areas.size():
		var a := xf * faces[t * 3]
		var bb := xf * faces[t * 3 + 1]
		var c := xf * faces[t * 3 + 2]
		var n := (bb - a).cross(c - a).normalized()
		var want := areas[t] / (s * s)
		var count := int(want) + (1 if rng.randf() < want - int(want) else 0)
		for k in count:
			var u := rng.randf()
			var v := rng.randf()
			if u + v > 1.0:
				u = 1.0 - u
				v = 1.0 - v
			var p := a + (bb - a) * u + (c - a) * v
			if not _in_area(p):
				continue
			var g: float = ground_fn.call(p.x, p.z)
			var h := p.y - g
			if h < -0.05:
				continue
			pq.position = p
			if not space.intersect_point(pq, 1).is_empty():
				continue
			samples += 1
			if absf(h) <= tol:
				continue
			probe.radius = tol
			q.transform = Transform3D(Basis.IDENTITY, p)
			if not space.intersect_shape(q, 1).is_empty():
				continue
			if _enclosed(p, n):
				continue
			bare += 1
			bare_positions.append(p)
			probe.radius = NEAR_M
			var none_near := space.intersect_shape(q, 1).is_empty()
			var gap: Variant = "none" if none_near else NEAR_M
			if not none_near:
				for g_m in GAPS:
					probe.radius = g_m
					if not space.intersect_shape(q, 1).is_empty():
						gap = g_m
						break
			if h >= BAND_LOW and h <= ROLL_HIGH:
				gaps[str(gap)] = int(gaps.get(str(gap), 0)) + 1
			if none_near:
				invisible += 1
			var in_band := h >= BAND_LOW and h <= BAND_HIGH
			if in_band and h <= ROLL_HIGH:
				bare_roll += 1
				if none_near:
					inv_roll += 1
			if in_band:
				bare_band += 1
				if none_near:
					inv_band += 1
					if h > worst_h:
						worst_h = h
						worst = p
			var rolling := in_band and h <= ROLL_HIGH
			if in_band and ((rolling and roll_points < 600) or (not rolling and points.size() - roll_points < 200)):
				roll_points += 1 if rolling else 0
				points.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1), 1 if none_near else 0, snappedf(h, 0.1)])
	var owner := _owner_label(body)
	var aabb: AABB = b["aabb"]
	return {
		"owner": owner,
		"recipe": _meta_up(body, "park_recipe"),
		"path": String(b["label"]),
		"shape": shape.get_class() + _shape_size(shape),
		"aabb": [snappedf(aabb.position.x, 0.1), snappedf(aabb.position.y, 0.1), snappedf(aabb.position.z, 0.1),
			snappedf(aabb.size.x, 0.1), snappedf(aabb.size.y, 0.1), snappedf(aabb.size.z, 0.1)],
		"area_m2": snappedf(total_area, 0.1),
		"samples": samples, "bare": bare, "invisible": invisible,
		"bare_band_m2": snappedf(bare_band * s * s, 0.1),
		"invisible_band_m2": snappedf(inv_band * s * s, 0.1),
		"bare_roll_m2": snappedf(bare_roll * s * s, 0.1),
		"roll_gap_m2": _scaled(gaps, s * s),
		"invisible_roll_m2": snappedf(inv_roll * s * s, 0.1),
		"worst": [snappedf(worst.x, 0.1), snappedf(worst.y, 0.1), snappedf(worst.z, 0.1), snappedf(worst_h, 0.1)] if worst_h >= 0.0 else [],
		"points": points,
	}


func _enclosed(p: Vector3, _n: Vector3) -> bool:
	var rq := PhysicsRayQueryParameters3D.new()
	rq.collision_mask = VISUAL_LAYER
	rq.hit_back_faces = true
	rq.hit_from_inside = false
	var odd := 0
	var dirs := [Vector3.UP, Vector3.RIGHT, Vector3.BACK]
	for i in dirs.size():
		var d: Vector3 = dirs[i]
		var from := p
		var crossings := 0
		for k in 24:
			rq.from = from
			rq.to = p + d * 60.0
			var hit := space.intersect_ray(rq)
			if hit.is_empty():
				break
			crossings += 1
			from = (hit["position"] as Vector3) + d * 0.01
		if crossings % 2 == 1:
			odd += 1
		if odd >= 2:
			return true
		if odd + (dirs.size() - 1 - i) < 2:
			return false
	return false


func _scaled(counts: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in counts:
		out[key] = snappedf(counts[key] * k, 0.1)
	return out


func _shape_size(shape: Shape3D) -> String:
	if shape is BoxShape3D:
		var v: Vector3 = (shape as BoxShape3D).size
		return " %.1fx%.1fx%.1f" % [v.x, v.y, v.z]
	if shape is CylinderShape3D:
		return " r%.1f h%.1f" % [(shape as CylinderShape3D).radius, (shape as CylinderShape3D).height]
	if shape is SphereShape3D:
		return " r%.1f" % (shape as SphereShape3D).radius
	if shape is CapsuleShape3D:
		return " r%.1f h%.1f" % [(shape as CapsuleShape3D).radius, (shape as CapsuleShape3D).height]
	if shape is ConcavePolygonShape3D:
		return " %d tris" % ((shape as ConcavePolygonShape3D).get_faces().size() / 3)
	if shape is ConvexPolygonShape3D:
		return " %d pts" % (shape as ConvexPolygonShape3D).points.size()
	return ""


func _meta_up(node: Node, key: String) -> String:
	var n := node
	while n != null and n != game:
		if n.has_meta(key):
			return str(n.get_meta(key))
		n = n.get_parent()
	return ""


func _owner_label(body: Node) -> String:
	var n := body
	while n != null and n != game:
		var nm := String(n.name)
		if nm.begins_with("Park_") or nm.begins_with("Landmark_"):
			return nm
		if n.get_parent() != null and String(n.get_parent().name) == "CampRoot":
			return "camp/" + nm
		n = n.get_parent()
	return str(game.get_path_to(body.get_parent()))


func _census(ball: Node) -> void:
	var rows := {}
	for node in game.find_children("*", "CollisionObject3D", true, false):
		var body := node as CollisionObject3D
		if body == ball:
			continue
		var kinds := {}
		for c in body.get_children():
			var kk := c.get_class() + ("(" + (c as CollisionShape3D).shape.get_class() + ")" if c is CollisionShape3D and (c as CollisionShape3D).shape != null else "")
			kinds[kk] = int(kinds.get(kk, 0)) + 1
		var key := "%s layer=%d mask=%d owners=%d %s %s" % [body.get_class(), body.collision_layer, body.collision_mask, body.get_shape_owners().size(), _owner_label(body).get_slice("/", 0).left(40), kinds]
		rows[key] = int(rows.get(key, 0)) + 1
	var keys := rows.keys()
	keys.sort()
	for k in keys:
		print("  census %4d  %s" % [rows[k], k])


func _run_bot() -> void:
	game.run.run_seed_override = run_seed
	driver = BotDriver.new(game, bot_policy, run_seed)
	driver.start(false)
	var terrain = game.ctx.terrain
	while not (game.flow.state_name() == "stage" and terrain.rows_ready(1) and terrain.is_ready(1)):
		await process_frame
	await _frames(10)
	ground_fn = func(x: float, z: float) -> float: return terrain.height(x, z)
	ball_body = game.player.body()
	_visual_bodies(_blockers())
	await _physics(3)
	space = game.get_world_3d().direct_space_state
	watching = true
	var started := Time.get_ticks_msec()
	var stage_time := 0.0
	while not bot_over and game.flow.stage() <= 1 and float(game.run.stage_time) < bot_seconds:
		await process_frame
		stage_time = float(game.run.stage_time)
	watching = false
	var rows: Array = []
	for key in contacts:
		rows.append(contacts[key])
	rows.sort_custom(func(a, b): return int(a["ticks"]) > int(b["ticks"]))
	var report := {"area": "park_dam", "mode": "bot", "policy": bot_policy, "seed": run_seed, "stage_time_s": snappedf(stage_time, 0.1),
		"wall_s": (Time.get_ticks_msec() - started) / 1000.0, "contact_ticks": contact_ticks, "contacts": contact_total,
		"invisible_contacts": rows}
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join("bot-%s-s%d.json" % [bot_policy, run_seed])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("collision_sweep: bot %s seed %d: stage time %.1f s, %d contact ticks, %d contacts, %d invisible-contact cells -> %s" % [
		bot_policy, run_seed, stage_time, contact_ticks, contact_total, rows.size(), path])
	for r: Dictionary in rows.slice(0, 30):
		print("  %-40s ticks %4d  at %s  max speed %.1f  %s" % [String(r["owner"]).left(40), r["ticks"], str(r["at"]), r["speed"], r["body"]])
	quit(0)


func _physics_process(delta: float) -> bool:
	if driver != null and not bot_over:
		bot_over = driver.tick(delta)
	if watching:
		_watch_contacts()
	return false


func _watch_contacts() -> void:
	var state := PhysicsServer3D.body_get_direct_state(ball_body.get_rid())
	if state == null:
		return
	var n := state.get_contact_count()
	if n > 0:
		contact_ticks += 1
	var probe := SphereShape3D.new()
	probe.radius = tol + 0.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.collision_mask = VISUAL_LAYER
	for i in n:
		var obj := state.get_contact_collider_object(i)
		if not obj is CollisionObject3D:
			continue
		var body := obj as CollisionObject3D
		if body.get_parent() != null and String(body.get_parent().name) == "Tiles":
			continue
		contact_total += 1
		var p := state.get_contact_collider_position(i)
		if absf(p.y - float(ground_fn.call(p.x, p.z))) <= tol + 0.1:
			continue
		q.transform = Transform3D(Basis.IDENTITY, p)
		if not space.intersect_shape(q, 1).is_empty():
			continue
		if _drawn_near(body, p):
			continue
		var cell := Vector3i((p / 2.0).round())
		var key := "%s|%s" % [body.get_instance_id(), cell]
		if not contacts.has(key):
			contacts[key] = {"owner": _owner_label(body), "body": str(game.get_path_to(body)), "class": body.get_class(),
				"at": [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)], "ticks": 0, "speed": 0.0,
				"h": snappedf(p.y - float(ground_fn.call(p.x, p.z)), 0.1)}
		contacts[key]["ticks"] += 1
		contacts[key]["speed"] = snappedf(maxf(float(contacts[key]["speed"]), ball_body.linear_velocity.length()), 0.1)


func _drawn_near(body: Node, p: Vector3) -> bool:
	var top: Node = body.get_parent() if body.get_parent() != null else body
	for node in [body] + top.find_children("*", "GeometryInstance3D", true, false):
		if node is GeometryInstance3D and _rider_can_see(node):
			var gi := node as GeometryInstance3D
			if (gi.global_transform * gi.get_aabb()).grow(tol).has_point(p):
				return true
	return false


func _terrain_check(stage_index: int) -> void:
	var ground = game.ctx.terrain._grounds[stage_index - 1]
	var t3d = ground.terrain3d
	if t3d == null or t3d.data == null:
		printerr("collision_sweep: no Terrain3D render for stage %d" % stage_index)
		return
	var h: PackedFloat32Array = ground.heights
	var side: int = ground.SIDE
	var step_m: float = ground.STEP
	var half: float = ground.HALF
	var buckets := {}
	var worst: Array = []
	var nan := 0
	for j in side:
		for i in side:
			var x := -half + i * step_m
			var z := -half + j * step_m
			var drawn: float = t3d.data.get_height(Vector3(x, 0.0, z))
			if is_nan(drawn):
				nan += 1
				continue
			var d := h[j * side + i] - drawn
			var b := "%.1f" % clampf(snappedf(d, 0.5), -5.0, 5.0)
			buckets[b] = int(buckets.get(b, 0)) + 1
			if absf(d) > 0.3:
				worst.append([snappedf(d, 0.01), x, z, snappedf(drawn, 0.01)])
	worst.sort_custom(func(a, c): return absf(a[0]) > absf(c[0]))
	print("collision_sweep: terrain stage %d: %d vertices, %d drawn holes (NaN), off by >0.3 m: %d, buckets %s" % [stage_index, side * side, nan, worst.size(), buckets])
	for w in worst.slice(0, 30):
		print("  terrain collider - drawn %+.2f m at (%.0f, %.0f), drawn y %.2f" % w)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join("%s-terrain.json" % area), FileAccess.WRITE)
	f.store_string(JSON.stringify({"area": area, "buckets": buckets, "nan": nan, "off": worst.slice(0, 5000)}, " "))
	f.close()
