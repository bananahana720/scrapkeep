extends SceneTree

# W1-123. Check the real, placed level, including both sides of the piers and the shared
# foundations at the tile seams. --plant removes the foundations from the physics world.
const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Recipes := preload("res://src/world/park/park_recipes.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_flume"}]}
const REACHES := ["flume_weir_reach", "flume_hollow_reach", "flume_head_reach"]
const BENT_STATIONS := [0.35, 12.0, 24.0, 36.0, 48.0, 60.0, 72.0, 84.0, 96.0, 108.0, 119.65]
const TEST_LAYER := 1 << 30
const BALL_CLEARANCE_M := 0.1

var t := T.new("park_flume_piers_test")
var ground: Callable
var space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var park := Node3D.new()
	root.add_child(park)
	var camera := Camera3D.new()
	park.add_child(camera)
	camera.make_current()
	var terrain := Terrain.new(TABLE)
	terrain.build(park)
	terrain.use(1)
	ground = terrain.ground_callable(1)
	space = park.get_world_3d().direct_space_state
	var reaches: Array[Node3D] = []
	for id: String in REACHES:
		var reach := park.find_child("Park_" + id, true, false) as Node3D
		var body := reach.get_node("Collider") as StaticBody3D
		t.check(id + " is on the world collision layer", body.collision_layer & Recipes.WORLD_LAYER != 0)
		body.collision_layer |= TEST_LAYER
		if "--plant" in OS.get_cmdline_user_args():
			(body.get_node("Piers") as CollisionShape3D).disabled = true
		reaches.append(reach)
	await physics_frame
	await physics_frame
	for reach in reaches:
		_check_reach(reach)
	quit(t.verdict())


func _check_reach(reach: Node3D) -> void:
	var label := String(reach.name).trim_prefix("Park_")
	var view := reach.get_node_or_null("Piers") as MeshInstance3D
	var solid := reach.get_node_or_null("Collider/Piers") as CollisionShape3D
	if not t.check(label + " has one view and a collision shape for the foundations", view != null and solid != null):
		return
	var shape := solid.shape as ConcavePolygonShape3D
	t.check(label + " draws the same faces that collide", shape.get_faces() == view.mesh.get_faces() and solid.transform == view.transform)
	var base := reach.get_node("flume_reach_120_body_tile0") as MeshInstance3D
	t.check(label + " keeps the foundations for the deck's full visibility range", view.visibility_range_begin == base.visibility_range_begin
			and view.visibility_range_end == base.visibility_range_end
			and view.visibility_range_end_margin == base.visibility_range_end_margin)
	var misses: Array[Vector3] = []
	var upper_misses: Array[Vector3] = []
	var clear_misses: Array[Vector3] = []
	var open_feet := 0
	var open_segments := 0
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + BALL_CLEARANCE_M
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = TEST_LAYER
	var previous := Vector3.INF
	for tile: Transform3D in reach.get_meta("tile_fit"):
		var frame := reach.global_transform * tile
		for z: float in BENT_STATIONS:
			var centre := frame * Vector3(0.0, -6.0, z)
			var rider_y := _floor(centre) + sphere.radius
			if rider_y + sphere.radius < centre.y:
				centre.y = rider_y
				if previous.is_finite():
					query.transform = Transform3D(Basis.IDENTITY, previous)
					query.motion = centre - previous
					if space.cast_motion(query)[0] < 1.0:
						clear_misses.append(centre)
					open_segments += 1
				previous = centre
			else:
				previous = Vector3.INF  # the hillside meets the steel here
			for side: float in [-1.0, 1.0]:
				var sole := frame * Vector3(side * 3.7, -6.0, z)
				var floor_y := _floor(sole)
				if sole.y - floor_y < 0.3:
					continue  # the existing leg has already entered the hillside
				open_feet += 1
				var across := frame.basis.x * side
				var toe := Vector3(sole.x, floor_y + 0.15, sole.z)
				if not _hits(reach, toe - across * 2.0, toe):
					misses.append(toe)
				if not _hits(reach, sole - across * 2.0, sole):
					upper_misses.append(sole)
	t.check(label + " seats every exposed foot", open_feet > 0 and misses.is_empty(), "%d soles, gaps at %s" % [open_feet, misses])
	t.check(label + " reaches each original steel sole including paired bents", upper_misses.is_empty(), str(upper_misses))
	t.check(label + " passes a ball between the foundations", open_segments > 0 and clear_misses.is_empty(),
			"%d spans, blocked at %s" % [open_segments, clear_misses])


func _floor(at: Vector3) -> float:
	return (ground.call(at.x, at.z, 0.0) as Vector3).y


func _hits(reach: Node3D, from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to, TEST_LAYER)
	return space.intersect_ray(ray).get("collider") == reach.get_node("Collider")
