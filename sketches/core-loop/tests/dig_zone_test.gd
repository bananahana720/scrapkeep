extends SceneTree

# The Dig greybox zone (map_dig.gd): ZoneSchema-valid; two tiers with the beacon at
# least 8 m below the spawn; every breach plate reads as the upper tier while its id is
# live and as its drop_to floor once erased; one plate drops with a ball on it the
# probe way (probe_dig_floor_drop_test.gd); the authored ground route from spawn to
# beacon never climbs over the bot's 0.5 grade and never crosses a plate; ZoneSeed is
# deterministic. Evidence limit: headless physics; no camera or feel claim.

const T := preload("res://tests/support/t.gd")
const DigMap := preload("res://src/world/map_dig.gd")
const ZoneSchema := preload("res://src/world/zone_schema.gd")
const ZoneSeed := preload("res://src/world/zone_seed.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const TOLERANCE := 0.3
const SETTLE_FRAMES := 120
const DROP_FRAMES := 120
const CLIMB_SLOPE := 0.5
const TIER_GAP := 8.0
# Spawn, down to the ramp head, down the ramp, across the lower tier to the beacon.
const ROUTE := [Vector2(0.0, -120.0), Vector2(0.0, -30.0), Vector2(0.0, 30.0), Vector2(20.0, 90.0)]


# Terrain takes only registered maps (terrain.gd _init), so this one fills its own row.
class DigTerrain extends "res://src/world/terrain.gd":
	func _init() -> void:
		super({"DEFS": []})
		maps.append(DigMap.new())
		_worlds.append(1)
		_roots.append(null)
		_heights.append(PackedFloat32Array())


func _initialize() -> void:
	_run()


func _run() -> void:
	var t := T.new("dig_zone_test")

	# (1) Schema.
	var issues := ZoneSchema.validate(DigMap.new())
	t.check("ZoneSchema.validate is empty", issues.is_empty(), str(issues))

	# (2) Tiers, built once.
	var world := Node3D.new()
	root.add_child(world)
	var terrain := DigTerrain.new()
	terrain.build(world)
	terrain.use(1)
	var m = terrain.map()
	var spawn_h := terrain.height(m.spawn.x, m.spawn.y)
	var beacon_h := terrain.height(m.beacon.x, m.beacon.y)
	t.check("spawn and beacon heights are finite", is_finite(spawn_h) and is_finite(beacon_h),
		"spawn %.3f, beacon %.3f" % [spawn_h, beacon_h])
	t.check("beacon is at least %.0f m below the spawn" % TIER_GAP, spawn_h - beacon_h >= TIER_GAP,
		"drop %.3f" % (spawn_h - beacon_h))

	# (3) Every plate: live cover reads upper, erased reads drop_to on the pit floor.
	t.check("three or more plates", m.breach_plates.size() >= 3, "%d plates" % m.breach_plates.size())
	for plate in m.breach_plates:
		var id: String = plate["id"]
		var r: Rect2 = plate["rect"]
		var drop_to: float = plate["drop_to"]
		t.check("%s: rect at least 8 m a side" % id, r.size.x >= 8.0 and r.size.y >= 8.0, str(r.size))
		t.check("%s: id in start_overlays" % id, m.start_overlays.has(id + "_before"), str(m.start_overlays))
		var floor_rect := r.grow(-DigMap.PIT_WALL)
		var points := [r.get_center(), floor_rect.position, floor_rect.end,
			Vector2(floor_rect.position.x, floor_rect.end.y), Vector2(floor_rect.end.x, floor_rect.position.y)]
		var covered := 0.0
		for p in points:
			covered = maxf(covered, absf(terrain.height(p.x, p.y) - DigMap.UPPER_H))
		var had: bool = terrain.overlays.has(id + "_before")
		terrain.overlays.erase(id + "_before")
		var dropped := 0.0
		for p in points:
			dropped = maxf(dropped, absf(terrain.height(p.x, p.y) - drop_to))
		if had:
			terrain.overlays.append(id + "_before")
		t.check("%s: upper tier while live" % id, covered <= 0.001, "worst gap %.4f" % covered)
		t.check("%s: drop_to %.1f once erased" % [id, drop_to], dropped <= 0.001, "worst gap %.4f" % dropped)

	# (4) The first plate drops with a ball on it.
	var plate0: Dictionary = m.breach_plates[0]
	var pid: String = plate0["id"]
	var centre: Vector2 = (plate0["rect"] as Rect2).get_center()
	var radius: float = Tuning.RADIUS
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.25
	ball.physics_material_override = material
	ball.gravity_scale = Tuning.new().f("gravity") / 9.8
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	ball.add_child(shape)
	ball.position = Vector3(centre.x, DigMap.UPPER_H + radius + 2.0, centre.y)
	world.add_child(ball)
	for i in SETTLE_FRAMES:
		await physics_frame
	var at := ball.global_position
	var upper := terrain.height(at.x, at.z)
	var gap_before := at.y - radius - upper
	t.check("%s: ball rests on the cover" % pid, absf(gap_before) <= TOLERANCE,
		"y %.3f, terrain.height %.3f, gap %.3f" % [at.y, upper, gap_before])
	terrain.overlays.erase(pid + "_before")
	m.apply_swap(pid, true)
	var reached := -1
	var gap := INF
	for frame in range(1, DROP_FRAMES + 1):
		await physics_frame
		at = ball.global_position
		gap = at.y - radius - terrain.height(at.x, at.z)
		if reached < 0 and absf(gap) <= TOLERANCE:
			reached = frame
	var lower := terrain.height(at.x, at.z)
	t.check("%s: ball reaches the pit floor within %d frames" % [pid, DROP_FRAMES], reached > 0 and lower < upper - 1.0,
		"first agreeing frame %d, terrain.height %.3f (was %.3f)" % [reached, lower, upper])
	t.check("%s: ball agrees with the floor at frame %d" % [pid, DROP_FRAMES], absf(gap) <= TOLERANCE,
		"y %.3f, terrain.height %.3f, gap %.3f" % [at.y, lower, gap])
	terrain.overlays.append(pid + "_before")
	m.apply_swap(pid, false)

	# (5) The ground route: sampled every 1 m, never uphill over the bot's grade, never on a plate.
	var worst_climb := -INF
	var on_plate := ""
	var prev_h := NAN
	for i in ROUTE.size() - 1:
		var a: Vector2 = ROUTE[i]
		var b: Vector2 = ROUTE[i + 1]
		var steps := int(ceil(a.distance_to(b)))
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps)
			var h := terrain.height(p.x, p.y)
			if not is_nan(prev_h):
				worst_climb = maxf(worst_climb, h - prev_h)
			prev_h = h
			for plate in m.breach_plates:
				if on_plate.is_empty() and DigMap._inside(plate["rect"], p.x, p.y):
					on_plate = "%s at %s" % [plate["id"], p]
	t.check("route never climbs over %.1f per m" % CLIMB_SLOPE, worst_climb <= CLIMB_SLOPE,
		"worst climb %.3f per m" % worst_climb)
	t.check("route never enters a plate rect", on_plate.is_empty(), on_plate if not on_plate.is_empty() else "clear")

	# (6) ZoneSeed is deterministic.
	var seeded_a := var_to_str(ZoneSeed.fill(DigMap.new(), 7))
	var seeded_b := var_to_str(ZoneSeed.fill(DigMap.new(), 7))
	t.check("ZoneSeed.fill(map, 7) is stable", seeded_a == seeded_b, "%d and %d chars" % [seeded_a.length(), seeded_b.length()])

	world.free()
	quit(t.verdict())
