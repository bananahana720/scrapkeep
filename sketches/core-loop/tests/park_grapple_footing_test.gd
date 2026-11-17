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
const TOWERS := {
	"flume_ride_pier_3": [50.0, 87.0], "flume_ride_pier_34": [50.0, 138.977],
	"bluff_ride_pier_9": [28.0, 8.0], "bluff_ride_pier_19": [28.0, 8.0], "bluff_ride_pier_21": [28.0, 8.0],
}
const UNCHANGED := ["bluff_ride_pier_11", "bluff_ride_pier_13", "flume_ride_pier_25", "flume_head_reach", "flume_weir_reach"]
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
	for id: String in TOWERS:
		_check_tower(_row(stage, id), space, ground, TOWERS[id])
	for id: String in UNCHANGED:
		var node := _row(stage, id)
		_t.check("%s keeps its own support" % id, node != null
			and not node.has_node("GrappleFooting") and not node.has_node("Collider/GrappleFooting"))
	await _check_underpass(_row(stage, "flume_ride_pier_3"), space, -16.8, 3.13, false)
	await _check_underpass(_row(stage, "bluff_ride_pier_21"), space, -4.75, -3.13, true)
	game.free()
	quit(_t.verdict())


func _row(stage: Node3D, id: String) -> Node3D:
	return stage.find_child("Park_" + id, true, false) as Node3D


func _check_tower(node: Node3D, space: PhysicsDirectSpaceState3D, ground: Callable, heights: Array) -> void:
	if not _t.check("the named tower is present", node != null):
		return
	var id := String(node.name)
	var body := node.get_node("Collider") as StaticBody3D
	var extra := body.get_node_or_null("GrappleFooting") as CollisionShape3D
	var view := node.get_node_or_null("GrappleFooting") as MeshInstance3D
	if not _t.check(id + " has a matching drawn and solid footing", extra != null and view != null):
		return
	var bounds := view.mesh.get_aabb()
	_t.check(id + " keeps the tower at its previous height", absf(node.global_position.y - float(heights[1])) < EPS)
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
	var aim := node.to_global(Vector3(2.0, float(heights[0]) * 0.70, 0.0))
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


func _check_underpass(tower: Node3D, space: PhysicsDirectSpaceState3D, height: float, z: float, open: bool) -> void:
	if tower == null or not tower.has_node("Collider/GrappleFooting"):
		return
	var footing := tower.get_node("Collider/GrappleFooting") as CollisionShape3D
	var ball := SphereShape3D.new()
	ball.radius = Tuning.RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.collision_mask = Augments.WORLD_MASK
	query.transform = Transform3D(Basis.IDENTITY, tower.to_global(Vector3(3.3, height, z)))
	query.motion = tower.global_basis * Vector3(-6.6, 0.0, 0.0)
	var candidate := space.cast_motion(query)[0]
	footing.disabled = true
	await physics_frame
	await physics_frame
	var stock := space.cast_motion(query)[0]
	footing.disabled = false
	var expected := stock >= 0.999 if open else stock > 0.8 and stock < 0.999
	_t.check("%s keeps the same ball-size crossing beside its footing" % tower.name,
		expected and absf(candidate - stock) < EPS,
		"candidate %.4f stock %.4f" % [candidate, stock])
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
	_t.check("control: filling the full tower footprint obstructs the same crossing", space.cast_motion(query)[0] < stock - 0.2)
	wall.free()
