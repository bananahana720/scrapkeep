extends RefCounted

# Mini-boss sites and risk-line rows of one park (assets/park/<map>/sites.json, schema
# scrapkeep-sites/1), kept beside the park file so authoring them never stales the park's bake or
# graph (both hash the park JSON). validate() returns one string per broken rule; empty means the
# file holds. The graph rules run only when a ParkGraph is passed.
#
# A mini-boss site is a disc the director may drop a fight into: 2 to 3 per park, one per third of
# the run at most, named for the world's WORLD_ANCIENTS kind (a placeholder while the roster is
# open, Q-P25). Its disc must sit on open, reachable ground off the landmark footprint,
# hold no event row, and cost no more than DETOUR_MAX_M over the drop-in to landmark path.
# d_spawn is the forward path to a node from the drop-in, d_landmark the path from a node to the
# landmark beacon (a reverse search), so d_spawn + d_landmark is the cost of going through it.
#
# A risk row names a route, the hazards on it and the reward at its end. It is an option off the
# line everyone rides, so the route is not the park's main route and the reward (and at least one
# hazard) sits off the shared path: the waymarks, the main route's rows, drop_in and landmark.
# Skipping the line must never strand the ball, so the route needs an alternative with the same
# from and to.

const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")

const SCHEMA := "scrapkeep-sites/1"
const THIRDS := ["early", "mid", "late"]
const SITES_MIN := 2
const SITES_MAX := 3
const RISK_MIN := 1
const RISK_MAX := 2
# A park row's centre sits at most this far from a site it is named for: about three disc radii,
# so "near" names a landform the player sees from the disc, not one across the map.
const NEAR_MAX_M := 150.0
# Islands early and mid measure 20 to 22 m of open ground; anything tighter has no room to fight.
const RADIUS_MIN_M := 20.0
const RING_SHARE := 0.75
const RING_POINTS := 8
const DETOUR_MAX_M := 200.0


static func path(map_id: String) -> String:
	return "res://assets/park/%s/sites.json" % map_id


static func read(map_id: String) -> Dictionary:
	return ParkSchema.read_file(path(map_id))


static func validate(sites: Dictionary, park: Dictionary, graph: ParkGraph = null) -> Array:
	var out := []
	if sites.is_empty():
		return ["sites: empty or missing file"]
	if sites.get("schema") != SCHEMA:
		out.append("schema: %s, want %s" % [str(sites.get("schema")), SCHEMA])
	if sites.get("map") != park.get("map"):
		out.append("map: %s, park is %s" % [str(sites.get("map")), str(park.get("map"))])
	_sites(out, sites.get("miniboss_sites", []), park, graph)
	_risk_rows(out, sites.get("risk_rows", []), park)
	return out


static func _sites(out: Array, list, park: Dictionary, graph: ParkGraph) -> void:
	if not list is Array or list.size() < SITES_MIN or list.size() > SITES_MAX:
		out.append("miniboss_sites: %s, want %d to %d" % [str(list.size()) if list is Array else "not an array", SITES_MIN, SITES_MAX])
		return
	var ctx := ParkSchema.stage_context(str(park.get("map", "")))
	var kind := ""
	if not ctx.is_empty():
		kind = str(ParkSchema.WORLD_ANCIENTS.get(ctx["world"], ""))
	var rows := _index(park.get("park_rows", []))
	var seen := {}
	for site in list:
		if not site is Dictionary or not _has(site, ["id", "at", "radius_m", "near", "third", "miniboss"]):
			out.append("miniboss_sites: a site lacks id, at, radius_m, near, third or miniboss")
			continue
		var id := str(site["id"])
		if seen.has(id):
			out.append("%s: id repeats" % id)
		seen[id] = true
		if not THIRDS.has(site["third"]):
			out.append("%s: third %s is not early, mid or late" % [id, str(site["third"])])
		if kind == "" or site["miniboss"] != kind:
			out.append("%s: miniboss %s, the world's ancient is %s" % [id, str(site["miniboss"]), kind])
		if not (site["at"] is Array and site["at"].size() == 2):
			out.append("%s: at is not [x, z]" % id)
			continue
		var at := Vector2(float(site["at"][0]), float(site["at"][1]))
		var radius := float(site["radius_m"])
		if radius < RADIUS_MIN_M:
			out.append("%s: radius_m %.1f under %.0f" % [id, radius, RADIUS_MIN_M])
		if not rows.has(site["near"]):
			out.append("%s: near %s is no park row" % [id, str(site["near"])])
		else:
			var d := at.distance_to(_at(rows[site["near"]]))
			if d > NEAR_MAX_M:
				out.append("%s: %.0f m from %s, over %.0f" % [id, d, site["near"], NEAR_MAX_M])
		if not _in_rect(at, park.get("play_rect", [])):
			out.append("%s: centre outside play_rect" % id)
		var stacked := hazards_in_disc(site, park)
		if not stacked.is_empty():
			out.append("%s: hazard rows in the disc: %s" % [id, str(stacked)])
		if graph != null:
			var m := measure(site, park, graph)
			for miss in m["misses"]:
				out.append("%s: %s" % [id, miss])


# The graph facts of one site: the centre node, whether the ring is clear, the two path legs and
# the detour. misses lists each rule the graph breaks.
static func measure(site: Dictionary, park: Dictionary, graph: ParkGraph) -> Dictionary:
	var at := Vector2(float(site["at"][0]), float(site["at"][1]))
	var radius := float(site["radius_m"])
	var foot := footprint(park, graph)
	var misses := []
	var node := graph.nearest(at)
	if not _clear(graph, node, foot):
		misses.append("centre node %d is not open ground off the landmark footprint" % node)
	for k in RING_POINTS:
		var a := TAU * k / RING_POINTS
		var ring := graph.nearest(at + Vector2(cos(a), sin(a)) * radius * RING_SHARE)
		if not _clear(graph, ring, foot):
			misses.append("ring bearing %d° lands on node %d, not open ground off the footprint" % [k * 45, ring])
	var out_m: float = graph.d_from[node]
	var in_m: float = graph.d_land[node]
	var detour := INF
	if is_inf(out_m):
		misses.append("not reachable from the drop-in")
	if is_inf(in_m):
		misses.append("the landmark is not reachable from it")
	if not is_inf(out_m) and not is_inf(in_m):
		detour = out_m + in_m - float(graph.d_land[graph.spawn_node])
		if detour > DETOUR_MAX_M:
			misses.append("detour %.0f m over %.0f" % [detour, DETOUR_MAX_M])
	return {"node": node, "out_m": out_m, "in_m": in_m, "detour_m": detour, "misses": misses}


# The ground nodes under the landmark's footprint, as a set.
static func footprint(park: Dictionary, graph: ParkGraph) -> Dictionary:
	var landmark: Dictionary = park["landmark"].duplicate()
	landmark["stamp"] = ""
	var set := {}
	for n in graph.inside_nodes(ParkGraph.Stamps.frame(landmark)):
		set[n] = true
	return set


# Event rows whose site row lies inside the disc, so a fight is not stacked on a hazard.
static func hazards_in_disc(site: Dictionary, park: Dictionary) -> Array:
	var rows := _index(park.get("park_rows", []))
	var at := Vector2(float(site["at"][0]), float(site["at"][1]))
	var out := []
	for ev in park.get("event_rows", []):
		if rows.has(ev["site"]) and at.distance_to(_at(rows[ev["site"]])) <= float(site["radius_m"]):
			out.append(ev["id"])
	return out


static func _risk_rows(out: Array, list, park: Dictionary) -> void:
	if not list is Array or list.size() < RISK_MIN or list.size() > RISK_MAX:
		out.append("risk_rows: %s, want %d to %d" % [str(list.size()) if list is Array else "not an array", RISK_MIN, RISK_MAX])
		return
	var routes := {}
	for r in park.get("routes", []):
		routes[r["id"]] = r
	var events := _index(park.get("event_rows", []))
	var acts := _index(park.get("activity_rows", []))
	var rows := _index(park.get("park_rows", []))
	var shared := {"drop_in": true, "landmark": true}
	for w in park.get("waymarks", []):
		shared[w] = true
	var main_via := []
	if routes.has("main"):
		main_via = routes["main"]["via"]
		for v in main_via:
			shared[v] = true
	var seen := {}
	for row in list:
		if not row is Dictionary or not _has(row, ["id", "route", "hazards", "reward"]):
			out.append("risk_rows: a row lacks id, route, hazards or reward")
			continue
		var id := str(row["id"])
		if seen.has(id):
			out.append("%s: id repeats" % id)
		seen[id] = true
		if not routes.has(row["route"]):
			out.append("%s: route %s is no route" % [id, str(row["route"])])
			continue
		var route: Dictionary = routes[row["route"]]
		var via: Array = route["via"]
		if route["id"] == "main" or (not main_via.is_empty() and via == main_via):
			out.append("%s: route %s is the main line, a risk line is an option off it" % [id, route["id"]])
		var alt := routes.values().filter(func(r): return r["id"] != route["id"] and r["from"] == route["from"] and r["to"] == route["to"])
		if alt.is_empty():
			out.append("%s: route %s has no alternative from %s to %s" % [id, route["id"], route["from"], route["to"]])
		if not row["hazards"] is Array or row["hazards"].is_empty():
			out.append("%s: no hazards" % id)
		else:
			var off_shared := false
			for h in row["hazards"]:
				var ok: bool = (rows.has(h) and via.has(h)) or (events.has(h) and via.has(events[h]["site"]))
				if not ok:
					out.append("%s: hazard %s is not on route %s" % [id, str(h), route["id"]])
				elif not shared.has(events[h]["site"] if events.has(h) else h):
					off_shared = true
			if not off_shared:
				out.append("%s: every hazard sits on the shared path" % id)
		var reward = row["reward"]
		if not ((rows.has(reward) and via.has(reward)) or (acts.has(reward) and via.has(acts[reward]["site"]))):
			out.append("%s: reward %s is not on route %s" % [id, str(reward), route["id"]])
		elif shared.has(acts[reward]["site"] if acts.has(reward) else reward):
			out.append("%s: reward %s is on the shared path" % [id, str(reward)])


static func _index(list: Array) -> Dictionary:
	var out := {}
	for row in list:
		out[row["id"]] = row
	return out


static func _has(row: Dictionary, keys: Array) -> bool:
	for k in keys:
		if not row.has(k):
			return false
	return true


static func _at(row: Dictionary) -> Vector2:
	return Vector2(float(row["at"][0]), float(row["at"][1]))


static func _in_rect(p: Vector2, rect: Array) -> bool:
	return rect.size() == 4 and p.x >= rect[0] and p.y >= rect[1] and p.x <= rect[0] + rect[2] and p.y <= rect[1] + rect[3]


static func _clear(graph: ParkGraph, node: int, foot: Dictionary) -> bool:
	return graph.node_flags[node] & ParkGraph.OPEN != 0 and not foot.has(node)
