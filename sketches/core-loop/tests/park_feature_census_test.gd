extends SceneTree

# Owner map points 6, 7 and 9 (10 Nov 2026; map-audit section G), read from the park file and the
# baked stage graph only; no scene boots. Per world 1 park (the dam and the flume):
#
#  point 6, feature_count_near_line (pass >= 2): the park's features that a player's action changes,
#    within LINE_REACH_M of path from a LINE node of the graph (either direction, whichever is shorter).
#    A feature is a contraption row of kind valve, cracked_wall, lift or launcher (at its `at`), or an
#    event row whose route_change opens or closes something (at its site, read with
#    ParkMap.place_of). Cables and thermals carry the player but change nothing, so they are not counted.
#  point 7, height_bands_populated (pass >= 3): the height bands that each hold at least BAND_SHARE_MIN
#    of the OPEN nodes. Band edges are the midpoints between the park's own tier heights (BANDS below,
#    with how each was read). ride_climb_rows (pass >= 4): distinct ride rows with at least one ride edge
#    that climbs RIDE_CLIMB_M or more in its own direction (ride edges counted too, printed as info).
#  point 9, hub_zones_3_bands (pass >= 1): zones whose crossings (walk, drop and ride) reach, with the
#    zone's own band, at least 3 height bands. A zone's band is the band of its mean node height.
#
# Output, one line per stage and measure: `MAPCHECK <stage> <measure> <value> pass>=<line> PASS|FAIL|OWED`,
# and `... report INFO` lines for the detail. OWED lists the stage measures under the line today. The
# test fails if an OWED entry now meets its line (prune it) and if an unlisted one is under its line.
#
# Planted, one per measure, each shown failing: feature rows stripped (the valve and bulkhead rows go,
# and with them every other counted kind and route-changing event row, or the dam's launchers and lift
# would still count); the node heights flattened to one value under the real band edges; and the
# crossings with every hub zone's removed.

const T := preload("res://tests/support/t.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")

const OUT_DIR := "res://assets/park"
const PARK_DIR := "res://src/world/park"
const WORLD1 := ["park_dam", "park_flume"]
const FEATURE_KINDS := ["valve", "cracked_wall", "lift", "launcher"]
const LINE_REACH_M := 150.0
const BAND_SHARE_MIN := 0.05
const RIDE_CLIMB_M := 10.0
const HUB_BANDS := 3
const MIN_FEATURES := 2
const MIN_BANDS := 3
const MIN_CLIMBS := 4
const MIN_HUBS := 1

# Band edges in metres, the midpoints between each park's tier heights (map-audit: the dam stands on
# tiers at y 0, 100 and 150, the flume on canal floor 0, bench and rim about 60, mesa about 100):
# below edge 0, between the edges, above edge 1.
const BANDS := {
	"park_dam": [50.0, 125.0],
	"park_flume": [30.0, 80.0],
}

# Stage measures under their line today. {"<stage> <measure>": {"value": measured, "why": "..."}}
const OWED := {}

var t := T.new("park_feature_census_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for map_id in WORLD1:
		var map := ParkMap.new("%s/%s.json" % [PARK_DIR, map_id])
		var g = ParkGraph.read("%s/%s/graph.bin" % [OUT_DIR, map_id])
		if not t.check("%s inputs load" % map_id, map.ok and g != null, "park file and graph.bin"):
			continue
		var ys := _node_heights(g)
		var r := measure(map_id, map.park, g, ys, g.crossings())
		_report(map_id, r)
		if map_id == "park_dam":
			_planted(map_id, map.park, g, ys)
	quit(t.verdict())


func _node_heights(g) -> PackedFloat32Array:
	var ys := PackedFloat32Array()
	for n in g.node_count():
		ys.append(g.position(n).y)
	return ys


static func band_of(y: float, edges: Array) -> int:
	var b := 0
	for e in edges:
		if y >= float(e):
			b += 1
	return b


# The features that change with a player's action: [{"id", "at": Vector2}].
static func features(park: Dictionary) -> Array:
	var out := []
	for row: Dictionary in park["contraption_rows"]:
		if row["kind"] in FEATURE_KINDS and row.has("at"):
			var a: Array = row["at"]
			out.append({"id": row["id"], "at": Vector2(float(a[0]), float(a[1]))})
	for row: Dictionary in park["event_rows"]:
		var change: Dictionary = row.get("route_change", {})
		if change.get("closes", []).is_empty() and change.get("opens", []).is_empty():
			continue
		var at := ParkMap.place_of(park, String(row["site"]))
		if at.is_finite():
			out.append({"id": row["id"], "at": at})
	return out


# All the census readings for one stage over a height array (one value a node), a crossings list and
# the park rows. Returns the measure values and the detail the report prints.
static func measure(map_id: String, park: Dictionary, g, ys: PackedFloat32Array, crossings: Array) -> Dictionary:
	var edges: Array = BANDS[map_id]
	var out := {}
	# Point 6.
	var lines := PackedInt32Array()
	for n in g.node_count():
		if g.flags(n) & ParkGraph.LINE != 0:
			lines.append(n)
	var from_line: PackedFloat32Array = g.search(lines, false, LINE_REACH_M)
	var to_line: PackedFloat32Array = g.search(lines, true, LINE_REACH_M)
	var near := []
	var far := []
	for f in features(park):
		var n: int = g.nearest(f["at"])
		var d := minf(from_line[n], to_line[n])
		if d <= LINE_REACH_M:
			near.append("%s %.0f m" % [f["id"], d])
		else:
			far.append(f["id"])
	out["feature_count_near_line"] = near.size()
	out["features_near"] = near
	out["features_far"] = far
	# Point 7, bands.
	var counts := [0, 0, 0]
	var open := 0
	for n in g.node_count():
		if g.flags(n) & ParkGraph.OPEN != 0:
			open += 1
			counts[band_of(ys[n], edges)] += 1
	var shares := []
	var populated := 0
	for c in counts:
		shares.append(float(c) / float(maxi(open, 1)))
		if float(c) / float(maxi(open, 1)) >= BAND_SHARE_MIN:
			populated += 1
	out["height_bands_populated"] = populated
	out["band_shares"] = shares
	# Point 7, ride climbs, in each ride edge's own direction.
	var rows := {}
	var edge_count := 0
	for a in g.node_count():
		for e in range(g.off[a], g.off[a + 1]):
			if g.ride[e] >= 0 and ys[g.to[e]] - ys[a] >= RIDE_CLIMB_M:
				edge_count += 1
				rows[g.names[g.ride[e]]] = true
	out["ride_climb_rows"] = rows.size()
	out["ride_climb_edges"] = edge_count
	out["ride_climb_names"] = rows.keys()
	# Point 9, hubs.
	var zone_band := {}
	for z in g.zones():
		var nodes: PackedInt32Array = g.zone_nodes(z["id"])
		var sum := 0.0
		for n in nodes:
			sum += ys[n]
		zone_band[z["id"]] = band_of(sum / float(maxi(nodes.size(), 1)), edges)
	var reach := {}
	for c in crossings:
		for pair in [[c["a"], c["b"]], [c["b"], c["a"]]]:
			if not reach.has(pair[0]):
				reach[pair[0]] = {zone_band[pair[0]]: true}
			reach[pair[0]][zone_band[pair[1]]] = true
	var hubs := []
	for zid in reach:
		if reach[zid].size() >= HUB_BANDS:
			hubs.append(zid)
	hubs.sort()
	out["hub_zones_3_bands"] = hubs.size()
	out["hub_ids"] = hubs
	out["hub_names"] = hubs.slice(0, 6).map(func(z): return String(g.zones()[z]["name"]))
	return out


func _line_for(measure_name: String) -> int:
	return {"feature_count_near_line": MIN_FEATURES, "height_bands_populated": MIN_BANDS,
		"ride_climb_rows": MIN_CLIMBS, "hub_zones_3_bands": MIN_HUBS}[measure_name]


func _report(map_id: String, r: Dictionary) -> void:
	for m in ["feature_count_near_line", "height_bands_populated", "ride_climb_rows", "hub_zones_3_bands"]:
		var line := _line_for(m)
		var value: int = r[m]
		var meets := value >= line
		var key := "%s %s" % [map_id, m]
		var owed := OWED.has(key)
		var status := "PASS" if meets else ("OWED" if owed else "FAIL")
		print("MAPCHECK %s %s %d pass>=%d %s" % [map_id, m, value, line, status])
		if owed:
			t.check("%s OWED, still under its line (prune the entry when it meets it)" % key, not meets, "%d vs %d" % [value, line])
		else:
			t.check("%s >= %d" % [key, line], meets, "%d" % value)
	print("MAPCHECK %s feature_near_list %s report INFO" % [map_id, "; ".join(r["features_near"]).replace(" ", "_")])
	print("MAPCHECK %s feature_far_list %s report INFO" % [map_id, ",".join(r["features_far"])])
	print("MAPCHECK %s band_shares %s report INFO" % [map_id, "/".join(r["band_shares"].map(func(s): return "%.3f" % s))])
	print("MAPCHECK %s ride_climb_edges %d report INFO" % [map_id, r["ride_climb_edges"]])
	print("MAPCHECK %s ride_climb_names %s report INFO" % [map_id, ",".join(r["ride_climb_names"])])
	print("MAPCHECK %s hub_zones %s report INFO" % [map_id, ",".join(r["hub_names"])])


func _planted(map_id: String, park: Dictionary, g, ys: PackedFloat32Array) -> void:
	var real := measure(map_id, park, g, ys, g.crossings())
	# 6: valve and bulkhead rows stripped; every other counted kind and route-changing event with them.
	var bare := park.duplicate(true)
	bare["contraption_rows"] = bare["contraption_rows"].filter(func(row): return not (row["kind"] in FEATURE_KINDS))
	bare["event_rows"] = bare["event_rows"].filter(func(row): return row.get("route_change", {}).get("closes", []).is_empty() and row.get("route_change", {}).get("opens", []).is_empty())
	var valve_only := park.duplicate(true)
	valve_only["contraption_rows"] = valve_only["contraption_rows"].filter(func(row): return row["kind"] != "valve" and row["kind"] != "cracked_wall")
	var r_bare := measure(map_id, bare, g, ys, g.crossings())
	var r_valve := measure(map_id, valve_only, g, ys, g.crossings())
	print("PLANTED %s feature_count_near_line %d (real %d; valve and bulkhead alone stripped %d) pass>=%d %s" % [map_id, r_bare["feature_count_near_line"], real["feature_count_near_line"], r_valve["feature_count_near_line"], MIN_FEATURES, "PASS" if r_bare["feature_count_near_line"] >= MIN_FEATURES else "FAIL"])
	t.check("planted: feature rows stripped fails the feature-count assertion", r_bare["feature_count_near_line"] < MIN_FEATURES, "%d vs %d" % [r_bare["feature_count_near_line"], MIN_FEATURES])
	# 7: heights flattened to one value, under the real band edges.
	var flat := ys.duplicate()
	flat.fill(100.0)
	var r_flat := measure(map_id, park, g, flat, g.crossings())
	print("PLANTED %s height_bands_populated %d ride_climb_rows %d (real %d, %d) pass>=%d, >=%d %s" % [map_id, r_flat["height_bands_populated"], r_flat["ride_climb_rows"], real["height_bands_populated"], real["ride_climb_rows"], MIN_BANDS, MIN_CLIMBS, "FAIL" if r_flat["height_bands_populated"] < MIN_BANDS else "PASS"])
	t.check("planted: flattened heights fail the height-band assertion", r_flat["height_bands_populated"] < MIN_BANDS, "%d vs %d" % [r_flat["height_bands_populated"], MIN_BANDS])
	t.check("planted: flattened heights fail the ride-climb assertion", r_flat["ride_climb_rows"] < MIN_CLIMBS, "%d vs %d" % [r_flat["ride_climb_rows"], MIN_CLIMBS])
	# 9: crossings with every hub zone's removed.
	var hubs: Array = real["hub_ids"]
	var kept := []
	for c in g.crossings():
		if not (c["a"] in hubs or c["b"] in hubs):
			kept.append(c)
	var r_hub := measure(map_id, park, g, ys, kept)
	print("PLANTED %s hub_zones_3_bands %d (real %d; %d of %d crossings kept) pass>=%d %s" % [map_id, r_hub["hub_zones_3_bands"], real["hub_zones_3_bands"], kept.size(), g.crossings().size(), MIN_HUBS, "PASS" if r_hub["hub_zones_3_bands"] >= MIN_HUBS else "FAIL"])
	t.check("planted: crossings with the hubs removed fail the hub assertion", r_hub["hub_zones_3_bands"] < MIN_HUBS, "%d vs %d" % [r_hub["hub_zones_3_bands"], MIN_HUBS])
