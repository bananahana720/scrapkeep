extends SceneTree

const Director := preload("res://src/world/event_director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const T := preload("res://tests/support/t.gd")
const FIXTURE := "res://tests/fixtures/park_events_industrial_rows.json"
const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Industrial := preload("res://src/world/events/industrial.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const BAR := 240.0 / 172.0
const H := 0.05
const FAR := Vector3(1000.0, 1.0, 1000.0)

class Player extends RefCounted:
	var state := {"velocity": Vector3(17, -2, 9), "grounded": true}
	func set_velocity_now(v: Vector3, _cause := "") -> void:
		state.velocity = v

class Context extends RefCounted:
	var player := Player.new()
	var events := GameEvents.new()
	var run := RunState.new(events, 823)
	var losses: Array = []
	var root: Node3D
	func burst(parent: Node, id: String, at: Vector3, count := -1, tint := Color.TRANSPARENT, toward := Vector3.ZERO, isolate := false) -> GPUParticles3D:
		return FxLibrary.burst(parent, id, at, count, tint, toward, isolate)

class Terrain extends RefCounted:
	var maps: Array = []
	var stage := 1
	var overlays: Array[String] = []
	var geometry: Node3D
	func geometry_root(_stage: int) -> Node3D:
		return geometry
	func map():
		return maps[stage - 1]
	func height(x: float, z: float) -> float:
		var h := 12.0 + 0.05 * x - 0.03 * z
		for id in overlays:
			h = maxf(h, map().overlay_height(id, x, z, h))
		return h

class World extends Node3D:
	var ctx := Context.new()
	var terrain := Terrain.new()
	var events
	var event_families := {}

var t := T.new("park_events_industrial_test")

func _initialize() -> void:
	_run.call_deferred()

func _world(row: Dictionary, sites: Array, routes: Array) -> World:
	var w := World.new()
	root.add_child(w)
	w.ctx.root = w
	w.add_child(w.ctx.events)
	w.ctx.run.add_scrap(20, FAR)
	w.ctx.events.scrap_lost.connect(func(amount, at, total, cause): w.ctx.losses.append({"amount": amount, "at": at, "total": total, "cause": cause}))
	w.terrain.geometry = w
	var map := ParkMap.new()
	map.park = {"map": "fixture", "park_rows": sites.duplicate(true), "event_rows": [row],
		"weather_rows": [], "routes": routes}
	w.terrain.maps = [map]
	w.events = Director.new(823, {}, map, 14.0, Callable(w.terrain, "height"))
	var industrial := Industrial.new()
	w.add_child(industrial)
	industrial.setup(w)
	w.events.register_family("industrial", Callable(industrial, "handle"))
	w.event_families = {"industrial": industrial}
	return w

func _context() -> Dictionary:
	return {"clock_tier": 4, "grounded": true, "bar_s": BAR, "bar_origin_s": 0.0}

func _land(w: World, row: Dictionary) -> bool:
	var announced := false
	var early := false
	var warning = null
	var warning_geometry: Array = []
	for i in 2000:
		var ctx := _context()
		ctx.warden_phases = ["chunk_2"] if i == 0 else []
		for fact in w.events.advance(H, FAR, Vector3.ZERO, ctx):
			if fact.id != row.id:
				continue
			if fact.kind == "announced":
				announced = true
				warning = w.event_families.industrial.active.get(row.id, {}).get("hazard")
				warning_geometry = _committed_geometry(warning)
			elif fact.kind == "started":
				var hazard = w.event_families.industrial.active.get(row.id, {}).get("hazard")
				t.check("%s telegraphs then lands without early damage or swap" % row.id, announced and not early and w.ctx.run.mass == 20)
				t.check("%s warning and live damage use one committed hazard" % row.id,
					is_instance_valid(hazard) and hazard == warning and hazard.is_live() and hazard.painter() != null)
				t.eq("%s landing preserves warning committed geometry" % row.id,
					_committed_geometry(hazard), warning_geometry)
				return true
		early = early or w.terrain.overlays.has(str(row.effect.swap) + "_after") or w.ctx.run.mass != 20
	t.check("%s lands within the run" % row.id, false)
	return false

func _committed_geometry(hazard) -> Array:
	return [hazard.attack_id, hazard.type, hazard.shape, hazard.centre, hazard.r_in,
		hazard.r_out, hazard.a_from, hazard.a_to, hazard.heading, hazard.back,
		hazard.length, hazard.half_width, hazard.reach, hazard.live_seconds]

func _commit_source_checks() -> void:
	var source := FileAccess.get_file_as_string("res://src/world/events/industrial.gd")
	var telegraph := source.get_slice("func _telegraph(", 1).get_slice("\n\nfunc ", 0)
	var branches := telegraph.get_slice("\tif spec.form == \"cone\":\n", 1).split("\n\telse:\n")
	var calls := RegEx.new()
	calls.compile("\\bcommit_[a-z_]+\\s*\\(")
	var sector := RegEx.new()
	sector.compile("\\bcommit_sector\\s*\\(")
	var annulus := RegEx.new()
	annulus.compile("\\bcommit_annulus\\s*\\(")
	t.eq("industrial telegraph has one sector commit callsite", sector.search_all(telegraph).size(), 1)
	t.eq("industrial telegraph has one annulus commit callsite", annulus.search_all(telegraph).size(), 1)
	t.check("industrial commit callsites are in mutually exclusive cone and else branches",
		branches.size() == 2 and calls.search_all(branches[0]).size() == 1
		and sector.search_all(branches[0]).size() == 1 and calls.search_all(branches[1]).size() == 1
		and annulus.search_all(branches[1]).size() == 1)
	t.eq("industrial handler has no other commit callsites", calls.search_all(source).size(), 2)
	var bookkeeping := RegEx.new()
	bookkeeping.compile("(?m)^var commits\\b|^\\s*commits\\[")
	t.eq("industrial handler has no test commit bookkeeping", bookkeeping.search_all(source).size(), 0)

func _route_checks(w: World, row: Dictionary) -> void:
	var opened := 0
	var closed := 0
	for id in row.route_change.opens:
		if w.events.has_method("route_open") and w.events.call("route_open", str(id)):
			opened += 1
	for id in row.route_change.closes:
		if w.events.has_method("route_open") and not w.events.call("route_open", str(id)):
			closed += 1
	t.eq("%s director opens routes after land" % row.id, opened, row.route_change.opens.size())
	t.eq("%s director closes routes after land" % row.id, closed, row.route_change.closes.size())

# Check the actual live fill triangles, independently of Hazard.contains().
func _painted(hazard, point: Vector3) -> bool:
	var painter = hazard.painter()
	var fill = painter._layers.get("fill") if painter != null else null
	if fill == null or fill.mesh == null or fill.mesh.get_surface_count() == 0:
		return false
	var vertices: PackedVector3Array = fill.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var p := Vector2(point.x, point.z)
	for k in range(0, vertices.size(), 3):
		var a := Vector2(vertices[k].x, vertices[k].z)
		var b := Vector2(vertices[k + 1].x, vertices[k + 1].z) - a
		var c := Vector2(vertices[k + 2].x, vertices[k + 2].z) - a
		var det := b.cross(c)
		if absf(det) < 0.000001:
			continue
		var u := (p - a).cross(c) / det
		var v := b.cross(p - a) / det
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			return true
	return false

func _damage(w: World, point: Vector3) -> int:
	point.y = w.terrain.height(point.x, point.z)
	var before: float = w.ctx.run.mass
	w.events.advance(0.01, point, Vector3.ZERO, _context())
	return before - w.ctx.run.mass

func _fill_ground_checks(w: World, hazard, row: Dictionary) -> void:
	var painter = hazard.painter()
	var fill = painter._layers.get("fill")
	var vertices: PackedVector3Array = fill.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var raised := 0
	var max_error := 0.0
	for vertex in vertices:
		var height := w.terrain.height(vertex.x, vertex.z)
		var base_height := 12.0 + 0.05 * vertex.x - 0.03 * vertex.z
		if height > base_height + 0.01:
			raised += 1
		max_error = maxf(max_error, absf(vertex.y - height - float(painter.lift)))
	t.check("%s live fill samples raised swap ground" % row.id, raised > 0, "raised vertices=%d" % raised)
	t.check("%s live fill vertices follow landed ground plus painter lift" % row.id,
		max_error < 0.0001, "max error=%.6f vertices=%d" % [max_error, vertices.size()])

func _run() -> void:
	_commit_source_checks()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var rows: Array = fixture.rows
	t.eq("fixture holds six industrial rows", rows.size(), 6)
	for row in rows:
		var w := _world(row, fixture.park_rows, fixture.routes_by_row[row.id])
		if not _land(w, row):
			w.free()
			continue
		var state: Dictionary = w.event_families.industrial.active[row.id]
		var hazard = state.hazard
		_fill_ground_checks(w, hazard, row)
		var centre: Vector3 = state.at
		var size: Array = row.effect.hazard_m
		var ring: bool = row.effect.hazard == "fallout_ring"
		var outer := minf(float(size[0]), float(size[1])) * 0.5 if ring else float(size[0])
		var axis := -deg_to_rad(float(state.site.yaw_deg))
		var direction := Vector3(cos(axis), 0.0, sin(axis))
		var inside := centre + direction * outer * 0.7
		var outside := centre + direction * (outer + 1.0)
		var eye := centre + direction * outer * 0.2
		var damage := ceili(float(row.effect.damage))
		var swap := str(row.effect.swap)
		t.check("%s lands its swap without a natural handler" % row.id, w.terrain.overlays.has(swap + "_after"))
		_route_checks(w, row)
		t.near("%s hazard follows the ground under its drawn footprint" % row.id, float(hazard.ground_at(inside)), w.terrain.height(inside.x, inside.z))
		t.near("%s drawn outer radius matches hazard_m" % row.id, float(hazard.descriptor().r_out), outer)
		t.check("%s inside probe is drawn in the live fill" % row.id, _painted(hazard, inside))
		t.check("%s outside probe is outside the live fill" % row.id, not _painted(hazard, outside))
		t.eq("%s probe 1 m outside takes none" % row.id, _damage(w, outside), 0)
		if ring:
			t.near("%s declared fallout eye is 0.4 of the outer radius" % row.id, float(hazard.r_in), outer * 0.4)
			t.check("%s eye probe is outside the live fill" % row.id, not _painted(hazard, eye))
			t.eq("%s eye probe takes none" % row.id, _damage(w, eye), 0)
		t.eq("%s inside probe takes exactly the row damage" % row.id, _damage(w, inside), damage)
		t.eq("%s second contact takes none in one activation" % row.id, _damage(w, inside), 0)
		t.check("%s real run state and scrap_lost fact agree on the hit" % row.id,
			w.ctx.run.scrap == 20 - damage and is_equal_approx(w.ctx.run.mass, 20 - damage)
			and w.ctx.losses.size() == 1 and w.ctx.losses[0].amount == damage
			and w.ctx.losses[0].total == w.ctx.run.scrap and w.ctx.losses[0].cause == row.kind)
		var ended := false
		for i in 2000:
			for fact in w.events.advance(H, FAR, Vector3.ZERO, _context()):
				if fact.id == row.id and fact.kind == "ended":
					ended = true
			if ended:
				break
		t.check("%s ends and removes hazard and swap" % row.id,
			ended and not is_instance_valid(hazard) and not w.terrain.overlays.has(swap + "_after"))
		w.event_families.industrial.release()
		w.free()
	t.eq("test runs all expected checks", t.checks + 1, 112)
	quit(t.verdict())
