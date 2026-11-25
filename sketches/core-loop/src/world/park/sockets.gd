extends RefCounted

const Graph := preload("res://src/world/park/park_graph.gd")
const Stamps := preload("res://src/world/park/park_stamps.gd")
const SEEDS := 1000
const SUCCESS_MIN := 0.95
const REROLL_MAX := 0.10
const FIXED_SHARE_MAX := 0.5
const VISIT_MAX := 3.0
const POCKET_MIN := 3
const POCKET_MAX := 8


static func _key(a: int, b: int, n: int) -> int:
	return a * n + b


static func validate(graph, sockets: Array) -> Array:
	var errors := []
	var owned := {}
	var ids := {}
	var counts := PackedInt32Array()
	counts.resize(graph.zone_count())
	var n: int = graph.node_count()
	for s in sockets:
		if ids.has(s["id"]):
			errors.append("duplicate socket %s" % s["id"])
		ids[s["id"]] = true
		if s["a"] == s["b"] or s["a"] < 0 or s["b"] < 0 or s["a"] >= counts.size() or s["b"] >= counts.size():
			errors.append("socket %s has invalid zones" % s["id"])
			continue
		counts[s["a"]] += 1
		counts[s["b"]] += 1
		var row: Dictionary = s["filler"]
		if row["recipe"] != "greybox:ground" or row["size"].size() != 3 or row["size"].min() <= 0 or row.get("y") == null:
			errors.append("socket %s needs a positive solid filler" % s["id"])
			continue
		var frame := _frame(row)
		if s["links"].is_empty():
			errors.append("socket %s has no links" % s["id"])
		for link in s["links"]:
			var a: int = link[0]
			var b: int = link[1]
			if a < 0 or b < 0 or a >= n or b >= n:
				errors.append("socket %s has an invalid node" % s["id"])
				continue
			if not ([graph.zone_of(a), graph.zone_of(b)] == [s["a"], s["b"]] or [graph.zone_of(a), graph.zone_of(b)] == [s["b"], s["a"]]):
				errors.append("socket %s links the wrong zones" % s["id"])
			var key := _key(a, b, n)
			if owned.has(key):
				errors.append("link %d to %d has two sockets" % [a, b])
			owned[key] = s["id"]
			if not _intersects(frame, graph.position(a), graph.position(b)):
				errors.append("socket %s filler misses its link" % s["id"])
	for z in counts.size():
		if counts[z] < 2 or counts[z] > 4:
			errors.append("zone %s has %d openings, expected 2 to 4" % [graph.zones()[z]["name"], counts[z]])
	var found := {}
	for a in n:
		for e in range(graph.off[a], graph.off[a + 1]):
			var b: int = graph.to[e]
			var key := _key(a, b, n)
			found[key] = true
			if graph.zone_of(a) != graph.zone_of(b) and not owned.has(key):
				errors.append("unmanaged crossing %d to %d" % [a, b])
	for key in owned:
		if not found.has(key):
			errors.append("socket declares a nonexistent link")
	return errors


static func _intersects(frame: Dictionary, a: Vector3, b: Vector3) -> bool:
	var pa := Stamps.local(frame, a.x, a.z)
	var pb := Stamps.local(frame, b.x, b.z)
	var p := Vector3(pa.x, pa.y, (a.y - frame["base_y"]) / frame["height"] - 0.5)
	var q := Vector3(pb.x, pb.y, (b.y - frame["base_y"]) / frame["height"] - 0.5)
	var lo := 0.0
	var hi := 1.0
	for axis in 3:
		var delta: float = q[axis] - p[axis]
		if is_zero_approx(delta):
			if absf(p[axis]) > 0.5:
				return false
		else:
			var u: float = (-0.5 - p[axis]) / delta
			var v: float = (0.5 - p[axis]) / delta
			lo = maxf(lo, minf(u, v))
			hi = minf(hi, maxf(u, v))
			if lo > hi:
				return false
	return true


static func _frame(row: Dictionary) -> Dictionary:
	var frame := Stamps.frame(row)
	frame["base_y"] = float(row["y"])
	frame["height"] = float(row["size"][1])
	return frame


static func _shortest_links(graph) -> Array:
	var path: Dictionary = graph.search_prev(graph.spawn_node)
	var links := []
	var node: int = graph.beacon_node
	while node != graph.spawn_node:
		var previous: int = path["prev"][node]
		if previous < 0:
			break
		links.append([previous, node])
		node = previous
	return links


static func _safe(graph, row: Dictionary, shortest: Array = []) -> bool:
	var frame := _frame(row)
	if shortest.is_empty():
		shortest = _shortest_links(graph)
	for link in shortest:
		if _intersects(frame, graph.position(link[0]), graph.position(link[1])):
			return false
	for a in graph.node_count():
		if graph.flags(a) & (Graph.LINE | Graph.WARDEN) != 0:
			if Stamps.inside(frame, graph.px[a], graph.pz[a]):
				return false
			for e in range(graph.off[a], graph.off[a + 1]):
				var b: int = graph.to[e]
				if graph.flags(b) & Graph.LINE != 0 and _intersects(frame, graph.position(a), graph.position(b)):
					return false
	return true


static func stage(layout: Dictionary, seed_value: int, arm: String) -> Dictionary:
	var base = layout["graph"]
	var sockets: Array = layout["sockets"]
	var cache_key := [base.to_bytes(), JSON.stringify(sockets, "", true)]
	if layout.get("_closure_key", []) != cache_key:
		layout["_closure_plan"] = _compile(base, sockets)
		layout["_closure_key"] = cache_key
	var plan: Dictionary = layout["_closure_plan"]
	var errors: Array = plan["errors"].duplicate()
	var out := {"ok": false, "errors": errors, "closed": [], "fillers": [], "pockets": [],
		"pocket_count": 0, "one_socket": 0, "off_route": true, "fillers_off_route": true,
		"openings_ok": errors.is_empty(), "reachable": false, "shortest_m": INF,
		"complete_placement": false, "full_visit_ratio": INF, "partial_visit_ratio": INF}
	if not errors.is_empty():
		return out
	if not ["fixed", "sockets"].has(arm):
		errors.append("unknown arm")
		return out
	var wanted: Array = layout["pocket_zones"]
	if wanted.size() < POCKET_MIN or wanted.size() > POCKET_MAX:
		errors.append("expected 3 to 8 pocket zones")
		return out
	var unique := {}
	for z in wanted:
		if z < 0 or z >= base.zone_count() or unique.has(z):
			errors.append("pocket zones must be valid and distinct")
			return out
		unique[z] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var keep := {}
	var drawn_doors := {}
	for z in wanted:
		if base.zones()[z]["line"] or base.zones()[z]["warden"] or base.zone_door_nodes(z).size() < Graph.ANCHOR_MIN_DOOR_NODES:
			errors.append("zone %s cannot hold a guaranteed pocket" % base.zones()[z]["name"])
			return out
		var choices := []
		for s in sockets:
			if s["a"] != z and s["b"] != z:
				continue
			var other: int = s["b"] if s["a"] == z else s["a"]
			var enters := false
			var leaves := false
			for link in s["links"]:
				enters = enters or base.zone_of(link[1]) == z
				leaves = leaves or base.zone_of(link[0]) == z
			if enters and leaves and not wanted.has(other):
				choices.append(s["id"])
		if choices.is_empty():
			errors.append("pocket has no returning socket")
			return out
		keep[z] = choices[rng.randi_range(0, choices.size() - 1)]
		var doors: PackedInt32Array = base.zone_door_nodes(z)
		drawn_doors[z] = doors[rng.randi_range(0, doors.size() - 1)]
	var blocked := {}
	for s in sockets:
		var close: bool = not s["fixed_open"] if arm == "fixed" else false
		if arm == "sockets":
			for z in [s["a"], s["b"]]:
				if keep.has(z) and keep[z] != s["id"]:
					close = true
		if not close:
			continue
		if not plan["sockets"][s["id"]]["safe"]:
			out["fillers_off_route"] = false
			errors.append("filler %s crosses the protected route" % s["id"])
			return out
		out["closed"].append(s["id"])
		out["fillers"].append(s["filler"].duplicate(true))
		blocked.merge(plan["sockets"][s["id"]]["blocked"])
	var graph = _overlay(base, blocked)
	out["graph"] = graph
	out["shortest_m"] = graph.d_from[graph.beacon_node]
	if out["shortest_m"] == INF or not is_equal_approx(out["shortest_m"], base.d_from[base.beacon_node]):
		errors.append("closure changes the shortest route")
	out["reachable"] = true
	for z in wanted:
		var open_count := 0
		for s in sockets:
			if (s["a"] == z or s["b"] == z) and not out["closed"].has(s["id"]):
				open_count += 1
		if open_count != 1:
			continue
		if graph.zones()[z]["degree"] != 1:
			errors.append("physical filler leaves the wrong entrance count")
			continue
		out["one_socket"] += 1
		var door: int = drawn_doors[z]
		out["pockets"].append({"zone": z, "door": door})
		out["off_route"] = out["off_route"] and graph.flags(door) & (Graph.LINE | Graph.WARDEN) == 0
		out["reachable"] = out["reachable"] and graph.d_from[door] < INF and graph.d_land[door] < INF
	out["pocket_count"] = out["pockets"].size()
	out["complete_placement"] = out["pocket_count"] == wanted.size()
	if not out["complete_placement"]:
		errors.append("fixed openings do not supply every requested anchor")
	if not out["reachable"]:
		errors.append("a pocket cannot be visited and left")
	if not out["off_route"]:
		errors.append("a guaranteed pocket sits on the shortest route")
	var visit := _full_visit(graph, out["pockets"])
	var ratio: float = visit / out["shortest_m"] if out["shortest_m"] > 0.0 and out["shortest_m"] < INF else INF
	if out["complete_placement"]:
		out["full_visit_ratio"] = ratio
	else:
		out["partial_visit_ratio"] = ratio
	if out["complete_placement"] and out["full_visit_ratio"] > VISIT_MAX:
		errors.append("full visit exceeds 3.0")
	out["ok"] = errors.is_empty()
	return out


static func _compile(base, sockets: Array) -> Dictionary:
	var plan := {"errors": validate(base, sockets), "sockets": {}}
	if not plan["errors"].is_empty():
		return plan
	var shortest := _shortest_links(base)
	for socket in sockets:
		var blocked := {}
		var frame := _frame(socket["filler"])
		for a in base.node_count():
			for e in range(base.off[a], base.off[a + 1]):
				var b: int = base.to[e]
				if _intersects(frame, base.position(a), base.position(b)):
					blocked[_key(a, b, base.node_count())] = true
		plan["sockets"][socket["id"]] = {"safe": _safe(base, socket["filler"], shortest), "blocked": blocked}
	return plan


static func _overlay(base, blocked: Dictionary):
	var graph = Graph.from_bytes(base.to_bytes())
	graph.off = PackedInt32Array([0])
	graph.to = PackedInt32Array()
	graph.length = PackedFloat32Array()
	graph.ride = PackedInt32Array()
	for a in base.node_count():
		for e in range(base.off[a], base.off[a + 1]):
			if not blocked.has(_key(a, base.to[e], base.node_count())):
				graph.to.append(base.to[e])
				graph.length.append(base.length[e])
				graph.ride.append(base.ride[e])
		graph.off.append(graph.to.size())
	graph.reverse()
	graph.d_from = graph.search(PackedInt32Array([graph.spawn_node]))
	graph.d_land = graph.search(PackedInt32Array([graph.beacon_node]), true)
	_zone_table(graph)
	return graph


static func _zone_table(graph) -> void:
	var entering := []
	var leaving := []
	var crossings := {}
	for z in graph.zone_count():
		entering.append({})
		leaving.append({})
	for a in graph.node_count():
		var za: int = graph.zone_of(a)
		for e in range(graph.off[a], graph.off[a + 1]):
			var zb: int = graph.zone_of(graph.to[e])
			if za != zb:
				entering[zb][za] = true
				leaving[za][zb] = true
				var key := _key(za, zb, graph.zone_count())
				crossings[key] = int(crossings.get(key, 0)) + 1
	graph.crossing_table = []
	for key in crossings:
		var a: int = key / graph.zone_count()
		var b: int = key % graph.zone_count()
		var reverse_key := _key(b, a, graph.zone_count())
		if crossings.has(reverse_key) and a > b:
			continue
		graph.crossing_table.append({"a": a, "b": b, "kind": "walk" if crossings.has(reverse_key) else "drop", "row": "", "links": crossings[key]})
	for z in graph.zone_count():
		var row: Dictionary = graph.zone_table[z]
		row["entrances"] = entering[z].keys()
		row["entrances"].sort()
		row["exits"] = leaving[z].keys()
		row["exits"].sort()
		row["degree"] = row["entrances"].size()
		row["openings"] = 0
		row["drops"] = 0
		for crossing in graph.crossing_table:
			if crossing["a"] == z or crossing["b"] == z:
				row["openings"] += 1 if crossing["kind"] != "drop" else 0
				row["drops"] += 1 if crossing["kind"] == "drop" else 0
		row["d_spawn"] = INF
		row["d_landmark"] = INF
		row["nodes"] = 0
		row["door_ok"] = 0
		for node in graph.zone_nodes(z):
			row["nodes"] += 1
			row["door_ok"] += 1 if graph.flags(node) & Graph.DOOR_OK != 0 else 0
			row["d_spawn"] = minf(row["d_spawn"], graph.d_from[node])
			row["d_landmark"] = minf(row["d_landmark"], graph.d_land[node])
		if row["d_spawn"] == INF:
			row["d_spawn"] = -1.0
		if row["d_landmark"] == INF:
			row["d_landmark"] = -1.0


static func _full_visit(graph, pockets: Array) -> float:
	var count := pockets.size()
	if count == 0:
		return graph.d_from[graph.beacon_node]
	var distances := []
	for p in pockets:
		distances.append(graph.search(PackedInt32Array([p["door"]])))
	var dp := {}
	for i in count:
		dp[(1 << i) * count + i] = graph.d_from[pockets[i]["door"]]
	for mask in range(1, 1 << count):
		for i in count:
			var key: int = mask * count + i
			if not dp.has(key):
				continue
			for j in count:
				if mask & (1 << j) == 0:
					var next: int = (mask | (1 << j)) * count + j
					var value: float = dp[key] + distances[i][pockets[j]["door"]]
					dp[next] = minf(dp.get(next, INF), value)
	var best := INF
	for i in count:
		best = minf(best, dp.get(((1 << count) - 1) * count + i, INF) + graph.d_land[pockets[i]["door"]])
	return best


static func template(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := rng.randi_range(POCKET_MIN, POCKET_MAX)
	var builder := LabBuilder.new()
	var main_count := count + 1
	for z in main_count + count:
		builder.zone(z, z < main_count)
	var width := (count + 1) * 160
	var start := -width / 2
	for x in range(start, start + width + 1, 8):
		var z := mini((x - start) / 160, main_count - 1)
		for y in [0, -8]:
			builder.node(x, y, z, Graph.OPEN | Graph.LINE)
	for x in range(start, start + width + 1, 8):
		builder.link_at(x, 0, x, -8)
		if x < start + width:
			for y in [0, -8]:
				builder.link_at(x, y, x + 8, y)
			if (x + 8 - start) % 160 == 0 and x + 8 < start + width:
				var a: int = (x - start) / 160
				builder.socket("route_%d" % a, a, a + 1, [[x, 0, x + 8, 0], [x, -8, x + 8, -8]],
					_filler("route_%d" % a, [x + 4, -4], [16, 8, 4]), true)
	var pocket_zones := []
	for i in count:
		var z := main_count + i
		pocket_zones.append(z)
		var centre := start + (i + 1) * 160
		var depth := rng.randi_range(12, 16) * 8
		for x in range(centre - 24, centre + 33, 8):
			for y in range(depth, depth + 33, 8):
				builder.node(x, y, z, Graph.OPEN | Graph.DOOR_OK | Graph.SIGHT_OK)
		for x in range(centre - 24, centre + 33, 8):
			for y in range(depth, depth + 33, 8):
				if x < centre + 32:
					builder.link_at(x, y, x + 8, y)
				if y < depth + 32:
					builder.link_at(x, y, x, y + 8)
		var fixed_keeper := rng.randi_range(0, 1)
		var fixed_both := rng.randi_range(0, 1) == 1
		for side in 2:
			var mouth := centre - 24 if side == 0 else centre + 24
			var main_zone := i + side
			for x in [mouth, mouth + 8]:
				for y in range(8, depth, 8):
					builder.node(x, y, main_zone if y <= 16 else z, Graph.OPEN)
				for y in range(0, depth, 8):
					builder.link_at(x, y, x, y + 8)
			for y in range(8, depth, 8):
				builder.link_at(mouth, y, mouth + 8, y)
			var id := "pocket_%d_%d" % [i, side]
			builder.socket(id, z, main_zone, [[mouth, 16, mouth, 24], [mouth + 8, 16, mouth + 8, 24]],
				_filler(id, [mouth + 4, 20], [4, 8, 16]), fixed_both or side == fixed_keeper)
	var graph = builder.finish()
	_zone_table(graph)
	return {"graph": graph, "sockets": builder.sockets, "pocket_zones": pocket_zones}


static func _filler(id: String, at: Array, size: Array) -> Dictionary:
	return {"id": "socket_fill_" + id, "element": "ground", "landform": "slickrock", "society": "none",
		"at": at, "y": 0, "size": size, "yaw_deg": 0, "recipe": "greybox:ground",
		"verb": "roll", "ride_fact": "", "stamp": "", "hole": false, "budget": "landform", "routes": []}


class LabBuilder:
	var graph = Graph.new()
	var nodes := {}
	var edges := []
	var sockets := []

	func zone(id: int, line: bool) -> void:
		graph.zone_table.append({"id": id, "name": "route_%d" % id if line else "landform_%d" % id,
			"kind": "open" if line else "landform", "row": "", "nodes": 0, "cx": 0, "cz": 0,
			"line": line, "warden": false, "door_ok": 0, "d_spawn": 0.0, "d_landmark": 0.0,
			"degree": 0, "openings": 0, "drops": 0, "entrances": [], "exits": []})

	func node(x: int, z: int, zone_id: int, flags: int) -> void:
		var key := Vector2i(x, z)
		if nodes.has(key):
			return
		nodes[key] = graph.node_count()
		graph.px.append(x)
		graph.py.append(0.0)
		graph.pz.append(z)
		graph.node_zone.append(zone_id)
		graph.node_flags.append(flags)
		graph.node_rows.append(-1)
		edges.append({})

	func link_at(x: int, z: int, xx: int, zz: int) -> void:
		var a: int = nodes[Vector2i(x, z)]
		var b: int = nodes[Vector2i(xx, zz)]
		edges[a][b] = graph.position(a).distance_to(graph.position(b))
		edges[b][a] = edges[a][b]

	func socket(id: String, a: int, b: int, points: Array, filler: Dictionary, fixed_open: bool) -> void:
		var links := []
		for p in points:
			var from: int = nodes[Vector2i(p[0], p[1])]
			var to: int = nodes[Vector2i(p[2], p[3])]
			links.append([from, to])
			links.append([to, from])
		sockets.append({"id": id, "a": a, "b": b, "links": links, "filler": filler, "fixed_open": fixed_open})

	func finish():
		graph.off.append(0)
		for neighbours in edges:
			var keys: Array = neighbours.keys()
			keys.sort()
			for b in keys:
				graph.to.append(b)
				graph.length.append(neighbours[b])
				graph.ride.append(-1)
			graph.off.append(graph.to.size())
		graph.spawn_node = 0
		var far := -INF
		for node_id in graph.node_count():
			if graph.pz[node_id] == 0 and graph.px[node_id] > far:
				far = graph.px[node_id]
				graph.beacon_node = node_id
		graph.reverse()
		graph.d_from = graph.search(PackedInt32Array([graph.spawn_node]))
		graph.d_land = graph.search(PackedInt32Array([graph.beacon_node]), true)
		return graph


static func signature(stage_rows: Dictionary) -> String:
	return JSON.stringify({"closed": stage_rows["closed"], "fillers": stage_rows["fillers"],
		"pockets": stage_rows["pockets"], "complete_placement": stage_rows["complete_placement"],
		"full_visit_ratio": stage_rows["full_visit_ratio"], "partial_visit_ratio": stage_rows["partial_visit_ratio"]}, "", true)


static func _record_draw(stats: Dictionary, made: Dictionary, requested: int, seed_value: int) -> void:
	stats["successes"] += 1 if made["ok"] else 0
	stats["rerolls"] += 0 if made["ok"] else 1
	stats["count_ok"] += 1 if made["pocket_count"] >= POCKET_MIN and made["pocket_count"] <= POCKET_MAX else 0
	stats["off_route"] += 1 if made["off_route"] and made["pocket_count"] > 0 else 0
	stats["complete"] += 1 if made["complete_placement"] else 0
	stats["incomplete"] += 0 if made["complete_placement"] else 1
	if made["complete_placement"]:
		stats["visit_ok"] += 1 if made["full_visit_ratio"] <= VISIT_MAX else 0
		stats["max_ratio"] = maxf(stats["max_ratio"], made["full_visit_ratio"])
	stats["fillers_off_route"] += 1 if made["fillers_off_route"] else 0
	stats["rows"].append({"seed": seed_value, "pockets": made["pocket_count"], "requested": requested,
		"reroll": not made["ok"], "complete_placement": made["complete_placement"],
		"full_visit_ratio": made["full_visit_ratio"] if made["complete_placement"] else null,
		"partial_visit_ratio": made["partial_visit_ratio"] if not made["complete_placement"] else null,
		"shortest_m": made["shortest_m"], "fillers": made["fillers"].size(), "off_route": made["off_route"],
		"fillers_off_route": made["fillers_off_route"], "errors": made["errors"]})


static func sweep(seeds := SEEDS) -> Dictionary:
	var result := {"errors": [], "ok": false}
	for arm in ["fixed", "sockets"]:
		result[arm] = {"seeds": seeds, "successes": 0, "rerolls": 0, "count_ok": 0,
			"off_route": 0, "visit_ok": 0, "complete": 0, "incomplete": 0,
			"fillers_off_route": 0, "max_ratio": 0.0, "rows": []}
	for seed_value in range(1, seeds + 1):
		var layout := template(seed_value)
		for arm in ["fixed", "sockets"]:
			var made := stage(layout, seed_value, arm)
			_record_draw(result[arm], made, layout["pocket_zones"].size(), seed_value)
	for arm in ["fixed", "sockets"]:
		result[arm]["success_share"] = float(result[arm]["successes"]) / maxf(seeds, 1)
		result[arm]["reroll_share"] = float(result[arm]["rerolls"]) / maxf(seeds, 1)
	result["errors"] = gate(result)
	result["ok"] = result["errors"].is_empty()
	return result


static func gate(result: Dictionary) -> Array:
	var errors := []
	var fixed: Dictionary = result["fixed"]
	var sockets: Dictionary = result["sockets"]
	if sockets["seeds"] <= 0 or sockets["seeds"] != fixed["seeds"]:
		errors.append("expected equal nonempty seeded arms")
	for arm in ["fixed", "sockets"]:
		var stats: Dictionary = result[arm]
		var rows: Array = stats["rows"]
		var seeds: int = stats["seeds"]
		if rows.size() != seeds:
			errors.append("%s row count disagrees with seeds" % arm)
		var failed := 0
		var identities := true
		for i in rows.size():
			identities = identities and rows[i]["seed"] == i + 1
			failed += 1 if rows[i]["reroll"] else 0
		if not identities:
			errors.append("%s rows must identify seeds 1 through %d exactly" % [arm, seeds])
		var expected := {"rerolls": failed, "successes": rows.size() - failed,
			"success_share": float(rows.size() - failed) / maxf(seeds, 1),
			"reroll_share": float(failed) / maxf(seeds, 1)}
		for field in expected:
			if stats[field] != expected[field]:
				errors.append("%s %s disagrees with rows" % [arm, field])
	if sockets["success_share"] < SUCCESS_MIN:
		errors.append("fewer than 95% of socket seeds meet every stage criterion")
	for metric in ["count_ok", "off_route", "visit_ok"]:
		if sockets[metric] < sockets["seeds"] * SUCCESS_MIN:
			errors.append("socket %s misses the 95%% threshold" % metric)
	if sockets["reroll_share"] >= REROLL_MAX:
		errors.append("socket re-roll rate is not under 10%")
	if sockets["reroll_share"] > fixed["reroll_share"] * FIXED_SHARE_MAX:
		errors.append("socket re-roll rate exceeds half the fixed rate")
	if sockets["fillers_off_route"] != sockets["seeds"]:
		errors.append("a filler crosses the shortest route")
	return errors


static func report(result: Dictionary) -> String:
	var lines := PackedStringArray(["sockets lab: paired 8 m open-route templates, fixed connector masks against adaptive closures"])
	for arm in ["fixed", "sockets"]:
		var s: Dictionary = result[arm]
		lines.append("%s: %d seeds; all-criteria success %.1f%% (socket minimum 95%%); pockets 3..8 %d/%d; guaranteed off-route %d/%d; re-roll %.1f%% (socket under 10%%); complete draws %d, incomplete draws %d; full visit <=3.0 %d/%d complete draws, maximum %.3f; fillers off-route %d/%d" % [
			arm, s["seeds"], 100.0 * s["success_share"], s["count_ok"], s["seeds"], s["off_route"], s["seeds"],
			100.0 * s["reroll_share"], s["complete"], s["incomplete"], s["visit_ok"], s["complete"], s["max_ratio"], s["fillers_off_route"], s["seeds"]])
	lines.append("socket re-roll %.1f%% <= half fixed %.1f%%: %s" % [100.0 * result["sockets"]["reroll_share"],
		50.0 * result["fixed"]["reroll_share"], "PASS" if result["sockets"]["reroll_share"] <= result["fixed"]["reroll_share"] * FIXED_SHARE_MAX else "FAIL"])
	lines.append("socket gate: %s %s" % ["PASS" if result["ok"] else "FAIL", str(result["errors"])])
	return "\n".join(lines)
