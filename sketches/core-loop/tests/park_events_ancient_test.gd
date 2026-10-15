extends SceneTree

# KE4 Ancient machines erupt. Each machine_eruption row in the fixture runs in its own stepped
# director, because an ancient row holds the one ancient slot until it ends (event_director.gd
# _park_capacity). Per row: it telegraphs and does nothing live before it lands; it lands within
# the run; the stage spawner gets one call for its miniboss kind at the site; its swap overlay
# (effect.swap) is in terrain.overlays and its body is visible after land; the started fact
# answers its routes. The spawner records calls and validates kinds against combat's own tables.
# Combat AI and physics are outside this bounded handler test. No natural handler is installed.

const T := preload("res://tests/support/t.gd")
const Director := preload("res://src/world/event_director.gd")
const Ancient := preload("res://src/world/events/ancient.gd")
const Combat := preload("res://src/combat/combat.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

const FIXTURE := "res://tests/fixtures/park_events_ancient_rows.json"
const H := 0.05
const BAR := 240.0 / 172.0
const FAR := Vector3(1000.0, 1.0, 1000.0)
const MAX_STEPS := 6000
const ROW_COUNT := 6
# Fixture, rejecting spawner, ten checks per row, route totals and count guard.
const EXPECTED_CHECKS := 66

var t := T.new("park_events_ancient_test")
var closes_total := 0
var opens_total := 0


class StubSpawner extends RefCounted:
	var calls: Array = []
	var fleet := Combat.Fleet.new()

	func spawn_enemy(kind: String, at: Vector3, _affix_id := "") -> Node3D:
		if kind not in Combat.KINDS and not fleet.makes(kind):
			return null
		var node := Node3D.new()
		node.position = at
		calls.append({"kind": kind, "at": at, "node": node})
		return node


class FakeTerrain extends RefCounted:
	var stage := 1
	var maps: Array = []
	var overlays: Array = []
	var flood = null
	var drops: Array = []

	func _init(map) -> void:
		maps = [map]

	func map():
		return maps[stage - 1]

	func height(x: float, z: float) -> float:
		var ground := 12.0 + 0.05 * x - 0.03 * z
		for id in overlays:
			ground = maxf(ground, map().overlay_height(id, x, z, ground))
		return ground

	func drop_point(x: float, z: float, clearance: float) -> Vector3:
		drops.append({"x": x, "z": z, "clearance": clearance})
		return Vector3(x, height(x, z) + clearance, z)


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
	var reject := StubSpawner.new()
	t.check("spawner rejects a kind combat cannot spawn", reject.spawn_enemy("unknown_ancient", Vector3.ZERO) == null and reject.calls.is_empty())
	reject.fleet.free()
	for row in rows:
		_drive(row, fixture.park_rows, fixture.routes_by_row[row.id])
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


func _drive(row: Dictionary, park_sites: Array, routes: Array) -> void:
	var site_row := _site(park_sites, str(row.site))
	var swap := str(row.effect.get("swap", row.id))
	var map := ParkMap.new()
	map.park = {"map": "fixture", "event_rows": [row], "weather_rows": [],
		"park_rows": [site_row], "routes": routes}
	var terrain := FakeTerrain.new(map)
	var ctx := FakeCtx.new()
	var spawner := StubSpawner.new()
	ctx.spawner = spawner
	var world := FakeWorld.new()
	world.terrain = terrain
	world.ctx = ctx
	var ancient := Ancient.new()
	ancient.setup(world)
	var director := Director.new(813, {}, map, 14.0, Callable(terrain, "height"))
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
	if "swaps" in terrain.map():
		entry = terrain.map().swaps.get(swap, {})
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
	var grounded := calls.size() == 1 and terrain.drops.size() == 1
	if grounded:
		grounded = is_equal_approx(float(terrain.drops[0].clearance), 2.4) \
			and calls[0].node.position.is_equal_approx(Vector3(site_at.x, terrain.height(site_at.x, site_at.y) + 2.4, site_at.y))
	t.check("%s miniboss uses terrain.drop_point with field clearance" % row.id, grounded, "drops %s calls %s" % [terrain.drops, calls])
	var opened := 0
	var closed := 0
	for id in row.route_change.opens:
		if director.has_method("route_open") and director.call("route_open", str(id)):
			opened += 1
	for id in row.route_change.closes:
		if director.has_method("route_open") and not director.call("route_open", str(id)):
			closed += 1
	t.eq("%s director opens routes after land" % row.id, opened, row.route_change.opens.size())
	t.eq("%s director closes routes after land" % row.id, closed, row.route_change.closes.size())
	closes_total += closed
	opens_total += opened
	# Free every node this run made, so the exit prints no leak lines.
	director.end_all()
	t.check("%s end removes its swap without a natural handler" % row.id, not terrain.overlays.has(swap + "_after"))
	ancient.release()
	for call in calls:
		call.node.free()
	ancient.free()
	spawner.fleet.free()
	ctx.root.free()
	ctx.events.free()
