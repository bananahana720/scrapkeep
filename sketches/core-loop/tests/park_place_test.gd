extends SceneTree

# Rule (K-UNITS KB9, PARK.md 2.9 and section 4): a park stage built through terrain.gd places every park row that names
# a recipe (its GLB, or the greybox stand-in) under the stage root as Park_<id>, and no row whose recipe is "". A
# placed row whose ride fact is a WORLD_ROWS kind carries a "Ride" Area3D, and the game ball entering run_wash's
# sensor publishes ("ride_chute", at the ball) on the bus exactly once per entry. world.gd hands terrain the bus's
# world_fact.emit. A greybox anchor_field is a field of posts such that every point of its footprint on a 10 m
# lattice has a world aim hit within 40 m, probed as tools/traversal_line.gd _anchored probes; a planted 80 m pitch
# fails that. The test also records how each recipe's collider meets the stamped ground and the placed draw count
# (report only; KB6 gates draws). Evidence: artifacts/local/alpha/push/w13/place/park_place.json.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RigidBall := preload("res://src/movement/rigid_ball.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_test"}]}
const FRAMES_MAX := 3000
const LATTICE_M := 10.0
const GAP_BAND_M := 40.0
const ROPE_M := 45.0
const PROBE_SPOKES := 12
const PROBE_PITCHES := [0.0, 0.4, 0.8]
const PLANTED_PITCH_M := 80.0
const OUT := "res://../../artifacts/local/alpha/push/w13/place/park_place.json"

var t := T.new("park_place_test")
var _heard: Array = []
# Untyped, so a method the base lacks is looked up at run time (red first).
var _recipes = load("res://src/world/park/park_recipes.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	var bus = GameEvents.new()
	holder.add_child(bus)
	bus.world_fact.connect(func(kind: String, at: Vector3) -> void: _heard.append([kind, at]))
	var terrain = Terrain.new(TABLE)
	if "publish" in terrain:
		terrain.publish = bus.world_fact.emit
	terrain.build(holder)
	terrain.use(1)
	var frames := 0
	var limit := FRAMES_MAX if terrain.has_method("rows_ready") else 30
	while frames < limit and not (terrain.has_method("rows_ready") and terrain.rows_ready(1)):
		await process_frame
		frames += 1
	for n in 3:
		await physics_frame
	var stage_root: Node3D = terrain.geometry_root(1)
	var park: Dictionary = terrain.map_for(1).park
	var report := {"frames_to_place": frames}

	# Every row naming a recipe has a node; a row with recipe "" has none.
	var placed := 0
	var missing := []
	var stray := []
	var sensors := 0
	var sensors_missing := []
	var nodes := {}
	for row: Dictionary in park["park_rows"]:
		var node := stage_root.find_child("Park_%s" % row["id"], true, false) as Node3D
		if String(row["recipe"]) == "":
			if node != null:
				stray.append(row["id"])
			continue
		if node == null:
			missing.append(row["id"])
			continue
		placed += 1
		nodes[row["id"]] = node
		if EventKinds.WORLD_ROWS.has(String(row["ride_fact"])):
			if node.get_node_or_null("Ride") is Area3D:
				sensors += 1
			else:
				sensors_missing.append(row["id"])
	var want := (park["park_rows"] as Array).filter(func(r: Dictionary) -> bool: return String(r["recipe"]) != "").size()
	print("park_place_test: %d of %d recipe rows placed after %d frames, %d ride sensors" % [placed, want, frames, sensors])
	report["placed"] = placed
	report["recipe_rows"] = want
	report["sensors"] = sensors
	t.check("every row naming a recipe is placed under the stage root", placed == want and missing.is_empty(), "%d of %d, missing %s" % [placed, want, missing])
	t.check("no row with recipe \"\" places anything", stray.is_empty(), str(stray))
	t.check("every placed WORLD_ROWS ride row carries a Ride sensor", sensors_missing.is_empty() and sensors > 0, "%d sensors, missing %s" % [sensors, sensors_missing])
	var world_src := FileAccess.get_file_as_string("res://src/world/world.gd")
	t.check("world.gd hands terrain the bus's world_fact.emit before build", world_src.contains("terrain.publish = ctx.events.world_fact.emit"))
	if placed == 0:
		_finish(report, holder)
		return

	# The game ball entering run_wash's sensor publishes ride_chute once per entry, at the ball.
	var wash: Node3D = nodes.get("run_wash")
	var area := wash.get_node_or_null("Ride") as Area3D if wash != null else null
	if t.check("run_wash has its Ride sensor", area != null):
		var box := area.get_child(0) as CollisionShape3D
		var inside: Vector3 = box.global_position
		var outside := inside + Vector3.UP * 80.0
		var ball := RigidBall.new()
		ball.setup(null, {"velocity": Vector3.ZERO})
		holder.add_child(ball)
		ball.set_active(true)
		ball.gravity_scale = 0.0
		t.eq("the ball is on the ball layer the sensor hears", ball.collision_layer, 1 << (ParkRecipes.BALL_LAYER - 1))
		ball.teleport(outside, Vector3.ZERO)
		for n in 4:
			await physics_frame
		_heard.clear()
		ball.teleport(inside, Vector3.ZERO)
		for n in 6:
			await physics_frame
		var first := _heard.duplicate()
		ball.teleport(outside, Vector3.ZERO)
		for n in 6:
			await physics_frame
		ball.teleport(inside, Vector3.ZERO)
		for n in 6:
			await physics_frame
		var chutes := _heard.filter(func(h: Array) -> bool: return h[0] == "ride_chute")
		print("park_place_test: heard %s" % str(_heard))
		t.check("one entry publishes ride_chute once on the bus", first.size() == 1 and first[0][0] == "ride_chute", str(first))
		t.check("the fact is at the ball", first.size() == 1 and (first[0][1] as Vector3).distance_to(inside) < 1.0, str(first))
		t.eq("a second entry publishes once more", chutes.size(), 2)
		report["sensor_events"] = _heard.size()
		ball.queue_free()

	# Anchor fields: the worst gap from any 10 m lattice point to a world aim hit, probed as traversal_line.gd does.
	var space := holder.get_world_3d().direct_space_state
	var floor_at := func(x: float, z: float) -> float: return terrain.height(x, z)
	var worst := 0.0
	var worst_at := Vector3.ZERO
	var fields := 0
	var posts := 0
	var points := 0
	var non_world := []
	var skipped_points := 0
	var over_points := 0
	var over_list := []
	var lane_worst := 0.0
	var lane_at := Vector3.ZERO
	var lane_points := 0
	var lane_over := 0
	# A lattice point inside another built row's footprint (the wash, the pool, the landmark) is that row's to anchor,
	# not the field's: the fixture's fields are density placeholders laid over the whole park (park_test.json). A point
	# in a route lane (park_recipes.gd clear_zones) is the line's; its gap is reported here and judged by the sweep's
	# max_anchor_gap_m, since posts may not stand in a lane.
	var zones: Array = _recipes.call("clear_zones", park) if _has_static("clear_zones") else []
	var owned: Array = zones.filter(func(z: Dictionary) -> bool: return not z.has("a"))
	var lanes: Array = zones.filter(func(z: Dictionary) -> bool: return z.has("a"))
	for row: Dictionary in park["park_rows"]:
		if String(row["recipe"]) != "greybox:anchor_field" or not nodes.has(row["id"]):
			continue
		fields += 1
		var node: Node3D = nodes[row["id"]]
		posts += int(node.get_meta("anchor_posts", 0))
		var body := node.get_node_or_null("Collider") as StaticBody3D
		if body == null or body.collision_layer != 1 << (ParkRecipes.WORLD_LAYER - 1):
			non_world.append(row["id"])
		var gaps := _field_gaps(space, row, floor_at, owned, lanes)
		points += gaps["points"]
		skipped_points += gaps["owned"]
		over_points += gaps["over"]
		over_list.append_array(gaps["over_at"])
		lane_points += gaps["lane_points"]
		lane_over += gaps["lane_over"]
		if gaps["worst"] > worst:
			worst = gaps["worst"]
			worst_at = gaps["at"]
		if gaps["lane_worst"] > lane_worst:
			lane_worst = gaps["lane_worst"]
			lane_at = gaps["lane_at"]
	print("park_place_test: %d anchor fields, %d posts; %d field lattice points, %d over 40 m, worst gap %.1f m at %s" % [fields, posts, points, over_points, worst, worst_at])
	print("park_place_test: %d points inside other rows' footprints left out; %d route-lane points, %d over 40 m, worst %.1f m at %s (report)" % [skipped_points, lane_points, lane_over, lane_worst, lane_at])
	report["anchor"] = {"fields": fields, "posts": posts, "points": points, "points_over_band": over_points, "over_at": over_list,
		"worst_gap_m": snappedf(worst, 0.1), "worst_at": [worst_at.x, worst_at.z], "points_in_other_rows": skipped_points,
		"lane_points": lane_points, "lane_over_band": lane_over, "lane_worst_gap_m": snappedf(lane_worst, 0.1) if is_finite(lane_worst) else -1.0, "lane_worst_at": [lane_at.x, lane_at.z]}
	t.check("the fixture's anchor fields place posts", fields > 0 and posts > fields, "%d fields, %d posts" % [fields, posts])
	t.check("anchor posts are world-layer static bodies", non_world.is_empty(), str(non_world))
	t.check("every anchor-field lattice point has a world aim hit within 40 m", fields > 0 and points > 0 and worst <= GAP_BAND_M, "worst %.1f m at %s over %d points" % [worst, worst_at, points])

	# A planted 80 m post pitch, on a flat plain far off the stage, must fail the same probe.
	var far := Node3D.new()
	holder.add_child(far)
	var planted_row := {"id": "planted", "element": "anchor_field", "at": [5000.0, 5000.0], "y": null, "size": [210, 14, 210],
		"yaw_deg": 0, "ride_fact": "", "recipe": "greybox:anchor_field", "stamp": "", "budget": "park_large"}
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var planted = _recipes.call("place_anchor_field", planted_row, far, flat, [], PLANTED_PITCH_M) if _has_static("place_anchor_field") else null
	for n in 3:
		await physics_frame
	var planted_gap := INF
	if planted != null:
		planted_gap = _field_gaps(space, planted_row, flat)["worst"]
	print("park_place_test: planted %d m pitch, worst gap %.1f m" % [PLANTED_PITCH_M, planted_gap])
	report["planted_80m_worst_gap_m"] = planted_gap if is_finite(planted_gap) else -1.0
	t.check("a planted 80 m post pitch fails the 40 m gap", planted != null and planted_gap > GAP_BAND_M, "worst %.1f m" % planted_gap)
	far.queue_free()

	# How each recipe's collider meets the stamped ground (report): down-rays over the footprint every 4 m; a ray
	# whose first world hit is the row's own collider counts as the recipe standing above the ground there.
	var meets := {}
	for row: Dictionary in park["park_rows"]:
		if not nodes.has(row["id"]) or String(row["element"]) == "anchor_field":
			continue
		meets[row["id"]] = _meets(space, row, nodes[row["id"]], floor_at)
	report["meets"] = meets
	for id in meets:
		print("park_place_test: %s %s" % [id, str(meets[id])])

	# Draws (report; PARK.md section 9 caps the p1 scene at 1,400 and each recipe class has its own).
	var draws := 0
	var by_row := {}
	for id in nodes:
		var n := 0
		for view: MeshInstance3D in (nodes[id] as Node).find_children("*", "MeshInstance3D", true, false):
			n += view.mesh.get_surface_count() if view.mesh != null else 0
		n += (nodes[id] as Node).find_children("*", "MultiMeshInstance3D", true, false).size()
		by_row[id] = n
		draws += n
	print("park_place_test: placed draws %d (PARK.md section 9: 1,400 a scene on p1), by row %s" % [draws, str(by_row)])
	report["draws"] = draws
	report["draws_by_row"] = by_row
	_finish(report, holder)


# The worst nearest world-aim hit over a row's footprint lattice: from the ball's centre above the floor, 12 spokes at
# three pitches, the rope's reach, no assist, walkable faces refused (traversal_line.gd _anchored).
func _field_gaps(space: PhysicsDirectSpaceState3D, row: Dictionary, floor_at: Callable, owned: Array = [], lanes: Array = []) -> Dictionary:
	var yaw := deg_to_rad(float(row["yaw_deg"]))
	var along := Vector3(sin(yaw), 0.0, cos(yaw))
	var across := Vector3(cos(yaw), 0.0, -sin(yaw))
	var centre := Vector3(float(row["at"][0]), 0.0, float(row["at"][1]))
	var half_l := float(row["size"][0]) * 0.5
	var half_w := float(row["size"][2]) * 0.5
	var worst := 0.0
	var worst_at := centre
	var points := 0
	var skipped := 0
	var over := 0
	var over_at := []
	var lane_worst := 0.0
	var lane_at := centre
	var lane_points := 0
	var lane_over := 0
	var ni := int(floor(half_w / LATTICE_M))
	var nj := int(floor(half_l / LATTICE_M))
	for i in range(-ni, ni + 1):
		for j in range(-nj, nj + 1):
			var p := centre + across * (i * LATTICE_M) + along * (j * LATTICE_M)
			if not owned.is_empty() and _recipes.call("in_clear", owned, Vector2(p.x, p.z), 0.0):
				skipped += 1
				continue
			var from := Vector3(p.x, float(floor_at.call(p.x, p.z)) + Tuning.RADIUS, p.z)
			var nearest := INF
			for pitch in PROBE_PITCHES:
				for s in PROBE_SPOKES:
					var a := TAU * float(s) / float(PROBE_SPOKES)
					var dir := Vector3(sin(a) * cos(pitch), sin(pitch), cos(a) * cos(pitch))
					var hit: Dictionary = Augments.grapple_target(space, from, dir, from, ROPE_M, 0.0, Augments.WORLD_MASK, false)
					if int(hit.get("state", Augments.AIM_NONE)) in [Augments.AIM_REACH, Augments.AIM_ASSIST]:
						nearest = minf(nearest, from.distance_to(hit["point"]))
			if not lanes.is_empty() and _recipes.call("in_clear", lanes, Vector2(p.x, p.z), 0.0):
				lane_points += 1
				if nearest > GAP_BAND_M:
					lane_over += 1
				if nearest > lane_worst:
					lane_worst = nearest
					lane_at = from
				continue
			points += 1
			if nearest > GAP_BAND_M:
				over += 1
				over_at.append([p.x, p.z])
			if nearest > worst:
				worst = nearest
				worst_at = from
	return {"worst": worst, "at": worst_at, "points": points, "owned": skipped, "over": over, "over_at": over_at,
		"lane_worst": lane_worst, "lane_at": lane_at, "lane_points": lane_points, "lane_over": lane_over}


func _meets(space: PhysicsDirectSpaceState3D, row: Dictionary, node: Node3D, floor_at: Callable) -> Dictionary:
	var body := node.get_node_or_null("Collider")
	var yaw := deg_to_rad(float(row["yaw_deg"]))
	var along := Vector3(sin(yaw), 0.0, cos(yaw))
	var across := Vector3(cos(yaw), 0.0, -sin(yaw))
	var centre := Vector3(float(row["at"][0]), 0.0, float(row["at"][1]))
	var half_l := float(row["size"][0]) * 0.5
	var half_w := float(row["size"][2]) * 0.5
	var samples := 0
	var above := 0
	var lip := 0.0
	var step := 4.0
	var u := -half_l
	while u <= half_l:
		var v := -half_w
		while v <= half_w:
			var p := centre + along * u + across * v
			var g := float(floor_at.call(p.x, p.z))
			var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, g + 80.0, p.z), Vector3(p.x, g - 40.0, p.z), 1)
			var hit := space.intersect_ray(q)
			samples += 1
			if not hit.is_empty() and hit["collider"] == body:
				above += 1
				lip = maxf(lip, (hit["position"] as Vector3).y - g)
			v += step
		u += step
	var kind := "under or inside the stamped ground"
	if above > 0:
		kind = "lips above the stamped ground" if lip > 0.5 else "sits on the stamped ground"
	return {"recipe": row["recipe"], "stamp": row["stamp"], "glb": not _recipes.call("stands_in", row) if _has_static("stands_in") else false,
		"samples": samples, "recipe_on_top": above, "max_above_ground_m": snappedf(lip, 0.01), "reads": kind}


# The base has no runtime placement API, so the test reaches it by name and still loads there (red first).
func _has_static(method: String) -> bool:
	for m in (ParkRecipes as Script).get_script_method_list():
		if m["name"] == method:
			return true
	return false


func _finish(report: Dictionary, holder: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, " ", false))
		f.close()
	holder.queue_free()
	await process_frame
	quit(t.verdict())
