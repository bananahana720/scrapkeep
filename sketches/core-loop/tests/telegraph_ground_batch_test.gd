extends SceneTree

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Ground := preload("res://src/combat/ground.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const EventGround := preload("res://src/world/events/event_ground.gd")

# A telegraph reads the ground under all its marks in one ask (terrain.gd heights, Painter.ground_many):
# a Warden pulse's two rings through height() one point at a time were 20 ms of a flume frame on the
# cloud. The batch must answer what height() answers point by point, with an overlay down under the
# ring and one far away (left out of a batch whose bounds miss it, read once they reach it), and a
# ring painted through it must be the ring painted point by point. In the arena the boss floor reads
# each point, so the batch stays out.

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_flume"}]}

var _t := T.new("telegraph_ground_batch_test")


class Flow:
	var in_arena := false


class Ctx:
	var terrain
	var flow := Flow.new()
	var boss = null


class Boss:
	extends Node
	func ground_height_at(point: Vector3) -> float:
		return 40.0 + point.x * 0.01


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	# Terrain3D follows the active camera; without one it prints an ERROR line.
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	SimClock.ticks = true
	var terrain = Terrain.new(TABLE)
	terrain.build(holder)
	terrain.stage = 1
	terrain.geometry_root(1)
	var m = _overlay_map(terrain, 0)
	var at: Vector3 = terrain.vault_point(1)
	var near_site := {"id": "test_near", "at": [at.x + 4.0, at.z], "size": [8.0, 0.0, 8.0], "yaw_deg": 30.0, "y": at.y + 3.0}
	var far_site := {"id": "test_far", "at": [at.x + 200.0, at.z + 200.0], "size": [10.0, 0.0, 10.0], "yaw_deg": 0.0, "y": at.y + 9.0}
	for site in [near_site, far_site]:
		m.profiles[site.id + "_after"] = {"site": site, "surface": EventGround.span_surface(site, 0.0)}
		terrain.overlays.append(site.id + "_after")

	var points := PackedVector2Array()
	for r in [0.0, 1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 11.0]:
		for k in 72:
			points.append(Vector2(at.x, at.z) + Vector2.from_angle(TAU * k / 72.0) * r)
	# The ring alone leaves the far overlay out; with a point just inside the far footprint's corner the
	# bounds reach it and it is read.
	var corner := Vector2(at.x + 200.0, at.z + 200.0) + Vector2(4.9, 4.9)
	var ring_raised := _compare(terrain, points, "the ring alone (bounds miss the far overlay)")
	var with_far := points.duplicate()
	with_far.append(corner)
	_compare(terrain, with_far, "the ring and a point inside the far footprint's corner")
	# A small ring over the far footprint's corner: its bounds miss the far centre but reach the footprint,
	# so the skip's disc, not the centre, must keep the overlay in.
	var corner_ring := PackedVector2Array()
	for k in 24:
		corner_ring.append(corner + Vector2.from_angle(TAU * k / 24.0) * 1.0)
	var corner_bounds := Rect2(corner_ring[0], Vector2.ZERO)
	for p in corner_ring:
		corner_bounds = corner_bounds.expand(p)
	_t.check("the corner ring's bounds miss the far centre", not corner_bounds.has_point(Vector2(at.x + 200.0, at.z + 200.0)))
	var corner_raised := _compare(terrain, corner_ring, "a ring over the far footprint's corner, its centre outside the bounds")
	_t.check("the far overlay stands under some of the corner ring", corner_raised > 0, "%d raised" % corner_raised)
	_t.check("the near overlay stands under some ring points", ring_raised > 0, "%d raised" % ring_raised)
	_t.check("the far overlay stands under the corner point", terrain.height(corner.x, corner.y) > terrain._floor(0, corner.x, corner.y) + 0.5)
	_t.check("an empty ask answers empty", terrain.heights(PackedVector2Array()).is_empty())

	var ctx := Ctx.new()
	ctx.terrain = terrain
	var ground = Ground.new(ctx)
	var world := Node3D.new()
	root.add_child(world)
	var ring = Telegraph.ring(world, ground, Threat.Type.INSTANT, at, 9.0)
	_t.check("a ring over combat ground reads it in one ask", ring._painter.ground_many.is_valid())
	_same_paint(ring, "stage")

	var boss := Boss.new()
	world.add_child(boss)
	ctx.boss = boss
	ctx.flow.in_arena = true
	_t.check("in the arena the batch stays out", ground.heights(points).is_empty())
	var arena_ring = Telegraph.ring(world, ground, Threat.Type.INSTANT, at, 9.0)
	_same_paint(arena_ring, "arena")
	quit(_t.verdict())


# heights() against height() point by point; answers how many points an overlay raised.
func _compare(terrain, points: PackedVector2Array, label: String) -> int:
	var batch: PackedFloat64Array = terrain.heights(points)
	var worst := 0.0
	var raised := 0
	for k in points.size():
		var one: float = terrain.height(points[k].x, points[k].y)
		worst = maxf(worst, absf(batch[k] - one))
		if one > terrain._floor(0, points[k].x, points[k].y) + 0.5:
			raised += 1
	_t.check("%s: heights() answers height() at every point" % label, batch.size() == points.size() and worst == 0.0,
		"worst difference %.6f m over %d points" % [worst, points.size()])
	return raised


# The ring's painter against one painted point by point from the same marks.
func _same_paint(ring, label: String) -> void:
	var a = ring._painter
	var b = Threat.Painter.new()
	b.floor_y = a.floor_y
	b.ground = a.ground
	b.lift = a.lift
	b.driven = a.driven
	b.centre = a.centre
	b.heading = a.heading
	b.motion_class = a.motion_class
	b.area_class = a.area_class
	ring.add_child(b)
	b.paint(Threat.marks(ring.descriptor(), false), Threat.STATIC_LAYERS)
	var compared := 0
	var worst := 0.0
	for layer in Threat.STATIC_LAYERS:
		if not a._layers.has(layer) or a._layers[layer].mesh == null:
			continue
		var va: PackedVector3Array = a._layers[layer].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var vb: PackedVector3Array = b._layers[layer].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if va.size() != vb.size():
			worst = INF
			continue
		for k in va.size():
			worst = maxf(worst, va[k].distance_to(vb[k]))
		compared += va.size()
	_t.check("%s: the ring painted in one ask is the ring painted point by point" % label, compared > 0 and worst == 0.0,
		"%d vertices, worst %.6f m" % [compared, worst])


func _overlay_map(terrain, i: int):
	var current = terrain.maps[i]
	var m = EventGround.OverlayMap.new("")
	for property in current.get_property_list():
		if int(property.usage) & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE) and property.name != "script":
			var value = current.get(property.name)
			m.set(property.name, value.duplicate(true) if value is Dictionary or value is Array else value)
	m.source = current
	terrain.maps[i] = m
	return m
