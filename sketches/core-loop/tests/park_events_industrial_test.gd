extends SceneTree

# KE5 industrial bursts: each boiler_burst and reactor_blow row runs from telegraph to land
# to end through the family handler in src/world/events/industrial.gd. The expected check
# count is EXPECTED_BEFORE_FINAL + 1; any other count fails.

const Director := preload("res://src/world/event_director.gd")
const Natural := preload("res://src/world/events/natural.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const T := preload("res://tests/support/t.gd")
const FIXTURE := "res://tests/fixtures/park_events_industrial_rows.json"
const INDUSTRIAL := "res://src/world/events/industrial.gd"
const EXPECTED_BEFORE_FINAL := 36
const BAR := 240.0 / 172.0
const H := 0.05
const FAR := Vector3(1000.0, 1.0, 1000.0)
const CONE := "powerhouse_boiler"
const RING := "annex_reactor_blow"
# Test-only inner radius for the ring probe: the authored fallout_ring row has inner == outer == 20.
const RING_PROBE_INNER_M := 14.0


class Player:
	extends RefCounted
	var state := {"velocity": Vector3(17, -2, 9), "grounded": true}

	func set_velocity_now(v: Vector3, _cause := "") -> void:
		state.velocity = v


class Run:
	extends RefCounted
	var mass := 20

	func lose_scrap(amount: int, _at: Vector3, _cause: String) -> int:
		var lost := mini(amount, mass)
		mass -= lost
		return lost


class SpyNatural:
	extends Natural
	# Counts overlay-end calls that reach natural after its own release (the release-order check).
	var release_end_calls := 0
	var released := false

	func release() -> void:
		released = true
		super.release()

	func _set_overlay(row: Dictionary, changed: bool) -> void:
		if released and not changed:
			release_end_calls += 1
			return
		super._set_overlay(row, changed)


class Context:
	extends RefCounted
	var player := Player.new()
	var run := Run.new()
	var root: Node3D


class Terrain:
	extends RefCounted
	var maps: Array = []
	var stage := 1
	var flood = null
	var overlays: Array[String] = []
	var geometry: Node3D

	func ground(_x: float, _z: float) -> float:
		return 0.0

	func geometry_root(_stage: int) -> Node3D:
		return geometry

	func map():
		return maps[stage - 1]

	func height(x: float, z: float) -> float:
		var h := ground(x, z)
		for id in overlays:
			h = maxf(h, map().overlay_height(id, x, z, 0.0))
		return h


class World:
	extends Node3D
	var ctx := Context.new()
	var terrain := Terrain.new()
	var events
	var flood = null
	var event_families := {}


var t := T.new("park_events_industrial_test")


func _initialize() -> void:
	_run.call_deferred()


func _world(rows: Array, sites: Array, spy := false) -> World:
	var w := World.new()
	root.add_child(w)
	w.ctx.root = w
	w.terrain.geometry = w
	var map := ParkMap.new()
	map.park = {"map": "fixture", "park_rows": sites.duplicate(true), "event_rows": rows.duplicate(true),
		"weather_rows": [], "routes": [{"id": "main", "from": "drop_in", "to": "landmark"}]}
	w.terrain.maps = [map]
	w.events = Director.new(823, {}, map, 14.0, Callable(w.terrain, "height"))
	var natural = SpyNatural.new() if spy else Natural.new()
	w.add_child(natural)
	natural.setup(w)
	var industrial = load(INDUSTRIAL).new()
	w.add_child(industrial)
	industrial.setup(w)
	w.events.register_family("natural", Callable(natural, "handle"))
	w.events.register_family("industrial", Callable(industrial, "handle"))
	w.event_families = {"natural": natural, "industrial": industrial}
	return w


# Steps the director until the row lands (to_end false) or ends (to_end true).
func _drive(w: World, row_id: String, to_end: bool) -> Dictionary:
	var out := {"announced": 0, "started": 0, "ended": 0, "opens": -1, "closes": -1, "live": false,
		"painted": false, "commits": 0, "overlay": false}
	var industrial = w.event_families.industrial
	for i in 2000:
		var ctx := {"clock_tier": 4, "grounded": true, "bar_s": BAR, "bar_origin_s": 0.0,
			"warden_phases": ["chunk_2"] if i == 0 else []}
		for f in w.events.advance(H, FAR, Vector3.ZERO, ctx):
			if f.id != row_id:
				continue
			if f.kind == "announced":
				out.announced += 1
			elif f.kind == "started":
				out.started += 1
				out.opens = f.route_change.opens.size()
				out.closes = f.route_change.closes.size()
				var state: Dictionary = industrial.active.get(row_id, {})
				var hazard = state.get("hazard")
				out.live = hazard != null and is_instance_valid(hazard) and hazard.is_live()
				out.painted = out.live and hazard.painter() != null
				out.commits = industrial.commits.get(row_id, 0)
				out.overlay = w.terrain.overlays.has(String(f.row.effect.get("swap", "")) + "_after")
				if not to_end:
					return out
			elif f.kind == "ended":
				out.ended += 1
		if out.ended > 0:
			break
	return out


func _row(rows: Array, id: String) -> Dictionary:
	for row in rows:
		if row.id == id:
			return row
	return {}


func _site(sites: Array, id: String) -> Dictionary:
	for site in sites:
		if site.id == id:
			return site
	return {}


func _run() -> void:
	if not FileAccess.file_exists(INDUSTRIAL):
		t.check("industrial family exists", false, INDUSTRIAL)
		quit(t.verdict())
		return
	t.check("industrial family exists", true, INDUSTRIAL)
	var fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var rows: Array = fixture.rows
	var sites: Array = fixture.park_rows

	# Every row, one director each: telegraph, land, end, one hazard, the swap and the routes.
	for row in rows:
		var w := _world([row], sites)
		var out := _drive(w, row.id, true)
		t.check("%s telegraphs, lands and ends once" % row.id,
			out.announced == 1 and out.started == 1 and out.ended == 1, str(out))
		t.check("%s commits one hazard, live and drawn at land" % row.id,
			out.commits == 1 and out.live and out.painted, "commits %d live %s painted %s" % [out.commits, out.live, out.painted])
		t.check("%s lands its swap overlay" % row.id, out.overlay, String(row.effect.swap))
		t.check("%s land fact carries its route changes" % row.id,
			out.opens == row.route_change.opens.size() and out.closes == row.route_change.closes.size(),
			"opens %d closes %d" % [out.opens, out.closes])
		w.free()

	# Cone: 6 damage once per activation inside the committed shape, none 1 m beyond its far end.
	var cone_row := _row(rows, CONE)
	var cone_site := _site(sites, cone_row.site)
	var cone_centre := Vector3(float(cone_site.at[0]), 0.0, float(cone_site.at[1]))
	var damage := ceili(float(cone_row.effect.damage))
	var cone_length := float(cone_row.effect.hazard_m[0])
	var w := _world([cone_row], sites)
	_drive(w, CONE, false)
	var industrial = w.event_families.industrial
	var before := w.ctx.run.mass
	industrial.handle("step", cone_row, {"ball": cone_centre + Vector3(12, 0, 0), "delta_s": 0.0})
	var after_inside := w.ctx.run.mass
	t.check("cone probe inside takes exactly the row damage", before - after_inside == damage,
		"mass %d -> %d, damage %d" % [before, after_inside, damage])
	industrial.handle("step", cone_row, {"ball": cone_centre + Vector3(12, 0, 0), "delta_s": 0.0})
	t.check("cone second contact in one activation takes none", w.ctx.run.mass == after_inside, str(w.ctx.run.mass))
	w.free()

	w = _world([cone_row], sites)
	_drive(w, CONE, false)
	industrial = w.event_families.industrial
	before = w.ctx.run.mass
	industrial.handle("step", cone_row, {"ball": cone_centre + Vector3(cone_length + 1.0, 0, 0), "delta_s": 0.0})
	t.eq("cone probe 1 m beyond its far end takes none", w.ctx.run.mass, before)
	w.free()

	# Seeded control (a): doubling the cone's length in the damage path only turns the outside probe red.
	w = _world([cone_row], sites)
	_drive(w, CONE, false)
	industrial = w.event_families.industrial
	industrial.damage_length_scale = 2.0
	before = w.ctx.run.mass
	industrial.handle("step", cone_row, {"ball": cone_centre + Vector3(cone_length + 1.0, 0, 0), "delta_s": 0.0})
	t.check("control (a): doubled damage length makes the outside probe take damage", w.ctx.run.mass < before,
		"mass %d -> %d" % [before, w.ctx.run.mass])
	w.free()
	w = _world([cone_row], sites)
	_drive(w, CONE, false)
	industrial = w.event_families.industrial
	industrial.damage_length_scale = 1.0
	before = w.ctx.run.mass
	industrial.handle("step", cone_row, {"ball": cone_centre + Vector3(cone_length + 1.0, 0, 0), "delta_s": 0.0})
	t.eq("control (a) restored: the outside probe takes none again", w.ctx.run.mass, before)
	w.free()

	# Ring: the authored band, then probes on a test-only inner radius.
	var ring_row := _row(rows, RING)
	var ring_site := _site(sites, ring_row.site)
	var ring_centre := Vector3(float(ring_site.at[0]), 0.0, float(ring_site.at[1]))
	var ring_outer := float(ring_row.effect.hazard_m[0])
	w = _world([ring_row], sites)
	_drive(w, RING, false)
	var hazard = w.event_families.industrial.active.get(RING, {}).get("hazard")
	# Strict band: the authored row must commit a real annulus (r_out > r_in). It fails while the
	# authored annex_reactor_blow row is zero width (hazard_m [20,20]); the owner ruling fixes the row.
	t.check("fallout_ring commits its authored [outer, inner] band as a real annulus (owner ruling pending on annex_reactor_blow)",
		hazard != null and hazard.r_out == ring_outer and hazard.r_in == float(ring_row.effect.hazard_m[1]) and hazard.r_out > hazard.r_in,
		"r_in %s r_out %s" % [hazard.r_in if hazard != null else "none", hazard.r_out if hazard != null else "none"])
	w.free()

	var ring_probe_row := ring_row.duplicate(true)
	ring_probe_row.effect.hazard_m = [ring_outer, RING_PROBE_INNER_M]
	w = _world([ring_probe_row], sites)
	_drive(w, RING, false)
	industrial = w.event_families.industrial
	before = w.ctx.run.mass
	industrial.handle("step", ring_probe_row, {"ball": ring_centre + Vector3(17.0, 0, 0), "delta_s": 0.0})
	t.check("ring probe inside takes exactly the row damage", before - w.ctx.run.mass == damage,
		"mass %d -> %d" % [before, w.ctx.run.mass])
	w.free()
	w = _world([ring_probe_row], sites)
	_drive(w, RING, false)
	industrial = w.event_families.industrial
	before = w.ctx.run.mass
	industrial.handle("step", ring_probe_row, {"ball": ring_centre + Vector3(ring_outer + 1.0, 0, 0), "delta_s": 0.0})
	t.eq("ring probe 1 m outside its outer radius takes none", w.ctx.run.mass, before)
	w.free()

	# Seeded control (b): without the declared swap, the overlay check goes red; then the restored landing.
	var declared := String(cone_row.effect.swap)
	var no_swap := cone_row.duplicate(true)
	no_swap.effect.erase("swap")
	w = _world([no_swap], sites)
	_drive(w, CONE, false)
	t.check("control (b): skipping the overlay makes the swap check red", not w.terrain.overlays.has(declared + "_after"),
		str(w.terrain.overlays))
	w.free()
	w = _world([cone_row], sites)
	_drive(w, CONE, false)
	t.check("control (b) restored: the declared swap lands", w.terrain.overlays.has(declared + "_after"), declared)
	w.free()

	# Release order (families.gd builds natural before industrial, so natural releases first): a
	# landed swap must not break industrial's release, and its hazard must be freed.
	w = _world([cone_row], sites, true)
	_drive(w, CONE, false)
	industrial = w.event_families.industrial
	var live_hazard = industrial.active.get(CONE, {}).get("hazard")
	var was_live := is_instance_valid(live_hazard)
	var spy = w.event_families.natural
	spy.release()
	industrial.release()
	t.check("industrial release makes no overlay call into a released natural (calls %d)" % spy.release_end_calls,
		was_live and spy.release_end_calls == 0 and not is_instance_valid(live_hazard),
		"live before %s, overlay calls after natural release %d" % [str(was_live), spy.release_end_calls])
	w.free()

	t.check("test executes its expected checks", t.checks == EXPECTED_BEFORE_FINAL, str(t.checks))
	quit(t.verdict())
