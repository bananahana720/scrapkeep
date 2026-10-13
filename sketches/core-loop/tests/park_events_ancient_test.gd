extends SceneTree

# KE4 Ancient machines erupt. Each machine_eruption row in the fixture runs in its own stepped
# director, because an ancient row holds the one ancient slot until it ends (event_director.gd
# _park_capacity). Per row: it telegraphs and does nothing live before it lands; it lands within
# the run; the stage spawner gets one call for its miniboss kind at the site; its swap overlay
# (effect.swap) is in terrain.overlays and its body is visible after land; the started fact
# carries its route_change. The spawner is a recording stub: the real combat spawn is not run.

const T := preload("res://tests/support/t.gd")
const Director := preload("res://src/world/event_director.gd")
const Ancient := preload("res://src/world/events/ancient.gd")
const Natural := preload("res://src/world/events/natural.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

const FIXTURE := "res://tests/fixtures/park_events_ancient_rows.json"
const ROUTES := [{"id": "main", "from": "drop_in", "to": "landmark", "via": []}]
const H := 0.05
const BAR := 240.0 / 172.0
const FAR := Vector3(1000.0, 1.0, 1000.0)
const MAX_STEPS := 6000
const ROW_COUNT := 6
# 1 fixture read, 1 row count, 7 per row, 2 route totals, 1 count check.
const EXPECTED_CHECKS := 47

var t := T.new("park_events_ancient_test")
var closes_total := 0
var opens_total := 0


class StubSpawner extends RefCounted:
	var calls: Array = []

	func spawn_enemy(kind: String, at: Vector3) -> Node3D:
		var node := Node3D.new()
		calls.append({"kind": kind, "at": at, "node": node})
		return node


class FakeTerrain extends RefCounted:
	var stage := 1
	var maps: Array = []
	var overlays: Array = []
	var flood = null

	func _init(map) -> void:
		maps = [map]

	func map():
		return maps[stage - 1]

	func height(_x: float, _z: float) -> float:
		return 0.0


class FakeCtx extends RefCounted:
	var root := Node3D.new()
	var events := Node.new()
	var spawner
	var calm := false


class FakeWorld extends RefCounted:
	var terrain
	var ctx
	var event_families := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture := _read_fixture()
	t.check("fixture reads as a JSON object", not fixture.is_empty(), FIXTURE)
	if fixture.is_empty():
		quit(t.verdict())
		return
	var rows: Array = fixture.event_rows
	t.eq("fixture holds six ancient rows", rows.size(), ROW_COUNT)
	for row in rows:
		_drive(row, fixture.park_rows)
	t.eq("route closes counted across the six rows", closes_total, 2)
	t.eq("route opens counted across the six rows", opens_total, 2)
	t.eq("test runs its expected check count", t.checks + 1, EXPECTED_CHECKS)
	quit(t.verdict())


func _read_fixture() -> Dictionary:
	var file := FileAccess.open(FIXTURE, FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}


func _site(park_sites: Array, id: String) -> Dictionary:
	for site in park_sites:
		if site.id == id:
			return site
	return {}


func _drive(row: Dictionary, park_sites: Array) -> void:
	var site_row := _site(park_sites, str(row.site))
	var swap := str(row.effect.get("swap", row.id))
	var map := ParkMap.new()
	map.park = {"map": "fixture", "event_rows": [row], "weather_rows": [],
		"park_rows": [site_row], "routes": ROUTES}
	var terrain := FakeTerrain.new(map)
	var ctx := FakeCtx.new()
	var spawner := StubSpawner.new()
	ctx.spawner = spawner
	var world := FakeWorld.new()
	world.terrain = terrain
	world.ctx = ctx
	var natural := Natural.new()
	natural.setup(world)
	world.event_families = {"natural": natural}
	var ancient := Ancient.new()
	ancient.setup(world)
	var director := Director.new(813, {}, map, 14.0, func(_x, _z): return 0.0)
	director.register_family("ancient", Callable(ancient, "handle"))
	var announced := false
	var landed_fact = null
	var early := false
	for _step in MAX_STEPS:
		var facts: Array = director.advance(H, FAR, Vector3.ZERO,
			{"clock_tier": 4, "grounded": true, "bar_s": BAR, "bar_origin_s": 0.0})
		for fact in facts:
			if fact.id != row.id:
				continue
			if fact.kind == "announced":
				announced = true
			elif fact.kind == "started" and landed_fact == null:
				landed_fact = fact
		if landed_fact != null:
			break
		early = early or terrain.overlays.has(swap + "_after") or not spawner.calls.is_empty()
	var landed := landed_fact != null
	var site_at := Vector2(float(site_row.at[0]), float(site_row.at[1]))
	var entry: Dictionary = {}
	if natural._overlay_map != null:
		entry = natural._overlay_map.swaps.get(swap, {})
	var body = entry.get("body")
	var calls: Array = spawner.calls
	var kind := str(row.effect.get("miniboss", ""))
	t.check("%s telegraphs and then lands" % row.id, announced and landed, "announced=%s landed=%s" % [announced, landed])
	t.check("%s is silent before land" % row.id, not early)
	t.check("%s lands within the run" % row.id, landed, "steps cap %d" % MAX_STEPS)
	var spawned_kind := calls.size() == 1 and str(calls[0].kind) == kind
	t.check("%s spawns one %s at land" % [row.id, kind], spawned_kind, "spawn calls %d" % calls.size())
	var near := calls.size() == 1 and is_instance_valid(calls[0].node) \
		and Vector2(calls[0].at.x, calls[0].at.z).distance_to(site_at) <= float(row.hold_clear_m)
	t.check("%s miniboss stands within hold_clear_m of the site" % row.id, near, "hold_clear_m %s" % row.hold_clear_m)
	var swap_on: bool = terrain.overlays.has(swap + "_after") and is_instance_valid(body) and body.visible
	t.check("%s swap %s is on after land" % [row.id, swap], swap_on, "overlays %s" % str(terrain.overlays))
	var closes: Array = landed_fact.route_change.closes if landed else []
	var opens: Array = landed_fact.route_change.opens if landed else []
	t.check("%s route_change on the started fact matches the row" % row.id,
		landed and closes == row.route_change.closes and opens == row.route_change.opens,
		"closes %s opens %s" % [str(closes), str(opens)])
	closes_total += closes.size()
	opens_total += opens.size()
	# Free every node this run made, so the exit prints no leak lines.
	ancient.release()
	natural.release()
	for call in calls:
		call.node.free()
	ancient.free()
	natural.free()
	ctx.root.free()
	ctx.events.free()
