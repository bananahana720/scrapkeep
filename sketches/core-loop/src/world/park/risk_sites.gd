extends RefCounted


const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")

const SCHEMA := "scrapkeep-sites/1"
const THIRDS := ["early", "mid", "late"]
const SITES_MIN := 2
const SITES_MAX := 3
const RISK_MIN := 1
const RISK_MAX := 2
const NEAR_MAX_M := 150.0
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
	var thirds := {}
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
		elif thirds.has(site["third"]):
			out.append("%s: third %s already holds %s" % [id, site["third"], thirds[site["third"]]])
		else:
			thirds[site["third"]] = id
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


static func measure(site: Dictionary, park: Dictionary, graph: ParkGraph) -> Dictionary:
	var at := Vector2(float(site["at"][0]), float(site["at"][1]))
	var radius := float(site["radius_m"])
	var foot := footprint(park, graph)
	var misses := []
	var node := graph.nearest(at)
	var why := _blocked(graph, node, foot)
	if why != "":
		misses.append("centre node %d %s" % [node, why])
	for k in RING_POINTS:
		var a := TAU * k / RING_POINTS
		var ring := graph.nearest(at + Vector2(cos(a), sin(a)) * radius * RING_SHARE)
		why = _blocked(graph, ring, foot)
		if why != "":
			misses.append("ring bearing %d° lands on node %d, which %s" % [k * 45, ring, why])
	var out_m: float = graph.d_from[node]
	var in_m: float = graph.d_land[node]
	var detour := INF
	if is_inf(out_m):
		misses.append("not reachable from the drop-in")
	if is_inf(in_m):
		misses.append("the landmark is not reachable from it")
	var direct: float = graph.d_land[graph.spawn_node]
	if is_inf(direct):
		misses.append("landmark unreachable from drop-in")
	elif not is_inf(out_m) and not is_inf(in_m):
		detour = out_m + in_m - direct
		if detour > DETOUR_MAX_M:
			misses.append("detour %.0f m over %.0f" % [detour, DETOUR_MAX_M])
	return {"node": node, "out_m": out_m, "in_m": in_m, "detour_m": detour, "misses": misses}


static func footprint(park: Dictionary, graph: ParkGraph) -> Dictionary:
	var landmark: Dictionary = park["landmark"].duplicate()
	landmark["stamp"] = ""
	var set := {}
	for n in graph.inside_nodes(ParkGraph.Stamps.frame(landmark)):
		set[n] = true
	return set


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
	var vias := {}
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
		vias[id] = via
		if route["id"] == "main" or (not main_via.is_empty() and via == main_via):
			out.append("%s: route %s is the main line, a risk line is an option off it" % [id, route["id"]])
		var alt := routes.values().filter(func(r): return r["id"] != route["id"] and r["from"] == route["from"] and r["to"] == route["to"])
		if alt.is_empty():
			out.append("%s: route %s has no alternative from %s to %s" % [id, route["id"], route["from"], route["to"]])
		var taken := {}
		for r in alt:
			for v in r["via"] + [r["from"], r["to"]]:
				if not taken.has(v):
					taken[v] = r["id"]
		if not row["hazards"] is Array or row["hazards"].is_empty():
			out.append("%s: no hazards" % id)
		else:
			var off_shared := false
			var on_route := true
			var why := []
			for h in row["hazards"]:
				if not events.has(h):
					on_route = false
					out.append("%s: hazard %s is no event row" % [id, str(h)])
				elif not via.has(events[h]["site"]):
					on_route = false
					out.append("%s: hazard %s is not on route %s" % [id, str(h), route["id"]])
				elif shared.has(events[h]["site"]):
					why.append("%s is on the shared path" % h)
				else:
					off_shared = true
			if on_route and not off_shared:
				out.append("%s: no hazard is off the shared path: %s" % [id, "; ".join(why)])
		var reward = row["reward"]
		var spot: String = acts[reward]["site"] if acts.has(reward) else str(reward)
		if not ((rows.has(reward) and via.has(reward)) or (acts.has(reward) and via.has(spot))):
			out.append("%s: reward %s is not on route %s" % [id, str(reward), route["id"]])
		elif shared.has(spot):
			out.append("%s: reward %s is on the shared path" % [id, str(reward)])
		elif taken.has(spot):
			out.append("%s: reward %s is also on route %s" % [id, str(reward), taken[spot]])
	var ids := vias.keys()
	if ids.size() == 2:
		var first: Array = vias[ids[0]]
		var second: Array = vias[ids[1]]
		if first.all(func(v): return second.has(v)) or second.all(func(v): return first.has(v)):
			out.append("%s and %s are one line: one via sits inside the other" % [ids[0], ids[1]])


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


static func _blocked(graph: ParkGraph, node: int, foot: Dictionary) -> String:
	if graph.node_flags[node] & ParkGraph.OPEN == 0:
		return "is not OPEN ground"
	if foot.has(node):
		return "is on the landmark footprint"
	return ""
