extends SceneTree

# Rule: stage 3, park_pit (world 2, The Dig; design-v3/park/stages/3-park_pit.md), ships as built. The committed bake
# and stage graph are fresh against park_pit.json; the waymarks run drop_in, canal_lip, switchback_camp, landmark; the
# four pockets keep their PARK.md 2.12 roles (cache_lip reward, switchback_camp_site on-line, bench3_altar risk,
# adit_valve hidden) with no breach and the reward's detour longer than the risk's; every route is connected and the
# spawn lies in the farthest quarter; the landmark is the 120 m headframe over the 100 m pit with the swarm Warden on
# its headframe mounting, harpoon anchor on; and every waypoint of assets/park/park_pit/lines.json resolves, six
# pilots and the floor, each line from drop_in through the waymarks in order to landmark, each point on an open
# graph node with a finite path to the beacon. Three planted controls run first: a moved row turns the bake stale, a
# swapped waymark order fails the order pin, a waypoint off the play square fails to resolve. K-UNITS KD3,
# greybox pass, 2026-10-11. Fix round, 2026-10-11: the reward pocket stands at least 150 m in a straight line from
# every pilot and floor line, and the Kest line crosses dust_devil_floor's column; each has its planted control.
# Fix round, 2026-10-12: named waypoints receive the numeric-point checks; a moved canal_lip pins the bounds error.
# Authored pass, 2026-10-17 (one skill per park: the pit tests abilities in close quarters): the beacon sight check
# passes on the headframe mounting, and a planted park whose tipple deck and hoist house stand in as greybox fails it;
# assets/park/park_pit/skill_line.json resolves for all six pilots, drop_in through canal_lip to landmark, and passes
# through every west cut and every drift, with a planted line that skips the barge drift failing that pin.

const T := preload("res://tests/support/t.gd")

const MAP := "park_pit"
const PARK := "res://src/world/park/park_pit.json"
const BAKED := "res://assets/park/park_pit"
const LINES := "res://assets/park/park_pit/lines.json"
const SCRATCH := "user://park_park_pit_test"
const BAKE_TOOL := "res://tools/park_bake.gd"
const GRAPH_TOOL := "res://tools/park_graph.gd"
const LOADER := "res://src/world/park/park_graph.gd"
const WAYMARKS := ["drop_in", "canal_lip", "switchback_camp", "landmark"]
const ROLES := {"cache_lip": "reward", "switchback_camp_site": "online", "bench3_altar": "risk", "adit_valve": "hidden"}
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]
const Graph := preload("res://src/world/park/park_graph.gd")
# The reward's least straight distance from any measured line (KD3 fix round): PARK.md 2.12's detour floor, 150 m.
const REWARD_CLEAR_M := 150.0
const SKILL_LINE := "res://assets/park/park_pit/skill_line.json"
const SKILL_WAYMARKS := ["drop_in", "canal_lip", "landmark"]
const CUTS := ["haul_road_west_1", "west_drift_1", "haul_road_west_2", "west_drift_2", "haul_road_west_3", "west_drift_3",
	"haul_road_west_4", "west_drift_4"]

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
	var off_named := park.duplicate(true)
	for row in off_named["park_rows"]:
		if row["id"] == "canal_lip":
			row["at"] = [900.0, 0.0]
	t.eq("planted: a named canal_lip off the play square returns the bounds error",
			_resolve(graph, off_named, {"waypoints": WAYMARKS}), ["canal_lip is off the play square"])

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
	for id in ROLES:
		t.eq("pocket %s role" % id, roles.get(id), ROLES[id])
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

	# Fix round (2026-10-11): the reward is a detour off every pilot line, not a pass on one, and Kest's line rides the
	# floor thermal. Planted first: the cache back at its greybox place beside the east conveyor, the thermal back at
	# its draft place off the Kest line.
	var cache: Array = _activity(park, "cache_lip")["at"]
	var thermal: Dictionary = _contraption(park, "dust_devil_floor")
	t.check("planted: the cache at (312, -20) sits within %d m of a pilot line" % REWARD_CLEAR_M,
			_off_lines(park, lines, Vector2(312.0, -20.0)) < REWARD_CLEAR_M)
	t.check("planted: a thermal at (80, 100) is off the kest line",
			_line_distance(park, lines["pilots"]["kest"], Vector2(80.0, 100.0)) > float(thermal["radius"]))
	var clear := _off_lines(park, lines, Vector2(float(cache[0]), float(cache[1])))
	t.check("cache_lip at least %d m from every pilot and floor line" % REWARD_CLEAR_M, clear >= REWARD_CLEAR_M, "%.1f m" % clear)
	var at: Array = thermal["at"]
	var kest := _line_distance(park, lines["pilots"]["kest"], Vector2(float(at[0]), float(at[1])))
	t.check("the kest line crosses dust_devil_floor's column", kest <= float(thermal["radius"]), "%.1f m from its centre" % kest)

	# Authored pass (2026-10-17): the beacon sight check on the headframe mounting, planted first.
	var greyed := park.duplicate(true)
	for row in greyed["park_rows"]:
		if row["id"] in ["tipple_deck", "hoist_house"]:
			row["recipe"] = "greybox:ledge"
	t.check("planted: a greybox tipple deck and hoist house fail the beacon check", not tool.beacon_check(graph, greyed)["ok"])
	var beacon: Dictionary = tool.beacon_check(graph, park)
	t.check("beacon check passes on the headframe mounting", beacon["ok"], str(beacon))

	# The skill line: every pilot rides the west cuts and their drifts, rim to floor.
	var skill: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SKILL_LINE))
	t.eq("skill line has six pilots", skill.get("pilots", {}).keys(), PILOTS)
	for pilot in PILOTS:
		t.eq("%s skill line resolves" % pilot, _resolve(graph, park, skill["pilots"][pilot], SKILL_WAYMARKS), [])
	var skipped: Dictionary = skill["pilots"]["kest"].duplicate(true)
	skipped["waypoints"] = skipped["waypoints"].filter(func(p) -> bool: return not (p is Array and _inside(park, "west_drift_3", p)))
	t.check("planted: a skill line that skips the barge drift misses a cut", not _missing_cuts(park, skipped).is_empty())
	for pilot in PILOTS:
		t.eq("%s skill line passes every cut and drift" % pilot, _missing_cuts(park, skill["pilots"][pilot]), [])
	quit(t.verdict())


# The cuts and drifts whose footprint holds none of the line's numeric waypoints.
func _missing_cuts(park: Dictionary, line: Dictionary) -> Array:
	var out := []
	for id in CUTS:
		if not line["waypoints"].any(func(p) -> bool: return p is Array and _inside(park, id, p)):
			out.append(id)
	return out


# Whether point p lies in the named row's footprint (yaw forward (sin, cos), size [length, height, width]).
func _inside(park: Dictionary, id: String, p: Array) -> bool:
	for row in park["park_rows"]:
		if row["id"] != id:
			continue
		var d := Vector2(float(p[0]) - float(row["at"][0]), float(p[1]) - float(row["at"][1]))
		var yaw := deg_to_rad(float(row["yaw_deg"]))
		var along := d.x * sin(yaw) + d.y * cos(yaw)
		var across := d.x * cos(yaw) - d.y * sin(yaw)
		return absf(along) <= float(row["size"][0]) * 0.5 and absf(across) <= float(row["size"][2]) * 0.5
	return false


func _activity(park: Dictionary, id: String) -> Dictionary:
	for row in park["activity_rows"]:
		if row["id"] == id:
			return row
	return {}


func _contraption(park: Dictionary, id: String) -> Dictionary:
	for row in park["contraption_rows"]:
		if row["id"] == id:
			return row
	return {}


# A line's points on the ground plane: waymark ids resolve to the spawn, a park row's at, or the landmark.
func _points(park: Dictionary, line: Dictionary) -> Array:
	var rows := {}
	for row in park["park_rows"]:
		rows[row["id"]] = row
	var out := []
	for point in line["waypoints"]:
		if point is String:
			var at: Array = park["spawn"]["at"] if point == "drop_in" else (park["landmark"]["at"] if point == "landmark" else rows[point]["at"])
			out.append(Vector2(float(at[0]), float(at[1])))
		else:
			out.append(Vector2(float(point[0]), float(point[1])))
	return out


# The straight distance from p to the nearest segment of one line.
func _line_distance(park: Dictionary, line: Dictionary, p: Vector2) -> float:
	var pts := _points(park, line)
	var best := INF
	for i in range(pts.size() - 1):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best


# The straight distance from p to the nearest of the six pilot lines and the floor line.
func _off_lines(park: Dictionary, lines: Dictionary, p: Vector2) -> float:
	var best := _line_distance(park, lines["floor"], p)
	for pilot in PILOTS:
		best = minf(best, _line_distance(park, lines["pilots"][pilot], p))
	return best


# Errors for one line: waymark ids in order from drop_in to landmark, every point inside the play square on an open
# graph node with a finite path to the beacon.
func _resolve(graph, park: Dictionary, line: Dictionary, waymarks: Array = []) -> Array:
	if waymarks.is_empty():
		waymarks = park["waymarks"]
	var out := []
	var named := []
	var rows := {}
	for row in park["park_rows"]:
		rows[row["id"]] = row
	for point in line["waypoints"]:
		var at: Array
		if point is String:
			named.append(point)
			if not waymarks.has(point):
				out.append("%s is no waymark" % point)
				continue
			if point == "drop_in":
				at = park["spawn"]["at"]
			elif point == "landmark":
				at = park["landmark"]["beacon"]
			elif rows.has(point):
				at = rows[point]["at"]
			else:
				out.append("%s has no park row" % point)
				continue
		else:
			at = point
		var p := Vector2(float(at[0]), float(at[1]))
		if absf(p.x) > Graph.HALF_M or absf(p.y) > Graph.HALF_M:
			out.append("%s is off the play square" % str(point))
			continue
		var n: int = graph.nearest(p)
		if graph.flags(n) & Graph.OPEN == 0:
			out.append("%s is on no open node" % str(point))
		elif not is_finite(graph.d_landmark_node(n)):
			out.append("%s has no path to the beacon" % str(point))
	if named != waymarks:
		out.append("waymarks named %s" % str(named))
	return out
