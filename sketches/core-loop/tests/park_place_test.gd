extends SceneTree

# Rule (K-UNITS KB9, PARK.md 2.9 and section 4): a park stage built through terrain.gd places every park row that names
# a recipe (its GLB, or the greybox stand-in) under the stage root as Park_<id>, and no row whose recipe is "". A
# placed row whose ride fact is a WORLD_ROWS kind carries a "Ride" Area3D, and the game ball entering run_wash's
# sensor publishes ("ride_chute", at the ball) on the bus exactly once per entry. world.gd hands terrain the bus's
# world_fact.emit. A greybox anchor_field is a field of posts such that every point of its footprint on a 10 m
# lattice has a world aim hit within 40 m, probed as tools/traversal_line.gd _anchored probes; a planted 80 m pitch
# fails that. The test also records how each recipe's collider meets the stamped ground and the placed draw count
# (report only; KB6 gates draws). Evidence: artifacts/local/alpha/push/w13/place/park_place.json.
#
# 2026-10-11 (w13 KB9 round 3): the judged anchor set is explicit. A field lattice point inside another built row's
# footprint or its run-out (park_recipes.gd clear_zones footprints, ANCHOR_RUNOUT_M at ends and ANCHOR_SIDE_M at
# sides) is that row's to anchor and is left out of the judged set (the 06:47 w13-park ruling keeps that exclusion);
# so is a point inside a post. Every other point is judged, lane points (route legs and the waymarks chain) included
# and also counted on their own. The run prints and the report records the excluded counts beside the judged count.
# The bus is checked on its own, apart from any sensor: the terrain is the one World.setup builds on a stand-in context,
# its publish must be a valid Callable, and a probe fact sent through it must arrive once on ctx.events.world_fact.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RigidBall := preload("res://src/movement/rigid_ball.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const World := preload("res://src/world/world.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_test"}]}
const FRAMES_MAX := 3000
const LATTICE_M := 10.0
const GAP_BAND_M := 40.0
const ROPE_M := 45.0
const PROBE_SPOKES := 12
const PROBE_PITCHES := [0.0, 0.4, 0.8]
const PLANTED_PITCH_M := 80.0
const OUT := "res://../../artifacts/local/alpha/push/w13/place/park_place.json"
const HOLES := "res://assets/park/park_test/holes.bin"

var t := T.new("park_place_test")
var _heard: Array = []
# Untyped, so a method the base lacks is looked up at run time (red first).
var _recipes = load("res://src/world/park/park_recipes.gd")
var _runout := float((_recipes as Script).get_script_constant_map().get("ANCHOR_RUNOUT_M", 0.0))
var _side := float((_recipes as Script).get_script_constant_map().get("ANCHOR_SIDE_M", _runout))


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
	# The terrain is the one World.setup builds (world.gd), on a stand-in context with this test's bus, so the sensors
	# below publish through world.gd's own wiring.
	var ctx := StandInCtx.new()
	ctx.events = bus
	ctx.stages = StandInTable.new(TABLE["DEFS"])
	ctx.root = holder
	ctx.tuning = Tuning.new()
	ctx.player = StandInPlayer.new()
	holder.add_child(ctx.player)
	ctx.codex = StandInCodex.new()
	holder.add_child(ctx.codex)
	ctx.flow = StandInFlow.new()
	holder.add_child(ctx.flow)
	var world := World.new()
	holder.add_child(world)
	world.setup(ctx)
	var terrain = ctx.terrain
	terrain.use(1)

	# The bus, independent of any sensor: world.gd handed terrain a valid publish, and a fact sent through it reaches
	# the stand-in context's events.world_fact.
	var publish = terrain.get("publish")
	var bus_valid: bool = publish is Callable and (publish as Callable).is_valid()
	var probe := Vector3(-1234.5, 67.0, 890.25)
	_heard.clear()
	if bus_valid:
		(publish as Callable).call("ride_chute", probe)
	var probe_heard := _heard.filter(func(h: Array) -> bool: return h[0] == "ride_chute" and (h[1] as Vector3).is_equal_approx(probe))
	print("park_place_test: World.setup handed terrain publish %s; a probe fact through it heard %d times on ctx.events.world_fact" % [str(publish), probe_heard.size()])
	t.check("World.setup hands terrain a valid publish Callable", bus_valid, str(publish))
	t.eq("a fact through terrain.publish reaches ctx.events.world_fact once", probe_heard.size(), 1)
	_heard.clear()
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
		t.eq("the ball is on the ball layer the sensor hears", ball.collision_layer, PhysicsLayers.BALL_MASK)
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
	var blocked_points := 0
	var over_points := 0
	var over_list := []
	var lane_worst := 0.0
	var lane_at := Vector3.ZERO
	var lane_points := 0
	var lane_over := 0
	# A lattice point inside another built row's footprint or its run-out (the wash, the pool, the landmark; posts stand
	# ANCHOR_RUNOUT_M back) is that row's to anchor, not the field's: the fixture's fields are density placeholders laid
	# over the whole park (park_test.json). A point in a lane (park_recipes.gd clear_zones: route legs and the waymarks
	# chain) is judged like any other, by the lane's edge posts; the lane points are also counted on their own.
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
		if body == null or body.collision_layer != PhysicsLayers.WORLD_MASK:
			non_world.append(row["id"])
		var gaps := _field_gaps(space, row, floor_at, owned, lanes)
		points += gaps["points"]
		skipped_points += gaps["owned"]
		blocked_points += gaps["blocked"]
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
	print("park_place_test: %d anchor fields, %d posts; %d judged field lattice points (%d excluded as other rows' footprints or run-outs, %d inside posts), %d over 40 m, worst gap %.1f m at %s" % [fields, posts, points, skipped_points, blocked_points, over_points, worst, worst_at])
	print("park_place_test: %d points inside other rows' footprints or run-outs and %d inside posts left out; of the judged points %d in lanes, %d over 40 m, worst %.1f m at %s" % [skipped_points, blocked_points, lane_points, lane_over, lane_worst, lane_at])
	report["anchor"] = {"fields": fields, "posts": posts, "points": points, "judged_points": points, "excluded_points": skipped_points + blocked_points, "points_over_band": over_points, "over_at": over_list,
		"worst_gap_m": snappedf(worst, 0.1), "worst_at": [worst_at.x, worst_at.z], "points_in_other_rows": skipped_points, "points_inside_posts": blocked_points,
		"lane_points": lane_points, "lane_over_band": lane_over, "lane_worst_gap_m": snappedf(lane_worst, 0.1) if is_finite(lane_worst) else -1.0, "lane_worst_at": [lane_at.x, lane_at.z]}
	t.check("the fixture's anchor fields place posts", fields > 0 and posts > fields, "%d fields, %d posts" % [fields, posts])
	t.check("anchor posts are world-layer static bodies", non_world.is_empty(), str(non_world))
	t.check("every judged anchor-field lattice point has a world aim hit within 40 m", fields > 0 and points > 0 and worst <= GAP_BAND_M,
		"worst %.1f m at %s over %d judged points (%d left out in other rows' footprints or run-outs, %d inside posts)" % [worst, worst_at, points, skipped_points, blocked_points])
	t.check("every lane lattice point in a field has a world aim hit within 40 m", lanes.size() > 0 and lane_points > 0 and lane_worst <= GAP_BAND_M,
		"%d lanes, %d points, %d over, worst %.1f m at %s" % [lanes.size(), lane_points, lane_over, lane_worst, lane_at])

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

	# Holes (PARK.md section 3): a hole cell is the hole row's own (the tube's recipe); no other placed collider stands in
	# one. A planted post in a hole cell must turn the check red.
	var rows_node: Node = terrain.park_rows(1) if terrain.has_method("park_rows") else null
	var hole_ids := []
	for row: Dictionary in park["park_rows"]:
		if bool(row.get("hole", false)):
			hole_ids.append("Park_%s" % row["id"])
	var cells := _hole_cells()
	var intruders := _hole_intruders(space, rows_node, hole_ids, cells)
	print("park_place_test: %d hole cells; placed colliders in them: %s (hole rows %s)" % [cells.size(), str(intruders["by_row"]), str(hole_ids)])
	report["hole_cells"] = {"cells": cells.size(), "by_row": intruders["by_row"]}
	t.check("no placed collider but the hole row's own stands in a hole cell", rows_node != null and cells.size() > 700 and intruders["count"] == 0,
		"%d cells hit, %s" % [intruders["count"], str(intruders["by_row"])])
	if rows_node != null and not cells.is_empty():
		var plant := Node3D.new()
		plant.name = "Park_planted_hole_post"
		var plant_body := StaticBody3D.new()
		plant_body.collision_layer = PhysicsLayers.WORLD_MASK
		var plant_shape := CollisionShape3D.new()
		var plant_box := BoxShape3D.new()
		plant_box.size = Vector3(ParkRecipes.ANCHOR_POST_M, 40.0, ParkRecipes.ANCHOR_POST_M)
		plant_shape.shape = plant_box
		plant_body.add_child(plant_shape)
		plant.add_child(plant_body)
		rows_node.add_child(plant)
		var c: Vector2 = cells[cells.size() / 2]
		plant.global_position = Vector3(c.x, terrain.height(c.x, c.y), c.y)
		for n in 2:
			await physics_frame
		var planted_hits := _hole_intruders(space, rows_node, hole_ids, cells)
		print("park_place_test: planted post at %s: %s" % [str(c), str(planted_hits["by_row"])])
		t.check("a planted post in a hole cell turns the hole check red", planted_hits["by_row"].has(String(plant.name)), str(planted_hits["by_row"]))
		plant.free()
		await physics_frame

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
	var blocked := 0
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
			if not owned.is_empty() and _recipes.call("in_clear", owned, Vector2(p.x, p.z), _runout, _side):
				skipped += 1
				continue
			var from := Vector3(p.x, float(floor_at.call(p.x, p.z)) + Tuning.RADIUS, p.z)
			# A point inside a post is no place for the ball, and a ray cast from inside a box cannot see that box.
			var inside := PhysicsPointQueryParameters3D.new()
			inside.position = from
			inside.collision_mask = 1
			if not space.intersect_point(inside, 1).is_empty():
				blocked += 1
				continue
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
			points += 1
			if nearest > GAP_BAND_M:
				over += 1
				over_at.append([p.x, p.z])
			if nearest > worst:
				worst = nearest
				worst_at = from
	return {"worst": worst, "at": worst_at, "points": points, "owned": skipped, "blocked": blocked, "over": over, "over_at": over_at,
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
	var reading := ""
	if node.has_meta("stamp_replaces"):
		# The greybox stand-in of a stamped row (deck, lip, apron on the fixture) has no collider of its own: PARK.md
		# section 4 makes such a row "height stamp plus a recipe", the stamp is its shape, and the greybox box had
		# no lip or rim to add (park_recipes.gd place_row).
		kind = "replaced by its stamp (no solid)"
		reading = "PARK.md section 4 height-stamp-plus-recipe row: the greybox stand-in's Collider and Greybox are removed, the stamped ground is its collider"
	elif above > 0:
		kind = "lips above the stamped ground" if lip > 0.5 else "sits on the stamped ground"
	return {"recipe": row["recipe"], "stamp": row["stamp"], "glb": not _recipes.call("stands_in", row) if _has_static("stands_in") else false,
		"samples": samples, "recipe_on_top": above, "max_above_ground_m": snappedf(lip, 0.01), "reads": kind, "reading": reading}


# The hole cells' centres from the fixture's holes.bin (800 by 800 cells of 2 m from -800, park_holes_test.gd).
func _hole_cells() -> Array:
	var holes := FileAccess.get_file_as_bytes(HOLES)
	var out := []
	for k in holes.size():
		if holes[k] == 1:
			out.append(Vector2(-800.0 + 2.0 * (k % 800) + 1.0, -800.0 + 2.0 * (k / 800) + 1.0))
	return out


# Placed colliders (under rows_node) standing in a hole cell, the hole rows' own excepted: a column 1.8 m square and
# 1 km tall over each cell, counted by the Park_ row it belongs to.
func _hole_intruders(space: PhysicsDirectSpaceState3D, rows_node: Node, hole_ids: Array, cells: Array) -> Dictionary:
	var by_row := {}
	var count := 0
	if rows_node == null:
		return {"count": 0, "by_row": by_row}
	var column := BoxShape3D.new()
	column.size = Vector3(1.8, 1000.0, 1.8)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = column
	q.collision_mask = PhysicsLayers.WORLD_MASK
	for c: Vector2 in cells:
		q.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, 0.0, c.y))
		var hit := false
		for h: Dictionary in space.intersect_shape(q, 32):
			var walk: Node = h["collider"]
			while walk != null and walk.get_parent() != rows_node:
				walk = walk.get_parent()
			if walk == null or hole_ids.has(String(walk.name)):
				continue
			by_row[String(walk.name)] = int(by_row.get(String(walk.name), 0)) + 1
			hit = true
		if hit:
			count += 1
	return {"count": count, "by_row": by_row}


# The base has no runtime placement API, so the test reaches it by name and still loads there (red first).
func _has_static(method: String) -> bool:
	for m in (ParkRecipes as Script).get_script_method_list():
		if m["name"] == method:
			return true
	return false


# What World.setup reads from a context, with no game behind it (world.gd setup; game.gd fills the real one).
class StandInCtx:
	var events
	var stages
	var root: Node3D
	var player
	var tuning
	var codex
	var terrain
	var flow
	var run
	var rng := RandomNumberGenerator.new()
	var calm := true
	var dev := false


class StandInTable:
	var DEFS: Array

	func _init(defs: Array) -> void:
		DEFS = defs

	func of(stage: int) -> Dictionary:
		for row: Dictionary in DEFS:
			if int(row["stage"]) == stage:
				return row
		return {}

	func packs() -> Array:
		return StageDefs.packs()

	func elite() -> Dictionary:
		return StageDefs.elite()

	func elite_arrival() -> int:
		return StageDefs.elite_arrival()


class StandInPlayer extends Node3D:
	var interact_claim := Callable()

	func ball_position() -> Vector3:
		return global_position


# No run: no stage is in play, so the world modules' per-frame steps stand idle.
class StandInFlow extends Node:
	# StageLocks.setup (#420) hands itself to the flow as its gate.
	var gate = null

	func in_stage() -> bool:
		return false

	func stage() -> int:
		return 1

	func state_name() -> String:
		return "title"

	func calm() -> bool:
		return false

	func stage_def() -> Dictionary:
		return {}


class StandInCodex extends Node:
	func declare(_entry: Dictionary) -> void:
		pass


func _finish(report: Dictionary, holder: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, " ", false))
		f.close()
	holder.queue_free()
	await process_frame
	quit(t.verdict())
