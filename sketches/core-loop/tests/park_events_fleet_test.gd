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
const EXPECTED_CHECKS := 48
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


# Stands in for the world's game director: the handler calls activate_home through it.
class HomeProxy extends RefCounted:
	var game
	var skip := false

	func activate_home(id: String) -> bool:
		if skip:
			return false
		return game.activate_home(id)


func _initialize() -> void:
	var entries = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	t.eq("fixture holds six fleet rows", entries.size() if entries is Array else -1, EXPECTED_ENTRIES)
	if not ResourceLoader.exists(FLEET_PATH):
		t.check("fleet handler file exists", false, FLEET_PATH)
		_finish()
		return
	for entry in entries:
		var out := _run(entry)
		_check_row(entry.row, entry.site, out)
	var first: Dictionary = entries[0]
	# Seeded control (a): skip activate_home, so the home stays dormant at land.
	var skipped := _run(first, true)
	t.check("control skip activate_home leaves home dormant", skipped.started and skipped.home_land == false,
		"home_live at land=%s" % str(skipped.home_land))
	var restored := _run(first)
	t.check("control restored: home wakes at land again", restored.started and restored.home_land == true,
		"home_live at land=%s" % str(restored.home_land))
	# Seeded control (b): move the vessel to y = 0 at land, so the ground check fails.
	var lowered := _run(first, false, true)
	t.check("control mark at y=0 fails the ground check", lowered.ground_broken > GROUND_TOLERANCE,
		"worst gap %.3f m" % lowered.ground_broken)
	t.check("control restored: vessel back on the ground", lowered.ground_restored <= GROUND_TOLERANCE,
		"worst gap %.3f m" % lowered.ground_restored)
	_finish()


func _finish() -> void:
	if ResourceLoader.exists(FLEET_PATH):
		t.check("check count is the expected %d" % EXPECTED_CHECKS, t.checks + 1 == EXPECTED_CHECKS, "ran %d before this check" % t.checks)
	quit(t.verdict())


func _check_row(row: Dictionary, site: Dictionary, out: Dictionary) -> void:
	var id: String = row.id
	t.check("%s home dormant before telegraph" % id, out.announced and out.home_telegraph == false,
		"home_live at telegraph=%s" % str(out.home_telegraph))
	t.check("%s telegraph builds the vessel" % id, out.mark_telegraph != null, "mark=%s" % str(out.mark_telegraph))
	t.check("%s land wakes home %s" % [id, row.effect.home], out.started and out.home_land == true,
		"home_live at land=%s" % str(out.home_land))
	var footprint: Array = row.effect.footprint_m
	t.check("%s footprint matches effect.footprint_m" % id,
		absf(out.span.x - float(footprint[0])) <= FOOTPRINT_TOLERANCE and absf(out.span.y - float(footprint[1])) <= FOOTPRINT_TOLERANCE,
		"span %s, want %s within %.1f m" % [out.span, Vector2(footprint[0], footprint[1]), FOOTPRINT_TOLERANCE])
	t.check("%s vessel sits on the ground under the site" % id, out.ground_n > 0 and out.ground_error <= GROUND_TOLERANCE,
		"vertices %d, worst gap %.3f m" % [out.ground_n, out.ground_error])
	var want_opens: int = row.route_change.opens.size()
	t.eq("%s route opens applied at land" % id, out.opens_live, want_opens)
	t.check("%s runs telegraph to end with no script error" % id, out.started and out.ended and out.handler_cleared,
		"started=%s ended=%s cleared=%s" % [out.started, out.ended, out.handler_cleared])


func _run(entry: Dictionary, skip := false, lower := false) -> Dictionary:
	var row: Dictionary = entry.row.duplicate(true)
	var site: Dictionary = entry.site.duplicate(true)
	var home: Dictionary = entry.home.duplicate(true)
	home.broken = false
	var game := GameDirector.new(SEED)
	game.homes.append(home)
	var proxy := HomeProxy.new()
	proxy.game = game
	proxy.skip = skip
	var world := StageWorld.new()
	world.terrain.park = {"map": entry.map, "park_rows": [site], "event_rows": [row],
		"weather_rows": [], "routes": entry.routes}
	world.director = proxy
	var handler = load(FLEET_PATH).new()
	root.add_child(handler)
	handler.setup(world)
	var map := Map.new()
	map.park = world.terrain.park
	var events := EventDirector.new(SEED, {}, map, 14.0, Callable(world.terrain, "height"))
	events.register_family("fleet", Callable(handler, "handle"))
	var out := {"announced": false, "home_telegraph": null, "mark_telegraph": null, "started": false,
		"ended": false, "home_land": null, "span": Vector2.ZERO, "ground_n": 0, "ground_error": INF,
		"opens_live": 0, "handler_cleared": false, "ground_broken": 0.0, "ground_restored": 0.0}
	var centre := Vector2(float(site.at[0]), float(site.at[1]))
	var yaw := deg_to_rad(float(site.yaw_deg))
	var done := false
	for step in 4000:
		for fact in events.advance(H, FAR, Vector3.ZERO, {"clock_tier": 4, "grounded": true, "bar_s": BAR, "bar_origin_s": 0.0}):
			if fact.kind == "announced" and not out.announced:
				out.announced = true
				out.home_telegraph = game.home_live(home.id)
				out.mark_telegraph = handler.active.get(row.id, {}).get("mark")
			elif fact.kind == "started" and not out.started:
				out.started = true
				out.home_land = game.home_live(home.id)
				var mark: Node3D = handler.active[row.id].mark
				var stats := _vessel_stats(mark, world.terrain, centre, yaw)
				out.span = stats.span
				out.ground_n = stats.count
				out.ground_error = stats.error
				out.opens_live = _opens_live(events, row.id, row.route_change.opens)
				if lower:
					var base: float = mark.position.y
					mark.position.y = 0.0
					out.ground_broken = _vessel_stats(mark, world.terrain, centre, yaw).error
					mark.position.y = base
					out.ground_restored = _vessel_stats(mark, world.terrain, centre, yaw).error
			elif fact.kind == "ended" and fact.id == row.id:
				out.ended = true
				done = true
		if done:
			break
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
	var error := 0.0
	for vertex in vertices:
		var world := Vector3(mark.position.x + vertex.x, mark.position.y + vertex.y, mark.position.z + vertex.z)
		var local := (Vector2(world.x, world.z) - centre).rotated(yaw)
		low = low.min(local)
		high = high.max(local)
		error = maxf(error, absf(world.y - terrain.height(world.x, world.z)))
	var span := high - low if not vertices.is_empty() else Vector2.ZERO
	return {"span": span, "count": vertices.size(), "error": error if not vertices.is_empty() else INF}


func _opens_live(events, id: String, opens: Array) -> int:
	var live := 0
	for state in events._park_states:
		if state.row.id == id and state.phase == EventDirector.LIVE:
			for route in state.row.route_change.opens:
				if opens.has(route):
					live += 1
	return live
