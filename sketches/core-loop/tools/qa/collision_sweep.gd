extends SceneTree

# Invisible-wall sweep (world 1 QA, 30 Oct). Boots the game headless like the bot runs, builds one area (the camp walk or a
# park stage), and checks every static collider the ball can hit against the meshes that draw there:
#   - each blocking shape (StaticBody3D / AnimatableBody3D on the ball's mask, terrain tiles left out: Terrain3D draws the
#     same heights) is sampled over its surface, about one point per --step m;
#   - every drawn mesh near a blocker (MeshInstance3D and each MultiMesh instance, visible in the tree, no near
#     visibility_range_begin) is copied as a trimesh onto a private layer, and each sample asks whether drawn geometry is
#     within --tol m of it (or the ground is, or a drawn volume encloses it);
#   - samples under the ground, inside another blocker or out of the ball's reach band are skipped.
# A sample with no drawn surface within --tol is "bare"; with none within NEAR_M either it is "invisible" (nothing at all
# draws there). The report ranks shapes by invisible area in the ball's band (0.15-12 m above the ground).
#
#   $GODOT_BIN --headless --path sketches/core-loop --script res://tools/qa/collision_sweep.gd -- \
#     --area=camp|park_dam|park_flume|... --out=<abs dir> [--seed=1] [--step=0.75] [--tol=0.4] [--centre=x,z --radius=r]
#
# Writes <out>/<area>-s<seed>.json (every flagged shape with its bare points) and prints a summary table.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

const BALL_MASK := 1 | 4
const VISUAL_LAYER := 1 << 23
const NEAR_M := 1.5
const BAND_LOW := 0.15
const BAND_HIGH := 12.0
const MAX_SAMPLES := 4000
const NEAR_BEGIN_M := 10.0
const FLAG_AREA_M2 := 1.0

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


func _initialize() -> void:
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
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
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
		var pp = game.presentation.park_props
		if pp != null:
			pp.finish()
		await _frames(30)
		ground_fn = func(x: float, z: float) -> float: return terrain.height(x, z)
	game.player.body().freeze = true
	game.player.body().global_position = Vector3(0.0, -5000.0, 0.0)
	await _physics(2)
	var blockers := _blockers()
	var made := _visual_bodies(blockers)
	await _physics(3)
	space = game.get_world_3d().direct_space_state
	var flagged: Array = []
	var totals := {"shapes": 0, "samples": 0, "bare": 0, "invisible": 0}
	for b: Dictionary in blockers:
		var r := _sweep_shape(b)
		totals["shapes"] += 1
		totals["samples"] += int(r["samples"])
		totals["bare"] += int(r["bare"])
		totals["invisible"] += int(r["invisible"])
		if float(r["invisible_band_m2"]) >= FLAG_AREA_M2 or float(r["bare_band_m2"]) >= FLAG_AREA_M2 * 4.0:
			flagged.append(r)
	flagged.sort_custom(func(a, b): return float(a["invisible_band_m2"]) + 0.25 * float(a["bare_band_m2"]) > float(b["invisible_band_m2"]) + 0.25 * float(b["bare_band_m2"]))
	for body in made:
		body.queue_free()
	var report := {"area": area, "seed": run_seed, "step": step, "tol": tol, "near_m": NEAR_M, "visual_meshes": visual_count,
		"band": [BAND_LOW, BAND_HIGH], "totals": totals, "flagged": flagged}
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join("%s-s%d.json" % [area, run_seed])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("collision_sweep: %s seed %d: %d shapes, %d visual meshes, %d samples, %d bare, %d invisible; %d flagged -> %s" % [
		area, run_seed, totals["shapes"], visual_count, totals["samples"], totals["bare"], totals["invisible"], flagged.size(), path])
	for r: Dictionary in flagged:
		print("  %-58s inv %7.1f m2  bare %7.1f m2  at %s  (%s)" % [String(r["owner"]).left(58), r["invisible_band_m2"], r["bare_band_m2"], str(r["worst"]), r["shape"]])
	quit(0)


func _in_area(p: Vector3) -> bool:
	return centre == Vector2.INF or Vector2(p.x, p.z).distance_to(centre) <= radius


# Every enabled CollisionShape3D on a static body the ball collides with, terrain tiles left out.
func _blockers() -> Array:
	var out: Array = []
	var ball = game.player.body()
	for node in game.find_children("*", "CollisionObject3D", true, false):
		if node is Area3D or node == ball:
			continue
		if not (node is StaticBody3D or node is AnimatableBody3D):
			continue
		var body := node as CollisionObject3D
		if body.collision_layer & BALL_MASK == 0 or not body.is_inside_tree():
			continue
		if body.get_parent() != null and String(body.get_parent().name) == "Tiles":
			continue
		if body.process_mode == Node.PROCESS_MODE_DISABLED or not body.can_process():
			if body.disable_mode == CollisionObject3D.DISABLE_MODE_REMOVE:
				continue
		for child in body.get_children():
			if not child is CollisionShape3D:
				continue
			var cs := child as CollisionShape3D
			if cs.disabled or cs.shape == null or cs.shape is HeightMapShape3D or cs.shape is WorldBoundaryShape3D:
				continue
			var xf := cs.global_transform
			var faces := _shape_faces(cs.shape)
			if faces.is_empty():
				continue
			var aabb := AABB(xf * faces[0], Vector3.ZERO)
			for v in faces:
				aabb = aabb.expand(xf * v)
			if not _in_area(aabb.get_center()) and not _in_area(aabb.position) and not _in_area(aabb.end):
				continue
			out.append({"cs": cs, "body": body, "xf": xf, "faces": faces, "aabb": aabb})
	return out


func _shape_faces(shape: Shape3D) -> PackedVector3Array:
	if shape is ConcavePolygonShape3D:
		return (shape as ConcavePolygonShape3D).get_faces()
	var mesh := shape.get_debug_mesh()
	return mesh.get_faces() if mesh != null else PackedVector3Array()


# Drawn meshes near any blocker, copied as baked trimeshes onto VISUAL_LAYER.
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
	var player_node: Node = game.player
	var made: Array = [holder]
	for node in game.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if not gi.is_visible_in_tree() or gi.visibility_range_begin > NEAR_BEGIN_M:
			continue
		if player_node.is_ancestor_of(gi) or holder.is_ancestor_of(gi):
			continue
		var items: Array = []
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			items.append([(gi as MeshInstance3D).mesh, gi.global_transform])
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm.mesh == null or mm.transform_format != MultiMesh.TRANSFORM_3D:
				continue
			var count := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			for i in count:
				items.append([mm.mesh, gi.global_transform * mm.get_instance_transform(i)])
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


func _sweep_shape(b: Dictionary) -> Dictionary:
	var cs: CollisionShape3D = b["cs"]
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
	if total_area / (s * s) > MAX_SAMPLES:
		s = sqrt(total_area / MAX_SAMPLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(cs.get_path()))
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
			probe.radius = NEAR_M
			var none_near := space.intersect_shape(q, 1).is_empty()
			if none_near:
				invisible += 1
			var in_band := h >= BAND_LOW and h <= BAND_HIGH
			if in_band:
				bare_band += 1
				if none_near:
					inv_band += 1
					if h > worst_h:
						worst_h = h
						worst = p
			if points.size() < 400 and in_band:
				points.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1), 1 if none_near else 0])
	var owner := _owner_label(body)
	var aabb: AABB = b["aabb"]
	return {
		"owner": owner,
		"recipe": _meta_up(body, "park_recipe"),
		"path": str(game.get_path_to(cs)),
		"shape": cs.shape.get_class() + _shape_size(cs.shape),
		"aabb": [snappedf(aabb.position.x, 0.1), snappedf(aabb.position.y, 0.1), snappedf(aabb.position.z, 0.1),
			snappedf(aabb.size.x, 0.1), snappedf(aabb.size.y, 0.1), snappedf(aabb.size.z, 0.1)],
		"area_m2": snappedf(total_area, 0.1),
		"samples": samples, "bare": bare, "invisible": invisible,
		"bare_band_m2": snappedf(bare_band * s * s, 0.1),
		"invisible_band_m2": snappedf(inv_band * s * s, 0.1),
		"worst": [snappedf(worst.x, 0.1), snappedf(worst.y, 0.1), snappedf(worst.z, 0.1), snappedf(worst_h, 0.1)] if worst_h >= 0.0 else [],
		"points": points,
	}


# Inside a drawn volume: at least four of six axis rays meet a back face first.
func _enclosed(p: Vector3, _n: Vector3) -> bool:
	var rq := PhysicsRayQueryParameters3D.new()
	rq.collision_mask = VISUAL_LAYER
	rq.hit_back_faces = true
	rq.hit_from_inside = true
	var inside := 0
	var dirs := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for i in dirs.size():
		var d: Vector3 = dirs[i]
		rq.from = p
		rq.to = p + d * 40.0
		var hit := space.intersect_ray(rq)
		if not hit.is_empty() and (hit["normal"] as Vector3).dot(d) > 0.0:
			inside += 1
		if inside + (dirs.size() - 1 - i) < 4:
			return false
		if inside >= 4:
			return true
	return false


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


# The nearest named owner: a park row or landmark, a camp piece, else the body's parent path.
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
