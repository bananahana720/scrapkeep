extends SceneTree

# Rule: stage 3, park_pit (world 2, The Dig; design-v3/park/stages/3-park_pit.md), ships as built. The committed bake
# and stage graph are fresh against park_pit.json; the waymarks run drop_in, canal_lip, switchback_camp, landmark; the
# four pockets keep their PARK.md 2.12 roles (cache_lip reward, switchback_camp_site on-line, bench3_altar risk,
# adit_valve hidden) with no breach and the reward's detour longer than the risk's; every route is connected and the
# spawn lies in the farthest quarter; the landmark is the 120 m headframe over the 100 m pit with the swarm Warden on
# its headframe mounting, harpoon anchor on; and every waypoint of tools/park_lines/park_pit.json resolves, six
# pilots and the floor, each line from drop_in through the waymarks in order to landmark, each point on an open
# graph node with a finite path to the beacon. Three planted controls run first: a moved row turns the bake stale, a
# swapped waymark order fails the order pin, a waypoint off the play square fails to resolve. K-UNITS KD3,
# greybox pass, 2026-10-11.

const T := preload("res://tests/support/t.gd")

const MAP := "park_pit"
const PARK := "res://src/world/park/park_pit.json"
const BAKED := "res://assets/park/park_pit"
const LINES := "res://tools/park_lines/park_pit.json"
const SCRATCH := "user://park_park_pit_test"
const BAKE_TOOL := "res://tools/park_bake.gd"
const GRAPH_TOOL := "res://tools/park_graph.gd"
const LOADER := "res://src/world/park/park_graph.gd"
const WAYMARKS := ["drop_in", "canal_lip", "switchback_camp", "landmark"]
const ROLES := {"cache_lip": "reward", "switchback_camp_site": "online", "bench3_altar": "risk", "adit_valve": "hidden"}
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]
const HALF := 800.0

var t := T.new("park_park_pit_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not t.check("bake tool, graph tool and loader exist",
			ResourceLoader.exists(BAKE_TOOL) and ResourceLoader.exists(GRAPH_TOOL) and ResourceLoader.exists(LOADER)):
		quit(t.verdict())
		return
	var bake: GDScript = load(BAKE_TOOL)
	var tool: GDScript = load(GRAPH_TOOL)
	var loader: GDScript = load(LOADER)
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LINES))
	var graph = loader.read(BAKED + "/graph.bin")
	if not t.check("park file, lines file and graph.bin load", park != null and lines != null and graph != null):
		quit(t.verdict())
		return

	# Planted controls: each must go red before its pin's green is trusted.
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	var moved := park.duplicate(true)
	for row in moved["park_rows"]:
		if row["id"] == "rim_road_berm":
			row["at"] = [row["at"][0] + 20.0, row["at"][1]]
	var planted := FileAccess.open(SCRATCH + "/moved.json", FileAccess.WRITE)
	planted.store_string(JSON.stringify(moved))
	planted.close()
	t.check("planted: a moved row turns the committed bake stale", not bake.freshness(SCRATCH + "/moved.json", BAKED).is_empty())
	var swapped := park.duplicate(true)
	swapped["waymarks"] = ["drop_in", "switchback_camp", "canal_lip", "landmark"]
	t.check("planted: a swapped waymark order fails the sable line", not _resolve(graph, swapped, lines["pilots"]["sable"]).is_empty())
	var off := {"waypoints": ["drop_in", [900.0, 0.0], "canal_lip", "switchback_camp", "landmark"]}
	t.check("planted: a waypoint off the play square fails to resolve", not _resolve(graph, park, off).is_empty())

	# Freshness: the committed bake and graph match park_pit.json byte for byte.
	t.eq("committed bake is fresh", bake.freshness(PARK, BAKED), [])
	t.eq("committed graph is fresh", tool.freshness(PARK, BAKED, BAKED), [])

	# The waymarks, in order.
	t.eq("waymark order", park["waymarks"], WAYMARKS)

	# Graph rules: routes, spawn, pockets.
	t.eq("every route connected", tool.route_breaks(graph, park), [])
	t.check("spawn in the farthest quarter", tool.spawn_check(graph, park)["ok"])
	var ruling: Dictionary = tool.pockets(graph, park)
	var roles := {}
	var detour := {}
	for row in ruling["rows"]:
		roles[row["id"]] = row["role"]
		detour[row["role"]] = float(row.get("detour_m", 0.0))
	t.eq("pocket roles", roles, ROLES)
	t.eq("no 2.12 breach", ruling["breaches"], [])
	t.check("reward detour longer than risk", detour.get("reward", 0.0) > detour.get("risk", INF), str(detour))

	# The landmark and its Warden.
	var mark: Dictionary = park["landmark"]
	t.eq("landmark kind", mark["kind"], "headframe")
	t.eq("landmark at", mark["at"], [0.0, 255.0])
	t.eq("headframe height", float(mark["size"][1]), 120.0)
	t.eq("sight share", float(mark["sight_share"]), 0.85)
	var warden: Dictionary = mark["warden"]
	t.eq("warden family", warden["family"], "swarm")
	t.eq("warden mounting", warden["mounting"], "headframe")
	t.eq("warden harpoon anchor", warden["harpoon_anchor"], true)

	# The lines file.
	t.eq("lines map", lines["map"], MAP)
	t.eq("lines stage", int(lines["stage"]), 3)
	t.eq("six pilots", lines["pilots"].keys(), PILOTS)
	for pilot in PILOTS:
		t.eq("%s line resolves" % pilot, _resolve(graph, park, lines["pilots"][pilot]), [])
	t.eq("floor line resolves", _resolve(graph, park, lines["floor"]), [])
	quit(t.verdict())


# Errors for one line: waymark ids in order from drop_in to landmark, every point inside the play square on an open
# graph node with a finite path to the beacon.
func _resolve(graph, park: Dictionary, line: Dictionary) -> Array:
	var out := []
	var named := []
	var open_bit := 1
	for point in line["waypoints"]:
		if point is String:
			if not park["waymarks"].has(point):
				out.append("%s is no waymark" % point)
			named.append(point)
			continue
		var p := Vector2(float(point[0]), float(point[1]))
		if absf(p.x) > HALF or absf(p.y) > HALF:
			out.append("%s is off the play square" % str(point))
			continue
		var n: int = graph.nearest(p)
		if graph.flags(n) & open_bit == 0:
			out.append("%s is on no open node" % str(point))
		elif graph.d_landmark_node(n) == INF:
			out.append("%s has no path to the beacon" % str(point))
	if named != park["waymarks"]:
		out.append("waymarks named %s" % str(named))
	return out
