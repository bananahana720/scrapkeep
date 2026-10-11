extends SceneTree

# Rule: the stage graph (design-v3/PARK.md 2.11, K-UNITS KB8) is the stage's one measured space.
# The committed graph of park_test is fresh and a rebuild reproduces it byte for byte; a park or
# bake.json edit without a rerun goes stale; the runtime loader answers nearest, path_m, flags,
# d_landmark and d_spawn from graph.bin; every fixture route is connected through its via rows
# on the committed graph (canal climbs onto the bench by bench_ramp), and a planted wall across
# main breaks main; a planted route that crosses a full-width trench
# only by a kicker onto a raised deck and climbs back out by a thermal is connected, and the same
# route without the kicker is not; the spawn's d_landmark lies in the farthest quarter of open
# nodes, and a spawn planted 100 m from the beacon fails. The beacon sits on an objective-fit
# node (tool.beacon_check, design-v3/PARK.md 2.11, SR15): every ground node of a flat disc
# round the beacon is open and within BEACON_FLAT_M of the beacon's height, the disc radius
# derived from the engage ring (reach_m). The fixture beacon passes and a beacon planted under
# the service ledge, and one planted on the bench's sheer edge, fail. stage_checks runs the
# beacon rule before the spawn rule and names the first rule that failed; the spawn rule is not
# run once the beacon fails. The fixture file is never edited: the
# planted parks are written to user:// and baked there.

const T := preload("res://tests/support/t.gd")

const PARK := "res://src/world/park/park_test.json"
const BAKED := "res://assets/park/park_test"
const SCRATCH := "user://park_graph_test"
const TOOL := "res://tools/park_graph.gd"
const LOADER := "res://src/world/park/park_graph.gd"
const BAKE_TOOL := "res://tools/park_bake.gd"
const ROUTES := ["main", "canal", "ledge", "pool_floor", "pool_rim"]

var t := T.new("park_graph_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not t.check("graph tool and loader exist", ResourceLoader.exists(TOOL) and ResourceLoader.exists(LOADER)):
		quit(t.verdict())
		return
	var tool: GDScript = load(TOOL)
	var loader: GDScript = load(LOADER)
	var bake: GDScript = load(BAKE_TOOL)
	DirAccess.make_dir_recursive_absolute(SCRATCH)

	var stale: Array = tool.freshness(PARK, BAKED, BAKED)
	t.check("committed graph is fresh", stale.is_empty(), str(stale))

	# Two runs give identical bytes: a rebuild here matches the committed (CLI) run.
	var again: Dictionary = tool.run(PARK, BAKED, SCRATCH + "/again")
	t.check("rebuild succeeds", again["ok"], str(again["errors"]))
	for name in ["graph.bin", "graph.json"]:
		var a := FileAccess.get_file_as_bytes(BAKED + "/" + name)
		var b := FileAccess.get_file_as_bytes(SCRATCH + "/again/" + name)
		t.check("rebuild is byte-identical: " + name, not a.is_empty() and a == b, "%d vs %d bytes" % [a.size(), b.size()])

	_stale(tool)
	var graph = loader.read(BAKED + "/graph.bin")
	if not t.check("graph.bin loads", graph != null):
		quit(t.verdict())
		return
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	_loader(graph, park)
	_routes(tool, graph, park)
	_spawn(tool, graph, park)
	_beacon(tool, graph, park)
	_wall(tool, bake, park)
	_ride(tool, bake, park)
	quit(t.verdict())


# The park file or bake.json changing without a rerun makes the graph stale, naming the hash.
func _stale(tool: GDScript) -> void:
	var text := FileAccess.get_file_as_string(PARK)
	var edited := text.replace('"at": [240, -120]', '"at": [244, -120]')
	t.check("the park edit changes one row", edited != text)
	_write(SCRATCH + "/edited.json", edited.to_utf8_buffer())
	var stale: Array = tool.freshness(SCRATCH + "/edited.json", BAKED, BAKED)
	t.check("park edit without a rerun is stale", str(stale).contains("park_sha256"), str(stale))

	var bake_json := FileAccess.get_file_as_bytes(BAKED + "/bake.json")
	DirAccess.make_dir_recursive_absolute(SCRATCH + "/bake_edit")
	var changed := bake_json.duplicate()
	changed.append(10)
	_write(SCRATCH + "/bake_edit/bake.json", changed)
	stale = tool.freshness(PARK, SCRATCH + "/bake_edit", BAKED)
	t.check("bake.json edit without a rerun is stale", str(stale).contains("bake_sha256"), str(stale))

	# A rerun on the edited park is fresh again.
	var rerun: Dictionary = tool.run(SCRATCH + "/edited.json", BAKED, SCRATCH + "/rerun")
	t.check("rerun on the edited park succeeds", rerun["ok"], str(rerun["errors"]))
	stale = tool.freshness(SCRATCH + "/edited.json", BAKED, SCRATCH + "/rerun")
	t.check("after the rerun it is fresh", stale.is_empty(), str(stale))


# The loader answers from graph.bin alone, and its answers agree with each other.
func _loader(graph, park: Dictionary) -> void:
	t.check("graph has the 201 by 201 ground lattice and more", graph.node_count() > 201 * 201, str(graph.node_count()))
	t.check("graph has edges", graph.edge_count() > 8 * 201 * 190, str(graph.edge_count()))
	var spawn_at := Vector2(park["spawn"]["at"][0], park["spawn"]["at"][1])
	var beacon := Vector2(park["landmark"]["beacon"][0], park["landmark"]["beacon"][1])
	var s: int = graph.nearest(spawn_at)
	var b: int = graph.nearest(beacon)
	var sp: Vector3 = graph.position(s)
	t.check("nearest(spawn) is within one lattice step", Vector2(sp.x, sp.z).distance_to(spawn_at) <= 5.7, str(sp))
	t.near("d_spawn at the spawn is 0", graph.d_spawn(spawn_at), 0.0, 0.001)
	t.near("d_landmark at the beacon is 0", graph.d_landmark(beacon), 0.0, 0.001)
	var whole: float = graph.path_m(s, b)
	t.near("path_m(spawn, beacon) equals d_landmark(spawn)", whole, graph.d_landmark(spawn_at), 0.01)
	t.near("path_m(spawn, beacon) equals d_spawn(beacon)", whole, graph.d_spawn(beacon), 0.01)
	t.check("the spawn-to-beacon path is longer than the straight line", whole >= spawn_at.distance_to(beacon) - 8.0, "%.1f m" % whole)
	t.check("the beacon is a warden node", graph.flags(b) & loader_flag(graph, "WARDEN") != 0)
	t.check("the spawn is a line node", graph.flags(s) & loader_flag(graph, "LINE") != 0)
	# The tube is a hole: its nodes are not open; the canal lip row is hohokam: guarded.
	var tube: int = graph.nearest(Vector2(100, 300))
	t.check("a tube node is not open", graph.flags(tube) & loader_flag(graph, "OPEN") == 0, str(graph.flags(tube)))
	var canal: int = graph.nearest(Vector2(150, -200))
	t.check("a canal lip node is guarded", graph.flags(canal) & loader_flag(graph, "GUARDED") != 0, str(graph.flags(canal)))
	t.check("a guarded node is never door_ok", graph.flags(canal) & loader_flag(graph, "DOOR_OK") == 0)
	# The raised ledge is a deck of its own at its y.
	var ledge: int = graph.nearest(Vector3(-200, 20, 200))
	t.near("the service ledge deck stands at its y", graph.position(ledge).y, 20.0, 0.001)


func loader_flag(graph, name: String) -> int:
	return int(graph.get_script().get(name))


# The fixture as committed: the bench is a 6 m plateau with a sheer edge (park_stamps.gd: one
# grid step of slope), and bench_ramp falls 6 m from the bench's west edge (x 199) to x 160, so
# canal climbs from the tube onto the bench and every fixture route is connected through its via
# rows on the committed graph.
func _routes(tool: GDScript, graph, park: Dictionary) -> void:
	var checked: Array = tool.route_steps(graph, park).keys()
	checked.sort()
	var want := ROUTES.duplicate()
	want.sort()
	t.eq("the route check walked every fixture route", checked, want)
	t.eq("on the committed fixture every route is connected", tool.route_breaks(graph, park), [])


func _spawn(tool: GDScript, graph, park: Dictionary) -> void:
	var fixture: Dictionary = tool.spawn_check(graph, park)
	t.check("fixture spawn is in the farthest quarter of open nodes", fixture["ok"], str(fixture))
	var planted := park.duplicate(true)
	planted["spawn"]["at"] = [0, 475]
	var near: Dictionary = tool.spawn_check(graph, planted)
	t.check("a spawn planted 100 m from the beacon fails", not near["ok"], str(near))


# SR15: the beacon rule, and the order beacon then spawn.
func _beacon(tool: GDScript, graph, park: Dictionary) -> void:
	var fixture: Dictionary = tool.beacon_check(graph, park)
	t.check("the fixture beacon passes beacon_ok", fixture.get("ok", false), str(fixture))
	t.near("the disc radius derives from the engage ring", float(fixture.get("radius_m", -1.0)),
		float(park["landmark"]["reach_m"]) * float(tool.BEACON_DISC_SHARE), 0.001)
	t.check("the disc holds ground nodes", int(fixture.get("nodes", 0)) > 8, str(fixture.get("nodes")))
	print("[beacon_ok] radius %.1f m, %d nodes, rise %.2f m (flat at most %.1f m)" % [
		float(fixture.get("radius_m", -1.0)), int(fixture.get("nodes", 0)), float(fixture.get("rise_m", -1.0)), float(tool.BEACON_FLAT_M)])

	# Planted: the beacon under the service ledge (a deck 20 m up roofs the ground below it).
	var ledge := park.duplicate(true)
	ledge["landmark"]["beacon"] = [-200, 200]
	var under: Dictionary = tool.beacon_check(graph, ledge)
	t.check("a beacon planted under the ledge fails beacon_ok", not under.get("ok", true), str(under))

	# Planted: the beacon on the bench's sheer edge (a 6 m step inside the disc).
	var edge := park.duplicate(true)
	edge["landmark"]["beacon"] = [199, -120]
	var step: Dictionary = tool.beacon_check(graph, edge)
	t.check("a beacon planted on the bench edge fails beacon_ok", not step.get("ok", true), str(step))

	# The order: beacon first, spawn second, and the first failure is named.
	var good: Dictionary = tool.stage_checks(graph, park)
	t.eq("on the fixture both rules run in order, beacon then spawn", good.get("checked"), ["beacon_ok", "spawn"])
	t.check("on the fixture no rule failed", good.get("ok", false) and good.get("first_failed") == "", str(good))
	var both := ledge.duplicate(true)
	both["spawn"]["at"] = [0, 475]
	var bad: Dictionary = tool.stage_checks(graph, both)
	t.eq("a bad beacon and a bad spawn name the beacon first", bad.get("first_failed"), "beacon_ok")
	t.eq("the spawn rule is not run after the beacon fails", bad.get("checked"), ["beacon_ok"])
	var spawn_only := park.duplicate(true)
	spawn_only["spawn"]["at"] = [0, 475]
	var later: Dictionary = tool.stage_checks(graph, spawn_only)
	t.eq("a bad spawn alone is named second", later.get("first_failed"), "spawn")
	t.eq("both rules ran when the beacon passed", later.get("checked"), ["beacon_ok", "spawn"])


# A full-width wall row across z -115, between run_wash and lip, baked in scratch.
func _wall(tool: GDScript, bake: GDScript, park: Dictionary) -> void:
	var planted := park.duplicate(true)
	planted["park_rows"].append(_row("planted_wall", "ground", [0, -115], null, [1700, 200, 10], 90, "plateau", []))
	var graph = _bake_build(tool, bake, planted, "wall")
	if graph == null:
		return
	var breaks: Array = tool.route_breaks(graph, planted)
	var broken := []
	for b in breaks:
		broken.append(b["route"])
	t.check("a wall across main breaks main", broken.has("main"), str(breaks))
	t.check("the routes beyond the wall stay connected", not broken.has("ledge") and not broken.has("pool_rim"), str(breaks))


# A full-width trench (channel, z 120 to 180, floor 30 m down) that no ground edge climbs out
# of. Rim A to rim B: the kicker on rim A lands on a deck floating over the trench (y 20, more
# than 11.4 m from either rim), the deck drops to the trench floor, and a thermal by the north
# wall climbs back to rim B. Without the kicker, rim A never reaches the deck.
func _ride(tool: GDScript, bake: GDScript, park: Dictionary) -> void:
	var planted := park.duplicate(true)
	var rows: Array = planted["park_rows"]
	rows.append(_row("trench", "flow_line", [0, 150], null, [1800, 30, 60], 90, "channel", ["gap_ride"]))
	rows.append(_row("rim_a", "ground", [500, 90], null, [40, 1, 40], 0, "", ["gap_ride"]))
	rows.append(_row("gap_kicker", "kicker", [500, 110], null, [10, 2, 20], 0, "", ["gap_ride"]))
	rows.append(_row("gap_deck", "ledge", [500, 150], 20, [16, 2, 16], 0, "", ["gap_ride"]))
	rows.append(_row("rim_b", "ground", [500, 220], null, [40, 1, 40], 0, "", ["gap_ride"]))
	planted["contraption_rows"].append({"id": "gap_thermal", "kind": "thermal", "site": "trench", "recipe": "",
		"at": [498, 170], "radius": 6.0, "height": 40.0})
	planted["routes"].append({"id": "gap_ride", "from": "rim_a", "to": "rim_b", "via": ["gap_kicker", "gap_deck", "trench"]})
	var graph = _bake_build(tool, bake, planted, "ride")
	if graph == null:
		return
	var steps: Dictionary = tool.route_steps(graph, planted)
	t.eq("the kicker-and-thermal route is connected", steps.get("gap_ride", ["missing"]), [])

	var without := planted.duplicate(true)
	var kept := []
	for row in without["park_rows"]:
		if row["id"] != "gap_kicker":
			kept.append(row)
	without["park_rows"] = kept
	for route in without["routes"]:
		if route["id"] == "gap_ride":
			route["via"] = ["gap_deck", "trench"]
	# The kicker row has no stamp, so the bake is the same; only the graph changes.
	var bake_data: Dictionary = tool.load_bake(SCRATCH + "/ride")
	var built: Dictionary = tool.build(without, bake_data, {"sight": false})
	if not t.check("the route without the kicker builds", built["errors"].is_empty(), str(built["errors"])):
		return
	var gone: Dictionary = tool.route_steps(built["graph"], without)
	t.check("without the kicker the route breaks at the deck", str(gone.get("gap_ride", [])).contains("gap_deck"), str(gone.get("gap_ride")))

	# And the climb out is the thermal's: without it the trench floor never reaches rim B.
	var grounded := planted.duplicate(true)
	var kept_rows := []
	for row in grounded["contraption_rows"]:
		if row["id"] != "gap_thermal":
			kept_rows.append(row)
	grounded["contraption_rows"] = kept_rows
	var no_lift: Dictionary = tool.build(grounded, bake_data, {"sight": false})
	var stuck: Dictionary = tool.route_steps(no_lift["graph"], grounded)
	t.eq("without the thermal the route breaks climbing out of the trench", stuck.get("gap_ride"), ["trench -> rim_b: no path"])


func _bake_build(tool: GDScript, bake: GDScript, park: Dictionary, name: String):
	var path := "%s/%s.json" % [SCRATCH, name]
	_write(path, JSON.stringify(park, " ").to_utf8_buffer())
	var baked: Dictionary = bake.bake(path, "%s/%s" % [SCRATCH, name])
	if not t.check("planted %s park bakes" % name, baked["ok"], str(baked["errors"])):
		return null
	var built: Dictionary = tool.build(park, tool.load_bake("%s/%s" % [SCRATCH, name]), {"sight": false})
	if not t.check("planted %s park builds" % name, built["errors"].is_empty(), str(built["errors"])):
		return null
	return built["graph"]


func _row(id: String, element: String, at: Array, y, size: Array, yaw: float, stamp: String, routes: Array) -> Dictionary:
	var verbs := {"ground": "roll", "flow_line": "roll", "kicker": "launch", "ledge": "roll"}
	var facts := {"ground": "", "flow_line": "ride_chute", "kicker": "kicker_launch", "ledge": "ride_ledge"}
	return {"id": id, "element": element, "landform": "slickrock", "society": "none", "at": at, "y": y,
		"size": size, "yaw_deg": yaw, "verb": verbs[element], "ride_fact": facts[element], "home": "",
		"recipe": "", "stamp": stamp, "hole": false, "budget": "landform", "routes": routes, "fragment": ""}


func _write(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
