extends SceneTree

# W1-123. Check the real, placed level, including both sides of the piers and the shared
# foundations at the tile seams. --plant removes the foundations from the physics world.
const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Recipes := preload("res://src/world/park/park_recipes.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Footings := preload("res://src/world/park/footings.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_flume"}]}
const REACHES := ["flume_weir_reach", "flume_hollow_reach", "flume_head_reach"]
const PARK_FILE := "res://src/world/park/park_flume.json"
const LINES := "res://assets/park/park_flume/lines.json"
const LINE_STEP_M := 2.0
# How far past the outermost feet a step still counts as under the span: a foot's concrete flares out
# to about a metre, and the ball is wider than that again.
const SPAN_MARGIN_M := 6.0
const TILE_BODY_PREFIX := "flume_reach_120_body_tile"
# The trestle's feet are read from the placed steel itself: the vertices within FOOT_BAND_M of the mesh's
# lowest point, grouped when they lie within FOOT_JOIN_M of each other.
const FOOT_BAND_M := 0.3
const FOOT_JOIN_M := 1.0
# A footing's top meets a hanging leg when its highest face lies within LEG_MEET_TOL_M of the foot's
# height, looking only at faces within LEG_MEET_RADIUS_M of the foot.
const LEG_MEET_TOL_M := 0.25
const LEG_MEET_RADIUS_M := 1.0
# A footing yields to an authored line (Footings.fit's ridden callable): the soles a line passes near stay
# bare. This is the most a bare sole's footing could have reached: the table's widest base half-extent
# plus a ball's radius plus the clearance. Only a sole with no concrete near it and a line this close is exempt.
const BARE_REACH_M := 3.0
const BARE_TOLERANCE_M := 0.5
# The soles left bare because a line passes, as [world x, z]: a later map card can move these lines or legs.
const EXPECTED_BARE := [
	Vector2(-160.5, -477.6), Vector2(-151.8, -465.8), Vector2(-148.9, -472.6),
	Vector2(-23.4, 167.6), Vector2(-17.1, 163.8), Vector2(196.7, 445.1), Vector2(210.5, 450.4),
]
# The rivet step that sat just outside the old swept margin.
const RIVET_STEP := Vector2(-15.3, 162.6)
const KNOWN_TOLERANCE_M := 0.3
const TEST_LAYER := 1 << 30
const BALL_CLEARANCE_M := 0.1

var t := T.new("park_flume_piers_test")
var ground: Callable
var space: PhysicsDirectSpaceState3D
var park_data: Dictionary
# One entry per placed tile of every reach: {"node", "feet" (local), "stations" ([left, right] local),
# "to_local", "half_x", "z0", "z1"}.
var spans: Array = []
# The authored lines as resolved points, by line name.
var line_points := {}
# Soles with no footing because a line passes: [Vector2 x z, recipe, reach id].
var bare: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Planted fault: footings ignore the lines, so the line check must go red with the shut steps.
	Footings.plant_ignore_lines = "--plant-lines" in OS.get_cmdline_user_args()
	park_data = JSON.parse_string(FileAccess.get_file_as_string(PARK_FILE))
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
	var footings: Array[CollisionShape3D] = []
	for id: String in REACHES:
		var reach := park.find_child("Park_" + id, true, false) as Node3D
		var body := reach.get_node("Collider") as StaticBody3D
		t.check(id + " is on the world collision layer", body.collision_layer & Recipes.WORLD_LAYER != 0)
		body.collision_layer |= TEST_LAYER
		var solid := body.get_node_or_null("Footings") as CollisionShape3D
		if solid != null:
			footings.append(solid)
		reaches.append(reach)
		_read_tiles(reach)
	# Sweep the authored lines with the footings off first, then on: a line that was open must stay open.
	for solid in footings:
		solid.disabled = true
	await physics_frame
	await physics_frame
	var swept := _line_steps()
	var open_steps: Array = swept["open"]
	var planted := "--plant" in OS.get_cmdline_user_args()
	for solid in footings:
		solid.disabled = planted
	await physics_frame
	await physics_frame
	t.check("the footings sit in the world collision", footings.size() == REACHES.size())
	_check_lines(swept["under"], open_steps)
	for reach in reaches:
		_check_reach(reach)
	_check_bare()
	quit(t.verdict())


# The trestle's feet, read from each placed tile's own mesh: the lowest vertices, grouped into feet.
func _read_tiles(reach: Node3D) -> void:
	for node in reach.get_children():
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or not String(node.name).begins_with(TILE_BODY_PREFIX):
			continue
		var verts := PackedVector3Array()
		for surface in mesh_node.mesh.get_surface_count():
			verts.append_array(mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
		var low := INF
		for v in verts:
			low = minf(low, v.y)
		var clusters: Array[AABB] = []
		for v in verts:
			if v.y > low + FOOT_BAND_M:
				continue
			var joined := false
			for i in clusters.size():
				if clusters[i].grow(FOOT_JOIN_M).has_point(v):
					clusters[i] = clusters[i].expand(v)
					joined = true
					break
			if not joined:
				clusters.append(AABB(v, Vector3.ZERO))
		var feet: Array[Vector3] = []
		for box in clusters:
			feet.append(box.get_center())
		var stations: Array = []
		var half_x := 0.0
		var z0 := INF
		var z1 := -INF
		for foot in feet:
			half_x = maxf(half_x, absf(foot.x))
			z0 = minf(z0, foot.z)
			z1 = maxf(z1, foot.z)
			if foot.x >= 0.0:
				continue
			for other in feet:
				if other.x > 0.0 and absf(other.z - foot.z) < FOOT_JOIN_M:
					stations.append([foot, other])
		stations.sort_custom(func(a: Array, b: Array) -> bool: return a[0].z < b[0].z)
		spans.append({"reach": reach, "node": mesh_node, "feet": feet, "stations": stations,
				"to_local": mesh_node.global_transform.affine_inverse(), "half_x": half_x, "z0": z0, "z1": z1})


func _check_reach(reach: Node3D) -> void:
	var label := String(reach.name).trim_prefix("Park_")
	var view := reach.get_node_or_null("Footings") as MeshInstance3D
	var solid := reach.get_node_or_null("Collider/Footings") as CollisionShape3D
	if not t.check(label + " has one view and a collision shape for the foundations", view != null and solid != null):
		return
	var shape := solid.shape as ConcavePolygonShape3D
	t.check(label + " draws the same faces that collide", shape.get_faces() == view.mesh.get_faces() and solid.transform == view.transform)
	var base := reach.get_node("flume_reach_120_body_tile0") as MeshInstance3D
	t.check(label + " keeps the foundations for the deck's full visibility range", view.visibility_range_begin == base.visibility_range_begin
			and view.visibility_range_end == base.visibility_range_end
			and view.visibility_range_end_margin == base.visibility_range_end_margin)
	var faces := view.mesh.get_faces()
	var view_frame := reach.global_transform * view.transform
	var misses: Array[Vector3] = []
	var upper_misses: Array[Vector3] = []
	var clear_misses: Array[Vector3] = []
	var loose: Array[Vector3] = []
	var open_feet := 0
	var open_segments := 0
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + BALL_CLEARANCE_M
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = TEST_LAYER
	var previous := Vector3.INF
	for span: Dictionary in spans:
		if span["reach"] != reach:
			continue
		var frame: Transform3D = (span["node"] as MeshInstance3D).global_transform
		for pair: Array in span["stations"]:
			var left: Vector3 = frame * pair[0]
			var right: Vector3 = frame * pair[1]
			var centre := (left + right) * 0.5
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
			for sole: Vector3 in [left, right]:
				var floor_y := _floor(sole)
				if sole.y - floor_y <= Footings.OFF_GROUND_M:
					continue  # the existing leg has already entered the hillside
				var top := -INF
				for i in faces.size():
					var corner := view_frame * faces[i]
					if Vector2(corner.x - sole.x, corner.z - sole.z).length() <= LEG_MEET_RADIUS_M:
						top = maxf(top, corner.y)
				var at := Vector2(sole.x, sole.z)
				if top == -INF and _line_near(at, BARE_REACH_M):
					_note_bare(at, reach)
					continue  # the footing yielded to a line
				open_feet += 1
				var across := (sole - centre) * Vector3(1.0, 0.0, 1.0)
				across = across.normalized()
				var toe := Vector3(sole.x, floor_y + 0.15, sole.z)
				if not _hits(reach, toe - across * 2.0, toe):
					misses.append(toe)
				if not _hits(reach, sole - across * 2.0, sole):
					upper_misses.append(sole)
				if absf(top - sole.y) > LEG_MEET_TOL_M:
					loose.append(sole)
	t.check(label + " seats every exposed foot", open_feet > 0 and misses.is_empty(), "%d soles, gaps at %s" % [open_feet, misses])
	t.check(label + " reaches each original steel sole including paired bents", upper_misses.is_empty(), str(upper_misses))
	t.check(label + " tops each hanging leg within %.2f m of the foot" % LEG_MEET_TOL_M, loose.is_empty(), str(loose))
	t.check(label + " passes a ball between the foundations", open_segments > 0 and clear_misses.is_empty(),
			"%d spans, blocked at %s" % [open_segments, clear_misses])


func _line_near(at: Vector2, reach: float) -> bool:
	for line: String in line_points:
		var points: Array[Vector2] = line_points[line]
		for i in range(1, points.size()):
			if Geometry2D.get_closest_point_to_segment(at, points[i - 1], points[i]).distance_to(at) <= reach:
				return true
	return false


func _note_bare(at: Vector2, reach: Node3D) -> void:
	for entry: Array in bare:
		if (entry[0] as Vector2).distance_to(at) <= BARE_TOLERANCE_M:
			return
	var id := String(reach.name).trim_prefix("Park_")
	var recipe := ""
	for row: Dictionary in park_data["park_rows"]:
		if row.get("id") == id:
			recipe = String(row.get("recipe", ""))
	bare.append([at, recipe, id])


# The bare soles are pinned, so a new one (or one that gets its footing back) is a deliberate edit.
func _check_bare() -> void:
	var listed := bare.map(func(entry: Array) -> String: return "(%.1f, %.1f) %s on %s" % [entry[0].x, entry[0].y, entry[1], entry[2]])
	print("%d soles left bare because a line passes: %s" % [bare.size(), listed])
	if "--plant" in OS.get_cmdline_user_args():
		return
	var missing := EXPECTED_BARE.filter(func(spot: Vector2) -> bool:
		return not bare.any(func(entry: Array) -> bool: return (entry[0] as Vector2).distance_to(spot) <= BARE_TOLERANCE_M))
	t.check("the soles left bare because a line passes are the pinned ones", bare.size() == EXPECTED_BARE.size() and missing.is_empty(),
			"%d bare, pinned %d, pinned but footed %s, now: %s" % [bare.size(), EXPECTED_BARE.size(), missing, listed])


func _floor(at: Vector3) -> float:
	return (ground.call(at.x, at.z, 0.0) as Vector3).y


func _hits(reach: Node3D, from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to, TEST_LAYER)
	return space.intersect_ray(ray).get("collider") == reach.get_node("Collider")


# Every step of every authored ride line that lies under a trough span across the full width between the
# legs, as a ball resting on the ground: {"under": all such steps, "open": those open with the footings off}.
# A step is [from, to, line name]. Legs to and from named waypoints are walked too. The lines come from the
# park's own file, so a moved line is covered.
func _line_steps() -> Dictionary:
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LINES))
	var routes := {}
	for pilot: String in lines["pilots"]:
		routes[pilot] = lines["pilots"][pilot]["waypoints"]
	routes["floor"] = lines["floor"]["waypoints"]
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + BALL_CLEARANCE_M
	var under: Array = []
	var open: Array = []
	for line: String in routes:
		var points: Array[Vector2] = []
		for waypoint in routes[line]:
			var at := Vector2.INF
			if waypoint is Array:
				at = Vector2(waypoint[0], waypoint[1])
			elif waypoint is String:
				at = ParkMap.place_of(park_data, waypoint)
			if at != Vector2.INF:
				points.append(at)
		line_points[line] = points
		for k in range(1, points.size()):
			var count := ceili(points[k - 1].distance_to(points[k]) / LINE_STEP_M)
			var previous := Vector3.INF
			for n in count + 1:
				var xz := points[k - 1].lerp(points[k], float(n) / count)
				var at := Vector3(xz.x, _floor(Vector3(xz.x, 0.0, xz.y)) + sphere.radius, xz.y)
				if previous.is_finite() and _under_span(previous) and _under_span(at):
					under.append([previous, at, line])
					if not _blocked(sphere, previous, at):
						open.append([previous, at, line])
				previous = at
	return {"under": under, "open": open}


func _check_lines(under: Array, open_steps: Array) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS + BALL_CLEARANCE_M
	var shut: Array = []
	for step: Array in open_steps:
		if _blocked(sphere, step[0], step[1]):
			shut.append(step)
	print("swept %d steps under the trough spans, %d open with the footings off, %d shut with them on" % [under.size(), open_steps.size(), shut.size()])
	t.check("the authored lines have steps to sweep", open_steps.size() > 0)
	t.check("the sweep covers the rivet step near %s" % RIVET_STEP, open_steps.any(func(step: Array) -> bool:
		return step[2] == "rivet" and Vector2(step[1].x, step[1].z).distance_to(RIVET_STEP) <= KNOWN_TOLERANCE_M))
	t.check("the foundations leave every open step of the authored lines open", shut.is_empty(),
			"%d of %d steps blocked (%d under the spans), first at %s" % [shut.size(), open_steps.size(), under.size(),
			shut.map(_describe)])


func _describe(step: Array) -> String:
	return "(%.1f, %.1f) on %s" % [step[1].x, step[1].z, step[2]]


func _blocked(sphere: SphereShape3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = TEST_LAYER
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	return space.cast_motion(query)[0] < 1.0


# Under a span: between the legs' outer feet across, and between the first and last bent along, plus
# SPAN_MARGIN_M each way for the concrete that spreads past a foot.
func _under_span(at: Vector3) -> bool:
	for span: Dictionary in spans:
		var local: Vector3 = span["to_local"] * at
		if absf(local.x) <= span["half_x"] + SPAN_MARGIN_M and local.z >= span["z0"] - SPAN_MARGIN_M and local.z <= span["z1"] + SPAN_MARGIN_M:
			return true
	return false
