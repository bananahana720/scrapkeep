extends SceneTree

# W1-129. Read the old and new surfaces together in the built flume. The footing must
# meet ground and the existing tower, and both its drawn side and physics side must agree.
# Lift the added shape out of the world for the stock underpass control. A full-width
# solid planted under that opening must stop the same ball-size sweep.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")
const Footings := preload("res://src/world/park/footings.gd")
const FLUME_ROWS := "res://src/world/park/park_flume.json"
# A tower's legs stand this far in from the ends of its length (flume_works.py), along its own z axis.
const END_INSET_M := 1.05
# An end's gap is measured to the lowest ground under the leg: across the tower's width and this far
# either side of the leg along its length.
const END_SPAN_M := 1.0
# A bare end hanging more than this is listed in the gap check's detail for the owner.
const HANG_NOTE_M := 0.3
# The count of footed towers in today's rows. A pin on the data, not a rule: a new hanging tower moves it.
const FOOTED_TODAY := 5
# A tower is crossed this far either side of its middle, beside its end footings.
const CROSSING_Z_M := 3.0
const CROSSING_HALF_M := 3.3
const CLEAR_M := 0.05
const CROSSING_SAMPLES := 8
const CROSSING_STEP_M := 1.0
const EPS := 0.015

var _t := T.new("park_grapple_footing_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 3000 and not (terrain.rows_ready(2) and terrain.is_ready(2) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	if not _t.check("built the real park flume", waited < 3000 and terrain.map().title == "park_flume"):
		game.free()
		quit(_t.verdict())
		return
	game.player.body().freeze = true
	game.player.body().global_position = Vector3(0.0, -5000.0, 0.0)
	await physics_frame
	await physics_frame
	var space := game.get_world_3d().direct_space_state
	var stage: Node3D = terrain.geometry_root(2)
	var ground: Callable = terrain.ground_callable(2)
	var rows: Dictionary = {}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(FLUME_ROWS))["park_rows"]:
		rows[String(row["id"])] = row
	var towers := 0
	var footed_ids: Array[String] = []
	var wrong: Array[String] = []
	var hanging_bare: Array[String] = []
	for id: String in rows:
		var recipe := String(rows[id]["recipe"])
		if not Footings.TABLE.has(recipe) or Footings.TABLE[recipe]["tiled"]:
			continue
		towers += 1
		var node := _row(stage, id)
		if not _t.check("%s is placed in the stage" % id, node != null):
			continue
		var view := node.get_node_or_null("Footings") as MeshInstance3D
		var footed := view != null and node.has_node("Collider/Footings")
		if footed:
			footed_ids.append(id)
		var gaps := _end_gaps(node, rows[id], ground)
		for side in 2:
			var gap: float = gaps[side]
			var has := view != null and _has_end(view, side)
			var wants := gap > Footings.TOWER_MIN_GAP_M
			if has != wants:
				wrong.append("%s end %d: gap %.2f m, %s" % [id, side, gap, "footed" if has else "bare"])
			if not has and gap > HANG_NOTE_M:
				hanging_bare.append("%s end %d: %.2f m" % [id, side, gap])
	_t.check("the flume's tower rows were found", towers > 0)
	_t.check("each tower end is footed exactly when its gap exceeds %.2f m" % Footings.TOWER_MIN_GAP_M, wrong.is_empty() and towers > 0,
		"%d towers; wrong: %s; bare ends hanging more than %.1f m: %s" % [towers, wrong, HANG_NOTE_M, hanging_bare])
	_t.check("today's rows have %d footed towers" % FOOTED_TODAY, footed_ids.size() == FOOTED_TODAY, "footed: %s" % [footed_ids])
	var swept := 0
	var open_crossings := 0
	for id in footed_ids:
		_check_tower(_row(stage, id), space, ground, rows[id])
		var crossings: Array[int] = await _check_underpass(_row(stage, id), space, ground)
		swept += crossings[0]
		open_crossings += crossings[1]
	_t.check("crossings beside the footings were swept, and some are open without them", swept > 0 and open_crossings > 0, "%d swept, %d open" % [swept, open_crossings])
	game.free()
	quit(_t.verdict())


func _floor(ground: Callable, at: Vector3) -> float:
	return (ground.call(at.x, at.z, 0.0) as Vector3).y


# Each end's gap, from the row and the ground alone: the lowest ground under the leg against the tower's
# underside, which is the row's own height or, with none, the ground at its spot.
func _end_gaps(node: Node3D, row: Dictionary, ground: Callable) -> Array[float]:
	var at := Vector3(float(row["at"][0]), 0.0, float(row["at"][1]))
	var underside := _floor(ground, at) if row["y"] == null else float(row["y"])
	var reach := float(row["size"][0]) * 0.5 - END_INSET_M
	var gaps: Array[float] = []
	for side: float in [-1.0, 1.0]:
		var lowest := INF
		for across: float in [-1.0, 0.0, 1.0]:
			for along: float in [-1.0, 0.0, 1.0]:
				var spot := at + node.global_basis.z * (side * reach + along * END_SPAN_M) \
						+ node.global_basis.x * across * float(row["size"][2]) * 0.5
				lowest = minf(lowest, _floor(ground, spot))
		gaps.append(underside - lowest)
	return gaps


# Whether the footing mesh has any face at one end of the tower's length: side 0 the -z end, 1 the +z end.
func _has_end(view: MeshInstance3D, side: int) -> bool:
	var faces := view.mesh.get_faces()
	for corner in faces:
		if (corner.z < 0.0) == (side == 0):
			return true
	return false


func _row(stage: Node3D, id: String) -> Node3D:
	return stage.find_child("Park_" + id, true, false) as Node3D


func _check_tower(node: Node3D, space: PhysicsDirectSpaceState3D, ground: Callable, row: Dictionary) -> void:
	if not _t.check("the named tower is present", node != null):
		return
	var id := String(node.name)
	var body := node.get_node("Collider") as StaticBody3D
	var extra := body.get_node_or_null("Footings") as CollisionShape3D
	var view := node.get_node_or_null("Footings") as MeshInstance3D
	if not _t.check(id + " has a matching drawn and solid footing", extra != null and view != null):
		return
	var bounds := view.mesh.get_aabb()
	_t.check(id + " keeps the tower on the ground at its own spot", absf(node.global_position.y - _floor(ground, node.global_position)) < EPS)
	_t.check(id + " footing stays in the tower's footprint and below the grapple face",
		bounds.position.x > -2.0 and bounds.end.x < 2.0 and bounds.position.z > -6.0 and bounds.end.z < 6.0
		and bounds.end.y > 0.0 and bounds.end.y < 0.12, str(bounds))
	var collider := extra.shape as ConcavePolygonShape3D
	_t.check(id + " uses the drawn footing faces for collision", collider != null and collider.get_faces() == view.mesh.get_faces())
	var mid_z := bounds.get_center().z
	var largest_gap := -INF
	for i in 9:
		var x := lerpf(bounds.position.x, bounds.end.x, float(i) / 8.0)
		for k in 9:
			var z := lerpf(bounds.position.z, bounds.end.z, float(k) / 8.0)
			var at := node.to_global(Vector3(x, bounds.position.y, z))
			var floor: Vector3 = ground.call(at.x, at.z, 0.0)
			largest_gap = maxf(largest_gap, at.y - floor.y)
	_t.check(id + " footing reaches the baked ground across its base", largest_gap <= EPS, "highest gap %.3f m" % largest_gap)
	# This face is exposed on the -X side even where the bank rises in front of +X.
	var from := node.to_global(Vector3(-3.5, -0.12, mid_z))
	var to := node.to_global(Vector3(0.0, -0.12, mid_z))
	var ray := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Augments.WORLD_MASK))
	var drawn := _drawn_hit(view, from, to)
	_t.check(id + " the footing's exposed side reads the same to sight and physics", ray.get("collider") == body
		and drawn.is_finite() and drawn.distance_to(ray["position"]) < EPS, "ray %s draw %s" % [str(ray.get("position")), str(drawn)])
	var aim := node.to_global(Vector3(2.0, float(row["size"][1]) * 0.70, 0.0))
	var eye := aim + node.global_basis.x * 8.0
	var hit := Augments.grapple_target(space, eye, -node.global_basis.x, eye, 45.0, 0.0, Augments.WORLD_MASK, false)
	_t.check(id + " the grapple still hits the authored side at the original height", hit.state != Augments.AIM_NONE
		and (hit.point as Vector3).distance_to(aim) < EPS and (hit.normal as Vector3).dot(node.global_basis.x) > 0.99, str(hit))
	var recipe: String = node.get_meta("park_recipe")
	var base := node.get_node(recipe + "_body") as MeshInstance3D
	_t.check(id + " the footing follows the tower's visibility range", view.visibility_range_end == base.visibility_range_end
		and view.visibility_range_end_margin == base.visibility_range_end_margin and view.visibility_range_fade_mode == base.visibility_range_fade_mode)


func _drawn_hit(view: MeshInstance3D, from: Vector3, to: Vector3) -> Vector3:
	var faces := view.mesh.get_faces()
	var direction := (to - from).normalized()
	var closest := Vector3.INF
	var distance := from.distance_to(to)
	for i in range(0, faces.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(from, direction, view.to_global(faces[i]), view.to_global(faces[i + 1]), view.to_global(faces[i + 2]))
		if hit != null and from.distance_to(hit) < distance:
			closest = hit
			distance = from.distance_to(hit)
	return closest


# Crosses the tower on both sides of its middle, beside the end footings, with a ball at every height
# from the lowest ground across it up to the tower's underside, with the footing off and on. The
# footing must change none of those crossings. Returns [crossings swept, crossings the terrain leaves open].
func _check_underpass(tower: Node3D, space: PhysicsDirectSpaceState3D, ground: Callable) -> Array[int]:
	var footing := tower.get_node("Collider/Footings") as CollisionShape3D
	var ball := SphereShape3D.new()
	ball.radius = Tuning.RADIUS
	var queries: Array[PhysicsShapeQueryParameters3D] = []
	for z: float in [-CROSSING_Z_M, CROSSING_Z_M]:
		var from := tower.to_global(Vector3(CROSSING_HALF_M, 0.0, z))
		var to := tower.to_global(Vector3(-CROSSING_HALF_M, 0.0, z))
		var lowest := INF
		for step in CROSSING_SAMPLES + 1:
			lowest = minf(lowest, _floor(ground, from.lerp(to, float(step) / CROSSING_SAMPLES)))
		var y := lowest + ball.radius + CLEAR_M
		while y + ball.radius <= tower.global_position.y:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = ball
			query.collision_mask = Augments.WORLD_MASK
			query.transform = Transform3D(Basis.IDENTITY, Vector3(from.x, y, from.z))
			query.motion = to - from
			queries.append(query)
			y += CROSSING_STEP_M
	var candidate: Array[float] = []
	for query in queries:
		candidate.append(space.cast_motion(query)[0])
	footing.disabled = true
	await physics_frame
	await physics_frame
	var stock: Array[float] = []
	for query in queries:
		stock.append(space.cast_motion(query)[0])
	footing.disabled = false
	await physics_frame
	await physics_frame
	var open: Array[int] = []
	var changed: Array[float] = []
	for i in queries.size():
		if stock[i] >= 0.999:
			open.append(i)
		if absf(candidate[i] - stock[i]) >= EPS:
			changed.append(queries[i].transform.origin.y)
	if queries.is_empty():
		_t.skip("%s footing leaves its crossings as the terrain has them" % tower.name, "no ball height fits between the ground and the underside, so no crossing was swept")
	else:
		_t.check("%s footing leaves each of its %d crossings as the terrain has them" % [tower.name, queries.size()], changed.is_empty(), "changed at y %s" % [changed])
	var wall := StaticBody3D.new()
	wall.collision_layer = Augments.WORLD_MASK
	var shape := CollisionShape3D.new()
	var broad := BoxShape3D.new()
	broad.size = Vector3(4.0, 20.0, 12.0)
	shape.position.y = -10.0
	shape.shape = broad
	wall.add_child(shape)
	tower.add_child(wall)
	await physics_frame
	await physics_frame
	var passed := 0
	for i in open:
		if space.cast_motion(queries[i])[0] < stock[i] - 0.2:
			passed += 1
	if open.is_empty():
		_t.skip("control: filling the full tower footprint obstructs the open crossings of %s" % tower.name, "no crossing is open, so the control had nothing to stop")
	else:
		_t.check("control: filling the full tower footprint obstructs every open crossing of %s" % tower.name, passed == open.size(), "%d of %d" % [passed, open.size()])
	wall.free()
	return [queries.size(), open.size()]
