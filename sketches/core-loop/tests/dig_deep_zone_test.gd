extends SceneTree

# The deep Dig greybox zone (map_dig_deep.gd): ZoneSchema-valid; three tiers at least 8 m
# apart; every breach plate reads as its own tier while its id is live and as its drop_to
# floor once erased; the first middle-tier plate drops with a ball on it (dig_zone_test.gd
# way); the authored ground route from spawn to beacon never climbs over the bot's 0.5 grade
# and never crosses a plate; ZoneSeed is deterministic; spawn and beacon are its own, not the
# first Dig's. Evidence limit: headless physics; no camera or feel claim.

const T := preload("res://tests/support/t.gd")
const DigMap := preload("res://src/world/map_dig.gd")
const DeepMap := preload("res://src/world/map_dig_deep.gd")
const ZoneSchema := preload("res://src/world/zone_schema.gd")
const ZoneSeed := preload("res://src/world/zone_seed.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const TOLERANCE := 0.3
const SETTLE_FRAMES := 120
const DROP_FRAMES := 120
const CLIMB_SLOPE := 0.5
const TIER_GAP := 8.0
# Spawn, down the first ramp, across the middle tier, down the second ramp, to the beacon.
const ROUTE := [Vector2(-24.0, -128.0), Vector2(0.0, -30.0), Vector2(0.0, 30.0), Vector2(40.0, 40.0),
	Vector2(40.0, 100.0), Vector2(40.0, 130.0)]
# A flat middle-tier point off the plates and ramps: the ambush altar.
const MIDDLE_POINT := Vector2(-110.0, 40.0)


# Terrain takes only registered maps (terrain.gd _init), so this one fills its own row.
class DeepTerrain extends "res://src/world/terrain.gd":
	func _init() -> void:
		super({"DEFS": []})
		maps.append(DeepMap.new())
		_worlds.append(1)
		_roots.append(null)
		_heights.append(PackedFloat32Array())


func _initialize() -> void:
	_run()


func _run() -> void:
	var t := T.new("dig_deep_zone_test")

	# (1) Schema.
	var issues := ZoneSchema.validate(DeepMap.new())
	t.check("ZoneSchema.validate is empty", issues.is_empty(), str(issues))

	# (2) Three tiers, built once.
	var world := Node3D.new()
	root.add_child(world)
	var terrain := DeepTerrain.new()
	terrain.build(world)
	terrain.use(1)
	var m = terrain.map()
	var spawn_h := terrain.height(m.spawn.x, m.spawn.y)
	var middle_h := terrain.height(MIDDLE_POINT.x, MIDDLE_POINT.y)
	var beacon_h := terrain.height(m.beacon.x, m.beacon.y)
	t.check("spawn, middle and beacon heights are finite", is_finite(spawn_h) and is_finite(middle_h) and is_finite(beacon_h),
		"spawn %.3f, middle %.3f, beacon %.3f" % [spawn_h, middle_h, beacon_h])
	t.check("three tiers each at least %.0f m apart" % TIER_GAP, spawn_h - middle_h >= TIER_GAP and middle_h - beacon_h >= TIER_GAP,
		"spawn %.3f, middle %.3f, beacon %.3f" % [spawn_h, middle_h, beacon_h])

	# (3) Every plate: live cover reads its tier, erased reads drop_to on the pit floor.
	t.check("five or more plates", m.breach_plates.size() >= 5, "%d plates" % m.breach_plates.size())
	var middle_plate := {}
	for plate in m.breach_plates:
		var id: String = plate["id"]
		var r: Rect2 = plate["rect"]
		var drop_to: float = plate["drop_to"]
		var c := r.get_center()
		var tier: float = DeepMap.UPPER_H if c.y < DeepMap.CLIFF_Z else DeepMap.LOWER_H
		if tier == DeepMap.LOWER_H and middle_plate.is_empty():
			middle_plate = plate
		t.check("%s: rect at least 8 m a side" % id, r.size.x >= 8.0 and r.size.y >= 8.0, str(r.size))
		t.check("%s: id in start_overlays" % id, m.start_overlays.has(id + "_before"), str(m.start_overlays))
		var floor_rect := r.grow(-DeepMap.PIT_WALL)
		var points := [c, floor_rect.position, floor_rect.end,
			Vector2(floor_rect.position.x, floor_rect.end.y), Vector2(floor_rect.end.x, floor_rect.position.y)]
		var covered := 0.0
		for p in points:
			covered = maxf(covered, absf(terrain.height(p.x, p.y) - tier))
		var had: bool = terrain.overlays.has(id + "_before")
		terrain.overlays.erase(id + "_before")
		var dropped := 0.0
		for p in points:
			dropped = maxf(dropped, absf(terrain.height(p.x, p.y) - drop_to))
		if had:
			terrain.overlays.append(id + "_before")
		t.check("%s: tier %.1f while live" % [id, tier], covered <= 0.001, "worst gap %.4f" % covered)
		t.check("%s: drop_to %.1f once erased" % [id, drop_to], dropped <= 0.001, "worst gap %.4f" % dropped)
	t.check("a plate sits on the middle tier", not middle_plate.is_empty(), str(m.breach_plates.map(func(p): return p["id"])))

	# (4) The first middle-tier plate drops with a ball on it.
	if not middle_plate.is_empty():
		var pid: String = middle_plate["id"]
		var drop_to: float = middle_plate["drop_to"]
		var centre: Vector2 = (middle_plate["rect"] as Rect2).get_center()
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
		ball.position = Vector3(centre.x, DeepMap.LOWER_H + radius + 2.0, centre.y)
		world.add_child(ball)
		for i in SETTLE_FRAMES:
			await physics_frame
		var at := ball.global_position
		var cover := terrain.height(at.x, at.z)
		var gap_before := at.y - radius - cover
		t.check("%s: ball rests on the cover" % pid, absf(gap_before) <= TOLERANCE,
			"y %.3f, terrain.height %.3f, gap %.3f" % [at.y, cover, gap_before])
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
		var floor_h := terrain.height(at.x, at.z)
		t.check("%s: ball reaches drop_to %.1f within %d frames" % [pid, drop_to, DROP_FRAMES],
			reached > 0 and absf(floor_h - drop_to) <= TOLERANCE,
			"first agreeing frame %d, terrain.height %.3f (was %.3f)" % [reached, floor_h, cover])
		t.check("%s: ball agrees with the floor at frame %d" % [pid, DROP_FRAMES], absf(gap) <= TOLERANCE,
			"y %.3f, terrain.height %.3f, gap %.3f" % [at.y, floor_h, gap])
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
				if on_plate.is_empty() and DeepMap._inside(plate["rect"], p.x, p.y):
					on_plate = "%s at %s" % [plate["id"], p]
	t.check("route starts at the spawn and ends at the beacon", ROUTE[0] == m.spawn and ROUTE[-1] == m.beacon,
		"%s -> %s" % [ROUTE[0], ROUTE[-1]])
	t.check("route never climbs over %.1f per m" % CLIMB_SLOPE, worst_climb <= CLIMB_SLOPE,
		"worst climb %.3f per m" % worst_climb)
	t.check("route never enters a plate rect", on_plate.is_empty(), on_plate if not on_plate.is_empty() else "clear")

	# (6) ZoneSeed is deterministic.
	var seeded_a := var_to_str(ZoneSeed.fill(DeepMap.new(), 7))
	var seeded_b := var_to_str(ZoneSeed.fill(DeepMap.new(), 7))
	t.check("ZoneSeed.fill(map, 7) is stable", seeded_a == seeded_b, "%d and %d chars" % [seeded_a.length(), seeded_b.length()])

	# (7) Its own spawn and beacon, not the first Dig's.
	var first = DigMap.new()
	t.check("spawn at least 20 m from the first Dig's", m.spawn.distance_to(first.spawn) >= 20.0,
		"%s vs %s" % [m.spawn, first.spawn])
	t.check("beacon differs from the first Dig's", m.beacon != first.beacon, "%s vs %s" % [m.beacon, first.beacon])

	world.free()
	quit(t.verdict())
