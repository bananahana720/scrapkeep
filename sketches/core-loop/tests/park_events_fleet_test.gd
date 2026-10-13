extends SceneTree

# KE3: each fleet_landing row runs telegraph -> land -> end through fleet.gd with the
# handler's greybox vessel on the ground, and its dormant home wakes at land.
# Fixture: six rows from the stage JSON (two repo stages, four scratch stages), with
# their home rows and sites copied from the same stage file.

const T := preload("res://tests/support/t.gd")
const EventDirector := preload("res://src/world/event_director.gd")
const GameDirector := preload("res://src/world/director.gd")

const FLEET_PATH := "res://src/world/events/fleet.gd"
const FIXTURE := "res://tests/fixtures/park_events_fleet_rows.json"
const EXPECTED_ENTRIES := 6
const EXPECTED_CHECKS := 76
const EXPECTED_ROUTE_OPENS := 3
const SEED := 813
const H := 0.05
const BAR := 240.0 / 172.0
const FAR := Vector3(1000.0, 1.0, 1000.0)
const GROUND_TOLERANCE := 0.5
const FOOTPRINT_TOLERANCE := 0.5

var t := T.new("park_events_fleet_test")


class Map extends RefCounted:
	var park := {}


class Terrain extends RefCounted:
	var park := {}

	# A slope, so a mark that is not projected onto the ground misses it.
	func height(x: float, z: float) -> float:
		return 12.0 + 0.05 * x - 0.03 * z

	func map() -> Map:
		var holder := Map.new()
		holder.park = park
		return holder


class StageWorld extends RefCounted:
	var terrain := Terrain.new()
	var director


func _initialize() -> void:
	var entries = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	t.eq("fixture holds six fleet rows", entries.size() if entries is Array else -1, EXPECTED_ENTRIES)
	if not ResourceLoader.exists(FLEET_PATH):
		t.check("fleet handler file exists", false, FLEET_PATH)
		_finish()
		return
	t.check("fixture exercises a yawed site", entries.any(func(e): return absf(float(e.site.yaw_deg)) > 1.0))
	var route_total := 0
	for entry in entries:
		var out := _run(entry)
		_check_row(entry.row, entry.site, out)
		route_total += out.opens_live
	t.eq("route opens open at land, across six rows", route_total, EXPECTED_ROUTE_OPENS)
	_finish()


func _finish() -> void:
	if ResourceLoader.exists(FLEET_PATH):
		t.check("check count is the expected %d" % EXPECTED_CHECKS, t.checks + 1 == EXPECTED_CHECKS, "ran %d before this check" % t.checks)
	quit(t.verdict())


func _check_row(row: Dictionary, site: Dictionary, out: Dictionary) -> void:
	var id: String = row.id
	t.check("%s home dormant before telegraph" % id, out.announced and out.home_telegraph == false,
		"home_live at telegraph=%s" % str(out.home_telegraph))
	t.check("%s telegraph builds the vessel" % id, out.mark_telegraph == true, "mark valid at telegraph=%s" % str(out.mark_telegraph))
	t.check("%s land wakes home %s" % [id, row.effect.home], out.started and out.home_land == true,
		"home_live at land=%s" % str(out.home_land))
	var footprint: Array = row.effect.footprint_m
	t.check("%s footprint matches effect.footprint_m" % id,
		absf(out.span.x - float(footprint[0])) <= FOOTPRINT_TOLERANCE and absf(out.span.y - float(footprint[1])) <= FOOTPRINT_TOLERANCE,
		"span %s, want %s within %.1f m" % [out.span, Vector2(footprint[0], footprint[1]), FOOTPRINT_TOLERANCE])
	t.check("%s vessel sits on the ground under the site" % id, out.ground_n > 0 and out.ground_error <= GROUND_TOLERANCE,
		"vertices %d, worst gap %.3f m" % [out.ground_n, out.ground_error])
	t.check("%s telegraph decal is projected on the ground" % id, out.telegraph_ground <= GROUND_TOLERANCE, str(out.telegraph_ground))
	t.eq("%s route closes closed after land" % id, out.closes_live, 0)
	var row_opens: Array = row.route_change.opens
	t.eq("%s route opens closed before telegraph" % id, out.opens_telegraph_open, 0)
	t.eq("%s route opens open after land" % id, out.opens_live, row_opens.size())
	t.eq("%s route opens named in the park's routes" % id, out.opens_routed, row_opens.size())
	t.check("%s land sets down a solid greybox hull" % id, out.thickness >= 1.0, "vertical thickness %.3f m" % out.thickness)
	t.check("%s runs telegraph to end with no script error" % id, out.started and out.ended and out.handler_cleared,
		"started=%s ended=%s cleared=%s" % [out.started, out.ended, out.handler_cleared])


func _run(entry: Dictionary) -> Dictionary:
	var row: Dictionary = entry.row.duplicate(true)
	var site: Dictionary = entry.site.duplicate(true)
	var home: Dictionary = entry.home.duplicate(true)
	home.broken = false
	var game := GameDirector.new(SEED)
	game.homes.append(home)
	var world := StageWorld.new()
	world.terrain.park = {"map": entry.map, "park_rows": [site], "event_rows": [row],
		"weather_rows": [], "routes": entry.routes, "spawn": entry.spawn, "landmark": entry.landmark,
		"activity_rows": entry.activity_rows}
	world.director = game
	var handler = load(FLEET_PATH).new()
	root.add_child(handler)
	handler.setup(world)
	var map := Map.new()
	map.park = world.terrain.park
	var events := EventDirector.new(SEED, {}, map, 14.0, Callable(world.terrain, "height"))
	events.register_family("fleet", Callable(handler, "handle"))
	var out := {"announced": false, "home_telegraph": null, "mark_telegraph": null, "started": false,
		"ended": false, "home_land": null, "span": Vector2.ZERO, "ground_n": 0, "ground_error": INF,
		"opens_telegraph_open": -1, "opens_live": 0, "opens_routed": 0, "fact_opens": [],
		"handler_cleared": false, "telegraph_ground": INF, "thickness": 0.0, "closes_live": -1}
	var named_routes := []
	for route in entry.routes:
		named_routes.append(route.id)
	var centre := Vector2(float(site.at[0]), float(site.at[1]))
	var yaw := deg_to_rad(float(site.yaw_deg))
	var done := false
	var after_land := 0
	for step in 4000:
		# No pilot lines: the test's ball is parked far away, so corridor clearance is not under test.
		var ctx := {"clock_tier": 4, "grounded": true, "bar_s": BAR, "bar_origin_s": 0.0, "pilot_lines": []}
		for fact in events.advance(H, FAR, Vector3.ZERO, ctx):
			if fact.kind == "announced" and not out.announced:
				out.announced = true
				out.home_telegraph = game.home_live(home.id)
				out.mark_telegraph = handler.active.has(row.id) and is_instance_valid(handler.active[row.id].mark)
				if out.mark_telegraph:
					out.telegraph_ground = _vessel_stats(handler.active[row.id].mark, world.terrain, centre, yaw).error
				out.opens_telegraph_open = _open_count(events, row.route_change.opens)
			elif fact.kind == "started" and not out.started:
				out.started = true
				out.home_land = game.home_live(home.id)
				var mark: Node3D = handler.active[row.id].mark
				var stats := _vessel_stats(mark, world.terrain, centre, yaw)
				out.span = stats.span
				out.thickness = stats.thickness
				out.closes_live = _open_count(events, row.route_change.closes)
				out.ground_n = stats.count
				out.ground_error = stats.error
				out.opens_live = _open_count(events, row.route_change.opens)
				out.opens_routed = _open_count_in(row.route_change.opens, named_routes)
			elif fact.kind == "ended" and fact.id == row.id:
				out.ended = true
				done = true
		if out.started:
			after_land += 1
		if done or after_land > 60:
			break
	# A fleet landing has live_s 0, so the step path never ends it: it persists until
	# teardown, as the lifecycle test in park_events_test does with end_all().
	for fact in events.end_all():
		if fact.kind == "ended" and fact.id == row.id:
			out.ended = true
	out.handler_cleared = not handler.active.has(row.id)
	handler.release()
	handler.free()
	return out


func _vessel_stats(mark: Node3D, terrain: Terrain, centre: Vector2, yaw: float) -> Dictionary:
	var vertices := PackedVector3Array()
	for child in mark.get_children():
		if child is MeshInstance3D and child.name == "Vessel" and child.mesh != null and child.mesh.get_surface_count() > 0:
			vertices = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var low := Vector2.INF
	var high := -Vector2.INF
	var bottoms := {}
	var tops := {}
	for vertex in vertices:
		var point := mark.transform * vertex
		var local := (Vector2(point.x, point.z) - centre).rotated(yaw)
		low = low.min(local)
		high = high.max(local)
		var key := Vector2(point.x, point.z)
		bottoms[key] = minf(bottoms.get(key, INF), point.y)
		tops[key] = maxf(tops.get(key, -INF), point.y)
	var error := 0.0
	var thickness := 0.0
	for point in bottoms:
		error = maxf(error, absf(bottoms[point] - terrain.height(point.x, point.y)))
		thickness = maxf(thickness, tops[point] - bottoms[point])
	var span := high - low if not vertices.is_empty() else Vector2.ZERO
	return {"span": span, "count": vertices.size(), "error": error if not vertices.is_empty() else INF, "thickness": thickness}


func _open_count(events, ids: Array) -> int:
	var count := 0
	for id in ids:
		if events.has_method("route_open") and events.call("route_open", str(id)):
			count += 1
	return count


func _open_count_in(ids: Array, named: Array) -> int:
	var count := 0
	for id in ids:
		if named.has(id):
			count += 1
	return count
