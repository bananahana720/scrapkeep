extends SceneTree

# Rule: stage 5, the Highdraft's sky islands (park_islands, K-UNITS KD5), ships as its park file
# says. The committed bake and stage graph are fresh against the park file and the tools; the
# waymarks run drop_in, saddle, anvil_rock, landmark; the graph's ruling (graph.json, written by
# tools/park_graph.gd) has no breach, every route connected, the spawn in the farthest quarter,
# and the four pockets in their PARK.md 2.12 roles with their distances inside the rule; the
# landmark is the Hanging Isle with the mind Warden hung under it as a harpoon anchor; and every
# named waypoint of the seven pilot and floor lines (tools/park_lines/park_islands.json) resolves
# on the park file. Each fact is checked by a function that a planted copy must fail, so a pin
# that cannot go red is caught here (the plants are the positive controls).
#
# Greybox pass, 2026-10-11 (KD5); fix round 2026-10-12 (flat arena, full-width sheets, the tram
# station ledge, the pockets moved). The byte-identity of two builds is a CLI receipt of the unit,
# not rerun here: the continuation's bake took 11.002 s and the shipped graph tool
# 8.380 s. The accepted float32 search fix makes comparison and storage agree, with tied
# predecessors resolved by lower index. The freshness pin holds the graph to that shipped tool.
#
# The PARK.md 2.12 distances are read from tools/park_graph.gd, so this test cannot drift from the
# tool that rules them. sight_share 0.85 is the stage page's own landmark row.

const T := preload("res://tests/support/t.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const Traversal := preload("res://tools/traversal_line.gd")
const GraphTool := preload("res://tools/park_graph.gd")

const MAP := "park_islands"
const PARK := "res://src/world/park/park_islands.json"
const DIR := "res://assets/park/park_islands"
const LINES := "res://tools/park_lines/park_islands.json"
const BAKE_TOOL := "res://tools/park_bake.gd"
const GRAPH_TOOL := "res://tools/park_graph.gd"

const WAYMARKS := ["drop_in", "saddle", "anvil_rock", "landmark"]
const POCKETS := {"online": "camp_anvil", "reward": "cache_east_wing", "risk": "bounty_ore_bench", "hidden": "saddle_seam"}
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]
const DOOR_TO_LINE_M := GraphTool.SIGHT_M
const SPAWN_M := GraphTool.DOOR_SPAWN_M
const BEACON_M := GraphTool.DOOR_BEACON_M
const DOOR_TO_DOOR_M := GraphTool.DOOR_DOOR_M
const DETOUR_M := [GraphTool.DETOUR_MIN_M, GraphTool.DETOUR_MAX_M]

var t := T.new("park_park_islands_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var bake: GDScript = load(BAKE_TOOL)
	var graph_tool: GDScript = load(GRAPH_TOOL)
	var bake_stale: Array = bake.freshness(PARK, DIR)
	t.check("the bake is fresh", bake_stale.is_empty(), str(bake_stale))
	var graph_stale: Array = graph_tool.freshness(PARK, DIR, DIR)
	t.check("the stage graph is fresh", graph_stale.is_empty(), str(graph_stale))

	var read := ParkSchema.load_park(PARK)
	if not t.check("the park file passes the schema", read["errors"].is_empty(), ParkSchema.describe(read["errors"])):
		quit(t.verdict())
		return
	var park: Dictionary = read["data"]
	var info = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/graph.json"))
	if not t.check("graph.json parses", info is Dictionary):
		quit(t.verdict())
		return
	var lines = JSON.parse_string(FileAccess.get_file_as_string(LINES))
	if not t.check("the lines file parses", lines is Dictionary):
		quit(t.verdict())
		return

	_pin("waymarks", _waymarks(park), _waymarks(_planted(park, "waymarks", ["drop_in", "anvil_rock", "saddle", "landmark"])))
	_pin("landmark and Warden", _landmark(park), _landmark(_planted_warden(park)))
	_pin("graph ruling", _ruling(info), _ruling(_planted_ruling(info)))
	_pin("pocket roles and distances", _pockets(info), _pockets(_planted_pocket(info)))
	_pin("pilot lines resolve", _lines(lines, park), _lines(_planted_lines(lines), park))
	quit(t.verdict())


# A pin passes on the shipped file and must fail on its plant.
func _pin(name: String, shipped: Array, planted: Array) -> void:
	t.check(name + " hold on the shipped stage", shipped.is_empty(), "; ".join(shipped))
	t.check(name + " fail on the plant (positive control)", not planted.is_empty())


func _waymarks(park: Dictionary) -> Array:
	var out := []
	if park["waymarks"] != WAYMARKS:
		out.append("waymarks %s, want %s" % [park["waymarks"], WAYMARKS])
	if String(park["map"]) != MAP:
		out.append("map %s" % park["map"])
	return out


func _landmark(park: Dictionary) -> Array:
	var out := []
	var mark: Dictionary = park["landmark"]
	if String(mark["id"]) != "hanging_isle" or String(mark["kind"]) != "sky_island":
		out.append("landmark %s %s" % [mark["id"], mark["kind"]])
	if absf(float(mark.get("sight_share", 0.0)) - 0.85) > 0.001:
		out.append("sight_share %s" % mark.get("sight_share"))
	var warden: Dictionary = mark.get("warden", {})
	if String(warden.get("family", "")) != "mind" or String(warden.get("mounting", "")) != "under_island" \
			or warden.get("harpoon_anchor") != true:
		out.append("warden %s" % warden)
	return out


func _ruling(info: Dictionary) -> Array:
	var out := []
	if not (info.get("breaches", [1]) as Array).is_empty():
		out.append("breaches %s" % [info.get("breaches")])
	if info.get("beacon_ok") != true:
		out.append("beacon_ok %s" % [info.get("beacon_ok")])
	var routes: Dictionary = info.get("routes", {})
	if routes.size() != 13:
		out.append("%d routes, want 13" % routes.size())
	for id in routes:
		if not (routes[id] as Array).is_empty():
			out.append("route %s breaks: %s" % [id, routes[id]])
	if info.get("spawn", {}).get("ok") != true:
		out.append("spawn %s" % info.get("spawn"))
	return out


func _pockets(info: Dictionary) -> Array:
	var out := []
	var by_role := {}
	for row in info.get("pockets", []):
		by_role[String(row["role"])] = row
	for role in POCKETS:
		if not by_role.has(role) or String(by_role[role]["id"]) != POCKETS[role]:
			out.append("%s pocket is %s, want %s" % [role, by_role.get(role, {}).get("id"), POCKETS[role]])
			continue
		var row: Dictionary = by_role[role]
		if row["sight_ok"] != true or int(row["door_m"]) > DOOR_TO_LINE_M:
			out.append("%s door %s m from the line, sight %s" % [role, row["door_m"], row["sight_ok"]])
		if int(row["d_spawn"]) < SPAWN_M or int(row["d_landmark"]) < BEACON_M:
			out.append("%s door %s m from spawn, %s m from the beacon" % [role, row["d_spawn"], row["d_landmark"]])
		if role != "online":
			if int(row["detour_m"]) < DETOUR_M[0] or int(row["detour_m"]) > DETOUR_M[1]:
				out.append("%s detour %s m" % [role, row["detour_m"]])
			if row["nearest_door"] != null and int(row["nearest_door"]) < DOOR_TO_DOOR_M:
				out.append("%s door %s m from %s" % [role, row["nearest_door"], row["nearest_door_id"]])
		if not (row["clear_ring"] as Array).is_empty():
			out.append("%s ring %s" % [role, row["clear_ring"]])
	if by_role.has("reward") and by_role.has("risk") and int(by_role["reward"]["detour_m"]) <= int(by_role["risk"]["detour_m"]):
		out.append("reward detour %s m is not larger than risk %s m" % [by_role["reward"]["detour_m"], by_role["risk"]["detour_m"]])
	return out


func _lines(lines: Dictionary, park: Dictionary) -> Array:
	var out := []
	for key in PILOTS + ["floor"]:
		var line: Dictionary = lines.get("floor", {}) if key == "floor" else lines.get("pilots", {}).get(key, {})
		var points: Array = line.get("waypoints", [])
		if points.is_empty():
			out.append("%s has no waypoints" % key)
			continue
		var named := []
		for point in points:
			if point is String:
				if Traversal.place_of(park, point) == Vector2.INF:
					out.append("%s waypoint %s does not resolve" % [key, point])
				named.append(point)
		if named != WAYMARKS:
			out.append("%s waymarks %s" % [key, named])
	return out


func _planted(park: Dictionary, key: String, value) -> Dictionary:
	var copy := park.duplicate(true)
	copy[key] = value
	return copy


func _planted_warden(park: Dictionary) -> Dictionary:
	var copy := park.duplicate(true)
	copy["landmark"]["warden"]["family"] = "reactor"
	return copy


func _planted_ruling(info: Dictionary) -> Dictionary:
	var copy: Dictionary = info.duplicate(true)
	copy["routes"]["main"] = ["anvil_rock -> net_post_run: no path"]
	return copy


func _planted_pocket(info: Dictionary) -> Dictionary:
	var copy: Dictionary = info.duplicate(true)
	for row in copy["pockets"]:
		if row["role"] == "reward":
			row["detour_m"] = 120
	return copy


func _planted_lines(lines: Dictionary) -> Dictionary:
	var copy: Dictionary = lines.duplicate(true)
	copy["pilots"]["rivet"]["waypoints"][5] = "altar_anvil"
	return copy
