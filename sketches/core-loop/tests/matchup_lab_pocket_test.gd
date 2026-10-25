extends SceneTree
# 2026-10-23: the matchup lab's pocket arena (--pocket=<shape>, tools/pocket_arena.gd and tools/pocket_terrain.gd).
# For each of the five lab pockets: the glb loads as a collidable arena, the crevice's slick walls keep friction 0, the
# pilot's start rests on the pocket floor (a rigid ball dropped there stays on the floor ray), the terrain API the enemies
# and the driver call (height, drop_point, spawn_point, entry_heading) answers from the pocket and matches a direct ray at
# a few points, the rail grove's height ignores its overhead rails, and the pack's three spots stand on the floor.
# Evidence limit: headless Jolt and the pocket meshes only. Enemies on the arena are exercised by the lab's own smoke duels,
# not here.

const T := preload("res://tests/support/t.gd")
const Arena := preload("res://tools/pocket_arena.gd")
const PocketTerrain := preload("res://tools/pocket_terrain.gd")
const Director := preload("res://src/world/director.gd")

const BALL_R := 0.92
const GRAVITY := 26.0
const SETTLE_FRAMES := 45
const FLOOR_TOL := 0.06
const POINTS := [Vector2(6.0, 0.0), Vector2(14.0, -5.0), Vector2(20.0, 6.0), Vector2(27.0, 1.0)]

var _t := T.new("matchup_lab_pocket_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for shape in Arena.SHAPES:
		await _check_shape(shape)
	await _check_rail_grove()
	await _check_crevice_slick()
	quit(_t.verdict())


func _stand(shape: String) -> Dictionary:
	var holder := Node3D.new()
	root.add_child(holder)
	var arena := Arena.new()
	var ok := arena.build(holder, shape, Vector3(0.0, Arena.LIFT, 0.0))
	await physics_frame
	await physics_frame
	return {"holder": holder, "arena": arena, "ok": ok}


# The reference ray: straight down from over the pocket against the floor class, written out here rather than called
# through the arena.
func _ray(arena, x: float, z: float) -> float:
	var space := (arena.root.get_world_3d() as World3D).direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, arena.origin.y + 50.0, z), Vector3(x, arena.origin.y - 50.0, z), 1 << (Arena.HEIGHT_LAYER - 1))
	var hit := space.intersect_ray(query)
	return hit["position"].y if not hit.is_empty() else NAN


func _check_shape(shape: String) -> void:
	var stood := await _stand(shape)
	var arena = stood["arena"]
	if not _t.check("%s: the glb loads and gets colliders" % shape, stood["ok"] and arena.floor_meshes.size() > 0):
		stood["holder"].free()
		return
	_t.check("%s: footprint is the pocket's own (entry at x = 0, longer than 24 m)" % shape, arena.bounds.position.x <= 0.0 and arena.length() >= 24.0)

	# The pilot's start rests on the floor: drop a ball there and follow it. It must never sink under the floor ray at its
	# own x, z and must be touching the floor (within a few cm) after it settles. The start is already on the lane at x = 2.5.
	var start: Vector3 = arena.start_point()
	_t.check("%s: the start is at the entry on the lane" % shape, absf(start.x - (arena.origin.x + Arena.START_X)) < 0.001 and absf(start.z - (arena.origin.z + arena.lane_z())) < 0.001)
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	ball.gravity_scale = GRAVITY / 9.8
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_R
	collider.shape = sphere
	ball.add_child(collider)
	ball.collision_layer = 0
	ball.set_collision_layer_value(2, true)
	ball.collision_mask = 0
	ball.set_collision_mask_value(Arena.WORLD_LAYER, true)
	stood["holder"].add_child(ball)
	ball.global_position = start
	var lowest := 1e9
	for i in SETTLE_FRAMES:
		await physics_frame
		var floor_y := _ray(arena, ball.global_position.x, ball.global_position.z)
		lowest = minf(lowest, ball.global_position.y - BALL_R - floor_y)
	var final_gap: float = ball.global_position.y - BALL_R - _ray(arena, ball.global_position.x, ball.global_position.z)
	_t.check("%s: the ball dropped at the start never sinks under the floor (lowest gap %.3f m)" % [shape, lowest], lowest > -FLOOR_TOL)
	_t.check("%s: and rests on the floor (final gap %.3f m)" % [shape, final_gap], absf(final_gap) < 0.12)
	ball.free()

	# The terrain API answers from the pocket and agrees with the direct ray.
	var terrain = PocketTerrain.new()
	terrain.arena = arena
	var worst := 0.0
	var dropped := true
	for point in POINTS:
		var x: float = arena.origin.x + point.x
		var z: float = arena.origin.z + arena.lane_z() + point.y
		var want := _ray(arena, x, z)
		if is_nan(want):
			continue
		worst = maxf(worst, absf(terrain.height(x, z) - want))
		dropped = dropped and absf(terrain.drop_point(x, z, 1.8).y - (want + 1.8)) < 0.0001
	_t.check("%s: terrain.height matches a direct ray at %d points (worst %.5f m)" % [shape, POINTS.size(), worst], worst < 0.0001)
	_t.check("%s: terrain.drop_point is the ray height plus its clearance" % shape, dropped)
	_t.check("%s: spawn_point and entry_heading are the pocket's start and +x" % shape, terrain.spawn_point(1).is_equal_approx(start) and terrain.entry_heading(1).is_equal_approx(Vector3.RIGHT))
	_t.check("%s: contains holds on the footprint and fails far off, and a rescue returns the start" % shape,
		terrain.contains(start) and not terrain.contains(start + Vector3(500.0, 0.0, 0.0)) and terrain.rescue_point(start + Vector3(500.0, 0, 0)).is_equal_approx(start) and arena.rescues == 1)

	# The pack: three spots, each on the floor ray, distinct, on the far half.
	var spots: Array = arena.pack_spots(3, Director.PACK_SPREAD)
	var on_floor := spots.size() == 3
	var far := true
	for spot in spots:
		on_floor = on_floor and absf(spot.y - _ray(arena, spot.x, spot.z)) < 0.0001
		far = far and spot.x - arena.origin.x >= arena.length() * 0.5
	_t.check("%s: the pack's three spots stand on the floor in the far half" % shape, on_floor and far)
	_t.check("%s: and are %.1f m apart (a line across the lane, or in file where the lane is narrower)" % [shape, Director.PACK_SPREAD],
		is_equal_approx(Vector2(spots[0].x, spots[0].z).distance_to(Vector2(spots[1].x, spots[1].z)), Director.PACK_SPREAD))
	terrain = null
	stood["holder"].free()


# The rail grove's rails block bodies but not the height question: under a rail the height is the floor, not the rail.
const RAIL_GRID := 24


func _check_rail_grove() -> void:
	var stood := await _stand("rail_grove")
	var arena = stood["arena"]
	_t.check("rail_grove: it has overhead meshes (rails, posts, pillars) apart from its floor", arena.overhead_meshes.size() > 0 and arena.floor_meshes.size() > 0)
	var space := (arena.root.get_world_3d() as World3D).direct_space_state
	var checked := 0
	var under_all := true
	for mi in arena.overhead_meshes:
		if not String(mi.name).begins_with("rail") or String(mi.name).begins_with("rail_post"):
			continue
		# The rails may share one mesh (rail_pbr), whose box centre falls between them: sample a grid over the box.
		var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
		for i in RAIL_GRID:
			for j in RAIL_GRID:
				var x := box.position.x + box.size.x * (i + 0.5) / RAIL_GRID
				var z := box.position.z + box.size.z * (j + 0.5) / RAIL_GRID
				var full := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, arena.origin.y + 50.0, z), Vector3(x, arena.origin.y - 50.0, z), 1 << (Arena.WORLD_LAYER - 1)))
				if full.is_empty() or full["position"].y < arena.origin.y + 3.0:
					continue
				checked += 1
				under_all = under_all and arena.height(x, z) < arena.origin.y + 0.5
	_t.check("rail_grove: at least one rail sample hit", checked > 0)
	_t.check("rail_grove: a full-world ray hits the rail over 3 m up while terrain.height reads the floor under it (%d samples)" % checked, under_all and checked > 0)
	stood["holder"].free()


# The crevice's choke walls are slick (friction 0) and its floor keeps its grip; the other pockets have no slick body.
func _check_crevice_slick() -> void:
	var stood := await _stand("crevice")
	var arena = stood["arena"]
	var slick := 0
	var slick_ok := true
	var grip_ok := true
	for mi in arena.root.find_children("*", "MeshInstance3D", true, false):
		for child in mi.get_children():
			if child is StaticBody3D:
				var body := child as StaticBody3D
				var friction := body.physics_material_override.friction if body.physics_material_override != null else 1.0
				if String(mi.name).begins_with("slick"):
					slick += 1
					slick_ok = slick_ok and body.physics_material_override != null and friction == 0.0
				else:
					grip_ok = grip_ok and body.physics_material_override == null
	_t.check("crevice: the slick_* meshes (%d) have friction 0" % slick, slick >= 2 and slick_ok)
	_t.check("crevice: its other meshes keep the default grip", grip_ok)
	stood["holder"].free()
	var other := await _stand("half_pipe")
	_t.check("half_pipe: no slick body", (other["arena"] as Arena).slick_meshes.is_empty())
	other["holder"].free()
