extends SceneTree

# Stage 4, park_sinkhole (design-v3/park/stages/4-park_sinkhole.md, K-UNITS KD4). Pinned
# 2026-10-12, merged greybox continuation. The committed bake and graph are fresh for the park file; the
# waymarks run drop_in, tube_mouth, great_room, landmark; the graph's pocket table names one
# pocket per role with the ids this stage ships and no breach; the landmark carries the swarm
# brood on the sinkhole mounting; every pilot line and the floor line start at drop_in, pass the
# waymarks in order, end at landmark and name only places the park file has; and the two
# ride-fact sources the runtime fires on this head (kicker rows and the lava channel's rope fan)
# are in the file. Fix round 2026-10-11: every row but the ground, the kickers and the stage page's
# site markers carries a recipe (R10), so it places at runtime. pins() is run on planted copies
# too, and each plant must turn it red.

const T := preload("res://tests/support/t.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")

const MAP := "park_sinkhole"
const PARK := "res://src/world/park/park_sinkhole.json"
const BAKED := "res://assets/park/park_sinkhole"
const LINES := "res://tools/park_lines/park_sinkhole.json"
const WAYMARKS := ["drop_in", "tube_mouth", "great_room", "landmark"]
const POCKETS := {"online": "great_room_camp", "risk": "east_chamber_bounty", "reward": "west_chamber_cache", "hidden": "sealed_crosscut"}
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]
const RECIPE_LEFT := ["great_room", "east_chamber", "west_chamber", "crosscut_drift", "west_cenote", "sinkhole_walls", "caisson_bowl"]

var t := T.new("park_park_sinkhole_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stale: Array = ParkBake.freshness(PARK, BAKED)
	t.check("the committed bake is fresh", stale.is_empty(), str(stale))
	var graph_stale: Array = ParkGraphTool.freshness(PARK, BAKED, BAKED)
	t.check("the committed graph is fresh", graph_stale.is_empty(), str(graph_stale))
	var read := ParkSchema.load_park(PARK)
	if not t.check("the park file loads with zero errors", read["errors"].is_empty(), str(read["errors"])):
		quit(t.verdict())
		return
	var park: Dictionary = read["data"]
	var graph = JSON.parse_string(FileAccess.get_file_as_string(BAKED + "/graph.json"))
	var lines = JSON.parse_string(FileAccess.get_file_as_string(LINES))
	if not t.check("graph.json and the lines file parse", graph is Dictionary and lines is Dictionary):
		quit(t.verdict())
		return
	var errors := pins(park, graph, lines)
	t.check("every stage pin holds", errors.is_empty(), "\n".join(errors))

	# Plants: each must break a pin.
	var p1: Dictionary = park.duplicate(true)
	p1["waymarks"] = ["drop_in", "great_room", "tube_mouth", "landmark"]
	t.check("plant: swapped waymarks fail", not pins(p1, graph, lines).is_empty())
	var g1: Dictionary = graph.duplicate(true)
	g1["pockets"][1]["role"] = "reward"
	t.check("plant: a second reward pocket fails", not pins(park, g1, lines).is_empty())
	var p2: Dictionary = park.duplicate(true)
	p2["landmark"]["warden"]["mounting"] = "headframe"
	t.check("plant: another mounting fails", not pins(p2, graph, lines).is_empty())
	var p4: Dictionary = park.duplicate(true)
	p4["landmark"]["warden"]["anchor"] = [0.0, -99.0, 380.0]
	t.check("plant: a moved Warden anchor fails", not pins(p4, graph, lines).is_empty())
	var l1: Dictionary = lines.duplicate(true)
	l1["pilots"]["tarn"]["waypoints"].insert(3, "no_such_row")
	t.check("plant: an unknown waypoint fails", not pins(park, graph, l1).is_empty())
	var p3: Dictionary = park.duplicate(true)
	p3["contraption_rows"] = p3["contraption_rows"].filter(func(c): return c["kind"] != "cable" or not String(c["site"]).begins_with("lava_channel"))
	t.check("plant: no rope fan fails", not pins(p3, graph, lines).is_empty())
	var p5: Dictionary = park.duplicate(true)
	for r in p5["park_rows"]:
		if r["element"] == "anchor_field":
			r["recipe"] = ""
			break
	t.check("plant: an anchor field with no recipe fails", not pins(p5, graph, lines).is_empty())
	var g2: Dictionary = graph.duplicate(true)
	g2["beacon_ok"] = false
	t.check("plant: an unqualified beacon fails", not pins(park, g2, lines).is_empty())
	var g3: Dictionary = graph.duplicate(true)
	g3["spawn"]["run"] = false
	t.check("plant: an unqualified spawn run fails", not pins(park, g3, lines).is_empty())
	quit(t.verdict())


# JSON numbers parse as floats, so a pinned point compares as a vector, not an Array of ints.
static func _v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and a.size() == 2 else Vector2.INF


static func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and a.size() == 3 else Vector3.INF


# The stage's facts, as error lines; [] when every pin holds.
static func pins(park: Dictionary, graph: Dictionary, lines: Dictionary) -> Array:
	var out := []
	if park.get("map") != MAP:
		out.append("map is %s" % park.get("map"))
	if park["waymarks"] != WAYMARKS:
		out.append("waymarks %s, want %s" % [park["waymarks"], WAYMARKS])
	var mark: Dictionary = park["landmark"]
	if mark["kind"] != "sinkhole" or _v2(mark["at"]) != Vector2(0, 350) or _v2(mark["beacon"]) != Vector2(0, 350):
		out.append("landmark %s at %s, beacon %s" % [mark["kind"], mark["at"], mark["beacon"]])
	var w: Dictionary = mark["warden"]
	if w.get("family") != "swarm" or w.get("mounting") != "sinkhole" or w.get("harpoon_anchor") != true or _v3(w.get("anchor", [])) != Vector3(0, -99, 388):
		out.append("warden %s" % str(w))
	var roles := {}
	for p in graph.get("pockets", []):
		if roles.has(p["role"]):
			out.append("two %s pockets" % p["role"])
		roles[p["role"]] = p["id"]
	if roles != POCKETS:
		out.append("pocket roles %s, want %s" % [roles, POCKETS])
	if not (graph.get("breaches", []) as Array).is_empty():
		out.append("graph breaches %s" % str(graph["breaches"]))
	if not graph.get("spawn", {}).get("ok", false):
		out.append("the spawn is not in the farthest quarter")
	if not graph.get("beacon_ok", false):
		out.append("the beacon is not qualified")
	if not graph.get("spawn", {}).get("run", false):
		out.append("the spawn run is not qualified")
	for route in graph.get("routes", {}):
		if not (graph["routes"][route] as Array).is_empty():
			out.append("route %s does not connect" % route)
	# Places a waypoint may name.
	var places := {"drop_in": true, "landmark": true}
	for r in park["park_rows"]:
		places[r["id"]] = true
	for a in park["activity_rows"]:
		places[a["id"]] = true
	var all := {}
	for k in PILOTS:
		if not lines.get("pilots", {}).has(k):
			out.append("no %s line" % k)
			continue
		all[k] = lines["pilots"][k]["waypoints"]
	all["floor"] = lines.get("floor", {}).get("waypoints", [])
	for k in all:
		var wps: Array = all[k]
		if wps.is_empty() or wps[0] != "drop_in" or wps[-1] != "landmark":
			out.append("%s line does not run drop_in to landmark" % k)
		var named := []
		for wp in wps:
			if wp is String:
				if not places.has(wp):
					out.append("%s line names %s, not a place in the park file" % [k, wp])
				named.append(wp)
		if named.filter(func(n): return n in WAYMARKS) != WAYMARKS:
			out.append("%s line waymarks %s" % [k, named])
	# The ride facts this head fires: a kicker row's lip, and the rope fan across the lava channel.
	var kickers: Array = park["park_rows"].filter(func(r): return r["element"] == "kicker")
	if kickers.size() < 2:
		out.append("%d kicker rows, want 2" % kickers.size())
	var fan: Array = park["contraption_rows"].filter(func(c): return c["kind"] == "cable" and String(c["site"]).begins_with("lava_channel"))
	if fan.size() < 4:
		out.append("%d rope-fan cables on the lava channel, want 4" % fan.size())
	# R10: every row but the ground carries a recipe, so it places at runtime; the rows left on "" are the
	# stage page's list (site markers with no stamp and no height, and kickers whose _ramp row's stamp is the lip).
	for r in park["park_rows"]:
		if r["element"] == "ground" or r["id"] in RECIPE_LEFT or r["element"] == "kicker":
			continue
		if String(r["recipe"]) == "":
			out.append("row %s (%s) has no recipe" % [r["id"], r["element"]])
	return out
